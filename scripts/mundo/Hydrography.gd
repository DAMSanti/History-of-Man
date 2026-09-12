@tool
class_name Hydrography
extends RefCounted
## Rasteriza la red fluvial de OpenStreetMap sobre la rejilla de alturas.
##
## Antes los cauces se deducían del relieve por acumulación de drenaje D8. Eso
## funciona a escala regional, donde una cuenca de 50 km² se ve sola, pero
## sobre un recuadro local de 4 km deja un 0,5% de celdas con valor medio 0,06:
## técnicamente hay río y visualmente no hay nada. Y sobre todo, del relieve no
## sale el NOMBRE ni el CAUDAL: un algoritmo no sabe que ese hilo concreto es
## el Nansa y aquel de al lado una escorrentía de temporal.
##
## OSM sí lo sabe, porque lo ha cartografiado alguien. Y trae una cosa que del
## relieve costaría mucho sacar: el sentido de la corriente. La convención es
## que una vía de agua se digitaliza aguas ABAJO, así que el orden de los
## vértices es la dirección del flujo, y con eso el agua puede correr en la
## dirección correcta en vez de vibrar en el sitio.
##
## Fuente: OpenStreetMap (ODbL). Ver [OSMWays] para la descarga.

## Celdas de difuminado de la orilla. Un borde duro entre agua y tierra canta
## muchísimo; con esto la lámina se desvanece contra la ribera.
const BANK_BLEND_CELLS := 1.6

## Umbrales de vadeo, sobre la escala de `ford_mask`.
##
## Por debajo de FORD_WADEABLE se cruza sin pensarlo -saltando de piedra en
## piedra-, entre los dos umbrales se vadea mojandose y perdiendo tiempo, y por
## encima de FORD_IMPASSABLE hace falta puente o embarcacion.
##
## La anchura se usa como medida indirecta del calado porque es lo unico que da
## OSM. No es exacta, pero la correlacion es buena: un cauce ancho lleva mas
## agua, y sobre todo el criterio que importa -si se moja el hombro o no- se
## corresponde bastante bien con si el cauce pasa de unos ocho metros.
const FORD_WADEABLE := 0.35
const FORD_IMPASSABLE := 0.70

## Por encima de esto ya se ve lamina de agua, aunque se cruce de un salto.
##
## No es un umbral de paso -de eso van los dos de arriba- sino de PRESENCIA:
## lo que contesta a «¿hay rio aqui al lado?». Lo preguntan quien busca
## orilla donde pescar -ver [Tajo._water_beside]- y quien busca el pasillo
## del cauce para explorarlo -ver [Reconocimiento._terrain_lure]-, y estaba
## escrito a mano en los dos.
const HAY_AGUA := 0.15

## El minimo por el que una celda cuenta como MOJADA para el trazado.
##
## Mas bajo que [HAY_AGUA] a proposito: aquello pregunta si se ve el rio y
## esto si la celda toca el cauce siquiera, que es cuando deja de poder
## cruzarse por donde sea. Ver [Navgrid.vado].
const ROZA_EL_AGUA := 0.05

## Anchura total, en metros, a la que un cauce deja de vadearse EN AGUAS
## MEDIAS. Estuvo en 9 y era demasiado restrictivo: gente que cruzaba Europa a
## pie no se paraba ante un rio de doce metros. Se vadea por las barras de
## grava y por los pasos anchos, que es donde el agua va somera.
const FORDABLE_WIDTH_M := 15.0

## Anchura a la que ya no lo salva ni un puente de troncos ni una piragua de
## la epoca: mar abierta y laminas grandes.
const UNBRIDGEABLE_WIDTH_M := 60.0

## Barridos de suavizado del perfil longitudinal de la lamina. El minimo local
## por seccion da un perfil escalonado, porque el MDT tiene ruido; esto lo
## convierte en una caida continua, que es como baja un rio.
const PROFILE_SMOOTHING_PASSES := 24

