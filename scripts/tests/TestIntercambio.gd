class_name TestIntercambio
extends TestCase
## Pruebas del trueque con la banda vecina.
##
## La tirada de éxito no se fuerza a mano -no hay forma limpia de fijar el
## resultado de `randf()` desde fuera-: se repite muchas veces, como ya hace
## `TestMishap` con sus percances, y se comprueba que aparecen los dos
## desenlaces y que cada uno mueve el almacén como toca.


func suite_name() -> String:
	return "Intercambio"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._rng.seed = 20260912
	return sim


func test_sin_material_de_sobra_no_hay_intento() -> void:
	var sim := _sim()
	assert_false(sim.intercambio.intentar(), "sin fruto seco de sobra, no hay trato")
	assert_eq(sim.store.amount(Materia.Kind.SILEX), 0.0, "y no llega sílex")


func test_exito_y_fracaso_mueven_el_almacen_como_toca() -> void:
	var sim := _sim()
	var exitos := 0
	var fallos := 0
	for i in range(300):
		sim.store.add(Materia.Kind.FRUTO_SECO, Intercambio.SE_OFRECE_CANTIDAD)
		var fruto_antes := sim.store.amount(Materia.Kind.FRUTO_SECO)
		var silex_antes := sim.store.amount(Materia.Kind.SILEX)

		var ok := sim.intercambio.intentar()
		var ultima := sim.chronicle.entries[-1]
		if ok:
			exitos += 1
			assert_lt(sim.store.amount(Materia.Kind.FRUTO_SECO), fruto_antes,
				"el fruto seco se entrega")
			assert_gt(sim.store.amount(Materia.Kind.SILEX), silex_antes,
				"y llega sílex")
			# El PRIMER exito lleva peso alto -"la concha de lejos"-; los
			# siguientes son ya trato corriente.
			if exitos == 1:
				assert_eq(int(ultima["weight"]), 2,
					"el primer trueque logrado es un hito, no una linea mas")
			else:
				assert_eq(int(ultima["weight"]), 1,
					"los siguientes no repiten el peso del primero")
		else:
			fallos += 1
			assert_eq(sim.store.amount(Materia.Kind.SILEX), silex_antes,
				"sin éxito, no llega sílex")

	assert_true(exitos > 0, "alguna vez sale bien")
	assert_true(fallos > 0, "y alguna vez no, tal como avisa SISTEMAS_COMPARTIDOS §5")
	assert_eq(int(sim.chronicle.counts().get(Chronicle.Kind.TRUEQUE, 0)),
		exitos + fallos, "cada intento queda anotado, salga bien o mal")


# --- el enganche al ciclo de estacion ---------------------------------------

func test_se_intenta_un_trueque_por_cada_cambio_de_estacion() -> void:
	# Directo sobre `_advance_local_season`, sin simular jornadas reales: lo
	# que se prueba es que el enganche llama a `intentar()`, no el paso del
	# tiempo en si. `GameState.season`/`.year` son `static var` -globales al
	# proceso-, asi que se restauran para no filtrar estado a otras pruebas.
	var season_antes := GameState.season
	var year_antes := GameState.year

	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, Intercambio.SE_OFRECE_CANTIDAD * 20.0)
	var antes := int(sim.chronicle.counts().get(Chronicle.Kind.TRUEQUE, 0))

	for i in range(8):
		sim._advance_local_season()

	var despues := int(sim.chronicle.counts().get(Chronicle.Kind.TRUEQUE, 0))
	assert_eq(despues - antes, 8,
		"un intento por cada una de las ocho estaciones, salga bien o mal")

	GameState.season = season_antes
	GameState.year = year_antes


func test_llega_silex_sin_ninguna_veta_local() -> void:
	# El criterio central del bloque: el sílex puede entrar SIN que exista
	# ningún paraje de tipo SILEX en el mapa -aqui, literalmente, sin que
	# `Parajes` tenga ninguno: `sim.parajes.list` esta vacio de partida en un
	# `SettlementSim` a secas, y nada en esta prueba lo llena-.
	var season_antes := GameState.season
	var year_antes := GameState.year

	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, Intercambio.SE_OFRECE_CANTIDAD * 20.0)
	for pj: Paraje in sim.parajes.list:
		assert_false(pj.kind == Materia.Kind.SILEX, "no deberia haber ninguno")

	for i in range(8):
		sim._advance_local_season()

	assert_true(sim.store.amount(Materia.Kind.SILEX) > 0.0,
		"llega sílex por trueque sin veta local ninguna")
	assert_true(sim.parajes.list.is_empty(),
		"y sigue sin haber ningun paraje de materia prima en el mapa")

	GameState.season = season_antes
	GameState.year = year_antes
