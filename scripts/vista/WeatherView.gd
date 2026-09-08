class_name WeatherView
extends Node3D
## Hace visible el tiempo que hace.
##
## El tiempo llevaba desde que se implantó decidiendo cosas importantes —lo que
## cunde la jornada, lo que se anda, lo que se arriesga en una pared, hasta
## dónde se ve— y el jugador sólo se enteraba por un rótulo. Un temporal que
## sólo existe en una etiqueta no es un temporal: es un número.
##
## Aquí se ve. Y se ve **donde está la banda**, no en todo el mapa: la caja de
## partículas viaja con la cámara, que es como se simula lluvia en todas
## partes sin pagar lluvia en todas partes.

## Cuánto lado tiene la caja de precipitación, en metros.
##
## Se mueve con la cámara, así que sólo tiene que cubrir lo que se ve de
## cerca. Doscientos metros bastan: más allá, lo que da sensación de lluvia es
## la niebla de distancia, no las gotas.
const BOX := 200.0

## A qué altura sobre el suelo caen las partículas.
const CEILING := 120.0

var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _environment: Environment
var _camera: Camera3D
var _kind: int = -1
var _haze: ColorRect

## La niebla que ya traía el entorno, para poder devolverla.
var _base_fog_density: float = 0.0
var _base_fog_enabled: bool = false
var _fog_now: float = 0.0
var _fog_target: float = 0.0


func setup(camera: Camera3D, environment: Environment) -> void:
	_camera = camera
	_environment = environment
	if _environment:
		_base_fog_enabled = _environment.fog_enabled
		_base_fog_density = _environment.fog_density

	_rain = _make_precipitation(Color(0.62, 0.72, 0.82, 0.55),
		Vector3(0.0, -34.0, 0.0), 0.06, 2.4)
	_snow = _make_precipitation(Color(0.95, 0.97, 1.0, 0.9),
		Vector3(0.0, -2.6, 0.0), 0.22, 0.9)
	_build_haze()


## La bruma de pantalla: cierra por los BORDES y deja limpio el centro.
##
## La primera version metia toda la visibilidad en la niebla volumetrica del
## entorno, y con eso no se veia nada: tapaba el terreno que uno esta mirando,
## que es justo lo que no puede tapar una interfaz.
##
## Aqui se separan dos cosas que no son la misma. Lo que la niebla le hace al
## PAISAJE -las lomas de lejos se borran- se queda en la niebla del entorno,
## pero muy floja. Y lo que le hace a QUIEN MIRA -que no ves mas alla de tu
## alrededor- se dice cerrando los bordes de la pantalla, que es como se siente
## de verdad y ademas deja el centro despejado para poder jugar.
func _build_haze() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(0.78, 0.81, 0.84);

void fragment() {
	// Distancia al centro, corregida para que el ovalo siga la pantalla y no
	// se estire en panoramico
	vec2 from_centre = (UV - vec2(0.5)) * vec2(1.15, 1.0);
	float edge = length(from_centre) * 1.42;

	// El centro entero limpio, y el cierre solo en el ultimo tercio. Con la
	// bruma empezando en el medio se pierde el terreno que se esta mirando.
	float veil = smoothstep(0.55, 1.05, edge);
	COLOR = vec4(tint, veil * strength * 0.85);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader

	_haze = ColorRect.new()
	_haze.material = material
	_haze.set_anchors_preset(Control.PRESET_FULL_RECT)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_haze)


