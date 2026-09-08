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
			"oficios": show_professions()
			"territorio": show_territory()
			"cronica": show_lore()
			"parajes": show_places()
			"rastros": show_trails()
			"entidades": show_census()
			# La ficha de una entidad se repinta SIN volver a mover la cámara.
			# Mover la cámara es lo que hace la flecha, no el repintado: con el
			# foco puesto aquí, la vista se enganchaba a la entidad y el
			# jugador no podía apartarse a mirar el alrededor, que es la mitad
			# de para qué sirve esto.
			"persona":
				if shown_person != null:
					show_person(shown_person)
			"entidad":
				if not _census_group.is_empty():
					show_entity(_census_group, _census_index, false)
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
## La barra de arriba, DE LADO A LADO.
##
## Era una caja apilada en la esquina: cuatro filas una debajo de otra que
## crecian hacia abajo y se comian el valle. La informacion que se mira sin
## dejar de jugar -que hora es, como esta la banda, como va el invierno- cabe
## en una linea a lo ancho, y a lo ancho hay sitio de sobra.
func _build_clock() -> void:
	var margin := MarginContainer.new()
	# Pegada arriba y estirada a los dos lados: es una BARRA, no un cartel.
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var frame := PanelContainer.new()
	frame.theme = _skin
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 18)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(strip)

	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 14)
	_clock.add_theme_color_override("font_color", UISkin.INK)
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_clock)

	_build_band_gauge(strip)
	_build_winter_gauge(strip)
	# Los botones de velocidad al final, empujados a la derecha.
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(gap)
	_build_speed_buttons(strip)
	_update_clock()

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


## Engancha la simulación. Lo llama [DemoMain] al montar la escena.
func watch_moments(simulation: SettlementSim) -> void:
	if simulation.moment_raised.is_connected(_on_moment):
		return
	simulation.moment_raised.connect(_on_moment)


func _on_moment(moment: Moment) -> void:
	_moments.append(moment)
	if _moment_card == null:
		_show_next_moment()


func _show_next_moment() -> void:
	if _moment_card != null:
		_moment_card.queue_free()
		_moment_card = null
	if _moments.is_empty():
		# Se devuelve la velocidad que había, no una fija: si el jugador estaba
		# en pausa mirando algo, reanudarle la partida sería peor que no parar.
		if _speed_before_moment >= 0.0 and sim != null:
			sim.time_scale = _speed_before_moment
			_speed_before_moment = -1.0
		return

	var moment: Moment = _moments.pop_front()
	# Sólo una decisión para el reloj. Un hallazgo se enseña sin parar nada: si
	# cada paraje bautizado congelara la partida, en dos estaciones el jugador
	# aprendería a cerrar la tarjeta sin leerla.
	if moment.is_decision() and sim != null and _speed_before_moment < 0.0:
		_speed_before_moment = sim.time_scale
		sim.time_scale = 0.0
	_moment_card = _build_moment_card(moment)


func _build_moment_card(moment: Moment) -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER_TOP)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.add_theme_constant_override("margin_top", 24)
	add_child(margin)

	var frame := PanelContainer.new()
	frame.theme = _skin
	frame.custom_minimum_size = Vector2(430, 0)
	margin.add_child(frame)

	var pad := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	frame.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	pad.add_child(column)

	var head := Label.new()
	head.text = moment.title.to_upper()
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", _moment_tint(moment))
	column.add_child(head)

	var body := Label.new()
	body.text = moment.text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(406, 0)
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", UISkin.INK)
	column.add_child(body)

	# Quién, con nombre y edad. Es lo que hace que un percance duela.
	if moment.who != null:
		var who := Label.new()
		who.text = _person_card_line(moment.who)
		who.add_theme_font_size_override("font_size", 11)
		who.add_theme_color_override("font_color", UISkin.INK_SOFT)
		column.add_child(who)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)

	if moment.has_place:
		var look := Button.new()
		look.text = "Verlo"
		look.custom_minimum_size = Vector2(80, 26)
		look.pressed.connect(func() -> void: _look_at_world(moment.where))
		buttons.add_child(look)

	for option: Dictionary in moment.options:
		var pick := Button.new()
		pick.text = String(option["label"])
		pick.tooltip_text = String(option.get("hint", ""))
		pick.custom_minimum_size = Vector2(0, 26)
		pick.pressed.connect(func() -> void:
			var act: Callable = option["on_pick"]
			act.call()
			_show_next_moment())
		buttons.add_child(pick)

	if moment.options.is_empty():
		var seen := Button.new()
		seen.text = "Seguir"
		seen.custom_minimum_size = Vector2(80, 26)
		seen.pressed.connect(func() -> void: _show_next_moment())
		buttons.add_child(seen)

	return margin


