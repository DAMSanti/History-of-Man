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
## cerca. Eran doscientos metros —400 de lado—: con la caída a la altura de la cámara, las
## gotas se repartían tanto que se veían cuatro rayas sueltas (`ClimaCaptura`,
## 2026-09-16). Con setenta, la misma cantidad llena lo que hay junto a la cámara, y más
## allá lo que da sensación de lluvia es la luz y la bruma, no las gotas.
const BOX := 70.0

## Y lo que mide con el zoom más lejano. La caja tiene que cubrir lo que se ve, y
## lo que se ve crece con la distancia de órbita: con 70 m fijos, desde lejos la
## lluvia se leía como **un cuadrado** de agua en medio del valle —queja del
## usuario del 2026-09-16—.
const CAJA_LEJOS := 320.0

## Cuánto de lo que se ve hay que cubrir. La cámara mira desde `orbit_distance`,
## así que a ojo abarca esa misma medida de suelo; se cubre con algo de margen.
const CAJA_POR_DISTANCIA := 1.1

## Lo más que se agranda una gota al alejarse. Sin tope, a ochocientos metros la
## gota mide cuatro y se lee como una grieta en la pantalla.
const GOTA_MAS_GRANDE := 2.5

## A qué altura sobre el suelo caen las partículas.
const CEILING := 120.0

var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _environment: Environment
var _camera: Camera3D

## Lo que mide ahora el lado de la caja de lluvia, en metros. Ver [_ajustar_la_caja].
var _lado_de_la_caja := BOX

## Cuánta lluvia se ve caer, de 0 a 1. Es lo que pica el agua, y no tiene que ver con
## lo mojado del suelo: para de llover y las ondas se van en dos segundos, mientras el
## suelo sigue mojado un rato largo.
var lluvia_vista := 0.0
var _kind: int = -1
var _haze: ColorRect

## La niebla que ya traía el entorno, para poder devolverla.
var _base_fog_density: float = 0.0
var _base_fog_enabled: bool = false
var _fog_now: float = 0.0
var _fog_target: float = 0.0

## El suelo que se moja y se nieva, por horas de juego. Ver [ClimaEnPantalla].
var suelo := ClimaEnPantalla.new()
## Lo que se ve del suelo: sigue al de las horas suavizado por cuadro, para que una hora
## que se come de golpe a x5 no se lea como un salto.
var mojado_visto := 0.0
var nieve_vista := 0.0
## La última hora de juego contada —jornada × 24 + hora—, o -1 sin contar todavía.
var _hora_contada := -1
## De dónde viene el viento de hoy, en grados desde el norte. Ver [viento_del_dia].
var viento := 0.0

## Si el clima se dibuja: el ajuste «Clima» (INTERFAZ §8.8). Apagado no se dibuja nada del
## tiempo, pero el suelo sigue contando horas, para que al encenderlo esté donde toca.
var encendido := true

## La niebla de valle, que se enciende con niebla. La pone la escena.
var niebla: NieblaDeValle = null

## La condensación en la cámara: cuánto se empaña la imagen, de 0 a 1, y la capa que lo
## pinta. Ver [se_empana_en].
var empanado := 0.0
var _condensacion: ColorRect = null

## El terreno y la estación, para pintar el suelo: los pone la escena con [pintar_el_suelo_en].
var _terreno: TerrainGenerator = null
var _temporada: Temporada = null

## Si en tantas horas no se ha mirado —una partida cargada, un mapa que se retoma—, no se
## cuentan una a una: se asienta el suelo por el tiempo de ahora.
const HORAS_QUE_SE_CUENTAN := 48


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
	_rain.draw_pass_1 = _gota_cruzada()
	_build_haze()
	_build_condensacion()
	add_to_group(Configuracion.GRUPO)
	aplicar_configuracion()


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


## De dónde sopla el viento en una jornada, en grados: **lo elige la vista**, con la
## jornada como semilla, y no el `_rng` de la partida, que no se gasta en dibujar (SPECS
## §3.3; decisión aceptada por el usuario el 2026-09-16). Un paso de ángulo áureo: días
## seguidos, vientos que no se parecen.
static func viento_del_dia(dia: int) -> float:
	return fposmod(float(dia) * 137.5, 360.0)


## Dónde pintar lo mojado y la nieve: el terreno y la estación que da la cota de nieve.
func pintar_el_suelo_en(terreno: TerrainGenerator, temporada: Temporada) -> void:
	_terreno = terreno
	_temporada = temporada


