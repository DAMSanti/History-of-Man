class_name TestSubsistence
extends TestCase
## Pruebas del modelo de subsistencia: que se puede comer, cuanto, y por que.

var _inland: Site
var _coastal: Site


func suite_name() -> String:
	return "Subsistence"


func before_each() -> void:
	# Sitio de interior con cauce al lado, como Cueva los pendios
	_inland = Site.new()
	_inland.elevation = 172.0
	_inland.slope_deg = 10.6
	_inland.water_km = 0.3
	_inland.coast_km = 12.8

	# Sitio costero
	_coastal = Site.new()
	_coastal.elevation = 30.0
	_coastal.slope_deg = 5.0
	_coastal.water_km = 8.0
	_coastal.coast_km = 0.8


func test_sin_costa_no_hay_marisqueo() -> void:
	var acts := Subsistence.available(_inland, Subsistence.Season.INVIERNO)
	assert_false(acts.has(Subsistence.Activity.MARISQUEO),
		"a 12,8 km del mar no se marisquea desde casa")


func test_con_costa_hay_marisqueo_todo_el_ano() -> void:
	for s: int in [0, 1, 2, 3]:
		var acts := Subsistence.available(_coastal, s as Subsistence.Season)
		assert_true(acts.has(Subsistence.Activity.MARISQUEO),
			"el marisco no es estacional: %s" % Subsistence.season_name(s as Subsistence.Season))


func test_la_pesca_es_solo_de_primavera() -> void:
	assert_true(Subsistence.available(_inland, Subsistence.Season.PRIMAVERA)
		.has(Subsistence.Activity.PESCA), "en primavera sube el salmon")
	for s: int in [1, 2, 3]:
		assert_false(Subsistence.available(_inland, s as Subsistence.Season)
			.has(Subsistence.Activity.PESCA),
			"fuera de primavera no hay pesquera: %s" % Subsistence.season_name(s as Subsistence.Season))


func test_sin_cauce_cerca_no_se_pesca() -> void:
	assert_false(Subsistence.available(_coastal, Subsistence.Season.PRIMAVERA)
		.has(Subsistence.Activity.PESCA), "a 8 km del cauce no se pesca")


func test_el_otono_es_la_mejor_caza() -> void:
	var autumn := Subsistence.yield_per_party(_inland, Subsistence.Season.OTONO,
		Subsistence.Activity.CAZA)
	for s: int in [0, 1, 3]:
		var other := Subsistence.yield_per_party(_inland, s as Subsistence.Season,
			Subsistence.Activity.CAZA)
		assert_gt(autumn, other, "la berrea debe superar a %s" %
			Subsistence.season_name(s as Subsistence.Season))


func test_el_invierno_es_la_peor_caza() -> void:
	var winter := Subsistence.yield_per_party(_inland, Subsistence.Season.INVIERNO,
		Subsistence.Activity.CAZA)
	for s: int in [0, 1, 2]:
		assert_lt(winter, Subsistence.yield_per_party(_inland, s as Subsistence.Season,
			Subsistence.Activity.CAZA), "el invierno es la peor caza")


func test_el_techo_del_sitio_limita_el_esfuerzo() -> void:
	# Mandar muchisimas partidas no puede rendir infinito: un valle no tiene
	# ciervos sin fin. Es lo que crea la capacidad de carga.
	var cap := Subsistence.season_cap(_inland, Subsistence.Season.OTONO,
		Subsistence.Activity.CAZA)
	var huge := Subsistence.harvest(_inland, Subsistence.Season.OTONO,
		Subsistence.Activity.CAZA, 500)
	assert_near(huge, cap, 0.01, "con 500 partidas se llega al techo, no mas")


func test_una_partida_rinde_menos_que_el_techo() -> void:
	var one := Subsistence.harvest(_inland, Subsistence.Season.OTONO,
		Subsistence.Activity.CAZA, 1)
	var cap := Subsistence.season_cap(_inland, Subsistence.Season.OTONO,
		Subsistence.Activity.CAZA)
	assert_lt(one, cap, "una sola partida no agota el coto")


