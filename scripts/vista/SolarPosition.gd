class_name SolarPosition
extends RefCounted
## Dónde está el sol, de verdad, para una latitud y un día del año.
##
## Sustituye a la fórmula que había en [WorldEnvironmentSetup], que era
## `-30 - sin(hora/24·π)·60`. Aquello daba noventa grados a mediodía —el sol EN
## VERTICAL— y eso no pasa en ningún sitio de España: a 43° de latitud el sol de
## mediodía sube a 70° en el solsticio de verano, a 47° en los equinoccios y se
## queda en 23° en el de invierno. Además la altura no dependía de la estación,
## con lo que el invierno se iluminaba igual que el verano.
##
## No hay nada que ajustar aquí y ésa es la gracia: sabemos dónde está el
## emplazamiento —Cueva los Pendios, 43,28° N— y sabemos qué día es. La posición
## del sol sale de eso y de la mecánica celeste, no de un número que quede bien.
##
## Se trabaja en TIEMPO SOLAR VERDADERO, o sea que las doce son, por definición,
## el momento en que el sol está más alto. Es lo correcto para este juego por
## partida doble: es lo que hace la trigonometría más simple y es lo único que
## significaba algo en el Magdaleniense, donde no había husos horarios ni
## relojes que corregir.

## Inclinación del eje de la Tierra, en grados.
##
## El valor de hoy. Hace quince mil años andaba por los 24°, porque la
## oblicuidad oscila entre 22,1° y 24,5° cada cuarenta y un mil años y por
## entonces venía de un máximo. La diferencia son ocho décimas de grado en la
## altura del sol de solsticio: real, comprobable y absolutamente invisible en
## pantalla. Se deja el valor moderno y queda anotado.
const OBLIQUITY := 23.44

## Qué día del año real es el primero de la primavera del juego.
##
## El calendario del juego son cuatro estaciones de cuarenta y cinco días. Se
## ancla su
## primer día al equinoccio de primavera —21 de marzo, día 80— que es lo que
## hace que «Primavera» signifique primavera y no un nombre suelto.
const SPRING_START_DAY := 80.0

## Días de un año. Uno solo, y con el valor bueno.
##
## Había DOS: 365,0 para la declinación y el calendario, y 365,2422 -el año
## trópico- para la longitud eclíptica de la luna. La diferencia es un cuarto
## de día, invisible, pero dos constantes para la misma magnitud es como se
## acaba corrigiendo una y olvidando la otra.
const YEAR_DAYS := 365.2422


## Altura del sol sobre el horizonte y dirección de la que viene, en radianes.
##
## Devuelve además el VECTOR de mundo que apunta al sol, que es lo que de verdad
## se usa: convertir a ángulos y volver es una fuente de errores de cuadrante
## que aquí no hace ninguna falta.
##
## En este mapa el norte es -Z y el este +X: sale de `v_for_lat`, que pone el
## borde norte del recuadro en v=0 y por tanto en z=0.
static func at(latitude_deg: float, day_of_year: float,
		solar_hour: float) -> Dictionary:
	var phi := deg_to_rad(latitude_deg)
	var delta := deg_to_rad(declination(day_of_year))
	# Ángulo horario: cero al mediodía solar, quince grados por hora, negativo
	# por la mañana.
	var hour_angle := deg_to_rad((solar_hour - 12.0) * 15.0)

	# Del sistema ecuatorial al horizonte local. Ver `_to_horizon`: es la
	# transformación directa, sin pasar por la altura, así que no hay divisiones
	# por el coseno de la altura -que se va a cero en el cenit-.
	return _to_horizon(phi, delta, hour_angle)


## Declinación del sol para un día del año, en grados.
##
## Es la ecuación de Cooper: la aproximación de manual, con un error de menos de
## medio grado en todo el año. Sobra de largo para iluminar un valle; lo que
## importa es que el verano tenga el sol alto y el invierno bajo, y eso lo
## clava.
static func declination(day_of_year: float) -> float:
	return OBLIQUITY * sin(TAU * (284.0 + day_of_year) / YEAR_DAYS)


## Pasa el calendario del juego —cuatro estaciones de cuarenta y cinco días,
## tres meses de quince cada una— al día del
## año real que le corresponde.
static func day_of_year(season: int, day: int, days_per_season: int,
		seasons_per_year: int) -> float:
	var total := float(maxi(days_per_season * seasons_per_year, 1))
	var elapsed := float(season * days_per_season + maxi(day - 1, 0))
	return fmod(SPRING_START_DAY + elapsed / total * YEAR_DAYS,
		YEAR_DAYS)


