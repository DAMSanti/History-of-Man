class_name TechGraph
extends Control

signal tech_selected(tech: TechTree.Tech)
## El árbol de técnicas de un oficio, dibujado como un árbol y hacia abajo.
##
## Era una lista sangrada con puntitos: «· Arpón — falta red». Se leía el
## nombre y el estado, pero no lo único que un árbol tiene que contestar de un
## vistazo —de qué cuelga qué, y por dónde se sigue— porque una sangría de
## cuatro espacios no dice de CUÁL de las tres de arriba cuelga.
##
## Crece HACIA ABAJO y no hacia la derecha. Un árbol horizontal obliga a
## desplazar la ventana en el eje en que no se desplaza nada más, y deja la
## rama larga —la caza, con ocho técnicas— fuera de pantalla desde el primer
## momento. Hacia abajo la profundidad se lee como se lee todo lo demás, y los
## hermanos quedan en fila, comparables.
##
## El estado no se dice con cuatro colores de fondo: la casilla se LLENA DE
## OCRE según se avanza, como se rellena una figura pintada. Ver [_draw].

## Tamaño de cada casilla y hueco entre ellas.
##
## Ciento setenta y dos y no ciento treinta y seis: la manuscrita ocupa mucho
## más a lo ancho que una tipografía de pantalla, y con la caja de antes salían
## «Pesquera de piea» y «Nasa de mimbr» recortadas a media palabra. Medido en
## la captura, no calculado.
const NODE := Vector2(168.0, 46.0)
const GAP := Vector2(16.0, 30.0)

## Grosor y cabeza de las flechas.
const ARROW_WIDTH := 1.5
const ARROW_HEAD := 6.5

var _tech: TechTree
var _techs: Array[int] = []
var _at: Dictionary = {}


## Monta el árbol de un oficio. `tree` es el estado de la banda, y `hueco` el
## ancho del que se dispone: el árbol se centra en él en vez de quedarse pegado
## a la izquierda con medio panel vacío al lado.
func build(tree: TechTree, job: int, hueco: float = 0.0) -> void:
	_tech = tree
	_techs.clear()
	_at.clear()
	for child: Node in get_children():
		child.queue_free()

	var branch: Array = TechTree.BRANCHES.get(job, [])
	if branch.is_empty():
		custom_minimum_size = Vector2(0.0, 0.0)
		return

	# Cada técnica va en la FILA de su profundidad y en la primera columna
	# libre de esa fila. La profundidad sale de los prerrequisitos —ver
	# `_depth_in`—, así que la forma del dibujo la dan los datos y no una tabla
	# de posiciones que se desincroniza al añadir una técnica.
	var filas: Dictionary = {}
	var orden: Dictionary = {}
	var mas_hondo := 0
	for entry: int in branch:
		var tech := entry as TechTree.Tech
		var fila := _depth_in(tech, branch)
		orden[tech] = [fila, int(filas.get(fila, 0))]
		filas[fila] = int(filas.get(fila, 0)) + 1
		_techs.append(entry)
		mas_hondo = maxi(mas_hondo, fila)

	var mas_ancha := 1
	for fila: int in filas:
		mas_ancha = maxi(mas_ancha, int(filas[fila]))
	var ancho := maxf(float(mas_ancha) * (NODE.x + GAP.x) - GAP.x, hueco)

	# Cada fila va centrada. Una fila de una casilla pegada a la izquierda
	# debajo de otra de cuatro no se lee como un árbol, se lee como una lista
	# mal alineada.
	for entry: int in _techs:
		var tech := entry as TechTree.Tech
		var par: Array = orden[tech]
		var cuantas: int = int(filas[par[0]])
		var margen := (ancho - (float(cuantas) * (NODE.x + GAP.x) - GAP.x)) * 0.5
		_at[tech] = Vector2(
			margen + float(par[1]) * (NODE.x + GAP.x),
			float(par[0]) * (NODE.y + GAP.y))

	custom_minimum_size = Vector2(ancho,
		float(mas_hondo + 1) * (NODE.y + GAP.y) - GAP.y)

	for entry: int in _techs:
		add_child(_node_box(entry as TechTree.Tech))
	queue_redraw()


