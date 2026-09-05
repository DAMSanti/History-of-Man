class_name GameUI
extends CanvasLayer
## Interfaz de ventanas del mapa de detalle.
##
## Hasta ahora todo era texto pegado a una esquina y teclas sueltas. Esto lo
## convierte en algo manejable con el ratón: una barra de botones abajo, y
## ventanas movibles que se abren y se cierran.
##
## Las ventanas son deliberadamente pocas y cada una responde a una pregunta
## que el jugador se hace de verdad: quién tengo (Banda), qué sabemos hacer
## (Técnicas), qué conocemos del valle (Territorio), y qué es este sitio
## (Lugar, que se abre al pinchar algo en el mundo).

signal cave_action(action: String, feature: Dictionary)

## Ancho de ventana. Subió de 380 a 430 al pasar el almacén a filas de una
## línea: nombre, cantidad, falta y objetivo con botones no caben en 380 sin
## recortar el nombre del material, que es lo único que no se puede recortar.
##
## Subió a 480 cuando la ficha de persona sumó fuerza, resistencia y agudeza
## a la lista de destrezas, y a 560 cuando los parajes de caza empezaron a
## decir "corzo, jabalí y urogallo" en vez de un material suelto: una lista
## de especies es mucho más larga que una palabra, y 480 la seguía cortando.
const PANEL_WIDTH := 560
const PANEL_HEIGHT := 460

## La de trabajos aparte, y bastante más ancha.
##
## Es la única con una tabla de verdad: quince personas por una columna de
## tarea. En 430 no cabía, y el remedio de partirla en una tabla por oficio
## salió peor que la enfermedad —cada persona repetida cinco veces y medio
## panel en blanco—. La tabla manda sobre el ancho, no al revés.
##
## OJO: el número de columnas es `tasks_of` sumado sobre `GRID_JOBS`, y
## sube cada vez que se añade una especialidad -pasó de doce a diecisiete
## sin que esta constante se enterara, y la tabla se salía del panel. Si se
## vuelve a quedar corta, es esto: hay que volver a medir, no solo poner un
## número más grande a ojo.
const JOBS_WIDTH := 900

var sim: SettlementSim
var knowledge: BandKnowledge
var field: ResourceField
var tech: TechTree
var site: Site

var _windows: Dictionary = {}
var _bodies: Dictionary = {}
var _captions: Dictionary = {}
var _next_offset := 0
var _skin: Theme

## Rótulos que se refrescan solos, sin volver a construir la ventana.
##
## Antes el repintado borraba los controles y los creaba de nuevo, así que
## había que saltárselo con el ratón encima —el botón que ibas a pulsar podía
## desaparecer a mitad de clic—. Y como leer un panel es tenerlo bajo el
## ratón, en la práctica un panel abierto NO se actualizaba nunca: mostraba la
## foto del instante en que se abrió.
##
## Atando cada dato a su rótulo, refrescar es escribir texto en un control que
## ya existe. No se borra nada, así que puede hacerse a diez veces por segundo
## y con el ratón donde esté.
## Quien pinta los rastros y las manchas de paraje en el mundo. Lo pone la
## escena.
var trails: TrailView = null
var markers: ParajeMarkers = null
var people_source: Node = null

var _live: Array[Dictionary] = []
var _building: String = ""

## El paraje que muestra la ficha "paraje" ahora mismo, si hay una abierta.
## Sirve para refrescarla en vivo (ver `_process`) y para que un clic sobre
## la misma mancha, con su ficha ya abierta, no la vuelva a abrir sin más:
## ver `DemoMain._unhandled_input`.
var shown_paraje: Paraje = null

## La cumbre cuya ficha está abierta, y lo que ha contestado el último
## «intentar cima»: sin guardarlo, el aviso se perdía al repintar la ficha
## y el botón parecía no hacer nada.
var shown_peak: Dictionary = {}
var _peak_notice: String = ""
var _peak_ordered: bool = false


## Si la ficha de ESTE paraje está abierta ahora mismo.
##
## Es lo que le dice al clic del mundo que ya ha hecho su trabajo: la mancha
## de un paraje puede ser enorme -120 m de radio o más-, y sin esto cada
## clic dentro de ella volvía a abrir la misma ficha una y otra vez. Con la
## ficha abierta, un clic ahí dentro tiene que comportarse como en cualquier
## otro punto del mapa, o se siente como si el terreno hubiera dejado de
## responder.
func paraje_is_open(paraje: Paraje) -> bool:
	if paraje == null or shown_paraje != paraje:
		return false
	var frame: Control = _windows.get("paraje", null)
	return is_instance_valid(frame) and frame.visible
var _clock: Label
var _speed_buttons: Array[Dictionary] = []
var _lore_button: Button


func _ready() -> void:
	layer = 10
	# El tema se cuelga de cada ventana y baja solo a todo lo que contenga.
	# Un CanvasLayer no es Control y no tiene `theme`, así que no se puede
	# poner una vez arriba del todo.
	_skin = UISkin.build_theme()
	_build_clock()
	_build_taskbar()
	set_process(true)


## Las ventanas abiertas se repintan solas.
##
## Sin esto, un panel abierto mostraba la foto del instante en que se abrio:
## abrias el almacen, la banda trabajaba media hora y el panel seguia diciendo
## que no habia nada. Se refresca cada segundo, que es de sobra para datos que
## cambian por jornadas y no cuesta nada.
func _process(_delta: float) -> void:
	# El reloj sí va a ritmo de pantalla: es lo único que cambia continuamente
	# y verlo saltar de hora en hora se lee como que el juego se ha colgado.
	_update_clock()

	# Lo atado se refresca a diez por segundo, pase lo que pase: no borra ni
	# crea controles, así que da igual dónde esté el ratón.
	if Engine.get_process_frames() % 6 == 0:
		_refresh_live()

	# Cada media jornada de reloj de pantalla. Lo que cambia de verdad ya va
	# atado y se refresca diez veces por segundo; esto sólo repone lo que
	# cambia de ESTRUCTURA -un material nuevo en el almacén, un crío que
	# cumple años y entra en los oficios-.
	if Engine.get_process_frames() % 30 != 0:
		return
	for id: String in _windows.keys():
		var frame: Control = _windows[id]
		if not frame.visible:
			continue
		# Con el ratón dentro NO se reconstruye. Reconstruir borra los
		# controles y los crea de nuevo, así que el que estabas señalando deja
		# de existir: el tooltip se cerraba solo al segundo, y un botón podía
		# desaparecer justo debajo del cursor a mitad de clic.
		#
		# Esto se probó a afinar dejando pasar todo lo que no fuera un botón,
		# y salió mal: el tooltip del almacén se cerraba igual, porque lo
		# lleva la fila entera y la fila también se destruía. Ahora ya no hace
		# falta afinar nada: las cifras que cambian van atadas a su rótulo y
		# se refrescan sin reconstruir, así que aplazar la reconstrucción
		# mientras se lee ya no congela nada.
		if frame.get_global_rect().has_point(frame.get_global_mouse_position()):
			continue
		match id:
			"almacen": show_store()
			"trabajos": show_jobs()
			"banda": show_band()
			"tecnicas": show_tech()
			"territorio": show_territory()
			"cronica": show_lore()
			"parajes": show_places()
			"rastros": show_trails()
			"paraje":
				# La ficha de UN paraje concreto: lo que descubre una batida
				# -materiales nuevos, el % conocido- tiene que verse aquí sin
				# cerrar y reabrir. Si el sitio se queda en descanso o deja de
				# existir de alguna forma, `shown_paraje` seguirá siendo valido
				# -los parajes no se borran-, así que basta con el nulo.
				if shown_paraje:
					show_paraje(shown_paraje)


# ---------------------------------------------------------------- reloj ---

## El reloj, arriba a la izquierda.
##
## Ahí estaba antes el panel de depuración, que se quitó por tapar el terreno
## con datos que no le importan a nadie. Lo que sí hace falta en esa esquina
## es la fecha: la jornada manda sobre todo lo demás —a qué hora sale la
## gente, cuándo vuelve— y la estación decide lo que rinde cada trabajo.
func _build_clock() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_left", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var frame := PanelContainer.new()
	frame.theme = _skin
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	frame.add_child(column)

	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 14)
	_clock.add_theme_color_override("font_color", UISkin.INK)
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_clock)

	_build_speed_buttons(column)
	_update_clock()


## Pausa y velocidades, debajo de la fecha.
##
## Estaba en las teclas + y −, que además movían el reloj del sol y no el de la
## banda, así que acelerar descuadraba las dos cosas. Aquí son cuatro estados
## discretos y se ve cuál está puesto, que es lo que hace falta: nadie quiere
## afinar una velocidad, quiere pausar o correr.
func _build_speed_buttons(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	column.add_child(row)

	_speed_buttons.clear()
	for entry: Array in [
		[0.0, TimeIcon.Shape.PAUSA, "Pausa"],
		[1.0, TimeIcon.Shape.PLAY, "Velocidad normal"],
		[3.0, TimeIcon.Shape.RAPIDO, "Rápido (x3)"],
		[5.0, TimeIcon.Shape.MUY_RAPIDO, "Muy rápido (x5)"],
	]:
		var speed: float = entry[0]
		var button := Button.new()
		button.custom_minimum_size = Vector2(34, 24)
		button.tooltip_text = String(entry[2])
		button.pressed.connect(func() -> void: _set_speed(speed))
		row.add_child(button)

		# El icono va DENTRO del botón, centrado: un Button no admite dibujo
		# propio, así que se le mete un hijo que no toca el ratón
		var holder := CenterContainer.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(holder)
		var icon := TimeIcon.make(entry[1] as TimeIcon.Shape, 13.0)
		holder.add_child(icon)

		_speed_buttons.append({"button": button, "icon": icon, "speed": speed})

	_paint_speed_buttons()


func _set_speed(speed: float) -> void:
	if sim == null:
		return
	sim.time_scale = speed
	_paint_speed_buttons()


## El estado puesto se marca en ocre; los demás quedan apagados.
func _paint_speed_buttons() -> void:
	var current := sim.time_scale if sim else 1.0
	for entry: Dictionary in _speed_buttons:
		var active: bool = is_equal_approx(float(entry["speed"]), current)
		var icon: TimeIcon = entry["icon"]
		icon.tint = UISkin.OCHRE if active else UISkin.INK_SOFT
		icon.queue_redraw()
		var button: Button = entry["button"]
		button.add_theme_stylebox_override("normal",
			UISkin.button_box("pressed" if active else "normal"))


## Lo que ya está escrito en el rótulo. Reescribir el texto y, sobre todo,
## pisar el color del tema en CADA fotograma obliga al Label a repintarse
## siempre, y esto corre sesenta veces por segundo para un dato que cambia
## una vez por minuto de juego.
var _clock_minute: int = -1
var _clock_night: bool = false
var _clock_speed: float = 1.0
var _lore_pending: int = -1


func _update_clock() -> void:
	if _clock == null:
		return
	if sim == null:
		_clock.text = "—"
		return

	var hour := int(sim.hour)
	var minute := int((sim.hour - float(hour)) * 60.0)
	var stamp := hour * 60 + minute
	if stamp != _clock_minute:
		_clock_minute = stamp
		_clock.text = "%02d:%02d  ·  día %d  ·  %s, %s, año %d  ·  %s" % [
			hour, minute, sim.day,
			Subsistence.month_name(GameState.season, sim.season_day).capitalize(),
			Subsistence.season_name(GameState.season), GameState.year,
			sim.weather.name_text().to_lower()]

	# De noche el color baja: se ve de un vistazo si la banda está trabajando
	# o durmiendo sin tener que leer la hora
	var night := sim.hour < SettlementSim.HORA_DESPERTAR \
		or sim.hour >= SettlementSim.HORA_DORMIR
	if night != _clock_night:
		_clock_night = night
		_clock.add_theme_color_override("font_color",
			UISkin.INK_SOFT if night else UISkin.INK)

	if not is_equal_approx(_clock_speed, sim.time_scale):
		_clock_speed = sim.time_scale
		_paint_speed_buttons()

	# Un diario que se escribe solo no sirve de nada si nadie lo abre: el
	# botón avisa de cuántas anotaciones hay sin leer.
	if _lore_button and sim.chronicle:
		var pending := sim.chronicle.unread
		if pending != _lore_pending:
			_lore_pending = pending
			_lore_button.text = "Crónica" if pending <= 0 else "Crónica ·%d" % pending
			_lore_button.add_theme_color_override("font_color",
				UISkin.OCHRE if pending > 0 else UISkin.INK)


# ---------------------------------------------------------------- barra ---

func _build_taskbar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_theme_constant_override("margin_right", 12)
	add_child(margin)

	var bar := HBoxContainer.new()
	bar.theme = _skin
	bar.add_theme_constant_override("separation", 6)
	margin.add_child(bar)

	for entry: Array in [
		["almacen", "Almacén"], ["trabajos", "Trabajos"], ["banda", "Banda"],
		["tecnicas", "Técnicas"], ["territorio", "Territorio"],
		["cronica", "Crónica"], ["parajes", "Parajes"], ["rastros", "Rastros"],
		["controles", "Controles"],
	]:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(96, 30)
		button.pressed.connect(_toggle.bind(entry[0] as String))
		bar.add_child(button)
		if entry[0] == "cronica":
			_lore_button = button


# --------------------------------------------------------------- ventana --

## Crea una ventana vacía, o devuelve la que ya existe.
##
## Son PanelContainer y no la clase Window de Godot a propósito: Window abre
## una ventana del sistema operativo, que en pantalla completa se comporta
## fatal y no se puede estilar con el resto de la interfaz.
func _window(id: String, title: String,
		width: int = PANEL_WIDTH) -> VBoxContainer:
	_building = id
	if _windows.has(id):
		var existing: Control = _windows[id]
		# NO se trae al frente aqui: esto tambien lo llama el repintado
		# automatico, y una ventana que se pone delante sola cada segundo es
		# inmanejable si tienes dos abiertas
		existing.visible = true
		# El TITULO si se actualiza siempre, aunque la ventana ya existiera:
		# sin esto, la ficha de paraje se quedaba con el nombre del primero
		# que se abrio para siempre, porque solo el contenido -el body- se
		# volvia a pintar en cada `show_paraje`.
		if _captions.has(id):
			(_captions[id] as Label).text = title
		return _bodies[id]

	var panel_height := _content_height() + 70
	var frame := PanelContainer.new()
	frame.theme = _skin
	frame.custom_minimum_size = Vector2(width, panel_height)
	# La ventana se come el raton entero. Sin esto la rueda sobre un panel
	# hacia zoom en el mapa de detras: los Label ignoran el raton por defecto y
	# dejan subir el evento, y el ScrollContainer lo propaga en cuanto llega a
	# su tope. La camara escucha en _unhandled_input, que es lo correcto, pero
	# solo funciona si la interfaz marca lo suyo como atendido.
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	# Escalonadas, para que al abrir varias no se tapen exactamente
	# Por debajo del reloj, que ocupa la esquina de arriba a la izquierda: con
	# 60 la barra de titulo de la primera ventana quedaba tapada.
	frame.position = Vector2(24 + _next_offset * 26, 108 + _next_offset * 26)
	_next_offset = (_next_offset + 1) % 5
	add_child(frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	frame.add_child(column)

	# Barra de título: además de rotular, es el asa para arrastrar
	var header := HBoxContainer.new()
	column.add_child(header)

	var caption := Label.new()
	caption.text = title
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", UISkin.OCHRE)
	header.add_child(caption)
	_captions[id] = caption

	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(26, 22)
	close.pressed.connect(func() -> void:
		frame.visible = false
		# Cerrar la ficha de un paraje apaga su mancha: la marca es de la
		# ficha, no del mundo
		if id == "paraje":
			if markers:
				markers.hide_extent()
			shown_paraje = null)
	header.add_child(close)

	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, _content_height())
	column.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(width - 40, 0)
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	# Solo el marco. El ScrollContainer NO se toca: tiene que recibir la rueda
	# para poder desplazar su contenido. Cuando llega a su tope deja subir el
	# evento, y ahi es donde lo para el marco, asi que la rueda desplaza dentro
	# del panel y nunca llega a la camara.
	_swallow_mouse(frame)
	_make_draggable(frame, header)

	_windows[id] = frame
	_bodies[id] = body
	return body


## Marca como atendido cualquier evento de ratón que llegue a este control.
##
## Es lo que aísla la ventana del mundo de detrás: `accept_event()` corta la
## propagación antes de que el evento llegue a `_unhandled_input`, que es donde
## escucha la cámara.
func _swallow_mouse(control: Control) -> void:
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton or event is InputEventMouseMotion:
			control.accept_event()
	)


## Alto util del contenido de una ventana. Se saca del alto real de la pantalla
## en vez de fijarlo: con un panel mas alto que la ventana del juego, el
## contenido de abajo queda inalcanzable por mucho que la rueda funcione.
func _content_height() -> int:
	var screen := DisplayServer.window_get_size().y
	return clampi(int(float(screen) * 0.62), 260, 640)


## Arrastrar por la barra de título. Se hace a mano porque un PanelContainer no
## trae comportamiento de ventana.
func _make_draggable(frame: Control, handle: Control) -> void:
	var dragging := {"active": false, "grab": Vector2.ZERO}
	handle.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging["active"] = event.pressed
			dragging["grab"] = frame.get_global_mouse_position() - frame.position
			if event.pressed:
				frame.move_to_front()
		elif event is InputEventMouseMotion and bool(dragging["active"]):
			frame.position = frame.get_global_mouse_position() - (dragging["grab"] as Vector2)
	)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP


## Cierra la ventana de más arriba, si hay alguna abierta.
##
## Devuelve si ha cerrado algo. Lo llama ESC: cerrar lo que tienes delante es
## lo que espera cualquiera al pulsarlo, y salirse del mapa entero —que es lo
## que hacía— da un susto cada vez.
func close_topmost() -> bool:
	var best: Control = null
	var best_order := -1
	for id: String in _windows:
		var frame: Control = _windows[id]
		if not frame.visible:
			continue
		if frame.get_index() > best_order:
			best_order = frame.get_index()
			best = frame
	if best == null:
		return false
	best.visible = false

	# Cerrar la ficha de un paraje apaga su mancha en el terreno: la marca es
	# de la ficha, no del mundo. Y ESC cierra igual que la cruz, asi que tiene
	# que apagarla igual.
	if markers and _windows.get("paraje", null) == best:
		markers.hide_extent()
	return true


## Si hay alguna ventana abierta.
func any_open() -> bool:
	for id: String in _windows:
		if (_windows[id] as Control).visible:
			return true
	return false


func _toggle(id: String) -> void:
	if _windows.has(id) and (_windows[id] as Control).visible:
		(_windows[id] as Control).visible = false
		return
	match id:
		"controles": show_controls()
		"almacen": show_store()
		"trabajos": show_jobs()
		"banda": show_band()
		"tecnicas": show_tech()
		"territorio": show_territory()
		"cronica": show_lore()
		"parajes": show_places()
		"rastros": show_trails()


