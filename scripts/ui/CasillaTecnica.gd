class_name CasillaTecnica
extends PanelContainer
## La casilla de una técnica en el árbol, con su aviso emergente escrito en
## BBCode.
##
## Existe por el aviso: el de Godot es texto plano, y el usuario pidió el
## 2026-09-13 que lo que le falta a una técnica saliera EN ROJO dentro de él. El
## texto lo compone [TechGraph._tooltip]; esto sólo lo pinta con color.
##
## **Y el aviso es NUESTRO, no el del motor** (2026-09-17). El tooltip de Godot se cierra
## solo: tiene un temporizador de aparición, se esconde al mover el ratón dentro del mismo
## control y se vuelve a pedir después. Eso es lo que el usuario veía como «aparece y
## desaparece», y no se arregla con un `_make_custom_tooltip` —que sólo cambia lo que hay
## DENTRO del globo, no cuándo se abre y se cierra—. La regla que pidió, literal: **abierto
## siempre que el ratón esté encima**. Así que el globo lo abre [_abrir] al entrar el ratón
## y sólo lo cierra [_cerrar] al salir, o si la casilla se va del árbol.

## Ancho del aviso. Sin él, un RichTextLabel que se ajusta al contenido se
## queda en una columna de una letra.
const ANCHO_DEL_AVISO := 380.0

## A cuánto del ratón se pone el globo, para no quedar debajo del cursor.
const APARTADO := Vector2(18.0, 12.0)

## El globo es UNO para todas las casillas: dos avisos a la vez no tienen sentido, y así
## no se queda ninguno colgado si una casilla muere con el ratón encima.
static var _globo: PanelContainer = null
static var _texto: RichTextLabel = null
static var _capa: CanvasLayer = null
## De quién es el globo que está abierto ahora mismo.
static var _dueña: CasillaTecnica = null

## Lo que dice el aviso de esta casilla, en BBCode. Lo pone [TechGraph].
var aviso := ""


## Las señales se atan AL CONSTRUIR y no en `_ready`: una casilla que todavía no está en
## el árbol —una prueba, un panel a medio montar— tiene que responder igual.
func _init() -> void:
	mouse_entered.connect(_abrir)
	mouse_exited.connect(_cerrar)
	tree_exiting.connect(_cerrar)


## El del motor, callado: el globo lo llevamos nosotros. Sin esto salen los dos.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""


func _abrir() -> void:
	if aviso.is_empty():
		return
	_montar()
	_texto.text = aviso
	_dueña = self
	_globo.visible = true
	if not is_inside_tree():
		return
	# Al ratón, y recortado contra los bordes de la ventana: una casilla del borde derecho
	# sacaba el globo fuera de la pantalla.
	_globo.reset_size()
	var pantalla := Vector2(get_viewport_rect().size)
	var donde := get_global_mouse_position() + APARTADO
	var tamaño := _globo.size
	if donde.x + tamaño.x > pantalla.x:
		donde.x = maxf(0.0, get_global_mouse_position().x - APARTADO.x - tamaño.x)
	if donde.y + tamaño.y > pantalla.y:
		donde.y = maxf(0.0, pantalla.y - tamaño.y)
	_globo.position = donde


func _cerrar() -> void:
	if _globo != null and _dueña == self:
		_globo.visible = false
		_dueña = null


## El globo, una vez. Cuelga de su propia capa para que salga por encima de los paneles.
##
## **El globo se fabrica siempre; colgarlo del árbol es aparte.** Así una prueba puede
## comprobar la regla —abierto con el ratón encima— sin montar media interfaz, y el juego
## lo ve porque la casilla sí está en el árbol. La suite corre en `_init` de un `SceneTree`,
## donde la raíz todavía no existe (2026-09-17).
func _montar() -> void:
	if _globo != null and is_instance_valid(_globo):
		_colgar()
		return
	_capa = CanvasLayer.new()
	_capa.layer = 100
	_globo = PanelContainer.new()
	# NO SE COME EL RATÓN: si el globo lo capturase, taparía la casilla, la casilla se
	# daría por abandonada y el aviso se cerraría solo. Justo lo que se viene a quitar.
	_globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.scroll_active = false
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(ANCHO_DEL_AVISO, 0.0)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_globo.add_child(_texto)
	_capa.add_child(_globo)
	_colgar()


## Cuelga la capa del árbol la primera vez que se puede.
func _colgar() -> void:
	if _capa == null or _capa.get_parent() != null or not is_inside_tree():
		return
	get_tree().root.add_child(_capa)
