class_name TestSiteRecord
extends TestCase
## Pruebas de la taxonomia del registro arqueologico y del filtro por epoca.
##
## Es donde mas errores he cometido: meter simas en la lista de cavidades y
## tratar lo construido como si ya existiera al empezar la partida.

var _shelter: Site


func suite_name() -> String:
	return "SiteRecord"


func before_each() -> void:
	_shelter = Site.new()
	_shelter.elevation = 172.0
	_shelter.slope_deg = 10.0
	_shelter.water_km = 0.3
	_shelter.coast_km = 12.8
	_shelter.has_shelter = true


func test_lo_natural_existe_desde_el_principio() -> void:
	for f: int in [Site.Feature.ABRIGO, Site.Feature.SIMA,
			Site.Feature.CAVIDAD, Site.Feature.SURGENCIA]:
		assert_true(Site.feature_is_natural(f as Site.Feature),
			"%s es natural, ya estaba ahi" % Site.feature_name(f as Site.Feature))


func test_lo_construido_no_existe_al_empezar() -> void:
	# Un dolmen o una ermita los levanto alguien DURANTE la partida: ponerlos
	# en el mapa inicial es un anacronismo.
	for f: int in [Site.Feature.MEGALITO, Site.Feature.CASTRO,
			Site.Feature.ROMANO, Site.Feature.CULTO, Site.Feature.DEFENSIVO]:
		assert_false(Site.feature_is_natural(f as Site.Feature),
			"%s lo construyo alguien" % Site.feature_name(f as Site.Feature))


func test_cada_construccion_pertenece_a_su_epoca() -> void:
	assert_eq(Site.feature_era(Site.Feature.MEGALITO), Site.Era.NEOLITICO,
		"los megalitos son neoliticos")
	assert_eq(Site.feature_era(Site.Feature.CASTRO), Site.Era.METALES,
		"los castros son de la Edad del Hierro")
	assert_eq(Site.feature_era(Site.Feature.CULTO), Site.Era.HISTORICA,
		"las ermitas son medievales")


func test_en_el_paleolitico_no_se_ve_una_ermita() -> void:
	_shelter.features = [
		{"name": "Cueva X", "class": Site.Feature.ABRIGO, "lat": 0.0, "lon": 0.0},
		{"name": "Ermita Y", "class": Site.Feature.CULTO, "lat": 0.0, "lon": 0.0},
		{"name": "Dolmen Z", "class": Site.Feature.MEGALITO, "lat": 0.0, "lon": 0.0},
	]
	var visible := _shelter.features_in(Site.Era.PALEOLITICO)
	assert_eq(visible.size(), 1, "en el Paleolitico solo se ve lo natural")
	assert_eq(visible[0]["class"], Site.Feature.ABRIGO, "y lo natural es el abrigo")


func test_en_epoca_historica_se_ve_todo() -> void:
	_shelter.features = [
		{"name": "Cueva X", "class": Site.Feature.ABRIGO, "lat": 0.0, "lon": 0.0},
		{"name": "Ermita Y", "class": Site.Feature.CULTO, "lat": 0.0, "lon": 0.0},
	]
	assert_eq(_shelter.features_in(Site.Era.HISTORICA).size(), 2,
		"para entonces la ermita ya esta construida")


func test_una_sima_no_cuenta_como_abrigo() -> void:
	# El error que dejaba los emplazamientos paleoliticos llenos de torcas.
	_shelter.features = [
		{"name": "Torca A", "class": Site.Feature.SIMA, "lat": 0.0, "lon": 0.0},
		{"name": "Sima B", "class": Site.Feature.SIMA, "lat": 0.0, "lon": 0.0},
		{"name": "Cueva C", "class": Site.Feature.ABRIGO, "lat": 0.0, "lon": 0.0},
	]
	assert_eq(_shelter.cave_count(), 1, "solo una es abrigo habitable")
	assert_eq(_shelter.shaft_count(), 2, "las otras dos son pozos verticales")


