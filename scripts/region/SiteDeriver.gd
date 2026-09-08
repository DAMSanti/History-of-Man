@tool
class_name SiteDeriver
extends RefCounted
## Deriva emplazamientos a partir del relieve real.
##
## No genera una rejilla uniforme: 5321 km2 divididos en celdas de 1 km serian
## miles de opciones indistinguibles. Busca sitios donde el terreno OFRECE algo
## —agua cerca, llano donde asentarse, costa accesible, prominencia defendible—
## y se queda con los maximos locales separados entre si.
##
## Todo se calcula con transformadas de distancia y desenfoques, en O(n): medir
## celda por celda la distancia al rio mas cercano sobre un millon de celdas
## seria inviable.

## Separacion minima entre emplazamientos, en km.
## Baja a proposito: el mapa regional debe verse poblado, y como la
## exploracion los revela poco a poco, el jugador nunca los ve todos de golpe.
var min_spacing_km: float = 1.6

## Cota del mar para la que se derivan. Cambiarla mueve la costa y hace
## aparecer la plataforma continental, que en el Paleolitico estaba emergida.
var sea_level_m: float = 0.0

## Pesos del criterio
var w_water: float = 1.0
var w_flat: float = 0.8
var w_coast: float = 0.9
var w_prominence: float = 0.6

## Puntuacion minima para considerar un sitio
var min_score: float = 0.55

## Campos calculados en la ultima llamada a derive(), para poder evaluar
## despues puntos concretos (los yacimientos reales) sin recalcular todo
var _coast_dist: PackedFloat32Array
var _river_dist: PackedFloat32Array
var _smooth: PackedFloat32Array
var _km: float = 0.0


## Deriva los emplazamientos de un heightmap. Devuelve Array[Site].
func derive(data: HeightmapData, limit: int = 6000) -> Array[Site]:
	var w := data.width
	var h := data.height
	var n := w * h
	var cell_m := data.meters_per_sample

	# --- campos de distancia -------------------------------------------
	var sea_seed := PackedByteArray()
	sea_seed.resize(n)
	var river_seed := PackedByteArray()
	river_seed.resize(n)
	var has_rivers := not data.river_mask.is_empty()

	sea_seed = _ocean_mask(data, sea_level_m)
	for i in range(n):
		river_seed[i] = 1 if (has_rivers and data.river_mask[i] > 0.3) else 0

	var coast_dist := _distance_field(sea_seed, w, h)
	var river_dist := _distance_field(river_seed, w, h) if has_rivers else PackedFloat32Array()

	# --- relieve local -------------------------------------------------
	var smooth := _box_blur(data.elevations, w, h, 12)

	# Guardados para site_at()
	_coast_dist = coast_dist
	_river_dist = river_dist
	_smooth = smooth
	_km = cell_m / 1000.0

	# --- puntuacion ----------------------------------------------------
	var score := PackedFloat32Array()
	score.resize(n)
	var km := cell_m / 1000.0

	for z in range(1, h - 1):
		var row := z * w
		for x in range(1, w - 1):
			var i := row + x
			var elev := data.elevations[i]

			# Bajo el agua no hay emplazamiento posible
			if elev <= sea_level_m:
				continue

			var dx := (data.elevations[i + 1] - data.elevations[i - 1]) / (2.0 * cell_m)
			var dz := (data.elevations[i + w] - data.elevations[i - w]) / (2.0 * cell_m)
			var slope := rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

			# Una ladera de mas de 25 grados no sostiene un asentamiento
			if slope > 25.0:
				continue

			var s := 0.0
			# Agua dulce: decisiva de cerca, irrelevante a partir de 4 km
			if has_rivers:
				s += w_water * clampf(1.0 - (river_dist[i] * km) / 4.0, 0.0, 1.0)
			# Terreno llano
			s += w_flat * clampf(1.0 - slope / 18.0, 0.0, 1.0)
			# Acceso al mar: fuerte hasta 3 km
			s += w_coast * clampf(1.0 - (coast_dist[i] * km) / 3.0, 0.0, 1.0)
			# Prominencia: se levanta sobre su entorno
			s += w_prominence * clampf((elev - smooth[i]) / 120.0, 0.0, 1.0)

			score[i] = s

	# --- maximos locales con separacion minima -------------------------
	var spacing_cells := maxi(int(min_spacing_km * 1000.0 / cell_m), 1)

	# Ordenar por puntuacion con conteo por franjas, no con sort_custom: sobre
	# cientos de miles de candidatos una comparacion por lambda en GDScript
	# tarda minutos, y esto es O(n).
	const BINS := 1024
	var top_score := 0.0
	for v in score:
		top_score = maxf(top_score, v)
	if top_score <= 0.0:
		return []

	var counts := PackedInt32Array()
	counts.resize(BINS)
	var candidates := 0
	for i in range(n):
		if score[i] >= min_score:
			counts[clampi(int(score[i] / top_score * float(BINS - 1)), 0, BINS - 1)] += 1
			candidates += 1

	var offsets := PackedInt32Array()
	offsets.resize(BINS)
	var running := 0
	for b in range(BINS - 1, -1, -1):   # de mayor a menor puntuacion
		offsets[b] = running
		running += counts[b]

	var order := PackedInt32Array()
	order.resize(candidates)
	var cursor := offsets.duplicate()
	for i in range(n):
		if score[i] >= min_score:
			var b := clampi(int(score[i] / top_score * float(BINS - 1)), 0, BINS - 1)
			order[cursor[b]] = i
			cursor[b] += 1

	var taken := PackedByteArray()
	taken.resize(n)
	var sites: Array[Site] = []

	for i: int in order:
		if sites.size() >= limit:
			break
		if taken[i] == 1:
			continue

		var x := i % w
		var z := i / w
		sites.append(_make_site(data, x, z, score[i], coast_dist, river_dist, smooth, km))

		# Bloquear el entorno para que no salgan racimos
		for dz in range(-spacing_cells, spacing_cells + 1):
			var zz := z + dz
			if zz < 0 or zz >= h:
				continue
			var base := zz * w
			for dx in range(-spacing_cells, spacing_cells + 1):
				var xx := x + dx
				if xx >= 0 and xx < w:
					taken[base + xx] = 1

	for k in range(sites.size()):
		sites[k].id = k
	return sites


