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
		if person.route_step >= person.route.size() \
				and person.position.distance_to(person.target) > sim.arrive_radius * 2.0:
			_send_to(person, person.target)

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
			if libre.length() > CATA_DEL_PASO * 0.5:
				step = libre
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
				if left_ok and (not right_ok
						or left.distance_to(person.target) < right.distance_to(person.target)):
					step = side
				elif right_ok:
					step = -side
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

			person.position += step
			person.note_step(step.length(), sim.home_position)
			if step.length() > 0.01:
				person.blocked_steps = 0
				person.blocked_replans = 0
				# Sólo un paso con recorrido real gira a la persona; uno de
				# longitud cero -parada, bloqueo- no dice hacia dónde mira.
				sim._headings[index] = atan2(step.x, step.z)
			person.position.y = sim._terrain.get_height_at(person.position)
			# Andar cansa. Hace falta para que la batida tenga final: sin esto
			# el explorador nunca acumulaba fatiga y no volvia jamas.
			person.fatigue = clampf(
				person.fatigue + hours * 2.6 * person.fatigue_factor(), 0.0, 100.0)


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
	# de vacio, para no tocar la escala de tiempo que ya estaba calibrada
	var reference := Traversal.travel_speed(0.0, Traversal.Ground.PASTO, 0.0)
	var here := Traversal.travel_speed(slope, ground, load)

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
	var ratio := maxf(here / maxf(reference, 0.001), SettlementSim.MIN_PACE)
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
		return Hydrography.can_cross(
			sim._terrain.crossing_difficulty_at(world_position),
			sim.has_boat, sim.has_bridge)

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
func _send_to(person: Inhabitant, destination: Vector3) -> void:
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
		return

	# Todo destino se amarra a celda abierta ANTES de nada. Lo hacia solo el
	# buscador de caminos, asi que `_best_known_spot` y compania seguian
	# mandando gente a tajos que la rejilla da por cerrados.
	destination = _firm_ground(destination)
	person.target = destination

	# Si el destino esta en otra ZONA del mapa no hay camino, y saberlo no
	# cuesta nada: la rejilla trae marcados los trozos comunicados entre si.
	# Antes esto era una busqueda exhaustiva de doce mil nodos, y se lanzaba
	# cada vez que alguien apuntaba al otro lado de un rio.
	if not _navgrid().connected(person.position, destination):
		person.route = PackedVector3Array()
		person.route_step = 0
		person.unreachable = destination
		return

	# El presupuesto se mira antes de buscar. Quien va sin camino pasa
	# igualmente, o se quedaria parado para siempre; pero solo uno por
	# fotograma, que es lo que impide que la manana en que la banda entera
	# sale a la vez se coma medio segundo.
	if sim._path_nodes_this_frame >= SettlementSim.NODES_PER_FRAME:
		if not person.route.is_empty():
			return
		if sim._stranded_this_frame > 0:
			return
		sim._stranded_this_frame += 1

	# La banda repite trayectos: los mismos quince salen del mismo abrigo a
	# los mismos cuatro tajos todas las mananas y vuelven por donde fueron.
	# Buscar de nuevo un camino que ya se busco ayer es el gasto mas tonto que
	# habia, asi que se guarda por par de celdas.
	var lane := _lane_key(person.position, destination)
	var kept: Variant = sim._route_cache.get(lane, null)
	if kept != null:
		person.route = _retarget(kept as PackedVector3Array, destination)
		person.route_step = 0
		person.unreachable = Vector3.ZERO
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
		return

	person.route = route
	person.route_step = 0
	person.unreachable = Vector3.ZERO


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
			GameState.season as Subsistence.Season, Temporada.CAUDAL)
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


func _lane_key(from_point: Vector3, to_point: Vector3) -> String:
	return "%d_%d>%d_%d" % [
		int(from_point.x / SettlementSim.LANE_CELL), int(from_point.z / SettlementSim.LANE_CELL),
		int(to_point.x / SettlementSim.LANE_CELL), int(to_point.z / SettlementSim.LANE_CELL)]


func _remember_route(lane: String, route: PackedVector3Array) -> void:
	if not sim._route_cache.has(lane):
		sim._route_order.append(lane)
	sim._route_cache[lane] = route

	# Se suelta lo mas viejo. Sin tope, una partida larga se llena de rutas de
	# sitios donde la banda no ha vuelto a poner un pie.
	while sim._route_order.size() > SettlementSim.ROUTE_CACHE_LIMIT:
		var oldest: String = sim._route_order[0]
		sim._route_order.remove_at(0)
		sim._route_cache.erase(oldest)


## El camino guardado, con el ultimo tramo llevado al destino exacto.
##
## El camino se guardo entre CELDAS, asi que su final es el centro de una
## celda y no el sitio al que va esta persona. Los tramos de en medio valen
## igual -son los mismos cuarenta metros de terreno-, pero el ultimo hay que
## rematarlo o se dejaria a la gente parada a veinte metros de su sim.tajo.
func _retarget(route: PackedVector3Array, destination: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array(route)
	if out.is_empty():
		out.append(destination)
	else:
		out[out.size() - 1] = destination
	return out


## Se tiran los caminos guardados. Lo llama quien cambie el terreno o lo que
## se puede cruzar: un camino de antes del puente ya no es el mejor.
func forget_routes() -> void:
	sim._route_cache.clear()
	sim._route_order.clear()


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
	var arrived := person.position.distance_to(person.target) < sim.arrive_radius * 1.5

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
	if person.position.distance_to(person.stuck_where) > SettlementSim.STUCK_SLACK:
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
		"lejos_hito": person.position.distance_to(waypoint),
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
