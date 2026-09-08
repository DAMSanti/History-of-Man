@tool
class_name DEMImporter
extends RefCounted
## Importa elevación real desde teselas Terrarium y la deja como [HeightmapData].
##
## Fuente: AWS Terrain Tiles (s3.amazonaws.com/elevation-tiles-prod), que agrega
## SRTM, NASADEM, EU-DEM y batimetría GEBCO en teselas PNG del esquema XYZ
## habitual. No necesita clave de API y su licencia permite uso derivado, al
## contrario que Google Maps, cuyos términos prohíben cachear o reutilizar la
## elevación fuera de un mapa de Google.
##
## Codificación Terrarium: altura_m = (R * 256 + G + B / 256) - 32768

const TILE_HOST := "https://s3.amazonaws.com"
const TILE_PATH := "/elevation-tiles-prod/terrarium/%d/%d/%d.png"
const TILE_SIZE := 256
const CACHE_DIR := "res://data/dem/tiles"

## Radio ecuatorial usado por Web Mercator, para el cálculo de metros por píxel
const EARTH_CIRCUMFERENCE := 40075016.686


## Coordenada X de tesela (fraccionaria) para una longitud dada
static func lon_to_tile_x(lon_deg: float, zoom: int) -> float:
	return (lon_deg + 180.0) / 360.0 * pow(2.0, zoom)


## Coordenada Y de tesela (fraccionaria) para una latitud dada
static func lat_to_tile_y(lat_deg: float, zoom: int) -> float:
	var lat_rad := deg_to_rad(lat_deg)
	return (1.0 - log(tan(lat_rad) + 1.0 / cos(lat_rad)) / PI) / 2.0 * pow(2.0, zoom)


## Longitud del borde oeste de una tesela
static func tile_x_to_lon(x: float, zoom: int) -> float:
	return x / pow(2.0, zoom) * 360.0 - 180.0


## Latitud del borde norte de una tesela
static func tile_y_to_lat(y: float, zoom: int) -> float:
	var n := PI - TAU * y / pow(2.0, zoom)
	return rad_to_deg(atan(sinh(n)))


## Metros de terreno por píxel a una latitud y zoom dados.
## Web Mercator comprime con la latitud, así que esto NO es constante.
static func meters_per_pixel(lat_deg: float, zoom: int) -> float:
	return EARTH_CIRCUMFERENCE * cos(deg_to_rad(lat_deg)) / pow(2.0, zoom + 8)


## Descarga (o recupera de caché) las teselas que cubren el recuadro dado y
## devuelve un HeightmapData ya ensamblado, o null si algo falla.
func import_area(lat_north: float, lat_south: float, lon_west: float, lon_east: float, zoom: int) -> HeightmapData:
	if lat_north <= lat_south or lon_east <= lon_west:
		push_error("DEMImporter: recuadro geográfico inválido")
		return null

	var x_min := int(floor(lon_to_tile_x(lon_west, zoom)))
	var x_max := int(floor(lon_to_tile_x(lon_east, zoom)))
	var y_min := int(floor(lat_to_tile_y(lat_north, zoom)))
	var y_max := int(floor(lat_to_tile_y(lat_south, zoom)))

	var cols := x_max - x_min + 1
	var rows := y_max - y_min + 1
	print("DEMImporter: %d x %d teselas en zoom %d (%d descargas)" % [cols, rows, zoom, cols * rows])

	var width := cols * TILE_SIZE
	var height := rows * TILE_SIZE

	var data := HeightmapData.new()
	data.width = width
	data.height = height
	data.elevations.resize(width * height)

	var min_e := INF
	var max_e := -INF

	for ty in range(rows):
		for tx in range(cols):
			var tile_x := x_min + tx
			var tile_y := y_min + ty
			var image := _fetch_tile(zoom, tile_x, tile_y)
			if image == null:
				push_error("DEMImporter: no se pudo obtener la tesela %d/%d/%d" % [zoom, tile_x, tile_y])
				return null

			var bytes := image.get_data()
			for py in range(TILE_SIZE):
				for px in range(TILE_SIZE):
					var o := (py * TILE_SIZE + px) * 3
					var elevation := float(bytes[o]) * 256.0 + float(bytes[o + 1]) + float(bytes[o + 2]) / 256.0 - 32768.0
					data.elevations[(ty * TILE_SIZE + py) * width + (tx * TILE_SIZE + px)] = elevation
					min_e = minf(min_e, elevation)
					max_e = maxf(max_e, elevation)

	data.min_elevation = min_e
	data.max_elevation = max_e
	data.lat_north = tile_y_to_lat(float(y_min), zoom)
	data.lat_south = tile_y_to_lat(float(y_max + 1), zoom)
	data.lon_west = tile_x_to_lon(float(x_min), zoom)
	data.lon_east = tile_x_to_lon(float(x_max + 1), zoom)
	# La resolución se evalúa en el centro del recuadro: es donde el error de
	# la proyección es menor para el conjunto
	data.meters_per_sample = meters_per_pixel((data.lat_north + data.lat_south) * 0.5, zoom)
	data.source = "AWS Terrain Tiles (terrarium) z%d" % zoom

	return data


