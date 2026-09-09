class_name Wayfinder
extends RefCounted
## Traza el camino que de verdad seguiría alguien de la banda.
##
## Hasta ahora la gente iba en línea recta y sólo esquivaba lo que le cortaba
## el paso del todo. Eso hace que crucen un canchal al 70% porque queda de
## camino, y un canchal al 70% es exactamente donde uno se rompe un tobillo.
##
## Nadie anda así. Se rodea. Se sube por la vaguada y no por la peña, aunque
## se tarde más, porque el rato de más lo pagas hoy y la pierna la pagas un
## mes. Aquí eso se hace con un A* cuyo coste no es la distancia sino **la
## distancia por lo que cuesta y por lo que arriesga**.
##
## Lo que cuesta cada trozo de comarca NO se calcula aquí: viene hecho en la
## [Navgrid], medido una sola vez al empezar la partida. Este fichero sólo
## busca.

## Nodos que se miran como mucho antes de rendirse.
##
## Ahora que cada nodo es leer un número de una lista —y no quince muestras
## del terreno— el tope se puede tener alto sin que se note.
## Cuarenta mil, y no doce mil.
##
## Doce mil bastaban mientras medio valle estaba incomunicado: los caminos
## largos ni se intentaban. Al abrir los vados —ver `Navgrid._has_ford`— la
## banda pasa a cruzar el río y a ir de punta a punta de la comarca, y una
## búsqueda así puede sacar y volver a meter la misma celda varias veces, así
## que el tope de doce mil se agotaba ANTES de llegar. El síntoma era «se quedó
## sin camino trazado» sobre un sitio perfectamente alcanzable: 26 en tres
## jornadas, medido en el sitio 56.
const MAX_NODES := 40000

## Cuánto se empuja la heurística por encima del mínimo teórico.
##
## Es lo que separa un A* de una inundación. Ceñida al mínimo -el paso de un
## llano de vacío- la búsqueda se abre en todas direcciones: medido en el sitio
## 56, 7,5 ms de media para una búsqueda de jornada. Con cuatro baja a la mitad
## larga. A cambio el camino deja de ser EL óptimo y pasa a ser uno bueno, que
## en un valle son metros de diferencia, no otro rumbo.
const HEURISTIC_PUSH := 4.0

## Nodos que costó la última búsqueda.
##
## Lo mira quien reparte trabajo por fotograma: una búsqueda que encuentra el
## camino enseguida cuesta cincuenta nodos, y una que fracasa se recorre la
## comarca entera antes de rendirse. Contar «búsquedas» trataba a las dos
## igual, y por eso un solo destino imposible se comía el fotograma.
static var last_nodes: int = 0


