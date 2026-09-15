extends SceneTree
## El bosque del valle, por escalón, visto con la cámara de juego. GRAFICOS §7.1.
##
## **Con ventana.**
##
##   ESCALON=2 godot --path . --script res://scripts/tests/BosqueCaptura.gd
##
## Monta el valle del sitio 56 con el escalón de árboles pedido (0 Mínimo, 1 Medio,
## 2 Alto, 3 Ultra), espera a que el bosque de cerca esté montado y deja en
## `user://capturas/bosque_<escalon>_{alto,bajo}.png` dos encuadres: el habitual y uno
## bajo, donde el relevo entre el 3D y el impostor cae en pantalla.

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var escalon := int(OS.get_environment("ESCALON")) if not OS.get_environment("ESCALON").is_empty() else 2
	Configuracion.graficos["arboles"] = escalon
	_preparar()
	var t := Time.get_ticks_msec()
	change_scene_to_file("res://scenes/demo_main.tscn")
	for _i in range(900):
		await process_frame
		if current_scene != null and current_scene.get("camera") != null \
				and current_scene.get("ui") != null:
			break
	var demo := current_scene
	var camera: Camera3D = demo.get("camera")
	if camera == null:
		print("no arrancó"); quit(1); return
	print("montar el mapa: %d ms" % (Time.get_ticks_msec() - t))
	var bosque := _buscar(demo, "Bosque") as Forest
	print("escalón %d · radio de cerca %.0f m · árboles %d" % [bosque.escalon, bosque.radio_de_cerca(), bosque.tree_count()])

	# A MEDIODÍA y sin la decisión del arranque encima: a las 6:00 con niebla la primera
	# captura salió de un marrón uniforme.
	var sim: Object = demo.get("sim")
	if sim != null:
		sim.set("hour", 12.0)
	var ui: Object = demo.get("ui")
	if ui != null and ui.get("barra") != null:
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	for _i in range(30):
		await process_frame
	# SOBRE LA CUEVA Y A DISTANCIA DE MIRAR, no a `min_distance`: desde que la cámara
	# baja hasta el suelo, eso son pocos metros, y la sonda la dejaba pegada al terreno
	# —el valle se veía un segundo y desaparecía, lo vio el usuario—.
	var casa: Vector3 = sim.get("home_position") if sim != null else camera.target_position
	camera.set_target(casa + Vector3(60.0, 0.0, 60.0))
	for encuadre: Array in [["alto", -38.0, 90.0], ["bajo", -12.0, 38.0]]:
		camera.orbit_angle_v = float(encuadre[1])
		camera.set_distance(float(encuadre[2]))
		for _i in range(90):
			await process_frame
		var ruta := "user://capturas/bosque_%d_%s.png" % [escalon, encuadre[0]]
		root.get_texture().get_image().save_png(ruta)
		print("  %s" % ProjectSettings.globalize_path(ruta))
	quit()


func _buscar(nodo: Node, nombre: String) -> Node:
	if nodo.name == nombre:
		return nodo
	for hijo: Node in nodo.get_children():
		var hallado := _buscar(hijo, nombre)
		if hallado != null:
			return hallado
	return null


func _preparar() -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))
