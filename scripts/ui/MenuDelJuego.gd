class_name MenuDelJuego
extends CanvasLayer
## El modal de ESC: seguir, guardar, guardar como, cargar y salir.
##
## Spec: `docs/INTERFAZ.md` §7. El mismo en las dos pantallas de una partida —el
## valle y el mapa regional—, porque escribirlo dos veces sería la misma regla
## en dos sitios.
##
## **Para el reloj mientras está abierto** (SPECS §4.6, como cualquier decisión
## del juego): un menú que se consulta con la simulación corriendo es una forma
## de perder gente mientras lees. Y guardar con el reloj parado es además lo que
## hace que la instantánea no se tome a mitad de un paso (SPECS §3.2).

## Encima de todo lo demás. La interfaz del juego va en capas 10 y 11 —ver
## [DemoMain] y el minimapa—; esto tiene que tapar las dos.
const CAPA := 20

var _sim: SettlementSim = null
var _fauna: WildlifeHerds = null
var _cuevas: Array = []
var _reloj_de_antes := 1.0

var _columna: VBoxContainer
var _aviso: Label
var _nombre: LineEdit
var _lista: ListaDePartidas
var _confirmar_nombre := ""


## Lo monta quien lo usa, con lo que haga falta para guardar. En el mapa
## regional no hay simulación: se guarda lo que ya hay en la carpeta de trabajo.
func montar(sim: SettlementSim = null, fauna: WildlifeHerds = null,
		cuevas: Array = []) -> void:
	_sim = sim
	_fauna = fauna
	_cuevas = cuevas


