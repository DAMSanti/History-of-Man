class_name Weather
extends RefCounted
## El tiempo que hace, por jornadas.
##
## Se añade porque sin él la «tormenta» de los percances era una tirada sin
## causa: te pasaba y ya. Con clima, el temporal es algo que ves venir —hace
## dos días que no para de llover— y decidir si sales igual es una decisión
## tuya, no un dado.
##
## Y porque el Cantábrico sin lluvia no es el Cantábrico. Aquí llueven
## 1.200-1.400 mm al año repartidos en unos 130 días, con el orbayu —esa
## llovizna fina que no cesa— como estado por defecto de media estación. Un
## valle del Nansa siempre despejado sería un valle de otro sitio.

enum Kind {
	DESPEJADO,   ## Se ve lejos y se anda bien
	NUBLADO,     ## Sin más consecuencia que la luz
	ORBAYU,      ## Llovizna fina y constante: lo normal aquí
	LLUVIA,      ## Moja de verdad. El suelo resbala
	TEMPORAL,    ## Viento y agua: no se sale, y quien está fuera vuelve
	NIEBLA,      ## No se ve. Explorar no sirve de nada
	NIEVE,       ## Sólo en invierno. Lo tapa todo
}

const NAMES := {
	Kind.DESPEJADO: "Despejado", Kind.NUBLADO: "Nublado",
	Kind.ORBAYU: "Orbayu", Kind.LLUVIA: "Lluvia",
	Kind.TEMPORAL: "Temporal", Kind.NIEBLA: "Niebla",
	Kind.NIEVE: "Nieve",
}

## Lo que hace cada tiempo, dicho como se diría.
const TELLS := {
	Kind.DESPEJADO: "Amanece despejado. Se ve el valle entero.",
	Kind.NUBLADO: "Cielo cubierto, sin agua.",
	Kind.ORBAYU: "Orbayu: no llueve, moja. Lleva así desde antes de amanecer.",
	Kind.LLUVIA: "Llueve. El suelo resbala y la leña no prende.",
	Kind.TEMPORAL: "Temporal de agua y viento. Hoy no se sale del abrigo.",
	Kind.NIEBLA: "Niebla cerrada. No se ve la mano.",
	Kind.NIEVE: "Ha nevado. El monte está tapado.",
}

## Pesos por estación. Suman lo que sea: se normalizan al sortear.
##
## Calibrado a lo que hace de verdad en la costa cantábrica: el otoño y el
## invierno son lo húmedo, el verano tiene la mitad de días de lluvia pero no
## se seca, y la niebla es cosa de mañanas frías y de primavera.
const ODDS := {
	Subsistence.Season.PRIMAVERA: {
		Kind.DESPEJADO: 22, Kind.NUBLADO: 26, Kind.ORBAYU: 24,
		Kind.LLUVIA: 16, Kind.TEMPORAL: 4, Kind.NIEBLA: 8, Kind.NIEVE: 0,
	},
	Subsistence.Season.VERANO: {
		Kind.DESPEJADO: 40, Kind.NUBLADO: 28, Kind.ORBAYU: 16,
		Kind.LLUVIA: 10, Kind.TEMPORAL: 2, Kind.NIEBLA: 4, Kind.NIEVE: 0,
	},
	Subsistence.Season.OTONO: {
		Kind.DESPEJADO: 16, Kind.NUBLADO: 22, Kind.ORBAYU: 26,
		Kind.LLUVIA: 22, Kind.TEMPORAL: 8, Kind.NIEBLA: 6, Kind.NIEVE: 0,
	},
	Subsistence.Season.INVIERNO: {
		Kind.DESPEJADO: 14, Kind.NUBLADO: 20, Kind.ORBAYU: 20,
		Kind.LLUVIA: 22, Kind.TEMPORAL: 12, Kind.NIEBLA: 6, Kind.NIEVE: 6,
	},
}

var kind: Kind = Kind.NUBLADO

## Cuántas jornadas lleva así. Un temporal de tres días no es lo mismo que uno
## de uno, y saberlo es lo que permite decir «lleva así desde el martes».
var days_running: int = 1


## Sortea el tiempo de mañana.
##
## El tiempo TIENE INERCIA: lo más probable con diferencia es que mañana haga
## lo mismo que hoy. Sorteando cada día de cero salía un cielo epiléptico que
## no se parece a ningún sitio real, y además hacía imposible planificar.
const PERSISTENCE := 0.45


func advance(rng: RandomNumberGenerator, season: Subsistence.Season) -> bool:
	if rng.randf() < PERSISTENCE:
		days_running += 1
		return false

	var table: Dictionary = ODDS[season]
	var total := 0
	for value: int in table.values():
		total += value

	var draw := rng.randi_range(1, maxi(total, 1))
	var running := 0
	for candidate: int in table:
		running += int(table[candidate])
		if draw <= running:
			var changed := candidate != kind
			kind = candidate as Kind
			days_running = 1 if changed else days_running + 1
			return changed
	return false


func name_text() -> String:
	return String(NAMES.get(kind, "?"))


## Cómo se cuenta en la crónica, con lo que lleva durando si lleva.
func tell() -> String:
	var base := String(TELLS.get(kind, ""))
	if days_running >= 3:
		return base + " Van %d días." % days_running
	return base


## Cuánto rinde el trabajo hoy, como multiplicador.
##
## Bajo el agua se recoge peor: se ve menos, se coge menos y se para más. No
## es cero ni de lejos —la gente trabajaba lloviendo, que si no aquí no se
## come— pero se nota.
func work_factor() -> float:
	match kind:
		Kind.DESPEJADO: return 1.05
		Kind.ORBAYU: return 0.9
		Kind.LLUVIA: return 0.75
		Kind.TEMPORAL: return 0.35
		Kind.NIEBLA: return 0.8
		Kind.NIEVE: return 0.5
		_: return 1.0


## Cuánto se anda, como multiplicador de la velocidad.
func pace_factor() -> float:
	match kind:
		Kind.LLUVIA: return 0.9
		Kind.TEMPORAL: return 0.65
		Kind.NIEVE: return 0.6
		Kind.NIEBLA: return 0.85
		_: return 1.0


## Cuánto multiplica el riesgo de percance.
##
## Es la razón de ser de todo esto: que el tobillo torcido tenga una causa que
## el jugador ha podido ver venir, en vez de ser un dado a ciegas.
func risk_factor() -> float:
	match kind:
		Kind.LLUVIA: return 1.5
		Kind.TEMPORAL: return 2.6
		Kind.NIEVE: return 2.2
		Kind.NIEBLA: return 1.8
		Kind.ORBAYU: return 1.15
		_: return 1.0


## Hasta dónde se ve, como multiplicador del alcance de la vista.
##
## Con niebla, explorar no sirve de nada: se anda igual y no se aprende mapa.
func sight_factor() -> float:
	match kind:
		Kind.DESPEJADO: return 1.25
		Kind.NIEBLA: return 0.25
		Kind.TEMPORAL: return 0.4
		Kind.LLUVIA: return 0.7
		Kind.NIEVE: return 0.55
		_: return 1.0


## Si con este tiempo no se sale del abrigo.
func keeps_indoors() -> bool:
	return kind == Kind.TEMPORAL
