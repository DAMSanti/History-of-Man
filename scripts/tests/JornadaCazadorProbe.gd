extends SceneTree
## En que se le va el dia a un cazador.
##
## La pregunta que queda despues de arreglar el acarreo. Medido con
## `CazaEscalonProbe`, doce jornadas y siete cazadores con azagaya: CUATRO
## caceria, cuatro piezas cobradas, 0,93 raciones por cazador y dia. O sea que
## el lance no falla —cuatro de cuatro— y la pieza rinde: lo que no pasa es
## LEVANTARLA. Una caceria cada veintiun jornadas de cazador.
##
## El modelo dice otra cosa. `_tracking_hours` reparte la jornada perfecta
## —1,6 piezas de caza mayor, 2,56 con azagaya— entre las horas utiles, asi que
## cortar un rastro deberia costar del orden de dia y medio con la destreza que
## tiene la banda. De dia y medio a veintiuno hay un factor catorce sin
## explicar, y este es el sitio donde se ve: por cada tick de cazador se apunta
## en que estaba.
##
##   DIAS=12   jornadas a seguir

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

	# Con azagaya, que es el escalon donde la caza ya cobra: sin ella el
	# alcance es de tres metros y no se llega a tirar nunca.
	sim.techs.known[TechTree.Tech.AZAGAYA] = true
	for i in range(8):
		sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.6)

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

	var days := 12
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	var reparto: Dictionary = {}
	var horas := 0.0
	var sin_pieza_cerca := 0
	var con_pieza_cerca := 0
	var first_day: int = sim.day
	var last: int = -1
	while sim.day < first_day + days:
		await process_frame
		for person: Inhabitant in sim.people:
			if person.job != Profession.Job.CAZA:
				continue
			var donde := _donde(sim, person)
			reparto[donde] = int(reparto.get(donde, 0)) + 1
		# Una vez por hora: cuanta pieza tiene al alcance quien esta batiendo.
		if int(sim.hour) == last:
			continue
		last = int(sim.hour)
		horas += 1.0
		for person: Inhabitant in sim.people:
			if person.job != Profession.Job.CAZA \
					or person.state != Inhabitant.State.TRABAJANDO \
					or sim.caceria.hunt_of(person) != null:
				continue
			if sim.caceria.wildlife == null:
				continue
			var cerca: Dictionary = sim.caceria.wildlife.quarry_near(
				person.position, Hunt.BUSCA_PIEZA_M,
				sim.caceria._huntable_species(Profession.Speciality.CAZA_MAYOR))
			if cerca.is_empty():
				sin_pieza_cerca += 1
			else:
				con_pieza_cerca += 1

	var total := 0
	for key: String in reparto:
		total += int(reparto[key])
	print("")
	print("=== EN QUE SE LE VA EL DIA A UN CAZADOR (%d cazadores, %d jornadas) ===" % [
		sent, days])
	var orden: Array[String] = []
	orden.assign(reparto.keys())
	orden.sort_custom(func(a: String, b: String) -> bool:
		return int(reparto[a]) > int(reparto[b]))
	for key: String in orden:
		print("  %-28s %7d ticks  %5.1f %%" % [
			key, int(reparto[key]), 100.0 * float(reparto[key]) / maxf(float(total), 1.0)])
	# Las dos cifras que deciden cada cuanto se levanta una pieza: lo que pide
	# el rastreo y lo que se le puede dedicar al dia. Si la primera es mucho
	# mayor que la segunda, la caceria no empieza y da igual todo lo demas.
	var pide := 0.0
	var cuantos := 0
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.CAZA:
			continue
		pide += sim.caceria._tracking_hours(person)
		cuantos += 1
	pide /= maxf(float(cuantos), 1.0)
	var trabajando := 0
	for key: String in reparto:
		if key == "cortando rastro" or key == "batiendo el monte" 				or key.begins_with("caceria:"):
			trabajando += int(reparto[key])
	var horas_de_trabajo := 24.0 * float(trabajando) / maxf(float(total), 1.0)
	print("")
	print("el rastreo pide %.1f h · al dia se trabaja %.1f h -> una pieza cada %.1f jornadas" % [
		pide, horas_de_trabajo, pide / maxf(horas_de_trabajo, 0.01)])
	print("")
	print("batiendo el monte, con pieza al alcance (%.0f m): %d de %d ratos (%.0f %%)" % [
		Hunt.BUSCA_PIEZA_M, con_pieza_cerca, con_pieza_cerca + sin_pieza_cerca,
		100.0 * float(con_pieza_cerca) / maxf(float(con_pieza_cerca + sin_pieza_cerca), 1.0)])
	print("finales de caceria: %s · lances fallados: %d · la mas larga %d jornadas" % [
		str(sim.caceria.hunt_endings), sim.caceria.lances_fallados,
		sim.caceria.jornadas_mas_larga])
	quit()


## La etiqueta de lo que esta haciendo AHORA, con el detalle de la caza.
func _donde(sim: Node, person: Inhabitant) -> String:
	if person.state != Inhabitant.State.TRABAJANDO:
		return person.state_name()
	var hunt: Hunt = sim.caceria.hunt_of(person)
	if hunt != null:
		return "caceria: " + String(Hunt.Phase.keys()[int(hunt.phase)]).to_lower()
	if person.hunt_cooldown > 0.0:
		return "cortando rastro"
	return "batiendo el monte"
