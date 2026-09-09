class_name PanelRastros
extends RefCounted
## Por donde ha andado la banda y que sabe de su territorio.
##
## Dos ventanas que son la misma pregunta desde dos lados: RASTROS mira lo que
## ha hecho cada persona -adonde fue, cuantas horas y que trajo- y TERRITORIO
## mira lo que la banda sabe del mapa. Es la ventana para ver el juego por
## dentro: responde a «¿la recoleccion no trae nada porque va lejos o porque da
## vueltas cerca?» sin tener que adivinarlo.
##
## Un oficio cada vez, a proposito: con quince rastros encima no se ve nada.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


## Por dónde ha andado la banda y qué ha hecho en cada sitio.
##
## Es la ventana para mirar el juego por dentro. Responde preguntas que si no
## hay que adivinar: ¿la recolección no trae nada porque va lejos o porque da
## vueltas cerca? ¿el batidor repite zona? ¿la caza cruza el río o lo rodea?
##
## Un oficio cada vez, a propósito: con quince rastros encima no se ve nada, y
## la pregunta siempre es sobre un oficio concreto.
func show_trails() -> void:
	var body := ui._window("rastros", "Rastros")
	ui._clear(body)
	if ui.sim == null or ui.trails == null:
		ui._text(body, "Sin asentamiento.")
		return

	# Los atascos, contados por motivo. Un atasco es una anécdota; veinte del
	# mismo motivo son un fallo con nombre, y esta es la pantalla donde eso
	# tiene que verse.
	if not ui.sim.stuck_tally.is_empty():
		var total := 0
		for why: String in ui.sim.stuck_tally:
			total += int(ui.sim.stuck_tally[why])
		ui._heading(body, "ATASCOS: %d" % total)
		ui._text(body, "Nadie debería quedarse atascado. Cuando pasa, aquí sale "
			+ "por qué — y el motivo apunta a la pieza que hay que arreglar.",
			true)
		var reasons: Array[String] = []
		reasons.assign(ui.sim.stuck_tally.keys())
		reasons.sort_custom(func(a: String, b: String) -> bool:
			return int(ui.sim.stuck_tally[a]) > int(ui.sim.stuck_tally[b]))
		for why: String in reasons:
			ui._text(body, "   %dx  %s" % [int(ui.sim.stuck_tally[why]), why])

	ui._heading(body, "QUÉ OFICIO SE MIRA")
	ui._text(body, "Se pinta el camino de todo el que hace ese oficio, uno de "
		+ "cada color. Los rombos marcan los sitios donde pasó algo.", true)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	for job_key: int in GameUI.GRID_JOBS:
		var job := job_key as Profession.Job
		var button := Button.new()
		button.text = String(GameUI.JOB_SHORT.get(job_key, "?"))
		button.custom_minimum_size = Vector2(GameUI.CELL_COL + 8, 22)
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = Profession.job_name(job)
		if ui.trails.showing() == job_key:
			button.add_theme_stylebox_override("normal",
				UISkin.button_box("pressed"))
			button.add_theme_color_override("font_color", UISkin.OCHRE)
		button.pressed.connect(func() -> void:
			ui.trails.show_job(job_key, ui.sim.people, ui.sim.terrain(),
				ui.sim.day)
			show_trails())
		row.add_child(button)

	var off := Button.new()
	off.text = "quitar"
	off.custom_minimum_size = Vector2(52, 22)
	off.add_theme_font_size_override("font_size", 10)
	off.pressed.connect(func() -> void:
		ui.trails.clear()
		show_trails())
	row.add_child(off)

	if ui.trails.showing() < 0:
		ui._text(body, "Ningún rastro pintado.", true)
		return

	var job := ui.trails.showing() as Profession.Job
	ui._heading(body, Profession.job_name(job).to_upper())
	# Por el oficio CON EL QUE SE SALIO, no por el que se tenga hoy. Cuando la
	# despensa llega al tope que puso el jugador, el reparto saca de golpe a
	# toda la recoleccion, y filtrando por el oficio de ahora esta pantalla se
	# quedaba vacia el mismo dia: parecia que se hubieran borrado los rastros.
	var told_someone := false
	for person: Inhabitant in ui.sim.people:
		if not _walked_as(person, job):
			continue
		told_someone = true
		_trail_summary(body, person, job)
	if not told_someone:
		ui._text(body, "Nadie ha salido a esto todavía.", true)


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
	name_label.custom_minimum_size = Vector2(GameUI.NAME_COL, 0)
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
		ui._text(body, "   No ha salido todavía.", true)


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
	what.custom_minimum_size = Vector2(GameUI.NAME_COL + 40, 0)
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
	if ui.sim == null or ui.sim.parajes == null:
		return "(%d, %d)" % [int(point.x), int(point.z)]
	return ui.sim.parajes.place_name(point, ui.sim.home_position)


