extends SceneTree
## Cuántos árboles hay, qué cuestan y cómo se ven desde el zoom más cercano.
##
## Las tres cosas del bloque del bosque en una pasada. La foto se hace desde una
## órbita como la del juego —no desde una cámara inventada— porque el problema
## que se venía a arreglar era justamente que al zoom más cercano todo eran
## impostores y había un claro en el centro.
##
##   ORBITA=60    a qué distancia se pone la cámara del suelo

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan datos"); quit(); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if site == null:
		print("sin emplazamiento"); quit(); return

	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(60):
		await process_frame

	var demo := current_scene
	var forest: Node = demo.forest if "forest" in demo else null
	var terrain: Node = demo.terrain if "terrain" in demo else null
	var camera: Node = demo.camera if "camera" in demo else null
	if forest == null or terrain == null or camera == null:
		print("falta bosque, terreno o camara"); quit(); return

	var orbit := 60.0
	if not OS.get_environment("ORBITA").is_empty():
		orbit = float(OS.get_environment("ORBITA"))

	print("")
	print("arboles sembrados: %d" % forest.tree_count())
	print("zoom: de %.0f a %.0f m de orbita" % [
		camera.min_distance, camera.max_distance])
	print("relevo a malla de verdad: %.0f m" % forest.near_distance)

	# La cámara del juego, puesta como la pondría el jugador al acercarse.
	if "sim" in demo and demo.sim != null:
		demo.sim.hour = 13.0
		camera.set_target(demo.sim.home_position)
	camera.set_distance(orbit)
	camera.orbit_angle_v = -32.0
	print("camara: orbita %.0f m sobre %s" % [
		camera.orbit_distance, camera.target_position])
	_hide_ui(demo)

	# Se mide por RELOJ DE PARED y no por número de fotogramas: si la escena va
	# a dos por segundo, esperar ciento veinte fotogramas es esperar un minuto,
	# y la propia medición se vuelve tan lenta como el problema que mide.
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 8000:
		await process_frame

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var start := Time.get_ticks_msec()
	var frames := 0
	var ms := 0.0
	while Time.get_ticks_msec() - start < 8000:
		await process_frame
		frames += 1
		ms += RenderingServer.viewport_get_measured_render_time_cpu(vp) 			+ RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var wall := float(Time.get_ticks_msec() - start) / maxf(float(frames), 1.0)
	print("a %.0f m de orbita: %.1f fps · %.1f ms de reloj · %.1f ms de render" % [
		orbit, 1000.0 / maxf(wall, 0.001), wall, ms / maxf(float(frames), 1.0)])

	root.get_texture().get_image().save_png("user://bosque_%d.png" % int(orbit))
	print("captura en %s" % ProjectSettings.globalize_path("user://"))
	quit()


func _hide_ui(node: Node) -> void:
	var layer := node as CanvasLayer
	if layer != null:
		layer.visible = false
		return
	for child in node.get_children():
		_hide_ui(child)
