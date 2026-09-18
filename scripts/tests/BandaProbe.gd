extends SceneTree
## ¿CUÁNTO CUESTA LA BANDA? GRAFICOS §5.1, tareas 1 y 10.
##
## El criterio que puso el usuario para dar por buena la banda nueva es que **su máquina la
## mueva**, y la spec lo concreta en no subir más de un 15 % sobre lo que cuesta hoy. Esto
## es la línea base y, al final del trabajo, la misma medida con todo puesto.
##
## Mide **con la banda dibujada y sin ella**, que es la única forma de separar lo suyo del
## terreno: en el valle del sitio 56 el terreno solo se lleva 18,6 de los 28,7 ms de GPU
## (GRAFICOS §1), así que mirar el total no dice nada de veinticinco personas.
##
##   godot --path . --script res://scripts/tests/BandaProbe.gd
##
##   SITIO=56     en qué valle se mide
##   CUADROS=90   cuántos cuadros por medida, sin contar los de asentarse
##
## **La ventana se fija a 1080p** por lo mismo que en `ResolucionProbe`: las sondas con
## ventana abren a la resolución del escritorio y el presupuesto de GPU está escrito a
## 1080p (GRAFICOS §1).

const VENTANA := Vector2i(1920, 1080)
## Los cuadros que se dejan pasar tras esconder o enseñar la banda: el motor rehace lo suyo
## y el primero sale caro. Mismo número que `ResolucionProbe`, por comparar peras con peras.
const ASENTARSE := 30
## A qué distancia se pone la cámara del centro de la banda, en metros. Lo bastante cerca
## para que quepan las veinticinco personas y lo bastante lejos para que no llenen la
## pantalla: es la distancia a la que se juega mirando trabajar a la gente.
const DISTANCIA_M := 35.0
## Lo que el presupuesto de fotograma le da a «Personajes» a 1080p en la 1070
## (GRAFICOS §1). Es el listón de verdad de este trabajo: ver el porqué abajo.
const PRESUPUESTO_MS := 2.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/banda"
	Configuracion.ruta = "user://sondas/banda/configuracion.cfg"
	var id := 56
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))
	var cuadros := 90
	if not OS.get_environment("CUADROS").is_empty():
		cuadros = int(OS.get_environment("CUADROS"))
	var lejos := DISTANCIA_M
	if not OS.get_environment("DISTANCIA").is_empty():
		lejos = float(OS.get_environment("DISTANCIA"))

	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("BandaProbe: no hay sitio %d" % id)
		quit(1)
		return
	Expedition.site = sitio
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % id

	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# En modo ventana antes de redimensionar: maximizado, `window_set_size` no hace nada
	# -el fallo que arregló INTERFAZ §16-.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VENTANA)
	get_root().size = VENTANA

	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	for i in range(240):
		await process_frame

	var sim: Object = demo.get("sim")
	var camara: Node = demo.get("camera")
	var crowd := _buscar_la_banda(demo)
	if sim == null or camara == null or crowd == null:
		print("BandaProbe: falta sim, cámara o banda")
		quit(1)
		return

	var gente: Array = sim.get("people")
	var centro := Vector3.ZERO
	for persona in gente:
		centro += persona.position as Vector3
	if not gente.is_empty():
		centro /= float(gente.size())
	camara.call("mirar_a", centro)
	camara.call("set_distance", lejos)

	# Quieto: sin la banda andando ni el sol moviéndose entre las dos medidas, o se mide
	# otra cosa. La animación de la banda NO se para con esto -sale del TIME del shader-,
	# que es justo lo que se quiere medir.
	paused = true
	camara.process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	print("=== QUÉ CUESTA LA BANDA · valle %d · ventana %d x %d ===" % [
		id, VENTANA.x, VENTANA.y])
	print("%d personas, a %.0f m de la cámara" % [gente.size(), lejos])
	print("")
	print("%-12s %9s %9s %9s %9s" % ["", "GPU ms", "CPU ms", "fps", "VRAM MB"])

	var con := await _medir(vp, cuadros)
	# LA FOTO NO ES ADORNO: una medida de una banda que no se ve en pantalla vale cero, y
	# aquí la diferencia entre las dos filas es de décimas. Se mira antes de creerse nada.
	await process_frame
	var foto := get_root().get_texture().get_image()
	if foto != null:
		DirAccess.make_dir_recursive_absolute("user://sondas/banda")
		foto.save_png("user://sondas/banda/banda.png")
		print("foto: %s" % ProjectSettings.globalize_path("user://sondas/banda/banda.png"))
	crowd.visible = false
	var sin := await _medir(vp, cuadros)
	crowd.visible = true

	_fila("con banda", con)
	_fila("sin banda", sin)
	print("")
	# EL LISTÓN ES EL PRESUPUESTO, NO UN PORCENTAJE. La spec pedía no subir más de un 15 %
	# sobre lo de hoy, y al medirlo la primera vez se vio que no vale: la banda cuesta 0,15
	# y 0,21 ms de GPU en dos corridas, así que el 15 % -0,03 ms- queda POR DEBAJO del
	# ruido entre corridas. Lo que sí significa algo es la fila «Personajes» del
	# presupuesto de GRAFICOS §1. Corregido el 2026-09-18, ver §5.1.
	print("LA BANDA: %.2f ms de GPU y %.2f ms de CPU · el presupuesto de §1 es %.1f ms" % [
		con.gpu - sin.gpu, con.cpu - sin.cpu, PRESUPUESTO_MS])
	quit()


func _fila(nombre: String, m: Dictionary) -> void:
	print("%-12s %9.2f %9.2f %9.1f %9.0f" % [nombre, m.gpu, m.cpu,
		1000.0 / maxf(m.gpu + m.cpu, 0.001), m.vram])


func _medir(vp: RID, cuadros: int) -> Dictionary:
	for i in range(ASENTARSE):
		await process_frame
	var gpu := 0.0
	var cpu := 0.0
	for i in range(cuadros):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	return {
		"gpu": gpu / float(cuadros),
		"cpu": cpu / float(cuadros),
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}


## La banda no cuelga de un sitio fijo de la escena -la monta `SettlementSim`-, así que se
## busca por tipo en vez de por ruta.
func _buscar_la_banda(raiz: Node) -> BandaCrowd:
	if raiz is BandaCrowd:
		return raiz as BandaCrowd
	for hijo in raiz.get_children():
		var encontrada := _buscar_la_banda(hijo)
		if encontrada != null:
			return encontrada
	return null
