class_name Temporada
extends RefCounted
## Lo que la estación le hace al PAISAJE, no a las tablas de rendimiento.
##
## El año ya cambiaba lo que se recoge, lo que se pesca y lo que se caza —eso
## está en [ResourceField.seasonal_factor] y en [Tajo._gathering_yields]—, pero
## el valle era el mismo el 3 de enero que el 3 de agosto: mismo verde, mismo
## río, mismo camino. Aquí viven las tres cosas que sí cambian el terreno.
##
## ## 1. La nieve
##
## No cae en todo el valle a la vez: cae por encima de una COTA, y esa cota
## baja con el invierno. Es lo que hace que el monte alto se cierre y la banda
## se quede en el fondo del valle, que es exactamente lo que pasa. El shader
## del terreno ya tiene `snow_min_height` —la capa de nieve estaba puesta a una
## altura fija todo el año—: aquí sólo se mueve.
##
## Y no es sólo pintura: la nieve **frena**. Ver [freno_por_nieve].
##
## ## 2. El barro
##
## Otoño e invierno encharcan lo que ya era húmedo. [Traversal] ya sabe que la
## marisma es lo más lento que hay —factor 0,34, «cada paso hay que sacar el
## pie»—; lo que faltaba es que en octubre haya marisma donde en julio había
## prado. Se hace subiendo el umbral de agua somera con la estación.
##
## ## 3. El caudal
##
## Crecidas y estiajes. Un río crecido no es un río con más textura azul: es un
## río que **no se vadea**, y eso cierra media comarca porque los vados son por
## donde se cruza. Ver [Hydrography.FORD_WADEABLE].
##
## En el Cantábrico el régimen es pluvial oceánico: máximo de invierno —lluvia
## y deshielo—, estiaje marcado de agosto. No es el régimen nival de un río de
## montaña continental, y por eso el pico es en enero y no en mayo.

## El relieve del mapa local, en metros: (la cota más baja, la más alta).
##
## Hace falta para pasar la cota de nieve —que [Termometro] da en metros sobre el
## mar— a la fracción del relieve con la que trabajan el shader del terreno y el
## freno de la marcha. Lo pone [SettlementSim.setup], que es quien tiene el
## terreno. Sin él no se sabe dónde cae la nieve, y no nieva.
##
## Aquí vivía `COTA_DE_NIEVE`, una fracción del relieve por estación sacada del
## Dryas reciente. Se quitó el 2026-09-12: la nieve sale ahora del termómetro.
## Ver [Termometro.cota_de_hielo]. Y el Dryas reciente es más frío que el
## 12 000 a.C. en que se fijó la época, que es por qué aquella nieve caía tan
## baja.
var relieve := Vector2.ZERO

## Cuánto encharca cada estación, de 0 a 1.
const ENCHARCA := {
	Subsistence.Season.PRIMAVERA: 0.55,
	Subsistence.Season.VERANO: 0.0,
	Subsistence.Season.OTONO: 0.70,
	Subsistence.Season.INVIERNO: 0.85,
}

## Caudal del río, en veces lo normal.
##
## Régimen pluvial oceánico: pico de invierno por lluvia, estiaje de agosto.
const CAUDAL := {
	Subsistence.Season.PRIMAVERA: 1.25,
	Subsistence.Season.VERANO: 0.60,
	Subsistence.Season.OTONO: 1.15,
	Subsistence.Season.INVIERNO: 1.55,
}

## Cuánto frena la nieve por encima de la cota, como factor de velocidad.
##
## Un tercio. Andar con nieve por la rodilla cuesta más o menos lo que andar
## por marisma —[Traversal.ground_factor] le da 0,34 al barro— y por el mismo
## motivo: cada paso hay que sacar el pie. Es de las cifras que más se van a
## mover en playtest.
const FRENA_LA_NIEVE := 0.36

## Cuánto tarda en llegar y en irse, en jornadas.
##
## La estación no cambia de un día para otro: la primera nevada no deja el
## puerto cerrado. Se interpola sobre esto para que el paisaje se mueva.
const TRANSICION := 12.0

var _cota := 0.95
var _charca := 0.0
var _caudal := 1.0

