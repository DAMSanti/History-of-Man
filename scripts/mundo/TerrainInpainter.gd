@tool
class_name TerrainInpainter
extends RefCounted
## Borra del relieve la obra humana y reconstruye la ladera que había debajo.
##
## El problema: el MDT del IGN es LiDAR, o sea que las carreteras están
## TALLADAS en la malla, con su desmonte por arriba y su terraplén por abajo.
## En un mapa que empieza en el Paleolítico eso son cicatrices de hormigón en
## un paisaje que no debería tener ninguna.
##
## La solución no es alisar: alisar se carga también los acantilados y las
## vaguadas reales. Se marcan las celdas de la obra con la geometría de OSM
## —que sabe DÓNDE hay carretera, sin tener que adivinarlo del relieve— y solo
## dentro de esa marca se resuelve la ecuación de Laplace con la cota del borde
## como condición de contorno. Es decir: se tiende una membrana entre los dos
## lados del corte. Sobre una ladera, la membrana de mínima energía entre dos
## bordes a distinta cota es exactamente la rampa original.
##
## Ver [OSMWays] para la parte que habla con la red.

## Barridos de relajación. Con franjas de 3-5 celdas de semiancho converge
## mucho antes; el margen es para las canteras, que son anchas.
const DEFAULT_ITERATIONS := 40

## Factor de sobrerrelajación (SOR). Con 1.0 esto es Gauss-Seidel a secas, que
## sobre una cantera ancha necesita cientos de barridos porque la corrección
## avanza una celda por barrido. Pasarse del valor de equilibrio acelera mucho
## la propagación; por encima de 2.0 el método diverge, así que 1.85 deja
## margen de sobra.
const OVER_RELAXATION := 1.85


## Marca en la rejilla las celdas ocupadas por obra humana.
## `ways` son diccionarios {points (lon,lat), half_width_m, closed}.
static func build_mask(data: HeightmapData, ways: Array) -> PackedByteArray:
	var w := data.width
	var h := data.height
	var mask := PackedByteArray()
	mask.resize(w * h)

	if w <= 0 or h <= 0 or ways.is_empty():
		return mask

	var mps: float = maxf(data.meters_per_sample, 0.001)

	for entry: Variant in ways:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var way: Dictionary = entry
		var points: PackedVector2Array = way.get("points", PackedVector2Array())
		if points.size() < 2:
			continue

		# Geográfico a celda, una sola vez por vértice
		var cells := PackedVector2Array()
		for p: Vector2 in points:
			cells.append(Vector2(
				data.u_for_lon(p.x) * float(w - 1),
				data.v_for_lat(p.y) * float(h - 1)))

		if bool(way.get("closed", false)):
			_fill_polygon(mask, w, h, cells)

		var radius: float = maxf(float(way.get("half_width_m", 8.0)) / mps, 0.5)
		for i in range(cells.size() - 1):
			_stroke_segment(mask, w, h, cells[i], cells[i + 1], radius)

	return mask


## Reconstruye la cota de las celdas marcadas. Devuelve cuántas ha reparado.
static func inpaint(data: HeightmapData, mask: PackedByteArray,
		iterations: int = DEFAULT_ITERATIONS) -> int:
	var w := data.width
	var h := data.height
	var n := w * h
	if mask.size() != n or n == 0:
		return 0

	var marked := PackedInt32Array()
	for i in range(n):
		if mask[i] != 0:
			marked.append(i)
	if marked.is_empty():
		return 0

	var elev := data.elevations

	# --- 1. Semilla: la cota del borde más cercano -------------------------
	# Sin esto la relajación parte de la cota falsa de la carretera y tarda
	# cientos de barridos en olvidarla.
	#
	# Se propaga en anchura desde el contorno de la marca hacia dentro, tocando
	# SOLO las celdas marcadas. La primera versión hacía dos barridos de chamfer
	# sobre la rejilla entera y eso costaba cuatro segundos para sembrar el 4%
	# de las celdas: el 96% del trabajo era sobre terreno que no se toca.
	_seed_from_border(elev, mask, marked, w, h)

	# --- 2. Relajación de Laplace dentro de la marca -----------------------
	# Los índices de los cuatro vecinos se calculan UNA vez, no una por celda y
	# barrido: con 35.000 celdas marcadas y decenas de barridos, el módulo y la
	# división del índice costaban más que la propia física.
	var count := marked.size()
	var nb_l := PackedInt32Array()
	var nb_r := PackedInt32Array()
	var nb_u := PackedInt32Array()
	var nb_d := PackedInt32Array()
	nb_l.resize(count)
	nb_r.resize(count)
	nb_u.resize(count)
	nb_d.resize(count)

	for k in range(count):
		var i: int = marked[k]
		var x := i % w
		var z := i / w
		# En el borde de la rejilla se refleja el vecino de enfrente: da
		# derivada nula, que es lo correcto cuando no hay dato más allá.
		nb_l[k] = i - 1 if x > 0 else i + 1
		nb_r[k] = i + 1 if x < w - 1 else i - 1
		nb_u[k] = i - w if z > 0 else i + w
		nb_d[k] = i + w if z < h - 1 else i - w

	# Gauss-Seidel en sitio con sobrerrelajación: usa los vecinos ya
	# actualizados de este mismo barrido, sin necesitar una segunda copia de la
	# rejilla, y el factor de sobrerrelajación empuja la corrección más allá del
	# equilibrio local para que atraviese antes las marcas anchas.
	var omega := OVER_RELAXATION
	for _pass in range(iterations):
		for k in range(count):
			var i: int = marked[k]
			var average: float = (elev[nb_l[k]] + elev[nb_r[k]]
				+ elev[nb_u[k]] + elev[nb_d[k]]) * 0.25
			elev[i] += omega * (average - elev[i])

	data.elevations = elev

	# El rango cambia al quitar terraplenes y desmontes, y de él dependen las
	# bandas de material y la escala vertical de la malla.
	var lo := INF
	var hi := -INF
	for e in elev:
		lo = minf(lo, e)
		hi = maxf(hi, e)
	data.min_elevation = lo
	data.max_elevation = hi

	return marked.size()


