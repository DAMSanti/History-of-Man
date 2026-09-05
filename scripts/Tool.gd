class_name Tool
extends RefCounted
## Una herramienta concreta, con su desgaste propio.
##
## Es por PIEZA y no un contador agregado, y el motivo es el material: una
## raedera de cuarcita y una de sílex hacen el mismo trabajo pero duran cosas
## muy distintas, y esa diferencia es lo que convierte «ir a por sílex a
## cuarenta kilómetros» en una decisión económica en vez de en un capricho.
##
## A escala de banda esto es barato: quince personas manejan del orden de
## treinta a sesenta piezas. Sería otra cosa en un poblado de doscientos, y
## entonces habría que agregar.

enum Kind {
	BURIL,      ## Ranura el asta. Sin él, el astero no trabaja
	RAEDERA,    ## Descarna la piel. Sin ella, el peletero no trabaja
	LASCA,      ## Filo de uso general: despiece, corte
	PUNTA,      ## Punta lítica para enmangar
	AZAGAYA,    ## Punta de asta enmangada: caza mayor
	ARPON,      ## Asta dentada: pesca de remonte
	AGUJA,      ## Hueso: coser piel
	PUNZON,     ## Hueso: perforar
	CESTO,      ## Fibra: duplica lo que se trae de una jornada
	ODRE,       ## Piel: transportar agua
	CUERDA,     ## Fibra trenzada: ligaduras, lazos
	NASA,       ## Mimbre en embudo: pesca sola mientras se hace otra cosa
	ANZUELO,    ## Bastoncillo de hueso apuntado por los dos cabos. Con cebo
	RED,        ## Fibra trenzada entre dos orillas: lo que mas pescado da
}

## De qué está hecha. Decide cuánto aguanta.
enum Stuff { CUARCITA, SILEX, ASTA, HUESO, FIBRA, PIEL }

## Usos que aguanta cada material antes de quedar inservible.
##
## El sílex da unas tres veces más filo útil que la cuarcita: aguanta el doble
## de usos y además se puede reavivar. Es la cifra que justifica el viaje.
const DURABILITY := {
	Stuff.CUARCITA: 45.0,
	Stuff.SILEX: 130.0,
	Stuff.ASTA: 90.0,
	Stuff.HUESO: 70.0,
	Stuff.FIBRA: 60.0,
	Stuff.PIEL: 80.0,
}

const KIND_NAMES := {
	Kind.BURIL: "Buril", Kind.RAEDERA: "Raedera", Kind.LASCA: "Lasca",
	Kind.PUNTA: "Punta", Kind.AZAGAYA: "Azagaya", Kind.ARPON: "Arpón",
	Kind.AGUJA: "Aguja", Kind.PUNZON: "Punzón", Kind.CESTO: "Cesto",
	Kind.ODRE: "Odre", Kind.CUERDA: "Cuerda", Kind.NASA: "Nasa",
	Kind.ANZUELO: "Anzuelo", Kind.RED: "Red",
}

const STUFF_NAMES := {
	Stuff.CUARCITA: "cuarcita", Stuff.SILEX: "sílex", Stuff.ASTA: "asta",
	Stuff.HUESO: "hueso", Stuff.FIBRA: "fibra", Stuff.PIEL: "piel",
}

var kind: Kind = Kind.LASCA
var stuff: Stuff = Stuff.CUARCITA

## Usos acumulados. Cuando llega a la durabilidad, la pieza está agotada.
var used: float = 0.0

## Quién la hizo, y con qué pericia. Una pieza de buen tallador dura más.
var quality: float = 1.0


## Usos que se lleva una JORNADA ENTERA de trabajo con cada tipo.
##
## No todas se gastan igual y el motivo importa: la azagaya es la que mas se
## rompe porque su modo de fallo es el impacto, no el rozamiento -se parte
## contra el hueso, y esa es la razon de que aparezcan a cientos en los
## yacimientos-. El cesto, en cambio, aguanta una estacion entera.
const WEAR_PER_DAY := {
	Kind.AZAGAYA: 3.0,
	Kind.ARPON: 2.5,
	Kind.LASCA: 2.0,
	Kind.RAEDERA: 2.0,
	Kind.PUNTA: 2.5,
	Kind.BURIL: 1.5,
	Kind.AGUJA: 1.0,
	Kind.PUNZON: 1.0,
	Kind.CUERDA: 1.2,
	Kind.ODRE: 0.6,
	Kind.CESTO: 0.8,
	# La nasa se cala en el agua y se pudre; la red se engancha y se rompe
	# por donde menos conviene. El anzuelo de hueso es lo que mas aguanta de
	# los tres: no roza contra nada, solo se pierde con el pez que se lo
	# lleva.
	Kind.NASA: 1.1,
	Kind.ANZUELO: 0.9,
	Kind.RED: 1.4,
}


