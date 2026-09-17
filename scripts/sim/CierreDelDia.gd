class_name CierreDelDia
extends RefCounted
## Lo que pasa cuando acaba la jornada.
##
## Sale de `SettlementSim` en la segunda pasada (ARQUITECTURA §3.2). Es el tema
## del MEDIANOCHE: apuntar el historial de cada material, cerrar las cuentas del
## dia -la comida, el frio, la merma, quien muere-, la practica que cada uno ha
## ganado, lo que se transmite de unos a otros, el parte de lo que se ha echado a
## perder y el giro de la estacion local.
##
## Es lo que corre una vez por jornada, frente a [Rutina], que corre cada tick.
##
## **El estado se queda en el simulador** y aqui se pide por `sim.`: lo perdido
## hoy, los avisos de hambre ya dados. Ver la nota de
## `SettlementSim.berrea_hasta_el_dia`.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Apunta el cierre del dia de cada material.
func _record_history() -> void:
	for kind: int in Materia.Kind.values():
		_push_history(kind, sim.store.amount(kind as Materia.Kind))

	# Y el utillaje. Se apunta con clave NEGATIVA para que no choque con los
	# materiales, que empiezan en cero como las piezas: es el mismo apano que
	# usa el libro de trabajo, y por el mismo motivo.
	for kind: int in Tool.Kind.values():
		_push_history(-1 - kind, float(sim.toolkit.count(kind as Tool.Kind)))


func _push_history(key: int, value: float) -> void:
	var series: PackedFloat32Array = sim.history.get(key, PackedFloat32Array())
	series.append(value)
	while series.size() > sim.HISTORY_DAYS:
		series.remove_at(0)
	sim.history[key] = series


## La serie de un material, de la jornada mas vieja a la de hoy.
func history_of(kind: Materia.Kind) -> PackedFloat32Array:
	return sim.history.get(int(kind), PackedFloat32Array())


## Y la de una pieza de utillaje.
func tool_history_of(kind: Tool.Kind) -> PackedFloat32Array:
	return sim.history.get(-1 - int(kind), PackedFloat32Array())


