extends SceneTree
## Vuelca el albedo de una pieza a PNG, para mirarlo sin luz de por medio.
##
## Cuando la medida dice una cosa y el render parece decir otra, la textura en
## crudo desempata: si el albedo es gris claro y en pantalla sale oscuro, el
## problema es la luz o el material, no el color.

func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	for key: String in ["canto", "nodulo", "yesca"]:
		if not library.has(key):
			continue
		var mesh: ArrayMesh = library.mesh(key)
		var material := mesh.surface_get_material(0)
		if not (material is BaseMaterial3D):
			continue
		var base := material as BaseMaterial3D
		print("%-8s albedo_color=%s  metalico=%.2f  rugosidad=%.2f  ao=%s" % [
			key, str(base.albedo_color), base.metallic, base.roughness,
			"si" if base.get_texture(
				BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION) else "no"])
		var texture := base.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
		if texture == null:
			continue
		var image := texture.get_image()
		if image.is_compressed():
			image = image.duplicate()
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(320, 320, Image.INTERPOLATE_LANCZOS)
		image.save_png("user://albedo_%s.png" % key)
	print("volcados en %s" % ProjectSettings.globalize_path("user://"))
	quit()
