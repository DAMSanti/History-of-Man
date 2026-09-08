class_name Subsistence
extends RefCounted
## Que puede comer una banda en un emplazamiento, y cuanto.
##
## Todo se mide en JORNADAS-PERSONA: lo que come una persona en un dia. Una
## banda de 25 en una estacion de [DAYS_PER_SEASON] dias necesita 25 veces
## eso. Asi el alimento, el trabajo y el tiempo estan en la misma unidad y no
## hay que inventar conversiones.
##
## Los rendimientos salen de los atributos reales del emplazamiento, no de una
## tabla por tipo: un sitio a 300 m de un cauce puede pescar, uno a 20 km no.

enum Activity { CAZA, PESCA, MARISQUEO, RECOLECCION, MATERIA_PRIMA }

enum Season { PRIMAVERA, VERANO, OTONO, INVIERNO }

## Cuarenta y cinco: bastante para notar la estación -y para que dé tiempo a
## reorganizar la banda cuando cambia- sin que un año entero se haga eterno.
## Antes eran 90 -un año de 360-, y ese ritmo se sentía demasiado largo para
## lo que de verdad avanza la partida en ese tiempo.
const DAYS_PER_SEASON := 45

## Meses inventados: no son un calendario de verdad -nadie en el Paleolítico
## contaba así-, son solo un marcador más fino que la estación para que un
## cambio a media estación -una helada tardía, una desbandada de salmón- se
## pueda fechar sin decir "a mitad de primavera, más o menos". Quince días
## parte la estación en tres tercios limpios.
const DAYS_PER_MONTH := 15
const MONTHS_PER_SEASON := 3

## Un nombre por tercio de estación, no un número: "el mes 2 de verano" no
## dice nada, "la sequía" sí. Van de lo que empieza a lo que ya se nota y a
## lo que ya se acaba, dentro de cada estación.
const MONTH_NAMES := {
	Season.PRIMAVERA: ["el deshielo", "los brotes", "el retorno"],
	Season.VERANO: ["el bochorno", "la sequía", "la maduración"],
	Season.OTONO: ["la cosecha", "el desmogue", "las brumas"],
	Season.INVIERNO: ["el hielo", "la escasez", "el resguardo"],
}


## El mes -inventado- que toca, según cuántos días lleva la estación en
## curso. Ver [DAYS_PER_MONTH].
static func month_name(season: Season, season_day: int) -> String:
	var index := clampi(season_day / DAYS_PER_MONTH, 0, MONTHS_PER_SEASON - 1)
	return (MONTH_NAMES[season] as Array)[index]

## Cuanta gente hace falta para una partida de trabajo
const PEOPLE_PER_PARTY := 5.0

## Distancia maxima para explotar la costa desde el asentamiento, en km.
## Mas lejos, el marisqueo exige campamento aparte y deja de ser una actividad
## que se hace desde casa.
const COAST_REACH_KM := 9.0

## Distancia maxima al cauce para pescar
const RIVER_REACH_KM := 2.5


static func season_name(s: Season) -> String:
	match s:
		Season.PRIMAVERA: return "Primavera"
		Season.VERANO: return "Verano"
		Season.OTONO: return "Otoño"
		_: return "Invierno"


static func activity_name(a: Activity) -> String:
	match a:
		Activity.CAZA: return "Caza"
		Activity.PESCA: return "Pesca"
		Activity.MARISQUEO: return "Marisqueo"
		Activity.RECOLECCION: return "Recolección"
		_: return "Materia prima"


## Actividades posibles en este sitio y esta estacion
static func available(site: Site, season: Season) -> Array[Activity]:
	var out: Array[Activity] = [Activity.CAZA, Activity.MATERIA_PRIMA]

	# El salmon sube en primavera. Es el gran recurso estacional de los rios
	# cantabricos y esta documentado en los yacimientos magdalenienses.
	if season == Season.PRIMAVERA and site.water_km <= RIVER_REACH_KM:
		out.append(Activity.PESCA)

	# El marisco esta todo el año. Poco rendimiento, pero no falla: es el
	# recurso de temporada mala.
	if site.coast_km <= COAST_REACH_KM:
		out.append(Activity.MARISQUEO)

	if season == Season.VERANO or season == Season.OTONO:
		out.append(Activity.RECOLECCION)

	return out


