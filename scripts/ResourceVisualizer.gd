class_name ResourceVisualizer
extends Node3D
## Visualiza los recursos del Chunk en el mundo usando MultiMesh para eficiencia.
## Muestra rocas, vetas de mineral, etc. según el tipo de recurso.

signal resource_clicked(world_pos: Vector3, material: RawMaterial)

## Referencia al Chunk que contiene los recursos
@export var chunk: Chunk

## Referencia al TerrainGenerator para obtener alturas
@export var terrain: TerrainGenerator

## Escala base de los recursos visuales
@export var resource_scale: float = 1.0

## Máximo de instancias por tipo de recurso
@export var max_instances_per_type: int = 1000

## Colores por tipo de material
var _material_colors: Dictionary = {
	"iron": Color(0.6, 0.3, 0.2),      # Marrón rojizo
	"coal": Color(0.15, 0.12, 0.1),    # Negro carbón
	"stone": Color(0.5, 0.48, 0.45),   # Gris piedra
	"copper": Color(0.72, 0.45, 0.2),  # Naranja cobre
	"clay": Color(0.7, 0.5, 0.35),     # Marrón arcilla
	"wood": Color(0.4, 0.26, 0.13),    # Marrón madera
}

## MultiMesh por tipo de material
var _multimesh_instances: Dictionary = {}

## Mesh base para recursos (roca/mineral)
var _rock_mesh: Mesh
var _ore_mesh: Mesh


func _ready() -> void:
	_create_meshes()


func _create_meshes() -> void:
	# Crear mesh de roca (icosaedro irregular)
	_rock_mesh = _create_rock_mesh()
	
	# Crear mesh de mineral (cristal/veta)
	_ore_mesh = _create_ore_mesh()


func _create_rock_mesh() -> ArrayMesh:
	# Roca irregular usando un icosaedro deformado
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Crear forma de roca irregular
	var points: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	# Generar puntos de un icosaedro con perturbación
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var base_points: Array[Vector3] = [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)
	]
	
	for p: Vector3 in base_points:
		var perturbed: Vector3 = p.normalized() * (0.4 + rng.randf() * 0.3)
		# Aplanar un poco para que parezca más una roca
		perturbed.y *= 0.6
		points.append(perturbed)
	
	# Triángulos del icosaedro
	var triangles: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
	]
	
	for tri in triangles:
		# Color blanco para que el color de instancia se use directamente
		st.set_color(Color.WHITE)
		st.add_vertex(points[tri[0]])
		st.set_color(Color.WHITE)
		st.add_vertex(points[tri[1]])
		st.set_color(Color.WHITE)
		st.add_vertex(points[tri[2]])
	
	st.generate_normals()
	return st.commit()


func _create_ore_mesh() -> ArrayMesh:
	# Cristal/veta de mineral - forma más angular
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Crear forma de cristal hexagonal
	var height := 0.8
	var radius := 0.3
	var segments := 6
	
	# Vértices superiores e inferiores
	var top := Vector3(0, height * 0.5, 0)
	var bottom := Vector3(0, -height * 0.3, 0)
	
	for i in range(segments):
		var angle1 := float(i) / float(segments) * TAU
		var angle2 := float(i + 1) / float(segments) * TAU
		
		var p1 := Vector3(cos(angle1) * radius, 0, sin(angle1) * radius)
		var p2 := Vector3(cos(angle2) * radius, 0, sin(angle2) * radius)
		
		# Triángulos hacia arriba - color blanco para usar color de instancia
		st.set_color(Color.WHITE)
		st.add_vertex(p1)
		st.set_color(Color.WHITE)
		st.add_vertex(p2)
		st.set_color(Color.WHITE)
		st.add_vertex(top)
		
		# Triángulos hacia abajo
		st.set_color(Color.WHITE)
		st.add_vertex(p2)
		st.set_color(Color.WHITE)
		st.add_vertex(p1)
		st.set_color(Color.WHITE)
		st.add_vertex(bottom)
	
	st.generate_normals()
	return st.commit()


## Inicializa la visualización conectándose al Chunk
func initialize(_chunk: Chunk, _terrain: TerrainGenerator) -> void:
	chunk = _chunk
	terrain = _terrain
	
	# Conectar señales del chunk
	if chunk:
		chunk.resource_added.connect(_on_resource_added)
		chunk.resource_removed.connect(_on_resource_removed)
	
	# Crear visualización inicial
	refresh_all()


