class_name Conchero
extends Node3D
## El montón de desechos, visto: crece con lo que la banda tira y TIÑE EL SUELO.
##
## Es lo que hace que el paisaje lleve la marca de la partida. El Cantábrico
## está lleno de concheros —El Mazo, La Fragua, Santimamiñe— y son montones de
## metros de espesor hechos de una sola cosa: cáscara. Un jugador que vuelva a
## un abrigo suyo de hace tres años tiene que ver que ahí vivió alguien, sin
## abrir ninguna ventana.
##
## Tres capas, y las tres crecen con [Desechos.crecido]:
##
##   1. La MANCHA. Un [Decal] proyectado sobre el terreno: el suelo se aclara
##      donde se lleva años tirando cáscara. Es lo que de verdad cambia la
##      textura del paisaje, y va con decal en vez de repintando el mapa del
##      terreno porque un decal se mueve y crece sin tocar nada de lo horneado.
##   2. El MONTÓN, una loma baja. Un conchero no es un cono: es un talud que se
##      desparrama, más ancho que alto.
##   3. La CÁSCARA suelta, un [MultiMesh] de piezas menudas repartidas por la
##      mancha, que es lo que se ve de cerca y lo que dice de qué está hecho.
##
## La TEXTURA sale de qué se ha comido —[Desechos.dominante]—: valvas si la banda
## vivió del marisco, cascarilla parda si vivió de la bellota, astillas de hueso
## si vivió de la caza. Así el montón cuenta la dieta de años sin una sola letra.
## Ver [Familia].

## Radio de la mancha cuando el montón está en su máximo, en metros.
const RADIO_MAX := 11.0

## Alto del montón en su máximo. Bajo a propósito: se desparrama.
const ALTO_MAX := 1.5

## Cuántas cáscaras sueltas se siembran como mucho.
const CASCARAS := 220

## Cada cuántos segundos se mira si ha crecido. No hace falta más: un montón
## crece por jornadas, no por fotogramas.
const CADA := 4.0

## De qué está hecho el montón, a la vista. No es un color: es una TEXTURA.
##
## Petición del usuario del 2026-09-14: «el conchero debe tener la textura
## predominante del material que lo forma: carne y huesos, cáscaras, conchas».
## Era un tinte liso —blanco, pardo o gris— sobre una loma sin dibujo, y a la
## distancia de gestión un montón de conchas y uno de huesos se leían igual. Tres
## familias, porque son tres cosas distintas de ver: la valva que brilla y se
## apila, la cascarilla menuda y parda, y la astilla de hueso entre tierra oscura.
enum Familia { CONCHA, CASCARA, HUESO }

const FAMILIA_DE := {
	Materia.Kind.MARISCO: Familia.CONCHA,
	Materia.Kind.CARACOL: Familia.CONCHA,
	Materia.Kind.CONCHA: Familia.CONCHA,
	Materia.Kind.BELLOTA: Familia.CASCARA,
	Materia.Kind.BELLOTA_DULCE: Familia.CASCARA,
	Materia.Kind.FRUTO_SECO: Familia.CASCARA,
	Materia.Kind.CARNE: Familia.HUESO,
	Materia.Kind.PESCADO: Familia.HUESO,
}

## El fondo y las piezas de cada familia: la tierra que queda entre medias y lo
## que asoma. Colores de dibujo, no medidas.
const FONDO := {
	Familia.CONCHA: Color(0.62, 0.58, 0.50),
	Familia.CASCARA: Color(0.30, 0.22, 0.14),
	Familia.HUESO: Color(0.26, 0.22, 0.18),
}
const PIEZA := {
	Familia.CONCHA: Color(0.92, 0.89, 0.82),
	Familia.CASCARA: Color(0.52, 0.39, 0.24),
	Familia.HUESO: Color(0.84, 0.80, 0.70),
}

## Las texturas horneadas, por familia. Son imágenes de CPU —no dependen de
## ningún viewport—, así que sobreviven al cambio de escena sin más.
static var _texturas: Dictionary = {}

var _sim: SettlementSim
var _terrain: TerrainGenerator
var _mancha: Decal
var _loma: MeshInstance3D
var _sueltas: MultiMeshInstance3D
var _material: StandardMaterial3D
var _reloj := 0.0
var _ultimo := -1.0


