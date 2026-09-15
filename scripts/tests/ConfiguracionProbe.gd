extends SceneTree
## Se aplica al abrir el juego: INTERFAZ §8, en dos procesos.
##
## El primero escribe una configuración; el segundo arranca la primera pantalla
## del juego —el menú principal— y mira el motor: el modo y el tamaño de la
## ventana, la sincronización, el tope de fotogramas y el escalón de árboles. Dos procesos porque lo que
## se prueba es lo que queda en disco y lo que hace un juego que arranca, no el
## estado que la sonda deja en memoria.
##
## Con su propia ruta, nunca la del jugador:
##
##   CONFIGURACION=user://sondas/configuracion_sonda.cfg MODO=escribir \
##     godot --headless --path . --script res://scripts/tests/ConfiguracionProbe.gd
##   CONFIGURACION=user://sondas/configuracion_sonda.cfg MODO=comprobar \
##     godot --path . --script res://scripts/tests/ConfiguracionProbe.gd

const RESOLUCION := Vector2i(1280, 720)
const TOPE := 30
## Un escalón de árboles que no es el de Bajo: así se ve que se guarda el suelto.
const ARBOLES := 2


func _init() -> void:
	if Configuracion.ruta == Configuracion.RUTA:
		print("MAL: sin CONFIGURACION= esta sonda escribiría la del jugador")
		quit(1)
		return
	match OS.get_environment("MODO"):
		"escribir":
			Configuracion.por_defecto()
			Configuracion.modo = Configuracion.Modo.VENTANA
			Configuracion.resolucion = RESOLUCION
			Configuracion.vsync = false
			Configuracion.tope = TOPE
			Configuracion.poner_nivel(Configuracion.Nivel.BAJO)
			Configuracion.poner_ajuste("arboles", ARBOLES)
			var error := Configuracion.guardar()
			print("escrita en %s: %s" % [Configuracion.ruta, "ok" if error == OK else "MAL %d" % error])
			quit(0 if error == OK else 1)
		"comprobar":
			change_scene_to_file("res://scenes/menu_principal.tscn")
			for i in range(90):
				await process_frame
			var fallos: Array[String] = []
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				fallos.append("modo %d" % DisplayServer.window_get_mode())
			if DisplayServer.window_get_size() != RESOLUCION:
				fallos.append("tamaño %s" % str(DisplayServer.window_get_size()))
			if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
				fallos.append("sincronización %d" % DisplayServer.window_get_vsync_mode())
			if Engine.max_fps != TOPE:
				fallos.append("tope %d" % Engine.max_fps)
			if Configuracion.nivel != Configuracion.Nivel.PERSONALIZADO:
				fallos.append("nivel %d" % Configuracion.nivel)
			if int(Configuracion.graficos.get("arboles", -1)) != ARBOLES:
				fallos.append("árboles %s" % str(Configuracion.graficos.get("arboles")))
			print("al abrir: %s" % ("TODO BIEN · ventana %s, sin sincronizar, tope %d, Bajo con árboles Alto" % [
				str(RESOLUCION), TOPE] if fallos.is_empty() else "MAL %s" % str(fallos)))
			quit(0 if fallos.is_empty() else 1)
		_:
			print("MODO=escribir o MODO=comprobar")
			quit(1)