func _clear(body: VBoxContainer) -> void:
	for child in body.get_children():
		child.queue_free()


## Ata un rótulo a lo que muestra. Se le vuelve a llamar cada décima de
## segundo mientras su ventana esté abierta.
func _bind(node: Control, refresh: Callable) -> void:
	refresh.call()
	_live.append({"win": _building, "node": node, "refresh": refresh})


## Refresca lo atado y suelta lo que ya no existe.
##
## La poda va aquí y no en `_clear` porque los controles se liberan con
## `queue_free`, que no es inmediato: en el momento de limpiar todavía son
## válidos, y un fotograma después ya no.
func _refresh_live() -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in _live:
		# Sin tipo. Asignar un objeto ya liberado a una variable TIPADA revienta
		# ahi mismo, antes de poder preguntar si sigue vivo: es el orden de las
		# dos lineas lo que fallaba, no la comprobacion.
		var node: Variant = entry["node"]
		if not is_instance_valid(node):
			continue
		var control := node as Control
		if control == null or not control.is_inside_tree():
			continue
		kept.append(entry)

		var window: Variant = _windows.get(entry["win"], null)
		if is_instance_valid(window) and not (window as Control).visible:
			continue
		(entry["refresh"] as Callable).call()
	_live = kept


func _heading(body: VBoxContainer, text: String) -> void:
	# Un filete encima en vez de un separador suelto: agrupa la sección con lo
	# que viene debajo en vez de partir la ventana por la mitad. Antes de la
	# primera no, que ahí ya está el de la barra de título.
	if body.get_child_count() > 0:
		body.add_child(HSeparator.new())

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UISkin.OCHRE)
	body.add_child(label)


func _text(body: VBoxContainer, content: String, dim: bool = false) -> void:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Se mide contra la ventana en la que va y no contra `PANEL_WIDTH`: la de
	# trabajos es mucho más ancha, y con el ancho fijo su texto se envolvía a
	# media caja dejando un palmo de blanco a la derecha.
	#
	# 45 y no 20: los márgenes de la caja, los 12 de la barra de
	# desplazamiento y un respiro. Sin ellos la última palabra queda cortada.
	label.custom_minimum_size = Vector2(
		maxf(body.custom_minimum_size.x - 45.0, 200.0), 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color",
		UISkin.INK_SOFT if dim else UISkin.INK)
	body.add_child(label)


func _bar(body: VBoxContainer, caption: String, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	var label := Label.new()
	label.text = caption
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var meter := ProgressBar.new()
	meter.min_value = 0.0
	meter.max_value = 1.0
	meter.value = clampf(value, 0.0, 1.0)
	meter.custom_minimum_size = Vector2(190, 16)
	meter.show_percentage = true
	row.add_child(meter)


# ------------------------------------------------------------ controles ---

## Qué teclas hacen qué.
##
## Estaba en el panel de la esquina, tapando el terreno y visible siempre
## aunque no hiciera falta. Aquí se consulta cuando se necesita y se cierra.
func show_controls() -> void:
	var body := _window("controles", "Controles")
	_clear(body)

	_heading(body, "MOVERSE")
	for entry: Array in [
		["W A S D", "desplazar la vista"],
		["SHIFT + WASD", "desplazarse más deprisa"],
		["Rueda", "acercar y alejar"],
		["Botón derecho", "girar la cámara"],
	]:
		_key_row(body, entry[0], entry[1])
	_text(body, "La vista se para en el borde del recuadro. Lo gris de "
		+ "alrededor es terreno real, pero no se juega ahí.", true)

	body.add_child(HSeparator.new())
	_heading(body, "MIRAR")
	for entry: Array in [
		["Clic", "ver la ficha de una persona, un recurso o una cueva"],
		["R", "cambiar la capa del mapa: territorio y recursos"],
		["F3", "mostrar u ocultar los fotogramas por segundo"],
	]:
		_key_row(body, entry[0], entry[1])
	_text(body, "Las capas pintan lo que la banda CONOCE, no lo que hay. Al "
		+ "empezar están casi en blanco: eso es información, no un fallo.", true)

	body.add_child(HSeparator.new())
	_heading(body, "MANDAR")
	for entry: Array in [
		["B", "modo construcción: el clic levanta en vez de seleccionar"],
		["1 a 5", "mandar a toda la banda a una actividad"],
		["P o espacio", "pausar y reanudar"],
		["F1 F2 F3", "velocidad normal, x3 y x5"],
		["ESC", "cerrar la ventana de delante"],
	]:
		_key_row(body, entry[0], entry[1])
	_text(body, "El reparto fino se hace en la pestaña de Trabajos, no con las "
		+ "teclas: ahí se ve quién puede hacer cada oficio y por qué.", true)


## Una fila de tecla y para qué sirve.
func _key_row(body: VBoxContainer, keys: String, what: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)

	var key := Label.new()
	key.text = keys
	key.custom_minimum_size = Vector2(118, 0)
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", Color(0.72, 0.86, 0.95))
	row.add_child(key)

	var text := Label.new()
	text.text = what
	text.add_theme_font_size_override("font_size", 12)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(PANEL_WIDTH - 200, 0)
	row.add_child(text)


# -------------------------------------------------------------- almacén ---

## Qué hay guardado, qué falta y qué se ha mandado tener.
##
## Todo va en UNA fila por material: icono, nombre, lo que hay, lo que hace
## falta y el objetivo con sus botones. Antes el control de tope colgaba en
## una segunda línea debajo, y con veinte materiales la pestaña era una
## escalera imposible de leer.
func show_store() -> void:
	var body := _window("almacen", "Almacén")
	_clear(body)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()

	var days := sim.store.days_of_food(mouths)

	_heading(body, _autonomy_text(days))
	_text(body, "%d personas comen %.1f raciones al día. Los críos y los "
		% [sim.population(), mouths]
		+ "ancianos comen menos, así que la cuenta no es una por cabeza.", true)

	if days < 3.0:
		_notice(body, "Hambre. Con menos de tres jornadas, cualquier temporal "
			+ "deja a la banda sin nada.", UISkin.ALARM)
	elif days < 10.0:
		_text(body, "Sin margen: un mal mes acaba con las reservas.", true)

	# --- el sitio ---------------------------------------------------------
	_heading(body, "EL ABRIGO")
	_bar(body, "Ocupación", sim.store.fullness())
	_text(body, "%s de %s · quedan %s libres · pesa %s" % [
		Materia.format_volume(sim.store.total_litres()),
		Materia.format_volume(sim.store.capacity_litres),
		Materia.format_volume(maxf(sim.store.free_litres(), 0.0)),
		Materia.format_weight(sim.store.total_kg())], true)

	if sim.store.fullness() > 0.92:
		_notice(body, "El abrigo está lleno. Lo que traigan se queda fuera.",
			UISkin.ALARM)

	_show_camp(body)

	# --- el desglose ------------------------------------------------------
	_food_cap_row(body)

	# En el orden del catálogo y SIEMPRE entero, no ordenado por lo que más
	# abulte. Ordenarlo por volumen quería decir que las filas bailaban cada
	# vez que la banda traía algo: ibas a por la leña donde estaba hace un
	# momento y ahí había otra cosa. Cada material tiene su sitio, y lo
	# conserva aunque hoy no quede nada de él.
	var rows := sim.store.in_catalogue_order()
	var index := 0
	var food_done := false
	_heading(body, "ALIMENTO · EN RACIONES")
	_ledger_header(body)
	for row: Dictionary in rows:
		var kind := row["kind"] as Materia.Kind
		if not Materia.is_provision(kind) and not food_done:
			food_done = true
			_heading(body, "MATERIA PRIMA · EN UNIDADES")
			_ledger_header(body)
			index = 0
		_material_row(body, kind, float(row["units"]), index)
		index += 1

	_show_toolkit(body)

	_heading(body, "CONSERVACIÓN")
	var perishing: Array[String] = []
	for row: Dictionary in rows:
		var kind := row["kind"] as Materia.Kind
		var life := Materia.shelf_life(kind)
		if life <= 0 or life > 200:
			continue
		var aged := float(sim.store.ages.get(kind, 0.0))
		var left := maxi(life - int(aged), 0)
		# Y cuánto se ha ido AYER, que es la cifra que contesta «¿por qué no
		# sube esto?». Un montón que no crece porque se pudre y un montón que
		# no crece porque nadie lo trae se leen igual, y no son lo mismo.
		var lost := float(sim.store.spoiled.get(kind, 0.0))
		var tail := "" if lost < 0.05 else "  ·  ayer se echaron a perder %.1f" % lost
		perishing.append("%s: %d días antes de echarse a perder%s"
			% [Materia.material_name(kind), left, tail])
	if perishing.is_empty():
		_text(body, "Nada que se estropee de momento.", true)
	else:
		for line: String in perishing:
			_text(body, "  · " + line, true)

	if not sim.camp_built.get(CampProjects.Kind.SECADERO, false):
		_notice(body, "Sin secadero, la carne dura cuatro días y el pescado "
			+ "TRES. Ahumarlos los lleva a medio año: mientras no lo levantes, "
			+ "una jornada buena de pesca se pudre antes de comérsela.",
			UISkin.OCHRE)


## Aviso en color, con su filete a la izquierda. Se lee de un vistazo sin
## tener que buscar el símbolo dentro de un párrafo.
func _notice(body: VBoxContainer, content: String, tint: Color) -> void:
	var frame := PanelContainer.new()
	var box := UISkin.row_box(UISkin.SURFACE)
	box.border_color = tint
	box.border_width_left = 3
	frame.add_theme_stylebox_override("panel", box)
	body.add_child(frame)

	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 100, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", tint)
	frame.add_child(label)


## No se construye una choza: se EQUIPA la cueva. Hogar y secadero son las
## dos mejoras del abrigo, y el secadero exige el hogar porque ahumar sin
## fuego no se hace.
func _show_camp(body: VBoxContainer) -> void:
	_heading(body, "CAMPAMENTO")

	for kind: int in CampProjects.all():
		var project := kind as CampProjects.Kind
		var built: bool = sim.camp_built.get(project, false)
		var working: bool = sim.camp_queue == project

		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UISkin.row_box(
			UISkin.SURFACE if built else UISkin.GROUND.lightened(0.04)))
		body.add_child(frame)

		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		frame.add_child(column)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		column.add_child(row)

		var mark := Label.new()
		mark.text = "✓" if built else ("◐" if working else "○")
		mark.custom_minimum_size = Vector2(16, 0)
		mark.add_theme_color_override("font_color",
			UISkin.GREEN if built else (UISkin.OCHRE if working else UISkin.INK_FAINT))
		row.add_child(mark)

		var label := Label.new()
		label.text = CampProjects.project_name(project)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color",
			UISkin.INK if built or working else UISkin.INK_SOFT)
		row.add_child(label)

		if built:
			var done := Label.new()
			done.text = "en pie"
			done.add_theme_font_size_override("font_size", 11)
			done.add_theme_color_override("font_color", UISkin.GREEN)
			row.add_child(done)
		elif working:
			var meter := ProgressBar.new()
			meter.min_value = 0.0
			meter.max_value = CampProjects.labor_days(project)
			meter.value = clampf(sim.camp_progress, 0.0, meter.max_value)
			meter.custom_minimum_size = Vector2(84, 14)
			# El rótulo de serie va centrado DENTRO de la barra y en una tan
			# estrecha se sale por el lado. Va aparte, a su derecha.
			meter.show_percentage = false
			row.add_child(meter)

			var pct := Label.new()
			pct.text = "%d%%" % int(meter.value / meter.max_value * 100.0)
			pct.custom_minimum_size = Vector2(34, 0)
			pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			pct.add_theme_font_size_override("font_size", 11)
			pct.add_theme_color_override("font_color", UISkin.OCHRE)
			row.add_child(pct)
		else:
			var needs := CampProjects.requires(project)
			var blocked: bool = needs >= 0 and not sim.camp_built.get(needs, false)
			var button := Button.new()
			button.text = "levantar" if not blocked else "pide %s" \
				% CampProjects.project_name(needs as CampProjects.Kind).to_lower()
			button.disabled = blocked or sim.camp_queue >= 0
			button.custom_minimum_size = Vector2(84, 22)
			button.pressed.connect(func() -> void:
				sim.queue_project(project)
				show_store())
			row.add_child(button)

		var note := Label.new()
		note.text = CampProjects.project_desc(project)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(PANEL_WIDTH - 110, 0)
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", UISkin.INK_FAINT)
		column.add_child(note)

	if sim.camp_queue >= 0:
		var pending: Array[String] = []
		var recipe: Dictionary = CampProjects.materials(
			sim.camp_queue as CampProjects.Kind)
		for material: int in recipe:
			var wanted: float = float(recipe[material])
			var have := sim.store.amount(material as Materia.Kind)
			if have < wanted:
				pending.append("%s (%d de %d)" % [
					Materia.material_name(material as Materia.Kind),
					int(have), int(wanted)])
		if not pending.is_empty():
			_notice(body, "Esperando material: %s." % ", ".join(pending), UISkin.OCHRE)
		var hands := 0
		for person: Inhabitant in sim.people:
			if person.job == Profession.Job.HOGAR:
				hands += 1
		if hands == 0:
			_notice(body, "No hay nadie en el hogar: la obra no avanza sola.",
				UISkin.ALARM)


## Lo importante del utillaje no es el inventario sino la COBERTURA: doce
## lascas no dicen nada, «doce lascas para siete manos» sí.
func _show_toolkit(body: VBoxContainer) -> void:
	_heading(body, "EL UTILLAJE")

	var demand := sim.tool_demand()

	# Se listan TODAS las piezas que la banda necesita, tenga o no ninguna. Lo
	# que no existe es justo lo que hay que ver, y en una lista de lo que hay
	# nunca aparece.
	# TODAS las del catalogo, no solo las que hoy se piden o se tienen.
	#
	# Antes se listaba lo que tuviera demanda o existencias, y eso dejaba
	# fuera el aparejo de pesca entero: la nasa, el anzuelo, la red y el
	# arpon no se piden hasta que la banda sabe usarlos, asi que el jugador
	# no los veia en ninguna parte y no habia forma de saber que existian ni
	# que hacia falta para llegar a ellos. Lo que no se tiene es justo lo que
	# hay que ver.
	var kinds: Array[int] = []
	for kind: int in Tool.Kind.values():
		kinds.append(kind)

	# En el orden del catálogo, SIN ordenar por cobertura.
	#
	# Ordenar por lo peor cubierto parecía buena idea —lo accionable arriba—
	# hasta ver lo que hacía: la cobertura depende de la meta, así que pulsar
	# «+» en una pieza la mandaba a otro sitio de la tabla y el botón que
	# ibas a volver a pulsar ya no estaba debajo del cursor. Cada pieza tiene
	# su sitio, y lo conserva.
	kinds.sort_custom(func(a: int, b: int) -> bool: return a < b)

	_ledger_header(body)
	var index := 0
	for kind: int in kinds:
		_tool_row(body, kind as Tool.Kind, int(demand.get(kind, 0)), index)
		index += 1

	if not sim.toolkit.broken_today.is_empty():
		_text(body, "Hoy se ha roto: %s." % ", ".join(sim.toolkit.broken_today), true)

	_text(body, "«Gasta» es lo que la banda consume en un mes: lo que come, lo "
		+ "que rompe y lo que piden las obras. «Meta» es cuánto quieres tener "
		+ "guardado — al llegar, dejan de traer más y se emplean en otra cosa.",
		true)
	_text(body, "Las piezas se gastan con el uso. El sílex da casi tres veces "
		+ "más filo que la cuarcita, y ésa es la razón de mandar a alguien "
		+ "lejos a buscarlo.", true)


# ------------------------------------------------------------- el libro ---
#
# Almacén y utillaje comparten rejilla a propósito: son la misma pregunta
# —qué tengo, qué me falta, cuánto quiero— sobre dos cosas distintas, y con
# las columnas alineadas se leen las dos con la misma mirada.

## Anchos medidos CONTRA la ventana, no a ojo: 560 de panel menos 20 de
## margen y 12 de barra de desplazamiento dejan 508 útiles. La suma de todo
## lo que va en una fila —columnas, tres botones y siete separaciones— tiene
## que caber ahí dentro o la fila se sale y se corta por la derecha.
##
## NAME es para almacén y utillaje, filas de un material suelto: no hace
## falta más. La fila de un paraje —que puede decir «corzo, jabalí y
## urogallo»— no usa esta columna: su nombre se expande solo, ver
## `_content_row`.
const COL_ICON := 20
const COL_NAME := 130
const COL_HAVE := 48
const COL_NEED := 48
const COL_GOAL := 42
const COL_BUTTON := 20


func _ledger_header(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	var widths := [COL_ICON + COL_NAME + 4, COL_HAVE, COL_NEED, COL_NEED, COL_GOAL]
	# Cortos a propósito: «HACE FALTA» no cabe en su columna y se montaba
	# encima de la siguiente
	# GASTA es lo que la banda consume al mes y no lo decide el jugador; META
	# es cuanto quiere tener guardado y lo decide el. Estaban vinculados —los
	# dos salian de lo mismo— y por eso subir uno subia el otro.
	var texts := ["", "HAY", "GASTA", "PRODUCE", "META"]
	for i in range(5):
		var cell := Label.new()
		cell.text = texts[i]
		cell.custom_minimum_size = Vector2(widths[i], 0)
		cell.add_theme_font_size_override("font_size", 9)
		cell.add_theme_color_override("font_color", UISkin.INK_FAINT)
		if i > 0:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cell)


