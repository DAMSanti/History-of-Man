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
	# montículo, monte…» (2026-09-14). Sin cambiar qué es tierra y qué mar ni con
	# el mar de hoy ni con el del Paleolítico: la costa y la frontera siguen.
	var original: HeightmapData = load("res://data/dem/cantabria_region.res")
	if original == null:
		assert_true(false, "falta el relieve")
		return
	var con := original.duplicate() as HeightmapData
	RelieveDeLaPlataforma.aplicar(con, -120.0)
	var cambian := 0
	var sube_mas := 0.0
	var por_encima_de_cien := 0
	for i in range(original.elevations.size()):
		var antes := original.elevations[i]
		var ahora := con.elevations[i]
		# Lo que era mar con el mar de la época sigue igual, y lo que era tierra
		# sigue siendo tierra: el relieve sólo sube lo que ya emergía.
		if (antes > -120.0) != (ahora > -120.0) or (antes <= -120.0 and ahora != antes):
			cambian += 1
		sube_mas = maxf(sube_mas, ahora - antes)
		if ahora - antes > 100.0:
			por_encima_de_cien += 1
	assert_eq(cambian, 0, "con el mar a -120 la costa no se mueve")
	# 288 m medido: el ruido casi nunca llega al percentil 99 de la franja real
	# (312 m), y ése es el tope que se ve.
	assert_gt(sube_mas, 250.0, "y hay orografía de verdad: el mayor sube %.0f m" % sube_mas)
	assert_gt(float(por_encima_de_cien), 1000.0,
		"con cerros por todas partes: %d celdas suben de 100 m" % por_encima_de_cien)


func test_con_el_mar_de_hoy_la_plataforma_sigue_bajo_el_agua() -> void:
	# La otra promesa: el relieve es de la época que se juega, y con el mar de hoy
	# la plataforma es mar y no se toca.
	var original: HeightmapData = load("res://data/dem/cantabria_region.res")
	var con := original.duplicate() as HeightmapData
	RelieveDeLaPlataforma.aplicar(con, 0.0)
	var cambian := 0
	for i in range(original.elevations.size()):
		if original.elevations[i] <= 0.0 and con.elevations[i] != original.elevations[i]:
			cambian += 1
	assert_eq(cambian, 0, "ninguna celda bajo el agua de hoy se levanta")
