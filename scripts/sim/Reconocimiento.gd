class_name Reconocimiento
extends RefCounted
## Abrir monte nuevo: adonde se va a mirar y que se trae de mirar.
##
## Sale de `SettlementSim` como [Caceria] o [Tajo]. Son las dos formas de salir
## a lo desconocido -la EXPEDICION, que duerme fuera y abre comarca, y la
## BATIDA, que va y vuelve el mismo dia y trabaja a fondo lo ya conocido- mas
## lo que sale de ellas: sim.parajes con nombre y pericia de explorador.
##
## No produce comida. Lo que produce es SABER, que es lo que luego deja a [Tajo]
## elegir un sitio mejor: un cotarro sin pisar no esta en el mapa de la banda
## por muy bueno que sea.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Destino de una batida de sim.reconocimiento.
func _scout_target(person: Inhabitant) -> Vector3:
	if sim.knowledge == null or sim._terrain == null:
		return sim.home_position

	var target: Vector3

	# Si el jugador ha señalado un rumbo, se va ahi. La logica de frontera
	# -que elige el punto que mas mapa abre- se queda de reserva para cuando
	# no hay orden: es buena, y ese era justo el problema. Elegia siempre
	# bien y no dejaba nada que decidir.
	if sim.has_scout_order:
		# Cada cual llega por su lado: sin esto salen en fila india al mismo
		# punto, que es lo que ya paso con los recolectores
		var spread := 90.0
		var angle := float(person.id) * 1.7
		target = sim.scout_order + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
	else:
		# Para explorar basta con que el camino sea MAYORMENTE transitable: un
		# batidor rodea el obstaculo, que es justo su trabajo. Exigiendo la recta
		# limpia entera -como para ir al sim.tajo- casi ningun destino la pasaba y los
		# exploradores se quedaban parados en el campamento.
		# Se llega o no se llega, y eso lo sabe la rejilla de navegacion sin
		# buscar nada. Antes se exigia que la RECTA de aqui alla fuera
		# transitable en un 85%, y en terreno de verdad casi ningun destino
		# lejano pasa esa prueba: cualquier rio de por medio la tumba.
		#
		# Eso es lo que hacia que la banda no saliera de expedicion sola. No
		# es que no quisiera: es que se descartaba ella misma todas las
		# fronteras y se quedaba con las cuatro de al lado de casa.
		var reachable := func(point: Vector3) -> bool:
			return sim.marcha._navgrid().connected(person.position, point)

		# Los destinos que ya tienen batida en marcha, para que las partidas se
		# abran en abanico en vez de salir en fila india a la misma frontera
		var taken: Array[Vector3] = []
		for other: Inhabitant in sim.people:
			if other == person or other.job != Profession.Job.EXPLORACION:
				continue
			if other.state == Inhabitant.State.YENDO:
				taken.append(other.target)

		target = Exploration.best_frontier(
			sim.knowledge, sim.home_position, reachable, taken)

		# `best_frontier` devuelve el punto de partida cuando NO ENCUENTRA nada
		# que merezca el viaje. Eso es lo que apagaba la exploracion en silencio:
		# hacia el dia treinta la banda ya conoce todo lo que tiene al alcance,
		# la frontera deja de existir, el destino sale igual al campamento, la
		# comprobacion de distancia no pasa y el explorador se queda quieto para
		# siempre sin que nadie diga nada.
		#
		# Que no quede frontera es un hito de la partida, no una averia: se
		# cuenta, y a partir de ahi se sigue saliendo a repasar lo que peor se
		# conoce. Un territorio no se conoce de una vez: cambia con la estacion,
		# y lo que se vio hace tres meses hay que volver a verlo.
		if target.distance_to(sim.home_position) < sim.arrive_radius * 2.0:
			if not sim._comarca_known:
				sim._comarca_known = true
				sim._note(Chronicle.Kind.TIERRA,
					"Ya no queda nada nuevo que reconocer a este lado. La banda "
						+ "conoce su comarca; para ver mas habria que cruzar el "
						+ "agua o levantar el campamento.", 2)
			# Y se repasa TODO EL MAPA, no un radio: lo que peor se conoce
			# puede estar en la otra punta, y llegar hasta alli es cosa de la
			# mochila y no de un numero escrito aqui.
			var ancho := 4096.0
			if sim._terrain != null:
				ancho = maxf(float(sim._terrain.terrain_size.x),
					float(sim._terrain.terrain_size.y))
			target = _least_known_around(sim.home_position,
				BATIDA_RADIUS, ancho, person)

	# AQUI NO HAY TOPE DE DISTANCIA, Y ES DELIBERADO.
	#
	# Habia uno: pasados 2.600 m se le cambiaba el destino por otro mas
	# cerca si la banda no tenia tres personas dedicadas a expedicion. Eso
	# es limitar por distancia y por plantilla, y no es lo que limita a una
	# expedicion de verdad.
	#
	# Lo que la limita es LO QUE SE PUEDE LLEVAR ENCIMA: los dias de viaje
	# salen de la distancia, la comida sale de los dias, y si no se puede
	# cargar esa comida no se sale. Eso lo decide [Despensa._provision],
	# que es quien tiene delante el almacen y la mochila. Aqui solo se
	# elige adonde merece la pena ir.

	target.y = sim._terrain.get_height_at(target)
	return target


## Destino de una BATIDA: el entorno inmediato del campamento, no la frontera.
##
## Radio corto y punto aleatorio dentro de el, sin fan-out entre batidores
## -a diferencia de `_scout_target`- porque el objetivo no es repartirse el
## territorio entero, es peinar los alrededores. Con `arrive_radius` de por
## medio, en pocas jornadas cubre el circulo entero por simple variacion.
const BATIDA_RADIUS := 380.0

## Cuanto se le consiente salirse del sitio antes de traerlo de vuelta.
##
## Un cuarto de margen sobre el radio del paraje: batir su borde saca a
## cualquiera un poco fuera, y traerlo por eso seria una correa demasiado
## corta. Pendiente de playtest.
const SE_PASA_DE_LA_RAYA := 1.25


## Cuántas batidas lleva cada cual. Por persona, para que dos batidores no
## salgan el mismo día a lo mismo.
var _batidas: Dictionary = {}


