class_name FakeTerrain
extends TerrainGenerator
## Una comarca de mentira, hecha a medida para probar el trazado de caminos.
##
## Generar terreno de verdad tarda demasiado para una prueba, y ademas no hace
## falta: lo que se prueba aqui es el PLANIFICADOR, no el muestreo del mapa.
## Basta con responder a las tres preguntas que hace el A* -altura, pendiente
## y dificultad de vado- sobre una comarca que uno decide.
##
## La comarca es esta:
##   · meseta llana de dos kilometros de lado
##   · un BARRANCO vertical de treinta metros de ancho que la parte en dos,
##     con un unico paso al norte. Treinta metros es MENOS que la celda vieja
##     de ochenta, que es exactamente por lo que el planificador no lo veia
##   · un RIO infranqueable de ochenta metros que corta la mitad sur

const GORGE_X := 1024.0
const GORGE_HALF := 15.0
const GORGE_GAP_Z := 260.0
const GORGE_GAP_HALF := 90.0

const RIVER_Z := 1500.0
const RIVER_HALF := 40.0


func _init() -> void:
	terrain_size = Vector2i(2048, 2048)


## Dentro del barranco, y no en el paso.
static func in_gorge(point: Vector3) -> bool:
	return absf(point.x - GORGE_X) < GORGE_HALF \
		and absf(point.z - GORGE_GAP_Z) > GORGE_GAP_HALF


static func in_river(point: Vector3) -> bool:
	return absf(point.z - RIVER_Z) < RIVER_HALF


func get_height_at(world_pos: Vector3) -> float:
	if in_gorge(world_pos):
		return 80.0
	if in_river(world_pos):
		return 40.0
	return 200.0


func get_slope_at(world_pos: Vector3) -> float:
	# Las paredes del barranco: casi verticales, que es lo que lo hace malo
	return 1.4 if in_gorge(world_pos) else 0.03


func crossing_difficulty_at(world_pos: Vector3) -> float:
	return 1.0 if in_river(world_pos) else 0.0