## El tinte del pasto de hoy. Se interpola hacia el de la estacion como todo lo
## demas: el valle vira en unas jornadas, no a medianoche.
var _tinte := Color.WHITE


## Lleva el paisaje hacia lo que toca en esta estación. Una jornada de camino.
func nuevo_dia(season: Subsistence.Season) -> void:
	var paso := 1.0 / TRANSICION
	_cota = move_toward(_cota, fraccion_de(season), paso)
	_charca = move_toward(_charca, float(ENCHARCA.get(season, 0.0)), paso)
	_caudal = move_toward(_caudal, float(CAUDAL.get(season, 1.0)), paso * 1.5)
	# El color va MAS DESPACIO que el resto: la hierba no amarillea en doce
	# dias, y un valle que cambia de color a ojos vista canta a interruptor.
	_tinte = _tinte.lerp(TerrainLayers.tint_of_season(season), paso * 0.5)


## Deja el paisaje YA en lo que toca, sin transición. Para arrancar partida y
## para las sondas, que si no medirían doce jornadas de otra estación.
func asentar(season: Subsistence.Season) -> void:
	_cota = fraccion_de(season)
	_charca = float(ENCHARCA.get(season, 0.0))
	_caudal = float(CAUDAL.get(season, 1.0))
	_tinte = TerrainLayers.tint_of_season(season)


## La cota de nieve de esa estación, en tanto por uno del relieve del mapa.
##
## Puede pasar de uno —«por encima de todo el mapa: no nieva»— o bajar de cero
## —«nieva hasta abajo»—, y las dos cosas son ciertas en algún mapa: el shader
## las admite (`TerrainGenerator.set_snow_line` recorta entre 0 y 2).
func fraccion_de(season: Subsistence.Season) -> float:
	var alto := relieve.y - relieve.x
	if alto <= 0.0:
		# Sin relieve conocido no hay contra qué medir. Por encima de todo.
		return 2.0
	return (Termometro.cota_de_hielo(season) - relieve.x) / alto


## La cota de nieve de hoy, para el shader del terreno.
func cota_de_nieve() -> float:
	return _cota


func encharcamiento() -> float:
	return _charca


func caudal() -> float:
	return _caudal


## El tinte de hoy para las capas vivas del terreno.
func tinte_del_pasto() -> Color:
	return _tinte


## Si a esta altura hay nieve hoy. `altura` va en tanto por uno del mapa.
func hay_nieve(altura: float) -> bool:
	return altura >= _cota


## Cuánto frena andar por aquí, de 0 a 1. Uno es «como en verano».
##
## Junta las dos cosas que frenan y que no estaban: la nieve por encima de la
## cota y el barro de las vegas. No incluye la pendiente ni la carga —de eso ya
## se ocupa [Traversal]—: esto es lo que pone ENCIMA el calendario.
func freno_por_nieve(altura: float) -> float:
	if not hay_nieve(altura):
		return 1.0
	# Cuanto más arriba de la cota, más espesor. A media cota por encima ya es
	# el freno entero.
	var espesor := clampf((altura - _cota) / maxf(1.0 - _cota, 0.05), 0.0, 1.0)
	return lerpf(1.0, FRENA_LA_NIEVE, espesor)


## Y cuánto sube el calado del río hoy. Se multiplica por la dificultad de vado
## de [TerrainGenerator.crossing_difficulty_at]: con el río crecido, lo que en
## agosto era un vado deja de serlo.
func vado(dificultad: float) -> float:
	return dificultad * _caudal


## Lo que hay que decir en una línea, para la barra y la crónica.
func resumen(season: Subsistence.Season) -> String:
	var partes: Array[String] = []
	if _cota < 0.9:
		partes.append("nieve por encima de la cota")
	if _charca > 0.4:
		partes.append("vegas encharcadas")
	if _caudal >= 1.3:
		partes.append("río crecido")
	elif _caudal <= 0.75:
		partes.append("río bajo")
	if partes.is_empty():
		return Subsistence.season_name(season)
	return "%s · %s" % [Subsistence.season_name(season), ", ".join(partes)]
