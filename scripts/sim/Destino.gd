class_name Destino
extends RefCounted
## Donde se pone cada uno en el abrigo, y a que tajo se le manda.
##
## Sale de `SettlementSim` en la segunda pasada (ARQUITECTURA §3.2). Es el tema
## de EN QUE SITIO esta la gente: el hueco que ocupa en casa segun lo que hace,
## la salida por la boca de la cueva, cuando se da por llegado, y a que punto
## del valle se le manda a trabajar con lo que sabe la banda.
##
## No se confunda con [Marcha], que es ANDAR -trazar el camino y seguirlo-, ni
## con [Rutina], que es QUE hace cada uno y cuando. Aqui solo esta el DONDE.
##
## **El estado se queda en el simulador** y aqui se pide por `sim.`: ver la nota
## de `SettlementSim.berrea_hasta_el_dia`.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Dónde se pone esta persona cuando está en el abrigo, según lo que hace.
##
## Estable por `id`, igual que el carril de la marcha y el reparto del tajo: si
## se sorteara cada vez, la banda temblaría dentro de la cueva.
func _home_spot(person: Inhabitant, inside: bool) -> Vector3:
	var centre := sim.home_inside if inside else sim.home_forecourt
	if centre == Vector3.ZERO:
		centre = sim.home_position
	# AL CORRO DEL FUEGO, si hay hogar levantado y queda sitio en los troncos.
	# Es lo que pidió el usuario el 2026-09-13: que la banda se junte alrededor
	# de la hoguera —ociosos, comiendo, al hogar o tallando en el abrigo— en vez
	# de repartirse por la campa. Los que no cogen sitio siguen como siempre.
	# Ver [CorroDelHogar].
	if not inside and sim.camp_built.get(CampProjects.Kind.HOGAR, false) \
			and sim.home_forecourt != Vector3.ZERO:
		var asiento := CorroDelHogar.asiento_de(sim.home_forecourt, sim.people.find(person))
		if asiento != Vector3.ZERO:
			if sim._terrain:
				asiento.y = sim._terrain.get_height_at(asiento)
			return asiento

	var spread := sim.CAVE_SPREAD if inside else sim.FORECOURT_SPREAD
	var angle := TAU * fmod(float(person.id) * 0.618, 1.0)
	var reach := spread * (0.35 + fmod(float(person.id) * 0.37, 0.65))
	var spot := centre + Vector3(cos(angle), 0.0, sin(angle)) * reach
	# Dentro de la cueva la altura es la del SUELO DE LA CUEVA, que la trae el
	# punto de referencia; preguntársela al terreno pondría a la gente encima
	# del monte que tapa la galería. Fuera sí manda el terreno.
	if sim._terrain and not inside:
		spot.y = sim._terrain.get_height_at(spot)
	else:
		spot.y = centre.y
	return spot


## Si alguien esta YA en el abrigo, campa de la boca incluida.
##
## Se miraba con `distance_to(home_position) < arrive_radius`, y eso deja la
## puerta fuera de casa: la campa esta a su propia distancia del punto del
## abrigo y la gente se reparte por ella hasta [FORECOURT_SPREAD], asi que
## quien estaba plantado delante de la cueva caia fuera del radio de llegada.
## A la hora de recogerse se le mandaba «a casa» estando en casa: VOLVIENDO,
## tres metros, llegar, ocioso, `_settle_at_home` lo devolvia a la campa, y
## otra vez. Medido en el sitio 56 con la banda entera ocho jornadas: el 3,8 %
## de las horas de luz figuraba como «volviendo» a menos de treinta metros de
## la boca.
##
## El alcance no es un numero elegido: es hasta donde llega la propia campa.
func _at_shelter(person: Inhabitant) -> bool:
	return person.position.distance_to(sim.home_position) <= _shelter_reach()


