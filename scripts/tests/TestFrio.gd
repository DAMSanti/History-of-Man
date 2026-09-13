class_name TestFrio
extends TestCase
## El frío se coge por los grados que hace, no por la estación que es.
##
## Hasta el 2026-09-12 `Inhabitant.cold` subía sólo si era invierno Y el hogar
## estaba apagado, y **dormir al raso no tocaba el frío en ninguna estación**:
## sólo la fatiga. El tercer criterio del frente 7 —«dormir al raso en invierno
## tiene consecuencia distinta de dormir al raso en verano»— no fallaba: no
## había nada que medir. Ver EPOCA_01 §10.1, tanda 2, frente 7.


func suite_name() -> String:
	return "Frio"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	for i in range(4):
		var p := Inhabitant.new()
		p.id = i
		sim.people.append(p)
	return sim


func _noche(estacion: Subsistence.Season, cota: float) -> float:
	return Termometro.grados(estacion, 3.0, cota)


# ------------------------------------------ la calibración no mueve nada --

func test_la_noche_de_invierno_de_siempre_enfria_lo_de_siempre() -> void:
	# LA QUE ASEGURA QUE NO SE HA MOVIDO EL BALANCE. La pendiente sale de que una
	# madrugada de invierno al nivel del mar dé exactamente `HEARTH_COLD_RISE`,
	# que es lo que el juego aplicaba antes a cualquier noche de invierno.
	assert_near(SettlementSim.frio_por_hora(_noche(Subsistence.Season.INVIERNO, 0.0)),
		SettlementSim.HEARTH_COLD_RISE, 0.001,
		"en el punto de calibración, el frío de antes")


func test_por_encima_del_umbral_no_se_coge_frio() -> void:
	assert_near(SettlementSim.frio_por_hora(Termometro.GRADOS_DE_ABRIGO + 0.5),
		0.0, 0.0001, "con cinco grados y medio no se enfría nadie")
	assert_near(SettlementSim.frio_por_hora(20.0), 0.0, 0.0001, "ni con veinte")


func test_cuanto_mas_frio_hace_mas_frio_se_coge() -> void:
	var tibio := SettlementSim.frio_por_hora(3.0)
	var helado := SettlementSim.frio_por_hora(-4.0)
	assert_gt(tibio, 0.0, "a tres grados ya se coge algo")
	assert_gt(helado, tibio, "y bajo cero, bastante más")


func test_el_umbral_es_uno_solo_para_la_barra_y_para_el_cuerpo() -> void:
	# Nació en la barra como cifra de interfaz y se mudó al termómetro en cuanto
	# empezó a decidir la partida. Si volviera a haber dos, el aviso se pondría
	# rojo a una temperatura y la gente se enfriaría a otra.
	assert_near(SettlementSim.frio_por_hora(Termometro.GRADOS_DE_ABRIGO), 0.0, 0.0001,
		"justo en el umbral, frío cero: la frontera es la misma")


# --------------------------------------- lo que antes no se veía --

func test_en_la_estacion_de_siempre_enfria_cuando_enfriaba() -> void:
	# Al nivel del mar: la noche de invierno enfría y la de primavera, otoño y
	# verano no. Que es lo que hacía el «si es invierno» de antes.
	assert_gt(SettlementSim.frio_por_hora(_noche(Subsistence.Season.INVIERNO, 0.0)), 0.0,
		"invierno, sí")
	for estacion in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO]:
		assert_near(SettlementSim.frio_por_hora(_noche(estacion, 0.0)), 0.0, 0.0001,
			"el resto del año, no")


func test_mas_arriba_enfria_mas_la_misma_noche() -> void:
	# LO NUEVO: el gradiente vertical es físico, y el roquedo es otro sitio.
	var cueva := SettlementSim.frio_por_hora(_noche(Subsistence.Season.INVIERNO, 120.0))
	var roquedo := SettlementSim.frio_por_hora(_noche(Subsistence.Season.INVIERNO, 400.0))
	assert_gt(roquedo, cueva, "arriba se coge más frío que en la cueva")


func test_un_abrigo_alto_coge_frio_tambien_en_otono() -> void:
	# Lo que el «si es invierno» no podía decir. Una cueva a 600 m tiene la
	# madrugada de otoño por debajo del umbral.
	assert_gt(SettlementSim.frio_por_hora(_noche(Subsistence.Season.OTONO, 600.0)), 0.0,
		"a seiscientos metros, el otoño ya enfría")


# ------------------------------------ una noche, con y sin fuego --

func test_al_raso_en_invierno_se_coge_frio_y_en_verano_no() -> void:
	# EL TERCER CRITERIO DEL FRENTE 7, que antes no tenía nada que medir.
	var sim := _sim()
	var invierno := sim.people[0]
	var verano := sim.people[1]
	sim._frio_de_una_noche(invierno, 8.0,
		_noche(Subsistence.Season.INVIERNO, 300.0), false)
	sim._frio_de_una_noche(verano, 8.0,
		_noche(Subsistence.Season.VERANO, 300.0), false)
	assert_gt(invierno.cold, 0.0, "una noche de enero al raso deja frío")
	assert_near(verano.cold, 0.0, 0.0001, "una de agosto, no")


func test_con_fuego_se_entra_en_calor_haga_el_frio_que_haga() -> void:
	var sim := _sim()
	var p := sim.people[0]
	p.cold = 50.0
	sim._frio_de_una_noche(p, 4.0, -8.0, true)
	assert_lt(p.cold, 50.0, "con hoguera, aunque hiele, se recupera")


