class_name Marcha
extends RefCounted
## Andar: trazar el camino, seguirlo paso a paso y vigilar a quien no avanza.
##
## Sale de `SettlementSim` la ultima de todas, y por eso: estaba repartida en
## DOCE trozos por el fichero y es el codigo del que depende que nadie se quede
## clavado contra una pared. Se junto primero en un commit que no cambio una
## letra -ver ARQUITECTURA §3, regla 2- y solo despues se corto, ya de una
## pieza.
##
## Lo que hay aqui es la capa de MOVIMIENTO, y son cuatro cosas encadenadas:
##
##   - TRAZAR: `_send_to` pide camino a [Wayfinder] sobre la rejilla, y se
##     guarda por carril para no repetir el A* de los quince.
##   - ANDAR: `_tick_step` da el paso de cada tick -velocidad de Tobler segun
##     la pendiente EN EL SENTIDO DE LA MARCHA, el suelo y la carga-.
##   - REPARTIRSE: `_lane_shift` y `_lane_pace` dan a cada uno su carril, para
##     que una cuadrilla no vaya en fila india por la misma linea.
##   - VIGILAR: `_watch_for_stuck` y compania. Un atasco es que HAY camino, el
##     suelo deja pasar, y aun asi no se anda; eso es una averia y el objetivo
##     es cero. Distinto de la renuncia, que es la salida de emergencia.
##
## El coste de pedirle las cosas al simulador por `sim.` esta medido y es el
## 0,06 % del fotograma -`tools/CosteIndireccion.gd`-. Lo que si se paga es que
## esos accesos ya no los comprueba el compilador: ver
## `tools/LlamadasHuerfanas.gd`.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Cuanto se tarda en andar una distancia, en HORAS DE JUEGO.
##
## `walk_speed` va en unidades por segundo REAL, y una hora de juego son
## `seconds_per_day / 24` segundos reales: sin esa conversion el viaje sale en
## unas unidades que no son horas. Estaba escrito a mano en `_rank_known_spots`
## y hace falta en dos sitios mas -decidir cuando emprender la vuelta y si se
## llega antes de que anochezca-, asi que vive aqui.
##
## Es una estimacion EN LINEA RECTA y a paso de llano, o sea que se queda
## corta: el camino da rodeos y sube cuestas. Quien la use para decidir cuando
## dar media vuelta tiene que multiplicarla por [RODEO_DE_VUELTA]; quedarse
## corto ahi no es el lado seguro, es llegar de noche.
func hours_to_walk(metres: float) -> float:
	var per_hour := sim.walk_speed * (sim.seconds_per_day / 24.0)
	return metres / maxf(per_hour, 0.1)


## Coloca un sitio de trabajo para una actividad
## Si desde el poblado se puede llegar andando a un punto.
##
## Solo mira el trayecto recto, que es como anda la gente. No es un buscador de
## caminos: si hiciera falta rodear el rio por un vado a dos kilometros, este
## metodo dice que no se llega, y esta bien que lo diga, porque a efectos de
## una jornada de trabajo no se llega.
##
## El ultimo tramo, el del radio de llegada, no se comprueba: a un sim.tajo de
## pesca se llega ESTANDO en la orilla, no metiendose en el cauce.
func can_reach(world_position: Vector3, margin: float = -1.0) -> bool:
	if sim._terrain == null:
		return true

	var stop_short: float = sim.arrive_radius if margin < 0.0 else margin
	var to_target := world_position - sim.home_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stop_short:
		return true

	var stop := sim.home_position + to_target.normalized() * (distance - stop_short)
	# Las dos cosas que cortan el paso: el agua honda y el cortado. Mirar solo
	# el agua dejaba asignar tajos detras de una pared, y la gente salia hacia
	# ellos para quedarse atascada.
	if not sim._terrain.path_is_passable(sim.home_position, stop, sim.has_boat, sim.has_bridge):
		return false

	# Y lo que de verdad manda: la REJILLA, que es quien traza los caminos.
	#
	# La linea recta de arriba dice si el terreno deja pasar por el medio; no
	# dice si hay camino andable, que es otra cosa. Medido en el sitio 56:
	# `can_reach` daba verdadero para el sim.tajo de pesca y la rejilla decia
	# `connected(casa, rio) = false` —cuatro zonas, el abrigo en una y el rio
	# en otra—. Se plantaba un sim.tajo al que nadie podia llegar, la gente salia
	# a por el, no habia ruta, y se quedaba dando vueltas por el monte sin
	# traer un solo pez. Preguntar dos cosas distintas y creerse la que no
	# manda es como se planta un sitio de trabajo imposible.
	return _navgrid().connected(sim.home_position, world_position)