## TRES PREGUNTAS DISTINTAS SOBRE «ESTAR EN CASA», Y HAY QUE SABER CUAL SE HACE.
##
## Estaban las tres escritas a mano y repartidas, con cuatro numeros distintos
## para lo que parecia lo mismo. No lo es, y por eso siguen siendo tres; lo que
## no puede ser es que cada sitio se invente el suyo:
##
##   `_at_shelter`      ESTAR DENTRO. La galeria y la campa —ver
##                      [_shelter_reach]—. Es la de dormir, comer y repartirse
##                      sitio, y su alcance sale de donde se pone la gente.
##   `_home_reached`    HABER LLEGADO. Lo anterior, o sin camino por delante y
##                      a menos de una celda: la rejilla no sabe dejar a nadie
##                      mas cerca. Es la de entregar la carga y cerrar la
##                      salida.
##   `_saliendo_de_casa` SALIR DE AQUI. Un radio mas ancho, porque la pregunta
##                      es «¿empieza esta jornada en el campamento?» y quien
##                      esta a veinte metros la empieza en el campamento.
##
## El numero de la tercera era `arrive_radius * 4.0` escrito en cinco sitios.
## Aqui esta una vez.
func _saliendo_de_casa(person: Inhabitant) -> bool:
	return Traversal.en_llano(person.position, sim.home_position) <= SALIDA_DE_CASA


## Hasta donde se cuenta que una jornada empieza EN el campamento.
##
## Veinticuatro metros: cuatro veces el radio de llegada, que es el numero que
## ya estaba repartido por el fichero. Se le pone nombre para poder discutirlo
## en un sitio en vez de en cinco.
const SALIDA_DE_CASA := 24.0


## Hasta donde llega el abrigo, en metros.
##
## No es un numero elegido: es lo que ocupan de verdad la galeria y la campa,
## que es donde `_home_spot` reparte a la gente. Si el abrigo se muda -ver
## `move_home`- el alcance se muda con el.
func _shelter_reach() -> float:
	# El reparto existe con cueva y sin ella: cuando no hay boca marcada
	# `_home_spot` reparte alrededor del propio punto del abrigo, con la misma
	# holgura. Partir del radio de llegada a secas dejaba fuera de casa, otra
	# vez, a quien cayera en el borde de la campa.
	var reach := maxf(sim.arrive_radius, maxf(sim.CAVE_SPREAD, sim.FORECOURT_SPREAD))
	if sim.home_forecourt != Vector3.ZERO:
		reach = maxf(reach,
			sim.home_position.distance_to(sim.home_forecourt) + sim.FORECOURT_SPREAD)
	if sim.home_inside != Vector3.ZERO:
		reach = maxf(reach,
			sim.home_position.distance_to(sim.home_inside) + sim.CAVE_SPREAD)
	return reach


## Si quien vuelve ya ha llegado, aunque no pise el punto exacto del abrigo.
##
## Llegar se medía con seis metros al punto del abrigo, y el camino de vuelta
## no lo traza una persona: lo traza la rejilla, que no llega mas fino que su
## celda -cuarenta metros- y ademas amarra el destino al suelo firme mas
## cercano, ver `_firm_ground`. O sea que la ruta se acaba legitimamente a
## veinte metros de la boca y alli ya no queda camino que andar.
##
## Lo que pasaba entonces no era un atasco -no hay ruta que seguir- sino algo
## peor y mas callado: no se entregaba la carga, no se cerraba la salida, no
## se cenaba y no se dormia, porque los cuatro se preguntaban lo mismo. La
## persona se quedaba de pie en la puerta hasta que a la mañana siguiente
## `_send_to_work` le tiraba la carga entera a la basura -ver `lost_loads`-.
##
## Medido en el sitio 56, la banda entera ocho jornadas: 264 horas-persona
## plantadas entre seis y cuarenta metros del abrigo en estado «volviendo»,
## frente a 282 andando de verdad. Y en las salidas de recoleccion que volvian
## de vacio -el 85 %-, cuatro horas y tres cuartos de «volviendo» contra una
## centesima de hora trabajando.
func _home_reached(person: Inhabitant) -> bool:
	if _at_shelter(person):
		return true
	# Con camino por delante todavia se esta volviendo de verdad.
	if person.route_step < person.route.size():
		return false
	# Sin camino y a una celda de la boca, se ha llegado: mas cerca no sabe
	# dejar a nadie la rejilla.
	return person.position.distance_to(sim.home_position) <= Navgrid.CELL


