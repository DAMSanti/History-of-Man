class_name TestDecisiones
extends TestCase
## Las decisiones del año: que cuesten, y que se sepa lo que cuestan.
##
## EPOCA_01 §10.1, tanda 2, frente 8. El criterio que ordena todo lo demás es
## que **un momento con dos botones cuya elección da igual no cuenta como
## decisión**, aunque pare el reloj. Para poder contarlo, cada opción tiene que
## declarar qué cambia —`Moment.options[i]["cuesta"]`—; sin eso el criterio es
## una opinión.


func suite_name() -> String:
	return "Decisiones"


func _nada() -> void:
	pass


# ------------------------------------------ D1: la elección importa o no --

func test_sin_opciones_no_hay_eleccion() -> void:
	var m := Moment.new()
	assert_false(m.la_eleccion_importa(), "sin opciones no se decide nada")
	m.options = [Moment.opcion("Seguir", "", _nada)]
	assert_false(m.la_eleccion_importa(), "con una sola, tampoco")


func test_dos_botones_que_cuestan_lo_mismo_no_son_una_decision() -> void:
	# EL CASO QUE EL CRITERIO EXCLUYE A PROPÓSITO: parece una decisión y no lo
	# es, porque elijas lo que elijas pasa lo mismo.
	var m := Moment.new()
	m.options = [
		Moment.opcion("Por aquí", "", _nada, {"jornadas": 2}),
		Moment.opcion("Por allá", "", _nada, {"jornadas": 2}),
	]
	assert_false(m.la_eleccion_importa(), "mismo coste, no cuenta")


func test_si_una_opcion_cuesta_distinto_la_eleccion_importa() -> void:
	var m := Moment.new()
	m.options = [
		Moment.opcion("Dejarlo", "", _nada),
		Moment.opcion("Ir", "", _nada, {"jornadas": 4}),
	]
	assert_true(m.la_eleccion_importa(),
		"no hacer nada frente a gastar cuatro jornadas es una decisión")


func test_cuentan_las_tres_cifras_de_la_spec() -> void:
	for clave in ["despensa", "jornadas", "riesgo"]:
		var m := Moment.new()
		m.options = [
			Moment.opcion("A", "", _nada),
			Moment.opcion("B", "", _nada, {clave: 1.0}),
		]
		assert_true(m.la_eleccion_importa(), "«%s» cuenta como coste" % clave)


func test_el_trueque_es_una_decision_que_importa() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.contacto.ocupados[7] = true
	sim.contacto.conocerse(7)
	var caja := {"m": null}
	sim.moment_raised.connect(func(m: Moment) -> void: caja["m"] = m)
	sim.intercambio.proponer_el_trato()
	var tarjeta := caja["m"] as Moment
	assert_true(tarjeta != null, "sale la tarjeta del trueque")
	if tarjeta == null:
		return
	assert_true(tarjeta.la_eleccion_importa(), "y elegir cambia cifras")


func test_ir_a_tratar_con_comida_cuesta_despensa_y_con_piel_no() -> void:
	# La piel no se come: ofrecerla no toca la despensa, sólo las jornadas.
	var con_comida := Intercambio._cuesta(Materia.Kind.FRUTO_SECO, Intercambio.Como.JUSTO)
	var con_piel := Intercambio._cuesta(Materia.Kind.PIEL, Intercambio.Como.JUSTO)
	assert_lt(float(con_comida.get("despensa", 0.0)), 0.0, "la comida sale de la despensa")
	assert_near(float(con_piel.get("despensa", 0.0)), 0.0, 0.0001, "la piel no")
	assert_eq(int(con_piel.get("jornadas", 0)), Intercambio.JORNADAS_DE_TRUEQUE,
		"pero las jornadas se van igual")


# --------------------------------------- D3: la berrea deja de ser gratis --