## --- La luna ---------------------------------------------------------------
##
## Se modela como un cuerpo SOBRE LA ECLÍPTICA, adelantado al sol tantos grados
## como diga la fase. Es una simplificación, pero de las buenas: la órbita de la
## luna está inclinada sólo cinco grados respecto a la eclíptica, así que darla
## por contenida en ella se equivoca menos de lo que se nota en un valle.
##
## Y a cambio sale bien todo lo que importa: la luna nueva se pone con el sol, la
## llena sale cuando el sol se pone, cada día sale unos cincuenta minutos más
## tarde, y en invierno la llena pasa ALTA mientras el sol pasa bajo -porque está
## en el lado opuesto de la eclíptica-, que es una de esas cosas que se notan sin
## saber nombrarlas.

## Duración de una lunación, en días reales: de luna nueva a luna nueva.
const SYNODIC_MONTH := 29.53059



## En qué fase está la luna: 0 es nueva, 0,5 llena, y vuelve a 1 en nueva.
##
## Se cuenta de los días REALES transcurridos, no de los de juego, porque la
## lunación es un periodo físico y el calendario del juego es una convención.
##
## Aunque las dos casi coinciden, y merece la pena saberlo: un mes de juego son
## quince días, que a dos días reales por día de juego salen 30,4 días reales
## contra los 29,5 de una lunación. Un tres por ciento. O sea que los meses
## inventados de este juego son, de hecho, meses lunares -que es justo lo que era
## un calendario en el Magdaleniense-.
static func moon_phase(elapsed_real_days: float) -> float:
	return fposmod(elapsed_real_days / SYNODIC_MONTH, 1.0)


## Qué parte del disco se ve iluminada, de 0 a 1.
##
## Sale del ángulo entre la luna y el sol vistos desde aquí: en luna nueva vale
## cero porque la cara iluminada mira al otro lado, y en llena vale uno.
static func moon_lit(phase: float) -> float:
	return (1.0 - cos(TAU * phase)) * 0.5


## Dónde está la luna, con la misma salida que `at`.
static func moon_at(latitude_deg: float, day_of_year: float,
		solar_hour: float, phase: float) -> Dictionary:
	# Longitud eclíptica del sol, contada desde el equinoccio de primavera.
	var sun_longitude := (day_of_year - SPRING_START_DAY) / YEAR_DAYS * TAU
	# Y la de la luna: la del sol más lo que se haya adelantado en su vuelta.
	var moon_longitude := sun_longitude + TAU * phase

	var sun_sky := _ecliptic_to_equatorial(sun_longitude)
	var moon_sky := _ecliptic_to_equatorial(moon_longitude)

	# El ángulo horario del sol es la hora solar, por definición. El de la luna
	# es el mismo corregido por lo que se hayan separado en ascensión recta: eso
	# es lo que hace que la luna salga cada día más tarde.
	var sun_angle := deg_to_rad((solar_hour - 12.0) * 15.0)
	var sun_ra: float = sun_sky["ra"]
	var moon_ra: float = moon_sky["ra"]
	var moon_dec: float = moon_sky["dec"]

	var sky := _to_horizon(deg_to_rad(latitude_deg), moon_dec,
		sun_angle + sun_ra - moon_ra)
	# Se renombra la clave: quien pida la luna no debe recibir algo que se llame
	# «hacia el sol», que es como se cuelan los errores de copiar y pegar.
	return {"elevation": sky["elevation"], "to_moon": sky["to_sun"]}


## De coordenadas eclípticas a ecuatoriales, para un cuerpo sobre la eclíptica.
static func _ecliptic_to_equatorial(longitude: float) -> Dictionary:
	var tilt := deg_to_rad(OBLIQUITY)
	return {
		"dec": asin(sin(tilt) * sin(longitude)),
		"ra": atan2(cos(tilt) * sin(longitude), cos(longitude)),
	}


## De declinación y ángulo horario a lo que se ve desde el suelo.
##
## Es la misma transformación que usa `at`, sacada aparte para que el sol y la
## luna no puedan acabar usándola de dos maneras distintas.
static func _to_horizon(phi: float, dec: float, hour_angle: float) -> Dictionary:
	var east := -cos(dec) * sin(hour_angle)
	var north := sin(dec) * cos(phi) - cos(dec) * sin(phi) * cos(hour_angle)
	var up := sin(dec) * sin(phi) + cos(dec) * cos(phi) * cos(hour_angle)
	return {
		"elevation": asin(clampf(up, -1.0, 1.0)),
		"to_sun": Vector3(east, up, -north).normalized(),
	}


## La orientación que hay que darle a una luz direccional para que sea ese sol.
##
## Una direccional alumbra hacia su -Z, así que hay que apuntarla en el sentido
## CONTRARIO al que está el sol. El «arriba» de referencia se cambia cuando el
## sol está casi en el cenit: con el sol vertical, la vertical no sirve para
## orientar nada y la base saldría degenerada.
static func light_basis(to_sun: Vector3) -> Basis:
	var travel := -to_sun
	var up := Vector3.UP if absf(travel.y) < 0.99 else Vector3.FORWARD
	return Basis.looking_at(travel, up)
