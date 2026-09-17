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

## La versión de cómo se leen las cifras de arriba. **2 desde el 2026-09-16**: la
## distancia a la costa se lee interpolada y no por casillas de cuatro muestras, que
## en un valle de 5 m salían en terrazas de 444 m (EPOCA_01 §10.2). Entra en la
## [huella], así que la malla regional se rehace sola.
const VERSION := 3

## Cuánto más altas son las lomas que las medidas entre Santander y Torrelavega.
##
## **Es `static var` y no constante a propósito**: el usuario pidió más relieve en la
## plataforma («se ve poco», 2026-09-16) y cuánto se elige mirando capturas con varias
## propuestas, que la sonda pone cambiando esto. Fuera de la sonda nadie lo toca; entra
## en la [huella], así que cada propuesta tiene su malla.
## **1,6**: la eligió el usuario el 2026-09-16 entre ×1, ×1,6 y ×2,4 con capturas frente a
## Santander (`PlataformaCaptura AMPLITUDES=1,1.6,2.4`).
static var amplitud := 1.6

## Cuánto se abre un valle a cada lado de un río de la plataforma, en metros. A esta
## distancia las lomas ya son las de siempre; en el río, el fondo del valle.
const ANCHO_DEL_VALLE_M := 1500.0

## Cuánto se hunde el fondo del valle bajo la cota más baja que lleva el río, en
## metros. Es lo que hace que baje siempre, aunque la batimetría tenga un umbral.
const HONDO_DEL_CAUCE_M := 3.0


## Le pone orografía a la plataforma emergida con ese mar. Sin `mar`, el del
## Paleolítico.
## Lo que decide estas lomas, en un número: si cambia una cifra de arriba, cambia. Va en
## el nombre de la caché de la malla regional (ver [TerrainGenerator.sufijo_de_la_cache]),
## así que retocar las lomas rehace la malla sola en vez de seguir enseñando la vieja.
static func huella() -> int:
	return hash([HASTA, PERCENTILES, COTAS, LLANURA_M, ONDA_M, PASO_DE_LA_DISTANCIA, VERSION,
		amplitud, ANCHO_DEL_VALLE_M, HONDO_DEL_CAUCE_M])


static func aplicar(data: HeightmapData, mar: float = -120.0, cauces: Array = []) -> void:
	if data == null or data.elevations.is_empty():
		return
	var plataforma := para(data, mar, cauces)
	var elevaciones := PackedFloat32Array(data.elevations)
	for i in range(elevaciones.size()):
		var e := elevaciones[i]
		if e <= mar or e >= HASTA:
			continue
		var x := i % data.width
		@warning_ignore("integer_division")
		var z := i / data.width
		elevaciones[i] = plataforma._cota_de_la_plataforma(e, float(x), float(z))
	data.elevations = elevaciones


# --- La cota de un punto suelto ------------------------------------------------
#
# `aplicar` trabaja sobre la rejilla regional entera, a 111 m por muestra. El valle
# de un sitio de la plataforma se inventa a 5 m (EPOCA_01 §10.2) y tiene que casar
# con lo que se ve en el mapa: por eso la cota de un punto sale de LAS MISMAS
# cuentas, con el ruido leído en la posición fraccionaria y las distancias
# interpoladas. En las muestras de la rejilla, las dos dan lo mismo.

var _datos: HeightmapData = null
var _mar: float = -120.0
var _ruido: FastNoiseLite = null
var _distancia: PackedFloat32Array = PackedFloat32Array()
var _ancho_corto: int = 0
var _alto_corto: int = 0
## La distancia al río de la plataforma más cercano, en las casillas cortas, y la cota
## del fondo de su valle. Vacías si no se dieron ríos.
var _al_rio: PackedFloat32Array = PackedFloat32Array()
var _fondo: PackedFloat32Array = PackedFloat32Array()


## Deja preparada la plataforma de estos datos regionales, **sin aplicar**, para
## preguntarle puntos. Los datos tienen que ser los de siempre, sin lomas. `cauces`
## son los tramos de la plataforma de [RiosDeLaRegion]: por donde van, se abre valle.
static func para(data: HeightmapData, mar: float = -120.0,
		cauces: Array = []) -> RelieveDeLaPlataforma:
	var plataforma := RelieveDeLaPlataforma.new()
	plataforma._datos = data
	plataforma._mar = mar
	if data == null or data.elevations.is_empty():
		return plataforma
	plataforma._ruido = _ruido_para(data)
	plataforma._distancia = _distancia_a_la_costa(data.elevations, data.width, mar,
		data.meters_per_sample)
	plataforma._ancho_corto = int(ceil(float(data.width) / float(PASO_DE_LA_DISTANCIA)))
	plataforma._alto_corto = int(ceil(float(data.height) / float(PASO_DE_LA_DISTANCIA)))
	if not cauces.is_empty():
		plataforma._valles(cauces)
	return plataforma


## La cota con lomas en ese punto, en metros.
func cota_en(lon: float, lat: float) -> float:
	if _datos == null or _datos.elevations.is_empty():
		return 0.0
	var u := clampf(_datos.u_for_lon(lon), 0.0, 1.0)
	var v := clampf(_datos.v_for_lat(lat), 0.0, 1.0)
	var e := _datos.sample_bilinear(u, v)
	if e <= _mar or e >= HASTA:
		return e
	return _cota_de_la_plataforma(e, u * float(_datos.width - 1), v * float(_datos.height - 1))


