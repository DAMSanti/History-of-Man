class_name TestAgua
extends TestCase
## El agua del cauce: dónde rompe y hacia dónde corre. GRAFICOS §7.3.
##
## Lo que se ve lo dan por bueno las capturas y el usuario; aquí va lo que decide dónde
## se pinta cada cosa, que se calcula en la CPU justo para poder probarlo: la suite no
## ejecuta shaders.


func suite_name() -> String:
	return "Agua"


## Un cauce de oeste a este por el centro de una rejilla de `res`, con la lámina entera
## en las filas del medio y degradándose hacia las márgenes, y un escalón de `salto` en
## la columna `donde`. La corriente, hacia el este.
func _cauce(res: int, salto: float, donde: int) -> Dictionary:
	var altura := PackedFloat32Array()
	var lamina := PackedFloat32Array()
	var flujo := PackedVector2Array()
	altura.resize(res * res)
	lamina.resize(res * res)
	flujo.resize(res * res)
	var centro := res / 2
	for z in range(res):
		for x in range(res):
			var i := z * res + x
			altura[i] = 10.0 - (salto if x > donde else 0.0)
			var lejos := absi(z - centro)
			lamina[i] = 1.0 if lejos <= 2 else (0.3 if lejos == 3 else 0.0)
			flujo[i] = Vector2(1.0, 0.0) if lamina[i] > 0.0 else Vector2.ZERO
	return {"altura": altura, "lamina": lamina, "flujo": flujo}


func test_la_espuma_de_rapido_sale_en_el_escalon_y_no_en_el_llano() -> void:
	var c := _cauce(30, 3.0, 20)
	var centro := 15
	var llano := AguaDelCauce.rapido(c["altura"], c["lamina"], c["flujo"], 30, 6, centro, 5.0)
	var escalon := AguaDelCauce.rapido(c["altura"], c["lamina"], c["flujo"], 30, 19, centro, 5.0)
	assert_near(llano, 0.0, 0.0001, "en el llano, nada")
	# Suavizada con las vecinas, que a un lado del escalón todavía no bajan.
	assert_gt(escalon, 0.3, "en el escalón, espuma")


## La queja que dejó la tarea 1 en captura: la espuma salía en vetas pegadas a la margen
## empinada, porque la caída se medía con la normal del terreno y la orilla de un cauce
## encajado siempre es empinada.
func test_una_margen_empinada_no_es_un_rapido() -> void:
	var c := _cauce(30, 0.0, 99)
	var altura: PackedFloat32Array = c["altura"]
	var lamina: PackedFloat32Array = c["lamina"]
	# La ladera sube a cada lado de la lámina, fuerte.
	for z in range(30):
		for x in range(30):
			if lamina[z * 30 + x] <= 0.0:
				altura[z * 30 + x] = 10.0 + 4.0 * float(absi(z - 15) - 3)
	var en_la_margen := AguaDelCauce.caida(altura, lamina, c["flujo"], 30, 10, 13, 5.0)
	assert_near(en_la_margen, 0.0, 0.0001, "la ladera de al lado no hace rápido")


func test_la_espuma_de_orilla_sale_en_el_borde_y_no_en_el_centro() -> void:
	var c := _cauce(30, 0.0, 99)
	var borde := AguaDelCauce.orilla(c["lamina"], 30, 10, 17)
	var centro := AguaDelCauce.orilla(c["lamina"], 30, 10, 15)
	var fuera := AguaDelCauce.orilla(c["lamina"], 30, 10, 25)
	assert_gt(borde, 0.2, "donde el agua lame la tierra, espuma")
	assert_near(centro, 0.0, 0.0001, "en medio del río, no")
	assert_near(fuera, 0.0, 0.0001, "y en seco, tampoco")


## Queja del usuario del 2026-09-15: «la orilla se está metiendo varios metros en
## tierra». La máscara del río se difumina hacia la ribera para que la hierba no corte a
## cuchillo, y lo difuminado es TIERRA MOJADA: el relieve sólo se allana a la cota del
## agua donde la máscara llega a la línea del agua. Ahí no hay orilla que pintar.
func test_la_orilla_no_se_mete_en_tierra() -> void:
	var c := _cauce(30, 0.0, 99)
	var mojado_pero_tierra := AguaDelCauce.orilla(c["lamina"], 30, 10, 18)
	assert_true(float((c["lamina"] as PackedFloat32Array)[18 * 30 + 10]) < AguaDelCauce.LINEA_DEL_AGUA,
		"la celda de prueba está por fuera de la línea del agua")
	assert_near(mojado_pero_tierra, 0.0, 0.0001, "en la ribera mojada no hay espuma de orilla")


