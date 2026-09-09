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
##   [Parajes.NAMED_AT], que es lo que hace falta para bautizar un sitio
##   [Tajo.SE_PUEDE_TRABAJAR], lo que se exige para OFRECERLO como tajo
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
## Cuanto se conoce alrededor del sitio elegido, en metros.
##
## Ciento veinte: la mancha de un paraje, no la comarca. Lo que se conoce de
## acampar aqui una semana es DONDE ESTAN LAS COSAS, no todo lo que hay entre
## medias.
const MANCHA := 120.0

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
## UNO DE CADA OFICIO, no todo lo que haya. La primera version revelaba el
## terreno entero del radio y dejaba que [Parajes.refresh] bautizara lo que
## pasara del umbral: salian NUEVE parajes y LOS NUEVE DE RECOLECCION, porque
## es la actividad que mas celdas tiene por encima del listón. La banda
## empezaba sin saber donde pescar ni donde cazar, que es justo lo que habia
## que arreglar.
##
## Ahora se busca EL MEJOR SITIO DE CADA OFICIO dentro del radio y se conoce
## solo su entorno. El resto del valle sigue en blanco y se gana explorando.
func asentarse() -> int:
	if sim.field == null or sim.knowledge == null or sim.parajes == null:
		return 0

	var salen: Array[Paraje] = []
	for actividad: int in OFICIOS:
		var act := actividad as Subsistence.Activity
		# Se busca en la vuelta corta y, SI NO HAY NADA, se ensancha.
		#
		# Hace falta y no es un capricho: medido en el sitio 56, el rio queda a
		# 290 m del abrigo y el radio era 280, asi que la banda se asentaba
		# junto a un rio SIN SABER DONDE ESTABA EL AGUA. Lo primero que
		# reconoce cualquiera que acampa es donde beber y donde pescar, y si
		# esta un poco mas lejos se anda un poco mas.
		var donde := _el_mejor(act, RADIO)
		if donde == Vector3.ZERO:
			donde = _el_mejor(act, RADIO * 2.0)
		if donde == Vector3.ZERO:
			continue
		# Solo su entorno, no el radio entero: lo que se conoce es UN SITIO,
		# no la comarca.
		for celda: Vector2i in sim.field.cells_within(donde, MANCHA):
			var centre := sim.field.cell_center(celda.x, celda.y)
			if sim.field.abundance_cell(act, celda.x, celda.y) <= 0.0:
				continue
			# El SITIO se conoce; su alrededor, sólo se ha visto.
			#
			# Caía de 0,62 a 0,46 y las dos cifras pasan el listón de bautizar
			# —0,30—, así que la mancha entera quedaba lista para nombrarse y el
			# primer repaso de medianoche sacaba NUEVE parajes de golpe. Es la
			# queja del jugador por partida doble: ni salían cuatro el primer
			# día ni salían a medida que se descubren.
			#
			# Ahora el borde se queda por debajo del listón: hay dónde ir a
			# trabajar desde el primer día, y el sitio de al lado se bautiza
			# cuando alguien lo trabaje lo bastante.
			# En llano: `donde` trae la cota del terreno y `centre` sale de la
			# rejilla con y = 0. Ver [Traversal.en_llano], que es donde está
			# medido lo que costaba esta resta.
			var lejos := Traversal.en_llano(donde, centre) / MANCHA
			sim.knowledge.reveal(act, centre, lerpf(SABIDO,
				Parajes.NAMED_AT * 0.8, clampf(lejos, 0.0, 1.0)))

		# UNO, y de ESTE oficio. Se bautiza a mano y no se deja que lo haga el
		# barrido de [Parajes.refresh].
		#
		# El barrido abre TODOS los sitios que pasen el liston dentro de lo
		# conocido, asi que revelar cuatro manchas sacaba doce parajes el primer
		# dia y de los oficios que cayeran. Lo pedido es uno de caza, uno de
		# pesca, uno de recoleccion y uno de materia prima: cuatro, y el resto
		# se descubren andando.
		var celda := sim.field.cell_of(donde)
		var nacido := sim.parajes.bautizar(sim.field, act, celda.x, celda.y,
			sim.field.cell_center(celda.x, celda.y), sim.day, sim._terrain)
		if nacido != null:
			salen.append(nacido)

	if salen.is_empty():
		return 0

	# Estos cuatro NO levantan tarjeta de hallazgo uno por uno: se cuentan de
	# una vez, abajo. Cuatro «un sitio con nombre» seguidos en el primer minuto
	# de partida son ruido, no noticias.
	sim.parajes.just_found.clear()

	# Y la lista de tajos se rehace AQUI, no al cerrar la jornada.
	#
	# `_rank_known_spots` corre una vez al dia, asi que el dia 1 la banda
	# amanecia con cuatro parajes bautizados y CERO tajos conocidos: para
	# `Barbecho.sin_sitio` no habia donde trabajar, y los once salian a
	# investigar en vez de a recoger. La primera jornada entera perdida
	# sabiendo perfectamente donde estan las cosas.
	sim.tajo._rank_known_spots()

	sim._note(Chronicle.Kind.HALLAZGO,
		"La banda se asienta. De la primera vuelta al abrigo salen %d "
			% salen.size()
		+ "sitios con nombre: uno de cada oficio, lo que se ve desde la boca "
		+ "de la cueva.", 2)
	return salen.size()


## El mejor sitio de un oficio dentro del radio, o cero si no hay ninguno.
##
## Se pide ADEMAS que se pueda llegar: un avellanar al otro lado del rio no es
## un sitio que la banda «conozca de acampar aqui», es un sitio que ve.
func _el_mejor(act: Subsistence.Activity, hasta: float) -> Vector3:
	var mejor := Vector3.ZERO
	var mejor_nota := 0.0
	for celda: Vector2i in sim.field.cells_within(sim.home_position, hasta):
		var centre := sim.field.cell_center(celda.x, celda.y)
		var hay := sim.field.abundance_cell(act, celda.x, celda.y)
		# EL MISMO LISTON QUE BAUTIZA, no el de «aqui hay algo».
		#
		# `threshold_for` da 0,08 para la pesca y `refresh` pide ademas
		# [Parajes.WORTH_NAMING] -0,18-, asi que elegir por el primero podia
		# quedarse con un hilo de agua a doscientos metros que luego no daba
		# paraje: la banda acababa sin sitio de pesca teniendo un remanso al
		# 0,98 a quinientos metros. Medido en el sitio 56.
		if hay <= maxf(Parajes.WORTH_NAMING, sim.parajes.threshold_for(act)):
			continue
		# QUE SE LLEGUE DE VERDAD, y no solo que este comunicado.
		#
		# Estar en la misma zona de la rejilla solo dice que EXISTE un
		# camino; puede ser dar la vuelta al rio por un vado a kilometro y
		# medio. Es la queja del jugador: uno de los cuatro sitios del primer
		# dia salia al otro lado del agua, y comunicado lo estaba. Ver
		# [Marcha.alcanzable_de_verdad].
		if not sim.marcha.alcanzable_de_verdad(sim.home_position, centre):
			continue
		# Lo que hay, contra lo que cuesta llegar. Cerca y bueno gana a lejos y
		# mejor: es la vuelta al abrigo, no una expedicion.
		var lejos := Traversal.en_llano(sim.home_position, centre)
		var nota := hay * (1.0 - clampf(lejos / hasta, 0.0, 1.0) * 0.5)
		if nota > mejor_nota:
			mejor_nota = nota
			if sim._terrain:
				centre.y = sim._terrain.get_height_at(centre)
			mejor = centre
	return mejor
