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


# ------------------------------------------- el color del año en el valle --

func test_solo_se_apagan_las_capas_vivas() -> void:
	# La caliza es igual de gris en enero que en agosto. Teñir la piedra con el
	# calendario seria pintar el año encima de la roca.
	var verano := TerrainLayers.tints_in_order_tinted(
		TerrainLayers.tint_of_season(Subsistence.Season.VERANO))
	var invierno := TerrainLayers.tints_in_order_tinted(
		TerrainLayers.tint_of_season(Subsistence.Season.INVIERNO))
	for capa: int in [TerrainLayers.Layer.ROQUEDO, TerrainLayers.Layer.CANCHAL,
			TerrainLayers.Layer.CANTOS, TerrainLayers.Layer.NIEVE]:
		assert_true(verano[capa].is_equal_approx(invierno[capa]),
			"la capa %d no es viva y no cambia con la estacion" % capa)


func test_el_pasto_se_apaga_en_invierno() -> void:
	var primavera := TerrainLayers.tints_in_order_tinted(
		TerrainLayers.tint_of_season(Subsistence.Season.PRIMAVERA))
	var invierno := TerrainLayers.tints_in_order_tinted(
		TerrainLayers.tint_of_season(Subsistence.Season.INVIERNO))
	var verde_primavera: float = primavera[TerrainLayers.Layer.PRADERA].y
	var verde_invierno: float = invierno[TerrainLayers.Layer.PRADERA].y
	assert_lt(verde_invierno, verde_primavera,
		"en invierno queda menos verde en el pasto que en primavera")


func test_el_otono_tira_a_pardo() -> void:
	# Pardo es mas rojo que azul. En otoño la hojarasca amarillea, no se apaga
	# a gris: eso es el invierno.
	var otono := TerrainLayers.tint_of_season(Subsistence.Season.OTONO)
	assert_gt(otono.r, otono.b, "el otoño tira a pardo, no a gris")


func test_el_paisaje_no_cambia_de_golpe_a_medianoche() -> void:
	# La primera nevada no deja el puerto cerrado. Doce jornadas de transicion.
	var t := Temporada.new()
	t.asentar(Subsistence.Season.VERANO)
	var antes := t.cota_de_nieve()
	t.nuevo_dia(Subsistence.Season.INVIERNO)
	var despues := t.cota_de_nieve()
	assert_lt(despues, antes, "la cota de nieve empieza a bajar")
	assert_gt(despues, Temporada.COTA_DE_NIEVE[Subsistence.Season.INVIERNO],
		"pero no llega a la del invierno en una sola jornada")


func test_asentar_deja_la_estacion_puesta_del_todo() -> void:
	# Para arrancar partida y para las sondas: sin esto medirian doce jornadas
	# de la estacion anterior.
	var t := Temporada.new()
	t.asentar(Subsistence.Season.INVIERNO)
	assert_near(t.cota_de_nieve(),
		Temporada.COTA_DE_NIEVE[Subsistence.Season.INVIERNO], 0.001,
		"asentar pone la cota del invierno ya")
	assert_near(t.caudal(), Temporada.CAUDAL[Subsistence.Season.INVIERNO],
		0.001, "y el caudal del invierno")


func test_el_rio_crecido_cierra_vados() -> void:
	var t := Temporada.new()
	t.asentar(Subsistence.Season.INVIERNO)
	var crecido := t.vado(0.30)
	t.asentar(Subsistence.Season.VERANO)
	var bajo := t.vado(0.30)
	assert_gt(crecido, bajo,
		"el mismo paso del rio cuesta mas en invierno que en el estiaje")


func test_la_nieve_frena_solo_por_encima_de_la_cota() -> void:
	var t := Temporada.new()
	t.asentar(Subsistence.Season.INVIERNO)
	assert_near(t.freno_por_nieve(0.10), 1.0, 0.001,
		"en el fondo del valle no hay nieve y no frena")
	assert_lt(t.freno_por_nieve(1.0), 0.5,
		"en la cumbre la nieve frena como el barro")


# --------------------------------------------- el bosque a lo largo del año --

func test_el_pino_no_pierde_la_hoja() -> void:
	# Es perennifolio: la muda poco a poco todo el año, no la tira en octubre.
	# Si el pinar se pelara en invierno, la ladera de umbria desapareceria.
	for season: int in Subsistence.Season.values():
		assert_near(float(Forest.PERENNE[season]["hoja"]), 1.0, 0.001,
			"el pino conserva la hoja en %s"
				% Subsistence.season_name(season as Subsistence.Season))


func test_el_abedul_se_queda_desnudo_en_invierno() -> void:
	assert_lt(float(Forest.CADUCO[Subsistence.Season.INVIERNO]["hoja"]), 0.15,
		"en enero el abedular esta pelado")
	assert_gt(float(Forest.CADUCO[Subsistence.Season.VERANO]["hoja"]), 0.9,
		"y en agosto esta lleno")


func test_el_abedul_amarillea_en_otono() -> void:
	# Amarillo es rojo y verde altos con el azul bajo. Es de las cosas que mas
	# se ven de un valle cantabrico en octubre.
	var otono: Color = Forest.CADUCO[Subsistence.Season.OTONO]["tinte"]
	assert_gt(otono.r, otono.b * 2.0, "el otoño del abedul tira a amarillo")
	assert_gt(otono.g, otono.b * 2.0, "y no a rojo solo")


func test_solo_el_abedul_es_caduco() -> void:
	# Si algun dia entra otro caducifolio hay que darle su fila; esta prueba
	# esta para que no se cuele uno sin ella.
	var caducos := 0
	for kind: Dictionary in Forest.KINDS:
		if bool(kind.get("caduco", false)):
			caducos += 1
			assert_eq(String(kind["model"]), "abedul",
				"el unico caducifolio del catalogo es el abedul")
	assert_eq(caducos, 1, "y hay uno")
