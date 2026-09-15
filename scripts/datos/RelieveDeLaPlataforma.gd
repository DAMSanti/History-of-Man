class_name RelieveDeLaPlataforma
extends RefCounted
## La orografía de la plataforma que emerge con el mar bajo.
##
## Petición del usuario del 2026-09-14: «la plataforma emergida es totalmente
## plana». La batimetría del relieve regional va a 111 m por muestra y el fondo
## sale liso: con el mar a −120 m se veía una llanura sin un bulto.
##
## **Reescrito el mismo día, con la queja repetida**: la primera versión subía el
## fondo saturando hacia la cota cero de hoy —para no mover la costa actual—, así
## que las lomas se quedaban en veinte o treinta metros sobre un mapa de doscientos
## kilómetros: invisibles. El usuario: «no se aprecia NADA de elevación… quiero que
## tenga orografía como hoy la hay entre Santander y Torrelavega».
##
## **Las alturas salen de ahí, medidas** sobre `cantabria_region.res` en la franja
## costera entre las dos (43,33–43,48 N, 4,08–3,78 O; 28 637 celdas de tierra):
##
## | | p05 | p25 | p50 | p75 | p90 | p99 | máx |
## |---|---|---|---|---|---|---|---|
## | cota | 3 m | 19 m | 48 m | 100 m | 159 m | 312 m | 515 m |
##
## y el terreno sube o baja **22 m por kilómetro** de mediana, 86 en el décimo más
## quebrado. El ruido se mapea a esa escalera de percentiles, así que la plataforma
## tiene la misma repartición de alturas que esa costa, y la escala de las formas
## sale de ese desnivel por kilómetro.
##
## **Dos promesas, y las dos por construcción:**
##
## - **La costa de la época no se mueve.** Sólo se sube lo que YA es tierra con ese
##   mar (`e > mar`), y subir tierra la deja tierra. Lo que está bajo el agua no se
##   toca, así que con el mar de hoy la plataforma sigue siendo mar.
## - **La orilla es llana.** El bulto entra con una rampa desde la costa
##   ([LLANURA_M]), que es lo que deja sitio a la playa y a la hierba de orilla
##   —decisión del usuario del 2026-09-14—.
##
## Lo usan los tres que dibujan o miden la plataforma: [RegionMap] al montar el
## terreno, `tools/HornearEras.gd` al hornear las máscaras de cada época —cada una
## con SU mar— y `TestFrontera`.

## Hasta qué cota de hoy hay plataforma: por encima de cero es tierra de siempre y
## no se toca.
const HASTA := 0.0

## Los percentiles medidos de la franja Santander–Torrelavega, y su cota.
const PERCENTILES: Array[float] = [0.05, 0.25, 0.50, 0.75, 0.90, 0.99, 1.0]
const COTAS: Array[float] = [3.0, 19.0, 48.0, 100.0, 159.0, 312.0, 515.0]

## Cuánta costa se queda llana antes de que empiecen las colinas, en metros.
## Decisión del usuario: «llanura costera antes de las colinas».
const LLANURA_M := 600.0

## Cada cuántos metros se repite una loma. De los 22 m de desnivel por kilómetro
## medidos: con dos kilómetros de onda y la escalera de percentiles sale ese
## desnivel.
const ONDA_M := 2000.0

## Cada cuántas muestras se mide la distancia a la costa. A 111 m por muestra, de
## cuatro en cuatro son 444 m: de sobra para una rampa de 600, y cuesta la
## dieciseisava parte.
const PASO_DE_LA_DISTANCIA := 4


## Le pone orografía a la plataforma emergida con ese mar. Sin `mar`, el del
## Paleolítico.
## Lo que decide estas lomas, en un número: si cambia una cifra de arriba, cambia. Va en
## el nombre de la caché de la malla regional (ver [TerrainGenerator.sufijo_de_la_cache]),
## así que retocar las lomas rehace la malla sola en vez de seguir enseñando la vieja.
static func huella() -> int:
	return hash([HASTA, PERCENTILES, COTAS, LLANURA_M, ONDA_M, PASO_DE_LA_DISTANCIA])


