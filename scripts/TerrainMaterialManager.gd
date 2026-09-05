class_name TerrainMaterialManager
extends RefCounted
## Gestiona el material del terreno con shader triplanar.
##
## Antes generaba cuatro texturas procedurales píxel a píxel y las ataba a ocho
## samplers sueltos. Ahora carga los tres [Texture2DArray] que deja
## `scripts/tools/TerrainTextureIngest.gd` —ocho capas de fotogrametría con
## albedo, normal y ORM— y sólo sigue generando las del agua, que son patrones
## que teselan y no fotografías.

## Dónde avisar si faltan los arrays. Se regeneran con la herramienta y no van
## al repositorio, así que en una copia recién clonada no están.
const MISSING_HINT := "Faltan las texturas del terreno. Genéralas con:\n" \
	+ "  godot --headless --path . --script res://scripts/tools/TerrainTextureIngest.gd"

var _material: ShaderMaterial
var _arrays: TerrainTextureArrays
var _water: Dictionary = {}


## Crea el material del terreno con shader triplanar
func create_terrain_material() -> ShaderMaterial:
	_material = ShaderMaterial.new()

	var shader := load("res://shaders/triplanar.gdshader") as Shader
	if not shader:
		push_error("No se pudo cargar el shader triplanar")
		return null
	_material.shader = shader

	_load_arrays()
	_load_water_textures()
	_configure_shader_params()

	return _material


func _load_arrays() -> void:
	if not ResourceLoader.exists(TerrainLayers.ARRAYS_PATH):
		push_error(MISSING_HINT)
		return

	_arrays = load(TerrainLayers.ARRAYS_PATH) as TerrainTextureArrays
	if _arrays == null or not _arrays.is_usable():
		# Que el recurso exista no basta: puede ser de una ingesta anterior con
		# otro número de capas, y entonces los índices del shader apuntarían a
		# materiales cambiados de sitio.
		push_error("Las texturas del terreno no coinciden con %d capas. %s"
			% [TerrainLayers.COUNT, MISSING_HINT])
		_arrays = null
		return

	_material.set_shader_parameter("terrain_albedo", _arrays.albedo())
	_material.set_shader_parameter("terrain_normal", _arrays.normal())
	_material.set_shader_parameter("terrain_orm", _arrays.orm())
	_material.set_shader_parameter("layer_tile_m", TerrainLayers.tiles_in_order())

	print("Terreno: %d capas de %d px" % [_arrays.layers, _arrays.size])


## Las del agua siguen siendo procedurales, y con motivo: son patrones que
## tienen que teselar EXACTAMENTE y desfilar sobre el cauce, y eso se construye
## con senos de periodo entero. Una fotografía de agua no tesela sin costura.
func _load_water_textures() -> void:
	_water = ProceduralTextureGenerator.get_water_textures()
	if _water.has("water_normal"):
		_material.set_shader_parameter("water_normal_tex", _water["water_normal"])
	if _water.has("water_foam"):
		_material.set_shader_parameter("water_foam_tex", _water["water_foam"])


func _configure_shader_params() -> void:
	if not _material:
		return

	# Sharpness del blend entre materiales (más bajo = transiciones más suaves)
	_material.set_shader_parameter("blend_sharpness", 1.5)
	_material.set_shader_parameter("triplanar_sharpness", 2.5)

	# Configuración de alturas para el blend (valores normalizados 0-1)
	_material.set_shader_parameter("grass_max_height", 0.45)
	_material.set_shader_parameter("rock_min_height", 0.35)
	_material.set_shader_parameter("rock_max_height", 0.70)
	_material.set_shader_parameter("snow_min_height", 0.65)
	_material.set_shader_parameter("sand_max_height", 0.15)
	_material.set_shader_parameter("max_world_height", 30.0)

	# Configuración de pendiente - pendientes pronunciadas muestran más roca
	# `slope` es 1 - |normal.y|. Empezo en 0.55 -unos 63 grados, casi solo
	# cortados- y por eso no salia una piedra en ninguna ladera. Bajo a 0.26
	# (42 grados) y seguia siendo poco.
	#
	# Ahora 0.15 son unos 32 grados, que en terreno calizo es de sobra donde
	# aflora: por encima de esa pendiente el suelo no se sostiene. Y el blend
	# es ancho a proposito -0.20- para que la transicion sea un manto de
	# derrubio que va clareando, no una linea de nivel pintada en la ladera.
	#
	# Ese manto ya no es un degradado de color: entre el pasto y la pared hay
	# una capa propia, el CANCHAL, que sale de la mitad baja de este mismo
	# margen. Ver el reparto de pesos en el shader.
	_material.set_shader_parameter("slope_threshold", 0.15)
	_material.set_shader_parameter("slope_blend", 0.20)

	# La rugosidad ya no es una constante por material: la trae el canal verde
	# del ORM. Aquí sólo queda el margen para retocarla en bloque.
	_material.set_shader_parameter("use_orm", true)
	_material.set_shader_parameter("roughness_scale", 1.0)
	_material.set_shader_parameter("ao_strength", 0.8)
	_material.set_shader_parameter("terrain_specular", 0.08)


## Obtiene el material
func get_material() -> ShaderMaterial:
	return _material


## Ajusta las bandas de altura del blend (valores normalizados 0-1).
## Los defaults estan pensados para terreno procedural; con elevacion real hay
## que recolocarlas o la arena se come media montana.
func set_height_bands(sand_max: float, grass_max: float, rock_min: float, rock_max: float, snow_min: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("sand_max_height", sand_max)
	_material.set_shader_parameter("grass_max_height", grass_max)
	_material.set_shader_parameter("rock_min_height", rock_min)
	_material.set_shader_parameter("rock_max_height", rock_max)
	_material.set_shader_parameter("snow_min_height", snow_min)


## Activa el apagado del terreno fuera de la region jugable
func set_region_mask_enabled(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter("use_region_mask", enabled)


## Cambia la mascara de region. Barata: es solo cambiar la textura, asi que
## el area jugable puede seguir a la cota del mar sin rehacer la malla.
func set_region_mask_texture(texture: Texture2D, world_size: Vector2) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("region_mask_tex", texture)
	_material.set_shader_parameter("region_world_size", world_size)


## Actualiza la altura máxima del mundo en el shader
func set_max_world_height(height: float) -> void:
	if _material:
		_material.set_shader_parameter("max_world_height", height)


## Reescala las bandas por un factor.
##
## Sirve para subir el techo de normalizacion sin mover NADA de sitio: el
## shader compara `y / max_world_height` contra las bandas, asi que si el techo
## se multiplica por 1/k y las bandas por k, la misma cota absoluta sigue
## cayendo en la misma banda. Es lo que permite que el contorno -que llega mas
## alto que el recuadro- deje de saturar sin que el terreno jugable cambie de
## aspecto ni un pixel.
func scale_height_bands(k: float) -> void:
	if not _material or k <= 0.0:
		return
	for name: String in ["sand_max_height", "grass_max_height",
			"rock_min_height", "rock_max_height", "snow_min_height"]:
		var value: float = _material.get_shader_parameter(name)
		_material.set_shader_parameter(name, value * k)
