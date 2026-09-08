class_name TestExploration
extends TestCase
## Pruebas de a dónde manda la batida de reconocimiento.
##
## Es la mecánica que hace que la exploración funcione sin que el jugador lleve
## a nadie de la mano: el explorador no tiene tajo fijo, su destino se calcula
## cada jornada y es el punto que más mapa abre por lo que cuesta llegar.


func suite_name() -> String:
	return "Exploracion"


func _knowledge() -> BandKnowledge:
	var k := BandKnowledge.new()
	k.setup(48, 48, Vector2(4800.0, 4800.0))
	return k


func _libre() -> Callable:
	return func(_p: Vector3) -> bool: return true


func test_sin_nada_explorado_manda_lejos_del_punto_de_partida() -> void:
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	var destino := Exploration.best_frontier(k, casa, _libre())
	assert_gt(casa.distance_to(destino), 100.0,
		"la batida sale del campamento")


func test_manda_hacia_lo_desconocido_y_no_hacia_lo_ya_visto() -> void:
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	# Se explora a fondo todo el lado este
	for i in range(14):
		k.see_from(casa + Vector3(float(i) * 120.0, 0.0, 0.0), 400.0)
		k.see_from(casa + Vector3(float(i) * 120.0, 0.0, 300.0), 400.0)
		k.see_from(casa + Vector3(float(i) * 120.0, 0.0, -300.0), 400.0)

	var destino := Exploration.best_frontier(k, casa, _libre())
	assert_lt(destino.x, casa.x + 200.0,
		"con el este ya batido, la batida se va al oeste")


func test_a_igual_desconocido_prefiere_lo_cercano() -> void:
	# La batida tiene que volver el mismo dia: un desconocido a dos kilometros
	# vale menos que uno igual de desconocido a quinientos metros
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	var destino := Exploration.best_frontier(k, casa, _libre())
	assert_lt(casa.distance_to(destino), 700.0,
		"con todo por descubrir, se empieza por lo de al lado")


func test_no_manda_a_donde_no_se_puede_llegar() -> void:
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	# Solo se puede ir al oeste
	var solo_oeste := func(p: Vector3) -> bool: return p.x < casa.x
	var destino := Exploration.best_frontier(k, casa, solo_oeste)
	assert_lt(destino.x, casa.x, "la batida solo va adonde se puede ir")


func test_si_no_hay_nada_alcanzable_se_queda() -> void:
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	var cerrado := func(_p: Vector3) -> bool: return false
	assert_eq(Exploration.best_frontier(k, casa, cerrado), casa,
		"sin salida, no se sale")


func test_con_todo_explorado_ya_no_hay_donde_ir() -> void:
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	# Batir el recuadro entero, y de cerca: pasar de lejos deja las celdas a
	# media claridad y eso todavia es territorio por afinar
	for z in range(0, 4800, 140):
		for x in range(0, 4800, 140):
			k.see_from(Vector3(x, 0, z), 260.0)
	assert_eq(Exploration.best_frontier(k, casa, _libre()), casa,
		"cuando no queda nada por descubrir, la batida no tiene destino")


func test_la_batida_avanza_la_frontera_en_pasos_sucesivos() -> void:
	# Lo que de verdad importa: repetir el ciclo abre mapa de forma sostenida,
	# sin que nadie diga adonde ir
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	k.see_from(casa, 300.0)

	var visto_antes := _visto(k)
	for jornada in range(12):
		var destino := Exploration.best_frontier(k, casa, _libre())
		# El explorador ve por el camino, no solo al llegar
		for t in range(1, 6):
			k.see_from(casa.lerp(destino, float(t) / 5.0), 280.0)

	assert_gt(_visto(k), visto_antes * 4.0,
		"doce batidas multiplican el territorio conocido")


func test_no_cuenta_como_por_descubrir_lo_que_esta_fuera_del_mapa() -> void:
	# Si contara, las batidas se irian todas contra el borde del recuadro, que
	# es donde mas "desconocido" hay
	var k := _knowledge()
	var esquina := Vector3(60, 0, 60)
	var centro := Vector3(2400, 0, 2400)
	assert_lt(Exploration.unknown_around(k, esquina, 400.0) + 0.001,
		Exploration.unknown_around(k, centro, 400.0) + 0.002,
		"la esquina no parece mas desconocida que el centro")


func test_dos_batidas_no_van_al_mismo_sitio() -> void:
	# Si las dos salen a la misma frontera, la segunda anda lo mismo y
	# descubre la mitad: sus radios de vista se solapan
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	var primera := Exploration.best_frontier(k, casa, _libre())
	var segunda := Exploration.best_frontier(k, casa, _libre(), [primera])
	assert_gt(primera.distance_to(segunda), 200.0,
		"la segunda batida se abre hacia otro lado")


func test_pero_si_no_hay_alternativa_se_repite_destino() -> void:
	# La penalizacion es un descuento, no un veto: mas vale batir dos veces la
	# unica zona con salida que quedarse en el campamento
	var k := _knowledge()
	var casa := Vector3(2400, 0, 2400)
	var solo_norte := func(p: Vector3) -> bool:
		return p.z < casa.z - 200.0 and absf(p.x - casa.x) < 300.0
	var primera := Exploration.best_frontier(k, casa, solo_norte)
	var segunda := Exploration.best_frontier(k, casa, solo_norte, [primera])
	assert_true(solo_norte.call(segunda),
		"la segunda sigue saliendo por el unico paso que hay")


func _visto(k: BandKnowledge) -> float:
	var n := 0.0
	for v in k.explored:
		if v > 0.01:
			n += 1.0
	return n


# --------------------------------------------- reconocer es andar la zona --

func _sim_on_fake() -> SettlementSim:
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(700.0, 200.0, 700.0)
	sim._rng.seed = 11
	return sim


func test_reconocer_mueve_a_la_persona_por_la_zona() -> void:
	# La queja literal: el explorador llegaba a su destino y se quedaba nueve
	# horas quieto para decir «explorado». No era el sorteo del siguiente
	# tramo: al llegar quedaba el camino del viaje a medio consumir, y el
	# hito del camino manda sobre el destino, asi que apuntaba al sitio donde
	# ya estaba.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, Vector3(700.0, 200.0, 700.0), sim._rng)
	person.work_centre = person.position
	person.forage_target = person.position

	# El camino del viaje, ya gastado: es lo que lo tenia clavado
	person.route = PackedVector3Array([person.position])
	person.route_step = 0

	sim.reconocimiento._next_survey_leg(person)

	var moved := person.forage_target.distance_to(person.work_centre)
	assert_gt(moved, 50.0,
		"el siguiente tramo se va lejos del punto (%d m)" % int(moved))
	assert_eq(person.target, person.forage_target,
		"y es adonde apunta de verdad")


