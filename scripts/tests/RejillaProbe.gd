extends SceneTree
## Cuánto miente la rejilla de navegación sobre el terreno de verdad.
##
## El planificador y el andador tienen que estar de acuerdo. Cuando la rejilla
## da por pisable un sitio que el terreno no deja pisar, el camino sale
## perfecto y la persona no lo puede seguir: se queda empujando una pared hasta
## que la vigilancia de atascos la manda a casa. Esa es la avería, y no se ve
## mirando: se ve contando.
##
## Se sortean puntos por todo el mapa y se comparan las dos autoridades:
##
##   - `Navgrid.passable`, que es lo que cree el planificador
##   - `Traversal.is_passable` sobre la pendiente y el vadeo REALES de ese
##     punto, que es lo que puede hacer una persona
##
## Lo grave es que la rejilla PROMETA DE MÁS —dice que sí y el terreno dice que
## no—, porque eso es exactamente lo que deja a alguien clavado. Lo contrario
## —la rejilla cierra un sitio que se podría andar— sólo cuesta un rodeo.

const SITE_ID := 56

## Cuántos puntos se sortean.
const SAMPLES := 40000


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
	var terrain: TerrainGenerator = demo.terrain if "terrain" in demo else null
	var sim: Node = demo.sim if "sim" in demo else null
	if terrain == null or sim == null:
		print("sin terreno o simulacion"); quit(); return

	var started := Time.get_ticks_usec()
	var grid := Navgrid.from_terrain(terrain, false, false)
	var build_ms := float(Time.get_ticks_usec() - started) / 1000.0

	print("")
	print("=== LA REJILLA ===")
	print("%d x %d celdas de %d m · construirla %.0f ms" % [
		grid.wide, grid.tall, int(Navgrid.CELL), build_ms])
	print("transitable %.1f %% · zonas comunicadas %d" % [
		grid.open_fraction() * 100.0, grid.areas])

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260907
	var promises := 0     # la rejilla dice que si y el terreno que no
	var refuses := 0      # la rejilla dice que no y el terreno que si
	var open_cells := 0
	var worst_slope := 0.0

	for i in range(SAMPLES):
		var point := Vector3(
			rng.randf() * float(terrain.terrain_size.x), 0.0,
			rng.randf() * float(terrain.terrain_size.y))
		point.y = terrain.get_height_at(point)
		var slope := terrain.get_slope_at(point)
		var ford := terrain.crossing_difficulty_at(point)
		var walkable := Traversal.is_passable(slope, ford, false, false)
		var planned := grid.passable(point)
		if planned:
			open_cells += 1
		if planned and not walkable:
			promises += 1
			worst_slope = maxf(worst_slope, slope)
		elif walkable and not planned:
			refuses += 1

	print("")
	print("de %d puntos sorteados:" % SAMPLES)
	print("  la rejilla los da por buenos: %d (%.1f %%)" % [
		open_cells, 100.0 * float(open_cells) / float(SAMPLES)])
	print("  PROMETE DE MAS -dice que si y no se pasa-: %d (%.2f %% del mapa," % [
		promises, 100.0 * float(promises) / float(SAMPLES)]
		+ " %.1f %% de lo que da por bueno)" % (
			100.0 * float(promises) / maxf(float(open_cells), 1.0)))
	print("     la peor pendiente que promete: %.2f (el limite es %.2f)" % [
		worst_slope, Traversal.CLIMB_LIMIT])
	print("  cierra de mas -dice que no y si se pasa-: %d (%.2f %%)" % [
		refuses, 100.0 * float(refuses) / float(SAMPLES)])

	# Y lo que importa de verdad: que desde el abrigo se siga llegando a todas
	# partes. Una rejilla que no promete de más pero deja media comarca
	# incomunicada no sirve de nada.
	var home: Vector3 = sim.home_position
	var reachable := 0
	var tried := 0
	for i in range(4000):
		var point := Vector3(
			rng.randf() * float(terrain.terrain_size.x), 0.0,
			rng.randf() * float(terrain.terrain_size.y))
		if not grid.passable(point):
			continue
		tried += 1
		if grid.connected(home, point):
			reachable += 1
	# ¿Hay vado en alguna parte? Si el río entero está por encima de lo que se
	# cruza a pie, que las dos orillas estén incomunicadas es el diseño -para
	# eso están la piragua y la pasarela-. Si lo hay y aun así está cerrado, es
	# que la rejilla lo está tapando.
	var wettest := 0.0
	var best_ford := INF
	var river_points := 0
	for i in range(SAMPLES):
		var point := Vector3(
			rng.randf() * float(terrain.terrain_size.x), 0.0,
			rng.randf() * float(terrain.terrain_size.y))
		var ford := terrain.crossing_difficulty_at(point)
		if ford <= 0.001:
			continue
		river_points += 1
		wettest = maxf(wettest, ford)
		best_ford = minf(best_ford, ford)
	print("")
	print("del cauce: %d puntos · el peor %.2f · el mejor %.2f (se vadea hasta %.2f)" % [
		river_points, wettest, best_ford, Hydrography.FORD_WADEABLE])

	# El tamaño de cada zona, que es lo que dice si lo que no se alcanza es una
	# comarca entera al otro lado del río o cuatro rincones sueltos.
	var sizes: Dictionary = {}
	for cell in range(grid.area.size()):
		var zone: int = grid.area[cell]
		if zone < 0:
			continue
		sizes[zone] = int(sizes.get(zone, 0)) + 1
	var order: Array[int] = []
	order.assign(sizes.keys())
	order.sort_custom(func(a: int, b: int) -> bool:
		return int(sizes[a]) > int(sizes[b]))
	var open_total := 0
	for zone: int in order:
		open_total += int(sizes[zone])
	var home_zone: int = grid.area[grid.cell_of(sim.home_position)]
	print("")
	print("zonas, de mayor a menor:")
	for zone: int in order:
		print("  zona %d: %d celdas (%.1f %% de lo transitable)%s" % [
			zone, int(sizes[zone]),
			100.0 * float(sizes[zone]) / maxf(float(open_total), 1.0),
			"   <-- la del abrigo" if zone == home_zone else ""])

	# Y lo que cuesta buscar, que es la otra mitad: una rejilla honesta que
	# obligue a búsquedas carísimas no vale.
	#
	# Se mide en dos bandas, y la que importa es la primera. La banda de
	# JORNADA -novecientos metros, el radio dentro del que la gente elige tajo,
	# ver `_rank_known_spots`- es lo que de verdad se busca jugando. La de punta
	# a punta sale sólo cuando se manda una expedición al otro extremo del
	# valle, y además se guarda en el caché de rutas.
	for band: Array in [["de jornada (900 m)", 900.0], ["de punta a punta", 99999.0]]:
		var slowest := 0.0
		var total_ms := 0.0
		var worst_nodes := 0
		var searches := 0
		var tries := 0
		while searches < 120 and tries < 4000:
			tries += 1
			var a := Vector3(rng.randf() * float(terrain.terrain_size.x), 0.0,
				rng.randf() * float(terrain.terrain_size.y))
			var away := rng.randf_range(60.0, minf(float(band[1]), 2600.0))
			var angle := rng.randf() * TAU
			var b := a + Vector3(cos(angle), 0.0, sin(angle)) * away
			if b.x < 0.0 or b.z < 0.0 or b.x > float(terrain.terrain_size.x) 					or b.z > float(terrain.terrain_size.y):
				continue
			if not grid.passable(a) or not grid.passable(b):
				continue
			var t := Time.get_ticks_usec()
			Wayfinder.find(grid, a, b)
			var spent := float(Time.get_ticks_usec() - t) / 1000.0
			searches += 1
			total_ms += spent
			slowest = maxf(slowest, spent)
			worst_nodes = maxi(worst_nodes, Wayfinder.last_nodes)
		print("")
		print("%d busquedas %s: %.2f ms de media · %.1f ms la peor · %d nodos" % [
			searches, String(band[0]), total_ms / maxf(float(searches), 1.0),
			slowest, worst_nodes])

	print("")
	print("desde el abrigo se llega al %.1f %% de lo transitable" % (
		100.0 * float(reachable) / maxf(float(tried), 1.0)))
	quit()