## Adónde va la batida: AL PARAJE CON «???» MÁS CERCANO, y sólo si no queda
## ninguno, a peinar monte sin nombre.
##
## «Lo que deben hacer es explorar los materiales de los parajes de más cercano
## a más lejano, esa es su misión mientras haya ?? en los parajes». Es
## exactamente lo que distingue una batida de una expedición: la expedición
## abre comarca —[Exploration.best_frontier]—, la batida acaba de conocer lo
## que la banda ya encontró. Un avellanar del que sólo se sabe que tiene
## avellanas es un avellanar a medias.
##
## Aquí hubo una de cada tres batidas desviada a monte sin nombre, porque
## medido salían siete parajes el día uno, ocho el día seis y ni uno más. Ese
## atasco no era de la batida: la rejilla de familiaridad no pasaba de 0,24 por
## una resta que medía la altura, así que NINGUNA celda llegaba al 0,30 que
## hace falta para bautizar y daba igual a dónde se fuera. Arreglado eso, el
## desvío sólo servía para quitarle al batidor una de cada tres jornadas de su
## trabajo. Ver [Traversal.en_llano].
func _batida_target(person: Inhabitant) -> Vector3:
	_batidas[person.id] = int(_batidas.get(person.id, 0)) + 1

	# NO SE SUELTA UN SITIO HASTA DEJARLO SIN «???».
	#
	# Una batida dura media jornada —ver `_survey_hours_for`— asi que cada
	# batidor sale dos veces al dia, y volver a elegir en cada salida le hacia
	# cambiar de paraje a media tarde. Con dos batidores y la regla de no ir
	# adonde ya va otro, los dos se iban turnando los mismos cuatro sitios: cada
	# uno estaba yendo al mas cercano que tenia libre, y visto desde fuera era
	# un ir y venir sin orden.
	#
	# «Lo que noto es que dan vueltas entre varios parajes sin orden. Tiene que
	# ir de paraje mas cercano a mas lejano descubriendo ??».
	#
	# Asi que el sitio se hereda de la salida anterior mientras siga sirviendo:
	# mientras exista, le queden incognitas y se llegue. El orden por cercania
	# decide a que sitio se ENTRA; esto decide cuando se sale de el.
	if not person.paraje_batido.is_empty() and sim.parajes != null:
		var seguido := sim.parajes.por_id(person.paraje_batido)
		if seguido != null and seguido.has_unknowns() and not seguido.resting \
				and sim.marcha.alcanzable_de_verdad(
					person.position, seguido.position):
			return seguido.position

	var pending := sim._paraje_to_survey(person)
	if pending != null:
		# Se apunta CUAL, no solo adonde: al cerrar la jornada hay que saber a
		# que paraje se le abona lo aprendido. Ver [Inhabitant.paraje_batido].
		person.paraje_batido = pending.id()
		return pending.position

	# Sin incógnitas pendientes al alcance, se peina el entorno buscando
	# sitios nuevos: es lo único que queda por hacer aquí cerca.
	#
	# Y AQUI TAMBIEN SE MIRA EL CAMINO. Este es el plan B, y un plan B que
	# manda a alguien a estrellarse es peor que no tenerlo: `_least_known_around`
	# ya descarta lo que tiene el cauce de por medio en linea recta, pero un
	# punto puede estar seco, sin agua en la recta, y aun asi pedir un rodeo que
	# no se anda. Se prueban varios y se coge el primero que merezca el camino.
	person.paraje_batido = ""
	var suelto := sim.home_position
	var mejor_rodeo := INF
	for intento in range(4):
		var candidato := _least_known_around(sim.home_position,
			BATIDA_RADIUS * 0.35, BATIDA_RADIUS, person)
		# La ruta se vacia antes de pedir la del candidato siguiente: si no, un
		# candidato al que `_send_to` no le traza nada -por sabido imposible-
		# se queda con la ruta del anterior y se le mide un rodeo que no es
		# suyo.
		person.route = PackedVector3Array()
		person.route_step = 0
		sim.marcha._send_to(person, candidato)
		if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
			# Sin mirar no se descarta: se deja de probar y se sale con lo
			# que haya. Ver [Marcha.Traza].
			break
		if sim.marcha.merece_el_camino(person, candidato):
			return candidato
		# EL MENOS MALO, y no el ultimo probado.
		#
		# Se devolvia `suelto` = el cuarto candidato, hubiera salido como
		# hubiera salido: si los cuatro pedian rodeo, el batidor se iba con el
		# que tocara en el sorteo. Es la queja literal —«un explorador ha ido a
		# batir ese paraje y se ha ido a 1 km contra el rio»—: no es que no
		# hubiera camino, es que se cogia uno cualquiera de los malos.
		#
		# Y sin ruta no es candidato a nada: eso es mandar a alguien a un sitio
		# al que no se llega.
		if person.route.is_empty():
			continue
		var derecho := maxf(Traversal.en_llano(person.position, candidato), 1.0)
		var rodeo := sim.marcha.largo_de(person.position, person.route) / derecho
		if rodeo < mejor_rodeo:
			mejor_rodeo = rodeo
			suelto = candidato
	return suelto


## Cuantos sitios se miran antes de elegir adonde batir.
##
## Doce da para cubrir el circulo sin que la eleccion cueste nada: son doce
## consultas al mapa mental, no doce busquedas de camino.
## A que distancia se considera que a ese sitio YA VA OTRO.
##
## Ciento veinte metros, que es el radio de un paraje -ver [Paraje.extent]-:
## dos exploradores dentro de eso estan resolviendo las mismas incognitas y
## uno de los dos sobra.
##
## Estaba escrito a mano aqui y otra vez en
## [SettlementSim._paraje_to_survey], que decide lo mismo un paso antes. Dos
## copias de la regla de repartirse el monte es como se acaba con los dos
## batidores en el mismo sitio.
const YA_HAY_OTRO := 120.0


const SCAN_CANDIDATES := 12


## Cuánto tira el terreno de un sitio, de 0 a 1.
##
## Las dos guías de cualquiera que anda por el monte sin mapa: **el agua y el
## lomo**. La orilla de un cauce es un pasillo natural —se anda, se bebe, y
## lleva a alguna parte—; una loma es un mirador que se paga subiendo una vez
## y se cobra viendo mucho.
##
## No es un peso grande a propósito. Tiene que inclinar la elección entre dos
## sitios igual de desconocidos, no mandar a la banda a bordear el río mientras
## media comarca sigue en blanco.
func _terrain_lure(point: Vector3) -> float:
	if sim._terrain == null:
		return 0.0

	var lure := 0.0

	# La ORILLA: suelo que se pisa CON agua al lado. Se busca en los
	# alrededores y no en el propio punto, que era el fallo del primer intento:
	# preguntando solo por el punto, lo unico que da agua es el punto que ESTA
	# dentro del cauce -y por dentro del cauce no se explora, se nada-.
	#
	# Una orilla es justo lo contrario: tierra firme desde la que se ve el rio.
	var ford := sim._terrain.crossing_difficulty_at(point)
	if Hydrography.can_cross(ford, sim.has_boat, sim.has_bridge):
		var reach_water := 60.0
		for offset: Vector2 in [Vector2(reach_water, 0.0), Vector2(-reach_water, 0.0),
				Vector2(0.0, reach_water), Vector2(0.0, -reach_water)]:
			var side := point + Vector3(offset.x, 0.0, offset.y)
			if sim._terrain.crossing_difficulty_at(side) > Hydrography.HAY_AGUA:
				lure += LURE_WATER
				break

	# El LOMO: más alto que lo que tiene a un lado y a otro. Se mira a paso
	# largo porque un lomo es una forma del valle, no un bulto de tres metros.
	var here := sim._terrain.get_height_at(point)
	var reach := 90.0
	var above := 0
	for offset: Vector2 in [Vector2(reach, 0.0), Vector2(-reach, 0.0),
			Vector2(0.0, reach), Vector2(0.0, -reach)]:
		if here > sim._terrain.get_height_at(
				point + Vector3(offset.x, 0.0, offset.y)) + 6.0:
			above += 1
	if above >= 3:
		lure += LURE_RIDGE

	return lure


## Cuánto tira una orilla y cuánto tira un lomo.
##
## En la misma escala que «lo conocido», que va de 0 a 1: 0,12 quiere decir
## que un sitio junto al río gana a otro que esté un 12% menos explorado. Es
## una preferencia, no una obsesión.
const LURE_WATER := 0.12
const LURE_RIDGE := 0.10


## El punto MENOS conocido dentro de un anillo alrededor de un centro.
##
## Antes se sorteaba a ciegas, y sortear a ciegas quiere decir volver una y
## otra vez al mismo prado mientras el barranco de al lado sigue en blanco
## despues de veinte jornadas. Un batidor de verdad sabe por donde ha ido ya.
##
## No se coge el peor sin mas: se sortea entre los tres menos conocidos. Sin
## ese margen, dos batidores que salen la misma manana eligen exactamente el
## mismo punto, y salen en fila india.
## Donde esta "trabajando" de verdad un explorador ahora mismo, para el
## reparto entre batidores -que dos no vayan a lo mismo.
##
## Mientras viaja hacia su destino, es `target`. Una vez ha llegado y esta
## reconociendo, `target` deja de servir: cada tramo de la batida apunta a
## un punto nuevo dentro de SURVEY_RADIUS -hasta 260 m- del sitio, asi que
## un rato despues de llegar el "destino" ya no tiene nada que ver con el
## paraje que esta batiendo. Lo que se queda quieto mientras dura la visita
## es `work_centre`, y es eso lo que hay que mirar.
func _exploration_anchor(person: Inhabitant) -> Vector3:
	if person.state == Inhabitant.State.RECONOCIENDO:
		return person.work_centre
	return person.target


