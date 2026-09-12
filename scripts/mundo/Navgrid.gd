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

## Los puntos que se miran de cada celda: las nueve de un tablero de tres en
## raya, ESQUINAS INCLUIDAS.
##
## Con una sola muestra en el centro, un río que pasa entre dos centros es
## invisible y la gente sale a cruzarlo; y un barranco más estrecho que la celda
## no existe, que es por lo que tiraban por él.
##
## Eran cinco y estaban todas DENTRO —a ±0,34 de celda—, o sea que cubrían el
## cuadrado interior y dejaban sin mirar el borde y las cuatro esquinas. Y las
## esquinas es justo donde acaba la gente: medido en el sitio 56, la rejilla
## daba por pisables puntos de pendiente 1,85 con el límite de escalada en 1,20,
## y quien llegaba allí se quedaba empujando la pared hasta que la noche lo
## mandaba a casa. El caso concreto que lo destapó fue una cuadrilla de caza
## menor plantada día tras día en el mismo punto, a diez metros del borde de su
## celda.
##
## A ±0,5 los puntos caen en el borde, así que dos celdas vecinas comparten sus
## muestras: un cortado justo en la linde cierra las dos, que es lo correcto —a
## una linde no se llega por un lado sin llegar por el otro—.
##
## Cuántas por lado. Tres, el tres en raya, y NO cinco: está probado.
##
## Con tres quedan veinte metros entre muestra y muestra y la rejilla promete de
## más en el 0,20 % del mapa —pendientes de hasta 1,71 con el límite de escalada
## en 1,20—, o sea puntos que el trazado da por buenos y en los que no se puede
## dar un paso. Cinco por lado estrecha la malla a diez metros y baja esa mentira
## a la mitad (0,12 %, la peor pendiente 1,53).
##
## Y aun así sale peor, medido con la banda andando ocho jornadas en el sitio 56:
## el precio de mirar más de cerca es cerrar más suelo bueno —del 3,87 % al
## 5,13 % del mapa—, y eso son rodeos y tajos descartados. Las salidas que traen
## algo bajaron de 26-30 a 22, y los atascos siguieron en cero con las dos, que
## es lo que dice que esa mentira del 0,2 % no es la que atora a nadie: el
## andador ya la absorbe —ver `SettlementSim._can_step_into`— y quien no se mueve
## acaba renunciando al sitio, no clavado.
##
## Construirla, además, pasa de 540 ms a 1575 ms.
const PROBE_SIDE := 3

## Las muestras de cada celda, repartidas por igual de borde a borde.
##
## Se calculan en vez de escribirse a mano para poder cambiar [PROBE_SIDE] sin
## reescribir la lista ni las líneas del vado.
static var PROBES: Array[Vector2] = _build_probes()


static func _build_probes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var last := float(PROBE_SIDE - 1)
	for row in range(PROBE_SIDE):
		for col in range(PROBE_SIDE):
			out.append(Vector2(
				-0.5 + float(col) / last, -0.5 + float(row) / last))
	return out

## Cuánto pesa el riesgo frente a la distancia.
const RISK_WEIGHT := 5.0

## Cuánto pesa mojarse, sobre la dificultad de vadeo.
const WATER_WEIGHT := 2.5

## Cuánto tira el peor paso de la celda frente al promedio.
const WORST_BIAS := 0.6

## Cuánto puede encarecer el RIESGO una celda, como máximo.
##
## No es una cifra nueva: es [Marcha.RODEO_QUE_SE_ANDA], el rodeo que el juego
## ya declara andable, y está atada a él a propósito. Si esquivar lo peligroso
## no puede encarecer un metro más de dos veces y media, tampoco puede provocar
## un rodeo mayor que ese: las dos reglas dicen lo mismo y salen del mismo
## número, en vez de contradecirse como se contradecían.
##
## El tope es al MIEDO, no al tiempo: lo que se tarda en subir una cuesta sigue
## entero, y por eso el camino sigue prefiriendo el llano cuando de verdad es
## más rápido. Lo que ya no puede es rodear un valle por no pisar un canchal.
const RIESGO_MAXIMO := Marcha.RODEO_QUE_SE_ANDA

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

