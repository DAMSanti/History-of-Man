extends SceneTree
## De dónde salen los 25 ms del terreno.
##
## La bisección a ciegas -apagar cosas y ver qué baja- se agotó: no eran los
## píxeles, ni los triángulos, ni los scripts, ni las sombras. Aquí se usa el
## medidor que trae Godot, que separa el tiempo de CPU del de GPU dentro del
## render. Eso dice de qué lado está el problema en vez de hacerlo adivinar.

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
	for i in range(220):
		await process_frame

	var demo := current_scene
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var home := Vector3(2048.0, 0.0, 2048.0)
	var terrain: Node = _first(demo, "TerrainGenerator")
	if terrain and terrain.has_method("get_height_at"):
		home.y = terrain.get_height_at(home)

	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(0.0, 75.0, 130.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()

	print("")
	print("=== DE DONDE SALEN LOS MILISEGUNDOS (camara de juego) ===")
	print("%-26s %8s %8s %8s" % ["", "total", "cpu-rnd", "gpu-rnd"])
	await _sample(vp, "todo encendido")

	var ring: Node = demo.get_node_or_null("Alrededores")
	var pieces: Node = demo.get_node_or_null("TerrainMesh")
	if terrain:
		pieces = (terrain as Node).get_node_or_null("TerrainMesh")

	var light: DirectionalLight3D = _find_light(demo)

	if ring:
		(ring as Node3D).visible = false
		await _sample(vp, "sin contorno")
		(ring as Node3D).visible = true

	if pieces:
		(pieces as Node3D).visible = false
		await _sample(vp, "sin terreno jugable")
		(pieces as Node3D).visible = true

	if light:
		light.shadow_enabled = false
		await _sample(vp, "sin sombras")
		light.shadow_enabled = true

	# Y con un material trivial en el terreno: si el tiempo se desploma, el
	# coste esta en el shader triplanar y no en la geometria
	if pieces:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(0.4, 0.45, 0.35)
		plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var saved := {}
		for child in (pieces as Node).get_children():
			if child is MeshInstance3D:
				saved[child] = (child as MeshInstance3D).material_override
				(child as MeshInstance3D).material_override = plain
		await _sample(vp, "terreno sin shader")
		for child: Variant in saved:
			(child as MeshInstance3D).material_override = saved[child]

	# Los ajustes del proyecto: MSAA x4 Y TAA a la vez es raro -el TAA suele
	# sustituir al MSAA- y el filtro de sombras esta en calidad alta.
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _sample(vp, "sin MSAA")

	root.use_taa = false
	await _sample(vp, "sin MSAA ni TAA")
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_4X

	# Y la combinacion que propondria: escala al 75% con FSR2, que reconstruye
	# mucho mejor que el escalado bilineal
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	root.scaling_3d_scale = 0.75
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _sample(vp, "FSR2 75% + sin MSAA")
	root.scaling_3d_scale = 1.0
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.msaa_3d = Viewport.MSAA_4X

	# Las dos palancas de dentro del shader: los mapas de normales duplican
	# los muestreos, y la anisotropia multiplica los texeles por fetch.
	if terrain and terrain.has_method("get_terrain_material"):
		var mat: ShaderMaterial = terrain.get_terrain_material()
		if mat:
			mat.set_shader_parameter("use_normal_maps", false)
			await _sample(vp, "sin mapas de normales")
			mat.set_shader_parameter("use_normal_maps", true)

			var sharp: float = mat.get_shader_parameter("triplanar_sharpness")
			mat.set_shader_parameter("weight_cutoff", 0.12)
			await _sample(vp, "corte de capa al 12%")
			mat.set_shader_parameter("weight_cutoff", 0.02)

	# La prueba de resolucion de antes no valia: cambiar el tamano de VENTANA
	# no cambia la resolucion a la que se dibuja el 3D. Esto si: `scaling_3d`
	# es el factor de la resolucion interna del render.
	for scale: float in [0.75, 0.5, 0.35]:
		root.scaling_3d_scale = scale
		await _sample(vp, "escala 3D al %d%%" % int(scale * 100.0))
	root.scaling_3d_scale = 1.0

	quit()


func _find_light(node: Node) -> DirectionalLight3D:
	for child in node.get_children():
		if child is DirectionalLight3D:
			return child
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


func _sample(vp: RID, label: String) -> void:
	for i in range(25):
		await process_frame

	var frames := 60
	var start := Time.get_ticks_usec()
	var cpu := 0.0
	var gpu := 0.0
	for i in range(frames):
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var total := float(Time.get_ticks_usec() - start) / float(frames) / 1000.0

	print("%-26s %7.1f  %7.1f  %7.1f   · %d tri, %d draws" % [
		label, total, cpu / frames, gpu / frames,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
