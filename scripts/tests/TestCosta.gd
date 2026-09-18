class_name TestCosta
extends TestCase
## La costa de la época: los abrigos hipotéticos de la plataforma y su valle.
##
## EPOCA_01 §10.2. Lo que se comprueba aquí son las REGLAS —dónde salen, qué se
## cruza, qué da la orilla— con relieve construido; lo que cuesta una partida
## entera en la costa lo mide `CostaProbe`.


func suite_name() -> String:
	return "Costa"


## Una rejilla regional de juguete: un plano que baja de +200 m al este a −400 m
## al oeste, con la costa del Paleolítico por el medio.
func _rejilla() -> HeightmapData:
	var datos := HeightmapData.new()
	datos.width = 64
	datos.height = 48
	datos.meters_per_sample = 111.0
	datos.lat_north = 43.6
	datos.lat_south = 43.1
	datos.lon_west = -4.6
	datos.lon_east = -3.8
	datos.geographic_rows = true
	var cotas := PackedFloat32Array()
	cotas.resize(datos.width * datos.height)
	for z in range(datos.height):
		for x in range(datos.width):
			cotas[z * datos.width + x] = lerpf(-400.0, 200.0,
				float(x) / float(datos.width - 1)) + float(z) * 0.5
	datos.elevations = cotas
	return datos


func test_la_cota_de_un_punto_casa_con_la_rejilla_con_lomas() -> void:
	# En las muestras de la rejilla, preguntar un punto y aplicar las lomas a la
	# rejilla entera tienen que dar lo mismo: si no, el valle de un sitio de la
	# plataforma no casaría con lo que se ve en el mapa.
	var limpia := _rejilla()
	var plataforma := RelieveDeLaPlataforma.para(limpia, -120.0)
	var con_lomas := _rejilla()
	RelieveDeLaPlataforma.aplicar(con_lomas, -120.0)
	var peor := 0.0
	var en_la_plataforma := 0
	for z in range(0, limpia.height, 3):
		for x in range(0, limpia.width, 3):
			var lon := lerpf(limpia.lon_west, limpia.lon_east,
				float(x) / float(limpia.width - 1))
			var lat := lerpf(limpia.lat_north, limpia.lat_south,
				float(z) / float(limpia.height - 1))
			var e := limpia.get_elevation(x, z)
			if e > -120.0 and e < 0.0:
				en_la_plataforma += 1
			peor = maxf(peor, absf(plataforma.cota_en(lon, lat)
				- con_lomas.get_elevation(x, z)))
	assert_true(en_la_plataforma > 10, "la rejilla tiene plataforma que probar")
	assert_near(peor, 0.0, 1.0, "la cota del punto es la de la rejilla con lomas")


func test_fuera_de_la_plataforma_no_sube_nada() -> void:
	var limpia := _rejilla()
	var plataforma := RelieveDeLaPlataforma.para(limpia, -120.0)
	# Mar adentro (−400 m, más hondo que [HONDO_DEL_DETALLE_M] bajo la lámina) y tierra de
	# hoy (+200 m): se quedan como estaban.
	assert_near(plataforma.cota_en(-4.6, 43.35), limpia.sample_bilinear(0.0,
		limpia.v_for_lat(43.35)), 0.01, "el fondo del mar no se toca")
	assert_near(plataforma.cota_en(-3.8, 43.35), limpia.sample_bilinear(1.0,
		limpia.v_for_lat(43.35)), 0.01, "ni la tierra de hoy")


func test_las_lomas_no_hacen_terrazas_entre_muestras() -> void:
	# La distancia a la costa se lee interpolada: entre dos muestras vecinas la
	# cota no puede dar un salto mayor que el de las dos muestras.
	var limpia := _rejilla()
	var plataforma := RelieveDeLaPlataforma.para(limpia, -120.0)
	var lat := 43.35
	var antes := plataforma.cota_en(-4.35, lat)
	var peor := 0.0
	for i in range(1, 400):
		var lon := -4.35 + float(i) * 0.0005
		var ahora := plataforma.cota_en(lon, lat)
		peor = maxf(peor, absf(ahora - antes))
		antes = ahora
	# Cada paso son unos 40 m: con lomas de 2 km no hay razón para saltar más de
	# unos metros de uno a otro.
	assert_true(peor < 15.0, "sin terrazas: el mayor salto en 40 m es %.1f m" % peor)