## Y con que caudal se midio.
##
## Una rejilla de invierno y una de agosto NO son la misma: en enero el rio va
## crecido y hay vados que dejan de serlo. Ver [Temporada] y [HornoDeRejillas].
var built_with_caudal: float = 1.0

## Y con cuanto ENCHARCAMIENTO.
##
## Es el otro lado de la estacion, y faltaba: `classify_ground` convierte
## en marisma el suelo humedo cuando el valle esta saturado -ver
## [Temporada.ENCHARCA]- y la marisma se anda al 34 %. La rejilla lo
## clasificaba SIEMPRE en seco, asi que en enero trazaba por barrizales
## dandolos por prado mientras el que andaba se hundia en ellos: el mismo
## metro de monte costeado de dos maneras, otra vez.
var built_with_encharque: float = 0.0

## Por que fila va el horneado, cuando se hace a trozos. Igual a `tall` cuando
## esta terminada.
var _fila: int = 0

## Y por que columna, para poder cortar a mitad de fila. Ver [amasar].
var _columna: int = 0

## Cada cuantas celdas se mira el reloj al hornear a trozos.
##
## Dieciseis. Mirar el reloj cuesta, asi que no se mira en cada celda; a
## 0,085 ms la celda es un milisegundo y pico de grano, que cabe de sobra en
## los cuatro del presupuesto.
const CELDAS_POR_RELOJ := 16


## Construye la rejilla a partir del terreno. Es lo caro -novecientos
## milisegundos medidos- y pasa una vez por estacion.
static func from_terrain(terrain: TerrainGenerator,
		has_boat: bool, has_bridge: bool, con_caudal: float = 1.0,
		con_encharque: float = 0.0) -> Navgrid:
	var grid := preparar(terrain, has_boat, has_bridge, con_caudal,
		con_encharque)
	while not grid.horneada():
		grid.amasar(terrain, grid.tall)
	return grid


## Reserva la rejilla sin medir ni una celda. Lo que sigue es [amasar].
##
## Existe para poder hornear A TROZOS. Una rejilla cuesta novecientos
## milisegundos: hacer las cuatro estaciones de golpe al arrancar serian tres
## segundos y medio de tiron, y hacerlas al cambiar de estacion seria un
## parpadeo a mitad de partida. Ver [HornoDeRejillas].
static func preparar(terrain: TerrainGenerator, has_boat: bool,
		has_bridge: bool, con_caudal: float = 1.0,
		con_encharque: float = 0.0) -> Navgrid:
	var grid := Navgrid.new()
	grid.built_with_boat = has_boat
	grid.built_with_bridge = has_bridge
	grid.built_with_caudal = con_caudal
	grid.built_with_encharque = con_encharque
	if terrain == null:
		return grid
	grid.world = Vector2(float(terrain.terrain_size.x), float(terrain.terrain_size.y))
	grid.wide = int(grid.world.x / CELL) + 1
	grid.tall = int(grid.world.y / CELL) + 1
	grid.cost.resize(grid.wide * grid.tall)
	grid.area.resize(grid.wide * grid.tall)
	grid.vado.resize(grid.wide * grid.tall)
	return grid