## Barridos de suavizado del TECHO de la lamina, antes de usarlo como tope.
## Sin esto el techo llega escalonado y sus escalones se copian a la ribera.
const FLOOR_SMOOTHING_PASSES := 10

## Celdas de ribera que se reperfilan por fuera de la lamina. Encajar el cauce
## deja un muro donde la orilla es empinada -la mascara cae en un par de celdas
## mientras el terreno puede bajar diez metros-, y la ribera es parte del rio:
## que la remodele es correcto, no un efecto colateral.
const BANK_REGRADE_CELLS := 5


## Escribe en `data` la máscara de lámina de agua y el campo de corriente.
##
## `channels` son cauces lineales {points (lon,lat), half_width_m, kind} y
## `bodies` láminas cerradas {points (lon,lat), kind}. Los cuerpos se pintan
## primero y los cauces encima, porque un río que entra en una laguna debe
## seguir teniendo corriente dentro de su propio canal.
static func apply(data: HeightmapData, channels: Array, bodies: Array) -> void:
	var w := data.width
	var h := data.height
	var n := w * h
	if n <= 0:
		return

	var mask := PackedFloat32Array()
	var flow_x := PackedFloat32Array()
	var flow_z := PackedFloat32Array()
	var ford := PackedFloat32Array()
	mask.resize(n)
	flow_x.resize(n)
	flow_z.resize(n)
	ford.resize(n)

	var mps: float = maxf(data.meters_per_sample, 0.001)

	# --- láminas quietas ---------------------------------------------------
	for entry: Variant in bodies:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var body: Dictionary = entry
		var cells := _to_cells(data, body.get("points", PackedVector2Array()))
		if cells.size() < 3:
			continue
		_fill_polygon(mask, w, h, cells)
		# Una lamina no tiene fondo que pisar: se cruza en barca o no se cruza.
		#
		# Justo por debajo de 1, no en 1: el tope reservado a lo que no cruza
		# NADIE es la mar abierta. Un lago es lo mas facil que hay de navegar,
		# y dejarlo en 1 significaba que la piragua no servia ni para eso.
		_fill_polygon(ford, w, h, cells, 0.95)

	# --- cauces con corriente ---------------------------------------------
	for entry: Variant in channels:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var channel: Dictionary = entry
		var cells := _to_cells(data, channel.get("points", PackedVector2Array()))
		if cells.size() < 2:
			continue

		var half_width_m: float = float(channel.get("half_width_m", 4.0))
		var radius: float = maxf(half_width_m / mps, 0.8)
		var difficulty := crossing_difficulty_for_width(half_width_m * 2.0)
		for i in range(cells.size() - 1):
			_stroke_channel(mask, flow_x, flow_z, ford, w, h,
				cells[i], cells[i + 1], radius, difficulty)

	# Normalizar la corriente: donde se cruzan dos tramos se han sumado dos
	# direcciones, y lo que interesa es el sentido, no cuántas veces se pasó
	for i in range(n):
		var length := sqrt(flow_x[i] * flow_x[i] + flow_z[i] * flow_z[i])
		if length > 0.0001:
			flow_x[i] /= length
			flow_z[i] /= length
		else:
			flow_x[i] = 0.0
			flow_z[i] = 0.0

	data.river_mask = mask
	data.flow_x = flow_x
	data.flow_z = flow_z
	data.ford_mask = ford

	_settle_water_surface(data, mask)


