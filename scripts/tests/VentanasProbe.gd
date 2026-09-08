extends SceneTree
## Que TODAS las ventanas de la interfaz se monten.
##
## `PanelProbe` mide dos -trabajos y almacen- y `FichaSitioProbe` las seis del
## sitio. Las demas no las abria nada: oficios, tecnicas, censo, la ficha de una
## entidad, la cronica, la banda, los rastros, el territorio y los controles.
##
## Una ventana que revienta al abrirse no falla ninguna prueba: se queda a
## medias y ya esta. Paso al sacar [PanelAlmacen] -veinte accesos rotos- y es
## justo lo que este proyecto no puede permitirse mientras se sigue troceando.
##
## Cuenta las filas que cuelgan de cada una. Cero filas es una ventana rota.


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	var terreno := FakeTerrain.new()
	get_root().add_child(terreno)
	sim.setup(terreno, Vector3(100.0, 0.0, 100.0), 15, 40.0)
	sim.apply_priorities()
	for kind: int in [Materia.Kind.CARNE, Materia.Kind.BAYA, Materia.Kind.SILEX,
			Materia.Kind.LENA, Materia.Kind.PIEL]:
		sim.store.add(kind as Materia.Kind, 30.0)
	sim.chronicle.record(sim.day, 0, 1, Chronicle.Kind.GENTE,
		"La banda se instala en el abrigo.", 2)

	var ui := GameUI.new()
	ui.sim = sim
	ui.tech = TechTree.new()
	ui.tech.larder = sim.store
	get_root().add_child(ui)
	get_root().add_child(sim)
	await process_frame

	print("")
	print("=== TODAS LAS VENTANAS ===")
	_mide(ui, "oficios", "oficios", func() -> void: ui.oficios.show_professions())
	_mide(ui, "tecnicas", "tecnicas", func() -> void: ui.oficios.show_tech())
	_mide(ui, "censo", "entidades", func() -> void: ui.censo.show_census())
	_mide(ui, "ficha de entidad", "entidad",
		func() -> void: ui.censo.show_entity("banda", 0, false))
	_mide(ui, "cronica", "cronica", func() -> void: ui.show_lore())
	_mide(ui, "banda", "banda", func() -> void: ui.show_band())
	_mide(ui, "trabajos", "trabajos", func() -> void: ui.show_jobs())
	_mide(ui, "almacen", "almacen", func() -> void: ui.show_store())
	_mide(ui, "rastros", "rastros", func() -> void: ui.show_trails())
	_mide(ui, "territorio", "territorio", func() -> void: ui.show_territory())
	_mide(ui, "controles", "controles", func() -> void: ui.show_controls())
	_mide(ui, "ficha de persona", "persona",
		func() -> void: ui.show_person(sim.people[0]))
	print("")
	quit()


## Abre una ventana y cuenta lo que ha pintado dentro.
func _mide(ui: GameUI, titulo: String, ventana: String, abrir: Callable) -> void:
	abrir.call()
	var body: VBoxContainer = ui._bodies.get(ventana)
	var hijos := body.get_child_count() if body != null else -1
	var texto := ""
	if body != null:
		for hijo: Node in body.get_children():
			if hijo is Label and not (hijo as Label).text.strip_edges().is_empty():
				texto = (hijo as Label).text.split("\n")[0]
				break
	print("  %-20s %3d filas   %s" % [
		titulo, hijos, texto.substr(0, 46) if hijos > 0 else "VACIA O ROTA"])
