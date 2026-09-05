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


func test_la_celda_se_mira_por_dentro_y_no_solo_en_el_centro() -> void:
	# Es el fallo que mandaba a la gente al rio: con una sola muestra, un
	# cauce que pasa entre dos centros de celda no existe para el A*
	assert_true(Navgrid.PROBES.size() >= 5, "varias muestras por celda")
	var centres := 0
	for probe: Vector2 in Navgrid.PROBES:
		if probe == Vector2.ZERO:
			centres += 1
		assert_true(absf(probe.x) < 0.5 and absf(probe.y) < 0.5,
			"la muestra %s cae dentro de su celda" % probe)
	assert_eq(centres, 1, "y una de ellas es el centro")


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
