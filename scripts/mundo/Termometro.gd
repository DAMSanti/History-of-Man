class_name Termometro
extends RefCounted
## Cuantos grados hace aqui y ahora. Y se contesta SOLO DESDE AQUI.
##
## Es el invariante 3 de SPECS.md §7 puesto en pie antes de que haga falta: el
## hogar, el vivac, la ropa y la escalera termica van a preguntar los cuatro, y
## si cada uno se hace su cuenta acabaran dando respuestas distintas. Ver
## docs/SISTEMAS.md §19.
##
## Tres sumandos, y cada uno tiene fuente o razon:
##
##   media de la estacion al nivel del mar, HOY
##   + el desfase frio del final del Magdaleniense
##   + la vuelta del dia (frio antes del alba, calor a media tarde)
##   - lo que enfria subir
##
## Las fuentes estan en docs/CREDITOS.md, seccion «Clima». Ninguna de estas
## cifras se ha elegido para que cuadre una partida: si el juego sale
## desequilibrado con ellas, lo que se ajusta es el juego.


## Media mensual al nivel del mar, de enero a diciembre, en grados.
##
## AEMET, normales de 1991-2020, observatorio de Santander / aeropuerto, a 3 m
## de cota — que es lo que lo hace servir de base «al nivel del mar»—. Media
## anual 14,8. Ver CREDITOS.md.
const MEDIA_MENSUAL_HOY := [
	10.0, 9.9, 11.6, 12.9, 15.6, 18.1,
	20.1, 20.8, 18.9, 16.5, 12.8, 10.8]


## Que meses cae cada estacion. El año del juego son cuatro estaciones de
## cuarenta y cinco jornadas -[Subsistence.DAYS_PER_SEASON]- y no doce meses,
## asi que la media de la estacion es la de sus tres meses.
const MESES_DE_LA_ESTACION := {
	Subsistence.Season.PRIMAVERA: [2, 3, 4],    # marzo, abril, mayo
	Subsistence.Season.VERANO: [5, 6, 7],       # junio, julio, agosto
	Subsistence.Season.OTONO: [8, 9, 10],       # septiembre, octubre, noviembre
	Subsistence.Season.INVIERNO: [11, 0, 1],    # diciembre, enero, febrero
}


## Lo que el final del Magdaleniense era mas frio que hoy, en INVIERNO.
##
## Tarroso et al. (2016), «Spatial climate dynamics in the Iberian Peninsula
## since 15 000 yr BP», *Climate of the Past* 12, 1137-1149, abierto y en
## CREDITOS.md. Su grupo C1 —la Iberia del norte y noroeste, que es esta— va de
## −5,5 a 0,2 °C de minima de enero entre los 15 ka y los 3 ka, y el propio
## texto cifra el calentamiento medio de enero en ~5,5 °C sobre esos 15 000
## años. A ~14 ka cal BP, que son los 12 000 a.C. del final del Magdaleniense,
## toca el extremo frio.
##
## **No es una cifra de balanceo y no se toca para cuadrar una partida.**
const ANOMALIA_INVIERNO := -5.0

## Y lo que era mas frio en VERANO, que es mucho menos.
##
## Del mismo trabajo: el julio del grupo C1 va de 21,7 a 24,2 °C sobre el mismo
## tramo, o sea unos 2,5 grados contra los 5,5 del invierno. El texto lo dice:
## «this pattern is less obvious for July temperatures, where variations showed
## a smaller amplitude».
##
## **Y esto es lo que de verdad importa para el juego, mas que las cifras: el
## final del Magdaleniense no era «como hoy pero mas frio», era MAS ESTACIONAL.**
## El verano se parecia al de ahora y el invierno no se parecia en nada. De ahi
## que el abrigo sea una puerta y no un porcentaje.
const ANOMALIA_VERANO := -2.0


## Media jornada de oscilacion: cuanto se aparta el mediodia de la media.
##
## AEMET, mismas normales: la maxima media anual es 18,6 y la minima media 10,9,
## o sea 7,7 grados de recorrido, la mitad 3,85. Y es notablemente constante a
## lo largo del año -7,4 en enero, 7,2 en julio-, cosa de costa: el mar no deja
## que el dia se dispare. Se redondea a 3,8.
const MEDIO_DIA := 3.8

## A que hora se llega al maximo del dia. Media tarde, no mediodia: el suelo
## sigue soltando calor un par de horas despues de que el sol este mas alto.
const HORA_MAS_CALIDA := 15.0


## Cuanto enfria subir, en grados por cada cien metros.
##
## 0,65 es el gradiente termico vertical de la atmosfera. **NO ES UNA CIFRA DE
## BALANCEO**: es fisica, y no se ajusta para que una partida cuadre. Si el
## roquedo resulta inhabitable, lo que se cambia es el roquedo.
const GRADIENTE_POR_100M := 0.65


## Los grados que hace en una estacion, a una hora y a una cota.
##
## `hora` es la del reloj del juego, de 0 a 24. `altitud_m` es la cota sobre el
## nivel del mar DE ESA EPOCA, no sobre el de hoy: quien la pida tiene que
## haberla medido contra el mar que toque.
static func grados(estacion: Subsistence.Season, hora: float,
		altitud_m: float) -> float:
	var base := media_de_la_estacion(estacion)
	var enfria_la_altura := GRADIENTE_POR_100M * altitud_m / 100.0
	return base + _vuelta_del_dia(hora) - enfria_la_altura


## La media del dia entero en esa estacion, al nivel del mar y en esta epoca.
static func media_de_la_estacion(estacion: Subsistence.Season) -> float:
	var meses: Array = MESES_DE_LA_ESTACION.get(estacion, [11, 0, 1])
	var suma := 0.0
	for mes: int in meses:
		suma += float(MEDIA_MENSUAL_HOY[mes])
	return suma / float(meses.size()) + anomalia(estacion)


## El desfase frio de esta epoca en esa estacion.
##
## Invierno y verano vienen de la fuente; primavera y otoño son el punto medio
## entre los dos, que es lo unico honesto que se puede decir con un trabajo que
## reconstruye enero y julio y no las medias templadas.
static func anomalia(estacion: Subsistence.Season) -> float:
	match estacion:
		Subsistence.Season.INVIERNO:
			return ANOMALIA_INVIERNO
		Subsistence.Season.VERANO:
			return ANOMALIA_VERANO
		_:
			return (ANOMALIA_INVIERNO + ANOMALIA_VERANO) * 0.5


## Lo que sube o baja el termometro por la hora que es.
static func _vuelta_del_dia(hora: float) -> float:
	var vuelta := (hora - HORA_MAS_CALIDA) / 24.0 * TAU
	return MEDIO_DIA * cos(vuelta)