## La corriente va aguas abajo también donde el cauce gira: la saca `Hydrography` del
## orden de los vértices de OSM, y el shader la arrastra en ese sentido.
func test_la_corriente_sigue_el_cauce_cuando_gira() -> void:
	var data := HeightmapData.new()
	data.width = 60
	data.height = 60
	data.meters_per_sample = 5.0
	data.lon_west = -4.0
	data.lon_east = -3.99
	data.lat_north = 43.01
	data.lat_south = 43.00
	data.geographic_rows = true
	data.elevations.resize(3600)
	data.elevations.fill(100.0)
	# Baja de norte a sur por el oeste y gira hacia el este por el sur.
	var codo := {"points": PackedVector2Array([Vector2(-3.998, 43.010), Vector2(-3.998, 43.002),
		Vector2(-3.990, 43.002)]), "half_width_m": 8.0, "kind": "river", "closed": false}
	Hydrography.apply(data, [codo], [])
	var bajando := 15 * 60 + 12
	var girado := 48 * 60 + 45
	assert_gt(data.flow_z[bajando], 0.8, "el primer tramo corre hacia el sur")
	assert_gt(data.flow_x[girado], 0.8, "y tras el codo, hacia el este")


## Lo que se hornea en la malla no depende del nivel del agua de la configuración: el
## nivel sólo enciende cosas en el shader. Y construir la malla no toca los mapas, que
## son los que lee la partida.
func test_el_nivel_del_agua_no_cambia_la_malla_ni_los_mapas() -> void:
	var antes := Configuracion.graficos.duplicate()
	var terreno := _terreno_pequeno()
	var mapas := [terreno._height_map.duplicate(), terreno._river_map.duplicate(), terreno._flow_map.duplicate()]
	Configuracion.graficos["agua"] = 0
	var bajo: Array = await terreno.malla._construir_arrays()
	Configuracion.graficos["agua"] = 3
	var ultra: Array = await terreno.malla._construir_arrays()
	Configuracion.graficos = antes
	var iguales_mapas: bool = mapas[0] == terreno._height_map and mapas[1] == terreno._river_map \
		and mapas[2] == terreno._flow_map
	var uv_bajo: PackedVector2Array = bajo[Mesh.ARRAY_TEX_UV]
	var uv_ultra: PackedVector2Array = ultra[Mesh.ARRAY_TEX_UV]
	var con_espuma := 0
	for v: Vector2 in uv_bajo:
		if v.x > 0.0:
			con_espuma += 1
	terreno.free()
	assert_true(uv_bajo == uv_ultra, "el agua horneada, igual en Bajo y en Ultra")
	assert_true(iguales_mapas, "y los mapas del terreno, intactos")
	assert_gt(float(con_espuma), 0.0, "y el escalón del cauce de prueba sí se hornea")


func _terreno_pequeno() -> TerrainGenerator:
	var res := 30
	var c := _cauce(res, 3.0, 20)
	var terreno := TerrainGenerator.new()
	terreno.terrain_size = Vector2i(145, 145)
	terreno.resolution = res
	terreno._setup_noise()
	terreno._height_map = c["altura"]
	terreno._river_map = c["lamina"]
	terreno._flow_map = c["flujo"]
	return terreno


## Ultra: las salpicaduras no pasan de su número de emisores, eligen los rápidos más
## fuertes cerca de la cámara y no los de lejos.
func test_las_salpicaduras_eligen_los_rapidos_mas_fuertes_cerca() -> void:
	var puntos: Array[Dictionary] = []
	for i in range(30):
		puntos.append({"pos": Vector3(float(i) * 4.0, 0.0, 0.0), "fuerza": 0.6 + float(i % 5) * 0.08,
			"dir": Vector2.RIGHT})
	puntos.append({"pos": Vector3(5000.0, 0.0, 0.0), "fuerza": 1.0, "dir": Vector2.RIGHT})
	var elegidos := SalpicadurasDelRio.elegir_los_que_salpican(puntos, Vector3.ZERO, 12, 160.0)
	var la_mas_debil := INF
	var lejos := false
	for e: Dictionary in elegidos:
		la_mas_debil = minf(la_mas_debil, float(e["fuerza"]))
		if (e["pos"] as Vector3).x > 1000.0:
			lejos = true
	assert_eq(elegidos.size(), 12, "no pasan de su número")
	assert_false(lejos, "el rápido de lejos no entra, por fuerte que sea")
	# Seis de 0,92 y seis de 0,84 son los doce más fuertes; los de 0,76 no entran.
	assert_gt(la_mas_debil, 0.8, "y entran los más fuertes de cerca")