# --- Los ríos de la época por la plataforma (tarea 3) --------------------------


func _lon_de(datos: HeightmapData, x: int) -> float:
	return lerpf(datos.lon_west, datos.lon_east, float(x) / float(datos.width - 1))


func _lat_de(datos: HeightmapData, z: int) -> float:
	return lerpf(datos.lat_north, datos.lat_south, float(z) / float(datos.height - 1))


func test_el_rio_baja_desde_la_boca_hasta_el_mar_de_la_epoca() -> void:
	var datos := _rejilla()
	# La costa de hoy (cota 0) cae hacia la columna 42 de la rampa.
	var boca_x := 42
	var bajada := RioDeLaPlataforma.bajar(datos, _lon_de(datos, boca_x),
		_lat_de(datos, 20), -120.0)
	assert_true(bool(bajada["llega"]), "llega al mar de la época")
	var puntos: PackedVector2Array = bajada["puntos"]
	var ultimo := puntos[puntos.size() - 1]
	var cota_final := datos.sample_bilinear(datos.u_for_lon(ultimo.x),
		datos.v_for_lat(ultimo.y))
	assert_true(cota_final <= -120.0 + 1.0, "y acaba en él (%.0f m)" % cota_final)
	assert_eq(int(bajada["abiertos"]), 0, "por una rampa no hace falta abrir paso")


func test_en_un_llano_se_abre_paso_y_se_cuenta() -> void:
	var datos := _rejilla()
	# Un muro de 30 m cruzando la rampa, a la altura de la columna 36: sin abrir
	# paso el río se atascaría detrás.
	var cotas := PackedFloat32Array(datos.elevations)
	for z in range(datos.height):
		cotas[z * datos.width + 36] += 30.0
	datos.elevations = cotas
	var bajada := RioDeLaPlataforma.bajar(datos, _lon_de(datos, 42),
		_lat_de(datos, 20), -120.0)
	assert_true(bool(bajada["llega"]), "llega igual")
	assert_true(int(bajada["abiertos"]) > 0, "y dice cuántos pasos tuvo que subir")


func test_la_boca_es_la_punta_que_no_sigue_y_esta_a_ras_del_mar() -> void:
	var datos := _rejilla()
	var arriba := PackedVector2Array([Vector2(_lon_de(datos, 60), _lat_de(datos, 10)),
		Vector2(_lon_de(datos, 50), _lat_de(datos, 10))])
	var abajo := PackedVector2Array([Vector2(_lon_de(datos, 50), _lat_de(datos, 10)),
		Vector2(_lon_de(datos, 42), _lat_de(datos, 10))])
	var en_el_monte := PackedVector2Array([Vector2(_lon_de(datos, 62), _lat_de(datos, 30)),
		Vector2(_lon_de(datos, 58), _lat_de(datos, 30))])
	var cauces := [
		{"points": arriba, "name": "Nansa", "kind": "river", "half_width_m": 11.0},
		{"points": abajo, "name": "Nansa", "kind": "river", "half_width_m": 11.0},
		{"points": en_el_monte, "name": "Otro", "kind": "river", "half_width_m": 8.0},
	]
	var bocas := RioDeLaPlataforma.bocas(cauces, datos)
	assert_eq(bocas.size(), 1, "una sola boca: las puntas altas no cuentan")
	assert_near(float(bocas[0]["lon"]), _lon_de(datos, 42), 0.0001,
		"la del tramo de abajo, que no sigue en otro")


# --- Los valles de la plataforma (tarea 4) -------------------------------------


## Un río de la plataforma en la rejilla de juguete: recto, de la costa de hoy
## (columna 42) al mar de la época, por la fila 24.
func _rio_recto(datos: HeightmapData) -> Array:
	var puntos := PackedVector2Array()
	for x in range(42, 20, -1):
		puntos.append(Vector2(_lon_de(datos, x), _lat_de(datos, 24)))
	return [{"points": puntos, "half_width_m": 11.0, "kind": "river", "name": "Prueba"}]


