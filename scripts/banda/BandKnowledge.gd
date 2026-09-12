class_name BandKnowledge
extends RefCounted
## Lo que la banda sabe de su territorio, frente a lo que el territorio tiene.
##
## El punto de partida no es la ignorancia: una banda paleolítica sabe
## perfectamente que en los ríos hay peces y que los ciervos pastan en el
## llano. Ese saber es cultural y viene con ella. Lo que NO sabe al llegar a un
## valle nuevo es en qué remanso concreto, en qué collado, y en qué mes.
##
## Eso es lo que se aprende pisando, y es lo que convierte la exploración en
## una mecánica en vez de en un adorno: la banda no elige el mejor sitio del
## mapa, elige el mejor sitio QUE CONOCE, y por eso al principio trabaja de
## más para comer de menos.
##
## Ver [ResourceField], que es la otra mitad: aquello es lo que hay, esto lo
## que se cree que hay.

## Cuánto sube la familiaridad en una jornada completa de trabajo. Da unas
## quince jornadas para conocer un paraje a fondo, que a razón de una estación
## por temporada de trabajo es un par de años. Aprender un valle lleva tiempo.
const LEARN_RATE := 0.16

## Rendimiento que se le saca a un paraje del que no se sabe nada. No es cero:
## se sabe QUE hay peces en el río, así que algo se pesca aunque se pesque a
## ciegas. Lo que no se tiene es el sitio bueno ni el momento bueno.
##
## Estuvo en 0,28 y era demasiado. El problema no es este número solo: es que
## se multiplica con la destreza (~0,6), la estación (0,75 en primavera) y el
## agotamiento del paraje. Cuatro penalizaciones encadenadas dejaban la
## producción en el 12% de la nominal y la banda no llegaba ni a comer.
##
## A 0,5, conocer bien un paraje DOBLA lo que da —sigue siendo un incentivo
## fuerte para explorar— pero no conocerlo no mata de hambre.
const BLIND_YIELD := 0.50

## Lo que añade haber vivido ya esa temporada: saber que el salmón remonta
## AHORA y no dentro de dos meses.
const SEASON_BONUS := 0.25

## Familiaridad minima para que un paraje cuente como conocido y la banda pueda
## elegirlo. Por debajo de esto se ha pasado por ahi, pero no se sabe lo que da.
const KNOWN_ENOUGH := 0.30

## Familiaridad por actividad. Cada valor es una rejilla del tamaño del mundo.
var familiarity: Dictionary = {}

## Qué parte del terreno se ha llegado a VER, al margen de lo que se sepa de
## sus recursos. Se puede cruzar un valle entero sin aprender nada de su caza
## y aun así conocer el camino, y son cosas distintas: esto decide lo que se
## pinta en el mapa, y `familiarity` lo que rinde una jornada de trabajo.
var explored: PackedFloat32Array = PackedFloat32Array()

## Bocas de cueva ya encontradas, por celda. Una cueva no existe para el
## jugador hasta que alguien pasa lo bastante cerca como para verla.
var discovered_cells: Dictionary = {}

## Fracción del alcance de vista dentro de la cual se distingue una boca de
## cueva concreta. Ver el terreno de lejos no es lo mismo que reconocer en él
## un agujero de diez metros.
const CAVE_SIGHT_FRACTION := 0.55

## Temporadas ya vividas, por actividad: {activity: {season: true}}
var seasons_seen: Dictionary = {}

var width: int = 0
var height: int = 0
var world_size: Vector2 = Vector2.ZERO


# --- las veredas: los caminos que la banda ya sabe ------------------------
#
# Viven AQUI y no en `SettlementSim` porque son lo que la banda SABE, igual
# que la familiaridad con un tajo o las estaciones ya vividas. Estaban en
# `SettlementSim._route_cache` / `_route_order`, que es donde acaban las cosas
# cuando nadie decide de quien son. Ver docs/SISTEMAS.md §18.

## Las veredas guardadas, por clave de trayecto: {String: Vereda}.
var veredas: Dictionary = {}

## En que orden se aprendieron, para soltar la mas vieja al llegar al tope.
var _veredas_orden: Array[String] = []