## Una persona en dos líneas: quién es, no cuántos años de trabajo aporta.
func _person_card_line(person: Inhabitant) -> String:
	var parts: Array[String] = ["%d años" % person.age_years,
		Profession.job_name(person.job as Profession.Job).to_lower()]
	var best := _best_trait(person)
	if not best.is_empty():
		parts.append(best)
	if person.hurt_days > 0:
		parts.append("tocado %d días" % person.hurt_days)
	return "%s · %s" % [person.given_name, " · ".join(parts)]


## Nombres de las cualidades, para escribirlas en una ficha corta.
const STAT_WORDS := {
	Inhabitant.Stat.FUERZA: "fuerte",
	Inhabitant.Stat.RESISTENCIA: "resistente",
	Inhabitant.Stat.AGUDEZA: "espabilado",
}


## En qué destaca esta persona, dicho en una palabra. Vacío si en nada.
##
## Una sola, y sólo si de verdad destaca: una ficha que enumera las tres
## cualidades de todo el mundo no distingue a nadie de nadie, que es justo lo
## contrario de lo que se busca al ponerle cara a quien va a arriesgarse.
func _best_trait(person: Inhabitant) -> String:
	var best := ""
	var best_value := 0.55
	for stat: int in STAT_WORDS:
		var value := person.stat_in(stat as Inhabitant.Stat)
		if value > best_value:
			best_value = value
			best = String(STAT_WORDS[stat])
	return best


func _moment_tint(moment: Moment) -> Color:
	match moment.kind:
		Moment.Kind.PERCANCE: return UISkin.ALARM
		Moment.Kind.BERREA: return UISkin.OCHRE
		# El relato va en ocre, que es el color del pigmento con el que se
		# pinta: es la tarjeta que ofrece dejarlo en la pared.
		Moment.Kind.RELATO: return UISkin.OCHRE
		_: return UISkin.GREEN


## Cuánto se lleva acumulado de cara al invierno, siempre a la vista.
##
## La tensión central de la época —SLICE_PALEOLITICO §3: el otoño decide si se
## sobrevive al invierno— vivía repartida entre el almacén y la cabeza del
## jugador. Un número dentro de un panel de gestión no da urgencia: hay que ir a
## mirarlo, y se mira cuando ya se ha decidido. Esto va debajo del reloj, no se
## Cómo está la banda, en la barra de arriba.
##
## El hambre y el cansancio medios son las dos cifras que deciden si hay que
## mover gente HOY, y estaban escondidas una por una en quince fichas: para
## saber si la banda aguantaba había que abrirlas todas y sumar de cabeza.
##
## Van con el reloj y el invierno porque son la misma pregunta —¿aguantamos?—
## y se leen juntas: hambre alta con la despensa llena es un problema de
## reparto, y hambre alta con la despensa vacía es otro muy distinto.
func _build_band_gauge(strip: HBoxContainer) -> void:
	_band_label = Label.new()
	_band_label.add_theme_font_size_override("font_size", 11)
	_band_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_band_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_band_label)

	# El hambre y el cansancio, como BARRAS. Un porcentaje escrito hay que
	# leerlo y compararlo con el de hace un rato; una barra que sube o baja se
	# ve sin leer, que es lo que se pide de algo que esta en pantalla todo el
	# rato mientras se mira otra cosa.
	_hunger_bar = _strip_gauge(strip, "Hambre")
	_tired_bar = _strip_gauge(strip, "Cansancio")


## Una barra con su rotulo, para la tira de arriba.
func _strip_gauge(strip: HBoxContainer, caption: String) -> ProgressBar:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(box)

	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", UISkin.INK_FAINT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var meter := ProgressBar.new()
	meter.min_value = 0.0
	meter.max_value = 100.0
	meter.custom_minimum_size = Vector2(150, 12)
	meter.show_percentage = true
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(meter)
	return meter


