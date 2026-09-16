class_name Avistamiento
extends RefCounted
## Qué yacimientos se ven desde una cima, sobre el relieve regional: SISTEMAS §4, spec
## del 2026-09-15, «las tres cumbres más altas de cada valle avistan».
##
## **La vista de verdad**: de la cima a cada yacimiento se recorre el relieve regional a
## pasos de una celda, y si algo asoma por encima de la visual el yacimiento no se ve —lo
## que tapa una sierra no se ve—. Con la curvatura de la Tierra y la refracción, porque
## las distancias son de decenas de kilómetros: a 50 km se esconden unos 170 m.
##
## Estático y sin estado: el relieve entra por parámetro, para que la prueba ponga su
## sierra a mano.

## A qué altura sobre la cima mira quien corona, en metros. Decisión aceptada por el
## usuario el 2026-09-16: los ojos de alguien de pie.
const OJO_M := 1.6

## A qué altura sobre su suelo tiene que verse un yacimiento para contar como visto.
## Decisión aceptada por el usuario el 2026-09-16: una boca de cueva, un abrigo.
const YACIMIENTO_M := 2.0

## El coeficiente de refracción de la atmósfera: la luz se curva hacia abajo y deja ver
## algo más allá del horizonte geométrico. 0,13 es el valor de uso en topografía.
const REFRACCION := 0.13

const RADIO_DE_LA_TIERRA_M := 6371000.0

## Lo que no se mira junto a la cima, en metros. La cota de la cima sale del mapa local,
## más fino que el regional de ~111 m: sin esto, las celdas de al lado —la misma cima
## redondeada— podían tapar la vista desde su propio punto más alto.
const SIN_MIRAR_M := 300.0


## Los yacimientos de `sitios` que se ven desde la cima en (`lon`, `lat`), con su cota en
## metros —la del mapa local, que es más fina—, sobre `relieve`.
static func a_la_vista(lon: float, lat: float, cota_de_la_cima: float, sitios: Array[Site],
		relieve: HeightmapData) -> Array[Site]:
	var vistos: Array[Site] = []
	if relieve == null:
		return vistos
	var ojo := cota_de_la_cima + OJO_M
	var paso := relieve.meters_per_sample if relieve.meters_per_sample > 0.0 else 111.0
	var coseno := cos(deg_to_rad(lat))
	for site: Site in sitios:
		var este := (site.lon - lon) * Viaje.METROS_POR_GRADO * coseno
		var norte := (site.lat - lat) * Viaje.METROS_POR_GRADO
		var lejos := sqrt(este * este + norte * norte)
		if lejos < 1.0:
			continue
		var objetivo := _cota(relieve, site.lon, site.lat) + YACIMIENTO_M - _escondido(lejos)
		var visual := (objetivo - ojo) / lejos
		var se_ve := true
		var pasos := int(lejos / paso)
		for i in range(1, pasos):
			var d := float(i) * paso
			if d < SIN_MIRAR_M:
				continue
			var t := d / lejos
			var alto := _cota(relieve, lon + (site.lon - lon) * t, lat + (site.lat - lat) * t) \
				- _escondido(d)
			if (alto - ojo) / d > visual:
				se_ve = false
				break
		if se_ve:
			vistos.append(site)
	return vistos


## Los `cuantos` más lejanos de (`lon`, `lat`), del más lejano al más cercano.
static func los_mas_lejanos(lon: float, lat: float, sitios: Array[Site], cuantos: int) -> Array[Site]:
	var coseno := cos(deg_to_rad(lat))
	var ordenados := sitios.duplicate()
	ordenados.sort_custom(func(a: Site, b: Site) -> bool:
		var ax := (a.lon - lon) * coseno
		var az := a.lat - lat
		var bx := (b.lon - lon) * coseno
		var bz := b.lat - lat
		return ax * ax + az * az > bx * bx + bz * bz)
	if ordenados.size() > cuantos:
		ordenados.resize(cuantos)
	return ordenados


static func _cota(relieve: HeightmapData, lon: float, lat: float) -> float:
	return relieve.sample_bilinear(relieve.u_for_lon(lon), relieve.v_for_lat(lat))


## Cuánto baja el suelo a `d` metros por la curvatura, descontada la refracción.
static func _escondido(d: float) -> float:
	return d * d * (1.0 - REFRACCION) / (2.0 * RADIO_DE_LA_TIERRA_M)
