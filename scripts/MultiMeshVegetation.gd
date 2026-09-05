class_name MultiMeshVegetation
extends MultiMeshInstance3D
## Sistema de vegetación con MultiMesh para renderizar miles de instancias eficientemente.
## Usa el TerrainGenerator para posicionar vegetación según humedad y pendiente.

@export_group("Vegetation Settings")
## Mesh a usar para la vegetación (árbol, arbusto, etc.)
@export var vegetation_mesh: Mesh

## Material opcional para la vegetación
@export var vegetation_material: Material

## Número máximo de instancias
@export var max_instances: int = 5000

## Espaciado mínimo entre instancias
@export var min_spacing: float = 3.0

## Escala base de las instancias
@export var base_scale: Vector3 = Vector3(1, 1, 1)

## Variación de escala (0-1)
@export_range(0.0, 1.0) var scale_variation: float = 0.3

## Rotación aleatoria en Y
@export var random_rotation: bool = true

@export_group("Placement Rules")
## Humedad mínima para colocar vegetación
@export_range(0.0, 1.0) var min_humidity: float = 0.35

## Pendiente máxima para colocar vegetación
@export_range(0.0, 2.0) var max_slope: float = 0.6

## Altura mínima normalizada (0 = nivel del mar)
@export_range(0.0, 1.0) var min_height: float = 0.15

## Altura máxima normalizada (1 = cima)
@export_range(0.0, 1.0) var max_height_normalized: float = 0.65

@export_group("LOD Settings")
## Distancia a la que la vegetacion deja de dibujarse (0 = sin limite)
@export var lod_distance_end: float = 200.0

## Margen de desvanecimiento justo antes de lod_distance_end
@export var lod_fade_margin: float = 40.0

## Distancia MINIMA a la que se dibuja (0 = sin limite cercano).
## Solo tiene sentido si otro nodo cubre el detalle de cerca.
@export var lod_distance_begin: float = 0.0

## Referencia al generador de terreno
var _terrain: TerrainGenerator

## Semilla para aleatoriedad
var _rng: RandomNumberGenerator


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(name)
	
	# CUIDADO con la semantica de Godot: visibility_range_begin es el limite
	# CERCANO, no el inicio del desvanecimiento. Estaba a 150 con end a 200, o
	# sea que solo se dibujaba una cascara esferica entre 150 y 200 unidades de
	# la camara y TODO lo cercano quedaba oculto. El fade va aparte, en
	# visibility_range_end_margin.
	visibility_range_begin = lod_distance_begin
	visibility_range_end = lod_distance_end
	visibility_range_end_margin = lod_fade_margin
	if lod_distance_end > 0.0:
		visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	else:
		visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


## Inicializa el MultiMesh con el terreno dado
func initialize(terrain: TerrainGenerator) -> void:
	_terrain = terrain
	_populate()


## Puebla la vegetación basándose en el terreno
func _populate() -> void:
	if not _terrain or not vegetation_mesh:
		push_warning("MultiMeshVegetation: Falta terreno o mesh de vegetación")
		return
	
	# Obtener posiciones válidas del terreno
	var valid_positions := _terrain.get_vegetation_positions(min_humidity, max_slope, min_spacing)
	
	# Filtrar por altura ANTES de reservar instancias. Antes se reservaban
	# instancias que luego se "ocultaban" con escala 0: seguían contando para el
	# límite y dejaban una base degenerada en el origen del MultiMesh.
	var placeable: Array[Vector3] = []
	for pos in valid_positions:
		# Normalizado contra el rango REAL del terreno: dividir por max_height
		# solo valia en modo procedural, con elevacion real da valores absurdos.
		var normalized_h := _terrain.get_normalized_height_at(pos)
		if normalized_h >= min_height and normalized_h <= max_height_normalized:
			placeable.append(pos)
	
	# Limitar al máximo de instancias
	var total := placeable.size()
	var instance_count := mini(total, max_instances)
	
	if instance_count == 0:
		push_warning("MultiMeshVegetation: No se encontraron posiciones válidas")
		return
	
	# Muestreo repartido por todo el terreno: quedarse con las primeras N
	# posiciones concentraba la vegetación en una franja del mapa.
	var stride := float(total) / float(instance_count)
	
	# Crear el MultiMesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = vegetation_mesh
	mm.instance_count = instance_count
	
	# Posicionar cada instancia
	for i in range(instance_count):
		var pos := placeable[mini(int(float(i) * stride), total - 1)]
		
		# Calcular transformación
		var xform := Transform3D()
		
		# Rotación aleatoria en Y
		if random_rotation:
			xform = xform.rotated(Vector3.UP, _rng.randf() * TAU)
		
		# Escala con variación
		var scale_factor := 1.0 + _rng.randf_range(-scale_variation, scale_variation)
		xform = xform.scaled(base_scale * scale_factor)
		
		# Posición
		xform.origin = pos
		
		mm.set_instance_transform(i, xform)
		
		# Color con variación sutil
		var color_variation := _rng.randf_range(0.85, 1.0)
		mm.set_instance_color(i, Color(color_variation, color_variation, color_variation))
	
	multimesh = mm
	
	# Aplicar material si existe
	if vegetation_material:
		material_override = vegetation_material
	
	print("MultiMeshVegetation: Colocadas ", instance_count, " instancias")


## Actualiza la vegetación (regenera posiciones)
func refresh() -> void:
	if _terrain:
		_populate()


## Obtiene el número de instancias activas
func get_instance_count() -> int:
	if multimesh:
		return multimesh.instance_count
	return 0
