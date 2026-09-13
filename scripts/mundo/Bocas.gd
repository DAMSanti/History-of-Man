class_name Bocas
extends RefCounted
## Dónde se abre DE VERDAD cada boca de cueva: nunca en el agua ni donde no se
## llega andando desde la cueva de la banda.
##
## Frente 21 de EPOCA_01 §10.1, tanda 4. Lo pidió el usuario el 2026-09-13:
## «TODAS las cuevas de TODOS los mapas deben comprobar que no aparezcan en el
## agua o en una zona inaccesible; si lo están, se mueven al sitio más cercano
## que esté bien». Las coordenadas del catálogo son de hoy y redondeadas: el
## meandro se ha movido en veinte mil años, y una boca a veinte metros de un
## cantil cae al otro lado.
##
## **Es el único sitio que lo decide.** Antes había un `_nudge_out_of_water` en
## `DemoMain` que sólo miraba el agua, con ocho rumbos y cien metros de
## búsqueda; y nadie miraba si se llegaba. Lo llama el terreno al generarse
## —ver [TerrainGenerator.colocar_las_bocas]— porque la entalladura se excava
## en el relieve y tiene que excavarse donde queda la boca, no donde decía el
## catálogo.

## La versión de estas reglas. Entra en la clave de la caché del terreno —ver
## [MallaDelTerreno._carvings_hash]—, que si no se cargaría la malla excavada con
## las reglas de antes: pasó al medir, con las bocas de la primera versión.
## **Súbela si cambia dónde se considera buena una boca.**
const REGLAS := 4

## Metros entre un anillo de búsqueda y el siguiente, y entre dos puntos del
## mismo anillo. Diez es una decisión: menos que la entalladura de una boca
## (13 m de radio), así que el punto bueno que se salta queda dentro del hueco.
const PASO := 10.0

## Hasta dónde se busca. Todo el recuadro: la regla es «el sitio bueno más
## cercano», no «el sitio bueno si está cerca». Si ni así hay, se deja donde
## estaba y lo cuenta la sonda.
const ALCANCE := 3000.0

## Cuánto más allá del borde de la entalladura tiene que haber seco, en
## proporción a su radio. Pedir seco sólo el centro dejó la Cueva del Fósil del
## mapa 56 en la orilla, con el hueco de 9 m por debajo del agua y el río metido
## dentro: capturado el 2026-09-13 con `CuevaCaptura`. La mitad más es decisión.
const ORILLA := 1.5

## Hasta cuánto más lejos que el primer sitio bueno se busca uno con más
## pendiente, en proporción a la distancia de ese primero, con un mínimo de
## [VENTANA_MINIMA]. Decisión del usuario el 2026-09-13: «las cuevas sumergidas
## deberán moverse hacia el lado con pendiente, que es donde suelen estar las
## cuevas, no hacia el lado plano». El más cercano a secas elegía la orilla
## llana cuando estaba un anillo más cerca, y la cueva quedaba en la vega como
## un búnker. Las cifras de la ventana son decisión, no medida.
const VENTANA := 1.0
const VENTANA_MINIMA := 40.0

## A qué distancia se mide la pendiente: la misma que usa [CaveMouth.build] para
## orientar la boca, por la misma razón —a escala de vértice manda el ruido—.
const CATA_DE_PENDIENTE := 22.0


## Coloca las entalladuras pedidas. Devuelve copias con `position` ya válida,
## `desde` (lo que pedía el catálogo) y `movida_m`.
##
## Con la MISMA pregunta de tránsito que la marcha —[Navgrid], con la puerta de
## casa abierta como la abre [Marcha._navgrid]— y al caudal de siempre: la zona
## de una estación crecida no es la zona a la que se llega, es la de ese
## invierno.
static func colocar(terrain: TerrainGenerator, pedidas: Array[Dictionary],
		casa: Vector3) -> Array[Dictionary]:
	var colocadas: Array[Dictionary] = []
	if pedidas.is_empty():
		return colocadas
	var grid := Navgrid.from_terrain(terrain, false, [])
	grid.open_around_home(casa, terrain)
	for pedida: Dictionary in pedidas:
		var boca := pedida.duplicate()
		var desde: Vector3 = pedida.get("position", Vector3.ZERO)
		var radio := float(pedida.get("radius", 0.0)) * ORILLA
		var queda := punto_bueno(terrain, grid, desde, casa, radio)
		boca["position"] = queda
		boca["desde"] = desde
		boca["movida_m"] = Vector2(queda.x - desde.x, queda.z - desde.z).length()
		colocadas.append(boca)
	return colocadas


