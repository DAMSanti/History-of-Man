class_name BarraSuperior
extends RefCounted
## La barra de arriba y la tarjeta que interrumpe.
##
## Sale de [GameUI] porque es lo unico de la interfaz que NO es una ventana. La
## barra esta SIEMPRE -reloj, hambre y cansancio medios de la banda, reserva de
## cara al invierno y los botones de velocidad- y la tarjeta de momento
## interrumpe: para el juego y pide mirar o decidir. Ver [Moment].
##
## El resto de [GameUI] son ventanas que se abren y se cierran, y para eso esta
## el marco -`_window`, `_bind`, `_text`- que se queda alli porque lo usan los
## cinco paneles.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


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
## Cuanto sitio se le guarda al minimapa en la barra, en pixeles.
##
## El minimapa se mete DENTRO de la barra de arriba, pero la barra no engorda
## entera: se queda fina y solo baja en el trozo que ocupa el mapa. Para eso el
## mapa vive en su propia capa, pegado arriba a la derecha y sin margen, y aqui
## se le reserva su ancho para que los medidores no acaben tapados.
##
## Son los 256 px del minimapa mas el borde del panel. Ver
## [Minimapa._build_minimap].
const HUECO_DEL_MAPA := 268.0


func _build_clock() -> void:
	var margin := MarginContainer.new()
	# Pegada arriba y estirada a los dos lados: es una BARRA, no un cartel.
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)

	var frame := PanelContainer.new()
	frame.theme = ui._skin
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 18)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(strip)

	# LOS BOTONES DE VELOCIDAD, A LA IZQUIERDA DEL TODO.
	#
	# Estaban al final, empujados a la derecha, y ahi es donde ahora se mete el
	# minimapa. Ademas es lo que mas se pulsa: la mano va sola a la esquina.
	_build_speed_buttons(strip)

	# El reloj se crea aqui pero se muda DEBAJO DEL MINIMAPA en cuanto ese se
	# construye -ver [Minimapa._build_minimap]-. Si no llega a haber minimapa,
	# se queda en la barra, que es lo que hacia siempre.
	ui._clock = Label.new()
	ui._clock.add_theme_font_size_override("font_size", 13)
	ui._clock.add_theme_color_override("font_color", UISkin.INK)
	ui._clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui._clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(ui._clock)

	_build_band_gauge(strip)
	_build_winter_gauge(strip)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(gap)

	# Y un hueco a la derecha del ancho del minimapa, para que los medidores no
	# se metan debajo de el: el minimapa vive en su propia capa, encima.
	var sitio_del_mapa := Control.new()
	sitio_del_mapa.custom_minimum_size = Vector2(HUECO_DEL_MAPA, 0)
	sitio_del_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(sitio_del_mapa)
	_update_clock()


## Engancha la simulación. Lo llama [DemoMain] al montar la escena.
func watch_moments(simulation: SettlementSim) -> void:
	if simulation.moment_raised.is_connected(_on_moment):
		return
	simulation.moment_raised.connect(_on_moment)


func _on_moment(moment: Moment) -> void:
	ui._moments.append(moment)
	if ui._moment_card == null:
		_show_next_moment()


func _show_next_moment() -> void:
	if ui._moment_card != null:
		ui._moment_card.queue_free()
		ui._moment_card = null
	if ui._moments.is_empty():
		# Se devuelve la velocidad que había, no una fija: si el jugador estaba
		# en pausa mirando algo, reanudarle la partida sería peor que no parar.
		if ui._speed_before_moment >= 0.0 and ui.sim != null:
			ui.sim.time_scale = ui._speed_before_moment
			ui._speed_before_moment = -1.0
		return

	var moment: Moment = ui._moments.pop_front()
	# Sólo una decisión para el reloj. Un hallazgo se enseña sin parar nada: si
	# cada paraje bautizado congelara la partida, en dos estaciones el jugador
	# aprendería a cerrar la tarjeta sin leerla.
	if moment.is_decision() and ui.sim != null and ui._speed_before_moment < 0.0:
		ui._speed_before_moment = ui.sim.time_scale
		ui.sim.time_scale = 0.0
	ui._moment_card = _build_moment_card(moment)


func _build_moment_card(moment: Moment) -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER_TOP)
	margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
	margin.add_theme_constant_override("margin_top", 24)
	ui.add_child(margin)

	var frame := PanelContainer.new()
	frame.theme = ui._skin
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
		look.pressed.connect(func() -> void: ui.censo._look_at_world(moment.where))
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


