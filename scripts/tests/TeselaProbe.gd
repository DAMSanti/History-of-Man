extends SceneTree
## De dónde sale la cuadrícula que se ve en el terreno.
##
## «Se nota la repetición» tiene al menos tres causas posibles y desde el
## terreno acabado no se distinguen:
##
##   1. La textura, que tesela cada pocos metros y dibuja su rejilla
##   2. El reparto de capas, que puede cambiar de material en línea recta
##   3. La variación de mancha, que va por VÉRTICE y se interpola en el
##      triángulo, así que sus fronteras siguen aristas
##
## Se saca la misma vista tres veces —terreno normal, capa dominante como color
## plano, y albedo sin normales— y comparándolas se ve cuál manda.

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
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(240):
		await process_frame

	var demo := current_scene
	var terrain: Node = _first(demo, "TerrainGenerator")
	if terrain == null or not terrain.has_method("get_terrain_material"):
		print("sin terreno"); quit(); return
	var material: ShaderMaterial = terrain.get_terrain_material()

	# Luz de mediodía a la fuerza. La partida arranca a las 06:00 y con niebla,
	# y bajo esa luz no se puede juzgar una PALETA: todo sale gris azulado y
	# cualquier graduación de color parece la misma. Para calibrar hace falta una
	# luz de referencia, igual que para medir hace falta una tanda de referencia.
	_force_noon(demo)

	var home := Vector3(2048.0, 0.0, 2048.0)
	home.y = terrain.get_height_at(home)

	# Vista de ladera media, que es donde se ve la rejilla
	var from_point := home + Vector3(120.0, 60.0, 190.0)

	for view in range(3):
		material.set_shader_parameter("debug_view", view)
		await _shoot(demo, "user://tesela_%d.png" % view, from_point, home)
	material.set_shader_parameter("debug_view", 0)

	# Vista de cerca, para comprobar que los props están donde deben y con la
	# talla que dicen. A distancia de juego un canto de 34 cm es subpíxel, así
	# que desde lejos no se puede saber si el modelo está bien o está roto.
	await _shoot(demo, "user://props_cerca.png",
		home + Vector3(9.0, 5.0, 12.0), home)

	# Prueba de la oclusión del material sobre las sombras
	for strength: float in [0.0, 0.25, 0.8]:
		material.set_shader_parameter("ao_strength", strength)
		await _shoot(demo, "user://ao_%02d.png" % int(strength * 100.0),
			from_point, home)
	material.set_shader_parameter("ao_strength", 0.8)

	print("0 terreno · 1 capa dominante · 2 albedo sin normales")
	print("en %s" % ProjectSettings.globalize_path("user://"))
	quit()


## Sol alto, luz plena y sin bruma, para juzgar color.
##
## Aviso para quien mire estas capturas: las laderas en sombra salen casi
## NEGRAS, y eso no es la paleta. Se probaron y se descartaron cuatro causas:
## `ssao_intensity` (estaba en 2,0), `ambient_light_energy`, `tonemap_white`
## (6,0, que con ACES aplasta) y que WeatherView estuviese pisando el entorno
## —sólo toca la niebla—. Ninguna de las cuatro abre las sombras.
##
## Lo que queda es que NO HAY LUZ DE REBOTE: con SDFGI apagado, una ladera de
## espaldas al sol sólo recibe el cielo. Es físicamente lo que se ha pedido, y
## por eso ningún ajuste lo arregla: falta una fuente de luz, no sobra un
## número. Pendiente de probar con SDFGI encendido.
func _force_noon(node: Node) -> void:
	var light := _find_light(node)
	if light:
		light.rotation_degrees = Vector3(-62.0, -50.0, 0.0)
		light.light_energy = 1.15
	for child in node.get_children():
		if child is WorldEnvironment:
			var env: Environment = (child as WorldEnvironment).environment
			if env:
				env.volumetric_fog_enabled = false
				env.fog_enabled = false
			return
		_force_noon_env(child)


func _force_noon_env(node: Node) -> void:
	for child in node.get_children():
		if child is WorldEnvironment:
			var env: Environment = (child as WorldEnvironment).environment
			if env:
				env.volumetric_fog_enabled = false
				env.fog_enabled = false
			return
		_force_noon_env(child)


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
	for i in range(10):
		await process_frame
	root.get_texture().get_image().save_png(path)
	camera.queue_free()