## Una banda con dos que pueden cazar y un anciano que no, todos recolectando.
func _banda() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	var recoger := Profession.task_id(Profession.Job.RECOLECCION)
	for i in range(3):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "P%d" % i
		if i < 2:
			p.age_group = Inhabitant.Age.ADULTO
			p.age_years = 30
		else:
			p.age_group = Inhabitant.Age.ANCIANO
			p.age_years = 62
		p.set_priority(recoger, 1)
		sim.people.append(p)
	sim.day = 100
	return sim


func _caza_mayor() -> int:
	return Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR)


func _recolecta(p: Inhabitant) -> bool:
	for task: int in p.priorities:
		if Profession.task_job(task) == Profession.Job.RECOLECCION:
			return true
	return false


func test_volcarse_pone_la_caza_mayor_la_primera() -> void:
	# ANTES LA PONÍA A 3, que en este reparto es la MENOS urgente: quien tuviera
	# recolección a 1 seguía recolectando y volcarse no hacía casi nada.
	var sim := _banda()
	sim.focus_on_rut()
	assert_eq(int(sim.people[0].priorities.get(_caza_mayor(), 0)), 1,
		"la caza mayor, lo más urgente")


func test_volcarse_apaga_la_recoleccion_de_quien_va() -> void:
	# EL CRITERIO LITERAL: «ese mes no se recolecta ni se hace leña».
	var sim := _banda()
	sim.focus_on_rut()
	assert_false(_recolecta(sim.people[0]), "quien caza deja de recolectar")
	assert_false(_recolecta(sim.people[1]), "los dos")


func test_quien_no_puede_cazar_sigue_recolectando() -> void:
	var sim := _banda()
	sim.focus_on_rut()
	assert_true(_recolecta(sim.people[2]), "el anciano no va a la berrea y sigue a lo suyo")


func test_la_berrea_dura_un_mes_y_no_para_siempre() -> void:
	var sim := _banda()
	sim.focus_on_rut()
	sim.day += SettlementSim.DIAS_DE_BERREA - 1
	sim._acabar_la_berrea()
	assert_false(_recolecta(sim.people[0]), "la víspera del fin, sigue en la berrea")
	sim.day += 1
	sim._acabar_la_berrea()
	assert_true(_recolecta(sim.people[0]), "y al acabar el mes, vuelve a recolectar")
	assert_eq(sim.berrea_hasta_el_dia, -1, "y ya no hay berrea en curso")


func test_al_acabar_cada_uno_vuelve_exactamente_a_lo_suyo() -> void:
	# No «a lo de por defecto»: a lo que tenía. Si alguien había puesto la
	# talla a 2 antes de la berrea, la recupera.
	var sim := _banda()
	var tallar := Profession.task_id(Profession.Job.MANUFACTURA, Profession.Speciality.TALLA)
	sim.people[0].set_priority(tallar, 2)
	var antes := sim.people[0].priorities.duplicate()
	sim.focus_on_rut()
	sim.day += SettlementSim.DIAS_DE_BERREA
	sim._acabar_la_berrea()
	assert_eq(sim.people[0].priorities, antes, "las prioridades de antes, tal cual")


func test_ese_mes_es_el_mes_del_calendario() -> void:
	# No es una cifra aparte: la spec dice «ese mes».
	assert_eq(SettlementSim.DIAS_DE_BERREA, Subsistence.DAYS_PER_MONTH,
		"la berrea dura un mes del juego")


func test_la_tarjeta_de_la_berrea_dice_lo_que_cuesta() -> void:
	var sim := _banda()
	var caja := {"m": null}
	sim.moment_raised.connect(func(m: Moment) -> void: caja["m"] = m)
	sim._offer_rut_choice()
	var tarjeta := caja["m"] as Moment
	assert_true(tarjeta != null, "sale la tarjeta de la berrea")
	if tarjeta == null:
		return
	assert_true(tarjeta.la_eleccion_importa(), "volcarse o no cambia cifras")
	assert_near(float((tarjeta.options[0]["cuesta"] as Dictionary).get("jornadas", 0)), 0.0, 0.001,
		"la primera opción, seguir, no compromete a nada")
	assert_eq(int((tarjeta.options[1]["cuesta"] as Dictionary).get("jornadas", 0)),
		2 * SettlementSim.DIAS_DE_BERREA,
		"dos cazadores por un mes: treinta jornadas que no se recogen")


