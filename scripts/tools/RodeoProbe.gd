extends SceneTree
## Cuanto mas largo es el camino de verdad que la linea recta.
##
## Hace falta para decidir cuando emprender la vuelta: si se calcula el tiempo
## de regreso en linea recta, se sale tarde y la noche coge a la gente en el
## monte. Medido antes de ponerle margen: hora y media despues de la de dormir
## seguia habiendo persona y media fuera del abrigo, todas las noches.
##
## Se sortean pares de puntos a distancia de jornada, se traza el camino y se
## compara su longitud con la recta.

const SITE_ID := 56
const SAMPLES := 400


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

	var grid := Navgrid.from_terrain(terrain, false, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260907
	var home: Vector3 = sim.home_position

	# La vuelta a casa, que es la que importa: del tajo al abrigo.
	var ratios: Array[float] = []
	var tries := 0
	while ratios.size() < SAMPLES and tries < SAMPLES * 40:
		tries += 1
		var away := rng.randf_range(120.0, 1600.0)
		var angle := rng.randf() * TAU
		var from_point := home + Vector3(cos(angle), 0.0, sin(angle)) * away
		if from_point.x < 0.0 or from_point.z < 0.0 \
				or from_point.x > float(terrain.terrain_size.x) \
				or from_point.z > float(terrain.terrain_size.y):
			continue
		from_point.y = terrain.get_height_at(from_point)
		if not grid.passable(from_point):
			continue
		var route := Wayfinder.find(grid, from_point, home)
		if route.size() < 2:
			continue
		# El camino que devuelve `Wayfinder.find` NO trae el punto de partida:
		# empieza en el primer hito. Sumando solo entre hitos salia un camino
		# MAS CORTO que la recta, que es imposible y delataba el fallo.
		var walked := 0.0
		var previous := from_point
		for step: Vector3 in route:
			walked += Vector2(step.x - previous.x, step.z - previous.z).length()
			previous = step
		var straight := Vector2(home.x - from_point.x, home.z - from_point.z).length()
		if straight < 1.0:
			continue
		ratios.append(walked / straight)

	ratios.sort()
	var total := 0.0
	for r: float in ratios:
		total += r
	print("")
	print("=== EL RODEO DE LA VUELTA A CASA (%d caminos) ===" % ratios.size())
	print("media   %.2f veces la linea recta" % (total / maxf(float(ratios.size()), 1.0)))
	for cut: float in [0.5, 0.75, 0.9, 0.95, 0.99]:
		print("%3.0f %%   %.2f" % [cut * 100.0,
			ratios[mini(int(cut * float(ratios.size())), ratios.size() - 1)]])
	print("peor    %.2f" % ratios[ratios.size() - 1])
	quit()