# -------------------------------------------------------------- técnicas --


func show_territory() -> void:
	var body := ui._window("territorio", "Territorio conocido")
	ui._clear(body)
	if ui.knowledge == null or ui.field == null:
		ui._text(body, "Sin datos del terreno.")
		return

	ui._text(body, "La banda sabe que en el río hay peces y que el ciervo pasta en "
		+ "el llano: eso viene con ella. Lo que aprende aquí es EN QUÉ remanso "
		+ "y EN QUÉ mes.", true)

	# Territorio simplemente VISTO. Es dato distinto de la familiaridad con
	# cada recurso: se puede cruzar un valle entero sin aprender nada de su
	# caza y aun asi conocer el camino.
	var seen := 0
	for value in ui.knowledge.explored:
		if value > 0.01:
			seen += 1
	ui._bar(body, "Valle recorrido", float(seen) / maxf(float(ui.knowledge.explored.size()), 1.0))
	ui._text(body, "Lo que la banda ha llegado a ver, al margen de lo que sepa de "
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
		var catalog := Parajes.materials_on_map(act, ui.field)
		if catalog.is_empty():
			ui._heading(body, Subsistence.activity_name(act))
			ui._text(body, "   No hay nada de esto en este valle.", true)
			continue

		var known_kinds := {}
		if ui.sim and ui.sim.parajes:
			for paraje: Paraje in ui.sim.parajes.list:
				if not paraje.serves(act):
					continue
				for entry: Dictionary in paraje.listing():
					if bool(entry["sabido"]):
						known_kinds[entry["kind"] as Materia.Kind] = true

		var known_count := 0
		for kind: Materia.Kind in catalog:
			if known_kinds.has(kind):
				known_count += 1

		ui._bar(body, Subsistence.activity_name(act), float(known_count) / float(catalog.size()))

		# Lo que hay AHI FUERA, conocido y sin recoger. Es la pregunta que se
		# hace el jugador de verdad: no «cuanto he explorado» sino «que me
		# queda por recoger de lo que ya se donde esta».
		var known_cells := 0
		var stock_left := 0.0
		var best_spot := Vector3.ZERO
		var richest := 0.0
		for z in range(ui.field.height):
			for x in range(ui.field.width):
				var centre := ui.field.cell_center(x, z)
				if ui.knowledge.familiarity_at(act, centre) < BandKnowledge.KNOWN_ENOUGH:
					continue
				if ui.field.abundance_cell(act, x, z) <= 0.05:
					continue
				known_cells += 1
				var fraction := ui.field.stock_fraction(act, x, z)
				stock_left += fraction
				var value := ui.field.seasonal_abundance_at(act, centre, GameState.season)
				if value > richest:
					richest = value
					best_spot = centre

		if known_cells > 0:
			var average := stock_left / float(known_cells)
			ui._text(body, "   %d parajes conocidos, al %d%% de lo que daban intactos"
				% [known_cells, int(average * 100.0)], true)

			# Y QUÉ hay en ellos, por material. Decir «recolección» no dice
			# nada: lo que el jugador quiere saber es si tiene localizado un
			# avellanar o solo leña.
			for line: String in ui._materials_of(act):
				ui._text(body, "      " + line, true)
			if average < 0.45:
				ui._text(body, "   ⚠ Esquilmados: rinden menos de la mitad. Hay que "
					+ "buscar otros o dejarlos reponerse.")
			if ui.sim:
				var distance := Vector2(best_spot.x - ui.sim.home_position.x,
					best_spot.z - ui.sim.home_position.z).length()
				ui._text(body, "   El mejor está a %d m del campamento." % int(distance), true)
		else:
			ui._text(body, "   Sin ningún paraje localizado todavía.", true)

		var seasons: Array[String] = []
		for season in range(4):
			if ui.knowledge.knows_season(act, season as Subsistence.Season):
				seasons.append(Subsistence.season_name(season as Subsistence.Season))
		if seasons.is_empty():
			ui._text(body, "   Sin ninguna temporada vivida todavía.", true)
		else:
			ui._text(body, "   Temporadas conocidas: " + ", ".join(seasons), true)

		var best_season := Subsistence.Season.PRIMAVERA
		var best_value := -1.0
		for season in range(4):
			var value := ResourceField.seasonal_factor(act, season as Subsistence.Season)
			if value > best_value:
				best_value = value
				best_season = season as Subsistence.Season
		if ui.knowledge.knows_season(act, best_season):
			ui._text(body, "   La banda ha visto que lo mejor es %s (×%.2f)." % [
				Subsistence.season_name(best_season), best_value], true)


# --------------------------------------------------------------- crónica --
