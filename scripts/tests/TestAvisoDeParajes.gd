class_name TestAvisoDeParajes
extends TestCase
## El aviso de paraje se puede apagar, y apaga LA TARJETA y nada más. INTERFAZ §8.9.
##
## Lo que se fija aquí es la diferencia entre «callar la tarjeta» y «callar el hallazgo»:
## con el aviso apagado la Crónica tiene que salir **idéntica**. Sin esa comprobación la
## implementación puede cortar por donde no es —dejar de bautizar el paraje, o no
## escribirlo en la Crónica— y el resultado se vería igual de silencioso.


func suite_name() -> String:
	return "Aviso de parajes"


func _al_empezar() -> void:
	Configuracion.aviso_de_parajes = true


## Una banda mínima con un paraje recién bautizado esperando a que se cuente.
##
## **Se construye el estado, no se simula**: bautizar un paraje de verdad pide una batida
## de varias jornadas, y lo que se comprueba aquí es qué pasa DESPUÉS de bautizarlo.
func _con_un_paraje_recien_puesto() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.game_seed = 7
	sim.home_position = Vector3(100.0, 0.0, 100.0)
	var paraje := Paraje.new()
	paraje.position = Vector3(160.0, 0.0, 140.0)
	paraje.cell_x = 4
	paraje.cell_z = 3
	paraje.activity = int(Subsistence.Activity.RECOLECCION)
	paraje.name_text = "el avellanar de prueba"
	sim.parajes.just_found.append(paraje)
	return sim


## Cuenta las tarjetas que la simulación levanta al contar lo recién bautizado.
func _tarjetas_al_contar(sim: SettlementSim) -> Array[Moment]:
	var salieron: Array[Moment] = []
	sim.moment_raised.connect(func(m: Moment) -> void: salieron.append(m))
	sim.reconocimiento._contar_los_nuevos()
	return salieron


## ENCENDIDO, UNA TARJETA POR PARAJE. APAGADO, NINGUNA. Y la Crónica, idéntica.
func test_apagado_no_sale_la_tarjeta_pero_la_cronica_no_se_entera() -> void:
	# La simulación levanta el momento pase lo que pase: el ajuste es de la vista, y eso
	# es lo que hace que no pueda llevarse por delante los otros canales.
	var con := _con_un_paraje_recien_puesto()
	var de_con := _tarjetas_al_contar(con)
	assert_eq(de_con.size(), 1, "un paraje bautizado, un momento")
	assert_eq(int(de_con[0].kind), int(Moment.Kind.HALLAZGO), "y es de hallazgo")
	var cronica_con := con.chronicle.entries.size()

	var sin := _con_un_paraje_recien_puesto()
	var de_sin := _tarjetas_al_contar(sin)

	# Y LA VISTA es quien decide si esa tarjeta se enseña.
	Configuracion.aviso_de_parajes = false
	assert_false(BarraSuperior._sale_la_tarjeta(de_sin[0]),
		"con el aviso apagado, la tarjeta de paraje no se enseña")
	Configuracion.aviso_de_parajes = true
	assert_true(BarraSuperior._sale_la_tarjeta(de_con[0]),
		"con el aviso encendido, sí")

	# LO QUE NO CAMBIA: la Crónica sale igual en los dos casos, porque el ajuste no la
	# toca. Es el criterio que distingue callar la tarjeta de callar el hallazgo.
	assert_eq(sin.chronicle.entries.size(), cronica_con,
		"la Crónica gana su línea de Hallazgos en los dos casos")
	assert_true(cronica_con > 0, "y esa línea existe de verdad (%d)" % cronica_con)
	var texto := String(sin.chronicle.entries[cronica_con - 1].get("text", ""))
	assert_true(texto.contains("el avellanar de prueba"),
		"con el nombre del sitio: %s" % texto)
	con.free()
	sin.free()


## EL RESTO DE TARJETAS SIGUE SALIENDO con el aviso de parajes apagado. Una por clase.
##
## Las decisiones **no se pueden apagar** ni por accidente: paran el reloj y piden
## respuesta, así que si se tragaran la partida no avanzaría.
func test_apagar_el_aviso_no_calla_a_las_demas() -> void:
	Configuracion.aviso_de_parajes = false
	for cual: Moment.Kind in [Moment.Kind.CUMBRE, Moment.Kind.PERCANCE, Moment.Kind.BERREA,
			Moment.Kind.RELATO, Moment.Kind.CUEVA, Moment.Kind.INICIO,
			Moment.Kind.ASCENSO, Moment.Kind.INVIERNO, Moment.Kind.VICTORIA,
			Moment.Kind.DERROTA]:
		var moment := Moment.new()
		moment.kind = cual
		assert_true(BarraSuperior._sale_la_tarjeta(moment),
			"la tarjeta de clase %d sigue saliendo" % int(cual))


## LA CUMBRE SIGUE CONTANDO LOS SUYOS. Su tarjeta sale de `Moment.found()` pero se pone
## `CUMBRE`, así que el «se han descubierto N parajes» no lo toca este ajuste: ese aviso
## es de la cumbre, no del paraje, y ya es uno solo.
func test_la_cumbre_sigue_diciendo_cuantos_parajes() -> void:
	Configuracion.aviso_de_parajes = false
	var cumbre := Moment.summit("Una cumbre coronada",
		"Se han descubierto 4 parajes: el uno, el dos, el tres y el cuatro.",
		Vector3.ZERO, null)
	assert_eq(int(cumbre.kind), int(Moment.Kind.CUMBRE), "la cumbre no es un hallazgo")
	assert_true(BarraSuperior._sale_la_tarjeta(cumbre), "y su tarjeta sale igual")
	assert_true(cumbre.text.contains("parajes"), "contando los suyos")


## LA COLA SE VACÍA AL APAGARLO: apagar el aviso y aun así tragarse seis carteles sería el
## mismo problema con un paso más. Se van las que esperan turno; la que está en pantalla ya
## se ha leído.
func test_al_apagarlo_se_van_las_que_esperaban() -> void:
	var ui := GameUI.new()
	for i in range(3):
		var paraje := Moment.new()
		paraje.kind = Moment.Kind.HALLAZGO
		paraje.title = "Un sitio con nombre %d" % i
		ui._moments.append(paraje)
	var percance := Moment.new()
	percance.kind = Moment.Kind.PERCANCE
	percance.title = "Un percance"
	ui._moments.append(percance)
	assert_eq(ui._moments.size(), 4, "tres de paraje y una de percance")

	Configuracion.aviso_de_parajes = false
	ui.aplicar_configuracion()
	assert_eq(ui._moments.size(), 1, "se van las de paraje")
	assert_eq(int(ui._moments[0].kind), int(Moment.Kind.PERCANCE), "y queda la de percance")

	# Y ENCENDIDO NO SE TOCA NADA: volver a encenderlo no puede tirar lo que espera.
	Configuracion.aviso_de_parajes = true
	ui._moments.append(percance)
	ui.aplicar_configuracion()
	assert_eq(ui._moments.size(), 2, "con el aviso encendido la cola se queda como está")
	ui.free()
