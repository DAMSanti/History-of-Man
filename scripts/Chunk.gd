class_name Chunk
extends Node3D
## Representa un fragmento del mapa que contiene recursos físicos en celdas.
## Cada celda puede contener múltiples depósitos de recursos.

signal resource_added(world_pos: Vector3, material: RawMaterial, amount: float)
signal resource_removed(world_pos: Vector3, index: int)
signal resource_depleted(world_pos: Vector3)

## Tamaño del chunk en unidades del mundo (ancho y largo)
@export var chunk_size: Vector2i = Vector2i(32, 32)

## Tamaño de cada celda en unidades del mundo
@export var cell_size: float = 1.0

## Posición del chunk en coordenadas de chunk (no mundo)
@export var chunk_coords: Vector2i = Vector2i.ZERO

## Datos de recursos: Dictionary[Vector2i, Array[ResourceDeposit]]
## Cada celda (Vector2i) contiene un array de depósitos
var _resources: Dictionary = {}

## Estructura interna para un depósito de recurso
class ResourceDeposit:
	var material: RawMaterial
	var amount: float  # Cantidad en unidades (kg, litros, etc.)
	var quality: float  # Calidad 0.0-1.0
	
	func _init(mat: RawMaterial = null, amt: float = 0.0, qual: float = 1.0) -> void:
		material = mat
		amount = amt
		quality = qual
	
	func to_dict() -> Dictionary:
		return {
			"material_path": material.resource_path if material else "",
			"amount": amount,
			"quality": quality
		}


func _ready() -> void:
	# Inicializar el diccionario de recursos vacío
	_resources = {}


## Convierte una posición del mundo a coordenadas de celda local
func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_pos := world_pos - global_position
	var cell_x := int(floor(local_pos.x / cell_size))
	var cell_z := int(floor(local_pos.z / cell_size))
	return Vector2i(cell_x, cell_z)


## Convierte coordenadas de celda a posición del mundo (centro de la celda)
func cell_to_world(cell: Vector2i) -> Vector3:
	var x := global_position.x + (cell.x + 0.5) * cell_size
	var z := global_position.z + (cell.y + 0.5) * cell_size
	return Vector3(x, global_position.y, z)


## Comprueba si una celda está dentro de los límites del chunk
func is_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < chunk_size.x and cell.y >= 0 and cell.y < chunk_size.y


## Añade un recurso en una posición del mundo
func add_resource_at(world_pos: Vector3, material: RawMaterial, amount: float, quality: float = 1.0) -> bool:
	var cell := world_to_cell(world_pos)
	
	if not is_cell_valid(cell):
		push_warning("Chunk: Intentando añadir recurso fuera de límites: ", cell)
		return false
	
	if not _resources.has(cell):
		_resources[cell] = []
	
	# Buscar si ya existe un depósito del mismo material
	for deposit: ResourceDeposit in _resources[cell]:
		if deposit.material == material:
			# Añadir al depósito existente
			var old_amount := deposit.amount
			deposit.amount += amount
			# Promediar la calidad ponderada
			deposit.quality = (deposit.quality * old_amount + quality * amount) / deposit.amount
			resource_added.emit(world_pos, material, amount)
			return true
	
	# Crear nuevo depósito
	var new_deposit := ResourceDeposit.new(material, amount, quality)
	_resources[cell].append(new_deposit)
	resource_added.emit(world_pos, material, amount)
	return true


## Obtiene todos los recursos en una posición del mundo
func get_resources_at(world_pos: Vector3) -> Array:
	var cell := world_to_cell(world_pos)
	
	if not is_cell_valid(cell) or not _resources.has(cell):
		return []
	
	return _resources[cell].duplicate()


## Obtiene la cantidad de un material específico en una posición
func get_resource_amount(world_pos: Vector3, material: RawMaterial) -> float:
	var cell := world_to_cell(world_pos)
	
	if not is_cell_valid(cell) or not _resources.has(cell):
		return 0.0
	
	for deposit: ResourceDeposit in _resources[cell]:
		if deposit.material == material:
			return deposit.amount
	
	return 0.0


