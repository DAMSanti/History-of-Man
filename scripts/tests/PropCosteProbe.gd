extends SceneTree
## Cuánto cuesta sembrar props de fotogrametría, y si los LOD sirven de algo.
##
## `ResourceProps` siembra hasta 2600 instancias por tipo. Un modelo de Poly
## Haven trae unos 15.000 triángulos: 38,6 millones para UN tipo, y hay ocho.
## Para comparar, el terreno entero son 3,4 millones y su geometría cuesta
## 0,3 ms. O sea que en crudo no se puede.
##
## Lo que hay que averiguar antes de tocar arte son dos cosas:
##
##   1. ¿`ImporterMesh.generate_lods` sabe decimar esto, y hasta dónde?
##   2. ¿Un `MultiMesh` USA esos LOD? Porque si no los usa, da igual generarlos:
##      habrá que sembrar una malla baja y punto.
##
## Se mide en escena aislada -suelo, luz, cámara y el sembrado- y no dentro del
## juego, para que el número sea del sembrado y no de todo lo demás.

const MODEL := "user://prop_ingest/rock_07/rock_07_1k.gltf"
const COUNT := 2600
const SPREAD := 2048.0
const ROUNDS := 2

var _camera: Camera3D
var _holder: MultiMeshInstance3D


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var source := _load_model()
	if source == null:
		print("no se pudo cargar %s" % MODEL)
		quit(1)
		return
	print("malla de origen: %d triangulos" % _triangles(source))

	var with_lods := _make_lods(source)

	_build_scene()

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var cases := [
		["origen sin LOD", source],
		["origen con LOD", with_lods],
		["caja de control", _control_mesh()],
	]

	var best: Dictionary = {}
	var tris: Dictionary = {}
	for round_index in range(ROUNDS):
		for case: Array in cases:
			var mesh: Mesh = case[1]
			if mesh == null:
				continue
			_scatter(mesh)
			var result := await _sample(vp)
			var label: String = case[0]
			if not best.has(label) or result.x < best[label]:
				best[label] = result.x
				tris[label] = result.y

	print("")
	print("=== SEMBRADO DE %d INSTANCIAS (minimo de %d vueltas) ===" % [COUNT, ROUNDS])
	print("%-20s %8s %14s" % ["", "GPU ms", "triangulos"])
	for case: Array in cases:
		var label: String = case[0]
		if best.has(label):
			print("%-20s %7.1f %14s" % [label, best[label],
				_thousands(int(tris[label]))])
	quit()


func _load_model() -> ArrayMesh:
	var path := ProjectSettings.globalize_path(MODEL)
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	# Sin texturas: el .bin y el .gltf bastan para contar geometria, y las
	# imagenes que falten solo producen avisos.
	if doc.append_from_file(path, state) != OK:
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		return null
	return _first_mesh(scene)


func _first_mesh(node: Node) -> ArrayMesh:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			return mesh as ArrayMesh
	for child in node.get_children():
		var found := _first_mesh(child)
		if found:
			return found
	return null


## Reconstruye la malla como `ImporterMesh` y le pide los niveles de detalle.
##
## Es la via que trae el motor: la usa el importador de glTF del editor. Aqui se
## llama a mano porque esto corre como herramienta, sin editor.
func _make_lods(source: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in range(source.get_surface_count()):
		importer.add_surface(
			source.surface_get_primitive_type(surface),
			source.surface_get_arrays(surface),
			[], {}, source.surface_get_material(surface))

	# La firma de `generate_lods` ha cambiado entre versiones de Godot, asi que
	# se prueban las dos en vez de dar una por buena.
	var done := false
	for args: Array in [[25.0, 60.0, []], [25.0, []]]:
		if importer.has_method("generate_lods"):
			importer.callv("generate_lods", args)
			done = true
			break
	if not done:
		print("ImporterMesh no expone generate_lods en esta version")
		return null

	var levels := importer.get_surface_lod_count(0)
	print("niveles de detalle generados: %d" % levels)
	for level in range(levels):
		var indices: PackedInt32Array = importer.get_surface_lod_indices(0, level)
		print("   nivel %d: %s triangulos" % [level, _thousands(indices.size() / 3)])
	return importer.get_mesh()


## Malla de control: una caja. Sirve de suelo del experimento —si el sembrado de
## cajas ya cuesta, el problema no es la fotogrametria sino el numero.
func _control_mesh() -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.4, 0.6)
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		box.get_mesh_arrays())
	return array_mesh


func _build_scene() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -40.0, 0.0)
	world.add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = environment
	world.add_child(env)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SPREAD * 3.0, SPREAD * 3.0)
	ground.mesh = plane
	world.add_child(ground)

	_holder = MultiMeshInstance3D.new()
	world.add_child(_holder)

	# La camara de juego: orbita a 130 con 30 grados, que es lo que trae
	# CameraController por defecto.
	_camera = Camera3D.new()
	_camera.far = 8000.0
	world.add_child(_camera)
	_camera.global_position = Vector3(0.0, 75.0, 130.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.make_current()


func _scatter(mesh: Mesh) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = COUNT

	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in range(COUNT):
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		var spot := Vector3(rng.randf_range(-SPREAD, SPREAD), 0.0,
			rng.randf_range(-SPREAD, SPREAD))
		multi.set_instance_transform(i, Transform3D(basis, spot))
	_holder.multimesh = multi


## Devuelve (ms de GPU, triangulos dibujados).
func _sample(vp: RID) -> Vector2:
	for i in range(30):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return Vector2(gpu / 60.0, float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))


func _triangles(mesh: ArrayMesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += verts.size() / 3
		else:
			total += indices.size() / 3
	return total


func _thousands(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out
