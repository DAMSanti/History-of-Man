extends SceneTree
## Por que un artesano con manufactura en prioridad 1 acaba en otro oficio.
##
## Reproduce el reparto de la captura del jugador -Gala con taller a 1 y
## hogar a 2- sobre el terreno de verdad, y en vez de suponer imprime QUE
## PUERTA le cierra el paso a cada especialidad: si esta cubierta de sobra,
## si le falta la herramienta previa o si no hay materia prima.

const SITE_ID := 56
const DAYS := 12

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

	# Como en la captura: uno con el taller a 1 y el hogar a 2, y el resto
	# repartido entre forrajeo, leña y cantera, todos a 1.
	var gala: Inhabitant = null
	for person: Inhabitant in sim.people:
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 0)
		if gala == null and Profession.can_do(Profession.Job.MANUFACTURA, person):
			gala = person
			for task: int in Profession.tasks_of(Profession.Job.MANUFACTURA):
				person.set_priority(task, 1)
			person.set_priority(Profession.task_id(Profession.Job.HOGAR), 2)
			continue
		for speciality: int in [Profession.Speciality.FORRAJEO,
				Profession.Speciality.LENA_FIBRA, Profession.Speciality.CANTERA]:
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				speciality as Profession.Speciality), 1)
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 2)
	sim.apply_priorities()
	print("=== ARTESANO === %s" % gala.given_name)

	var step := sim.seconds_per_day / 24.0 / 60.0
	for day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)
		_report(sim, gala)


func _report(sim: SettlementSim, gala: Inhabitant) -> void:
	print("--- dia %d --- %s hace %s/%s" % [sim.day, gala.given_name,
		Profession.job_name(gala.job),
		Profession.speciality_name(gala.current_speciality as Profession.Speciality)])
	print("    almacen: piedra %.1f  silex %.1f  asta %.1f  hueso %.1f  piel %.1f  fibra %.1f  lena %.1f  resina %.1f" % [
		sim.store.amount(Materia.Kind.PIEDRA), sim.store.amount(Materia.Kind.SILEX),
		sim.store.amount(Materia.Kind.ASTA), sim.store.amount(Materia.Kind.HUESO),
		sim.store.amount(Materia.Kind.PIEL), sim.store.amount(Materia.Kind.FIBRA),
		sim.store.amount(Materia.Kind.LENA), sim.store.amount(Materia.Kind.RESINA)])

	var oficios := {}
	for person: Inhabitant in sim.people:
		var key := "%s/%s" % [Profession.job_name(person.job),
			Profession.speciality_name(person.current_speciality as Profession.Speciality)]
		oficios[key] = int(oficios.get(key, 0)) + 1
	print("    reparto: %s" % JSON.stringify(oficios))

	for speciality_key: int in SettlementSim.SPECIALITY_MAKES:
		var speciality := speciality_key as Profession.Speciality
		var motives: Array[String] = []
		for kind_key: int in (SettlementSim.SPECIALITY_MAKES[speciality_key] as Array):
			var kind := kind_key as Tool.Kind
			var why := ""
			var coverage := sim.taller.tool_coverage(kind)
			if coverage >= SettlementSim.RESERVA_UTILLAJE:
				why = "cubierta %.2f" % coverage
			else:
				var prerequisite := Tool.needs_tool(kind)
				if prerequisite >= 0 and sim.toolkit.count(prerequisite as Tool.Kind) <= 0:
					why = "sin %s" % Tool.kind_name(prerequisite as Tool.Kind)
				elif not sim.taller._can_pay_for(kind):
					why = "sin material (%s)" % _recipe_text(sim, kind)
				else:
					why = "SE PUEDE (cobertura %.2f)" % coverage
			motives.append("%s: %s" % [Tool.kind_name(kind), why])
		print("    %-12s %s" % [Profession.speciality_name(speciality),
			" | ".join(motives)])


func _recipe_text(sim: SettlementSim, kind: Tool.Kind) -> String:
	var bits: Array[String] = []
	var recipe := Tool.recipe(kind)
	for material: int in recipe:
		bits.append("%s %.1f/%.1f" % [
			Materia.material_name(material as Materia.Kind),
			sim.store.amount(material as Materia.Kind), float(recipe[material])])
	return ", ".join(bits)
