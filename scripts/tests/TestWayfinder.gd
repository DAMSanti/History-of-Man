class_name TestWayfinder
extends TestCase
## Pruebas del trazado de caminos.
##
## Lo que hay que asegurar es que el coste no sea la distancia sino la
## distancia POR lo que arriesga: un canchal empinado tiene que costar mucho
## mas que un pasto llano, o el camino seguira cruzandolo por en medio, que es
## donde la gente se rompe un tobillo.


var _grid: Navgrid = null


func suite_name() -> String:
	return "Caminos"


## La comarca de mentira, medida una vez para todas las pruebas del fichero.
func _fake_grid() -> Navgrid:
	if _grid == null:
		_grid = Navgrid.from_terrain(FakeTerrain.new(), false, false)
	return _grid


# ------------------------------------------------------- lo que se mide --

func test_el_canchal_cuesta_mas_que_el_pasto() -> void:
	# Es la razon de ser del fichero: si costaran igual, se iria en recta
	var flat := Traversal.classify_ground(0.05, 0.0)
	var scree := Traversal.classify_ground(0.9, 0.0)
	assert_eq(flat, Traversal.Ground.PASTO, "poca pendiente es pasto")
	assert_eq(scree, Traversal.Ground.CANCHAL, "mucha, canchal")


func test_el_peso_del_riesgo_no_es_cero_ni_absurdo() -> void:
	# Con 0 se va en linea recta y no sirve de nada; con mucho se dan rodeos
	# ridiculos por evitar una piedra
	assert_true(Navgrid.RISK_WEIGHT > 1.0, "el riesgo pesa de verdad")
	assert_true(Navgrid.RISK_WEIGHT < 8.0, "pero no hasta lo absurdo")


func test_el_agua_pesa_aunque_se_pueda_vadear() -> void:
	# Que un cauce sea vadeable no quiere decir que apetezca: moja la carga y
	# arrastra, y se rodea siempre que haya por donde
	assert_true(Navgrid.WATER_WEIGHT > 1.5,
		"meterse en el rio cuesta de verdad")


func test_la_rejilla_es_lo_bastante_fina_y_lo_bastante_gruesa() -> void:
	# Cuarenta metros. A ochenta el planificador NO VEIA los barrancos: se
	# muestreaba un punto por celda y una vaguada de treinta metros cabe
	# entera entre dos muestras, asi que tiraba por ella.
	assert_true(Navgrid.CELL >= 20.0, "no tan fina que no acabe")
	assert_true(Navgrid.CELL <= 80.0, "ni tan gruesa que no rodee nada")
	var cells := int(4096.0 / Navgrid.CELL)
	assert_true(cells * cells < Wayfinder.MAX_NODES * 2,
		"el mapa entero cabe en el presupuesto de busqueda")


func test_la_celda_se_mira_entera_esquinas_incluidas() -> void:
	# Es el fallo que mandaba a la gente al rio: con una sola muestra, un
	# cauce que pasa entre dos centros de celda no existe para el A*.
	#
	# Y las muestras llegan HASTA EL BORDE, no sólo al cuadrado interior.
	# Estaban a ±0,34 de celda, o sea que las cuatro esquinas no se miraban
	# nunca, y las esquinas es donde acaba la gente: medido en el sitio 56, la
	# rejilla daba por pisables puntos de pendiente 1,85 con el limite de
	# escalada en 1,20.
	assert_true(Navgrid.PROBES.size() >= 9, "las nueve del tres en raya")
	var centres := 0
	var corners := 0
	for probe: Vector2 in Navgrid.PROBES:
		if probe == Vector2.ZERO:
			centres += 1
		if absf(probe.x) == 0.5 and absf(probe.y) == 0.5:
			corners += 1
		assert_true(absf(probe.x) <= 0.5 and absf(probe.y) <= 0.5,
			"la muestra %s no se sale de su celda" % probe)
	assert_eq(centres, 1, "una de ellas es el centro")
	assert_eq(corners, 4, "y las cuatro esquinas se miran")


func test_el_mal_paso_de_la_celda_encarece_la_celda() -> void:
	# Ni el promedio pelado -que se come los barrancos- ni el peor punto -que
	# haria intransitable media comarca-
	assert_true(Navgrid.WORST_BIAS > 0.3, "el mal paso se nota")
	assert_true(Navgrid.WORST_BIAS < 1.0, "pero no manda del todo")


# ---------------------------------------------------- la rejilla, hecha --

func test_la_rejilla_marca_lo_que_no_se_pisa() -> void:
	var grid := _fake_grid()
	assert_true(grid.is_ready(), "la rejilla se construye")
	assert_false(grid.passable(Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)),
		"por el rio no se anda")
	assert_true(grid.passable(Vector3(700.0, 0.0, 700.0)),
		"por la meseta si")


