class_name OrbitalCamera
extends Camera3D
## Controlador de cámara orbital para el demo.
## Permite movimiento WASD, rotación con click derecho y zoom con scroll.

@export var target_position: Vector3 = Vector3(64, 0, 64)
@export var orbit_distance: float = 50.0
@export var orbit_angle_h: float = 0.0
@export var orbit_angle_v: float = -30.0
@export var move_speed: float = 30.0
@export var rotate_speed: float = 0.3
## Factor de zoom por muesca de rueda. Es MULTIPLICATIVO a proposito: el paso
## crece con la distancia, que es lo unico que funciona cuando el rango va de
## 70 a 14000 unidades. Con el paso fijo anterior (5 unidades) hacian falta
## unas 2800 muescas para recorrer el rango entero.
@export_range(1.01, 2.0, 0.01) var zoom_factor: float = 1.13

## Y cuánto vale una muesca ABAJO DEL TODO, pegado al suelo.
##
## El paso multiplicativo es proporcional a la distancia, que es lo correcto
## mientras la distancia sea grande: un 13 % de dos kilómetros es un salto de
## dos kilómetros de vista, y está bien. Abajo no: a cincuenta metros de órbita
## se distingue a la gente y a los árboles uno por uno, y ahí un 13 % es medio
## encuadre de golpe. La muesca se afina según se baja, de modo que el tramo
## nuevo de zoom —el que antes no existía— se recorra despacio.
@export_range(1.01, 2.0, 0.01) var zoom_factor_near: float = 1.045

## En qué parte del recorrido se termina de afinar la muesca, de 0 -abajo- a 1.
@export_range(0.05, 1.0, 0.05) var zoom_fine_span: float = 0.45
@export var min_distance: float = 10.0
@export var max_distance: float = 200.0

## Recorte del recorrido de zoom. El recorrido completo se reparte en
## ZOOM_STEPS muescas de rueda y solo se conserva la banda entre `zoom_near_step`
## y `zoom_far_step`.
##
## Existe porque los extremos no sirven de nada: por abajo la camara se mete
## entre las piedras y por arriba el mapa entero es una mancha en la que ni los
## arboles se dibujan. Recortando queda un rango en el que todas las muescas
## ensenan algo util.
##
## El recorte es en escala LOGARITMICA porque el zoom es multiplicativo: media
## muesca cerca vale metros y lejos vale kilometros, asi que repartir en lineal
## no daria pasos iguales.
const ZOOM_STEPS := 16
##
## El extremo cercano estaba en la muesca 6, o sea a unos 300 m de órbita en un
## mapa de cuatro kilómetros. Eso no era "acercarse": era mirar el valle desde
## un poco más abajo, y tenía dos consecuencias que se veían. Una, que nunca se
## distinguía nada —ni la gente, ni un animal, ni un árbol de otro—. Y dos, que
## el bosque no llegaba a relevar el impostor por la malla de verdad, porque ese
## relevo está justo en los 300 m (`Forest.near_distance`): al zoom más cercano
## TODO el bosque quedaba al otro lado del corte y todo eran impostores.
@export_range(0, 16) var zoom_near_step: int = 1
@export_range(0, 16) var zoom_far_step: int = 13

## Consulta de altura del terreno. La pone la escena; si no hay, la camara se
## comporta como antes. Sirve para no meter la camara debajo del suelo al hacer
## zoom: el limite util no es una distancia fija sino la propia superficie.
var height_probe: Callable = Callable()

## Metros por encima del terreno a los que se frena el acercamiento.
##
## Baja de 12 a 6: doce metros es la altura de un pino, así que con el zoom
## abierto hasta los cincuenta metros de órbita el tope se comía buena parte del
## recorrido nuevo.
@export var ground_clearance: float = 6.0

## Limites del recuadro jugable. La camara no sale de aqui aunque el terreno
## siga: las casillas de alrededor estan para que el mapa no se corte a
## cuchillo, no para ir a ellas.
@export var bounds_min: Vector2 = Vector2.ZERO
@export var bounds_max: Vector2 = Vector2.ZERO

## Cuanto acelera el desplazamiento mientras se mantiene SHIFT
@export_range(1.0, 12.0, 0.5) var sprint_multiplier: float = 5.0

var _is_rotating: bool = false


