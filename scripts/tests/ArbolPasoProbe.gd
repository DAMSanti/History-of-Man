extends SceneTree
## Por que se para el arbol de tecnicas, tecnica por tecnica y jornada a jornada.
##
## La queja del jugador es «hay varias que no se desbloquean y no se ve por
## que», y las causas posibles son tres -prerrequisito, jornadas o material-
## que desde fuera se ven iguales. Esto las separa: para cada tecnica al
## alcance apunta CUAL de las dos fracciones de `TechTree.progress` va por
## detras, y cuantas jornadas lleva parada por cada motivo.
##
## No mide balanceo: mide que puerta esta cerrada. Por eso le basta con unas
## semanas -la tasa de jornadas por oficio y la entrada de piedra se
## estabilizan enseguida- y con ellas se extrapola cuando llegaria cada
## tecnica, en vez de correr el año entero para verlo. Ver CLAUDE.md, «mide
## barato».
##
##   DIAS=60   cuantas jornadas seguir

const SITE_ID := 56

## Los materiales que deciden la azagaya, mas los que compiten por la piedra.
const MIRAR := [Materia.Kind.PIEDRA, Materia.Kind.SILEX, Materia.Kind.ASTA,
	Materia.Kind.TENDON, Materia.Kind.LENA, Materia.Kind.FIBRA,
	Materia.Kind.RESINA, Materia.Kind.HUESO]


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
	var ui: GameUI = demo.ui if "ui" in demo else null
	if sim == null or ui == null:
		print("sin simulacion o interfaz"); quit(); return

	sim.assign_default_jobs()
	# Cuanta gente en el taller. El reparto por defecto deja menos de uno, y
	# la cifra que hay que fijar -las jornadas de la talla laminar- depende de
	# a que ritmo se practica de verdad la manufactura con uno o con dos, que
	# es el caso que ESTADO.md §2 nombra. Ver `docs/ESTADO.md`.
	if not OS.get_environment("MANU").is_empty():
		sim.set_job_count(Profession.Job.MANUFACTURA, int(OS.get_environment("MANU")))
	sim.time_scale = 5.0

	# Sin jugador delante, la primera decision deja el reloj a cero para
	# siempre. Mismo apaño que en `AnoProbe`, y por el mismo motivo.
	var resolver := func() -> void:
		# La opción 0 es siempre la que no compromete (SPECS §4.6), y los avisos
		# se cierran: ver [BarraSuperior.contestar_todo].
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)

	var dias := 60
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	var techs: TechTree = sim.techs
	if techs == null:
		print("sin arbol"); quit(); return

	# Jornadas que cada tecnica pasa parada por CADA motivo. Es el dato que
	# hace falta: una tecnica que no sube porque nadie practica su oficio y
	# otra que no sube porque falta asta piden arreglos distintos.
	var por_material: Dictionary = {}
	var por_jornadas: Dictionary = {}
	var primero: int = sim.day
	var ultimo := -1

	print("")
	print("dia   estacion   almacen y jornadas por oficio")

	while sim.day < primero + dias:
		await process_frame
		resolver.call()
		if sim.day == ultimo:
			continue
		ultimo = sim.day

		for tech: int in TechTree.CATALOGUE:
			var t := tech as TechTree.Tech
			if techs.has(t) or not techs.is_available(t):
				continue
			var needed := float((TechTree.CATALOGUE[t] as Dictionary)["days"])
			var job := TechTree.job_of(t)
			if needed <= 0.0 or job < 0:
				continue
			var por_dias := clampf(
				techs.days_in(job as Profession.Job) / needed, 0.0, 1.0)
			# Lo que MANDA: la fraccion que va por detras es la que frena.
			if techs.fraccion_pagada(t) < por_dias - 0.001:
				por_material[tech] = int(por_material.get(tech, 0)) + 1
			else:
				por_jornadas[tech] = int(por_jornadas.get(tech, 0)) + 1

		if (sim.day - primero) % 10 != 0:
			continue
		var oficios: Array[String] = []
		for job: int in Profession.Job.values():
			var d := techs.days_in(job as Profession.Job)
			if d > 0.0:
				oficios.append("%s %.0f" % [
					Profession.job_name(job as Profession.Job).substr(0, 4), d])
		print("%-5d %-10s piedra %.0f asta %.0f tendon %.0f | %s" % [sim.day,
			Subsistence.season_name(GameState.season),
			sim.store.amount(Materia.Kind.PIEDRA),
			sim.store.amount(Materia.Kind.ASTA),
			sim.store.amount(Materia.Kind.TENDON),
			", ".join(oficios)])

	var corridos := maxi(sim.day - primero, 1)
	print("")
	print("=== %d jornadas ===" % corridos)

	print("")
	print("almacen:")
	for kind: int in MIRAR:
		print("  %-12s %7.1f" % [
			Materia.material_name(kind as Materia.Kind),
			sim.store.amount(kind as Materia.Kind)])

	print("")
	print("utillaje: azagaya %d, punta %d, buril %d, lasca %d" % [
		sim.toolkit.count(Tool.Kind.AZAGAYA), sim.toolkit.count(Tool.Kind.PUNTA),
		sim.toolkit.count(Tool.Kind.BURIL), sim.toolkit.count(Tool.Kind.LASCA)])

	print("")
	print("jornadas por oficio, y a cuantas por jornada simulada:")
	for job: int in Profession.Job.values():
		var d := techs.days_in(job as Profession.Job)
		if d <= 0.0:
			continue
		print("  %-14s %7.0f  (%.2f/dia)" % [
			Profession.job_name(job as Profession.Job), d, d / float(corridos)])

	print("")
	print("%-22s %-12s %6s %6s %6s %6s %6s  %s" % ["tecnica", "oficio",
		"jorn%", "mat%", "prog%", "parMat", "parJor", "falta"])
	for tech: int in TechTree.CATALOGUE:
		var t := tech as TechTree.Tech
		var nombre := TechTree.tech_name(t)
		if techs.has(t):
			print("%-22s DOMINADA" % nombre)
			continue
		if not techs.is_available(t):
			var razon := "pide obra" if TechTree.needs_camp(t) >= 0 else "?"
			for need: int in ((TechTree.CATALOGUE[t] as Dictionary)["needs"] as Array):
				if not techs.has(need as TechTree.Tech):
					razon = "tras %s" % TechTree.tech_name(need as TechTree.Tech)
			print("%-22s %s" % [nombre, razon])
			continue
		var needed := float((TechTree.CATALOGUE[t] as Dictionary)["days"])
		var job := TechTree.job_of(t)
		var por_dias := 1.0
		if needed > 0.0 and job >= 0:
			por_dias = clampf(techs.days_in(job as Profession.Job) / needed, 0.0, 1.0)
		print("%-22s %-12s %5.0f%% %5.0f%% %5.0f%% %6d %6d  %s" % [nombre,
			"-" if job < 0 else Profession.job_name(job as Profession.Job),
			100.0 * por_dias, 100.0 * techs.fraccion_pagada(t),
			100.0 * techs.progress(t),
			int(por_material.get(tech, 0)), int(por_jornadas.get(tech, 0)),
			", ".join(techs.missing_for(t))])

	# Y la pregunta que lo motiva todo: cuando llegaria la azagaya al ritmo de
	# estas semanas. Extrapolar la tasa es lo que evita correr el año entero.
	print("")
	var manu := techs.days_in(Profession.Job.MANUFACTURA) / float(corridos)
	var caza := techs.days_in(Profession.Job.CAZA) / float(corridos)
	print("al ritmo medido: manufactura %.2f jorn/dia, caza %.2f jorn/dia" % [manu, caza])
	if manu > 0.0:
		print("  nucleo+laminar (155 jorn. de manufactura) hacia el dia %.0f" % (155.0 / manu))
	else:
		print("  talla laminar: NUNCA, nadie practica manufactura")
	if caza > 0.0:
		print("  azagaya (140 jorn. de caza, y ademas tras la laminar) hacia el dia %.0f"
			% (140.0 / caza))
	else:
		print("  azagaya: NUNCA, nadie practica caza")

	# Y si el asta se puede siquiera buscar: la ficha de los parajes.
	var con_asta := 0
	for paraje: Paraje in sim.parajes.list:
		if paraje.contents.has(int(Materia.Kind.ASTA)):
			con_asta += 1
	print("")
	print("parajes bautizados: %d, y anuncian asta: %d"
		% [sim.parajes.list.size(), con_asta])
	quit()
