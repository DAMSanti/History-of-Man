class_name Aperos
## LAS OCHO COSAS QUE SE LLEVAN EN LA MANO.
##
## Qué especialidad lleva cuál lo dice [ClipsDeLaBanda]; aquí sólo está la forma y cómo se
## empuña. Cuelgan de un `BoneAttachment3D` en el hueso `hand_r`, así que siguen la mano de
## verdad — antes de tener esqueleto había que hornear la pose de la mano fotograma a
## fotograma, que era una muleta.
##
## **Dos salen de un pack CC0 y seis se componen.** Del «Fantasy Props MegaKit» de
## Quaternius sirven el cuchillo de mesa —hace de buril— y el hachón —hace de tea—. Los
## demás se componen aquí, y no por capricho: **lo que se bajó primero no decía lo que era**.
## La «piedra de afilar» resultó ser una rueda de molino con su bancada; el cubo de madera se
## leía como un escudo y el rollo de cuerda, como una cuerda. Los tres los cazó el usuario o
## una captura. Una punta de sílex enmangada, además, no existe en ningún pack libre: no es
## un objeto medieval.
##
## Ver `docs/CREDITOS.md`.

const PROPS := "res://models/props/aperos/%s.gltf"

## Cuánto mide cada uno de largo, en metros, para llevar el modelo del pack a su tamaño. Se
## escala por la caja medida, no por un número a ojo: los props vienen en su propia escala.
const LARGO := {
	"buril": 0.14,
	"tea": 0.60,
}

## De qué pack sale cada uno. Los que no están aquí se componen en [_asta].
const DEL_PACK := {
	"buril": "Table_Knife",       ## Hoja estrecha: lo que ranura asta y hueso
	"tea": "Torch_Metal",
}

## Colores de los dos que se componen.
const MADERA := Color(0.36, 0.26, 0.17)
const SILEX := Color(0.38, 0.37, 0.36)
const MIMBRE := Color(0.62, 0.49, 0.26)
const ASTA := Color(0.86, 0.82, 0.70)


## El apero montado y ya a su tamaño, o `null` si el nombre no es de los ocho.
static func montar(nombre: String) -> Node3D:
	if DEL_PACK.has(nombre):
		return _del_pack(nombre)
	if nombre == "percutor":
		# Un canto de río. El pack tiene una «piedra de afilar», pero resultó ser una rueda
		# de molino con su bancada: se vio en captura y se cambió por una primitiva.
		return _piedra(Vector3(0.10, 0.075, 0.085), SILEX)
	if nombre == "raspador":
		# Una lasca ancha y plana, que es lo que se ve de canto mientras se raspa.
		return _piedra(Vector3(0.075, 0.016, 0.055), SILEX)
	if nombre == "cesto":
		# El cubo de madera del pack se leía como un ESCUDO —tabla plana colgando del brazo—
		# y el rollo de cuerda, como una cuerda: los dos los vio el usuario y ninguno era lo
		# que decían ser (2026-09-18). Un canasto es un tronco de cono abierto, y eso sí se
		# lee de lejos.
		return _canasto()
	if nombre == "haz":
		return _fajo()
	if nombre == "azagaya":
		return _asta(1.75, 0.011, MADERA, 0.14, SILEX)
	if nombre == "arpon":
		# Más corto y de asta, para que no se confunda con la azagaya a la distancia de
		# juego: es lo único que separa a un pescador de un cazador cuando los dos miden
		# cuarenta píxeles.
		return _asta(1.15, 0.013, ASTA, 0.17, ASTA)
	return null


## CÓMO SE EMPUÑA cada uno, en el espacio del hueso de la mano.
##
## El hueso tiene su **Y a lo largo del brazo, hacia los dedos** —se comprobó en captura, no
## se supuso—, así que una vara agarrada sale derecha sin girar nada: lo único que hace falta
## es correrla para que el puño caiga por detrás del medio, que es por donde se lleva una
## azagaya. El primer intento la giraba 90° «para tumbarla» y salía clavada en el suelo.
static func agarre(nombre: String) -> Transform3D:
	match nombre:
		"azagaya":
			return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.40, 0.0))
		"arpon":
			return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.28, 0.0))
		"tea":
			return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.20, 0.0))
		"haz":
			# El rollo cuelga de la mano, atravesado.
			return Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0.0, -0.10, 0.0))
		"cesto":
			# Colgando: el asa en la mano y el canasto debajo.
			return Transform3D(Basis.IDENTITY, Vector3(0.0, -0.22, 0.0))
	return Transform3D.IDENTITY