func _ready() -> void:
	print("CameraController _ready - target: ", target_position)
	current = true
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = event.pressed
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(1.0 / _zoom_step())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(_zoom_step())
			get_viewport().set_input_as_handled()
	
	if event is InputEventMouseMotion and _is_rotating:
		orbit_angle_h -= event.relative.x * rotate_speed
		orbit_angle_v = clampf(orbit_angle_v - event.relative.y * rotate_speed, -89.0, -10.0)
		_update_camera()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	
	# Movimiento con teclas directas (más confiable)
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	# También intentar con acciones de input
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	# Zoom con Q/E, tambien proporcional a la distancia actual
	if Input.is_key_pressed(KEY_Q):
		_apply_zoom(pow(_zoom_step(), delta * 6.0))
	if Input.is_key_pressed(KEY_E):
		_apply_zoom(pow(1.0 / _zoom_step(), delta * 6.0))
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		# Rotar input según ángulo de cámara
		var rotated := input_dir.rotated(Vector3.UP, deg_to_rad(orbit_angle_h))
		# El desplazamiento escala con el zoom: de cerca se avanza despacio,
		# de lejos se cruza el mapa sin desesperar
		var speed := move_speed * clampf(orbit_distance / 500.0, 0.15, 4.0)
		# Con SHIFT se cruza el mapa; sin el, se recorre
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= sprint_multiplier
		target_position += rotated * speed * delta

		# El objetivo no sale del recuadro. Se recorta la POSICION y no la
		# velocidad, asi que la camara se para en seco contra el borde en vez
		# de frenar poco a poco, que es lo que deja claro que ahi se acaba.
		if bounds_max.x > bounds_min.x:
			target_position.x = clampf(target_position.x, bounds_min.x, bounds_max.x)
			target_position.z = clampf(target_position.z, bounds_min.y, bounds_max.y)
		_update_camera()


## Fija el recorrido de zoom a partir del rango COMPLETO que pediria la escena,
## quedandose solo con la banda util.
##
## Las escenas siguen razonando en terminos del mundo entero -"de un centesimo
## del mapa a dos veces el mapa"- y el recorte se decide en un solo sitio.
func set_distance_limits(full_near: float, full_far: float) -> void:
	var near := maxf(full_near, 0.01)
	var far := maxf(full_far, near * 1.01)
	var ratio := far / near
	var near_fraction := float(clampi(zoom_near_step, 0, ZOOM_STEPS)) / float(ZOOM_STEPS)
	var far_fraction := float(clampi(zoom_far_step, 0, ZOOM_STEPS)) / float(ZOOM_STEPS)
	if far_fraction <= near_fraction:
		far_fraction = minf(near_fraction + 1.0 / float(ZOOM_STEPS), 1.0)

	min_distance = near * pow(ratio, near_fraction)
	max_distance = near * pow(ratio, far_fraction)
	orbit_distance = clampf(orbit_distance, min_distance, max_distance)


## Cuánto vale una muesca de rueda AQUÍ.
##
## Se mide en el recorrido logarítmico —que es el que recorre la rueda— y no en
## metros: abajo del todo la muesca es `zoom_factor_near` y a partir de
## `zoom_fine_span` del recorrido ya es la de siempre.
func _zoom_step() -> float:
	var span := log(max_distance / maxf(min_distance, 0.001))
	if span <= 0.001:
		return zoom_factor
	var t := log(orbit_distance / maxf(min_distance, 0.001)) / span
	return lerpf(zoom_factor_near, zoom_factor,
		smoothstep(0.0, zoom_fine_span, clampf(t, 0.0, 1.0)))


## Aplica un zoom multiplicativo respetando los limites
func _apply_zoom(factor: float) -> void:
	orbit_distance = clampf(orbit_distance * factor, min_distance, max_distance)
	_update_camera()


func _update_camera() -> void:
	var offset := Vector3.ZERO
	offset.x = orbit_distance * cos(deg_to_rad(orbit_angle_v)) * sin(deg_to_rad(orbit_angle_h))
	offset.y = orbit_distance * -sin(deg_to_rad(orbit_angle_v))
	offset.z = orbit_distance * cos(deg_to_rad(orbit_angle_v)) * cos(deg_to_rad(orbit_angle_h))

	var eye := target_position + offset

	# Tope de acercamiento por la SUPERFICIE, no por una distancia fija: en un
	# valle puedes bajar mucho y en una ladera no, y con un limite unico o te
	# quedas corto en el llano o te metes dentro del monte.
	#
	# Y se sube por la ÓRBITA, no en vertical. Levantar el ojo a secas lo sacaba
	# de la esfera: la distancia real a la que estaba la cámara dejaba de ser
	# `orbit_distance`, y como la rueda calcula su paso sobre `orbit_distance`,
	# el zoom se desincronizaba de lo que se veía —muescas que no movían nada,
	# y un tope de acercamiento que aparecía y desaparecía según la ladera que
	# hubiera debajo—. Subiendo por la esfera sólo cambia el ángulo, y la
	# distancia sigue siendo exactamente la pedida.
	if height_probe.is_valid():
		var ground: float = height_probe.call(eye)
		var floor_y := ground + ground_clearance
		if eye.y < floor_y:
			var lifted := eye
			lifted.y = floor_y
			var reach := (lifted - target_position).length()
			if reach > 0.001:
				eye = target_position 					+ (lifted - target_position) / reach * orbit_distance

	global_position = eye
	look_at(target_position, Vector3.UP)


## Establece la posición objetivo de la cámara
func set_target(pos: Vector3) -> void:
	target_position = pos
	_update_camera()


## Establece la distancia de órbita
func set_distance(dist: float) -> void:
	orbit_distance = clampf(dist, min_distance, max_distance)
	_update_camera()