## Calcula la cota de la lamina y encaja el cauce en ella.
##
## El problema que resuelve: el agua se pinta sobre la propia malla del
## terreno, asi que sobre una ladera el "rio" subia con la ladera. Un rio real
## tiene la lamina horizontal de orilla a orilla y solo desciende aguas abajo.
##
## En vez de montar una malla de agua aparte -que obligaria a un segundo pase
## de render y a resolver su recorte contra la ribera-, se aplana el propio
## terreno dentro del cauce hasta la cota de lamina. La superficie del terreno
## ES la superficie del agua, y el shader ya sabe pintarla como tal.
static func _settle_water_surface(data: HeightmapData, mask: PackedFloat32Array) -> void:
	var w := data.width
	var h := data.height
	var n := w * h
	var elev := data.elevations
	if elev.size() != n:
		return

	var level := PackedFloat32Array()
	level.resize(n)

	var wet := PackedInt32Array()
	for i in range(n):
		if mask[i] > 0.001:
			wet.append(i)
	if wet.is_empty():
		data.water_level = level
		return

	# --- 1. Cota de partida: el fondo de cada seccion ---------------------
	# Se toma el MINIMO del entorno y no la cota de la celda: la lamina de una
	# seccion la fija su punto mas hondo, el thalweg, no la orilla.
	var radius := 3
	for i in wet:
		var x := i % w
		var z := i / w
		var lowest := elev[i]
		for dz in range(-radius, radius + 1):
			var nz := z + dz
			if nz < 0 or nz >= h:
				continue
			var row := nz * w
			for dx in range(-radius, radius + 1):
				var nx := x + dx
				if nx < 0 or nx >= w:
					continue
				var j := row + nx
				if mask[j] > 0.001:
					lowest = minf(lowest, elev[j])
		level[i] = lowest

	# El fondo de cada seccion es el techo de la lamina: sin el, suavizar la
	# subiria por encima del thalweg de su propia seccion y dejaria de estar a
	# nivel de orilla a orilla.
	#
	# Pero ese techo hay que SUAVIZARLO antes de usarlo. El minimo sobre un
	# disco de celdas mojadas da un valor escalonado cuando el cauce va en
	# diagonal -el disco entra y sale de celdas distintas a cada paso-, y
	# reimponer ese techo en cada pasada de suavizado clavaba las escaleras.
	# Eso era el peine que se veia en la ribera.
	var section_floor := PackedFloat32Array(level)
	for _pass in range(FLOOR_SMOOTHING_PASSES):
		var eased := PackedFloat32Array(section_floor)
		for i in wet:
			var fx := i % w
			var fz := i / w
			var fsum := section_floor[i]
			var fcount := 1.0
			for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(0, -1), Vector2i(0, 1)]:
				var nx := fx + offset.x
				var nz := fz + offset.y
				if nx < 0 or nz < 0 or nx >= w or nz >= h:
					continue
				var j := nz * w + nx
				if mask[j] > 0.001:
					fsum += section_floor[j]
					fcount += 1.0
			eased[i] = fsum / fcount
		section_floor = eased

	# --- 2. Perfil longitudinal continuo ----------------------------------
	# Media con los vecinos mojados, reclavando despues a que no supere el
	# fondo: suavizar sin ese tope subiria el agua por encima de la orilla.
	for _pass in range(PROFILE_SMOOTHING_PASSES):
		var updated := PackedFloat32Array(level)
		for i in wet:
			var x := i % w
			var z := i / w
			var sum := level[i]
			var count := 1.0
			for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(0, -1), Vector2i(0, 1)]:
				var nx := x + offset.x
				var nz := z + offset.y
				if nx < 0 or nz < 0 or nx >= w or nz >= h:
					continue
				var j := nz * w + nx
				if mask[j] > 0.001:
					sum += level[j]
					count += 1.0
			# Nunca por encima del fondo de su seccion
			updated[i] = minf(sum / count, section_floor[i])
		level = updated

	# --- 3. Encajar el cauce en la lamina ---------------------------------
	# El nucleo del cauce se pone EXACTAMENTE a la cota de lamina, sin mezclar
	# con el terreno: mezclando con la mascara cruda quedaba un resto de la
	# pendiente transversal y la lamina no salia a nivel.
	var core_low := 0.15
	var core_high := 0.80
	for i in wet:
		# El agua nunca queda por encima del fondo de su seccion: se encaja, no
		# se apoya encima. Se compara contra el fondo de la SECCION y no contra
		# la cota de la propia celda, porque si no la orilla -que esta mas
		# alta- se quedaria con una lamina mas alta que el eje del cauce, que
		# es justo el desnivel transversal que se quiere quitar.
		var surface: float = minf(level[i], section_floor[i])
		level[i] = surface
		var blend := smoothstep(core_low, core_high, clampf(mask[i], 0.0, 1.0))
		elev[i] = lerpf(elev[i], surface, blend)

	# --- 4. Reperfilar la ribera ------------------------------------------
	# Encajar el cauce deja un muro donde la orilla es empinada: la mascara cae
	# en un par de celdas mientras el terreno puede bajar diez metros. Se
	# relaja el anillo de ribera para que suba de forma continua desde el agua,
	# con la lamina como suelo -la orilla no puede quedar por debajo del rio-
	# y el terreno original como techo, que ahi no se rellena nada.
	var bank := PackedInt32Array()
	var bank_seen := PackedByteArray()
	bank_seen.resize(n)

	# Peso del reperfilado por celda. Es lo que evita los dientes de sierra:
	# antes el conjunto reperfilado tenia BORDE DURO -dentro se alisaba y fuera
	# no-, y como ese borde es dentado a resolucion de celda, el escalon
	# copiaba sus dientes. Ahora el efecto se desvanece hacia fuera, con lo que
	# en el ultimo anillo ya no hay nada que copiar.
	var bank_weight := PackedFloat32Array()
	bank_weight.resize(n)

	for i in wet:
		if mask[i] >= core_high:
			continue
		bank.append(i)
		bank_seen[i] = 1
		bank_weight[i] = 1.0

	var ceiling := PackedFloat32Array(elev)
	for ring in range(BANK_REGRADE_CELLS):
		var grown := PackedInt32Array()
		for i in bank:
			var x := i % w
			var z := i / w
			for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(0, -1), Vector2i(0, 1)]:
				var nx := x + offset.x
				var nz := z + offset.y
				if nx < 0 or nz < 0 or nx >= w or nz >= h:
					continue
				var j := nz * w + nx
				if bank_seen[j] != 0 or mask[j] >= core_high:
					continue
				bank_seen[j] = 1
				# Cae de forma continua hasta anularse justo fuera del ultimo
				# anillo, que es donde antes estaba el escalon
				bank_weight[j] = 1.0 - float(ring + 1) / float(BANK_REGRADE_CELLS + 1)
				grown.append(j)
		for j in grown:
			bank.append(j)

	for _pass in range(30):
		var updated := PackedFloat32Array(elev)
		for i in bank:
			var x := i % w
			var z := i / w
			var sum := 0.0
			var count := 0.0
			for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(0, -1), Vector2i(0, 1)]:
				var nx := x + offset.x
				var nz := z + offset.y
				if nx < 0 or nz < 0 or nx >= w or nz >= h:
					continue
				sum += elev[nz * w + nx]
				count += 1.0
			if count > 0.0:
				# Nunca por debajo de la lamina ni por encima del terreno que
				# habia: la ribera se alisa, no se inventa. El suelo es la
				# lamina de la celda si esta mojada, y si no, la del cauce mas
				# cercano, que es lo que evita que la ribera se hunda por
				# debajo del agua que tiene al lado.
				var floor_here: float = level[i] if mask[i] > 0.001 else -1e9
				var relaxed := clampf(sum / count, floor_here, ceiling[i])
				updated[i] = lerpf(elev[i], relaxed, bank_weight[i])
		elev = updated

	# La cota de lamina se propaga unas celdas hacia fuera. No es que ahi haya
	# agua: es para que quien mezcle terreno con lamina cerca de la orilla
	# tenga un valor continuo al que tirar. Sin esto, un vertice justo fuera
	# del cauce leia cero y su vecino de dentro leia la cota buena, y esa
	# alternancia era otra fuente de dientes de sierra.
	for _ring in range(3):
		var spread := PackedFloat32Array(level)
		for z in range(h):
			for x in range(w):
				var i := z * w + x
				if level[i] != 0.0:
					continue
				var sum := 0.0
				var count := 0.0
				for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0),
						Vector2i(0, -1), Vector2i(0, 1)]:
					var nx := x + offset.x
					var nz := z + offset.y
					if nx < 0 or nz < 0 or nx >= w or nz >= h:
						continue
					var value := level[nz * w + nx]
					if value != 0.0:
						sum += value
						count += 1.0
				if count > 0.0:
					spread[i] = sum / count
		level = spread

	data.elevations = elev
	data.water_level = level

	var lo := INF
	var hi := -INF
	for e in elev:
		lo = minf(lo, e)
		hi = maxf(hi, e)
	data.min_elevation = lo
	data.max_elevation = hi


