extends SceneTree
## Mide el taller sobre el terreno de verdad (sitio 56, Cueva los pendios).
##
## El jugador dijo que la manufactura «no fabrica». Medido antes del arreglo:
## los talladores se pasaban el 79% del dia andando a una cantera al otro lado
## del valle y NUNCA entraban en TRABAJANDO. Esta sonda vuelve a contar los
## estados, el reparto de oficios y las piezas que salen.
##
## Uso:
##   godot --headless --path . --script res://scripts/tests/CraftProbe.gd

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
	if chosen == null:
		print("no esta el sitio %d en el catalogo" % SITE_ID)
		quit(1)
		return

	var path := "res://data/dem/local/site_%d.res" % SITE_ID
	var local: HeightmapData = load(path)
	var size_m := local.get_world_size_meters()
	var u := local.u_for_lon(chosen.lon)
	var v := local.v_for_lat(chosen.lat)
	var half := float(Expedition.local_size_m) * 0.5

	Expedition.site = chosen
	Expedition.heightmap_path = path
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(u * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(v * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	_scene = (load("res://scenes/demo_main.tscn") as PackedScene).instantiate()
	get_root().add_child(_scene)


## Se dejan pasar unos fotogramas antes de medir: el terreno y el campo de
## recursos se montan en `_ready` y en llamadas diferidas, y arrancar la
## simulacion antes de eso mide un mundo a medio montar.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 15:
		return false
	_run(_scene)
	return true


func _run(inst: Node) -> void:
	var sim: SettlementSim = inst.get("sim")
	if sim == null:
		print("no encuentro el SettlementSim en la escena")
		return

	# La escena arranca en pausa: `setup` deja `time_scale` a cero esperando
	# que el jugador le de al play
	sim.time_scale = 1.0

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-. Sin esto, la sonda ponia a tres al taller y dejaba a los
	# otros doce parados: nadie bajaba materia prima al abrigo y el taller no
	# sacaba una sola pieza. Se reparte primero y se pisa despues lo del taller.
	sim.assign_default_jobs()

	# Tres al taller con la recoleccion de segunda: asi se ve a la vez que
	# tallan cuando hay materia y que se bajan al monte cuando no la hay
	var workshop: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		if workshop.size() >= 3 and not Profession.can_do(Profession.Job.MANUFACTURA, person):
			continue
		if workshop.size() < 3 and Profession.can_do(Profession.Job.MANUFACTURA, person):
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				Profession.Speciality.TALLA), 1)
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				Profession.Speciality.FORRAJEO), 2)
			workshop.append(person)
	sim.apply_priorities()
	var names: Array[String] = []
	for person: Inhabitant in workshop:
		names.append(person.given_name)
	print("=== TALLER === %s" % ", ".join(names))

	# Estados por persona de taller, acumulados en minutos
	var states := {}
	var pieces_before := _toolkit_total(sim)

	var step := sim.seconds_per_day / 24.0 / 60.0
	for day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)
			for person: Inhabitant in workshop:
				var key := "%s|%s|%d" % [person.given_name,
					Profession.job_name(person.job), person.state]
				states[key] = float(states.get(key, 0.0)) + 1.0

		if day % 5 == 0 or day == DAYS - 1:
			var jobs := {}
			for person: Inhabitant in sim.people:
				var jn := Profession.job_name(person.job)
				jobs[jn] = int(jobs.get(jn, 0)) + 1
			print("dia %2d  oficios %s" % [sim.day, JSON.stringify(jobs)])
			print("        piedra %.1f  silex %.1f  asta %.1f  fibra %.1f  hueso %.1f  piel %.1f  lena %.1f  resina %.1f" % [
				sim.store.amount(Materia.Kind.PIEDRA),
				sim.store.amount(Materia.Kind.SILEX),
				sim.store.amount(Materia.Kind.ASTA),
				sim.store.amount(Materia.Kind.FIBRA),
				sim.store.amount(Materia.Kind.HUESO),
				sim.store.amount(Materia.Kind.PIEL),
				sim.store.amount(Materia.Kind.LENA),
				sim.store.amount(Materia.Kind.RESINA)])
			print("        utillaje %s" % _toolkit_text(sim))

	print("=== ESTADOS DE QUIEN ESTA EN TALLER (minutos) ===")
	var keys := states.keys()
	keys.sort()
	for key: String in keys:
		var parts := key.split("|")
		print("  %-10s %-14s %-12s %6d min" % [
			parts[0], parts[1], _state_name(int(parts[2])), int(states[key])])

	print("=== PIEZAS ===  antes %d  despues %d" % [pieces_before, _toolkit_total(sim)])


func _toolkit_total(sim: SettlementSim) -> int:
	var total := 0
	for kind: int in Tool.Kind.values():
		total += int(sim.toolkit.count(kind as Tool.Kind))
	return total


func _toolkit_text(sim: SettlementSim) -> String:
	var bits: Array[String] = []
	for kind: int in Tool.Kind.values():
		var n := sim.toolkit.count(kind as Tool.Kind)
		if n > 0:
			bits.append("%s %d" % [Tool.kind_name(kind as Tool.Kind), n])
	return ", ".join(bits) if not bits.is_empty() else "nada"


func _state_name(state: int) -> String:
	match state:
		Inhabitant.State.DURMIENDO: return "DURMIENDO"
		Inhabitant.State.OCIOSO: return "OCIOSO"
		Inhabitant.State.YENDO: return "YENDO"
		Inhabitant.State.TRABAJANDO: return "TRABAJANDO"
		Inhabitant.State.VOLVIENDO: return "VOLVIENDO"
		Inhabitant.State.COMIENDO: return "COMIENDO"
		_: return "estado %d" % state
