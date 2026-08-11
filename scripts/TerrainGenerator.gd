@tool
class_name TerrainGenerator
extends Node3D
## Generador de terreno procedural con 3 capas de ruido.
## Genera altura, humedad y geología para el mundo.

signal generation_complete()
signal chunk_populated(chunk: Chunk)

## Tamaño del terreno en unidades
@export var terrain_size: Vector2i = Vector2i(128, 128):
	set(value):
		terrain_size = value
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Resolución del heightmap (vértices por lado)
@export var resolution: int = 129:
	set(value):
		resolution = clampi(value, 2, 513)
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Altura máxima del terreno
@export var max_height: float = 30.0:
	set(value):
		max_height = value
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Semilla para generación procedural
@export var seed_value: int = 12345:
	set(value):
		seed_value = value
		_update_noise_seeds()
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

@export_group("Height Noise")
@export var height_frequency: float = 0.02
@export var height_octaves: int = 5
@export var height_lacunarity: float = 2.0
@export var height_gain: float = 0.5

@export_group("Humidity Noise")
@export var humidity_frequency: float = 0.01
@export var humidity_octaves: int = 3

@export_group("Geology Noise")
@export var geology_frequency: float = 0.015
@export var geology_octaves: int = 4

@export_group("Debug")
@export var auto_generate: bool = false
@export var show_debug_gizmos: bool = false
@export var debug_layer: String = "height"  # height, humidity, geology

## Nodos de ruido
var _height_noise: FastNoiseLite
var _humidity_noise: FastNoiseLite
var _geology_noise: FastNoiseLite

## Datos generados
var _height_map: PackedFloat32Array
var _humidity_map: PackedFloat32Array
var _geology_map: PackedFloat32Array

## Mesh del terreno
var _terrain_mesh: MeshInstance3D
var _terrain_collision: StaticBody3D

## Manager del material del terreno (carga diferida)
var _material_manager: RefCounted

## Variable para regeneración en editor
var _regenerate_queued: bool = false

## Si usar shader triplanar (true) o colores de vértice (false)
@export var use_triplanar_shader: bool = true


func _ready() -> void:
	_setup_noise()
	# No generar automáticamente - se llama generate() desde el código que lo use
	# if not Engine.is_editor_hint():
	# 	generate()


func _process(_delta: float) -> void:
	if _regenerate_queued:
		_regenerate_queued = false
		generate()


func _queue_regenerate() -> void:
	_regenerate_queued = true


func _setup_noise() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = height_frequency
	_height_noise.fractal_octaves = height_octaves
	_height_noise.fractal_lacunarity = height_lacunarity
	_height_noise.fractal_gain = height_gain
	
	_humidity_noise = FastNoiseLite.new()
	_humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_humidity_noise.frequency = humidity_frequency
	_humidity_noise.fractal_octaves = humidity_octaves
	
	_geology_noise = FastNoiseLite.new()
	_geology_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_geology_noise.frequency = geology_frequency
	_geology_noise.fractal_octaves = geology_octaves
	
	_update_noise_seeds()


func _update_noise_seeds() -> void:
	if _height_noise:
		_height_noise.seed = seed_value
	if _humidity_noise:
		_humidity_noise.seed = seed_value + 1000
	if _geology_noise:
		_geology_noise.seed = seed_value + 2000


## Genera el terreno completo
func generate() -> void:
	_setup_noise()
	_generate_maps()
	_create_terrain_mesh()
	generation_complete.emit()


