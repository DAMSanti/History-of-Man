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
