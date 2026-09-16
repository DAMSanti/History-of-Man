class_name AguaDelCauce
extends RefCounted
## Dónde rompe el agua del cauce: los rápidos y la orilla. GRAFICOS §7.3.
##
## **Se calcula aquí, en la CPU, y se hornea en la malla del terreno**, y el shader sólo
## lo lee (`MallaDelTerreno`, en el UV del vértice, que el shader no usaba: texturiza por
## posición de mundo). Antes el rápido lo calculaba el shader con la normal del terreno
## proyectada sobre la corriente, y dos cosas lo pedían fuera: la suite no ejecuta
## shaders, así que «la espuma sale en el escalón y no en el llano» no se podía probar; y
## la normal no distingue un escalón del cauce de la **ladera de la margen**, que en un
## cauce encajado siempre es empinada —en captura la espuma salía en vetas dentadas
## pegadas a la orilla y no en los rápidos (`AguaCaptura`, 2026-09-15)—.
##
## Funciones puras sobre los mapas del terreno. **No toca la partida**: lo que lee la
## banda —alturas, lámina, corriente, vados— no pasa por aquí.

## La caída del cauce aguas abajo, en metros por metro, a partir de la cual el agua
## empieza a romper, y cuántas veces esa caída hacen falta para que rompa entera.
## Decisiones mirando capturas, no medidas. **Eran 0,06 y ×4**, la cifra del shader
## (`foam_fall`): medida ya entre celdas de cauce, el torrente del sitio 56 salía blanco
## de punta a punta (`AguaCaptura`, 2026-09-15).
##
## **En la malla va la caída en bruto** ([caida]) y estos umbrales van al shader como
## uniformes (`TerrainMaterialManager`): así se afinan sin rehacer la caché del terreno.
const CAIDA_DE_RAPIDO := 0.08
const VECES_PARA_ROMPER_ENTERA := 5.0

## La caída que se hornea, recortada: por encima de esto todo es rápido.
const CAIDA_MAXIMA := 1.0

## LA LÍNEA DEL AGUA: desde qué lámina una celda es agua y no ribera mojada. La máscara
## del río se difumina hacia la tierra —`Hydrography.BANK_BLEND_CELLS`, para que la hierba
## no corte a cuchillo— y el relieve sólo se allana a la cota del agua a partir de ~0,55
## (`TerrainGenerator._generate_maps`): lo de debajo es tierra. **Todo lo que pinta agua
## lee esta cifra**: la espuma de orilla, el color del agua del terreno, la lámina y el
## lecho hundido. Pintando desde 0,02, la orilla se metía varios metros en tierra (queja
## del usuario del 2026-09-15). La caída se mide también sólo entre celdas de agua.
const LINEA_DEL_AGUA := 0.5
const LAMINA_DE_CAUCE := LINEA_DEL_AGUA

## Cuánto se hunde el lecho bajo la lámina, en metros, donde el cauce es entero: SÓLO
## AL DIBUJAR, en el vértice del terreno, desde Alto. El relieve LiDAR es la superficie
## del agua, no el fondo, y sin hundirlo la lámina transparente no tendría nada que
## enseñar debajo. Decisión mirando capturas; los mapas no se tocan.
const LECHO_M := 0.8

## Desde qué lámina entra una esquina en la malla de la lámina: un poco por fuera de la
## línea del agua, para que el triángulo del borde la cruce y el shader la funda ahí.
const LAMINA_QUE_SE_DIBUJA := 0.4

## Cuántas celdas se mira aguas abajo para medir la caída. Dos, porque la lámina del
## relieve se asienta por tramos (`Hydrography._settle_water_surface`) y una celda sola
## da escalones de centímetros que no son rápidos.
const CELDAS_AGUAS_ABAJO := 2


## Cuánto rompe el agua en esta celda, de 0 a 1, con los umbrales de arriba. Es lo que
## pinta el shader con la caída horneada —la suave—.
static func rapido(altura: PackedFloat32Array, lamina: PackedFloat32Array,
		flujo: PackedVector2Array, res: int, gx: int, gz: int, paso: float) -> float:
	return smoothstep(CAIDA_DE_RAPIDO, CAIDA_DE_RAPIDO * VECES_PARA_ROMPER_ENTERA,
		caida_suave(altura, lamina, flujo, res, gx, gz, paso))


