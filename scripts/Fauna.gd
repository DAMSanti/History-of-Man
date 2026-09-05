class_name Fauna
extends RefCounted
## Qué especies se cazan, cuándo, y QUÉ SALE de cada una.
##
## La caza era un único material -CARNE- para todo: trampa, caza menor y
## caza mayor, sin distinguir un corzo de un jabalí. Un urogallo daba piel y
## un ciervo no daba asta, porque el despiece no miraba la especie: miraba
## la especialidad. Eso es exactamente lo que hay que arreglar, porque el
## despiece ES la caza: de un ave salen plumas y huesos huecos, de un ciervo
## salen asta, tendón y una piel que viste a alguien todo el invierno, y esa
## diferencia es la que hace que el jugador prefiera un cotarro u otro.
##
## Cada especie trae:
##
## - `porte`: si es pieza menor, mayor o de trampa. Decide quién la caza.
## - `raciones`: lo que da de carne una pieza entera, en raciones-persona.
## - `despiece`: unidades de cada material por pieza. Sin piel en las aves,
##   sin asta en la hembra ni en el jabalí, tendón solo en lo grande.
## - `riesgo`: lo que puede costar. Un uro no es un conejo.

## Porte de la pieza. No es tamaño por tamaño: es CÓMO se caza.
enum Porte {
	MENUDA,   ## Lazo y cepo: liebre, conejo, ave. Se coge sola mientras duermes
	MENOR,    ## Al acecho, con azagaya o arco: corzo, rebeco, ave grande
	MAYOR,    ## Batida y varias manos: ciervo, jabalí, uro, caballo
}

