class_name TestTeclas
extends TestCase
## Las teclas que se pueden cambiar: INTERFAZ §11.
##
## Lo que se comprueba aqui es el catalogo, el choque, el guardado y —la que impide
## que esto se deshaga solo— que **ningun guion del juego pregunta por una tecla**.

## LA RUTA DE LAS PRUEBAS, nunca la del jugador. Ver [Configuracion.ruta].
const RUTA_DE_PRUEBAS := "user://pruebas/configuracion.cfg"

## El botón de cerrar del marco de una ventana de [GameUI]. Lo lleva toda ventana y no
## es una tecla: si no se aparta, la prueba de abajo lo toma por una escrita a mano.
const CRUZ_DE_CERRAR := "✕"

var _ruta_antes := ""


func suite_name() -> String:
	return "Teclas"


func before_each() -> void:
	if _ruta_antes.is_empty():
		_ruta_antes = Configuracion.ruta
	Configuracion.ruta = RUTA_DE_PRUEBAS
	if FileAccess.file_exists(RUTA_DE_PRUEBAS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA_DE_PRUEBAS))
	Teclas.por_defecto()


# --- el catalogo (tarea 1) ------------------------------------------------------

func test_cada_accion_sale_una_sola_vez() -> void:
	var vistos: Dictionary = {}
	for fila: Dictionary in Teclas.CATALOGO:
		var id: String = fila["id"]
		assert_false(vistos.has(id), "%s sale una sola vez" % id)
		vistos[id] = true
		assert_false(String(fila["rotulo"]).is_empty(), "%s tiene rótulo" % id)


func test_las_de_siempre_no_chocan_entre_ellas() -> void:
	# Si el catalogo naciera con un choque, la ventana avisaria del primer dia por algo
	# que no es culpa del jugador. Es justo lo que pasaba con F3, que era «velocidad x5»
	# y el panel de rendimiento a la vez.
	for fila: Dictionary in Teclas.CATALOGO:
		var chocan := Teclas.choca_con(fila["id"], fila["tecla"])
		assert_true(chocan.is_empty(), "%s no choca con nadie: %s" % [fila["id"], str(chocan)])


func test_dos_pantallas_distintas_pueden_compartir_tecla() -> void:
	# La R es la capa del minimapa en el valle y la ficha del sitio en el regional, y
	# nunca se pulsan en la misma pantalla.
	assert_eq(Teclas.tecla_de("capa_del_minimapa"), Teclas.tecla_de("ficha_del_sitio"),
		"las dos son la R de siempre")
	assert_true(Teclas.choca_con("capa_del_minimapa", KEY_R).is_empty(),
		"y no chocan: son pantallas distintas")
	assert_true(Teclas.choca_con("pausa", KEY_SPACE).is_empty(),
		"lo mismo el espacio, que pausa en el valle y resuelve en el regional")


func test_lo_de_todas_partes_choca_con_cualquiera() -> void:
	var chocan := Teclas.choca_con("avanzar", Teclas.tecla_de("numero_1"))
	assert_true(chocan.has("numero_1"),
		"el 1 vale en todas partes, así que sí choca con el valle: %s" % str(chocan))


func test_aplicar_deja_el_mapa_de_entrada_con_esas_teclas() -> void:
	Teclas.por_defecto()
	for fila: Dictionary in Teclas.CATALOGO:
		var id: String = fila["id"]
		assert_true(InputMap.has_action(id), "%s existe como acción" % id)
		var eventos := InputMap.action_get_events(id)
		assert_eq(eventos.size(), 1, "%s lleva una tecla y sólo una" % id)
		var tecla := eventos[0] as InputEventKey
		assert_eq(int(tecla.physical_keycode), int(fila["tecla"]),
			"%s es la de siempre" % id)


func test_cambiar_una_tecla_la_cambia_en_el_mapa() -> void:
	assert_true(Teclas.poner("avanzar", KEY_I), "avanzar se puede cambiar")
	assert_eq(Teclas.tecla_de("avanzar"), KEY_I, "avanzar es la I")
	var eventos := InputMap.action_get_events("avanzar")
	assert_eq(int((eventos[0] as InputEventKey).physical_keycode), int(KEY_I),
		"y el mapa de entrada lo sabe")


