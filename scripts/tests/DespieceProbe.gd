extends SceneTree
## Por que la carne se queda en el monte.
##
## Medido con `CazaEscalonProbe`: doce jornadas, un uro cobrado, DOSCIENTAS
## CINCUENTA Y SIETE unidades de carne -ciento cuarenta raciones, cinco dias de
## comida para la banda entera- tiradas en el suelo, la caceria todavia en
## DESPIECE al acabar y una sola persona fuera del abrigo. O sea: la caza si
## cobra, pero lo cobrado no llega.
##
## «No llega» son tres averias distintas que desde fuera se ven igual: que no
## se termine de abrir la pieza, que se abra y nadie vuelva a por ella, o que
## se vuelva y no quepa. Esto las separa: por cada hora de juego apunta, de
## cada caceria con pieza en el suelo, en que fase esta, cuanto lleva abierta
## de lo que hay que abrir, quien sigue en la cuadrilla, donde esta cada uno y
## a que distancia de la pieza.
##
##   DIAS=10   cuantas jornadas seguir

const SITE_ID := 56


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

	# TODA la banda a la caza mayor, y no media. Con media, la despensa sigue
	# llena y `task_blocked_by` cierra la caza entera -«la despensa esta al
	# tope; nadie sale a por mas comida»-: se midieron diez jornadas con cinco
	# cazadores que en realidad estaban todos sin oficio.
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
		sent += 1
	sim.apply_priorities()
	sim.time_scale = 20.0

	var days := 10
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	print("")
	print("=== EL DESPIECE, HORA A HORA (%d cazadores) ===" % sent)

	# Se PLANTA la pieza cobrada en vez de esperar a que caiga una sola.
	# Esperandola, diez jornadas con cinco cazadores dieron UNA caceria y cero
	# piezas: no se puede medir el acarreo con eso. Lo que se viene a mirar
	# empieza despues del lance, asi que el lance se da por hecho.
	# Media manana del dia siguiente: a medianoche estan todos en el abrigo y
	# no hay a quien plantarle la pieza.
	# Se espera a que HAYA cazador en el monte, y no a una hora fija. La
	# partida empieza con la despensa al tope y `task_blocked_by` cierra la
	# caza entera mientras lo este -«nadie sale a por mas comida»-: en las
	# primeras jornadas la banda entera figura sin oficio.
	var first_day: int = sim.day
	var quien: Inhabitant = null
	while quien == null and sim.day < first_day + 6:
		await process_frame
		for person: Inhabitant in sim.people:
			if person.job == Profession.Job.CAZA and not sim._at_shelter(person) 					and sim.caceria.hunt_of(person) == null:
				quien = person
				break
	if quien == null:
		print("ningun cazador salio al monte en seis jornadas (dia %d)" % sim.day)
		for person: Inhabitant in sim.people:
			print("   %-6s %-12s %-11s a %.0f m del abrigo" % [
				person.given_name,
				Profession.job_name(person.job as Profession.Job),
				person.state_name(),
				person.position.distance_to(sim.home_position)])
		quit(); return
	var animal: Dictionary = sim.caceria.wildlife.place_for_test("uro", quien.position)
	var puesta := Hunt.create("uro", animal, quien)
	puesta.kill_site = quien.position
	puesta.day = sim.day
	puesta.counted_day = sim.day
	puesta.spoils = Hunt.spoils_of("uro")
	puesta.phase = Hunt.Phase.DESPIECE
	sim.caceria.hunts.append(puesta)
	sim.caceria.kills_today.append(puesta)
	print("uro puesto a %.0f m del abrigo · %.0f u de carne · %.2f jornadas de despiece" % [
		quien.position.distance_to(sim.home_position),
		float(puesta.spoils.get(int(Materia.Kind.CARNE), 0.0)),
		Hunt.butcher_days("uro")])

	sim.taller.produced_days.clear()
	sim.taller.produced_today.clear()
	var last_hour := -1
	while sim.day < first_day + days:
		await process_frame
		var hour := int(sim.hour)
		if hour == last_hour:
			continue
		last_hour = hour
		for hunt: Hunt in sim.caceria.hunts:
			if hunt.spoils.is_empty():
				continue
			_parte(sim, hunt)

	# Lo PRODUCIDO y no el delta del almacen: con la banda entera cazando, la
	# carne se come segun entra y el delta sale cero aunque hayan llegado
	# doscientas unidades.
	var carne := 0.0
	for a_day: Dictionary in sim.taller.produced_days:
		carne += float(a_day.get(int(Materia.Kind.CARNE), 0.0))
	carne += float(sim.taller.produced_today.get(int(Materia.Kind.CARNE), 0.0))
	print("")
	print("carne entregada al almacen: %.1f (el almacen tiene %.1f)" % [
		carne, sim.store.amount(Materia.Kind.CARNE)])
	var suelo := 0.0
	for hunt: Hunt in sim.caceria.hunts:
		suelo += float(hunt.spoils.get(int(Materia.Kind.CARNE), 0.0))
	print("carne en el suelo sin acarrear: %.1f" % suelo)
	print("finales de caceria: %s" % str(sim.caceria.hunt_endings))
	print("lances fallados: %d" % sim.caceria.lances_fallados)
	quit()


## El parte de una pieza en el suelo: todo lo que decide si llega o no.
func _parte(sim: Node, hunt: Hunt) -> void:
	var falta := Hunt.butcher_days(hunt.species)
	print("d%d %2dh %-8s %-10s abierta %.2f/%.2f · en el suelo %.0f u · cuadrilla %d" % [
		sim.day, int(sim.hour), Fauna.species_name(hunt.species),
		String(Hunt.Phase.keys()[int(hunt.phase)]),
		hunt.opened, falta, hunt.spoils_kg(), hunt.crew.size()])
	for person: Inhabitant in hunt.crew:
		print("      %-6s %-11s a %5.0f m de la pieza · fatiga %2.0f · hambre %2.0f · carga %.0f%%" % [
			person.given_name, person.state_name(),
			person.position.distance_to(hunt.kill_site),
			person.fatigue, person.hunger, person.load_fraction() * 100.0])
	if hunt.crew.is_empty():
		var cerca := 0
		for person: Inhabitant in sim.people:
			if person.position.distance_to(hunt.kill_site) < 400.0:
				cerca += 1
		print("      SIN CUADRILLA · gente a menos de 400 m de la pieza: %d" % cerca)
