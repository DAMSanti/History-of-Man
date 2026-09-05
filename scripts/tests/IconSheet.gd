extends SceneTree
## Hoja de contactos de los iconos: los dibuja todos y guarda un PNG para
## poder mirarlos. No es una prueba, es una herramienta de vista.

func _init() -> void:
	var root_control := Control.new()
	root_control.size = Vector2(760, 560)
	root.add_child(root_control)

	var back := ColorRect.new()
	back.color = UISkin.GROUND
	back.size = Vector2(760, 560)
	root_control.add_child(back)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(16, 16)
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	root_control.add_child(grid)

	for kind: int in MateriaIcon.LOOK:
		grid.add_child(_cell(
			MateriaIcon.for_materia(kind as Materia.Kind, 34.0),
			Materia.material_name(kind as Materia.Kind)))

	for kind: int in MateriaIcon.TOOL_LOOK:
		grid.add_child(_cell(
			MateriaIcon.for_tool(kind as Tool.Kind, 34.0),
			Tool.kind_name(kind as Tool.Kind)))

	await process_frame
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	var path := "user://iconos.png"
	image.save_png(path)
	print("hoja guardada en %s" % ProjectSettings.globalize_path(path))
	print("iconos de material: %d · de herramienta: %d"
		% [MateriaIcon.LOOK.size(), MateriaIcon.TOOL_LOOK.size()])
	quit()


func _cell(icon: MateriaIcon, caption: String) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(112, 0)
	column.add_theme_constant_override("separation", 2)

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(112, 38)
	holder.add_child(icon)
	column.add_child(holder)

	var label := Label.new()
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", UISkin.INK_SOFT)
	column.add_child(label)

	return column