## El camino de un punto a otro, como lista de puntos del mundo.
##
## Vacío significa QUE NO HAY CAMINO, y quien llame tiene que hacer algo con
## eso. Devolver la recta al fallar era lo que mandaba a la gente a cruzar un
## río que no se cruza: «no hay por dónde» se traducía en «tira derecho».
static func find(grid: Navgrid, from_point: Vector3,
		to_point: Vector3) -> PackedVector3Array:
	last_nodes = 0
	var straight := PackedVector3Array([to_point])
	if grid == null or not grid.is_ready():
		return straight

	# El destino se amarra a suelo pisable ANTES del atajo de «esta al lado, ve
	# derecho», y ahi estaba el fallo que llenaba la cronica: los abrigos se
	# eligen junto al agua, asi que a diez metros de la puerta hay cauce. Se
	# mandaba a la gente derecha a un punto que no se pisa, el andador no podia
	# dar el paso, y quedaban once atascos «a 11 m del abrigo».
	if grid.cost[grid.cell_of(to_point)] <= Navgrid.BLOCKED:
		var dry := grid.nearest_open(to_point)
		if dry < 0:
			return PackedVector3Array()
		to_point = grid.point_of(dry)
		straight = PackedVector3Array([to_point])

	# El atajo de «está al lado, ve derecho» SÓLO si la línea recta está limpia.
	#
	# Aquí estaba el atasco grande. Cualquier destino a menos de sesenta metros
	# se resolvía con una recta sin mirar el terreno de en medio, así que
	# bastaba un cortado de diez metros entre la persona y su tajo para que la
	# «ruta» fuera un único punto al otro lado de una pared. Desde fuera se veía
	# como «camino 1 hito, va por el 0, el siguiente a 54 m» y no avanza: el
	# planificador no había mirado nada.
	#
	# Medido en el sitio 56: la caza menor trabaja a cincuenta y pico metros del
	# sitio, o sea justo dentro del atajo, y cerraba el 81 % de sus salidas con
	# «atascado».
	var span := Vector2(to_point.x - from_point.x, to_point.z - from_point.z).length()
	if span < Navgrid.CELL * 1.5 and _clear_line(grid, from_point, to_point):
		return straight

	# Los dos extremos se amarran a suelo pisable. El destino porque el jugador
	# señala a ojo; y el ORIGEN porque una celda de cuarenta metros que roce el
	# río queda cerrada, y el campamento suele estar justo ahí —los abrigos se
	# eligen junto al agua—. Sin amarrar el origen, la banda entera salía de
	# una celda inexistente y no se le podía trazar nada.
	var start := grid.nearest_open(from_point)
	if start < 0:
		return PackedVector3Array()

	var goal := grid.cell_of(to_point)
	if start == goal:
		return straight


	# Y si están en zonas distintas del mapa, no hay camino y no hace falta
	# buscarlo. Esto es lo que antes costaba doce mil nodos.
	if grid.area[start] < 0 or grid.area[start] != grid.area[goal]:
		return PackedVector3Array()

	# El coste mínimo posible de una celda, para que la heurística no se pase.
	# Una heurística que sobreestima da caminos malos; ésta se queda corta a
	# propósito, que es lo que garantiza que el que salga sea el mejor.
	#
	# Y se le da un EMPUJE. Ceñida al mínimo teórico —el paso de un llano de
	# vacío— la heurística se queda tan corta que el A* se comporta casi como
	# una inundación: medido en el sitio 56 con el valle entero comunicado, 181
	# búsquedas al azar salían a 37 ms de media y 14.000 nodos la peor, o sea
	# más celdas que las que tiene el mapa. Con el empuje deja de explorar hacia
	# atrás; a cambio el camino puede no ser EL óptimo, sino uno bueno, que en
	# un valle es una diferencia de metros y no de rumbo.
	var floor_cost := HEURISTIC_PUSH / Traversal.hiking_speed(0.0)
	var wide := grid.wide
	var tall := grid.tall
	var cells := wide * tall
	var costs := grid.cost

	# Arrays y no diccionarios, y vecinos calculados a mano y no en una lista
	# aparte.
	#
	# Medido: con diccionarios y una lista de vecinos por nodo, un trayecto de
	# punta a punta del mapa costaba 19 ms —un fotograma entero— y eso con la
	# rejilla ya hecha. La búsqueda no hacía nada caro: lo caro era el hash de
	# cada consulta y reservar un array de ocho elementos por cada celda que
	# se miraba. Con arrays planos y el bucle escrito a la vista, lo mismo
	# baja a menos de dos.
	var came := PackedInt32Array()
	came.resize(cells)
	came.fill(-1)
	# A 64 bits, y no es un detalle. Con float32 el coste acumulado se redondea
	# al guardarlo, el siguiente paso se calcula a partir del valor redondeado
	# y sale una pizca MENOR que el guardado: la comparacion lo lee como una
	# mejora y la celda se vuelve a meter en la cola. Medido: la busqueda de
	# punta a punta se reexpandia sin parar y agotaba los doce mil nodos sobre
	# un mapa de dos mil setecientas celdas por las que BFS pasa sin
	# despeinarse.
	var so_far := PackedFloat64Array()
	so_far.resize(cells)
	so_far.fill(INF)
	so_far[start] = 0.0

	var gx := goal % wide
	var gz := goal / wide

	var heap := _Heap.new()
	heap.push(start, float(maxi(absi(start % wide - gx), absi(start / wide - gz)))
		* Navgrid.CELL * floor_cost)
	var visited := 0

	# La lista de CERRADAS. Sin ella, una celda a la que se llega por un camino
	# mejor se vuelve a meter en el montón y se vuelve a expandir entera, y las
	# entradas viejas siguen saliendo después: la misma celda se abría una y
	# otra vez. Medido en el sitio 56 con el valle comunicado, una búsqueda de
	# novecientos metros llegaba a expandir catorce mil nodos —más celdas que
	# las que tiene el mapa entero— y tardaba ochenta milisegundos.
	var closed := PackedByteArray()
	closed.resize(cells)

	while not heap.is_empty() and visited < MAX_NODES:
		var current := heap.pop()
		if closed[current] == 1:
			continue
		closed[current] = 1
		if current == goal:
			last_nodes = visited
			return _rebuild(came, current, start, grid, to_point)
		visited += 1

		var cx := current % wide
		var cz := current / wide
		var here := so_far[current]

		for dz in range(-1, 2):
			var nz := cz + dz
			if nz < 0 or nz >= tall:
				continue
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx := cx + dx
				if nx < 0 or nx >= wide:
					continue

				var neighbour := nz * wide + nx
				var cost := costs[neighbour]
				if cost <= Navgrid.BLOCKED:
					continue

				# NO SE CORTAN ESQUINAS. Una diagonal sólo vale si las dos
				# celdas ortogonales que la rodean están abiertas.
				#
				# Aquí estaba el atasco de verdad, y no era la rejilla: el A*
				# encadena centros de celda y la persona anda en LÍNEA RECTA de
				# uno a otro. Con la diagonal libre, el camino podía colarse por
				# el vértice entre dos celdas cerradas —un paso que no existe
				# sobre el terreno— y quien lo seguía se metía de frente en una
				# de ellas. Desde fuera se veía como «tiene camino, el hito es
				# pisable, y no avanza»: el planificador prometía un paso de
				# anchura cero.
				#
				# Medido en el sitio 56 con la caza menor: el 81 % de las
				# salidas se cerraban con «atascado» y la cuadrilla acababa
				# siempre en el mismo punto, a diez metros de la linde de su
				# celda.
				if dx != 0 and dz != 0:
					if costs[cz * wide + nx] <= Navgrid.BLOCKED:
						continue
					if costs[nz * wide + cx] <= Navgrid.BLOCKED:
						continue
					# Y EL AGUA NO SE CRUZA EN DIAGONAL.
					#
					# Una celda de agua se abre porque tiene una linea vadeable
					# de lado a lado -la fila o la columna de en medio, ver
					# [Navgrid._vado_de_verdad]-. Una diagonal la atraviesa de
					# esquina a esquina, o sea POR FUERA de esa linea, y eso es
					# el cauce. El camino prometia un paso que sobre el terreno
					# es agua honda, y quien lo seguia se plantaba en la orilla
					# a barrerla -y varios en el mismo punto, porque el vado
					# falso era siempre la misma celda.
					if grid.vado.size() == costs.size() 							and (grid.vado[current] != 0 or grid.vado[neighbour] != 0):
						continue

				var step := Navgrid.CELL * (1.414 if dx != 0 and dz != 0 else 1.0)
				var total := here + cost * step
				if total >= so_far[neighbour]:
					continue

				came[neighbour] = current
				so_far[neighbour] = total
				heap.push(neighbour, total
					+ float(maxi(absi(nx - gx), absi(nz - gz)))
						* Navgrid.CELL * floor_cost)

	# Se ha agotado la búsqueda sin llegar: NO hay camino.
	last_nodes = visited
	return PackedVector3Array()


