class_name ObrasDelAbrigo
extends Node3D
## Lo que la banda levanta en el abrigo, visto: secadero, paraviento, lavadero
## y los troncos del corro del fuego.
##
## La hoguera la pone [HearthFire] —es la primera obra y además arde, que es
## caso aparte—; esto es todo lo demás. Existían sólo como una casilla marcada
## en el panel: el jugador pagaba jornadas y material y el valle seguía igual.
## Queja del usuario del 2026-09-13: «el secadero, el paraviento y el lavadero
## no se ven en el terreno».
##
## **Cada pieza se apoya en SU suelo.** Preguntar la altura en un punto y plantar
## ahí una obra de dos metros la entierra por el lado de arriba en cuanto hay
## cuesta —que es lo que le pasaba a la hoguera—. Ver [asentar].

## Dónde va cada cosa, en metros:
##
## - el secadero, **encima de la hoguera**, que es de donde saca el humo;
## - el paraviento, **delante de la boca de la cueva**, que es el hueco que cierra;
## - el lavadero, **en la orilla más cercana**, que es donde se remoja la bellota.
##
## El secadero iba a 2,9 m a un lado del fuego: petición del usuario del
## 2026-09-14, «prácticamente encima» de la hoguera.
##
## **El paraviento, a 3,5 m del centro del pozo** —decisión del usuario del
## 2026-09-14, la segunda de ese día—. La primera fue «a 5–6 m del borde» y se
## midió desde un borde que no era: `CaveMouth.mouth_radius` vale 7 m fijos, y el
## pozo de verdad mide de 2 a 2,7 m de radio —[CaveMouth.hueco_de]—. Quedó a
## 12,5 m del centro y el usuario lo pidió a un cuarto. Se mide DESDE EL CENTRO,
## que es el único punto de la boca que no depende de ningún radio.
##
## Las horquillas del secadero se abren lo justo para no pisar el corro de
## piedras: [Bonfire.RING_RADIUS] y un palmo.
const HORQUILLAS_DEL_SECADERO := Bonfire.RING_RADIUS + 0.25
const PARAVIENTO_DESDE_EL_CENTRO := 3.5

var _sim: SettlementSim
var _terrain: TerrainGenerator

## Dónde va cada obra. Lo decide quien monta la escena, que es el único que sabe
## dónde cae la boca de la cueva y dónde el río.
var _campa: Vector3 = Vector3.ZERO
var _boca: Vector3 = Vector3.ZERO
var _mirando: Vector3 = Vector3.FORWARD
var _orilla: Vector3 = Vector3.ZERO

## Lo que hay plantado ahora mismo, por obra, para no rehacerlo cada fotograma.
var _puesto: Dictionary = {}
var _troncos: Node3D = null


func setup(sim: SettlementSim, terrain: TerrainGenerator, campa: Vector3,
		boca: Vector3, mirando: Vector3, orilla: Vector3) -> void:
	_sim = sim
	_terrain = terrain
	_campa = campa
	_boca = boca
	# Si ya estaban puestas —la banda se ha mudado—, se plantan otra vez en el
	# sitio nuevo.
	for obra: Node in _puesto.values():
		obra.queue_free()
	_puesto.clear()
	if _troncos != null:
		_troncos.queue_free()
		_troncos = null
	_mirando = mirando if mirando.length() > 0.01 else Vector3.FORWARD
	_orilla = orilla
	revisar()


## Planta una obra de `radio` metros de ancho SIGUIENDO LA PENDIENTE: apoyada en
## la altura de su centro e inclinada con el plano que hace el terreno bajo su
## huella, girada `rumbo` radianes sobre sí misma.
##
## Es la tercera forma, y las dos anteriores fallaban por un lado cada una. Con la
## altura del centro y la obra derecha, en cuesta se enterraba por arriba: la
## «hoguera medio metida en la tierra» del 2026-09-13. Con el punto MÁS ALTO de
## la huella dejó de enterrarse y se puso a volar por el lado de abajo: «los
## modelos están flotando sobre el terreno; si hay pendiente, deben seguir la
## pendiente», queja del usuario del 2026-09-14. Inclinada con el plano, lo que
## sube por un lado baja por el otro y la base toca el suelo en toda la huella.
static func asentar(nodo: Node3D, terrain: TerrainGenerator, centro: Vector3,
		radio: float, rumbo: float = 0.0) -> void:
	var punto := centro
	var arriba := Vector3.UP
	if terrain != null:
		punto.y = terrain.get_height_at(centro)
		arriba = normal_del_suelo(terrain, centro, radio)
	nodo.position = punto
	nodo.basis = Basis(Quaternion(Vector3.UP, arriba)) * Basis(Vector3.UP, rumbo)


