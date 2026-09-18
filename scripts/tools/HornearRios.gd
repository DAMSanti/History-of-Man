extends SceneTree
## Hornea los ríos del mapa regional: `data/sites/rios_de_la_region.res`.
##
## EPOCA_01 §10.2, tareas 2 y 3. Baja de OSM los ríos de la región por trozos
## —Overpass no da la región entera de una vez— y los prolonga por la plataforma
## emergida con [RioDeLaPlataforma].
##
##   godot --headless --path . --script res://scripts/tools/HornearRios.gd
##
## `SIN_RED=1`: no baja nada y rehace sólo la prolongación con los ríos de hoy que
## ya estén guardados. Es lo que se usa al retocar la regla de la plataforma.

const DESTINO := RiosDeLaRegion.RUTA
const RELIEVE := "res://data/dem/cantabria_region.res"

## Trozos en que se pide la región. Cuatro por dos da recuadros de algo más de
## medio grado, que Overpass sirve sin cortar.
const COLUMNAS := 4
const FILAS := 2

## El mar de la época hasta el que se prolongan.
const MAR := -120.0


func _init() -> void:
	# UN CUADRO ANTES DE PEDIR NADA A LA RED: en `_init` el módulo de cifrado todavía
	# no está arrancado, y Overpass va por HTTPS —«SSL module failed to initialize»,
	# 2026-09-16—.
	await process_frame
	var datos: HeightmapData = load(RELIEVE)
	if datos == null:
		print("MAL: no está el relieve regional")
		quit(1)
		return

	var rios: RiosDeLaRegion = null
	if ResourceLoader.exists(DESTINO):
		rios = load(DESTINO) as RiosDeLaRegion
	if rios == null:
		rios = RiosDeLaRegion.new()

	if OS.get_environment("SIN_RED") != "1":
		_bajar_los_rios(datos, rios)
		ResourceSaver.save(rios, DESTINO)
	print("ríos de hoy: %d tramos, %.0f km" % [rios.de_hoy.size(), _km(rios.de_hoy)])
	for nombre: String in ["Nansa", "Saja", "Besaya", "Pas", "Asón"]:
		var tramos := 0
		for cauce: Dictionary in rios.de_hoy:
			if String(cauce.get("name", "")).contains(nombre):
				tramos += 1
		print("   %s: %d tramos" % [nombre, tramos])

	var t0 := Time.get_ticks_msec()
	# SOBRE LA PLATAFORMA CON SU RELIEVE, no sobre el fondo liso: desde el 2026-09-17 las
	# lomas son relieve real prestado (GRAFICOS §3), y un río deducido sobre la batimetría
	# lisa cruzaba las lomas por encima en vez de bajar por las vaguadas. Sobre una COPIA:
	# `aplicar` reescribe las cotas, y el recurso cargado es el mismo que lee todo el
	# proceso (ver la memoria de `Resource.duplicate`).
	var con_relieve := HeightmapData.new()
	con_relieve.width = datos.width
	con_relieve.height = datos.height
	con_relieve.meters_per_sample = datos.meters_per_sample
	con_relieve.lat_north = datos.lat_north
	con_relieve.lat_south = datos.lat_south
	con_relieve.lon_west = datos.lon_west
	con_relieve.lon_east = datos.lon_east
	con_relieve.geographic_rows = datos.geographic_rows
	con_relieve.elevations = PackedFloat32Array(datos.elevations)
	RelieveDeLaPlataforma.aplicar(con_relieve, MAR)
	var prolongados := RioDeLaPlataforma.prolongar(rios.de_hoy, con_relieve, MAR)
	rios.de_la_plataforma.assign(prolongados["cauces"])
	rios.pasos_abiertos = int(prolongados["abiertos"])
	rios.mar_de_la_plataforma = MAR

	# LOS ANCHOS, sobre todos juntos: el tramo de la plataforma sigue al río de hoy, y
	# tiene que empezar con lo que le llega de arriba.
	var todos: Array = []
	todos.append_array(rios.de_hoy)
	todos.append_array(rios.de_la_plataforma)
	AnchoDeLosRios.poner(todos)
	rios.version_de_los_anchos = AnchoDeLosRios.VERSION
	var mas_ancho := 0.0
	for cauce: Dictionary in todos:
		for ancho: float in (cauce["half_widths_m"] as PackedFloat32Array):
			mas_ancho = maxf(mas_ancho, ancho)
	print("anchos: el más ancho, %.0f m de semiancho" % mas_ancho)
	print("por la plataforma: %d ríos, %.0f km, %d pasos abiertos en llano (%d ms)" % [
		rios.de_la_plataforma.size(), _km(rios.de_la_plataforma), rios.pasos_abiertos,
		Time.get_ticks_msec() - t0])

	var error := ResourceSaver.save(rios, DESTINO)
	print("guardado en %s: %s" % [DESTINO, "bien" if error == OK else "ERROR %d" % error])
	quit()


## Baja los trozos que falten y los suma a lo guardado. **Un trozo que Overpass no
## sirve —504, está saturado— se queda sin marcar** y se pide en la siguiente pasada:
## en la primera, dos de ocho volvieron vacíos (2026-09-16).
func _bajar_los_rios(datos: HeightmapData, rios: RiosDeLaRegion) -> void:
	var osm := OSMWays.new()
	var vistos: Dictionary = {}
	for cauce: Dictionary in rios.de_hoy:
		vistos[int(cauce.get("id", 0))] = true
	var alto := (datos.lat_north - datos.lat_south) / float(FILAS)
	var ancho := (datos.lon_east - datos.lon_west) / float(COLUMNAS)
	for f in range(FILAS):
		for c in range(COLUMNAS):
			var trozo_id := f * COLUMNAS + c
			if rios.trozos_bajados.has(trozo_id):
				continue
			var norte := datos.lat_north - alto * float(f)
			var oeste := datos.lon_west + ancho * float(c)
			var t0 := Time.get_ticks_msec()
			var trozo := osm.fetch_rivers(norte, norte - alto, oeste, oeste + ancho)
			if trozo.is_empty():
				print("   trozo %d,%d: SIN RESPUESTA, queda para la siguiente pasada" % [f, c])
				continue
			var nuevos := 0
			for cauce: Dictionary in trozo:
				var id := int(cauce.get("id", 0))
				if id != 0 and vistos.has(id):
					continue
				vistos[id] = true
				rios.de_hoy.append(cauce)
				nuevos += 1
			rios.trozos_bajados.append(trozo_id)
			print("   trozo %d,%d: %d ríos (%d nuevos) en %d ms" % [f, c, trozo.size(),
				nuevos, Time.get_ticks_msec() - t0])
	var faltan := FILAS * COLUMNAS - rios.trozos_bajados.size()
	if faltan > 0:
		print("FALTAN %d trozos: vuelve a correr la herramienta" % faltan)


func _km(cauces: Array) -> float:
	var total := 0.0
	for cauce: Dictionary in cauces:
		var puntos: PackedVector2Array = cauce["points"]
		for i in range(1, puntos.size()):
			var a := puntos[i - 1]
			var b := puntos[i]
			var dy := (b.y - a.y) * 111.32
			var dx := (b.x - a.x) * 111.32 * cos(deg_to_rad(a.y))
			total += sqrt(dx * dx + dy * dy)
	return total
