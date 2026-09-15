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


func test_sin_caminos_aprendidos_se_elige_por_la_rejilla() -> void:
	# Cambió el 2026-09-14: antes, sin veredas no había cruce que elegir —y a la
	# otra orilla de un río que no se ha cruzado nunca no hay vereda ninguna, así
	# que esa mitad del valle no se abría—. Ahora lo primero que se mira es qué
	# parte del valle no se alcanza, y eso sale de la rejilla de caminos.
	var sim := _sim()
	sim.home_position = Vector3(100.0, 0.0, 300.0)
	sim.navgrid()
	assert_gt(float(sim.pasarelas.elegir_cruce().size()), 0.0,
		"sin veredas, el cruce sale de la rejilla")


func test_sin_valle_que_abrir_ni_veredas_no_se_elige_nada() -> void:
	var sim := _sim()
	sim._terrain = SinRio.new()
	sim.home_position = Vector3(100.0, 0.0, 300.0)
	sim.navgrid()
	assert_eq(sim.pasarelas.elegir_cruce().size(), 0,
		"un valle entero de una pieza y sin veredas no pide pasarela")


## Un valle sin agua: una sola zona, nada que abrir.
class SinRio extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65

	func get_height_at(_p: Vector3) -> float:
		return 10.0

	func get_slope_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_with(_p: Vector3, _caudal: float = 1.0) -> float:
		return 0.0


func test_un_cauce_mas_ancho_del_limite_no_se_salva() -> void:
	# Dos celdas es el límite —80 m con la celda de 40, decisión del usuario—: un río de
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


# ---------------------------- el vado que la crecida cierra (2026-09-14) ----
#
# Queja del usuario: «no se están construyendo pasarelas; gracias a ellas
# deberíamos tener acceso a todo el mapa», y «si han ido al otro lado del río en
# verano...». Un río que se cruza andando en verano no rodea nada, así que la
# regla del rodeo no lo veía; y la riada se llevaba la pasarela en cuanto el vado
# se cerraba, que es justo cuando sirve. Ver SISTEMAS §20.

## Un río que en verano se vadea y con la crecida no: calado 0,5 por el caudal.
class RioDeVerano extends TerrainGenerator:
	var calado := 0.5

	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65

	func get_height_at(_p: Vector3) -> float:
		return 10.0

	func get_slope_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_at(p: Vector3) -> float:
		return calado if p.x >= 200.0 and p.x < 240.0 else 0.0

	func crossing_difficulty_with(p: Vector3, caudal: float = 1.0) -> float:
		return crossing_difficulty_at(p) * caudal


func test_el_vado_de_verano_que_la_crecida_cierra_es_donde_va_la_pasarela() -> void:
	var sim := _sim()
	sim._terrain = RioDeVerano.new()
	var vereda := Vereda.new()
	# Recta, de orilla a orilla: la banda cruza por el vado sin rodear nada.
	vereda.hitos = PackedVector3Array([Vector3(100.0, 0.0, 300.0),
		Vector3(400.0, 0.0, 300.0)])
	sim.knowledge.veredas["vado"] = vereda
	var celdas := sim.pasarelas.elegir_cruce()
	assert_eq(celdas.size(), 1, "el vado que se cierra en invierno es el cruce")
	if celdas.size() == 1:
		assert_true(celdas[0].x >= 200.0 and celdas[0].x < 240.0,
			"y la celda está en el cauce: %s" % str(celdas[0]))


func test_la_crecida_que_cierra_el_vado_no_se_lleva_la_pasarela() -> void:
	var sim := _sim()
	sim._terrain = RioDeVerano.new()
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	sim.pasarelas.levantar([celda])
	# El caudal de invierno cierra el vado a pie: 0,5 × 1,55 = 0,78.
	var invierno := float(Temporada.CAUDAL[Subsistence.Season.INVIERNO])
	assert_false(Hydrography.can_cross(
		sim._terrain.crossing_difficulty_with(celda, invierno), false, false),
		"en invierno ese vado no se cruza andando")
	sim.pasarelas.revisar_riada(invierno)
	assert_eq(sim.pasarelas.puentes.size(), 1,
		"y la pasarela sigue: es para eso para lo que está")
	assert_true(Hydrography.can_cross(
		sim._terrain.crossing_difficulty_with(celda, invierno), false,
		sim.pasarelas.hay_en(celda)), "y por ella se cruza en invierno")