## Dificultad de cruzar un cauce de la anchura total dada, en metros.
##
## Crece de forma continua y no a saltos: entre un arroyo y un rio no hay una
## frontera, hay un gradiente, y lo que cambia es donde caen los umbrales.
static func crossing_difficulty_for_width(width_m: float) -> float:
	if width_m <= 0.0:
		return 0.0
	# Hasta el ancho vadeable se reparte el tramo facil; a partir de ahi sube
	# hacia infranqueable y satura al llegar a lo que no salva ni un puente
	if width_m <= FORDABLE_WIDTH_M:
		return FORD_IMPASSABLE * (width_m / FORDABLE_WIDTH_M) * 0.98
	var over := (width_m - FORDABLE_WIDTH_M) / maxf(UNBRIDGEABLE_WIDTH_M - FORDABLE_WIDTH_M, 1.0)
	return minf(FORD_IMPASSABLE + (1.0 - FORD_IMPASSABLE) * clampf(over, 0.0, 1.0) + 0.01, 1.0)


## Peor punto de cruce a lo largo de un trayecto recto, en metros de mundo.
##
## Se queda con el PEOR y no con la media a proposito: cien metros de vado no
## compensan veinte de rio, porque lo que decide si se puede pasar es el punto
## mas dificil del camino.
static func worst_crossing(data: HeightmapData, from_m: Vector2, to_m: Vector2) -> float:
	if data.ford_mask.is_empty():
		return 0.0

	var size := data.get_world_size_meters()
	if size.x <= 0.0 or size.y <= 0.0:
		return 0.0

	# Un paso por celda: saltarse celdas seria saltarse el cauce
	var distance := from_m.distance_to(to_m)
	var steps := maxi(int(distance / maxf(data.meters_per_sample, 0.5)), 1)
	var worst := 0.0

	for s in range(steps + 1):
		var point := from_m.lerp(to_m, float(s) / float(steps))
		var x := clampi(int(round(clampf(point.x / size.x, 0.0, 1.0) * float(data.width - 1))),
			0, data.width - 1)
		var z := clampi(int(round(clampf(point.y / size.y, 0.0, 1.0) * float(data.height - 1))),
			0, data.height - 1)
		worst = maxf(worst, data.ford_mask[z * data.width + x])

	return worst