## Mide unas cuantas filas. Devuelve si ya esta terminada.
##
## Al acabar la ultima fila se inundan las zonas, que es lo que dice que dos
## puntos estan conectados: eso NO se puede hacer a medias, asi que va entero
## en el ultimo trozo.
##
## `hasta_ms` corta A MITAD DE FILA si se da: es el reloj del sistema al que
## hay que haber terminado. Hacia falta porque el grano mas fino que sabia
## cortar el horno era una FILA entera -unas cien celdas, entre nueve y
## diecisiete milisegundos- y el horno se habia puesto un presupuesto de
## cuatro. Un presupuesto mas fino que el trozo mas pequeno que sabes cortar
## no es un presupuesto: es un deseo. Ver [HornoDeRejillas.MS_POR_CUADRO].
func amasar(terrain: TerrainGenerator, filas: int,
		hasta_ms: int = 0) -> bool:
	if terrain == null or tall <= 0:
		_fila = maxi(tall, 0)
		return true
	var hasta := mini(_fila + maxi(filas, 1), tall)
	while _fila < hasta:
		for x in range(_columna, wide):
			var centre := Vector3(
				(float(x) + 0.5) * CELL, 0.0, (float(_fila) + 0.5) * CELL)
			var i := _fila * wide + x
			# EL AGUA DE LA CELDA SE MIRA UNA VEZ, y de ahi salen las dos
			# cosas: por donde se cruza y si se cruza siquiera.
			#
			# Se miraba TRES veces: las nueve muestras dentro de `_measure`,
			# las dos lineas enteras de `_vado_de_verdad`, y otra vez las
			# nueve mas las cuatro medias lineas de `_paso_de_la_celda`. Cada
			# rejilla pasaba de 934 ms a 1.315, y con el horno amasando a
			# cuatro milisegundos por cuadro eso son dos jornadas y media de
			# retraso hasta tener la del verano: la banda seguia sin poder
			# cruzar el rio con el rio ya bajo.
			var medida := _medir_la_celda(terrain, centre, built_with_boat,
				built_with_bridge, built_with_caudal, built_with_encharque)
			cost[i] = medida.x
			if cost[i] > BLOCKED:
				vado[i] = int(medida.y)
			# Cada pocas celdas se mira el reloj: cortar solo al acabar la
			# fila es lo que hacia que el horno se pasara del presupuesto.
			if hasta_ms > 0 and x % CELDAS_POR_RELOJ == 0 \
				and Time.get_ticks_msec() >= hasta_ms:
				_columna = x + 1
				return false
		_columna = 0
		_fila += 1
	if _fila >= tall:
		_flood_areas()
		return true
	return false


## POR DÓNDE se sale de cada celda que lleva agua. Índice `z * wide + x`.
##
## Cero es monte seco: la celda no toca el cauce y se anda en cualquier
## dirección. Con [MOJA] puesto, la celda lleva agua y sólo se cruza por las
## medias líneas que digan los otros cuatro bits —[PASO_E], [PASO_O], [PASO_S] y
## [PASO_N]—, cada uno el tramo que va DEL CENTRO DE LA CELDA A UNO DE SUS
## CUATRO LADOS. Ver [_paso_de_la_celda].
##
## Medias líneas y no líneas enteras, porque un paso de una celda a la de al
## lado es justamente eso: media celda de aquí y media de allá. Con la línea
## entera, una celda de ribera —seca por su fila y mojada por su columna— no se
## podía pisar viniendo del monte de arriba, y la orilla quedaba convertida en
## una tira incomunicada del valle al que pertenece.
##
## Esto era un sí/no que además se medía SÓLO EN EL CENTRO de la celda, y ahí
## estaban los dos agujeros por los que se colaban los atascos:
##
##   - Una celda con el cauce a un lado y el centro seco no se marcaba, así que
##     el trazado la cruzaba por donde quisiera y quien andaba se encontraba el
##     río. Ahora se miran las nueve muestras.
##   - Marcada o no, sólo se prohibía la DIAGONAL. Una celda que se vadea de
##     este a oeste y se cruza de norte a sur es exactamente el mismo paso
##     imposible, y ése sí se trazaba.
##
## Sin esto, la rejilla promete un vado que sobre el terreno no está donde ella
## dice: la persona llega a la orilla, no encuentra por dónde, y se pasa la
## jornada barriéndola. Es el ovillo pegado al agua de la ventana de rastros.
var vado: PackedByteArray = PackedByteArray()

## La celda lleva agua: no se cruza por donde sea.
const MOJA := 1

## Del centro de la celda a cada uno de sus cuatro lados.
const PASO_E := 2
const PASO_O := 4
const PASO_S := 8
const PASO_N := 16


