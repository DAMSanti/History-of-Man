@tool
class_name Erosion
extends RefCounted
## Erosión hidráulica y térmica sobre un heightmap.
##
## El ruido parece ruido. Se le puede ajustar la amplitud, la frecuencia y las
## octavas y sigue leyéndose como una manta de bultos, porque no hay ninguna
## relación entre un bulto y el de al lado. El terreno real no es aleatorio: es
## el residuo de un proceso, y por eso todo en él está relacionado —la vaguada
## desemboca en el arroyo, el arroyo pasa por el punto bajo, el cono de
## derrubios está al pie de la ladera que lo produjo.
##
## Simular el proceso, aunque sea toscamente, da esa coherencia gratis.
##
## Se usan los dos mecanismos que dominan a esta escala:
##
##  · HIDRÁULICA: gotas que caen, escurren ladera abajo, arrancan material
##    donde van rápidas y lo sueltan donde se frenan. Produce vaguadas que
##    convergen, cárcavas y conos de deyección. Es el modelo de partícula, que
##    es órdenes de magnitud más barato que resolver una capa de agua sobre
##    toda la rejilla, y a cambio da lo mismo visualmente.
##
##  · TÉRMICA: el material suelto no se sostiene por encima del ángulo de
##    reposo —unos 34° para derrubio calizo— y se derrumba. Es lo que convierte
##    las paredes verticales que deja el agua en canchales, y sin ella el
##    resultado se ve tallado a cuchillo.
##
## Las dos conservan materia: lo que se quita de un sitio aparece en otro. Es
## la propiedad que las separa de "meter más ruido", y está bajo prueba.

## Cuánto se lleva una gota por unidad de capacidad sobrante
const EROSION_RATE := 0.18

## Fracción máxima del desnivel que una gota puede llevarse de una vez.
##
## Sin este tope la gota se llevaba el escalón entero en cada paso: excavaba
## una zanja de una celda de ancho en la primera pasada y a partir de ahí todas
## las demás gotas caían en ella, con lo que salía un relieve de agujas en vez
## de un valle. La erosión es un proceso lento; dejarla ir a saco no la acelera,
## la rompe.
const MAX_BITE := 0.03

## Cuánto suelta de lo que lleva cuando se pasa de capacidad
const DEPOSITION_RATE := 0.28

## Rozamiento: fracción de velocidad que conserva la gota en cada paso
const FRICTION := 0.82

## Agua que se evapora por paso. Es lo que hace que una gota tenga recorrido
## finito y no baje el mapa entero.
##
## Con 0,018 hacian falta 215 pasos para agotarse, o sea que la condicion no se
## cumplia NUNCA dentro de los 64 pasos del tope: toda gota moria por limite de
## pasos y sin soltar su carga donde tocaba. Con 0,065 se agota sobre el paso
## 50, que es lo que hace que el cono de deyeccion aparezca donde debe.
const EVAPORATION := 0.065

## Capacidad de arrastre por unidad de pendiente y velocidad.
##
## Es la constante que decide si esto erosiona o desuella. Con 5,5 la capacidad
## era tan alta que la gota nunca llegaba a saturarse, o sea que NUNCA
## depositaba por el camino: bajaba arrancando hasta evaporarse, y sobre un
## cono de 120 m se llevaba 18 de media. Calibrada por medicion: con 0,8 se
## lleva 4,4 m de media -un 3,6% del relieve- y los surcos bajan hasta 17,6,
## que es la proporcion que hace que se vean vaguadas en vez de un cepillado.
const CAPACITY := 0.8

## Pasos máximos de una gota antes de darla por agotada. Es una red de
## seguridad: con la evaporación de arriba la gota se agota antes.
const MAX_STEPS := 56




