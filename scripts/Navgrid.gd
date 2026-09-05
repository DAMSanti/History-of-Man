class_name Navgrid
extends RefCounted
## Lo que cuesta andar por cada trozo de la comarca, calculado UNA vez.
##
## Antes esto se preguntaba al terreno en mitad de la búsqueda: cada celda que
## miraba el A* eran cinco muestras de altura, cinco de pendiente y cinco de
## vadeo, y cada búsqueda mira cientos de celdas. Multiplicado por quince
## personas que piden camino varias veces al día, el juego se pasaba el rato
## remuestreando un terreno que **no cambia**.
##
## Aquí se muestrea entero al empezar la partida y se guarda en dos arrays.
## Después, buscar un camino es leer números de una lista: el A* deja de tocar
## el terreno.
##
## Y de paso sale gratis lo que antes era lo más caro de todo. Al construirla
## se marcan las ZONAS —los trozos de mapa comunicados entre sí— con un relleno
## por inundación. Saber si se puede llegar de un sitio a otro deja de ser una
## búsqueda exhaustiva de doce mil nodos y pasa a ser comparar dos enteros.

## Metros por celda. La misma que usaba el A*: fina para ver un barranco de
## treinta metros, gruesa para que la comarca entera quepa en diez mil celdas.
const CELL := 40.0

## Los puntos que se miran dentro de cada celda: el centro y cuatro alrededor.
##
## Con una sola muestra en el centro, un río que pasa entre dos centros es
## invisible y la gente sale a cruzarlo; y un barranco más estrecho que la
## celda no existe, que es por lo que tiraban por él.
const PROBES: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(-0.34, -0.34), Vector2(0.34, -0.34),
	Vector2(-0.34, 0.34), Vector2(0.34, 0.34),
]

## Cuánto pesa el riesgo frente a la distancia.
const RISK_WEIGHT := 5.0

## Cuánto pesa mojarse, sobre la dificultad de vadeo.
const WATER_WEIGHT := 2.5

## Cuánto tira el peor paso de la celda frente al promedio.
const WORST_BIAS := 0.6

## Lo que vale una celda por la que no se pasa.
const BLOCKED := -1.0


var wide: int = 0
var tall: int = 0
var world: Vector2 = Vector2.ZERO

## Coste por celda, como multiplicador de la distancia. `BLOCKED` si no se pasa.
var cost: PackedFloat32Array = PackedFloat32Array()

## A qué zona comunicada pertenece cada celda. -1 si no se pasa.
##
## Dos puntos con la misma zona tienen camino entre ellos, seguro. Con zonas
## distintas, seguro que no. Es la respuesta que antes costaba una búsqueda
## entera y ahora es una comparación.
var area: PackedInt32Array = PackedInt32Array()

## Cuántas zonas comunicadas hay, para poder contarlo en la sonda.
var areas: int = 0

## Con qué se contaba al construirla. Barca y puente cambian lo que se pasa,
## así que hay que rehacerla cuando aparecen.
var built_with_boat: bool = false
var built_with_bridge: bool = false


## Construye la rejilla a partir del terreno. Es lo caro, y pasa una vez.
static func from_terrain(terrain: TerrainGenerator,
		has_boat: bool, has_bridge: bool) -> Navgrid:
	var grid := Navgrid.new()
	grid.built_with_boat = has_boat
	grid.built_with_bridge = has_bridge
	if terrain == null:
		return grid

	grid.world = Vector2(float(terrain.terrain_size.x), float(terrain.terrain_size.y))
	grid.wide = int(grid.world.x / CELL) + 1
	grid.tall = int(grid.world.y / CELL) + 1
	grid.cost.resize(grid.wide * grid.tall)
	grid.area.resize(grid.wide * grid.tall)

	for z in range(grid.tall):
		for x in range(grid.wide):
			var centre := Vector3(
				(float(x) + 0.5) * CELL, 0.0, (float(z) + 0.5) * CELL)
			grid.cost[z * grid.wide + x] = _measure(
				terrain, centre, has_boat, has_bridge)

	grid._flood_areas()
	return grid


## Cuánto alrededor del abrigo se garantiza andable, en metros.
##
## Ciento veinte: el patio de la cueva. Lo justo para salir, dar la vuelta y
## coger cualquiera de los caminos, y no tanto como para regalar un vado.
const HOME_APRON := 120.0


