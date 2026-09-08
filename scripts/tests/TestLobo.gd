class_name TestLobo
extends TestCase
## El trato con los lobos: que las dos ramas existan y que ninguna sea gratis.
##
## Es un sistema de ramas, y en un sistema de ramas lo que se rompe no es una
## cuenta: es que un camino deje de tener salida sin que nadie se entere. Dos
## de estas pruebas están escritas contra fallos que `PerroProbe` encontró
## midiendo, no imaginando —el camino amable era imposible de andar y el del
## enemigo no se podía alcanzar—, y están aquí para que no vuelvan.


func suite_name() -> String:
	return "El lobo"


## Una banda con montón de sobra y lobos en el valle: lo mínimo para que el
## camino exista.
func _con_lobos() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.FRUTO_SECO, 5000.0)
	sim.desechos.tirar_litros(Materia.Kind.MARISCO,
		ElLobo.MONTON_QUE_ATRAE * 2.0)
	var fauna := WildlifeHerds.new()
	fauna._animals.append({"species": "lobo"})
	sim.caceria.wildlife = fauna
	return sim


## Contesta a los momentos que salten eligiendo por el texto del botón.
func _responder(sim: SettlementSim, clave: String) -> void:
	sim.moment_raised.connect(func(momento: Moment) -> void:
		for opcion: Dictionary in momento.options:
			if String(opcion["label"]).contains(clave):
				(opcion["on_pick"] as Callable).call()
				return)


func _correr(sim: SettlementSim, dias: int) -> void:
	for d in range(dias):
		sim.day = d + 1
		sim.lobo.nuevo_dia()


func test_sin_monton_los_lobos_no_se_acercan() -> void:
	# Es la condición de arranque de todo el sistema, y la que lo encadena con
	# los desechos: la basura es lo que trae al animal.
	var sim := _con_lobos()
	sim.desechos.litros.clear()
	_correr(sim, 40)
	assert_eq(sim.lobo.paso, ElLobo.Paso.LEJOS,
		"sin montón que rebañar no hay merodeo")


func test_sin_lobos_en_el_valle_no_hay_camino() -> void:
	# Si el jugador ha barrido los lobos a azagayazos, no puede salir un perro
	# de la nada: se le pregunta a la fauna de verdad, no a un dado.
	var sim := _con_lobos()
	sim.caceria.wildlife = WildlifeHerds.new()
	_correr(sim, 40)
	assert_eq(sim.lobo.paso, ElLobo.Paso.LEJOS,
		"sin lobos vivos no hay merodeo")


func test_con_monton_y_lobos_empiezan_a_merodear() -> void:
	var sim := _con_lobos()
	_correr(sim, ElLobo.NOCHES_PARA_EMPEZAR)
	assert_eq(sim.lobo.paso, ElLobo.Paso.MERODEAN,
		"a las seis noches vienen al montón")


func test_el_camino_amable_llega_al_perro() -> void:
	# LA PRUEBA IMPORTANTE. `PerroProbe` midió que eligiendo siempre lo amable
	# se llegaba a 24 de trato y la camada pedía 55: el camino no se podía
	# andar y el perro era código muerto. Ver [ElLobo.POR_NOCHE].
	var sim := _con_lobos()
	_responder(sim, "Dejarlos comer")
	_responder(sim, "Echarle una tajada")
	_responder(sim, "Coger un cachorro")
	_correr(sim, 200)
	assert_true(sim.lobo.perro,
		"eligiendo lo amable se llega al perro dentro de un año de partida")


func test_criar_el_cachorro_cuesta_lo_que_dice() -> void:
	var sim := _con_lobos()
	_responder(sim, "Dejarlos comer")
	_responder(sim, "Echarle una tajada")
	_responder(sim, "Coger un cachorro")
	# Justo antes de las jornadas de cría no puede haber perro todavía.
	_correr(sim, 120)
	assert_false(sim.lobo.perro,
		"a las ciento veinte jornadas el cachorro aún no es perro")


func test_matar_dos_veces_pone_a_la_manada_en_contra() -> void:
	# La otra rama, y la que NO existía: los momentos se preguntaban una sola
	# vez, así que en toda la partida había dos ocasiones de matar y con dos no
	# se llegaba. Ver [ElLobo._volver_a_empezar].
	var sim := _con_lobos()
	_responder(sim, "Matar")
	_correr(sim, 40)
	assert_true(sim.lobo.hostil(),
		"matando a los que vienen al montón la manada se pone en contra")


func test_la_hostilidad_se_paga_en_el_vivac() -> void:
	var sim := _con_lobos()
	_responder(sim, "Matar")
	_correr(sim, 40)
	assert_gt(sim.lobo.riesgo_de_vivac(), 1.0,
		"con la manada en contra, dormir fuera es más peligroso")


func test_el_perro_hace_el_vivac_mas_seguro() -> void:
	var sim := _con_lobos()
	sim.lobo.perro = true
	assert_lt(sim.lobo.riesgo_de_vivac(), 1.0,
		"a un campamento con perro no lo sorprenden de noche")


func test_el_perro_come_y_si_no_hay_se_va() -> void:
	# Es lo que lo hace una decisión y no un regalo: una boca más.
	var sim := _con_lobos()
	sim.lobo.perro = true
	sim.store.take(Materia.Kind.FRUTO_SECO, 5000.0)
	_correr(sim, 1)
	assert_false(sim.lobo.perro,
		"sin qué darle, el perro se vuelve con la manada")


func test_el_perro_corta_el_rastro_a_veces_y_no_siempre() -> void:
	var sim := _con_lobos()
	sim.lobo.perro = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cortados := 0
	for i in range(2000):
		if sim.lobo.corta_el_rastro(rng):
			cortados += 1
	assert_between(float(cortados) / 2000.0,
		ElLobo.CORTA_EL_RASTRO - 0.06, ElLobo.CORTA_EL_RASTRO + 0.06,
		"corta el rastro perdido cerca de lo declarado, no siempre")


func test_sin_perro_no_corta_nada() -> void:
	var sim := _con_lobos()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cortados := 0
	for i in range(500):
		if sim.lobo.corta_el_rastro(rng):
			cortados += 1
	assert_eq(cortados, 0, "sin perro no se recupera ningún rastro")