## Por dónde se sale de una celda: cero si por donde sea, si no [MOJA] más los
## lados a los que se llega desde el centro sin meterse en el agua.
##
## Se mira primero si la celda toca el agua siquiera —las nueve muestras que ya
## cuesta medirla— y sólo entonces se catan finas las cuatro medias líneas. El
## monte seco, que es casi todo el mapa, no paga nada de esto.
static func _paso_de_la_celda(terrain: TerrainGenerator, centre: Vector3,
		has_boat: bool, has_bridge: bool, con_caudal: float,
		moja: bool) -> int:
	if terrain == null:
		return 0

	# Si la celda no toca el agua no hay nada que catar. `moja` llega hecho
	# desde [_medir_la_celda], que ya ha mirado las nueve muestras: mirarlas
	# aqui otra vez era la segunda pasada sobre la misma celda.
	if not moja:
		return 0

	var mask := MOJA
	for lado: Array in [[PASO_E, Vector3(1.0, 0.0, 0.0)],
			[PASO_O, Vector3(-1.0, 0.0, 0.0)],
			[PASO_S, Vector3(0.0, 0.0, 1.0)],
			[PASO_N, Vector3(0.0, 0.0, -1.0)]]:
		if _media_linea_se_vadea(terrain, centre, lado[1] as Vector3,
				has_boat, has_bridge, con_caudal):
			mask |= int(lado[0])
	return mask


## Si del centro de la celda a uno de sus lados se va sin meterse en el agua.
static func _media_linea_se_vadea(terrain: TerrainGenerator, centre: Vector3,
		hacia: Vector3, has_boat: bool, has_bridge: bool,
		con_caudal: float) -> bool:
	var catas := maxi(int(ceil(CELL * 0.5 / CATA_DEL_VADO)), 2)
	var hondo := 0.0
	for i in range(catas + 1):
		var point := centre + hacia * (CELL * 0.5 * float(i) / float(catas))
		hondo = maxf(hondo, terrain.crossing_difficulty_with(point, con_caudal))
	return Hydrography.can_cross(hondo, has_boat, has_bridge)


## Si por esta celda se cruza de LADO A LADO en uno de los dos sentidos.
##
## `a_lo_ancho` es la fila de en medio -se va en X, la Z fija-, que es por donde
## pasa quien entra por el este y sale por el oeste. Lo otro es la columna.
static func _linea_se_vadea(terrain: TerrainGenerator, centre: Vector3,
		a_lo_ancho: bool, has_boat: bool, has_bridge: bool,
		con_caudal: float) -> bool:
	var uno := Vector3(1.0, 0.0, 0.0) if a_lo_ancho else Vector3(0.0, 0.0, 1.0)
	if not _media_linea_se_vadea(terrain, centre, uno, has_boat, has_bridge,
			con_caudal):
		return false
	return _media_linea_se_vadea(terrain, centre, -uno, has_boat, has_bridge,
			con_caudal)


## Si el paso de una celda a la de al lado existe de verdad.
##
## Es LA regla, y tiene que ser la misma en los tres sitios que la necesitan:
## el buscador de caminos, la inundación de zonas que dice quién está
## comunicado con quién, y el recorte de la escalera. Estaba escrita sólo en el
## primero y a medias —sólo la diagonal—, así que los otros dos prometían pasos
## que el trazado no daba, y de esa discrepancia salían las dos averías: rutas
## que el andador no puede seguir, y sitios que `connected` juraba alcanzables y
## para los que el A* volvía sin camino después de recorrerse la comarca.
##
## `dx` y `dz` son el salto en celdas, cada uno en -1, 0, 1.
func paso_entre(a: int, b: int, dx: int, dz: int) -> bool:
	if vado.size() != cost.size():
		return true
	var va: int = vado[a]
	var vb: int = vado[b]
	if va == 0 and vb == 0:
		return true

	# EL AGUA NO SE CRUZA EN DIAGONAL. Una celda con cauce se abre por su línea
	# de vado, y una diagonal la atraviesa de esquina a esquina, o sea por
	# fuera de esa línea: eso es el cauce.
	if dx != 0 and dz != 0:
		return false

	var sale := PASO_E
	var entra := PASO_O
	if dx < 0:
		sale = PASO_O
		entra = PASO_E
	elif dz > 0:
		sale = PASO_S
		entra = PASO_N
	elif dz < 0:
		sale = PASO_N
		entra = PASO_S

	if (va & MOJA) != 0 and (va & sale) == 0:
		return false
	if (vb & MOJA) != 0 and (vb & entra) == 0:
		return false
	return true


