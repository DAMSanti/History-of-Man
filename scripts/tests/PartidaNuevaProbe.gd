extends SceneTree
## EL MAPA REGIONAL DE UNA PARTIDA NUEVA: ¿trae la plataforma emergida, con su orografía y
## sus ríos? GRAFICOS §3.
##
## **Con ventana**, a 1920×1080:
##
##   godot --path . --script res://scripts/tests/PartidaNuevaProbe.gd
##
## Es la hermana de [DebugCaptura] para el camino que de verdad recorre el jugador: **sin
## modo Debug y sin partida guardada**, que es donde la queja aparece —«todo lo del mapa
## regional en la plataforma emergida… orografía, ríos, rías»—. Debug ya salía bien desde el
## 2026-09-17, y por eso el fallo se coló: la sonda que lo vigilaba entraba por Debug.
##
## Cuenta lo mismo que aquélla —celdas emergidas y celdas con cauce sobre la plataforma— y
## deja dos capturas: la comarca entera y un primer plano del mar de hoy al norte del valle.

## Un punto cualquiera de la cinta de frontera, para encuadrarla de cerca.
func _en_medio_de_la_frontera(mapa: Node) -> Vector3:
	for nodo: Node in mapa.get_children():
		if not nodo.name.begins_with("Frontera_"):
			continue
		var malla := (nodo as MeshInstance3D).mesh as ArrayMesh
		if malla == null or malla.get_surface_count() == 0:
			continue
		var puntos: PackedVector3Array = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if not puntos.is_empty():
			return puntos[puntos.size() / 2]
	return Vector3.INF


