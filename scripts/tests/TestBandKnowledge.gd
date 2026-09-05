class_name TestBandKnowledge
extends TestCase
## Pruebas del conocimiento que la banda acumula sobre su territorio.
##
## El punto de partida no es la ignorancia total: una banda paleolítica SABE
## que en los ríos hay peces y que los ciervos pastan en el llano. Lo que no
## sabe es dónde exactamente ni cuándo mejor. Eso se aprende pisando el
## terreno, y es lo que la vuelve eficiente con el tiempo.
##
## Distingue por tanto dos cosas que suelen confundirse: la abundancia REAL,
## que existe la mire alguien o no, y lo que la banda CREE, que es lo único
## sobre lo que puede decidir.


func suite_name() -> String:
	return "Conocimiento"


func _knowledge() -> BandKnowledge:
	var k := BandKnowledge.new()
	k.setup(16, 16, Vector2(1600.0, 1600.0))
	return k


func _field_with_hotspot() -> ResourceField:
	var field := ResourceField.new()
	field.setup(16, 16, Vector2(1600.0, 1600.0))
	field.set_abundance(Subsistence.Activity.CAZA, 12, 12, 1.0)
	field.set_abundance(Subsistence.Activity.CAZA, 3, 3, 0.4)
	return field


# --- de que se parte -------------------------------------------------------

func test_al_empezar_no_se_sabe_donde() -> void:
	var k := _knowledge()
	assert_eq(k.familiarity_at(Subsistence.Activity.CAZA, Vector3(600, 0, 600)), 0.0,
		"al principio no se conoce ningun paraje")


func test_pero_si_se_sabe_que_existe_el_recurso() -> void:
	# Una banda no descubre que hay peces en el rio: eso ya lo trae puesto. Lo
	# que descubre es en que remanso concreto y en que mes.
	var k := _knowledge()
	assert_true(k.knows_activity(Subsistence.Activity.PESCA),
		"se sabe que en el agua hay pesca")
	assert_true(k.knows_activity(Subsistence.Activity.CAZA),
		"se sabe que hay caza")


# --- se aprende pisando ----------------------------------------------------

func test_trabajar_una_zona_la_da_a_conocer() -> void:
	var k := _knowledge()
	var punto := Vector3(600, 0, 600)
	k.observe(Subsistence.Activity.CAZA, punto, 1.0)
	assert_gt(k.familiarity_at(Subsistence.Activity.CAZA, punto), 0.0,
		"tras trabajar ahi, se conoce")


func test_el_conocimiento_se_acumula_pero_no_se_desborda() -> void:
	var k := _knowledge()
	var punto := Vector3(600, 0, 600)
	var previo := 0.0
	for i in range(40):
		k.observe(Subsistence.Activity.CAZA, punto, 1.0)
		var ahora := k.familiarity_at(Subsistence.Activity.CAZA, punto)
		assert_true(ahora >= previo, "el conocimiento no retrocede al insistir")
		previo = ahora
	assert_between(previo, 0.95, 1.0, "satura en conocimiento pleno")


func test_conocer_un_paraje_no_es_conocer_el_de_al_lado() -> void:
	var k := _knowledge()
	k.observe(Subsistence.Activity.CAZA, Vector3(600, 0, 600), 1.0)
	assert_eq(k.familiarity_at(Subsistence.Activity.CAZA, Vector3(1500, 0, 1500)), 0.0,
		"el otro extremo del valle sigue sin conocerse")


# --- descubrir de golpe, sin la curva de observe ---------------------------

func test_reveal_pone_la_familiaridad_de_golpe() -> void:
	# `observe` con una sola llamada nunca llega al umbral de nombrarse -esta
	# limitado a proposito para modelar hacerse bueno con el tiempo-. `reveal`
	# es lo contrario: un hallazgo de una tarde, de una vez.
	var k := _knowledge()
	var punto := Vector3(600, 0, 600)
	k.reveal(Subsistence.Activity.RECOLECCION, punto, BandKnowledge.KNOWN_ENOUGH + 0.02)
	assert_gt(k.familiarity_at(Subsistence.Activity.RECOLECCION, punto),
		BandKnowledge.KNOWN_ENOUGH,
		"una revelacion sola ya cruza el umbral de nombrarse")


func test_reveal_no_retrocede_lo_ya_sabido() -> void:
	# Volver a batir un sitio bien conocido no puede hacer que se sepa menos
	var k := _knowledge()
	var punto := Vector3(600, 0, 600)
	for i in range(30):
		k.observe(Subsistence.Activity.CAZA, punto, 1.0)
	var antes := k.familiarity_at(Subsistence.Activity.CAZA, punto)
	k.reveal(Subsistence.Activity.CAZA, punto, 0.1)
	assert_eq(k.familiarity_at(Subsistence.Activity.CAZA, punto), antes,
		"revelar un nivel mas bajo que lo ya sabido no baja nada")


