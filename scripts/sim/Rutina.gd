class_name Rutina
extends RefCounted
## La jornada de una persona: que hace en cada tick y como decide el dia.
##
## Sale de `SettlementSim` en la segunda pasada (ARQUITECTURA §3.2) y es **el
## corte grande**: ochocientas sesenta lineas seguidas que son el corazon del
## paso. Lo que hay aqui es el bucle de una persona -las necesidades, el
## horario, el estado en que esta y a que pasa- y la decision de la manana.
##
## Lo que NO esta aqui, a proposito: ANDAR, que es [Marcha]; DONDE se pone y a
## que tajo se le manda, que es [Destino]; y lo que pasa al cerrar la jornada,
## que es [CierreDelDia]. Los cuatro se leen en ese orden.
##
## **El estado se queda en el simulador** y aqui se pide por `sim.`: la
## instantanea firma las propiedades del simulador por su sitio, asi que mudar
## un `var` cambiaria la forma de la firma aunque la partida fuera la misma. Ver
## la nota de `SettlementSim.berrea_hasta_el_dia`.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Como se llama el tramo de la rutina segun el estado en que se entra. Es
## solo para el cepo: ver [_tick_person].
const RUTINA_POR_ESTADO := {
	Inhabitant.State.DURMIENDO: "rutina: durmiendo",
	Inhabitant.State.OCIOSO: "rutina: ocioso (decide el dia)",
	Inhabitant.State.COMIENDO: "rutina: comiendo",
	Inhabitant.State.YENDO: "rutina: yendo",
	Inhabitant.State.BUSCANDO: "rutina: buscando",
	Inhabitant.State.TRABAJANDO: "rutina: trabajando",
	Inhabitant.State.RECONOCIENDO: "rutina: reconociendo",
	Inhabitant.State.VOLVIENDO: "rutina: volviendo",
}