## El paso: seguir el camino trazado, sortear lo que no se pisa y girar la cara
## hacia donde se anda.
##
## Sale de `_tick_person` por lo mismo que la rutina: son cien lineas de una
## cosa sola, y mezcladas con el horario no se leia ninguna de las dos.
func _tick_step(person: Inhabitant, index: int, hours: float,
		delta: float) -> void:
	# Movimiento
	if person.state == Inhabitant.State.YENDO \
			or person.state == Inhabitant.State.VOLVIENDO \
			or person.state == Inhabitant.State.BUSCANDO \
			or person.state == Inhabitant.State.TRABAJANDO 			or person.state == Inhabitant.State.RECONOCIENDO:
		# La ruta agotada sin haber llegado NO es via libre para tirar en
		# linea recta: es justamente cuando hay que volver a trazar. Antes
		# `next_waypoint` caia al destino y la persona salia derecha a
		# seiscientos metros sin plan, que es el atasco «no avanza por el
		# camino trazado».
		#
		# Y SI SIGUE SIN HABER CAMINO, NO SE ANDA.
		#
		# Volver a trazar no siempre da ruta -el destino se ha vuelto
		# inalcanzable, o la traza fallo-, y aqui se seguia adelante igual:
		# `next_waypoint` devuelve el destino cuando la ruta esta vacia, asi
		# que la persona salia DERECHA hacia el, cruzara lo que cruzara. Es
		# como se llega a la orilla de un rio que no se pasa.
		#
		# Medido con `AtascoProbe` en el sitio 56: el 22,9 % de los fotogramas
		# andando se andaban asi, sin un camino debajo. Casi un cuarto del
		# movimiento de la banda no lo habia trazado nadie.
		if person.route_step >= person.route.size() \
				and person.position.distance_to(person.target) > sim.arrive_radius * 2.0:
			_send_to(person, person.target)
			if person.route_step >= person.route.size():
				# Sin presupuesto es que HOY no toca buscar, no que no haya
				# camino: se espera al cuadro siguiente y ya esta.
				#
				# Y soltar el destino es cosa de quien VIAJA. Quien busca una
				# pieza o trabaja una mancha tiene su propia forma de darse por
				# vencido -el rastro se pierde, la mata se acaba-, y meterle
				# aqui un cambio de estado seria decidir por ella. Lo que si
				# vale para todos es no andar sin camino.
				var viajando := person.state == Inhabitant.State.YENDO \
					or person.state == Inhabitant.State.VOLVIENDO \
					or person.state == Inhabitant.State.RECONOCIENDO
				if viajando and ultima_traza == Traza.IMPOSIBLE:
					_sin_rumbo(person)
				return

		var to_target := person.next_waypoint() - person.position
		to_target.y = 0.0
		# Al alcanzar un hito del camino se pasa al siguiente: asi se rodea
		# el canchal en vez de cruzarlo, que es donde uno se rompe un tobillo
		# UN HITO SE DA POR ALCANZADO SI SE HA REBASADO, no solo si se esta
		# dentro de su radio: a velocidad de persona una zancada puede medir
		# mas que el radio de llegada, y entonces se pasa por encima del hito
		# sin llegar a estar nunca dentro. El hito no se marcaba, `to_target`
		# seguia apuntando hacia atras y la persona se quedaba oscilando.
		var alcance := maxf(sim.arrive_radius, sim.walk_speed * delta)
		if person.route_step < person.route.size() \
				and to_target.length() < alcance:
			person.route_step += 1
			to_target = person.next_waypoint() - person.position
			to_target.y = 0.0
		# Cada uno por su carril. El paso de hito se mide sobre el hito de verdad
		# -arriba-, y el carril sólo tuerce hacia dónde se camina: si desviara
		# también la cuenta de hitos, el camino se recorrería torcido.
		#
		# EL EJE SE GUARDA. El carril aparta hasta dos metros y medio de la
		# línea que el trazado ha comprobado, y esa línea es la única de la
		# que hay palabra: pegada a un cortado o a la orilla, el desvío mete
		# a la persona en la celda de al lado, que está cerrada. Entonces se
		# la manda a RODEAR algo que no le estorbaba —el eje estaba libre—,
		# y eso son pasos de lado, tiempo y un rastro que no se entiende.
		#
		# Medido con `AtascoProbe`: 5.741 pasos cortados en ocho jornadas con
		# el carril puesto a ciegas. El carril es un apaño de presentación
		# —que no vayan en fila india— y no puede mandar sobre el trazado.
		var eje := to_target
		to_target = _lane_shift(person, to_target)
		if to_target.length() > 0.5:
			var direction := to_target.normalized()

			# La velocidad NO es constante. Sale de la funcion de sim.marcha de
			# Tobler segun la pendiente EN EL SENTIDO DE LA MARCHA -no la del
			# terreno a secas, porque subir y bajar no cuestan lo mismo-, del
			# suelo que se pisa y de lo que se lleva encima.
			var pace := _terrain_speed(person, direction, hours) \
				* sim.weather.pace_factor() * _lane_pace(person) \
				* sim.caceria._hunt_pace(person)
			# Sin pasarse del DESTINO. Del hito si se pasa: los hitos estan a
			# unos pocos metros y recortar el paso en cada uno era lo que dejaba
			# el avance en la sexta parte de lo que tocaba.
			var recorrido := pace * delta
			var queda := person.position.distance_to(person.target)
			var step := direction * minf(recorrido, maxf(queda, sim.arrive_radius))

			# El agua es un obstaculo, no una textura. Si el paso siguiente
			# entra en algo que no se puede cruzar, se bordea la orilla en vez
			# de meterse: se prueban las dos perpendiculares y se toma la que
			# acerque mas al destino. No es un buscador de caminos, pero acaba
			# con lo que se veia antes, que era gente andando sobre el rio.
			# LO QUE DEL PASO SE PUEDE ANDAR, y no todo o nada.
			#
			# A velocidad de persona un paso mide varios metros, asi que topar
			# con el agua a mitad de paso pasa a cada rato. Descartando el paso
			# entero, la gente se quedaba CLAVADA: medido, el 90 % del tiempo
			# parada y salidas de siete horas con cero metros andados. Se anda
			# hasta el borde, que es lo que hace cualquiera, y desde ahi se
			# busca por donde rodear.
			var libre := _avance_libre(person.position, step)

			# Y SI LO QUE ESTORBA ES EL CARRIL, SE VUELVE AL EJE.
			#
			# Antes de dar nada por bloqueado se prueba la línea del trazado
			# sin desviar. Rodear es caro y se reserva para lo que estorba de
			# verdad; que a uno no le quepa su carril no es que no haya paso.
			if libre.length() <= CATA_DEL_PASO * 0.5 and eje.length() > 0.5:
				var derecho := eje.normalized() * step.length()
				var libre_eje := _avance_libre(person.position, derecho)
				if libre_eje.length() > CATA_DEL_PASO * 0.5:
					step = derecho
					libre = libre_eje

			if libre.length() > CATA_DEL_PASO * 0.5:
				step = libre
				person.pasos_de_lado = 0
			else:
				# Ni el primer tramo: hay que rodear. El paso de lado mide LO
				# MISMO que el que se iba a dar, no la zancada entera a
				# velocidad maxima -con la velocidad de verdad, eso eran quince
				# metros de salto lateral que tampoco cabian en ningun sitio.
				var side := Vector3(-direction.z, 0.0, direction.x) * step.length()
				var left := person.position + side
				var right := person.position - side
				var left_ok := _avance_libre(person.position, side).length() \
					> step.length() * 0.9
				var right_ok := _avance_libre(person.position, -side).length() \
					> step.length() * 0.9

				# EL CAMINO PROMETIO UN PASO QUE NO EXISTE.
				#
				# Aqui, y no en cualquier roce con el agua: esto es que NI EL
				# PRIMER TRAMO del paso se puede andar, o sea que hay que
				# rodear. Es LA cifra que dice si el trazado y el que anda estan
				# de acuerdo sobre el agua, porque cada una de estas es una
				# persona plantada en una orilla donde la rejilla le habia dicho
				# que se pasa. De ahi sale el ovillo de la ventana de rastros.
				#
				# Y se apunta CUAL DE LOS DOS lo corta, porque son averias
				# distintas: el agua es que el vado no esta donde la rejilla
				# dice, y la celda cerrada es que el camino trazado roza algo
				# por lo que no se pasa -un recorte de escalera demasiado
				# alegre, o una ruta pegada al cortado-.
				pasos_cortados += 1
				var cata := person.position + direction * CATA_DEL_PASO
				var rejilla := _navgrid()
				if rejilla.is_ready() \
					and rejilla.cost[rejilla.cell_of(cata)] <= Navgrid.BLOCKED:
					pasos_cortados_celda += 1
				else:
					pasos_cortados_agua += 1
				# Y EL RODEO DE ORILLA TIENE UN TOPE.
				#
				# Este apaño es para bordear un charco: dos o tres pasos de
				# lado y se sigue. Sin tope se convierte en lo contrario de lo
				# que parece: como el paso de lado SÍ mueve a la persona, la
				# cuenta de bloqueos se reinicia cada cuadro y no salta nunca
				# el replanteo. La persona camina la orilla de un lado para
				# otro durante horas —anda muchísimo y no se acerca nada— y de
				# ahí no la saca más que la vigilancia de atascos, dos horas de
				# juego después.
				#
				# Es el ovillo pegado al agua de la ventana de rastros, y el
				# motivo de que se leyera como «no avanza por el camino
				# trazado»: el hito estaba perfectamente pisable, al otro lado.
				#
				# Pasado el tope se deja de barrer y se pide camino, que es lo
				# que de verdad sabe por dónde se cruza.
				var barriendo := person.pasos_de_lado >= SettlementSim.RODEOS_DE_ORILLA
				if not barriendo and left_ok and (not right_ok
						or left.distance_to(person.target) < right.distance_to(person.target)):
					step = side
					person.pasos_de_lado += 1
				elif not barriendo and right_ok:
					step = -side
					person.pasos_de_lado += 1
				else:
					# Ni por un lado ni por otro. Antes se paraba y ya: el
					# esquive de orilla es un apano para bordear un charco, no
					# un buscador de caminos, y contra un cortado deja a la
					# persona empujando la roca hasta que la noche la manda a
					# casa.
					#
					# Ahora se pide camino OTRA VEZ desde donde esta. La
					# rejilla sabe por donde se pasa; el esquive no.
					step = Vector3.ZERO
					person.blocked_steps += 1
					if person.blocked_steps > SettlementSim.BLOCKED_BEFORE_REPLAN:
						person.blocked_steps = 0
						person.blocked_replans += 1
						# Camino nuevo, rodeo de orilla nuevo: el tope es por
						# tramo, no de por vida. Ver [SettlementSim.RODEOS_DE_ORILLA].
						person.pasos_de_lado = 0
						# Y SE APUNTA QUE POR AHI NO SE PASA.
						#
						# Es la diferencia entre tropezar una vez y tropezar
						# todos los dias. La rejilla habia abierto esta celda
						# por un vado que sobre el terreno no existe; sin
						# cerrarla, mañana se traza la misma ruta por el mismo
						# sitio y se planta la misma gente en la misma orilla.
						# Ver [Navgrid.cerrar].
						# SOLO SI LO QUE ESTORBA ES AGUA.
						#
						# Es para lo que esta: la rejilla abre celdas por vados
						# que sobre el terreno no existen. Un cantil no: la
						# rejilla ya lo mide con la pendiente, y cerrar celda
						# cada vez que alguien roza una peña iria troceando el
						# valle hasta dejar la mitad incomunicada. Medido con
						# el juego delante: diez cierres en dos jornadas, y no
						# todos eran agua.
						var delante := person.position + direction 							* Navgrid.CELL * 0.5
						var estorba_el_agua := sim._terrain != null 							and sim._terrain.crossing_difficulty_at(delante) > Hydrography.ROZA_EL_AGUA
						if estorba_el_agua and _navgrid().cerrar(delante):
							forget_routes()
							sim._note(Chronicle.Kind.TIERRA,
								"Por %s no se pasa: la banda lo tacha de sus "
									% sim.parajes.place_name(delante,
										sim.home_position)
								+ "caminos.", 0)
						var goal := person.target
						person.route = PackedVector3Array()
						person.route_step = 0
						# Y A LA TERCERA SE DEJA. Replanificar contra la misma
						# pared no la abre: la rejilla mide celdas de cuarenta
						# metros y un cortado más estrecho que eso no existe
						# para ella, así que devuelve la misma ruta imposible
						# una y otra vez. Medido en el sitio 56: la cuadrilla de
						# caza menor llegaba todos los días al mismo punto
						# —pendiente 1,4, paso al 2 % de lo normal— y se pasaba
						# la tarde replanificando hasta que la vigilancia de
						# atascos la mandaba a casa. Siete salidas seguidas
						# cerradas con «atascado».
						#
						# Dándolo por inalcanzable, el sim.reparto de mañana lo
						# manda a otro sim.tajo, que es lo que tenía que pasar.
						if person.blocked_replans >= SettlementSim.BLOCKED_REPLANS:
							person.blocked_replans = 0
							person.unreachable = goal
							_give_up_on(person, goal)
						else:
							_send_to(person, goal)

			# UN PASO SIN NINGUN CAMINO DEBAJO. Tiene que quedarse en cero: es
			# el tiro en linea recta que llevaba a la gente contra el rio.
			#
			# Se pregunta por la ruta VACIA y no por la ruta AGOTADA, que son
			# cosas distintas: agotarla es haber llegado al final del camino
			# —lo normal— y los ultimos metros hasta el destino se andan
			# derechos a proposito. Lo que no puede pasar es andar sin haber
			# tenido camino nunca.
			if step.length() > 0.01 and person.route.is_empty() \
				and person.position.distance_to(person.target) > sim.arrive_radius * 2.0:
				pasos_sin_camino += 1
			person.position += step
			person.note_step(step.length(), sim.home_position)
			if step.length() > 0.01:
				person.blocked_steps = 0
				person.blocked_replans = 0
				# Sólo un paso con recorrido real gira a la persona; uno de
				# longitud cero -parada, bloqueo- no dice hacia dónde mira.
				#
				# Y sólo si hay dónde apuntarla. `_headings` se llena al crear
				# la banda, al lado del cuerpo de cada uno: un montaje de
				# prueba que mete gente en `people` a mano no tiene cuerpos, y
				# escribir en el índice 0 de un array vacío reventaba la prueba
				# ANTES de su primer assert. Eso no falla: PASA. Mirar hacia
				# dónde se anda es cosa de la vista, así que sin cuerpo no hay
				# nada que girar.
				if index < sim._headings.size():
					sim._headings[index] = atan2(step.x, step.z)
			person.position.y = sim._terrain.get_height_at(person.position)
			# Andar cansa. Hace falta para que la batida tenga final: sin esto
			# el explorador nunca acumulaba fatiga y no volvia jamas.
			person.fatigue = clampf(
				person.fatigue + hours * 2.6 * person.fatigue_factor(), 0.0, 100.0)


## Alguien se ha quedado sin camino a donde iba, andando.
##
## No es un atasco -no se ha perdido el dia peleandose con nada- ni una
## renuncia por haber topado con el terreno: es que el destino ha dejado de
## tener ruta mientras se iba hacia el. Lo que corresponde es soltarlo y que el
## reparto le de otro sitio, que es lo que habria pasado si se hubiera sabido
## antes de salir.
##
## Se cuenta aparte porque dice una cosa distinta de las demas: si esto sube,
## quien elige los destinos esta mandando gente a sitios sin comprobar el
## camino. Ver [SettlementSim.SIN_RUMBO].
func _sin_rumbo(person: Inhabitant) -> void:
	var goal := person.target
	sim.stuck_tally[SettlementSim.SIN_RUMBO] = int(
		sim.stuck_tally.get(SettlementSim.SIN_RUMBO, 0)) + 1
	_record_stuck(person, SettlementSim.SIN_RUMBO)
	person.route = PackedVector3Array()
	person.route_step = 0
	person.survey_hours = 0.0
	person.horas_en_el_tramo = 0.0

	# DE CASA NO SE RENUNCIA NUNCA.
	#
	# Volver es la salida de emergencia de todo lo demas: si el abrigo se
	# apunta como imposible, `_send_to` deja de trazarle ruta y la persona se
	# queda en el monte para siempre. Y ademas casi nunca es verdad —el trozo
	# de casa se abre a la fuerza, ver [Navgrid.open_around_home]—: lo que
	# suele pasar es que se ha quedado en un rincon del que hay que salir, y de
	# eso ya se encarga la vigilancia de plantados.
	if Traversal.en_llano(goal, sim.home_position) <= SettlementSim.SALIDA_DE_CASA:
		person.state = Inhabitant.State.OCIOSO
		return

	person.unreachable = goal
	if not _given_up_on(person, goal):
		person.given_up.append(goal)
	if not person.journey.is_empty():
		person.end_journey(sim.day,
			sim.parajes.place_name(person.position, sim.home_position),
			"se quedo sin camino: se le dara otro sitio")
	person.state = Inhabitant.State.OCIOSO


## Como acabo la ultima llamada a [_send_to].
##
## ESTO ES LO QUE FALTABA, Y COSTABA CARO.
##
## `_send_to` deja la ruta vacia por CUATRO motivos que no significan lo mismo
## -no hay camino, ya se sabia imposible, no se ha buscado por presupuesto, o
## se ha buscado y no ha salido- y quien llamaba solo veia `route.is_empty()`.
## Los cuatro se leian como el primero.
##
## De ahi salia el fallo mas gordo que quedaba, y esta medido: `_send_to_work`
## prueba VARIOS tajos, cada uno cuesta una busqueda, y el presupuesto es de
## unos pocos nodos por cuadro. Agotado el presupuesto, los candidatos que
## quedaban volvian con la ruta vacia -sin haberse mirado siquiera- y el
## reparto lo leia como «a ninguno de estos tajos hay camino»: se anotaba el
## atasco, se marcaba la actividad como inalcanzable y la persona se quedaba
## ociosa la jornada entera. Medido en el sitio 56, jornada 1: seis personas
## con «no hay camino hasta ningun tajo» a 211 m de casa, con la rejilla
## diciendo `zona 0 -> 0` y todo el suelo pisable.
##
## No se llegaba a estrellar contra nada: se decidia que no habia camino sin
## haberlo buscado.
enum Traza {
	TRAZADO,          ## Hay ruta -nueva, guardada, o la que ya llevaba-.
	IMPOSIBLE,        ## No hay camino: otra zona, o la busqueda no lo encontro.
	SIN_PRESUPUESTO,  ## NO SE HA MIRADO. No dice nada del camino.
}

