extends SceneTree
## Que la ficha de quien trabaja en el abrigo se abra y diga la verdad.
##
## El texto nuevo -«Talla raedera: 40 % de la pieza», «Levantando hogar»- solo
## corre cuando el jugador pincha a alguien, asi que ni las pruebas ni las
## sondas de simulacion lo tocan: una errata ahi no se ve hasta que la ve el
## jugador. Aqui se abre la ficha de cada uno a proposito.

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
	for i in range(60):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var ui: Node = demo.ui if "ui" in demo else null
	if sim == null or ui == null:
		print("sin simulacion o sin interfaz"); quit(); return

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	sim.time_scale = 20.0
	# Hasta media manana del segundo dia, que es cuando hay hogar en cola y
	# alguien tallando: con la partida recien empezada no hay ni una cosa ni
	# la otra y la ficha no diria nada.
	var first_day: int = sim.day
	while sim.day < first_day + 2 or sim.hour < 11.0:
		await process_frame

	print("")
	print("")
	print("=== EL ABRIGO, POR DENTRO ===")
	print("del punto del abrigo a la galeria: %.1f m (reparto %.1f)" % [
		sim.home_position.distance_to(sim.home_inside), SettlementSim.CAVE_SPREAD])
	print("del punto del abrigo a la campa:   %.1f m (reparto %.1f)" % [
		sim.home_position.distance_to(sim.home_forecourt),
		SettlementSim.FORECOURT_SPREAD])
	print("radio de llegada %.1f · alcance de «esta en casa» %.1f" % [
		sim.arrive_radius, sim._shelter_reach()])
	print("=== LAS FICHAS, A LAS %02d:00 DEL DIA %d ===" % [int(sim.hour), sim.day])
	var opened := 0
	var told := 0
	for person: Inhabitant in sim.people:
		ui.show_person(person)
		opened += 1
		var said := _panel_text(ui)
		var camp: bool = sim._works_at_camp(person)
		if camp and (said.contains("Talla ") or said.contains("Levantando ")):
			told += 1
		print("  %-6s %-12s %-12s | %s" % [
			person.given_name,
			Profession.job_name(person.job as Profession.Job),
			person.state_name(),
			said.replace("\n", " · ")])

	# Y lo que pidio el jugador: que la ficha se mueva sola. Se abre UNA, se
	# deja correr la partida sin volver a pintarla a mano, y se mira si el
	# texto cambia. Antes no cambiaba nunca: «persona» no estaba en la lista
	# de ventanas que se repintan.
	var watched: Inhabitant = sim.people[0]
	for person: Inhabitant in sim.people:
		if person.state == Inhabitant.State.YENDO:
			watched = person
			break
	ui.show_person(watched)
	await process_frame
	var first := _person_window_text(ui)
	var day_before: int = sim.day
	var hour_before: float = sim.hour
	for i in range(600):
		await process_frame
	var later := _person_window_text(ui)
	print("")
	print("=== LA FICHA, EN VIVO ===")
	print("mirando a %s · del dia %d %05.2fh al dia %d %05.2fh" % [
		watched.given_name, day_before, hour_before, sim.day, sim.hour])
	print("antes:   %s" % first.replace("
", " · "))
	print("despues: %s" % later.replace("
", " · "))
	print("cambia sola: %s" % ("si" if first != later else "NO"))

	print("")
	print("fichas abiertas sin reventar: %d" % opened)
	print("de abrigo, diciendo QUE hacen: %d" % told)
	quit()



## Lo que ya se habia leido, para poder quedarse solo con lo de la ficha
## recien abierta: el arbol de la interfaz conserva las ventanas anteriores.
var _already: int = 0

## Todo el texto de la VENTANA de persona, leido de ella y no del arbol
## entero. `_panel_text` se queda con lo nuevo desde la ultima llamada, y eso
## no vale cuando la ventana se reconstruye sola: los rotulos viejos se
## liberan y la cuenta deja de cuadrar.
func _person_window_text(ui: Node) -> String:
	var window: Variant = ui._windows.get("persona", null)
	if not is_instance_valid(window):
		return ""
	var found: Array[String] = []
	_gather(window as Node, found)
	return " ".join(found)


## Todo el texto de la ventana de persona, en una cadena.
func _panel_text(ui: Node) -> String:
	var found: Array[String] = []
	_gather(ui, found)
	var fresh := found.slice(_already)
	_already = found.size()
	return " ".join(fresh)


func _gather(node: Node, into: Array[String]) -> void:
	if node is Label and not (node as Label).text.is_empty():
		var text := (node as Label).text
		# Solo lo que interesa de la ficha: lo de «AHORA MISMO».
		if text.begins_with("Está ") or text.begins_with("Oficio") \
				or text.begins_with("Talla ") or text.begins_with("Levantando ") \
				or text.begins_with("Sin tarea") or text.begins_with("  · ") \
				or text.begins_with("Sin cesto"):
			into.append(text)
	for child: Node in node.get_children():
		_gather(child, into)
