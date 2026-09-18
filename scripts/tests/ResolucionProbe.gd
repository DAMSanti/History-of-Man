extends SceneTree
## ¿CUÁNTO GANA DIBUJAR A MENOS? INTERFAZ §16, tarea 5.
##
## El criterio que puso el usuario para dar por hecho el selector de resolución es que
## **gane fotogramas, medido**. Esto monta un valle, se queda quieto en un sitio y mide
## **ms de GPU y fps en cada escalón**, del que más dibuja al que menos.
##
##   godot --path . --script res://scripts/tests/ResolucionProbe.gd
##
##   SITIO=56    en qué valle se mide
##   CUADROS=90  cuántos cuadros por escalón, sin contar los de asentarse
##
## **La ventana se fija a 1080p**: las sondas con ventana abren a la resolución del
## escritorio —3 651 × 2 054 en la máquina del usuario— y el presupuesto de GPU está
## escrito a 1080p (GRAFICOS §7). Sin fijarla, las cifras no se pueden comparar con nada.

const VENTANA := Vector2i(1920, 1080)
## Los cuadros que se dejan pasar tras cambiar de escalón: el motor rehace los búferes del
## render y el primero sale caro.
const ASENTARSE := 30


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/resolucion"
	Configuracion.ruta = "user://sondas/resolucion/configuracion.cfg"
	var id := 56
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))
	var cuadros := 90
	if not OS.get_environment("CUADROS").is_empty():
		cuadros = int(OS.get_environment("CUADROS"))

	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("ResolucionProbe: no hay sitio %d" % id)
		quit(1)
		return
	Expedition.site = sitio
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % id

	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# EN MODO VENTANA ANTES DE REDIMENSIONAR: el proyecto arranca maximizado y ahí
	# `window_set_size` no hace nada —lo mismo que le pasa al jugador, que es de lo que va
	# todo esto—. Sin esto la primera corrida midió a 3 840 x 2 054 (2026-09-18).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VENTANA)
	get_root().size = VENTANA

	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	for i in range(240):
		await process_frame

	# Quieto: sin la banda andando ni el sol moviéndose entre medidas, o se mide otra cosa.
	paused = true
	var camara: Node = demo.get("camera")
	if camara != null:
		camara.process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	print("=== A CUÁNTO SE DIBUJA · valle %d · ventana %d x %d ===" % [id, VENTANA.x, VENTANA.y])
	print("%-14s %-9s %8s %8s %8s" % ["dibujo", "escala", "GPU ms", "fps", "UI"])
	for escala: float in Configuracion.ESCALAS_DE_DIBUJO:
		Configuracion.poner_ajuste("escala", escala)
		Configuracion.aplicar_graficos(self)
		for i in range(ASENTARSE):
			await process_frame
		var gpu := 0.0
		var cpu := 0.0
		for i in range(cuadros):
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu /= float(cuadros)
		cpu /= float(cuadros)
		var dibujo := Configuracion.dibujo_con(escala, Vector2i(get_root().size))
		# LA INTERFAZ NO SE ESCALA: el tamaño de la capa 2D se queda en el de la ventana,
		# dibuje el mundo a lo que dibuje. Es la otra mitad del criterio.
		var interfaz := "%d x %d" % [get_root().size.x, get_root().size.y]
		print("%-14s %-9s %8.2f %8.1f %8s" % ["%d x %d" % [dibujo.x, dibujo.y],
			"%d %%" % int(round(escala * 100.0)), gpu,
			1000.0 / maxf(gpu + cpu, 0.001), interfaz])
	quit()
