class_name TestRelleno
extends TestCase
## El mar de hoy de un valle de costa, rellenado con el suelo de la época, y los ríos que
## siguen por él. GRAFICOS §3, depurar del 2026-09-17.
##
## El valle es de bote —tierra con lomas al oeste, mar a cota cero exacta al este, como lo
## da el LiDAR— pero puesto sobre la costa de verdad, delante de Santander, para que la
## plataforma que lo rellena sea la del mapa regional.

func suite_name() -> String:
	return "Relleno"


const ANCHO := 320
const ALTO := 200
const METROS := 5.0
## Las columnas de tierra: de la 0 a la 149. El resto es el mar de hoy.
const ORILLA := 150
const MAR := -120.0
## Donde el Pas desembocaba en la plataforma: el abrigo de la costa de allí está a −52 m
## (SitiosDeLaCosta). El recuadro se pone con ese punto en la mitad de mar.
const LON := -4.0753
const LAT := 43.5314

static var _regional: HeightmapData = null
static var _rios: RiosDeLaRegion = null


func _base() -> Array:
	if _regional == null:
		_regional = load(PreparaValle.RELIEVE_REGIONAL)
		_rios = RiosDeLaRegion.cargar()
	return [_regional, _rios]


## El valle de bote, con un río que llega a la orilla de hoy.
func _valle() -> HeightmapData:
	var d := HeightmapData.new()
	d.width = ANCHO
	d.height = ALTO
	d.meters_per_sample = METROS
	var lado_lon := float(ANCHO) * METROS / (111320.0 * cos(deg_to_rad(LAT)))
	var lado_lat := float(ALTO) * METROS / 111320.0
	d.lon_west = LON - lado_lon * 0.75
	d.lon_east = LON + lado_lon * 0.25
	d.lat_north = LAT + lado_lat * 0.5
	d.lat_south = LAT - lado_lat * 0.5
	d.geographic_rows = true
	var cotas := PackedFloat32Array()
	cotas.resize(ANCHO * ALTO)
	for z in range(ALTO):
		for x in range(ANCHO):
			if x >= ORILLA:
				continue
			# Una playa: a metro y medio en la orilla, y lomas que crecen tierra adentro.
			var adentro := float(ORILLA - x)
			cotas[z * ANCHO + x] = 1.5 + adentro * 0.3 + minf(adentro / 30.0, 1.0) \
				* (sin(float(x) * 0.21) * 4.0 + cos(float(z) * 0.17) * 5.0 + 9.0)
	d.elevations = cotas
	# EL AGUA COMO LA PONE EL VALLE DE VERDAD, encajando su cauce antes del relleno.
	var puntos := PackedVector2Array()
	for x in range(0, ORILLA, 10):
		puntos.append(Vector2(lerpf(d.lon_west, d.lon_east, float(x) / float(ANCHO - 1)),
			d.lat_for_v(0.5)))
	d.agua_de_osm = {"channels": [{"points": puntos, "half_width_m": 4.0, "kind": "river"}],
		"bodies": []}
	RellenoDelMarDeHoy.pintar_el_agua(d, d.agua_de_osm["channels"], [])
	return d


## Cuántas celdas difieren. Comparar los arreglos con assert_eq vuelca megas en el fallo.
static func _distintas(a: PackedFloat32Array, b: PackedFloat32Array) -> int:
	if a.size() != b.size():
		return maxi(a.size(), b.size())
	var n := 0
	for i in range(a.size()):
		if absf(a[i] - b[i]) > 0.0001:
			n += 1
	return n


func test_el_valle_de_bote_esta_sobre_la_plataforma() -> void:
	var b := _base()
	var plataforma := RelieveDeLaPlataforma.para(b[0], MAR)
	var d := _valle()
	var cota := plataforma.cota_en(LON, LAT)
	assert_true(RellenoDelMarDeHoy.mar_de_hoy(d)[(ALTO / 2) * ANCHO + roundi(0.75 * float(ANCHO - 1))] == 1,
		"el punto cae en el mar de hoy del valle de bote")
	assert_true(cota < 0.0 and cota > MAR,
		"la mitad de mar de hoy cae en plataforma: %.1f m" % cota)


func test_el_mar_de_hoy_es_lo_que_esta_a_cero_y_llega_al_borde() -> void:
	var d := _valle()
	# Una balsa a cero tierra adentro no es mar.
	for z in range(90, 100):
		for x in range(40, 50):
			d.elevations[z * ANCHO + x] = 0.0
	var mascara := RellenoDelMarDeHoy.mar_de_hoy(d)
	var mal := 0
	for z in range(ALTO):
		for x in range(ANCHO):
			var esperado := 1 if x >= ORILLA else 0
			if mascara[z * ANCHO + x] != esperado:
				mal += 1
	assert_eq(mal, 0, "sólo el mar unido al borde, sin la balsa")


