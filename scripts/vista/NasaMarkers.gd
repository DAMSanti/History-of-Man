class_name NasaMarkers
extends Node3D
## Las nasas caladas, vistas en la orilla.
##
## Mismo argumento que [TrapMarkers], que es de donde sale el idioma entero:
## una nasa que no se ve es un número en un panel, y viéndola es un tramo de
## río al que se va. Las dos son lo único que la banda deja PLANTADO en el
## mapa, así que se leen igual —algo puesto, no un sitio conocido— y se
## distinguen por la forma, que es la del aparejo.
##
## Y se dibuja a mano, no se descarga. Es la misma decisión que ya se tomó con
## el aparejo de cada trampa: no hay modelo CC0 scripteable de nasa de mimbre
## —ni de lazo, ni de cepo, ni de foso—, y la fotogrametría de Poly Haven que
## usa [ResourceProps] es de piedras y plantas, no de objetos hechos por gente.
## Un cesto trenzado en embudo son un cono y unos aros, y sale mejor puesto a
## mano que esperando a un escaneo que no existe.
##
## La diferencia de fondo con la trampa: una nasa está METIDA EN EL AGUA. Se
## dibuja medio hundida y ladeada hacia el cauce, con la boca del embudo
## mirando corriente arriba, que es como se cala de verdad.

## Cuánto se levanta la señal sobre el suelo.
const HEIGHT := 2.6

## Altura de la estaca a la que se amarra. Más corta que la de una trampa: lo
## que sujeta una nasa es una vara clavada en la orilla, no un poste.
const STAKE := 1.7

## Tamaño de la señal de arriba.
const HEAD := 1.2

## Largo y radio del cesto, en metros. Una nasa de río es cosa de un brazo.
const CREEL_LENGTH := 0.95
const CREEL_RADIUS := 0.26

## Cuántos aros lleva el trenzado. Tres se leen como cesto; con uno parece un
## cucurucho y con seis no se distingue nada a la distancia de juego.
const CREEL_HOOPS := 3

## Cuánto se ladea hacia el agua, en grados. Una nasa calada no está de pie.
const CREEL_TILT := 62.0

## El mimbre, y el color de cuando hay algo dentro. El segundo es el MISMO
## ocre que la trampa cebada a propósito: «ve a levantar eso» tiene que
## significar lo mismo en el monte y en el río.
const WICKER := Color(0.66, 0.56, 0.33)
const CEBADA := Color(0.90, 0.72, 0.30)

## Y el de la que se ha quedado sin cebo, que sigue cogiendo pero coge poco.
## Ver [Nasa.SIN_CEBO].
const SIN_CEBO := Color(0.45, 0.50, 0.56)

var _markers: Dictionary = {}


## Rehace las señales a partir de las nasas que hay caladas.
##
## Una vez al cerrar la jornada, igual que las trampas: una nasa se cala y se
## pudre por jornadas, no por fotogramas.
func refresh(nasas: Array, terrain: TerrainGenerator) -> void:
	var alive := {}

	for nasa: Nasa in nasas:
		var key := _key(nasa)
		alive[key] = true
		var holder: Node3D = _markers.get(key)
		if holder == null or not is_instance_valid(holder):
			holder = _build(nasa, terrain)
			_markers[key] = holder
		_paint(holder, nasa)

	# Y se quitan las que ya no están: una nasa podrida deja de verse, que es
	# como se nota que se ha perdido.
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


func _key(nasa: Nasa) -> String:
	return "%d_%d_%d" % [int(nasa.position.x), int(nasa.position.z),
		nasa.set_day]


