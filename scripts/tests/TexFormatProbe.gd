extends SceneTree
## En que formato acaban las texturas del terreno, y cuanto ocupan.

func _init() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("terrain_textures.res"):
		dir.remove("terrain_textures.res")
		print("cache de texturas borrada")

	var textures: Dictionary = ProceduralTextureGenerator.get_terrain_textures()
	var total := 0
	for name: String in textures:
		var tex: Texture2D = textures[name]
		var img := tex.get_image()
		if img == null:
			print("%-16s sin imagen" % name)
			continue
		var bytes := img.get_data().size()
		total += bytes
		print("%-16s %4d x %4d · %-22s mips %s · %6.2f MB" % [
			name, img.get_width(), img.get_height(),
			_format_name(img.get_format()),
			"si" if img.has_mipmaps() else "NO", bytes / 1048576.0])
	print("TOTAL %.2f MB" % (total / 1048576.0))
	quit()


func _format_name(f: int) -> String:
	match f:
		Image.FORMAT_RGB8: return "RGB8 (crudo)"
		Image.FORMAT_RGBA8: return "RGBA8 (crudo)"
		Image.FORMAT_BPTC_RGBA: return "BPTC/BC7 (comprimido)"
		Image.FORMAT_DXT1: return "DXT1"
		Image.FORMAT_DXT5: return "DXT5"
	return "formato %d" % f
