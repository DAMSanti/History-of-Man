class_name TestPasarela
extends TestCase
## La pasarela abre UN cruce, no el mapa.
##
## Frente 13 de EPOCA_01 §10.1, tanda 3. Hasta el 2026-09-13 aprender la técnica
## ponía `SettlementSim.has_bridge = true` y con eso se vadeaba cualquier cauce
## del valle menos la mar abierta: dos troncos funcionaban como un permiso.
##
## El terreno de mentira es un valle con un río de una celda de ancho, así que
## la regla se comprueba sin escena y sin simular jornadas.


func suite_name() -> String:
	return "Pasarela"


## Un terreno llano con una franja de agua intransitable en x ∈ [200, 240).
class RioFalso extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65

	func get_height_at(_p: Vector3) -> float:
		return 10.0

	func get_slope_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_at(p: Vector3) -> float:
		return 1.0 if p.x >= 200.0 and p.x < 240.0 else 0.0

	func crossing_difficulty_with(p: Vector3, caudal: float = 1.0) -> float:
		# Con el río bajo, el mismo cauce se vadea.
		if p.x < 200.0 or p.x >= 240.0:
			return 0.0
		return clampf(caudal, 0.0, 1.0)


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.techs = TechTree.new()
	sim.knowledge = BandKnowledge.new()
	sim._terrain = RioFalso.new()
	return sim


func _con_gente(sim: SettlementSim, cuantos: int) -> void:
	for i in range(cuantos):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.ADULTO
		p.oficio_de_hoy = Profession.Job.EXPLORACION
		sim.people.append(p)


## Una vereda que va de una orilla a la otra dando un rodeo.
func _vereda_con_rodeo(sim: SettlementSim) -> void:
	var vereda := Vereda.new()
	vereda.hitos = PackedVector3Array([
		Vector3(100.0, 0.0, 300.0),
		Vector3(100.0, 0.0, 20.0),
		Vector3(400.0, 0.0, 20.0),
		Vector3(400.0, 0.0, 300.0)])
	sim.knowledge.veredas["rodeo"] = vereda


# --------------------------------------- la técnica no abre nada por sí sola

func test_la_tecnica_sola_no_abre_el_cruce() -> void:
	# EL CRITERIO: con la pasarela aprendida y ninguna obra levantada, un cruce
	# cerrado sigue cerrado.
	var sim := _sim()
	sim.techs.known[TechTree.Tech.PASARELA] = true
	assert_false(Hydrography.can_cross(
		sim._terrain.crossing_difficulty_at(Vector3(220.0, 0.0, 300.0)),
		false, sim.pasarelas.hay_en(Vector3(220.0, 0.0, 300.0))),
		"saber hacer pasarelas no es tener una")


func test_con_la_obra_ese_cruce_se_abre_y_los_demas_no() -> void:
	var sim := _sim()
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	assert_true(sim.pasarelas.levantar([celda]), "se levanta")
	assert_true(sim.pasarelas.hay_en(Vector3(220.0, 0.0, 300.0)),
		"ese paso tiene pasarela")
	assert_false(sim.pasarelas.hay_en(Vector3(220.0, 0.0, 100.0)),
		"y el mismo río, doscientos metros más allá, no")


func test_lo_que_abre_vale_en_las_cuatro_estaciones() -> void:
	# Es lo que un vado no da: la pasarela no depende del caudal.
	var sim := _sim()
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	sim.pasarelas.levantar([celda])
	for season in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		assert_true(sim.pasarelas.hay_en(celda),
			"en %s sigue ahí" % Subsistence.season_name(season as Subsistence.Season))


# ------------------------------------------------- dónde la pone la banda --

func test_se_elige_el_cruce_del_camino_que_mas_rodea() -> void:
	var sim := _sim()
	_vereda_con_rodeo(sim)
	var celdas := sim.pasarelas.elegir_cruce()
	assert_eq(celdas.size(), 1, "el cauce es de una celda")
	if celdas.size() == 1:
		assert_true(celdas[0].x >= 200.0 and celdas[0].x < 240.0,
			"y la celda elegida está en el agua: %s" % str(celdas[0]))


