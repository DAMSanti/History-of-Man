class_name TestMapaRegional
extends TestCase
## Lo que el mapa regional enseña de cada sitio y de la banda.
##
## Frente 18 de EPOCA_01 §10.1, tanda 4.


## El mapa regional no tiene `class_name` —es la escena de arranque—, así que
## sus funciones estáticas se piden por el guion.
const Mapa := preload("res://scripts/region/RegionMap.gd")


func suite_name() -> String:
	return "MapaRegional"


func _sitio() -> Site:
	var site := Site.new()
	site.id = 56
	site.historical_name = "Cuevona"
	site.water_km = 0.3
	site.has_shelter = true
	return site


func test_de_un_sitio_sin_descubrir_no_se_ve_nada() -> void:
	var lineas: PackedStringArray = Mapa.ficha_del_sitio(_sitio(), false,
		[{"sitio": 56, "trato": {56: 40.0}, "cuevas_exploradas": 2}])
	var texto := "\n".join(lineas)
	assert_false(texto.contains("Cuevona"), "ni el nombre")
	assert_false(texto.contains("Trato"), "ni el trato")
	assert_false(texto.contains("explorada"), "ni sus cuevas")


func test_de_un_sitio_descubierto_se_ve_gente_trato_recursos_y_cueva() -> void:
	var cabeceras: Array[Dictionary] = [{"sitio": 56, "jornada": 30,
		"trato": {56: 40.0}, "cuevas_exploradas": 1, "cuevas_pintables": 1}]
	var texto := "\n".join(Mapa.ficha_del_sitio(_sitio(), true, cabeceras))
	assert_true(texto.contains("Vive gente"), "si tiene gente")
	assert_true(texto.contains("Trato bueno"), "y el trato con ella")
	assert_true(texto.contains("agua cerca"), "qué recursos se conocen")
	assert_true(texto.contains("1 cueva explorada"), "y el estado de su cueva")


func test_la_cueva_pintada_se_dice() -> void:
	var cabeceras: Array[Dictionary] = [{"sitio": 56, "pintada": true}]
	var texto := "\n".join(Mapa.ficha_del_sitio(_sitio(), true, cabeceras))
	assert_true(texto.contains("pintada"), "la cueva está pintada")


func test_el_panel_dice_donde_esta_la_banda_y_la_jornada_de_cada_mapa() -> void:
	var cabeceras: Array[Dictionary] = [
		{"sitio": 56, "jornada": 40, "poblacion": 12},
		{"sitio": 12, "jornada": 7, "poblacion": 3},
	]
	var lineas: PackedStringArray = Mapa.panel_de_la_banda(cabeceras, 56,
		{56: "Cuevona", 12: "El Pendo"})
	var texto := "\n".join(lineas)
	assert_true(texto.contains("Cuevona · jornada 40"), "la jornada de cada mapa")
	assert_true(texto.contains("El Pendo · jornada 7"), "de todos")
	assert_true(texto.contains("la banda está aquí"), "dónde vive la banda")
	assert_true(texto.contains("F para volver"), "y cómo volver")


func test_sin_mapas_guardados_lo_dice() -> void:
	var sin: Array[Dictionary] = []
	var una: PackedStringArray = Mapa.panel_de_la_banda(sin, -1, {})
	assert_eq(una.size(), 1,
		"una línea: todavía no se ha asentado")
