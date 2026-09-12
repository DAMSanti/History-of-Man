extends SceneTree
## Que es lo que CRECE con los dias, que es lo que hace que los tirones se
## vuelvan mas comunes segun avanza la partida.
##
## La queja: «a medida que pasan los dias los tirones se hacen mucho mas
## comunes». Un tiron que empeora con el tiempo no es un calculo caro: es algo
## que se acumula y que nadie tira. Y no se encuentra mirando el peor fotograma
## -ahi solo se ve el sintoma, y en este caso encima sale como «SIN EXPLICAR»,
## porque lo que cuesta es PINTAR lo acumulado, no calcularlo-.
##
## Asi que aqui no se mira el fotograma: se miran LOS MONTONES. Cada jornada se
## apunta el tamaño de todo lo que puede crecer, y al final se enseña la tabla.
## Lo que crezca sin parar es el culpable.
##
##   DIAS=16   cuantas jornadas seguir

const SITE_ID := 56

var _filas: Array[String] = []

## Las mallas por nodo de vista el primer dia, para poder restar.
var _primer_dia: Dictionary = {}


## Cuantas mallas cuelgan de cada nodo con nombre de la escena.
##
## Es lo que de verdad cuesta pintar, y lo que crece cuando los tirones se
## vuelven mas comunes con los dias. Se cuenta por RAMA para saber a quien
## pedirle cuentas.
func _mallas() -> Dictionary:
	var out := {}
	var raiz := current_scene
	if raiz == null:
		return out
	for hijo: Node in raiz.get_children():
		out[hijo.name] = _mallas_bajo(hijo)
	return out


func _mallas_bajo(nodo: Node) -> int:
	var n := 1 if nodo is VisualInstance3D else 0
	for hijo: Node in nodo.get_children():
		n += _mallas_bajo(hijo)
	return n


func _init() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	_repartir(sim)
	sim.time_scale = 20.0

	# CON LOS RASTROS PUESTOS, que es como jugaba quien se quejo: la ventana
	# de rastros abierta es la que dispara el dibujo que crece.
	if "ui" in demo and demo.ui != null and demo.ui.trails != null:
		demo.ui.trails.show_job(Profession.Job.RECOLECCION, sim.people,
			sim.terrain(), sim.day)

	var dias := 16
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== QUE CRECE CON LOS DIAS ===")
	print("")
	print("  dia  cuadro  nodos  objetos  dibujos  parajes  huellas  salidas  "
		+ "rastro  cronica  cacerias  rutas  hitos  bichos  RAM  estacion  rejilla  cola  lejos")

	var primero: int = sim.day
	var ultimo := -1
	var t_cuadro := 0.0
	var cuadros := 0
	while sim.day < primero + dias:
		await process_frame
		t_cuadro += Engine.get_frames_per_second()
		cuadros += 1
		if sim.day == ultimo:
			continue
		ultimo = sim.day
		_apuntar(sim, t_cuadro / maxf(float(cuadros), 1.0))
		if _primer_dia.is_empty():
			_primer_dia = _mallas()
		t_cuadro = 0.0
		cuadros = 0

	for fila: String in _filas:
		print(fila)

	# Y QUIEN PONE ESOS OBJETOS. La tabla dice que el pintado crece; esto
	# dice de quien son las cosas nuevas. Se cuentan las mallas colgadas de
	# cada nodo de vista, el primer dia y el ultimo.
	print("")
	print("--- MALLAS POR NODO DE VISTA (dia 1 -> hoy) ---")
	var hoy := _mallas()
	var nombres: Array = hoy.keys()
	nombres.sort_custom(func(a: String, b: String) -> bool:
		return int(hoy[a]) - int(_primer_dia.get(a, 0)) \
			> int(hoy[b]) - int(_primer_dia.get(b, 0)))
	for nombre: String in nombres:
		var antes := int(_primer_dia.get(nombre, 0))
		var ahora := int(hoy[nombre])
		if ahora == 0 and antes == 0:
			continue
		print("   %-28s %5d -> %5d   %+d" % [nombre, antes, ahora, ahora - antes])
	print("")
	print("Lo que crezca sin parar es lo que hay que atar. Un monton que sube")
	print("con los dias y nadie tira sale en el panel como «SIN EXPLICAR»,")
	print("porque lo que cuesta es PINTARLO.")
	quit()


## Cuantos animales lleva vivos el valle.
func _bichos() -> int:
	var raiz := current_scene
	if raiz == null or not ("herds" in raiz) or raiz.herds == null:
		return 0
	return (raiz.herds._animals as Array).size()


## Con que caudal se midio la rejilla que se esta usando ahora mismo.
##
## Es lo que dice si la banda anda con los caminos de SU estacion o con los
## de la anterior: en verano el caudal es 0,60 y en primavera 1,25. Si a
## mitad de verano sigue diciendo 1,25, la rejilla nueva no ha llegado.
## Cuantos parajes con nombre estan hoy fuera del alcance, y por que motivo.
##
## Es la queja: «en el cambio de primavera a verano hay muchos parajes que se
## ponen en no alcanzable cuando deberian ser alcanzables perfectamente».
func _no_alcanzables(sim: Node) -> int:
	var fuera := 0
	for pj: Paraje in sim.parajes.list:
		if not sim.marcha.por_que_no_se_llega(pj.position).is_empty():
			fuera += 1
	return fuera


func _caudal_de_la_rejilla(sim: Node) -> float:
	var grid: Navgrid = sim.marcha._navgrid()
	return grid.built_with_caudal if grid != null else 0.0


func _pendientes(sim: Node) -> int:
	return sim.horno.pendientes() if sim.horno != null else 0


func _apuntar(sim: Node, fps: float) -> void:
	var salidas := 0
	var hitos := 0
	for p: Inhabitant in sim.people:
		salidas += p.journeys.size()
		hitos += p.route.size()

	var huellas := 0
	for pj: Paraje in sim.parajes.list:
		if pj.huella != null:
			huellas += 1

	var cacerias := 0
	if sim.caceria != null:
		cacerias = sim.caceria.hunts.size()

	var cronica := 0
	if sim.chronicle != null and "entries" in sim.chronicle:
		cronica = (sim.chronicle.entries as Array).size()

	var rastro := 0
	for p2: Inhabitant in sim.people:
		rastro += p2.trail.size()

	_filas.append("  %3d  %6.1f  %5d  %7d  %7d  %7d  %7d  %7d  %6d  %7d  %8d  %5d  %5d  %6d  %4d MB  %-8s  %7.2f  %4d  %5d" % [
		int(sim.day), fps,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		sim.parajes.list.size(), huellas, salidas, rastro, cronica, cacerias,
		(sim.knowledge as BandKnowledge).veredas_recordadas(), hitos, _bichos(),
		int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0),
		Subsistence.season_name(GameState.season as Subsistence.Season).substr(0, 4),
		_caudal_de_la_rejilla(sim), _pendientes(sim), _no_alcanzables(sim)])


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


## El mismo reparto que usa PasoProbe, con exploracion de sobra: los atascos
## que se buscan son de batida y de expedicion.
func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 3,
		Profession.Job.CAZA: 3,
		Profession.Job.RIBERA: 2,
		Profession.Job.EXPLORACION: 4,
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
