class_name TestFording
extends TestCase
## Pruebas del cruce de cauces.
##
## Un río no es una textura azul: es un obstáculo. Un arroyo de dos metros se
## cruza saltando, uno de seis se vadea mojándose, y el Nansa no se cruza a pie
## por mucho que se quiera. Sin esto la banda camina en línea recta sobre el
## agua como si no estuviera, que es lo que hacía hasta ahora.


func suite_name() -> String:
	return "Vadeo"


func _grid() -> HeightmapData:
	var data := HeightmapData.new()
	data.width = 80
	data.height = 80
	data.meters_per_sample = 5.0
	data.lon_west = -4.0
	data.lon_east = -3.99
	data.lat_north = 43.01
	data.lat_south = 43.00
	data.geographic_rows = true
	data.elevations.resize(80 * 80)
	data.elevations.fill(100.0)
	return data


## Cauce norte-sur por el centro, del ancho que se pida.
func _cauce(half_width: float, kind: String) -> Dictionary:
	return {
		"points": PackedVector2Array([Vector2(-3.995, 43.010), Vector2(-3.995, 43.000)]),
		"half_width_m": half_width,
		"kind": kind,
		"closed": false,
	}


func _en_el_eje(data: HeightmapData) -> float:
	# El eje del cauce cae en el centro del recuadro
	return data.ford_mask[40 * data.width + 40]


# --- dificultad segun el calado --------------------------------------------

func test_un_arroyo_pequeno_se_cruza_saltando() -> void:
	var data := _grid()
	Hydrography.apply(data, [_cauce(1.5, "stream")], [])
	assert_lt(_en_el_eje(data), Hydrography.FORD_WADEABLE,
		"un arroyo de 3 m se pasa sin mojarse")


func test_un_arroyo_mediano_se_vadea() -> void:
	var data := _grid()
	Hydrography.apply(data, [_cauce(4.0, "stream")], [])
	var d := _en_el_eje(data)
	assert_between(d, Hydrography.FORD_WADEABLE, Hydrography.FORD_IMPASSABLE,
		"un arroyo de 8 m se vadea, pero cuesta")


func test_un_rio_no_se_cruza_a_pie() -> void:
	var data := _grid()
	Hydrography.apply(data, [_cauce(11.0, "river")], [])
	assert_gt(_en_el_eje(data), Hydrography.FORD_IMPASSABLE,
		"un rio de 22 m necesita puente o embarcacion")


func test_mas_ancho_es_siempre_mas_dificil() -> void:
	var anterior := -1.0
	for half_width: float in [1.0, 3.0, 6.0, 10.0, 16.0]:
		var data := _grid()
		Hydrography.apply(data, [_cauce(half_width, "stream")], [])
		var d := _en_el_eje(data)
		assert_gt(d, anterior, "a %.0f m de semiancho cuesta mas que al anterior" % half_width)
		anterior = d


func test_una_laguna_no_se_vadea() -> void:
	var data := _grid()
	Hydrography.apply(data, [], [{
		"points": PackedVector2Array([
			Vector2(-3.9970, 43.0070), Vector2(-3.9930, 43.0070),
			Vector2(-3.9930, 43.0030), Vector2(-3.9970, 43.0030),
			Vector2(-3.9970, 43.0070)]),
		"kind": "lake",
	}])
	var cx := int(data.u_for_lon(-3.9950) * float(data.width - 1))
	var cz := int(data.v_for_lat(43.0050) * float(data.height - 1))
	assert_gt(data.ford_mask[cz * data.width + cx], Hydrography.FORD_IMPASSABLE,
		"un lago no tiene fondo que pisar")


func test_en_tierra_seca_no_cuesta_nada() -> void:
	var data := _grid()
	Hydrography.apply(data, [_cauce(11.0, "river")], [])
	assert_eq(data.ford_mask[40 * data.width + 70], 0.0,
		"lejos del cauce se anda sin obstaculo")


# --- cruzar un trayecto ----------------------------------------------------

func test_un_trayecto_que_cruza_el_rio_esta_cortado() -> void:
	var data := _grid()
	Hydrography.apply(data, [_cauce(11.0, "river")], [])
	# De orilla a orilla, atravesando el cauce
	var coste := Hydrography.worst_crossing(data,
		Vector2(20.0 * 5.0, 40.0 * 5.0), Vector2(60.0 * 5.0, 40.0 * 5.0))
	assert_gt(coste, Hydrography.FORD_IMPASSABLE, "el trayecto cruza un rio infranqueable")


func test_un_trayecto_por_la_misma_orilla_pasa() -> void:
	var data := _grid()
	Hydrography.apply(data, [_cauce(11.0, "river")], [])
	# Paralelo al cauce y bien lejos de el
	var coste := Hydrography.worst_crossing(data,
		Vector2(15.0 * 5.0, 10.0 * 5.0), Vector2(15.0 * 5.0, 70.0 * 5.0))
	assert_lt(coste, Hydrography.FORD_WADEABLE, "por la orilla no hay que cruzar nada")


