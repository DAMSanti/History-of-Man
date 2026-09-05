class_name TestResourceField
extends TestCase
## Pruebas de los campos de recursos y de su estacionalidad.
##
## Hasta ahora cada actividad tenía UN punto fijo en el mapa: la pesquera, el
## coto. Eso convierte la subsistencia en una lista de coordenadas, cuando lo
## que define a un cazador-recolector es justo lo contrario: el recurso está
## repartido, se mueve con la estación, y saber dónde y cuándo ES el
## conocimiento que la banda va acumulando.


func suite_name() -> String:
	return "Recursos"


func _field() -> ResourceField:
	var field := ResourceField.new()
	field.setup(16, 16, Vector2(1600.0, 1600.0))
	return field


# --- el campo reparte, no concentra en un punto ---------------------------

func test_el_campo_cubre_todo_el_recuadro() -> void:
	var field := _field()
	field.set_abundance(Subsistence.Activity.CAZA, 4, 4, 1.0)
	assert_eq(field.width * field.height, 256, "la rejilla cubre el recuadro entero")
	assert_gt(field.abundance_at(Subsistence.Activity.CAZA, Vector3(450, 0, 450)), 0.0,
		"donde se sembro abundancia, la hay")


func test_una_mancha_se_extiende_a_las_celdas_de_alrededor() -> void:
	# El recurso no vive en una celda suelta: un cotarro de caza es una zona.
	var field := _field()
	field.set_abundance(Subsistence.Activity.CAZA, 8, 8, 1.0)
	field.spread(Subsistence.Activity.CAZA, 2)

	var centro := field.abundance_cell(Subsistence.Activity.CAZA, 8, 8)
	var vecina := field.abundance_cell(Subsistence.Activity.CAZA, 10, 8)
	var lejos := field.abundance_cell(Subsistence.Activity.CAZA, 15, 15)
	assert_gt(vecina, 0.0, "la mancha llega a las celdas de alrededor")
	assert_gt(centro, vecina, "y decae con la distancia al nucleo")
	assert_eq(lejos, 0.0, "sin llegar a la otra punta del recuadro")


func test_fuera_del_recuadro_no_hay_nada() -> void:
	var field := _field()
	field.set_abundance(Subsistence.Activity.CAZA, 8, 8, 1.0)
	assert_eq(field.abundance_at(Subsistence.Activity.CAZA, Vector3(-500, 0, -500)), 0.0,
		"fuera del mapa no hay recurso")


func test_cada_actividad_tiene_su_propio_campo() -> void:
	var field := _field()
	field.set_abundance(Subsistence.Activity.PESCA, 3, 3, 1.0)
	assert_gt(field.abundance_cell(Subsistence.Activity.PESCA, 3, 3), 0.0,
		"la pesca tiene abundancia donde se sembro")
	assert_eq(field.abundance_cell(Subsistence.Activity.CAZA, 3, 3), 0.0,
		"y la caza no la hereda")


# --- estacionalidad --------------------------------------------------------

func test_el_salmon_remonta_en_primavera() -> void:
	var primavera := ResourceField.seasonal_factor(
		Subsistence.Activity.PESCA, Subsistence.Season.PRIMAVERA)
	var invierno := ResourceField.seasonal_factor(
		Subsistence.Activity.PESCA, Subsistence.Season.INVIERNO)
	assert_gt(primavera, invierno, "en primavera hay mucho mas pescado que en invierno")
	assert_gt(primavera, 1.0, "el remonte es un pico, no la media")


func test_la_caza_es_mejor_en_otono() -> void:
	# La berrea concentra los ciervos y llegan cebados del verano
	var otono := ResourceField.seasonal_factor(
		Subsistence.Activity.CAZA, Subsistence.Season.OTONO)
	for season: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.INVIERNO]:
		assert_gt(otono, ResourceField.seasonal_factor(
			Subsistence.Activity.CAZA, season as Subsistence.Season),
			"el otono es la mejor epoca de caza")


func test_la_recoleccion_se_hunde_en_invierno() -> void:
	assert_lt(ResourceField.seasonal_factor(
		Subsistence.Activity.RECOLECCION, Subsistence.Season.INVIERNO), 0.4,
		"en invierno no hay practicamente nada que recolectar")


func test_el_marisqueo_sostiene_el_invierno() -> void:
	# Es lo que dice el registro de los concheros cantabricos: el marisco
	# aguanta justo cuando lo demas falla.
	var invierno := ResourceField.seasonal_factor(
		Subsistence.Activity.MARISQUEO, Subsistence.Season.INVIERNO)
	assert_gt(invierno, ResourceField.seasonal_factor(
		Subsistence.Activity.RECOLECCION, Subsistence.Season.INVIERNO),
		"en invierno el marisco da mas que la recoleccion")
	assert_gt(invierno, 0.9, "el marisqueo no se hunde en invierno")


func test_la_piedra_no_tiene_estacion() -> void:
	var factors: Array[float] = []
	for season in range(4):
		factors.append(ResourceField.seasonal_factor(
			Subsistence.Activity.MATERIA_PRIMA, season as Subsistence.Season))
	for f in factors:
		assert_near(f, factors[0], 0.35, "la piedra esta ahi todo el ano")


func test_el_valor_de_temporada_combina_sitio_y_estacion() -> void:
	var field := _field()
	field.set_abundance(Subsistence.Activity.PESCA, 8, 8, 1.0)
	var punto := Vector3(850.0, 0.0, 850.0)
	var primavera := field.seasonal_abundance_at(
		Subsistence.Activity.PESCA, punto, Subsistence.Season.PRIMAVERA)
	var invierno := field.seasonal_abundance_at(
		Subsistence.Activity.PESCA, punto, Subsistence.Season.INVIERNO)
	assert_gt(primavera, invierno, "el mismo sitio da mas en su temporada")
	assert_gt(primavera, 0.0, "y en temporada da algo")
