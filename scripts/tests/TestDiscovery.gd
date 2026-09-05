class_name TestDiscovery
extends TestCase
## Pruebas de lo que la banda ha llegado a ver del mapa.
##
## Es distinto de [BandKnowledge], y la diferencia importa: aquello mide lo que
## se SABE de un recurso —dónde entra el ciervo, cuándo remonta el salmón— y
## esto mide simplemente por dónde se ha pasado. Se puede haber cruzado un
## valle entero sin aprender nada de su caza, y aun así conocer el terreno.
##
## De aquí salen dos cosas del juego: las zonas en negro del mapa, y que una
## cueva no exista para el jugador hasta que alguien pase lo bastante cerca
## como para verla.


func suite_name() -> String:
	return "Descubrimiento"


func _knowledge() -> BandKnowledge:
	var k := BandKnowledge.new()
	k.setup(32, 32, Vector2(3200.0, 3200.0))
	return k


# --- el mapa empieza en negro ---------------------------------------------

func test_al_empezar_no_se_ha_visto_nada() -> void:
	var k := _knowledge()
	assert_eq(k.explored_at(Vector3(1600, 0, 1600)), 0.0,
		"el valle esta sin ver entero")


func test_pasar_por_un_sitio_lo_descubre() -> void:
	var k := _knowledge()
	var punto := Vector3(1600, 0, 1600)
	k.see_from(punto, 200.0)
	assert_gt(k.explored_at(punto), 0.9, "donde se ha estado, se ha visto")


func test_se_ve_hasta_donde_alcanza_la_vista_y_no_mas() -> void:
	var k := _knowledge()
	var punto := Vector3(1600, 0, 1600)
	k.see_from(punto, 200.0)

	assert_gt(k.explored_at(punto + Vector3(150, 0, 0)), 0.0,
		"dentro del alcance se ve")
	assert_eq(k.explored_at(punto + Vector3(700, 0, 0)), 0.0,
		"mas alla del alcance, no")


func test_lo_visto_se_desvanece_hacia_el_borde() -> void:
	# Un circulo de borde duro se lee como un foco, no como una vista: lo de
	# lejos se distingue peor, y el mapa tiene que decirlo
	var k := _knowledge()
	var punto := Vector3(1600, 0, 1600)
	k.see_from(punto, 300.0)
	assert_gt(k.explored_at(punto), k.explored_at(punto + Vector3(250, 0, 0)),
		"se conoce mejor lo que se tiene al lado")


func test_lo_visto_no_se_olvida() -> void:
	var k := _knowledge()
	var punto := Vector3(1600, 0, 1600)
	k.see_from(punto, 200.0)
	var antes := k.explored_at(punto)
	k.see_from(Vector3(200, 0, 200), 200.0)
	assert_near(k.explored_at(punto), antes, 0.0001,
		"ir a otro sitio no borra lo ya visto")


func test_volver_a_pasar_afina_lo_que_ya_se_conocia() -> void:
	var k := _knowledge()
	var punto := Vector3(1600, 0, 1600)
	var lejos := punto + Vector3(280, 0, 0)
	k.see_from(punto, 300.0)
	var primera := k.explored_at(lejos)
	k.see_from(lejos, 300.0)
	assert_gt(k.explored_at(lejos), primera,
		"acercarse a lo que se vio de lejos lo aclara")


func test_conocer_el_terreno_no_es_conocer_su_caza() -> void:
	# La distincion que justifica que esto sea un mapa aparte
	var k := _knowledge()
	var punto := Vector3(1600, 0, 1600)
	k.see_from(punto, 200.0)
	assert_gt(k.explored_at(punto), 0.9, "el terreno se conoce")
	assert_eq(k.familiarity_at(Subsistence.Activity.CAZA, punto), 0.0,
		"pero de su caza no se sabe nada por haber pasado")


func test_fuera_del_mapa_no_rompe() -> void:
	var k := _knowledge()
	k.see_from(Vector3(-500, 0, -500), 200.0)
	assert_eq(k.explored_at(Vector3(-500, 0, -500)), 0.0,
		"lo de fuera del recuadro no se registra")


# --- las cuevas ------------------------------------------------------------

func test_una_cueva_lejana_sigue_sin_descubrir() -> void:
	var k := _knowledge()
	k.see_from(Vector3(200, 0, 200), 200.0)
	assert_false(k.is_discovered(Vector3(2800, 0, 2800)),
		"una cueva al otro lado del valle no se ha encontrado")


func test_pasar_cerca_descubre_la_cueva() -> void:
	var k := _knowledge()
	var cueva := Vector3(1600, 0, 1600)
	k.see_from(cueva + Vector3(120, 0, 0), 250.0)
	assert_true(k.is_discovered(cueva), "pasando al lado, se ve la boca")


func test_una_cueva_descubierta_no_se_pierde() -> void:
	var k := _knowledge()
	var cueva := Vector3(1600, 0, 1600)
	k.see_from(cueva, 250.0)
	k.see_from(Vector3(200, 0, 200), 250.0)
	assert_true(k.is_discovered(cueva),
		"lo encontrado se queda encontrado")


func test_verla_de_muy_lejos_no_basta() -> void:
	# En el borde del alcance el terreno se distingue, pero una boca de cueva
	# concreta no: hay que arrimarse
	var k := _knowledge()
	var cueva := Vector3(1600, 0, 1600)
	k.see_from(cueva + Vector3(290, 0, 0), 300.0)
	assert_gt(k.explored_at(cueva), 0.0, "el terreno si se ha visto")
	assert_false(k.is_discovered(cueva),
		"pero la boca de la cueva todavia no")
