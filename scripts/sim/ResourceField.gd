class_name ResourceField
extends RefCounted
## Abundancia de cada recurso repartida por el territorio, y su estación.
##
## Antes cada actividad tenía UN punto: la pesquera, el coto de caza. Eso
## convierte la subsistencia en una lista de coordenadas fijas, cuando lo que
## define a un cazador-recolector es justo lo contrario: el recurso está
## repartido en manchas, se mueve con la estación, y averiguar dónde y cuándo
## es el trabajo de toda una vida. Ver [BandKnowledge], que es la otra mitad:
## esto es lo que HAY, y aquello lo que la banda SABE que hay.
##
## La rejilla es gruesa a propósito —decenas de metros por celda— porque una
## mancha de avellanos o un cotarro de ciervos son zonas, no puntos, y porque
## así cabe entera en memoria y se puede consultar por fragmento.

## Rejilla de abundancia por actividad. La clave es Subsistence.Activity.
var grids: Dictionary = {}

## Lo que tenia cada celda intacta. Se guarda aparte para poder saber cuanto se
## ha esquilmado y hasta donde puede reponerse.
var capacities: Dictionary = {}

var width: int = 0
var height: int = 0
var world_size: Vector2 = Vector2.ZERO


func setup(cells_x: int, cells_z: int, world_extent: Vector2) -> void:
	width = maxi(cells_x, 1)
	height = maxi(cells_z, 1)
	world_size = world_extent
	grids.clear()
	capacities.clear()
	for activity in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var grid := PackedFloat32Array()
		grid.resize(width * height)
		grids[activity] = grid
		capacities[activity] = PackedFloat32Array(grid)


## Multiplicador de temporada de una actividad.
##
## Los valores no son de adorno: salen de lo que dice el registro cantábrico.
## El salmón remonta el Nansa y el Deva en primavera; la berrea concentra los
## ciervos en otoño y además llegan cebados; el marisco es lo que sostiene el
## invierno, y eso está escrito en los concheros de la costa, que se disparan
## justo cuando la caza y la recolección fallan.
static func seasonal_factor(activity: Subsistence.Activity,
		season: Subsistence.Season) -> float:
	match activity:
		Subsistence.Activity.PESCA:
			# El REMONTE manda: el salmón atlántico sube el Deva y el Nansa de
			# primavera a principios de verano, y ésa es la ventana. El otoño
			# baja más de lo que estaba: con las crecidas el río va turbio y
			# alto, y en agua turbia no se ve la pieza ni se clava el arpón.
			match season:
				Subsistence.Season.PRIMAVERA: return 1.85
				Subsistence.Season.VERANO: return 1.15
				Subsistence.Season.OTONO: return 0.60
				_: return 0.40
		Subsistence.Activity.CAZA:
			# Dos picos y no uno, que es lo que faltaba:
			#
			#   OTOÑO   la berrea. Los ciervos se juntan, braman -o sea que se
			#           les oye desde lejos- y llegan gordos del verano.
			#   INVIERNO la trasterminancia. Cabra, rebeco y ciervo BAJAN de la
			#           montaña a los valles huyendo de la nieve, y la nieve
			#           delata el rastro y agota a la pieza. La caza mayor
			#           invernal está atestiguada en los yacimientos cantábricos
			#           y aquí valía 1,05, o sea «un mes más».
			#
			# Y una penalización de verdad en primavera: los animales están
			# flacos, las hembras preñadas o con cría, y matarlas hipoteca el
			# año siguiente. Ahora eso se nota también en la población, no sólo
			# en el rendimiento. Ver [Poblaciones].
			match season:
				Subsistence.Season.OTONO: return 1.70
				Subsistence.Season.INVIERNO: return 1.35
				Subsistence.Season.VERANO: return 0.80
				_: return 0.55
		Subsistence.Activity.RECOLECCION:
			# El otoño es LA cosecha y el invierno es el vacío. Se separan más
			# que antes: con 1,80 contra 0,25 el invierno ya era flojo, pero la
			# avellana salía las cuatro estaciones y lo tapaba. Ver
			# [Tajo._gathering_yields], que es donde estaba el error de verdad.
			match season:
				Subsistence.Season.OTONO: return 1.90
				Subsistence.Season.VERANO: return 1.10
				Subsistence.Season.PRIMAVERA: return 0.70
				_: return 0.20
		Subsistence.Activity.MARISQUEO:
			# Lapa y mejillón aguantan todo el año y son el colchón del invierno
			match season:
				Subsistence.Season.INVIERNO: return 1.15
				Subsistence.Season.PRIMAVERA: return 1.05
				_: return 0.90
		_:
			# La piedra no tiene temporada. Baja algo en invierno solo porque
			# la crecida tapa las barras de cantos del río.
			return 0.85 if season == Subsistence.Season.INVIERNO else 1.0


