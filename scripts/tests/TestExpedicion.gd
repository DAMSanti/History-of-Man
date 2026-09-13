class_name TestExpedicion
extends TestCase
## La salida larga, fuera del mapa: lo que descubre y lo que cuesta.
##
## Es lo único que levanta la niebla regional —ver [TestNiebla]— y la mitad del
## frente 5 de EPOCA_01 §10.1, tanda 2. Las pruebas construyen el estado en vez
## de simular jornadas: la regla es la regla, y comprobarla no pide un año.


func suite_name() -> String:
	return "Expedicion"


var _antes_descubierto: Dictionary = {}


## `GameState` es estático: lo que se toque aquí se devuelve.
func _guardar() -> void:
	_antes_descubierto = GameState.discovered.duplicate()


func _devolver() -> void:
	GameState.discovered = _antes_descubierto


## Una banda de adultos en casa, con despensa de sobra.
func _sim(gente: int = 8, comida: float = 400.0) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, comida)
	for i in range(gente):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	sim.day = 10
	return sim


## Una comarca de mentira: cinco emplazamientos en fila, cada vez más lejos.
func _comarca() -> SiteSet:
	var conjunto := SiteSet.new()
	for i in range(6):
		var s := Site.new()
		s.id = 1000 + i
		s.lon = float(i) * 0.1
		s.lat = 0.0
		conjunto.sites.append(s)
	return conjunto


# --------------------------------------------------------- lo que cuesta --

func test_salir_saca_la_comida_de_la_despensa() -> void:
	var sim := _sim()
	var antes := sim.store.food_rations()
	assert_true(sim.expedicion.mandar(3, 1000), "sale")
	assert_lt(sim.store.food_rations(), antes, "y se lleva comida que no vuelve")


func test_se_lleva_la_comida_de_todo_el_viaje() -> void:
	# Dos raciones por persona y jornada —[Materia.KCAL_RACION] es media
	# jornada—: tres personas doce jornadas son setenta y dos raciones.
	var sim := _sim()
	var antes := sim.store.food_rations()
	sim.expedicion.mandar(3, 1000)
	assert_near(antes - sim.store.food_rations(),
		3.0 * float(Expedicion.JORNADAS_FUERA) * 2.0, 0.5,
		"las raciones de todo el viaje, en la cuenta de siempre")


func test_quien_sale_no_trabaja_mientras_esta_fuera() -> void:
	var sim := _sim()
	sim.expedicion.mandar(3, 1000)
	var fuera := 0
	for p: Inhabitant in sim.people:
		if p.esta_de_expedicion(sim.day):
			fuera += 1
	assert_eq(fuera, 3, "tres fuera del mapa")


func test_las_jornadas_persona_se_cuentan() -> void:
	# ES LA CIFRA QUE EL FRENTE PIDE CONTAR: esas jornadas no se recolectan.
	var sim := _sim()
	sim.expedicion.mandar(3, 1000)
	assert_eq(sim.expedicion.jornadas_persona, 3 * Expedicion.JORNADAS_FUERA,
		"treinta y seis jornadas-persona")


func test_la_que_vuelve_sin_nada_cuesta_igual() -> void:
	# EL CRITERIO QUE MÁS FÁCIL SERÍA SALTARSE. Una expedición a un sitio donde
	# no hay nada que descubrir se ha comido las mismas jornadas y la misma
	# comida: el coste es haber salido, no haber acertado.
	var con_mapa := _sim()
	var sin_mapa := _sim()
	con_mapa.expedicion.sitios = _comarca()
	# `sin_mapa` no tiene comarca: no puede descubrir nada.
	var antes_con := con_mapa.store.food_rations()
	var antes_sin := sin_mapa.store.food_rations()
	_guardar()
	var salio_con := con_mapa.expedicion.mandar(3, 1000)
	var salio_sin := sin_mapa.expedicion.mandar(3, 1000)
	_devolver()
	# Sin esto la prueba pasaría aunque NINGUNA saliera: cero jornadas contra
	# cero jornadas también son «iguales».
	assert_true(salio_con and salio_sin, "las dos salen de verdad")
	assert_gt(float(sin_mapa.expedicion.jornadas_persona), 0.0,
		"y la que no descubre nada también gasta jornadas")
	assert_eq(sin_mapa.expedicion.jornadas_persona,
		con_mapa.expedicion.jornadas_persona, "las mismas jornadas")
	assert_near(antes_sin - sin_mapa.store.food_rations(),
		antes_con - con_mapa.store.food_rations(), 0.01, "la misma comida")