func test_el_mapa_de_pasos_no_revienta_con_una_pasarela() -> void:
	# La tecla N cerraba el juego: `NavOverlay` preguntaba por un permiso de
	# pasarela que ya no existe. Se comprueba el color de un punto del cauce con
	# la pasarela puesta y sin ella.
	# Un cauce que a pie no se cruza y con pasarela sí: calado 0,8. El `RioFalso`
	# tiene 1,0, que es mar, y ése no lo salva nada.
	var terreno := RioDeVerano.new()
	terreno.calado = 0.8
	var celda := Pasarelas._centro_de_la_celda(Vector3(220.0, 0.0, 300.0))
	var con := Navgrid.from_terrain(terreno, false, [celda])
	var sin := Navgrid.from_terrain(terreno, false, [])
	var overlay := NavOverlay.new()
	var abierto := overlay._colour_at(con, terreno, celda, -1)
	var cerrado := overlay._colour_at(sin, terreno, celda, -1)
	overlay.free()
	assert_false(abierto == NavOverlay.BLOCKED_COLOUR, "con pasarela no sale cerrado")
	assert_true(cerrado == NavOverlay.BLOCKED_COLOUR, "sin ella, sí")


# --- que abran todo el valle (queja del usuario, 2026-09-14) ------------------

## Una isla: tierra a los dos lados de un cauce de dos celdas, y sin vereda que
## los una. Es el caso que la regla del rodeo no veía nunca.
class RioSinVereda extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65

	func get_height_at(_p: Vector3) -> float:
		return 10.0

	func get_slope_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_at(p: Vector3) -> float:
		return 1.0 if p.x >= 200.0 and p.x < 280.0 else 0.0

	func crossing_difficulty_with(p: Vector3, caudal: float = 1.0) -> float:
		return clampf(caudal, 0.0, 1.0) if p.x >= 200.0 and p.x < 280.0 else 0.0


func test_se_arma_hacia_el_valle_que_no_se_alcanza_aunque_no_haya_vereda() -> void:
	# «Gracias a ellas deberíamos tener acceso a todo el mapa»: sin vereda a la
	# otra orilla, la banda no tiene rodeo que ahorrar, y esa mitad del valle no
	# se abría nunca.
	var sim := _sim()
	sim._terrain = RioSinVereda.new()
	sim.home_position = Vector3(100.0, 0.0, 300.0)
	_con_gente(sim, 3)
	var rejilla := sim.navgrid()
	assert_true(rejilla != null and rejilla.is_ready(), "la rejilla está lista")
	assert_gt(float(rejilla.areas), 1.0, "hay más de una zona: el río parte el valle")
	var cruce := sim.pasarelas.elegir_cruce()
	assert_false(cruce.is_empty(), "se elige un cruce hacia la otra orilla")
	if not cruce.is_empty():
		assert_lt(float(cruce.size()), float(Pasarelas.CELDAS_DE_ANCHO) + 0.5,
			"de dos celdas como mucho")
		var en_el_agua := true
		for celda: Vector3 in cruce:
			if sim._terrain.crossing_difficulty_at(celda) < 1.0:
				en_el_agua = false
		assert_true(en_el_agua, "y sobre el agua")


func test_la_vereda_del_vado_sobrevive_al_cambio_de_rejilla() -> void:
	# Lo que hacía que la regla del vado casi nunca tuviera nada que mirar: al
	# rehacer la rejilla —cada estación— se borraban todas las veredas. Desde el
	# 2026-09-14 duermen y vuelven (SISTEMAS §18), así que el vado que se cierra
	# sigue siendo el cruce elegido cuando vuelve su estación.
	var sim := _sim()
	sim._terrain = RioDeVerano.new()
	var vereda := Vereda.new()
	vereda.hitos = PackedVector3Array([Vector3(100.0, 0.0, 300.0),
		Vector3(400.0, 0.0, 300.0)])
	sim.knowledge.veredas["vado"] = vereda
	var antes := sim.pasarelas._vado_que_se_cierra()
	# Lo que hace el reloj al entrar la estación: rehacer la rejilla.
	sim.marcha.forget_routes()
	var despues := sim.pasarelas._vado_que_se_cierra()
	assert_eq(antes.size(), 1, "antes del cambio de estación hay cruce")
	assert_eq(despues.size(), antes.size(), "y después sigue habiéndolo")
	assert_eq(sim.knowledge.veredas.size(), 1, "porque la vereda no se ha borrado")


