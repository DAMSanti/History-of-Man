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
## Así que se quitó todo lo que sobresalía. La entalladura la excava el propio
## terreno (ver `_mark_cave_carvings`) y aquí sólo iba la oscuridad del interior,
## hundida en ella, más unos bloques desprendidos al pie. **Los bloques se
## quitaron el 2026-09-13** a petición del usuario: eran esferas facetadas y se
## leían como pedruscos redondos puestos en la puerta.
##
## Y el tercero fue ése: **no se veía**, y lo que se veía era una pieza puesta
## encima del prado. Por ahí pasaron una visera de caliza, una cámara abovedada y
## un túnel con su marco de bloques, y el usuario los fue tumbando uno a uno el
## 2026-09-13: «no se ven bien», «no tienen parte oscura donde se mete la banda»,
## «parece hecha por el hombre», «parece un túnel de tren».
##
## Lo que pidió, y lo que hay ahora:
##
## > «El agujero será real, en el propio terreno, abierto, a una cueva. El
## > terreno se abre y hace un agujero, y alrededor de ese agujero se pone el
## > elemento de las piedras, construyéndola de forma orgánica.»
##
## Así que la cueva son **dos cosas y ninguna más**:
##
## - **Un agujero en la malla del relieve.** Lo abre el propio terreno: los
##   cuadros que caen dentro no se dibujan. Ver [hueco_de],
##   [TerrainGenerator.aberturas] y [MallaDelTerreno._construir_arrays].
## - **Y las piedras**: un pozo oscuro que forra el agujero por debajo —no se ve
##   más que a través de él, y es donde se mete la banda: [inside_point]— y
##   bloques sueltos repartidos por el borde, cada uno de su tamaño y su ángulo,
##   medio enterrados.
##
## Ver [_build_cueva].

## Datos del registro de este elemento, para la ventana de información
var feature: Dictionary = {}

## Qué cueva es, para la simulación: su índice en el catálogo del emplazamiento.
## Es lo que usa [Exploracion] para saber qué se ha explorado.
var id: int = -1

## Si la banda ya la ha encontrado. Mientras no, la cueva no se dibuja: no es
## que esté oculta, es que para el jugador todavía no existe.
var discovered: bool = false

var _marker: Node3D

## Radio del vano, en metros
var mouth_radius: float = 7.0

## A qué altura, respecto a la boca, queda el suelo de la cueva. Lo usa
## [inside_point]: la banda se mete AHÍ ABAJO, en lo oscuro.
var _suelo_de_la_cueva: float = -6.0

## El ancho de la boca de esta cueva, en metros. Ver [tamano_de].
var tamano: float = CUEVA_MINIMA

var _mouth_position: Vector3

## Hacia dónde mira la boca, en el plano. Ladera abajo, que es por donde se
## entra y por donde se sale. Lo usa la banda: ver `inside_point` y
## `forecourt_point`.
var _facing := Vector3(0.0, 0.0, 1.0)

var _rng := RandomNumberGenerator.new()


## Construye la boca en un punto del terreno, mirando ladera abajo.
func build(terrain: TerrainGenerator, world: Vector3, data: Dictionary) -> void:
	feature = data
	_mouth_position = world
	# Semilla estable por posición: la misma cueva sale igual entre partidas
	_rng.seed = int(world.x) * 73856093 ^ int(world.z) * 19349663
	tamano = tamano_de(data)

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

	_facing = facing

	_build_cueva(terrain, world)
	_build_marker()

	# LA PIEDRA SE VE SIEMPRE: la cueva está ahí aunque la banda no la haya
	# encontrado, y el agujero del relieve tampoco se esconde. Lo que aparece al
	# descubrirla es la marca con su nombre. Antes se ocultaba el nodo entero, que
	# con la cueva hecha de terreno dejaba un agujero sin una sola piedra.
	if _marker != null:
		_marker.visible = false


## LA CUEVA, entre 3 y 6 metros y distinta en cada una. Decisión del usuario del
## 2026-09-13: «más pequeña, de entre 3 y 6 metros, que varíe entre cuevas».
const CUEVA_MINIMA := 3.0
const CUEVA_MAXIMA := 6.0