func test_sin_fuego_y_con_frio_no_se_recupera() -> void:
	var sim := _sim()
	var p := sim.people[0]
	p.cold = 50.0
	sim._frio_de_una_noche(p, 4.0, -8.0, false)
	assert_gt(p.cold, 50.0, "sin hoguera y helando, a peor")


func test_el_vestido_quita_frio_pero_no_lo_quita_todo() -> void:
	var sin_ropa := _sim()
	var con_ropa := _sim()
	for i in range(con_ropa.people.size()):
		con_ropa.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL, 0.6)
	var a := sin_ropa.people[0]
	var b := con_ropa.people[0]
	sin_ropa._frio_de_una_noche(a, 8.0, -4.0, false)
	con_ropa._frio_de_una_noche(b, 8.0, -4.0, false)
	assert_lt(b.cold, a.cold, "con ropa se coge menos frío")
	assert_gt(b.cold, 0.0, "pero se coge: el vestido se suma al fuego, no lo sustituye")


func test_el_frio_no_se_sale_de_escala() -> void:
	var sim := _sim()
	var p := sim.people[0]
	for i in range(40):
		sim._frio_de_una_noche(p, 8.0, -20.0, false)
	assert_near(p.cold, 100.0, 0.001, "el frío tiene techo")


# ------------------------------------------ V2: el frío cierra lo alto --

## Una cumbre fácil —no pide equipo ni cordada— a esa cota. Sin terreno, la
## cota es la `y` de la posición: ver `Cumbres.motivo_del_frio`.
func _cumbre(cota: float) -> Dictionary:
	return {"pos": Vector3(500.0, cota, 500.0), "hard": 0.1}


func _con_estacion(estacion: Subsistence.Season, que: Callable) -> Variant:
	var antes := GameState.season
	GameState.season = estacion
	var r: Variant = que.call()
	GameState.season = antes
	return r


func test_sin_abrigo_no_se_sube_adonde_hiela_de_noche() -> void:
	# EL SEGUNDO CRITERIO DEL FRENTE 7. La peletería es una puerta, como la
	# cuerda para una pared.
	var sim := _sim()
	var motivo: String = _con_estacion(Subsistence.Season.INVIERNO,
		func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(1200.0)))
	assert_false(motivo.is_empty(), "en invierno, arriba y sin ropa, no se sube")


func test_con_abrigo_para_la_cordada_si_se_sube() -> void:
	var sim := _sim()
	for i in range(Cumbres.MIN_CLIMBING_PARTY):
		sim.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL, 0.6)
	var motivo: String = _con_estacion(Subsistence.Season.INVIERNO,
		func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(1200.0)))
	assert_true(motivo.is_empty(), "con un vestido por cada uno que sube, la puerta se abre")


func test_un_vestido_menos_de_los_que_suben_no_basta() -> void:
	var sim := _sim()
	for i in range(Cumbres.MIN_CLIMBING_PARTY - 1):
		sim.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL, 0.6)
	var motivo: String = _con_estacion(Subsistence.Season.INVIERNO,
		func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(1200.0)))
	assert_false(motivo.is_empty(), "si falta abrigo para uno, no sube la cordada")


func test_en_verano_la_misma_cumbre_no_hiela() -> void:
	# No es «en invierno no se sube»: es «adonde hiela no se sube». La misma
	# cumbre en agosto tiene la madrugada por encima del umbral.
	var sim := _sim()
	var motivo: String = _con_estacion(Subsistence.Season.VERANO,
		func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(1200.0)))
	assert_true(motivo.is_empty(), "en verano, sin ropa, se sube")


func test_en_otono_cierra_lo_alto_y_deja_lo_bajo() -> void:
	# Donde la altitud decide de verdad: en otoño la madrugada del llano no
	# hiela y la de la cumbre sí. Es lo que el «si es invierno» no podía decir.
	var sim := _sim()
	var bajo: String = _con_estacion(Subsistence.Season.OTONO,
		func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(100.0)))
	var alto: String = _con_estacion(Subsistence.Season.OTONO,
		func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(1500.0)))
	assert_true(bajo.is_empty(), "en otoño, una loma baja se sube sin ropa")
	assert_false(alto.is_empty(), "y la cumbre alta, no")


func test_la_puerta_y_el_frio_que_castiga_dicen_lo_mismo() -> void:
	# UNA PREGUNTA, UN SITIO. La puerta se cierra exactamente donde la noche al
	# raso empieza a enfriar: si una dijera «hiela» y la otra «no enfría», el
	# jugador se encontraría un sitio cerrado donde no pasa nada, o abierto
	# donde se muere.
	var sim := _sim()
	for cota in [0.0, 300.0, 900.0, 1500.0, 2200.0]:
		for estacion in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
				Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
			var enfria := SettlementSim.frio_por_hora(Termometro.grados(estacion, 3.0, cota)) > 0.0
			var cerrada: bool = not (_con_estacion(estacion,
				func() -> String: return sim.cumbres.motivo_del_frio(_cumbre(cota))) as String).is_empty()
			assert_eq(cerrada, enfria,
				"a %.0f m en %s, la puerta y el frío coinciden" % [cota,
					Subsistence.season_name(estacion)])


func test_el_motivo_llega_por_la_orden_a_mano() -> void:
	# EL MOTIVO QUE EL PANEL DICE. `order_ascent` devuelve el texto que la
	# interfaz enseña; si la puerta se cerrara en silencio, el jugador vería que
	# no sube nadie y no sabría por qué.
	var sim := _sim()
	var respuesta: String = _con_estacion(Subsistence.Season.INVIERNO,
		func() -> String: return sim.cumbres.order_ascent(_cumbre(1200.0)))
	assert_true(respuesta.contains("abrigo"), "la orden dice que falta abrigo")