func test_las_partidas_crecen_con_la_poblacion() -> void:
	# El fallo que extinguia la banda: con division entera, pasar de 25 a 29
	# anadia bocas y ni un trabajador.
	assert_gt(float(Subsistence.parties(29)), float(Subsistence.parties(25)),
		"crecer de 25 a 29 debe dar mas partidas, no las mismas")


func test_el_consumo_es_proporcional_a_la_gente() -> void:
	var por_estacion := float(Subsistence.DAYS_PER_SEASON)
	assert_near(Subsistence.consumption(25), 25.0 * por_estacion, 0.01,
		"25 personas por una estacion son sus jornadas-persona")
	assert_near(Subsistence.consumption(50), 50.0 * por_estacion, 0.01,
		"el doble de gente come el doble")


func test_el_mes_avanza_con_los_dias_de_estacion() -> void:
	var primero := Subsistence.month_name(Subsistence.Season.OTONO, 0)
	var segundo := Subsistence.month_name(Subsistence.Season.OTONO, Subsistence.DAYS_PER_MONTH)
	var tercero := Subsistence.month_name(Subsistence.Season.OTONO,
		Subsistence.DAYS_PER_MONTH * 2)
	assert_true(primero != segundo and segundo != tercero and primero != tercero,
		"los tres tercios de la estacion tienen nombre distinto")


func test_el_mes_no_se_sale_de_la_estacion() -> void:
	# Un dia de mas -por redondeo, o al cambiar DAYS_PER_SEASON- no debe
	# hacer que se busque un cuarto mes que no existe
	var ultimo_dia := Subsistence.DAYS_PER_SEASON - 1
	var nombre := Subsistence.month_name(Subsistence.Season.VERANO, ultimo_dia)
	assert_true(not nombre.is_empty(), "el ultimo dia de la estacion sigue teniendo mes")


func test_la_capacidad_de_carga_es_finita_y_razonable() -> void:
	var capacity := Subsistence.carrying_capacity(_inland, 25)
	assert_between(float(capacity), 15.0, 60.0,
		"un abrigo paleolitico sostiene decenas de personas, no miles")


# --- la cuenta del invierno, la que decide la epoca ----------------------
#
# SLICE_PALEOLITICO §3: el otoño decide si se sobrevive al invierno. Hasta
# ahora esa cuenta no existía en ningún sitio; vivía repartida entre el almacén
# y la cabeza del jugador.

func test_la_reserva_de_invierno_se_mide_contra_una_estacion_entera() -> void:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var people: Array[Inhabitant] = []
	for i in range(6):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		people.append(person)
	sim.people = people

	var stock := sim.despensa.winter_stock()
	assert_gt(float(stock["needed"]), 0.0, "seis bocas comen algo")
	assert_eq(stock["share"], 0.0, "con el almacen vacio no se llega a nada")

	# Justo lo de una estacion entera
	sim.store.add(Materia.Kind.CARNE_SECA,
		float(stock["needed"]) / Materia.nutrition(Materia.Kind.CARNE_SECA))
	var full := sim.despensa.winter_stock()
	assert_true(absf(float(full["share"]) - 1.0) < 0.05,
		"con la despensa justa, el invierno esta cubierto (%.2f)" % full["share"])


func test_volcarse_en_la_berrea_manda_gente_a_la_caza_mayor() -> void:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var people: Array[Inhabitant] = []
	for i in range(8):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 28
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		Profession.assign(Profession.Job.OCIOSO, person)
		people.append(person)
	sim.people = people

	sim.focus_on_rut()
	var hunters := 0
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.CAZA:
			hunters += 1
	assert_gt(float(hunters), 0.0, "la decision mueve gente de verdad")