func _tick_person(person: Inhabitant, index: int, hours: float, delta: float) -> void:
	# Las necesidades corren para todos, trabajen o no
	person.hunger = clampf(person.hunger + hours * sim.HAMBRE_POR_HORA, 0.0, 100.0)
	Cronometro.tramo("gente: rastro y atascos")
	person.mark_trail(sim.day, sim.hour)
	sim.marcha._watch_for_stuck(person, hours)
	Cronometro.cierra("gente: rastro y atascos")

	# Las horas se apuntan SIEMPRE que este de servicio, ande o trabaje. Sin
	# las de andar, «la recoleccion no trae nada» no se distingue de «la
	# recoleccion se pasa la jornada andando», que es una respuesta muy
	# distinta y con un arreglo muy distinto.
	if person.job != Profession.Job.OCIOSO \
			and person.state != Inhabitant.State.DURMIENDO \
			and person.state != Inhabitant.State.COMIENDO:
		person.log_hours(person.current_task(), hours)

	# La RESISTENCIA se entrena AGUANTANDO, no trabajando sin mas: hace falta
	# estar ya cansado y seguir en ello. Un dia corto y descansado no curte a
	# nadie.
	#
	# El trabajo de abrigo queda fuera MIENTRAS no cueste fatiga -ver
	# [Hogar.CAMP_FATIGUE_RATE], que hoy vale cero-. Si contara, quien llegase cansado
	# de la vispera se pondria a tallar junto al fuego, no se cansaria mas ni se
	# le pasaria en todo el dia, y curtiria aguante gratis. El dia que tallar
	# canse, esta excepcion sobra y se cae sola.
	if person.fatigue > sim.RESISTENCIA_TRAINING_THRESHOLD \
			and person.state != Inhabitant.State.DURMIENDO \
			and person.state != Inhabitant.State.OCIOSO \
			and person.state != Inhabitant.State.COMIENDO \
			and (Hogar.CAMP_FATIGUE_RATE > 0.0 or not sim.hogar._works_at_camp(person)):
		person.train_stat(Inhabitant.Stat.RESISTENCIA, hours * sim.RESISTENCIA_TRAINING_RATE)

	# Fuera de la jornada. La gente se recoge, come y duerme a sus horas.
	var night := sim.hour < sim.HORA_DESPERTAR or sim.hour >= sim.HORA_DORMIR
	# Volver PARA el anochecer, no empezar a volver al anochecer.
	#
	# [HORA_REGRESO] era la hora de dar media vuelta, con lo que quien estaba a
	# dos kilometros llegaba de noche cerrada. Medido en el sitio 56, seis
	# jornadas: a las nueve -la hora de dormir- seguia habiendo dos personas
	# andando por el monte, y a las tres de la madrugada media.
	#
	# Ahora se cuenta lo que se tarda en llegar y se sale con esa antelacion.
	# Ver [hours_to_walk], que se queda corta a proposito.
	# Y el rodeo se MIDE, no se supone.
	#
	# Era la linea recta por un factor fijo -[RODEO_DE_VUELTA], 2,4-, que vale
	# para monte abierto y se queda cortisimo con un rio de por medio: medido en
	# el sitio 56, un pescador dormia al raso A 150 M DEL ABRIGO despues de
	# haber andado 1.284 m para llegar alli. Rodeo real, ocho veces y media. Se
	# le decia de volver cuando ya no daba tiempo, y la noche le cogia a dos
	# minutos de casa.
	#
	# Lo que costo la IDA es la mejor prevision de lo que costara la vuelta, y
	# ya esta apuntado: ver [Inhabitant.note_step]. Se coge lo mayor de las dos
	# cuentas, que es lo prudente: equivocarse volviendo pronto cuesta un rato
	# de trabajo, y equivocarse volviendo tarde cuesta la noche a la intemperie.
	Cronometro.tramo("gente: decidir la vuelta")
	var derecho := person.position.distance_to(sim.home_position)
	var vuelta_m := maxf(derecho * sim.RODEO_DE_VUELTA,
		float(person.journey.get("ida", 0.0)))
	var winding_down := sim.hour + sim.marcha.hours_to_walk(vuelta_m) >= sim.HORA_REGRESO \
		and sim.hour < sim.HORA_DORMIR
	var morning := sim.hour >= sim.HORA_DESPERTAR and sim.hour < sim.HORA_SALIDA

	# A la hora de volver, todo el mundo emprende el regreso salvo quien esta
	# de expedicion. Sin esto la gente se quedaba trabajando hasta la noche y
	# volvia a oscuras, que es lo que hace un autómata, no una persona.
	if winding_down and person.state != Inhabitant.State.VOLVIENDO \
			and not (sim.hogar._works_at_camp(person) and sim.hogar._can_work_at_night(person)):
		var on_expedition := person.job == Profession.Job.EXPLORACION \
			and person.current_speciality != Profession.Speciality.BATIDA \
			and not sim._saliendo_de_casa(person)
		if not on_expedition:
			if sim._at_shelter(person):
				sim.despensa._deliver(person)
				person.state = Inhabitant.State.OCIOSO
			else:
				# Y SE APUNTA QUE SE VUELVE ANTES DE TIEMPO. Es lo que se pidió
				# para la crónica: «si no terminó de trabajar, si se tuvo que
				# volver al asentamiento antes». Sin esto, una jornada cortada
				# por la noche se lee igual que una terminada.
				if person.state == Inhabitant.State.RECONOCIENDO:
					var pide := sim.reconocimiento._survey_hours_for(person)
					sim.cronista.apuro(person,
						"Se hacía de noche y dejó el reconocimiento a medias: "
							+ "llevaba %.1f h de las %.1f que pide batir el sitio."
								% [person.survey_hours, pide])
				elif person.state == Inhabitant.State.TRABAJANDO 						or person.state == Inhabitant.State.BUSCANDO:
					sim.cronista.apuro(person,
						"Se hacía de noche y tuvo que dejar el trabajo para "
							+ "emprender la vuelta.")
				sim.marcha._send_to(person, sim.home_position)
				person.state = Inhabitant.State.VOLVIENDO

	# EL DESAYUNO. Se sienta todo el mundo, tenga el hambre que tenga: es una
	# comida, no un remedio. Quien no la necesite se levanta enseguida -se sale
	# de COMIENDO en cuanto el hambre baja de 15-.
	#
	# Ya no lleva condicion de hambre porque ya no hay tercera oportunidad: se
	# quito el bocado de mediodia y el picoteo de cualquier rato muerto, asi que
	# quien se salte el desayuno aguanta hasta la cena.
	if morning and person.hunger > sim.COMIDA_SUFICIENTE \
			and sim.store.food_rations() > 0.0:
		person.state = Inhabitant.State.COMIENDO

	# LA CENA, y va antes de la noche a proposito: a las nueve el reparto
	# noche/dia manda a todo el mundo a dormir, asi que una cena a esa hora se
	# quedaba en una comida que empieza y no termina. Se cena en casa y al
	# fuego -de ahi el aprovechamiento de mas del hogar- y luego se duerme.
	if sim.hour >= sim.HORA_CENA and sim.hour < sim.HORA_CENA + sim.DURA_LA_COMIDA \
			and person.hunger > sim.COMIDA_SUFICIENTE \
			and sim._at_shelter(person) and sim.store.food_rations() > 0.0 \
			and person.state != Inhabitant.State.DURMIENDO:
		person.state = Inhabitant.State.COMIENDO
	Cronometro.cierra("gente: decidir la vuelta")

	# Y la noche respeta la mesa: quien esta cenando cena, y se acuesta cuando
	# termina. Esto se resolvia con un `return` que se saltaba el resto del
	# tick -incluida la vigilancia de atascos, que contaba la cena como una
	# hora sin moverse y sacaba un «llego y el estado no se entero»-.
	# Las marcas del cepo van por PIEZA y no por persona: quince personas por
	# veinte trozos por ocho pasos son dos mil cuatrocientas llamadas en un
	# fotograma, y una marca por persona costaria mas que lo que mide. Ver
	# docs/specs/LO_MISMO_MAS_DEPRISA.md, tarea 18.
	# La rutina, y ADEMAS por el estado en que se entra: es el tramo que se
	# lleva el 70 % del año -ver la linea base en la spec- y «rutina» a secas
	# no dice si eso es trabajar, andar, decidir la jornada o dormir. El nombre
	# se saca ANTES, porque la rutina cambia el estado por el camino.
	var cual: String = "rutina: noche" if night else String(
		RUTINA_POR_ESTADO.get(person.state, "rutina: otro"))
	Cronometro.tramo("gente: rutina")
	Cronometro.tramo(cual)
	_tick_routine(person, hours, delta, night)
	Cronometro.cierra(cual)
	Cronometro.cierra("gente: rutina")

	Cronometro.tramo("gente: marcha")
	sim.marcha._tick_step(person, index, hours, delta)
	Cronometro.cierra("gente: marcha")

	# Las pruebas montan una `SettlementSim` a medias -gente y reservas, sin
	# pasar por [setup]- para probar la lógica sin pagar el terreno ni la
	# banda dibujada. `_crowd` y `_bodies` son justo lo que no montan, y no
	# tienen por qué: lo que se prueba ahí no depende de cómo se ve nadie.
	# Y dónde se queda si está en casa: dentro a dormir, en la puerta a todo lo
	# demás. Ver `_settle_at_home`.
	# El agua del dia. Va aqui, al final del tick, para que mire la posicion en
	# la que la persona ha ACABADO el paso y no la de antes de darlo.
	Cronometro.tramo("gente: agua")
	sim.despensa._drink_and_thirst(person, hours)
	Cronometro.cierra("gente: agua")

	Cronometro.tramo("gente: sitio en casa")
	sim._settle_at_home(person, delta)
	Cronometro.cierra("gente: sitio en casa")

	if sim.se_mira and sim._crowd and index < sim._bodies.size():
		Cronometro.tramo("gente: cuerpos (vista)")
		sim._pintar_a(person, index)
		Cronometro.cierra("gente: cuerpos (vista)")

	Cronometro.tramo("gente: aprender")
	sim._learn_from(person, delta)
	Cronometro.cierra("gente: aprender")

	# Y el ultimo en mirar es quien lo apunta: el diario de cada cual se
	# escribe leyendo COMO HA QUEDADO la persona tras el tick entero. Ver
	# [Cronista].
	Cronometro.tramo("gente: cronista")
	sim.cronista.mirar(person)
	Cronometro.cierra("gente: cronista")


