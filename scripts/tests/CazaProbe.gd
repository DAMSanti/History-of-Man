extends SceneTree
## La caza, sobre el terreno de verdad.
##
## Contesta las tres preguntas del encargo: si las trampas se arman y se ven,
## si el despiece sale de la PIEZA -pluma en las aves, no piel- y si cazar da
## mas raciones que recolectar.

const SITE_ID := 56
const DAYS := 190

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
	var tech: TechTree = _scene.get("tech")
	var markers: TrapMarkers = _scene.get("trap_markers")
	sim.time_scale = 1.0
	# Las tecnicas de trampa, dadas: lo que se mide aqui es la mecanica, no
	# cuanto tarda en aprenderse -eso ya lo dice el arbol.
	for t: int in [TechTree.Tech.LAZO, TechTree.Tech.CEPO,
			TechTree.Tech.RED_AVES]:
		tech.known[t as TechTree.Tech] = true

	# Cinco a la caza -dos de trampas, dos menor, uno mayor- y el resto a
	# recolectar, para poder comparar las dos cosas en la misma partida.
	var reparto := {}
	var i := 0
	for person: Inhabitant in sim.people:
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 0)
		if not person.can_work():
			continue
		var speciality := Profession.Speciality.FORRAJEO
		var job := Profession.Job.RECOLECCION
		if i < 2:
			speciality = Profession.Speciality.TRAMPAS
			job = Profession.Job.CAZA
		elif i < 4:
			speciality = Profession.Speciality.CAZA_MENOR
			job = Profession.Job.CAZA
		elif i < 5:
			speciality = Profession.Speciality.CAZA_MAYOR
			job = Profession.Job.CAZA
		if Profession.can_do(job, person):
			person.set_priority(Profession.task_id(job, speciality), 1)
			reparto[person.given_name] = Profession.speciality_name(speciality)
			i += 1
			continue
		# El resto: recoleccion, lena y taller. Hace falta un astero de verdad,
		# porque sin azagayas la caza va al 25% de filo y eso no mide la caza,
		# mide una banda desarmada.
		person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
			Profession.Speciality.FORRAJEO), 1)
		person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
			Profession.Speciality.LENA_FIBRA), 1)
		person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
			Profession.Speciality.TALLA), 1)
		person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
			Profession.Speciality.ASTA), 1)
	# Materia prima de salida: sin fibra, lena y piedra no se arma una trampa,
	# y lo que se mide aqui es la mecanica de la caza, no la de la cordeleria.
	sim.store.add(Materia.Kind.FIBRA, 60.0)
	sim.store.add(Materia.Kind.LENA, 60.0)
	sim.store.add(Materia.Kind.PIEDRA, 60.0)
	sim.store.add(Materia.Kind.ASTA, 30.0)
	sim.store.add(Materia.Kind.HUESO, 30.0)
	sim.store.add(Materia.Kind.RESINA, 20.0)
	sim.apply_priorities()
	print("=== REPARTO === %s" % JSON.stringify(reparto))

	var step := sim.seconds_per_day / 24.0 / 60.0
	for day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)
		if day % 45 == 0 or day == DAYS - 1:
			print("dia %2d  trampas puestas %d (chapas %d)  carne %.1f  piel %.1f  hueso %.1f  tendon %.1f  pluma %.1f  asta %.1f" % [
				sim.day, sim.trampas.traps.size(), markers.count(),
				sim.store.amount(Materia.Kind.CARNE),
				sim.store.amount(Materia.Kind.PIEL),
				sim.store.amount(Materia.Kind.HUESO),
				sim.store.amount(Materia.Kind.TENDON),
				sim.store.amount(Materia.Kind.PLUMA),
				sim.store.amount(Materia.Kind.ASTA)])

	print("=== LAS TRAMPAS PUESTAS ===")
	for trap: Trap in sim.trampas.traps:
		print("  %-14s de %-6s en %-28s  estado %3.0f%%  ha dado %d piezas  cala %s" % [
			Trap.trap_name(trap.kind), trap.maker,
			sim.parajes.place_name(trap.position, sim.home_position),
			trap.condition() * 100.0, trap.taken,
			Fauna.species_text(trap.position, GameState.season as Subsistence.Season)])

	print("=== RACIONES POR JORNADA, OFICIO A OFICIO ===")
	var por_especialidad := {}
	for person: Inhabitant in sim.people:
		var speciality := person.current_speciality as Profession.Speciality
		var entry: Dictionary = por_especialidad.get(int(speciality),
			{"raciones": 0.0, "jornadas": 0.0})
		for row: Dictionary in person.work_summary():
			for kind: int in (row["gained"] as Dictionary):
				if kind >= 0 and Materia.is_food(kind as Materia.Kind):
					entry["raciones"] = float(entry["raciones"]) + float(
						(row["gained"] as Dictionary)[kind]) * Materia.nutrition(
							kind as Materia.Kind)
		entry["jornadas"] = float(entry["jornadas"]) + float(DAYS)
		por_especialidad[int(speciality)] = entry
	for key: int in por_especialidad:
		var entry: Dictionary = por_especialidad[key]
		print("  %-18s %.2f raciones por jornada-persona" % [
			Profession.speciality_name(key as Profession.Speciality),
			float(entry["raciones"]) / maxf(float(entry["jornadas"]), 1.0)])

	print("=== POR QUE RINDE LO QUE RINDE ===")
	print("  azagayas %d · lascas %d · cestos %d" % [
		sim.toolkit.count(Tool.Kind.AZAGAYA), sim.toolkit.count(Tool.Kind.LASCA),
		sim.toolkit.count(Tool.Kind.CESTO)])
	print("  filo de caza %.2f · filo de recoleccion %.2f" % [
		sim.toolkit.efficiency(Tool.Kind.AZAGAYA,
			sim.workers_in(Subsistence.Activity.CAZA)),
		sim.toolkit.efficiency(Tool.Kind.CESTO,
			sim.workers_in(Subsistence.Activity.RECOLECCION))])
	print("  temporada: caza %.2f · recoleccion %.2f  (%s)" % [
		ResourceField.seasonal_factor(Subsistence.Activity.CAZA,
			GameState.season as Subsistence.Season),
		ResourceField.seasonal_factor(Subsistence.Activity.RECOLECCION,
			GameState.season as Subsistence.Season),
		Subsistence.season_name(GameState.season as Subsistence.Season)])
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.CAZA:
			continue
		var speciality := person.current_speciality as Profession.Speciality
		if speciality == Profession.Speciality.TRAMPAS:
			continue
		var nominal := Hunting.yields_at(speciality, person.work_centre,
			GameState.season as Subsistence.Season, tech)
		var raciones := 0.0
		for kind: int in nominal:
			if Materia.is_food(kind as Materia.Kind):
				raciones += float(nominal[kind]) * Materia.nutrition(kind as Materia.Kind)
		print("  %-8s %-12s nominal %.1f raciones/jornada perfecta · piezas %.2f · aqui: %s" % [
			person.given_name, Profession.speciality_name(speciality), raciones,
			Hunting.pieces_per_day(speciality, tech),
			Fauna.species_text(person.work_centre,
				GameState.season as Subsistence.Season)])
	var forrajeo := 0.0
	for kind: int in SettlementSim.SPECIALITY_YIELDS[Profession.Speciality.FORRAJEO]:
		if Materia.is_food(kind as Materia.Kind):
			forrajeo += float(SettlementSim.SPECIALITY_YIELDS[
				Profession.Speciality.FORRAJEO][kind]) * Materia.nutrition(
					kind as Materia.Kind)
	print("  forrajeo  nominal %.1f raciones/jornada perfecta" % forrajeo)

	print("=== LO QUE TRAE CADA UNO ===")
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.CAZA:
			continue
		var bits: Array[String] = []
		var total := {}
		for row: Dictionary in person.work_summary():
			for kind: int in (row["gained"] as Dictionary):
				if kind < 0:
					continue
				total[kind] = float(total.get(kind, 0.0)) + float(
					(row["gained"] as Dictionary)[kind])
		for kind: int in total:
			bits.append("%s %.1f" % [
				Materia.material_name(kind as Materia.Kind), float(total[kind])])
		print("  %-8s %-18s %s" % [person.given_name,
			Profession.speciality_name(person.current_speciality as Profession.Speciality),
			", ".join(bits)])
