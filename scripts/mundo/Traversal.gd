class_name Traversal
extends RefCounted
## Por dónde se puede pasar y a qué velocidad.
##
## La velocidad de marcha NO es un número inventado: es la función de Tobler,
## ajustada sobre datos reales de excursionistas y sobre las tablas de marcha
## alpina de Imhof. Se usa en arqueología del paisaje precisamente para esto,
## para calcular hasta dónde llegaba una comunidad en una jornada.
##
##     v = 6 · e^(−3,5 · |S + 0,05|)   km/h,  con S = desnivel / recorrido
##
## De ahí salen tres cosas que ninguna fórmula inventada daría bien:
##
##  · El máximo NO está en el llano sino en una bajada del 5%: cuesta abajo
##    poco se aprovecha la gravedad sin tener que frenar.
##  · Bajar fuerte es MÁS LENTO que llanear, porque hay que frenar en cada
##    paso y el pie resbala.
##  · La caída es exponencial: subir al 30% no cuesta el triple que al 10%.
##
## Encima de eso van la carga y el suelo, que son los otros dos factores que
## de verdad cambian una jornada de marcha.

## Distancia EN LLANO entre dos puntos: la sombra sobre el mapa, sin la altura.
##
## Hace falta porque en este valle conviven dos clases de Vector3 y se parecen
## demasiado: los que llevan la cota puesta —la posición de una persona, la del
## abrigo, la de un paraje— y los que salen de una rejilla, que traen `y = 0`
## porque una celda no está a ninguna altura. Restar uno de otro con
## `distance_to` no mide una distancia: mide la altitud.
##
## Y no es teoría. Medido en el sitio 56, donde el relieve va de 96 a 718 m:
## [Querencia] repartía lo que la banda sabe con `donde.distance_to(centre)`,
## con la cota en un lado y cero en el otro, así que la distancia salía SIEMPRE
## mayor que la mancha, toda la vuelta del abrigo se quedaba en el valor del
## filo —0,24— y la rejilla entera de familiaridad no pasaba de ahí. Por debajo
## del 0,30 que hace falta para bautizar y del 0,35 para ofrecer un tajo: la
## banda no tenía NI UN sitio donde trabajar, salía a investigar todos los días
## y se pasaba la jornada dando vueltas por la ribera.
##
## Siempre que un lado venga de una celda, la distancia se mide aquí.
static func en_llano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Tipos de suelo por lo que cuesta pisarlos, no por lo que parecen.
enum Ground {
	PASTO,     ## Herbazal y suelo forestal: la referencia
	ARENA,     ## Playa y duna: cede bajo el pie
	ROCA,      ## Caliza desnuda: incómoda pero firme
	CANCHAL,   ## Derrubio suelto: se mueve al pisarlo
	MARISMA,   ## Barro y agua somera: lo más lento que hay
}

## Pendiente (tangente) por encima de la cual ya no es andar sino trepar.
##
## 1,2 son unos 50°. Es el límite de subir a pie CON CARGA, no el de un
## escalador: la banda va con crios, con leña y con la caza a cuestas.
const CLIMB_LIMIT := 1.2

## Cuánto frena ir cargado, como fracción de velocidad perdida a plena carga.
const LOAD_PENALTY := 0.55

## Velocidad mínima de marcha, en km/h. Por debajo de esto no es que se ande
## despacio, es que no se avanza: en una pendiente digna de escalada la
## curva de Tobler se acerca a cero de verdad, y eso es exactamente lo que
## deja a alguien "atascado" sin que nada le corte el paso.
##
## Hace falta sobre todo porque `open_around_home` fuerza a pasable el
## entorno del abrigo aunque la pendiente real pase de [CLIMB_LIMIT] -la
## puerta de una cueva no siempre tiene un llano delante-, con un coste fijo
## que el planificador lee como "caro, no imposible". Sin este suelo, el
## andador que de verdad pisa esa celda se arrastraba a milímetros por hora:
## el planificador prometía una ruta cara y el andador no la cumplía, que es
## justo el patrón que ya rompió atascos parecidos en el pasado -ver
## `Navgrid._measure` y `Wayfinder.floor_cost`, que aplicaban este mismo
## suelo cada uno por su lado antes de que viviera aquí.
const MIN_SPEED := 0.15

## Velocidad de marcha en km/h para una pendiente dada, según Tobler.
##
## `slope` es la tangente con signo: positiva subiendo, negativa bajando.
static func hiking_speed(slope: float) -> float:
	return maxf(6.0 * exp(-3.5 * absf(slope + 0.05)), MIN_SPEED)


