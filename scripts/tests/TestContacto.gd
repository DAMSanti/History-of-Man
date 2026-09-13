class_name TestContacto
extends TestCase
## Quién hay ahí fuera, y que el contacto no se olvide.
##
## Es la capa exterior de SISTEMAS.md §4 y la dependencia dura del trueque:
## sin «con quién» no hay nada que recordar. Ver EPOCA_01 §10.1, tanda 2,
## frente 5.


func suite_name() -> String:
	return "Contacto"


func _sim(semilla: int = 42) -> SettlementSim:
	var sim := SettlementSim.new()
	sim._rng.seed = semilla
	return sim


func _unos_cuantos(cuantos: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i in range(cuantos):
		ids.append(i)
	return ids


# ------------------------------------------------- quién está ocupado --

func test_el_sorteo_sale_del_azar_de_la_partida() -> void:
	# INVARIANTE 2 DE SPECS §7. Si esto saliera de `randf()`, dos corridas de la
	# misma semilla encontrarían vecinos distintos y no se podría comparar nada
	# —ni medir el frente, ni cotejar dos firmas—.
	var una := _sim(42)
	var otra := _sim(42)
	una.contacto.repartir_la_gente(_unos_cuantos(72))
	otra.contacto.repartir_la_gente(_unos_cuantos(72))
	assert_eq(una.contacto.ocupados.size(), otra.contacto.ocupados.size(),
		"la misma semilla, la misma comarca")


func test_con_otra_semilla_la_comarca_es_otra() -> void:
	# La otra mitad: si saliera siempre lo mismo, el sorteo no sería tal.
	var una := _sim(42)
	var otra := _sim(7)
	una.contacto.repartir_la_gente(_unos_cuantos(72))
	otra.contacto.repartir_la_gente(_unos_cuantos(72))
	var iguales := true
	for id: int in una.contacto.ocupados:
		if not otra.contacto.hay_gente_en(id):
			iguales = false
			break
	assert_false(iguales and una.contacto.ocupados.size() == otra.contacto.ocupados.size(),
		"otra semilla, otros vecinos")


func test_ni_todos_ocupados_ni_ninguno() -> void:
	# Con todos ocupados la expedición es un trámite; con ninguno, una lotería
	# perdida. `Contacto.OCUPADOS` es una decisión y está dicho.
	var sim := _sim(42)
	sim.contacto.repartir_la_gente(_unos_cuantos(72))
	var cuantos := sim.contacto.ocupados.size()
	assert_gt(float(cuantos), 0.0, "hay gente en alguna parte")
	assert_lt(float(cuantos), 72.0, "pero no en todas")


func test_la_comarca_se_reparte_una_vez_y_no_cambia() -> void:
	# Salió al escribir la prueba: sin guarda, la segunda llamada volvía a
	# sortear con el `_rng` ya avanzado y daba otra comarca —19 ocupados y
	# luego 12—, o sea que la gente que habías conocido dejaba de estar donde
	# estaba. Ahora repartir dos veces no hace nada la segunda.
	var sim := _sim(42)
	sim.contacto.repartir_la_gente(_unos_cuantos(72))
	var primera := sim.contacto.ocupados.size()
	sim.contacto.repartir_la_gente(_unos_cuantos(72))
	assert_eq(sim.contacto.ocupados.size(), primera,
		"la comarca se reparte una vez y se queda como está")


# ------------------------------------------------------ conocer gente --

func test_al_empezar_no_se_conoce_a_nadie() -> void:
	var sim := _sim()
	assert_eq(sim.contacto.conocidos(), 0, "la banda empieza sola")
	assert_false(sim.contacto.se_conocen(5), "y sin tratar con nadie")


func test_conocerse_es_la_primera_vez_y_solo_la_primera() -> void:
	var sim := _sim()
	assert_true(sim.contacto.conocerse(5), "la primera vez sí")
	assert_false(sim.contacto.conocerse(5), "la segunda ya no")
	assert_eq(sim.contacto.conocidos(), 1, "y sigue siendo una sola gente")


func test_el_contacto_no_se_deshace() -> void:
	# EL CRITERIO DEL FRENTE 5: el contacto sobrevive a la expedición que lo
	# trajo, porque es lo que el trueque va a usar una estación después.
	var sim := _sim()
	sim.contacto.conocerse(5)
	sim.contacto.mover_el_trato(5, -40.0)
	assert_true(sim.contacto.se_conocen(5),
		"aunque el trato se estropee, seguís conociéndoos")


# ------------------------------------------------------------ el trato --

func test_el_trato_empieza_a_cero_y_se_mueve() -> void:
	var sim := _sim()
	sim.contacto.conocerse(5)
	assert_near(sim.contacto.trato_con(5), 0.0, 0.001, "ni bien ni mal")
	sim.contacto.mover_el_trato(5, 12.0)
	assert_near(sim.contacto.trato_con(5), 12.0, 0.001, "la generosidad suma")
	sim.contacto.mover_el_trato(5, -20.0)
	assert_near(sim.contacto.trato_con(5), -8.0, 0.001, "el regateo resta")


func test_no_se_queda_bien_con_quien_no_has_visto() -> void:
	var sim := _sim()
	sim.contacto.mover_el_trato(9, 50.0)
	assert_near(sim.contacto.trato_con(9), 0.0, 0.001,
		"sin contacto no hay trato que mover")
	assert_false(sim.contacto.se_conocen(9), "y seguís sin conoceros")


func test_el_trato_no_se_sale_de_escala() -> void:
	var sim := _sim()
	sim.contacto.conocerse(5)
	for i in range(50):
		sim.contacto.mover_el_trato(5, 20.0)
	assert_near(sim.contacto.trato_con(5), Contacto.TRATO_MEJOR, 0.001,
		"un año de generosidad no rompe la escala")
	for i in range(100):
		sim.contacto.mover_el_trato(5, -20.0)
	assert_near(sim.contacto.trato_con(5), Contacto.TRATO_PEOR, 0.001,
		"ni uno de regateo")
