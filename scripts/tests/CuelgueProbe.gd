extends SceneTree
## El cuelgue de la hambruna total, REPRODUCIDO EN MINUTOS EN VEZ DE EN HORA Y MEDIA.
##
## El 🔴 se reproducia con `SEMILLA=42 DIAS=95 BANDA=4,3,2` sobre `AnoProbe`:
## noventa jornadas de reloj —tres cuartos de hora— para llegar al cruce
## verano→otono con la banda muerta de hambre. Aqui ese estado NO SE SIMULA, SE
## ESCRIBE: se pone la estacion a dos dias del cruce, el hambre al maximo y la
## despensa a cero, y se dan los pasos que faltan. Ver CLAUDE.md, «mide barato».
##
## Y lleva VIGIA: Godot no suelta la salida hasta salir, y un proceso colgado no
## sale —de ahi los «17 minutos sin escribir una linea de log» del parte—. El
## vigia escribe cada vuelta a un fichero con `flush()`, asi que se puede leer
## MIENTRAS esta colgado y decir en que se quedo.
##
##   SEMILLA=42       la del parte
##   DIAS=6           cuantas jornadas dar despues de construir el estado
##   VIGIA=ruta       donde escribir el parte (por defecto, user://cuelgue.txt)

const SITE_ID := 56

## A cuantos dias del cambio de estacion se deja la partida.
##
## Dos: los justos para que el cruce ocurra con la banda ya hambrienta y no
## antes de que el estado construido haga efecto. `Subsistence.DAYS_PER_SEASON`
## es 45, asi que verano acaba el dia 90 y otono empieza el 91.
const AL_FILO := 2

var _vigia: FileAccess = null


