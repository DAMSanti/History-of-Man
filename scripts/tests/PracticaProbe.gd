extends SceneTree
## Quién cuenta como práctica, jornada a jornada y oficio a oficio.
##
## Sale de la queja del 2026-09-13 (EPOCA_01 §10.1, tanda 3, fallo 1): en dos
## años de partida, con material de sobra, las técnicas de ribera, manufactura y
## hogar se quedan en 0 %. Las jornadas de práctica las suma `DemoMain` al
## cerrar la jornada, contando a quien tiene oficio Y `has_task`. Esto mira ESE
## instante —se engancha a la misma señal, `day_passed`— y apunta, por oficio,
## cuántos lo tienen, cuántos cuentan, las jornadas que lleva el árbol y qué
## frena a la primera técnica de cada rama.
##
## No es un año: la pregunta es si una jornada de ribera, de taller o de hogar
## suma o no, y eso se ve en unas pocas. Ver ARQUITECTURA §5.1.
##
##   DIAS=12      cuántas jornadas seguir
##   REPARTO=...  ribera,manufactura,hogar,exploracion (por defecto 3,2,2,1)

const SITE_ID := 56

const OFICIOS := [Profession.Job.RIBERA, Profession.Job.MANUFACTURA,
	Profession.Job.HOGAR, Profession.Job.EXPLORACION, Profession.Job.CAZA,
	Profession.Job.RECOLECCION]

## La primera técnica de cada rama que no pide otra técnica antes, o la que
## sigue a la que ya se tiene de salida.
const MIRAR := [TechTree.Tech.PESQUERA, TechTree.Tech.NUCLEO, TechTree.Tech.ARTE,
	TechTree.Tech.PASARELA, TechTree.Tech.LAZO]


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
	var sim: SettlementSim = demo.sim if "sim" in demo else null
	var ui: GameUI = demo.ui if "ui" in demo else null
	if sim == null or ui == null or sim.techs == null:
		print("sin simulacion, interfaz o arbol"); quit(); return

	var reparto := [3, 2, 2, 1]
	# REPARTO=defecto deja el reparto con el que arranca la partida, sin tocar
	# prioridades. Es el que tiene exploradores de verdad batiendo: forzarlos a
	# mano el primer día no funciona, el reparto rechaza la batida.
	var por_defecto := OS.get_environment("REPARTO") == "defecto"
	if not por_defecto and not OS.get_environment("REPARTO").is_empty():
		reparto.clear()
		for trozo in OS.get_environment("REPARTO").split(","):
			reparto.append(int(trozo))
	sim.assign_default_jobs()
	if por_defecto:
		reparto = [0, 0, 0, 0]
	# LAS PRIORIDADES A MANO, que es lo que hace el jugador en «Trabajos».
	# `set_job_count` sólo coge a quien está LIBRE —ver [Reparto.set_job_count]—
	# y con el reparto por defecto no queda nadie libre: la primera pasada pidió
	# tres en ribera y uno en exploración y se quedaron en cero, que no es que
	# el trabajo no cuente sino que no había quien trabajara.
	# Por OFICIO, con todas sus tareas a 1 y sólo a quien puede hacerlo, como
	# hace `AtascoProbe`: poniendo una sola especialidad a los primeros de la
	# lista, la exploración se quedaba sin nadie —el reparto rechaza la batida
	# a quien no tiene edad o destino—.
	var pendiente := {
		Profession.Job.RIBERA: reparto[0],
		Profession.Job.MANUFACTURA: reparto[1],
		Profession.Job.HOGAR: reparto[2],
		Profession.Job.EXPLORACION: reparto[3],
	}
	if not por_defecto:
		for person: Inhabitant in sim.people:
			for task: int in person.priorities.keys():
				person.set_priority(task, 0)
		for job: int in pendiente:
			for person: Inhabitant in sim.people:
				if int(pendiente[job]) <= 0:
					break
				if person.priorities.size() > 0:
					continue
				if not Profession.can_do(job as Profession.Job, person):
					continue
				for task: int in Profession.tasks_of(job as Profession.Job):
					person.set_priority(task, 1)
				pendiente[job] = int(pendiente[job]) - 1
		for person: Inhabitant in sim.people:
			if person.priorities.is_empty():
				person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
					Profession.Speciality.FORRAJEO), 1)
	sim.apply_priorities()
	sim.time_scale = 5.0

	var dias := 12
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	# En el MISMO instante en que `DemoMain` cuenta: la señal de cierre de
	# jornada. Un Array y no enteros sueltos: la lambda captura por valor.
	var lineas: Array[String] = []
	var techs: TechTree = sim.techs
	var al_cerrar := func(dia: int) -> void:
		var partes: Array[String] = []
		for job: int in OFICIOS:
			var tienen := 0
			var cuentan := 0
			for person: Inhabitant in sim.people:
				if person.job != job:
					continue
				tienen += 1
				if person.can_work() and person.has_task:
					cuentan += 1
			partes.append("%s %d/%d (%.0f)" % [
				Profession.job_name(job as Profession.Job).substr(0, 5),
				cuentan, tienen, techs.days_in(job as Profession.Job)])
		lineas.append("dia %-3d %-9s | %s" % [dia,
			Subsistence.season_name(GameState.season), " · ".join(partes)])
	sim.day_passed.connect(al_cerrar)

	var primero := sim.day
	while sim.day < primero + dias:
		await process_frame
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)

	print("")
	print("=== LA PRACTICA, %d jornadas (oficio: cuentan/tienen (jornadas en el arbol)) ===" % dias)
	print("    ojo: `DemoMain` suma DESPUES de esta linea, asi que las jornadas son las de ANTES de ese cierre")
	for l in lineas:
		print(l)
	print("")
	print("=== LA PRIMERA DE CADA RAMA ===")
	for t: int in MIRAR:
		var tech := t as TechTree.Tech
		print("%-22s al alcance %s · progreso %.2f · pagado %.2f · causa: %s" % [
			TechTree.tech_name(tech), str(techs.is_available(tech)),
			techs.progress(tech), techs.fraccion_pagada(tech), techs.causa(tech)])
	print("piedra %.0f · fibra %.0f · lena %.0f · ocre %.0f · grasa %.0f" % [
		sim.store.amount(Materia.Kind.PIEDRA), sim.store.amount(Materia.Kind.FIBRA),
		sim.store.amount(Materia.Kind.LENA), sim.store.amount(Materia.Kind.OCRE),
		sim.store.amount(Materia.Kind.GRASA)])
	print("")
	print("=== LAS ESPECIALIDADES AL ACABAR ===")
	for person: Inhabitant in sim.people:
		print("  %-10s %-12s esp %-12s tajo %s · estado %s" % [person.given_name,
			Profession.job_name(person.job as Profession.Job),
			Profession.Speciality.keys()[person.current_speciality],
			str(person.has_task), Inhabitant.State.keys()[person.state]])
	quit()