func test_escape_no_se_cambia() -> void:
	# Decisión del usuario (2026-09-17): ESC es la salida de todas las ventanas,
	# incluida la de cambiar teclas y su aviso de choque.
	assert_false(Teclas.poner("cerrar", KEY_J), "ESC no se cambia")
	assert_eq(Teclas.tecla_de("cerrar"), KEY_ESCAPE, "y sigue siendo ESC")


func test_intercambiar_deja_cada_una_con_la_del_otro() -> void:
	var de_avanzar := Teclas.tecla_de("avanzar")
	var de_acercar := Teclas.tecla_de("acercar")
	assert_true(Teclas.intercambiar("avanzar", "acercar"), "se intercambian")
	assert_eq(Teclas.tecla_de("avanzar"), de_acercar, "avanzar lleva la del acercar")
	assert_eq(Teclas.tecla_de("acercar"), de_avanzar, "y al revés")


func test_volver_a_las_de_siempre() -> void:
	Teclas.poner("avanzar", KEY_I)
	Teclas.poner("pausa", KEY_J)
	Teclas.por_defecto()
	assert_eq(Teclas.tecla_de("avanzar"), KEY_W, "avanzar vuelve a la W")
	assert_eq(Teclas.tecla_de("pausa"), KEY_SPACE, "y la pausa al espacio")


func test_una_tecla_fisica_dispara_su_accion_y_solo_la_suya() -> void:
	# EL CRITERIO DE LA SPEC: «con avanzar puesta en la I, la I mueve la cámara y la W
	# no». Se comprueba donde de verdad se decide —si el evento de una tecla es el de
	# una acción—, que es lo que preguntan la cámara, el valle y el regional.
	var la_w := InputEventKey.new()
	la_w.physical_keycode = KEY_W
	la_w.pressed = true
	assert_true(Teclas.es(la_w, "avanzar"), "la W es «avanzar»")
	assert_false(Teclas.es(la_w, "retroceder"), "y no es «retroceder»")
	Teclas.poner("avanzar", KEY_I)
	var la_i := InputEventKey.new()
	la_i.physical_keycode = KEY_I
	la_i.pressed = true
	assert_false(Teclas.es(la_w, "avanzar"), "cambiada, la W ya no avanza")
	assert_true(Teclas.es(la_i, "avanzar"), "y la I sí")


func test_preguntar_sin_haber_leido_la_configuracion_no_revienta() -> void:
	# Una sonda arranca `demo_main` sin pasar por el menú principal, así que nadie ha
	# leído la configuración: sin esto, la primera pregunta daba «request for nonexistent
	# InputMap action». Ver [Teclas.pulsada].
	Teclas.puestas = {}
	assert_false(Teclas.pulsada("avanzar"), "no está pulsada, pero contesta")
	assert_true(InputMap.has_action("avanzar"), "y de paso ha montado el mapa")


# --- se guardan y se leen (tarea 2) ---------------------------------------------

func test_dos_teclas_cambiadas_sobreviven_al_fichero() -> void:
	Teclas.poner("avanzar", KEY_I)
	Teclas.poner("fundar", KEY_G)
	Configuracion.guardar()
	Teclas.por_defecto()
	assert_eq(Teclas.tecla_de("avanzar"), KEY_W, "de momento, las de siempre")
	Configuracion.cargar()
	assert_eq(Teclas.tecla_de("avanzar"), KEY_I, "avanzar sigue en la I")
	assert_eq(Teclas.tecla_de("fundar"), KEY_G, "y fundar en la G")


func test_un_fichero_sin_teclas_da_las_de_siempre() -> void:
	# El de quien jugaba antes de que esto existiera.
	var fichero := ConfigFile.new()
	fichero.set_value("graficos", "nivel", int(Configuracion.Nivel.MEDIO))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RUTA_DE_PRUEBAS.get_base_dir()))
	fichero.save(RUTA_DE_PRUEBAS)
	Configuracion.cargar()
	assert_eq(Teclas.tecla_de("avanzar"), KEY_W, "avanzar es la W")
	assert_eq(Teclas.tecla_de("velocidad_x5"), KEY_F3, "y la x5 la F3")


func test_el_escape_del_fichero_no_manda() -> void:
	var fichero := ConfigFile.new()
	fichero.set_value("teclas", "cerrar", int(KEY_J))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(RUTA_DE_PRUEBAS.get_base_dir()))
	fichero.save(RUTA_DE_PRUEBAS)
	Configuracion.cargar()
	assert_eq(Teclas.tecla_de("cerrar"), KEY_ESCAPE,
		"editar el fichero a mano tampoco cambia ESC")


