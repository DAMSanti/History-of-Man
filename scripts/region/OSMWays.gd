@tool
class_name OSMWays
extends RefCounted
## Descarga de OpenStreetMap la obra humana que deforma el relieve.
##
## El MDT del IGN viene de LiDAR y es fiel: si hay una carretera, la carretera
## ESTA en la malla, con su desmonte y su terraplen. Para un juego que empieza
## en el Paleolitico eso es un anacronismo tallado en el terreno.
##
## Aqui solo se piden las geometrias. Recortarlas y reconstruir la ladera lo
## hace [TerrainInpainter], que no depende de la red y por eso se puede probar.
##
## Fuente: OpenStreetMap (ODbL), via la API Overpass.

const HOST := "https://overpass-api.de"
const PATH := "/api/interpreter"

## Semiancho de borrado por clase de via, en metros. NO es el ancho del asfalto
## sino el de la obra: una carretera de monte de 5 m de calzada arrastra
## cuneta, desmonte y terraplen, y si solo borras la calzada te quedas con las
## dos cicatrices a los lados, que es peor que dejarlo como estaba.
##
## Los senderos van a cero a proposito: no mueven tierra, y borrarlos seria
## inventar relieve a cambio de nada.
const ROAD_WIDTHS := {
	"motorway": 22.0, "motorway_link": 16.0,
	"trunk": 20.0, "trunk_link": 14.0,
	"primary": 15.0, "primary_link": 11.0,
	"secondary": 13.0, "secondary_link": 10.0,
	"tertiary": 11.0, "tertiary_link": 9.0,
	# Las de pueblo. Son la inmensa mayoria de lo que hay en un recuadro de
	# 4 km en Cantabria y el motivo de que esto exista.
	"residential": 9.0,
	"unclassified": 9.0,
	"living_street": 8.0,
	"service": 7.0,
	"track": 6.0,
	"road": 9.0,
	"busway": 10.0,
	# Sin huella en un MDT de 5 m
	"footway": 0.0, "path": 0.0, "steps": 0.0, "cycleway": 0.0,
	"bridleway": 0.0, "corridor": 0.0, "pedestrian": 0.0,
}

const RAIL_WIDTHS := {
	"rail": 15.0, "light_rail": 11.0, "narrow_gauge": 11.0,
	"tram": 8.0, "subway": 0.0, "abandoned": 8.0, "disused": 8.0,
	"funicular": 8.0, "preserved": 10.0,
	# Las estaciones vienen como area
	"station": 20.0, "platform": 8.0,
}

## Areas: canteras, escombreras, presas y explanaciones. Se rellenan por dentro
## en vez de trazarse, porque lo alterado es toda la superficie.
## Superficies que NO son relieve natural y hay que reconstruir.
##
## Las urbanas se añadieron al abrir Torrelavega en el mapa de detalle: el
## MDT del IGN es fiel al suelo de HOY, y el suelo de hoy en una ciudad lleva
## dos siglos allanado y aterrazado. Sale una meseta con escalones rectos que
## no se parece en nada a la vega que había.
##
## Se piden los POLÍGONOS de uso del suelo y no los edificios: los edificios
## en un pueblo son decenas de miles de vías y además el MDT05 ya es un
## modelo del terreno, no de la superficie, así que los tejados no están. Lo
## que está es el allanado, y eso es lo que cubre el polígono.
const AREA_TAGS := [
	["landuse", "quarry"],
	["landuse", "landfill"],
	["man_made", "embankment"],
	["waterway", "dam"],
	["landuse", "residential"],
	["landuse", "industrial"],
	["landuse", "commercial"],
	["landuse", "retail"],
	["landuse", "construction"],
	["aeroway", "aerodrome"],
]


## Semiancho de la lamina de agua por clase de cauce, en metros.
##
## Los canales, acequias y tuberias forzadas van a cero: son obra del XIX y el
## XX -aqui, el Canal de Celis y la central hidroelectrica- y en un mapa que
## empieza en el Paleolitico no pueden salir pintados como rios.
const CHANNEL_WIDTHS := {
	"river": 11.0,
	"stream": 3.5,
	"tidal_channel": 9.0,
	"brook": 2.5,
	# Artificial: no es agua natural
	"canal": 0.0, "ditch": 0.0, "drain": 0.0, "penstock": 0.0,
	"pressurised": 0.0, "fish_pass": 0.0, "dam": 0.0, "weir": 0.0,
	"lock_gate": 0.0, "sluice_gate": 0.0, "waterfall": 0.0,
}