func test_la_batida_da_la_vuelta_al_punto() -> void:
	# Que no se bata tres veces el mismo lado. Quien reparte los tramos ya no
	# es un abanico de angulos sino el MAPA MENTAL: se va a lo que falta por
	# ver, y lo que se acaba de ver deja de faltar. Asi que la prueba tiene
	# que llevar la cuenta de lo visto, como la lleva la partida.
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))

	var centre := Vector3(700.0, 200.0, 700.0)
	var person := Inhabitant.create(0, centre, sim._rng)
	person.position = centre
	person.work_centre = centre
	person.forage_target = centre
	sim.knowledge.see_from(centre, 90.0)

	var quadrants := {}
	for leg in range(SettlementSim.SURVEY_LEGS):
		sim.reconocimiento._next_survey_leg(person)
		var away := person.forage_target - centre
		quadrants[int(floor((atan2(away.z, away.x) + PI) / (PI * 0.5)))] = true
		# Andar el tramo es VER el tramo: es lo que hace que el siguiente se
		# vaya a otro lado en vez de repetir
		sim.knowledge.see_from(person.forage_target, 150.0)

	assert_gt(float(quadrants.size()), 2.0,
		"seis tramos cubren %d cuadrantes de cuatro" % quadrants.size())


func test_dos_tramos_seguidos_no_caen_en_el_mismo_sitio() -> void:
	# Lo que se veia: el batidor volviendo una y otra vez al mismo prado
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))

	var centre := Vector3(700.0, 200.0, 700.0)
	var person := Inhabitant.create(0, centre, sim._rng)
	person.position = centre
	person.work_centre = centre
	person.forage_target = centre

	var previous := centre
	for leg in range(8):
		sim.reconocimiento._next_survey_leg(person)
		var moved := previous.distance_to(person.forage_target)
		assert_gt(moved, 60.0,
			"el tramo %d se va a otro sitio (%d m del anterior)"
				% [leg, int(moved)])
		previous = person.forage_target
		sim.knowledge.see_from(person.forage_target, 150.0)


func test_reconocer_lleva_una_jornada_entera() -> void:
	# Llegar es marcar una casilla; reconocer es batir la comarca
	assert_gt(SettlementSim.SURVEY_HOURS, 6.0, "una jornada util")
	assert_lt(SettlementSim.SURVEY_HOURS, 14.0, "pero cabe en un dia")
	assert_gt(float(SettlementSim.SURVEY_LEGS), 3.0,
		"y se anda en varios tramos, no en uno")


func test_se_llega_desde_donde_uno_esta_y_no_desde_el_campamento() -> void:
	# El fallo que dejaba al explorador mirando al infinito. Se comprobaba si
	# se llegaba DESDE EL CAMPAMENTO, asi que a alguien que ya habia cruzado
	# al otro lado se le decia que no a cada tramo de su propia batida, y se
	# le pasaba la jornada quieto.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, Vector3.ZERO, sim._rng)

	# Al sur del rio, con el rio entre el y el campamento
	person.position = Vector3(700.0, 200.0, 1900.0)
	var next_door := Vector3(900.0, 200.0, 1900.0)

	assert_true(sim.marcha._reachable(person, next_door),
		"desde donde esta, ahi al lado se llega andando")

	# Y desde el campamento, en efecto, no se llega: es lo que se preguntaba
	# antes, y por eso salia que no
	var at_home := Inhabitant.create(1, sim.home_position, sim._rng)
	at_home.position = sim.home_position
	assert_false(sim.marcha._reachable(at_home, next_door),
		"desde el campamento hay un rio de por medio")


func test_la_batida_va_a_lo_que_no_conoce() -> void:
	# La peticion: que no exploren una y otra vez la misma zona.
	#
	# Se compara con el sorteo a ciegas, que es lo que habia antes: la batida
	# tiene que caer en terreno MENOS conocido que un punto al azar del mismo
	# anillo. Comparar «al este» con «conocido» no vale, que es en lo que se
	# equivoco la primera version de esta prueba: lo explorado es una mancha,
	# no un sector.
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))

	var centre := Vector3(700.0, 200.0, 700.0)
	for step in range(10):
		var angle := float(step) / 10.0 * PI
		sim.knowledge.see_from(centre + Vector3(
			cos(angle) * 260.0, 0.0, sin(angle) * 260.0), 150.0)

	var person := Inhabitant.create(0, centre, sim._rng)
	person.position = centre

	var chosen := 0.0
	var blind := 0.0
	var tries := 40
	for attempt in range(tries):
		var pick := sim.reconocimiento._least_known_around(centre, 120.0, 380.0, person)
		chosen += sim.knowledge.explored_at(pick)

		var angle := sim._rng.randf() * TAU
		var radius := sim._rng.randf_range(120.0, 380.0)
		blind += sim.knowledge.explored_at(centre + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius))

	chosen /= float(tries)
	blind /= float(tries)
	assert_lt(chosen, blind,
		"la batida cae en terreno menos visto (%.2f) que el sorteo a ciegas (%.2f)"
			% [chosen, blind])


func test_los_batidores_no_salen_en_fila_india() -> void:
	# Sin margen, dos que salen la misma manana eligen el mismo punto exacto
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))

	var centre := Vector3(700.0, 200.0, 700.0)
	var person := Inhabitant.create(0, centre, sim._rng)
	person.position = centre

	var picks := {}
	for attempt in range(10):
		var pick := sim.reconocimiento._least_known_around(centre, 120.0, 380.0, person)
		picks["%d_%d" % [int(pick.x / 60.0), int(pick.z / 60.0)]] = true

	assert_gt(float(picks.size()), 3.0,
		"diez salidas dan %d sitios distintos" % picks.size())


func test_una_salida_de_cero_metros_no_se_guarda() -> void:
	# La red de seguridad del historial. La salida se abria al elegir destino
	# y volver al abrigo la cerraba, asi que estando ocioso en el campamento
	# se abria y se cerraba una por tick: cuarenta salidas de cero metros el
	# mismo dia, y el historial de verdad por delante.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)

	person.begin_journey("Expedicion", 1, 7.0, Vector3.ZERO)
	person.end_journey(1, "el abrigo", "vuelto sin terminar")
	assert_eq(person.journeys.size(), 0, "no se guarda lo que no anduvo")
	assert_true(person.journey.is_empty(), "y no se queda abierta")


func test_una_salida_de_verdad_si_se_guarda() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)

	person.begin_journey("Batida", 1, 7.0, Vector3.ZERO)
	for step in range(20):
		person.position = Vector3(float(step) * 40.0, 0.0, 0.0)
		person.note_step(40.0, Vector3.ZERO)
	person.end_journey(1, "el robledal", "hay caza")

	assert_eq(person.journeys.size(), 1, "una salida")
	var trip: Dictionary = person.journeys[0]
	assert_gt(float(trip["metres"]), 700.0, "con sus metros")
	assert_gt(float(trip["farthest"]), 700.0, "y lo mas lejos que llego")
	assert_gt(float((trip["path"] as PackedVector3Array).size()), 5.0,
		"y el camino guardado, que es lo que se dibuja")


