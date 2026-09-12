class_name TestInstantanea
extends TestCase
## Pruebas de la instantánea de la partida y de su firma.
##
## Nace de docs/specs/LO_MISMO_MAS_DEPRISA.md, tareas 2, 3 y 15: antes de
## comparar dos corridas con esto hay que saber que dos partidas iguales dan
## lo mismo y que cualquier diferencia, por pequeña, sale.


func suite_name() -> String:
	return "Instantanea"


## Las simulaciones de la prueba anterior. Son nodos: si no se liberan, se
## quedan vivos hasta el final de la tanda.
var _sims: Array[SettlementSim] = []


## Los terrenos de mentira de la prueba anterior: también son nodos.
var _terrenos: Array[Node] = []


func before_each() -> void:
	for sim: SettlementSim in _sims:
		if is_instance_valid(sim):
			sim.free()
	_sims.clear()
	for terreno: Node in _terrenos:
		if is_instance_valid(terreno):
			terreno.free()
	_terrenos.clear()


func _sim() -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var people: Array[Inhabitant] = []
	for i in range(4):
		people.append(Inhabitant.create(i, Vector3.ZERO, rng))
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	sim._rng.seed = 7
	_sims.append(sim)
	return sim


## Cuántas entradas de la tabla de objetos son de esta clase.
func _cuantos(foto: Instantanea, clase: String) -> int:
	var n := 0
	for entrada: Array in foto.objetos:
		if Instantanea.clase_de(entrada) == clase:
			n += 1
	return n


func test_la_misma_partida_da_los_mismos_bytes() -> void:
	var sim := _sim()
	var a := Instantanea.tomar(sim)
	var b := Instantanea.tomar(sim)
	assert_eq(a.errores.size(), 0,
		"una simulación montada a mano se deja tomar sin errores: %s" % str(a.errores))
	assert_true(a.bytes() == b.bytes(), "tomar dos veces lo mismo da lo mismo")


func test_tocar_a_una_persona_cambia_los_bytes() -> void:
	var sim := _sim()
	var antes := Instantanea.tomar(sim).bytes()
	sim.people[2].hunger += 0.000001
	assert_true(Instantanea.tomar(sim).bytes() != antes,
		"una millonésima de hambre en una persona ya es otra partida")


func test_una_tirada_de_azar_cambia_los_bytes() -> void:
	var sim := _sim()
	var antes := Instantanea.tomar(sim).bytes()
	sim._rng.randf()
	assert_true(Instantanea.tomar(sim).bytes() != antes,
		"una tirada de más desplaza todas las siguientes, y se tiene que ver")


func test_lo_que_se_apunta_dos_veces_se_guarda_una() -> void:
	var sim := _sim()
	sim.people.append(sim.people[0])
	var foto := Instantanea.tomar(sim)
	assert_eq(_cuantos(foto, "Inhabitant"), 4,
		"cuatro personas, aunque una esté apuntada dos veces")


func test_un_ciclo_no_revienta() -> void:
	var guion := GDScript.new()
	guion.source_code = "extends RefCounted\nvar otro\n"
	guion.reload()
	var a: RefCounted = guion.new()
	var b: RefCounted = guion.new()
	a.set("otro", b)
	b.set("otro", a)
	var sim := _sim()
	sim.limits = {"ciclo": a}
	var foto := Instantanea.tomar(sim)
	assert_eq(_cuantos(foto, "(sin guion)"), 2, "los dos del ciclo, una vez cada uno")
	assert_eq(foto.errores.size(), 0, "y sin errores")
	a.set("otro", null)


func test_un_callable_en_el_estado_es_un_error() -> void:
	var sim := _sim()
	sim.limits = {"prisa": func() -> void: pass}
	var foto := Instantanea.tomar(sim)
	assert_eq(foto.errores.size(), 1, "un error")
	assert_true(foto.errores.size() == 1 and foto.errores[0].contains("Callable")
		and foto.errores[0].contains("limits"),
		"que dice qué es y dónde está: %s" % str(foto.errores))


func test_un_nodo_no_se_recorre_por_dentro() -> void:
	var sim := _sim()
	var nodo := Node3D.new()
	sim.limits = {"nodo": nodo}
	var antes := Instantanea.tomar(sim)
	nodo.position = Vector3(5.0, 0.0, 0.0)
	var despues := Instantanea.tomar(sim)
	assert_true(antes.bytes() == despues.bytes(),
		"mover un nodo de la escena no es cambiar la partida")
	assert_eq(int(antes.ajenos.get("Node3D", 0)), 1, "y se cuenta como ajeno")
	nodo.free()


func test_los_modulos_apuntan_a_la_simulacion_por_su_papel() -> void:
	var sim := _sim()
	var foto := Instantanea.tomar(sim)
	var marcha := -1
	for i in range(foto.objetos.size()):
		if Instantanea.clase_de(foto.objetos[i]) == "Marcha":
			marcha = i
	assert_true(marcha >= 0, "la marcha está en la tabla")
	if marcha < 0:
		return
	var pares: Array = foto.objetos[marcha][1]
	var sim_de_la_marcha: Variant = null
	for i in range(0, pares.size(), 2):
		if pares[i] == "sim":
			sim_de_la_marcha = pares[i + 1]
	assert_eq(sim_de_la_marcha, [Instantanea.NODO, "sim"],
		"su `sim` es la raíz, no una copia de la simulación")


# --- La firma de la jornada ----------------------------------------------