## Obtiene una tesela, de la caché local si ya está, y la deja lista en RGB8
func _fetch_tile(zoom: int, x: int, y: int) -> Image:
	var cache_path := "%s/%d_%d_%d.png" % [CACHE_DIR, zoom, x, y]

	if FileAccess.file_exists(cache_path):
		var cached := Image.new()
		if cached.load(cache_path) == OK:
			cached.convert(Image.FORMAT_RGB8)
			return cached

	var body := _http_get(TILE_HOST, TILE_PATH % [zoom, x, y])
	if body.is_empty():
		return null

	var image := Image.new()
	if image.load_png_from_buffer(body) != OK:
		push_error("DEMImporter: la tesela %d/%d/%d no es un PNG válido" % [zoom, x, y])
		return null

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()

	image.convert(Image.FORMAT_RGB8)
	return image


## GET bloqueante con HTTPClient. Se usa HTTPClient y no HTTPRequest porque
## este último necesita estar dentro del árbol de escena, y el importador debe
## poder ejecutarse como herramienta suelta.
func _http_get(host: String, path: String) -> PackedByteArray:
	var http := HTTPClient.new()
	if http.connect_to_host(host, 443) != OK:
		push_error("DEMImporter: no se pudo conectar a " + host)
		return PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(20)

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("DEMImporter: conexión fallida con " + host)
		return PackedByteArray()

	if http.request(HTTPClient.METHOD_GET, path, ["User-Agent: CityBuilder-DEMImporter"]) != OK:
		return PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(20)

	if http.get_response_code() != 200:
		push_error("DEMImporter: HTTP %d en %s" % [http.get_response_code(), path])
		return PackedByteArray()

	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(10)
		else:
			body.append_array(chunk)

	http.close()
	return body