func test_la_salida_recuerda_su_punto_mas_lejano() -> void:
	# Para poder nombrar el sitio cuando la salida NO termina: al volver, el
	# destino ya es el propio abrigo y salia «en del abrigo, a 0 m»
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)

	person.begin_journey("Expedicion", 1, 7.0, Vector3.ZERO)
	person.position = Vector3(600.0, 0.0, 0.0)
	person.note_step(600.0, Vector3.ZERO)
	person.position = Vector3(20.0, 0.0, 0.0)
	person.note_step(580.0, Vector3.ZERO)

	assert_gt((person.journey["far_point"] as Vector3).x, 500.0,
		"el punto mas lejano es el de ida, no donde acabo")


# ------------------------------------------------ cumbres de verdad ------

func _sim_on_peaks() -> SettlementSim:
	var sim := SettlementSim.new()
	sim._terrain = PeakTerrain.new()
	sim.home_position = Vector3(300.0, 0.0, 300.0)
	sim.home_position.y = sim._terrain.get_height_at(sim.home_position)
	sim._rng.seed = 8
	sim.parajes = Parajes.new()
	return sim


func test_las_cumbres_caen_en_la_cima_y_no_en_la_ladera() -> void:
	# La queja: no acierta el punto mas alto como mirador. Se buscaba con
	# veinticuatro rayos desde el campamento y cuatro distancias fijas, y eso
	# no busca cumbres: coge noventa y seis puntos cualesquiera y llama cumbre
	# a la altura que tuvieran. Casi siempre caia en mitad de una ladera.
	var sim := _sim_on_peaks()
	var peaks := sim.cumbres._find_peaks()
	assert_eq(peaks.size(), PeakTerrain.SUMMITS.size(),
		"encuentra las TRES cumbres, no %d" % peaks.size())

	for peak: Dictionary in peaks:
		var pos: Vector3 = peak["pos"]
		var flat := Vector2(pos.x, pos.z)

		# Cada cumbre tiene que caer encima de una de las tres puestas a mano
		var best := INF
		for summit: Array in PeakTerrain.SUMMITS:
			best = minf(best, flat.distance_to(summit[0] as Vector2))
		assert_lt(best, 60.0,
			"la cumbre en %s cae a %d m del alto de verdad" % [pos, int(best)])


func test_una_cumbre_domina_lo_que_tiene_debajo() -> void:
	# Es lo que separa un mirador de un reperecho en mitad de una ladera
	var sim := _sim_on_peaks()
	for peak: Dictionary in sim.cumbres._find_peaks():
		assert_gt(float(peak["command"]), Cumbres.PEAK_MIN_COMMAND - 1.0,
			"se levanta %d m sobre lo que la rodea" % int(peak["command"]))


func test_no_se_cuenta_dos_veces_la_misma_cumbre() -> void:
	var sim := _sim_on_peaks()
	var peaks := sim.cumbres._find_peaks()
	assert_lt(float(peaks.size()), float(PeakTerrain.SUMMITS.size()) + 1.0,
		"tres montes dan como mucho tres cumbres, no %d" % peaks.size())


# --- mandar subir una cumbre a mano ----------------------------------------

func test_sin_nadie_capaz_la_orden_de_cima_lo_dice() -> void:
	# Peticion explicita: el boton tiene que dar «no hay ningun miembro de
	# la banda con habilidad suficiente», no fallar en silencio.
	var sim := _sim_on_peaks()
	var novato := Inhabitant.create(0, sim.home_position, sim._rng)
	novato.age_years = 30
	novato.age_group = Inhabitant.Age.ADULTO
	novato.skill[Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)] = 0.0
	sim.people = [novato]

	# Una cumbre dura de verdad, pero por debajo del techo de equipo
	var peak := {"pos": sim.home_position + Vector3(400.0, 0.0, 0.0),
		"hard": 0.75, "rise": 500.0}
	var problem := sim.cumbres.order_ascent(peak)
	assert_true(problem.contains("habilidad suficiente") 			or problem.contains("solitario"),
		"se explica por que no se puede: «%s»" % problem)
	assert_false(sim.cumbres.has_peak_order, "y no queda orden puesta")


func test_con_alguien_capaz_la_orden_sale() -> void:
	var sim := _sim_on_peaks()
	var veterano := Inhabitant.create(0, sim.home_position, sim._rng)
	veterano.age_years = 30
	veterano.age_group = Inhabitant.Age.ADULTO
	veterano.skill[Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)] = 0.9
	sim.people = [veterano]

	var facil := {"pos": sim.home_position + Vector3(300.0, 0.0, 0.0),
		"hard": 0.3, "rise": 200.0}
	assert_eq(sim.cumbres.order_ascent(facil), "", "con quien se atreva, la orden sale")
	assert_true(sim.cumbres.has_peak_order, "y queda señalada")


func test_una_pared_que_pide_equipo_no_se_intenta() -> void:
	var sim := _sim_on_peaks()
	var crack := Inhabitant.create(0, sim.home_position, sim._rng)
	crack.age_years = 30
	crack.age_group = Inhabitant.Age.ADULTO
	crack.skill[Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)] = 0.95
	sim.people = [crack]

	var pared := {"pos": sim.home_position + Vector3(300.0, 0.0, 0.0),
		"hard": 0.95, "rise": 900.0}
	var problem := sim.cumbres.order_ascent(pared)
	assert_false(problem.is_empty(),
		"una pared que pide equipo no se intenta ni con el mejor")
	assert_false(sim.cumbres.has_peak_order, "y no queda orden puesta")


# --- las cumbres duras piden grupo -----------------------------------------

func test_una_cumbre_facil_se_sube_en_solitario() -> void:
	var sim := _sim_on_fake()
	assert_true(sim.cumbres._climbing_party_enough(0.2),
		"una cumbre por debajo del umbral no pide compania")


func test_una_cumbre_dura_no_se_sube_solo() -> void:
	# Peticion explicita: "las ascensiones mas dificiles necesitaran mas de
	# una persona"
	var sim := _sim_on_fake()
	assert_false(sim.cumbres._climbing_party_enough(0.9),
		"una cumbre dura no se ataca en solitario")


func test_una_cumbre_dura_si_se_sube_con_grupo_bastante() -> void:
	var sim := _sim_on_fake()
	for i in range(Cumbres.MIN_CLIMBING_PARTY):
		var p := Inhabitant.create(i, sim.home_position, sim._rng)
		p.job = Profession.Job.EXPLORACION
		p.current_speciality = Profession.Speciality.ASCENSION
		sim.people.append(p)
	assert_true(sim.cumbres._climbing_party_enough(0.9),
		"con bastante gente puesta en ascension, si se ataca")


