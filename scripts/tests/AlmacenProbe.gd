extends SceneTree
## Que filas de utillaje salen de verdad en el Almacen. No es una prueba: es
## para contestar «no aparece la nasa en el utillaje» mirando el panel de
## verdad y no la tabla que lo alimenta.

func _init() -> void:
	var sim := SettlementSim.new()
	root.add_child(sim)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	for i in range(15):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		sim.people.append(person)
	for i in range(3):
		Profession.assign(Profession.Job.RIBERA, sim.people[i],
			Profession.Speciality.ORILLA)
	for i in range(3, 10):
		Profession.assign(Profession.Job.RECOLECCION, sim.people[i],
			Profession.Speciality.FORRAJEO)

	var ui := GameUI.new()
	ui.sim = sim
	ui.tech = TechTree.new()
	sim.techs = ui.tech
	root.add_child(ui)
	ui.show_store()

	await process_frame
	await process_frame

	print("=== FILAS DE UTILLAJE EN EL ALMACEN ===")
	var found := _labels(ui._bodies["almacen"])
	for kind: int in Tool.Kind.values():
		var name_text := Tool.kind_name(kind as Tool.Kind)
		print("  %-10s %s" % [name_text,
			"SALE" if found.has(name_text) else "NO SALE"])
	print("=== demanda: %s" % JSON.stringify(sim.taller.tool_demand()))
	quit()


## Todos los textos de etiqueta que hay colgando de un nodo.
func _labels(node: Node) -> Array[String]:
	var out: Array[String] = []
	var label := node as Label
	if label:
		out.append(label.text)
	for child: Node in node.get_children():
		out.append_array(_labels(child))
	return out