## Calcula la mascara de cauce a partir del DEM y la deja en `data`.
##
## Acumulacion de flujo D8: cada celda vierte su agua a su vecino mas bajo, y
## recorriendo las celdas de mayor a menor cota se acumula rio abajo. Las celdas
## con mucha area drenada son el cauce. Es lo que produce una red dendritica
## real, a diferencia de medir concavidad, que solo encuentra puntos sueltos.
##
## Es caro pero se paga UNA vez al importar y queda guardado en el recurso.
## Para cauces exactos la fuente correcta serian los poligonos de agua de
## OpenStreetMap; esto los deduce del relieve.
func compute_river_mask(data: HeightmapData, fill_passes: int = 20, min_drainage_km2: float = 0.6) -> void:
	var w := data.width
	var h := data.height
	if w <= 2 or h <= 2:
		return

	var n := w * h
	# --- 1. Rellenar depresiones (Planchon-Darboux) ----------------------
	# Un DEM remuestreado esta lleno de hoyos; sin rellenarlos el flujo queda
	# atrapado en cada uno y los rios salen troceados o directamente no
	# acumulan. Bajar cada celda hasta max(original, min(vecino)+eps) desde una
	# superficie inicial muy alta converge en pocas pasadas si se alternan las
	# direcciones de barrido, cosa que un barrido siempre en el mismo sentido
	# no hace: la informacion solo viaja una celda por pasada.
	var elev := _fill_depressions(data.elevations, w, h, fill_passes)

	# --- 2. Ordenar las celdas por cota, de mayor a menor -----------------
	# Counting sort por franjas de altura: O(n), frente al O(n log n) de un
	# sort_custom en GDScript sobre 400.000 elementos.
	const BINS := 4096
	var lo := INF
	var hi := -INF
	for v in elev:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.001)

	var counts := PackedInt32Array()
	counts.resize(BINS)
	var bin_of := PackedInt32Array()
	bin_of.resize(n)
	for i in range(n):
		var b := clampi(int((elev[i] - lo) / span * float(BINS - 1)), 0, BINS - 1)
		bin_of[i] = b
		counts[b] += 1

	var offsets := PackedInt32Array()
	offsets.resize(BINS)
	var running := 0
	for b in range(BINS):
		offsets[b] = running
		running += counts[b]

	var order := PackedInt32Array()
	order.resize(n)
	var cursor := offsets.duplicate()
	for i in range(n):
		var b := bin_of[i]
		order[cursor[b]] = i
		cursor[b] += 1

	# --- 3. Acumular caudal de arriba hacia abajo -------------------------
	var accum := PackedFloat32Array()
	accum.resize(n)
	accum.fill(1.0)

	var neighbours := [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]
	for k in range(n - 1, -1, -1):
		var i: int = order[k]
		var x := i % w
		var z := i / w
		# Los bordes se dejan fuera: no tienen los 8 vecinos y el agua sale del mapa
		if x == 0 or z == 0 or x == w - 1 or z == h - 1:
			continue

		var here := elev[i]
		var best := -1
		var best_drop := 0.0
		for d: int in neighbours:
			var j := i + d
			var drop := here - elev[j]
			if drop > best_drop:
				best_drop = drop
				best = j
		if best >= 0:
			accum[best] += accum[i]

	# --- 4. Convertir el caudal en mascara --------------------------------
	# El umbral es AREA DRENADA real, no una fraccion del maximo. Con la
	# fraccion del maximo pasaba el corte cualquier barranquera y la mascara
	# salia moteada; un cauce se define por cuanta cuenca recoge.
	var peak_accum := 0.0
	for a in accum:
		peak_accum = maxf(peak_accum, a)

	var cell_area_km2 := (data.meters_per_sample * data.meters_per_sample) / 1000000.0
	print("DEMImporter: cuenca maxima acumulada %d celdas = %.2f km2" % [
		int(peak_accum), peak_accum * cell_area_km2])
	var threshold_cells := maxf(min_drainage_km2 / maxf(cell_area_km2, 0.000001), 1.0)

	var mask := PackedFloat32Array()
	mask.resize(n)
	for i in range(n):
		# El cauce se ensancha de forma continua segun crece la cuenca
		mask[i] = smoothstep(threshold_cells, threshold_cells * 4.0, accum[i])

	print("DEMImporter: umbral de cauce %.2f km2 = %d celdas drenadas" % [
		min_drainage_km2, int(threshold_cells)])

	# Ensanchar y suavizar: a 13.9 m por muestra un cauce de una celda es
	# invisible en pantalla, y el borde dentado canta mucho.
	var wide := _box_blur(mask, w, h, 2)
	for i in range(n):
		wide[i] = clampf(wide[i] * 3.0, 0.0, 1.0)
	data.river_mask = _box_blur(wide, w, h, 1)