## Cuanto multiplica la destreza de expedicion los dias de comida que se
## llevan. `expedition_days` es el suelo -lo que aguanta cualquiera con
## cero destreza-; quien ya sabe racionar y buscar por el camino estira eso
## y aguanta mas noches fuera con la misma banda a la espalda. Es la
## respuesta mecanica a «dependiendo su habilidad podra pasar mas o menos
## noches fuera»: la comida es lo que de verdad pone el limite, mas todavia
## que el cansancio -ver la nota en el bloque nocturno de `_tick_person`.
const EXPEDITION_SKILL_DAYS_RANGE := Vector2(1.0, 2.2)

## Por debajo de esta fatiga se considera "descansado" para partir de
## expedicion o ascension. Bastante mas bajo que el 78 al que se manda
## volver a un trabajador: salir a varios dias del abrigo no es lo mismo
## que un tajo del que se vuelve esa misma tarde.
const REST_BEFORE_EXPEDITION := 35.0


## Cuanta comida de mas se lleva "por si acaso", en dias. Un rio crecido,
## una pierna torcida, una tormenta que obliga a esperar: la petición
## explícita era llevar "un poco mas por posibles problemas".
const SAFETY_MARGIN_DAYS := 1.0

## Cada cuantos kilometros de frente se cuenta un dia mas de comida.
##
## No es un calculo de marcha real -a paso llano, cualquier distancia de
## este mapa local se anda en un par de horas, y con esa cuenta ningun
## destino de la partida pesaria nunca mas que el suelo fijo de siempre-.
## Es una vara de medir de JUEGO: quiere que un frente a la vuelta de la
## esquina y uno a dos valles de distancia carguen cosas claramente
## distintas, no reproducir la marcha real.
const KM_PER_EXTRA_DAY := 1.2

## La rutina de la jornada: dormir, cenar, salir, trabajar y volver.
##
## Sale de `_tick_person` porque aquello eran quinientas setenta y seis lineas
## en una sola funcion y trescientas veintinueve eran esto. Lo que queda alli
## es el ORDEN de un tick -necesidades, horario, rutina, movimiento- y aqui
## esta la rutina entera, que es lo que se lee cuando se quiere saber que hace
## alguien a las once de la manana.
func _tick_routine(person: Inhabitant, hours: float, delta: float,
		night: bool) -> void:
	if night and person.state == Inhabitant.State.COMIENDO:
		sim.despensa._eat_meal(person, hours)
		sim._settle_at_home(person, delta)
	elif night:
		# La batida de reconocimiento NO vuelve a dormir a casa: acampa donde
		# le coge la noche y sigue al dia siguiente.
		#
		# Sin esto la exploracion no funcionaba en absoluto. Medido: el
		# explorador elegia un destino a 720 m, la noche lo devolvia al
		# campamento antes de llegar, y lo mas lejos que llego en diez
		# jornadas fueron 182 m. El territorio conocido no se movia del 3%.
		#
		# Y es lo historico: una partida logistica de forrajeo sale varios
		# dias, duerme fuera y vuelve con lo conseguido. Volver cada noche es
		# lo que hace un recolector de radio corto, no un batidor.
		# Si YA esta reconociendo el sitio -ha llegado, esta batiendo la
		# comarca-, se deja terminar esa visita pase lo que pase con la
		# comida o el cansancio: es un compromiso corto y con techo -como
		# mucho `SURVEY_HOURS`, ahora mismo nueve-, y cortarlo a medio camino
		# del final era la manera de que ninguna expedicion llegase nunca a
		# `_finish_survey`. Reconocer YA cuesta 4 de fatiga por hora -ver
		# `_survey`-, asi que acercarse al techo de horas casi siempre cruza
		# el 70 de cansancio justo antes de terminar: exigir estar por debajo
		# de eso para poder acampar cortaba la visita a un paso del final.
		# Medido: un explorador se quedaba a 8,4 de las 9 horas -con la
		# noche encima- y volvia con las manos vacias, sin haber llamado ni
		# una vez a `_finish_survey`.
		var mid_survey := person.state == Inhabitant.State.RECONOCIENDO
		var camping := sim.despensa._camps_out(person, mid_survey)

		# Sin comida encima, la salida se acaba y se vuelve: es lo que pone
		# limite a su alcance, mas todavia que el cansancio -salvo, por lo
		# de arriba, mientras se este terminando de reconocer.
		if camping and (sim.despensa.pack_rations(person) > 0.2 or mid_survey):
			person.state = Inhabitant.State.DURMIENDO
			# La tienda y la hoguera de esta noche. Ver `_bivouac`.
			sim.despensa._bivouac(person)
			# Se descansa peor al raso que en el abrigo, y peor todavía sin
			# nada con que armar el vivac.
			# Lo que falta y lo mal armado que este pesan igual: una tienda que se
			# viene abajo abriga lo mismo que no tenerla.
			var botched := 1.0 if person.bivouac_botched else 0.0
			var rest := 6.0 - (float(person.bivouac_lack) + botched) * sim.VIVAC_REST_LOSS
			person.fatigue = maxf(person.fatigue - hours * maxf(rest, 0.0), 0.0)
			# Y se cena de lo que se lleva
			sim.despensa._eat_from_pack(person, hours)
		else:
			# QUIEN NO PUEDE ACAMPAR SIGUE ANDANDO, sea la hora que sea.
			#
			# «De noche no se anda» dejaba tirado en el monte a cualquiera al
			# que se le hiciera tarde, y medido en el sitio 56 eso eran
			# VEINTIUNA NOCHES al raso en diez jornadas entre dos pescadores y
			# un recolector, ninguno de los cuales puede acampar -ver
			# [Despensa._camps_out]-, con un caso durmiendo A CINCUENTA Y TRES
			# METROS DE LA BOCA DE LA CUEVA.
			#
			# Ahora se vuelve SIEMPRE y se paga en sueño: se entra a la hora que
			# sea y se duerme lo que quede de noche. Ver [CANSA_DE_NOCHE].
			if not sim._home_reached(person):
				sim.marcha._send_to(person, sim.home_position)
				if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
					# NO SE HA MIRADO, que no es lo mismo que no haber camino.
					#
					# Y aqui el error tiene precio: leyendo el silencio como «no
					# hay camino a casa» se manda a dormir al raso a quien solo
					# tenia que esperar un cuadro. Ver [Marcha.Traza].
					return
				if not person.route.is_empty():
					person.state = Inhabitant.State.VOLVIENDO
					person.fatigue = clampf(person.fatigue
						+ hours * sim.CANSA_DE_NOCHE, 0.0, 100.0)
					return
				# Y SI NO HAY CAMINO, se duerme donde se este. No es lo mismo
				# «se me ha hecho tarde» que «estoy al otro lado del rio»: al
				# primero se le manda seguir andando, al segundo no hay nada
				# que mandarle. Sin esta salida, quien queda aislado se pasa
				# la noche entera intentando trazar una ruta que no existe y
				# amanece a cien de fatiga; medido antes, el explorador dejaba
				# de salir el dia veinte y se pasaba los otros veinte despierto
				# en mitad del monte.
				person.state = Inhabitant.State.DURMIENDO
				sim.despensa._bivouac(person)
				var suelto := 1.0 if person.bivouac_botched else 0.0
				var raso := 6.0 - (float(person.bivouac_lack) + suelto) * sim.VIVAC_REST_LOSS
				person.fatigue = maxf(
					person.fatigue - hours * maxf(raso, 0.0), 0.0)
				# Y AL RASO SE COGE FRÍO, que hasta el 2026-09-12 no se cogía:
				# dormir fuera sólo tocaba la fatiga, en cualquier estación. Con
				# hoguera se entra en calor; sin ella, por los grados que haga
				# ahí arriba, que suelen ser menos que en la cueva.
				sim._frio_de_una_noche(person, hours, sim._grados_donde(person),
					person.bivouac_fire)
				sim.despensa._eat_from_pack(person, hours)
				return
			if sim._home_reached(person):
				# Lo primero al llegar es descargar, y llegar de noche tambien es
				# llegar. Sin esto se dormia con el cesto puesto y la cosecha del dia
				# no entraba en el almacen hasta la manana siguiente -y si por la
				# manana se salia sin pasar por la boca, se perdia entera-. Medido
				# antes: 635 momentos de gente en el abrigo con 5,5 kg encima.
				sim.despensa._deliver(person)
				person.state = Inhabitant.State.DURMIENDO
				person.fatigue = maxf(person.fatigue - hours * 9.0, 0.0)
				# Una noche fría en una cueva sin fuego no se descansa: se aguanta.
				# ANTES decía «en invierno»; ahora dice «a los grados que haga»,
				# que en la cueva de siempre viene a ser lo mismo y en una cueva
				# alta no. Ver [frio_por_hora].
				var grados_en_casa := sim._grados_donde(person)
				# El fuego que calienta ESTA noche, que no es lo mismo que el
				# hogar prendido: racionado, una noche de cada dos no hay.
				var con_fuego := sim.hogar.calienta_esta_noche()
				if not con_fuego and sim.frio_por_hora(grados_en_casa) > 0.0:
					person.fatigue = clampf(
						person.fatigue + hours * sim.HEARTH_COLD_FATIGUE, 0.0, 100.0)
				sim._frio_de_una_noche(person, hours, grados_en_casa, con_fuego)
				# Superar el aforo del abrigo no es un muro -no impide nacer
				# ni expulsa a nadie-: alimenta los mismos contadores que ya
				# castigan dormir mal, no un cuarto camino de muerte aparte.
				# Aparte de estación y de hogar: apretujarse molesta todo el
				# año, no sólo en invierno.
				if sim.population() > sim.plazas_abrigo():
					person.fatigue = clampf(
						person.fatigue + hours * sim.ABARROTADO_FATIGUE_RISE,
						0.0, 100.0)
					person.cold = clampf(
						person.cold + hours * sim.ABARROTADO_COLD_RISE, 0.0, 100.0)
			else:
				# No puede volver y no le queda comida: duerme donde le coge
				# la noche. Es lo que hace cualquiera, y sin esto era una
				# trampa sin salida: quien no podia llegar al abrigo no
				# dormia NUNCA -solo se descansaba en casa-, la fatiga se
				# clavaba en cien y a partir de ahi ya no volvia a salir de
				# expedicion, porque reventado no se sale.
				#
				# Medido antes de arreglarlo: el explorador dejaba de hacer
				# expediciones el dia veinte y se pasaba las otras veinte
				# jornadas despierto en mitad del monte.
				#
				# Se repone peor que en el abrigo -al raso, con hambre y sin
				# fuego- pero se repone.
				person.state = Inhabitant.State.DURMIENDO
				person.fatigue = maxf(person.fatigue - hours * 4.5, 0.0)
				# Y SIN FUEGO NINGUNO, que es lo que dice el comentario de
				# arriba: el frío de la noche entero, por los grados que haga.
				sim._frio_de_una_noche(person, hours, sim._grados_donde(person), false)
	else:
		_tick_daylight(person, hours)