func test_el_trayecto_mira_el_punto_peor_no_la_media() -> void:
	# Un vado de 100 m no compensa un rio de 20: lo que decide si se puede
	# pasar es el peor punto del camino, no el promedio.
	var data := _grid()
	Hydrography.apply(data, [_cauce(11.0, "river")], [])
	var coste := Hydrography.worst_crossing(data,
		Vector2(5.0 * 5.0, 40.0 * 5.0), Vector2(75.0 * 5.0, 40.0 * 5.0))
	assert_gt(coste, Hydrography.FORD_IMPASSABLE,
		"un trayecto largo no diluye un obstaculo infranqueable")


func test_sin_agua_todo_trayecto_es_libre() -> void:
	var data := _grid()
	Hydrography.apply(data, [], [])
	assert_eq(Hydrography.worst_crossing(data, Vector2(0, 0), Vector2(390.0, 390.0)), 0.0,
		"sin cauces no hay nada que cruzar")


# --- la estacion manda tanto como el ancho ---------------------------------

func test_en_estiaje_se_vadea_lo_que_en_avenida_no() -> void:
	# Un rio no es una barrera fija: el mismo cauce que en marzo va bravo, en
	# agosto se pasa por las barras de grava con el agua por la rodilla. Que
	# fuera infranqueable todo el ano era demasiado restrictivo.
	var rio := Hydrography.crossing_difficulty_for_width(22.0)
	assert_false(Hydrography.can_cross(rio, false, false, Subsistence.Season.INVIERNO),
		"en invierno el rio va crecido y no se pasa")
	assert_true(Hydrography.can_cross(rio, false, false, Subsistence.Season.VERANO),
		"en verano, con el agua baja, si")


func test_el_verano_es_la_epoca_de_menos_agua() -> void:
	var previo := -9.0
	for season: int in [Subsistence.Season.VERANO, Subsistence.Season.OTONO,
			Subsistence.Season.PRIMAVERA, Subsistence.Season.INVIERNO]:
		var mod := Hydrography.seasonal_ford_modifier(season as Subsistence.Season)
		assert_gt(mod, previo, "el agua sube segun avanza el ano hacia el invierno")
		previo = mod


func test_el_deshielo_de_primavera_complica_el_paso() -> void:
	assert_gt(Hydrography.seasonal_ford_modifier(Subsistence.Season.PRIMAVERA),
		Hydrography.seasonal_ford_modifier(Subsistence.Season.OTONO),
		"el deshielo trae mas agua que el estiaje de otono")


func test_ni_en_verano_se_vadea_una_ria() -> void:
	# La estacion mueve el umbral, no lo borra
	var ria := Hydrography.crossing_difficulty_for_width(80.0)
	assert_false(Hydrography.can_cross(ria, false, false, Subsistence.Season.VERANO),
		"ochenta metros de agua no se vadean en agosto tampoco")


func test_un_arroyo_se_pasa_en_cualquier_epoca() -> void:
	var arroyo := Hydrography.crossing_difficulty_for_width(4.0)
	for season in range(4):
		assert_true(Hydrography.can_cross(arroyo, false, false,
			season as Subsistence.Season),
			"un arroyo de cuatro metros se salta todo el ano")


# --- que permite cruzar ----------------------------------------------------

func test_sin_tecnologia_solo_se_pasan_los_vados() -> void:
	# En el Paleolitico no hay puentes. Lo unico que se cruza es lo que se
	# puede vadear andando.
	assert_true(Hydrography.can_cross(0.2, false, false), "un arroyo se salta")
	assert_true(Hydrography.can_cross(Hydrography.FORD_WADEABLE + 0.1, false, false),
		"un vado se pasa mojandose")
	assert_false(Hydrography.can_cross(Hydrography.FORD_IMPASSABLE + 0.1, false, false),
		"un rio no se cruza a pelo")


func test_la_embarcacion_abre_los_rios() -> void:
	assert_true(Hydrography.can_cross(Hydrography.FORD_IMPASSABLE + 0.1, true, false),
		"con embarcacion se cruza el rio")


func test_el_puente_abre_los_rios() -> void:
	assert_true(Hydrography.can_cross(Hydrography.FORD_IMPASSABLE + 0.1, false, true),
		"con puente se cruza el rio")


func test_ni_el_puente_ni_la_barca_hacen_andar_sobre_el_agua() -> void:
	# El tope superior queda reservado a la mar abierta y a las laminas
	# grandes: un puente de troncos no cruza una ria.
	assert_false(Hydrography.can_cross(1.0, false, true),
		"un puente de la epoca no salva cualquier anchura")