## Las piedras de los rápidos: ninguna en el llano, algunas en el escalón —no todas las
## celdas: agua entre piedras— y siempre las mismas.
func test_las_piedras_salen_en_los_rapidos_y_siempre_en_las_mismas_celdas() -> void:
	var res := 60
	var c := _cauce(res, 0.0, 999)
	var altura: PackedFloat32Array = c["altura"]
	# Todo el cauce baja fuerte desde la columna 20: un rápido largo.
	for z in range(res):
		for x in range(res):
			if x > 20:
				altura[z * res + x] = 10.0 - float(x - 20) * 1.5
	var en_llano := 0
	var en_rapido := 0
	var celdas_de_rapido := 0
	var primera := []
	for z in range(res):
		for x in range(2, res - 3):
			var p := AguaDelCauce.piedra(altura, c["lamina"], c["flujo"], res, x, z, 5.0)
			if x < 18 and p > 0.0:
				en_llano += 1
			if x > 22 and AguaDelCauce.rapido(altura, c["lamina"], c["flujo"], res, x, z, 5.0) > 0.5:
				celdas_de_rapido += 1
				if p > 0.0:
					en_rapido += 1
					primera.append(Vector2i(x, z))
	var otra_vez := []
	for z in range(res):
		for x in range(23, res - 3):
			if AguaDelCauce.piedra(altura, c["lamina"], c["flujo"], res, x, z, 5.0) > 0.0:
				otra_vez.append(Vector2i(x, z))
	assert_eq(en_llano, 0, "en el llano no asoma ninguna")
	assert_gt(float(en_rapido), 0.0, "en el rápido, alguna")
	assert_lt(float(en_rapido), float(celdas_de_rapido) * 0.5, "y agua entre ellas, no un pedregal")
	assert_true(primera == otra_vez, "y en las mismas celdas cada vez")


## La corriente para dibujar se suaviza con las vecinas de agua —una celda torcida no
## tuerce el dibujo— y no mira la tierra de al lado; la de la partida no cambia.
func test_la_corriente_para_dibujar_se_suaviza_sin_tocar_la_de_la_partida() -> void:
	var c := _cauce(30, 0.0, 99)
	var flujo: PackedVector2Array = c["flujo"]
	flujo[15 * 30 + 10] = Vector2(0.0, 1.0)
	var antes := flujo[15 * 30 + 10]
	var suave := AguaDelCauce.corriente_suave(flujo, c["lamina"], 30, 10, 15)
	assert_gt(suave.x, 0.8, "la celda torcida sigue la corriente de sus vecinas")
	assert_lt(suave.y, 0.2, "y apenas se tuerce")
	assert_true(flujo[15 * 30 + 10] == antes, "y la corriente de la partida no se toca")


## La lámina sigue al relieve, pero en la margen no sube más que el tope sobre el agua de
## al lado: el talud la corta. En un hoyo, o en la ribera tendida, su propio relieve.
func test_la_lamina_no_sube_por_el_talud() -> void:
	var c := _cauce(30, 0.0, 99)
	var altura: PackedFloat32Array = c["altura"]
	# El cauce es z 13..17; la margen, z 18, un talud cuatro metros por encima.
	for x in range(30):
		altura[18 * 30 + x] = 14.0
	altura[12 * 30 + 10] = 9.0
	altura[12 * 30 + 11] = 10.2
	assert_near(AguaDelCauce.cota_del_agua(altura, c["lamina"], 30, 10, 15, 0.5), 10.0, 0.0001, "en el agua, su cota")
	assert_near(AguaDelCauce.cota_del_agua(altura, c["lamina"], 30, 10, 18, 0.5), 10.5, 0.0001, "en el talud, el agua y el tope")
	assert_near(AguaDelCauce.cota_del_agua(altura, c["lamina"], 30, 10, 12, 0.5), 9.0, 0.0001, "en el hoyo, la suya")
	assert_near(AguaDelCauce.cota_del_agua(altura, c["lamina"], 30, 11, 12, 0.5), 10.2, 0.0001, "en la ribera tendida, la suya")
	assert_near(AguaDelCauce.cota_del_agua(altura, c["lamina"], 30, 10, 25, 0.5), 10.0, 0.0001, "lejos del agua, la suya")


## La orilla dentada: un valle que corre en diagonal a la rejilla se parte a lo largo del
## valle —vaya por la diagonal que vaya—, y un plano como siempre.
func test_cada_cuadro_se_parte_a_lo_largo_del_valle() -> void:
	var valle := PackedFloat32Array()
	var valle_cruzado := PackedFloat32Array()
	var plano := PackedFloat32Array()
	for z in range(12):
		for x in range(12):
			valle.append(absf(float(x - z)) * 5.0)
			valle_cruzado.append(absf(float(x + z - 11)) * 5.0)
			plano.append(float(x + z))
	assert_true(MallaDelTerreno.diagonal_principal(valle, 12, 5, 5), "el valle, por su fondo")
	assert_false(MallaDelTerreno.diagonal_principal(valle_cruzado, 12, 5, 5), "el valle de la otra diagonal, por el suyo")
	assert_false(MallaDelTerreno.diagonal_principal(plano, 12, 5, 5), "el plano, como siempre")