# ------------------------------------ D2: una decisión fija por estación --

## Las tarjetas que salen al entrar en esa estación, desde la anterior.
func _tarjetas_al_entrar_en(sim: SettlementSim, estacion: Subsistence.Season) -> Array:
	var season_antes := GameState.season
	var year_antes := GameState.year
	GameState.season = ((estacion + 3) % 4) as Subsistence.Season
	var salidas := []
	sim.moment_raised.connect(func(m: Moment) -> void: salidas.append(m))
	sim._advance_local_season()
	GameState.season = season_antes
	GameState.year = year_antes
	return salidas


func _de_tipo(tarjetas: Array, kind: Moment.Kind) -> Moment:
	for m: Moment in tarjetas:
		if m.kind == kind:
			return m
	return null


## Una banda sobre cumbres de mentira, con comarca y alguien que sabe subir.
func _banda_completa() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._terrain = PeakTerrain.new()
	sim.home_position = Vector3(300.0, 0.0, 300.0)
	sim.home_position.y = sim._terrain.get_height_at(sim.home_position)
	sim.parajes = Parajes.new()
	var subir := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	for i in range(4):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "P%d" % i
		p.age_group = Inhabitant.Age.ADULTO
		p.age_years = 30
		p.skill[subir] = 0.9
		sim.people.append(p)
	sim.store.add(Materia.Kind.CARNE_SECA, 400.0)
	var comarca := SiteSet.new()
	for i in range(4):
		var s := Site.new()
		s.id = 2000 + i
		s.lon = float(i) * 0.1
		s.inside_region = true
		# Con abrigo y por encima del mar: en el Paleolítico sólo cuenta como
		# sitio al que ir el que tiene abrigo —`Site.is_usable_in`—, que es por
		# qué de los 869 emplazamientos son 72.
		s.has_shelter = true
		s.elevation = 50.0
		comarca.sites.append(s)
	sim.expedicion.sitios = comarca
	return sim


func test_en_otono_sale_la_berrea() -> void:
	var sim := _banda()
	assert_true(_de_tipo(_tarjetas_al_entrar_en(sim, Subsistence.Season.OTONO),
		Moment.Kind.BERREA) != null, "otoño: la berrea")


func test_en_invierno_sale_la_del_fuego() -> void:
	var sim := _banda()
	var m := _de_tipo(_tarjetas_al_entrar_en(sim, Subsistence.Season.INVIERNO),
		Moment.Kind.INVIERNO)
	assert_true(m != null, "invierno: ¿cuánto fuego?")
	if m != null:
		assert_true(m.la_eleccion_importa(), "y elegir cambia cifras")


func test_en_verano_sale_la_de_las_cumbres() -> void:
	var sim := _banda_completa()
	var m := _de_tipo(_tarjetas_al_entrar_en(sim, Subsistence.Season.VERANO),
		Moment.Kind.ASCENSO)
	assert_true(m != null, "verano: ¿se sube ahora que no hiela?")
	if m != null:
		assert_true(m.la_eleccion_importa(), "y elegir cambia cifras")


func test_en_primavera_sale_la_de_la_expedicion() -> void:
	var sim := _banda_completa()
	var m := _de_tipo(_tarjetas_al_entrar_en(sim, Subsistence.Season.PRIMAVERA),
		Moment.Kind.EXPEDICION)
	assert_true(m != null, "primavera: ¿se sale del valle?")
	if m != null:
		assert_true(m.la_eleccion_importa(), "y elegir cambia cifras")


