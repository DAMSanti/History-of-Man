class_name TestTermometro
extends TestCase
## Cuántos grados hace aquí y ahora.
##
## Las cifras esperadas están calculadas a mano desde las constantes de
## [Termometro] y sus fuentes (CREDITOS.md, «Clima»). Si alguien cambia una
## constante, estas pruebas se ponen rojas — y eso es lo que se quiere: las
## cifras de este sistema **no son de balanceo** y no se tocan para que cuadre
## una partida. Ver docs/SISTEMAS.md §19.


func suite_name() -> String:
	return "Termometro"


# ------------------------------------------- entradas fijas, grados fijos --

func test_la_media_de_cada_estacion_al_nivel_del_mar() -> void:
	# Media de los tres meses de AEMET más la anomalía del final del
	# Magdaleniense. Invierno: (10,8 + 10,0 + 9,9)/3 − 5,0 = 5,23.
	assert_near(Termometro.media_de_la_estacion(Subsistence.Season.INVIERNO),
		5.23, 0.02, "el invierno del Magdaleniense final, al nivel del mar")
	# Verano: (18,1 + 20,1 + 20,8)/3 − 2,0 = 17,67.
	assert_near(Termometro.media_de_la_estacion(Subsistence.Season.VERANO),
		17.67, 0.02, "y su verano")
	# Primavera: (11,6 + 12,9 + 15,6)/3 − 3,5 = 9,87.
	assert_near(Termometro.media_de_la_estacion(Subsistence.Season.PRIMAVERA),
		9.87, 0.02, "y su primavera")
	# Otoño: (18,9 + 16,5 + 12,8)/3 − 3,5 = 12,57.
	assert_near(Termometro.media_de_la_estacion(Subsistence.Season.OTONO),
		12.57, 0.02, "y su otoño")


func test_el_dia_es_mas_caliente_que_la_noche_y_a_su_hora() -> void:
	var verano := Subsistence.Season.VERANO
	var tarde := Termometro.grados(verano, Termometro.HORA_MAS_CALIDA, 0.0)
	var madrugada := Termometro.grados(verano, 3.0, 0.0)
	assert_near(tarde, 17.67 + Termometro.MEDIO_DIA, 0.02,
		"a media tarde se suma la oscilación entera")
	assert_near(madrugada, 17.67 - Termometro.MEDIO_DIA, 0.02,
		"y antes del alba se resta entera")
	assert_gt(tarde - madrugada, 7.0, "el día y la noche no se parecen")


func test_el_maximo_cae_por_la_tarde_y_no_al_mediodia() -> void:
	# El suelo sigue soltando calor un par de horas después de que el sol esté
	# más alto. Es la razón de que `HORA_MAS_CALIDA` sea 15 y no 12.
	var verano := Subsistence.Season.VERANO
	assert_gt(Termometro.grados(verano, 15.0, 0.0),
		Termometro.grados(verano, 12.0, 0.0),
		"las tres de la tarde, más que el mediodía")


# ------------------------------------------------- la altitud, que es física --

func test_el_gradiente_vertical_es_el_de_la_atmosfera() -> void:
	# 0,65 °C por cada 100 m NO es una cifra de balanceo: es física. Si el
	# roquedo resulta inhabitable, lo que se cambia es el roquedo.
	assert_near(Termometro.GRADIENTE_POR_100M, 0.65, 0.0001,
		"el gradiente térmico vertical")


func test_cien_metros_de_cota_cuestan_su_grado_y_medio_largo() -> void:
	var verano := Subsistence.Season.VERANO
	var abajo := Termometro.grados(verano, 12.0, 0.0)
	var arriba := Termometro.grados(verano, 12.0, 100.0)
	assert_near(abajo - arriba, 0.65, 0.0001, "cien metros, 0,65 grados")


func test_entre_la_cueva_y_el_roquedo_hay_la_diferencia_que_toca() -> void:
	# La cueva del enclave inicial está baja y el roquedo alto. Con 280 m de
	# diferencia de cota, 1,82 grados, y siempre a favor de la cueva.
	var invierno := Subsistence.Season.INVIERNO
	var cueva := Termometro.grados(invierno, 6.0, 120.0)
	var roquedo := Termometro.grados(invierno, 6.0, 400.0)
	assert_near(cueva - roquedo, 1.82, 0.01,
		"280 m de cota son 1,82 grados")
	assert_gt(cueva, roquedo, "arriba siempre hace más frío")


# ---------------------------------------- el invierno y el verano no se parecen --

func test_el_mediodia_de_verano_y_la_noche_de_invierno_no_se_parecen() -> void:
	# Criterio explícito de EPOCA_01 §10.1, frente 3. En la boca de la cueva.
	var cota := 120.0
	var verano := Termometro.grados(Subsistence.Season.VERANO, 15.0, cota)
	var invierno := Termometro.grados(Subsistence.Season.INVIERNO, 3.0, cota)
	assert_gt(verano - invierno, 15.0,
		"del mediodía de agosto a la madrugada de enero hay un mundo")
	assert_lt(invierno, 3.0, "la noche de invierno ronda el cero")