## La caída de esta celda promediada con la de sus vecinas de agua: la mitad la suya y la
## mitad la media de las ocho de alrededor. Es la que se hornea en la malla.
##
## **Sin suavizar, la espuma salía en triángulos de bordes rectos** (captura de cerca,
## 2026-09-15): la caída salta de un vértice al de al lado, la tarjeta la interpola dentro
## de cada triángulo y el umbral de la espuma corta por las aristas de la malla.
static func caida_suave(altura: PackedFloat32Array, lamina: PackedFloat32Array,
		flujo: PackedVector2Array, res: int, gx: int, gz: int, paso: float) -> float:
	var propia := caida(altura, lamina, flujo, res, gx, gz, paso)
	if gz * res + gx >= lamina.size() or lamina[gz * res + gx] < LINEA_DEL_AGUA:
		return propia
	var suma := 0.0
	var cuantas := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var x := gx + dx
			var z := gz + dz
			if (dx == 0 and dz == 0) or x < 0 or z < 0 or x >= res or z >= res:
				continue
			if lamina[z * res + x] < LINEA_DEL_AGUA:
				continue
			suma += caida(altura, lamina, flujo, res, x, z, paso)
			cuantas += 1
	if cuantas == 0:
		return propia
	return propia * 0.5 + (suma / float(cuantas)) * 0.5


## La caída del cauce aguas abajo en esta celda, en metros por metro, de 0 a
## [CAIDA_MAXIMA]. Cero fuera del cauce, en agua quieta y donde aguas abajo ya no hay
## cauce: medida contra la margen, la ladera se leería como rápido.
static func caida(altura: PackedFloat32Array, lamina: PackedFloat32Array,
		flujo: PackedVector2Array, res: int, gx: int, gz: int, paso: float) -> float:
	var i := gz * res + gx
	if i >= lamina.size() or lamina[i] < LAMINA_DE_CAUCE or i >= flujo.size():
		return 0.0
	var f := flujo[i]
	if f.length_squared() < 0.01:
		return 0.0
	var d := f.normalized()
	for celdas in range(CELDAS_AGUAS_ABAJO, 0, -1):
		var nx := gx + roundi(d.x * float(celdas))
		var nz := gz + roundi(d.y * float(celdas))
		if nx < 0 or nz < 0 or nx >= res or nz >= res:
			continue
		var j := nz * res + nx
		if j == i or lamina[j] < LAMINA_DE_CAUCE:
			continue
		var baja := (altura[i] - altura[j]) / (Vector2(nx - gx, nz - gz).length() * paso)
		return clampf(baja, 0.0, CAIDA_MAXIMA)
	return 0.0


## Desde cuánto rápido puede haber piedra, y cuántas celdas de cada cien del rápido
## más fuerte llevan una. Decisiones mirando la foto del Pas (CREDITOS): agua clara entre
## piedras, no un pedregal.
const RAPIDO_CON_PIEDRAS := 0.3
const PIEDRAS_POR_CIEN := 22.0


## Si en esta celda asoma una piedra, y cómo de fuerte rompe el agua en ella: 0 si no
## hay. Sólo en rápidos, más cuanto más rompe, y siempre en las mismas celdas —el azar
## sale de la celda, no del reloj—. Vuelta del 2026-09-15: el rápido era una tira blanca
## y en el Pas la espuma sale detrás de las piedras. Ver [PiedrasDelRio].
static func piedra(altura: PackedFloat32Array, lamina: PackedFloat32Array,
		flujo: PackedVector2Array, res: int, gx: int, gz: int, paso: float) -> float:
	var fuerza := rapido(altura, lamina, flujo, res, gx, gz, paso)
	if fuerza < RAPIDO_CON_PIEDRAS:
		return 0.0
	var azar := fposmod(sin(float(gx) * 127.1 + float(gz) * 311.7) * 43758.5453, 1.0)
	return fuerza if azar < fuerza * PIEDRAS_POR_CIEN / 100.0 else 0.0


