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
			["plataforma", Vector2(valle.lon, valle.lat + 0.20), 0.12]]:
		var donde: Vector2 = encuadre[1]
		mapa.camera.set_target(mapa.terrain.geo_to_world(donde.x, donde.y))
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
