extends SceneTree
## Por que la recoleccion vuelve de vacio.
##
## Medido con la banda entera ocho jornadas: el 85 % de las salidas de
## recoleccion se cierra con «volvio de vacio», y las de vacio son mas cortas
## que las que traen algo -611 m frente a 974-. Eso admite tres explicaciones
## muy distintas que desde fuera se ven igual:
##
##   - NO LLEGAN A TRABAJAR: se pasan la salida buscando y se les acaba el dia.
##   - TRABAJAN Y NO COBRAN: entran en TRABAJANDO y la cosecha sale a cero.
##   - COBRAN Y NO CUENTA: traen algo pero por debajo de lo que el rastro
##     considera digno de mencion.
##
## Aqui se cuenta, salida por salida, cuanto tiempo se ha estado en cada estado
## y cuanto se ha traido. Y ademas se descompone el multiplicador de `_harvest`
## para un recolector tipo, que es donde estaria el cero si lo hay.
##
##   DIAS=8      cuantas jornadas seguir

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

	# Horas por estado de la salida EN CURSO de cada persona. Se vuelca cuando
	# la persona cierra una salida, o sea cuando le crece el historial.
	var stranded: Dictionary = {}
	var running: Dictionary = {}
	var seen: Dictionary = {}
	var closed: Array[Dictionary] = []
	var last_hour: float = sim.hour

	var first_day: int = sim.day
	while sim.day < first_day + days:
		await process_frame
		var step: float = sim.hour - last_hour
		if step < 0.0:
			step += 24.0
		last_hour = sim.hour
		for person: Inhabitant in sim.people:
			if person.job != Profession.Job.RECOLECCION:
				continue
			# Donde se planta el que «vuelve». Cinco horas volviendo de un tajo a
			# doscientos metros no es andar: es no llegar nunca.
			# Y donde se para el que ya ha llegado. `_settle_at_home` solo recoge a
			# quien esta a tres radios de llegada; mas lejos se queda plantado donde
			# le pillo, y eso seria dormir a treinta metros de la cueva.
			if person.state == Inhabitant.State.DURMIENDO \
				or person.state == Inhabitant.State.OCIOSO:
				var off := person.position.distance_to(sim.home_position)
				if off > sim.arrive_radius * 3.0 and off <= Navgrid.CELL:
					stranded["EN EL MONTE, a %d-%d m del abrigo" % [
						int(sim.arrive_radius * 3.0), int(Navgrid.CELL)]] = float(
						stranded.get("EN EL MONTE, a %d-%d m del abrigo" % [
							int(sim.arrive_radius * 3.0), int(Navgrid.CELL)], 0.0)) + step
			if person.state == Inhabitant.State.VOLVIENDO:
				var away := person.position.distance_to(sim.home_position)
				var band := "lejos (mas de 40 m)"
				if away < sim.arrive_radius:
					band = "encima de casa (menos de %d m)" % int(sim.arrive_radius)
				elif away < 40.0:
					band = "EN LA PUERTA (%d-40 m)" % int(sim.arrive_radius)
				var key := "%s · ruta %s" % [band,
					"pendiente" if person.route_step < person.route.size() else "AGOTADA"]
				stranded[key] = float(stranded.get(key, 0.0)) + step
			var tally: Dictionary = running.get(person.id, {})
			tally[person.state_name()] = float(
				tally.get(person.state_name(), 0.0)) + step
			running[person.id] = tally
			var count: int = person.journeys.size()
			if count == int(seen.get(person.id, 0)):
				continue
			seen[person.id] = count
			var trip: Dictionary = person.journeys[count - 1]
			tally["salida"] = String(trip.get("outcome", ""))
			tally["metros"] = float(trip.get("metres", 0.0))
			closed.append(tally)
			running[person.id] = {}

	# El reparto de horas, separando las que trajeron algo de las que no.
	print("")
	print("=== %d SALIDAS DE RECOLECCION ===" % closed.size())
	for group: Array in [["DE VACIO", true], ["CON ALGO", false]]:
		var hours: Dictionary = {}
		var trips := 0
		var metres := 0.0
		for trip: Dictionary in closed:
			var empty := String(trip.get("salida", "")).begins_with("volvio de vacio")
			if empty != bool(group[1]):
				continue
			trips += 1
			metres += float(trip.get("metros", 0.0))
			for key: String in trip:
				if key == "salida" or key == "metros":
					continue
				hours[key] = float(hours.get(key, 0.0)) + float(trip[key])
		if trips == 0:
			continue
		print("")
		print("%s: %d salidas, %.0f m de media" % [
			String(group[0]), trips, metres / float(trips)])
		var order: Array = hours.keys()
		order.sort_custom(func(a: String, b: String) -> bool:
			return float(hours[a]) > float(hours[b]))
		for key: String in order:
			print("   %5.2f h de media  %s" % [float(hours[key]) / float(trips), key])

	# Y de que se compone lo que cobra una hora de trabajo. Es el otro sitio
	# donde puede estar el cero, y no se ve en ningun estado.
	print("")
	print("=== DONDE ESTA EL QUE «VUELVE», EN HORAS-PERSONA ===")
	var where: Array = stranded.keys()
	where.sort_custom(func(a: String, b: String) -> bool:
		return float(stranded[a]) > float(stranded[b]))
	for key: String in where:
		print("  %7.1f h  %s" % [float(stranded[key]), key])
	print("")
	print("=== EL MULTIPLICADOR DE UNA HORA, RECOLECTOR A RECOLECTOR ===")
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.RECOLECCION:
			continue
		var skill: float = person.effectiveness() * sim._knowledge_factor(person)
		var season: float = ResourceField.seasonal_factor(
			person.activity, GameState.season)
		var left := 1.0
		if sim.field:
			left = sim.field.seasonal_abundance_at(
				person.activity, person.position, GameState.season)
		var tool_factor := 1.0
		var tool_kind: int = sim.taller._tool_for(person)
		if tool_kind >= 0:
			tool_factor = sim.toolkit.efficiency(tool_kind as Tool.Kind,
				sim.taller.workers_in(person.activity))
		print("%-6s %-14s destreza %.2f · estacion %.2f · paraje %.2f · filo %.2f · tiempo %.2f" % [
			person.given_name,
			Subsistence.activity_name(person.activity),
			skill, season, left, tool_factor, sim.weather.work_factor()])
	print("")
	print("escala de cosecha: %.3f" % sim.HARVEST_SCALE)
	print("almacen: %s" % sim.store.summary_text() if sim.store.has_method(
		"summary_text") else "")
	quit()