func test_las_atestiguaciones_son_solo_lo_construido() -> void:
	_shelter.features = [
		{"name": "Cueva C", "class": Site.Feature.ABRIGO, "lat": 0.0, "lon": 0.0},
		{"name": "Castro D", "class": Site.Feature.CASTRO, "lat": 0.0, "lon": 0.0},
	]
	var att := _shelter.attestations()
	assert_eq(att.size(), 1, "solo lo construido atestigua ocupacion posterior")
	assert_eq(att[0]["name"], "Castro D", "y es el castro")


func test_el_paleolitico_exige_abrigo() -> void:
	assert_true(_shelter.is_usable_in(Site.Era.PALEOLITICO),
		"con abrigo se puede ocupar: la cueva ES la vivienda")
	_shelter.has_shelter = false
	assert_false(_shelter.is_usable_in(Site.Era.PALEOLITICO),
		"sin abrigo no, porque no hay tecnica para construir vivienda")


func test_desde_el_neolitico_se_construye() -> void:
	_shelter.has_shelter = false
	_shelter.slope_deg = 8.0
	_shelter.water_km = 1.0
	assert_true(_shelter.is_usable_in(Site.Era.NEOLITICO),
		"ya se levanta poblado sin depender de una cueva")


func test_un_sitio_sumergido_no_esta_disponible() -> void:
	_shelter.elevation = -40.0
	assert_false(_shelter.is_available(0.0), "con el mar actual esta bajo el agua")
	assert_true(_shelter.is_available(-120.0), "con el mar glacial emerge")


func test_la_costa_se_mueve_y_reclasifica() -> void:
	# Portus Blendium no puede existir en el Paleolitico: entonces era interior.
	_shelter.coast_km_by_era = PackedFloat32Array([0.5, 9.0, 13.0])
	_shelter.prominence = 10.0
	assert_eq(_shelter.kind_at(0), Site.Kind.COSTERO, "hoy esta al pie del mar")
	assert_false(_shelter.kind_at(2) == Site.Kind.COSTERO,
		"con el mar 120 m mas bajo queda tierra adentro")


func test_rejilla_geografica_y_mercator_no_se_confunden() -> void:
	# Las dos fuentes reparten las filas distinto: terrarium es Mercator y el
	# MDT del IGN viene en grados. Confundirlas desplaza el emplazamiento
	# respecto a sus propias cuevas.
	var geo := HeightmapData.new()
	geo.lat_north = 43.30
	geo.lat_south = 43.26
	geo.geographic_rows = true

	var merc := HeightmapData.new()
	merc.lat_north = 43.30
	merc.lat_south = 43.26
	merc.geographic_rows = false

	assert_near(geo.v_for_lat(43.30), 0.0, 0.001, "el borde norte es v=0")
	assert_near(geo.v_for_lat(43.26), 1.0, 0.001, "el borde sur es v=1")
	assert_near(merc.v_for_lat(43.30), 0.0, 0.001, "tambien en Mercator")
	assert_near(merc.v_for_lat(43.26), 1.0, 0.001, "tambien en Mercator")

	assert_near(geo.v_for_lat(43.28), 0.5, 0.001,
		"en grados el centro cae en la mitad exacta")
	assert_false(is_equal_approx(geo.v_for_lat(43.28), merc.v_for_lat(43.28)),
		"Mercator NO reparte igual: por eso hay que distinguirlas")


func test_la_longitud_se_reparte_igual_en_ambas() -> void:
	var h := HeightmapData.new()
	h.lon_west = -4.45
	h.lon_east = -4.41
	assert_near(h.u_for_lon(-4.45), 0.0, 0.001, "borde oeste")
	assert_near(h.u_for_lon(-4.41), 1.0, 0.001, "borde este")
	assert_near(h.u_for_lon(-4.43), 0.5, 0.001, "la longitud si es lineal en ambas")
