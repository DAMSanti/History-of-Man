class_name TestAvistamiento
extends TestCase
## Lo que se ve desde una cima: la línea de vista sobre el relieve regional y las tres
## cumbres que avistan. SISTEMAS §4, spec del 2026-09-15.


func suite_name() -> String:
	return "Avistamiento"


## Un relieve llano de ~8 × 11 km a cota cero, de filas geográficas, en celdas de ~80 m.
func _llano() -> HeightmapData:
	var relieve := HeightmapData.new()
	relieve.width = 101
	relieve.height = 101
	relieve.geographic_rows = true
	relieve.lat_north = 43.1
	relieve.lat_south = 43.0
	relieve.lon_west = -4.1
	relieve.lon_east = -4.0
	relieve.meters_per_sample = 80.0
	relieve.elevations.resize(101 * 101)
	relieve.elevations.fill(0.0)
	return relieve


## Una sierra de norte a sur, de 900 m, en la columna de la longitud dada.
func _con_sierra(relieve: HeightmapData, lon: float) -> void:
	var x := int(round(relieve.u_for_lon(lon) * float(relieve.width - 1)))
	for z in range(relieve.height):
		for ancho in range(-1, 2):
			relieve.elevations[z * relieve.width + x + ancho] = 900.0


func _sitio(id: int, lon: float) -> Site:
	var s := Site.new()
	s.id = id
	s.lon = lon
	s.lat = 43.05
	return s


## Cinco yacimientos al este de la cima, de 0,8 a 6,5 km.
func _cinco() -> Array[Site]:
	var sitios: Array[Site] = []
	var i := 0
	for lon: float in [-4.08, -4.06, -4.04, -4.02, -4.01]:
		sitios.append(_sitio(700 + i, lon))
		i += 1
	return sitios


func test_sin_sierra_se_ven_y_con_sierra_no() -> void:
	var sitios := _cinco()
	var llano := _llano()
	var abiertos := Avistamiento.a_la_vista(-4.09, 43.05, 500.0, sitios, llano)
	var tapado := _llano()
	_con_sierra(tapado, -4.07)
	var con_sierra := Avistamiento.a_la_vista(-4.09, 43.05, 500.0, sitios, tapado)
	assert_eq(abiertos.size(), 5, "sin sierra se ven los cinco")
	assert_eq(con_sierra.size(), 1, "con la sierra delante, sólo el de este lado")
	assert_true(con_sierra.has(sitios[0]), "que es el más cercano, antes de la sierra")


func test_hasta_dos_y_los_mas_lejanos() -> void:
	var sitios := _cinco()
	var vistos := Avistamiento.a_la_vista(-4.09, 43.05, 500.0, sitios, _llano())
	var dos := Avistamiento.los_mas_lejanos(-4.09, 43.05, vistos, 2)
	var uno := Avistamiento.los_mas_lejanos(-4.09, 43.05, [sitios[1]] as Array[Site], 2)
	assert_eq(dos, [sitios[4], sitios[3]] as Array[Site], "de cinco a la vista, los dos más lejanos")
	assert_eq(uno.size(), 1, "y si sólo hay uno, uno")


func test_la_curvatura_esconde_lo_que_toca_a_esa_distancia() -> void:
	# A 50 km, con la refracción de uso en topografía, se esconden unos 170 m.
	assert_near(Avistamiento._escondido(50000.0), 171.0, 3.0, "a 50 km")
	assert_near(Avistamiento._escondido(0.0), 0.0, 0.001, "y nada junto a la cima")


# ------------------------------------------ las tres cumbres más altas --

func _cumbre(x: float, alto: float) -> Dictionary:
	return {"pos": Vector3(x, alto, 0.0), "rise": alto, "command": 100.0, "hard": 0.1}


func test_de_cuatro_cumbres_avistan_las_tres_mas_altas() -> void:
	var cuatro: Array[Dictionary] = [_cumbre(0.0, 700.0), _cumbre(1000.0, 1200.0),
		_cumbre(2000.0, 900.0), _cumbre(3000.0, 1100.0)]
	var altas := Cumbres.las_mas_altas(cuatro, Cumbres.CUMBRES_QUE_AVISTAN)
	assert_eq(altas.size(), 3, "tres")
	assert_false(altas.has(Vector3(0.0, 700.0, 0.0)), "la cuarta, la más baja, no avista")
	assert_eq(altas[0], Vector3(1000.0, 1200.0, 0.0), "y la primera es la más alta")


