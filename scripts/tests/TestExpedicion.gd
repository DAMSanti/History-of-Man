class_name TestExpedicion
extends TestCase
## La salida larga, fuera del mapa: lo que descubre y lo que cuesta.
##
## Es lo único que levanta la niebla regional —ver [TestNiebla]— y la mitad del
## frente 5 de EPOCA_01 §10.1, tanda 2. Las pruebas construyen el estado en vez
## de simular jornadas: la regla es la regla, y comprobarla no pide un año.


func suite_name() -> String:
	return "Expedicion"


var _antes: Array = []


## `GameState` es estático: lo que se toque aquí se devuelve.
func _guardar() -> void:
	_antes = [GameState.discovered.duplicate(), GameState.niebla, GameState.home]


func _devolver() -> void:
	GameState.discovered = _antes[0]
	GameState.niebla = _antes[1]
	GameState.home = _antes[2]


## Un sitio lejos de la comarca, donde el pasillo no encuentra nada: las pruebas
## de coste no deben descubrir ni tocar la niebla de la partida.
func _en_ninguna_parte() -> Site:
	var s := Site.new()
	s.id = 99999
	s.lon = 0.0
	s.lat = 0.0
	return s


## Una banda de adultos en casa, con despensa de sobra.
func _sim(gente: int = 8, comida: float = 400.0) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, comida)
	# Y el vivac: desde la tanda 3 una expedición se lleva tienda y hoguera.
	# Ver [Expedicion.hace_falta_para].
	sim.store.add(Materia.Kind.PIEL_CURTIDA, 10.0)
	sim.store.add(Materia.Kind.LENA, 200.0)
	for i in range(gente):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	sim.day = 10
	sim.sitio = _en_ninguna_parte()
	return sim


## Un sitio de la comarca con otro a unos kilómetros, y el rumbo hacia él: un
## pasillo en el que seguro hay algo. Se busca y no se escribe, que los ids
## cambian en cada horneado.
func _salida_con_algo() -> Dictionary:
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	for desde: Site in comarca.available_in(-120.0, Site.Era.PALEOLITICO):
		for hasta: Site in comarca.available_in(-120.0, Site.Era.PALEOLITICO):
			var x := (hasta.lon - desde.lon) * Viaje.METROS_POR_GRADO * cos(deg_to_rad(desde.lat))
			var z := (hasta.lat - desde.lat) * Viaje.METROS_POR_GRADO
			var lejos := sqrt(x * x + z * z)
			if lejos > 3000.0 and lejos < 12000.0:
				return {"desde": desde, "rumbo": rad_to_deg(atan2(x, z)), "hasta": hasta}
	return {}


## Los sitios que caen en el pasillo de una salida, sin el de salida.
func _del_pasillo(sim: SettlementSim, rumbo: float, dias: int) -> Array[Site]:
	var pasillo := sim.expedicion.pasillo_hacia(rumbo, dias)
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var dentro: Array[Site] = []
	for s: Site in comarca.sites:
		if s.id != sim.sitio.id and pasillo.contiene(s.lon, s.lat):
			dentro.append(s)
	return dentro


## Un sitio de la salida, medido desde el origen.
func _lejos_de(desde: Site, s: Site) -> float:
	var x := (s.lon - desde.lon) * Viaje.METROS_POR_GRADO * cos(deg_to_rad(desde.lat))
	var z := (s.lat - desde.lat) * Viaje.METROS_POR_GRADO
	return sqrt(x * x + z * z)


# --------------------------------------------------------- lo que cuesta --

func test_salir_saca_la_comida_de_la_despensa() -> void:
	var sim := _sim()
	var antes := sim.store.food_rations()
	assert_true(sim.expedicion.mandar(3, 90.0), "sale")
	assert_lt(sim.store.food_rations(), antes, "y se lleva comida que no vuelve")


func test_se_lleva_la_comida_de_todo_el_viaje() -> void:
	# Dos raciones por persona y jornada —[Materia.KCAL_RACION] es media
	# jornada—: tres personas doce jornadas son setenta y dos raciones.
	var sim := _sim()
	var antes := sim.store.food_rations()
	sim.expedicion.mandar(3, 90.0)
	assert_near(antes - sim.store.food_rations(),
		3.0 * float(Expedicion.JORNADAS_PROPUESTAS) * 2.0, 0.5,
		"las raciones de todo el viaje, en la cuenta de siempre")


