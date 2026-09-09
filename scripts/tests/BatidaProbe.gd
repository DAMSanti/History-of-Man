extends SceneTree
## Que hacen los batidores, jornada a jornada.
##
## Es la queja literal del jugador: «los batidores no estan yendo a los parajes
## a descubrir materiales que estan en ??, de hecho no estan haciendo nada».
##
## Aqui se sigue a cada explorador en cada cuadro y se apunta lo unico que
## contesta por que: en que estado pasa las horas, si tenia un paraje con
## incognitas al que ir, si llego a el, y cuantas incognitas resolvio.
##
##   DIAS=10   cuantas jornadas seguir

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

	var dias := 10
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== LOS BATIDORES, %d JORNADAS ===" % dias)

	# Cuantos cuadros pasa cada explorador en cada estado. Es la cifra que dice
	# «no hacen nada»: si casi todo cae en PARADO o VOLVIENDO, no baten.
	var horas: Dictionary = {}
	var incognitas_antes := _incognitas(sim)
	var visitas := 0
	var salidas := 0
	var estaba: Dictionary = {}
	var visto := -1
	var primero: int = sim.day

	while sim.day < primero + dias:
		await process_frame
		for p: Inhabitant in sim.people:
			if p.job != Profession.Job.EXPLORACION:
				continue
			var estado := p.state_name()
			horas[estado] = int(horas.get(estado, 0)) + 1
			if p.state == Inhabitant.State.RECONOCIENDO \
					and sim._paraje_at(p.work_centre) != null:
				visitas += 1
			# Una batida TERMINADA es la que resuelve incognitas: el paso de
			# reconocer a volver. Contarlas aparte separa «no llegan» de
			# «llegan y no encuentran nada».
			var antes_estado := int(estaba.get(p.given_name, -1))
			if antes_estado == int(Inhabitant.State.RECONOCIENDO) 					and int(p.state) != antes_estado:
				salidas += 1
			estaba[p.given_name] = int(p.state)
		if sim.day == visto or sim.hour < 13.0 or sim.hour > 14.0:
			continue
		visto = sim.day
		var cuenta := _incognitas(sim)
		print("")
		print("dia %d · batidas terminadas %d · sabido %d de %d" % [
			sim.day, salidas, cuenta[1] - cuenta[0], cuenta[1]])
		_parte(sim)

	print("")
	print("--- EN QUE PASAN EL TIEMPO (cuadros) ---")
	var total := 0
	for e: String in horas:
		total += int(horas[e])
	for e: String in horas:
		print("   %-14s %5d  (%.0f %%)" % [e, int(horas[e]),
			100.0 * float(horas[e]) / maxf(float(total), 1.0)])
	print("cuadros RECONOCIENDO dentro de un paraje: %d" % visitas)
	print("batidas terminadas: %d" % salidas)
	print("")
	print("--- LAS INCOGNITAS ---")
	var ahora := _incognitas(sim)
	print("al empezar: %d sin saber de %d" % [incognitas_antes[0], incognitas_antes[1]])
	print("al acabar:  %d sin saber de %d" % [ahora[0], ahora[1]])
	for paraje: Paraje in sim.parajes.list:
		print("   %-26s %-14s a %4.0f m · sabido %3.0f %% · %d cosas" % [
			paraje.name_text,
			Subsistence.activity_name(paraje.activity),
			sim.home_position.distance_to(paraje.position),
			paraje.known_fraction() * 100.0,
			paraje.contents.size()])
	quit()


func _parte(sim: Node) -> void:
	for p: Inhabitant in sim.people:
		if p.job != Profession.Job.EXPLORACION:
			continue
		var pendiente: Paraje = sim._paraje_to_survey(p)
		var encima: Paraje = sim._paraje_at(p.work_centre)
		print("   %-9s %-14s %-13s a %4.0f m · pendiente: %-22s · encima: %s" % [
			p.given_name.substr(0, 9),
			Profession.speciality_name(p.current_speciality as Profession.Speciality),
			p.state_name(),
			sim.home_position.distance_to(p.position),
			"ninguno" if pendiente == null else pendiente.name_text,
			"NO" if encima == null else encima.name_text])


## Cuantas cosas hay por saber en los parajes, y cuantas hay en total.
func _incognitas(sim: Node) -> Array:
	var sin_saber := 0
	var todas := 0
	for paraje: Paraje in sim.parajes.list:
		for kind: int in paraje.contents:
			todas += 1
			if not bool((paraje.contents[kind] as Dictionary)["sabido"]):
				sin_saber += 1
	return [sin_saber, todas]


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


## Dos de cada y DOS a explorar, que es de lo que va esto.
func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 2,
		Profession.Job.CAZA: 2,
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