## Si de aquí a allí se puede ir en línea recta sin pisar celda cerrada.
##
## Se mira cada media celda: es el paso más largo con el que no se puede saltar
## por encima de una celda de cuarenta metros sin verla.
static func _clear_line(grid: Navgrid, from_point: Vector3,
		to_point: Vector3) -> bool:
	var span := Vector2(to_point.x - from_point.x,
		to_point.z - from_point.z).length()
	var steps := maxi(int(span / (Navgrid.CELL * 0.5)), 1)
	for i in range(steps + 1):
		var at := from_point.lerp(to_point, float(i) / float(steps))
		if not grid.passable(at):
			return false
	return true


static func _rebuild(came: PackedInt32Array, goal: int, start: int,
		grid: Navgrid, exact: Vector3) -> PackedVector3Array:
	var back: Array[int] = [goal]
	var node := goal
	while node != start and came[node] >= 0:
		node = came[node]
		back.append(node)
	back.reverse()

	# La escalera se quita aquí. Un A* sobre rejilla de ocho direcciones sólo
	# sabe andar en múltiplos de 45 grados, así que un trayecto casi recto le
	# sale en dientes de sierra: se ve fatal, hace andar de más y llena la
	# ruta de hitos que no dicen nada. Se recorta tirando del hilo —se salta
	# todo hito que se pueda saltar sin pisar celda mala— y queda la línea que
	# de verdad seguiría alguien.
	var pulled := _pull_string(back, grid)

	var out := PackedVector3Array()
	# El primero es la celda de donde se sale: se salta, ya se está ahí
	for i in range(1, pulled.size()):
		out.append(grid.point_of(pulled[i]))

	# Y el último tramo, hasta el punto exacto y no al centro de su celda
	if out.size() > 0:
		out[out.size() - 1] = exact
	else:
		out.append(exact)
	return out


