class_name TestIntercambio
extends TestCase
## El trueque: se decide, se paga, y la otra gente recuerda cómo la trataste.
##
## **Reescrita el 2026-09-12**, y dos de sus pruebas de antes afirmaban justo lo
## que la tanda 2 invierte: «se intenta un trueque por cada cambio de estación»
## y «llega sílex al pasar ocho estaciones». Las dos describían un envío que
## ocurría solo, sin que el jugador decidiera nada. Ahora el trueque **se
## propone** y no pasa nada hasta que alguien elige. Ver EPOCA_01 §10.1, tanda
## 2, frente 6.
##
## La tirada no se fuerza desde fuera: se repite muchas veces, como ya hacía la
## versión anterior y como hace `TestMishap`.


func suite_name() -> String:
	return "Intercambio"


const CON := 7


## Una banda con adultos en casa, despensa de sobra, y alguien conocido.
func _sim(semilla: int = 20260912) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._rng.seed = semilla
	for i in range(6):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "Persona%d" % i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	sim.contacto.ocupados[CON] = true
	sim.contacto.conocerse(CON)
	sim.day = 10
	return sim


func _llenar(sim: SettlementSim) -> void:
	for kind in [Materia.Kind.FRUTO_SECO, Materia.Kind.CARNE_SECA, Materia.Kind.PIEL]:
		sim.store.add(kind, 60.0)


## Trata hasta que salga bien, adelantando el día para que quien fue vuelva.
## Devuelve si llegó a salir bien en los intentos dados.
func _hasta_que_salga(sim: SettlementSim, ofrece: Materia.Kind,
		como: Intercambio.Como, pide: Intercambio.Pide) -> bool:
	for i in range(60):
		_llenar(sim)
		sim.day += Intercambio.JORNADAS_DE_TRUEQUE
		if sim.intercambio.tratar(CON, ofrece, como, pide):
			return true
	return false


# -------------------------------------------- T1: ya no ocurre solo --

func test_el_trueque_no_ocurre_solo() -> void:
	# EL PRIMER CRITERIO DEL FRENTE: sin que nadie decida nada, cero
	# intercambios. Ocho estaciones con gente conocida y despensa llena, y
	# nadie contesta la tarjeta.
	var season_antes := GameState.season
	var year_antes := GameState.year
	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, 200.0)
	for i in range(8):
		sim._advance_local_season()
	GameState.season = season_antes
	GameState.year = year_antes

	assert_eq(sim.intercambio.consumados, 0, "ni un solo trato consumado")
	assert_eq(sim.intercambio.intentados, 0, "ni siquiera intentado")
	assert_near(sim.store.amount(Materia.Kind.SILEX), 0.0, 0.001, "y no llega sílex")


func test_se_propone_una_vez_por_estacion() -> void:
	var season_antes := GameState.season
	var year_antes := GameState.year
	var sim := _sim()
	# UN ARRAY Y NO UN ENTERO: las lambdas de GDScript capturan las variables
	# locales POR VALOR. Con un entero, la tarjeta salía y el contador de
	# fuera se quedaba en cero.
	var propuestos := [0]
	sim.moment_raised.connect(func(m: Moment) -> void:
		if m.kind == Moment.Kind.TRUEQUE:
			propuestos[0] += 1)
	for i in range(4):
		sim._advance_local_season()
	GameState.season = season_antes
	GameState.year = year_antes
	assert_eq(propuestos[0], 4, "una tarjeta de trueque por estación")


func test_sin_conocer_a_nadie_no_se_propone_nada() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	var propuestos := [0]
	sim.moment_raised.connect(func(_m: Moment) -> void: propuestos[0] += 1)
	sim.intercambio.proponer_el_trato()
	assert_eq(propuestos[0], 0, "sin contacto no hay «con quién»")

	# Y EL CONTROL, sin el que el cero de arriba no significa nada: esta prueba
	# pasó en vacío en su primera versión, porque contaba con un entero que la
	# lambda capturaba por valor y valía cero se propusiera o no.
	var con_gente := _sim()
	var si := [0]
	con_gente.moment_raised.connect(func(_m: Moment) -> void: si[0] += 1)
	con_gente.intercambio.proponer_el_trato()
	assert_eq(si[0], 1, "y con alguien conocido, sí")


func test_la_primera_opcion_es_no_ir_y_no_cuesta_nada() -> void:
	# Por dos motivos, y los dos dichos en `Intercambio.proponer_el_trato`: no decidir no
	# puede costar nada, y las sondas contestan con la primera opción.
	var sim := _sim()
	_llenar(sim)
	var caja := {"tarjeta": null}
	sim.moment_raised.connect(func(m: Moment) -> void: caja["tarjeta"] = m)
	sim.intercambio.proponer_el_trato()
	var tarjeta := caja["tarjeta"] as Moment
	assert_true(tarjeta != null and tarjeta.is_decision(), "se propone una decisión")
	if tarjeta == null:
		return
	var fruto := sim.store.amount(Materia.Kind.FRUTO_SECO)
	(tarjeta.options[0]["on_pick"] as Callable).call()
	assert_near(sim.store.amount(Materia.Kind.FRUTO_SECO), fruto, 0.001,
		"no ir no se lleva nada")
	assert_eq(sim.intercambio.intentados, 0, "ni cuenta como intento")


