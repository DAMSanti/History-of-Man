class_name TestHydrography
extends TestCase
## Pruebas de la red fluvial tomada de OpenStreetMap.
##
## Hasta ahora los cauces se deducían del relieve por acumulación de drenaje, y
## sobre un recuadro de 4 km eso daba un 0,5% de celdas con valor medio 0,06:
## invisible. OSM sabe dónde está el Nansa porque alguien lo ha cartografiado,
## y además trae el SENTIDO de la corriente, que del relieve no sale gratis.


func suite_name() -> String:
	return "Hidrografia"


func _grid(width: int = 60, height: int = 60) -> HeightmapData:
	var data := HeightmapData.new()
	data.width = width
	data.height = height
	data.meters_per_sample = 5.0
	data.lon_west = -4.0
	data.lon_east = -3.99
	data.lat_north = 43.01
	data.lat_south = 43.00
	data.geographic_rows = true
	data.elevations.resize(width * height)
	data.elevations.fill(100.0)
	return data


## Un cauce que baja de norte a sur por el centro del recuadro. En OSM las vías
## de agua se digitalizan aguas ABAJO, así que el orden de los vértices ES el
## sentido de la corriente.
func _channel(half_width: float = 8.0) -> Dictionary:
	return {
		"points": PackedVector2Array([Vector2(-3.995, 43.010), Vector2(-3.995, 43.000)]),
		"half_width_m": half_width,
		"kind": "river",
		"closed": false,
	}


func _count(mask: PackedFloat32Array, threshold: float = 0.001) -> int:
	var n := 0
	for v in mask:
		if v > threshold:
			n += 1
	return n


# --- rasterizado del cauce ----------------------------------------------

func test_el_cauce_marca_una_franja_continua() -> void:
	var data := _grid()
	Hydrography.apply(data, [_channel()], [])

	assert_eq(data.river_mask.size(), data.width * data.height, "la mascara cubre la rejilla")
	assert_gt(_count(data.river_mask), 0, "el cauce marca celdas")

	# Continua: toda fila del recorrido tiene al menos una celda de agua
	var filas_secas := 0
	for z in range(5, data.height - 5):
		var mojada := false
		for x in range(data.width):
			if data.river_mask[z * data.width + x] > 0.001:
				mojada = true
		if not mojada:
			filas_secas += 1
	assert_eq(filas_secas, 0, "el cauce no se corta a mitad de recorrido")


func test_el_eje_del_cauce_va_a_tope_y_la_orilla_se_degrada() -> void:
	var data := _grid()
	Hydrography.apply(data, [_channel()], [])

	var centro: float = data.river_mask[30 * data.width + 30]
	assert_gt(centro, 0.9, "el eje del cauce esta a plena lamina de agua")

	# La orilla se difumina en vez de cortar a hachazo: un borde duro canta
	var orilla_dentro: float = data.river_mask[30 * data.width + 31]
	var fuera: float = data.river_mask[30 * data.width + 45]
	assert_gt(orilla_dentro, 0.0, "junto al eje sigue habiendo agua")
	assert_eq(fuera, 0.0, "lejos del cauce no hay agua")


func test_un_arroyo_es_mas_estrecho_que_un_rio() -> void:
	var rio := _grid()
	Hydrography.apply(rio, [_channel(12.0)], [])
	var arroyo := _grid()
	Hydrography.apply(arroyo, [_channel(3.0)], [])
	assert_gt(float(_count(rio.river_mask)), float(_count(arroyo.river_mask)) * 1.5,
		"el rio moja bastantes mas celdas que el arroyo")


# --- sentido de la corriente ---------------------------------------------

func test_la_corriente_apunta_aguas_abajo() -> void:
	var data := _grid()
	Hydrography.apply(data, [_channel()], [])

	# El cauce baja de norte a sur. En la rejilla la fila crece hacia el sur,
	# asi que la corriente tiene que apuntar a +Z y no llevar componente en X.
	var i := 30 * data.width + 30
	assert_gt(data.flow_z[i], 0.9, "la corriente va hacia el sur")
	assert_near(data.flow_x[i], 0.0, 0.1, "y no se desvia en el eje este-oeste")


