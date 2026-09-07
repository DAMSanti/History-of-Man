extends SceneTree
## Cómo se ve un momento cuando salta, y el medidor del invierno de fondo.
##
## Los dos son de interfaz y ninguno se comprueba con una aserción: hay que
## verlos. Se corre la partida hasta que salta el primer [Moment] y se fotografía
## la pantalla entera, con su tarjeta y su medidor.
##
##   ESTACION=1   deja la partida en el último día de esa estación, para que el
##                cambio caiga enseguida (1 = verano, así entra el otoño)
##   TIPO=3       espera a un momento de ese tipo (ver `Moment.Kind`)

const SITE_ID := 56
const FRAMES := 30000


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
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("sin simulacion"); quit(); return

	if not OS.get_environment("ESTACION").is_empty():
		GameState.season = int(OS.get_environment("ESTACION")) as Subsistence.Season
		sim.season_day = Subsistence.DAYS_PER_SEASON - 1
	sim.hour = 11.0
	sim.time_scale = 30.0

	var caught: Array[Moment] = []
	# Se puede pedir un tipo concreto: si no, gana el primero que salte, que
	# casi siempre es un paraje bautizado.
	var wanted := -1
	if not OS.get_environment("TIPO").is_empty():
		wanted = int(OS.get_environment("TIPO"))
	sim.moment_raised.connect(func(moment: Moment) -> void:
		if wanted < 0 or int(moment.kind) == wanted:
			caught.append(moment))

	for frame in range(FRAMES):
		await process_frame
		if caught.is_empty():
			continue
		# Se deja pintar la tarjeta antes de la foto.
		for i in range(20):
			await process_frame
		var first: Moment = caught[0]
		print("momento: %s — %s" % [first.title, first.text])
		print("decision: %s · sitio: %s" % [first.is_decision(), first.has_place])
		root.get_texture().get_image().save_png("user://momento.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://"))
		quit()
		return

	print("no salto ningun momento")
	quit()
