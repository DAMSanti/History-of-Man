extends SceneTree
## Cuánto ocupa cada modelo en texturas, y en qué formato.
##
## La biblioteca se fue a 1,2 GB con las mallas ya recortadas, así que el peso
## está en las texturas. Esto dice cuáles NO se comprimieron: `Image.compress`
## no protesta si falla, se queda cruda y sigue.

func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("sin biblioteca"); quit(1); return
	var grand := 0
	print("%-10s %5s %8s %10s  %s" % ["clave", "tex", "MB", "formato", "tamaños"])
	for key: String in PropModels.CATALOGUE:
		if not library.has(key):
			continue
		var mesh: ArrayMesh = library.mesh(key)
		var bytes := 0
		var count := 0
		var formats: Dictionary = {}
		var dims: Dictionary = {}
		var seen: Dictionary = {}
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface)
			if not (material is BaseMaterial3D):
				continue
			for slot: int in [BaseMaterial3D.TEXTURE_ALBEDO,
					BaseMaterial3D.TEXTURE_NORMAL,
					BaseMaterial3D.TEXTURE_ROUGHNESS,
					BaseMaterial3D.TEXTURE_METALLIC,
					BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION,
					BaseMaterial3D.TEXTURE_EMISSION]:
				var texture := (material as BaseMaterial3D).get_texture(slot)
				if texture == null or seen.has(texture.get_instance_id()):
					continue
				seen[texture.get_instance_id()] = true
				var image := texture.get_image()
				if image == null:
					continue
				bytes += image.get_data().size()
				count += 1
				formats[image.get_format()] = true
				dims["%dx%d" % [image.get_width(), image.get_height()]] = true
		grand += bytes
		print("%-10s %5d %8.1f %10s  %s" % [key, count, bytes / 1048576.0,
			", ".join(formats.keys().map(func(f): return str(f))),
			", ".join(dims.keys())])
	print("TOTAL %.1f MB en texturas" % (grand / 1048576.0))
	print("(formato 37 = BPTC/BC7 comprimido · 5 = RGBA8 crudo)")
	quit()
