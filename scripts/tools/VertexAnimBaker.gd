class_name VertexAnimBaker
extends RefCounted
## El horneado de animación a textura de vértice, para cualquier bicho con
## esqueleto -no sólo la banda-. Extraído de `BandaAtlas.gd`: ver ese fichero
## para el porqué de hornear a mano en vez de usar el botón del addon
## (`AnimatedMultiMeshInstance3D`) o `bake_mesh_from_current_skeleton_pose()`
## -ninguno de los dos funciona en un `--script` headless sin GPU real-.
##
## Mismo álgebra en los dos sitios: por cada fotograma, la pose de cada hueso
## sale de `Skeleton3D.get_bone_global_pose()` -eso SÍ es CPU pura, no toca el
## servidor de render-, y se combina a mano con los pesos de cada vértice.

const SHADER_PATH := "res://addons/animated_multimeshinstance3d/shaders/vetex_animation_shader.gdshader"
const BONES_PER_VERTEX := 8


## Hornea un modelo entero -uno o varios clips- a `<out_dir>/<prefix>_*.res`.
## `clips` es `{nombre_corto: nombre_real_de_la_pista}`. Devuelve
## `{nombre_corto: {"start_frame": int, "length": int}}`, el mismo formato
## que usan [BandaCrowd] y [WildlifeCrowd] para su `animation_list`.
static func bake(tree: SceneTree, scene_path: String, armature_path: String,
		mesh_path: String, clips: Dictionary, sampling_fps: float, out_dir: String,
		prefix: String, albedo_path: String) -> Dictionary:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("VertexAnimBaker: no se pudo cargar %s" % scene_path)
		return {}

	var scene := packed.instantiate()
	tree.root.add_child(scene)

	var armature := scene.get_node_or_null(armature_path) as Node3D
	var mesh_instance := scene.get_node_or_null(mesh_path) as MeshInstance3D
	if armature == null or mesh_instance == null:
		push_error("VertexAnimBaker: falta armature o mesh en %s (%s / %s)"
			% [scene_path, armature_path, mesh_path])
		scene.queue_free()
		return {}

	var player := _find_type(scene, "AnimationPlayer") as AnimationPlayer
	var skeleton := _find_type(scene, "Skeleton3D") as Skeleton3D
	if player == null or skeleton == null:
		push_error("VertexAnimBaker: falta AnimationPlayer o Skeleton3D en %s" % scene_path)
		scene.queue_free()
		return {}

	var skin := mesh_instance.skin
	if skin == null:
		push_error("VertexAnimBaker: %s no trae Skin" % scene_path)
		scene.queue_free()
		return {}

	var armature_transform := armature.transform
	var mesh := mesh_instance.mesh as ArrayMesh
	var arrays := mesh.surface_get_arrays(0)
	var rest_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rest_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bone_idx: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vertex_count := rest_verts.size()
	var bones_per_vertex := bone_idx.size() / maxi(vertex_count, 1)

	var bind_bone := PackedInt32Array()
	bind_bone.resize(skin.get_bind_count())
	for b in range(skin.get_bind_count()):
		var bone := skin.get_bind_bone(b)
		if bone < 0:
			bone = skeleton.find_bone(skin.get_bind_name(b))
		if bone < 0:
			push_error("VertexAnimBaker: %s, bind %d sin hueso resoluble" % [scene_path, b])
			scene.queue_free()
			return {}
		bind_bone[b] = bone

	var frame_counts: Dictionary = {}
	var total_frames := 0
	for key: String in clips:
		var anim := player.get_animation(clips[key])
		if anim == null:
			push_error("VertexAnimBaker: falta el clip %s (%s) en %s"
				% [key, clips[key], scene_path])
			scene.queue_free()
			return {}
		var count := maxi(ceili(anim.length * sampling_fps), 1)
		frame_counts[key] = count
		total_frames += count

	var vertex_image := Image.create_empty(total_frames, vertex_count, false, Image.FORMAT_RGBF)
	var normal_image := Image.create_empty(total_frames, vertex_count, false, Image.FORMAT_RGBF)

	var animation_list: Dictionary = {}
	var cursor := 0
	var skin_matrix: Array[Transform3D] = []
	skin_matrix.resize(skin.get_bind_count())

	for key: String in clips:
		var track_name: String = clips[key]
		var count: int = frame_counts[key]
		animation_list[key] = {"start_frame": cursor, "length": count}
		player.play(track_name)
		for frame_index in range(count):
			player.seek(float(frame_index) / sampling_fps, true)
			for b in range(skin.get_bind_count()):
				skin_matrix[b] = armature_transform \
					* skeleton.get_bone_global_pose(bind_bone[b]) \
					* skin.get_bind_pose(b)
			var column := cursor + frame_index
			for v in range(vertex_count):
				var base := v * bones_per_vertex
				var posed_vertex := Vector3.ZERO
				var posed_normal := Vector3.ZERO
				for k in range(bones_per_vertex):
					var w: float = weights[base + k]
					if w <= 0.0:
						continue
					var m := skin_matrix[bone_idx[base + k]]
					posed_vertex += (m * rest_verts[v]) * w
					posed_normal += (m.basis * rest_normals[v]) * w
				vertex_image.set_pixel(column, v,
					Color(posed_vertex.x, posed_vertex.y, posed_vertex.z))
				var n := posed_normal.normalized()
				normal_image.set_pixel(column, v, Color(n.x, n.y, n.z))
		cursor += count
	player.stop()
	scene.queue_free()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var vertex_texture := ImageTexture.create_from_image(vertex_image)
	var normal_texture := ImageTexture.create_from_image(normal_image)
	ResourceSaver.save(vertex_texture, "%s/%s_vertex.res" % [out_dir, prefix])
	ResourceSaver.save(normal_texture, "%s/%s_normal.res" % [out_dir, prefix])
	# Recargados desde el fichero: el objeto recién creado no lleva
	# `resource_path`, y sin él el material de abajo INCRUSTA la textura
	# entera en vez de apuntar al fichero -ver el aviso igual en BandaAtlas.gd-.
	vertex_texture = load("%s/%s_vertex.res" % [out_dir, prefix])
	normal_texture = load("%s/%s_normal.res" % [out_dir, prefix])

	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	if not albedo_path.is_empty():
		material.set_shader_parameter("albedo", load(albedo_path))
	material.set_shader_parameter("vertex_animation", vertex_texture)
	material.set_shader_parameter("normal_animation", normal_texture)
	material.set_shader_parameter("total_frame_count", float(total_frames))
	material.set_shader_parameter("total_vertex_count", float(vertex_count))
	material.set_shader_parameter("sampling_fps", sampling_fps)
	ResourceSaver.save(material, "%s/%s_material.tres" % [out_dir, prefix])
	ResourceSaver.save(mesh, "%s/%s_mesh.res" % [out_dir, prefix])

	print("  %s: %d vertices, %d fotogramas, %d clips -> %s/%s_*"
		% [prefix, vertex_count, total_frames, clips.size(), out_dir, prefix])
	return animation_list


static func _find_type(node: Node, cls: String) -> Node:
	if node.get_class() == cls:
		return node
	for child in node.get_children():
		var found := _find_type(child, cls)
		if found:
			return found
	return null
