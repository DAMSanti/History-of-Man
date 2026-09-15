class_name ArbolModelo
extends Resource
## Un árbol del bosque en 3D: sus niveles de detalle, ya a su altura en metros.
##
## Los hace `scripts/tools/ArbolesImport.gd` a partir de lo que genera EZ-Tree
## (`scripts/tools/arboles/generar.mjs`). GRAFICOS §7.1: se generan porque no hay
## modelos CC0 realistas hechos para juego de estas especies —decisión del usuario
## del 2026-09-15—.

## La clave de la especie, la misma que en [Forest.KINDS]: `pino`, `abedul`...
@export var especie: String = ""

## Cuál de las variantes de su especie es.
@export var variante: int = 0

## Del más detallado al menos. Cada uno con dos superficies: corteza y hoja, con
## sus materiales puestos.
@export var niveles: Array[Mesh] = []

## Cuánto mide, en metros, con la escala ya aplicada a la malla.
@export var alto_m: float = 0.0


## Triángulos de un nivel, para las pruebas y el presupuesto.
func triangulos(nivel: int) -> int:
	var malla := niveles[nivel]
	var total := 0
	for s in range(malla.get_surface_count()):
		var arrays := malla.surface_get_arrays(s)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else PackedInt32Array()
		@warning_ignore("integer_division")
		total += indices.size() / 3
	return total


static func ruta(especie_clave: String, numero: int) -> String:
	return "res://models/arboles/%s_%d.res" % [especie_clave, numero]