func test_el_rio_de_la_plataforma_va_por_su_valle() -> void:
	# EL RÍO ABRE SU VALLE EN LA PLATAFORMA: donde pasa, el terreno queda más bajo que
	# sin él. **Hasta el 2026-09-17 se comprobaba contra el terreno a 1 km**, y valía
	# porque las lomas de ruido sólo subían. Con relieve real prestado (GRAFICOS §3) a un
	# kilómetro puede haber una vaguada más honda que el propio río, y eso no es un fallo
	# del valle: es el terreno. Así que se compara el mismo punto con valle y sin él.
	var con_valle := _rejilla()
	var rio := _rio_recto(con_valle)
	RelieveDeLaPlataforma.aplicar(con_valle, -120.0, rio)
	var sin_valle := _rejilla()
	RelieveDeLaPlataforma.aplicar(sin_valle, -120.0)
	var puntos_de_plataforma := 0
	var mas_alto := 0
	var hunde := 0.0
	for x in range(22, 42):
		var e := con_valle.get_elevation(x, 24)
		if e <= -120.0:
			continue
		puntos_de_plataforma += 1
		var sin := sin_valle.get_elevation(x, 24)
		if e > sin + 0.01:
			mas_alto += 1
		hunde += sin - e
	assert_true(puntos_de_plataforma > 5, "el río cruza plataforma")
	assert_eq(mas_alto, 0, "el valle nunca deja el cauce más alto que sin valle")
	assert_gt(hunde / float(maxi(puntos_de_plataforma, 1)), 5.0,
		"y lo hunde de media: %.1f m" % (hunde / float(maxi(puntos_de_plataforma, 1))))


func test_el_rio_de_la_plataforma_nunca_sube() -> void:
	var datos := _rejilla()
	# Un umbral de 25 m cruzando el río: sin tallar, subiría.
	var cotas := PackedFloat32Array(datos.elevations)
	for z in range(datos.height):
		cotas[z * datos.width + 34] += 25.0
	datos.elevations = cotas
	var rio := _rio_recto(datos)
	var plataforma := RelieveDeLaPlataforma.para(datos, -120.0, rio)
	var mas_bajo := INF
	var peor := 0.0
	for punto: Vector2 in (rio[0]["points"] as PackedVector2Array):
		var cota := plataforma.cota_en(punto.x, punto.y)
		if mas_bajo < INF:
			peor = maxf(peor, cota - mas_bajo)
		mas_bajo = minf(mas_bajo, cota)
	assert_true(peor <= 2.0, "no sube más de 2 m sobre lo más bajo recorrido (%.1f)" % peor)


func test_los_valles_no_mueven_la_costa() -> void:
	var sin := _rejilla()
	var con := _rejilla()
	RelieveDeLaPlataforma.aplicar(sin, -120.0)
	RelieveDeLaPlataforma.aplicar(con, -120.0, _rio_recto(con))
	var distintas := 0
	for i in range(sin.elevations.size()):
		if (sin.elevations[i] <= -120.0) != (con.elevations[i] <= -120.0):
			distintas += 1
	assert_eq(distintas, 0, "lo que era mar sigue siendo mar, y lo que era tierra, tierra")


func test_con_valles_la_cota_del_punto_sigue_casando() -> void:
	var limpia := _rejilla()
	var rio := _rio_recto(limpia)
	var plataforma := RelieveDeLaPlataforma.para(limpia, -120.0, rio)
	var con := _rejilla()
	RelieveDeLaPlataforma.aplicar(con, -120.0, rio)
	var peor := 0.0
	for z in range(18, 31):
		for x in range(20, 44):
			peor = maxf(peor, absf(plataforma.cota_en(_lon_de(limpia, x), _lat_de(limpia, z))
				- con.get_elevation(x, z)))
	assert_near(peor, 0.0, 1.0, "el valle del punto es el de la rejilla")


