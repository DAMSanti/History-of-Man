extends SceneTree
## Qué le pasa a una expedición según lleve o no con qué dormir.
##
## El criterio del bloque es que una partida mal avituallada corra un riesgo
## real y MEDIBLE, y que llevar lo necesario lo evite. Eso no se comprueba con
## una aserción: hace falta jugar las dos partidas y comparar el recuento.
##
## Se cuentan las noches fuera, cuántas se pasaron sin tienda o sin hoguera, y
## los percances que salieron en la crónica.
##
##   DIAS=30      cuántas jornadas seguir
##   DETALLE=1    saca el reparto de oficios y el parte diario de cada explorador
##   SIN_VIVAC=1  vacía piel y leña del almacén cada fotograma, para forzar el
##                caso de la partida mal avituallada

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
	for i in range(240):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("sin simulacion"); quit(); return

	# Una banda volcada en explorar, que es la que pernocta fuera.
	# Se ponen PRIORIDADES, que es lo que hace el jugador, y no
	# `set_job_count`: ése vuelve a resolver el reparto entero cada vez y el
	# cierre del día lo repite, así que cualquier asignación a mano dura una
	# jornada. Y en EXPEDICIÓN, no en batida: la batida vuelve a dormir a casa
	# todas las noches, así que no pernocta y no es de lo que va esto.
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION)
	var sent := 0
	for person: Inhabitant in sim.people:
		if sent >= 4 or not Profession.can_do(Profession.Job.EXPLORACION, person):
			continue
		for job: int in Profession.Job.values():
			for other: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(other, 0)
		person.set_priority(task, 3)
		person.speciality = Profession.Speciality.EXPEDICION
		sent += 1
	sim.apply_priorities()

	sim.time_scale = 30.0

	if not OS.get_environment("DETALLE").is_empty():
		for person: Inhabitant in sim.people:
			print("   %-6s %-12s %s" % [person.given_name,
				Profession.job_name(person.job as Profession.Job),
				Profession.speciality_name(
					person.current_speciality as Profession.Speciality)])

	var bare := not OS.get_environment("SIN_VIVAC").is_empty()
	var days := 30
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	# El almacén arranca con algo de piel y leña: sin nada de nada, la primera
	# expedición saldría desnuda por falta de existencias y no por decisión.
	if not bare:
		sim.store.add(Materia.Kind.PIEL, 60.0)
		sim.store.add(Materia.Kind.LENA, 120.0)

	var first_day: int = sim.day
	var last_day: int = sim.day
	var nights := 0
	var rough := 0
	var lacks := 0
	var seen: int = sim.chronicle.entries.size()
	var mishaps := 0
	var carried_piel := 0.0
	var carried_lena := 0.0
	var samples := 0

	while sim.day < first_day + days:
		await process_frame
		if bare:
			sim.store.take(Materia.Kind.PIEL, sim.store.amount(Materia.Kind.PIEL))
			sim.store.take(Materia.Kind.LENA, sim.store.amount(Materia.Kind.LENA))
		if sim.day == last_day:
			continue
		last_day = sim.day

		for person: Inhabitant in sim.people:
			if person.bivouac_day != sim.day:
				continue
			nights += 1
			if person.bivouac_lack > 0:
				rough += 1
				lacks += person.bivouac_lack
			carried_piel += float(person.load.get(Materia.Kind.PIEL, 0.0))
			carried_lena += float(person.load.get(Materia.Kind.LENA, 0.0))
			samples += 1

		if not OS.get_environment("DETALLE").is_empty():
			for person: Inhabitant in sim.people:
				if person.job != Profession.Job.EXPLORACION:
					continue
				print("   %-6s %-12s %-10s %6.0f m  fat %3.0f  rac %.1f" % [
					person.given_name,
					Profession.speciality_name(
						person.current_speciality as Profession.Speciality),
					person.state_name(),
					person.position.distance_to(sim.home_position),
					person.fatigue, sim.despensa.pack_rations(person)])

		var entries: Array = sim.chronicle.entries
		for i in range(seen, entries.size()):
			var text: String = entries[i]["text"]
			if text.contains("torció") or text.contains("al suelo") \
					or text.contains("perdió el rumbo") \
					or text.contains("media vuelta"):
				mishaps += 1
				print("  · %s" % text)
		seen = entries.size()

	print("")
	print("almacen %s" % ("VACIO de piel y lena" if bare else "con vivac"))
	print("noches fuera: %d · malas: %d (%.0f %%) · carencias: %d" % [
		nights, rough, 100.0 * float(rough) / maxf(float(nights), 1.0), lacks])
	print("lo que llevaban de media: %.2f piel · %.2f lena" % [
		carried_piel / maxf(float(samples), 1.0),
		carried_lena / maxf(float(samples), 1.0)])
	print("percances en la cronica: %d" % mishaps)
	if "bivouac_fires" in demo and demo.bivouac_fires != null:
		print("hogueras de vivac encendidas ahora: %d" % 
			demo.bivouac_fires.lit_count())
	quit()