func test_la_epoca_es_mas_ESTACIONAL_que_hoy_no_solo_mas_fria() -> void:
	# ES EL HALLAZGO QUE IMPORTA, y viene de la fuente, no de una decisión: el
	# final del Magdaleniense no era «como hoy pero más frío». El verano se
	# parecía al de ahora y el invierno no se parecía en nada. De ahí que el
	# abrigo sea una puerta y no un porcentaje.
	assert_lt(Termometro.ANOMALIA_INVIERNO, Termometro.ANOMALIA_VERANO,
		"el invierno se desfasa más que el verano")
	var salto_hoy := (18.1 + 20.1 + 20.8) / 3.0 - (10.8 + 10.0 + 9.9) / 3.0
	var verano_entonces := Termometro.media_de_la_estacion(Subsistence.Season.VERANO)
	var invierno_entonces := Termometro.media_de_la_estacion(Subsistence.Season.INVIERNO)
	var salto_entonces := verano_entonces - invierno_entonces
	assert_gt(salto_entonces, salto_hoy,
		"la distancia entre verano e invierno era mayor que hoy")


func test_todas_las_estaciones_tienen_respuesta() -> void:
	# Sin esto, una estación sin entrada en la tabla caería al invierno por el
	# valor por defecto y nadie se enteraría.
	for estacion in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		var media := Termometro.media_de_la_estacion(estacion)
		assert_between(media, 0.0, 25.0, "una temperatura creíble")


func test_la_misma_pregunta_da_siempre_la_misma_respuesta() -> void:
	# No hay azar aquí dentro, y no puede haberlo: esto lo van a preguntar el
	# hogar, el vivac y la ropa, y tienen que oír lo mismo los tres.
	var una := Termometro.grados(Subsistence.Season.OTONO, 9.5, 240.0)
	var otra := Termometro.grados(Subsistence.Season.OTONO, 9.5, 240.0)
	assert_eq(una, otra, "misma entrada, misma salida")


# --------------------------------------------- la cota de nieve (V3) --

func test_la_cota_de_hielo_de_invierno_es_la_de_la_madrugada() -> void:
	# Donde la madrugada de invierno llega a 0 °C: 1,43 °C al nivel del mar
	# entre 0,65 por cada 100 m, ~220 m. Con la media saldría ~805 m, y en el
	# valle de partida no nevaría nunca: se decidió la madrugada por eso.
	assert_near(Termometro.cota_de_hielo(Subsistence.Season.INVIERNO), 220.5, 1.0,
		"en invierno hiela de madrugada a partir de ~220 m")


func test_la_nieve_sube_del_invierno_al_verano() -> void:
	var invierno := Termometro.cota_de_hielo(Subsistence.Season.INVIERNO)
	var primavera := Termometro.cota_de_hielo(Subsistence.Season.PRIMAVERA)
	var verano := Termometro.cota_de_hielo(Subsistence.Season.VERANO)
	assert_lt(invierno, primavera, "en primavera la nieve está más arriba")
	assert_lt(primavera, verano, "y en verano, más todavía")
	assert_gt(verano, 2000.0, "por encima de casi toda Cantabria")


func test_la_cota_es_de_la_montana_no_del_mapa() -> void:
	# EL PROBLEMA QUE ARREGLA: la cota era una fracción del relieve local, así
	# que dependía del mapa. Ahora la montaña manda: los mismos metros caen en
	# fracciones distintas según el mapa, y no al revés.
	var bajo := Temporada.new()
	bajo.relieve = Vector2(96.0, 718.0)
	var alto := Temporada.new()
	alto.relieve = Vector2(400.0, 2600.0)
	var metros := Termometro.cota_de_hielo(Subsistence.Season.INVIERNO)
	assert_near(bajo.fraccion_de(Subsistence.Season.INVIERNO),
		(metros - 96.0) / 622.0, 0.001, "en el valle, su fracción")
	assert_lt(alto.fraccion_de(Subsistence.Season.INVIERNO), 0.0,
		"en un mapa que empieza a 400 m, nieva hasta abajo en invierno")


func test_en_el_valle_de_partida_solo_nieva_en_invierno() -> void:
	var t := Temporada.new()
	t.relieve = Vector2(96.0, 718.0)
	assert_lt(t.fraccion_de(Subsistence.Season.INVIERNO), 1.0,
		"en invierno la nieve cae dentro del mapa")
	for estacion in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO]:
		assert_gt(t.fraccion_de(estacion), 1.0,
			"el resto del año, por encima del mapa entero")


func test_sin_relieve_conocido_no_nieva() -> void:
	# No se sabe contra qué medir, y se dice «por encima de todo» en vez de
	# inventar una nevada.
	assert_gt(Temporada.new().fraccion_de(Subsistence.Season.INVIERNO), 1.0,
		"sin relieve no hay nieve")
