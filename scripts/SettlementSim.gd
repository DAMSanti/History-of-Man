class_name SettlementSim
extends Node3D
## Simula el asentamiento en el mapa local: gente concreta con rutina diaria.
##
## Los dos relojes del juego viven en escalas distintas y esto es el de abajo:
## el mapa local corre por DIAS, con la gente yendo y viniendo del tajo, y el
## regional por ESTACIONES, para estrategia y expediciones. Encaja con la
## arquitectura de dos escalas: cada capa simula lo que le corresponde.

signal day_passed(day: int)

## Se emite cuando el reloj local hace cambiar la estación. Antes esto solo
## pasaba a mano desde el mapa regional: jugar cien jornadas en el
## asentamiento no traía nunca el otoño.
signal season_changed(season: int, year: int)

## El almacen se ha llenado y se ha tenido que dejar cosas fuera
signal storage_full(units_lost: float)

## Algo que merece parar y mirar —o decidir— ahora mismo. Ver [Moment].
##
## Va por señal y no por consulta porque lo que hace la interfaz con esto no es
## pintar un dato: es interrumpir. La simulación no sabe -ni tiene que saber-
## qué se hace con el momento; sólo que ha ocurrido.
signal moment_raised(moment: Moment)

## Segundos reales por dia de juego.
##
## Estaba en 24 y era el fallo de calibrado que rompia toda la simulacion: con
## una jornada util de doce horas comprimida en doce segundos, y a la velocidad
## de marcha de entonces, una persona llegaba a 150 m de casa antes de tener
## que volver. Como el radio ya conocido al empezar es de 416 m, nadie salia
## nunca del terreno visto: el territorio conocido no se movia del 3%, no se
## recogia nada y la gente se pasaba el dia yendo y viniendo.
##
## Con 120 s la jornada util son 60 s reales, que ademas es tiempo suficiente
## para ver a la gente trabajar en vez de parpadear.
@export var seconds_per_day: float = 120.0

## La jornada, en horas del reloj. No es decoracion: define cuando se puede
## salir, cuanto dura la jornada util y a que hora hay que estar de vuelta.
##
## Se levanta con luz y se recoge antes del anochecer. En Cantabria eso son
## unas nueve horas utiles en invierno y quince en verano, pero de momento se
## usa una jornada fija y honesta de doce.
const HORA_DESPERTAR := 6.0
const HORA_SALIDA := 7.0      ## Antes de esto se desayuna y se prepara
## La parada de mediodia. Ya NO se come en ella -se come dos veces al dia, ver
## [HORA_DESAYUNO] y [HORA_CENA]-, pero se sigue descontando de las horas
## utiles: la banda para igual, a la sombra y sin trabajar.
const HORA_MEDIODIA := 13.0
const HORA_FIN_MEDIODIA := 14.0
const HORA_REGRESO := 19.0    ## A esta hora hay que emprender la vuelta
const HORA_DORMIR := 21.0

## Las DOS comidas de la jornada: al levantarse y a la hora de recogerse.
##
## Antes se comia de tres maneras y ninguna era una comida: un desayuno si se
## tenia hambre, un bocado del zurron a mediodia, y ademas cualquier rato
## muerto en el que el hambre pasara de 55. O sea que la banda picaba todo el
## dia y no se sentaba nunca.
##
## Dos y a sus horas. El desayuno es lo que permite aguantar la jornada sin
## cargar comida; la cena es lo ultimo que se hace antes de dormir, junto al
## fuego, que es de donde sale el aprovechamiento de mas del hogar.
const HORA_DESAYUNO := HORA_DESPERTAR
const HORA_CENA := HORA_DORMIR

## Cuanto dura sentarse a comer, en horas de reloj.
const DURA_LA_COMIDA := 1.0

## Con menos hambre que esto, uno se levanta de la mesa.
##
## Estaba escrito a pelo dentro del estado COMIENDO y hace falta ADEMAS para
## decidir si merece la pena sentarse: sin ese filtro, la hora del desayuno
## volvia a sentar a la mesa a quien acababa de terminar, tick tras tick, y
## cada vuelta sacaba comida del almacen. Medido: la despensa pasaba de ocho
## dias de reserva a CERO en ocho jornadas.
const COMIDA_SUFICIENTE := 15.0

## Cuanta hambre quita una racion, y cuanta sube por hora.
##
## Las dos salen de lo mismo: la barra de 0 a 100 ES la jornada de una persona.
## Una racion es media jornada, asi que quita cincuenta; y el dia entero sube
## cien, asi que la hora sube cien partido por veinticuatro.
##
## Antes eran dos cifras sueltas -3,4 por hora y 81,6 por racion- que decian
## que una racion era un dia entero mientras `daily_food` decia lo mismo y la
## banda comia dos veces: la despensa prometia el doble de lo que daba.
const HAMBRE_POR_RACION := 50.0
const HAMBRE_POR_HORA := 100.0 / 24.0

## Cuanto se tarda en andar una distancia, en HORAS DE JUEGO.
##
## `walk_speed` va en unidades por segundo REAL, y una hora de juego son
## `seconds_per_day / 24` segundos reales: sin esa conversion el viaje sale en
## unas unidades que no son horas. Estaba escrito a mano en `_rank_known_spots`
## y hace falta en dos sitios mas -decidir cuando emprender la vuelta y si se
## llega antes de que anochezca-, asi que vive aqui.
##
## Es una estimacion EN LINEA RECTA y a paso de llano, o sea que se queda
## corta: el camino da rodeos y sube cuestas. Quien la use para decidir cuando
## dar media vuelta tiene que multiplicarla por [RODEO_DE_VUELTA]; quedarse
## corto ahi no es el lado seguro, es llegar de noche.
func hours_to_walk(metres: float) -> float:
	var per_hour := walk_speed * (seconds_per_day / 24.0)
	return metres / maxf(per_hour, 0.1)


## Cuanto mas largo es el camino de verdad que la linea recta.
##
## MEDIDO, no elegido: `scripts/tools/RodeoProbe.gd` traza cuatrocientas
## vueltas al abrigo desde puntos sorteados a distancia de jornada en el sitio
## 56 y compara la ruta con la recta. Mediana 1,22; percentil 90 en 1,97;
## percentil 95 en 2,43.
##
## Se usa el percentil 95 y no el 90, y no hay que elegir entre las dos cosas:
## con dos se quedaba a dormir en el monte una persona de quince cada noche
## -recolectores a los que se les hacia de noche, no el explorador, que acampa
## a proposito-; con 2,4 son 0,2. Y el trabajo de la banda SUBE, de 125,6 a
## 128,1 persona-horas al dia, porque a quien se queda tirado no se le pierde
## solo la noche: se le pierde tambien la manana siguiente volviendo.
##
## Solo se aplica a decidir CUANDO dar media vuelta. Para comparar parajes
## entre si -ver `_rank_known_spots`- el rodeo afecta a todos por igual y no
## cambia cual gana.
const RODEO_DE_VUELTA := 2.4


## Horas utiles de trabajo en una jornada, descontando la parada
const HORAS_UTILES := (HORA_REGRESO - HORA_SALIDA) - (HORA_FIN_MEDIODIA - HORA_MEDIODIA)

## Velocidad de la gente en llano, de vacio y por pasto, en unidades de mundo
## por segundo. Es la referencia: sobre ella actuan pendiente, suelo y carga.
##
## Calibrada CONTRA la duracion del dia, no a ojo: con 60 y una jornada util de
## 60 s reales, se alcanza algo menos de dos kilometros de ida. Descontando la
## vuelta y el tiempo de recoger, el radio util de una jornada queda en torno a
## 800 m, que es lo que da un forrajeo de radio corto de verdad.
@export var walk_speed: float = 60.0

## Lo que puede llevar una persona antes de ir a plena carga, en las mismas
## unidades que `carrying`. Sirve para saber si va cargada o no.
@export var carry_capacity: float = 3.0

## Hasta donde se ve el terreno desde donde uno esta, en metros. Es lo que
## descubre mapa al andar.
@export var sight_range: float = 260.0

## Volumen util del abrigo, en litros. Doce metros cubicos es un abrigo
## pequeno; una cueva grande admite bastante mas.
@export var shelter_litres: float = 12000.0

## Abundancia que se lleva UNA persona en UNA jornada completa de trabajo.
##
## Un paraje bueno -capacidad 0,65- aguanta asi unas ochenta jornadas-persona
## antes de quedar seco, que es tiempo de sobra para que el jugador vea caer el
## rendimiento y reaccione.
const DEPLETION_PER_DAY := 0.008

## Y lo mismo, pero por UNIDAD recogida de verdad.
##
## Recoger y vaciar el sitio eran dos numeros que no se hablaban: el paraje
## perdia [DEPLETION_PER_DAY] por jornada trabajada, cogiera la persona el
## cesto lleno o volviera de vacio. Eso es lo que hacia que la recoleccion se
## leyera como un trabajo binario -se esta o no se esta- en vez de como lo que
## es: se va cogiendo, y el sitio se va quedando sin.
##
## No es un numero nuevo, es el mismo dividido por lo que se coge de verdad en
## una jornada: medido con `scripts/tests/CosechaVivaProbe.gd` en el sitio 56,
## 3,0 unidades por persona y jornada. Asi la merma TOTAL de una jornada normal
## sale igual que antes y lo unico que cambia es que ahora sigue a la mano que
## coge.
const UNIDADES_POR_JORNADA := 3.0
const DEPLETION_PER_UNIT := DEPLETION_PER_DAY / UNIDADES_POR_JORNADA

## Fraccion de las cifras nominales de `_yield_materials` que llega de verdad
## al almacen. Aquellas son «once horas de trabajo puro con destreza perfecta»,
## y una jornada real se va en camino, busqueda y vuelta. Medido en la
## simulacion: en torno al 7%.
const TYPICAL_YIELD_FRACTION := 0.07

## Tope de cada material, en unidades. Si no hay entrada, se recoge sin limite.
##
## Es la forma de decirle a la banda «de lena ya tenemos bastante». Cuando se
## llega al tope, ese material se deja en el monte: no se recoge, no ocupa
## sitio en el abrigo y la jornada se emplea en lo que falta.
var limits: Dictionary = {}


## Radio en el que un recolector bate el terreno buscando. Mas alla de esto ya
## no es prospectar el paraje, es cambiar de paraje.
@export var search_radius: float = 220.0

## Radio en el que se considera alcanzado un destino
@export var arrive_radius: float = 6.0

## Cuánto se aparta cada persona del centro del camino, en metros.
##
## El trazado de [Wayfinder] es UNO para todos, así que dos personas que
## comparten tramo se dibujan una dentro de otra mientras andan: el reparto de
## `_best_known_spot` sólo las separa al llegar al tajo. Se le da a cada una su
## carril, estable por `id` y no sorteado cada fotograma, que temblaría.
##
## Pendiente de playtest: dos metros y medio separan los cuerpos sin que la
## cuadrilla se deshilache ni se salga del paso por donde de verdad se pasa.
const LANE_SPREAD := 2.5

## Cuánto se aparta del paso medio cada persona, en tanto por uno.
##
## El carril separa de lado; esto separa a lo largo, y hacen falta los dos. El
## reparto áureo garantiza que dos personas no lleven el MISMO carril, no que no
## se rocen: con quince en la banda y cinco metros de ancho, los dos carriles más
## juntos quedan a menos de un palmo, y esos dos vuelven a andar pegados. Con
## paso distinto se separan solos a los pocos metros.
##
## Y además es cierto: no hay dos personas que anden al mismo paso.
const LANE_PACE := 0.06

## Raciones que se lleva una batida por jornada prevista fuera. Sin comida no
## se sale: una expedicion de tres dias sin provisiones no es una expedicion,
## es mandar a alguien a pasar hambre lejos de casa.
@export var expedition_days: int = 3

## Medios de cruce de la banda. En el Paleolitico no hay ninguno de los dos, y
## eso es justo lo que hace que el rio importe: define el territorio al que se
## puede llegar a pie. Conseguirlos abre media comarca de golpe.
@export var has_boat: bool = false
@export var has_bridge: bool = false

## Lo que el territorio tiene y lo que la banda sabe que tiene. Los pone la
## escena; sin ellos la simulacion funciona como antes.
var field: ResourceField
var knowledge: BandKnowledge

var people: Array[Inhabitant] = []

## El almacen de la banda, con materiales, peso y volumen. Antes era un solo
## numero de raciones; ahora sabe que la lena ocupa cuarenta litros el haz y
## que un abrigo pequeno se llena de lena antes que de comida.
var store := Storehouse.new()

## El utillaje de la banda, pieza a pieza y con su desgaste.
##
## Es lo que hace que la manufactura sea necesaria en vez de decorativa: las
## herramientas se rompen con el uso, y si nadie las repone la caza y la
## recoleccion caen solas sin que haga falta castigar a nadie.
var toolkit := Toolkit.new()

## El diario de la partida. Lo pone la escena; sin el, la simulacion funciona
## igual y no cuenta nada.
var chronicle: Chronicle

## El tiempo que hace hoy. Ver [Weather].
var weather := Weather.new()

## Los sitios con nombre que conoce la banda, y cual ha elegido el jugador
## para cada oficio. Ver [Parajes].
var parajes := Parajes.new()

## Hacia donde ha mandado el jugador que se explore, o ZERO si no ha mandado.
##
## Es la otra mitad del clic como verbo: señalar un paraje dice «id a trabajar
## ahi» y señalar terreno desnudo dice «id a MIRAR alli». La diferencia
## importa, porque lo segundo es una apuesta: no se sabe que hay.
var scout_order: Vector3 = Vector3.ZERO
var has_scout_order: bool = false

## A que distancia se da por cumplida una orden de exploracion.
const SCOUT_REACHED := 140.0

## --- El abrigo por dentro y por delante ----------------------------------
##
## `home_position` es UN punto, y con un solo punto la banda entera se apilaba
## encima del abrigo: los quince en el mismo metro cuadrado, a la intemperie,
## tanto de día como de noche. Una cueva no se habita así. Se duerme DENTRO y se
## hace todo lo demás DELANTE, en la campa de la boca, que es donde da la luz.
##
## Los dos puntos los pone [DemoMain] a partir de la boca de cueva de verdad
## -ver `CaveMouth.inside_point` y `forecourt_point`-. Sin ellos se cae en
## `home_position` y se comporta como antes.
var home_inside: Vector3 = Vector3.ZERO
var home_forecourt: Vector3 = Vector3.ZERO

## Cuánto se reparte la gente dentro de la galería y en la campa, en metros.
## Pendiente de playtest: es lo que decide si el abrigo se ve habitado o
## amontonado.
const CAVE_SPREAD := 3.2
const FORECOURT_SPREAD := 7.0

## Que mejoras del abrigo estan hechas. Ver [CampProjects].
##
## Son de ESTE abrigo y no de la banda: un hogar es un corro de piedras en el
## suelo de una cueva concreta, y al mudarse a otra hay que levantarlo otra vez.
## Ver `move_home`.
var camp_built: Dictionary = {}

## --- El hogar ------------------------------------------------------------
##
## El hogar dejó de ser un rótulo. Antes `_tend_camp` escribía «manteniendo el
## fuego» y ahí se acababa: ni gastaba leña, ni podía apagarse, ni pasaba nada
## si no lo cuidaba nadie. Ahora es una instalación con estado, y todo lo que
## el fuego permite —cocinar, ahumar, pasar la noche de invierno— cuelga de que
## esté encendido y no de que esté construido.

## Si hay brasas vivas. Se prende al terminar la obra y se apaga si falta leña
## o si no queda nadie en el hogar que lo cuide.
var hearth_lit: bool = false

## Jornada acumulada de quien está prendiéndolo otra vez.
var hearth_relight: float = 0.0

## Si alguien ha estado hoy al cuidado del fuego.
var _hearth_tended: bool = false

## Jornada de cuidados dada hoy a los heridos. Ver `_tend_the_hurt`.
var _care_given: float = 0.0

## Proyecto en curso, o -1 si no hay ninguno en cola.
var camp_queue: int = -1
var camp_progress: float = 0.0
var _camp_paid: bool = false

## Ascensiones completadas. Ver [Profession.Speciality.ASCENSION].
var ascents: int = 0

## Cuanto ve la banda desde una cumbre. Mucho de golpe, pero de lejos: la
## claridad de `BandKnowledge.see_from` ya cae con la distancia sola.
const ASCENT_SIGHT_RANGE := 1400.0

var _peaks: Array[Dictionary] = []
var _peak_found: bool = false

## Cumbres ya coronadas. Subir dos veces al mismo alto no aporta NADA -la
## vista ya esta descubierta- y sin embargo es lo que hacia el explorador:
## volvia una y otra vez al mismo sitio porque era el punto mas alto.
var _climbed: Array[Vector3] = []

## Dias transcurridos en la estacion en curso. Ver [_advance_local_season].
var season_day: int = 0


## Sitios de trabajo por actividad, en coordenadas de mundo
var work_sites: Dictionary = {}
var home_position: Vector3 = Vector3.ZERO

var day: int = 1
var hour: float = 6.0

var _terrain: TerrainGenerator


## El terreno, para quien tenga que apoyar algo en el suelo.
func terrain() -> TerrainGenerator:
	return _terrain


## La rejilla de navegacion, para quien quiera DIBUJARLA.
##
## Es lo que decide media simulacion y era invisible: cuando alguien se
## quedaba atascado habia que deducir la causa de un rotulo en vez de mirar el
## mapa y verla.
func navgrid() -> Navgrid:
	return _navgrid()
## Dónde vive cada persona dentro de [BandaCrowd]: qué variante de piel y qué
## hueco de ese `MultiMesh`. Antes esto era un `Node3D` por persona -una
## cápsula-, y no aguanta los miles de miembros de los que avisa
## `Inhabitant.gd`: ver [BandaCrowd].
var _bodies: Array[Vector2i] = []
## Hacia dónde mira cada persona, en radianes sobre Y. Sólo cambia cuando
## anda -una cápsula no necesitaba esto porque es igual de cualquier lado,
## una persona sí-.
var _headings: Array[float] = []
var _crowd: BandaCrowd
var _rng := RandomNumberGenerator.new()


## Arranca con la poblacion y las reservas que trae la partida
func setup(terrain: TerrainGenerator, home: Vector3, population: int, food: float) -> void:
	_terrain = terrain
	home_position = home

	# Capacidad del abrigo. Una cueva no es un almacen infinito: doce metros
	# cubicos utiles es un abrigo pequeno, y en eso caben trescientos haces de
	# lena y nada mas.
	store = Storehouse.new()
	store.capacity_litres = shelter_litres
	# Reserva de partida. Sin ella la banda arranca con la despensa vacia, y
	# como el hambre baja la efectividad, entra en barrena antes de la primera
	# cosecha: no es dificultad, es un arranque imposible.
	store.add(Materia.Kind.FRUTO_SECO, maxf(food, float(population) * 8.0))
	# Cada partida, distinta. Estaba clavada en una fecha, asi que la comarca
	# entera se comportaba igual siempre: los mismos picos en el mismo orden,
	# los mismos percances, el mismo tiempo.
	#
	# La semilla se IMPRIME. Un juego con azar de verdad es imposible de
	# depurar si no se puede repetir una partida concreta, y basta con poder
	# ponerla a mano cuando algo sale raro.
	# Y se puede FIJAR desde fuera: `SEMILLA=123` en el entorno. Sin eso, dos
	# ejecuciones de la misma sonda salen con valles distintos y no hay forma de
	# saber si un número mejoró por el arreglo o por la tirada.
	var forced := OS.get_environment("SEMILLA")
	game_seed = int(forced) if not forced.is_empty() 		else int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	_rng.seed = game_seed
	print("Semilla de partida: %d" % game_seed)

	# El utillaje con el que se llega al abrigo. Va CORTO a proposito: da para
	# arrancar y no para acomodarse, asi que la primera escasez de filo llega
	# a las pocas semanas y con ella la razon de poner a alguien a tallar.
	#
	# Todo de cuarcita, que es lo que hay en cualquier playa del Cantabrico. El
	# silex bueno esta lejos, y encontrarlo es media aventura.
	toolkit = Toolkit.new()
	for i in range(8):
		toolkit.craft(Tool.Kind.LASCA, Tool.Stuff.CUARCITA, 0.5)
	for i in range(2):
		toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA, 0.5)
	toolkit.craft(Tool.Kind.BURIL, Tool.Stuff.CUARCITA, 0.5)
	for i in range(2):
		toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.5)
	# NI CESTOS NI ODRES. Se llega con el filo justo y con las manos: el cesto
	# dobla lo que se trae de una jornada y el odre es lo que permite pasar el
	# dia lejos del agua -ver `_hand_out_containers`-, o sea que regalarlos al
	# empezar es regalar las dos primeras decisiones del taller.

	# La partida arranca EN PAUSA. Al fundar hay que repartir el trabajo, mirar
	# dónde se ha caído y decidir; que el reloj empiece a correr mientras el
	# jugador se orienta es quitarle la primera decisión de la partida.
	time_scale = 0.0

	# Se VACÍA, no se sustituye: `TechTree.camp_built` apunta a este mismo
	# diccionario para no tener dos verdades sobre si hay hogar, y cambiarlo
	# por uno nuevo dejaría al árbol mirando el de la partida anterior.
	camp_built.clear()
	camp_queue = -1
	camp_progress = 0.0
	hearth_lit = false
	hearth_relight = 0.0
	_hearth_tended = false
	_care_given = 0.0
	season_day = 0
	_peak_found = false

	# Cede el reloj de luz al de la banda. Sin esto el sol daba una vuelta
	# completa cada 24 segundos reales mientras la jornada de trabajo dura
	# 120: cinco amaneceres por cada dia de la banda.

	_crowd = BandaCrowd.new()
	_crowd.name = "Banda"
	add_child(_crowd)
	_crowd.setup(population)

	# La banda se crea ENTERA, con cupos: sorteando la edad persona a persona
	# salian bandas de doce crios y dos adultos. Ver [Inhabitant.create_band].
	for person: Inhabitant in Inhabitant.create_band(population, home, _rng):
		# Repartidos alrededor del abrigo para que no salgan apilados
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(4.0, 22.0)
		person.position = home + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		person.position.y = _terrain.get_height_at(person.position)
		people.append(person)
		var slot := _crowd.add_person()
		_bodies.append(slot)
		_headings.append(angle)
		_crowd.update(slot, person.position, angle, person.state, person.age_group)

	# El reparto de oficios NO va aqui: necesita que los tajos esten montados,
	# y en este punto todavia no lo estan. Lo llama la escena despues.


## Coloca un sitio de trabajo para una actividad
## Si desde el poblado se puede llegar andando a un punto.
##
## Solo mira el trayecto recto, que es como anda la gente. No es un buscador de
## caminos: si hiciera falta rodear el rio por un vado a dos kilometros, este
## metodo dice que no se llega, y esta bien que lo diga, porque a efectos de
## una jornada de trabajo no se llega.
##
## El ultimo tramo, el del radio de llegada, no se comprueba: a un tajo de
## pesca se llega ESTANDO en la orilla, no metiendose en el cauce.
func can_reach(world_position: Vector3, margin: float = -1.0) -> bool:
	if _terrain == null:
		return true

	var stop_short: float = arrive_radius if margin < 0.0 else margin
	var to_target := world_position - home_position
	to_target.y = 0.0
	var distance := to_target.length()
	if distance <= stop_short:
		return true

	var stop := home_position + to_target.normalized() * (distance - stop_short)
	# Las dos cosas que cortan el paso: el agua honda y el cortado. Mirar solo
	# el agua dejaba asignar tajos detras de una pared, y la gente salia hacia
	# ellos para quedarse atascada.
	if not _terrain.path_is_passable(home_position, stop, has_boat, has_bridge):
		return false

	# Y lo que de verdad manda: la REJILLA, que es quien traza los caminos.
	#
	# La linea recta de arriba dice si el terreno deja pasar por el medio; no
	# dice si hay camino andable, que es otra cosa. Medido en el sitio 56:
	# `can_reach` daba verdadero para el tajo de pesca y la rejilla decia
	# `connected(casa, rio) = false` —cuatro zonas, el abrigo en una y el rio
	# en otra—. Se plantaba un tajo al que nadie podia llegar, la gente salia
	# a por el, no habia ruta, y se quedaba dando vueltas por el monte sin
	# traer un solo pez. Preguntar dos cosas distintas y creerse la que no
	# manda es como se planta un sitio de trabajo imposible.
	return _navgrid().connected(home_position, world_position)


## Muda la banda a otro abrigo.
##
## Lo que se lleva es lo que cabe en la espalda; lo que se queda es el abrigo.
## El hogar, el secadero y todo lo que se hubiera levantado son de aquella
## cueva: en la nueva se empieza otra vez por el corro de piedras.
##
## De momento no lo llama nadie —la slice ocupa un solo abrigo, ver
## SLICE_PALEOLITICO §5— y está escrito ahora porque el día que la banda se mude
## la alternativa sería descubrir que arrastraba consigo un hogar imaginario.
func move_home(world_position: Vector3) -> void:
	if home_position.distance_to(world_position) < arrive_radius:
		return
	home_position = world_position
	home_inside = Vector3.ZERO
	home_forecourt = Vector3.ZERO
	camp_built.clear()
	camp_queue = -1
	camp_progress = 0.0
	_camp_paid = false
	hearth_lit = false
	hearth_relight = 0.0
	_note(Chronicle.Kind.OBRA,
		"La banda se muda de abrigo. Lo levantado se queda atrás: aquí no hay "
			+ "hogar todavía.", 2)


func set_work_site(activity: Subsistence.Activity, world_position: Vector3) -> void:
	work_sites[activity] = world_position


## Reparte a los adultos entre las actividades que haya en el sitio
## Reparto inicial de oficios.
##
## Es PUBLICO y hay que llamarlo cuando ya existen los tajos. Al reordenar el
## montaje para que la comprobacion de alcance tuviera terreno, esto pasó a
## correr antes que los tajos, se encontraba la lista vacia y salia sin
## asignar a nadie: la banda entera se quedaba durmiendo y no avanzaba ni el
## conocimiento ni las tecnicas.
func assign_default_jobs() -> void:
	if work_sites.is_empty():
		return

	# Oficios que tienen tajo montado, mas los que no lo necesitan
	var available: Array[Profession.Job] = []
	for job: int in Profession.CATALOGUE.keys():
		var activity := Profession.job_activity(job as Profession.Job)
		if activity < 0 or work_sites.has(activity):
			available.append(job as Profession.Job)
	if available.is_empty():
		return

	# Orden de prioridad: primero lo que da de comer. Repartiendo en ciclo por
	# el catalogo, el hogar se llevaba seis de quince personas y la banda se
	# moria de hambre con un tercio de la gente cuidando el fuego.
	var priority: Array[Profession.Job] = [
		Profession.Job.RECOLECCION, Profession.Job.RECOLECCION,
		Profession.Job.CAZA, Profession.Job.RIBERA,
		Profession.Job.RECOLECCION,
		Profession.Job.MANUFACTURA, Profession.Job.HOGAR,
		# OCIOSO no entra en el reparto: es adonde va lo que sobra, no un
		# sitio al que mandar gente
	]

	# El reparto de partida escribe PRIORIDADES, no oficios: a partir de ahi
	# manda `apply_priorities`, que es lo unico que toca `person.job`.
	#
	# A cada cual se le pone primero un oficio distinto -para que la banda
	# salga repartida y no toda al mismo sitio- y de segundo todo lo demas que
	# pueda hacer, para que nadie se quede parado si su primera opcion no da.
	var next := 0
	for person: Inhabitant in people:
		person.priorities.clear()

		for attempt in range(priority.size()):
			var job: Profession.Job = priority[(next + attempt) % priority.size()]
			# La exploracion no se reparte sola: cuesta comida a cambio de
			# mapa, y esa es una decision del jugador
			if job == Profession.Job.EXPLORACION or not available.has(job):
				continue
			if Profession.can_do(job, person):
				for task: int in Profession.tasks_of(job):
					person.set_priority(task, 1)
				next += 1
				break

		for job_key: int in available:
			if job_key == Profession.Job.EXPLORACION \
					or job_key == Profession.Job.OCIOSO:
				continue
			if person.priority_in_job(job_key) > 0:
				continue
			if Profession.can_do(job_key as Profession.Job, person):
				for task: int in Profession.tasks_of(job_key as Profession.Job):
					person.set_priority(task, 2)

	apply_priorities()


## Jornadas-persona de trabajo que aguantan todavia los parajes CONOCIDOS de
## una actividad antes de quedar secos.
##
## Es la cifra que de verdad se pregunta el jugador: no un porcentaje, sino
## cuanto le queda. Sale del propio modelo de agotamiento, no de una
## estimacion: lo que queda en cada celda dividido por lo que se lleva una
## persona en una jornada.
func remaining_person_days(activity: Subsistence.Activity) -> float:
	if field == null or knowledge == null:
		return 0.0

	var total := 0.0
	for z in range(field.height):
		for x in range(field.width):
			var centre := field.cell_center(x, z)
			if knowledge.familiarity_at(activity, centre) < BandKnowledge.KNOWN_ENOUGH:
				continue
			total += field.abundance_cell(activity, x, z)

	return total / DEPLETION_PER_DAY


## Cuanto rinde este material en esta actividad, en una jornada completa.
##
## Mira primero las especialidades de verdad -[SPECIALITY_YIELDS], que es lo
## que usa un trabajador real y tiene numeros mas finos, como el hueso del
## asta que solo sale de caza mayor- y si ninguna lo tiene, cae al numero
## generico de [_yield_materials]. Hace falta mirar las dos: `_gathering_yields`
## trae cosas de temporada -bellota, miel, seta- que no estan en ninguna
## especialidad suelta, y `SPECIALITY_YIELDS` trae cosas -concha, asta,
## silex- que no estan en el generico. Ninguna de las dos por si sola cubre
## todo lo que un paraje puede llegar a enseñar.
##
## Y si NINGUNA de las dos tiene el material bajo ESTA actividad, se busca
## en CUALQUIER actividad y oficio. Un paraje enseña extras que no son lo
## suyo -resina en un cantizal, yesca en un desmogadero-, y esos extras
## vienen del catalogo de RECOLECCION aunque el sitio sea de otra cosa. La
## resina no rinde menos por asomar en materia prima que por asomar en un
## hayedo: es la misma resina. Sin este ultimo escalon, cualquier extra
## fuera de su actividad natural se quedaba sin cifra y caia a la palabra
## de siempre -"a manta", "cuatro cosas"-, que es justo lo que no se quiere
## cuando se pide que la cantidad se vea SIEMPRE.
func _yield_per_day(activity: Subsistence.Activity, kind: Materia.Kind) -> float:
	var best: float = _yield_materials(activity).get(kind, 0.0)
	for speciality: int in Profession.Speciality.values():
		if Profession.SPECIALITY_ACTIVITY.get(speciality, -1) != activity:
			continue
		var table: Dictionary = SPECIALITY_YIELDS.get(speciality, {})
		best = maxf(best, float(table.get(kind, 0.0)))
	if best > 0.0:
		return best

	for other: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
			Subsistence.Activity.MATERIA_PRIMA]:
		best = maxf(best, float(_yield_materials(other as Subsistence.Activity).get(kind, 0.0)))
	for speciality: int in Profession.Speciality.values():
		var table: Dictionary = SPECIALITY_YIELDS.get(speciality, {})
		best = maxf(best, float(table.get(kind, 0.0)))
	return best


## Unidades de un material que quedan por recoger en los parajes conocidos.
func remaining_units(activity: Subsistence.Activity, kind: Materia.Kind) -> float:
	var per_day := _yield_per_day(activity, kind)
	if per_day <= 0.0:
		return 0.0
	var season := ResourceField.seasonal_factor(activity, GameState.season)
	return per_day * TYPICAL_YIELD_FRACTION * season * remaining_person_days(activity)


## Unidades de un material que quedan por recoger en ESTE paraje en
## concreto -no en todos los conocidos de la actividad, que es lo que
## pregunta [remaining_units]-. Misma cuenta, un solo sitio: lo que queda
## en la celda entre lo que se lleva una persona en una jornada.
func remaining_units_at(activity: Subsistence.Activity, kind: Materia.Kind,
		cell_x: int, cell_z: int) -> float:
	if field == null:
		return 0.0
	var per_day := _yield_per_day(activity, kind)
	if per_day <= 0.0:
		return 0.0
	var season := ResourceField.seasonal_factor(activity, GameState.season)
	var cell_days := field.abundance_cell(activity, cell_x, cell_z) / DEPLETION_PER_DAY
	return per_day * TYPICAL_YIELD_FRACTION * season * cell_days


## Lo mismo, pero para la mancha entera de un paraje. Es la cifra que se
## enseña en su ficha: la cuadrilla trabaja el sitio, no una celda suelta.
func remaining_units_in(paraje: Paraje, activity: Subsistence.Activity,
		kind: Materia.Kind) -> float:
	if field == null or paraje == null:
		return 0.0
	var per_day := _yield_per_day(activity, kind)
	if per_day <= 0.0:
		return 0.0
	var season := ResourceField.seasonal_factor(activity, GameState.season)
	var stock := field.stock_fraction_around(activity, paraje.position, paraje.extent)
	var cell_days := field.abundance_cell(activity, paraje.cell_x, paraje.cell_z) \
		/ DEPLETION_PER_DAY
	# El fondo de la celda del centro da la escala; la mancha, cuánto queda
	# de verdad en ella. Sin lo segundo la cifra no bajaba con las visitas.
	return per_day * TYPICAL_YIELD_FRACTION * season * cell_days * stock


## Decide qué especialidad ejerce hoy quien no tiene una fijada.
##
## Se elige la que más lejos esté de su pedido permanente, NO por turnos. Con
## turnos te encuentras al tallador trenzando cordel mientras la banda se queda
## sin puntas, que es justo lo que no debe pasar.
func _choose_speciality(person: Inhabitant) -> int:
	if person.speciality != Profession.Speciality.NINGUNA:
		return person.speciality

	var options: Array = Profession.specialities_of(person.job as Profession.Job)
	if options.is_empty():
		return Profession.Speciality.NINGUNA

	var worst: int = options[0]
	var worst_ratio := INF

	for speciality: int in options:
		var ratio := _speciality_pressure(speciality as Profession.Speciality)
		if ratio < worst_ratio:
			worst_ratio = ratio
			worst = speciality

	return worst


## Cuanto de cubierto esta lo que produce una especialidad, de 0 a 1.
##
## Para el taller sale del utillaje: la talla se elige cuando faltan lascas, no
## cuando falta piedra. Es la diferencia entre mirar el almacen y mirar lo que
## la banda necesita de verdad, y es lo que evita al tallador trenzando cordel
## mientras se acaban las puntas.
func _speciality_pressure(speciality: Profession.Speciality) -> float:
	var makes: Array = SPECIALITY_MAKES.get(speciality, [])
	if not makes.is_empty():
		# La cobertura PEOR de lo que hace, no la media: una especialidad con
		# tres cosas cubiertas y una a cero tiene un problema, no un notable
		var worst := INF
		for kind: int in makes:
			worst = minf(worst, tool_coverage(kind as Tool.Kind))
		return worst

	# Las de comida no producen UN material: producen comida, y la comida se
	# mide en raciones y contra los dias de reserva que se quieran tener. Sin
	# esto devolvian 1.0 fijo -"satisfecho"- y no ganaban un empate jamas:
	# poner la pesca de orilla en prioridad 1 al lado de la recoleccion no
	# mandaba a nadie al rio.
	if ESPECIALIDADES_DE_COMIDA.has(speciality):
		var mouths := 0.0
		for person: Inhabitant in people:
			mouths += person.daily_food()
		var larder: float = food_cap if food_cap > 0.0 else mouths * DIAS_DE_RESERVA
		return store.food_rations() / maxf(larder, 0.001)

	# El HOGAR ya no tiene especialidades -lo hace todo, ver
	# `Profession.SPECIALITIES`-, asi que aqui no llega ninguna suya. Tenia tres
	# ramas -yesquero, ahumado, cuidado- y se han ido con ellas.

	# Exploracion y demas: se sigue mirando el material que producen
	var materials := speciality_outputs(speciality)
	if materials.is_empty():
		return 1.0
	# La PEOR de las que trae, por el mismo motivo que en el taller: quien
	# trae leña y fibra tiene un problema si falta la fibra, aunque la leña
	# sobre.
	var worst_ratio := INF
	for material: int in materials:
		var target: float = float(limits.get(material, 0.0))
		if target <= 0.0:
			target = float(people.size())
		worst_ratio = minf(worst_ratio,
			store.amount(material as Materia.Kind) / maxf(target, 0.001))
	return worst_ratio


## Qué material produce cada especialidad. -1 si no produce ninguno todavía.
##
## De momento apunta a los materiales que ya existen; cuando estén las
## herramientas con su desgaste, esto pasará a devolverlas a ellas.
func speciality_output(speciality: Profession.Speciality) -> int:
	var out := speciality_outputs(speciality)
	return out[0] if not out.is_empty() else -1


## Las especialidades que traen COMIDA, sea del monte, del coto o del rio.
##
## Van juntas porque se miden igual: contra las raciones que hay guardadas y
## los dias de reserva que se quieren tener, no contra un material suelto. Un
## pescador y un forrajeador compiten por lo mismo -llenar la despensa-, y el
## reparto tiene que poder empatarlos y luego separarlos por apiñamiento.
##
## Faltaban todas menos el forrajeo, y por eso subir la pesca de orilla a
## prioridad 1 no mandaba a nadie al rio: empatada con la recoleccion, la
## pesca devolvia 1.0 -"satisfecho"- y perdia siempre.
const ESPECIALIDADES_DE_COMIDA := [
	Profession.Speciality.FORRAJEO,
	Profession.Speciality.TRAMPAS,
	Profession.Speciality.CAZA_MENOR,
	Profession.Speciality.CAZA_MAYOR,
	Profession.Speciality.MARISQUEO,
	Profession.Speciality.ORILLA,
	Profession.Speciality.ALTURA,
]


## Cuantos dias de comida se quieren tener guardados cuando el jugador no ha
## puesto tope. Es el listón contra el que se mide si hace falta salir a
## recolectar o si ya vale con lo que hay.
const DIAS_DE_RESERVA := 12.0


## Que materiales trae o gasta cada especialidad, para saber si hace falta.
##
## Las de RECOLECCION estaban fuera de esta tabla, y eso las dejaba a todas
## con la misma presion -1.0, "satisfecha"-: puestas las tres al mismo nivel
## de prioridad, el desempate se lo llevaba siempre el forrajeo por ser el
## primero de `Profession.SPECIALITIES`, y luego el habito lo fijaba para
## siempre. Medido en el sitio 56: doce personas con forrajeo, leña y cantera
## las tres a nivel 1, y a los trece dias el almacen seguia con 0,0 de
## cuarcita, 0,0 de fibra y 0,0 de leña. Sin fibra ni piedra el taller no
## puede tallar nada, asi que la manufactura no arrancaba nunca por mucho que
## el jugador la pusiera la primera.
func speciality_outputs(speciality: Profession.Speciality) -> Array[int]:
	match speciality:
		Profession.Speciality.TALLA: return [Materia.Kind.PIEDRA]
		Profession.Speciality.ASTA: return [Materia.Kind.HUESO]
		Profession.Speciality.PELETERIA: return [Materia.Kind.PIEL]
		Profession.Speciality.CORDELERIA: return [Materia.Kind.FIBRA]
		Profession.Speciality.LENA_FIBRA:
			return [Materia.Kind.FIBRA, Materia.Kind.LENA]
		Profession.Speciality.CANTERA: return [Materia.Kind.PIEDRA]
		_: return []


## Cuanta gente hay en cada oficio
func job_counts() -> Dictionary:
	var counts := {}
	for person: Inhabitant in people:
		counts[person.job] = int(counts.get(person.job, 0)) + 1
	return counts


## Pone a `count` personas en un oficio, quitandolas de otros.
##
## Devuelve cuantas se pudieron colocar de verdad: puede ser menos de las
## pedidas si no hay quien cumpla los requisitos.
## Fija -o quita- la especialidad de toda la gente de un oficio.
func set_speciality(job: Profession.Job, speciality: Profession.Speciality) -> void:
	for person: Inhabitant in people:
		if person.job == job:
			person.speciality = speciality
			person.current_speciality = speciality


## Cuánta gente hay en cada especialidad de un oficio, contando lo que ejercen
## HOY: quien rota cuenta en la que le ha tocado.
func speciality_counts(job: Profession.Job) -> Dictionary:
	var counts := {}
	for person: Inhabitant in people:
		if person.job != job:
			continue
		counts[person.current_speciality] = int(
			counts.get(person.current_speciality, 0)) + 1
	return counts


## Cuanta gente hay en un oficio, moviendo PRIORIDADES.
##
## Se conserva porque es comodo para las pruebas y para el reparto automatico,
## pero ya no toca `person.job` directamente: pone o quita la prioridad mas
## alta y deja que `apply_priorities` decida. Asi no hay dos caminos que se
## pisen.
func set_job_count(job: Profession.Job, count: int) -> int:
	var current: Array[Inhabitant] = []
	var spare: Array[Inhabitant] = []
	for person: Inhabitant in people:
		if person.job == job:
			current.append(person)
		elif Profession.can_do(job, person) and _is_spare(person):
			spare.append(person)

	# Sobran: los que salgan van al hogar, que lo puede hacer casi cualquiera
	# Los que salgan pierden la prioridad de ESTE oficio. Si no tienen otra,
	# `apply_priorities` los dejara sin oficio.
	var floor_count := MIN_HEARTH if job == Profession.Job.HOGAR else 0
	var target := maxi(count, floor_count)
	while current.size() > target:
		var leaving: Inhabitant = current.pop_back()
		for task: int in Profession.tasks_of(job):
			leaving.set_priority(task, 0)

	# Faltan: se cogen SOLO de los que estan libres, dandoles este oficio como
	# primera opcion
	while current.size() < count and not spare.is_empty():
		var joining: Inhabitant = spare.pop_front()
		# Una tarea del oficio QUE SE PUEDA HACER HOY, no la primera de la
		# lista a ciegas.
		#
		# La primera de Caza es Trampas, y armar trampas necesita fibra y leña
		# en el abrigo -ver `_speciality_can_work`-. Sin ellas, pedir cuatro
		# cazadores colocaba a cuatro personas en una tarea que el reparto
		# descarta acto seguido, y el jugador veia el numero volver a cero sin
		# que nadie le dijera por que.
		var wanted: int = Profession.tasks_of(job)[0]
		for task: int in Profession.tasks_of(job):
			if _speciality_can_work(
				Profession.task_speciality(task) as Profession.Speciality):
				wanted = task
				break
		joining.set_priority(wanted, 1)
		current.append(joining)

	apply_priorities()

	var placed := 0
	for person: Inhabitant in people:
		if person.job == job:
			placed += 1
	return placed


## Reparte el trabajo del dia a partir de las prioridades de cada cual.
##
## Sustituye al reparto por numeros, que tenia dos problemas que el jugador
## fue encontrando uno a uno: sumar a un oficio le robaba gente a otro sin
## decirlo, y no habia forma de ver de un vistazo quien podia hacer que.
##
## Aqui nadie «es» cazador: cada jornada, cada persona hace lo que mas arriba
## tenga en su lista de entre lo que puede hacer. Es como funciona una banda
## de verdad, y de paso el reparto deja de ser un juego de suma cero contra la
## interfaz.
## Si este oficio tiene algún sitio de verdad al que mandar gente hoy.
##
## El hogar, el taller y la exploración lo tienen siempre: se trabaja en el
## campamento, sobre lo que hay en el abrigo, o se sale a abrir mapa. Los
## que sacan cosas del monte, no: si no se conoce ningún paraje suyo, ni
## hay un sitio de reserva de la fundación, ni queda un paraje que lo
## sirva, salir es andar por andar. Sin esto, alguien con recolección de
## primera y taller de segunda salía igual a un valle que no daba nada en
## vez de bajar a su segunda opción.
## Si esta TAREA tiene adonde ir. Por la especialidad y no por el oficio.
##
## La diferencia no es un detalle: la cantera es una especialidad de
## recoleccion cuya actividad es MATERIA_PRIMA, no RECOLECCION. Mirando el
## oficio, un cantero con su cantizal a la vista se quedaba sin trabajo
## porque no hubiera avellanas en el valle, y al reves, un forrajeador
## entraba a recolectar sin nada que recolectar porque hubiera un cantizal.
func _task_has_somewhere(job: Profession.Job, task: int) -> bool:
	var speciality := Profession.task_speciality(task)
	return _activity_has_somewhere(job, int(Profession.activity_of(job, speciality)))


func _job_has_somewhere(job: Profession.Job) -> bool:
	return _activity_has_somewhere(job, Profession.CATALOGUE[job]["activity"] as int)


func _activity_has_somewhere(job: Profession.Job, activity: int) -> bool:
	if activity < 0:
		return true
	if job == Profession.Job.EXPLORACION:
		return true
	# El taller figura en la tabla con actividad MATERIA_PRIMA -es de donde
	# saca lo que talla-, pero no sale al monte a por ella: trabaja en el
	# abrigo sobre lo que ya está guardado, así que no necesita paraje. Que
	# tenga o no con qué trabajar lo decide `_speciality_can_work`, que es
	# quien sabe de recetas y de lo que hay en el almacén.
	if job == Profession.Job.MANUFACTURA:
		return true
	# Sin mundo montado no hay nada que comprobar, y desde luego no hay que
	# dejar a la banda entera sin oficio por ello: pasa en las pruebas y en
	# el rato entre crear el asentamiento y levantar el campo de recursos.
	if field == null:
		return true

	var act := activity as Subsistence.Activity
	# Si hoy no se ha podido llegar a ningun tajo de esta actividad, no la
	# hay: el reparto tiene que bajar a esa gente a su siguiente oficio en vez
	# de dejarla mirando el rio desde el campamento.
	if _unreachable_today.has(int(act)):
		return false
	if work_sites.has(act):
		return true
	if not (_known_spots.get(act, []) as Array).is_empty():
		return true
	if parajes:
		for paraje: Paraje in parajes.list:
			if paraje.serves(act):
				return true
	return false


## Cuanto se encarece una especialidad por cada persona que ya va a ella en
## este mismo reparto. Es lo que hace que una banda con tres cosas empatadas
## se reparta entre las tres en vez de irse entera a la primera.
const APINAMIENTO := 0.35

## La ventaja que tiene seguir en lo de ayer. Poca a proposito: sirve para no
## cambiar de tajo por un pelo, no para congelar el reparto del primer dia.
const HABITO := 0.08


## Por que una tarea que el jugador ha marcado NO se puede hacer hoy. "" si
## si se puede.
##
## Existe porque el reparto la descartaba en silencio. Queja literal: «Haro no
## deberia tener como profesion principal trampas cuando tiene pesca de orilla
## en 1; la seleccion del jugador tiene prioridad sobre todo». Y la tiene: lo
## marcado manda salvo que ese dia sea IMPOSIBLE -no hay adonde ir, no hay con
## que trabajar, la despensa esta al tope-. Lo que no puede ser es que sea
## imposible y no se diga: desde fuera parece que el panel no sirve.
func task_blocked_by(person: Inhabitant, task: int) -> String:
	var job := Profession.task_job(task)
	if not Profession.can_do(job, person):
		return "no puede: no le toca por edad o por criar"

	if food_is_capped() and _feeds_the_band(job):
		return "la despensa esta al tope; nadie sale a por mas comida"

	var speciality := Profession.task_speciality(task)
	if not _task_has_somewhere(job, task):
		var act := Profession.activity_of(job, speciality)
		if _unreachable_today.has(int(act)):
			return "hoy no hay camino a ningun sitio de %s" 				% Subsistence.activity_name(act).to_lower()
		return "no se conoce ningun sitio de %s" 			% Subsistence.activity_name(act).to_lower()

	if not _speciality_can_work(speciality):
		return "no hay materia prima en el abrigo para eso"

	return ""


## La tarea que el jugador ha puesto MAS ARRIBA para esta persona, se pueda
## hacer hoy o no. -1 si no ha marcado ninguna.
func top_choice(person: Inhabitant) -> int:
	var best := -1
	var best_level := 99
	for job_key: int in Profession.CATALOGUE:
		if job_key == Profession.Job.OCIOSO:
			continue
		for task: int in Profession.tasks_of(job_key as Profession.Job):
			var level := person.priority_for(task)
			if level <= 0 or level >= best_level:
				continue
			best_level = level
			best = task
	return best


func apply_priorities() -> void:
	# Cuanta gente lleva ya asignada cada especialidad en este reparto.
	var taken: Dictionary = {}
	for person: Inhabitant in people:
		var best_level := 99
		# TODAS las tareas empatadas al mejor nivel, no solo la primera que
		# se encuentre. Con "level >= best_level: continue" de antes, un
		# empate entre OFICIOS distintos -no solo entre especialidades del
		# mismo, que ya se llevaba bien- lo ganaba quien apareciera primero
		# en `Profession.CATALOGUE`, sin mirar para nada lo que el jugador
		# hubiera puesto. Medido: exploracion puesta a nivel 1 no ganaba
		# NUNCA a una recoleccion que ya estuviera a nivel 1 de antes, asi
		# que subir su prioridad en la pantalla de Trabajos no hacia nada
		# -la banda seguia recolectando igual, en silencio.
		var candidates: Array[int] = []

		var larder_full := food_is_capped()

		for job_key: int in Profession.CATALOGUE:
			if job_key == Profession.Job.OCIOSO:
				continue
			if not Profession.can_do(job_key as Profession.Job, person):
				continue
			# Con la despensa al tope nadie sale a BUSCAR mas comida. Se
			# bloquea el reparto, no el trabajo empezado: quien viene cargado
			# entrega igual, y quien esta en una pieza abatida la termina de
			# traer. Lo que se para es abrir tajo nuevo.
			if larder_full and _feeds_the_band(job_key as Profession.Job):
				continue
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				# Si esa TAREA no tiene ADONDE ir, no cuenta: se pasa a la
				# siguiente de la lista del jugador en vez de mandar a
				# alguien a recolectar donde no hay nada que recoger. La
				# prioridad dice en qué orden se prefieren las cosas, no que
				# haya que salir a hacer la primera aunque no exista: quien
				# tiene recolección arriba y taller debajo se queda tallando
				# cuando el monte no da, que es lo que haría cualquiera.
				#
				# Por TAREA y no por oficio: la cantera es recolección para el
				# jugador y materia prima para el terreno, y mirando el oficio
				# un cantero se quedaba parado por no haber avellanas.
				if not _task_has_somewhere(job_key as Profession.Job, task):
					continue
				# Y el taller, ademas, solo cuenta si tiene con que trabajar. La
				# materia prima la traen los recolectores: si no la han traido,
				# mala suerte, el artesano se va a su siguiente oficio en vez de
				# quedarse el dia entero delante de un banco vacio.
				if not _speciality_can_work(
						Profession.task_speciality(task) as Profession.Speciality):
					continue
				var level := person.priority_for(task)
				if level <= 0 or level > best_level:
					continue
				if level < best_level:
					best_level = level
					candidates.clear()
				candidates.append(task)

		# Sin nada que pueda o quiera hacer, se queda esperando destino
		if candidates.is_empty():
			Profession.assign(Profession.Job.OCIOSO, person)
			person.current_speciality = Profession.Speciality.NINGUNA
			continue

		# Empate al mismo nivel: puede ser entre especialidades de un mismo
		# oficio -la rotacion de siempre- o, ahora tambien, entre OFICIOS
		# distintos que el jugador haya puesto igual de arriba.
		var best: int = candidates[0]
		if candidates.size() > 1:
			# La exploracion no compite por necesidad: no trae material que
			# medir, asi que su presion siempre sale "satisfecha" y jamas
			# ganaria un empate contra un oficio con carencia real -ver
			# `_speciality_pressure`. Pero es la UNICA decision de las que
			# entran aqui que toma el jugador a mano, no la banda sola: "la
			# exploracion no se reparte sola... es una decision del
			# jugador". Si la ha puesto al mismo nivel que otro oficio, gana
			# ella sin mas vuelta -para eso ha tocado el mando.
			var explore_candidate := -1
			for task: int in candidates:
				if Profession.task_job(task) == Profession.Job.EXPLORACION:
					explore_candidate = task
					break

			if explore_candidate >= 0:
				best = explore_candidate
			else:
				# Si no hay exploracion de por medio, gana lo que mas falte,
				# con dos correcciones.
				#
				# Una: lo que ya se estaba haciendo sale con ventaja -no se
				# cambia de tajo cada jornada por deportividad-. Antes era
				# mas que ventaja, era ley: si la tarea de ayer seguia
				# empatada se quedaba y no se miraba nada mas, asi que el
				# reparto del primer dia se congelaba para el resto de la
				# partida.
				#
				# Dos: cada persona que ya va a esa especialidad HOY se la
				# encarece un poco. Sin eso, doce personas con las mismas
				# prioridades toman la misma decision doce veces y salen las
				# doce a lo mismo; con eso, la banda se REPARTE entre lo que
				# tiene empatado, que es lo que el jugador quiere decir
				# cuando pone tres cosas al mismo nivel.
				var current_task := Profession.task_id(person.job as Profession.Job,
					person.current_speciality as Profession.Speciality)
				var worst_ratio := INF
				for task: int in candidates:
					var speciality := Profession.task_speciality(task)
					var ratio := _speciality_pressure(speciality)
					ratio += float(taken.get(int(speciality), 0)) * APINAMIENTO
					if task == current_task:
						ratio -= HABITO
					if ratio < worst_ratio:
						worst_ratio = ratio
						best = task

		var job := Profession.task_job(best)
		# La especialidad va DENTRO de `assign` y no despues.
		#
		# Antes se asignaba el oficio primero y se ponia la especialidad
		# despues, asi que `assign` calculaba la actividad -de que parte del
		# monte se tira- con la especialidad de AYER y ya no se volvia a
		# tocar. Un pescador de orilla se quedaba con la actividad del dia
		# anterior: no contaba como pesca ni para pedir aparejo, ni para el
		# remonte del salmon, ni para las jornadas que dan las tecnicas.
		# Medido: 260 dias con cuatro personas en la orilla y CERO jornadas
		# de pesca en el arbol de tecnicas.
		Profession.assign(job, person, Profession.task_speciality(best))
		var chosen := int(person.speciality)
		taken[chosen] = int(taken.get(chosen, 0)) + 1

	_ensure_hearth()


## Cuantas especialidades del oficio que va a hacer tiene esta persona a ese
## mismo nivel de prioridad.
func _tied_specialities(person: Inhabitant, level: int) -> int:
	var count := 0
	for task: int in person.priorities:
		if int(person.priorities[task]) != level:
			continue
		if Profession.task_job(task) != person.job:
			continue
		count += 1
	return count


## Pone a todo el mundo una prioridad para un oficio, si puede hacerlo.
func set_priority_all(job: Profession.Job, level: int) -> void:
	for person: Inhabitant in people:
		if Profession.can_do(job, person):
			person.set_priority(job, level)
	apply_priorities()


## Cuanta gente hace falta como minimo en el hogar.
##
## Uno. Sin nadie no se mantiene el fuego, las obras del abrigo no avanzan y
## la carne fresca se pierde en cuatro dias.
const MIN_HEARTH := 1


## --- Lo que cuesta tener fuego ------------------------------------------
##
## Todos estos números son de BALANCEO y están sin calibrar: se dejan aquí,
## juntos y con nombre, para poder moverlos en playtest de una tacada. Lo que
## está decidido es que el fuego cueste y que apagarse duela; cuánto, no.

## Leña que se lleva el hogar en una jornada, en unidades de `Materia.Kind.LENA`.
const HEARTH_WOOD_PER_DAY := 2.0

## Cuánto más se gasta en invierno: el fuego se aviva y además se pasa el día
## dentro.
const HEARTH_WINTER_FACTOR := 1.8

## Leña que se lleva prenderlo de nuevo.
const HEARTH_RELIGHT_WOOD := 1.0

## Jornadas de alguien del hogar que cuesta reavivarlo.
const HEARTH_RELIGHT_DAYS := 0.5

## Cuánto rinde el yesquero al prender y cuánta leña ahorra al cuidarlo.
const YESQUERO_BONUS := 1.8
const YESQUERO_SAVING := 0.8

## Cuánto rinde el secadero atendido por quien sabe ahumar.
const AHUMADO_BONUS := 1.6

## Cuántos días de convalecencia adelanta al cabo de una jornada quien cuida a
## los heridos. Lo hace quien atiende el hogar, que ya no se reparte en
## especialidades: cuidar es una de las cosas que hace, no un
## rótulo: sin esto no cambiaría nada en la partida.
const CUIDADO_DAYS := 1

## Fatiga por hora que añade dormir en el abrigo con el fuego apagado, y sólo
## en invierno: el resto del año una cueva se aguanta sin fuego.
const HEARTH_COLD_FATIGUE := 3.0


## --- Lo que hace falta para dormir fuera ---------------------------------
##
## Quien pernocta fuera sólo gastaba comida de mochila y recuperaba menos
## fatiga. Una expedición de otoño en Cantabria sin tienda ni hoguera no es
## «descansar peor»: es la clase de noche de la que se vuelve con algo roto.
## También aquí lo decidido es que duela, no cuánto.

## Piel de tienda por persona. NO se gasta: se lleva y se devuelve al abrigo,
## que es lo que se hace con una tienda. Lo que se pierde es la noche que no se
## llevó.
const VIVAC_PIEL := 1.0

## Leña de hoguera por persona y NOCHE. Ésta sí arde.
const VIVAC_LENA := 1.0

## Cuánto multiplica el riesgo de percance cada una de las dos cosas que falte.
## Con las dos, casi seis veces: dormir al raso, mojado y sin fuego, lejos de
## casa, es de las peores decisiones que se pueden tomar en este juego.
const VIVAC_RIESGO := 2.4

## Cuánta recuperación de fatiga por hora se pierde por cada cosa que falte.
## Lo que había antes —descansar peor y nada más— se queda, pero deja de ser la
## única consecuencia.
const VIVAC_REST_LOSS := 1.5

## Noches de leña que se cargan de más. Una salida que se alarga un día no
## debería quedarse sin hoguera justo la última noche, que es la que pilla más
## lejos de casa. Medido sin margen: la mitad de las noches se dormían sin
## fuego aun con el almacén lleno, porque la cuenta de días se redondeaba a la
## baja.
const VIVAC_MARGEN_NOCHES := 1.0


## Se asegura de que quede alguien en el hogar, cogiendolo de los ociosos.
func _ensure_hearth() -> void:
	var hearth := 0
	for person: Inhabitant in people:
		if person.job == Profession.Job.HOGAR:
			hearth += 1
	if hearth >= MIN_HEARTH:
		return

	# Primero, de quien no esta haciendo nada
	for person: Inhabitant in people:
		if person.job != Profession.Job.OCIOSO:
			continue
		if Profession.assign(Profession.Job.HOGAR, person):
			hearth += 1
			if hearth >= MIN_HEARTH:
				return

	# Y si no hay nadie libre, se saca a alguien de su oficio: sin fuego no se
	# cocina, no se seca la carne y no avanza ninguna obra, asi que el minimo
	# es un minimo de verdad. Se coge a quien MENOS ganas tenga de lo que esta
	# haciendo, y se anota en la cronica para que no sea a espaldas del
	# jugador -que es lo que hacia el reparto viejo y por lo que se noto-.
	var weakest: Inhabitant = null
	var weakest_level := -1
	for person: Inhabitant in people:
		if person.job == Profession.Job.HOGAR:
			continue
		if not Profession.can_do(Profession.Job.HOGAR, person):
			continue
		var level := person.priority_in_job(person.job)
		if level > weakest_level:
			weakest_level = level
			weakest = person

	if weakest != null and Profession.assign(Profession.Job.HOGAR, weakest):
		_note(Chronicle.Kind.GENTE,
			"No quedaba nadie para el fuego: %s deja %s y se queda en el abrigo."
				% [weakest.given_name,
					Profession.job_name(weakest.job as Profession.Job).to_lower()], 1)


## Cuanta gente esta sin oficio ahora mismo.
func idle_count() -> int:
	var total := 0
	for person: Inhabitant in people:
		if person.job == Profession.Job.OCIOSO:
			total += 1
	return total


## Por que la gente que esta sin oficio NO puede entrar en uno.
##
## Existe porque el boton de sumar se apagaba sin decir nada cuando quedaban
## ociosos pero ninguno servia para ese trabajo: el jugador veia «3 sin
## oficio» y un boton muerto. Aqui se cuenta el motivo de cada uno para poder
## decirselo.
func idle_blockers(job: Profession.Job) -> Dictionary:
	var entry: Dictionary = Profession.CATALOGUE[job]
	var out := {"crios": 0, "ancianos": 0, "criando": 0, "sexo": 0}

	for person: Inhabitant in people:
		if person.job != Profession.Job.OCIOSO or Profession.can_do(job, person):
			continue
		if person.age_years < int(entry["min_age"]):
			out["crios"] = int(out["crios"]) + 1
		elif person.age_years > int(entry["max_age"]) 				or (bool(entry["mobile"]) and person.age_group != Inhabitant.Age.ADULTO):
			out["ancianos"] = int(out["ancianos"]) + 1
		elif bool(entry["mobile"]) and person.nursing:
			out["criando"] = int(out["criando"]) + 1
		else:
			out["sexo"] = int(out["sexo"]) + 1
	return out


## Si esta persona esta disponible para que otro oficio la reclame.
##
## Solo lo esta quien no tiene oficio de campo: el hogar y quien se ha quedado
## sin tarea. Antes se cogia al primero que pudiera hacer el trabajo, asi que
## sumar un recolector le quitaba un cazador a la partida SIN DECIRLO: el
## jugador pedia una cosa y perdia otra a su espalda.
##
## Ahora sacar gente de un oficio es un acto aparte -se baja ese oficio y la
## gente pasa al hogar, que es el fondo comun- y meterla en otro, otro. Dos
## clics deliberados en vez de uno con efecto oculto.
func _is_spare(person: Inhabitant) -> bool:
	return person.job == Profession.Job.OCIOSO


## Cuanta gente hay libre para reclamar ahora mismo. Lo usa la interfaz para
## poder decir por que no se puede sumar a un oficio.
func spare_count(job: Profession.Job) -> int:
	var total := 0
	for person: Inhabitant in people:
		if person.job != job and Profession.can_do(job, person) and _is_spare(person):
			total += 1
	return total


## Manda a todos los adultos a una actividad
func assign_all(activity: Subsistence.Activity) -> void:
	if not work_sites.has(activity):
		return
	for person: Inhabitant in people:
		if person.can_work():
			person.activity = activity
			person.has_task = true
			person.state = Inhabitant.State.OCIOSO


## Multiplicador de velocidad del juego. 0 es pausa.
##
## Va aqui y no en `Engine.time_scale` porque `Engine.time_scale` congelaria
## tambien la interfaz: los paneles dejarian de repintarse y las ventanas de
## responder a su propio ritmo. Lo que se pausa es EL MUNDO, no el programa.
var time_scale: float = 1.0

## Cuanto puede avanzar una persona de una tacada, en unidades de mundo.
##
## A x5 y con el fotograma largo, un solo paso salia de dieciocho unidades, y
## como el paso se comprueba SOLO EN SU DESTINO, la gente cruzaba rios
## estrechos de un salto. Partir el avance en trozos cortos hace que el
## resultado a cualquier velocidad sea el mismo que a velocidad normal.
const MAX_STEP := 4.0


func _process(delta: float) -> void:
	if people.is_empty() or _terrain == null or time_scale <= 0.0:
		return

	_path_nodes_this_frame = 0
	_stranded_this_frame = 0

	var scaled := delta * time_scale
	var hours := scaled / seconds_per_day * 24.0
	hour += hours
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		_end_of_day()
		day_passed.emit(day)


	# El tick se parte en trozos para que acelerar no cambie el resultado: con
	# un solo paso largo la gente atraviesa obstaculos que a velocidad normal
	# la pararian.
	var steps := maxi(int(ceil(time_scale)), 1)
	var slice := scaled / float(steps)
	var slice_hours := hours / float(steps)
	for _s in range(steps):
		for i in range(people.size()):
			_tick_person(people[i], i, slice_hours, slice)


## Cuanto suben los rasgos fisicos por el uso, por hora. Muchisimo mas lento
## que la destreza -esta es una vida, no una temporada- y por eso los
## numeros son minusculos: con estos ritmos, notarse de verdad lleva años de
## partida, que es justo lo que tiene que costar cambiar el cuerpo de nadie.
const FUERZA_TRAINING_RATE := 0.00004
const RESISTENCIA_TRAINING_RATE := 0.00003

## A partir de cuanta fatiga trabajar cuenta como aguantar de verdad. Por
## debajo de esto es una jornada normal, no un esfuerzo que curta.
const RESISTENCIA_TRAINING_THRESHOLD := 55.0


func _tick_person(person: Inhabitant, index: int, hours: float, delta: float) -> void:
	# Las necesidades corren para todos, trabajen o no
	person.hunger = clampf(person.hunger + hours * HAMBRE_POR_HORA, 0.0, 100.0)
	person.mark_trail(day, hour)
	_watch_for_stuck(person, hours)

	# Las horas se apuntan SIEMPRE que este de servicio, ande o trabaje. Sin
	# las de andar, «la recoleccion no trae nada» no se distingue de «la
	# recoleccion se pasa la jornada andando», que es una respuesta muy
	# distinta y con un arreglo muy distinto.
	if person.job != Profession.Job.OCIOSO \
			and person.state != Inhabitant.State.DURMIENDO \
			and person.state != Inhabitant.State.COMIENDO:
		person.log_hours(person.current_task(), hours)

	# La RESISTENCIA se entrena AGUANTANDO, no trabajando sin mas: hace falta
	# estar ya cansado y seguir en ello. Un dia corto y descansado no curte a
	# nadie.
	#
	# El trabajo de abrigo queda fuera MIENTRAS no cueste fatiga -ver
	# [CAMP_FATIGUE_RATE], que hoy vale cero-. Si contara, quien llegase cansado
	# de la vispera se pondria a tallar junto al fuego, no se cansaria mas ni se
	# le pasaria en todo el dia, y curtiria aguante gratis. El dia que tallar
	# canse, esta excepcion sobra y se cae sola.
	if person.fatigue > RESISTENCIA_TRAINING_THRESHOLD \
			and person.state != Inhabitant.State.DURMIENDO \
			and person.state != Inhabitant.State.OCIOSO \
			and person.state != Inhabitant.State.COMIENDO \
			and (CAMP_FATIGUE_RATE > 0.0 or not _works_at_camp(person)):
		person.train_stat(Inhabitant.Stat.RESISTENCIA, hours * RESISTENCIA_TRAINING_RATE)

	# Fuera de la jornada. La gente se recoge, come y duerme a sus horas.
	var night := hour < HORA_DESPERTAR or hour >= HORA_DORMIR
	# Volver PARA el anochecer, no empezar a volver al anochecer.
	#
	# [HORA_REGRESO] era la hora de dar media vuelta, con lo que quien estaba a
	# dos kilometros llegaba de noche cerrada. Medido en el sitio 56, seis
	# jornadas: a las nueve -la hora de dormir- seguia habiendo dos personas
	# andando por el monte, y a las tres de la madrugada media.
	#
	# Ahora se cuenta lo que se tarda en llegar y se sale con esa antelacion.
	# Ver [hours_to_walk], que se queda corta a proposito.
	var walk_home := hours_to_walk(person.position.distance_to(home_position))
	var winding_down := hour + walk_home * RODEO_DE_VUELTA >= HORA_REGRESO \
		and hour < HORA_DORMIR
	var morning := hour >= HORA_DESPERTAR and hour < HORA_SALIDA

	# A la hora de volver, todo el mundo emprende el regreso salvo quien esta
	# de expedicion. Sin esto la gente se quedaba trabajando hasta la noche y
	# volvia a oscuras, que es lo que hace un autómata, no una persona.
	if winding_down and person.state != Inhabitant.State.VOLVIENDO \
			and not (_works_at_camp(person) and _can_work_at_night(person)):
		var on_expedition := person.job == Profession.Job.EXPLORACION \
			and person.current_speciality != Profession.Speciality.BATIDA \
			and person.position.distance_to(home_position) > arrive_radius * 4.0
		if not on_expedition:
			if _at_shelter(person):
				_deliver(person)
				person.state = Inhabitant.State.OCIOSO
			else:
				_send_to(person, home_position)
				person.state = Inhabitant.State.VOLVIENDO

	# EL DESAYUNO. Se sienta todo el mundo, tenga el hambre que tenga: es una
	# comida, no un remedio. Quien no la necesite se levanta enseguida -se sale
	# de COMIENDO en cuanto el hambre baja de 15-.
	#
	# Ya no lleva condicion de hambre porque ya no hay tercera oportunidad: se
	# quito el bocado de mediodia y el picoteo de cualquier rato muerto, asi que
	# quien se salte el desayuno aguanta hasta la cena.
	if morning and person.hunger > COMIDA_SUFICIENTE \
			and store.food_rations() > 0.0:
		person.state = Inhabitant.State.COMIENDO

	# LA CENA, y va antes de la noche a proposito: a las nueve el reparto
	# noche/dia manda a todo el mundo a dormir, asi que una cena a esa hora se
	# quedaba en una comida que empieza y no termina. Se cena en casa y al
	# fuego -de ahi el aprovechamiento de mas del hogar- y luego se duerme.
	if hour >= HORA_CENA and hour < HORA_CENA + DURA_LA_COMIDA \
			and person.hunger > COMIDA_SUFICIENTE \
			and _at_shelter(person) and store.food_rations() > 0.0 \
			and person.state != Inhabitant.State.DURMIENDO:
		person.state = Inhabitant.State.COMIENDO

	# Y la noche respeta la mesa: quien esta cenando cena, y se acuesta cuando
	# termina. Esto se resolvia con un `return` que se saltaba el resto del
	# tick -incluida la vigilancia de atascos, que contaba la cena como una
	# hora sin moverse y sacaba un «llego y el estado no se entero»-.
	if night and person.state == Inhabitant.State.COMIENDO:
		_eat_meal(person, hours)
		_settle_at_home(person, delta)
	elif night:
		# La batida de reconocimiento NO vuelve a dormir a casa: acampa donde
		# le coge la noche y sigue al dia siguiente.
		#
		# Sin esto la exploracion no funcionaba en absoluto. Medido: el
		# explorador elegia un destino a 720 m, la noche lo devolvia al
		# campamento antes de llegar, y lo mas lejos que llego en diez
		# jornadas fueron 182 m. El territorio conocido no se movia del 3%.
		#
		# Y es lo historico: una partida logistica de forrajeo sale varios
		# dias, duerme fuera y vuelve con lo conseguido. Volver cada noche es
		# lo que hace un recolector de radio corto, no un batidor.
		# Si YA esta reconociendo el sitio -ha llegado, esta batiendo la
		# comarca-, se deja terminar esa visita pase lo que pase con la
		# comida o el cansancio: es un compromiso corto y con techo -como
		# mucho `SURVEY_HOURS`, ahora mismo nueve-, y cortarlo a medio camino
		# del final era la manera de que ninguna expedicion llegase nunca a
		# `_finish_survey`. Reconocer YA cuesta 4 de fatiga por hora -ver
		# `_survey`-, asi que acercarse al techo de horas casi siempre cruza
		# el 70 de cansancio justo antes de terminar: exigir estar por debajo
		# de eso para poder acampar cortaba la visita a un paso del final.
		# Medido: un explorador se quedaba a 8,4 de las 9 horas -con la
		# noche encima- y volvia con las manos vacias, sin haber llamado ni
		# una vez a `_finish_survey`.
		var mid_survey := person.state == Inhabitant.State.RECONOCIENDO
		var camping := person.job == Profession.Job.EXPLORACION \
			and person.current_speciality != Profession.Speciality.BATIDA \
			and (person.fatigue < 70.0 or mid_survey) \
			and person.position.distance_to(home_position) > arrive_radius * 4.0

		# Sin comida encima, la salida se acaba y se vuelve: es lo que pone
		# limite a su alcance, mas todavia que el cansancio -salvo, por lo
		# de arriba, mientras se este terminando de reconocer.
		if camping and (pack_rations(person) > 0.2 or mid_survey):
			person.state = Inhabitant.State.DURMIENDO
			# La tienda y la hoguera de esta noche. Ver `_bivouac`.
			_bivouac(person)
			# Se descansa peor al raso que en el abrigo, y peor todavía sin
			# nada con que armar el vivac.
			# Lo que falta y lo mal armado que este pesan igual: una tienda que se
			# viene abajo abriga lo mismo que no tenerla.
			var botched := 1.0 if person.bivouac_botched else 0.0
			var rest := 6.0 - (float(person.bivouac_lack) + botched) * VIVAC_REST_LOSS
			person.fatigue = maxf(person.fatigue - hours * maxf(rest, 0.0), 0.0)
			# Y se cena de lo que se lleva
			_eat_from_pack(person, hours)
		else:
			# De noche NO SE ANDA. Se trazaba camino a casa cada tick y se seguia
			# andando en la oscuridad: medido antes, a las nueve -la hora de
			# dormir- quedaban dos personas por el monte, y a las tres de la
			# madrugada media. A quien no ha llegado le coge la noche donde este,
			# que es lo que le pasa a cualquiera que calcula mal la vuelta.
			if _home_reached(person):
				# Lo primero al llegar es descargar, y llegar de noche tambien es
				# llegar. Sin esto se dormia con el cesto puesto y la cosecha del dia
				# no entraba en el almacen hasta la manana siguiente -y si por la
				# manana se salia sin pasar por la boca, se perdia entera-. Medido
				# antes: 635 momentos de gente en el abrigo con 5,5 kg encima.
				_deliver(person)
				person.state = Inhabitant.State.DURMIENDO
				person.fatigue = maxf(person.fatigue - hours * 9.0, 0.0)
				# El invierno en una cueva sin fuego no se descansa: se
				# aguanta. El resto del año la cueva sola ya abriga bastante,
				# que es justamente por lo que se ocupa una cueva.
				if not hearth_lit \
						and GameState.season == Subsistence.Season.INVIERNO:
					person.fatigue = clampf(
						person.fatigue + hours * HEARTH_COLD_FATIGUE, 0.0, 100.0)
			else:
				# No puede volver y no le queda comida: duerme donde le coge
				# la noche. Es lo que hace cualquiera, y sin esto era una
				# trampa sin salida: quien no podia llegar al abrigo no
				# dormia NUNCA -solo se descansaba en casa-, la fatiga se
				# clavaba en cien y a partir de ahi ya no volvia a salir de
				# expedicion, porque reventado no se sale.
				#
				# Medido antes de arreglarlo: el explorador dejaba de hacer
				# expediciones el dia veinte y se pasaba las otras veinte
				# jornadas despierto en mitad del monte.
				#
				# Se repone peor que en el abrigo -al raso, con hambre y sin
				# fuego- pero se repone.
				person.state = Inhabitant.State.DURMIENDO
				person.fatigue = maxf(person.fatigue - hours * 4.5, 0.0)
	else:
		match person.state:
			Inhabitant.State.DURMIENDO, Inhabitant.State.OCIOSO:
				# Aqui estaba el picoteo: cualquier rato muerto con hambre por
				# encima de 55 era una comida. Con eso la banda comia a todas
				# horas y no se sentaba a comer nunca. Se come al levantarse y a
				# la hora de recogerse, y entre medias se aguanta.
				if person.job == Profession.Job.EXPLORACION \
						and person.current_speciality != Profession.Speciality.BATIDA \
						and person.fatigue > 70.0 \
						and person.position.distance_to(home_position) > arrive_radius * 4.0:
					# Reventado EN EL CAMPO: se vuelve al campamento a
					# reponer. La condicion de distancia es la que faltaba:
					# sin ella, alguien que ya estaba en casa y seguia
					# cansado -de dia no se descansa solo por estar
					# ocioso, hace falta que caiga la noche- se mandaba
					# "a casa" una y otra vez sin moverse casi nada,
					# entraba en VOLVIENDO, llegaba, volvia a OCIOSO,
					# disparaba esto otra vez... y se perdia la jornada
					# entera dando vueltas en el sitio en vez de salir o
					# de verdad descansar. Ver [REST_BEFORE_EXPEDITION],
					# que es quien de verdad decide cuando esta descansado.
					_send_to(person, home_position)
					person.state = Inhabitant.State.VOLVIENDO
				elif person.job == Profession.Job.EXPLORACION \
						and person.current_speciality == Profession.Speciality.BATIDA:
					# La batida es radio corto y vuelve siempre a dormir a
					# casa: no hace falta avituallarla como a una expedicion.
					# Amplia el entorno inmediato del campamento, no la
					# frontera del territorio.
					var target := _batida_target(person)
					if target.distance_to(person.position) > arrive_radius:
						_send_to(person, target)
						if not person.route.is_empty():
							if person.journey.is_empty():
								person.begin_journey("Batida", day, hour,
									home_position)
							person.state = Inhabitant.State.YENDO
				elif person.job == Profession.Job.EXPLORACION:
					# Expedicion y ascension: se sale varios dias y hace falta
					# avituallar. El explorador no tiene tajo fijo: su destino
					# se calcula cada jornada. Ver [Exploration].
					var at_home := person.position.distance_to(home_position) \
						< arrive_radius * 4.0

					# El destino se calcula ANTES de avituallar, para saber
					# cuanto pesa el viaje de hoy -ver [_provision]-: cuanta
					# comida hace falta depende de adonde se va, no es igual
					# para el pico de al lado que para la loma a dos valles.
					var frontier := Vector3.ZERO
					var climb := {}
					if person.current_speciality == Profession.Speciality.ASCENSION \
							and has_peak():
						# La cumbre que ESTA persona se atreve a atacar, no la mas
						# alta que haya. Ver [peak_for].
						climb = peak_for(person)

					if climb.is_empty():
						# Que HAYA cumbre no quiere decir que le toque a esta
						# persona: puede no atreverse con ninguna de las que quedan,
						# o estar todas al otro lado del agua. Aqui se leia ["pos"]
						# sin mirar, y el juego se caia en cuanto pasaba.
						#
						# No es un caso raro ni un error: es la vuelta a la
						# exploracion normal, que es lo que hace quien se queda sin
						# monte al que subir.
						frontier = _scout_target(person)
					else:
						frontier = climb["pos"]

					if at_home and person.fatigue > REST_BEFORE_EXPEDITION:
						# Esperar a estar descansado antes de partir: salir ya
						# cansado de varios dias fuera es la manera de no
						# volver. La noche en casa recupera fatiga sola -ver el
						# bloque nocturno-, asi que esto no atasca a nadie:
						# solo retrasa la salida un dia o dos.
						person.state = Inhabitant.State.OCIOSO
					elif at_home and not _provision(person, frontier.distance_to(home_position)):
						# Sin provisiones no hay expedicion. Se queda ayudando.
						person.state = Inhabitant.State.OCIOSO
					else:
						if frontier.distance_to(person.position) > arrive_radius:
							_send_to(person, frontier)
							if person.route.is_empty():
								# No hay por donde llegar -un rio de por medio,
								# un cortado-: se busca otro sitio en vez de
								# salir andando derecho al agua
								_lament(person, frontier)
								if has_scout_order:
									clear_scout_order()
								person.state = Inhabitant.State.OCIOSO
							else:
								# La salida se abre AQUI: cuando hay camino y
								# se echa a andar de verdad.
								#
								# Estaba unas lineas mas arriba, al elegir
								# destino, y eso abria una salida cada vez que
								# alguien se quedaba ocioso en el campamento.
								# Como volver al abrigo la cierra, salian
								# cuarenta salidas de cero metros el mismo dia,
								# una por tick, y se llevaban por delante el
								# historial de verdad.
								if person.journey.is_empty():
									person.begin_journey(
										Profession.speciality_name(
											person.current_speciality as Profession.Speciality),
										day, hour, home_position)
								person.state = Inhabitant.State.YENDO
				elif _works_at_camp(person) and _can_work_at_night(person):
					# Fichar. La faena en si la hace `_camp_work` desde TRABAJANDO,
					# igual que la de cualquiera: aqui solo se dice que se empieza.
					person.work_centre = home_position
					person.forage_target = home_position
					person.state = Inhabitant.State.TRABAJANDO
				elif person.has_task and hour >= HORA_SALIDA and hour < HORA_REGRESO:
					_send_to_work(person)
			Inhabitant.State.COMIENDO:
				_eat_meal(person, hours)
			Inhabitant.State.YENDO:
				if person.position.distance_to(person.target) < arrive_radius:
					if person.job == Profession.Job.EXPLORACION \
							and person.current_speciality == Profession.Speciality.ASCENSION \
							and _is_on_peak(person):
						# Llegar al pie de la cumbre no es coronarla: se
						# INTENTA, y con poca pericia se falla. Ver [Ascent].
						_try_ascent(person)
						_send_to(person, home_position)
						person.state = Inhabitant.State.VOLVIENDO
						return
					# Si conoce el paraje, se pone a trabajar. Si no, primero
					# tiene que ENCONTRAR lo que ha venido a buscar.
					var known := 0.0
					if knowledge:
						known = knowledge.familiarity_at(person.activity, person.position)
					# El explorador que llega adonde se le mando no ha
					# terminado: llegar es marcar una casilla, reconocer es
					# batir la comarca. Se queda una jornada.
					if person.job == Profession.Job.EXPLORACION:
						person.work_centre = person.position
						person.forage_target = person.position
						person.survey_hours = 0.0
						person.state = Inhabitant.State.RECONOCIENDO
						return

					if known > 0.35:
						person.work_centre = person.position
						person.forage_target = person.position
						person.state = Inhabitant.State.TRABAJANDO
					else:
						person.search_hours = 0.0
						person.state = Inhabitant.State.BUSCANDO

			Inhabitant.State.BUSCANDO:
				# Prospectar: batir el paraje hasta dar con lo que hay. Cuesta
				# tiempo, y ese tiempo sale de la jornada de recoleccion.
				#
				# Es lo que faltaba para que explorar sirviera de algo: el que
				# llega a un sitio que ya conoce se pone a recoger de
				# inmediato, y el que no, pierde media manana buscando.
				person.search_hours += hours
				person.fatigue = clampf(
					person.fatigue + hours * 3.0 * person.fatigue_factor(), 0.0, 100.0)

				# Buscar ENSENA el paraje, aunque no se recoja nada
				if knowledge:
					knowledge.observe(person.activity, person.position, hours / 8.0)

				var found := 0.0
				if field:
					found = field.seasonal_abundance_at(
						person.activity, person.position, GameState.season)

				# Cuanto mas rico el paraje, antes se da con ello
				var needed: float = lerpf(4.5, 1.0, clampf(found, 0.0, 1.0))
				if person.search_hours >= needed:
					person.work_centre = person.position
					person.forage_target = person.position
					person.state = Inhabitant.State.TRABAJANDO
				elif person.search_hours > 5.0:
					# Aqui no hay nada. Se prueba en otro sitio.
					_send_to(person, _search_target(person))
					person.state = Inhabitant.State.YENDO
			Inhabitant.State.RECONOCIENDO:
				_survey(person, hours)
			Inhabitant.State.TRABAJANDO:
				if _works_at_camp(person):
					_camp_work(person, hours)
				else:
					person.fatigue = clampf(
						person.fatigue + hours * 5.0 * person.fatigue_factor(), 0.0, 100.0)
					# El brazo se entrena cargando y no tallando: FUERZA sube
					# muchisimo mas despacio que la destreza, y solo con tajo de
					# verdad fisico -al taller no le hace falta.
					if person.job == Profession.Job.CAZA \
							or person.job == Profession.Job.RIBERA \
							or person.job == Profession.Job.RECOLECCION:
						person.train_stat(Inhabitant.Stat.FUERZA, hours * FUERZA_TRAINING_RATE)
					_forage_drift(person)
					if person.job == Profession.Job.MANUFACTURA:
						_craft(person, hours)
					elif person.current_speciality == Profession.Speciality.TRAMPAS:
						# El trampero no cosecha: arma trampas y luego las levanta.
						# Es el unico trabajo que rinde MIENTRAS la banda hace otra
						# cosa, y por eso no puede ser una tabla de rendimiento
						# como las demas.
						_trapline(person, hours)
					else:
						_harvest(person, hours)
					# La practica mejora la destreza: es el saber tacito
					# La practica mejora la TAREA que se esta haciendo, no la
					# actividad entera: quien talla no aprende a curtir pieles
					var task := person.current_task()
					var current: float = person.skill_in(task)
					person.skill[task] = minf(
						current + hours * 0.0008 * person.learn_rate(), 0.95)

					# Se vuelve cuando no se puede cargar mas, no por un numero
					# fijo: es lo que hace que los recipientes cambien la jornada.
					if person.fatigue > 78.0 or person.load_fraction() >= 1.0:
						_send_to(person, home_position)
						person.state = Inhabitant.State.VOLVIENDO

			Inhabitant.State.VOLVIENDO:
				if _home_reached(person):
					_deliver(person)
					person.state = Inhabitant.State.OCIOSO

	# Movimiento
	if person.state == Inhabitant.State.YENDO \
			or person.state == Inhabitant.State.VOLVIENDO \
			or person.state == Inhabitant.State.BUSCANDO \
			or person.state == Inhabitant.State.TRABAJANDO 			or person.state == Inhabitant.State.RECONOCIENDO:
		# La ruta agotada sin haber llegado NO es via libre para tirar en
		# linea recta: es justamente cuando hay que volver a trazar. Antes
		# `next_waypoint` caia al destino y la persona salia derecha a
		# seiscientos metros sin plan, que es el atasco «no avanza por el
		# camino trazado».
		if person.route_step >= person.route.size() \
				and person.position.distance_to(person.target) > arrive_radius * 2.0:
			_send_to(person, person.target)

		var to_target := person.next_waypoint() - person.position
		to_target.y = 0.0
		# Al alcanzar un hito del camino se pasa al siguiente: asi se rodea
		# el canchal en vez de cruzarlo, que es donde uno se rompe un tobillo
		if person.route_step < person.route.size() \
				and to_target.length() < arrive_radius:
			person.route_step += 1
			to_target = person.next_waypoint() - person.position
			to_target.y = 0.0
		# Cada uno por su carril. El paso de hito se mide sobre el hito de verdad
		# -arriba-, y el carril sólo tuerce hacia dónde se camina: si desviara
		# también la cuenta de hitos, el camino se recorrería torcido.
		to_target = _lane_shift(person, to_target)
		if to_target.length() > 0.5:
			var direction := to_target.normalized()

			# La velocidad NO es constante. Sale de la funcion de marcha de
			# Tobler segun la pendiente EN EL SENTIDO DE LA MARCHA -no la del
			# terreno a secas, porque subir y bajar no cuestan lo mismo-, del
			# suelo que se pisa y de lo que se lleva encima.
			var pace := _terrain_speed(person, direction, hours) \
				* weather.pace_factor() * _lane_pace(person)
			var step := direction * pace * delta

			# El agua es un obstaculo, no una textura. Si el paso siguiente
			# entra en algo que no se puede cruzar, se bordea la orilla en vez
			# de meterse: se prueban las dos perpendiculares y se toma la que
			# acerque mas al destino. No es un buscador de caminos, pero acaba
			# con lo que se veia antes, que era gente andando sobre el rio.
			if not _can_step_into(person.position + step):
				var side := Vector3(-direction.z, 0.0, direction.x) * walk_speed * delta
				var left := person.position + side
				var right := person.position - side
				var left_ok := _can_step_into(left)
				var right_ok := _can_step_into(right)
				if left_ok and (not right_ok
						or left.distance_to(person.target) < right.distance_to(person.target)):
					step = side
				elif right_ok:
					step = -side
				else:
					# Ni por un lado ni por otro. Antes se paraba y ya: el
					# esquive de orilla es un apano para bordear un charco, no
					# un buscador de caminos, y contra un cortado deja a la
					# persona empujando la roca hasta que la noche la manda a
					# casa.
					#
					# Ahora se pide camino OTRA VEZ desde donde esta. La
					# rejilla sabe por donde se pasa; el esquive no.
					step = Vector3.ZERO
					person.blocked_steps += 1
					if person.blocked_steps > BLOCKED_BEFORE_REPLAN:
						person.blocked_steps = 0
						person.blocked_replans += 1
						var goal := person.target
						person.route = PackedVector3Array()
						person.route_step = 0
						# Y A LA TERCERA SE DEJA. Replanificar contra la misma
						# pared no la abre: la rejilla mide celdas de cuarenta
						# metros y un cortado más estrecho que eso no existe
						# para ella, así que devuelve la misma ruta imposible
						# una y otra vez. Medido en el sitio 56: la cuadrilla de
						# caza menor llegaba todos los días al mismo punto
						# —pendiente 1,4, paso al 2 % de lo normal— y se pasaba
						# la tarde replanificando hasta que la vigilancia de
						# atascos la mandaba a casa. Siete salidas seguidas
						# cerradas con «atascado».
						#
						# Dándolo por inalcanzable, el reparto de mañana lo
						# manda a otro tajo, que es lo que tenía que pasar.
						if person.blocked_replans >= BLOCKED_REPLANS:
							person.blocked_replans = 0
							person.unreachable = goal
							_give_up_on(person, goal)
						else:
							_send_to(person, goal)

			person.position += step
			person.note_step(step.length(), home_position)
			if step.length() > 0.01:
				person.blocked_steps = 0
				person.blocked_replans = 0
				# Sólo un paso con recorrido real gira a la persona; uno de
				# longitud cero -parada, bloqueo- no dice hacia dónde mira.
				_headings[index] = atan2(step.x, step.z)
			person.position.y = _terrain.get_height_at(person.position)
			# Andar cansa. Hace falta para que la batida tenga final: sin esto
			# el explorador nunca acumulaba fatiga y no volvia jamas.
			person.fatigue = clampf(
				person.fatigue + hours * 2.6 * person.fatigue_factor(), 0.0, 100.0)

	# Las pruebas montan una `SettlementSim` a medias -gente y reservas, sin
	# pasar por [setup]- para probar la lógica sin pagar el terreno ni la
	# banda dibujada. `_crowd` y `_bodies` son justo lo que no montan, y no
	# tienen por qué: lo que se prueba ahí no depende de cómo se ve nadie.
	# Y dónde se queda si está en casa: dentro a dormir, en la puerta a todo lo
	# demás. Ver `_settle_at_home`.
	# El agua del dia. Va aqui, al final del tick, para que mire la posicion en
	# la que la persona ha ACABADO el paso y no la de antes de darlo.
	_drink_and_thirst(person, hours)

	_settle_at_home(person, delta)

	if _crowd and index < _bodies.size():
		_crowd.update(_bodies[index], person.position, _headings[index], person.state,
			person.age_group)
	_learn_from(person, delta)


## Cuanto multiplica la destreza de expedicion los dias de comida que se
## llevan. `expedition_days` es el suelo -lo que aguanta cualquiera con
## cero destreza-; quien ya sabe racionar y buscar por el camino estira eso
## y aguanta mas noches fuera con la misma banda a la espalda. Es la
## respuesta mecanica a «dependiendo su habilidad podra pasar mas o menos
## noches fuera»: la comida es lo que de verdad pone el limite, mas todavia
## que el cansancio -ver la nota en el bloque nocturno de `_tick_person`.
const EXPEDITION_SKILL_DAYS_RANGE := Vector2(1.0, 2.2)

## Por debajo de esta fatiga se considera "descansado" para partir de
## expedicion o ascension. Bastante mas bajo que el 78 al que se manda
## volver a un trabajador: salir a varios dias del abrigo no es lo mismo
## que un tajo del que se vuelve esa misma tarde.
const REST_BEFORE_EXPEDITION := 35.0


## Cuanta comida de mas se lleva "por si acaso", en dias. Un rio crecido,
## una pierna torcida, una tormenta que obliga a esperar: la petición
## explícita era llevar "un poco mas por posibles problemas".
const SAFETY_MARGIN_DAYS := 1.0

## Cada cuantos kilometros de frente se cuenta un dia mas de comida.
##
## No es un calculo de marcha real -a paso llano, cualquier distancia de
## este mapa local se anda en un par de horas, y con esa cuenta ningun
## destino de la partida pesaria nunca mas que el suelo fijo de siempre-.
## Es una vara de medir de JUEGO: quiere que un frente a la vuelta de la
## esquina y uno a dos valles de distancia carguen cosas claramente
## distintas, no reproducir la marcha real.
const KM_PER_EXTRA_DAY := 1.2

## Cuantos dias de mas pide una distancia, por encima del suelo de
## siempre. Grosero a proposito: no sabe de rios ni de cuestas por el
## camino real, solo dice "esto esta lejos, para esto no basta con lo de
## siempre".
func _travel_days_for(distance_m: float) -> float:
	if distance_m <= 0.0:
		return 0.0
	return floor((distance_m / 1000.0) / KM_PER_EXTRA_DAY)


## Cuantos dias de comida le tocan a esta persona, segun su destreza y lo
## lejos que va.
##
## En LA SUYA: expedicion y ascension no comparten cuenta, cada una avanza
## con su propio ritmo -alguien puede ser un buen escalador y un mal
## logistico de expedicion larga, o al reves.
##
## `distance_m` es la distancia real al destino de esta salida. Antes se
## cargaban siempre los mismos `expedition_days` sin mirar adonde se iba,
## asi que una ascension a la loma de al lado y una expedicion a dos
## valles cargaban exactamente lo mismo: de sobra para la primera, corto
## para la segunda. Sin distancia -pruebas, o destino aun sin calcular- se
## queda en el suelo de siempre.
func _expedition_days_for(person: Inhabitant, distance_m: float = -1.0) -> float:
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		person.current_speciality as Profession.Speciality)
	var factor := lerpf(EXPEDITION_SKILL_DAYS_RANGE.x, EXPEDITION_SKILL_DAYS_RANGE.y,
		person.skill_in(task))
	var base_days := float(expedition_days)
	if distance_m > 0.0:
		base_days = maxf(base_days, _travel_days_for(distance_m) + SAFETY_MARGIN_DAYS)
	return base_days * factor


## Avitualla una expedicion o ascension. Devuelve si pudo salir.
##
## Es lo que hace que explorar lejos deje de ser gratis: cada salida se
## lleva comida del almacen, y en un mal invierno eso es comida que no esta.
## La batida no pasa por aqui -no acampa, vuelve a diario- ver el bloque
## nocturno de `_tick_person`.
##
## `distance_m` es la distancia al destino de HOY. Si no llega a acampar
## -un pico cercano, un frente a un paso del abrigo- no hace falta cargar
## nada: se come en casa como cualquier otro y se vuelve esa misma tarde.
## Cargar racion aqui era pedirle un peaje a quien ni siquiera duerme fuera.
func _provision(person: Inhabitant, distance_m: float = -1.0) -> bool:
	if distance_m >= 0.0 and distance_m <= arrive_radius * 4.0:
		return true

	# Lo que ya lleve cuenta
	var carried := 0.0
	for kind: int in person.load.keys():
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			carried += float(person.load[kind]) * Materia.nutrition(k)

	var days := _expedition_days_for(person, distance_m)
	var needed := person.daily_food() * days - carried
	if needed <= 0.0:
		return true

	# Se prefiere lo que menos pesa por racion y mas aguanta: para llevar
	# encima varios dias, la carne seca y el fruto son lo unico razonable
	for kind: int in [Materia.Kind.CARNE_SECA, Materia.Kind.PESCADO_SECO,
			Materia.Kind.FRUTO_SECO, Materia.Kind.GRASA]:
		if needed <= 0.0:
			break
		var k := kind as Materia.Kind
		var units := store.take(k, needed / maxf(Materia.nutrition(k), 0.001))
		if units > 0.0:
			person.add_load(k, units)
			person.note_from_store(k, units)
			needed -= units * Materia.nutrition(k)

	# Sin nada de eso -o sin bastante-, se carga lo que HAYA, fresco o no.
	# Antes, si el almacen se quedaba sin las tres cosas concretas de
	# arriba, la expedicion simplemente NO SALIA, sin una nota ni un
	# aviso: una banda que agotaba su carne seca dejaba de explorar EL
	# RESTO DE LA PARTIDA sin que nadie supiera por que, aunque el
	# almacen siguiera lleno de pescado, mariscos o fruto fresco.
	# Cualquier banda de verdad sale con lo que tenga antes que quedarse
	# en el abrigo por no tener precisamente la mejor racion de viaje.
	if needed > 0.0:
		for kind: int in Materia.Kind.values():
			if needed <= 0.0:
				break
			var k := kind as Materia.Kind
			if not Materia.is_food(k):
				continue
			var units := store.take(k, needed / maxf(Materia.nutrition(k), 0.001))
			if units > 0.0:
				person.add_load(k, units)
				person.note_from_store(k, units)
				needed -= units * Materia.nutrition(k)

	_pack_bivouac(person, days)

	# Con menos de un dia de comida no se sale
	return needed <= person.daily_food() * (days - 1.0)


## Carga la tienda y la hoguera de las noches que se van a pasar fuera.
##
## No impide salir si falta: una banda sale con lo que tiene, igual que con la
## comida. Lo que hace la falta es cara: se paga esa noche, en riesgo de
## percance. Ver `_bivouac`.
func _pack_bivouac(person: Inhabitant, days: float) -> void:
	var nights := maxf(ceil(days), 1.0) + VIVAC_MARGEN_NOCHES
	var piel := VIVAC_PIEL - float(person.load.get(Materia.Kind.PIEL, 0.0))
	if piel > 0.0:
		var got := store.take(Materia.Kind.PIEL, piel)
		person.add_load(Materia.Kind.PIEL, got)
		person.note_from_store(Materia.Kind.PIEL, got)
	var lena := VIVAC_LENA * nights - float(person.load.get(Materia.Kind.LENA, 0.0))
	if lena > 0.0:
		var got_wood := store.take(Materia.Kind.LENA, lena)
		person.add_load(Materia.Kind.LENA, got_wood)
		person.note_from_store(Materia.Kind.LENA, got_wood)


## Lo que cuesta pasar la noche fuera del abrigo.
##
## Se cobra UNA vez por noche —de ahí `bivouac_day`— y no en cada tick, que es
## como se cobraría sesenta veces por segundo. La piel no se gasta: hay que
## tenerla, y vuelve al abrigo con quien la llevó. La leña arde.
func _bivouac(person: Inhabitant) -> void:
	if person.bivouac_day == day:
		return
	person.bivouac_day = day
	person.bivouac_lack = 0
	if float(person.load.get(Materia.Kind.PIEL, 0.0)) < VIVAC_PIEL:
		person.bivouac_lack += 1
	# La leña que se quema es la hoguera, y ahora se ve arder: ver
	# [BivouacFires]. Sin fuego se sigue durmiendo, pero a oscuras y con el
	# riesgo que eso trae.
	person.bivouac_fire = person.take_load(
		Materia.Kind.LENA, VIVAC_LENA) >= VIVAC_LENA
	if not person.bivouac_fire:
		person.bivouac_lack += 1

	# Y ARMARLO, que no es tener el material. Montar una tienda de pieles con
	# viento, prender con leña húmeda y dejarlo de forma que aguante la noche es
	# saber del HOGAR: es el mismo oficio que mantiene el fuego del abrigo, y
	# por eso es su saber el que decide, no el de explorar.
	#
	# Quien no lo sabe hacer duerme peor aunque lleve todo lo que hace falta, y
	# eso se paga a la mañana siguiente: se levanta mas cansado y la jornada le
	# cunde menos. Es lo que hace que poner a alguien en el hogar valga tambien
	# para quien sale de expedicion.
	# Va APARTE de `bivouac_lack`, que cuenta lo que FALTA: llevar la piel y la
	# leña y no saber armarlo son dos cosas distintas y se leen distinto en la
	# cronica -«sin tienda» no es «mal armado»-.
	person.bivouac_botched = not _camps_well(person)
	if person.bivouac_botched:
		person.log_deed(person.current_task(),
			"pasó la noche mal armado", false)

	if person.bivouac_lack <= 0:
		return
	var falta := "sin tienda ni hoguera"
	if person.bivouac_lack == 1:
		var tent := float(person.load.get(Materia.Kind.PIEL, 0.0)) >= VIVAC_PIEL
		falta = "sin hoguera" if tent else "sin tienda"
	_note(Chronicle.Kind.PENURIA,
		"%s pasa la noche %s en %s." % [person.given_name, falta,
			parajes.place_name(person.position, home_position)], 1)


## Cuanto pesa el saber del hogar en armar un vivac.
##
## De cero a uno: con el hogar sin practicar se falla casi siempre, y con el
## oficio hecho no se falla nunca. La suerte que queda es la noche -llueve, o
## no-, y por eso no es un si o no seco.
##
## Pendiente de playtest: lo decidido es que el hogar sirva para esto, no
## cuanto.
const VIVAC_BASE := 0.35


## Si esta persona sabe armar el campamento de una noche.
func _camps_well(person: Inhabitant) -> bool:
	var task := Profession.task_id(Profession.Job.HOGAR)
	var know := clampf(VIVAC_BASE + person.skill_in(task), 0.0, 1.0)
	return _rng.randf() < know


## Come de lo que lleva en la mochila, estando fuera.## Come de lo que lleva en la mochila, estando fuera.
func _eat_from_pack(person: Inhabitant, hours: float) -> void:
	var wanted := person.daily_food() * (hours / 24.0)
	for kind: int in person.load.keys().duplicate():
		if wanted <= 0.0:
			break
		var k := kind as Materia.Kind
		if not Materia.is_food(k):
			continue
		var have: float = person.load[k]
		var units := minf(have, wanted / maxf(Materia.nutrition(k), 0.001))
		person.load[k] = have - units
		if person.load[k] <= 0.0001:
			person.load.erase(k)
		# Lo comido sale de lo que se sacó del almacén: si no se descontara
		# aquí, al volver se le restaría a la producción una comida que ya no
		# lleva encima.
		person.carried_out[k] = maxf(
			float(person.carried_out.get(k, 0.0)) - units, 0.0)
		wanted -= units * Materia.nutrition(k)
		person.hunger = maxf(person.hunger - units * Materia.nutrition(k) * (3.4 * 24.0), 0.0)


## Cuanta comida le queda encima a una persona, en raciones.
func pack_rations(person: Inhabitant) -> float:
	var total := 0.0
	for kind: int in person.load.keys():
		var k := kind as Materia.Kind
		if Materia.is_food(k):
			total += float(person.load[kind]) * Materia.nutrition(k)
	return total


## A partir de que distancia del abrigo cuenta como "lejos": el borde del
## mapa local, donde la exploracion empieza a asomarse a la comarca.
const REGIONAL_DISTANCE := 2600.0

## Cuanta gente hace falta dedicada a la expedicion antes de dejar que
## alguien se aventure mas alla de [REGIONAL_DISTANCE].
##
## La peticion explicita: "las exploraciones mas lejanas o regionales
## requieren grupos relativamente numerosos". Todavia no hay partidas que
## caminen juntas en formacion -cada explorador sigue su propio paso y su
## propio destino-, asi que esto se aplica como una condicion de PARTIDA:
## mientras la banda no tenga suficiente gente puesta en ello, nadie sale
## solo a explorar el borde del mapa. Con mas manos dedicadas a la vez, sí.
const MIN_GROUP_FOR_REGIONAL := 3


## Cuanta gente de la banda esta puesta en expedicion ahora mismo.
func _expedition_party_size() -> int:
	var n := 0
	for p: Inhabitant in people:
		if p.job == Profession.Job.EXPLORACION \
				and p.current_speciality == Profession.Speciality.EXPEDICION:
			n += 1
	return n


## Destino de una batida de reconocimiento.
func _scout_target(person: Inhabitant) -> Vector3:
	if knowledge == null or _terrain == null:
		return home_position

	var target: Vector3

	# Si el jugador ha señalado un rumbo, se va ahi. La logica de frontera
	# -que elige el punto que mas mapa abre- se queda de reserva para cuando
	# no hay orden: es buena, y ese era justo el problema. Elegia siempre
	# bien y no dejaba nada que decidir.
	if has_scout_order:
		# Cada cual llega por su lado: sin esto salen en fila india al mismo
		# punto, que es lo que ya paso con los recolectores
		var spread := 90.0
		var angle := float(person.id) * 1.7
		target = scout_order + Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
	else:
		# Para explorar basta con que el camino sea MAYORMENTE transitable: un
		# batidor rodea el obstaculo, que es justo su trabajo. Exigiendo la recta
		# limpia entera -como para ir al tajo- casi ningun destino la pasaba y los
		# exploradores se quedaban parados en el campamento.
		# Se llega o no se llega, y eso lo sabe la rejilla de navegacion sin
		# buscar nada. Antes se exigia que la RECTA de aqui alla fuera
		# transitable en un 85%, y en terreno de verdad casi ningun destino
		# lejano pasa esa prueba: cualquier rio de por medio la tumba.
		#
		# Eso es lo que hacia que la banda no saliera de expedicion sola. No
		# es que no quisiera: es que se descartaba ella misma todas las
		# fronteras y se quedaba con las cuatro de al lado de casa.
		var reachable := func(point: Vector3) -> bool:
			return _navgrid().connected(person.position, point)

		# Los destinos que ya tienen batida en marcha, para que las partidas se
		# abran en abanico en vez de salir en fila india a la misma frontera
		var taken: Array[Vector3] = []
		for other: Inhabitant in people:
			if other == person or other.job != Profession.Job.EXPLORACION:
				continue
			if other.state == Inhabitant.State.YENDO:
				taken.append(other.target)

		target = Exploration.best_frontier(
			knowledge, home_position, reachable, taken)

		# `best_frontier` devuelve el punto de partida cuando NO ENCUENTRA nada
		# que merezca el viaje. Eso es lo que apagaba la exploracion en silencio:
		# hacia el dia treinta la banda ya conoce todo lo que tiene al alcance,
		# la frontera deja de existir, el destino sale igual al campamento, la
		# comprobacion de distancia no pasa y el explorador se queda quieto para
		# siempre sin que nadie diga nada.
		#
		# Que no quede frontera es un hito de la partida, no una averia: se
		# cuenta, y a partir de ahi se sigue saliendo a repasar lo que peor se
		# conoce. Un territorio no se conoce de una vez: cambia con la estacion,
		# y lo que se vio hace tres meses hay que volver a verlo.
		if target.distance_to(home_position) < arrive_radius * 2.0:
			if not _comarca_known:
				_comarca_known = true
				_note(Chronicle.Kind.TIERRA,
					"Ya no queda nada nuevo que reconocer a este lado. La banda "
						+ "conoce su comarca; para ver mas habria que cruzar el "
						+ "agua o levantar el campamento.", 2)
			target = _least_known_around(home_position,
				BATIDA_RADIUS, PEAK_SEARCH_RADIUS, person)

	# Ni el rumbo del jugador se salta esto: una partida corta no se
	# aventura al borde del mapa por mucho que se le señale. Se queda
	# repasando lo que tiene mas cerca hasta que se sume mas gente.
	if target.distance_to(home_position) > REGIONAL_DISTANCE \
			and _expedition_party_size() < MIN_GROUP_FOR_REGIONAL:
		target = _least_known_around(home_position,
			BATIDA_RADIUS, REGIONAL_DISTANCE, person)

	target.y = _terrain.get_height_at(target)
	return target


## Destino de una BATIDA: el entorno inmediato del campamento, no la frontera.
##
## Radio corto y punto aleatorio dentro de el, sin fan-out entre batidores
## -a diferencia de `_scout_target`- porque el objetivo no es repartirse el
## territorio entero, es peinar los alrededores. Con `arrive_radius` de por
## medio, en pocas jornadas cubre el circulo entero por simple variacion.
const BATIDA_RADIUS := 380.0


func _batida_target(person: Inhabitant) -> Vector3:
	# Lo primero, un paraje a medio investigar. Es lo que de verdad hace una
	# batida: no descubrir monte nuevo -eso es la expedicion- sino acabar de
	# conocer lo que ya se ha encontrado. Un avellanar del que solo se sabe
	# que tiene avellanas es un avellanar a medias.
	var pending := _paraje_to_survey(person)
	if pending != null:
		return pending.position

	# Y si no queda ninguno, se peina el entorno buscando parajes nuevos
	return _least_known_around(home_position, BATIDA_RADIUS * 0.35,
		BATIDA_RADIUS, person)


## Cuantos sitios se miran antes de elegir adonde batir.
##
## Doce da para cubrir el circulo sin que la eleccion cueste nada: son doce
## consultas al mapa mental, no doce busquedas de camino.
const SCAN_CANDIDATES := 12


## Cuánto tira el terreno de un sitio, de 0 a 1.
##
## Las dos guías de cualquiera que anda por el monte sin mapa: **el agua y el
## lomo**. La orilla de un cauce es un pasillo natural —se anda, se bebe, y
## lleva a alguna parte—; una loma es un mirador que se paga subiendo una vez
## y se cobra viendo mucho.
##
## No es un peso grande a propósito. Tiene que inclinar la elección entre dos
## sitios igual de desconocidos, no mandar a la banda a bordear el río mientras
## media comarca sigue en blanco.
func _terrain_lure(point: Vector3) -> float:
	if _terrain == null:
		return 0.0

	var lure := 0.0

	# La ORILLA: suelo que se pisa CON agua al lado. Se busca en los
	# alrededores y no en el propio punto, que era el fallo del primer intento:
	# preguntando solo por el punto, lo unico que da agua es el punto que ESTA
	# dentro del cauce -y por dentro del cauce no se explora, se nada-.
	#
	# Una orilla es justo lo contrario: tierra firme desde la que se ve el rio.
	var ford := _terrain.crossing_difficulty_at(point)
	if Hydrography.can_cross(ford, has_boat, has_bridge):
		var reach_water := 60.0
		for offset: Vector2 in [Vector2(reach_water, 0.0), Vector2(-reach_water, 0.0),
				Vector2(0.0, reach_water), Vector2(0.0, -reach_water)]:
			var side := point + Vector3(offset.x, 0.0, offset.y)
			if _terrain.crossing_difficulty_at(side) > 0.15:
				lure += LURE_WATER
				break

	# El LOMO: más alto que lo que tiene a un lado y a otro. Se mira a paso
	# largo porque un lomo es una forma del valle, no un bulto de tres metros.
	var here := _terrain.get_height_at(point)
	var reach := 90.0
	var above := 0
	for offset: Vector2 in [Vector2(reach, 0.0), Vector2(-reach, 0.0),
			Vector2(0.0, reach), Vector2(0.0, -reach)]:
		if here > _terrain.get_height_at(
				point + Vector3(offset.x, 0.0, offset.y)) + 6.0:
			above += 1
	if above >= 3:
		lure += LURE_RIDGE

	return lure


## Cuánto tira una orilla y cuánto tira un lomo.
##
## En la misma escala que «lo conocido», que va de 0 a 1: 0,12 quiere decir
## que un sitio junto al río gana a otro que esté un 12% menos explorado. Es
## una preferencia, no una obsesión.
const LURE_WATER := 0.12
const LURE_RIDGE := 0.10


## El punto MENOS conocido dentro de un anillo alrededor de un centro.
##
## Antes se sorteaba a ciegas, y sortear a ciegas quiere decir volver una y
## otra vez al mismo prado mientras el barranco de al lado sigue en blanco
## despues de veinte jornadas. Un batidor de verdad sabe por donde ha ido ya.
##
## No se coge el peor sin mas: se sortea entre los tres menos conocidos. Sin
## ese margen, dos batidores que salen la misma manana eligen exactamente el
## mismo punto, y salen en fila india.
## Donde esta "trabajando" de verdad un explorador ahora mismo, para el
## reparto entre batidores -que dos no vayan a lo mismo.
##
## Mientras viaja hacia su destino, es `target`. Una vez ha llegado y esta
## reconociendo, `target` deja de servir: cada tramo de la batida apunta a
## un punto nuevo dentro de SURVEY_RADIUS -hasta 260 m- del sitio, asi que
## un rato despues de llegar el "destino" ya no tiene nada que ver con el
## paraje que esta batiendo. Lo que se queda quieto mientras dura la visita
## es `work_centre`, y es eso lo que hay que mirar.
func _exploration_anchor(person: Inhabitant) -> Vector3:
	if person.state == Inhabitant.State.RECONOCIENDO:
		return person.work_centre
	return person.target


func _least_known_around(centre: Vector3, near: float, far: float,
		person: Inhabitant) -> Vector3:
	var best: Array[Dictionary] = []

	for i in range(SCAN_CANDIDATES):
		# En abanico y no al azar, para que el barrido cubra el circulo
		var angle := (float(i) + _rng.randf()) / float(SCAN_CANDIDATES) * TAU
		var radius := _rng.randf_range(near, far)
		var candidate := centre + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		if _terrain:
			candidate.y = _terrain.get_height_at(candidate)
			if not Traversal.is_passable(_terrain.get_slope_at(candidate),
					_terrain.crossing_difficulty_at(candidate),
					has_boat, has_bridge):
				continue

		# Un pelin de azar encima de lo conocido. Sin el, en cuanto dos sitios
		# empatan -y al principio de la partida empatan TODOS, porque no se
		# conoce nada- gana siempre el primero del barrido, y el abanico se
		# convierte en salir doce veces en la misma direccion. El margen es
		# pequeno a proposito: desempata sin tapar una diferencia de verdad.
		var known := _rng.randf() * 0.06
		if knowledge:
			known += knowledge.explored_at(candidate)

		# Y el terreno TIRA. Nadie explora un mapa a cuadros: se sigue el río
		# aguas arriba porque lleva a alguna parte y da de beber, y se sube al
		# lomo porque desde arriba se ve adónde ir. Un valle se conoce por sus
		# líneas, no por sus casillas.
		known -= _terrain_lure(candidate)
		# Adonde ya va otro no se va: asi se abren en abanico
		for other: Inhabitant in people:
			if other != person and other.job == Profession.Job.EXPLORACION \
					and _exploration_anchor(other).distance_to(candidate) < 120.0:
				known += 0.5
		best.append({"pos": candidate, "known": known})

	if best.is_empty():
		return centre

	best.sort_custom(func(a, b): return float(a["known"]) < float(b["known"]))
	var pick: Dictionary = best[_rng.randi() % mini(3, best.size())]
	return pick["pos"]


## El punto mas alto al alcance de una ASCENSION. Se calcula una vez y se
## guarda: no cambia de una jornada a otra, y recorrerlo cada vez que alguien
## sale seria pagar setenta muestras de altura por nada.
##
## Es un barrido radial burdo, no una busqueda de picos de verdad -no hay
## lista de cumbres con nombre-, pero con el MDT real de por medio el punto
## mas alto de la zona ES un sitio real desde el que se domina el valle, que
## es lo unico que le pide la mecanica.
const PEAK_SEARCH_RADIUS := 2200.0

## Separacion entre los puntos desde los que se sube, en metros.
##
## Doscientos cuarenta. Cada uno acaba en la cima de su ladera, asi que basta
## con que caiga al menos uno en cada monte: mas fino no encuentra mas
## cumbres, solo repite las mismas mas veces.
const PEAK_SEED_STEP := 240.0

## Los pasos con los que se sube hasta la cima, de grueso a fino.
const PEAK_CLIMB_STEPS: Array[float] = [100.0, 50.0, 25.0, 12.0]

## Cuantos pasos se dan como mucho con cada tamano antes de pasar al siguiente.
const PEAK_CLIMB_TURNS := 30

## Radio del anillo con el que se mide cuanto domina una cumbre, en metros.
const PEAK_RING := 400.0
const PEAK_RING_SAMPLES := 16

## Cuanto tiene que levantarse una cumbre sobre lo que la rodea para contar
## como mirador, en metros.
##
## Ochenta. Por debajo de eso no es una cima: es un reperecho en mitad de una
## ladera larga, y desde ahi no se ve el valle, se ve el monte de al lado.
const PEAK_MIN_COMMAND := 80.0


## Distancia minima para que un alto cuente como cumbre. Sin esto, cualquier
## reperecho al lado del campamento valia por un pico, y como el destino
## quedaba dentro del radio de llegada la ascension se daba por hecha NADA MAS
## SALIR: se revelaba medio mapa desde la puerta de la cueva sin andar un paso.
const PEAK_MIN_DISTANCE := 500.0

## Y minima altura sobre el campamento, por lo mismo: subir tiene que ser
## subir. Un llano cien metros mas alla no es una cumbre por mucho que sea el
## punto mas alto que se ha mirado.
const PEAK_MIN_RISE := 60.0


## El punto mas alto al alcance, o el propio campamento si no hay ninguno que
## merezca el nombre de cumbre. Quien llame a esto tiene que comprobar con
## [has_peak] antes de mandar a nadie.
## Todas las cumbres al alcance, con su dureza. Se calcula una vez.
##
## Antes se buscaba UNA -la mas alta- y se mandaba alli a quien fuera. Eso
## hace que un novato ataque la peor pared de la comarca, que no es lo que
## hace nadie: uno mira el monte y se va al que se atreve.
func _find_peaks() -> Array[Dictionary]:
	if _peak_found:
		return _peaks
	_peak_found = true
	_peaks = []

	if _terrain == null:
		return _peaks

	# Los candidatos se recortan al recuadro del mapa. Fuera de el
	# `get_height_at` devuelve la altura del BORDE, no la real, asi que sin
	# recortar el barrido se iba a buscar cumbres que no existen.
	var limit_x := float(_terrain.terrain_size.x)
	var limit_z := float(_terrain.terrain_size.y)
	var margin := 40.0
	var home_height := _terrain.get_height_at(home_position)

	# --- 1. donde el terreno hace un alto -------------------------------
	#
	# Se barre una rejilla y se guardan los maximos LOCALES: los puntos mas
	# altos que sus ocho vecinos. Antes esto eran veinticuatro rayos desde el
	# campamento con cuatro distancias fijas, y eso no busca cumbres: coge
	# noventa y seis puntos cualesquiera y llama cumbre a la altura que
	# tuvieran. Casi siempre caia en mitad de una ladera, que como mirador no
	# vale para nada: se ve el monte de al lado y poco mas.
	# Se siembra una rejilla y desde CADA punto se sube cuesta arriba. El que
	# sube siempre acaba en la cima de su ladera, asi que los puntos distintos
	# a los que se llega son las cumbres de la comarca.
	#
	# Se probo antes a coger solo los maximos locales de la rejilla y salio
	# mal, con numeros: de tres montes puestos a mano encontraba UNO. El
	# motivo es que un monte no esta solo: la ladera del de al lado inclina
	# todo el campo, y en esa cuesta ningun punto de la rejilla es mas alto
	# que sus ocho vecinos aunque haya una cima a cincuenta metros. Subiendo,
	# ese sesgo da igual.
	var candidates: Array[Vector3] = []
	var span := int(PEAK_SEARCH_RADIUS / PEAK_SEED_STEP)
	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var seed_point := home_position + Vector3(
				float(dx) * PEAK_SEED_STEP, 0.0, float(dz) * PEAK_SEED_STEP)
			if seed_point.distance_to(home_position) > PEAK_SEARCH_RADIUS:
				continue
			if seed_point.x < margin or seed_point.z < margin 					or seed_point.x > limit_x - margin 					or seed_point.z > limit_z - margin:
				continue
			seed_point.y = _terrain.get_height_at(seed_point)
			candidates.append(seed_point)

	# --- 2. y se sube andando hasta el alto de verdad --------------------
	for rough: Vector3 in candidates:
		var summit := _climb_to_top(rough, margin, limit_x, limit_z)
		var away := summit.distance_to(home_position)
		if away < PEAK_MIN_DISTANCE:
			continue
		if summit.y - home_height < PEAK_MIN_RISE:
			continue
		if _already_climbed(summit):
			continue

		# --- 3. y tiene que DOMINAR lo que hay alrededor -----------------
		#
		# Es lo que separa una cumbre de un reperecho en una ladera larga: un
		# alto de verdad se levanta sobre todo lo que lo rodea. Se mide contra
		# lo mas bajo de un anillo, que no es la prominencia topografica de
		# verdad -eso pide buscar el collado- pero distingue perfectamente lo
		# que hace falta distinguir.
		var command := summit.y - _lowest_around(summit, PEAK_RING)
		if command < PEAK_MIN_COMMAND:
			continue

		var repeated := false
		for other: Dictionary in _peaks:
			var seen: Vector3 = other["pos"]
			if Vector2(summit.x - seen.x, summit.z - seen.z).length() \
					< PEAK_MIN_DISTANCE * 0.5:
				repeated = true
				break
		if repeated:
			continue

		_peaks.append({
			"pos": summit,
			"rise": summit.y - home_height,
			"command": command,
			"hard": Ascent.difficulty(summit.y - home_height,
				_terrain.get_slope_at(summit), away),
		})

	# De la mas dura a la mas suave: asi elegir «la mejor que me atrevo» es
	# recorrer la lista y quedarse con la primera
	_peaks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["hard"]) > float(b["hard"]))

	print("Cumbres al alcance: %d" % _peaks.size())

	# Si la mas alta pide equipo, se dice una vez. No es un aviso de error: es
	# una promesa de que hay mas juego mas adelante, y de las que dan ganas.
	if not _peaks.is_empty() and Ascent.needs_gear(float(_peaks[0]["hard"])):
		_note(Chronicle.Kind.TIERRA,
			"Hay un alto %s que nadie de la banda sabe como subir. Haria falta "
				% Parajes.bearing(home_position, _peaks[0]["pos"])
			+ "cuerda de verdad y algo que agarre en la roca. Todavia no.", 2)

	return _peaks


## Sube desde un punto hasta el alto que lo domina.
##
## Se mira alrededor y se va al vecino mas alto, con pasos cada vez mas cortos.
## Es andar cuesta arriba hasta que ya no hay cuesta, que es como se llega a
## una cima y como se encuentra en un mapa de alturas.
##
## Los pasos van de grueso a fino a proposito: el paso largo saca del rellano
## y sube la ladera de una vez, y el corto afina los ultimos metros. Con un
## solo paso fino se tarda cien veces mas y se queda enganchado en cualquier
## bulto del camino.
func _climb_to_top(from_point: Vector3, margin: float,
		limit_x: float, limit_z: float) -> Vector3:
	var here := from_point
	here.y = _terrain.get_height_at(here)

	for step: float in PEAK_CLIMB_STEPS:
		for _turn in range(PEAK_CLIMB_TURNS):
			var best := here
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var side := here + Vector3(
						float(dx) * step, 0.0, float(dz) * step)
					if side.x < margin or side.z < margin \
							or side.x > limit_x - margin \
							or side.z > limit_z - margin:
						continue
					side.y = _terrain.get_height_at(side)
					if side.y > best.y:
						best = side
			if best.y <= here.y:
				break
			here = best
	return here


## Lo mas bajo de un anillo alrededor de un punto.
##
## Sirve para saber cuanto DOMINA una cumbre lo que tiene debajo, que es lo que
## la hace un mirador y no un bulto.
func _lowest_around(summit: Vector3, radius: float) -> float:
	var lowest := summit.y
	for i in range(PEAK_RING_SAMPLES):
		var angle := (float(i) / float(PEAK_RING_SAMPLES)) * TAU
		var point := summit + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		lowest = minf(lowest, _terrain.get_height_at(point))
	return lowest


## A partir de que dureza una cumbre no se sube en solitario.
##
## Peticion explicita: "las ascensiones mas dificiles necesitaran mas de
## una persona". Por debajo de esto sube uno solo; de aqui para arriba
## hace falta quien asegure la cuerda o vaya a buscar ayuda si algo sale
## mal, y eso no lo hace un unico explorador.
##
## Estuvo en 0,6 y era demasiado bajo: con relieve de verdad, cualquier
## cumbre con buen desnivel -[Ascent.difficulty] pesa el desnivel un 45%-
## ya arañaba ese numero, así que un escalador solo casi nunca encontraba
## NINGUNA cumbre atacable y se pasaba la partida sin subir nunca, que es
## justo la queja de "ahora es la ascension la que no descubre nada": sin
## coronar, se pierde el vistazo grande desde arriba que es lo que hace de
## la ascension la exploracion que ve mas lejos y mas disperso. 0,80 deja
## solo la franja mas dura -pegada al techo de 0,88 que ya exige equipo
## que no existe- como la que de verdad pide compañía.
const HARD_PEAK_PARTY_THRESHOLD := 0.80

## Cuanta gente hace falta puesta en ascension para atacar una cumbre dura.
const MIN_CLIMBING_PARTY := 2


## Cuanta gente de la banda esta puesta en ascension ahora mismo.
func _ascension_party_size() -> int:
	var n := 0
	for p: Inhabitant in people:
		if p.job == Profession.Job.EXPLORACION \
				and p.current_speciality == Profession.Speciality.ASCENSION:
			n += 1
	return n


## Si esta cumbre se puede atacar con la gente que hay puesta en ello ahora.
func _climbing_party_enough(hardness: float) -> bool:
	return hardness < HARD_PEAK_PARTY_THRESHOLD \
		or _ascension_party_size() >= MIN_CLIMBING_PARTY


## La cumbre que ESTA persona se atreve a atacar.
##
## La mas dura que su pericia le permite, que es lo que hace alguien de
## verdad: no la mas alta que hay, la mas alta a la que se atreve. Un novato
## mira el pico grande, calcula, y se va al de al lado.
## La cumbre que ha señalado el jugador a mano, si ha señalado alguna.
var peak_order: Vector3 = Vector3.ZERO
var has_peak_order: bool = false


## Todas las cumbres que la banda tiene a la vista, para pintarlas y
## poder pincharlas. Ver [ParajeMarkers.refresh_peaks].
func peaks() -> Array[Dictionary]:
	return _find_peaks()


## Quién de la banda se atreve con esta cumbre, o null si nadie.
##
## Se mira la pericia de ASCENSION de cada cual contra la dureza del pico
## -[Ascent.dares]-, no quién esté libre: la pregunta del jugador al pinchar
## el botón es «¿puede alguien con esto?», y la respuesta no depende de en
## qué ande metido hoy.
## Todos los que se atreven con esta cumbre, de más a menos pericia.
##
## Existe para poder ENSEÑARLOS. Mandar a alguien a una pared se decidía sobre
## una cifra —«el mejor»— y perder al mejor no duele igual que perder a Jara,
## que tiene cuarenta y un años y es la única que sabe curtir. Ver
## `GameUI.show_peak`.
func climbers_for(peak: Dictionary) -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	if peak.is_empty():
		return out
	var hardness := float(peak.get("hard", 1.0))
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	for person: Inhabitant in people:
		if not Profession.can_do(Profession.Job.EXPLORACION, person):
			continue
		if Ascent.dares(person.skill_in(task)) < hardness:
			continue
		out.append(person)
	out.sort_custom(func(a: Inhabitant, b: Inhabitant) -> bool:
		return a.skill_in(task) > b.skill_in(task))
	return out


func climber_for(peak: Dictionary) -> Inhabitant:
	if peak.is_empty():
		return null
	var hardness := float(peak.get("hard", 1.0))
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)

	var best: Inhabitant = null
	var best_skill := -1.0
	for person: Inhabitant in people:
		if not Profession.can_do(Profession.Job.EXPLORACION, person):
			continue
		var skill := person.skill_in(task)
		if Ascent.dares(skill) < hardness:
			continue
		if skill > best_skill:
			best_skill = skill
			best = person
	return best


## Manda intentar una cumbre. Devuelve "" si sale la orden, o el motivo por
## el que no.
##
## Los motivos son tres y se dicen distintos a propósito: no es lo mismo
## «no se puede con lo que hay» -pide equipo que nadie sabe hacer todavía-
## que «nadie tiene el nivel», ni que «hace falta más de uno».
## `who` deja elegir a mano quién sube. Sin él sube el de más pericia, que es
## lo que hacía siempre.
func order_ascent(peak: Dictionary, who: Inhabitant = null) -> String:
	if peak.is_empty():
		return "No hay tal cumbre."
	var hardness := float(peak.get("hard", 1.0))

	if Ascent.needs_gear(hardness):
		return "Esa pared no se sube con lo que hay. Haría falta cuerda de " \
			+ "verdad y quien sepa asegurar, y eso todavía no se sabe hacer."

	if not _climbing_party_enough(hardness):
		return "Una cumbre así no se ataca en solitario: hacen falta al menos " \
			+ "%d en ascensión antes de intentarla." % MIN_CLIMBING_PARTY

	var climber := who if who != null else climber_for(peak)
	if climber == null:
		return "No hay ningún miembro de la banda con habilidad suficiente."
	if not climbers_for(peak).has(climber):
		return "%s no se atreve con esa pared." % climber.given_name

	# Se le pone en ascensión y se le señala ESA cumbre: `peak_for` la
	# devuelve mientras la orden esté puesta.
	climber.set_priority(Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION), 1)
	peak_order = peak["pos"]
	has_peak_order = true
	apply_priorities()
	_note(Chronicle.Kind.TIERRA, "%s va a intentar la cumbre %s."
		% [climber.given_name, parajes.place_name(peak_order, home_position)], 1)
	return ""


func peak_for(person: Inhabitant) -> Dictionary:
	var peaks := _find_peaks()
	if peaks.is_empty():
		return {}

	var skill := person.skill_in(Profession.task_id(
		Profession.Job.EXPLORACION, Profession.Speciality.ASCENSION))
	var dares := Ascent.dares(skill)

	# La cumbre señalada a mano manda sobre la que elegiría la banda, igual
	# que el rumbo de exploración manda sobre la frontera -si quien va se
	# atreve con ella, claro.
	if has_peak_order:
		for peak: Dictionary in peaks:
			if (peak["pos"] as Vector3).distance_to(peak_order) > 1.0:
				continue
			if float(peak["hard"]) <= dares and _reachable(person, peak["pos"]):
				return peak

	# TODAS las que se atreve a atacar, no la primera de la lista.
	#
	# Devolver la primera hacia que la banda subiera siempre los mismos picos
	# y en el mismo orden: la lista sale ordenada del terreno, que no cambia,
	# asi que la eleccion no tenia ni un gramo de azar aunque la partida si.
	var within: Array[Dictionary] = []
	for peak: Dictionary in peaks:
		# Las que piden equipo no se intentan siquiera: no es que sean
		# dificiles, es que no se suben con lo que hay
		if Ascent.needs_gear(float(peak["hard"])):
			continue
		if not _climbing_party_enough(float(peak["hard"])):
			continue
		if not _reachable(person, peak["pos"]):
			continue
		if float(peak["hard"]) <= dares:
			within.append(peak)

	if not within.is_empty():
		# De las que puede, tira a las mas dificiles: es lo que hace alguien
		# con ganas de mirar lejos. Pero no siempre la peor, que seria un
		# automata igual que ir siempre a la primera.
		within.sort_custom(func(a, b): return float(a["hard"]) > float(b["hard"]))
		var reach := maxi(within.size() / 2, 1)
		return within[_rng.randi() % reach]

	# Ninguna a su altura: la mas suave que haya, que es lo que hace alguien
	# de verdad -mirar el monte y bajar el objetivo- en vez de ir derecho a la
	# peor pared del valle.
	for i in range(peaks.size() - 1, -1, -1):
		if Ascent.needs_gear(float(peaks[i]["hard"])):
			continue
		if not _climbing_party_enough(float(peaks[i]["hard"])):
			continue
		if _reachable(person, peaks[i]["pos"]):
			return peaks[i]
	return {}


## Si ese punto cae en una cumbre que la banda ya ha coronado.
##
## Se compara con holgura -media distancia minima entre cumbres- porque el
## barrido radial no cae dos veces exactamente en el mismo sitio, y sin la
## holgura el explorador volveria al mismo alto por un metro de diferencia.
func _already_climbed(point: Vector3) -> bool:
	for peak: Vector3 in _climbed:
		var flat := Vector2(point.x - peak.x, point.z - peak.z)
		if flat.length() < PEAK_MIN_DISTANCE * 0.5:
			return true
	return false


func has_peak() -> bool:
	var peaks := _find_peaks()

	# Coronarlas TODAS tambien es un hito, y tambien se apagaba en silencio:
	# `peak_for` devolvia vacio, el explorador caia en la exploracion normal y
	# el jugador se quedaba mirando un panel donde la ascension no volvia a
	# pasar nunca sin saber por que.
	if peaks.is_empty() and not _peaks_done and not _climbed.is_empty():
		_peaks_done = true
		_note(Chronicle.Kind.TIERRA,
			"No queda cumbre al alcance que no se haya coronado. Se han "
				+ "subido %d, y desde arriba ya se ha visto todo lo que "
					% _climbed.size()
				+ "habia que ver por aqui.", 2)
	return not peaks.is_empty()


## Lo que se cobra al llegar arriba: una revelacion grande y de golpe, con la
## claridad cayendo con la distancia -eso ya lo hace `see_from` solo-, y una
## ascension mas en la cuenta. No hace falta prospectar ni trabajar la cima:
## la recompensa de subir es la vista, no un recurso.
## Si esta persona esta de verdad EN la cima, y no en cualquier otro sitio al
## que haya ido a parar. La comprobacion es en planta -sin la altura- porque
## el pico guarda la cota del terreno y la persona la suya propia.
func _is_on_peak(person: Inhabitant) -> bool:
	for peak: Dictionary in _find_peaks():
		var pos: Vector3 = peak["pos"]
		var flat := Vector2(person.position.x - pos.x, person.position.z - pos.z)
		if flat.length() < arrive_radius * 2.0:
			return true
	return false


func _do_ascent(person: Inhabitant) -> void:
	if knowledge:
		knowledge.see_from(person.position, ASCENT_SIGHT_RANGE)
		_reveal_from_summit(person.position)
	ascents += 1
	person.fatigue = clampf(person.fatigue + 15.0, 0.0, 100.0)

	# Si era la que el jugador habia señalado, la orden se cumple y se quita
	if has_peak_order and person.position.distance_to(peak_order) < PEAK_MIN_DISTANCE:
		has_peak_order = false

	# Esta cumbre queda coronada: no se vuelve. La vista ya esta descubierta y
	# repetirla no aporta nada, asi que el barrido buscara la siguiente y, si
	# no queda ninguna, la ascension se comportara como una expedicion normal.
	_climbed.append(person.position)
	_peak_found = false

	var remaining := has_peak()
	var where := parajes.place_name(person.position, home_position)
	if ascents == 1:
		_note(Chronicle.Kind.HALLAZGO,
			"%s corono el alto %s. Desde alli se ve de golpe lo que costaria "
				% [person.given_name, where] + "semanas recorrer.", 2)
	elif remaining:
		_note(Chronicle.Kind.HALLAZGO,
			"%s corono otra cumbre, la %d de la banda. Queda mas monte por "
				% [person.given_name, ascents] + "encima del valle.", 1)
	else:
		_note(Chronicle.Kind.HALLAZGO,
			"%s corono la ultima cumbre al alcance. Ya no queda alto que suba "
				% person.given_name
			+ "lo bastante: a partir de ahora saldran de expedicion.", 2)

	# Y se para la partida a enseñarlo. Coronar un pico revela media comarca de
	# golpe -ver `_reveal_from_summit`- y hasta ahora eso era un cambio callado
	# en el mapa de niebla que el jugador descubría después, si se fijaba.
	raise_moment(Moment.summit(
		"Cumbre coronada",
		"%s ha coronado el alto %s. Desde arriba se lee de una vez medio valle: "
			% [person.given_name, where]
		+ "dónde abunda la caza, por dónde va el agua y qué queda por explorar.",
		person.position, person))


## Que tan clara tiene que verse una celda desde el pico para que coronar
## cuente como haberla conocido de verdad, y no solo como niebla de guerra
## levantada.
##
## Es la misma claridad que ya calcula `see_from` -1 junto al pico, cayendo
## hacia el borde del alcance-, asi que 0,65 deja la mitad mas cercana del
## radio con reves de verdad y el borde brumoso solo como mapa visto, no
## conocido.
const SUMMIT_REVEAL_CLARITY := 0.65


## Lo que se ve desde arriba no es solo paisaje: quien corona lee un valle
## entero desde el mirador, donde abunda cada cosa a ojo, igual que ha
## hecho siempre cualquiera que sube a mirar antes de bajar a trabajar.
##
## Es lo que hace de la ascension la exploracion que ve MAS LEJOS Y MAS
## DISPERSO -peticion explicita-, y no una expedicion mas con vistas: sin
## esto, coronar solo destapaba niebla de guerra -`see_from`, que apunta a
## `explored` y no a `familiarity`- y ningun paraje lejano nacia nunca de
## subir a un pico, por mucho que la cronica dijera "se ve de golpe lo que
## costaria semanas recorrer".
func _reveal_from_summit(peak_position: Vector3) -> void:
	if knowledge == null or field == null:
		return
	for z in range(field.height):
		for x in range(field.width):
			var centre := field.cell_center(x, z)
			if centre.distance_to(peak_position) > ASCENT_SIGHT_RANGE:
				continue
			if knowledge.explored_at(centre) < SUMMIT_REVEAL_CLARITY:
				continue
			for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
					Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
					Subsistence.Activity.MATERIA_PRIMA]:
				knowledge.reveal(activity as Subsistence.Activity, centre,
					BandKnowledge.KNOWN_ENOUGH + 0.02)


## Levanta un momento: algo que hay que enseñar o decidir ahora. Ver [Moment].
func raise_moment(moment: Moment) -> void:
	moment_raised.emit(moment)


## Cómo va la reserva de cara al invierno.
##
## Es la cuenta central de la época —SLICE_PALEOLITICO §3: el otoño decide si
## sobrevives al invierno— y hasta ahora sólo existía repartida entre el almacén
## y la cabeza del jugador. Devuelve raciones guardadas, las que hacen falta
## para pasar el invierno entero, y la fracción entre las dos.
func winter_stock() -> Dictionary:
	var mouths := 0.0
	for person: Inhabitant in people:
		mouths += person.daily_food()
	var needed := mouths * float(Subsistence.DAYS_PER_SEASON)
	var have := store.food_rations()
	return {
		"have": have, "needed": needed,
		"share": have / maxf(needed, 0.001),
	}


## Lo que se lleva el fuego en un día, y qué pasa si no lo hay.
##
## Dos cosas lo apagan y las dos son las que pide el diseño: que se acabe la
## leña y que no lo cuide nadie. La segunda no es un castigo arbitrario —un
## hogar sin nadie encima se apaga solo en una noche— y es lo que hace que el
## mínimo de gente en el hogar signifique algo: hasta ahora se podía dejar el
## oficio vacío y no pasaba nada.
##
## Y se cuenta: apagarse sin que quede rastro en la crónica sería un castigo
## invisible, que es la peor clase.
func _burn_hearth() -> void:
	var built: bool = camp_built.get(CampProjects.Kind.HOGAR, false)
	var tended := _hearth_tended
	_hearth_tended = false
	if not built or not hearth_lit:
		return

	if not tended:
		hearth_lit = false
		hearth_relight = 0.0
		_note(Chronicle.Kind.PENURIA,
			"Nadie se quedó al cuidado del hogar y el fuego se apagó.", 2)
		return

	var wanted := HEARTH_WOOD_PER_DAY
	if GameState.season == Subsistence.Season.INVIERNO:
		wanted *= HEARTH_WINTER_FACTOR
	if _hearth_keeper():
		wanted *= YESQUERO_SAVING

	var burnt := store.take(Materia.Kind.LENA, wanted)
	if burnt >= wanted - 0.001:
		return

	hearth_lit = false
	hearth_relight = 0.0
	_note(Chronicle.Kind.PENURIA,
		"Se acabó la leña y el hogar se quedó frío.", 2)


## Si hoy hay alguien en el hogar, que es quien estira la leña.
##
## Era una ESPECIALIDAD -yesquero- y ya no: el hogar del Paleolitico lo hace
## todo, y quien lo atiende sabe prender, estirar la leña, ahumar y cuidar. Ver
## `Profession.SPECIALITIES`.
func _hearth_keeper() -> bool:
	for person: Inhabitant in people:
		if person.job == Profession.Job.HOGAR:
			return true
	return false


## Quien trabaja SIN salir del abrigo: el hogar y el taller.
##
## Los dos hacen faena de verdad y ninguno tiene tajo en el monte, asi que no
## abren salida ni piden camino. Eso los dejaba fuera del estado TRABAJANDO y
## haciendo su jornada desde OCIOSO, o sea que la banda salia en pantalla
## parada media jornada cuando no lo estaba: medido en el sitio 56, ocho dias,
## el 39,6 % de las horas de luz figuraba como ocio y de ese ocio el 17,2 % era
## el hogar y el 16,0 % el taller, los dos trabajando.
func _works_at_camp(person: Inhabitant) -> bool:
	return person.job == Profession.Job.HOGAR \
		or person.job == Profession.Job.MANUFACTURA


## Si a esta persona le queda jornada, contando que ya ha anochecido.
##
## De noche solo se trabaja AL FUEGO Y EN CASA. Es la diferencia entre una
## banda y una cuadrilla de turnos: fuera no hay luz, y la que hay es la del
## hogar. Quien esta en el abrigo con el fuego encendido puede seguir tallando
## o curtiendo despues de que se ponga el sol; quien esta en el monte, no.
##
## Y a la hora de dormir se acaba para todos, tengan fuego o no: [HORA_DORMIR]
## no se negocia. Una banda que talla hasta la madrugada porque le sobra leña
## es un almacen con antorchas, no gente.
func _can_work_at_night(person: Inhabitant) -> bool:
	if hour < HORA_SALIDA or hour >= HORA_DORMIR:
		return false
	if hour < HORA_REGRESO:
		return true
	# Anochecido: hace falta estar en el abrigo y que el hogar arda.
	return hearth_lit and _at_shelter(person)


## Lo que cansa una jornada de taller o de hogar, por hora.
##
## A CERO, que es exactamente lo que valia hasta ahora: en OCIOSO no se sumaba
## fatiga ninguna, asi que el tallador podia trabajar el ano entero sin
## cansarse. Se deja escrito y en su sitio para poder subirlo cuando toque
## ajustar -curtir pieles cansa, y no como andar diez kilometros-, pero
## subirlo AHORA seria cambiar el juego a la vez que se arregla el nombre, y
## entonces no se sabria cual de las dos cosas movio los numeros.
const CAMP_FATIGUE_RATE := 0.0


## La jornada de quien se queda en el abrigo.
##
## No bate el paraje -no hay paraje- ni se vuelve a casa al cansarse -ya esta
## en casa-, que son las dos cosas que hace el trabajo de monte y aqui no
## pintan. Lo demas es igual: se trabaja hasta la hora de recogerse, y de eso
## se encarga el bloque de `winding_down`.
func _camp_work(person: Inhabitant, hours: float) -> void:
	# Quieto. TRABAJANDO es uno de los estados que ANDAN -ver el bloque de
	# movimiento-, asi que sin esto el del taller se echaria a andar hacia el
	# ultimo destino que tuviera apuntado, que es el tajo del oficio anterior.
	person.target = person.position
	person.route = PackedVector3Array()
	person.route_step = 0
	if CAMP_FATIGUE_RATE > 0.0:
		person.fatigue = clampf(person.fatigue
			+ hours * CAMP_FATIGUE_RATE * person.fatigue_factor(), 0.0, 100.0)
	if person.job == Profession.Job.HOGAR:
		# El hogar levanta lo que este en cola y, si ya hay secadero, ahuma lo
		# que haya llegado fresco.
		_tend_camp(person, hours)
	else:
		# El taller no sale a picar piedra. En la tabla de oficios figura con
		# actividad MATERIA_PRIMA -es de donde saca lo que talla- y eso lo
		# mandaba cada manana a un cotarro al otro lado del valle: medido, un
		# tallador se pasaba el 79 % del dia andando y no salia una sola pieza.
		# La materia prima la traen los recolectores; el artesano trabaja sobre
		# lo que hay en el abrigo, y si no hay, se va a su siguiente oficio
		# -ver `_speciality_can_work`.
		_craft(person, hours)


## Trabajo de quien esta en el hogar: no sale del campamento. Si hay un
## proyecto en cola lo saca adelante; si no, y ya hay secadero, ahuma lo que
## haya de carne fresca. Sin ninguna de las dos cosas, simplemente cuida del
## fuego y de quien no puede valerse solo, que es lo que ya hacia antes de
## que existiera nada de esto.
func _tend_camp(person: Inhabitant, hours: float) -> void:
	var fraction := hours / HORAS_UTILES
	if fraction <= 0.0:
		return

	# El hogar no se le pide a nadie: es lo primero que levanta una banda al
	# llegar a un abrigo. Y hasta ahora no lo levantaba NUNCA, porque poner una
	# obra en cola sólo lo hacía el jugador desde el panel. Medido antes de
	# arreglarlo: cuarenta y cinco jornadas con ciento ochenta y cinco de leña
	# guardada y el abrigo todavía sin hogar, o sea la banda entera comiendo
	# crudo por un menú que nadie había abierto.
	if camp_queue < 0 and not camp_built.get(CampProjects.Kind.HOGAR, false):
		queue_project(CampProjects.Kind.HOGAR)

	if camp_queue >= 0 and not camp_built.get(camp_queue, false):
		# El nombre se coge ANTES de trabajar: la jornada que termina la obra
		# vacía la cola -`_work_on_project` deja `camp_queue` en -1- y pedir
		# el nombre después reventaba con «Out of bounds get index '-1'»
		# justo al acabar el hogar, que es lo primero que levanta la banda.
		var doing := CampProjects.project_name(
			camp_queue as CampProjects.Kind).to_lower()
		_work_on_project(person, fraction)
		person.log_deed(person.current_task(), "levantando %s" % doing, false)
		return

	# Prender otra vez es lo primero, por delante del secadero: sin brasas no se
	# ahuma nada, así que ponerse al secadero con el fuego apagado sería una
	# jornada tirada.
	if camp_built.get(CampProjects.Kind.HOGAR, false) and not hearth_lit:
		_relight_hearth(person, fraction)
		return

	_hearth_tended = _hearth_tended or hearth_lit

	if hearth_lit and camp_built.get(CampProjects.Kind.SECADERO, false):
		# Ahumar es del hogar, sin especialidad que lo separe: el que mantiene
		# el fuego es el que cura la carne, porque es el mismo fuego.
		var skill := person.effectiveness() * AHUMADO_BONUS
		_dry_meat(fraction, skill)
		person.log_deed(person.current_task(), "ahumando carne", false)
		return

	# Y cuidar de quien no se vale, tambien. Se hace cuando hay a quien cuidar
	# y no hay fuego que atender ni carne que curar.
	if _someone_hurt():
		_tend_the_hurt(person, fraction)
		return

	person.log_deed(person.current_task(),
		"manteniendo el fuego" if hearth_lit else "en el abrigo, sin fuego",
		false)


## Si hay alguien a quien cuidar: heridos, o quien no se vale solo.
func _someone_hurt() -> bool:
	for person: Inhabitant in people:
		if person.hurt_days > 0:
			return true
	return false


## Prender el hogar otra vez, que cuesta jornada y leña.## Prender el hogar otra vez, que cuesta jornada y leña.
##
## Cuesta las dos cosas a propósito. Encender no es el problema —la banda sabe
## hacer fuego, ver SLICE_PALEOLITICO §1— y por eso no cuesta una tirada de
## suerte: lo que cuesta es la mañana de alguien y la leña que hay que reunir,
## que es exactamente lo que se pierde cuando se deja apagar.
func _relight_hearth(person: Inhabitant, fraction: float) -> void:
	person.log_deed(person.current_task(), "prendiendo el fuego", false)
	var pace := person.effectiveness() * YESQUERO_BONUS
	hearth_relight += fraction * pace
	if hearth_relight < HEARTH_RELIGHT_DAYS:
		return
	# No basta la leña de prenderlo: hace falta además con qué alimentarlo el
	# resto del día. Sin esta condición se entraba en un bucle de prenderlo por
	# la mañana y quedarse frío por la noche, gastando cada jornada la leña que
	# la banda acababa de traer y sin llegar nunca a tener fuego de verdad.
	if store.amount(Materia.Kind.LENA) < HEARTH_RELIGHT_WOOD + HEARTH_WOOD_PER_DAY:
		return
	store.take(Materia.Kind.LENA, HEARTH_RELIGHT_WOOD)
	hearth_relight = 0.0
	hearth_lit = true
	_hearth_tended = true
	_note(Chronicle.Kind.OBRA,
		"%s volvió a prender el hogar." % person.given_name, 1)


## Cuidar de quien no se vale solo. Adelanta la convalecencia de los heridos.
func _tend_the_hurt(person: Inhabitant, fraction: float) -> void:
	var worst: Inhabitant = null
	for other: Inhabitant in people:
		if other.hurt_days <= 0:
			continue
		if worst == null or other.hurt_days > worst.hurt_days:
			worst = other
	if worst == null:
		person.log_deed(person.current_task(), "manteniendo el fuego", false)
		return
	person.log_deed(person.current_task(),
		"cuidando de %s" % worst.given_name, false)
	_care_given += fraction * person.effectiveness()


## Pone en cola una mejora del abrigo. Falla si ya esta hecha o si le falta la
## que necesita antes -el secadero sin hogar, por ejemplo-.
func queue_project(kind: CampProjects.Kind) -> bool:
	if camp_built.get(kind, false):
		return false
	var needs := CampProjects.requires(kind)
	if needs >= 0 and not camp_built.get(needs, false):
		return false
	camp_queue = kind
	camp_progress = 0.0
	_camp_paid = false
	return true


func _work_on_project(person: Inhabitant, fraction: float) -> void:
	if camp_queue < 0:
		return
	var kind := camp_queue as CampProjects.Kind

	# El material se paga una vez, al arrancar. Si no hay bastante, el
	# proyecto espera: no se descuenta a medias ni se avanza sin haberlo
	# pagado.
	if not _camp_paid:
		for material: int in CampProjects.materials(kind):
			var wanted: float = float(CampProjects.materials(kind)[material])
			if store.amount(material as Materia.Kind) < wanted:
				return
		for material: int in CampProjects.materials(kind):
			store.take(material as Materia.Kind,
				float(CampProjects.materials(kind)[material]))
		_camp_paid = true

	camp_progress += fraction * person.effectiveness()
	if camp_progress < CampProjects.labor_days(kind):
		return

	camp_built[kind] = true
	# Se levanta el hogar y se prende de una vez: nadie delimita una fogata con
	# piedras para dejarla apagada.
	if kind == CampProjects.Kind.HOGAR:
		hearth_lit = true
		_hearth_tended = true
	camp_queue = -1
	camp_progress = 0.0
	_camp_paid = false
	_note(Chronicle.Kind.OBRA,
		"Queda levantado el %s del abrigo, obra de %s."
			% [CampProjects.project_name(kind).to_lower(), person.given_name], 2)


## Cuanto ahuma un dia entero de trabajo al frente del secadero, a rendimiento
## perfecto. Una persona no seca una res al dia: es un goteo constante,
## limitado sobre todo por cuanta carne fresca vaya llegando de la caza.
## Raciones que ahuma una jornada entera de alguien en el hogar.
##
## Eran cuatro, y cuatro no es un secadero: es un pincho. Medido en el sitio
## 56 con tres personas en la pesca de orilla, la banda descargaba 53
## raciones de pescado al dia y el almacen se quedaba clavado en 124, porque
## el pescado fresco aguanta TRES DIAS y se pudria mas deprisa de lo que se
## podia curar. El jugador lo veia como «pescan pero no sube el pescado».
##
## Veinticuatro es lo que da de si un bastidor sobre el hogar con alguien
## atendiendolo la jornada entera: da para el remonte de un rio, que es
## justo lo que tiene que dar.
const DRY_PER_DAY := 24.0


## Lo que se cura y en que se convierte. La carne en cecina, el pescado en
## pescado seco: no es lo mismo y no se llama igual.
const CURADO := {
	Materia.Kind.PESCADO: Materia.Kind.PESCADO_SECO,
	Materia.Kind.CARNE: Materia.Kind.CARNE_SECA,
}


## Ahuma lo que se pudre: carne y PESCADO.
##
## El secadero solo curaba carne, y el pescado —que aguanta tres dias, uno
## menos que la carne— se perdia entero. Ahumar el remonte del salmon es la
## razon de plantarse en el rio: no se pesca para comer hoy, se pesca para
## comer en enero. Se cura primero lo que antes se pudre, que es lo mismo que
## se come primero.
func _dry_meat(fraction: float, skill: float) -> void:
	var capacity := DRY_PER_DAY * fraction * skill
	if capacity <= 0.0:
		return

	var fresh: Array[int] = []
	for kind: int in CURADO:
		fresh.append(kind)
	fresh.sort_custom(func(a: int, b: int) -> bool:
		return Materia.shelf_life(a as Materia.Kind) 			< Materia.shelf_life(b as Materia.Kind))

	for kind: int in fresh:
		if capacity <= 0.0:
			break
		var raw := kind as Materia.Kind
		var dried := minf(capacity, store.amount(raw))
		if dried <= 0.0:
			continue
		store.take(raw, dried)
		store.add(CURADO[raw] as Materia.Kind, dried)
		capacity -= dried


## Dónde se pone esta persona cuando está en el abrigo, según lo que hace.
##
## Estable por `id`, igual que el carril de la marcha y el reparto del tajo: si
## se sorteara cada vez, la banda temblaría dentro de la cueva.
func _home_spot(person: Inhabitant, inside: bool) -> Vector3:
	var centre := home_inside if inside else home_forecourt
	if centre == Vector3.ZERO:
		centre = home_position
	var spread := CAVE_SPREAD if inside else FORECOURT_SPREAD
	var angle := TAU * fmod(float(person.id) * 0.618, 1.0)
	var reach := spread * (0.35 + fmod(float(person.id) * 0.37, 0.65))
	var spot := centre + Vector3(cos(angle), 0.0, sin(angle)) * reach
	# Dentro de la cueva la altura es la del SUELO DE LA CUEVA, que la trae el
	# punto de referencia; preguntársela al terreno pondría a la gente encima
	# del monte que tapa la galería. Fuera sí manda el terreno.
	if _terrain and not inside:
		spot.y = _terrain.get_height_at(spot)
	else:
		spot.y = centre.y
	return spot


## Si alguien esta YA en el abrigo, campa de la boca incluida.
##
## Se miraba con `distance_to(home_position) < arrive_radius`, y eso deja la
## puerta fuera de casa: la campa esta a su propia distancia del punto del
## abrigo y la gente se reparte por ella hasta [FORECOURT_SPREAD], asi que
## quien estaba plantado delante de la cueva caia fuera del radio de llegada.
## A la hora de recogerse se le mandaba «a casa» estando en casa: VOLVIENDO,
## tres metros, llegar, ocioso, `_settle_at_home` lo devolvia a la campa, y
## otra vez. Medido en el sitio 56 con la banda entera ocho jornadas: el 3,8 %
## de las horas de luz figuraba como «volviendo» a menos de treinta metros de
## la boca.
##
## El alcance no es un numero elegido: es hasta donde llega la propia campa.
func _at_shelter(person: Inhabitant) -> bool:
	return person.position.distance_to(home_position) <= _shelter_reach()


## Hasta donde llega el abrigo, en metros.
##
## No es un numero elegido: es lo que ocupan de verdad la galeria y la campa,
## que es donde `_home_spot` reparte a la gente. Si el abrigo se muda -ver
## `move_home`- el alcance se muda con el.
func _shelter_reach() -> float:
	# El reparto existe con cueva y sin ella: cuando no hay boca marcada
	# `_home_spot` reparte alrededor del propio punto del abrigo, con la misma
	# holgura. Partir del radio de llegada a secas dejaba fuera de casa, otra
	# vez, a quien cayera en el borde de la campa.
	var reach := maxf(arrive_radius, maxf(CAVE_SPREAD, FORECOURT_SPREAD))
	if home_forecourt != Vector3.ZERO:
		reach = maxf(reach,
			home_position.distance_to(home_forecourt) + FORECOURT_SPREAD)
	if home_inside != Vector3.ZERO:
		reach = maxf(reach,
			home_position.distance_to(home_inside) + CAVE_SPREAD)
	return reach


## Si quien vuelve ya ha llegado, aunque no pise el punto exacto del abrigo.
##
## Llegar se medía con seis metros al punto del abrigo, y el camino de vuelta
## no lo traza una persona: lo traza la rejilla, que no llega mas fino que su
## celda -cuarenta metros- y ademas amarra el destino al suelo firme mas
## cercano, ver `_firm_ground`. O sea que la ruta se acaba legitimamente a
## veinte metros de la boca y alli ya no queda camino que andar.
##
## Lo que pasaba entonces no era un atasco -no hay ruta que seguir- sino algo
## peor y mas callado: no se entregaba la carga, no se cerraba la salida, no
## se cenaba y no se dormia, porque los cuatro se preguntaban lo mismo. La
## persona se quedaba de pie en la puerta hasta que a la mañana siguiente
## `_send_to_work` le tiraba la carga entera a la basura -ver `lost_loads`-.
##
## Medido en el sitio 56, la banda entera ocho jornadas: 264 horas-persona
## plantadas entre seis y cuarenta metros del abrigo en estado «volviendo»,
## frente a 282 andando de verdad. Y en las salidas de recoleccion que volvian
## de vacio -el 85 %-, cuatro horas y tres cuartos de «volviendo» contra una
## centesima de hora trabajando.
func _home_reached(person: Inhabitant) -> bool:
	if _at_shelter(person):
		return true
	# Con camino por delante todavia se esta volviendo de verdad.
	if person.route_step < person.route.size():
		return false
	# Sin camino y a una celda de la boca, se ha llegado: mas cerca no sabe
	# dejar a nadie la rejilla.
	return person.position.distance_to(home_position) <= Navgrid.CELL


## Coloca a quien está en el abrigo dentro o en la puerta, según el estado.
##
## Se llama al final del tick de cada persona y sólo toca a quien ya está en
## casa: si tocara a quien va de camino, lo teletransportaría a media marcha.
func _settle_at_home(person: Inhabitant, delta: float) -> void:
	if not _home_reached(person):
		return
	# En casa no hay vivac que valga: se duerme en la cueva.
	person.bivouac_fire = false
	var spot := Vector3.ZERO
	match person.state:
		Inhabitant.State.DURMIENDO:
			spot = _home_spot(person, true)
		Inhabitant.State.OCIOSO, Inhabitant.State.COMIENDO:
			spot = _home_spot(person, false)
		Inhabitant.State.TRABAJANDO:
			# El hogar y el taller trabajan en la campa de la boca. Al de
			# monte no le toca: su sitio es el tajo.
			if not _works_at_camp(person):
				return
			spot = _home_spot(person, false)
		_:
			return
	# Los ultimos metros se ANDAN, no se aparecen.
	#
	# Antes esto colocaba a la gente de golpe, y valia porque solo tocaba a
	# quien ya estaba a tres radios de llegada. Ahora recoge a cualquiera que
	# haya llegado -y llegar es agotar el camino a una celda de la boca, ver
	# `_home_reached`-, asi que el salto podia ser de cuarenta metros: gente
	# apareciendose en la puerta a la vista del jugador. Medido: 88
	# horas-persona plantadas entre dieciocho y cuarenta metros del abrigo.
	person.position = person.position.move_toward(spot, walk_speed * delta)


## Se abandona un destino al que no se consigue llegar.
##
## No es lo mismo que atascarse: aquí no se ha perdido el día ni hace falta
## contarlo en la crónica. Es «por ahí no se pasa», que es una cosa que se
## aprende andando, y lo que corresponde es probar otro sitio.
func _give_up_on(person: Inhabitant, goal: Vector3) -> void:
	person.route = PackedVector3Array()
	person.route_step = 0
	person.survey_hours = 0.0
	# Lo que se descarta es ESE SITIO, no el oficio entero. Marcando la
	# actividad como inalcanzable se dejaría de cazar en todo el valle por un
	# cortado de cincuenta metros; lo que hay que hacer es ir al siguiente
	# cotarro. De eso se encarga `_best_known_spot`, que ya no elige lo que
	# esta persona tiene apuntado como imposible.
	person.state = Inhabitant.State.OCIOSO
	if not _given_up_on(person, goal):
		person.given_up.append(goal)

	# La salida se CIERRA, y se cierra diciendo la verdad. Dejarla abierta es
	# el fallo que ya está avisado en `end_journey`: una salida que no se cierra
	# sigue sumando kilómetros de los días siguientes, y además el jugador no ve
	# nunca en los rastros qué pasó con la jornada.
	if not person.journey.is_empty():
		person.end_journey(day,
			parajes.place_name(person.position, home_position),
			"por ahi no se pasa: se probo otro sitio")

	_record_stuck(person, "por ahi no se pasa: se prueba otro sitio")
	stuck_tally[RENUNCIA] = int(stuck_tally.get(RENUNCIA, 0)) + 1


## El motivo de renunciar a un destino, con nombre fijo para poder contarlo.
const RENUNCIA := "por ahi no se pasa"


## Si esta persona ya se dio hoy por vencida con este sitio.
func _given_up_on(person: Inhabitant, point: Vector3) -> bool:
	for gone: Vector3 in person.given_up:
		if gone.distance_to(point) < UNREACHABLE_SLACK:
			return true
	return false


## Manda a alguien a su tajo, o a buscarlo si no sabe donde esta.
##
## Es la mecanica que pediste: sin conocimiento NO se va en linea recta a un
## punto, porque nadie sabe donde esta ese punto. Se sale hacia una zona con
## el recurso y se bate hasta encontrarlo.
func _send_to_work(person: Inhabitant) -> void:
	# Lo primero, qué se hace hoy: quien no tiene especialidad fijada la elige
	# según lo que más falte
	person.current_speciality = _choose_speciality(person)
	# La actividad la manda la ESPECIALIDAD, no el oficio: «cantera» y
	# «fruto y raiz» son el mismo oficio para el jugador y dos sitios muy
	# distintos del monte para el terreno.
	person.activity = Profession.activity_of(
		person.job as Profession.Job,
		person.current_speciality as Profession.Speciality)
	# Lo que lleve encima se entrega ANTES de salir de nuevo. Estaba
	# limpiandose sin mas, asi que quien acababa la jornada sin pasar por el
	# abrigo -porque se atasco, porque se le cambio el oficio- perdia la carga
	# entera y nadie se enteraba: entre lo traido y lo guardado faltaba un
	# tercio de TODO, y el reparto era identico material a material, que es la
	# firma de una fuga y no de un gasto.
	if not person.load.is_empty():
		if _home_reached(person):
			_deliver(person)
		else:
			lost_loads += 1
	person.load.clear()
	person.carrying = 0.0
	person.search_hours = 0.0

	# Los recipientes se cogen al salir, y DESPUES de entregar: `_deliver`
	# los devuelve al abrigo, asi que repartirlos antes era dejar salir a la
	# gente con las manos vacias.
	_hand_out_containers(person)

	# El taller NO sale a picar piedra. Su oficio figura con la actividad
	# «materia prima» -es de donde saca lo que gasta- y eso le mandaba al
	# canchal como si fuera un recolector: se veia al tallador cruzando el
	# valle para traer cantos que cualquiera de los que ya estan fuera podia
	# haber traido de paso.
	#
	# Sale SOLO cuando de verdad falta lo que necesita para la pieza que toca,
	# y entonces es un recado, no una jornada de cantera.
	if person.job == Profession.Job.MANUFACTURA and not _workshop_short(person):
		person.has_task = true
		person.work_centre = home_position
		person.forage_target = home_position
		person.state = Inhabitant.State.TRABAJANDO
		return

	# Se prueban VARIOS tajos, no uno.
	#
	# Antes se pedia el mejor, y si no habia camino la persona se quedaba
	# ociosa en el campamento «en vez de salir a estrellarse contra el rio»
	# —y se quedaba asi PARA SIEMPRE, reintentando el mismo destino imposible
	# cada tick de cada dia. Medido en el sitio 56 con gente puesta en la
	# pesca de orilla: veinte jornadas seguidas ociosa, ruta 0, hambre 100,
	# sin una sola salida que pintar en los rastros. Desde fuera parecia que
	# el oficio no hacia nada, que es literalmente lo que pasaba.
	var destination := Vector3.ZERO
	for candidate: Vector3 in _work_candidates(person):
		_send_to(person, candidate)
		if not person.route.is_empty():
			destination = candidate
			break

	if destination == Vector3.ZERO:
		# A ningun tajo de este oficio se llega hoy. Se apunta —para que salga
		# en los atascos y no en el silencio— y se marca la actividad como
		# inalcanzable, que es lo que hace que el reparto de manana lo baje a
		# su siguiente oficio en vez de dejarlo mirando el rio desde casa.
		_record_stuck(person, "no hay camino hasta ningun tajo de %s"
			% Subsistence.activity_name(person.activity).to_lower())
		_unreachable_today[int(person.activity)] = true
		person.has_task = true
		person.state = Inhabitant.State.OCIOSO
		return

	# La jornada de trabajo tambien es una salida, con su camino y su
	# resultado. Solo las abrian los exploradores, y por eso en los rastros no
	# se pintaba nada mas que exploracion: el resto de la banda no tenia
	# ninguna salida que dibujar.
	if person.journey.is_empty():
		person.begin_journey(Profession.job_name(person.job as Profession.Job),
			day, hour, home_position)
	person.state = Inhabitant.State.YENDO

## Cuanta agua cubre un odre lleno, en horas.
##
## Una jornada util entera, y no es un numero elegido: ES la peticion. Un odre
## lleno tiene que dar para pasar el dia fuera, asi que se ata a [HORAS_UTILES]
## y se mueve con ella si algun dia cambia la jornada.
const SED_HORAS_CON_ODRE := HORAS_UTILES

## Cuanto se aguanta sin odre desde el ultimo trago.
##
## Media jornada. Lo unico que la peticion fija es que TIENE que ser menos que
## el dia entero -sin odre no se pasa la jornada lejos del agua-; la mitad es
## el reparto neutro dentro de esa condicion y es el numero de aqui que esta
## pendiente de playtest. Subirlo hace el odre menos necesario; bajarlo obliga
## a la banda a trabajar pegada al rio.
const SED_HORAS_SIN_ODRE := HORAS_UTILES * 0.5


## Cuantos odres LLENOS cuelgan del abrigo ahora mismo.
##
## El almacen no guarda agua a granel: guarda odres llenos, y por eso
## `Materia.Kind.AGUA` se mide en «odre» y pesa lo que pesa uno. La cifra no se
## lleva a mano -eso serian dos verdades sobre lo mismo- sino que se deriva de
## los odres que ha hecho el taller menos los que hay fuera con alguien.
##
## Y estan llenos porque el abrigo se funda junto al agua: colgar un odre en la
## boca de la cueva es tenerlo lleno. El que se vacia es el que sale.
func _sync_waterskins() -> void:
	if store == null or toolkit == null:
		return
	var out := 0
	for person: Inhabitant in people:
		if person.has_waterskin:
			out += 1
	var at_home := maxf(float(toolkit.count(Tool.Kind.ODRE) - out), 0.0)
	var now := store.amount(Materia.Kind.AGUA)
	if absf(now - at_home) < 0.01:
		return
	if now > at_home:
		store.take(Materia.Kind.AGUA, now - at_home)
	else:
		store.add(Materia.Kind.AGUA, at_home - now)


## Reparte cesto y odre entre los que salen, de lo que hay HECHO.
##
## Uno por cabeza y hasta donde llegue el taller: dos personas no comparten un
## odre. Antes se preguntaba si en el almacen quedaba piel o fibra en bruto,
## con lo que la banda entera salia siempre con los dos recipientes desde el
## primer dia -medido en el sitio 56: cero odres tallados y aun asi todo el
## mundo con odre- y el taller no servia para nada en este frente.
func _hand_out_containers(person: Inhabitant) -> void:
	person.has_basket = _take_container(person, Tool.Kind.CESTO)
	person.has_waterskin = _take_container(person, Tool.Kind.ODRE)
	# Se sale de casa con el odre lleno; sin odre, con lo que se lleva bebido.
	person.water_left = SED_HORAS_CON_ODRE if person.has_waterskin \
		else SED_HORAS_SIN_ODRE
	_sync_waterskins()


## Si queda una pieza de este tipo libre para esta persona.
func _take_container(person: Inhabitant, kind: Tool.Kind) -> bool:
	var made := toolkit.count(kind)
	if made <= 0:
		return false
	var taken := 0
	for other: Inhabitant in people:
		if other == person:
			continue
		var carries := other.has_basket if kind == Tool.Kind.CESTO \
			else other.has_waterskin
		if carries:
			taken += 1
	return taken < made


## El agua del dia: se bebe donde la hay y se gasta donde no.
##
## Es la regla que faltaba para que una banda no pueda plantarse una jornada
## entera en un canchal seco. Beber es gratis y no cuesta tiempo mientras se
## este JUNTO al agua -o en el abrigo, que se funda al lado de ella-; lo que
## cuesta es el viaje cuando se acaba a media tarde en mitad del monte.
func _drink_and_thirst(person: Inhabitant, hours: float) -> void:
	if _water_beside(person.position) or _at_shelter(person):
		person.water_left = SED_HORAS_CON_ODRE if person.has_waterskin \
			else SED_HORAS_SIN_ODRE
		return
	# Durmiendo no se bebe, pero tampoco se suda: la noche no cuenta.
	if person.state == Inhabitant.State.DURMIENDO:
		return
	person.water_left = maxf(person.water_left - hours, 0.0)
	if person.water_left > 0.0:
		return
	# Sin agua se deja el tajo. No se sigue trabajando sediento, que es
	# exactamente lo que se venia haciendo.
	if person.state != Inhabitant.State.TRABAJANDO \
			and person.state != Inhabitant.State.BUSCANDO:
		return
	# Al charco mas cercano si lo hay, y si no, al abrigo, que se funda junto
	# al agua. `_shore_near` solo mira setenta metros y devuelve el MISMO punto
	# cuando no encuentra nada: tomando eso por un destino, la persona se
	# quedaba plantada trabajando seca, que es justo lo que se venia a impedir.
	var water := _shore_near(person.position)
	if not _water_beside(water):
		water = home_position
	_send_to(person, water)
	person.state = Inhabitant.State.YENDO
	person.log_deed(person.current_task(), "a por agua", false)


## Cuantos tajos se prueban antes de darse por vencido. Cinco: el mejor y
## cuatro alternativas. Probar todos seria trazar cuarenta caminos por
## persona y jornada para nada.
const INTENTOS_DE_TAJO := 5

## Actividades a las que hoy no se ha podido llegar por ningun sitio.
##
## Se limpia al cerrar la jornada, DESPUES del reparto, para que el reparto
## la vea y mande a esa gente a otra cosa; al dia siguiente se vuelve a
## intentar, porque una pasarela o una piragua pueden haber abierto el paso.
var _unreachable_today: Dictionary = {}


## Los sitios adonde se puede mandar a trabajar a alguien, por orden de
## preferencia. El primero que tenga camino se lleva la jornada.
func _work_candidates(person: Inhabitant) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var best := _best_known_spot(person)
	if best != Vector3.ZERO:
		out.append(best)

	for entry: Dictionary in (_known_spots.get(person.activity, []) as Array):
		if out.size() >= INTENTOS_DE_TAJO:
			break
		var spot: Vector3 = entry["pos"]
		if not out.has(spot):
			out.append(spot)

	# El sitio de reserva, que es el que se monto al fundar y no depende de
	# lo que la banda haya llegado a conocer
	if work_sites.has(person.activity):
		var site: Vector3 = work_sites[person.activity]
		if not out.has(site):
			out.append(site)

	# Y, en ultimo termino, prospectar: mejor salir a buscar que quedarse
	var search := _search_target(person)
	if search != Vector3.ZERO and not out.has(search):
		out.append(search)
	return out


## Parajes conocidos por actividad, ya puntuados y ordenados. Se rehace una vez
## al dia, no una vez por persona: recorrer las 4.096 celdas del campo cada vez
## que alguien salia de casa dejaba la simulacion inservible.
## Cuánto más vale un paraje bautizado que monte anónimo igual de rico.
##
## Pendiente de playtest, como todo lo de balanceo. Lo decidido es que el sitio
## que el jugador ha visto nacer y nombrar sea al que la banda va.
const PARAJE_BONUS := 1.6

var _known_spots: Dictionary = {}


## Rehace la lista de parajes conocidos. Una pasada por actividad y dia.
func _rank_known_spots() -> void:
	_known_spots.clear()
	if knowledge == null or field == null:
		return

	for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var act := activity as Subsistence.Activity
		var spots: Array[Dictionary] = []

		for z in range(field.height):
			for x in range(field.width):
				var centre := field.cell_center(x, z)
				# Solo cuenta lo que se conoce: un cotarro sin pisar no esta en
				# el mapa de la banda por muy bueno que sea
				if knowledge.familiarity_at(act, centre) < 0.35:
					continue

				var value := knowledge.believed_abundance(
					field, act, centre, GameState.season)
				if value <= 0.05:
					continue

				var distance := Vector2(centre.x - home_position.x,
					centre.z - home_position.z).length()
				# Radio de jornada: hay que ir, trabajar y volver antes de que
				# anochezca. Mas lejos que esto no da tiempo a recoger nada.
				if distance > 900.0:
					continue

				if _terrain:
					centre.y = _terrain.get_height_at(centre)

				# El término medio entre no esquilmar y no perderse el día
				# andando, dicho como una cuenta y no como un descuento
				# inventado: lo que se saca de una jornada es lo que se
				# recoge por hora POR las horas que quedan después de ir y
				# volver. Un sitio el doble de rico a hora y media no gana
				# a uno mediano a diez minutos, y uno esquilmado al lado
				# tampoco gana a uno entero un poco más allá.
				var travel := 2.0 * hours_to_walk(distance)
				var usable := clampf(1.0 - travel / HORAS_UTILES, 0.1, 1.0)
				var stock := field.stock_fraction_around(act, centre, 90.0)
				# Un paraje con nombre pesa más que monte anónimo del mismo
				# rendimiento.
				#
				# El reparto miraba sólo la rejilla de familiaridad y no los
				# parajes, así que la banda podía estar trabajando a cincuenta
				# metros de un avellanar bautizado sin ir a él: para el reparto
				# no existía, aunque para el jugador fuera el sitio que había
				# encontrado y al que le había puesto nombre. Y un sitio con
				# nombre es un sitio que la banda CONOCE de verdad: sabe qué da,
				# por dónde se entra y cuándo conviene.
				var named := 1.0
				if _paraje_at(centre) != null:
					named = PARAJE_BONUS
				spots.append({
					"pos": centre,
					"score": value * usable * stock * named,
				})

		spots.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
		# Solo interesan los mejores: con veinte hay de sobra para repartir a
		# una banda de quince
		_known_spots[activity] = spots.slice(0, mini(spots.size(), 20))


## El mejor paraje que la banda CONOCE para esa actividad y que este a tiro.
## Devuelve ZERO si no conoce ninguno: entonces toca prospectar.
## Tuerce la marcha hacia el carril de esta persona.
##
## Mismo reparto por ángulo áureo que usa `_best_known_spot` para el sitio de
## trabajo, y por lo mismo: es estable entre jornadas -cada cual va siempre por
## su lado del camino- y no repite valor en un grupo pequeño.
##
## El carril se deshace al llegar. Si el desvío siguiera vivo en los últimos
## metros nadie tocaría nunca su destino: se quedarían dando vueltas alrededor a
## dos metros y medio, que es peor que el solape.
## El paso de esta persona, en fracción del paso medio.
##
## Otro irracional distinto del que reparte el carril, y a propósito: con el
## mismo, quien comparte carril compartiría también paso y los dos apaños se
## anularían justo en el caso que vienen a arreglar.
func _lane_pace(person: Inhabitant) -> float:
	return 1.0 + (fmod(float(person.id) * 0.7548776662, 1.0) - 0.5) * 2.0 * LANE_PACE


func _lane_shift(person: Inhabitant, to_target: Vector3) -> Vector3:
	var reach := to_target.length()
	if reach < 0.5:
		return to_target
	var fade := clampf(person.position.distance_to(person.target)
		/ (arrive_radius * 3.0), 0.0, 1.0)
	if fade < 0.01:
		return to_target
	var lane := (fmod(float(person.id) * 0.618, 1.0) - 0.5) * 2.0 * LANE_SPREAD
	var side := Vector3(-to_target.z, 0.0, to_target.x) / reach
	return to_target + side * lane * fade


## Cuánto se busca la orilla alrededor de un tajo de agua, en metros.
const SHORE_SEARCH_M := 70.0

## Cuántos sitios se prueban antes de conformarse con uno sin agua al lado.
const SHORE_TRIES := 16

## Cuánto se estrecha la batida cuando se trabaja el agua.
##
## Un recolector bate setenta metros de mancha; un pescador no se aleja de la
## orilla, porque fuera de ella no hay nada que pescar. Con el radio entero, la
## mitad de los sitios que probaba caían tierra adentro.
const SHORE_FORAGE_FACTOR := 0.45

## Arrima un punto a la orilla: tierra firme con agua justo al lado.
##
## Se pesca DESDE la orilla, no desde el prado de al lado ni desde dentro del
## cauce. El reparto de tajos elige una celda de la rejilla de recursos, y esa
## celda mide decenas de metros: caía tan pronto en la ribera como en el pasto
## de detrás, y entonces la cuadrilla se plantaba a cincuenta metros del agua a
## «pescar». Aquí se busca el punto pisable más cercano que tenga agua al lado.
func _shore_near(point: Vector3) -> Vector3:
	if _terrain == null:
		return point

	var best := point
	var best_reach := INF
	for radius: float in [0.0, 8.0, 16.0, 26.0, 38.0, 52.0, SHORE_SEARCH_M]:
		for spoke in range(12):
			var angle := TAU * float(spoke) / 12.0
			var candidate := point
			if radius > 0.01:
				candidate += Vector3(cos(angle), 0.0, sin(angle)) * radius
			# Pisable: la orilla es tierra firme, no el cauce.
			if _terrain.crossing_difficulty_at(candidate) > Hydrography.FORD_WADEABLE:
				continue
			if not _water_beside(candidate):
				continue
			var reach := point.distance_to(candidate)
			if reach < best_reach:
				best_reach = reach
				best = candidate
			if radius < 0.01:
				break
		if best_reach < INF:
			break

	if best_reach == INF:
		return point
	best.y = _terrain.get_height_at(best)
	return best


## Si desde aquí se alcanza el agua con la mano: hay cauce a menos de un paso
## largo. Es lo que distingue una orilla de un prado que da al río.
func _water_beside(point: Vector3) -> bool:
	# Veinte metros y no nueve. El mismo `_terrain_lure` que decide dónde se
	# funda un abrigo mira el agua a sesenta: la máscara de río sólo pasa de
	# 0,15 sobre una banda estrecha del cauce, así que preguntando a nueve
	# metros la respuesta era «no hay agua» incluso plantado en la ribera.
	for reach: float in [12.0, 20.0]:
		for spoke in range(8):
			var angle := TAU * float(spoke) / 8.0
			if _terrain.crossing_difficulty_at(point + Vector3(
					cos(angle) * reach, 0.0, sin(angle) * reach)) > 0.15:
				return true
	return false


func _best_known_spot(person: Inhabitant) -> Vector3:
	# El trampero va primero a lo que ya tiene puesto y esta cebado. Levantar
	# una trampa cargada rinde mas por hora que cualquier otra cosa de la
	# caza, y ademas es lo que se hace: la linea se recorre.
	if person.current_speciality == Profession.Speciality.TRAMPAS:
		var cebada := _fullest_trap()
		if cebada != null:
			return cebada.position
		# Y si no hay nada que levantar, se ALARGA la linea: a un sitio de
		# caza donde todavia no haya trampa. Sin esto el trampero volvia cada
		# dia a la misma estaca vacia -el mejor sitio conocido es siempre el
		# mismo- y la linea entera se quedaba en dos trampas amontonadas en el
		# mismo claro.
		if traps.size() < trap_allowance():
			for spot: Dictionary in (_known_spots.get(
					Subsistence.Activity.CAZA, []) as Array):
				var point: Vector3 = spot["pos"]
				if _room_for_trap(point) and not _is_resting(
						Subsistence.Activity.CAZA, point):
					return point
			# Y si todo lo conocido ya tiene trampa, se sale a monte nuevo. Una
			# linea de trampas se ALARGA: quedarse dando vueltas a las mismas
			# dos estacas es lo contrario de tener una linea.
			var fresh := _search_target(person)
			if fresh != Vector3.ZERO:
				return fresh

	# Si el jugador ha señalado un paraje para este oficio, se va ahi y no se
	# discute. Es todo el sentido de poder pinchar un sitio: la banda deja de
	# elegir por su cuenta cuando tu eliges por ella.
	var picked := parajes.chosen_for(person.activity)
	if picked != null:
		return picked.position

	var spots: Array = _known_spots.get(person.activity, [])
	if spots.is_empty():
		return work_sites.get(person.activity, Vector3.ZERO)

	var best := Vector3.ZERO
	var best_score := 0.0

	for spot: Dictionary in spots:
		var centre: Vector3 = spot["pos"]

		# En barbecho no se entra: es la unica forma que tiene el jugador de
		# gestionar el agotamiento sin mover gente de oficio
		if _is_resting(person.activity, centre):
			continue

		# Ni adonde ya se ha intentado llegar hoy sin conseguirlo. Ver
		# `_give_up_on`: sin esto se vuelve a elegir el mismo cotarro detrás del
		# mismo cortado en cuanto se queda uno libre, y la jornada se va en ir y
		# volver del mismo sitio imposible.
		if _given_up_on(person, centre):
			continue

		# Descuento por lo que ya hay trabajando ahi. El radio es amplio y la
		# penalizacion fuerte a proposito: con un descuento flojo todos
		# elegian el mismo paraje y salian en fila india uno detras de otro,
		# que es justo lo contrario de como se reparte una cuadrilla.
		var crowd := 0.0
		for other: Inhabitant in people:
			if other == person or other.activity != person.activity:
				continue
			if other.state == Inhabitant.State.DURMIENDO \
					or other.state == Inhabitant.State.OCIOSO:
				continue
			if other.target.distance_to(centre) < 260.0:
				crowd += 1.0

		# Y un TOPE, no solo un descuento. Un descuento que solo penaliza deja
		# que todo el mundo termine en el mismo sitio si es el unico bueno que
		# se conoce: se va notando cada vez menos atractivo, pero nunca deja
		# de ser el mejor numero de la lista. Pasada una partida de trabajo
		# -Subsistence.PEOPLE_PER_PARTY, la misma vara que ya mide cuanta
		# gente forma una cuadrilla- el sitio se descarta del todo para
		# ESTA persona: que se reparta con el siguiente mejor conocido, no
		# que seis cuadrillas esquilmen la misma mancha de golpe.
		if crowd >= Subsistence.PEOPLE_PER_PARTY:
			continue

		var score: float = float(spot["score"]) / (1.0 + crowd * 1.8)

		# Y el cazador va donde esta SU pieza.
		#
		# El sitio se elegia solo por abundancia de caza, que es un numero que
		# no distingue un uro de una liebre. Medido en el sitio 56: un batidor
		# de caza mayor trabajando un cotarro de «liebre, urogallo y corzo»
		# cobraba 2,6 raciones de jornada perfecta contra las 14,2 de un
		# recolector, o sea que salir a por ciervo era el peor oficio de la
		# banda. No era que la caza rindiera poco: era que se cazaba en el
		# sitio equivocado.
		score *= _quarry_bonus(person, centre)

		if score > best_score:
			best_score = score
			best = centre

	if best == Vector3.ZERO:
		return best

	# Y dentro del paraje, cada uno a su trozo. Un avellanar no es un punto:
	# son decenas de metros, y dos personas recogiendo la misma mata es una
	# tonteria. El reparto es por identidad, asi que es estable entre jornadas
	# y cada cual vuelve a su rincon.
	var spread := 55.0
	var angle := TAU * (float(person.id) * 0.618)
	best += Vector3(cos(angle), 0.0, sin(angle)) * spread \
		* (0.4 + fmod(float(person.id) * 0.37, 0.6))
	if _terrain:
		best.x = clampf(best.x, 10.0, float(_terrain.terrain_size.x) - 10.0)
		best.z = clampf(best.z, 10.0, float(_terrain.terrain_size.y) - 10.0)
		best.y = _terrain.get_height_at(best)
	return best


## Adonde salir a buscar cuando no se conoce ningun paraje.
##
## Se abren en abanico, cada uno por una direccion que no lleve otro. Es lo
## mismo que hacen los exploradores, pero a radio de jornada y buscando un
## recurso concreto en vez de mapa.
func _search_target(person: Inhabitant) -> Vector3:
	if _terrain == null:
		return home_position

	var taken: Array[Vector3] = []
	for other: Inhabitant in people:
		if other != person and other.state == Inhabitant.State.YENDO:
			taken.append(other.target)

	var best := home_position
	var best_score := -1.0

	for spoke in range(12):
		# El desfase por persona evita que todos prueben las mismas direcciones
		var angle := TAU * (float(spoke) / 12.0 + float(person.id) * 0.083)
		for distance: float in [200.0, 430.0, 700.0]:
			var candidate := home_position \
				+ Vector3(cos(angle), 0.0, sin(angle)) * distance
			if candidate.x < 20.0 or candidate.z < 20.0 \
					or candidate.x > float(_terrain.terrain_size.x) - 20.0 \
					or candidate.z > float(_terrain.terrain_size.y) - 20.0:
				continue
			candidate.y = _terrain.get_height_at(candidate)

			if not Traversal.is_passable(_terrain.get_slope_at(candidate),
					_terrain.crossing_difficulty_at(candidate), has_boat, has_bridge):
				continue

			# Lo que promete el terreno, aunque la banda no lo sepa todavia:
			# el recolector no adivina, pero el monte tiene lo que tiene
			var promise := 0.0
			if field:
				promise = field.seasonal_abundance_at(
					person.activity, candidate, GameState.season)

			# Se premia lo que esta sin batir y se penaliza la distancia
			var unknown := 1.0
			if knowledge:
				unknown = 1.0 - knowledge.familiarity_at(person.activity, candidate)

			var score := (promise * 0.6 + unknown * 0.4) / (1.0 + distance / 700.0)
			for other_target: Vector3 in taken:
				if candidate.distance_to(other_target) < 260.0:
					score *= 0.35

			if score > best_score:
				best_score = score
				best = candidate

	return best


## Lo que se saca de un rato de trabajo, ya en materiales concretos.
## Cuenta una rotura, y con mas enfasis si era LA ULTIMA.
##
## Quedarse sin la ultima azagaya a mitad de temporada de caza es el momento
## en que el jugador entiende para que servia el taller. Una linea en una
## lista no dice eso; una frase con el nombre de quien la llevaba, si.
func _note_breakage(person: Inhabitant, kind: Tool.Kind) -> void:
	if toolkit.broke_last_use.is_empty():
		return

	var left := toolkit.count(kind)
	var doing := Subsistence.activity_name(person.activity).to_lower()
	if left <= 0:
		_note(Chronicle.Kind.TALLER,
			"A %s se le partio la ULTIMA %s, %s. No queda ninguna."
				% [person.given_name, toolkit.broke_last_use.to_lower(), doing], 2)
	else:
		_note(Chronicle.Kind.TALLER,
			"A %s se le partio %s %s. Quedan %d."
				% [person.given_name, toolkit.broke_last_use.to_lower(), doing, left], 0)


## Que herramienta pide cada actividad, o -1 si ninguna.
##
## El marisqueo no lleva nada, y es a proposito: es el trabajo al que se puede
## echar mano cuando todo lo demas se ha roto. Por eso sostiene el invierno.
func activity_tool(activity: Subsistence.Activity) -> int:
	match activity:
		Subsistence.Activity.CAZA: return Tool.Kind.AZAGAYA
		Subsistence.Activity.PESCA: return Tool.Kind.ARPON
		Subsistence.Activity.RECOLECCION: return Tool.Kind.CESTO
		_: return -1


## Cuanta gente esta en una actividad. Es lo que decide cuantas piezas hacen
## falta para ir a pleno rendimiento: una por mano.
func workers_in(activity: Subsistence.Activity) -> int:
	var total := 0
	for person: Inhabitant in people:
		if person.has_task and person.activity == activity:
			total += 1
	return maxi(total, 1)


## Cuanta gente esta HOY en esta especialidad de caza en concreto -no toda
## la actividad CAZA, que mezcla trampas, menor y mayor-. Es lo que decide
## si una cuadrilla de caza mayor es de verdad una cuadrilla: ver
## [Hunting.crew_factor].
func hunters_in(speciality: Profession.Speciality) -> int:
	var total := 0
	for person: Inhabitant in people:
		if person.has_task and person.current_speciality == speciality:
			total += 1
	return maxi(total, 1)


## Pedidos permanentes de herramienta que ha puesto el jugador.
##
## Vacio quiere decir «lo que haga falta», que es lo razonable por defecto.
var tool_orders: Dictionary = {}


## Fija -o quita, con 0- un pedido permanente de una pieza.
##
## Igual que el tope de material del almacen: sin pedido, el taller decide
## solo cuanto hace falta de cada cosa; con uno puesto, el pedido manda.
func set_tool_order(kind: Tool.Kind, value: int) -> void:
	if value <= 0:
		tool_orders.erase(kind)
	else:
		tool_orders[kind] = value


## Si la banda sabe hacer esta pieza.
##
## Sin arbol de tecnicas -las pruebas montan simulaciones a medias- se sabe
## hacer todo, que es como se comportaba antes de que existiera esta puerta.
func knows_tool(kind_value: Tool.Kind) -> bool:
	var tech := Tool.tech_of(kind_value)
	if tech < 0 or techs == null:
		return true
	return techs.has(tech as TechTree.Tech)


## Cuantas piezas de cada tipo le hacen falta a la banda ahora mismo.
##
## Sale de quien esta trabajando en que, no de una tabla fija: si el jugador
## pone a cinco a pescar, la demanda de arpones sube sola y el taller lo nota
## sin que nadie tenga que pedirlo.
func tool_demand() -> Dictionary:
	var demand := tool_natural_demand()
	# El pedido permanente del jugador manda por encima de lo calculado
	for kind: int in tool_orders:
		demand[kind] = int(tool_orders[kind])
	return demand


## Cuantas piezas pide EL TRABAJO, sin contar lo que haya pedido el jugador.
##
## Existe aparte porque el consumo de materia prima NO puede depender de lo
## que el jugador quiera tener guardado: que quieras treinta huesos en el
## abrigo no hace que la banda gaste mas huesos. Lo que se gasta sale del uso
## -cuanta gente trabaja y cuanto aguanta cada pieza- y punto.
func tool_natural_demand() -> Dictionary:
	var demand := {
		Tool.Kind.LASCA: maxi(people.size() / 2, 2),
		Tool.Kind.AZAGAYA: workers_in(Subsistence.Activity.CAZA),
		Tool.Kind.CESTO: workers_in(Subsistence.Activity.RECOLECCION),
		Tool.Kind.RAEDERA: 2,
		Tool.Kind.BURIL: 2,
		Tool.Kind.AGUJA: 2,
		Tool.Kind.PUNZON: 1,
		Tool.Kind.CUERDA: 3,
		Tool.Kind.ODRE: 2,
		Tool.Kind.PUNTA: 2,
		# El aparejo de pesca NO va con una cifra fija: va con la forma de
		# pescar que la banda sepa. Pedir arpones desde el primer dia era
		# pedirle al taller que gastara asta en algo que nadie sabe usar
		# todavia, y pedir de todo a la vez seria peor: una red se lleva la
		# fibra de una estacion entera.
		Tool.Kind.ARPON: 0,
		Tool.Kind.NASA: 0,
		Tool.Kind.ANZUELO: 0,
		Tool.Kind.RED: 0,
	}
	var fishers := workers_in(Subsistence.Activity.PESCA)
	if fishers > 0:
		var wanted := _fishing_tool_to_stock()
		if wanted >= 0:
			demand[wanted] = maxi(fishers, 1)
	return demand


## Que aparejo hay que tener hecho: el de la mejor manera de pescar que la
## banda SEPA, tenga hoy la pieza o no.
##
## Va aparte de `fishing_method` a proposito. Aquella dice con que se pesca
## HOY -y si se ha roto el ultimo arpon dice "a mano"-; esta dice que hay que
## reponer, que es el arpon precisamente porque se ha roto.
func _fishing_tool_to_stock() -> int:
	var top := -1
	for i in range(Fishing.ORDER.size() - 1, -1, -1):
		var method: Fishing.Method = Fishing.ORDER[i]
		var tech := Fishing.tech_of(method)
		if tech >= 0 and (techs == null or not techs.has(tech as TechTree.Tech)):
			continue
		var tool := Fishing.tool_of(method)
		if tool < 0:
			# La pesquera no es una pieza: es una obra. A partir de aqui hacia
			# abajo no hay nada que encargarle al taller.
			break
		if top < 0:
			top = tool
		# Se encarga lo mejor que se pueda HACER, no solo lo mejor que se
		# sepa. Sin esto, el dia que la banda aprende el arpon dejaba de
		# trenzar redes -solo se pedia el escalon de arriba- y si no habia
		# asta en el abrigo se quedaba sin lo uno y sin lo otro, pescando a
		# mano con dos tecnicas de pesca dominadas.
		if toolkit.count(tool as Tool.Kind) > 0 or _can_pay_for(tool as Tool.Kind):
			return tool
	return top


## Cuantas piezas de un tipo se rompen al mes con el trabajo que hay puesto.
##
## Es el GASTO de verdad: sale de cuantas estan en uso, cuanto se desgastan al
## dia y cuanto aguantan. No lo toca el jugador.
func tools_broken_per_month(kind: Tool.Kind) -> float:
	var in_use := float(int(tool_natural_demand().get(kind, 0)))
	if in_use <= 0.0:
		return 0.0
	var life := Tool.durability_of(kind)
	var per_day := Tool.wear_per_day(kind) * TYPICAL_YIELD_FRACTION
	return in_use * per_day * float(CONSUMO_DIAS) / maxf(life, 1.0)


## Lo que la banda ha traído HOY, por material, y el registro de los últimos
## días. La columna PRODUCE del almacén sale de aquí.
##
## Es producción MEDIDA, no una estimación a partir de las tablas: entre lo
## nominal y lo que de verdad entra hay cinco penalizaciones y un día que se
## va casi entero en andar -ver [HARVEST_SCALE]-, así que una estimación
## habría dicho diez veces más de lo que el jugador ve llegar al abrigo.
var produced_today: Dictionary = {}

## Lo producido cada uno de los últimos días, el más reciente al final.
##
## Era una media exponencial POR DÍA, y la columna de al lado -GASTA- va por
## [CONSUMO_DIAS], o sea por mes: las dos cifras que el jugador lee juntas
## estaban en escalas distintas por un factor de treinta, y la comparación que
## justifica la columna -entra tanto, se va tanto- no se podía hacer. Ahora se
## guardan los días de verdad y se suman.
var produced_days: Array[Dictionary] = []


## Apunta lo que acaba de entrar en el almacén.
func note_production(kind: Materia.Kind, units: float) -> void:
	if units <= 0.0:
		return
	produced_today[int(kind)] = float(produced_today.get(int(kind), 0.0)) + units


## Lo que produce la banda de esto en el mismo periodo que se mide el gasto,
## o sea en [CONSUMO_DIAS].
##
## Con menos días jugados que el periodo se proyecta a mes completo -si no, un
## día tres compararía tres jornadas de producción contra treinta de gasto y la
## banda parecería arruinada siempre-. En cuanto hay mes entero es la suma a
## secas, sin nada encima.
func production_of(kind: Materia.Kind) -> float:
	return _produced_in_period(int(kind))


## Y lo mismo para el taller. Las piezas van con clave NEGATIVA para no
## chocar con los materiales, igual que en el libro de trabajo de cada cual.
func note_tool_made(kind: Tool.Kind) -> void:
	var key := -1 - int(kind)
	produced_today[key] = float(produced_today.get(key, 0.0)) + 1.0


func tool_production_of(kind: Tool.Kind) -> float:
	return _produced_in_period(-1 - int(kind))


## La suma del periodo para una clave, materiales y piezas por igual.
func _produced_in_period(key: int) -> float:
	var total := 0.0
	for a_day: Dictionary in produced_days:
		total += float(a_day.get(key, 0.0))
	# El día en curso cuenta: sin él, la cifra no se mueve hasta mañana y el
	# jugador que acaba de mandar a media banda a por leña no ve nada.
	total += float(produced_today.get(key, 0.0))
	var days := produced_days.size() + 1
	if days >= CONSUMO_DIAS:
		return total
	return total * float(CONSUMO_DIAS) / float(days)


## Cierra el día de producción y lo mete en el registro.
func _roll_production() -> void:
	produced_days.append(produced_today.duplicate())
	while produced_days.size() > CONSUMO_DIAS:
		produced_days.remove_at(0)
	produced_today = {}

## Materiales que NO están en todas partes: solo salen del paraje que los
## tiene. Son los que dan nombre a un sitio por sí solos -una veta de
## sílex, una de ocre, un desmogadero- frente a la piedra corriente, que se
## coge de cualquier canchal.
const LOCAL_ONLY := [Materia.Kind.SILEX, Materia.Kind.OCRE, Materia.Kind.ASTA]

## Lo que solo se consigue cazando o pescando.
##
## Un recolector sale a por avellanas, raiz y leña: no cobra piezas ni cala
## aparejo. La caracola y el huevo NO estan aqui a proposito -se cogen a mano,
## agachandose, que es recoleccion de manual- y la piel y el hueso tampoco: se
## encuentra un animal muerto sin haberlo cazado.
const SOLO_DE_CAZA_O_PESCA := [Materia.Kind.CARNE, Materia.Kind.CARNE_SECA,
	Materia.Kind.PESCADO, Materia.Kind.PESCADO_SECO, Materia.Kind.MARISCO]


## Si el sitio donde está esta persona tiene de verdad este material.
##
## Se pregunta al paraje que cubre el punto: sus contenidos salen del campo
## de recursos y de la posición, o sea que son lo que hay ahí de verdad, se
## haya mirado ya o no -encontrarlo es otra cosa, y de eso va `sabido`.
func _spot_has(kind: Materia.Kind, point: Vector3) -> bool:
	var here := _paraje_at(point)
	if here == null:
		return false
	return here.contents.has(int(kind))


## El mando de calibración de la cosecha, y el único.
##
## Las cifras de [SPECIALITY_YIELDS] son de jornada entera y perfecta, y
## sobre ellas caen CINCO penalizaciones que se multiplican: pericia (0,58 al
## empezar), conocimiento del sitio (0,50 si no se conoce), estación (0,75 en
## primavera, 0,25 en invierno), utillaje (0,55 sin cestos) y la parte del
## día que de verdad se pasa recogiendo y no andando (~0,30). El producto es
## un 4 % de lo nominal, y con eso un recolector traía 0,67 raciones al día:
## menos de lo que come él solo, o sea una banda que no puede existir.
##
## Va aquí, en un sitio único y con nombre, en vez de repartido por las tablas
## de rendimiento: así se toca UN número para mover la dificultad y las
## proporciones entre oficios se quedan como estaban.
##
## De 5,5 a 26 al pasar la comida a CALORÍAS. Es un salto grande y hay tres
## razones sumadas, ninguna arbitraria:
##
##   - La ración dejó de ser «lo que come alguien en un día» y pasó a ser media
##     jornada -ver [Materia.KCAL_RACION]-: la banda necesita 1,9 veces más.
##   - La composición real da MENOS de lo que decía el `alimenta` puesto a
##     mano, y sobre todo en lo que más recoge un forrajeador: la baya pasa de
##     0,45 a 0,16 raciones por unidad, la seta de 0,30 a 0,06 y el caracol de
##     0,60 a 0,28. Una jornada de zarzas de verdad no da de comer a nadie.
##   - Y la banda arranca SIN CESTOS, que era media jornada de carga.
##
## El número está medido, no tanteado: con 13,2 -sólo el factor aritmético- la
## despensa aguantaba dos jornadas y la banda entraba en espiral -la
## producción por recolector se hundía de 3,0 unidades diarias a 0,59, que no
## es la conversión sino el hambre comiéndose la eficacia-. Con 33 sobraba
## comida (14,5 días); con 26 quedan 11,5, que es donde estaba antes de todo
## esto (9,3) con un poco de margen.
const HARVEST_SCALE := 26.0

## Hasta donde llega el brazo desde donde se planta uno a trabajar, en metros.
##
## Poco mas de una celda del campo de recursos: lo justo para que quien pesca
## desde la orilla alcance el agua y quien recoge alcance la mata de al lado,
## sin que un cotarro rinda desde el otro lado del valle.
const ALCANCE_DEL_TAJO := 80.0


func _harvest(person: Inhabitant, hours: float) -> void:
	# Fraccion de la jornada trabajada en este tick
	var fraction := hours / HORAS_UTILES
	if fraction <= 0.0:
		return

	# Destreza, estado y conocimiento del paraje
	var skill := person.effectiveness() * _knowledge_factor(person)

	# La estacion, que hasta ahora no entraba en la cosecha: sin esto el otono
	# no se notaba y toda la estacionalidad era decorativa
	var season := ResourceField.seasonal_factor(person.activity, GameState.season)

	# El agotamiento del paraje. Devuelve lo que quedaba, de 0 a 1, asi que el
	# segundo recolector del dia saca menos que el primero.
	# Cuanto se lleva del paraje. La cifra importa mucho mas de lo que parece:
	# con 0,05 por jornada y celdas de capacidad 0,35, tres recolectores
	# dejaban el avellanar a CERO en dia y medio, y a partir de ahi la cosecha
	# se multiplicaba por cero. La banda no comia y no habia forma de verlo
	# desde fuera.
	#
	# Con 0,008 un paraje bueno aguanta unas cuarenta jornadas-persona antes de
	# notarse, que es lo que da tiempo a que el jugador vea el rendimiento
	# caer y reaccione.
	# De la mejor celda AL ALCANCE, no de la de debajo de los pies. Se pesca
	# desde la ribera -una celda de tierra- y el pescado esta en la celda de
	# agua de al lado: mirando solo la de debajo, un pescador volvia de vacio
	# todos los dias en un rio lleno de peces. Vale igual para lo demas:
	# nadie trabaja de pie sobre un punto, se trabaja un trecho.
	# La celda que se esta trabajando: la mas rica al alcance. Se MIRA aqui y se
	# le resta abajo lo que de verdad se haya cogido de ella.
	var left := 1.0
	var worked_cell := -1
	if field:
		worked_cell = field.best_cell(person.activity, person.position,
			ALCANCE_DEL_TAJO)
		left = field.stock_of_cell(person.activity, worked_cell)

	# El filo disponible. Un cazador sin azagaya sigue trayendo algo -trampa,
	# carrona y caza menor-, pero poco; quien recolecta sin cesto trae lo que
	# le cabe en los brazos. Y usar la herramienta la gasta, que es de donde
	# sale la demanda del taller sin tener que inventarse ninguna cuota.
	var tool_factor := 1.0
	var tool_kind := _tool_for(person)
	if tool_kind >= 0:
		var kind_value := tool_kind as Tool.Kind
		tool_factor = toolkit.efficiency(kind_value, workers_in(person.activity))
		toolkit.use(kind_value, fraction * Tool.wear_per_day(kind_value))
		_note_breakage(person, kind_value)

	# El despiece se lleva por delante mas filo que ninguna otra cosa: una res
	# grande se come varias lascas. Va aparte de la azagaya porque son dos
	# trabajos distintos, y es lo que da sentido al tallador.
	if person.activity == Subsistence.Activity.CAZA:
		toolkit.use(Tool.Kind.LASCA,
			fraction * Tool.wear_per_day(Tool.Kind.LASCA))
		_note_breakage(person, Tool.Kind.LASCA)

	# La cuadrilla. Sólo pinta en caza mayor -ver [Hunting.crew_factor]-, y
	# ahi es donde manda de verdad: un solo batidor contra un uro trae casi
	# nada, cuatro traen la pieza entera.
	var crew := 1.0
	if person.activity == Subsistence.Activity.CAZA:
		var speciality := person.current_speciality as Profession.Speciality
		crew = Hunting.crew_factor(speciality, hunters_in(speciality))
		_check_hunting_risk(person, speciality, fraction)

	var multiplier := fraction * skill * season * left * tool_factor * crew 		* weather.work_factor() * HARVEST_SCALE
	if multiplier <= 0.0:
		return

	var yields := _yields_for(person)

	# El cebo del sedal se gasta. Es lo que hace que el anzuelo no sea una
	# mejora gratis: hay que traer caracol, y el dia que no queda `Fishing`
	# baja el aparejo un escalon por su cuenta.
	if person.current_speciality == Profession.Speciality.ORILLA:
		var method := fishing_method() as Fishing.Method
		var bait := Fishing.bait_at_hand(method, store)
		if bait >= 0:
			store.take(bait as Materia.Kind,
				fraction * Fishing.bait_per_day(method))

	var food := 0.0
	# Lo que de verdad sale del sitio en este tick, para restarselo despues.
	var taken := 0.0
	for kind: int in yields:
		var per_day: float = yields[kind]
		var units := per_day * multiplier
		if units <= 0.0:
			continue

		# Lo que no está en TODAS partes, solo sale donde está. El sílex, el
		# ocre y la cuerna caída no se sacan de cualquier pedrera: se sacan
		# de la veta o del desmogadero que los tiene, y hasta ahora salían
		# de picar piedra en cualquier sitio -en una comarca donde el sílex
		# escasea, la banda tenía sílex desde el primer día sin haberlo
		# encontrado nunca.
		if LOCAL_ONLY.has(kind) and not _spot_has(kind as Materia.Kind, person.position):
			continue

		# Y lo que no es de esta epoca del año no se coge, aqui ni en ningun
		# sitio. La tabla de temporadas -[Parajes.SEASONAL_EXTRAS]- decidia
		# que salia en la ficha de un paraje, pero no que se podia recoger:
		# la miel y la bellota figuraban como de verano y otoño y aun asi
		# entraban en el zurron en marzo, asi que el jugador las veia en el
		# almacen sin verlas en ningun paraje. Una de las dos cosas sobraba,
		# y la que sobra es coger en marzo lo que no hay en marzo.
		if not Parajes.in_season(kind as Materia.Kind, GameState.season):
			continue

		# Tope puesto por el jugador: si ya hay bastante de esto, se deja en el
		# monte. Cuenta lo guardado mas lo que ya lleva encima, para que no se
		# pase de largo en una sola jornada.
		if limits.has(kind):
			var cap: float = limits[kind]
			var have: float = store.amount(kind as Materia.Kind) \
				+ float(person.load.get(kind, 0.0))
			if have >= cap:
				continue

		# No se carga mas de lo que se puede llevar. Es la razon mecanica de
		# que los recipientes importen: sin cesto se llena antes y la jornada
		# se acaba a media manana.
		var room_kg := person.carry_limit_kg() - person.load_kg()
		if room_kg <= 0.0:
			break
		var fits := minf(units, room_kg / maxf(Materia.kg_per_unit(kind as Materia.Kind), 0.001))
		if fits <= 0.0:
			continue

		# EL RECOLECTOR NO CAZA NI PESCA. En las tablas ya no habia carne ni
		# pescado bajo recoleccion, pero eso era una propiedad de los DATOS:
		# cualquier extra o cualquier retoque de temporada podia colar una
		# pieza en el zurron de quien salio a por avellanas. Aqui es una regla.
		if person.activity == Subsistence.Activity.RECOLECCION \
			and SOLO_DE_CAZA_O_PESCA.has(kind):
			continue

		person.add_load(kind as Materia.Kind, fits)
		person.log_gain(person.current_task(), kind, fits)
		taken += fits
		if Materia.is_food(kind as Materia.Kind):
			food += fits * Materia.nutrition(kind as Materia.Kind)

	person.carrying += food

	# Y el sitio se queda sin lo que se han llevado. Aqui, al final y con la
	# cuenta hecha, no arriba con un numero fijo por jornada: es lo que hace que
	# recoger y vaciar sean la misma cosa y no dos. Ver [DEPLETION_PER_UNIT].
	if field and taken > 0.0:
		field.take_from_cell(person.activity, worked_cell,
			taken * DEPLETION_PER_UNIT)


## Piezas que hace en una JORNADA COMPLETA cada especialidad del taller.
##
## Son cifras de jornada entera y perfecta, o sea que lo que sale de verdad es
## bastante menos. Una azagaya lleva dias: hay que ranurar el asta, sacar la
## punta, preparar el astil y ligarlo con tendon y resina.
## Hasta donde trabaja el taller antes de parar: la cobertura justa mas una
## reserva. Sin tope, un artesano acumula cientos de piezas inutiles.
const RESERVA_UTILLAJE := 1.3

const CRAFT_PER_DAY := {
	Profession.Speciality.TALLA: 3.0,
	Profession.Speciality.ASTA: 0.6,
	Profession.Speciality.PELETERIA: 0.5,
	Profession.Speciality.CORDELERIA: 1.2,
}

## Que fabrica cada especialidad.
const SPECIALITY_MAKES := {
	Profession.Speciality.TALLA: [Tool.Kind.LASCA, Tool.Kind.RAEDERA,
		Tool.Kind.BURIL, Tool.Kind.PUNTA],
	Profession.Speciality.ASTA: [Tool.Kind.AZAGAYA, Tool.Kind.ARPON,
		Tool.Kind.AGUJA, Tool.Kind.PUNZON, Tool.Kind.ANZUELO],
	Profession.Speciality.PELETERIA: [Tool.Kind.ODRE],
	Profession.Speciality.CORDELERIA: [Tool.Kind.CUERDA, Tool.Kind.CESTO,
		Tool.Kind.NASA, Tool.Kind.RED],
}


## Anota algo en el diario, con la fecha puesta.
##
## Todo lo que se cuenta sale de cosas que la simulacion YA detectaba y se
## limitaba a reflejar en un numero. Aqui solo se redacta.
func _note(kind: Chronicle.Kind, text: String, weight: int = 1) -> void:
	if chronicle == null:
		return
	chronicle.record(day, GameState.season as int, GameState.year,
		kind, text, weight)


## Sobre cuantos dias se mide lo que la banda GASTA de cada material.
##
## Un mes: es el horizonte con el que se piensa de verdad -«esto me llega al
## invierno o no me llega»- y es bastante mas util que un dia, que para casi
## todo sale cero.
const CONSUMO_DIAS := 30


## Lo que la banda CONSUME de un material en un mes.
##
## Estaba mal planteado: «falta» y «meta» salian de lo mismo, asi que subir la
## meta subia la falta y el numero no informaba de nada. Son dos cosas
## distintas y ahora lo son de verdad:
##
##   FALTA · lo que se va a gastar. Sale del uso: lo que se come, lo que se
##           rompe y lo que piden las obras. No lo decide el jugador.
##   META  · cuanto quiere el jugador tener guardado. Lo decide el, y es lo
##           que hace que la banda deje de traer mas.
func material_needed(kind: Materia.Kind) -> float:
	var total := 0.0

	# Lo que se COME, si alimenta. Es el gasto mas grande con diferencia.
	if Materia.is_food(kind):
		var mouths := 0.0
		for person: Inhabitant in people:
			mouths += person.daily_food()
		# Repartido entre los alimentos que la banda tiene: nadie come solo
		# avellana treinta dias seguidos
		var larder := 0
		for other: int in Materia.Kind.values():
			if Materia.is_food(other as Materia.Kind) 					and store.amount(other as Materia.Kind) > 0.5:
				larder += 1
		var share := 1.0 / maxf(float(larder), 1.0)
		total += mouths * float(CONSUMO_DIAS) * share 			/ maxf(Materia.nutrition(kind), 0.001)

	# Lo que se ROMPE al mes, por su receta. Se usa la demanda NATURAL: si
	# usara la del jugador, subir la meta de azagayas subiria el asta que
	# «gasta» la banda, y querer tener mas guardado no hace que se gaste mas.
	for tool_kind: int in tool_natural_demand():
		var recipe := Tool.recipe(tool_kind as Tool.Kind)
		var per_material := float(recipe.get(kind, 0.0))
		if per_material <= 0.0:
			continue
		total += tools_broken_per_month(tool_kind as Tool.Kind) * per_material

	# Y lo que pide la obra en cola, que es un gasto de una vez
	if camp_queue >= 0 and not _camp_paid:
		var project: Dictionary = CampProjects.materials(camp_queue as CampProjects.Kind)
		total += float(project.get(kind, 0.0))

	return total


## Cuanto tiene la banda de un tipo respecto a lo que le hace falta, de 0 a 1.
## No se recorta a 1: el taller necesita distinguir «justo» de «de sobra»
## para saber cuando parar. Quien si recorta es `Toolkit.efficiency`, porque
## ahi acumular de mas no debe dar rendimiento de mas.
func tool_coverage(kind: Tool.Kind) -> float:
	var needed: float = float(tool_demand().get(kind, 1))
	if needed <= 0.0:
		return 1.0
	return float(toolkit.count(kind)) / needed


## Que pieza toca hacer dentro de una especialidad: la que mas falte.
func _next_piece(speciality: Profession.Speciality) -> int:
	var options: Array = SPECIALITY_MAKES.get(speciality, [])
	if options.is_empty():
		return -1
	var chosen := -1
	var worst := INF
	for kind: int in options:
		var kind_value := kind as Tool.Kind
		# Lo que ya esta cubierto de sobra no se hace: nadie talla ciento
		# veinte lascas que no va a usar
		# Lo que nadie pide no se hace. `tool_coverage` devuelve 1.0 cuando la
		# demanda es cero -no hay con que dividir- y 1.0 esta por debajo de la
		# reserva, asi que sin esta linea el taller se ponia a trenzar redes
		# que la banda ni sabe calar todavia.
		if float(tool_demand().get(kind_value, 0)) <= 0.0:
			continue
		# Y lo que todavia no se sabe hacer, no se hace. Ver `Tool.tech_of`.
		if not knows_tool(kind_value):
			continue
		var coverage := tool_coverage(kind_value)
		if coverage >= RESERVA_UTILLAJE:
			continue
		# Sin la herramienta previa no es que se tarde mas: es que no se hace
		var prerequisite := Tool.needs_tool(kind_value)
		if prerequisite >= 0 and toolkit.count(prerequisite as Tool.Kind) <= 0:
			continue
		# Y sin materia prima en el abrigo, tampoco. Antes esto no se miraba
		# aqui: se elegia la pieza MENOS cubierta aunque no hubiera con que
		# hacerla, y el artesano se plantaba delante de ella sin probar con
		# otra que si podia sacar.
		if not _can_pay_for(kind_value):
			continue
		if coverage < worst:
			worst = coverage
			chosen = kind
	return chosen


## Si el abrigo tiene la materia prima que pide una pieza.
##
## Mismo criterio que usa `_craft` al cobrarla, incluida la sustitucion de
## cuarcita por silex cuando lo hay: si aqui dijera que si y alli que no, el
## artesano se plantaria en el banco sin sacar nada.
func _can_pay_for(kind: Tool.Kind) -> bool:
	var recipe := Tool.recipe(kind)
	for material: int in recipe:
		var wanted: float = float(recipe[material])
		if material == Materia.Kind.PIEDRA \
				and store.amount(Materia.Kind.SILEX) >= wanted:
			continue
		if store.amount(material as Materia.Kind) < wanted:
			return false
	return true


## Si esta especialidad de taller tiene algo que hacer hoy. Lo que no es
## taller no le afecta: devuelve que si y sigue su camino.
func _speciality_can_work(speciality: Profession.Speciality) -> bool:
	# El trampero tampoco sale con las manos vacias.
	#
	# Armar una trampa cuesta fibra y leña -ver `Trap.materials`- y eso se
	# comprobaba YA EN EL MONTE: se le mandaba a la linea, andaba su kilometro,
	# llegaba, no habia con que armar nada y apuntaba «sin material para armar
	# mas trampas». La jornada entera para escribir esa linea.
	#
	# Con trampas ya puestas si sale, con material o sin el: ir a levantarlas es
	# la mitad del oficio y no cuesta nada mas que el paseo.
	if speciality == Profession.Speciality.TRAMPAS:
		return not traps.is_empty() or _can_afford_a_trap()
	if not SPECIALITY_MAKES.has(speciality):
		return true
	return _next_piece(speciality) >= 0


## Si en el abrigo hay con que armar alguna de las trampas que se saben hacer.
func _can_afford_a_trap() -> bool:
	for kind: int in known_traps():
		if _can_afford(Trap.materials(kind as Trap.Kind)):
			return true
	return false


## Trabajo de taller. Se llama en lugar de la cosecha para quien esta en
## manufactura: no trae nada del monte, gasta lo que hay en el abrigo y saca
## piezas.
##
## Lo que no se puede hacer se queda sin hacer y punto, sin penalizacion
## escondida. La falta se ve en el panel, que es donde tiene que verse.
## Qué está haciendo esta persona ahora mismo, para poder ENSEÑARLO encima de
## su cabeza. Vacío si no está en faena.
##
## Devuelve siempre lo mismo —glifo, color, avance y rótulo— venga de donde
## venga, porque quien mira la pantalla hace una sola pregunta: qué hace ése y
## cuánto le falta. Que el taller lleve la cuenta en piezas, el trampero en
## jornadas de armar y el pescador en lo que lleva en el cesto es cosa de la
## simulación, no del jugador.
func doing_now(person: Inhabitant) -> Dictionary:
	var crafting := crafting_now(person)
	if not crafting.is_empty():
		var look: Array = MateriaIcon.TOOL_LOOK[int(crafting["tool"]) as Tool.Kind]
		return {
			"glyph": look[0], "tint": look[1],
			"progress": float(crafting["progress"]),
			"label": Tool.kind_name(int(crafting["tool"]) as Tool.Kind),
		}

	if person.state != Inhabitant.State.TRABAJANDO:
		return {}

	# El trampero armando: la cuenta es la misma `craft_progress`, pero de una
	# trampa y no de una pieza de taller.
	if person.current_speciality == Profession.Speciality.TRAMPAS 			and person.craft_progress > 0.0:
		return {
			"glyph": MateriaIcon.Glyph.HEBRAS, "tint": Color(0.62, 0.68, 0.34),
			"progress": clampf(person.craft_progress, 0.0, 1.0),
			"label": "trampa",
		}

	# Y todo el que trabaja el monte o el agua: lo que lleva en el cesto. Es la
	# cuenta que de verdad gobierna su jornada —se vuelve cuando no cabe más—,
	# así que la barra dice además cuándo va a volver.
	var material := speciality_output(
		person.current_speciality as Profession.Speciality)
	if material < 0:
		return {}
	var look: Array = MateriaIcon.LOOK.get(material,
		[MateriaIcon.Glyph.CANTO, Color(0.6, 0.6, 0.6)])
	return {
		"glyph": look[0], "tint": look[1],
		"progress": person.load_fraction(),
		"label": Materia.material_name(material as Materia.Kind),
	}


## Qué pieza está haciendo alguien ahora mismo, y cuánto lleva de ella.
##
## Devuelve vacío si no está fabricando. Existe porque `craft_progress` llevaba
## desde siempre en `Inhabitant` sin que lo leyera nadie fuera de esta clase: en
## pantalla no había forma de saber qué estaba tallando alguien ni cuánto le
## faltaba, así que un artesano trabajando y un artesano parado se veían igual.
## Ver [CraftMarkers].
func crafting_now(person: Inhabitant) -> Dictionary:
	# La misma puerta que abre `_craft`, y no una parecida. Se mira el oficio y
	# la hora, no el estado: la chapa tiene que encenderse en cuanto hay pieza
	# en marcha, y el estado ya lo comprueba quien llama si le hace falta.
	if person.job != Profession.Job.MANUFACTURA:
		return {}
	if hour < HORA_SALIDA or hour >= HORA_REGRESO:
		return {}
	var kind := _next_piece(person.current_speciality as Profession.Speciality)
	if kind < 0:
		return {}
	return {"tool": kind, "progress": clampf(person.craft_progress, 0.0, 1.0)}


func _craft(person: Inhabitant, hours: float) -> void:
	var fraction := hours / HORAS_UTILES
	if fraction <= 0.0:
		return

	var speciality := person.current_speciality as Profession.Speciality
	var kind := _next_piece(speciality)
	if kind < 0:
		return
	var kind_value := kind as Tool.Kind

	# Con todo cubierto no se sigue tallando. Nadie hace ciento veinte lascas
	# que no va a usar, y dejarlo abierto convertia al artesano en una fabrica
	# de numeros que no cambian nada.
	#
	# El margen del 30% es la reserva: se trabaja hasta tener algo de sobra,
	# no hasta el filo justo, porque quedarse al ras un dia de caza es como se
	# pierde una jornada entera.
	if tool_coverage(kind_value) >= RESERVA_UTILLAJE:
		person.craft_progress = 0.0
		return

	# La herramienta previa. Sin buril no se ranura el asta: no es que se
	# tarde mas, es que no se hace, y esa dependencia entre talleres es media
	# gracia del sistema.
	var prerequisite := Tool.needs_tool(kind_value)
	if prerequisite >= 0 and toolkit.count(prerequisite as Tool.Kind) <= 0:
		return

	# Progreso acumulado hacia la siguiente pieza. Se guarda por persona
	# porque una azagaya no sale de una sentada.
	var rate: float = float(CRAFT_PER_DAY.get(speciality, 1.0))
	person.craft_progress += fraction * rate * person.effectiveness()
	if person.craft_progress < 1.0:
		return

	# Ya hay pieza. Se paga la materia prima; si no la hay, no sale y el
	# progreso se queda esperando a que alguien la traiga.
	var stuff := Tool.default_stuff(kind_value)
	var recipe := Tool.recipe(kind_value)
	for material: int in recipe:
		var wanted: float = float(recipe[material])
		# El silex se prefiere cuando lo hay: triplica la vida de la pieza
		if material == Materia.Kind.PIEDRA \
				and store.amount(Materia.Kind.SILEX) >= wanted:
			continue
		if store.amount(material as Materia.Kind) < wanted:
			return

	for material: int in recipe:
		var wanted: float = float(recipe[material])
		if material == Materia.Kind.PIEDRA \
				and store.amount(Materia.Kind.SILEX) >= wanted:
			store.take(Materia.Kind.SILEX, wanted)
			stuff = Tool.Stuff.SILEX
			continue
		store.take(material as Materia.Kind, wanted)

	if prerequisite >= 0:
		toolkit.use(prerequisite as Tool.Kind,
			Tool.wear_per_day(prerequisite as Tool.Kind) * 0.5)

	var made := toolkit.craft(kind_value, stuff, person.effectiveness())
	note_tool_made(kind_value)
	person.craft_progress -= 1.0
	# Las piezas se apuntan en negativo del catalogo de materiales para no
	# mezclarlas con la materia prima: el libro de trabajo las separa al
	# leerlas. Ver [Inhabitant.work_log].
	person.log_gain(person.current_task(), -1 - int(kind_value), 1.0)

	# La PRIMERA de un tipo, o la primera de silex, se cuenta. Las siguientes
	# no: un diario que anota cada lasca deja de leerse.
	var first_of_kind := toolkit.count(kind_value) == 1
	if stuff == Tool.Stuff.SILEX and not _knows_silex:
		_knows_silex = true
		_note(Chronicle.Kind.TALLER,
			"%s saco la primera pieza de silex de la banda: %s. Aguanta casi el "
				% [person.given_name, made.display_name().to_lower()]
			+ "triple que la cuarcita.", 2)
	elif first_of_kind:
		_note(Chronicle.Kind.TALLER,
			"%s hizo la primera %s de la banda."
				% [person.given_name, Tool.kind_name(kind_value).to_lower()], 1)


## Si la banda ha llegado a trabajar silex alguna vez. Solo para no repetir el
## aviso: la primera pieza de silex es noticia, la decima no.
var _knows_silex: bool = false


## Que trae cada actividad en una JORNADA COMPLETA de trabajo, en unidades de
## cada material.
##
## Son cantidades absolutas, no proporciones de una tasa comun. Con
## proporciones habia un fallo grave: un haz de lena pesa 16 kg y el limite de
## carga sin cesto son 11, asi que la misma "tasa" que daba dos raciones de
## fruto -un kilo- daba tambien media tonelada equivalente de lena. La gente se
## llenaba en el primer instante y volvia a casa con las manos casi vacias.
##
## OJO CON LA UNIDAD, que es donde estuvo el error: son las cifras de once
## horas de trabajo PURO, con destreza perfecta y el paraje bien conocido. Eso
## no pasa nunca.
##
## Una jornada real se va en el camino de ida (hasta tres horas), la busqueda
## del paraje (hasta cuatro) y la vuelta. Medido en la simulacion, solo un 30%
## de la jornada es recoger de verdad, y encima la destreza y el conocimiento
## multiplican por otro 0,3. O sea que lo que llega al almacen es en torno al
## 7% de estas cifras.
##
## Estan calibradas CONTRA ESO: siete recolectores en primavera tienen que dar
## de comer a quince personas con algo de margen. En otono, con el factor de
## estacion a 1,8, sale la cosecha que hay que almacenar; en invierno, a 0,25,
## no llega y hay que tirar de reserva.
func _yield_materials(activity: Subsistence.Activity) -> Dictionary:
	match activity:
		Subsistence.Activity.CAZA:
			# Una pieza mediana repartida entre la partida
			return {
				Materia.Kind.CARNE: 45.0, Materia.Kind.PIEL: 1.1,
				Materia.Kind.HUESO: 3.8, Materia.Kind.TENDON: 1.9,
				Materia.Kind.GRASA: 2.5,
			}
		Subsistence.Activity.PESCA:
			return {Materia.Kind.PESCADO: 42.0}
		Subsistence.Activity.MARISQUEO:
			# Rinde poco por peso: la concha va incluida
			return {Materia.Kind.MARISCO: 26.0}
		Subsistence.Activity.MATERIA_PRIMA:
			return {Materia.Kind.PIEDRA: 13.0, Materia.Kind.OCRE: 0.8}
		_:
			# Recoleccion: comida, y todo lo que se recoge del suelo de paso.
			# En invierno no hay fruto que coger, y a cambio es cuando el
			# ciervo suelta la cuerna.
			return _gathering_yields()


## Lo que da la recoleccion, que cambia mucho con la estacion.
##
## No es solo comida ni es siempre lo mismo: en otono se recoge la cosecha del
## ano, en primavera hay huevos y brotes pero poca caloria, en verano fruto
## fresco y resina, y en invierno no hay vegetal y lo que se recoge es lena,
## raiz y la cuerna que suelta el ciervo.
##
## Esa variacion ES la estacionalidad: sin ella el otono y el invierno serian
## el mismo trabajo con distinto multiplicador.
func _gathering_yields() -> Dictionary:
	# Lo que hay todo el ano, pase lo que pase
	var yields := {
		Materia.Kind.LENA: 2.2,
		Materia.Kind.FIBRA: 3.5,
		Materia.Kind.YESCA: 0.6,
		Materia.Kind.RAIZ: 6.0,
		Materia.Kind.CORTEZA: 0.9,
		Materia.Kind.HUESO: 0.4,
	}

	match GameState.season:
		Subsistence.Season.PRIMAVERA:
			# Todo brota y todo cria: poca caloria, mucha materia prima
			yields[Materia.Kind.FRUTO_SECO] = 6.0
			yields[Materia.Kind.HUEVO] = 4.5
			yields[Materia.Kind.BAYA] = 3.0
			yields[Materia.Kind.CARACOL] = 5.0
			yields[Materia.Kind.PLUMA] = 1.2
			yields[Materia.Kind.RAIZ] = 9.0
		Subsistence.Season.VERANO:
			yields[Materia.Kind.BAYA] = 12.0
			yields[Materia.Kind.MIEL] = 1.2
			yields[Materia.Kind.CARACOL] = 6.0
			yields[Materia.Kind.RESINA] = 1.8
			yields[Materia.Kind.FRUTO_SECO] = 9.0
		Subsistence.Season.OTONO:
			# La cosecha. Lo que se guarde ahora decide el invierno.
			yields[Materia.Kind.FRUTO_SECO] = 32.0
			yields[Materia.Kind.BELLOTA] = 22.0
			yields[Materia.Kind.SETA] = 7.0
			yields[Materia.Kind.BAYA] = 6.0
		_:
			# Invierno: no hay vegetal. Lena, raiz, y la cuerna de desmogue,
			# que es la unica materia dura animal que no exige matar.
			yields[Materia.Kind.FRUTO_SECO] = 4.0
			yields[Materia.Kind.ASTA] = 0.8
			yields[Materia.Kind.LENA] = 3.2
			yields[Materia.Kind.HUESO] = 1.0

	return yields


## Descarga lo que trae en el almacen.
func _deliver(person: Inhabitant) -> void:
	# Volver al abrigo cierra la salida. Sin esto, una salida que se
	# interrumpe -porque se acaba la comida, porque se le cambia el oficio, o
	# porque no habia por donde llegar- se queda abierta para siempre y sigue
	# sumando kilometros de otros dias.
	if not person.journey.is_empty():
		# El sitio se nombra por LO MAS LEJOS que llego, no por su destino: al
		# volver, el destino ya es el propio abrigo, y salia «en del abrigo, a
		# 0 m», que no es una frase.
		var reached := float(person.journey["farthest"])
		var where := "el entorno del abrigo" if reached < arrive_radius * 3.0 			else parajes.place_name(
				person.journey["far_point"] as Vector3, home_position)
		person.end_journey(day, where, _brought_text(person))

	var rejected := 0.0
	for kind: int in person.load.keys():
		var units: float = person.load[kind]
		if units <= 0.0:
			continue
		store.add(kind as Materia.Kind, units)
		# Lo que se llevó de casa y vuelve sin gastar NO es producción: es la
		# misma comida y la misma piel dando un paseo. Ver `carried_out`.
		var gathered := units - person.brought_from_store(kind as Materia.Kind)
		note_production(kind as Materia.Kind, maxf(gathered, 0.0))
		rejected += store.overflow
	person.load.clear()
	person.carried_out.clear()
	person.carrying = 0.0
	# Y el cesto y el odre vuelven al abrigo con quien los llevaba. Se cogen
	# AL SALIR -ver `_hand_out_containers`-, asi que quedarselos puestos en
	# casa es quitarselos a quien sale manana: con dos cestos hechos y quince
	# personas, los dos primeros que los cogieron no los soltaban nunca.
	person.has_basket = false
	person.has_waterskin = false
	# El odre vuelve al abrigo, y vuelve LLENO: se rellena en el rio de la
	# puerta. Ver `_sync_waterskins`.
	_sync_waterskins()
	if rejected > 0.01:
		storage_full.emit(rejected)


## Un rato de comida: se come del almacen y baja el hambre.
##
## Sale del bloque de estados para poder llamarla TAMBIEN de noche. La cena es
## a las nueve -ver [HORA_CENA]- y a esa hora el reparto noche/dia ya ha
## mandado a todo el mundo a dormir, asi que el estado COMIENDO no llegaba a
## procesarse nunca y la cena era una comida que empezaba y no terminaba.
func _eat_meal(person: Inhabitant, hours: float) -> void:
	# La barra de hambre ES la jornada: de 0 a 100 va lo que come una persona en
	# un dia. Asi una RACION -media jornada, ver [Materia.KCAL_RACION]- quita
	# exactamente cincuenta, y las dos comidas del dia suman cien.
	#
	# Antes eran dos numeros sueltos —hambre por hora y hambre por racion— y no
	# cuadraban: la banda consumia un 50% mas de lo que decia `daily_food()`.
	var bite := _eat_from_store(hours * 3.0)
	# Cocinar no anade comida: hace que la que hay cunda mas. La carne y la
	# raiz al fuego se digieren mejor y dan mas calorias aprovechables por la
	# misma racion -es la tesis de Wrangham sobre el fuego en la dieta humana-,
	# asi que el hogar no toca el almacen, toca cuanto quita el hambre.
	# Encendido, no construido: un hogar apagado es un corro de piedras, y
	# sobre un corro de piedras no se cocina.
	var cooked := 1.15 if hearth_lit else 1.0
	person.hunger = maxf(person.hunger - bite * cooked * HAMBRE_POR_RACION, 0.0)
	if person.hunger < COMIDA_SUFICIENTE or bite <= 0.0:
		person.state = Inhabitant.State.OCIOSO


## Come del almacen, empezando por lo que antes se echa a perder.## Come del almacen, empezando por lo que antes se echa a perder.
##
## El orden importa: comerse primero la carne fresca y dejar el fruto seco para
## el final es lo que de verdad hacia una banda, y ademas es lo optimo.
func _eat_from_store(rations: float) -> float:
	# TODO lo que alimenta, y no una lista escrita a mano.
	#
	# Era una lista de seis -pescado, marisco, carne, grasa, carne seca y
	# fruto seco- mientras `Storehouse.food_rations` contaba las doce cosas
	# que alimentan. O sea que la raiz, la baya, la bellota, la seta, el
	# huevo, la miel y el caracol entraban en la cuenta de la despensa y no
	# se comian NUNCA. Medido en el sitio 56: dia 23, cuarenta y siete
	# raciones en el abrigo, los quince con el hambre a 100 y la cifra
	# clavada quince dias seguidos. En primavera lo que se recoge es raiz, y
	# la banda se moria de hambre al lado de ella.
	#
	# El orden es por lo que antes se pudre: se come primero lo que no
	# aguanta, que es lo que haria cualquiera y ademas evita tirarlo.
	var order: Array[int] = []
	for kind: int in Materia.Kind.values():
		if Materia.is_food(kind as Materia.Kind):
			order.append(kind)
	order.sort_custom(func(a: int, b: int) -> bool:
		return Materia.shelf_life(a as Materia.Kind) 			< Materia.shelf_life(b as Materia.Kind))

	var eaten := 0.0
	for kind: int in order:
		if eaten >= rations:
			break
		var k := kind as Materia.Kind
		var needed := (rations - eaten) / maxf(Materia.nutrition(k), 0.001)
		var taken := store.take(k, needed)
		eaten += taken * Materia.nutrition(k)
	return eaten


## Cuanto multiplica la velocidad por marisma o vado saber nadar de verdad.
const NATACION_MARISMA_BONUS := 1.6

## Cuanto sube NATACION por hora metido en el barro o el vado. Minusculo, a
## proposito: es un rasgo de cuerpo, no una destreza de tajo.
const NATACION_TRAINING_RATE := 0.00006


## Velocidad de una persona aqui y ahora, en unidades de mundo por segundo.
##
## `hours` solo hace falta para entrenar NATACION si se cruza marisma o vado;
## si algun dia esto se llama fuera de `_tick_person` sin ese dato, 0.0 lo
## deja sin efecto.
func _terrain_speed(person: Inhabitant, direction: Vector3, hours: float = 0.0) -> float:
	if _terrain == null:
		return walk_speed

	# Pendiente en el sentido de la marcha, medida sobre una zancada larga: a
	# la distancia de un vertice manda el ruido del terreno, no la ladera
	var probe := 12.0
	var ahead := person.position + direction * probe
	var rise := _terrain.get_height_at(ahead) - person.position.y
	var slope := rise / probe

	var ground := Traversal.classify_ground(
		absf(slope), _terrain.crossing_difficulty_at(person.position))
	var load := clampf(person.carrying / maxf(carry_capacity, 0.001), 0.0, 1.0)

	# La curva de Tobler da km/h; aqui interesa la PROPORCION respecto al llano
	# de vacio, para no tocar la escala de tiempo que ya estaba calibrada
	var reference := Traversal.travel_speed(0.0, Traversal.Ground.PASTO, 0.0)
	var here := Traversal.travel_speed(slope, ground, load)

	var swim := 1.0
	if ground == Traversal.Ground.MARISMA:
		# El barro y el agua somera es donde de verdad se nota saber nadar:
		# quien nada no lucha con cada paso igual que quien no. No abre paso
		# donde antes no lo habia -eso pide tocar la rejilla compartida, ver
		# `NATACION` en Inhabitant- pero cruza lo que ya se cruza mucho mejor.
		swim = lerpf(1.0, NATACION_MARISMA_BONUS,
			person.trait_in(Inhabitant.Trait.NATACION))
		# Y se entrena AQUI, metido en el barro, no reconociendo terreno seco.
		person.train_trait(Inhabitant.Trait.NATACION, hours * NATACION_TRAINING_RATE)

		# Y si es la primera vez que la banda pasa por AQUI, es un hito de
		# expedicion: una forma de cruzar el rio que antes no se sabia. La
		# batida no cuenta -no se aleja lo bastante para toparse con un vado
		# que nadie conociera ya.
		if person.current_speciality == Profession.Speciality.EXPEDICION:
			var ford_key := _ford_key(person.position)
			if not _known_fords.has(ford_key):
				_known_fords[ford_key] = true
				_award_exploration_skill(person, Profession.Speciality.EXPEDICION,
					FORD_MILESTONE)
				_note(Chronicle.Kind.HALLAZGO,
					"%s encontro por donde cruzar %s." % [person.given_name,
						parajes.place_name(person.position, home_position)], 1)

	# Con un suelo, y no por bondad: Tobler multiplicado por el suelo que se
	# pisa y por la carga puede bajar al 2 % del paso normal -medido en un
	# canchal de pendiente 1,4-, y a ese paso cincuenta metros son media
	# jornada. Desde fuera eso no se distingue de estar parado: es exactamente
	# lo que la vigilancia de atascos lee como «plantado», y con razón. El 12 %
	# sigue siendo ocho veces más lento que el llano, pero se ve avanzar.
	# El suelo se aplica ANTES del saber nadar, no después: puesto al final
	# aplastaba los dos casos contra el mismo número y quien sabía nadar cruzaba
	# la marisma exactamente igual que quien no. El suelo dice «nadie se queda
	# clavado»; el saber nadar sigue siendo una ventaja sobre eso.
	var ratio := maxf(here / maxf(reference, 0.001), MIN_PACE)
	return walk_speed * ratio * swim


## Si se puede poner el pie en un punto concreto.
func _can_step_into(world_position: Vector3) -> bool:
	if _terrain == null:
		return true

	# UNA sola autoridad sobre donde se puede estar, y es la rejilla.
	#
	# Antes esto miraba el punto suelto bajo los pies mientras el planificador
	# miraba la celda entera de cuarenta metros con cinco muestras. Los dos
	# tenian razon y no se ponian de acuerdo: habia sitios donde una persona
	# podia estar tan tranquila y que para la rejilla NO EXISTIAN. Se mandaba
	# a un recolector a un tajo asi, el andador le dejaba llegar, y una vez
	# alli no se le podia trazar nada -cualquier ruta empieza en una celda
	# inexistente-. De ahi salian los tres atascos: sin camino, con el camino
	# agotado, o de pie en la nada.
	#
	# Medido en la partida: Duna el dia 17 y Caro el dia 19, en el mismo punto
	# exacto, con «aqui CERRADO, el andador pasa: si».
	var grid := _navgrid()
	if grid.is_ready():
		return grid.cost[grid.cell_of(world_position)] > Navgrid.BLOCKED

	var slope := _terrain.get_slope_at(world_position)
	return Traversal.is_passable(slope,
		_terrain.crossing_difficulty_at(world_position), has_boat, has_bridge)


## Qué actividades enseña estar donde se está.
##
## Para casi todo el mundo es la suya: quien recoge avellana aprende de
## avellanares, no de vados de salmón. Pero la exploración no produce nada
## propio -bate la comarca entera-, y a `person.activity` solo se le puso
## CAZA porque la tabla de oficios exige poner algo. Sin distinguir esto,
## ningún explorador enseñaba nunca pesca, marisqueo, recolección ni
## materia prima por mucho que anduviera: solo podían nacer parajes de
## caza, nunca de nada más, que es justo la queja de "no descubre nada".
static func _activities_for_learning(person: Inhabitant) -> Array:
	if person.job == Profession.Job.EXPLORACION:
		return [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
			Subsistence.Activity.MATERIA_PRIMA]
	return [person.activity]


## Anota lo que una persona esta aprendiendo por estar donde esta.
##
## Se aprende de las dos cosas, pero no igual: la jornada en el tajo ensena
## lo que da ese paraje, y el camino solo ensena que existe.
func _learn_from(person: Inhabitant, delta: float) -> void:
	if knowledge == null:
		return

	var working := person.state == Inhabitant.State.TRABAJANDO
	var moving := person.state == Inhabitant.State.YENDO \
		or person.state == Inhabitant.State.VOLVIENDO
	if not working and not moving:
		return

	# Andar descubre mapa. Va aparte de la familiaridad con el recurso: se
	# puede cruzar un valle entero sin aprender nada de su caza y aun asi
	# conocer el camino y haber visto las bocas de cueva del paso.
	knowledge.see_from(person.position, sight_range * weather.sight_factor())

	# El ritmo se escala con el dia de juego para que aprender un paraje
	# lleve jornadas y no segundos
	var pace := delta / maxf(seconds_per_day, 0.001)
	var intensity := pace * (1.0 if working else 0.18)
	for activity: int in _activities_for_learning(person):
		knowledge.observe(activity as Subsistence.Activity, person.position, intensity)

	# Trabajar un paraje ensena tambien lo que se ve alrededor: quien pasa el
	# dia recogiendo avellana ve el avellanar entero, no solo la mata que tiene
	# delante. Sin esto la familiaridad subia en una unica celda y el
	# porcentaje de la pestana no se movia nunca de cero.
	if working:
		for offset: Vector2 in [Vector2(85.0, 0.0), Vector2(-85.0, 0.0),
				Vector2(0.0, 85.0), Vector2(0.0, -85.0)]:
			for activity: int in _activities_for_learning(person):
				knowledge.observe(activity as Subsistence.Activity,
					person.position + Vector3(offset.x, 0.0, offset.y), pace * 0.45)


## Factor por conocimiento del paraje y de la temporada.
##
## Es lo que hace que la banda mejore con los anos sin tocar ni un numero de
## produccion: el mismo cazador en el mismo sitio saca mas cuando ya sabe por
## donde entran los ciervos y en que mes bajan.
func _knowledge_factor(person: Inhabitant) -> float:
	if knowledge == null or field == null:
		return 1.0
	var believed := knowledge.believed_abundance(
		field, person.activity, person.position, GameState.season)
	var real := field.seasonal_abundance_at(
		person.activity, person.position, GameState.season)
	if real <= 0.001:
		return 1.0
	return (believed / real) * knowledge.efficiency(person.activity, GameState.season)


## Lo que consigue una persona en una jornada completa de su actividad
func _daily_yield(person: Inhabitant) -> float:
	# El explorador vuelve con mapa, no con comida. Es la contrapartida que
	# hace que asignar gente a explorar sea una DECISION: se cambia comida de
	# hoy por saber donde estara la de manana.
	if person.job == Profession.Job.EXPLORACION:
		return 0.0
	# Cifras por JORNADA COMPLETA de trabajo efectivo. Estaban calibradas para
	# cuando la produccion no se descontaba por camino, busqueda ni carga, y
	# con todo eso descontado la banda producia justo lo que comia: cero
	# margen, hambre permanente y ninguna decision posible.
	#
	# La referencia real: un forrajeo bueno da 2.000-3.000 kcal por jornada y
	# un adulto necesita 2.000-2.500. Como ocho adultos sostienen a quince
	# personas -crios y ancianos incluidos-, cada uno tiene que traer cerca del
	# doble de lo que come.
	match person.activity:
		Subsistence.Activity.CAZA: return 6.5 * person.effectiveness()
		Subsistence.Activity.PESCA: return 7.5 * person.effectiveness()
		Subsistence.Activity.MARISQUEO: return 4.2 * person.effectiveness()
		Subsistence.Activity.RECOLECCION: return 5.0 * person.effectiveness()
		_: return 2.5 * person.effectiveness()


## Cierre del dia: comer de la reserva y pasar cuentas
## Cuantas jornadas de historia se guardan de cada material.
##
## Ciento veinte: una temporada larga. Con menos no se ve la curva de una
## estacion, que es justo lo que hay que ver -si el fruto seco aguanta el
## invierno, si la carne se pudre antes de comerla-, y con mucho mas la
## grafica se vuelve ilegible en un panel de cuatrocientos pixeles.
const HISTORY_DAYS := 120

## Lo que habia de cada material al acabar cada jornada.
##
## Materia.Kind -> PackedFloat32Array, la ultima al final. Se guarda el
## RESULTADO del dia y no cada movimiento: lo que el jugador necesita ver es
## la tendencia -sube, baja, se estanca-, no el minuto a minuto.
var history: Dictionary = {}


## Apunta el cierre del dia de cada material.
func _record_history() -> void:
	for kind: int in Materia.Kind.values():
		_push_history(kind, store.amount(kind as Materia.Kind))

	# Y el utillaje. Se apunta con clave NEGATIVA para que no choque con los
	# materiales, que empiezan en cero como las piezas: es el mismo apano que
	# usa el libro de trabajo, y por el mismo motivo.
	for kind: int in Tool.Kind.values():
		_push_history(-1 - kind, float(toolkit.count(kind as Tool.Kind)))


func _push_history(key: int, value: float) -> void:
	var series: PackedFloat32Array = history.get(key, PackedFloat32Array())
	series.append(value)
	while series.size() > HISTORY_DAYS:
		series.remove_at(0)
	history[key] = series


## La serie de un material, de la jornada mas vieja a la de hoy.
func history_of(kind: Materia.Kind) -> PackedFloat32Array:
	return history.get(int(kind), PackedFloat32Array())


## Y la de una pieza de utillaje.
func tool_history_of(kind: Tool.Kind) -> PackedFloat32Array:
	return history.get(-1 - int(kind), PackedFloat32Array())


func _end_of_day() -> void:
	_record_history()
	# Lo que la banda cree saber se reordena una vez al dia. Antes se
	# recalculaba por persona y por salida, y eso eran 61.000 operaciones cada
	# vez que alguien cruzaba la puerta.
	_rank_known_spots()
	store.age(1)
	_burn_hearth()

	# Las piezas rotas se retiran ahora y no al romperse, para que el parte del
	# dia pueda contarlas antes de que desaparezcan.
	toolkit.discard_spent()
	toolkit.broken_today.clear()

	# Las trampas cobran mientras la banda duerme, y se van gastando.
	_age_traps()

	# Los parajes se reponen. Sin esto lo esquilmado no volvia nunca y el valle
	# se vaciaba en unas semanas. Las vetas quedan fuera: ver `_freeze_veins`.
	if field:
		_freeze_veins()
		for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
				Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
				Subsistence.Activity.MATERIA_PRIMA]:
			field.regrow(activity as Subsistence.Activity, 0.045)
	# La comida se consume DURANTE el dia, en el estado COMIENDO. Aqui solo se
	# pasa cuenta de quien no ha conseguido comer.
	#
	# Antes se descontaba tambien aqui, asi que la banda comia dos veces: una
	# al ir a comer y otra al cerrar el dia. Con el consumo doblado, la
	# produccion nunca llegaba y el almacen se quedaba clavado en cero por
	# mucho que subieran los rendimientos.
	for person: Inhabitant in people:
		if person.hunger > 70.0:
			person.hunger = clampf(person.hunger + 6.0, 0.0, 100.0)

	_roll_production()
	_roll_weather()
	_check_mishaps()
	_check_scout_order()

	# Los sitios que la banda ya conoce lo bastante se bautizan. Va aqui, una
	# vez por jornada: recorre las 4.096 celdas del campo y hacerlo por
	# fotograma fue lo que se comio el rendimiento la vez anterior.
	_name_new_parajes()

	# Se cuenta al calor del fuego, no en el tajo: el que se ha quedado fuera
	# esta noche no oye nada de esto.
	_knowledge_transmission()

	# El reparto se rehace cada jornada: una persona que ha dejado de criar,
	# o un crio que ha crecido, entran solos en los trabajos que ya tenian
	# marcados sin que el jugador tenga que acordarse.
	apply_priorities()

	# Y AHORA se olvida lo que hoy no tenia camino. El reparto de arriba
	# acaba de verlo -para eso esta-, y manana se vuelve a intentar: una
	# pasarela o una piragua pueden haber abierto el paso mientras tanto.
	_unreachable_today.clear()
	# Y cada cual vuelve a probar los sitios que ayer no pudo: un vado que
	# bajaba, un canchal con nieve. Ver `Inhabitant.given_up`.
	for person: Inhabitant in people:
		person.given_up.clear()

	_note_daily_state()

	season_day += 1
	if season_day >= Subsistence.DAYS_PER_SEASON:
		_advance_local_season()


## Cuanta distancia hacia el techo transmisible se cierra en una noche de
## relato, antes de aplicar la velocidad de cada cual. Ver
## `Inhabitant.learn_rate`.
const TRANSMISSION_RATE := 0.06

## Que fraccion de lo que sabe el mejor presente se puede pasar de palabra.
##
## Contar no es lo mismo que hacer: un anciano con el 50% no transmite ese
## 50% entero por mucho que lo cuente todo, porque una parte de lo que sabe
## es la mano, no el relato -aquello que solo se fija haciendolo, no
## oyendolo-. El 75% es lo que de verdad cabe en una historia junto al
## fuego; el resto solo se aprende saliendo a probarlo.
const TRANSMISSION_CEILING := 0.75


## Transmision de conocimiento junto al fuego.
##
## Cada noche, quien esta EN LA CUEVA -durmiendo alli, no de camino ni
## acampado al raso- se acerca un poco a lo que sabe el mejor de los que
## estan esa misma noche, tarea por tarea. Es la otra mitad de aprender, al
## lado de la practica en el tajo: un crio o un anciano no salen a cazar,
## pero oyen contar la cacena junto al fuego, y de ahi sacan algo igual. El
## techo NO es lo que sabe el mejor presente, es el [TRANSMISSION_CEILING]
## de eso: se escucha y se acerca, no se supera de oidas ni se iguala del
## todo.
##
## Solo cuenta quien esta AHI esa noche. Quien anda de expedicion o acampado
## fuera no oye nada de esto, por mucho que lleve tres jornadas camino de
## casa: es la unica forma honesta de que "en la cueva juntos" signifique
## algo.
func _knowledge_transmission() -> void:
	var present: Array[Inhabitant] = []
	for person: Inhabitant in people:
		# Presente es estar EN el abrigo, galeria incluida: preguntando doce
		# metros al punto del abrigo, una cueva con la galeria mas adentro
		# dejaba a los que duermen dentro fuera del corro, y entonces no se
		# enseña nadie a nadie sin que se vea por ninguna parte.
		if person.state == Inhabitant.State.DURMIENDO \
				and _at_shelter(person):
			present.append(person)
	if present.size() < 2:
		return

	# Lo mejor que se sabe esta noche, tarea por tarea, entre los presentes.
	# Quien no esta en la cueva no cuenta ni como maestro ni como alumno.
	var best_known: Dictionary = {}
	for person: Inhabitant in present:
		for task: int in person.skill:
			var value: float = float(person.skill[task])
			if value > float(best_known.get(task, 0.0)):
				best_known[task] = value

	for person: Inhabitant in present:
		for task: int in best_known:
			var ceiling: float = float(best_known[task]) * TRANSMISSION_CEILING
			var mine := person.skill_in(task)
			if ceiling <= mine:
				continue
			var gain := (ceiling - mine) * TRANSMISSION_RATE * person.learn_rate()
			person.skill[task] = minf(mine + gain, ceiling)


## Umbral de reserva por debajo del cual se avisa, en jornadas de comida.
const RESERVA_CRITICA := 3.0

## Estado del ultimo aviso de hambre, para no repetirlo cada jornada. La
## primera vez que se cruza el umbral es noticia; las diez siguientes, ruido.
var _warned_hungry: bool = false
var _warned_full: bool = false


func _note_daily_state() -> void:
	var mouths := 0.0
	for person: Inhabitant in people:
		mouths += person.daily_food()
	var days_left := store.days_of_food(mouths)

	if days_left < RESERVA_CRITICA and not _warned_hungry:
		_warned_hungry = true
		_note(Chronicle.Kind.PENURIA,
			"Queda comida para menos de tres jornadas. Con %d bocas, "
				% people.size()
			+ "cualquier temporal deja a la banda sin nada.", 2)
	elif days_left > RESERVA_CRITICA * 2.5:
		_warned_hungry = false

	var full := store.fullness()
	if full > 0.92 and not _warned_full:
		_warned_full = true
		_note(Chronicle.Kind.PENURIA,
			"El abrigo esta lleno: %s de %s. Lo que traigan se queda fuera."
				% [Materia.format_volume(store.total_litres()),
					Materia.format_volume(store.capacity_litres)], 1)
	elif full < 0.80:
		_warned_full = false


## Avanza la estacion desde el reloj local, SIN repetir el calculo economico
## abstracto del mapa regional.
##
## Antes `GameState.season` solo se movia a mano, desde `RegionMap`, con un
## calculo de produccion y consumo agregado para toda la estacion. Jugar en el
## asentamiento no lo tocaba: se podian vivir cien jornadas sin que llegara
## nunca el otono. Aqui la comida YA se lleva dia a dia y persona a persona, o
## sea que llamar a `GameState.advance_season()` la contaria dos veces -una
## granular, aqui, y otra agregada, alla-. Este metodo solo gira la fecha.
func _advance_local_season() -> void:
	season_day = 0
	GameState.season = ((GameState.season + 1) % 4) as Subsistence.Season
	if GameState.season == Subsistence.Season.PRIMAVERA:
		GameState.year += 1
	GameState.last_report = "Empieza %s, año %d." % [
		Subsistence.season_name(GameState.season), GameState.year]
	_note(Chronicle.Kind.TIERRA, _season_line(), 2)

	# Lo que hay en cada paraje conocido se rehace para la estación nueva:
	# sin esto, un sitio se quedaba con lo que daba el día que se bautizó
	# para siempre -miel en pleno invierno, cuernas caídas en julio-, y la
	# estación no se notaba en QUÉ hay que ir a buscar, solo en el
	# multiplicador de rendimiento. Ver [Paraje.fill_contents].
	if field:
		for paraje: Paraje in parajes.list:
			paraje.fill_contents(field, GameState.season)

	season_changed.emit(GameState.season, GameState.year)

	if GameState.season == Subsistence.Season.OTONO:
		_offer_rut_choice()


## Cuánto sube de precio la lesión de quien decide aguantar y seguir fuera.
##
## Sin calibrar, como el resto del balanceo: lo decidido es que quedarse fuera
## con un tobillo torcido tenga precio, no cuánto.
const PERCANCE_AGUANTAR := 1.8


## La decisión de la berrea, al empezar el otoño.
##
## SLICE_PALEOLITICO §3 dice que el otoño decide si se sobrevive al invierno.
## Hasta ahora eso pasaba solo: cambiaba el multiplicador de rendimiento de la
## caza y el jugador se enteraba si iba a mirar la tabla. Aquí se le pone
## delante, con la reserva que lleva, y se le deja decidir en el momento.
func _offer_rut_choice() -> void:
	var stock := winter_stock()
	var moment := Moment.new()
	moment.kind = Moment.Kind.BERREA
	moment.title = "Empieza la berrea"
	moment.text = ("El ciervo baja y se junta: son las mejores semanas de caza "
		+ "del año, y las únicas que llenan la despensa de cara al invierno. "
		+ "Ahora mismo hay %d raciones de las %d que se comerán en invierno."
		) % [int(stock["have"]), int(stock["needed"])]
	moment.options = [
		{
			"label": "Volcarse en la berrea",
			"hint": "Todo el que pueda cazar pasa a caza mayor. Se dejan de "
				+ "hacer otras cosas: es la apuesta.",
			"on_pick": func() -> void: focus_on_rut(),
		},
		{
			"label": "Seguir como hasta ahora",
			"hint": "El reparto de oficios no se toca.",
			"on_pick": func() -> void: pass,
		},
	]
	raise_moment(moment)


## Vuelca la banda en la caza mayor. Es la mitad activa de la berrea.
func focus_on_rut() -> void:
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	var sent := 0
	for person: Inhabitant in people:
		if not Profession.can_do(Profession.Job.CAZA, person):
			continue
		person.set_priority(task, 3)
		sent += 1
	apply_priorities()
	_note(Chronicle.Kind.TIERRA,
		"La banda se vuelca en la berrea: %d salen a la caza mayor." % sent, 2)


## Lo que significa que entre cada estacion, dicho como se diria.
##
## No es adorno: cada frase avisa de lo que va a cambiar en los rendimientos,
## que es informacion que hoy solo esta en una tabla de multiplicadores.
func _season_line() -> String:
	match GameState.season:
		Subsistence.Season.PRIMAVERA:
			return "Entra la primavera del año %d. Sube el rio y remonta el " \
				% GameState.year + "pescado."
		Subsistence.Season.VERANO:
			return "Entra el verano. Los dias son largos y se puede ir lejos."
		Subsistence.Season.OTONO:
			return "Entra el otoño: la avellana y la bellota. Es AHORA cuando " \
				+ "se llena el abrigo o no se llena."
		_:
			return "Entra el invierno. El monte no da y se vive de lo guardado."


func population() -> int:
	return people.size()


## Cuantos estan en cada estado, para la interfaz
func state_counts() -> Dictionary:
	var counts := {}
	for person: Inhabitant in people:
		var key := person.state_name()
		counts[key] = int(counts.get(key, 0)) + 1
	return counts


func hungry_count(threshold: float = 60.0) -> int:
	var total := 0
	for person: Inhabitant in people:
		if person.hunger >= threshold:
			total += 1
	return total


## Ya se ha marcado que celdas de materia prima no vuelven a crecer.
var _veins_frozen := false


## Marca de una vez las celdas de materia prima que NO se reponen.
##
## La materia prima no es una sola cosa: un desmogadero da cuerna caida, que
## vuelve cada invierno, y una veta de silex da nodulos, que no vuelven nunca.
## Cual es cual lo decide [Parajes._kind_for], determinista por posicion, y
## si vuelve o no lo dice [Materia.renews].
##
## Sin esto, `regrow` le devolvia a la veta lo mismo que a un pastizal:
## medido, ocho canteros sacando seis mil unidades en ciento cuarenta dias
## dejaban el cantizal al 77% y ahi se quedaba. No se podia agotar, y sin
## poder agotarse un paraje no se puede perder.
##
## Se hace una sola vez -mil celdas- y no cada jornada.
func _freeze_veins() -> void:
	if _veins_frozen or field == null:
		return
	_veins_frozen = true
	var act := Subsistence.Activity.MATERIA_PRIMA
	for z in range(field.height):
		for x in range(field.width):
			if field.abundance_cell(act, x, z) <= 0.001:
				continue
			var kind := Parajes._kind_for(act, field.cell_center(x, z),
				GameState.season as Subsistence.Season)
			if not Materia.renews(kind):
				field.freeze(act, x, z)


## Si hay un paraje en barbecho cubriendo ese punto.
func _is_resting(activity: Subsistence.Activity, point: Vector3) -> bool:
	for paraje: Paraje in parajes.list:
		if not paraje.resting or not paraje.serves(activity):
			continue
		var flat := Vector2(point.x - paraje.position.x, point.z - paraje.position.z)
		if flat.length() < 90.0:
			return true
	return false


## Bautiza los parajes que se hayan ganado un nombre y los cuenta.
func _name_new_parajes() -> void:
	if field == null or knowledge == null:
		_new_ground_surveys_today.clear()
		return

	parajes.just_found.clear()

	# Primero las bajas y luego las altas. Una veta agotada deja de nombrar
	# su paraje ANTES de que se repase el mapa, para que el punto quede
	# libre y `refresh` pueda bautizarlo esa misma jornada por otra cosa.
	for loss: Dictionary in parajes.prune_exhausted(field):
		var lost: Paraje = loss["paraje"]
		var spent := Materia.material_name(loss["kind"] as Materia.Kind).to_lower()
		if bool(loss["gone"]):
			_note(Chronicle.Kind.PENURIA,
				"Se acabo %s: no queda %s que sacar y el sitio deja de tener nombre."
					% [lost.name_text, spent], 2)
		else:
			_note(Chronicle.Kind.PENURIA,
				"Se acabo el %s de aquel sitio; lo que queda alli ya es otra cosa: %s."
					% [spent, lost.name_text], 1)

	# "Mismo trozo de monte" es "misma zona de la rejilla de navegacion":
	# no hace falta un rio de por medio para que dos celdas cercanas sean
	# sitios distintos, basta con que no se pueda ir de una a otra sin
	# rodear. Es lo mismo que ya usa `_scout_target` para saber si se
	# puede llegar a un sitio, aplicado ahora a si dos sitios son el mismo.
	var grid := _navgrid()
	var same_patch := func(a: Vector3, b: Vector3) -> bool:
		return grid.connected(a, b)
	parajes.refresh(field, knowledge, day, [
		Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
		Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
		Subsistence.Activity.MATERIA_PRIMA], _terrain, same_patch)

	for paraje: Paraje in parajes.just_found:
		_note(Chronicle.Kind.HALLAZGO,
			"La banda ya conoce bien un sitio y le ha puesto nombre: %s, %s a %d m."
				% [paraje.name_text,
					Parajes.bearing(home_position, paraje.position),
					int(paraje.distance_from(home_position))], 1)
		# Poner nombre a un sitio es el hito de la exploración, y se enseña como
		# tal: hasta ahora aparecía un alfiler más en el valle y nada más.
		raise_moment(Moment.found("Un sitio con nombre",
			"%s, %s a %d m del abrigo. La banda ya lo conoce lo bastante como "
				% [paraje.name_text,
					Parajes.bearing(home_position, paraje.position),
					int(paraje.distance_from(home_position))]
			+ "para volver sola.", paraje.position))

	_credit_new_ground(parajes.just_found)
	_new_ground_surveys_today.clear()


## Premia con destreza a quien de verdad ha abierto cada paraje de
## `just_found` hoy -batida o expedicion, cada cual en lo suyo. El hito
## grande no es acabar de conocer un sitio que ya se tenia -eso es
## `_finish_survey`, un material a la vez-, es abrir uno que no existia.
## Aparte de `_name_new_parajes` para poder probarlo sin montar un campo de
## recursos entero.
func _credit_new_ground(just_found: Array[Paraje]) -> void:
	for paraje: Paraje in just_found:
		for entry: Dictionary in _new_ground_surveys_today:
			var surveyor: Inhabitant = entry["person"]
			var spot: Vector3 = entry["position"]
			var speciality := entry["speciality"] as Profession.Speciality
			if spot.distance_to(paraje.position) < SURVEY_RADIUS:
				_award_exploration_skill(surveyor, speciality, PARAJE_MILESTONE)


## Manda a la cuadrilla de un oficio a un paraje concreto. Lo llama el clic.
func work_at(paraje: Paraje) -> void:
	parajes.choose(paraje)
	set_work_site(paraje.activity, paraje.position)
	_note(Chronicle.Kind.GENTE,
		"A trabajar a %s." % paraje.name_text, 1)


## Deja un paraje en barbecho. La banda no vuelve hasta que se le quite.
func rest_paraje(paraje: Paraje) -> void:
	paraje.resting = true
	if paraje.chosen:
		parajes.clear_choice(paraje.activity)
	_note(Chronicle.Kind.GENTE,
		"%s queda en descanso: la banda buscara en otra parte."
			% paraje.name_text, 1)


## Manda explorar hacia un punto. Lo llama el clic sobre terreno desnudo.
func scout_towards(point: Vector3) -> void:
	scout_order = point
	has_scout_order = true
	_note(Chronicle.Kind.GENTE,
		"Sale partida a reconocer %s. Nadie sabe que hay alli."
			% parajes.place_name(point, home_position), 1)


func clear_scout_order() -> void:
	if not has_scout_order:
		return
	has_scout_order = false
	_note(Chronicle.Kind.GENTE,
		"Se levanta la orden de reconocimiento: la banda vuelve a elegir "
			+ "adonde mirar.", 0)


## Si alguien ha llegado ya al sitio señalado, la orden se da por cumplida.
##
## Se comprueba al cerrar la jornada y no por fotograma: una orden que se
## cancela sola a mitad de camino deja a la partida dando vueltas.
func _check_scout_order() -> void:
	# La orden ya NO se cumple por pisar el punto: se cumple cuando alguien
	# termina de reconocer la comarca. Lo hace `_finish_survey`.
	pass


## Lo que puede salir mal ahi fuera, una vez por jornada y por explorador.
##
## Solo le pasa a quien esta LEJOS: el riesgo es el precio de haber mandado la
## partida a mirar, no un impuesto por existir. Y solo a la exploracion: el
## que va al avellanar de al lado no se pierde.
func _check_mishaps() -> void:
	if _terrain == null:
		return

	# Lo que ha dado hoy quien cuidaba adelanta la convalecencia del PEOR
	# herido, que es a quien se atiende primero. Ver `_tend_the_hurt`.
	var nursed: Inhabitant = null
	if _care_given >= 1.0:
		for person: Inhabitant in people:
			if person.hurt_days <= 0:
				continue
			if nursed == null or person.hurt_days > nursed.hurt_days:
				nursed = person
	_care_given = 0.0

	for person: Inhabitant in people:
		if person.hurt_days > 0:
			var gained := CUIDADO_DAYS if person == nursed else 0
			person.hurt_days = maxi(person.hurt_days - 1 - gained, 0)
			if person.hurt_days == 0:
				_note(Chronicle.Kind.GENTE,
					"%s vuelve a andar bien." % person.given_name, 0)

		if person.job != Profession.Job.EXPLORACION:
			continue
		var away := Vector2(person.position.x - home_position.x,
			person.position.z - home_position.z).length()
		if away < 300.0:
			continue

		var ground := Traversal.classify_ground(
			_terrain.get_slope_at(person.position),
			_terrain.crossing_difficulty_at(person.position))
		var risk := Mishap.chance(ground, person.fatigue, away) 			* weather.risk_factor()
		# Dormir mal a la intemperie no es sólo cansancio: es la noche de la
		# que se vuelve con un tobillo o no se vuelve con la carga. Ver
		# `_bivouac`.
		risk *= pow(VIVAC_RIESGO, float(person.bivouac_lack))
		person.bivouac_lack = 0
		if _rng.randf() > risk:
			continue

		_apply_mishap(person, ground, away)


func _apply_mishap(person: Inhabitant, ground: Traversal.Ground,
		away: float) -> void:
	var kind := Mishap.roll(_rng, ground)
	var where := parajes.place_name(person.position, home_position)

	if Mishap.is_good(kind):
		# A veces sale bien: se tropieza con algo que no buscaba
		var found := Materia.Kind.PIEDRA
		if _rng.randf() < 0.4:
			found = Materia.Kind.ASTA
		elif _rng.randf() < 0.3:
			found = Materia.Kind.OCRE
		person.add_load(found, 1.0)
		_note(Chronicle.Kind.HALLAZGO,
			Mishap.tell(kind, person.given_name, where), 1)
		return

	person.hurt_days = maxi(person.hurt_days, Mishap.hurt_days(kind))

	if Mishap.drops_load(kind):
		person.load.clear()
		person.carrying = 0.0

	if Mishap.turns_back(kind):
		_send_to(person, home_position)
		person.state = Inhabitant.State.VOLVIENDO
		# Un percance cancela la orden: insistir en mandarlos al mismo sitio
		# despues de que se hayan tenido que volver es el jugador quien lo
		# decide, no la maquina
		if has_scout_order:
			has_scout_order = false

	_note(Chronicle.Kind.PENURIA,
		Mishap.tell(kind, person.given_name, where),
		2 if Mishap.hurt_days(kind) > 0 else 1)

	# El accidente no se elige; la reacción sí, y es la que hace que perder a
	# alguien concreto pese. Sólo cuando queda margen: una caída ya obliga a dar
	# media vuelta, así que ahí no hay nada que decidir.
	if Mishap.hurt_days(kind) > 0 and not Mishap.turns_back(kind):
		_offer_mishap_choice(person, kind, where)


## Qué se hace con quien se ha roto algo lejos de casa. Ver [Moment].
func _offer_mishap_choice(person: Inhabitant, kind: Mishap.Kind,
		where: String) -> void:
	var moment := Moment.new()
	moment.kind = Moment.Kind.PERCANCE
	moment.who = person
	moment.where = person.position
	moment.has_place = true
	moment.title = "%s, %d años" % [person.given_name, person.age_years]
	moment.text = Mishap.tell(kind, person.given_name, where) 		+ " Está a %d m del abrigo." % int(
			person.position.distance_to(home_position))
	moment.options = [
		{
			"label": "Que vuelva ya",
			"hint": "Se acaba su salida y pierde lo que fuera a traer, pero se "
				+ "cura como debe.",
			"on_pick": func() -> void:
				_send_to(person, home_position)
				person.state = Inhabitant.State.VOLVIENDO,
		},
		{
			"label": "Que aguante y siga",
			"hint": "Termina lo que fue a hacer. Andar con eso roto lo deja "
				+ "tocado bastantes más días.",
			"on_pick": func() -> void:
				person.hurt_days = int(round(
					float(person.hurt_days) * PERCANCE_AGUANTAR))
				_note(Chronicle.Kind.PENURIA,
					"%s aprieta los dientes y sigue." % person.given_name, 1),
		},
	]
	raise_moment(moment)


## Lo que puede salir mal EN EL TAJO de caza, aparte de volver sin pieza:
## «riesgo» en [Fauna] no es un adorno -un uro no es un conejo-, y hasta
## ahora `Hunting.risk_at` se calculaba y no se usaba en ningun sitio: la
## banda podia mandar a un solo cazador contra un uro sin que le pasara
## nunca nada. Una vez al dia y por fraccion de jornada, no en cada tick de
## `_harvest`, o la probabilidad compuesta desmentiria el numero.
##
## La cuadrilla tambien reparte el peligro, no solo el trabajo: cuatro
## batidores no corren cada uno el riesgo entero del que va solo, que es
## justo la otra cara de [Hunting.crew_factor] -ir en cuadrilla no es solo
## mas pieza, es tambien mas seguro-.
func _check_hunting_risk(person: Inhabitant, speciality: Profession.Speciality,
		fraction: float) -> void:
	if speciality != Profession.Speciality.CAZA_MENOR \
			and speciality != Profession.Speciality.CAZA_MAYOR:
		return

	var risk := Hunting.risk_at(speciality, person.work_centre,
		GameState.season as Subsistence.Season, hunters_in(speciality))
	if risk <= 0.0:
		return
	risk *= fraction
	if _rng.randf() > risk:
		return

	var porte := Hunting.porte_of(speciality)
	var species := Fauna.huntable_at(person.work_centre,
		GameState.season as Subsistence.Season, porte as Fauna.Porte)
	var name := Fauna.species_name(species[_rng.randi() % species.size()]) \
		if not species.is_empty() else "la pieza"

	var hurt := Mishap.FALL_DAYS if speciality == Profession.Speciality.CAZA_MAYOR \
		else Mishap.SPRAIN_DAYS
	person.hurt_days = maxi(person.hurt_days, hurt)
	var where := parajes.place_name(person.position, home_position)
	_note(Chronicle.Kind.PENURIA,
		"%s salió mal parado%s cazando %s %s. Va a andar mal unos días." % [
			person.given_name,
			"a" if person.sex == Inhabitant.Sex.MUJER else "",
			name.to_lower(), where],
		2)


## Lo más despacio que anda alguien, en fracción del paso de llano y de vacío.
## Ver `_terrain_speed`.
const MIN_PACE := 0.12


## Radio dentro del cual se batea un paraje mientras se trabaja.
const FORAGE_RADIUS := 70.0


## Mueve a quien esta trabajando por su zona, de mata en mata.
##
## Sin esto la gente llegaba a un punto, se quedaba clavada seis horas y
## volvia, que se lee como un automata. Recoger es batir la mancha, y ademas
## asi la cuadrilla se reparte sola por el paraje en vez de amontonarse.
func _forage_drift(person: Inhabitant) -> void:
	if person.work_centre == Vector3.ZERO:
		person.work_centre = person.position

	if person.position.distance_to(person.forage_target) > arrive_radius * 0.8:
		person.target = person.forage_target
		return

	# Quien trabaja el agua bate la ORILLA, no la mancha entera.
	#
	# Se pesca y se marisquea con los pies en el borde: batiendo el paraje como
	# un recolector, la cuadrilla acababa a cincuenta metros del cauce, de
	# espaldas al río, «pescando» en un prado. Se prueban varios puntos y se
	# toma el primero que tenga agua al alcance de la mano; si ninguno la tiene
	# —el paraje se ha alejado del agua— se bate como siempre, que es mejor que
	# quedarse quieto.
	var waterside := person.activity == Subsistence.Activity.PESCA 		or person.activity == Subsistence.Activity.MARISQUEO
	var tries := SHORE_TRIES if waterside else 1
	for attempt in range(tries):
		var angle := _rng.randf() * TAU
		var reach := FORAGE_RADIUS
		if waterside:
			reach *= SHORE_FORAGE_FACTOR
		var radius := sqrt(_rng.randf()) * reach
		var candidate := person.work_centre + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		if _terrain:
			candidate.y = _terrain.get_height_at(candidate)
			# No se va a recoger al otro lado de un cortado ni al agua
			if not Traversal.is_passable(_terrain.get_slope_at(candidate),
					_terrain.crossing_difficulty_at(candidate), has_boat, has_bridge):
				continue
			if waterside and attempt < tries - 1 and not _water_beside(candidate):
				continue

		person.forage_target = candidate
		person.target = candidate
		return


## Manda a alguien a un sitio TRAZANDO el camino, no en linea recta.
##
## Todo lo que fija un destino pasa por aqui: asi no hay dos maneras de andar
## por el mapa, una con camino y otra sin el.
## Cuantos NODOS de busqueda se gastan como mucho en un fotograma.
##
## Antes se contaban busquedas, y ahi estaba el fallo: un camino que se
## encuentra enseguida cuesta cincuenta nodos y uno que NO existe cuesta doce
## mil, porque para saber que no hay paso hay que recorrerse la comarca
## entera. Tres busquedas por fotograma podian ser ciento cincuenta nodos o
## treinta y seis mil, y de ahi los tirones.
##
## Contando nodos, un fotograma cuesta lo mismo lo pida quien lo pida: si la
## primera busqueda sale cara, las demas esperan al siguiente y mientras tanto
## cada cual sigue con el camino que llevaba.
## Medido sobre la comarca de prueba: unos 8 microsegundos por nodo. Con
## quinientos, lo que puede gastar un fotograma en buscar caminos son cuatro
## milisegundos, y lo que no entre espera al siguiente.
##
## El tope de verdad no es este: es que la mayoria de las busquedas ya no
## llegan aqui. Las que van a un sitio incomunicado se resuelven comparando
## dos enteros, y las repetidas salen de la cache.
const NODES_PER_FRAME := 500
var _path_nodes_this_frame: int = 0

## Cuanta gente sin camino se ha atendido ya este fotograma pasandose el
## presupuesto. Uno como mucho: sin este tope, la manana en que sale la banda
## entera son quince busquedas seguidas y se nota.
var _stranded_this_frame: int = 0


## Manda a alguien a un sitio TRAZANDO el camino, no en linea recta.
##
## Con dos guardas que no son un detalle: el destino REPETIDO no se vuelve a
## trazar, y hay tope por fotograma.
##
## Sin la primera, el juego bajaba a dos fotogramas por segundo a los pocos
## minutos: los bloques de «volver a casa» corren cada fotograma, asi que cada
## persona lanzaba un A* completo sesenta veces por segundo para pedir
## exactamente el mismo camino.
func _send_to(person: Inhabitant, destination: Vector3) -> void:
	var same := Vector2(person.target.x - destination.x,
		person.target.z - destination.z).length() < 1.0

	# El camino tiene que servir TODAVIA, no solo existir.
	#
	# La guarda pedia «mismo destino y ruta no vacia», y una ruta CONSUMIDA
	# hasta el final sin haber llegado cumple las dos: la persona se quedaba
	# con un camino gastado que ya no la llevaba a ninguna parte y no se le
	# volvia a trazar nunca. Peor: el re-trazado que puse para eso entraba
	# aqui y se daba media vuelta en esta misma linea, o sea que no hacia
	# nada.
	#
	# Medido: los tres unicos atascos que quedaban eran esto, los tres a las
	# 21:32 -al mandar a la gente a dormir- con «va por el hito 4 de 4» y el
	# abrigo a 648 metros.
	var spent := person.route_step >= person.route.size()
	if same and not person.route.is_empty() and not spent:
		return

	# A un sitio del que YA se sabe que no hay camino no se vuelve a pedir
	# ruta. Sin esto el juego se hundia a cuatro fotogramas por segundo en
	# cuanto alguien apuntaba al otro lado de un rio: la ruta salia vacia, la
	# guarda de arriba exige ruta NO vacia para no recalcular, y entonces se
	# lanzaba una busqueda completa -agotando los cuatro mil nodos- en cada
	# fotograma y para cada persona.
	if Vector2(person.unreachable.x - destination.x,
			person.unreachable.z - destination.z).length() < 1.0:
		person.target = destination
		return

	# Todo destino se amarra a celda abierta ANTES de nada. Lo hacia solo el
	# buscador de caminos, asi que `_best_known_spot` y compania seguian
	# mandando gente a tajos que la rejilla da por cerrados.
	destination = _firm_ground(destination)
	person.target = destination

	# Si el destino esta en otra ZONA del mapa no hay camino, y saberlo no
	# cuesta nada: la rejilla trae marcados los trozos comunicados entre si.
	# Antes esto era una busqueda exhaustiva de doce mil nodos, y se lanzaba
	# cada vez que alguien apuntaba al otro lado de un rio.
	if not _navgrid().connected(person.position, destination):
		person.route = PackedVector3Array()
		person.route_step = 0
		person.unreachable = destination
		return

	# El presupuesto se mira antes de buscar. Quien va sin camino pasa
	# igualmente, o se quedaria parado para siempre; pero solo uno por
	# fotograma, que es lo que impide que la manana en que la banda entera
	# sale a la vez se coma medio segundo.
	if _path_nodes_this_frame >= NODES_PER_FRAME:
		if not person.route.is_empty():
			return
		if _stranded_this_frame > 0:
			return
		_stranded_this_frame += 1

	# La banda repite trayectos: los mismos quince salen del mismo abrigo a
	# los mismos cuatro tajos todas las mananas y vuelven por donde fueron.
	# Buscar de nuevo un camino que ya se busco ayer es el gasto mas tonto que
	# habia, asi que se guarda por par de celdas.
	var lane := _lane_key(person.position, destination)
	var kept: Variant = _route_cache.get(lane, null)
	if kept != null:
		person.route = _retarget(kept as PackedVector3Array, destination)
		person.route_step = 0
		person.unreachable = Vector3.ZERO
		return

	var route := Wayfinder.find(_navgrid(), person.position, destination)
	_path_nodes_this_frame += Wayfinder.last_nodes

	if not route.is_empty():
		_remember_route(lane, route)

	if route.is_empty():
		# No hay camino: ni se intenta. Se queda donde esta y se le buscara
		# otro destino, que es mejor que salir andando hacia un rio.
		person.route = PackedVector3Array()
		person.route_step = 0
		person.unreachable = destination
		return

	person.route = route
	person.route_step = 0
	person.unreachable = Vector3.ZERO


## Lo que arriesga el camino que lleva ahora mismo, de 0 a 1. Lo usa la ficha
## para poder decirle al jugador que la ruta es mala.
func route_risk(person: Inhabitant) -> float:
	if _terrain == null or person.route.is_empty():
		return 0.0
	var worst := 0.0
	for point: Vector3 in person.route:
		var ground := Traversal.classify_ground(
			_terrain.get_slope_at(point), _terrain.crossing_difficulty_at(point))
		var risk := 0.0
		match ground:
			Traversal.Ground.CANCHAL: risk = 1.0
			Traversal.Ground.ROCA: risk = 0.6
			Traversal.Ground.MARISMA: risk = 0.5
			_: risk = 0.1
		worst = maxf(worst, risk)
	return worst


## Sortea el tiempo de la jornada y lo cuenta si ha cambiado.
##
## Solo se anota cuando CAMBIA o cuando lleva ya varios dias: un diario que
## dice «hoy nublado» todas las jornadas deja de leerse a la tercera.
func _roll_weather() -> void:
	var changed := weather.advance(_rng, GameState.season)
	if changed:
		var heavy := weather.kind == Weather.Kind.TEMPORAL 			or weather.kind == Weather.Kind.NIEVE
		_note(Chronicle.Kind.TIERRA, weather.tell(), 1 if heavy else 0)
	elif weather.days_running == 4:
		_note(Chronicle.Kind.TIERRA, weather.tell(), 1)


## Horas de reconocimiento que hacen falta para dar una comarca por vista.
##
## Una jornada util entera. Llegar a un sitio no es explorarlo: hay que subir
## al alto de al lado, bajar al arroyo, mirar si hay boca de cueva en el
## cortado. Eso lleva el dia.
const SURVEY_HOURS := 9.0

## Radio que se bate reconociendo, en metros. Bastante mas que forrajeando:
## aqui no se recoge nada, se mira.
const SURVEY_RADIUS := 260.0

## Cuanto sube la destreza de batida al dar con un material que no se sabia
## de un paraje. Es aprender por HITO y no por hora: encontrar algo deja mas
## poso que una hora mas de la misma rutina, y es lo unico que de verdad
## sube esta destreza -nadie la practica sentado, ver [Inhabitant.can_work].
const BATIDA_MATERIAL_MILESTONE := 0.02

## Cuanto sube al abrir un paraje que no existia, para quien lo haya batido
## -batida, expedicion o ascension de paso. El hito grande: no es acabar de
## conocer lo que ya se tenia, es encontrar un sitio nuevo.
const PARAJE_MILESTONE := 0.05

## Cuanto sube la expedicion al encontrar un vado nuevo: una forma de cruzar
## un rio que la banda no conocia. Ver `_terrain_speed`, que es donde se
## detecta el cruce de verdad.
const FORD_MILESTONE := 0.04

## Cuanto sube la ascension al coronar. Es siempre un pico NUEVO -ver
## `_already_climbed`- asi que no hace falta comprobarlo aparte: coronar YA
## es el hito. Ver `_try_ascent`.
const PEAK_MILESTONE := 0.06

## Salidas de HOY que han batido monte sin nombre -no un paraje ya
## conocido-, para poder premiar a quien de verdad lo ha abierto si al
## cerrar la jornada resulta que ahi se acaba de bautizar algo. Guarda
## tambien la especialidad, porque cada una aprende lo suyo. Se consume y se
## vacia en `_name_new_parajes`, una vez por jornada.
var _new_ground_surveys_today: Array[Dictionary] = []

## Vados ya conocidos, por celda gruesa: dan por buena la primera vez que
## alguien los cruza, y a partir de ahi ya no son un hallazgo. Ver
## `_terrain_speed` y `_ford_key`.
var _known_fords: Dictionary = {}

## El lado de la celda con la que se agrupan los vados, en metros. Mas
## grueso que la rejilla de navegacion a proposito: un vado es un tramo de
## rio, no un punto, y con una celda fina el mismo tramo saldria como
## «nuevo» tres veces por cruzarlo por sitios ligeramente distintos.
const FORD_CELL := 48.0

func _ford_key(point: Vector3) -> String:
	return "%d_%d" % [int(point.x / FORD_CELL), int(point.z / FORD_CELL)]


## Cuanto de un hito de exploracion (material, paraje o vado nuevo) le queda
## a la AGUDEZA en vez de a la destreza de la tarea. Es minusculo a
## proposito: el hito ensena mucho de la especialidad, y solo un poquito de
## ESPABILAR en general.
const AGUDEZA_MILESTONE_SHARE := 0.15


## Sube la destreza de una especialidad de EXPLORACION. Los hitos -material
## nuevo, paraje nuevo, vado nuevo- pasan por aqui y no por
## `skill_in`/`skill[]` a pelo, para que el techo y la velocidad por edad se
## apliquen siempre igual.
func _award_exploration_skill(person: Inhabitant,
		speciality: Profession.Speciality, amount: float) -> void:
	var task := Profession.task_id(Profession.Job.EXPLORACION, speciality)
	var current := person.skill_in(task)
	person.skill[task] = minf(current + amount * person.learn_rate(), 0.95)
	person.train_stat(Inhabitant.Stat.AGUDEZA, amount * AGUDEZA_MILESTONE_SHARE)


## Techos de la destreza de BATIDA segun COMO se gana. No es un tope unico:
## la petición literal es que sin hito de verdad no se pase de medio saber
## el oficio, y que abrir un paraje pese mucho mas que acabar de conocer uno
## que ya se tenia.
##
##   - Sola practica, sin encontrar nada: hasta 50.
##   - Dar con un material que faltaba en un paraje YA conocido: hasta 75.
##   - Abrir un paraje que no existia: hasta 95 -el techo de siempre-.
##
## Un batidor de sillon -que sale, mira y no encuentra nada nuevo nunca- se
## queda a medias para siempre. Eso es la intención, no un fallo de ajuste.
const BATIDA_REPETITION_CEILING := 0.50
const BATIDA_MATERIAL_CEILING := 0.75


## Sube la destreza de BATIDA sin pasar del techo que le toca a esta fuente
## de aprendizaje. Ver la nota de arriba para los tres techos.
func _grow_batida_skill(person: Inhabitant, amount: float, ceiling: float) -> void:
	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)
	var current := person.skill_in(task)
	if current >= ceiling:
		return
	person.skill[task] = minf(current + amount * person.learn_rate(), ceiling)
	person.train_stat(Inhabitant.Stat.AGUDEZA, amount * AGUDEZA_MILESTONE_SHARE)


## Batir la comarca adonde se mando mirar.
##
## Es lo que faltaba para que explorar signifique algo. Antes se pisaba el
## punto y la orden se daba por cumplida, que es marcar una casilla. Ahora se
## pasa la jornada dando vueltas por los alrededores, y lo que se descubre
## sale de haberlos andado.
## Cuanto sube la destreza de batida por hora de puro andar y mirar, sin dar
## con nada -tope BATIDA_REPETITION_CEILING. Minusculo a proposito: es la
## unica de las tres fuentes que no pide encontrar nada, asi que tiene que
## ser tambien la mas floja.
const BATIDA_REPETITION_RATE := 0.001


func _survey(person: Inhabitant, hours: float) -> void:
	person.survey_hours += hours
	var needed := _survey_hours_for(person)
	person.fatigue = clampf(
		person.fatigue + hours * 4.0 * person.fatigue_factor(), 0.0, 100.0)

	# Batir la comarca ES la enseñanza, no un aparte de ella: `_learn_from`
	# -que enseña el YENDO y el TRABAJANDO- no corre en RECONOCIENDO, así
	# que las horas de reconocimiento -que son la mayor parte del viaje de
	# una expedición- no enseñaban nada de nada. La familiaridad nunca
	# llegaba al umbral de nombrar un paraje nuevo por mucho que la banda
	# saliera a explorar: esto es lo que de verdad apagaba el descubrimiento.
	if knowledge:
		knowledge.see_from(person.position, sight_range * weather.sight_factor())
		var pace := hours / 24.0
		for activity: int in _activities_for_learning(person):
			knowledge.observe(activity as Subsistence.Activity, person.position, pace)

	if person.current_speciality == Profession.Speciality.BATIDA:
		_grow_batida_skill(person, hours * BATIDA_REPETITION_RATE,
			BATIDA_REPETITION_CEILING)

	if person.work_centre == Vector3.ZERO:
		person.work_centre = person.position

	# Se BATE la comarca: se da la vuelta al punto por tramos, subiendo al
	# alto de al lado, bajando al arroyo, mirando el cortado.
	#
	# Antes se quedaba clavado nueve horas y luego decia «explorado». Y el
	# fallo no era del sorteo del siguiente tramo sino de la ruta: al llegar
	# quedaba el camino del viaje a medio consumir, y `next_waypoint` devuelve
	# el hito del camino ANTES que el destino, asi que por mucho que se
	# cambiara el destino la persona seguia apuntando al sitio donde ya
	# estaba.
	var arrived := person.position.distance_to(person.forage_target) < arrive_radius
	if arrived or person.route_step >= person.route.size():
		_next_survey_leg(person)

	if person.survey_hours >= needed:
		_finish_survey(person)


## Se acabo el reconocimiento: se cuenta lo visto y se vuelve.
## Cuantos materiales como mucho se resuelven en una sola visita, por buena
## que sea la destreza. Sin tope, un batidor muy bueno vaciaba un paraje
## entero de una tarde: es descubrir DEMASIADO deprisa, y deja de sentirse
## como volver dia tras dia.
const MAX_REVEALS_PER_VISIT := 3

## Cuanto pesa la destreza en la probabilidad de encadenar otro hallazgo la
## misma tarde. Por debajo de 1 a proposito: con la destreza entera, hasta
## el mejor batidor encadena como mucho la mitad de las veces.
const CHAIN_REVEAL_FACTOR := 0.5


## Se acabo el reconocimiento: se cuenta lo visto y se vuelve.
func _finish_survey(person: Inhabitant) -> void:
	var where := parajes.place_name(person.work_centre, home_position)

	if has_scout_order:
		var flat := Vector2(person.work_centre.x - scout_order.x,
			person.work_centre.z - scout_order.z)
		if flat.length() < SCOUT_REACHED:
			has_scout_order = false

	var speciality := person.current_speciality as Profession.Speciality
	var is_batida := speciality == Profession.Speciality.BATIDA
	# La expedicion y la ascension caen aqui cuando NO estan resolviendo su
	# cosa propia -un frente lejano, un pico- sino batiendo terreno de paso:
	# abrir un paraje nuevo tambien les cuenta como hito.
	var opens_ground := speciality == Profession.Speciality.EXPEDICION \
		or speciality == Profession.Speciality.ASCENSION
	var batida_task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA)

	# Si se ha batido un paraje, la jornada resuelve una o mas incognitas,
	# hasta MAX_REVEALS_PER_VISIT. Cuantas depende de la destreza: un ojo
	# entrenado no se conforma con lo primero que ve, y esa misma destreza
	# sube por dar con algo NUEVO -no por las horas andadas, que esas ya se
	# cuentan aparte en `_survey`, con su propio techo bajo. Esto es cosa de
	# BATIDA: la expedicion no vuelve a un paraje a resolver lo que le
	# falta, eso es justo lo que distingue a las dos.
	var here := _paraje_at(person.work_centre)
	var discovered: Array[String] = []
	if here != null and here.has_unknowns():
		var reveals := 1
		while reveals > 0 and here.has_unknowns() \
				and discovered.size() < MAX_REVEALS_PER_VISIT:
			reveals -= 1
			var found_kind := here.reveal_one()
			if found_kind < 0:
				continue
			discovered.append(Materia.material_name(
				found_kind as Materia.Kind).to_lower())
			if is_batida:
				_grow_batida_skill(person, BATIDA_MATERIAL_MILESTONE,
					BATIDA_MATERIAL_CEILING)
				if _rng.randf() < person.skill_in(batida_task) * CHAIN_REVEAL_FACTOR:
					reveals += 1
	elif here == null:
		# Monte sin nombre. RECONOCER ES DESCUBRIR, y lo es para cualquiera.
		#
		# Esto sólo lo hacía la exploración, y el efecto era que un recolector
		# podía pasarse la vida trabajando un avellanar sin que el sitio llegara
		# a tener nombre nunca: la banda tenía que mandar aparte a un explorador
		# a "descubrir" un sitio en el que ya estaba trabajando. Ahora una
		# jornada entera batiendo un sitio nuevo basta para saber qué hay allí,
		# lo mismo que ya valía para el batidor.
		#
		# Lo que sigue distinguiendo al explorador es el ALCANCE de lo que
		# aprende: él abre el sitio para todos los oficios -para eso bate la
		# comarca entera- y los demás sólo para el suyo. Ver
		# `_activities_for_learning`.
		if knowledge:
			for activity: int in _activities_for_learning(person):
				knowledge.reveal(activity as Subsistence.Activity,
					person.work_centre, BandKnowledge.KNOWN_ENOUGH + 0.02)

		# El hito de exploración sí es sólo suyo: `_credit_new_ground` premia
		# destreza DE EXPLORACIÓN, y dársela a un recolector por recoger sería
		# pagarle dos veces por la misma jornada.
		if is_batida or opens_ground:
			_new_ground_surveys_today.append({"person": person,
				"position": person.work_centre, "speciality": speciality})

	# Que contar. Encontrar algo en un paraje manda siempre sobre el repaso
	# generico del terreno -"hay caza", "monte y piedra"-: una batida que
	# vuelve con novedades de verdad no puede leerse igual que una que no
	# encontro nada, ni en la cronica ni en el rastro.
	var outcome: String
	if not discovered.is_empty():
		outcome = "investig\u00f3 %s y encontr\u00f3 %s" % [where, ", ".join(discovered)]
		_note(Chronicle.Kind.HALLAZGO,
			"%s investig\u00f3 %s y encontr\u00f3 %s. Se sabe el %.0f%% de lo que hay."
				% [person.given_name, here.name_text, ", ".join(discovered),
					here.known_fraction() * 100.0], 1)
	else:
		var found: Array[String] = []
		if field:
			for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
					Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
					Subsistence.Activity.MATERIA_PRIMA]:
				var value := field.seasonal_abundance_at(
					activity as Subsistence.Activity, person.work_centre,
					GameState.season)
				if value > 0.45:
					found.append(Subsistence.activity_name(
						activity as Subsistence.Activity).to_lower())

		if found.is_empty():
			outcome = "poca cosa: monte y piedra"
			_note(Chronicle.Kind.HALLAZGO,
				"%s paso la jornada reconociendo %s. Poca cosa: monte y piedra."
					% [person.given_name, where], 1)
		else:
			outcome = "hay %s" % ", ".join(found)
			_note(Chronicle.Kind.HALLAZGO,
				"%s reconocio %s. Hay %s." % [person.given_name, where,
					", ".join(found)], 2)

	person.survey_hours = 0.0
	person.log_deed(person.current_task(), "comarca reconocida")
	person.end_journey(day, where, outcome)
	_send_to(person, home_position)
	person.state = Inhabitant.State.VOLVIENDO


## Intentar coronar. Con poca pericia, casi siempre se falla.
##
## Es la peticion literal: mandar a un novato a la peor cumbre de la comarca
## tiene que salir mal nueve de cada diez veces. Y coronar lo que esta a tu
## nivel tiene que salir bien casi siempre, o nadie sube nunca.
func _try_ascent(person: Inhabitant) -> void:
	var peak := peak_for(person)
	if peak.is_empty():
		return

	var task := Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.ASCENSION)
	var skill := person.skill_in(task)
	var hardness := float(peak["hard"])
	var odds := Ascent.chance(skill, hardness, weather.risk_factor(),
		person.fatigue)

	var where := parajes.place_name(person.position, home_position)
	person.fatigue = clampf(
		person.fatigue + 18.0 * person.fatigue_factor(), 0.0, 100.0)

	# Se aprende intentandolo, se corone o no: es lo que hace que valga la
	# pena mandar al novato a cumbres pequenas antes que a la grande
	person.skill[task] = minf(skill + 0.035 * person.learn_rate(), 0.95)

	if _rng.randf() > odds:
		var scale := _terrain.meters_per_unit 			/ maxf(_terrain.vertical_exaggeration, 0.001) if _terrain else 1.0
		var missing := int(float(peak["rise"]) * (1.0 - Ascent.reached(_rng)) * scale)
		_note(Chronicle.Kind.PENURIA,
			"%s no pudo con la cumbre %s. Se quedo a unos %d m del alto y "
				% [person.given_name, where, maxi(missing, 10)]
			+ "tuvo que bajar.", 1)
		person.end_journey(day, where,
			"NO corono: se quedo a %d m del alto" % maxi(missing, 10))
		return

	person.end_journey(day, where, "CORONADA (+%d m)" % int(_peak_rise(peak)))

	# El hito grande de la ascension: cada cumbre solo se ofrece una vez -ver
	# `_already_climbed`, que las saca de `peak_for`-, asi que coronar SIEMPRE
	# es abrir un pico que nadie habia pisado, no repetir el de ayer.
	_award_exploration_skill(person, Profession.Speciality.ASCENSION, PEAK_MILESTONE)

	_do_ascent(person)


## Si desde donde esta esta persona hay camino hasta ese punto.
##
## Se guarda el resultado por punto: preguntarlo es un A* completo, y sin
## cache preguntarlo por cada cumbre y cada persona hundiria el fotograma.
##
## Existe porque un explorador salia hacia una cumbre al otro lado de un rio
## infranqueable y se pasaba la partida intentandolo. Saber que NO se llega
## tiene que pasar antes de mandar a nadie, no despues.
var _grid: Navgrid = null

## Lo que costo construir la rejilla, en milisegundos. Lo lee la sonda: es el
## unico coste que queda, y conviene saber cuanto es de verdad.
var grid_build_ms: int = 0


## La celda gruesa de la cache. Si a un punto no se llega, a los de al lado
## tampoco: lo que corta el paso es un rio o un cortado, no un metro cuadrado.
func _reach_key(point: Vector3) -> String:
	return "%d_%d" % [int(point.x / 64.0), int(point.z / 64.0)]


## La rejilla de navegacion, construida a la primera y reusada siempre.
##
## Se rehace solo cuando la banda aprende a cruzar el agua: barca y puente
## cambian por donde se pasa, y una rejilla que no lo sabe deja medio mapa
## marcado como imposible para siempre.
func _navgrid() -> Navgrid:
	if _grid == null or not _grid.matches(has_boat, has_bridge):
		var started := Time.get_ticks_msec()
		_grid = Navgrid.from_terrain(_terrain, has_boat, has_bridge)
		grid_build_ms = Time.get_ticks_msec() - started
		# Los caminos de antes de la barca ya no son los mejores
		forget_routes()

		# Y la puerta de casa se anda SIEMPRE. Un abrigo se elige por ser
		# habitable, asi que si la medicion dice que su entrada esta cerrada,
		# la equivocada es la medicion: la banda entera quedaria en una celda
		# que no existe y no se le podria trazar nada.
		var freed := _grid.open_around_home(home_position, _terrain)
		if freed > 0:
			print("Navegacion: %d celdas abiertas a la fuerza junto al abrigo"
				% freed)

		# Se dice en voz alta porque una rejilla mal medida NO se ve: la gente
		# simplemente se queda en el campamento, y desde fuera parece que el
		# reparto de trabajo esta roto. Si «desde casa» sale bajo, el problema
		# es este fichero y no el que se este mirando.
		var home_cell := _grid.nearest_open(home_position)
		print("Navegacion: %d x %d celdas · transitable %.0f%% · zonas %d · %d ms"
			% [_grid.wide, _grid.tall, _grid.open_fraction() * 100.0,
				_grid.areas, grid_build_ms])
		if home_cell < 0:
			push_warning("El campamento no tiene suelo pisable cerca: "
				+ "nadie podra ir a ninguna parte.")
	return _grid


## Si esta persona puede llegar a un punto DESDE DONDE ESTA.
##
## Comprobarlo era lo mas caro del juego: para decir que NO se llega hay que
## agotar la busqueda entera. Ahora la rejilla trae las zonas comunicadas
## marcadas de antemano y esto son dos enteros.
func _reachable(person: Inhabitant, point: Vector3) -> bool:
	if _terrain == null:
		return true
	return _navgrid().connected(person.position, point)


## Cuantos tramos se andan reconociendo una comarca.
##
## Nueve horas dan para unas seis patas de trescientos metros con sus paradas.
## Menos se lee como estar quieto; mas, como dar vueltas sin sentido.
const SURVEY_LEGS := 6


## El siguiente tramo de la batida.
##
## Las direcciones se reparten en abanico alrededor del punto en vez de
## sortearse: sorteadas salian tres tramos seguidos hacia el mismo lado, que
## parece que la persona no sabe lo que hace. En abanico se ve que esta
## rodeando el sitio.
func _next_survey_leg(person: Inhabitant) -> void:
	for attempt in range(3):
		# Al trozo de alrededor que menos se conozca: reconocer es rellenar
		# los huecos del mapa, no dar vueltas por lo ya visto
		var candidate := _least_known_around(person.work_centre,
			SURVEY_RADIUS * 0.45, SURVEY_RADIUS, person)

		# El camino se traza de nuevo. Es lo que suelta el hito viejo que
		# tenia a la persona clavada donde llego: `next_waypoint` devuelve el
		# hito ANTES que el destino, asi que cambiar el destino no bastaba.
		person.route = PackedVector3Array()
		person.route_step = 0
		person.forage_target = candidate
		_send_to(person, candidate)

		if not person.route.is_empty() \
				or candidate.distance_to(person.position) < arrive_radius * 2.0:
			return

	# Si de verdad no hay por donde salir, se bate lo que se tenga a mano en
	# vez de quedarse mirando la nada
	var angle := _rng.randf() * TAU
	var near := person.position + Vector3(
		cos(angle) * arrive_radius * 2.5, 0.0, sin(angle) * arrive_radius * 2.5)
	if _terrain:
		near.y = _terrain.get_height_at(near)
	person.forage_target = near
	person.target = near


## Sitios de los que ya se ha dicho que no hay por donde llegar.
##
## La clave es la CELDA, no el punto: si a un punto no se llega, a los de al
## lado tampoco, y la cronica no tiene por que enterarse tres veces del mismo
## rio.
var _lamented: Dictionary = {}


## Contar que no hay camino, y contarlo UNA vez.
##
## Sin esto la cronica se llenaba: el bloque que reparte el trabajo corre cada
## pocos segundos, la persona vuelve a quedarse ociosa, se le vuelve a elegir
## el mismo destino imposible y se volvia a escribir el mismo parte. Y lo que
## se repite deja de leerse, que es lo peor que le puede pasar a un diario.
func _lament(person: Inhabitant, where: Vector3) -> void:
	var key := _reach_key(where)
	if _lamented.has(key):
		return
	_lamented[key] = true

	# Solo cuando el jugador HABIA mandado ir: que la banda descarte sola un
	# monte al otro lado del rio es su trabajo, no una noticia.
	if not has_scout_order:
		return

	_note(Chronicle.Kind.GENTE,
		"%s no encuentra por donde llegar %s. Hara falta cruzar el agua."
			% [person.given_name, parajes.place_name(where, home_position)], 1)


## Tope de comida guardada, en raciones. Cero es sin tope.
##
## Existe porque poner el tope material a material es un trabajo que el
## jugador no deberia tener: no le importa tener treinta bayas o veinte
## raices, le importa que la banda tenga comida de sobra y que la gente se
## dedique a otra cosa cuando la tenga.
##
## Y lo que para NO es la entrega: es la BUSQUEDA. Con la despensa llena nadie
## abre tajo nuevo, pero el que vuelve cargado entrega, y una pieza abatida se
## acaba de traer. Tirar carne para respetar un tope seria absurdo.
var food_cap: float = 0.0


## Hasta donde tiene que bajar la despensa para volver a salir a por comida,
## en tanto por uno del tope.
##
## Es una banda de histeresis, y hace falta porque el tope a secas producia
## esto -medido, sitio 56, tope de diez dias-:
##
##     dia  9  raciones 130,8 / 127  LLENO   a por comida  0 de 15
##     dia 10  raciones 111,2 / 127          a por comida  7 de 15
##     dia 11  raciones 134,9 / 127  LLENO   a por comida  0 de 15
##     dia 12  raciones 113,5 / 127          a por comida  7 de 15
##
## Siete personas fuera, cero al dia siguiente, siete otra vez. Palabras del
## jugador: «llegan al tope y no cogen mas, llega la noche, comen, baja del
## maximo y entonces vuelven a salir; es un circulo vicioso».
##
## Con la banda, al llegar al tope se deja de salir y no se vuelve hasta
## haberse comido un tercio de la despensa. Salen por tandas, que es como se
## hace: no se sube al monte a por la racion de hoy teniendo la despensa
## llena, se sube cuando se ve el fondo.
const REANUDAR_COMIDA := 0.65

## Si la despensa esta llena. Con memoria: ver [REANUDAR_COMIDA].
var _larder_full := false


## Si la despensa ha llegado al tope que puso el jugador.
func food_is_capped() -> bool:
	if food_cap <= 0.0:
		_larder_full = false
		return false
	var have := store.food_rations()
	if _larder_full:
		if have < food_cap * REANUDAR_COMIDA:
			_larder_full = false
	elif have >= food_cap:
		_larder_full = true
	return _larder_full


## Si este oficio existe para traer comida.
##
## La manufactura gasta materia prima y el hogar no sale del campamento: el
## tope no les toca. La exploracion tampoco, que no trae comida sino mapa.
func _feeds_the_band(job: Profession.Job) -> bool:
	return job == Profession.Job.CAZA or job == Profession.Job.RIBERA \
		or job == Profession.Job.RECOLECCION


## Cuantos dias de comida da el tope puesto, para poder decirselo al jugador
## en dias y no en raciones -que no significan nada solas-.
func food_cap_days() -> float:
	if food_cap <= 0.0:
		return 0.0
	var mouths := 0.0
	for person: Inhabitant in people:
		mouths += person.daily_food()
	return food_cap / maxf(mouths, 0.001)


## Caminos ya trazados, por par de celdas.
##
## Existe porque el patron de una partida es repetitivo hasta el aburrimiento:
## el abrigo, los tres tajos de la temporada y la vuelta. El primero que va
## paga la busqueda; los otros catorce, y el mismo manana, no pagan nada.
##
## La clave es la celda gruesa y no el punto exacto: dos personas que salen
## del abrigo con veinte metros de diferencia no necesitan dos caminos
## distintos, y exigir el punto exacto convertiria la cache en un adorno.
var _route_cache: Dictionary = {}
var _route_order: Array[String] = []

## Cuantos caminos se guardan. Doscientos cubren de sobra los trayectos de una
## temporada; guardarlos todos seria pagar memoria por rutas que no se van a
## repetir nunca.
const ROUTE_CACHE_LIMIT := 200

## Metros por celda de la cache. Mas gruesa que la de navegacion a proposito:
## lo que se quiere es que los quince del campamento compartan camino.
const LANE_CELL := 48.0


func _lane_key(from_point: Vector3, to_point: Vector3) -> String:
	return "%d_%d>%d_%d" % [
		int(from_point.x / LANE_CELL), int(from_point.z / LANE_CELL),
		int(to_point.x / LANE_CELL), int(to_point.z / LANE_CELL)]


func _remember_route(lane: String, route: PackedVector3Array) -> void:
	if not _route_cache.has(lane):
		_route_order.append(lane)
	_route_cache[lane] = route

	# Se suelta lo mas viejo. Sin tope, una partida larga se llena de rutas de
	# sitios donde la banda no ha vuelto a poner un pie.
	while _route_order.size() > ROUTE_CACHE_LIMIT:
		var oldest: String = _route_order[0]
		_route_order.remove_at(0)
		_route_cache.erase(oldest)


## El camino guardado, con el ultimo tramo llevado al destino exacto.
##
## El camino se guardo entre CELDAS, asi que su final es el centro de una
## celda y no el sitio al que va esta persona. Los tramos de en medio valen
## igual -son los mismos cuarenta metros de terreno-, pero el ultimo hay que
## rematarlo o se dejaria a la gente parada a veinte metros de su tajo.
func _retarget(route: PackedVector3Array, destination: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array(route)
	if out.is_empty():
		out.append(destination)
	else:
		out[out.size() - 1] = destination
	return out


## Se tiran los caminos guardados. Lo llama quien cambie el terreno o lo que
## se puede cruzar: un camino de antes del puente ya no es el mejor.
func forget_routes() -> void:
	_route_cache.clear()
	_route_order.clear()


## Como se llama lo que aparece en el libro de trabajo de una persona.
##
## Las piezas de utillaje se guardan con clave NEGATIVA para no chocar con los
## materiales, que empiezan en cero como ellas. Aqui se deshace.
static func logged_name(key: int) -> String:
	if key < 0:
		return Tool.kind_name((-1 - key) as Tool.Kind)
	return Materia.material_name(key as Materia.Kind)


## Cuanto se levanta una cumbre sobre el valle, en metros de verdad.
func _peak_rise(peak: Dictionary) -> float:
	if _terrain == null:
		return float(peak.get("rise", 0.0))
	return float(peak.get("rise", 0.0)) * _terrain.meters_per_unit \
		/ maxf(_terrain.vertical_exaggeration, 0.001)


## Cuanto dura un reconocimiento, segun de que salida sea.
##
## La batida es radio corto y vuelve a dormir a casa, asi que no le caben
## nueve horas de reconocimiento: se le acababa el dia a medio batir, no
## terminaba nunca y por eso no aparecia ni una sola batida en los rastros.
## Media jornada es lo que de verdad cabe entre salir despues del desayuno y
## volver antes de que oscurezca.
func _survey_hours_for(person: Inhabitant) -> float:
	if person.current_speciality == Profession.Speciality.BATIDA:
		return SURVEY_HOURS * 0.45

	# Abrir monte nuevo es asomarse a ver que hay, no trabajar a fondo un
	# paraje que ya se conoce y del que quedan incognitas por resolver
	# -eso es justo lo que distingue a la batida-. Exigir la jornada
	# entera para las dos cosas por igual era pedirle a una expedicion el
	# mismo tiempo por mirar de pasada que por investigar en detalle, y
	# entre eso y la logistica de varios dias fuera, terminar de reconocer
	# terreno nuevo se volvia raro: casi ninguna salida llegaba a tiempo.
	if _paraje_at(person.work_centre) == null:
		return SURVEY_HOURS * 0.5
	return SURVEY_HOURS


## Semilla de esta partida. Se imprime al empezar para poder repetirla.
var game_seed: int = 0


## Horas quieto a partir de las cuales se da por plantado a alguien.
##
## Dos. Una parada de mediodia dura menos, y un tajo de recoleccion mueve a la
## persona cada pocos minutos, asi que dos horas sin moverse yendo a algun
## sitio no es descanso: es que se ha quedado enganchado.
const STUCK_HOURS := 2.0

## Cuanto hay que moverse para no contar como plantado, en metros.
const STUCK_SLACK := 12.0


## Saca de la parálisis a quien lleve horas sin moverse.
##
## Es una red de seguridad, no un diagnostico, y se pone porque los motivos
## por los que alguien se queda clavado son muchos y van saliendo de uno en
## uno: una ruta que se vacia, un destino que deja de ser alcanzable, una
## pared que el andador no cruza aunque el planificador dijera que si. Lo que
## NO puede pasar es que el jugador vea a alguien dos dias parado en un monte
## sin que el juego se entere.
##
## Se anota en la cronica a proposito. Un remiendo silencioso esconde el fallo
## que hay debajo; uno que se cuenta deja el rastro para arreglarlo.
func _watch_for_stuck(person: Inhabitant, hours: float) -> void:
	# SOLO yendo, volviendo y reconociendo. Prospectar un paraje es quedarse
	# quieto mirando el suelo durante horas, y eso es el trabajo, no una
	# averia. Reconocer una comarca, en cambio, es andarla.
	var busy := person.state == Inhabitant.State.YENDO \
		or person.state == Inhabitant.State.VOLVIENDO \
		or person.state == Inhabitant.State.RECONOCIENDO
	if not busy:
		person.stuck_hours = 0.0
		person.stuck_where = person.position
		return

	# Estar quieto AL LADO de donde ibas no es estar atascado: es haber
	# llegado y que el estado no se haya enterado. El remedio es otro.
	var arrived := person.position.distance_to(person.target) < arrive_radius * 1.5

	# QUIEN SE MUEVE NO ESTÁ ATASCADO. Punto, y sin mirar dónde está.
	#
	# Aquí ponía `and not arrived`, y eso convertía «andar cerca de tu destino»
	# en «estar plantado»: al acercarse a menos de nueve metros del tajo el
	# reloj de atasco dejaba de reiniciarse aunque la persona siguiera andando,
	# y a las dos horas se la daba por enganchada. Si para entonces se había
	# separado un poco del punto —cosa que pasa sola, porque el destino se
	# recalcula— ni siquiera entraba por la rama buena: salía por la de
	# «no avanza por el camino trazado», se cerraba la salida como atasco y se
	# la mandaba a casa.
	#
	# Lo pagaba sobre todo la CAZA MENOR, que es la que más ronda su tajo:
	# medido en el sitio 56, 72 atascos en tres jornadas y CERO ticks en los que
	# alguien estuviera de verdad parado. Se veía en la ventana de rastros como
	# una columna entera de salidas cerradas con «atascado» sin que ninguna lo
	# estuviera.
	#
	# El caso que `arrived` venía a resolver -llegar y que el estado no se
	# entere- sigue saliendo por su rama: quien ha llegado y no se mueve tampoco
	# supera `STUCK_SLACK`, así que el reloj corre igual y lo recoge abajo.
	if person.position.distance_to(person.stuck_where) > STUCK_SLACK:
		person.stuck_hours = 0.0
		person.stuck_where = person.position
		return

	person.stuck_hours += hours
	if person.stuck_hours < STUCK_HOURS:
		return
	person.stuck_hours = 0.0
	person.stuck_where = person.position

	# LLEGO y el estado no se entero. Es el caso mas comun de todos -medido:
	# dieciocho de treinta y uno- y no tiene nada que ver con el terreno: la
	# persona esta encima de su destino, la ruta se ha acabado, y sigue en
	# «yendo» porque la transicion de llegada vive en un bloque de la jornada
	# que a esa hora no corre.
	#
	# Se suelta y se le vuelve a repartir trabajo, que es lo que tenia que
	# haber pasado solo. No va a la cronica -no es una noticia, es una
	# costura- pero SI a la cuenta, porque veinte de estos son un fallo con
	# nombre y hay que poder verlo.
	if arrived:
		stuck_tally[LLEGADA_COLGADA] = int(stuck_tally.get(LLEGADA_COLGADA, 0)) + 1
		_record_stuck(person, LLEGADA_COLGADA)
		person.route = PackedVector3Array()
		person.route_step = 0
		person.state = Inhabitant.State.OCIOSO
		return

	# Metido donde no se pisa: de ahi no se sale con un camino, porque
	# cualquier camino empieza en una celda que no existe. Se le saca al suelo
	# firme mas cercano y ya andara desde ahi.
	var grid := _navgrid()
	if not grid.passable(person.position):
		var open_cell := grid.nearest_open(person.position)
		if open_cell >= 0:
			stuck_tally[SUELO_MALO] = int(stuck_tally.get(SUELO_MALO, 0)) + 1
			_record_stuck(person, SUELO_MALO)
			var firm := grid.point_of(open_cell)
			firm.y = _terrain.get_height_at(firm)
			person.position = firm
			person.route = PackedVector3Array()
			person.route_step = 0
			person.state = Inhabitant.State.OCIOSO
			return

	# Al lado de casa: el estado se ha quedado colgado y ya esta. Se corrige y
	# NO se cuenta.
	#
	# Contarlo llenaba la cronica de «llevaba horas plantado a 6 m del
	# abrigo» -once avisos el primer dia- y eso no es informar: es tapar con
	# ruido las dos lineas que si importaban.
	if _home_reached(person):
		_deliver(person)
		person.route = PackedVector3Array()
		person.route_step = 0
		person.state = Inhabitant.State.OCIOSO
		return

	# Lejos y sin poder seguir: eso si es noticia, y una vez al dia por
	# persona. Se anota a proposito: un remiendo silencioso esconde el fallo
	# que hay debajo; uno que se cuenta deja el rastro para arreglarlo.
	var why := _stuck_reason(person)
	stuck_tally[why] = int(stuck_tally.get(why, 0)) + 1
	_record_stuck(person, why)

	if person.stuck_told != day:
		person.stuck_told = day
		_note(Chronicle.Kind.GENTE,
			'%s se quedo atascado %s: %s. Vuelve al abrigo.'
				% [person.given_name,
					parajes.place_name(person.position, home_position), why], 0)

	if not person.journey.is_empty():
		person.end_journey(day,
			parajes.place_name(person.position, home_position),
			'atascado: %s' % why)

	person.route = PackedVector3Array()
	person.route_step = 0
	person.survey_hours = 0.0
	person.unreachable = person.target
	_send_to(person, home_position)
	person.state = Inhabitant.State.VOLVIENDO if not person.route.is_empty() \
		else Inhabitant.State.OCIOSO


## Lo que trae encima quien vuelve, dicho en una linea.
##
## Es lo que convierte una linea de rastro en algo que se lee: «4,2 km · trajo
## 14 fruto seco, 3 lena» responde de un vistazo si la jornada valio la pena, y
## «volvio de vacio» tambien responde, que es lo importante.
func _brought_text(person: Inhabitant) -> String:
	# Media unidad de corte era una mentira: una jornada que trae 0,3
	# raciones se contaba como «volvio de vacio», y con los rendimientos de
	# principio de partida ESO ES CASI TODAS. El jugador leia el rastro
	# entero lleno de salidas fallidas cuando lo que pasaba es que traian
	# poco. Poco no es nada, y se dice distinto.
	var parts: Array[String] = []
	for kind: int in person.load.keys():
		var units: float = person.load[kind]
		if units < 0.05:
			continue
		var name := Materia.material_name(kind as Materia.Kind).to_lower()
		if units < 0.95:
			parts.append("algo de %s" % name)
		else:
			parts.append("%.0f %s" % [units, name])
	if parts.is_empty():
		return "volvio de vacio"
	return "trajo %s" % ", ".join(parts)


## Si ya se ha contado que la comarca esta reconocida entera.
##
## Una vez y no mas: es un hito, y un hito repetido deja de ser un hito.
var _comarca_known: bool = false

## Y si ya se ha contado que no queda cumbre por coronar.
var _peaks_done: bool = false


## Si al taller le falta materia prima para lo que toca hacer.
##
## Es la unica razon por la que un artesano sale del abrigo. Mientras haya de
## que, se trabaja dentro: el taller es un sitio, no una ruta.
func _workshop_short(person: Inhabitant) -> bool:
	var speciality := person.current_speciality as Profession.Speciality
	var kind := _next_piece(speciality)
	if kind < 0:
		return false

	for material: int in Tool.recipe(kind as Tool.Kind):
		var wanted: float = float(Tool.recipe(kind as Tool.Kind)[material])
		# El silex vale por la piedra: si hay de uno, no falta el otro
		if material == Materia.Kind.PIEDRA \
				and store.amount(Materia.Kind.SILEX) >= wanted:
			continue
		if store.amount(material as Materia.Kind) < wanted * WORKSHOP_RESERVE:
			return true
	return false


## Cuantas piezas de reserva de materia prima quiere tener el taller.
##
## Tres. Con una sola, el artesano saldria a por material cada dos dias y se
## pasaria la vida andando; con muchas mas, no saldria nunca y el taller se
## pararia en seco el dia que se acabase.
const WORKSHOP_RESERVE := 3.0


## Cuantos pasos seguidos contra un obstaculo antes de volver a trazar.
##
## Treinta: medio segundo de reloj. Bastantes para que un roce con la orilla
## se resuelva solo con el esquive -que para eso esta- y pocos para que nadie
## se pase la jornada empujando una pared.
const BLOCKED_BEFORE_REPLAN := 30

## A qué distancia de un sitio que se dio por imposible sigue contando como el
## mismo sitio. Un cotarro mide decenas de metros: cien es «el de detrás del
## cortado», no «el de al lado».
const UNREACHABLE_SLACK := 100.0


## Cuántas veces se vuelve a trazar contra la misma pared antes de rendirse.
##
## Tres. Con una o dos se abandonaría un destino por un roce con la orilla que
## el esquive habría resuelto solo; con más, la tarde se va en intentarlo.
const BLOCKED_REPLANS := 3


## Cuantas veces se ha quedado alguien atascado por cada motivo.
##
## Se lleva la cuenta a proposito y no solo el aviso suelto: un atasco es una
## anecdota, veinte del mismo motivo son un fallo con nombre. Lo lee el panel
## de rastros.
var stuck_tally: Dictionary = {}


## Por que no puede seguir esta persona.
##
## No es adorno. «Se quedo atascado» sin mas es exactamente lo que no sirve:
## deja al jugador con la sospecha y a mi sin el dato. Cada motivo de estos
## apunta a una pieza distinta del juego, y se distinguen mirando.
func _stuck_reason(person: Inhabitant) -> String:
	if _terrain == null:
		return "sin terreno"

	var grid := _navgrid()

	# 1. El destino esta en otra zona del mapa: no hay camino y no lo habra
	if not grid.connected(person.position, person.target):
		return "no hay paso hasta alli"

	# 2. Esta parado ENCIMA de algo que no se pisa. Pasa cuando el terreno
	#    cambia bajo los pies -o cuando alguien acaba metido en un cauce- y es
	#    el peor caso, porque desde ahi no se puede ni salir andando.
	if not grid.passable(person.position):
		return "metido donde no se pisa"

	# 3. Tiene camino pero no avanza: hay algo delante que el andador no cruza
	#    aunque el planificador dijera que si
	if not person.route.is_empty():
		var next_point := person.next_waypoint()
		if not _can_step_into(next_point):
			return "algo cortando el paso"
		return "no avanza por el camino trazado"

	# 4. Sin camino y sin destino imposible: la traza fallo por presupuesto
	return "se quedo sin camino trazado"


## Los dos motivos de atasco que NO son del terreno, con nombre fijo para
## poder contarlos.
const LLEGADA_COLGADA := "llego y el estado no se entero"
const SUELO_MALO := "estaba metido donde no se pisa"


## Cuantas cargas se han perdido por salir de nuevo sin haber entregado.
##
## Deberia quedarse en cero. Si sube, alguien esta acabando la jornada lejos
## del abrigo y volviendo a salir sin pasar por casa.
var lost_loads: int = 0


## El paraje a medio investigar mas conveniente para una batida.
##
## Se prefiere el que MENOS se sepa y mas cerca este, en ese orden: acabar de
## conocer un sitio a doscientos metros vale mas que empezar a conocer otro a
## dos kilometros, porque el de al lado es al que se va a volver a diario.
##
## Devuelve null si no queda ninguno con incognitas.
func _paraje_to_survey(person: Inhabitant) -> Paraje:
	if parajes == null:
		return null

	var best: Paraje = null
	var best_score := -INF
	for paraje: Paraje in parajes.list:
		if not paraje.has_unknowns():
			continue
		if not _navgrid().connected(person.position, paraje.position):
			continue
		# Adonde ya va otro, no se va: la batida es cosa de uno, y dos
		# batidores resolviendo la misma incognita es una jornada tirada.
		# Se mira `_exploration_anchor` y no `target` a pelo: en cuanto el
		# primero llega y se pone a reconocer, su `target` empieza a
		# alejarse del paraje -tramo a tramo, hasta 260 m- y comparar solo
		# eso dejaba de detectar que el sitio ya estaba ocupado justo
		# cuando mas hacia falta saberlo.
		var taken := false
		for other: Inhabitant in people:
			if other != person and other.job == Profession.Job.EXPLORACION \
					and _exploration_anchor(other).distance_to(paraje.position) < 120.0:
				taken = true
				break
		if taken:
			continue

		var away := paraje.distance_from(home_position)
		var score := (1.0 - paraje.known_fraction()) - away / 4000.0
		if score > best_score:
			best_score = score
			best = paraje
	return best


## El paraje que hay en un punto, si lo hay.
func _paraje_at(point: Vector3) -> Paraje:
	if parajes == null:
		return null
	for paraje: Paraje in parajes.list:
		if paraje.position.distance_to(point) < paraje.extent:
			return paraje
	return null


## Lo que rinde una JORNADA COMPLETA de cada especialidad.
##
## Es donde vive de verdad la diferencia entre hermanas. La trampa y la caza
## mayor tocan el mismo monte y el mismo bicho, pero una trae media pieza sin
## fallar nunca y la otra trae una res entera cuando sale: si las dos dieran
## lo mismo, elegir seria decorado.
##
## Vacio quiere decir «lo que diga la actividad», que es lo que pasa con las
## especialidades de taller y de exploracion: esas no recogen nada del monte.
const SPECIALITY_YIELDS := {
	# --- recoleccion ---------------------------------------------------
	Profession.Speciality.FORRAJEO: {
		Materia.Kind.FRUTO_SECO: 5.2, Materia.Kind.RAIZ: 4.6,
		Materia.Kind.BAYA: 3.0, Materia.Kind.SETA: 1.2,
		Materia.Kind.HUEVO: 0.7, Materia.Kind.CARACOL: 1.4,
		# Miel y bellota SI tienen su buena cosecha propia en
		# `_gathering_yields` -verano y otoño-, pero fuera de esa
		# temporada no aparecian en NINGUNA tabla, y un paraje que las
		# enseñara como extra se quedaba sin cifra el resto del año.
		# Esta es la baja de fondo -lo que se encuentra rebuscando, no
		# la cosecha grande-, y no depende de la estacion.
		Materia.Kind.MIEL: 0.5, Materia.Kind.BELLOTA: 2.0,
	},
	Profession.Speciality.LENA_FIBRA: {
		Materia.Kind.LENA: 7.0, Materia.Kind.FIBRA: 5.5,
		Materia.Kind.YESCA: 1.8, Materia.Kind.CORTEZA: 2.2,
		Materia.Kind.RESINA: 0.8,
	},
	Profession.Speciality.CANTERA: {
		Materia.Kind.PIEDRA: 13.0, Materia.Kind.OCRE: 0.8,
		Materia.Kind.SILEX: 4.0,
	},

	# --- caza ------------------------------------------------------------
	# La trampa trabaja sola: se pone y se recoge. Poca carne, sin riesgo y
	# sin necesidad de azagaya.
	Profession.Speciality.TRAMPAS: {
		Materia.Kind.CARNE: 11.0, Materia.Kind.PIEL: 0.7,
		Materia.Kind.HUESO: 0.6, Materia.Kind.TENDON: 0.4,
	},
	Profession.Speciality.CAZA_MENOR: {
		Materia.Kind.CARNE: 22.0, Materia.Kind.PIEL: 0.9,
		Materia.Kind.HUESO: 1.4, Materia.Kind.TENDON: 0.8,
		Materia.Kind.GRASA: 0.6,
	},
	# La res entera: es el golpe grande, y lo que trae de una vez no es solo
	# comida sino la materia prima de medio taller
	Profession.Speciality.CAZA_MAYOR: {
		Materia.Kind.CARNE: 62.0, Materia.Kind.PIEL: 1.8,
		Materia.Kind.HUESO: 5.4, Materia.Kind.TENDON: 2.8,
		Materia.Kind.GRASA: 4.2, Materia.Kind.ASTA: 0.9,
	},

	# --- ribera ----------------------------------------------------------
	Profession.Speciality.MARISQUEO: {
		Materia.Kind.MARISCO: 26.0, Materia.Kind.CONCHA: 2.0,
	},
	Profession.Speciality.ORILLA: {
		Materia.Kind.PESCADO: 42.0,
	},
	Profession.Speciality.ALTURA: {
		Materia.Kind.PESCADO: 95.0, Materia.Kind.GRASA: 3.0,
	},
}


## El utillaje que pide cada especialidad.
##
## Es la otra mitad de lo que las distingue. La trampa no pide filo -pide
## cordel, y eso ya lo cobra el taller-, y la caza mayor sin azagaya no es
## caza mayor: es mirar pasar al ciervo.
const SPECIALITY_TOOL := {
	Profession.Speciality.FORRAJEO: Tool.Kind.CESTO,
	Profession.Speciality.CANTERA: Tool.Kind.LASCA,
	Profession.Speciality.CAZA_MENOR: Tool.Kind.AZAGAYA,
	Profession.Speciality.CAZA_MAYOR: Tool.Kind.AZAGAYA,
	Profession.Speciality.MARISQUEO: Tool.Kind.CESTO,
	Profession.Speciality.ORILLA: Tool.Kind.ARPON,
	Profession.Speciality.ALTURA: Tool.Kind.ARPON,
}


## Lo que rinde esta persona hoy: por especialidad si la tiene, y si no por la
## actividad de su oficio.
## Lo que la banda sabe hacer. Lo pone DemoMain al montar la partida.
##
## La simulacion lo consulta de verdad y no solo la ficha: es lo que decide
## con que se pesca hoy -ver [Fishing]-, y sin el solo se pesca a mano.
## El árbol de técnicas. Al enganchárselo se le pasa el estado del campamento:
## la piragua y el arte parietal dependen de que HAYA HOGAR, no de haber
## descubierto el fuego. Ver [TechTree].
var techs: TechTree = null:
	set(value):
		techs = value
		if techs != null:
			techs.camp_built = camp_built


## Con que se esta pescando ahora mismo.
##
## No es la mejor manera que la banda sepa: es la mejor que puede hacer HOY.
## Se sabe la red y se han roto todas, se pesca con arpon; se sabe el sedal y
## no hay caracol de cebo, se pesca con nasa. Bajar un escalon es lo que se
## hace de verdad cuando falta el aparejo bueno.
func fishing_method() -> int:
	return Fishing.best_for(techs, toolkit, store,
		workers_in(Subsistence.Activity.PESCA))


func _yields_for(person: Inhabitant) -> Dictionary:
	var speciality := person.current_speciality as Profession.Speciality
	# La pesca no tiene UNA tabla: tiene una por cada forma de pescar, y cual
	# toca depende de lo que se sepa, de lo que haya en el abrigo y de cuanta
	# gente este en el agua a la vez.
	if speciality == Profession.Speciality.ORILLA:
		return Fishing.yields_of(fishing_method() as Fishing.Method)

	# La caza tampoco tiene UNA tabla: tiene la PIEZA. Lo que se cobra sale de
	# que animales de su porte andan por ese sitio en esta estacion y de como
	# se despieza cada uno, no de una lista escrita a mano. Por eso un cotarro
	# de aves da plumas y no piel, y por eso la tecnica se nota: un cazador
	# con propulsor no encuentra ciervos donde no los hay, cobra mas de los
	# que encuentra.
	if speciality == Profession.Speciality.CAZA_MENOR 			or speciality == Profession.Speciality.CAZA_MAYOR:
		return Hunting.yields_at(speciality, person.work_centre,
			GameState.season as Subsistence.Season, techs)
	if SPECIALITY_YIELDS.has(speciality):
		return SPECIALITY_YIELDS[speciality]
	return _yield_materials(person.activity)


## Y el utillaje que pide, por el mismo criterio.
func _tool_for(person: Inhabitant) -> int:
	var speciality := person.current_speciality as Profession.Speciality
	if speciality == Profession.Speciality.ORILLA:
		# El aparejo lo pone la forma de pescar, no la especialidad: a mano y
		# con pesquera no se gasta ninguna pieza.
		return Fishing.tool_of(fishing_method() as Fishing.Method)
	if SPECIALITY_TOOL.has(speciality):
		return int(SPECIALITY_TOOL[speciality])
	return activity_tool(person.activity)


## Los primeros atascos, con TODO el contexto.
##
## Existe para poder contestar «por que se traba» con datos y no con una
## teoria. Un motivo resumido -«no avanza por el camino trazado»- dice que
## sintoma tiene, no que le pasa: hace falta saber donde estaba, adonde iba,
## que llevaba trazado y como estaba el suelo debajo.
var stuck_reports: Array[Dictionary] = []

## Cuantos se guardan. Veinte llegan de sobra para ver el patron; guardar
## todos seria memoria por nada.
const STUCK_REPORTS := 20


func _record_stuck(person: Inhabitant, why: String) -> void:
	if stuck_reports.size() >= STUCK_REPORTS or _terrain == null:
		return

	var grid := _navgrid()
	var here := grid.cell_of(person.position)
	var goal := grid.cell_of(person.target)
	var waypoint := person.next_waypoint()

	stuck_reports.append({
		"dia": day,
		"hora": hour,
		"quien": person.given_name,
		"motivo": why,
		"estado": int(person.state),
		"oficio": Profession.job_name(person.job as Profession.Job),
		"donde": person.position,
		"adonde": person.target,
		"lejos_destino": person.position.distance_to(person.target),
		"lejos_casa": person.position.distance_to(home_position),
		"hitos": person.route.size(),
		"hito_actual": person.route_step,
		"lejos_hito": person.position.distance_to(waypoint),
		# El suelo, visto por los dos que tienen que estar de acuerdo
		"celda_pisable": grid.cost[here] > Navgrid.BLOCKED,
		"destino_pisable": grid.cost[goal] > Navgrid.BLOCKED,
		"hito_pisable": grid.passable(waypoint),
		"anda_al_hito": _can_step_into(waypoint),
		"zona_aqui": grid.area[here],
		"zona_destino": grid.area[goal],
		"pendiente": _terrain.get_slope_at(person.position),
		"vado": _terrain.crossing_difficulty_at(person.position),
		# Y las dos que de verdad dicen por qué no se mueve: cuántas veces se
		# le ha cortado el paso y a qué velocidad anda. Sin ellas, «no avanza
		# por el camino trazado» describe el síntoma y nada más.
		"bloqueos": person.blocked_steps,
		"paso": _terrain_speed(person,
			(waypoint - person.position).normalized()) / maxf(walk_speed, 0.001),
	})


## El informe forense, en texto.
func stuck_report_text() -> String:
	var lines: Array[String] = []
	for report: Dictionary in stuck_reports:
		lines.append(("d%d %05.2fh %-6s %-12s | %s" % [
			int(report["dia"]), float(report["hora"]), String(report["quien"]),
			String(report["oficio"]), String(report["motivo"])]))
		lines.append("      de (%d,%d) a (%d,%d) · %d m del destino · %d m de casa" % [
			int((report["donde"] as Vector3).x), int((report["donde"] as Vector3).z),
			int((report["adonde"] as Vector3).x), int((report["adonde"] as Vector3).z),
			int(report["lejos_destino"]), int(report["lejos_casa"])])
		lines.append("      camino %d hitos, va por el %d, el siguiente a %d m" % [
			int(report["hitos"]), int(report["hito_actual"]),
			int(report["lejos_hito"])])
		lines.append("      suelo: aqui %s · destino %s · hito %s · el andador pasa: %s" % [
			"pisable" if bool(report["celda_pisable"]) else "CERRADO",
			"pisable" if bool(report["destino_pisable"]) else "CERRADO",
			"pisable" if bool(report["hito_pisable"]) else "CERRADO",
			"si" if bool(report["anda_al_hito"]) else "NO"])
		# El ESTADO va en el parte y no salia impreso, y es la mitad de la
		# respuesta: «llego y el estado no se entero» no dice lo mismo si el
		# estado es «de camino» -no vio su tajo- que si es «volviendo» -no vio
		# su abrigo-.
		lines.append("      estado %s · hora %s" % [
			Inhabitant.new_state_name(int(report["estado"])),
			"de vuelta" if float(report["hora"]) >= HORA_REGRESO else "de jornada"])
		lines.append("      bloqueos %d · paso %.3f de lo normal" % [
			int(report.get("bloqueos", 0)), float(report.get("paso", 1.0))])
		lines.append("      zona %d -> %d · pendiente %.2f · vado %.2f" % [
			int(report["zona_aqui"]), int(report["zona_destino"]),
			float(report["pendiente"]), float(report["vado"])])
	return "\n".join(lines)


## El punto pisable mas cercano a otro.
##
## Es la contrapartida obligatoria de que mande la rejilla: si nadie puede
## PISAR una celda cerrada, un tajo que caiga en una se vuelve inalcanzable, y
## la banda perderia parajes buenos por un metro de rio. Amarrandolo a la
## orilla abierta de al lado se trabaja igual y se llega siempre.
func _firm_ground(point: Vector3) -> Vector3:
	var grid := _navgrid()
	if not grid.is_ready():
		return point
	if grid.cost[grid.cell_of(point)] > Navgrid.BLOCKED:
		return point

	var cell := grid.nearest_open(point, 4)
	if cell < 0:
		return point
	var firm := grid.point_of(cell)
	if _terrain:
		firm.y = _terrain.get_height_at(firm)
	return firm


# ------------------------------------------------------------- trampas ---
#
# La trampa es el único trabajo de la banda que rinde MIENTRAS SE HACE OTRA
# COSA. Se arma una vez —cuesta materiales y jornadas de brazo— y a partir de
# ahí cobra sola: el trampero solo tiene que ir a levantarla. Eso la hace
# distinta de todo lo demás: no es una jornada por pieza, es una inversión.

## Las trampas puestas en el monte, con su sitio y su estado.
var traps: Array[Trap] = []

## Las armadas hoy, para que la crónica pueda contarlas y luego se limpia.
var traps_set_today: Array[Trap] = []

## Las que hoy han quedado inservibles.
var traps_lost_today: Array[Trap] = []

## Cuántas trampas mantiene puestas cada trampero. Más no es mejor: hay que
## ir a levantarlas todas, y una línea demasiado larga se recorre a medias.
const TRAMPAS_POR_TRAMPERO := 5

## A qué distancia se levanta una trampa sin desviarse: si está más lejos, se
## va a por ella; si está a mano, se recoge de paso.
## A que distancia se levanta una trampa. Amplio a proposito: el trampero
## llega al paraje, no a la estaca, y `_forage_drift` lo mueve por la mancha
## mientras trabaja. Con setenta metros medidos, dos tramperos con la linea
## puesta levantaron DOS piezas en sesenta dias: iban y volvian sin llegar a
## tocarla.
const ALCANCE_TRAMPA := 160.0

## Lo cerca que pueden estar dos trampas. Una línea de trampas es una LÍNEA:
## amontonarlas en el mismo claro no coge más, coge lo mismo repartido.
## Medido: con noventa metros, dos tramperos con sitio para ocho trampas
## mantenian DOS, amontonadas en el mismo claro. La deriva de trabajo mueve a
## la gente unos cincuenta metros, asi que noventa era una separacion que
## nadie alcanzaba andando por su tajo.
const SEPARACION_TRAMPAS := 60.0


## Cuántas trampas caben, por la gente que hay puesta a ello.
func trap_allowance() -> int:
	var trappers := 0
	for person: Inhabitant in people:
		if person.current_speciality == Profession.Speciality.TRAMPAS:
			trappers += 1
	return maxi(trappers, 1) * TRAMPAS_POR_TRAMPERO


## Los tipos de trampa que la banda sabe armar hoy, de la mejor a la peor.
func known_traps() -> Array[int]:
	var out: Array[int] = []
	for kind: int in Trap.INFO:
		var tech := Trap.tech_of(kind as Trap.Kind)
		if tech >= 0 and (techs == null or not techs.has(tech as TechTree.Tech)):
			continue
		out.append(kind)
	# La que más raciones da por pieza, primero: es la que interesa poner
	# cuando hay materiales para elegir.
	out.sort_custom(func(a: int, b: int) -> bool:
		return Trap.typical_rations(a as Trap.Kind) \
			> Trap.typical_rations(b as Trap.Kind))
	return out


## La trampa que toca armar aquí: la mejor que se sepa y se pueda pagar. -1 si
## ninguna.
##
## Se mira que de verdad coja algo de lo que anda por este punto: poner un
## foso donde solo hay perdices es tirar seis de leña.
func _trap_to_set(point: Vector3) -> int:
	var here := Fauna.species_at(point, GameState.season as Subsistence.Season)
	var fallback := -1
	for kind: int in known_traps():
		if not _can_afford(Trap.materials(kind as Trap.Kind)):
			continue
		if fallback < 0:
			fallback = kind
		for species: String in Trap.catches(kind as Trap.Kind):
			if here.has(species):
				return kind
	return fallback


func _can_afford(recipe: Dictionary) -> bool:
	for material: int in recipe:
		if store.amount(material as Materia.Kind) < float(recipe[material]):
			return false
	return true


## Si en este punto cabe una trampa más: ni encima de otra, ni pasándose del
## número que la banda puede recorrer.
func _room_for_trap(point: Vector3) -> bool:
	if traps.size() >= trap_allowance():
		return false
	for trap: Trap in traps:
		var flat := Vector2(point.x - trap.position.x, point.z - trap.position.z)
		if flat.length() < SEPARACION_TRAMPAS:
			return false
	return true


## Cuanto vale un sitio para ESTA rama de la caza. Uno para lo que no es
## caza, que no distingue especies.
##
## No es un ajuste fino: es la diferencia entre encontrar la pieza y no
## encontrarla. Un cotarro sin nada de su porte se descuenta fuerte, y uno
## que la tiene sube, para que la cuadrilla de caza mayor se vaya de verdad
## adonde estan los ciervos aunque haya mas roce de animales en otra ladera.
## Con cuanto se compara: un sitio que diera estas raciones por jornada
## perfecta ni sube ni baja la puntuacion. Por encima suma, por debajo resta.
const CAZA_DE_REFERENCIA := 14.0


func _quarry_bonus(person: Inhabitant, centre: Vector3) -> float:
	var speciality := person.current_speciality as Profession.Speciality
	if not Hunting.PIEZAS_POR_JORNADA.has(speciality):
		return 1.0
	# La cifra de verdad y no un premio a ojo: lo que ESTA rama sacaria de
	# ESTE sitio, en raciones. Un cotarro de conejos no es «malo para la caza
	# mayor», es exactamente 1,4 raciones por pieza, y con eso la lista se
	# ordena sola sin inventarse ningun factor.
	var here := Hunting.rations_at(speciality, centre,
		GameState.season as Subsistence.Season, techs)
	return clampf(here / CAZA_DE_REFERENCIA, 0.15, 4.0)


## La trampa que más lleva cebada, o null si ninguna tiene nada. Es a la que
## hay que ir hoy.
func _fullest_trap() -> Trap:
	var best: Trap = null
	var best_ready := 0.0
	for trap: Trap in traps:
		var ready := trap.soaking / maxf(Trap.days_per_catch(trap.kind), 0.01)
		if ready < 1.0 or ready <= best_ready:
			continue
		best_ready = ready
		best = trap
	return best


## La trampa más cercana con algo dentro, o null.
func trap_with_catch_near(point: Vector3, radius: float) -> Trap:
	var best: Trap = null
	var best_distance := radius
	for trap: Trap in traps:
		if trap.soaking < Trap.days_per_catch(trap.kind) * 0.5:
			continue
		var flat := Vector2(point.x - trap.position.x, point.z - trap.position.z)
		if flat.length() < best_distance:
			best_distance = flat.length()
			best = trap
	return best


## La jornada del trampero: levantar lo que haya caído, y si no, armar más.
func _trapline(person: Inhabitant, hours: float) -> void:
	var fraction := hours / HORAS_UTILES
	if fraction <= 0.0:
		return

	# Primero, lo que ya está puesto. Levantar una trampa cebada es lo que
	# más rinde por hora de toda la caza, y por eso va antes que armar otra.
	# Se mira desde donde esta Y desde el centro del tajo: quien se ha
	# desplazado un poco buscando sigue teniendo su trampa a la espalda.
	var trap := trap_with_catch_near(person.position, ALCANCE_TRAMPA)
	if trap == null:
		trap = trap_with_catch_near(person.work_centre, ALCANCE_TRAMPA)
	if trap != null:
		var pieces := trap.collect()
		if pieces > 0:
			var brought: Array[String] = []
			for _i in range(pieces):
				var species := trap.quarry_here(
					GameState.season as Subsistence.Season, _rng)
				brought.append(Fauna.species_name(species).to_lower())
				_butcher(person, species, 1.0)
			person.log_deed(person.current_task(),
				"levantó %s: %s" % [Trap.trap_name(trap.kind).to_lower(),
					", ".join(brought)])
			_note(Chronicle.Kind.TIERRA, "%s levantó %s en %s: %s."
				% [person.given_name, Trap.trap_name(trap.kind).to_lower(),
					parajes.place_name(trap.position, home_position),
					", ".join(brought)], 0)
		else:
			# Sin nada dentro, se repasa: se recompone el ramaje y se vuelve a
			# cebar. Una trampa atendida dura bastante más que una olvidada.
			trap.worn = maxf(trap.worn - fraction * 1.5, 0.0)
			person.log_deed(person.current_task(),
				"repasó %s" % Trap.trap_name(trap.kind).to_lower(), false)
		return

	# Y si no hay nada que levantar, se arma más línea.
	if not _room_for_trap(person.position):
		person.log_deed(person.current_task(), "recorrió la línea de trampas", false)
		return

	var kind := _trap_to_set(person.position)
	if kind < 0:
		person.log_deed(person.current_task(),
			"sin material para armar más trampas", false)
		return

	var trap_kind := kind as Trap.Kind
	person.craft_progress += fraction / maxf(Trap.labor_days(trap_kind), 0.01)
	if person.craft_progress < 1.0:
		person.log_deed(person.current_task(),
			"armando %s" % Trap.trap_name(trap_kind).to_lower(), false)
		return

	person.craft_progress = 0.0
	# Se paga al terminar, no al empezar: una obra a medias no se ha comido
	# la fibra todavía.
	if not _can_afford(Trap.materials(trap_kind)):
		return
	for material: int in Trap.materials(trap_kind):
		store.take(material as Materia.Kind,
			float(Trap.materials(trap_kind)[material]))

	var placed := Trap.create(trap_kind, person.position, day, person.given_name)
	traps.append(placed)
	traps_set_today.append(placed)
	person.log_deed(person.current_task(),
		"armó %s" % Trap.trap_name(trap_kind).to_lower())
	_note(Chronicle.Kind.TIERRA, "%s armó %s en %s. Cobra sola: solo hay que ir a levantarla."
		% [person.given_name, Trap.trap_name(trap_kind).to_lower(),
			parajes.place_name(placed.position, home_position)], 1)


## Despieza una pieza y se la carga a quien la ha cobrado.
##
## Todo sale de [Fauna]: la carne por sus raciones y lo demás por el despiece
## de ESA especie. De un ave salen plumas y no piel, de un jabalí no sale
## asta, y el tendón solo de lo grande. Es la diferencia entre cazar y sumar
## un número.
func _butcher(person: Inhabitant, species: String, share: float) -> void:
	var meat := Fauna.rations_of(species) * share
	if meat > 0.0:
		person.add_load(Materia.Kind.CARNE, meat)
		person.carrying += meat
		person.log_gain(person.current_task(), Materia.Kind.CARNE, meat)
	for kind: int in Fauna.spoils_of(species):
		var units := float(Fauna.spoils_of(species)[kind]) * share
		if units > 0.0:
			person.add_load(kind as Materia.Kind, units)
			person.log_gain(person.current_task(), kind, units)


## Pasa un día por todas las trampas: cobran solas y se van gastando.
##
## Va en el cierre de jornada porque eso es lo que las hace distintas: una
## trampa trabaja mientras la banda duerme. Las que se han pasado de vida se
## retiran, y se cuenta —perder una línea de trampas en marzo es noticia.
func _age_traps() -> void:
	traps_set_today.clear()
	traps_lost_today.clear()
	if traps.is_empty():
		return

	var alive: Array[Trap] = []
	for trap: Trap in traps:
		trap.soaking += 1.0
		trap.worn += 1.0
		if trap.is_spent():
			traps_lost_today.append(trap)
			_note(Chronicle.Kind.PENURIA,
				"%s de %s se ha echado a perder en %s. Dio %d piezas."
					% [Trap.trap_name(trap.kind), trap.maker,
						parajes.place_name(trap.position, home_position),
						trap.taken], 0)
			continue
		alive.append(trap)
	traps = alive
