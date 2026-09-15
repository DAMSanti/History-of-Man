@tool
class_name RegionBoundary
extends Resource
## Frontera administrativa en coordenadas geograficas, para delimitar la zona
## jugable sobre el mapa regional.
##
## El DEM se importa por recuadros de teselas, que nunca coinciden con una
## frontera real: el recuadro de Cantabria se come trozos de Asturias, Leon,
## Palencia, Burgos y Vizcaya, y ademas hay que extenderlo mar adentro para que
## quepa la linea de costa glacial. Esta clase separa "lo que hay en el DEM" de
## "lo que es Cantabria".
##
## Los puntos van como Vector2(x = longitud, y = latitud), en grados.

@export var region_name: String = ""
@export var source: String = ""

## Anillos del poligono. El primero es el contorno principal; los demas son
## islas o enclaves — Cantabria tiene uno real, el Valle de Villaverde.
@export var rings: Array[PackedVector2Array] = []

@export var lon_min: float = 0.0
@export var lon_max: float = 0.0
@export var lat_min: float = 0.0
@export var lat_max: float = 0.0


## Carga la frontera desde el volcado JSON generado a partir de OpenStreetMap
static func from_json(path: String) -> RegionBoundary:
	if not FileAccess.file_exists(path):
		push_error("RegionBoundary: no existe " + path)
		return null

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RegionBoundary: JSON invalido en " + path)
		return null

	var boundary := RegionBoundary.new()
	boundary.region_name = parsed.get("name", "")
	boundary.source = parsed.get("source", "")
	boundary.lon_min = parsed.get("lon_min", 0.0)
	boundary.lon_max = parsed.get("lon_max", 0.0)
	boundary.lat_min = parsed.get("lat_min", 0.0)
	boundary.lat_max = parsed.get("lat_max", 0.0)

	for flat: Array in parsed.get("rings", []):
		var ring := PackedVector2Array()
		ring.resize(flat.size() / 2)
		for i in range(ring.size()):
			ring[i] = Vector2(flat[i * 2], flat[i * 2 + 1])
		boundary.rings.append(ring)

	return boundary


## Numero total de vertices, sumando todos los anillos
func point_count() -> int:
	var total := 0
	for ring in rings:
		total += ring.size()
	return total


## Rasteriza la frontera sobre la rejilla de un heightmap.
## Devuelve 1.0 dentro de la region y 0.0 fuera, con el borde suavizado.
##
## Se hace por barrido de lineas y no punto a punto porque comprobar un millon
## de vertices contra 630 aristas seria inviable: aqui es una pasada por fila.
## La latitud de cada fila se interpola en Y de MERCATOR, no en grados, porque
## asi es como esta muestreado el DEM.
func rasterize(data: HeightmapData, feather_cells: int = 2) -> PackedFloat32Array:
	var w := data.width
	var h := data.height
	var mask := PackedFloat32Array()
	mask.resize(w * h)

	if rings.is_empty() or w <= 0 or h <= 0:
		return mask

	var merc_north := DEMImporter.mercator_y(data.lat_north)
	var merc_south := DEMImporter.mercator_y(data.lat_south)
	var lon_span := data.lon_east - data.lon_west
	if absf(lon_span) < 1e-9:
		return mask

	var crossings := PackedFloat32Array()

	for z in range(h):
		var v := float(z) / float(maxi(h - 1, 1))
		var lat := DEMImporter.tile_y_to_lat(lerpf(merc_north, merc_south, v), 0)

		crossings.clear()
		for ring: PackedVector2Array in rings:
			var count := ring.size()
			for i in range(count):
				var a := ring[i]
				var b := ring[(i + 1) % count]
				# La arista cruza esta latitud
				if (a.y > lat) != (b.y > lat):
					var t := (lat - a.y) / (b.y - a.y)
					crossings.append(a.x + t * (b.x - a.x))

		if crossings.is_empty():
			continue

		var sorted := Array(crossings)
		sorted.sort()

		var row := z * w
		# Regla par-impar: se rellena entre pares consecutivos de cruces
		var pair := 0
		while pair + 1 < sorted.size():
			var lon_a: float = sorted[pair]
			var lon_b: float = sorted[pair + 1]
			var x0 := int(ceil((lon_a - data.lon_west) / lon_span * float(w - 1)))
			var x1 := int(floor((lon_b - data.lon_west) / lon_span * float(w - 1)))
			for x in range(maxi(x0, 0), mini(x1, w - 1) + 1):
				mask[row + x] = 1.0
			pair += 2

	if feather_cells > 0:
		mask = _feather(mask, w, h, feather_cells)

	return mask


