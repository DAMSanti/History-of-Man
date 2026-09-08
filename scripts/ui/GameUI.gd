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

## El censo de lo pintado y la cámara a la que lleva. Los pone la escena; sin
## ellos la pestaña de Entidades lo dice y no hace nada, que es mejor que
## romperse. Ver [EntityCensus].
var census: EntityCensus = null
var camera: OrbitalCamera = null

var _live: Array[Dictionary] = []
var _building: String = ""

## El paraje que muestra la ficha "paraje" ahora mismo, si hay una abierta.
## Sirve para refrescarla en vivo (ver `_process`) y para que un clic sobre
## la misma mancha, con su ficha ya abierta, no la vuelva a abrir sin más:
## ver `DemoMain._unhandled_input`.
var shown_paraje: Paraje = null

## La persona cuya ficha esta abierta, para poder repintarla.
##
## Sin esto la ficha era la foto del instante en que se pincho: no estaba en
## la lista de ventanas que se repintan solas, asi que se podia tener delante
## a alguien «de camino» que llevaba media jornada trabajando.
var shown_person: Inhabitant = null

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


## La barra de arriba y la tarjeta que interrumpe. Ver [BarraSuperior].
var barra: BarraSuperior = BarraSuperior.new(self)


## Que hay donde has pinchado. Ver [PanelSitios].
var sitios: PanelSitios = PanelSitios.new(self)


## Los oficios que hay y quien los ejerce. Ver [PanelOficios].
var oficios: PanelOficios = PanelOficios.new(self)

## Lo que sabe hacer cada oficio y su arbol. Ver [PanelTecnicas].
var tecnicas: PanelTecnicas = PanelTecnicas.new(self)

## Que hay pintado en el mundo. Ver [PanelCenso].
var censo: PanelCenso = PanelCenso.new(self)


## Las cuatro ventanas que se abren desde la barra de abajo y desde el mundo.
func show_professions() -> void:
	oficios.show_professions()


func show_tech() -> void:
	tecnicas.show_tech()


func show_census() -> void:
	censo.show_census()


func show_entity(key: String, index: int, focus: bool = true) -> void:
	censo.show_entity(key, index, focus)


## Las seis fichas del sitio. Se dejan pasamanos porque las abre `DemoMain` al
## pinchar en el mundo, y son la cara publica de la interfaz para el raton.
func show_ground(world: Vector3, terrain: TerrainGenerator) -> void:
	sitios.show_ground(world, terrain)


func show_paraje(paraje: Paraje) -> void:
	sitios.show_paraje(paraje)


func show_peak(peak: Dictionary) -> void:
	sitios.show_peak(peak)


func show_places() -> void:
	sitios.show_places()


func show_resource(kind: Materia.Kind, world: Vector3,
		activity: Subsistence.Activity) -> void:
	sitios.show_resource(kind, world, activity)


func show_feature(data: Dictionary, world: Vector3, home: Vector3) -> void:
	sitios.show_feature(data, world, home)


## Que la interfaz se entere de los momentos: hallazgos que enseñar y
## decisiones que pedir. Lo lleva [BarraSuperior]; el pasamanos se deja porque
## lo llama `DemoMain`.
func watch_moments(simulation: SettlementSim) -> void:
	barra.watch_moments(simulation)


func _ready() -> void:
	layer = 10
	# El tema se cuelga de cada ventana y baja solo a todo lo que contenga.
	# Un CanvasLayer no es Control y no tiene `theme`, así que no se puede
	# poner una vez arriba del todo.
	_skin = UISkin.build_theme()
	barra._build_clock()
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
	barra._update_clock()

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
			"tecnicas": tecnicas.show_tech()
			"oficios": oficios.show_professions()
			"territorio": show_territory()
			"cronica": show_lore()
			"parajes": sitios.show_places()
			"rastros": show_trails()
			"entidades": censo.show_census()
			# La ficha de una entidad se repinta SIN volver a mover la cámara.
			# Mover la cámara es lo que hace la flecha, no el repintado: con el
			# foco puesto aquí, la vista se enganchaba a la entidad y el
			# jugador no podía apartarse a mirar el alrededor, que es la mitad
			# de para qué sirve esto.
			"persona":
				if shown_person != null:
					show_person(shown_person)
			"entidad":
				censo.repintar()
			"paraje":
				# La ficha de UN paraje concreto: lo que descubre una batida
				# -materiales nuevos, el % conocido- tiene que verse aquí sin
				# cerrar y reabrir. Si el sitio se queda en descanso o deja de
				# existir de alguna forma, `shown_paraje` seguirá siendo valido
				# -los parajes no se borran-, así que basta con el nulo.
				if shown_paraje:
					sitios.show_paraje(shown_paraje)


