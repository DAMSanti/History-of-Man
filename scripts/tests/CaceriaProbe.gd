extends SceneTree
## La cacería y la línea de nasas, sobre el terreno de verdad.
##
## Las pruebas de `TestCaceria` dicen que la máquina de fases funciona; lo que
## no pueden decir es si en una partida de verdad se llega a cobrar algo. Un
## acecho que nunca alcanza la pieza, un rastreo que se come la jornada entera
## o una banda que se muere de hambre porque la caza dejó de ser una tabla son
## fallos que sólo salen jugando.
##
## Contesta cuatro cosas:
##   1. ¿Se acecha, se persigue y se cobra? ¿En qué proporción se falla?
##   2. ¿Cuántas raciones por jornada-persona trae la caza AHORA? Es la cifra
##      que hay que comparar con la que había: si se hunde, la banda no come.
##   3. ¿Se calan nasas y dan pescado sin que el pescador deje de pescar?
##   4. ¿Cuánto se ahúma y cuánto se pudre?
##
## Se lanza CON VENTANA. Ver `scripts/tests/CazaProbe.gd`.

const SITE_ID := 56
const DAYS := 120

## Cada cuántos ticks se mueve la fauna. Ver el bucle de abajo.
const FAUNA_CADA := 12

var _scene: Node
var _frames := 0

## Lo que se ve pasar por cada fase, contado a lo largo de la partida.
var _phases: Dictionary = {}
var _opened := 0
var _killed := 0
var _lost := 0
var _by_species: Dictionary = {}


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
	if _frames < 20:
		return false
	_run()
	return true