## Cuanto sube o baja la dificultad de vadeo segun la epoca del ano.
##
## Un rio no es una barrera fija. El mismo cauce que en marzo baja bravo con el
## deshielo, en agosto se pasa por las barras de grava con el agua por la
## rodilla. En la cornisa cantabrica el estiaje es de finales de verano y las
## avenidas de invierno, asi que ese es el orden.
static func seasonal_ford_modifier(season: Subsistence.Season) -> float:
	match season:
		Subsistence.Season.VERANO: return -0.13
		Subsistence.Season.OTONO: return -0.04
		Subsistence.Season.PRIMAVERA: return 0.05
		_: return 0.10


## Si una dificultad de cruce es salvable con los medios disponibles.
##
## `season` mueve el umbral: el mismo vado que no existe en febrero se cruza en
## agosto. Es lo que convierte al rio en una barrera ESTACIONAL, que es lo que
## de verdad era, en vez de en un muro permanente.
static func can_cross(difficulty: float, has_boat: bool, has_bridge: bool,
		season: int = -1) -> bool:
	var adjusted := difficulty
	if season >= 0:
		adjusted = clampf(
			difficulty + seasonal_ford_modifier(season as Subsistence.Season),
			0.0, 1.0)
		# La mar abierta no la abre ninguna estacion
		if difficulty >= 1.0:
			adjusted = 1.0

	var tope := tope_de_vado(has_boat, has_bridge)
	return adjusted < tope.x if tope.y > 0.5 else adjusted <= tope.x