# --- ninguna tecla fija (tarea 7) -----------------------------------------------

func test_ningun_guion_del_juego_pregunta_por_una_tecla() -> void:
	# LA PRUEBA QUE IMPIDE QUE ESTO SE DESHAGA SOLO. La cámara miraba la W física y la
	# acción a la vez, y por eso cambiar la acción no servía de nada; si alguien vuelve
	# a poner un `KEY_` en un guion del juego, vuelve el mismo fallo sin dar un error de
	# compilación. Las sondas y las herramientas no cuentan: son instrumentos.
	var culpables: Array[String] = []
	_buscar_teclas("res://scripts", culpables)
	assert_true(culpables.is_empty(),
		"sólo `Teclas.gd` nombra teclas; las nombran además: %s" % ", ".join(culpables))


func _buscar_teclas(carpeta: String, culpables: Array[String]) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	for nombre: String in dir.get_directories():
		if nombre == "tests" or nombre == "tools":
			continue
		_buscar_teclas("%s/%s" % [carpeta, nombre], culpables)
	for nombre: String in dir.get_files():
		if not nombre.ends_with(".gd") or nombre == "Teclas.gd":
			continue
		var texto := FileAccess.get_file_as_string("%s/%s" % [carpeta, nombre])
		for linea: String in texto.split("\n"):
			var limpia := linea.strip_edges()
			if limpia.begins_with("#"):
				continue
			if limpia.contains("is_key_pressed") or _nombra_una_tecla(limpia):
				culpables.append("%s (%s)" % [nombre, limpia.substr(0, 48)])
				break


## Si la línea nombra una constante `KEY_…` del motor. `KEY_` a secas daría positivo en
## palabras que la llevan dentro, como `MONKEY_`.
func _nombra_una_tecla(linea: String) -> bool:
	var desde := 0
	while true:
		var i := linea.find("KEY_", desde)
		if i < 0:
			return false
		var antes := linea[i - 1] if i > 0 else " "
		if not (antes == "_" or antes.is_valid_identifier()):
			return true
		desde = i + 4
	return false


# --- la pestaña que las cambia (tarea 8) ----------------------------------------

func test_desde_la_ventana_se_cambia_una_tecla() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.esperar_la_tecla("avanzar")
	var que_paso := ventana.tecla_pulsada(KEY_I)
	var puesta := Teclas.tecla_de("avanzar")
	Teclas.por_defecto()
	Configuracion.cargar()
	var en_disco := Teclas.tecla_de("avanzar")
	ventana.free()
	assert_eq(que_paso, "puesta", "la tecla entra sin choque")
	assert_eq(puesta, KEY_I, "avanzar es la I")
	assert_eq(en_disco, KEY_I, "y quedó guardada al momento")


func test_la_ventana_avisa_del_choque_y_las_intercambia() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.esperar_la_tecla("avanzar")
	var que_paso := ventana.tecla_pulsada(Teclas.tecla_de("acercar"))
	var avisa := not ventana.choque.is_empty()
	var sin_tocar := Teclas.tecla_de("avanzar")
	ventana.resolver_el_choque(true)
	var de_avanzar := Teclas.tecla_de("avanzar")
	var de_acercar := Teclas.tecla_de("acercar")
	ventana.free()
	assert_eq(que_paso, "choque", "se ve el choque")
	assert_true(avisa, "y la ventana lo tiene pendiente de resolver")
	assert_eq(sin_tocar, KEY_W, "mientras no se resuelve, nada ha cambiado")
	assert_eq(de_avanzar, KEY_Q, "al aceptar, avanzar toma la del acercar")
	assert_eq(de_acercar, KEY_W, "y el acercar la de avanzar")


func test_cancelar_el_choque_no_toca_nada() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.esperar_la_tecla("avanzar")
	ventana.tecla_pulsada(Teclas.tecla_de("acercar"))
	ventana.resolver_el_choque(false)
	var de_avanzar := Teclas.tecla_de("avanzar")
	var de_acercar := Teclas.tecla_de("acercar")
	var limpio := ventana.choque.is_empty()
	ventana.free()
	assert_eq(de_avanzar, KEY_W, "avanzar sigue en la W")
	assert_eq(de_acercar, KEY_Q, "y el acercar en la Q")
	assert_true(limpio, "y no queda choque pendiente")


