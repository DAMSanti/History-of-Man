extends SceneTree
## Si la caza compensa mas segun sube el armamento.
##
## Medido antes: en ocho jornadas salian TRES caceria -dos con el rastro frio y
## una cobrada- y cuatro de siete salidas de caza volvian de vacio. La pregunta
## que queda es si eso es el principio de una curva o es el oficio entero.
##
## El arma no da punteria: da ALCANCE -azagaya 16 m, propulsor por dos- y el
## alcance es justo lo que decide si un acecho llega al lance o se enfria. Asi
## que la hipotesis es que la caza no se arregla afinando el acierto sino
## llegando a tirar, y eso se comprueba escalon a escalon.
##
## Cada escalon corre las mismas jornadas con la misma semilla y se apunta:
## caceria abiertas, como acaban, piezas cobradas y raciones por cazador y dia.
##
## CADA ESCALON PIDE PARTIDA NUEVA, y por eso la sonda corre UNO y sale: al
## encadenarlos en la misma partida, el tercero heredaba una banda hambrienta y
## sin filo del segundo -toda la banda a la caza, nadie recolectando- y medi
## «no se abre ni una caceria» cuando lo que pasaba es que no habia banda.
##
##   DIAS=8       jornadas
##   ESCALON=2    cual de los cinco (0 a 4). Obligatorio.

const SITE_ID := 56

## Los escalones, de menos a mas. Cada uno anade lo del anterior.
const ESCALONES := [
	{"nombre": "a mano", "armas": [], "tecnicas": []},
	{"nombre": "azagaya", "armas": [Tool.Kind.AZAGAYA],
		"tecnicas": [TechTree.Tech.AZAGAYA]},
	{"nombre": "+ propulsor", "armas": [Tool.Kind.AZAGAYA],
		"tecnicas": [TechTree.Tech.AZAGAYA, TechTree.Tech.PROPULSOR]},
	{"nombre": "+ ojeo", "armas": [Tool.Kind.AZAGAYA],
		"tecnicas": [TechTree.Tech.AZAGAYA, TechTree.Tech.PROPULSOR,
			TechTree.Tech.OJEO]},
	{"nombre": "+ arco", "armas": [Tool.Kind.AZAGAYA],
		"tecnicas": [TechTree.Tech.AZAGAYA, TechTree.Tech.PROPULSOR,
			TechTree.Tech.OJEO, TechTree.Tech.ARCO]},
]


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
	if sim == null:
		print("sin simulacion"); quit(); return

	var days := 8
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))
	var solo := -1
	if not OS.get_environment("ESCALON").is_empty():
		solo = int(OS.get_environment("ESCALON"))

	print("")
	print("=== LA CAZA, ESCALON A ESCALON (%d jornadas cada uno) ===" % days)
	print("%-13s %7s %7s %8s %9s   %s" % [
		"", "salidas", "vacias", "caceria", "cobradas", "como acaban"])

	if solo < 0 or solo >= ESCALONES.size():
		print("hace falta ESCALON=0..%d" % (ESCALONES.size() - 1))
		quit(); return
	await _correr(sim, ESCALONES[solo] as Dictionary, days)
	quit()


