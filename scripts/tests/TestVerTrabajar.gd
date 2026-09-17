class_name TestVerTrabajar
extends TestCase
## Ver a la gente trabajar: la cámara lenta y los viajes abreviados. GRAFICOS §7.6.
##
## Lo que se juega aquí es el contrato de SPECS §3.1: **las dos cosas cambian lo que se
## ve y ninguna cambia la partida**. La cámara lenta da MENOS pasos, no pasos más cortos;
## los viajes abreviados sólo tocan la pose que recibe la multitud.

## Los nodos que crea cada prueba, para soltarlos en la siguiente.
var _nodos: Array[Node] = []


func suite_name() -> String:
	return "VerTrabajar"


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()


## Una simulación que puede dar pasos, la receta de [TestReloj].
func _sim(semilla: int) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var people: Array[Inhabitant] = []
	for i in range(4):
		people.append(Inhabitant.create(i, Vector3.ZERO, rng))
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	sim._rng.seed = semilla
	var terreno := FakeTerrain.new()
	sim._terrain = terreno
	sim.home_position = Vector3(700.0, 200.0, 700.0)
	for persona: Inhabitant in sim.people:
		persona.position = sim.home_position
	sim.hour = 7.0
	_nodos.append(sim)
	_nodos.append(terreno)
	return sim


# --- el freno: menos pasos, no pasos más cortos (tarea 1) -----------------------

func test_el_freno_da_menos_pasos_en_el_mismo_tiempo() -> void:
	# Un segundo de reloj real, repartido en cuadros de 1/60, con y sin freno.
	#
	# **Sin saltarse la noche**: con la banda ociosa las dos avanzaban cinco horas en ese
	# segundo y lo que se estaba midiendo era el salto de la noche, no los pasos.
	var suelto := _sim(11)
	var frenado := _sim(11)
	suelto.noche_acelerada = false
	frenado.noche_acelerada = false
	frenado.freno_de_la_vista = 0.05
	var dia_suelto := suelto.hour
	var dia_frenado := frenado.hour
	for i in range(60):
		suelto._process(1.0 / 60.0)
		frenado._process(1.0 / 60.0)
	var avanzo_suelto := suelto.hour - dia_suelto
	var avanzo_frenado := frenado.hour - dia_frenado
	assert_gt(avanzo_suelto, 0.0, "sin freno avanza")
	# Con un veinteavo de los pasos avanza un veinteavo de la hora. El margen es de un
	# paso: `_pendiente` deja resto, y con tan pocos pasos un resto pesa.
	assert_near(avanzo_frenado, avanzo_suelto * 0.05, avanzo_suelto * 0.08,
		"con el freno a 1/20 avanza la veinteava parte: %.5f contra %.5f" % [
			avanzo_frenado, avanzo_suelto])


func test_el_freno_no_cambia_la_partida() -> void:
	# LA PRUEBA QUE VALE. Los mismos pasos, del mismo tamaño, con y sin freno: la firma
	# tiene que ser la misma. Se dan pasos a mano y no se espera al reloj, porque diez
	# jornadas a cámara lenta de verdad serían horas.
	# UNA DETRAS DE OTRA, no intercaladas: las dos escriben en el mismo `GameState`
	# —lo descubierto, la niebla—, y alternando los pasos la segunda encontraba
	# descubierto lo que acababa de descubrir la primera. Costó dos vueltas verlo.
	var suelto := _sim(23)
	for i in range(120):
		suelto._advance(SettlementSim.PASO_FIJO)
	var sin_freno := FirmaDiaria.de(suelto).firma
	var antes := GameState.discovered.duplicate()
	GameState.discovered = {}
	var frenado := _sim(23)
	frenado.freno_de_la_vista = 0.05
	for i in range(120):
		frenado._advance(SettlementSim.PASO_FIJO)
	var con_freno := FirmaDiaria.de(frenado).firma
	GameState.discovered = antes
	assert_eq(con_freno, sin_freno, "frenar la vista no cambia la partida")