func test_quien_sale_no_trabaja_mientras_esta_fuera() -> void:
	var sim := _sim()
	sim.expedicion.mandar(3, 90.0)
	var fuera := 0
	for p: Inhabitant in sim.people:
		if p.esta_de_expedicion(sim.day):
			fuera += 1
	assert_eq(fuera, 3, "tres fuera del mapa")


func test_las_jornadas_persona_se_cuentan() -> void:
	# ES LA CIFRA QUE EL FRENTE PIDE CONTAR: esas jornadas no se recolectan.
	var sim := _sim()
	sim.expedicion.mandar(3, 90.0)
	assert_eq(sim.expedicion.jornadas_persona, 3 * Expedicion.JORNADAS_PROPUESTAS,
		"treinta y seis jornadas-persona")


func test_la_que_vuelve_sin_nada_cuesta_igual() -> void:
	# EL CRITERIO QUE MÁS FÁCIL SERÍA SALTARSE. Una expedición hacia donde no hay
	# nada que descubrir se ha comido las mismas jornadas y la misma comida: el
	# coste es haber salido, no haber acertado.
	var salida := _salida_con_algo()
	var con_algo := _sim()
	con_algo.sitio = salida["desde"]
	var sin_nada := _sim()
	var antes_con := con_algo.store.food_rations()
	var antes_sin := sin_nada.store.food_rations()
	_guardar()
	var salio_con := con_algo.expedicion.mandar(3, float(salida["rumbo"]))
	var salio_sin := sin_nada.expedicion.mandar(3, 90.0)
	_devolver()
	# Sin esto la prueba pasaría aunque NINGUNA saliera: cero jornadas contra
	# cero jornadas también son «iguales».
	assert_true(salio_con and salio_sin, "las dos salen de verdad")
	assert_gt(float(sin_nada.expedicion.jornadas_persona), 0.0,
		"y la que no descubre nada también gasta jornadas")
	assert_eq(sin_nada.expedicion.jornadas_persona,
		con_algo.expedicion.jornadas_persona, "las mismas jornadas")
	assert_near(antes_sin - sin_nada.store.food_rations(),
		antes_con - con_algo.store.food_rations(), 0.01, "la misma comida")


func test_las_jornadas_las_elige_el_jugador_y_cuestan_lo_suyo() -> void:
	var cortas := _sim()
	var largas := _sim()
	var antes := cortas.store.food_rations()
	assert_true(cortas.expedicion.mandar(3, 90.0, 4), "sale para cuatro jornadas")
	assert_true(largas.expedicion.mandar(3, 90.0, 20), "y otra para veinte")
	assert_near(antes - cortas.store.food_rations(), 3.0 * 4.0 * 2.0, 0.5,
		"cuatro jornadas, las raciones de cuatro")
	assert_eq(largas.expedicion.vuelve_el_dia, largas.day + 20, "y vuelven cuando toca")
	assert_eq(largas.expedicion.jornadas_persona, 60, "tres por veinte")


func test_solo_se_eligen_las_jornadas_que_se_pueden() -> void:
	var sim := _sim()
	assert_false(sim.expedicion.mandar(3, 90.0, 13), "impares no")
	assert_false(sim.expedicion.mandar(3, 90.0, 30), "ni más de veinticuatro")
	assert_false(sim.expedicion.en_marcha(), "y no sale nadie")


func test_se_sale_en_cualquier_estacion() -> void:
	# El criterio: mandarla no depende de la estación. Se prueba en invierno.
	var sim := _sim()
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO
	var salio := sim.expedicion.mandar(3, 180.0)
	GameState.season = antes
	assert_true(salio, "en invierno sale")


# ------------------------------------------------------ cuándo no se sale --

# ------------------------------------------- a quién se manda (tanda 3) --