func test_la_amplitud_sube_las_lomas() -> void:
	var antes := RelieveDeLaPlataforma.amplitud
	var normal := _rejilla()
	RelieveDeLaPlataforma.amplitud = 1.0
	RelieveDeLaPlataforma.aplicar(normal, -120.0)
	var alta := _rejilla()
	RelieveDeLaPlataforma.amplitud = 2.0
	RelieveDeLaPlataforma.aplicar(alta, -120.0)
	RelieveDeLaPlataforma.amplitud = antes
	var base := _rejilla()
	# LO QUE CAMBIA, EN VALOR ABSOLUTO, y sólo donde ninguna de las dos toca el suelo del
	# mar: desde el 2026-09-17 el detalle es relieve real y baja además de subir, y lo que
	# bajaría del mar se queda en él (la costa no se mueve), así que ahí deja de ser lineal.
	var cambia_normal := 0.0
	var cambia_alta := 0.0
	var cuenta := 0
	for i in range(base.elevations.size()):
		if base.elevations[i] <= -120.0 or base.elevations[i] >= 0.0:
			continue
		if normal.elevations[i] <= -118.9 or alta.elevations[i] <= -118.9:
			continue
		cambia_normal += absf(normal.elevations[i] - base.elevations[i])
		cambia_alta += absf(alta.elevations[i] - base.elevations[i])
		cuenta += 1
	assert_gt(float(cuenta), 10.0, "hay plataforma que mirar")
	assert_near(cambia_alta, cambia_normal * 2.0, absf(cambia_normal) * 0.01 + 0.01,
		"con el doble de amplitud, el doble de relieve")


# --- El ancho de los ríos (tarea 5) --------------------------------------------


func _tramo(desde: Vector2, hasta: Vector2, puntos: int = 6) -> Dictionary:
	var linea := PackedVector2Array()
	for k in range(puntos):
		linea.append(desde.lerp(hasta, float(k) / float(puntos - 1)))
	return {"points": linea, "half_width_m": 11.0, "kind": "river", "name": ""}


func test_el_rio_se_ensancha_aguas_abajo() -> void:
	# Dos tramos seguidos, de unos 11 km cada uno.
	var arriba := _tramo(Vector2(-4.0, 43.0), Vector2(-4.0, 43.1))
	var abajo := _tramo(Vector2(-4.0, 43.1), Vector2(-4.0, 43.2))
	var cauces := [arriba, abajo]
	AnchoDeLosRios.poner(cauces)
	var anchos_arriba: PackedFloat32Array = arriba["half_widths_m"]
	var anchos_abajo: PackedFloat32Array = abajo["half_widths_m"]
	assert_near(anchos_arriba[0], AnchoDeLosRios.EN_LA_FUENTE_M, 0.01,
		"en la fuente, el ancho de la fuente")
	assert_true(anchos_arriba[anchos_arriba.size() - 1] > anchos_arriba[0],
		"crece a lo largo del tramo")
	assert_near(anchos_abajo[0], anchos_arriba[anchos_arriba.size() - 1], 0.5,
		"el tramo de abajo empieza con lo que trae el de arriba")
	assert_true(anchos_abajo[anchos_abajo.size() - 1] > anchos_abajo[0],
		"y sigue creciendo hasta la boca")


func test_un_afluente_ensancha_al_rio_en_el_que_cae() -> void:
	var solo_arriba := _tramo(Vector2(-4.0, 43.0), Vector2(-4.0, 43.1))
	var solo_abajo := _tramo(Vector2(-4.0, 43.1), Vector2(-4.0, 43.2))
	var sin := [solo_arriba, solo_abajo]
	AnchoDeLosRios.poner(sin)
	var con_arriba := _tramo(Vector2(-4.0, 43.0), Vector2(-4.0, 43.1))
	var afluente := _tramo(Vector2(-3.9, 43.1), Vector2(-4.0, 43.1))
	var con_abajo := _tramo(Vector2(-4.0, 43.1), Vector2(-4.0, 43.2))
	var con := [con_arriba, afluente, con_abajo]
	AnchoDeLosRios.poner(con)
	assert_true((con_abajo["half_widths_m"] as PackedFloat32Array)[0]
		> (solo_abajo["half_widths_m"] as PackedFloat32Array)[0],
		"con el afluente, el río de abajo empieza más ancho")


