extends SceneTree
## Qué compra la luz de rebote, y qué cuesta.
##
## Las laderas en sombra salen casi negras. Se descartaron `ssao_intensity`,
## `ambient_light_energy`, `tonemap_white` y que WeatherView pisara el entorno
## —ver TeselaProbe—. Lo que queda es que no hay luz de rebote: con SDFGI
## apagado, una ladera de espaldas al sol sólo recibe el cielo. Falta una fuente
## de luz, no sobra un número.
##
## El plan daba por supuesto que SDFGI «se nota poco y va sólo en Ultra». Eso
## puede ser cierto con las texturas viejas —ruido de bajo contraste— y falso con
## fotogrametría. Y además hay una sospecha concreta: `sdfgi_min_cell_size` está
## en 0,2 m, que con cuatro cascadas cubre poco más de cien metros. En un valle
## de cuatro kilómetros eso es una burbuja alrededor de la cámara, así que puede
## que no es que SDFGI no sirva, sino que está configurado para una escena de
## interior.
##
## Se prueba apagado y con tres tamaños de celda, midiendo y capturando lo mismo.

const SITE_ID := 56
const ROUNDS := 2

## nombre · encendido · min_cell_size
const CASES := [
	["apagado", false, 0.0],
	["celda 0,2 m (lo puesto)", true, 0.2],
	["celda 1,5 m", true, 1.5],
	["celda 4,0 m", true, 4.0],
]

var _env: Environment


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
	for i in range(240):
		await process_frame

	var demo := current_scene
	var terrain: Node = _first(demo, "TerrainGenerator")
	if terrain == null:
		print("sin terreno"); quit(); return

	_setup_light(demo)
	if _env == null:
		print("sin entorno"); quit(); return

	var home := Vector3(2048.0, 0.0, 2048.0)
	home.y = terrain.get_height_at(home)
	var from_point := home + Vector3(120.0, 60.0, 190.0)

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var best: Dictionary = {}
	for round_index in range(ROUNDS):
		for index in range(CASES.size()):
			var case: Array = CASES[index]
			_apply(case[1] as bool, case[2] as float)
			var gpu := await _sample(vp)
			var label: String = case[0]
			if not best.has(label) or gpu < best[label]:
				best[label] = gpu
			if round_index == 0:
				await _shoot(demo, "user://rebote_%d.png" % index, from_point, home)

	print("")
	print("=== LUZ DE REBOTE (GPU de render, mínimo de %d vueltas) ===" % ROUNDS)
	var reference: float = best["apagado"]
	for case: Array in CASES:
		var label: String = case[0]
		print("%-26s %5.1f ms   %s" % [label, best[label],
			"referencia" if label == "apagado" else "%+.1f ms" % (best[label] - reference)])
	print("capturas rebote_0..3 en %s" % ProjectSettings.globalize_path("user://"))
	quit()


## SDFGI necesita reconstruir sus cascadas al cambiarle el tamaño de celda, y
## además tarda unos fotogramas en converger: si se mide o se captura demasiado
## pronto se ve a medio llenar y parece que no hace nada.
func _apply(enabled: bool, cell: float) -> void:
	_env.sdfgi_enabled = false
	if enabled:
		_env.sdfgi_min_cell_size = cell
		_env.sdfgi_enabled = true


func _sample(vp: RID) -> float:
	for i in range(90):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0


func _setup_light(node: Node) -> void:
	var light := _find_light(node)
	if light:
		light.rotation_degrees = Vector3(-62.0, -50.0, 0.0)
		light.light_energy = 1.15
	_find_env(node)


func _find_env(node: Node) -> void:
	for child in node.get_children():
		if child is WorldEnvironment:
			_env = (child as WorldEnvironment).environment
			if _env:
				_env.volumetric_fog_enabled = false
				_env.fog_enabled = false
			return
		_find_env(child)


func _find_light(node: Node) -> DirectionalLight3D:
	for child in node.get_children():
		if child is DirectionalLight3D:
			return child as DirectionalLight3D
		var deeper := _find_light(child)
		if deeper:
			return deeper
	return null


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if child.get_class() == type_name:
			return child
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null


func _shoot(demo: Node, path: String, from_point: Vector3, at: Vector3) -> void:
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = from_point
	camera.look_at(at, Vector3.UP)
	camera.make_current()
	for i in range(20):
		await process_frame
	root.get_texture().get_image().save_png(path)
	camera.queue_free()