## Lo que se hace con luz: comer, salir al tajo, trabajarlo y volver.
##
## Sale de `_tick_routine` porque aquello eran trescientas treinta y siete
## lineas y doscientas cuarenta eran esto. Arriba queda LA NOCHE -acampar o
## dormir en casa- y aqui el dia: dos cosas que no se parecen en nada y que
## estaban en las dos ramas del mismo `if`.
## Cuanta destreza se gana por hora de trabajo.
##
## Estuvo en 0,0008, o sea 0,0072 al dia con las nueve horas utiles, y con eso
## un recolector pasaba de 0,096 a 0,505 de pericia EN CUARENTA Y CINCO DIAS y
## tocaba el techo hacia el 120. Medido con `scripts/tests/AnoProbe.gd`:
##
##   dia  1   pericia 0,096 · efectividad 0,218 · despensa 6 dias
##   dia 16   pericia 0,293 · efectividad 0,301 · despensa 17
##   dia 31   pericia 0,395 · efectividad 0,373 · despensa 72
##   dia 46   pericia 0,505 · efectividad 0,462 · despensa 94
##
## Eso es lo que hacia explotar la despensa: el rendimiento de la recoleccion
## se multiplicaba por 2,4 en mes y medio -de 4,0 raciones por persona y dia a
## 9,5- cuando el objetivo que este mismo fichero declara es «cerca del doble
## de lo que come», o sea 3,4.
##
## Y ademas dejaba sin sentido dos sistemas: si un adulto domina su oficio en
## cuatro meses, la transmision nocturna -`_knowledge_transmission`- no tiene
## a quien enseñar, y el relevo generacional no es un problema.
##
## Puesto para que la pericia suba del orden de 0,25 EN UN AÑO de juego: se
## nota en la campaña, y dominar un oficio sigue siendo cosa de vida entera,
## que es lo que dicen los datos de rendimiento por edad en forrajeadores
## -Kaplan y otros: el rendimiento de un cazador ache no llega a su techo
## hasta los treinta y tantos-.
##
## Pendiente de playtest: lo medido es la curva vieja; lo decidido es que
## aprender lleve una campaña y no una estacion.
## Estuvo en 0,00015 y era INVISIBLE: a ocho horas de trabajo al dia son doce
## milesimas por jornada, o sea que ir del 0,50 de partida al 0,95 de tope
## costaba TRESCIENTOS SETENTA Y CINCO DIAS, mas de dos años de juego. El
## jugador no veia subir la pericia de nadie porque, a efectos practicos, no
## subia.
##
## Con 0,0005 una estacion de trabajo diario mueve unos veinte puntos, que es lo
## que se nota sin que la banda se vuelva experta en un mes. Queda a playtest
## como toda cifra que decide el rendimiento.
##
const APRENDE_POR_HORA := 0.0005