## Abre a la fuerza el entorno del abrigo.
##
## Un abrigo se elige por ser habitable, así que su puerta se anda: si la
## medición dice lo contrario, la equivocada es la medición. Y las
## consecuencias de no hacerlo son enormes y silenciosas —la banda entera
## queda en una celda que no existe y no se le puede trazar nada—, así que
## vale la pena forzarlo aunque sea inventar un metro de suelo.
##
## Las celdas forzadas quedan CARAS, no baratas: se pasa porque hay que pasar,
## no porque sea buen camino, y así el trazado sigue prefiriendo rodear.
func open_around_home(home: Vector3, terrain: TerrainGenerator) -> int:
	if not is_ready():
		return 0

	var opened := 0
	var reach := int(HOME_APRON / CELL) + 1
	var centre := cell_of(home)
	var cx := centre % wide
	var cz := centre / wide

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= wide or z >= tall:
				continue
			var cell := z * wide + x
			if cost[cell] > BLOCKED:
				continue
			var point := point_of(cell)
			if point.distance_to(Vector3(home.x, point.y, home.z)) > HOME_APRON:
				continue

			# Caro pero transitable: la salida de casa no es una autopista
			cost[cell] = FORCED_COST
			opened += 1

	if opened > 0:
		_flood_areas()
	return opened


## Lo que cuesta una celda abierta a la fuerza. Alto a propósito.
const FORCED_COST := 9.0


## Lo que cuesta pisar una celda, mirándola en cinco puntos.
##
## Si CUALQUIERA de los cinco no se pasa, la celda no se pasa: por una celda
## que tiene un tramo de río dentro no se anda, aunque su centro esté seco.
##
## Es deliberadamente severo, y tiene que serlo: el andador comprueba el
## terreno punto a punto, así que una celda que el planificador diera por
## buena mirando sólo su centro sería una celda que la persona no puede
## cruzar. Se probó a aflojarlo y el resultado, medido, fue gente parada
## contra una pared durante horas.
static func _measure(terrain: TerrainGenerator, centre: Vector3,
		has_boat: bool, has_bridge: bool) -> float:
	var total := 0.0
	var worst := 0.0

	for probe: Vector2 in PROBES:
		var point := Vector3(
			centre.x + probe.x * CELL, 0.0, centre.z + probe.y * CELL)
		point.y = terrain.get_height_at(point)

		var slope := terrain.get_slope_at(point)
		var ford := terrain.crossing_difficulty_at(point)

		# Cualquiera de los cinco puntos que no se pase cierra la celda, y va
		# para el agua Y para la pendiente.
		#
		# Se probó a aflojarlo para la pendiente —que una peña suelta no
		# cerrara los cuarenta metros— y salió peor, con el juego delante:
		# 385 minutos de gente parada contra una pared. El motivo es que el
		# ANDADOR comprueba punto a punto, así que una celda que el
		# planificador da por buena porque su centro se pisa es una celda que
		# la persona no puede cruzar. El planificador que promete más de lo
		# que el andador cumple no es optimista: deja a la gente clavada.
		if not Traversal.is_passable(slope, ford, has_boat, has_bridge):
			return BLOCKED

		# Lo que cuesta andarlo: la función de marcha ya sabe que subir cansa
		# y que bajar mucho también. El suelo de velocidad va dentro de
		# `hiking_speed` -lo comparte con el andador real, ver su comentario.
		var pace := Traversal.hiking_speed(slope)
		var step := 1.0 / pace

		# Y lo que arriesga. Es la misma clasificación que usan los percances,
		# así que el camino evita justo donde la gente se hace daño.
		var risk := 0.0
		match Traversal.classify_ground(slope, ford):
			Traversal.Ground.CANCHAL: risk = 1.0
			Traversal.Ground.ROCA: risk = 0.6
			Traversal.Ground.MARISMA: risk = 0.5
			Traversal.Ground.ARENA: risk = 0.15
			_: risk = 0.0
		risk *= 1.0 + slope * 1.5
		risk += ford * WATER_WEIGHT

		var value := step * (1.0 + risk * RISK_WEIGHT)
		total += value
		worst = maxf(worst, value)

	return lerpf(total / float(PROBES.size()), worst, WORST_BIAS)