## Desenfoque de caja separable con sumas corridas: O(n) independientemente del
## radio, que es lo que lo hace viable sobre cientos de miles de muestras.
func _box_blur(src: PackedFloat32Array, w: int, h: int, radius: int) -> PackedFloat32Array:
	if radius <= 0:
		return src.duplicate()

	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)

	# Horizontal
	for z in range(h):
		var row := z * w
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += src[row + clampi(x, 0, w - 1)]
		for x in range(w):
			tmp[row + x] = acc / float(radius * 2 + 1)
			acc -= src[row + clampi(x - radius, 0, w - 1)]
			acc += src[row + clampi(x + radius + 1, 0, w - 1)]

	# Vertical
	for x in range(w):
		var acc := 0.0
		for z in range(-radius, radius + 1):
			acc += tmp[clampi(z, 0, h - 1) * w + x]
		for z in range(h):
			out[z * w + x] = acc / float(radius * 2 + 1)
			acc -= tmp[clampi(z - radius, 0, h - 1) * w + x]
			acc += tmp[clampi(z + radius + 1, 0, h - 1) * w + x]

	return out


## Rellena depresiones con el algoritmo de Planchon-Darboux.
## Devuelve una superficie donde toda celda tiene salida hacia el borde del
## mapa. La original NO se toca: es la que dibuja el terreno.
func _fill_depressions(source: PackedFloat32Array, w: int, h: int, max_passes: int) -> PackedFloat32Array:
	const EPS := 0.01
	var n := w * h
	var filled := PackedFloat32Array()
	filled.resize(n)

	# Se arranca de una superficie "inundada" y se va bajando. El borde se
	# queda en su cota real: es por donde el agua sale del mapa.
	var high := 0.0
	for v in source:
		high = maxf(high, v)
	high += 1000.0

	for z in range(h):
		var row := z * w
		for x in range(w):
			if x == 0 or z == 0 or x == w - 1 or z == h - 1:
				filled[row + x] = source[row + x]
			else:
				filled[row + x] = high

	var neighbours := [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]
	var passes_used := 0

	for pass_index in range(max_passes):
		var changed := 0
		# Alternar el sentido del barrido en cada pasada para que la
		# informacion se propague en ambas direcciones
		var forward := pass_index % 2 == 0

		for zi in range(1, h - 1):
			var z := zi if forward else h - 1 - zi
			if z <= 0 or z >= h - 1:
				continue
			var row := z * w
			for xi in range(1, w - 1):
				var x := xi if forward else w - 1 - xi
				var i := row + x
				var original := source[i]
				if filled[i] <= original:
					continue

				for d: int in neighbours:
					var candidate: float = filled[i + d] + EPS
					if original >= candidate:
						filled[i] = original
						changed += 1
						break
					if filled[i] > candidate:
						filled[i] = candidate
						changed += 1

		passes_used = pass_index + 1
		if changed == 0:
			break

	print("DEMImporter: depresiones rellenadas en %d pasadas" % passes_used)
	return filled


## Coordenada Y de Mercator normalizada (0 = norte, 1 = sur) para una latitud.
## Es lat_to_tile_y a zoom 0, y sirve para relacionar dos DEM cualesquiera:
## en Mercator la rejilla de teselas es lineal en esta coordenada, no en la
## latitud, asi que interpolar sobre lat directamente introduce error.
static func mercator_y(lat_deg: float) -> float:
	return lat_to_tile_y(lat_deg, 0)


