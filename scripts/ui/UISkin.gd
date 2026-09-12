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

## La era que se lleva puesta. Ver [PielDeEra].
static var era: Site.Era = Site.Era.PALEOLITICO

# Los colores son `static var` y no `const` porque cambian al cambiar de era.
# Se leen igual desde fuera -`UISkin.OCHRE`- asi que los ciento cuarenta y
# cinco sitios que los usan no se enteran.
static var GROUND := Color(0.106, 0.086, 0.067)   ## Piel curtida en sombra
static var SURFACE := Color(0.153, 0.125, 0.098)  ## La misma piel, a la luz
static var RAISED := Color(0.212, 0.176, 0.137)   ## Piel tensada de un boton
static var RULE := Color(0.400, 0.318, 0.216)     ## Filete de ocre apagado

static var INK := Color(0.925, 0.894, 0.827)      ## Hueso
static var INK_SOFT := Color(0.690, 0.639, 0.557) ## Ceniza
static var INK_FAINT := Color(0.478, 0.435, 0.376)## Carbon frotado

static var OCHRE := Color(0.851, 0.588, 0.267)    ## Ocre: el acento
static var FLINT := Color(0.545, 0.647, 0.722)    ## Silex: piedra y utillaje
static var GREEN := Color(0.514, 0.639, 0.400)    ## Liquen: bien
static var ALARM := Color(0.769, 0.353, 0.286)    ## Hematites: mal


## Viste la interfaz con los materiales de una era.
##
## Se llama UNA vez al montar la partida, con la era del emplazamiento. Toda la
## interfaz cambia detras: los colores son `static var`, asi que quien ya los
## leyo no se entera, pero todo lo que se pinte a partir de aqui sale con la
## piel nueva. Por eso hay que llamarlo ANTES de construir las ventanas.
static func vestir(nueva: Site.Era) -> void:
	era = nueva
	var p := PielDeEra.paleta(nueva)
	GROUND = p["ground"]
	SURFACE = p["surface"]
	RAISED = p["raised"]
	RULE = p["rule"]
	INK = p["ink"]
	INK_SOFT = p["ink_soft"]
	INK_FAINT = p["ink_faint"]
	OCHRE = p["accent"]
	FLINT = p["cold"]
	GREEN = p["good"]
	ALARM = p["bad"]


## Caja de la ventana entera.
static func window_box() -> StyleBoxFlat:
	# Caja plana con borde; el GRANO del soporte va como capa aparte dentro de
	# `GameUI._window`, porque una `StyleBoxTexture` no admite borde y el borde
	# es justo lo que separa la ventana del terreno.
	var box := StyleBoxFlat.new()
	box.bg_color = GROUND
	box.border_color = RULE
	box.set_border_width_all(1)
	# Un filete mas grueso arriba: es donde se tensa la piel.
	box.border_width_top = 2
	box.set_corner_radius_all(PielDeEra.esquina_de(era))
	box.set_content_margin_all(11)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 4)
	return box


## El grano del soporte, para colgarlo DENTRO de la ventana.
##
## Es lo que separa un rectangulo de color de algo que parece material: una
## piel raspada tiene poro y veta. Va como capa propia y no como fondo porque
## el fondo lleva el borde. Ver [PielDeEra.textura_de_grano].
static func grain_layer() -> TextureRect:
	var capa := TextureRect.new()
	capa.texture = PielDeEra.textura_de_grano(era)
	capa.stretch_mode = TextureRect.STRETCH_TILE
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# En multiply: el grano oscurece y aclara lo que hay debajo en vez de
	# taparlo, que es lo que hace un poro de verdad.
	capa.material = CanvasItemMaterial.new()
	(capa.material as CanvasItemMaterial).blend_mode = 		CanvasItemMaterial.BLEND_MODE_MUL
	capa.modulate = Color(1.0, 1.0, 1.0, 1.0)
	return capa


## Caja de una fila o de un bloque dentro de la ventana.
static func row_box(tint: Color = SURFACE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(PielDeEra.esquina_de(era))
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## Caja de una fila MARCADA: la misma de siempre con un filete alrededor.
##
## Para lo que hay que ver sin pinchar. Hoy la usa la lista de parajes para
## los que esta estacion no se pueden trabajar: el sitio sigue ahi —la banda
## lo conoce— pero el rio va crecido o hay que dar la vuelta al valle.
static func outlined_box(tint: Color, edge: Color) -> StyleBoxFlat:
	var box := row_box(tint)
	box.set_border_width_all(1)
	box.border_color = edge
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
	box.set_corner_radius_all(PielDeEra.esquina_de(era))
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
	rule.content_margin_left = 2
	rule.content_margin_right = 2
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
