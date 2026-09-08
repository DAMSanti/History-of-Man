extends SceneTree
## Vista de las casillas de alrededor sobre el mapa real de Los Pendios.
##
## Monta la escena local igual que la fundación desde el mapa regional, coloca
## la cámara mirando a la costura desde fuera y guarda un PNG. No es una
## prueba: es la única forma de comprobar que las ocho casillas salen con
## textura y no en gris, que es un fallo que sólo se ve mirando.

const SITE_ID := 56


func _init() -> void:
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res") if \
		ResourceLoader.exists("res://data/sites/cantabria_sites.res") else null

	var site := _find_site(sites)
	if site == null:
		print("Sin emplazamiento %d: no se puede montar la vista" % SITE_ID)
		quit()
		return

	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	if local == null:
		print("Sin MDT local del emplazamiento %d" % SITE_ID)
		quit()
		return

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

	# SIN vsync. Con el activado los tiempos se pegan a multiplos del refresco
	# -16,7 ms, 33,3 ms- y no miden trabajo, miden esperas: 640x360 y 1920x1080
	# daban exactamente lo mismo, que es imposible salvo por cuantizacion.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	change_scene_to_file("res://scenes/demo_main.tscn")

	# El terreno tarda: se le dan bastantes fotogramas antes de mirar
	for i in range(240):
		await process_frame

	var demo := current_scene
	if demo == null:
		print("La escena no ha cargado")
		quit()
		return

	_report(demo)

	# La camara del banco mira el valle entero desde 1.500 m: es el caso PEOR
	# para el troceado, porque no hay nada fuera de encuadre que descartar.
	print("--- camara de banco (todo el valle a la vista) ---")
	await _measure(demo)

	# Y la de jugar de verdad: orbita a 150 unidades con 30 grados de
	# inclinacion, que es lo que trae CameraController por defecto. Aqui es
	# donde el troceado tiene que notarse.
	var home := Vector3(2048.0, 0.0, 2048.0)
	var terrain_node: Node = _first(demo, "TerrainGenerator")
	if terrain_node and terrain_node.has_method("get_height_at"):
		home.y = terrain_node.get_height_at(home)
	print("--- camara de juego (orbita a 150, 30 grados) ---")
	await _measure_from(demo, home + Vector3(0.0, 75.0, 130.0), home)

	# Y cuanto de eso es el contorno, desde la MISMA camara de juego: las
	# casillas de fuera miden 4 km cada una, asi que a ras de suelo ocupan
	# todo el horizonte y el nivel de detalle no las simplifica.
	var ring: Node = demo.get_node_or_null("Alrededores")
	if ring:
		(ring as Node3D).visible = false
		print("--- camara de juego SIN contorno ---")
		await _measure_from(demo, home + Vector3(0.0, 75.0, 130.0), home)
		(ring as Node3D).visible = true

	# Sospechoso: las sombras. Una direccional con cascadas repinta la escena
	# entera una vez por cascada, y eso no depende de la resolucion de
	# pantalla, que es justo lo que se ha medido.
	var light: DirectionalLight3D = null
	for n in demo.get_children():
		if n is DirectionalLight3D:
			light = n
		for m in n.get_children():
			if m is DirectionalLight3D:
				light = m
	if light:
		light.shadow_enabled = false
		print("--- sin sombras ---")
		await _measure(demo)
		light.shadow_enabled = true
	else:
		print("--- no se ha encontrado la luz direccional ---")

	# Bisección de lo que se DIBUJA: se esconde un grupo y se vuelve a medir
	var groups := {
		"contorno": demo.get_node_or_null("Alrededores"),
		"props de recurso": _first(demo, "ResourceProps"),
		"terreno jugable": _first(demo, "TerrainGenerator"),
	}
	# Los dos a la vez: lo que quede es coste fijo, ni geometria ni shader
	var both_a: Node = demo.get_node_or_null("Alrededores")
	var both_b: Node = _first(demo, "TerrainGenerator")
	if both_a and both_b:
		(both_a as Node3D).visible = false
		(both_b as Node3D).visible = false
		print("--- sin NADA de terreno ---")
		await _measure(demo)
		(both_a as Node3D).visible = true
		(both_b as Node3D).visible = true

	for label: String in groups:
		var node: Node = groups[label]
		if node == null or not (node is Node3D):
			print("   %-18s no encontrado" % label)
			continue
		var was: bool = (node as Node3D).visible
		(node as Node3D).visible = false
		print("--- sin %s ---" % label)
		await _measure(demo)
		(node as Node3D).visible = was
	await _shoot(demo, "user://alrededores_alto.png",
		Vector3(2048.0, 1500.0, 5200.0), Vector3(2048.0, 0.0, 2048.0))
	await _shoot(demo, "user://alrededores_costura.png",
		Vector3(2048.0, 420.0, 4900.0), Vector3(2048.0, 120.0, 3600.0))

	print("vistas guardadas en %s"
		% ProjectSettings.globalize_path("user://"))
	quit()