func test_el_freno_no_frena_la_noche() -> void:
	# De noche no hay a nadie mirando trabajar, así que la noche se salta igual.
	var frenado := _sim(31)
	frenado.freno_de_la_vista = 0.05
	frenado.hour = 1.0
	for persona: Inhabitant in frenado.people:
		persona.state = Inhabitant.State.DURMIENDO
	var antes := frenado.hour
	frenado._process(1.0 / 60.0)
	assert_gt(frenado.hour - antes, 0.05,
		"la noche corre igual con el freno puesto: avanzó %.3f h" % (frenado.hour - antes))


# --- la curva de la cámara lenta (tarea 2) -------------------------------------

func test_lejos_no_frena_y_cerca_frena_lo_que_dice() -> void:
	assert_near(CamaraLenta.freno(CamaraLenta.DESDE_M, 10.0), 1.0, 0.001,
		"a 60 m no se frena")
	assert_near(CamaraLenta.freno(500.0, 10.0), 1.0, 0.001, "y de lejos, tampoco")
	assert_near(CamaraLenta.freno(10.0, 10.0), CamaraLenta.LO_MAS_LENTO, 0.001,
		"en la distancia mínima, veinte veces más despacio")


func test_la_curva_no_da_saltos_ni_se_sale() -> void:
	var antes := 1.0
	for i in range(61):
		var distancia := 60.0 - float(i)
		var freno := CamaraLenta.freno(distancia, 0.0)
		assert_true(freno >= CamaraLenta.LO_MAS_LENTO - 0.001 and freno <= 1.001,
			"a %.0f m el freno está en su rango: %.3f" % [distancia, freno])
		assert_true(freno <= antes + 0.001, "y no sube al acercarse")
		antes = freno


func test_el_letrero_sale_cerca_y_se_va_lejos() -> void:
	assert_false(CamaraLenta.se_avisa(CamaraLenta.freno(120.0, 10.0)),
		"a 120 m no se avisa de nada")
	assert_true(CamaraLenta.se_avisa(CamaraLenta.freno(12.0, 10.0)),
		"pegado al suelo, sí")
	assert_true(CamaraLenta.rotulo(0.05).contains("20"),
		"y dice cuántas veces: %s" % CamaraLenta.rotulo(0.05))


# --- los viajes abreviados (tareas 5 y 6) --------------------------------------

## Alguien andando una ruta recta de `metros`, colocado a `recorrido` del principio.
func _en_ruta(sim: SettlementSim, index: int, metros: float, recorrido: float) -> Inhabitant:
	var person: Inhabitant = sim.people[index]
	var desde := Vector3(0.0, 0.0, 0.0)
	var hasta := Vector3(metros, 0.0, 0.0)
	person.route = PackedVector3Array([desde, hasta])
	person.route_step = 1
	person.position = desde.lerp(hasta, recorrido / maxf(metros, 0.001))
	return person


func _figuras(sim: SettlementSim) -> Figuras:
	var figuras := Figuras.new()
	figuras.sim = sim
	figuras.crowd = BandaCrowd.new()
	figuras.crowd.setup(sim.people.size())
	sim._bodies.clear()
	sim._headings.clear()
	for i in range(sim.people.size()):
		sim._bodies.append(figuras.crowd.add_person())
		sim._headings.append(0.0)
	_nodos.append(figuras.crowd)
	_nodos.append(figuras)
	return figuras


func test_un_viaje_corto_se_dibuja_donde_esta() -> void:
	var sim := _sim(41)
	var figuras := _figuras(sim)
	var person := _en_ruta(sim, 0, 100.0, 0.0)
	figuras.anotar(person, 0)
	figuras._cuantos_habia = sim.people.size()
	person.position = Vector3(90.0, 0.0, 0.0)
	figuras._process(1.0 / 60.0)
	assert_near(figuras.donde(0, Vector3.ZERO).distance_to(person.position), 0.0, 0.01,
		"por debajo de 150 m la figura va pegada")