func test_la_rejilla_separa_lo_que_el_rio_separa() -> void:
	# Es lo que sustituye a la busqueda exhaustiva. Si esto se equivoca, el
	# juego declara imposible medio mapa.
	var grid := _fake_grid()
	assert_true(grid.areas >= 2,
		"el rio parte la comarca en %d zonas" % grid.areas)
	assert_false(grid.connected(Vector3(700.0, 0.0, 700.0),
		Vector3(700.0, 0.0, 1900.0)), "de un lado al otro del rio, no")
	assert_true(grid.connected(Vector3(700.0, 0.0, 700.0),
		Vector3(1350.0, 0.0, 700.0)),
		"y de un lado al otro del barranco, si: hay paso al norte")


func test_un_destino_en_el_agua_se_corrige_a_la_orilla() -> void:
	# El jugador senala a ojo, y a ojo se senala el cauce. Tratar un clic
	# aproximado como una orden imposible es culparle del pulso.
	var grid := _fake_grid()
	var wet := Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)
	var dry := grid.nearest_open(wet)
	assert_true(dry >= 0, "hay orilla cerca")
	assert_true(grid.cost[dry] > Navgrid.BLOCKED, "y se pisa")


# ------------------------------------------------------------ el camino --

func test_sin_rejilla_devuelve_la_recta() -> void:
	# Nunca puede devolver vacio por no tener mapa: la gente se quedaria parada
	var route := Wayfinder.find(null, Vector3.ZERO, Vector3(500, 0, 500))
	assert_eq(route.size(), 1, "un solo punto")
	assert_eq(route[0], Vector3(500, 0, 500), "y es el destino")


func test_un_trayecto_corto_no_gasta_rejilla() -> void:
	# Ir a la mata de al lado no necesita A*
	var route := Wayfinder.find(_fake_grid(), Vector3(700, 0, 700),
		Vector3(730, 0, 700))
	assert_eq(route.size(), 1, "derecho")


func test_rodea_el_barranco_por_el_paso() -> void:
	# La queja literal: prefiere ir por barrancos a recorrer un poco mas de
	# camino. Con celda de ochenta metros y una sola muestra, un barranco de
	# treinta no existia para el planificador.
	var route := Wayfinder.find(_fake_grid(), Vector3(700.0, 0.0, 700.0),
		Vector3(1350.0, 0.0, 700.0))
	assert_true(route.size() > 0, "hay camino: el paso esta al norte")

	for point: Vector3 in route:
		assert_false(FakeTerrain.in_gorge(point),
			"el camino no pisa el barranco en %s" % point)

	# Donde cruza se INTERPOLA sobre el tramo, no se toma del hito siguiente.
	# Al recortar los dientes de sierra los hitos quedan lejos unos de otros,
	# asi que el hito de despues del barranco puede estar a cuatrocientos
	# metros del sitio por el que de verdad se cruzo.
	var crossed_at := -1000.0
	var previous := Vector3(700.0, 0.0, 700.0)
	for point: Vector3 in route:
		var before := previous.x - FakeTerrain.GORGE_X
		var after := point.x - FakeTerrain.GORGE_X
		if before * after <= 0.0 and not is_equal_approx(before, after):
			var t := before / (before - after)
			crossed_at = lerpf(previous.z, point.z, t)
		previous = point
	assert_lt(absf(crossed_at - FakeTerrain.GORGE_GAP_Z), 160.0,
		"cruza por el paso (z=%d, el paso esta en %d)"
			% [int(crossed_at), int(FakeTerrain.GORGE_GAP_Z)])


func test_el_rodeo_no_es_absurdo() -> void:
	# Rodear si, pero no dar la vuelta a la comarca
	var from_point := Vector3(700.0, 0.0, 700.0)
	var route := Wayfinder.find(_fake_grid(), from_point,
		Vector3(1350.0, 0.0, 700.0))

	var length := 0.0
	var previous := from_point
	for point: Vector3 in route:
		length += Vector2(point.x - previous.x, point.z - previous.z).length()
		previous = point
	assert_lt(length, 2600.0, "rodea lo justo (%d m)" % int(length))


func test_no_sale_andando_hacia_un_rio_que_no_se_cruza() -> void:
	# Es la queja tal cual. Devolver la recta al fallar era lo que la provocaba.
	var route := Wayfinder.find(_fake_grid(), Vector3(700.0, 0.0, 700.0),
		Vector3(700.0, 0.0, 1900.0))
	assert_eq(route.size(), 0, "dice que no hay camino, no una recta al rio")


func test_saber_que_no_hay_camino_ya_no_cuesta_una_busqueda() -> void:
	# Era lo mas caro del juego: para decir que NO se llega habia que agotar
	# los doce mil nodos. Con las zonas marcadas de antemano, cero.
	var _route := Wayfinder.find(_fake_grid(), Vector3(700.0, 0.0, 700.0),
		Vector3(700.0, 0.0, 1900.0))
	assert_eq(Wayfinder.last_nodes, 0,
		"no se ha buscado nada: se sabia de antemano")


func test_un_camino_facil_sale_barato() -> void:
	var route := Wayfinder.find(_fake_grid(), Vector3(300.0, 0.0, 700.0),
		Vector3(900.0, 0.0, 700.0))
	assert_true(route.size() > 0, "hay camino, no hay nada en medio")
	assert_lt(float(Wayfinder.last_nodes), 400.0,
		"y sale barato (%d nodos)" % Wayfinder.last_nodes)


