class_name RuggedTerrain
extends TerrainGenerator
## Comarca de mentira ACCIDENTADA: lomas y vaguadas por todas partes, sin un
## solo obstaculo infranqueable.
##
## Sirve para una pregunta muy concreta: si el terreno es aspero pero no tiene
## ni un rio ni un cortado, la rejilla TIENE que decir que se llega a todas
## partes. Si dice que no, es que la esta troceando ella sola.

var roughness: float = 0.3
var _noise: FastNoiseLite


func _init() -> void:
	terrain_size = Vector2i(2048, 2048)
	_noise = FastNoiseLite.new()
	_noise.seed = 5
	_noise.frequency = 0.004
	_noise.fractal_octaves = 5


## Amplitud del relieve, en metros. `roughness` es la fraccion de 260 m, que
## es un desnivel canabro creible sobre una onda de doscientos y pico metros.
func get_height_at(world_pos: Vector3) -> float:
	return 200.0 + _noise.get_noise_2d(world_pos.x, world_pos.z) 		* 260.0 * roughness


func get_slope_at(world_pos: Vector3) -> float:
	# La pendiente sale del propio ruido, a paso corto: asi hay laderas duras
	# de verdad repartidas, que es lo que tiene un valle canabro
	var step := 6.0
	var here := get_height_at(world_pos)
	var east := get_height_at(world_pos + Vector3(step, 0.0, 0.0))
	var south := get_height_at(world_pos + Vector3(0.0, 0.0, step))
	# La pendiente REAL, sin multiplicadores inventados. La primera version
	# multiplicaba por doce y salian laderas del 500%: con eso la rejilla
	# bloqueaba el mapa entero y parecia un fallo de la rejilla cuando el
	# disparate estaba en el terreno de prueba.
	return Vector2(east - here, south - here).length() / step


func crossing_difficulty_at(_world_pos: Vector3) -> float:
	# Ni una gota de agua: lo unico que se prueba aqui es la pendiente
	return 0.0


## El vado a un caudal dado. Lo pide [Navgrid] para hornear la rejilla de cada
## estacion, y el doble tiene que tenerlo o la rejilla mide cero por todas
## partes -o sea que se anda por encima del rio-.
func crossing_difficulty_with(world_pos: Vector3, con_caudal: float) -> float:
	return crossing_difficulty_at(world_pos) * con_caudal
