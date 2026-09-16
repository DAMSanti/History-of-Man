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
	_antes = [GameState.discovered.duplicate(), GameState.niebla, GameState.home,
		GameState.avistados.duplicate()]


func _devolver() -> void:
	GameState.discovered = _antes[0]
	GameState.niebla = _antes[1]
	GameState.home = _antes[2]
	GameState.avistados = _antes[3]


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
	con_algo_al_lado(sim)
	return sim


## Pone la simulación en ninguna parte con un yacimiento sin descubrir a cien metros:
## desde ahí el pasillo no anda nada, así que los ocho rumbos se ofrecen y una prueba
## que no mira adónde va puede mandar una expedición. Desde el 2026-09-16 sólo se sale
## hacia un rumbo con algo al alcance ([Expedicion.se_ofrece]). La usan otras suites.
static func con_algo_al_lado(sim: SettlementSim) -> void:
	sim.sitio = Site.new()
	sim.sitio.id = 99999
	var vecino := Site.new()
	vecino.id = 99998
	vecino.lon = 0.0009
	sim.expedicion.comarca = SiteSet.new()
	sim.expedicion.comarca.sites.append(vecino)


## Un sitio de la comarca y uno de los ocho rumbos con otro sitio a unos kilómetros
## dentro de su pasillo de doce jornadas: una salida en la que seguro hay algo. Se busca
## y no se escribe, que los ids cambian en cada horneado. Desde el 2026-09-16 el rumbo
## es de los ocho (SISTEMAS §4): antes era el ángulo exacto hacia el otro sitio.
func _salida_con_algo() -> Dictionary:
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	for desde: Site in comarca.available_in(-120.0, Site.Era.PALEOLITICO):
		for hacia: float in Expedicion.RUMBOS:
			var pasillo := Pasillo.trazar(desde.lon, desde.lat, hacia, 12)
			for hasta: Site in comarca.sites:
				if hasta.id != desde.id and _lejos_de(desde, hasta) > 3000.0 \
						and pasillo.contiene(hasta.lon, hasta.lat):
					return {"desde": desde, "rumbo": hacia, "hasta": hasta}
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
	con_algo.expedicion.comarca = null
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
	sim.expedicion.comarca = null
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
	sim.expedicion.comarca = null
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
	sim.expedicion.comarca = null
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
	sim.expedicion.comarca = null
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
	sim.expedicion.comarca = null
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
	sim.expedicion.comarca = null
	_guardar()
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var primera := sim.contacto.conocidos()
	for s: Site in _del_pasillo(sim, float(salida["rumbo"]), 12):
		sim.contacto.ocupados.erase(s.id)
	sim.contacto.trato.clear()
	# Y se olvida lo descubierto: desde el 2026-09-16 un rumbo sin nada por descubrir
	# no se ofrece (SISTEMAS §4), y aquí se prueba el contacto, no el descubrimiento.
	GameState.discovered = {sim.sitio.id: true}
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
	sim.expedicion.comarca = null
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


# ------------------------------------------------------- los ocho rumbos --

## Un sitio de la comarca lejos de la costa y del borde, para que los pasillos anden.
func _origen_de_dentro() -> Site:
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var mejor: Site = null
	var mas_cerca := INF
	for s: Site in comarca.sites:
		var d := absf(s.lon - GameState.HOME_LON) + absf(s.lat - GameState.HOME_LAT)
		if d < mas_cerca:
			mas_cerca = d
			mejor = s
	return mejor


## Un yacimiento puesto a mano a `metros` del origen hacia un rumbo.
func _hacia(desde: Site, rumbo: float, metros: float, id: int) -> Site:
	var s := Site.new()
	s.id = id
	s.lon = desde.lon + sin(deg_to_rad(rumbo)) * metros / (Viaje.METROS_POR_GRADO * cos(deg_to_rad(desde.lat)))
	s.lat = desde.lat + cos(deg_to_rad(rumbo)) * metros / Viaje.METROS_POR_GRADO
	return s


func test_un_rumbo_se_ofrece_si_y_solo_si_su_pasillo_tiene_algo() -> void:
	# A dos kilómetros por su rumbo cada uno: del eje del rumbo de al lado quedan a
	# 1,4 km, fuera de sus 700 m. Así cada yacimiento enciende uno solo.
	var sim := _sim()
	sim.sitio = _origen_de_dentro()
	_guardar()
	GameState.discovered = {sim.sitio.id: true}
	var comarca := SiteSet.new()
	for rumbo: float in [0.0, 90.0, 225.0]:
		comarca.sites.append(_hacia(sim.sitio, rumbo, 2000.0, 900000 + int(rumbo)))
	sim.expedicion.comarca = comarca
	var con_los_tres := sim.expedicion.rumbos_posibles()
	GameState.discover(comarca.sites[1])
	var sin_el_este := sim.expedicion.rumbos_posibles()
	_devolver()
	assert_eq(con_los_tres, [0.0, 90.0, 225.0] as Array[float], "se ofrecen los tres que tienen algo")
	assert_eq(sin_el_este, [0.0, 225.0] as Array[float], "y el este se apaga al descubrir lo suyo")