## Cuantas veredas se recuerdan.
##
## Doscientas cubren de sobra los trayectos de una temporada; guardarlas todas
## seria pagar memoria por caminos que no se van a repetir nunca. Era
## `SettlementSim.ROUTE_CACHE_LIMIT` y se movio con la memoria.
const VEREDAS_QUE_SE_RECUERDAN := 200


## La vereda a ese trayecto, si se sabe Y SIRVE CON LA REJILLA DE HOY.
##
## Devuelve `null` si no hay, y tambien si la que hay se trazo con otro rio:
## ahi se descarta de verdad -se borra- en vez de dejarla ocupando sitio hasta
## que alguien avise. Ver [Vereda.sirve_en].
func vereda(clave: String, grid: Navgrid) -> Vereda:
	var guardada: Variant = veredas.get(clave, null)
	if guardada == null:
		return null
	var camino := guardada as Vereda
	if not camino.sirve_en(grid):
		_olvidar(clave)
		return null
	return camino


## Se aprende un camino, sellado con la rejilla que lo trazo.
func recordar_vereda(clave: String, camino: PackedVector3Array,
		grid: Navgrid) -> void:
	if not veredas.has(clave):
		_veredas_orden.append(clave)
	veredas[clave] = Vereda.de(camino, grid)
	while _veredas_orden.size() > VEREDAS_QUE_SE_RECUERDAN:
		_olvidar(_veredas_orden[0])


## Se olvidan todas. Lo llama quien cambie por donde se pasa.
##
## El sello de [Vereda] ya impide que una vereda de otra rejilla se ande, asi
## que esto no es lo que sostiene la regla: es la limpieza, para no arrastrar
## doscientas veredas muertas hasta que el tope las empuje.
func olvidar_veredas() -> void:
	veredas.clear()
	_veredas_orden.clear()


## Cuantas veredas hay guardadas. Es el tope que pide EPOCA_01 §10.1, frente 4.
func veredas_recordadas() -> int:
	return veredas.size()


func _olvidar(clave: String) -> void:
	veredas.erase(clave)
	_veredas_orden.erase(clave)


func setup(cells_x: int, cells_z: int, world_extent: Vector2) -> void:
	width = maxi(cells_x, 1)
	height = maxi(cells_z, 1)
	world_size = world_extent
	familiarity.clear()
	seasons_seen.clear()
	discovered_cells.clear()
	explored.resize(width * height)
	explored.fill(0.0)
	for activity in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var grid := PackedFloat32Array()
		grid.resize(width * height)
		familiarity[activity] = grid
		seasons_seen[activity] = {}


## Si la banda sabe siquiera que ese recurso existe.
##
## Siempre sí, y es deliberado: lo contrario sería una banda que descubre la
## pesca, y eso no es lo que pasa cuando un grupo humano llega a un valle. Se
## deja como método propio porque en eras posteriores habrá tecnologías que
## abran actividades nuevas, y entonces dejara de ser siempre cierto.
func knows_activity(_activity: Subsistence.Activity) -> bool:
	return true


func _cell_index(world_position: Vector3) -> int:
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return -1
	if world_position.x < 0.0 or world_position.z < 0.0 \
			or world_position.x > world_size.x or world_position.z > world_size.y:
		return -1
	var x := clampi(int(world_position.x / world_size.x * float(width)), 0, width - 1)
	var z := clampi(int(world_position.z / world_size.y * float(height)), 0, height - 1)
	return z * width + x


## Cuánto se ha visto de un punto del mapa, de 0 a 1.
func explored_at(world_position: Vector3) -> float:
	var i := _cell_index(world_position)
	if i < 0 or i >= explored.size():
		return 0.0
	return explored[i]


