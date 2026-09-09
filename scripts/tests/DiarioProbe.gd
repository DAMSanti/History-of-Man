extends SceneTree
## La crónica de una persona, tal y como se va a leer.
##
## Es la petición literal del jugador: «detalle paso a paso lo que ha hecho esa
## persona. Desayunó a las XX:XX, salió de batida a las XX:XX, ha descubierto
## raíces a X metros de la cueva a las XX:XX... DÍA 2 despertó a las XX:XX». Y
## «vamos a empezar de momento con los exploradores y recolectores, haz la
## crónica lo más detallada posible».
##
## Aquí se saca a la consola lo que va a salir en la pestaña, que es la única
## forma de juzgar si se lee como una jornada o como un volcado de estados.
##
##   DIAS=3   cuántas jornadas seguir
##   QUIEN=   parte del nombre, para mirar sólo a una persona

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sim := await _arrancar()
	if sim == null:
		quit()
		return
	_repartir(sim)
	sim.time_scale = 20.0

	var dias := 3
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var quien := OS.get_environment("QUIEN")

	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame

	print("")
	print("=== LA CRONICA, PERSONA A PERSONA ===")
	for person: Inhabitant in sim.people:
		# Exploradores y recolectores, que es por donde se pidio empezar.
		if person.job != Profession.Job.EXPLORACION \
				and person.job != Profession.Job.RECOLECCION:
			continue
		if not quien.is_empty() and not person.given_name.contains(quien):
			continue

		print("")
		print("--- %s · %s ---" % [person.given_name,
			Profession.job_name(person.job as Profession.Job)])
		var jornadas := person.diario.jornadas()
		jornadas.reverse()
		for dia: int in jornadas:
			print("  DIA %d" % dia)
			for apunte: Dictionary in person.diario.del_dia(dia):
				print("    %s  %s" % [
					Diario.reloj(float(apunte["hora"])),
					String(apunte["texto"])])
		if jornadas.is_empty():
			print("    (sin nada apuntado)")
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
	for i in range(90):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo.sim


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
