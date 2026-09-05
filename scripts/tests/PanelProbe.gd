extends SceneTree
## Mide el panel de trabajos con una banda de verdad.
##
## Existe porque «se sale por la derecha» y «los botones no son iguales» son
## cosas que se ven, no que se razonan: la unica forma honrada de decir que
## caben es construir la tabla y medirla.


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4

	var sim := SettlementSim.new()
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.apply_priorities()

	var ui := GameUI.new()
	ui.sim = sim
	get_root().add_child(ui)
	ui.show_jobs()

	await process_frame
	await process_frame

	var frame: Control = ui._windows["trabajos"]
	var body: VBoxContainer = ui._bodies["trabajos"]
	var usable := body.custom_minimum_size.x

	print("=== PANEL DE TRABAJOS ===")
	print("   ventana: %d px · util: %d px" % [
		int(frame.custom_minimum_size.x), int(usable)])

	var widths := {}
	var heights := {}
	var widest := 0.0
	var rows := 0
	var people_seen := {}

	for child: Node in body.get_children():
		var row := _row_of(child)
		if row == null:
			continue
		rows += 1
		widest = maxf(widest, _row_width(row))
		for cell: Node in _cells_of(row):
			var control := cell as Control
			widths[int(control.custom_minimum_size.x)] = true
			heights[int(control.custom_minimum_size.y)] = true

	for person: Inhabitant in sim.people:
		people_seen[person.given_name] = 0
	for child: Node in body.get_children():
		var row := _row_of(child)
		if row == null:
			continue
		var first := row.get_child(0) as Label
		if first != null and people_seen.has(first.text):
			people_seen[first.text] = int(people_seen[first.text]) + 1

	print("   filas de persona: %d" % rows)
	print("   fila mas ancha: %d px -> %s" % [int(widest),
		"CABE" if widest <= usable else "SE SALE"])
	print("   anchos de casilla distintos: %d %s" % [widths.size(),
		"(todas iguales)" if widths.size() == 1 else str(widths.keys())])
	print("   altos de casilla distintos: %d" % heights.size())

	var repeated := 0
	var missing := 0
	for name_text: String in people_seen:
		var times := int(people_seen[name_text])
		if times > 1:
			repeated += 1
		elif times == 0:
			missing += 1
	print("   cada persona sale una vez: %s" % [
		"si" if repeated == 0 and missing == 0
		else "NO (%d repetidas, %d ausentes)" % [repeated, missing]])

	await _probe_store(ui, sim)
	quit()


## El almacen, que ahora ensena los veintisiete materiales siempre y en el
## mismo orden. Se comprueba que se dibuja y que el orden no baila.
func _probe_store(ui: GameUI, sim: SettlementSim) -> void:
	var first := await _store_order(ui, false)
	sim.store.add(Materia.Kind.LENA, 120.0)
	sim.store.add(Materia.Kind.CARNE, 30.0)
	var second := await _store_order(ui, false)

	# Y el utillaje, que era el que de verdad bailaba: iba ordenado por
	# cobertura, y la cobertura depende de la meta, asi que pulsar «+» mandaba
	# la pieza a otra fila y el boton se escapaba de debajo del cursor
	var tools_before := await _store_order(ui, true)
	sim.limits[Tool.Kind.AZAGAYA] = 40.0
	sim.limits[Tool.Kind.CESTO] = 1.0
	var tools_after := await _store_order(ui, true)

	print("=== ALMACEN ===")
	print("   materiales en la tabla: %d de %d" % [
		first.size(), Materia.Kind.size()])
	print("   orden estable tras guardar lena y carne: %s"
		% ["si" if first == second else "NO"])
	if first.size() > 0:
		print("   primero: %s · ultimo: %s" % [first[0], first[-1]])
	print("   piezas de utillaje: %d" % tools_before.size())
	print("   orden estable tras cambiar dos metas: %s"
		% ["si" if tools_before == tools_after else "NO"])


## Los nombres de material de la tabla, en el orden en que salen.
##
## Se espera un fotograma entre lecturas: `_clear` suelta los controles con
## `queue_free`, que no es inmediato, asi que sin la espera la segunda lectura
## ve la tabla vieja y la nueva juntas.
func _store_order(ui: GameUI, tools: bool) -> Array[String]:
	ui.show_store()
	await process_frame
	await process_frame
	var body: VBoxContainer = ui._bodies["almacen"]
	# Material y utillaje comparten armazon de fila, asi que hay que saber
	# cual es cual por el nombre
	var known := {}
	if tools:
		for kind: int in Tool.Kind.values():
			known[Tool.kind_name(kind as Tool.Kind)] = true
	else:
		for kind: int in Materia.Kind.values():
			known[Materia.material_name(kind as Materia.Kind)] = true

	var names: Array[String] = []
	for child: Node in body.get_children():
		var row := _row_of(child)
		if row == null:
			continue
		for cell: Node in row.get_children():
			var label := cell as Label
			if label != null and label.clip_text:
				if known.has(label.text):
					names.append(label.text)
				break
	return names


## La caja de una fila de persona: son PanelContainer con un HBox dentro.
func _row_of(child: Node) -> HBoxContainer:
	if child is not PanelContainer:
		return null
	for inner: Node in child.get_children():
		if inner is HBoxContainer:
			return inner as HBoxContainer
	return null


## Las casillas de una fila: van dentro de la caja de su oficio.
func _cells_of(row: HBoxContainer) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in row.get_children():
		if child is HBoxContainer:
			out.append_array(child.get_children())
	return out


func _row_width(row: HBoxContainer) -> float:
	var total := 0.0
	var count := 0
	for child: Node in row.get_children():
		var control := child as Control
		if control == null:
			continue
		count += 1
		if control is HBoxContainer:
			var inner := 0.0
			var cells := 0
			for cell: Node in control.get_children():
				inner += (cell as Control).custom_minimum_size.x
				cells += 1
			total += inner + float(maxi(cells - 1, 0)) * GameUI.CELL_GAP
		else:
			total += control.custom_minimum_size.x
	return total + float(maxi(count - 1, 0)) * GameUI.GROUP_GAP
