class_name SepulturasView
extends Node3D
## Las tumbas de la banda sobre el terreno: un túmulo de piedras donde se cubrió
## a alguien, y el mismo con una losa de ocre encima donde se le enterró con
## ajuar.
##
## Frente 27 de EPOCA_01 §10.1, tanda 4: «el lugar queda en el mapa; la
## sepultura se ve sobre el terreno y la banda sabe dónde están sus muertos».
## Sólo LEE [Sepulturas.tumbas]: la vista no decide nada (SPECS §4.7).

## Cuántas piedras lleva un túmulo, y de qué tamaño, en metros. Decisión de la
## captura: lo bastante para leerse como montón hecho a mano a la distancia de
## gestión, sin pasar de lo que una banda apila en una tarde.
const PIEDRAS := 9
const PIEDRA := 0.55

## Cuántas tumbas había la última vez, para no rehacerlas cada jornada.
var _hechas: int = -1


## Repinta si ha cambiado el número de tumbas. Se llama cada jornada; si no hay
## tumbas nuevas no cuesta nada.
func refresh(sepulturas: Sepulturas, terrain: TerrainGenerator) -> void:
	if sepulturas == null or terrain == null or sepulturas.tumbas.size() == _hechas:
		return
	_hechas = sepulturas.tumbas.size()
	for child: Node in get_children():
		child.queue_free()
	for tumba: Dictionary in sepulturas.tumbas:
		_tumulo(tumba, terrain)


## Un túmulo: piedras en corro que se amontonan hacia el centro.
func _tumulo(tumba: Dictionary, terrain: TerrainGenerator) -> void:
	var donde: Vector3 = tumba["donde"]
	var azar := RandomNumberGenerator.new()
	# Siempre igual para la misma tumba: por su sitio y su nombre.
	azar.seed = hash([int(donde.x), int(donde.z), String(tumba["nombre"])])

	var roca := CaveMouth.material_de_roca()
	for i in range(PIEDRAS):
		# Las primeras, en corro; las últimas, encima y hacia el centro.
		var alto := float(i) / float(PIEDRAS)
		var angulo := azar.randf() * TAU
		var radio := PIEDRA * 1.6 * (1.0 - alto)
		var sitio := donde + Vector3(cos(angulo) * radio, 0.0, sin(angulo) * radio)
		sitio.y = terrain.get_height_at(sitio) + PIEDRA * 0.3 + alto * PIEDRA * 1.2

		var piedra := MeshInstance3D.new()
		var forma := SphereMesh.new()
		forma.radius = PIEDRA * azar.randf_range(0.6, 1.0)
		forma.height = forma.radius * 1.3
		# Facetada: una esfera lisa se lee como bola, no como canto.
		forma.radial_segments = 6
		forma.rings = 3
		piedra.mesh = forma
		piedra.material_override = roca
		piedra.position = sitio
		piedra.rotation = Vector3(azar.randf() * 0.6, azar.randf() * TAU, azar.randf() * 0.6)
		add_child(piedra)

	# El ajuar se nota: una losa manchada de ocre encima.
	if int(tumba["despedida"]) == Sepulturas.Despedida.ENTERRAR:
		var losa := MeshInstance3D.new()
		var tabla := BoxMesh.new()
		tabla.size = Vector3(PIEDRA * 2.2, PIEDRA * 0.25, PIEDRA * 1.4)
		losa.mesh = tabla
		var ocre := StandardMaterial3D.new()
		ocre.albedo_color = Color(0.55, 0.24, 0.12)
		ocre.roughness = 1.0
		losa.material_override = ocre
		losa.position = donde + Vector3(0.0,
			terrain.get_height_at(donde) + PIEDRA * 1.8, 0.0)
		losa.rotation.y = azar.randf() * TAU
		add_child(losa)
