extends SceneTree
## «Anado gente a la pesca de orilla, pero no hacen nada.»
##
## Se reproduce tal cual: partida por defecto y, encima, ORILLA en prioridad
## 1 a tres personas -que es lo que hace el jugador en la pestana Trabajos-.
## Luego se mira, persona a persona, que oficio les toca y por que.

const SITE_ID := 56
const DAYS := 30

var _scene: Node
var _frames := 0


func _initialize() -> void:
	var set_res: SiteSet = load("res://data/sites/cantabria_sites.res")
	var chosen: Site = null
	for s: Site in set_res.sites:
		if s.id == SITE_ID:
			chosen = s
			break

	var path := "res://data/dem/local/site_%d.res" % SITE_ID
	var local: HeightmapData = load(path)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5

	Expedition.site = chosen
	Expedition.heightmap_path = path
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(chosen.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(chosen.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))

	_scene = (load("res://scenes/demo_main.tscn") as PackedScene).instantiate()
	get_root().add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 15:
		return false
	_run()
	return true


func _run() -> void:
	var sim: SettlementSim = _scene.get("sim")
	sim.time_scale = 1.0

	print("=== SITIOS DE TRABAJO MONTADOS ===")
	for activity: int in sim.work_sites:
		print("  %s en %v" % [
			Subsistence.activity_name(activity as Subsistence.Activity),
			sim.work_sites[activity]])
	print("  hay sitio de PESCA: %s" % sim.work_sites.has(
		Subsistence.Activity.PESCA))

	# Lo que hace el jugador: subir ORILLA a 1 en tres personas, sin tocar
	# nada mas
	var elegidos: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		if elegidos.size() >= 3 and true:
			break
		if not Profession.can_do(Profession.Job.RIBERA, person):
			continue
		# Exactamente el reparto de la captura del jugador: TODO a 2 y la
		# orilla sola en 1. Sin empates que valgan.
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 2)
		person.set_priority(Profession.task_id(Profession.Job.RIBERA,
			Profession.Speciality.ORILLA), 1)
		elegidos.append(person)
	sim.apply_priorities()
	print("=== A LA ORILLA: %s ===" % _names(elegidos))
	for person: Inhabitant in elegidos:
		var wanted := sim.top_choice(person)
		print("  %s quiere %s | estorbo: «%s»" % [person.given_name,
			Profession.speciality_name(Profession.task_speciality(wanted)),
			sim.task_blocked_by(person, wanted)])

	_report(sim, elegidos)

	var step := sim.seconds_per_day / 24.0 / 60.0
	for _day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)
	print("--- tras %d dias ---" % DAYS)
	_report(sim, elegidos)
	print("  pescado fresco %.1f · pescado seco %.1f · raciones totales %.1f" % [
		sim.store.amount(Materia.Kind.PESCADO),
		sim.store.amount(Materia.Kind.PESCADO_SECO),
		sim.store.food_rations()])
	print("  secadero levantado: %s" % sim.camp_built.get(
		CampProjects.Kind.SECADERO, false))
	print("  atascos: %s" % JSON.stringify(sim.stuck_tally))
	print("  cargas perdidas: %d" % sim.lost_loads)
	print("  produccion diaria de pescado que cuenta la banda: %.2f"
		% sim.production_of(Materia.Kind.PESCADO))
	print("=== LO QUE DICE CADA SALIDA DE PESCA ===")
	for person: Inhabitant in elegidos:
		if person.activity != Subsistence.Activity.PESCA:
			continue
		print("  --- %s (lleva encima: %s) ---" % [person.given_name,
			JSON.stringify(person.load)])
		var contadas := 0
		for i in range(person.journeys.size() - 1, -1, -1):
			if contadas >= 10:
				break
			contadas += 1
			var trip: Dictionary = person.journeys[i]
			print("      d%d %-12s :: %s" % [int(trip["day"]),
				String(trip["kind"]), String(trip["outcome"])])

	print("=== DOS JORNADAS, HORA A HORA, DE UN PESCADOR ===")
	var quien: Inhabitant = null
	for person: Inhabitant in elegidos:
		if person.activity == Subsistence.Activity.PESCA:
			quien = person
			break
	if quien:
		for _hora in range(48):
			for _tick in range(60):
				sim._process(step)
			print("  d%d %5.2fh  %-12s  en %v  destino %v  ruta %d  hambre %.0f cansancio %.0f" % [
				sim.day, sim.hour, _state(quien.state), quien.position,
				quien.target, quien.route.size(), quien.hunger, quien.fatigue])

	print("=== EL CAUCE, VISTO POR EL CAMPO DE RECURSOS ===")
	var sitio: Vector3 = sim.work_sites.get(Subsistence.Activity.PESCA, Vector3.ZERO)
	print("  abundancia de pesca en el sitio de trabajo: %.3f"
		% sim.field.abundance_at(Subsistence.Activity.PESCA, sitio))
	print("  stock alrededor (120 m): %.3f" % sim.field.stock_fraction_around(
		Subsistence.Activity.PESCA, sitio, 120.0))

	var celdas := 0
	var suma := 0.0
	var mejor := 0.0
	for z in range(sim.field.height):
		for x in range(sim.field.width):
			var value := sim.field.abundance_cell(Subsistence.Activity.PESCA, x, z)
			if value > 0.001:
				celdas += 1
				suma += value
			mejor = maxf(mejor, value)
	print("  celdas con pesca en TODO el mapa: %d de %d  ·  media %.3f  ·  mejor %.3f" % [
		celdas, sim.field.width * sim.field.height,
		suma / maxf(float(celdas), 1.0), mejor])

	print("=== SITIOS CONOCIDOS DE PESCA ===")
	var spots: Array = sim._known_spots.get(Subsistence.Activity.PESCA, [])
	print("  %d sitios en la lista" % spots.size())
	for i in range(mini(spots.size(), 6)):
		var spot: Dictionary = spots[i]
		print("    %v  puntuacion %.3f  abundancia %.3f" % [
			spot["pos"], float(spot["score"]),
			sim.field.abundance_at(Subsistence.Activity.PESCA, spot["pos"])])
	var reserva: Vector3 = sim.work_sites.get(Subsistence.Activity.PESCA, Vector3.ZERO)
	var grid := sim._navgrid()
	print("  sitio de reserva: %v" % reserva)
	print("  can_reach: %s | connected(casa, sitio): %s | zonas: %d" % [
		sim.can_reach(reserva), grid.connected(sim.home_position, reserva),
		grid.areas])
	print("  celda de casa: %d | celda del rio: %d" % [
		grid.nearest_open(sim.home_position), grid.nearest_open(reserva)])
	for person: Inhabitant in elegidos:
		if person.activity == Subsistence.Activity.PESCA:
			print("  _best_known_spot(%s) = %v" % [person.given_name,
				sim._best_known_spot(person)])

	print("=== DONDE ESTAN Y QUE SACAN ===")
	for person: Inhabitant in elegidos:
		if person.activity != Subsistence.Activity.PESCA:
			continue
		print("  %s trabaja en %v · abundancia ahi %.3f · umbral para nombrarlo %.2f" % [
			person.given_name, person.work_centre,
			sim.field.abundance_at(Subsistence.Activity.PESCA, person.work_centre),
			Parajes.threshold_for(Subsistence.Activity.PESCA)])
		for trip: Dictionary in person.journeys:
			print("      d%d %s :: %s" % [int(trip["day"]),
				String(trip["kind"]), String(trip["outcome"])])