func _least_known_around(centre: Vector3, near: float, far: float,
		person: Inhabitant) -> Vector3:
	var best: Array[Dictionary] = []

	# ADONDE YA VA OTRO, UNA VEZ Y NO DOCE. Los demas exploradores no se mueven
	# mientras se barre el abanico, asi que sus anclas se sacan aqui: dentro
	# del bucle eran quince personas por cada uno de los doce candidatos. Van
	# en el mismo orden que `sim.people`, que es el orden en que se sumaban.
	var anclas: Array[Vector3] = []
	for other: Inhabitant in sim.people:
		if other != person and other.job == Profession.Job.EXPLORACION:
			anclas.append(_exploration_anchor(other))
	var terreno := sim._terrain

	for i in range(SCAN_CANDIDATES):
		# En abanico y no al azar, para que el barrido cubra el circulo
		var angle := (float(i) + sim._rng.randf()) / float(SCAN_CANDIDATES) * TAU
		var radius := sim._rng.randf_range(near, far)
		var candidate := centre + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		if terreno:
			candidate.y = terreno.get_height_at(candidate)
			if not Traversal.is_passable(terreno.get_slope_at(candidate),
					terreno.crossing_difficulty_at(candidate),
					sim.has_boat, sim.has_bridge):
				continue
			# Y que no haya cauce de por medio: pisable no es alcanzable, y la
			# otra orilla es las dos cosas menos la segunda. Ver
			# [Marcha.cruza_el_agua].
			if sim.marcha.cruza_el_agua(centre, candidate):
				continue

		# Un pelin de azar encima de lo conocido. Sin el, en cuanto dos sitios
		# empatan -y al principio de la partida empatan TODOS, porque no se
		# conoce nada- gana siempre el primero del barrido, y el abanico se
		# convierte en salir doce veces en la misma direccion. El margen es
		# pequeno a proposito: desempata sin tapar una diferencia de verdad.
		var known := sim._rng.randf() * 0.06
		if sim.knowledge:
			known += sim.knowledge.explored_at(candidate)

		# Y el terreno TIRA. Nadie explora un mapa a cuadros: se sigue el río
		# aguas arriba porque lleva a alguna parte y da de beber, y se sube al
		# lomo porque desde arriba se ve adónde ir. Un valle se conoce por sus
		# líneas, no por sus casillas.
		known -= _terrain_lure(candidate)
		# Adonde ya va otro no se va: asi se abren en abanico
		for ancla: Vector3 in anclas:
			if Traversal.en_llano(ancla, candidate) < YA_HAY_OTRO:
				known += 0.5
		best.append({"pos": candidate, "known": known})

	if best.is_empty():
		return centre

	best.sort_custom(func(a, b): return float(a["known"]) < float(b["known"]))
	var pick: Dictionary = best[sim._rng.randi() % mini(3, best.size())]
	return pick["pos"]


## Cuántos sitios trae como mucho quien vuelve de mirar el monte.
##
## UNO. Una jornada de reconocimiento cubre doscientos sesenta metros de radio y
## ahí caben siete sitios con nombre, así que sin tope el jugador ve siete
## chapas aparecer de golpe —medido: cuatro «pastos» y tres más, todos a las
## 16:10 del día 2—, que es la misma queja que con las de medianoche. Quien
## vuelve del monte trae UN sitio; los demás se quedan para la siguiente vuelta.
const DE_UNA_VUELTA := 1


## La prueba de «a este sitio se va de verdad», para pasarsela al bautizo.
func _se_llega() -> Callable:
	# Con memoria: la misma pregunta sale miles de veces en un barrido y la
	# respuesta no cambia hasta que cambia la rejilla. Ver
	# [Marcha.alcanzable_desde_casa].
	return func(punto: Vector3) -> bool:
		return sim.marcha.alcanzable_desde_casa(punto)


## Recoge los sitios que se ganaron nombre y no llegaron a salir en su momento.
##
## Corre a cada hora de luz, no al cerrar la jornada. Una vuelta de
## reconocimiento levanta un círculo de doscientos sesenta metros de golpe y
## sólo bautiza uno —ver [DE_UNA_VUELTA]—, así que siempre queda cola; con el
## repaso a medianoche, esa cola salía de madrugada y con el valle a oscuras,
## que es justo lo que el jugador no quería ver.
func repasar_rezagados() -> int:
	if sim.field == null or sim.knowledge == null:
		return 0
	var grid := sim.marcha._navgrid()
	var mismo_trozo := func(a: Vector3, b: Vector3) -> bool:
		return grid.connected(a, b)
	# UN OFICIO POR VUELTA, no los cinco.
	#
	# Esto barria las 4.096 celdas del campo POR CADA UNO de los cinco oficios,
	# y corre a cada hora de luz. El propio `Parajes.refresh` avisa —«sin
	# acotar, el barrido recorre las 4.096 celdas y hacerlo a cada hallazgo se
	# comeria el rendimiento»— y este era justo quien no le hacia caso.
	#
	# Medido con `PicoProbe`: 665 ms POR LLAMADA, una llamada cada 0,83 s de
	# reloj a velocidad 6. Es el tiron que se veia, dicho por el jugador antes
	# que por la sonda: «cada segundo o asi llega algun frame de 1000 ms».
	#
	# Es una COLA, no una urgencia: lo que busca son sitios que se ganaron el
	# nombre y no llegaron a salir. Repasar un oficio por hora los repasa los
	# cinco cada cinco horas de luz, y una jornada tiene trece.
	# Un oficio Y UNA FRANJA por vuelta. Con cinco oficios y cuatro franjas, el
	# campo entero se repasa cada veinte horas de luz, o sea cada dia y medio
	# largo. De sobra para una cola.
	# PRIMERO LA COLA, que es de lo que va esto.
	#
	# Sacar al siguiente que espera no cuesta un barrido: los candidatos ya
	# estan apuntados desde que se encontraron. Ver [Parajes.cola].
	var salieron := sim.parajes.vaciar_cola(sim.field, sim.knowledge,
		sim.day, sim._terrain, mismo_trozo, DE_UNA_VUELTA, _se_llega())
	if salieron > 0:
		_contar_los_nuevos()
		return salieron

	# Y EL BARRIDO, SOLO CUANDO HAY MOTIVO.
	#
	# El motivo es que haya cambiado POR DONDE SE PASA: un sitio que se
	# descarto en enero porque el rio iba crecido vuelve a ser candidato en
	# agosto sin que nadie haya vuelto a mirarlo, asi que ahi si hay que
	# repasar el mapa. Lo avisa la propia rejilla al cambiar -ver
	# [Marcha.forget_routes]-.
	#
	# Barria SIEMPRE, a cada hora de luz, y de ahi salia el tiron: 178 ms del
	# peor cuadro medidos con `PicoProbe`. Y no era solo caro: al barrer por
	# turnos -un oficio y una franja por vuelta- un sitio podia esperar dia y
	# medio a que le tocara su casilla, que es una cola con latencia
	# inventada. Ahora sale en cuanto se descubre.
	if not sim.parajes.revisar_el_mapa:
		return 0

	var turno := _de_quien_toca % TURNOS.size()
	@warning_ignore("integer_division")
	var trozo := (_de_quien_toca / TURNOS.size()) % FRANJAS
	_de_quien_toca += 1
	# Cuando se han dado las cinco vueltas por las cuatro franjas, el mapa
	# esta repasado entero y el aviso se apaga hasta el proximo cambio.
	if _de_quien_toca % (TURNOS.size() * FRANJAS) == 0:
		sim.parajes.revisar_el_mapa = false
	var alto := int(ceil(float(sim.field.height) / float(FRANJAS)))
	salieron = sim.parajes.refresh(sim.field, sim.knowledge, sim.day,
		[TURNOS[turno]], sim._terrain, mismo_trozo,
		Vector3.ZERO, 0.0, DE_UNA_VUELTA, _se_llega(),
		Vector2i(trozo * alto, (trozo + 1) * alto))
	if salieron > 0:
		_contar_los_nuevos()
	return salieron


## Los oficios del repaso, en el orden en que se turnan.
const TURNOS := [
	Subsistence.Activity.RECOLECCION,
	Subsistence.Activity.CAZA,
	Subsistence.Activity.MATERIA_PRIMA,
	Subsistence.Activity.PESCA,
	Subsistence.Activity.MARISQUEO,
]

## En cuantos trozos se parte el campo para repasarlo.
const FRANJAS := 4

## A quien le toca el proximo repaso.
var _de_quien_toca: int = 0