## Como acabo la ultima traza. Se mira JUNTO a la ruta, nunca en su lugar.
var ultima_traza: Traza = Traza.TRAZADO

## Pasos dados SIN un camino debajo. Tiene que quedarse en cero.
##
## `next_waypoint` devuelve el destino cuando la ruta esta vacia, asi que
## andar sin camino es andar EN LINEA RECTA hacia el, cruzara lo que
## cruzara. No se mide desde fuera —desde fuera, quien acaba de gastar su
## ruta y quien nunca la tuvo se ven igual—, asi que se cuenta aqui.
var pasos_sin_camino: int = 0

## Pasos que el terreno cortó a pesar de haber camino trazado.
##
## Es la cifra que dice si el trazado y el andador estan de acuerdo sobre el
## agua: cada uno es alguien llegando a una orilla donde la rejilla le habia
## dicho que se pasa. Lo que sale de ahi es el ovillo de la ventana de
## rastros. Ver [Navgrid.vado].
var pasos_cortados: int = 0

## De esos, los que corta una celda por la que no se pasa.
var pasos_cortados_celda: int = 0

## Y los que corta el agua.
var pasos_cortados_agua: int = 0

## Caminos entregados que NO merecian andarse, y de cuantos en total.
##
## Es la queja medida: «en ocasiones multiplica la distancia en linea recta
## por muchas veces». Se mide con [rodeo_aceptable], que es la misma vara con
## la que se decide si un sitio esta al alcance.
var rodeos_malos: int = 0
var rodeos_mirados: int = 0


## Apunta si el camino que se acaba de entregar merecia andarse.
func _apuntar_el_rodeo(person: Inhabitant, destino: Vector3) -> void:
	if person.route.is_empty():
		return
	rodeos_mirados += 1
	if not rodeo_aceptable(Traversal.en_llano(person.position, destino),
		largo_de(person.position, person.route)):
		rodeos_malos += 1


## Se abandona un destino al que no se consigue llegar.
##
## No es lo mismo que atascarse: aquí no se ha perdido el día ni hace falta
## contarlo en la crónica. Es «por ahí no se pasa», que es una cosa que se
## aprende andando, y lo que corresponde es probar otro sitio.
func _give_up_on(person: Inhabitant, goal: Vector3) -> void:
	person.route = PackedVector3Array()
	person.route_step = 0
	person.survey_hours = 0.0
	# Lo que se descarta es ESE SITIO, no el oficio entero. Marcando la
	# actividad como inalcanzable se dejaría de cazar en todo el valle por un
	# cortado de cincuenta metros; lo que hay que hacer es ir al siguiente
	# cotarro. De eso se encarga `_best_known_spot`, que ya no elige lo que
	# esta persona tiene apuntado como imposible.
	person.state = Inhabitant.State.OCIOSO
	if not _given_up_on(person, goal):
		person.given_up.append(goal)

	# La salida se CIERRA, y se cierra diciendo la verdad. Dejarla abierta es
	# el fallo que ya está avisado en `end_journey`: una salida que no se cierra
	# sigue sumando kilómetros de los días siguientes, y además el jugador no ve
	# nunca en los rastros qué pasó con la jornada.
	if not person.journey.is_empty():
		person.end_journey(sim.day,
			sim.parajes.place_name(person.position, sim.home_position),
			"por ahi no se pasa: se probo otro sitio")

	_record_stuck(person, "por ahi no se pasa: se prueba otro sitio")
	sim.stuck_tally[SettlementSim.RENUNCIA] = int(sim.stuck_tally.get(SettlementSim.RENUNCIA, 0)) + 1


## Si esta persona ya se dio hoy por vencida con este sitio.
func _given_up_on(person: Inhabitant, point: Vector3) -> bool:
	for gone: Vector3 in person.given_up:
		if gone.distance_to(point) < SettlementSim.UNREACHABLE_SLACK:
			return true
	return false


## El mejor paraje que la banda CONOCE para esa actividad y que este a tiro.
## Devuelve ZERO si no conoce ninguno: entonces toca prospectar.
## Tuerce la sim.marcha hacia el carril de esta persona.
##
## Mismo sim.reparto por ángulo áureo que usa `_best_known_spot` para el sitio de
## trabajo, y por lo mismo: es estable entre jornadas -cada cual va siempre por
## su lado del camino- y no repite valor en un grupo pequeño.
##
## El carril se deshace al llegar. Si el desvío siguiera vivo en los últimos
## metros nadie tocaría nunca su destino: se quedarían dando vueltas alrededor a
## dos metros y medio, que es peor que el solape.
## El paso de esta persona, en fracción del paso medio.
##
## Otro irracional distinto del que reparte el carril, y a propósito: con el
## mismo, quien comparte carril compartiría también paso y los dos apaños se
## anularían justo en el caso que vienen a arreglar.
func _lane_pace(person: Inhabitant) -> float:
	return 1.0 + (fmod(float(person.id) * 0.7548776662, 1.0) - 0.5) * 2.0 * SettlementSim.LANE_PACE


func _lane_shift(person: Inhabitant, to_target: Vector3) -> Vector3:
	var reach := to_target.length()
	if reach < 0.5:
		return to_target
	var fade := clampf(person.position.distance_to(person.target)
		/ (sim.arrive_radius * 3.0), 0.0, 1.0)
	if fade < 0.01:
		return to_target
	# EN EL AGUA NO HAY CARRILES. Se cruza por el vado, en fila.
	#
	# El carril aparta a cada uno hasta dos metros y medio del eje, y el eje es
	# justo la linea que la rejilla ha comprobado que se vadea -el camino va de
	# centro a centro de celda, o sea por la fila o la columna de en medio, que
	# es donde se mide el vado, ver [Navgrid._vado_de_verdad]-. Dos metros y
	# medio a un lado de un vado estrecho es el rio, y ahi el andador se planta:
	# es el ovillo pegado al agua que se veia en los rastros, y con varios a la
	# vez porque cada carril daba en un sitio distinto de la misma orilla.
	#
	# Y SE DESHACE ANTES DE ENTRAR, no al estar ya dentro. Preguntando por el
	# punto que se pisa, el carril seguia vivo durante toda la aproximacion y
	# se llegaba a la orilla dos metros y medio al lado del vado: justo donde
	# no se pasa. Se pregunta por la CELDA -la de aqui y la del hito al que se
	# va- que es la misma unidad en la que la rejilla mide el vado.
	if sim._terrain != null:
		var grid := _navgrid()
		if grid.moja(person.position) or grid.moja(person.next_waypoint()):
			return to_target

	var lane := (fmod(float(person.id) * 0.618, 1.0) - 0.5) * 2.0 * SettlementSim.LANE_SPREAD
	var side := Vector3(-to_target.z, 0.0, to_target.x) / reach
	return to_target + side * lane * fade


## Velocidad de una persona aqui y ahora, en unidades de mundo por segundo.
##
## `hours` solo hace falta para entrenar NATACION si se cruza marisma o vado;
## si algun dia esto se llama fuera de `_tick_person` sin ese dato, 0.0 lo
## deja sin efecto.
func _terrain_speed(person: Inhabitant, direction: Vector3, hours: float = 0.0) -> float:
	if sim._terrain == null:
		return sim.walk_speed

	# Pendiente en el sentido de la sim.marcha, medida sobre una zancada larga: a
	# la distancia de un vertice manda el ruido del terreno, no la ladera
	var probe := 12.0
	var ahead := person.position + direction * probe
	var rise := sim._terrain.get_height_at(ahead) - person.position.y
	var slope := rise / probe

	# Con el encharcamiento de la estacion: en enero hay barro donde en agosto
	# habia prado. Ver [Traversal.classify_ground] y [Temporada].
	var ground := Traversal.classify_ground(
		absf(slope), sim._terrain.crossing_difficulty_at(person.position),
		sim.temporada.encharcamiento() if sim.temporada != null else 0.0)
	var load := clampf(person.carrying / maxf(sim.carry_capacity, 0.001), 0.0, 1.0)

	# La curva de Tobler da km/h; aqui interesa la PROPORCION respecto al llano
	# de vacio, para no tocar la escala de tiempo que ya estaba calibrada.
	#
	# Y sale de [Traversal.pace_fraction] y no de una division escrita aqui,
	# porque es LA MISMA cuenta que hace la rejilla al costear una celda
	# -ver [Navgrid._measure]-. Estaban las dos escritas por separado y no
	# decian lo mismo: el trazado se olvidaba del suelo.
	var here := Traversal.pace_fraction(slope, ground, load)

	# Y LA NIEVE, que es lo que pone el calendario encima de todo lo demas. No
	# es un tinte en el terreno: por encima de la cota se anda como por barro
	# -cada paso hay que sacar el pie- y eso es lo que cierra el monte alto en
	# invierno y baja a la banda al fondo del valle. Ver [Temporada].
	if sim.temporada != null and sim._terrain != null:
		# Contra el RANGO DE VERDAD del relieve. Ver
		# [TerrainGenerator.altura_relativa]: dividiendo entre `max_height` -que
		# con un DEM cargado se queda en su valor por defecto- el abrigo salia a
		# 4,5 veces la altura del mapa y la banda andaba por nieve todo el año.
		here *= sim.temporada.freno_por_nieve(
			sim._terrain.altura_relativa(person.position))

	var swim := 1.0
	if ground == Traversal.Ground.MARISMA:
		# El barro y el agua somera es donde de verdad se nota saber nadar:
		# quien nada no lucha con cada paso igual que quien no. No abre paso
		# donde antes no lo habia -eso pide tocar la rejilla compartida, ver
		# `NATACION` en Inhabitant- pero cruza lo que ya se cruza mucho mejor.
		swim = lerpf(1.0, SettlementSim.NATACION_MARISMA_BONUS,
			person.trait_in(Inhabitant.Trait.NATACION))
		# Y se entrena AQUI, metido en el barro, no reconociendo terreno seco.
		person.train_trait(Inhabitant.Trait.NATACION, hours * SettlementSim.NATACION_TRAINING_RATE)

		# Y si es la primera vez que la banda pasa por AQUI, es un hito de
		# expedicion: una forma de cruzar el rio que antes no se sabia. La
		# batida no cuenta -no se aleja lo bastante para toparse con un vado
		# que nadie conociera ya.
		if person.current_speciality == Profession.Speciality.EXPEDICION:
			var ford_key := sim._ford_key(person.position)
			if not sim._known_fords.has(ford_key):
				sim._known_fords[ford_key] = true
				sim.reconocimiento._award_exploration_skill(person, Profession.Speciality.EXPEDICION,
					SettlementSim.FORD_MILESTONE)
				sim._note(Chronicle.Kind.HALLAZGO,
					"%s encontro por donde cruzar %s." % [person.given_name,
						sim.parajes.place_name(person.position, sim.home_position)], 1)

	# Con un suelo, y no por bondad: Tobler multiplicado por el suelo que se
	# pisa y por la carga puede bajar al 2 % del paso normal -medido en un
	# canchal de pendiente 1,4-, y a ese paso cincuenta metros son media
	# jornada. Desde fuera eso no se distingue de estar parado: es exactamente
	# lo que la vigilancia de atascos lee como «plantado», y con razón. El 12 %
	# sigue siendo ocho veces más lento que el llano, pero se ve avanzar.
	# El suelo se aplica ANTES del saber nadar, no después: puesto al final
	# aplastaba los dos casos contra el mismo número y quien sabía nadar cruzaba
	# la marisma exactamente igual que quien no. El suelo dice «nadie se queda
	# clavado»; el saber nadar sigue siendo una ventaja sobre eso.
	var ratio := maxf(here, SettlementSim.MIN_PACE)
	return sim.walk_speed * ratio * swim


