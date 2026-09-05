extends SceneTree
## Por qué no se ve ni un canto en el terreno.
##
## Los modelos son correctos —`PropSheet` los enseña a su talla junto a una
## persona— y el sembrado informa de miles de instancias colocadas. Pero
## poniendo la cámara encima de una de ellas no hay nada.
##
## En vez de seguir mirando capturas, esto pregunta el estado de cada capa:
## cuántas instancias tiene, si la malla es nula, dónde está el nodo, dónde está
## la primera instancia, y qué recorte de visibilidad lleva puesto. Y luego
## apaga el recorte y vuelve a mirar, que es la prueba que separa «no están» de
## «están y algo las esconde».

const SITE_ID := 56


func _init() -> void:
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
	var layers: Array[MultiMeshInstance3D] = []
	_collect(demo, layers)

	print("")
	print("=== CAPAS DE PROPS ===")
	print("%-24s %7s %8s %10s %26s %26s" % [
		"capa", "inst.", "malla", "recorte", "nodo en", "instancia 0 en"])
	for node: MultiMeshInstance3D in layers:
		var multi := node.multimesh
		var count := 0
		var first := Vector3.ZERO
		if multi != null:
			count = multi.instance_count
			if count > 0:
				first = multi.get_instance_transform(0).origin
		print("%-24s %7d %8s %10.0f %26s %26s" % [
			node.name, count,
			"NULA" if multi == null or multi.mesh == null else "ok",
			node.visibility_range_end,
			str(node.global_position.round()), str(first.round())])

	# ¿Y cuántas caen cerca del poblado? Que una materia esté sembrada no quiere
	# decir que se vea: si su hábitat la manda toda al otro extremo del valle,
	# el jugador no la encuentra nunca. Esto mide reparto, no existencia.
	var terrain: Node = _first(demo, "TerrainGenerator")
	var home := Vector3(2048.0, 0.0, 2048.0)
	if terrain and terrain.has_method("get_height_at"):
		home.y = terrain.get_height_at(home)

	var near: Dictionary = {}
	var closest: Dictionary = {}
	for node: MultiMeshInstance3D in layers:
		var kind := node.name.substr(0, node.name.rfind("_", node.name.rfind("_") - 1))
		var multi := node.multimesh
		for i in range(multi.instance_count):
			var world: Vector3 = node.global_position 				+ multi.get_instance_transform(i).origin
			var flat := Vector2(world.x - home.x, world.z - home.z).length()
			near[kind] = int(near.get(kind, 0)) + (1 if flat < 300.0 else 0)
			if flat < float(closest.get(kind, 1e9)):
				closest[kind] = flat

	print("")
	print("=== REPARTO RESPECTO AL POBLADO ===")
	print("%-26s %10s %14s" % ["materia", "a <300 m", "la mas cercana"])
	for kind: String in near:
		print("%-26s %10d %11.0f m" % [kind, near[kind], closest[kind]])

	# Bisección por materia: se apaga una y se mide. Es la única forma de saber
	# cuál se está comiendo el fotograma, porque el coste no se reparte a partes
	# iguales -un follaje con alfa no se deja simplificar y arrastra su nivel más
	# basto entero-.
	var kinds: Dictionary = {}
	for node: MultiMeshInstance3D in layers:
		var kind := node.name.substr(0, node.name.rfind("_", node.name.rfind("_") - 1))
		if not kinds.has(kind):
			kinds[kind] = ([] as Array[MultiMeshInstance3D])
		(kinds[kind] as Array[MultiMeshInstance3D]).append(node)

	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(0.0, 75.0, 130.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var base := await _cost(vp)
	print("")
	print("=== QUÉ CUESTA CADA MATERIA (camara de juego) ===")
	print("todo encendido            %5.1f ms · %d triangulos" % [base.x, int(base.y)])
	for kind: String in kinds:
		for node: MultiMeshInstance3D in kinds[kind]:
			node.visible = false
		var without := await _cost(vp)
		for node: MultiMeshInstance3D in kinds[kind]:
			node.visible = true
		print("%-25s %5.1f ms · ahorra %4.1f ms y %d triangulos" % [
			"sin " + kind.replace("Recurso_", ""), without.x,
			base.x - without.x, int(base.y - without.y)])
	camera.queue_free()

	# Y la prueba que decide: apagar el recorte de visibilidad. Si con esto
	# aparecen, es que el recorte los estaba tapando; si no, es que no están.
	var target := Vector3.INF
	for node: MultiMeshInstance3D in layers:
		if node.name.begins_with("Recurso_Cuarcita") and node.multimesh.instance_count > 0:
			target = node.global_position \
				+ node.multimesh.get_instance_transform(0).origin
	if target == Vector3.INF:
		print("sin cuarcita que mirar"); quit(); return

	print("")
	print("primera cuarcita en %s · camara a 6 m de ella" % str(target.round()))
	await _shoot(demo, "user://visible_con_recorte.png", target)

	for node: MultiMeshInstance3D in layers:
		node.visibility_range_end = 0.0
		node.visibility_range_end_margin = 0.0
	await _shoot(demo, "user://visible_sin_recorte.png", target)

	print("capturas en %s" % ProjectSettings.globalize_path("user://"))
	quit()


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null


func _cost(vp: RID) -> Vector2:
	for i in range(20):
		await process_frame
	var gpu := 0.0
	for i in range(40):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return Vector2(gpu / 40.0, float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))


func _collect(node: Node, out: Array[MultiMeshInstance3D]) -> void:
	if node is MultiMeshInstance3D and node.name.begins_with("Recurso_"):
		out.append(node as MultiMeshInstance3D)
	for child in node.get_children():
		_collect(child, out)


func _shoot(demo: Node, path: String, at: Vector3) -> void:
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = at + Vector3(3.5, 2.2, 4.5)
	camera.look_at(at, Vector3.UP)
	camera.make_current()
	for i in range(12):
		await process_frame
	root.get_texture().get_image().save_png(path)
	camera.queue_free()