func test_el_camino_no_sale_en_dientes_de_sierra() -> void:
	# Un A* de ocho direcciones solo anda en multiplos de 45 grados, asi que
	# un trayecto casi recto le sale en escalera: se ve fatal y hace andar de
	# mas. Se recorta tirando del hilo.
	var route := Wayfinder.find(_fake_grid(), Vector3(300.0, 0.0, 700.0),
		Vector3(900.0, 0.0, 740.0))
	assert_true(route.size() > 0, "hay camino")
	assert_lt(float(route.size()), 6.0,
		"seiscientos metros de llano son %d hitos, no quince" % route.size())


func test_el_recorte_no_deshace_el_rodeo() -> void:
	# Tirar del hilo tiene que quitar dientes de sierra, NO atajar por el
	# barranco: si recortara mirando la distancia y no lo transitable,
	# desharia justo el rodeo que costo encontrar
	var route := Wayfinder.find(_fake_grid(), Vector3(700.0, 0.0, 700.0),
		Vector3(1350.0, 0.0, 700.0))
	for point: Vector3 in route:
		assert_false(FakeTerrain.in_gorge(point),
			"el recorte no mete el camino en el barranco")


# ------------------------------------------------------------ el heap ----

func test_el_monticulo_saca_siempre_el_mas_barato() -> void:
	# Es codigo nuevo, y un monticulo mal hecho no casca: devuelve caminos
	# malos en silencio, que es peor
	var heap := Wayfinder._Heap.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var costs: Array[float] = []
	for i in range(200):
		var cost := rng.randf_range(0.0, 1000.0)
		costs.append(cost)
		heap.push(i, cost)

	var last := -INF
	var taken := 0
	while not heap.is_empty():
		var node := heap.pop()
		var cost: float = costs[node]
		assert_true(cost >= last,
			"sale %f despues de %f, en orden" % [cost, last])
		last = cost
		taken += 1
	assert_eq(taken, 200, "salen todos los que entraron")


func test_el_monticulo_aguanta_empujar_y_sacar_mezclados() -> void:
	# Que es como lo usa el A*: se empuja mientras se saca
	var heap := Wayfinder._Heap.new()
	heap.push(1, 5.0)
	heap.push(2, 3.0)
	assert_eq(heap.pop(), 2, "el mas barato de los dos")
	heap.push(3, 1.0)
	heap.push(4, 9.0)
	assert_eq(heap.pop(), 3, "el nuevo, que es mas barato")
	assert_eq(heap.pop(), 1, "el que quedaba de antes")
	assert_eq(heap.pop(), 4, "y el caro al final")
	assert_true(heap.is_empty(), "no queda nada")


func test_un_campamento_a_la_orilla_no_deja_encerrada_a_la_banda() -> void:
	# El fallo que dejaba a los exploradores dando vueltas a veinte metros de
	# casa. La celda mide cuarenta metros y basta con que la roce el rio para
	# que quede cerrada; los abrigos estan junto al agua, porque para eso se
	# eligen. Con el campamento en celda cerrada su zona era «ninguna», y
	# «ninguna» no coincide con nada.
	var grid := _fake_grid()

	# Justo en el cauce: la peor colocacion posible
	var camp := Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)
	assert_false(grid.passable(camp), "la celda del campamento esta cerrada")

	assert_true(grid.connected(camp, Vector3(700.0, 0.0, 700.0)),
		"y aun asi se llega al valle de este lado")

	var route := Wayfinder.find(grid, camp, Vector3(1000.0, 0.0, 600.0))
	assert_true(route.size() > 0, "y se le puede trazar camino")


func test_una_pena_suelta_no_cierra_la_celda() -> void:
	# El agua es barrera y la pendiente es precio. Confundirlas troceaba la
	# comarca en islas: una pena de quince metros en mitad de un puerto
	# perfectamente andable cerraba los cuarenta enteros.
	var terrain := RuggedTerrain.new()
	terrain.roughness = 0.15
	var grid := Navgrid.from_terrain(terrain, false, false)

	assert_eq(grid.areas, 1,
		"una comarca sin agua ni cortados es UNA sola zona, no %d" % grid.areas)
	assert_gt(grid.open_fraction(), 0.95,
		"y se anda entera (%.0f%%)" % (grid.open_fraction() * 100.0))


# ------------------------------------------- cada uno por su carril ------
#
# El reparto de `SettlementSim._best_known_spot` separa el TAJO, no el camino.
# El trazado de `Wayfinder` es uno solo, así que dos personas con el mismo tramo
# se dibujaban una dentro de otra durante todo el trayecto y sólo se despegaban
# al llegar. El carril es el desvío lateral, estable por persona, que las separa
# mientras andan.

func _andando(id: int, from: Vector3, to: Vector3) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906 + id
	var person := Inhabitant.create(id, from, rng)
	person.position = from
	person.target = to
	return person


