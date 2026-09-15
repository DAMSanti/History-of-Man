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

## La primera pantalla del juego, y adonde se vuelve al salir de una partida.
## Desde el 2026-09-13: antes se arrancaba en el mapa regional. Ver
## `docs/INTERFAZ.md` §7 y [MenuPrincipal].
const MENU_SCENE := "res://scenes/menu_principal.tscn"


## Si lo que se va a montar es una partida GUARDADA y no una fundación nueva.
##
## Lo pone el mapa regional al pulsar «retomar» y lo lee [DemoMain] al acabar de
## montar la escena: no basta con que haya un fichero guardado, porque fundar de
## nuevo en el mismo emplazamiento es una partida distinta. Ver [Guardado].
static var retomando: bool = false

## Si lo que se va a montar es una VISITA: un mapa que no es el de la banda, sin
## gente, sin guardar y con el reloj parado. Decisión del usuario del 2026-09-14,
## «no debe traer a mi banda, sólo cargar y mostrarme el mapa». Lo pone el mapa
## regional; ver [Guardado.sitio_de_la_banda].
static var visita: bool = false


static func is_active() -> bool:
	return site != null and not heightmap_path.is_empty()


static func clear() -> void:
	visita = false
	site = null
	heightmap_path = ""
	region_offset = Vector2.ZERO