## Suaviza el borde para que la transicion no quede en escalera
func _feather(mask: PackedFloat32Array, w: int, h: int, radius: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var window := float(radius * 2 + 1)

	for z in range(h):
		var row := z * w
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += mask[row + clampi(x, 0, w - 1)]
		for x in range(w):
			tmp[row + x] = acc / window
			acc -= mask[row + clampi(x - radius, 0, w - 1)]
			acc += mask[row + clampi(x + radius + 1, 0, w - 1)]

	for x in range(w):
		var acc := 0.0
		for z in range(-radius, radius + 1):
			acc += tmp[clampi(z, 0, h - 1) * w + x]
		for z in range(h):
			out[z * w + x] = acc / window
			acc -= tmp[clampi(z - radius, 0, h - 1) * w + x]
			acc += tmp[clampi(z + radius + 1, 0, h - 1) * w + x]

	return out


## Construye la mascara de area jugable para una cota del mar concreta.
##
## La frontera NO es fija: el territorio de cada epoca es Cantabria mas la
## tierra que este emergida entonces. Con el mar actual no emerge nada y la
## mascara es exactamente la frontera administrativa.
##
## El crecimiento es una inundacion por vecindad sobre el fondo marino que
## emerge, no una proyeccion recta: asi el contorno lo dibuja la batimetria y
## sale con la forma quebrada de una costa real.
##
## **HASTA EL AGUA** desde el 2026-09-13. Había un tope de 60 km de alcance, con
## ruido para que el borde no saliera en arco, y a −120 m la línea amarilla se
## paraba antes de llegar a la costa de la época: el usuario la vio a medio
## camino en el mapa regional. Ahora la inundación sigue mientras haya fondo
## marino emergido, y el borde lo pone el mar. **Los límites laterales se
## quedan** —la costa de Cantabria, medida en la costa—: sin ellos la plataforma
## se extendería por delante de Asturias y del País Vasco.
func build_playable_mask(data: HeightmapData, sea_level_m: float) -> PackedFloat32Array:
	var mask := rasterize(data)
	var w := data.width
	var h := data.height
	var n := w * h

	if sea_level_m >= 0.0:
		return mask

	# --- 1. cerrar la costura con la costa -----------------------------
	# El poligono administrativo y la isobata 0 del DEM no coinciden a 111 m
	# por muestra, asi que entre ambos queda un anillo de celdas con cota
	# positiva que no pertenece a ninguno de los dos. Sin cerrarlo aparece una
	# segunda frontera en vez de una ampliada.
	_dilate_shoreline(mask, data, 4, 30.0)

	# --- 2. limites laterales, medidos en la COSTA ---------------------
	# No sirve el lon_min del poligono: el punto mas occidental de Cantabria
	# esta tierra adentro, en Liebana, y usarlo hace que la plataforma se
	# extienda por delante de Asturias.
	var coast := _coastal_x_range(mask, data)
	var x_min: int = coast.x
	var x_max: int = coast.y
	if x_max <= x_min:
		return mask
	var limites := _limites_por_fila(mask, coast, w, h)

	# --- 3. inundacion hasta el agua ------------------------------------
	# Por vecindad sobre el fondo marino que emerge, sin tope de distancia: el
	# contorno lo dibuja la batimetria, que ya sale quebrado como una costa real.
	var dist := PackedInt32Array()
	dist.resize(n)
	var queue := PackedInt32Array()
	for i in range(n):
		if mask[i] > 0.5:
			dist[i] = 0
			queue.append(i)
		else:
			dist[i] = -1

	var head := 0
	var added := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var d := dist[i]
		var x := i % w
		var z := i / w

		for dz: int in [-1, 0, 1]:
			var zz := z + dz
			if zz < 0 or zz >= h:
				continue
			for dx: int in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var xx := x + dx
				var limite: Vector2i = limites[zz]
				if xx < limite.x or xx > limite.y:
					continue
				var j := zz * w + xx
				if dist[j] != -1:
					continue
				# Solo fondo marino que emerge a esta cota
				var e: float = data.elevations[j]
				if e <= sea_level_m or e > 0.0:
					continue
				dist[j] = d + 1
				mask[j] = 1.0
				queue.append(j)
				added += 1

	# Cierre morfologico: dilatar y volver a erosionar. Cierra la costura entre
	# la tierra y la plataforma sin cambiar la silueta. Hace falta porque la
	# costa cantabrica tiene acantilados de mas de 30 m justo fuera del poligono
	# que el ensanchado litoral no alcanza, y quedaban como un anillo huerfano
	# que se dibujaba como una segunda frontera.
	_close_gaps(mask, w, h, 5)

	# Rellenar huecos cerrados. Los islotes y roquedos tienen cota POSITIVA, asi
	# que la inundacion los salta -solo admite fondo marino que emerge- y quedan
	# como agujeros rodeados de territorio. Si el fondo alrededor esta seco, el
	# islote tambien lo esta. Se rellena por conectividad y no por tamano, para
	# que valga sea cual sea la razon del hueco.
	var filled := _fill_holes(mask, w, h)

	print("RegionBoundary: %d celdas de islote o hueco interior rellenadas" % filled)
	print("RegionBoundary: mar %+.0f m -> %d celdas emergidas, costa entre las columnas %d y %d" % [
		sea_level_m, added, x_min, x_max])
	return mask


## Dilata y erosiona la misma cantidad: cierra huecos y costuras estrechas
## dejando el contorno exterior donde estaba.
func _close_gaps(mask: PackedFloat32Array, w: int, h: int, radius: int) -> void:
	for step in range(radius):
		var grow: Array[int] = []
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				if mask[i] > 0.5:
					continue
				if mask[i - 1] > 0.5 or mask[i + 1] > 0.5 or mask[i - w] > 0.5 or mask[i + w] > 0.5:
					grow.append(i)
		for i: int in grow:
			mask[i] = 1.0

	for step in range(radius):
		var shrink: Array[int] = []
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				if mask[i] <= 0.5:
					continue
				if mask[i - 1] <= 0.5 or mask[i + 1] <= 0.5 or mask[i - w] <= 0.5 or mask[i + w] <= 0.5:
					shrink.append(i)
		for i: int in shrink:
			mask[i] = 0.0


## Ensancha la mascara unas celdas sobre la franja litoral, para que el borde
## del poligono administrativo y la isobata 0 del DEM se solapen.
func _dilate_shoreline(mask: PackedFloat32Array, data: HeightmapData, passes: int, max_elev: float) -> void:
	var w := data.width
	var h := data.height
	for pass_index in range(passes):
		var grow: Array[int] = []
		for z in range(1, h - 1):
			var row := z * w
			for x in range(1, w - 1):
				var i := row + x
				if mask[i] > 0.5 or data.elevations[i] > max_elev:
					continue
				if mask[i - 1] > 0.5 or mask[i + 1] > 0.5 						or mask[i - w] > 0.5 or mask[i + w] > 0.5:
					grow.append(i)
		for i: int in grow:
			mask[i] = 1.0


## LOS LÍMITES LATERALES DE LA PLATAFORMA, fila a fila, en columnas.
##
## Eran las dos columnas de [_coastal_x_range] tal cual, y hacia el norte la
## frontera salía como dos reglas: «vamos a hacerla algo fractal y no
## completamente recta, como una frontera moderna», petición del usuario del
## 2026-09-14. Cada lado se desplaza con un ruido fractal propio —varias octavas,
## así que quiebra a lo grande y a lo pequeño, como una raya que sigue arroyos y
## cordales— y el desplazamiento CRECE desde la costa de hoy: en la línea de
## costa vale cero, para que la frontera nueva empalme con la administrativa sin
## escalón, y a [QUIEBRO_FILAS] filas mar adentro ya quiebra entero.
##
## Semilla fija: la frontera es la misma en cada partida y en cada horneado.
func _limites_por_fila(mask: PackedFloat32Array, coast: Vector2i, w: int,
		h: int) -> Array[Vector2i]:
	var ruido := FastNoiseLite.new()
	ruido.seed = 20260914
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ruido.fractal_type = FastNoiseLite.FRACTAL_FBM
	ruido.fractal_octaves = 5
	ruido.frequency = QUIEBRO_FRECUENCIA
	var costa_izq := _primera_fila_de_tierra(mask, coast.x, w, h)
	var costa_der := _primera_fila_de_tierra(mask, coast.y, w, h)
	var limites: Array[Vector2i] = []
	limites.resize(h)
	for z in range(h):
		var sube_izq := clampf(float(costa_izq - z) / QUIEBRO_FILAS, 0.0, 1.0)
		var sube_der := clampf(float(costa_der - z) / QUIEBRO_FILAS, 0.0, 1.0)
		var izq := coast.x + roundi(ruido.get_noise_2d(float(z), 0.0)
			* QUIEBRO_COLUMNAS * sube_izq)
		var der := coast.y + roundi(ruido.get_noise_2d(float(z), 5000.0)
			* QUIEBRO_COLUMNAS * sube_der)
		limites[z] = Vector2i(clampi(izq, 0, w - 1), clampi(der, 0, w - 1))
	return limites


## Cuánto se aparta cada lado de la frontera de su columna, como mucho, en
## columnas del relieve (unos 111 m cada una). Decisión de dibujo, no de
## geografía: lo bastante para que se lea quebrada a la escala del mapa, y no
## tanto como para meterse de verdad delante de Asturias o del País Vasco.
const QUIEBRO_COLUMNAS := 22.0

## Cada cuántas filas cambia de rumbo la octava gorda del quiebro.
const QUIEBRO_FRECUENCIA := 0.035

## En cuántas filas desde la costa de hoy crece el quiebro de cero a entero.
const QUIEBRO_FILAS := 18.0


## La fila más al norte con territorio en una columna: donde esa columna toca la
## costa. `h` si no hay ninguna.
func _primera_fila_de_tierra(mask: PackedFloat32Array, x: int, w: int, h: int) -> int:
	for z in range(h):
		if mask[z * w + x] > 0.5:
			return z
	return h


## Los límites laterales con que se construye la máscara a una cota: la MISMA
## cuenta que [build_playable_mask], para quien tenga que comprobarla.
func limites_por_fila(data: HeightmapData) -> Array[Vector2i]:
	var mask := rasterize(data)
	_dilate_shoreline(mask, data, 4, 30.0)
	return _limites_por_fila(mask, _coastal_x_range(mask, data), data.width,
		data.height)


## Rango de columnas donde la region toca el mar
func _coastal_x_range(mask: PackedFloat32Array, data: HeightmapData) -> Vector2i:
	var w := data.width
	var h := data.height
	var lo := w
	var hi := -1
	for z in range(1, h - 1):
		var row := z * w
		for x in range(1, w - 1):
			var i := row + x
			if mask[i] <= 0.5:
				continue
			if data.elevations[i - 1] <= 0.0 or data.elevations[i + 1] <= 0.0 					or data.elevations[i - w] <= 0.0 or data.elevations[i + w] <= 0.0:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	return Vector2i(lo, hi)


## Rellena todo hueco que no conecte con el exterior del mapa.
##
## Se inunda el EXTERIOR desde los bordes sobre las celdas que no son region;
## lo que la inundacion no alcanza esta encerrado y por tanto es un hueco.
## Devuelve cuantas celdas se han rellenado.
func _fill_holes(mask: PackedFloat32Array, w: int, h: int) -> int:
	var n := w * h
	var outside := PackedByteArray()
	outside.resize(n)
	var queue := PackedInt32Array()

	for x in range(w):
		for z: int in [0, h - 1]:
			var i := z * w + x
			if mask[i] <= 0.5 and outside[i] == 0:
				outside[i] = 1
				queue.append(i)
	for z in range(h):
		for x: int in [0, w - 1]:
			var i := z * w + x
			if mask[i] <= 0.5 and outside[i] == 0:
				outside[i] = 1
				queue.append(i)

	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var x := i % w
		var z := i / w
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var xx := x + step.x
			var zz := z + step.y
			if xx < 0 or zz < 0 or xx >= w or zz >= h:
				continue
			var j := zz * w + xx
			if outside[j] == 1 or mask[j] > 0.5:
				continue
			outside[j] = 1
			queue.append(j)

	var filled := 0
	for i in range(n):
		if mask[i] <= 0.5 and outside[i] == 0:
			mask[i] = 1.0
			filled += 1
	return filled