## Un CANTIL seco que parte el valle: no se pasa, y no hay una gota de agua.
##
## Es lo que la primera versión de `_hacia_lo_que_no_se_alcanza` confundía con un
## río, porque buscaba el hueco con `cost <= Navgrid.BLOCKED` y eso significa «no
## se pasa», no «hay agua».
class CantilSeco extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65

	func get_height_at(p: Vector3) -> float:
		return 10.0 if p.x < 200.0 or p.x >= 280.0 else 400.0

	func get_slope_at(p: Vector3) -> float:
		# La pared del cantil, muy por encima de lo que se trepa.
		return 5.0 if p.x >= 190.0 and p.x < 290.0 else 0.0

	func crossing_difficulty_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_with(_p: Vector3, _caudal: float = 1.0) -> float:
		return 0.0


func test_no_se_arma_una_pasarela_sobre_roca_seca() -> void:
	# Queja del usuario del 2026-09-14: «está construyendo pasarelas de troncos
	# en el monte, no para cruzar los ríos... las pasarelas son para ponerlas de
	# vereda a vereda de ríos». Con la regla de esa mañana esto elegía cruce.
	var sim := _sim()
	sim._terrain = CantilSeco.new()
	sim.home_position = Vector3(100.0, 0.0, 300.0)
	_con_gente(sim, 3)
	var rejilla := sim.navgrid()
	assert_true(rejilla != null and rejilla.is_ready(), "la rejilla está lista")
	assert_gt(float(rejilla.areas), 1.0,
		"el cantil parte el valle, igual que lo partiría un río")
	var cruce := sim.pasarelas.elegir_cruce()
	assert_true(cruce.is_empty(),
		"dos troncos no salvan un cantil: no debería elegirse cruce, y eligió %d celdas"
			% cruce.size())


## Dos ríos: uno pegado a casa y otro al fondo del mapa.
##
## El de casa abre una franja estrecha; el del fondo abre casi todo lo demás. La
## regla vieja miraba sólo el tamaño y se iba al del fondo.
class DosRios extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(2400, 600)
		resolution = 121

	func get_height_at(_p: Vector3) -> float:
		return 10.0

	func get_slope_at(_p: Vector3) -> float:
		return 0.0

	func crossing_difficulty_at(p: Vector3) -> float:
		if p.x >= 200.0 and p.x < 240.0:
			return 1.0
		if p.x >= 400.0 and p.x < 440.0:
			return 1.0
		return 0.0

	func crossing_difficulty_with(p: Vector3, caudal: float = 1.0) -> float:
		return clampf(caudal, 0.0, 1.0) if crossing_difficulty_at(p) > 0.0 else 0.0


func test_se_elige_el_cruce_de_cerca_aunque_el_de_lejos_abra_mas() -> void:
	# Queja del usuario del 2026-09-14: «ha hecho una pasarela para cruzar el río
	# pegado al borde del mapa, como a 3 km de la cueva. Deben estar cerca de la
	# cueva, la clave es la eficiencia».
	var sim := _sim()
	sim._terrain = DosRios.new()
	sim.home_position = Vector3(100.0, 0.0, 300.0)
	_con_gente(sim, 3)
	var rejilla := sim.navgrid()
	assert_true(rejilla != null and rejilla.is_ready(), "la rejilla está lista")
	var cruce := sim.pasarelas.elegir_cruce()
	assert_false(cruce.is_empty(), "algún cruce se elige")
	if not cruce.is_empty():
		var lejos := Vector2(cruce[0].x - sim.home_position.x,
			cruce[0].z - sim.home_position.z).length()
		assert_lt(lejos, 300.0,
			"el cruce elegido está a %d m de casa: debería ser el de cerca" % int(lejos))


func test_un_cruce_mas_lejos_del_limite_no_se_mira() -> void:
	# El mismo mapa de dos ríos, pero con la cueva al otro extremo: los dos
	# cruces quedan a más de [Pasarelas._LEJOS_NI_MIRARLO], y entonces no hay
	# obra que valga la pena. «La clave es la eficiencia».
	var sim := _sim()
	sim._terrain = DosRios.new()
	sim.home_position = Vector3(2000.0, 0.0, 300.0)
	_con_gente(sim, 3)
	var rejilla := sim.navgrid()
	assert_true(rejilla != null and rejilla.is_ready(), "la rejilla está lista")
	var mas_cercano := 2000.0 - 440.0
	assert_gt(mas_cercano, Pasarelas._LEJOS_NI_MIRARLO,
		"el montaje vale: el río más cercano está a %d m, más que el límite"
			% int(mas_cercano))
	# Sin veredas aprendidas, la única regla que podría elegir es la del valle
	# que no se alcanza, y ésa ahora mira la distancia.
	var cruce := sim.pasarelas.elegir_cruce()
	assert_true(cruce.is_empty(),
		"a %d m de casa no se arma nada, y armó %d celdas"
			% [int(mas_cercano), cruce.size()])
