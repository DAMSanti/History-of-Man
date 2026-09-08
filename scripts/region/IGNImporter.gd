@tool
class_name IGNImporter
extends RefCounted
## Importa elevación del MDT del IGN a 5 metros, vía su servicio WCS.
##
## Terrarium da una muestra cada 13,9 m con cotas en metros ENTEROS. Esto da
## una cada 5 m con precisión centimétrica, porque viene de LiDAR. Es unas
## ocho veces más muestras y, sobre todo, relieve de verdad en vez de una
## interpolación suave: es la mayor mejora disponible para el mapa de detalle
## y no cuesta un solo frame, porque la malla sigue teniendo los mismos
## vértices.
##
## Se pide en `application/asc` -rejilla ASCII, texto plano- a propósito: el
## servicio también sirve GeoTIFF, pero parsear GeoTIFF en GDScript sería
## meterse en un decodificador entero para nada.
##
## Fuente: Instituto Geográfico Nacional / CNIG, servicio INSPIRE de elevación.

const HOST := "https://servicios.idee.es"
const PATH := "/wcs-inspire/mdt"

## Cobertura de 5 m en EPSG:4258, que a efectos prácticos es lat/lon WGS84.
## Se elige esa y no la proyectada para no tener que reproyectar nada.
const COVERAGE := "Elevacion4258_5"

## Metros por muestra del destino. Cuadrada, a diferencia de la rejilla de
## origen: en grados, una celda cuadrada NO es cuadrada en metros.
const TARGET_METERS := 5.0

## Grados de latitud por metro, y de longitud por metro a la latitud dada
const DEG_PER_METER_LAT := 1.0 / 111320.0


static func deg_per_meter_lon(lat_deg: float) -> float:
	return 1.0 / (111320.0 * cos(deg_to_rad(lat_deg)))


## Descarga el recuadro y lo devuelve como HeightmapData de celda cuadrada.
## Devuelve null si el servicio falla.
## `target_meters` es el paso de la rejilla que se guarda. Por defecto los 5 m
## del propio MDT; para el contorno del mapa se pide mas grueso, porque ahi la
## malla muestrea cada 32 m y guardar a 5 serian veinte millones de cotas para
## un detalle que no se llega a dibujar.
##
## El DATO es el mismo en los dos casos: MDT05 del IGN, LiDAR. Lo que cambia es
## cuanto se guarda de el.
func import_area(lat_north: float, lat_south: float,
		lon_west: float, lon_east: float,
		target_meters: float = TARGET_METERS) -> HeightmapData:
	var query := "?service=WCS&version=2.0.1&request=GetCoverage" \
		+ "&coverageId=" + COVERAGE \
		+ "&subset=lat(%.6f,%.6f)" % [lat_south, lat_north] \
		+ "&subset=long(%.6f,%.6f)" % [lon_west, lon_east] \
		+ "&format=application/asc"

	var body := _http_get(HOST, PATH + query)
	if body.is_empty():
		push_error("IGNImporter: el servicio no devolvio datos")
		return null

	return _parse_ascii_grid(body.get_string_from_utf8(), target_meters)