func set_abundance(activity: Subsistence.Activity, x: int, z: int, value: float) -> void:
	if not grids.has(activity) or x < 0 or z < 0 or x >= width or z >= height:
		return
	var grid: PackedFloat32Array = grids[activity]
	grid[z * width + x] = value
	grids[activity] = grid
	var cap: PackedFloat32Array = capacities.get(activity, PackedFloat32Array(grid))
	if cap.size() == grid.size():
		cap[z * width + x] = value
		capacities[activity] = cap


func abundance_cell(activity: Subsistence.Activity, x: int, z: int) -> float:
	if not grids.has(activity) or x < 0 or z < 0 or x >= width or z >= height:
		return 0.0
	return (grids[activity] as PackedFloat32Array)[z * width + x]


## Extiende cada núcleo a las celdas de alrededor, decayendo con la distancia.
##
## Un cotarro de caza no es una celda suelta: es una zona con un centro mejor y
## unos bordes peores. Sin esto la banda tendría que acertar la celda exacta.
func spread(activity: Subsistence.Activity, radius: int) -> void:
	if not grids.has(activity) or radius <= 0:
		return

	var source: PackedFloat32Array = grids[activity]
	var out := PackedFloat32Array(source)

	for z in range(height):
		for x in range(width):
			var seed_value := source[z * width + x]
			if seed_value <= 0.0:
				continue
			for dz in range(-radius, radius + 1):
				var nz := z + dz
				if nz < 0 or nz >= height:
					continue
				for dx in range(-radius, radius + 1):
					var nx := x + dx
					if nx < 0 or nx >= width:
						continue
					var distance := sqrt(float(dx * dx + dz * dz))
					if distance > float(radius):
						continue
					# Decae de forma continua hasta anularse en el borde
					var falloff := 1.0 - distance / float(radius + 1)
					var value := seed_value * falloff * falloff
					var j := nz * width + nx
					if value > out[j]:
						out[j] = value

	grids[activity] = out
	# La capacidad se fija DESPUES de extender las manchas: es el estado
	# intacto del terreno, y de ahi se mide cuanto se ha esquilmado
	capacities[activity] = PackedFloat32Array(out)


## Abundancia bruta en un punto del mundo, sin contar la estación.
func abundance_at(activity: Subsistence.Activity, world_position: Vector3) -> float:
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return 0.0
	if world_position.x < 0.0 or world_position.z < 0.0 \
			or world_position.x > world_size.x or world_position.z > world_size.y:
		return 0.0

	var x := clampi(int(world_position.x / world_size.x * float(width)), 0, width - 1)
	var z := clampi(int(world_position.z / world_size.y * float(height)), 0, height - 1)
	return abundance_cell(activity, x, z)


## Lo que ese punto da EN esta estación, que es lo único que importa para
## decidir a qué se dedica la jornada de hoy.
func seasonal_abundance_at(activity: Subsistence.Activity, world_position: Vector3,
		season: Subsistence.Season) -> float:
	return abundance_at(activity, world_position) * seasonal_factor(activity, season)


## Repone lo gastado, con curva logistica: se recupera mas rapido a media carga
## que casi vacio, que es como funcionan las poblaciones de verdad. Una mancha
## esquilmada tarda desproporcionadamente en volver.
func regrow(activity: Subsistence.Activity, rate: float) -> void:
	if not grids.has(activity) or not capacities.has(activity):
		return
	var grid: PackedFloat32Array = grids[activity]
	var cap: PackedFloat32Array = capacities[activity]
	var dead: PackedByteArray = frozen.get(activity, PackedByteArray())
	for i in range(grid.size()):
		var capacity := cap[i]
		if capacity <= 0.001:
			continue
		if i < dead.size() and dead[i] != 0:
			continue
		var stock := grid[i]
		grid[i] = clampf(stock + rate * maxf(stock, capacity * 0.04)
			* (1.0 - stock / capacity), 0.0, capacity)
	grids[activity] = grid


## Cuanto queda en una celda respecto a lo que tenia intacta, de 0 a 1.
func stock_fraction(activity: Subsistence.Activity, x: int, z: int) -> float:
	if not capacities.has(activity):
		return 1.0
	var cap: PackedFloat32Array = capacities[activity]
	var i := z * width + x
	if i < 0 or i >= cap.size() or cap[i] <= 0.001:
		return 1.0
	return clampf(abundance_cell(activity, x, z) / cap[i], 0.0, 1.0)


