class_name Expedition
extends RefCounted
## Traspaso entre la capa regional y la local.
##
## Cuando el jugador funda en un emplazamiento hay que llevar a la otra escena
## que sitio es y con que relieve. Se usan variables estaticas y no un autoload
## para no tocar project.godot: el script queda cargado entre cambios de
## escena, que es justo lo que hace falta aqui.

## Emplazamiento elegido en el mapa regional
static var site: Site

## Heightmap fino descargado para ese emplazamiento
static var heightmap_path: String = ""

## Esquina del recuadro local dentro de ese heightmap, en metros
static var region_offset: Vector2 = Vector2.ZERO

## Lado del mapa local en metros
static var local_size_m: int = 4096

## Cota del mar de la epoca en curso
static var sea_level_m: float = 0.0

## Epoca en curso: decide que elementos existen ya en el mapa local
static var era: Site.Era = Site.Era.PALEOLITICO

const REGION_SCENE := "res://scenes/region_map.tscn"
const LOCAL_SCENE := "res://scenes/demo_main.tscn"


static func is_active() -> bool:
	return site != null and not heightmap_path.is_empty()


static func clear() -> void:
	site = null
	heightmap_path = ""
	region_offset = Vector2.ZERO
