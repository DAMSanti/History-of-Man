class_name PanelAlmacen
extends RefCounted
## El almacen y el libro: que hay guardado, que falta y que se ha mandado tener.
##
## Es el trozo mas grande que quedaba de una pieza en [GameUI] -mil catorce
## lineas seguidas- y es un tema cerrado: la tabla de materiales, la de
## utillaje, las fichas de cada cosa y las graficas de su historia.
##
## **La unidad de todo lo que se come es la RACION**, y eso no es un detalle de
## presentacion. Las dos cifras vivian mezcladas y no cuadraban nunca: la
## despensa decia 303 y la columna sumaba 307, porque un panal de miel alimenta
## 1,2 y un puñado de setas 0,06. Con la racion como unica medida, sumar la
## columna da el total de la despensa. Ver el encabezado de [Materia.CATALOGUE],
## que cuenta por que ninguna unidad se llama ya «racion».
var ui: GameUI


func _init(panel: GameUI) -> void:
	ui = panel


## Qué hay guardado, qué falta y qué se ha mandado tener.
##
## Todo va en UNA fila por material: icono, nombre, lo que hay, lo que hace
## falta y el objetivo con sus botones. Antes el control de tope colgaba en
## una segunda línea debajo, y con veinte materiales la pestaña era una
## escalera imposible de leer.
func show_store() -> void:
	var body := ui._window("almacen", "Almacén")
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	var mouths := 0.0
	for person: Inhabitant in ui.sim.people:
		mouths += person.daily_food()

	var days := ui.sim.store.days_of_food(mouths)

	ui._heading(body, _autonomy_text(days))
	ui._text(body, "%d personas comen %.1f raciones al día. Los críos y los "
		% [ui.sim.population(), mouths]
		+ "ancianos comen menos, así que la cuenta no es una por cabeza.", true)

	if days < 3.0:
		ui._notice(body, "Hambre. Con menos de tres jornadas, cualquier temporal "
			+ "deja a la banda sin nada.", UISkin.ALARM)
	elif days < 10.0:
		ui._text(body, "Sin margen: un mal mes acaba con las reservas.", true)

	# --- el sitio ---------------------------------------------------------
	ui._heading(body, "EL ABRIGO")
	ui._bar(body, "Ocupación", ui.sim.store.fullness())
	ui._text(body, "%s de %s · quedan %s libres · pesa %s" % [
		Materia.format_volume(ui.sim.store.total_litres()),
		Materia.format_volume(ui.sim.store.capacity_litres),
		Materia.format_volume(maxf(ui.sim.store.free_litres(), 0.0)),
		Materia.format_weight(ui.sim.store.total_kg())], true)

	if ui.sim.store.fullness() > 0.92:
		ui._notice(body, "El abrigo está lleno. Lo que traigan se queda fuera.",
			UISkin.ALARM)

	_show_camp(body)

	# --- el desglose ------------------------------------------------------
	_food_cap_row(body)

	# En el orden del catálogo y SIEMPRE entero, no ordenado por lo que más
	# abulte. Ordenarlo por volumen quería decir que las filas bailaban cada
	# vez que la banda traía algo: ibas a por la leña donde estaba hace un
	# momento y ahí había otra cosa. Cada material tiene su sitio, y lo
	# conserva aunque hoy no quede nada de él.
	var rows := ui.sim.store.in_catalogue_order()
	var index := 0
	var food_done := false
	ui._heading(body, "ALIMENTO · EN RACIONES")
	_ledger_header(body)
	for row: Dictionary in rows:
		var kind := row["kind"] as Materia.Kind
		if not Materia.is_provision(kind) and not food_done:
			food_done = true
			ui._heading(body, "MATERIA PRIMA · EN UNIDADES")
			_ledger_header(body)
			index = 0
		_material_row(body, kind, float(row["units"]), index)
		index += 1

	_show_toolkit(body)

	ui._heading(body, "CONSERVACIÓN")
	var perishing: Array[String] = []
	for row: Dictionary in rows:
		var kind := row["kind"] as Materia.Kind
		var life := Materia.shelf_life(kind)
		if life <= 0 or life > 200:
			continue
		var aged := float(ui.sim.store.ages.get(kind, 0.0))
		var left := maxi(life - int(aged), 0)
		# Y cuánto se ha ido AYER, que es la cifra que contesta «¿por qué no
		# sube esto?». Un montón que no crece porque se pudre y un montón que
		# no crece porque nadie lo trae se leen igual, y no son lo mismo.
		var lost := float(ui.sim.store.spoiled.get(kind, 0.0))
		var tail := "" if lost < 0.05 else "  ·  ayer se echaron a perder %.1f" % lost
		perishing.append("%s: %d días antes de echarse a perder%s"
			% [Materia.material_name(kind), left, tail])
	if perishing.is_empty():
		ui._text(body, "Nada que se estropee de momento.", true)
	else:
		for line: String in perishing:
			ui._text(body, "  · " + line, true)

	if not ui.sim.camp_built.get(CampProjects.Kind.SECADERO, false):
		ui._notice(body, "Sin secadero, la carne dura cuatro días y el pescado "
			+ "TRES. Ahumarlos los lleva a medio año: mientras no lo levantes, "
			+ "una jornada buena de pesca se pudre antes de comérsela.",
			UISkin.OCHRE)