func test_invertir_la_via_invierte_la_corriente() -> void:
	var data := _grid()
	var arriba := _channel()
	var puntos: PackedVector2Array = arriba["points"]
	puntos.reverse()
	arriba["points"] = puntos
	Hydrography.apply(data, [arriba], [])

	var i := 30 * data.width + 30
	assert_lt(data.flow_z[i], -0.9, "digitalizada al reves, la corriente va al norte")


func test_la_corriente_es_unitaria_donde_hay_agua() -> void:
	var data := _grid()
	Hydrography.apply(data, [_channel()], [])

	var peor := 0.0
	for i in range(data.river_mask.size()):
		if data.river_mask[i] > 0.5:
			var largo := sqrt(data.flow_x[i] * data.flow_x[i] + data.flow_z[i] * data.flow_z[i])
			peor = maxf(peor, absf(largo - 1.0))
	assert_lt(peor, 0.01, "el vector de corriente esta normalizado")


func test_fuera_del_cauce_no_hay_corriente() -> void:
	var data := _grid()
	Hydrography.apply(data, [_channel()], [])
	var i := 30 * data.width + 50
	assert_near(data.flow_x[i], 0.0, 0.0001, "sin agua no hay corriente en X")
	assert_near(data.flow_z[i], 0.0, 0.0001, "sin agua no hay corriente en Z")


# --- cuerpos de agua ------------------------------------------------------

func test_una_laguna_se_rellena_por_dentro() -> void:
	var data := _grid()
	var laguna := {
		"points": PackedVector2Array([
			Vector2(-3.9970, 43.0070), Vector2(-3.9930, 43.0070),
			Vector2(-3.9930, 43.0030), Vector2(-3.9970, 43.0030),
			Vector2(-3.9970, 43.0070)]),
		"kind": "lake",
	}
	Hydrography.apply(data, [], [laguna])

	var cx := int(data.u_for_lon(-3.9950) * float(data.width - 1))
	var cz := int(data.v_for_lat(43.0050) * float(data.height - 1))
	var i := cz * data.width + cx
	assert_gt(data.river_mask[i], 0.9, "el interior de la laguna es lamina de agua")
	assert_gt(_count(data.river_mask), 200, "se rellena el area, no solo el contorno")


func test_el_agua_quieta_no_tiene_corriente() -> void:
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
	var i := cz * data.width + cx
	# Una laguna no corre: si le pusieramos corriente, el shader haria
	# desfilar la textura sobre agua parada
	assert_near(data.flow_x[i], 0.0, 0.0001, "la laguna no corre en X")
	assert_near(data.flow_z[i], 0.0, 0.0001, "la laguna no corre en Z")


func test_sin_hidrografia_la_mascara_queda_limpia() -> void:
	var data := _grid()
	Hydrography.apply(data, [], [])
	assert_eq(_count(data.river_mask), 0, "sin vias de agua no se moja nada")


# --- la lamina es horizontal de orilla a orilla --------------------------

## Ladera inclinada de este a oeste, con un cauce que la baja de norte a sur.
## Es el caso que se veia mal: el agua pintada sobre el terreno subia la ladera
## con el, cuando un rio tiene la lamina a nivel de orilla a orilla.
func _hillside() -> HeightmapData:
	var data := _grid()
	for z in range(data.height):
		for x in range(data.width):
			# Pendiente transversal fuerte mas una caida suave aguas abajo
			data.elevations[z * data.width + x] = \
				100.0 + absf(float(x) - 30.0) * 3.0 - float(z) * 0.4
	return data