func _run() -> void:
	var sim: SettlementSim = _scene.get("sim")
	var tech: TechTree = _scene.get("tech")
	sim.time_scale = 1.0

	# Las técnicas, dadas: lo que se mide aquí es la cacería, no cuánto tarda
	# en aprenderse el árbol. Con azagaya y con nasa, que son las dos puertas.
	for t: int in [TechTree.Tech.NUCLEO, TechTree.Tech.HOJA,
			TechTree.Tech.AZAGAYA, TechTree.Tech.OJEO,
			TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
			TechTree.Tech.LAZO]:
		tech.known[t as TechTree.Tech] = true

	# Cuatro a la caza mayor -que es una cuadrilla de verdad-, dos a la menor,
	# dos a la ribera y el resto a traer materia prima y a tallar.
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
		if i < 4:
			speciality = Profession.Speciality.CAZA_MAYOR
			job = Profession.Job.CAZA
		elif i < 6:
			speciality = Profession.Speciality.CAZA_MENOR
			job = Profession.Job.CAZA
		elif i < 8:
			speciality = Profession.Speciality.ORILLA
			job = Profession.Job.RIBERA
		elif i < 10:
			# Dos al hogar A LA FUERZA. Sin nadie ahí el fuego se apaga a los
			# dos días y no hay secadero que medir: el reparto por prioridades
			# manda a todo el mundo a por comida cuando la despensa está baja,
			# que es lo correcto y aquí tapa justo lo que se quiere ver.
			speciality = Profession.Speciality.NINGUNA
			job = Profession.Job.HOGAR
		if Profession.can_do(job, person):
			person.set_priority(Profession.task_id(job, speciality), 1)
			reparto[person.given_name] = Profession.speciality_name(speciality)
			i += 1
			continue
		person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
			Profession.Speciality.FORRAJEO), 1)
		person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
			Profession.Speciality.LENA_FIBRA), 1)
		person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
			Profession.Speciality.TALLA), 1)
		person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
			Profession.Speciality.ASTA), 1)
		person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
			Profession.Speciality.CORDELERIA), 1)
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)

	# Materia prima de salida. Sin azagayas la caza mayor no sale siquiera del
	# abrigo -es la puerta nueva-, y lo que se mide es la cacería, no el taller.
	sim.store.add(Materia.Kind.ASTA, 40.0)
	sim.store.add(Materia.Kind.FIBRA, 80.0)
	sim.store.add(Materia.Kind.LENA, 80.0)
	sim.store.add(Materia.Kind.PIEDRA, 80.0)
	sim.store.add(Materia.Kind.RESINA, 30.0)
	sim.store.add(Materia.Kind.CORTEZA, 20.0)
	for _n in range(6):
		sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.6)
		sim.toolkit.craft(Tool.Kind.LASCA, Tool.Stuff.CUARCITA, 0.6)
	for _n in range(4):
		sim.toolkit.craft(Tool.Kind.NASA, Tool.Stuff.FIBRA, 0.6)
	# Hogar y secadero LEVANTADOS, y encendido. No es hacer trampa: lo que se
	# quiere medir aquí es si el secadero salva la carne, y para eso tiene que
	# existir. Sin él la banda pierde ochocientas raciones en cuatro meses
	# —medido— y lo que se estaría midiendo es la podredumbre, que ya se mide
	# en `TestDespensa`.
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.camp_built[CampProjects.Kind.SECADERO] = true
	sim.hearth_lit = true

	sim.apply_priorities()
	# Y dos personas clavadas al hogar. El reparto por prioridades manda a todo
	# el mundo a por comida cuando la despensa baja —que es lo correcto— y eso
	# vacía justo el oficio que hay que observar.
	#
	# Y se hace con PRIORIDADES y no cambiando `job` a mano: `apply_priorities`
	# corre otra vez en cada cierre de jornada y deshacía el apaño esa misma
	# noche. Medido: «al hogar: 0» con dos personas puestas a mano.
	var al_hogar := 0
	for person: Inhabitant in sim.people:
		if al_hogar >= 2 or not person.can_work():
			continue
		if not Profession.can_do(Profession.Job.HOGAR, person):
			continue
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 0)
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
		al_hogar += 1
	sim.apply_priorities()
	print("=== REPARTO === %s" % JSON.stringify(reparto))
	print("al hogar: %d" % al_hogar)
	print("fauna en el valle: %d animales" % sim.wildlife.animals().size())

	var pudrido := 0.0
	var ahumado := 0.0
	var step := sim.seconds_per_day / 24.0 / 60.0
	for day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)
			# LA FAUNA TAMBIEN. El bucle llama a `sim._process` a mano y el
			# arbol de escena sólo late una vez por fotograma real, así que sin
			# esta línea los animales se quedaban CLAVADOS mientras la banda
			# vivía cuatro meses: se estaría midiendo un acecho contra estatuas.
			#
			# Cada FAUNA_CADA ticks y con el delta acumulado, no cada tick. La
			# fauna se replantea el rumbo cada tres segundos y medio -ver
			# `WildlifeHerds.RETHINK_SECONDS`-, así que a este paso se mueve
			# igual; y son ochocientos animales por llamada, que a cada tick son
			# ciento treinta millones de cuentas y la sonda no termina nunca.
			if _tick % FAUNA_CADA == 0:
				sim.wildlife._process(step * float(FAUNA_CADA))
			_watch(sim)
		for kind: int in sim.spoiled_today:
			if Materia.is_food(kind as Materia.Kind):
				pudrido += float(sim.spoiled_today[kind]) * Materia.nutrition(
					kind as Materia.Kind)
		for kind: int in sim.smoked_today:
			ahumado += float(sim.smoked_today[kind]) * Materia.nutrition(
				kind as Materia.Kind)
		if day % 30 == 0 or day == DAYS - 1:
			print("dia %3d  caceria %d  nasas %d  carne %.0f  seca %.0f  pescado %.0f  seco %.0f  raciones %.0f" % [
				sim.day, sim.hunts.size(), sim.nasas.size(),
				sim.store.amount(Materia.Kind.CARNE),
				sim.store.amount(Materia.Kind.CARNE_SECA),
				sim.store.amount(Materia.Kind.PESCADO),
				sim.store.amount(Materia.Kind.PESCADO_SECO),
				sim.store.food_rations()])

	print("")
	print("=== LA CACERIA ===")
	print("  levantadas %d · cobradas %d · perdidas %d  (%.0f%% se cobran)" % [
		_opened, _killed, _lost,
		100.0 * float(_killed) / maxf(float(_killed + _lost), 1.0)])
	print("  ticks vistos por fase:")
	for phase: int in _phases:
		print("    %-14s %d" % [_phase_name(phase), int(_phases[phase])])
	print("  por qué se acaba cada una:")
	for why: String in sim.hunt_endings:
		print("    %-26s %d" % [why, int(sim.hunt_endings[why])])
	print("  piezas cobradas por especie:")
	for species: String in _by_species:
		print("    %-10s %d" % [Fauna.species_name(species),
			int(_by_species[species])])

	print("")
	print("=== RACIONES POR JORNADA-PERSONA ===")
	var por_especialidad := {}
	for person: Inhabitant in sim.people:
		var speciality := person.current_speciality as Profession.Speciality
		var entry: Dictionary = por_especialidad.get(int(speciality),
			{"raciones": 0.0, "gente": 0.0})
		for row: Dictionary in person.work_summary():
			for kind: int in (row["gained"] as Dictionary):
				if kind >= 0 and Materia.is_food(kind as Materia.Kind):
					entry["raciones"] = float(entry["raciones"]) + float(
						(row["gained"] as Dictionary)[kind]) * Materia.nutrition(
							kind as Materia.Kind)
		entry["gente"] = float(entry["gente"]) + 1.0
		por_especialidad[int(speciality)] = entry
	for key: int in por_especialidad:
		var entry: Dictionary = por_especialidad[key]
		print("  %-18s %.2f  (%d personas)" % [
			Profession.speciality_name(key as Profession.Speciality),
			float(entry["raciones"]) / maxf(
				float(entry["gente"]) * float(DAYS), 1.0),
			int(entry["gente"])])

	print("")
	print("=== LA RIBERA ===")
	print("  nasas caladas: %d" % sim.nasas.size())
	for nasa: Nasa in sim.nasas:
		print("    en %-26s  estado %3.0f%%  ha dado %d piezas  %s" % [
			sim.parajes.place_name(nasa.position, sim.home_position),
			nasa.condition() * 100.0, nasa.taken, nasa.status_text()])
	print("  se pesca con: %s" % Fishing.method_name(
		sim.fishing_method() as Fishing.Method))

	print("")
	print("=== LA DESPENSA ===")
	print("  ahumado en %d jornadas: %.0f raciones" % [DAYS, ahumado])
	print("  perdido  en %d jornadas: %.0f raciones" % [DAYS, pudrido])
	print("  hogar %s · secadero %s" % [
		"encendido" if sim.hearth_lit else "APAGADO",
		"sí" if sim.camp_built.get(CampProjects.Kind.SECADERO, false) else "no"])

	print("")
	print("=== LO QUE SE HA CONTADO ===")
	print("  relatos: %d · pintados: %d" % [sim.tales.size(),
		sim.paintings.size()])
	for tale: Tale in sim.tales:
		print("    [%s] %s" % [tale.stamp(), tale.title])


