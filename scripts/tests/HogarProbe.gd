extends SceneTree
## Qué le pasa al fuego en una partida de verdad.
##
## Las pruebas de `TestCampProjects` comprueban las reglas una por una con una
## simulación de mentira; esto mira si la banda entera se apaña con ellas: si
## levanta el hogar lo primero, si la leña que entra da para mantenerlo, y si
## cuando se apaga se entera alguien.
##
## Se cuenta una línea por jornada y se recogen las entradas de crónica que
## hablen del fuego, que es exactamente lo que vería el jugador.
##
##   DIAS=40        cuántas jornadas seguir
##   VELOCIDAD=30   a qué velocidad correr la partida
##   SIN_LENA=12    a partir de qué jornada se vacía la leña del almacén, para
##                  ver de verdad lo que pasa cuando el fuego se queda sin qué
##                  quemar. Sin esto la banda trae más leña de la que gasta y el
##                  caso no llega a darse.

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

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()
	# La partida arranca en pausa. Se corre deprisa a propósito: lo que se mira
	# aquí son jornadas enteras, no el paso a paso.
	sim.time_scale = 30.0
	if not OS.get_environment("VELOCIDAD").is_empty():
		sim.time_scale = float(OS.get_environment("VELOCIDAD"))

	var days := 40
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	print("")
	print("%4s %-10s %-8s %7s %7s %s" % [
		"dia", "estacion", "hogar", "lena", "carne", "quien lo cuida"])

	var starve := 0
	if not OS.get_environment("SIN_LENA").is_empty():
		starve = int(OS.get_environment("SIN_LENA"))

	var first_day: int = sim.day
	var last_day: int = sim.day
	var seen := 0
	var lit_days := 0
	var out_days := 0
	while sim.day < first_day + days:
		await process_frame
		# Se vacía CADA FOTOGRAMA y no al cambiar de día: la banda trae leña
		# durante la jornada, así que vaciar sólo en el cambio de día deja el
		# almacén lleno otra vez antes de que el hogar tire de él.
		if starve > 0 and sim.day - first_day >= starve:
			sim.store.take(Materia.Kind.LENA,
				sim.store.amount(Materia.Kind.LENA))
		if sim.day == last_day:
			continue
		last_day = sim.day
		if sim.hearth_lit:
			lit_days += 1
		else:
			out_days += 1
		print("%4d %-10s %-8s %7.1f %7.1f %s" % [
			sim.day, Subsistence.season_name(GameState.season),
			"encendido" if sim.hearth_lit else "APAGADO",
			sim.store.amount(Materia.Kind.LENA),
			sim.store.amount(Materia.Kind.CARNE),
			_keepers(sim)])
		seen = _tell_fire(sim, seen)

	print("")
	print("jornadas con fuego: %d · sin fuego: %d" % [lit_days, out_days])
	print("hogar levantado: %s · secadero: %s" % [
		sim.camp_built.get(CampProjects.Kind.HOGAR, false),
		sim.camp_built.get(CampProjects.Kind.SECADERO, false)])
	quit()


## Quién está hoy en el hogar, y en qué.
func _keepers(sim: Node) -> String:
	var out: Array[String] = []
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.HOGAR:
			continue
		out.append("%s (%s)" % [person.given_name,
			Profession.speciality_name(
				person.current_speciality as Profession.Speciality)])
	return ", ".join(out) if not out.is_empty() else "NADIE"


## Saca las entradas nuevas de crónica que hablen del fuego.
func _tell_fire(sim: Node, seen: int) -> int:
	var entries: Array = sim.chronicle.entries
	for i in range(seen, entries.size()):
		var text: String = entries[i]["text"]
		if text.contains("hogar") or text.contains("fuego"):
			print("      · %s" % text)
	return entries.size()
