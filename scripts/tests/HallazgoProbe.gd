extends SceneTree
## Por qué dejan de aparecer parajes nuevos después del primer día.
##
## Es la queja del jugador: «está descubriendo materiales en parajes que no veo
## como jugador... desde los primeros que muestra el día 1 no descubren ninguno
## más, o al menos no son visibles con sus markers».
##
## Un paraje nace cuando una celda del campo pasa DOS listones a la vez: tener
## bastante material —`WORTH_NAMING` y el propio de la actividad— y estar lo
## bastante conocida —`NAMED_AT`—. Aquí se cuentan las dos cosas por separado, y
## además cuántos alfileres hay pintados de verdad, para saber cuál de los tres
## eslabones está roto:
##
##   RICAS      celdas con material de sobra para dar nombre
##   SABIDAS    de ésas, las que la banda conoce lo bastante
##   LIBRES     de ésas, las que no caen encima de un paraje que ya existe
##   MARCADAS   alfileres pintados en el mundo
##
##   DIAS=30   cuántas jornadas seguir

const SITE_ID := 56

var _reconocimientos := 0
var _cuando: Array[String] = []
var _sin_paraje := 0


## Lo mas lejos que ha llegado en cualquiera de sus salidas.
func _lo_mas_lejos(person: Inhabitant) -> float:
	var lejos := 0.0
	for trip: Dictionary in person.journeys:
		lejos = maxf(lejos, float(trip.get("farthest", 0.0)))
	return lejos


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	_repartir(sim)
	sim.time_scale = 25.0

	var dias := 30
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== POR QUE NO SALEN PARAJES NUEVOS ===")
	print("%5s %8s %8s %8s %9s %9s" % [
		"dia", "parajes", "marcadas", "ricas", "sabidas", "libres"])

	var primero: int = sim.day
	var visto := -1
	var estaba: Dictionary = {}
	var vistos := {}
	while sim.day < primero + dias:
		await process_frame
		# La hora a la que sale cada chapa: es la queja -«aparecen todos a la
		# vez cuando llegan las 12 de la noche».
		for paraje: Paraje in sim.parajes.list:
			if vistos.has(paraje.id()):
				continue
			vistos[paraje.id()] = true
			_cuando.append("dia %2d %s  %-27s %s" % [
				sim.day, Diario.reloj(sim.hour), paraje.name_text,
				Subsistence.activity_name(paraje.activity)])
		# Cada reconocimiento que TERMINA, y si fue sobre un paraje o no: es lo
		# que dice quien esta abriendo monte de verdad.
		for p: Inhabitant in sim.people:
			var antes := int(estaba.get(p.given_name, -1))
			if antes == int(Inhabitant.State.RECONOCIENDO) 					and int(p.state) != antes:
				_reconocimientos += 1
				if sim._paraje_at(p.work_centre) == null:
					_sin_paraje += 1
			estaba[p.given_name] = int(p.state)
		if sim.day == visto or sim.hour < 12.0 or sim.hour > 13.0:
			continue
		visto = sim.day
		if sim.day % 2 == 1 or sim.day - primero < 4:
			_parte(sim, demo)

	print("")
	print("--- CUANDO APARECE CADA UNO ---")
	for fila: String in _cuando:
		print("   %s" % fila)

	print("")
	print("--- Y SI ALGUNO DE TIERRA COGE RIO ---")
	var sucios := 0
	for paraje: Paraje in sim.parajes.list:
		if paraje.activity == Subsistence.Activity.PESCA 				or paraje.activity == Subsistence.Activity.MARISQUEO:
			continue
		var mojadas := 0
		if paraje.huella != null:
			for centro: Vector3 in paraje.huella.celdas():
				if sim._terrain.crossing_difficulty_at(centro) > 0.05:
					mojadas += 1
		if mojadas > 0:
			sucios += 1
			print("   %-27s %-14s · %d celdillas con agua" % [
				paraje.name_text,
				Subsistence.activity_name(paraje.activity), mojadas])
	if sucios == 0:
		print("   ninguno")

	print("")
	print("--- QUIEN ABRE MONTE ---")
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.EXPLORACION:
			continue
		print("   %-9s %-12s · %d salidas · lo mas lejos %.0f m" % [
			person.given_name.substr(0, 9),
			Profession.speciality_name(
				person.current_speciality as Profession.Speciality),
			person.journeys.size(), _lo_mas_lejos(person)])
	print("   reconocimientos en monte SIN paraje: %d de %d" % [
		_sin_paraje, _reconocimientos])

	print("")
	_desglose(sim, demo)
	quit()


