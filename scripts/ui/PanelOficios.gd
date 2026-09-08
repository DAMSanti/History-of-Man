class_name PanelOficios
extends RefCounted
## Los oficios que hay y las tecnicas que se pueden aprender.
##
## Sale de [GameUI] y son DOS ventanas que van juntas porque son la misma
## pregunta: que sabe hacer la banda.
##
## OFICIOS es el mapa -que oficios existen, en que especialidades se abre cada
## uno, que hace falta para cada una y quien la ejerce hoy-, y no hay que
## confundirlo con «Trabajos», que es la mesa de mando: cuanta gente en que,
## con sus prioridades. Sin esta ventana, la unica forma de saber que la pesca
## de altura existe y pide embarcacion era leer el codigo.
##
## TECNICAS es el arbol, dibujado como un arbol de verdad -ver [TechGraph]-,
## con una pestana por profesion. En el Paleolitico nadie investiga: se aprende
## haciendo, asi que lo que abre una tecnica son jornadas de oficio y material,
## no un boton.
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


## El árbol de oficios: qué sabe hacer la banda y en qué se puede repartir.
##
## Va aparte de «Trabajos» y no es lo mismo. Aquélla es la mesa de mando —cuánta
## gente en qué, con sus prioridades— y ésta es el mapa: qué oficios hay, en qué
## especialidades se abre cada uno, qué hace falta para cada especialidad y
## quién la ejerce hoy. Sin esto, la única forma de saber que la pesca de altura
## existe y pide embarcación era leer el código.
func show_professions() -> void:
	var body := ui._window("oficios", "Oficios")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	ui._text(body, "Un oficio es cómo se organiza la banda; una especialidad es "
		+ "qué parte del monte se toca. Casi nadie vive de un solo trabajo: en "
		+ "una banda de quince, la especialización es la recompensa de haber "
		+ "crecido.", true)

	var counts := _job_headcount()
	for job: int in Profession.Job.values():
		if job == Profession.Job.OCIOSO:
			continue
		body.add_child(HSeparator.new())
		var here: int = counts.get(job, 0)
		ui._heading(body, "%s · %d %s" % [
			Profession.job_name(job as Profession.Job).to_upper(), here,
			"persona" if here == 1 else "personas"])
		ui._text(body, Profession.job_desc(job as Profession.Job), true)
		ui._text(body, "   pueden: %s" % _who_can(job as Profession.Job), true)

		var specialities := Profession.specialities_of(job as Profession.Job)
		if specialities.is_empty():
			ui._text(body, "   no se reparte en especialidades", true)
			continue
		for speciality: int in specialities:
			_speciality_line(body, job as Profession.Job,
				speciality as Profession.Speciality)


## Cuánta gente hay hoy en cada oficio.
func _job_headcount() -> Dictionary:
	var counts: Dictionary = {}
	for person: Inhabitant in ui.sim.people:
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
	for person: Inhabitant in ui.sim.people:
		if Profession.can_do(job, person):
			able += 1
	parts.append("%d de los %d de la banda" % [able, ui.sim.people.size()])
	return " · ".join(parts)


