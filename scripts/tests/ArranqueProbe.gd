extends SceneTree
## Las primeras jornadas de una partida, persona a persona.
##
## Es la queja literal del jugador: «mis recolectores, cazadores y pescadores se
## van a 600 m en línea recta hasta que tienen que volver con las manos vacías;
## el explorador tarda dos días en descubrir el primer paraje y hasta el día
## cinco no descubre el primer material». Un mes para empezar a trabajar.
##
## Aquí se mira lo único que contesta por qué: dónde acaba cada cual, si tenía
## celda que trabajar debajo, y qué trajo. `_harvest` multiplica por
## `stock_of_cell(best_cell(...))`, así que si no hay celda CON CAPACIDAD a
## ochenta metros el multiplicador es cero y la jornada entera se pierde
## andando.
##
##   DIAS=8    cuántas jornadas seguir

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sim := await _arrancar()
	if sim == null:
		quit()
		return
	_repartir(sim)
	sim.time_scale = 20.0

	var dias := 8
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== LAS PRIMERAS %d JORNADAS ===" % dias)
	var quien: Dictionary = {}
	for p: Inhabitant in sim.people:
		var j := Profession.job_name(p.job as Profession.Job)
		quien[j] = int(quien.get(j, 0)) + 1
	print("reparto: %s" % str(quien))
	print("parajes conocidos al empezar: %d" % sim.parajes.list.size())
	print("")

	# A MEDIODIA, no al cambiar el dia. Medir al filo de la medianoche es medir
	# a gente dormida que ya ha descargado: la primera version de esta sonda
	# decia «lleva 0.0» de los quince y no era verdad, era la hora.
	var primero: int = sim.day
	var visto := -1
	var mojados := 0
	var antes := _total_en_despensa(sim)
	while sim.day < primero + dias:
		await process_frame
		# En CADA cuadro, no solo a mediodia: cruzar el rio dura unos segundos
		# y mirando una vez al dia no se ve nunca.
		mojados += _pisadas_en_lo_hondo(sim)
		if sim.day == visto or sim.hour < 14.0 or sim.hour > 15.0:
			continue
		visto = sim.day
		_parte_del_dia(sim, antes)
		antes = _total_en_despensa(sim)

	print("")
	print("--- Y AL CABO ---")
	print("pisadas en agua que no se vadea: %d" % mojados)
	print("parajes conocidos: %d" % sim.parajes.list.size())
	for paraje: Paraje in sim.parajes.list:
		print("   %-26s %-14s a %4.0f m · sabido %.0f %%" % [
			paraje.name_text,
			Subsistence.activity_name(paraje.activity),
			sim.home_position.distance_to(paraje.position),
			paraje.known_fraction() * 100.0])
	print("")
	print("en la despensa:")
	for kind: int in Materia.Kind.values():
		var hay: float = sim.store.amount(kind as Materia.Kind)
		if hay > 0.05:
			print("   %-16s %.1f" % [
				Materia.material_name(kind as Materia.Kind), hay])


## El parte de una jornada: dónde acabó cada cual y si tenía algo debajo.
func _parte_del_dia(sim: Node, antes: float) -> void:
	print("dia %d · en la despensa %+.1f desde ayer · %d parajes" % [
		sim.day, _total_en_despensa(sim) - antes, sim.parajes.list.size()])
	for person: Inhabitant in sim.people:
		# Por OFICIO, no por actividad: quien cuida el fuego no tiene actividad
		# puesta y salia listado como cazador.
		if person.job == Profession.Job.OCIOSO 				or person.job == Profession.Job.HOGAR 				or person.job == Profession.Job.MANUFACTURA:
			continue
		var act := person.activity as Subsistence.Activity
		var lejos: float = sim.home_position.distance_to(person.position)
		# Lo que decide si la jornada vale algo: hay celda con capacidad de SU
		# actividad al alcance del tajo, o no.
		var celda := -1
		var queda := 0.0
		if sim.field != null:
			celda = sim.field.best_cell(act, person.position, Tajo.ALCANCE_DEL_TAJO)
			queda = sim.field.stock_of_cell(act, celda)
		var trajo := 0.0
		for kind: int in person.load:
			trajo += float(person.load[kind])
		print("   %-9s %-11s %-12s a %4.0f m · celda %s · queda %3.0f %% · lleva %5.1f · %s" % [
			person.given_name.substr(0, 9),
			Profession.job_name(person.job as Profession.Job),
			Subsistence.activity_name(act),
			lejos,
			"NO" if celda < 0 else "si",
			queda * 100.0, trajo,
			person.state_name()])


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
	for i in range(90):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo.sim


## Lo que hace el jugador al empezar: dos de cada y uno a explorar.
func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 2,
		Profession.Job.CAZA: 2,
		Profession.Job.RIBERA: 2,
		Profession.Job.EXPLORACION: 1,
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


## Cuántas veces alguien ha puesto el pie en agua que no se vadea.
##
## Es la comprobación de «hay algún poblador que ha cruzado el río y no sé por
## dónde»: si esto sale por encima de cero, alguien está andando por lo hondo.
func _pisadas_en_lo_hondo(sim: Node) -> int:
	var cuantas := 0
	for person: Inhabitant in sim.people:
		var calado: float = sim._terrain.crossing_difficulty_at(person.position)
		if not Hydrography.can_cross(calado, sim.has_boat, sim.has_bridge):
			cuantas += 1
	return cuantas


## Lo que hay en la despensa ahora mismo, todo junto.
func _total_en_despensa(sim: Node) -> float:
	var total := 0.0
	for kind: int in Materia.Kind.values():
		total += sim.store.amount(kind as Materia.Kind)
	return total