## Cambia lo que se ve. Se le llama cuando cambia el tiempo, no cada fotograma.
func show_weather(kind: Weather.Kind) -> void:
	if int(kind) == _kind:
		return
	_kind = int(kind)

	var rain := 0.0
	var snow := 0.0
	var fog := 0.0

	# Las cantidades salen de lo que cada estado SIGNIFICA, no de una escala
	# inventada: el orbayu es esa llovizna que no parece nada y te cala, así
	# que son muchas gotas pequeñas y poca niebla; el temporal tapa el valle.
	match kind:
		Weather.Kind.DESPEJADO:
			pass
		Weather.Kind.NUBLADO:
			fog = 0.04
		Weather.Kind.ORBAYU:
			rain = 0.30
			fog = 0.16
		Weather.Kind.LLUVIA:
			rain = 1.0
			fog = 0.24
		Weather.Kind.TEMPORAL:
			rain = 1.0
			fog = 0.45
		Weather.Kind.NIEBLA:
			# El unico estado que de verdad tapa. Y aun asi deja el centro
			# jugable: que no se vea NADA seria fiel y seria injugable.
			fog = 0.80
		Weather.Kind.NIEVE:
			snow = 1.0
			fog = 0.30

	_set_flow(_rain, rain, 9000)
	_set_flow(_snow, snow, 2600)
	_fog_target = fog


func _process(delta: float) -> void:
	# La caja viaja con la cámara. Sin esto habría que llenar de partículas
	# toda la comarca para que lloviera donde miras, que es pagar veinte
	# kilómetros de lluvia para ver doscientos metros.
	if _camera:
		var eye := _camera.global_position
		global_position = Vector3(eye.x, 0.0, eye.z)

	# La niebla entra y sale despacio. Un temporal que aparece de golpe entre
	# dos fotogramas se lee como un fallo gráfico, no como que ha cambiado el
	# tiempo: en el monte el cielo se cierra en minutos, no en un parpadeo.
	_fog_now = move_toward(_fog_now, _fog_target, delta * 0.35)

	# La niebla del entorno NO se toca si la escena la traia apagada.
	#
	# Es la segunda vez que la bajo y la segunda vez que sigue tapando todo, y
	# el motivo es que la densidad de niebla de Godot es POR METRO: aqui se
	# mira un valle de kilometros, asi que hasta 0,0045 —que parece nada— se
	# come el noventa y nueve por ciento de la luz a dos kilometros. No hay un
	# numero pequeno que valga; el error es usar niebla volumetrica para esto.
	#
	# La visibilidad se cuenta entera con el cierre de bordes, que no depende
	# de la distancia y por tanto no cambia al alejar la camara.
	if _environment and _base_fog_enabled:
		_environment.fog_density = _base_fog_density * (1.0 + _fog_now * 0.35)

	# Y el cierre de los bordes, que es donde va de verdad la visibilidad
	if _haze and _haze.material:
		(_haze.material as ShaderMaterial).set_shader_parameter(
			"strength", _fog_now)


func _make_precipitation(tint: Color, gravity: Vector3, scale_m: float,
		lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 8000
	particles.lifetime = lifetime
	particles.visibility_aabb = AABB(
		Vector3(-BOX, -20.0, -BOX), Vector3(BOX * 2.0, CEILING + 40.0, BOX * 2.0))
	particles.local_coords = false
	particles.position = Vector3(0.0, CEILING, 0.0)

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(BOX, 2.0, BOX)
	material.gravity = gravity
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 4.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 6.0
	# El copo baila y la gota no: es lo que distingue nieve de lluvia mirando
	material.turbulence_enabled = gravity.y > -10.0
	if material.turbulence_enabled:
		material.turbulence_noise_strength = 2.2
		material.turbulence_noise_scale = 3.0
	material.scale_min = scale_m
	material.scale_max = scale_m * 1.6
	particles.process_material = material

	var quad := QuadMesh.new()
	# La gota se estira en el sentido de la caída; el copo es cuadrado
	quad.size = Vector2(1.0, 14.0) if gravity.y < -10.0 else Vector2(1.0, 1.0)
	particles.draw_pass_1 = quad

	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = tint
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	draw.billboard_keep_scale = true
	draw.vertex_color_use_as_albedo = false
	draw.disable_receive_shadows = true
	particles.material_override = draw
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(particles)
	return particles


func _set_flow(particles: GPUParticles3D, strength: float, full: int) -> void:
	if particles == null:
		return
	particles.emitting = strength > 0.01
	particles.amount = maxi(int(float(full) * strength), 1)