## El armazón común de una fila. Devuelve la caja donde el llamante mete sus
## botones, para que la parte fija —icono, nombre, cifras— se escriba una vez.
func _ledger_row(body: VBoxContainer, icon: Control, name_text: String,
		have_text: String, have_tint: Color, need_text: String,
		goal_text: String, goal_tint: Color, index: int,
		makes_text: String = "") -> HBoxContainer:
	var frame := PanelContainer.new()
	# Filas alternas: sin esto, con veinte materiales seguidos la vista se
	# pierde de línea a mitad de tabla
	frame.add_theme_stylebox_override("panel", UISkin.row_box(
		UISkin.SURFACE if index % 2 == 0 else UISkin.GROUND.lightened(0.03)))
	body.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	frame.add_child(row)

	icon.custom_minimum_size = Vector2(COL_ICON - 4, COL_ICON - 4)
	row.add_child(icon)

	var label := Label.new()
	label.text = name_text
	label.custom_minimum_size = Vector2(COL_NAME - 4, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.clip_text = true
	row.add_child(label)

	var have := Label.new()
	row.set_meta("have", have)
	have.text = have_text
	have.custom_minimum_size = Vector2(COL_HAVE, 0)
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	have.add_theme_font_size_override("font_size", 12)
	have.add_theme_color_override("font_color", have_tint)
	row.add_child(have)

	var need := Label.new()
	row.set_meta("need", need)
	need.text = need_text
	need.custom_minimum_size = Vector2(COL_NEED, 0)
	need.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	need.add_theme_font_size_override("font_size", 12)
	need.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(need)

	# PRODUCE va entre lo que se gasta y lo que se quiere tener: las tres se
	# leen juntas -entra tanto, se va tanto, quiero tanto- y es la cuenta que
	# de verdad decide si hace falta mover gente de oficio.
	var makes := Label.new()
	row.set_meta("makes", makes)
	makes.text = makes_text
	makes.custom_minimum_size = Vector2(COL_NEED, 0)
	makes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	makes.add_theme_font_size_override("font_size", 12)
	makes.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(makes)

	var goal := Label.new()
	goal.text = goal_text
	goal.custom_minimum_size = Vector2(COL_GOAL, 0)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal.add_theme_font_size_override("font_size", 12)
	goal.add_theme_color_override("font_color", goal_tint)
	row.add_child(goal)

	return row


## El tope de comida de toda la despensa, en una sola línea.
##
## Poner tope material a material es un trabajo que el jugador no debería
## tener: no le importa tener treinta bayas o veinte raíces, le importa que la
## banda tenga comida de sobra y que la gente se dedique a otra cosa cuando la
## tenga. Aquí se dice una vez y vale para todo lo que se come.
func _food_cap_row(body: VBoxContainer) -> void:
	var have := sim.store.food_rations()
	var capped := sim.food_is_capped()

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UISkin.row_box(UISkin.SURFACE))
	body.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)

	var label := Label.new()
	# Con la unidad puesta: esta fila cuenta RACIONES -lo que come una
	# persona en un día- y la columna «hay» de abajo cuenta UNIDADES de cada
	# material, que no es lo mismo. Una ración de miel no es una unidad de
	# miel: la miel alimenta 1,6 y la seta 0,3. Sin decirlo, la fila parece
	# la suma de la columna y no cuadra nunca.
	label.text = "Tope de comida (raciones)"
	label.custom_minimum_size = Vector2(COL_ICON + COL_NAME, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var now := Label.new()
	now.custom_minimum_size = Vector2(COL_HAVE, 0)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	now.add_theme_font_size_override("font_size", 12)
	row.add_child(now)
	_bind(now, func() -> void:
		var rations := sim.store.food_rations()
		now.text = "%.0f" % rations
		now.add_theme_color_override("font_color",
			UISkin.OCHRE if sim.food_is_capped() else UISkin.INK))

	var state := Label.new()
	state.custom_minimum_size = Vector2(COL_NEED, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.add_theme_font_size_override("font_size", 10)
	row.add_child(state)
	_bind(state, func() -> void:
		state.text = "lleno" if sim.food_is_capped() else ""
		state.add_theme_color_override("font_color", UISkin.OCHRE))

	var goal := Label.new()
	goal.text = "%.0f" % sim.food_cap if sim.food_cap > 0.0 else "—"
	goal.custom_minimum_size = Vector2(COL_GOAL, 0)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal.add_theme_font_size_override("font_size", 12)
	goal.add_theme_color_override("font_color",
		UISkin.OCHRE if sim.food_cap > 0.0 else UISkin.INK_FAINT)
	row.add_child(goal)

	_goal_buttons(row,
		func() -> void:
			var base: float = sim.food_cap if sim.food_cap > 0.0 else have
			sim.food_cap = maxf(base - _goal_step() * 10.0, 0.0)
			sim.apply_priorities()
			show_store(),
		func() -> void:
			var base: float = sim.food_cap if sim.food_cap > 0.0 else have
			sim.food_cap = base + _goal_step() * 10.0
			sim.apply_priorities()
			show_store(),
		func() -> void:
			sim.food_cap = 0.0
			sim.apply_priorities()
			show_store(),
		sim.food_cap > 0.0)

	var days := sim.food_cap_days()
	frame.tooltip_text = "Tope de comida para toda la despensa.\n\n"
	if sim.food_cap > 0.0:
		frame.tooltip_text += "%.0f raciones: unas %.0f jornadas para la banda entera.\n" % [
			sim.food_cap, days]
	frame.tooltip_text += "Al llegar al tope nadie sale a BUSCAR más comida: " \
		+ "caza, pesca, marisqueo y recolección se quedan sin gente y esa " \
		+ "gente se emplea en otra cosa.\n\n" \
		+ "Lo que ya está empezado sí se termina: el que vuelve cargado " \
		+ "entrega, y una pieza abatida se acaba de traer. Tirar carne para " \
		+ "respetar un tope sería absurdo."

	if capped:
		_text(body, "Despensa al tope: nadie sale a buscar más comida. Lo que "
			+ "haya pendiente de recoger sí se recoge.", true)


## La ficha de una pieza de utillaje.
##
## Va aparte de la del material porque las preguntas son distintas: de un
## material interesa cuánto hay y cuánto se gasta; de una pieza interesa
## además con qué se hace, quién la saca y cómo está de filo, que es lo que
## decide si hay que ponerse a tallar hoy o se puede esperar.
func show_tool(kind: Tool.Kind) -> void:
	var body := _window("utensilio", Tool.kind_name(kind))
	_clear(body)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	_heading(body, Tool.kind_name(kind).to_upper())

	var have := sim.toolkit.count(kind)
	var hands := int(sim.tool_natural_demand().get(int(kind), 0))
	_text(body, "Hay %d para %d manos · filo medio al %.0f%%" % [
		have, hands, sim.toolkit.condition(kind) * 100.0])

	_heading(body, "CÓMO HA IDO")
	var series := sim.tool_history_of(kind)
	if series.size() < 2:
		_text(body, "Todavía no hay historia: hace falta cerrar alguna "
			+ "jornada para poder dibujar una curva.", true)
	else:
		body.add_child(_history_chart(series))
		_text(body, _history_tale(series), true)
		# Con el utillaje, la pendiente ES la noticia: las piezas no se
		# estropean de golpe, se van rompiendo, y una cuenta que baja despacio
		# avisa con tres semanas de antelación.
		_text(body, "Las piezas se rompen con el uso. Si la línea baja y nadie "
			+ "está tallando, la banda se queda sin filo antes de notarlo.",
			true)

	_heading(body, "CÓMO SE HACE")
	_text(body, _how_and_what_for(kind), true)

	if not sim.toolkit.broken_today.is_empty():
		_text(body, "Hoy se ha roto: %s."
			% ", ".join(sim.toolkit.broken_today), true)


## La ficha de un material: qué es, para qué sirve y cómo ha ido.
##
## La cifra de hoy no dice nada sola. «Cuarenta de fruto seco» puede ser una
## despensa que se llena o una que se vacía, y son dos partidas distintas: en
## una no hay que hacer nada y en la otra hay que mandar gente al monte antes
## de que sea tarde. La curva lo dice de un vistazo y el número no.
func show_material(kind: Materia.Kind) -> void:
	var body := _window("material", Materia.material_name(kind))
	_clear(body)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	_heading(body, Materia.material_name(kind).to_upper())
	_text(body, Materia.describe(kind), true)

	var have := sim.store.amount(kind)
	var needed := sim.material_needed(kind)
	_text(body, "Ahora hay %.0f · se gastan %.0f al mes · pesa %s y ocupa %s"
		% [have, needed,
			Materia.format_weight(have * Materia.kg_per_unit(kind)),
			Materia.format_volume(have * Materia.litres_per_unit(kind))])

	_heading(body, "CÓMO HA IDO")
	var series := sim.history_of(kind)
	if series.size() < 2:
		_text(body, "Todavía no hay historia: hace falta cerrar alguna "
			+ "jornada para poder dibujar una curva.", true)
	else:
		body.add_child(_history_chart(series))
		_text(body, _history_tale(series), true)

	_heading(body, "PARA QUÉ SIRVE")
	_text(body, _uses_of(kind), true)

	var life := Materia.shelf_life(kind)
	if life > 0:
		_heading(body, "CONSERVACIÓN")
		_text(body, "Aguanta unas %d jornadas antes de echarse a perder." % life,
			true)


## La curva de existencias, dibujada a mano.
##
## Es un Control con `draw` propio y no una imagen: son treinta líneas, y
## montar una textura para eso sería pagar memoria y un rebote por el disco
## para dibujar lo que el propio panel puede pintar.
func _history_chart(series: PackedFloat32Array) -> Control:
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(PANEL_WIDTH - 60, 110)

	var top := 1.0
	for value: float in series:
		top = maxf(top, value)

	chart.draw.connect(func() -> void:
		var box := chart.get_rect().size
		chart.draw_rect(Rect2(Vector2.ZERO, box), UISkin.GROUND)

		# Tres rayas de referencia: sin ellas la curva sube y baja sin escala
		for i in range(1, 4):
			var y := box.y * float(i) / 4.0
			chart.draw_line(Vector2(0.0, y), Vector2(box.x, y),
				UISkin.INK_FAINT * Color(1, 1, 1, 0.25), 1.0)

		var points := PackedVector2Array()
		for i in range(series.size()):
			var x := box.x * float(i) / float(maxi(series.size() - 1, 1))
			var y := box.y * (1.0 - series[i] / top)
			points.append(Vector2(x, y))
		if points.size() >= 2:
			chart.draw_polyline(points, UISkin.OCHRE, 2.0, true)

		# El techo de la escala, escrito: una curva sin numeros no se lee
		var font := chart.get_theme_default_font()
		if font:
			chart.draw_string(font, Vector2(4.0, 12.0), "%.0f" % top,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.INK_SOFT)
			chart.draw_string(font, Vector2(4.0, box.y - 4.0),
				"hace %d jornadas" % series.size(),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UISkin.INK_FAINT))
	return chart


## Lo que cuenta la curva, dicho con palabras.
##
## Va debajo del dibujo y no en su lugar: la curva se lee de un vistazo y la
## frase dice lo que hay que hacer, que no es lo mismo.
func _history_tale(series: PackedFloat32Array) -> String:
	var now := series[series.size() - 1]
	var week := series[maxi(series.size() - 8, 0)]
	var change := now - week

	var trend := "se mantiene"
	if change > maxf(now * 0.12, 1.0):
		trend = "sube"
	elif change < -maxf(now * 0.12, 1.0):
		trend = "baja"

	var top := 0.0
	var low := INF
	for value: float in series:
		top = maxf(top, value)
		low = minf(low, value)

	return "En la última semana %s (%+.0f). En lo que se recuerda ha ido de %.0f a %.0f." % [
		trend, change, low, top]


## Para qué sirve un material: qué se hace con él y qué se come.
##
## Lo que decía el tooltip era qué ES el material, y eso sólo responde media
## pregunta. La otra mitad —«¿y esto para qué lo quiero?»— es la que decide si
## se le pone objetivo, y hasta ahora había que deducirla probando.
func _uses_of(kind: Materia.Kind) -> String:
	var uses: Array[String] = []

	for tool_key: int in Tool.Kind.values():
		var tool_kind := tool_key as Tool.Kind
		if Tool.recipe(tool_kind).has(kind):
			uses.append(Tool.kind_name(tool_kind).to_lower())

	var works: Array[String] = []
	for project_key: int in CampProjects.Kind.values():
		var project := project_key as CampProjects.Kind
		if CampProjects.materials(project).has(kind):
			works.append(CampProjects.project_name(project).to_lower())

	var lines: Array[String] = []
	if Materia.is_food(kind):
		lines.append("Se come: %.1f raciones por unidad."
			% Materia.nutrition(kind))
	if not uses.is_empty():
		lines.append("Se gasta en: %s." % ", ".join(uses))
	if not works.is_empty():
		lines.append("Hace falta para: %s." % ", ".join(works))
	if lines.is_empty():
		lines.append("No se gasta en nada todavía: se guarda por si acaso.")
	return "\n".join(lines)


## Cómo se hace una pieza y para qué sirve.
##
## El tooltip decía cuántas hay y cómo están de filo, que es lo que ya se ve
## en la fila. Lo que no estaba en ninguna parte es lo único que hace falta
## para decidir: qué materia prima se lleva, qué herramienta hace falta para
## hacerla, quién la hace y en qué se nota tenerla.
func _how_and_what_for(kind: Tool.Kind) -> String:
	var lines: Array[String] = []

	var recipe := Tool.recipe(kind)
	if recipe.is_empty():
		lines.append("No se fabrica.")
	else:
		var parts: Array[String] = []
		for material: int in recipe:
			parts.append("%.1f de %s" % [float(recipe[material]),
				Materia.material_name(material as Materia.Kind).to_lower()])
		lines.append("Se hace con: %s." % ", ".join(parts))

	# La herramienta previa. Sin buril no se ranura el asta: no es que se
	# tarde más, es que no se hace.
	var prerequisite := Tool.needs_tool(kind)
	if prerequisite >= 0:
		lines.append("Hace falta %s para hacerla."
			% Tool.kind_name(prerequisite as Tool.Kind).to_lower())

	# Y la tecnica, que en el aparejo de pesca es la mitad del asunto: se
	# puede tener el asta y el buril y seguir sin saber hacer un arpon.
	var needed_tech := _tech_behind(kind)
	if needed_tech >= 0:
		var got := tech != null and tech.has(needed_tech as TechTree.Tech)
		lines.append("Pide saber %s%s." % [
			TechTree.tech_name(needed_tech as TechTree.Tech).to_lower(),
			"" if got else " — y todavia no se sabe"])

	var who := _crafted_by(kind)
	if not who.is_empty():
		lines.append("La saca: %s." % who)

	var uses := _tool_serves(kind)
	if not uses.is_empty():
		lines.append("Se usa para: %s." % uses)

	lines.append("Aguanta %d jornadas de uso; en sílex, casi el triple que en "
		% int(Tool.durability_of(kind)
			/ maxf(Tool.wear_per_day(kind), 0.001))
		+ "cuarcita.")
	return "\n".join(lines)


## Qué especialidad del taller saca esta pieza.
func _crafted_by(kind: Tool.Kind) -> String:
	for speciality: int in Profession.SPECIALITY_INFO:
		var made: Array = SettlementSim.SPECIALITY_MAKES.get(speciality, [])
		if made.has(int(kind)):
			return Profession.speciality_name(
				speciality as Profession.Speciality).to_lower()
	return ""


## En qué trabajo se nota tener esta pieza.
func _tool_serves(kind: Tool.Kind) -> String:
	var jobs: Array[String] = []
	for activity: int in ALL_ACTIVITIES:
		if sim.activity_tool(activity as Subsistence.Activity) == int(kind):
			jobs.append(Subsistence.activity_name(
				activity as Subsistence.Activity).to_lower())
	if kind == Tool.Kind.LASCA:
		jobs.append("despiezar lo cazado")
	if kind == Tool.Kind.BURIL:
		jobs.append("ranurar asta y hueso")
	if kind == Tool.Kind.RAEDERA:
		jobs.append("raspar pieles")
	# El aparejo de pesca no sale de `activity_tool`: cual se usa depende de
	# la manera de pescar que la banda pueda hoy -ver [Fishing].
	for method_key: int in Fishing.ORDER:
		var method := method_key as Fishing.Method
		if Fishing.tool_of(method) == int(kind):
			jobs.append("pescar de orilla (%s)"
				% Fishing.method_name(method).to_lower())
	return ", ".join(jobs)


## La tecnica que hay que dominar para poder hacer esta pieza, o -1.
func _tech_behind(kind: Tool.Kind) -> int:
	for method_key: int in Fishing.ORDER:
		var method := method_key as Fishing.Method
		if Fishing.tool_of(method) == int(kind):
			return Fishing.tech_of(method)
	return -1


## Cuánto mueve una pulsación el objetivo.
##
## De uno en uno, que es lo previsible, y de diez en diez con Mayúsculas para
## las cantidades grandes. Se mira la tecla en el momento de pulsar porque la
## señal `pressed` no trae el evento.
func _goal_step() -> float:
	return 10.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0


## Los tres botones del objetivo, iguales en las dos tablas.
func _goal_buttons(row: HBoxContainer, on_less: Callable, on_more: Callable,
		on_clear: Callable, has_goal: bool) -> void:
	for entry: Array in [["−", on_less], ["+", on_more]]:
		var button := Button.new()
		button.text = entry[0]
		button.tooltip_text = "De uno en uno · con Mayúsculas, de diez en diez"
		button.custom_minimum_size = Vector2(COL_BUTTON, 20)
		button.pressed.connect(entry[1] as Callable)
		row.add_child(button)

	var clear := Button.new()
	clear.text = "∞"
	clear.tooltip_text = "Sin objetivo: que lo decida la banda"
	clear.custom_minimum_size = Vector2(COL_BUTTON, 20)
	clear.disabled = not has_goal
	clear.pressed.connect(on_clear)
	row.add_child(clear)


## Una fila de material: lo que hay, lo que piden las obras y el utillaje, y
## el tope que haya puesto el jugador.
## De qué está hecha una pieza, con sus cantidades. Es lo que hay que tener
## en el abrigo para que el taller pueda sacarla, y hasta ahora no se decía
## en ninguna parte: el jugador veía «no se hacen azagayas» sin poder saber
## que lo que faltaba era el asta.
func _recipe_text(kind: Tool.Kind) -> String:
	var parts: Array[String] = []
	for material: int in Tool.recipe(kind):
		parts.append("%.0f %s" % [float(Tool.recipe(kind)[material]),
			Materia.material_name(material as Materia.Kind).to_lower()])
	if parts.is_empty():
		return "nada: se hace con las manos"
	return ", ".join(parts)


## Lo que entra al día, dicho para que se lea.
##
## Con un decimal por debajo de diez: la mitad de los materiales entran a
## medio y a cuarto por jornada, y redondeando a entero la columna entera
## salía a cero y parecía que la banda no producía nada.
func _makes_text(per_day: float) -> String:
	if per_day <= 0.005:
		return "—"
	if per_day < 10.0:
		return "%.1f" % per_day
	return "%.0f" % per_day


## Cuántas raciones da una unidad de esto. Lo que no se come va en unidades
## -una piel es una piel- y se queda a 1.
func _ration_rate(kind: Materia.Kind) -> float:
	if not Materia.is_food(kind):
		return 1.0
	return maxf(Materia.nutrition(kind), 0.01)


func _material_row(body: VBoxContainer, kind: Materia.Kind,
		units: float, index: int) -> void:
	var needed := sim.material_needed(kind)
	var has_goal: bool = sim.limits.has(kind)
	var goal: float = float(sim.limits.get(kind, 0.0))

	# El color compara lo que hay con lo que se GASTA: verde si da para mas de
	# un mes, ocre si justo, rojo si no llega. La meta no pinta aqui: es un
	# deseo del jugador, no una necesidad de la banda.
	var have_tint := UISkin.INK
	if needed > 0.0:
		have_tint = UISkin.coverage_color(units / maxf(needed, 0.001))
	elif has_goal and units >= goal:
		have_tint = UISkin.GREEN

	# Todo lo que se come se cuenta en RACIONES, no en unidades.
	#
	# Las dos cifras existían mezcladas y no cuadraban nunca: la despensa
	# decía 303 y la columna sumaba 307, porque una unidad de miel alimenta
	# 1,6 y una de seta 0,3. Con la ración como única medida, sumar la
	# columna da el total de la despensa y «me quedan 40» significa lo mismo
	# en todas partes: cuarenta días-persona de comida.
	var rate := _ration_rate(kind)

	var goal_text := "%.0f" % (goal * rate) if has_goal else "—"
	var goal_tint := UISkin.OCHRE if has_goal else UISkin.INK_FAINT

	var makes := sim.production_of(kind) * rate
	var row := _ledger_row(body, MateriaIcon.for_materia(kind),
		Materia.material_name(kind),
		"%.0f" % (units * rate), have_tint,
		"%.0f" % (needed * rate) if needed > 0.0 else "—",
		goal_text, goal_tint, index,
		_makes_text(makes))

	# Lo que hay y lo que hace falta se mueven con la jornada: la banda trae
	# leña, el taller gasta sílex. Atados, la cifra cambia con el panel
	# abierto y bajo el ratón, que es donde el jugador la está mirando.
	var have_label: Label = row.get_meta("have")
	_bind(have_label, func() -> void:
		var now := sim.store.amount(kind)
		var want := sim.material_needed(kind)
		var tint := UISkin.INK
		if want > 0.0:
			tint = UISkin.coverage_color(now / maxf(want, 0.001))
		elif sim.limits.has(kind) and now >= float(sim.limits[kind]):
			tint = UISkin.GREEN
		have_label.text = "%.0f" % (now * rate)
		have_label.add_theme_color_override("font_color", tint))

	var need_label: Label = row.get_meta("need")
	_bind(need_label, func() -> void:
		var want := sim.material_needed(kind)
		need_label.text = "%.0f" % (want * rate) if want > 0.0 else "—")

	var makes_label: Label = row.get_meta("makes")
	_bind(makes_label, func() -> void:
		makes_label.text = _makes_text(sim.production_of(kind) * rate))

	# El paso era el 25% de lo que hubiera guardado, así que cambiaba solo
	# según lo que la banda trajera ese día: pulsabas «+» y subía 5, 12 o 30
	# sin ninguna lógica visible. Ahora es de uno en uno, y de diez en diez
	# con Mayúsculas para no tener que dar treinta clics.
	# El paso se pulsa en RACIONES y se guarda en unidades, que es como lo
	# entiende el almacén: si no, pedir «treinta» de miel y «treinta» de
	# seta pediría cantidades de comida muy distintas con el mismo número.
	_goal_buttons(row,
		func() -> void:
			var base: float = goal if has_goal else units
			sim.limits[kind] = maxf(base - _goal_step() / rate, 0.0)
			show_store(),
		func() -> void:
			var base: float = goal if has_goal else units
			sim.limits[kind] = base + _goal_step() / rate
			show_store(),
		func() -> void:
			sim.limits.erase(kind)
			show_store(),
		has_goal)

	# Peso y volumen van al tooltip y no a la fila. Son la cifra que decide si
	# cabe en el abrigo, pero se consultan de tarde en tarde, y metidos en
	# línea empujaban la fila fuera de la ventana.
	# La fila entera es un boton hacia su historia. No hay icono que lo diga
	# porque la fila ya va cargada de cifras y botones; lo dice el tooltip, y
	# el cursor cambia al pasar por encima.
	var frame := row.get_parent() as PanelContainer
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			show_material(kind))

	row.get_parent().tooltip_text = "%s · %s · %s\n%s\n\n%s\n\nPincha para ver su historia." % [
		Materia.material_name(kind),
		Materia.format_weight(units * Materia.kg_per_unit(kind)),
		Materia.format_volume(units * Materia.litres_per_unit(kind)),
		Materia.describe(kind),
		_uses_of(kind)]


## Una fila de utillaje. «Hace falta» aquí es la demanda calculada a partir de
## quién está trabajando en qué, y el objetivo la anula si el jugador lo pone.
func _tool_row(body: VBoxContainer, kind: Tool.Kind,
		needed: int, index: int) -> void:
	var have := sim.toolkit.count(kind)
	var has_order: bool = sim.tool_orders.has(kind)
	var order: int = int(sim.tool_orders.get(kind, 0))

	# GASTA es cuantas se rompen al mes, no cuantas quieres tener: si fuera lo
	# segundo, subir la meta subiria el gasto y el numero no diria nada.
	var broken := sim.tools_broken_per_month(kind)
	var have_tint := UISkin.coverage_color(
		float(have) / maxf(float(needed), 0.001)) if needed > 0 else UISkin.INK

	var row := _ledger_row(body, MateriaIcon.for_tool(kind),
		Tool.kind_name(kind),
		"%d" % have, have_tint,
		"%.1f" % broken if broken < 10.0 else "%.0f" % broken,
		"%d" % order if has_order else "—",
		UISkin.OCHRE if has_order else UISkin.INK_FAINT, index,
		_makes_text(sim.tool_production_of(kind)))

	_goal_buttons(row,
		func() -> void:
			var base := order if has_order else needed
			sim.set_tool_order(kind, maxi(base - int(_goal_step()), 0))
			show_store(),
		func() -> void:
			var base := order if has_order else needed
			sim.set_tool_order(kind, base + int(_goal_step()))
			show_store(),
		func() -> void:
			sim.set_tool_order(kind, 0)
			show_store(),
		has_order)

	# La fila de utillaje tambien lleva a su historia. Es la misma pregunta que
	# con un material -«¿esto sube o baja?»- y la respuesta importa mas aqui:
	# el filo se gasta solo, asi que una cuenta que baja despacio es una crisis
	# con tres semanas de aviso.
	var tool_frame := row.get_parent() as PanelContainer
	tool_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	tool_frame.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			show_tool(kind))

	var condition := sim.toolkit.condition(kind)
	row.get_parent().tooltip_text = "%s\n%s\n\n%s" % [
		Tool.kind_name(kind),
		"No hay ninguna." if have == 0
			else "Filo medio al %.0f%%." % (condition * 100.0),
		_how_and_what_for(kind)]