func setup(sim: SettlementSim, terrain: TerrainGenerator, donde: Vector3) -> void:
	_sim = sim
	_terrain = terrain
	_montar()
	colocar(donde)
	visible = false


## Lo lleva a otro sitio —la banda se ha mudado— y lo rehace allí.
func colocar(donde: Vector3) -> void:
	var spot := donde
	if _terrain != null:
		spot.y = _terrain.get_height_at(spot)
	global_position = spot
	# Obliga a rehacer la loma y la cáscara sobre el suelo nuevo.
	_ultimo = -1.0
	if _sim != null and _sim.desechos != null and _loma != null:
		_crecer()


func _montar() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.95
	# Proyectada desde el mundo: la loma es una malla cosida al suelo, sin UV, y
	# así la textura no se estira por la cuesta ni cambia de escala al crecer.
	_material.uv1_triplanar = true
	_material.uv1_world_triplanar = true
	_material.uv1_scale = Vector3.ONE * 0.45

	_mancha = Decal.new()
	_mancha.texture_albedo = _textura_de_mancha()
	# Hacia abajo y con altura de sobra: el terreno tiene pendiente y un decal
	# corto se queda flotando en la parte alta de la ladera.
	_mancha.size = Vector3(2.0, 8.0, 2.0)
	_mancha.upper_fade = 0.6
	_mancha.lower_fade = 0.6
	add_child(_mancha)

	# La loma se hace a medida del suelo en cada crecida: ver [_malla_de_la_loma].
	_loma = MeshInstance3D.new()
	_loma.material_override = _material
	add_child(_loma)

	_sueltas = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pieza := SphereMesh.new()
	pieza.radius = 0.055
	pieza.height = 0.045
	pieza.radial_segments = 5
	pieza.rings = 2
	mm.mesh = pieza
	mm.instance_count = CASCARAS
	mm.visible_instance_count = 0
	_sueltas.multimesh = mm
	_sueltas.material_override = _material
	add_child(_sueltas)


func _process(delta: float) -> void:
	Cronometro.tramo_raiz("vista: conchero")
	if _sim == null or _sim.desechos == null:
		Cronometro.cierra("vista: conchero")
		return
	_reloj += delta
	if _reloj < CADA:
		Cronometro.cierra("vista: conchero")
		return
	_reloj = 0.0
	_crecer()
	Cronometro.cierra("vista: conchero")


func _crecer() -> void:
	if not _sim.desechos.se_ve():
		visible = false
		return
	visible = true
	var cuanto := _sim.desechos.crecido()
	# Ni un pelo de trabajo si no ha cambiado nada apreciable: sembrar
	# doscientas cáscaras cada cuatro segundos para dejarlas donde estaban es
	# tirar el presupuesto de un montón que casi no se mira.
	if absf(cuanto - _ultimo) < 0.02:
		return
	_ultimo = cuanto

	var familia := familia_de(_sim.desechos.dominante())
	_material.albedo_texture = textura_de(familia)
	_material.albedo_color = Color.WHITE

	var radio := RADIO_MAX * cuanto
	_mancha.size = Vector3(radio * 2.0, 8.0, radio * 2.0)
	_mancha.modulate = PIEZA[familia]

	_loma.mesh = _malla_de_la_loma(radio * 0.72, ALTO_MAX * cuanto)

	_sembrar(radio, cuanto)


## Anillos de la loma, y radios por anillo. Pocos: es un montón bajo que se mira
## de lejos, y se rehace sólo cuando crece.
const ANILLOS := 7
const RADIOS := 20