func test_al_pintar_la_boca_ocupa_mas_que_la_fuente() -> void:
	var datos := HeightmapData.new()
	datos.width = 60
	datos.height = 20
	datos.meters_per_sample = 20.0
	datos.lat_north = 43.002
	datos.lat_south = 43.0
	datos.lon_west = -4.01
	datos.lon_east = -4.0
	datos.geographic_rows = true
	var cotas := PackedFloat32Array()
	cotas.resize(datos.width * datos.height)
	for x in range(datos.width):
		for z in range(datos.height):
			cotas[z * datos.width + x] = 100.0 - float(x)
	datos.elevations = cotas
	var rio := _tramo(Vector2(-4.0095, 43.001), Vector2(-4.0005, 43.001), 10)
	var anchos := PackedFloat32Array()
	for k in range(10):
		anchos.append(lerpf(2.0, 60.0, float(k) / 9.0))
	rio["half_widths_m"] = anchos
	Hydrography.apply(datos, [rio], [])
	var mojadas_fuente := 0
	var mojadas_boca := 0
	for z in range(datos.height):
		if datos.river_mask[z * datos.width + 8] > 0.5:
			mojadas_fuente += 1
		if datos.river_mask[z * datos.width + 52] > 0.5:
			mojadas_boca += 1
	assert_true(mojadas_boca > mojadas_fuente,
		"la boca moja %d celdas de ancho y la fuente %d" % [mojadas_boca, mojadas_fuente])


func test_el_rio_de_la_plataforma_no_va_en_escalera() -> void:
	var escalera := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
		Vector2(2, 1), Vector2(2, 2)])
	var suave := RioDeLaPlataforma.suavizar(escalera, 2)
	assert_true(suave[0] == escalera[0] and suave[suave.size() - 1] == escalera[4],
		"las puntas no se mueven")
	# Sin esquinas de 90°: ningún giro entre tramos seguidos pasa de 60°.
	var peor := 0.0
	for k in range(1, suave.size() - 1):
		var a := (suave[k] - suave[k - 1]).normalized()
		var b := (suave[k + 1] - suave[k]).normalized()
		peor = maxf(peor, absf(rad_to_deg(a.angle_to(b))) if a != Vector2.ZERO and b != Vector2.ZERO else 0.0)
	assert_true(absf(peor) <= 60.0, "el giro más brusco son %.0f°" % peor)


# --- Los cuatro abrigos de la costa, y la puerta única (tarea 7) ---------------


func test_los_cuatro_salen_con_el_mar_de_la_epoca_y_no_con_el_de_hoy() -> void:
	var comarca := SiteSet.comarca()
	var con_el_mar_bajo := 0
	var con_el_mar_de_hoy := 0
	for sitio: Site in comarca.available_in(-120.0, Site.Era.PALEOLITICO):
		if sitio.fidelity == Site.Fidelity.HIPOTETICO:
			con_el_mar_bajo += 1
	for sitio: Site in comarca.available_in(0.0, Site.Era.PALEOLITICO):
		if sitio.fidelity == Site.Fidelity.HIPOTETICO:
			con_el_mar_de_hoy += 1
	assert_eq(con_el_mar_bajo, SitiosDeLaCosta.LOS_SITIOS.size(),
		"con el mar del Paleolítico están los cuatro")
	assert_eq(con_el_mar_de_hoy, 0, "con el mar de hoy, ninguno: están bajo el agua")


func test_llevan_la_marca_y_ningun_sitio_real_la_lleva() -> void:
	var comarca := SiteSet.comarca()
	var hipoteticos := 0
	for sitio: Site in comarca.sites:
		if sitio.fidelity == Site.Fidelity.HIPOTETICO:
			hipoteticos += 1
			assert_true(sitio.describe_for_player().contains("Hipotético"),
				"%s dice que es una hipótesis" % sitio.display_name())
			assert_true(sitio.has_shelter, "y tiene abrigo, que es para lo que vale")
	assert_eq(hipoteticos, SitiosDeLaCosta.LOS_SITIOS.size(),
		"sólo son hipotéticos los cuatro de la costa")


func test_la_comarca_no_crece_cada_vez_que_se_pide() -> void:
	var una := SiteSet.comarca().sites.size()
	var otra := SiteSet.comarca().sites.size()
	assert_eq(una, otra, "pedirla dos veces no duplica los abrigos")


