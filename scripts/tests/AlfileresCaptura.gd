extends SceneTree
## Los alfileres de los parajes sobre el valle, para poder mirarlos.
##
## La queja era visual —«no son visibles con sus markers»— así que la
## comprobación tiene que serlo: se juegan unas jornadas, se sube la cámara y se
## dispara. Una cuenta dice cuántos hay; sólo la captura dice si se ven.
##
##   DIAS=15    cuántas jornadas jugar
##   ALTURA=1400  a qué distancia se pone la cámara

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
	sim.time_scale = 25.0

	var dias := 15
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame

	sim.time_scale = 0.0
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false

	var lejos := 1400.0
	if not OS.get_environment("ALTURA").is_empty():
		lejos = float(OS.get_environment("ALTURA"))
	if "camera" in demo and demo.camera != null:
		demo.camera.set_target(sim.home_position)
		demo.camera.set_distance(lejos)
		demo.camera.orbit_angle_v = -55.0
	for i in range(40):
		sim.hour = 12.0
		await process_frame

	print("")
	print("despensa: %.1f raciones" % sim.store.food_rations())
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		if Materia.is_food(k) and sim.store.amount(k) > 0.05:
			print("   %-16s %7.1f uds · %6.1f raciones" % [
				Materia.material_name(k), sim.store.amount(k),
				sim.store.amount(k) * Materia.nutrition(k)])
	print("parajes: %d · alfileres: %d" % [
		sim.parajes.list.size(),
		(demo.paraje_markers._markers as Dictionary).size()])
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://alfileres.png")
		print("captura en user://alfileres.png")
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
