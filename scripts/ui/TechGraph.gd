class_name TechGraph
extends Control
## El árbol de técnicas de un oficio, dibujado como un árbol.
##
## Era una lista sangrada con puntitos: «· Arpón — falta red». Se leía el
## nombre y el estado, pero no lo único que un árbol tiene que contestar de un
## vistazo —de qué cuelga qué, y por dónde se sigue— porque una sangría de
## cuatro espacios no dice de CUÁL de las tres de arriba cuelga.
##
## Aquí cada técnica es una casilla con su dibujo, colocada en la columna de su
## profundidad, y las flechas se trazan de la que hace falta a la que se abre.
## Encima de cada una, el detalle completo en el aviso emergente: qué es, qué
## jornadas lleva, qué material pide y qué falta.

## Tamaño de cada casilla y hueco entre ellas.
const NODE := Vector2(132.0, 46.0)
const GAP := Vector2(38.0, 14.0)

## Grosor y cabeza de las flechas.
const ARROW_WIDTH := 1.6
const ARROW_HEAD := 7.0

var _tech: TechTree
var _techs: Array[int] = []
var _at: Dictionary = {}


## Monta el árbol de un oficio. `tree` es el estado de la banda.
func build(tree: TechTree, job: int) -> void:
	_tech = tree
	_techs.clear()
	_at.clear()
	for child: Node in get_children():
		child.queue_free()

	var branch: Array = TechTree.BRANCHES.get(job, [])
	if branch.is_empty():
		custom_minimum_size = Vector2(0.0, 0.0)
		return

	# Cada técnica va en la columna de su profundidad y en la primera fila
	# libre de esa columna. La profundidad sale de los prerrequisitos —ver
	# `TechTree.depth_of`—, así que la forma del dibujo la dan los datos y no
	# una tabla de posiciones que se desincroniza al añadir una técnica.
	var rows: Dictionary = {}
	var deepest := 0
	# En el orden del catálogo, que es el orden en que se piensan.
	for entry: int in branch:
		var tech := entry as TechTree.Tech
		var column := _depth_in(tech, branch)
		var row: int = int(rows.get(column, 0))
		rows[column] = row + 1
		_at[tech] = Vector2(
			float(column) * (NODE.x + GAP.x),
			float(row) * (NODE.y + GAP.y))
		_techs.append(entry)
		deepest = maxi(deepest, column)

	var tallest := 0
	for column: int in rows:
		tallest = maxi(tallest, int(rows[column]))
	custom_minimum_size = Vector2(
		float(deepest + 1) * (NODE.x + GAP.x) - GAP.x,
		float(tallest) * (NODE.y + GAP.y) - GAP.y)

	for entry: int in _techs:
		add_child(_node_box(entry as TechTree.Tech))
	queue_redraw()


## A qué profundidad queda una técnica CONTANDO SÓLO SU RAMA.
##
## `TechTree.depth_of` cuenta el árbol entero, y eso descoloca las ramas que
## cuelgan de otro oficio: el arte parietal está a cuatro eslabones de la talla
## sobre lasca, así que la pestaña del hogar dibujaba una sola casilla en la
## quinta columna con seiscientos píxeles de nada a su izquierda. Lo que el
## jugador tiene que ver ahí es el orden DE ESE OFICIO; de qué depende fuera lo
## dice el aviso emergente.
func _depth_in(tech: TechTree.Tech, branch: Array) -> int:
	var deepest := -1
	for need: int in (TechTree.CATALOGUE[tech]["needs"] as Array):
		if not branch.has(need):
			continue
		deepest = maxi(deepest, _depth_in(need as TechTree.Tech, branch))
	return deepest + 1


## La casilla de una técnica: dibujo, nombre y estado, con su aviso emergente.
func _node_box(tech: TechTree.Tech) -> Control:
	var frame := PanelContainer.new()
	frame.position = _at[tech]
	frame.custom_minimum_size = NODE
	frame.size = NODE
	frame.add_theme_stylebox_override("panel", UISkin.row_box(_tint(tech)))
	frame.tooltip_text = _tooltip(tech)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)

	var face: int = int(TechTree.TECH_FACE.get(tech, 0))
	var icon: Control = MateriaIcon.for_tool((-1 - face) as Tool.Kind, 18.0) \
		if face < 0 else MateriaIcon.for_materia(face as Materia.Kind, 18.0)
	icon.custom_minimum_size = Vector2(18.0, 18.0)
	icon.modulate.a = 1.0 if _tech.has(tech) else 0.55
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	var title := Label.new()
	title.text = TechTree.tech_name(tech)
	title.add_theme_font_size_override("font_size", 10)
	title.clip_text = true
	title.custom_minimum_size = Vector2(NODE.x - 34.0, 0.0)
	title.add_theme_color_override("font_color",
		UISkin.INK if _tech.has(tech) else UISkin.INK_SOFT)
	text.add_child(title)

	var state := Label.new()
	state.text = _state_line(tech)
	state.add_theme_font_size_override("font_size", 9)
	state.clip_text = true
	state.add_theme_color_override("font_color", UISkin.INK_FAINT)
	text.add_child(state)
	return frame