## Registra lo que se ve desde un punto, hasta `sight_range` metros.
##
## Lo visto se desvanece hacia el borde en vez de cortar en círculo: un borde
## duro se lee como un foco, y lo que se quiere decir es que de lejos se
## distingue peor. Y nunca baja: lo visto no se olvida, solo se afina al
## volver a pasar más cerca.
func see_from(world_position: Vector3, sight_range: float) -> void:
	if explored.is_empty() or world_size.x <= 0.0 or world_size.y <= 0.0:
		return
	if world_position.x < 0.0 or world_position.z < 0.0 			or world_position.x > world_size.x or world_position.z > world_size.y:
		return

	var cell_w := world_size.x / float(width)
	var cell_h := world_size.y / float(height)
	var reach_x := int(ceil(sight_range / maxf(cell_w, 0.001)))
	var reach_z := int(ceil(sight_range / maxf(cell_h, 0.001)))

	var cx := clampi(int(world_position.x / world_size.x * float(width)), 0, width - 1)
	var cz := clampi(int(world_position.z / world_size.y * float(height)), 0, height - 1)

	for dz in range(-reach_z, reach_z + 1):
		var z := cz + dz
		if z < 0 or z >= height:
			continue
		for dx in range(-reach_x, reach_x + 1):
			var x := cx + dx
			if x < 0 or x >= width:
				continue

			var centre := Vector2(
				(float(x) + 0.5) * cell_w, (float(z) + 0.5) * cell_h)
			var distance := centre.distance_to(
				Vector2(world_position.x, world_position.z))
			if distance > sight_range:
				continue

			# La distancia util es al punto MAS CERCANO de la celda, no a su
			# centro. Con celdas de cien metros, el centro de aquella en la que
			# uno esta parado puede quedar a setenta, y entonces el sitio donde
			# se esta de pie salia a medio ver.
			var half_diagonal := Vector2(cell_w, cell_h).length() * 0.5
			var reach := maxf(distance - half_diagonal, 0.0)
			var clarity := 1.0 - (reach / sight_range) * 0.65
			var i := z * width + x
			if clarity > explored[i]:
				explored[i] = clarity

			# La boca de la cueva solo se distingue de cerca
			if reach <= sight_range * CAVE_SIGHT_FRACTION:
				discovered_cells[i] = true


## Si en esa celda ya se ha encontrado lo que hubiera que encontrar.
func is_discovered(world_position: Vector3) -> bool:
	var i := _cell_index(world_position)
	if i < 0:
		return false
	return discovered_cells.get(i, false)


## Cuánto se conoce un paraje para una actividad, de 0 a 1.
func familiarity_at(activity: Subsistence.Activity, world_position: Vector3) -> float:
	var i := _cell_index(world_position)
	if i < 0 or not familiarity.has(activity):
		return 0.0
	return (familiarity[activity] as PackedFloat32Array)[i]


## Registra tiempo pasado en un paraje. `intensity` va de 0 a 1: una jornada
## entera de trabajo vale 1, pasar de camino vale mucho menos, porque se ve el
## terreno pero no se prueba lo que da.
func observe(activity: Subsistence.Activity, world_position: Vector3,
		intensity: float) -> void:
	var i := _cell_index(world_position)
	if i < 0 or not familiarity.has(activity):
		return

	var grid: PackedFloat32Array = familiarity[activity]
	# Se acerca a 1 de forma asintótica: las primeras jornadas en un sitio
	# nuevo enseñan mucho y las siguientes cada vez menos, que es como
	# funciona conocer un terreno.
	var gain := LEARN_RATE * clampf(intensity, 0.0, 1.0)
	grid[i] = clampf(grid[i] + (1.0 - grid[i]) * gain, 0.0, 1.0)
	familiarity[activity] = grid


## Fuerza la familiaridad de un punto a un nivel, sin la atenuación
## asintótica de [observe].
##
## Son dos cosas distintas y no una: `observe` modela hacerse bueno
## explotando un sitio al que se vuelve una y otra vez -sube poco a poco,
## y por diseño-, pero DESCUBRIR que aquí hay un buen sitio es un hallazgo
## de una tarde, no una curva de aprendizaje. Una batida, una expedición o
## una ascensión que reconoce terreno nuevo tiene que poder bautizarlo esa
## misma jornada si de verdad hay algo, y con solo `observe` -que no pasa
## de 0,16 de golpe ni acumulando toda la intensidad posible en una
## visita- ningún paraje lejano llegaba nunca al umbral de nombrarse.
func reveal(activity: Subsistence.Activity, world_position: Vector3, level: float) -> void:
	var i := _cell_index(world_position)
	if i < 0 or not familiarity.has(activity):
		return
	var grid: PackedFloat32Array = familiarity[activity]
	grid[i] = maxf(grid[i], clampf(level, 0.0, 1.0))
	familiarity[activity] = grid


