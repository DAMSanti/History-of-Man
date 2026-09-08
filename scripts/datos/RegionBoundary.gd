@tool
class_name RegionBoundary
extends Resource
## Frontera administrativa en coordenadas geograficas, para delimitar la zona
## jugable sobre el mapa regional.
##
## El DEM se importa por recuadros de teselas, que nunca coinciden con una
## frontera real: el recuadro de Cantabria se come trozos de Asturias, Leon,
## Palencia, Burgos y Vizcaya, y ademas hay que extenderlo mar adentro para que
## quepa la linea de costa glacial. Esta clase separa "lo que hay en el DEM" de
## "lo que es Cantabria".
##
## Los puntos van como Vector2(x = longitud, y = latitud), en grados.

@export var region_name: String = ""
@export var source: String = ""

## Anillos del poligono. El primero es el contorno principal; los demas son
## islas o enclaves — Cantabria tiene uno real, el Valle de Villaverde.
@export var rings: Array[PackedVector2Array] = []

@export var lon_min: float = 0.0
@export var lon_max: float = 0.0
@export var lat_min: float = 0.0
@export var lat_max: float = 0.0


## Carga la frontera desde el volcado JSON generado a partir de OpenStreetMap
static func from_json(path: String) -> RegionBoundary:
	if not FileAccess.file_exists(path):
		push_error("RegionBoundary: no existe " + path)
		return null

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RegionBoundary: JSON invalido en " + path)
		return null

	var boundary := RegionBoundary.new()
	boundary.region_name = parsed.get("name", "")
	boundary.source = parsed.get("source", "")
	boundary.lon_min = parsed.get("lon_min", 0.0)
	boundary.lon_max = parsed.get("lon_max", 0.0)
	boundary.lat_min = parsed.get("lat_min", 0.0)
	boundary.lat_max = parsed.get("lat_max", 0.0)

	for flat: Array in parsed.get("rings", []):
		var ring := PackedVector2Array()
		ring.resize(flat.size() / 2)
		for i in range(ring.size()):
			ring[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
		boundary.rings.append(ring)

	return boundary


## Numero total de vertices, sumando todos los anillos
func point_count() -> int:
	var total := 0
	for ring in rings:
		total += ring.size()
	return total


## Rasteriza la frontera sobre la rejilla de un heightmap.
## Devuelve 1.0 dentro de la region y 0.0 fuera, con el borde suavizado.
##
## Se hace por barrido de lineas y no punto a punto porque comprobar un millon
## de vertices contra 630 aristas seria inviable: aqui es una pasada por fila.
## La latitud de cada fila se interpola en Y de MERCATOR, no en grados, porque
## asi es como esta muestreado el DEM.
func rasterize(data: HeightmapData, feather_cells: int = 2) -> PackedFloat32Array:
	var w := data.width
	var h := data.height
	var mask := PackedFloat32Array()
	mask.resize(w * h)

	if rings.is_empty() or w <= 0 or h <= 0:
		return mask

	var merc_north := DEMImporter.mercator_y(data.lat_north)
	var merc_south := DEMImporter.mercator_y(data.lat_south)
	var lon_span := data.lon_east - data.lon_west
	if absf(lon_span) < 1e-9:
		return mask

	var crossings := PackedFloat32Array()

	for z in range(h):
		var v := float(z) / float(maxi(h - 1, 1))
		var lat := DEMImporter.tile_y_to_lat(lerpf(merc_north, merc_south, v), 0)

		crossings.clear()
		for ring: PackedVector2Array in rings:
			var count := ring.size()
			for i in range(count):
				var a := ring[i]
				var b := ring[(i + 1) % count]
				# La arista cruza esta latitud
				if (a.y > lat) != (b.y > lat):
					var t := (lat - a.y) / (b.y - a.y)
					crossings.append(a.x + t * (b.x - a.x))

		if crossings.is_empty():
			continue

		var sorted := Array(crossings)
		sorted.sort()

		var row := z * w
		# Regla par-impar: se rellena entre pares consecutivos de cruces
		var pair := 0
		while pair + 1 < sorted.size():
			var lon_a: float = sorted[pair]
			var lon_b: float = sorted[pair + 1]
			var x0 := int(ceil((lon_a - data.lon_west) / lon_span * float(w - 1)))
			var x1 := int(floor((lon_b - data.lon_west) / lon_span * float(w - 1)))
			for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
				mask[row + x] = 1.0
			pair += 2

	if feather_cells > 0:
		mask = _feather(mask, w, h, feather_cells)

	return mask


## Suaviza el borde para que la transicion no quede en escalera
func _feather(mask: PackedFloat32Array, w: int, h: int, radius: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var window := float(radius * 2 + 1)

	for z in range(h):
		var row := z * w
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += mask[row + clampi(x, 0, w - 1)]
		for x in range(w):
			tmp[row + x] = acc / window
			acc -= mask[row + clampi(x - radius, 0, w - 1)]
			acc += mask[row + clampi(x + radius + 1, 0, w - 1)]

	for x in range(w):
		var acc := 0.0
		for z in range(-radius, radius + 1):
			acc += tmp[clampi(z, 0, h - 1) * w + x]
		for z in range(h):
			out[z * w + x] = acc / window
			acc -= tmp[clampi(z - radius, 0, h - 1) * w + x]
			acc += tmp[clampi(z + radius + 1, 0, h - 1) * w + x]

	return out


## Construye la mascara de area jugable para una cota del mar concreta.
##
## La frontera NO es fija: el territorio de cada epoca es Cantabria mas la
## tierra que este emergida entonces. Con el mar actual no emerge nada y la
## mascara es exactamente la frontera administrativa.
##
## El crecimiento es una inundacion por vecindad sobre el fondo marino que
## emerge, no una proyeccion recta: asi el contorno lo dibuja la batimetria y
## sale con la forma quebrada de una costa real.
func build_playable_mask(data: HeightmapData, sea_level_m: float, reach_km: float = 60.0) -> PackedFloat32Array:
	var mask := rasterize(data)
	var w := data.width
	var h := data.height
	var n := w * h

	if sea_level_m >= 0.0:
		return mask

	# --- 1. cerrar la costura con la costa -----------------------------
	# El poligono administrativo y la isobata 0 del DEM no coinciden a 111 m
	# por muestra, asi que entre ambos queda un anillo de celdas con cota
	# positiva que no pertenece a ninguno de los dos. Sin cerrarlo aparece una
	# segunda frontera en vez de una ampliada.
	_dilate_shoreline(mask, data, 4, 30.0)

	# --- 2. limites laterales, medidos en la COSTA ---------------------
	# No sirve el lon_min del poligono: el punto mas occidental de Cantabria
	# esta tierra adentro, en Liebana, y usarlo hace que la plataforma se
	# extienda por delante de Asturias.
	var coast := _coastal_x_range(mask, data)
	var x_min: int = coast.x
	var x_max: int = coast.y
	if x_max <= x_min:
		return mask

	# --- 3. inundacion con alcance irregular ---------------------------
	# Donde manda la batimetria el contorno ya sale quebrado. Donde el limite
	# lo pone la distancia saldria un arco liso, asi que el alcance se modula
	# con ruido y se afila hacia los extremos laterales.
	# Dos escalas de ruido: una ancha que mete entrantes y salientes de varios
	# kilometros, y otra fina que rompe el borde a escala de cientos de metros.
	# Con una sola octava lenta el limite salia escalonado, no quebrado.
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.3
	noise.fractal_gain = 0.55
	noise.seed = 20250902

	var detail := FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = 0.055
	detail.fractal_octaves = 3
	detail.seed = 771

	var reach_cells := reach_km * 1000.0 / data.meters_per_sample
	var taper := float(x_max - x_min) * 0.12

	var dist := PackedInt32Array()
	dist.resize(n)
	var queue := PackedInt32Array()
	for i in range(n):
		if mask[i] > 0.5:
			dist[i] = 0
			queue.append(i)
		else:
			dist[i] = -1

	var head := 0
	var added := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var d := dist[i]
		var x := i % w
		var z := i / w

		# Alcance permitido en este punto
		var edge: float = minf(float(x - x_min), float(x_max - x)) / maxf(taper, 1.0)
		var wide: float = noise.get_noise_2d(float(x), float(z)) * 0.5 + 0.5
		var fine: float = detail.get_noise_2d(float(x), float(z)) * 0.5 + 0.5
		var allowed := reach_cells * clampf(edge, 0.0, 1.0) 			* (0.55 + 0.70 * wide) * (0.82 + 0.36 * fine)
		if float(d) >= allowed:
			continue

		for dz: int in [-1, 0, 1]:
			var zz := z + dz
			if zz < 0 or zz >= h:
				continue
			for dx: int in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var xx := x + dx
				if xx < x_min or xx > x_max:
					continue
				var j := zz * w + xx
				if dist[j] != -1:
					continue
				# Solo fondo marino que emerge a esta cota
				var e: float = data.elevations[j]
				if e <= sea_level_m or e > 0.0:
					continue
				dist[j] = d + 1
				mask[j] = 1.0
				queue.append(j)
				added += 1

	# Cierre morfologico: dilatar y volver a erosionar. Cierra la costura entre
	# la tierra y la plataforma sin cambiar la silueta. Hace falta porque la
	# costa cantabrica tiene acantilados de mas de 30 m justo fuera del poligono
	# que el ensanchado litoral no alcanza, y quedaban como un anillo huerfano
	# que se dibujaba como una segunda frontera.
	_close_gaps(mask, w, h, 5)

	# Rellenar huecos cerrados. Los islotes y roquedos tienen cota POSITIVA, asi
	# que la inundacion los salta -solo admite fondo marino que emerge- y quedan
	# como agujeros rodeados de territorio. Si el fondo alrededor esta seco, el
	# islote tambien lo esta. Se rellena por conectividad y no por tamano, para
	# que valga sea cual sea la razon del hueco.
	var filled := _fill_holes(mask, w, h)

	print("RegionBoundary: %d celdas de islote o hueco interior rellenadas" % filled)
	print("RegionBoundary: mar %+.0f m -> %d celdas emergidas, costa entre las columnas %d y %d" % [
		sea_level_m, added, x_min, x_max])
	return mask


## Dilata y erosiona la misma cantidad: cierra huecos y costuras estrechas
## dejando el contorno exterior donde estaba.
func _close_gaps(mask: PackedFloat32Array, w: int, h: int, radius: int) -> void:
	for step in range(radius):
		var grow: Array[int] = []
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				if mask[i] > 0.5:
					continue
				if mask[i - 1] > 0.5 or mask[i + 1] > 0.5 or mask[i - w] > 0.5 or mask[i + w] > 0.5:
					grow.append(i)
		for i: int in grow:
			mask[i] = 1.0

	for step in range(radius):
		var shrink: Array[int] = []
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				if mask[i] <= 0.5:
					continue
				if mask[i - 1] <= 0.5 or mask[i + 1] <= 0.5 or mask[i - w] <= 0.5 or mask[i + w] <= 0.5:
					shrink.append(i)
		for i: int in shrink:
			mask[i] = 0.0


## Ensancha la mascara unas celdas sobre la franja litoral, para que el borde
## del poligono administrativo y la isobata 0 del DEM se solapen.
func _dilate_shoreline(mask: PackedFloat32Array, data: HeightmapData, passes: int, max_elev: float) -> void:
	var w := data.width
	var h := data.height
	for pass_index in range(passes):
		var grow: Array[int] = []
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				if mask[i] > 0.5 or data.elevations[i] > max_elev:
					continue
				if mask[i - 1] > 0.5 or mask[i + 1] > 0.5 						or mask[i - w] > 0.5 or mask[i + w] > 0.5:
					grow.append(i)
		for i: int in grow:
			mask[i] = 1.0


## Rango de columnas donde la region toca el mar
func _coastal_x_range(mask: PackedFloat32Array, data: HeightmapData) -> Vector2i:
	var w := data.width
	var h := data.height
	var lo := w
	var hi := -1
	for z in range(1, h - 1):
		var row := z * w
		for x in range(1, w - 1):
			var i := row + x
			if mask[i] <= 0.5:
				continue
			if data.elevations[i - 1] <= 0.0 or data.elevations[i + 1] <= 0.0 					or data.elevations[i - w] <= 0.0 or data.elevations[i + w] <= 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return Vector2i(lo, hi)


## Rellena todo hueco que no conecte con el exterior del mapa.
##
## Se inunda el EXTERIOR desde los bordes sobre las celdas que no son region;
## lo que la inundacion no alcanza esta encerrado y por tanto es un hueco.
## Devuelve cuantas celdas se han rellenado.
func _fill_holes(mask: PackedFloat32Array, w: int, h: int) -> int:
	var n := w * h
	var outside := PackedByteArray()
	outside.resize(n)
	var queue := PackedInt32Array()

	for x in range(w):
		for z: int in [0, h - 1]:
			var i := z * w + x
			if mask[i] <= 0.5 and outside[i] == 0:
				outside[i] = 1
				queue.append(i)
	for z in range(h):
		for x: int in [0, w - 1]:
			var i := z * w + x
			if mask[i] <= 0.5 and outside[i] == 0:
				outside[i] = 1
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
			if outside[j] == 1 or mask[j] > 0.5:
				continue
			outside[j] = 1
			queue.append(j)

	var filled := 0
	for i in range(n):
		if mask[i] <= 0.5 and outside[i] == 0:
			mask[i] = 1.0
			filled += 1
	return filled