## Factor por carga, de 0 (de vacío) a 1 (a plena carga).
##
## No baja a cero ni siquiera a tope: a plena carga se sigue andando, despacio.
## Que alguien quede clavado por ir cargado sería un bloqueo, no una
## dificultad.
static func load_factor(load_fraction: float) -> float:
	var load := clampf(load_fraction, 0.0, 1.0)
	# Cuadrático: los primeros kilos apenas se notan y los últimos pesan mucho,
	# que es como funciona cargar de verdad
	return 1.0 - LOAD_PENALTY * load * load


## Factor por el suelo que se pisa.
static func ground_factor(ground: Ground) -> float:
	match ground:
		Ground.ARENA: return 0.72
		Ground.ROCA: return 0.80
		Ground.CANCHAL: return 0.58
		# El barro es, con diferencia, lo que más frena: cada paso hay que
		# sacar el pie. Los pasos de marisma son un factor real del poblamiento
		# costero cantábrico, no un detalle de sabor.
		Ground.MARISMA: return 0.34
		_: return 1.0


## Velocidad final, en km/h, juntando los tres factores.
static func travel_speed(slope: float, ground: Ground, load_fraction: float) -> float:
	return hiking_speed(slope) * ground_factor(ground) * load_factor(load_fraction)


## Si se puede pasar por un punto.
##
## Ojo con la distinción: que algo sea AGOTADOR no lo hace intransitable. Son
## cosas distintas, y confundirlas dejaría a la banda encerrada en el fondo del
## valle. Lo intransitable es lo que no se sube andando con carga, y el agua
## que no se vadea.
static func is_passable(slope: float, ford_difficulty: float,
		has_boat: bool, has_bridge: bool) -> bool:
	if absf(slope) > CLIMB_LIMIT:
		return false
	return Hydrography.can_cross(ford_difficulty, has_boat, has_bridge)


## Desde cuánta agua somera el suelo es barro, en seco y encharcado.
##
## El umbral BAJA con la estación, y ahí está el barro: en agosto una vaguada
## húmeda se cruza andando y en enero es un barrizal. La misma vaguada, el
## mismo mapa de vados —lo que cambia es cuánta agua hace falta para que el pie
## se hunda, y en suelo saturado hace falta muy poca.
##
## Sólo cambia la VELOCIDAD, nunca si se pasa o no: eso lo decide
## [is_passable] con el vado, y un invierno que cerrara media comarca de golpe
## dejaría a la banda encerrada. El barro cansa, no tapia.
const MOJADO_EN_SECO := 0.05
const MOJADO_ENCHARCADO := 0.012


## Deduce el suelo del propio terreno: pendiente y cuánta agua hay.
##
## No hace falta un mapa de tipos de suelo aparte. Donde el agua es somera hay
## barro; donde la pendiente pasa de lo que aguanta el suelo hay derrubio; y
## donde pasa de lo que aguanta el derrubio, la roca ya está a la vista.
##
## `encharcado` es lo que dice [Temporada.encharcamiento], de 0 a 1. Va con
## valor por defecto a propósito: [Navgrid] hornea la rejilla de caminos UNA
## vez y tiene que seguir clasificando en seco, o cada cambio de estación
## obligaría a rehacerla. Los caminos no cambian con la lluvia; lo que cambia
## es lo que cuesta andarlos.
static func classify_ground(slope: float, ford_difficulty: float,
		encharcado: float = 0.0) -> Ground:
	var mojado := lerpf(MOJADO_EN_SECO, MOJADO_ENCHARCADO,
		clampf(encharcado, 0.0, 1.0))
	if ford_difficulty > mojado:
		return Ground.MARISMA
	# Los umbrales no son de gusto: el derrubio suelto se sostiene hasta su
	# angulo de reposo, unos 34 grados -tangente 0,67-, que es la misma
	# constante que usa la erosion termica. Por debajo de ahi el suelo agarra y
	# hay pasto; por encima, lo que queda en la ladera es piedra suelta.
	#
	# Estuvo en 0,45 (24 grados) y clasificaba como canchal el 40% del valle,
	# que a esa pendiente es herbazal de toda la vida.
	var steep := absf(slope)
	if steep > 1.15:
		return Ground.ROCA
	if steep > 0.67:
		return Ground.CANCHAL
	return Ground.PASTO