func _autonomy_text(days: float) -> String:
	if days < 1.0:
		return "No hay para mañana"
	if days < 2.0:
		return "Para un día"
	if days < 90.0:
		return "Para %d días" % int(days)
	return "Para más de una estación"


# ------------------------------------------------------------- trabajos ---

## La ficha de un trozo de terreno cualquiera.
##
## Es la otra mitad del clic como verbo. Señalar un paraje dice «id a trabajar
## ahí»; señalar monte pelado dice «id a MIRAR allí», que es una apuesta: no
## se sabe qué hay. Y la ficha nunca es un clic perdido, porque aunque no
## mandes nada te dice qué suelo es y si se puede llegar.
func show_ground(world: Vector3, terrain: TerrainGenerator) -> void:
	var body := _window("terreno", "El terreno")
	_clear(body)
	if sim == null or terrain == null:
		_text(body, "Sin asentamiento.")
		return

	var away := int(Vector2(world.x - sim.home_position.x,
		world.z - sim.home_position.z).length())
	var metres := int(world.y * terrain.meters_per_unit
		/ maxf(terrain.vertical_exaggeration, 0.001))
	# El sitio dicho como lo diria alguien de la banda, no en coordenadas: es
	# lo que hace que la cronica y las ordenes se lean
	_heading(body, sim.parajes.place_name(world, sim.home_position).capitalize())
	_text(body, "A %d m del abrigo · cota %d m" % [away, metres], true)

	# Qué se pisa y si se puede pisar: es lo que decide si mandar a alguien
	var slope := terrain.get_slope_at(world)
	var ford := terrain.crossing_difficulty_at(world)
	var ground := Traversal.classify_ground(slope, ford)
	var passable := Traversal.is_passable(slope, ford, sim.has_boat, sim.has_bridge)

	_text(body, "Suelo: %s · pendiente %d%%" % [
		_ground_name(ground), int(slope * 100.0)])

	if not passable:
		_notice(body, "No se puede pasar por aquí: %s." % (
			"el agua corta el paso" if ford > 0.0
			else "la pendiente ya no es andar, es trepar"), UISkin.ALARM)

	# Y lo que la banda sabe de este sitio, que es la mitad del juego
	if knowledge:
		var seen := knowledge.explored_at(world)
		if seen < 0.05:
			_text(body, "Nadie ha estado aquí. No se sabe qué hay.")
		elif seen < 0.5:
			_text(body, "Visto de lejos, sin detalle.", true)
		else:
			_text(body, "Terreno conocido.", true)

	var close := sim.parajes.near(Subsistence.Activity.RECOLECCION, world, 200.0)
	if close:
		_text(body, "Cerca queda %s." % close.name_text, true)

	# --- el verbo ---------------------------------------------------------
	_heading(body, "QUÉ SE HACE")

	# El tiempo cambia si conviene salir hoy o esperar, así que va donde se
	# toma esa decisión y no sólo en el reloj
	if sim.weather.keeps_indoors():
		_notice(body, "%s Mandar a alguien hoy es mandarlo a que se vuelva."
			% sim.weather.tell(), UISkin.ALARM)
	elif sim.weather.risk_factor() > 1.4 or sim.weather.sight_factor() < 0.6:
		_notice(body, "%s Se anda peor y se ve menos." % sim.weather.tell(),
			UISkin.OCHRE)

	var explorers := 0
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.EXPLORACION:
			explorers += 1

	if explorers <= 0:
		_notice(body, "No hay nadie en exploración. Ponle gente en Trabajos y "
			+ "podrás mandarla adonde quieras.", UISkin.OCHRE)
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	var go := Button.new()
	go.text = "Explorar hacia aquí"
	go.custom_minimum_size = Vector2(150, 26)
	go.disabled = not passable
	go.tooltip_text = "La partida sale hacia este punto en vez de elegir ella" 		if passable else "Ahí no se puede llegar a pie"
	go.pressed.connect(func() -> void:
		sim.scout_towards(world)
		show_ground(world, terrain))
	row.add_child(go)

	if sim.has_scout_order:
		var stop := Button.new()
		stop.text = "Que decidan"
		stop.custom_minimum_size = Vector2(110, 26)
		stop.pressed.connect(func() -> void:
			sim.clear_scout_order()
			show_ground(world, terrain))
		row.add_child(stop)

		_notice(body, "Hay una partida en camino %s."
			% sim.parajes.place_name(sim.scout_order, sim.home_position),
			UISkin.OCHRE)

	_text(body, "Los %d de exploración van adonde les mandes. No traen comida: "
		% explorers + "traen mapa, y con él los sitios donde habrá comida.", true)


func _ground_name(ground: Traversal.Ground) -> String:
	match ground:
		Traversal.Ground.ARENA: return "arena"
		Traversal.Ground.ROCA: return "roca desnuda"
		Traversal.Ground.CANCHAL: return "canchal suelto"
		Traversal.Ground.MARISMA: return "marisma"
		_: return "pasto"


## La ficha de un paraje: lo que da, lo que queda y qué se puede mandar hacer.
##
## Es la ventana donde el clic se convierte en orden. Hasta ahora pinchar en
## el mundo sólo servía para MIRAR —una cueva, un recurso, una persona— y el
## jugador no tenía forma de decir «id a trabajar ahí». Aquí sí.
func show_paraje(paraje: Paraje) -> void:
	# Solo se redibuja la mancha 3D cuando cambia el paraje, no en cada
	# repintado en vivo. `show_extent` recorre y drapea toda la huella sobre
	# el terreno -caro-, y el refresco automático llama a esta función dos
	# veces por segundo mientras la ficha está abierta: repetirlo sin
	# necesidad era el hipo que se sentía como si la cámara dejara de
	# responder, justo mientras esta ficha estaba activa y ninguna otra.
	var is_new_paraje := shown_paraje != paraje
	shown_paraje = paraje
	var body := _window("paraje", paraje.name_text)
	_clear(body)

	# La mancha de terreno que ocupa, SOLO mientras su ficha esté abierta. Una
	# capa permanente sobre el paisaje lo tapa, y el paisaje es medio juego.
	if is_new_paraje and markers and sim:
		markers.show_extent(paraje, sim.terrain(), field)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	# Varios oficios pueden coincidir en el mismo trozo de monte -un cotarro
	# con caza, avellanas y buena piedra a la vez-, y se leen como UN SOLO
	# paraje: un marcador, una ficha con todo junto, aunque por debajo sigan
	# siendo registros separados -cada uno con su propio reparto de trabajo,
	# que es lo que de verdad decide a quién se manda adónde.
	var away := int(paraje.distance_from(sim.home_position))
	var activities: Array[String] = []
	for activity_key: int in paraje.activities:
		activities.append(Subsistence.activity_name(
			activity_key as Subsistence.Activity))
	if activities.is_empty():
		activities.append(Subsistence.activity_name(paraje.activity))
	_heading(body, "%s · a %d m del abrigo" % [", ".join(activities), away])

	var walking := int(float(away) / maxf(sim.walk_speed, 1.0) / 60.0)
	_text(body, "Se tarda cerca de %d minutos de reloj en llegar, ida sola."
		% maxi(walking, 1), true)

	# Y lo que hay, UNA sola vez: `fill_contents` ya recorre las cinco
	# actividades de este punto, así que no hay una lista por oficio que
	# repetir. Los botones de "qué se hace" se fueron a peticion expresa:
	# la ficha es para MIRAR el sitio; a quién se manda se decide en el
	# panel de trabajos.
	_paraje_contents(body, paraje)

	_heading(body, "CÓMO SE ENCONTRÓ")
	_text(body, "La banda lo dio por conocido el día %d. Un sitio deja de ser "
		% paraje.found_day
		+ "monte y pasa a tener nombre cuando se ha trabajado lo bastante como "
		+ "para volver a él a propósito.", true)


## Lo que se sabe de una cumbre, y la decisión de intentarla.
##
## Una cumbre no es un tajo: no tiene contenidos ni cuadrilla. Tiene altura,
## dureza y una pregunta —¿la intentamos?—, y hasta ahora esa pregunta la
## contestaba la banda sola sin que el jugador pudiera meterse.
func show_peak(peak: Dictionary) -> void:
	shown_peak = peak
	if sim == null or peak.is_empty():
		return

	var where := sim.parajes.place_name(peak["pos"] as Vector3, sim.home_position)
	var body := _window("cima", "Cumbre %s" % where)
	_clear(body)

	var rise := float(peak.get("rise", 0.0))
	var hardness := float(peak.get("hard", 0.0))
	var away := int((peak["pos"] as Vector3).distance_to(sim.home_position))
	_heading(body, "Se levanta %d m sobre el valle · a %d m del abrigo"
		% [int(rise), away])

	_bar(body, "Dureza", hardness)
	_text(body, _peak_hardness_text(hardness), true)

	# Quién de la banda se atreve, dicho antes de pulsar nada: el botón que
	# falla sin avisar no informa, castiga.
	_heading(body, "QUIÉN PUEDE")
	var climber := sim.climber_for(peak)
	if Ascent.needs_gear(hardness):
		_text(body, "Nadie: esto no es cuestión de pericia. Pide equipo que "
			+ "todavía no se sabe hacer.", true)
	elif climber == null:
		_text(body, "Nadie de la banda tiene la pericia que pide.", true)
	else:
		var task := Profession.task_id(Profession.Job.EXPLORACION,
			Profession.Speciality.ASCENSION)
		_text(body, "%s, con %d%% de ascensión, es quien mejor la ve."
			% [climber.given_name, int(climber.skill_in(task) * 100.0)], true)

	_heading(body, "QUÉ SE HACE")
	var attempt := Button.new()
	attempt.text = "Intentar cima"
	attempt.custom_minimum_size = Vector2(140, 26)
	attempt.pressed.connect(func() -> void:
		var problem := sim.order_ascent(peak)
		_peak_notice = problem if not problem.is_empty() else ""
		_peak_ordered = problem.is_empty()
		show_peak(peak))
	body.add_child(attempt)

	if _peak_ordered and _peak_notice.is_empty():
		_notice(body, "Orden dada: alguien sale a por ella.", UISkin.OCHRE)
	elif not _peak_notice.is_empty():
		_notice(body, _peak_notice, UISkin.ALARM)


## En palabras, que es como se decide de verdad si se manda a alguien.
func _peak_hardness_text(hardness: float) -> String:
	if Ascent.needs_gear(hardness):
		return "Pared. No se sube con lo que hay en esta época."
	if hardness > 0.7:
		return "Muy dura: solo para quien lleve años subiendo, y con compañía."
	if hardness > 0.45:
		return "Seria. Un novato se queda a media pared."
	if hardness > 0.25:
		return "Se sube con maña, sin más."
	return "Un paseo cuesta arriba."


## Los parajes que la banda conoce y ha bautizado.
##
## Un sitio con nombre es un sitio que existe. Hasta aquí los parajes vivían
## en el mundo —marcadores que hay que ir a buscar con la cámara— y no había
## forma de responder «¿qué conocemos?» sin dar una vuelta por el valle.
func show_places() -> void:
	var body := _window("parajes", "Parajes")
	_clear(body)
	if sim == null or sim.parajes == null:
		_text(body, "Sin asentamiento.")
		return

	var places := sim.parajes.list
	if places.is_empty():
		_text(body, "Todavía no hay ningún paraje con nombre. Se bautizan "
			+ "solos cuando la banda conoce un sitio lo bastante bien como "
			+ "para volver a él sin pensarlo.", true)
		return

	_heading(body, "%d PARAJES CONOCIDOS" % places.size())
	_text(body, "Ordenados por cercanía. Pincha uno para verlo y mandar gente.",
		true)

	# Por cercanía: el que está a diez minutos importa más que el que está a
	# dos horas, y es como los tiene ordenados la cabeza de cualquiera
	var sorted: Array[Paraje] = []
	sorted.assign(places)
	sorted.sort_custom(func(a: Paraje, b: Paraje) -> bool:
		return a.distance_from(sim.home_position) < b.distance_from(sim.home_position))

	var index := 0
	for paraje: Paraje in sorted:
		_place_row(body, paraje, index)
		index += 1