## Cada cuantos metros se comprueba el suelo dentro de un mismo paso.
##
## Tres. Mirar solo el punto de llegada valia cuando un paso median centimetros;
## a velocidad de persona un paso mide varios metros y se puede saltar un arroyo
## entero sin que nadie lo mire. Es lo que antes evitaba el troceado del tick, y
## aqui sale mas barato: se trocea el PASO, que es lo que tiene geometria, no la
## jornada entera de las quince personas.
const CATA_DEL_PASO := 3.0


## Cuanto de un paso se puede andar de verdad, mirando por el camino.
##
## Devuelve el trozo mas largo del paso que esta libre; cero si ni el primer
## tramo lo esta. Mirar solo el punto de llegada valia cuando un paso median
## centimetros; a velocidad de persona mide varios metros y se saltaba un arroyo
## entero sin que nadie lo mirara.
func _avance_libre(desde: Vector3, step: Vector3) -> Vector3:
	var largo := step.length()
	if largo <= 0.001:
		return step
	var catas := maxi(int(ceil(largo / CATA_DEL_PASO)), 1)
	var bueno := 0
	for i in range(1, catas + 1):
		if not _can_step_into(desde + step * (float(i) / float(catas))):
			break
		bueno = i
	if bueno == catas:
		return step
	return step * (float(bueno) / float(catas))


## Si en este punto el agua deja pasar.
##
## ES LA PREGUNTA SOBRE EL AGUA, y se hace aqui para que la contesten igual los
## dos que tienen que estar de acuerdo: el que anda y el que elige adonde ir.
## Estaba escrita en tres sitios con tres respuestas distintas, y esa
## discrepancia es exactamente de donde salen los atascos —se elige un destino
## creyendo que no hay cauce de por medio, se traza el camino creyendo otra cosa,
## y quien anda se encuentra el rio—.
##
## Y AL CAUDAL CON EL QUE SE TRAZAN LOS CAMINOS, no al del paisaje de hoy.
##
## El rio que se ve no cambia de golpe: [Temporada] lo lleva del caudal de una
## estacion al de la siguiente en unas jornadas, para que el valle no vire a
## medianoche. La rejilla, en cambio, entra entera el dia que cambia la
## estacion y esta medida con el caudal DE DESTINO. Preguntando por el de hoy,
## durante los dias de transicion el planificador y el andador miraban dos rios
## distintos: yendo a verano —de 1,25 a 0,60— el andador ve mas agua que la que
## la rejilla dio por vadeable, asi que se traza el camino por un vado, la
## persona llega y no lo encuentra, y se pasa la tarde barriendo la orilla.
## Cuatro o cinco jornadas asi en cada cambio de estacion, cuatro veces al año.
##
## Tampoco se le suma aqui el arreglo estacional de [Hydrography.can_cross]: eso
## seria contar la estacion dos veces, una en el caudal y otra en el umbral, y
## dejaria pasar por sitios que la rejilla ha cerrado.
func agua_deja_pasar(world_position: Vector3) -> bool:
	if sim._terrain == null:
		return true
	return agua_deja_pasar_con(world_position, caudal_de_hoy())


## El caudal con el que se midio la rejilla que se esta usando.
##
## Va aparte para poder PREGUNTARLO UNA VEZ por recorrido en vez de una vez por
## cata. `_navgrid()` no es gratis -mira si el horno sirve, pide la rejilla de
## la estacion y la compara con la puesta- y `cruza_el_agua` la llamaba en cada
## cata: un candidato de doscientos sesenta metros son ochenta y siete catas, y
## ochenta y siete veces la misma pregunta. Ver la tarea 21 de
## docs/specs/LO_MISMO_MAS_DEPRISA.md.
##
## Sacarla del bucle no cambia nada: lo que `_navgrid()` hace de verdad -montar
## la rejilla, o cambiar a la de la estacion nueva- lo hacia ya en la PRIMERA
## cata, y las otras ochenta y seis eran la misma consulta sin efecto.
func caudal_de_hoy() -> float:
	var grid := _navgrid()
	return grid.built_with_caudal if grid != null and grid.is_ready() else 1.0


## Lo mismo que [agua_deja_pasar] con el caudal ya sabido.
func agua_deja_pasar_con(world_position: Vector3, caudal: float) -> bool:
	if sim._terrain == null:
		return true
	return Hydrography.can_cross(
		sim._terrain.crossing_difficulty_with(world_position, caudal),
		sim.has_boat, sim.has_bridge)


## Si se puede poner el pie en un punto concreto.
func _can_step_into(world_position: Vector3) -> bool:
	if sim._terrain == null:
		return true

	# UNA sola autoridad sobre donde se puede estar, y es la rejilla.
	#
	# Antes esto miraba el punto suelto bajo los pies mientras el planificador
	# miraba la celda entera de cuarenta metros con cinco muestras. Los dos
	# tenian razon y no se ponian de acuerdo: habia sitios donde una persona
	# podia estar tan tranquila y que para la rejilla NO EXISTIAN. Se mandaba
	# a un recolector a un sim.tajo asi, el andador le dejaba llegar, y una vez
	# alli no se le podia trazar nada -cualquier ruta empieza en una celda
	# inexistente-. De ahi salian los tres atascos: sin camino, con el camino
	# agotado, o de pie en la nada.
	#
	# Medido en la partida: Duna el dia 17 y Caro el dia 19, en el mismo punto
	# exacto, con «aqui CERRADO, el andador pasa: si».
	var grid := _navgrid()
	if grid.is_ready():
		if grid.cost[grid.cell_of(world_position)] <= Navgrid.BLOCKED:
			return false
		# Y EL AGUA, UNA VEZ MAS Y EN ESTE PUNTO. La rejilla contesta otra
		# pregunta: si la CELDA de cuarenta metros tiene paso. La abre en
		# cuanto encuentra una linea vadeable dentro -ver [Navgrid._has_ford]-
		# y eso es correcto para PLANEAR, porque significa que por ahi se
		# cruza.
		#
		# Pero quien anda no va por esa linea: va por donde le lleve la ruta. Y
		# con la rejilla como unica autoridad, cruzaba el rio POR LO HONDO
		# dentro de una celda abierta por un vado que estaba tres metros mas
		# alla. Es la queja del jugador -«hay algun poblador que ha cruzado el
		# rio y no se por donde»- y tambien por que la capa de la tecla N
		# pintaba andable una casilla que al pincharla decia que no lo era: no
		# se contradecian, contestaban a cosas distintas.
		#
		# Solo el AGUA, y no la pendiente: mirar tambien la pendiente punto a
		# punto es lo que dejaba gente de pie en sitios que para la rejilla no
		# existian, y de ahi salian los atascos. Ver el comentario de arriba.
		# Si el paso se moja, `_tick_step` ya sabe apartarse a un lado y
		# replantear: se arrima al vado en vez de meterse en la poza.
		# Con el caudal de la rejilla que ya se tiene aqui: preguntarlo otra vez
		# por dentro seria pedir `_navgrid()` dos veces por cata. Ver
		# [caudal_de_hoy].
		return agua_deja_pasar_con(world_position,
			grid.built_with_caudal if grid.is_ready() else 1.0)

	var slope := sim._terrain.get_slope_at(world_position)
	return Traversal.is_passable(slope,
		sim._terrain.crossing_difficulty_at(world_position), sim.has_boat, sim.has_bridge)


## Manda a alguien a un sitio TRAZANDO el camino, no en linea recta.
##
## Con dos guardas que no son un detalle: el destino REPETIDO no se vuelve a
## trazar, y hay tope por fotograma.
##
## Sin la primera, el juego bajaba a dos fotogramas por segundo a los pocos
## minutos: los bloques de «volver a casa» corren cada fotograma, asi que cada
## persona lanzaba un A* completo sesenta veces por segundo para pedir
## exactamente el mismo camino.
## Cuanto puede rodear un camino antes de que el sitio deje de estar al alcance.
##
## Dos veces y media la linea recta. Un valle obliga a rodear -se sube el
## reguero, se bordea el canchal- y eso es andar; dar la vuelta al rio por un
## vado a dos kilometros para trabajar un avellanar que se ve desde casa no lo
## es. Pendiente de playtest.
const RODEO_QUE_SE_ANDA := 2.5

## Por debajo de esto no se mide rodeo ninguno: es andar, no irse lejos.
##
## Dos celdas. A veinte metros, bordear una roca ya multiplica por tres el
## trayecto, y eso no es un rodeo: es el ancho de la rejilla.
const SALTO_CORTO := Navgrid.CELL * 2.0


## LA REGLA DEL RODEO, Y UNA SOLA.
##
## Estaba escrita dos veces con dos fórmulas distintas para la misma pregunta
## —«¿este camino merece andarse?»—: `alcanzable_de_verdad` daba vía libre por
## debajo de una celda y sin holgura, y `merece_el_camino` por debajo de dos y
## con dos celdas de holgura. O sea que un sitio a sesenta metros pasaba una y
## no la otra.
##
## Y las dos deciden sobre lo mismo, encadenadas: la primera filtra qué parajes
## se le ofrecen a la batida y la segunda decide si sale. Con dos varas, el
## batidor elegía un paraje que su propia salida rechazaba, volvía a elegir, y
## desde fuera eso es «dan vueltas entre varios parajes sin orden».
##
## `derecho` es la línea recta y `andado` lo que mide el camino trazado.
## `veces` es cuanto se consiente rodear. Va como parametro y no fijo porque
## NO es igual para todos: [RODEO_QUE_SE_ANDA] es el de quien vuelve a cenar,
## y quien duerme fuera —expedicion, ascension— puede permitirse dar la
## vuelta al rio por un vado lejano, que para el es un tramo mas del viaje.
##
## Hoy esas dos salidas no aplican NINGUNA regla de rodeo -ver la rama de
## exploracion de `SettlementSim._decide_the_day`, que solo mira si hay
## camino-. Cual es su numero es cosa de playtest y no de una corazonada, asi
## que el hueco esta aqui, con nombre, esperandolo.
func rodeo_aceptable(derecho: float, andado: float,
		veces: float = RODEO_QUE_SE_ANDA) -> bool:
	if derecho <= SALTO_CORTO:
		return true
	return andado <= derecho * veces + SALTO_CORTO


## Lo mismo, pero DESDE EL ABRIGO y con memoria.
##
## `alcanzable_de_verdad` cuesta una busqueda entera, y la pregunta «¿se llega a
## esta celda desde casa?» se hace a puñados: el repaso de rezagados barre las
## 4.096 celdas del campo por cada uno de los cinco oficios y pregunta por toda
## candidata que pase el liston. Medido con `PicoProbe`: 1.233 busquedas en 107
## segundos, 22,7 ms cada una, 28 de los 67 segundos que se van en tirones.
##
## La respuesta no cambia hasta que cambia la rejilla —o sea con la estacion,
## ver [HornoDeRejillas]— asi que se guarda por celda de rejilla. Una celda son
## cuarenta metros: dos puntos de la misma celda tienen la misma respuesta, y
## eso reduce cuatro mil preguntas a las pocas decenas de celdas que de verdad
## se miran.
## POR QUE no se llega a un sitio desde el abrigo, o "" si se llega.
##
## Es la misma cuenta que [alcanzable_desde_casa] —el mismo mapa de
## distancias, la misma regla de rodeo— pero contando el porque, para que el
## jugador lo vea en la ventana de parajes en vez de tener que adivinarlo:
## «quiero que en las temporadas en las que haya parajes no alcanzables lo
## marque».
##
## Se contesta AQUI y no en la ventana porque la razon la sabe la rejilla, y
## una segunda copia de la regla en la interfaz acabaria diciendo otra cosa
## que la que de verdad manda a la gente.
func por_que_no_se_llega(punto: Vector3) -> String:
	var grid := _navgrid()
	if grid == null or not grid.is_ready():
		return ""
	if _mapa_de != grid:
		_mapa_de = grid
		_rehacer_el_mapa_de_casa(grid)

	var celda := grid.nearest_open(punto)
	if celda < 0:
		return "no hay suelo que pisar"
	if celda >= _metros_desde_casa.size() or is_inf(_metros_desde_casa[celda]):
		# Incomunicado. Lo que corta el paso en este valle es el agua, y la
		# rejilla de cada estacion se mide con SU caudal: si en verano se
		# llegaba y ahora no, es que el rio ha subido.
		if grid.moja(punto) or _hay_agua_de_por_medio(punto):
			return "el rio va crecido"
		return "no hay paso hasta alli"

	var derecho := Traversal.en_llano(sim.home_position, punto)
	if not rodeo_aceptable(derecho, _metros_desde_casa[celda]):
		return "solo se llega dando la vuelta (%d m para %d en recta)" % [
			int(_metros_desde_casa[celda]), int(derecho)]
	return ""


