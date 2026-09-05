class_name CaveMouth
extends Node3D
## Boca de cueva integrada en la ladera.
##
## Ha pasado por dos errores que conviene dejar escritos, porque los dos
## enseñan lo mismo desde lados opuestos.
##
## El primero fue una media esfera oscura mirando al cielo: eso no es una
## cueva, es una sima. Una cueva se abre HORIZONTALMENTE contra la ladera.
##
## El segundo fue pasarse al arreglarlo. Le puse dintel y jambas de caja, y el
## resultado parecía una construcción megalítica plantada en el monte. Una
## cueva no tiene nada añadido: es un HUECO. Todo lo que sobresalga del terreno
## la delata como objeto pegado encima.
##
## Así que ahora no sobresale nada. La entalladura la excava el propio terreno
## (ver `_mark_cave_carvings`) y aquí solo va la oscuridad del interior, hundida
## en ella, más unos bloques desprendidos al pie —que son piedra suelta, no
## sillería— para que la boca no salga limpia como un tubo cortado.

## Datos del registro de este elemento, para la ventana de información
var feature: Dictionary = {}

## Si la banda ya la ha encontrado. Mientras no, la cueva no se dibuja: no es
## que esté oculta, es que para el jugador todavía no existe.
var discovered: bool = false

var _marker: Node3D

## Radio del vano, en metros
var mouth_radius: float = 7.0

var _mouth_position: Vector3
var _rng := RandomNumberGenerator.new()


## Construye la boca en un punto del terreno, mirando ladera abajo.
func build(terrain: TerrainGenerator, world: Vector3, data: Dictionary) -> void:
	feature = data
	_mouth_position = world
	# Semilla estable por posición: la misma cueva sale igual entre partidas
	_rng.seed = int(world.x) * 73856093 ^ int(world.z) * 19349663

	# Hacia dónde cae la ladera: es la dirección a la que mira la cueva. Se
	# mide sobre varias decenas de metros y no entre vértices vecinos, porque a
	# escala de vértice manda el ruido y la boca miraría a cualquier lado.
	var probe := 22.0
	var east := terrain.get_height_at(world + Vector3(probe, 0, 0))
	var west := terrain.get_height_at(world - Vector3(probe, 0, 0))
	var south := terrain.get_height_at(world + Vector3(0, 0, probe))
	var north := terrain.get_height_at(world - Vector3(0, 0, probe))

	var downhill := Vector2(west - east, north - south)
	if downhill.length() < 0.01:
		downhill = Vector2(0.0, 1.0)
	downhill = downhill.normalized()
	var facing := Vector3(downhill.x, 0.0, downhill.y)

	position = world
	# El eje -Z del nodo mira ladera abajo; con eso las piezas se colocan en
	# coordenadas locales sin volver a pensar en la orientación
	look_at_from_position(world, world + facing, Vector3.UP)

	_build_darkness()
	_build_fallen_blocks(terrain, world, facing)
	_build_marker()

	# Sin descubrir no se dibuja nada
	visible = false


## La oscuridad del interior. Es lo ÚNICO que representa la cueva.
##
## Va hundida en la entalladura y con la boca por debajo del labio del terreno,
## de modo que su silueta la recorta la propia ladera. Eso es lo que hace que
## se lea como hueco y no como bulto: no se ve dónde acaba la geometría.
func _build_darkness() -> void:
	var throat := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	# Achatada y alargada hacia dentro: la sección de una galería no es
	# circular, es más ancha que alta
	mesh.radius = mouth_radius
	mesh.height = mouth_radius * 1.3
	throat.mesh = mesh
	throat.scale = Vector3(1.15, 0.78, 2.1)
	# Metida en el monte y un poco por debajo del punto de referencia, para
	# que el borde superior quede tapado por el terreno
	throat.position = Vector3(0.0, -mouth_radius * 0.30, -mouth_radius * 0.55)

	var material := StandardMaterial3D.new()
	# Casi negro pero no negro puro: el negro puro se lee como un agujero en el
	# render, no como una boca en sombra
	material.albedo_color = Color(0.030, 0.028, 0.027)
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Sin luz: dentro de una cueva no entra el sol, y dejar que la ilumine el
	# direccional la volvía gris y plana
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	throat.material_override = material
	add_child(throat)


## Bloques desprendidos al pie de la boca.
##
## No es decoración: toda cueva kárstica tiene su caos de bloques, y visualmente
## son lo que rompe el borde limpio del hueco. Son cantos irregulares, con
## escala y giro al azar, para que en ningún caso se lean como sillería.
func _build_fallen_blocks(terrain: TerrainGenerator, world: Vector3,
		facing: Vector3) -> void:
	for i in range(7):
		var block := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var size := _rng.randf_range(0.9, 2.6)
		mesh.radius = size
		mesh.height = size * 2.0
		# Pocos segmentos: un canto no es una esfera lisa, y facetado grande
		# le da aristas de roca partida
		mesh.radial_segments = 6
		mesh.rings = 3
		block.mesh = mesh

		# Repartidos en el abanico de delante de la boca
		var spread := _rng.randf_range(0.6, 2.4) * mouth_radius
		var lateral := _rng.randf_range(-1.0, 1.0) * mouth_radius * 1.1
		var spot := world + facing * spread + Vector3(-facing.z, 0.0, facing.x) * lateral
		var ground := terrain.get_height_at(spot)

		block.position = to_local(Vector3(spot.x, ground + size * 0.35, spot.z))
		block.rotation = Vector3(
			_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		block.scale = Vector3(
			_rng.randf_range(0.7, 1.4), _rng.randf_range(0.5, 0.9),
			_rng.randf_range(0.7, 1.4))

		var material := StandardMaterial3D.new()
		# Caliza cantábrica: gris con una punta de ocre, no gris de cemento
		var brightness := _rng.randf_range(0.42, 0.58)
		material.albedo_color = Color(
			brightness * 1.03, brightness * 0.99, brightness * 0.90)
		material.roughness = 0.97
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		block.material_override = material
		add_child(block)


## Señal sobre la boca, para que una cueva encontrada se localice de lejos.
##
## Va por encima del terreno y sin prueba de profundidad, o sea que se ve
## aunque la tape una loma: es una marca del jugador sobre su mapa, no un
## objeto del mundo, y su trabajo es que no se pierda lo que ya se encontró.
func _build_marker() -> void:
	_marker = Node3D.new()
	add_child(_marker)

	var beacon := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 2.4
	mesh.height = 9.0
	beacon.mesh = mesh
	# Punta hacia abajo, señalando la boca
	beacon.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	beacon.position = Vector3(0.0, mouth_radius * 2.6, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.86, 0.42)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	beacon.material_override = material
	_marker.add_child(beacon)

	var name_text := String(feature.get("name", ""))
	if name_text.is_empty() or name_text == "sin nombre":
		name_text = "Cavidad"

	var label := Label3D.new()
	label.text = name_text
	label.position = Vector3(0.0, mouth_radius * 3.6, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	label.pixel_size = 0.05
	label.modulate = Color(1.0, 0.92, 0.70)
	label.outline_size = 12
	_marker.add_child(label)


## Marca la cueva como encontrada. Solo va en un sentido: lo hallado no se
## vuelve a perder.
func discover() -> void:
	if discovered:
		return
	discovered = true
	visible = true


## Punto por el que se pincha, y radio de acierto en metros
func pick_position() -> Vector3:
	return _mouth_position + Vector3(0.0, mouth_radius * 0.4, 0.0)


func pick_radius() -> float:
	return mouth_radius * 2.2
