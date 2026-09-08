class_name Tienda
extends Node3D
## La tienda del vivac: pieles sobre un armazón de varas.
##
## La simulación llevaba cobrándola desde siempre —[SettlementSim.VIVAC_PIEL],
## una piel por salida, y [Despensa] mira si el que sale la lleva encima antes
## de dejarle dormir fuera— y no se dibujaba NADA. En pantalla, el que se había
## cargado con una piel de doce kilos y el que salió a pelo dormían igual: una
## hoguera y un cuerpo tumbado. Y son dos noches muy distintas, que es
## exactamente lo que [Percances] cobra al día siguiente.
##
## Es un abrigo de una vertiente —un paraviento, no un tipi—, que es lo que se
## arma en una noche con lo que se lleva a la espalda: tres varas, una cumbrera
## y la piel tirante encima, anclada con cantos. El tipi de varas largas es de
## cazadores de llanura con perros de carga; aquí, en un valle cantábrico y a
## pie, lo que se monta es esto.

## Alto de la cumbrera, en metros. Un paraviento no se levanta más: cuanto más
## alto, más viento coge y más piel hace falta.
const ALTO := 1.35

## Fondo del abrigo, de la boca a la trasera.
const FONDO := 1.9

## Ancho de la boca.
const ANCHO := 2.2

## Grosor de las varas.
const VARA := 0.045

## Cuántos cantos sujetan el faldón. Es lo que se hace: no se clava nada, se
## lastra el borde con lo que hay en el suelo.
const CANTOS := 7

var _rng := RandomNumberGenerator.new()


## Arma la tienda. `seed_value` la hace distinta de la de al lado sin que
## ninguna sea aleatoria entre arranques.
func build(seed_value: int = 20260908, factor: float = 1.0) -> void:
	_rng.seed = seed_value
	_armazon()
	_piel()
	_lastre()
	scale = Vector3.ONE * factor


## Las varas: dos horquillas delante y la cumbrera apoyada en ellas, cayendo
## hasta el suelo por detrás.
func _armazon() -> void:
	var madera := StandardMaterial3D.new()
	madera.albedo_color = Color(0.38, 0.29, 0.19)
	madera.roughness = 1.0

	var palo := CylinderMesh.new()
	palo.top_radius = VARA * 0.8
	palo.bottom_radius = VARA
	palo.height = ALTO
	palo.radial_segments = 5

	for lado: float in [-1.0, 1.0]:
		var horquilla := MeshInstance3D.new()
		horquilla.name = "Horquilla"
		horquilla.mesh = palo
		horquilla.material_override = madera
		horquilla.position = Vector3(lado * ANCHO * 0.5, ALTO * 0.5, 0.0)
		# Abiertas hacia fuera: una vara vertical se cae con el primer tirón de
		# la piel, y quien ha armado un paraviento las abre sin pensarlo.
		horquilla.rotation.z = deg_to_rad(-lado * 7.0)
		add_child(horquilla)

	var cumbrera := MeshInstance3D.new()
	cumbrera.name = "Cumbrera"
	var travesano := CylinderMesh.new()
	travesano.top_radius = VARA
	travesano.bottom_radius = VARA
	travesano.height = ANCHO * 1.06
	travesano.radial_segments = 5
	cumbrera.mesh = travesano
	cumbrera.material_override = madera
	cumbrera.position = Vector3(0.0, ALTO, 0.0)
	cumbrera.rotation.z = deg_to_rad(90.0)
	add_child(cumbrera)


## El faldón de piel: un plano de la cumbrera al suelo, por detrás.
##
## Se hace a mano y no con un [PlaneMesh] porque una piel tirante NO es plana:
## se hunde entre los puntos de anclaje, igual que en la interfaz. Ver
## [PielTensada], que resuelve lo mismo en dos dimensiones.
func _piel() -> void:
	var filas := 5
	var columnas := 7
	var malla := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for f in range(filas + 1):
		var v := float(f) / float(filas)
		for c in range(columnas + 1):
			var u := float(c) / float(columnas)
			# De la cumbrera (v=0) al suelo de atrás (v=1).
			var x := (u - 0.5) * ANCHO * 1.04
			var y := ALTO * (1.0 - v)
			var z := -FONDO * v
			# La comba: máxima en el centro de cada tramo y nula en los bordes,
			# que es donde la piel está sujeta.
			var comba := sin(PI * u) * sin(PI * v) * 0.10
			vertices.append(Vector3(x, y - comba, z + comba * 0.5))
			normales.append(Vector3(0.0, 0.82, 0.57).normalized())
			uvs.append(Vector2(u, v))

	for f in range(filas):
		for c in range(columnas):
			var a := f * (columnas + 1) + c
			var b := a + 1
			var d := a + columnas + 1
			var e := d + 1
			indices.append_array([a, d, b, b, d, e])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var cuero := StandardMaterial3D.new()
	cuero.albedo_color = Color(0.44, 0.33, 0.23)
	cuero.roughness = 0.92
	# Se ve por las dos caras: desde dentro del abrigo, una piel de una cara
	# desaparece y se ve el suelo a través del techo.
	cuero.cull_mode = BaseMaterial3D.CULL_DISABLED

	var faldon := MeshInstance3D.new()
	faldon.name = "Faldón"
	faldon.mesh = malla
	faldon.material_override = cuero
	add_child(faldon)

	_costados(cuero)


## Los dos costados, que son dos triángulos de piel de la cumbrera al suelo.
##
## Sin ellos el abrigo es una rampa —así salió en la lámina de `ObrasAtlas`, y
## por eso se ven las cosas juntas— y además sería un paraviento que no para el
## viento: la gracia de cerrar los lados es que sólo quede abierta la boca, que
## es la que mira al fuego.
func _costados(cuero: StandardMaterial3D) -> void:
	for lado: float in [-1.0, 1.0]:
		var x := lado * ANCHO * 0.52
		var malla := ArrayMesh.new()
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var v := PackedVector3Array([
			Vector3(x, ALTO, 0.0),       # la cumbrera, delante
			Vector3(x, 0.0, -FONDO),     # el suelo, detrás
			Vector3(x, 0.0, 0.0),        # el suelo, delante
		])
		# Que la normal mire hacia fuera en los dos lados.
		if lado < 0.0:
			v = PackedVector3Array([v[0], v[2], v[1]])
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
			Vector3(lado, 0.0, 0.0), Vector3(lado, 0.0, 0.0),
			Vector3(lado, 0.0, 0.0)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0.5, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
		malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var costado := MeshInstance3D.new()
		costado.name = "Costado"
		costado.mesh = malla
		costado.material_override = cuero
		add_child(costado)


## Los cantos que lastran el borde de atrás. No se clava nada: se pone encima
## lo que hay en el suelo, y por eso el faldón queda irregular.
func _lastre() -> void:
	var canto := SphereMesh.new()
	canto.radius = 0.13
	canto.height = 0.20
	canto.radial_segments = 6
	canto.rings = 3
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.40, 0.38, 0.35)
	piedra.roughness = 0.95

	for i in range(CANTOS):
		var u := float(i) / float(CANTOS - 1)
		var node := MeshInstance3D.new()
		node.mesh = canto
		node.material_override = piedra
		node.position = Vector3((u - 0.5) * ANCHO * 1.02, 0.06,
			-FONDO + _rng.randf_range(-0.06, 0.10))
		node.scale = Vector3.ONE * _rng.randf_range(0.7, 1.3)
		node.rotation.y = _rng.randf() * TAU
		add_child(node)