func _paint_of(colour: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	paint.roughness = 1.0
	return paint


func _build(nasa: Nasa, terrain: TerrainGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Nasa_" + _key(nasa)
	var world := nasa.position
	if terrain:
		world.y = terrain.get_height_at(world)
	holder.position = world
	add_child(holder)

	var wicker := _paint_of(WICKER)

	# La vara de la orilla a la que se amarra. Corta y clavada de través: es
	# lo que impide que la corriente se lleve el cesto.
	var stake := MeshInstance3D.new()
	stake.name = "Vara"
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.08
	pole.height = STAKE
	pole.radial_segments = 5
	stake.mesh = pole
	stake.position = Vector3(0.0, STAKE * 0.5, 0.0)
	stake.rotation = Vector3(0.0, 0.0, deg_to_rad(-9.0))
	stake.material_override = _paint_of(Color(0.42, 0.33, 0.22))
	holder.add_child(stake)

	# El cesto: un cono tumbado hacia el agua, con la boca del embudo mirando
	# corriente arriba. Va bajo, medio hundido, que es como se cala.
	var creel := Node3D.new()
	creel.name = "Cesto"
	creel.position = Vector3(0.75, 0.16, 0.0)
	creel.rotation = Vector3(0.0, 0.0, deg_to_rad(-CREEL_TILT))
	holder.add_child(creel)

	var body := MeshInstance3D.new()
	body.name = "Mimbre"
	var cone := CylinderMesh.new()
	cone.top_radius = CREEL_RADIUS * 0.35
	cone.bottom_radius = CREEL_RADIUS
	cone.height = CREEL_LENGTH
	cone.radial_segments = 7
	body.mesh = cone
	body.material_override = wicker
	creel.add_child(body)

	# Los aros del trenzado. Son lo que hace que se lea como cestería y no
	# como un cucurucho: sin ellos, a diez metros es un cono liso.
	for i in range(CREEL_HOOPS):
		var t := float(i + 1) / float(CREEL_HOOPS + 1)
		var hoop := MeshInstance3D.new()
		var ring := TorusMesh.new()
		var radius: float = lerpf(CREEL_RADIUS, CREEL_RADIUS * 0.35, t)
		ring.inner_radius = radius
		ring.outer_radius = radius + 0.035
		ring.rings = 7
		ring.ring_segments = 4
		hoop.mesh = ring
		hoop.material_override = wicker
		hoop.position = Vector3(0.0, lerpf(-CREEL_LENGTH * 0.5,
			CREEL_LENGTH * 0.5, t), 0.0)
		creel.add_child(hoop)

	# Y la señal de arriba, que es la que se ve de lejos.
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
	label.font_size = 38
	label.pixel_size = 0.011
	label.no_depth_test = true
	label.render_priority = 3
	label.position = Vector3(0.0, HEIGHT + 1.2, 0.0)
	label.outline_size = 12
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	holder.add_child(label)

	return holder


## El color dice el estado sin tener que pinchar, con TRES casos y no dos: la
## nasa de río tiene uno que la trampa no tiene, que es estar calada y sin
## cebo. Coge igual, pero coge poco, y eso hay que poder verlo de lejos porque
## tiene arreglo y es barato.
func _paint(holder: Node3D, nasa: Nasa) -> void:
	var head := holder.get_node_or_null("Señal") as MeshInstance3D
	var label := holder.get_node_or_null("Rotulo") as Label3D
	if head == null or label == null:
		return

	var tint := WICKER if nasa.is_baited() else SIN_CEBO
	# El mimbre calado se pudre, y el color se apaga con él: es la forma de ver
	# que una línea hay que renovar sin abrir ningún panel.
	tint = tint.lerp(Color(0.30, 0.29, 0.27), 1.0 - nasa.condition())

	var paint := head.material_override as StandardMaterial3D
	if paint:
		paint.albedo_color = CEBADA if nasa.has_catch() else tint

	if nasa.has_catch():
		label.text = "Nasa"
		label.modulate = CEBADA
		label.visible = true
	elif not nasa.is_baited():
		label.text = "sin cebo"
		label.modulate = SIN_CEBO
		label.visible = true
	else:
		label.visible = false