## Bautiza lo que se acabe de descubrir alrededor de un punto, EN EL MOMENTO.
##
## La otra mitad de [_name_new_parajes], que es el repaso de fin de jornada.
## Esta corre cuando alguien descubre algo y sólo mira su vuelta, para que la
## chapa aparezca cuando el hallazgo, y no todas juntas a medianoche.
func bautizar_lo_descubierto(centro: Vector3, radio: float) -> int:
	if sim.field == null or sim.knowledge == null:
		return 0
	var grid := sim.marcha._navgrid()
	var mismo_trozo := func(a: Vector3, b: Vector3) -> bool:
		return grid.connected(a, b)
	var salieron := sim.parajes.refresh(sim.field, sim.knowledge, sim.day, [
		Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
		Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
		Subsistence.Activity.MATERIA_PRIMA], sim._terrain, mismo_trozo,
		centro, radio, DE_UNA_VUELTA, _se_llega())
	if salieron > 0:
		_contar_los_nuevos()
	return salieron


## Bautiza los sim.parajes que se hayan ganado un nombre y los cuenta.
func _name_new_parajes() -> void:
	if sim.field == null or sim.knowledge == null:
		sim._new_ground_surveys_today.clear()
		return

	sim.parajes.just_found.clear()

	# Primero las bajas y luego las altas. Una veta agotada deja de nombrar
	# su paraje ANTES de que se repase el mapa, para que el punto quede
	# libre y `refresh` pueda bautizarlo esa misma jornada por otra cosa.
	for loss: Dictionary in sim.parajes.prune_exhausted(sim.field):
		var lost: Paraje = loss["paraje"]
		var spent := Materia.material_name(loss["kind"] as Materia.Kind).to_lower()
		if bool(loss["gone"]):
			sim._note(Chronicle.Kind.PENURIA,
				"Se acabo %s: no queda %s que sacar y el sitio deja de tener nombre."
					% [lost.name_text, spent], 2)
		else:
			sim._note(Chronicle.Kind.PENURIA,
				"Se acabo el %s de aquel sitio; lo que queda alli ya es otra cosa: %s."
					% [spent, lost.name_text], 1)

	# AQUI YA NO SE BAUTIZA NADA.
	#
	# Bautizan dos: quien vuelve de mirar el monte -[bautizar_lo_descubierto]- y
	# el repaso de cada hora de luz -[repasar_rezagados]-. Este cierre de
	# jornada se queda con lo suyo: dar de baja las vetas agotadas y contar lo
	# que haya salido. Mientras bautizaba, la cola entera aparecia a las 00:00 y
	# el jugador veia las chapas salir todas juntas de madrugada.
	_contar_los_nuevos()
	sim._new_ground_surveys_today.clear()


## Cuenta los sitios recien bautizados y vacia la lista.
##
## Vive aparte porque bautizan DOS: el hallazgo de quien vuelve de mirar -ver
## [bautizar_lo_descubierto]- y el repaso de fin de jornada. Los dos tienen que
## contarlo igual, y ninguno debe volver a contar lo que ya conto el otro.
func _contar_los_nuevos() -> void:
	for paraje: Paraje in sim.parajes.just_found:
		sim._note(Chronicle.Kind.HALLAZGO,
			"La banda ya conoce bien un sitio y le ha puesto nombre: %s, %s a %d m."
				% [paraje.name_text,
					Parajes.bearing(sim.home_position, paraje.position),
					int(paraje.distance_from(sim.home_position))], 1)
		# Poner nombre a un sitio es el hito de la exploración, y se enseña como
		# tal: hasta ahora aparecía un alfiler más en el valle y nada más.
		sim.raise_moment(Moment.found("Un sitio con nombre",
			"%s, %s a %d m del abrigo. La banda ya lo conoce lo bastante como "
				% [paraje.name_text,
					Parajes.bearing(sim.home_position, paraje.position),
					int(paraje.distance_from(sim.home_position))]
			+ "para volver sola.", paraje.position))

	_credit_new_ground(sim.parajes.just_found)
	sim.parajes.just_found.clear()


## Premia con destreza a quien de verdad ha abierto cada paraje de
## `just_found` hoy -batida o expedicion, cada cual en lo suyo. El hito
## grande no es acabar de conocer un sitio que ya se tenia -eso es
## `_finish_survey`, un material a la vez-, es abrir uno que no existia.
## Aparte de `_name_new_parajes` para poder probarlo sin montar un campo de
## recursos entero.
func _credit_new_ground(just_found: Array[Paraje]) -> void:
	for paraje: Paraje in just_found:
		for entry: Dictionary in sim._new_ground_surveys_today:
			var surveyor: Inhabitant = entry["person"]
			var spot: Vector3 = entry["position"]
			var speciality := entry["speciality"] as Profession.Speciality
			if spot.distance_to(paraje.position) < SettlementSim.SURVEY_RADIUS:
				_award_exploration_skill(surveyor, speciality, SettlementSim.PARAJE_MILESTONE)
				# «Encontro un buen paraje a las XX:XX», en el diario de quien
				# lo encontro. La cronica de la banda ya lo cuenta, pero no
				# dice de quien fue.
				sim.cronista.hallazgo(surveyor,
					"Encontró un buen paraje y le puso nombre: %s, %s a %d m."
						% [paraje.name_text,
							Parajes.bearing(sim.home_position, paraje.position),
							int(paraje.distance_from(sim.home_position))])


## Manda explorar hacia un punto. Lo llama el clic sobre terreno desnudo.
func scout_towards(point: Vector3) -> void:
	sim.scout_order = point
	sim.has_scout_order = true
	sim._note(Chronicle.Kind.GENTE,
		"Sale partida a reconocer %s. Nadie sabe que hay alli."
			% sim.parajes.place_name(point, sim.home_position), 1)


func clear_scout_order() -> void:
	if not sim.has_scout_order:
		return
	sim.has_scout_order = false
	sim._note(Chronicle.Kind.GENTE,
		"Se levanta la orden de sim.reconocimiento: la banda vuelve a elegir "
			+ "adonde mirar.", 0)


## Si alguien ha llegado ya al sitio señalado, la orden se da por cumplida.
##
## Se comprueba al cerrar la jornada y no por fotograma: una orden que se
## cancela sola a mitad de camino deja a la partida dando vueltas.
func _check_scout_order() -> void:
	# La orden ya NO se cumple por pisar el punto: se cumple cuando alguien
	# termina de reconocer la comarca. Lo hace `_finish_survey`.
	pass


## Radio dentro del cual se batea un paraje mientras se trabaja.
const FORAGE_RADIUS := 70.0


## Sube la destreza de una especialidad de EXPLORACION. Los hitos -material
## nuevo, paraje nuevo, vado nuevo- pasan por aqui y no por
## `skill_in`/`skill[]` a pelo, para que el techo y la velocidad por edad se
## apliquen siempre igual.
func _award_exploration_skill(person: Inhabitant,
		speciality: Profession.Speciality, amount: float) -> void:
	var task := Profession.task_id(Profession.Job.EXPLORACION, speciality)
	var current := person.skill_in(task)
	person.skill[task] = minf(current + amount * person.learn_rate(), 0.95)
	person.train_stat(Inhabitant.Stat.AGUDEZA, amount * SettlementSim.AGUDEZA_MILESTONE_SHARE)


## Techos de la destreza de BATIDA segun COMO se gana. No es un tope unico:
## la petición literal es que sin hito de verdad no se pase de medio saber
## el oficio, y que abrir un paraje pese mucho mas que acabar de conocer uno
## que ya se tenia.
##
##   - Sola practica, sin encontrar nada: hasta 50.
##   - Dar con un material que faltaba en un paraje YA conocido: hasta 75.
##   - Abrir un paraje que no existia: hasta 95 -el techo de siempre-.
##
## Un batidor de sillon -que sale, mira y no encuentra nada nuevo nunca- se
## queda a medias para siempre. Eso es la intención, no un fallo de ajuste.
const BATIDA_REPETITION_CEILING := 0.50
const BATIDA_MATERIAL_CEILING := 0.75


## Sube la destreza de BATIDA sin pasar del techo que le toca a esta fuente
## de aprendizaje. Ver la nota de arriba para los tres techos.
func _grow_batida_skill(person: Inhabitant, amount: float, ceiling: float) -> void:
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	var current := person.skill_in(task)
	if current >= ceiling:
		return
	person.skill[task] = minf(current + amount * person.learn_rate(), ceiling)
	person.train_stat(Inhabitant.Stat.AGUDEZA, amount * SettlementSim.AGUDEZA_MILESTONE_SHARE)


