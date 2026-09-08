extends SceneTree
## Que la ventana de tecnicas se abra, se dibuje y diga la verdad.
##
## Es la ventana que mas cosas junta -pestañas, arbol dibujado, flechas,
## avisos emergentes- y ninguna de ellas la tocan las pruebas: todo eso solo
## corre cuando el jugador la abre. Aqui se abre a proposito, se recorre cada
## pestaña y se saca una captura de cada una.
##
##   OFICIO=Caza   abrir solo esa

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
	for i in range(90):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var ui: Node = demo.ui if "ui" in demo else null
	var tree_data: TechTree = demo.tech if "tech" in demo else null
	if sim == null or ui == null or tree_data == null:
		print("sin simulacion, interfaz o arbol"); quit(); return

	sim.assign_default_jobs()
	# Con la partida recien empezada no hay ni jornadas ni material, y entonces
	# el arbol sale entero apagado y no se ve si las flechas y los estados
	# funcionan. Se le da practica y despensa a proposito.
	for activity: int in Subsistence.Activity.values():
		tree_data.practice_days[activity] = 90.0
	for kind: int in [Materia.Kind.PIEDRA, Materia.Kind.FIBRA, Materia.Kind.LENA,
			Materia.Kind.ASTA, Materia.Kind.HUESO, Materia.Kind.TENDON]:
		sim.store.add(kind as Materia.Kind, 40.0)
	sim.time_scale = 0.0

	print("")
	print("=== EL ARBOL, OFICIO A OFICIO ===")
	for job: int in TechTree.BRANCHES:
		ui.oficios._tech_tab = job
		ui.oficios.show_tech()
		for i in range(6):
			await process_frame
		var graph := _find_graph(ui)
		if graph == null:
			print("%-14s SIN ARBOL DIBUJADO" % Profession.job_name(
				job as Profession.Job))
			continue
		var boxes := 0
		var with_tip := 0
		for child: Node in graph.get_children():
			if child is PanelContainer:
				boxes += 1
				if not (child as Control).tooltip_text.is_empty():
					with_tip += 1
		print("%-14s %d tecnicas · %d con aviso · lienzo %.0f x %.0f" % [
			Profession.job_name(job as Profession.Job), boxes, with_tip,
			graph.custom_minimum_size.x, graph.custom_minimum_size.y])
		var branch: Array = TechTree.BRANCHES[job]
		if boxes != branch.size():
			print("   OJO: la rama tiene %d y se pintan %d" % [
				branch.size(), boxes])

	# Y el almacen, que ahora dice PRODUCE en el mismo periodo que GASTA: si esa
	# columna reventara o saliera en blanco no se veria en ninguna prueba.
	ui.show_store()
	for i in range(6):
		await process_frame
	print("")
	print("=== EL ALMACEN ===")
	print("cabeceras: %s" % ", ".join(_ledger_lines(ui)))
	# Lo que no se sabe hacer no se lista. Se compara la ventana con el
	# catalogo entero: lo que sobra es lo que se ensenaba de mas.
	var listed := _tool_names(ui)
	var hidden: Array[String] = []
	for kind: int in Tool.Kind.values():
		var name := Tool.kind_name(kind as Tool.Kind)
		if not listed.has(name):
			hidden.append("%s (%s)" % [name,
				"no se sabe" if not sim.taller.knows_tool(kind as Tool.Kind) else "OJO"])
	print("piezas listadas: %d de %d" % [listed.size(), Tool.Kind.values().size()])
	print("no listadas: %s" % ", ".join(hidden))
	print("odres llenos en el abrigo: %.0f · odres que existen: %d" % [
		sim.store.amount(Materia.Kind.AGUA), sim.toolkit.count(Tool.Kind.ODRE)])
	# Y con odres de verdad: el almacen tiene que contarlos, no tener agua suelta.
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL, 0.5)
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL, 0.5)
	sim.despensa._sync_waterskins()
	print("con dos odres hechos y nadie fuera: %.0f llenos" % sim.store.amount(
		Materia.Kind.AGUA))
	sim.despensa._hand_out_containers(sim.people[0])
	print("uno se lo lleva alguien: %.0f llenos, y el lleva agua para %.1f h" % [
		sim.store.amount(Materia.Kind.AGUA), sim.people[0].water_left])
	sim.despensa._deliver(sim.people[0])
	print("vuelve y lo cuelga: %.0f llenos" % sim.store.amount(Materia.Kind.AGUA))

	# Y una vista del valle con los parajes, para mirar los alfileres nuevos.
	if not OS.get_environment("MAPA").is_empty():
		for id: String in ui._windows.keys():
			(ui._windows[id] as Control).visible = false
		var camera: Node = demo.camera if "camera" in demo else null
		if camera != null:
			camera.set_target(sim.home_position)
			camera.set_distance(float(OS.get_environment("MAPA")))
			camera.orbit_angle_v = -38.0
		# Unas jornadas para que la banda bautice varios sitios, y luego el
		# reloj clavado a mediodia: de noche no se ven los alfileres.
		sim.time_scale = 20.0
		for i in range(900):
			await process_frame
		sim.time_scale = 0.0
		for i in range(40):
			sim.hour = 12.0
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot != null:
			shot.save_png("user://mapa.png")
			print("mapa guardado · %d parajes" % sim.parajes.list.size())
		quit()
		return

	# Y la captura de la pestaña que se pida, para poder mirarla.
	var wanted := OS.get_environment("OFICIO")
	for job: int in TechTree.BRANCHES:
		if wanted.is_empty() or Profession.job_name(
				job as Profession.Job) == wanted:
			ui.oficios._tech_tab = job
			ui.oficios.show_tech()
			for i in range(10):
				await process_frame
			var image := get_root().get_texture().get_image()
			if image != null:
				image.save_png("user://arbol_%d.png" % job)
				print("captura de %s guardada" % Profession.job_name(
					job as Profession.Job))
			break
	# Las reglas nuevas: sin recipientes al empezar, y el hogar sin repartir.
	print("")
	print("=== AL EMPEZAR ===")
	print("cestos hechos: %d · odres: %d" % [
		sim.toolkit.count(Tool.Kind.CESTO), sim.toolkit.count(Tool.Kind.ODRE)])
	print("especialidades del hogar: %d" % Profession.specialities_of(
		Profession.Job.HOGAR).size())
	print("una racion son %.0f kcal · un dia %.0f kcal · un adulto %.1f raciones" % [
		Materia.KCAL_RACION, Materia.KCAL_DIA, sim.people[0].daily_food()])
	print("raciones por unidad: fruto seco %.2f · carne %.2f · carne seca %.2f" % [
		Materia.nutrition(Materia.Kind.FRUTO_SECO),
		Materia.nutrition(Materia.Kind.CARNE),
		Materia.nutrition(Materia.Kind.CARNE_SECA)])

	# La barra de arriba: reloj, banda e invierno juntos.
	print("")
	# Se mete carne y pescado fresco A PROPOSITO: en una partida normal la banda
	# se lo come segun entra, y sin nada perecedero en el abrigo no hay merma
	# que enseñar. Lo que se viene a comprobar es que la cifra LLEGA a la barra.
	sim.store.add(Materia.Kind.CARNE, 60.0)
	sim.store.add(Materia.Kind.PESCADO, 60.0)
	sim.time_scale = 20.0
	for i in range(700):
		await process_frame
	sim.time_scale = 0.0
	for i in range(20):
		await process_frame
	print("se pudrio ayer: %.2f raciones · %s" % [
		sim.spoiled_rations_today, str(sim.spoiled_today)])
	print("perecedero en el abrigo: carne %.1f · pescado %.1f · baya %.1f" % [
		sim.store.amount(Materia.Kind.CARNE), sim.store.amount(Materia.Kind.PESCADO),
		sim.store.amount(Materia.Kind.BAYA)])
	# Y el camino del dato, que es lo que se viene a comprobar: en esta partida
	# la banda se come lo perecedero antes de que se pudra -no sobra nada-, asi
	# que la cifra se pone a mano y se mira si la barra la recoge.
	sim.spoiled_rations_today = 3.7
	ui.barra._update_band_gauge()
	print("con merma puesta a mano: %s" % ui._band_label.text)
	sim.spoiled_rations_today = 0.0
	ui.barra._update_band_gauge()
	print("y sin ella:              %s" % ui._band_label.text)

	print("=== LA BARRA DE ARRIBA ===")
	for line: String in _hud_lines(ui):
		print("   %s" % line)

	print("")
	print("carpeta: %s" % ProjectSettings.globalize_path("user://"))
	quit()


