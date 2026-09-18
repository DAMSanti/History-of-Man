extends SceneTree
## ¿DÓNDE ESTÁ LA BANDA? Sonda de depuración: «no se ven los miembros de la banda».
##
## La sonda de coste (`BandaProbe`) sí los dibujaba, así que la diferencia está en algo que
## ella no hace: **dejar correr la partida**. Ésta la deja correr y cuenta, cada pocos
## segundos, las cuatro cifras que tienen que cuadrar y no siempre cuadran:
##
##   gente    · cuántas personas tiene la simulación
##   huecos   · cuántas entradas tiene `_bodies`, que es lo que indexa los cuerpos
##   cuerpos  · cuántos nodos [Cuerpo] hay montados
##   a la vista · cuántos de ésos están visibles y por encima del suelo
##
## Si «gente» y «huecos» se separan, hay alguien sin cuerpo. Si «a la vista» cae a cero, es
## que algo los apaga o los entierra.
##
##   godot --path . --script res://scripts/tests/BandaViveProbe.gd
##
##   SITIO=56       en qué valle
##   SEGUNDOS=40    cuánto se deja correr
##   VELOCIDAD=3    a qué escala de tiempo

const VENTANA := Vector2i(1280, 720)


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/banda_vive"
	Configuracion.ruta = "user://sondas/banda_vive/configuracion.cfg"
	var id := 56
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))
	var segundos := 40.0
	if not OS.get_environment("SEGUNDOS").is_empty():
		segundos = float(OS.get_environment("SEGUNDOS"))
	var velocidad := 3.0
	if not OS.get_environment("VELOCIDAD").is_empty():
		velocidad = float(OS.get_environment("VELOCIDAD"))

	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("BandaViveProbe: no hay sitio %d" % id)
		quit(1)
		return
	Expedition.site = sitio
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % id

	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VENTANA)
	get_root().size = VENTANA

	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	for i in range(240):
		await process_frame

	var sim: Object = demo.get("sim")
	var crowd := _buscar(demo, "BandaCrowd") as Node3D
	if sim == null or crowd == null:
		print("BandaViveProbe: falta sim o banda")
		quit(1)
		return
	Engine.time_scale = velocidad

	# A qué distancia arranca la cámara: es lo que decide si una persona son dos píxeles o
	# doscientos, y por tanto si «no se ven» es un fallo o es el encuadre.
	var cam0: Node3D = demo.get("camera")
	var gente1: Array = sim.get("people")
	if cam0 != null and not gente1.is_empty():
		var d: float = cam0.global_position.distance_to(gente1[0].position as Vector3)
		# 1,70 m de persona, con el campo de visión por defecto, a 1080p.
		print("cámara de entrada: %.0f m · una persona mide ahí %.1f px de alto a 1080p" % [
			d, 1196.0 / maxf(d, 0.001)])

	print("=== ¿DÓNDE ESTÁ LA BANDA? · valle %d · x%.0f ===" % [id, velocidad])
	print("%8s %8s %8s %8s %8s %s" % ["reloj", "gente", "huecos", "cuerpos",
		"a la vista", "hora"])

	var reloj := 0.0
	var siguiente := 0.0
	while reloj < segundos:
		await process_frame
		reloj += get_root().get_process_delta_time()
		if reloj < siguiente:
			continue
		siguiente = reloj + 4.0
		_contar(sim, crowd, reloj)

	_contar(sim, crowd, reloj)
	# DOS FOTOS: la de lejos es la que ve el jugador al entrar, y la de cerca separa «no
	# están» de «no se ven». Con la de lejos sola no se puede decidir nada.
	await _foto("lejos")
	var gente0: Array = sim.get("people")
	var camara: Node = demo.get("camera")
	if camara != null and not gente0.is_empty():
		var quien: Vector3 = gente0[0].position
		camara.call("mirar_a", quien)
		camara.call("set_distance", 8.0)
		var c3 := camara as Node3D
		print("cámara a %.1f m de la primera persona (%.0f, %.0f, %.0f)" % [
			c3.global_position.distance_to(quien), quien.x, quien.y, quien.z])
		for i in range(40):
			await process_frame
		_contar(sim, crowd, reloj)
		await _foto("cerca")
	var foto := get_root().get_texture().get_image()
	if foto != null:
		DirAccess.make_dir_recursive_absolute("user://sondas/banda_vive")
		foto.save_png("user://sondas/banda_vive/banda.png")
		print("foto: %s" % ProjectSettings.globalize_path(
			"user://sondas/banda_vive/banda.png"))
	quit()


func _foto(mote: String) -> void:
	await process_frame
	var img := get_root().get_texture().get_image()
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute("user://sondas/banda_vive")
	var ruta := "user://sondas/banda_vive/%s.png" % mote
	img.save_png(ruta)
	print("foto %s: %s" % [mote, ProjectSettings.globalize_path(ruta)])


func _contar(sim: Object, crowd: Node3D, reloj: float) -> void:
	var gente: Array = sim.get("people")
	var huecos: Array = sim.get("_bodies")
	var cuerpos := 0
	var a_la_vista := 0
	for hijo in crowd.get_children():
		if not (hijo is Cuerpo):
			continue
		cuerpos += 1
		var c := hijo as Node3D
		if c.visible and c.position.y > -500.0:
			a_la_vista += 1
	print("%8.1f %8d %8d %8d %8d   %s" % [reloj, gente.size(), huecos.size(),
		cuerpos, a_la_vista, str(sim.get("hora_del_dia"))])


func _buscar(nodo: Node, clase: String) -> Node:
	if clase == "BandaCrowd" and nodo is BandaCrowd:
		return nodo
	for h in nodo.get_children():
		var f := _buscar(h, clase)
		if f != null:
			return f
	return null
