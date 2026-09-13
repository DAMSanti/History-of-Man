extends SceneTree
## Cuántas jornadas seguidas pasan sin ningún [Moment], por estación.
##
## Nace de docs/specs/QUE_FALTA_PARA_JUGARLO.md, punto 3: 45 días por
## estación es mucho reloj si no hay nada que decidir. Esto mide el hueco
## real con el reparto por defecto -es instrumentación, no construye ninguna
## decisión nueva- para saber si el hueco existe antes de llenarlo.
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
	var ui: GameUI = demo.ui if "ui" in demo else null
	if sim == null or ui == null:
		print("sin simulacion o interfaz"); quit(); return

	sim.assign_default_jobs()
	# x5, no x20: tope acordado entre las sondas tras los cambios de
	# rendimiento de hoy. Ver docs/specs/LO_MISMO_MAS_DEPRISA.md.
	sim.time_scale = 5.0

	# Cuenta cada momento que cae HOY -no sólo los de decisión, como hace
	# AnoProbe-: lo que se mide aquí es si hubo algo que mirar, no sólo algo
	# que decidir.
	var hubo_momento_hoy := false
	var total_momentos := 0
	sim.moment_raised.connect(func(m: Moment) -> void:
		hubo_momento_hoy = true
		total_momentos += 1)

	# Las decisiones se resuelven por `BarraSuperior.elegir()`, viendo qué hay
	# de verdad en pantalla -no llamando a `on_pick` a pelo desde
	# `moment_raised`, que ejecuta la elección pero nunca hace avanzar la cola
	# ni devuelve `time_scale`: por eso se quedaba colgada con el reloj a
	# cero para siempre en cuanto tocaba la primera decisión del año. Ver el
	# mismo arreglo en `AnoProbe.gd`.
	var _resolver_decisiones := func() -> void:
		# La opción 0 es siempre la que no compromete (SPECS §4.6), y los avisos
		# se cierran: ver [BarraSuperior.contestar_todo].
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)

	var dias := 180
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	var racha := 0
	# estacion -> {"maxima": int, "tramos": Array[int]} -para ver no solo el
	# peor hueco, sino si hay varios largos seguidos.
	var por_estacion: Dictionary = {}
	var estacion_anterior: int = GameState.season

	var primero: int = sim.day
	var ultimo: int = -1
	while sim.day < primero + dias:
		await process_frame
		_resolver_decisiones.call()
		if sim.day == ultimo:
			continue

		if ultimo >= 0:
			var est_nombre := Subsistence.season_name(estacion_anterior as Subsistence.Season)
			if not por_estacion.has(est_nombre):
				por_estacion[est_nombre] = {"maxima": 0, "tramos": []}
			var entrada: Dictionary = por_estacion[est_nombre]

			if GameState.season != estacion_anterior:
				# Cambio de estación: el hueco en curso se cierra aquí, no
				# se le presta a la estación siguiente.
				if racha > 0:
					(entrada["tramos"] as Array).append(racha)
					entrada["maxima"] = maxi(int(entrada["maxima"]), racha)
				racha = 0
				estacion_anterior = GameState.season
			else:
				if hubo_momento_hoy:
					if racha > 0:
						(entrada["tramos"] as Array).append(racha)
						entrada["maxima"] = maxi(int(entrada["maxima"]), racha)
					racha = 0
				else:
					racha += 1

		hubo_momento_hoy = false
		ultimo = sim.day

	# El ultimo tramo abierto tambien cuenta.
	if racha > 0:
		var est_nombre := Subsistence.season_name(estacion_anterior as Subsistence.Season)
		if not por_estacion.has(est_nombre):
			por_estacion[est_nombre] = {"maxima": 0, "tramos": []}
		var entrada: Dictionary = por_estacion[est_nombre]
		(entrada["tramos"] as Array).append(racha)
		entrada["maxima"] = maxi(int(entrada["maxima"]), racha)

	print("")
	print("=== RITMO: jornadas seguidas sin ningun momento (%d jornadas, %d momentos en total) ===" \
		% [dias, total_momentos])
	print("%-11s %8s   %s" % ["estacion", "peor hueco", "todos los tramos (jornadas)"])
	for est_nombre: String in por_estacion:
		var entrada: Dictionary = por_estacion[est_nombre]
		print("%-11s %8d   %s" % [est_nombre, int(entrada["maxima"]), str(entrada["tramos"])])
	quit()
