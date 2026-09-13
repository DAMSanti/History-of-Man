class_name TestIntercambio
extends TestCase
## El trueque: precios, la regla del 10 % y un cambio exacto.
##
## **Reescrita dos veces.** El 2026-09-12 dejó de probar un envío automático y
## pasó a probar la tarjeta de trueque de la tanda 2; el 2026-09-13 la tarjeta y
## su viaje se quitaron —el trueque es la ventana, `PanelTrueque`— y con ellos
## sus quince pruebas. Quedan las de los precios. Ver EPOCA_01 §10.1, tanda 4,
## frente 25.


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


# --- Frente 25, tanda 4: precios y la regla del 10 % -------------------------

func test_dentro_del_diez_por_ciento_se_acepta_y_fuera_no() -> void:
	var sim := _sim()
	# Con trato 0 todo vale su precio: 6 de fruto seco valen 6; 3 de sílex, 6.
	var da := {Materia.Kind.FRUTO_SECO: 6.0}
	assert_true(sim.intercambio.se_acepta(da, {Materia.Kind.SILEX: 3.0}, CON),
		"igual, se acepta")
	# 6 contra 5,5 (sílex 2,75): se separan un 8 %.
	assert_true(sim.intercambio.se_acepta(da, {Materia.Kind.SILEX: 2.75}, CON),
		"dentro del diez por ciento, también")
	# 6 contra 5 (sílex 2,5): un 17 %.
	assert_false(sim.intercambio.se_acepta(da, {Materia.Kind.SILEX: 2.5}, CON),
		"fuera, no")


func test_con_mejor_relacion_lo_mismo_compra_mas() -> void:
	var sim := _sim()
	var da := {Materia.Kind.FRUTO_SECO: 6.0}
	var antes := sim.intercambio.valor_de_lo_que_se_da(da, CON)
	assert_false(sim.intercambio.se_acepta(da, {Materia.Kind.SILEX: 5.0}, CON),
		"con trato cero, cinco de sílex no salen")
	sim.contacto.mover_el_trato(CON, 60.0)
	assert_gt(sim.intercambio.valor_de_lo_que_se_da(da, CON), antes,
		"lo de la banda vale más a sus ojos")
	# Y con eso llega a lo que antes no llegaba. Con trato 60 el factor es 1,3:
	# lo suyo 7,8, y cinco de sílex valen 10 / 1,3 = 7,7. Con trato 0 no se
	# aceptaban.
	assert_true(sim.intercambio.se_acepta(da, {Materia.Kind.SILEX: 5.0}, CON),
		"ahora seis de fruto seco compran cinco de sílex")


func test_lo_que_se_da_sale_y_lo_que_se_recibe_entra_exactamente() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, 10.0)
	var silex_antes := sim.store.amount(Materia.Kind.SILEX)
	assert_true(sim.intercambio.cambiar(CON, {Materia.Kind.FRUTO_SECO: 6.0},
		{Materia.Kind.SILEX: 3.0}), "el trato sale")
	assert_eq(sim.store.amount(Materia.Kind.FRUTO_SECO), 4.0, "salen seis")
	assert_eq(sim.store.amount(Materia.Kind.SILEX), silex_antes + 3.0, "entran tres")
	assert_eq(sim.intercambio.historial.size(), 1, "y queda apuntado")


func test_sin_lo_que_se_da_no_se_cambia() -> void:
	var sim := _sim()
	assert_false(sim.intercambio.cambiar(CON, {Materia.Kind.FRUTO_SECO: 6.0},
		{Materia.Kind.SILEX: 3.0}), "no se da lo que no se tiene")