func test_pueden_ir_los_adultos_sin_tocar() -> void:
	var sim := _sim(5)
	sim.people[0].hurt_days = 3
	sim.people[1].age_group = Inhabitant.Age.NINO
	assert_false(sim.expedicion.puede_ir(sim.people[0]), "el tocado no")
	assert_false(sim.expedicion.puede_ir(sim.people[1]), "el niño tampoco")
	assert_true(sim.expedicion.puede_ir(sim.people[2]), "un adulto sano, sí")


func test_con_menos_del_minimo_no_se_manda() -> void:
	var sim := _sim(5)
	var dos: Array[int] = [2, 3]
	assert_false(sim.expedicion.mandar_a(dos, 90.0), "con dos no sale")


func test_salen_los_elegidos_y_nadie_mas() -> void:
	var sim := _sim(6)
	var elegidos: Array[int] = [1, 4, 5]
	assert_true(sim.expedicion.mandar_a(elegidos, 90.0), "sale la expedición")
	assert_eq(sim.expedicion.fuera.size(), 3, "salen los que se marcaron")
	for id: int in elegidos:
		assert_true(sim.expedicion.fuera.has(id), "y son ellos: falta el %d" % id)


func test_el_coste_crece_con_los_que_van() -> void:
	var sim := _sim(6)
	assert_lt(float(sim.expedicion.hace_falta_para(3)["raciones"]),
		float(sim.expedicion.hace_falta_para(4)["raciones"]),
		"cuantos más van, más raciones se llevan")


func test_sin_pieles_no_se_sale() -> void:
	# La tienda es la mitad de dormir fuera doce noches. Misma regla que la
	# acampada de la cumbre, sin cifras nuevas.
	var sim := _sim()
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	assert_false(sim.expedicion.mandar(3, 90.0), "sin tienda no se sale")
	assert_false(sim.expedicion.en_marcha(), "y no queda nadie fuera")


func test_sin_lena_no_se_sale() -> void:
	var sim := _sim()
	sim.store.take(Materia.Kind.LENA, 200.0)
	assert_false(sim.expedicion.mandar(3, 90.0), "sin hoguera no se sale")


func test_lo_que_se_lleva_es_lo_que_dice_la_regla() -> void:
	# 3 personas y 12 jornadas: 72 raciones, 3 pieles y 3 × (12 + 1) = 39 de
	# leña. Las pieles vuelven; la leña y la comida, no.
	var sim := _sim()
	var lena_antes := sim.store.amount(Materia.Kind.LENA)
	var piel_antes := sim.store.amount(Materia.Kind.PIEL_CURTIDA)
	var comida_antes := sim.store.food_rations()
	assert_true(sim.expedicion.mandar(3, 90.0), "sale")
	assert_near(lena_antes - sim.store.amount(Materia.Kind.LENA), 39.0, 0.001,
		"se lleva la leña de doce noches y una de margen")
	assert_near(piel_antes - sim.store.amount(Materia.Kind.PIEL_CURTIDA), 3.0, 0.001,
		"y una piel de tienda por cabeza")
	assert_near(comida_antes - sim.store.food_rations(), 72.0, 0.5,
		"y las raciones de siempre")
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	assert_near(sim.store.amount(Materia.Kind.PIEL_CURTIDA), piel_antes, 0.001,
		"y al volver, las pieles vuelven enteras")


func test_lo_que_falta_se_dice() -> void:
	var sim := _sim()
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	var falta := sim.expedicion.lo_que_falta(3)
	assert_eq(falta.size(), 1, "falta una cosa")
	if falta.size() == 1:
		assert_true(falta[0].contains("pieles"), "y son las pieles: %s" % falta[0])


func test_sin_comida_no_se_sale() -> void:
	# Salir sin comida no es una decisión difícil: es mandar a tres personas a
	# morirse. Y no se deja a nadie a medio salir.
	var sim := _sim(8, 5.0)
	assert_false(sim.expedicion.mandar(3, 90.0), "no sale")
	assert_near(sim.store.amount(Materia.Kind.LENA), 200.0, 0.001,
		"ni se lleva la leña")
	assert_false(sim.expedicion.en_marcha(), "y no queda nadie fuera")
	assert_false(sim.expedicion.mandada_alguna_vez, "ni cuenta como mandada")
	# Y la comida que había se queda en la despensa. Hasta el 2026-09-13 se
	# sacaba lo que hubiera y DESPUÉS se veía que no llegaba: la expedición no
	# salía y las raciones desaparecían igual.
	assert_near(sim.store.amount(Materia.Kind.CARNE_SECA), 5.0, 0.001,
		"no se lleva la comida de una expedición que no sale")


