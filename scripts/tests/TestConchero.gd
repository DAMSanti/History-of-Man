class_name TestConchero
extends TestCase
## De qué está hecho el conchero se ve en su textura.
##
## Petición del usuario del 2026-09-14: «el conchero debe tener la textura
## predominante del material que lo forma: carne y huesos, cáscaras, conchas».


func suite_name() -> String:
	return "Conchero"


func test_cada_desecho_cae_en_su_familia() -> void:
	assert_eq(Conchero.familia_de(Materia.Kind.MARISCO), Conchero.Familia.CONCHA,
		"el marisco deja concha")
	assert_eq(Conchero.familia_de(Materia.Kind.BELLOTA), Conchero.Familia.CASCARA,
		"la bellota deja cáscara")
	assert_eq(Conchero.familia_de(Materia.Kind.CARNE), Conchero.Familia.HUESO,
		"la carne deja hueso")


func test_las_tres_familias_no_se_ven_igual() -> void:
	var concha := Conchero.textura_de(Conchero.Familia.CONCHA).get_image()
	var cascara := Conchero.textura_de(Conchero.Familia.CASCARA).get_image()
	var hueso := Conchero.textura_de(Conchero.Familia.HUESO).get_image()
	assert_gt(_brillo(concha), _brillo(cascara) + 0.15,
		"la concha es clara y la cáscara parda")
	assert_gt(_contraste(hueso), 0.1, "el hueso asoma sobre tierra oscura")
	assert_false(_brillo(hueso) == _brillo(concha), "y no son la misma imagen")


func _brillo(img: Image) -> float:
	var suma := 0.0
	var cuantos := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			suma += img.get_pixel(x, y).get_luminance()
			cuantos += 1
	return suma / float(maxi(cuantos, 1))


func _contraste(img: Image) -> float:
	var bajo := 1.0
	var alto := 0.0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var l := img.get_pixel(x, y).get_luminance()
			bajo = minf(bajo, l)
			alto = maxf(alto, l)
	return alto - bajo