func test_en_un_viaje_largo_la_figura_anda_a_paso_legible() -> void:
	var sim := _sim(43)
	var figuras := _figuras(sim)
	var person := _en_ruta(sim, 0, 2000.0, 0.0)
	figuras.anotar(person, 0)
	figuras._cuantos_habia = sim.people.size()
	# La primera vuelta sólo la coloca al principio del camino; se mira la segunda.
	figuras._process(1.0 / 60.0)
	var donde_estaba := figuras.donde(0, Vector3.ZERO)
	# La persona se va mil metros de golpe, que es lo que hace a 900 m por segundo. La
	# figura tiene que seguir andando lo suyo.
	person.position = Vector3(1000.0, 0.0, 0.0)
	figuras._process(1.0 / 60.0)
	var anduvo := figuras.donde(0, Vector3.ZERO).distance_to(donde_estaba)
	assert_true(anduvo <= Figuras.PASO_MAXIMO / 60.0 + 0.01,
		"en un cuadro anda como mucho su paso: %.3f m" % anduvo)
	assert_eq(figuras.fase_de(0), Figuras.Fase.SALIDA, "y va saliendo")


func test_cada_tramo_andado_dura_lo_que_dice_la_spec() -> void:
	# LO QUE DE VERDAD SE PROMETE. No es que la figura esté siempre cerca de la persona
	# —a 900 m/s eso es imposible: mientras la figura anda sus doce metros, la persona
	# cruza el valle—, sino que **cada tramo que se le ve andar dura como mucho
	# RETRASO_TOPE segundos**. Lo de antes, medir la distancia, daba 64 m en la sonda y
	# era medir lo que no se había prometido.
	var sim := _sim(47)
	var figuras := _figuras(sim)
	var person := _en_ruta(sim, 0, 4000.0, 0.0)
	figuras.anotar(person, 0)
	figuras._cuantos_habia = sim.people.size()
	var cuadros_de_salida := 0
	var cuadros_de_llegada := 0
	var lo_mas_que_anduvo := 0.0
	var antes := person.position
	var antes_fase := Figuras.Fase.PEGADA as int
	for paso in range(600):
		# La persona recorre los 4 km en veinte cuadros, que es lo que hace a ×1.
		person.position = Vector3(minf(float(paso) * 200.0, 4000.0), 0.0, 0.0)
		if paso >= 20:
			person.route = PackedVector3Array()
		figuras._process(1.0 / 60.0)
		var fase := figuras.fase_de(0)
		if fase == Figuras.Fase.SALIDA:
			cuadros_de_salida += 1
		elif fase == Figuras.Fase.LLEGADA:
			cuadros_de_llegada += 1
		# El cuadro en que REAPARECE no cuenta: venía de estar escondida al otro lado del
		# valle, y ese salto no lo ve nadie.
		if fase == antes_fase and (fase == Figuras.Fase.SALIDA
				or fase == Figuras.Fase.LLEGADA):
			lo_mas_que_anduvo = maxf(lo_mas_que_anduvo,
				figuras.donde(0, Vector3.ZERO).distance_to(antes))
		antes_fase = fase
		antes = figuras.donde(0, Vector3.ZERO)
	assert_true(float(cuadros_de_salida) / 60.0 <= Figuras.RETRASO_TOPE + 0.02,
		"la salida dura %.2f s" % (float(cuadros_de_salida) / 60.0))
	assert_true(float(cuadros_de_llegada) / 60.0 <= Figuras.RETRASO_TOPE + 0.02,
		"y la llegada %.2f s" % (float(cuadros_de_llegada) / 60.0))
	assert_gt(float(cuadros_de_llegada), 0.0, "y llega, que si no no se prueba nada")
	assert_true(lo_mas_que_anduvo <= Figuras.PASO_MAXIMO / 60.0 + 0.01,
		"y mientras se la ve nunca corre: %.3f m en un cuadro" % lo_mas_que_anduvo)