## Se mira en CADA tick porque las fases duran poco: un lance es instantáneo y
## una persecución no llega al minuto de juego. Mirando una vez al día se vería
## una foto vacía y se concluiría que no se caza.
func _watch(sim: SettlementSim) -> void:
	for hunt: Hunt in sim.hunts:
		if not hunt.get_meta("vista", false):
			hunt.set_meta("vista", true)
			_opened += 1
		_phases[int(hunt.phase)] = int(_phases.get(int(hunt.phase), 0)) + 1
		if hunt.phase == Hunt.Phase.DESPIECE or hunt.phase == Hunt.Phase.ACARREO:
			if not hunt.get_meta("contada", false):
				hunt.set_meta("contada", true)
				_killed += 1
				_by_species[hunt.species] = int(
					_by_species.get(hunt.species, 0)) + 1
		elif hunt.phase == Hunt.Phase.FALLIDA:
			if not hunt.get_meta("contada", false):
				hunt.set_meta("contada", true)
				_lost += 1


func _phase_name(phase: int) -> String:
	match phase:
		Hunt.Phase.ACECHO: return "acecho"
		Hunt.Phase.PERSECUCION: return "persecucion"
		Hunt.Phase.LANCE: return "lance"
		Hunt.Phase.DESPIECE: return "despiece"
		Hunt.Phase.ACARREO: return "acarreo"
		_: return "fallida"
