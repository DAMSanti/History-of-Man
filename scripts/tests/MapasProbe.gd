extends SceneTree
## Qué cuesta cada mapa del terreno, medido como hay que medirlo.
##
## Dos cifras del plan se tomaron comparando ejecuciones distintas —la compresión
## a BC7 y el paso a `Texture2DArray` con ORM— y resultaron estar contaminadas:
## había otra instancia de Godot con el juego abierto durante buena parte de la
## sesión, así que la carga de fondo variaba entre tandas. La dirección de esas
## medidas casi seguro era correcta, pero la magnitud no valía.
##
## Aquí se alterna dentro de UNA ejecución, que es inmune a una carga de fondo
## constante:
##
##   - BC7 contra crudo, construyendo los dos juegos de arrays desde las mismas
##     imágenes y cambiando el uniform en caliente
##   - el ORM encendido y apagado
##   - los mapas de normales encendidos y apagados
##
## Lo que NO se puede repetir es el shader viejo de ocho samplers: se borró. Así
## que la comparación «arrays contra samplers» se queda sin repetir, y lo que se
## mide en su lugar es qué cuesta el TERCER mapa, que era el argumento.

const SITE_ID := 56
const ROUNDS := 3


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

	var arrays: TerrainTextureArrays = load(TerrainLayers.ARRAYS_PATH)
	if arrays == null or not arrays.is_usable():
		print("sin texturas de terreno"); quit(); return

	print("construyendo el juego SIN comprimir...")
	var raw_albedo := _uncompressed(arrays.albedo_images)
	var raw_normal := _uncompressed(arrays.normal_images)
	var raw_orm := _uncompressed(arrays.orm_images)

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

	var best: Dictionary = {}
	for round_index in range(ROUNDS):
		best = _keep(best, "todo, BC7", await _measure(vp, material, arrays,
			raw_albedo, raw_normal, raw_orm, true, true, true))
		best = _keep(best, "todo, sin comprimir", await _measure(vp, material,
			arrays, raw_albedo, raw_normal, raw_orm, false, true, true))
		best = _keep(best, "BC7 sin ORM", await _measure(vp, material, arrays,
			raw_albedo, raw_normal, raw_orm, true, false, true))
		best = _keep(best, "BC7 sin normales", await _measure(vp, material,
			arrays, raw_albedo, raw_normal, raw_orm, true, true, false))

	print("")
	print("=== MAPAS DEL TERRENO (GPU, minimo de %d vueltas) ===" % ROUNDS)
	var reference: float = best["todo, BC7"]
	for label: String in ["todo, BC7", "todo, sin comprimir", "BC7 sin ORM",
			"BC7 sin normales"]:
		print("%-22s %5.1f ms   %s" % [label, best[label],
			"referencia" if label == "todo, BC7"
			else "%+.1f ms" % (best[label] - reference)])
	quit()


func _keep(best: Dictionary, label: String, value: float) -> Dictionary:
	if not best.has(label) or value < best[label]:
		best[label] = value
	return best


func _measure(vp: RID, material: ShaderMaterial, arrays: TerrainTextureArrays,
		raw_a: Texture2DArray, raw_n: Texture2DArray, raw_o: Texture2DArray,
		compressed: bool, orm: bool, normals: bool) -> float:
	material.set_shader_parameter("terrain_albedo",
		arrays.albedo() if compressed else raw_a)
	material.set_shader_parameter("terrain_normal",
		arrays.normal() if compressed else raw_n)
	material.set_shader_parameter("terrain_orm",
		arrays.orm() if compressed else raw_o)
	material.set_shader_parameter("use_orm", orm)
	material.set_shader_parameter("use_normal_maps", normals)

	for i in range(25):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0


## El mismo contenido descomprimido, para poder comparar sólo la compresión.
func _uncompressed(images: Array[Image]) -> Texture2DArray:
	var out: Array[Image] = []
	for image: Image in images:
		var copy := (image as Image).duplicate() as Image
		if copy.is_compressed():
			copy.decompress()
		out.append(copy)
	var array := Texture2DArray.new()
	array.create_from_images(out)
	return array


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