func test_sin_caminos_aprendidos_no_se_elige_nada() -> void:
	var sim := _sim()
	assert_eq(sim.pasarelas.elegir_cruce().size(), 0,
		"sin veredas no hay rodeo que ahorrar")


func test_un_cauce_mas_ancho_del_limite_no_se_salva() -> void:
	# Dos celdas es el límite —unos 16 m, decisión del usuario—: un río de
	# cuatro celdas no se cruza con dos troncos.
	var sim := _sim()
	var ancho := RioFalso.new()
	sim._terrain = ancho
	_vereda_con_rodeo(sim)
	# Se ensancha el cauce a 160 m cambiando el terreno por uno equivalente.
	sim._terrain = RioAncho.new()
	assert_eq(sim.pasarelas.elegir_cruce().size(), 0,
		"cuatro celdas de agua no son para una pasarela")


class RioAncho extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65

	func get_height_at(_p: Vector3) -> float:
		return 10.0

	func crossing_difficulty_at(p: Vector3) -> float:
		return 1.0 if p.x >= 200.0 and p.x < 360.0 else 0.0

	func crossing_difficulty_with(p: Vector3, caudal: float = 1.0) -> float:
		if p.x < 200.0 or p.x >= 360.0:
			return 0.0
		return clampf(caudal, 0.0, 1.0)


# ------------------------------------------------------ lo que cuesta ----

func test_se_levanta_con_seis_jornadas_y_cuarenta_de_lena() -> void:
	var sim := _sim()
	_vereda_con_rodeo(sim)
	_con_gente(sim, 3)
	sim.store.add(Materia.Kind.LENA, 100.0)
	sim.techs.known[TechTree.Tech.PASARELA] = true
	sim.pasarelas.nuevo_dia()
	assert_eq(sim.pasarelas.puentes.size(), 0, "el primer día sólo se empieza")
	sim.pasarelas.nuevo_dia()
	assert_eq(sim.pasarelas.puentes.size(), 1,
		"con seis jornadas-persona queda armada")
	assert_near(sim.store.amount(Materia.Kind.LENA), 60.0, 0.001,
		"y se pagan cuarenta de leña")


func test_sin_lena_no_se_remata() -> void:
	var sim := _sim()
	_vereda_con_rodeo(sim)
	_con_gente(sim, 6)
	sim.store.add(Materia.Kind.LENA, 10.0)
	sim.techs.known[TechTree.Tech.PASARELA] = true
	sim.pasarelas.nuevo_dia()
	assert_eq(sim.pasarelas.puentes.size(), 0,
		"con las jornadas hechas pero sin leña, no hay pasarela")


func test_sin_la_tecnica_no_se_construye() -> void:
	var sim := _sim()
	_vereda_con_rodeo(sim)
	_con_gente(sim, 6)
	sim.store.add(Materia.Kind.LENA, 100.0)
	sim.pasarelas.nuevo_dia()
	assert_eq(sim.pasarelas.puentes.size(), 0,
		"primero hay que saber hacerla")


# ------------------------------------------------------------ la riada --

func test_una_crecida_se_la_lleva() -> void:
	var sim := _sim()
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	sim.pasarelas.levantar([celda])
	sim.pasarelas.revisar_riada(1.0)
	assert_eq(sim.pasarelas.puentes.size(), 0, "la riada se la lleva")


func test_sin_crecida_no_se_pierde_nunca() -> void:
	# La otra mitad: sin esto, «se la lleva la riada» sería «se cae sola».
	var sim := _sim()
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	sim.pasarelas.levantar([celda])
	for i in range(8):
		sim.pasarelas.revisar_riada(0.2)
	assert_eq(sim.pasarelas.puentes.size(), 1,
		"con el río bajo aguanta todas las estaciones que haga falta")


func test_perderla_obliga_a_rehacer_las_rejillas() -> void:
	var sim := _sim()
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	sim.pasarelas.levantar([celda])
	var version := sim.pasarelas.version
	sim.pasarelas.revisar_riada(1.0)
	assert_gt(sim.pasarelas.version, version,
		"la versión sube, que es lo que dice a las rejillas que ya no valen")
