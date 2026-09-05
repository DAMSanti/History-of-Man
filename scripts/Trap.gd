class_name Trap
extends RefCounted
## Una trampa puesta en el monte: dónde está, de qué tipo y cómo va.
##
## La trampa es el único trabajo de la banda que rinde MIENTRAS SE HACE OTRA
## COSA. Se arma una vez, cuesta materiales y una jornada de brazo, y a
## partir de ahí pesca sola: el trampero solo tiene que ir a levantarla. Eso
## la hace distinta de todo lo demás —no es una jornada por pieza, es una
## inversión— y por eso tiene objeto propio y no un número en una tabla.
##
## Y se ve en el terreno. Una trampa que no se ve es una estadística; una
## trampa con su chapa en la ladera es un sitio al que uno va, que es lo que
## el jugador pidió: «las trampas se deben construir y mostrar en el terreno
## cuando estén puestas».

## Qué clase de trampa es. Cada una coge lo suyo: no hay una trampa buena,
## hay la trampa que va con la pieza.
enum Kind {
	LAZO,      ## Corredera de fibra en el paso: liebre, conejo
	CEPO,      ## Losa de piedra que cae al tocar el cebo: pieza menuda
	RED_AVES,  ## Malla tendida en el bebedero: perdiz, ánade
	FOSO,      ## Hoyo tapado en la vereda: jabalí, ciervo. Obra de días
}

## Todo lo que define un tipo de trampa.
##
## `caza` son las especies que caen en ella, y no está puesto a ojo: un lazo
## de fibra no sujeta a un jabalí y una losa no cae sobre un ciervo. `cada`
## son las jornadas que tarda de media en dar UNA pieza, con la trampa nueva
## y bien puesta. `aguanta` son las jornadas que dura antes de quedar
## inservible: la fibra se pudre, el hoyo se ciega.
const INFO := {
	Kind.LAZO: {
		"name": "Lazo",
		"desc": "Corredera de fibra atada a una vara doblada, puesta en el "
			+ "paso que el animal ya usa. Es la trampa más barata y la primera "
			+ "que se aprende: no hace falta más que cordel y saber leer una "
			+ "vereda.",
		"materials": {Materia.Kind.FIBRA: 1.5, Materia.Kind.LENA: 0.5},
		"labor_days": 0.35,
		"tech": TechTree.Tech.LAZO,
		"caza": ["liebre", "conejo"],
		"cada": 2.6, "aguanta": 26.0,
	},
	Kind.CEPO: {
		"name": "Cepo de losa",
		"desc": "Una losa calzada sobre un disparador cebado. Cae con el peso "
			+ "y mata en el sitio, así que no hay que llegar antes que el "
			+ "zorro. Pide piedra y un poco de maña.",
		"materials": {Materia.Kind.PIEDRA: 3.0, Materia.Kind.LENA: 1.0},
		"labor_days": 0.5,
		"tech": TechTree.Tech.CEPO,
		"caza": ["conejo", "liebre", "perdiz"],
		"cada": 3.4, "aguanta": 42.0,
	},
	Kind.RED_AVES: {
		"name": "Red de aves",
		"desc": "Malla fina tendida entre dos varas en el bebedero o en el "
			+ "paso de la nube. Da plumas a espuertas —el ave no da piel— y "
			+ "pide la misma cordelería que la red de pescar.",
		"materials": {Materia.Kind.FIBRA: 4.0, Materia.Kind.LENA: 1.0},
		"labor_days": 0.6,
		"tech": TechTree.Tech.RED_AVES,
		"caza": ["perdiz", "anade", "urogallo"],
		"cada": 2.2, "aguanta": 30.0,
	},
	Kind.FOSO: {
		"name": "Foso",
		"desc": "Hoyo en la vereda, tapado con ramaje y tierra, a veces con "
			+ "estacas al fondo. Es la única trampa que coge pieza mayor, y "
			+ "cuesta lo que parece: días de cavar y una jornada de acarreo.",
		"materials": {Materia.Kind.LENA: 6.0, Materia.Kind.FIBRA: 2.0},
		"labor_days": 3.0,
		"tech": TechTree.Tech.FOSO,
		"caza": ["jabali", "ciervo", "corzo"],
		"cada": 9.0, "aguanta": 70.0,
	},
}


