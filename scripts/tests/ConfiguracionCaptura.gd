extends SceneTree
## La ventana de configuración a 1920×1080 y a 1280×720: que no se salga nada.
##
## INTERFAZ §8, último criterio. Con ventana —sin ella no hay captura— y con la
## receta de `PrioridadesCaptura`: el escalado de contenido desactivado y la
## ventana abierta **a cada resolución**, que se coloca con el tamaño que había al
## abrirse. Las tres pestañas.
##
##   godot --path . --script res://scripts/tests/ConfiguracionCaptura.gd

var _fallos: Array[String] = []


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Su configuración: la del jugador no se lee ni se escribe.
	Configuracion.ruta = "user://sondas/configuracion_captura.cfg"
	change_scene_to_file("res://scenes/menu_principal.tscn")
	for i in range(30):
		await process_frame
	var menu := current_scene as MenuPrincipal
	if menu == null:
		print("MAL: sin menú principal")
		quit(1)
		return
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion)
		get_root().size = resolucion
		var esperas := 0
		while get_root().size != resolucion and esperas < 240:
			esperas += 1
			await process_frame
		for i in range(20):
			await process_frame
		if menu.configuracion != null:
			menu.configuracion.cerrada.emit()
			await process_frame
		var ventana := menu.abrir_configuracion()
		for pestana in range(3):
			ventana._pestanas.current_tab = pestana
			for i in range(8):
				await process_frame
			var nombre: String = ventana._pestanas.get_tab_title(pestana)
			var fuera := _fuera_de(ventana, Rect2(Vector2.ZERO, Vector2(get_root().size)))
			if fuera.is_empty():
				print("   ok · %dx%d · %s: nada se sale" % [resolucion.x, resolucion.y, nombre])
			else:
				_fallos.append("%dx%d · %s: %s" % [resolucion.x, resolucion.y, nombre,
					str(fuera.slice(0, 4))])
				print("   MAL · %s" % _fallos.back())
			var shot := get_root().get_texture().get_image()
			if shot != null:
				var ruta := "user://configuracion_%d_%dx%d.png" % [pestana, resolucion.x, resolucion.y]
				shot.save_png(ruta)
				print("      captura en %s" % ProjectSettings.globalize_path(ruta))
	print("=== %s ===" % ("TODO BIEN" if _fallos.is_empty() else "%d COSAS MAL" % _fallos.size()))
	quit(0 if _fallos.is_empty() else 1)


## La vara de `RegionCaptura`: lo que va dentro de un panel con desplazamiento lo
## recorta el panel, así que se mide el panel.
func _fuera_de(nodo: Node, pantalla: Rect2) -> Array:
	var salida: Array = []
	if nodo is ScrollContainer:
		if (nodo as Control).is_visible_in_tree():
			var marco := (nodo as Control).get_global_rect()
			if not pantalla.grow(1.0).encloses(marco):
				salida.append("%s %s" % [nodo.name, str(marco)])
		return salida
	if nodo is Control and (nodo as Control).is_visible_in_tree():
		var rect := (nodo as Control).get_global_rect()
		var dentro := pantalla.grow(1.0).encloses(rect)
		if rect.size.x > 1.0 and rect.size.y > 1.0 and not dentro:
			salida.append("%s %s" % [nodo.name, str(rect)])
	for hijo: Node in nodo.get_children():
		salida.append_array(_fuera_de(hijo, pantalla))
	return salida