## Erosión hidráulica por gotas. Modifica `grid` en el sitio.
##
## `drops` es cuántas gotas se sueltan; con una rejilla de 900×900, del orden
## de 200.000 da un resultado claro sin irse de tiempo.
static func hydraulic(grid: PackedFloat32Array, width: int, height: int,
		drops: int, seed_value: int = 0) -> void:
	if width < 3 or height < 3 or drops <= 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for drop in range(drops):
		# La gota nace en cualquier parte, en coordenadas continuas: si naciera
		# en el centro de una celda, todas seguirían los mismos surcos
		var px := rng.randf_range(1.0, float(width) - 2.0)
		var pz := rng.randf_range(1.0, float(height) - 2.0)
		var dx := 0.0
		var dz := 0.0
		var speed := 1.0
		var water := 1.0
		var carried := 0.0

		for step in range(MAX_STEPS):
			var cell_x := int(px)
			var cell_z := int(pz)
			if cell_x < 1 or cell_z < 1 or cell_x >= width - 2 or cell_z >= height - 2:
				break

			var offset_x := px - float(cell_x)
			var offset_z := pz - float(cell_z)

			var here := _bilinear(grid, width, px, pz)
			var gradient := _gradient(grid, width, cell_x, cell_z, offset_x, offset_z)

			# Inercia: la gota no gira en seco en cada celda, arrastra rumbo.
			# Sin esto los surcos salen en escalera siguiendo la rejilla.
			dx = dx * 0.75 - gradient.x * 0.25
			dz = dz * 0.75 - gradient.y * 0.25
			var length := sqrt(dx * dx + dz * dz)
			if length < 0.0001:
				break
			dx /= length
			dz /= length

			var next_x := px + dx
			var next_z := pz + dz
			if next_x < 1.0 or next_z < 1.0 \
					or next_x >= float(width) - 2.0 or next_z >= float(height) - 2.0:
				break

			var drop_height := here - _bilinear(grid, width, next_x, next_z)

			# Capacidad de arrastre: cuánto barro puede llevar el agua. Depende
			# de cuánto cae y de lo rápida que va, que es la física de esto.
			var capacity: float = maxf(drop_height, 0.01) * speed * water * CAPACITY

			if carried > capacity or drop_height < 0.0:
				# Se frena o sube: suelta. Si sube, no puede soltar más de lo
				# que hay de desnivel, o rellenaría el hoyo por encima del borde
				var release: float = (carried - capacity) * DEPOSITION_RATE
				if drop_height < 0.0:
					release = minf(carried, -drop_height)
				carried -= release
				_deposit(grid, width, height, cell_x, cell_z, offset_x, offset_z, release)
			else:
				# Acelera: arranca. Nunca más de lo que cae, o se excavaría un
				# pozo por debajo del punto al que va
				var taken: float = minf(
					(capacity - carried) * EROSION_RATE, drop_height * MAX_BITE)
				carried += taken
				_deposit(grid, width, height, cell_x, cell_z, offset_x, offset_z, -taken)

			# La velocidad se acota: sin tope, una gota que encadene desniveles
			# grandes se dispara, y con ella la capacidad de arrastre
			speed = clampf(
				sqrt(maxf(speed * speed * FRICTION + drop_height * 0.4, 0.0001)),
				0.0, 4.0)
			water *= 1.0 - EVAPORATION
			px = next_x
			pz = next_z

			if water < 0.02:
				# Al evaporarse suelta lo que llevaba: es el cono de deyección
				_deposit(grid, width, height, cell_x, cell_z, offset_x, offset_z, carried)
				carried = 0.0
				break

		# Lo que quede al agotarse la gota no se pierde: la materia se conserva
		if carried > 0.0:
			var last_x := clampi(int(px), 0, width - 2)
			var last_z := clampi(int(pz), 0, height - 2)
			_deposit(grid, width, height, last_x, last_z, 0.5, 0.5, carried)