## Una fila de paraje: qué es, a cuánto está y cómo anda de existencias.
func _place_row(body: VBoxContainer, paraje: Paraje, index: int) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UISkin.row_box(
		UISkin.SURFACE if index % 2 == 0 else UISkin.GROUND.lightened(0.03)))
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			show_paraje(paraje))
	body.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)

	var icon := MateriaIcon.for_materia(paraje.kind)
	icon.custom_minimum_size = Vector2(COL_ICON - 4, COL_ICON - 4)
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = paraje.name_text
	name_label.custom_minimum_size = Vector2(170, 0)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.clip_text = true
	if paraje.chosen:
		name_label.add_theme_color_override("font_color", UISkin.OCHRE)
	row.add_child(name_label)

	var away := Label.new()
	away.text = "%d m" % int(paraje.distance_from(sim.home_position))
	away.custom_minimum_size = Vector2(56, 0)
	away.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	away.add_theme_font_size_override("font_size", 11)
	away.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(away)

	var note := Label.new()
	note.add_theme_font_size_override("font_size", 10)
	note.clip_text = true
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	# El estado cambia con la temporada y con quien esté trabajando ahí, así
	# que va atado: se refresca sin reconstruir la lista
	_bind(note, func() -> void:
		if paraje.resting:
			note.text = "agotado, se está reponiendo"
			note.add_theme_color_override("font_color", UISkin.ALARM)
		elif paraje.chosen:
			note.text = "elegido para %s" % Subsistence.activity_name(
				paraje.activity).to_lower()
			note.add_theme_color_override("font_color", UISkin.OCHRE)
		else:
			note.text = Subsistence.activity_name(paraje.activity).to_lower()
			note.add_theme_color_override("font_color", UISkin.INK_FAINT))

	frame.tooltip_text = "%s\nDescubierto el día %d · %s\n%s" % [
		paraje.name_text, paraje.found_day,
		Materia.material_name(paraje.kind),
		"Se ha dejado descansar." if paraje.resting
			else "Pincha para verlo y mandar gente."]


## Qué hay en un paraje, y cuánto de eso se sabe.
##
## Encontrar un sitio y conocerlo son dos cosas. Desde lejos se ve que aquello
## es un avellanar; lo que además haya allí —leña, fibra, una veta de ocre—
## sólo se sabe yendo a mirar. Por eso las incógnitas salen como «???»: no son
## un hueco, son trabajo pendiente, y son la razón de mandar una batida a un
## sitio que ya está en el mapa.
func _paraje_contents(body: VBoxContainer, paraje: Paraje) -> void:
	var rows := paraje.listing()
	if rows.is_empty():
		return

	var known := paraje.known_fraction()
	_heading(body, "QUÉ HAY AQUÍ · SE SABE EL %.0f%%" % (known * 100.0))
	_bar(body, "Conocido", known)

	if paraje.has_unknowns():
		_text(body, "Quedan cosas por averiguar. Una batida aquí resuelve una "
			+ "cada jornada, empezando por lo que más abunde.", true)
	else:
		_text(body, "Sitio conocido a fondo: no queda nada que averiguar.", true)

	# La carne fresca YA SABIDA no sale aquí: lo que hay que ver es qué
	# animal es -corzo, jabalí...-, y eso lo dice la sección FAUNA de más
	# abajo con su propio icono, no una fila con el icono de una tajada.
	# Pero mientras NO se sabe, la fila se queda -con su "???"-, porque es
	# la única pista de que ahí hay caza por descubrir: quitarla del todo
	# borraba también lo que faltaba por saber, no solo lo ya sabido.
	var index := 0
	for entry: Dictionary in rows:
		if entry["kind"] as Materia.Kind == Materia.Kind.CARNE \
				and bool(entry["sabido"]):
			continue
		_content_row(body, entry, index, paraje)
		index += 1

	_fauna_section(body, paraje)


## Qué animales hay, aparte -no dentro de la fila de «carne fresca».
##
## Comparten cesto en el almacén -ahí SÍ es una sola ración indistinta- pero
## no comparten fila aquí: un corzo no se lee ni se dibuja como un jabalí, y
## meterlos en la línea de la carne con su icono de tajada era mentir sobre
## qué se ha visto. Solo aparece si la carne YA se sabe -ver `_content_row`-,
## que es la misma incógnita: no se sabe qué animal hay hasta que se mira.
func _fauna_section(body: VBoxContainer, paraje: Paraje) -> void:
	var carne_sabido := false
	for entry: Dictionary in paraje.listing():
		if entry["kind"] as Materia.Kind == Materia.Kind.CARNE:
			carne_sabido = bool(entry["sabido"])
			break
	if not carne_sabido:
		return

	var species := Fauna.species_at(paraje.position, GameState.season)
	if species.is_empty():
		return

	_heading(body, "FAUNA")
	for name: String in species:
		_fauna_row(body, name)


## Una línea de animal: su propio icono, no el de la carne.
func _fauna_row(body: VBoxContainer, species: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	var icon := MateriaIcon.for_fauna(species)
	icon.custom_minimum_size = Vector2(COL_ICON - 4, COL_ICON - 4)
	row.add_child(icon)

	var name_label := Label.new()
	name_label.text = species.capitalize()
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", UISkin.INK)
	row.add_child(name_label)


## Una línea de material del paraje, sabido o por saber.
##
## La cantidad se pregunta EN VIVO a este sitio -`field.stock_fraction` de
## su propia celda-, no a la foto fija de cuando se bautizó ni a lo que le
## queda a la banda entera. Antes esta fila usaba la abundancia congelada
## de la creación mientras la cabecera de la ficha preguntaba por toda la
## comarca con `remaining_units`: un material podía salir "bastante" aquí y
## "esquilmado" dos líneas más arriba, sobre el mismo material y el mismo
## sitio. Con una sola pregunta, una sola respuesta.
func _content_row(body: VBoxContainer, entry: Dictionary, index: int,
		paraje: Paraje) -> void:
	var kind := entry["kind"] as Materia.Kind
	var sabido := bool(entry["sabido"])

	var stock := float(entry["abundancia"])
	# La leña y la fibra no tienen actividad propia -salen de cualquier
	# sitio de paso, ver `Parajes.activity_for_kind`- pero eso no puede
	# significar que se queden sin cifra: se cuentan con la actividad DEL
	# PROPIO PARAJE, que es una vara de medir razonable -un hayedo bien
	# surtido tiene tambien mas leña a mano que uno esquilmado.
	var activity := Parajes.activity_for_kind(kind)
	if activity < 0:
		activity = paraje.activity as int
	if sabido and field:
		# De TODA la mancha, no de la celda del centro: la cuadrilla se
		# reparte por el sitio y gasta las de alrededor, así que mirando
		# solo el centro la cifra no bajaba nunca.
		stock = field.stock_fraction_around(activity as Subsistence.Activity,
			paraje.position, paraje.extent)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UISkin.row_box(
		UISkin.SURFACE if index % 2 == 0 else UISkin.GROUND.lightened(0.03)))
	body.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)

	# El icono se ve SIEMPRE, aunque no se sepa cuánto hay: se ha visto que
	# allí hay algo, y de qué. Lo que falta es la medida, no la existencia.
	var icon := MateriaIcon.for_materia(kind)
	icon.custom_minimum_size = Vector2(COL_ICON - 4, COL_ICON - 4)
	icon.modulate = Color(1, 1, 1, 1.0 if sabido else 0.35)
	row.add_child(icon)

	# El nombre NO se recorta: el ancho de columna fijo era lo que clavaba el
	# contenido a un cesto que no le entraba con nombres largos.
	var name_label := Label.new()
	name_label.text = Materia.material_name(kind) if sabido else "???"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color",
		UISkin.INK if sabido else UISkin.INK_FAINT)
	row.add_child(name_label)

	var esquilmado := sabido and activity >= 0 and stock < 0.4
	var amount := Label.new()
	if not sabido:
		amount.text = "por saber"
		amount.add_theme_color_override("font_color", UISkin.INK_FAINT)
	else:
		# La cantidad de verdad, no solo la palabra: cuanto queda de ESTE
		# material en ESTE sitio, con la misma cuenta que usa la banda para
		# decidir si merece el viaje -ni la foto fija de cuando se bautizo
		# ni la suma de toda la comarca, que es lo que contradecia esta
		# fila con la cabecera del paraje.
		var quantity := 0.0
		if sim and activity >= 0:
			quantity = sim.remaining_units_in(paraje,
				activity as Subsistence.Activity, kind)
		if quantity >= 1.0:
			amount.text = "~%.0f %s" % [quantity, Materia.unit_name(kind)]
		elif quantity > 0.05:
			amount.text = "menos de 1 %s" % Materia.unit_name(kind)
		else:
			# Sin una cifra fiable para este material -no todos tienen
			# rendimiento tabulado-, se cae a la palabra de siempre.
			amount.text = "esquilmado" if esquilmado else _abundance_word(stock)
		amount.add_theme_color_override("font_color",
			UISkin.ALARM if esquilmado else UISkin.coverage_color(stock * 2.0))
	amount.add_theme_font_size_override("font_size", 11)
	# Fija y no expansiva: lo que pide sitio de verdad es el nombre. Mas
	# ancha que antes -"~120 raciones" no cabe en lo que bastaba para "a
	# manta".
	amount.custom_minimum_size = Vector2(130, 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)

	frame.tooltip_text = "%s\n%s%s" % [
		Materia.material_name(kind) if sabido else "Algo que no se ha mirado",
		Materia.describe(kind) if sabido
			else "Se sabe que hay algo, no cuánto ni de qué. Manda una batida.",
		"\n⚠ Esquilmado: se repone, pero despacio." if esquilmado else ""]


## Cuánto hay, dicho como lo diría alguien.
##
## Nadie dice «abundancia 0,43». Se dice que hay mucho, o que hay para un
## apaño, y esa es la información con la que se decide si merece el viaje.
func _abundance_word(amount: float) -> String:
	if amount > 0.55:
		return "a manta"
	if amount > 0.35:
		return "bastante"
	if amount > 0.18:
		return "lo justo"
	return "cuatro cosas"


## Reparto de la mano de obra, persona a persona.
##
## Es una REJILLA: una fila por persona, una columna por oficio, y en cada
## casilla con cuántas ganas lo hace. Sustituye a los botones de más y menos,
## que tenían tres problemas que fueron saliendo uno detrás de otro: sumar a
## un oficio le robaba gente a otro sin avisar, no había forma de ver quién
## podía hacer qué, y cuando el botón se apagaba no decía por qué.
##
## Aquí las tres cosas se ven de un vistazo. Un guion es «no lo hace»; una
## casilla apagada es «no puede», y basta mirar la fila para saber por qué.
func show_jobs() -> void:
	var body := _window("trabajos", "Trabajos", JOBS_WIDTH)
	_clear(body)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	_heading(body, "")
	var tally: Label = body.get_child(body.get_child_count() - 1)
	_bind(tally, func() -> void:
		tally.text = "%d personas · %d sin oficio" % [
			sim.population(), sim.idle_count()])
	_legend(body)

	_job_grid(body)

	_text(body, "Cada cual hace lo que tiene MÁS ARRIBA de lo que puede. Si "
		+ "alguien lleva recolección en 1 y exploración en 2, recolecta: para "
		+ "que salga a explorar, súbele la exploración o bájale la otra.", true)
	_text(body, "Dentro de un oficio, todas las especialidades al mismo nivel "
		+ "es «lo que haga falta»: cada jornada se hace la que más falta haga. "
		+ "Bajar una y subir otra es lo que convierte a alguien en artesano.",
		true)

	_heading(body, "CÓMO FUNCIONA")
	_text(body, "Nadie «es» cazador: la banda reparte el trabajo cada mañana "
		+ "según lo que cada cual esté dispuesto a hacer. Por eso un crío que "
		+ "crece o alguien que deja de criar entran solos en los trabajos que "
		+ "ya tenían marcados.", true)
	_text(body, "El hogar es el único con mínimo: si nadie lo atiende, la banda "
		+ "saca a quien menos ganas tenga de lo suyo y lo anota en la crónica. "
		+ "Sin fuego no se cocina, no se seca la carne y no avanza ninguna obra.",
		true)