## La normal del plano del terreno bajo una huella de `radio` metros.
##
## Por diferencias entre bordes opuestos de la huella, no por la normal de la
## celda de la malla: una obra de dos metros se apoya en lo que hay bajo sus dos
## metros, no en el triángulo que caiga en su centro.
static func normal_del_suelo(terrain: TerrainGenerator, centro: Vector3,
		radio: float) -> Vector3:
	var r := maxf(radio, 0.5)
	var dx := (terrain.get_height_at(centro + Vector3(r, 0.0, 0.0))
		- terrain.get_height_at(centro - Vector3(r, 0.0, 0.0))) / (2.0 * r)
	var dz := (terrain.get_height_at(centro + Vector3(0.0, 0.0, r))
		- terrain.get_height_at(centro - Vector3(0.0, 0.0, r))) / (2.0 * r)
	return Vector3(-dx, 1.0, -dz).normalized()


## Cada cuánto se mira si hay obra nueva, en segundos. Una obra tarda jornadas
## en levantarse: mirarlo sesenta veces por segundo sería recorrer la lista de
## obras para nada.
const CADA := 0.5

var _desde := 0.0


func _process(delta: float) -> void:
	_desde += delta
	if _desde < CADA:
		return
	_desde = 0.0
	revisar()


## El trozo MÁS LLANO cerca de un punto, para plantar ahí lo que tenga huella
## ancha.
##
## Es la otra mitad del arreglo de la hoguera enterrada. Apoyar bien una cosa en
## una cuesta no se puede: o se entierra por arriba o vuela por abajo. Lo que se
## hace de verdad es buscar el rellano, que es lo que hace cualquiera antes de
## delimitar una fogata con piedras. Se mira el desnivel de la huella en unos
## cuantos sitios alrededor y gana el menor; a igualdad, el más cercano.
static func asiento_llano(terrain: TerrainGenerator, centro: Vector3,
		radio: float, busqueda: float = 6.0) -> Vector3:
	if terrain == null:
		return centro
	var mejor := centro
	var menor := _desnivel(terrain, centro, radio)
	for anillo: float in [busqueda * 0.5, busqueda]:
		for rumbo in range(8):
			var angulo := TAU * float(rumbo) / 8.0
			var punto := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * anillo
			# Y EN SECO: el rellano más llano de una orilla es la lámina del
			# agua. «Las obras del hogar no se pueden hacer en el río»
			# (2026-09-14).
			if not Bocas._explanada_seca(terrain, punto):
				continue
			var cuanto := _desnivel(terrain, punto, radio)
			# Con margen: un rellano que gana por un centímetro no compensa
			# alejar la hoguera de la boca.
			if cuanto < menor - 0.05:
				menor = cuanto
				mejor = punto
	mejor.y = terrain.get_height_at(mejor)
	return mejor


## Cuánto sube y baja el terreno en la huella de una obra, en metros.
static func _desnivel(terrain: TerrainGenerator, centro: Vector3, radio: float) -> float:
	var alto := terrain.get_height_at(centro)
	var bajo := alto
	for i in range(8):
		var angulo := TAU * float(i) / 8.0
		var cota := terrain.get_height_at(
			centro + Vector3(cos(angulo), 0.0, sin(angulo)) * radio)
		alto = maxf(alto, cota)
		bajo = minf(bajo, cota)
	return alto - bajo


## Pasa revista a lo levantado y planta lo que falte. Se llama de tarde en
## tarde: las obras se levantan una vez, no una vez por fotograma.
func revisar() -> void:
	if _sim == null:
		return
	_revisar_troncos()
	for kind: int in CampProjects.all():
		if kind == CampProjects.Kind.HOGAR:
			continue  # lo pone [HearthFire]
		var levantada: bool = _sim.camp_built.get(kind, false)
		if levantada == _puesto.has(kind):
			continue
		if not levantada:
			(_puesto[kind] as Node).queue_free()
			_puesto.erase(kind)
			continue
		var obra := _levantar(kind as CampProjects.Kind)
		if obra != null:
			add_child(obra)
			_puesto[kind] = obra


