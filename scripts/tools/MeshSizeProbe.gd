extends SceneTree
## Cuánto ocupa la GEOMETRÍA de cada modelo en la biblioteca.
##
## Las texturas suman 152 MB y el fichero pesa 1.257: hay que buscar el resto.

func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("sin biblioteca"); quit(1); return
	var grand := 0
	print("%-10s %4s %9s %10s %10s" % ["clave", "sup", "tri", "vertices", "MB"])
	for key: String in PropModels.CATALOGUE:
		if not library.has(key):
			continue
		var mesh: ArrayMesh = library.mesh(key)
		var bytes := 0
		var tris := 0
		var verts := 0
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			verts += v.size()
			tris += idx.size() / 3
			bytes += v.size() * 12 + idx.size() * 4
			for channel: int in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
					Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
				var a: Variant = arrays[channel]
				if a is PackedVector3Array:
					bytes += (a as PackedVector3Array).size() * 12
				elif a is PackedVector2Array:
					bytes += (a as PackedVector2Array).size() * 8
				elif a is PackedColorArray:
					bytes += (a as PackedColorArray).size() * 16
				elif a is PackedFloat32Array:
					bytes += (a as PackedFloat32Array).size() * 4
		grand += bytes
		print("%-10s %4d %9d %10d %10.1f" % [key, mesh.get_surface_count(),
			tris, verts, bytes / 1048576.0])
	print("TOTAL %.1f MB de geometria" % (grand / 1048576.0))
	quit()