## La loma COSIDA AL TERRENO: cada vértice a la altura del suelo que tiene
## debajo, más el perfil del montón.
##
## Era una media esfera escalada, o sea una tapa plana, y en la ladera de la boca
## se quedaba medio en el aire por el lado de abajo: «el conchero no sigue el
## terreno, está plano, parte flotando en el aire», queja del usuario del
## 2026-09-14. Un conchero es tierra y cáscara vertida sobre la cuesta, así que
## toma la forma de la cuesta. El borde va un pelo por debajo del suelo para que
## no se vea dónde acaba.
func _malla_de_la_loma(radio: float, alto: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := maxf(radio, 0.05)
	var puntos: Array[Vector3] = []
	# El centro, y luego anillo a anillo hacia fuera.
	puntos.append(_sobre_el_suelo(Vector3.ZERO, alto))
	for anillo in range(1, ANILLOS + 1):
		var f := float(anillo) / float(ANILLOS)
		for k in range(RADIOS):
			var a := TAU * float(k) / float(RADIOS)
			var plano := Vector3(cos(a), 0.0, sin(a)) * (r * f)
			# Perfil de talud: alto en el centro y tendido hacia el borde.
			var sube := alto * (1.0 - f * f)
			if anillo == ANILLOS:
				sube = -0.04
			puntos.append(_sobre_el_suelo(plano, sube))
	# En sentido HORARIO visto desde arriba, que es la cara delantera en Godot:
	# al revés, la loma sólo se vería desde debajo del suelo.
	for k in range(RADIOS):
		var sig := (k + 1) % RADIOS
		st.add_vertex(puntos[0])
		st.add_vertex(puntos[1 + k])
		st.add_vertex(puntos[1 + sig])
	for anillo in range(1, ANILLOS):
		var dentro := 1 + (anillo - 1) * RADIOS
		var fuera := 1 + anillo * RADIOS
		for k in range(RADIOS):
			var sig := (k + 1) % RADIOS
			st.add_vertex(puntos[dentro + k])
			st.add_vertex(puntos[fuera + sig])
			st.add_vertex(puntos[dentro + sig])
			st.add_vertex(puntos[dentro + k])
			st.add_vertex(puntos[fuera + k])
			st.add_vertex(puntos[fuera + sig])
	st.generate_normals()
	return st.commit()


## Un punto de la loma, en local, a `sube` metros sobre el suelo que tiene debajo.
func _sobre_el_suelo(plano: Vector3, sube: float) -> Vector3:
	var suelo := 0.0
	if _terrain != null:
		suelo = _terrain.get_height_at(global_position + plano) - global_position.y
	return Vector3(plano.x, suelo + sube, plano.z)


## Reparte la cáscara suelta por la mancha, más densa en el centro.
##
## Semilla fija: el montón tiene que estar igual cada vez que se mira. Un
## conchero que se recoloca al girar la cámara no es un conchero.
func _sembrar(radio: float, cuanto: float) -> void:
	var mm := _sueltas.multimesh
	var cuantas := int(float(CASCARAS) * cuanto)
	mm.visible_instance_count = cuantas
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	for i in range(cuantas):
		# Raíz de un aleatorio: sin ella, repartir por ángulo y radio amontona
		# todo en el centro. Con ella el reparto es uniforme por superficie, y
		# el amontonamiento del centro se hace aparte, a propósito.
		var t := sqrt(rng.randf())
		var sesgo := lerpf(t, t * t, 0.55)
		var angulo := rng.randf() * TAU
		var lejos := sesgo * radio
		var punto := Vector3(cos(angulo) * lejos, 0.0, sin(angulo) * lejos)
		if _terrain != null:
			punto.y = _terrain.get_height_at(global_position + punto) \
				- global_position.y
		# Y las que caen sobre la loma, encima de ella.
		var sobre := 1.0 - clampf(lejos / maxf(radio * 0.72, 0.01), 0.0, 1.0)
		punto.y += ALTO_MAX * cuanto * sobre * sobre + 0.02
		var t3 := Transform3D()
		t3 = t3.rotated(Vector3.UP, rng.randf() * TAU)
		t3 = t3.scaled(Vector3(rng.randf_range(0.7, 1.5),
			rng.randf_range(0.4, 0.9), rng.randf_range(0.7, 1.5)))
		t3.origin = punto
		mm.set_instance_transform(i, t3)


## Una mancha irregular con el borde deshilachado, para el decal.
##
## Un círculo limpio se lee como un foco de luz; lo que hace un montón es
## desparramarse de forma sucia. El ruido en el alfa es lo que lo consigue.
func _textura_de_mancha() -> ImageTexture:
	var lado := 128
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 20260908
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency = 0.045
	ruido.fractal_octaves = 3
	var centro := Vector2(lado, lado) * 0.5
	for y in range(lado):
		for x in range(lado):
			var d := Vector2(x, y).distance_to(centro) / (float(lado) * 0.5)
			var borde := ruido.get_noise_2d(float(x), float(y)) * 0.42
			var a := clampf(1.0 - smoothstep(0.35, 1.0, d + borde), 0.0, 1.0)
			# Y moteada por dentro: no es una capa de pintura, son cáscaras.
			var moteado := 0.72 + 0.28 * (ruido.get_noise_2d(
				float(x) * 3.1, float(y) * 3.1) * 0.5 + 0.5)
			img.set_pixel(x, y, Color(moteado, moteado, moteado, a * 0.85))
	return ImageTexture.create_from_image(img)


## La familia de un material de desecho. Lo que no está en la tabla —nada, o un
## material que no deja resto— sale como hueso, que es lo que queda de todo.
static func familia_de(kind: int) -> Familia:
	return FAMILIA_DE.get(kind, Familia.HUESO) as Familia


## La textura de una familia, horneada la primera vez que se pide.
##
## Piezas sueltas sobre un fondo moteado, repartidas con semilla fija y
## repetibles —la imagen se envuelve por los bordes—: valvas en abanico para la
## concha, escamas menudas para la cáscara y astillas alargadas para el hueso.
static func textura_de(familia: Familia) -> ImageTexture:
	if _texturas.has(familia):
		return _texturas[familia]
	var lado := 128
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 20260914 + int(familia)
	ruido.frequency = 0.08
	var fondo: Color = FONDO[familia]
	for y in range(lado):
		for x in range(lado):
			var n := ruido.get_noise_2d(float(x), float(y)) * 0.12
			img.set_pixel(x, y, Color(fondo.r + n, fondo.g + n, fondo.b + n))
	var azar := RandomNumberGenerator.new()
	azar.seed = 20260914 + int(familia)
	var pieza: Color = PIEZA[familia]
	var cuantas: int = {Familia.CONCHA: 70, Familia.CASCARA: 160, Familia.HUESO: 45}[familia]
	for i in range(cuantas):
		var cx := azar.randf() * lado
		var cy := azar.randf() * lado
		var angulo := azar.randf() * TAU
		var largo: float
		var ancho: float
		match familia:
			Familia.CONCHA:
				largo = azar.randf_range(4.0, 7.0)
				ancho = largo * 0.8
			Familia.CASCARA:
				largo = azar.randf_range(1.5, 3.0)
				ancho = largo * 0.6
			_:
				largo = azar.randf_range(6.0, 12.0)
				ancho = azar.randf_range(1.0, 2.0)
		var tono := pieza * azar.randf_range(0.8, 1.05)
		_pintar_pieza(img, cx, cy, largo, ancho, angulo, tono, familia == Familia.CONCHA)
	var textura := ImageTexture.create_from_image(img)
	_texturas[familia] = textura
	return textura


## Una pieza elíptica girada, envuelta por los bordes. Con `costillas`, las líneas
## en abanico de una valva.
static func _pintar_pieza(img: Image, cx: float, cy: float, largo: float,
		ancho: float, angulo: float, tono: Color, costillas: bool) -> void:
	var lado := img.get_width()
	var c := cos(angulo)
	var s := sin(angulo)
	var alcance := int(ceil(largo))
	for dy in range(-alcance, alcance + 1):
		for dx in range(-alcance, alcance + 1):
			var u := (float(dx) * c + float(dy) * s) / largo
			var v := (-float(dx) * s + float(dy) * c) / ancho
			var d := u * u + v * v
			if d > 1.0:
				continue
			var color := tono
			if costillas and int((atan2(v, u + 1.0) + PI) * 5.0) % 2 == 0:
				color = tono.darkened(0.12)
			# Sombra en el borde: la pieza está encima, no pintada.
			color = color.darkened(smoothstep(0.6, 1.0, d) * 0.35)
			img.set_pixel(posmod(int(cx) + dx, lado), posmod(int(cy) + dy, lado), color)