## Erosión térmica: derrumba lo que pasa del ángulo de reposo.
##
## `cell_meters` es el lado de celda y `talus` la tangente del ángulo máximo
## que aguanta el material —0,6 son unos 31°, que es lo que se sostiene un
## canchal de caliza.
static func thermal(grid: PackedFloat32Array, width: int, height: int,
		passes: int, cell_meters: float, talus: float) -> void:
	if width < 3 or height < 3 or passes <= 0:
		return

	var max_step := talus * maxf(cell_meters, 0.001)

	for pass_index in range(passes):
		var delta := PackedFloat32Array()
		delta.resize(width * height)

		# Se recorre la rejilla ENTERA, borde incluido, y son los vecinos que
		# faltan los que se saltan. Antes se saltaba la celda del borde entera,
		# y el resultado era que la fila de fuera se quedaba con el escalon
		# vertical intacto mientras el interior ya era un talud perfecto: un
		# muro justo en el limite del recuadro.
		for z in range(height):
			for x in range(width):
				var i := z * width + x
				var here := grid[i]

				# Reparto proporcional al exceso de cada vecino: si se le diera
				# todo al vecino más bajo, el material bajaría en zigzag por la
				# rejilla en vez de abrirse en abanico
				var total_excess := 0.0
				var max_excess := 0.0
				var excesses := [0.0, 0.0, 0.0, 0.0]
				var neighbours := [
					i - 1 if x > 0 else -1,
					i + 1 if x < width - 1 else -1,
					i - width if z > 0 else -1,
					i + width if z < height - 1 else -1,
				]
				for n in range(4):
					if neighbours[n] < 0:
						continue
					var difference := here - grid[neighbours[n]]
					if difference > max_step:
						excesses[n] = difference - max_step
						total_excess += excesses[n]
						max_excess = maxf(max_excess, excesses[n])

				if total_excess <= 0.0:
					continue

				# Lo que baja la celda se calcula sobre el exceso MAYOR, no
				# sobre la suma. Con la suma, una celda rodeada de cuatro
				# vecinos bajos cedía cuatro veces su desnivel y se hundía por
				# debajo de todos ellos; a la pasada siguiente le tocaba al
				# vecino, y el conjunto oscilaba divergiendo hasta desbordar.
				#
				# Con el máximo y un factor de 0,5, la celda nunca puede bajar
				# más de la mitad de su mayor desnivel, así que ese desnivel no
				# puede invertirse y el proceso converge.
				var moved: float = max_excess * 0.5
				delta[i] -= moved
				for n in range(4):
					if neighbours[n] >= 0 and excesses[n] > 0.0:
						delta[neighbours[n]] += moved * (excesses[n] / total_excess)

		for i in range(grid.size()):
			grid[i] += delta[i]


