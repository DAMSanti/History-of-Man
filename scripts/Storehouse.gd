class_name Storehouse
extends RefCounted
## Lo que la banda tiene guardado, con su peso y su volumen.
##
## La gracia no es que sume: es que el sitio se acaba. Un abrigo tiene los
## metros cúbicos que tiene, y la leña —que es lo que más abulta con
## diferencia— lo llena antes que ninguna otra cosa. Eso convierte «¿qué
## recojo?» en una decisión en vez de en una acumulación.
##
## Ver [Materia] para las cifras de cada cosa.

## Volumen utilizable, en litros. Cero significa sin límite, que es lo que pasa
## al aire libre y lo que se usa para probar.
var capacity_litres: float = 0.0

## Cantidades por material, en unidades del propio material.
var contents: Dictionary = {}

## Edad de lo guardado, en días, por material. Solo importa para lo perecedero.
var ages: Dictionary = {}

## Lo que no cupo en la última entrada. Se anota para poder avisar en vez de
## desaparecer sin decir nada.
var overflow: float = 0.0

## Lo que carga una persona en una jornada larga, en kilos. Es la cifra
## habitual en etnografía de porteo: por encima de eso el ritmo se hunde.
const BASE_CARRY_KG := 25.0


func amount(kind: Materia.Kind) -> float:
	return float(contents.get(kind, 0.0))


## Guarda material. Devuelve cuánto entró de verdad, que puede ser menos de lo
## que se pidió si no cabe.
func add(kind: Materia.Kind, units: float) -> float:
	overflow = 0.0
	if units <= 0.0:
		return 0.0

	var accepted := units
	if capacity_litres > 0.0:
		var per_unit := Materia.litres_per_unit(kind)
		if per_unit > 0.0:
			var room := maxf(free_litres(), 0.0)
			accepted = minf(units, room / per_unit)
			overflow = units - accepted

	if accepted <= 0.0:
		return 0.0

	# La edad se promedia con lo que ya había: meter carne fresca en el montón
	# no rejuvenece la vieja, pero tampoco la envejece de golpe
	var had := amount(kind)
	if had > 0.0:
		var old_age := float(ages.get(kind, 0.0))
		ages[kind] = old_age * had / (had + accepted)
	else:
		ages[kind] = 0.0

	contents[kind] = had + accepted
	return accepted


## Saca material. Devuelve cuánto se pudo sacar.
func take(kind: Materia.Kind, units: float) -> float:
	var had := amount(kind)
	var taken := minf(units, had)
	if taken <= 0.0:
		return 0.0
	contents[kind] = had - taken
	if contents[kind] <= 0.0001:
		contents.erase(kind)
		ages.erase(kind)
	return taken


func total_kg() -> float:
	var sum := 0.0
	for kind: int in contents.keys():
		sum += amount(kind as Materia.Kind) * Materia.kg_per_unit(kind as Materia.Kind)
	return sum


func total_litres() -> float:
	var sum := 0.0
	for kind: int in contents.keys():
		sum += amount(kind as Materia.Kind) * Materia.litres_per_unit(kind as Materia.Kind)
	return sum


func free_litres() -> float:
	if capacity_litres <= 0.0:
		return INF
	return capacity_litres - total_litres()


func fullness() -> float:
	if capacity_litres <= 0.0:
		return 0.0
	return clampf(total_litres() / capacity_litres, 0.0, 1.0)


## Raciones-persona de comida disponibles.
func food_rations() -> float:
	var sum := 0.0
	for kind: int in contents.keys():
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			sum += amount(k) * Materia.nutrition(k)
	return sum


## Cuántos días da de comer a un número de bocas.
func days_of_food(mouths_per_day: float) -> float:
	if mouths_per_day <= 0.0:
		return INF
	return food_rations() / mouths_per_day


## Pasa el tiempo. Lo perecedero se echa a perder de forma progresiva.
##
## No se pierde de golpe al cumplir la fecha: empieza a estropearse a partir de
## la mitad de su vida, que es como funciona de verdad y además da margen al
## jugador para reaccionar antes de perderlo todo.
func age(days: int) -> void:
	for kind: int in contents.keys().duplicate():
		var k := kind as Materia.Kind
		var life := Materia.shelf_life(k)
		if life <= 0:
			continue

		var new_age := float(ages.get(k, 0.0)) + float(days)
		ages[k] = new_age

		var half := float(life) * 0.5
		if new_age <= half:
			continue

		# De la mitad de vida al final se pierde progresivamente
		var spoiled_fraction := clampf(
			(new_age - half) / maxf(float(life) - half, 1.0), 0.0, 1.0)
		var keep := 1.0 - spoiled_fraction
		var had := amount(k)
		var left := had * keep
		if left <= 0.0001:
			contents.erase(k)
			ages.erase(k)
		else:
			contents[k] = left


## Materiales guardados, ordenados por volumen ocupado: lo que más estorba
## primero.
##
## Ya NO es lo que se enseña en el almacén. Ordenar por volumen quiere decir
## que las filas se reordenan solas cada vez que la banda trae algo: buscabas
## la leña donde estaba hace un momento y ahí había otra cosa. Sirve para
## responder «qué me está llenando el abrigo», y para eso se sigue usando.
func by_volume() -> Array[Dictionary]:
	var rows := in_catalogue_order()
	rows.sort_custom(func(a, b): return float(a["litres"]) > float(b["litres"]))
	return rows


## Todos los materiales, SIEMPRE en el mismo orden y siempre todos.
##
## El orden es el del catálogo —primero el alimento, luego la materia prima—,
## que no depende de lo que haya guardado. Así cada material tiene su sitio
## fijo en la tabla: la leña está donde estaba ayer, aunque hoy no quede
## ninguna, y se le puede poner objetivo a algo que todavía no se tiene.
func in_catalogue_order() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		var units := amount(k)
		rows.append({
			"kind": k,
			"units": units,
			"kg": units * Materia.kg_per_unit(k),
			"litres": units * Materia.litres_per_unit(k),
		})
	return rows


## Cuántas unidades de un material caben en una carga de tantos kilos.
static func units_carryable(kind: Materia.Kind, kg: float) -> float:
	var per_unit := Materia.kg_per_unit(kind)
	if per_unit <= 0.0:
		return 0.0
	return kg / per_unit


## Lo que carga una persona según lo que lleve para cargarlo.
##
## Es la razón mecánica de que los recipientes importen: sin nada se va a
## brazadas, y eso limita la jornada de recolección más que el tiempo.
static func carry_capacity_kg(has_basket: bool, has_skin: bool) -> float:
	var kg := BASE_CARRY_KG * 0.45
	if has_basket:
		kg = BASE_CARRY_KG * 0.85
	if has_skin:
		kg += BASE_CARRY_KG * 0.25
	return kg