func test_la_lamina_queda_a_nivel_de_orilla_a_orilla() -> void:
	var data := _hillside()
	var antes := PackedFloat32Array(data.elevations)
	Hydrography.apply(data, [_channel(10.0)], [])

	# Se compara la cota a lo ancho del cauce en una misma seccion
	var z := 30
	var cotas: Array[float] = []
	for x in range(data.width):
		if data.river_mask[z * data.width + x] > 0.9:
			cotas.append(data.elevations[z * data.width + x])

	assert_gt(float(cotas.size()), 2.0, "la seccion tiene varias celdas de agua")
	var lo := cotas[0]
	var hi := cotas[0]
	for c in cotas:
		lo = minf(lo, c)
		hi = maxf(hi, c)
	assert_lt(hi - lo, 0.30, "la lamina no tiene desnivel transversal")

	# Y antes SI lo tenia: si no, la prueba no estaria probando nada
	var lo0 := INF
	var hi0 := -INF
	for x in range(data.width):
		if data.river_mask[z * data.width + x] > 0.9:
			lo0 = minf(lo0, antes[z * data.width + x])
			hi0 = maxf(hi0, antes[z * data.width + x])
	assert_gt(hi0 - lo0, 1.0, "el terreno original si estaba inclinado ahi")


func test_la_lamina_desciende_aguas_abajo() -> void:
	var data := _hillside()
	Hydrography.apply(data, [_channel(10.0)], [])

	var arriba := data.water_level[15 * data.width + 30]
	var abajo := data.water_level[50 * data.width + 30]
	assert_lt(abajo, arriba, "el agua baja hacia aguas abajo")


func test_el_agua_se_encaja_en_el_terreno_y_no_se_apoya_encima() -> void:
	# La lamina puede quedar unos centimetros por encima de la cota bruta de
	# una celda suelta: eso es inundar un bajio, y es lo que hace un rio. Lo
	# que no puede es subirse metros por encima del terreno, que es lo que
	# pasaba cuando el agua se pintaba sobre la ladera sin nivelar.
	var data := _hillside()
	var antes := PackedFloat32Array(data.elevations)
	Hydrography.apply(data, [_channel(10.0)], [])

	var peor := 0.0
	for i in range(data.elevations.size()):
		if data.river_mask[i] > 0.5:
			peor = maxf(peor, data.elevations[i] - antes[i])
	assert_lt(peor, 0.60, "la lamina se encaja, no se sube al monte")


func test_lejos_del_cauce_el_terreno_no_se_toca() -> void:
	# La RIBERA si se remodela, y a proposito: es parte del rio, y sin
	# reperfilarla el encaje del cauce deja un muro donde la orilla es
	# empinada. Lo que no se puede tocar es la ladera de mas alla.
	var data := _hillside()
	var antes := PackedFloat32Array(data.elevations)
	Hydrography.apply(data, [_channel(10.0)], [])

	var w := data.width
	var margin := Hydrography.BANK_REGRADE_CELLS + 2
	var intacto := true
	for z in range(data.height):
		for x in range(w):
			var i := z * w + x
			if data.river_mask[i] > 0.0:
				continue
			# Solo se juzgan las celdas lejos de cualquier celda mojada
			var cerca := false
			for dz in range(-margin, margin + 1):
				var nz := z + dz
				if nz < 0 or nz >= data.height:
					continue
				for dx in range(-margin, margin + 1):
					var nx := x + dx
					if nx < 0 or nx >= w:
						continue
					if data.river_mask[nz * w + nx] > 0.0:
						cerca = true
			if cerca:
				continue
			if absf(data.elevations[i] - antes[i]) > 0.0001:
				intacto = false
	assert_true(intacto, "la ladera lejos del rio queda como estaba")


func test_la_orilla_baja_de_forma_continua_hasta_el_agua() -> void:
	# Si el encaje dejara un muro, se veria un corte vertical en la ribera. Se
	# compara contra la pendiente del propio terreno y no contra un numero
	# fijo: en una ladera de 30 grados dos celdas vecinas ya se llevan tres
	# metros de por si, y eso no es un escalon, es la ladera.
	var data := _hillside()
	var antes := PackedFloat32Array(data.elevations)
	Hydrography.apply(data, [_channel(10.0)], [])

	var z := 30
	var natural := 0.0
	var salto := 0.0
	for x in range(1, data.width):
		var i := z * data.width + x
		natural = maxf(natural, absf(antes[i] - antes[i - 1]))
		if data.river_mask[i] > 0.0 or data.river_mask[i - 1] > 0.0:
			salto = maxf(salto, absf(data.elevations[i] - data.elevations[i - 1]))
	# El margen es 2x y no 1x porque una orilla encajada ES mas brusca que la
	# ladera: eso es un talud de socavacion, y exigir que fuera igual de suave
	# seria pedirle al rio que no se encaje. Lo que no puede haber es un muro,
	# y sin reperfilar la ribera este mismo caso daba 3,4x.
	assert_lt(salto, natural * 2.0,
		"la ribera baja como un talud, no como un muro")


