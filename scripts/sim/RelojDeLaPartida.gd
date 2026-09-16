class_name RelojDeLaPartida
extends Node
## Una sola fecha para toda la partida: da los pasos a todos los campamentos.
##
## SISTEMAS §23, tarea 4. Con un campamento, el reloj era de la simulación y
## bastaba —SPECS §3.1—. Con varios, cada `SettlementSim` daba sus pasos en su
## `_process`, y eso rompe la fecha de tres maneras: la noche se salta mirando
## `nadie_trabaja` de cada una, así que una la salta y otra no; una decisión para
## sólo la simulación que la levanta; y la estación global la giraba cada una. Ahora cada una gira su copia y sólo la
## primera publica la de la partida.
##
## **El paso no cambia**: el mismo `PASO_FIJO`, el mismo tope de
## `PASOS_POR_CUADRO`, la misma noche acelerada con el mismo presupuesto, y las
## tres señales de §3.2 salen donde salían. Lo único que cambia es quién cuenta:
## aquí se decide cuántos pasos toca dar, y se dan **los mismos a todos**, uno a
## uno y en el mismo orden. Una simulación dirigida no da pasos por su cuenta:
## ver [SettlementSim.dirigido].

## Las simulaciones que llevan este reloj, en el orden en que dan cada paso.
var campamentos: Array[SettlementSim] = []

## La velocidad de la partida entera. Cero es la pausa de todos.
var time_scale: float = 1.0

## Si la noche se salta cuando no trabaja nadie en ningún campamento. Ver
## [SettlementSim.noche_acelerada]: el interruptor es para medir, no para jugar.
var noche_acelerada: bool = true

## Reloj real por simular, el mismo papel que [SettlementSim._pendiente].
var _pendiente := 0.0

## LA FECHA DE LA PARTIDA: la del primer campamento con gente, y si todos se han
## ido de viaje, la que lleva el reloj él solo. Una sola fecha para todos
## (SISTEMAS §23, punto 5): un grupo de camino no deja de contar jornadas porque
## no quede nadie en ningún campamento.
var dia: int = 1
var hora: float = 0.0
var dia_de_estacion: int = 0

## Se emite en la barrera cuando la fecha pasa a otra jornada. Es lo que hace
## andar a los viajes. Ver [Campamentos].
signal jornada_cerrada(dia: int)

## La velocidad que se les dio a las simulaciones en la última vuelta.
##
## Para saber si alguien la ha cambiado desde fuera: la interfaz y las decisiones
## siguen tocando la `time_scale` de UNA simulación —la que se mira, la que
## levanta la decisión—, y lo que cambie en cualquiera pasa a ser de todas.
var _escala_dada: float = 1.0


## Toma una simulación: desde ahora sus pasos los da este reloj.
func dirigir(sim: SettlementSim) -> void:
	if campamentos.has(sim):
		return
	# La fecha de la partida, en su copia: desde ahora la lee y la gira ella. Ver
	# [SettlementSim.estacion].
	sim._estacion = GameState.season
	sim._anyo = GameState.year
	sim.dirigido = true
	# LA PRIMERA LE DA SU VELOCIDAD AL RELOJ; LAS DEMÁS LA TOMAN DE ÉL.
	#
	# Las demás, porque una simulación recién montada trae la suya: si el reloj
	# estaba en pausa, la adoptaría como un cambio del jugador y despausaría a
	# todos. Y la primera al revés, porque el reloj todavía no tiene partida:
	# `setup` deja la simulación EN PAUSA hasta que se contesta la decisión del
	# arranque, y la primera versión le ponía la del reloj —1— y la dejaba andar a
	# ×1 mientras se montaba el resto, a merced del reloj de pared. Lo cazó la
	# firma: la partida se separaba en la jornada 2. Ver [_adoptar_la_velocidad].
	if campamentos.is_empty():
		time_scale = sim.time_scale
		_escala_dada = sim.time_scale
		dia = sim.day
		hora = sim.hour
		dia_de_estacion = sim.season_day
	else:
		sim.time_scale = _escala_dada
	campamentos.append(sim)
	_repartir_el_giro()


## Suelta una simulación, que vuelve a dar sus pasos sola.
func soltar(sim: SettlementSim) -> void:
	campamentos.erase(sim)
	sim.dirigido = false
	sim.publica_la_fecha = true
	_repartir_el_giro()


## La fecha de la partida la publica sólo una simulación: la primera, hasta el
## primer paso, que la reparte al primero CON GENTE. Ver
## [SettlementSim.publica_la_fecha] y [_un_paso_a_todos].
func _repartir_el_giro() -> void:
	for i in range(campamentos.size()):
		campamentos[i].publica_la_fecha = i == 0