func test_lo_que_se_aprende_de_una_actividad_no_vale_para_otra() -> void:
	# Conocer los pasos del ciervo no dice nada de donde desovan los salmones
	var k := _knowledge()
	var punto := Vector3(600, 0, 600)
	k.observe(Subsistence.Activity.CAZA, punto, 1.0)
	assert_eq(k.familiarity_at(Subsistence.Activity.PESCA, punto), 0.0,
		"la pesca no se aprende cazando")


func test_pasar_por_un_sitio_ensena_menos_que_trabajarlo() -> void:
	var trabajando := _knowledge()
	var pasando := _knowledge()
	var punto := Vector3(600, 0, 600)
	trabajando.observe(Subsistence.Activity.CAZA, punto, 1.0)
	pasando.observe(Subsistence.Activity.CAZA, punto, 0.2)
	assert_gt(trabajando.familiarity_at(Subsistence.Activity.CAZA, punto),
		pasando.familiarity_at(Subsistence.Activity.CAZA, punto),
		"se aprende mas de la jornada que del camino")


# --- lo que la banda cree frente a lo que hay -----------------------------

func test_sin_conocer_el_sitio_se_le_saca_la_mitad() -> void:
	var k := _knowledge()
	var field := _field_with_hotspot()
	var rico := Vector3(1250, 0, 1250)
	# Rinde la mitad de lo que rendiria conociendolo. No menos: la banda sabe
	# que hay ciervos aunque no sepa por donde entran, asi que algo caza.
	var real := field.seasonal_abundance_at(Subsistence.Activity.CAZA, rico,
		Subsistence.Season.OTONO)
	assert_near(k.believed_abundance(field, Subsistence.Activity.CAZA, rico,
		Subsistence.Season.OTONO), real * BandKnowledge.BLIND_YIELD, 0.05,
		"sin conocer el sitio se saca la mitad")


func test_conocerlo_deja_aprovecharlo_entero() -> void:
	var k := _knowledge()
	var field := _field_with_hotspot()
	var rico := Vector3(1250, 0, 1250)
	for i in range(60):
		k.observe(Subsistence.Activity.CAZA, rico, 1.0)
	var creido := k.believed_abundance(field, Subsistence.Activity.CAZA, rico,
		Subsistence.Season.OTONO)
	var real := field.seasonal_abundance_at(Subsistence.Activity.CAZA, rico,
		Subsistence.Season.OTONO)
	assert_near(creido, real, 0.05, "conocido a fondo, se le saca todo")


func test_la_banda_elige_el_mejor_sitio_QUE_CONOCE() -> void:
	# Y esto es lo importante: al principio se va al sitio mediocre que conoce,
	# no al bueno que ignora. Explorar es lo que arregla eso.
	var k := _knowledge()
	var field := _field_with_hotspot()
	var pobre := Vector3(350, 0, 350)
	var rico := Vector3(1250, 0, 1250)

	for i in range(60):
		k.observe(Subsistence.Activity.CAZA, pobre, 1.0)

	var elegido := k.best_known_site(field, Subsistence.Activity.CAZA,
		Subsistence.Season.OTONO)
	assert_lt(elegido.distance_to(pobre), 150.0,
		"solo conociendo el sitio pobre, se va al pobre")

	for i in range(60):
		k.observe(Subsistence.Activity.CAZA, rico, 1.0)
	elegido = k.best_known_site(field, Subsistence.Activity.CAZA,
		Subsistence.Season.OTONO)
	assert_lt(elegido.distance_to(rico), 150.0,
		"al conocer el bueno, se cambia a el")


# --- estacionalidad aprendida ---------------------------------------------

func test_la_estacion_no_se_sabe_hasta_haberla_vivido() -> void:
	var k := _knowledge()
	assert_false(k.knows_season(Subsistence.Activity.PESCA, Subsistence.Season.PRIMAVERA),
		"la primera primavera coge a la banda sin saber del remonte")


func test_una_temporada_vivida_se_recuerda() -> void:
	var k := _knowledge()
	k.record_season(Subsistence.Activity.PESCA, Subsistence.Season.PRIMAVERA)
	assert_true(k.knows_season(Subsistence.Activity.PESCA, Subsistence.Season.PRIMAVERA),
		"despues de vivirla, se sabe")
	assert_false(k.knows_season(Subsistence.Activity.PESCA, Subsistence.Season.OTONO),
		"pero solo esa")


func test_saber_la_temporada_mejora_el_rendimiento() -> void:
	var ciego := _knowledge()
	var sabio := _knowledge()
	var field := _field_with_hotspot()
	var punto := Vector3(1250, 0, 1250)
	for i in range(60):
		ciego.observe(Subsistence.Activity.CAZA, punto, 1.0)
		sabio.observe(Subsistence.Activity.CAZA, punto, 1.0)
	sabio.record_season(Subsistence.Activity.CAZA, Subsistence.Season.OTONO)

	assert_gt(sabio.efficiency(Subsistence.Activity.CAZA, Subsistence.Season.OTONO),
		ciego.efficiency(Subsistence.Activity.CAZA, Subsistence.Season.OTONO),
		"quien ya vivio la berrea le saca mas partido")
