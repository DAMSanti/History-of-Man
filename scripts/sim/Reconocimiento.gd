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
			target = _least_known_around(sim.home_position,
				BATIDA_RADIUS, Cumbres.PEAK_SEARCH_RADIUS, person)

	# Ni el rumbo del jugador se salta esto: una partida corta no se
	# aventura al borde del mapa por mucho que se le señale. Se queda
	# repasando lo que tiene mas cerca hasta que se sume mas gente.
	if target.distance_to(sim.home_position) > Despensa.REGIONAL_DISTANCE \
			and sim.despensa._expedition_party_size() < Despensa.MIN_GROUP_FOR_REGIONAL:
		target = _least_known_around(sim.home_position,
			BATIDA_RADIUS, Despensa.REGIONAL_DISTANCE, person)

	target.y = sim._terrain.get_height_at(target)
	return target


## Destino de una BATIDA: el entorno inmediato del campamento, no la frontera.
##
## Radio corto y punto aleatorio dentro de el, sin fan-out entre batidores
## -a diferencia de `_scout_target`- porque el objetivo no es repartirse el
## territorio entero, es peinar los alrededores. Con `arrive_radius` de por
## medio, en pocas jornadas cubre el circulo entero por simple variacion.
const BATIDA_RADIUS := 380.0


func _batida_target(person: Inhabitant) -> Vector3:
	# Lo primero, un paraje a medio investigar. Es lo que de verdad hace una
	# batida: no descubrir monte nuevo -eso es la expedicion- sino acabar de
	# conocer lo que ya se ha encontrado. Un avellanar del que solo se sabe
	# que tiene avellanas es un avellanar a medias.
	var pending := sim._paraje_to_survey(person)
	if pending != null:
		return pending.position

	# Y si no queda ninguno, se peina el entorno buscando sim.parajes nuevos
	return _least_known_around(sim.home_position, BATIDA_RADIUS * 0.35,
		BATIDA_RADIUS, person)