func test_peak_for_descarta_cumbres_duras_sin_grupo() -> void:
	# Integracion con `peak_for`: aunque la pericia de sobra para atreverse,
	# sin compania una cumbre dura no debe salir elegida.
	var sim := _sim_on_peaks()
	var persona := Inhabitant.create(0, sim.home_position, sim._rng)
	persona.job = Profession.Job.EXPLORACION
	persona.current_speciality = Profession.Speciality.ASCENSION
	sim.people = [persona]

	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	persona.skill[task] = 0.95

	var elegida := sim.cumbres.peak_for(persona)
	if not elegida.is_empty():
		assert_lt(float(elegida["hard"]), Cumbres.HARD_PEAK_PARTY_THRESHOLD,
			"solo, no se elige una cumbre que pida grupo")


func test_quien_no_puede_volver_a_casa_duerme_igual() -> void:
	# La trampa sin salida que apagaba la exploracion a las tres semanas: solo
	# se descansaba EN el abrigo, asi que quien no podia llegar no dormia
	# nunca, la fatiga se clavaba en cien, y reventado no se sale de
	# expedicion. Medido: el explorador dejaba de hacer expediciones el dia
	# veinte y se pasaba las otras veinte despierto en mitad del monte.
	var sim := _sim_on_fake()
	sim.store = Storehouse.new()
	sim.time_scale = 1.0
	sim.hour = 23.0

	# Al otro lado del rio: desde ahi no hay camino al campamento
	var person := Inhabitant.create(0, Vector3.ZERO, sim._rng)
	person.position = Vector3(700.0, 200.0, 1900.0)
	person.fatigue = 100.0
	person.state = Inhabitant.State.VOLVIENDO
	sim.people = [person]

	assert_false(sim.marcha._navgrid().connected(person.position, sim.home_position),
		"de verdad no puede volver: hay un rio de por medio")

	for tick in range(120):
		sim._process(sim.seconds_per_day / 24.0 / 60.0)

	assert_lt(person.fatigue, 100.0,
		"descansa aunque sea al raso (fatiga %.0f)" % person.fatigue)


func test_la_exploracion_sigue_el_agua() -> void:
	# Nadie explora un mapa a cuadros: se sigue el rio aguas arriba porque
	# lleva a alguna parte y da de beber. El tiron tiene que existir y no
	# tiene que ser una obsesion.
	var sim := _sim_on_fake()
	var dry := Vector3(700.0, 0.0, 700.0)
	var bank := Vector3(700.0, 0.0, FakeTerrain.RIVER_Z + FakeTerrain.RIVER_HALF + 5.0)

	assert_eq(sim.reconocimiento._terrain_lure(dry), 0.0,
		"en mitad de la meseta el terreno no tira de nadie")
	assert_gt(sim.reconocimiento._terrain_lure(bank), 0.0,
		"y en la orilla si")
	assert_lt(sim.reconocimiento._terrain_lure(bank), 0.4,
		"pero es una preferencia, no una obsesion")


func test_el_cauce_infranqueable_no_es_un_pasillo() -> void:
	# La orilla llama; el vado imposible no. Un rio que no se cruza no es una
	# guia, es una pared, y mandar alli a la gente es mandarla a mirar agua.
	var sim := _sim_on_fake()
	var midstream := Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)
	assert_eq(sim.reconocimiento._terrain_lure(midstream), 0.0,
		"por el medio del rio no se explora")


func test_un_camino_gastado_se_vuelve_a_trazar() -> void:
	# El ultimo atasco que quedaba, y el mas escurridizo: la guarda que evita
	# recalcular pedia «mismo destino y ruta no vacia», y una ruta CONSUMIDA
	# hasta el final sin haber llegado cumple las dos. La persona se quedaba
	# con un camino gastado que ya no llevaba a ninguna parte.
	#
	# Peor todavia: el re-trazado que puse para arreglarlo entraba por esta
	# misma guarda y se daba media vuelta, o sea que no hacia nada.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, Vector3.ZERO, sim._rng)
	person.position = Vector3(1000.0, 200.0, 700.0)

	var far := Vector3(400.0, 200.0, 700.0)
	sim.marcha._send_to(person, far)
	assert_gt(float(person.route.size()), 0.0, "se le traza camino")

	# Se gasta el camino sin haber llegado, que es lo que pasa de verdad
	# cuando a alguien lo interrumpen a mitad de trayecto
	person.route_step = person.route.size()
	sim.marcha._send_to(person, far)

	assert_lt(float(person.route_step), float(person.route.size()),
		"se le traza otro y vuelve a tener hitos por delante")


# --------------------------- batida: cuanto revela y por que sube el ojo --

func _paraje_con_incognitas(sim: SettlementSim, count: int) -> Paraje:
	var p := Paraje.create(1, 1, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, sim.home_position + Vector3(150.0, 0.0, 0.0), 1)
	p.contents = {}
	for i in range(count):
		p.contents[i] = {"abundancia": 0.2, "sabido": false}
	sim.parajes.add(p)
	return p


func _batidor(sim: SettlementSim, paraje: Paraje, skill_value: float) -> Inhabitant:
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.BATIDA
	person.skill[Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)] = skill_value
	person.work_centre = paraje.position
	person.position = paraje.position
	return person


func _revealed_count(paraje: Paraje) -> int:
	var n := 0
	for kind: int in paraje.contents:
		if bool((paraje.contents[kind] as Dictionary)["sabido"]):
			n += 1
	return n


func test_sin_destreza_una_batida_revela_como_mucho_un_material() -> void:
	var sim := _sim_on_fake()
	var paraje := _paraje_con_incognitas(sim, 6)
	var person := _batidor(sim, paraje, 0.0)

	sim.reconocimiento._finish_survey(person)

	assert_eq(_revealed_count(paraje), 1,
		"sin ojo entrenado, una sola incognita por tarde")


func test_con_destreza_alta_una_batida_suele_revelar_mas_de_un_material() -> void:
	# Es una tirada encadenada -cada hallazgo da otra oportunidad-, asi que se
	# mide en MEDIA sobre varias tardes y no en una sola: con buen ojo (0,9)
	# lo raro es quedarse en uno solo.
	var trials := 30
	var total := 0
	for i in range(trials):
		var sim := _sim_on_fake()
		sim._rng.seed = 100 + i
		var paraje := _paraje_con_incognitas(sim, 6)
		var person := _batidor(sim, paraje, 0.9)
		sim.reconocimiento._finish_survey(person)
		total += _revealed_count(paraje)

	var average := float(total) / float(trials)
	assert_gt(average, 1.3,
		"con buen ojo, una tarde suele dar para mas de un hallazgo (media %.2f)" % average)