## Las cabeceras de la tabla del almacen, para ver que dicen su periodo.
func _ledger_lines(node: Node) -> Array[String]:
	var out: Array[String] = []
	_gather_headers(node, out)
	return out


func _gather_headers(node: Node, into: Array[String]) -> void:
	if node is Label:
		var text := (node as Label).text
		if text == "HAY" or text.begins_with("GASTA") or text.begins_with("PRODUCE") 				or text == "META":
			into.append(text)
	for child: Node in node.get_children():
		_gather_headers(child, into)


## Los nombres de pieza que la ventana del almacen esta enseñando.
func _tool_names(ui: Node) -> Array[String]:
	var out: Array[String] = []
	var window: Variant = ui._windows.get("almacen", null)
	if not is_instance_valid(window):
		return out
	var every: Array[String] = []
	_gather_labels(window as Node, every)
	for kind: int in Tool.Kind.values():
		if every.has(Tool.kind_name(kind as Tool.Kind)):
			out.append(Tool.kind_name(kind as Tool.Kind))
	return out


func _gather_labels(node: Node, into: Array[String]) -> void:
	if node is Label:
		into.append((node as Label).text)
	for child: Node in node.get_children():
		_gather_labels(child, into)


## Lo que dice la barra de arriba, que es lo primero que se mira.
func _hud_lines(ui: Node) -> Array[String]:
	var out: Array[String] = []
	for name: String in ["_clock", "_band_label", "_winter_label"]:
		var label: Variant = ui.get(name)
		if is_instance_valid(label):
			out.append((label as Label).text)
	return out


func _find_graph(node: Node) -> TechGraph:
	if node is TechGraph:
		return node as TechGraph
	for child: Node in node.get_children():
		var found := _find_graph(child)
		if found != null:
			return found
	return null