func test_su_cota_es_la_de_la_plataforma() -> void:
	var datos: HeightmapData = load("res://data/dem/cantabria_region.res")
	assert_true(datos != null, "está el relieve regional")
	var rios := RiosDeLaRegion.cargar()
	var plataforma := RelieveDeLaPlataforma.para(datos, -120.0, rios.de_la_plataforma)
	for sitio: Site in SitiosDeLaCosta.como_sitios():
		var cota := plataforma.cota_en(sitio.lon, sitio.lat)
		assert_near(sitio.elevation, cota, 5.0,
			"%s: la cota escrita (%.0f) es la del relieve (%.0f)" % [
				sitio.display_name(), sitio.elevation, cota])
		assert_true(cota > -120.0, "y queda fuera del agua con el mar de la época")


func test_ningun_guion_del_juego_carga_la_lista_por_su_cuenta() -> void:
	# La lista se pedía con `load` en ocho sitios distintos. Con los hipotéticos por
	# medio, uno que se quede con el `load` es un abrigo que sale en el mapa y no al
	# guardar la partida. Las sondas y las herramientas no cuentan: son instrumentos.
	var culpables: Array[String] = []
	_buscar_la_carga("res://scripts", culpables)
	assert_true(culpables.is_empty(),
		"sólo `SiteSet.comarca` carga la lista; la cargan además: %s"
			% ", ".join(culpables))


func _buscar_la_carga(carpeta: String, culpables: Array[String]) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	for nombre: String in dir.get_directories():
		if nombre == "tests" or nombre == "tools":
			continue
		_buscar_la_carga("%s/%s" % [carpeta, nombre], culpables)
	for nombre: String in dir.get_files():
		if not nombre.ends_with(".gd") or nombre == "SiteSet.gd":
			continue
		var texto := FileAccess.get_file_as_string("%s/%s" % [carpeta, nombre])
		if texto.contains("load(\"res://data/sites/cantabria_sites.res\")"):
			culpables.append(nombre)


# --- El mar, agua que no se cruza (tarea 8) ------------------------------------


func test_el_mar_hondo_no_se_cruza_en_ninguna_estacion() -> void:
	var hondo := TerrainGenerator.vado_del_mar(-125.0, -120.0)
	assert_near(hondo, 1.0, 0.001, "cinco metros de agua es mar abierto")
	for estacion: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		assert_false(Hydrography.can_cross(hondo, false, false, estacion),
			"en %s tampoco" % Subsistence.season_name(estacion as Subsistence.Season))
	assert_false(Hydrography.can_cross(hondo, false, true),
		"y una pasarela de dos troncos no salva el mar")


func test_la_orilla_se_pisa_y_da_para_un_paraje() -> void:
	# La franja que descubre la marea: tierra mojada, y es donde se marisquea.
	var franja := TerrainGenerator.vado_del_mar(-119.0, -120.0)
	assert_true(franja > 0.05 and franja < 0.35, "la franja de marea se anda (%.2f)" % franja)
	assert_true(Parajes.activity_fits(Subsistence.Activity.MARISQUEO, franja),
		"y allí puede nacer un marisqueo")
	var orilla := TerrainGenerator.vado_del_mar(-120.3, -120.0)
	assert_true(Hydrography.can_cross(orilla, false, false),
		"con el agua por el tobillo se anda")
	assert_true(Parajes.activity_fits(Subsistence.Activity.MARISQUEO, orilla),
		"y allí puede nacer un marisqueo")
	assert_true(Parajes.activity_fits(Subsistence.Activity.PESCA, orilla),
		"y una pesquera")
	assert_false(Parajes.activity_fits(Subsistence.Activity.RECOLECCION, orilla),
		"pero no un avellanar: eso pide suelo seco")


func test_en_tierra_el_mar_no_estorba() -> void:
	assert_near(TerrainGenerator.vado_del_mar(10.0, -120.0), 0.0, 0.001,
		"a diez metros sobre el mar no hay agua salada que cruzar")
	assert_true(TerrainGenerator.vado_del_mar(-119.9, -120.0) > 0.05,
		"pero justo encima de la lámina hay franja de marea, que es agua para el juego")