func test_dar_con_un_material_sube_la_destreza_de_batida() -> void:
	# El hito -encontrar algo- es lo que sube el ojo, no las horas andadas:
	# `_survey` ya cuenta esas horas aparte, y batida no tiene otro sitio
	# donde practicar -ni criios ni ancianos, y de adulto no se «trabaja» una
	# batida, se sale a ella.
	var sim := _sim_on_fake()
	var paraje := _paraje_con_incognitas(sim, 3)
	var person := _batidor(sim, paraje, 0.1)
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	var before := person.skill_in(task)

	sim.reconocimiento._finish_survey(person)

	assert_gt(person.skill_in(task), before,
		"encontrar algo deja poso, no solo las horas")


func test_resolver_una_incognita_de_un_paraje_conocido_no_es_un_paraje_nuevo() -> void:
	# El hito grande es abrir sitio, no acabar de conocer uno que ya se tenia:
	# batir un paraje EXISTENTE no debe apuntarse como monte sin nombre.
	var sim := _sim_on_fake()
	var paraje := _paraje_con_incognitas(sim, 3)
	var person := _batidor(sim, paraje, 0.1)

	sim.reconocimiento._finish_survey(person)

	assert_eq(sim._new_ground_surveys_today.size(), 0,
		"batir un sitio que ya tenia nombre no cuenta como monte nuevo")


# --------------------- destreza de batida: un techo por cada fuente -------

func test_la_pura_repeticion_no_pasa_del_cincuenta() -> void:
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.BATIDA
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	person.skill[task] = Reconocimiento.BATIDA_REPETITION_CEILING - 0.01

	# Muchas horas de puro andar y mirar, sin _finish_survey -sin encontrar
	# nada-, tienen que quedarse pegadas al techo de repeticion
	for _i in range(500):
		sim.reconocimiento._survey(person, 1.0)

	assert_between(person.skill_in(task), 0.0,
		Reconocimiento.BATIDA_REPETITION_CEILING + 0.001,
		"sin descubrir nada, la destreza no pasa del %.0f" 			% (Reconocimiento.BATIDA_REPETITION_CEILING * 100.0))


func test_descubrir_materiales_no_pasa_del_setenta_y_cinco() -> void:
	# Se sale bajo -0,3-, no pegado al techo: con veinte incognitas y varias
	# visitas de sobra para vaciarlas todas, el crecimiento SIN techo pasaria
	# de largo el 75 con holgura, asi que si la prueba pasa es porque el
	# techo de verdad esta cortando.
	var sim := _sim_on_fake()
	var paraje := _paraje_con_incognitas(sim, 20)
	var person := _batidor(sim, paraje, 0.3)
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)

	for _i in range(10):
		if not paraje.has_unknowns():
			break
		sim.reconocimiento._finish_survey(person)

	assert_between(person.skill_in(task), 0.0,
		Reconocimiento.BATIDA_MATERIAL_CEILING + 0.001,
		"resolver incognitas de un paraje ya conocido no pasa del %.0f" 			% (Reconocimiento.BATIDA_MATERIAL_CEILING * 100.0))


func test_abrir_un_paraje_nuevo_si_puede_pasar_del_setenta_y_cinco() -> void:
	# El techo de arriba -95, el de siempre- solo se destapa con el hito
	# grande: abrir un sitio que no existia.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.BATIDA
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	person.skill[task] = Reconocimiento.BATIDA_MATERIAL_CEILING

	var spot := sim.home_position + Vector3(150.0, 0.0, 0.0)
	sim._new_ground_surveys_today = [{"person": person, "position": spot,
		"speciality": Profession.Speciality.BATIDA}]
	var paraje := Paraje.create(1, 1, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, spot, 1)

	sim.reconocimiento._credit_new_ground([paraje])

	assert_gt(person.skill_in(task), Reconocimiento.BATIDA_MATERIAL_CEILING,
		"abrir un paraje nuevo si rompe el techo de los 75")


func test_abrir_un_paraje_nuevo_premia_a_quien_lo_ha_batido() -> void:
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.BATIDA
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	person.skill[task] = 0.2

	var spot := sim.home_position + Vector3(150.0, 0.0, 0.0)
	sim._new_ground_surveys_today = [{"person": person, "position": spot,
		"speciality": Profession.Speciality.BATIDA}]
	var paraje := Paraje.create(1, 1, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, spot, 1)

	sim.reconocimiento._credit_new_ground([paraje])

	assert_gt(person.skill_in(task), 0.2, "quien lo ha abierto aprende del hito")


func test_quien_no_ha_batido_cerca_no_se_lleva_el_hito() -> void:
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.BATIDA
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	person.skill[task] = 0.2

	var far := sim.home_position + Vector3(2000.0, 0.0, 0.0)
	sim._new_ground_surveys_today = [{"person": person, "position": far,
		"speciality": Profession.Speciality.BATIDA}]
	var paraje := Paraje.create(1, 1, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, sim.home_position + Vector3(150.0, 0.0, 0.0), 1)

	sim.reconocimiento._credit_new_ground([paraje])

	assert_eq(person.skill_in(task), 0.2,
		"batir lejos de donde nace el paraje no cuenta como haberlo abierto")


func test_el_andador_y_la_rejilla_dicen_lo_mismo() -> void:
	# La raiz de los tres atascos: el andador miraba el punto bajo los pies y
	# el planificador la celda entera con cinco muestras. Los dos tenian razon
	# y no se ponian de acuerdo, asi que habia sitios donde una persona podia
	# estar y que para la rejilla no existian.
	var sim := _sim_on_fake()
	var grid := sim.marcha._navgrid()

	for probe in range(60):
		var point := Vector3(
			sim._rng.randf_range(60.0, 1980.0), 0.0,
			sim._rng.randf_range(60.0, 1980.0))
		assert_eq(sim.marcha._can_step_into(point),
			grid.cost[grid.cell_of(point)] > Navgrid.BLOCKED,
			"en %s los dos dicen lo mismo" % point)


# ------------------ dias de avituallamiento, por especialidad y destreza --

func test_mas_destreza_de_expedicion_da_mas_dias_de_comida() -> void:
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.EXPEDICION
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION)

	person.skill[task] = 0.0
	var novato_days := sim.despensa._expedition_days_for(person)
	person.skill[task] = 0.9
	var veterano_days := sim.despensa._expedition_days_for(person)

	assert_gt(veterano_days, novato_days,
		"quien mejor sabe racionar y buscar por el camino aguanta mas noches fuera")