func _apunta(que: String) -> void:
	if _vigia == null:
		return
	_vigia.store_line("%d ms · %s" % [Time.get_ticks_msec(), que])
	_vigia.flush()


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var ruta := OS.get_environment("VIGIA")
	if ruta.is_empty():
		ruta = "user://cuelgue.txt"
	_vigia = FileAccess.open(ruta, FileAccess.WRITE)
	_apunta("arranca; parte en %s" % ProjectSettings.globalize_path(ruta))

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
	_apunta("montando la escena")
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(90):
		await process_frame
	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var ui: GameUI = demo.ui if "ui" in demo else null
	if sim == null or ui == null:
		print("sin simulacion o interfaz"); quit(); return
	_apunta("escena montada")

	_repartir(sim, [4, 3, 2])

	# --- EL ESTADO DEL PARTE, ESCRITO -------------------------------------
	#
	# Lo que el ultimo punto de control del 🔴 media el dia 76: despensa 0 y
	# hambre media de la banda 100, el maximo, con los quince todavia vivos.
	GameState.season = Subsistence.Season.VERANO
	sim.season_day = Subsistence.DAYS_PER_SEASON - AL_FILO
	sim.store.contents.clear()
	sim.store.ages.clear()
	for person: Inhabitant in sim.people:
		person.hunger = 100.0
		# Y AL FILO DE LA MUERTE, no recien hambrientos: `Relevo.revisar_hambre`
		# mata al adulto a los diez dias seguidos de hambre y al nino o al
		# anciano a los seis, asi que una banda que acaba de empezar a pasar
		# hambre no reproduce nada. Dejandolos a un dia del suyo, los quince
		# mueren en la misma jornada -las «muertes masivas simultaneas» del
		# parte- en vez de tener que simular diez dias para llegar.
		person.hunger_sick_days = sim.relevo._hunger_death_days(person) - 1
	_apunta("estado construido: verano dia %d de %d, despensa 0, hambre 100 x%d, al filo"
		% [sim.season_day, Subsistence.DAYS_PER_SEASON, sim.people.size()])

	sim.time_scale = 5.0

	# El mismo despachador que `AnoProbe`, y A PROPOSITO SIN ARREGLAR: si el
	# cuelgue esta aqui —solo se contestan las DECISIONES, y un momento que se
	# enseña sin opciones se queda en pantalla— esta sonda tiene que caer en el
	# mismo agujero. Arreglarlo aqui seria dejar de reproducir lo que se quiere
	# reproducir.
	var _resolver_decisiones := func() -> void:
		var actual := ui.barra.momento_en_pantalla()
		while actual != null and actual.is_decision():
			var index := 1 if actual.kind == Moment.Kind.BERREA else 0
			ui.barra.elegir(index)
			actual = ui.barra.momento_en_pantalla()

	var dias := 6
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	var primero: int = sim.day
	var ultimo: int = -1
	var vueltas := 0
	# Cuantas vueltas de fotograma se aguantan sin que avance la jornada antes
	# de declarar el cuelgue.
	#
	# Una jornada a x5 son unas 1 300 vueltas medidas en esta misma sonda, asi
	# que 4 000 es tres veces lo que tarda la mas lenta: si se pasa de ahi, el
	# dia no es que vaya despacio, es que NO VA. Esto es lo que convierte el
	# cuelgue en un resultado que se lee, en vez de un proceso que hay que
	# matar a mano a los diecisiete minutos.
	var TOPE_SIN_AVANZAR := 4000
	var sin_avanzar := 0
	while sim.day < primero + dias:
		# El arreglo, y lo que esta sonda comprueba que funciona: en cuanto la
		# partida termina se sale, en vez de esperar una jornada que no va a
		# llegar. Ver `SettlementSim.partida_terminada`.
		if sim.partida_terminada():
			_apunta(("PARA SOLA · la partida termino en la jornada %d · "
				+ "vivos %d · desenlace %d · %d vueltas")
				% [sim.day, sim.people.size(), sim.desenlace, vueltas])
			print("para sola: la partida termino en la jornada %d (desenlace %d)"
				% [sim.day, sim.desenlace])
			_vigia.close()
			quit()
			return
		await process_frame
		vueltas += 1
		sin_avanzar += 1
		_resolver_decisiones.call()
		if sin_avanzar > TOPE_SIN_AVANZAR:
			_apunta(("CUELGUE CONFIRMADO · %d vueltas sin que avance el dia %d"
				+ " · vivos %d · desenlace %d · reloj x%.1f")
				% [sin_avanzar, sim.day, sim.people.size(), sim.desenlace,
					sim.time_scale])
			print("CUELGUE: el dia %d no avanza; vivos %d, desenlace %d"
				% [sim.day, sim.people.size(), sim.desenlace])
			_vigia.close()
			quit()
			return
		# El vigia apunta CADA VUELTA de fotograma, no cada jornada: si el dia
		# deja de avanzar —que es la forma que tiene esto de colgarse— una traza
		# por jornada no volveria a escribir nunca y el parte se quedaria mudo
		# exactamente igual que el log.
		if vueltas % 200 == 0:
			var card := ui.barra.momento_en_pantalla()
			_apunta(("vuelta %d · dia %d · estacion %s · reloj x%.1f · "
				+ "en pantalla: %s · en cola: %d · vivos %d")
				% [vueltas, sim.day, Subsistence.season_name(GameState.season),
					sim.time_scale,
					"nada" if card == null else "%s (%s)" % [card.title,
						"decision" if card.is_decision() else "aviso"],
					ui._moments.size(), sim.people.size()])
		if sim.day == ultimo:
			continue
		ultimo = sim.day
		sin_avanzar = 0
		_apunta("JORNADA %d · %s · vivos %d · desenlace %d"
			% [sim.day, Subsistence.season_name(GameState.season),
				sim.people.size(), sim.desenlace])

	_apunta("TERMINA SOLA: llego al dia %d en %d vueltas" % [sim.day, vueltas])
	print("termina sola en el dia %d" % sim.day)
	_vigia.close()
	quit()


func _repartir(sim: Node, reparto: Array) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: reparto[0],
		Profession.Job.CAZA: reparto[1],
		Profession.Job.RIBERA: reparto[2],
	}
	for person: Inhabitant in sim.people:
		for job: int in Profession.Job.values():
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 0)
	for job: int in pendiente:
		for person: Inhabitant in sim.people:
			if pendiente[job] <= 0:
				break
			if person.priorities.size() > 0:
				continue
			if not Profession.can_do(job as Profession.Job, person):
				continue
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 1)
			pendiente[job] -= 1