## Convierte la rejilla ASCII del IGN en un HeightmapData de celda cuadrada.
##
## El origen viene en GRADOS, y una celda cuadrada en grados no lo es en
## metros: a 43° de latitud, 0,000045° son 5,0 m en latitud pero solo 3,7 m en
## longitud. Se remuestrea a celda cuadrada para que el resto del motor -que
## asume metros por muestra escalar- siga funcionando sin tocarlo.
func _parse_ascii_grid(text: String, target_meters: float = TARGET_METERS) -> HeightmapData:
	var header := {}
	var values := PackedFloat32Array()
	var expected := 0

	for line in text.split("\n", false):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("--") or trimmed.begins_with("Content"):
			continue

		var parts := trimmed.split(" ", false)
		# Cabecera: clave y un solo valor
		if parts.size() == 2 and not parts[0].is_valid_float():
			header[parts[0].to_lower()] = parts[1].to_float()
			continue

		if header.has("ncols") and expected == 0:
			expected = int(header["ncols"]) * int(header.get("nrows", 0))

		# Se acumula sin reservar: reservar primero y anadir despues dejaba el
		# array lleno de ceros y la condicion de corte nunca dejaba entrar un
		# solo valor, con lo que todo el recuadro salia a cota cero.
		for token in parts:
			if token.is_valid_float():
				values.append(token.to_float())

	if not header.has("ncols") or not header.has("nrows"):
		push_error("IGNImporter: cabecera de rejilla ASCII no reconocida")
		return null

	var cols := int(header["ncols"])
	var rows := int(header["nrows"])
	var cell := float(header["cellsize"])
	var lon_west: float = header["xllcorner"]
	var lat_south: float = header["yllcorner"]
	var lon_east := lon_west + float(cols) * cell
	var lat_north := lat_south + float(rows) * cell
	var nodata: float = header.get("nodata_value", -9999.0)

	var source := values
	if source.size() < cols * rows:
		push_error("IGNImporter: faltan datos (%d de %d)" % [source.size(), cols * rows])
		return null
	if source.size() > cols * rows:
		source = source.slice(source.size() - cols * rows)

	# --- remuestreo a celda cuadrada ------------------------------------
	var lat_mid := (lat_north + lat_south) * 0.5
	var width_m := (lon_east - lon_west) / deg_per_meter_lon(lat_mid)
	var height_m := (lat_north - lat_south) / DEG_PER_METER_LAT
	var step := maxf(target_meters, 1.0)
	var out_w := maxi(int(width_m / step), 2)
	var out_h := maxi(int(height_m / step), 2)

	var data := HeightmapData.new()
	data.width = out_w
	data.height = out_h
	data.elevations.resize(out_w * out_h)
	data.lon_west = lon_west
	data.lon_east = lon_east
	data.lat_north = lat_north
	data.lat_south = lat_south
	data.meters_per_sample = step
	data.geographic_rows = true
	data.source = "IGN/CNIG MDT05 (LiDAR) via WCS INSPIRE"

	var min_e := INF
	var max_e := -INF
	for z in range(out_h):
		var v := float(z) / float(out_h - 1)
		for x in range(out_w):
			var u := float(x) / float(out_w - 1)
			# La rejilla ASCII empieza por la fila NORTE, igual que la nuestra
			var sx := u * float(cols - 1)
			var sz := v * float(rows - 1)
			var e := _bilinear(source, cols, rows, sx, sz, nodata)
			data.elevations[z * out_w + x] = e
			min_e = minf(min_e, e)
			max_e = maxf(max_e, e)

	data.min_elevation = min_e
	data.max_elevation = max_e
	return data


func _bilinear(grid: PackedFloat32Array, cols: int, rows: int,
		x: float, z: float, nodata: float) -> float:
	var x0 := clampi(int(floor(x)), 0, cols - 1)
	var z0 := clampi(int(floor(z)), 0, rows - 1)
	var x1 := mini(x0 + 1, cols - 1)
	var z1 := mini(z0 + 1, rows - 1)
	var tx := x - float(x0)
	var tz := z - float(z0)

	var a := _at(grid, cols, x0, z0, nodata)
	var b := _at(grid, cols, x1, z0, nodata)
	var c := _at(grid, cols, x0, z1, nodata)
	var d := _at(grid, cols, x1, z1, nodata)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _at(grid: PackedFloat32Array, cols: int, x: int, z: int, nodata: float) -> float:
	var index := z * cols + x
	if index < 0 or index >= grid.size():
		return 0.0
	var value := grid[index]
	# El mar y los huecos vienen como nodata; se tratan como cota cero
	return 0.0 if value <= nodata + 0.001 else value


## GET bloqueante. Mismo motivo que en DEMImporter: HTTPRequest necesita estar
## en el arbol de escena y esto debe poder correr como herramienta suelta.
func _http_get(host: String, path: String) -> PackedByteArray:
	var http := HTTPClient.new()
	if http.connect_to_host(host, 443) != OK:
		push_error("IGNImporter: no se pudo conectar a " + host)
		return PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(20)

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("IGNImporter: conexion fallida")
		return PackedByteArray()

	if http.request(HTTPClient.METHOD_GET, path, ["User-Agent: CityBuilder/1.0"]) != OK:
		return PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(20)

	if http.get_response_code() != 200:
		push_error("IGNImporter: HTTP %d" % http.get_response_code())
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