# --- Lo que da la orilla (tarea 9) ---------------------------------------------


## Un valle de costa de juguete: mar al oeste de x = 300, tierra al este, sin ríos.
class CostaFalsa extends TerrainGenerator:
	func _init() -> void:
		terrain_size = Vector2i(600, 600)
		resolution = 65
		sea_level = 0.0

	func get_height_at(p: Vector3) -> float:
		# Baja hasta −20 m mar adentro y sube tierra adentro.
		return (p.x - 300.0) * 0.1

	func get_slope_at(_p: Vector3) -> float:
		return 0.0

	func is_underwater(p: Vector3) -> bool:
		return get_height_at(p) <= 0.0

	func crossing_difficulty_at(p: Vector3) -> float:
		return TerrainGenerator.vado_del_mar(get_height_at(p), 0.0)

	func crossing_difficulty_with(p: Vector3, _caudal: float = 1.0) -> float:
		return crossing_difficulty_at(p)


func test_el_marisqueo_es_de_la_orilla_y_no_de_mar_adentro() -> void:
	var terreno := CostaFalsa.new()
	var campo := ResourceMapper.build(terreno, Vector3(500.0, 0.0, 300.0))
	var en_la_orilla := campo.abundance_at(Subsistence.Activity.MARISQUEO,
		Vector3(305.0, 0.0, 300.0))
	var mar_adentro := campo.abundance_at(Subsistence.Activity.MARISQUEO,
		Vector3(30.0, 0.0, 300.0))
	var en_tierra := campo.abundance_at(Subsistence.Activity.MARISQUEO,
		Vector3(500.0, 0.0, 300.0))
	assert_true(en_la_orilla > 0.5, "en la orilla hay lapa y mejillón (%.2f)" % en_la_orilla)
	assert_near(mar_adentro, 0.0, 0.01, "mar adentro no se marisquea")
	assert_near(en_tierra, 0.0, 0.01, "y en tierra tampoco")


func test_se_pesca_en_el_mar_somero_como_en_un_rio_medio() -> void:
	var terreno := CostaFalsa.new()
	var campo := ResourceMapper.build(terreno, Vector3(500.0, 0.0, 300.0))
	var en_la_orilla := campo.abundance_at(Subsistence.Activity.PESCA,
		Vector3(305.0, 0.0, 300.0))
	assert_true(en_la_orilla > 0.3,
		"la orilla del mar da pesca (%.2f)" % en_la_orilla)
	assert_near(campo.abundance_at(Subsistence.Activity.PESCA, Vector3(30.0, 0.0, 300.0)),
		0.0, 0.01, "mar adentro, sin barca, no")


# --- El valle inventado (tarea 10) ---------------------------------------------
#
# Se prueba con un recuadro pequeño —2 km a 10 m por muestra— y no con el de verdad
# —4,5 km a 5 m, 810 000 puntos—: la regla es la misma y la prueba tarda un segundo en
# vez de medio minuto. Lo que hace el valle entero lo mira `CostaProbe`.


func _valle_de_prueba(cual: int = 0, lado_m: float = 2000.0,
		metros: float = 10.0) -> HeightmapData:
	var regional: HeightmapData = load("res://data/dem/cantabria_region.res")
	var rios := RiosDeLaRegion.cargar()
	var sitio: Site = SitiosDeLaCosta.como_sitios()[cual]
	return ValleDeLaPlataforma.generar(sitio, rios, regional, -120.0, lado_m, metros)


func test_el_valle_inventado_sale_igual_las_dos_veces() -> void:
	var una := _valle_de_prueba()
	var otra := _valle_de_prueba()
	assert_eq(una.width, otra.width, "mismo tamaño")
	var distintas := 0
	for i in range(una.elevations.size()):
		if una.elevations[i] != otra.elevations[i]:
			distintas += 1
	assert_eq(distintas, 0, "y las mismas cotas, punto por punto")