## La corriente de esta celda PARA DIBUJAR: la media de la de las celdas de agua en dos
## celdas a la redonda, con su dirección y la fuerza de la media. La que usa la partida
## —`TerrainGenerator._flow_map`— no se toca.
##
## **Sin suavizar, la espuma salía en astillas triangulares** (2026-09-15, vista de
## términos de `AguaCaptura`): la corriente de OSM cambia de un vértice al de al lado, la
## tarjeta la interpola en línea recta dentro de cada triángulo, y el ruido de la espuma,
## desplazado varios metros por ella, se estiraba distinto a cada lado de cada arista.
static func corriente_suave(flujo: PackedVector2Array, lamina: PackedFloat32Array,
		res: int, gx: int, gz: int) -> Vector2:
	var i := gz * res + gx
	if i >= flujo.size():
		return Vector2.ZERO
	var suma := Vector2.ZERO
	var cuantas := 0
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var x := gx + dx
			var z := gz + dz
			if x < 0 or z < 0 or x >= res or z >= res:
				continue
			var j := z * res + x
			if j >= lamina.size() or lamina[j] < LINEA_DEL_AGUA:
				continue
			suma += flujo[j]
			cuantas += 1
	if cuantas == 0:
		return flujo[i]
	return suma / float(cuantas)


## Cuánto puede subir la lámina por encima del agua de al lado, en metros. Decisión
## mirando las capturas: lo que sube una ribera tendida, y nada de una pared.
const LAMINA_SUBE_M := 0.25

## A qué cota va la LÁMINA en este vértice: el relieve, pero en un vértice de tierra nunca
## más de `tope` —en unidades del relieve, ver [LAMINA_SUBE_M]— por encima de la media de
## las celdas de agua que lo tocan.
##
## **Que el talud la corte.** La lámina se ponía en el relieve de cada vértice, y en una
## margen empinada el vértice de tierra está metros más alto: el triángulo subía por el
## talud y la línea del agua salía en dientes de sierra con una mancha de espuma en cada
## punta (capturas de Alto y Ultra, 2026-09-15). Topada, se mete bajo el talud y la corta
## la profundidad donde el relieve la cruza.
##
## **Y no del todo plana.** Plana a la cota del agua, en la ribera tendida tocaba el lecho
## —hundido por vértice al dibujar— en escalones de una celda. Con el tope, ahí sigue al
## relieve como antes y el borde lo pone la línea suave de la humedad.
static func cota_del_agua(alturas: PackedFloat32Array, lamina: PackedFloat32Array,
		res: int, gx: int, gz: int, tope: float) -> float:
	var i := gz * res + gx
	if i >= alturas.size():
		return 0.0
	if i < lamina.size() and lamina[i] >= LINEA_DEL_AGUA:
		return alturas[i]
	var suma := 0.0
	var cuantas := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var x := gx + dx
			var z := gz + dz
			if x < 0 or z < 0 or x >= res or z >= res:
				continue
			var j := z * res + x
			if j < lamina.size() and lamina[j] >= LINEA_DEL_AGUA:
				suma += alturas[j]
				cuantas += 1
	if cuantas == 0:
		return alturas[i]
	return minf(alturas[i], suma / float(cuantas) + tope)


## Cuánta espuma de orilla hay en esta celda, de 0 a 1: celdas de AGUA que tocan una
## que ya no lo es. Por dentro de la línea del agua, nunca en la ribera mojada. Cero en
## medio del cauce y en tierra.
static func orilla(lamina: PackedFloat32Array, res: int, gx: int, gz: int) -> float:
	var i := gz * res + gx
	if i >= lamina.size() or lamina[i] < LINEA_DEL_AGUA:
		return 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var x := gx + dx
			var z := gz + dz
			if x >= 0 and z >= 0 and x < res and z < res and lamina[z * res + x] < LINEA_DEL_AGUA:
				return 1.0
	return 0.0
