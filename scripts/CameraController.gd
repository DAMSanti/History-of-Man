extends Camera3D
## Controlador de cámara orbital para el demo.
## Permite movimiento WASD, rotación con click derecho y zoom con scroll.

@export var target_position: Vector3 = Vector3(64, 0, 64)
@export var orbit_distance: float = 50.0
@export var orbit_angle_h: float = 0.0
@export var orbit_angle_v: float = -30.0
@export var move_speed: float = 30.0
@export var rotate_speed: float = 0.3
@export var zoom_speed: float = 5.0
@export var min_distance: float = 10.0
@export var max_distance: float = 200.0

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
			orbit_distance = clampf(orbit_distance - zoom_speed, min_distance, max_distance)
			_update_camera()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = clampf(orbit_distance + zoom_speed, min_distance, max_distance)
			_update_camera()
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
	
	# Zoom con Q/E
	if Input.is_key_pressed(KEY_Q):
		orbit_distance = clampf(orbit_distance + zoom_speed * delta * 10, min_distance, max_distance)
		_update_camera()
	if Input.is_key_pressed(KEY_E):
		orbit_distance = clampf(orbit_distance - zoom_speed * delta * 10, min_distance, max_distance)
		_update_camera()
	
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		# Rotar input según ángulo de cámara
		var rotated := input_dir.rotated(Vector3.UP, deg_to_rad(orbit_angle_h))
		target_position += rotated * move_speed * delta
		_update_camera()


func _update_camera() -> void:
	var offset := Vector3.ZERO
	offset.x = orbit_distance * cos(deg_to_rad(orbit_angle_v)) * sin(deg_to_rad(orbit_angle_h))
	offset.y = orbit_distance * -sin(deg_to_rad(orbit_angle_v))
	offset.z = orbit_distance * cos(deg_to_rad(orbit_angle_v)) * cos(deg_to_rad(orbit_angle_h))
	
	global_position = target_position + offset
	look_at(target_position, Vector3.UP)


## Establece la posición objetivo de la cámara
func set_target(pos: Vector3) -> void:
	target_position = pos
	_update_camera()


## Establece la distancia de órbita
func set_distance(dist: float) -> void:
	orbit_distance = clampf(dist, min_distance, max_distance)
	_update_camera()
