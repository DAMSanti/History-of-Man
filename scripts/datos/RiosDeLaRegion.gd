class_name RiosDeLaRegion
extends Resource
## Los ríos del mapa regional, horneados: los de hoy, de OpenStreetMap, y su
## prolongación por la plataforma emergida hasta el mar de la época.
##
## EPOCA_01 §10.2. El relieve regional se horneó **sin cauces** —el mapa regional
## no dibujaba ni un río, ni en la tierra de hoy— y el usuario pidió verlos, y que
## siguieran por la plataforma. Se hornea una vez con `HornearRios`, como las
## máscaras de las eras: bajar los ríos de la región son minutos de red.
##
## Cada cauce es el diccionario de [OSMWays.parse_water] —`points` en (lon, lat),
## `half_width_m`, `kind`, `name`—, que es lo que come [Hydrography.apply].

## Dónde se guarda. Lo lee el mapa regional y lo escribe `HornearRios`.
const RUTA := "res://data/sites/rios_de_la_region.res"


## Los ríos horneados, o un conjunto vacío si no se han horneado todavía: el mapa se
## monta igual, sin ríos.
static func cargar() -> RiosDeLaRegion:
	if ResourceLoader.exists(RUTA):
		var rios := load(RUTA) as RiosDeLaRegion
		if rios != null:
			return rios
	return RiosDeLaRegion.new()


## Los de hoy, tal cual los da OSM.
@export var de_hoy: Array[Dictionary] = []

## Los tramos de la plataforma, uno por boca en la costa de hoy: desde la boca,
## bajando por el relieve, hasta el mar de [mar_de_la_plataforma].
@export var de_la_plataforma: Array[Dictionary] = []

## Qué trozos de la región ya se bajaron de OSM, para reintentar sólo los que falten.
@export var trozos_bajados: PackedInt32Array = PackedInt32Array()

## El mar hasta el que se prolongaron, en metros.
@export var mar_de_la_plataforma: float = -120.0

## Cuántos pasos de los tramos de la plataforma tuvieron que subir para no
## atascarse en un llano. Se guarda para decirlo, no para usarlo.
@export var pasos_abiertos: int = 0


## Todos los cauces que se pintan con ese mar: los de hoy siempre, y los de la
## plataforma sólo con el mar hasta el que se prolongaron o más bajo. Con un mar a
## medias acabarían dentro del agua.
func para_el_mar(mar: float) -> Array:
	var todos: Array = []
	todos.append_array(de_hoy)
	if mar <= mar_de_la_plataforma + 0.5:
		todos.append_array(de_la_plataforma)
	return todos


## La versión de la regla de los anchos con la que se hornearon.
@export var version_de_los_anchos: int = 0


## Lo que decide cómo se pintan: si cambia, la malla regional se rehace.
func huella() -> int:
	return hash([de_hoy.size(), de_la_plataforma.size(), mar_de_la_plataforma,
		pasos_abiertos, version_de_los_anchos])