# ------------------------------------------------------ cuándo no se sale --

func test_sin_comida_no_se_sale() -> void:
	# Salir sin comida no es una decisión difícil: es mandar a tres personas a
	# morirse. Y no se deja a nadie a medio salir.
	var sim := _sim(8, 5.0)
	assert_false(sim.expedicion.mandar(3, 1000), "no sale")
	assert_false(sim.expedicion.en_marcha(), "y no queda nadie fuera")
	assert_false(sim.expedicion.mandada_alguna_vez, "ni cuenta como mandada")
	# Y la comida que había se queda en la despensa. Hasta el 2026-09-13 se
	# sacaba lo que hubiera y DESPUÉS se veía que no llegaba: la expedición no
	# salía y las raciones desaparecían igual.
	assert_near(sim.store.amount(Materia.Kind.CARNE_SECA), 5.0, 0.001,
		"no se lleva la comida de una expedición que no sale")


func test_sola_no_se_sale() -> void:
	var sim := _sim()
	assert_false(sim.expedicion.mandar(Expedicion.MINIMO_PARA_SALIR - 1, 1000),
		"con menos del mínimo no se sale")


func test_no_hay_dos_expediciones_a_la_vez() -> void:
	var sim := _sim(10)
	assert_true(sim.expedicion.mandar(3, 1000), "sale la primera")
	assert_false(sim.expedicion.mandar(3, 1001), "la segunda espera")


func test_ni_ninos_ni_ancianos_salen_de_expedicion() -> void:
	# Doce jornadas fuera del valle son para adultos. Es una decisión, y está en
	# `Expedicion._quienes_pueden_ir`.
	var sim := _sim(0)
	for i in range(4):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.NINO if i < 2 else Inhabitant.Age.ANCIANO
		sim.people.append(p)
	assert_false(sim.expedicion.mandar(3, 1000), "sin adultos no hay expedición")


# ------------------------------------------------------------ al volver --

func test_vuelven_en_su_jornada_y_no_antes() -> void:
	var sim := _sim()
	sim.expedicion.mandar(3, 1000)
	sim.day += Expedicion.JORNADAS_FUERA - 1
	sim.expedicion.nuevo_dia()
	assert_true(sim.expedicion.en_marcha(), "la víspera siguen fuera")
	sim.day += 1
	_guardar()
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_false(sim.expedicion.en_marcha(), "y en su jornada vuelven")
	for p: Inhabitant in sim.people:
		assert_false(p.esta_de_expedicion(sim.day), "todos en casa")


func test_al_volver_levanta_la_niebla() -> void:
	# LO QUE FALTABA: nadie llamaba a `GameState.discover` desde la partida.
	var sim := _sim()
	sim.expedicion.sitios = _comarca()
	_guardar()
	var antes := GameState.discovered.size()
	sim.expedicion.mandar(3, 1000)
	sim.day += Expedicion.JORNADAS_FUERA
	sim.expedicion.nuevo_dia()
	var despues := GameState.discovered.size()
	_devolver()
	assert_eq(despues - antes, Expedicion.SE_DESCUBREN,
		"se descubren los que se ven desde allí")
	assert_eq(sim.expedicion.descubiertos, Expedicion.SE_DESCUBREN,
		"y quedan contados")


