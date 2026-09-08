class_name PeakTerrain
extends TerrainGenerator
## Comarca con TRES cumbres puestas a mano y en sitios que se saben.
##
## Sirve para comprobar que el buscador cae en la cima y no en una ladera. Con
## el terreno real no se puede: no hay forma de saber cual era la respuesta
## correcta, y entonces cualquier resultado parece bueno.

## posicion, altura sobre el llano, lo ancho que es el monte.
##
## Los anchos son ESTRECHOS a proposito, y la primera version no lo era: con
## campanas de cuatrocientos metros el monte de en medio no era un maximo del
## campo sumado sino un hombro del grande de al lado -la ladera del vecino
## inclina el terreno mas de lo que cae la propia cima-, asi que la respuesta
## correcta no eran tres cumbres sino una. El buscador acertaba y la prueba
## estaba mal.
const SUMMITS := [
	[Vector2(1400.0, 1000.0), 520.0, 260.0],
	[Vector2( 700.0, 1600.0), 300.0, 200.0],
	[Vector2(1700.0, 1750.0), 180.0, 150.0],
]

const BASE := 120.0


func _init() -> void:
	terrain_size = Vector2i(2048, 2048)


func get_height_at(world_pos: Vector3) -> float:
	var height := BASE
	for summit: Array in SUMMITS:
		var centre: Vector2 = summit[0]
		var rise: float = summit[1]
		var width: float = summit[2]
		var away := Vector2(world_pos.x, world_pos.z).distance_to(centre)
		# Campana: cae suave hasta el llano, sin bordes duros
		height += rise * exp(-(away * away) / (2.0 * width * width))
	return height


func get_slope_at(world_pos: Vector3) -> float:
	var step := 8.0
	var here := get_height_at(world_pos)
	var east := get_height_at(world_pos + Vector3(step, 0.0, 0.0))
	var south := get_height_at(world_pos + Vector3(0.0, 0.0, step))
	return Vector2(east - here, south - here).length() / step


func crossing_difficulty_at(_world_pos: Vector3) -> float:
	return 0.0


## El vado a un caudal dado. Lo pide [Navgrid] para hornear la rejilla de cada
## estacion, y el doble tiene que tenerlo o la rejilla mide cero por todas
## partes -o sea que se anda por encima del rio-.
func crossing_difficulty_with(world_pos: Vector3, con_caudal: float) -> float:
	return crossing_difficulty_at(world_pos) * con_caudal
