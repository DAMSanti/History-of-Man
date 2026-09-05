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
			# Remonte del salmón: primavera y arranque del verano
			match season:
				Subsistence.Season.PRIMAVERA: return 1.85
				Subsistence.Season.VERANO: return 1.15
				Subsistence.Season.OTONO: return 0.85
				_: return 0.40
		Subsistence.Activity.CAZA:
			# La berrea junta los ciervos y llegan gordos del verano
			match season:
				Subsistence.Season.OTONO: return 1.70
				Subsistence.Season.INVIERNO: return 1.05
				Subsistence.Season.VERANO: return 0.85
				_: return 0.65
		Subsistence.Activity.RECOLECCION:
			# Avellana, bellota y fruto de otoño; en invierno no queda nada
			match season:
				Subsistence.Season.OTONO: return 1.80
				Subsistence.Season.VERANO: return 1.30
				Subsistence.Season.PRIMAVERA: return 0.75
				_: return 0.25
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


## Gasta parte de lo que hay en una celda y devuelve el rendimiento relativo
## que quedaba, de 0 a 1.
##
## Es lo que hace que un paraje se agote: el segundo recolector del dia saca
## menos que el primero, y el de la semana que viene menos todavia. Sin esto,
## anadir gente a un sitio bueno da comida sin limite.
func deplete_at(activity: Subsistence.Activity, world_position: Vector3,
		amount: float) -> float:
	if world_size.x <= 0.0 or world_size.y <= 0.0 or not grids.has(activity):
		return 1.0
	if world_position.x < 0.0 or world_position.z < 0.0 			or world_position.x > world_size.x or world_position.z > world_size.y:
		return 1.0

	var x := clampi(int(world_position.x / world_size.x * float(width)), 0, width - 1)
	var z := clampi(int(world_position.z / world_size.y * float(height)), 0, height - 1)
	var i := z * width + x

	var grid: PackedFloat32Array = grids[activity]
	var capacity := grid[i]
	if capacities.has(activity):
		var cap: PackedFloat32Array = capacities[activity]
		if i < cap.size():
			capacity = cap[i]
	if capacity <= 0.001:
		return 0.0

	var before := grid[i]
	grid[i] = maxf(before - amount, 0.0)
	grids[activity] = grid
	return clampf(before / capacity, 0.0, 1.0)


## Repone lo gastado, con curva logistica: se recupera mas rapido a media carga
## que casi vacio, que es como funcionan las poblaciones de verdad. Una mancha
## esquilmada tarda desproporcionadamente en volver.
func regrow(activity: Subsistence.Activity, rate: float) -> void:
	if not grids.has(activity) or not capacities.has(activity):
		return
	var grid: PackedFloat32Array = grids[activity]
	var cap: PackedFloat32Array = capacities[activity]
	for i in range(grid.size()):
		var capacity := cap[i]
		if capacity <= 0.001:
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


## Centro del mundo de una celda
func cell_center(x: int, z: int) -> Vector3:
	if width <= 0 or height <= 0:
		return Vector3.ZERO
	return Vector3(
		(float(x) + 0.5) / float(width) * world_size.x, 0.0,
		(float(z) + 0.5) / float(height) * world_size.y)