## No se construye una choza: se EQUIPA la cueva. Hogar y secadero son las
## dos mejoras del abrigo, y el secadero exige el hogar porque ahumar sin
## fuego no se hace.
func _show_camp(body: VBoxContainer) -> void:
	ui._heading(body, "CAMPAMENTO")

	for kind: int in CampProjects.all():
		var project := kind as CampProjects.Kind
		var built: bool = ui.sim.camp_built.get(project, false)
		var working: bool = ui.sim.camp_queue == project

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
			meter.value = clampf(ui.sim.camp_progress, 0.0, meter.max_value)
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
			var blocked: bool = needs >= 0 and not ui.sim.camp_built.get(needs, false)
			var button := Button.new()
			button.text = "levantar" if not blocked else "pide %s" \
				% CampProjects.project_name(needs as CampProjects.Kind).to_lower()
			button.disabled = blocked or ui.sim.camp_queue >= 0
			button.custom_minimum_size = Vector2(84, 22)
			button.pressed.connect(func() -> void:
				ui.sim.queue_project(project)
				show_store())
			row.add_child(button)

		var note := Label.new()
		note.text = CampProjects.project_desc(project)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(GameUI.PANEL_WIDTH - 110, 0)
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", UISkin.INK_FAINT)
		column.add_child(note)

	if ui.sim.camp_queue >= 0:
		var pending: Array[String] = []
		var recipe: Dictionary = CampProjects.materials(
			ui.sim.camp_queue as CampProjects.Kind)
		for material: int in recipe:
			var wanted: float = float(recipe[material])
			var have := ui.sim.store.amount(material as Materia.Kind)
			if have < wanted:
				pending.append("%s (%d de %d)" % [
					Materia.material_name(material as Materia.Kind),
					int(have), int(wanted)])
		if not pending.is_empty():
			ui._notice(body, "Esperando material: %s." % ", ".join(pending), UISkin.OCHRE)
		var hands := 0
		for person: Inhabitant in ui.sim.people:
			if person.job == Profession.Job.HOGAR:
				hands += 1
		if hands == 0:
			ui._notice(body, "No hay nadie en el hogar: la obra no avanza sola.",
				UISkin.ALARM)