func test_lo_ya_conocido_no_se_vuelve_a_contar() -> void:
	# Importa para el cierre de la fase: «puntos regionales nuevos» no se puede
	# inflar mandando la misma expedición al mismo sitio.
	var sim := _sim()
	sim.expedicion.sitios = _comarca()
	_guardar()
	for vuelta in range(2):
		sim.expedicion.mandar(3, 1000)
		sim.day += Expedicion.JORNADAS_FUERA
		sim.expedicion.nuevo_dia()
	var total := sim.expedicion.descubiertos
	_devolver()
	assert_lt(float(total), float(Expedicion.SE_DESCUBREN * 2),
		"la segunda vuelta al mismo sitio descubre menos que la primera")


func test_mandarla_cuenta_para_cerrar_la_fase() -> void:
	var sim := _sim()
	assert_false(sim.expedicion.mandada_alguna_vez, "al principio, no")
	sim.expedicion.mandar(3, 1000)
	assert_true(sim.expedicion.mandada_alguna_vez, "en cuanto sale, sí")


# -------------------------------------------- lo que queda al volver (E4) --

func test_alcanzar_un_sitio_con_gente_deja_contacto() -> void:
	# EL PROPÓSITO DE LA EXPEDICIÓN: no busca terreno, busca gente con la que
	# tratar. Ver docs/SISTEMAS.md §4.
	var sim := _sim()
	sim.contacto.ocupados[1000] = true
	_guardar()
	sim.expedicion.mandar(3, 1000)
	sim.day += Expedicion.JORNADAS_FUERA
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_true(sim.contacto.se_conocen(1000), "se vuelve conociendo a esa gente")


func test_la_primera_expedicion_siempre_encuentra_gente() -> void:
	# Decidido por el usuario el 2026-09-13: con el sorteo a secas, dos años
	# de partida acabaron sin conocer a nadie y sin un solo trato.
	var sim := _sim()
	_guardar()
	assert_false(sim.contacto.hay_gente_en(1000), "el sitio estaba vacío")
	sim.expedicion.mandar(3, 1000)
	sim.day += Expedicion.JORNADAS_FUERA
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_true(sim.contacto.se_conocen(1000), "y aun así la primera vuelve conociendo a alguien")
	assert_eq(sim.contacto.conocidos(), 1, "a esa gente y a nadie más")


func test_un_sitio_vacio_no_deja_contacto() -> void:
	# La otra mitad, y sin ella la de arriba no prueba nada: si cualquier
	# expedición dejara contacto, «hay alguien al final» no significaría nada.
	# Desde la SEGUNDA: la primera siempre encuentra gente.
	var sim := _sim()
	_guardar()
	sim.expedicion.mandar(3, 1000)
	sim.day += Expedicion.JORNADAS_FUERA
	sim.expedicion.nuevo_dia()
	assert_eq(sim.contacto.conocidos(), 1, "la primera dejó contacto, como debe")
	assert_true(sim.expedicion.mandar(3, 1001), "sale la segunda")
	sim.day += Expedicion.JORNADAS_FUERA
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_false(sim.contacto.se_conocen(1001), "donde no vive nadie no se conoce a nadie")
	assert_eq(sim.contacto.conocidos(), 1, "y la cuenta no sube")


func test_el_contacto_sigue_ahi_una_estacion_despues() -> void:
	# EL CRITERIO LITERAL DEL FRENTE 5: «el contacto sigue ahí una estación
	# después». Es lo que el trueque va a usar, y el trueque no se hace el
	# mismo día que se vuelve.
	var sim := _sim()
	sim.contacto.ocupados[1000] = true
	_guardar()
	sim.expedicion.mandar(3, 1000)
	sim.day += Expedicion.JORNADAS_FUERA
	sim.expedicion.nuevo_dia()
	# Una estación entera de jornadas cerradas.
	for dia in range(Subsistence.DAYS_PER_SEASON):
		sim.day += 1
		sim.expedicion.nuevo_dia()
	_devolver()
	assert_true(sim.contacto.se_conocen(1000),
		"cuarenta y cinco jornadas después, os seguís conociendo")
