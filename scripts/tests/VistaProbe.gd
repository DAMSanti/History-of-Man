extends SceneTree
## Una captura de la partida de verdad, a la hora que se pida.
##
## No mide nada: enseña. Las pruebas de luz -[SombraDiaProbe]- montan su propia
## cámara y esconden la interfaz para que la medida no dependa de ellas, con lo
## que lo que fotografían NO es lo que ve el jugador. Ésta arranca la escena tal
## cual, con su cámara orbital y su interfaz, y guarda lo que se vería.
##
## Se gobierna por entorno, para no tocar el código al cambiar de encuadre:
##
##   HORAS=6,13,19   qué horas de la partida fotografiar (por defecto, la de
##                   arranque)
##   VISTA=vista     con qué nombre guardar las capturas
##   ESPERA=600      cuántos fotogramas dejar correr la simulación antes de la
##                   primera captura, para pillar a la banda ya en movimiento

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
	for i in range(240):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("sin simulacion"); quit(); return

	var wait := int(OS.get_environment("ESPERA")) if not OS.get_environment("ESPERA").is_empty() else 0
	for i in range(wait):
		await process_frame

	var name := OS.get_environment("VISTA")
	if name.is_empty():
		name = "vista"
	var hours := OS.get_environment("HORAS")
	var wanted: Array[float] = []
	if hours.is_empty():
		wanted.append(sim.hour)
	else:
		for piece: String in hours.split(","):
			wanted.append(float(piece.strip_edges()))

	for hour: float in wanted:
		sim.hour = hour
		for i in range(30):
			await process_frame
		var shot := root.get_texture().get_image()
		var file := "user://%s_%02d.png" % [name, int(hour)]
		shot.save_png(file)
		print("captura %s · hora %.1f" % [file, hour])

	print("en %s" % ProjectSettings.globalize_path("user://"))
	quit()
