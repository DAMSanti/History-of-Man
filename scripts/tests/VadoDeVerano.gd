class_name VadoDeVerano
extends TerrainGenerator
## Un valle con DOS vados: uno enfrente que sólo abre en verano y otro lejos
## que está siempre. Es la queja del jugador dibujada.
##
## [VadoTerrain] no vale para esto y no se le puede añadir: su vado es
## permanente y sus pruebas afirman que **es uno solo** —«lejos del vado hay que
## ir a buscarlo»—, así que meterle un segundo paso las rompe. Y [FakeTerrain]
## tiene el río cerrado a cualquier caudal, que es lo contrario de lo que hay
## que probar aquí.
##
## Lo que hace falta probar es la ESTACIÓN: que cuando el río baja y el vado de
## enfrente se abre, el camino deja de dar el rodeo. La comarca:
##
##   · meseta llana de dos kilómetros de lado, sin una cuesta
##   · un RÍO de sesenta metros, de este a oeste, más ancho que la celda de
##     cuarenta —que es el caso en el que mirar la celda entera no basta—
##   · un VADO DE ENFRENTE, delante del abrigo, que se cruza con el río bajo
##   · y un VADO LEJOS, al oeste, que se cruza siempre: es el rodeo
##
## Las dificultades salen de la regla del vado, no de un gusto. Se pasa hasta
## [Hydrography.FORD_IMPASSABLE] —0,70— incluido, y la dificultad se multiplica
## por el caudal de la estación, [Temporada.CAUDAL]:
##
##   ENFRENTE (0,62)  primavera 0,78 · VERANO 0,37 · otoño 0,71 · invierno 0,96
##   LEJOS    (0,40)  primavera 0,50 · verano 0,24 · otoño 0,46 · invierno 0,62
##   EL CAUCE (2,00)  no se pasa en ninguna
##
## O sea: el de enfrente abre en verano y sólo en verano, y el de lejos está
## siempre. Con caudal 1,0 —el que se usa cuando una prueba no dice estación—
## el de enfrente también está cerrado (0,62 pasa, ojo: 0,62 <= 0,70), así que
## las pruebas de esta comarca dicen SIEMPRE con qué caudal hornean.

const RIO_Z := 1000.0
const RIO_MEDIO := 30.0

## El vado de enfrente del abrigo: centro y medio ancho.
const ENFRENTE_X := 1000.0
const ENFRENTE_MEDIO := 30.0

## Y el del rodeo, al oeste.
const LEJOS_X := 200.0
const LEJOS_MEDIO := 30.0

const DIF_CAUCE := 2.0
const DIF_ENFRENTE := 0.62
const DIF_LEJOS := 0.40


func _init() -> void:
	terrain_size = Vector2i(2048, 2048)


static func en_el_rio(world_pos: Vector3) -> bool:
	return absf(world_pos.z - RIO_Z) < RIO_MEDIO


func get_height_at(_world_pos: Vector3) -> float:
	return 100.0


func get_slope_at(_world_pos: Vector3) -> float:
	return 0.03


func crossing_difficulty_at(world_pos: Vector3) -> float:
	if not en_el_rio(world_pos):
		return 0.0
	if absf(world_pos.x - ENFRENTE_X) < ENFRENTE_MEDIO:
		return DIF_ENFRENTE
	if absf(world_pos.x - LEJOS_X) < LEJOS_MEDIO:
		return DIF_LEJOS
	return DIF_CAUCE


func crossing_difficulty_with(world_pos: Vector3, con_caudal: float) -> float:
	return crossing_difficulty_at(world_pos) * con_caudal