func test_dos_personas_del_mismo_tramo_no_van_por_la_misma_linea() -> void:
	var sim := SettlementSim.new()
	var origen := Vector3(400.0, 0.0, 400.0)
	var destino := Vector3(900.0, 0.0, 400.0)
	var rumbo := destino - origen

	var separacion := 0.0
	# Se prueban ids consecutivos porque es el caso real: la banda se crea de
	# corrido y quien sale junto a otro suele llevar el id de al lado.
	for id in range(8):
		var uno := _andando(id, origen, destino)
		var otro := _andando(id + 1, origen, destino)
		var a := sim.marcha._lane_shift(uno, rumbo)
		var b := sim.marcha._lane_shift(otro, rumbo)
		separacion = (a - b).length()
		assert_gt(separacion, 0.6,
			"id %d y %d se separan solo %.2f m" % [id, id + 1, separacion])


func test_el_carril_es_lateral_y_no_alarga_el_camino() -> void:
	var sim := SettlementSim.new()
	var person := _andando(3, Vector3(400.0, 0.0, 400.0), Vector3(900.0, 0.0, 400.0))
	var rumbo := person.target - person.position
	var desviado := sim.marcha._lane_shift(person, rumbo)

	# Lo que se suma tiene que ser perpendicular a la marcha: si tuviera
	# componente en el sentido del camino, el carril adelantaria o frenaria a
	# quien lo lleva y la cuadrilla se estiraria sola.
	var añadido := desviado - rumbo
	assert_lt(absf(añadido.normalized().dot(rumbo.normalized())), 0.01,
		"el desvio es perpendicular a la marcha")
	assert_lt(añadido.length(), SettlementSim.LANE_SPREAD + 0.01,
		"y no se va mas alla del carril")


func test_el_carril_se_deshace_al_llegar() -> void:
	# Si el desvio siguiera vivo en los ultimos metros, nadie tocaria nunca su
	# destino: se quedarian dando vueltas alrededor a dos metros y medio, que
	# es peor que el solape que viene a arreglar.
	var sim := SettlementSim.new()
	var destino := Vector3(900.0, 0.0, 400.0)
	# En el borde mismo de la llegada el desvio ya tiene que ser bastante menor
	# que el radio de llegada, o el destino queda fuera de alcance para siempre.
	for metros: float in [1.0, 3.0, sim.arrive_radius]:
		var person := _andando(3, destino + Vector3(metros, 0.0, 0.0), destino)
		var rumbo := destino - person.position
		var desvio := (sim.marcha._lane_shift(person, rumbo) - rumbo).length()
		assert_lt(desvio, sim.arrive_radius * 0.5,
			"a %.0f m del destino el carril ya no estorba (%.2f m)" % [metros, desvio])


func test_el_carril_no_cambia_de_un_fotograma_a_otro() -> void:
	# Estable por identidad y no sorteado: con un desvio aleatorio por
	# fotograma la persona no se separa, tiembla.
	var sim := SettlementSim.new()
	var person := _andando(5, Vector3(400.0, 0.0, 400.0), Vector3(900.0, 0.0, 400.0))
	var rumbo := person.target - person.position
	var primero := sim.marcha._lane_shift(person, rumbo)
	for _i in range(10):
		assert_eq(sim.marcha._lane_shift(person, rumbo), primero,
			"el carril es el mismo mientras no se mueva")


# --- no avanzar no puede durar para siempre ------------------------------
#
# La caza menor cerraba el 81 % de sus salidas con «atascado: no avanza por el
# camino trazado» -medido con semilla fija-, y no era el camino: era que en un
# cortado el paso se quedaba en el 2 % de lo normal y que replanificar contra
# la misma pared devuelve la misma ruta imposible.

func test_nadie_anda_a_velocidad_cero() -> void:
	# Tobler por el suelo por la carga puede bajar al 2 %, y a ese paso
	# cincuenta metros son media jornada: desde fuera no se distingue de estar
	# parado, y la vigilancia de atascos lo da por plantado con razon.
	assert_gt(SettlementSim.MIN_PACE, 0.05,
		"hay un suelo de paso: lento no es parado")
	assert_lt(SettlementSim.MIN_PACE, 0.35,
		"pero sigue siendo mucho mas lento que el llano")


func test_se_deja_de_insistir_contra_la_misma_pared() -> void:
	assert_gt(float(SettlementSim.BLOCKED_REPLANS), 1.0,
		"un roce con la orilla lo arregla el esquive: no se abandona a la primera")
	assert_lt(float(SettlementSim.BLOCKED_REPLANS), 8.0,
		"ni se pasa la tarde intentandolo")