func test_coronar_no_cambia_cuales_son_las_tres_mas_altas() -> void:
	# La lista de adónde subir quita las coronadas; la de las que avistan, no. Si se
	# quitaran, al coronar la tercera entraría la cuarta.
	var sim := SettlementSim.new()
	sim._terrain = PeakTerrain.new()
	sim.home_position = Vector3(300.0, 0.0, 300.0)
	sim.home_position.y = sim._terrain.get_height_at(sim.home_position)
	var antes := sim.cumbres.tres_mas_altas().duplicate()
	for cima: Vector3 in antes:
		sim.cumbres._climbed.append(cima)
	sim.cumbres._mas_altas_buscadas = false
	var despues := sim.cumbres.tres_mas_altas()
	var por_subir := sim.cumbres._barrer(true)
	sim._terrain.free()
	sim.free()
	assert_eq(antes.size(), PeakTerrain.SUMMITS.size(), "las del relieve de prueba")
	assert_eq(despues, antes, "coronadas todas, siguen siendo las mismas")
	assert_eq(por_subir.size(), 0, "aunque ya no quede ninguna por subir")


func test_una_cima_que_no_es_de_las_tres_no_avista() -> void:
	var sim := SettlementSim.new()
	sim._terrain = PeakTerrain.new()
	sim.home_position = Vector3(300.0, 0.0, 300.0)
	sim.home_position.y = sim._terrain.get_height_at(sim.home_position)
	var en_una := sim.cumbres.avista_desde(sim.cumbres.tres_mas_altas()[0])
	var en_el_llano := sim.cumbres.avista_desde(Vector3(1900.0, 0.0, 300.0))
	var avistados := sim.cumbres._avistar_desde(Vector3(1900.0, 0.0, 300.0))
	sim._terrain.free()
	sim.free()
	assert_true(en_una, "desde una de las tres, sí")
	assert_false(en_el_llano, "desde otro sitio, no")
	assert_eq(avistados, 0, "y no avista nada")


func test_coronar_una_de_las_tres_avista_hasta_dos_de_lo_que_se_ve() -> void:
	# Con el valle real del sitio 56 y el relieve regional: lo que avista es lo que la
	# línea de vista deja ver, los más lejanos, y nunca más de dos.
	var terreno := TerrainGenerator.new()
	terreno.heightmap = load("res://data/dem/local/site_56.res") as HeightmapData
	terreno.meters_per_unit = 1.0
	terreno.terrain_size = Vector2i(4096, 4096)
	# Las alturas, de la caché de generación del valle: un TerrainGenerator recién hecho
	# no tiene alturas hasta generarse, y montar la malla no hace falta para esto.
	var cache := load("res://data/dem/local/site_56_mesh_r825.res") as TerrainGenerationCache
	terreno.resolution = cache.resolution
	terreno.heightmap_region_offset = cache.heightmap_region_offset
	terreno._height_map = cache.height_map
	var sim := SettlementSim.new()
	sim._terrain = terreno
	sim.chronicle = Chronicle.new()
	sim.home_position = Vector3(2048.0, 0.0, 2048.0)
	sim.home_position.y = terreno.get_height_at(sim.home_position)
	var antes := [GameState.discovered.duplicate(), GameState.avistados.duplicate()]
	GameState.discovered = {}
	GameState.avistados = {}
	var altas := sim.cumbres.tres_mas_altas()
	var cima: Vector3 = altas[0] if not altas.is_empty() else Vector3.ZERO
	var geo := terreno.world_to_geo(cima)
	print("  cima %s: cota local %.0f m, regional %.0f m" % [cima, terreno.get_height_at(cima),
		Viaje.cota(geo.y, geo.x)])
	var t0 := Time.get_ticks_msec()
	var avistados := sim.cumbres._avistar_desde(cima)
	print("  avista %d en %d ms" % [avistados, Time.get_ticks_msec() - t0])
	var apuntados := GameState.avistados.keys()
	GameState.discovered = antes[0]
	GameState.avistados = antes[1]
	sim.free()
	terreno.free()
	assert_false(altas.is_empty(), "el valle tiene cumbres")
	assert_lt(float(avistados), float(Cumbres.AVISTA_HASTA) + 0.5, "nunca más de dos: %d" % avistados)
	assert_eq(apuntados.size(), avistados, "y quedan avistados en la partida")