## Coloca a quien está en el abrigo dentro o en la puerta, según el estado.
##
## Se llama al final del tick de cada persona y sólo toca a quien ya está en
## casa: si tocara a quien va de camino, lo teletransportaría a media marcha.
func _settle_at_home(person: Inhabitant, delta: float) -> void:
	if not _home_reached(person):
		return
	# En casa no hay vivac que valga: se duerme en la cueva.
	person.bivouac_fire = false
	var spot := Vector3.ZERO
	match person.state:
		Inhabitant.State.DURMIENDO:
			spot = _home_spot(person, true)
		Inhabitant.State.OCIOSO, Inhabitant.State.COMIENDO:
			spot = _home_spot(person, false)
		Inhabitant.State.TRABAJANDO:
			# El hogar y el taller trabajan en la campa de la boca. Al de
			# monte no le toca: su sitio es el tajo.
			if not sim.hogar._works_at_camp(person):
				return
			spot = _home_spot(person, false)
		_:
			return
	# Los ultimos metros se ANDAN, no se aparecen.
	#
	# Antes esto colocaba a la gente de golpe, y valia porque solo tocaba a
	# quien ya estaba a tres radios de llegada. Ahora recoge a cualquiera que
	# haya llegado -y llegar es agotar el camino a una celda de la boca, ver
	# `_home_reached`-, asi que el salto podia ser de cuarenta metros: gente
	# apareciendose en la puerta a la vista del jugador. Medido: 88
	# horas-persona plantadas entre dieciocho y cuarenta metros del abrigo.
	person.position = person.position.move_toward(spot, sim.walk_speed * delta)


## El motivo de renunciar a un destino, con nombre fijo para poder contarlo.
const RENUNCIA := "por ahi no se pasa"