func test_expedicion_y_ascension_no_comparten_destreza_para_los_dias() -> void:
	# La misma persona puede ser un gran escalador y un mal logistico de
	# expedicion larga: cada especialidad cuenta la suya, no la del otro.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.skill[Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)] = 0.9
	person.skill[Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION)] = 0.0

	person.current_speciality = Profession.Speciality.ASCENSION
	var ascension_days := sim.despensa._expedition_days_for(person)
	person.current_speciality = Profession.Speciality.EXPEDICION
	var expedicion_days := sim.despensa._expedition_days_for(person)

	assert_gt(ascension_days, expedicion_days,
		"la destreza de ascension no regala dias a una expedicion")


func test_no_hace_falta_avituallar_un_viaje_de_un_dia() -> void:
	# Un pico o un frente a un paso del abrigo no necesita racion de viaje:
	# se come en casa y se vuelve esa misma tarde, como cualquier otro tajo.
	var sim := _sim_on_fake()
	sim.store = Storehouse.new()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.EXPEDICION

	assert_true(sim.despensa._provision(person, sim.arrive_radius * 2.0),
		"con el destino cerca, sale sin comida encima")
	assert_true(person.load.is_empty(),
		"y no ha cargado nada del almacen")


func test_sin_carne_seca_ni_grasa_se_sale_igual_con_lo_que_haya() -> void:
	# El bug de verdad: una banda que se queda sin carne seca, fruto seco
	# ni grasa -las tres unicas cosas que antes se aceptaban para el
	# viaje- dejaba de explorar EL RESTO DE LA PARTIDA sin ni un aviso,
	# aunque el almacen siguiera lleno de pescado o marisco fresco.
	# Medido en una partida real: mas de ciento cincuenta dias seguidos
	# sin que ningun explorador saliera del abrigo.
	var sim := _sim_on_fake()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.PESCADO, 200.0)
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.EXPEDICION

	assert_true(sim.despensa._provision(person, 2000.0),
		"sin carne seca ni grasa, pero con pescado de sobra, sale igual")
	assert_false(person.load.is_empty(),
		"y ha cargado del pescado que si habia")


func test_avituallar_pide_mas_comida_cuanto_mas_lejos_se_va() -> void:
	# La peticion explicita: la comida a llevar depende de adonde se vaya,
	# no un numero fijo igual para el pico de al lado que para dos valles
	# mas alla.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.EXPEDICION

	var cerca := sim.despensa._expedition_days_for(person, 400.0)
	var lejos := sim.despensa._expedition_days_for(person, 8000.0)
	assert_gt(lejos, cerca,
		"un destino mucho mas lejano pide mas dias de comida")


func test_la_cantidad_de_un_extra_se_encuentra_fuera_de_su_actividad_natural() -> void:
	# La resina es cosa de recoleccion -LENA_FIBRA-, pero tambien puede
	# aparecer como extra de un paraje de MATERIA PRIMA -un cantizal con
	# resina de paso-. Peticion explicita: la cantidad tiene que verse
	# SIEMPRE, no solo cuando el material coincide con la actividad que da
	# nombre al sitio.
	var sim := _sim_on_fake()
	var antes := GameState.season
	for season: int in Subsistence.Season.values():
		GameState.season = season as Subsistence.Season
		assert_gt(sim._yield_per_day(Subsistence.Activity.MATERIA_PRIMA,
				Materia.Kind.RESINA), 0.0,
			"resina en un paraje de materia prima, temporada %d" % season)
		assert_gt(sim._yield_per_day(Subsistence.Activity.MARISQUEO,
				Materia.Kind.CARACOL), 0.0,
			"caracol en un paraje de marisqueo, temporada %d" % season)
	GameState.season = antes


func test_miel_y_bellota_nunca_se_quedan_a_cero_fuera_de_temporada() -> void:
	# Solo tenian cosecha grande en su estacion -miel en verano, bellota en
	# otoño- y en cualquier otra caian a cero en todas las tablas: un
	# paraje que las enseñara como extra se quedaba sin cifra el resto del
	# año, justo lo contrario de "debe tener cantidad siempre".
	var sim := _sim_on_fake()
	var antes := GameState.season
	for season: int in Subsistence.Season.values():
		GameState.season = season as Subsistence.Season
		assert_gt(sim._yield_per_day(Subsistence.Activity.RECOLECCION,
				Materia.Kind.MIEL), 0.0, "miel, temporada %d" % season)
		assert_gt(sim._yield_per_day(Subsistence.Activity.RECOLECCION,
				Materia.Kind.BELLOTA), 0.0, "bellota, temporada %d" % season)
	GameState.season = antes


func test_avituallar_sin_distancia_usa_el_suelo_de_siempre() -> void:
	# Las pruebas y sitios donde aun no se ha calculado destino no deben
	# quedarse sin racion: se cae al suelo fijo de antes.
	var sim := _sim_on_fake()
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.current_speciality = Profession.Speciality.EXPEDICION

	assert_eq(sim.despensa._expedition_days_for(person), sim.despensa._expedition_days_for(person, -1.0),
		"sin distancia, el mismo resultado de siempre")


func test_no_sale_de_expedicion_si_esta_muy_cansado() -> void:
	# La peticion explicita: esperar a estar descansado antes de partir. Sin
	# esto, quien llega reventado de una salida se echa a andar otra vez de
	# inmediato en cuanto amanece.
	var sim := _sim_on_fake()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 50.0)
	sim.time_scale = 1.0
	sim.hour = 8.0

	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.position = sim.home_position
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.EXPEDICION
	person.state = Inhabitant.State.OCIOSO
	# Por debajo del 70 al que ya se manda volver a quien esta reventado EN
	# EL CAMPO -otra regla, mas vieja-, pero por encima de lo que aqui
	# cuenta como descansado: el hueco que antes no cubria nadie.
	person.fatigue = 50.0
	sim.people = [person]

	sim._process(sim.seconds_per_day / 24.0)

	assert_eq(person.state, Inhabitant.State.OCIOSO,
		"se queda en el abrigo en vez de partir cansado")
	assert_true(person.load.is_empty(),
		"y no ha cargado comida para un viaje que no ha empezado")


# --------------------------- aprender explorando: todas las actividades --