## La celda y sus cuatro vecinas a cota cero: el llano de mar que había que quitar.
static func _llano_a_cero(d: HeightmapData, i: int) -> bool:
	for j: int in [i, i - 1, i + 1, i - ANCHO, i + ANCHO]:
		if absf(d.elevations[j]) > 0.01:
			return false
	return true


func test_el_relleno_tiene_relieve_y_no_toca_la_tierra() -> void:
	var b := _base()
	var d := _valle()
	var antes := PackedFloat32Array(d.elevations)
	assert_true(RellenoDelMarDeHoy.poner_al_dia(d, b[0], MAR, b[1]), "había que rellenar")
	var tierra_tocada := 0
	var a_cero := 0
	var lo := INF
	var hi := -INF
	for z in range(ALTO):
		for x in range(ANCHO):
			var i := z * ANCHO + x
			if x < ORILLA:
				# El corredor del río, no: con el cauce más largo su lámina baja más lejos,
				# y [Hydrography] reperfila la ribera unas celdas a cada lado del agua.
				@warning_ignore("integer_division")
				var del_rio := absi(z - ALTO / 2) <= 12
				if not del_rio and not is_equal_approx(d.elevations[i], antes[i]):
					tierra_tocada += 1
				continue
			# Llano a cota cero: la celda y sus cuatro vecinas, que es lo que se veía.
			if x >= ORILLA + 10 and x < ANCHO - 1 and z > 0 and z < ALTO - 1 \
					and _llano_a_cero(d, i):
				a_cero += 1
			# Lejos de la orilla, donde ya no cose.
			if x >= ORILLA + 60:
				lo = minf(lo, d.elevations[i])
				hi = maxf(hi, d.elevations[i])
	assert_eq(tierra_tocada, 0, "la tierra de hoy no se toca, fuera del corredor del río")
	assert_eq(a_cero, 0, "no queda mar de hoy plano a cota cero")
	assert_gt(hi - lo, 5.0, "y lo rellenado tiene relieve: de %.1f a %.1f m" % [lo, hi])
	assert_eq(d.relleno_version, RellenoDelMarDeHoy.sello(), "con su sello")
	assert_near(d.relleno_mar, MAR, 0.01, "y el mar para el que es")


func test_lo_que_queda_bajo_el_mar_esta_unido_al_mar() -> void:
	# La misma regla que el mapa regional: una vaguada que llega al mar es ría y se inunda;
	# una que no llega se levanta como valle. Un hoyo bajo el agua sin salida lo pintaría el
	# plano del mar y sería un lago imposible. Ver [RelieveDeLaPlataforma.rias_y_valles].
	var b := _base()
	var d := _valle()
	RellenoDelMarDeHoy.poner_al_dia(d, b[0], MAR, b[1])
	var bajo := PackedByteArray()
	bajo.resize(ANCHO * ALTO)
	var cola := PackedInt32Array()
	for z in range(ALTO):
		for x in range(ANCHO):
			var i := z * ANCHO + x
			if d.elevations[i] > MAR:
				continue
			bajo[i] = 1
			# Del borde del recuadro para dentro: ahí es donde está la mar abierta.
			if x == 0 or z == 0 or x == ANCHO - 1 or z == ALTO - 1:
				bajo[i] = 2
				cola.append(i)
	var leido := 0
	while leido < cola.size():
		var i := cola[leido]
		leido += 1
		for vecino: int in [i - 1, i + 1, i - ANCHO, i + ANCHO]:
			if vecino < 0 or vecino >= ANCHO * ALTO or bajo[vecino] != 1:
				continue
			if absi(vecino % ANCHO - i % ANCHO) > 1:
				continue
			bajo[vecino] = 2
			cola.append(vecino)
	var sueltas := 0
	for v in bajo:
		if v == 1:
			sueltas += 1
	assert_gt(float(cola.size()), 100.0, "hay mar de la época en el recuadro")
	assert_eq(sueltas, 0, "y nada bajo el agua sin salida al mar")