func test_la_marca_va_donde_esta_la_persona() -> void:
	var sim := _sim(53)
	var figuras := _figuras(sim)
	var person := _en_ruta(sim, 0, 2000.0, 1000.0)
	person.job = Profession.Job.CAZA
	figuras.anotar(person, 0)
	figuras._cuantos_habia = sim.people.size()
	# Hasta que no acaba de salir no hay marca: primero se la ve andar. Andar el tramo
	# cuesta RETRASO_TOPE segundos, o sea noventa cuadros.
	for cuadro in range(95):
		figuras._process(1.0 / 60.0)
	# Se mira lo que `Figuras` DECIDIÓ, no la malla: un `MultiMesh` no devuelve lo que se
	# le escribe sin ventana. Que se dibujan lo mira la sonda. Ver [Figuras.marcas_puestas].
	assert_eq(figuras.marcas_puestas.size(), 1, "una marca, la del que va de viaje")
	var donde: Vector3 = figuras.marcas_puestas[0]["donde"]
	assert_true(donde.distance_to(person.position) < 5.0,
		"la marca está a menos de 5 m de lo simulado: %.2f" % donde.distance_to(person.position))
	assert_eq(figuras.marcas_puestas[0]["color"],
		Figuras.COLOR_DEL_OFICIO[Profession.Job.CAZA], "y lleva el color de su oficio")


func test_en_las_puntas_no_hay_marca() -> void:
	var sim := _sim(59)
	var figuras := _figuras(sim)
	var person := _en_ruta(sim, 0, 2000.0, 4.0)
	figuras.anotar(person, 0)
	figuras._cuantos_habia = sim.people.size()
	figuras._process(1.0 / 60.0)
	assert_eq(figuras.marcas_puestas.size(), 0,
		"saliendo del sitio se le ve a él, no una marca")


func test_cada_oficio_tiene_su_color() -> void:
	for job: int in Profession.Job.values():
		assert_true(Figuras.COLOR_DEL_OFICIO.has(job),
			"%s tiene color" % Profession.job_name(job as Profession.Job))


# --- y tampoco cambian la partida (tarea 7) ------------------------------------

func test_los_viajes_abreviados_no_cambian_la_partida() -> void:
	# `Figuras` guarda estado por persona y por cuadro, que es justo lo que el invariante
	# 3 de SPECS §7 prohíbe en la simulación. Aquí se comprueba que es vista y nada más:
	# con figuras y sin ellas, los mismos pasos dan la misma firma.
	# Una detrás de otra, por lo mismo que arriba: `GameState` es de las dos. Y LAS DOS
	# CON MULTITUD: la instantánea firma `_crowd` por su clase, así que una con banda
	# dibujada y otra sin ella diferirían por eso y no por lo que se está probando.
	var sin_figuras := _sim(67)
	var sin_ellas_crowd := _figuras(sin_figuras)
	sin_figuras._crowd = sin_ellas_crowd.crowd
	for i in range(120):
		sin_figuras._advance(SettlementSim.PASO_FIJO)
	var sin_ellas := FirmaDiaria.de(sin_figuras).firma
	var antes := GameState.discovered.duplicate()
	GameState.discovered = {}
	var con_figuras := _sim(67)
	var figuras := _figuras(con_figuras)
	con_figuras.figuras = figuras
	con_figuras._crowd = figuras.crowd
	for i in range(120):
		con_figuras._advance(SettlementSim.PASO_FIJO)
		figuras._process(1.0 / 60.0)
	var con_ellas := FirmaDiaria.de(con_figuras).firma
	GameState.discovered = antes
	assert_eq(con_ellas, sin_ellas, "abreviar los viajes no cambia la partida")
