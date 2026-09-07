class_name TestMishap
extends TestCase
## Pruebas de lo que sale mal en el monte.
##
## Lo que hay que asegurar es que el riesgo sea PROPORCIONADO: que salir lejos
## y por mal terreno se note, que estar reventado lo empeore, y que nada de
## esto mate a nadie. Una banda de quince no aguanta perder gente por un tiro
## de dados, y matar por azar es la forma mas rapida de que el jugador no
## vuelva a arriesgar nunca.


func suite_name() -> String:
	return "Percances"


func test_el_terreno_malo_multiplica_el_riesgo() -> void:
	var easy := Mishap.chance(Traversal.Ground.PASTO, 20.0, 500.0)
	var rough := Mishap.chance(Traversal.Ground.CANCHAL, 20.0, 500.0)
	assert_true(rough > easy * 1.8, "el canchal es mucho peor que el pasto")


func test_el_cansancio_lo_empeora() -> void:
	var fresh := Mishap.chance(Traversal.Ground.PASTO, 20.0, 500.0)
	var spent := Mishap.chance(Traversal.Ground.PASTO, 85.0, 500.0)
	assert_true(spent > fresh, "reventado se tropieza mas")


func test_ir_mas_lejos_cuesta_mas() -> void:
	var near := Mishap.chance(Traversal.Ground.PASTO, 20.0, 400.0)
	var far := Mishap.chance(Traversal.Ground.PASTO, 20.0, 4000.0)
	assert_true(far > near, "cuatro kilometros no son cuatrocientos metros")


func test_el_riesgo_tiene_techo() -> void:
	# Sin tope, una expedicion larga por canchal y reventada saldria mal
	# siempre, y entonces nadie explora
	var worst := Mishap.chance(Traversal.Ground.CANCHAL, 100.0, 20000.0)
	assert_true(worst <= 0.45, "ni en el peor caso pasa del 45%%")


func test_una_jornada_normal_casi_nunca_sale_mal() -> void:
	# Si salir doliera a menudo, el jugador dejaria de salir
	var normal := Mishap.chance(Traversal.Ground.PASTO, 30.0, 600.0)
	assert_true(normal < 0.10, "menos de una de cada diez jornadas")


func test_lo_que_hiere_hiere_dias_no_un_instante() -> void:
	assert_true(Mishap.hurt_days(Mishap.Kind.TORCEDURA) > 0, "la torcedura dura")
	assert_true(Mishap.hurt_days(Mishap.Kind.CAIDA)
		> Mishap.hurt_days(Mishap.Kind.TORCEDURA), "y la caida mas")
	assert_eq(Mishap.hurt_days(Mishap.Kind.TORMENTA), 0,
		"una tormenta no rompe a nadie: solo te hace volver")


func test_hay_percances_que_salen_bien() -> void:
	# No todo lo inesperado es malo, y esto es lo que hace que salir siga
	# apeteciendo despues de la primera torcedura
	assert_true(Mishap.is_good(Mishap.Kind.HALLAZGO), "tropezarse con algo")
	assert_false(Mishap.is_good(Mishap.Kind.CAIDA), "caerse no")


func test_todo_percance_se_puede_contar() -> void:
	# Si uno no tiene texto, sale una linea en blanco en la cronica
	for kind: int in [Mishap.Kind.TORCEDURA, Mishap.Kind.CAIDA,
			Mishap.Kind.PERDIDA, Mishap.Kind.TORMENTA, Mishap.Kind.HALLAZGO]:
		var text := Mishap.tell(kind as Mishap.Kind, "Naia", "al norte")
		assert_true(text.length() > 20, "el percance %d se cuenta" % kind)
		assert_true(text.contains("Naia"), "y dice a quien le paso")


func test_una_herida_baja_el_rendimiento_y_se_cura() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	var healthy := person.effectiveness()

	person.hurt_days = Mishap.FALL_DAYS
	assert_true(person.effectiveness() < healthy, "tocado rinde menos")

	person.hurt_days = 0
	assert_near(person.effectiveness(), healthy, 0.001, "curado vuelve a lo suyo")


# --- dormir fuera: tienda, hoguera y lo que pasa sin ellas ---------------
#
# Quien pernoctaba fuera sólo gastaba comida de mochila y recuperaba menos
# fatiga. Una expedición de otoño sin tienda ni hoguera no es «descansar
# peor»: es la noche de la que se vuelve con algo roto.