## La boca de la sima no baja de esto. Ya no la limita la rejilla del relieve
## —el embudo se cose aparte, ver [MallaDelTerreno._construir_simas]—, así que
## puede ser tan pequeña como pidió el usuario el 2026-09-13: «incluso 2 m».
const HUECO_MINIMO := 2.0

## Lo que baja la sima. Cincuenta metros, decisión del usuario el 2026-09-13:
## «coge la entrada de la cueva y dale una profundidad de −50 m a la malla en esa
## zona, que sea como una sima». Antes se probó a QUITAR los cuadros de la malla
## —un agujero de verdad— y el recorte salía enorme y con los bordes rectos,
## porque el relieve va a cuadros de cinco metros.
const PROFUNDIDAD_DE_LA_SIMA := 50.0

## Lo que el borde del pozo se sale del agujero, para tapar por debajo el
## recorte de la malla, que va a cuadros.
const SOBRE_EL_BORDE := 3.0

## Lo que le sobra al suelo del pozo por cada lado sobre el reparto de la gente
## dentro —[SettlementSim.CAVE_SPREAD]—, para que nadie duerma metido en la roca.
const HOLGURA_DE_LA_CAMARA := 0.8


## El tamaño de una cueva. Sale de sus coordenadas y su nombre, así que la misma
## cueva es igual en cada partida y lo puede saber `DemoMain` —para abrir el
## agujero y excavar alrededor— antes de que exista el nodo.
static func tamano_de(data: Dictionary) -> float:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([snappedf(float(data.get("lat", 0.0)), 0.00001),
		snappedf(float(data.get("lon", 0.0)), 0.00001), String(data.get("name", ""))])
	return azar.randf_range(CUEVA_MINIMA, CUEVA_MAXIMA)


## El radio de la boca de la sima. Ver [entalladura_de].
static func hueco_de(data: Dictionary) -> float:
	return maxf(HUECO_MINIMO, tamano_de(data) * 0.45)


## La entalladura que le toca a una cueva: un solo sitio para las dos cifras, que
## las usa `DemoMain._mark_cave_carvings` y las mide [Bocas].
static func entalladura_de(data: Dictionary) -> Dictionary:
	# El relieve sólo pone la vaguada: el pozo lo hace el embudo cosido en la
	# malla, ver [MallaDelTerreno._construir_simas]. Hundir aquí los cincuenta
	# metros daba un cráter cuadrado del tamaño de la rejilla.
	return {"radius": hueco_de(data) * 4.0, "depth": 1.2}


## La cueva: el pozo oscuro bajo el agujero del terreno, y las piedras del borde.
##
## En coordenadas del nodo, y = 0 es el suelo de la boca y −Z mira ladera abajo
## (ver [build]).
## LA ENTRADA ROCOSA: grandes rocas que cubren la cueva por el lado de la
## pendiente y por los costados, y la entrada libre ladera abajo.
##
## El agujero no lo pone esto: lo abre el propio relieve —ver [hueco_de] y
## [MallaDelTerreno._construir_simas]—. Esto es la roca que lo cubre.
##
## Dos intentos tumbados antes de dar con esto, los dos el 2026-09-13: cantos
## repartidos por el corro («no debe haber pedruscos desperdigados») y un brocal
## cerrado alrededor de la boca. Lo que pidió el usuario es lo tercero: «la cueva
## estará cubierta por la parte de la pendiente por grandes rocas, y por los
## lados también, pero tendrá la entrada libre».
##
## Así que la roca es UNA PIEZA en herradura, abierta ladera abajo —el eje −Z del
## nodo, ver [build]—: vuela sobre el hueco por detrás y por los costados, sube en
## crestones y baja a ras de tierra por fuera, y tiene grueso, para que desde la
## entrada se vea el canto de la roca y no una lámina.
func _build_cueva(terrain: TerrainGenerator, world: Vector3) -> void:
	var roca_v := PackedVector3Array()
	var roca_n := PackedVector3Array()
	var roca_c := PackedColorArray()
	_techo(terrain, world, roca_v, roca_n, roca_c, hueco_de(feature))

	var malla := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = roca_v
	arrays[Mesh.ARRAY_NORMAL] = roca_n
	arrays[Mesh.ARRAY_COLOR] = roca_c
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	malla.surface_set_material(0, material_de_roca())

	var piedra := MeshInstance3D.new()
	piedra.name = "Entrada"
	piedra.mesh = malla
	add_child(piedra)