## Repinta el estado de la banda. Va con el reloj, no por fotograma.
func _update_band_gauge() -> void:
	if _band_label == null or sim == null or sim.people.is_empty():
		return
	var hunger := 0.0
	var tired := 0.0
	var hurt := 0
	for person: Inhabitant in sim.people:
		hunger += person.hunger
		tired += person.fatigue
		if person.hurt_days > 0:
			hurt += 1
	var mouths := float(sim.people.size())
	hunger /= mouths
	tired /= mouths
	# Y lo que se echó a perder ayer. Estaba escrito -en la crónica y en una
	# línea del almacén, dentro de la lista de perecederos- y aun así no se
	# encontraba: es una cifra DIARIA y del día no se entera nadie leyendo una
	# ficha. Aquí sale sola, y sólo cuando hay algo que decir.
	var rot := ""
	if sim.spoiled_rations_today > 0.05:
		rot = "  ·  se pudrieron %.1f raciones" % sim.spoiled_rations_today
	_band_label.text = "%d personas%s%s" % [sim.people.size(),
		"  ·  %d tocados" % hurt if hurt > 0 else "", rot]
	if _hunger_bar != null:
		_hunger_bar.value = hunger
		_paint_gauge(_hunger_bar, hunger)
	if _tired_bar != null:
		_tired_bar.value = tired
		_paint_gauge(_tired_bar, tired)


## El color de una barra segun lo alta que este: la barra dice CUANTO y el
## color dice si hay que hacer algo.
func _paint_gauge(meter: ProgressBar, value: float) -> void:
	var tint := UISkin.GREEN
	if value > 75.0:
		tint = UISkin.ALARM
	elif value > 50.0:
		tint = UISkin.OCHRE
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	meter.add_theme_stylebox_override("fill", box)

## puede cerrar, y en otoño se pone en ocre.
func _build_winter_gauge(strip: HBoxContainer) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)

	_winter_label = Label.new()
	_winter_label.add_theme_font_size_override("font_size", 11)
	_winter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_winter_label)

	_winter_bar = ProgressBar.new()
	_winter_bar.custom_minimum_size = Vector2(220, 12)
	_winter_bar.max_value = 1.0
	_winter_bar.show_percentage = false
	_winter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_winter_bar)


## Repinta el medidor del invierno. Se llama con el reloj, no por fotograma.
func _update_winter_gauge() -> void:
	if _winter_label == null or sim == null:
		return
	var stock: Dictionary = sim.despensa.winter_stock()
	var share := float(stock["share"])
	_winter_bar.value = minf(share, 1.0)

	var season := GameState.season
	var head := "De cara al invierno"
	if season == Subsistence.Season.OTONO:
		head = "BERREA · de cara al invierno"
	elif season == Subsistence.Season.INVIERNO:
		head = "Invierno · reserva"
	_winter_label.text = "%s   %d de %d raciones  (%d %%)" % [
		head, int(stock["have"]), int(stock["needed"]), int(share * 100.0)]

	# Tres colores y no un degradado: lo que hace falta saber de un vistazo es
	# si se llega, si va justo o si no se llega.
	var tint := UISkin.INK_SOFT
	if share < 0.45:
		tint = UISkin.ALARM
	elif share < 0.9:
		tint = UISkin.OCHRE
	_winter_label.add_theme_color_override("font_color", tint)


