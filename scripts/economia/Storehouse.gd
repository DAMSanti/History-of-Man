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
## Litros que caben SIN recipiente: lo que se apila en el suelo y en hoyos.
##
## La lena, el asta y la piedra se amontonan; la comida no. Un monton de
## avellana en el suelo de una cueva se lo comen los roedores y se moja.
## Litros de comida que caben ahora mismo, contando los recipientes que hay.
##
## Lo pone `SettlementSim` cada dia desde el utillaje: los cestos se rompen y
## se trenzan otros, asi que la despensa crece y encoge con el taller.
var capacidad_comida: float = 0.0

const A_GRANEL := 900.0

## Litros que guarda cada cesto y cada odre.
##
## Un cesto de mimbre de los que se trenzan en una tarde son unos treinta
## litros; un odre de piel, doce. No son cifras de balanceo: son el tamano de
## la cosa.
const POR_CESTO := 30.0
const POR_ODRE := 12.0


## Cuanta comida cabe, que NO es lo mismo que cuanto cabe en la cueva.
##
## Esto sustituye a un tope inventado que hubo aqui -un numero que el jugador
## ponia en el panel- y que no era una mecanica: nada en el mundo impedia a la
## banda seguir amontonando. Medido entonces, la despensa iba de 6 dias de
## comida a 120 y no bajaba nunca.
##
## Lo que de verdad limita es EN QUE SE GUARDA. Doce metros cubicos de cueva
## dan para 10.200 raciones de avellana -cuatrocientos dias para quince bocas-,
## asi que el volumen del abrigo no muerde jamas; lo que muerde es que la banda
## arranca SIN CESTOS y trenzar cuesta jornadas de cordeleria.
##
## Con eso guardar comida deja de ser gratis y pasa a competir con lo demas del
## taller, que es la decision que se buscaba.
func capacidad_de_comida(cestos: int, odres: int) -> float:
	return A_GRANEL + float(cestos) * POR_CESTO + float(odres) * POR_ODRE


## Los litros de comida que hay ahora mismo.
func litros_de_comida() -> float:
	var total := 0.0
	for kind: int in contents:
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			total += float(contents[k]) * Materia.litres_per_unit(k)
	return total


func add(kind: Materia.Kind, units: float) -> float:
	overflow = 0.0
	if units <= 0.0:
		return 0.0

	var accepted := units
	var per_unit := Materia.litres_per_unit(kind)
	if per_unit > 0.0:
		# La comida tiene su propio limite -en que se guarda- ademas del de la
		# cueva. Ver [capacidad_de_comida]: lo que no cabe en cesto ni en odre
		# se queda en el suelo, y en el suelo se lo comen los roedores.
		var room := maxf(free_litres(), 0.0)
		if Materia.is_food(kind) and capacidad_comida > 0.0:
			room = minf(room, maxf(capacidad_comida - litros_de_comida(), 0.0))
		if capacity_litres > 0.0 or (Materia.is_food(kind) and capacidad_comida > 0.0):
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


## Lo que ha SALIDO hoy, material a material.
##
## Aquí y no en quien saca, porque `take` es la única puerta: por ella pasa lo
## que se come, lo que se gasta en el taller, el cebo del sedal y el material
## de una obra. Contarlo en cada sitio sería pedir que nadie se olvide nunca.
##
## Lo que NO cuenta es lo que se pudre: eso no lo ha gastado la banda, se ha
## perdido, y va aparte en `SettlementSim.spoiled_today`.
var spent_today: Dictionary = {}


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
	spent_today[int(kind)] = float(spent_today.get(int(kind), 0.0)) + taken
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


## Proteína aprovechable que hay en la despensa, en gramos.
func food_protein() -> float:
	var sum := 0.0
	for kind: int in contents.keys():
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			sum += amount(k) * Materia.protein(k)
	return sum


## Raciones COMPLETAS: comidas de verdad que la despensa puede servir.
##
## [food_rations] cuenta energía, que es lo que se come y lo que hay que
## contabilizar. Pero una despensa de puro fruto seco tiene energía para un mes
## y comidas completas para dos semanas: lo que falta es proteína, y no se
## sustituye con nada.
##
## Es la cifra que contesta «¿por qué me interesa la carne?», y la contesta
## donde la pregunta tiene respuesta: no por unidad —una tajada de carne magra
## tiene menos energía que un puñado de avellana, y eso es cierto— sino EN EL
## MONTÓN. Echar carne a una despensa de avellana sube las comidas completas de
## golpe; echar más avellana no las sube nada.
func raciones_completas() -> float:
	return minf(food_rations(),
		food_protein() / maxf(Materia.PROTEINA_RACION, 0.001))


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
## Lo que se ha echado a perder en la ultima jornada, material por material.
##
## Se guarda porque si no NO SE VE. Queja literal: «los pescadores pescan pero
## no esta subiendo el pescado al almacen». Estaba entrando y pudriendose a la
## vez —el pescado fresco aguanta tres dias— y desde fuera solo se veia un
## numero que no crecia. Un monton que no sube porque se pudre y un monton
## que no sube porque nadie lo trae se leen igual, y no son lo mismo.
var spoiled: Dictionary = {}


func age(days: int) -> void:
	spoiled.clear()
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
		if had - left > 0.0001:
			spoiled[k] = had - left
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