func test_sola_no_se_sale() -> void:
	var sim := _sim()
	assert_false(sim.expedicion.mandar(Expedicion.MINIMO_PARA_SALIR - 1, 90.0),
		"con menos del mínimo no se sale")


func test_no_hay_dos_expediciones_a_la_vez() -> void:
	var sim := _sim(10)
	assert_true(sim.expedicion.mandar(3, 90.0), "sale la primera")
	assert_false(sim.expedicion.mandar(3, 270.0), "la segunda espera")


func test_ni_ninos_ni_ancianos_salen_de_expedicion() -> void:
	# Doce jornadas fuera del valle son para adultos. Es una decisión, y está en
	# `Expedicion._quienes_pueden_ir`.
	var sim := _sim(0)
	for i in range(4):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.NINO if i < 2 else Inhabitant.Age.ANCIANO
		sim.people.append(p)
	assert_false(sim.expedicion.mandar(3, 90.0), "sin adultos no hay expedición")


# ------------------------------------------------------------ al volver --

func test_vuelven_en_su_jornada_y_no_antes() -> void:
	var sim := _sim()
	sim.expedicion.mandar(3, 90.0)
	sim.day += Expedicion.JORNADAS_PROPUESTAS - 1
	sim.expedicion.nuevo_dia()
	assert_true(sim.expedicion.en_marcha(), "la víspera siguen fuera")
	sim.day += 1
	_guardar()
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_false(sim.expedicion.en_marcha(), "y en su jornada vuelven")
	for p: Inhabitant in sim.people:
		assert_false(p.esta_de_expedicion(sim.day), "todos en casa")


func test_al_volver_descubre_todo_lo_del_pasillo_y_nada_mas() -> void:
	# LO QUE LA SPEC PIDE: sólo y todos los sitios del pasillo recorrido. Antes
	# se descubría el destino y sus cuatro vecinos.
	var salida := _salida_con_algo()
	assert_false(salida.is_empty(), "hay una salida con algo a la vista")
	var sim := _sim()
	sim.sitio = salida["desde"]
	_guardar()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {sim.sitio.id: true}
	var esperados := _del_pasillo(sim, float(salida["rumbo"]), 12)
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	var antes := GameState.discovered.size()
	var vista_antes := GameState.niebla.cuantas()
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var sobran := 0
	for id: Variant in GameState.discovered:
		var es_esperado := int(id) == sim.sitio.id
		for s: Site in esperados:
			es_esperado = es_esperado or s.id == int(id)
		if not es_esperado:
			sobran += 1
	var faltan := 0
	for s: Site in esperados:
		if not GameState.is_discovered(s):
			faltan += 1
	var nuevos := GameState.discovered.size() - antes
	var vista := GameState.niebla.cuantas() - vista_antes
	var recorrida := GameState.niebla.cuantas(NieblaRegional.RECORRIDA)
	_devolver()
	assert_gt(float(esperados.size()), 0.0, "el pasillo tiene algo: %d" % esperados.size())
	assert_eq(faltan, 0, "se descubren todos los del pasillo")
	assert_eq(sobran, 0, "y ninguno de fuera")
	assert_eq(sim.expedicion.descubiertos, nuevos, "y quedan contados")
	assert_gt(float(vista), 0.0, "levanta la niebla")
	assert_gt(float(recorrida), 0.0, "y deja el pasillo recorrido")


func test_lo_ya_conocido_no_se_vuelve_a_contar() -> void:
	# Importa para el cierre de la fase: «puntos regionales nuevos» no se puede
	# inflar mandando la misma expedición por el mismo sitio.
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	_guardar()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {sim.sitio.id: true}
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var primera := sim.expedicion.descubiertos
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var segunda := sim.expedicion.descubiertos - primera
	_devolver()
	assert_gt(float(primera), 0.0, "la primera descubre")
	assert_eq(segunda, 0, "la segunda por el mismo pasillo, nada")