func horneada() -> bool:
	return tall > 0 and _fila >= tall


## Si por esta celda se puede cruzar el agua de lado a lado.
##
## Las nueve muestras son un tres en raya; se mira la fila de en medio y la
## columna de en medio. Si alguna de las dos se vadea entera, hay paso.
## Cada cuantos metros se cata la linea del vado.
##
## Tres, que es EXACTAMENTE lo que cata el andador dentro de un paso -ver
## [Marcha.CATA_DEL_PASO]-, y ahi estaba el desajuste que dejaba a media banda
## peleandose con la orilla.
##
## Las nueve muestras de la celda estan a veinte metros unas de otras, y un
## cauce mas estrecho que eso se cuela entre dos: la rejilla veia una linea
## vadeable donde el andador se encontraba el rio. La rejilla trazaba el camino
## por ese vado que no existe, la gente llegaba a la orilla y se pasaba la
## jornada barriendola. Y todos en EL MISMO PUNTO, porque el vado falso era
## siempre la misma celda.
##
## Se cata fino solo cuando la cata gruesa dice que hay paso, que es en las
## pocas celdas del cauce: el resto ni entra aqui.
const CATA_DEL_VADO := 3.0


## Si por esta celda se puede cruzar el agua de lado a lado, de verdad.
##
## Dos pasadas: la de las nueve muestras, que es barata y descarta la inmensa
## mayoria de las celdas, y una fina por la linea que aquella daba por buena.
static func _vado_de_verdad(terrain: TerrainGenerator, centre: Vector3,
		fords: PackedFloat32Array, has_boat: bool, has_bridge: bool,
		con_caudal: float) -> bool:
	if not _has_ford(fords, has_boat, has_bridge):
		return false
	if terrain == null:
		return true

	for a_lo_ancho: bool in [true, false]:
		if _linea_se_vadea(terrain, centre, a_lo_ancho, has_boat, has_bridge,
				con_caudal):
			return true
	return false


static func _has_ford(fords: PackedFloat32Array, has_boat: bool,
		has_bridge: bool) -> bool:
	# La fila y la columna de en medio de la malla de muestras.
	var mid := PROBE_SIDE / 2
	var across: Array[int] = []
	var down: Array[int] = []
	for i in range(PROBE_SIDE):
		across.append(mid * PROBE_SIDE + i)
		down.append(i * PROBE_SIDE + mid)
	for line: Array in [across, down]:
		var deepest := 0.0
		for i: int in line:
			deepest = maxf(deepest, fords[i])
		if Hydrography.can_cross(deepest, has_boat, has_bridge):
			return true
	return false


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

			# ABRIR LA PUERTA NO ES BORRAR EL RÍO.
			#
			# La celda se abre —eso no se discute, la banda tiene que poder
			# salir— pero se abre CON SU MÁSCARA DE VADO, no en blanco. En
			# blanco quiere decir «monte seco, se cruza por donde sea», y como
			# los abrigos se eligen junto al agua eso equivalía a trazar
			# caminos por el cauce mismo a veinte metros de la puerta. No es un
			# caso raro: es el caso normal.
			#
			# Y si la medición no deja NINGÚN lado por el que salir, entonces
			# sí se abre en blanco: el abrigo está metido en el canal, y una
			# banda que no puede salir de su propia puerta es peor que cuarenta
			# metros de suelo inventado. Es la misma decisión que ya estaba
			# tomada arriba, sólo que ahora se paga únicamente donde hace falta.
			# Por la misma puerta que todo lo demas: una sola pasada por la
			# celda. Ver [_medir_la_celda].
			var paso := int(_medir_la_celda(terrain, point, built_with_boat,
				built_with_bridge, built_with_caudal, built_with_encharque).y)
			if paso == MOJA:
				paso = 0

			# Caro pero transitable: la salida de casa no es una autopista
			cost[cell] = FORCED_COST
			vado[cell] = paso
			opened += 1

	if opened > 0:
		_flood_areas()
	return opened


