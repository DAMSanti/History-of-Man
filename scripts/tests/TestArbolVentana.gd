class_name TestArbolVentana
extends TestCase
## Lo que el árbol de técnicas dice de una técnica parada.
##
## Sale de la queja del 2026-09-13 (EPOCA_01 §10.1, tanda 3, fallo 2): «la
## pasarela lleva 82 de 70 jornadas y no se aprende». El contador es del OFICIO
## y sigue subiendo mientras la técnica espera a la que va antes, así que la
## línea decía una cifra imposible y la causa salía tres líneas más abajo.


func suite_name() -> String:
	return "ArbolVentana"


func _arbol() -> TechTree:
	var tech := TechTree.new()
	tech.larder = Storehouse.new()
	return tech


func test_las_jornadas_no_pasan_de_las_que_pide() -> void:
	var tech := _arbol()
	# Exploración de sobra, y el núcleo preparado —lo que la pasarela pide
	# antes— todavía sin aprender.
	tech.add_practice(Profession.Job.EXPLORACION, 82.0)
	var graph := TechGraph.new()
	graph._tech = tech
	var texto := graph._tooltip(TechTree.Tech.PASARELA)
	graph.free()
	assert_false(texto.contains("82 de 70"),
		"no se anuncian más jornadas de las que la técnica pide")
	assert_true(texto.contains("70 de 70 jornadas, ya hechas"),
		"se dice que las jornadas están hechas")
	assert_true(texto.contains("falta: tras núcleo preparado"),
		"y qué la frena, en esa misma línea")


func test_a_medias_se_cuenta_lo_que_lleva() -> void:
	# La otra mitad: mientras no llegan, la cifra es la de verdad y no se
	# anuncia nada de «ya hechas».
	var tech := _arbol()
	tech.add_practice(Profession.Job.EXPLORACION, 30.0)
	var graph := TechGraph.new()
	graph._tech = tech
	var texto := graph._tooltip(TechTree.Tech.PASARELA)
	graph.free()
	assert_true(texto.contains("30 de 70 jornadas."),
		"a medio camino se dice el camino que lleva")
	assert_false(texto.contains("ya hechas"), "y no que estén hechas")
