extends SceneTree
## De que depende de verdad lo que trae una salida.
##
## Dos preguntas que se contestan con la misma medida:
##
##   - Como pulir [Tajo.HARVEST_SCALE]. Es un mando unico que compensa
##     CINCO penalizaciones multiplicadas, y un mando unico solo vale si las
##     cinco se mueven juntas. Si una de ellas domina, subir la escala es tapar
##     un agujero con una manta: la partida entera se vuelve mas facil para
##     arreglar una cosa.
##   - Por que vuelven de vacio tantas salidas. «No sabe» y «no habia» se ven
##     igual desde fuera y tienen arreglos opuestos.
##
## Se apunta cada tick de trabajo con sus factores, y al cerrar cada salida se
## guarda la media de los suyos junto a lo que trajo.
##
##   DIAS=6      cuantas jornadas
##   SEMILLA=n   para comparar dos ejecuciones

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
	var field: ResourceField = demo.field if "field" in demo else null
	if sim == null or field == null:
		print("sin simulacion o campo"); quit(); return

	sim.assign_default_jobs()
	sim.time_scale = 20.0

	var days := 6
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	# Por persona: suma de cada factor y cuantos ticks, para sacar la media.
	var tally: Dictionary = {}
	var closed: Array[Dictionary] = []
	var seen: Dictionary = {}

	var first_day: int = sim.day
	while sim.day < first_day + days:
		await process_frame
		for person: Inhabitant in sim.people:
			if person.state == Inhabitant.State.TRABAJANDO \
					and person.job != Profession.Job.MANUFACTURA \
					and person.job != Profession.Job.HOGAR:
				var row: Dictionary = tally.get(person.id, _blank())
				row["ticks"] = float(row["ticks"]) + 1.0
				row["pericia"] = float(row["pericia"]) + person.effectiveness()
				row["sitio"] = float(row["sitio"]) + sim._knowledge_factor(person)
				row["estacion"] = float(row["estacion"]) + \
					ResourceField.seasonal_factor(person.activity, GameState.season)
				var cell := field.best_cell(person.activity, person.position,
					Tajo.ALCANCE_DEL_TAJO)
				row["queda"] = float(row["queda"]) + \
					field.stock_of_cell(person.activity, cell)
				var tool_kind: int = sim._tool_for(person)
				var filo := 1.0
				if tool_kind >= 0:
					filo = sim.toolkit.efficiency(tool_kind as Tool.Kind,
						sim.workers_in(person.activity))
				row["filo"] = float(row["filo"]) + filo
				row["tiempo"] = float(row["tiempo"]) + sim.weather.work_factor()
				tally[person.id] = row

			var count: int = person.journeys.size()
			if count == int(seen.get(person.id, 0)):
				continue
			seen[person.id] = count
			var row2: Dictionary = tally.get(person.id, _blank())
			if float(row2["ticks"]) <= 0.0:
				tally[person.id] = _blank()
				continue
			var trip: Dictionary = person.journeys[count - 1]
			row2["vacio"] = 1.0 if String(trip.get("outcome", "")).begins_with(
				"volvio de vacio") else 0.0
			row2["oficio"] = float(int(trip.get("job", 0)))
			closed.append(row2)
			tally[person.id] = _blank()

	print("")
	print("=== %d SALIDAS, DESCOMPUESTAS ===" % closed.size())
	print("cada factor multiplica: pericia · sitio · estacion · queda · filo · tiempo")
	print("")
	for group: Array in [["DE VACIO", 1.0], ["CON ALGO", 0.0]]:
		var sums := _blank()
		var n := 0
		for row: Dictionary in closed:
			if not is_equal_approx(float(row["vacio"]), float(group[1])):
				continue
			n += 1
			for key: String in sums:
				sums[key] = float(sums[key]) + float(row[key]) / maxf(float(row["ticks"]), 1.0)
		if n == 0:
			continue
		# Los TICKS de trabajo: si las de vacio trabajan menos, el problema no
		# es lo que rinde una hora sino cuantas horas se llegan a trabajar.
		var ticks := 0.0
		for row: Dictionary in closed:
			if is_equal_approx(float(row["vacio"]), float(group[1])):
				ticks += float(row["ticks"])
		var oficios: Dictionary = {}
		for row: Dictionary in closed:
			if is_equal_approx(float(row["vacio"]), float(group[1])):
				var who := Profession.job_name(int(row["oficio"]) as Profession.Job)
				oficios[who] = int(oficios.get(who, 0)) + 1
		print("%-9s %d salidas · %.0f ticks de trabajo de media · %s" % [
			String(group[0]), n, ticks / float(n), str(oficios)])
		var product := 1.0
		for key: String in ["pericia", "sitio", "estacion", "queda", "filo", "tiempo"]:
			var mean := float(sums[key]) / float(n)
			product *= mean
			print("   %-9s %.3f" % [key, mean])
		print("   producto  %.4f  ·  por la escala %.0f = %.2f" % [
			product, Tajo.HARVEST_SCALE,
			product * Tajo.HARVEST_SCALE])
		print("")
	# Como acaban las caceria: es lo que decide si «vuelve de vacio» es un
	# fallo del juego o la caza siendo caza.
	print("como acaban las caceria: %s" % str(sim.caceria.hunt_endings))
	print("piezas cobradas: %d · caceria abiertas ahora: %d" % [
		sim.caceria.kills_today.size(), sim.caceria.hunts.size()])

	# Y como crece la pericia, que es el factor que mas pesa y el unico que
	# CAMBIA con la partida: un mando fijo no puede estar bien en los dos
	# extremos.
	print("")
	print("pericia por oficio, al cabo de %d jornadas:" % days)
	var por_oficio: Dictionary = {}
	for person: Inhabitant in sim.people:
		var who := Profession.job_name(person.job as Profession.Job)
		var row: Array = por_oficio.get(who, [0.0, 0, 0.0])
		row[0] = float(row[0]) + person.effectiveness()
		row[1] = int(row[1]) + 1
		row[2] = maxf(float(row[2]), person.skill_in(person.current_task()))
		por_oficio[who] = row
	for who: String in por_oficio:
		var row: Array = por_oficio[who]
		print("   %-14s eficacia %.3f · la mejor destreza %.3f (tope 0.95)" % [
			who, float(row[0]) / float(row[1]), float(row[2])])
	quit()


func _blank() -> Dictionary:
	return {"ticks": 0.0, "pericia": 0.0, "sitio": 0.0, "estacion": 0.0,
		"queda": 0.0, "filo": 0.0, "tiempo": 0.0, "vacio": 0.0, "oficio": 0.0}
