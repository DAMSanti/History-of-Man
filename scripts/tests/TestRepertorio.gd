class_name TestRepertorio
extends TestCase
## El repertorio de lo que pasa dentro de una cueva.
##
## Frente 22 de EPOCA_01 §10.1, tanda 4: «que cada cueva que investigue tenga
## opciones diferentes y no se sienta como *siempre me preguntan lo mismo*».


func suite_name() -> String:
	return "Repertorio"


func test_hay_treinta_situaciones_o_mas() -> void:
	assert_gt(float(Repertorio.cuantas()), 29.0,
		"la spec pide un repertorio de al menos treinta")


func test_toda_situacion_tiene_texto_y_al_menos_dos_opciones() -> void:
	var flojas := 0
	for id: String in Repertorio.SITUACIONES:
		var ficha: Dictionary = Repertorio.SITUACIONES[id]
		if String(ficha["texto"]).length() < 20:
			flojas += 1
		if (ficha["opciones"] as Array).size() < 2:
			flojas += 1
	assert_eq(flojas, 0, "cada situación se cuenta y ofrece elegir")


func test_las_ramas_llevan_a_situaciones_que_existen() -> void:
	var rotas := 0
	for id: String in Repertorio.SITUACIONES:
		var ficha: Dictionary = Repertorio.SITUACIONES[id]
		for opcion: Dictionary in (ficha["opciones"] as Array):
			var destino := String(opcion["lleva_a"])
			if not destino.is_empty() and not Repertorio.SITUACIONES.has(destino):
				rotas += 1
	assert_eq(rotas, 0, "ninguna opción lleva a una situación que no existe")


func test_el_oso_del_usuario_rama_por_rama() -> void:
	# El ejemplo es del usuario y marca el tono: se oye algo; seguir puede acabar
	# con el oso encima, tirar piedras lo trae hacia la boca, y el fuego lo
	# espanta.
	assert_eq(Repertorio.lleva_a("ruido_en_lo_oscuro", 0), "el_oso_de_frente",
		"seguir investigando lleva al oso")
	assert_eq(Repertorio.lleva_a("ruido_en_lo_oscuro", 1), "el_oso_hacia_la_boca",
		"tirar piedras lo mueve hacia la entrada")
	assert_eq(Repertorio.lleva_a("ruido_en_lo_oscuro", 2), "el_humo_lo_espanta",
		"el fuego lo espanta")
	assert_eq(int(Repertorio.efecto_de("ruido_en_lo_oscuro", 0)),
		int(Repertorio.Efecto.PELIGRO), "y seguir a oscuras puede costar la vida")


func test_una_visita_trae_dos_o_tres_sin_repetir() -> void:
	for cueva in range(40):
		var visita := Repertorio.visita_de(5, cueva)
		assert_gt(float(visita.size()), float(Repertorio.MINIMO_POR_VISITA) - 0.5,
			"dos por lo menos")
		assert_lt(float(visita.size()), float(Repertorio.MAXIMO_POR_VISITA) + 0.5,
			"y tres como mucho")
		var vistas: Dictionary = {}
		for id: String in visita:
			vistas[id] = true
		assert_eq(vistas.size(), visita.size(),
			"dentro de una cueva no se repite ninguna")


func test_dos_cuevas_seguidas_no_empiezan_igual() -> void:
	var anterior := ""
	var repetidas := 0
	for cueva in range(30):
		var visita := Repertorio.visita_de(9, cueva, anterior)
		if String(visita[0]) == anterior:
			repetidas += 1
		anterior = String(visita[0])
	assert_eq(repetidas, 0, "la de después nunca abre como la de antes")


func test_la_misma_cueva_de_la_misma_partida_ofrece_lo_mismo() -> void:
	for cueva in range(10):
		assert_eq(str(Repertorio.visita_de(3, cueva)),
			str(Repertorio.visita_de(3, cueva)),
			"preguntar dos veces no cambia la cueva")


func test_partidas_distintas_ven_cosas_distintas() -> void:
	var iguales := 0
	for cueva in range(30):
		if str(Repertorio.visita_de(1, cueva)) == str(Repertorio.visita_de(2, cueva)):
			iguales += 1
	assert_lt(float(iguales), 10.0, "otra semilla, otra cueva")