func test_cada_opcion_dice_lo_que_cuesta() -> void:
	# Lo pide el frente 8: la consecuencia escrita ANTES de elegir.
	var sim := _sim()
	var caja := {"tarjeta": null}
	sim.moment_raised.connect(func(m: Moment) -> void: caja["tarjeta"] = m)
	sim.intercambio.proponer_el_trato()
	var tarjeta := caja["tarjeta"] as Moment
	assert_true(tarjeta != null, "sale la tarjeta, o las de abajo no prueban nada")
	if tarjeta == null:
		return
	for opcion: Dictionary in tarjeta.options:
		assert_false(String(opcion.get("hint", "")).is_empty(),
			"«%s» dice lo que cuesta" % opcion["label"])


# ---------------------------------- T2: la otra gente recuerda --

func test_ser_generoso_sube_la_tasa_y_regatear_la_baja() -> void:
	# EL SEGUNDO CRITERIO: el 55 % fijo deja de ser fijo. Misma semilla, dos
	# maneras de tratar, trescientos intentos cada una, y cada intento
	# comprueba que el almacén se mueve como toca.
	var tasas := {}
	for como in [Intercambio.Como.GENEROSO, Intercambio.Como.REGATEAR]:
		var sim := _sim()
		var bien := 0
		for i in range(300):
			_llenar(sim)
			sim.day += Intercambio.JORNADAS_DE_TRUEQUE
			var silex_antes := sim.store.amount(Materia.Kind.SILEX)
			var ok := sim.intercambio.tratar(CON, Materia.Kind.FRUTO_SECO, como,
				Intercambio.Pide.SILEX)
			if ok:
				bien += 1
				assert_gt(sim.store.amount(Materia.Kind.SILEX), silex_antes,
					"si sale bien, llega sílex")
			else:
				assert_near(sim.store.amount(Materia.Kind.SILEX), silex_antes, 0.001,
					"si sale mal, no llega nada")
		tasas[como] = float(bien) / 300.0

	assert_gt(float(tasas[Intercambio.Como.GENEROSO]),
		float(tasas[Intercambio.Como.REGATEAR]),
		"la generosidad se recuerda mejor que el regateo")


func test_el_trato_se_mueve_aunque_salga_mal() -> void:
	# Si regateas y no tienen nada que darte, se acuerdan igual de que
	# regateaste.
	var sim := _sim()
	_llenar(sim)
	var antes := sim.contacto.trato_con(CON)
	sim.intercambio.tratar(CON, Materia.Kind.FRUTO_SECO, Intercambio.Como.REGATEAR,
		Intercambio.Pide.SILEX)
	assert_lt(sim.contacto.trato_con(CON), antes,
		"el regateo baja el trato, salga como salga")


func test_con_quien_se_trata_es_con_quien_mejor_os_lleva() -> void:
	var sim := _sim()
	sim.contacto.ocupados[3] = true
	sim.contacto.conocerse(3)
	sim.contacto.mover_el_trato(3, 40.0)
	assert_eq(sim.intercambio.con_quien(), 3, "la memoria decide con quién")


func test_con_quien_no_depende_del_orden_de_un_diccionario() -> void:
	# A igualdad de trato, el de id más bajo: si no, dos corridas de la misma
	# semilla podrían ir a tratar con gente distinta.
	var sim := _sim()
	sim.contacto.ocupados[2] = true
	sim.contacto.conocerse(2)
	assert_eq(sim.intercambio.con_quien(), 2, "a igualdad, el id más bajo")


# ------------------------------ T3: qué se ofrece, y que duela --

func test_desprenderse_duele() -> void:
	# EL TERCER CRITERIO: lo que se da sale de la despensa y no vuelve. Antes de
	# cada intento la carne vuelve a 60, así que en el que sale bien se ve
	# exactamente lo que se fue.
	var sim := _sim()
	var se_fue := -1.0
	for i in range(60):
		sim.day += Intercambio.JORNADAS_DE_TRUEQUE
		sim.store.take(Materia.Kind.CARNE_SECA, sim.store.amount(Materia.Kind.CARNE_SECA))
		sim.store.add(Materia.Kind.CARNE_SECA, 60.0)
		if sim.intercambio.tratar(CON, Materia.Kind.CARNE_SECA,
				Intercambio.Como.GENEROSO, Intercambio.Pide.SILEX):
			se_fue = 60.0 - sim.store.amount(Materia.Kind.CARNE_SECA)
			break
	assert_gt(se_fue, 0.0, "alguna vez sale bien")
	assert_near(se_fue, Intercambio.LO_JUSTO * 1.5, 0.01,
		"siendo generosos se van nueve de carne seca que no vuelven")