## A qué profundidad queda una técnica CONTANDO SÓLO SU RAMA.
##
## `TechTree.depth_of` cuenta el árbol entero, y eso descoloca las ramas que
## cuelgan de otro oficio: el arte parietal está a cuatro eslabones de la talla
## sobre lasca, así que la pestaña del hogar dibujaba una sola casilla en la
## quinta fila con doscientos píxeles de nada encima. Lo que el jugador tiene
## que ver ahí es el orden DE ESE OFICIO; de qué depende fuera lo dice el aviso
## emergente.
func _depth_in(tech: TechTree.Tech, branch: Array) -> int:
	var deepest := -1
	for need: int in (TechTree.CATALOGUE[tech]["needs"] as Array):
		if not branch.has(need):
			continue
		deepest = maxi(deepest, _depth_in(need as TechTree.Tech, branch))
	return deepest + 1


## La casilla de una técnica: dibujo, nombre y estado, con su aviso emergente.
##
## El fondo NO va aquí: lo pinta [_draw] por debajo, porque el relleno de ocre
## sube según el avance y eso no es una caja de estilo, es una figura a medio
## pintar.
func _node_box(tech: TechTree.Tech) -> Control:
	var frame := PanelContainer.new()
	frame.position = _at[tech]
	frame.custom_minimum_size = NODE
	frame.size = NODE
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.tooltip_text = _tooltip(tech)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)

	var hueco := MarginContainer.new()
	hueco.add_theme_constant_override("margin_left", 7)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hueco)

	var face: int = int(TechTree.TECH_FACE.get(tech, 0))
	var icon: Control = MateriaIcon.for_tool((-1 - face) as Tool.Kind, 19.0) \
		if face < 0 else MateriaIcon.for_materia(face as Materia.Kind, 19.0)
	icon.custom_minimum_size = Vector2(19.0, 19.0)
	icon.modulate.a = 1.0 if _tech.has(tech) else 0.5
	hueco.add_child(icon)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	# Sobre una casilla YA PINTADA de ocre no se escribe en hueso: se escribe en
	# carbón, encima del pigmento. Es lo que se hace en una pared y además es lo
	# único que se lee —hueso sobre ocre era ocre sobre ocre—.
	var pintada := _tech.has(tech)
	var title := Label.new()
	title.text = TechTree.tech_name(tech)
	title.clip_text = true
	title.custom_minimum_size = Vector2(NODE.x - 44.0, 0.0)
	Pigmento.escribir(title, UISkin.GROUND.darkened(0.45) if pintada
		else UISkin.INK_SOFT, 17)
	text.add_child(title)

	var state := Label.new()
	state.text = _state_line(tech)
	state.clip_text = true
	# El estado va en CARBÓN: seco, roto, de segundo plano. Es la jerarquía
	# hecha con el material y no con el tamaño de la letra.
	Pigmento.escribir(state, UISkin.GROUND.darkened(0.2) if pintada
		else UISkin.INK_FAINT, 14, Pigmento.carbon())
	text.add_child(state)

	if pintada and tech != TechTree.Tech.LASCA:
		frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		frame.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				tech_selected.emit(tech)
		)

	return frame


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
	var job := TechTree.job_of(tech)
	if job >= 0 and float(entry["days"]) > 0.0:
		lines.append("Se aprende trabajando de %s: %d de %d jornadas." % [
			Profession.job_name(job as Profession.Job).to_lower(),
			int(_tech.days_in(job as Profession.Job)),
			int(entry["days"])])

	var cost := TechTree.learning_cost(tech)
	if cost.is_empty():
		lines.append("No gasta material: sale de la práctica y nada más.")
	else:
		# A PLAZOS, y diciendo cuánto abre cada unidad: es lo que hace legible
		# que una técnica se pare por falta de material aunque sobren jornadas.
		var parts: Array[String] = []
		for material: int in cost:
			var total := float(cost[material])
			parts.append("%.0f %s" % [total,
				Materia.material_name(material as Materia.Kind).to_lower()])
		lines.append("Se gasta mientras se aprende: %s." % ", ".join(parts))
		var puestas := TechTree.learning_cost(tech).size()
		if puestas > 0 and float(entry["days"]) > 0.0:
			var una: float = float(cost[cost.keys()[0]])
			if una > 0.0:
				lines.append("Cada unidad abre el %.0f %% de las jornadas."
					% (100.0 / una))
		var falta := _tech.missing_for(tech)
		if not falta.is_empty():
			lines.append("PARADA por falta de: %s." % ", ".join(falta))

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


