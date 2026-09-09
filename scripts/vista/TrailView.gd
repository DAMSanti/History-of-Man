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

## En que jornada va la partida, para poder tirar los rastros viejos. Menos de
## cero es «no se sabe»: entonces se pintan todos, que es lo que hacia antes.
var _today: int = -1

## El rastro de UNA entidad suelta, que es lo que mira el censo.
##
## Va por su lado y no reutiliza `_job` porque contesta otra pregunta. El
## oficio pregunta «¿por dónde anda la recolección?» y saca quince líneas; el
## censo pregunta «¿por dónde ha andado ESTE uro?» y saca una. Mezclarlas
## obligaría a apagar una para ver la otra, y la gracia de tener las dos es
## poder ver el rastro de un lobo con el de los cazadores puesto.
##
## `_solo_source` es un `Callable` y no una lista de puntos porque el rastro
## crece: una lista se congela en el instante en que se pulsó, y lo que se
## quiere ver es por dónde va AHORA. Devuelve `Array[PackedVector3Array]`, que
## es una persona con varias salidas o un animal con un solo recorrido.
var _solo_lines: Array[MeshInstance3D] = []
var _solo_source: Callable = Callable()
var _solo_tint := Color.WHITE
var _solo_name := ""

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
	_wipe(_lines)
	_job = -1
	_people.clear()


## Pinta el rastro de todo el que hace este oficio.
func show_job(job: int, people: Array[Inhabitant],
		terrain: TerrainGenerator, today: int = -1) -> void:
	_people = people
	_terrain = terrain
	_job = job
	_today = today
	_repaint()


## Sigue el rastro de una sola entidad: una persona, un uro, un lobo.
##
## `source` se llama en cada repintado y devuelve los tramos a dibujar. Se pide
## así -y no una lista ya hecha- porque el rastro crece mientras el bicho anda:
## con una lista, el dibujo se queda en la foto del instante en que se pulsó.
func follow(source: Callable, tint: Color, terrain: TerrainGenerator,
		label: String = "") -> void:
	_solo_source = source
	_solo_tint = tint
	_solo_name = label
	if terrain != null:
		_terrain = terrain
	_repaint_solo()


func stop_following() -> void:
	_solo_source = Callable()
	_solo_name = ""
	_wipe(_solo_lines)


## A quién se está siguiendo, o cadena vacía si a nadie.
func following() -> String:
	return _solo_name if _solo_source.is_valid() else ""


func _process(delta: float) -> void:
	# Se repinta solo mientras haya algo elegido. Sin esto habia que cerrar y
	# abrir el panel para ver por donde iban ahora, que es justo la pregunta
	# que uno se hace con el rastro delante.
	if _job < 0 and not _solo_source.is_valid():
		return
	_since_redraw += delta
	if _since_redraw < REDRAW_EVERY:
		return
	_since_redraw = 0.0
	if _job >= 0:
		_repaint()
	if _solo_source.is_valid():
		_repaint_solo()


## El rastro de la entidad seguida, entero de una vez.
##
## Se dibuja SIN apagar en los tramos viejos, al reves que el de oficio: aqui
## hay una sola linea y lo que se pregunta es la forma del recorrido completo
## -si repite querencia, si el lobo lo echo del prado-, no cual es el trecho
## de hoy.
func _repaint_solo() -> void:
	_wipe(_solo_lines)
	var paths: Variant = _solo_source.call()
	if not (paths is Array):
		return
	var head := true
	for path: PackedVector3Array in (paths as Array):
		_draw_solo(path, head)
		head = false


func _draw_solo(points: PackedVector3Array, live: bool) -> void:
	if points.size() < 2:
		return
	var mesh := _drape(points)
	if live:
		_diamond(mesh, points[points.size() - 1])
	var line := _hang(mesh, _solo_tint if live
		else _solo_tint * Color(1.0, 1.0, 1.0, 0.45), "RastroSolo")
	_solo_lines.append(line)


## Tira las lineas de una tanda y deja la lista vacia.
func _wipe(lines: Array[MeshInstance3D]) -> void:
	for line: MeshInstance3D in lines:
		if is_instance_valid(line):
			line.queue_free()
	lines.clear()


func _repaint() -> void:
	_wipe(_lines)
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
	# SOLO LAS DE LOS ULTIMOS DIEZ DIAS. El tope de cuarenta salidas es de la
	# ficha -lo que se puede leer- y no vale para el mapa: cuarenta salidas de
	# un explorador son casi dos meses de lineas encima del valle, y lo que se
	# ve es una maraña. Lo que interesa mirar sobre el terreno es por donde se
	# anda AHORA. Ver [Inhabitant.RASTRO_DIAS].
	var recientes: Array[Dictionary] = person.journeys if _today < 0 		else person.rastros_recientes(_today)
	for trip: Dictionary in recientes:
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
	var mesh := _drape(points)
	# La punta de la salida en curso lleva rombo: es donde esta la persona
	if live:
		_diamond(mesh, points[points.size() - 1])
	_lines.append(_hang(mesh, tint, "Rastro%s" % person.given_name))


## La linea, partida cada DRAPE metros y pegada al relieve.
func _drape(points: PackedVector3Array) -> ImmediateMesh:
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
	return mesh


## El rombo de la punta: donde esta ahora quien deja el rastro.
func _diamond(mesh: ImmediateMesh, at: Vector3) -> void:
	var head := at
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


## Un color por persona, repartido por el círculo cromático.
##
## Por identificador y no al azar: así el mismo cazador es del mismo color
## cada vez que se abre el panel, y se le puede seguir de una mirada a otra.
static func colour_for(person_id: int) -> Color:
	return Color.from_hsv(fposmod(float(person_id) * 0.381, 1.0), 0.65, 1.0)


## Cuelga la malla ya montada del arbol, con su material.
func _hang(mesh: ImmediateMesh, tint: Color, label: String) -> MeshInstance3D:
	var line := MeshInstance3D.new()
	line.name = label
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
	return line
