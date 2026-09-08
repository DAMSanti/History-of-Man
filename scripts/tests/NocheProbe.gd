extends SceneTree
## Como acaba el dia de verdad, antes de tocar nada.
##
## Cuatro preguntas, y las cuatro se contestan contando y no mirando:
##
##   - A las nueve de la noche, ¿quien sigue por el monte? Recogerse deberia
##     ser recogerse: a esa hora no hay nadie andando.
##   - ¿Se vuelve PARA el anochecer, o se EMPIEZA a volver a esa hora? No es lo
##     mismo: quien esta a dos kilometros y arranca a las siete llega de noche.
##   - Quien vuelve, ¿deja lo cogido en el almacen nada mas llegar, o se lo
##     queda encima?
##   - ¿Quien pasa la jornada lejos del agua, y con que odre?
##
##   DIAS=6      cuantas jornadas seguir

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

	var days := 6
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))
	sim.time_scale = 20.0

	var by_hour: Dictionary = {}     # hora -> [fuera de casa, andando, trabajando]
	var carried_home := 0            # llegadas con algo encima
	var carried_kg := 0.0
	var dry_days := 0                # jornadas enteras lejos del agua
	var dry_with_skin := 0
	var last_hour: float = sim.hour
	var thirsty_trips := 0
	var out_at_night: Dictionary = {}
	var nights := 0
	var counted_night := -1
	var peak_odre := 0
	var peak_cesto := 0
	var was_dry: Dictionary = {}
	var away_hours: Dictionary = {}  # persona -> horas seguidas sin agua al lado

	var first_day: int = sim.day
	while sim.day < first_day + days:
		await process_frame
		var step: float = sim.hour - last_hour
		if step < 0.0:
			step += 24.0
		last_hour = sim.hour
		var slot := int(sim.hour)
		var row: Array = by_hour.get(slot, [0, 0, 0, 0])
		row[3] = int(row[3]) + 1
		for person: Inhabitant in sim.people:
			if not sim._at_shelter(person):
				row[0] = int(row[0]) + 1
			if person.state == Inhabitant.State.YENDO \
					or person.state == Inhabitant.State.VOLVIENDO:
				row[1] = int(row[1]) + 1
			if person.state == Inhabitant.State.TRABAJANDO \
					or person.state == Inhabitant.State.BUSCANDO:
				row[2] = int(row[2]) + 1

			# Lo que se trae puesto al llegar: si al pisar el abrigo sigue
			# teniendo cosas encima, es que no se ha entregado nada aun.
			if sim._at_shelter(person) and not person.load.is_empty():
				carried_home += 1
				carried_kg += person.load_kg()

			# Los que se quedan secos y tienen que ir a beber.
			var dry := person.water_left <= 0.0
			if dry and not bool(was_dry.get(person.id, false)):
				thirsty_trips += 1
			was_dry[person.id] = dry

			# Horas de TRABAJO seguidas lejos del agua. Dormir fuera no cuenta:
			# de noche no se suda ni se bebe, y contarlo mezclaba al explorador
			# que acampa con el recolector que se pasa el dia en un canchal
			# seco, que es lo unico que se venia a mirar.
			var working := person.state == Inhabitant.State.TRABAJANDO 				or person.state == Inhabitant.State.BUSCANDO 				or person.state == Inhabitant.State.YENDO
			if sim.tajo._water_beside(person.position) or sim._at_shelter(person):
				if float(away_hours.get(person.id, 0.0)) >= SettlementSim.HORAS_UTILES:
					dry_days += 1
					if person.has_waterskin:
						dry_with_skin += 1
				away_hours[person.id] = 0.0
			elif working:
				away_hours[person.id] = float(away_hours.get(person.id, 0.0)) + step
		by_hour[slot] = row
		# Una foto por noche, a las dos de la madrugada: quien no esta en casa.
		if slot == 2 and counted_night != sim.day:
			counted_night = sim.day
			nights += 1
			for person: Inhabitant in sim.people:
				if sim._at_shelter(person):
					continue
				var who := Profession.job_name(person.job as Profession.Job)
				out_at_night[who] = int(out_at_night.get(who, 0)) + 1
		# Los recipientes se devuelven al abrigo al entregar, asi que contarlos
		# de noche da cero siempre: hay que mirarlos con la gente en el tajo.
		var odres := 0
		var cestos := 0
		for person: Inhabitant in sim.people:
			if person.has_waterskin:
				odres += 1
			if person.has_basket:
				cestos += 1
		peak_odre = maxi(peak_odre, odres)
		peak_cesto = maxi(peak_cesto, cestos)

	print("")
	print("=== EL DIA, HORA A HORA (media de %d jornadas, %d personas) ===" % [
		days, sim.people.size()])
	print("      fuera del abrigo · andando · trabajando")
	for slot in range(24):
		if not by_hour.has(slot):
			continue
		var row: Array = by_hour[slot]
		var ticks := maxf(float(row[3]), 1.0)
		print("%02dh   %5.1f            %5.1f     %5.1f%s" % [slot,
			float(row[0]) / ticks, float(row[1]) / ticks, float(row[2]) / ticks,
			"   <-- a dormir" if slot == int(SettlementSim.HORA_DORMIR) else ""])

	print("")
	print("jornadas ENTERAS (%.0f h) de trabajo lejos del agua: %d (con odre: %d)" % [
		SettlementSim.HORAS_UTILES, dry_days, dry_with_skin])
	print("momentos en el abrigo con la carga todavia encima: %d (%.1f kg de media)" % [
		carried_home, carried_kg / maxf(float(carried_home), 1.0)])
	print("odres tallados: %d · cestos: %d" % [
		sim.toolkit.count(Tool.Kind.ODRE), sim.toolkit.count(Tool.Kind.CESTO)])
	print("a la vez en el tajo, con odre: %d · con cesto: %d (de %d)" % [
		peak_odre, peak_cesto, sim.people.size()])
	print("viajes a por agua a media jornada: %d" % thirsty_trips)
	# Quien se queda a dormir fuera. El explorador lo hace a proposito -acampa
	# y sigue-; el resto es que ha calculado mal la vuelta, y eso es lo que
	# mide si el margen de regreso llega o no llega.
	print("")
	print("durmiendo fuera del abrigo, por oficio:")
	var order: Array = out_at_night.keys()
	order.sort_custom(func(a: String, b: String) -> bool:
		return int(out_at_night[a]) > int(out_at_night[b]))
	for who: String in order:
		print("  %5.2f personas de media  %s" % [
			float(out_at_night[who]) / maxf(float(nights), 1.0), who])
	quit()
