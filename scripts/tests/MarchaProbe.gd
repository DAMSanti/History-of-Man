extends SceneTree
## Si la banda entera anda o se atora.
##
## `CazaMenorProbe` mira una cuadrilla puesta a una sola cosa, que es como se
## encontro la averia; esto mira la partida tal como se juega: todo el mundo en
## su oficio, varios dias seguidos, y se cuenta cuantas salidas se cierran mal.
##
## Se separan dos cosas que el jugador ve juntas y no lo son:
##
##   - ATASCO: hay camino, el suelo deja pasar y aun asi no se anda. Eso es una
##     averia; el objetivo es cero.
##   - RENUNCIA: se ha trazado camino tres veces contra la misma pared y se deja
##     ese sitio por imposible. No es una averia -es la salida de emergencia-,
##     pero muchas seguidas significan que la rejilla miente sobre el terreno.
##
## Y de paso el reparto del dia, que es lo que dice si la banda VIVE o solo no
## se atora. Tres cifras que hay que mirar juntas:
##
##   - En que se van las horas de luz. Andar no es trabajar: la primera vez
##     que se midio salio 42 % andando contra 9 % trabajando, y ahi estaban
##     escondidas dos averias -el hogar y el taller trabajando desde OCIOSO, y
##     la banda sin poder cerrar los ultimos veinte metros de vuelta a casa.
##   - Cuantas salidas vuelven de vacio, y cuanto anduvieron. Que las de vacio
##     sean MAS CORTAS que las que traen algo es la firma de que no llegan; que
##     anden lo mismo quiere decir que llegan y no cobran, que es otra cosa.
##   - Raciones en la despensa y cargas tiradas por no llegar a entregarlas.
##
##   DIAS=8      cuantas jornadas seguir
##   SEMILLA=n   fijar la suerte para poder comparar dos ejecuciones

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
	for i in range(60):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("sin simulacion"); quit(); return

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	var days := 8
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))
	sim.time_scale = 20.0

	var first_day: int = sim.day
	# En que se va el dia. Una salida corta y de vacio puede ser que no se
	# llegue -movimiento- o que se llegue y no se trabaje -otra cosa-, y esas
	# dos se distinguen contando en que estado esta la gente de dia.
	var census: Dictionary = {}
	var ticks := 0
	while sim.day < first_day + days:
		await process_frame
		# La primera manana llena el registro con el arranque de la partida:
		# se vacia una vez pasada para que quepa lo que se viene a mirar.
		if sim.day == first_day + 1 and not sim.stuck_reports.is_empty():
			sim.stuck_reports.clear()
		if sim.hour < 7.0 or sim.hour > 20.0:
			continue
		ticks += 1
		for person: Inhabitant in sim.people:
			var name := person.state_name()
			census[name] = int(census.get(name, 0)) + 1
			# Volver estando ya en casa no es volver. Se cuenta aparte porque un
			# «volviendo» de dos horas a diez metros de la boca es otra vez la
			# pantalla diciendo lo que no es.
			if person.state == Inhabitant.State.VOLVIENDO \
				and person.position.distance_to(sim.home_position) < 30.0:
				census["volviendo A DIEZ PASOS DE CASA"] = int(
					census.get("volviendo A DIEZ PASOS DE CASA", 0)) + 1
			if person.state != Inhabitant.State.OCIOSO:
				continue
			# Un ocioso a las once de la manana con tarea asignada y a un paso
			# del abrigo es una jornada perdida; uno a las siete de la tarde ya
			# de vuelta, no. Se apunta la hora y si tenia algo que hacer.
			var idle := "ocioso: %-12s %s %s" % [
				Profession.job_name(person.job as Profession.Job),
				"con tarea" if person.has_task else "sin tarea",
				"en casa" if person.position.distance_to(
					sim.home_position) < 80.0 else "fuera"]
			census[idle] = int(census.get(idle, 0)) + 1

	var trips := 0
	var by_outcome: Dictionary = {}
	var abandoned := 0
	for person: Inhabitant in sim.people:
		abandoned += person.given_up.size()
		for trip: Dictionary in person.journeys:
			trips += 1
			var why := String(trip.get("outcome", "sin motivo"))
			if why.contains(":"):
				why = why.split(":")[0]
			by_outcome[why] = int(by_outcome.get(why, 0)) + 1

	print("")
	print("=== %d JORNADAS DE LA BANDA ENTERA ===" % days)
	print("%d personas · %d salidas" % [sim.people.size(), trips])
	print("")
	var order: Array = by_outcome.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		return int(by_outcome[a]) > int(by_outcome[b]))
	for why: String in order:
		print("  %4d (%5.1f %%)  %s" % [int(by_outcome[why]),
			100.0 * float(by_outcome[why]) / maxf(float(trips), 1.0), why])

	# Volver de vacio tambien puede ser movimiento disfrazado: si se vuelve de
	# vacio SIN haber llegado, el problema sigue siendo andar; si se llego y se
	# trabajo, es cosecha, que es otra averia y de otro dia.
	print("")
	print("las horas de luz, en que se van:")
	var states: Array = census.keys()
	states.sort_custom(func(a: String, b: String) -> bool:
		return int(census[a]) > int(census[b]))
	var moments := maxf(float(ticks * sim.people.size()), 1.0)
	for name: String in states:
		if 100.0 * float(census[name]) / moments < 0.4:
			continue
		print("  %5.1f %%  %s" % [100.0 * float(census[name]) / moments, name])

	print("")
	print("las salidas, por oficio y por si trajeron algo:")
	var empty_by_job: Dictionary = {}
	for person: Inhabitant in sim.people:
		for trip: Dictionary in person.journeys:
			var full := not String(trip.get("outcome", "")).begins_with("volvio de vacio")
			var who := "%s %s" % [
				Profession.job_name(int(trip.get("job", 0)) as Profession.Job),
				"CON ALGO" if full else "de vacio"]
			var row: Array = empty_by_job.get(who, [0, 0.0, 0.0])
			row[0] = int(row[0]) + 1
			row[1] = float(row[1]) + float(trip.get("metres", 0.0))
			row[2] = float(row[2]) + float(trip.get("farthest", 0.0))
			empty_by_job[who] = row
	for who: String in empty_by_job:
		var row: Array = empty_by_job[who]
		print("  %4d  %-12s anduvo %5.0f m de media, se alejo %4.0f m" % [
			int(row[0]), who, float(row[1]) / float(row[0]),
			float(row[2]) / float(row[0])])

	print("")
	# Lo que de verdad dice si la banda vive: raciones en la despensa y cuantas
	# cargas se han tirado por no llegar a entregarlas.
	print("")
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	print("despensa: %.1f raciones · %.1f dias de comida para %d bocas" % [
		sim.store.food_rations(), sim.store.food_rations() / maxf(mouths, 0.001),
		sim.people.size()])
	print("cargas perdidas por no llegar a casa: %d" % sim.lost_loads)
	print("atascos por motivo: %s" % str(sim.stuck_tally))
	print("sitios dados por imposibles ahora mismo: %d" % abandoned)
	print("")
	print(sim.stuck_report_text())
	quit()
