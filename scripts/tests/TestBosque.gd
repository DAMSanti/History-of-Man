class_name TestBosque
extends TestCase
## El claro alrededor de las bocas de cueva.
##
## Queja del usuario del 2026-09-13: «aparecen árboles justo encima de la cueva
## y sus obras». El bosque se sembraba por ruido y sólo esquivaba el agua. La
## regla —25 m sin árboles alrededor de todas las bocas del mapa— es suya.


func suite_name() -> String:
	return "Bosque"


func test_dentro_del_radio_no_se_siembra() -> void:
	var bocas := PackedVector3Array([Vector3(1000.0, 50.0, 1000.0)])
	assert_true(Forest.en_un_claro(Vector3(1015.0, 0.0, 1015.0), bocas),
		"a 21 m de la boca es claro")


func test_fuera_del_radio_si() -> void:
	var bocas := PackedVector3Array([Vector3(1000.0, 50.0, 1000.0)])
	assert_false(Forest.en_un_claro(Vector3(1030.0, 0.0, 1000.0), bocas),
		"a 30 m ya puede haber bosque")


func test_el_radio_es_de_veinticinco_metros() -> void:
	assert_near(Forest.RADIO_DEL_CLARO, 25.0, 0.001,
		"lo que pidió el usuario: por lo menos 25 m")


func test_la_altura_no_cuenta() -> void:
	# Una boca en la ladera tiene el árbol de encima a la misma distancia en
	# planta aunque esté diez metros más arriba: se mide en planta.
	var bocas := PackedVector3Array([Vector3(500.0, 80.0, 500.0)])
	assert_true(Forest.en_un_claro(Vector3(510.0, 95.0, 500.0), bocas),
		"diez metros por encima de la boca sigue siendo su claro")


func test_vale_para_todas_las_bocas() -> void:
	# De todas las del mapa, no sólo la de la banda.
	var bocas := PackedVector3Array([
		Vector3(100.0, 0.0, 100.0), Vector3(3000.0, 0.0, 2000.0)])
	assert_true(Forest.en_un_claro(Vector3(3010.0, 0.0, 2005.0), bocas),
		"la segunda boca también tiene su claro")
