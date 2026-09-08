extends SceneTree
## Por qué los pescadores salen y no pescan.
##
## «Salen y no pescan» puede ser cuatro cosas muy distintas —no llegan, llegan y
## no encuentran, encuentran y no cobran, o cobran y se pudre— y las cuatro se
## ven igual desde fuera: un montón de pescado que no sube. Esto separa las
## cuatro: por cada jornada dice en qué estado está cada uno de la ribera, a qué
## distancia de su tajo, cuántas horas ha apuntado y qué ha entrado al almacén.
##
##   DIAS=20        cuántas jornadas seguir
##   ESPECIALIDAD=orilla|marisqueo   a cuál poner a la banda

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

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	var wanted := Profession.Speciality.ORILLA
	if OS.get_environment("ESPECIALIDAD") == "marisqueo":
		wanted = Profession.Speciality.MARISQUEO

	var task := Profession.task_id(Profession.Job.RIBERA, wanted)
	var sent := 0
	for person: Inhabitant in sim.people:
		if sent >= 5 or not Profession.can_do(Profession.Job.RIBERA, person):
			continue
		for job: int in Profession.Job.values():
			for other: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(other, 0)
		person.set_priority(task, 3)
		person.speciality = wanted
		sent += 1
	sim.apply_priorities()
	sim.time_scale = 20.0

	var activity := Profession.activity_of(Profession.Job.RIBERA, wanted)
	print("")
	print("tajo de %s: %s" % [Subsistence.activity_name(activity),
		sim.work_sites.get(activity, "NO HAY")])
	print("forma de pescar: %s" % Fishing.method_name(
		sim.fishing_method() as Fishing.Method))
	print("")

	var days := 20
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	var first_day: int = sim.day
	var last_day: int = sim.day
	# Se mide MIENTRAS TRABAJAN, no al cambiar de día: al cambiar de día están
	# durmiendo en la cueva, y preguntar allí si tienen agua al lado no dice
	# nada de dónde pescan.
	var working := 0
	var beside := 0
	while sim.day < first_day + days:
		await process_frame
		for person: Inhabitant in sim.people:
			if person.job != Profession.Job.RIBERA:
				continue
			if person.state != Inhabitant.State.TRABAJANDO:
				continue
			working += 1
			if sim.tajo._water_beside(person.position):
				beside += 1
		if sim.day == last_day:
			continue
		last_day = sim.day
		print("dia %d · conocidos %d · almacen pescado %.1f marisco %.1f" % [
			sim.day, (sim._known_spots.get(activity, []) as Array).size(),
			sim.store.amount(Materia.Kind.PESCADO),
			sim.store.amount(Materia.Kind.MARISCO)])
		for person: Inhabitant in sim.people:
			if person.job != Profession.Job.RIBERA:
				continue
			print("   %-6s %-12s %-13s tajo a %5.0f m · agua al lado %s · horas %s" % [
				person.given_name,
				Profession.speciality_name(
					person.current_speciality as Profession.Speciality),
				person.state_name(),
				person.position.distance_to(person.target),
				"si" if sim.tajo._water_beside(person.position) else "NO",
				_hours(person)])

	print("")
	print("trabajando junto al agua: %d de %d momentos (%.0f %%)" % [
		beside, working, 100.0 * float(beside) / maxf(float(working), 1.0)])
	quit()


## Las horas que lleva apuntadas hoy en su tarea, tal como las cuenta el libro
## de trabajo: es la diferencia entre «no sale» y «sale y no cobra».
func _hours(person: Inhabitant) -> String:
	var log_entry: Dictionary = person.work_log.get(person.current_task(), {})
	return "%.1f" % float(log_entry.get("hours", 0.0))
