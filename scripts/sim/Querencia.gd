class_name Querencia
extends RefCounted
## Lo que la banda YA SABE del sitio al que ha llegado.
##
## La partida arrancaba con el valle en blanco: cero parajes, cero familiaridad,
## y quince personas que salían a probar suerte. Medido con `ArranqueProbe`:
##
##   dia 1 · en la despensa  -9.4 · 0 parajes
##   dia 2 · en la despensa -13.0 · 0 parajes
##   dia 3 · en la despensa -21.4 · 1 paraje
##   dia 6 · en la despensa -18.5 · 1 paraje
##
## A mediodía de cualquiera de esas jornadas, casi nadie estaba trabajando:
## estaban «de camino» o «volviendo», con el tajo a seiscientos metros. Un mes
## para empezar a trabajar, y la despensa cayendo veinte al día mientras tanto.
##
## ## Por qué es un error de simulación y no una dificultad
##
## Una banda no llega a un valle desconocido y planta el campamento a ciegas.
## **Elige el abrigo POR LO QUE TIENE ALREDEDOR**: por el agua, por el paso de
## la caza, por el avellanar de la ladera. Que la primera decisión del jugador
## sea dónde fundar y que luego la banda no sepa nada de lo que hay a doscientos
## metros es contradecir la propia premisa del juego.
##
## Lo que se hace aquí es lo que la banda sabría: **una vuelta al abrigo**. No
## el valle entero —eso hay que ganárselo explorando— sino el radio en el que
## cualquiera que haya acampado una semana ya sabe dónde está el agua y dónde
## está el avellanar.
##
## ## Lo que NO se regala
##
##   - El mapa. Fuera de [RADIO] todo sigue en blanco.
##   - Las cifras. Los parajes nacen con lo suyo por descubrir, igual que los
##     que se encuentran andando: se sabe QUE está, no CUÁNTO.
##   - Los buenos sitios. Lo que se siembra es lo que hay CERCA, que casi nunca
##     es lo mejor del valle; el avellanar grande sigue estando a dos horas y
##     hay que salir a buscarlo.

## Hasta dónde llega lo que la banda ya conoce, en metros.
##
## Doscientos ochenta: una vuelta de tarde. Es la distancia a la que se va a por
## agua y a por leña sin pensarlo, y la que cualquiera reconoce el primer día de
## acampada. Más lejos ya es explorar.
const RADIO := 280.0

## Con cuánta familiaridad se siembra, de 0 a 1.
##
## Tiene que pasar DOS umbrales, y son distintos:
##
##   0,30  [Parajes.NAMED_AT], que es lo que hace falta para bautizar un sitio
##   0,35  lo que exige `Tajo._rank_known_spots` para OFRECERLO como tajo
##
## Con 0,42 en la puerta y caída hasta 0,30 en el filo, la mitad de fuera del
## radio pasaba el primero y no el segundo: salían los parajes y la banda no
## podía trabajar en ellos. Ahora el filo se queda en 0,46, holgadamente por
## encima de los dos. Sigue sin ser «conocido a fondo» —eso es 1,0 y se gana
## trabajando—: es lo que se sabe de una vuelta.
const SABIDO := 0.62

## Las actividades que se siembran, y hasta cuántos parajes de cada una.
##
## Uno de cada, y de las cuatro que dan de comer o de trabajar. Con uno basta
## para que la banda empiece a trabajar el primer día; el segundo y el tercero
## hay que encontrarlos.
const DE_CADA := 1

const OFICIOS := [
	Subsistence.Activity.RECOLECCION,
	Subsistence.Activity.CAZA,
	Subsistence.Activity.PESCA,
	Subsistence.Activity.MATERIA_PRIMA,
]

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Siembra lo que la banda ya sabe. Se llama UNA vez, al fundar.
##
## Devuelve cuántos parajes salieron, que no tienen por qué ser cuatro: si en
## esos doscientos ochenta metros no hay río, no hay paraje de pesca, y está
## bien que no lo haya. Lo que se siembra es el conocimiento del terreno, no el
## terreno.
func asentarse() -> int:
	if sim.field == null or sim.knowledge == null or sim.parajes == null:
		return 0

	# Primero el TERRENO: la vuelta al abrigo, actividad por actividad. Es lo
	# que hace que `Tajo._rank_known_spots` -que sólo ofrece celdas con
	# familiaridad por encima de 0,35- tenga algo que ofrecer el primer día.
	for actividad: int in OFICIOS:
		var act := actividad as Subsistence.Activity
		for celda: Vector2i in sim.field.cells_within(sim.home_position, RADIO):
			var centre := sim.field.cell_center(celda.x, celda.y)
			if sim.field.abundance_cell(act, celda.x, celda.y) <= 0.0:
				continue
			# Menos cuanto más lejos: lo de la puerta se conoce mejor que lo
			# del filo del radio, que es como se conoce un sitio de verdad.
			var lejos := sim.home_position.distance_to(centre) / RADIO
			sim.knowledge.reveal(act, centre,
				SABIDO * lerpf(1.0, 0.75, clampf(lejos, 0.0, 1.0)))

	# Y con el terreno conocido, los parajes salen SOLOS: `Parajes.refresh` es
	# quien bautiza, y lo hace con las mismas reglas que cuando los encuentra
	# un explorador. No se fabrica ninguno a mano.
	var antes := sim.parajes.list.size()
	# El mismo criterio de «dos sitios son el mismo» que usa el explorador: si
	# hay camino de uno a otro, es el mismo trozo de monte.
	var grid := sim.marcha._navgrid()
	var mismo_trozo := func(a: Vector3, b: Vector3) -> bool:
		return grid.connected(a, b)
	sim.parajes.refresh(sim.field, sim.knowledge, sim.day, OFICIOS,
		sim._terrain, mismo_trozo)
	var salieron := sim.parajes.list.size() - antes
	if salieron > 0:
		sim._note(Chronicle.Kind.HALLAZGO,
			"La banda se asienta. De la primera vuelta al abrigo salen %d "
				% salieron
			+ "sitios con nombre: lo que se ve desde la boca de la cueva.", 2)
	return salieron
