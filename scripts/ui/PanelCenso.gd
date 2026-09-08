class_name PanelCenso
extends RefCounted
## Que hay pintado en el mundo ahora mismo, contado y localizable.
##
## Sale de [GameUI]. Es la herramienta para mirar el mundo por dentro: primero
## se ve QUE hay y cuanto -por familias: gente, arboles, props, fauna- y solo
## despues se entra a una pieza concreta y la camara va a ella.
##
## Al reves ya existe -pinchar algo en el mundo abre su ficha- y no resuelve lo
## mismo: para pinchar algo hay que haberlo encontrado antes, y encontrarlo es
## justamente lo que aqui se esta intentando.
##
## Lo que cuenta lo lleva [EntityCensus]; aqui solo se pinta.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


## Qué silueta se está recorriendo, cuál de sus fichas, y qué pieza era.
##
## Los tres, y no sólo el número. Las listas se vuelven a pedir en cada
## repintado y una silueta puede perder piezas por el camino —los props se
## descargan cuando la cámara se aleja de su bloque—, así que con el número
## solo la ficha «7/40» acababa enseñando otra cosa sin avisar. Con la
## identidad se sigue enseñando LA MISMA pieza mientras exista.
var _census_group := ""
var _census_index := 0
var _census_id := ""

## Desde dónde se midió «de más cerca a más lejos» al abrir esta silueta.
##
## Se congela al entrar y no se vuelve a tomar, y ahí está la gracia. La ficha
## lleva la cámara a la pieza, así que midiendo desde la cámara VIVA la pieza
## que estás mirando vuelve a ser la número uno en cada repintado y la lista se
## reordena bajo los pies: pulsabas ▶ ocho veces y podías volver al mismo sitio
## sin haber salido del uno. Congelado, las doscientas fichas son siempre las
## doscientas más cercanas a donde estabas cuando entraste, y ▶ se aleja.
var _census_anchor := Vector3.ZERO

## Anchos de la lista de siluetas, medidos contra los 520 útiles de la ventana.
const CENSUS_NAME := 210
const CENSUS_COUNT := 64


## La lista de lo que hay pintado en el mundo, por familias.
##
## Es la puerta de la herramienta: primero se ve QUÉ hay y cuánto, y sólo
## después se entra a mirar una pieza concreta. Al revés —una ficha suelta a la
## que se llega pinchando en el mundo— ya existe y no resuelve lo mismo: para
## pinchar algo en el mundo hay que haberlo encontrado antes, y encontrarlo es
## justamente lo que aquí se está intentando.
func show_census() -> void:
	var body := ui._window("entidades", "Entidades pintadas")
	ui._clear(body)
	if ui.census == null:
		ui._text(body, "No hay mundo montado todavía.")
		return

	var groups := ui.census.groups()
	if groups.is_empty():
		ui._text(body, "No hay nada pintado.")
		return

	ui._text(body, "Lo que el juego tiene puesto en el mundo ahora mismo. Pincha "
		+ "una silueta para recorrer sus piezas una a una: la cámara va a cada "
		+ "una y, si es algo que anda, se le pinta el rastro por donde ha "
		+ "pasado.", true)

	var family := ""
	for group: Dictionary in groups:
		if String(group["family"]) != family:
			family = String(group["family"])
			ui._heading(body, family.to_upper())
		_census_row(body, group)