func _fuera(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var person := Inhabitant.create(0, Vector3(900.0, 0.0, 900.0), rng)
	person.position = Vector3(900.0, 0.0, 900.0)
	sim.people = [person]
	sim.home_position = Vector3.ZERO
	sim.day = 5
	return person


func test_el_vivac_se_cobra_una_vez_por_noche() -> void:
	# Se llama desde el tick nocturno, o sea sesenta veces por segundo: sin la
	# marca del dia la hoguera se llevaria la lena entera en un suspiro.
	var sim := SettlementSim.new()
	var person := _fuera(sim)
	person.add_load(Materia.Kind.PIEL, 1.0)
	person.add_load(Materia.Kind.LENA, 8.0)

	for _i in range(50):
		sim._bivouac(person)
	assert_eq(person.load.get(Materia.Kind.LENA, 0.0),
		8.0 - SettlementSim.VIVAC_LENA, "una noche, una hoguera")
	assert_eq(person.bivouac_lack, 0, "con las dos cosas no falta nada")


func test_la_piel_no_se_gasta_pero_hace_falta() -> void:
	# Una tienda se lleva y se devuelve; lo que se pierde es la noche que no se
	# llevo.
	var sim := SettlementSim.new()
	var person := _fuera(sim)
	person.add_load(Materia.Kind.PIEL, 1.0)
	person.add_load(Materia.Kind.LENA, 4.0)
	sim._bivouac(person)
	assert_eq(person.load.get(Materia.Kind.PIEL, 0.0), 1.0,
		"la piel vuelve al abrigo con quien la llevo")


func test_sin_nada_encima_se_duerme_a_la_intemperie() -> void:
	var sim := SettlementSim.new()
	var person := _fuera(sim)
	sim._bivouac(person)
	assert_eq(person.bivouac_lack, 2, "faltan la tienda y la hoguera")


func test_falta_solo_la_hoguera() -> void:
	var sim := SettlementSim.new()
	var person := _fuera(sim)
	person.add_load(Materia.Kind.PIEL, 1.0)
	sim._bivouac(person)
	assert_eq(person.bivouac_lack, 1, "tienda si, hoguera no")


func test_la_mala_noche_deja_rastro_en_la_cronica() -> void:
	# Si no se cuenta, el percance de manana llega sin explicacion.
	var sim := SettlementSim.new()
	# Sin montar la cronica esta prueba reventaba con «Invalid access to
	# property 'entries' on Nil» y el marco la contaba como pasada.
	sim.chronicle = Chronicle.new()
	var person := _fuera(sim)
	var antes := sim.chronicle.entries.size()
	sim._bivouac(person)
	assert_gt(float(sim.chronicle.entries.size()), float(antes),
		"la noche mala se anota")


func test_la_carencia_multiplica_el_riesgo_de_verdad() -> void:
	assert_gt(SettlementSim.VIVAC_RIESGO, 1.5,
		"si el multiplicador fuera flojo, llevar el vivac no cambiaria nada")
	# Con las dos cosas de menos, el riesgo de la jornada se multiplica por el
	# cuadrado: es la cuenta que hace `_check_mishaps`.
	assert_gt(pow(SettlementSim.VIVAC_RIESGO, 2.0), 4.0,
		"dormir al raso sin fuego y lejos de casa tiene que doler")


# --- momentos: cuando la partida deja de ser gestion y te mira -----------

func test_un_percance_con_margen_pide_decision() -> void:
	# El accidente no se elige; la reaccion si. Una torcedura deja margen -se
	# puede seguir o volver-, asi que ahi hay algo que decidir.
	var sim := SettlementSim.new()
	var person := _fuera(sim)
	var caught: Array[Moment] = []
	sim.moment_raised.connect(func(m: Moment) -> void: caught.append(m))

	sim._offer_mishap_choice(person, Mishap.Kind.TORCEDURA, "en el canchal")
	assert_eq(caught.size(), 1, "salta el momento")
	assert_true(caught[0].is_decision(), "y trae decision")
	assert_eq(caught[0].who, person, "con nombre y cara, no una cifra")


func test_aguantar_sale_mas_caro_que_volver() -> void:
	var sim := SettlementSim.new()
	var person := _fuera(sim)
	person.hurt_days = Mishap.SPRAIN_DAYS
	var caught: Array[Moment] = []
	sim.moment_raised.connect(func(m: Moment) -> void: caught.append(m))
	sim._offer_mishap_choice(person, Mishap.Kind.TORCEDURA, "en el canchal")

	# La segunda opcion es aguantar y seguir
	var aguantar: Callable = caught[0].options[1]["on_pick"]
	aguantar.call()
	assert_gt(float(person.hurt_days), float(Mishap.SPRAIN_DAYS),
		"andar con eso roto se paga en dias")


func test_una_caida_no_deja_nada_que_decidir() -> void:
	# `Mishap.turns_back` ya obliga a dar media vuelta: ofrecer «que siga»
	# seria un boton que no hace nada.
	assert_true(Mishap.turns_back(Mishap.Kind.CAIDA),
		"una caida devuelve a casa por si sola")
	assert_false(Mishap.turns_back(Mishap.Kind.TORCEDURA),
		"una torcedura no")
