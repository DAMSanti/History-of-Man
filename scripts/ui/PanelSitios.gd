class_name PanelSitios
extends RefCounted
## Que hay donde has pinchado.
##
## Sale de [GameUI] y es el trozo mas grande que le quedaba: seis fichas que
## responden a la misma pregunta desde angulos distintos -el suelo desnudo, un
## paraje con nombre, una cumbre, un recurso del suelo, una boca de cueva y la
## lista entera de sitios conocidos-.
##
## El orden en que se prueban al pinchar NO esta aqui sino en
## `DemoMain._pinchar_en_el_mundo`, y tiene su razon: los parajes son chapas
## que flotan sobre el terreno, o sea lo mas alto y lo que el jugador esta
## buscando; el suelo desnudo va el ultimo.
##
## Se comprueban con `scripts/tests/FichaSitioProbe.gd`, que las monta todas y
## cuenta las filas: ninguna prueba de la suite las abre.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


## La ficha de un trozo de terreno cualquiera.
##
## Es la otra mitad del clic como verbo. Señalar un paraje dice «id a trabajar
## ahí»; señalar monte pelado dice «id a MIRAR allí», que es una apuesta: no
## se sabe qué hay. Y la ficha nunca es un clic perdido, porque aunque no
## mandes nada te dice qué suelo es y si se puede llegar.
func show_ground(world: Vector3, terrain: TerrainGenerator) -> void:
	var body := ui._window("terreno", "El terreno")
	ui._clear(body)
	if ui.sim == null or terrain == null:
		ui._text(body, "Sin asentamiento.")
		return

	var away := int(Vector2(world.x - ui.sim.home_position.x,
		world.z - ui.sim.home_position.z).length())
	var metres := int(world.y * terrain.meters_per_unit
		/ maxf(terrain.vertical_exaggeration, 0.001))
	# El sitio dicho como lo diria alguien de la banda, no en coordenadas: es
	# lo que hace que la cronica y las ordenes se lean
	ui._heading(body, ui.sim.parajes.place_name(world, ui.sim.home_position).capitalize())
	ui._text(body, "A %d m del abrigo · cota %d m" % [away, metres], true)

	# Qué se pisa y si se puede pisar: es lo que decide si mandar a alguien
	var slope := terrain.get_slope_at(world)
	var ford := terrain.crossing_difficulty_at(world)
	var ground := Traversal.classify_ground(slope, ford)
	var passable := Traversal.is_passable(slope, ford, ui.sim.has_boat, ui.sim.has_bridge)

	ui._text(body, "Suelo: %s · pendiente %d%%" % [
		_ground_name(ground), int(slope * 100.0)])

	if not passable:
		ui._notice(body, "No se puede pasar por aquí: %s." % (
			"el agua corta el paso" if ford > 0.0
			else "la pendiente ya no es andar, es trepar"), UISkin.ALARM)

	# Y lo que la banda sabe de este sitio, que es la mitad del juego
	if ui.knowledge:
		var seen := ui.knowledge.explored_at(world)
		if seen < 0.05:
			ui._text(body, "Nadie ha estado aquí. No se sabe qué hay.")
		elif seen < 0.5:
			ui._text(body, "Visto de lejos, sin detalle.", true)
		else:
			ui._text(body, "Terreno conocido.", true)

	var close := ui.sim.parajes.near(Subsistence.Activity.RECOLECCION, world, 200.0)
	if close:
		ui._text(body, "Cerca queda %s." % close.name_text, true)

	# --- el verbo ---------------------------------------------------------
	ui._heading(body, "QUÉ SE HACE")

	# El tiempo cambia si conviene salir hoy o esperar, así que va donde se
	# toma esa decisión y no sólo en el reloj
	if ui.sim.weather.keeps_indoors():
		ui._notice(body, "%s Mandar a alguien hoy es mandarlo a que se vuelva."
			% ui.sim.weather.tell(), UISkin.ALARM)
	elif ui.sim.weather.risk_factor() > 1.4 or ui.sim.weather.sight_factor() < 0.6:
		ui._notice(body, "%s Se anda peor y se ve menos." % ui.sim.weather.tell(),
			UISkin.OCHRE)

	var explorers := 0
	for person: Inhabitant in ui.sim.people:
		if person.job == Profession.Job.EXPLORACION:
			explorers += 1

	if explorers <= 0:
		ui._notice(body, "No hay nadie en exploración. Ponle gente en Trabajos y "
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
		ui.sim.reconocimiento.scout_towards(world)
		show_ground(world, terrain))
	row.add_child(go)

	if ui.sim.has_scout_order:
		var stop := Button.new()
		stop.text = "Que decidan"
		stop.custom_minimum_size = Vector2(110, 26)
		stop.pressed.connect(func() -> void:
			ui.sim.reconocimiento.clear_scout_order()
			show_ground(world, terrain))
		row.add_child(stop)

		ui._notice(body, "Hay una partida en camino %s."
			% ui.sim.parajes.place_name(ui.sim.scout_order, ui.sim.home_position),
			UISkin.OCHRE)

	ui._text(body, "Los %d de exploración van adonde les mandes. No traen comida: "
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
	var is_new_paraje := ui.shown_paraje != paraje
	ui.shown_paraje = paraje
	var body := ui._window("paraje", paraje.name_text)
	ui._clear(body)

	# La mancha de terreno que ocupa, SOLO mientras su ficha esté abierta. Una
	# capa permanente sobre el paisaje lo tapa, y el paisaje es medio juego.
	if is_new_paraje and ui.markers and ui.sim:
		ui.markers.show_extent(paraje, ui.sim.terrain(), ui.field)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	# Varios oficios pueden coincidir en el mismo trozo de monte -un cotarro
	# con caza, avellanas y buena piedra a la vez-, y se leen como UN SOLO
	# paraje: un marcador, una ficha con todo junto, aunque por debajo sigan
	# siendo registros separados -cada uno con su propio reparto de trabajo,
	# que es lo que de verdad decide a quién se manda adónde.
	var away := int(paraje.distance_from(ui.sim.home_position))
	var activities: Array[String] = []
	for activity_key: int in paraje.activities:
		activities.append(Subsistence.activity_name(
			activity_key as Subsistence.Activity))
	if activities.is_empty():
		activities.append(Subsistence.activity_name(paraje.activity))
	ui._heading(body, "%s · a %d m del abrigo" % [", ".join(activities), away])

	var walking := int(float(away) / maxf(ui.sim.walk_speed, 1.0) / 60.0)
	ui._text(body, "Se tarda cerca de %d minutos de reloj en llegar, ida sola."
		% maxi(walking, 1), true)

	# Y lo que hay, UNA sola vez: `fill_contents` ya recorre las cinco
	# actividades de este punto, así que no hay una lista por oficio que
	# repetir. Los botones de "qué se hace" se fueron a peticion expresa:
	# la ficha es para MIRAR el sitio; a quién se manda se decide en el
	# panel de trabajos.
	_paraje_contents(body, paraje)

	ui._heading(body, "CÓMO SE ENCONTRÓ")
	ui._text(body, "La banda lo dio por conocido el día %d. Un sitio deja de ser "
		% paraje.found_day
		+ "monte y pasa a tener nombre cuando se ha trabajado lo bastante como "
		+ "para volver a él a propósito.", true)


## Lo que se sabe de una cumbre, y la decisión de intentarla.
##
## Una cumbre no es un tajo: no tiene contenidos ni cuadrilla. Tiene altura,
## dureza y una pregunta —¿la intentamos?—, y hasta ahora esa pregunta la
## contestaba la banda sola sin que el jugador pudiera meterse.
func show_peak(peak: Dictionary) -> void:
	ui.shown_peak = peak
	if ui.sim == null or peak.is_empty():
		return

	var where := ui.sim.parajes.place_name(peak["pos"] as Vector3, ui.sim.home_position)
	var body := ui._window("cima", "Cumbre %s" % where)
	ui._clear(body)

	var rise := float(peak.get("rise", 0.0))
	var hardness := float(peak.get("hard", 0.0))
	var away := int((peak["pos"] as Vector3).distance_to(ui.sim.home_position))
	ui._heading(body, "Se levanta %d m sobre el valle · a %d m del abrigo"
		% [int(rise), away])

	ui._bar(body, "Dureza", hardness)
	ui._text(body, _peak_hardness_text(hardness), true)

	# Quién de la banda se atreve, con nombre y cara y no como una cifra.
	#
	# Antes esto era una línea —«el mejor la ve al 62 %»— y un botón que mandaba
	# a quien la máquina eligiera. Perder «al mejor» en un percance no duele:
	# perder a Jara, de cuarenta y un años, que es la que sabe curtir, sí. Y el
	# botón que falla sin avisar no informa, castiga: por eso los que no se
	# atreven salen igual, apagados y diciendo por qué.
	ui._heading(body, "QUIÉN SUBE")
	if Ascent.needs_gear(hardness):
		ui._text(body, "Nadie: esto no es cuestión de pericia. Pide equipo que "
			+ "todavía no se sabe hacer.", true)
	else:
		var daring := ui.sim.cumbres.climbers_for(peak)
		if daring.is_empty():
			ui._text(body, "Nadie de la banda tiene la pericia que pide.", true)
		for person: Inhabitant in daring:
			_climber_row(body, person, peak)
		_shy_climbers(body, peak, daring)

	if ui._peak_ordered and ui._peak_notice.is_empty():
		ui._notice(body, "Orden dada: alguien sale a por ella.", UISkin.OCHRE)
	elif not ui._peak_notice.is_empty():
		ui._notice(body, ui._peak_notice, UISkin.ALARM)


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
		var problem := ui.sim.cumbres.order_ascent(peak, person)
		ui._peak_notice = problem
		ui._peak_ordered = problem.is_empty()
		show_peak(peak))
	row.add_child(send)

	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	var label := Label.new()
	label.text = "%s · %d%% de ascensión" % [
		ui.barra._person_card_line(person), int(person.skill_in(task) * 100.0)]
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
	for person: Inhabitant in ui.sim.people:
		if daring.has(person) or not Profession.can_do(
				Profession.Job.EXPLORACION, person):
			continue
		shy.append("%s (%d%%)" % [person.given_name,
			int(person.skill_in(task) * 100.0)])
	if shy.is_empty():
		return
	ui._text(body, "No se atreven: " + ", ".join(shy), true)


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
	var body := ui._window("parajes", "Parajes")
	ui._clear(body)
	if ui.sim == null or ui.sim.parajes == null:
		ui._text(body, "Sin asentamiento.")
		return

	var places := ui.sim.parajes.list
	if places.is_empty():
		ui._text(body, "Todavía no hay ningún paraje con nombre. Se bautizan "
			+ "solos cuando la banda conoce un sitio lo bastante bien como "
			+ "para volver a él sin pensarlo.", true)
		return

	ui._heading(body, "%d PARAJES CONOCIDOS" % places.size())
	ui._text(body, "Ordenados por cercanía. Pincha uno para verlo y mandar gente.",
		true)

	# Por cercanía: el que está a diez minutos importa más que el que está a
	# dos horas, y es como los tiene ordenados la cabeza de cualquiera
	var sorted: Array[Paraje] = []
	sorted.assign(places)
	sorted.sort_custom(func(a: Paraje, b: Paraje) -> bool:
		return a.distance_from(ui.sim.home_position) < b.distance_from(ui.sim.home_position))

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
	icon.custom_minimum_size = Vector2(GameUI.COL_ICON - 4, GameUI.COL_ICON - 4)
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
	away.text = "%d m" % int(paraje.distance_from(ui.sim.home_position))
	away.custom_minimum_size = Vector2(56, 0)
	away.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	away.add_theme_font_size_override("font_size", 11)
	away.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(away)

	# CUANTO SE SABE DE ESTE SITIO, en la lista y no solo al abrirlo.
	#
	# Es lo que decide adonde va la siguiente batida -ver
	# [SettlementSim._paraje_to_survey]-, asi que el jugador tiene que poder
	# leerlo de un vistazo y en el mismo orden en que la banda lo va a
	# trabajar: la lista va de mas cerca a mas lejos, y este numero dice cual
	# de los cercanos todavia tiene «???».
	var sabido := Label.new()
	sabido.custom_minimum_size = Vector2(46, 0)
	sabido.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sabido.add_theme_font_size_override("font_size", 11)
	row.add_child(sabido)
	# Atado, que se mueve solo: una batida resuelve una incognita por jornada
	# y esto tiene que bajar de «???» sin reconstruir la lista.
	ui._bind(sabido, func() -> void:
		var cuanto := paraje.known_fraction()
		sabido.text = "%d %%" % int(round(cuanto * 100.0))
		if not paraje.has_unknowns():
			sabido.add_theme_color_override("font_color", UISkin.GREEN)
		elif cuanto < 0.5:
			sabido.add_theme_color_override("font_color", UISkin.OCHRE)
		else:
			sabido.add_theme_color_override("font_color", UISkin.INK_SOFT))

	var note := Label.new()
	note.add_theme_font_size_override("font_size", 10)
	note.clip_text = true
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(note)
	# El estado cambia con la temporada y con quien esté trabajando ahí, así
	# que va atado: se refresca sin reconstruir la lista
	ui._bind(note, func() -> void:
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

	frame.tooltip_text = "%s\nDescubierto el día %d · %s\nSe sabe el %d %% de lo que hay%s\n%s" % [
		paraje.name_text, paraje.found_day,
		Materia.material_name(paraje.kind),
		int(round(paraje.known_fraction() * 100.0)),
		"" if not paraje.has_unknowns() else ": quedan «???» que resolver",
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
	ui._heading(body, "QUÉ HAY AQUÍ · SE SABE EL %.0f%%" % (known * 100.0))
	ui._bar(body, "Conocido", known)

	if paraje.has_unknowns():
		ui._text(body, "Quedan cosas por averiguar. Una batida aquí resuelve una "
			+ "cada jornada, empezando por lo que más abunde.", true)
	else:
		ui._text(body, "Sitio conocido a fondo: no queda nada que averiguar.", true)

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

	ui._heading(body, "FAUNA")
	for name: String in species:
		_fauna_row(body, name)


## Una línea de animal: su propio icono, no el de la carne.
func _fauna_row(body: VBoxContainer, species: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)

	var icon := MateriaIcon.for_fauna(species)
	icon.custom_minimum_size = Vector2(GameUI.COL_ICON - 4, GameUI.COL_ICON - 4)
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
	if sabido and ui.field:
		# De TODA la mancha, no de la celda del centro: la cuadrilla se
		# reparte por el sitio y gasta las de alrededor, así que mirando
		# solo el centro la cifra no bajaba nunca.
		stock = ui.field.stock_fraction_in(
			activity as Subsistence.Activity, paraje.huella)

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
	icon.custom_minimum_size = Vector2(GameUI.COL_ICON - 4, GameUI.COL_ICON - 4)
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
		if ui.sim and activity >= 0:
			quantity = ui.sim.remaining_units_in(paraje,
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


## Ficha de un recurso del mapa.
##
## Se abre al pinchar una mata, un canto o una cuerna. Dice qué es, cuánto
## queda en ese paraje y —lo que de verdad importa— si la banda sabe que está
## ahí, porque saberlo y que exista son cosas distintas.
func show_resource(kind: Materia.Kind, world: Vector3,
		activity: Subsistence.Activity) -> void:
	var body := ui._window("recurso", "Recurso")
	ui._clear(body)

	ui._heading(body, Materia.material_name(kind))
	ui._text(body, Materia.describe(kind))

	body.add_child(HSeparator.new())
	ui._heading(body, "AQUÍ")

	if ui.field:
		var cell_x := clampi(int(world.x / ui.field.world_size.x * float(ui.field.width)),
			0, ui.field.width - 1)
		var cell_z := clampi(int(world.z / ui.field.world_size.y * float(ui.field.height)),
			0, ui.field.height - 1)
		var stock := ui.field.stock_fraction(activity, cell_x, cell_z)
		ui._bar(body, "Lo que queda en el paraje", stock)
		if stock < 0.4:
			ui._text(body, "⚠ Esquilmado. Se repone, pero despacio: una mancha "
				+ "casi vacía tarda desproporcionadamente en volver.")

		var season := ResourceField.seasonal_factor(activity, GameState.season)
		ui._text(body, "Temporada: %s, rinde ×%.2f" % [
			Subsistence.season_name(GameState.season), season], true)

	if ui.knowledge:
		var known := ui.knowledge.familiarity_at(activity, world)
		ui._bar(body, "Lo que la banda conoce de aquí", known)
		if known < BandKnowledge.KNOWN_ENOUGH:
			ui._text(body, "La banda no tiene este paraje localizado: aunque esté "
				+ "aquí, no vendrá sola. Hay que pisarlo para que cuente.", true)

	body.add_child(HSeparator.new())
	ui._heading(body, "QUÉ DA")
	ui._text(body, "Una unidad son %s: %s y %s." % [
		Materia.unit_name(kind),
		Materia.format_weight(Materia.kg_per_unit(kind)),
		Materia.format_volume(Materia.litres_per_unit(kind))], true)

	if Materia.is_food(kind):
		# UN número, sacado de las dos cuentas. Ver [Materia.nutrition].
		ui._text(body, "Alimenta %.1f raciones por %s." % [
			Materia.nutrition(kind), Materia.unit_name(kind)], true)
		ui._text(body, "Trae %.0f kcal de las %.0f y %.0f g de proteína "
			% [Materia.kcal(kind), Materia.KCAL_DIA, Materia.protein(kind)]
			+ "aprovechable de los %.0f que come una persona al día."
				% Materia.PROTEINA_DIA, true)
		# Y por qué sale ese número y no otro: lo que sobra de un nutriente no
		# sustituye a lo que falta del otro. Ver [Materia.EXCEDENTE].
		var energia := Materia.kcal(kind) / Materia.KCAL_RACION
		var proteina := Materia.protein(kind) / Materia.PROTEINA_RACION
		if proteina > energia * 1.2:
			ui._text(body, "Sostiene más de lo que llena: es de lo que hace "
				+ "falta para que lo demás sirva de algo.", true)
		elif energia > proteina * 1.2:
			ui._text(body, "Llena más de lo que sostiene, y lo que sobra de "
				+ "una cosa no tapa lo que falta de la otra.", true)
	var life := Materia.shelf_life(kind)
	if life <= 0:
		ui._text(body, "No se estropea.", true)
	else:
		ui._text(body, "Aguanta %d días guardado." % life, true)

	if ui.sim:
		ui._text(body, "En el abrigo: %.0f %s" % [
			ui.sim.store.amount(kind), Materia.unit_name(kind)], true)

	ui._text(body, "Lo trae: %s" % Subsistence.activity_name(activity), true)


## Ventana de un elemento pinchado en el mundo.
func show_feature(data: Dictionary, world: Vector3, home: Vector3) -> void:
	var body := ui._window("lugar", "Lugar")
	ui._clear(body)

	var feature_class := int(data.get("class", Site.Feature.OTRO)) as Site.Feature
	var name_text := String(data.get("name", ""))
	if name_text.is_empty():
		name_text = "Cavidad sin nombre"

	ui._heading(body, name_text)
	ui._text(body, Site.feature_name(feature_class))
	body.add_child(HSeparator.new())

	ui._heading(body, "LO QUE SE VE")
	var elevation := world.y
	var distance := Vector2(world.x - home.x, world.z - home.z).length()
	ui._text(body, "A %.0f m del campamento, a %.0f m de altitud." % [distance, elevation], true)
	if not String(data.get("kind", "")).is_empty():
		ui._text(body, "Tipo en el registro: %s" % data["kind"], true)
	if not String(data.get("period", "")).is_empty():
		ui._text(body, "Periodo documentado: %s" % data["period"], true)
	ui._text(body, "Coordenadas: %.5f N, %.5f E" % [
		float(data.get("lat", 0.0)), float(data.get("lon", 0.0))], true)

	body.add_child(HSeparator.new())
	ui._heading(body, "QUÉ OFRECE")
	match feature_class:
		Site.Feature.ABRIGO:
			ui._text(body, "Abrigo natural: se ocupa sin construir nada, que en el "
				+ "Paleolítico es la única forma de pasar el invierno. La pared "
				+ "seca del fondo sirve además de soporte para pintar.")
			ui._text(body, "Una cavidad de boca ancha y orientada al sur reúne las "
				+ "dos cosas que hacen habitable una cueva: entra luz buena "
				+ "parte del día y no entra el viento del norte.", true)
		Site.Feature.SURGENCIA:
			ui._text(body, "Agua todo el año, no estacional. Es lo que decide si un "
				+ "sitio se puede ocupar en verano seco.")
		Site.Feature.SIMA:
			ui._text(body, "Pozo vertical. No se ocupa y es peligroso, pero delata "
				+ "caliza: donde hay simas hay cuevas.")
		_:
			ui._text(body, "Elemento del terreno.")

	body.add_child(HSeparator.new())
	ui._heading(body, "QUÉ HACER")
	for entry: Array in _actions_for(feature_class):
		var button := Button.new()
		button.text = entry[1]
		button.tooltip_text = entry[2]
		button.pressed.connect(func() -> void:
			ui.cave_action.emit(entry[0] as String, data))
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
