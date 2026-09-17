class_name RioDeLaPlataforma
extends RefCounted
## Por dónde seguía un río de hoy cuando el mar estaba a −120 m.
##
## EPOCA_01 §10.2. Los ríos de hoy acaban en la costa de hoy, y en el Paleolítico
## esa costa era tierra: el Nansa, el Pas o el Asón seguían kilómetros por la
## plataforma emergida hasta el mar de la época. Nadie los ha cartografiado —están
## bajo el mar—, así que se deducen: **desde la boca de hoy, bajando por el relieve**.
##
## Es una regla de datos, sin red ni nodos: la usa `HornearRios` y se prueba con
## relieve construido.

## Hasta qué cota puede estar la punta de un río para ser su boca en la costa de hoy,
## en metros. La costa del relieve regional no casa al metro con la de OSM: la punta
## del río cae unos metros tierra adentro o ya en el agua.
const COTA_DE_BOCA := 15.0

## Dos puntas a menos de esto son el mismo sitio: un tramo que sigue en otro, o dos
## brazos que salen al mismo estuario.
const MISMO_SITIO_M := 300.0

## Pasos como mucho de un río por la plataforma, en muestras del relieve regional: a
## 111 m son 44 km, y la plataforma de Cantabria no llega ni a la mitad de ancha.
const PASOS_MAXIMOS := 400


## Las bocas en la costa de hoy: una punta de río que no sigue en otro tramo y que está
## a ras del mar.
##
## **Se miran LAS DOS PUNTAS de cada tramo.** Las vías de agua de OSM se dibujan en el
## sentido de la corriente, pero no siempre: mirando sólo la de aguas abajo, el Pas se
## quedaba sin boca y su tramo de plataforma no existía (`CostaCaptura`, 2026-09-16).
static func bocas(cauces: Array, datos: HeightmapData) -> Array[Dictionary]:
	# Todas las puntas, para saber cuáles se tocan: una punta que toca otra no es el
	# final del río, es una junta entre dos tramos.
	var puntas: Array[Vector2] = []
	for cauce: Dictionary in cauces:
		var puntos: PackedVector2Array = cauce["points"]
		if puntos.size() < 2:
			continue
		puntas.append(puntos[0])
		puntas.append(puntos[puntos.size() - 1])

	var fuera: Array[Dictionary] = []
	for cauce: Dictionary in cauces:
		var puntos: PackedVector2Array = cauce["points"]
		if puntos.size() < 2:
			continue
		for punta: Vector2 in [puntos[0], puntos[puntos.size() - 1]]:
			var tocando := 0
			for otra: Vector2 in puntas:
				if _metros(otra, punta) < 30.0:
					tocando += 1
			# La suya propia cuenta una vez: con más, el río sigue en otro tramo.
			if tocando > 1:
				continue
			var cota := datos.sample_bilinear(datos.u_for_lon(punta.x), datos.v_for_lat(punta.y))
			if cota > COTA_DE_BOCA:
				continue
			# Y si ya hay una boca aquí, se queda la del río más ancho.
			var repetida := -1
			for i in range(fuera.size()):
				if _metros(Vector2(float(fuera[i]["lon"]), float(fuera[i]["lat"])), punta) \
						< MISMO_SITIO_M:
					repetida = i
					break
			var boca := {"lon": punta.x, "lat": punta.y, "name": cauce.get("name", ""),
				"kind": cauce.get("kind", "river"),
				"half_width_m": float(cauce.get("half_width_m", 11.0))}
			if repetida < 0:
				fuera.append(boca)
			elif float(boca["half_width_m"]) > float(fuera[repetida]["half_width_m"]):
				fuera[repetida] = boca
	return fuera


