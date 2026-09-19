class_name TestFrontera
extends TestCase
## La frontera de la comunidad llega hasta el agua de la época.
##
## Frente 18 de EPOCA_01 §10.1, tanda 4: «con el mar a −120 m, ningún tramo de
## costa emergida queda fuera de la línea de frontera». Se comprueba sobre la
## máscara horneada, que es lo que dibuja el mapa regional.


func suite_name() -> String:
	return "Frontera"


func test_a_menos_ciento_veinte_la_linea_llega_al_agua() -> void:
	var relieve: HeightmapData = load("res://data/dem/cantabria_region.res")
	var eras: RegionEras = load("res://data/sites/cantabria_eras.res")
	if relieve == null or eras == null:
		assert_true(false, "faltan el relieve o las máscaras horneadas")
		return
	var i := eras.index_for(-120.0)
	assert_eq(eras.sea_levels[i], -120.0, "hay máscara para el Paleolítico")
	var mascara: PackedByteArray = eras.masks[i]
	var w := eras.width
	var h := eras.height

	# Los límites laterales, CON EL MISMO CÁLCULO que el constructor: la costa de
	# Cantabria, medida en la costa, y quebrada fila a fila desde el 2026-09-14
	# —ver [RegionBoundary._limites_por_fila]—. Fuera de ellos no se mira, que ahí
	# delante están Asturias y el País Vasco y la frontera no debe seguir.
	# Estimarlos aquí por otro camino daba dos columnas de más, y la prueba
	# fallaba por el límite y no por la costa.
	var frontera: RegionBoundary = load("res://data/boundaries/cantabria.res")
	var limites := frontera.limites_por_fila(relieve)

	# Tierra emergida de la época —fondo por encima de −120 y por debajo de
	# cero— pegada al territorio pero fuera de él: eso es costa que se queda sin
	# línea.
	var fuera := 0
	for z in range(1, h - 1):
		var limite: Vector2i = limites[z]
		for x in range(maxi(limite.x, 1), mini(limite.y, w - 2) + 1):
			var j := z * w + x
			if mascara[j] > 0:
				continue
			var e: float = relieve.elevations[j]
			if e <= -120.0 or e > 0.0:
				continue
			if mascara[j - 1] > 0 or mascara[j + 1] > 0 \
					or mascara[j - w] > 0 or mascara[j + w] > 0:
				fuera += 1
	assert_eq(fuera, 0, "ninguna celda de costa emergida se queda fuera")


func test_mar_adentro_la_frontera_no_es_una_regla() -> void:
	# Petición del usuario del 2026-09-14: «la frontera ampliada hacia el norte,
	# algo fractal y no completamente recta, como una frontera moderna». Eran dos
	# columnas fijas: el borde de poniente de la plataforma salía en la misma
	# columna fila tras fila.
	var eras: RegionEras = load("res://data/sites/cantabria_eras.res")
	if eras == null:
		assert_true(false, "faltan las máscaras horneadas")
		return
	var mascara: PackedByteArray = eras.masks[eras.index_for(-120.0)]
	var hoy: PackedByteArray = eras.masks[eras.index_for(0.0)]
	var w := eras.width
	# De cada fila, el borde de poniente y el de levante de la máscara a -120,
	# sólo donde ese borde es PLATAFORMA —más allá de la tierra de hoy en esa
	# fila—; y de todas, la RACHA más larga de filas seguidas con el borde en la
	# misma columna. Una regla da una racha tan larga como la plataforma; una raya
	# quebrada, rachas cortas. Medido con la máscara vieja: el levante clavado en
	# la misma columna más de ciento sesenta filas seguidas.
	var filas := 0
	var peor_racha := 0
	for lado: int in [-1, 1]:
		var racha := 0
		var anterior := -1
		for z in range(eras.height):
			var borde := _borde(mascara, z, w, lado)
			var tierra := _borde(hoy, z, w, lado)
			var es_plataforma := borde >= 0 and (tierra < 0
				or (lado < 0 and borde < tierra) or (lado > 0 and borde > tierra))
			if not es_plataforma:
				anterior = -1
				racha = 0
				continue
			filas += 1
			racha = racha + 1 if borde == anterior else 1
			anterior = borde
			peor_racha = maxi(peor_racha, racha)
	assert_gt(float(filas), 40.0, "hay plataforma que mirar")
	assert_lt(float(peor_racha), 12.0,
		"la frontera quiebra: la racha recta más larga es de %d filas" % peor_racha)