## Y su tope, en metros.
##
## Treinta: unas cuantas zancadas. Sin tope, un tick largo -acelerando el juego-
## da zancadas de cientos de metros y entonces «he llegado» valdria desde medio
## valle. No hace falta que valga: el paso se recorta al destino, asi que quien
## lo tenia a tiro cae encima y el tick siguiente lo ve a cero.
const LLEGADA_MAXIMA := 30.0


## Cuanto cuenta como «he llegado», en metros.
##
## No es un numero fijo: es lo que se anda de una zancada, o el radio de
## siempre si la zancada es mas corta. Estando a menos de un paso del destino,
## el paso siguiente cae encima o mas alla, asi que se ha llegado.
##
## Con `arrive_radius` a pelo -seis metros- y pasos de treinta a sesenta, nadie
## llegaba nunca a ningun sitio: se pasaba de largo, se volvia a trazar el
## camino y se pasaba otra vez.
func _radio_de_llegada(hours: float) -> float:
	return clampf(sim.walk_speed * hours * sim.seconds_per_day / 24.0,
		sim.arrive_radius, LLEGADA_MAXIMA)


## Si en este estado se está trabajando el oficio: lo que cuenta como jornada
## de práctica. **Una pregunta, un sitio** —ver [_practica_del_dia]—.
##
## Trabajar en el tajo o en la campa, prospectar un paraje buscando lo que da, y
## batir el monte reconociéndolo. Hasta el 2026-09-13 esto se apuntaba DENTRO
## de la rama de TRABAJANDO y nada más, y la batida —que corre en
## RECONOCIENDO— dejó de practicar exploración: «la técnica de exploración no
## sube con las batidas», lo vio el usuario. Aquí, antes de repartir por estado,
## no se puede olvidar ninguna rama.
static func cuenta_como_trabajo(state: Inhabitant.State) -> bool:
	return state == Inhabitant.State.TRABAJANDO 		or state == Inhabitant.State.BUSCANDO 		or state == Inhabitant.State.RECONOCIENDO