## Lo importante del utillaje no es el inventario sino la COBERTURA: doce
## lascas no dicen nada, «doce lascas para siete manos» sí.
func _show_toolkit(body: VBoxContainer) -> void:
	ui._heading(body, "EL UTILLAJE")

	var demand := ui.sim.taller.tool_demand()

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

	# Lo que todavía no se sabe hacer NO SE LISTA. El almacén enseñaba arpones,
	# nasas y anzuelos desde la primera jornada, con su fila, su meta y sus
	# botones, como si fueran cosas que se pueden pedir: y no se podían, porque
	# la técnica no estaba. Aparecen al descubrirlas, que es la mitad del premio
	# de descubrirlas. Lo que ya se tiene se lista igual, se sepa o no: si está
	# en el abrigo, está.
	var known_kinds: Array[int] = []
	for kind: int in kinds:
		if ui.sim.taller.knows_tool(kind as Tool.Kind) \
			or ui.sim.toolkit.count(kind as Tool.Kind) > 0:
			known_kinds.append(kind)
	kinds = known_kinds

	_ledger_header(body)
	var index := 0
	for kind: int in kinds:
		_tool_row(body, kind as Tool.Kind, int(demand.get(kind, 0)), index)
		index += 1

	if not ui.sim.toolkit.broken_today.is_empty():
		ui._text(body, "Hoy se ha roto: %s." % ", ".join(ui.sim.toolkit.broken_today), true)

	ui._text(body, "«Gasta» es lo que la banda consume en un mes: lo que come, lo "
		+ "que rompe y lo que piden las obras. «Meta» es cuánto quieres tener "
		+ "guardado — al llegar, dejan de traer más y se emplean en otra cosa.",
		true)
	ui._text(body, "Las piezas se gastan con el uso. El sílex da casi tres veces "
		+ "más filo que la cuarcita, y ésa es la razón de mandar a alguien "
		+ "lejos a buscarlo.", true)


# ------------------------------------------------------------- el libro ---
#
# Almacén y utillaje comparten rejilla a propósito: son la misma pregunta
# —qué tengo, qué me falta, cuánto quiero— sobre dos cosas distintas, y con
# las columnas alineadas se leen las dos con la misma mirada.