static func aplicar(data: HeightmapData, mar: float = -120.0) -> void:
	if data == null or data.elevations.is_empty():
		return
	var relieve := FastNoiseLite.new()
	relieve.seed = 20260914
	relieve.noise_type = FastNoiseLite.TYPE_SIMPLEX
	relieve.fractal_type = FastNoiseLite.FRACTAL_FBM
	relieve.fractal_octaves = 4
	relieve.frequency = data.meters_per_sample / ONDA_M

	# UNA COPIA DE VERDAD. `Resource.duplicate()` no copia este array: la copia
	# y el original lo comparten, y escribir en él escribía en el recurso que
	# `load()` tiene en caché —medido el 2026-09-14—.
	var elevaciones := PackedFloat32Array(data.elevations)
	var distancia := _distancia_a_la_costa(elevaciones, data.width, mar,
		data.meters_per_sample)
	var ancho_corto := int(ceil(float(data.width) / float(PASO_DE_LA_DISTANCIA)))
	for i in range(elevaciones.size()):
		var e := elevaciones[i]
		if e <= mar or e >= HASTA:
			continue
		var x := i % data.width
		@warning_ignore("integer_division")
		var z := i / data.width
		@warning_ignore("integer_division")
		var corta := (z / PASO_DE_LA_DISTANCIA) * ancho_corto + x / PASO_DE_LA_DISTANCIA
		var rampa := clampf(distancia[corta] / LLANURA_M, 0.0, 1.0)
		var altura := _cota_del_ruido(relieve.get_noise_2d(float(x), float(z)))
		elevaciones[i] = e + altura * rampa
	data.elevations = elevaciones


## La cota que le toca a un valor de ruido, por la escalera de percentiles
## medidos: así la plataforma tiene la repartición de alturas de esa costa.
static func _cota_del_ruido(ruido: float) -> float:
	var t := clampf(ruido * 0.5 + 0.5, 0.0, 1.0)
	var antes_p := 0.0
	var antes_cota := 0.0
	for i in range(PERCENTILES.size()):
		if t <= PERCENTILES[i]:
			var tramo := maxf(PERCENTILES[i] - antes_p, 0.0001)
			return lerpf(antes_cota, COTAS[i], (t - antes_p) / tramo)
		antes_p = PERCENTILES[i]
		antes_cota = COTAS[i]
	return COTAS[COTAS.size() - 1]


## A cuántos metros de la costa está cada celda, en una rejilla de un cuarto de
## lado. Dos pasadas de chanfle —ida y vuelta—, que es lo que cuesta una distancia
## aproximada sin recorrer el mapa entero por cada celda.
static func _distancia_a_la_costa(elevaciones: PackedFloat32Array, ancho: int,
		mar: float, metros_por_muestra: float) -> PackedFloat32Array:
	var alto := int(elevaciones.size() / ancho)
	var ancho_corto := int(ceil(float(ancho) / float(PASO_DE_LA_DISTANCIA)))
	var alto_corto := int(ceil(float(alto) / float(PASO_DE_LA_DISTANCIA)))
	var paso_m := metros_por_muestra * float(PASO_DE_LA_DISTANCIA)
	var lejos := 1.0e9
	var distancia := PackedFloat32Array()
	distancia.resize(ancho_corto * alto_corto)
	for zc in range(alto_corto):
		for xc in range(ancho_corto):
			var i := mini(zc * PASO_DE_LA_DISTANCIA, alto - 1) * ancho \
				+ mini(xc * PASO_DE_LA_DISTANCIA, ancho - 1)
			distancia[zc * ancho_corto + xc] = lejos if elevaciones[i] > mar else 0.0
	for zc in range(alto_corto):
		for xc in range(ancho_corto):
			var i := zc * ancho_corto + xc
			if xc > 0:
				distancia[i] = minf(distancia[i], distancia[i - 1] + paso_m)
			if zc > 0:
				distancia[i] = minf(distancia[i], distancia[i - ancho_corto] + paso_m)
	for zc in range(alto_corto - 1, -1, -1):
		for xc in range(ancho_corto - 1, -1, -1):
			var i := zc * ancho_corto + xc
			if xc < ancho_corto - 1:
				distancia[i] = minf(distancia[i], distancia[i + 1] + paso_m)
			if zc < alto_corto - 1:
				distancia[i] = minf(distancia[i], distancia[i + ancho_corto] + paso_m)
	return distancia
