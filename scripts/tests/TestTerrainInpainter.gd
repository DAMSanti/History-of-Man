class_name TestTerrainInpainter
extends TestCase
## Pruebas del borrado de obra humana del relieve.
##
## Lo que se comprueba aqui es la parte que NO depende de la red: rasterizar
## geometrias sobre la rejilla y reconstruir la cota por dentro. La descarga de
## OpenStreetMap se prueba a mano, porque probar contra un servicio ajeno es
## probar el servicio.

const TOLERANCE := 0.35


func suite_name() -> String:
	return "Inpainter"


## Rejilla de prueba: un plano inclinado limpio, 1 m por muestra, sobre el que
## luego se talla la carretera. Se usa un plano porque tiene solucion analitica
## conocida: la reconstruccion DEBE devolver exactamente la rampa.
func _slope(width: int = 60, height: int = 60, gradient: float = 2.0) -> HeightmapData:
	var data := HeightmapData.new()
	data.width = width
	data.height = height
	data.meters_per_sample = 1.0
	data.lon_west = -4.0
	data.lon_east = -3.99
	data.lat_north = 43.01
	data.lat_south = 43.00
	data.geographic_rows = true
	data.elevations.resize(width * height)
	for z in range(height):
		for x in range(width):
			data.elevations[z * width + x] = 100.0 + float(x) * gradient
	data.min_elevation = 100.0
	data.max_elevation = 100.0 + float(width - 1) * gradient
	return data


func _count(mask: PackedByteArray) -> int:
	var n := 0
	for v in mask:
		if v != 0:
			n += 1
	return n


# --- rasterizado ---------------------------------------------------------

func test_traza_recta_marca_una_franja() -> void:
	var data := _slope()
	# Una via vertical por el centro del recuadro, de 4 m de semiancho
	var mask := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-3.995, 43.01), Vector2(-3.995, 43.00)]),
		"half_width_m": 4.0, "closed": false,
	}])

	assert_eq(mask.size(), data.width * data.height, "la mascara cubre la rejilla")
	assert_gt(_count(mask), 0, "la traza marca celdas")
	# Franja de ~9 celdas de ancho por 60 de alto: no debe comerse el recuadro
	assert_between(float(_count(mask)) / float(mask.size()), 0.05, 0.30,
		"la franja ocupa una fraccion razonable del recuadro")
	# El centro cae dentro, y la esquina no
	assert_true(mask[30 * data.width + 30] != 0, "el eje de la via queda marcado")
	assert_true(mask[0] == 0, "la esquina lejana no se toca")


func test_semiancho_manda_en_el_grosor() -> void:
	var data := _slope()
	var ancha := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-3.995, 43.01), Vector2(-3.995, 43.00)]),
		"half_width_m": 8.0, "closed": false,
	}])
	var estrecha := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-3.995, 43.01), Vector2(-3.995, 43.00)]),
		"half_width_m": 3.0, "closed": false,
	}])
	assert_gt(float(_count(ancha)), float(_count(estrecha)) * 1.5,
		"una via mas ancha marca bastantes mas celdas")


func test_sin_geometrias_no_marca_nada() -> void:
	var data := _slope()
	assert_eq(_count(TerrainInpainter.build_mask(data, [])), 0,
		"sin vias no se marca ninguna celda")


func test_poligono_cerrado_se_rellena_por_dentro() -> void:
	var data := _slope()
	# Una cantera es un area, no una linea: hay que rellenar el interior
	var mask := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([
			Vector2(-3.9970, 43.0070), Vector2(-3.9930, 43.0070),
			Vector2(-3.9930, 43.0030), Vector2(-3.9970, 43.0030),
			Vector2(-3.9970, 43.0070)]),
		"half_width_m": 1.0, "closed": true,
	}])
	# El centro del cuadrilatero esta dentro aunque no lo cruce ninguna arista
	var cx := int(data.u_for_lon(-3.9950) * float(data.width - 1))
	var cz := int(data.v_for_lat(43.0050) * float(data.height - 1))
	assert_true(mask[cz * data.width + cx] != 0, "el interior del area queda marcado")
	assert_gt(_count(mask), 200, "el area rellena mas que su propio contorno")


# --- reconstruccion ------------------------------------------------------