## Si una boca puede estar aquí: dentro del recuadro, en seco —el centro y un
## corro de `radio` alrededor, que es lo que se excava— y unida a casa.
##
## **No pide que su celda se ande**, y es a propósito. Una cueva se abre en la
## ladera, y la celda de cuarenta metros de una ladera sale cerrada por
## pendiente: pedirlo movió 8 de las 9 bocas del mapa 56 —medido el 2026-09-13
## con `CuevasProbe`—, sacándolas de la pared a la campa. «Se llega» es lo que
## pregunta la marcha: [Navgrid.connected] va a la celda abierta más cercana,
## igual que [Marcha.alcanzable_desde_casa].
static func vale(terrain: TerrainGenerator, grid: Navgrid, punto: Vector3,
		casa: Vector3, radio: float = 0.0) -> bool:
	var fuera := punto.x < 0.0 or punto.z < 0.0
	fuera = fuera or punto.x > float(terrain.terrain_size.x)
	fuera = fuera or punto.z > float(terrain.terrain_size.y)
	if fuera:
		return false
	if terrain.crossing_difficulty_at(punto) > 0.0:
		return false
	if radio > 0.0:
		for i in range(12):
			var angulo := float(i) / 12.0 * TAU
			if terrain.crossing_difficulty_at(punto + Vector3(cos(angulo) * radio,
					0.0, sin(angulo) * radio)) > 0.0:
				return false
	return grid.connected(casa, punto)


## Si el pedido ya vale, él. Si no, de los puntos buenos entre el más cercano y
## [VENTANA] más allá, el de más pendiente: una cueva se abre en la ladera, no
## en el llano. A igual pendiente, el más cercano.
static func punto_bueno(terrain: TerrainGenerator, grid: Navgrid, punto: Vector3,
		casa: Vector3, radio: float = 0.0) -> Vector3:
	if vale(terrain, grid, punto, casa, radio):
		return punto
	var mejor := punto
	var mejor_pendiente := -1.0
	var hasta := ALCANCE
	var anillo := PASO
	while anillo <= hasta:
		var rumbos := maxi(8, int(ceil(TAU * anillo / PASO)))
		for i in range(rumbos):
			var angulo := float(i) / float(rumbos) * TAU
			var candidato := punto + Vector3(cos(angulo) * anillo, 0.0,
				sin(angulo) * anillo)
			if not vale(terrain, grid, candidato, casa, radio):
				continue
			if mejor_pendiente < 0.0:
				hasta = minf(ALCANCE, anillo + maxf(VENTANA_MINIMA, anillo * VENTANA))
			var cuesta := pendiente(terrain, candidato)
			if cuesta > mejor_pendiente:
				mejor_pendiente = cuesta
				mejor = candidato
		anillo += PASO
	return mejor


## Cuánto cae el terreno alrededor de un punto, en metros por metro.
static func pendiente(terrain: TerrainGenerator, punto: Vector3) -> float:
	var d := CATA_DE_PENDIENTE
	var este := terrain.get_height_at(punto + Vector3(d, 0.0, 0.0))
	var oeste := terrain.get_height_at(punto - Vector3(d, 0.0, 0.0))
	var sur := terrain.get_height_at(punto + Vector3(0.0, 0.0, d))
	var norte := terrain.get_height_at(punto - Vector3(0.0, 0.0, d))
	return Vector2(este - oeste, sur - norte).length() / (2.0 * d)