func test_acercarse_reinicia_el_reloj_de_atasco() -> void:
	# El fallo original: al acercarse a menos de arrive_radius*1,5 del tajo el
	# reloj dejaba de reiniciarse aunque la persona siguiera andando, y a las
	# dos horas se la daba por enganchada -medido, 72 atascos en tres jornadas
	# sin que nadie estuviera parado.
	#
	# La vara pasó de MOVERSE a ACERCARSE, y por un motivo: moverse doce metros
	# reiniciaba el reloj, y eso deja fuera el atasco más aparatoso que hay
	# —quien camina la orilla de un río de un lado a otro buscando por dónde
	# pasar—. Se mueve muchísimo y no se acerca nada.
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260907
	var person := Inhabitant.create(0, Vector3(700.0, 200.0, 700.0), rng)
	person.state = Inhabitant.State.YENDO
	person.target = Vector3(704.0, 200.0, 700.0)
	person.position = Vector3(700.0, 200.0, 700.0)
	person.stuck_where = person.position
	person.stuck_hours = 0.0
	sim.people = [person]

	# Lejos y acercandose: el reloj se reinicia por mucho que siga sin llegar.
	person.target = Vector3(900.0, 200.0, 700.0)
	person.lo_mas_cerca = 200.0
	person.stuck_hours = 1.5
	person.position = Vector3(760.0, 200.0, 700.0)
	sim.marcha._watch_for_stuck(person, 1.0)
	assert_eq(person.stuck_hours, 0.0,
		"quien se ha acercado cuarenta metros no esta atascado")

	# Y quien anda mucho SIN acercarse -la orilla del rio- si lo esta.
	person.lo_mas_cerca = 140.0
	person.stuck_hours = 0.0
	person.position = Vector3(760.0, 200.0, 780.0)
	sim.marcha._watch_for_stuck(person, 1.0)
	assert_gt(person.stuck_hours, 0.0,
		"andar la orilla sin acercarse SI cuenta como atasco")


func test_quien_llega_y_no_se_mueve_si_se_detecta() -> void:
	# La otra mitad: el caso que la condicion mala venia a resolver tiene que
	# seguir saliendo por su rama.
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var person := Inhabitant.create(0, Vector3(700.0, 200.0, 700.0), rng)
	person.state = Inhabitant.State.YENDO
	person.position = Vector3(700.0, 200.0, 700.0)
	person.target = person.position
	person.stuck_where = person.position
	sim.people = [person]

	sim.marcha._watch_for_stuck(person, SettlementSim.STUCK_HOURS + 0.1)
	assert_eq(person.state, Inhabitant.State.OCIOSO,
		"llego y el estado se ha soltado solo")


# --- las esquinas no se cortan -------------------------------------------
#
# El A* encadena centros de celda y la persona anda en LÍNEA RECTA de uno a
# otro. Con la diagonal libre, el camino podía colarse por el vértice entre dos
# celdas cerradas -un paso de anchura cero- y quien lo seguía se metía de frente
# en una de ellas. Era el atasco de verdad: 81 % de las salidas de caza menor
# cerradas con «atascado», medido con semilla fija.

func test_el_atajo_de_cerca_mira_lo_que_hay_en_medio() -> void:
	# El atasco grande: cualquier destino a menos de sesenta metros se resolvia
	# con una recta SIN MIRAR el terreno de en medio, asi que bastaba un
	# cortado entre la persona y su tajo para que la «ruta» fuera un unico
	# punto al otro lado de una pared.
	var grid := Navgrid.new()
	grid.wide = 3
	grid.tall = 1
	grid.world = Vector2(3.0, 1.0) * Navgrid.CELL
	grid.cost.resize(3)
	grid.area.resize(3)
	for i in range(3):
		grid.cost[i] = 1.0
	grid.cost[1] = Navgrid.BLOCKED
	grid._flood_areas()

	# Cincuenta y cinco metros, o sea dentro del atajo, con la celda de en
	# medio cerrada.
	var from := Vector3(10.0, 0.0, 20.0)
	var to := Vector3(65.0, 0.0, 20.0)
	assert_lt(Vector2(to.x - from.x, to.z - from.z).length(),
		Navgrid.CELL * 1.5, "el destino cae dentro del atajo")

	var route := Wayfinder.find(grid, from, to)
	assert_false(route.size() == 1 and route[0].distance_to(to) < 1.0,
		"no se manda a nadie derecho a traves de una celda cerrada")


func test_el_atajo_de_cerca_sigue_valiendo_con_el_paso_libre() -> void:
	# El arreglo no puede cargarse el atajo: sin el, cada paseo de treinta
	# metros lanzaria una busqueda entera.
	var grid := Navgrid.new()
	grid.wide = 3
	grid.tall = 1
	grid.world = Vector2(3.0, 1.0) * Navgrid.CELL
	grid.cost.resize(3)
	grid.area.resize(3)
	for i in range(3):
		grid.cost[i] = 1.0
	grid._flood_areas()

	var to := Vector3(65.0, 0.0, 20.0)
	var route := Wayfinder.find(grid, Vector3(10.0, 0.0, 20.0), to)
	assert_eq(route.size(), 1, "con el paso libre se va derecho")


func test_la_diagonal_libre_si_vale() -> void:
	# El arreglo no puede cerrar las diagonales buenas: sin ellas los caminos
	# salen en escalera y se andan un 40 % mas de metros.
	var grid := Navgrid.new()
	grid.wide = 3
	grid.tall = 3
	grid.world = Vector2(3.0, 3.0) * Navgrid.CELL
	grid.cost.resize(9)
	grid.area.resize(9)
	for i in range(9):
		grid.cost[i] = 1.0
	grid._flood_areas()

	var route := Wayfinder.find(grid, grid.point_of(0), grid.point_of(1 * 3 + 1))
	assert_false(route.is_empty(), "con todo abierto hay camino")