func _end_of_day() -> void:

	# El frío y el hambre sostenidos enferman y, si no se cortan, matan. Ver
	# [Relevo].
	sim.relevo.revisar_frio()
	sim.relevo.revisar_hambre()
	sim._revisar_hambre_de_la_banda()
	# Cuanta comida cabe cambia con el taller: los cestos se rompen y se
	# trenzan otros. Ver [_ajustar_despensa].
	sim._ajustar_despensa()
	_record_history()
	# Lo que la banda cree saber se reordena una vez al dia. Antes se
	# recalculaba por persona y por salida, y eso eran 61.000 operaciones cada
	# vez que alguien cruzaba la puerta.
	sim.tajo._rank_known_spots()
	# El secadero, ANTES de que pase la noche por la despensa: lo que se cuelga
	# por la mañana ya está curado cuando llega la madrugada, y curarlo después
	# de aplicar la podredumbre sería ahumar lo que ya se tiró.
	sim.hogar._smoke_the_larder()
	# Y el lavadero, que no pide fuego pero se atiende igual: se saca lo que ya
	# está dulce y se vuelve a llenar el cesto. Ver [Hogar._lavar_bellota].
	sim.hogar._lavar_bellota()
	# Y los odres vacíos, con quien esté en el hogar. Ver [Hogar._fill_waterskins].
	sim.hogar._fill_waterskins()
	sim.store.age(1)
	# El vestido se lleva puesto, no se usa a ratos: se gasta por dia de
	# calendario, no por tarea. Ver `VESTIDO_WEAR_PER_DAY`.
	sim.toolkit.wear_all(Tool.Kind.VESTIDO, sim.VESTIDO_WEAR_PER_DAY)
	sim.desechos.nuevo_dia()
	# Y la cuenta de la PROTEINA del dia: comer no es lo mismo que comer bien.
	# Ver [Despensa.pasar_cuenta_de_proteina].
	sim.despensa.pasar_cuenta_de_proteina()
	sim.lobo.nuevo_dia()
	sim.expedicion.nuevo_dia()
	# La obra del cruce: la banda la levanta sola con quien ese día ha salido
	# de exploración. Ver [Pasarelas].
	sim.pasarelas.nuevo_dia()
	sim._acabar_la_berrea()
	# Y revista a los parajes: lo que baja del veinte por ciento se deja
	# descansar solo, sin que el jugador tenga que estar mirandolo.
	sim.barbecho.revisar()
	# Y el paisaje se mueve: la cota de nieve baja, las vegas se encharcan y el
	# rio crece o baja. No es pintura -frena y cierra vados-. Ver [Temporada].
	sim.temporada.nuevo_dia(sim.estacion as Subsistence.Season)
	# Y la fauna cria, con techo. Sin esto la caza solo resta y el valle se
	# vacia; con crecimiento sin techo, no se vacia nunca.
	if sim.poblaciones != null:
		sim.poblaciones.nuevo_dia(sim.estacion as Subsistence.Season)
	sim.despensa._report_spoilage()
	sim.hogar._burn_hearth()

	# Las piezas rotas se retiran ahora y no al romperse, para que el parte del
	# dia pueda contarlas antes de que desaparezcan.
	sim.toolkit.discard_spent()
	sim.toolkit.broken_today.clear()

	# Las trampas cobran mientras la banda duerme, y se van gastando. Y las
	# nasas igual, que es lo mismo en el agua.
	sim._age_traps()
	sim.nasas_line._age_nasas()
	# Y lo que quedó abierto en el monte: se pudre y, sobre todo, hay lobos.
	sim.caceria._age_kills()

	# Los parajes se reponen. Sin esto lo esquilmado no volvia nunca y el valle
	# se vaciaba en unas semanas. Las vetas quedan fuera: ver `_freeze_veins`.
	if sim.field:
		sim._freeze_veins()
		for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
				Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
				Subsistence.Activity.MATERIA_PRIMA]:
			# Y LO QUE REBROTA POR ENCIMA DEL UMBRAL ENTRA EN LA COLA.
			#
			# Es la unica forma de que un sitio se gane un nombre sin que
			# nadie haya ido a mirarlo: una veta esquilmada que vuelve a dar.
			# Apuntarlo aqui -donde se sabe- es lo que permite que nadie
			# tenga que barrer el campo por si acaso. Ver [Parajes.cola].
			var act := activity as Subsistence.Activity
			var umbral := maxf(Parajes.WORTH_NAMING,
				sim.parajes.threshold_for(act))
			for celda: int in sim.field.regrow(act, 0.045, umbral):
				sim.parajes.encolar_celda(sim.field, act, celda)
	# La comida se consume DURANTE el dia, en el estado COMIENDO. Aqui solo se
	# pasa cuenta de quien no ha conseguido comer.
	#
	# Antes se descontaba tambien aqui, asi que la banda comia dos veces: una
	# al ir a comer y otra al cerrar el dia. Con el consumo doblado, la
	# produccion nunca llegaba y el almacen se quedaba clavado en cero por
	# mucho que subieran los rendimientos.
	for person: Inhabitant in sim.people:
		if person.hunger > 70.0:
			person.hunger = clampf(person.hunger + 6.0, 0.0, 100.0)

	sim.tajo._roll_production()
	sim._roll_weather()
	sim.percances._check_mishaps()
	sim.reconocimiento._check_scout_order()

	# Los sitios que la banda ya conoce lo bastante se bautizan. Va aqui, una
	# vez por jornada: recorre las 4.096 celdas del campo y hacerlo por
	# fotograma fue lo que se comio el rendimiento la vez anterior.
	sim.reconocimiento._name_new_parajes()

	# Se cuenta al calor del fuego, no en el tajo: el que se ha quedado fuera
	# esta noche no oye nada de esto.
	_knowledge_transmission()

	# Lo trabajado hoy, al arbol de tecnicas y a lo que la banda sabe de la
	# temporada. VA ANTES DEL REPARTO: el de abajo es ya el de manana.
	# ANTES de repartir la práctica: la jornada de quien ha estado dentro de una
	# cueva cuenta como oficio de hogar. Ver [Exploracion.nueva_jornada].
	sim.exploracion.nueva_jornada()
	sim.sepulturas.nueva_jornada()
	_practica_del_dia()

	# El reparto se rehace cada jornada: una persona que ha dejado de criar,
	# o un crio que ha crecido, entran solos en los trabajos que ya tenian
	# marcados sin que el jugador tenga que acordarse.
	sim.apply_priorities()

	# Y AHORA se olvida lo que hoy no tenia camino. El reparto de arriba
	# acaba de verlo -para eso esta-, y manana se vuelve a intentar: una
	# pasarela o una piragua pueden haber abierto el paso mientras tanto.
	sim._unreachable_today.clear()
	# Y cada cual vuelve a probar los sitios que ayer no pudo: un vado que
	# bajaba, un canchal con nieve. Ver `Inhabitant.given_up`.
	for person: Inhabitant in sim.people:
		person.given_up.clear()
		# Y nadie empieza la jornada esperando: el reparto de arriba acaba de
		# repartir los oficios, asi que la primera decision de la manana es
		# nueva aunque la de anoche no llevara a nada. Ver
		# [Inhabitant.repensar_tras].
		person.repensar_tras = -1.0

	_note_daily_state()
	# Lo que se vio pasar hoy se olvida: manana la banda puede tener ya la
	# azagaya, y entonces el aviso estorba en vez de informar.
	sim._quarry_lamented.clear()

	sim.season_day += 1
	if sim.season_day >= Subsistence.DAYS_PER_SEASON:
		_advance_local_season()
	else:
		# Y si hoy tocaba decidir, se decide. Va DESPUÉS del cambio de
		# estación: el que acaba de entrar cita la suya y no se le pisa.
		sim._revisar_la_decision()