## Las correas del árbol y las casillas. Van DETRÁS del texto porque se dibujan
## sobre el propio control y los hijos se pintan encima.
func _draw() -> void:
	if _tech == null:
		return
	for entry: int in _techs:
		var tech := entry as TechTree.Tech
		for need: int in (TechTree.CATALOGUE[tech]["needs"] as Array):
			if not _at.has(need):
				continue
			_arrow(_at[need] as Vector2, _at[tech] as Vector2,
				UISkin.OCHRE.darkened(0.15) if _tech.has(need)
				else UISkin.INK_FAINT)
	for entry: int in _techs:
		_casilla(entry as TechTree.Tech)


## La casilla: el hueco excavado y el ocre que lo va llenando.
##
## El avance se ve como se ve una figura a medio pintar —el color sube desde
## abajo— en vez de con un color de fondo por estado. Una barra de progreso más
## en la esquina sería otra barra de progreso; esto dice lo mismo y además dice
## que lo que se está haciendo es PINTAR.
func _casilla(tech: TechTree.Tech) -> void:
	var caja := Rect2(_at[tech] as Vector2, NODE)
	var alcanzable := _tech.is_available(tech)

	# El hueco: un rebaje en la piel, más oscuro que ella.
	draw_rect(caja, UISkin.GROUND.darkened(0.35 if alcanzable else 0.15), true)

	var lleno := 0.0
	if _tech.has(tech):
		lleno = 1.0
	elif alcanzable:
		lleno = clampf(_tech.progress(tech), 0.0, 1.0)
	if lleno > 0.0:
		var alto := caja.size.y * lleno
		# Dominada: ocre macizo. A medias: ocre aguado, que es lo que hay
		# cuando la mano todavía no ha terminado.
		var tinta := UISkin.OCHRE.darkened(0.42)
		tinta.a = 1.0 if _tech.has(tech) else 0.55
		draw_rect(Rect2(caja.position + Vector2(0.0, caja.size.y - alto),
			Vector2(caja.size.x, alto)), tinta, true)

	# El filo. En ocre si se puede tocar, en carbón si todavía no.
	draw_rect(caja, UISkin.OCHRE.darkened(0.25) if alcanzable
		else UISkin.INK_FAINT.darkened(0.35), false, 1.0)


## Una correa de la casilla de arriba a la de abajo, en tres tramos rectos: una
## diagonal cruzaría las casillas de en medio.
func _arrow(from_at: Vector2, to_at: Vector2, tint: Color) -> void:
	var start := from_at + Vector2(NODE.x * 0.5, NODE.y)
	var end := to_at + Vector2(NODE.x * 0.5, 0.0)
	var middle := start.y + (end.y - start.y) * 0.5
	var elbow_a := Vector2(start.x, middle)
	var elbow_b := Vector2(end.x, middle)
	draw_line(start, elbow_a, tint, ARROW_WIDTH, true)
	draw_line(elbow_a, elbow_b, tint, ARROW_WIDTH, true)
	draw_line(elbow_b, end, tint, ARROW_WIDTH, true)
	draw_colored_polygon(PackedVector2Array([
		end,
		end + Vector2(-ARROW_HEAD * 0.55, -ARROW_HEAD),
		end + Vector2(ARROW_HEAD * 0.55, -ARROW_HEAD),
	]), tint)