# --- el agua se juzga por el vado, no por lo hondo -----------------------
#
# Una pared que cruza la celda la cierra: se mire por donde se mire, por ahi no
# se sube. Un rio NO: se cruza POR EL VADO. Midiendolo con la muestra mas honda
# se cerraba el cauce entero -vados incluidos- y en el sitio 56 eso dejaba un
# tercio del valle incomunicado del abrigo para toda la partida.

func _fords(values: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(Navgrid.PROBES.size())
	for i in range(mini(values.size(), out.size())):
		out[i] = float(values[i])
	return out


func test_una_linea_vadeable_abre_la_celda() -> void:
	# Fila de en medio -indices 3,4,5- somera de lado a lado.
	# Hondo es por encima de FORD_IMPASSABLE, que es donde `can_cross` dice que
	# no: FORD_WADEABLE es sólo donde se deja de cruzar sin mojarse.
	var shallow := Hydrography.FORD_WADEABLE * 0.5
	var deep := Hydrography.FORD_IMPASSABLE + 0.2
	var fords := _fords([deep, deep, deep, shallow, shallow, shallow,
		deep, deep, deep])
	assert_true(Navgrid._has_ford(fords, false, false),
		"si se cruza de lado a lado por la fila de en medio, hay paso")


func test_un_charco_suelto_no_abre_la_celda() -> void:
	# Un unico punto somero en una esquina no es un vado: cruzar por ahi seria
	# meterse en lo hondo dos pasos despues.
	var shallow := Hydrography.FORD_WADEABLE * 0.5
	var deep := Hydrography.FORD_IMPASSABLE + 0.2
	var fords := _fords([shallow, deep, deep, deep, deep, deep,
		deep, deep, deep])
	assert_false(Navgrid._has_ford(fords, false, false),
		"un punto somero suelto no es por donde se cruza")


func test_el_cauce_hondo_sigue_cerrado() -> void:
	var deep := Hydrography.FORD_IMPASSABLE + 0.2
	var fords := _fords([deep, deep, deep, deep, deep, deep, deep, deep, deep])
	assert_false(Navgrid._has_ford(fords, false, false),
		"un rio que no se vadea sigue siendo una pared")


# --- las zonas y el buscador tienen que decir lo mismo -------------------

func test_las_zonas_no_se_unen_por_el_vertice() -> void:
	# Si la inundacion de zonas une dos trozos por el vertice entre dos celdas
	# cerradas y el buscador no lo cruza, `connected` miente: dice que si hay
	# camino, la busqueda vuelve vacia, y la persona se queda «sin camino
	# trazado» sobre un sitio que la rejilla juraba alcanzable.
	var grid := Navgrid.new()
	grid.wide = 2
	grid.tall = 2
	grid.world = Vector2(2.0, 2.0) * Navgrid.CELL
	grid.cost.resize(4)
	grid.area.resize(4)
	grid.cost[0] = 1.0
	grid.cost[1] = Navgrid.BLOCKED
	grid.cost[2] = Navgrid.BLOCKED
	grid.cost[3] = 1.0
	grid._flood_areas()

	assert_eq(grid.areas, 2,
		"las dos abiertas se tocan solo por el vertice: son dos zonas")
	assert_false(grid.connected(grid.point_of(0), grid.point_of(3)),
		"y no se llega de una a otra")

# --- llegar a casa -------------------------------------------------------
#
# El camino de vuelta lo traza la rejilla, y la rejilla no deja a nadie mas
# cerca que su celda: la ruta se acaba legitimamente a veinte metros de la
# boca. Preguntando por seis metros al punto del abrigo, quien volvia se
# plantaba ahi y no entregaba, no cenaba y no dormia, y a la mañana siguiente
# perdia la carga entera. Medido antes de arreglarlo, sitio 56, ocho jornadas:
# 264 horas-persona de pie en la puerta y el 85 % de las salidas de
# recoleccion cerradas como «volvio de vacio»; despues, 16 %.

func test_con_camino_por_delante_todavia_no_se_ha_llegado() -> void:
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.position = Vector3(Navgrid.CELL * 0.5, 0.0, 0.0)
	person.route = PackedVector3Array([Vector3.ZERO])
	person.route_step = 0
	assert_false(sim._home_reached(person),
		"con hitos sin pisar se sigue volviendo")


func test_sin_camino_y_a_una_celda_de_la_boca_se_ha_llegado() -> void:
	# Es el caso que dejaba a la banda en la puerta: no queda ruta que andar,
	# asi que esperar a pisar el punto exacto es esperar para siempre.
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.position = Vector3(Navgrid.CELL * 0.5, 0.0, 0.0)
	person.route = PackedVector3Array()
	person.route_step = 0
	assert_true(sim._home_reached(person),
		"agotado el camino y a media celda, se ha llegado")


func test_lejos_de_casa_no_se_ha_llegado_aunque_no_quede_camino() -> void:
	# La otra mitad: quedarse sin ruta en mitad del monte no es estar en casa.
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.position = Vector3(Navgrid.CELL * 4.0, 0.0, 0.0)
	person.route = PackedVector3Array()
	person.route_step = 0
	assert_false(sim._home_reached(person),
		"a cuatro celdas no se ha llegado a ninguna parte")


# --- el hogar y el taller trabajan ---------------------------------------
#
# Los dos oficios que no salen del abrigo hacian su jornada desde OCIOSO, asi
# que la banda figuraba parada media jornada sin estarlo: el 39,6 % de las
# horas de luz salia como ocio y de ese ocio el 17,2 % era el hogar y el
# 16,0 % el taller.

func test_el_hogar_y_el_taller_cuentan_como_trabajo() -> void:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for job: Profession.Job in [Profession.Job.HOGAR,
		Profession.Job.MANUFACTURA]:
		var person := Inhabitant.create(0, Vector3.ZERO, rng)
		person.job = job
		assert_true(sim.hogar._works_at_camp(person),
			"%s trabaja en el abrigo" % Profession.job_name(job))


func test_el_de_monte_no_trabaja_en_el_abrigo() -> void:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for job: Profession.Job in [Profession.Job.RECOLECCION,
		Profession.Job.CAZA, Profession.Job.RIBERA,
		Profession.Job.EXPLORACION]:
		var person := Inhabitant.create(0, Vector3.ZERO, rng)
		person.job = job
		assert_false(sim.hogar._works_at_camp(person),
			"%s tiene su tajo fuera" % Profession.job_name(job))


func test_el_taller_no_se_echa_a_andar_al_destino_viejo() -> void:
	# TRABAJANDO es uno de los estados que ANDAN. Al pasar el taller a ese
	# estado habia que pararle el paso, o se iria al tajo del oficio anterior.
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.MANUFACTURA
	person.position = Vector3(10.0, 0.0, 10.0)
	person.target = Vector3(900.0, 0.0, 900.0)
	person.route = PackedVector3Array([person.target])
	person.route_step = 0
	sim.hogar._camp_work(person, 0.0)
	assert_eq(person.target, person.position, "se le para el paso")
	assert_eq(person.route.size(), 0, "y se le tira el camino viejo")

func test_el_abrigo_llega_hasta_donde_se_reparte_la_gente() -> void:
	# La averia de origen, en una linea: el radio de llegada son seis metros y
	# la gente en casa se reparte por la campa hasta dieciocho -medido en el
	# sitio 56: la campa a 11,3 m del punto del abrigo mas 7,0 de reparto-. O
	# sea que estar en casa caia fuera de haber llegado a casa.
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	sim.home_forecourt = Vector3(11.3, 0.0, 0.0)
	sim.home_inside = Vector3(-6.9, 0.0, 0.0)
	assert_true(sim._shelter_reach() >= 11.3 + SettlementSim.FORECOURT_SPREAD,
		"el abrigo llega hasta el ultimo sitio de la campa")
	assert_true(sim._shelter_reach() >= 6.9 + SettlementSim.CAVE_SPREAD,
		"y hasta el fondo de la galeria")
	assert_true(sim._shelter_reach() > sim.arrive_radius,
		"y desde luego mas alla del radio de llegada")


func test_sin_cueva_marcada_el_abrigo_es_solo_el_reparto() -> void:
	# Sin boca de cueva -las pruebas, un campamento al raso- `_home_spot` sigue
	# repartiendo a la gente alrededor del punto del abrigo, asi que el abrigo
	# llega hasta ahi y ni un metro mas: nada de inventarse cuarenta.
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	assert_true(sim._shelter_reach() >= SettlementSim.FORECOURT_SPREAD,
		"llega hasta donde se reparte la campa")
	assert_true(sim._shelter_reach() < Navgrid.CELL,
		"y no se inventa un abrigo de una celda entera")


# ------------------------------ una rejilla por estacion, y vados que cierran --

func test_la_rejilla_se_mide_al_caudal_que_se_le_diga() -> void:
	# Es lo que permite hornear la del invierno en agosto: se le pasa el rio de
	# enero, no el del dia en que se hornea.
	# `FakeTerrain` tiene el rio binario -1,0 dentro y 0,0 fuera- asi que para
	# que la diferencia sea legible hay que cruzar el umbral de vadeo
	# ([Hydrography.FORD_WADEABLE], 0,35): con un estiaje fuerte el cauce se
	# pasa de piedra en piedra y con la crecida no.
	var terrain := FakeTerrain.new()
	var seca := Navgrid.from_terrain(terrain, false, false, 0.30)
	var crecida := Navgrid.from_terrain(terrain, false, false, 1.55)
	assert_lt(crecida.open_fraction(), seca.open_fraction(),
		"con el rio crecido se anda menos valle que en el estiaje")


func test_un_vado_se_cierra_en_invierno() -> void:
	# La peticion literal: «quiero que haya vados que se vuelven intransitables
	# en algunas temporadas». Con el caudal del invierno tiene que haber celdas
	# que dejan de pasarse.
	var terrain := FakeTerrain.new()
	var verano := Navgrid.from_terrain(terrain, false, false,
		Temporada.CAUDAL[Subsistence.Season.VERANO])
	var invierno := Navgrid.from_terrain(terrain, false, false,
		Temporada.CAUDAL[Subsistence.Season.INVIERNO])
	var cerradas := 0
	for i in range(mini(verano.cost.size(), invierno.cost.size())):
		if verano.cost[i] > Navgrid.BLOCKED and invierno.cost[i] <= Navgrid.BLOCKED:
			cerradas += 1
	assert_gt(float(cerradas), 0.0,
		"con la crecida de enero hay celdas que dejan de pasarse")


func test_hornear_a_trozos_da_la_misma_rejilla_que_de_golpe() -> void:
	# Es la condicion para que amasar en segundo plano no cambie la partida.
	var terrain := FakeTerrain.new()
	var golpe := Navgrid.from_terrain(terrain, false, false, 1.0)
	var trozos := Navgrid.preparar(terrain, false, false, 1.0)
	var vueltas := 0
	while not trozos.amasar(terrain, 1):
		vueltas += 1
		assert_lt(float(vueltas), 10000.0, "el horneado a trozos termina")
	assert_eq(trozos.cost.size(), golpe.cost.size(), "mismo tamaño")
	var iguales := true
	for i in range(golpe.cost.size()):
		if not is_equal_approx(golpe.cost[i], trozos.cost[i]):
			iguales = false
			break
	assert_true(iguales, "y las mismas celdas, celda a celda")
	assert_eq(trozos.areas, golpe.areas, "y las mismas zonas comunicadas")


func test_el_horno_da_la_de_hoy_entera_desde_el_primer_momento() -> void:
	# Sin ella no hay partida: la de hoy se hornea entera al encargar y las
	# otras tres quedan a medias, a la cola.
	var terrain := FakeTerrain.new()
	var horno := HornoDeRejillas.new()
	horno.encargar(terrain, false, false, Subsistence.Season.VERANO,
		Temporada.CAUDAL)
	assert_true(horno.de(Subsistence.Season.VERANO).horneada(),
		"la de hoy esta lista ya")
	assert_eq(horno.pendientes(), 3, "y las otras tres estan a la cola")


func test_mientras_se_hornea_una_se_anda_con_otra() -> void:
	# Nunca se devuelve una a medias: una rejilla sin inundar dice que no hay
	# camino a ninguna parte, y con eso la banda se queda en el abrigo.
	var terrain := FakeTerrain.new()
	var horno := HornoDeRejillas.new()
	horno.encargar(terrain, false, false, Subsistence.Season.VERANO,
		Temporada.CAUDAL)
	var invierno := horno.de(Subsistence.Season.INVIERNO)
	assert_true(invierno.horneada(),
		"pidiendo la del invierno sin estar lista se devuelve una que si lo esta")


func test_la_barca_invalida_las_cuatro() -> void:
	var terrain := FakeTerrain.new()
	var horno := HornoDeRejillas.new()
	horno.encargar(terrain, false, false, Subsistence.Season.VERANO,
		Temporada.CAUDAL)
	assert_true(horno.sirven(false, false), "sirven para lo que se hornearon")
	assert_false(horno.sirven(true, false),
		"con barca cambian los pasos y hay que rehacerlas")


## «Al otro lado del rio» no es lo mismo que «incomunicado».
##
## Queja literal: «uno de los parajes iniciales esta al otro lado del rio, que
## pollas haces». Y estaba comunicado —habia camino— dando la vuelta por un vado
## a kilometro y medio. Estar en la misma zona de la rejilla solo dice que EXISTE
## un camino; lo que hace falta saber es si se anda.
func test_no_basta_con_que_haya_camino_tiene_que_andarse() -> void:
	assert_gt(Marcha.RODEO_QUE_SE_ANDA, 1.0,
		"un valle obliga a rodear: el camino nunca es la linea recta")
	assert_lt(Marcha.RODEO_QUE_SE_ANDA, 4.0,
		"pero dar la vuelta al rio para trabajar lo que se ve desde casa no "
			+ "es rodear, es otro sitio")

	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(500.0, 200.0, 500.0)

	# Al lado de casa se llega siempre, sin buscar nada.
	assert_true(sim.marcha.alcanzable_de_verdad(sim.home_position,
		sim.home_position + Vector3(20.0, 0.0, 0.0)),
		"a la puerta de casa se llega")


## Y una celda que el terreno desmiente se CIERRA, para no repetir el viaje.
##
## Sin esto, la ruta pasaba por un vado que sobre el suelo no existe, la persona
## se plantaba en la orilla, se le daba media vuelta, y al dia siguiente se le
## trazaba la misma ruta por el mismo sitio. Todos los dias y varios a la vez.
func test_una_celda_desmentida_se_cierra() -> void:
	var terrain := FakeTerrain.new()
	var grid := Navgrid.from_terrain(terrain, false, false)
	var seco := Vector3(500.0, 0.0, 500.0)
	assert_true(grid.passable(seco), "la meseta se anda")

	assert_true(grid.cerrar(seco), "se cierra la celda que el terreno desmiente")
	assert_false(grid.passable(seco), "y deja de existir para el trazado")
	assert_false(grid.cerrar(seco), "cerrar lo ya cerrado no hace nada")
	terrain.free()