## Pausa y velocidades, debajo de la fecha.
##
## Estaba en las teclas + y −, que además movían el reloj del sol y no el de la
## banda, así que acelerar descuadraba las dos cosas. Aquí son cuatro estados
## discretos y se ve cuál está puesto, que es lo que hace falta: nadie quiere
## afinar una velocidad, quiere pausar o correr.
func _build_speed_buttons(strip: HBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	strip.add_child(row)

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
## El estado de la banda en la barra de arriba: hambre y cansancio medios.
var _band_label: Label

## Las barras de hambre y cansancio de la tira de arriba.
var _hunger_bar: ProgressBar
var _tired_bar: ProgressBar

var _winter_label: Label
var _winter_bar: ProgressBar
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
		_clock.text = "%02d:%02d  ·  día %d  ·  %s, %s, año %d  ·  %s%s" % [
			hour, minute, sim.day,
			Subsistence.month_name(GameState.season, sim.season_day).capitalize(),
			Subsistence.season_name(GameState.season), GameState.year,
			sim.weather.name_text().to_lower(), _hearth_note()]

		_update_winter_gauge()
		_update_band_gauge()

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


## Lo que se dice del hogar en la barra de arriba.
##
## Sólo cuando algo va mal. Un aviso permanente de que el fuego está encendido
## es ruido —lo normal es que lo esté— y a los dos minutos deja de leerse; lo
## que hace falta es que se note el día que se apaga, sin tener que abrir la
## crónica para enterarse.
func _hearth_note() -> String:
	if sim == null:
		return ""
	if not sim.camp_built.get(CampProjects.Kind.HOGAR, false):
		return "  ·  sin hogar"
	if not sim.hearth_lit:
		return "  ·  EL HOGAR ESTÁ APAGADO"
	return ""


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
			shown_paraje = null
		# Y cerrar la ficha de una entidad apaga su rastro, por lo mismo: el
		# rastro lo pinta la ficha y sin ficha no tiene quién lo mantenga al
		# día, así que se quedaría congelado en el mapa para siempre.
		elif id == "entidad":
			_forget_entity())
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
	# Y la ficha de una entidad apaga su rastro, igual que al pulsar la cruz.
	if _windows.get("entidad", null) == best:
		_forget_entity()
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
		"oficios": show_professions()
		"territorio": show_territory()
		"cronica": show_lore()
		"parajes": show_places()
		"rastros": show_trails()
		"entidades": show_census()


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
		sim.reconocimiento.scout_towards(world)
		show_ground(world, terrain))
	row.add_child(go)

	if sim.has_scout_order:
		var stop := Button.new()
		stop.text = "Que decidan"
		stop.custom_minimum_size = Vector2(110, 26)
		stop.pressed.connect(func() -> void:
			sim.reconocimiento.clear_scout_order()
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

	# Quién de la banda se atreve, con nombre y cara y no como una cifra.
	#
	# Antes esto era una línea —«el mejor la ve al 62 %»— y un botón que mandaba
	# a quien la máquina eligiera. Perder «al mejor» en un percance no duele:
	# perder a Jara, de cuarenta y un años, que es la que sabe curtir, sí. Y el
	# botón que falla sin avisar no informa, castiga: por eso los que no se
	# atreven salen igual, apagados y diciendo por qué.
	_heading(body, "QUIÉN SUBE")
	if Ascent.needs_gear(hardness):
		_text(body, "Nadie: esto no es cuestión de pericia. Pide equipo que "
			+ "todavía no se sabe hacer.", true)
	else:
		var daring := sim.cumbres.climbers_for(peak)
		if daring.is_empty():
			_text(body, "Nadie de la banda tiene la pericia que pide.", true)
		for person: Inhabitant in daring:
			_climber_row(body, person, peak)
		_shy_climbers(body, peak, daring)

	if _peak_ordered and _peak_notice.is_empty():
		_notice(body, "Orden dada: alguien sale a por ella.", UISkin.OCHRE)
	elif not _peak_notice.is_empty():
		_notice(body, _peak_notice, UISkin.ALARM)


## Una fila por candidato: quién es, qué se le da bien y el botón de mandarlo.
func _climber_row(body: VBoxContainer, person: Inhabitant,
		peak: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	var send := Button.new()
	send.text = "Que suba"
	send.custom_minimum_size = Vector2(92, 24)
	send.add_theme_font_size_override("font_size", 11)
	send.pressed.connect(func() -> void:
		var problem := sim.cumbres.order_ascent(peak, person)
		_peak_notice = problem
		_peak_ordered = problem.is_empty()
		show_peak(peak))
	row.add_child(send)

	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	var label := Label.new()
	label.text = "%s · %d%% de ascensión" % [
		_person_card_line(person), int(person.skill_in(task) * 100.0)]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UISkin.INK)
	row.add_child(label)


## Y los que NO se atreven, dichos también.
##
## Un panel que sólo enseña a los que valen deja al jugador sin saber si le
## faltan manos o le falta pericia, que son dos problemas con dos remedios muy
## distintos.
func _shy_climbers(body: VBoxContainer, peak: Dictionary,
		daring: Array[Inhabitant]) -> void:
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	var shy: Array[String] = []
	for person: Inhabitant in sim.people:
		if daring.has(person) or not Profession.can_do(
				Profession.Job.EXPLORACION, person):
			continue
		shy.append("%s (%d%%)" % [person.given_name,
			int(person.skill_in(task) * 100.0)])
	if shy.is_empty():
		return
	_text(body, "No se atreven: " + ", ".join(shy), true)


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


## El árbol de oficios: qué sabe hacer la banda y en qué se puede repartir.
##
## Va aparte de «Trabajos» y no es lo mismo. Aquélla es la mesa de mando —cuánta
## gente en qué, con sus prioridades— y ésta es el mapa: qué oficios hay, en qué
## especialidades se abre cada uno, qué hace falta para cada especialidad y
## quién la ejerce hoy. Sin esto, la única forma de saber que la pesca de altura
## existe y pide embarcación era leer el código.
func show_professions() -> void:
	var body := _window("oficios", "Oficios")
	_clear(body)
	if sim == null:
		_text(body, "Sin asentamiento.")
		return

	_text(body, "Un oficio es cómo se organiza la banda; una especialidad es "
		+ "qué parte del monte se toca. Casi nadie vive de un solo trabajo: en "
		+ "una banda de quince, la especialización es la recompensa de haber "
		+ "crecido.", true)

	var counts := _job_headcount()
	for job: int in Profession.Job.values():
		if job == Profession.Job.OCIOSO:
			continue
		body.add_child(HSeparator.new())
		var here: int = counts.get(job, 0)
		_heading(body, "%s · %d %s" % [
			Profession.job_name(job as Profession.Job).to_upper(), here,
			"persona" if here == 1 else "personas"])
		_text(body, Profession.job_desc(job as Profession.Job), true)
		_text(body, "   pueden: %s" % _who_can(job as Profession.Job), true)

		var specialities := Profession.specialities_of(job as Profession.Job)
		if specialities.is_empty():
			_text(body, "   no se reparte en especialidades", true)
			continue
		for speciality: int in specialities:
			_speciality_line(body, job as Profession.Job,
				speciality as Profession.Speciality)


## Cuánta gente hay hoy en cada oficio.
func _job_headcount() -> Dictionary:
	var counts: Dictionary = {}
	for person: Inhabitant in sim.people:
		counts[person.job] = int(counts.get(person.job, 0)) + 1
	return counts


## Quién puede con un oficio, dicho en una línea.
func _who_can(job: Profession.Job) -> String:
	var entry: Dictionary = Profession.CATALOGUE[job]
	var parts: Array[String] = ["de %d a %d años" % [
		int(entry["min_age"]), int(entry["max_age"])]]
	if bool(entry["mobile"]):
		parts.append("adultos, y no quien esté criando")
	var able := 0
	for person: Inhabitant in sim.people:
		if Profession.can_do(job, person):
			able += 1
	parts.append("%d de los %d de la banda" % [able, sim.people.size()])
	return " · ".join(parts)


## Una especialidad: qué es, qué le hace falta y quién la ejerce hoy.
func _speciality_line(body: VBoxContainer, job: Profession.Job,
		speciality: Profession.Speciality) -> void:
	var doing: Array[String] = []
	for person: Inhabitant in sim.people:
		if person.job == job and person.current_speciality == speciality:
			doing.append(person.given_name)

	var blocked := _speciality_blocked(speciality)
	var mark := "·" if not blocked.is_empty() else ("◆" if not doing.is_empty() else "▸")
	_text(body, "   %s %s" % [mark,
		Profession.speciality_name(speciality)], blocked.is_empty() == false)
	_text(body, "       %s" % Profession.speciality_desc(speciality), true)
	if not blocked.is_empty():
		_text(body, "       falta: %s" % blocked, true)
	elif not doing.is_empty():
		_text(body, "       hoy: %s" % ", ".join(doing), true)


## Qué le falta a una especialidad para poder ejercerse, o "" si nada.
##
## Es la pregunta que no tenía respuesta en pantalla: por qué la pesca de altura
## sale en la tabla y no se puede elegir, o por qué el ahumado no hace nada.
func _speciality_blocked(speciality: Profession.Speciality) -> String:
	match speciality:
		Profession.Speciality.ALTURA:
			return "embarcación, y todavía no se sabe hacer"

	return ""


## Qué oficio se está mirando en la ventana de técnicas.
var _tech_tab: int = Profession.Job.MANUFACTURA


func show_tech() -> void:
	var body := _window("tecnicas", "Técnicas")
	_clear(body)
	if tech == null:
		_text(body, "Sin datos de técnica.")
		return

	_text(body, "En el Paleolítico nadie investiga: se aprende haciendo. Cada "
		+ "técnica sale de acumular jornadas en la actividad que la produce, y "
		+ "de gastar material aprendiendo: se estropean nódulos aprendiendo a "
		+ "tallarlos. Pon el ratón encima de una para ver qué pide.", true)
	_text(body, "verde: dominada    ocre: las jornadas están, falta el "
		+ "material    gris: falta lo de antes", true)

	# Una pestaña por oficio, y dentro el árbol dibujado. Ver [TechGraph].
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)
	for job: int in TechTree.BRANCHES:
		var button := Button.new()
		button.text = Profession.job_name(job as Profession.Job)
		button.add_theme_font_size_override("font_size", 11)
		button.custom_minimum_size = Vector2(0, 24)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if job == _tech_tab:
			button.add_theme_stylebox_override("normal",
				UISkin.button_box("pressed"))
			button.add_theme_color_override("font_color", UISkin.OCHRE)
		button.pressed.connect(func() -> void:
			_tech_tab = job
			show_tech())
		tabs.add_child(button)

	if not TechTree.BRANCHES.has(_tech_tab):
		_tech_tab = int(TechTree.BRANCHES.keys()[0])

	# El árbol es más ancho que la ventana: se desplaza en horizontal, que es
	# como se mira un árbol de progreso.
	var scroll := ScrollContainer.new()
	# Alto justo: la rama del hogar tiene UNA técnica y con un alto fijo la
	# ventana dejaba doscientos píxeles de negro debajo.
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	var graph := TechGraph.new()
	scroll.add_child(graph)
	graph.build(tech, _tech_tab)
	# Más doce de la barra de desplazamiento horizontal, que si no tapa la
	# fila de abajo.
	scroll.custom_minimum_size = Vector2(0, graph.custom_minimum_size.y + 12.0)

	body.add_child(HSeparator.new())
	_heading(body, "EL HOGAR")
	_text(body, "No son técnicas que se aprendan: son obras que se levantan en "
		+ "el abrigo, con su material y sus jornadas.", true)
	for kind: int in CampProjects.all():
		_camp_row(body, kind as CampProjects.Kind)

	body.add_child(HSeparator.new())
	_fishing_block(body)
	_hunting_block(body)
	_paintings_block(body)


