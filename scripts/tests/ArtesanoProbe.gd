extends SceneTree
## Qué se ve de un artesano trabajando.
##
## El criterio del bloque es «con solo mirar a un artesano se ve qué pieza está
## haciendo y cuánto le falta, sin clicar nada», y eso no se comprueba con una
## aserción: hay que ponerse delante y mirar. Esto pone al taller a trabajar,
## espera a pillar a alguien fabricando y hace la foto desde la distancia a la
## que se juega.

const SITE_ID := 56

## Cuántos fotogramas se espera como mucho a pillar a alguien fabricando.
const FRAMES := 6000


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

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	# El taller no arranca solo si nadie lo pide: se pone gente a mano, que es
	# lo que haría el jugador.
	sim.set_job_count(Profession.Job.MANUFACTURA, 3)
	sim.set_job_count(Profession.Job.RECOLECCION, 6)
	sim.time_scale = 12.0

	var camera := Camera3D.new()
	camera.far = 4000.0
	demo.add_child(camera)

	var found: Inhabitant = null
	var work := {}
	for frame in range(FRAMES):
		await process_frame
		for person: Inhabitant in sim.people:
			var doing: Dictionary = sim.crafting_now(person)
			# Se espera a que lleve algo hecho: una barra a cero no enseña que
			# la barra funcione.
			if doing.is_empty() or float(doing["progress"]) < 0.15:
				continue
			found = person
			work = doing
			break
		if found != null:
			break

	if found == null:
		print("nadie llego a fabricar nada"); quit(); return

	print("")
	print("%s hace %s · lleva %.0f %%" % [found.given_name,
		Tool.kind_name(int(work["tool"]) as Tool.Kind),
		100.0 * float(work["progress"])])

	# A la distancia a la que se juega de verdad, no pegado a la cara.
	var head := found.position + Vector3(0.0, 1.7, 0.0)
	camera.global_position = head + Vector3(14.0, 9.0, 14.0)
	camera.look_at(head, Vector3.UP)
	camera.make_current()
	# El artesano no se mueve del abrigo, así que no hace falta parar el mundo:
	# y parándolo, los marcadores no llegarían a montarse para esta cámara.
	for i in range(30):
		await process_frame
	root.get_texture().get_image().save_png("user://artesano.png")
	print("captura en %s" % ProjectSettings.globalize_path("user://"))
	quit()