func _process(delta: float) -> void:
	if campamentos.is_empty():
		return
	# MIENTRAS SE CARGA, LA PARTIDA NO ANDA, y el tiempo de esos cuadros se tira: no se
	# guarda para ponerse al día al terminar. Detrás de la pantalla de carga no se ve
	# nada, y con la carga repartida entre cuadros el reloj seguía corriendo por detrás.
	# INTERFAZ §9, SPECS §3.1.
	if Carga.abierta():
		return
	Cronometro.tramo_raiz("reloj de la partida")
	# El horno de rejillas de quien está fuera del árbol: su `_process` no corre,
	# y amasar aun con el reloj parado es lo que hacía allí. No cambia la partida.
	# Ver [Campamentos.dejar_de_mirar] y [SettlementSim._process].
	for sim: SettlementSim in campamentos:
		if not sim.is_inside_tree() and sim.horno != null:
			sim.horno.amasar()
	_adoptar_la_velocidad()
	if time_scale <= 0.0:
		Cronometro.cierra("reloj de la partida")
		return

	_pendiente += delta
	var dados := 0
	while _pendiente >= SettlementSim.PASO_FIJO and dados < SettlementSim.PASOS_POR_CUADRO:
		_pendiente -= SettlementSim.PASO_FIJO
		dados += 1
		_un_paso_a_todos()
		# SI ALGUIEN PARA EL RELOJ DENTRO DEL PASO, SE ACABA AQUÍ, igual que
		# cortaba [SettlementSim._process]. Todos terminan el paso en que se
		# levantó la decisión —si no, el que la levantó llevaría un paso más o
		# menos que los otros— y ninguno da el siguiente.
		if _adoptar_la_velocidad() <= 0.0:
			break

	# Y AQUÍ SE SALTA LA NOCHE, con la misma regla y el mismo presupuesto que la
	# simulación sola, pero mirando a TODOS: un campamento durmiendo no acelera
	# mientras en otro hay alguien trabajando. Ver [SettlementSim.noche_acelerada].
	if noche_acelerada and time_scale > 0.0 and _nadie_trabaja_en_ninguno():
		var primero := campamentos[0]
		var hasta := Time.get_ticks_usec() \
			+ int(SettlementSim.MS_DE_NOCHE_TOPE * 1000.0)
		var dia_al_entrar := primero.day
		var faltan := delta * SettlementSim.NOCHE_HORAS_POR_SEGUNDO
		var por_paso := SettlementSim.PASO_FIJO * time_scale \
			/ primero.seconds_per_day * 24.0
		Cronometro.tramo("noche acelerada")
		while time_scale > 0.0 and faltan > 0.0 and Time.get_ticks_usec() < hasta:
			_un_paso_a_todos()
			faltan -= por_paso
			if _adoptar_la_velocidad() <= 0.0:
				break
			# El cierre de jornada corta el cuadro, por lo mismo que en la
			# simulación sola: es el peor fotograma de la partida.
			if primero.day != dia_al_entrar:
				break
			if not _nadie_trabaja_en_ninguno():
				break
		Cronometro.cierra("noche acelerada")
	Cronometro.cierra("reloj de la partida")


## Se emite en la barrera, con todos los campamentos acabado su paso y ANTES de
## juntar lo descubierto y entregar las decisiones: el límite limpio de la
## partida entera, el equivalente de `paso_cerrado` para varios campamentos. Una
## firma se toma aquí, en serie y en paralelo por igual (SPECS §3.2).
signal pasos_cerrados()

## Si los campamentos dan su paso a la vez, cada uno en un hilo.
##
## Verdadero por defecto. En falso, uno detrás de otro en el hilo principal: es
## la pareja con la que se demuestra que el paralelo no cambia la partida.
var paralelo: bool = true

## Los que dan el paso en curso, y de ellos los que van a otro hilo.
var _del_paso: Array[SettlementSim] = []
var _fuera_del_arbol: Array[SettlementSim] = []