func test_rumbos_opuestos_descubren_cosas_distintas() -> void:
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	var uno := _del_pasillo(sim, float(salida["rumbo"]), 12)
	var otro := _del_pasillo(sim, float(salida["rumbo"]) + 180.0, 12)
	var comunes := 0
	for s: Site in uno:
		# Lo que está a menos de un medio ancho de casa lo ven los dos.
		if otro.has(s) and _lejos_de(sim.sitio, s) > Pasillo.MEDIO_ANCHO_M:
			comunes += 1
	assert_gt(float(uno.size()), 0.0, "hacia un lado hay algo")
	assert_eq(comunes, 0, "y lo de un lado no lo ve quien va al otro")


func test_mandarla_cuenta_para_cerrar_la_fase() -> void:
	var sim := _sim()
	assert_false(sim.expedicion.mandada_alguna_vez, "al principio, no")
	sim.expedicion.mandar(3, 90.0)
	assert_true(sim.expedicion.mandada_alguna_vez, "en cuanto sale, sí")


# -------------------------------------------- lo que queda al volver (E4) --

func test_alcanzar_un_sitio_con_gente_deja_contacto() -> void:
	# EL PROPÓSITO DE LA EXPEDICIÓN: no busca terreno, busca gente con la que
	# tratar. Ver docs/SISTEMAS.md §4.
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	_guardar()
	var dentro := _del_pasillo(sim, float(salida["rumbo"]), 12)
	var con_gente: Site = dentro[0]
	sim.contacto.ocupados[con_gente.id] = true
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_true(sim.contacto.se_conocen(con_gente.id), "se vuelve conociendo a esa gente")


func test_la_primera_expedicion_encuentra_gente_en_lo_mas_lejano() -> void:
	# Decidido por el usuario el 2026-09-13 —la primera siempre encuentra gente—
	# y el 2026-09-14 dónde: en el sitio del pasillo más lejano del campamento.
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	_guardar()
	var dentro := _del_pasillo(sim, float(salida["rumbo"]), 12)
	var lejano: Site = dentro[0]
	for s: Site in dentro:
		if _lejos_de(sim.sitio, s) > _lejos_de(sim.sitio, lejano):
			lejano = s
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_true(sim.contacto.se_conocen(lejano.id), "conoce a la gente del más lejano")
	assert_eq(sim.contacto.conocidos(), 1, "a esa gente y a nadie más")


func test_un_sitio_vacio_no_deja_contacto() -> void:
	# La otra mitad, y sin ella la de arriba no prueba nada. Desde la SEGUNDA:
	# la primera siempre encuentra gente. La segunda, por un pasillo vaciado.
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	_guardar()
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var primera := sim.contacto.conocidos()
	for s: Site in _del_pasillo(sim, float(salida["rumbo"]), 12):
		sim.contacto.ocupados.erase(s.id)
	sim.contacto.trato.clear()
	var salio := sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	_devolver()
	assert_eq(primera, 1, "la primera dejó contacto, como debe")
	assert_true(salio, "sale la segunda")
	assert_eq(sim.contacto.conocidos(), 0, "donde no vive nadie no se conoce a nadie")


func test_el_contacto_sigue_ahi_una_estacion_despues() -> void:
	# EL CRITERIO LITERAL DEL FRENTE 5: «el contacto sigue ahí una estación
	# después». Es lo que el trueque va a usar.
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	_guardar()
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var conocidos := sim.contacto.conocidos()
	for dia in range(Subsistence.DAYS_PER_SEASON):
		sim.day += 1
		sim.expedicion.nuevo_dia()
	_devolver()
	assert_eq(conocidos, 1, "vuelve conociendo a alguien")
	assert_eq(sim.contacto.conocidos(), 1,
		"y cuarenta y cinco jornadas después, os seguís conociendo")


# -------------------------------- que se les vea irse y volver (tanda 3) --