## Pone lo mojado, la nieve y la cota de nieve en el terreno y en la capa de las piedras.
## Se llama cada cuadro con lo que se ve; es poner cuatro uniformes.
func _pintar_el_suelo() -> void:
	var cota_fraccion := _temporada.cota_de_nieve() if _temporada != null else 2.0
	var cota_m := _temporada.cota_de_nieve_en_metros() if _temporada != null else 100000.0
	if _terreno != null and _terreno.get_terrain_material() != null:
		var terreno := _terreno.get_terrain_material()
		terreno.set_shader_parameter("clima_mojado", mojado_visto)
		terreno.set_shader_parameter("clima_nieve", nieve_vista)
		terreno.set_shader_parameter("clima_cota_de_nieve", cota_fraccion)
	# EL AGUA PICADA DE GOTAS mientras llueve. No es lo mojado del suelo —que se seca
	# despacio y dura horas—: esto es lo que cae AHORA, así que sale de lo que está
	# cayendo y no de `mojado_visto` (petición del usuario del 2026-09-16).
	if _terreno != null:
		for agua: ShaderMaterial in _terreno.materiales_del_agua():
			agua.set_shader_parameter("lluvia_en_el_agua", lluvia_vista)

	var encima := ClimaEnPantalla.material_encima()
	encima.set_shader_parameter("mojado", mojado_visto)
	encima.set_shader_parameter("nieve", nieve_vista)
	encima.set_shader_parameter("cota_de_nieve_m", cota_m)


## Las horas de juego que han pasado desde la última vez: el suelo avanza una por hora con
## el tiempo que hace. Lo llama la escena al mirar el tiempo. Tras un salto largo —cargar,
## retomar el mapa— se asienta en vez de contar.
func contar_horas(dia: int, hora: float, tiempo: Weather.Kind) -> void:
	var ahora := dia * 24 + int(hora)
	viento = viento_del_dia(dia)
	if _hora_contada < 0 or ahora - _hora_contada > HORAS_QUE_SE_CUENTAN or ahora < _hora_contada:
		suelo.asentar(tiempo)
		mojado_visto = suelo.mojado
		nieve_vista = suelo.nieve
	else:
		for i in range(ahora - _hora_contada):
			suelo.una_hora(tiempo)
	_hora_contada = ahora


## El ajuste «Clima», en caliente. **Apagado no dibuja nada** (GRAFICOS §7.4): ni
## partículas, ni niebla de valle, ni bruma, ni suelo mojado, ni nieve cuajada, ni
## condensación. La luz del tiempo la quita la escena (`DemoMain._sync_weather`).
func aplicar_configuracion() -> void:
	encendido = bool(Configuracion.graficos.get("clima", true))
	# Que el siguiente `show_weather` vuelva a poner lo que toca aunque el tiempo no cambie.
	_kind = -1
	if encendido:
		return
	_llover(_rain, ClimaEnPantalla.lluvia(Weather.Kind.DESPEJADO))
	_llover(_snow, ClimaEnPantalla.nieve_que_cae(Weather.Kind.DESPEJADO))
	_fog_target = 0.0
	_fog_now = 0.0
	if _haze != null and _haze.material != null:
		(_haze.material as ShaderMaterial).set_shader_parameter("strength", 0.0)
	if _environment != null and _base_fog_enabled:
		_environment.fog_density = _base_fog_density
	if niebla != null:
		niebla.quitar()
	mojado_visto = 0.0
	nieve_vista = 0.0
	empanado = 0.0
	if _condensacion != null:
		_condensacion.visible = false
	_pintar_el_suelo()


## Si la cámara en `punto` se empaña: **dentro de la niebla de valle**, y no encima de la
## capa ni sin niebla (GRAFICOS §7.4, decisión del usuario).
func se_empana_en(punto: Vector3) -> bool:
	return encendido and niebla != null and niebla.dentro(punto)


## El agua en la cámara: gotas sueltas sobre la lente, cada una una lente pequeña
## (`gotas_en_la_camara.gdshader`). Una capa de pantalla por encima del mundo y por debajo
## de la interfaz, como la bruma de los bordes.
func _build_condensacion() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/gotas_en_la_camara.gdshader") as Shader
	_condensacion = ColorRect.new()
	_condensacion.material = material
	_condensacion.set_anchors_preset(Control.PRESET_FULL_RECT)
	_condensacion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_condensacion.visible = false
	layer.add_child(_condensacion)