# ---------------------------------------------------------------- reloj ---

## --- El momento, la tarjeta que interrumpe -----------------------------
##
## Ver [Moment] para el porqué. Aquí sólo se pinta: un titular, dos líneas y —si
## el momento trae decisión— los botones. Va centrada arriba y por encima de
## todo, porque su trabajo es que no se pueda seguir jugando sin verla.

## Lo que queda por atender. Se encolan: en una jornada pueden bautizarse dos
## parajes a la vez, y tragarse el segundo sería peor que no avisar de ninguno.
var _moments: Array[Moment] = []
var _moment_card: Control

## La velocidad que llevaba la partida antes de parar por una decisión.
var _speed_before_moment: float = -1.0


## Nombres de las cualidades, para escribirlas en una ficha corta.
const STAT_WORDS := {
	Inhabitant.Stat.FUERZA: "fuerte",
	Inhabitant.Stat.RESISTENCIA: "resistente",
	Inhabitant.Stat.AGUDEZA: "espabilado",
}


## Lo que ya está escrito en el rótulo. Reescribir el texto y, sobre todo,
## pisar el color del tema en CADA fotograma obliga al Label a repintarse
## siempre, y esto corre sesenta veces por segundo para un dato que cambia
## una vez por minuto de juego.
## El estado de la banda en la barra de arriba: hambre y cansancio medios.
var _band_label: Label

## Las barras de hambre y cansancio de la tira de arriba.
var _hunger_bar: Muescas
var _tired_bar: Muescas

var _winter_label: Label
var _winter_bar: ProgressBar
var _clock_minute: int = -1
var _clock_night: bool = false
var _clock_speed: float = 1.0
var _lore_pending: int = -1


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
		["tecnicas", "Técnicas"], ["oficios", "Oficios"],
		["territorio", "Territorio"],
		["cronica", "Crónica"], ["parajes", "Parajes"], ["rastros", "Rastros"],
		["entidades", "Entidades"], ["controles", "Controles"],
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
		width: int = PANEL_WIDTH, piel: bool = false) -> VBoxContainer:
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
	# El soporte, encima del fondo y debajo de todo lo demas. Hay dos:
	#
	#   `piel`  la piel TENSADA, con su borde combado y sus correas. Es la
	#           buena, y la ventana que la lleva no necesita caja de estilo
	#           porque el fondo lo dibuja ella. Ver [PielTensada].
	#   si no   una capa de grano en multiply sobre la caja de siempre, que es
	#           lo que tenian todas antes de que hubiera piel.
	#
	# Se va a ir pasando ventana a ventana. Ver docs/INTERFAZ.md.
	var soporte: Control = null
	if piel:
		# La caja no pinta nada: solo aparta el contenido del borde de la piel,
		# que sobresale y se comba y necesita su sitio.
		var hueca := StyleBoxEmpty.new()
		hueca.set_content_margin_all(PielTensada.DESBORDE)
		frame.add_theme_stylebox_override("panel", hueca)
		soporte = PielTensada.new()
	else:
		soporte = UISkin.grain_layer()
	frame.add_child(soporte)
	# Detras de todo lo demas: el soporte tiñe lo escrito encima, no al reves.
	# En Godot el orden de hijos ES el orden de dibujo.
	frame.move_child(soporte, 0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	frame.add_child(column)

	# Barra de título: además de rotular, es el asa para arrastrar
	var header := HBoxContainer.new()
	column.add_child(header)

	var caption := Label.new()
	caption.text = title
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# En una ventana de piel, el rotulo va escrito a mano como el resto. Dejarlo
	# con la letra de serie era lo unico que seguia pareciendo un programa.
	if piel:
		Pigmento.escribir(caption, UISkin.OCHRE, 24)
	else:
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
			shown_paraje = null
		# Y cerrar la ficha de una entidad apaga su rastro, por lo mismo: el
		# rastro lo pinta la ficha y sin ficha no tiene quién lo mantenga al
		# día, así que se quedaría congelado en el mapa para siempre.
		elif id == "entidad":
			censo._forget_entity())
	header.add_child(close)

	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, _content_height())
	column.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# El borde de la piel se come su ancho por los dos lados. Sin descontarlo,
	# el minimo del cuerpo salia mas ancho que el hueco util y los renglones se
	# cortaban por la derecha: se leia «la misma persona en el mismo rio trae» y
	# ahi se acababa la frase.
	var margen := PielTensada.DESBORDE * 2.0 if piel else 0.0
	body.custom_minimum_size = Vector2(width - 40 - margen, 0)
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
	# Y la ficha de una entidad apaga su rastro, igual que al pulsar la cruz.
	if _windows.get("entidad", null) == best:
		censo._forget_entity()
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
		"tecnicas": tecnicas.show_tech()
		"oficios": oficios.show_professions()
		"territorio": show_territory()
		"cronica": show_lore()
		"parajes": sitios.show_places()
		"rastros": show_trails()
		"entidades": censo.show_census()


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


