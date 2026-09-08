class_name Bonfire
extends Node3D
## Un fuego: el corro de piedras, la leña, la llama y la luz.
##
## Es la pieza, no el sitio. La usan los dos fuegos que hay en el juego y que no
## se parecen en nada salvo en esto: el HOGAR del abrigo —una obra, permanente,
## que se apaga si falta leña— y la hoguera de VIVAC que enciende quien pasa la
## noche fuera, que dura una noche y se va con quien la hizo. Ver [HearthFire] y
## [BivouacFires].
##
## Lo que se ve es lo que dice `CampProjects.HOGAR`: una fogata delimitada con
## piedras, como en Cueva Morín o El Esquilleu. Nada de estructura: un corro de
## cantos, unos leños cruzados y fuego encima.
##
## Y alumbra de verdad. De noche es la única luz del valle aparte de la luna.

## Radio del corro de piedras, en metros.
const RING_RADIUS := 1.1

## Cuántos cantos lo delimitan.
const RING_STONES := 9

## Alcance de la luz, en metros.
##
## Una hoguera de verdad alumbra el corro y poco más, y con eso puesto —26 m y
## energía 3— no se veía nada: a la distancia a la que se juega, el círculo de
## luz era del tamaño de una moneda. Esto es de las cosas que hay que exagerar
## para que signifiquen algo en pantalla, igual que la luna. Lo que tiene que
## leerse es «el campamento está vivo ahí abajo».
const LIGHT_RANGE := 85.0

## Energía de la luz con el fuego vivo.
##
## De 9 a 22, medido con `scripts/tests/NocheLuzProbe.gd` sobre el brillo del
## tercio central de la imagen —la boca de la cueva— en una noche de luna
## llena. Con 9 la boca daba 0,042; con 22 da 0,086; con 45, 0,153, que sobre
## un mediodía de 0,190 ya es un foco de estadio y no una hoguera.
##
## Lo que hace falta saber para moverlo: la hoguera es lo que MÁS cambia esa
## esquina de la pantalla. Apagada, la boca da 0,012; encendida a 22, 0,086.
const LIGHT_ENERGY := 22.0

## Cuánto y a qué ritmo tiembla la llama. Una hoguera quieta se lee como una
## bombilla naranja.
const FLICKER_AMOUNT := 0.22
const FLICKER_SPEED := 7.0

## Color del fuego y de su luz. Naranja muy cálido, no amarillo de linterna.
const FIRE_TINT := Color(1.0, 0.52, 0.16)
const LIGHT_TINT := Color(1.0, 0.62, 0.30)

## Cuánto de grande es este fuego. Uno es el hogar del abrigo; una hoguera de
## vivac es la mitad.
var size := 1.0

## Si arde ahora mismo. Apagado quedan las piedras y los leños.
var lit := false

var _light: OmniLight3D
var _flames: Node3D
var _wood: Node3D
var _rng := RandomNumberGenerator.new()
var _phase := 0.0


func build(seed_value: int = 20260907, factor: float = 1.0) -> void:
	size = factor
	_rng.seed = seed_value
	_build_ring()
	_build_wood()
	_build_flames()
	_build_light()
	scale = Vector3.ONE * size


## El corro de cantos. Irregular a propósito: son piedras del río puestas a
## mano, no un anillo trazado con compás.
func _build_ring() -> void:
	var stone := SphereMesh.new()
	stone.radius = 0.26
	stone.height = 0.42
	stone.radial_segments = 8
	stone.rings = 4
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.42, 0.40, 0.37)
	rock.roughness = 0.95

	for i in range(RING_STONES):
		var angle := TAU * float(i) / float(RING_STONES) \
			+ _rng.randf_range(-0.12, 0.12)
		var reach := RING_RADIUS * _rng.randf_range(0.88, 1.12)
		var node := MeshInstance3D.new()
		node.mesh = stone
		node.material_override = rock
		node.position = Vector3(cos(angle) * reach, 0.1, sin(angle) * reach)
		node.scale = Vector3.ONE * _rng.randf_range(0.75, 1.25)
		node.rotation.y = _rng.randf() * TAU
		add_child(node)


## Los leños, cruzados en tienda como se apila la leña que va a arder.
func _build_wood() -> void:
	_wood = Node3D.new()
	add_child(_wood)

	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = 0.055
	log_mesh.bottom_radius = 0.085
	log_mesh.height = 1.15
	log_mesh.radial_segments = 6
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.24, 0.16, 0.10)
	bark.roughness = 1.0

	for i in range(5):
		var angle := TAU * float(i) / 5.0
		var node := MeshInstance3D.new()
		node.mesh = log_mesh
		node.material_override = bark
		# Apoyado en el suelo por un cabo y cruzado sobre el centro por el otro.
		node.position = Vector3(cos(angle) * 0.34, 0.30, sin(angle) * 0.34)
		node.rotation = Vector3(deg_to_rad(_rng.randf_range(26.0, 38.0)),
			-angle, 0.0)
		_wood.add_child(node)