func _tick_daylight(person: Inhabitant, hours: float) -> void:
	# Lo que se trabaja hoy se apunta AQUÍ, antes de repartir por estado. Ver
	# [cuenta_como_trabajo] e [Inhabitant.oficio_de_hoy].
	if cuenta_como_trabajo(person.state):
		person.oficio_de_hoy = person.job
		if person.has_task:
			person.actividad_de_hoy = person.activity
	match person.state:
		Inhabitant.State.DURMIENDO, Inhabitant.State.OCIOSO:
			# Y POR OFICIO, que es lo que decide cuanto cuesta: decidir la
			# jornada sale a 0,17 ms de media y a SIETE en los fotogramas
			# malos -medido en el año de cierre: 6.894 ms de un tiron de
			# 7.255-. Hace falta saber de cual de las tres ramas es. Se marca
			# aqui y no dentro porque `_decide_the_day` esta lleno de
			# `return`, y una marca que no se cierra ensucia a la siguiente
			# persona. Ver la tarea 21 de docs/specs/LO_MISMO_MAS_DEPRISA.md.
			# Y NO CUARENTA VECES POR MINUTO DE JUEGO. Ver
			# [Inhabitant.repensar_tras]: quien acaba de pensar la jornada y no
			# ha podido salir no vuelve a pensarla hasta dentro de un rato.
			# Quien SI sale no espera nada, que es lo que hace que esto no se
			# note jugando.
			var ahora := float(sim.day) * 24.0 + sim.hour
			if ahora < person.repensar_tras:
				return
			var quien := "decide: tajo"
			if person.job == Profession.Job.EXPLORACION:
				quien = "decide: batida" if person.current_speciality 					== Profession.Speciality.BATIDA else "decide: expedicion"
			Cronometro.tramo(quien)
			_decide_the_day(person, hours)
			Cronometro.cierra(quien)
			if person.state == Inhabitant.State.OCIOSO \
					or person.state == Inhabitant.State.DURMIENDO:
				# La decision no ha cambiado nada: se espera un rato.
				#
				# De noche la espera no cuenta desde ahora sino HASTA LA HORA DE
				# SALIR: aplazar la primera decision de la manana seria retrasar
				# la jornada entera de la banda, y eso ya no seria «lo mismo mas
				# deprisa».
				if sim.hour < sim.HORA_SALIDA:
					person.repensar_tras = float(sim.day) * 24.0 + sim.HORA_SALIDA
				else:
					person.repensar_tras = ahora + sim.ESPERA_PARA_REPENSAR
		Inhabitant.State.COMIENDO:
			sim.despensa._eat_meal(person, hours)
		Inhabitant.State.YENDO:
			# LLEGAR ES TAMBIEN HABER PASADO DE LARGO.
			#
			# El radio de llegada son seis metros y, a velocidad de persona, un
			# paso mide entre treinta y sesenta: se pasa por encima del destino
			# sin llegar a estar nunca dentro de esos seis metros, no se da por
			# llegado, se vuelve a trazar el camino y se pasa otra vez. Desde
			# fuera se lee como «va a un paraje y cuando llega va a otro»: no va
			# a otro, es que no ha llegado a este.
			#
			# Medido con `PasoProbe` a velocidad de juego: los recolectores
			# andaban 728 m para un viaje de 274, o sea dos vueltas y media de
			# mas alrededor del sitio.
			if person.position.distance_to(person.target) < _radio_de_llegada(hours):
				if person.job == Profession.Job.EXPLORACION \
						and person.current_speciality == Profession.Speciality.ASCENSION \
						and (person.cumbre_objetivo != Vector3.ZERO or sim.cumbres._is_on_peak(person)):
					# Llegar al pie de la cumbre no es coronarla: se
					# INTENTA, y con poca pericia se falla. Ver [Ascent].
					#
					# Y el pie es SU DESTINO, no los 12 m del pico: la celda de
					# la cumbre está cerrada por pendiente y el camino acaba una
					# más abajo. Ver [Inhabitant.cumbre_objetivo].
					sim.cumbres._try_ascent(person)
					person.cumbre_objetivo = Vector3.ZERO
					sim.marcha._send_to(person, sim.home_position)
					person.state = Inhabitant.State.VOLVIENDO
					return
				if person.job == Profession.Job.HOGAR:
					# De camino al agua, no a un paraje -ver
					# [Hogar._fetch_water]-: el hogar no tiene otra razón
					# para salir del abrigo, así que llegar YENDO siempre
					# es llegar a la orilla.
					sim.hogar._arrive_at_water(person)
					return
				# Si conoce el paraje, se pone a trabajar. Si no, primero
				# tiene que ENCONTRAR lo que ha venido a buscar.
				var known := 0.0
				if sim.knowledge:
					known = sim.knowledge.familiarity_at(person.activity, person.position)
				# El explorador que llega adonde se le mando no ha
				# terminado: llegar es marcar una casilla, reconocer es
				# batir la comarca. Se queda una jornada.
				# El explorador nunca ha terminado por llegar: llegar es
				# marcar una casilla, reconocer es batir la comarca. Y lo
				# mismo vale para quien ha salido A INVESTIGAR por no tener
				# fuente conocida de lo suyo. Ver [Inhabitant.investigando].
				if person.job == Profession.Job.EXPLORACION 						or person.investigando:
					person.work_centre = person.position
					person.forage_target = person.position
					person.survey_hours = 0.0
					person.state = Inhabitant.State.RECONOCIENDO
					return

				if known > Tajo.SE_PUEDE_TRABAJAR:
					person.work_centre = person.position
					person.forage_target = person.position
					person.state = Inhabitant.State.TRABAJANDO
				else:
					person.search_hours = 0.0
					person.state = Inhabitant.State.BUSCANDO

		Inhabitant.State.BUSCANDO:
			# Prospectar: batir el paraje hasta dar con lo que hay. Cuesta
			# tiempo, y ese tiempo sale de la jornada de recoleccion.
			#
			# Es lo que faltaba para que explorar sirviera de algo: el que
			# llega a un sitio que ya conoce se pone a recoger de
			# inmediato, y el que no, pierde media manana buscando.
			person.search_hours += hours
			person.fatigue = clampf(
				person.fatigue + hours * 3.0 * person.fatigue_factor(), 0.0, 100.0)

			# Buscar ENSENA el paraje, aunque no se recoja nada
			if sim.knowledge:
				sim.knowledge.observe(person.activity, person.position, hours / 8.0)

			var found := 0.0
			if sim.field:
				found = sim.field.seasonal_abundance_at(
					person.activity, person.position, sim.estacion)

			# Cuanto mas rico el paraje, antes se da con ello
			var needed: float = lerpf(4.5, 1.0, clampf(found, 0.0, 1.0))
			if person.search_hours >= needed:
				person.work_centre = person.position
				person.forage_target = person.position
				person.state = Inhabitant.State.TRABAJANDO
				# Dar con lo que se venia a buscar ES descubrir el sitio, y la
				# chapa tiene que salir AHORA y no a medianoche. Ver
				# [Reconocimiento.bautizar_lo_descubierto].
				sim.reconocimiento.bautizar_lo_descubierto(
					person.position, Reconocimiento.FORAGE_RADIUS)

				# Y si esto era un paraje con «???», prospectar con exito
				# resuelve uno. No hace falta ser explorador para saber que en
				# el avellanar al que vas a diario tambien hay zarza: eso se
				# aprende recogiendo.
				#
				# «Lo primero que haran los recolectores es ir a un paraje de su
				# especializacion y tratar de encontrar materiales que ellos
				# puedan recolectar. Si encuentran alguno, descubriran una de
				# las ?? de los parajes».
				var aqui := sim._paraje_at(person.position)
				if aqui != null and aqui.activity == person.activity:
					var salio := aqui.reveal_one()
					if salio >= 0:
						sim._note(Chronicle.Kind.HALLAZGO, "%s da con %s en %s."
							% [person.given_name, Materia.material_name(
								salio as Materia.Kind).to_lower(), aqui.name_text], 1)
			elif person.search_hours > 5.0:
				# Aqui no hay nada. Se prueba en otro sitio.
				sim.marcha._send_to(person, sim.tajo._search_target(person))
				person.state = Inhabitant.State.YENDO
		Inhabitant.State.RECONOCIENDO:
			sim.reconocimiento._survey(person, hours)
		Inhabitant.State.TRABAJANDO:
			# Lo trabajado ya se apuntó arriba. Ver [cuenta_como_trabajo].
			if sim.hogar._works_at_camp(person):
				sim.hogar._camp_work(person, hours)
			else:
				person.fatigue = clampf(
					person.fatigue + hours * 5.0 * person.fatigue_factor(), 0.0, 100.0)
				# El brazo se entrena cargando y no tallando: FUERZA sube
				# muchisimo mas despacio que la destreza, y solo con tajo de
				# verdad fisico -al taller no le hace falta.
				if person.job == Profession.Job.CAZA \
						or person.job == Profession.Job.RIBERA \
						or person.job == Profession.Job.RECOLECCION:
					person.train_stat(Inhabitant.Stat.FUERZA, hours * sim.FUERZA_TRAINING_RATE)
				# Batir la mancha es de quien recoge. Quien acecha va a
				# donde está la pieza, y `_forage_drift` le reescribiría el
				# destino cada tick con un punto sorteado del paraje.
				if not sim.caceria._is_hunting(person):
					sim.tajo._forage_drift(person, hours)
				if person.job == Profession.Job.MANUFACTURA:
					sim.taller._craft(person, hours)
				elif person.current_speciality == Profession.Speciality.CAZA_MENOR \
						or person.current_speciality == Profession.Speciality.CAZA_MAYOR:
					# La caza YA NO cosecha: acecha, persigue y cobra una
					# pieza de las que andan por el valle. Ver `_hunt_step`.
					sim.caceria._hunt_step(person, hours)
				elif person.current_speciality == Profession.Speciality.ORILLA:
					# La nasa se revisa y luego SE PESCA. `_creel_round`
					# devuelve las horas que quedan de jornada, que es lo
					# que la separa de la línea de trampas: aquélla se
					# lleva el día entero, ésta un rato.
					sim.tajo._harvest(person, sim.nasas_line._creel_round(person, hours))
				elif person.current_speciality == Profession.Speciality.TRAMPAS:
					# El trampero no cosecha: arma trampas y luego las levanta.
					# Es el unico trabajo que rinde MIENTRAS la banda hace otra
					# cosa, y por eso no puede ser una tabla de rendimiento
					# como las demas.
					sim.trampas._trapline(person, hours)
				else:
					sim.tajo._harvest(person, hours)
				# La practica mejora la TAREA que se esta haciendo, no la
				# actividad entera: quien talla no aprende a curtir pieles.
				var task := person.current_task()
				var current: float = person.skill_in(task)
				person.skill[task] = minf(
					current + hours * APRENDE_POR_HORA * person.learn_rate(), 0.95)

				# Se vuelve cuando no se puede cargar mas, no por un numero
				# fijo: es lo que hace que los recipientes cambien la jornada.
				if person.fatigue > 78.0 or person.load_fraction() >= 1.0:
					sim.marcha._send_to(person, sim.home_position)
					person.state = Inhabitant.State.VOLVIENDO

		Inhabitant.State.VOLVIENDO:
			if sim._home_reached(person):
				sim.despensa._deliver(person)
				person.state = Inhabitant.State.OCIOSO