func _report(sim: SettlementSim, elegidos: Array[Inhabitant]) -> void:
	for person: Inhabitant in elegidos:
		var tarea := Profession.task_id(Profession.Job.RIBERA,
			Profession.Speciality.ORILLA)
		print("  %-8s oficio %-14s espec %-16s actividad %-12s tarea:%s estado:%d salidas:%d" % [
			person.given_name, Profession.job_name(person.job),
			Profession.speciality_name(person.current_speciality as Profession.Speciality),
			Subsistence.activity_name(person.activity),
			person.has_task, int(person.state), person.journeys.size()])
		print("        prioridad orilla %d | tiene adonde ir: %s | puede: %s" % [
			person.priority_for(tarea),
			sim._task_has_somewhere(Profession.Job.RIBERA, tarea),
			Profession.can_do(Profession.Job.RIBERA, person)])


func _state(state: int) -> String:
	match state:
		Inhabitant.State.DURMIENDO: return "DURMIENDO"
		Inhabitant.State.OCIOSO: return "OCIOSO"
		Inhabitant.State.YENDO: return "YENDO"
		Inhabitant.State.TRABAJANDO: return "TRABAJANDO"
		Inhabitant.State.VOLVIENDO: return "VOLVIENDO"
		Inhabitant.State.COMIENDO: return "COMIENDO"
		Inhabitant.State.BUSCANDO: return "BUSCANDO"
		Inhabitant.State.RECONOCIENDO: return "RECONOCIENDO"
		_: return "estado %d" % state


func _names(people: Array[Inhabitant]) -> String:
	var out: Array[String] = []
	for person: Inhabitant in people:
		out.append(person.given_name)
	return ", ".join(out)
