class_name TestAscent
extends TestCase
## Pruebas de la ascension.
##
## Lo que hay que asegurar es la peticion literal: mandar a un novato a la
## peor cumbre de la comarca sale mal nueve de cada diez veces, y coronar lo
## que esta a tu nivel sale bien casi siempre. Sin lo primero la pericia no
## vale nada; sin lo segundo nadie sube nunca.


func suite_name() -> String:
	return "Ascension"


func test_una_cumbre_alta_y_empinada_es_dura() -> void:
	var gentle := Ascent.difficulty(80.0, 0.2, 600.0)
	var brutal := Ascent.difficulty(600.0, 0.9, 4000.0)
	assert_true(gentle < 0.35, "una loma cercana es facil (%.2f)" % gentle)
	assert_true(brutal > 0.8, "una pared lejana es dura (%.2f)" % brutal)


func test_la_pericia_decide_a_que_te_atreves() -> void:
	# Es la mitad del asunto, y pasa ANTES de tirar ningun dado: un novato
	# mira el pico grande, calcula, y se va al de al lado
	var novice := Ascent.dares(0.35)
	var master := Ascent.dares(0.9)
	assert_true(novice < 0.5, "el novato no se atreve con media comarca")
	assert_true(master > 0.95, "el veterano con todo")


func test_un_novato_en_una_cumbre_dura_casi_nunca_corona() -> void:
	# La cifra que pediste: nueve de cada diez veces no llega
	var odds := Ascent.chance(0.35, 0.95, 1.0, 20.0)
	assert_true(odds < 0.15, "corona menos de una de cada seis (%.2f)" % odds)


func test_en_su_nivel_se_corona_casi_siempre() -> void:
	# Si fallara a menudo lo que esta a tu nivel, nadie subiria nunca
	var odds := Ascent.chance(0.75, 0.5, 1.0, 20.0)
	assert_true(odds > 0.75, "se corona lo que uno sabe (%.2f)" % odds)


func test_el_mal_tiempo_y_el_cansancio_bajan_las_opciones() -> void:
	var calm := Ascent.chance(0.7, 0.5, 1.0, 10.0)
	var storm := Ascent.chance(0.7, 0.5, 2.6, 10.0)
	var tired := Ascent.chance(0.7, 0.5, 1.0, 90.0)
	assert_true(storm < calm, "con temporal se corona menos")
	assert_true(tired < calm, "y reventado tambien")


func test_nunca_es_seguro_ni_imposible() -> void:
	# Un cero desanima para siempre; un uno quita toda la tension
	var best := Ascent.chance(0.95, 0.0, 1.0, 0.0)
	var worst := Ascent.chance(0.2, 1.0, 2.6, 100.0)
	assert_true(best < 1.0, "nunca es seguro")
	assert_true(worst > 0.0, "ni imposible del todo")


func test_quien_no_corona_llega_a_alguna_parte() -> void:
	# Sirve para contarlo: «se quedo a doscientos metros» dice mucho mas que
	# «no pudo»
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(20):
		var got := Ascent.reached(rng)
		assert_true(got > 0.4 and got < 1.0,
			"se queda a medio camino, no en la base ni arriba")


# --- lo que no se sube todavia ---------------------------------------------

func test_hay_cumbres_que_piden_equipo_que_no_existe() -> void:
	# Una pared vertical no se corona con pericia: se corona con cuerda
	# trenzada de verdad y calzado que agarre, y eso no hay en el Paleolitico
	var wall := Ascent.difficulty(700.0, 1.0, 4500.0)
	assert_true(Ascent.needs_gear(wall), "la pared queda fuera (%.2f)" % wall)

	var reachable := Ascent.difficulty(300.0, 0.5, 1500.0)
	assert_false(Ascent.needs_gear(reachable),
		"un monte normal si (%.2f)" % reachable)


func test_el_limite_no_se_come_las_cumbres_normales() -> void:
	# Si el umbral fuera bajo, media comarca quedaria fuera y la ascension no
	# tendria nada que hacer en esta era
	assert_true(Ascent.GEAR_THRESHOLD > 0.8,
		"solo lo verdaderamente extremo queda fuera")
	assert_true(Ascent.GEAR_THRESHOLD < 1.0,
		"pero algo tiene que quedar fuera, o la promesa es mentira")