## En qué destaca esta persona, dicho en una palabra. Vacío si en nada.
##
## Una sola, y sólo si de verdad destaca: una ficha que enumera las tres
## cualidades de todo el mundo no distingue a nadie de nadie, que es justo lo
## contrario de lo que se busca al ponerle cara a quien va a arriesgarse.
func _best_trait(person: Inhabitant) -> String:
	var best := ""
	var best_value := 0.55
	for stat: int in GameUI.STAT_WORDS:
		var value := person.stat_in(stat as Inhabitant.Stat)
		if value > best_value:
			best_value = value
			best = String(GameUI.STAT_WORDS[stat])
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
	ui._band_label = Label.new()
	ui._band_label.add_theme_font_size_override("font_size", 11)
	ui._band_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui._band_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(ui._band_label)

	# El hambre y el cansancio, como BARRAS. Un porcentaje escrito hay que
	# leerlo y compararlo con el de hace un rato; una barra que sube o baja se
	# ve sin leer, que es lo que se pide de algo que esta en pantalla todo el
	# rato mientras se mira otra cosa.
	ui._hunger_bar = _strip_gauge(strip, "Hambre")
	ui._tired_bar = _strip_gauge(strip, "Cansancio")


## Una barra con su rotulo, para la tira de arriba.
func _strip_gauge(strip: HBoxContainer, caption: String) -> Muescas:
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

	# Muescas talladas y no barra de relleno: es como se cuenta en esta epoca
	# -los bastones de muescas estan atestiguados- y ademas se lee mejor.
	# Ver [Muescas] y docs/INTERFAZ.md.
	var meter := Muescas.new()
	meter.custom_minimum_size = Vector2(150, 13)
	box.add_child(meter)
	return meter


## Repinta el estado de la banda. Va con el reloj, no por fotograma.
func _update_band_gauge() -> void:
	if ui._band_label == null or ui.sim == null or ui.sim.people.is_empty():
		return
	var hunger := 0.0
	var tired := 0.0
	var hurt := 0
	for person: Inhabitant in ui.sim.people:
		hunger += person.hunger
		tired += person.fatigue
		if person.hurt_days > 0:
			hurt += 1
	var mouths := float(ui.sim.people.size())
	hunger /= mouths
	tired /= mouths
	# Y lo que se echó a perder ayer. Estaba escrito -en la crónica y en una
	# línea del almacén, dentro de la lista de perecederos- y aun así no se
	# encontraba: es una cifra DIARIA y del día no se entera nadie leyendo una
	# ficha. Aquí sale sola, y sólo cuando hay algo que decir.
	var rot := ""
	if ui.sim.spoiled_rations_today > 0.05:
		rot = "  ·  se pudrieron %.1f raciones" % ui.sim.spoiled_rations_today
	ui._band_label.text = "%d personas%s%s" % [ui.sim.people.size(),
		"  ·  %d tocados" % hurt if hurt > 0 else "", rot]
	if ui._hunger_bar != null:
		ui._hunger_bar.valor = hunger / 100.0
		_paint_gauge(ui._hunger_bar, hunger)
	if ui._tired_bar != null:
		ui._tired_bar.valor = tired / 100.0
		_paint_gauge(ui._tired_bar, tired)


## El color de una barra segun lo alta que este: la barra dice CUANTO y el
## color dice si hay que hacer algo.
func _paint_gauge(meter: Muescas, value: float) -> void:
	var tint := UISkin.GREEN
	if value > 75.0:
		tint = UISkin.ALARM
	elif value > 50.0:
		tint = UISkin.OCHRE
	meter.tinta = tint


## puede cerrar, y en otoño se pone en ocre.
func _build_winter_gauge(strip: HBoxContainer) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)

	ui._winter_label = Label.new()
	ui._winter_label.add_theme_font_size_override("font_size", 11)
	ui._winter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ui._winter_label)

	ui._winter_bar = ProgressBar.new()
	ui._winter_bar.custom_minimum_size = Vector2(220, 12)
	ui._winter_bar.max_value = 1.0
	ui._winter_bar.show_percentage = false
	ui._winter_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ui._winter_bar)


