class_name FiltroDeMarcadores
extends MenuButton
## Qué alfileres se ven en el valle: ninguno, todos, o los que se elijan.
##
## Petición del usuario del 2026-09-13: «quiero un botón para poder filtrar y
## mostrar ningún marker, todos, las cuevas, las cimas, los de pesca, los de
## caza, los de frutos y raíces, los de leña y fibra, los de cantera o cualquier
## combinación de ellos».
##
## Guarda QUÉ familias se ven y avisa; quién apaga cada alfiler es cosa de
## [ParajeMarkers] y de [CaveMouth], que son los que los tienen.

signal cambiado

## Las familias de alfiler. No son las actividades de [Subsistence]: la
## recolección se parte en dos —frutos y raíces por un lado, leña y fibra por
## otro— porque son dos cuadrillas distintas y el jugador las mira por separado,
## y hay dos familias que no son de trabajo, la cueva y la cima.
enum Familia { CUEVA, CIMA, PESCA, CAZA, FRUTOS, LENA, CANTERA }

const NOMBRES := {
	Familia.CUEVA: "Cuevas",
	Familia.CIMA: "Cimas",
	Familia.PESCA: "Pesca",
	Familia.CAZA: "Caza",
	Familia.FRUTOS: "Frutos y raíces",
	Familia.LENA: "Leña y fibra",
	Familia.CANTERA: "Cantera",
}

## Lo que se recoge en cada familia de la recolección. Sale del material del
## paraje —lo que de verdad se saca de allí— y no del oficio, que es el mismo.
const DE_LENA := [Materia.Kind.LENA, Materia.Kind.FIBRA, Materia.Kind.YESCA,
	Materia.Kind.CORTEZA, Materia.Kind.RESINA]

## Qué familias se ven. Se empieza con todo puesto: el filtro es para quitar
## ruido cuando estorba, no para tener que encender el mapa al empezar.
var visibles: Dictionary = {}


func _init() -> void:
	text = "Marcadores"
	tooltip_text = "Qué alfileres se ven en el valle"
	# Lo que el jugador dejó elegido, que sobrevive a la escena. Ver
	# [GameState.marcadores_visibles].
	for familia: int in Familia.values():
		visibles[familia] = bool(GameState.marcadores_visibles.get(familia, true))


func _ready() -> void:
	var menu := get_popup()
	menu.add_item("Todos", -2)
	menu.add_item("Ninguno", -1)
	menu.add_separator()
	for familia: int in Familia.values():
		menu.add_check_item(String(NOMBRES[familia]), familia)
		menu.set_item_checked(menu.get_item_index(familia), bool(visibles[familia]))
	# Sin cerrarse al marcar: se eligen varias de una vez, que es justo lo que
	# se pidió —«o cualquier combinación de ellos»—.
	menu.hide_on_checkable_item_selection = false
	menu.id_pressed.connect(_elegido)


func _elegido(id: int) -> void:
	var menu := get_popup()
	if id < 0:
		var puesto := id == -2
		for familia: int in Familia.values():
			visibles[familia] = puesto
			menu.set_item_checked(menu.get_item_index(familia), puesto)
	else:
		visibles[id] = not bool(visibles.get(id, true))
		menu.set_item_checked(menu.get_item_index(id), bool(visibles[id]))
	GameState.marcadores_visibles = visibles.duplicate()
	cambiado.emit()


func se_ve(familia: Familia) -> bool:
	return bool(visibles.get(familia, true))


## En qué familia cae un paraje. El marisqueo va con la pesca: es la misma
## cuadrilla y el mismo sitio, la orilla.
static func familia_de(paraje: Paraje) -> Familia:
	match paraje.activity:
		Subsistence.Activity.PESCA, Subsistence.Activity.MARISQUEO:
			return Familia.PESCA
		Subsistence.Activity.CAZA:
			return Familia.CAZA
		Subsistence.Activity.MATERIA_PRIMA:
			return Familia.CANTERA
	return Familia.LENA if DE_LENA.has(paraje.kind) else Familia.FRUTOS