## Los troncos del corro salen con el hogar: son de sentarse al fuego.
func _revisar_troncos() -> void:
	var hay: bool = _sim.camp_built.get(CampProjects.Kind.HOGAR, false) \
		and _campa != Vector3.ZERO
	if hay == (_troncos != null):
		return
	if not hay:
		_troncos.queue_free()
		_troncos = null
		return
	_troncos = Node3D.new()
	_troncos.name = "TroncosDelCorro"
	add_child(_troncos)
	var corteza := StandardMaterial3D.new()
	corteza.albedo_color = Color(0.30, 0.22, 0.14)
	corteza.roughness = 1.0
	var leno := CylinderMesh.new()
	leno.top_radius = CorroDelHogar.GRUESO * 0.5
	leno.bottom_radius = CorroDelHogar.GRUESO * 0.5
	leno.height = CorroDelHogar.LARGO
	leno.radial_segments = 8
	for tronco: Dictionary in CorroDelHogar.troncos(_campa):
		var node := MeshInstance3D.new()
		node.mesh = leno
		node.material_override = corteza
		# Tumbado y atravesado al radio: se mira al fuego sentado de lado al leño.
		# Y tendido en la cuesta, no horizontal: ver [asentar].
		asentar(node, _terrain, tronco["pos"] as Vector3, CorroDelHogar.LARGO * 0.5,
			-float(tronco["angulo"]))
		node.position += node.basis.y * (CorroDelHogar.GRUESO * 0.5)
		node.basis = node.basis * Basis(Vector3.RIGHT, deg_to_rad(90.0))
		_troncos.add_child(node)


## El filo del agua más cercano a un punto de la ribera, o el mismo punto si no
## se encuentra cauce. Se para UN PASO antes del agua: el cesto se cala desde la
## orilla, no se tira al medio del río.
func _al_borde_del_agua(desde: Vector3) -> Vector3:
	if _terrain == null:
		return desde
	for radio in range(2, 26, 2):
		for rumbo in range(16):
			var angulo := TAU * float(rumbo) / 16.0
			var punto := desde + Vector3(cos(angulo), 0.0, sin(angulo)) * float(radio)
			if _terrain.crossing_difficulty_at(punto) <= Hydrography.HAY_AGUA:
				continue
			# Agua: el cesto va un metro por detrás, en el filo.
			return desde + Vector3(cos(angulo), 0.0, sin(angulo)) \
				* maxf(float(radio) - 1.0, 0.0)
	return desde


func _levantar(kind: CampProjects.Kind) -> Node3D:
	match kind:
		CampProjects.Kind.SECADERO:
			return _secadero()
		CampProjects.Kind.PARAVIENTO:
			return _paraviento()
		CampProjects.Kind.LAVADERO:
			return _lavadero()
	return null


## El secadero: dos horquillas, un palo atravesado y las tiras colgando. Va
## encima de la hoguera porque lo que cura es SU humo —ver [Hogar._smoke_the_larder]
## y `HORQUILLAS_DEL_SECADERO`—.
func _secadero() -> Node3D:
	var nodo := Node3D.new()
	nodo.name = "Secadero"
	# A horcajadas del fuego, con el travesaño cruzado a lo ancho de la boca: las
	# tiras cuelgan en la columna de humo.
	var mirada := _mirando.normalized()
	asentar(nodo, _terrain, _campa, HORQUILLAS_DEL_SECADERO,
		atan2(mirada.x, mirada.z))
	var abierto := HORQUILLAS_DEL_SECADERO

	var palo := StandardMaterial3D.new()
	palo.albedo_color = Color(0.34, 0.25, 0.16)
	palo.roughness = 1.0
	var vara := CylinderMesh.new()
	vara.top_radius = 0.05
	vara.bottom_radius = 0.06
	vara.height = 1.7
	vara.radial_segments = 6

	for lado in [-1.0, 1.0]:
		var horquilla := MeshInstance3D.new()
		horquilla.mesh = vara
		horquilla.material_override = palo
		horquilla.position = Vector3(lado * abierto, 0.85, 0.0)
		nodo.add_child(horquilla)

	var travesano := MeshInstance3D.new()
	var largo := CylinderMesh.new()
	largo.top_radius = 0.045
	largo.bottom_radius = 0.045
	largo.height = abierto * 2.0 + 0.3
	largo.radial_segments = 6
	travesano.mesh = largo
	travesano.material_override = palo
	travesano.position = Vector3(0.0, 1.62, 0.0)
	travesano.rotation = Vector3(0.0, 0.0, deg_to_rad(90.0))
	nodo.add_child(travesano)

	# Las tiras colgadas: es lo que dice de un vistazo que el secadero ESTÁ
	# trabajando, y lo que lo distingue de dos palos clavados.
	var tira := StandardMaterial3D.new()
	tira.albedo_color = Color(0.55, 0.27, 0.20)
	tira.roughness = 0.9
	tira.cull_mode = BaseMaterial3D.CULL_DISABLED
	var lonja := BoxMesh.new()
	lonja.size = Vector3(0.16, 0.52, 0.02)
	for i in range(7):
		var cacho := MeshInstance3D.new()
		cacho.mesh = lonja
		cacho.material_override = tira
		cacho.position = Vector3(lerpf(-abierto + 0.3, abierto - 0.3, float(i) / 6.0),
			1.32, 0.0)
		nodo.add_child(cacho)
	return nodo