## Qué parte del valle se lleva vista, de 0 a 1.
##
## La niebla, no la familiaridad: es «cuánto mapa hay abierto», que es lo que
## mide si a la banda le queda comarca por reconocer. Lo usa [Reparto] para
## decidir si hace falta salir de expedición. Ver `_speciality_pressure`.
func explored_fraction() -> float:
	if explored.is_empty():
		return 1.0
	var suma := 0.0
	for value: float in explored:
		suma += value
	return clampf(suma / float(explored.size()), 0.0, 1.0)


## Lo mismo, pero sólo en la vuelta que de verdad se pisa.
##
## La media del mapa entero incluye rincones a los que la banda no va a ir
## nunca, así que se queda pegada a cero para siempre. Medida en un radio, dice
## lo que se quiere saber: si a esta banda le queda comarca que reconocer.
func explored_fraction_near(centre: Vector3, radius: float) -> float:
	if explored.is_empty() or width <= 0 or height <= 0:
		return 1.0
	var cell_w := world_size.x / float(width)
	var cell_h := world_size.y / float(height)
	var suma := 0.0
	var cuantas := 0
	for z in range(height):
		for x in range(width):
			var punto := Vector2((float(x) + 0.5) * cell_w,
				(float(z) + 0.5) * cell_h)
			if punto.distance_to(Vector2(centre.x, centre.z)) > radius:
				continue
			suma += explored[z * width + x]
			cuantas += 1
	if cuantas <= 0:
		return 1.0
	return clampf(suma / float(cuantas), 0.0, 1.0)


## Cuánto se aprende del borde de lo batido, respecto al centro.
##
## Poco más de la mitad. Reconocer un trozo de monte no es conocerlo por igual:
## por el medio se pasa y se rebusca, y el borde se ve de lejos. Con esto, sólo
## la mitad interior de lo batido llega al listón de bautizar un sitio
## —[Parajes.NAMED_AT]—, y la orla queda en «visto», que es lo que de verdad
## pasa. Pendiente de playtest.
const SE_APRENDE_MENOS_LEJOS := 0.55


## Revela TODO lo batido, no la celda que se pisa. Devuelve cuántas se tocaron.
##
## Es el fallo que dejaba el valle en blanco para siempre. [reveal] y [observe]
## tocan UNA celda —la de debajo de los pies— y las celdas de conocimiento miden
## sesenta y cuatro metros, así que una jornada entera batiendo un círculo de
## doscientos sesenta de radio revelaba un cuadrado de sesenta y cuatro.
##
## Medido con `HallazgoProbe`, treinta jornadas con dos exploradores: la banda
## conocía VEINTISÉIS celdas de cuatro mil noventa y seis, con la familiaridad
## media del valle en 0,004. Y como sólo se puede bautizar un sitio donde se
## conoce, no nacía ni un paraje nuevo después del primer día: las pocas celdas
## sabidas caían todas dentro de un paraje que ya existía.
##
## Un valle no se aprende pisando cada cuadrado: se aprende MIRÁNDOLO. Se sube
## al alto de al lado, se baja al arroyo, y al final de la tarde se sabe dónde
## hay avellanos en toda la vuelta. Es lo mismo que ya hacía
## [Cumbres._reveal_from_summit] desde una cima, con menos alcance.
##
## Sólo lo que se ha VISTO: la niebla manda, y lo que no se ha llegado a ver no
## se aprende por mucho que se pase cerca.
func reveal_around(activity: Subsistence.Activity, centre: Vector3,
		radius: float, level: float) -> int:
	if not familiarity.has(activity) or width <= 0 or height <= 0:
		return 0
	var cell_w := world_size.x / float(width)
	var cell_h := world_size.y / float(height)
	var reach_x := int(ceil(radius / maxf(cell_w, 0.001)))
	var reach_z := int(ceil(radius / maxf(cell_h, 0.001)))
	var cx := clampi(int(centre.x / world_size.x * float(width)), 0, width - 1)
	var cz := clampi(int(centre.z / world_size.y * float(height)), 0, height - 1)

	var grid: PackedFloat32Array = familiarity[activity]
	var tocadas := 0
	for dz in range(-reach_z, reach_z + 1):
		var z := cz + dz
		if z < 0 or z >= height:
			continue
		for dx in range(-reach_x, reach_x + 1):
			var x := cx + dx
			if x < 0 or x >= width:
				continue
			var punto := Vector3((float(x) + 0.5) * cell_w, 0.0,
				(float(z) + 0.5) * cell_h)
			var lejos := Vector2(punto.x - centre.x, punto.z - centre.z).length()
			if lejos > radius:
				continue
			if explored_at(punto) <= 0.0:
				continue
			var cuanto := level * lerpf(1.0, SE_APRENDE_MENOS_LEJOS,
				clampf(lejos / maxf(radius, 1.0), 0.0, 1.0))
			var i := z * width + x
			if cuanto > grid[i]:
				grid[i] = clampf(cuanto, 0.0, 1.0)
			tocadas += 1
	familiarity[activity] = grid
	return tocadas