## Batir la comarca adonde se mando mirar.
##
## Es lo que faltaba para que explorar signifique algo. Antes se pisaba el
## punto y la orden se daba por cumplida, que es marcar una casilla. Ahora se
## pasa la jornada dando vueltas por los alrededores, y lo que se descubre
## sale de haberlos andado.
## Cuanto sube la destreza de batida por hora de puro andar y mirar, sin dar
## con nada -tope BATIDA_REPETITION_CEILING. Minusculo a proposito: es la
## unica de las tres fuentes que no pide encontrar nada, asi que tiene que
## ser tambien la mas floja.
const BATIDA_REPETITION_RATE := 0.001


func _survey(person: Inhabitant, hours: float) -> void:
	# Las marcas del cepo de aqui son las de la tarea 21 de
	# docs/specs/LO_MISMO_MAS_DEPRISA.md: reconocer cuesta 2,1 ms por tick
	# -cien veces mas que trabajar- y se lleva el 73 % de los tirones de una
	# ventana de invierno. «Reconocer» a secas no dice cual de sus piezas.
	person.survey_hours += hours
	Cronometro.tramo("reconociendo: horas que pide")
	var needed := _survey_hours_for(person)
	Cronometro.cierra("reconociendo: horas que pide")
	person.fatigue = clampf(
		person.fatigue + hours * 4.0 * person.fatigue_factor(), 0.0, 100.0)

	# Batir la comarca ES la enseñanza, no un aparte de ella: `_learn_from`
	# -que enseña el YENDO y el TRABAJANDO- no corre en RECONOCIENDO, así
	# que las horas de sim.reconocimiento -que son la mayor parte del viaje de
	# una expedición- no enseñaban nada de nada. La familiaridad nunca
	# llegaba al umbral de nombrar un paraje nuevo por mucho que la banda
	# saliera a explorar: esto es lo que de verdad apagaba el descubrimiento.
	if sim.knowledge:
		Cronometro.tramo("reconociendo: ver y observar")
		sim.knowledge.see_from(person.position, sim.sight_range * sim.weather.sight_factor())
		var pace := hours / 24.0
		for activity: int in sim._activities_for_learning(person):
			sim.knowledge.observe(activity as Subsistence.Activity, person.position, pace)
		Cronometro.cierra("reconociendo: ver y observar")

	if person.current_speciality == Profession.Speciality.BATIDA:
		_grow_batida_skill(person, hours * BATIDA_REPETITION_RATE,
			BATIDA_REPETITION_CEILING)

	# Y se recoge lo que va saliendo: reconocer no es andar con las manos en
	# los bolsillos. Ver [_recoger_de_paso].
	Cronometro.tramo("reconociendo: recoger de paso")
	_recoger_de_paso(person, hours)
	Cronometro.cierra("reconociendo: recoger de paso")

	if person.work_centre == Vector3.ZERO:
		person.work_centre = person.position

	# LA CORREA DE LA BATIDA, Y ES ABSOLUTA.
	#
	# Todo lo demas de aqui mide RODEOS -el camino contra la linea recta- y esa
	# cuenta es relativa: una vez que alguien esta lejos, cualquier tramo suyo
	# le sale de rodeo corto y nada le trae de vuelta. Medido con `BatidaProbe`:
	# el destino a 292 m del abrigo y el batidor A 843, jornada tras jornada,
	# «encima» de un paraje que esta a 226.
	#
	# Una batida sale despues de desayunar y duerme en casa: su radio es
	# [SettlementSim.RADIO_DE_JORNADA] —el mismo hasta donde se va a un tajo,
	# porque es la misma pregunta— y punto. Pasado eso no se sortea otro tramo,
	# se vuelve al
	# sitio que se vino a batir. Es lo que se pidio dicho al derecho: «lo que no
	# quiero nunca es que se vayan mas lejos de lo necesario».
	if person.current_speciality == Profession.Speciality.BATIDA:
		Cronometro.tramo("reconociendo: correa")
		var vuelvo := Vector3.ZERO
		var porque := ""

		# LA CORREA VA AL SITIO QUE SE ESTA BATIENDO, no al abrigo.
		#
		# Atada al abrigo no sirve: batiendo un paraje a 227 m, el batidor se
		# plantaba a 818 —medido con `BatidaProbe`, jornadas 4 a 6, y dos dias
		# seguidos sin resolver una sola incognita— y la correa del abrigo no
		# se enteraba porque 818 cabe de sobra en el radio de jornada. Lo que
		# esta mal no es estar lejos de casa: es estar lejos DEL SITIO al que
		# se ha venido, que es donde estan las «???».
		var suyo: Paraje = null
		if not person.paraje_batido.is_empty() and sim.parajes != null:
			suyo = sim.parajes.por_id(person.paraje_batido)
		if suyo != null:
			var fuera := Traversal.en_llano(suyo.position, person.position)
			if fuera > suyo.extent * SE_PASA_DE_LA_RAYA:
				vuelvo = suyo.position
				porque = "batiendo %s se habia ido %.0f m fuera de el" % [
					suyo.name_text, fuera]
		# Y sin sitio —peinando monte— la correa es la del PEINADO, que es lo
		# que [BATIDA_RADIUS] quiere decir: la vuelta corta alrededor del
		# campamento. Con la de jornada —novecientos, la de ir a un sitio que ya
		# se conoce— se consentia deambular hasta 900 m sin estar batiendo nada,
		# y ahi es donde se perdian: medido en un año, tres jornadas seguidas
		# «reconociendo» a 156, 270 y 338 m sin estar encima de ningun paraje, y
		# a la cuarta plantada.
		elif Traversal.en_llano(sim.home_position, person.position) 				> BATIDA_RADIUS * SE_PASA_DE_LA_RAYA:
			vuelvo = sim.home_position
			porque = "peinando monte se habia ido a %.0f m del abrigo" % 				Traversal.en_llano(sim.home_position, person.position)

		if vuelvo != Vector3.ZERO:
			sim.marcha._record_stuck(person, porque)
			person.route = PackedVector3Array()
			person.route_step = 0
			person.horas_en_el_tramo = 0.0
			person.forage_target = vuelvo
			sim.marcha._send_to(person, vuelvo)
			Cronometro.cierra("reconociendo: correa")
			return
		Cronometro.cierra("reconociendo: correa")

	# Se BATE la comarca: se da la vuelta al punto por tramos, subiendo al
	# alto de al lado, bajando al arroyo, mirando el cortado.
	#
	# Antes se quedaba clavado nueve horas y luego decia «explorado». Y el
	# fallo no era del sorteo del siguiente tramo sino de la ruta: al llegar
	# quedaba el camino del viaje a medio consumir, y `next_waypoint` devuelve
	# el hito del camino ANTES que el destino, asi que por mucho que se
	# cambiara el destino la persona seguia apuntando al sitio donde ya
	# estaba.
	# RECONOCER NO ES CORRER: en cada tramo hay que pararse a mirar.
	#
	# Antes se sorteaba el siguiente tramo en cuanto se llegaba, y a velocidad
	# de persona doscientos sesenta metros se andan en cinco minutos: la jornada
	# de reconocimiento salían casi cincuenta tramos y once kilómetros de
	# zigzag. En la ventana de rastros se veía como un ovillo y siete kilómetros
	# por batida para un sitio a ochocientos metros.
	#
	# Reconocer un trozo de monte es subirse al alto, bajar al arroyo, mirar el
	# cortado: eso lleva un rato en cada sitio. Ver [MIRAR_EL_SITIO].
	person.horas_en_el_tramo += hours
	var arrived := person.position.distance_to(person.forage_target) < sim.arrive_radius
	var sin_ruta := person.route.is_empty()
	var ruta_acabada := not sin_ruta and person.route_step >= person.route.size()

	# EN CADA TRAMO HAY QUE PARARSE A MIRAR, Y AHORA SE CUMPLE.
	#
	# La condicion era «llego y miro, O la ruta se acabo», y ese O se comia la
	# regla: el andador sube `route_step` al pisar el ultimo hito -ver el paso
	# de hito en [Marcha]-, asi que en el mismo tick de llegar ya se sorteaba
	# el siguiente tramo, sin la media hora. Medido, dos ventanas de cinco
	# jornadas desde el dia 151: CERO tramos de casi mil respetaban
	# [MIRAR_EL_SITIO], y sortearlos era el 68 % del paso en los fotogramas
	# malos. Ver la tarea 21.9 de docs/specs/LO_MISMO_MAS_DEPRISA.md.
	#
	# SI EL CAMINO NO LLEGA DEL TODO, SE MIRA DESDE DONDE ACABA. La ruta puede
	# acabar antes del destino -el trazado amarra el destino a suelo pisable-,
	# y esperar ahi con el destino puesto seria peor que no esperar: el
	# andador vuelve a trazar hacia el en cada tick («la ruta agotada sin
	# haber llegado es justamente cuando hay que volver a trazar», [Marcha]).
	# Se da el sitio por alcanzado donde se esta.
	if ruta_acabada and not arrived:
		person.forage_target = person.position
		person.target = person.position
		arrived = true

	var toca := false
	if sin_ruta:
		# SIN RUTA, UN RATO QUIETO Y SE VUELVE A PROBAR. Es la misma espera
		# que la de la decision que no llevo a nada -ver
		# [SettlementSim.ESPERA_PARA_REPENSAR]-: el monte no cambia en
		# veinticuatro segundos. Y quieto de verdad: con el destino puesto, el
		# andador volveria a trazar hacia el en cada tick.
		toca = person.horas_en_el_tramo >= SettlementSim.ESPERA_PARA_REPENSAR
		if not toca:
			person.target = person.position
	else:
		toca = arrived and person.horas_en_el_tramo >= MIRAR_EL_SITIO

	if toca:
		var porque_tramo := "reconociendo: siguiente tramo (sin ruta)" if sin_ruta \
			else "reconociendo: siguiente tramo (miro el sitio)"
		person.horas_en_el_tramo = 0.0
		Cronometro.tramo("reconociendo: siguiente tramo")
		Cronometro.tramo(porque_tramo)
		_next_survey_leg(person)
		Cronometro.cierra(porque_tramo)
		Cronometro.cierra("reconociendo: siguiente tramo")

	if person.survey_hours >= needed:
		Cronometro.tramo("reconociendo: terminar")
		_finish_survey(person)
		Cronometro.cierra("reconociendo: terminar")


