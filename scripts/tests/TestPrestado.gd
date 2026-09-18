class_name TestPrestado
extends TestCase
## El relieve prestado: detalle real de otro sitio, cosido sin que se note. GRAFICOS §3,
## depurar del 2026-09-17.

func suite_name() -> String:
	return "Prestado"


## Desviacion tipica de una lista.
static func _desviacion(valores: PackedFloat32Array) -> Dictionary:
	var suma := 0.0
	for v in valores:
		suma += v
	var media := suma / maxf(float(valores.size()), 1.0)
	var acum := 0.0
	for v in valores:
		acum += (v - media) * (v - media)
	return {"media": media, "tipica": sqrt(acum / maxf(float(valores.size()), 1.0))}


func test_el_detalle_de_un_trozo_tiene_media_cero() -> void:
	# Una ladera inclinada con lomas encima: la ladera es forma grande y se va; las lomas
	# se quedan.
	var lado := 96
	var cotas := PackedFloat32Array()
	cotas.resize(lado * lado)
	for z in range(lado):
		for x in range(lado):
			cotas[z * lado + x] = float(x) * 2.0 + sin(float(x) * 0.6) * 10.0 \
				+ cos(float(z) * 0.5) * 10.0
	var prestado := RelievePrestado.new()
	prestado.radio_m = 2000.0
	prestado.sumar_trozo(cotas, lado, lado, 100.0)
	var detalle: PackedFloat32Array = prestado._trozos[0]["detalle"]
	# Sin los bordes, donde el emborronado se sale.
	var dentro := PackedFloat32Array()
	for z in range(25, lado - 25):
		for x in range(25, lado - 25):
			dentro.append(detalle[z * lado + x])
	var d := _desviacion(dentro)
	assert_near(float(d["media"]), 0.0, 2.0, "media cero: %.2f" % d["media"])
	assert_true(float(d["tipica"]) > 5.0 and float(d["tipica"]) < 15.0,
		"y se quedan las lomas, no la ladera: típica %.1f m" % d["tipica"])


func test_la_region_da_trozos_de_tierra_real() -> void:
	var regional: HeightmapData = load("res://data/dem/cantabria_region.res")
	var prestado := RelievePrestado.de_la_region(regional)
	assert_gt(float(prestado.cuantos()), 10.0,
		"la franja costera da trozos enteros de tierra: %d" % prestado.cuantos())


func test_cosido_la_amplitud_no_baja_en_las_juntas() -> void:
	# LO QUE HACE QUE NO SE NOTE: si mezclar cuatro bloques bajara la amplitud en las
	# juntas, se verían como surcos lisos cada cuatro kilómetros.
	var regional: HeightmapData = load("res://data/dem/cantabria_region.res")
	var prestado := RelievePrestado.de_la_region(regional)
	var centros := PackedFloat32Array()
	var juntas := PackedFloat32Array()
	for j in range(40):
		for i in range(40):
			var b := prestado.bloque_m
			centros.append(prestado.detalle((float(i) + 0.5) * b + 37.0, (float(j) + 0.5) * b + 53.0))
			juntas.append(prestado.detalle(float(i) * b, float(j) * b))
	var en_centros := _desviacion(centros)
	var en_juntas := _desviacion(juntas)
	print("   detalle prestado a 111 m: típica %.1f m en los centros, %.1f m en las juntas" % [
		en_centros["tipica"], en_juntas["tipica"]])
	assert_gt(float(en_centros["tipica"]), 3.0, "hay relieve")
	assert_near(float(en_juntas["tipica"]) / float(en_centros["tipica"]), 1.0, 0.3,
		"y en las juntas la amplitud es la misma que en los centros")


func test_el_mismo_punto_da_siempre_lo_mismo() -> void:
	var regional: HeightmapData = load("res://data/dem/cantabria_region.res")
	var uno := RelievePrestado.de_la_region(regional)
	var otro := RelievePrestado.de_la_region(regional)
	assert_eq(uno.detalle(12345.0, 67890.0), otro.detalle(12345.0, 67890.0),
		"sin azar: el valle rehecho sale igual")