func test_un_avistado_enciende_su_rumbo() -> void:
	# Un avistado está sin descubrir: saberlo ahí es justo para elegir hacia dónde.
	var sim := _sim()
	sim.sitio = _origen_de_dentro()
	_guardar()
	GameState.discovered = {sim.sitio.id: true}
	var comarca := SiteSet.new()
	comarca.sites.append(_hacia(sim.sitio, 180.0, 2000.0, 900180))
	sim.expedicion.comarca = comarca
	var posibles := sim.expedicion.rumbos_posibles()
	_devolver()
	assert_eq(posibles, [180.0] as Array[float], "el sur, y sólo el sur")


func test_el_yacimiento_mas_al_este_no_ofrece_el_este() -> void:
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var este: Site = null
	for s: Site in comarca.sites:
		if este == null or s.lon > este.lon:
			este = s
	var sim := _sim()
	sim.sitio = este
	sim.expedicion.comarca = null
	_guardar()
	GameState.discovered = {este.id: true}
	var posibles := sim.expedicion.rumbos_posibles()
	_devolver()
	assert_false(posibles.has(90.0), "desde el más al este, el este no: %s" % str(posibles))


func test_solo_se_manda_hacia_uno_de_los_ocho_que_se_ofrecen() -> void:
	var torcida := _sim()
	var sin_nada := _sim()
	sin_nada.sitio = _origen_de_dentro()
	var comarca := SiteSet.new()
	comarca.sites.append(_hacia(sin_nada.sitio, 90.0, 2000.0, 900090))
	sin_nada.expedicion.comarca = comarca
	_guardar()
	GameState.discovered = {sin_nada.sitio.id: true}
	var con_ochenta := torcida.expedicion.mandar(3, 80.0)
	var al_oeste := sin_nada.expedicion.mandar(3, 270.0)
	var al_este := sin_nada.expedicion.mandar(3, 90.0)
	_devolver()
	assert_false(con_ochenta, "un ángulo que no es de los ocho no sale")
	assert_false(al_oeste, "uno de los ocho sin nada al alcance tampoco")
	assert_true(al_este, "el que se ofrece, sí")
	assert_true(Expedicion.es_un_rumbo(sin_nada.expedicion.rumbo), "y el rumbo que lleva es de los ocho")


func test_por_los_ocho_rumbos_descubre_todo_lo_del_pasillo_y_nada_mas() -> void:
	# La prueba de pasillo de siempre, con cada rumbo que se ofrece desde un sitio real:
	# lo que se descubre no cambia por ser uno de ocho.
	var desde := _origen_de_dentro()
	var comprobados := 0
	var mal: Array[String] = []
	for rumbo: float in Expedicion.RUMBOS:
		var sim := _sim()
		sim.sitio = desde
		sim.expedicion.comarca = null
		_guardar()
		GameState.niebla = NieblaRegional.de_la_comarca()
		GameState.discovered = {desde.id: true}
		if not sim.expedicion.se_ofrece(rumbo):
			_devolver()
			continue
		var esperados := _del_pasillo(sim, rumbo, 12)
		sim.expedicion.mandar(3, rumbo)
		sim.day += Expedicion.JORNADAS_PROPUESTAS
		sim.expedicion.nuevo_dia()
		var sobran := GameState.discovered.size() - 1
		var faltan := 0
		for s: Site in esperados:
			if not GameState.is_discovered(s):
				faltan += 1
			else:
				sobran -= 1
		_devolver()
		comprobados += 1
		if faltan != 0 or sobran != 0:
			mal.append("%s: faltan %d, sobran %d" % [Expedicion.nombre_del_rumbo(rumbo), faltan, sobran])
	assert_gt(float(comprobados), 0.0, "algún rumbo se ofrece desde casa: %d" % comprobados)
	assert_true(mal.is_empty(), "todos los del pasillo y ninguno más, por cada rumbo: %s" % str(mal))


# ------------------------------------ el botón: lo que falta para la más corta --