## Erosiona a resolución reducida y devuelve al original solo la DIFERENCIA.
##
## Es la forma de que esto sea pagable. Las formas que produce la erosión
## —cárcavas, vaguadas, conos de deyección— viven a escala de decenas de
## metros, así que no hace falta calcularlas sobre celdas de cinco: sobre
## celdas de diez salen igual y cuesta la cuarta parte de celdas y la cuarta
## parte de gotas, o sea dieciséis veces menos trabajo.
##
## Y como lo que se devuelve es la diferencia y no el resultado, el detalle
## fino del MDT —que es dato medido de verdad— se conserva intacto: la erosión
## se SUMA a él en vez de sustituirlo por una versión suavizada.
##
## `factor` es cuántas celdas del original entran en una de trabajo.
static func erode_coarse(grid: PackedFloat32Array, width: int, height: int,
		drops: int, thermal_passes: int, cell_meters: float, talus: float,
		seed_value: int = 0, factor: int = 2) -> void:
	if factor <= 1:
		hydraulic(grid, width, height, drops, seed_value)
		thermal(grid, width, height, thermal_passes, cell_meters, talus)
		return

	var small_w := width / factor
	var small_h := height / factor
	if small_w < 8 or small_h < 8:
		return

	# --- reducir promediando el bloque ------------------------------------
	var small := PackedFloat32Array()
	small.resize(small_w * small_h)
	for z in range(small_h):
		for x in range(small_w):
			var sum := 0.0
			var count := 0.0
			for dz in range(factor):
				var sz := z * factor + dz
				if sz >= height:
					continue
				for dx in range(factor):
					var sx := x * factor + dx
					if sx >= width:
						continue
					sum += grid[sz * width + sx]
					count += 1.0
			small[z * small_w + x] = sum / maxf(count, 1.0)

	var before := PackedFloat32Array(small)

	# Las gotas se reparten entre menos celdas, asi que hacen falta menos para
	# la misma densidad por celda
	hydraulic(small, small_w, small_h, maxi(drops / (factor * factor), 1), seed_value)
	thermal(small, small_w, small_h, thermal_passes,
		cell_meters * float(factor), talus)

	# --- devolver la diferencia, interpolada ------------------------------
	for i in range(small.size()):
		before[i] = small[i] - before[i]

	for z in range(height):
		# Coordenada en la rejilla de trabajo, centrada en el bloque
		var fz: float = (float(z) + 0.5) / float(factor) - 0.5
		var z0 := clampi(int(floor(fz)), 0, small_h - 1)
		var z1 := mini(z0 + 1, small_h - 1)
		var tz: float = clampf(fz - float(z0), 0.0, 1.0)

		for x in range(width):
			var fx: float = (float(x) + 0.5) / float(factor) - 0.5
			var x0 := clampi(int(floor(fx)), 0, small_w - 1)
			var x1 := mini(x0 + 1, small_w - 1)
			var tx: float = clampf(fx - float(x0), 0.0, 1.0)

			var top := lerpf(before[z0 * small_w + x0], before[z0 * small_w + x1], tx)
			var bottom := lerpf(before[z1 * small_w + x0], before[z1 * small_w + x1], tx)
			grid[z * width + x] += lerpf(top, bottom, tz)


## Gradiente bilineal: la pendiente vista de forma continua, no por celdas.
## Si se tomara por celda, la gota bajaría en escalera siguiendo la rejilla.
static func _gradient(grid: PackedFloat32Array, width: int,
		x: int, z: int, u: float, v: float) -> Vector2:
	var i := z * width + x
	var h00 := grid[i]
	var h10 := grid[i + 1]
	var h01 := grid[i + width]
	var h11 := grid[i + width + 1]
	return Vector2(
		(h10 - h00) * (1.0 - v) + (h11 - h01) * v,
		(h01 - h00) * (1.0 - u) + (h11 - h10) * u)


static func _bilinear(grid: PackedFloat32Array, width: int, x: float, z: float) -> float:
	var cell_x := int(x)
	var cell_z := int(z)
	var u := x - float(cell_x)
	var v := z - float(cell_z)
	var i := cell_z * width + cell_x
	return grid[i] * (1.0 - u) * (1.0 - v) + grid[i + 1] * u * (1.0 - v) \
		+ grid[i + width] * (1.0 - u) * v + grid[i + width + 1] * u * v


## Reparte material entre las cuatro celdas que rodean al punto de la gota.
##
## Es el reparto bilineal: cada celda recibe según lo cerca que esté del punto
## EXACTO, no del centro de su celda. Depositar todo en una sola celda dejaría
## picos de un vértice, que es justo el ruido de alta frecuencia del que se
## venía huyendo.
##
## Está escrito sin bucles ni arrays a propósito. Se llama dos veces por paso
## de gota y una erosión de un recuadro son del orden de diez millones de
## pasos: la versión con dos `Array` temporales por llamada se pasaba cinco
## minutos solo reservando memoria.
static func _deposit(grid: PackedFloat32Array, width: int, height: int,
		x: int, z: int, u: float, v: float, amount: float) -> void:
	if absf(amount) < 1e-9:
		return
	# El llamante ya garantiza 1 <= x < width-2 y lo mismo en z, asi que las
	# cuatro celdas existen y no hace falta comprobar limites
	var i := z * width + x
	var iu := 1.0 - u
	var iv := 1.0 - v
	grid[i] += amount * iu * iv
	grid[i + 1] += amount * u * iv
	grid[i + width] += amount * iu * v
	grid[i + width + 1] += amount * u * v
