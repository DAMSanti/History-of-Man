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
## El COLOR sale de qué se ha comido —[Desechos.dominante]—: blanco de concha
## si la banda vivió del marisco, pardo si vivió de la bellota. Así el montón
## cuenta la dieta de años sin una sola letra.

## Radio de la mancha cuando el montón está en su máximo, en metros.
const RADIO_MAX := 11.0

## Alto del montón en su máximo. Bajo a propósito: se desparrama.
const ALTO_MAX := 1.5

## Cuántas cáscaras sueltas se siembran como mucho.
const CASCARAS := 220

## Cada cuántos segundos se mira si ha crecido. No hace falta más: un montón
## crece por jornadas, no por fotogramas.
const CADA := 4.0

## De qué color es el montón según de qué esté hecho.
const TINTES := {
	Materia.Kind.MARISCO: Color(0.82, 0.79, 0.71),      ## Blanco de concha
	Materia.Kind.CARACOL: Color(0.74, 0.70, 0.60),
	Materia.Kind.BELLOTA: Color(0.44, 0.34, 0.22),      ## Pardo de cascarilla
	Materia.Kind.BELLOTA_DULCE: Color(0.48, 0.38, 0.25),
	Materia.Kind.FRUTO_SECO: Color(0.40, 0.31, 0.21),
	Materia.Kind.CARNE: Color(0.72, 0.69, 0.62),        ## Hueso
	Materia.Kind.PESCADO: Color(0.68, 0.67, 0.63),
}
const TINTE_POR_DEFECTO := Color(0.70, 0.66, 0.58)

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
	var spot := donde
	if _terrain != null:
		spot.y = _terrain.get_height_at(spot)
	global_position = spot
	_montar()
	visible = false


func _montar() -> void:
	_material = StandardMaterial3D.new()
	_material.roughness = 0.95

	_mancha = Decal.new()
	_mancha.texture_albedo = _textura_de_mancha()
	# Hacia abajo y con altura de sobra: el terreno tiene pendiente y un decal
	# corto se queda flotando en la parte alta de la ladera.
	_mancha.size = Vector3(2.0, 8.0, 2.0)
	_mancha.upper_fade = 0.6
	_mancha.lower_fade = 0.6
	add_child(_mancha)

	_loma = MeshInstance3D.new()
	var domo := SphereMesh.new()
	domo.radius = 1.0
	domo.height = 1.0
	domo.radial_segments = 18
	domo.rings = 8
	# Media esfera: la mitad de abajo está enterrada, que es donde está la
	# parte vieja del montón.
	domo.is_hemisphere = true
	_loma.mesh = domo
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

	_material.albedo_color = TINTES.get(_sim.desechos.dominante(),
		TINTE_POR_DEFECTO)

	var radio := RADIO_MAX * cuanto
	_mancha.size = Vector3(radio * 2.0, 8.0, radio * 2.0)
	_mancha.modulate = _material.albedo_color

	_loma.scale = Vector3(radio * 0.72, ALTO_MAX * cuanto, radio * 0.72)

	_sembrar(radio, cuanto)


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
