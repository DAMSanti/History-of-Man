class_name Tanteo
extends RefCounted
## Cuando un oficio no tiene dónde trabajar, sale a tantear el terreno.
##
## Es la queja literal del jugador: «si recolectores, cazadores y pescadores no
## tienen paraje donde trabajar, se comportarán como batidores y además
## recogerán los recursos que se vayan encontrando que correspondan a su
## profesión. Los pescadores deberían recorrer el margen del río; los cazadores
## y los recolectores dar una vuelta por terreno transitable».
##
## Y hasta ahora hacían lo contrario: [Barbecho.donde_buscar] barría el valle
## entero y mandaba a cada cual al mejor punto que encontrara, que casi siempre
## estaba a seiscientos metros. Medido con `ArranqueProbe`, a mediodía de las
## seis primeras jornadas casi nadie estaba trabajando: estaban «de camino» o
## «volviendo», y la despensa caía veinte al día.
##
## ## La diferencia entre buscar y tantear
##
## `Barbecho.donde_buscar` sigue existiendo y sirve para otra cosa: elegir EL
## MEJOR SITIO CONOCIDO cuando el de siempre se ha esquilmado. Eso es una
## mudanza, y se hace sabiendo adónde se va.
##
## Esto es lo otro: **no se sabe adónde ir**. Entonces no se elige un punto
## lejano, se da una vuelta cerca y se mira. Se trae menos —lo que caiga— pero
## se trae ALGO, y sobre todo se aprende el terreno, que es lo que hace que
## mañana sí haya adónde ir.
##
## ## Y por eso los sectores
##
## La vuelta no es al azar: cada jornada se sale por un sector distinto, y en
## unas cuantas se ha peinado el círculo entero. Al azar, tres batidores se
## pisan la misma ladera tres días seguidos y el resto del entorno sigue en
## blanco.

## Hasta dónde se tantea, en metros.
##
## Trescientos: lo que se anda de sobra en una mañana, con la tarde entera para
## trabajar lo que se encuentre. Es la mitad del tope de jornada a propósito —
## quien tantea no sabe si al llegar habrá algo, así que no se juega el día.
const VUELTA := 300.0

## Y desde dónde. No se tantea la puerta de casa: eso ya se conoce.
const DESDE := 90.0

## En cuántos sectores se parte el círculo.
##
## Ocho: con menos, dos batidores del mismo oficio salen por el mismo sitio
## demasiado a menudo; con más, la vuelta se hace tan estrecha que hay que dar
## muchas jornadas para cubrir el entorno.
const SECTORES := 8

## Cuánto se aparta un pescador del agua, en metros.
##
## Se pesca DESDE la orilla, así que su vuelta no es un círculo por el monte:
## es el margen del río. Ver [SettlementSim._shore_near], que es quien arrima
## un punto al agua.
const MARGEN := 40.0

var sim: SettlementSim

## Por qué sector va cada oficio. Uno por actividad, no por persona: lo que se
## reparte es el ENTORNO, y dos batidores del mismo oficio el mismo día tienen
## que ir a sitios distintos.
var _sector: Dictionary = {}


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Adónde sale a tantear quien no tiene dónde trabajar.
##
## Devuelve `Vector3.ZERO` si no hay ni eso, y entonces quien pregunta que haga
## lo de siempre: quedarse. No debería pasar —siempre hay monte alrededor— pero
## un tanteo que devuelve un punto imposible es peor que no tantear.
func adonde(person: Inhabitant) -> Vector3:
	if sim._terrain == null:
		return Vector3.ZERO
	var act := person.activity as Subsistence.Activity
	if act == Subsistence.Activity.PESCA or act == Subsistence.Activity.MARISQUEO:
		return _margen_del_rio(act)
	return _vuelta_por_el_monte(act)


## El siguiente sector de este oficio, y se pasa al siguiente.
func _siguiente_sector(act: Subsistence.Activity) -> float:
	var n := int(_sector.get(int(act), 0))
	_sector[int(act)] = (n + 1) % SECTORES
	return TAU * float(n) / float(SECTORES)


## Una vuelta por terreno transitable, para cazadores y recolectores.
##
## Se prueban varias distancias dentro del sector y se coge la más lejana que
## se pise: así la vuelta es tan ancha como el terreno deje, y no se corta en
## el primer cantil.
func _vuelta_por_el_monte(act: Subsistence.Activity) -> Vector3:
	var angulo := _siguiente_sector(act) \
		+ sim._rng.randf_range(-0.3, 0.3)
	var mejor := Vector3.ZERO
	for paso in range(6):
		var lejos := lerpf(DESDE, VUELTA, float(paso) / 5.0)
		var punto := sim.home_position + Vector3(
			cos(angulo) * lejos, 0.0, sin(angulo) * lejos)
		punto.y = sim._terrain.get_height_at(punto)
		# Que se pueda LLEGAR de verdad: un tanteo al otro lado del rio es una
		# jornada mirando el agua desde la orilla equivocada.
		if not _se_llega(punto):
			continue
		mejor = punto
	return mejor


## El margen del río, para pescadores y mariscadores.
##
## No es un círculo por el monte: es la orilla, que es donde se pesca. Se busca
## agua en el sector que toca y se arrima el punto a tierra firme con agua al
## lado —[SettlementSim._shore_near]—, que es exactamente el problema que ya
## resolvía para los tajos de ribera.
func _margen_del_rio(act: Subsistence.Activity) -> Vector3:
	var angulo := _siguiente_sector(act)
	var mejor := Vector3.ZERO
	for vuelta in range(SECTORES):
		var a := angulo + TAU * float(vuelta) / float(SECTORES)
		for paso in range(6):
			var lejos := lerpf(DESDE, VUELTA, float(paso) / 5.0)
			var punto := sim.home_position + Vector3(
				cos(a) * lejos, 0.0, sin(a) * lejos)
			punto.y = sim._terrain.get_height_at(punto)
			# Sólo vale si de verdad hay agua cerca: tantear la ribera lejos
			# del agua es dar una vuelta por el prado.
			#
			# Con el umbral de todos y no con uno propio. Aquí había un 0,02 a
			# mano, que era el cuarto número distinto para «aquí hay agua». Da
			# igual afinarlo: esto es sólo un descarte barato y quien decide de
			# verdad es `_shore_near`, unas líneas más abajo.
			if sim._terrain.crossing_difficulty_at(punto) <= Hydrography.ROZA_EL_AGUA:
				continue
			var orilla := sim.tajo._shore_near(punto)
			if orilla == Vector3.ZERO:
				continue
			if not _se_llega(orilla):
				continue
			mejor = orilla
		if mejor != Vector3.ZERO:
			break
	return mejor


## Si desde el abrigo se llega andando. La rejilla ya lleva las zonas
## comunicadas marcadas, asi que esto son dos enteros.
func _se_llega(punto: Vector3) -> bool:
	var grid := sim.marcha._navgrid()
	if grid == null:
		return true
	return grid.connected(sim.home_position, punto)