## Hacia dónde desagua cada celda: la vecina a la que pasa su agua camino del mar, o
## −2 si no llega (queda por encima de `cota_tope`, o es mar que no toca tierra).
##
## **Inundando desde el mar hacia tierra**: se siembran las celdas de mar que tocan
## tierra y se va abriendo siempre la celda más baja de la orilla de lo inundado. La
## celda por la que se llegó a otra es por donde esa otra desagua. Así cada río sale al
## mar por el paso más bajo y por el camino corto.
##
## Hubo antes dos formas que no valían (`HornearRios`, 2026-09-16): bajar a la vecina
## más baja **se atascaba** contra un umbral, e inundar desde cada boca **vagaba en
## paralelo a la costa** —54 ríos con 1 490 km por una plataforma de 10 a 30 km—.
static func hacia_el_mar(datos: HeightmapData, mar: float,
		cota_tope: float = 40.0) -> PackedInt32Array:
	var ancho := datos.width
	var total := ancho * datos.height
	var padres := PackedInt32Array()
	padres.resize(total)
	padres.fill(-2)
	var cola := _Cola.new()
	for celda in range(total):
		if datos.elevations[celda] > mar:
			continue
		# Sólo el mar que toca tierra: el resto no hace falta abrirlo.
		var x := celda % ancho
		@warning_ignore("integer_division")
		var z := celda / ancho
		var toca := false
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var nx := x + dx
				var nz := z + dz
				if nx >= 0 and nz >= 0 and nx < ancho and nz < datos.height \
						and datos.elevations[nz * ancho + nx] > mar:
					toca = true
		if toca:
			padres[celda] = -1
			cola.meter(celda, datos.elevations[celda])
	while not cola.vacia():
		var celda := cola.sacar()
		var x := celda % ancho
		@warning_ignore("integer_division")
		var z := celda / ancho
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx := x + dx
				var nz := z + dz
				if nx < 0 or nz < 0 or nx >= ancho or nz >= datos.height:
					continue
				var vecina := nz * ancho + nx
				if padres[vecina] != -2:
					continue
				var cota := datos.elevations[vecina]
				if cota <= mar or cota > cota_tope:
					continue
				padres[vecina] = celda
				cola.meter(vecina, cota)
	return padres


