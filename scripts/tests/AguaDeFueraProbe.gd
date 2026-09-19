extends SceneTree
## ¿CONTINÚA EL RÍO al salir del recuadro jugable? GRAFICOS §3.
##
## **Con ventana**, a 1920×1080:
##
##   NIVEL=3 godot --path . --script res://scripts/tests/AguaDeFueraProbe.gd
##
## Nace de una queja que se repitió cuatro veces —«el río sigue sin continuar por las 8
## tiles que rodean el mapa»— y de que **la sonda anterior no medía nada**: muestreaba el
## contorno en el mismo punto de dentro de la caja, o sea el recuadro jugable, y por eso
## daba 100 %. Ésta mide **hacia fuera**, y las dos cosas por separado:
##
## - **pintada**: ¿trae el MDT del contorno cauce justo al otro lado de la raya? Es un
##   dato, no un dibujo: si esto falla, lo que falta es el río del mapa regional.
## - **lámina**: ¿hay malla de agua ahí? Desde el escalón «Agua» Alto el río del recuadro
##   se dibuja con una malla encima, mucho más viva que el agua pintada en el suelo. Sin
##   lámina fuera, el río se corta en una raya recta en el borde aunque el dato esté.
##
## Las dos cifras juntas dicen de quién es el corte. Y deja capturas del cruce más ancho
## en `user://capturas/fuera_*.png` para mirarlo, que es lo único que cuenta de verdad.

const SITE_ID := 56

## Cuánto se sale de la raya para preguntar, en pasos de la rejilla del recuadro.
const FUERA := 4.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute("user://capturas")
	Configuracion.ruta = "user://sondas/configuracion.cfg"
	Configuracion.por_defecto()
	Guardado.carpeta = "user://sondas/mapas"
	var nivel := 3
	if not OS.get_environment("NIVEL").is_empty():
		nivel = int(OS.get_environment("NIVEL"))
	Configuracion.poner_ajuste("agua", nivel)
	var sitio := int(OS.get_environment("SITIO")) if not OS.get_environment("SITIO").is_empty() else SITE_ID
	if not AguaCaptura.preparar(sitio):
		print("faltan los datos del sitio %d" % sitio)
		quit(1)
		return

	change_scene_to_file("res://scenes/demo_main.tscn")
	var demo: Node = null
	for _i in range(4000):
		await process_frame
		demo = current_scene
		if demo != null and demo.get("montado") == true:
			break
	if demo == null or demo.get("montado") != true:
		print("no arrancó")
		quit(1)
		return
	var sim: Object = demo.get("sim")
	var ui: Object = demo.get("ui")
	if ui != null and ui.get("barra") != null:
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	if sim != null:
		sim.set("hour", 12.0)
	for _i in range(60):
		await process_frame
	paused = true

	var terreno: TerrainGenerator = demo.get("terrain")
	var contorno: TerrainSurround = demo.get_node_or_null("Alrededores") as TerrainSurround
	if terreno == null or contorno == null:
		print("sin terreno o sin contorno")
		quit(1)
		return

	var cruces := _cruces_del_borde(terreno)
	print("")
	print("=== EL AGUA FUERA DEL RECUADRO, sitio %d, «Agua» %d ===" % [sitio, nivel])
	var triangulos := 0
	for nodo: MeshInstance3D in contorno.laminas:
		var m := nodo.mesh as ArrayMesh
		if m != null and m.get_surface_count() > 0:
			triangulos += m.surface_get_array_index_len(0) / 3
	print("láminas del contorno: %d de 8 casillas, %d triángulos en total" % [
		contorno.laminas.size(), triangulos])
	if cruces.is_empty():
		print("este valle no tiene ningún río que cruce la raya")
		quit()
		return

	var vertices := _vertices_de_las_laminas(contorno)
	var region := load("res://data/dem/local/site_%d_surround.res" % sitio) as HeightmapData
	var paso_fuera := float(terreno.terrain_size.x) * 1.04 / float(contorno.resolution - 1)
	var cerca := paso_fuera * 1.5

	var con_dato := 0
	var con_lamina := 0
	for cruce: Dictionary in cruces:
		var punto: Vector3 = cruce["punto"] + cruce["afuera"] * (FUERA * cruce["paso"])
		if region != null and _cauce_pintado(terreno, region, punto):
			con_dato += 1
		if _distancia_minima(vertices, punto) <= cerca:
			con_lamina += 1
	print("cruces de río en la raya: %d" % cruces.size())
	print("  con cauce en el MDT del contorno: %d (%.0f %%)" % [
		con_dato, 100.0 * float(con_dato) / float(cruces.size())])
	print("  con LÁMINA de agua del contorno: %d (%.0f %%)" % [
		con_lamina, 100.0 * float(con_lamina) / float(cruces.size())])
	print("  (se pregunta a %.0f unidades por fuera, y «cerca» son %.0f)" % [
		FUERA * float(cruces[0]["paso"]), cerca])

	await _retratar(demo, terreno, cruces, nivel)
	quit()


