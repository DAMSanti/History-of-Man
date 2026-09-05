class_name Architecto
extends Node
## Sistema de arquitectura y construcción.
## Verifica si una construcción puede colocarse basándose en el material del suelo.
## Gestiona el sistema de colapso estructural.

signal building_placed(world_pos: Vector3, building: Node3D)
signal building_collapsed(world_pos: Vector3, building: Node3D)
signal placement_denied(world_pos: Vector3, reason: String)

## Factor de peso para cálculos de soporte: kg que aguanta cada punto de dureza.
## weight / weight_factor debe ser menor que la hardness del material del suelo.
## Recalibrado de 100 a 2500 al pasar los edificios a BlockData con pesos
## reales: una cabaña de piedra pesa ~7 t, que con el factor antiguo exigía
## dureza 72 cuando el material más duro del juego (piedra) tiene 6.5, así que
## no se podía construir en ninguna parte. Con 2500 una cabaña se sostiene en
## tierra normal y una estructura de 20 t ya necesita suelo rocoso.
@export var weight_factor: float = 2500.0

## Factor de seguridad para colapsos (margen de error)
@export var safety_factor: float = 0.8

## Tiempo de delay antes del colapso (segundos)
@export var collapse_delay: float = 0.5

## Referencia al Chunk activo
var _active_chunk: Chunk

## Referencia al TerrainGenerator
var _terrain: TerrainGenerator

## Registro de edificios colocados: Dictionary[Vector3, BuildingData]
var _buildings: Dictionary = {}

## Estructura para datos de edificio
class BuildingData:
	var node: Node3D
	var weight: float
	var footprint: Array[Vector2i]  # Celdas que ocupa
	var supports: Array[Vector3]  # Posiciones de edificios que lo soportan
	
	func _init(n: Node3D = null, w: float = 0.0) -> void:
		node = n
		weight = w
		footprint = []
		supports = []


func _ready() -> void:
	pass


## Inicializa el Architecto con referencias necesarias
func initialize(chunk: Chunk, terrain: TerrainGenerator = null) -> void:
	_active_chunk = chunk
	_terrain = terrain


## Cambia el chunk activo
func set_active_chunk(chunk: Chunk) -> void:
	_active_chunk = chunk


## Comprueba si se puede colocar un edificio en una posición
func can_place_at_world(world_pos: Vector3, building_weight: float) -> Dictionary:
	var result := {
		"can_place": false,
		"reason": "",
		"material": null,
		"support_factor": 0.0
	}
	
	if not _active_chunk:
		result["reason"] = "No hay chunk activo"
		return result
	
	# Obtener el material más duro en la posición
	var ground_material := _active_chunk.get_hardest_material_at(world_pos)
	
	# Si no hay material específico, usar un valor por defecto (tierra/suelo)
	var effective_hardness := 3.0  # Tierra normal
	if ground_material:
		effective_hardness = ground_material.hardness
		result["material"] = ground_material
	
	# Calcular si el material puede soportar el peso
	var required_hardness := building_weight / weight_factor
	var support_factor := effective_hardness / required_hardness if required_hardness > 0 else 999.0
	
	result["support_factor"] = support_factor
	
	if support_factor >= safety_factor:
		result["can_place"] = true
		result["reason"] = "OK"
	else:
		result["can_place"] = false
		result["reason"] = "Material demasiado débil (dureza %.1f < requerida %.1f)" % [effective_hardness, required_hardness]
	
	# Verificar pendiente si hay terreno
	if _terrain and result["can_place"]:
		var slope := _terrain.get_slope_at(world_pos)
		if slope > 0.7:  # Pendiente máxima para construcción
			result["can_place"] = false
			result["reason"] = "Pendiente demasiado pronunciada (%.1f)" % slope
	
	return result


## Coloca un edificio en una posición del mundo
func place_building(world_pos: Vector3, building_weight: float, building_scene: PackedScene) -> Node3D:
	var check := can_place_at_world(world_pos, building_weight)
	
	if not check["can_place"]:
		placement_denied.emit(world_pos, check["reason"])
		push_warning("Architecto: No se puede colocar edificio - ", check["reason"])
		return null
	
	# Instanciar el edificio
	var building := building_scene.instantiate() as Node3D
	if not building:
		push_error("Architecto: La escena no es un Node3D válido")
		return null
	
	# Ajustar altura al terreno si existe
	var final_pos := world_pos
	if _terrain:
		final_pos.y = _terrain.get_height_at(world_pos)
	
	_set_building_position(building, final_pos)
	
	# Registrar el edificio
	var data := BuildingData.new(building, building_weight)
	_buildings[final_pos] = data
	
	# Añadir al árbol de escena (el padre debe agregarlo)
	building_placed.emit(final_pos, building)
	
	return building