func test_sin_bastante_que_ofrecer_no_se_va() -> void:
	var sim := _sim()
	var trato_antes := sim.contacto.trato_con(CON)
	assert_false(sim.intercambio.tratar(CON, Materia.Kind.PIEL,
		Intercambio.Como.JUSTO, Intercambio.Pide.SILEX), "sin piel no se va")
	var alguien_fuera := false
	for p: Inhabitant in sim.people:
		if p.esta_de_expedicion(sim.day):
			alguien_fuera = true
	assert_false(alguien_fuera, "y no sale nadie de casa")
	assert_near(sim.contacto.trato_con(CON), trato_antes, 0.001, "ni se mueve el trato")


func test_no_se_trata_con_quien_no_se_conoce() -> void:
	var sim := _sim()
	_llenar(sim)
	assert_false(sim.intercambio.tratar(99, Materia.Kind.FRUTO_SECO,
		Intercambio.Como.JUSTO, Intercambio.Pide.SILEX), "sin contacto no hay trato")


# --------------------------------------- ir cuesta jornadas --

func test_ir_cuesta_jornadas_aunque_salga_mal() -> void:
	# EL CUARTO CRITERIO: las jornadas del que va no se recolectan, y se van
	# igual si vuelve con las manos vacías.
	var sim := _sim()
	_llenar(sim)
	sim.intercambio.tratar(CON, Materia.Kind.FRUTO_SECO, Intercambio.Como.JUSTO,
		Intercambio.Pide.SILEX)
	var fuera := 0
	for p: Inhabitant in sim.people:
		if p.esta_de_expedicion(sim.day):
			fuera += 1
	assert_eq(fuera, 1, "alguien está fuera tratando")
	assert_eq(sim.intercambio.intentados, 1, "y cuenta como intento")


# ------------------------- T4: sílex, concha y gente, y los tres llegan --

func test_se_puede_pedir_silex_y_llega() -> void:
	var sim := _sim()
	assert_true(_hasta_que_salga(sim, Materia.Kind.FRUTO_SECO,
		Intercambio.Como.JUSTO, Intercambio.Pide.SILEX), "sale")
	assert_gt(sim.store.amount(Materia.Kind.SILEX), 0.0, "y llega sílex")


func test_se_puede_pedir_concha_y_llega() -> void:
	# «La concha de lejos», que hoy no tenía de dónde venir.
	var sim := _sim()
	assert_true(_hasta_que_salga(sim, Materia.Kind.CARNE_SECA,
		Intercambio.Como.JUSTO, Intercambio.Pide.CONCHA), "sale")
	assert_gt(sim.store.amount(Materia.Kind.CONCHA), 0.0, "y llega concha")


func test_se_puede_pedir_gente_y_llega() -> void:
	# Así funcionaban las redes paleolíticas: se movía gente, no sólo cosas.
	var sim := _sim()
	var antes := sim.people.size()
	assert_true(_hasta_que_salga(sim, Materia.Kind.PIEL,
		Intercambio.Como.GENEROSO, Intercambio.Pide.GENTE), "sale")
	assert_eq(sim.people.size(), antes + 1, "y viene alguien a vivir con la banda")


func test_quien_llega_no_repite_id() -> void:
	var sim := _sim()
	_hasta_que_salga(sim, Materia.Kind.PIEL, Intercambio.Como.GENEROSO,
		Intercambio.Pide.GENTE)
	var ids := {}
	var repetido := false
	for p: Inhabitant in sim.people:
		if ids.has(p.id):
			repetido = true
		ids[p.id] = true
	assert_false(repetido, "ningún id repetido: lo da `Relevo.id_libre`")


func test_llega_silex_sin_ninguna_veta_local() -> void:
	# Se conserva de la versión anterior, porque sigue siendo la razón de ser
	# del sistema: el sílex bueno no existe en Cantabria y hay que traerlo. Lo
	# que cambia es que ahora llega TRATANDO, no pasando estaciones.
	var sim := _sim()
	for pj: Paraje in sim.parajes.list:
		assert_false(pj.kind == Materia.Kind.SILEX, "no debería haber ninguna veta")
	_hasta_que_salga(sim, Materia.Kind.FRUTO_SECO, Intercambio.Como.JUSTO,
		Intercambio.Pide.SILEX)
	assert_gt(sim.store.amount(Materia.Kind.SILEX), 0.0,
		"llega sílex por trueque sin veta local ninguna")