## Manda a alguien a su tajo, o a buscarlo si no sabe donde esta.
##
## Es la mecanica que pediste: sin conocimiento NO se va en linea recta a un
## punto, porque nadie sabe donde esta ese punto. Se sale hacia una zona con
## el recurso y se bate hasta encontrarlo.
func _send_to_work(person: Inhabitant) -> void:
	# Lo primero, qué se hace hoy: quien no tiene especialidad fijada la elige
	# según lo que más falte
	Cronometro.tramo("tajo: elegir especialidad")
	person.current_speciality = sim._choose_speciality(person)
	Cronometro.cierra("tajo: elegir especialidad")
	# La actividad la manda la ESPECIALIDAD, no el oficio: «cantera» y
	# «fruto y raiz» son el mismo oficio para el jugador y dos sitios muy
	# distintos del monte para el terreno.
	person.activity = Profession.activity_of(
		person.job as Profession.Job,
		person.current_speciality as Profession.Speciality)
	# Lo que lleve encima se entrega ANTES de salir de nuevo. Estaba
	# limpiandose sin mas, asi que quien acababa la jornada sin pasar por el
	# abrigo -porque se atasco, porque se le cambio el oficio- perdia la carga
	# entera y nadie se enteraba: entre lo traido y lo guardado faltaba un
	# tercio de TODO, y el reparto era identico material a material, que es la
	# firma de una fuga y no de un gasto.
	if not person.load.is_empty():
		if _home_reached(person):
			sim.despensa._deliver(person)
		else:
			sim.lost_loads += 1
	person.load.clear()
	person.carrying = 0.0
	person.search_hours = 0.0

	# Los recipientes se cogen al salir, y DESPUES de entregar: `_deliver`
	# los devuelve al abrigo, asi que repartirlos antes era dejar salir a la
	# gente con las manos vacias.
	sim.despensa._hand_out_containers(person)

	# EL CAZADOR MAYOR SE AVITUALLA, como el explorador. Una pieza grande no se
	# cobra entre el desayuno y la cena -medido: con caza de jornada salian una
	# a tres piezas en seis dias con ochenta y cuatro cacerias levantadas- y
	# seguir un rastro dos jornadas pide llevar de comer. Sin provisiones sale
	# igual: lo que no puede es dormir fuera, y eso ya lo mira `_camps_out`.
	if person.current_speciality == Profession.Speciality.CAZA_MAYOR:
		sim.despensa._provision(person, sim.CAZA_LEJOS_M)

	# El taller NO sale a picar piedra. Su oficio figura con la actividad
	# «materia prima» -es de donde saca lo que gasta- y eso le mandaba al
	# canchal como si fuera un recolector: se veia al tallador cruzando el
	# valle para traer cantos que cualquiera de los que ya estan fuera podia
	# haber traido de paso.
	#
	# Sale SOLO cuando de verdad falta lo que necesita para la pieza que toca,
	# y entonces es un recado, no una jornada de cantera.
	if person.job == Profession.Job.MANUFACTURA and not sim.taller._workshop_short(person):
		person.has_task = true
		person.work_centre = sim.home_position
		person.forage_target = sim.home_position
		person.state = Inhabitant.State.TRABAJANDO
		return

	# Se prueban VARIOS tajos, no uno.
	#
	# Antes se pedia el mejor, y si no habia camino la persona se quedaba
	# ociosa en el campamento «en vez de salir a estrellarse contra el rio»
	# —y se quedaba asi PARA SIEMPRE, reintentando el mismo destino imposible
	# cada tick de cada dia. Medido en el sitio 56 con gente puesta en la
	# pesca de orilla: veinte jornadas seguidas ociosa, ruta 0, hambre 100,
	# sin una sola salida que pintar en los rastros. Desde fuera parecia que
	# el oficio no hacia nada, que es literalmente lo que pasaba.
	# SIN FUENTE CONOCIDA NO SE SALE A UN TAJO: SE SALE A INVESTIGAR.
	#
	# «Los trabajadores que no saben dónde hay recursos simplemente echan a
	# andar en línea recta hasta que se acaba el día. Quiero que si no tienen
	# una fuente conocida en un paraje, se dediquen a investigar la zona
	# alrededor del asentamiento».
	#
	# Y es que lo de antes no era investigar: se elegía un punto lejano por su
	# abundancia supuesta, se andaba hasta él, no se conocía el sitio, se
	# prospectaba un rato y se probaba en otro. La jornada se iba en el camino
	# y no quedaba nada aprendido.
	#
	# Reconocer el entorno sí deja algo: revela terreno —y con él nacen parajes,
	# ver [Reconocimiento]—, y de paso se recoge lo que se encuentra.
	Cronometro.tramo("tajo: ¿hay sitio?")
	person.investigando = sim.barbecho.sin_sitio(person.activity)
	Cronometro.cierra("tajo: ¿hay sitio?")
	if person.investigando:
		Cronometro.tramo("tajo: donde investigar")
		var mirar := sim.reconocimiento._least_known_around(sim.home_position,
			Reconocimiento.BATIDA_RADIUS * 0.25,
			Reconocimiento.BATIDA_RADIUS, person)
		Cronometro.cierra("tajo: donde investigar")
		# Ruta vacia antes de pedirla, para que «hay camino» hable de ESTE
		# destino y no del anterior. Ver el bucle de candidatos de mas abajo.
		person.route = PackedVector3Array()
		person.route_step = 0
		sim.marcha._send_to(person, mirar)
		if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
			# No se ha mirado. Ver [Marcha.Traza].
			person.state = Inhabitant.State.OCIOSO
			return
		if not person.route.is_empty():
			person.has_task = true
			if person.journey.is_empty():
				person.begin_journey("Investigar el entorno", sim.day, sim.hour,
					sim.home_position)
			person.state = Inhabitant.State.YENDO
			return

	# Se prueban por orden y se coge el primero AL QUE MEREZCA LA PENA IR. Que
	# exista camino no basta: el avellanar de enfrente esta comunicado por un
	# vado a kilometro y medio, y esa ruta es perfectamente valida.
	#
	# «Lo que no quiero nunca es que se vayan mas lejos de lo necesario, no
	# tiene sentido alejarse 2000 m si hay parajes sin descubrir a 500 m». Ver
	# [Marcha.merece_el_camino].
	var destination := Vector3.ZERO
	var descartados := 0
	var sin_mirar := false
	Cronometro.tramo("tajo: lista de candidatos")
	var candidatos := _work_candidates(person)
	Cronometro.cierra("tajo: lista de candidatos")
	for candidate: Vector3 in candidatos:
		# La ruta se vacia antes de pedir la del siguiente. Sin esto, a un
		# candidato que `_send_to` descarta de entrada -por sabido imposible,
		# o por presupuesto- se le mide la ruta del candidato ANTERIOR: se le
		# da por bueno un camino que no es suyo y se manda a la persona a un
		# sitio al que no se le ha trazado nada.
		person.route = PackedVector3Array()
		person.route_step = 0
		Cronometro.tramo("tajo: probar candidato")
		sim.marcha._send_to(person, candidate)
		Cronometro.cierra("tajo: probar candidato")

		# Y SI NO SE HA MIRADO, NO SE CONCLUYE NADA.
		#
		# Cada candidato cuesta una busqueda y el presupuesto del cuadro son
		# unos pocos nodos; agotado, los que quedan vuelven con la ruta vacia
		# SIN HABERSE MIRADO. Leyendo eso como «no hay camino» se cerraba el
		# oficio entero por la manana: medido en el sitio 56, seis personas la
		# jornada 1 con «no hay camino hasta ningun tajo» a 211 m de casa y la
		# rejilla diciendo que estaban en la misma zona.
		#
		# Lo que toca es dejarlo para el cuadro siguiente, que llega en
		# milesimas. Ver [Marcha.Traza].
		if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
			sin_mirar = true
			break

		if sim.marcha.merece_el_camino(person, candidate):
			destination = candidate
			break
		if not person.route.is_empty():
			descartados += 1

	if destination == Vector3.ZERO and sin_mirar:
		# Ni se sale ni se cierra el oficio: se vuelve a intentar enseguida.
		person.state = Inhabitant.State.OCIOSO
		return

	# Si TODOS los candidatos salian por un rodeo que no se anda, se apunta:
	# es un dato distinto de «no hay camino» y se lee distinto en los atascos.
	if destination == Vector3.ZERO and descartados > 0:
		sim.marcha._record_stuck(person, "a los %d tajos de %s que conoce solo se "
			% [descartados, Subsistence.activity_name(person.activity).to_lower()]
			+ "llega dando la vuelta al agua")

	if destination == Vector3.ZERO:
		# A ningun tajo de este oficio se llega hoy. Se apunta —para que salga
		# en los atascos y no en el silencio— y se marca la actividad como
		# inalcanzable, que es lo que hace que el reparto de manana lo baje a
		# su siguiente oficio en vez de dejarlo mirando el rio desde casa.
		sim.marcha._record_stuck(person, "no hay camino hasta ningun tajo de %s"
			% Subsistence.activity_name(person.activity).to_lower())
		sim._unreachable_today[int(person.activity)] = true
		person.has_task = true
		person.state = Inhabitant.State.OCIOSO
		return

	# La jornada de trabajo tambien es una salida, con su camino y su
	# resultado. Solo las abrian los exploradores, y por eso en los rastros no
	# se pintaba nada mas que exploracion: el resto de la banda no tenia
	# ninguna salida que dibujar.
	if person.journey.is_empty():
		person.begin_journey(Profession.job_name(person.job as Profession.Job),
			sim.day, sim.hour, sim.home_position)
	person.state = Inhabitant.State.YENDO

