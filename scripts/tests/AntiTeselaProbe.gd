extends SceneTree
## Qué cuesta cada mitad del anti-teselado.
##
## Son dos técnicas y conviene saber el precio de cada una por separado, porque
## una puede no compensar:
##
##   `warp_amount`  desplaza las coordenadas con ruido de onda larga; deshace la
##                  ALINEACIÓN de la rejilla pero no cambia el contenido
##   `macro_break`  muestrea la misma capa a una escala mucho mayor y la usa
##                  para modular; cambia el CONTENIDO, y cuesta un muestreo
##
## Se alternan dentro de la misma ejecución y se informa del mínimo, por lo de
## siempre: entre tandas hay dos milisegundos largos de deriva y el efecto que
## se busca es de ese orden. Ver `CorteProbe`.

const SITE_ID := 56
const ROUNDS := 3

## nombre · warp · macro · hex
##
## El hex-tiling entra como tercera columna porque es de otra naturaleza que las
## dos anteriores. `warp` y `macro` DISIMULAN la repetición -deshacen la
## alineación y modulan el color- pero el patrón sigue estando ahí; el hex la
## QUITA, porque cada parche de textura es un trozo distinto del original.
## Interesa el precio de cada cosa por separado y el de las tres juntas.
const CASES := [
	["sin nada", 0.0, 0.0, false],
	["solo desplazamiento", 2.6, 0.0, false],
	["solo escala grande", 0.0, 0.85, false],
	["desplazamiento y escala", 2.6, 0.85, false],
	["solo hex-tiling", 0.0, 0.0, true],
	["hex y escala grande", 0.0, 0.85, true],
	["todo", 2.6, 0.85, true],
]


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

	var home := Vector3(2048.0, 0.0, 2048.0)
	home.y = terrain.get_height_at(home)
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(0.0, 75.0, 130.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()

	# A MEDIODÍA. La partida arranca a las seis y en pausa, y el día 80 el sol
	# sale a las 6:02: sin esto las capturas salen en penumbra ámbar y la
	# cuadrícula de la textura no se ve ni estando.
	if "sim" in demo and demo.sim != null:
		demo.sim.hour = 12.0
		for i in range(6):
			await process_frame

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var best: Dictionary = {}
	for round_index in range(ROUNDS):
		for case: Array in CASES:
			material.set_shader_parameter("warp_amount", case[1])
			material.set_shader_parameter("macro_break", case[2])
			material.set_shader_parameter("use_hex_tiling", case[3])
			var gpu := await _sample(vp)
			var label: String = case[0]
			if not best.has(label) or gpu < best[label]:
				best[label] = gpu
			# Una captura de cada caso en la primera vuelta: el coste se lee en
			# la tabla, pero si la cuadrícula se ve o no sólo se juzga mirando.
			if round_index == 0:
				var shot := root.get_texture().get_image()
				shot.save_png("user://tesela_%d.png" % CASES.find(case))

	print("")
	print("=== ANTI-TESELADO (GPU de render, mínimo de %d vueltas) ===" % ROUNDS)
	var reference: float = best["sin nada"]
	for case: Array in CASES:
		var label: String = case[0]
		print("%-22s %5.1f ms   %s" % [label, best[label],
			"referencia" if label == "sin nada" else "%+.1f ms" % (best[label] - reference)])
	print("capturas tesela_0..%d en %s" % [CASES.size() - 1,
		ProjectSettings.globalize_path("user://")])
	quit()


func _sample(vp: RID) -> float:
	for i in range(25):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if child.get_class() == type_name:
			return child
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
