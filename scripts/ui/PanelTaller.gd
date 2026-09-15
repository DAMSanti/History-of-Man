class_name PanelTaller
extends RefCounted
## La cola del taller: lo que se va a hacer, en qué orden, y por qué algo no
## sale.
##
## Sale de [GameUI] como [PanelObras]. Hasta ahora el taller era una caja
## cerrada: hacía «la pieza menos cubierta» de lo que pedía el trabajo y no
## había forma de ver qué venía después ni de mandar hacer algo concreto. Ver
## SISTEMAS §22 e INTERFAZ §4.
##
## **Lo que se pinta aquí es [Taller.cola], entrada a entrada.** No hay una
## segunda lista ni un orden propio de la ventana: la vista no decide nada de
## la partida (SPECS §4.7), y si pintara con una regla y el artesano eligiera
## con otra, un día dirían cosas distintas.

## Anchos de la lista, a juego con los de [PanelObras].
const PIEZA := 150
const CUANTAS := 44
const QUIEN := 96

var ui: GameUI

## Qué pieza y cuántas lleva puesta la fila de encargar. Se guardan entre
## repintados: la ventana se repinta sola, y un desplegable que se vuelve a su
## sitio cada segundo no se puede usar.
var _encargo_pieza: int = -1
var _encargo_cuantas: int = 1


func _init(panel: GameUI) -> void:
	ui = panel


func show_workshop() -> void:
	var body := ui._window("taller", "Taller")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "no hay partida", true)
		return

	_fila_de_encargo(body)

	var lista := ui.sim.taller.cola_de_trabajo()
	if lista.is_empty():
		ui._text(body, "no hay nada que hacer: todo cubierto.", true)
	else:
		ui._text(body, "lo que se va a hacer, en orden:", true)
	for i in range(lista.size()):
		_fila(body, lista[i], i)

	_apartadas(body)


## La fila de arriba: una pieza, cuántas, y a la cola.
func _fila_de_encargo(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	var pieza := OptionButton.new()
	pieza.custom_minimum_size = Vector2(PIEZA, 22)
	pieza.add_theme_font_size_override("font_size", 11)
	var opciones: Array[int] = []
	for speciality_key: int in SettlementSim.SPECIALITY_MAKES:
		for kind_key: int in (SettlementSim.SPECIALITY_MAKES[speciality_key] as Array):
			# Sólo lo que se sabe hacer: encargar lo que nadie sabe todavía
			# sería una entrada bloqueada para siempre. Ver [Taller.knows_tool].
			if not ui.sim.taller.knows_tool(kind_key as Tool.Kind):
				continue
			opciones.append(kind_key)
			pieza.add_item(Tool.kind_name(kind_key as Tool.Kind))
	if opciones.is_empty():
		ui._text(body, "todavía no se sabe hacer nada que encargar", true)
		return
	if _encargo_pieza < 0 or not opciones.has(_encargo_pieza):
		_encargo_pieza = opciones[0]
	pieza.selected = opciones.find(_encargo_pieza)
	pieza.item_selected.connect(func(donde: int) -> void:
		_encargo_pieza = opciones[donde])
	row.add_child(pieza)

	var cuantas := Label.new()
	cuantas.text = "%d" % _encargo_cuantas
	cuantas.custom_minimum_size = Vector2(CUANTAS, 0)
	cuantas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cuantas.add_theme_font_size_override("font_size", 12)
	row.add_child(cuantas)

	for entry: Array in [["−", -1], ["+", 1]]:
		var paso := Button.new()
		paso.text = entry[0]
		paso.custom_minimum_size = Vector2(GameUI.COL_BUTTON, 20)
		paso.pressed.connect(func() -> void:
			_encargo_cuantas = maxi(_encargo_cuantas + int(entry[1]), 1)
			show_workshop())
		row.add_child(paso)

	var manda := Button.new()
	manda.text = "Encargar"
	manda.tooltip_text = "Un encargo se hace aunque pase de la meta: la meta " \
		+ "es un tope para lo que el taller decide solo."
	manda.custom_minimum_size = Vector2(76, 20)
	manda.pressed.connect(func() -> void:
		ui.sim.taller.encargar_pieza(_encargo_pieza as Tool.Kind, _encargo_cuantas)
		show_workshop())
	row.add_child(manda)


## Una entrada de la cola, con sus botones de orden.
func _fila(body: VBoxContainer, entrada: Dictionary, donde: int) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UISkin.row_box(
		UISkin.SURFACE if donde % 2 == 0 else UISkin.GROUND.lightened(0.03)))
	body.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	frame.add_child(row)

	var kind := int(entrada["tool"]) as Tool.Kind
	var automatico := bool(entrada["automatico"])

	var nombre := Label.new()
	nombre.text = Tool.kind_name(kind)
	if not automatico:
		# El encargo se distingue de un vistazo: es lo que ha pedido el
		# jugador, y va delante por eso.
		nombre.add_theme_color_override("font_color", UISkin.OCHRE)
	nombre.custom_minimum_size = Vector2(PIEZA, 0)
	nombre.add_theme_font_size_override("font_size", 12)
	row.add_child(nombre)

	var faltan := Label.new()
	faltan.text = "%d" % int(entrada["faltan"]) if not automatico else "—"
	faltan.custom_minimum_size = Vector2(CUANTAS, 0)
	faltan.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	faltan.add_theme_font_size_override("font_size", 12)
	row.add_child(faltan)

	var quien := Label.new()
	quien.text = _quien_la_hara(int(entrada["especialidad"]))
	quien.custom_minimum_size = Vector2(QUIEN, 0)
	quien.add_theme_font_size_override("font_size", 11)
	quien.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(quien)

	# Y por qué no sale, en rojo como en la ventana de técnicas. Una entrada
	# bloqueada no para la cola: se queda a la vista y se hace la siguiente.
	var motivo := Label.new()
	motivo.text = String(entrada["motivo"])
	motivo.custom_minimum_size = Vector2(150, 0)
	motivo.add_theme_font_size_override("font_size", 11)
	motivo.add_theme_color_override("font_color", UISkin.ALARM)
	row.add_child(motivo)

	_botones_de_orden(row, entrada, donde)


