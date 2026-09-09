class_name PanelTrabajos
extends RefCounted
## La ventana de Trabajos: quien hace que, y por que no puede hacer lo otro.
##
## Sale de [GameUI] porque era su trozo mas grande y el mas cerrado: setecientas
## lineas que solo hablan de la rejilla de reparto y de la ficha corta de cada
## persona. Nada de aqui lo llama otra ventana; lo unico que cruza es la ficha
## larga -`ui.show_person`-, que se abre al pinchar una fila.
##
## Guarda el panel en vez de heredar de el a proposito: la ventana, el tema y
## las ayudas de dibujo -`_window`, `_text`, `_bind`- son del panel, y lo que
## hay aqui es lo que se pinta dentro.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


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
	var body := ui._window("trabajos", "Trabajos", ui.JOBS_WIDTH)
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	ui._heading(body, "")
	var tally: Label = body.get_child(body.get_child_count() - 1)
	ui._bind(tally, func() -> void:
		tally.text = "%d personas · %d sin oficio" % [
			ui.sim.population(), ui.sim.idle_count()])
	_legend(body)

	_job_grid(body)

	ui._text(body, "Cada cual hace lo que tiene MÁS ARRIBA de lo que puede. Si "
		+ "alguien lleva recolección en 1 y exploración en 2, recolecta: para "
		+ "que salga a explorar, súbele la exploración o bájale la otra.", true)
	ui._text(body, "Dentro de un oficio, todas las especialidades al mismo nivel "
		+ "es «lo que haga falta»: cada jornada se hace la que más falta haga. "
		+ "Bajar una y subir otra es lo que convierte a alguien en artesano.",
		true)

	ui._heading(body, "CÓMO FUNCIONA")
	ui._text(body, "Nadie «es» cazador: la banda reparte el trabajo cada mañana "
		+ "según lo que cada cual esté dispuesto a hacer. Por eso un crío que "
		+ "crece o alguien que deja de criar entran solos en los trabajos que "
		+ "ya tenían marcados.", true)
	ui._text(body, "El hogar es el único con mínimo: si nadie lo atiende, la banda "
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

	ui._text(body, "Una fila por persona y una casilla por tarea. Pincha para "
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
	for job_key: int in GameUI.GRID_JOBS:
		var job := job_key as Profession.Job
		var specialities := Profession.specialities_of(job)
		if specialities.is_empty():
			continue

		var parts: Array[String] = []
		for speciality: int in specialities:
			parts.append("%s %s" % [
				String(GameUI.SPECIALITY_SHORT.get(speciality, "?")),
				Profession.speciality_name(speciality as Profession.Speciality)])

		var label := Label.new()
		label.text = "%s:  %s" % [Profession.job_name(job), "   ".join(parts)]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", UISkin.FLINT)
		body.add_child(label)


## Reparto de la mano de obra: una fila por persona, doce columnas de tarea.
func _job_grid(body: VBoxContainer) -> void:
	_job_head(body)

	# Los críos no salen hasta que puedan hacer ALGO. Un renglón con las
	# diecisiete casillas cerradas no es información: es una fila que no se
	# puede tocar ocupando sitio, y con tres o cuatro niños en la banda la
	# tabla se llena de gente a la que no se le puede mandar nada.
	var index := 0
	var hidden := 0
	for person: Inhabitant in ui.sim.people:
		if not _can_work_at_all(person):
			hidden += 1
			continue
		_person_row(body, person, index)
		index += 1

	if hidden > 0:
		ui._text(body, "%d %s todavía demasiado pequeño%s para ningún oficio. %s en "
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
	for job_key: int in GameUI.GRID_JOBS:
		var job := job_key as Profession.Job
		var tasks := Profession.tasks_of(job)
		var width := _group_width(tasks.size())
		var full := Profession.job_name(job)

		var label := Label.new()
		# El nombre entero si cabe en el grupo, y la forma corta si no —que la
		# leyenda de arriba traduce—. Recortar «Recolección» a «Recolec…» no le
		# sirve a nadie.
		label.text = full if full.length() * 7 <= width \
			else String(GameUI.JOB_SHORT.get(job_key, "?"))
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
	for job_key: int in GameUI.GRID_JOBS:
		var job := job_key as Profession.Job
		var group := _grid_group(spec_row)
		for task: int in Profession.tasks_of(job):
			var speciality := Profession.task_speciality(task)
			var label := Label.new()
			label.text = String(GameUI.SPECIALITY_SHORT.get(speciality, "·")) \
				if speciality != Profession.Speciality.NINGUNA else "·"
			label.custom_minimum_size = Vector2(GameUI.CELL_COL, 0)
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
	row.add_theme_constant_override("separation", GameUI.GROUP_GAP)
	frame.add_child(row)

	var name_label := Label.new()
	name_label.text = person.given_name
	name_label.custom_minimum_size = Vector2(GameUI.NAME_COL, 0)
	name_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.clip_text = true
	name_label.tooltip_text = _skills_text(person)
	row.add_child(name_label)
	# En ocre mientras trabaje, apagado al quedarse ocioso. Va atado para que
	# cambie solo, sin reconstruir la tabla entera.
	ui._bind(name_label, func() -> void:
		name_label.add_theme_color_override("font_color",
			UISkin.INK if person.job == Profession.Job.OCIOSO else UISkin.OCHRE))

	for job_key: int in GameUI.GRID_JOBS:
		var job := job_key as Profession.Job
		var group := _grid_group(row)
		var able := Profession.can_do(job, person)
		for task: int in Profession.tasks_of(job):
			group.add_child(_task_cell(person, task, able))

	# Qué hace HOY. Es la columna que cambia sola: la banda reparte cada
	# mañana, y sin esto había que cerrar y abrir el panel para enterarse.
	var today := Label.new()
	today.custom_minimum_size = Vector2(GameUI.TODAY_COL, 0)
	today.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	today.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	today.add_theme_font_size_override("font_size", 10)
	row.add_child(today)
	ui._bind(today, func() -> void:
		if person.job == Profession.Job.OCIOSO:
			today.text = "—"
			today.add_theme_color_override("font_color", UISkin.INK_FAINT)
			today.tooltip_text = "Sin oficio: no tiene marcado nada que pueda hacer."
			return
		var speciality := person.current_speciality as Profession.Speciality
		today.text = String(GameUI.SPECIALITY_SHORT.get(speciality, "")) \
			if speciality != Profession.Speciality.NINGUNA \
			else String(GameUI.JOB_SHORT.get(person.job, "?"))
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
	ui._bind(why, func() -> void:
		why.text = _demotion_text(person))


## Por que esta persona no esta haciendo lo que tiene marcado mas arriba.
## Cadena vacia si SI lo esta haciendo, que es lo normal.
func _demotion_text(person: Inhabitant) -> String:
	if ui.sim == null:
		return ""
	var wanted := ui.sim.top_choice(person)
	if wanted < 0:
		return ""
	var doing := Profession.task_id(person.job as Profession.Job,
		person.current_speciality as Profession.Speciality)
	if doing == wanted:
		return ""
	var reason := ui.sim.task_blocked_by(person, wanted)
	if reason.is_empty():
		# Empate: hay otra tarea al mismo nivel y hoy hacia mas falta. Eso no
		# es que se le ignore, es lo que significa poner dos cosas iguales.
		if person.priority_for(doing) == person.priority_for(wanted):
			return ""
		return ""
	return "%s: %s" % [String(GameUI.SPECIALITY_SHORT.get(
		Profession.task_speciality(wanted), GameUI.JOB_SHORT.get(
			Profession.task_job(wanted), "?"))), reason]


## Una fila de la rejilla con el hueco del nombre ya puesto, para que las
## cabeceras caigan exactamente encima de las casillas.
func _grid_row(body: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameUI.GROUP_GAP)
	body.add_child(row)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(GameUI.NAME_COL, 0)
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(spacer)
	return row


## El grupo de casillas de un oficio dentro de una fila.
func _grid_group(row: HBoxContainer) -> HBoxContainer:
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", GameUI.CELL_GAP)
	group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(group)
	return group


## La columna de la derecha, la de «hoy».
func _grid_tail(row: HBoxContainer, text: String, tint: Color) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(GameUI.TODAY_COL, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", tint)
	row.add_child(label)


## Lo que ocupa el grupo de un oficio: sus casillas más los huecos de dentro.
func _group_width(cells: int) -> int:
	return cells * GameUI.CELL_COL + (cells - 1) * GameUI.CELL_GAP


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
		blocked.custom_minimum_size = Vector2(GameUI.CELL_COL, 22)
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
	button.custom_minimum_size = Vector2(GameUI.CELL_COL, 22)
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
		ui.sim.apply_priorities()
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
	for person: Inhabitant in ui.sim.people:
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
	# Se recorre LO QUE HA APRENDIDO, no la lista de actividades.
	#
	# Es el mismo fallo que tenia la fila de la banda: `skill` esta indexado
	# por TAREA -ver [Inhabitant.current_task]- y aqui se preguntaba por
	# ACTIVIDAD, asi que ninguna acertaba y todas devolvian el 0,5 por
	# defecto. Con el corte en 0,505 eso queria decir que el cuadro salia
	# SIEMPRE VACIO: «todavia nada» a un cazador con veinte temporadas.
	var lines: Array[String] = [person.given_name + " sabe hacer:"]
	var filas: Array[Dictionary] = []
	for task: int in person.skill:
		var value := float(person.skill[task])
		if value <= 0.01:
			continue
		filas.append({"tarea": task, "pericia": value})
	filas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["pericia"]) > float(b["pericia"]))
	for fila: Dictionary in filas:
		lines.append("  %s · %s (%d%%)" % [
			Profession.task_name(int(fila["tarea"])),
			person.skill_label(float(fila["pericia"])),
			int(float(fila["pericia"]) * 100.0)])
	if filas.is_empty():
		lines.append("  Todavía nada: es lo que se aprende trabajando.")
	return "\n".join(lines)


## Lo que hay que saber para repartirle trabajo: qué hace hoy y qué se le da
## bien.
func _person_note(person: Inhabitant) -> String:
	# Por TAREA, igual que `_skills_text`: preguntando por actividad no
	# acertaba ninguna y nadie tenia nunca un «se le da bien».
	var best_name := ""
	var best_value := 0.55
	for task: int in person.skill:
		var value := float(person.skill[task])
		if value > best_value:
			best_value = value
			best_name = Profession.task_name(task)

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
	if ui.sim == null:
		return []

	var person_days := ui.sim.remaining_person_days(activity)
	if person_days <= 0.0:
		return []

	var lines: Array[String] = []
	var yields: Dictionary = ui.sim.tajo._yield_materials(activity)
	for kind: int in yields.keys():
		var k := kind as Materia.Kind
		var left := ui.sim.remaining_units(activity, k)
		if left < 0.5:
			continue

		# Del abrigo solo se dice si va bien o va justo: el detalle esta en su
		# propia pestana, y aqui estorbaria
		var stored := ui.sim.store.amount(k)
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
	for person: Inhabitant in ui.sim.people:
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
	if ui.sim == null:
		return

	var current := Profession.Speciality.NINGUNA
	for person: Inhabitant in ui.sim.people:
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
			ui.sim.set_speciality(job, speciality as Profession.Speciality)
			show_jobs())
		row.add_child(button)

	# Y qué está haciendo cada cual AHORA, que con rotación no es lo mismo que
	# lo que se ha pedido
	if current == Profession.Speciality.NINGUNA:
		var counts: Dictionary = ui.sim.speciality_counts(job)
		var parts: Array[String] = []
		for speciality: int in counts.keys():
			parts.append("%d en %s" % [counts[speciality],
				Profession.speciality_name(speciality as Profession.Speciality).to_lower()])
		if not parts.is_empty():
			ui._text(body, "   hoy: " + ", ".join(parts), true)

	_who_goes(body, job)


## Quiénes van, por su nombre, en los oficios que salen del abrigo.
##
## «Asignar 2 a expedición» es una cifra, y una cifra no se pierde. Lo que se
## pierde en un percance es Jara, de cuarenta y un años. El dato estaba desde
## siempre en `Inhabitant`; lo que faltaba era enseñarlo donde se decide. Sólo
## en exploración y caza: son los dos oficios de los que se puede no volver.
func _who_goes(body: VBoxContainer, job: Profession.Job) -> void:
	if job != Profession.Job.EXPLORACION and job != Profession.Job.CAZA:
		return
	var going: Array[Inhabitant] = []
	for person: Inhabitant in ui.sim.people:
		if person.job == job:
			going.append(person)
	if going.is_empty():
		ui._text(body, "   no sale nadie", true)
		return
	for person: Inhabitant in going:
		var line := "   %s — %s" % [
			Profession.speciality_name(
				person.current_speciality as Profession.Speciality).to_lower(),
			ui.barra._person_card_line(person)]
		ui._text(body, line, person.hurt_days <= 0)
func show_band() -> void:
	var body := ui._window("banda", "La banda")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	ui._heading(body, "%d personas · %s (%s) del año %d" % [
		ui.sim.population(), Subsistence.season_name(GameState.season),
		Subsistence.month_name(GameState.season, ui.sim.season_day), GameState.year])
	ui._text(body, "Reservas: %.1f raciones" % ui.sim.store.food_rations(), true)
	body.add_child(HSeparator.new())

	# Agrupadas por OFICIO, no por actividad. Por actividad se perdía media
	# banda: quien no tiene oficio -los críos que aún no llegan a la edad de
	# nada, y quien está en el hogar- lleva actividad -1, y `activity_name`
	# no tiene nombre para el -1: los metía a todos bajo «Materia prima»,
	# revueltos con los canteros de verdad. Beru y Caro estaban ahí, no
	# desaparecidos. Por oficio cada uno cae donde le toca y los que no
	# tienen ninguno salen juntos y con su nombre.
	var by_job: Dictionary = {}
	for person: Inhabitant in ui.sim.people:
		var list: Array = by_job.get(person.job, [])
		list.append(person)
		by_job[person.job] = list

	for job: int in by_job.keys():
		var list: Array = by_job[job]
		ui._heading(body, "%s — %d" % [
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
	# una fraccion, y va POR TAREA, no por actividad.
	#
	# Se leia `person.skill.get(person.activity, 0.5)` y ahi estaba el fallo:
	# `skill` esta indexado por TAREA -ver [Inhabitant.current_task]- asi que la
	# busqueda no acertaba nunca y devolvia el valor por defecto. Resultado:
	# TODA la banda con «pericia 50 %», siempre, sin moverse jamas. No es que no
	# subiera: es que no se estaba mirando.
	#
	# Y se dice en que, ademas del numero: «pericia 62 %» sin decir en que no
	# significa nada cuando la misma persona talla, recolecta y cuida el fuego.
	#
	# Y quien no tiene oficio no tiene pericia QUE ENSEÑAR. Salia «medianero en
	# sin oficio (50 %)», que es el 0,5 por defecto de `skill_in` cuando la
	# tarea no esta en la tabla: un numero inventado con pinta de dato. Se dice
	# que no tiene oficio y se calla la cifra.
	var nota := " · criando" if person.nursing else ""
	var tarea := person.current_task()
	var pericia := person.skill_in(tarea)
	var lo_que_sabe := "sin oficio: no ha aprendido nada todavía"
	if person.job != Profession.Job.OCIOSO:
		lo_que_sabe = "%s en %s (%d %%)" % [person.skill_label(pericia),
			Profession.task_name(tarea).to_lower(), int(pericia * 100.0)]
	var label := Label.new()
	label.text = "  %s (%s %s, %d)%s · %s · hambre %d · fatiga %d · %s" % [
		person.given_name,
		"mujer" if person.sex == Inhabitant.Sex.MUJER else "hombre",
		person.age_name(), person.age_years, nota,
		person.state_name(), int(person.hunger), int(person.fatigue),
		lo_que_sabe]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(
		maxf(body.custom_minimum_size.x - 45.0, 200.0), 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UISkin.INK_SOFT)
	frame.add_child(label)

	frame.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			ui.show_person(person))
	frame.tooltip_text = "Pincha para ver su ficha."