## Una silueta: cómo se llama, cuántas hay y qué significa ese cuántas.
##
## La coletilla de la derecha no es decoración. «Sembrados en todo el valle» y
## «pintados alrededor de la cámara» son dos cifras que no se pueden comparar,
## y sin decirlo la lista invita a compararlas: doscientas yescas parecerían
## poquísimo al lado de ciento ochenta mil pinos cuando son cosas distintas.
func _census_row(body: VBoxContainer, group: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	var key := String(group["key"])
	var button := Button.new()
	button.text = String(group["label"])
	button.custom_minimum_size = Vector2(CENSUS_NAME, 24)
	button.add_theme_font_size_override("font_size", 12)
	button.tooltip_text = "Recorrer las piezas de %s una a una" % group["label"]
	if _census_group == key:
		button.add_theme_stylebox_override("normal",
			UISkin.button_box("pressed"))
		button.add_theme_color_override("font_color", UISkin.OCHRE)
	button.pressed.connect(func() -> void:
		_census_id = ""
		show_entity(key, 0))
	row.add_child(button)

	var count := Label.new()
	count.text = "%d" % int(group["count"])
	count.custom_minimum_size = Vector2(CENSUS_COUNT, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 13)
	count.add_theme_color_override("font_color", UISkin.OCHRE)
	row.add_child(count)

	var note := Label.new()
	note.text = String(group["note"])
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", UISkin.INK_FAINT)
	row.add_child(note)


## La ficha de una pieza concreta, con las flechas para pasar a la siguiente.
##
## `focus` distingue las dos formas de llegar aquí, que no quieren lo mismo.
## Pulsando una flecha se quiere ir a ver la pieza, así que la cámara salta.
## En el repintado automático NO: enganchar la vista a la entidad cada medio
## segundo impide apartarse a mirar el alrededor, que es media herramienta —lo
## que se suele querer saber de un uro es qué tiene alrededor, no el uro—.
func show_entity(key: String, index: int, focus: bool = true) -> void:
	var body := ui._window("entidad", "Ficha")
	ui._clear(body)
	if key != _census_group:
		_census_group = key
		_census_anchor = _looking_at()
	if ui.census == null:
		ui._text(body, "No hay mundo montado todavía.")
		return

	var entries := ui.census.entries(key, _census_anchor)
	if entries.is_empty():
		_census_id = ""
		if ui.trails:
			ui.trails.stop_following()
		ui._text(body, "No queda ninguna a la vista.")
		ui._text(body, "Los props y los árboles de malla se descargan cuando la "
			+ "cámara se aleja de su bloque: acércate a donde deberían estar y "
			+ "vuelve a entrar.", true)
		_census_back(body)
		return

	# Por IDENTIDAD antes que por número: ver `_census_id`. Quien quiere
	# cambiar de pieza —las flechas, la lista— lo dice borrando la identidad,
	# y entonces manda el número.
	var wanted := index
	if not _census_id.is_empty():
		for i in range(entries.size()):
			if String(entries[i].get("id", "")) == _census_id:
				wanted = i
				break
	_census_index = clampi(wanted, 0, entries.size() - 1)
	var entry: Dictionary = entries[_census_index]
	_census_id = String(entry.get("id", ""))

	# El título de la ventana es el de la pieza, así que la barra de arriba ya
	# dice a quién se está mirando sin gastar una línea del cuerpo.
	ui._window("entidad", String(entry["title"]))

	_census_nav(body, key, _census_index, entries.size())
	_census_scope(body, key, entries.size())

	for line: String in (entry["lines"] as Array[String]):
		ui._text(body, line)

	# La distancia se calcula AQUÍ y no en el censo, contra la cámara de ahora
	# mismo y no contra el punto desde el que se ordenó la lista —ver
	# `_census_anchor`—. Son dos cosas distintas en cuanto el jugador se mueve,
	# y la que sirve para ir a ver algo es la de ahora.
	var spot: Vector3 = entry["pos"]
	var eye := _looking_at()
	ui._text(body, "En (%.0f, %.0f), a %.0f m de altura, a %.0f m de la cámara."
		% [spot.x, spot.z, spot.y,
			Vector2(spot.x - eye.x, spot.z - eye.z).length()], true)

	_census_trail(body, entry)

	var go := Button.new()
	go.text = "Llevar la cámara aquí"
	go.pressed.connect(func() -> void:
		_look_at_world(spot))
	body.add_child(go)

	if focus:
		_look_at_world(spot)


## Las flechas y el «3 / 14», que es lo que convierte la ficha en un recorrido.
func _census_nav(body: VBoxContainer, key: String, shown: int,
		total: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	# Dan la vuelta al llegar al final. Una lista de piezas iguales no tiene
	# principio ni final que signifiquen nada, y un botón que se apaga en el
	# borde sólo obliga a desandar el camino.
	var back := Button.new()
	back.text = "◀"
	back.custom_minimum_size = Vector2(34, 24)
	back.disabled = total <= 1
	back.pressed.connect(func() -> void:
		_census_id = ""
		show_entity(key, (shown - 1 + total) % total))
	row.add_child(back)

	var counter := Label.new()
	counter.text = "%d / %d" % [shown + 1, total]
	counter.custom_minimum_size = Vector2(84, 0)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_font_size_override("font_size", 14)
	counter.add_theme_color_override("font_color", UISkin.OCHRE)
	row.add_child(counter)

	var next := Button.new()
	next.text = "▶"
	next.custom_minimum_size = Vector2(34, 24)
	next.disabled = total <= 1
	next.pressed.connect(func() -> void:
		_census_id = ""
		show_entity(key, (shown + 1) % total))
	row.add_child(next)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var list := Button.new()
	list.text = "Ver la lista"
	list.custom_minimum_size = Vector2(94, 24)
	list.add_theme_font_size_override("font_size", 11)
	list.pressed.connect(show_census)
	row.add_child(list)


## De cuántas de cuántas: el total de la silueta y qué parte se puede recorrer.
##
## Van los dos números porque casi nunca son el mismo. De un pinar se pueden
## recorrer doscientos árboles de ciento ochenta mil, y enseñar sólo el «1/200»
## haría creer que el valle tiene doscientos pinos, que es la lectura opuesta
## a la verdadera.
func _census_scope(body: VBoxContainer, key: String, shown: int) -> void:
	var whole := shown
	var note := ""
	if ui.census != null:
		for group: Dictionary in ui.census.groups():
			if String(group["key"]) == key:
				whole = int(group["count"])
				note = String(group["note"])
	if whole > shown:
		ui._text(body, "Se pueden recorrer %d. Hay %d %s." % [shown, whole, note],
			true)
	else:
		ui._text(body, "Hay %d, %s." % [whole, note], true)


## El rastro: se enciende solo con la ficha, y se dice cuando no hay ninguno.
##
## Decirlo importa. Sin la línea, una yesca sin rastro y un uro cuyo rastro no
## se está pintando por un fallo se ven exactamente igual —el mapa sin líneas—,
## y son dos cosas muy distintas.
func _census_trail(body: VBoxContainer, entry: Dictionary) -> void:
	if ui.trails == null:
		return
	var trail: Callable = entry.get("trail", Callable())
	if not trail.is_valid():
		ui.trails.stop_following()
		ui._text(body, "Esto no anda: no hay rastro que pintar.", true)
		return

	var tint: Color = entry.get("tint", Color.WHITE)
	ui.trails.follow(trail, tint, ui.sim.terrain() if ui.sim else null,
		String(entry["title"]))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	# La pastilla del color de la línea, para emparejar la ficha con el rastro
	# del mapa sin tener que contar rastros. Es lo mismo que hace la pestaña de
	# Rastros con cada persona.
	var chip := ColorRect.new()
	chip.color = tint
	chip.custom_minimum_size = Vector2(14, 14)
	row.add_child(chip)

	var caption := Label.new()
	caption.text = "Su rastro está pintado en el terreno."
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(caption)


func _census_back(body: VBoxContainer) -> void:
	var list := Button.new()
	list.text = "Ver la lista"
	list.pressed.connect(show_census)
	body.add_child(list)


## Suelta la pieza que se estaba mirando y apaga su rastro.
func _forget_entity() -> void:
	_census_group = ""
	_census_id = ""
	_census_index = 0
	if ui.trails:
		ui.trails.stop_following()


## Desde dónde se mide «cerca».
##
## Es el punto que MIRA la cámara, no dónde está la cámara. Con la vista alta
## los dos quedan a cientos de metros uno del otro, y lo que el jugador tiene
## delante es el primero: ordenar por el segundo pone las primeras fichas
## detrás del hombro.
func _looking_at() -> Vector3:
	if ui.camera != null:
		return ui.camera.target_position
	if ui.sim != null:
		return ui.sim.home_position
	return Vector3.ZERO


## Lleva la cámara a un punto, y se acerca sólo si estaba lejos.
##
## Sólo si estaba lejos porque el zoom es del jugador: si ya está mirando de
## cerca, reencuadrarle en cada flecha le quita el encuadre que había elegido.
## Y el tope de acercamiento es el de la cámara del juego —`min_distance`, ver
## `OrbitalCamera.set_distance_limits`—, no un número puesto aquí: más cerca no
## se puede ir, ni con este botón ni con la rueda.
func _look_at_world(point: Vector3) -> void:
	if ui.camera == null:
		return
	ui.camera.set_target(point)
	var close_enough := ui.camera.min_distance * 1.6
	if ui.camera.orbit_distance > close_enough:
		ui.camera.set_distance(close_enough)


## Vuelve a pintar la ficha que este abierta, si hay alguna.
##
## Lo pide el repintado en vivo de [GameUI]: la ventana se refresca sola
## mientras la partida corre, y quien sabe QUE silueta se esta mirando es este
## panel, no el marco.
func repintar() -> void:
	if _census_group.is_empty():
		return
	show_entity(_census_group, _census_index, false)