## Los sitios donde un río toca el borde del recuadro, uno por tramo seguido de agua: un
## cauce de veinte celdas de ancho es **un** cruce, no veinte.
func _cruces_del_borde(terreno: TerrainGenerator) -> Array[Dictionary]:
	var maps := terreno.sample_maps()
	var res: int = maps.get("resolution", 0)
	var rio: PackedFloat32Array = maps.get("river", PackedFloat32Array())
	var altura: PackedFloat32Array = maps.get("height", PackedFloat32Array())
	var fuera: Array[Dictionary] = []
	if res <= 1 or rio.is_empty():
		return fuera
	var extension: Vector2 = maps["extent"]
	var origen: Vector2 = maps["origin"]
	var paso := extension.x / float(res - 1)
	var bordes := [
		{"eje": "z", "fijo": 0, "afuera": Vector3(0.0, 0.0, -1.0)},
		{"eje": "z", "fijo": res - 1, "afuera": Vector3(0.0, 0.0, 1.0)},
		{"eje": "x", "fijo": 0, "afuera": Vector3(-1.0, 0.0, 0.0)},
		{"eje": "x", "fijo": res - 1, "afuera": Vector3(1.0, 0.0, 0.0)},
	]
	for borde: Dictionary in bordes:
		var mojado := false
		var desde := 0
		for i in range(res + 1):
			var gx: int = i if borde["eje"] == "z" else int(borde["fijo"])
			var gz: int = int(borde["fijo"]) if borde["eje"] == "z" else i
			var hay := false
			if i < res:
				hay = rio[gz * res + gx] >= AguaDelCauce.LINEA_DEL_AGUA
			if hay and not mojado:
				desde = i
				mojado = true
			elif not hay and mojado:
				mojado = false
				var medio := (desde + i - 1) / 2
				var mx: int = medio if borde["eje"] == "z" else int(borde["fijo"])
				var mz: int = int(borde["fijo"]) if borde["eje"] == "z" else medio
				fuera.append({
					"punto": Vector3(origen.x + float(mx) * paso,
						altura[mz * res + mx], origen.y + float(mz) * paso),
					"afuera": borde["afuera"],
					"ancho": float(i - desde) * paso,
					"paso": paso,
				})
	return fuera


## Todos los vértices de las láminas del contorno, ya en coordenadas del mundo.
func _vertices_de_las_laminas(contorno: TerrainSurround) -> PackedVector3Array:
	var fuera := PackedVector3Array()
	for nodo: MeshInstance3D in contorno.laminas:
		var malla := nodo.mesh as ArrayMesh
		if malla == null or malla.get_surface_count() == 0:
			continue
		var arrays := malla.surface_get_arrays(0)
		for v: Vector3 in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			fuera.append(v + nodo.position)
	return fuera


func _distancia_minima(vertices: PackedVector3Array, punto: Vector3) -> float:
	var mejor := INF
	for v: Vector3 in vertices:
		var d := Vector2(v.x - punto.x, v.z - punto.z).length_squared()
		if d < mejor:
			mejor = d
	return sqrt(mejor)


## ¿Trae el MDT del contorno cauce en este punto del mundo? Es el dato, no el dibujo.
func _cauce_pintado(terreno: TerrainGenerator, region: HeightmapData, punto: Vector3) -> bool:
	var grados := terreno.world_to_geo(punto)
	if grados == Vector2.INF:
		return false
	return region.sample_river_mask(
		region.u_for_lon(grados.x), region.v_for_lat(grados.y)) > 0.01


## El cruce más ancho, desde dentro mirando afuera y a ras de valle: si el río se corta en
## la raya, aquí se ve la raya.
func _retratar(demo: Node, terreno: TerrainGenerator, cruces: Array[Dictionary],
		nivel: int) -> void:
	var elegido: Dictionary = cruces[0]
	for cruce: Dictionary in cruces:
		if float(cruce["ancho"]) > float(elegido["ancho"]):
			elegido = cruce
	var camara: OrbitalCamera = demo.get("camera")
	camara.process_mode = Node.PROCESS_MODE_ALWAYS
	for nodo: Node in demo.find_children("SalpicadurasDelRio", "", true, false):
		nodo.process_mode = Node.PROCESS_MODE_ALWAYS
	AguaCaptura.ocultar_la_interfaz(demo)
	var afuera: Vector3 = elegido["afuera"]
	# DESDE DENTRO MIRANDO AFUERA, no al revés: desde fuera, la pared del [build_border] se
	# mete entre la cámara y el río y no se ve nada del borde.
	#
	# Y el ángulo vertical va en NEGATIVO —de -89 a -3, ver [OrbitalCamera._update_camera]—:
	# en positivo la cámara sale por debajo del terreno y las dos primeras capturas de esta
	# sonda salieron mirando el reverso del mapa.
	var rumbo := rad_to_deg(atan2(-afuera.x, -afuera.z))
	# **La que decide es la cenital**: el cruce entero en el encuadre, con la raya en medio.
	# La rasante depende de cómo caiga el monte en el cruce elegido y a veces sale metida en
	# una ladera; se deja porque cuando sale, sale mejor.
	for encuadre: Array in [["ras", -38.0, 620.0], ["cenital", -75.0, 700.0]]:
		camara.set_target(elegido["punto"])
		camara.orbit_angle_h = rumbo
		camara.orbit_angle_v = float(encuadre[1])
		camara.set_distance(float(encuadre[2]))
		camara._update_camera()
		for _i in range(90):
			await process_frame
		var ruta := "user://capturas/fuera_agua%d_%s.png" % [nivel, encuadre[0]]
		var imagen := root.get_texture().get_image()
		for _reintento in range(10):
			if imagen != null and not imagen.is_empty() and imagen.get_pixel(960, 540).a > 0.0:
				break
			await process_frame
			imagen = root.get_texture().get_image()
		if imagen == null or imagen.is_empty():
			print("  %-5s CAPTURA VACÍA: ¿la ventana está minimizada o tapada?" % encuadre[0])
			continue
		imagen.save_png(ruta)
		print("  %-7s cruce de %.0f m en (%.0f, %.0f), cámara a %.0f  %s" % [encuadre[0],
			elegido["ancho"], elegido["punto"].x, elegido["punto"].z,
			camara.orbit_distance, ProjectSettings.globalize_path(ruta)])
	print("  terreno de %d unidades de lado" % terreno.terrain_size.x)
