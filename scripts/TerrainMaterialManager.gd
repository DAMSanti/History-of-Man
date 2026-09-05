class_name TerrainMaterialManager
extends RefCounted
## Gestiona el material del terreno con shader triplanar.
## Genera y aplica texturas procedurales al terreno.

var _material: ShaderMaterial
var _textures: Dictionary = {}


## Crea el material del terreno con shader triplanar
func create_terrain_material() -> ShaderMaterial:
	_material = ShaderMaterial.new()
	
	# Cargar el shader triplanar
	var shader := load("res://shaders/triplanar.gdshader") as Shader
	if not shader:
		push_error("No se pudo cargar el shader triplanar")
		return null
	
	_material.shader = shader
	
	# Generar texturas procedurales
	_generate_textures()
	
	# Aplicar texturas al shader
	_apply_textures()
	
	# Configurar parámetros del shader
	_configure_shader_params()
	
	print("Material de terreno creado con shader triplanar")
	
	return _material


func _generate_textures() -> void:
	print("Generando texturas de terreno...")
	_textures = ProceduralTextureGenerator.get_terrain_textures()


func _apply_textures() -> void:
	if not _material:
		return
	
	# Texturas de albedo
	if _textures.has("grass"):
		_material.set_shader_parameter("texture_grass", _textures["grass"])
	if _textures.has("rock"):
		_material.set_shader_parameter("texture_rock", _textures["rock"])
	if _textures.has("snow"):
		_material.set_shader_parameter("texture_snow", _textures["snow"])
	if _textures.has("sand"):
		_material.set_shader_parameter("texture_sand", _textures["sand"])
	
	# Normal maps
	if _textures.has("grass_normal"):
		_material.set_shader_parameter("normal_grass", _textures["grass_normal"])
	if _textures.has("rock_normal"):
		_material.set_shader_parameter("normal_rock", _textures["rock_normal"])
	if _textures.has("snow_normal"):
		_material.set_shader_parameter("normal_snow", _textures["snow_normal"])
	if _textures.has("sand_normal"):
		_material.set_shader_parameter("normal_sand", _textures["sand_normal"])


func _configure_shader_params() -> void:
	if not _material:
		return
	
	# Escala de textura - mayor = más detalle visible
	_material.set_shader_parameter("texture_scale", 0.15)
	
	# Sharpness del blend entre materiales (más bajo = transiciones más suaves)
	_material.set_shader_parameter("blend_sharpness", 1.5)
	
	# Sharpness del triplanar
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
	_material.set_shader_parameter("slope_threshold", 0.15)
	_material.set_shader_parameter("slope_blend", 0.20)
	
	# Propiedades de material. Todo muy mate a proposito: ninguna superficie
	# natural de este mapa -hierba, tierra, caliza- refleja de forma especular.
	_material.set_shader_parameter("roughness_grass", 0.95)
	_material.set_shader_parameter("roughness_rock", 0.94)
	_material.set_shader_parameter("roughness_snow", 0.85)
	_material.set_shader_parameter("roughness_sand", 0.97)
	_material.set_shader_parameter("terrain_specular", 0.08)
	if _textures.has("water_normal"):
		_material.set_shader_parameter("water_normal_tex", _textures["water_normal"])
	if _textures.has("water_foam"):
		_material.set_shader_parameter("water_foam_tex", _textures["water_foam"])


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
