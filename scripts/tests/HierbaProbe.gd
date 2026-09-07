extends SceneTree
## Cómo se ve y qué cuesta la alfombra de hierba, mirada desde donde se juega.
##
## Hace falta una sonda propia porque `GpuProfile` mira desde setenta y cinco
## metros de altura, y ahí la hierba ni se ve ni se paga: la alfombra vive en
## los primeros cien metros. Todo lo que se midió de la hierba con esa cámara
## estaba midiendo otra cosa.
##
## Saca tres vistas -a ras de ojo, a media altura y desde arriba- y en cada una
## dice el coste y cuántas matas hay puestas. Las tres juntas son lo que permite
## juzgar el compromiso: la de abajo dice si hay alfombra, la de arriba dice si
## se está pagando por hierba que no se ve.

const SITE_ID := 56
const SHOTS := "user://hierba"

## Altura de los ojos y a dónde mira, en metros. 1,70 es la talla real de la
## gente de este juego, así que es la vista que importa.
const VIEWS: Array[Dictionary] = [
	{"name": "ojos", "height": 1.7, "pitch": -6.0, "back": 0.0},
	{"name": "media", "height": 18.0, "pitch": -22.0, "back": 40.0},
	{"name": "lejos", "height": 75.0, "pitch": -30.0, "back": 130.0},
	# La vista que destapó los anillos concéntricos y el claro del centro: cámara
	# alta mirando hacia abajo, que es como se juega la mayor parte del tiempo.
	{"name": "alto", "height": 190.0, "pitch": -55.0, "back": 150.0},
]


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
	for i in range(240):
		await process_frame

	var demo := current_scene
	var terrain: Node = _first(demo, "TerrainGenerator")
	var cover: Node = demo.get_node_or_null("Hierba")
	if terrain == null:
		print("sin terreno"); quit(); return
	if cover == null:
		print("SIN NODO DE HIERBA: no esta montado en DemoMain"); quit(); return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	# A MEDIODÍA. La partida arranca a las seis y en pausa -ver `SettlementSim`-,
	# y el día 80 el sol sale a las 6:02, así que sin esto todas las capturas
	# salen en penumbra ámbar y no se puede juzgar ni el color ni la densidad de
	# nada. No es maquillar la foto: es fotografiar con luz.
	if "sim" in demo and demo.sim != null:
		demo.sim.hour = 12.0
		for i in range(6):
			await process_frame

	var home := _find_meadow(terrain, Vector3(2048.0, 0.0, 2048.0))
	home.y = terrain.get_height_at(home)

	var camera := Camera3D.new()
	camera.far = 20000.0
	camera.fov = 62.0
	demo.add_child(camera)
	camera.make_current()

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	print("")
	print("=== ALFOMBRA DE HIERBA ===")
	for view: Dictionary in VIEWS:
		camera.global_position = home + Vector3(
			0.0, float(view["height"]), float(view["back"]))
		camera.rotation = Vector3.ZERO
		camera.rotate_y(PI)
		camera.rotate_object_local(Vector3.RIGHT,
			deg_to_rad(float(view["pitch"])))

		# Le damos margen: la alfombra se puebla a tres celdas por fotograma, y
		# medir antes de que termine mide un mundo a medio poner.
		for i in range(90):
			await process_frame

		var gpu := 0.0
		for i in range(60):
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		gpu /= 60.0

		var matas: int = cover.live_instances() if cover.has_method(
			"live_instances") else -1
		print("%-6s alto %5.1f m · %5.1f ms GPU · %7d matas · %8d tri · %4d draws" % [
			view["name"], float(view["height"]), gpu, matas,
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])

		var shot := root.get_texture().get_image()
		shot.save_png("%s/%s.png" % [SHOTS, view["name"]])

	print("fotos en %s" % ProjectSettings.globalize_path(SHOTS))
	quit()


## Busca un prado de verdad cerca del centro.
##
## Hace falta porque las primeras capturas a ras de ojo salían sobre un canchal
## en sombra, y allí la hierba NO DEBE salir: la cobertura horneada la quita en
## pendiente fuerte. La foto parecía decir que el sistema no funcionaba cuando lo
## que decía es que el sitio estaba mal elegido. Se busca llano y húmedo, que es
## donde se juzga una alfombra.
func _find_meadow(terrain: Node, around: Vector3) -> Vector3:
	var best := around
	var best_score := -1.0
	for z in range(-9, 10):
		for x in range(-9, 10):
			var spot := around + Vector3(float(x) * 45.0, 0.0, float(z) * 45.0)
			if terrain.crossing_difficulty_at(spot) > 0.05:
				continue
			var score: float = (1.0 - clampf(terrain.get_slope_at(spot) / 0.4, 0.0, 1.0)) 				* terrain.get_humidity_at(spot)
			if score > best_score:
				best_score = score
				best = spot
	print("prado en (%.0f, %.0f), pendiente %.2f, humedad %.2f" % [
		best.x, best.z, terrain.get_slope_at(best),
		terrain.get_humidity_at(best)])
	return best


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