## Lo que queda en TODA la mancha de un sitio, de 0 a 1, y no en una sola
## celda.
##
## Hace falta porque quien trabaja un paraje no pisa siempre su celda: cada
## cual se reparte su rincón —hasta 55 m de la chapa, ver
## `SettlementSim._best_known_spot`— y va derivando mientras recoge, así que
## el gasto cae en las celdas de alrededor. Mirando solo la del centro, la
## ficha del paraje decía que quedaba todo mientras la cuadrilla lo estaba
## dejando seco: el número no bajaba nunca y el agotamiento era invisible.
func stock_fraction_around(activity: Subsistence.Activity, centre: Vector3,
		radius: float) -> float:
	if not capacities.has(activity) or width <= 0 or height <= 0:
		return 1.0
	var cell_w := world_size.x / float(width)
	var cell_h := world_size.y / float(height)
	var reach_x := maxi(int(ceil(radius / maxf(cell_w, 0.001))), 0)
	var reach_z := maxi(int(ceil(radius / maxf(cell_h, 0.001))), 0)

	var cx := clampi(int(centre.x / world_size.x * float(width)), 0, width - 1)
	var cz := clampi(int(centre.z / world_size.y * float(height)), 0, height - 1)

	# Se pondera por capacidad: las celdas vacías de nacimiento no cuentan,
	# porque «no queda nada» y «aquí nunca hubo nada» no son lo mismo.
	var stock := 0.0
	var room := 0.0
	var cap: PackedFloat32Array = capacities[activity]
	var grid: PackedFloat32Array = grids[activity]
	for dz in range(-reach_z, reach_z + 1):
		var z := cz + dz
		if z < 0 or z >= height:
			continue
		for dx in range(-reach_x, reach_x + 1):
			var x := cx + dx
			if x < 0 or x >= width:
				continue
			var i := z * width + x
			if cap[i] <= 0.001:
				continue
			stock += grid[i]
			room += cap[i]

	if room <= 0.001:
		return 1.0
	return clampf(stock / room, 0.0, 1.0)


## Celdas que no se reponen, por actividad: `activity -> PackedByteArray`.
##
## Una mata de avellano rebrota y una manada se recompone; un nodulo de silex
## no. Sin esto, `regrow` le devolvia a la veta lo mismo que a un pastizal y
## una cantera se estabilizaba para siempre en tres cuartos de carga: medido
## con ocho canteros, ciento cuarenta dias y seis mil unidades sacadas, el
## cantizal seguia al 77% y no se agotaba nunca. Lo llena
## [SettlementSim._freeze_veins] una vez, al montar el mundo.
var frozen: Dictionary = {}


## Marca una celda como de las que no vuelven a crecer.
func freeze(activity: Subsistence.Activity, x: int, z: int) -> void:
	if not grids.has(activity) or x < 0 or z < 0 or x >= width or z >= height:
		return
	var dead: PackedByteArray = frozen.get(activity, PackedByteArray())
	if dead.size() != width * height:
		dead.resize(width * height)
	dead[z * width + x] = 1
	frozen[activity] = dead


## Si esta celda es de las que no vuelven a crecer.
func is_frozen(activity: Subsistence.Activity, x: int, z: int) -> bool:
	var dead: PackedByteArray = frozen.get(activity, PackedByteArray())
	var i := z * width + x
	return i >= 0 and i < dead.size() and dead[i] != 0


## Gasta de la MEJOR celda que haya al alcance, no de la de debajo.
##
## Existe por la pesca, y es un problema de todos los oficios de orilla: se
## pesca DESDE la ribera, o sea desde una celda de tierra, y el pescado esta
## en la celda de agua de al lado. Mirando solo la celda de debajo, un
## pescador se pasaba la jornada en un cotarro con abundancia 0,000 y volvia
## de vacio todos los dias -medido en el sitio 56: doce salidas, cero
## pescado, con 156 celdas de rio con pesca en el mismo mapa.
##
## Vale para todo lo demas igual: nadie trabaja de pie sobre un punto, se
## La celda mas rica al alcance para esta actividad, o -1 si no hay ninguna.
##
## Se saco de `deplete_around` porque MIRAR y RESTAR son dos cosas y hacian
## falta por separado: la cosecha necesita saber cuanto queda ANTES de decidir
## cuanto se lleva, y restar antes de coger obligaba a que la merma fuera un
## numero fijo por jornada en vez de lo que de verdad se ha cogido.
func best_cell(activity: Subsistence.Activity, centre: Vector3,
	radius: float) -> int:
	if not grids.has(activity):
		return -1
	var grid: PackedFloat32Array = grids[activity]
	var cap: PackedFloat32Array = capacities.get(activity, grid)
	var best := -1
	var best_stock := 0.0
	for cell: Vector2i in cells_within(centre, radius):
		var i := cell.y * width + cell.x
		if i < 0 or i >= grid.size() or cap[i] <= 0.001:
			continue
		if grid[i] > best_stock:
			best_stock = grid[i]
			best = i
	return best