## Una especialidad: qué es, qué le hace falta y quién la ejerce hoy.
func _speciality_line(body: VBoxContainer, job: Profession.Job,
		speciality: Profession.Speciality) -> void:
	var doing: Array[String] = []
	for person: Inhabitant in ui.sim.people:
		if person.job == job and person.current_speciality == speciality:
			doing.append(person.given_name)

	var blocked := _speciality_blocked(speciality)
	var mark := "·" if not blocked.is_empty() else ("◆" if not doing.is_empty() else "▸")
	ui._text(body, "   %s %s" % [mark,
		Profession.speciality_name(speciality)], blocked.is_empty() == false)
	ui._text(body, "       %s" % Profession.speciality_desc(speciality), true)
	if not blocked.is_empty():
		ui._text(body, "       falta: %s" % blocked, true)
	elif not doing.is_empty():
		ui._text(body, "       hoy: %s" % ", ".join(doing), true)


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
	var body := ui._window("tecnicas", "Técnicas")
	ui._clear(body)
	if ui.tech == null:
		ui._text(body, "Sin datos de técnica.")
		return

	ui._text(body, "En el Paleolítico nadie investiga: se aprende haciendo. Cada "
		+ "técnica sale de acumular jornadas en la actividad que la produce, y "
		+ "de gastar material aprendiendo: se estropean nódulos aprendiendo a "
		+ "tallarlos. Pon el ratón encima de una para ver qué pide.", true)
	ui._text(body, "verde: dominada    ocre: las jornadas están, falta el "
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
	graph.build(ui.tech, _tech_tab)
	# Más doce de la barra de desplazamiento horizontal, que si no tapa la
	# fila de abajo.
	scroll.custom_minimum_size = Vector2(0, graph.custom_minimum_size.y + 12.0)

	body.add_child(HSeparator.new())
	ui._heading(body, "EL HOGAR")
	ui._text(body, "No son técnicas que se aprendan: son obras que se levantan en "
		+ "el abrigo, con su material y sus jornadas.", true)
	for kind: int in CampProjects.all():
		_camp_row(body, kind as CampProjects.Kind)

	body.add_child(HSeparator.new())
	_fishing_block(body)
	_hunting_block(body)
	_paintings_block(body)


## Una obra del abrigo: qué es, qué cuesta y en qué punto está.
func _camp_row(body: VBoxContainer, kind: CampProjects.Kind) -> void:
	if ui.sim == null:
		return
	var name_text := CampProjects.project_name(kind)
	if ui.sim.camp_built.get(kind, false):
		var state := ""
		if kind == CampProjects.Kind.HOGAR:
			state = " · encendido" if ui.sim.hearth_lit else " · APAGADO"
		ui._text(body, "◆ %s%s" % [name_text, state])
		return

	var needs := CampProjects.requires(kind)
	if needs >= 0 and not ui.sim.camp_built.get(needs, false):
		ui._text(body, "· %s — falta %s" % [name_text,
			CampProjects.project_name(needs as CampProjects.Kind).to_lower()], true)
		return

	if ui.sim.camp_queue == kind:
		ui._bar(body, "▸ %s" % name_text,
			ui.sim.camp_progress / maxf(CampProjects.labor_days(kind), 0.01))
	else:
		ui._text(body, "▸ %s" % name_text)
	ui._text(body, "     %s" % CampProjects.project_desc(kind), true)
	ui._text(body, "     %s · %.0f jornadas de hogar" % [
		_materials_line(CampProjects.materials(kind)),
		CampProjects.labor_days(kind)], true)


## Lo que pide una receta, con lo que hay al lado.
##
## «6 piedra, 3 leña» no dice si se puede hacer o no; «6 piedra (hay 14), 3 leña
## (hay 1)» sí, y de un vistazo. Es la mitad de lo que había que adivinar.
func _materials_line(recipe: Dictionary) -> String:
	if ui.sim == null or recipe.is_empty():
		return "sin material"
	var parts: Array[String] = []
	for material: int in recipe:
		var wanted := float(recipe[material])
		var have := ui.sim.store.amount(material as Materia.Kind)
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
	if ui.sim == null:
		return
	ui._heading(body, "CAZA")

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
				ui.sim.trampas.traps.size(), ui.sim.trampas.trap_allowance()]
		else:
			var known := Hunting.known_improvements(speciality, ui.sim.techs)
			note.text = "%.1f piezas por jornada%s" % [
				Hunting.pieces_per_day(speciality, ui.sim.techs),
				"" if known.is_empty() else "  ·  con " + ", ".join(known).to_lower()]
		row.add_child(note)

		var pending := Hunting.next_improvement(speciality, ui.sim.techs)
		if pending >= 0:
			ui._text(body, "   falta %s: ×%.2f"
				% [TechTree.tech_name(pending as TechTree.Tech).to_lower(),
					_improvement_factor(speciality, pending)], true)

		# Y lo que anda por el coto y NO se puede cobrar por falta de arma. Es
		# la otra mitad de la puerta de [Fauna.huntable_with]: cerrarla en
		# silencio deja al jugador con una cuadrilla que vuelve de vacío de un
		# cotarro lleno de ciervos y ninguna forma de saber por qué.
		if speciality != Profession.Speciality.TRAMPAS:
			var coto := ui.sim.parajes.chosen_for(Subsistence.Activity.CAZA)
			var donde := coto.position if coto != null else ui.sim.home_position
			var escapa := Hunting.out_of_reach_text(speciality, donde,
				GameState.season as Subsistence.Season, ui.sim.toolkit)
			if not escapa.is_empty():
				ui._text(body, "   %s" % escapa, true)

	# Y la línea de trampas, una por una. Es lo único que la banda deja
	# PLANTADO en el mapa, así que merece una lista y no un número.
	if ui.sim.trampas.traps.is_empty():
		ui._text(body, "Sin una sola trampa puesta. Pon a alguien en trampas: "
			+ "es el único trabajo que rinde mientras la banda hace otra cosa.",
			true)
	else:
		for trap: Trap in ui.sim.trampas.traps:
			var ready := trap.soaking >= Trap.days_per_catch(trap.kind)
			ui._text(body, "   %s %s en %s — %.0f%% de vida, %d piezas%s" % [
				"◆" if ready else "·",
				Trap.trap_name(trap.kind),
				ui.sim.parajes.place_name(trap.position, ui.sim.home_position),
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
	if ui.sim == null:
		return
	ui._heading(body, "PESCA DE ORILLA")

	var actual := ui.sim.fishing_method() as Fishing.Method
	for method_key: int in Fishing.ORDER:
		var method := method_key as Fishing.Method
		var why := Fishing.blocked_by(method, ui.sim.techs, ui.sim.toolkit, ui.sim.store,
			ui.sim.taller.workers_in(Subsistence.Activity.PESCA))
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

	ui._text(body, "Se pesca siempre con lo mejor que se pueda HOY. Si se rompe "
		+ "el último arpón o se acaba el cebo, se baja un escalón hasta que "
		+ "el taller reponga.", true)

	# Y la línea de nasas, una por una, igual que la de trampas: es lo otro que
	# la banda deja plantado en el mapa.
	if ui.sim.techs != null and ui.sim.techs.has(TechTree.Tech.NASA):
		if ui.sim.nasas_line.nasas.is_empty():
			ui._text(body, "Sin una sola nasa calada. El pescador las revisa por "
				+ "la mañana y luego pesca: no le quita la jornada.", true)
		else:
			for nasa: Nasa in ui.sim.nasas_line.nasas:
				ui._text(body, "   %s Nasa en %s — %.0f%% de vida, %d piezas  ·  %s"
					% ["◆" if nasa.has_catch() else "·",
						ui.sim.parajes.place_name(nasa.position, ui.sim.home_position),
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
	if ui.sim == null:
		return
	if ui.sim.techs == null or not ui.sim.techs.has(TechTree.Tech.ARTE):
		return
	ui._heading(body, "LA PARED DEL FONDO")

	if ui.sim.painting_queue != null:
		ui._text(body, "Pintando: %s (%.0f%%)" % [ui.sim.painting_queue.title,
			100.0 * ui.sim.painting_progress / SettlementSim.PINTURA_JORNADAS])

	if ui.sim.paintings.is_empty():
		var falta := ui.sim.pinturas.painting_blocked_by()
		ui._text(body, "La pared está limpia. " + ("Lo que se cuenta dura lo que "
			+ "dure quien lo cuente." if falta.is_empty()
			else "Para pintar: %s." % falta), true)
	else:
		for tale: Tale in ui.sim.paintings:
			ui._text(body, "   · %s — %s" % [tale.title, tale.stamp()])
		ui._text(body, "Lo que está en la pared se aprende aunque no quede nadie "
			+ "que estuviera allí.", true)
	body.add_child(HSeparator.new())
