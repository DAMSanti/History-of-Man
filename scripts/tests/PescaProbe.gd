extends SceneTree
## La progresion de la pesca de orilla sobre el terreno de verdad.
##
## Se pone media banda a pescar y se mira como sube el escalon: a mano,
## pesquera, nasa, sedal, arpon, red. Y con que se queda cuando falta la
## pieza o el cebo.

const SITE_ID := 56
const DAYS := 260

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
	sim.time_scale = 1.0
	print("=== arbol enlazado: %s ===" % ("si" if sim.techs != null else "NO"))

	# Media banda a la orilla, el resto repartido: hace falta cordeleria y
	# asta para que el taller pueda hacer el aparejo
	var fishers := 0
	for person: Inhabitant in sim.people:
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 0)
		if fishers < 5 and person.can_work() and Profession.can_do(Profession.Job.RIBERA, person):
			person.set_priority(Profession.task_id(Profession.Job.RIBERA,
				Profession.Speciality.ORILLA), 1)
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				Profession.Speciality.FORRAJEO), 2)
			fishers += 1
			continue
		for speciality: int in [Profession.Speciality.FORRAJEO,
				Profession.Speciality.LENA_FIBRA, Profession.Speciality.CANTERA]:
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				speciality as Profession.Speciality), 1)
		for speciality: int in [Profession.Speciality.TALLA,
				Profession.Speciality.ASTA, Profession.Speciality.CORDELERIA]:
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				speciality as Profession.Speciality), 1)
		person.set_priority(Profession.task_id(Profession.Job.CAZA,
			Profession.Speciality.CAZA_MENOR), 2)
	sim.apply_priorities()
	print("=== %d a la orilla de %d ===" % [fishers, sim.people.size()])

	var step := sim.seconds_per_day / 24.0 / 60.0
	var last := -1
	for _day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)

		var method := sim.fishing_method()
		var pescadores := sim.taller.workers_in(Subsistence.Activity.PESCA)
		if method != last or sim.day % 40 == 0:
			last = method
			print("dia %3d  %-20s  pescado %7.1f  pescadores %d  aparejo: %s" % [
				sim.day, Fishing.method_name(method as Fishing.Method),
				sim.store.amount(Materia.Kind.PESCADO), pescadores,
				_gear(sim)])
			var con_tarea := 0
			var actividades := {}
			for person: Inhabitant in sim.people:
				var key := "%d/%s" % [int(person.activity),
					"tarea" if person.has_task else "sin"]
				actividades[key] = int(actividades.get(key, 0)) + 1
				if person.activity == Subsistence.Activity.PESCA and person.has_task:
					con_tarea += 1
			print("         jornadas %s | pesca con tarea %d | %s" % [
				JSON.stringify(tech.practice_days), con_tarea,
				JSON.stringify(actividades)])
			print("         %s" % _next_step(sim, method))

	print("=== TECNICAS DE PESCA AL FINAL ===")
	for t: int in [TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
			TechTree.Tech.ANZUELO, TechTree.Tech.ARPON, TechTree.Tech.RED]:
		print("  %-22s %s  (%.0f%%)" % [TechTree.tech_name(t as TechTree.Tech),
			"SI" if tech.has(t as TechTree.Tech) else "no",
			tech.progress(t as TechTree.Tech) * 100.0])


func _gear(sim: SettlementSim) -> String:
	var bits: Array[String] = []
	for kind: int in [Tool.Kind.NASA, Tool.Kind.ANZUELO, Tool.Kind.ARPON,
			Tool.Kind.RED]:
		var n := sim.toolkit.count(kind as Tool.Kind)
		if n > 0:
			bits.append("%s %d" % [Tool.kind_name(kind as Tool.Kind), n])
	bits.append("caracol %.1f" % sim.store.amount(Materia.Kind.CARACOL))
	return ", ".join(bits)


func _next_step(sim: SettlementSim, actual: int) -> String:
	var index := Fishing.ORDER.find(actual)
	if index < 0 or index + 1 >= Fishing.ORDER.size():
		return "no hay escalon mas alto"
	var siguiente: Fishing.Method = Fishing.ORDER[index + 1]
	var why := Fishing.blocked_by(siguiente, sim.techs, sim.toolkit, sim.store,
		sim.taller.workers_in(Subsistence.Activity.PESCA))
	return "para %s: %s" % [Fishing.method_name(siguiente),
		why if why != "" else "nada, ya se puede"]
