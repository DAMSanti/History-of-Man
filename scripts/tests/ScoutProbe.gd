extends SceneTree
## Sigue a un explorador al que se le manda un sitio, hora a hora.
##
## Se escribe porque «se queda parado mirando al infinito» es una observacion
## del jugador, y la unica forma honrada de arreglarla es reproducirla: correr
## la simulacion de verdad e imprimir donde esta y que hace en cada hora.


func _initialize() -> void:
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(400.0, 200.0, 400.0)
	sim._rng.seed = 3

	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	sim.people = Inhabitant.create_band(15, sim.home_position, rng)
	for _person: Inhabitant in sim.people:
		sim._bodies.append(Node3D.new())
	sim.time_scale = 1.0
	sim.hour = 7.0

	# Lo que la escena monta de verdad: sin despensa no hay expedicion, y sin
	# mapa mental `_scout_target` devuelve el propio campamento
	sim.store.add(Materia.Kind.CARNE_SECA, 300.0)
	sim.store.add(Materia.Kind.FRUTO_SECO, 300.0)
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))
	sim.knowledge.see_from(sim.home_position, 200.0)
	sim.chronicle = Chronicle.new()

	# Uno solo, y a explorar: asi se lee el rastro
	var scout: Inhabitant = null
	for person: Inhabitant in sim.people:
		for task: int in Profession.tasks_of(Profession.Job.EXPLORACION):
			person.set_priority(task, 0)
		# El resto, a recolectar: asi se ve si los oficios que no son
		# exploracion dejan rastro
		# Por ESPECIALIDAD: la recoleccion ya no es un boton sino tres
		person.set_priority(Profession.task_id(
			Profession.Job.RECOLECCION, Profession.Speciality.FORRAJEO), 2)
		person.set_priority(Profession.task_id(
			Profession.Job.RECOLECCION, Profession.Speciality.LENA_FIBRA), 3)
		if scout == null and Profession.can_do(Profession.Job.EXPLORACION, person):
			scout = person
	for task: int in Profession.tasks_of(Profession.Job.EXPLORACION):
		scout.set_priority(task, 0)
	scout.set_priority(Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION), 1)

	# Y otro a la batida, que es radio corto: sin el no se puede comprobar que
	# una batida llegue a terminar y deje su linea
	var beater: Inhabitant = null
	for person: Inhabitant in sim.people:
		if person != scout and Profession.can_do(Profession.Job.EXPLORACION, person):
			beater = person
			break
	if beater:
		beater.set_priority(Profession.task_id(Profession.Job.EXPLORACION,
			Profession.Speciality.BATIDA), 1)
	sim.apply_priorities()

	var order := Vector3(900.0, 200.0, 900.0)
	sim.reconocimiento.scout_towards(order)

	print("=== EXPLORADOR ===")
	print("   %s sale de %s hacia %s" % [scout.given_name,
		_short(sim.home_position), _short(order)])

	var last_state := -1
	var last_report := -1.0
	var walked := 0.0
	var previous := scout.position
	var survey_walked := 0.0
	var survey_cells := {}
	var _nodes_total := 0
	var _worst_frame := 0
	var idle_survey_minutes := 0
	var finished := 0

	# Cuatro jornadas de juego, a paso de un minuto de reloj por vuelta
	for tick in range(25 * 24 * 60):
		# Un minuto de reloj de juego por vuelta
		sim._process(sim.seconds_per_day / 24.0 / 60.0)
		# Se informa POR EL CAMINO: una tirada larga que se corta antes de
		# llegar al final no imprime nada, y entonces no se ha medido nada
		if tick % (10 * 24 * 60) == 0 and tick > 0:
			var line := "   dia %3d:" % sim.day
			for who: Inhabitant in sim.people:
				if who.job != Profession.Job.EXPLORACION:
					continue
				var recent := 0
				for trip: Dictionary in who.journeys:
					if int(trip["day"]) > sim.day - 10:
						recent += 1
				line += "  %s %d salidas (fat %.0f)" % [
					who.given_name, recent, who.fatigue]
			var stuck_now := 0
			for why: String in sim.stuck_tally:
				stuck_now += int(sim.stuck_tally[why])
			print(line + "  · atascos %d" % stuck_now)

		_nodes_total += sim._path_nodes_this_frame
		_worst_frame = maxi(_worst_frame, sim._path_nodes_this_frame)
		var step := previous.distance_to(scout.position)
		walked += step
		if scout.state == Inhabitant.State.RECONOCIENDO:
			survey_walked += step
			survey_cells["%d_%d" % [int(scout.position.x / 64.0),
				int(scout.position.z / 64.0)]] = true
			if step < 0.5:
				idle_survey_minutes += 1
		if last_state == int(Inhabitant.State.RECONOCIENDO) 				and scout.state != Inhabitant.State.RECONOCIENDO:
			finished += 1
		previous = scout.position

		var hour := sim.hour
		var changed := int(scout.state) != last_state
		var due := absf(hour - last_report) >= 1.0
		if false:
			last_state = int(scout.state)
			last_report = hour
			print("   d%d %05.2fh  %-13s %s  andado %4d m  reconocido %.1f h" % [
				sim.day, hour, _state_name(scout.state),
				_short(scout.position), int(walked), scout.survey_hours])

	print("=== LIBRO DE TRABAJO ===")
	for person: Inhabitant in sim.people:
		var rows := person.work_summary()
		if rows.is_empty():
			continue
		var line := "   %-8s" % person.given_name
		for entry: Dictionary in rows:
			var got: Array[String] = []
			for key: int in (entry["gained"] as Dictionary):
				var units := float((entry["gained"] as Dictionary)[key])
				if units >= 0.05:
					got.append("%.0f %s" % [units,
						SettlementSim.logged_name(key).to_lower()])
			for what: String in (entry["deeds"] as Dictionary):
				got.append("%s x%d" % [what,
					int((entry["deeds"] as Dictionary)[what])])
			line += "  [%s %.1fh %s]" % [
				Profession.task_name(int(entry["task"])), float(entry["hours"]),
				", ".join(got) if not got.is_empty() else "SIN NADA"]
		print(line)

	print("=== FORENSE DE ATASCOS ===")
	print(sim.stuck_report_text())

	print("=== ATASCOS ===")
	var total_stuck := 0
	for why: String in sim.stuck_tally:
		total_stuck += int(sim.stuck_tally[why])
	print("   %d en 40 jornadas" % total_stuck)
	for why: String in sim.stuck_tally:
		print("   %4dx  %s" % [int(sim.stuck_tally[why]), why])

	print("=== UNIDADES DEL ALMACEN ===")
	print("   cargas perdidas por no pasar por el abrigo: %d" % sim.lost_loads)
	print("   abrigo al %.0f%% de su capacidad (%s de %s)" % [
		sim.store.fullness() * 100.0,
		Materia.format_volume(sim.store.total_litres()),
		Materia.format_volume(sim.store.capacity_litres)])
	var brought := {}
	for person: Inhabitant in sim.people:
		for entry: Dictionary in person.work_summary():
			for key: int in (entry["gained"] as Dictionary):
				if key >= 0:
					brought[key] = float(brought.get(key, 0.0)) + float((entry["gained"] as Dictionary)[key])
	for key: int in brought:
		var kind := key as Materia.Kind
		print("   %-12s traido %6.0f · en el almacen %6.0f · vida %d dias" % [
			Materia.material_name(kind), float(brought[key]),
			sim.store.amount(kind), Materia.shelf_life(kind)])

	print("=== SE MANTIENE LA BANDA? ===")
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	print("   %d personas comen %.1f raciones al dia" % [
		sim.population(), mouths])
	print("   despensa: %.0f raciones = %.1f jornadas" % [
		sim.store.food_rations(), sim.store.days_of_food(mouths)])

	# Lo que trae CADA oficio, sumando lo que quedo apuntado en el libro
	var got := {}
	var hours := {}
	for person: Inhabitant in sim.people:
		for entry: Dictionary in person.work_summary():
			var job := Profession.task_job(int(entry["task"]))
			hours[job] = float(hours.get(job, 0.0)) + float(entry["hours"])
			for key: int in (entry["gained"] as Dictionary):
				if key < 0:
					continue
				var kind := key as Materia.Kind
				if not Materia.is_food(kind):
					continue
				got[job] = float(got.get(job, 0.0)) + float((entry["gained"] as Dictionary)[key]) * Materia.nutrition(kind)
	for job: int in hours:
		print("   %-14s %6.0f h de trabajo -> %6.0f raciones (%.2f por hora)" % [
			Profession.job_name(job as Profession.Job), float(hours[job]),
			float(got.get(job, 0.0)),
			float(got.get(job, 0.0)) / maxf(float(hours[job]), 0.001)])

	print("   comidas en 40 jornadas: %.0f raciones" % (mouths * 40.0))

	print("=== DESPENSA ===")
	print("   raciones: %.0f · carne seca %.0f · fruto seco %.0f · grasa %.0f" % [
		sim.store.food_rations(),
		sim.store.amount(Materia.Kind.CARNE_SECA),
		sim.store.amount(Materia.Kind.FRUTO_SECO),
		sim.store.amount(Materia.Kind.GRASA)])
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.EXPLORACION:
			print("   %s: oficio %s · %s · fatiga %.0f · lleva %.1f raciones" % [
				person.given_name,
				Profession.job_name(person.job as Profession.Job),
				Profession.speciality_name(
					person.current_speciality as Profession.Speciality),
				person.fatigue, sim.despensa.pack_rations(person)])

	print("=== EXPLORACION A LO LARGO DE 40 JORNADAS ===")
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.EXPLORACION:
			continue
		var by_ten := [0, 0, 0, 0, 0, 0, 0]
		for trip: Dictionary in person.journeys:
			var bucket := clampi(int(trip["day"]) / 10, 0, 6)
			by_ten[bucket] += 1
		print("   %-8s (%s) salidas por decena: %d %d %d %d %d %d %d" % [
			person.given_name,
			Profession.speciality_name(person.current_speciality as Profession.Speciality),
			by_ten[0], by_ten[1], by_ten[2], by_ten[3], by_ten[4], by_ten[5], by_ten[6]])
		print("       fatiga %.0f · hambre %.0f · %d cumbres coronadas · frontera %s" % [
			person.fatigue, person.hunger, sim.cumbres._climbed.size(),
			"agotada" if sim._comarca_known else "abierta"])

	print("=== CRONICA ===")
	if sim.chronicle:
		var counts := {}
		for entry: Dictionary in sim.chronicle.entries:
			var line: String = String(entry["text"])
			var key := line.substr(line.find(" ") + 1, 34)
			counts[key] = int(counts.get(key, 0)) + 1
		print("   %d apuntes en cuatro jornadas" % sim.chronicle.entries.size())
		for key: String in counts:
			if int(counts[key]) > 1:
				print("   REPETIDO x%d: %s..." % [int(counts[key]), key])

	print("=== SALIDAS ===")
	for person: Inhabitant in sim.people:
		if person.journeys.is_empty() and person.journey.is_empty():
			continue
		print("   %s (%s):" % [person.given_name,
			Profession.speciality_name(
				person.current_speciality as Profession.Speciality)])
		for trip: Dictionary in person.journeys:
			print("      d%d-%d %-12s %5.1f km · lejos %4d m · %s · %s" % [
				int(trip["day"]), int(trip["ended"]), String(trip["kind"]),
				float(trip["metres"]) / 1000.0, int(float(trip["farthest"])),
				String(trip["place"]), String(trip["outcome"])])
			var path: PackedVector3Array = trip.get("path", PackedVector3Array())
			if path.size() < 2:
				print("         (sin camino guardado: no se podra dibujar)")
		if not person.journey.is_empty():
			print("      EN MARCHA    %5.1f km · lejos %4d m" % [
				float(person.journey["metres"]) / 1000.0,
				int(float(person.journey["farthest"]))])

	print("=== COSTE DE CAMINOS ===")
	print("   rejilla construida en %d ms, una vez" % sim.grid_build_ms)
	print("   caminos guardados: %d" % sim._route_cache.size())
	print("   nodos de busqueda en toda la partida: %d" % _nodes_total)
	print("   fotograma mas caro: %d nodos (~%.1f ms)" % [
		_worst_frame, float(_worst_frame) * 0.008])
	print("   TOTAL andado %d m · de ellos %d m batiendo la zona" % [
		int(walked), int(survey_walked)])
	print("   reconocimientos terminados: %d" % finished)
	print("   celdas distintas batidas: %d" % survey_cells.size())
	print("   minutos QUIETO reconociendo: %d" % idle_survey_minutes)
	if sim.knowledge:
		var seen := 0
		for value: float in sim.knowledge.explored:
			if value > 0.05:
				seen += 1
		print("   mapa conocido: %.1f%%" % [
			100.0 * float(seen) / float(sim.knowledge.explored.size())])
	quit()


func _short(point: Vector3) -> String:
	return "(%4d,%4d)" % [int(point.x), int(point.z)]


func _state_name(state: int) -> String:
	for key: String in Inhabitant.State.keys():
		if int(Inhabitant.State[key]) == state:
			return key
	return "?"