## Cuánto de la vuelta queda LIBRE para entrar, en grados, centrado ladera abajo.
## Ciento diez: un vano ancho, por el que se ve el fondo negro del pozo.
const VANO_DE_ENTRADA := 110.0

## Cuánto vuela la roca sobre el hueco, en proporción al radio de la boca. Es lo
## que le queda al labio JUNTO AL VANO; por detrás la roca cruza el hueco entero
## —ver [TAPA_POR_ARRIBA]— y lo cubre, que es lo que pidió el usuario: «que
## también esté tapado por arriba».
const VUELO_DEL_TECHO := 0.45

## Lo que queda sin cubrir en el fondo del techo, en proporción al radio: casi
## nada, para que desde arriba se vea roca y no el agujero abierto al cielo. La
## cueva se mira desde el vano, no desde el cielo.
const TAPA_POR_ARRIBA := 0.08

## Hasta dónde llega la roca por fuera, en radios de boca.
const ANCHO_DEL_TECHO := 2.6

## Cuánto se hunde la roca en la tierra por el borde de fuera, en metros: es lo
## que hace que no se vea dónde acaba.
const HUNDIDO_POR_FUERA := 1.2

## El grueso de la roca en el labio, en metros: es lo que se ve como canto desde
## la entrada, y lo que la aparta de parecer una lámina.
const GRUESO_DEL_TECHO := 1.1