func test_la_mas_corta_sale_con_todo_y_dice_por_que_no_sin_cada_cosa() -> void:
	# La más corta: tres personas y cuatro jornadas. Cada caso quita UNA cosa.
	var corta := Expedicion.new(null).hace_falta_para(Expedicion.MINIMO_PARA_SALIR,
		Pasillo.JORNADAS_MINIMAS)
	var con_todo := _sim()
	var sin_pieles := _sim()
	sin_pieles.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	sin_pieles.store.add(Materia.Kind.PIEL_CURTIDA, float(corta["piel"]) - 1.0)
	var sin_comida := _sim(8, float(corta["raciones"]) * 0.2)
	var sin_lena := _sim()
	sin_lena.store.take(Materia.Kind.LENA, 200.0)
	var sin_gente := _sim(Expedicion.MINIMO_PARA_SALIR - 1)
	var con_una_fuera := _sim()
	_guardar()
	con_una_fuera.expedicion.mandar(3, 90.0)
	_devolver()
	assert_eq(con_todo.expedicion.por_que_no_sale(), "", "con todo, sale")
	assert_true(sin_pieles.expedicion.por_que_no_sale().contains("pieles curtidas"),
		"sin tres pieles curtidas, lo dice: %s" % sin_pieles.expedicion.por_que_no_sale())
	assert_true(sin_comida.expedicion.por_que_no_sale().contains("raciones"),
		"sin raciones, lo dice: %s" % sin_comida.expedicion.por_que_no_sale())
	assert_true(sin_lena.expedicion.por_que_no_sale().contains("leña"),
		"sin leña, lo dice: %s" % sin_lena.expedicion.por_que_no_sale())
	assert_true(sin_gente.expedicion.por_que_no_sale().contains("adultos"),
		"sin gente, lo dice: %s" % sin_gente.expedicion.por_que_no_sale())
	assert_true(con_una_fuera.expedicion.por_que_no_sale().contains("fuera"),
		"con una fuera, lo dice: %s" % con_una_fuera.expedicion.por_que_no_sale())


func test_la_mas_corta_cuesta_lo_de_tres_aunque_puedan_ir_mas() -> void:
	# Ocho que pueden ir y las pieles justas para tres: el botón se enciende.
	var sim := _sim(8)
	var corta := sim.expedicion.hace_falta_para(Expedicion.MINIMO_PARA_SALIR,
		Pasillo.JORNADAS_MINIMAS)
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	sim.store.add(Materia.Kind.PIEL_CURTIDA, float(corta["piel"]))
	assert_eq(sim.expedicion.por_que_no_sale(), "", "con las de tres, sale: no pide ocho")


func test_la_ficha_bloquea_con_los_mismos_motivos() -> void:
	var sim := _sim()
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	var ficha := FichaDeRumbo.new()
	ficha.abrir(sim, "casa")
	var bloqueo := ficha.bloqueo()
	ficha.free()
	assert_eq(bloqueo, sim.expedicion.motivo_para(Expedicion.MINIMO_PARA_SALIR,
		Expedicion.JORNADAS_PROPUESTAS), "la ficha dice lo mismo que la expedición")
	assert_true(bloqueo.contains("pieles curtidas"), "y es el de las pieles: %s" % bloqueo)


func test_la_expedicion_que_pasa_por_un_avistado_lo_descubre_y_la_que_no_no() -> void:
	var salida := _salida_con_algo()
	var sim := _sim()
	sim.sitio = salida["desde"]
	sim.expedicion.comarca = null
	_guardar()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {sim.sitio.id: true}
	var dentro: Site = salida["hasta"]
	# Uno de fuera del pasillo: el primero de la comarca que no cae en él.
	var fuera: Site = null
	var pasillo := sim.expedicion.pasillo_hacia(float(salida["rumbo"]), 12)
	for s: Site in (load("res://data/sites/cantabria_sites.res") as SiteSet).sites:
		if s.id != sim.sitio.id and not pasillo.contiene(s.lon, s.lat):
			fuera = s
			break
	GameState.avistar(dentro)
	GameState.avistar(fuera)
	sim.expedicion.mandar(3, float(salida["rumbo"]))
	sim.day += Expedicion.JORNADAS_PROPUESTAS
	sim.expedicion.nuevo_dia()
	var dentro_descubierto := GameState.is_discovered(dentro)
	var dentro_avistado := GameState.avistado(dentro)
	var fuera_avistado := GameState.avistado(fuera)
	_devolver()
	assert_true(dentro_descubierto and not dentro_avistado,
		"el avistado del pasillo queda descubierto como cualquiera")
	assert_true(fuera_avistado, "y el de fuera sigue avistado, sin descubrir")


# ---------------------------------------------- la ficha de los ocho rumbos --