## Quita los hitos que no hacen falta.
##
## De cada hito se mira hasta dónde se llega en línea recta sin pisar una
## celda por la que no se pasa; ése pasa a ser el siguiente. Es lo que
## convierte una escalera de veinte dientes en cuatro tramos rectos.
static func _pull_string(cells: Array[int], grid: Navgrid) -> Array[int]:
	if cells.size() < 3:
		return cells

	var out: Array[int] = [cells[0]]
	var anchor := 0
	while anchor < cells.size() - 1:
		var furthest := anchor + 1
		for candidate in range(cells.size() - 1, anchor, -1):
			if _clear_between(cells[anchor], cells[candidate], grid):
				furthest = candidate
				break
		out.append(cells[furthest])
		anchor = furthest
	return out


## Si de una celda a otra se va derecho sin pisar nada intransitable.
##
## Sólo mira que se PUEDA pasar, no lo que cuesta: el camino ya lo eligió el
## A* con el coste delante, y esto únicamente le quita los dientes de sierra.
## Recortar por coste desharía el rodeo del canchal, que es justo lo que no se
## quiere.
static func _clear_between(from_cell: int, to_cell: int, grid: Navgrid) -> bool:
	var ax := from_cell % grid.wide
	var az := from_cell / grid.wide
	var bx := to_cell % grid.wide
	var bz := to_cell / grid.wide

	var steps := maxi(absi(bx - ax), absi(bz - az))
	if steps == 0:
		return true

	# Se muestrea DENSO y con los dos vecinos ortogonales de cada punto.
	#
	# Con una muestra por celda, la recta recortada pasa rozando la esquina de
	# una celda cerrada sin llegar a caer dentro de ella, y el recorte la da
	# por buena. Luego el que anda sigue esa recta de verdad, pisa la esquina,
	# y ahi se queda empujando la roca: medido, cincuenta y un atascos de
	# cincuenta y seis eran esto -«no avanza por el camino trazado»- y no un
	# fallo del andador ni de la rejilla, sino de este recorte prometiendo un
	# atajo que no existe.
	var fine := steps * 3
	for i in range(1, fine + 1):
		var t := float(i) / float(fine)
		var fx := lerpf(float(ax), float(bx), t)
		var fz := lerpf(float(az), float(bz), t)
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var x := clampi(int(floor(fx)) + corner.x, 0, grid.wide - 1)
			var z := clampi(int(floor(fz)) + corner.y, 0, grid.tall - 1)
			if grid.cost[z * grid.wide + x] <= Navgrid.BLOCKED:
				return false
	return true


## Montículo binario mínimo.
##
## Existe porque la lista abierta se recorría entera para sacar el mejor nodo,
## y eso es cuadrático: con cuatro mil nodos, ocho millones de comparaciones
## en un solo fotograma. Ahí es donde se congelaba la imagen cada vez que
## alguien pedía un camino largo.
class _Heap extends RefCounted:
	var _nodes: PackedInt32Array = PackedInt32Array()
	var _costs: PackedFloat64Array = PackedFloat64Array()

	func is_empty() -> bool:
		return _nodes.is_empty()

	func push(node: int, cost: float) -> void:
		_nodes.append(node)
		_costs.append(cost)
		var i := _nodes.size() - 1
		while i > 0:
			@warning_ignore("integer_division")
			var parent := (i - 1) / 2
			if _costs[parent] <= _costs[i]:
				break
			_swap(parent, i)
			i = parent

	func pop() -> int:
		var top := _nodes[0]
		var last := _nodes.size() - 1
		_swap(0, last)
		_nodes.remove_at(last)
		_costs.remove_at(last)

		var i := 0
		while true:
			var left := i * 2 + 1
			var right := left + 1
			var best := i
			if left < _nodes.size() and _costs[left] < _costs[best]:
				best = left
			if right < _nodes.size() and _costs[right] < _costs[best]:
				best = right
			if best == i:
				break
			_swap(best, i)
			i = best
		return top

	func _swap(a: int, b: int) -> void:
		var node := _nodes[a]
		_nodes[a] = _nodes[b]
		_nodes[b] = node
		var cost := _costs[a]
		_costs[a] = _costs[b]
		_costs[b] = cost