## El paraviento: un armazón con las pieles tensadas, atravesado en la boca de
## la cueva. Cierra el hueco por el que entra el viento, así que va donde está
## ese hueco y mirando como mira la boca.
func _paraviento() -> Node3D:
	var nodo := Node3D.new()
	nodo.name = "Paraviento"
	var mirada := _mirando.normalized()
	var centro := _boca + mirada * PARAVIENTO_DESDE_EL_CENTRO
	asentar(nodo, _terrain, centro, 1.6, atan2(mirada.x, mirada.z))

	var piel := StandardMaterial3D.new()
	piel.albedo_color = Color(0.52, 0.40, 0.28)
	piel.roughness = 1.0
	piel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var pano := BoxMesh.new()
	pano.size = Vector3(3.2, 1.6, 0.06)
	var lienzo := MeshInstance3D.new()
	lienzo.mesh = pano
	lienzo.material_override = piel
	lienzo.position = Vector3(0.0, 0.82, 0.0)
	# Vencido hacia dentro, como una piel tensada que no está tirante del todo.
	lienzo.rotation.x = deg_to_rad(6.0)
	nodo.add_child(lienzo)

	var palo := StandardMaterial3D.new()
	palo.albedo_color = Color(0.30, 0.22, 0.14)
	palo.roughness = 1.0
	var poste := CylinderMesh.new()
	poste.top_radius = 0.06
	poste.bottom_radius = 0.08
	poste.height = 1.9
	poste.radial_segments = 6
	for lado in [-1.6, 0.0, 1.6]:
		var vara := MeshInstance3D.new()
		vara.mesh = poste
		vara.material_override = palo
		vara.position = Vector3(lado, 0.95, 0.06)
		nodo.add_child(vara)
	return nodo


## El lavadero: el cesto de bellota metido en el remanso, sujeto con piedras. Va
## en la ORILLA, no en el campamento: la bellota se desamarga en agua corriente
## —ver [Hogar] y `docs/SISTEMAS.md`, el lavadero— y por eso lo pone donde está
## el agua quien monta la escena.
func _lavadero() -> Node3D:
	var nodo := Node3D.new()
	nodo.name = "Lavadero"
	# AL BORDE DEL AGUA, no al sitio desde el que se coge agua. El punto que da
	# `Tajo._shore_near` vale para mandar a alguien a llenar odres —cuenta como
	# orilla lo que tiene cauce a veinte metros— y ahí un cesto de remojo se
	# queda en mitad del prado. Aquí se busca el filo.
	var donde := _al_borde_del_agua(_orilla if _orilla != Vector3.ZERO else _campa)
	# Calado en la orilla y ladeado con ella hacia el cauce. Ver [asentar].
	asentar(nodo, _terrain, donde, 0.7)

	var mimbre := StandardMaterial3D.new()
	mimbre.albedo_color = Color(0.58, 0.46, 0.26)
	mimbre.roughness = 1.0
	var cesto := CylinderMesh.new()
	cesto.top_radius = 0.55
	cesto.bottom_radius = 0.42
	cesto.height = 0.6
	cesto.radial_segments = 10
	var pieza := MeshInstance3D.new()
	pieza.mesh = cesto
	pieza.material_override = mimbre
	# Medio hundido: es un cesto calado en el agua, no una cesta en la hierba.
	pieza.position = Vector3(0.0, 0.18, 0.0)
	nodo.add_child(pieza)

	var canto := StandardMaterial3D.new()
	canto.albedo_color = Color(0.44, 0.42, 0.39)
	canto.roughness = 0.95
	var piedra := SphereMesh.new()
	piedra.radius = 0.24
	piedra.height = 0.34
	piedra.radial_segments = 8
	piedra.rings = 4
	for i in range(4):
		var angulo := TAU * float(i) / 4.0 + 0.4
		var node := MeshInstance3D.new()
		node.mesh = piedra
		node.material_override = canto
		node.position = Vector3(cos(angulo) * 0.72, 0.12, sin(angulo) * 0.72)
		nodo.add_child(node)
	return nodo