func _parte(sim: Node, demo: Node) -> void:
	var cuenta := _cuenta_celdas(sim)
	print("%5d %8d %8d %8d %9d %9d" % [
		sim.day, sim.parajes.list.size(), _marcadas(demo),
		cuenta["ricas"], cuenta["sabidas"], cuenta["libres"]])


## Cuántos alfileres hay pintados de verdad en el mundo.
func _marcadas(demo: Node) -> int:
	if not ("paraje_markers" in demo) or demo.paraje_markers == null:
		return -1
	return (demo.paraje_markers._markers as Dictionary).size()


## Las celdas del campo que podrían dar nombre, en tres cortes.
func _cuenta_celdas(sim: Node) -> Dictionary:
	var ricas := 0
	var sabidas := 0
	var libres := 0
	if sim.field == null or sim.knowledge == null:
		return {"ricas": 0, "sabidas": 0, "libres": 0}

	for actividad: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var act := actividad as Subsistence.Activity
		var worth: float = maxf(Parajes.WORTH_NAMING, sim.parajes.threshold_for(act))
		for z in range(sim.field.height):
			for x in range(sim.field.width):
				if sim.field.abundance_cell(act, x, z) < worth:
					continue
				ricas += 1
				var centre: Vector3 = sim.field.cell_center(x, z)
				if sim.knowledge.familiarity_at(act, centre) < Parajes.NAMED_AT:
					continue
				sabidas += 1
				if sim.parajes.cubre(act, centre) != null:
					continue
				libres += 1
	return {"ricas": ricas, "sabidas": sabidas, "libres": libres}


func _desglose(sim: Node, demo: Node) -> void:
	print("--- LOS PARAJES QUE HAY ---")
	for paraje: Paraje in sim.parajes.list:
		print("   dia %3d · %-27s %-14s a %4.0f m · sabido %3.0f %%" % [
			paraje.found_day, paraje.name_text,
			Subsistence.activity_name(paraje.activity),
			sim.home_position.distance_to(paraje.position),
			paraje.known_fraction() * 100.0])
	print("alfileres pintados: %d" % _marcadas(demo))

	print("")
	print("--- CUANTO CONOCE LA BANDA DEL VALLE ---")
	# Si la familiaridad no crece, no puede nacer ningun paraje nuevo por muy
	# rico que sea el monte: es el eslabon de en medio.
	for actividad: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MATERIA_PRIMA]:
		var act := actividad as Subsistence.Activity
		var pasan := 0
		var total := 0
		var suma := 0.0
		for z in range(sim.field.height):
			for x in range(sim.field.width):
				var centre: Vector3 = sim.field.cell_center(x, z)
				var f: float = sim.knowledge.familiarity_at(act, centre)
				suma += f
				total += 1
				if f >= Parajes.NAMED_AT:
					pasan += 1
		print("   %-14s familiaridad media %.3f · celdas por encima de %.2f: %d de %d" % [
			Subsistence.activity_name(act), suma / maxf(float(total), 1.0),
			Parajes.NAMED_AT, pasan, total])


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
		Profession.Job.RECOLECCION: 4,
		Profession.Job.CAZA: 3,
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