## Pinta un segmento grueso recorriéndolo y estampando un disco.
static func _stroke_segment(mask: PackedByteArray, w: int, h: int,
		a: Vector2, b: Vector2, radius: float) -> void:
	var delta := b - a
	var length := delta.length()
	# Un paso de media celda garantiza que los discos se solapan y la traza
	# sale continua en vez de una hilera de puntos
	var steps := maxi(int(length * 2.0), 1)

	var r2 := radius * radius
	var ri := int(ceil(radius))

	for s in range(steps + 1):
		var centre := a + delta * (float(s) / float(steps))
		var cx := int(round(centre.x))
		var cz := int(round(centre.y))
		# Descarte rápido: la mayor parte de las vías de una consulta caen
		# fuera del recuadro jugable
		if cx < -ri or cz < -ri or cx > w + ri or cz > h + ri:
			continue

		for dz in range(-ri, ri + 1):
			var z := cz + dz
			if z < 0 or z >= h:
				continue
			var row := z * w
			for dx in range(-ri, ri + 1):
				var x := cx + dx
				if x < 0 or x >= w:
					continue
				var ox := float(x) - centre.x
				var oz := float(z) - centre.y
				if ox * ox + oz * oz <= r2:
					mask[row + x] = 1


## Relleno de polígono por barrido de líneas, regla par-impar. Es el mismo
## método que usa RegionBoundary para la frontera, aquí sobre coordenadas de
## celda en vez de geográficas.
static func _fill_polygon(mask: PackedByteArray, w: int, h: int,
		cells: PackedVector2Array) -> void:
	var min_z := INF
	var max_z := -INF
	for c: Vector2 in cells:
		min_z = minf(min_z, c.y)
		max_z = maxf(max_z, c.y)

	var z_from := maxi(int(floor(min_z)), 0)
	var z_to := mini(int(ceil(max_z)), h - 1)

	for z in range(z_from, z_to + 1):
		var scan := float(z) + 0.5
		var crossings := PackedFloat32Array()

		for i in range(cells.size()):
			var a := cells[i]
			var b := cells[(i + 1) % cells.size()]
			if (a.y <= scan) == (b.y <= scan):
				continue
			var t := (scan - a.y) / (b.y - a.y)
			crossings.append(a.x + t * (b.x - a.x))

		if crossings.size() < 2:
			continue
		crossings.sort()

		var row := z * w
		var i := 0
		while i + 1 < crossings.size():
			var x_from := maxi(int(ceil(crossings[i])), 0)
			var x_to := mini(int(floor(crossings[i + 1])), w - 1)
			for x in range(x_from, x_to + 1):
				mask[row + x] = 1
			i += 2


## Rellena las celdas marcadas con la cota del borde de la marca más cercano,
## propagando en anchura desde fuera hacia dentro.
##
## Es solo una aproximación de arranque: la que fija la forma buena es la
## relajación posterior. Lo que aporta es que la relajación empiece con valores
## del orden correcto en vez de con la cota de la carretera.
static func _seed_from_border(elev: PackedFloat32Array, mask: PackedByteArray,
		marked: PackedInt32Array, w: int, h: int) -> void:
	var seeded := PackedByteArray()
	seeded.resize(mask.size())
	var frontier := PackedInt32Array()

	# Anillo exterior: celdas marcadas con al menos un vecino de terreno bueno
	for i in marked:
		var x := i % w
		var z := i / w
		var sum := 0.0
		var count := 0
		if x > 0 and mask[i - 1] == 0:
			sum += elev[i - 1]
			count += 1
		if x < w - 1 and mask[i + 1] == 0:
			sum += elev[i + 1]
			count += 1
		if z > 0 and mask[i - w] == 0:
			sum += elev[i - w]
			count += 1
		if z < h - 1 and mask[i + w] == 0:
			sum += elev[i + w]
			count += 1
		if count > 0:
			elev[i] = sum / float(count)
			seeded[i] = 1
			frontier.append(i)

	# Hacia dentro, anillo a anillo, hasta que no quede nada por sembrar
	while not frontier.is_empty():
		var next := PackedInt32Array()
		for i in frontier:
			var x := i % w
			var z := i / w
			var neighbours := [
				i - 1 if x > 0 else -1,
				i + 1 if x < w - 1 else -1,
				i - w if z > 0 else -1,
				i + w if z < h - 1 else -1,
			]
			for j: int in neighbours:
				if j < 0 or mask[j] == 0 or seeded[j] != 0:
					continue
				elev[j] = elev[i]
				seeded[j] = 1
				next.append(j)
		frontier = next