## Laminas cerradas que cuentan como agua natural. Un embalse queda fuera por
## el mismo motivo que un canal, y ademas su cota es la que le da la presa.
##
## `pond` tambien queda fuera, aunque suene natural: en OSM una charca es casi
## siempre artificial -balsa de riego, abrevadero, camara de carga- y en este
## recuadro lo es literalmente, porque la unica que hay es el deposito de la
## central hidroelectrica de Celis. Una charca de verdad viene como `lake`.
const NATURAL_WATER := ["lake", "river", "oxbow", "lagoon", "stream_pool"]


static func channel_width_for(kind: String) -> float:
	# Una clase desconocida se trata como arroyo menor: mas vale un hilo de
	# agua de menos que inventarse un rio donde hay una acequia
	return CHANNEL_WIDTHS.get(kind, 2.0)


static func is_natural_water_body(water_kind: String) -> bool:
	# Sin etiqueta `water=` concreta, un `natural=water` es una lamina natural
	return water_kind.is_empty() or NATURAL_WATER.has(water_kind)


static func half_width_for(kind: String) -> float:
	if ROAD_WIDTHS.has(kind):
		return ROAD_WIDTHS[kind]
	if RAIL_WIDTHS.has(kind):
		return RAIL_WIDTHS[kind]
	# Una clase que no conocemos es casi siempre una via menor: mejor borrarla
	# con un ancho conservador que dejar una cicatriz en el terreno.
	return 8.0


## Pide el recuadro y devuelve las geometrias listas para rasterizar.
## Devuelve un array vacio si el servicio no responde: quitar carreteras es una
## mejora, no un requisito, y no debe impedir fundar el asentamiento.
func fetch_area(lat_north: float, lat_south: float,
		lon_west: float, lon_east: float) -> Array[Dictionary]:
	var bbox := "%.6f,%.6f,%.6f,%.6f" % [lat_south, lon_west, lat_north, lon_east]
	var query := "[out:json][timeout:60];("
	query += 'way["highway"](%s);' % bbox
	query += 'way["railway"](%s);' % bbox
	for pair: Array in AREA_TAGS:
		query += 'way["%s"="%s"](%s);' % [pair[0], pair[1], bbox]
	query += ");out geom;"

	var body := _http_get(HOST, PATH + "?data=" + query.uri_encode())
	if body.is_empty():
		push_warning("OSMWays: sin respuesta de Overpass, el relieve se deja como esta")
		return []

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("OSMWays: respuesta ilegible de Overpass")
		return []

	return parse_elements((parsed as Dictionary).get("elements", []))


## Convierte los elementos de Overpass en geometrias con ancho. Separado del
## descargador para poder alimentarlo con una respuesta guardada.
static func parse_elements(elements: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	for element: Variant in elements:
		if typeof(element) != TYPE_DICTIONARY:
			continue
		var way: Dictionary = element
		var geometry: Array = way.get("geometry", [])
		if geometry.size() < 2:
			continue

		var tags: Dictionary = way.get("tags", {})
		var kind := ""
		var is_area := false

		for pair: Array in AREA_TAGS:
			if tags.get(pair[0], "") == pair[1]:
				kind = pair[1]
				is_area = true
				break

		if kind.is_empty():
			if tags.has("highway"):
				kind = str(tags["highway"])
			elif tags.has("railway"):
				kind = str(tags["railway"])
			else:
				continue

		var half_width := 1.0 if is_area else half_width_for(kind)
		if half_width <= 0.0:
			continue

		var points := PackedVector2Array()
		for node: Variant in geometry:
			if typeof(node) != TYPE_DICTIONARY:
				continue
			var n: Dictionary = node
			# (x, y) = (lon, lat), para que encaje con el resto del motor
			points.append(Vector2(float(n.get("lon", 0.0)), float(n.get("lat", 0.0))))

		if points.size() < 2:
			continue

		# Un poligono cerrado con etiqueta de area se rellena; uno cerrado que
		# es una glorieta se traza, porque su interior es terreno normal.
		var closed := is_area and points[0].distance_to(points[points.size() - 1]) < 1e-7

		out.append({
			"points": points,
			"half_width_m": half_width,
			"closed": closed,
			"kind": kind,
		})

	return out


## Pide la hidrografia del recuadro. Devuelve {channels, bodies} listos para
## [Hydrography]: cauces lineales con su ancho y su sentido, y laminas cerradas.
##
## Va en una consulta aparte de la obra humana porque son dos cosas con signos
## opuestos: de la obra se BORRA el relieve, y del agua se PINTA encima.
## Cuantas veces se reintenta una consulta a Overpass.
##
## Al fundar se le hacen TRES peticiones seguidas -vias, agua del recuadro y
## agua del contorno- y Overpass limita por cliente: la tercera es la que se
## quedaba sin respuesta, y por eso los rios se cortaban en el borde sin que
## nada avisara. Con una espera entre medias pasa.
const RETRIES := 3
const RETRY_WAIT_MS := 2500


func fetch_water(lat_north: float, lat_south: float,
		lon_west: float, lon_east: float) -> Dictionary:
	var bbox := "%.6f,%.6f,%.6f,%.6f" % [lat_south, lon_west, lat_north, lon_east]
	var query := "[out:json][timeout:60];("
	query += 'way["waterway"](%s);' % bbox
	query += 'way["natural"="water"](%s);' % bbox
	query += ");out geom;"

	var body := _http_get(HOST, PATH + "?data=" + query.uri_encode())
	if body.is_empty():
		push_warning("OSMWays: sin hidrografia de Overpass")
		return {"channels": [], "bodies": []}

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"channels": [], "bodies": []}

	return parse_water((parsed as Dictionary).get("elements", []))