## A que se sale hoy: expedicion, cumbre, batida, el abrigo o el tajo.
##
## Es la rama mas larga de `_tick_daylight` -mas de cien lineas de un `if`
## encadenado- y la unica que DECIDE: las demas ejecutan lo ya decidido. Sacarla
## deja el reparto de estados como lo que es, un indice, y la decision donde se
## puede leer entera.
func _decide_the_day(person: Inhabitant, hours: float) -> void:
	# Aqui estaba el picoteo: cualquier rato muerto con hambre por
	# encima de 55 era una comida. Con eso la banda comia a todas
	# horas y no se sentaba a comer nunca. Se come al levantarse y a
	# la hora de recogerse, y entre medias se aguanta.
	if person.job == Profession.Job.EXPLORACION \
			and person.current_speciality != Profession.Speciality.BATIDA \
			and person.fatigue > 70.0 \
			and not sim._saliendo_de_casa(person):
		# Reventado EN EL CAMPO: se vuelve al campamento a
		# reponer. La condicion de distancia es la que faltaba:
		# sin ella, alguien que ya estaba en casa y seguia
		# cansado -de dia no se descansa solo por estar
		# ocioso, hace falta que caiga la noche- se mandaba
		# "a casa" una y otra vez sin moverse casi nada,
		# entraba en VOLVIENDO, llegaba, volvia a OCIOSO,
		# disparaba esto otra vez... y se perdia la jornada
		# entera dando vueltas en el sitio en vez de salir o
		# de verdad descansar. Ver [REST_BEFORE_EXPEDITION],
		# que es quien de verdad decide cuando esta descansado.
		sim.marcha._send_to(person, sim.home_position)
		person.state = Inhabitant.State.VOLVIENDO
	elif person.job == Profession.Job.EXPLORACION \
			and person.current_speciality == Profession.Speciality.BATIDA:
		# La batida es radio corto y vuelve siempre a dormir a
		# casa: no hace falta avituallarla como a una expedicion.
		# Amplia el entorno inmediato del campamento, no la
		# frontera del territorio.
		#
		# Y MIRA LA HORA, igual que la mira `_send_to_work` unas lineas mas
		# abajo. Es lo que faltaba: sin esa guarda, a las ocho de la tarde se
		# mandaba al batidor a un paraje a ciento sesenta metros, la regla de
		# recogida -que si mira la hora- le daba media vuelta en el acto, y al
		# tick siguiente se le volvia a mandar. Sacado del diario de Kelo:
		# «20:08 salio hacia El cantizal de abajo · 20:08 decidio volver al
		# abrigo · 20:08 llego al abrigo», treinta veces seguidas.
		if sim.hour < sim.HORA_SALIDA or sim.hour >= _ultima_salida(person):
			return
		var target := sim.reconocimiento._batida_target(person)
		if target.distance_to(person.position) > sim.arrive_radius:
			# Ruta vacia antes de pedirla. `_batida_target` deja puesta la del
			# ultimo candidato que probo, asi que sin esto «hay camino» podia
			# ser verdad de OTRO destino y el batidor salia siguiendo una ruta
			# que no llevaba adonde se le mandaba.
			person.route = PackedVector3Array()
			person.route_step = 0
			sim.marcha._send_to(person, target)
			if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
				# No se ha mirado: no se concluye nada. Ver [Marcha.Traza].
				return
			if not person.route.is_empty():
				if person.journey.is_empty():
					person.begin_journey("Batida", sim.day, sim.hour,
						sim.home_position)
				person.state = Inhabitant.State.YENDO
			elif not sim._at_shelter(person):
				# SIN CAMINO Y LEJOS DE CASA: SE VUELVE.
				#
				# Sin esto no pasaba NADA —ni ruta ni cambio de estado— asi que
				# quien estuviera parado en mitad del monte se quedaba ahi. Y
				# se quedaba de verdad: medido con `BatidaProbe` en una tirada
				# de un año, Jara se planta ociosa a 399 m del abrigo la jornada
				# 49 y sigue en el mismo punto, al metro, TREINTA JORNADAS
				# despues. Ni bate, ni vuelve, ni come.
				#
				# Volver a casa siempre es una salida: desde el campamento se
				# vuelve a decidir con la rejilla y la estacion del dia
				# siguiente, y una batida que no encuentra destino hoy lo
				# encuentra manana.
				sim.marcha._record_stuck(person,
					"sin camino a ningun sitio que batir, se vuelve al abrigo")
				sim.marcha._send_to(person, sim.home_position)
				person.state = Inhabitant.State.VOLVIENDO
	elif person.job == Profession.Job.EXPLORACION:
		# Expedicion y ascension: se sale varios dias y hace falta
		# avituallar. El explorador no tiene tajo fijo: su destino
		# se calcula cada jornada. Ver [Exploration].
		#
		# El tope de hora es el mismo bucle de la batida, pero aqui la guarda
		# no puede ser `_ultima_salida`: una expedicion NO vuelve hoy, asi que
		# no hay ida y vuelta que reservar. Lo que si hace falta es no
		# empezarla de noche. A quien YA esta fuera no le afecta: sigue su
		# viaje a la hora que sea.
		var at_home := sim._saliendo_de_casa(person)
		if at_home and sim.hour >= sim.HORA_REGRESO:
			return

		# El destino se calcula ANTES de avituallar, para saber
		# cuanto pesa el viaje de hoy -ver [_provision]-: cuanta
		# comida hace falta depende de adonde se va, no es igual
		# para el pico de al lado que para la loma a dos valles.
		var frontier := Vector3.ZERO
		var climb := {}
		if person.current_speciality == Profession.Speciality.ASCENSION \
				and sim.cumbres.has_peak():
			# La cumbre que ESTA persona se atreve a atacar, no la mas
			# alta que haya. Ver [peak_for].
			climb = sim.cumbres.peak_for(person)

		if climb.is_empty():
			# Que HAYA cumbre no quiere decir que le toque a esta
			# persona: puede no atreverse con ninguna de las que quedan,
			# o estar todas al otro lado del agua. Aqui se leia ["pos"]
			# sin mirar, y el juego se caia en cuanto pasaba.
			#
			# No es un caso raro ni un error: es la vuelta a la
			# exploracion normal, que es lo que hace quien se queda sin
			# monte al que subir.
			frontier = sim.reconocimiento._scout_target(person)
			person.cumbre_objetivo = Vector3.ZERO
		else:
			frontier = climb["pos"]
			person.cumbre_objetivo = frontier

		if at_home and person.fatigue > REST_BEFORE_EXPEDITION:
			# Esperar a estar descansado antes de partir: salir ya
			# cansado de varios dias fuera es la manera de no
			# volver. La noche en casa recupera fatiga sola -ver el
			# bloque nocturno-, asi que esto no atasca a nadie:
			# solo retrasa la salida un dia o dos.
			person.state = Inhabitant.State.OCIOSO
		elif at_home and not sim.despensa._provision(person, frontier.distance_to(sim.home_position)):
			# Sin provisiones no hay expedicion. Se queda ayudando.
			person.state = Inhabitant.State.OCIOSO
		else:
			if frontier.distance_to(person.position) > sim.arrive_radius:
				# Ruta vacia antes de pedirla: «no hay camino» tiene que hablar de
				# ESTA frontera y no de la ruta que la persona traia puesta.
				person.route = PackedVector3Array()
				person.route_step = 0
				sim.marcha._send_to(person, frontier)
				if sim.marcha.ultima_traza == Marcha.Traza.SIN_PRESUPUESTO:
					# No se ha mirado: se reintenta al cuadro siguiente en vez
					# de dar la frontera por imposible. Ver [Marcha.Traza].
					person.state = Inhabitant.State.OCIOSO
				elif person.route.is_empty():
					# No hay por donde llegar -un rio de por medio,
					# un cortado-: se busca otro sitio en vez de
					# salir andando derecho al agua
					sim._lament(person, frontier)
					if sim.has_scout_order:
						sim.reconocimiento.clear_scout_order()
					person.state = Inhabitant.State.OCIOSO
				else:
					# La salida se abre AQUI: cuando hay camino y
					# se echa a andar de verdad.
					#
					# Estaba unas lineas mas arriba, al elegir
					# destino, y eso abria una salida cada vez que
					# alguien se quedaba ocioso en el campamento.
					# Como volver al abrigo la cierra, salian
					# cuarenta salidas de cero metros el mismo dia,
					# una por tick, y se llevaban por delante el
					# historial de verdad.
					if person.journey.is_empty():
						person.begin_journey(
							Profession.speciality_name(
								person.current_speciality as Profession.Speciality),
							sim.day, sim.hour, sim.home_position)
					person.state = Inhabitant.State.YENDO
	elif sim.hogar._works_at_camp(person) and sim.hogar._can_work_at_night(person):
		# Fichar. La faena en si la hace `_camp_work` desde TRABAJANDO,
		# igual que la de cualquiera: aqui solo se dice que se empieza.
		person.work_centre = sim.home_position
		person.forage_target = sim.home_position
		person.state = Inhabitant.State.TRABAJANDO
	elif person.has_task and sim.hour >= sim.HORA_SALIDA and sim.hour < _ultima_salida(person):
		sim._send_to_work(person)


