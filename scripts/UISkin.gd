class_name UISkin
extends RefCounted
## La piel de la interfaz: paleta y cajas de estilo.
##
## Antes todo eran los paneles de serie de Godot —negro semitransparente con
## borde gris— y con el terreno detrás no se leía nada. Aquí hay una paleta
## propia, opaca y con jerarquía: un fondo que no compite con el mundo, una
## superficie más clara para las filas, y un solo acento.
##
## El acento es OCRE, y no es una elección arbitraria de diseñador: es el
## pigmento que la banda recoge y usa. La piedra tira a azul frío para que el
## utillaje se distinga del alimento de un vistazo.

const GROUND := Color(0.086, 0.078, 0.066)      ## Fondo de ventana
const SURFACE := Color(0.129, 0.118, 0.102)     ## Fila, campo, cabecera
const RAISED := Color(0.180, 0.165, 0.141)      ## Botón, fila alterna
const RULE := Color(0.263, 0.239, 0.204)        ## Filetes y bordes

const INK := Color(0.914, 0.886, 0.835)         ## Texto normal
const INK_SOFT := Color(0.655, 0.616, 0.549)    ## Texto secundario
const INK_FAINT := Color(0.463, 0.435, 0.388)   ## Rótulos de columna

const OCHRE := Color(0.851, 0.635, 0.325)       ## Acento
const FLINT := Color(0.553, 0.655, 0.729)       ## Piedra y utillaje
const GREEN := Color(0.478, 0.663, 0.435)       ## Bien
const ALARM := Color(0.824, 0.408, 0.349)       ## Mal


## Caja de la ventana entera.
static func window_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = GROUND
	box.border_color = RULE
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 3)
	return box


## Caja de una fila o de un bloque dentro de la ventana.
static func row_box(tint: Color = SURFACE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(4)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## Botón: tres estados con el mismo borde y distinto relleno.
static func button_box(state: String) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	match state:
		"hover":
			box.bg_color = RAISED.lightened(0.12)
			box.border_color = OCHRE
		"pressed":
			box.bg_color = OCHRE.darkened(0.55)
			box.border_color = OCHRE
		"disabled":
			box.bg_color = SURFACE
			box.border_color = RULE.darkened(0.3)
		_:
			box.bg_color = RAISED
			box.border_color = RULE
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## Tema completo, para colgarlo del nodo raíz de la interfaz y que baje solo a
## todo lo que cuelgue de él. Hacerlo así evita tener que estilar control a
## control, que es como se acaba con una ventana a medio pintar.
static func build_theme() -> Theme:
	var theme := Theme.new()

	theme.set_stylebox("panel", "PanelContainer", window_box())

	theme.set_stylebox("normal", "Button", button_box("normal"))
	theme.set_stylebox("hover", "Button", button_box("hover"))
	theme.set_stylebox("pressed", "Button", button_box("pressed"))
	theme.set_stylebox("disabled", "Button", button_box("disabled"))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", OCHRE)
	theme.set_color("font_disabled_color", "Button", INK_FAINT)
	theme.set_font_size("font_size", "Button", 12)

	theme.set_color("font_color", "Label", INK)
	theme.set_font_size("font_size", "Label", 12)

	# El separador de serie es una línea gruesa y clara que parte la ventana
	# en dos. Aquí es un filete fino, que es lo que tiene que ser.
	var rule := StyleBoxFlat.new()
	rule.bg_color = RULE
	rule.content_margin_top = 1
	theme.set_stylebox("separator", "HSeparator", rule)
	theme.set_constant("separation", "HSeparator", 8)

	var track := StyleBoxFlat.new()
	track.bg_color = SURFACE
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = OCHRE
	fill.set_corner_radius_all(3)
	theme.set_stylebox("background", "ProgressBar", track)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", INK)
	theme.set_font_size("font_size", "ProgressBar", 10)

	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	return theme


## Color con el que se lee una proporción de cobertura: rojo si falta, ocre si
## va justo, verde si sobra. Es el mismo criterio en todas las tablas para que
## el color signifique siempre lo mismo.
static func coverage_color(ratio: float) -> Color:
	if ratio < 0.5:
		return ALARM
	if ratio < 1.0:
		return OCHRE
	return GREEN
