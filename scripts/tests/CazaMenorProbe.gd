extends SceneTree
## Por qué se atasca la caza menor.
##
## En la ventana de rastros, la caza menor sale con TODAS sus salidas cerradas
## con «atascado: no avanza por el camino trazado», y siempre en el mismo
## paraje. Ese motivo lo escribe `SettlementSim._stuck_reason` cuando la persona
## tiene ruta, el siguiente hito es pisable, y aun así no se ha movido en horas.
## O sea: el camino existe, el suelo deja pasar, y el paso no se da.
##
## Eso son varias cosas posibles a la vez —el hito de al lado, la velocidad a
## cero, el esquive de orilla comiéndose el paso, el carril— y desde fuera se
## ven igual. Aquí se saca el detalle de cada tick de quien está atascándose:
## dónde está, adónde va, cuántos hitos le quedan, a qué distancia el siguiente
## y cuánto se ha movido de verdad.

const SITE_ID := 56
const FRAMES := 4200


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
	if sim == null:
		print("sin simulacion"); quit(); return

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	# Toda la banda que pueda, a caza menor.
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MENOR)
	var sent := 0
	for person: Inhabitant in sim.people:
		if sent >= 5 or not Profession.can_do(Profession.Job.CAZA, person):
			continue
		for job: int in Profession.Job.values():
			for other: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(other, 0)
		person.set_priority(task, 3)
		person.speciality = Profession.Speciality.CAZA_MENOR
		sent += 1
	sim.apply_priorities()
	sim.time_scale = 12.0

	var last: Dictionary = {}
	var still: Dictionary = {}
	var told := 0

	var first_day: int = sim.day
	for frame in range(FRAMES):
		await process_frame
		# El registro de atascos tiene tope y la primera mañana lo llena entera
		# con el arranque de la partida: se vacía pasada esa mañana para que
		# quepa lo que se viene a mirar.
		if sim.day == first_day + 1:
			sim.stuck_reports.clear()
		for person: Inhabitant in sim.people:
			if person.job != Profession.Job.CAZA:
				continue
			var before: Vector3 = last.get(person.id, person.position)
			var moved := before.distance_to(person.position)
			last[person.id] = person.position
			if person.state != Inhabitant.State.YENDO \
					and person.state != Inhabitant.State.VOLVIENDO:
				still[person.id] = 0
				continue
			if moved > 0.05:
				still[person.id] = 0
				continue
			still[person.id] = int(still.get(person.id, 0)) + 1
			# Un cuarto de segundo quieto YENDO ya es sospechoso; se cuenta
			# una vez por persona y episodio para no llenar la consola.
			if int(still[person.id]) != 30 or told > 24:
				continue
			told += 1
			_tell(sim, person)

	# Lo que de verdad se venía a arreglar: que las salidas dejen de cerrarse
	# como atasco y que la caza traiga algo.
	var trips := 0
	var stuck_trips := 0
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.CAZA:
			continue
		for trip: Dictionary in person.journeys:
			trips += 1
			if String(trip.get("outcome", "")).contains("atascado"):
				stuck_trips += 1

	print("")
	print("salidas de caza: %d · cerradas como atasco: %d" % [trips, stuck_trips])
	print("almacen: %.1f carne · %.1f piel · %.1f pluma · %.1f hueso" % [
		sim.store.amount(Materia.Kind.CARNE), sim.store.amount(Materia.Kind.PIEL),
		sim.store.amount(Materia.Kind.PLUMA), sim.store.amount(Materia.Kind.HUESO)])
	print("episodios de parada mirados: %d" % told)
	print("atascos por motivo: %s" % str(sim.stuck_tally))
	print("")
	# El propio juego ya guarda el parte completo de cada atasco: se lee de ahí
	# en vez de intentar pillarlo en el aire desde fuera.
	# El informe forense entero, que ya lo sabe escribir el propio juego.
	print(sim.marcha.stuck_report_text())
	quit()


## El parte de una persona parada: todo lo que decide su paso, en una línea.
func _tell(sim: Node, person: Inhabitant) -> void:
	var next_point := person.next_waypoint()
	var to_target := next_point - person.position
	to_target.y = 0.0
	var grid: Navgrid = sim.marcha._navgrid()
	print("%-6s %-11s hito %d/%d a %6.1f m · destino a %6.1f m · %s" % [
		person.given_name, person.state_name(),
		person.route_step, person.route.size(), to_target.length(),
		person.position.distance_to(person.target),
		"pisable" if grid.passable(person.position) else "EN SUELO CERRADO"])
	print("       siguiente hito %s · paso libre %s · bloqueos %d · fatiga %.0f" % [
		"pisable" if grid.passable(next_point) else "CERRADO",
		"si" if sim.marcha._can_step_into(next_point) else "NO",
		person.blocked_steps, person.fatigue])
	print("       carga %.0f%% · terreno %.2f de velocidad" % [
		person.load_fraction() * 100.0,
		sim.marcha._terrain_speed(person, to_target.normalized()) / maxf(sim.walk_speed, 0.001)])
