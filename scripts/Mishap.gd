class_name Mishap
extends RefCounted
## Lo que puede salir mal ahí fuera.
##
## Existe porque hasta ahora salir a explorar no podía salir mal, y sin
## posibilidad de perder no hay tensión al pulsar «id a mirar allí». Va
## DESPUÉS del clic a propósito: asumir un riesgo sólo significa algo si el
## riesgo lo eliges tú, y hasta que no se pudo señalar el destino, el riesgo
## habría sido un impuesto arbitrario en vez de una apuesta.
##
## Nada de esto mata a nadie. Una banda de quince no aguanta perder gente por
## un tiro de dados, y matar por azar es la forma más rápida de que el jugador
## deje de arriesgar nunca más.

enum Kind {
	TORCEDURA,   ## Un tobillo. Se anda peor durante días
	CAIDA,       ## Golpe en un canchal: peor, y se pierde lo que se llevaba
	PERDIDA,     ## Se pierde el rumbo y se vuelve sin nada
	TORMENTA,    ## Obliga a volver: no se llega adonde se iba
	HALLAZGO,    ## Y a veces sale BIEN: se tropieza con algo
}

## Probabilidad base de que pase algo en una jornada de expedición.
##
## 4% por jornada suena poco y no lo es: una expedición de cinco días a
## terreno malo se va por encima del 30%. Está calibrado para que salir lejos
## se note sin que salir sea suicida.
const BASE_CHANCE := 0.04

## Cuánto multiplica el riesgo el terreno malo y el cansancio.
const ROUGH_FACTOR := 2.2
const TIRED_FACTOR := 1.8

## Días que dura una torcedura y una caída.
const SPRAIN_DAYS := 4
const FALL_DAYS := 8


## Qué probabilidad hay de que a esta persona le pase algo hoy.
##
## Sube con el terreno que pisa, con el cansancio y con la distancia: lejos de
## casa, un tobillo torcido es otra cosa.
static func chance(ground: Traversal.Ground, fatigue: float,
		distance_m: float) -> float:
	var risk := BASE_CHANCE

	if ground == Traversal.Ground.CANCHAL or ground == Traversal.Ground.ROCA:
		risk *= ROUGH_FACTOR
	elif ground == Traversal.Ground.MARISMA:
		risk *= 1.6

	if fatigue > 60.0:
		risk *= TIRED_FACTOR

	# Cada kilómetro de más añade la mitad del riesgo base
	risk += BASE_CHANCE * 0.5 * (distance_m / 1000.0)

	return clampf(risk, 0.0, 0.45)


## Qué pasa, dado que ha pasado algo. Los pesos no son iguales: lo más común
## es volverse con las manos vacías, no romperse una pierna.
static func roll(rng: RandomNumberGenerator,
		ground: Traversal.Ground) -> Kind:
	var draw := rng.randf()

	# En canchal y roca lo que pasa es que uno se cae; en marisma, que se
	# pierde. El terreno decide QUÉ sale mal, no sólo cuánto.
	if ground == Traversal.Ground.CANCHAL or ground == Traversal.Ground.ROCA:
		if draw < 0.30:
			return Kind.CAIDA
		if draw < 0.60:
			return Kind.TORCEDURA
	elif ground == Traversal.Ground.MARISMA:
		if draw < 0.45:
			return Kind.PERDIDA

	if draw < 0.22:
		return Kind.TORCEDURA
	if draw < 0.40:
		return Kind.PERDIDA
	if draw < 0.62:
		return Kind.TORMENTA
	if draw < 0.88:
		return Kind.CAIDA
	return Kind.HALLAZGO


static func is_good(kind: Kind) -> bool:
	return kind == Kind.HALLAZGO


## Cuántos días queda tocada la persona.
static func hurt_days(kind: Kind) -> int:
	match kind:
		Kind.TORCEDURA: return SPRAIN_DAYS
		Kind.CAIDA: return FALL_DAYS
		_: return 0


## Si el percance obliga a dar media vuelta.
static func turns_back(kind: Kind) -> bool:
	return kind == Kind.TORMENTA or kind == Kind.CAIDA or kind == Kind.PERDIDA


## Si se pierde lo que se llevaba encima.
static func drops_load(kind: Kind) -> bool:
	return kind == Kind.CAIDA or kind == Kind.PERDIDA


## Cómo se cuenta, con el nombre de quien le ha pasado y dónde.
static func tell(kind: Kind, who: String, where: String) -> String:
	match kind:
		Kind.TORCEDURA:
			return "%s se torció un tobillo %s. Anda mal, y va a andar mal " \
				% [who, where] + "unos días."
		Kind.CAIDA:
			return "%s se fue al suelo en un canchal %s. Vuelve golpeado y " \
				% [who, where] + "sin lo que llevaba."
		Kind.PERDIDA:
			return "%s perdió el rumbo %s y anduvo dando vueltas. Vuelve con " \
				% [who, where] + "las manos vacías."
		Kind.TORMENTA:
			return "Rompió a llover %s y %s tuvo que dar media vuelta sin " \
				% [where, who] + "llegar adonde iba."
		_:
			return "%s se tropezó con algo %s: no era lo que buscaba, pero " \
				% [who, where] + "merecía la pena traerlo."
