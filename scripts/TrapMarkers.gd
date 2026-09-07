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


## El aparejo de cada trampa, al pie de la estaca.
##
## La estaca sola dice «aquí hay una trampa» y nada más: cuatro tipos distintos
## se veían exactamente iguales, y son cuatro jornadas y cuatro presas muy
## distintas. Cada una lleva ahora su forma, pequeña y a ras de suelo, que es
## como está una trampa de verdad: lo que se ve de un lazo puesto es la vara
## doblada, no el lazo.
func _build_gear(holder: Node3D, kind: Trap.Kind, wood: StandardMaterial3D) -> void:
	match kind:
		Trap.Kind.LAZO:
			# Vara doblada y corredera colgando del cabo.
			var bow := MeshInstance3D.new()
			var rod := CylinderMesh.new()
			rod.top_radius = 0.045
			rod.bottom_radius = 0.07
			rod.height = 2.1
			rod.radial_segments = 5
			bow.mesh = rod
			bow.material_override = wood
			bow.position = Vector3(0.35, 0.85, 0.0)
			bow.rotation = Vector3(0.0, 0.0, deg_to_rad(-38.0))
			holder.add_child(bow)

			var loop := MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.20
			ring.outer_radius = 0.26
			ring.rings = 8
			ring.ring_segments = 5
			loop.mesh = ring
			loop.material_override = _paint_of(Color(0.68, 0.72, 0.42))
			loop.position = Vector3(1.02, 0.30, 0.0)
			loop.rotation = Vector3(deg_to_rad(90.0), 0.0, 0.0)
			holder.add_child(loop)

		Trap.Kind.CEPO:
			# Losa calzada sobre un palo: la piedra encima y el disparador.
			var slab := MeshInstance3D.new()
			var stone := BoxMesh.new()
			stone.size = Vector3(1.5, 0.22, 1.1)
			slab.mesh = stone
			slab.material_override = _paint_of(Color(0.46, 0.44, 0.41))
			slab.position = Vector3(0.55, 0.62, 0.0)
			slab.rotation = Vector3(0.0, deg_to_rad(12.0), deg_to_rad(-22.0))
			holder.add_child(slab)

			var prop := MeshInstance3D.new()
			var stick := CylinderMesh.new()
			stick.top_radius = 0.04
			stick.bottom_radius = 0.05
			stick.height = 0.85
			stick.radial_segments = 5
			prop.mesh = stick
			prop.material_override = wood
			prop.position = Vector3(1.05, 0.42, 0.0)
			prop.rotation = Vector3(0.0, 0.0, deg_to_rad(9.0))
			holder.add_child(prop)

		Trap.Kind.RED_AVES:
			# Dos varas y la malla tendida entre ellas.
			for side: float in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var pole_mesh := CylinderMesh.new()
				pole_mesh.top_radius = 0.045
				pole_mesh.bottom_radius = 0.06
				pole_mesh.height = 2.4
				pole_mesh.radial_segments = 5
				post.mesh = pole_mesh
				post.material_override = wood
				post.position = Vector3(1.3 * side, 1.2, 0.0)
				holder.add_child(post)

			var mesh_panel := MeshInstance3D.new()
			var sheet := QuadMesh.new()
			sheet.size = Vector2(2.6, 1.9)
			mesh_panel.mesh = sheet
			var net := _paint_of(Color(0.46, 0.62, 0.55))
			net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			net.albedo_color.a = 0.42
			net.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh_panel.mesh.material = net
			mesh_panel.material_override = net
			mesh_panel.position = Vector3(0.0, 1.45, 0.0)
			holder.add_child(mesh_panel)

		Trap.Kind.FOSO:
			# El brocal de tierra removida y el ramaje que lo tapa.
			var lip := MeshInstance3D.new()
			var rim := TorusMesh.new()
			rim.inner_radius = 1.05
			rim.outer_radius = 1.45
			rim.rings = 12
			rim.ring_segments = 6
			lip.mesh = rim
			lip.material_override = _paint_of(Color(0.38, 0.29, 0.20))
			lip.position = Vector3(0.9, 0.14, 0.0)
			holder.add_child(lip)

			for i in range(4):
				var branch := MeshInstance3D.new()
				var twig := CylinderMesh.new()
				twig.top_radius = 0.035
				twig.bottom_radius = 0.045
				twig.height = 2.2
				twig.radial_segments = 4
				branch.mesh = twig
				branch.material_override = wood
				branch.position = Vector3(0.9, 0.24, 0.0)
				branch.rotation = Vector3(deg_to_rad(90.0),
					TAU * float(i) / 4.0 + 0.3, 0.0)
				holder.add_child(branch)


## Un material mate de un color, que es lo único que se pide aquí.
func _paint_of(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 1.0
	return paint


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

	_build_gear(holder, trap.kind, wood)

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
