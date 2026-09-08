class_name Exploration
extends RefCounted
## Adónde va una batida de reconocimiento.
##
## Es la respuesta a "no quiero controlar a los pobladores". El explorador no
## tiene un tajo fijo como el cazador o el pescador: su destino se CALCULA cada
## jornada, y es el punto que más mapa nuevo abre por lo que cuesta llegar.
##
## Con eso, asignar gente a exploración es una decisión de reparto de mano de
## obra —los tienes recogiendo o los tienes abriendo territorio— y la frontera
## avanza sola, sin que el jugador tenga que llevar a nadie de la mano.
##
## El criterio no es "lo más lejos posible": es la mejor relación entre lo que
## se descubre y lo que se anda. Un desconocido a dos kilómetros vale menos que
## uno igual de desconocido a quinientos metros, porque el segundo se recorre y
## se vuelve en la misma jornada.

## Anillos de distancia, en metros, sobre los que se buscan candidatos.
const RING_DISTANCES := [260.0, 480.0, 720.0, 1000.0, 1300.0]

## Direcciones que se prueban en cada anillo.
const SPOKES := 16

## Radio en el que se mide cuánto hay por descubrir alrededor de un candidato.
const SURVEY_RADIUS := 220.0

## Cuánto penaliza la distancia. Con 1,0 el valor se reparte proporcionalmente
## a lo que cuesta llegar; por debajo se premia ir lejos.
const DISTANCE_WEIGHT := 0.9

## Fraccion por descubrir por debajo de la cual no compensa gastar la jornada.
##
## No puede ser casi cero: una celda vista DE LEJOS se queda en 0,35 de
## claridad, asi que un valle entero recorrido sigue teniendo un 20-30% sin
## afinar. Con el umbral pegado a cero, las batidas nunca dejaban de salir a
## repasar terreno que ya se conocia de sobra.
const WORTH_THE_TRIP := 0.22

## Distancia a la que dos batidas dejan de estorbarse, en metros. Por debajo de
## esto sus radios de vista se solapan y la segunda aporta poco.
const SEPARATION := 520.0


## Elige el mejor destino de batida desde un punto.
##
## `reachable` es un Callable(Vector3) -> bool que dice si se puede llegar; se
## pasa de fuera para que esto no dependa del terreno y se pueda probar solo.
## Devuelve `from` si no hay ningún destino mejor que quedarse.
## `avoid` son destinos que ya tienen batida en marcha. Se penalizan en vez de
## descartarse: si de verdad no hay nada mejor, dos partidas pueden ir a la
## misma zona, pero por defecto se abren en abanico. Sin esto los tres
## exploradores salian en fila india a la misma frontera y el mapa se abria a
## un tercio de velocidad.
static func best_frontier(knowledge: BandKnowledge, from: Vector3,
		reachable: Callable, avoid: Array = []) -> Vector3:
	if knowledge == null:
		return from

	var best := from
	var best_score := 0.0

	for distance: float in RING_DISTANCES:
		for spoke in range(SPOKES):
			# Los anillos se giran entre sí para no muestrear siempre las
			# mismas direcciones y dejar cuñas sin mirar
			var angle := TAU * (float(spoke) / float(SPOKES)
				+ distance * 0.00037)
			var candidate := from + Vector3(cos(angle), 0.0, sin(angle)) * distance

			if reachable.is_valid() and not reachable.call(candidate):
				continue

			var unknown := unknown_around(knowledge, candidate, SURVEY_RADIUS)
			if unknown <= WORTH_THE_TRIP:
				continue

			# Lo que se descubre, repartido entre lo que cuesta llegar
			var cost := 1.0 + (distance / 1000.0) * DISTANCE_WEIGHT
			var score := unknown / cost

			# Y descontando lo que ya va a batir otro
			for taken: Vector3 in avoid:
				var gap := candidate.distance_to(taken)
				if gap < SEPARATION:
					score *= gap / SEPARATION
			if score > best_score:
				best_score = score
				best = candidate

	return best


## Fracción sin descubrir en el entorno de un punto, de 0 a 1.
static func unknown_around(knowledge: BandKnowledge, centre: Vector3,
		radius: float) -> float:
	if knowledge == null or knowledge.world_size.x <= 0.0:
		return 0.0

	var samples := 0
	var unknown := 0.0
	var steps := 3

	for dz in range(-steps, steps + 1):
		for dx in range(-steps, steps + 1):
			var offset := Vector3(
				float(dx) / float(steps) * radius, 0.0,
				float(dz) / float(steps) * radius)
			var point := centre + offset
			# Fuera del recuadro no es territorio por descubrir, es que no hay
			# territorio: contarlo mandaria las batidas contra el borde
			if point.x < 0.0 or point.z < 0.0 \
					or point.x > knowledge.world_size.x \
					or point.z > knowledge.world_size.y:
				continue
			samples += 1
			unknown += 1.0 - knowledge.explored_at(point)

	if samples == 0:
		return 0.0
	return unknown / float(samples)
