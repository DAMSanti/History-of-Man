extends SceneTree
## Qué color tiene de verdad el albedo de cada prop, ya graduado.
##
## Ajustar un tinte mirando una miniatura es adivinar: un tinte de 1,4 sobre un
## albedo de 0,10 sigue siendo 0,14, o sea oscuro. Esto da el número.

func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("sin biblioteca"); quit(1); return

	print("%-9s %-22s %6s %6s %6s   luz  saturacion" % [
		"clave", "nombre", "R", "G", "B"])
	for key: String in PropModels.CATALOGUE:
		if not library.has(key):
			continue
		var mesh: ArrayMesh = library.mesh(key)
		var total := Color(0, 0, 0)
		var samples := 0
		for surface in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(surface)
			if not (material is BaseMaterial3D):
				continue
			var texture := (material as BaseMaterial3D).get_texture(
				BaseMaterial3D.TEXTURE_ALBEDO)
			if texture == null:
				continue
			var image := texture.get_image()
			if image == null:
				continue
			if image.is_compressed():
				image = image.duplicate()
				image.decompress()
			image.convert(Image.FORMAT_RGBA8)
			# Una rejilla de muestras basta: es una media, no un histograma
			var step := maxi(1, image.get_width() / 24)
			for y in range(0, image.get_height(), step):
				for x in range(0, image.get_width(), step):
					var c := image.get_pixel(x, y)
					if c.a < 0.5:
						continue  # la hoja transparente no cuenta
					total += Color(c.r, c.g, c.b)
					samples += 1
		if samples == 0:
			continue
		var mean := total / float(samples)
		var lum := 0.299 * mean.r + 0.587 * mean.g + 0.114 * mean.b
		var mx := maxf(mean.r, maxf(mean.g, mean.b))
		var mn := minf(mean.r, minf(mean.g, mean.b))
		print("%-9s %-22s %6.3f %6.3f %6.3f  %5.3f  %5.3f" % [
			key, PropModels.CATALOGUE[key]["name"], mean.r, mean.g, mean.b,
			lum, (mx - mn) / maxf(mx, 0.001)])
	quit()
