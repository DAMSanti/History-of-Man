extends SceneTree
## Comprueba que una veta se puede agotar DE VERDAD jugando, y no solo en
## una prueba unitaria: que el gasto de una cuadrilla de canteros le gana a
## `regrow`, y que el dia que se acaba el paraje desaparece del mapa.

func _initialize() -> void:
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(400.0, 200.0, 400.0)
	sim._rng.seed = 5

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	sim.people = Inhabitant.create_band(8, sim.home_position, rng)
	for _person: Inhabitant in sim.people:
		sim._bodies.append(Node3D.new())
	sim.time_scale = 1.0
	sim.hour = 7.0

	sim.store.add(Materia.Kind.CARNE_SECA, 4000.0)
	sim.store.add(Materia.Kind.FRUTO_SECO, 4000.0)

	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))
	sim.knowledge.see_from(sim.home_position, 300.0)
	sim.chronicle = Chronicle.new()

	sim.field = ResourceField.new()
	sim.field.setup(32, 32, Vector2(2048.0, 2048.0))
	var spot := sim.home_position + Vector3(180.0, 0.0, 0.0)
	var cw := 2048.0 / 32.0
	sim.field.set_abundance(Subsistence.Activity.MATERIA_PRIMA,
		int(spot.x / cw), int(spot.z / cw), 1.0)
	sim.field.spread(Subsistence.Activity.MATERIA_PRIMA, 2)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cell := sim.field.cell_center(
				int(spot.x / cw) + dx, int(spot.z / cw) + dz)
			sim.knowledge.see_from(cell, 120.0)
			sim.knowledge.reveal(Subsistence.Activity.MATERIA_PRIMA, cell, 1.0)

	sim.parajes = Parajes.new()

	for person: Inhabitant in sim.people:
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 0)
		person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
			Profession.Speciality.CANTERA), 1)
	sim.apply_priorities()

	var seen := ""
	for day in range(400):
		for _tick in range(24 * 60):
			sim._process(sim.seconds_per_day / 24.0 / 60.0)
		var left := sim.field.stock_fraction_around(
			Subsistence.Activity.MATERIA_PRIMA, spot, 120.0)
		var names: Array[String] = []
		for p: Paraje in sim.parajes.list:
			names.append(p.name_text)
		var line := ", ".join(names)
		if line != seen or day % 25 == 0:
			seen = line
			print("dia %3d  queda %.3f  piedra %.1f  parajes: %s" % [
				sim.day, left, sim.store.amount(Materia.Kind.PIEDRA),
				line if line != "" else "ninguno"])
		if line == "" and day > 20:
			break

	print("=== CRONICA de penuria ===")
	for entry: Dictionary in sim.chronicle.entries:
		if int(entry["kind"]) == int(Chronicle.Kind.PENURIA):
			print("  d%d %s" % [int(entry["day"]), String(entry["text"])])
	quit()
