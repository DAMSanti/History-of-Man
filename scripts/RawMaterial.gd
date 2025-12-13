@tool
class_name RawMaterial
extends Resource
## Recurso base que define las propiedades físicas de un material crudo.
## Usado para determinar comportamiento de construcción, fundición, y física estructural.

## Nombre visible del material en UI
@export var display_name: String = "Unknown Material"

## Densidad en kg/m³ - afecta peso de estructuras
@export_range(0.1, 25000.0, 0.1) var density: float = 1000.0

## Punto de fusión en °C - para sistemas de fundición/herrería
@export_range(-273.0, 5000.0, 1.0) var melting_point: float = 1000.0

## Dureza (escala 0-10, similar a Mohs) - determina si puede soportar peso
@export_range(0.0, 10.0, 0.1) var hardness: float = 5.0

## Conductividad térmica W/(m·K) - para propagación de calor
@export_range(0.0, 500.0, 0.1) var conductivity: float = 50.0

## Color representativo del material para debug/UI
@export var color: Color = Color.GRAY

## Categoría del material
@export_enum("Metal", "Stone", "Organic", "Earth", "Liquid", "Gas") var category: String = "Stone"

## ¿Es combustible?
@export var is_flammable: bool = false

## Temperatura de ignición si es combustible (°C)
@export_range(0.0, 1000.0, 1.0) var ignition_point: float = 250.0

## Valor económico base (monedas por unidad)
@export_range(0.0, 10000.0, 0.1) var base_value: float = 1.0


## Calcula el peso de un volumen dado de este material
func calculate_weight(volume_m3: float) -> float:
	return density * volume_m3


## Comprueba si este material puede soportar un peso dado
## weight_kg: peso en kg que se intenta colocar encima
## support_area_m2: área de soporte en m²
func can_support_weight(weight_kg: float, support_area_m2: float = 1.0) -> bool:
	# Factor de conversión: hardness 10 puede soportar ~100000 kg/m²
	var max_pressure := hardness * 10000.0  # kg/m²
	var applied_pressure := weight_kg / support_area_m2
	return applied_pressure <= max_pressure


## Comprueba si este material se fundiría a una temperatura dada
func would_melt_at(temperature_c: float) -> bool:
	return temperature_c >= melting_point


## Comprueba si este material se incendiaría a una temperatura dada
func would_ignite_at(temperature_c: float) -> bool:
	return is_flammable and temperature_c >= ignition_point


## Devuelve un diccionario con todas las propiedades (útil para serialización)
func to_dict() -> Dictionary:
	return {
		"display_name": display_name,
		"density": density,
		"melting_point": melting_point,
		"hardness": hardness,
		"conductivity": conductivity,
		"color": color.to_html(),
		"category": category,
		"is_flammable": is_flammable,
		"ignition_point": ignition_point,
		"base_value": base_value
	}


## Carga propiedades desde un diccionario
func from_dict(data: Dictionary) -> void:
	if data.has("display_name"):
		display_name = data["display_name"]
	if data.has("density"):
		density = data["density"]
	if data.has("melting_point"):
		melting_point = data["melting_point"]
	if data.has("hardness"):
		hardness = data["hardness"]
	if data.has("conductivity"):
		conductivity = data["conductivity"]
	if data.has("color"):
		color = Color.html(data["color"])
	if data.has("category"):
		category = data["category"]
	if data.has("is_flammable"):
		is_flammable = data["is_flammable"]
	if data.has("ignition_point"):
		ignition_point = data["ignition_point"]
	if data.has("base_value"):
		base_value = data["base_value"]