func test_el_valle_tiene_mar_y_tierra() -> void:
	var valle := _valle_de_prueba()
	var bajo_el_mar := 0
	var en_tierra := 0
	for cota: float in valle.elevations:
		if cota <= -120.0:
			bajo_el_mar += 1
		else:
			en_tierra += 1
	assert_true(bajo_el_mar > 0, "hay mar en el recuadro")
	assert_true(en_tierra > bajo_el_mar / 4, "y bastante tierra donde vivir")


func test_el_abrigo_esta_al_pie_de_un_cantil_y_mira_al_mar() -> void:
	var valle := _valle_de_prueba()
	var sitio: Site = SitiosDeLaCosta.como_sitios()[0]
	var en_el_sitio := valle.sample_bilinear(valle.u_for_lon(sitio.lon),
		valle.v_for_lat(sitio.lat))
	assert_near(en_el_sitio, sitio.elevation, 12.0,
		"la cota del abrigo es la que dice el sitio (%.0f)" % en_el_sitio)
	# Ciento cincuenta metros tierra adentro, el cantil ya ha levantado.
	var arriba := -INF
	var abajo := INF
	for grados in range(0, 360, 30):
		var rad := deg_to_rad(float(grados))
		var lon := sitio.lon + cos(rad) * 150.0 / (111320.0 * cos(deg_to_rad(sitio.lat)))
		var lat := sitio.lat + sin(rad) * 150.0 / 111320.0
		var cota := valle.sample_bilinear(valle.u_for_lon(lon), valle.v_for_lat(lat))
		arriba = maxf(arriba, cota)
		abajo = minf(abajo, cota)
	assert_true(arriba - en_el_sitio > 10.0,
		"a un lado del abrigo sube un cantil (%.0f m)" % (arriba - en_el_sitio))
	assert_true(abajo < en_el_sitio,
		"y al otro baja hacia el mar")


func test_el_valle_trae_el_rio_de_la_epoca() -> void:
	# El recuadro de verdad es más ancho: el río pasa por la desembocadura, no
	# necesariamente por encima del abrigo.
	var valle := _valle_de_prueba(0, 4500.0, 15.0)
	var mojadas := 0
	for v: float in valle.river_mask:
		if v > 0.5:
			mojadas += 1
	assert_true(mojadas > 50, "el río del mapa cruza el valle (%d celdas)" % mojadas)
	assert_eq(valle.water_level.size(), valle.elevations.size(),
		"y trae su lámina, que es lo que hace que se dibuje como agua")


## EL MAPA REGIONAL SE MONTA CON EL MAR DE LA ÉPOCA, haya campamento o no.
##
## Había dos respuestas a esa pregunta en líneas contiguas de `RegionMap._ready`, y la del
## caso «todavía no he fundado» devolvía el mar de HOY: una partida nueva dibujaba la
## Cantabria actual, sin plataforma emergida y **sin los ríos que corren por ella**. En
## cuanto fundabas y volvías al mapa, aparecían. Depurado el 2026-09-18; GRAFICOS §3.
func _region() -> GDScript:
	return load("res://scripts/region/RegionMap.gd") as GDScript


func test_el_mapa_regional_usa_el_mar_de_la_epoca_sin_campamento() -> void:
	var mapa := _region()
	var antes_home := GameState.home
	var antes_mar := GameState.sea_level_m
	GameState.home = null
	GameState.sea_level_m = -120.0
	assert_eq(float(mapa.mar_del_mapa()), -120.0,
		"sin campamento, el mapa es el de la época")
	GameState.sea_level_m = -45.0
	assert_eq(float(mapa.mar_del_mapa()), -45.0, "y sigue a la época si la época cambia")
	GameState.home = antes_home
	GameState.sea_level_m = antes_mar


func test_el_mapa_regional_usa_el_mismo_mar_con_campamento() -> void:
	var mapa := _region()
	var antes_home := GameState.home
	var antes_mar := GameState.sea_level_m
	GameState.sea_level_m = -120.0
	GameState.home = null
	var sin_campamento := float(mapa.mar_del_mapa())
	GameState.home = Site.new()
	assert_eq(float(mapa.mar_del_mapa()), sin_campamento,
		"fundar no cambia con qué mar se dibuja el mapa")
	GameState.home = antes_home
	GameState.sea_level_m = antes_mar
