extends SceneTree
## Qué trae de verdad el FBX de Quaternius, para saber cómo hornearlo.
##
## Antes de escribir un horneador de animaciones a mano hay que saber los
## nombres reales: dónde cae el `AnimationPlayer`, el `Skeleton3D` y la
## `MeshInstance3D` dentro de la escena importada, cuántos vértices tiene la
## malla y qué clips trae. `AnimatedMultiMeshInstance3D.gd` da estos mismos
## datos por defecto (`Armature/Skeleton3D/Mesh`), pero cada FBX los coloca a
## su manera y hay que comprobarlo, no suponerlo.

func _init() -> void:
	var scene: PackedScene = load("res://models/people/source/Animated Human.fbx")
	if scene == null:
		print("no se pudo cargar el FBX"); quit(); return

	var root := scene.instantiate()
	print("raiz: %s (%s)" % [root.name, root.get_class()])
	_dump(root, 0)

	var player := _find_type(root, "AnimationPlayer") as AnimationPlayer
	if player:
		print("")
		print("AnimationPlayer en: %s" % root.get_path_to(player))
		for clip in player.get_animation_list():
			var anim := player.get_animation(clip)
			print("  %-20s %.2f s  (%d pistas)" % [clip, anim.length, anim.get_track_count()])

	var skel := _find_type(root, "Skeleton3D") as Skeleton3D
	if skel:
		print("")
		print("Skeleton3D en: %s (%d huesos)" % [root.get_path_to(skel), skel.get_bone_count()])

	var mesh_node := _find_type(root, "MeshInstance3D") as MeshInstance3D
	if mesh_node:
		print("")
		print("MeshInstance3D en: %s" % root.get_path_to(mesh_node))
		var mesh := mesh_node.mesh
		if mesh is ArrayMesh:
			for surf in range((mesh as ArrayMesh).get_surface_count()):
				var arrays := (mesh as ArrayMesh).surface_get_arrays(surf)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				print("  superficie %d: %d vertices" % [surf, verts.size()])

	quit()


func _dump(node: Node, depth: int) -> void:
	print("  ".repeat(depth) + "- %s : %s" % [node.name, node.get_class()])
	for child in node.get_children():
		_dump(child, depth + 1)


func _find_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var found := _find_type(child, type_name)
		if found:
			return found
	return null