## Cambia lo que se ve. Se le llama cuando cambia el tiempo, no cada fotograma.
func show_weather(kind: Weather.Kind) -> void:
	if int(kind) == _kind or not encendido:
		return
	_kind = int(kind)

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
			fog = 0.16
		Weather.Kind.LLUVIA:
			fog = 0.24
		Weather.Kind.TEMPORAL:
			fog = 0.45
		Weather.Kind.NIEBLA:
			# Menos que el 0,8 de antes: desde el 2026-09-16 la visibilidad la quita
			# sobre todo la niebla de valle (GRAFICOS §7.4), que se ve como niebla.
			fog = 0.35
		Weather.Kind.NIEVE:
			snow = 1.0
			fog = 0.30

	# LA LLUVIA POR INTENSIDAD (GRAFICOS §7.4): cuántas gotas, de qué tamaño y cuánto las
	# inclina el viento, de [ClimaEnPantalla]. Antes orbayu, lluvia y temporal eran la misma
	# lluvia con más o menos gotas.
	_llover(_rain, ClimaEnPantalla.lluvia(kind))
	_llover(_snow, ClimaEnPantalla.nieve_que_cae(kind))
	if niebla != null:
		niebla.poner(ClimaEnPantalla.hay_niebla_de_valle(kind))
	_fog_target = fog


func _process(delta: float) -> void:
	if not encendido:
		return
	Cronometro.tramo_raiz("vista: tiempo")
	# La caja viaja con la cámara. Sin esto habría que llenar de partículas
	# toda la comarca para que lloviera donde miras, que es pagar veinte
	# kilómetros de lluvia para ver doscientos metros.
	# A LA ALTURA DE LA CÁMARA, con el techo de la caja por encima de ella: iba a cota
	# cero, y con el relieve real —el valle, de 100 a 700 m— la lluvia caía bajo tierra y
	# no se veía nunca (`ClimaCaptura`, 2026-09-16).
	if _camera:
		var eye := _camera.global_position
		global_position = Vector3(eye.x, eye.y - CEILING * 0.6, eye.z)
		_ajustar_la_caja()

	# LA CONDENSACIÓN: entra y sale en un segundo al meter y sacar la cámara de la niebla.
	var metida := _camera != null and _camera.is_inside_tree() and se_empana_en(_camera.global_position)
	empanado = move_toward(empanado, 1.0 if metida else 0.0, delta)
	if _condensacion != null:
		_condensacion.visible = empanado > 0.001
		(_condensacion.material as ShaderMaterial).set_shader_parameter("fuerza", empanado)

	# Lo que pica el agua entra y sale con la lluvia, sin saltos: un chaparrón que
	# aparece entre dos cuadros se lee como un fallo, no como que se ha puesto a llover.
	var cayendo := float(ClimaEnPantalla.lluvia(_kind).get("cantidad", 0)) / 8000.0
	lluvia_vista = move_toward(lluvia_vista, clampf(cayendo, 0.0, 1.0), delta * 0.6)

	# El suelo que se ve sigue al de las horas, sin saltos.
	mojado_visto = move_toward(mojado_visto, suelo.mojado, delta * 0.5)
	nieve_vista = move_toward(nieve_vista, suelo.nieve, delta * 0.5)
	_pintar_el_suelo()

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
	Cronometro.cierra("vista: tiempo")


## Pone la caja al tamaño de lo que se ve, según el zoom.
##
## **No basta con mover la caja con la cámara**, que es lo que había: las gotas
## nacían en coordenadas de mundo y se quedaban donde nacieron, así que al girar
## o alejarse la caja se iba y la lluvia se quedaba atrás —«desaparece un momento
## y después se reinicia, pero lejos, y saliendo sólo de un cuadrado», 2026-09-16—.
## Lo que arregla eso es que las gotas viajen CON la caja (`local_coords`), y lo
## que arregla el cuadrado es que la caja crezca con el zoom.
func _ajustar_la_caja() -> void:
	var orbital := _camera as OrbitalCamera
	var lado := BOX
	if orbital != null:
		lado = clampf(orbital.orbit_distance * CAJA_POR_DISTANCIA, BOX, CAJA_LEJOS)
	# Sólo cuando cambia de verdad: tocar la caja de un emisor cada cuadro es
	# rehacer su material, y el zoom se mueve a muescas.
	if absf(lado - _lado_de_la_caja) < 1.0:
		return
	_lado_de_la_caja = lado
	for particles: GPUParticles3D in [_rain, _snow]:
		if particles == null:
			continue
		var proceso := particles.process_material as ParticleProcessMaterial
		if proceso != null:
			proceso.emission_box_extents = Vector3(lado, 2.0, lado)
		# LA CAJA DE VISIBILIDAD VA CON ELLA. Si se queda corta, Godot descarta el
		# sistema entero y la lluvia desaparece sin decir nada (2026-09-16).
		particles.visibility_aabb = AABB(
			Vector3(-lado, -CEILING * 1.5, -lado),
			Vector3(lado * 2.0, CEILING * 1.5 + 20.0, lado * 2.0))
	# Y lo que cae se reparte otra vez: la misma agua en una caja veinte veces más
	# grande se ve como cuatro gotas sueltas.
	_llover(_rain, ClimaEnPantalla.lluvia(_kind))
	_llover(_snow, ClimaEnPantalla.nieve_que_cae(_kind))