## A qué nivel deja una jornada de reconocimiento lo que ha batido.
##
## Se pone para que EL BORDE de lo batido caiga justo en el listón de bautizar
## —[Parajes.NAMED_AT]— y el centro quede por encima. No es un número suelto:
## es la traducción de «una jornada reconociendo deja el sitio conocido».
##
## Con el listón a secas —0,32— no servía de nada, y ése fue mi propio error al
## repartir lo aprendido por el área: la caída hasta el borde
## ([BandKnowledge.SE_APRENDE_MENOS_LEJOS], 0,55) dejaba el filo en 0,176, o sea
## por debajo del umbral, y sólo pasaban las celdillas a menos de treinta y seis
## metros del punto. Una. Exactamente lo que había antes de repartir nada.
const LO_QUE_DEJA_UNA_JORNADA := BandKnowledge.KNOWN_ENOUGH 	/ BandKnowledge.SE_APRENDE_MENOS_LEJOS + 0.02


## Cuanto se recoge reconociendo, en partes de lo que sacaria un recolector.
##
## Un quinto. Quien bate el monte no se para a vaciar un avellanar -esta
## mirando, no cosechando- pero tampoco pasa de largo por delante de la leña, un
## nodulo bueno o un puñado de avellanas. Es lo que se pidio: «los exploradores
## tambien deben ir recogiendo materiales y recursos mientras hacen sus batidas,
## exploraciones y ascensiones».
##
## Pendiente de playtest: subirlo convierte al explorador en un recolector lento,
## bajarlo lo deja volviendo de vacio otra vez.
const DE_PASO := 0.20


## Lo que se coge ANDANDO, o -1 si aqui no hay nada que echarse al zurron.
##
## Recoleccion y materia prima y nada mas: nadie caza ni pesca mientras
## reconoce, pero leña, fibra y un canto bueno se cogen de paso.
func _lo_que_se_coge_andando(donde: Vector3) -> int:
	var mejor := -1
	var cuanto := 0.05
	for actividad: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var hay := sim.field.seasonal_abundance_at(
			actividad as Subsistence.Activity, donde, GameState.season)
		if hay > cuanto:
			cuanto = hay
			mejor = actividad
	return mejor


## Recoge lo que se encuentra sin dejar de reconocer.
##
## Se le PRESTA la actividad al tajo y se le devuelve. Es feo y es a proposito:
## la cosecha lleva dentro la pericia, la estacion, el agotamiento de la celda,
## la herramienta y el libro de produccion, y duplicar todo eso aqui para
## restarle un factor seria tener dos cosechas que se separarian a la primera.
## Lo que cambia es el RITMO -[DE_PASO]- y nada mas.
func _recoger_de_paso(person: Inhabitant, hours: float) -> void:
	if sim.field == null or sim.tajo == null:
		return
	var act := _lo_que_se_coge_andando(person.position)
	if act < 0:
		return
	var suya := person.activity
	person.activity = act as Subsistence.Activity
	sim.tajo._harvest(person, hours * DE_PASO)
	person.activity = suya


## Se acabo el sim.reconocimiento: se cuenta lo visto y se vuelve.
## Cuantos materiales como mucho se resuelven en una sola visita, por buena
## que sea la destreza. Sin tope, un batidor muy bueno vaciaba un paraje
## entero de una tarde: es descubrir DEMASIADO deprisa, y deja de sentirse
## como volver dia tras dia.
const MAX_REVEALS_PER_VISIT := 3

## Cuanto pesa la destreza en la probabilidad de encadenar otro hallazgo la
## misma tarde. Por debajo de 1 a proposito: con la destreza entera, hasta
## el mejor batidor encadena como mucho la mitad de las veces.
const CHAIN_REVEAL_FACTOR := 0.5