func _ready() -> void:
	layer = CAPA
	var fondo := ColorRect.new()
	# Oscurece lo de detrás: deja ver dónde estabas y deja claro que está parado.
	fondo.color = Color(0.0, 0.0, 0.0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", UISkin.window_box())
	marco.theme = UISkin.build_theme()
	marco.custom_minimum_size = Vector2(620, 0)
	centro.add_child(marco)

	_columna = VBoxContainer.new()
	_columna.add_theme_constant_override("separation", 8)
	marco.add_child(_columna)
	_menu()


func _limpiar() -> void:
	for hijo: Node in _columna.get_children():
		hijo.queue_free()
	_confirmar_nombre = ""


func _titulo(texto: String) -> void:
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", UISkin.OCHRE)
	_columna.add_child(label)


func _boton(texto: String, que_hace: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(300, 30)
	boton.pressed.connect(que_hace)
	_columna.add_child(boton)
	return boton


# ------------------------------------------------------------- el menú --

func _menu() -> void:
	_limpiar()
	_titulo("La partida")

	var donde := Label.new()
	donde.text = _estado()
	donde.add_theme_color_override("font_color", UISkin.INK_SOFT)
	_columna.add_child(donde)
	_columna.add_child(HSeparator.new())

	_boton("Seguir jugando", cerrar)
	# EN DEBUG NO SE GUARDA NADA (INTERFAZ §14): ni guardar, ni cargar encima, ni el aviso
	# de «hay cambios sin guardar» al salir.
	if not ModoDebug.activo:
		_boton("Guardar", _guardar_rapido)
		_boton("Guardar como…", _pedir_nombre)
		_boton("Cargar", _abrir_lista)
	_boton("Configuración", func() -> void: abrir_configuracion())
	_boton("Salir al menú principal", func() -> void: _salir(false))
	_boton("Salir del juego", func() -> void: _salir(true))

	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 12)
	_aviso.add_theme_color_override("font_color", UISkin.GREEN)
	_aviso.visible = false
	_columna.add_child(_aviso)


func _estado() -> String:
	var nombre := Partidas.nombre_abierto()
	var como := "«%s»" % nombre if not nombre.is_empty() \
		else "sin guardar todavía"
	return "%s  ·  %s" % [como, "con cambios sin guardar"
		if Partidas.hay_cambios() else "al día"]


func _decir(texto: String, mal := false) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso.add_theme_color_override("font_color",
		UISkin.ALARM if mal else UISkin.GREEN)
	_aviso.visible = true


# ------------------------------------------------------------- guardar --

## Guardar a secas: con el nombre que ya tenga. La primera vez no lo tiene, así
## que se pide —que es lo que dice la spec: el nombre se pide la primera vez que
## se guarda—.
func _guardar_rapido() -> void:
	if Partidas.nombre_abierto().is_empty():
		_pedir_nombre()
		return
	var fallo := Partidas.guardar_donde_estaba(_sim, _fauna, _cuevas)
	if fallo.is_empty():
		_decir("Guardada como «%s»." % Partidas.nombre_abierto())
	else:
		_decir("No se ha podido guardar: %s" % fallo, true)


func _pedir_nombre() -> void:
	_limpiar()
	_titulo("¿Cómo se llama esta partida?")
	_nombre = LineEdit.new()
	_nombre.text = Partidas.nombre_abierto()
	_nombre.placeholder_text = "La cueva del río"
	_nombre.custom_minimum_size = Vector2(300, 0)
	_columna.add_child(_nombre)
	_nombre.grab_focus()

	_aviso = Label.new()
	_aviso.add_theme_font_size_override("font_size", 12)
	_aviso.visible = false
	_columna.add_child(_aviso)

	_boton("Guardar", _guardar_con_nombre)
	_boton("Volver", _menu)


func _guardar_con_nombre() -> void:
	var como := _nombre.text.strip_edges()
	if como.is_empty():
		_decir("Una partida guardada necesita un nombre.", true)
		return
	# Sobrescribir pregunta: el segundo clic es el que manda.
	if Partidas.existe(como) and _confirmar_nombre != como:
		_confirmar_nombre = como
		_decir("Ya hay una partida llamada «%s». Pulsa otra vez para "
			% como + "escribir encima.", true)
		return
	var fallo := Partidas.guardar(como, _sim, _fauna, _cuevas)
	if fallo.is_empty():
		_menu()
		_decir("Guardada como «%s»." % como)
	else:
		_decir("No se ha podido guardar: %s" % fallo, true)


# -------------------------------------------------------------- cargar --

func _abrir_lista() -> void:
	_limpiar()
	_titulo("Cargar una partida")
	_lista = ListaDePartidas.new()
	_lista.sitios = SiteSet.comarca()
	_lista.elegida.connect(_cargar)
	_columna.add_child(_lista)
	_lista.refrescar()
	_boton("Volver", _menu)


func _cargar(id: String) -> void:
	# La pantalla antes que leer. Ver [MenuPrincipal._cargar].
	Carga.abrir(get_tree(), "Retomando la partida")
	await get_tree().process_frame
	var fallo := Partidas.cargar(id, SiteSet.comarca())
	if not fallo.is_empty():
		Carga.cerrar()
		_decir("No se ha podido cargar: %s" % fallo, true)
		return
	Expedition.retomando = true
	Carga.cambiar_de_escena(get_tree(), Expedition.LOCAL_SCENE)


# --------------------------------------------------------------- salir --

## Salir avisa si hay cambios, y **no los pierde**: decisión del usuario del
## 2026-09-13. Lo que no se ha guardado a mano se guarda solo, con su nombre o
## con [Partidas.SIN_TITULO], y aparece en la lista como una partida más.
func _salir(del_juego: bool) -> void:
	if ModoDebug.activo or not Partidas.hay_cambios():
		_irse(del_juego)
		return
	_limpiar()
	_titulo("Hay cambios sin guardar")
	var texto := Label.new()
	var nombre := Partidas.nombre_abierto()
	texto.text = ("Al salir se guardará sola en «%s»."
		% (nombre if not nombre.is_empty() else Partidas.SIN_TITULO)
		+ "\nSi prefieres ponerle otro nombre, hazlo ahora.")
	texto.add_theme_color_override("font_color", UISkin.INK_SOFT)
	_columna.add_child(texto)

	_aviso = Label.new()
	_aviso.visible = false
	_columna.add_child(_aviso)

	_boton("Guardar y salir", func() -> void:
		var fallo := Partidas.guardar_donde_estaba(_sim, _fauna, _cuevas)
		if fallo.is_empty():
			_irse(del_juego)
		else:
			_decir("No se ha podido guardar: %s" % fallo, true))
	_boton("Ponerle nombre", _pedir_nombre)
	_boton("Volver a la partida", _menu)


func _irse(del_juego: bool) -> void:
	# El reloj se devuelve antes de nada: si el juego se cierra o la escena
	# cambia con `time_scale` a cero, la partida siguiente arrancaría parada.
	_devolver_el_reloj()
	if del_juego:
		get_tree().quit()
		return
	# Al menú principal la partida no sigue: lo guardado ya está en disco.
	Campamentos.vaciar()
	# Y del Debug se sale devolviendo lo del jugador. Ver [ModoDebug.salir].
	ModoDebug.salir()
	get_tree().change_scene_to_file(Expedition.MENU_SCENE)


# ------------------------------------------------------ abrir y cerrar --

## Abre el modal parando el reloj. Devuelve si se ha abierto: lo llama ESC, y
## ESC sólo llega aquí cuando no hay ventana que cerrar. Ver [DemoMain._tecla].
func abrir() -> bool:
	if visible:
		return false
	visible = true
	if _sim != null:
		_reloj_de_antes = _sim.time_scale
		_sim.time_scale = 0.0
	_menu()
	return true


func cerrar() -> void:
	visible = false
	_devolver_el_reloj()


func _devolver_el_reloj() -> void:
	if _sim != null and _sim.time_scale == 0.0:
		_sim.time_scale = _reloj_de_antes


func esta_abierto() -> bool:
	return visible


## La ventana de configuración abierta, o null.
var configuracion: VentanaDeConfiguracion = null


## Abre la ventana de configuración encima del menú, con el reloj parado como todo
## el menú. La misma que abre el menú principal —ver
## [MenuPrincipal.abrir_configuracion]—.
func abrir_configuracion() -> VentanaDeConfiguracion:
	if configuracion != null:
		return configuracion
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	configuracion = VentanaDeConfiguracion.new()
	configuracion.cerrada.connect(func() -> void:
		centro.queue_free()
		configuracion = null)
	centro.add_child(configuracion)
	return configuracion