## La leyenda de los numeros. Sin ella la rejilla es una cuadricula de digitos
## sueltos: nadie adivina que 1 es mas que 3.
func _legend(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	for entry: Array in [
		["1", "antes que nada", UISkin.OCHRE],
		["2", "si hace falta", UISkin.INK],
		["3", "sólo si no hay otra", UISkin.INK_SOFT],
		["—", "no lo hace", UISkin.INK_FAINT],
	]:
		var chip := Label.new()
		chip.text = "%s · %s" % [entry[0], entry[1]]
		chip.add_theme_font_size_override("font_size", 10)
		chip.add_theme_color_override("font_color", entry[2] as Color)
		row.add_child(chip)

	_text(body, "Una fila por persona y una casilla por tarea. Pincha para "
		+ "cambiar: se rueda por los tres niveles y vuelve a «no lo hace». Un "
		+ "punto apagado es que esa persona NO puede con ese oficio —pásale el "
		+ "ratón por encima y te dice por qué—. La última columna es lo que "
		+ "está haciendo hoy, y cambia sola.", true)
	_spec_legend(body)


## Qué es cada abreviatura de la cabecera.
##
## Las columnas miden 34 px, que no dan para «Cordelería»; y esperar que el
## jugador adivine qué es «Cor» es pedirle demasiado. Se traducen todas aquí,
## una vez, agrupadas por oficio.
func _spec_legend(body: VBoxContainer) -> void:
	for job_key: int in GRID_JOBS:
		var job := job_key as Profession.Job
		var specialities := Profession.specialities_of(job)
		if specialities.is_empty():
			continue

		var parts: Array[String] = []
		for speciality: int in specialities:
			parts.append("%s %s" % [
				String(SPECIALITY_SHORT.get(speciality, "?")),
				Profession.speciality_name(speciality as Profession.Speciality)])

		var label := Label.new()
		label.text = "%s:  %s" % [Profession.job_name(job), "   ".join(parts)]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", UISkin.FLINT)
		body.add_child(label)


# ------------------------------------------------------------ rastros ----

## Por dónde ha andado la banda y qué ha hecho en cada sitio.
##
## Es la ventana para mirar el juego por dentro. Responde preguntas que si no
## hay que adivinar: ¿la recolección no trae nada porque va lejos o porque da
## vueltas cerca? ¿el batidor repite zona? ¿la caza cruza el río o lo rodea?
##
## Un oficio cada vez, a propósito: con quince rastros encima no se ve nada, y
## la pregunta siempre es sobre un oficio concreto.
func show_trails() -> void:
	var body := _window("rastros", "Rastros")
	_clear(body)
	if sim == null or trails == null:
		_text(body, "Sin asentamiento.")
		return

	# Los atascos, contados por motivo. Un atasco es una anécdota; veinte del
	# mismo motivo son un fallo con nombre, y esta es la pantalla donde eso
	# tiene que verse.
	if not sim.stuck_tally.is_empty():
		var total := 0
		for why: String in sim.stuck_tally:
			total += int(sim.stuck_tally[why])
		_heading(body, "ATASCOS: %d" % total)
		_text(body, "Nadie debería quedarse atascado. Cuando pasa, aquí sale "
			+ "por qué — y el motivo apunta a la pieza que hay que arreglar.",
			true)
		var reasons: Array[String] = []
		reasons.assign(sim.stuck_tally.keys())
		reasons.sort_custom(func(a: String, b: String) -> bool:
			return int(sim.stuck_tally[a]) > int(sim.stuck_tally[b]))
		for why: String in reasons:
			_text(body, "   %dx  %s" % [int(sim.stuck_tally[why]), why])

	_heading(body, "QUÉ OFICIO SE MIRA")
	_text(body, "Se pinta el camino de todo el que hace ese oficio, uno de "
		+ "cada color. Los rombos marcan los sitios donde pasó algo.", true)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	for job_key: int in GRID_JOBS:
		var job := job_key as Profession.Job
		var button := Button.new()
		button.text = String(JOB_SHORT.get(job_key, "?"))
		button.custom_minimum_size = Vector2(CELL_COL + 8, 22)
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = Profession.job_name(job)
		if trails.showing() == job_key:
			button.add_theme_stylebox_override("normal",
				UISkin.button_box("pressed"))
			button.add_theme_color_override("font_color", UISkin.OCHRE)
		button.pressed.connect(func() -> void:
			trails.show_job(job_key, sim.people, sim.terrain())
			show_trails())
		row.add_child(button)

	var off := Button.new()
	off.text = "quitar"
	off.custom_minimum_size = Vector2(52, 22)
	off.add_theme_font_size_override("font_size", 10)
	off.pressed.connect(func() -> void:
		trails.clear()
		show_trails())
	row.add_child(off)

	if trails.showing() < 0:
		_text(body, "Ningún rastro pintado.", true)
		return

	var job := trails.showing() as Profession.Job
	_heading(body, Profession.job_name(job).to_upper())
	# Por el oficio CON EL QUE SE SALIO, no por el que se tenga hoy. Cuando la
	# despensa llega al tope que puso el jugador, el reparto saca de golpe a
	# toda la recoleccion, y filtrando por el oficio de ahora esta pantalla se
	# quedaba vacia el mismo dia: parecia que se hubieran borrado los rastros.
	var told_someone := false
	for person: Inhabitant in sim.people:
		if not _walked_as(person, job):
			continue
		told_someone = true
		_trail_summary(body, person, job)
	if not told_someone:
		_text(body, "Nadie ha salido a esto todavía.", true)


## Si esta persona ha andado alguna vez con este oficio, lo tenga ahora o no.
func _walked_as(person: Inhabitant, job: Profession.Job) -> bool:
	if not person.journey.is_empty() 			and int(person.journey.get("job", person.job)) == int(job):
		return true
	for trip: Dictionary in person.journeys:
		if int(trip.get("job", person.job)) == int(job):
			return true
	return false


## El resumen de una persona: sus salidas, una por una.
##
## Una línea por SALIDA, y no todo junto. «2 jornadas de ascensión» no
## distingue haber coronado dos picos de haberse dado la vuelta dos veces a
## media pared, y son partidas distintas: en una la banda tiene el valle
## cartografiado y en la otra ha perdido dos días.
func _trail_summary(body: VBoxContainer, person: Inhabitant,
		job: Profession.Job) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	body.add_child(head)

	# La misma pastilla de color que su línea en el mundo, para poder
	# emparejar la ficha con el rastro sin contar rastros
	var chip := ColorRect.new()
	chip.color = TrailView.colour_for(person.id)
	chip.custom_minimum_size = Vector2(10, 10)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(chip)

	var name_label := Label.new()
	name_label.text = person.given_name
	name_label.custom_minimum_size = Vector2(NAME_COL, 0)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", UISkin.OCHRE)
	head.add_child(name_label)

	# El total sale de las SALIDAS y no del rastro dibujado: el rastro es un
	# anillo de trescientos puntos que se va tirando lo viejo, y por eso una
	# expedición larga podía acabar contando cero.
	var total := 0.0
	var farthest := 0.0
	var outings := 0
	var mine: Array[Dictionary] = []
	for trip: Dictionary in person.journeys:
		if int(trip.get("job", person.job)) != int(job):
			continue
		mine.append(trip)
		outings += 1
		total += float(trip["metres"])
		farthest = maxf(farthest, float(trip["farthest"]))
	var live := not person.journey.is_empty() 		and int(person.journey.get("job", person.job)) == int(job)
	if live:
		total += float(person.journey["metres"])
		farthest = maxf(farthest, float(person.journey["farthest"]))

	var stats := Label.new()
	stats.text = "%d salidas · %.1f km · lo más lejos %d m" % [
		outings, total / 1000.0, int(farthest)]
	stats.add_theme_font_size_override("font_size", 10)
	stats.add_theme_color_override("font_color", UISkin.INK_SOFT)
	head.add_child(stats)

	# En qué se le van las horas, que es otra pregunta
	for entry: Dictionary in person.work_summary():
		_work_line(body, entry)

	# Y las salidas, de la última a la primera: lo de hoy interesa más
	if live:
		_journey_line(body, person.journey, true)
	var told := 0
	for i in range(mine.size() - 1, -1, -1):
		if told >= 8:
			break
		told += 1
		_journey_line(body, mine[i], false)

	if told == 0 and not live:
		_text(body, "   No ha salido todavía.", true)


## Una salida: cuándo, adónde, cuánto anduvo y cómo acabó.
func _journey_line(body: VBoxContainer, trip: Dictionary, open_now: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	var when := Label.new()
	var day := int(trip["day"])
	var ended := int(trip["ended"])
	when.text = "   d%d" % day if ended == day else "   d%d-%d" % [day, ended]
	when.custom_minimum_size = Vector2(56, 0)
	when.add_theme_font_size_override("font_size", 10)
	when.add_theme_color_override("font_color", UISkin.INK_FAINT)
	row.add_child(when)

	var what := Label.new()
	what.text = String(trip["kind"])
	what.custom_minimum_size = Vector2(78, 0)
	what.add_theme_font_size_override("font_size", 11)
	what.add_theme_color_override("font_color", UISkin.FLINT)
	what.clip_text = true
	row.add_child(what)

	# Los metros de la salida, que es lo que dice si fue un paseo o una
	# jornada de verdad
	var walked := Label.new()
	var metres := float(trip["metres"])
	walked.text = "%.1f km" % (metres / 1000.0) if metres >= 1000.0 \
		else "%d m" % int(metres)
	walked.custom_minimum_size = Vector2(56, 0)
	walked.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	walked.add_theme_font_size_override("font_size", 10)
	walked.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(walked)

	var tale := Label.new()
	if open_now:
		tale.text = "en marcha · lo más lejos %d m" % int(float(trip["farthest"]))
		tale.add_theme_color_override("font_color", UISkin.OCHRE)
	else:
		tale.text = "%s · %s" % [String(trip["place"]), String(trip["outcome"])]
		# Coronar y no coronar se distinguen de un vistazo: es la diferencia
		# entre traer el valle cartografiado y haber perdido dos días
		tale.add_theme_color_override("font_color",
			UISkin.ALARM if String(trip["outcome"]).begins_with("NO ")
			else UISkin.INK)
	tale.add_theme_font_size_override("font_size", 10)
	tale.clip_text = true
	tale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tale)


## Una línea del libro: la tarea, las horas y lo que ha salido de ellas.
func _work_line(body: VBoxContainer, entry: Dictionary) -> void:
	var task := int(entry["task"])
	var hours := float(entry["hours"])
	var gained := entry["gained"] as Dictionary
	var deeds := entry.get("deeds", {}) as Dictionary

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	var what := Label.new()
	what.text = "   %s" % Profession.task_name(task)
	what.custom_minimum_size = Vector2(NAME_COL + 40, 0)
	what.add_theme_font_size_override("font_size", 11)
	what.clip_text = true
	row.add_child(what)

	var spent := Label.new()
	spent.text = _spell_hours(hours)
	spent.custom_minimum_size = Vector2(64, 0)
	spent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spent.add_theme_font_size_override("font_size", 11)
	spent.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(spent)

	# Lo que ha salido de esas horas. Vacío es una respuesta, y de las
	# importantes: seis horas de pesca sin un solo pez es un fallo, no un
	# apunte que sobre.
	var parts: Array[String] = []
	for key: int in gained:
		var units := float(gained[key])
		if units < 0.05:
			continue
		parts.append("%.0f %s" % [units, SettlementSim.logged_name(key).to_lower()])

	# Y lo hecho que no es material. Medio trabajo de la banda no vuelve con
	# nada encima —el hogar mantiene el fuego, el explorador trae mapa—, y
	# contando sólo unidades esas tareas salían con seis horas y cero. Eso se
	# lee como una avería cuando es que están funcionando.
	for deed: String in deeds:
		var times := int(deeds[deed])
		parts.append(deed if times <= 1 else "%s (x%d)" % [deed, times])

	var got := Label.new()
	if parts.is_empty():
		# Ahora sí: sin material y sin nada hecho, en horas de trabajo, es un
		# fallo y se dice en rojo
		got.text = "SIN NADA" if hours > 1.0 else ""
		got.add_theme_color_override("font_color",
			UISkin.ALARM if hours > 4.0 else UISkin.INK_FAINT)
	else:
		got.text = ", ".join(parts)
		got.add_theme_color_override("font_color", UISkin.INK)
	got.add_theme_font_size_override("font_size", 11)
	got.clip_text = true
	got.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(got)


## Las horas, dichas como las diría alguien.
##
## «14 h» no se lee: hay que traducirlo a jornadas mentalmente cada vez. En
## jornadas de trabajo se entiende de un vistazo cuánto es mucho.
func _spell_hours(hours: float) -> String:
	if hours < 1.0:
		return "%d min" % int(hours * 60.0)
	if hours < 10.0:
		return "%.1f h" % hours
	return "%.1f jorn." % (hours / SettlementSim.HORAS_UTILES)


## El nombre del sitio, si hay parajes puestos.
func parajes_name(point: Vector3) -> String:
	if sim == null or sim.parajes == null:
		return "(%d, %d)" % [int(point.x), int(point.z)]
	return sim.parajes.place_name(point, sim.home_position)


## Las actividades que se aprenden, para poder listar lo que sabe cada cual.
const ALL_ACTIVITIES := [
	Subsistence.Activity.RECOLECCION, Subsistence.Activity.CAZA,
	Subsistence.Activity.PESCA, Subsistence.Activity.MARISQUEO,
	Subsistence.Activity.MATERIA_PRIMA,
]

## Los oficios de la rejilla, en orden. `OCIOSO` no: no es un destino, es lo
## que queda cuando no hay ninguno marcado.
const GRID_JOBS := [
	Profession.Job.RECOLECCION, Profession.Job.CAZA, Profession.Job.RIBERA,
	Profession.Job.MANUFACTURA,
	Profession.Job.EXPLORACION, Profession.Job.HOGAR,
]

const JOB_SHORT := {
	Profession.Job.RECOLECCION: "Rec", Profession.Job.CAZA: "Caz",
	Profession.Job.RIBERA: "Rib",
	Profession.Job.MANUFACTURA: "Man", Profession.Job.EXPLORACION: "Exp",
	Profession.Job.HOGAR: "Hog",
}

## Los enums `Job` y `Speciality` empiezan los dos en cero, así que sus
## valores chocan: en un solo diccionario unas claves pisaban a otras.
const SPECIALITY_SHORT := {
	Profession.Speciality.TALLA: "Tal", Profession.Speciality.ASTA: "Ast",
	Profession.Speciality.PELETERIA: "Pel", Profession.Speciality.CORDELERIA: "Cor",
	Profession.Speciality.BATIDA: "Bat", Profession.Speciality.EXPEDICION: "Exd",
	Profession.Speciality.ASCENSION: "Asc",
	Profession.Speciality.FORRAJEO: "For", Profession.Speciality.LENA_FIBRA: "Len",
	Profession.Speciality.CANTERA: "Can",
	Profession.Speciality.TRAMPAS: "Tra", Profession.Speciality.CAZA_MENOR: "Men",
	Profession.Speciality.CAZA_MAYOR: "May",
	Profession.Speciality.MARISQUEO: "Mar", Profession.Speciality.ORILLA: "Ori",
	Profession.Speciality.ALTURA: "Alt",
}

## Anchos de la tabla de trabajos, medidos y no a ojo.
##
## Cada persona sale UNA vez, en su fila, con las doce tareas de la banda a lo
## largo. Se probó a partirlo en una tabla por oficio y salió mucho peor: la
## misma persona aparecía en cinco bloques, cada bloque dejaba medio panel en
## blanco, y no había forma de comparar a dos personas de un vistazo, que es
## justo para lo que sirve esta pestaña.
##
## 92 de nombre + doce casillas de 34 + los huecos + la columna de «hoy» suman
## 634, y de ahí sale el ancho de la ventana.
const NAME_COL := 92
const CELL_COL := 34
const TODAY_COL := 44

## Hueco entre casillas del mismo oficio, y entre un oficio y el siguiente.
##
## Son distintos a propósito: es lo único que agrupa las cuatro casillas de
## manufactura y las separa de las tres de exploración sin dibujar una sola
## línea. Con un hueco único la fila es una ristra de doce dígitos sueltos.
const CELL_GAP := 2
const GROUP_GAP := 10


## Reparto de la mano de obra: una fila por persona, doce columnas de tarea.
func _job_grid(body: VBoxContainer) -> void:
	_job_head(body)

	# Los críos no salen hasta que puedan hacer ALGO. Un renglón con las
	# diecisiete casillas cerradas no es información: es una fila que no se
	# puede tocar ocupando sitio, y con tres o cuatro niños en la banda la
	# tabla se llena de gente a la que no se le puede mandar nada.
	var index := 0
	var hidden := 0
	for person: Inhabitant in sim.people:
		if not _can_work_at_all(person):
			hidden += 1
			continue
		_person_row(body, person, index)
		index += 1

	if hidden > 0:
		_text(body, "%d %s todavía demasiado pequeño%s para ningún oficio. %s en "
			% [hidden, "crío" if hidden == 1 else "críos", "" if hidden == 1 else "s",
				"Aparece" if hidden == 1 else "Aparecen"]
			+ "la pestaña de la banda, y entrarán aquí solos al cumplir la edad.",
			true)


## Si esta persona puede hacer HOY algún oficio, el que sea.
##
## Un crío de cuatro años no puede ninguno -el hogar es el más blando y pide
## cinco-, así que no tiene sentido enseñarle una fila de casillas cerradas.
func _can_work_at_all(person: Inhabitant) -> bool:
	for job_key: int in Profession.CATALOGUE:
		if job_key == Profession.Job.OCIOSO:
			continue
		if Profession.can_do(job_key as Profession.Job, person):
			return true
	return false


## Las dos filas de cabecera: el oficio arriba, sus especialidades debajo.
func _job_head(body: VBoxContainer) -> void:
	var doing := _task_counts()

	# Fila de oficios. Cada rótulo mide lo que mide su grupo entero, así que
	# «Manufactura» se lee encima de sus cuatro casillas y no encima de una.
	var jobs_row := _grid_row(body)
	for job_key: int in GRID_JOBS:
		var job := job_key as Profession.Job
		var tasks := Profession.tasks_of(job)
		var width := _group_width(tasks.size())
		var full := Profession.job_name(job)

		var label := Label.new()
		# El nombre entero si cabe en el grupo, y la forma corta si no —que la
		# leyenda de arriba traduce—. Recortar «Recolección» a «Recolec…» no le
		# sirve a nadie.
		label.text = full if full.length() * 7 <= width \
			else String(JOB_SHORT.get(job_key, "?"))
		label.custom_minimum_size = Vector2(width, 0)
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", UISkin.OCHRE)
		label.tooltip_text = "%s\n%s" % [full, Profession.job_desc(job)]
		jobs_row.add_child(label)
	_grid_tail(jobs_row, "hoy", UISkin.OCHRE)

	# Fila de especialidades
	var spec_row := _grid_row(body)
	for job_key: int in GRID_JOBS:
		var job := job_key as Profession.Job
		var group := _grid_group(spec_row)
		for task: int in Profession.tasks_of(job):
			var speciality := Profession.task_speciality(task)
			var label := Label.new()
			label.text = String(SPECIALITY_SHORT.get(speciality, "·")) \
				if speciality != Profession.Speciality.NINGUNA else "·"
			label.custom_minimum_size = Vector2(CELL_COL, 0)
			label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 10)
			label.add_theme_color_override("font_color", UISkin.FLINT)
			label.tooltip_text = "%s · %d hoy\n%s" % [
				Profession.task_name(task), int(doing.get(task, 0)),
				Profession.task_desc(task)]
			group.add_child(label)
	_grid_tail(spec_row, "", UISkin.INK_FAINT)


## Una persona: su nombre, sus doce casillas y lo que hace hoy.
func _person_row(body: VBoxContainer, person: Inhabitant, index: int) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UISkin.row_box(
		UISkin.SURFACE if index % 2 == 0 else UISkin.GROUND.lightened(0.03)))
	body.add_child(frame)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GROUP_GAP)
	frame.add_child(row)

	var name_label := Label.new()
	name_label.text = person.given_name
	name_label.custom_minimum_size = Vector2(NAME_COL, 0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.clip_text = true
	name_label.tooltip_text = _skills_text(person)
	row.add_child(name_label)
	# En ocre mientras trabaje, apagado al quedarse ocioso. Va atado para que
	# cambie solo, sin reconstruir la tabla entera.
	_bind(name_label, func() -> void:
		name_label.add_theme_color_override("font_color",
			UISkin.INK if person.job == Profession.Job.OCIOSO else UISkin.OCHRE))

	for job_key: int in GRID_JOBS:
		var job := job_key as Profession.Job
		var group := _grid_group(row)
		var able := Profession.can_do(job, person)
		for task: int in Profession.tasks_of(job):
			group.add_child(_task_cell(person, task, able))

	# Qué hace HOY. Es la columna que cambia sola: la banda reparte cada
	# mañana, y sin esto había que cerrar y abrir el panel para enterarse.
	var today := Label.new()
	today.custom_minimum_size = Vector2(TODAY_COL, 0)
	today.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	today.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	today.add_theme_font_size_override("font_size", 10)
	row.add_child(today)
	_bind(today, func() -> void:
		if person.job == Profession.Job.OCIOSO:
			today.text = "—"
			today.add_theme_color_override("font_color", UISkin.INK_FAINT)
			today.tooltip_text = "Sin oficio: no tiene marcado nada que pueda hacer."
			return
		var speciality := person.current_speciality as Profession.Speciality
		today.text = String(SPECIALITY_SHORT.get(speciality, "")) \
			if speciality != Profession.Speciality.NINGUNA \
			else String(JOB_SHORT.get(person.job, "?"))
		today.add_theme_color_override("font_color", UISkin.OCHRE)
		today.tooltip_text = _doing_text(person))

	# Y si lo que hace HOY no es lo que el jugador puso arriba, se dice por
	# que. Antes se descartaba en silencio y desde fuera parecia que el panel
	# no servia: alguien con la pesca de orilla en 1 aparecia poniendo
	# trampas sin una palabra de explicacion.
	var why := Label.new()
	why.add_theme_font_size_override("font_size", 10)
	why.add_theme_color_override("font_color", UISkin.ALARM)
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	why.clip_text = true
	row.add_child(why)
	_bind(why, func() -> void:
		why.text = _demotion_text(person))


## Por que esta persona no esta haciendo lo que tiene marcado mas arriba.
## Cadena vacia si SI lo esta haciendo, que es lo normal.
func _demotion_text(person: Inhabitant) -> String:
	if sim == null:
		return ""
	var wanted := sim.top_choice(person)
	if wanted < 0:
		return ""
	var doing := Profession.task_id(person.job as Profession.Job,
		person.current_speciality as Profession.Speciality)
	if doing == wanted:
		return ""
	var reason := sim.task_blocked_by(person, wanted)
	if reason.is_empty():
		# Empate: hay otra tarea al mismo nivel y hoy hacia mas falta. Eso no
		# es que se le ignore, es lo que significa poner dos cosas iguales.
		if person.priority_for(doing) == person.priority_for(wanted):
			return ""
		return ""
	return "%s: %s" % [String(SPECIALITY_SHORT.get(
		Profession.task_speciality(wanted), JOB_SHORT.get(
			Profession.task_job(wanted), "?"))), reason]


## Una fila de la rejilla con el hueco del nombre ya puesto, para que las
## cabeceras caigan exactamente encima de las casillas.
func _grid_row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GROUP_GAP)
	body.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(NAME_COL, 0)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(spacer)
	return row


## El grupo de casillas de un oficio dentro de una fila.
func _grid_group(row: HBoxContainer) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", CELL_GAP)
	group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(group)
	return group