## Todo lo que se puede cazar en la cornisa cantábrica del Paleolítico
## superior, con lo que de verdad sale de cada pieza.
##
## Las cifras de `raciones` son de pieza entera y aprovechada: un ciervo son
## unos 30 kg de carne útil, que a media ración por kilo largo salen las 62
## de abajo. No son un número redondo puesto a ojo, son el motivo de que una
## sola pieza mayor cambie la semana de la banda.
const SPECIES := {
	# --- pieza menuda: la que cae en la trampa ---------------------------
	"liebre": {
		"name": "Liebre", "porte": Porte.MENUDA, "raciones": 2.6, "riesgo": 0.0,
		"despiece": {Materia.Kind.PIEL: 0.5, Materia.Kind.HUESO: 0.3,
			Materia.Kind.TENDON: 0.1},
	},
	"conejo": {
		"name": "Conejo", "porte": Porte.MENUDA, "raciones": 1.4, "riesgo": 0.0,
		"despiece": {Materia.Kind.PIEL: 0.35, Materia.Kind.HUESO: 0.2},
	},
	"urogallo": {
		# Un ave no da piel: da PLUMA. Es la peticion literal, y ademas es lo
		# que se hace: se desplumaba y las plumas valian para el emplumado y
		# el adorno. El hueso de ave es hueco y ligero -de ahi las flautas
		# paleoliticas-, asi que da poco pero da.
		"name": "Urogallo", "porte": Porte.MENOR, "raciones": 3.2, "riesgo": 0.0,
		"despiece": {Materia.Kind.PLUMA: 2.4, Materia.Kind.HUESO: 0.25,
			Materia.Kind.GRASA: 0.2},
	},
	"perdiz": {
		"name": "Perdiz", "porte": Porte.MENUDA, "raciones": 1.1, "riesgo": 0.0,
		"despiece": {Materia.Kind.PLUMA: 1.1, Materia.Kind.HUESO: 0.1},
	},
	"anade": {
		"name": "Ánade", "porte": Porte.MENUDA, "raciones": 1.8, "riesgo": 0.0,
		"despiece": {Materia.Kind.PLUMA: 1.8, Materia.Kind.HUESO: 0.15,
			Materia.Kind.GRASA: 0.35},
	},

	# --- pieza menor: al acecho ------------------------------------------
	"corzo": {
		"name": "Corzo", "porte": Porte.MENOR, "raciones": 14.0, "riesgo": 0.04,
		"despiece": {Materia.Kind.PIEL: 1.0, Materia.Kind.HUESO: 1.1,
			Materia.Kind.TENDON: 0.6, Materia.Kind.GRASA: 0.5,
			Materia.Kind.ASTA: 0.25},
	},
	"rebeco": {
		"name": "Rebeco", "porte": Porte.MENOR, "raciones": 11.0, "riesgo": 0.09,
		"despiece": {Materia.Kind.PIEL: 0.9, Materia.Kind.HUESO: 0.9,
			Materia.Kind.TENDON: 0.5, Materia.Kind.GRASA: 0.6},
	},

	# --- pieza mayor: la que cambia la semana ----------------------------
	"ciervo": {
		# El asta NO se le arranca al ciervo vivo: la que se talla es sobre
		# todo la de desmogue, que se recoge del suelo. De la pieza sale
		# alguna, pero poca, y por eso el desmogadero sigue importando.
		"name": "Ciervo", "porte": Porte.MAYOR, "raciones": 62.0, "riesgo": 0.06,
		"despiece": {Materia.Kind.PIEL: 1.8, Materia.Kind.HUESO: 5.4,
			Materia.Kind.TENDON: 2.8, Materia.Kind.GRASA: 4.2,
			Materia.Kind.ASTA: 0.9},
	},
	"jabali": {
		# Sin asta, con mucha grasa y con el riesgo mas alto de todo lo que
		# se caza aqui: un jabali acosado carga, y eso esta en los partes de
		# percance de cualquier epoca.
		"name": "Jabalí", "porte": Porte.MAYOR, "raciones": 48.0, "riesgo": 0.16,
		"despiece": {Materia.Kind.PIEL: 1.4, Materia.Kind.HUESO: 3.8,
			Materia.Kind.TENDON: 1.6, Materia.Kind.GRASA: 6.0},
	},
	"caballo": {
		"name": "Caballo", "porte": Porte.MAYOR, "raciones": 86.0, "riesgo": 0.08,
		"despiece": {Materia.Kind.PIEL: 2.4, Materia.Kind.HUESO: 6.2,
			Materia.Kind.TENDON: 3.4, Materia.Kind.GRASA: 5.0},
	},
	"uro": {
		"name": "Uro", "porte": Porte.MAYOR, "raciones": 140.0, "riesgo": 0.22,
		"despiece": {Materia.Kind.PIEL: 3.6, Materia.Kind.HUESO: 9.0,
			Materia.Kind.TENDON: 5.0, Materia.Kind.GRASA: 8.0},
	},
	"lobo": {
		# No se caza para comer: se caza por la piel y porque compite. La
		# carne de lobo es mala y se aprovecha poco.
		"name": "Lobo", "porte": Porte.MENOR, "raciones": 4.0, "riesgo": 0.18,
		"despiece": {Materia.Kind.PIEL: 1.2, Materia.Kind.HUESO: 0.8,
			Materia.Kind.TENDON: 0.4},
	},
}

## Qué se puede topar cada estación, de lo típico del monte cantábrico.
## El invierno es corto de piezas a propósito: es la estación mala, cuando
## menos se mueve el bosque y menos hay que encontrar.
## Cada estación tiene que traer PIEZA MAYOR, aunque sea poca.
##
## Antes el verano solo tenía uro de pieza grande, de siete especies, y la
## primavera dos. Con eso, una cuadrilla de caza mayor pasaba tres estaciones
## de cada cuatro topándose conejos: medido, 0,3 raciones de jornada perfecta
## contra las 14,2 de un recolector. La estacionalidad de la caza mayor está
## en el RENDIMIENTO -otoño 1,70 y primavera 0,65, ver
## `ResourceField.seasonal_factor`-, no en que el animal desaparezca del
## monte. Un ciervo en marzo está flaco, no ausente.
const BY_SEASON := {
	Subsistence.Season.PRIMAVERA: ["ciervo", "jabali", "caballo",
		"corzo", "liebre", "urogallo", "conejo", "anade"],
	Subsistence.Season.VERANO: ["uro", "caballo", "jabali",
		"corzo", "rebeco", "liebre", "urogallo", "conejo", "perdiz"],
	Subsistence.Season.OTONO: ["ciervo", "jabali", "caballo", "uro",
		"corzo", "urogallo", "perdiz"],
	Subsistence.Season.INVIERNO: ["jabali", "ciervo",
		"rebeco", "lobo", "liebre", "anade"],
}