## Cuanto aguanta de media una pieza de este tipo, con la materia con la que
## se suele hacer. Sirve para estimar cuantas se rompen en un mes.
static func durability_of(kind_value: Kind) -> float:
	return float(DURABILITY[default_stuff(kind_value)])


static func wear_per_day(kind_value: Kind) -> float:
	return float(WEAR_PER_DAY.get(kind_value, 1.5))


## De que materia se hace normalmente cada tipo, si no se dice otra cosa.
static func default_stuff(kind_value: Kind) -> Stuff:
	match kind_value:
		Kind.BURIL, Kind.RAEDERA, Kind.LASCA, Kind.PUNTA:
			return Stuff.CUARCITA
		Kind.AZAGAYA, Kind.ARPON:
			return Stuff.ASTA
		Kind.AGUJA, Kind.PUNZON:
			return Stuff.HUESO
		Kind.ODRE:
			return Stuff.PIEL
		Kind.ANZUELO:
			return Stuff.HUESO
		_:
			return Stuff.FIBRA


static func make(kind_value: Kind, stuff_value: Stuff, maker_skill: float = 0.5) -> Tool:
	var tool := Tool.new()
	tool.kind = kind_value
	tool.stuff = stuff_value
	# La pericia del artesano se nota en la vida útil, no en el rendimiento:
	# una hoja bien sacada tiene el filo más regular y se reaviva mejor
	tool.quality = 0.7 + maker_skill * 0.6
	return tool


## Vida útil total de esta pieza, en usos.
func durability() -> float:
	return float(DURABILITY[stuff]) * quality


## De 1 (nueva) a 0 (agotada).
func condition() -> float:
	return clampf(1.0 - used / maxf(durability(), 0.001), 0.0, 1.0)


func is_spent() -> bool:
	return used >= durability()


## Gasta la herramienta. Devuelve si ha quedado inservible con este uso.
func wear(amount: float) -> bool:
	used += amount
	return is_spent()


func display_name() -> String:
	return "%s de %s" % [KIND_NAMES[kind], STUFF_NAMES[stuff]]


static func kind_name(kind_value: Kind) -> String:
	return KIND_NAMES[kind_value]


static func stuff_name(stuff_value: Stuff) -> String:
	return STUFF_NAMES[stuff_value]


## Qué material hace falta para fabricar cada tipo, y cuánto.
##
## Es la receta: sin la materia prima no hay pieza, y por eso la manufactura
## depende de que la recolección y la caza traigan lo suyo.
static func recipe(kind_value: Kind) -> Dictionary:
	match kind_value:
		Kind.BURIL, Kind.RAEDERA, Kind.LASCA, Kind.PUNTA:
			# La materia se decide al fabricar segun lo que haya en el abrigo:
			# si hay silex se gasta silex, y si no, cuarcita
			return {Materia.Kind.PIEDRA: 1.0}
		Kind.AZAGAYA:
			# Punta de asta, astil de madera y ligadura: cuatro materiales
			return {
				Materia.Kind.ASTA: 0.5, Materia.Kind.LENA: 0.2,
				Materia.Kind.FIBRA: 0.5, Materia.Kind.RESINA: 0.2,
			}
		Kind.ARPON:
			return {Materia.Kind.ASTA: 0.8, Materia.Kind.FIBRA: 0.4}
		Kind.AGUJA, Kind.PUNZON:
			return {Materia.Kind.HUESO: 0.4}
		Kind.ANZUELO:
			# El bastoncillo de hueso y el cordel que lo ata por el medio
			return {Materia.Kind.HUESO: 0.3, Materia.Kind.FIBRA: 0.4}
		Kind.NASA:
			# Cesteria, la misma que el cesto, trenzada en embudo
			return {Materia.Kind.FIBRA: 3.5}
		Kind.RED:
			# Una red es cordel y mas cordel: es la pieza mas cara de la banda
			return {Materia.Kind.FIBRA: 9.0}
		Kind.CESTO:
			return {Materia.Kind.FIBRA: 3.0}
		Kind.ODRE:
			return {Materia.Kind.PIEL: 1.0, Materia.Kind.FIBRA: 0.5}
		_:
			return {Materia.Kind.FIBRA: 1.5}


## Herramienta que hace falta PARA fabricar este tipo, o -1 si ninguna.
##
## Es lo que teje la cadena: el astero necesita buriles que hace el tallador, y
## el peletero raederas. Sin tallador, dos talleres se paran.
static func needs_tool(kind_value: Kind) -> int:
	match kind_value:
		Kind.AZAGAYA, Kind.ARPON, Kind.AGUJA, Kind.PUNZON:
			return Kind.BURIL
		Kind.ANZUELO:
			# El hueso se ranura y se apunta con buril, igual que el asta
			return Kind.BURIL
		Kind.RED:
			# Una red no se trenza sin cordel hecho antes
			return Kind.CUERDA
		Kind.ODRE:
			return Kind.RAEDERA
		_:
			return -1