## Lo que cuesta una celda abierta a la fuerza. Alto a propósito.
const FORCED_COST := 9.0


## Mide una celda ENTERA de una sola pasada: lo que cuesta y por donde se
## cruza. Devuelve `(coste, mascara de vado)`.
##
## Existe porque el agua de la celda se estaba mirando TRES VECES: las nueve
## muestras dentro de `_measure`, las dos lineas enteras de `_vado_de_verdad`,
## y otra vez las nueve mas las cuatro medias lineas de `_paso_de_la_celda`.
## Tres respuestas a la misma pregunta, y encima con el coste multiplicado.
##
## Y no era gratis: cada rejilla paso de 934 ms a 1.315, el horno amasa a
## cuatro milisegundos por cuadro, y eso son dos jornadas y media hasta tener
## la rejilla del verano. La banda seguia sin poder cruzar el rio con el rio ya
## bajo, y los parajes de la otra orilla salian «no alcanzable» sin serlo.
static func _medir_la_celda(terrain: TerrainGenerator, centre: Vector3,
		has_boat: bool, has_bridge: bool, con_caudal: float,
		con_encharque: float) -> Vector2:
	if terrain == null:
		return Vector2(BLOCKED, 0.0)

	# Las nueve muestras, UNA vez. De aqui salen las dos respuestas.
	var fords := PackedFloat32Array()
	fords.resize(PROBES.size())
	var moja := false
	var index := -1
	for probe: Vector2 in PROBES:
		index += 1
		var point := Vector3(
			centre.x + probe.x * CELL, 0.0, centre.z + probe.y * CELL)
		var ford := terrain.crossing_difficulty_with(point, con_caudal)
		fords[index] = ford
		if ford > Hydrography.ROZA_EL_AGUA:
			moja = true

	var paso := _paso_de_la_celda(terrain, centre, has_boat, has_bridge,
		con_caudal, moja)
	var coste := _measure(terrain, centre, has_boat, has_bridge, con_caudal,
		con_encharque, paso)
	return Vector2(coste, float(paso))


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
		has_boat: bool, has_bridge: bool, con_caudal: float = 1.0,
		con_encharque: float = 0.0, paso: int = -1) -> float:
	var total := 0.0
	var worst := 0.0
	# El vadeo de cada muestra, en el orden de `PROBES`, para poder mirar
	# después si hay una LÍNEA que cruce la celda y no sólo un punto somero.
	var fords := PackedFloat32Array()
	fords.resize(PROBES.size())
	var index := -1

	for probe: Vector2 in PROBES:
		index += 1
		var point := Vector3(
			centre.x + probe.x * CELL, 0.0, centre.z + probe.y * CELL)
		point.y = terrain.get_height_at(point)

		var slope := terrain.get_slope_at(point)
		# AL CAUDAL DE ESTA REJILLA, no al de hoy: una rejilla de invierno se
		# mide con el rio de enero aunque se hornee en agosto.
		var ford := terrain.crossing_difficulty_with(point, con_caudal)

		# LA PENDIENTE Y EL AGUA NO SE JUZGAN IGUAL, y ésa es la diferencia.
		#
		# Una pared que cruza la celda la cierra: se mire por donde se mire, por
		# ahí no se sube, y cualquiera de las nueve muestras basta para
		# cerrarla. Se probó a aflojarlo —que una peña suelta no cerrara los
		# cuarenta metros— y salió peor, con el juego delante: 385 minutos de
		# gente parada contra una pared.
		#
		# Un río NO. Un río se cruza POR EL VADO, no por un punto cualquiera, y
		# midiéndolo con la muestra más honda se cerraba el cauce entero
		# —incluidos los vados—. Medido en el sitio 56: se vadea hasta 0,35 y el
		# mejor paso del río estaba en 0,32, o sea que había vado y la rejilla
		# no lo veía; el resultado era un tercio del valle incomunicado del
		# abrigo para toda la partida. El agua se juzga por su MEJOR paso.
		if absf(slope) > Traversal.CLIMB_LIMIT:
			return BLOCKED
		fords[index] = ford

		# Lo que cuesta andarlo, Y ES LA MISMA CUENTA QUE HACE EL QUE ANDA.
		#
		# Aquí ponía `hiking_speed(slope)` con un comentario que decía que el
		# suelo iba dentro. No iba: `hiking_speed` es Tobler a secas y el suelo
		# —que frena hasta un 0,34 en marisma— lo mete `travel_speed`, que es
		# la que usa [Marcha._terrain_speed]. O sea que el trazado y la marcha
		# costeaban el mismo metro de monte de dos maneras distintas, y el
		# comentario juraba lo contrario.
		#
		# Y `slope` viene de `get_slope_at`, que es un MÓDULO: Tobler es
		# asimétrica, así que la rejilla daba por cuesta arriba hasta las
		# bajadas. Ver [Traversal.pace_both_ways].
		var suelo := Traversal.classify_ground(slope, ford, con_encharque)
		var step := 1.0 / maxf(Traversal.pace_both_ways(slope, suelo, 0.0),
			0.01)

		# Y lo que arriesga. Es la misma clasificación que usan los percances,
		# así que el camino evita justo donde la gente se hace daño.
		var risk := 0.0
		match suelo:
			Traversal.Ground.CANCHAL: risk = 1.0
			Traversal.Ground.ROCA: risk = 0.6
			Traversal.Ground.MARISMA: risk = 0.5
			Traversal.Ground.ARENA: risk = 0.15
			_: risk = 0.0
		risk *= 1.0 + slope * 1.5
		risk += ford * WATER_WEIGHT

		# Y EL RIESGO NO MULTIPLICA SIN TOPE.
		#
		# Aquí ponía `step * (1.0 + risk * RISK_WEIGHT)` a pelo. Con eso un
		# canchal de cincuenta grados costaba 587 veces un prado llano, y de
		# esas 587 sólo 58 son TIEMPO —lo que de verdad se tarda, ver
		# [Traversal.pace_both_ways]—: el resto es miedo. Como el trazado
		# minimiza coste, cambiaba cientos de metros de camino por no pisar
		# cuarenta de cuesta.
		#
		# Se veía en verano y no antes, que es lo que despistaba: es cuando
		# bajan los ríos y se abren las celdas de vado, y con ellas aparecen
		# recorridos por el llano que antes no existían. Medido en el sitio 56,
		# los mismos 213 trayectos: rodeo medio x1,24 en primavera, otoño e
		# invierno, y x2,50 en verano —84 empeoraban, ninguno mejoraba— con el
		# cruce del agua pasando de 174 m del abrigo a 698. Y 88 sitios que la
		# regla del rodeo admitía se andaban por encima de ella.
		#
		# Cruzar el río nunca fue lo caro: un vado con el agua por la rodilla
		# cuesta 20. Lo caro era la ladera.
		var value := step * minf(1.0 + risk * RISK_WEIGHT, RIESGO_MAXIMO)
		total += value
		worst = maxf(worst, value)

	# Y el agua, POR SI HAY POR DÓNDE CRUZAR LA CELDA.
	#
	# No basta con que un punto suelto sea somero: eso abriría la celda por un
	# charco de una esquina y mandaría a la gente a cruzar por lo hondo. Lo
	# que hace falta es una línea que la atraviese de lado a lado, que es lo
	# que de verdad significa «aquí hay vado».
	#
	# Eso YA ESTÁ MEDIDO en la máscara que llega hecha —ver [_paso_de_la_celda],
	# que cata las cuatro medias líneas cada tres metros—, así que aquí sólo
	# hay que leerla: hay línea entera si se sale por los dos lados opuestos.
	#
	# Volver a escanear el agua aquí era la TERCERA pasada sobre la misma
	# celda, y el horneado de una rejilla habia subido de 934 ms a 1.315. Con
	# cuatro milisegundos por cuadro, eso son dos jornadas y media hasta tener
	# la rejilla del verano: la banda seguía sin cruzar el río con el río ya
	# bajo.
	if paso >= 0:
		if (paso & MOJA) != 0 \
			and (paso & (PASO_E | PASO_O)) != (PASO_E | PASO_O) \
			and (paso & (PASO_S | PASO_N)) != (PASO_S | PASO_N):
			return BLOCKED
	elif not _vado_de_verdad(terrain, centre, fords, has_boat, has_bridge,
			con_caudal):
		return BLOCKED

	return lerpf(total / float(PROBES.size()), worst, WORST_BIAS)