## Se acabo el sim.reconocimiento: se cuenta lo visto y se vuelve.
func _finish_survey(person: Inhabitant) -> void:
	var where := sim.parajes.place_name(person.work_centre, sim.home_position)

	if sim.has_scout_order:
		var flat := Vector2(person.work_centre.x - sim.scout_order.x,
			person.work_centre.z - sim.scout_order.z)
		if flat.length() < SettlementSim.SCOUT_REACHED:
			sim.has_scout_order = false

	var speciality := person.current_speciality as Profession.Speciality
	var is_batida := speciality == Profession.Speciality.BATIDA
	# La expedicion y la ascension caen aqui cuando NO estan resolviendo su
	# cosa propia -un frente lejano, un pico- sino batiendo terreno de paso:
	# abrir un paraje nuevo tambien les cuenta como hito.
	var opens_ground := speciality == Profession.Speciality.EXPEDICION \
		or speciality == Profession.Speciality.ASCENSION
	var batida_task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)

	# Si se ha batido un paraje, la jornada resuelve una o mas incognitas,
	# hasta MAX_REVEALS_PER_VISIT. Cuantas depende de la destreza: un ojo
	# entrenado no se conforma con lo primero que ve, y esa misma destreza
	# sube por dar con algo NUEVO -no por las horas andadas, que esas ya se
	# cuentan aparte en `_survey`, con su propio techo bajo. Esto es cosa de
	# BATIDA: la expedicion no vuelve a un paraje a resolver lo que le
	# falta, eso es justo lo que distingue a las dos.
	# EL PARAJE AL QUE SE LE MANDO, no el primero que pille el punto.
	#
	# Las huellas se solapan y `_paraje_at` devuelve el primero de la lista que
	# contenga el punto —el mas antiguo—, asi que la jornada se le abonaba a un
	# vecino que a lo mejor ya estaba conocido a fondo. Ver
	# [Inhabitant.paraje_batido].
	#
	# Y HABER LLEGADO SE MIDE CON LA MISMA VARA QUE LA CORREA, no con la
	# huella.
	#
	# Aqui se exigia estar DENTRO de la huella, y la correa que sujeta al
	# batidor mientras bate usa otra cosa: el radio del paraje con un cuarto
	# de margen -[SE_PASA_DE_LA_RAYA]-. Dos reglas para «¿esta en su sitio?»,
	# y la de aqui es la mas estrecha.
	#
	# Lo pagaban LAS PESQUERAS. Un paraje de pesca abarca setenta metros
	# -[Paraje.EXTENSION]- y su huella es una cinta que sigue el cauce, asi
	# que el batidor acaba la jornada en la orilla, un paso fuera de la
	# cinta: la correa lo daba por dentro y esto por fuera, y la jornada no
	# resolvia ninguna incognita. Es la queja: «hay parajes, sobre todo de
	# pesca, que no se descubren todos los ?? aunque esten al alcance».
	var here := sim._paraje_at(person.work_centre)
	if not person.paraje_batido.is_empty() and sim.parajes != null:
		var mandado := sim.parajes.por_id(person.paraje_batido)
		if mandado != null and Traversal.en_llano(mandado.position,
			person.work_centre) <= mandado.extent * SE_PASA_DE_LA_RAYA:
			here = mandado

	# APRENDER EL TERRENO SE HACE SIEMPRE, se esté sobre un paraje o no.
	#
	# Estaba metido en un `elif here == null`, o sea que sólo se aprendía monte
	# cuando la jornada caía FUERA de un sitio con nombre. Y como una batida
	# elige siempre un paraje a medio investigar —[SettlementSim._paraje_to_survey]
	# devuelve uno mientras quede alguno con incógnitas—, esa rama no corría
	# casi nunca y la banda no aprendía el valle.
	#
	# Son dos cosas distintas y ninguna es el «si no» de la otra: una jornada
	# reconociendo RESUELVE una incógnita del sitio, si está en uno, y ADEMÁS
	# enseña la vuelta entera, que es lo que se ve desde allí.
	#
	# Lo que sigue distinguiendo al explorador es el ALCANCE de lo que aprende:
	# él abre el sitio para todos los oficios —para eso bate la comarca— y los
	# demás sólo para el suyo. Ver `_activities_for_learning`.
	if sim.knowledge:
		# Primero la niebla: no se puede APRENDER lo que no se ha visto -de eso
		# se encarga [BandKnowledge.reveal_around]-, y terminar una jornada
		# batiendo un circulo es haberlo visto entero. Se hacia solo por el
		# camino, tick a tick, asi que dependia de por donde hubieran pasado
		# los pasos en vez de por donde se ha batido.
		sim.knowledge.see_from(person.work_centre, SettlementSim.SURVEY_RADIUS)
		# TODO LO BATIDO, no la celda que se pisa. Ver
		# [BandKnowledge.reveal_around]: una jornada reconociendo un círculo de
		# doscientos sesenta metros revelaba un cuadrado de sesenta y cuatro, y
		# el valle se quedaba en blanco para siempre.
		for activity: int in sim._activities_for_learning(person):
			sim.knowledge.reveal_around(activity as Subsistence.Activity,
				person.work_centre, SettlementSim.SURVEY_RADIUS,
				LO_QUE_DEJA_UNA_JORNADA)

		# Y SE BAUTIZA AHORA, no al cierre de la jornada.
		#
		# «Los parajes deben aparecer a medida que se descubran; ahora mismo
		# aparecen todos a la vez cuando llegan las 12 de la noche». Salian de
		# golpe porque el unico que bautizaba era el repaso de medianoche. Un
		# sitio se descubre cuando alguien vuelve de mirarlo, y es entonces
		# cuando tiene que aparecer su chapa en el valle.
		#
		# Acotado a lo que esta persona acaba de aprender: el barrido completo
		# recorre las 4.096 celdas del campo y hacerlo a cada hallazgo se
		# comeria el rendimiento.
		bautizar_lo_descubierto(person.work_centre, SettlementSim.SURVEY_RADIUS)

	var discovered: Array[String] = []
	if here != null and here.has_unknowns():
		var reveals := 1
		while reveals > 0 and here.has_unknowns() \
				and discovered.size() < MAX_REVEALS_PER_VISIT:
			reveals -= 1
			var found_kind := here.reveal_one()
			if found_kind < 0:
				continue
			discovered.append(Materia.material_name(
				found_kind as Materia.Kind).to_lower())
			if is_batida:
				_grow_batida_skill(person, SettlementSim.BATIDA_MATERIAL_MILESTONE,
					BATIDA_MATERIAL_CEILING)
				# LA CUENTA INTERNA, y se cuenta. El jugador pidió saber «si no
				# encontró nada por una cuenta interna, y si es así, qué % tenía
				# de haberlo encontrado»: aquí está la única del reconocimiento.
				var opcion := person.skill_in(batida_task) * CHAIN_REVEAL_FACTOR
				if sim._rng.randf() < opcion:
					reveals += 1
				elif discovered.size() < MAX_REVEALS_PER_VISIT:
					sim.cronista.hallazgo(person,
						"Buscó si había algo más y no dio con ello: tenía un "
							+ "%.0f %% de encontrarlo, que es lo que da su "
								% (opcion * 100.0)
							+ "destreza batiendo.")
	# Y el hito de abrir MONTE NUEVO sigue siendo sólo del explorador:
	# `_credit_new_ground` premia destreza DE EXPLORACIÓN, y dársela a un
	# recolector por recoger sería pagarle dos veces por la misma jornada.
	if here == null and (is_batida or opens_ground):
		sim._new_ground_surveys_today.append({"person": person,
				"position": person.work_centre, "speciality": speciality})

	# Que contar. Encontrar algo en un paraje manda siempre sobre el repaso
	# generico del terreno -"hay caza", "monte y piedra"-: una batida que
	# vuelve con novedades de verdad no puede leerse igual que una que no
	# encontro nada, ni en la cronica ni en el rastro.
	# POR QUE SE VUELVE DE VACIO. Es la otra mitad de lo que se pidió: que la
	# crónica diga si no se encontró nada y por qué, en vez de dejar una línea
	# de «volvió de vacío» sin explicación.
	if discovered.is_empty():
		if here == null:
			sim.cronista.hallazgo(person,
				"Aquí no había ningún sitio con nombre que investigar: lo que "
					+ "trae es mapa, no hallazgos.")
		elif not here.has_unknowns():
			sim.cronista.hallazgo(person,
				"De %s ya se sabía todo: no quedaba nada por descubrir."
					% here.name_text)

	var outcome: String
	if not discovered.is_empty():
		outcome = "investig\u00f3 %s y encontr\u00f3 %s" % [where, ", ".join(discovered)]
		sim._note(Chronicle.Kind.HALLAZGO,
			"%s investig\u00f3 %s y encontr\u00f3 %s. Se sabe el %.0f%% de lo que hay."
				% [person.given_name, here.name_text, ", ".join(discovered),
					here.known_fraction() * 100.0], 1)
		# Y en SU diario, con la hora y la distancia: es la mitad de lo que se
		# pidio -«ha descubierto raices a X metros de la cueva a las XX:XX».
		sim.cronista.hallazgo(person,
			"Descubrió %s en %s, a %.0f m del abrigo. Del sitio se sabe ya el %.0f %%."
				% [", ".join(discovered), here.name_text,
					sim.home_position.distance_to(person.work_centre),
					here.known_fraction() * 100.0])
	else:
		var found: Array[String] = []
		if sim.field:
			for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
					Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
					Subsistence.Activity.MATERIA_PRIMA]:
				var value := sim.field.seasonal_abundance_at(
					activity as Subsistence.Activity, person.work_centre,
					GameState.season)
				if value > 0.45:
					found.append(Subsistence.activity_name(
						activity as Subsistence.Activity).to_lower())

		if found.is_empty():
			outcome = "poca cosa: monte y piedra"
			sim._note(Chronicle.Kind.HALLAZGO,
				"%s paso la jornada reconociendo %s. Poca cosa: monte y piedra."
					% [person.given_name, where], 1)
		else:
			outcome = "hay %s" % ", ".join(found)
			sim._note(Chronicle.Kind.HALLAZGO,
				"%s reconocio %s. Hay %s." % [person.given_name, where,
					", ".join(found)], 2)

	person.survey_hours = 0.0
	person.log_deed(person.current_task(), "comarca reconocida")
	person.end_journey(sim.day, where, outcome)
	sim.marcha._send_to(person, sim.home_position)
	person.state = Inhabitant.State.VOLVIENDO