func test_hay_cota_de_lamina_dondequiera_que_llegue_la_mascara() -> void:
	# Este es el invariante cuyo incumplimiento producia los dientes de sierra
	# de la ribera.
	#
	# Al componer la malla del terreno, un vertice mezcla su cota con la de la
	# lamina SOLO si ahi hay cota de lamina. La mascara se muestrea bilineal y
	# la cota por celda mas cercana, asi que si la mascara llega mas lejos que
	# la cota, un vertice se mezcla y el siguiente no. Esa alternancia, sobre
	# la rejilla de la malla, es exactamente un peine.
	#
	# Se prueba con el cauce en DIAGONAL porque es donde el borde rasterizado
	# sale escalonado y la discrepancia entre las dos mascaras es mayor.
	var data := _grid()
	for z in range(data.height):
		for x in range(data.width):
			data.elevations[z * data.width + x] = \
				100.0 + float(x) * 1.2 + float(z) * 0.35

	Hydrography.apply(data, [{
		"points": PackedVector2Array([
			Vector2(-3.9985, 43.0090), Vector2(-3.9915, 43.0010)]),
		"half_width_m": 9.0, "kind": "river", "closed": false,
	}], [])

	var huerfanas := 0
	for i in range(data.river_mask.size()):
		if data.river_mask[i] > 0.05 and data.water_level[i] == 0.0:
			huerfanas += 1
	assert_eq(huerfanas, 0,
		"ninguna celda con agua se queda sin cota de lamina")


func test_la_cota_de_lamina_desborda_la_mascara() -> void:
	# Y no basta con cubrirla justa: la malla del terreno se muestrea a un paso
	# distinto del de la rejilla -4 m frente a 5-, asi que un vertice puede
	# caer fuera de la ultima celda mojada y seguir necesitando la cota.
	var data := _hillside()
	Hydrography.apply(data, [_channel(10.0)], [])

	var con_cota := 0
	var mojadas := 0
	for i in range(data.river_mask.size()):
		if data.water_level[i] != 0.0:
			con_cota += 1
		if data.river_mask[i] > 0.0:
			mojadas += 1
	assert_gt(float(con_cota), float(mojadas) * 1.1,
		"la cota de lamina se extiende mas alla del agua, con margen")


# --- que cuenta como agua natural ----------------------------------------

func test_los_canales_y_acequias_no_son_rios() -> void:
	# Canal de Celis, la central hidroelectrica: obra del siglo XX. En un mapa
	# que empieza en el Paleolitico no puede aparecer como rio.
	for clase: String in ["canal", "ditch", "drain", "penstock"]:
		assert_eq(OSMWays.channel_width_for(clase), 0.0,
			"la clase %s no es agua natural" % clase)


func test_rios_y_arroyos_si_cuentan_y_con_ancho_propio() -> void:
	assert_gt(OSMWays.channel_width_for("river"), 0.0, "un rio es agua natural")
	assert_gt(OSMWays.channel_width_for("stream"), 0.0, "un arroyo es agua natural")
	assert_gt(OSMWays.channel_width_for("river"), OSMWays.channel_width_for("stream"),
		"el rio es mas ancho que el arroyo")


func test_los_embalses_y_balsas_no_cuentan_como_lamina_natural() -> void:
	assert_false(OSMWays.is_natural_water_body("reservoir"),
		"un embalse es artificial")
	# En este recuadro la unica `pond` es el deposito de carga de la central
	# hidroelectrica de Celis: obra del XX, no una charca
	assert_false(OSMWays.is_natural_water_body("pond"),
		"una charca de OSM es casi siempre artificial")
	assert_true(OSMWays.is_natural_water_body("lake"), "un lago es natural")
	assert_true(OSMWays.is_natural_water_body("river"),
		"el poligono de superficie de un rio es agua natural")
