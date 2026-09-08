extends SceneTree
## Un año entero de partida, estacion a estacion.
##
## Es la pregunta que ninguna prueba contesta: ¿se puede JUGAR esto? Las
## pruebas dicen que cada pieza funciona y las sondas miden un oficio cada una;
## esto deja correr la banda un año con el reparto por defecto y apunta lo que
## de verdad decide la partida.
##
## Por cada estacion: cuanta gente, cuanto se come, cuanto entra de cada cosa,
## que se pudre, que se aprende, quien se hace daño y en que se va el dia.
##
##   DIAS=180   cuantas jornadas seguir

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
		if s.id == SITE_ID: site = s
	if site == null:
		print("sin emplazamiento"); quit(); return
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
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("sin simulacion"); quit(); return

	# La partida arranca sin repartir -la primera decision es del jugador-, asi
	# que la sonda reparte por defecto para poder medir un año de banda viva.
	sim.assign_default_jobs()
	sim.time_scale = 20.0

	var dias := 180
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== UN AÑO DE PARTIDA (%d jornadas) ===" % dias)
	print("%-6s %-11s %5s %7s %7s %6s %6s %7s  %s" % [
		"dia", "estacion", "gente", "despensa", "dias", "hambre", "cansa", "heridos",
		"tecnicas"])

	var primero: int = sim.day
	var ultimo: int = -1
	var pudrido := 0.0
	var por_estacion: Dictionary = {}
	while sim.day < primero + dias:
		await process_frame
		if sim.day == ultimo:
			continue
		ultimo = sim.day
		pudrido += sim.spoiled_rations_today
		var est := Subsistence.season_name(GameState.season)
		por_estacion[est] = float(por_estacion.get(est, 0.0)) + sim.spoiled_rations_today
		if (sim.day - primero) % 15 != 0:
			continue
		var hambre := 0.0
		var cansa := 0.0
		var heridos := 0
		var comen := 0.0
		for p: Inhabitant in sim.people:
			hambre += p.hunger
			cansa += p.fatigue
			comen += p.daily_food()
			if p.hurt_days > 0:
				heridos += 1
		var n := maxf(float(sim.people.size()), 1.0)
		var per := 0.0
		var efi := 0.0
		var cuantos := 0
		for p3: Inhabitant in sim.people:
			if p3.job != Profession.Job.RECOLECCION:
				continue
			per += p3.skill_in(p3.current_task())
			efi += p3.effectiveness()
			cuantos += 1
		if cuantos > 0:
			print("        pericia media del recolector %.3f · efectividad %.3f" % [
				per / float(cuantos), efi / float(cuantos)])
		print("%-6d %-11s %5d %7.0f %7.1f %6.0f %6.0f %7d  %d" % [
			sim.day, est, sim.people.size(), sim.store.food_rations(),
			sim.store.food_rations() / maxf(comen, 0.01),
			hambre / n, cansa / n, heridos, sim.techs.known.size()])

	# Lo que decide la calibracion: raciones por PERSONA Y DIA de cada oficio,
	# contra las 2,0 que come una persona. Un oficio que no llega a 2 no se
	# mantiene a si mismo; uno que pasa de 6 hace irrelevantes a los demas.
	print("")
	print("--- POR QUE CADA CUAL HACE LO QUE HACE ---")
	print("   tajos montados:")
	for act: int in sim.work_sites:
		print("      %-16s a %5.0f m del abrigo" % [
			Subsistence.activity_name(act as Subsistence.Activity),
			sim.home_position.distance_to(sim.work_sites[act])])
	for act: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		if not sim.work_sites.has(act):
			print("      %-16s SIN TAJO" % Subsistence.activity_name(
				act as Subsistence.Activity))
	print("   por que se bloquea cada tarea (para el primero que pueda):")
	for job: int in Profession.Job.values():
		if job == Profession.Job.OCIOSO:
			continue
		for tarea: int in Profession.tasks_of(job as Profession.Job):
			for quien: Inhabitant in sim.people:
				if not Profession.can_do(job as Profession.Job, quien):
					continue
				var motivo: String = sim.task_blocked_by(quien, tarea)
				print("      %-26s %s" % [
					Profession.task_name(tarea),
					motivo if not motivo.is_empty() else "se puede"])
				break

	print("")
	print("--- LO QUE RINDE CADA OFICIO ---")
	var jornadas: Dictionary = {}
	for p2: Inhabitant in sim.people:
		var j := Profession.job_name(p2.job as Profession.Job)
		jornadas[j] = int(jornadas.get(j, 0)) + 1
	var come := 0.0
	for p2: Inhabitant in sim.people:
		come += p2.daily_food()
	come /= maxf(float(sim.people.size()), 1.0)
	print("   una persona come %.2f raciones al dia" % come)
	var por_actividad: Dictionary = {}
	for a_day: Dictionary in sim.taller.produced_days:
		for k: int in a_day:
			# Las claves negativas son piezas de utillaje, no materiales: la
			# produccion lleva las dos en el mismo registro. Ver `logged_name`.
			if k < 0:
				continue
			var kk := k as Materia.Kind
			if not Materia.is_food(kk):
				continue
			var act := "otros"
			if kk in [Materia.Kind.CARNE, Materia.Kind.CARNE_SECA]:
				act = "Caza"
			elif kk in [Materia.Kind.PESCADO, Materia.Kind.PESCADO_SECO,
					Materia.Kind.MARISCO]:
				act = "Ribera"
			else:
				act = "Recolección"
			por_actividad[act] = float(por_actividad.get(act, 0.0)) 				+ float(a_day[k]) * Materia.nutrition(kk)
	var dias_corridos := maxf(float(sim.day - primero), 1.0)
	for oficio: String in ["Recolección", "Caza", "Ribera"]:
		var gente: int = int(jornadas.get(oficio, 0))
		var rac: float = float(por_actividad.get(oficio, 0.0))
		print("   %-14s %2d personas · %7.0f raciones · %6.2f por persona y dia" % [
			oficio, gente, rac, rac / maxf(float(gente) * dias_corridos, 1.0)])

	print("")
	print("--- QUE HAY EN LA DESPENSA AL FINAL ---")
	var raciones: Array = []
	for k: int in Materia.Kind.values():
		var kk := k as Materia.Kind
		if not Materia.is_food(kk):
			continue
		var u: float = sim.store.amount(kk)
		if u <= 0.5:
			continue
		raciones.append([u * Materia.nutrition(kk), u, kk])
	raciones.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for fila: Array in raciones:
		print("   %-16s %8.0f raciones (%.0f %s · aguanta %d dias)" % [
			Materia.material_name(fila[2]), fila[0], fila[1],
			Materia.unit_name(fila[2]), Materia.shelf_life(fila[2])])

	print("")
	print("--- lo que ha entrado en el año, por material ---")
	var total: Dictionary = {}
	for a_day: Dictionary in sim.taller.produced_days:
		for k: int in a_day:
			total[k] = float(total.get(k, 0.0)) + float(a_day[k])
	var orden: Array[int] = []
	orden.assign(total.keys())
	orden.sort_custom(func(a: int, b: int) -> bool: return total[a] > total[b])
	for k: int in orden:
		if k < 0:
			continue
		var nombre := Materia.material_name(k as Materia.Kind)
		var rac := ""
		if Materia.is_food(k as Materia.Kind):
			rac = " = %.0f raciones" % (float(total[k]) * Materia.nutrition(k as Materia.Kind))
		print("   %-16s %8.1f %s%s" % [nombre, total[k],
			Materia.unit_name(k as Materia.Kind), rac])

	print("")
	print("se ha podrido en el año: %.1f raciones · por estacion %s" % [
		pudrido, str(por_estacion)])
	print("tecnicas sabidas al final: %d de %d" % [
		sim.techs.known.size(), TechTree.Tech.size()])
	var utillaje := 0
	for entrada: Dictionary in sim.toolkit.summary():
		utillaje += int(entrada.get("count", 0))
	print("piezas de utillaje: %d" % utillaje)
	print("atascos: %s" % str(sim.stuck_tally))
	print("cronica: %d entradas" % sim.chronicle.entries.size())
	quit()