## Una obra del abrigo: qué es, qué cuesta y en qué punto está.
func _camp_row(body: VBoxContainer, kind: CampProjects.Kind) -> void:
	if sim == null:
		return
	var name_text := CampProjects.project_name(kind)
	if sim.camp_built.get(kind, false):
		var state := ""
		if kind == CampProjects.Kind.HOGAR:
			state = " · encendido" if sim.hearth_lit else " · APAGADO"
		_text(body, "◆ %s%s" % [name_text, state])
		return

	var needs := CampProjects.requires(kind)
	if needs >= 0 and not sim.camp_built.get(needs, false):
		_text(body, "· %s — falta %s" % [name_text,
			CampProjects.project_name(needs as CampProjects.Kind).to_lower()], true)
		return

	if sim.camp_queue == kind:
		_bar(body, "▸ %s" % name_text,
			sim.camp_progress / maxf(CampProjects.labor_days(kind), 0.01))
	else:
		_text(body, "▸ %s" % name_text)
	_text(body, "     %s" % CampProjects.project_desc(kind), true)
	_text(body, "     %s · %.0f jornadas de hogar" % [
		_materials_line(CampProjects.materials(kind)),
		CampProjects.labor_days(kind)], true)


## Lo que pide una receta, con lo que hay al lado.
##
## «6 piedra, 3 leña» no dice si se puede hacer o no; «6 piedra (hay 14), 3 leña
## (hay 1)» sí, y de un vistazo. Es la mitad de lo que había que adivinar.
func _materials_line(recipe: Dictionary) -> String:
	if sim == null or recipe.is_empty():
		return "sin material"
	var parts: Array[String] = []
	for material: int in recipe:
		var wanted := float(recipe[material])
		var have := sim.store.amount(material as Materia.Kind)
		var mark := "" if have >= wanted else "  ¡faltan %.0f!" % (wanted - have)
		parts.append("%.0f %s (hay %.0f)%s" % [wanted,
			Materia.material_name(material as Materia.Kind).to_lower(),
			have, mark])
	return " · ".join(parts)


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
				sim.trampas.traps.size(), sim.trampas.trap_allowance()]
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

		# Y lo que anda por el coto y NO se puede cobrar por falta de arma. Es
		# la otra mitad de la puerta de [Fauna.huntable_with]: cerrarla en
		# silencio deja al jugador con una cuadrilla que vuelve de vacío de un
		# cotarro lleno de ciervos y ninguna forma de saber por qué.
		if speciality != Profession.Speciality.TRAMPAS:
			var coto := sim.parajes.chosen_for(Subsistence.Activity.CAZA)
			var donde := coto.position if coto != null else sim.home_position
			var escapa := Hunting.out_of_reach_text(speciality, donde,
				GameState.season as Subsistence.Season, sim.toolkit)
			if not escapa.is_empty():
				_text(body, "   %s" % escapa, true)

	# Y la línea de trampas, una por una. Es lo único que la banda deja
	# PLANTADO en el mapa, así que merece una lista y no un número.
	if sim.trampas.traps.is_empty():
		_text(body, "Sin una sola trampa puesta. Pon a alguien en trampas: "
			+ "es el único trabajo que rinde mientras la banda hace otra cosa.",
			true)
	else:
		for trap: Trap in sim.trampas.traps:
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
			sim.taller.workers_in(Subsistence.Activity.PESCA))
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
		# La nasa NO se mide en pescado al día: no es una jornada en el agua,
		# es un aparejo calado. Enseñarla con la cifra del arpón al lado hacía
		# creer que eran dos maneras de hacer lo mismo, y son dos cosas que se
		# hacen a la vez. Ver [Nasa].
		if Fishing.is_passive(method):
			note.text = "se cala y pesca sola" if why == "" else why
		else:
			note.text = "%.0f de pescado al día" % pescado if why == "" else why
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color",
			UISkin.INK_SOFT if why == "" else UISkin.INK_FAINT)
		row.add_child(note)

	_text(body, "Se pesca siempre con lo mejor que se pueda HOY. Si se rompe "
		+ "el último arpón o se acaba el cebo, se baja un escalón hasta que "
		+ "el taller reponga.", true)

	# Y la línea de nasas, una por una, igual que la de trampas: es lo otro que
	# la banda deja plantado en el mapa.
	if sim.techs != null and sim.techs.has(TechTree.Tech.NASA):
		if sim.nasas_line.nasas.is_empty():
			_text(body, "Sin una sola nasa calada. El pescador las revisa por "
				+ "la mañana y luego pesca: no le quita la jornada.", true)
		else:
			for nasa: Nasa in sim.nasas_line.nasas:
				_text(body, "   %s Nasa en %s — %.0f%% de vida, %d piezas  ·  %s"
					% ["◆" if nasa.has_catch() else "·",
						sim.parajes.place_name(nasa.position, sim.home_position),
						nasa.condition() * 100.0, nasa.taken,
						nasa.status_text()], not nasa.has_catch())
	body.add_child(HSeparator.new())