## Lo trabajado hoy: una jornada de práctica por cada cual, en el oficio en que
## trabajó, y la temporada que ha visto trabajando.
##
## **Una jornada por persona que trabajó, no por horas**: es la unidad con la
## que están calibradas las técnicas —«si me pide 100 jornadas de caza contará
## cada jornada que un cazador sale»— y se respeta.
##
## Vivía en `DemoMain._on_day_passed`, que es la capa que monta la escena:
## contaba a quien tuviera oficio y `has_task` **en la señal de medianoche**, o
## sea después de que `apply_priorities` hubiera repartido ya el día siguiente y
## cuando nadie tiene tajo. Con eso, el hogar no practicaba nunca —trabaja en la
## cueva, nunca tiene tajo en el mapa— y la ribera tampoco. Medido el 2026-09-13
## con `PracticaProbe`: 3 personas, 10 jornadas en la orilla, **0 jornadas de
## ribera** en el árbol. Ahora es una regla del juego, vive en la simulación y
## tiene prueba.
func _practica_del_dia() -> void:
	var jornadas: Dictionary = {}
	for person: Inhabitant in sim.people:
		if person.oficio_de_hoy >= 0 and person.oficio_de_hoy != Profession.Job.OCIOSO:
			jornadas[person.oficio_de_hoy] = int(
				jornadas.get(person.oficio_de_hoy, 0)) + 1
		# Una temporada no se sabe hasta haberla trabajado, y se anota por la
		# actividad de cada cual: la banda puede haber vivido tres otoños de
		# caza sin ver el remonte del salmón, porque nadie estaba en el río.
		if sim.knowledge != null and person.actividad_de_hoy >= 0:
			sim.knowledge.record_season(
				person.actividad_de_hoy as Subsistence.Activity,
				sim.estacion as Subsistence.Season)
		person.oficio_de_hoy = -1
		person.actividad_de_hoy = -1

	if sim.techs == null:
		return
	for job: int in jornadas:
		for gained: int in sim.techs.add_practice(
				job as Profession.Job, float(jornadas[job])):
			sim.tecnica_aprendida.emit(gained)


## Cuanta distancia hacia el techo transmisible se cierra en una noche de
## relato, antes de aplicar la velocidad de cada cual. Ver
## `Inhabitant.learn_rate`.
const TRANSMISSION_RATE := 0.06

