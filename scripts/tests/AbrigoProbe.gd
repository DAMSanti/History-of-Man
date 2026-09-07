extends SceneTree
## El abrigo visto de cerca: la hoguera, la gente y la boca de la cueva.
##
## Tres cosas que sólo se comprueban mirando: que la hoguera esté delante de la
## boca y alumbre de noche, que la banda se reparta —dentro a dormir, en la
## campa a lo demás— en vez de apilarse en un punto, y que el bosque llegue
## hasta la puerta.
##
##   HORA=22      a qué hora mirar
##   ORBITA=45    a qué distancia poner la cámara

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
	var sim: Node = demo.sim if "sim" in demo else null
	var camera: Node = demo.camera if "camera" in demo else null
	if sim == null or camera == null:
		print("sin simulacion o camara"); quit(); return

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	# El hogar, dado por levantado y encendido: lo que se mira aquí es cómo se
	# ve, no cuánto tarda la banda en construirlo.
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.hearth_lit = true

	var hour := 22.0
	if not OS.get_environment("HORA").is_empty():
		hour = float(OS.get_environment("HORA"))
	sim.hour = hour

	var orbit := 45.0
	if not OS.get_environment("ORBITA").is_empty():
		orbit = float(OS.get_environment("ORBITA"))

	print("")
	print("abrigo en %s" % sim.home_position)
	print("dentro   %s" % sim.home_inside)
	print("campa    %s" % sim.home_forecourt)

	camera.set_target(sim.home_forecourt if sim.home_forecourt != Vector3.ZERO
		else sim.home_position)
	camera.set_distance(orbit)
	camera.orbit_angle_v = -24.0
	_hide_ui(demo)

	# La partida arranca en pausa: sin dejarla correr nadie cambia de estado y
	# todo el mundo se queda como se fundó. Se le clava la hora a cada cuadro
	# para mirar siempre el mismo momento del día.
	sim.time_scale = 3.0
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 12000:
		await process_frame
		sim.hour = hour

	var inside := 0
	var outside := 0
	for person: Inhabitant in sim.people:
		if person.position.distance_to(sim.home_position) > 40.0:
			continue
		if sim.home_inside != Vector3.ZERO \
				and person.position.distance_to(sim.home_inside) < 4.5:
			inside += 1
		else:
			outside += 1
	# Y los que se quedan A MEDIAS: ni dentro ni en la campa, plantados en el
	# canchal a la vista del jugador. Es lo que salia de dar por llegado a
	# quien agotaba el camino lejos de la boca -ver `_home_reached`- sin
	# recogerlo despues.
	var scree := 0
	for person: Inhabitant in sim.people:
		var off := person.position.distance_to(sim.home_position)
		if off > sim._shelter_reach() and off <= Navgrid.CELL:
			scree += 1
	print("en el abrigo: %d dentro · %d en la campa" % [inside, outside])
	print("en el canchal, a %d-%d m: %d" % [
		int(sim._shelter_reach()), int(Navgrid.CELL), scree])

	root.get_texture().get_image().save_png("user://abrigo_%02d.png" % int(hour))
	print("captura en %s" % ProjectSettings.globalize_path("user://"))
	quit()


func _hide_ui(node: Node) -> void:
	var layer := node as CanvasLayer
	if layer != null:
		layer.visible = false
		return
	for child in node.get_children():
		_hide_ui(child)