## La cota final de una celda de la plataforma con cota de fondo `e`, en la posición
## `fx`, `fz` de la rejilla (en muestras, con decimales).
##
## El nombre largo es a propósito: `MallaDelTerreno` tiene su propio `_cota`, y
## `LlamadasHuerfanas` sólo ve nombres, así que un `_cota` aquí salía como llamada mal
## puesta a la del terreno.
func _cota_de_la_plataforma(e: float, fx: float, fz: float) -> float:
	var rampa := clampf(_interpolar(_distancia, fx, fz) / LLANURA_M, 0.0, 1.0)
	var lomas := _cota_del_ruido(_ruido.get_noise_2d(fx, fz)) * amplitud * rampa
	if _al_rio.is_empty():
		return e + lomas
	var al_rio := _interpolar(_al_rio, fx, fz)
	if al_rio >= ANCHO_DEL_VALLE_M:
		return e + lomas
	# EL VALLE: en el río, el fondo; a [ANCHO_DEL_VALLE_M], las lomas de siempre. El
	# fondo nunca por debajo del mar de la época, que la costa no se mueve.
	# Con el fondo PLANO el primer cuarto: la distancia sale de casillas de 446 m
	# interpoladas, y sin llano el propio río quedaba a doscientos metros de su fondo
	# y subía con las lomas (`TestCosta`, 2026-09-16).
	var abierto := smoothstep(ANCHO_DEL_VALLE_M * 0.25, ANCHO_DEL_VALLE_M, al_rio)
	return lerpf(minf(e, _interpolar(_fondo, fx, fz)), e + lomas, abierto)


## Lo que abre valle: la distancia de cada casilla corta al río más cercano y la cota
## del fondo de ese río.
##
## El fondo de cada punto del río es **la cota más baja que lleva recorrida desde la
## boca**, un poco hundida: así el río baja siempre, aunque la batimetría tenga un
## umbral (`RioDeLaPlataforma` los cuenta al hornear). Y nunca por debajo del mar.
func _valles(cauces: Array) -> void:
	var total := _ancho_corto * _alto_corto
	var lejos := 1.0e9
	_al_rio.resize(total)
	_al_rio.fill(lejos)
	_fondo.resize(total)
	_fondo.fill(0.0)
	var paso_m := _datos.meters_per_sample * float(PASO_DE_LA_DISTANCIA)
	for cauce: Dictionary in cauces:
		var puntos: PackedVector2Array = cauce["points"]
		var mas_bajo := INF
		for k in range(puntos.size()):
			var u := clampf(_datos.u_for_lon(puntos[k].x), 0.0, 1.0)
			var v := clampf(_datos.v_for_lat(puntos[k].y), 0.0, 1.0)
			mas_bajo = minf(mas_bajo, _datos.sample_bilinear(u, v))
			var fondo := maxf(mas_bajo - HONDO_DEL_CAUCE_M, _mar + 1.0)
			var cx := clampi(roundi(u * float(_datos.width - 1) / float(PASO_DE_LA_DISTANCIA)),
				0, _ancho_corto - 1)
			var cz := clampi(roundi(v * float(_datos.height - 1) / float(PASO_DE_LA_DISTANCIA)),
				0, _alto_corto - 1)
			var celda := cz * _ancho_corto + cx
			if _al_rio[celda] > 0.0 or fondo < _fondo[celda]:
				_al_rio[celda] = 0.0
				_fondo[celda] = fondo
	# Chanfle de ida y vuelta, llevando el fondo del río del que viene la distancia.
	for zc in range(_alto_corto):
		for xc in range(_ancho_corto):
			var i := zc * _ancho_corto + xc
			if xc > 0:
				_heredar(i, i - 1, paso_m)
			if zc > 0:
				_heredar(i, i - _ancho_corto, paso_m)
	for zc in range(_alto_corto - 1, -1, -1):
		for xc in range(_ancho_corto - 1, -1, -1):
			var i := zc * _ancho_corto + xc
			if xc < _ancho_corto - 1:
				_heredar(i, i + 1, paso_m)
			if zc < _alto_corto - 1:
				_heredar(i, i + _ancho_corto, paso_m)


func _heredar(aqui: int, de: int, paso_m: float) -> void:
	if _al_rio[de] + paso_m < _al_rio[aqui]:
		_al_rio[aqui] = _al_rio[de] + paso_m
		_fondo[aqui] = _fondo[de]


## Una casilla corta, interpolada en la posición de la rejilla fina.
func _interpolar(casillas: PackedFloat32Array, fx: float, fz: float) -> float:
	var cx := clampf(fx / float(PASO_DE_LA_DISTANCIA), 0.0, float(_ancho_corto - 1))
	var cz := clampf(fz / float(PASO_DE_LA_DISTANCIA), 0.0, float(_alto_corto - 1))
	var x0 := int(floor(cx))
	var z0 := int(floor(cz))
	var x1 := mini(x0 + 1, _ancho_corto - 1)
	var z1 := mini(z0 + 1, _alto_corto - 1)
	var tx := cx - float(x0)
	var tz := cz - float(z0)
	var a := lerpf(casillas[z0 * _ancho_corto + x0], casillas[z0 * _ancho_corto + x1], tx)
	var b := lerpf(casillas[z1 * _ancho_corto + x0], casillas[z1 * _ancho_corto + x1], tx)
	return lerpf(a, b, tz)


## El ruido de las lomas para esta rejilla. Uno solo, para [aplicar] y [cota_en].
static func _ruido_para(data: HeightmapData) -> FastNoiseLite:
	var relieve := FastNoiseLite.new()
	relieve.seed = 20260914
	relieve.noise_type = FastNoiseLite.TYPE_SIMPLEX
	relieve.fractal_type = FastNoiseLite.FRACTAL_FBM
	relieve.fractal_octaves = 4
	relieve.frequency = data.meters_per_sample / ONDA_M
	return relieve


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