## Que fraccion de lo que sabe el mejor presente se puede pasar de palabra.
##
## Contar no es lo mismo que hacer: un anciano con el 50% no transmite ese
## 50% entero por mucho que lo cuente todo, porque una parte de lo que sabe
## es la mano, no el relato -aquello que solo se fija haciendolo, no
## oyendolo-. El 75% es lo que de verdad cabe en una historia junto al
## fuego; el resto solo se aprende saliendo a probarlo.
const TRANSMISSION_CEILING := 0.75


## Transmision de conocimiento junto al fuego.
##
## Cada noche, quien esta EN LA CUEVA -durmiendo alli, no de camino ni
## acampado al raso- se acerca un poco a lo que sabe el mejor de los que
## estan esa misma noche, tarea por tarea. Es la otra mitad de aprender, al
## lado de la practica en el tajo: un crio o un anciano no salen a cazar,
## pero oyen contar la cacena junto al fuego, y de ahi sacan algo igual. El
## techo NO es lo que sabe el mejor presente, es el [TRANSMISSION_CEILING]
## de eso: se escucha y se acerca, no se supera de oidas ni se iguala del
## todo.
##
## Solo cuenta quien esta AHI esa noche. Quien anda de expedicion o acampado
## fuera no oye nada de esto, por mucho que lleve tres jornadas camino de
## casa: es la unica forma honesta de que "en la cueva juntos" signifique
## algo.
func _knowledge_transmission() -> void:
	var present: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		# Presente es estar EN el abrigo, galeria incluida: preguntando doce
		# metros al punto del abrigo, una cueva con la galeria mas adentro
		# dejaba a los que duermen dentro fuera del corro, y entonces no se
		# enseña nadie a nadie sin que se vea por ninguna parte.
		if person.state == Inhabitant.State.DURMIENDO \
				and sim._at_shelter(person):
			present.append(person)
	if present.size() < 2:
		return

	# Lo mejor que se sabe esta noche, tarea por tarea, entre los presentes.
	# Quien no esta en la cueva no cuenta ni como maestro ni como alumno.
	var best_known: Dictionary = {}
	for person: Inhabitant in present:
		for task: int in person.skill:
			var value: float = float(person.skill[task])
			if value > float(best_known.get(task, 0.0)):
				best_known[task] = value

	for person: Inhabitant in present:
		for task: int in best_known:
			# El techo YA NO es fijo: lo que hay pintado en la pared lo sube,
			# tarea por tarea. Es la diferencia entre contar una cacería y
			# dejarla puesta -ver `paintings_ceiling` y [Tale]-, y sin
			# paredes devuelve exactamente el de siempre.
			var ceiling: float = float(best_known[task]) \
				* sim.pinturas.paintings_ceiling(task)
			var mine := person.skill_in(task)
			if ceiling <= mine:
				continue
			var gain := (ceiling - mine) * TRANSMISSION_RATE * person.learn_rate()
			person.skill[task] = minf(mine + gain, ceiling)


## --- El parte de lo que se ha echado a perder ----------------------------
##
## La podredumbre existía —[Storehouse.age] la aplica desde siempre— y NO SE
## VEÍA: el almacén enseñaba un número que no subía y desde fuera un montón que
## no crece porque nadie lo trae y uno que no crece porque se pudre se leen
## igual. Ahora se dice todos los días, con nombre y cantidad.

## Por encima de estas raciones perdidas en una jornada, el parte deja de ser
## rutina y pasa a ser noticia que sobrevive a la criba de la crónica. Cuatro
## raciones son dos días de una persona: por debajo de eso es la merma normal
## de una despensa, por encima es que algo se está haciendo mal.
const MERMA_QUE_DUELE := 4.0


## Une una lista como se diría en voz alta: «a, b y c». Vacía da cadena vacía.
static func _join_and(parts: Array[String]) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return "%s y %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[-1]]


## Umbral de reserva por debajo del cual se avisa, en jornadas de comida.
const RESERVA_CRITICA := 3.0