## Cierra una celda que el terreno ha desmentido, y rehace las zonas.
##
## La rejilla mide con nueve muestras y una linea de vado; el terreno tiene mas
## detalle que eso, y de vez en cuando abre una celda por un paso que sobre el
## suelo no existe. Antes eso era un pozo sin fondo: la ruta pasaba por ahi, la
## persona se plantaba en la orilla, se le daba media vuelta, y AL DIA SIGUIENTE
## se le volvia a trazar la misma ruta por el mismo sitio. Todos los dias, y
## varios a la vez, siempre en el mismo punto.
##
## Ahora la banda APRENDE: quien se topa con que por ahi no se pasa lo cierra
## para todos, y el camino de mañana da la vuelta o el sitio deja de estar al
## alcance. Devuelve si de verdad cerro algo.
func cerrar(world_position: Vector3) -> bool:
	var i := cell_of(world_position)
	if i < 0 or i >= cost.size() or cost[i] <= BLOCKED:
		return false
	cost[i] = BLOCKED
	_flood_areas()
	return true


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


## Si la celda de este punto lleva cauce, o sea que sólo se cruza por su vado.
##
## Lo preguntan los dos que tienen que apartarse del agua: el atajo de la recta
## corta -ver [Wayfinder._clear_line]- y el carril de cada persona -ver
## [Marcha._lane_shift]-, que dos metros y medio a un lado de un vado es el río.
func moja(point: Vector3) -> bool:
	if not is_ready() or vado.size() != cost.size():
		return false
	return (vado[cell_of(point)] & MOJA) != 0


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


