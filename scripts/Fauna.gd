class_name Fauna
extends RefCounted
## Qué especies se cazan, y cuándo.
##
## La caza era un único material -CARNE- para todo: trampa, caza menor y
## caza mayor, sin distinguir un corzo de un jabalí. Eso sigue así por
## debajo -el guiso no sabe de especies, sabe de raciones-, pero un paraje
## de caza que solo dice «carne fresca» no se lee como un sitio, se lee
## como un número. Esto es la capa de encima: qué animal es el que de
## verdad se vería ahí, esta estación.

## Qué se puede topar cada estación, de lo típico del monte cantábrico.
## El invierno es corto de piezas a propósito: es la estación mala, cuando
## menos se mueve el bosque y menos hay que encontrar.
const BY_SEASON := {
	Subsistence.Season.PRIMAVERA: ["corzo", "jabalí", "liebre", "urogallo"],
	Subsistence.Season.VERANO: ["corzo", "rebeco", "liebre", "urogallo"],
	Subsistence.Season.OTONO: ["ciervo", "corzo", "jabalí", "urogallo"],
	Subsistence.Season.INVIERNO: ["jabalí", "rebeco", "lobo"],
}

## Cuántas especies distintas se pueden ver de golpe en un mismo paraje.
const MAX_SPECIES := 3


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
	if species.size() == 1:
		return species[0]
	return "%s y %s" % [", ".join(species.slice(0, species.size() - 1)), species[-1]]
