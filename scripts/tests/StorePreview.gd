extends SceneTree
## Vista del panel de Almacén con datos de mentira, para poder mirarlo sin
## montar el terreno entero. No es una prueba: es una herramienta de vista.

func _init() -> void:
	var back := ColorRect.new()
	back.color = Color(0.22, 0.26, 0.20)
	back.size = Vector2(900, 720)
	root.add_child(back)

	var sim := SettlementSim.new()
	root.add_child(sim)

	# Una banda de quince con oficios repartidos
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	for i in range(15):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		sim.people.append(person)
	for i in range(3):
		Profession.assign(Profession.Job.CAZA, sim.people[i])
	for i in range(3, 5):
		Profession.assign(Profession.Job.RIBERA, sim.people[i])
	for i in range(5, 11):
		Profession.assign(Profession.Job.RECOLECCION, sim.people[i])
	for i in range(11, 13):
		Profession.assign(Profession.Job.MANUFACTURA, sim.people[i])
	for i in range(13, 15):
		Profession.assign(Profession.Job.EXPLORACION, sim.people[i])
	sim.people[11].speciality = Profession.Speciality.TALLA
	sim.people[11].current_speciality = Profession.Speciality.TALLA
	sim.people[13].speciality = Profession.Speciality.ASCENSION
	sim.people[13].current_speciality = Profession.Speciality.ASCENSION
	for person: Inhabitant in sim.people:
		person.set_priority(person.job, 1)

	sim.store = Storehouse.new()
	sim.store.capacity_litres = 12000.0
	sim.store.add(Materia.Kind.FRUTO_SECO, 62.0)
	sim.store.add(Materia.Kind.CARNE, 14.0)
	sim.store.add(Materia.Kind.LENA, 9.0)
	sim.store.add(Materia.Kind.PIEDRA, 4.0)
	sim.store.add(Materia.Kind.FIBRA, 11.0)
	sim.store.add(Materia.Kind.ASTA, 2.0)
	sim.store.add(Materia.Kind.PIEL, 3.0)
	sim.store.add(Materia.Kind.MARISCO, 21.0)
	sim.store.add(Materia.Kind.OCRE, 1.0)
	sim.limits[Materia.Kind.LENA] = 20.0

	sim.toolkit = Toolkit.new()
	for i in range(5):
		sim.toolkit.craft(Tool.Kind.LASCA, Tool.Stuff.CUARCITA, 0.5)
	sim.toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA, 0.5)
	sim.toolkit.craft(Tool.Kind.BURIL, Tool.Stuff.SILEX, 0.7)
	for i in range(4):
		sim.toolkit.craft(Tool.Kind.CESTO, Tool.Stuff.FIBRA, 0.5)
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.5)
	sim.toolkit.pieces[0].wear(20.0)
	sim.set_tool_order(Tool.Kind.AZAGAYA, 4)

	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.queue_project(CampProjects.Kind.SECADERO)
	sim.camp_progress = 1.1

	sim.day = 34
	sim.hour = 11.25
	GameState.season = Subsistence.Season.OTONO
	GameState.year = 1

	var ui := GameUI.new()
	ui.sim = sim
	root.add_child(ui)
	ui.show_jobs()

	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	image.save_png("user://trabajos.png")

	# Y la mitad de abajo, que es donde cae la tabla de utillaje
	var scroll := ui._bodies["trabajos"].get_parent() as ScrollContainer
	scroll.scroll_vertical = 100000
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("user://trabajos2.png")

	print("paneles guardados en %s"
		% ProjectSettings.globalize_path("user://trabajos.png"))
	quit()
