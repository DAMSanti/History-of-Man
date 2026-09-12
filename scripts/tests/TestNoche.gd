class_name TestNoche
extends TestCase
## La noche se salta cuando no hay nadie trabajando.
##
## Lo que aquí se asegura no es que vaya más rápido —eso se mide, no se
## comprueba— sino las cuatro reglas que la aceleración no puede romper: quién
## cuenta como dormido, quién la frena, y que ni la decisión del jugador ni el
## tamaño del paso se vean afectados. Ver EPOCA_01 §10.1, tanda 1, frente 2.


func suite_name() -> String:
	return "Noche"


func _banda(cuantos: int) -> Array[Inhabitant]:
	var gente: Array[Inhabitant] = []
	for i in range(cuantos):
		var quien := Inhabitant.new()
		quien.id = i
		quien.state = Inhabitant.State.DURMIENDO
		gente.append(quien)
	return gente


func _sim(cuantos: int) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.people = _banda(cuantos)
	return sim


# ------------------------------------------------- quién frena la noche --

func test_con_todos_durmiendo_no_trabaja_nadie() -> void:
	assert_true(_sim(5).nadie_trabaja(), "nadie trabaja")


func test_el_que_vuelve_andando_a_casa_no_frena_la_noche() -> void:
	# CAMBIÓ AL PROBARLO EN EL JUEGO, y queda escrito porque la primera versión
	# afirmaba lo contrario. Con «todos duermen» bastaba uno volviendo del
	# monte para bloquear la aceleración durante la hora larga en que la banda
	# se va acostando, y la noche se quedaba a medio saltar: 71 s por cuatro
	# jornadas contra los 61 de ahora. Volver a casa no es trabajar.
	var sim := _sim(5)
	sim.people[3].state = Inhabitant.State.VOLVIENDO
	assert_true(sim.nadie_trabaja(), "volver a casa no es nada que mirar")


func test_prospectar_y_batir_la_comarca_si_la_frenan() -> void:
	# Los tres estados en los que pasa algo que el jugador puede querer ver.
	for estado in [Inhabitant.State.BUSCANDO, Inhabitant.State.RECONOCIENDO]:
		var sim := _sim(5)
		sim.people[1].state = estado
		assert_false(sim.nadie_trabaja(),
			"prospectar y batir la comarca cuentan como trabajar")


func test_uno_trabajando_frena_la_noche() -> void:
	var sim := _sim(5)
	sim.people[0].state = Inhabitant.State.TRABAJANDO
	assert_false(sim.nadie_trabaja(), "quien trabaja no deja saltar la noche")


func test_el_que_vivaquea_lejos_no_bloquea_la_noche() -> void:
	# EL CRITERIO EXPLÍCITO DE LA SPEC. Si el vivac no contara como dormir, un
	# solo cazador a tres kilómetros bloquearía la aceleración todas las
	# noches, que es lo contrario de lo que se pidió. Entra solo, porque dormir
	# a la intemperie también acaba en DURMIENDO.
	var sim := _sim(5)
	var cazador := sim.people[2]
	cazador.state = Inhabitant.State.DURMIENDO
	cazador.position = Vector3(3000.0, 0.0, 3000.0)
	cazador.bivouac_day = 1
	assert_true(sim.nadie_trabaja(),
		"el que vivaquea a tres kilómetros no bloquea la noche")


func test_sin_gente_no_se_acelera_nada() -> void:
	# Una banda extinta no «duerme»: la partida ha terminado, y acelerar ahí
	# sería girar en el vacío. Ver `SettlementSim.partida_terminada`.
	var sim := SettlementSim.new()
	assert_false(sim.nadie_trabaja(), "sin nadie no hay noche que saltar")


# --------------------------------------- lo que la noche no puede romper --