## Hasta que hora se puede mandar a alguien a trabajar fuera.
##
## No hasta [HORA_REGRESO]: hasta que quede dia para IR Y VOLVER. Mandar a
## alguien a las siete de la tarde a un tajo de seiscientos metros es mandarle a
## dormir al monte, y eso es lo que estaba pasando. Medido en el sitio 56, diez
## jornadas: dos pescadores y un recolector pasaban entre cuatro y ocho noches
## al raso sin ser ni exploradores ni cazadores mayores, que son los unicos que
## pueden acampar -ver [Despensa._camps_out]-.
##
## Se mira el ULTIMO tajo que trabajo, que es la mejor pista de a que distancia
## se le va a mandar hoy. Sin ninguna, vale la hora de siempre.
func _ultima_salida(person: Inhabitant) -> float:
	if not sim.work_sites.has(person.activity):
		return sim.HORA_REGRESO
	var lejos: float = sim.home_position.distance_to(sim.work_sites[person.activity])
	var ida_y_vuelta := sim.marcha.hours_to_walk(lejos * sim.RODEO_DE_VUELTA) * 2.0
	# Y algo de margen para que la salida sirva de algo: llegar, dar dos golpes
	# y darse la vuelta no es una jornada.
	return maxf(sim.HORA_SALIDA, sim.HORA_REGRESO - ida_y_vuelta - 0.5)