## Elimina un recurso por índice en una posición del mundo
func remove_resource_at(world_pos: Vector3, index: int) -> bool:
	var cell := world_to_cell(world_pos)
	
	if not is_cell_valid(cell) or not _resources.has(cell):
		return false
	
	if index < 0 or index >= _resources[cell].size():
		return false
	
	_resources[cell].remove_at(index)
	resource_removed.emit(world_pos, index)
	
	# Limpiar celda si está vacía
	if _resources[cell].is_empty():
		_resources.erase(cell)
		resource_depleted.emit(world_pos)
	
	return true


## Extrae una cantidad de un material específico (para recolección)
## Retorna la cantidad realmente extraída
func extract_resource(world_pos: Vector3, material: RawMaterial, amount: float) -> float:
	var cell := world_to_cell(world_pos)
	
	if not is_cell_valid(cell) or not _resources.has(cell):
		return 0.0
	
	for i in range(_resources[cell].size()):
		var deposit: ResourceDeposit = _resources[cell][i]
		if deposit.material == material:
			var extracted := minf(amount, deposit.amount)
			deposit.amount -= extracted
			
			if deposit.amount <= 0.0:
				_resources[cell].remove_at(i)
				if _resources[cell].is_empty():
					_resources.erase(cell)
					resource_depleted.emit(world_pos)
			
			return extracted
	
	return 0.0


## Obtiene el material más duro en una posición (para cálculos de construcción)
func get_hardest_material_at(world_pos: Vector3) -> RawMaterial:
	var resources := get_resources_at(world_pos)
	var hardest: RawMaterial = null
	var max_hardness := -1.0
	
	for deposit: ResourceDeposit in resources:
		if deposit.material and deposit.material.hardness > max_hardness:
			max_hardness = deposit.material.hardness
			hardest = deposit.material
	
	return hardest


## Obtiene el peso total de recursos en una posición
func get_total_weight_at(world_pos: Vector3) -> float:
	var resources := get_resources_at(world_pos)
	var total_weight := 0.0
	
	for deposit: ResourceDeposit in resources:
		if deposit.material:
			# Asumiendo que 1 unidad = 1 m³ para simplificar
			total_weight += deposit.material.calculate_weight(deposit.amount)
	
	return total_weight


## Obtiene todas las celdas que contienen recursos
func get_all_resource_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _resources.keys():
		cells.append(cell)
	return cells


## Obtiene los recursos en una celda específica (por coordenadas de celda)
func get_resources_at_cell(cell: Vector2i) -> Array:
	if not is_cell_valid(cell) or not _resources.has(cell):
		return []
	return _resources[cell].duplicate()


## Limpia todos los recursos del chunk
func clear_all_resources() -> void:
	_resources.clear()


## Serializa el chunk a un diccionario para guardado
func serialize() -> Dictionary:
	var data := {
		"chunk_coords": [chunk_coords.x, chunk_coords.y],
		"chunk_size": [chunk_size.x, chunk_size.y],
		"cell_size": cell_size,
		"resources": {}
	}
	
	for cell: Vector2i in _resources.keys():
		var cell_key := "%d,%d" % [cell.x, cell.y]
		var deposits := []
		for deposit: ResourceDeposit in _resources[cell]:
			deposits.append(deposit.to_dict())
		data["resources"][cell_key] = deposits
	
	return data


## Deserializa el chunk desde un diccionario
func deserialize(data: Dictionary) -> void:
	if data.has("chunk_coords"):
		chunk_coords = Vector2i(data["chunk_coords"][0], data["chunk_coords"][1])
	if data.has("chunk_size"):
		chunk_size = Vector2i(data["chunk_size"][0], data["chunk_size"][1])
	if data.has("cell_size"):
		cell_size = data["cell_size"]
	
	_resources.clear()
	
	if data.has("resources"):
		for cell_key: String in data["resources"].keys():
			var parts := cell_key.split(",")
			var cell := Vector2i(int(parts[0]), int(parts[1]))
			_resources[cell] = []
			
			for deposit_data: Dictionary in data["resources"][cell_key]:
				var mat_path: String = deposit_data.get("material_path", "")
				var material: RawMaterial = null
				if not mat_path.is_empty() and ResourceLoader.exists(mat_path):
					material = load(mat_path) as RawMaterial
				
				var deposit := ResourceDeposit.new(
					material,
					deposit_data.get("amount", 0.0),
					deposit_data.get("quality", 1.0)
				)
				_resources[cell].append(deposit)