## El techo de roca, corona a corona, en herradura alrededor del hueco.
func _techo(terrain: TerrainGenerator, world: Vector3, roca_v: PackedVector3Array,
		roca_n: PackedVector3Array, roca_c: PackedColorArray, boca: float) -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = _rng.randi()
	ruido.frequency = 0.9
	var crestas := FastNoiseLite.new()
	crestas.seed = _rng.randi()
	crestas.frequency = 0.4

	var lados := 26
	var anillos := 5
	# Ladera abajo es −Z, o sea el ángulo −90°: el vano se centra ahí, y la roca
	# ocupa el resto de la vuelta.
	var medio_vano := deg_to_rad(VANO_DE_ENTRADA) * 0.5
	var arranca := -PI * 0.5 + medio_vano
	var barre := TAU - deg_to_rad(VANO_DE_ENTRADA)

	var arriba: Array[Vector3] = []
	var abajo: Array[Vector3] = []
	for j in range(anillos + 1):
		var t := float(j) / float(anillos)
		for i in range(lados + 1):
			var angulo := arranca + barre * float(i) / float(lados)
			var seno := sin(angulo)
			var coseno := cos(angulo)
			var mordida := 1.0 + 0.25 * ruido.get_noise_2d(coseno * 4.0, seno * 4.0)
			var creston := maxf(0.0, crestas.get_noise_2d(coseno * 2.0, seno * 2.0))
			# EL LABIO SE METE MÁS CUANTO MÁS AL FONDO: junto al vano deja la
			# boca despejada, y en el fondo cruza el hueco y lo tapa.
			var al_fondo := sin(PI * float(i) / float(lados))
			var dentro := lerpf(1.0 - VUELO_DEL_TECHO, TAPA_POR_ARRIBA, al_fondo)
			var radio := lerpf(boca * dentro, boca * ANCHO_DEL_TECHO, t) * mordida
			var x := coseno * radio
			var z := seno * radio
			var suelo := _suelo_local(terrain, world, x, z)
			# Alta en el labio y en los crestones, y ENTERRADA por fuera. A ras
			# de tierra no vale: las dos superficies se peleaban por el mismo
			# píxel y la roca salía negra a manchas.
			var alto := (GRUESO_DEL_TECHO + boca * (0.35 + creston * 0.8)) \
				* (1.0 - smoothstep(0.0, 0.9, t)) - HUNDIDO_POR_FUERA * t
			arriba.append(Vector3(x, suelo + alto, z))
			# La cara de abajo: el canto de la roca en el labio, y por debajo de
			# la tierra según se aleja.
			abajo.append(Vector3(x, suelo + alto - GRUESO_DEL_TECHO, z))

	var fila := lados + 1
	for j in range(anillos):
		for i in range(lados):
			var a := j * fila + i
			var b := a + 1
			var d := a + fila
			var e := d + 1
			var medio := (arriba[a] + arriba[e]) * 0.5
			var luz := 0.95 + 0.12 * ruido.get_noise_3dv(medio * 0.4)
			var color := Color(luz, luz * 0.99, luz * 0.96)
			# Musgo en lo que mira al cielo por fuera, que es donde se agarra.
			if j >= anillos - 2 and _rng.randf() < 0.3:
				color = Color(luz * 0.72, luz * 0.82, luz * 0.52)
			_cara(roca_v, roca_n, roca_c, arriba[a], arriba[d], arriba[b],
				Vector3.UP, color)
			_cara(roca_v, roca_n, roca_c, arriba[b], arriba[d], arriba[e],
				Vector3.UP, color)
			# Y la cara de abajo, la que se ve desde el vano, más en sombra.
			var bajo := color * 0.55
			_cara(roca_v, roca_n, roca_c, abajo[a], abajo[d], abajo[b],
				Vector3.DOWN, bajo)
			_cara(roca_v, roca_n, roca_c, abajo[b], abajo[d], abajo[e],
				Vector3.DOWN, bajo)

	# El canto del labio, que es lo que se ve de frente al entrar, y los dos
	# testeros del vano, para que la roca no acabe en filo.
	for i in range(lados):
		var color := Color(0.88, 0.87, 0.84)
		_cara(roca_v, roca_n, roca_c, arriba[i], abajo[i], arriba[i + 1],
			arriba[i] - Vector3(0.0, arriba[i].y, 0.0), color)
		_cara(roca_v, roca_n, roca_c, arriba[i + 1], abajo[i], abajo[i + 1],
			arriba[i] - Vector3(0.0, arriba[i].y, 0.0), color)
	for lado: int in [0, lados]:
		for j in range(anillos):
			var a := j * fila + lado
			var d := a + fila
			var hacia := (arriba[a] - arriba[d]).cross(Vector3.UP)
			_cara(roca_v, roca_n, roca_c, arriba[a], arriba[d], abajo[d],
				hacia, Color(0.9, 0.89, 0.86))
			_cara(roca_v, roca_n, roca_c, arriba[a], abajo[d], abajo[a],
				hacia, Color(0.9, 0.89, 0.86))


## LA MISMA ROCA QUE EL MAPA. Las piedras de la boca salían de un color plano y
## se leían como bultos de plastilina —«primero debería ser roca», el usuario el
## 2026-09-13—, así que llevan la capa de roquedo calizo del terreno
## ([TerrainLayers.Layer.ROQUEDO], `Rock030`), mapeada por triplanar para que no
## haya que darle UV a cada canto.
##
## Es un solo material para todas las cuevas del mapa: la textura pesa y no hay
## por qué tener una copia por boca.
static var _roca: StandardMaterial3D = null