## Si entre el abrigo y ese punto hay cauce, aunque no sea lo que corta.
func _hay_agua_de_por_medio(punto: Vector3) -> bool:
	var grid := _navgrid()
	if grid == null or not grid.is_ready():
		return false
	var largo := Traversal.en_llano(sim.home_position, punto)
	var catas := maxi(int(largo / Navgrid.CELL), 1)
	for i in range(catas + 1):
		if grid.moja(sim.home_position.lerp(punto, float(i) / float(catas))):
			return true
	return false


func alcanzable_desde_casa(punto: Vector3) -> bool:
	var grid := _navgrid()
	if grid == null or not grid.is_ready():
		return true

	# EL MAPA DE DISTANCIAS, hecho una vez por rejilla.
	#
	# Esto era una busqueda por pregunta, con memoria por celda y un
	# presupuesto por cuadro. Los tres apanos venian del mismo sitio: la
	# pregunta se creia cara. Y no lo es, porque EL ORIGEN ES SIEMPRE EL
	# MISMO -el abrigo-: un solo Dijkstra da los metros exactos hasta cada
	# celda del mapa por lo que costaba UNA de aquellas busquedas.
	#
	# Y al dejar de ser cara desaparecen los tres apanos de golpe: no hace
	# falta memoria -el mapa ES la memoria-, ni presupuesto -no se busca-, ni
	# aplazar la respuesta, que era lo que degradaba las decisiones.
	if _mapa_de != grid:
		_mapa_de = grid
		_rehacer_el_mapa_de_casa(grid)

	var celda := grid.nearest_open(punto)
	if celda < 0 or celda >= _metros_desde_casa.size():
		return false
	var andado := _metros_desde_casa[celda]
	if is_inf(andado):
		return false
	return rodeo_aceptable(Traversal.en_llano(sim.home_position, punto), andado)


## Los metros de camino hasta cada celda, desde el abrigo, POR EL CAMINO QUE SE
## ANDA -el del arbol- y no por el mas corto que existiria. Ver
## [alcanzable_desde_casa] y [_rehacer_el_mapa_de_casa].
var _metros_desde_casa: PackedFloat64Array = PackedFloat64Array()

## Y EL ARBOL: de que celda se viene al llegar a cada una, saliendo del abrigo.
##
## Con el, el camino de casa a cualquier sitio -y de cualquier sitio a casa-
## sale tirando del hilo y es EXACTO. Es lo que quita de en medio el reparto de
## caminos guardados en los viajes que de verdad se repiten, que son los del
## abrigo: ahi es donde uno se comia el rodeo de otro. Ver
## [Wayfinder.camino_por_el_arbol].
var _arbol_desde_casa: PackedInt32Array = PackedInt32Array()

## Los caminos del arbol ya recortados, por celda. Es COSTE Y NO PARTIDA: el
## recorte es una funcion del arbol, la rejilla y la celda, asi que guardarlo
## da lo mismo que rehacerlo. Se vacia al rehacer el arbol.
##
## Lo que evita: `Wayfinder._pull_string` es cuadratico y mira si se ve una
## celda desde otra, y se llamaba UNA VEZ POR CANDIDATO Y POR TICK. Medido en
## tres jornadas de otoño: 100.897 ms de los 104.544 de probar candidatos, que
## a su vez son el 92 % de decidir la jornada. Ver la tarea 21 de
## docs/specs/LO_MISMO_MAS_DEPRISA.md.
var _recortes_del_arbol: Dictionary = {}


## Rehace el mapa y el arbol del abrigo. UN Dijkstra, una vez por rejilla.
##
## El arbol va por COSTE: es el camino que se ANDA, y rodea el canchal y la
## marisma porque ahi es donde uno se rompe un tobillo. Y los metros que se
## guardan son LOS DE ESE MISMO CAMINO -[Wayfinder.metros_desde] los acumula
## sobre el arbol que construye-, que es lo que pregunta la regla del rodeo.
##
## AQUI HUBO DOS DIJKSTRA, y esa es la historia. El segundo media el camino mas
## corto EN METROS, o sea otro camino distinto del que se anda, y se puso para
## tapar esto: al pasar de primavera a verano, 44 parajes de 182 se volvian
## inalcanzables el dia que BAJA el rio. Con dos caminos el sintoma desaparecia
## —la puerta juzgaba uno corto y la gente andaba otro largo— pero la causa
## seguia entera, y se veia en la partida: el jugador miraba las estelas y veia
## rodeos enormes a sitios que se ven desde la puerta.
##
## Medido en el sitio 56, y por eso se deshace: en verano habia 88 sitios que
## la regla del rodeo ADMITIA y que luego se andaban por encima de su propio
## tope de x2,5. Una regla que se comprueba sobre un camino y se incumple en
## otro no es una regla.
##
## La causa era el coste, no la medicion: el riesgo multiplicaba el tiempo sin
## tope y una ladera costaba mas que kilometros de rodeo. Ver
## [Navgrid.RIESGO_MAXIMO]. Con el tope puesto, esta pregunta se puede volver a
## hacer sobre el camino de verdad.
func _rehacer_el_mapa_de_casa(grid: Navgrid) -> void:
	var caminos := Wayfinder.metros_desde(grid, sim.home_position)
	_arbol_desde_casa = caminos["arbol"]
	# Arbol nuevo, recortes viejos que ya no valen. Ver [_recortes_del_arbol].
	_recortes_del_arbol.clear()
	_metros_desde_casa = caminos["metros"]

## De que rejilla es ese mapa. Otra rejilla, otras distancias.
var _mapa_de: Navgrid = null


## Si ya se ha gastado lo que este cuadro consiente buscar.
##
## UN SOLO BOTE, y se mira aqui. Habia dos -este por nodos y otro por
## numero de busquedas- y ademas tres caminos que no pasaban por ninguno:
## `Querencia` preguntando dentro de un bucle, el paraje heredado de la
## batida y el reparto de tajos. Un tope que se puede rodear no es un tope,
## y se veia: setenta y nueve busquedas en un fotograma de 2.541 ms.
func presupuesto_agotado() -> bool:
	return sim._path_nodes_this_frame >= SettlementSim.NODES_PER_FRAME


## Empieza el cuadro.
##
## Ya no reparte presupuesto de busquedas: no hay busquedas que repartir.
## La pregunta que se las comia -«¿se llega desde casa?»- se contesta ahora
## leyendo un mapa de distancias hecho una vez por rejilla. Ver
## [alcanzable_desde_casa].
func nuevo_cuadro() -> void:
	pass


## Si a este punto se llega DE VERDAD desde aqui.
##
## No basta con que la rejilla los ponga en la misma zona: eso solo dice que hay
## un camino, y el camino puede ser dar la vuelta al rio entero. Es la queja del
## jugador -«uno de los parajes iniciales esta al otro lado del rio»-: estaba
## comunicado, si, por un vado a kilometro y medio.
##
## Se mide el camino de verdad y se compara con la linea recta. Cuesta una
## busqueda, asi que esto se pregunta al BAUTIZAR un sitio -unas pocas veces al
## dia- y no al repartir trabajo, que ya tiene su propio filtro.
func alcanzable_de_verdad(desde: Vector3, hasta: Vector3) -> bool:
	var grid := _navgrid()
	if grid == null or not grid.is_ready():
		return true
	if not grid.connected(desde, hasta):
		return false

	var derecho := Traversal.en_llano(desde, hasta)
	if derecho <= SALTO_CORTO:
		return true

	# Y ESTA BUSQUEDA SE PAGA DEL MISMO BOTE QUE LAS DEMAS.
	#
	# Habia dos presupuestos para lo mismo -el de `_send_to` por nodos y el
	# de `alcanzable_desde_casa` por busquedas- y este camino no pasaba por
	# ninguno. Un tope que se puede rodear no es un tope: medido con el
	# panel de F3, el peor cuadro de la jornada 1 eran 950 ms, y 871 de
	# ellos TREINTA Y DOS busquedas en un solo cuadro.
	#
	# Y SI EL BOTE ESTA GASTADO, NO SE BUSCA. No es un consejo: es el tope.
	#
	# Apuntar lo que cuesta sin cortar no sirve de nada -era lo que habia-,
	# porque quien llama esta dentro de un bucle y no mira la cuenta. El
	# tope tiene que estar donde se gasta.
	#
	# Se avisa con [Traza.SIN_PRESUPUESTO] y se devuelve `false`, que es lo
	# conservador: quien llama, si sabe esperar, aplaza; y si no, se queda
	# con un candidato menos este cuadro y lo tendra al siguiente.
	if presupuesto_agotado():
		ultima_traza = Traza.SIN_PRESUPUESTO
		return false

	var camino := Wayfinder.find(grid, desde, hasta)
	sim._path_nodes_this_frame += Wayfinder.last_nodes
	if camino.is_empty():
		return false
	return rodeo_aceptable(derecho, largo_de(desde, camino))


## Si en línea recta entre estos dos puntos hay agua que no se vadea.
##
## Es la comprobación barata para elegir DÓNDE TRABAJAR dentro de un sitio: la
## mata siguiente, el tramo siguiente de una batida. Un A* por cada candidato
## sería absurdo —se sortean varios cada pocos minutos de juego— y aquí no hace
## falta saber el camino, sino sólo si hay cauce de por medio.
##
## Se cata al mismo paso que anda una persona, [CATA_DEL_PASO], porque el río
## de este valle mide entre cuarenta y ochenta metros y catar cada veinte lo
## deja pasar a trozos: es el mismo fallo que ya se arregló en la rejilla —ver
## [Navgrid.CATA_DEL_VADO]— y en las huellas de los parajes.
func cruza_el_agua(desde: Vector3, hasta: Vector3) -> bool:
	if sim._terrain == null:
		return false
	var largo := Traversal.en_llano(desde, hasta)
	if largo <= 0.001:
		return false
	# LA CATA ENTERA LA HACE EL TERRENO, de una llamada: ver
	# [TerrainGenerator.linea_sin_agua]. Aqui se hacian dos llamadas por punto
	# y ochenta y siete puntos por candidato.
	var tope := Hydrography.tope_de_vado(sim.has_boat, sim.has_bridge)
	return not sim._terrain.linea_sin_agua(desde, hasta, CATA_DEL_PASO,
		caudal_de_hoy(), tope.x, tope.y > 0.5)




## Lo que mide un camino ya trazado, en metros.
func largo_de(desde: Vector3, camino: PackedVector3Array) -> float:
	if camino.is_empty():
		return 0.0
	var largo := Traversal.en_llano(desde, camino[0])
	for i in range(1, camino.size()):
		largo += Traversal.en_llano(camino[i - 1], camino[i])
	return largo