## Coloca un edificio directamente (sin instanciar escena)
func place_building_node(world_pos: Vector3, building: Node3D, building_weight: float) -> bool:
	var check := can_place_at_world(world_pos, building_weight)
	
	if not check["can_place"]:
		placement_denied.emit(world_pos, check["reason"])
		return false
	
	# Ajustar altura al terreno si existe
	var final_pos := world_pos
	if _terrain:
		final_pos.y = _terrain.get_height_at(world_pos)
	
	_set_building_position(building, final_pos)
	
	# Registrar el edificio
	var data := BuildingData.new(building, building_weight)
	_buildings[final_pos] = data
	
	building_placed.emit(final_pos, building)
	return true


## Coloca el edificio respetando que puede no estar aún en el árbol de escena.
## global_position sobre un nodo fuera del árbol falla y descarta la posición
## (el llamador añade el nodo después de que place_*() devuelva true).
func _set_building_position(building: Node3D, world_pos: Vector3) -> void:
	if building.is_inside_tree():
		building.global_position = world_pos
	else:
		building.position = world_pos


## Elimina un edificio y comprueba colapsos en cadena
func remove_building(world_pos: Vector3) -> bool:
	if not _buildings.has(world_pos):
		return false
	
	# El llamador puede obtener el nodo con get_building_at() antes de llamar remove_building()
	_buildings.erase(world_pos)
	
	# Comprobar si otros edificios dependían de este
	_check_cascade_collapse(world_pos)
	
	return true


## Comprueba colapsos en cadena cuando se elimina un soporte
func _check_cascade_collapse(removed_pos: Vector3) -> void:
	var to_collapse: Array[Vector3] = []
	
	for pos: Vector3 in _buildings.keys():
		var bld_data: BuildingData = _buildings[pos]
		
		# Verificar si este edificio está directamente encima del eliminado
		# (simplificado: solo comprueba si está cerca en X/Z y más arriba)
		if pos.distance_to(removed_pos) < 2.0 and pos.y > removed_pos.y:
			# Revaluar soporte
			var check := can_place_at_world(pos, bld_data.weight)
			if not check["can_place"]:
				to_collapse.append(pos)
	
	# Colapsar edificios sin soporte
	for pos in to_collapse:
		_trigger_collapse(pos)


## Activa el colapso de un edificio
func _trigger_collapse(world_pos: Vector3) -> void:
	if not _buildings.has(world_pos):
		return
	
	var data: BuildingData = _buildings[world_pos]
	var building := data.node
	
	# Esperar antes de colapsar
	await get_tree().create_timer(collapse_delay).timeout
	
	if not is_instance_valid(building):
		return
	
	building_collapsed.emit(world_pos, building)
	
	# Animar colapso simple (caer y rotar)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(building, "position:y", building.position.y - 2.0, 0.5)
	tween.tween_property(building, "rotation_degrees:x", randf_range(-30, 30), 0.5)
	tween.tween_property(building, "rotation_degrees:z", randf_range(-30, 30), 0.5)
	
	await tween.finished
	
	_buildings.erase(world_pos)
	building.queue_free()
	
	# Continuar cadena de colapsos
	_check_cascade_collapse(world_pos)


## Calcula el peso total de una estructura (suma de bloques)
static func calculate_structure_weight(blocks: Array[Dictionary]) -> float:
	var total := 0.0
	for block in blocks:
		if block.has("weight"):
			total += block["weight"]
		elif block.has("material") and block["material"] is RawMaterial:
			var mat: RawMaterial = block["material"]
			var volume: float = block.get("volume", 1.0)
			total += mat.calculate_weight(volume)
	return total


## Obtiene todos los edificios colocados
func get_all_buildings() -> Dictionary:
	return _buildings.duplicate()


## Obtiene el edificio en una posición (o null)
func get_building_at(world_pos: Vector3, tolerance: float = 0.5) -> Node3D:
	for pos: Vector3 in _buildings.keys():
		if pos.distance_to(world_pos) <= tolerance:
			return _buildings[pos].node
	return null