## Baja por el relieve desde un punto hasta el mar dado, siguiendo [hacia_el_mar].
## Devuelve `puntos` (lon, lat), si `llega` al mar y cuántos pasos `abiertos` suben:
## los umbrales de la batimetría a 111 m que el agua tiene que salvar. El valle que la
## hace bajar de verdad lo talla después [RelieveDeLaPlataforma].
static func bajar(datos: HeightmapData, lon: float, lat: float, mar: float,
		padres: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	if padres.is_empty():
		padres = hacia_el_mar(datos, mar)
	var ancho := datos.width
	var x0 := clampi(roundi(datos.u_for_lon(lon) * float(ancho - 1)), 0, ancho - 1)
	var z0 := clampi(roundi(datos.v_for_lat(lat) * float(datos.height - 1)), 0, datos.height - 1)
	var celda := z0 * ancho + x0
	var puntos := PackedVector2Array([Vector2(lon, lat)])
	var subidas := 0
	var pasos := 0
	if padres[celda] == -2:
		return {"puntos": puntos, "llega": false, "abiertos": 0}
	while padres[celda] >= 0 and pasos < PASOS_MAXIMOS:
		var siguiente := padres[celda]
		# Estrictamente: un llano no es subir. Con `>=` salían 4 029 «pasos abiertos»
		# que eran casi todos llanos de la batimetría (2026-09-16).
		if datos.elevations[siguiente] > datos.elevations[celda]:
			subidas += 1
		celda = siguiente
		pasos += 1
		var cx := celda % ancho
		@warning_ignore("integer_division")
		var cz := celda / ancho
		puntos.append(Vector2(
			lerpf(datos.lon_west, datos.lon_east, float(cx) / float(ancho - 1)),
			datos.lat_for_v(float(cz) / float(datos.height - 1))))
	var llega := datos.elevations[celda] <= mar
	return {"puntos": puntos, "llega": llega, "abiertos": subidas}


## Una cola de prioridad por cota: un montículo en un par de listas. GDScript no trae
## ninguna, y con la región entera la inundación abre decenas de miles de celdas.
class _Cola:
	var _celdas: Array[int] = []
	var _cotas: Array[float] = []

	func vacia() -> bool:
		return _celdas.is_empty()

	func meter(celda: int, cota: float) -> void:
		_celdas.append(celda)
		_cotas.append(cota)
		var i := _celdas.size() - 1
		while i > 0:
			@warning_ignore("integer_division")
			var arriba := (i - 1) / 2
			if _cotas[arriba] <= _cotas[i]:
				break
			_cambiar(i, arriba)
			i = arriba

	func sacar() -> int:
		var fuera := _celdas[0]
		var ultimo := _celdas.size() - 1
		_cambiar(0, ultimo)
		_celdas.pop_back()
		_cotas.pop_back()
		var i := 0
		while true:
			var menor := i
			var izq := i * 2 + 1
			var der := i * 2 + 2
			if izq < _celdas.size() and _cotas[izq] < _cotas[menor]:
				menor = izq
			if der < _celdas.size() and _cotas[der] < _cotas[menor]:
				menor = der
			if menor == i:
				break
			_cambiar(i, menor)
			i = menor
		return fuera

	func _cambiar(a: int, b: int) -> void:
		var c := _celdas[a]
		_celdas[a] = _celdas[b]
		_celdas[b] = c
		var k := _cotas[a]
		_cotas[a] = _cotas[b]
		_cotas[b] = k


## Los tramos de la plataforma de todos los ríos que salen a la costa de hoy.
static func prolongar(cauces: Array, datos: HeightmapData, mar: float) -> Dictionary:
	var fuera: Array[Dictionary] = []
	var abiertos := 0
	# Una sola inundación para todos: es lo caro.
	var padres := hacia_el_mar(datos, mar)
	for boca: Dictionary in bocas(cauces, datos):
		var bajada := bajar(datos, float(boca["lon"]), float(boca["lat"]), mar, padres)
		var puntos: PackedVector2Array = bajada["puntos"]
		if not bool(bajada["llega"]) or puntos.size() < 2:
			continue
		abiertos += int(bajada["abiertos"])
		fuera.append({
			"points": suavizar(puntos, 2),
			"half_width_m": float(boca["half_width_m"]),
			"kind": String(boca["kind"]),
			"name": String(boca["name"]),
			"closed": false,
			"de_la_plataforma": true,
		})
	return {"cauces": fuera, "abiertos": abiertos}


## La línea sin la escalera de celdas: cada pasada corta las esquinas por un cuarto y
## tres cuartos de cada tramo (Chaikin). Los puntos de las puntas se quedan, que son los
## que tocan el río de hoy y el mar.
##
## Sin esto, un río de la plataforma se dibujaba en rectas con quiebros de 45°, el rastro
## de ir de celda en celda (captura del mapa regional, 2026-09-16).
static func suavizar(puntos: PackedVector2Array, pasadas: int) -> PackedVector2Array:
	var linea := puntos
	for _p in range(pasadas):
		if linea.size() < 3:
			return linea
		var nueva := PackedVector2Array([linea[0]])
		for k in range(linea.size() - 1):
			var a := linea[k]
			var b := linea[k + 1]
			nueva.append(a.lerp(b, 0.25))
			nueva.append(a.lerp(b, 0.75))
		nueva.append(linea[linea.size() - 1])
		linea = nueva
	return linea


## Metros entre dos puntos (lon, lat), a ojo de cartógrafo: sobra para decir si dos
## puntas son el mismo sitio.
static func _metros(a: Vector2, b: Vector2) -> float:
	var dy := (b.y - a.y) * 111320.0
	var dx := (b.x - a.x) * 111320.0 * cos(deg_to_rad(a.y))
	return sqrt(dx * dx + dy * dy)