## La primera columna con territorio de una fila, empezando por poniente (-1) o
## por levante (1). -1 si la fila no tiene.
func _borde(mascara: PackedByteArray, z: int, w: int, lado: int) -> int:
	for i in range(w):
		var x := i if lado < 0 else w - 1 - i
		if mascara[z * w + x] > 0:
			return x
	return -1


func test_la_plataforma_tiene_relieve_y_no_mueve_la_costa() -> void:
	# «La plataforma emergida es totalmente plana; deberíamos hacer algún
	# montículo, monte…» (2026-09-14).
	#
	# **Hasta el 2026-09-17 esto comprobaba que la costa no se movía en absoluto.** Con
	# relieve real prestado, las vaguadas que llegan al mar se inundan —rías, decisión del
	# usuario, GRAFICOS §3—, así que la promesa es otra: **la tierra sólo se vuelve mar como
	# ría, unida al mar**. Nunca un lago bajo el nivel del mar, que el plano del agua
	# pintaría de mar sin serlo.
	#
	# Y **el mar tampoco queda intacto desde esa misma tarde**: el fondo de los primeros
	# 60 m bajo la lámina lleva detalle para que la isolínea de la costa no sea un corte
	# —sin eso salía una raya de escalones de hasta 49,5 m—. Lo que se promete ahora es que
	# **el mar sigue siendo mar**: nada sumergido emerge.
	var original: HeightmapData = load("res://data/dem/cantabria_region.res")
	if original == null:
		assert_true(false, "falta el relieve")
		return
	var con := original.duplicate() as HeightmapData
	RelieveDeLaPlataforma.aplicar(con, -120.0)
	var mar_tocado := 0
	var sube_mas := 0.0
	var por_encima_de_cien := 0
	var nuevo_mar := PackedByteArray()
	nuevo_mar.resize(original.elevations.size())
	var rias := 0
	for i in range(original.elevations.size()):
		var antes := original.elevations[i]
		var ahora := con.elevations[i]
		if antes <= -120.0 and ahora > -120.0:
			mar_tocado += 1
		if antes > -120.0 and ahora <= -120.0:
			nuevo_mar[i] = 1
			rias += 1
		sube_mas = maxf(sube_mas, ahora - antes)
		if ahora - antes > 100.0:
			por_encima_de_cien += 1
	# Cada celda de ría, unida al mar de antes por otras de ría.
	var ancho := original.width
	var cola := PackedInt32Array()
	var visto := PackedByteArray()
	visto.resize(original.elevations.size())
	for i in range(original.elevations.size()):
		if original.elevations[i] <= -120.0:
			visto[i] = 1
			cola.append(i)
	var leido := 0
	var rias_unidas := 0
	while leido < cola.size():
		var i := cola[leido]
		leido += 1
		for vecino: int in [i - 1, i + 1, i - ancho, i + ancho]:
			if vecino < 0 or vecino >= visto.size() or visto[vecino] == 1:
				continue
			if absi(vecino % ancho - i % ancho) > 1 or nuevo_mar[vecino] == 0:
				continue
			visto[vecino] = 1
			rias_unidas += 1
			cola.append(vecino)
	assert_eq(mar_tocado, 0, "con el mar a -120, lo que era mar sigue siendo mar")
	assert_gt(float(rias), 0.0, "hay rías: %d celdas de tierra inundadas" % rias)
	assert_eq(rias_unidas, rias, "y todas unidas al mar: ningún lago bajo su nivel")
	# 288 m medido: el ruido casi nunca llega al percentil 99 de la franja real
	# (312 m), y ése es el tope que se ve.
	assert_gt(sube_mas, 250.0, "y hay orografía de verdad: el mayor sube %.0f m" % sube_mas)
	assert_gt(float(por_encima_de_cien), 1000.0,
		"con cerros por todas partes: %d celdas suben de 100 m" % por_encima_de_cien)


