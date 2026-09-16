extends SceneTree
## La pestaña de Parajes abierta, para poder mirarla.
##
## Una ventana no se juzga con una cuenta: se juzga viéndola. Lo que hay que
## comprobar aquí es que cada paraje enseña SU PORCENTAJE de descubrimiento al
## lado, y que la lista va de mas cerca a mas lejos, que es el mismo orden en
## que los va a batir la banda.
##
##   DIAS=4   cuántas jornadas jugar antes de abrirla

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	var ui: Node = demo.ui
	_repartir(sim)
	sim.time_scale = 20.0

	var dias := 4
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame

	sim.time_scale = 0.0
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false

	# A 1280×720, que es la medida en la que hay que poder leer la ventana
	# (INTERFAZ §9): la ventana de la sonda abre a la del escritorio, y a
	# 3651×2054 todo se lee bien y no se comprueba nada.
	# VENTANA, y luego la medida: la partida arranca con lo que diga la
	# configuración del jugador —a pantalla completa aquí— y a pantalla completa
	# el tamaño que se pide se ignora sin decir nada (2026-09-16).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in range(10):
		await process_frame

	ui.sitios.show_places()
	for i in range(30):
		await process_frame

	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://parajes.png")
		print("captura en user://parajes.png · %d parajes" % sim.parajes.list.size())

	# Y LA MISMA LISTA FILTRADA (INTERFAZ §10): caza y pesca encendidas, y sólo
	# lo que queda a menos de un kilómetro del abrigo.
	FiltroDeParajes.para(sim)
	FiltroDeParajes.alternar(Subsistence.Activity.PESCA)
	FiltroDeParajes.alternar(Subsistence.Activity.MARISQUEO)
	FiltroDeParajes.poner_tramo(500.0)
	ui.sitios.show_places()
	for i in range(20):
		await process_frame
	var filtrada := get_root().get_texture().get_image()
	if filtrada != null:
		filtrada.save_png("user://parajes_filtrados.png")
		var salen := FiltroDeParajes.filtrar(sim.parajes.list,
			sim.home_position).size()
		print("captura en user://parajes_filtrados.png · %d de %d parajes"
			% [salen, sim.parajes.list.size()])
	FiltroDeParajes.todo()

	await _tooltip_de_una_tecnica(sim, ui)
	await _la_pasarela_en_obras(sim, ui)
	quit()


## La pasarela como una obra más, con su ficha (INTERFAZ §10).
##
## La pasarela se PONE, no se espera: armarla pide la técnica, un cruce, gente de
## exploración y cuarenta haces de leña, y eso son jornadas de reloj para mirar
## una ventana.
func _la_pasarela_en_obras(sim: Node, ui: Node) -> void:
	var cerca: Vector3 = sim.home_position + Vector3(60.0, 0.0, 40.0)
	sim.pasarelas.levantar([Pasarelas._centro_de_la_celda(cerca)], sim.day)
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false
	ui.obras._grupo = "obra:pasarela"
	ui.obras._indice = 0
	ui.obras.show_obras()
	for i in range(20):
		await process_frame
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://obras_pasarela.png")
		print("captura en user://obras_pasarela.png")


## El aviso emergente de una técnica, con su efecto y su «lo de hoy».
##
## EL ESTADO SE CONSTRUYE, no se juega: se dan por sabidas tres técnicas y se
## pone lo que la banda tendría, en vez de correr las jornadas que costarían
## (CLAUDE.md, «mide barato»).
func _tooltip_de_una_tecnica(sim: Node, ui: Node) -> void:
	sim.techs.known[TechTree.Tech.NUCLEO] = true
	sim.techs.known[TechTree.Tech.HOJA] = true
	sim.techs.known[TechTree.Tech.AZAGAYA] = true
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.6)
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.6)
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.6)
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false
	ui.tecnicas._tab = Profession.Job.CAZA
	ui.show_tech()
	for i in range(20):
		await process_frame

	# LA FICHA FIJA, que es lo que sustituye al aviso que se cerraba solo
	# (depurar del 2026-09-16): pinchar la azagaya y que se quede abierta.
	ui.tecnicas._elegida = TechTree.Tech.AZAGAYA
	ui.show_tech()
	for i in range(20):
		await process_frame
	var fija := get_root().get_texture().get_image()
	if fija != null:
		fija.save_png("user://tecnica_ficha.png")
		print("captura en user://tecnica_ficha.png")

	var casilla := _casilla_con(get_root(), "multiplica")
	if casilla == null:
		print("no se encontró ninguna casilla con efecto: "
			+ "el árbol abre en otra pestaña")
		return
	print("--- lo que dice la casilla ---")
	print(casilla.tooltip_text)
	# El aviso sale al posarse encima, como al jugar. Y no basta con llevar el
	# ratón: `warp_mouse` mueve el puntero pero no manda el movimiento por la
	# cola de sucesos, que es lo que arranca el temporizador del aviso
	# (2026-09-16). Así que se manda a mano, dos veces y quieto después.
	# EN COORDENADAS DE LA VENTANA, no del lienzo: el juego estira un lienzo de
	# 1920×1080 sobre una ventana de 1280×720 (`window/stretch/mode`), así que
	# la casilla que está en el 356 del lienzo está en el 237 de la ventana, y
	# el ratón se iba a otra parte sin que nada se quejara (2026-09-16).
	var centro: Vector2 = get_root().get_screen_transform() 		* casilla.get_global_rect().get_center()
	# La ventana, al frente: sin foco el aviso no llega a salir.
	DisplayServer.window_move_to_foreground()
	get_root().grab_focus()
	Input.warp_mouse(centro)
	for paso: Vector2 in [centro + Vector2(3.0, 3.0), centro]:
		var movimiento := InputEventMouseMotion.new()
		movimiento.position = paso
		movimiento.global_position = paso
		movimiento.relative = Vector2(3.0, 3.0)
		Input.parse_input_event(movimiento)
		for i in range(5):
			await process_frame
	for i in range(150):
		await process_frame
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://tecnica_tooltip.png")
		print("captura en user://tecnica_tooltip.png")


func _casilla_con(nodo: Node, palabra: String) -> Control:
	if nodo is CasillaTecnica and String((nodo as Control).tooltip_text).contains(palabra):
		return nodo as Control
	for hijo: Node in nodo.get_children():
		var encontrada := _casilla_con(hijo, palabra)
		if encontrada != null:
			return encontrada
	return null


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
		return null
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo


func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 3,
		Profession.Job.CAZA: 2,
		Profession.Job.RIBERA: 2,
		Profession.Job.EXPLORACION: 2,
	}
	for person: Inhabitant in sim.people:
		for job: int in Profession.Job.values():
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 0)
	for job: int in pendiente:
		for person: Inhabitant in sim.people:
			if pendiente[job] <= 0:
				break
			if person.priorities.size() > 0:
				continue
			if not Profession.can_do(job as Profession.Job, person):
				continue
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 1)
			pendiente[job] -= 1
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()