func test_la_misma_partida_da_la_misma_firma() -> void:
	var sim := _sim()
	var a := FirmaDiaria.de(sim)
	var b := FirmaDiaria.de(sim)
	assert_eq(a.firma.length(), 64, "un SHA-256 en hexadecimal")
	assert_eq(a.firma, b.firma, "la misma partida, la misma firma")


func test_una_tirada_de_mas_cambia_la_firma_aunque_no_se_vea() -> void:
	var sim := _sim()
	var antes := FirmaDiaria.de(sim)
	sim._rng.randf()
	var despues := FirmaDiaria.de(sim)
	assert_true(antes.firma != despues.firma, "la firma lo ve")
	var sin_azar_antes := antes.resumen.duplicate()
	var sin_azar_despues := despues.resumen.duplicate()
	sin_azar_antes.erase("azar")
	sin_azar_despues.erase("azar")
	assert_eq(sin_azar_antes, sin_azar_despues,
		"y lo demás del resumen no ha cambiado todavía: por eso va el azar dentro")


func test_lo_que_es_coste_no_cambia_la_firma() -> void:
	var sim := _sim()
	var antes := FirmaDiaria.de(sim).firma
	sim.grid_build_ms = 999
	sim._pendiente = 0.5
	sim._path_nodes_this_frame = 12
	sim.time_scale = 20.0
	assert_eq(FirmaDiaria.de(sim).firma, antes,
		"lo que depende del fotograma o de la sonda no es la partida")


func test_el_resumen_trae_lo_que_pide_la_spec() -> void:
	var sim := _sim()
	var resumen := FirmaDiaria.de(sim).resumen
	for campo: String in ["gente", "ids", "raciones", "lena", "tecnicas",
			"heridos", "parajes", "cacerias", "cronica", "desenlace", "azar"]:
		assert_true(resumen.has(campo), "el resumen trae «%s»" % campo)
	assert_eq(int(resumen.get("gente", 0)), 4, "cuatro personas")


func test_el_detalle_dice_donde_esta_la_diferencia() -> void:
	var sim := _sim()
	var antes := FirmaDiaria.de(sim).detalle
	sim.people[1].hunger += 0.000001
	var despues := FirmaDiaria.de(sim).detalle
	assert_true(antes.get("Inhabitant.hunger") != despues.get("Inhabitant.hunger"),
		"el hambre de las personas ha cambiado")
	assert_eq(antes.get("Inhabitant.fatigue"), despues.get("Inhabitant.fatigue"),
		"el cansancio no")
	assert_eq(antes.get("sim.day"), despues.get("sim.day"), "ni el día")


# --- La vuelta: de bytes a la partida (tarea 15) --------------------------


## Una simulación que puede dar pasos: la de siempre, sobre la meseta de
## mentira de las pruebas de caminos.
func _sim_que_anda() -> SettlementSim:
	var sim := _sim()
	var terreno := FakeTerrain.new()
	_terrenos.append(terreno)
	sim._terrain = terreno
	sim.home_position = Vector3(700.0, 200.0, 700.0)
	for persona: Inhabitant in sim.people:
		persona.position = sim.home_position
	sim.time_scale = 20.0
	sim.hour = 7.0
	return sim


func test_tomar_volcar_y_tomar_da_lo_mismo() -> void:
	var a := _sim()
	a.people[1].hunger = 42.5
	a._rng.randf()
	a.hour = 13.25
	a.limits = {"x": 3}
	var foto := Instantanea.tomar(a)
	var b := _sim()
	var fallos := Instantanea.desde_bytes(foto.bytes()).volcar(b)
	assert_eq(fallos.size(), 0, "entra todo: %s" % str(fallos))
	assert_true(Instantanea.tomar(b).bytes() == foto.bytes(),
		"y lo que queda en la simulación nueva es lo que se guardó")


func test_tras_volcar_la_partida_sigue_igual() -> void:
	var a := _sim_que_anda()
	for i in range(5):
		a._advance(SettlementSim.PASO_FIJO)
	var foto := Instantanea.tomar(a)
	var b := _sim_que_anda()
	var fallos := Instantanea.desde_bytes(foto.bytes()).volcar(b)
	assert_eq(fallos.size(), 0, "entra todo: %s" % str(fallos))
	for i in range(10):
		a._advance(SettlementSim.PASO_FIJO)
		b._advance(SettlementSim.PASO_FIJO)
	assert_eq(FirmaDiaria.de(b).firma, FirmaDiaria.de(a).firma,
		"diez pasos después, la restaurada y la original son la misma partida")


func test_un_campo_que_ya_no_existe_es_un_error() -> void:
	var foto := Instantanea.tomar(_sim())
	(foto.raices["sim"] as Array).append_array(["campo_que_no_existe", 7])
	var fallos := foto.volcar(_sim())
	var lo_dice := false
	for fallo: String in fallos:
		if fallo.contains("campo_que_no_existe"):
			lo_dice = true
	assert_true(lo_dice,
		"un campo guardado que el código ya no tiene invalida la instantánea: %s" % str(fallos))


func test_la_linea_se_lee_de_vuelta() -> void:
	var sim := _sim()
	var huella := FirmaDiaria.de(sim)
	var leida := FirmaDiaria.desde_linea(huella.linea())
	assert_true(leida != null, "la línea se entiende")
	if leida == null:
		return
	assert_eq(leida.dia, huella.dia, "la jornada")
	assert_eq(leida.firma, huella.firma, "la firma")
	assert_eq(leida.resumen, huella.resumen, "el resumen")
	assert_eq(leida.detalle, huella.detalle, "el detalle")