func test_con_el_mar_de_hoy_la_plataforma_sigue_bajo_el_agua() -> void:
	# La otra promesa: el relieve es de la época que se juega, y con el mar de hoy la
	# plataforma **sigue siendo mar**. Su fondo sí cambia —lleva detalle hasta 60 m bajo la
	# lámina, 2026-09-17— pero no emerge ni una celda.
	var original: HeightmapData = load("res://data/dem/cantabria_region.res")
	var con := original.duplicate() as HeightmapData
	RelieveDeLaPlataforma.aplicar(con, 0.0)
	var emergen := 0
	var hondas := 0
	for i in range(original.elevations.size()):
		if original.elevations[i] > 0.0:
			continue
		if con.elevations[i] > 0.0:
			emergen += 1
		# Y el fondo de verdad, el que está más abajo del detalle, intacto.
		if original.elevations[i] < -80.0 and con.elevations[i] != original.elevations[i]:
			hondas += 1
	assert_eq(emergen, 0, "ninguna celda bajo el agua de hoy emerge")
	assert_eq(hondas, 0, "y por debajo de 80 m el fondo se queda como estaba")


## LA CINTA SE TIENE QUE VER DESDE ARRIBA, que es de donde se mira el mapa.
##
## Nació de una queja de bulto —«la línea amarilla que marca el límite ha desaparecido»—
## cuyo fallo no era ni el trazado ni el color ni la cota: los triángulos estaban girados al
## revés, o sea mirando hacia abajo, y la cámara del mapa los descartaba por cara trasera.
## El nodo seguía ahí, visible, con 13 036 triángulos y despejado 2,14 unidades sobre el
## terreno; medido con `PartidaNuevaProbe` el 2026-09-19.
##
## **Ninguna prueba lo habría cogido, y una captura tampoco**, porque no falla nada: sale
## un mapa sin línea. Lo que se fija aquí es el giro, que es lo único que estaba mal.
##
## La cara delantera de Godot es la de giro horario vista desde delante, así que para que
## la cara de arriba sea la delantera, `(v1-v0) x (v2-v0)` tiene que apuntar hacia ABAJO.
func test_la_cinta_de_la_frontera_mira_hacia_arriba() -> void:
	var Mapa := load("res://scripts/region/RegionMap.gd")
	# Los dos únicos tramos que traza [RegionMap._trace_border]: el que sigue un borde
	# vertical de la trama y el que sigue uno horizontal.
	var tramos := {
		"vertical": [Vector3(10.0, 0.0, 0.0), Vector3(10.0, 0.0, 20.0), Vector3(-2.0, 0.0, 0.0)],
		"horizontal": [Vector3(0.0, 0.0, 10.0), Vector3(20.0, 0.0, 10.0), Vector3(0.0, 0.0, 2.0)],
	}
	for nombre: String in tramos:
		var t: Array = tramos[nombre]
		var v: Array[Vector3] = Mapa.tramo_de_la_cinta(t[0], t[1], t[2])
		assert_eq(v.size(), 6, "un tramo de cinta son dos triángulos")
		for i in range(0, 6, 3):
			var hacia: Vector3 = (v[i + 1] - v[i]).cross(v[i + 2] - v[i])
			assert_true(hacia.y < 0.0,
				"tramo %s, triángulo %d: la cara de arriba tiene que ser la delantera" % [
					nombre, i / 3])
