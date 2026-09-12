class_name VadoTerrain
extends TerrainGenerator
## Un valle con UN vado, hecho a medida para probar que el camino pasa por él.
##
## [FakeTerrain] tiene un río infranqueable, que sirve para probar que el
## trazado NO lo cruza. Lo que hace falta probar aquí es lo contrario y es más
## fino: que cuando sí hay por dónde cruzar, el camino que se traza pasa por ahí
## y no por al lado.
##
## Ahí estaba el ovillo de la orilla. La rejilla abre una celda de agua porque
## tiene una línea vadeable —ver [Navgrid._paso_de_la_celda]— y luego el
## trazado, o el recorte de la escalera, la cruzaba por cualquier otro sitio: el
## camino prometía un paso que sobre el terreno es agua honda, la persona
## llegaba a la orilla, no lo encontraba, y se pasaba la jornada barriéndola.
##
## La comarca es ésta:
##   · meseta llana de dos kilómetros de lado, sin una cuesta
##   · un RÍO de sesenta metros de ancho, de este a oeste, que la parte en dos
##   · un VADO de veinte metros de ancho, y uno solo, por el que sí se pasa
##
## Sesenta metros de río y veinte de vado son a propósito: el río es más ancho
## que la celda de cuarenta y el vado más estrecho, que es el caso en el que
## mirar la celda entera no basta.

const RIVER_Z := 1000.0
const RIVER_HALF := 30.0

## Dónde está el vado y cuánto mide de ancho a cada lado.
const FORD_X := 820.0
const FORD_HALF := 10.0


func _init() -> void:
	terrain_size = Vector2i(2048, 2048)


static func in_river(world_pos: Vector3) -> bool:
	return absf(world_pos.z - RIVER_Z) < RIVER_HALF


static func in_ford(world_pos: Vector3) -> bool:
	return in_river(world_pos) and absf(world_pos.x - FORD_X) < FORD_HALF


func get_height_at(_world_pos: Vector3) -> float:
	return 100.0


func get_slope_at(_world_pos: Vector3) -> float:
	return 0.03


func crossing_difficulty_at(world_pos: Vector3) -> float:
	if not in_river(world_pos):
		return 0.0
	# El vado se pasa con el agua por la rodilla; el resto del cauce, no.
	return 0.2 if in_ford(world_pos) else 1.0


func crossing_difficulty_with(world_pos: Vector3, con_caudal: float) -> float:
	return minf(crossing_difficulty_at(world_pos) * con_caudal, 1.0)
