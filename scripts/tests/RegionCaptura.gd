extends SceneTree
## El mapa regional a 1920×1080 y a 1280×720: que ninguna ventana se salga, y
## cómo se ve la frontera hasta el agua.
## Frente 18 de EPOCA_01 §10.1, tanda 4.
##
## No sólo captura: recorre todos los controles visibles de la interfaz y dice
## cuáles se salen de la pantalla. Eso es lo que se mide; la captura es para
## verlo.
##   godot --path . --script res://scripts/tests/RegionCaptura.gd

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Una sonda no escribe en los mapas del jugador. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/mapas"
	change_scene_to_file("res://scenes/region_map.tscn")
	for i in range(240):
		await process_frame
	var mapa := current_scene
	if mapa == null:
		print("sin mapa regional")
		quit(1)
		return
	for site: Site in mapa._site_set.sites:
		if site.id == SITE_ID:
			mapa._select_site(site)

	var total_fuera := 0
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		DisplayServer.window_set_size(resolucion)
		get_root().size = resolucion
		for i in range(30):
			await process_frame
		var pantalla := Rect2(Vector2.ZERO, Vector2(get_root().size))
		var fuera := _fuera_de(mapa, pantalla)
		total_fuera += fuera.size()
		print("%dx%d: %d controles se salen %s" % [resolucion.x, resolucion.y,
			fuera.size(), str(fuera.slice(0, 6))])
		var shot := get_root().get_texture().get_image()
		if shot != null:
			var ruta := "user://region_%dx%d.png" % [resolucion.x, resolucion.y]
			shot.save_png(ruta)
			print("captura en %s" % ProjectSettings.globalize_path(ruta))
	quit(0 if total_fuera == 0 else 1)


## Los controles visibles que no caben enteros en la pantalla.
func _fuera_de(nodo: Node, pantalla: Rect2) -> Array:
	var salida: Array = []
	# Lo que va dentro de un panel con desplazamiento lo recorta el panel: su
	# rectángulo puede ser más alto que la pantalla sin que se vea fuera. Se mide
	# el panel, no lo de dentro.
	if nodo is ScrollContainer:
		if (nodo as Control).is_visible_in_tree():
			var marco := (nodo as Control).get_global_rect()
			if not pantalla.grow(1.0).encloses(marco):
				salida.append("%s %s" % [nodo.name, str(marco)])
		return salida
	if nodo is Control and (nodo as Control).is_visible_in_tree():
		var rect := (nodo as Control).get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0 \
				and not pantalla.grow(1.0).encloses(rect):
			salida.append("%s %s" % [nodo.name, str(rect)])
	for hijo: Node in nodo.get_children():
		salida.append_array(_fuera_de(hijo, pantalla))
	return salida