func _ledger_header(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	var widths := [GameUI.COL_ICON + GameUI.COL_NAME + 4, GameUI.COL_HAVE, GameUI.COL_NEED, GameUI.COL_NEED, GameUI.COL_GOAL]
	# Cortos a propósito: «HACE FALTA» no cabe en su columna y se montaba
	# encima de la siguiente
	# GASTA es lo que la banda consume al mes y no lo decide el jugador; META
	# es cuanto quiere tener guardado y lo decide el. Estaban vinculados —los
	# dos salian de lo mismo— y por eso subir uno subia el otro.
	#
	# Las dos del medio van EN EL MISMO PERIODO y con la MISMA regla: la suma
	# de lo que ha entrado y lo que ha salido en los ultimos treinta dias. Ni
	# una proyecta ni la otra pronostica.
	#
	# Las dos lo hacian, cada una a su manera, y las dos engañaban:
	#
	#   GASTA era `material_needed`, o sea «lo que la banda gastaria en un
	#   mes». El dia dos declaraba 762 raciones de comida sin que se hubiera
	#   comido casi nada: proyectaba treinta dias de bocas.
	#
	#   PRODUCE multiplicaba lo recogido por «mes entero / dias jugados». El dia
	#   cinco, veinte de cuarcita salian como 112 al lado de un «HAY 20».
	#
	# Ahora las dos son libros: se apunta lo que pasa y se suma. Al principio de
	# partida las dos salen pequeñas, y eso es lo correcto.
	var texts := ["", "HAY", "GASTADO/30d", "PRODUCE/30d", "META"]
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

	icon.custom_minimum_size = Vector2(GameUI.COL_ICON - 4, GameUI.COL_ICON - 4)
	row.add_child(icon)

	var label := Label.new()
	label.text = name_text
	label.custom_minimum_size = Vector2(GameUI.COL_NAME - 4, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.clip_text = true
	row.add_child(label)

	var have := Label.new()
	row.set_meta("have", have)
	have.text = have_text
	have.custom_minimum_size = Vector2(GameUI.COL_HAVE, 0)
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	have.add_theme_font_size_override("font_size", 12)
	have.add_theme_color_override("font_color", have_tint)
	row.add_child(have)

	var need := Label.new()
	row.set_meta("need", need)
	need.text = need_text
	need.custom_minimum_size = Vector2(GameUI.COL_NEED, 0)
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
	makes.custom_minimum_size = Vector2(GameUI.COL_NEED, 0)
	makes.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	makes.add_theme_font_size_override("font_size", 12)
	makes.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(makes)

	var goal := Label.new()
	goal.text = goal_text
	goal.custom_minimum_size = Vector2(GameUI.COL_GOAL, 0)
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
	var have := ui.sim.store.food_rations()
	var capped := ui.sim.despensa.food_is_capped()

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
	label.custom_minimum_size = Vector2(GameUI.COL_ICON + GameUI.COL_NAME, 0)
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var now := Label.new()
	now.custom_minimum_size = Vector2(GameUI.COL_HAVE, 0)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	now.add_theme_font_size_override("font_size", 12)
	row.add_child(now)
	ui._bind(now, func() -> void:
		var rations := ui.sim.store.food_rations()
		now.text = "%.0f" % rations
		now.add_theme_color_override("font_color",
			UISkin.OCHRE if ui.sim.despensa.food_is_capped() else UISkin.INK))

	var state := Label.new()
	state.custom_minimum_size = Vector2(GameUI.COL_NEED, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state.add_theme_font_size_override("font_size", 10)
	row.add_child(state)
	ui._bind(state, func() -> void:
		state.text = "lleno" if ui.sim.despensa.food_is_capped() else ""
		state.add_theme_color_override("font_color", UISkin.OCHRE))

	var goal := Label.new()
	goal.text = "%.0f" % ui.sim.food_cap if ui.sim.food_cap > 0.0 else "—"
	goal.custom_minimum_size = Vector2(GameUI.COL_GOAL, 0)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal.add_theme_font_size_override("font_size", 12)
	goal.add_theme_color_override("font_color",
		UISkin.OCHRE if ui.sim.food_cap > 0.0 else UISkin.INK_FAINT)
	row.add_child(goal)

	_goal_buttons(row,
		func() -> void:
			var base: float = ui.sim.food_cap if ui.sim.food_cap > 0.0 else have
			ui.sim.food_cap = maxf(base - _goal_step() * 10.0, 0.0)
			ui.sim.apply_priorities()
			show_store(),
		func() -> void:
			var base: float = ui.sim.food_cap if ui.sim.food_cap > 0.0 else have
			ui.sim.food_cap = base + _goal_step() * 10.0
			ui.sim.apply_priorities()
			show_store(),
		func() -> void:
			ui.sim.food_cap = 0.0
			ui.sim.apply_priorities()
			show_store(),
		ui.sim.food_cap > 0.0)

	var days := ui.sim.despensa.food_cap_days()
	frame.tooltip_text = "Tope de comida para toda la despensa.\n\n"
	if ui.sim.food_cap > 0.0:
		frame.tooltip_text += "%.0f raciones: unas %.0f jornadas para la banda entera.\n" % [
			ui.sim.food_cap, days]
	frame.tooltip_text += "Al llegar al tope nadie sale a BUSCAR más comida: " \
		+ "caza, pesca, marisqueo y recolección se quedan sin gente y esa " \
		+ "gente se emplea en otra cosa.\n\n" \
		+ "Lo que ya está empezado sí se termina: el que vuelve cargado " \
		+ "entrega, y una pieza abatida se acaba de traer. Tirar carne para " \
		+ "respetar un tope sería absurdo."

	if capped:
		ui._text(body, "Despensa al tope: nadie sale a buscar más comida. Lo que "
			+ "haya pendiente de recoger sí se recoge.", true)


## La ficha de una pieza de utillaje.
##
## Va aparte de la del material porque las preguntas son distintas: de un
## material interesa cuánto hay y cuánto se gasta; de una pieza interesa
## además con qué se hace, quién la saca y cómo está de filo, que es lo que
## decide si hay que ponerse a tallar hoy o se puede esperar.
func show_tool(kind: Tool.Kind) -> void:
	var body := ui._window("utensilio", Tool.kind_name(kind))
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	ui._heading(body, Tool.kind_name(kind).to_upper())

	var have := ui.sim.toolkit.count(kind)
	var hands := int(ui.sim.taller.tool_natural_demand().get(int(kind), 0))
	ui._text(body, "Hay %d para %d manos · filo medio al %.0f%%" % [
		have, hands, ui.sim.toolkit.condition(kind) * 100.0])

	ui._heading(body, "CÓMO HA IDO")
	var series := ui.sim.tool_history_of(kind)
	if series.size() < 2:
		ui._text(body, "Todavía no hay historia: hace falta cerrar alguna "
			+ "jornada para poder dibujar una curva.", true)
	else:
		body.add_child(_history_chart(series))
		ui._text(body, _history_tale(series), true)
		# Con el utillaje, la pendiente ES la noticia: las piezas no se
		# estropean de golpe, se van rompiendo, y una cuenta que baja despacio
		# avisa con tres semanas de antelación.
		ui._text(body, "Las piezas se rompen con el uso. Si la línea baja y nadie "
			+ "está tallando, la banda se queda sin filo antes de notarlo.",
			true)

	ui._heading(body, "CÓMO SE HACE")
	ui._text(body, _how_and_what_for(kind), true)

	if not ui.sim.toolkit.broken_today.is_empty():
		ui._text(body, "Hoy se ha roto: %s."
			% ", ".join(ui.sim.toolkit.broken_today), true)


## La ficha de un material: qué es, para qué sirve y cómo ha ido.
##
## La cifra de hoy no dice nada sola. «Cuarenta de fruto seco» puede ser una
## despensa que se llena o una que se vacía, y son dos partidas distintas: en
## una no hay que hacer nada y en la otra hay que mandar gente al monte antes
## de que sea tarde. La curva lo dice de un vistazo y el número no.
func show_material(kind: Materia.Kind) -> void:
	var body := ui._window("material", Materia.material_name(kind))
	ui._clear(body)
	if ui.sim == null:
		ui._text(body, "Sin asentamiento.")
		return

	ui._heading(body, Materia.material_name(kind).to_upper())
	ui._text(body, Materia.describe(kind), true)

	var have := ui.sim.store.amount(kind)
	var needed := ui.sim.taller.material_needed(kind)
	ui._text(body, "Ahora hay %.0f · se gastan %.0f al mes · pesa %s y ocupa %s"
		% [have, needed,
			Materia.format_weight(have * Materia.kg_per_unit(kind)),
			Materia.format_volume(have * Materia.litres_per_unit(kind))])

	ui._heading(body, "CÓMO HA IDO")
	var series := ui.sim.history_of(kind)
	if series.size() < 2:
		ui._text(body, "Todavía no hay historia: hace falta cerrar alguna "
			+ "jornada para poder dibujar una curva.", true)
	else:
		body.add_child(_history_chart(series))
		ui._text(body, _history_tale(series), true)

	ui._heading(body, "PARA QUÉ SIRVE")
	ui._text(body, _uses_of(kind), true)

	var life := Materia.shelf_life(kind)
	if life > 0:
		ui._heading(body, "CONSERVACIÓN")
		ui._text(body, "Aguanta unas %d jornadas antes de echarse a perder." % life,
			true)


## La curva de existencias, dibujada a mano.
##
## Es un Control con `draw` propio y no una imagen: son treinta líneas, y
## montar una textura para eso sería pagar memoria y un rebote por el disco
## para dibujar lo que el propio panel puede pintar.
func _history_chart(series: PackedFloat32Array) -> Control:
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(GameUI.PANEL_WIDTH - 60, 110)

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
		# Con la UNIDAD por delante y la racion explicada detras. Decia «0,5
		# raciones por unidad» de una carne cuya unidad se llamaba «ración»,
		# que no hay quien lo cuadre -ver el encabezado de [Materia.CATALOGUE]-
		# y ademas no decia contra que se compara: las columnas del almacen van
		# en raciones y una persona come dos al dia.
		lines.append("Se come: 1 %s da %.2f raciones (%.0f kcal)."
			% [Materia.unit_name(kind), Materia.nutrition(kind),
				Materia.kcal(kind)])
		lines.append("Una persona come %.0f raciones al día, y el almacén "
			% (Materia.KCAL_DIA / Materia.KCAL_RACION)
			+ "cuenta en raciones, no en bultos.")
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
		var got := ui.tech != null and ui.tech.has(needed_tech as TechTree.Tech)
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
	for activity: int in GameUI.ALL_ACTIVITIES:
		if ui.sim.taller.activity_tool(activity as Subsistence.Activity) == int(kind):
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
		button.custom_minimum_size = Vector2(GameUI.COL_BUTTON, 20)
		button.pressed.connect(entry[1] as Callable)
		row.add_child(button)

	var clear := Button.new()
	clear.text = "∞"
	clear.tooltip_text = "Sin objetivo: que lo decida la banda"
	clear.custom_minimum_size = Vector2(GameUI.COL_BUTTON, 20)
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


## Lo que entra en el periodo de consumo, dicho para que se lea.
##
## Con un decimal por debajo de diez: aun por mes hay materiales que entran a
## medio y a cuarto, y redondeando a entero esas filas salian a cero y parecia
## que la banda no producia nada de ellas.
func _makes_text(per_period: float) -> String:
	if per_period <= 0.005:
		return "—"
	if per_period < 10.0:
		return "%.1f" % per_period
	return "%.0f" % per_period


## Cuántas raciones da una unidad de esto. Lo que no se come va en unidades
## -una piel es una piel- y se queda a 1.
func _ration_rate(kind: Materia.Kind) -> float:
	if not Materia.is_food(kind):
		return 1.0
	return maxf(Materia.nutrition(kind), 0.01)


func _material_row(body: VBoxContainer, kind: Materia.Kind,
		units: float, index: int) -> void:
	var needed := ui.sim.taller.material_needed(kind)
	var has_goal: bool = ui.sim.limits.has(kind)
	var goal: float = float(ui.sim.limits.get(kind, 0.0))

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

	var makes := ui.sim.taller.production_of(kind) * rate
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
	ui._bind(have_label, func() -> void:
		var now := ui.sim.store.amount(kind)
		var want := ui.sim.taller.material_needed(kind)
		var tint := UISkin.INK
		if want > 0.0:
			tint = UISkin.coverage_color(now / maxf(want, 0.001))
		elif ui.sim.limits.has(kind) and now >= float(ui.sim.limits[kind]):
			tint = UISkin.GREEN
		have_label.text = "%.0f" % (now * rate)
		have_label.add_theme_color_override("font_color", tint))

	var need_label: Label = row.get_meta("need")
	ui._bind(need_label, func() -> void:
		var want := ui.sim.taller.material_needed(kind)
		need_label.text = "%.0f" % (want * rate) if want > 0.0 else "—")

	var makes_label: Label = row.get_meta("makes")
	ui._bind(makes_label, func() -> void:
		makes_label.text = _makes_text(ui.sim.taller.production_of(kind) * rate))

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
			ui.sim.limits[kind] = maxf(base - _goal_step() / rate, 0.0)
			show_store(),
		func() -> void:
			var base: float = goal if has_goal else units
			ui.sim.limits[kind] = base + _goal_step() / rate
			show_store(),
		func() -> void:
			ui.sim.limits.erase(kind)
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
	var have := ui.sim.toolkit.count(kind)
	var has_order: bool = ui.sim.taller.tool_orders.has(kind)
	var order: int = int(ui.sim.taller.tool_orders.get(kind, 0))

	# GASTA es cuantas se rompen al mes, no cuantas quieres tener: si fuera lo
	# segundo, subir la meta subiria el gasto y el numero no diria nada.
	var broken := ui.sim.taller.tools_broken_per_month(kind)
	var have_tint := UISkin.coverage_color(
		float(have) / maxf(float(needed), 0.001)) if needed > 0 else UISkin.INK

	var row := _ledger_row(body, MateriaIcon.for_tool(kind),
		Tool.kind_name(kind),
		"%d" % have, have_tint,
		"%.1f" % broken if broken < 10.0 else "%.0f" % broken,
		"%d" % order if has_order else "—",
		UISkin.OCHRE if has_order else UISkin.INK_FAINT, index,
		_makes_text(ui.sim.taller.tool_production_of(kind)))

	_goal_buttons(row,
		func() -> void:
			var base := order if has_order else needed
			ui.sim.taller.set_tool_order(kind, maxi(base - int(_goal_step()), 0))
			show_store(),
		func() -> void:
			var base := order if has_order else needed
			ui.sim.taller.set_tool_order(kind, base + int(_goal_step()))
			show_store(),
		func() -> void:
			ui.sim.taller.set_tool_order(kind, 0)
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

	var condition := ui.sim.toolkit.condition(kind)
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
