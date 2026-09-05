extends SceneTree
## Cuanto ahorra el descarte de planos del triplanar, medido en serio.
##
## Comparar entre ejecuciones no vale: entre tanda y tanda hay dos milisegundos
## largos de deriva -boost clock que cae con la carga sostenida, y lo que haya
## abierto en la maquina- y el efecto que se busca es de ese orden. Una tanda
## llego a dar 48 ms de linea base cuando las de al lado daban 23.
##
## Aqui se alternan los valores DENTRO de la misma ejecucion y se dan varias
## vueltas, asi que la deriva afecta por igual a todos. Se informa del MINIMO y
## no de la media, porque el ruido de rendimiento solo suma: la muestra mas baja
## es la que menos contaminada esta.

const SITE_ID := 56
const CUTOFFS := [0.0, 0.08, 0.15, 0.25]
const ROUNDS := 3

var _times: Dictionary = {}


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
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(220):
		await process_frame

	var demo := current_scene
	var terrain: Node = _first(demo, "TerrainGenerator")
	if terrain == null or not terrain.has_method("get_terrain_material"):
		print("sin terreno"); quit(); return
	var material: ShaderMaterial = terrain.get_terrain_material()
	if material == null:
		print("sin material"); quit(); return

	var home := Vector3(2048.0, 0.0, 2048.0)
	home.y = terrain.get_height_at(home)
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(0.0, 75.0, 130.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	for value: float in CUTOFFS:
		_times[value] = []

	for round_index in range(ROUNDS):
		for value: float in CUTOFFS:
			material.set_shader_parameter("plane_cutoff", value)
			var gpu := await _sample(vp)
			(_times[value] as Array).append(gpu)
			print("  vuelta %d · corte %.2f · %.1f ms" % [round_index + 1, value, gpu])

	print("")
	print("=== DESCARTE DE PLANOS (GPU de render, minimo de %d vueltas) ===" % ROUNDS)
	var reference := 0.0
	for value: float in CUTOFFS:
		var best: float = (_times[value] as Array).min()
		if value == 0.0:
			reference = best
		print("corte %.2f  ->  %5.1f ms   %s" % [value, best,
			"referencia" if value == 0.0 else "%+.1f ms" % (best - reference)])
	quit()


func _sample(vp: RID) -> float:
	for i in range(25):
		await process_frame
	var gpu := 0.0
	var frames := 60
	for i in range(frames):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / float(frames)


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if child.get_class() == type_name:
			return child
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
