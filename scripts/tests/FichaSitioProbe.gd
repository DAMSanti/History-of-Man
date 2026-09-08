extends SceneTree
## Que las fichas del sitio se monten de verdad.
##
## Son las que responden «que hay donde has pinchado»: el suelo desnudo, un
## paraje con nombre, una cumbre, un recurso del suelo, una boca de cueva y la
## lista de sitios conocidos. NO las cubre ninguna prueba y `PanelProbe` no las
## abre, asi que hasta ahora la unica forma de saber que seguian en pie era
## jugar y pinchar.
##
## Y hace falta: al sacar [PanelAlmacen] se quedaron veinte accesos rotos y la
## ventana del almacen reventaba al abrirse sin que nada lo dijera. Esto cuenta
## los hijos que cuelgan de cada ficha: una ficha que revienta se queda a
## medias, y una que se monta entera tiene sus filas.


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5

	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.apply_priorities()
	for kind: int in [Materia.Kind.CARNE, Materia.Kind.BAYA, Materia.Kind.SILEX]:
		sim.store.add(kind as Materia.Kind, 30.0)

	# Con terreno de mentira: `show_ground` pregunta altura y pendiente, y sin
	# terreno se sale por «Sin asentamiento» sin llegar a montar nada.
	var terreno := FakeTerrain.new()
	get_root().add_child(terreno)
	sim.setup(terreno, Vector3(100.0, 0.0, 100.0), 15, 40.0)

	var ui := GameUI.new()
	ui.sim = sim
	ui.tech = TechTree.new()
	get_root().add_child(ui)
	get_root().add_child(sim)
	await process_frame

	print("")
	print("=== LAS FICHAS DEL SITIO ===")

	_mide(ui, "suelo desnudo", "terreno",
		func() -> void: ui.show_ground(Vector3(120.0, 0.0, 80.0), terreno))

	var paraje := Paraje.new()
	paraje.activity = Subsistence.Activity.RECOLECCION
	paraje.position = Vector3(200.0, 0.0, 150.0)
	paraje.name_text = "El Avellanar"
	_mide(ui, "paraje con nombre", "paraje",
		func() -> void: ui.show_paraje(paraje))

	_mide(ui, "cumbre", "cima", func() -> void: ui.show_peak({
		"pos": Vector3(900.0, 300.0, 900.0), "rise": 180.0,
		"command": 120.0, "hardness": 0.4}))

	_mide(ui, "lista de sitios", "parajes", func() -> void: ui.show_places())

	_mide(ui, "recurso del suelo", "recurso", func() -> void: ui.show_resource(
		Materia.Kind.SILEX, Vector3(300.0, 0.0, 300.0),
		Subsistence.Activity.MATERIA_PRIMA))

	_mide(ui, "boca de cueva", "lugar", func() -> void: ui.show_feature(
		{"kind": "cueva", "name": "Cueva de los Pendios"},
		Vector3(50.0, 0.0, 50.0), Vector3.ZERO))

	print("")
	quit()


## Abre una ficha y cuenta lo que ha pintado dentro.
func _mide(ui: GameUI, titulo: String, ventana: String, abrir: Callable) -> void:
	abrir.call()
	var body: VBoxContainer = ui._bodies.get(ventana)
	var hijos := body.get_child_count() if body != null else -1
	var texto := ""
	if body != null:
		for hijo: Node in body.get_children():
			if hijo is Label and not (hijo as Label).text.is_empty():
				texto = (hijo as Label).text.split("\n")[0]
				break
	print("  %-20s %2d filas   %s" % [
		titulo, hijos, texto.substr(0, 52) if hijos > 0 else "VACIA O ROTA"])
