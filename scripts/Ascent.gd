class_name Ascent
extends RefCounted
## Subir a una cumbre: cuándo se intenta y cuándo se corona.
##
## Antes coronar era llegar. Se mandaba a cualquiera al punto más alto de la
## comarca y con pisar la cima bastaba, lo cual convierte una ascensión en un
## desplazamiento. Nadie sube así: hay cumbres que uno no ataca si no sabe, y
## hay días en que se llega a media pared y se da media vuelta.
##
## Aquí la pericia hace DOS cosas distintas, y las dos importan:
##   · decide a qué cumbre se atreve uno — un novato no elige el pico peor
##   · decide si corona la que ha elegido

## Cuánto desnivel sobre el campamento cuenta como «una cumbre seria».
const HARD_RISE := 400.0

## Pendiente a partir de la cual la cima ya no se anda, se trepa.
const HARD_SLOPE := 0.75


## Lo dura que es una cumbre, de 0 a 1.
##
## Sale de lo que de verdad cuesta subir: cuánto se levanta sobre el valle,
## cómo está de empinada la última parte y lo lejos que queda —una cumbre a
## seis kilómetros se ataca cansado—.
static func difficulty(rise: float, slope: float, distance_m: float) -> float:
	var by_rise := clampf(rise / HARD_RISE, 0.0, 1.0)
	var by_slope := clampf(slope / HARD_SLOPE, 0.0, 1.0)
	var by_distance := clampf(distance_m / 5000.0, 0.0, 1.0)
	return clampf(by_rise * 0.45 + by_slope * 0.40 + by_distance * 0.15, 0.0, 1.0)


## Dureza a partir de la cual una cumbre NO se sube con lo que hay.
##
## No es que sea difícil: es que no se hace. Una pared de roca vertical no se
## corona con pericia, se corona con cuerda trenzada de verdad, con calzado
## que agarre y con gente que sepa asegurar a otra, y nada de eso existe en el
## Paleolítico. Esas cumbres se quedan mirando desde abajo hasta que el juego
## llegue a la era que las abra.
##
## Se pone como límite explícito y no como una probabilidad ínfima a
## propósito: dejar que se intente y falle siempre es hacerle perder jornadas
## al jugador sin decirle por qué. Que no se pueda —y que se sepa— es mejor
## diseño y además es verdad.
const GEAR_THRESHOLD := 0.88


## Si esta cumbre pide equipo que la banda todavía no sabe hacer.
static func needs_gear(hardness: float) -> bool:
	return hardness >= GEAR_THRESHOLD


## A qué dureza se atreve alguien con esta pericia.
##
## Un novato no se planta delante de la peor pared de la comarca: mira el
## monte, calcula, y se va a otro. Es lo que hace que la pericia se note ANTES
## de tirar ningún dado.
##
## Con pericia 0,5 —lo que trae alguien que empieza— se atreve con la mitad de
## lo que hay; con maestría, con todo.
static func dares(skill: float) -> float:
	return clampf(skill * 1.25, 0.20, 1.0)


## Probabilidad de coronar, si se intenta.
##
## Mandar a un novato a una cumbre dura tiene que salir mal casi siempre: es
## la petición literal —«no llegará arriba nueve de cada diez veces»— y es lo
## que hace que la pericia valga algo. Pero coronar algo que está a tu nivel
## tiene que salir bien casi siempre, o nadie sube nunca.
static func chance(skill: float, hardness: float, weather_risk: float,
		fatigue: float) -> float:
	# Cuánto le sobra o le falta a esta persona para esta cumbre
	var margin := dares(skill) - hardness

	# En su nivel justo, algo más de la mitad. Por encima sube despacio; por
	# debajo se desploma deprisa, que es lo que separa «difícil» de «no es
	# para ti».
	var base := 0.55 + margin * 0.9
	if margin < 0.0:
		base = 0.55 + margin * 3.2

	# Se acota ANTES de aplicar tiempo y cansancio. Sin esto, la pericia de
	# sobra empujaba el número por encima de 1, el recorte lo devolvía a 0,97
	# y entonces daba igual salir reventado o descansado: los dos casos
	# tocaban el techo. Un factor que no cambia nada no es un factor.
	base = clampf(base, 0.0, 1.0)

	# El tiempo y el cansancio no perdonan en una pared
	base /= maxf(weather_risk, 1.0)
	base -= clampf(fatigue / 100.0, 0.0, 1.0) * 0.45

	return clampf(base, 0.03, 0.97)


## Hasta dónde llegó quien no coronó, como fracción de la subida.
##
## Sirve para contarlo: «se quedó a doscientos metros de la cima» dice mucho
## más que «no pudo».
static func reached(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(0.45, 0.9)