## Si el camino que ACABA de trazarse para esta persona merece andarse.
##
## Es `alcanzable_de_verdad` sin pagar la busqueda dos veces: el camino ya está
## en `person.route` porque `_send_to` lo puso ahí, así que sólo hay que
## medirlo. Y es la misma regla —no más de [RODEO_QUE_SE_ANDA] veces la línea
## recta—, que estaba escrita en un sitio y comprobada en ninguno de los tres
## que deciden adónde se va.
##
## Porque «hay camino» no quiere decir «se va»: la otra orilla está comunicada
## por un vado a kilómetro y medio, así que `_send_to` devuelve una ruta
## perfectamente válida de mil metros para un sitio que se ve desde la puerta.
## Es la queja, literal: «un explorador ha ido a batir ese paraje y se ha ido a
## 1 km contra el río».
##
## El suelo de cortesía es para los saltos cortos: a veinte metros, rodear una
## roca ya multiplica por tres y eso no es irse lejos, es andar.
func merece_el_camino(person: Inhabitant, destino: Vector3) -> bool:
	if person.route.is_empty():
		return false
	var derecho := Traversal.en_llano(person.position, destino)
	return rodeo_aceptable(derecho,
		largo_de(person.position, person.route))


## Amarra el ARRANQUE del camino, que es el unico tramo que nadie comprueba.
##
## Un camino trazado es una cadena de CENTROS DE CELDA: el A* encadena celdas y
## el recorte de la escalera comprueba el pasillo de centro a centro -ver
## [Wayfinder._clear_between]-. O sea que lo que esta comprobado es la linea que
## sale del CENTRO de la celda de partida.
##
## Y quien anda no esta en el centro de su celda: esta donde esta, hasta a
## veintiocho metros en diagonal. La recta de ahi al primer hito no la ha
## mirado nadie, y por ahi puede haber una celda cerrada. Eso vale para
## CUALQUIER camino, no solo para los guardados: los guardados solo lo hacen
## mas probable, porque ademas se comparten entre gente de la misma celda.
##
## El arreglo es meter el centro de la celda propia como primer hito cuando la
## recta no esta limpia. Entonces todos los tramos del camino son exactamente
## los que se comprobaron, y el unico trozo nuevo es de la persona al centro de
## SU PROPIA celda, que esta abierta -por eso se puede estar en ella-.
##
## Se probo antes a DESCARTAR el camino guardado cuando la recta no salia
## limpia, y salio carisimo: cada descarte caia en una busqueda nueva, eso
## agotaba el presupuesto de nodos del cuadro y media banda se quedaba
## esperando -medido: 2.567 atascos en cuatro jornadas-. Esto no descarta nada
## ni busca nada: mira una recta y, como mucho, añade un punto.
func _amarrar_la_entrada(person: Inhabitant) -> void:
	if person.route.is_empty():
		return
	var grid := _navgrid()
	if not grid.is_ready():
		return
	if Wayfinder.linea_limpia(grid, person.position, person.route[0]):
		return

	var centro := grid.point_of(grid.cell_of(person.position))
	if sim._terrain != null:
		centro.y = sim._terrain.get_height_at(centro)
	# Si ya se esta practicamente en el centro, meterlo seria un hito de cero
	# metros: el problema entonces no es el arranque y no hay nada que amarrar.
	if Traversal.en_llano(centro, person.position) < 1.0:
		return

	var con_entrada := PackedVector3Array([centro])
	con_entrada.append_array(person.route)
	person.route = con_entrada
	person.route_step = 0


func _send_to(person: Inhabitant, destination: Vector3) -> void:
	ultima_traza = Traza.TRAZADO
	var same := Vector2(person.target.x - destination.x,
		person.target.z - destination.z).length() < 1.0

	# El camino tiene que servir TODAVIA, no solo existir.
	#
	# La guarda pedia «mismo destino y ruta no vacia», y una ruta CONSUMIDA
	# hasta el final sin haber llegado cumple las dos: la persona se quedaba
	# con un camino gastado que ya no la llevaba a ninguna parte y no se le
	# volvia a trazar nunca. Peor: el re-trazado que puse para eso entraba
	# aqui y se daba media vuelta en esta misma linea, o sea que no hacia
	# nada.
	#
	# Medido: los tres unicos atascos que quedaban eran esto, los tres a las
	# 21:32 -al mandar a la gente a dormir- con «va por el hito 4 de 4» y el
	# abrigo a 648 metros.
	var spent := person.route_step >= person.route.size()
	if same and not person.route.is_empty() and not spent:
		return

	# A un sitio del que YA se sabe que no hay camino no se vuelve a pedir
	# ruta. Sin esto el juego se hundia a cuatro fotogramas por segundo en
	# cuanto alguien apuntaba al otro lado de un rio: la ruta salia vacia, la
	# guarda de arriba exige ruta NO vacia para no recalcular, y entonces se
	# lanzaba una busqueda completa -agotando los cuatro mil nodos- en cada
	# fotograma y para cada persona.
	if Vector2(person.unreachable.x - destination.x,
			person.unreachable.z - destination.z).length() < 1.0:
		person.target = destination
		ultima_traza = Traza.IMPOSIBLE
		return

	# Todo destino se amarra a celda abierta ANTES de nada. Lo hacia solo el
	# buscador de caminos, asi que `_best_known_spot` y compania seguian
	# mandando gente a tajos que la rejilla da por cerrados.
	Cronometro.tramo("send_to: suelo firme")
	destination = _firm_ground(destination)
	Cronometro.cierra("send_to: suelo firme")
	person.target = destination
	# Destino nuevo, cuenta nueva de lo cerca que se ha estado. Ver
	# [Inhabitant.lo_mas_cerca].
	person.lo_mas_cerca = person.position.distance_to(destination)

	# Si el destino esta en otra ZONA del mapa no hay camino, y saberlo no
	# cuesta nada: la rejilla trae marcados los trozos comunicados entre si.
	# Antes esto era una busqueda exhaustiva de doce mil nodos, y se lanzaba
	# cada vez que alguien apuntaba al otro lado de un rio.
	Cronometro.tramo("send_to: ¿comunicados?")
	var comunicados := _navgrid().connected(person.position, destination)
	Cronometro.cierra("send_to: ¿comunicados?")
	if not comunicados:
		person.route = PackedVector3Array()
		person.route_step = 0
		person.unreachable = destination
		ultima_traza = Traza.IMPOSIBLE
		return

	# El presupuesto se mira antes de buscar. Quien va sin camino pasa
	# igualmente, o se quedaria parado para siempre; pero solo uno por
	# fotograma, que es lo que impide que la manana en que la banda entera
	# sale a la vez se coma medio segundo.
	# El presupuesto se mira antes de buscar. Quien va sin camino pasa
	# igualmente, o se quedaria parado para siempre; pero solo uno por
	# paso de simulacion, que es lo que impide que la manana en que la banda
	# entera sale a la vez se coma medio segundo.
	#
	# QUIEN YA LLEVA UN CAMINO SIGUE CON EL. Y si, el camino que lleva no va
	# a donde se acaba de pedir -para llegar aqui hay que haber pasado la
	# guarda de «mismo destino»-, asi que durante un cuadro anda hacia el
	# sitio de antes con el destino nuevo puesto.
	#
	# Esta apuntado porque es un apaño y hay que saberlo: es el COLCHON que
	# sostiene el bote de nodos. Se probo a quitarlo -que nadie ande nunca
	# con la ruta de otro viaje- y tambien a devolver el destino de antes
	# para que ruta y destino casaran; las dos cosas dejan a la banda
	# plantada, medido en ocho jornadas: 329 y 292 atascos contra 3.
	#
	# El colchon hace falta mientras cada viaje cueste una busqueda. Deja de
	# hacer falta el dia que los caminos de casa salgan del arbol de
	# Dijkstra, que es el arreglo de verdad. Ver [Vereda.clave_de].
	if sim._path_nodes_this_frame >= SettlementSim.NODES_PER_FRAME:
		if not person.route.is_empty():
			return
		if sim._stranded_this_frame > 0:
			# Ruta vacia por PRESUPUESTO, que NO ES LO MISMO que no haberla:
			# aqui no se ha mirado. Ver [Traza].
			ultima_traza = Traza.SIN_PRESUPUESTO
			return
		sim._stranded_this_frame += 1

	# LOS VIAJES DEL ABRIGO SALEN DEL ARBOL, exactos y sin buscar.
	#
	# Son la mayoria: por la manana los quince salen de casa a sus tajos y
	# por la tarde vuelven. Y son justo donde se veia la queja -«siguiendo
	# el camino de otros pobladores que van a sitios diferentes»-, porque
	# es donde la cache repartia: quince personas saliendo del mismo cubo de
	# cuarenta y ocho metros a destinos distintos se prestaban el camino, y
	# quien lo tomaba se comia el rodeo del otro.
	#
	# El arbol no reparte nada: da EL camino de este viaje. Y no cuesta
	# busqueda, porque ya esta hecho -un Dijkstra por rejilla, ver
	# [_rehacer_el_mapa_de_casa]-.
	var del_abrigo := Traversal.en_llano(person.position, sim.home_position) \
		<= SettlementSim.SALIDA_DE_CASA
	var al_abrigo := Traversal.en_llano(destination, sim.home_position) \
		<= SettlementSim.SALIDA_DE_CASA
	if _arbol_desde_casa.size() == _navgrid().cost.size() \
		and (del_abrigo or al_abrigo):
		var grid_casa := _navgrid()
		Cronometro.tramo("send_to: punta del arbol")
		var punta := grid_casa.nearest_open(destination if del_abrigo \
			else person.position)
		Cronometro.cierra("send_to: punta del arbol")
		if punta >= 0:
			Cronometro.tramo("send_to: camino por el arbol")
			var por_el_arbol := Wayfinder.camino_por_el_arbol(grid_casa,
				_arbol_desde_casa, punta,
				destination, al_abrigo and not del_abrigo,
				_recortes_del_arbol)
			Cronometro.cierra("send_to: camino por el arbol")
			if not por_el_arbol.is_empty():
				person.route = por_el_arbol
				person.route_step = 0
				person.unreachable = Vector3.ZERO
				_amarrar_la_entrada(person)
				_apuntar_el_rodeo(person, destination)
				return

	# LA VEREDA DE ESTE TRAYECTO, si la banda ya la sabe. Se entra a ella por
	# donde toca y se sale por un remate catado, que es lo que la diferencia de
	# la cache que habia: los dos extremos se miran. Ver [Vereda.clave_de],
	# donde esta medido por que la clave es el par y no solo el destino.
	var lane := Vereda.clave_de(person.position, destination)
	var sabida: Vereda = null
	if sim.knowledge != null:
		sabida = sim.knowledge.vereda(lane, _navgrid())
	if sabida != null and not sabida.hitos.is_empty():
		# Y EL ULTIMO TRAMO SE CATA IGUAL QUE EL PRIMERO.
		#
		# Una vereda es del SITIO, y el sitio es un cubo de [Vereda.CELDA]: su
		# ultimo hito puede estar a setenta metros del punto exacto al que va
		# esta persona. Rematar ahi sin mirar era lo que hacia la cache vieja
		# -lo hacia `_retarget`, ya borrado- y con la clave por destino es
		# el remate de TODOS los viajes al sitio, no solo de los que salian
		# del mismo cubo.
		#
		# Medido, ocho jornadas en el sitio 56: sin catarlo, los pasos que el
		# terreno corta con camino trazado suben de 79 a 1.471. Con la cata,
		# ver el parte de ESTADO.md §2.
		var por_la_vereda := sabida.remate(person.position, destination,
			_navgrid())
		if not por_la_vereda.is_empty():
			person.route = por_la_vereda
			sabida.recorridos += 1
			person.route_step = 0
			person.unreachable = Vector3.ZERO
			_amarrar_la_entrada(person)
			_apuntar_el_rodeo(person, destination)
			return

	var route := Wayfinder.find(_navgrid(), person.position, destination)
	sim._path_nodes_this_frame += Wayfinder.last_nodes

	if not route.is_empty():
		_remember_route(lane, route)

	if route.is_empty():
		# No hay camino: ni se intenta. Se queda donde esta y se le buscara
		# otro destino, que es mejor que salir andando hacia un rio.
		person.route = PackedVector3Array()
		person.route_step = 0
		person.unreachable = destination
		ultima_traza = Traza.IMPOSIBLE
		return

	person.route = route
	person.route_step = 0
	person.unreachable = Vector3.ZERO
	_amarrar_la_entrada(person)
	_apuntar_el_rodeo(person, destination)