## Lo que hay pintado en la pared del fondo.
##
## Va con la caza y la pesca porque es de lo mismo: qué sabe hacer la banda y
## qué cambia. Una pared no es un adorno de la ficha —sube el techo de lo que
## se puede aprender de oídas sobre esa tarea, y lo sube para siempre— así que
## el jugador tiene que poder ver qué hay puesto. Ver [Tale].
func _paintings_block(body: VBoxContainer) -> void:
	if sim == null:
		return
	if sim.techs == null or not sim.techs.has(TechTree.Tech.ARTE):
		return
	_heading(body, "LA PARED DEL FONDO")

	if sim.painting_queue != null:
		_text(body, "Pintando: %s (%.0f%%)" % [sim.painting_queue.title,
			100.0 * sim.painting_progress / SettlementSim.PINTURA_JORNADAS])

	if sim.paintings.is_empty():
		var falta := sim.pinturas.painting_blocked_by()
		_text(body, "La pared está limpia. " + ("Lo que se cuenta dura lo que "
			+ "dure quien lo cuente." if falta.is_empty()
			else "Para pintar: %s." % falta), true)
	else:
		for tale: Tale in sim.paintings:
			_text(body, "   · %s — %s" % [tale.title, tale.stamp()])
		_text(body, "Lo que está en la pared se aprende aunque no quede nadie "
			+ "que estuviera allí.", true)
	body.add_child(HSeparator.new())


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
		_text(body, "Alimenta %.2f raciones por %s: %.0f kcal de las %.0f que "
			% [Materia.nutrition(kind), Materia.unit_name(kind),
				Materia.kcal(kind), Materia.KCAL_DIA]
			+ "come una persona al día.", true)
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
	shown_person = person
	var body := _window("persona", "Persona")
	_clear(body)

	_heading(body, person.given_name)
	_text(body, "%s · %s de %d años%s" % [
		"Mujer" if person.sex == Inhabitant.Sex.MUJER else "Hombre",
		person.age_name(), person.age_years,
		" · criando" if person.nursing else ""])

	body.add_child(HSeparator.new())
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

	# Y el resto del petate, que no va en `load` y por eso no se veía: el
	# apero con el que trabaja, los recipientes y el agua. «Qué lleva» decía
	# sólo lo recogido, o sea que un cazador con azagaya, cesto y odre lleno
	# salía con «las manos vacías» de vuelta a casa.
	body.add_child(HSeparator.new())
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