## Jornadas-persona que produce una partida en una estacion.
## Devuelve 0 si la actividad no esta disponible aqui.
static func yield_per_party(site: Site, season: Season, activity: Activity) -> float:
	if not available(site, season).has(activity):
		return 0.0

	match activity:
		Activity.CAZA:
			# El otoño es la berrea: la mejor caza del año con diferencia, y
			# es cuando se decide si se pasa el invierno.
			var base := 620.0 if season == Season.OTONO else (
				420.0 if season == Season.VERANO else (
				330.0 if season == Season.PRIMAVERA else 210.0))
			# Terreno: el valle y el bosque dan ciervo; el roquedo, cabra
			var terrain := 1.0
			if site.slope_deg > 20.0:
				terrain = 0.75
			elif site.slope_deg < 10.0:
				terrain = 1.15
			return base * terrain

		Activity.PESCA:
			return 520.0 * clampf(2.0 - site.water_km, 0.6, 1.4)

		Activity.MARISQUEO:
			# Fiable pero pobre, y peor cuanto mas lejos queda la orilla
			return 210.0 * clampf(1.4 - site.coast_km / 12.0, 0.4, 1.2)

		Activity.RECOLECCION:
			return 250.0 if season == Season.OTONO else 210.0

		_:
			return 0.0


## Lo que consume la banda en una estacion
static func consumption(population: int) -> float:
	return float(population) * float(DAYS_PER_SEASON)


## Partidas de trabajo que puede formar la banda.
## Se redondea en vez de truncar: con division entera, crecer de 25 a 29
## anadia bocas sin anadir un solo trabajador, y la banda entraba en espiral.
static func parties(population: int) -> int:
	return maxi(roundi(float(population) / PEOPLE_PER_PARTY), 1)


## Techo de lo que el sitio puede dar en una estacion, mandes las partidas que
## mandes. Es lo que crea la CAPACIDAD DE CARGA: un valle no tiene ciervos
## infinitos, y sin este tope la produccion escalaba con la poblacion, asi que
## o crecias sin limite o te extinguias. Es tambien lo que obliga a expandirse.
static func season_cap(site: Site, season: Season, activity: Activity) -> float:
	match activity:
		Activity.CAZA:
			var base := 3200.0 if season == Season.OTONO else (
				2100.0 if season == Season.VERANO else (
				1600.0 if season == Season.PRIMAVERA else 1150.0))
			# Un valle ancho sostiene mas manada que un roquedo
			return base * (1.15 if site.slope_deg < 10.0 else 1.0)
		Activity.PESCA:
			return 3100.0
		Activity.MARISQUEO:
			# Los bancos de marisco se agotan y tardan en reponerse
			return 1100.0
		Activity.RECOLECCION:
			return 1000.0 if season == Season.OTONO else 900.0
		_:
			return 99999.0


## Lo que rinde de verdad un numero de partidas, con el techo del sitio
static func harvest(site: Site, season: Season, activity: Activity, party_count: int) -> float:
	var per := yield_per_party(site, season, activity)
	return minf(per * float(party_count), season_cap(site, season, activity))


## Cuanta gente puede sostener el sitio al año.
##
## Es el minimo entre lo que dan los recursos y lo que puede recoger la mano de
## obra: de nada sirve un valle lleno de ciervos si no hay partidas para
## batirlo, y al reves. Por eso el limite se mueve al mejorar la tecnica.
static func carrying_capacity(site: Site, population: int = 0) -> int:
	var resource_total := 0.0
	var labour_total := 0.0
	var party_count := parties(population) if population > 0 else 5

	for s: int in [0, 1, 2, 3]:
		var season := s as Season
		var acts: Array[Activity] = []
		for a: int in available(site, season):
			if a != Activity.MATERIA_PRIMA:
				acts.append(a as Activity)
		for a: Activity in acts:
			resource_total += season_cap(site, season, a)
		# Con la mano de obra repartida en lo mejor de cada estacion
		var best := 0.0
		for a: Activity in acts:
			best = maxf(best, harvest(site, season, a, party_count))
		labour_total += best

	return int(minf(resource_total, labour_total * 1.15) / float(DAYS_PER_SEASON * 4))