## Lleva la mascara de cauce de un DEM amplio a otro mas fino y contenido en el.
##
## Hace falta porque la acumulacion de flujo solo cuenta las celdas que estan
## DENTRO del DEM. Un rio que entra en el recuadro ya crecido (el Besaya entra
## en la ventana desde el sur) recibe un area drenada ridicula, mientras que un
## arroyo que nace y muere dentro acumula toda su cuenca: el arroyo pasa el
## umbral y el rio principal no. Calculando el drenaje sobre la cuenca entera y
## transfiriendo el resultado, cada cauce recibe el caudal que le corresponde.
func transfer_river_mask(source: HeightmapData, target: HeightmapData) -> void:
	if source.river_mask.is_empty() or target.width <= 0 or target.height <= 0:
		push_error("DEMImporter: no hay mascara de origen o el destino es invalido")
		return

	var src_lon_span := source.lon_east - source.lon_west
	var src_y_north := mercator_y(source.lat_north)
	var src_y_south := mercator_y(source.lat_south)
	var src_y_span := src_y_south - src_y_north
	if absf(src_lon_span) < 1e-9 or absf(src_y_span) < 1e-9:
		push_error("DEMImporter: el DEM de origen no tiene extension valida")
		return

	var tgt_y_north := mercator_y(target.lat_north)
	var tgt_y_south := mercator_y(target.lat_south)

	var mask := PackedFloat32Array()
	mask.resize(target.width * target.height)

	var outside := 0
	for z in range(target.height):
		var v := float(z) / float(maxi(target.height - 1, 1))
		var merc_y: float = lerpf(tgt_y_north, tgt_y_south, v)
		var sv := (merc_y - src_y_north) / src_y_span
		var row := z * target.width

		for x in range(target.width):
			var u := float(x) / float(maxi(target.width - 1, 1))
			var lon: float = lerpf(target.lon_west, target.lon_east, u)
			var su := (lon - source.lon_west) / src_lon_span

			if su < 0.0 or su > 1.0 or sv < 0.0 or sv > 1.0:
				outside += 1
				mask[row + x] = 0.0
			else:
				mask[row + x] = source.sample_river_mask(su, sv)

	target.river_mask = mask
	if outside > 0:
		push_warning("DEMImporter: %d muestras del destino caen fuera del DEM de origen" % outside)
	print("DEMImporter: mascara transferida (%d x %d desde %d x %d)" % [
		target.width, target.height, source.width, source.height])


## Corrige picos y valores basura del DEM. Devuelve cuantas celdas ha tocado.
##
## Las teselas terrarium traen artefactos puntuales: al importar Cantabria
## aparecio una franja vertical con +4416 m pegada a -1783 m, cotas que no
## existen en la peninsula. Un solo pico envenena todo lo que dependa del rango
## de elevacion: la normalizacion del color, las bandas del shader y el relleno
## de depresiones.
##
## Se sustituye por la mediana de sus 8 vecinos toda celda que se aparte de
## ella mas de `threshold`. La mediana y no la media porque los artefactos
## suelen venir en franjas de varias celdas, y la media se contamina. El umbral
## alto solo caza basura: ningun relieve real sube 400 m entre dos muestras
## separadas 112 m.
func despike(data: HeightmapData, threshold: float = 400.0, passes: int = 2) -> int:
	var w := data.width
	var h := data.height
	if w < 3 or h < 3:
		return 0

	var total_fixed := 0
	var offsets := [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]
	var ring := []
	ring.resize(8)

	for pass_index in range(passes):
		var fixed := 0
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				for k in range(8):
					ring[k] = data.elevations[i + offsets[k]]
				ring.sort()
				var median: float = (ring[3] + ring[4]) * 0.5
				if absf(data.elevations[i] - median) > threshold:
					data.elevations[i] = median
					fixed += 1
		total_fixed += fixed
		if fixed == 0:
			break

	# El rango guardado deja de ser valido tras corregir
	var mn := INF
	var mx := -INF
	for e in data.elevations:
		mn = minf(mn, e)
		mx = maxf(mx, e)
	data.min_elevation = mn
	data.max_elevation = mx

	return total_fixed