## Lo que arriesga el camino que lleva ahora mismo, de 0 a 1. Lo usa la ficha
## para poder decirle al jugador que la ruta es mala.
func route_risk(person: Inhabitant) -> float:
	if sim._terrain == null or person.route.is_empty():
		return 0.0
	var worst := 0.0
	for point: Vector3 in person.route:
		var ground := Traversal.classify_ground(
			sim._terrain.get_slope_at(point),
			sim._terrain.crossing_difficulty_at(point),
			sim.temporada.encharcamiento() if sim.temporada != null else 0.0)
		var risk := 0.0
		match ground:
			Traversal.Ground.CANCHAL: risk = 1.0
			Traversal.Ground.ROCA: risk = 0.6
			Traversal.Ground.MARISMA: risk = 0.5
			_: risk = 0.1
		worst = maxf(worst, risk)
	return worst


## La celda gruesa de la cache. Si a un punto no se llega, a los de al lado
## tampoco: lo que corta el paso es un rio o un cortado, no un metro cuadrado.
func _reach_key(point: Vector3) -> String:
	return "%d_%d" % [int(point.x / 64.0), int(point.z / 64.0)]


## La rejilla de navegacion, construida a la primera y reusada siempre.
##
## Se rehace solo cuando la banda aprende a cruzar el agua: barca y puente
## cambian por donde se pasa, y una rejilla que no lo sabe deja medio mapa
## marcado como imposible para siempre.
func _navgrid() -> Navgrid:
	# UNA REJILLA POR ESTACION. El rio crecido cierra vados, asi que los
	# caminos de enero no son los de agosto: con una sola rejilla -horneada en
	# seco- la banda planeaba rutas por vados que ya no existian. Ver
	# [HornoDeRejillas], que amasa las otras tres mientras se juega.
	if not sim.horno.sirven(sim.has_boat, sim.has_bridge):
		var started := Time.get_ticks_msec()
		sim.horno.encargar(sim._terrain, sim.has_boat, sim.has_bridge,
			GameState.season as Subsistence.Season, Temporada.CAUDAL,
			Temporada.ENCHARCA)
		sim._grid = sim.horno.de(GameState.season as Subsistence.Season)
		sim.grid_build_ms = Time.get_ticks_msec() - started
		# Los caminos de antes de la barca ya no son los mejores
		forget_routes()

		# Y la puerta de casa se anda SIEMPRE. Un abrigo se elige por ser
		# habitable, asi que si la medicion dice que su entrada esta cerrada,
		# la equivocada es la medicion: la banda entera quedaria en una celda
		# que no existe y no se le podria trazar nada.
		var freed := sim._grid.open_around_home(sim.home_position, sim._terrain)
		if freed > 0:
			print("Navegacion: %d celdas abiertas a la fuerza junto al abrigo"
				% freed)

		# Se dice en voz alta porque una rejilla mal medida NO se ve: la gente
		# simplemente se queda en el campamento, y desde fuera parece que el
		# sim.reparto de trabajo esta roto. Si «desde casa» sale bajo, el problema
		# es este fichero y no el que se este mirando.
		var home_cell := sim._grid.nearest_open(sim.home_position)
		print("Navegacion: %d x %d celdas · transitable %.0f%% · zonas %d · %d ms"
			% [sim._grid.wide, sim._grid.tall, sim._grid.open_fraction() * 100.0,
				sim._grid.areas, sim.grid_build_ms])
		if home_cell < 0:
			push_warning("El campamento no tiene suelo pisable cerca: "
				+ "nadie podra ir a ninguna parte.")

	# Y AQUI ES DONDE CAMBIA LA ESTACION. Es una consulta a un diccionario, asi
	# que se hace en cada llamada sin pensarlo: en cuanto el horno tiene lista
	# la del trimestre nuevo, se pasa a ella.
	var quiere := sim.horno.de(GameState.season as Subsistence.Season)
	if quiere != null and quiere != sim._grid:
		sim._grid = quiere
		# Los caminos guardados son de la estacion pasada y puede que crucen
		# por un vado que ahora va crecido. Se tiran.
		forget_routes()
		# La puerta de casa se anda SIEMPRE, tambien en la rejilla nueva: cada
		# una se mide por su cuenta y ninguna hereda el hueco de la anterior.
		sim._grid.open_around_home(sim.home_position, sim._terrain)
		print("Navegacion: caminos de %s · transitable %.0f%% · zonas %d" % [
			Subsistence.season_name(GameState.season as Subsistence.Season),
			sim._grid.open_fraction() * 100.0, sim._grid.areas])
	return sim._grid


## Si esta persona puede llegar a un punto DESDE DONDE ESTA.
##
## Comprobarlo era lo mas caro del juego: para decir que NO se llega hay que
## agotar la busqueda entera. Ahora la rejilla trae las zonas comunicadas
## marcadas de antemano y esto son dos enteros.
func _reachable(person: Inhabitant, point: Vector3) -> bool:
	if sim._terrain == null:
		return true
	return _navgrid().connected(person.position, point)


## Se aprende el camino. El tope y el sello los pone [BandKnowledge].
func _remember_route(lane: String, route: PackedVector3Array) -> void:
	if sim.knowledge == null:
		return
	sim.knowledge.recordar_vereda(lane, route, _navgrid())


## Se tiran los caminos guardados. Lo llama quien cambie el terreno o lo que
## se puede cruzar: un camino de antes del puente ya no es el mejor.
func forget_routes() -> void:
	if sim.knowledge != null:
		sim.knowledge.olvidar_veredas()
	# Y SE AVISA DE QUE HAY QUE REPASAR EL MAPA.
	#
	# Cambiar por donde se pasa cambia qué sitios se pueden bautizar sin que
	# nadie haya ido a mirarlos: un avellanar descartado en enero porque el
	# río iba crecido es candidato en agosto. Es el único caso en que hace
	# falta barrer el campo, y por eso el barrido cuelga de aquí en vez de
	# correr a cada hora por si acaso. Ver [Parajes.revisar_el_mapa].
	if sim.parajes != null:
		sim.parajes.revisar_el_mapa = true