## La columna de la derecha, la de «hoy».
func _grid_tail(row: HBoxContainer, text: String, tint: Color) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(TODAY_COL, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", tint)
	row.add_child(label)


## Lo que ocupa el grupo de un oficio: sus casillas más los huecos de dentro.
func _group_width(cells: int) -> int:
	return cells * CELL_COL + (cells - 1) * CELL_GAP


## Una casilla de prioridad. TODAS miden lo mismo, siempre: una tabla con
## botones de anchos distintos se lee torcida.
##
## Quien no puede con el oficio tiene casilla igual pero apagada y sin pulsar,
## no un hueco. Un hueco descuadra la fila y además no dice por qué.
func _task_cell(person: Inhabitant, task: int, able: bool) -> Control:
	var speciality := Profession.task_speciality(task)
	var job := Profession.task_job(task)

	if not able:
		var blocked := Label.new()
		blocked.custom_minimum_size = Vector2(CELL_COL, 22)
		blocked.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		blocked.text = "·"
		blocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		blocked.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		blocked.add_theme_font_size_override("font_size", 11)
		blocked.add_theme_color_override("font_color", UISkin.INK_FAINT)
		blocked.mouse_filter = Control.MOUSE_FILTER_STOP
		blocked.tooltip_text = "%s\n%s no puede: %s" % [
			Profession.task_name(task), person.given_name, _who_cannot(job)]
		return blocked

	var level := person.priority_for(task)
	var doing := person.job == job and person.current_speciality == speciality

	var button := Button.new()
	button.custom_minimum_size = Vector2(CELL_COL, 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 11)
	button.text = "—" if level <= 0 else str(level)
	button.tooltip_text = "%s · %s\n%s" % [
		Profession.task_name(task),
		"no lo hace" if level <= 0 else _level_name(level),
		Profession.task_desc(task)]

	if doing:
		button.add_theme_stylebox_override("normal", UISkin.button_box("pressed"))
		button.add_theme_color_override("font_color", UISkin.OCHRE)
	elif level <= 0:
		button.add_theme_color_override("font_color", UISkin.INK_FAINT)

	var next := (level + 1) % 4
	button.pressed.connect(func() -> void:
		person.set_priority(task, next)
		sim.apply_priorities()
		show_jobs())
	return button


## Por qué alguien no puede con un oficio.
func _who_cannot(job: Profession.Job) -> String:
	var entry: Dictionary = Profession.CATALOGUE[job]
	if bool(entry["mobile"]):
		return "pide adulto de %d a %d años que no esté criando" % [
			int(entry["min_age"]), int(entry["max_age"])]
	return "pide de %d a %d años" % [int(entry["min_age"]), int(entry["max_age"])]


## Cuánta gente está HOY en cada tarea.
func _task_counts() -> Dictionary:
	var out := {}
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.OCIOSO:
			continue
		var task := Profession.task_id(person.job as Profession.Job,
			person.current_speciality as Profession.Speciality)
		out[task] = int(out.get(task, 0)) + 1
	return out


## Lo que esta persona ha aprendido haciendo. Va en el tooltip del nombre: no
## es adorno, entra en el rendimiento, y es la razón por la que mover gente de
## oficio constantemente sale caro.
func _skills_text(person: Inhabitant) -> String:
	var lines: Array[String] = [person.given_name + " sabe hacer:"]
	var any := false
	for activity: int in ALL_ACTIVITIES:
		var value := person.skill_in(activity)
		if value <= 0.505:
			continue
		any = true
		lines.append("  %s · %s (%d%%)" % [
			Subsistence.activity_name(activity as Subsistence.Activity),
			person.skill_label(value), int(value * 100.0)])
	if not any:
		lines.append("  Todavía nada: es lo que se aprende trabajando.")
	return "\n".join(lines)


## Lo que hay que saber para repartirle trabajo: qué hace hoy y qué se le da
## bien.
func _person_note(person: Inhabitant) -> String:
	var best_name := ""
	var best_value := 0.55
	for activity: int in ALL_ACTIVITIES:
		var value := person.skill_in(activity)
		if value > best_value:
			best_value = value
			best_name = Subsistence.activity_name(activity as Subsistence.Activity)

	if person.nursing:
		return "criando · %d años" % person.age_years
	if person.job == Profession.Job.OCIOSO:
		return "sin oficio · %d años" % person.age_years
	if not best_name.is_empty():
		return "%s · %s" % [_doing_text(person), best_name.to_lower()]
	return "%s · %d años" % [_doing_text(person), person.age_years]


## Qué está haciendo hoy: el oficio, o la especialidad si la tiene.
func _doing_text(person: Inhabitant) -> String:
	if person.current_speciality != Profession.Speciality.NINGUNA:
		return Profession.speciality_name(
			person.current_speciality as Profession.Speciality).to_lower()
	return Profession.job_name(person.job as Profession.Job).to_lower()






## Corto, porque va DENTRO del botón. La explicación entera está en la
## leyenda, arriba del panel.
func _level_name(level: int) -> String:
	match level:
		1: return "primero"
		2: return "si hace falta"
		_: return "último"


## Por qué esta persona no puede con este oficio, en una línea.
func _cannot_because(job: Profession.Job, person: Inhabitant) -> String:
	var entry: Dictionary = Profession.CATALOGUE[job]
	if person.age_years < int(entry["min_age"]):
		return "es un crío (pide %d años)" % int(entry["min_age"])
	if person.age_years > int(entry["max_age"]):
		return "tiene años de más (tope %d)" % int(entry["max_age"])
	if bool(entry["mobile"]) and person.age_group != Inhabitant.Age.ADULTO:
		return "no está para jornadas lejos del campamento"
	if bool(entry["mobile"]) and person.nursing:
		return "está criando, y con un lactante no se sale el día entero"
	return "no cumple lo que pide el oficio"




## Qué materiales concretos hay en los parajes conocidos, y CUÁNTO QUEDA.
##
## Lo que importa es lo que sigue ahí fuera, no lo que ya está guardado: el
## almacén tiene su propia pestaña. Aquí la pregunta es «¿me queda avellana en
## el avellanar o lo hemos dejado seco?».
##
## Solo se listan los materiales que esa actividad da AHORA. El asta aparece
## en invierno y no antes, porque es cuando el ciervo suelta la cuerna; la
## bellota solo en otoño.
func _materials_of(activity: Subsistence.Activity) -> Array[String]:
	if sim == null:
		return []

	var person_days := sim.remaining_person_days(activity)
	if person_days <= 0.0:
		return []

	var lines: Array[String] = []
	var yields: Dictionary = sim._yield_materials(activity)
	for kind: int in yields.keys():
		var k := kind as Materia.Kind
		var left := sim.remaining_units(activity, k)
		if left < 0.5:
			continue

		# Del abrigo solo se dice si va bien o va justo: el detalle esta en su
		# propia pestana, y aqui estorbaria
		var stored := sim.store.amount(k)
		var depot := "nada guardado"
		if stored >= left * 0.5:
			depot = "buena cantidad en el abrigo"
		elif stored >= 1.0:
			depot = "poco en el abrigo"
		elif stored > 0.0:
			depot = "casi nada en el abrigo"

		lines.append("· %s — quedan ~%.0f %s · %s" % [
			Materia.material_name(k), left, Materia.unit_name(k), depot])

	lines.sort()

	# Cuanto aguanta con la gente que hay puesta AHORA. Es la unica cifra que
	# convierte el porcentaje en una decision.
	var workers := 0
	for person: Inhabitant in sim.people:
		if person.has_task and person.activity == activity:
			workers += 1
	if workers > 0:
		lines.append("· Con %d trabajando aguanta ~%d jornadas antes de agotarse."
			% [workers, int(person_days / float(workers))])
	else:
		lines.append("· Sin nadie trabajando: %d jornadas-persona sin tocar."
			% int(person_days))

	return lines
func _speciality_picker(body: VBoxContainer, job: Profession.Job) -> void:
	if sim == null:
		return

	var current := Profession.Speciality.NINGUNA
	for person: Inhabitant in sim.people:
		if person.job == job:
			current = person.speciality as Profession.Speciality
			break

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(14, 0)
	row.add_child(spacer)

	var options: Array = [Profession.Speciality.NINGUNA]
	options.append_array(Profession.specialities_of(job))

	for speciality: int in options:
		var button := Button.new()
		button.text = Profession.speciality_name(speciality as Profession.Speciality)
		button.tooltip_text = Profession.speciality_desc(
			speciality as Profession.Speciality)
		button.toggle_mode = true
		button.button_pressed = current == speciality
		button.add_theme_font_size_override("font_size", 11)
		button.pressed.connect(func() -> void:
			sim.set_speciality(job, speciality as Profession.Speciality)
			show_jobs())
		row.add_child(button)

	# Y qué está haciendo cada cual AHORA, que con rotación no es lo mismo que
	# lo que se ha pedido
	if current == Profession.Speciality.NINGUNA:
		var counts: Dictionary = sim.speciality_counts(job)
		var parts: Array[String] = []
		for speciality: int in counts.keys():
			parts.append("%d en %s" % [counts[speciality],
				Profession.speciality_name(speciality as Profession.Speciality).to_lower()])
		if not parts.is_empty():
			_text(body, "   hoy: " + ", ".join(parts), true)
func show_band() -> void:
	var body := _window("banda", "La banda")
	_clear(body)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	_heading(body, "%d personas · %s (%s) del año %d" % [
		sim.population(), Subsistence.season_name(GameState.season),
		Subsistence.month_name(GameState.season, sim.season_day), GameState.year])
	_text(body, "Reservas: %.0f raciones" % sim.store.food_rations(), true)
	body.add_child(HSeparator.new())

	# Agrupadas por OFICIO, no por actividad. Por actividad se perdía media
	# banda: quien no tiene oficio -los críos que aún no llegan a la edad de
	# nada, y quien está en el hogar- lleva actividad -1, y `activity_name`
	# no tiene nombre para el -1: los metía a todos bajo «Materia prima»,
	# revueltos con los canteros de verdad. Beru y Caro estaban ahí, no
	# desaparecidos. Por oficio cada uno cae donde le toca y los que no
	# tienen ninguno salen juntos y con su nombre.
	var by_job: Dictionary = {}
	for person: Inhabitant in sim.people:
		var list: Array = by_job.get(person.job, [])
		list.append(person)
		by_job[person.job] = list

	for job: int in by_job.keys():
		var list: Array = by_job[job]
		_heading(body, "%s — %d" % [
			Profession.job_name(job as Profession.Job), list.size()])
		for person: Inhabitant in list:
			_band_person_row(body, person)


## Una fila de la banda que abre la ficha de esa persona al pinchar, igual
## que si se le hubiera hecho clic directamente en el mundo.
##
## No se llama `_person_row` a secas: ese nombre ya lo tiene la fila -muy
## distinta, con las doce casillas de oficio- del panel de Trabajos.
func _band_person_row(body: VBoxContainer, person: Inhabitant) -> void:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(frame)

	# Hambre y fatiga son escalas 0-100, no fracciones; la pericia si es
	# una fraccion, y va por actividad
	var nota := " · criando" if person.nursing else ""
	var label := Label.new()
	label.text = "  %s (%s %s, %d)%s · %s · hambre %d · fatiga %d · pericia %d%%" % [
		person.given_name,
		"mujer" if person.sex == Inhabitant.Sex.MUJER else "hombre",
		person.age_name(), person.age_years, nota,
		person.state_name(), int(person.hunger), int(person.fatigue),
		int(float(person.skill.get(person.activity, 0.5)) * 100.0)]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(
		maxf(body.custom_minimum_size.x - 45.0, 200.0), 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UISkin.INK_SOFT)
	frame.add_child(label)

	frame.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			show_person(person))
	frame.tooltip_text = "Pincha para ver su ficha."


# -------------------------------------------------------------- técnicas --

func show_tech() -> void:
	var body := _window("tecnicas", "Técnicas")
	_clear(body)
	if tech == null:
		_text(body, "Sin datos de técnica.")
		return

	_text(body, "En el Paleolítico nadie investiga: se aprende haciendo. Cada "
		+ "técnica sale de acumular jornadas en la actividad que la produce.", true)
	body.add_child(HSeparator.new())

	_fishing_block(body)
	_hunting_block(body)

	_heading(body, "DOMINADAS")
	var any := false
	for t: int in TechTree.CATALOGUE.keys():
		if tech.has(t as TechTree.Tech):
			any = true
			_text(body, "◆ " + TechTree.tech_name(t as TechTree.Tech))
	if not any:
		_text(body, "Ninguna todavía.", true)

	body.add_child(HSeparator.new())
	_heading(body, "AL ALCANCE")
	for t: int in TechTree.CATALOGUE.keys():
		var candidate := t as TechTree.Tech
		if not tech.is_available(candidate):
			continue
		var entry: Dictionary = TechTree.CATALOGUE[candidate]
		var activity: int = entry["practice"]
		_bar(body, TechTree.tech_name(candidate), tech.progress(candidate))
		if activity >= 0:
			_text(body, "   %s · %d de %d jornadas" % [
				Subsistence.activity_name(activity as Subsistence.Activity),
				int(tech.days_in(activity as Subsistence.Activity)),
				int(entry["days"])], true)
		_text(body, "   " + TechTree.tech_desc(candidate), true)

	body.add_child(HSeparator.new())
	_heading(body, "FUERA DE ALCANCE")
	for t: int in TechTree.CATALOGUE.keys():
		var far := t as TechTree.Tech
		if tech.has(far) or tech.is_available(far):
			continue
		var missing: Array[String] = []
		for need: int in (TechTree.CATALOGUE[far]["needs"] as Array):
			if not tech.has(need as TechTree.Tech):
				missing.append(TechTree.tech_name(need as TechTree.Tech))
		_text(body, "· %s — falta: %s" % [
			TechTree.tech_name(far), ", ".join(missing)], true)


## Cómo caza la banda hoy: las tres ramas, lo que rinde cada una y la línea
## de trampas que hay puesta.
##
## Va aquí, al lado de la pesca, porque es la misma pregunta: qué se sabe
## hacer y qué cambia cuando se aprenda lo siguiente. Sin esto, aprender el
## propulsor es una línea en una lista y no un cambio en la jornada.
func _hunting_block(body: VBoxContainer) -> void:
	if sim == null:
		return
	_heading(body, "CAZA")

	for speciality_key: int in [Profession.Speciality.TRAMPAS,
			Profession.Speciality.CAZA_MENOR, Profession.Speciality.CAZA_MAYOR]:
		var speciality := speciality_key as Profession.Speciality
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		body.add_child(row)

		var name_label := Label.new()
		name_label.text = Profession.speciality_name(speciality)
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", UISkin.INK)
		name_label.tooltip_text = Profession.speciality_desc(speciality)
		row.add_child(name_label)

		var note := Label.new()
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color", UISkin.INK_SOFT)
		if speciality == Profession.Speciality.TRAMPAS:
			note.text = "%d trampas puestas de %d que se pueden atender" % [
				sim.traps.size(), sim.trap_allowance()]
		else:
			var known := Hunting.known_improvements(speciality, sim.techs)
			note.text = "%.1f piezas por jornada%s" % [
				Hunting.pieces_per_day(speciality, sim.techs),
				"" if known.is_empty() else "  ·  con " + ", ".join(known).to_lower()]
		row.add_child(note)

		var pending := Hunting.next_improvement(speciality, sim.techs)
		if pending >= 0:
			_text(body, "   falta %s: ×%.2f"
				% [TechTree.tech_name(pending as TechTree.Tech).to_lower(),
					_improvement_factor(speciality, pending)], true)

	# Y la línea de trampas, una por una. Es lo único que la banda deja
	# PLANTADO en el mapa, así que merece una lista y no un número.
	if sim.traps.is_empty():
		_text(body, "Sin una sola trampa puesta. Pon a alguien en trampas: "
			+ "es el único trabajo que rinde mientras la banda hace otra cosa.",
			true)
	else:
		for trap: Trap in sim.traps:
			var ready := trap.soaking >= Trap.days_per_catch(trap.kind)
			_text(body, "   %s %s en %s — %.0f%% de vida, %d piezas%s" % [
				"◆" if ready else "·",
				Trap.trap_name(trap.kind),
				sim.parajes.place_name(trap.position, sim.home_position),
				trap.condition() * 100.0, trap.taken,
				"  ·  CEBADA" if ready else ""], not ready)

	body.add_child(HSeparator.new())


## Cuánto multiplica una técnica de caza en su rama.
func _improvement_factor(speciality: Profession.Speciality, tech_key: int) -> float:
	for entry: Dictionary in (Hunting.MEJORAS.get(speciality, []) as Array):
		if int(entry["tech"]) == tech_key:
			return float(entry["factor"])
	return 1.0


## Con qué se pesca hoy y qué falta para el siguiente escalón.
##
## Va aquí y no en una ventana propia porque la pesca es la actividad donde
## la técnica se nota de verdad en la jornada: la misma persona en el mismo
## río trae doce o ciento cinco según el aparejo que lleve. Sin esto, el
## jugador ve subir el pescado y no sabe por qué.
func _fishing_block(body: VBoxContainer) -> void:
	if sim == null:
		return
	_heading(body, "PESCA DE ORILLA")

	var actual := sim.fishing_method() as Fishing.Method
	for method_key: int in Fishing.ORDER:
		var method := method_key as Fishing.Method
		var why := Fishing.blocked_by(method, sim.techs, sim.toolkit, sim.store,
			sim.workers_in(Subsistence.Activity.PESCA))
		var pescado: float = float((Fishing.yields_of(method) as Dictionary).get(
			Materia.Kind.PESCADO, 0.0))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		body.add_child(row)

		var mark := Label.new()
		mark.text = "◆" if method == actual else ("·" if why == "" else " ")
		mark.custom_minimum_size = Vector2(12, 0)
		mark.add_theme_font_size_override("font_size", 11)
		mark.add_theme_color_override("font_color",
			UISkin.OCHRE if method == actual else UISkin.INK_FAINT)
		row.add_child(mark)

		var name_label := Label.new()
		name_label.text = Fishing.method_name(method)
		name_label.custom_minimum_size = Vector2(150, 0)
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color",
			UISkin.OCHRE if method == actual else
			(UISkin.INK if why == "" else UISkin.INK_FAINT))
		name_label.tooltip_text = Fishing.method_desc(method)
		row.add_child(name_label)

		var note := Label.new()
		note.text = "%.0f de pescado al día" % pescado if why == "" else why
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color",
			UISkin.INK_SOFT if why == "" else UISkin.INK_FAINT)
		row.add_child(note)

	_text(body, "Se pesca siempre con lo mejor que se pueda HOY. Si se rompe "
		+ "el último arpón o se acaba el cebo, se baja un escalón hasta que "
		+ "el taller reponga.", true)
	body.add_child(HSeparator.new())


# ------------------------------------------------------------ territorio --

func show_territory() -> void:
	var body := _window("territorio", "Territorio conocido")
	_clear(body)
	if knowledge == null or field == null:
		_text(body, "Sin datos del terreno.")
		return

	_text(body, "La banda sabe que en el río hay peces y que el ciervo pasta en "
		+ "el llano: eso viene con ella. Lo que aprende aquí es EN QUÉ remanso "
		+ "y EN QUÉ mes.", true)

	# Territorio simplemente VISTO. Es dato distinto de la familiaridad con
	# cada recurso: se puede cruzar un valle entero sin aprender nada de su
	# caza y aun asi conocer el camino.
	var seen := 0
	for value in knowledge.explored:
		if value > 0.01:
			seen += 1
	_bar(body, "Valle recorrido", float(seen) / maxf(float(knowledge.explored.size()), 1.0))
	_text(body, "Lo que la banda ha llegado a ver, al margen de lo que sepa de "
		+ "sus recursos. Sube andando; los exploradores lo suben deprisa.", true)

	body.add_child(HSeparator.new())

	for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
			Subsistence.Activity.MATERIA_PRIMA]:
		var act := activity as Subsistence.Activity

		# Qué materiales de esta actividad existen DE VERDAD en este mapa
		# -no el surtido teórico, que es el mismo en cualquier partida, sino
		# lo que de verdad sale en este campo de recursos-, y de cuántos la
		# banda ya conoce al menos una buena fuente.
		#
		# Antes esto era la familiaridad MEDIA de cada celda con recurso de
		# TODO el mapa -miles de celdas-, y salía cerca de cero aunque la
		# banda tuviera cuatro parajes al 90%: cuatro sitios son una fracción
		# minúscula de un mapa entero. Lo que de verdad quiere saber el
		# jugador es "¿conozco dónde encontrar esto?", y para eso basta con
		# UNA buena fuente por material, no con haber pisado el valle entero.
		var catalog := Parajes.materials_on_map(act, field)
		if catalog.is_empty():
			_heading(body, Subsistence.activity_name(act))
			_text(body, "   No hay nada de esto en este valle.", true)
			continue

		var known_kinds := {}
		if sim and sim.parajes:
			for paraje: Paraje in sim.parajes.list:
				if not paraje.serves(act):
					continue
				for entry: Dictionary in paraje.listing():
					if bool(entry["sabido"]):
						known_kinds[entry["kind"] as Materia.Kind] = true

		var known_count := 0
		for kind: Materia.Kind in catalog:
			if known_kinds.has(kind):
				known_count += 1

		_bar(body, Subsistence.activity_name(act), float(known_count) / float(catalog.size()))

		# Lo que hay AHI FUERA, conocido y sin recoger. Es la pregunta que se
		# hace el jugador de verdad: no «cuanto he explorado» sino «que me
		# queda por recoger de lo que ya se donde esta».
		var known_cells := 0
		var stock_left := 0.0
		var best_spot := Vector3.ZERO
		var richest := 0.0
		for z in range(field.height):
			for x in range(field.width):
				var centre := field.cell_center(x, z)
				if knowledge.familiarity_at(act, centre) < BandKnowledge.KNOWN_ENOUGH:
					continue
				if field.abundance_cell(act, x, z) <= 0.05:
					continue
				known_cells += 1
				var fraction := field.stock_fraction(act, x, z)
				stock_left += fraction
				var value := field.seasonal_abundance_at(act, centre, GameState.season)
				if value > richest:
					richest = value
					best_spot = centre

		if known_cells > 0:
			var average := stock_left / float(known_cells)
			_text(body, "   %d parajes conocidos, al %d%% de lo que daban intactos"
				% [known_cells, int(average * 100.0)], true)

			# Y QUÉ hay en ellos, por material. Decir «recolección» no dice
			# nada: lo que el jugador quiere saber es si tiene localizado un
			# avellanar o solo leña.
			for line: String in _materials_of(act):
				_text(body, "      " + line, true)
			if average < 0.45:
				_text(body, "   ⚠ Esquilmados: rinden menos de la mitad. Hay que "
					+ "buscar otros o dejarlos reponerse.")
			if sim:
				var distance := Vector2(best_spot.x - sim.home_position.x,
					best_spot.z - sim.home_position.z).length()
				_text(body, "   El mejor está a %d m del campamento." % int(distance), true)
		else:
			_text(body, "   Sin ningún paraje localizado todavía.", true)

		var seasons: Array[String] = []
		for season in range(4):
			if knowledge.knows_season(act, season as Subsistence.Season):
				seasons.append(Subsistence.season_name(season as Subsistence.Season))
		if seasons.is_empty():
			_text(body, "   Sin ninguna temporada vivida todavía.", true)
		else:
			_text(body, "   Temporadas conocidas: " + ", ".join(seasons), true)

		var best_season := Subsistence.Season.PRIMAVERA
		var best_value := -1.0
		for season in range(4):
			var value := ResourceField.seasonal_factor(act, season as Subsistence.Season)
			if value > best_value:
				best_value = value
				best_season = season as Subsistence.Season
		if knowledge.knows_season(act, best_season):
			_text(body, "   La banda ha visto que lo mejor es %s (×%.2f)." % [
				Subsistence.season_name(best_season), best_value], true)


