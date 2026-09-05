class_name TrailView
extends Node3D
## Dibuja por dónde ha andado la banda y qué ha hecho en cada sitio.
##
## Es una herramienta para mirar el juego por dentro, no una capa de la
## partida. Sirve para responder preguntas que de otra forma hay que adivinar:
## ¿por qué la recolección no trae nada —van lejos, o dan vueltas cerca?
## ¿el batidor repite zona? ¿la caza cruza el río o lo rodea?
##
## Se enseña un oficio cada vez. Con los quince rastros a la vez no se ve
## nada, y la pregunta siempre es sobre un oficio concreto.

## Cuánto se levanta la línea sobre el suelo para que no se entierre.
const LIFT := 3.0

## Tamaño del rombo que marca un hito con algo que contar.
const MARK := 6.0

## Cada cuántos metros se parte un tramo para que siga el relieve. Sin esto
## una recta entre dos hitos lejanos se hunde bajo la loma de en medio.
const DRAPE := 14.0


var _lines: Array[MeshInstance3D] = []
var _job: int = -1
var _people: Array[Inhabitant] = []
var _terrain: TerrainGenerator
var _since_redraw: float = 0.0

## Cada cuánto se vuelve a pintar, en segundos.
##
## El rastro crece mientras la gente anda, así que un dibujo hecho una vez al
## pulsar el botón se queda viejo en cuanto la banda da diez pasos. Cuatro
## veces por segundo basta: son líneas, no simulación.
const REDRAW_EVERY := 0.25


## Qué oficio se está mirando, o -1 si ninguno.
func showing() -> int:
	return _job


func clear() -> void:
	for line: MeshInstance3D in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()
	_job = -1
	_people.clear()


## Pinta el rastro de todo el que hace este oficio.
func show_job(job: int, people: Array[Inhabitant],
		terrain: TerrainGenerator) -> void:
	_people = people
	_terrain = terrain
	_job = job
	_repaint()


func _process(delta: float) -> void:
	# Se repinta solo mientras haya un oficio elegido. Sin esto habia que
	# cerrar y abrir el panel para ver por donde iban ahora, que es justo la
	# pregunta que uno se hace con el rastro delante.
	if _job < 0:
		return
	_since_redraw += delta
	if _since_redraw < REDRAW_EVERY:
		return
	_since_redraw = 0.0
	_repaint()


func _repaint() -> void:
	for line: MeshInstance3D in _lines:
		if is_instance_valid(line):
			line.queue_free()
	_lines.clear()

	for person: Inhabitant in _people:
		_draw_person(person)


## Todas las salidas de una persona, no solo la ultima.
##
## Se dibujan desde las SALIDAS y no desde el rastro comun: el rastro es un
## anillo de trescientos puntos que va tirando lo viejo, asi que pintando
## desde ahi solo se veia el ultimo trecho. Las salidas se guardan enteras.
func _draw_person(person: Inhabitant) -> void:
	var tint := colour_for(person.id)

	# Las de antes, apagadas: son historia y no deben tapar lo de hoy.
	#
	# Se filtra por el oficio CON EL QUE SE SALIO, no por el que tenga la
	# persona ahora. Con lo segundo, el dia que la despensa llega al tope el
	# reparto saca a todo el mundo de la recoleccion a la vez y los rastros
	# de recoleccion desaparecian de golpe, como si nadie hubiera pisado el
	# monte en toda la partida.
	for trip: Dictionary in person.journeys:
		if int(trip.get("job", person.job)) != _job:
			continue
		_draw_path(trip.get("path", PackedVector3Array()) as PackedVector3Array,
			person, tint * Color(1.0, 1.0, 1.0, 0.45), false)

	# Y la de ahora, viva y con los hitos marcados
	if not person.journey.is_empty() 			and int(person.journey.get("job", person.job)) == _job:
		_draw_path(person.journey["path"] as PackedVector3Array,
			person, tint, true)


func _draw_path(points: PackedVector3Array, person: Inhabitant, tint: Color,
		live: bool) -> void:
	if points.size() < 2:
		return

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(int(a.distance_to(b) / DRAPE), 1)
		for step in range(steps + 1):
			var point := a.lerp(b, float(step) / float(steps))
			if _terrain:
				point.y = _terrain.get_height_at(point)
			mesh.surface_add_vertex(point + Vector3(0.0, LIFT, 0.0))
	mesh.surface_end()

	# La punta de la salida en curso lleva rombo: es donde esta la persona
	if live:
		var head := points[points.size() - 1]
		if _terrain:
			head.y = _terrain.get_height_at(head)
		head.y += LIFT
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		mesh.surface_add_vertex(head + Vector3(-MARK, 0.0, 0.0))
		mesh.surface_add_vertex(head + Vector3(0.0, 0.0, -MARK))
		mesh.surface_add_vertex(head + Vector3(MARK, 0.0, 0.0))
		mesh.surface_add_vertex(head + Vector3(0.0, 0.0, MARK))
		mesh.surface_add_vertex(head + Vector3(-MARK, 0.0, 0.0))
		mesh.surface_end()

	_finish(mesh, person, tint)


## Un color por persona, repartido por el círculo cromático.
##
## Por identificador y no al azar: así el mismo cazador es del mismo color
## cada vez que se abre el panel, y se le puede seguir de una mirada a otra.
static func colour_for(person_id: int) -> Color:
	return Color.from_hsv(fposmod(float(person_id) * 0.381, 1.0), 0.65, 1.0)


## Cuelga la malla ya montada del arbol, con su material.
func _finish(mesh: ImmediateMesh, person: Inhabitant, tint: Color) -> void:
	var line := MeshInstance3D.new()
	line.name = "Rastro%s" % person.given_name
	line.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Se ve a traves del terreno: un rastro que se esconde detras de una loma
	# no cuenta nada, y la pregunta suele ser justo que hay detras de la loma
	material.no_depth_test = true
	line.material_override = material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	_lines.append(line)
