class_name MenuPrincipal
extends Control
## La primera pantalla del juego: nueva partida, cargar, salir.
##
## Spec: `docs/INTERFAZ.md` §7. Antes el juego arrancaba cayendo directamente en
## el mapa regional, así que la primera pantalla de una partida nueva y la de
## una empezada eran la misma y no había forma de decir «quiero seguir la de
## ayer». Y del juego no se salía: se cerraba la ventana.
##
## **Aquí no hay simulación.** El menú monta botones y lee cabeceras de disco;
## la partida no empieza hasta que se pulsa. Es el criterio 1 de la spec.

## El catálogo de emplazamientos, para que la lista diga el nombre del valle y
## no su número.
const SITIOS := "res://data/sites/cantabria_sites.res"

var _lista: ListaDePartidas
var _panel_de_carga: PanelContainer


## La ventana de configuración abierta, o null. Ver [abrir_configuracion].
var configuracion: VentanaDeConfiguracion = null

## Si ya se aplicó la configuración guardada en este proceso: se aplica una vez,
## al abrir el juego, y no cada vez que se vuelve al menú.
static var _configuracion_aplicada := false


func _ready() -> void:
	# LA CONFIGURACIÓN DEL EQUIPO, ANTES DE PINTAR NADA: ésta es la primera pantalla
	# del juego (INTERFAZ §8). Una vez por proceso.
	if not _configuracion_aplicada:
		_configuracion_aplicada = true
		Configuracion.cargar()
		Configuracion.aplicar_pantalla()
		Configuracion.aplicar_sonido()
		Configuracion.aplicar_graficos(get_tree())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UISkin.build_theme()

	var fondo := ColorRect.new()
	fondo.color = UISkin.GROUND
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	centro.add_child(columna)

	var titulo := Label.new()
	titulo.text = "HISTORY OF MAN"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 34)
	titulo.add_theme_color_override("font_color", UISkin.OCHRE)
	columna.add_child(titulo)

	var pie := Label.new()
	pie.text = "Una banda del Magdaleniense, en la Cantabria de hace 15 000 años"
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.add_theme_color_override("font_color", UISkin.INK_SOFT)
	columna.add_child(pie)

	columna.add_child(HSeparator.new())

	_boton(columna, "Nueva partida", _nueva)
	_boton(columna, "Cargar", _abrir_lista)
	_boton(columna, "Configuración", func() -> void: abrir_configuracion())
	_boton(columna, "Salir del juego", _salir)

	_panel_de_carga = PanelContainer.new()
	_panel_de_carga.add_theme_stylebox_override("panel", UISkin.window_box())
	_panel_de_carga.visible = false
	_panel_de_carga.custom_minimum_size = Vector2(620, 0)
	columna.add_child(_panel_de_carga)

	var dentro := VBoxContainer.new()
	dentro.add_theme_constant_override("separation", 6)
	_panel_de_carga.add_child(dentro)

	_lista = ListaDePartidas.new()
	_lista.sitios = load(SITIOS) as SiteSet
	_lista.elegida.connect(_cargar)
	dentro.add_child(_lista)


func _boton(columna: VBoxContainer, texto: String, que_hace: Callable) -> void:
	var boton := Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(280, 34)
	boton.pressed.connect(que_hace)
	columna.add_child(boton)


## Partida limpia: se vacía la carpeta de trabajo y se olvida lo que hubiera en
## el estado global, que es lo que cruza escenas (SPECS §2.2). Sin esto, «nueva
## partida» heredaría la comarca descubierta de la anterior.
func _nueva() -> void:
	Partidas.nueva()
	GameState.started = false
	GameState.discovered = {}
	GameState.niebla = null
	Expedition.clear()
	Carga.abrir(get_tree(), "Saliendo a la comarca")
	Carga.cambiar_de_escena(get_tree(), Expedition.REGION_SCENE)


func _abrir_lista() -> void:
	_panel_de_carga.visible = not _panel_de_carga.visible
	if _panel_de_carga.visible:
		_lista.refrescar()


func _cargar(id: String) -> void:
	# LA PANTALLA ANTES QUE LEER: copiar la partida guardada también es del cuadro del
	# clic, y leída antes de abrir la pantalla ese cuadro pasaba de 500 ms. INTERFAZ §9.
	Carga.abrir(get_tree(), "Retomando la partida")
	await get_tree().process_frame
	var sitios := load(SITIOS) as SiteSet
	var fallo := Partidas.cargar(id, sitios)
	if not fallo.is_empty():
		Carga.cerrar()
		push_warning("No se ha podido cargar la partida: %s" % fallo)
		return
	# Retomando: la escena local se monta y luego se vuelca lo guardado encima.
	# Ver [DemoMain._retomar_la_partida].
	Expedition.retomando = true
	Carga.cambiar_de_escena(get_tree(), Expedition.LOCAL_SCENE)


func _salir() -> void:
	get_tree().quit()


## Abre la ventana de configuración encima del menú. La misma que abre el menú de
## ESC —ver [MenuDelJuego.abrir_configuracion]—.
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