# --------------------------------------------------------------- crónica --

## El diario de la partida: lo que ha pasado, contado cuando pasó.
##
## Va lo primero de la pestaña porque es lo que se viene a leer. La ficha del
## emplazamiento —que es lo único que había aquí antes— queda debajo: se
## consulta una vez y no cambia nunca.
func _show_diary(body: VBoxContainer) -> void:
	if sim == null or sim.chronicle == null:
		_text(body, "Todavía no ha pasado nada digno de contarse.", true)
		return

	var log: Chronicle = sim.chronicle
	log.mark_read()

	# Los filtros, con el recuento de cada tipo. Un tipo sin nada no sale: un
	# botón que no lleva a ninguna parte sólo estorba.
	var counts := log.counts()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	body.add_child(row)

	var options: Array = [[-1, "Todo", log.entries.size()]]
	for kind: int in Chronicle.KIND_NAMES:
		var many := int(counts.get(kind, 0))
		if many > 0:
			options.append([kind, Chronicle.kind_name(kind as Chronicle.Kind), many])

	for option: Array in options:
		var value: int = option[0]
		var button := Button.new()
		button.text = "%s %d" % [String(option[1]), int(option[2])]
		button.custom_minimum_size = Vector2(0, 22)
		button.add_theme_font_size_override("font_size", 10)
		if value == _lore_filter:
			button.add_theme_stylebox_override("normal", UISkin.button_box("pressed"))
			button.add_theme_color_override("font_color", UISkin.OCHRE)
		button.pressed.connect(func() -> void:
			_lore_filter = value
			show_lore())
		row.add_child(button)

	var entries := log.recent(60, _lore_filter)
	if entries.is_empty():
		_text(body, "Nada anotado de eso todavía.", true)
		return

	# Se agrupa por fecha: un diario con la fecha repetida en cada línea se
	# lee como un registro de sistema, no como una crónica.
	var last_stamp := ""
	for entry: Dictionary in entries:
		var stamp := Chronicle.stamp(entry)
		if stamp != last_stamp:
			last_stamp = stamp
			var date := Label.new()
			date.text = stamp
			date.add_theme_font_size_override("font_size", 10)
			date.add_theme_color_override("font_color", UISkin.INK_FAINT)
			body.add_child(date)

		var weight := int(entry["weight"])
		var frame := PanelContainer.new()
		var box := UISkin.row_box(UISkin.SURFACE if weight >= 2 else UISkin.GROUND)
		box.border_width_left = 3
		box.border_color = _lore_tint(int(entry["kind"]), weight)
		frame.add_theme_stylebox_override("panel", box)
		body.add_child(frame)

		var label := Label.new()
		label.text = String(entry["text"])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(PANEL_WIDTH - 100, 0)
		label.add_theme_font_size_override("font_size", 12 if weight >= 2 else 11)
		label.add_theme_color_override("font_color",
			UISkin.INK if weight >= 2 else UISkin.INK_SOFT)
		frame.add_child(label)


## El color del filete de cada anotación. Es el mismo criterio que en el resto
## de la interfaz: ocre lo que reclama atención, rojo lo que va mal.
func _lore_tint(kind: int, weight: int) -> Color:
	match kind:
		Chronicle.Kind.PENURIA: return UISkin.ALARM
		Chronicle.Kind.HALLAZGO: return UISkin.OCHRE
		Chronicle.Kind.OBRA: return UISkin.GREEN
		Chronicle.Kind.TALLER: return UISkin.FLINT
		_: return UISkin.OCHRE if weight >= 2 else UISkin.RULE


## Filtro activo del diario. -1 es «todo».
var _lore_filter: int = -1


func show_lore() -> void:
	var body := _window("cronica", "Crónica")
	_clear(body)

	_show_diary(body)

	if site == null:
		return

	_heading(body, "EL LUGAR")
	_text(body, site.display_name())
	_text(body, site.describe_for_player(int(GameState.era)))
	body.add_child(HSeparator.new())

	_heading(body, "EL SITIO")
	_text(body, "Clase: %s" % site.kind_name(), true)
	_text(body, "Altitud: %.0f m sobre el nivel actual del mar" % site.elevation, true)
	_text(body, "Agua permanente a %.1f km" % site.water_km, true)
	if not site.record_kind.is_empty():
		_text(body, "En el registro: %s" % site.record_kind, true)
	if not site.record_period.is_empty():
		_text(body, "Periodo documentado: %s" % site.record_period, true)

	var caves := site.cave_count()
	var shafts := site.shaft_count()
	if caves > 0 or shafts > 0:
		body.add_child(HSeparator.new())
		_heading(body, "KARST")
		_text(body, "%d cavidades habitables y %d simas en el entorno. Las simas "
			% [caves, shafts]
			+ "no se ocupan —son pozos verticales— pero delatan roca caliza, y "
			+ "donde hay karst hay más cuevas por encontrar.", true)

	var attested := site.attestations()
	if not attested.is_empty():
		body.add_child(HSeparator.new())
		_heading(body, "LO QUE VINO DESPUÉS")
		_text(body, "Documentado en este mismo lugar, en épocas posteriores a la "
			+ "que juegas. No está en el mapa todavía: lo levantará alguien.", true)
		for a: Dictionary in attested:
			_text(body, "  · %s — %s" % [
				Site.feature_name(int(a["class"]) as Site.Feature), a["name"]], true)


# --------------------------------------------------------------- recurso --

## Ficha de un recurso del mapa.
##
## Se abre al pinchar una mata, un canto o una cuerna. Dice qué es, cuánto
## queda en ese paraje y —lo que de verdad importa— si la banda sabe que está
## ahí, porque saberlo y que exista son cosas distintas.
func show_resource(kind: Materia.Kind, world: Vector3,
		activity: Subsistence.Activity) -> void:
	var body := _window("recurso", "Recurso")
	_clear(body)

	_heading(body, Materia.material_name(kind))
	_text(body, Materia.describe(kind))

	body.add_child(HSeparator.new())
	_heading(body, "AQUÍ")

	if field:
		var cell_x := clampi(int(world.x / field.world_size.x * float(field.width)),
			0, field.width - 1)
		var cell_z := clampi(int(world.z / field.world_size.y * float(field.height)),
			0, field.height - 1)
		var stock := field.stock_fraction(activity, cell_x, cell_z)
		_bar(body, "Lo que queda en el paraje", stock)
		if stock < 0.4:
			_text(body, "⚠ Esquilmado. Se repone, pero despacio: una mancha "
				+ "casi vacía tarda desproporcionadamente en volver.")

		var season := ResourceField.seasonal_factor(activity, GameState.season)
		_text(body, "Temporada: %s, rinde ×%.2f" % [
			Subsistence.season_name(GameState.season), season], true)

	if knowledge:
		var known := knowledge.familiarity_at(activity, world)
		_bar(body, "Lo que la banda conoce de aquí", known)
		if known < BandKnowledge.KNOWN_ENOUGH:
			_text(body, "La banda no tiene este paraje localizado: aunque esté "
				+ "aquí, no vendrá sola. Hay que pisarlo para que cuente.", true)

	body.add_child(HSeparator.new())
	_heading(body, "QUÉ DA")
	_text(body, "Una unidad son %s: %s y %s." % [
		Materia.unit_name(kind),
		Materia.format_weight(Materia.kg_per_unit(kind)),
		Materia.format_volume(Materia.litres_per_unit(kind))], true)

	if Materia.is_food(kind):
		_text(body, "Alimenta %.1f raciones por unidad." % Materia.nutrition(kind), true)
	var life := Materia.shelf_life(kind)
	if life <= 0:
		_text(body, "No se estropea.", true)
	else:
		_text(body, "Aguanta %d días guardado." % life, true)

	if sim:
		_text(body, "En el abrigo: %.0f %s" % [
			sim.store.amount(kind), Materia.unit_name(kind)], true)

	_text(body, "Lo trae: %s" % Subsistence.activity_name(activity), true)


# --------------------------------------------------------------- persona --

## Ficha de una persona concreta.
##
## Es lo que convierte a la banda de un número en gente: quién es, qué está
## haciendo ahora mismo, qué lleva encima y por qué puede o no puede hacer
## ciertos trabajos.
func show_person(person: Inhabitant) -> void:
	var body := _window("persona", "Persona")
	_clear(body)

	_heading(body, person.given_name)
	_text(body, "%s · %s de %d años%s" % [
		"Mujer" if person.sex == Inhabitant.Sex.MUJER else "Hombre",
		person.age_name(), person.age_years,
		" · criando" if person.nursing else ""])

	body.add_child(HSeparator.new())
	_heading(body, "AHORA MISMO")
	_text(body, "Está %s." % person.state_name())
	if person.has_task:
		_text(body, "Oficio: %s" % Profession.job_name(person.job as Profession.Job), true)
	else:
		_text(body, "Sin tarea asignada.", true)

	if person.state == Inhabitant.State.BUSCANDO:
		_text(body, "Lleva %.1f horas batiendo el paraje. No conoce este sitio, "
			% person.search_hours
			+ "así que primero tiene que encontrar lo que ha venido a buscar.", true)

	body.add_child(HSeparator.new())
	_heading(body, "CÓMO ESTÁ")
	_bar(body, "Hambre", person.hunger / 100.0)
	_bar(body, "Fatiga", person.fatigue / 100.0)
	if person.hurt_days > 0:
		_notice(body, "Tocado: le quedan %d jornadas andando mal."
			% person.hurt_days, UISkin.ALARM)

	# El cuerpo, aparte del oficio: esto no se aprende en un tajo concreto,
	# es de fábrica y sube muy despacio con los años. Ver [Inhabitant.Stat].
	body.add_child(HSeparator.new())
	_heading(body, "CUERPO Y RASGOS")
	_bar(body, "Fuerza", person.stat_in(Inhabitant.Stat.FUERZA))
	_bar(body, "Resistencia", person.stat_in(Inhabitant.Stat.RESISTENCIA))
	_bar(body, "Agudeza", person.stat_in(Inhabitant.Stat.AGUDEZA))
	_text(body, "Fuerza carga más peso, resistencia aguanta más antes de "
		+ "rendirse, agudeza aprende más rápido. Cambian con los años, no "
		+ "con la práctica de un oficio.", true)

	var rasgos: Array[String] = []
	if person.trait_in(Inhabitant.Trait.NATACION) > 0.05:
		rasgos.append("nada (%s)" % person.skill_label(
			person.trait_in(Inhabitant.Trait.NATACION)))
	if rasgos.is_empty():
		_text(body, "Sin rasgos aparte: no sabe nadar, ni nada por el estilo.", true)
	else:
		_text(body, "Sabe: " + ", ".join(rasgos), true)

	# La pericia, oficio por oficio. Antes salía una sola barra que decía
	# «pericia en su oficio» sin decir cuál era, y encima mezclaba talla con
	# peletería porque las dos eran «materia prima».
	_heading(body, "QUÉ SABE HACER")
	for job_key: int in GRID_JOBS:
		var job := job_key as Profession.Job
		var tasks := Profession.tasks_of(job)
		for task: int in tasks:
			var value := person.skill_in(task)
			var doing := person.current_task() == task
			var label := Profession.task_name(task)
			if tasks.size() > 1:
				label = "  " + label
			if doing:
				label += " ·"
			_bar(body, "%s  %s" % [label, person.skill_label(value)], value)

	_text(body, "Se aprende haciendo, y cada especialidad va por su cuenta: "
		+ "quien talla no aprende a curtir. Entra en lo que rinde, así que "
		+ "cambiar a alguien de oficio a menudo sale caro.", true)

	body.add_child(HSeparator.new())
	_heading(body, "QUÉ LLEVA")
	_bar(body, "Carga (%.0f de %.0f kg)" % [person.load_kg(), person.carry_limit_kg()],
		person.load_fraction())
	if person.load.is_empty():
		_text(body, "Las manos vacías.", true)
	else:
		for kind: int in person.load.keys():
			var k := kind as Materia.Kind
			_text(body, "  · %.1f %s de %s" % [
				float(person.load[kind]), Materia.unit_name(k),
				Materia.material_name(k).to_lower()], true)

	var recipientes: Array[String] = []
	if person.has_basket:
		recipientes.append("cesto")
	if person.has_waterskin:
		recipientes.append("odre")
	if recipientes.is_empty():
		_text(body, "Sin recipientes: va a brazadas, y eso limita la jornada "
			+ "más que el tiempo.", true)
	else:
		_text(body, "Lleva: " + ", ".join(recipientes), true)

	body.add_child(HSeparator.new())
	_heading(body, "QUÉ PUEDE HACER")
	for job_key: int in Profession.CATALOGUE.keys():
		var job := job_key as Profession.Job
		if Profession.can_do(job, person):
			_text(body, "  ✓ " + Profession.job_name(job), true)
		else:
			_text(body, "  ✗ %s — %s" % [
				Profession.job_name(job), _why_not(job, person)], true)


## Por qué esta persona no puede hacer este oficio. Decirlo importa: si no, el
## jugador solo ve una lista de negativas sin causa.
func _why_not(job: Profession.Job, person: Inhabitant) -> String:
	var entry: Dictionary = Profession.CATALOGUE[job]
	if person.age_years < int(entry["min_age"]):
		return "demasiado joven"
	if person.age_years > int(entry["max_age"]):
		return "demasiado mayor"
	if bool(entry["mobile"]):
		if person.nursing:
			return "lleva una cría de pecho"
		if person.age_group != Inhabitant.Age.ADULTO:
			return "no aguanta la jornada larga"
	if not Profession.allows_sex(entry["sex"] as Profession.Sex, person):
		return "vetado por sexo en el catálogo"
	return "no cumple los requisitos"


# ----------------------------------------------------------------- lugar --

## Ventana de un elemento pinchado en el mundo.
func show_feature(data: Dictionary, world: Vector3, home: Vector3) -> void:
	var body := _window("lugar", "Lugar")
	_clear(body)

	var feature_class := int(data.get("class", Site.Feature.OTRO)) as Site.Feature
	var name_text := String(data.get("name", ""))
	if name_text.is_empty():
		name_text = "Cavidad sin nombre"

	_heading(body, name_text)
	_text(body, Site.feature_name(feature_class))
	body.add_child(HSeparator.new())

	_heading(body, "LO QUE SE VE")
	var elevation := world.y
	var distance := Vector2(world.x - home.x, world.z - home.z).length()
	_text(body, "A %.0f m del campamento, a %.0f m de altitud." % [distance, elevation], true)
	if not String(data.get("kind", "")).is_empty():
		_text(body, "Tipo en el registro: %s" % data["kind"], true)
	if not String(data.get("period", "")).is_empty():
		_text(body, "Periodo documentado: %s" % data["period"], true)
	_text(body, "Coordenadas: %.5f N, %.5f E" % [
		float(data.get("lat", 0.0)), float(data.get("lon", 0.0))], true)

	body.add_child(HSeparator.new())
	_heading(body, "QUÉ OFRECE")
	match feature_class:
		Site.Feature.ABRIGO:
			_text(body, "Abrigo natural: se ocupa sin construir nada, que en el "
				+ "Paleolítico es la única forma de pasar el invierno. La pared "
				+ "seca del fondo sirve además de soporte para pintar.")
			_text(body, "Una cavidad de boca ancha y orientada al sur reúne las "
				+ "dos cosas que hacen habitable una cueva: entra luz buena "
				+ "parte del día y no entra el viento del norte.", true)
		Site.Feature.SURGENCIA:
			_text(body, "Agua todo el año, no estacional. Es lo que decide si un "
				+ "sitio se puede ocupar en verano seco.")
		Site.Feature.SIMA:
			_text(body, "Pozo vertical. No se ocupa y es peligroso, pero delata "
				+ "caliza: donde hay simas hay cuevas.")
		_:
			_text(body, "Elemento del terreno.")

	body.add_child(HSeparator.new())
	_heading(body, "QUÉ HACER")
	for entry: Array in _actions_for(feature_class):
		var button := Button.new()
		button.text = entry[1]
		button.tooltip_text = entry[2]
		button.pressed.connect(func() -> void:
			cave_action.emit(entry[0] as String, data))
		body.add_child(button)


func _actions_for(feature_class: Site.Feature) -> Array:
	match feature_class:
		Site.Feature.ABRIGO:
			return [
				["ocupar", "Trasladar el campamento aquí",
					"La banda se muda a esta cavidad."],
				["explorar", "Explorar el interior",
					"Recorrerla a fondo: puede haber galerías, agua o restos."],
				["taller", "Usar como taller de talla",
					"Trabajar la piedra a cubierto y con la materia prima a mano."],
				["pintar", "Pintar la pared del fondo",
					"Requiere dominar el fuego y la talla laminar."],
			]
		Site.Feature.SURGENCIA:
			return [["explorar", "Reconocer el manantial",
				"Comprobar si mana todo el año."]]
		_:
			return [["explorar", "Reconocer el sitio", "Acercarse a ver qué hay."]]