## Marca las zonas comunicadas con un relleno por inundación.
##
## Se hace con una pila y no con recursión porque una comarca de diez mil
## celdas desborda cualquier pila de llamadas.
func _flood_areas() -> void:
	for i in range(area.size()):
		area[i] = -1

	var next := 0
	var stack := PackedInt32Array()
	for start in range(cost.size()):
		if cost[start] <= BLOCKED or area[start] != -1:
			continue

		area[start] = next
		stack.append(start)
		while not stack.is_empty():
			var cell := stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			for neighbour: int in neighbours(cell):
				if cost[neighbour] <= BLOCKED or area[neighbour] != -1:
					continue
				area[neighbour] = next
				stack.append(neighbour)
		next += 1

	areas = next


func is_ready() -> bool:
	return wide > 0 and tall > 0


## Si esta rejilla sirve todavía, o hay que rehacerla porque la banda ya sabe
## cruzar el agua.
func matches(has_boat: bool, has_bridge: bool) -> bool:
	return built_with_boat == has_boat and built_with_bridge == has_bridge


func cell_of(point: Vector3) -> int:
	var x := clampi(int(point.x / CELL), 0, wide - 1)
	var z := clampi(int(point.z / CELL), 0, tall - 1)
	return z * wide + x


func point_of(cell: int) -> Vector3:
	return Vector3(
		minf(float(cell % wide) * CELL + CELL * 0.5, world.x), 0.0,
		minf(float(cell / wide) * CELL + CELL * 0.5, world.y))


func cost_of(cell: int) -> float:
	return cost[cell]


func passable(point: Vector3) -> bool:
	if not is_ready():
		return true
	return cost[cell_of(point)] > BLOCKED


## Si hay camino de un punto a otro, sin buscarlo.
##
## Ésta es la que se llevaba el fotograma. Para decir que NO se llega hacía
## falta agotar la búsqueda —doce mil nodos— y eso pasaba cada vez que alguien
## apuntaba al otro lado de un río. Ahora son dos enteros.
##
## Los dos extremos se AMARRAN a la celda transitable más próxima antes de
## comparar, y no es un detalle de borde: es lo que dejaba a la banda entera
## encerrada. La celda mide cuarenta metros y basta con que la roce el río para
## que quede cerrada; los abrigos están junto al agua, porque para eso se
## eligen. Con el campamento en una celda cerrada, su zona era «ninguna», y
## «ninguna» no coincide con nada: a nadie se le podía trazar un camino a
## ninguna parte y la gente se quedaba a veinte metros de casa dando vueltas.
func connected(from_point: Vector3, to_point: Vector3) -> bool:
	if not is_ready():
		return true

	var from_cell := nearest_open(from_point)
	var to_cell := nearest_open(to_point)
	if from_cell < 0 or to_cell < 0:
		return false
	return area[from_cell] >= 0 and area[from_cell] == area[to_cell]


## La celda transitable más cercana a un punto, o -1 si no hay ninguna cerca.
##
## Hace falta porque el jugador señala donde le parece, y donde le parece
## puede ser el cauce. Rendirse ahí sería tratar un clic aproximado como una
## orden imposible.
func nearest_open(point: Vector3, rings: int = 3) -> int:
	if not is_ready():
		return -1
	var start := cell_of(point)
	if cost[start] > BLOCKED:
		return start

	var cx := start % wide
	var cz := start / wide
	for ring in range(1, rings + 1):
		var best := -1
		var best_cost := INF
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dz)) != ring:
					continue
				var x := cx + dx
				var z := cz + dz
				if x < 0 or z < 0 or x >= wide or z >= tall:
					continue
				var cell := z * wide + x
				if cost[cell] > BLOCKED and cost[cell] < best_cost:
					best_cost = cost[cell]
					best = cell
		if best >= 0:
			return best
	return -1


func neighbours(cell: int) -> Array[int]:
	var out: Array[int] = []
	var x := cell % wide
	var z := cell / wide
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dz == 0:
				continue
			var nx := x + dx
			var nz := z + dz
			if nx < 0 or nz < 0 or nx >= wide or nz >= tall:
				continue
			out.append(nz * wide + nx)
	return out


## Cuánta comarca se puede andar, para poder contarlo.
func open_fraction() -> float:
	if cost.is_empty():
		return 0.0
	var open := 0
	for value: float in cost:
		if value > BLOCKED:
			open += 1
	return float(open) / float(cost.size())
