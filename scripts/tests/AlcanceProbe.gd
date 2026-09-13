extends SceneTree
## Por qué un paraje cercano sale «inalcanzable», uno a uno.
##
## Queja del usuario (EPOCA_01 §10.1, tabla de dependencias de la tanda 3):
## «en verano, el raizal del paso sale inalcanzable a 226 m». El juego tiene
## tres motivos para decirlo —`Marcha.por_que_no_se_llega`—: el río crecido,
## que no haya paso, o que sólo se llegue dando una vuelta que no compensa. Esto
## pone la estación que se pida, espera a que su rejilla esté hecha, y lista
## cada paraje cerca del abrigo con la recta, lo que se anda y el motivo.
##
## No simula jornadas: la pregunta es de la rejilla de una estación, no de lo
## que pase en ella.
##
##   ESTACION=verano   primavera|verano|otono|invierno
##   CERCA=500         hasta cuántos metros en recta

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
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
	for i in range(120):
		await process_frame
	var demo := current_scene
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0

	var nombre := OS.get_environment("ESTACION")
	if nombre.is_empty():
		nombre = "verano"
	var estaciones := {"primavera": Subsistence.Season.PRIMAVERA,
		"verano": Subsistence.Season.VERANO, "otono": Subsistence.Season.OTONO,
		"invierno": Subsistence.Season.INVIERNO}
	GameState.season = estaciones.get(nombre, Subsistence.Season.VERANO)
	var cerca := 500.0
	if not OS.get_environment("CERCA").is_empty():
		cerca = float(OS.get_environment("CERCA"))

	# La rejilla de esa estación, hecha. El horno las amasa a trozos.
	var espera := 0
	while espera < 6000:
		var grid: Navgrid = sim.marcha._navgrid()
		if grid != null and grid.is_ready():
			break
		await process_frame
		espera += 1
	print("rejilla de %s lista tras %d cuadros" % [nombre, espera])

	var filas: Array = []
	for paraje: Paraje in sim.parajes.list:
		var recta := Traversal.en_llano(sim.home_position, paraje.position)
		if recta > cerca:
			continue
		var llega := sim.marcha.alcanzable_desde_casa(paraje.position)
		var motivo := sim.marcha.por_que_no_se_llega(paraje.position)
		filas.append([recta, paraje.name_text, llega, motivo,
			Subsistence.activity_name(paraje.activity)])
	filas.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	print("")
	print("=== PARAJES A MENOS DE %.0f m, en %s ===" % [cerca, nombre])
	var no := 0
	for f: Array in filas:
		if not bool(f[2]):
			no += 1
		print("  %4.0f m  %-34s %-12s %s %s" % [float(f[0]), String(f[1]), String(f[4]),
			"llega" if bool(f[2]) else "NO LLEGA",
			"" if String(f[3]).is_empty() else "· " + String(f[3])])
	print("")
	print("%d de %d no se alcanzan" % [no, filas.size()])
	quit()