## Separa los elementos de Overpass en cauces y laminas. Aparte del descargador
## para poder alimentarlo con una respuesta guardada, igual que parse_elements.
static func parse_water(elements: Array) -> Dictionary:
	var channels: Array[Dictionary] = []
	var bodies: Array[Dictionary] = []

	for element: Variant in elements:
		if typeof(element) != TYPE_DICTIONARY:
			continue
		var way: Dictionary = element
		var geometry: Array = way.get("geometry", [])
		if geometry.size() < 2:
			continue

		var points := PackedVector2Array()
		for node: Variant in geometry:
			if typeof(node) != TYPE_DICTIONARY:
				continue
			var nd: Dictionary = node
			points.append(Vector2(float(nd.get("lon", 0.0)), float(nd.get("lat", 0.0))))
		if points.size() < 2:
			continue

		var tags: Dictionary = way.get("tags", {})
		var name := str(tags.get("name", ""))

		if tags.get("natural", "") == "water":
			if not is_natural_water_body(str(tags.get("water", ""))):
				continue
			bodies.append({"points": points, "kind": str(tags.get("water", "lake")), "name": name})
			continue

		if not tags.has("waterway"):
			continue
		var kind := str(tags["waterway"])
		var half_width := channel_width_for(kind)
		if half_width <= 0.0:
			continue

		# `width` explicito cuando lo hay: mejor el dato que la tabla
		if tags.has("width"):
			var declared := str(tags["width"]).to_float()
			if declared > 0.5:
				half_width = declared * 0.5

		channels.append({
			"points": points,
			"half_width_m": half_width,
			"kind": kind,
			"name": name,
			"closed": false,
		})

	return {"channels": channels, "bodies": bodies}


## GET bloqueante, por el mismo motivo que en DEMImporter e IGNImporter:
## HTTPRequest necesita estar en el arbol de escena y esto tiene que poder
## correr tambien como herramienta suelta.
## Pide, y si vuelve vacio espera y reintenta. Ver [RETRIES].
func _http_get(host: String, path: String) -> PackedByteArray:
	for attempt in range(RETRIES):
		var body := _http_once(host, path)
		if not body.is_empty():
			return body
		if attempt < RETRIES - 1:
			print("OSMWays: sin respuesta, reintento %d de %d en %.1f s"
				% [attempt + 2, RETRIES, RETRY_WAIT_MS / 1000.0])
			OS.delay_msec(RETRY_WAIT_MS)
	return PackedByteArray()


func _http_once(host: String, path: String) -> PackedByteArray:
	var http := HTTPClient.new()
	# El esquema se pasa TAL CUAL: es lo que le dice a HTTPClient que abra TLS.
	# Quitandolo se conecta en claro al 443 y Overpass responde 400.
	if http.connect_to_host(host, 443) != OK:
		return PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_CONNECTING \
			or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(20)

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return PackedByteArray()

	if http.request(HTTPClient.METHOD_GET, path, ["User-Agent: CityBuilder/1.0"]) != OK:
		return PackedByteArray()

	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(20)

	if http.get_response_code() != 200:
		push_warning("OSMWays: HTTP %d desde Overpass" % http.get_response_code())
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