func test_explorar_ensena_todas_las_actividades_no_solo_caza() -> void:
	# `person.activity` de un explorador esta fijo a CAZA en la tabla de
	# oficios -algo habia que poner-, pero eso NO puede significar que solo
	# nazcan parajes de caza al explorar. Es la causa real de "la
	# exploracion no encuentra ningun paraje [que no sea de caza]".
	var sim := _sim_on_fake()
	var explorador := Inhabitant.create(0, sim.home_position, sim._rng)
	explorador.job = Profession.Job.EXPLORACION
	explorador.activity = Subsistence.Activity.CAZA

	var aprendidas := SettlementSim._activities_for_learning(explorador)
	assert_eq(aprendidas.size(), 5,
		"un explorador ensena las cinco actividades, no solo la suya")
	assert_true(aprendidas.has(Subsistence.Activity.RECOLECCION),
		"incluida recoleccion")
	assert_true(aprendidas.has(Subsistence.Activity.PESCA),
		"incluida pesca")

	var recolector := Inhabitant.create(1, sim.home_position, sim._rng)
	recolector.job = Profession.Job.RECOLECCION
	recolector.activity = Subsistence.Activity.RECOLECCION
	var suya := SettlementSim._activities_for_learning(recolector)
	assert_eq(suya, [Subsistence.Activity.RECOLECCION],
		"quien no explora solo ensena su propia actividad")


func test_reconocer_ensena_el_sitio_no_solo_el_camino_hasta_el() -> void:
	# `_learn_from` no corre en RECONOCIENDO -esta cansando fatiga, no
	# andando-, asi que sin que `_survey` enseñe algo por su cuenta, las
	# horas de reconocimiento -la mayor parte de una expedicion- no subian
	# la familiaridad de nada, y ningun paraje nuevo llegaba nunca al
	# umbral de nombrarse por mucho que la banda saliera a explorar.
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))

	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.EXPEDICION
	person.position = Vector3(700.0, 200.0, 700.0)
	person.work_centre = person.position
	person.forage_target = person.position
	person.state = Inhabitant.State.RECONOCIENDO

	var antes := sim.knowledge.familiarity_at(
		Subsistence.Activity.RECOLECCION, person.position)
	sim.reconocimiento._survey(person, 4.0)
	var despues := sim.knowledge.familiarity_at(
		Subsistence.Activity.RECOLECCION, person.position)

	assert_gt(despues, antes,
		"batir la comarca ensena el sitio, no solo el camino hasta el")


func test_terminar_de_reconocer_terreno_nuevo_lo_deja_a_punto_de_nombrarse() -> void:
	# La peticion explicita: batida, expedicion y ascension TIENEN que
	# encontrar parajes, no solo los recolectores. Con `observe` solo, una
	# unica visita a un frente lejano se quedaba muy por debajo del umbral
	# de nombrarse -y la expedicion casi nunca vuelve dos veces al mismo
	# frente-, asi que terminar de reconocer terreno nuevo tiene que bastar
	# por si solo para dejarlo a punto de bautizarse esa misma jornada.
	for speciality: int in [Profession.Speciality.BATIDA,
			Profession.Speciality.EXPEDICION, Profession.Speciality.ASCENSION]:
		var sim := _sim_on_fake()
		sim.knowledge = BandKnowledge.new()
		sim.knowledge.setup(64, 64, Vector2(2048.0, 2048.0))

		var person := Inhabitant.create(0, sim.home_position, sim._rng)
		person.job = Profession.Job.EXPLORACION
		person.current_speciality = speciality as Profession.Speciality
		person.position = Vector3(700.0, 200.0, 700.0)
		person.work_centre = person.position
		person.forage_target = person.position

		sim.reconocimiento._finish_survey(person)

		var conocido := sim.knowledge.familiarity_at(
			Subsistence.Activity.RECOLECCION, person.work_centre)
		assert_gt(conocido, BandKnowledge.KNOWN_ENOUGH,
			"%d: terminar de reconocer basta para cruzar el umbral, de una vez"
				% speciality)


# --------------- grupo minimo para explorar lejos: no vale ir solo -------

func test_una_partida_corta_no_va_al_borde_del_mapa() -> void:
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(4800.0, 4800.0))

	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.EXPEDICION
	person.position = sim.home_position
	sim.people = [person]

	# Rumbo del jugador al borde del mapa, muy por encima de REGIONAL_DISTANCE
	sim.has_scout_order = true
	sim.scout_order = sim.home_position + Vector3(4000.0, 0.0, 0.0)

	var destino := sim.reconocimiento._scout_target(person)
	assert_lt(destino.distance_to(sim.home_position), Despensa.REGIONAL_DISTANCE,
		"solo, no se aventura tan lejos aunque el jugador lo señale")


func test_con_grupo_numeroso_si_se_va_lejos() -> void:
	var sim := _sim_on_fake()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(64, 64, Vector2(4800.0, 4800.0))

	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.EXPEDICION
	person.position = sim.home_position

	var companeros: Array[Inhabitant] = [person]
	for i in range(1, Despensa.MIN_GROUP_FOR_REGIONAL):
		var otro := Inhabitant.create(i, sim.home_position, sim._rng)
		otro.job = Profession.Job.EXPLORACION
		otro.current_speciality = Profession.Speciality.EXPEDICION
		companeros.append(otro)
	sim.people = companeros

	sim.has_scout_order = true
	sim.scout_order = sim.home_position + Vector3(4000.0, 0.0, 0.0)

	var destino := sim.reconocimiento._scout_target(person)
	assert_gt(destino.distance_to(sim.home_position), Despensa.REGIONAL_DISTANCE,
		"con bastante gente puesta en ello, si se llega al rumbo lejano")


# --------------------------------- vados: un hito que se lleva una vez ----

func _en_el_vado(sim: SettlementSim) -> Inhabitant:
	var person := Inhabitant.create(0, sim.home_position, sim._rng)
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.EXPEDICION
	person.position = Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)
	return person


func test_cruzar_un_vado_nuevo_sube_la_destreza_de_expedicion() -> void:
	var sim := _sim_on_fake()
	var person := _en_el_vado(sim)
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION)
	var before := person.skill_in(task)

	sim.marcha._terrain_speed(person, Vector3(1.0, 0.0, 0.0), 1.0)

	assert_gt(person.skill_in(task), before,
		"encontrar por donde cruzar es un hallazgo, no un paso mas")


func test_el_mismo_vado_no_vuelve_a_contar() -> void:
	var sim := _sim_on_fake()
	var person := _en_el_vado(sim)
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION)

	sim.marcha._terrain_speed(person, Vector3(1.0, 0.0, 0.0), 1.0)
	var after_first := person.skill_in(task)
	sim.marcha._terrain_speed(person, Vector3(1.0, 0.0, 0.0), 1.0)

	assert_eq(person.skill_in(task), after_first,
		"un vado ya conocido no es un hallazgo la segunda vez")


func test_la_batida_no_se_lleva_el_hito_del_vado() -> void:
	# La batida es radio corto: si topa con agua no es porque haya abierto un
	# cruce nuevo, y no tiene sentido premiarla como si lo fuera
	var sim := _sim_on_fake()
	var person := _en_el_vado(sim)
	person.current_speciality = Profession.Speciality.BATIDA
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.EXPEDICION)
	var before := person.skill_in(task)

	sim.marcha._terrain_speed(person, Vector3(1.0, 0.0, 0.0), 1.0)

	assert_eq(person.skill_in(task), before,
		"una batida de paso no aprende de expedicion por cruzar agua")
	assert_false(sim._known_fords.has(sim._ford_key(person.position)),
		"y el vado ni siquiera queda registrado por una batida de paso")