func test_en_un_ano_salen_las_cuatro() -> void:
	# EL CRITERIO LITERAL DEL FRENTE 8: al menos cuatro al año que no se pueden
	# evitar, una por estación.
	var sim := _banda_completa()
	var tipos := {}
	for estacion in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		for m: Moment in _tarjetas_al_entrar_en(sim, estacion):
			if m.la_eleccion_importa():
				tipos[m.kind] = true
	for kind in [Moment.Kind.EXPEDICION, Moment.Kind.ASCENSO, Moment.Kind.BERREA,
			Moment.Kind.INVIERNO]:
		assert_true(tipos.has(kind), "la de %s sale en el año" % Moment.Kind.keys()[kind])


func test_mandar_la_expedicion_desde_la_tarjeta_la_manda() -> void:
	# EL BOTÓN QUE LA EXPEDICIÓN NO TENÍA: hasta ahora sólo se mandaba desde
	# código.
	var sim := _banda_completa()
	var m := _de_tipo(_tarjetas_al_entrar_en(sim, Subsistence.Season.PRIMAVERA),
		Moment.Kind.EXPEDICION)
	assert_true(m != null, "sale la tarjeta")
	if m == null:
		return
	(m.options[1]["on_pick"] as Callable).call()
	assert_true(sim.expedicion.en_marcha(), "y elegir «mandarla» la manda")


func test_la_primera_opcion_de_cada_estacion_no_compromete() -> void:
	# Contrato de SPECS §4.6: las sondas eligen la opción 0.
	var sim := _banda_completa()
	for estacion in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		for m: Moment in _tarjetas_al_entrar_en(sim, estacion):
			if not m.is_decision():
				continue
			assert_true((m.options[0].get("cuesta", {}) as Dictionary).is_empty(),
				"la opción 0 de %s no cuesta nada" % Moment.Kind.keys()[m.kind])


# ------------------------------------- el fuego racionado, que cueste --

func test_racionado_calienta_una_noche_si_y_otra_no() -> void:
	var sim := _banda()
	sim.hearth_lit = true
	sim.hogar.racionado = true
	sim.day = 10
	var par := sim.hogar.calienta_esta_noche()
	sim.day = 11
	var impar := sim.hogar.calienta_esta_noche()
	assert_true(par, "una noche, fuego")
	assert_false(impar, "la otra, no: por eso cuesta")


func test_a_manos_llenas_calienta_todas_las_noches() -> void:
	var sim := _banda()
	sim.hearth_lit = true
	for dia in [10, 11, 12, 13]:
		sim.day = dia
		assert_true(sim.hogar.calienta_esta_noche(), "fuego cada noche")


func test_sin_hogar_prendido_no_calienta_ni_racionado_ni_no() -> void:
	var sim := _banda()
	sim.hearth_lit = false
	sim.day = 10
	assert_false(sim.hogar.calienta_esta_noche(), "apagado no calienta")


func test_el_racionamiento_se_acaba_con_el_invierno() -> void:
	var sim := _banda()
	sim.hogar.racionado = true
	_tarjetas_al_entrar_en(sim, Subsistence.Season.PRIMAVERA)
	assert_false(sim.hogar.racionado, "en primavera se vuelve al fuego de siempre")



func test_al_empezar_la_partida_sale_la_decision_de_primavera() -> void:
	# LO QUE DESTAPÓ LA PRUEBA DE HUMO. La partida empieza ya en primavera, y
	# las decisiones de estación saltan al CAMBIAR de estación: la del primer
	# año no salía, y la primera expedición esperaba al año 2.
	var sim := _banda_completa()
	var season_antes := GameState.season
	GameState.season = Subsistence.Season.PRIMAVERA
	var salidas := []
	sim.moment_raised.connect(func(m: Moment) -> void: salidas.append(m))
	sim.iniciar_partida()
	GameState.season = season_antes
	assert_true(_de_tipo(salidas, Moment.Kind.EXPEDICION) != null,
		"en la primera primavera ya se puede mandar la expedición")