## Cuanto le queda a esa celda, de 0 a 1. Sin tocarla.
func stock_of_cell(activity: Subsistence.Activity, index: int) -> float:
	if index < 0 or not grids.has(activity):
		return 0.0
	var grid: PackedFloat32Array = grids[activity]
	var cap: PackedFloat32Array = capacities.get(activity, grid)
	if index >= grid.size() or cap[index] <= 0.001:
		return 0.0
	return clampf(grid[index] / cap[index], 0.0, 1.0)


## Le quita a esa celda lo que se haya cogido de ella.
func take_from_cell(activity: Subsistence.Activity, index: int,
	amount: float) -> void:
	if index < 0 or amount <= 0.0 or not grids.has(activity):
		return
	var grid: PackedFloat32Array = grids[activity]
	if index >= grid.size():
		return
	grid[index] = maxf(grid[index] - amount, 0.0)
	grids[activity] = grid


## Las mejores celdas de esta actividad al alcance, de mas a menos.
##
## Devuelve varias y no una porque la mejor puede no servir: el que planta un
## tajo tiene que poder descartar la celda que esta al otro lado del rio y
## quedarse con la siguiente.
func best_spots_near(activity: Subsistence.Activity, centre: Vector3,
		radius: float, limit: int = 8) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not grids.has(activity):
		return out
	var grid: PackedFloat32Array = grids[activity]

	var found: Array[Dictionary] = []
	for cell: Vector2i in cells_within(centre, radius):
		var i := cell.y * width + cell.x
		if i < 0 or i >= grid.size() or grid[i] <= 0.001:
			continue
		found.append({"pos": cell_center(cell.x, cell.y), "stock": grid[i]})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["stock"]) > float(b["stock"]))

	for entry: Dictionary in found:
		if out.size() >= limit:
			break
		out.append(entry["pos"] as Vector3)
	return out


## El centro de la mejor celda de esta actividad al alcance, o el propio punto
## si no hay ninguna. Sirve para plantar un tajo donde de verdad hay algo.
func best_spot_near(activity: Subsistence.Activity, centre: Vector3,
		radius: float) -> Vector3:
	var best := best_spots_near(activity, centre, radius, 1)
	return best[0] if not best.is_empty() else centre


## Las celdas que caen dentro de un radio alrededor de un punto.
func cells_within(centre: Vector3, radius: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if width <= 0 or height <= 0:
		return out
	var cell_w := world_size.x / float(width)
	var cell_h := world_size.y / float(height)
	var reach_x := maxi(int(ceil(radius / maxf(cell_w, 0.001))), 0)
	var reach_z := maxi(int(ceil(radius / maxf(cell_h, 0.001))), 0)
	var cx := clampi(int(centre.x / world_size.x * float(width)), 0, width - 1)
	var cz := clampi(int(centre.z / world_size.y * float(height)), 0, height - 1)
	for dz in range(-reach_z, reach_z + 1):
		var z := cz + dz
		if z < 0 or z >= height:
			continue
		for dx in range(-reach_x, reach_x + 1):
			var x := cx + dx
			if x < 0 or x >= width:
				continue
			out.append(Vector2i(x, z))
	return out


## Seca una celda para siempre: cero existencias y cero CAPACIDAD.
##
## Es lo que separa esquilmar de AGOTAR. Una mancha esquilmada vuelve -para
## eso esta `regrow`, que se apoya en la capacidad-; una celda seca no,
## porque se le quita la capacidad y ya no hay a que volver. El silex de un
## nodulo se saca una vez.
func dry_cell(activity: Subsistence.Activity, x: int, z: int) -> bool:
	if not grids.has(activity) or not capacities.has(activity):
		return false
	if x < 0 or z < 0 or x >= width or z >= height:
		return false
	var i := z * width + x
	var cap: PackedFloat32Array = capacities[activity]
	if cap[i] <= 0.001:
		return false
	var grid: PackedFloat32Array = grids[activity]
	cap[i] = 0.0
	grid[i] = 0.0
	capacities[activity] = cap
	grids[activity] = grid
	return true


## Centro del mundo de una celda
func cell_center(x: int, z: int) -> Vector3:
	if width <= 0 or height <= 0:
		return Vector3.ZERO
	return Vector3(
		(float(x) + 0.5) / float(width) * world_size.x, 0.0,
		(float(z) + 0.5) / float(height) * world_size.y)
