extends SceneTree
## Verifica que todas las texturas de materiales y herramientas cargan correctamente.

func _init() -> void:
	print("=== VERIFICANDO TEXTURAS DE MATERIALES ===")
	var mat_missing := 0
	for kind: int in MateriaIcon.LOOK:
		var tex := MateriaIcon.get_materia_texture(kind as Materia.Kind)
		var mat_name := Materia.material_name(kind as Materia.Kind)
		if tex == null:
			print("  [ERROR] Falta textura para material: %s (kind %d)" % [mat_name, kind])
			mat_missing += 1
		else:
			print("  [OK] %s: %dx%d" % [mat_name, tex.get_width(), tex.get_height()])

	print("\n=== VERIFICANDO TEXTURAS DE HERRAMIENTAS ===")
	var tool_missing := 0
	for kind: int in MateriaIcon.TOOL_LOOK:
		var tex := MateriaIcon.get_tool_texture(kind as Tool.Kind)
		var t_name := Tool.kind_name(kind as Tool.Kind)
		if tex == null:
			print("  [ERROR] Falta textura para herramienta: %s (kind %d)" % [t_name, kind])
			tool_missing += 1
		else:
			print("  [OK] %s: %dx%d" % [t_name, tex.get_width(), tex.get_height()])

	print("\n=== RESUMEN ===")
	print("Materiales: %d probados, %d errores." % [MateriaIcon.LOOK.size(), mat_missing])
	print("Herramientas: %d probadas, %d errores." % [MateriaIcon.TOOL_LOOK.size(), tool_missing])

	if mat_missing == 0 and tool_missing == 0:
		print("¡TODAS LAS 45 TEXTURAS DEL ALMACEN CARGAN CORRECTAMENTE!")

	quit()
