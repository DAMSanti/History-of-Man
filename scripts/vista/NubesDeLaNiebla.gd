class_name NubesDeLaNiebla
extends MeshInstance3D
## Las nubes que tapan lo no descubierto del mapa regional, **con volumen** (GRAFICOS §3).
##
## Petición del usuario del 2026-09-16: «las nubes son un plano sobre el mapa regional,
## quiero que tengan volumen, altura». Antes se pintaban en el propio relieve —con altura y
## sombra fingidas— y por eso se leían pegadas al suelo. Esto es **una losa de aire sobre la
## comarca** que el shader recorre (`nubes_con_volumen.gdshader`): se tapan entre ellas, se
## dan sombra y los montes altos asoman por encima.
##
## **Debajo sigue la calima lisa del relieve**, que es la que garantiza que de lo no
## descubierto no se vea ni un río: esto es el aspecto, no el tapado.
##
## Es vista: no toca la partida, y se mueve con el reloj ([Viento]).

## Entre qué cotas está la capa de nubes, en metros sobre el nivel del mar de la época.
## Decisión mirando capturas: por encima de casi toda Cantabria y por debajo de los Picos,
## que asoman.
const BASE_M := 800.0
const TECHO_M := 3200.0

## El tamaño de la nube, en metros: el ancho de un banco. **Grande**: con 26 km la tesela
## del ruido se repetía ocho veces sobre la comarca y se veía la cuadrícula (captura del
## 2026-09-16).
const NUBE_M := 50000.0

var _material: ShaderMaterial = null
var _ruido: NoiseTexture3D = null


## Monta la losa sobre el relieve regional, con la textura de lo visto.
func montar(terreno: TerrainGenerator, niebla_tex: Texture2D, metros_por_unidad: float,
		exageracion: float) -> void:
	name = "NubesDeLaNiebla"
	var lado_x := float(terreno.terrain_size.x)
	var lado_z := float(terreno.terrain_size.y)
	var base := BASE_M / metros_por_unidad * exageracion
	var techo := TECHO_M / metros_por_unidad * exageracion
	var caja := BoxMesh.new()
	caja.size = Vector3(lado_x, techo - base, lado_z)
	mesh = caja
	position = Vector3(lado_x * 0.5, (base + techo) * 0.5, lado_z * 0.5)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Que no la recorte el cuadro de la caja: se mira desde fuera y desde dentro.
	extra_cull_margin = maxf(lado_x, lado_z)
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/nubes_con_volumen.gdshader") as Shader
	_material.set_shader_parameter("caja_min", Vector3(0.0, base, 0.0))
	_material.set_shader_parameter("caja_max", Vector3(lado_x, techo, lado_z))
	_material.set_shader_parameter("fog_world_size", Vector2(lado_x, lado_z))
	_material.set_shader_parameter("nube_m", NUBE_M / metros_por_unidad)
	_material.set_shader_parameter("nube_tex", _ruido_de_la_nube())
	material_override = _material
	poner_la_niebla(niebla_tex)


## La textura de lo visto, cuando cambia.
func poner_la_niebla(niebla_tex: Texture2D) -> void:
	if _material != null and niebla_tex != null:
		_material.set_shader_parameter("fog_tex", niebla_tex)


## Lo que ha corrido el viento de la partida. Lo llama la escena cada cuadro.
func mover(recorrido: float) -> void:
	if _material != null:
		_material.set_shader_parameter("viento", recorrido)


## El ruido de la nube: **en tres dimensiones**, que es lo que distingue una nube con
## volumen de una textura estirada.
func _ruido_de_la_nube() -> Texture3D:
	if _ruido != null:
		return _ruido
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.03
	ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
	ruido.fractal_octaves = 4
	_ruido = NoiseTexture3D.new()
	_ruido.noise = ruido
	_ruido.seamless = true
	_ruido.width = 96
	_ruido.height = 96
	_ruido.depth = 96
	return _ruido