## Evalua un punto geografico concreto con los campos de la ultima derivacion.
## Sirve para dar atributos a los yacimientos REALES, que no se eligen por
## puntuacion sino porque existen.
func site_at(data: HeightmapData, lon: float, lat: float) -> Site:
	if _coast_dist.is_empty():
		push_error("SiteDeriver: hay que llamar a derive() antes que a site_at()")
		return null

	var u := (lon - data.lon_west) / (data.lon_east - data.lon_west)
	var mn := DEMImporter.mercator_y(data.lat_north)
	var ms := DEMImporter.mercator_y(data.lat_south)
	var v := (DEMImporter.mercator_y(lat) - mn) / (ms - mn)
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return null

	var x := clampi(int(u * float(data.width - 1)), 1, data.width - 2)
	var z := clampi(int(v * float(data.height - 1)), 1, data.height - 2)
	var site := _make_site(data, x, z, 0.0, _coast_dist, _river_dist, _smooth, _km)
	# Las coordenadas mandan las del registro, no las del centro de celda
	site.lon = lon
	site.lat = lat
	return site


func _make_site(data: HeightmapData, x: int, z: int, s: float,
		coast_dist: PackedFloat32Array, river_dist: PackedFloat32Array,
		smooth: PackedFloat32Array, km: float) -> Site:
	var i := z * data.width + x
	var site := Site.new()
	site.cell = Vector2i(x, z)
	site.score = s
	site.elevation = data.elevations[i]
	site.prominence = data.elevations[i] - smooth[i]
	site.coast_km = coast_dist[i] * km
	site.water_km = river_dist[i] * km if not river_dist.is_empty() else 99.0

	var cell_m := data.meters_per_sample
	var dx := (data.get_elevation(x + 1, z) - data.get_elevation(x - 1, z)) / (2.0 * cell_m)
	var dz := (data.get_elevation(x, z + 1) - data.get_elevation(x, z - 1)) / (2.0 * cell_m)
	site.slope_deg = rad_to_deg(atan(sqrt(dx * dx + dz * dz)))

	# Geografia
	var u := float(x) / float(maxi(data.width - 1, 1))
	var v := float(z) / float(maxi(data.height - 1, 1))
	site.lon = lerpf(data.lon_west, data.lon_east, u)
	site.lat = DEMImporter.tile_y_to_lat(lerpf(
		DEMImporter.mercator_y(data.lat_north),
		DEMImporter.mercator_y(data.lat_south), v), 0)

	site.inside_region = data.region_mask.is_empty() or data.region_mask[i] > 0.5

	# Clasificacion de partida, con la costa actual. La definitiva la da
	# Site.kind_at(), que la recalcula con la costa de cada epoca.
	if site.coast_km < 2.0:
		site.kind = Site.Kind.COSTERO
	elif site.prominence > 90.0:
		site.kind = Site.Kind.ALTURA
	elif site.water_km < 1.5 and site.slope_deg < 10.0:
		site.kind = Site.Kind.VALLE
	else:
		site.kind = Site.Kind.INTERIOR

	return site