static func trap_name(kind: Kind) -> String:
	return String(INFO[kind]["name"])


static func trap_desc(kind: Kind) -> String:
	return String(INFO[kind]["desc"])


static func materials(kind: Kind) -> Dictionary:
	return INFO[kind]["materials"]


static func labor_days(kind: Kind) -> float:
	return float(INFO[kind]["labor_days"])


## La técnica que hay que dominar para armarla, o -1.
static func tech_of(kind: Kind) -> int:
	return int(INFO[kind]["tech"])


## Qué cae en ella.
static func catches(kind: Kind) -> Array:
	return INFO[kind]["caza"] as Array


## Jornadas que tarda de media en dar una pieza, con la trampa nueva.
static func days_per_catch(kind: Kind) -> float:
	return float(INFO[kind]["cada"])


## Jornadas que aguanta antes de quedar inservible.
static func lifespan(kind: Kind) -> float:
	return float(INFO[kind]["aguanta"])


## Raciones que da de media una pieza de las que caen en esta trampa. Sirve
## para ordenar y para contárselo al jugador sin tener que abrir el catálogo.
static func typical_rations(kind: Kind) -> float:
	var total := 0.0
	var species := catches(kind)
	if species.is_empty():
		return 0.0
	for one: String in species:
		total += Fauna.rations_of(one)
	return total / float(species.size())


# --- una trampa concreta, puesta en un sitio -----------------------------

var kind: Kind = Kind.LAZO

## Dónde está puesta, en el mundo.
var position: Vector3 = Vector3.ZERO

## Jornada en que quedó armada.
var set_day: int = 1

## Jornadas que lleva puesta sin que nadie la levante. Es lo que se convierte
## en pieza: una trampa se cobra por el TIEMPO que lleva calada, no por la
## visita.
var soaking: float = 0.0

## Lo que lleva gastado de su vida útil, en jornadas.
var worn: float = 0.0

## Cuántas piezas ha dado desde que se puso. Es la única forma que tiene el
## jugador de saber si ese sitio era bueno.
var taken: int = 0

## Quién la armó, para poder decirlo en la crónica.
var maker: String = ""


## De 1 (recién puesta) a 0 (inservible).
func condition() -> float:
	return clampf(1.0 - worn / maxf(lifespan(kind), 0.001), 0.0, 1.0)


func is_spent() -> bool:
	return worn >= lifespan(kind)


## Cuántas piezas ha cobrado con lo que lleva calada, y descuenta el tiempo
## que se lleva por delante.
##
## La trampa vieja coge menos: la fibra se afloja, el ramaje del foso se
## hunde, y el animal ve el sitio revuelto. Por eso la condición entra en la
## cuenta y no solo decide cuándo se tira.
func collect() -> int:
	var per_catch := days_per_catch(kind) / maxf(condition(), 0.15)
	var pieces := int(soaking / maxf(per_catch, 0.01))
	if pieces > 0:
		soaking -= float(pieces) * per_catch
		taken += pieces
	return pieces


## Qué ha caído hoy, por especie. Se sortea de lo que ESTA trampa coge y
## además anda por ese sitio en esta estación: un lazo en un pinar sin
## liebres no da liebres por mucho lazo que sea.
func quarry_here(season: Subsistence.Season, rng: RandomNumberGenerator) -> String:
	var here := Fauna.species_at(position, season)
	var options: Array[String] = []
	for species: String in catches(kind):
		if here.has(species):
			options.append(species)
	# Si en este punto no anda ninguna de las suyas, cae lo más humilde de lo
	# que coge la trampa: algo se enreda siempre, pero poco.
	if options.is_empty():
		var poorest := ""
		var least := INF
		for species: String in catches(kind):
			if Fauna.rations_of(species) < least:
				least = Fauna.rations_of(species)
				poorest = species
		return poorest
	return options[rng.randi_range(0, options.size() - 1)]


static func create(kind_value: Kind, world: Vector3, day: int,
		who: String = "") -> Trap:
	var trap := Trap.new()
	trap.kind = kind_value
	trap.position = world
	trap.set_day = day
	trap.maker = who
	return trap