## Las celdas vecinas por las que SE PUEDE PASAR desde ésta.
##
## Con la misma regla de esquinas que usa el buscador de caminos: una diagonal
## sólo cuenta si las dos ortogonales que la rodean están abiertas. Es lo que
## hace que `connected` diga la verdad.
##
## Sin esto, la inundación de zonas unía dos trozos de mapa por el vértice entre
## dos celdas cerradas —un paso de anchura cero que nadie puede dar—, así que
## `connected` daba que sí y el buscador se quedaba sin camino. Desde fuera se
## veía como «se quedó sin camino trazado» sobre un sitio que la rejilla juraba
## alcanzable.
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
			if dx != 0 and dz != 0:
				if cost[z * wide + nx] <= BLOCKED:
					continue
				if cost[nz * wide + x] <= BLOCKED:
					continue
			# Y LA MISMA REGLA DEL AGUA QUE USA EL TRAZADO. Sin esto la
			# inundación comunicaba las dos orillas por un vado que el buscador
			# de caminos no consiente cruzar: `connected` decía que sí, el A*
			# se recorría la comarca entera y volvía sin camino, y desde fuera
			# eso era «se quedó sin camino trazado» sobre un sitio que la
			# rejilla juraba alcanzable. Ver [paso_entre].
			if not paso_entre(cell, nz * wide + nx, dx, dz):
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