## Una simulación en un sitio real con un yacimiento sin descubrir hacia cada rumbo dado.
func _sim_con_rumbos(rumbos: Array[float]) -> SettlementSim:
	var sim := _sim()
	sim.sitio = _origen_de_dentro()
	var comarca := SiteSet.new()
	for rumbo: float in rumbos:
		comarca.sites.append(_hacia(sim.sitio, rumbo, 2000.0, 910000 + int(rumbo)))
	sim.expedicion.comarca = comarca
	return sim


func _textos_de_botones(nodo: Node) -> Array[String]:
	var textos: Array[String] = []
	for hijo: Node in nodo.get_children():
		if hijo is Button and not (hijo as Button).toggle_mode:
			textos.append((hijo as Button).text)
		textos.append_array(_textos_de_botones(hijo))
	return textos


func test_la_ficha_solo_apunta_a_los_rumbos_que_se_ofrecen() -> void:
	var sim := _sim_con_rumbos([45.0, 180.0])
	_guardar()
	GameState.discovered = {sim.sitio.id: true}
	var ficha := FichaDeRumbo.new()
	ficha.abrir(sim, "casa")
	var de_entrada := ficha.rumbo
	ficha.apuntar(90.0)
	var tras_el_este := ficha.rumbo
	ficha.apuntar(180.0)
	var tras_el_sur := ficha.rumbo
	var posibles := ficha.posibles.duplicate()
	var salio := ficha.mandar()
	_devolver()
	ficha.free()
	assert_eq(posibles, [45.0, 180.0] as Array[float], "ofrece los dos que tienen algo")
	assert_eq(de_entrada, 45.0, "y apunta de entrada al primero")
	assert_eq(tras_el_este, 45.0, "el este, apagado, no se elige")
	assert_eq(tras_el_sur, 180.0, "el sur, sí")
	assert_true(salio, "y manda hacia él")
	assert_eq(sim.expedicion.rumbo, 180.0, "con ese rumbo")


func test_sin_nada_al_alcance_la_ficha_lo_dice_y_no_manda() -> void:
	var sim := _sim_con_rumbos([])
	_guardar()
	GameState.discovered = {sim.sitio.id: true}
	var ficha := FichaDeRumbo.new()
	ficha.abrir(sim, "casa")
	var bloqueo := ficha.bloqueo()
	var recorrido := ficha.pasillo()
	var salio := ficha.mandar()
	_devolver()
	ficha.free()
	assert_true(bloqueo.contains("nada por descubrir"), "lo dice: %s" % bloqueo)
	assert_true(recorrido == null, "sin rumbo no hay pasillo que dibujar")
	assert_false(salio, "y no manda")


func test_desde_el_valle_se_elige_volver_o_quedarse() -> void:
	var sim := _sim_con_rumbos([90.0])
	_guardar()
	GameState.discovered = {sim.sitio.id: true}
	var desde_el_regional := FichaDeRumbo.new()
	desde_el_regional.abrir(sim, "casa")
	var del_regional := _textos_de_botones(desde_el_regional)
	var desde_el_valle := FichaDeRumbo.new()
	desde_el_valle.abrir(sim, "casa", true)
	var del_valle := _textos_de_botones(desde_el_valle)
	var cierres: Array = []
	desde_el_valle.cerrada.connect(func(mandada: bool, volver: bool) -> void:
		cierres.append([mandada, volver]))
	desde_el_valle.mandar(true)
	_devolver()
	desde_el_regional.free()
	desde_el_valle.free()
	assert_eq(del_regional, ["Mandar", "Cancelar"] as Array[String], "desde el regional, mandar y cancelar")
	assert_eq(del_valle, ["Mandar y volver al valle", "Mandar y quedarse", "Cancelar"] as Array[String],
		"desde el valle, volver o quedarse")
	assert_eq(cierres, [[true, true]], "y al mandar y volver, lo dice al cerrarse")


func test_no_queda_forma_de_pinchar_un_rumbo() -> void:
	# El rumbo libre de 2026-09-14 se pinchaba en el regional y en el valle.
	var sueltas: Array[String] = []
	for ruta: String in ["res://scripts/region/RegionMap.gd", "res://scripts/DemoMain.gd"]:
		for metodo: Dictionary in (load(ruta) as GDScript).get_script_method_list():
			if String(metodo["name"]) in ["_apuntar_a", "_empezar_a_apuntar", "empezar_a_apuntar"]:
				sueltas.append("%s.%s" % [ruta.get_file(), metodo["name"]])
	assert_true(sueltas.is_empty(), "ni en el regional ni en el valle: %s" % str(sueltas))