## Cuanto se para uno a mirar cada tramo, en horas.
##
## Media hora. Con las cuatro horas que dura una batida salen ocho tramos y unos
## dos kilometros de vuelta, que es reconocer; sorteando tramo en cuanto se
## llega salian cincuenta y once kilometros, que es correr.
##
## Pendiente de playtest: subirlo hace la batida mas quieta y menos ancha,
## bajarlo la vuelve otra vez una carrera.
const MIRAR_EL_SITIO := 0.5


## El siguiente tramo de la batida.
##
## Las direcciones se reparten en abanico alrededor del punto en vez de
## sortearse: sorteadas salian tres tramos seguidos hacia el mismo lado, que
## parece que la persona no sabe lo que hace. En abanico se ve que esta
## rodeando el sitio.
func _next_survey_leg(person: Inhabitant) -> void:
	# Cuanto se abre la vuelta. Reconocer monte nuevo es abrirse; batir UN
	# PARAJE es lo contrario, y era el segundo motivo de que los batidores
	# parecieran no hacer nada: se les mandaba a 260 m del centro -el radio de
	# reconocer comarca- estando el paraje a 120 de radio, asi que la tarde se
	# iba en salirse del sitio al que habian ido a mirar y volver a entrar.
	#
	# Medido con `BatidaProbe`: 48 % del tiempo andando contra 13 %
	# reconociendo, y 0,6 hallazgos por batidor y jornada.
	# Y EL CENTRO DE LA VUELTA ES EL PARAJE, NO DONDE SE ESTA.
	#
	# Se sorteaba alrededor de `work_centre`, y `work_centre` se mueve con la
	# persona tramo a tramo: eso no es batir un sitio, es un paseo aleatorio sin
	# correa, y se va. Medido con `BatidaProbe`: un batidor reconociendo a 791 m
	# del abrigo con su paraje pendiente a CUARENTA Y SEIS, y dos jornadas
	# seguidas con «encima: NO», o sea fuera de todo paraje. El alcance de una
	# batida es [BATIDA_RADIUS]: 380 m.
	#
	# El sitio se toma de la chapa apuntada —ver [Inhabitant.paraje_batido]— y
	# no de `_paraje_at`, que con las huellas solapadas devuelve el vecino mas
	# antiguo y no aquel al que se vino.
	var vuelta := SettlementSim.SURVEY_RADIUS
	var centro := person.work_centre
	var aqui: Paraje = null
	if not person.paraje_batido.is_empty() and sim.parajes != null:
		aqui = sim.parajes.por_id(person.paraje_batido)
	if aqui == null:
		aqui = sim._paraje_at(person.work_centre)
	if aqui != null:
		vuelta = aqui.extent
		centro = aqui.position

	# Mas intentos cuando hay sitio al que ceñirse: cada uno puede caerse por
	# quedar fuera de la huella, y con tres se agotaban antes de dar con uno
	# bueno; entonces caia al salto corto de abajo y el batidor se quedaba
	# temblando en el borde.
	var intentos := 8 if aqui != null else 3
	for attempt in range(intentos):
		# Al trozo de alrededor que menos se conozca: reconocer es rellenar
		# los huecos del mapa, no dar vueltas por lo ya visto
		var candidate := _least_known_around(centro, vuelta * 0.45, vuelta, person)

		# Y que no se salga del sitio: si hay paraje, el tramo es SUYO. Sin
		# esto la vuelta se centra bien pero el borde sigue mordiendo monte de
		# fuera, y de tramo en tramo se acaba en el valle de al lado.
		if aqui != null and aqui.huella != null and not aqui.huella.vacia() \
				and not aqui.contains(candidate):
			continue

		# El camino se traza de nuevo. Es lo que suelta el hito viejo que
		# tenia a la persona clavada donde llego: `next_waypoint` devuelve el
		# hito ANTES que el destino, asi que cambiar el destino no bastaba.
		person.route = PackedVector3Array()
		person.route_step = 0
		person.forage_target = candidate
		sim.marcha._send_to(person, candidate)
		if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
			# No se ha mirado: se deja el tramo para el cuadro siguiente en
			# vez de sortear otro. Ver [Marcha.Traza].
			return

		# Que HAYA camino no basta: batiendo un paraje pegado al agua, la
		# otra orilla está comunicada por un vado lejano y el tramo de
		# doscientos metros se convierte en uno de mil contra el río. Ver
		# [Marcha.merece_el_camino].
		if sim.marcha.merece_el_camino(person, candidate) \
				or candidate.distance_to(person.position) < sim.arrive_radius * 2.0:
			return

	# Si no ha salido ningun tramo bueno pero se estaba batiendo un sitio, se
	# vuelve A SU CENTRO: es lo unico que se sabe seguro que esta dentro y al
	# alcance, y bate el nucleo en vez de dejar a la persona en el borde.
	if aqui != null:
		person.route = PackedVector3Array()
		person.route_step = 0
		person.forage_target = aqui.position
		sim.marcha._send_to(person, aqui.position)
		if sim.marcha.merece_el_camino(person, aqui.position):
			return

	# Si de verdad no hay por donde salir, se bate lo que se tenga a mano en
	# vez de quedarse mirando la nada. EN ABANICO Y CON CAMINO, las dos cosas.
	#
	# Esto sorteaba UN punto al azar y lo metia en `person.target` a pelo, sin
	# pedir ruta. Dos averias en dos lineas: la persona se quedaba andando en
	# linea recta hacia un punto que nadie habia comprobado -y si de por medio
	# habia cauce, contra el rio-, y como la ruta seguia vacia, el tramo se
	# volvia a sortear AL TICK SIGUIENTE. Eso es el paseo aleatorio que se ve
	# en los rastros como una vereda recorrida en bucle.
	#
	# Ahora se prueban ocho rumbos repartidos y se coge el primero que tenga
	# camino de verdad; si ninguno lo tiene, es que aqui no hay nada que batir
	# y se da la vuelta a casa, que es una respuesta y no un temblor.
	var salida := sim._rng.randf() * TAU
	for i in range(8):
		var angle := salida + float(i) / 8.0 * TAU
		var near := person.position + Vector3(
			cos(angle) * sim.arrive_radius * 2.5, 0.0,
			sin(angle) * sim.arrive_radius * 2.5)
		if sim._terrain:
			near.y = sim._terrain.get_height_at(near)
		person.route = PackedVector3Array()
		person.route_step = 0
		sim.marcha._send_to(person, near)
		if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
			return
		if not person.route.is_empty():
			person.forage_target = near
			return

	# Ni eso: se acaba el reconocimiento y a casa.
	_finish_survey(person)


## Cuanto dura un sim.reconocimiento, segun de que salida sea.
##
## La batida es radio corto y vuelve a dormir a casa, asi que no le caben
## nueve horas de sim.reconocimiento: se le acababa el dia a medio batir, no
## terminaba nunca y por eso no aparecia ni una sola batida en los rastros.
## Media jornada es lo que de verdad cabe entre salir despues del desayuno y
## volver antes de que oscurezca.
func _survey_hours_for(person: Inhabitant) -> float:
	if person.current_speciality == Profession.Speciality.BATIDA:
		return SettlementSim.SURVEY_HOURS * 0.45

	# Abrir monte nuevo es asomarse a ver que hay, no trabajar a fondo un
	# paraje que ya se conoce y del que quedan incognitas por resolver
	# -eso es justo lo que distingue a la batida-. Exigir la jornada
	# entera para las dos cosas por igual era pedirle a una expedicion el
	# mismo tiempo por mirar de pasada que por investigar en detalle, y
	# entre eso y la logistica de varios dias fuera, terminar de reconocer
	# terreno nuevo se volvia raro: casi ninguna salida llegaba a tiempo.
	if sim._paraje_at(person.work_centre) == null:
		return SettlementSim.SURVEY_HOURS * 0.5
	return SettlementSim.SURVEY_HOURS