func _find_site(sites: SiteSet) -> Site:
	if sites == null:
		return null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			return s
	return null


## Lo que de verdad se quiere saber: qué material ha acabado en las casillas.
func _report(demo: Node) -> void:
	var surround := demo.get_node_or_null("Alrededores")
	if surround == null:
		print("SIN casillas de alrededor")
		return

	var tiles := 0
	var shader_tiles := 0
	for child in surround.get_children():
		if not (child is MeshInstance3D):
			continue
		tiles += 1
		if (child as MeshInstance3D).material_override is ShaderMaterial:
			shader_tiles += 1

	print("casillas: %d · con shader del terreno: %d · en gris: %d"
		% [tiles, shader_tiles, tiles - shader_tiles])

	# La sospecha: el shader normaliza la altura contra el techo del RECUADRO,
	# y fuera hay monte mas alto. Todo lo que pase de ese techo se satura y
	# cae en la banda de roca, que es tostada.
	var terrain: TerrainGenerator = demo.get_node_or_null("Terreno")
	if terrain == null:
		for child in demo.get_children():
			if child is TerrainGenerator:
				terrain = child
	if terrain != null:
		var span := terrain.get_height_range()
		print("recuadro: cotas de %.1f a %.1f unidades" % [span.x, span.y])
		var lm: HeightmapData = terrain.heightmap
		if lm:
			var lsize := lm.get_world_size_meters()
			print("MDT local: %d x %d muestras, %.0f x %.0f m, %.1f m/muestra"
				% [lm.width, lm.height, lsize.x, lsize.y, lm.meters_per_sample])
			print("  recuadro jugable: %d m, desplazado a %s"
				% [terrain.terrain_size.x, str(terrain.heightmap_region_offset)])
			print("  rios en el MDT local: %s"
				% ("si" if not lm.river_mask.is_empty() else "NO"))
		var sm: HeightmapData = load("res://data/dem/local/site_56_surround.res")
		if sm:
			print("MDT contorno: %d x %d, %.1f m/muestra, rios %s"
				% [sm.width, sm.height, sm.meters_per_sample,
					"si" if not sm.river_mask.is_empty() else "NO"])
		var top := -1e9
		var low := 1e9
		for child in surround.get_children():
			if not (child is MeshInstance3D):
				continue
			var mesh := (child as MeshInstance3D).mesh as ArrayMesh
			if mesh == null or mesh.get_surface_count() == 0:
				continue
			var aabb := mesh.get_aabb()
			top = maxf(top, aabb.position.y + aabb.size.y)
			low = minf(low, aabb.position.y)
		print("contorno: cotas de %.1f a %.1f unidades" % [low, top])
		if top > span.y:
			print("  -> el contorno SE SALE %.1f unidades por arriba" % (top - span.y))


## Coste de fotograma con la camara puesta donde se ven las ocho casillas a la
## vez, que es el caso peor.
func _measure_from(demo: Node, from_point: Vector3, at: Vector3) -> void:
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = from_point
	camera.look_at(at, Vector3.UP)
	camera.make_current()

	for i in range(20):
		await process_frame
	var start := Time.get_ticks_usec()
	for i in range(60):
		await process_frame
	var per_frame := float(Time.get_ticks_usec() - start) / 60000.0

	print("fotograma %.1f ms (%.0f fps) · triangulos %d · draw calls %d" % [
		per_frame, 1000.0 / maxf(per_frame, 0.001),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	camera.queue_free()


func _measure(demo: Node) -> void:
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = Vector3(2048.0, 1500.0, 5200.0)
	camera.look_at(Vector3(2048.0, 0.0, 2048.0), Vector3.UP)
	camera.make_current()

	for i in range(30):
		await process_frame

	var start := Time.get_ticks_usec()
	for i in range(60):
		await process_frame
	var per_frame := float(Time.get_ticks_usec() - start) / 60000.0

	print("fotograma %.1f ms (%.0f fps) · script %.1f ms · fisica %.1f ms · triangulos %d · draw calls %d" % [
		per_frame, 1000.0 / maxf(per_frame, 0.001),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	camera.queue_free()


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

	for i in range(6):
		await process_frame

	root.get_texture().get_image().save_png(path)
	camera.queue_free()