## Devuelve el rótulo para que quien lo pinte pueda ATARLO y que se actualice
## sin reconstruir la ventana. Ver `_bind`.
func _text(body: VBoxContainer, content: String, dim: bool = false) -> Label:
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
	return label


## Devuelve la barra para que quien la pinte pueda ATARLA y que se mueva sola.
## Ver `_bind`.
func _bar(body: VBoxContainer, caption: String, value: float) -> ProgressBar:
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
	return meter


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

# --- lo que el almacen comparte con las demas ventanas --------------------
#
# Se quedan aqui y no en [PanelAlmacen] porque los usa mas de una: el
# aviso en recuadro lo pintan tres ventanas, y las anchuras de columna
# las lee tambien la rejilla de trabajos.

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
	label.custom_minimum_size = Vector2(GameUI.PANEL_WIDTH - 100, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", tint)
	frame.add_child(label)


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


## El almacen. Lo que se pinta dentro esta en [PanelAlmacen].
func show_store() -> void:
	_almacen_panel().show_store()


## La ficha de una pieza del utillaje: como se hace y para que sirve.
func show_tool(kind: Tool.Kind) -> void:
	_almacen_panel().show_tool(kind)


## La ficha de un material: de donde sale, en que se gasta y su historia.
func show_material(kind: Materia.Kind) -> void:
	_almacen_panel().show_material(kind)


func _almacen_panel() -> PanelAlmacen:
	if _almacen == null:
		_almacen = PanelAlmacen.new(self)
	return _almacen


var _almacen: PanelAlmacen = null


# ------------------------------------------------------------- trabajos ---

# --- vocabulario de la rejilla de trabajos --------------------------------
#
# Se quedan en el panel y no en [PanelTrabajos] porque las leen tambien
# otras ventanas -la ficha de material lista actividades, la de tecnicas
# dibuja columnas por oficio- y una sonda mide con ellas los anchos.

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


## La ficha corta de cada cual, en una tira. Lo pinta [PanelTrabajos].
func show_band() -> void:
	if _trabajos == null:
		_trabajos = PanelTrabajos.new(self)
	_trabajos.show_band()


## Con que se trabaja cada actividad, en lineas sueltas. Lo arma [PanelTrabajos].
func _materials_of(activity: Subsistence.Activity) -> Array[String]:
	if _trabajos == null:
		_trabajos = PanelTrabajos.new(self)
	return _trabajos._materials_of(activity)


## La ventana de Trabajos. Lo que se pinta dentro esta en [PanelTrabajos].
func show_jobs() -> void:
	if _trabajos == null:
		_trabajos = PanelTrabajos.new(self)
	_trabajos.show_jobs()


var _trabajos: PanelTrabajos = null


# ------------------------------------------------------------ rastros ----

## La ventana de Rastros. Lo que se pinta dentro esta en [PanelRastros].
func show_trails() -> void:
	_rastros_panel().show_trails()


## La ventana de Territorio: lo que la banda sabe del mapa.
func show_territory() -> void:
	_rastros_panel().show_territory()


## El nombre del sitio, si hay parajes puestos. Lo piden varias ventanas.
func parajes_name(point: Vector3) -> String:
	return _rastros_panel().parajes_name(point)


func _rastros_panel() -> PanelRastros:
	if _rastros == null:
		_rastros = PanelRastros.new(self)
	return _rastros


var _rastros: PanelRastros = null


# ------------------------------------------------------------ territorio --

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

# --------------------------------------------------------------- persona --

## Ficha de una persona concreta.
##
## Es lo que convierte a la banda de un número en gente: quién es, qué está
## haciendo ahora mismo, qué lleva encima y por qué puede o no puede hacer
## ciertos trabajos.
func show_person(person: Inhabitant) -> void:
	shown_person = person
	var body := _window("persona", "Persona")
	_clear(body)

	_ficha_quien_es(body, person)
	_ficha_ahora_mismo(body, person)
	_ficha_como_esta(body, person)
	_ficha_cuerpo(body, person)
	_ficha_que_sabe(body, person)
	_ficha_que_lleva(body, person)
	_ficha_petate(body, person)
	_ficha_que_puede_hacer(body, person)


## Quien es: nombre, sexo, edad y de que familia.
func _ficha_quien_es(body: VBoxContainer, person: Inhabitant) -> void:
	_heading(body, person.given_name)
	_text(body, "%s · %s de %d años%s" % [
		"Mujer" if person.sex == Inhabitant.Sex.MUJER else "Hombre",
		person.age_name(), person.age_years,
		" · criando" if person.nursing else ""])

	body.add_child(HSeparator.new())


## Que esta haciendo en este momento, y donde.
func _ficha_ahora_mismo(body: VBoxContainer, person: Inhabitant) -> void:
	_heading(body, "AHORA MISMO")
	var state_line := _text(body, "Está %s." % person.state_name())
	_bind(state_line, func() -> void:
		state_line.text = "Está %s." % person.state_name())
	# El oficio, no `has_task`: esa bandera dice si hay TAJO EN EL MAPA, y el
	# hogar no lo tiene -no se cuida el fuego en un paraje-. Preguntandole a
	# ella, quien estaba levantando el hogar salia como «sin tarea asignada»
	# mientras lo levantaba. Sin oficio es `Job.OCIOSO`, y esos si lo estan.
	if person.job != Profession.Job.OCIOSO:
		_text(body, "Oficio: %s" % Profession.job_name(person.job as Profession.Job), true)
	else:
		_text(body, "Sin tarea asignada.", true)

	# El hogar y el taller trabajan EN el abrigo, asi que su «trabajando» no
	# lleva paraje ni camino detras y se queda en una palabra sola. Se dice
	# que estan levantando o tallando, que es lo que se ve por la ventana.
	if sim and sim.hogar._works_at_camp(person) \
		and person.state == Inhabitant.State.TRABAJANDO:
		var piece: Dictionary = sim.taller.crafting_now(person)
		if not piece.is_empty():
			_text(body, "Talla %s: %.0f %% de la pieza." % [
				Tool.kind_name(int(piece["tool"]) as Tool.Kind).to_lower(),
				float(piece["progress"]) * 100.0], true)
		elif sim.camp_queue >= 0:
			_text(body, "Levantando %s." % CampProjects.project_name(
				sim.camp_queue as CampProjects.Kind).to_lower(), true)
	if person.state == Inhabitant.State.BUSCANDO:
		_text(body, "Lleva %.1f horas batiendo el paraje. No conoce este sitio, "
			% person.search_hours
			+ "así que primero tiene que encontrar lo que ha venido a buscar.", true)

	body.add_child(HSeparator.new())


## Hambre, cansancio y salud.
func _ficha_como_esta(body: VBoxContainer, person: Inhabitant) -> void:
	_heading(body, "CÓMO ESTÁ")
	# Atadas, no pintadas y ya: el hambre y el cansancio cambian a cada rato y
	# el repintado de la ventana se salta cuando el ratón está dentro —que es
	# justo cuando se está leyendo la ficha—. Ver `_bind`.
	var hunger_bar := _bar(body, "Hambre", person.hunger / 100.0)
	_bind(hunger_bar, func() -> void:
		hunger_bar.value = clampf(person.hunger / 100.0, 0.0, 1.0))
	var tired_bar := _bar(body, "Fatiga", person.fatigue / 100.0)
	_bind(tired_bar, func() -> void:
		tired_bar.value = clampf(person.fatigue / 100.0, 0.0, 1.0))
	if person.hurt_days > 0:
		_notice(body, "Tocado: le quedan %d jornadas andando mal."
			% person.hurt_days, UISkin.ALARM)

	# El cuerpo, aparte del oficio: esto no se aprende en un tajo concreto,
	# es de fábrica y sube muy despacio con los años. Ver [Inhabitant.Stat].
	body.add_child(HSeparator.new())


## El cuerpo y los rasgos con los que nacio.
func _ficha_cuerpo(body: VBoxContainer, person: Inhabitant) -> void:
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


## La pericia en cada actividad: lo que ha aprendido pisando.
func _ficha_que_sabe(body: VBoxContainer, person: Inhabitant) -> void:
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


## Lo que trae en las manos de esta salida.
func _ficha_que_lleva(body: VBoxContainer, person: Inhabitant) -> void:
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

	# Y el resto del petate, que no va en `load` y por eso no se veía: el
	# apero con el que trabaja, los recipientes y el agua. «Qué lleva» decía
	# sólo lo recogido, o sea que un cazador con azagaya, cesto y odre lleno
	# salía con «las manos vacías» de vuelta a casa.
	body.add_child(HSeparator.new())


## El petate: ropa, herramientas, cestos y odres. Lo que lleva SIEMPRE,
## que no es lo mismo que lo que ha recogido hoy.
func _ficha_petate(body: VBoxContainer, person: Inhabitant) -> void:
	_heading(body, "EL PETATE")
	# Quien sale al monte lleva apero; el del abrigo y el que no tiene oficio,
	# no. `_tool_for` cae en la azagaya cuando la actividad no esta definida, y
	# eso ponia una azagaya en las manos de un crio sin tarea.
	var sale: bool = sim != null and not sim.hogar._works_at_camp(person) \
		and person.job != Profession.Job.OCIOSO
	if sim and sale:
		var apero: int = sim.taller._tool_for(person)
		# El cesto y el odre se cuentan abajo como lo que son. Salen aquí
		# también porque son el «apero» de recolectar y de traer agua, y
		# repetirlos hacía que la ficha dijera «Cesto» y dos líneas más abajo
		# «sin recipientes».
		if apero == Tool.Kind.CESTO or apero == Tool.Kind.ODRE:
			apero = -1
		if apero >= 0 and sim.toolkit.count(apero as Tool.Kind) > 0:
			_text(body, "  · %s, para %s" % [
				Tool.kind_name(apero as Tool.Kind),
				Subsistence.activity_name(person.activity).to_lower()], true)
		elif apero >= 0:
			_text(body, "  · sin %s: el taller no ha hecho ninguna todavía" %
				Tool.kind_name(apero as Tool.Kind).to_lower(), true)
	if person.has_basket:
		_text(body, "  · cesto", true)
	if person.has_waterskin:
		_text(body, "  · odre, con agua para %.1f h" % person.water_left, true)
	# El agua sólo se cuenta a quien sale: en el abrigo se bebe del río, que es
	# por lo que el abrigo está donde está.
	if sale and not person.has_waterskin:
		if sim and sim._at_shelter(person):
			_text(body, "  · sin odre: mientras no se aleje del abrigo da igual, "
				+ "pero no puede pasar la jornada fuera", true)
		else:
			_text(body, "  · sin odre: le quedan %.1f h antes de tener que ir a "
				% person.water_left + "beber", true)
	if sale and not person.has_basket:
		_text(body, "Sin cesto va a brazadas, y eso limita la jornada más que "
			+ "el tiempo.", true)
	body.add_child(HSeparator.new())


## Que oficios puede ejercer y por que no puede los otros.
func _ficha_que_puede_hacer(body: VBoxContainer, person: Inhabitant) -> void:
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