## Refresca toda la visualización de recursos
func refresh_all() -> void:
	if not chunk:
		print("ResourceVisualizer: No hay chunk asignado")
		return
	
	# Limpiar visualizaciones anteriores
	_clear_all_visuals()
	
	# Agrupar recursos por tipo de material
	var resources_by_type: Dictionary = {}
	
	var cells := chunk.get_all_resource_cells()
	print("ResourceVisualizer: Encontradas ", cells.size(), " celdas con recursos")
	
	for cell: Vector2i in cells:
		var deposits: Array = chunk.get_resources_at_cell(cell)
		for deposit in deposits:
			if deposit.material:
				var mat_name: String = deposit.material.display_name.to_lower()
				if not resources_by_type.has(mat_name):
					resources_by_type[mat_name] = []
				
				# Obtener posición del mundo para esta celda
				var world_pos: Vector3 = chunk.cell_to_world(cell)
				if terrain:
					world_pos.y = terrain.get_height_at(world_pos) + 0.2  # Ligeramente sobre el suelo
				
				resources_by_type[mat_name].append({
					"position": world_pos,
					"amount": deposit.amount,
					"quality": deposit.quality
				})
	
	# Crear MultiMesh para cada tipo
	for mat_name: String in resources_by_type.keys():
		var resources: Array = resources_by_type[mat_name]
		print("  - ", mat_name, ": ", resources.size(), " depósitos")
		_create_multimesh_for_material(mat_name, resources)
	
	print("ResourceVisualizer: ", resources_by_type.size(), " tipos de recursos visualizados")


func _create_multimesh_for_material(mat_name: String, resources: Array) -> void:
	if resources.is_empty():
		return
	
	# Crear MultiMesh
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	
	# Usar mesh de roca para piedra, ore mesh para minerales
	if mat_name in ["stone", "clay"]:
		multimesh.mesh = _rock_mesh
	else:
		multimesh.mesh = _ore_mesh
	
	var count := mini(resources.size(), max_instances_per_type)
	multimesh.instance_count = count
	
	# Color del material
	var base_color: Color = _material_colors.get(mat_name, Color(0.5, 0.5, 0.5))
	
	# Configurar cada instancia
	var rng := RandomNumberGenerator.new()
	rng.seed = mat_name.hash()
	
	for i in range(count):
		var res: Dictionary = resources[i]
		var pos: Vector3 = res["position"]
		var amount: float = res["amount"]
		var quality: float = res["quality"]
		
		# Escala basada en cantidad
		var scale_factor := resource_scale * (0.5 + (amount / 200.0) * 0.5)
		scale_factor = clampf(scale_factor, 0.3, 1.5)
		
		# Rotación aleatoria
		var rotation := rng.randf() * TAU
		
		# Pequeño offset aleatorio
		var offset := Vector3(
			(rng.randf() - 0.5) * 0.5,
			0,
			(rng.randf() - 0.5) * 0.5
		)
		
		var transform := Transform3D()
		transform = transform.rotated(Vector3.UP, rotation)
		transform = transform.scaled(Vector3.ONE * scale_factor)
		transform.origin = pos + offset
		
		multimesh.set_instance_transform(i, transform)
		
		# Color con variación por calidad
		var color_variation := base_color.lightened((quality - 0.5) * 0.2)
		color_variation = color_variation.darkened(rng.randf() * 0.1)
		multimesh.set_instance_color(i, color_variation)
	
	# Crear MeshInstance3D
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.name = "Resources_" + mat_name
	
	# Material
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	material.metallic = 0.1 if mat_name in ["iron", "copper"] else 0.0
	if mat_name in ["iron", "copper"]:
		material.metallic = 0.3
	instance.material_override = material
	
	add_child(instance)
	_multimesh_instances[mat_name] = instance


func _clear_all_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_multimesh_instances.clear()


func _on_resource_added(_world_pos: Vector3, _material: RawMaterial, _amount: float) -> void:
	# Refrescar cuando se añade un recurso
	pass  # No refrescar automáticamente para evitar lag


func _on_resource_removed(_world_pos: Vector3, _index: int) -> void:
	# Refrescar cuando se quita un recurso
	pass  # No refrescar automáticamente para evitar lag


## Obtiene el material de recurso en una posición (para clicks)
func get_resource_at_position(world_pos: Vector3, _radius: float = 1.0) -> RawMaterial:
	if not chunk:
		return null
	
	var cell := chunk.world_to_cell(world_pos)
	var deposits := chunk.get_resources_at_cell(cell)
	
	if deposits.is_empty():
		return null
	
	return deposits[0].material