func _botones_de_orden(row: HBoxContainer, entrada: Dictionary,
		donde: int) -> void:
	var kind := int(entrada["tool"]) as Tool.Kind
	var automatico := bool(entrada["automatico"])
	var aviso_subir := "Sube la prioridad de esta pieza" if automatico \
		else "Sube el encargo en la cola"
	var aviso_bajar := "Baja la prioridad de esta pieza" if automatico \
		else "Baja el encargo en la cola"

	for entry: Array in [["▲", -1, aviso_subir], ["▼", 1, aviso_bajar]]:
		var button := Button.new()
		button.text = entry[0]
		button.tooltip_text = entry[2]
		button.custom_minimum_size = Vector2(GameUI.COL_BUTTON, 20)
		button.pressed.connect(func() -> void:
			# Una sola palanca con dos puertas: en lo automático, el orden ES
			# la prioridad de la pieza. Ver SISTEMAS §22.
			if automatico:
				ui.sim.prioridades.mover_pieza(kind, int(entry[1]))
			else:
				ui.sim.taller.mover_encargo(donde, int(entry[1]))
			show_workshop())
		row.add_child(button)

	var quita := Button.new()
	quita.text = "✕"
	quita.tooltip_text = "Deja esta pieza en nunca" if automatico \
		else "Quita el encargo"
	quita.custom_minimum_size = Vector2(GameUI.COL_BUTTON, 20)
	quita.pressed.connect(func() -> void:
		if automatico:
			ui.sim.fijar_prioridad_pieza(kind, Prioridades.Nivel.NUNCA)
		else:
			ui.sim.taller.quitar_encargo(donde)
		show_workshop())
	row.add_child(quita)


## Las piezas apartadas, con su vuelta.
##
## Quitar una entrada automática la deja en nunca, y sin esta línea sería
## irreversible desde la única ventana donde se quita.
func _apartadas(body: VBoxContainer) -> void:
	var fuera := ui.sim.prioridades.piezas_en_nunca()
	if fuera.is_empty():
		return
	ui._text(body, "apartadas —no se hacen— :", true)
	for kind: int in fuera:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		body.add_child(row)

		var nombre := Label.new()
		nombre.text = Tool.kind_name(kind as Tool.Kind)
		nombre.custom_minimum_size = Vector2(PIEZA, 0)
		nombre.add_theme_font_size_override("font_size", 11)
		nombre.add_theme_color_override("font_color", UISkin.INK_FAINT)
		row.add_child(nombre)

		var vuelve := Button.new()
		vuelve.text = "↺"
		vuelve.tooltip_text = "Devuelve esta pieza a la cola, en normal"
		vuelve.custom_minimum_size = Vector2(GameUI.COL_BUTTON, 20)
		vuelve.pressed.connect(func() -> void:
			ui.sim.fijar_prioridad_pieza(kind as Tool.Kind,
				Prioridades.Nivel.NORMAL)
			show_workshop())
		row.add_child(vuelve)


## Quién la hará: alguien de esa especialidad que esté hoy en el taller, o el
## aviso de que no hay nadie.
##
## No es un motivo de la entrada: que no haya peletero no impide hacer un
## vestido, impide que HOY lo haga alguien. Por eso va en su columna y no en
## rojo con los que faltan.
func _quien_la_hara(speciality: int) -> String:
	if speciality < 0:
		return "—"
	for person: Inhabitant in ui.sim.people:
		if person.job == Profession.Job.MANUFACTURA \
				and int(person.current_speciality) == speciality:
			return person.given_name
	return "nadie en %s" % Profession.speciality_name(
		speciality as Profession.Speciality).to_lower()