## Cuántas especies distintas se pueden ver de golpe en un mismo paraje.
const MAX_SPECIES := 3


static func species_name(species: String) -> String:
	var entry: Dictionary = SPECIES.get(species, {})
	return String(entry.get("name", species))


static func porte_of(species: String) -> int:
	var entry: Dictionary = SPECIES.get(species, {})
	return int(entry.get("porte", Porte.MENOR))


## Raciones-persona que da una pieza entera.
static func rations_of(species: String) -> float:
	var entry: Dictionary = SPECIES.get(species, {})
	return float(entry.get("raciones", 0.0))


## Lo que sale de una pieza aparte de la carne, material por material.
static func spoils_of(species: String) -> Dictionary:
	var entry: Dictionary = SPECIES.get(species, {})
	return entry.get("despiece", {})


## Probabilidad de que la pieza le cueste algo a quien la caza.
static func risk_of(species: String) -> float:
	var entry: Dictionary = SPECIES.get(species, {})
	return float(entry.get("riesgo", 0.0))


## Todas las especies de un porte, del catálogo entero.
static func of_porte(porte: Porte) -> Array[String]:
	var out: Array[String] = []
	for species: String in SPECIES:
		if porte_of(species) == int(porte):
			out.append(species)
	return out


## Lo que se puede cazar de este porte en esta estación y en este sitio.
##
## Cruza las dos cosas: lo que anda por ahí ahora -[species_at]- y lo que
## caza esta especialidad. Un trampero no trae un uro por mucho que haya uros
## en el prado, y un batidor no monta una cuadrilla por una perdiz.
static func huntable_at(position: Vector3, season: Subsistence.Season,
		porte: Porte) -> Array[String]:
	var out: Array[String] = []
	for species: String in species_at(position, season):
		if porte_of(species) == int(porte):
			out.append(species)
	return out


## Qué especies hay en un paraje de caza, esta estación.
##
## Determinista por POSICIÓN, no por sorteo: el mismo sitio da siempre los
## mismos animales en la misma estación, igual que su nombre no cambia entre
## partidas. Sin esto, mirar el mismo paraje dos veces dentro del mismo día
## podría contar cosas distintas, que es peor que no contar nada.
static func species_at(position: Vector3, season: Subsistence.Season) -> Array[String]:
	var pool: Array = BY_SEASON.get(season, [])
	if pool.is_empty():
		return []

	var seed_value := absi(int(position.x) * 73856093 ^ int(position.z) * 19349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var remaining := pool.duplicate()
	var count := rng.randi_range(1, mini(MAX_SPECIES, remaining.size()))
	var picked: Array[String] = []
	for _i in range(count):
		var index := rng.randi_range(0, remaining.size() - 1)
		picked.append(remaining[index])
		remaining.remove_at(index)
	return picked


## Las especies dichas como se dirían: «corzo y jabalí», no una lista con
## comas sueltas. Con una sola especie, esa sola.
static func species_text(position: Vector3, season: Subsistence.Season) -> String:
	var species := species_at(position, season)
	if species.is_empty():
		return ""
	var names: Array[String] = []
	for one: String in species:
		names.append(species_name(one).to_lower())
	if names.size() == 1:
		return names[0]
	return "%s y %s" % [", ".join(names.slice(0, names.size() - 1)), names[-1]]