static func material_de_roca() -> StandardMaterial3D:
	if _roca != null:
		return _roca
	_roca = StandardMaterial3D.new()
	_roca.vertex_color_use_as_albedo = true
	_roca.roughness = 1.0
	_roca.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Por las dos caras: son cáscaras, y recortando las traseras se veían
	# «cortadas, como si les faltasen caras».
	_roca.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Triplanar en coordenadas de mundo: así dos piedras vecinas no repiten el
	# mismo trozo de textura y no hace falta desplegar UV.
	_roca.uv1_triplanar = true
	_roca.uv1_world_triplanar = true
	var capas: TerrainTextureArrays = load(TerrainLayers.ARRAYS_PATH)
	if capas != null and capas.is_usable():
		var i := int(TerrainLayers.Layer.ROQUEDO)
		if i < capas.albedo_images.size():
			# DESCOMPRIMIDA. Las capas del terreno se guardan comprimidas para la
			# GPU, y una `ImageTexture` hecha con la imagen comprimida tal cual
			# salía NEGRA —comprobado en captura el 2026-09-13—.
			var lamina: Image = capas.albedo_images[i].duplicate()
			if lamina.is_compressed():
				lamina.decompress()
			_roca.albedo_texture = ImageTexture.create_from_image(lamina)
		# SIN MAPA DE NORMALES: la malla de la roca no lleva tangentes —se arma a
		# mano, cara a cara— y sin ellas el mapa de normales deja la piedra
		# NEGRA. Con la textura de albedo basta para que parezca caliza.
		var tile: float = float(TerrainLayers.CATALOGUE[TerrainLayers.Layer.ROQUEDO]["tile_m"])
		_roca.uv1_scale = Vector3.ONE / maxf(tile, 0.1)
	else:
		push_warning("Sin texturas de terreno: las piedras de las cuevas van lisas")
	return _roca


## Altura del terreno bajo un punto del nodo, contada desde el suelo de la boca.
func _suelo_local(terrain: TerrainGenerator, world: Vector3, x: float, z: float) -> float:
	return terrain.get_height_at(global_transform * Vector3(x, 0.0, z)) - world.y


## Los doce vértices de un icosaedro: la base de cada bloque, que deformada al
## azar da una roca de caras planas y aristas vivas.
const _ICO_V := [
	Vector3(-1.0, 1.618, 0.0), Vector3(1.0, 1.618, 0.0), Vector3(-1.0, -1.618, 0.0),
	Vector3(1.0, -1.618, 0.0), Vector3(0.0, -1.0, 1.618), Vector3(0.0, 1.0, 1.618),
	Vector3(0.0, -1.0, -1.618), Vector3(0.0, 1.0, -1.618), Vector3(1.618, 0.0, -1.0),
	Vector3(1.618, 0.0, 1.0), Vector3(-1.618, 0.0, -1.0), Vector3(-1.618, 0.0, 1.0),
]
const _ICO_F := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
	[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8],
	[3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]


## Un bloque de caliza de `medida` metros, centrado en `donde`.
##
## Base aplastada —se asienta, no rueda— y vértices sacudidos hasta un tercio,
## que es lo que le quita la redondez: con menos se leía como la esfera facetada
## que el usuario llamó «pedrusco». Musgo en algunas caras que miran arriba.
func _bloque(roca_v: PackedVector3Array, roca_n: PackedVector3Array,
		roca_c: PackedColorArray, donde: Vector3, medida: Vector3) -> void:
	var giro := Basis(Vector3.UP, _rng.randf() * TAU) \
		* Basis(Vector3.RIGHT, _rng.randf_range(-0.5, 0.5)) \
		* Basis(Vector3.FORWARD, _rng.randf_range(-0.4, 0.4))
	var puntos: Array[Vector3] = []
	for v: Vector3 in _ICO_V:
		var p := v.normalized() * _rng.randf_range(0.7, 1.15)
		p.y = maxf(p.y, -0.45)
		p.y = minf(p.y, 0.8)
		puntos.append(donde + giro * Vector3(p.x * medida.x, p.y * medida.y, p.z * medida.z) * 0.5)
	# Caliza cantábrica húmeda: más oscura y más cálida que la primera versión,
	# que a mediodía salía blanco azulado.
	# Con la textura de roquedo puesta, el color de vértice ya no pinta la
	# piedra: sólo la aclara o la oscurece un poco, para que no salgan todas
	# iguales.
	var tono := _rng.randf_range(0.85, 1.12)
	for cara: Array in _ICO_F:
		var p0: Vector3 = puntos[cara[0]]
		var p1: Vector3 = puntos[cara[1]]
		var p2: Vector3 = puntos[cara[2]]
		var mitad := (p0 + p1 + p2) / 3.0
		var afuera := mitad - donde
		var luz := tono * _rng.randf_range(0.92, 1.06)
		var color := Color(luz, luz * 0.99, luz * 0.96)
		# Musgo en algunas caras que miran arriba, que es donde se agarra.
		if afuera.normalized().y > 0.6 and _rng.randf() < 0.3:
			color = Color(luz * 0.72, luz * 0.82, luz * 0.52)
		_cara(roca_v, roca_n, roca_c, p0, p1, p2, afuera, color)


