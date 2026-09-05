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
