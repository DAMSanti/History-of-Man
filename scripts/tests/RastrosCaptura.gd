extends SceneTree
## Los rastros de la banda sobre el valle, para poder mirarlos.
##
## Es la vista con la que el jugador vio el problema: una recta larga hasta el
## río y un ovillo apretado pegado al agua, varias personas en el mismo punto.
## Una cuenta no dice si eso sigue ahí; la vista sí.
##
##   DIAS=4     cuántas jornadas jugar antes de mirar
##   OFICIO=1   qué oficio pintar (por defecto, recolección)
##   ALTURA=900

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	var ui: Node = demo.ui
	_repartir(sim)
	sim.time_scale = 3.0

	var dias := 4
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame

	sim.time_scale = 0.0
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false

	# Todos los rastros de todos los oficios, uno encima de otro: lo que se
	# busca es el amontonamiento, y con un solo oficio no se ve.
	var lejos := 900.0
	if not OS.get_environment("ALTURA").is_empty():
		lejos = float(OS.get_environment("ALTURA"))
	if "camera" in demo and demo.camera != null:
		demo.camera.set_target(sim.home_position)
		demo.camera.set_distance(lejos)
		demo.camera.orbit_angle_v = -85.0

	var pintados := 0
	for job: int in [Profession.Job.RECOLECCION, Profession.Job.CAZA,
			Profession.Job.RIBERA, Profession.Job.EXPLORACION]:
		ui.trails.show_job(job, sim.people, sim.terrain(), sim.day)
		pintados += 1
		for i in range(6):
			sim.hour = 12.0
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot != null:
			shot.save_png("user://rastros_%d.png" % job)
			print("rastro de %s en user://rastros_%d.png" % [
				Profession.job_name(job as Profession.Job), job])
	quit()


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
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo


func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 4,
		Profession.Job.CAZA: 3,
		Profession.Job.RIBERA: 2,
		Profession.Job.EXPLORACION: 2,
	}
	for person: Inhabitant in sim.people:
		for job: int in Profession.Job.values():
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 0)
	for job: int in pendiente:
		for person: Inhabitant in sim.people:
			if pendiente[job] <= 0:
				break
			if person.priorities.size() > 0:
				continue
			if not Profession.can_do(job as Profession.Job, person):
				continue
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 1)
			pendiente[job] -= 1
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()
