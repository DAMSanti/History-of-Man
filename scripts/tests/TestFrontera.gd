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
	# Cantabria, medida en la costa. Fuera de ellos no se mira, que ahí delante
	# están Asturias y el País Vasco y la frontera no debe seguir. Estimarlos
	# aquí por otro camino daba dos columnas de más, y la prueba fallaba por el
	# límite y no por la costa.
	var frontera: RegionBoundary = load("res://data/boundaries/cantabria.res")
	var costa := frontera._coastal_x_range(frontera.rasterize(relieve), relieve)
	var x_min := costa.x
	var x_max := costa.y

	# Tierra emergida de la época —fondo por encima de −120 y por debajo de
	# cero— pegada al territorio pero fuera de él: eso es costa que se queda sin
	# línea.
	var fuera := 0
	for z in range(1, h - 1):
		for x in range(maxi(x_min, 1), mini(x_max, w - 2) + 1):
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