## Campo de distancia a la costa para una cota del mar dada, en celdas.
## Publico porque el horneado lo necesita para cada epoca: la costa se mueve y
## con ella la clasificacion de cada emplazamiento.
func coast_field(data: HeightmapData, sea_level_m: float) -> PackedFloat32Array:
	return _distance_field(_ocean_mask(data, sea_level_m), data.width, data.height)


## Celdas que son MAR de verdad: por debajo de la cota y conectadas con el
## borde del mapa.
##
## Sembrar el campo de distancia con cualquier celda bajo cero metia dentro
## depresiones interiores y artefactos del DEM: habia 3232 celdas <= 0 m sin
## conexion con el oceano, y cada una convertia en "costero" todo lo que
## tuviera a dos kilometros. Un emplazamiento a 336 m de altitud salia costero
## por una celda de -1 m a 560 metros.
func _ocean_mask(data: HeightmapData, sea_level_m: float) -> PackedByteArray:
	var w := data.width
	var h := data.height
	var n := w * h
	var ocean := PackedByteArray()
	ocean.resize(n)
	var queue := PackedInt32Array()

	for x in range(w):
		for z: int in [0, h - 1]:
			var i := z * w + x
			if data.elevations[i] <= sea_level_m and ocean[i] == 0:
				ocean[i] = 1
				queue.append(i)
	for z in range(h):
		for x: int in [0, w - 1]:
			var i := z * w + x
			if data.elevations[i] <= sea_level_m and ocean[i] == 0:
				ocean[i] = 1
				queue.append(i)

	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x := i % w
		var z := i / w
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx := x + step.x
			var zz := z + step.y
			if xx < 0 or zz < 0 or xx >= w or zz >= h:
				continue
			var j := zz * w + xx
			if ocean[j] == 1 or data.elevations[j] > sea_level_m:
				continue
			ocean[j] = 1
			queue.append(j)

	return ocean


## Transformada de distancia por chamfer en dos pasadas. Devuelve la distancia
## en CELDAS hasta la semilla mas cercana. Es O(n) frente al O(n*m) de buscar
## el vecino mas cercano celda por celda.
func _distance_field(seed: PackedByteArray, w: int, h: int) -> PackedFloat32Array:
	const FAR := 1.0e9
	const D1 := 1.0
	const D2 := 1.41421356

	var d := PackedFloat32Array()
	d.resize(w * h)
	for i in range(w * h):
		d[i] = 0.0 if seed[i] == 1 else FAR

	# Pasada directa: arriba-izquierda hacia abajo-derecha
	for z in range(h):
		var row := z * w
		for x in range(w):
			var i := row + x
			var best := d[i]
			if z > 0:
				best = minf(best, d[i - w] + D1)
				if x > 0:
					best = minf(best, d[i - w - 1] + D2)
				if x < w - 1:
					best = minf(best, d[i - w + 1] + D2)
			if x > 0:
				best = minf(best, d[i - 1] + D1)
			d[i] = best

	# Pasada inversa
	for z in range(h - 1, -1, -1):
		var row := z * w
		for x in range(w - 1, -1, -1):
			var i := row + x
			var best := d[i]
			if z < h - 1:
				best = minf(best, d[i + w] + D1)
				if x > 0:
					best = minf(best, d[i + w - 1] + D2)
				if x < w - 1:
					best = minf(best, d[i + w + 1] + D2)
			if x < w - 1:
				best = minf(best, d[i + 1] + D1)
			d[i] = best

	return d


## Desenfoque de caja separable, para medir el entorno de cada celda
func _box_blur(src: PackedFloat32Array, w: int, h: int, radius: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var window := float(radius * 2 + 1)

	for z in range(h):
		var row := z * w
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += src[row + clampi(x, 0, w - 1)]
		for x in range(w):
			tmp[row + x] = acc / window
			acc -= src[row + clampi(x - radius, 0, w - 1)]
			acc += src[row + clampi(x + radius + 1, 0, w - 1)]

	for x in range(w):
		var acc := 0.0
		for z in range(-radius, radius + 1):
			acc += tmp[clampi(z, 0, h - 1) * w + x]
		for z in range(h):
			out[z * w + x] = acc / window
			acc -= tmp[clampi(z - radius, 0, h - 1) * w + x]
			acc += tmp[clampi(z + radius + 1, 0, h - 1) * w + x]

	return out