## El valle de referencia, el mismo de las demás sondas del agua.
const SITIO := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute("user://capturas")
	Configuracion.ruta = "user://sondas/configuracion.cfg"
	Configuracion.por_defecto()
	Guardado.carpeta = "user://sondas/partida_nueva"
	# PARTIDA NUEVA DE VERDAD: ni Debug, ni campamento, ni nada guardado. Es el estado en el
	# que el jugador ve el mapa por primera vez.
	var mapa_gd := load("res://scripts/region/RegionMap.gd")
	print("")
	print("=== MAPA REGIONAL DE PARTIDA NUEVA ===")
	print("antes de montar: home %s · debug %s · mar_del_mapa %.0f m · GameState %.0f m" % [
		GameState.home, ModoDebug.activo, mapa_gd.mar_del_mapa(), GameState.sea_level_m])

	change_scene_to_file("res://scenes/region_map.tscn")
	var mapa: Node = null
	for _i in range(4000):
		await process_frame
		mapa = current_scene
		if mapa != null and mapa.get("montado") == true:
			break
	if mapa == null or mapa.get("montado") != true:
		print("no montó el mapa regional")
		quit(1)
		return
	print("ya montado:     home %s · mar_del_mapa %.0f m · el mapa dibuja %.0f m" % [
		GameState.home.id if GameState.home != null else -1,
		mapa_gd.mar_del_mapa(), mapa._sea_level_m])

	var relieve: HeightmapData = mapa.terrain.heightmap
	var original: HeightmapData = load(mapa.heightmap_path)
	var emergida := 0
	var con_cauce := 0
	var sobre_el_mar := 0.0
	for i in range(relieve.elevations.size()):
		# Lo que hoy es fondo marino y en la época estaba fuera del agua.
		if original.elevations[i] >= 0.0:
			continue
		if relieve.elevations[i] > mapa._sea_level_m:
			emergida += 1
			sobre_el_mar += relieve.elevations[i] - mapa._sea_level_m
			if relieve.river_mask.size() == relieve.elevations.size() \
					and relieve.river_mask[i] > 0.01:
				con_cauce += 1
	print("plataforma emergida: %d celdas · con cauce %d · relieve medio %.1f m sobre el mar" % [
		emergida, con_cauce, sobre_el_mar / maxf(float(emergida), 1.0)])

	# LA CINTA AMARILLA DE LA FRONTERA: si está, dónde está y si se ve. Se pregunta aquí
	# porque «no se ve» tiene dos causas muy distintas —que no se dibuje, o que se dibuje en
	# otro sitio— y la captura sola no las distingue.
	for nodo: Node in mapa.get_children():
		if not nodo.name.begins_with("Frontera_"):
			continue
		var malla := (nodo as MeshInstance3D).mesh
		var caja := malla.get_aabb() if malla != null else AABB()
		print("%s: visible %s · %d triángulos · caja x %.0f..%.0f  y %.1f..%.1f  z %.0f..%.0f" % [
			nodo.name, (nodo as MeshInstance3D).visible,
			malla.surface_get_array_len(0) / 3 if malla != null else 0,
			caja.position.x, caja.position.x + caja.size.x,
			caja.position.y, caja.position.y + caja.size.y,
			caja.position.z, caja.position.z + caja.size.z])
		# ¿CUÁNTO LEVANTA LA CINTA sobre el terreno que tiene debajo? Si la cifra es la que
		# dice `border_lift_m` y aun así no se ve, el problema es que ese alzado se ha
		# quedado corto; si no lo es, la cinta se trazó contra otra cota que la malla.
		var puntos: PackedVector3Array = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bajo := 0
		var suma := 0.0
		var peor := INF
		for i in range(0, puntos.size(), 37):
			var hueco: float = puntos[i].y - mapa.terrain.get_height_at(puntos[i])
			suma += hueco
			peor = minf(peor, hueco)
			if hueco < 0.0:
				bajo += 1
		var cuantos := int(ceil(float(puntos.size()) / 37.0))
		print("  alza media %.2f u · la peor %.2f u · %d de %d muestras POR DEBAJO del terreno" % [
			suma / float(cuantos), peor, bajo, cuantos])

	# ¿POR QUÉ NO SE DIBUJA? La geometría está despejada, así que quedan la transformada,
	# el descarte de caras y la máscara de la cámara. Se dicen las tres y se prueba a quitar
	# el descarte: si aparece, era eso.
	var cinta: MeshInstance3D = null
	for nodo: Node in mapa.get_children():
		if nodo.name.begins_with("Frontera_"):
			cinta = nodo as MeshInstance3D
	if cinta != null:
		var mat := cinta.material_override as StandardMaterial3D
		print("cinta: capas %d · transform %s · terreno %s · camara ve %d" % [
			cinta.layers, cinta.global_transform.origin,
			mapa.terrain.global_transform.origin, mapa.camera.get_node_or_null("Camera3D").cull_mask
				if mapa.camera.get_node_or_null("Camera3D") != null else -1])
		print("material: %s · cull %d · color %s · transparencia %d" % [
			"nulo" if mat == null else "StandardMaterial3D",
			mat.cull_mode if mat != null else -1,
			mat.albedo_color if mat != null else Color.BLACK,
			mat.transparency if mat != null else -1])
		var prueba := OS.get_environment("PRUEBA")
		if mat != null and not prueba.is_empty():
			if prueba == "cull" or prueba == "ambas":
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if prueba == "fondo" or prueba == "ambas":
				mat.no_depth_test = true
			if prueba == "alza":
				cinta.position.y += 20.0
			print("  (prueba: %s)" % prueba)

	print("el terreno mide %d x %d unidades · el agua a %.1f" % [
		mapa.terrain.terrain_size.x, mapa.terrain.terrain_size.y,
		(mapa.terrain.get_node_or_null("Water") as MeshInstance3D).position.y
			if mapa.terrain.get_node_or_null("Water") != null else 0.0])

	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	var valle: Site = null
	for s: Site in sitios.sites:
		if s.id == SITIO:
			valle = s
	for encuadre: Array in [
			["comarca", Vector2(valle.lon, valle.lat), 0.55],
			# AL NORTE, que es donde está el mar de hoy y por tanto la plataforma. Al sur
			# está la cordillera, y las dos primeras capturas de esta sonda la retrataron a
			# ella: se veían idénticas antes y después del arreglo porque no salía la
			# plataforma en ninguna.
			["plataforma", Vector2(valle.lon, valle.lat + 0.20), 0.12],
			# ENCIMA DE LA CINTA DE LA FRONTERA, de cerca: a la escala de la comarca son
			# cuatro píxeles y la captura ancha no distingue «no está» de «no se aprecia».
			["frontera", Vector2.ZERO, 0.05]]:
		var donde: Vector2 = encuadre[1]
		var mirar: Vector3 = mapa.terrain.geo_to_world(donde.x, donde.y)
		if encuadre[0] == "frontera":
			mirar = _en_medio_de_la_frontera(mapa)
			if mirar == Vector3.INF:
				continue
		mapa.camera.set_target(mirar)
		# Casi cenital sobre la cinta: de lado la tapan los montes de delante, y con el
		# relieve a x2.5 eso no distingue «no está» de «está detrás de un cerro».
		if encuadre[0] == "frontera":
			mapa.camera.orbit_angle_v = -85.0
		mapa.camera.set_distance(float(maxi(mapa.terrain.terrain_size.x,
			mapa.terrain.terrain_size.y)) * float(encuadre[2]))
		mapa.camera._update_camera()
		for _i in range(90):
			await process_frame
		var ruta := "user://capturas/nueva_%s.png" % encuadre[0]
		var foto := root.get_texture().get_image()
		for _reintento in range(10):
			if foto != null and not foto.is_empty() and foto.get_pixel(960, 540).a > 0.0:
				break
			await process_frame
			foto = root.get_texture().get_image()
		if foto == null or foto.is_empty():
			print("  %-10s CAPTURA VACÍA" % encuadre[0])
			continue
		foto.save_png(ruta)
		print("  %-10s %s" % [encuadre[0], ProjectSettings.globalize_path(ruta)])

	if OS.get_environment("FUNDAR") != "1":
		quit()
		return

	# Y AHORA SE FUNDA, por el camino del jugador: el valle se prepara con el mar de la
	# época y **se rellena el mar de hoy**, que es el paso que con el mapa montado a cota
	# cero no llegaba a ejecutarse nunca. Es donde el 2026-09-19 apareció una cuña marrón de
	# bordes rectos metida en el valle, y por eso la sonda sigue hasta aquí en vez de
	# quedarse en la comarca.
	print("fundando en %s…" % valle.display_name())
	mapa._select_site(valle)
	# SIN `await`: fundar cambia de escena y **libera este mismo nodo** a mitad de la
	# corrutina, así que la espera no vuelve nunca. Se lanza y se espera a la escena.
	# EL MAPA REGIONAL TAMBIÉN TIENE `montado`, así que hay que saber distinguirlo: sin esto
	# la espera de abajo rompía en el primer fotograma con el mapa de la comarca todavía en
	# pie, y noventa fotogramas después le pedía el terreno a un nodo ya liberado.
	var quien_era_el_mapa := mapa.get_instance_id()
	mapa._found_settlement()
	var demo: Node = null
	var montado := false
	var hasta := Time.get_ticks_msec() + 10 * 60 * 1000
	while Time.get_ticks_msec() < hasta:
		await process_frame
		demo = current_scene
		if not is_instance_valid(demo) or demo.get_instance_id() == quien_era_el_mapa:
			continue
		if demo.get("montado") == true:
			montado = true
			break
	if not montado:
		print("no se entró al valle en diez minutos")
		quit(1)
		return
	var sim: Object = demo.get("sim")
	if sim != null:
		sim.set("hour", 12.0)
	for _i in range(90):
		await process_frame
	paused = true
	var terreno: TerrainGenerator = demo.get("terrain")
	var camara: OrbitalCamera = demo.get("camera")
	camara.process_mode = Node.PROCESS_MODE_ALWAYS
	AguaCaptura.ocultar_la_interfaz(demo)
	var centro := Vector3(float(terreno.terrain_size.x) * 0.5, 0.0,
		float(terreno.terrain_size.y) * 0.5)
	for vuelta: Array in [["valle_n", 0.0], ["valle_e", 90.0], ["valle_s", 180.0],
			["valle_o", 270.0]]:
		camara.set_target(centro)
		camara.orbit_angle_h = float(vuelta[1])
		camara.orbit_angle_v = -40.0
		camara.set_distance(float(terreno.terrain_size.x) * 0.75)
		camara._update_camera()
		for _i in range(60):
			await process_frame
		var foto := root.get_texture().get_image()
		if foto == null or foto.is_empty():
			print("  %-10s CAPTURA VACÍA" % vuelta[0])
			continue
		var donde := "user://capturas/nueva_%s.png" % vuelta[0]
		foto.save_png(donde)
		print("  %-10s %s" % [vuelta[0], ProjectSettings.globalize_path(donde)])
	quit()
