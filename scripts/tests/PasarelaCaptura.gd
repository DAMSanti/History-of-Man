extends SceneTree
## La pasarela sobre el cauce, para poder mirarla.
##
## Criterio del frente 13 de EPOCA_01 §10.1, tanda 3: «la pasarela se ve en su
## tramo». Una prueba dice que la obra existe y abre el paso; sólo una captura
## dice si se ve, y **las capturas necesitan ventana**: con `--headless`,
## `get_texture().get_image()` devuelve null.
##
## No se juega hasta que la banda la levante sola —eso son jornadas y una
## técnica por aprender—: se **construye el estado**, que es la regla de
## ARQUITECTURA §5.1. Se busca un cauce cerca del abrigo, se levanta allí, y se
## mira.
##
##   ALTURA=220   a qué distancia se pone la cámara

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: SettlementSim = demo.sim
	var ui: GameUI = demo.ui
	sim.time_scale = 0.0
	for i in range(30):
		await process_frame

	# EL PASO MÁS ESTRECHO que haya cerca del abrigo, que es donde la banda
	# construiría: la regla no deja salvar más de `Pasarelas.CELDAS_DE_ANCHO`
	# celdas de agua. Se puntúa cada celda mojada por cuánta agua tiene
	# alrededor y se coge la que menos: en un valle con río, eso es el
	# afluente o el estrechamiento, no la mitad del cauce.
	var celda := Vector3.ZERO
	var encontrada := false
	var mejor_agua := 99
	for radio in range(40, 900, 20):
		for paso in range(48):
			var angulo := TAU * float(paso) / 48.0
			var punto: Vector3 = sim.home_position + Vector3(
				cos(angulo) * float(radio), 0.0, sin(angulo) * float(radio))
			if Hydrography.can_cross(
					demo.terrain.crossing_difficulty_at(punto), false, false):
				continue
			var agua := _agua_alrededor(demo.terrain, punto)
			if agua < mejor_agua:
				mejor_agua = agua
				celda = Pasarelas._centro_de_la_celda(punto)
				encontrada = true
		if encontrada and mejor_agua <= 4:
			break
	print("agua alrededor del paso elegido: %d muestras de 24" % mejor_agua)
	if not encontrada:
		print("no hay cauce cerca del abrigo: nada que cruzar")
		quit()
		return

	celda.y = demo.terrain.get_height_at(celda)
	print("cauce a %.0f m del abrigo, en %s" % [
		sim.home_position.distance_to(celda), str(celda)])
	sim.pasarelas.levantar([celda])
	print("pasarelas levantadas: %d · version %d" % [
		sim.pasarelas.puentes.size(), sim.pasarelas.version])
	print("¿abre el paso? %s" % str(sim.pasarelas.hay_en(celda)))
	# La vista se repinta al cerrar la jornada, y aquí el reloj está parado: se
	# le pide lo mismo que le pide la escena. Ver [DemoMain._on_day_passed].
	if demo.pasarela_view != null:
		demo.pasarela_view.refresh(sim.pasarelas, demo.terrain)

	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false

	var lejos := 220.0
	if not OS.get_environment("ALTURA").is_empty():
		lejos = float(OS.get_environment("ALTURA"))
	if "camera" in demo and demo.camera != null:
		demo.camera.set_target(celda)
		demo.camera.set_distance(lejos)
		demo.camera.orbit_angle_v = -35.0
	for i in range(60):
		sim.hour = 12.0
		await process_frame

	var vistos := 0
	if demo.pasarela_view != null:
		vistos = demo.pasarela_view.get_child_count()
	print("troncos dibujados: %d" % vistos)

	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://pasarela.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://pasarela.png"))
	else:
		print("sin captura: ¿se ha lanzado con --headless?")
	quit()


## Cuánta agua hay alrededor de un punto: muestras que no se vadean en una
## cruz de doscientos metros. Cuanto menos, más estrecho es el paso.
func _agua_alrededor(terrain: TerrainGenerator, punto: Vector3) -> int:
	var mojadas := 0
	for eje: Vector3 in [Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0),
			Vector3(0.7, 0.0, 0.7), Vector3(0.7, 0.0, -0.7)]:
		for lado: float in [1.0, -1.0]:
			for salto in range(1, 4):
				var donde: Vector3 = punto + eje * lado * (Navgrid.CELL * float(salto))
				if not Hydrography.can_cross(
						terrain.crossing_difficulty_at(donde), false, false):
					mojadas += 1
	return mojadas


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
		return null
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	return current_scene