## Un `PASO_FIJO` a cada campamento con gente, y la barrera.
##
## Uno vacío no se simula —sin gente no da pasos, igual que la simulación sola—.
##
## **En paralelo**, cada campamento en un hilo del `WorkerThreadPool`, y se espera
## a todos. Es seguro porque en su paso un campamento sólo toca lo suyo: la fecha
## la lee de su copia, lo descubierto va a su cola, las decisiones esperan, el
## cepo no cuenta fuera del hilo principal y el alfiler de una cueva se enciende
## diferido. Ver SISTEMAS §23, «un hilo por campamento».
##
## **Salvo el paso que cruza medianoche, que va en serie**: el cierre de la
## jornada es donde más cosas pasan —y el giro de la estación, que el primer
## campamento publica en `GameState` en ese mismo instante—, y es un paso al día.
##
## **La barrera** es lo que va después: lo que es de la partida —lo descubierto
## de la comarca— se junta en orden de campamento, que no depende de quién acabe
## antes, y detrás las decisiones que se levantaron dentro del paso. Ver
## [SettlementSim.descubrir] y [SettlementSim.raise_moment].
func _un_paso_a_todos() -> void:
	_del_paso.clear()
	for sim: SettlementSim in campamentos:
		if not sim.people.is_empty() and sim._terrain != null:
			_del_paso.append(sim)
	# La fecha la publica el primero CON GENTE: si fuera el primero de la lista y
	# se quedara vacío, nadie giraría la estación de la partida.
	for sim: SettlementSim in campamentos:
		sim.publica_la_fecha = not _del_paso.is_empty() and sim == _del_paso[0]
	var dia_antes := dia
	if paralelo and _del_paso.size() > 1 and not _cruza_la_medianoche():
		# Sólo van a otro hilo los que están FUERA del árbol: Godot no deja tocar
		# un nodo del árbol desde otro hilo, y el campamento que se mira está
		# dentro. Ése da su paso aquí, en el principal, a la vez que los demás.
		_fuera_del_arbol.clear()
		for sim: SettlementSim in _del_paso:
			if not sim.is_inside_tree():
				_fuera_del_arbol.append(sim)
		var tarea := WorkerThreadPool.add_group_task(_paso_del_hilo,
			_fuera_del_arbol.size(), -1, true, "pasos de los campamentos")
		for sim: SettlementSim in _del_paso:
			if sim.is_inside_tree():
				_paso_de(sim)
		WorkerThreadPool.wait_for_group_task_completion(tarea)
	else:
		for sim: SettlementSim in _del_paso:
			Cronometro.tramo("paso de simulacion")
			_paso_de(sim)
			Cronometro.cierra("paso de simulacion")
	pasos_cerrados.emit()
	for sim: SettlementSim in campamentos:
		for site: Site in sim.descubrimientos:
			GameState.discover(site)
		sim.descubrimientos.clear()
		for site: Site in sim.avistamientos:
			GameState.avistar(site)
		sim.avistamientos.clear()
		# Y la niebla que levantó, que descubre lo de dentro. Ver
		# [SettlementSim.levantar_niebla].
		for forma: Dictionary in sim.niebla_por_levantar:
			GameState.levantar_niebla(forma)
		sim.niebla_por_levantar.clear()
	# Y las decisiones, después de lo descubierto y en orden de campamento: una
	# decisión puede hablar de lo que se acaba de descubrir.
	for sim: SettlementSim in campamentos:
		sim.entregar_momentos()
	# Y la fecha, que al cambiar de jornada hace andar a quien va de camino.
	if not _del_paso.is_empty():
		dia = _del_paso[0].day
		hora = _del_paso[0].hour
		dia_de_estacion = _del_paso[0].season_day
	else:
		_andar_la_fecha_sola()
	if dia != dia_antes:
		jornada_cerrada.emit(dia)


## La fecha sin ningún campamento que la lleve: todos de viaje. Avanza lo mismo
## que un paso —`PASO_FIJO` por la velocidad— y gira la estación y el año como
## lo haría el primer campamento. Ver [SettlementSim._advance_local_season].
func _andar_la_fecha_sola() -> void:
	var segundos_por_dia := 120.0
	if not campamentos.is_empty():
		segundos_por_dia = campamentos[0].seconds_per_day
	hora += SettlementSim.PASO_FIJO * time_scale / segundos_por_dia * 24.0
	if hora < 24.0:
		return
	hora -= 24.0
	dia += 1
	dia_de_estacion += 1
	if dia_de_estacion >= Subsistence.DAYS_PER_SEASON:
		dia_de_estacion = 0
		GameState.season = ((GameState.season + 1) % 4) as Subsistence.Season
		if GameState.season == Subsistence.Season.PRIMAVERA:
			GameState.year += 1


func _paso_del_hilo(indice: int) -> void:
	_paso_de(_fuera_del_arbol[indice])


func _paso_de(sim: SettlementSim) -> void:
	sim._en_paso = true
	sim._advance(SettlementSim.PASO_FIJO)
	sim._en_paso = false


## Si este paso lleva a algún campamento a la jornada siguiente. Todos van a la
## misma hora, así que basta con mirar uno —pero se miran todos, por si alguno se
## sumó a destiempo—.
func _cruza_la_medianoche() -> bool:
	for sim: SettlementSim in _del_paso:
		var horas := SettlementSim.PASO_FIJO * sim.time_scale / sim.seconds_per_day * 24.0
		if sim.hour + horas >= 24.0:
			return true
	return false


## Si alguien ha cambiado la velocidad de una simulación, pasa a ser la de todas.
## Devuelve la velocidad que queda.
##
## Se mira la PRIMERA que difiera de lo que se les dio, en el orden de la lista:
## una decisión que para un campamento se ve igual en cualquier vuelta, y la
## elección no depende del fotograma.
func _adoptar_la_velocidad() -> float:
	for sim: SettlementSim in campamentos:
		if not is_equal_approx(sim.time_scale, _escala_dada):
			time_scale = sim.time_scale
			break
	if not is_equal_approx(time_scale, _escala_dada):
		_escala_dada = time_scale
	for sim: SettlementSim in campamentos:
		sim.time_scale = time_scale
	return time_scale


func _nadie_trabaja_en_ninguno() -> bool:
	var alguno_con_gente := false
	for sim: SettlementSim in campamentos:
		if sim.people.is_empty():
			continue
		alguno_con_gente = true
		if not sim.nadie_trabaja():
			return false
	return alguno_con_gente