func test_la_misma_tecla_que_ya_tenia_no_es_un_choque() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.esperar_la_tecla("avanzar")
	var que_paso := ventana.tecla_pulsada(KEY_W)
	ventana.free()
	assert_eq(que_paso, "nada", "volver a pulsar la suya no avisa de nada")


func test_el_boton_de_siempre_las_devuelve_todas() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.esperar_la_tecla("avanzar")
	ventana.tecla_pulsada(KEY_I)
	ventana.esperar_la_tecla("fundar")
	ventana.tecla_pulsada(KEY_G)
	ventana.teclas_de_siempre()
	var de_avanzar := Teclas.tecla_de("avanzar")
	var de_fundar := Teclas.tecla_de("fundar")
	Configuracion.cargar()
	var en_disco := Teclas.tecla_de("avanzar")
	ventana.free()
	assert_eq(de_avanzar, KEY_W, "avanzar vuelve a la W")
	assert_eq(de_fundar, KEY_F, "y fundar a la F")
	assert_eq(en_disco, KEY_W, "y el fichero también")


func test_la_pestana_de_controles_enseña_la_tecla_puesta() -> void:
	var ventana := VentanaDeConfiguracion.new()
	ventana.esperar_la_tecla("avanzar")
	ventana.tecla_pulsada(KEY_I)
	var textos := _textos_de(ventana)
	ventana.free()
	assert_true(textos.has("I"), "la pestaña enseña la I: %s" % str(textos.slice(0, 12)))
	assert_false(textos.has("W"), "y ya no la W")


func test_escape_sale_en_la_pestana_pero_no_se_pulsa() -> void:
	var ventana := VentanaDeConfiguracion.new()
	var apagados: Array[String] = []
	_botones_apagados(ventana, apagados)
	ventana.free()
	assert_true(apagados.has("Escape"),
		"el botón de ESC está apagado: %s" % str(apagados))


## Los textos de todos los rótulos y botones de una ventana.
func _textos_de(nodo: Node) -> Array[String]:
	var salida: Array[String] = []
	if nodo is Label:
		salida.append((nodo as Label).text)
	elif nodo is Button:
		salida.append((nodo as Button).text)
	for hijo: Node in nodo.get_children():
		salida.append_array(_textos_de(hijo))
	return salida


func _botones_apagados(nodo: Node, dentro: Array[String]) -> void:
	if nodo is Button and (nodo as Button).disabled:
		dentro.append((nodo as Button).text)
	for hijo: Node in nodo.get_children():
		_botones_apagados(hijo, dentro)


# --- la ventana del juego dice la verdad (tarea 9) ------------------------------

func test_la_ventana_del_juego_enseña_las_teclas_puestas() -> void:
	# Antes se pintaba de una lista a mano, y la lista decía lo que le parecía: anunciaba
	# «B — modo construcción», y en el juego no hay ninguna B.
	Teclas.poner("pausa", KEY_J)
	var ui := GameUI.new()
	ui.show_controls()
	var textos := _textos_de(ui)
	ui.free()
	Teclas.por_defecto()
	assert_true(textos.has("J"), "enseña la J de la pausa: %s" % str(textos.slice(0, 16)))
	for texto: String in textos:
		assert_false(texto == "B", "y ninguna fila anuncia una B que no existe")


func test_la_ventana_del_juego_no_nombra_teclas_de_su_cosecha() -> void:
	# Cada tecla que enseña sale del catálogo, del ratón o es un rótulo. Si alguien
	# vuelve a escribir una a mano, esta prueba la caza.
	var ui := GameUI.new()
	ui.show_controls()
	var textos := _textos_de(ui)
	ui.free()
	var del_catalogo: Array[String] = []
	for fila: Dictionary in Teclas.CATALOGO:
		del_catalogo.append(Teclas.nombre_de_la_tecla(Teclas.tecla_de(String(fila["id"]))))
	var sueltas: Array[String] = []
	for texto: String in textos:
		# Las teclas se pintan solas en su columna: un texto de una o dos letras, o el
		# nombre de una tecla del motor. Un rótulo es una frase.
		if texto.length() > 3 or texto.is_empty() or texto.contains(" "):
			continue
		# La cruz de cerrar es el marco de la ventana, no una tecla.
		if texto == CRUZ_DE_CERRAR:
			continue
		if not del_catalogo.has(texto):
			sueltas.append(texto)
	assert_true(sueltas.is_empty(),
		"ninguna tecla escrita a mano en la ventana: %s" % str(sueltas))
