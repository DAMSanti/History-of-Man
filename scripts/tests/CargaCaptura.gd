extends SceneTree
## La pantalla de carga, en captura, a 1920×1080 y 1280×720. INTERFAZ §9.
##
##   godot --path . --script res://scripts/tests/CargaCaptura.gd
##
## Deja `user://capturas/carga_<ancho>x<alto>.png` con la barra a medias y una etapa.


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("user://capturas")
	Carga.abrir(self, "Volviendo al valle")
	Carga.etapas([["Levantando el relieve", 500.0], ["Sembrando el bosque", 14000.0],
		["Encendiendo el hogar", 600.0]])
	Carga.etapa(1)
	Carga.avanzar(0.45)
	for lado: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(lado)
		root.size = lado
		for _i in range(40):
			await process_frame
		var ruta := "user://capturas/carga_%dx%d.png" % [lado.x, lado.y]
		root.get_texture().get_image().save_png(ruta)
		print("  %s · barra %.2f · «%s»" % [ProjectSettings.globalize_path(ruta), Carga.valor(), Carga.texto()])
	Carga.cerrar()
	quit()