## Cuantos sitios se miran antes de elegir adonde batir.
##
## Doce da para cubrir el circulo sin que la eleccion cueste nada: son doce
## consultas al mapa mental, no doce busquedas de camino.
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
			if sim._terrain.crossing_difficulty_at(side) > 0.15:
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

	for i in range(SCAN_CANDIDATES):
		# En abanico y no al azar, para que el barrido cubra el circulo
		var angle := (float(i) + sim._rng.randf()) / float(SCAN_CANDIDATES) * TAU
		var radius := sim._rng.randf_range(near, far)
		var candidate := centre + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		if sim._terrain:
			candidate.y = sim._terrain.get_height_at(candidate)
			if not Traversal.is_passable(sim._terrain.get_slope_at(candidate),
					sim._terrain.crossing_difficulty_at(candidate),
					sim.has_boat, sim.has_bridge):
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
		for other: Inhabitant in sim.people:
			if other != person and other.job == Profession.Job.EXPLORACION \
					and _exploration_anchor(other).distance_to(candidate) < 120.0:
				known += 0.5
		best.append({"pos": candidate, "known": known})

	if best.is_empty():
		return centre

	best.sort_custom(func(a, b): return float(a["known"]) < float(b["known"]))
	var pick: Dictionary = best[sim._rng.randi() % mini(3, best.size())]
	return pick["pos"]


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

	# "Mismo trozo de monte" es "misma zona de la rejilla de navegacion":
	# no hace falta un rio de por medio para que dos celdas cercanas sean
	# sitios distintos, basta con que no se pueda ir de una a otra sin
	# rodear. Es lo mismo que ya usa `_scout_target` para saber si se
	# puede llegar a un sitio, aplicado ahora a si dos sitios son el mismo.
	var grid := sim.marcha._navgrid()
	var same_patch := func(a: Vector3, b: Vector3) -> bool:
		return grid.connected(a, b)
	sim.parajes.refresh(sim.field, sim.knowledge, sim.day, [
		Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
		Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
		Subsistence.Activity.MATERIA_PRIMA], sim._terrain, same_patch)

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
	sim._new_ground_surveys_today.clear()


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
	person.survey_hours += hours
	var needed := _survey_hours_for(person)
	person.fatigue = clampf(
		person.fatigue + hours * 4.0 * person.fatigue_factor(), 0.0, 100.0)

	# Batir la comarca ES la enseñanza, no un aparte de ella: `_learn_from`
	# -que enseña el YENDO y el TRABAJANDO- no corre en RECONOCIENDO, así
	# que las horas de sim.reconocimiento -que son la mayor parte del viaje de
	# una expedición- no enseñaban nada de nada. La familiaridad nunca
	# llegaba al umbral de nombrar un paraje nuevo por mucho que la banda
	# saliera a explorar: esto es lo que de verdad apagaba el descubrimiento.
	if sim.knowledge:
		sim.knowledge.see_from(person.position, sim.sight_range * sim.weather.sight_factor())
		var pace := hours / 24.0
		for activity: int in sim._activities_for_learning(person):
			sim.knowledge.observe(activity as Subsistence.Activity, person.position, pace)

	if person.current_speciality == Profession.Speciality.BATIDA:
		_grow_batida_skill(person, hours * BATIDA_REPETITION_RATE,
			BATIDA_REPETITION_CEILING)

	if person.work_centre == Vector3.ZERO:
		person.work_centre = person.position

	# Se BATE la comarca: se da la vuelta al punto por tramos, subiendo al
	# alto de al lado, bajando al arroyo, mirando el cortado.
	#
	# Antes se quedaba clavado nueve horas y luego decia «explorado». Y el
	# fallo no era del sorteo del siguiente tramo sino de la ruta: al llegar
	# quedaba el camino del viaje a medio consumir, y `next_waypoint` devuelve
	# el hito del camino ANTES que el destino, asi que por mucho que se
	# cambiara el destino la persona seguia apuntando al sitio donde ya
	# estaba.
	var arrived := person.position.distance_to(person.forage_target) < sim.arrive_radius
	if arrived or person.route_step >= person.route.size():
		_next_survey_leg(person)

	if person.survey_hours >= needed:
		_finish_survey(person)


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
	var here := sim._paraje_at(person.work_centre)
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
				if sim._rng.randf() < person.skill_in(batida_task) * CHAIN_REVEAL_FACTOR:
					reveals += 1
	elif here == null:
		# Monte sin nombre. RECONOCER ES DESCUBRIR, y lo es para cualquiera.
		#
		# Esto sólo lo hacía la exploración, y el efecto era que un recolector
		# podía pasarse la vida trabajando un avellanar sin que el sitio llegara
		# a tener nombre nunca: la banda tenía que mandar aparte a un explorador
		# a "descubrir" un sitio en el que ya estaba trabajando. Ahora una
		# jornada entera batiendo un sitio nuevo basta para saber qué hay allí,
		# lo mismo que ya valía para el batidor.
		#
		# Lo que sigue distinguiendo al explorador es el ALCANCE de lo que
		# aprende: él abre el sitio para todos los oficios -para eso bate la
		# comarca entera- y los demás sólo para el suyo. Ver
		# `_activities_for_learning`.
		if sim.knowledge:
			for activity: int in sim._activities_for_learning(person):
				sim.knowledge.reveal(activity as Subsistence.Activity,
					person.work_centre, BandKnowledge.KNOWN_ENOUGH + 0.02)

		# El hito de exploración sí es sólo suyo: `_credit_new_ground` premia
		# destreza DE EXPLORACIÓN, y dársela a un recolector por recoger sería
		# pagarle dos veces por la misma jornada.
		if is_batida or opens_ground:
			sim._new_ground_surveys_today.append({"person": person,
				"position": person.work_centre, "speciality": speciality})

	# Que contar. Encontrar algo en un paraje manda siempre sobre el repaso
	# generico del terreno -"hay caza", "monte y piedra"-: una batida que
	# vuelve con novedades de verdad no puede leerse igual que una que no
	# encontro nada, ni en la cronica ni en el rastro.
	var outcome: String
	if not discovered.is_empty():
		outcome = "investig\u00f3 %s y encontr\u00f3 %s" % [where, ", ".join(discovered)]
		sim._note(Chronicle.Kind.HALLAZGO,
			"%s investig\u00f3 %s y encontr\u00f3 %s. Se sabe el %.0f%% de lo que hay."
				% [person.given_name, here.name_text, ", ".join(discovered),
					here.known_fraction() * 100.0], 1)
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


## El siguiente tramo de la batida.
##
## Las direcciones se reparten en abanico alrededor del punto en vez de
## sortearse: sorteadas salian tres tramos seguidos hacia el mismo lado, que
## parece que la persona no sabe lo que hace. En abanico se ve que esta
## rodeando el sitio.
func _next_survey_leg(person: Inhabitant) -> void:
	for attempt in range(3):
		# Al trozo de alrededor que menos se conozca: reconocer es rellenar
		# los huecos del mapa, no dar vueltas por lo ya visto
		var candidate := _least_known_around(person.work_centre,
			SettlementSim.SURVEY_RADIUS * 0.45, SettlementSim.SURVEY_RADIUS, person)

		# El camino se traza de nuevo. Es lo que suelta el hito viejo que
		# tenia a la persona clavada donde llego: `next_waypoint` devuelve el
		# hito ANTES que el destino, asi que cambiar el destino no bastaba.
		person.route = PackedVector3Array()
		person.route_step = 0
		person.forage_target = candidate
		sim.marcha._send_to(person, candidate)

		if not person.route.is_empty() \
				or candidate.distance_to(person.position) < sim.arrive_radius * 2.0:
			return

	# Si de verdad no hay por donde salir, se bate lo que se tenga a mano en
	# vez de quedarse mirando la nada
	var angle := sim._rng.randf() * TAU
	var near := person.position + Vector3(
		cos(angle) * sim.arrive_radius * 2.5, 0.0, sin(angle) * sim.arrive_radius * 2.5)
	if sim._terrain:
		near.y = sim._terrain.get_height_at(near)
	person.forage_target = near
	person.target = near


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