## Una estalactita: una aguja de cuatro caras colgando de `raiz`.
func _estalactita(roca_v: PackedVector3Array, roca_n: PackedVector3Array,
		roca_c: PackedColorArray, raiz: Vector3, largo: float) -> void:
	var r := 0.12 + largo * 0.08
	var punta := raiz - Vector3(0.0, largo, 0.0)
	var esquinas: Array[Vector3] = [raiz + Vector3(r, 0, 0), raiz + Vector3(0, 0, r),
		raiz + Vector3(-r, 0, 0), raiz + Vector3(0, 0, -r)]
	var color := Color(0.24, 0.20, 0.15)
	for i in range(4):
		var a: Vector3 = esquinas[i]
		var b: Vector3 = esquinas[(i + 1) % 4]
		_cara(roca_v, roca_n, roca_c, a, b, punta, (a + b) * 0.5 - raiz, color)


## Un triángulo con su normal, mirando hacia `hacia`. El orden se elige y no se
## da por supuesto: la delantera es la que deja `(v1−v0)×(v2−v0)` hacia su
## normal —comprobado en captura el 2026-09-13; al revés se recortaba la roca y
## sólo quedaba el labio—.
static func _cara(vertices: PackedVector3Array, normales: PackedVector3Array,
		colores: PackedColorArray, p0: Vector3, p1: Vector3, p2: Vector3,
		hacia: Vector3, color: Color) -> void:
	var giro := (p1 - p0).cross(p2 - p0)
	if giro.length_squared() < 0.000001:
		return
	var normal := giro.normalized()
	if giro.dot(hacia) >= 0.0:
		vertices.append_array([p0, p1, p2])
	else:
		vertices.append_array([p0, p2, p1])
		normal = -normal
	normales.append_array([normal, normal, normal])
	colores.append_array([color, color, color])


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
	if _marker != null:
		_marker.visible = true


## Dónde está la boca, a ras de suelo. Es lo que la banda toma por casa.
func boca() -> Vector3:
	return _mouth_position


## Punto por el que se pincha, y radio de acierto en metros
## Un sitio DENTRO de la cueva, metido en la galería.
##
## Existe porque la banda dormía encima del abrigo, no dentro: la posición de
## casa era el punto del emplazamiento y ahí se apilaban los quince a la
## intemperie. Una cueva se ocupa por dentro, que es para lo que se ocupa.
func inside_point(spread: float = 0.0, angle: float = 0.0) -> Vector3:
	# En el suelo del pozo, debajo del agujero: ahí es donde se mete la banda.
	var deep := _mouth_position + Vector3(0.0, _suelo_de_la_cueva, 0.0)
	if spread > 0.001:
		deep += Vector3(cos(angle), 0.0, sin(angle)) * spread
	return deep


## Y un sitio DELANTE, en la campa de la boca.
##
## Es donde se hace todo lo que no es dormir: comer, contar, tallar al sol,
## esperar a que vuelva la partida de caza. Una cueva del Paleolítico se habita
## sobre todo en su puerta, que es donde da la luz.
func forecourt_point(spread: float = 0.0, angle: float = 0.0) -> Vector3:
	var out := _mouth_position + _facing * (mouth_radius * 1.6)
	if spread > 0.001:
		out += Vector3(cos(angle), 0.0, sin(angle)) * spread
	return out


## Hacia dónde mira la boca.
func facing() -> Vector3:
	return _facing


func pick_position() -> Vector3:
	return _mouth_position + Vector3(0.0, mouth_radius * 0.4, 0.0)


func pick_radius() -> float:
	return mouth_radius * 2.2