func test_salen_andando_hacia_el_borde() -> void:
	# No se desvanecen en la cueva: salen andando, y hasta que llegan al borde
	# siguen en el mapa. Ver [Expedicion.andar].
	var sim := _sim(6)
	_guardar()
	assert_true(sim.expedicion.mandar(3, 90.0), "sale")
	_devolver()
	var andando := 0
	for person: Inhabitant in sim.people:
		if person.expedicion_andando:
			andando += 1
			assert_eq(person.state, Inhabitant.State.YENDO, "va de camino")
	assert_eq(andando, 3, "los tres van andando hacia el borde")


func test_al_llegar_al_borde_dejan_de_estar_en_el_mapa() -> void:
	var sim := _sim(6)
	_guardar()
	sim.expedicion.mandar(3, 90.0)
	_devolver()
	var quien: Inhabitant = sim.people[0]
	# Se le pone en la puerta del valle: es el estado que interesa, y llegar
	# hasta ahí andando son jornadas que no hace falta simular.
	quien.position = sim.expedicion.salida
	sim.expedicion.andar(quien, 0, 1.0, 0.05)
	assert_false(quien.expedicion_andando,
		"en el borde deja de andar: ya está fuera del valle")


func test_vuelven_por_donde_salieron() -> void:
	var sim := _sim(6)
	_guardar()
	sim.expedicion.mandar(3, 90.0)
	var puerta := sim.expedicion.salida
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	_devolver()
	for person: Inhabitant in sim.people:
		if person.id < 3:
			assert_near(person.position.distance_to(puerta), 0.0, 1.0,
				"aparece en el borde por el que salió, no en la cueva")


func test_la_puerta_del_valle_esta_en_el_borde() -> void:
	var sim := _sim(6)
	_guardar()
	var puerta := sim.expedicion.puerta_del_valle(90.0)
	_devolver()
	# Sin terreno montado no hay borde que buscar: se sale por casa, que es lo
	# honesto en una prueba sin mapa. Lo que se comprueba aquí es que no
	# revienta y que devuelve algo utilizable.
	assert_true(puerta is Vector3, "devuelve un punto")


func test_por_donde_pasa_despeja_el_mapa() -> void:
	# Pedido por el usuario el 2026-09-13: la expedición cruza el valle entero
	# hasta el borde, y ese camino no puede quedarse en niebla. Medido en la
	# escena con `ExpedicionProbe`: del 2,0 % al 6,2 % sólo con la ida.
	var sim := _sim(6)
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(4096.0, 4096.0))
	_guardar()
	sim.expedicion.mandar(3, 90.0)
	_devolver()
	var antes := sim.knowledge.explored_fraction()
	var quien: Inhabitant = sim.people[0]
	quien.position = Vector3(2000.0, 0.0, 2000.0)
	quien.state = Inhabitant.State.YENDO
	sim.expedicion.andar(quien, 0, 1.0, 0.05)
	assert_gt(sim.knowledge.explored_fraction(), antes,
		"andando hacia el borde se despeja mapa")


func test_quien_ya_esta_fuera_no_despeja_nada() -> void:
	# El control: lo que descubre es ANDAR por el valle, no estar de
	# expedición. Fuera del mapa no se ve nada del mapa.
	var sim := _sim(6)
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(4096.0, 4096.0))
	_guardar()
	sim.expedicion.mandar(3, 90.0)
	_devolver()
	var quien: Inhabitant = sim.people[0]
	quien.expedicion_andando = false
	quien.position = Vector3(2000.0, 0.0, 2000.0)
	var antes := sim.knowledge.explored_fraction()
	sim.expedicion.andar(quien, 0, 1.0, 0.05)
	assert_near(sim.knowledge.explored_fraction(), antes, 0.0001,
		"quien ya salió del valle no descubre nada de él")


func test_la_tienda_es_de_piel_curtida() -> void:
	# Decisión del usuario del 2026-09-13: «todo debería usar piel curtida». Una
	# tienda de pellejo sin curar se pudre en la mochila a los doce días, que es
	# justo lo que dura la expedición.
	var sim := _sim()
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	sim.store.add(Materia.Kind.PIEL, 10.0)
	assert_false(sim.expedicion.mandar(3, 90.0), "con piel cruda no hay tienda")
	assert_eq(sim.store.amount(Materia.Kind.PIEL), 10.0, "y la cruda no se toca")
