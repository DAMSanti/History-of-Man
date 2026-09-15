class_name PantallaDeCarga
extends CanvasLayer
## La pantalla de carga: una piel tensada con el título, la barra y lo que se está
## haciendo. INTERFAZ §9.
##
## Cuelga de la raíz del árbol, no de la escena: la abre la escena que se va y la cierra
## la que llega (ver [Carga]). Tapa la pantalla entera y se come el ratón, porque detrás
## hay un mundo a medio montar.

## Por encima de toda la interfaz del juego.
const CAPA := 120
## Cada cuántos segundos recorre la barra el brillo de la señal de vida.
const VUELTA_DEL_BRILLO := 1.6
const ANCHO := 620.0

var titulo := "":
	set(valor):
		titulo = valor
		if _titulo != null:
			_titulo.text = valor

var _fondo: ColorRect
var _titulo: Label
var _barra: Control
var _etapa: Label


func _init() -> void:
	layer = CAPA
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fondo = ColorRect.new()
	_fondo.color = UISkin.GROUND
	_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fondo)

	var marco := PanelContainer.new()
	var hueca := StyleBoxEmpty.new()
	hueca.set_content_margin_all(PielTensada.DESBORDE + 28.0)
	marco.add_theme_stylebox_override("panel", hueca)
	marco.custom_minimum_size = Vector2(ANCHO, 0.0)
	_fondo.add_child(marco)
	var piel := PielTensada.new()
	marco.add_child(piel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 18)
	marco.add_child(columna)

	_titulo = Label.new()
	_titulo.text = titulo
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Pigmento.escribir(_titulo, UISkin.OCHRE, 30)
	columna.add_child(_titulo)

	_barra = Control.new()
	_barra.custom_minimum_size = Vector2(ANCHO - 2.0 * (PielTensada.DESBORDE + 28.0), 16.0)
	_barra.draw.connect(_pintar_la_barra)
	columna.add_child(_barra)

	_etapa = Label.new()
	_etapa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# En hueso y no en carbón: es lo único que se lee mientras se espera, y el carbón,
	# seco y roto, no se leía (captura del 2026-09-15).
	Pigmento.escribir(_etapa, UISkin.INK, 22)
	columna.add_child(_etapa)


func _process(_delta: float) -> void:
	# A mano y cada cuadro: un Control colgado de un CanvasLayer no toma solo el tamaño
	# de la ventana, y la ventana puede cambiar mientras carga.
	var lado := get_viewport().get_visible_rect().size
	_fondo.position = Vector2.ZERO
	_fondo.size = lado
	var marco := _fondo.get_child(0) as Control
	# El tamaño también a mano: colgado de un ColorRect, que no es contenedor, el marco
	# se quedaba más estrecho que su mínimo.
	marco.size = marco.get_combined_minimum_size()
	marco.position = ((lado - marco.size) * 0.5).floor()
	var texto := Carga.texto()
	if _etapa.text != texto:
		_etapa.text = texto
	_barra.queue_redraw()


## La barra: una tira de piel más oscura que se va llenando de ocre, como las casillas del
## árbol de técnicas.
##
## Y LA SEÑAL DE VIDA: un brillo que la recorre sin parar, cada [VUELTA_DEL_BRILLO]
## segundos. La barra dice lo hecho y puede detenerse —esperando a la red no hay nada
## hecho que contar—; el brillo dice que no está colgado. Decisión del usuario del
## 2026-09-15 (INTERFAZ §9.3).
func _pintar_la_barra() -> void:
	var r := Rect2(Vector2.ZERO, _barra.size)
	_barra.draw_rect(r, UISkin.RAISED)
	var lleno := Rect2(r.position, Vector2(r.size.x * Carga.valor(), r.size.y))
	if lleno.size.x > 0.5:
		_barra.draw_rect(lleno, UISkin.OCHRE)
	var fase := fmod(float(Time.get_ticks_msec()) / 1000.0, VUELTA_DEL_BRILLO) / VUELTA_DEL_BRILLO
	var ancho := r.size.x * 0.12
	var x := -ancho + (r.size.x + ancho) * fase
	var desde := maxf(x, 0.0)
	var hasta := minf(x + ancho, r.size.x)
	if hasta - desde > 0.5:
		_barra.draw_rect(Rect2(Vector2(desde, 0.0), Vector2(hasta - desde, r.size.y)),
			Color(UISkin.INK, 0.18))
	_barra.draw_rect(r, UISkin.RULE, false, 2.0)


## Lo que enseña ahora, para las pruebas.
func etapa_escrita() -> String:
	return _etapa.text