func test_reconstruye_la_rampa_bajo_una_trinchera() -> void:
	var data := _slope()
	var mask := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-3.995, 43.01), Vector2(-3.995, 43.00)]),
		"half_width_m": 4.0, "closed": false,
	}])

	# Se talla el desmonte: la carretera aplana la ladera a una cota fija
	var esperado := PackedFloat32Array(data.elevations)
	for i in range(mask.size()):
		if mask[i] != 0:
			data.elevations[i] = 130.0

	var reparadas := TerrainInpainter.inpaint(data, mask)
	assert_eq(reparadas, _count(mask), "se repara exactamente lo marcado")

	var peor := 0.0
	for i in range(mask.size()):
		if mask[i] != 0:
			peor = maxf(peor, absf(data.elevations[i] - esperado[i]))
	assert_lt(peor, TOLERANCE, "la ladera vuelve a su pendiente original")


func test_no_toca_lo_que_no_esta_marcado() -> void:
	var data := _slope()
	var mask := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-3.995, 43.01), Vector2(-3.995, 43.00)]),
		"half_width_m": 4.0, "closed": false,
	}])
	var antes := PackedFloat32Array(data.elevations)
	for i in range(mask.size()):
		if mask[i] != 0:
			data.elevations[i] = 130.0

	TerrainInpainter.inpaint(data, mask)

	var intactas := true
	for i in range(mask.size()):
		if mask[i] == 0 and absf(data.elevations[i] - antes[i]) > 0.0001:
			intactas = false
	assert_true(intactas, "el terreno fuera de la mascara queda igual")


func test_terraplen_sobre_valle_tambien_se_quita() -> void:
	# El caso simetrico: no todo son desmontes, un terraplen RELLENA. La
	# reconstruccion tiene que bajar la cota, no solo subirla.
	var data := _slope(60, 60, 0.0)
	for z in range(60):
		for x in range(60):
			# Vaguada en V a lo largo del eje Z
			data.elevations[z * 60 + x] = 100.0 + absf(float(x) - 30.0) * 1.5

	var mask := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-3.995, 43.01), Vector2(-3.995, 43.00)]),
		"half_width_m": 4.0, "closed": false,
	}])
	for i in range(mask.size()):
		if mask[i] != 0:
			data.elevations[i] = 140.0   # el terraplen sobresale mucho

	TerrainInpainter.inpaint(data, mask)

	var centro: float = data.elevations[30 * 60 + 30]
	assert_lt(centro, 115.0, "el terraplen deja de sobresalir")
	assert_gt(centro, 99.0, "y no se hunde por debajo del fondo del valle")


func test_mascara_vacia_no_repara_nada() -> void:
	var data := _slope()
	var mask := PackedByteArray()
	mask.resize(data.width * data.height)
	assert_eq(TerrainInpainter.inpaint(data, mask), 0, "sin marcas no hay nada que reparar")


func test_geometria_fuera_del_recuadro_no_rompe() -> void:
	var data := _slope()
	var mask := TerrainInpainter.build_mask(data, [{
		"points": PackedVector2Array([Vector2(-5.0, 44.0), Vector2(-4.5, 44.5)]),
		"half_width_m": 10.0, "closed": false,
	}])
	assert_eq(_count(mask), 0, "una via lejos del recuadro no marca nada")


# --- anchos por clase ----------------------------------------------------

func test_una_carretera_de_pueblo_cuenta_como_las_demas() -> void:
	# El requisito explicito: no vale con quitar autovias. Una `residential` o
	# una `track` mueven tierra igual y tienen que tener ancho propio.
	for clase: String in ["residential", "unclassified", "track", "service", "tertiary"]:
		assert_gt(OSMWays.half_width_for(clase), 0.0,
			"la clase %s tiene ancho de borrado" % clase)

	assert_gt(OSMWays.half_width_for("primary"), OSMWays.half_width_for("track"),
		"una carretera principal mueve mas tierra que una pista")


func test_los_senderos_no_se_borran() -> void:
	# Un sendero no deja huella en un MDT de 5 m; borrarlo seria inventarse
	# terreno a cambio de nada.
	for clase: String in ["footway", "path", "steps", "cycleway"]:
		assert_eq(OSMWays.half_width_for(clase), 0.0,
			"la clase %s no se borra" % clase)