## El tope de vado como NUMERO: hasta cuanto se pasa, y si la comparacion es
## estricta (`y` distinto de cero) o no.
##
## Es [can_cross] dicho al reves, y existe para poder catar una linea entera sin
## una llamada por punto: quien recorre una recta preguntando por el agua -ver
## [TerrainGenerator.linea_sin_agua]- pide el tope UNA vez y compara. La regla
## sigue viviendo aqui y en un solo sitio: `can_cross` sale de esta misma
## funcion.
##
## Sin barca ni puente se pasa hasta [FORD_IMPASSABLE] incluido. Con una de las
## dos se pasa cualquier cosa por debajo de 1,0 -mar abierta no, que ni la barca
## ni el puente de la epoca salvan cualquier anchura-, y eso incluye de sobra
## todo lo que ya pasaba sin ellas.
static func tope_de_vado(has_boat: bool, has_bridge: bool) -> Vector2:
	if has_boat or has_bridge:
		return Vector2(1.0, 1.0)
	return Vector2(FORD_IMPASSABLE, 0.0)


## Convierte una polilínea geográfica a coordenadas de celda.
static func _to_cells(data: HeightmapData, points: PackedVector2Array) -> PackedVector2Array:
	var cells := PackedVector2Array()
	for p: Vector2 in points:
		cells.append(Vector2(
			data.u_for_lon(p.x) * float(data.width - 1),
			data.v_for_lat(p.y) * float(data.height - 1)))
	return cells


## Pinta un tramo de cauce y le imprime su dirección de corriente.
##
## La lámina no se corta a hachazo en la orilla: dentro del radio vale 1 y en
## las últimas celdas cae suave, que es lo que hace que el borde no parezca
## recortado con tijeras.
static func _stroke_channel(mask: PackedFloat32Array,
		flow_x: PackedFloat32Array, flow_z: PackedFloat32Array,
		ford: PackedFloat32Array,
		w: int, h: int, a: Vector2, b: Vector2, radius: float,
		difficulty: float) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.0001:
		return

	var direction := delta / length
	var steps := maxi(int(length * 2.0), 1)
	var outer := radius + BANK_BLEND_CELLS
	var ri := int(ceil(outer))

	for s in range(steps + 1):
		var centre := a + delta * (float(s) / float(steps))
		var cx := int(round(centre.x))
		var cz := int(round(centre.y))
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
				var distance := sqrt(ox * ox + oz * oz)
				if distance > outer:
					continue

				var wetness := 1.0 - smoothstep(radius, outer, distance)
				var i := row + x
				if wetness > mask[i]:
					mask[i] = wetness
				# El obstaculo se aplica en el cauce, no en la orilla difuminada:
				# la ribera se pisa, el agua no
				if distance <= radius and difficulty > ford[i]:
					ford[i] = difficulty
				# La corriente se acumula con el peso de la lámina, para que en
				# una confluencia mande el brazo que más agua trae
				flow_x[i] += direction.x * wetness
				flow_z[i] += direction.y * wetness


## Relleno de polígono por barrido de líneas, regla par-impar.
static func _fill_polygon(mask: PackedFloat32Array, w: int, h: int,
		cells: PackedVector2Array, value: float = 1.0) -> void:
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
				mask[row + x] = value
			i += 2