func test_el_relleno_se_cose_en_la_orilla() -> void:
	# Ni escalón ni cortado: de la última tierra al primer relleno, lo mismo que entre dos
	# celdas cualquiera de un terreno con pendiente.
	var b := _base()
	var d := _valle()
	RellenoDelMarDeHoy.poner_al_dia(d, b[0], MAR, b[1])
	var peor := 0.0
	for z in range(ALTO):
		# El corredor del río no: desde el 2026-09-17 el cauce alargado **se abre** para que
		# el río no remonte, y un cauce abierto tiene sus riberas. Eso es relieve, no
		# costura. Ver [RellenoDelMarDeHoy.abrir_los_cauces].
		@warning_ignore("integer_division")
		if absi(z - ALTO / 2) <= 12:
			continue
		for x in range(ORILLA - 1, ORILLA + 3):
			peor = maxf(peor, absf(d.elevations[z * ANCHO + x + 1] - d.elevations[z * ANCHO + x]))
	assert_true(peor < 3.0, "el mayor salto junto a la orilla: %.2f m en 5 m" % peor)


func test_con_el_mar_de_hoy_no_se_rellena() -> void:
	var b := _base()
	var d := _valle()
	var antes := PackedFloat32Array(d.elevations)
	RellenoDelMarDeHoy.poner_al_dia(d, b[0], 0.0, b[1])
	assert_eq(_distintas(d.elevations, antes), 0, "con el mar a cero, el mar de hoy se queda mar")
	assert_false(RellenoDelMarDeHoy.hace_falta(d, 0.0), "y queda sellado")


func test_cambiar_de_epoca_rehace_el_relleno_igual_que_de_nuevas() -> void:
	# El valle guardado es uno para todas las épocas: pasar por −120 y luego a −50 tiene
	# que dar lo mismo que ir a −50 directamente. Si el primer relleno no se deshiciera,
	# se rellenaría encima.
	var b := _base()
	var pasado := _valle()
	RellenoDelMarDeHoy.poner_al_dia(pasado, b[0], MAR, b[1])
	RellenoDelMarDeHoy.poner_al_dia(pasado, b[0], -50.0, b[1])
	var directo := _valle()
	RellenoDelMarDeHoy.poner_al_dia(directo, b[0], -50.0, b[1])
	assert_eq(_distintas(pasado.elevations, directo.elevations), 0, "las mismas cotas")
	assert_eq(_distintas(pasado.river_mask, directo.river_mask), 0, "y el mismo agua")
	# Y volver al mar de hoy lo deja como el LiDAR.
	RellenoDelMarDeHoy.poner_al_dia(pasado, b[0], 0.0, b[1])
	assert_eq(_distintas(pasado.elevations, _valle().elevations), 0,
		"de vuelta a hoy, como estaba")


func test_el_rio_sigue_por_el_relleno_hasta_una_salida() -> void:
	var b := _base()
	var d := _valle()
	RellenoDelMarDeHoy.poner_al_dia(d, b[0], MAR, b[1])
	var canales: Array = d.agua_de_osm["channels"]
	var mascara := d.mar_de_hoy
	var alargados := RellenoDelMarDeHoy.alargar_los_rios(d, canales, mascara, MAR)
	var original: PackedVector2Array = canales[0]["points"]
	var puntos: PackedVector2Array = alargados[0]["points"]
	assert_gt(float(puntos.size()), float(original.size()), "el río es más largo")
	var ultimo := puntos[puntos.size() - 1]
	var x := d.u_for_lon(ultimo.x) * float(ANCHO - 1)
	var z := d.v_for_lat(ultimo.y) * float(ALTO - 1)
	var cota := d.get_elevation(roundi(x), roundi(z))
	var en_el_borde := x < 5.0 or z < 5.0 or x > float(ANCHO - 6) or z > float(ALTO - 6)
	assert_true(en_el_borde or cota <= MAR + 1.0,
		"y acaba en el borde o en el mar de la época: (%.0f, %.0f) a %.1f m" % [x, z, cota])
	# Y el agua pintada lo lleva: hay cauce en el relleno.
	var mojado := 0
	for zz in range(ALTO):
		for xx in range(ORILLA + 5, ANCHO):
			if d.river_mask[zz * ANCHO + xx] > 0.1:
				mojado += 1
	assert_gt(float(mojado), 20.0, "el cauce se pinta por el relleno: %d celdas" % mojado)


