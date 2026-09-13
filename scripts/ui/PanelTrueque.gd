class_name PanelTrueque
extends RefCounted
## La ventana del trueque, como la del almacén: lo de la banda a la izquierda, lo
## que traen los visitantes a la derecha, y se pasan cosas al trato.
##
## Frente 25 de EPOCA_01 §10.1, tanda 4. Sólo lee y pide: lo que vale cada cosa,
## si el trato sale y el cambio en sí los decide [Intercambio] (SPECS §4.7). Lo
## único que guarda es el trato a medio hacer, que es de la ventana y no de la
## partida.

var ui: GameUI

## El trato a medio hacer: lo que se pone de cada lado. `material -> cuánto`.
var da: Dictionary = {}
var recibe: Dictionary = {}

## Con quién, la última vez que se abrió. Si cambia, el trato se vacía.
var _con: int = -1


func _init(panel: GameUI) -> void:
	ui = panel


## Lo que la banda puede poner: todo lo que hay en el almacén, en el orden del
## catálogo. No se filtra nada más: qué se da lo decide el jugador.
static func lotes_de_la_banda(store: Storehouse) -> Array[int]:
	var lotes: Array[int] = []
	for kind: int in Materia.Kind.values():
		if store.amount(kind as Materia.Kind) >= 1.0:
			lotes.append(kind)
	return lotes


func show_trade() -> void:
	var body := ui._window("trueque", "Trueque")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return
	var con := ui.sim.intercambio.con_quien()
	if con < 0:
		ui._text(body, "No se conoce a nadie con quien tratar. Hay que salir "
			+ "a buscar gente: ver la expedición.")
		return
	if con != _con:
		_con = con
		da.clear()
		recibe.clear()

	ui._heading(body, PanelRelaciones.nombre_de(con).to_upper())
	ui._text(body, "Trato: %s. Con buen trato lo nuestro vale más a sus ojos y "
		% PanelRelaciones.como_va(ui.sim.contacto.trato_con(con))
		+ "lo suyo menos.", true)

	var columnas := HBoxContainer.new()
	columnas.add_theme_constant_override("separation", 18)
	body.add_child(columnas)

	var izquierda := VBoxContainer.new()
	izquierda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columnas.add_child(izquierda)
	ui._heading(izquierda, "LO DE LA BANDA")
	for kind: int in lotes_de_la_banda(ui.sim.store):
		_fila(izquierda, kind, ui.sim.store.amount(kind as Materia.Kind), da)

	var derecha := VBoxContainer.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columnas.add_child(derecha)
	ui._heading(derecha, "LO QUE TRAEN")
	var quedan := ui.sim.intercambio.quedan_de(con)
	for kind: int in quedan:
		_fila(derecha, kind, float(quedan[kind]), recibe)

	body.add_child(HSeparator.new())
	var dado := ui.sim.intercambio.valor_de_lo_que_se_da(da, con)
	var recibido := ui.sim.intercambio.valor_de_lo_que_se_recibe(recibe, con)
	ui._text(body, "Damos %.1f · recibimos %.1f" % [dado, recibido])
	var sale := ui.sim.intercambio.se_acepta(da, recibe, con)
	if not sale and dado > 0.0 and recibido > 0.0:
		ui._text(body, "No les compensa: los dos lados se separan un %.0f %%, "
			% (100.0 * absf(dado - recibido) / maxf(dado, recibido))
			+ "y el trato sale con un %.0f %% como mucho."
			% (100.0 * Intercambio.MARGEN), true)

	var cerrar := Button.new()
	cerrar.text = "Cerrar el trato"
	cerrar.disabled = not sale
	cerrar.pressed.connect(func() -> void:
		if ui.sim.intercambio.cambiar(con, da, recibe):
			da.clear()
			recibe.clear()
		show_trade())
	body.add_child(cerrar)


## Una fila: el material, cuánto hay, cuánto va al trato y los dos botones.
func _fila(columna: VBoxContainer, kind: int, hay: float, lado: Dictionary) -> void:
	var fila := HBoxContainer.new()
	columna.add_child(fila)
	var nombre := Label.new()
	nombre.text = "%s  %.0f" % [Materia.material_name(kind as Materia.Kind), hay]
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(nombre)
	var puesto := Label.new()
	puesto.text = "→ %.0f" % float(lado.get(kind, 0.0))
	fila.add_child(puesto)
	var menos := Button.new()
	menos.text = "−"
	menos.disabled = float(lado.get(kind, 0.0)) <= 0.0
	menos.pressed.connect(func() -> void:
		lado[kind] = maxf(float(lado.get(kind, 0.0)) - 1.0, 0.0)
		if float(lado[kind]) <= 0.0:
			lado.erase(kind)
		show_trade())
	fila.add_child(menos)
	var mas := Button.new()
	mas.text = "+"
	mas.disabled = float(lado.get(kind, 0.0)) + 1.0 > hay + 0.0001
	mas.pressed.connect(func() -> void:
		lado[kind] = float(lado.get(kind, 0.0)) + 1.0
		show_trade())
	fila.add_child(mas)
