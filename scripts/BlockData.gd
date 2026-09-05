@tool
class_name BlockData
extends Resource
## Define un bloque constructivo (muro, suelo, techo...).
## Complementa a [RawMaterial]: mientras aquel describe la sustancia, este
## describe una pieza concreta ya fabricada con ella, con sus dimensiones,
## su peso y su papel estructural.

## Nombre visible del bloque en UI
@export var block_name: String = "Unknown Block"

## Peso de la pieza en kg. Si se deja en 0 se deduce de la densidad del
## material primario y el volumen (ver get_effective_weight()).
@export_range(0.0, 100000.0, 0.1) var weight: float = 0.0

## Material del que está hecho el bloque
@export var primary_material: RawMaterial

## Dimensiones de la pieza en metros (ancho, alto, profundidad)
@export var dimensions: Vector3 = Vector3.ONE

## ¿Soporta carga? Un techo de paja no, un muro de piedra sí
@export var is_structural: bool = true

## Capacidad de soporte en la misma escala que RawMaterial.hardness (0-10).
## Solo tiene efecto si is_structural es true.
@export_range(0.0, 10.0, 0.1) var support_factor: float = 1.0

## ¿Necesita algo debajo para sostenerse?
@export var requires_support: bool = true

## Categoría funcional del bloque
@export_enum("Wall", "Floor", "Roof", "Foundation", "Decoration") var category: String = "Wall"

## Resistencia al fuego 0-1 (1 = incombustible)
@export_range(0.0, 1.0, 0.01) var fire_resistance: float = 0.5

## Aislamiento térmico 0-1 (1 = aísla por completo)
@export_range(0.0, 1.0, 0.01) var thermal_insulation: float = 0.5

## Coste de fabricación: entradas {"material": RawMaterial, "amount": float}
@export var crafting_materials: Array = []

## Tiempo de construcción en segundos de juego
@export_range(0.0, 600.0, 0.1) var build_time: float = 1.0


## Volumen de la pieza en m³
func get_volume() -> float:
	return dimensions.x * dimensions.y * dimensions.z


## Peso real de la pieza en kg.
## El valor explícito de `weight` manda; si es 0 se calcula desde la densidad
## del material, de modo que un bloque nuevo no necesita pesarse a mano.
func get_effective_weight() -> float:
	if weight > 0.0:
		return weight
	if primary_material:
		return primary_material.calculate_weight(get_volume())
	return 0.0


## Dureza efectiva del bloque, heredada del material si no es estructural
func get_hardness() -> float:
	if is_structural:
		return support_factor
	if primary_material:
		return primary_material.hardness
	return 0.0


## Peso máximo en kg que este bloque puede sostener encima.
## weight_factor debe coincidir con el de [Architecto] para que los dos
## sistemas hablen de lo mismo.
func max_supported_weight(weight_factor: float = 2500.0) -> float:
	if not is_structural:
		return 0.0
	return support_factor * weight_factor


## ¿Puede este bloque sostener el peso dado?
func can_support(weight_kg: float, weight_factor: float = 2500.0) -> bool:
	return weight_kg <= max_supported_weight(weight_factor)


## ¿Arde este bloque a la temperatura dada?
## fire_resistance 1.0 lo hace incombustible pase lo que pase.
func would_burn_at(temperature_c: float) -> bool:
	if fire_resistance >= 1.0:
		return false
	if not primary_material:
		return false
	if not primary_material.would_ignite_at(temperature_c):
		return false
	# La resistencia eleva efectivamente el punto de ignición
	var margin := temperature_c - primary_material.ignition_point
	return margin > primary_material.ignition_point * fire_resistance


## Devuelve un diccionario con las propiedades (útil para serialización)
func to_dict() -> Dictionary:
	return {
		"block_name": block_name,
		"weight": get_effective_weight(),
		"material_path": primary_material.resource_path if primary_material else "",
		"dimensions": [dimensions.x, dimensions.y, dimensions.z],
		"is_structural": is_structural,
		"support_factor": support_factor,
		"requires_support": requires_support,
		"category": category,
		"fire_resistance": fire_resistance,
		"thermal_insulation": thermal_insulation,
		"build_time": build_time
	}
