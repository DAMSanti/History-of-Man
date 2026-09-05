class_name TrapMarkers
extends Node3D
## Las trampas puestas, vistas en el monte.
##
## Petición literal: «las trampas se deben construir y mostrar en el terreno
## cuando estén puestas». Y hace falta, no es adorno: una trampa es lo único
## que la banda deja PLANTADO en el mapa. Sin verla, la línea de trampas es
## un número en un panel; viéndola, es un recorrido —esta ladera, aquel vado,
## el paso de arriba— y el jugador empieza a pensar en dónde ponerlas.
##
## Se dibuja distinto de un paraje a propósito. Un paraje es un sitio que la
## banda CONOCE; una trampa es una cosa que la banda ha PUESTO, y las dos no
## pueden leerse igual. El paraje lleva chapa de alfiler y rótulo; la trampa
## lleva una estaca clavada con una señal encima, pequeña, y solo dice algo
## cuando tiene presa dentro.

## Cuánto se levanta la señal sobre el suelo.
const HEIGHT := 3.2

## Altura de la estaca, en metros de mundo.
const STAKE := 2.6

## Tamaño de la señal.
const HEAD := 1.5

## El color de cada tipo. La red va en el verde de la fibra, el foso en el
## pardo de la tierra removida, el cepo en el gris de la losa.
const TINTS := {
	Trap.Kind.LAZO: Color(0.62, 0.68, 0.34),
	Trap.Kind.CEPO: Color(0.58, 0.57, 0.53),
	Trap.Kind.RED_AVES: Color(0.46, 0.62, 0.55),
	Trap.Kind.FOSO: Color(0.55, 0.42, 0.28),
}

## Lo que se pone encima de la estaca cuando la trampa tiene presa. Es la
## única información que da el marcador de lejos, y es la que importa: a esa
## hay que ir hoy.
const CEBADA := Color(0.90, 0.72, 0.30)

var _markers: Dictionary = {}
var _terrain: TerrainGenerator


## Rehace las señales a partir de las trampas que hay puestas.
##
## Se llama una vez al cerrar la jornada, igual que las chapas de paraje: las
## trampas se arman y se pierden por jornadas, no por fotogramas.
func refresh(traps: Array, terrain: TerrainGenerator) -> void:
	_terrain = terrain
	var alive := {}

	for trap: Trap in traps:
		var key := _key(trap)
		alive[key] = true
		var holder: Node3D = _markers.get(key)
		if holder == null or not is_instance_valid(holder):
			holder = _build(trap, terrain)
			_markers[key] = holder
		_paint(holder, trap)

	# Y se quitan las que ya no están: una trampa perdida deja de verse, que
	# es como se nota que se ha perdido.
	for key: String in _markers.keys():
		if alive.has(key):
			continue
		var gone: Node3D = _markers[key]
		if is_instance_valid(gone):
			gone.queue_free()
		_markers.erase(key)


func clear() -> void:
	for key: String in _markers.keys():
		var holder: Node3D = _markers[key]
		if is_instance_valid(holder):
			holder.queue_free()
	_markers.clear()


## Cuántas señales hay puestas ahora mismo. Para poder comprobarlo sin mirar.
func count() -> int:
	return _markers.size()


func _key(trap: Trap) -> String:
	return "%d_%d_%d_%d" % [int(trap.kind), int(trap.position.x),
		int(trap.position.z), trap.set_day]


func _build(trap: Trap, terrain: TerrainGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Trampa_" + _key(trap)
	var world := trap.position
	if terrain:
		world.y = terrain.get_height_at(world)
	holder.position = world
	add_child(holder)

	# La estaca: es lo que se clava, y lo que hace que la trampa se lea como
	# una cosa PUESTA y no como un sitio conocido.
	var stake := MeshInstance3D.new()
	stake.name = "Estaca"
	var pole := CylinderMesh.new()
	pole.top_radius = 0.10
	pole.bottom_radius = 0.14
	pole.height = STAKE
	pole.radial_segments = 6
	stake.mesh = pole
	stake.position = Vector3(0.0, STAKE * 0.5, 0.0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.33, 0.22)
	wood.roughness = 1.0
	stake.material_override = wood
	holder.add_child(stake)

	# Y la señal de arriba, que es la que se ve de lejos y la que cambia de
	# color cuando hay presa dentro.
	var head := MeshInstance3D.new()
	head.name = "Señal"
	var box := BoxMesh.new()
	box.size = Vector3(HEAD, HEAD * 0.22, HEAD)
	head.mesh = box
	head.position = Vector3(0.0, HEIGHT, 0.0)
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.no_depth_test = true
	paint.render_priority = 1
	head.material_override = paint
	holder.add_child(head)

	var label := Label3D.new()
	label.name = "Rotulo"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.011
	label.no_depth_test = true
	label.render_priority = 3
	label.position = Vector3(0.0, HEIGHT + 1.4, 0.0)
	label.outline_size = 12
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	holder.add_child(label)

	return holder


## El color y el rótulo dicen el estado sin tener que pinchar: encendida la
## que tiene presa, apagada la que está gastándose, y el rótulo solo aparece
## cuando hay algo que ir a buscar.
func _paint(holder: Node3D, trap: Trap) -> void:
	var head := holder.get_node_or_null("Señal") as MeshInstance3D
	var label := holder.get_node_or_null("Rotulo") as Label3D
	if head == null or label == null:
		return

	var ready := trap.soaking >= Trap.days_per_catch(trap.kind)
	var tint: Color = TINTS.get(trap.kind, Color(0.6, 0.6, 0.6))
	# La trampa vieja se ve gastada: el color se apaga con la condición, que
	# es la forma de ver una línea que hay que renovar sin abrir ningún panel.
	tint = tint.lerp(Color(0.30, 0.29, 0.27), 1.0 - trap.condition())

	var paint := head.material_override as StandardMaterial3D
	if paint:
		paint.albedo_color = CEBADA if ready else tint

	if ready:
		label.text = Trap.trap_name(trap.kind)
		label.modulate = CEBADA
		label.visible = true
	else:
		label.visible = false