## Un modelo del pack, escalado por su caja al largo que le toca.
static func _del_pack(nombre: String) -> Node3D:
	var escena: PackedScene = load(PROPS % DEL_PACK[nombre])
	if escena == null:
		push_error("Aperos: falta el modelo de «%s»" % nombre)
		return null
	var raiz := escena.instantiate() as Node3D
	var caja := AABB()
	var primera := true
	for m in CatalogoDeCuerpos.mallas(raiz):
		var a: AABB = (m as MeshInstance3D).get_aabb()
		caja = a if primera else caja.merge(a)
		primera = false
	var mayor := maxf(maxf(caja.size.x, caja.size.y), caja.size.z)
	if mayor > 0.0001:
		raiz.scale = Vector3.ONE * (float(LARGO[nombre]) / mayor)
	return raiz


## Un canasto de mimbre: tronco de cono abierto por arriba, más ancho que alto.
static func _canasto() -> Node3D:
	var raiz := Node3D.new()
	var cesta := CylinderMesh.new()
	cesta.top_radius = 0.155
	cesta.bottom_radius = 0.105
	cesta.height = 0.24
	cesta.radial_segments = 9
	cesta.rings = 0
	cesta.material = _material(MIMBRE)
	var nodo := MeshInstance3D.new()
	nodo.mesh = cesta
	raiz.add_child(nodo)
	return raiz


## Un haz de leña: cuatro palos atados, abiertos en abanico. Un solo cilindro parecía un
## tronco y el rollo del pack parecía una maroma; lo que dice «leña» son varios palos.
static func _fajo() -> Node3D:
	var raiz := Node3D.new()
	var palo := CylinderMesh.new()
	palo.top_radius = 0.022
	palo.bottom_radius = 0.026
	palo.height = 0.78
	palo.radial_segments = 5
	palo.rings = 0
	palo.material = _material(MADERA)
	var sitios := [Vector3(0.0, 0.0, 0.0), Vector3(0.045, 0.0, 0.02),
		Vector3(-0.04, 0.0, 0.03), Vector3(0.01, 0.0, -0.045)]
	var giros := [0.0, 0.05, -0.06, 0.03]
	for i in range(sitios.size()):
		var uno := MeshInstance3D.new()
		uno.mesh = palo
		uno.position = sitios[i]
		uno.rotation.z = giros[i]
		raiz.add_child(uno)
	return raiz


## Una piedra: el percutor y el raspador, que son dos bultos de sílex y no hace falta más.
static func _piedra(tamano: Vector3, color: Color) -> Node3D:
	var raiz := Node3D.new()
	var caja := BoxMesh.new()
	caja.size = tamano
	caja.material = _material(color)
	var nodo := MeshInstance3D.new()
	nodo.mesh = caja
	raiz.add_child(nodo)
	return raiz


## Un astil con su punta: la azagaya y el arpón, que ningún pack libre trae.
static func _asta(largo: float, grueso: float, color_astil: Color,
		punta: float, color_punta: Color) -> Node3D:
	var raiz := Node3D.new()
	var vara := CylinderMesh.new()
	vara.top_radius = grueso * 0.8
	vara.bottom_radius = grueso
	vara.height = largo
	vara.radial_segments = 6
	vara.rings = 0
	vara.material = _material(color_astil)
	var palo := MeshInstance3D.new()
	palo.mesh = vara
	raiz.add_child(palo)

	# La punta es un cono, que a esta distancia es lo que dice «esto atraviesa algo».
	var filo := CylinderMesh.new()
	filo.top_radius = 0.0
	filo.bottom_radius = grueso * 2.2
	filo.height = punta
	filo.radial_segments = 4
	filo.rings = 0
	filo.material = _material(color_punta)
	var cabeza := MeshInstance3D.new()
	cabeza.mesh = filo
	cabeza.position = Vector3(0.0, (largo + punta) * 0.5, 0.0)
	raiz.add_child(cabeza)
	return raiz


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	# Rugoso y nada metálico: son madera, asta y piedra.
	material.roughness = 0.9
	material.metallic = 0.0
	return material
