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
	_textures = ProceduralTextureGenerator.generate_all_terrain_textures()


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
	_material.set_shader_parameter("slope_threshold", 0.55)
	_material.set_shader_parameter("slope_blend", 0.25)
	
	# Propiedades de material (roughness)
	_material.set_shader_parameter("roughness_grass", 0.88)
	_material.set_shader_parameter("roughness_rock", 0.92)
	_material.set_shader_parameter("roughness_snow", 0.55)
	_material.set_shader_parameter("roughness_sand", 0.95)


## Obtiene el material
func get_material() -> ShaderMaterial:
	return _material


## Actualiza la altura máxima del mundo en el shader
func set_max_world_height(height: float) -> void:
	if _material:
		_material.set_shader_parameter("max_world_height", height)
