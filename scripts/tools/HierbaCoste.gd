extends SceneTree
## Qué trae cada silueta de hierba de la biblioteca, en triángulos.
##
## Es el dato que decide si la hierba se puede sembrar densa o no. Una mata de
## fotogrametría es una malla escaneada; una mata de juego son dos quads
## cruzados. Entre las dos hay dos órdenes de magnitud, y de ahí sale que la
## alfombra a la que se apuntaba sea inviable con lo que hay y trivial con lo
## que debería haber.


func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("sin biblioteca"); quit(1); return

	for key: String in ["herbazal", "pasto", "helecho"]:
		var total := 0
		var count := library.variants(key)
		for variant in range(count):
			total += _triangles(library.mesh(key, variant))
		if count == 0:
			continue
		print("%-9s %2d siluetas · %6d tri en total · %5d de media" % [
			key, count, total, total / count])
	quit()


func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var tris := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			tris += verts.size() / 3
		else:
			tris += indices.size() / 3
	return tris