## La llama: tres cuadros cruzados que miran a cámara, sin sombra ni luz propia.
##
## No es humo ni partículas y no hace falta que lo sea. Lo que tiene que leerse
## a la distancia a la que se juega es «ahí hay fuego», y eso lo dice el color y
## el temblor, no la forma.
func _build_flames() -> void:
	_flames = Node3D.new()
	_flames.position.y = 0.34
	add_child(_flames)

	var flame := StandardMaterial3D.new()
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame.cull_mode = BaseMaterial3D.CULL_DISABLED
	flame.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flame.albedo_color = Color(FIRE_TINT.r, FIRE_TINT.g, FIRE_TINT.b, 0.85)
	# Con SILUETA, y no un cuadro de color liso. Sin textura, un quad aditivo se
	# dibuja como lo que es: un RECTÁNGULO naranja de borde recto. De noche y de
	# lejos colaba porque lo que se leía era el resplandor; en la lámina de
	# `ObrasAtlas`, al lado de las demás piezas, cantaba. Ver [_textura_de_llama].
	flame.albedo_texture = _textura_de_llama()
	flame.disable_receive_shadows = true

	for i in range(3):
		# La llama, también exagerada: a tamaño real es un píxel desde donde se
		# mira, y lo que tiene que verse es que hay fuego.
		var quad := QuadMesh.new()
		quad.size = Vector2(1.5 - float(i) * 0.3, 2.3 - float(i) * 0.5)
		var node := MeshInstance3D.new()
		node.mesh = quad
		node.material_override = flame
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = Vector3(_rng.randf_range(-0.12, 0.12),
			float(i) * 0.16, _rng.randf_range(-0.12, 0.12))
		_flames.add_child(node)


## La silueta de una llama: ancha abajo, estrecha y deshilachada arriba.
##
## Se genera una vez para todas las hogueras -es `static`- porque es la misma
## para todas y son varias por partida.
static var _llama: ImageTexture = null

static func _textura_de_llama() -> ImageTexture:
	if _llama != null:
		return _llama
	var lado := 64
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var ruido := FastNoiseLite.new()
	ruido.seed = 20260907
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.frequency = 0.09
	for y in range(lado):
		# v=0 es la punta y v=1 la base, que es donde la llama es ancha. La fila
		# CERO de una imagen es la de ARRIBA, y la esquina (0,0) de un QuadMesh
		# también: sin invertir, la llama salía ancha arriba y en punta abajo,
		# con un chorro rojo por debajo de las piedras.
		var v := float(y) / float(lado - 1)
		# Ancho de la lengua a esa altura: casi todo abajo, un hilo arriba.
		var ancho := pow(v, 0.65) * 0.46
		for x in range(lado):
			var u := float(x) / float(lado - 1) - 0.5
			var borde := ruido.get_noise_2d(float(x), float(y) * 0.6) * 0.06
			var d := absf(u) / maxf(ancho + borde, 0.001)
			# Desvanecido por el borde y por la punta: una llama no tiene filo.
			var a := (1.0 - smoothstep(0.35, 1.0, d)) * smoothstep(0.0, 0.22, v)
			# Y el corazón, más blanco que la punta.
			var calor := clampf(1.0 - d * 0.8, 0.0, 1.0) * v
			img.set_pixel(x, y, Color(1.0, 0.55 + 0.42 * calor,
				0.18 + 0.55 * calor, clampf(a, 0.0, 1.0)))
	_llama = ImageTexture.create_from_image(img)
	return _llama


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.position.y = 0.6
	_light.light_color = LIGHT_TINT
	_light.light_energy = LIGHT_ENERGY * size
	# El alcance NO se escala con `size` como el resto: un fuego más pequeño
	# alumbra menos fuerte, pero la luz sigue llegando igual de lejos porque el
	# aire no cambia. Y `scale` ya encoge el nodo entero, así que hay que
	# compensarlo o el vivac alumbraría un palmo.
	_light.omni_range = LIGHT_RANGE / maxf(size, 0.05)
	# Con sombras: una hoguera que no proyecta la sombra de quien está sentado
	# delante no se lee como fuego, se lee como el suelo pintado de naranja.
	_light.shadow_enabled = true
	add_child(_light)


func _process(delta: float) -> void:
	if _flames == null:
		return
	_flames.visible = lit
	_light.visible = lit
	if not lit:
		return

	_phase += delta * FLICKER_SPEED
	var flicker := 1.0 + sin(_phase) * FLICKER_AMOUNT \
		+ sin(_phase * 2.7) * FLICKER_AMOUNT * 0.5
	_light.light_energy = LIGHT_ENERGY * size * flicker
	_flames.scale = Vector3(1.0, 0.88 + flicker * 0.16, 1.0)
