class_name SalpicadurasDelRio
extends Node3D
## Las salpicaduras de los rápidos, en Ultra (GRAFICOS §7.3).
##
## **No llenan el río**: un número fijo de emisores —[EMISORES]— en **las piedras** de los
## rápidos más cerca de la cámara, que se reparten otra vez cuando la cámara se mueve lo
## bastante, como el 3D del bosque. Las piedras son las de [PiedrasDelRio]: el agua salta
## donde choca. Es vista: no toca la partida.
##
## **Chorros que saltan y caen**, no gotas que flotan. Vuelta del usuario del 2026-09-15:
## «las salpicaduras no se leen como salpicaduras, flotan por encima del agua sin más».
## Salían de las celdas de rápido y no de las piedras, en una caja por encima del agua, con
## poca gravedad y en discos: ahora nacen en el agua junto a la piedra, saltan corriente
## abajo, caen con la gravedad de verdad en medio segundo y van estiradas en su dirección.

## Cuántos emisores como mucho. Decisión: los de un encuadre de gestión cerca del río
## caben de sobra, y cada uno son pocas partículas.
const EMISORES := 12

## Hasta dónde se buscan rápidos alrededor del punto que mira la cámara, en metros.
const RADIO_M := 160.0


## Cuánto se tiene que mover la cámara para repartir otra vez, en metros.
const PASO_DE_REPARTO_M := 25.0

var _terreno: TerrainGenerator
var _camara: OrbitalCamera
## Los puntos que salpican: {pos: Vector3, fuerza: float}.
var _puntos: Array[Dictionary] = []
var _emisores: Array[GPUParticles3D] = []
var _ultimo_reparto := Vector3(INF, INF, INF)


func setup(terreno: TerrainGenerator, camara: OrbitalCamera) -> void:
	_terreno = terreno
	_camara = camara
	name = "SalpicadurasDelRio"
	add_to_group(Configuracion.GRUPO)
	_puntos = puntos_que_salpican(terreno)
	for i in range(EMISORES):
		var e := _emisor()
		add_child(e)
		_emisores.append(e)
	aplicar_configuracion()


## Se encienden sólo en Ultra.
func aplicar_configuracion() -> void:
	var encendidas := int(Configuracion.graficos.get("agua", 1)) >= 3 and not _puntos.is_empty()
	visible = encendidas
	set_process(encendidas)
	for e: GPUParticles3D in _emisores:
		e.emitting = false
	_ultimo_reparto = Vector3(INF, INF, INF)


func _process(_delta: float) -> void:
	if _camara == null:
		return
	var mira := _camara.target_position
	if mira.distance_to(_ultimo_reparto) < PASO_DE_REPARTO_M:
		return
	_ultimo_reparto = mira
	var elegidos := elegir_los_que_salpican(_puntos, mira, EMISORES, RADIO_M)
	for i in range(_emisores.size()):
		var e := _emisores[i]
		if i < elegidos.size():
			e.global_position = elegidos[i]["pos"]
			e.amount_ratio = clampf(float(elegidos[i]["fuerza"]), 0.4, 1.0)
			# Corriente abajo y hacia arriba: el agua sube por la cara de la piedra y cae detrás.
			var d: Vector2 = elegidos[i]["dir"]
			(e.process_material as ParticleProcessMaterial).direction = Vector3(d.x, 1.3, d.y).normalized()
			e.emitting = true
		else:
			e.emitting = false


## Las piedras de un terreno, en coordenadas de mundo: donde salta el agua.
static func puntos_que_salpican(terreno: TerrainGenerator) -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	var origen := terreno.global_position if terreno.is_inside_tree() else terreno.position
	for p: Dictionary in PiedrasDelRio.piedras_de(terreno):
		salida.append({"pos": origen + (p["pos"] as Vector3), "fuerza": p["fuerza"], "dir": p["dir"]})
	return salida


## Los `cuantos` puntos que salpican a menos de `radio` de `centro`, los de más fuerza
## primero y, a igual fuerza, los más cerca. Nunca más de `cuantos`.
static func elegir_los_que_salpican(puntos: Array[Dictionary], centro: Vector3, cuantos: int, radio: float) -> Array[Dictionary]:
	var cerca: Array[Dictionary] = []
	for p: Dictionary in puntos:
		var pos: Vector3 = p["pos"]
		if Vector2(pos.x - centro.x, pos.z - centro.z).length() <= radio:
			cerca.append(p)
	cerca.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["fuerza"]), float(b["fuerza"])):
			return float(a["fuerza"]) > float(b["fuerza"])
		return (a["pos"] as Vector3).distance_squared_to(centro) < (b["pos"] as Vector3).distance_squared_to(centro))
	if cerca.size() > cuantos:
		cerca.resize(cuantos)
	return cerca


## Un emisor: gotas blancas que saltan un poco y caen, en billboard, sin sombra.
func _emisor() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.amount = 40
	e.lifetime = 0.55
	e.explosiveness = 0.15
	e.randomness = 0.6
	e.emitting = false
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 4, 8))
	var proceso := ParticleProcessMaterial.new()
	# Nacen EN el agua, pegadas a la piedra: un anillo pequeño a su alrededor, a la cota
	# de la lámina, y no una caja por encima.
	proceso.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	proceso.emission_ring_axis = Vector3.UP
	proceso.emission_ring_radius = 0.45
	proceso.emission_ring_inner_radius = 0.2
	proceso.emission_ring_height = 0.05
	proceso.direction = Vector3(0, 1, 0)
	proceso.spread = 28.0
	proceso.initial_velocity_min = 1.6
	proceso.initial_velocity_max = 3.2
	# La gravedad de verdad: en medio segundo sube un palmo y vuelve al agua.
	proceso.gravity = Vector3(0, -9.8, 0)
	proceso.damping_min = 0.5
	proceso.damping_max = 1.5
	proceso.scale_min = 0.5
	proceso.scale_max = 1.0
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.9))
	curva.add_point(Vector2(0.5, 0.7))
	curva.add_point(Vector2(1.0, 0.0))
	var textura_de_curva := CurveTexture.new()
	textura_de_curva.curve = curva
	proceso.alpha_curve = textura_de_curva
	e.process_material = proceso
	var gota := QuadMesh.new()
	gota.size = Vector2(0.12, 0.36)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# De partículas: con billboard fijo en Y y el eje alineado a la velocidad no se pintaban
	# (captura de cerca, 2026-09-15). La gota va estirada en vertical, que es como se lee
	# el agua que salta.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.92, 0.95, 0.97, 0.55)
	# UNA GOTA REDONDA Y BLANDA: sin textura, cada partícula era un cuadrado blanco duro
	# (captura de cerca de Ultra, 2026-09-15).
	var degradado := Gradient.new()
	degradado.set_color(0, Color(1, 1, 1, 1))
	degradado.set_color(1, Color(1, 1, 1, 0))
	var gota_redonda := GradientTexture2D.new()
	gota_redonda.gradient = degradado
	gota_redonda.fill = GradientTexture2D.FILL_RADIAL
	gota_redonda.fill_from = Vector2(0.5, 0.5)
	gota_redonda.fill_to = Vector2(0.5, 0.0)
	gota_redonda.width = 32
	gota_redonda.height = 32
	material.albedo_texture = gota_redonda
	gota.material = material
	e.draw_pass_1 = gota
	return e