func _make_precipitation(tint: Color, gravity: Vector3, scale_m: float,
		lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 8000
	particles.lifetime = lifetime
	# LA CAJA DE VISIBILIDAD, DESDE DONDE NACEN HASTA DONDE MUEREN, por debajo del emisor.
	# Iba de 20 m por debajo a 140 por encima: con la caída puesta a la altura de la cámara
	# quedaba por encima de ella, fuera de lo que se mira, y Godot descartaba la lluvia
	# entera —cero coste de GPU con temporal— (`ClimaCaptura`, 2026-09-16).
	particles.visibility_aabb = AABB(
		Vector3(-BOX, -CEILING * 1.5, -BOX), Vector3(BOX * 2.0, CEILING * 1.5 + 20.0, BOX * 2.0))
	# LAS GOTAS VIAJAN CON LA CAJA. En coordenadas de mundo se quedaban donde
	# nacieron mientras la caja seguía a la cámara: al moverse, la lluvia se
	# quedaba atrás y volvía a empezar lejos (queja del 2026-09-16).
	particles.local_coords = true
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
	# La gota va a lo largo de su velocidad: así la inclina el viento. El copo, no.
	material.particle_flag_align_y = gravity.y < -10.0
	particles.process_material = material

	var quad := QuadMesh.new()
	# La gota se estira en el sentido de la caída; el copo es cuadrado
	quad.size = Vector2(1.0, 14.0) if gravity.y < -10.0 else Vector2(1.0, 1.0)
	particles.draw_pass_1 = quad

	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.albedo_color = tint
	# La gota, alineada con su caída y sin billboard (ver `particle_flag_align_y`); el copo,
	# de cara a la cámara.
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED if gravity.y < -10.0 \
		else BaseMaterial3D.BILLBOARD_ENABLED
	draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	draw.billboard_keep_scale = true
	draw.vertex_color_use_as_albedo = false
	draw.disable_receive_shadows = true
	# Las que pasan pegadas a la cámara, fuera: una gota a un metro del ojo se pintaba como una
	# barra que cruzaba media pantalla (`ClimaCaptura`, 2026-09-16).
	draw.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	draw.distance_fade_min_distance = 8.0
	draw.distance_fade_max_distance = 22.0
	particles.material_override = draw
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	add_child(particles)
	return particles


## Pone lo que cae: cuántas partículas, de qué tamaño y con qué inclinación, soplando
## desde [viento]. La gota se alinea con su velocidad, así que se ve inclinada.
func _llover(particles: GPUParticles3D, que: Dictionary) -> void:
	if particles == null:
		return
	var cantidad := int(que["cantidad"])
	particles.emitting = cantidad > 0
	var proceso := particles.process_material as ParticleProcessMaterial
	if cantidad <= 0 or proceso == null:
		return
	# CON EL TAMAÑO DE LA CAJA: al alejarse, la caja crece y la misma cantidad de
	# gotas en un volumen mayor se ve como cuatro gotas sueltas, así que se suben
	# las dos cosas —cuántas y cómo de grandes— para que en pantalla se lea igual.
	var estirada := maxf(_lado_de_la_caja, BOX) / BOX
	particles.amount = maxi(int(float(cantidad) * minf(estirada, 2.0)), 1)
	var gorda := float(que["tamano"]) * minf(estirada, GOTA_MAS_GRANDE)
	proceso.scale_min = gorda
	proceso.scale_max = gorda * 1.6
	# El viento sopla DESDE `viento`: la gota va hacia el lado contrario.
	var hacia := deg_to_rad(viento + 180.0)
	var caida := absf(proceso.gravity.length())
	var inclinada := deg_to_rad(float(que["inclinacion"]))
	proceso.gravity = Vector3(sin(hacia) * sin(inclinada), -cos(inclinada), -cos(hacia) * sin(inclinada)) * caida
	proceso.direction = proceso.gravity.normalized()


## La gota de lluvia: dos tiras cruzadas, para que alineada con su caída se vea desde
## cualquier lado. Con una sola, de canto desaparecía.
static func _gota_cruzada() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for giro: float in [0.0, PI * 0.5]:
		var lado := Vector3(cos(giro), 0.0, sin(giro)) * 0.5
		var arriba := Vector3(0.0, 7.0, 0.0)
		for v: Vector3 in [-lado - arriba, lado - arriba, lado + arriba, -lado - arriba, lado + arriba, -lado + arriba]:
			st.add_vertex(v)
	return st.commit()