## Un escalon: se rearma la banda, se le pone el utillaje y la tecnica que
## toca, y se cuenta lo que caza.
func _correr(sim: Node, fila: Dictionary, days: int) -> void:
	# Se vuelve a empezar de cero cada vez: si no, el escalon de arriba hereda
	# la despensa y la destreza del de abajo y la comparacion no dice nada.
	sim.time_scale = 0.0
	sim.techs = TechTree.new()
	for tech: int in (fila["tecnicas"] as Array):
		sim.techs.known[tech] = true
	sim.techs.larder = sim.store
	sim.caceria.hunt_endings.clear()
	sim.caceria.hunts.clear()
	sim.caceria.jornadas_mas_larga = 0
	sim.caceria.lances_fallados = 0

	# Y se le QUITAN las armas que no toquen, que no es lo mismo que no darlas.
	# El escalon «a mano» no limpiaba el utillaje: la banda llegaba con las
	# azagayas que se hubiera tallado ella sola, `Fauna.weapon_at_hand` se las
	# encontraba, y el alcance pasaba de los tres metros de la mano a los
	# dieciseis de la azagaya. O sea que el suelo del escalon no era el suelo:
	# se midio 1,23 raciones por cazador y dia «a mano» con una azagaya en la
	# mano.
	# El arco no esta aqui porque no es una PIEZA: es una tecnica que cambia
	# como se caza, no con que. Ver `Hunting.MEJORAS`.
	for kind: int in [Tool.Kind.AZAGAYA, Tool.Kind.PUNTA]:
		if not (fila["armas"] as Array).has(kind):
			sim.toolkit.pieces = sim.toolkit.pieces.filter(
				func(t: Tool) -> bool: return t.kind != kind)
	for kind: int in (fila["armas"] as Array):
		for i in range(6):
			sim.toolkit.craft(kind as Tool.Kind, Tool.Stuff.ASTA, 0.6)

	# Toda la banda que pueda, a la caza: con uno o dos cazadores la muestra es
	# tan pequeña que el ruido tapa la señal.
	var sent := 0
	for person: Inhabitant in sim.people:
		if not Profession.can_do(Profession.Job.CAZA, person):
			continue
		for job: int in Profession.Job.values():
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 0)
		person.set_priority(Profession.task_id(Profession.Job.CAZA,
			Profession.Speciality.CAZA_MAYOR), 1)
		person.speciality = Profession.Speciality.CAZA_MAYOR
		person.journeys.clear()
		sent += 1
	sim.apply_priorities()
	sim.time_scale = 20.0

	# Lo PRODUCIDO, no lo que queda en el almacen: con toda la banda a la caza
	# no hay quien recolecte, se comen la carne segun entra y el delta del
	# almacen sale cero aunque se hayan cobrado tres piezas.
	sim.produced_days.clear()
	sim.produced_today.clear()
	var first_day: int = sim.day
	while sim.day < first_day + days:
		await process_frame

	var salidas := 0
	var vacias := 0
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.CAZA:
			continue
		for trip: Dictionary in person.journeys:
			salidas += 1
			if String(trip.get("outcome", "")).begins_with("volvio de vacio"):
				vacias += 1
	var cobradas := 0
	for motivo: String in sim.caceria.hunt_endings:
		if motivo == "cobrada":
			cobradas = int(sim.caceria.hunt_endings[motivo])
	var abiertas := 0
	for motivo: String in sim.caceria.hunt_endings:
		abiertas += int(sim.caceria.hunt_endings[motivo])

	print("%-13s %7d %7d %8d %9d   %s" % [
		String(fila["nombre"]), salidas, vacias, abiertas, cobradas,
		str(sim.caceria.hunt_endings)])
	print("%-13s lances fallados: %d (NO son caceria perdidas: fallar devuelve" % [
		"", sim.caceria.lances_fallados]
		+ " a la persecucion mientras quede fuelle)")
	var carne := 0.0
	for a_day: Dictionary in sim.produced_days:
		carne += float(a_day.get(int(Materia.Kind.CARNE), 0.0))
	carne += float(sim.produced_today.get(int(Materia.Kind.CARNE), 0.0))
	var raciones := carne * Materia.nutrition(Materia.Kind.CARNE)
	var comen := 0.0
	for person: Inhabitant in sim.people:
		comen += person.daily_food()
	print("%-13s carne producida: %.1f = %.1f raciones · %d cazadores · %.2f por cazador y dia" % [
		"", carne, raciones, sent, raciones / maxf(float(sent * days), 1.0)])
	print("%-13s la banda come %.1f raciones al dia: la caza cubre el %.0f %%" % [
		"", comen, 100.0 * raciones / maxf(comen * float(days), 1.0)])
	print("%-13s la caceria mas larga: %d jornadas" % [
		"", sim.caceria.jornadas_mas_larga])
	# Si hay piezas cobradas y cero producido, la carne se ha quedado por el
	# camino: encima de alguien, o en el suelo donde cayo la pieza.
	var encima := 0.0
	for person: Inhabitant in sim.people:
		encima += float(person.load.get(Materia.Kind.CARNE, 0.0))
	var en_el_suelo := 0.0
	for hunt: Hunt in sim.caceria.hunts:
		en_el_suelo += float(hunt.spoils.get(Materia.Kind.CARNE, 0.0))
	print("%-13s carne encima de la banda: %.1f · en el suelo sin acarrear: %.1f" % [
		"", encima, en_el_suelo])
	var fases: Dictionary = {}
	for hunt: Hunt in sim.caceria.hunts:
		var f: String = str(Hunt.Phase.keys()[int(hunt.phase)])
		fases[f] = int(fases.get(f, 0)) + 1
	print("%-13s en que fase estan las caceria abiertas: %s" % ["", str(fases)])
	print("%-13s piezas en el suelo: %d · gente fuera del abrigo: %d" % [
		"", sim.caceria.kills_today.size(),
		sim.people.filter(func(p: Inhabitant) -> bool:
			return not sim._at_shelter(p)).size()])