func test_el_valle_se_prepara_con_el_mar_que_le_dicen() -> void:
	# EL FALLO QUE ESTO IMPIDE (2026-09-17): al fundar desde el mapa regional,
	# `Expedition.sea_level_m` **todavía no está puesto** —se pone al entrar al valle, que
	# es después—, así que el valle se preparaba con el mar a cero: el relleno no rellenaba
	# nada y encima quedaba sellado como hecho, con lo que no se reintentaba. Medido en el
	# valle 60 del jugador: sello puesto, mar 0 y 106 470 celdas a cota cero intactas.
	var antes := Expedition.sea_level_m
	Expedition.sea_level_m = 0.0
	var preparador := PreparaValle.new()
	preparador.mar_de_la_epoca = MAR
	var d := _valle()
	assert_true(RellenoDelMarDeHoy.hace_falta(d, preparador._mar()),
		"con el mar dicho, el valle de costa pide relleno")
	assert_near(preparador._mar(), MAR, 0.01, "y el mar es el que le han dicho")
	# Y sin decirle nada, el de la expedición, como siempre.
	var callado := PreparaValle.new()
	assert_near(callado._mar(), 0.0, 0.01, "sin decirle nada, el de la expedición")
	assert_false(RellenoDelMarDeHoy.hace_falta(_relleno_de_hoy(d), 0.0),
		"y con el mar de hoy no hay nada que rellenar")
	Expedition.sea_level_m = antes


## Un valle ya sellado para el mar de hoy.
func _relleno_de_hoy(d: HeightmapData) -> HeightmapData:
	var b := _base()
	RellenoDelMarDeHoy.poner_al_dia(d, b[0], 0.0, b[1])
	return d


# --- que lo que pintamos sea agua de verdad (auditoría del 2026-09-17) ------------

func test_solo_se_pinta_agua_natural_y_ninguna_via() -> void:
	# EL ENCARGO DEL USUARIO: «comprueba que no hayas convertido carreteras en ríos».
	# La consulta del agua y la de las vías son distintas —`way["waterway"]` y
	# `way["natural"="water"]` frente a `way["highway"]`—, y además la tabla de anchos de
	# [OSMWays] deja fuera lo artificial. Esto lo fija: un canal, una acequia, un drenaje o
	# una presa NO son cauce, y una carretera no tiene por dónde entrar.
	var elementos: Array = []
	for clase: String in ["river", "stream", "canal", "ditch", "drain", "dam", "weir",
			"pressurised", "fish_pass"]:
		elementos.append({"id": elementos.size() + 1, "geometry": [
			{"lon": -4.0, "lat": 43.3}, {"lon": -4.001, "lat": 43.301}],
			"tags": {"waterway": clase, "name": clase}})
	# Y una carretera con la geometría de un río: aunque llegara, no se pinta.
	elementos.append({"id": 99, "geometry": [{"lon": -4.0, "lat": 43.3},
		{"lon": -4.001, "lat": 43.301}], "tags": {"highway": "residential"}})
	var agua := OSMWays.parse_water(elementos)
	var clases: Array = []
	for cauce: Dictionary in agua["channels"]:
		clases.append(str(cauce["kind"]))
	clases.sort()
	assert_eq(clases, ["river", "stream"], "sólo el río y el arroyo son cauce")
	assert_eq(agua["bodies"].size(), 0, "y sin láminas")


func test_un_rio_alargado_no_remonta() -> void:
	# UN RÍO NO SUBE. El camino sale de una inundación por prioridad, que busca el paso más
	# bajo pero puede cruzar collados: medido en el valle del sitio 36 antes de abrir el
	# cauce, el Deva remontaba 56 m y el Cabra 181,5 m (auditoría del 2026-09-17). Con el
	# cauce abierto, el mismo valle se queda en 0,5 m y el del sitio 60 en 0,7 m.
	var b := _base()
	var d := _valle()
	RellenoDelMarDeHoy.poner_al_dia(d, b[0], MAR, b[1])
	var canales: Array = d.agua_de_osm["channels"]
	var alargados := RellenoDelMarDeHoy.alargar_los_rios(d, canales, d.mar_de_hoy, MAR)
	RellenoDelMarDeHoy.abrir_los_cauces(d, canales, alargados, MAR)
	var peor := 0.0
	var mirados := 0
	for i in range(canales.size()):
		var antes: PackedVector2Array = canales[i]["points"]
		var ahora: PackedVector2Array = alargados[i]["points"]
		if ahora.size() <= antes.size():
			continue
		mirados += 1
		var sube := 0.0
		var anterior := INF
		for k in range(antes.size() - 1, ahora.size()):
			var e := d.sample_bilinear(clampf(d.u_for_lon(ahora[k].x), 0.0, 1.0),
				clampf(d.v_for_lat(ahora[k].y), 0.0, 1.0))
			# Bajo el mar ya es estuario: el fondo hace lo que quiera.
			if e <= MAR + 1.0:
				break
			if anterior != INF and e > anterior:
				sube += e - anterior
			anterior = e
		peor = maxf(peor, sube)
	assert_gt(float(mirados), 0.0, "hay algún río que siga por el relleno")
	assert_true(peor < 3.0, "el que más remonta sube %.1f m en todo su tramo nuevo" % peor)