## Anota que la banda ya ha vivido esa temporada para esa actividad.
func record_season(activity: Subsistence.Activity, season: Subsistence.Season) -> void:
	if not seasons_seen.has(activity):
		seasons_seen[activity] = {}
	var seen: Dictionary = seasons_seen[activity]
	seen[season] = true
	seasons_seen[activity] = seen


func knows_season(activity: Subsistence.Activity, season: Subsistence.Season) -> bool:
	if not seasons_seen.has(activity):
		return false
	return (seasons_seen[activity] as Dictionary).has(season)


## Fracción del recurso que la banda es capaz de aprovechar en esta temporada.
func efficiency(activity: Subsistence.Activity, season: Subsistence.Season) -> float:
	var base := 1.0
	if knows_season(activity, season):
		base += SEASON_BONUS
	return base


## Lo que la banda REALMENTE saca de un paraje: lo que hay, filtrado por lo que
## sabe. Un cotarro estupendo que no conoce apenas le rinde.
func believed_abundance(field: ResourceField, activity: Subsistence.Activity,
		world_position: Vector3, season: Subsistence.Season) -> float:
	var real := field.seasonal_abundance_at(activity, world_position, season)
	var known := familiarity_at(activity, world_position)
	# De BLIND_YIELD a 1 según se conoce el sitio: nunca cero, porque se sabe
	# que el recurso existe, pero tampoco todo, porque no se sabe dónde
	return real * lerpf(BLIND_YIELD, 1.0, known)


## El mejor sitio que la banda CONOCE para una actividad y temporada.
##
## Es el método que hace que la exploración importe: no devuelve el mejor
## paraje del mapa, devuelve el mejor de los que ha pisado. Al principio eso
## significa irse al sitio mediocre de al lado teniendo el bueno a dos valles.
func best_known_site(field: ResourceField, activity: Subsistence.Activity,
		season: Subsistence.Season) -> Vector3:
	var best := Vector3.ZERO
	var best_score := -1.0

	for z in range(field.height):
		for x in range(field.width):
			var centre := field.cell_center(x, z)

			# Solo se puede elegir lo que se CONOCE. Es la diferencia entre
			# este metodo y `believed_abundance`: aquel dice lo que se saca de
			# un sitio -y de uno desconocido se saca algo, porque se sabe que
			# en el rio hay peces-, y este dice adonde iria la banda.
			#
			# Sin este corte, un paraje excelente que nadie ha pisado le ganaba
			# a uno mediocre bien conocido, y entonces explorar no servia de
			# nada: la banda ya se iba sola a lo bueno sin haberlo visto.
			if familiarity_at(activity, centre) < KNOWN_ENOUGH:
				continue

			var score := believed_abundance(field, activity, centre, season)
			if score > best_score:
				best_score = score
				best = centre

	return best