## Cuanta agua cubre un odre lleno, en horas.
##
## Una jornada util entera, y no es un numero elegido: ES la peticion. Un odre
## lleno tiene que dar para pasar el dia fuera, asi que se ata a [HORAS_UTILES]
## y se mueve con ella si algun dia cambia la jornada.
const SED_HORAS_CON_ODRE := sim.HORAS_UTILES

## Cuanto se aguanta sin odre desde el ultimo trago.
##
## Media jornada. Lo unico que la peticion fija es que TIENE que ser menos que
## el dia entero -sin odre no se pasa la jornada lejos del agua-; la mitad es
## el reparto neutro dentro de esa condicion y es el numero de aqui que esta
## pendiente de playtest. Subirlo hace el odre menos necesario; bajarlo obliga
## a la banda a trabajar pegada al rio.
const SED_HORAS_SIN_ODRE := sim.HORAS_UTILES * 0.5


## Los sitios adonde se puede mandar a trabajar a alguien, por orden de
## preferencia. El primero que tenga camino se lleva la jornada.
func _work_candidates(person: Inhabitant) -> Array[Vector3]:
	var out: Array[Vector3] = []
	Cronometro.tramo("candidatos: el mejor conocido")
	var best := sim.tajo._best_known_spot(person)
	Cronometro.cierra("candidatos: el mejor conocido")
	if best != Vector3.ZERO:
		out.append(best)

	# Si a este oficio no le queda un sitio conocido sin esquilmar, se sale a
	# BUSCAR. Va lo primero -por delante incluso del mejor conocido- porque en
	# ese caso el mejor conocido es un sitio muerto.
	#
	# Dos cosas distintas, y las dos hacen falta:
	#
	#   BUSCAR   el mejor sitio del entorno, mirando el campo de recursos. Es
	#            una mudanza y se hace sabiendo adonde se va. Ver
	#            [Barbecho.donde_buscar].
	#   TANTEAR  cuando no hay ni eso: una vuelta por el sector que toca -el
	#            margen del rio si es pescador- a ver que sale. Ver [Tanteo].
	#
	# El tanteo va DETRAS del buscar como candidato: si hay un sitio bueno al
	# alcance se va a el, y si no, se da la vuelta. Lo que ya no pasa es
	# quedarse en el abrigo.
	Cronometro.tramo("candidatos: ¿hay sitio?")
	var sin_sitio := sim.barbecho.sin_sitio(person.activity)
	Cronometro.cierra("candidatos: ¿hay sitio?")
	if sin_sitio:
		# LO PRIMERO, EL PARAJE DE LO SUYO MAS CERCANO CON «???».
		#
		# Por delante de buscar y de tantear, que son las dos formas de irse
		# lejos: un sitio con nombre a doscientos metros del que no se sabe lo
		# que tiene es mejor apuesta que el mejor punto del campo de recursos a
		# dos kilometros, y ademas deja algo aprendido. Ver
		# [Tajo._paraje_por_prospectar].
		Cronometro.tramo("candidatos: donde buscar")
		var buscando := sim.barbecho.donde_buscar(person.activity, person.position)
		Cronometro.cierra("candidatos: donde buscar")
		if buscando != Vector3.ZERO:
			out.insert(0, buscando)

		# Y este por delante de aquel: los dos van antes que el mejor conocido
		# -que aqui es un sitio muerto- pero prospectar un paraje que ya esta
		# en el mapa gana a mudarse a un punto del campo de recursos.
		Cronometro.tramo("candidatos: paraje por prospectar")
		var prospectar := sim.tajo._paraje_por_prospectar(person)
		Cronometro.cierra("candidatos: paraje por prospectar")
		if prospectar != Vector3.ZERO:
			out.insert(0, prospectar)
		Cronometro.tramo("candidatos: tanteo")
		var tanteando := sim.tanteo.adonde(person)
		Cronometro.cierra("candidatos: tanteo")
		if tanteando != Vector3.ZERO and not out.has(tanteando):
			out.append(tanteando)

	for entry: Dictionary in (sim._known_spots.get(person.activity, []) as Array):
		if out.size() >= sim.INTENTOS_DE_TAJO:
			break
		var spot: Vector3 = entry["pos"]
		if not out.has(spot):
			out.append(spot)

	# El sitio de reserva, que es el que se monto al fundar y no depende de
	# lo que la banda haya llegado a conocer
	if sim.work_sites.has(person.activity):
		var site: Vector3 = sim.work_sites[person.activity]
		if not out.has(site):
			out.append(site)

	# Y, en ultimo termino, prospectar: mejor salir a buscar que quedarse
	var search := sim.tajo._search_target(person)
	if search != Vector3.ZERO and not out.has(search):
		out.append(search)

	# Y NADA EN DESCANSO, sea del paso que sea. Los sitios conocidos y el de
	# reserva entraban aquí sin mirarlo: si el mejor sitio sano no tenía camino,
	# el pescador acababa en el tramo que descansaba y lo vaciaba hasta cero.
	# Queja del usuario del 2026-09-13, «siguen esquilmando parajes de pesca en
	# apenas unos meses». Ver `TestParajes.test_ningun_sitio_candidato_...`.
	var sanos: Array[Vector3] = []
	sanos.assign(out.filter(func(donde: Vector3) -> bool:
		return not sim._is_resting(person.activity, donde)))
	return sanos


## Cuánto más vale un paraje bautizado que monte anónimo igual de rico.
##
## Pendiente de playtest, como todo lo de balanceo. Lo decidido es que el sitio
## que el jugador ha visto nacer y nombrar sea al que la banda va.
const PARAJE_BONUS := 1.6


## Cuánto se busca la orilla alrededor de un tajo de agua, en metros.
const SHORE_SEARCH_M := 70.0

## Cuántos sitios se prueban antes de conformarse con uno sin agua al lado.
const SHORE_TRIES := 16

## Cuánto se estrecha la batida cuando se trabaja el agua.
##
## Un recolector bate setenta metros de mancha; un pescador no se aleja de la
## orilla, porque fuera de ella no hay nada que pescar. Con el radio entero, la
## mitad de los sitios que probaba caían tierra adentro.
const SHORE_FORAGE_FACTOR := 0.45