func _note_daily_state() -> void:
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	var days_left := sim.store.days_of_food(mouths)

	if days_left < RESERVA_CRITICA and not sim._warned_hungry:
		sim._warned_hungry = true
		sim._note(Chronicle.Kind.PENURIA,
			"Queda comida para menos de tres jornadas. Con %d bocas, "
				% sim.people.size()
			+ "cualquier temporal deja a la banda sin nada.", 2)
	elif days_left > RESERVA_CRITICA * 2.5:
		sim._warned_hungry = false

	var full := sim.store.fullness()
	if full > 0.92 and not sim._warned_full:
		sim._warned_full = true
		sim._note(Chronicle.Kind.PENURIA,
			"El abrigo esta lleno: %s de %s. Lo que traigan se queda fuera."
				% [Materia.format_volume(sim.store.total_litres()),
					Materia.format_volume(sim.store.capacity_litres)], 1)
	elif full < 0.80:
		sim._warned_full = false


## Avanza la estacion desde el reloj local, SIN repetir el calculo economico
## abstracto del mapa regional.
##
## Antes `GameState.season` solo se movia a mano, desde `RegionMap`, con un
## calculo de produccion y consumo agregado para toda la estacion. Jugar en el
## asentamiento no lo tocaba: se podian vivir cien jornadas sin que llegara
## nunca el otono. Aqui la comida YA se lleva dia a dia y persona a persona, o
## sea que llamar a `GameState.advance_season()` la contaria dos veces -una
## granular, aqui, y otra agregada, alla-. Este metodo solo gira la fecha.
func _advance_local_season() -> void:
	sim.season_day = 0
	# La fecha la gira cada campamento EN SU COPIA si lo lleva el reloj de la
	# partida, y en la global si va solo. Ver [estacion].
	var nueva := ((sim.estacion + 1) % 4) as Subsistence.Season
	var otro_anyo := sim.anyo + 1 if nueva == Subsistence.Season.PRIMAVERA else sim.anyo
	if sim.dirigido:
		sim._estacion = nueva
		sim._anyo = otro_anyo
	# Y la global la gira quien la publica —el primer campamento del reloj— o la
	# simulación suelta, EN ESTE MISMO INSTANTE y no entre pasos: así quien la lea
	# dentro del paso —la firma en `paso_cerrado`, la huella de un paraje— ve lo
	# mismo que veía con un solo campamento. Ver [publica_la_fecha].
	if sim.publica_la_fecha or not sim.dirigido:
		GameState.season = nueva
		GameState.year = otro_anyo
	if sim.estacion == Subsistence.Season.PRIMAVERA:
		sim.relevo.cumplir_anyos()
		sim.relevo.revisar_vejez()
		sim.relevo.evaluar_nacimiento()
		sim.partida.evaluar_victoria()
	# El trueque no se propone aquí: se trata cuando el jugador abre la ventana.
	# Ver [Intercambio] y [PanelTrueque].
	# El parte de la partida lo da quien publica su fecha: con varios campamentos
	# escribirían todos la misma cadena a la vez. Ver [publica_la_fecha].
	if sim.publica_la_fecha or not sim.dirigido:
		GameState.last_report = "Empieza %s, año %d." % [
			Subsistence.season_name(sim.estacion), sim.anyo]
	sim._note(Chronicle.Kind.TIERRA, sim._season_line(), 2)

	# Lo que hay en cada paraje conocido se rehace para la estación nueva:
	# sin esto, un sitio se quedaba con lo que daba el día que se bautizó
	# para siempre -miel en pleno invierno, cuernas caídas en julio-, y la
	# estación no se notaba en QUÉ hay que ir a buscar, solo en el
	# multiplicador de rendimiento. Ver [Paraje.fill_contents].
	if sim.field:
		# Y en primavera, antes de rehacerlo, el remonte: el río se repuebla.
		# Ver [ResourceField.remonte].
		if sim.estacion == Subsistence.Season.PRIMAVERA:
			sim.field.remonte()
		for paraje: Paraje in sim.parajes.list:
			paraje.fill_contents(sim.field, sim.estacion)

	sim.season_changed.emit(sim.estacion, sim.anyo)

	if sim.estacion == Subsistence.Season.PRIMAVERA:
		sim.hogar.fin_del_invierno()
	# Y la crecida de la estación que entra puede llevarse una pasarela. Va
	# aquí, con el caudal de la estación nueva, que es el que la arrastra.
	sim.pasarelas.revisar_riada(float(Temporada.CAUDAL.get(sim.estacion, 1.0)))
	sim._citar_la_decision()