## Genera los mapas de ruido
func _generate_maps() -> void:
	var total_points := resolution * resolution
	_height_map.resize(total_points)
	_humidity_map.resize(total_points)
	_geology_map.resize(total_points)
	
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	
	for z in range(resolution):
		for x in range(resolution):
			var world_x := x * step_x
			var world_z := z * step_z
			var idx := z * resolution + x
			
			# Normalizar ruido de -1,1 a 0,1
			_height_map[idx] = (_height_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5
			_humidity_map[idx] = (_humidity_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5
			_geology_map[idx] = (_geology_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5


## Crea el mesh del terreno
func _create_terrain_mesh() -> void:
	# Limpiar mesh anterior
	if _terrain_mesh:
		_terrain_mesh.queue_free()
	if _terrain_collision:
		_terrain_collision.queue_free()
	
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	
	# Generar vértices
	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var height := _height_map[idx] * max_height
			var humidity := _humidity_map[idx]
			
			var pos := Vector3(x * step_x, height, z * step_z)
			
			# Color basado en altura y humedad para debug
			var color := _get_vertex_color(height / max_height, humidity)
			
			# UV basado en posición del mundo para tiling de texturas
			var uv := Vector2(pos.x / 4.0, pos.z / 4.0)
			
			st.set_color(color)
			st.set_uv(uv)
			st.add_vertex(pos)
	
	# Generar índices (triángulos) - CCW winding order visto desde arriba
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var top_left := z * resolution + x
			var top_right := top_left + 1
			var bottom_left := (z + 1) * resolution + x
			var bottom_right := bottom_left + 1
			
			# Primer triángulo (CCW: top_left -> top_right -> bottom_left)
			st.add_index(top_left)
			st.add_index(top_right)
			st.add_index(bottom_left)
			
			# Segundo triángulo (CCW: top_right -> bottom_right -> bottom_left)
			st.add_index(top_right)
			st.add_index(bottom_right)
			st.add_index(bottom_left)
	
	st.generate_normals()
	st.generate_tangents()
	
	var mesh := st.commit()
	
	_terrain_mesh = MeshInstance3D.new()
	_terrain_mesh.mesh = mesh
	_terrain_mesh.name = "TerrainMesh"
	
	# Aplicar material
	if use_triplanar_shader and not Engine.is_editor_hint():
		# Usar shader triplanar con texturas procedurales
		var manager_script := load("res://scripts/TerrainMaterialManager.gd")
		if manager_script:
			_material_manager = manager_script.new()
			var shader_material: ShaderMaterial = _material_manager.create_terrain_material()
			if shader_material:
				_material_manager.set_max_world_height(max_height)
				_terrain_mesh.material_override = shader_material
				print("Shader triplanar aplicado al terreno")
			else:
				# Fallback a material básico
				_apply_basic_material()
		else:
			push_warning("No se pudo cargar TerrainMaterialManager, usando material básico")
			_apply_basic_material()
	else:
		# Material básico con colores de vértice
		_apply_basic_material()
	
	add_child(_terrain_mesh)
	
	# Crear colisión
	_create_collision(mesh)


func _create_collision(mesh: Mesh) -> void:
	_terrain_collision = StaticBody3D.new()
	_terrain_collision.name = "TerrainCollision"
	
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = mesh.create_trimesh_shape()
	
	_terrain_collision.add_child(collision_shape)
	add_child(_terrain_collision)


func _apply_basic_material() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	_terrain_mesh.material_override = material


func _get_vertex_color(height_normalized: float, humidity: float) -> Color:
	# Gradiente de color basado en altura y humedad
	var base_color: Color
	
	if height_normalized < 0.2:
		# Agua/arena
		base_color = Color(0.76, 0.7, 0.5)
	elif height_normalized < 0.5:
		# Hierba
		base_color = Color(0.2, 0.5, 0.2).lerp(Color(0.1, 0.35, 0.1), humidity)
	elif height_normalized < 0.75:
		# Roca
		base_color = Color(0.5, 0.45, 0.4)
	else:
		# Nieve
		base_color = Color(0.95, 0.95, 0.98)
	
	return base_color


## Obtiene la altura en una posición del mundo
func get_height_at(world_pos: Vector3) -> float:
	var local_x := world_pos.x - global_position.x
	var local_z := world_pos.z - global_position.z
	
	if local_x < 0 or local_x > terrain_size.x or local_z < 0 or local_z > terrain_size.y:
		return 0.0
	
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	
	var grid_x := local_x / step_x
	var grid_z := local_z / step_z
	
	var x0 := int(floor(grid_x))
	var z0 := int(floor(grid_z))
	var x1 := mini(x0 + 1, resolution - 1)
	var z1 := mini(z0 + 1, resolution - 1)
	
	var fx := grid_x - x0
	var fz := grid_z - z0
	
	# Interpolación bilineal
	var h00 := _height_map[z0 * resolution + x0]
	var h10 := _height_map[z0 * resolution + x1]
	var h01 := _height_map[z1 * resolution + x0]
	var h11 := _height_map[z1 * resolution + x1]
	
	var h0 := lerpf(h00, h10, fx)
	var h1 := lerpf(h01, h11, fx)
	var height := lerpf(h0, h1, fz)
	
	return height * max_height


## Obtiene la humedad en una posición del mundo (0-1)
func get_humidity_at(world_pos: Vector3) -> float:
	return _get_map_value_at(world_pos, _humidity_map)


## Obtiene el valor de geología en una posición del mundo (0-1)
func get_geology_at(world_pos: Vector3) -> float:
	return _get_map_value_at(world_pos, _geology_map)


func _get_map_value_at(world_pos: Vector3, map: PackedFloat32Array) -> float:
	if map.is_empty():
		return 0.0
	
	var local_x := world_pos.x - global_position.x
	var local_z := world_pos.z - global_position.z
	
	if local_x < 0 or local_x > terrain_size.x or local_z < 0 or local_z > terrain_size.y:
		return 0.0
	
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	
	var x := clampi(int(local_x / step_x), 0, resolution - 1)
	var z := clampi(int(local_z / step_z), 0, resolution - 1)
	
	return map[z * resolution + x]


## Calcula la pendiente (slope) en una posición del mundo
func get_slope_at(world_pos: Vector3) -> float:
	var h := get_height_at(world_pos)
	var hx := get_height_at(world_pos + Vector3(1, 0, 0))
	var hz := get_height_at(world_pos + Vector3(0, 0, 1))
	
	var dx := hx - h
	var dz := hz - h
	
	return sqrt(dx * dx + dz * dz)


## Puebla un Chunk con recursos basados en la geología
func populate_chunk_resources(chunk: Chunk, materials_map: Dictionary, threshold: float = 0.5) -> void:
	var chunk_world_pos := chunk.global_position
	
	for z in range(chunk.chunk_size.y):
		for x in range(chunk.chunk_size.x):
			var cell_world_pos := Vector3(
				chunk_world_pos.x + x * chunk.cell_size + chunk.cell_size * 0.5,
				0,
				chunk_world_pos.z + z * chunk.cell_size + chunk.cell_size * 0.5
			)
			cell_world_pos.y = get_height_at(cell_world_pos)
			
			var geology := get_geology_at(cell_world_pos)
			
			# Determinar qué material colocar basado en geología
			if geology > threshold:
				# Hierro en geología alta
				if materials_map.has("iron"):
					var amount := (geology - threshold) * 100.0  # 0-50 unidades
					chunk.add_resource_at(cell_world_pos, materials_map["iron"], amount)
			elif geology < (1.0 - threshold):
				# Carbón en geología baja
				if materials_map.has("coal"):
					var amount := ((1.0 - threshold) - geology) * 80.0
					chunk.add_resource_at(cell_world_pos, materials_map["coal"], amount)
			
			# Piedra en pendientes
			var slope := get_slope_at(cell_world_pos)
			if slope > 0.5 and materials_map.has("stone"):
				chunk.add_resource_at(cell_world_pos, materials_map["stone"], slope * 50.0)
	
	chunk_populated.emit(chunk)


## Obtiene posiciones válidas para vegetación basadas en humedad y pendiente
func get_vegetation_positions(min_humidity: float = 0.4, max_slope: float = 0.5, spacing: float = 3.0) -> PackedVector3Array:
	var positions: PackedVector3Array = []
	
	var step := spacing
	var x := 0.0
	while x < terrain_size.x:
		var z := 0.0
		while z < terrain_size.y:
			var world_pos := Vector3(x, 0, z) + global_position
			var humidity := get_humidity_at(world_pos)
			var slope := get_slope_at(world_pos)
			
			if humidity >= min_humidity and slope <= max_slope:
				var height := get_height_at(world_pos)
				# No colocar vegetación en zonas muy bajas (agua) o muy altas (nieve)
				var normalized_height := height / max_height
				if normalized_height > 0.15 and normalized_height < 0.7:
					positions.append(Vector3(x, height, z) + global_position)
			
			z += step
		x += step
	
	return positions