## Saca de la parálisis a quien lleve horas sin moverse.
##
## Es una red de seguridad, no un diagnostico, y se pone porque los motivos
## por los que alguien se queda clavado son muchos y van saliendo de uno en
## uno: una ruta que se vacia, un destino que deja de ser alcanzable, una
## pared que el andador no cruza aunque el planificador dijera que si. Lo que
## NO puede pasar es que el jugador vea a alguien dos dias parado en un monte
## sin que el juego se entere.
##
## Se anota en la cronica a proposito. Un remiendo silencioso esconde el fallo
## que hay debajo; uno que se cuenta deja el rastro para arreglarlo.
func _watch_for_stuck(person: Inhabitant, hours: float) -> void:
	# SOLO yendo, volviendo y reconociendo. Prospectar un paraje es quedarse
	# quieto mirando el suelo durante horas, y eso es el trabajo, no una
	# averia. Reconocer una comarca, en cambio, es andarla.
	var busy := person.state == Inhabitant.State.YENDO \
		or person.state == Inhabitant.State.VOLVIENDO \
		or person.state == Inhabitant.State.RECONOCIENDO
	if not busy:
		person.stuck_hours = 0.0
		person.stuck_where = person.position
		return

	# Estar quieto AL LADO de donde ibas no es estar atascado: es haber
	# llegado y que el estado no se haya enterado. El remedio es otro.
	# Con el radio escalado, por lo mismo que en todas partes: a velocidad de
	# persona un paso mide mas que seis metros y el tramo de batida no se daba
	# nunca por terminado. Ver [SettlementSim._radio_de_llegada].
	var arrived := person.position.distance_to(person.target) \
		< sim._radio_de_llegada(hours) * 1.5

	# QUIEN SE MUEVE NO ESTÁ ATASCADO. Punto, y sin mirar dónde está.
	#
	# Aquí ponía `and not arrived`, y eso convertía «andar cerca de tu destino»
	# en «estar plantado»: al acercarse a menos de nueve metros del sim.tajo el
	# reloj de atasco dejaba de reiniciarse aunque la persona siguiera andando,
	# y a las dos horas se la daba por enganchada. Si para entonces se había
	# separado un poco del punto —cosa que pasa sola, porque el destino se
	# recalcula— ni siquiera entraba por la rama buena: salía por la de
	# «no avanza por el camino trazado», se cerraba la salida como atasco y se
	# la mandaba a casa.
	#
	# Lo pagaba sobre todo la CAZA MENOR, que es la que más ronda su sim.tajo:
	# medido en el sitio 56, 72 atascos en tres jornadas y CERO ticks en los que
	# alguien estuviera de verdad parado. Se veía en la ventana de rastros como
	# una columna entera de salidas cerradas con «atascado» sin que ninguna lo
	# estuviera.
	#
	# El caso que `arrived` venía a resolver -llegar y que el estado no se
	# entere- sigue saliendo por su rama: quien ha llegado y no se mueve tampoco
	# supera `SettlementSim.STUCK_SLACK`, así que el reloj corre igual y lo recoge abajo.
	# QUIEN SE ACERCA NO ESTA ATASCADO. Y quien no se acerca, si.
	#
	# La vara de antes era el DESPLAZAMIENTO: moverse doce metros reiniciaba el
	# reloj. Eso deja fuera el atasco mas aparatoso que hay, y es el que se ve
	# en los rastros como un ovillo pegado al agua: alguien que camina la
	# orilla de un rio de un lado para otro buscando por donde pasar. Se mueve
	# muchisimo -asi que nunca contaba como plantado- y no se acerca nada.
	#
	# Pasa porque la rejilla y el andador no dicen lo mismo del agua: la celda
	# de cuarenta metros se abre en cuanto hay UNA linea vadeable dentro -ver
	# [Navgrid._has_ford]- y el andador pregunta por el punto concreto que pisa
	# -ver `_can_step_into`-, que casi nunca es esa linea. La rejilla traza el
	# camino por el vado y quien anda no lo encuentra.
	# QUIEN VA TACHANDO HITOS ESTÁ ANDANDO SU CAMINO, y eso no es atascarse
	# aunque la distancia al destino no baje.
	#
	# La vara de abajo mide la línea recta al destino, y un camino de verdad no
	# es una línea recta: para pasar al otro lado se sube el reguero, se rodea
	# el canchal, se va A BUSCAR EL VADO —que puede estar en dirección
	# contraria—. Durante todo ese tramo la distancia al destino no baja o
	# incluso sube, y quien lo anda no tiene nada de averiado: está haciendo
	# exactamente lo que se le trazó.
	#
	# Sin esto, un rodeo largo se cierra como «no avanza por el camino trazado»
	# —el hito siguiente es perfectamente pisable, claro— y la persona se va a
	# casa a media jornada. Es un atasco de mentira que además tapa a los de
	# verdad en el recuento.
	var quedan := person.route.size() - person.route_step
	if not person.route.is_empty() and quedan < person.hitos_pendientes:
		person.hitos_pendientes = quedan
		person.stuck_hours = 0.0
		person.stuck_where = person.position
		return
	person.hitos_pendientes = quedan if not person.route.is_empty() else 0

	var falta := person.position.distance_to(person.target)
	if is_inf(person.lo_mas_cerca):
		# Marca sin estrenar: solo se toma la referencia. Reiniciando aqui el
		# reloj, quien llega y se queda colgado no se detecta nunca, porque
		# cada mirada seria la primera.
		person.lo_mas_cerca = falta
	elif falta < person.lo_mas_cerca - SettlementSim.STUCK_SLACK:
		person.lo_mas_cerca = falta
		person.stuck_hours = 0.0
		person.stuck_where = person.position
		return

	person.stuck_hours += hours
	if person.stuck_hours < SettlementSim.STUCK_HOURS:
		return
	person.stuck_hours = 0.0
	person.stuck_where = person.position

	# LLEGO y el estado no se entero. Es el caso mas comun de todos -medido:
	# dieciocho de treinta y uno- y no tiene nada que ver con el terreno: la
	# persona esta encima de su destino, la ruta se ha acabado, y sigue en
	# «yendo» porque la transicion de llegada vive en un bloque de la jornada
	# que a esa hora no corre.
	#
	# Se suelta y se le vuelve a repartir trabajo, que es lo que tenia que
	# haber pasado solo. No va a la cronica -no es una noticia, es una
	# costura- pero SI a la cuenta, porque veinte de estos son un fallo con
	# nombre y hay que poder verlo.
	if arrived:
		sim.stuck_tally[SettlementSim.LLEGADA_COLGADA] = int(sim.stuck_tally.get(SettlementSim.LLEGADA_COLGADA, 0)) + 1
		_record_stuck(person, SettlementSim.LLEGADA_COLGADA)
		person.route = PackedVector3Array()
		person.route_step = 0
		person.state = Inhabitant.State.OCIOSO
		return

	# Metido donde no se pisa: de ahi no se sale con un camino, porque
	# cualquier camino empieza en una celda que no existe. Se le saca al suelo
	# firme mas cercano y ya andara desde ahi.
	var grid := _navgrid()
	if not grid.passable(person.position):
		var open_cell := grid.nearest_open(person.position)
		if open_cell >= 0:
			sim.stuck_tally[SettlementSim.SUELO_MALO] = int(sim.stuck_tally.get(SettlementSim.SUELO_MALO, 0)) + 1
			_record_stuck(person, SettlementSim.SUELO_MALO)
			var firm := grid.point_of(open_cell)
			firm.y = sim._terrain.get_height_at(firm)
			person.position = firm
			person.route = PackedVector3Array()
			person.route_step = 0
			person.state = Inhabitant.State.OCIOSO
			return

	# Al lado de casa: el estado se ha quedado colgado y ya esta. Se corrige y
	# NO se cuenta.
	#
	# Contarlo llenaba la cronica de «llevaba horas plantado a 6 m del
	# abrigo» -once avisos el primer dia- y eso no es informar: es tapar con
	# ruido las dos lineas que si importaban.
	if sim._home_reached(person):
		sim.despensa._deliver(person)
		person.route = PackedVector3Array()
		person.route_step = 0
		person.state = Inhabitant.State.OCIOSO
		return

	# Lejos y sin poder seguir: eso si es noticia, y una vez al dia por
	# persona. Se anota a proposito: un remiendo silencioso esconde el fallo
	# que hay debajo; uno que se cuenta deja el rastro para arreglarlo.
	var why := _stuck_reason(person)
	sim.stuck_tally[why] = int(sim.stuck_tally.get(why, 0)) + 1
	_record_stuck(person, why)

	if person.stuck_told != sim.day:
		person.stuck_told = sim.day
		sim._note(Chronicle.Kind.GENTE,
			'%s se quedo atascado %s: %s. Vuelve al abrigo.'
				% [person.given_name,
					sim.parajes.place_name(person.position, sim.home_position), why], 0)

	# Y en SU diario, que es donde el jugador mira cuando una jornada no ha
	# dado nada. Sin esto, un dia entero peleandose con la orilla de un rio se
	# lee como «salio, decidio volver de vacio» y no dice por que.
	sim.cronista.apuro(person,
		"Llevaba %.0f horas sin poder acercarse a donde iba (%s, a %.0f m) y "
			% [SettlementSim.STUCK_HOURS, why,
				person.position.distance_to(person.target)]
		+ "lo dejo por imposible: manana se le repartira otro sitio.")

	if not person.journey.is_empty():
		person.end_journey(sim.day,
			sim.parajes.place_name(person.position, sim.home_position),
			'atascado: %s' % why)

	person.route = PackedVector3Array()
	person.route_step = 0
	person.survey_hours = 0.0
	person.unreachable = person.target
	_send_to(person, sim.home_position)
	person.state = Inhabitant.State.VOLVIENDO if not person.route.is_empty() \
		else Inhabitant.State.OCIOSO


## Por que no puede seguir esta persona.
##
## No es adorno. «Se quedo atascado» sin mas es exactamente lo que no sirve:
## deja al jugador con la sospecha y a mi sin el dato. Cada motivo de estos
## apunta a una pieza distinta del juego, y se distinguen mirando.
func _stuck_reason(person: Inhabitant) -> String:
	if sim._terrain == null:
		return "sin terreno"

	var grid := _navgrid()

	# 1. El destino esta en otra zona del mapa: no hay camino y no lo habra
	if not grid.connected(person.position, person.target):
		return "no hay paso hasta alli"

	# 2. Esta parado ENCIMA de algo que no se pisa. Pasa cuando el terreno
	#    cambia bajo los pies -o cuando alguien acaba metido en un cauce- y es
	#    el peor caso, porque desde ahi no se puede ni salir andando.
	if not grid.passable(person.position):
		return "metido donde no se pisa"

	# 3. Tiene camino pero no avanza: hay algo delante que el andador no cruza
	#    aunque el planificador dijera que si
	if not person.route.is_empty():
		var next_point := person.next_waypoint()
		if not _can_step_into(next_point):
			return "algo cortando el paso"
		return "no avanza por el camino trazado"

	# 4. Sin camino y sin destino imposible: la traza fallo por presupuesto
	return "se quedo sin camino trazado"


func _record_stuck(person: Inhabitant, why: String) -> void:
	if sim.stuck_reports.size() >= SettlementSim.STUCK_REPORTS or sim._terrain == null:
		return

	var grid := _navgrid()
	var here := grid.cell_of(person.position)
	var goal := grid.cell_of(person.target)
	var waypoint := person.next_waypoint()

	sim.stuck_reports.append({
		"dia": sim.day,
		"hora": sim.hour,
		"quien": person.given_name,
		"motivo": why,
		"estado": int(person.state),
		"oficio": Profession.job_name(person.job as Profession.Job),
		"donde": person.position,
		"adonde": person.target,
		"lejos_destino": person.position.distance_to(person.target),
		"lejos_casa": person.position.distance_to(sim.home_position),
		"hitos": person.route.size(),
		"hito_actual": person.route_step,
		# EN LLANO, que el hito viene de la rejilla y trae `y = 0`.
		#
		# Restar una celda de un punto con cota no mide una distancia:
		# mide la altitud. En este valle el relieve va de 96 a 718 m, asi
		# que el parte forense decia «el siguiente hito a 441 m» de un
		# hito que estaba a cuarenta. Ver [Traversal.en_llano].
		"lejos_hito": Traversal.en_llano(person.position, waypoint),
		# El suelo, visto por los dos que tienen que estar de acuerdo
		"celda_pisable": grid.cost[here] > Navgrid.BLOCKED,
		"destino_pisable": grid.cost[goal] > Navgrid.BLOCKED,
		"hito_pisable": grid.passable(waypoint),
		"anda_al_hito": _can_step_into(waypoint),
		"zona_aqui": grid.area[here],
		"zona_destino": grid.area[goal],
		"pendiente": sim._terrain.get_slope_at(person.position),
		"vado": sim._terrain.crossing_difficulty_at(person.position),
		# Y las dos que de verdad dicen por qué no se mueve: cuántas veces se
		# le ha cortado el paso y a qué velocidad anda. Sin ellas, «no avanza
		# por el camino trazado» describe el síntoma y nada más.
		"bloqueos": person.blocked_steps,
		"paso": _terrain_speed(person,
			(waypoint - person.position).normalized()) / maxf(sim.walk_speed, 0.001),
	})


## El informe forense, en texto.
func stuck_report_text() -> String:
	var lines: Array[String] = []
	for report: Dictionary in sim.stuck_reports:
		lines.append(("d%d %05.2fh %-6s %-12s | %s" % [
			int(report["dia"]), float(report["hora"]), String(report["quien"]),
			String(report["oficio"]), String(report["motivo"])]))
		lines.append("      de (%d,%d) a (%d,%d) · %d m del destino · %d m de casa" % [
			int((report["donde"] as Vector3).x), int((report["donde"] as Vector3).z),
			int((report["adonde"] as Vector3).x), int((report["adonde"] as Vector3).z),
			int(report["lejos_destino"]), int(report["lejos_casa"])])
		lines.append("      camino %d hitos, va por el %d, el siguiente a %d m" % [
			int(report["hitos"]), int(report["hito_actual"]),
			int(report["lejos_hito"])])
		lines.append("      suelo: aqui %s · destino %s · hito %s · el andador pasa: %s" % [
			"pisable" if bool(report["celda_pisable"]) else "CERRADO",
			"pisable" if bool(report["destino_pisable"]) else "CERRADO",
			"pisable" if bool(report["hito_pisable"]) else "CERRADO",
			"si" if bool(report["anda_al_hito"]) else "NO"])
		# El ESTADO va en el parte y no salia impreso, y es la mitad de la
		# respuesta: «llego y el estado no se entero» no dice lo mismo si el
		# estado es «de camino» -no vio su sim.tajo- que si es «volviendo» -no vio
		# su abrigo-.
		lines.append("      estado %s · hora %s" % [
			Inhabitant.new_state_name(int(report["estado"])),
			"de vuelta" if float(report["hora"]) >= SettlementSim.HORA_REGRESO else "de jornada"])
		lines.append("      bloqueos %d · paso %.3f de lo normal" % [
			int(report.get("bloqueos", 0)), float(report.get("paso", 1.0))])
		lines.append("      zona %d -> %d · pendiente %.2f · vado %.2f" % [
			int(report["zona_aqui"]), int(report["zona_destino"]),
			float(report["pendiente"]), float(report["vado"])])
	return "\n".join(lines)


## El punto pisable mas cercano a otro.
##
## Es la contrapartida obligatoria de que mande la rejilla: si nadie puede
## PISAR una celda cerrada, un sim.tajo que caiga en una se vuelve inalcanzable, y
## la banda perderia parajes buenos por un metro de rio. Amarrandolo a la
## orilla abierta de al lado se trabaja igual y se llega siempre.
func _firm_ground(point: Vector3) -> Vector3:
	var grid := _navgrid()
	if not grid.is_ready():
		return point
	if grid.cost[grid.cell_of(point)] > Navgrid.BLOCKED:
		return point

	var cell := grid.nearest_open(point, 4)
	if cell < 0:
		return point
	var firm := grid.point_of(cell)
	if sim._terrain:
		firm.y = sim._terrain.get_height_at(firm)
	return firm
