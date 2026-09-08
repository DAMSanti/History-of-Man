class_name HornoDeRejillas
extends RefCounted
## Una rejilla de caminos por estación, horneadas sin que se note.
##
## ## Por qué hacen falta cuatro
##
## Un río crecido no se vadea, y eso cierra pasos. Pero [Navgrid] se horneaba
## UNA vez y en seco, así que planeaba rutas por vados que en enero ya no
## existían y la cuadrilla salía a estrellarse contra el agua. Medido con
## `BandaProbe`: con la crecida cerrando vados sobre una sola rejilla, la pesca
## del año pasó de 639 raciones a 31 y la caza de 222 a 16. No es que el
## invierno fuera duro: es que la banda no sabía por dónde se pasa en invierno.
##
## Con una rejilla por estación el vado SÍ se cierra —que es lo que se quiere—
## y los caminos de esa estación lo saben.
##
## ## Por qué a trozos
##
## Una rejilla cuesta **891 ms medidos** (103 × 103 celdas, nueve sondeos cada
## una). Las cuatro de golpe al arrancar serían tres segundos y medio de tirón
## sobre una carga que ya es larga; hacerlas al cambiar de estación sería un
## parpadeo a mitad de partida, que es peor.
##
## Así que: la de HOY se hornea entera al arrancar —hace falta ya, no hay
## partida sin ella— y las otras tres se amasan a rodajas mientras se juega,
## unos milisegundos por fotograma. Para cuando cambia la estación llevan un
## trimestre hechas.
##
## ## Y cuando aparece la barca
##
## Barca y puente cambian por dónde se pasa, así que invalidan las cuatro. Se
## tiran y se vuelve a empezar por la de hoy, igual que al arrancar.

## Cuánto se amasa por fotograma, en milisegundos.
##
## Cuatro. Es el presupuesto de un fotograma de sobra —a sesenta por segundo
## hay 16,7— y con él las tres rejillas que faltan salen en unos veinte
## segundos de juego. Subirlo acaba antes y se nota; bajarlo no se nota y tarda.
const MS_POR_CUADRO := 4

## Cuántas filas se miden antes de volver a mirar el reloj.
##
## Mirar el reloj cuesta, así que no se mira cada celda. Dos filas son unas
## doscientas celdas, que a 0,085 ms cada una son diecisiete milisegundos... y
## por eso son DOS y no veinte: el trozo tiene que caber en el presupuesto.
const FILAS_POR_VUELTA := 1

var _terrain: TerrainGenerator = null
var _boat := false
var _bridge := false

## Estación -> rejilla. Las que están a medias también viven aquí.
var _rejillas: Dictionary = {}

## Lo que queda por amasar, por orden. La de hoy no entra: esa va entera.
var _cola: Array[int] = []


## Tira todo y vuelve a empezar. Se llama al montar y cuando aparece la barca.
##
## `caudales` es estación -> caudal, o sea [Temporada.CAUDAL].
func encargar(terrain: TerrainGenerator, has_boat: bool, has_bridge: bool,
		hoy: Subsistence.Season, caudales: Dictionary) -> void:
	_terrain = terrain
	_boat = has_boat
	_bridge = has_bridge
	_rejillas.clear()
	_cola.clear()
	if terrain == null:
		return

	# La de hoy, entera y ahora: sin ella no hay partida.
	_rejillas[int(hoy)] = Navgrid.from_terrain(terrain, has_boat, has_bridge,
		float(caudales.get(hoy, 1.0)))

	# Las otras tres, preparadas y a la cola. Por orden de LLEGADA -la que
	# viene después de hoy primero-, que es el orden en que van a hacer falta.
	for paso in range(1, 4):
		var season := ((int(hoy) + paso) % 4)
		_rejillas[season] = Navgrid.preparar(terrain, has_boat, has_bridge,
			float(caudales.get(season, 1.0)))
		_cola.append(season)


## Amasa un poco. Se llama una vez por fotograma; devuelve si quedan por hacer.
func amasar() -> bool:
	if _cola.is_empty() or _terrain == null:
		return false
	var hasta := Time.get_ticks_msec() + MS_POR_CUADRO
	while not _cola.is_empty():
		var season: int = _cola[0]
		var grid: Navgrid = _rejillas[season]
		if grid.amasar(_terrain, FILAS_POR_VUELTA):
			_cola.pop_front()
		if Time.get_ticks_msec() >= hasta:
			break
	return not _cola.is_empty()


## La rejilla de una estación, o la que haya si todavía no está.
##
## NUNCA devuelve una a medias: una rejilla sin inundar dice que no hay camino
## a ninguna parte, y con eso la banda se queda en el abrigo. Mientras la del
## invierno se hornea se sigue andando con la del otoño, que es lo peor que
## puede pasar —caminos de hace un trimestre— y no es grave.
func de(season: Subsistence.Season) -> Navgrid:
	var pedida: Navgrid = _rejillas.get(int(season))
	if pedida != null and pedida.horneada():
		return pedida
	for otra: int in _rejillas:
		var grid: Navgrid = _rejillas[otra]
		if grid != null and grid.horneada():
			return grid
	return pedida


## Si las que hay valen para este utillaje. Barca y puente cambian por dónde se
## pasa, así que invalidan las cuatro de golpe.
func sirven(has_boat: bool, has_bridge: bool) -> bool:
	return not _rejillas.is_empty() and _boat == has_boat \
		and _bridge == has_bridge


## Cuántas quedan por hornear, para la barra de rendimiento y las sondas.
func pendientes() -> int:
	return _cola.size()


## En qué punto va la que se está amasando, de 0 a 1.
func avance() -> float:
	if _cola.is_empty():
		return 1.0
	var grid: Navgrid = _rejillas[_cola[0]]
	if grid == null or grid.tall <= 0:
		return 0.0
	return clampf(float(grid._fila) / float(grid.tall), 0.0, 1.0)
