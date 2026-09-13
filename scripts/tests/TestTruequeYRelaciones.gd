class_name TestTruequeYRelaciones
extends TestCase
## Las ventanas del trueque y de las relaciones: qué enseñan.
##
## Frentes 25 y 26 de EPOCA_01 §10.1, tanda 4.

const CON := 34


func suite_name() -> String:
	return "TruequeYRelaciones"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.game_seed = 5
	sim.day = 12
	sim.contacto.ocupados[CON] = true
	sim.contacto.conocerse(CON)
	return sim


func test_la_banda_ofrece_lo_que_tiene() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, 10.0)
	sim.store.add(Materia.Kind.PIEL, 3.0)
	var lotes := PanelTrueque.lotes_de_la_banda(sim.store)
	assert_true(int(Materia.Kind.PIEL) in lotes, "lo que hay, se puede poner")
	assert_false(int(Materia.Kind.SILEX) in lotes, "lo que no hay, no sale")


func test_lo_que_se_lleva_la_banda_ya_no_lo_traen() -> void:
	var sim := _sim()
	var traen := sim.intercambio.lo_que_traen(CON)
	var material: int = traen.keys()[0]
	var cuanto := float(traen[material])
	# Lo que valga eso, en fruto seco, con trato cero.
	var pago := cuanto * Intercambio.precio(material as Materia.Kind)
	sim.store.add(Materia.Kind.FRUTO_SECO, pago)
	assert_true(sim.intercambio.cambiar(CON, {Materia.Kind.FRUTO_SECO: pago},
		{material: cuanto}), "el trato sale")
	assert_eq(float(sim.intercambio.quedan_de(CON).get(material, 0.0)), 0.0,
		"y ya no les queda de eso esta estación")
	sim.store.add(Materia.Kind.FRUTO_SECO, pago)
	assert_false(sim.intercambio.cambiar(CON, {Materia.Kind.FRUTO_SECO: pago},
		{material: cuanto}), "no se lleva dos veces lo mismo")


func test_relaciones_saca_cada_banda_conocida_y_ninguna_sin_conocer() -> void:
	var sim := _sim()
	sim.contacto.ocupados[77] = true  # con gente, pero sin conocer
	var filas := PanelRelaciones.filas(sim)
	assert_eq(filas.size(), 1, "sólo la conocida")
	assert_eq(int(filas[0]["id"]), CON, "que es ésta")


func test_tras_un_trueque_la_ventana_lo_recoge() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, 20.0)
	var traen := sim.intercambio.lo_que_traen(CON)
	var material: int = traen.keys()[0]
	var pago := Intercambio.precio(material as Materia.Kind)
	sim.intercambio.cambiar(CON, {Materia.Kind.FRUTO_SECO: pago}, {material: 1.0})
	var fila: Dictionary = PanelRelaciones.filas(sim)[0]
	assert_eq(int(fila["tratos"]), 1, "cuenta el trato")
	assert_eq(int(fila["ultimo"]), 12, "y cuándo fue")