func test_saber_nadar_cruza_la_marisma_mas_rapido() -> void:
	var sim := _sim_on_fake()
	var seco := _en_el_vado(sim)
	var nadador := _en_el_vado(sim)
	nadador.traits[Inhabitant.Trait.NATACION] = 1.0
	seco.traits[Inhabitant.Trait.NATACION] = 0.0

	var speed_seco := sim.marcha._terrain_speed(seco, Vector3(1.0, 0.0, 0.0))
	var speed_nadador := sim.marcha._terrain_speed(nadador, Vector3(1.0, 0.0, 0.0))

	assert_gt(speed_nadador, speed_seco, "quien nada cruza el vado mejor que quien no")


# ------------------------------- ascension: coronar siempre es hito nuevo -

func test_coronar_sube_la_destreza_mas_que_solo_intentarlo() -> void:
	# `_already_climbed` saca del reparto cualquier pico ya coronado, asi que
	# CORONAR es siempre abrir uno nuevo: tiene que dejar mas poso que un
	# intento que se queda en nada. El exito no esta garantizado ni con
	# mucha pericia -Ascent.chance tope en 0,97-, asi que la prueba mira el
	# desenlace de verdad en vez de asumir que corona.
	var sim := _sim_on_peaks()
	# La mas suave de las tres, para que la tirada de verdad tenga que fallar
	# mucho para no coronar
	var summit: Vector3 = sim.cumbres._find_peaks()[-1]["pos"]
	var person := Inhabitant.create(0, summit, sim._rng)
	person.job = Profession.Job.EXPLORACION
	person.current_speciality = Profession.Speciality.ASCENSION
	person.position = summit
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	# A medio camino y no cerca del 0,95: con antes 0,9 el hito se comia el
	# techo y la prueba no podia distinguir "solo practica" de "practica mas
	# hito" -los dos acababan clavados en el mismo tope.
	person.skill[task] = 0.5
	person.fatigue = 0.0
	var before := person.skill_in(task)
	var ascents_before := sim.cumbres.ascents

	sim.cumbres._try_ascent(person)

	var practice: float = 0.035 * person.learn_rate()
	if sim.cumbres.ascents > ascents_before:
		assert_near(person.skill_in(task) - before,
			practice + SettlementSim.PEAK_MILESTONE * person.learn_rate(), 0.001,
			"al coronar, la subida suma la practica Y el hito de la cumbre nueva")
	else:
		assert_near(person.skill_in(task) - before, practice, 0.001,
			"si no corona, solo cuenta la practica del intento")


func test_coronar_revela_familiaridad_no_solo_niebla_de_guerra() -> void:
	# Peticion explicita: la ascension tiene que ver parajes MAS LEJOS Y MAS
	# DISPERSO, no solo destapar mapa. Antes `_do_ascent` solo llamaba a
	# `see_from` -niebla de guerra, la variable `explored`- y nunca tocaba
	# `familiarity`, asi que ningun paraje lejano nacia nunca de subir a un
	# pico por muy claro que se viera el valle desde arriba.
	var sim := _sim_on_fake()
	sim.field = ResourceField.new()
	sim.field.setup(32, 32, Vector2(2048.0, 2048.0))
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(32, 32, Vector2(2048.0, 2048.0))

	var cima := Vector3(1024.0, 200.0, 1024.0)
	# `_do_ascent` siempre llama a `see_from` justo antes: sin niebla ya
	# levantada, ninguna celda pasa el corte de claridad y no hay nada que
	# revelar. Se replica el mismo orden aqui.
	sim.knowledge.see_from(cima, Cumbres.ASCENT_SIGHT_RANGE)
	sim.cumbres._reveal_from_summit(cima)

	assert_gt(sim.knowledge.familiarity_at(Subsistence.Activity.RECOLECCION, cima),
		BandKnowledge.KNOWN_ENOUGH,
		"justo bajo el pico, con la vista mas clara, ya se conoce")
	assert_gt(sim.knowledge.familiarity_at(Subsistence.Activity.MATERIA_PRIMA, cima),
		BandKnowledge.KNOWN_ENOUGH,
		"y de mas de una actividad a la vez -mas disperso, no solo un sitio")

	var lejos := cima + Vector3(Cumbres.ASCENT_SIGHT_RANGE + 200.0, 0.0, 0.0)
	assert_eq(sim.knowledge.familiarity_at(Subsistence.Activity.RECOLECCION, lejos), 0.0,
		"mas alla del alcance de vista desde el pico, no se conoce nada")


# ------------- la batida es individual: dos no van al mismo paraje --------

func test_un_paraje_ya_batido_no_se_vuelve_a_elegir() -> void:
	# El primero YA esta reconociendo -su target se ha ido de paseo a un
	# tramo lejano, como pasa de verdad tras la primera pierna de la
	# batida-. El segundo no tiene que elegir el mismo paraje.
	var sim := _sim_on_fake()
	var paraje := _paraje_con_incognitas(sim, 3)
	var primero := _batidor(sim, paraje, 0.3)
	primero.state = Inhabitant.State.RECONOCIENDO
	primero.work_centre = paraje.position
	# El tramo actual, lejos del paraje pero dentro de SURVEY_RADIUS
	primero.target = paraje.position + Vector3(200.0, 0.0, 0.0)
	sim.people = [primero]

	var segundo := Inhabitant.create(1, sim.home_position, sim._rng)
	segundo.job = Profession.Job.EXPLORACION
	segundo.current_speciality = Profession.Speciality.BATIDA
	sim.people = [primero, segundo]

	assert_eq(sim._paraje_to_survey(segundo), null,
		"el paraje ya esta ocupado, aunque el target del primero se haya alejado")


func test_libre_otra_vez_si_el_primero_ya_no_esta_alli() -> void:
	var sim := _sim_on_fake()
	var paraje := _paraje_con_incognitas(sim, 3)
	var lejos := Inhabitant.create(0, sim.home_position, sim._rng)
	lejos.job = Profession.Job.EXPLORACION
	lejos.current_speciality = Profession.Speciality.BATIDA
	lejos.state = Inhabitant.State.VOLVIENDO
	lejos.target = sim.home_position

	var segundo := Inhabitant.create(1, sim.home_position, sim._rng)
	segundo.job = Profession.Job.EXPLORACION
	segundo.current_speciality = Profession.Speciality.BATIDA
	sim.people = [lejos, segundo]

	assert_eq(sim._paraje_to_survey(segundo), paraje,
		"libre en cuanto el primero ya no esta trabajando alli")