## Repinta el medidor del invierno. Se llama con el reloj, no por fotograma.
func _update_winter_gauge() -> void:
	if ui._winter_label == null or ui.sim == null:
		return
	var stock: Dictionary = ui.sim.despensa.winter_stock()
	var share := float(stock["share"])
	ui._winter_bar.value = minf(share, 1.0)

	var season := GameState.season
	var head := "De cara al invierno"
	if season == Subsistence.Season.OTONO:
		head = "BERREA · de cara al invierno"
	elif season == Subsistence.Season.INVIERNO:
		head = "Invierno · reserva"
	# Las raciones, CON DECIMAL. Redondeadas a entero, el trasiego de un dia
	# normal -media racion arriba, media abajo- no se veia moverse, y la cifra
	# parecia congelada mientras la despensa se vaciaba de verdad.
	ui._winter_label.text = "%s   %.1f de %.0f raciones  (%d %%)" % [
		head, float(stock["have"]), float(stock["needed"]), int(share * 100.0)]

	# Tres colores y no un degradado: lo que hace falta saber de un vistazo es
	# si se llega, si va justo o si no se llega.
	var tint := UISkin.INK_SOFT
	if share < 0.45:
		tint = UISkin.ALARM
	elif share < 0.9:
		tint = UISkin.OCHRE
	ui._winter_label.add_theme_color_override("font_color", tint)


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

	ui._speed_buttons.clear()
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

		ui._speed_buttons.append({"button": button, "icon": icon, "speed": speed})

	_paint_speed_buttons()


func _set_speed(speed: float) -> void:
	if ui.sim == null:
		return
	ui.sim.time_scale = speed
	_paint_speed_buttons()


## El estado puesto se marca en ocre; los demás quedan apagados.
func _paint_speed_buttons() -> void:
	var current := ui.sim.time_scale if ui.sim else 1.0
	for entry: Dictionary in ui._speed_buttons:
		var active: bool = is_equal_approx(float(entry["speed"]), current)
		var icon: TimeIcon = entry["icon"]
		icon.tint = UISkin.OCHRE if active else UISkin.INK_SOFT
		icon.queue_redraw()
		var button: Button = entry["button"]
		button.add_theme_stylebox_override("normal",
			UISkin.button_box("pressed" if active else "normal"))


func _update_clock() -> void:
	if ui._clock == null:
		return
	if ui.sim == null:
		ui._clock.text = "—"
		return

	var hour := int(ui.sim.hour)
	var minute := int((ui.sim.hour - float(hour)) * 60.0)
	var stamp := hour * 60 + minute
	if stamp != ui._clock_minute:
		ui._clock_minute = stamp
		ui._clock.text = "%02d:%02d  ·  día %d  ·  %s, %s, año %d  ·  %s%s" % [
			hour, minute, ui.sim.day,
			Subsistence.month_name(GameState.season, ui.sim.season_day).capitalize(),
			Subsistence.season_name(GameState.season), GameState.year,
			ui.sim.weather.name_text().to_lower(), _hearth_note()]

		_update_winter_gauge()
		_update_band_gauge()

	# De noche el color baja: se ve de un vistazo si la banda está trabajando
	# o durmiendo sin tener que leer la hora
	var night := ui.sim.hour < SettlementSim.HORA_DESPERTAR \
		or ui.sim.hour >= SettlementSim.HORA_DORMIR
	if night != ui._clock_night:
		ui._clock_night = night
		ui._clock.add_theme_color_override("font_color",
			UISkin.INK_SOFT if night else UISkin.INK)

	if not is_equal_approx(ui._clock_speed, ui.sim.time_scale):
		ui._clock_speed = ui.sim.time_scale
		_paint_speed_buttons()

	# Un diario que se escribe solo no sirve de nada si nadie lo abre: el
	# botón avisa de cuántas anotaciones hay sin leer.
	if ui._lore_button and ui.sim.chronicle:
		var pending := ui.sim.chronicle.unread
		if pending != ui._lore_pending:
			ui._lore_pending = pending
			ui._lore_button.text = "Crónica" if pending <= 0 else "Crónica ·%d" % pending
			ui._lore_button.add_theme_color_override("font_color",
				UISkin.OCHRE if pending > 0 else UISkin.INK)


## Lo que se dice del hogar en la barra de arriba.
##
## Sólo cuando algo va mal. Un aviso permanente de que el fuego está encendido
## es ruido —lo normal es que lo esté— y a los dos minutos deja de leerse; lo
## que hace falta es que se note el día que se apaga, sin tener que abrir la
## crónica para enterarse.
func _hearth_note() -> String:
	if ui.sim == null:
		return ""
	if not ui.sim.camp_built.get(CampProjects.Kind.HOGAR, false):
		return "  ·  sin hogar"
	if not ui.sim.hearth_lit:
		return "  ·  EL HOGAR ESTÁ APAGADO"
	return ""
