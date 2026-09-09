extends SceneTree
## La pestaña de Parajes abierta, para poder mirarla.
##
## Una ventana no se juzga con una cuenta: se juzga viéndola. Lo que hay que
## comprobar aquí es que cada paraje enseña SU PORCENTAJE de descubrimiento al
## lado, y que la lista va de mas cerca a mas lejos, que es el mismo orden en
## que los va a batir la banda.
##
##   DIAS=4   cuántas jornadas jugar antes de abrirla

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
	sim.time_scale = 20.0

	var dias := 4
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame

	sim.time_scale = 0.0
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false

	ui.sitios.show_places()
	for i in range(30):
		await process_frame

	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://parajes.png")
		print("captura en user://parajes.png · %d parajes" % sim.parajes.list.size())
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
		Profession.Job.RECOLECCION: 3,
		Profession.Job.CAZA: 2,
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