# ---------------------------------------------------------------- censo ---

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
	var body := _window("entidades", "Entidades pintadas")
	_clear(body)
	if census == null:
		_text(body, "No hay mundo montado todavía.")
		return

	var groups := census.groups()
	if groups.is_empty():
		_text(body, "No hay nada pintado.")
		return

	_text(body, "Lo que el juego tiene puesto en el mundo ahora mismo. Pincha "
		+ "una silueta para recorrer sus piezas una a una: la cámara va a cada "
		+ "una y, si es algo que anda, se le pinta el rastro por donde ha "
		+ "pasado.", true)

	var family := ""
	for group: Dictionary in groups:
		if String(group["family"]) != family:
			family = String(group["family"])
			_heading(body, family.to_upper())
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
	var body := _window("entidad", "Ficha")
	_clear(body)
	if key != _census_group:
		_census_group = key
		_census_anchor = _looking_at()
	if census == null:
		_text(body, "No hay mundo montado todavía.")
		return

	var entries := census.entries(key, _census_anchor)
	if entries.is_empty():
		_census_id = ""
		if trails:
			trails.stop_following()
		_text(body, "No queda ninguna a la vista.")
		_text(body, "Los props y los árboles de malla se descargan cuando la "
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
	_window("entidad", String(entry["title"]))

	_census_nav(body, key, _census_index, entries.size())
	_census_scope(body, key, entries.size())

	for line: String in (entry["lines"] as Array[String]):
		_text(body, line)

	# La distancia se calcula AQUÍ y no en el censo, contra la cámara de ahora
	# mismo y no contra el punto desde el que se ordenó la lista —ver
	# `_census_anchor`—. Son dos cosas distintas en cuanto el jugador se mueve,
	# y la que sirve para ir a ver algo es la de ahora.
	var spot: Vector3 = entry["pos"]
	var eye := _looking_at()
	_text(body, "En (%.0f, %.0f), a %.0f m de altura, a %.0f m de la cámara."
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
	if census != null:
		for group: Dictionary in census.groups():
			if String(group["key"]) == key:
				whole = int(group["count"])
				note = String(group["note"])
	if whole > shown:
		_text(body, "Se pueden recorrer %d. Hay %d %s." % [shown, whole, note],
			true)
	else:
		_text(body, "Hay %d, %s." % [whole, note], true)


## El rastro: se enciende solo con la ficha, y se dice cuando no hay ninguno.
##
## Decirlo importa. Sin la línea, una yesca sin rastro y un uro cuyo rastro no
## se está pintando por un fallo se ven exactamente igual —el mapa sin líneas—,
## y son dos cosas muy distintas.
func _census_trail(body: VBoxContainer, entry: Dictionary) -> void:
	if trails == null:
		return
	var trail: Callable = entry.get("trail", Callable())
	if not trail.is_valid():
		trails.stop_following()
		_text(body, "Esto no anda: no hay rastro que pintar.", true)
		return

	var tint: Color = entry.get("tint", Color.WHITE)
	trails.follow(trail, tint, sim.terrain() if sim else null,
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
	if trails:
		trails.stop_following()


## Desde dónde se mide «cerca».
##
## Es el punto que MIRA la cámara, no dónde está la cámara. Con la vista alta
## los dos quedan a cientos de metros uno del otro, y lo que el jugador tiene
## delante es el primero: ordenar por el segundo pone las primeras fichas
## detrás del hombro.
func _looking_at() -> Vector3:
	if camera != null:
		return camera.target_position
	if sim != null:
		return sim.home_position
	return Vector3.ZERO


## Lleva la cámara a un punto, y se acerca sólo si estaba lejos.
##
## Sólo si estaba lejos porque el zoom es del jugador: si ya está mirando de
## cerca, reencuadrarle en cada flecha le quita el encuadre que había elegido.
## Y el tope de acercamiento es el de la cámara del juego —`min_distance`, ver
## `OrbitalCamera.set_distance_limits`—, no un número puesto aquí: más cerca no
## se puede ir, ni con este botón ni con la rueda.
func _look_at_world(point: Vector3) -> void:
	if camera == null:
		return
	camera.set_target(point)
	var close_enough := camera.min_distance * 1.6
	if camera.orbit_distance > close_enough:
		camera.set_distance(close_enough)