## El color de fondo dice el estado sin tener que leer: dominada, en marcha,
## esperando material, o todavía fuera de alcance.
func _tint(tech: TechTree.Tech) -> Color:
	if _tech.has(tech):
		return UISkin.GREEN.darkened(0.55)
	if not _tech.is_available(tech):
		return UISkin.GROUND.lightened(0.03)
	if _tech.progress(tech) >= 1.0:
		return UISkin.OCHRE.darkened(0.55)
	return UISkin.SURFACE


## Una línea corta con lo que le pasa ahora mismo.
func _state_line(tech: TechTree.Tech) -> String:
	if _tech.has(tech):
		return "dominada"
	if not _tech.is_available(tech):
		# Se dice CUÁL falta, no «falta lo de antes». Con la flecha delante eso
		# ya se veía; sin ella —porque la previa vive en la rama de otro
		# oficio— la casilla no decía nada, y es justo el caso en que hay que
		# mandar al jugador a otra pestaña.
		for need: int in (TechTree.CATALOGUE[tech]["needs"] as Array):
			if not _tech.has(need as TechTree.Tech):
				return "tras %s" % TechTree.tech_name(
					need as TechTree.Tech).to_lower()
		var camp := TechTree.needs_camp(tech)
		if camp >= 0:
			return "pide %s" % CampProjects.project_name(
				camp as CampProjects.Kind).to_lower()
		return "falta lo de antes"
	if _tech.progress(tech) >= 1.0:
		var short := _tech.missing_for(tech)
		return "falta %s" % ", ".join(short) if not short.is_empty() else "lista"
	return "%d %%" % int(_tech.progress(tech) * 100.0)


## Todo lo que hay que saber de una técnica, para el aviso emergente.
func _tooltip(tech: TechTree.Tech) -> String:
	var lines: Array[String] = [TechTree.tech_name(tech), ""]
	lines.append(TechTree.tech_desc(tech))
	lines.append("")

	var entry: Dictionary = TechTree.CATALOGUE[tech]
	var activity: int = entry["practice"]
	if activity >= 0 and float(entry["days"]) > 0.0:
		lines.append("Se aprende %s: %d de %d jornadas." % [
			Subsistence.activity_name(activity as Subsistence.Activity).to_lower(),
			int(_tech.days_in(activity as Subsistence.Activity)),
			int(entry["days"])])

	var cost := TechTree.learning_cost(tech)
	if cost.is_empty():
		lines.append("No gasta material: sale de la práctica y nada más.")
	else:
		var parts: Array[String] = []
		for material: int in cost:
			parts.append("%.0f %s" % [float(cost[material]),
				Materia.material_name(material as Materia.Kind).to_lower()])
		lines.append("Gasta al aprenderla: %s." % ", ".join(parts))

	var needs: Array = entry["needs"]
	if not needs.is_empty():
		var before: Array[String] = []
		for need: int in needs:
			before.append(TechTree.tech_name(need as TechTree.Tech))
		lines.append("Cuelga de: %s." % ", ".join(before))

	var short := _tech.missing_for(tech)
	if not short.is_empty():
		lines.append("")
		lines.append("Ahora mismo falta: %s." % ", ".join(short))
	return "\n".join(lines)


## Las flechas. Van DETRÁS de las casillas porque se dibujan sobre el propio
## control y los hijos se pintan encima.
func _draw() -> void:
	if _tech == null:
		return
	for entry: int in _techs:
		var tech := entry as TechTree.Tech
		for need: int in (TechTree.CATALOGUE[tech]["needs"] as Array):
			if not _at.has(need):
				continue
			_arrow(_at[need] as Vector2, _at[tech] as Vector2,
				UISkin.OCHRE if _tech.has(need) else UISkin.INK_FAINT)


## Una flecha del borde derecho de una casilla al borde izquierdo de la otra,
## en dos tramos rectos: una recta diagonal cruza las casillas de en medio.
func _arrow(from_at: Vector2, to_at: Vector2, tint: Color) -> void:
	var start := from_at + Vector2(NODE.x, NODE.y * 0.5)
	var end := to_at + Vector2(0.0, NODE.y * 0.5)
	var middle := start.x + (end.x - start.x) * 0.5
	var elbow_a := Vector2(middle, start.y)
	var elbow_b := Vector2(middle, end.y)
	draw_line(start, elbow_a, tint, ARROW_WIDTH)
	draw_line(elbow_a, elbow_b, tint, ARROW_WIDTH)
	draw_line(elbow_b, end, tint, ARROW_WIDTH)
	draw_colored_polygon(PackedVector2Array([
		end,
		end + Vector2(-ARROW_HEAD, -ARROW_HEAD * 0.55),
		end + Vector2(-ARROW_HEAD, ARROW_HEAD * 0.55),
	]), tint)