func test_el_paso_fijo_no_se_toca_al_acelerar() -> void:
	# Acelerar es dar MÁS pasos, no pasos más largos. Si esto cambiara, la
	# misma semilla dejaría de dar la misma partida: cambiaría el instante de
	# `hour_passed` y el trozo de fauna de `_fauna_pendiente`.
	assert_near(SettlementSim.PASO_FIJO, 1.0 / 30.0, 0.000001,
		"el paso de la simulación es el de siempre")


func test_la_noche_tiene_presupuesto_y_no_velocidad() -> void:
	# Es lo que acota el fotograma malo por construcción, que es el frente 4.
	assert_gt(SettlementSim.MS_DE_NOCHE_POR_CUADRO, 0.0,
		"la noche avanza algo")
	assert_lt(SettlementSim.MS_DE_NOCHE_POR_CUADRO, 16.7,
		"pero nunca un fotograma entero de 60 Hz")
	# Y el valor está medido, no elegido: el ahorro se agota en 8 ms —de ahí
	# en adelante se compran uno o dos segundos por cuatro jornadas y se paga
	# en fotograma medio, y pasados los 24, en tirones—. Ver ESTADO.md §2.


func test_con_una_decision_levantada_el_reloj_no_corre() -> void:
	# La noche no puede atropellar una decisión del jugador. Lo sostiene que
	# `_process` sale antes de simular con `time_scale` a cero, y que el bucle
	# de la noche lo vuelve a mirar en cada vuelta.
	var momento := Moment.new()
	momento.options = [{"texto": "ir"}, {"texto": "quedarse"}]
	assert_true(momento.is_decision(),
		"un momento con opciones para el reloj")
	var sim := _sim(5)
	sim.time_scale = 0.0
	var antes := sim.day
	sim._process(1.0)
	assert_eq(sim.day, antes, "con el reloj parado no avanza ni una jornada")


# ------------------------------------------------- que la noche SÍ corre --

func _sim_andando() -> SettlementSim:
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.people = _banda(3)
	sim.time_scale = 20.0
	sim.hour = 1.0
	return sim


func _horas_en(sim: SettlementSim, segundos: float) -> Array:
	var horas: Array = []
	sim.hour_passed.connect(func(dia: int, hora: int) -> void: horas.append([dia, hora]))
	var hecho := 0.0
	while hecho < segundos - 0.0001:
		sim._process(SettlementSim.PASO_FIJO)
		hecho += SettlementSim.PASO_FIJO
	return horas


func test_con_la_banda_dormida_pasa_mas_noche_por_segundo_de_reloj() -> void:
	# La razón de ser del frente: los mismos segundos de reloj tienen que dar
	# más horas de juego cuando no hay nada que mirar.
	var dormida := _sim_andando()
	var a_pelo := _sim_andando()
	a_pelo.noche_acelerada = false
	var con_noche := _horas_en(dormida, 1.0).size()
	var sin_noche := _horas_en(a_pelo, 1.0).size()
	assert_gt(float(con_noche), float(sin_noche),
		"la noche acelerada avanza más horas en el mismo reloj")


func test_la_noche_no_se_salta_ninguna_hora() -> void:
	# Acelerar es dar MÁS pasos, no pasos más largos, así que ninguna hora
	# puede quedarse sin anunciar: si esto fallara, algo que tiene que ocurrir
	# a una hora concreta no ocurriría nunca.
	#
	# Y SE COMPRUEBA CON UNA SOLA ASERCIÓN, a propósito: un assert por hora
	# emitida haría que el total de comprobaciones de la suite dependiera de lo
	# rápida que sea la máquina, y ese total es el suelo que dice si una prueba
	# se ha caído. Pasó: bajó de 7 006 a 7 001 al tocar el presupuesto de la
	# noche, sin que se rompiera nada.
	var horas := _horas_en(_sim_andando(), 1.0)
	assert_gt(float(horas.size()), 1.0, "ha corrido algo de noche")
	var todas_seguidas := true
	for i in range(1, horas.size()):
		if int(horas[i][1]) != (int(horas[i - 1][1]) + 1) % 24:
			todas_seguidas = false
	assert_true(todas_seguidas, "las horas van de una en una, sin saltos")
