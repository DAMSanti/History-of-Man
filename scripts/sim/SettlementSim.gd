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

## Las cumbres y todo lo que va con subirlas. Ver [Cumbres].
var cumbres: Cumbres = Cumbres.new(self)

## Lo que puede salir mal en el monte. Ver [Percances].
var percances: Percances = Percances.new(self)

## Quien hace que cada manana. Ver [Reparto].
var reparto: Reparto = Reparto.new(self)

## Adonde se va a trabajar y que se trae. Ver [Tajo].
var tajo: Tajo = Tajo.new(self)

## Abrir monte nuevo. Ver [Reconocimiento].
var reconocimiento: Reconocimiento = Reconocimiento.new(self)

## La pared del abrigo. Ver [Pinturas].
var pinturas: Pinturas = Pinturas.new(self)

## Lo que se fabrica y lo que se gasta. Ver [Taller].
var taller: Taller = Taller.new(self)

## Comer, beber y salir avituallado. Ver [Despensa].
var despensa: Despensa = Despensa.new(self)

## El trato con los lobos, que acaba en perro o en enemigo. Ver [ElLobo]. Va
## detras de `desechos` a proposito: es el monton lo que los trae.
var lobo: ElLobo = ElLobo.new(self)

## El monton de lo que se tira, que no desaparece. Ver [Desechos] y [Conchero].
var desechos: Desechos = Desechos.new()

## La poblacion de fauna: la caza resta y la cria repone. La pone [DemoMain] al
## sembrar la fauna. Ver [Poblaciones].
var poblaciones: Poblaciones = null

## Las rejillas de caminos, una por estacion. Ver [HornoDeRejillas].
var horno: HornoDeRejillas = HornoDeRejillas.new()

## Lo que la estacion le hace al PAISAJE: nieve, barro y caudal. Ver [Temporada].
var temporada: Temporada = Temporada.new()

## Sin paraje donde trabajar se sale a TANTEAR el terreno, no a cruzar el
## valle. Ver [Tanteo].
var tanteo: Tanteo = Tanteo.new(self)

## Lo esquilmado se deja descansar y se busca en otra parte. Ver [Barbecho].
var barbecho: Barbecho = Barbecho.new(self)


# --- lo que la despensa comparte con el resto ------------------------------

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

## Cuanto multiplica la velocidad por marisma o vado saber nadar de verdad.
const NATACION_MARISMA_BONUS := 1.6

## Cuanto sube NATACION por hora metido en el barro o el vado. Minusculo, a
## proposito: es un rasgo de cuerpo, no una destreza de tajo.
const NATACION_TRAINING_RATE := 0.00006

## Ya se ha marcado que celdas de materia prima no vuelven a crecer.
var _veins_frozen := false

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


# --- lo que el taller comparte con el resto --------------------------------

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


# --- lo que el reconocimiento comparte --------------------------------------

## Lo más despacio que anda alguien, en fracción del paso de llano y de vacío.
## Ver `_terrain_speed`.
const MIN_PACE := 0.12

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

## Especies de las que ya se ha dicho que se ven pasar y no hay con que
## entrarles. La clave lleva la jornada: se dice una vez al dia, no una vez y
## nunca mas -que se dejaria de avisar al mes siguiente- ni una por tick.
var _quarry_lamented: Dictionary = {}

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


# --- lo que el tajo comparte con el resto del simulador -------------------

## Para cuantos dias se avitualla una caceria mayor.
##
## `_provision` pide una DISTANCIA y saca de ahi los dias -ver
## `_expedition_days_for`-, asi que aqui se le da la que corresponde a una caza
## de dos jornadas. No es la distancia a la que se va: es cuanto se lleva.
const CAZA_LEJOS_M := 1800.0

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
	# La lampara va con la talla y no con la peleteria ni el asta: es un canto
	# ahuecado a golpes, o sea el mismo trabajo de piedra que una raedera.
	Profession.Speciality.TALLA: [Tool.Kind.LASCA, Tool.Kind.RAEDERA,
		Tool.Kind.BURIL, Tool.Kind.PUNTA, Tool.Kind.LAMPARA],
	Profession.Speciality.ASTA: [Tool.Kind.AZAGAYA, Tool.Kind.ARPON,
		Tool.Kind.AGUJA, Tool.Kind.PUNZON, Tool.Kind.ANZUELO],
	Profession.Speciality.PELETERIA: [Tool.Kind.ODRE],
	Profession.Speciality.CORDELERIA: [Tool.Kind.CUERDA, Tool.Kind.CESTO,
		Tool.Kind.NASA, Tool.Kind.RED],
}

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

## El fuego del abrigo y lo que se hace a su alrededor. Ver [Hogar].
var hogar: Hogar = Hogar.new(self)


## Pone una obra del campamento en cola. Lo hace [Hogar]; se deja el pasamanos
## porque lo llaman el panel del almacen y las pruebas.
func queue_project(kind: CampProjects.Kind) -> bool:
	return hogar.queue_project(kind)


# --- el fuego y el vivac -------------------------------------------------
#
# Se quedan en el simulador aunque el minimo del hogar lo aplique
# [Reparto]: quien las lee de verdad es la noche -`_burn_hearth`,
# `_bivouac`- y no el reparto de la manana.

## Cuanta gente hace falta como minimo en el hogar.
##
## Uno. Sin nadie no se mantiene el fuego, las obras del abrigo no avanzan y
## la carne fresca se pierde en cuatro dias.
const MIN_HEARTH := 1

## Cuántos días de convalecencia adelanta al cabo de una jornada quien cuida a
## los heridos. Lo hace quien atiende el hogar, que ya no se reparte en
## especialidades: cuidar es una de las cosas que hace, no un
## rótulo: sin esto no cambiaría nada en la partida.
const CUIDADO_DAYS := 1

## Cuánto multiplica el riesgo de percance cada una de las dos cosas que falte.
## Con las dos, casi seis veces: dormir al raso, mojado y sin fuego, lejos de
## casa, es de las peores decisiones que se pueden tomar en este juego.
const VIVAC_RIESGO := 2.4

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

## Fatiga por hora que añade dormir en el abrigo con el fuego apagado, y sólo
## en invierno: el resto del año una cueva se aguanta sin fuego.
const HEARTH_COLD_FATIGUE := 3.0

## Piel de tienda por persona. NO se gasta: se lleva y se devuelve al abrigo,
## que es lo que se hace con una tienda. Lo que se pierde es la noche que no se
## llevó.
const VIVAC_PIEL := 1.0

## Leña de hoguera por persona y NOCHE. Ésta sí arde.
const VIVAC_LENA := 1.0

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


# --- el reparto de la mano de obra, que vive en [Reparto] ----------------
#
# Se dejan aqui los pasamanos y no se cambian los ciento cincuenta y seis
# sitios que los llaman: el simulador sigue siendo la puerta de entrada y
# quien reparte esta detras. Mover las llamadas solo cambiaria de sitio el
# mismo acoplamiento y de paso rompeeria las sondas.

func assign_default_jobs() -> void:
	reparto.assign_default_jobs()


func apply_priorities() -> void:
	reparto.apply_priorities()


func task_blocked_by(person: Inhabitant, task: int) -> String:
	return reparto.task_blocked_by(person, task)


func idle_count() -> int:
	return reparto.idle_count()


func idle_blockers(job: Profession.Job) -> Dictionary:
	return reparto.idle_blockers(job)


func spare_count(job: Profession.Job) -> int:
	return reparto.spare_count(job)


func assign_all(activity: Subsistence.Activity) -> void:
	reparto.assign_all(activity)


func set_job_count(job: Profession.Job, count: int) -> int:
	return reparto.set_job_count(job, count)


func set_speciality(job: Profession.Job, speciality: Profession.Speciality) -> void:
	reparto.set_speciality(job, speciality)


func speciality_counts(job: Profession.Job) -> Dictionary:
	return reparto.speciality_counts(job)


func job_counts() -> Dictionary:
	return reparto.job_counts()


func speciality_output(speciality: Profession.Speciality) -> int:
	return reparto.speciality_output(speciality)


func speciality_outputs(speciality: Profession.Speciality) -> Array[int]:
	return reparto.speciality_outputs(speciality)


func top_choice(person: Inhabitant) -> int:
	return reparto.top_choice(person)


func set_priority_all(job: Profession.Job, level: int) -> void:
	reparto.set_priority_all(job, level)


func remaining_person_days(activity: Subsistence.Activity) -> float:
	return reparto.remaining_person_days(activity)


func remaining_units(activity: Subsistence.Activity, kind: Materia.Kind) -> float:
	return reparto.remaining_units(activity, kind)


func remaining_units_at(activity: Subsistence.Activity, kind: Materia.Kind,
		cell_x: int, cell_z: int) -> float:
	return reparto.remaining_units_at(activity, kind, cell_x, cell_z)


func remaining_units_in(paraje: Paraje, activity: Subsistence.Activity,
		kind: Materia.Kind) -> float:
	return reparto.remaining_units_in(paraje, activity, kind)


func _ensure_hearth() -> void:
	reparto._ensure_hearth()


func _choose_speciality(person: Inhabitant) -> int:
	return reparto._choose_speciality(person)


func _is_spare(person: Inhabitant) -> bool:
	return reparto._is_spare(person)


func _task_has_somewhere(job: Profession.Job, task: int) -> bool:
	return reparto._task_has_somewhere(job, task)


func _activity_has_somewhere(job: Profession.Job, activity: int) -> bool:
	return reparto._activity_has_somewhere(job, activity)


func _job_has_somewhere(job: Profession.Job) -> bool:
	return reparto._job_has_somewhere(job)


func _tied_specialities(person: Inhabitant, level: int) -> int:
	return reparto._tied_specialities(person, level)


func _speciality_pressure(speciality: Profession.Speciality) -> float:
	return reparto._speciality_pressure(speciality)


func _yield_per_day(activity: Subsistence.Activity, kind: Materia.Kind) -> float:
	return reparto._yield_per_day(activity, kind)


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
	return marcha._navgrid()
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
	cumbres.forget()

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

	_ajustar_despensa()
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


## Cuanto avanza la simulacion en cada paso, en segundos de reloj de pantalla.
##
## LA SIMULACION VA A PASO FIJO, y esto es lo que la hace medible.
##
## Iba con el `delta` del fotograma a pelo, o sea que avanzaba lo que hubiera
## tardado el fotograma anterior. Con eso, `SEMILLA` fija el azar pero NO el
## numero de tiradas: dos partidas con la misma semilla divergen segun lo
## cargada que este la maquina. Medido: la misma semilla, las mismas ocho
## jornadas y la misma configuracion daban entre 2,8 y 14,5 dias de despensa.
##
## Eso no es una molestia de medicion, es que NO SE PUEDE AJUSTAR NADA: cada
## cifra de balanceo que se fije mirando una corrida esta ajustada a ruido.
##
## Una treintava de segundo: fino para que nadie atraviese un obstaculo,
## grueso para que no cueste.
const PASO_FIJO := 1.0 / 30.0

## Cuantos pasos como mucho en un fotograma.
##
## Sin tope, un fotograma lento pide muchos pasos, que lo hacen mas lento
## todavia: la espiral de la muerte de toda simulacion de paso fijo. Lo que
## sobra NO se tira -se queda en `_pendiente` y se hace en el siguiente-, asi
## que la partida se retrasa pero no pierde tiempo ni deja de ser repetible.
const PASOS_POR_CUADRO := 8

## El tiempo real que aun no se ha simulado.
var _pendiente := 0.0


func _process(delta: float) -> void:
	# El horno amasa SIEMPRE, aunque el reloj este parado: si no, una partida en
	# pausa no adelantaria trabajo y al reanudar seguiria faltando la rejilla
	# del trimestre que viene. Cuatro milisegundos por cuadro, ver
	# [HornoDeRejillas.MS_POR_CUADRO].
	horno.amasar()
	if people.is_empty() or _terrain == null or time_scale <= 0.0:
		return
	_pendiente += delta
	var dados := 0
	while _pendiente >= PASO_FIJO and dados < PASOS_POR_CUADRO:
		_pendiente -= PASO_FIJO
		dados += 1
		_advance(PASO_FIJO)


## Un paso de simulacion. Siempre del mismo tamaño: ver [PASO_FIJO].
func _advance(delta: float) -> void:

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
	marcha._watch_for_stuck(person, hours)

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
	# [Hogar.CAMP_FATIGUE_RATE], que hoy vale cero-. Si contara, quien llegase cansado
	# de la vispera se pondria a tallar junto al fuego, no se cansaria mas ni se
	# le pasaria en todo el dia, y curtiria aguante gratis. El dia que tallar
	# canse, esta excepcion sobra y se cae sola.
	if person.fatigue > RESISTENCIA_TRAINING_THRESHOLD \
			and person.state != Inhabitant.State.DURMIENDO \
			and person.state != Inhabitant.State.OCIOSO \
			and person.state != Inhabitant.State.COMIENDO \
			and (Hogar.CAMP_FATIGUE_RATE > 0.0 or not hogar._works_at_camp(person)):
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
	var walk_home := marcha.hours_to_walk(person.position.distance_to(home_position))
	var winding_down := hour + walk_home * RODEO_DE_VUELTA >= HORA_REGRESO \
		and hour < HORA_DORMIR
	var morning := hour >= HORA_DESPERTAR and hour < HORA_SALIDA

	# A la hora de volver, todo el mundo emprende el regreso salvo quien esta
	# de expedicion. Sin esto la gente se quedaba trabajando hasta la noche y
	# volvia a oscuras, que es lo que hace un autómata, no una persona.
	if winding_down and person.state != Inhabitant.State.VOLVIENDO \
			and not (hogar._works_at_camp(person) and hogar._can_work_at_night(person)):
		var on_expedition := person.job == Profession.Job.EXPLORACION \
			and person.current_speciality != Profession.Speciality.BATIDA \
			and person.position.distance_to(home_position) > arrive_radius * 4.0
		if not on_expedition:
			if _at_shelter(person):
				despensa._deliver(person)
				person.state = Inhabitant.State.OCIOSO
			else:
				marcha._send_to(person, home_position)
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
	_tick_routine(person, hours, delta, night)

	marcha._tick_step(person, index, hours, delta)

	# Las pruebas montan una `SettlementSim` a medias -gente y reservas, sin
	# pasar por [setup]- para probar la lógica sin pagar el terreno ni la
	# banda dibujada. `_crowd` y `_bodies` son justo lo que no montan, y no
	# tienen por qué: lo que se prueba ahí no depende de cómo se ve nadie.
	# Y dónde se queda si está en casa: dentro a dormir, en la puerta a todo lo
	# demás. Ver `_settle_at_home`.
	# El agua del dia. Va aqui, al final del tick, para que mire la posicion en
	# la que la persona ha ACABADO el paso y no la de antes de darlo.
	despensa._drink_and_thirst(person, hours)

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

## La rutina de la jornada: dormir, cenar, salir, trabajar y volver.
##
## Sale de `_tick_person` porque aquello eran quinientas setenta y seis lineas
## en una sola funcion y trescientas veintinueve eran esto. Lo que queda alli
## es el ORDEN de un tick -necesidades, horario, rutina, movimiento- y aqui
## esta la rutina entera, que es lo que se lee cuando se quiere saber que hace
## alguien a las once de la manana.
func _tick_routine(person: Inhabitant, hours: float, delta: float,
		night: bool) -> void:
	if night and person.state == Inhabitant.State.COMIENDO:
		despensa._eat_meal(person, hours)
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
		var camping := despensa._camps_out(person, mid_survey)

		# Sin comida encima, la salida se acaba y se vuelve: es lo que pone
		# limite a su alcance, mas todavia que el cansancio -salvo, por lo
		# de arriba, mientras se este terminando de reconocer.
		if camping and (despensa.pack_rations(person) > 0.2 or mid_survey):
			person.state = Inhabitant.State.DURMIENDO
			# La tienda y la hoguera de esta noche. Ver `_bivouac`.
			despensa._bivouac(person)
			# Se descansa peor al raso que en el abrigo, y peor todavía sin
			# nada con que armar el vivac.
			# Lo que falta y lo mal armado que este pesan igual: una tienda que se
			# viene abajo abriga lo mismo que no tenerla.
			var botched := 1.0 if person.bivouac_botched else 0.0
			var rest := 6.0 - (float(person.bivouac_lack) + botched) * VIVAC_REST_LOSS
			person.fatigue = maxf(person.fatigue - hours * maxf(rest, 0.0), 0.0)
			# Y se cena de lo que se lleva
			despensa._eat_from_pack(person, hours)
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
				despensa._deliver(person)
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
		_tick_daylight(person, hours)


## Lo que se hace con luz: comer, salir al tajo, trabajarlo y volver.
##
## Sale de `_tick_routine` porque aquello eran trescientas treinta y siete
## lineas y doscientas cuarenta eran esto. Arriba queda LA NOCHE -acampar o
## dormir en casa- y aqui el dia: dos cosas que no se parecen en nada y que
## estaban en las dos ramas del mismo `if`.
## Cuanta destreza se gana por hora de trabajo.
##
## Estuvo en 0,0008, o sea 0,0072 al dia con las nueve horas utiles, y con eso
## un recolector pasaba de 0,096 a 0,505 de pericia EN CUARENTA Y CINCO DIAS y
## tocaba el techo hacia el 120. Medido con `scripts/tests/AnoProbe.gd`:
##
##   dia  1   pericia 0,096 · efectividad 0,218 · despensa 6 dias
##   dia 16   pericia 0,293 · efectividad 0,301 · despensa 17
##   dia 31   pericia 0,395 · efectividad 0,373 · despensa 72
##   dia 46   pericia 0,505 · efectividad 0,462 · despensa 94
##
## Eso es lo que hacia explotar la despensa: el rendimiento de la recoleccion
## se multiplicaba por 2,4 en mes y medio -de 4,0 raciones por persona y dia a
## 9,5- cuando el objetivo que este mismo fichero declara es «cerca del doble
## de lo que come», o sea 3,4.
##
## Y ademas dejaba sin sentido dos sistemas: si un adulto domina su oficio en
## cuatro meses, la transmision nocturna -`_knowledge_transmission`- no tiene
## a quien enseñar, y el relevo generacional no es un problema.
##
## Puesto para que la pericia suba del orden de 0,25 EN UN AÑO de juego: se
## nota en la campaña, y dominar un oficio sigue siendo cosa de vida entera,
## que es lo que dicen los datos de rendimiento por edad en forrajeadores
## -Kaplan y otros: el rendimiento de un cazador ache no llega a su techo
## hasta los treinta y tantos-.
##
## Pendiente de playtest: lo medido es la curva vieja; lo decidido es que
## aprender lleve una campaña y no una estacion.
const APRENDE_POR_HORA := 0.00015


func _tick_daylight(person: Inhabitant, hours: float) -> void:
	match person.state:
		Inhabitant.State.DURMIENDO, Inhabitant.State.OCIOSO:
			_decide_the_day(person, hours)
		Inhabitant.State.COMIENDO:
			despensa._eat_meal(person, hours)
		Inhabitant.State.YENDO:
			if person.position.distance_to(person.target) < arrive_radius:
				if person.job == Profession.Job.EXPLORACION \
						and person.current_speciality == Profession.Speciality.ASCENSION \
						and cumbres._is_on_peak(person):
					# Llegar al pie de la cumbre no es coronarla: se
					# INTENTA, y con poca pericia se falla. Ver [Ascent].
					cumbres._try_ascent(person)
					marcha._send_to(person, home_position)
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
				marcha._send_to(person, tajo._search_target(person))
				person.state = Inhabitant.State.YENDO
		Inhabitant.State.RECONOCIENDO:
			reconocimiento._survey(person, hours)
		Inhabitant.State.TRABAJANDO:
			if hogar._works_at_camp(person):
				hogar._camp_work(person, hours)
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
				# Batir la mancha es de quien recoge. Quien acecha va a
				# donde está la pieza, y `_forage_drift` le reescribiría el
				# destino cada tick con un punto sorteado del paraje.
				if not caceria._is_hunting(person):
					tajo._forage_drift(person)
				if person.job == Profession.Job.MANUFACTURA:
					taller._craft(person, hours)
				elif person.current_speciality == Profession.Speciality.CAZA_MENOR \
						or person.current_speciality == Profession.Speciality.CAZA_MAYOR:
					# La caza YA NO cosecha: acecha, persigue y cobra una
					# pieza de las que andan por el valle. Ver `_hunt_step`.
					caceria._hunt_step(person, hours)
				elif person.current_speciality == Profession.Speciality.ORILLA:
					# La nasa se revisa y luego SE PESCA. `_creel_round`
					# devuelve las horas que quedan de jornada, que es lo
					# que la separa de la línea de trampas: aquélla se
					# lleva el día entero, ésta un rato.
					tajo._harvest(person, nasas_line._creel_round(person, hours))
				elif person.current_speciality == Profession.Speciality.TRAMPAS:
					# El trampero no cosecha: arma trampas y luego las levanta.
					# Es el unico trabajo que rinde MIENTRAS la banda hace otra
					# cosa, y por eso no puede ser una tabla de rendimiento
					# como las demas.
					trampas._trapline(person, hours)
				else:
					tajo._harvest(person, hours)
				# La practica mejora la TAREA que se esta haciendo, no la
				# actividad entera: quien talla no aprende a curtir pieles.
				var task := person.current_task()
				var current: float = person.skill_in(task)
				person.skill[task] = minf(
					current + hours * APRENDE_POR_HORA * person.learn_rate(), 0.95)

				# Se vuelve cuando no se puede cargar mas, no por un numero
				# fijo: es lo que hace que los recipientes cambien la jornada.
				if person.fatigue > 78.0 or person.load_fraction() >= 1.0:
					marcha._send_to(person, home_position)
					person.state = Inhabitant.State.VOLVIENDO

		Inhabitant.State.VOLVIENDO:
			if _home_reached(person):
				despensa._deliver(person)
				person.state = Inhabitant.State.OCIOSO


## A que se sale hoy: expedicion, cumbre, batida, el abrigo o el tajo.
##
## Es la rama mas larga de `_tick_daylight` -mas de cien lineas de un `if`
## encadenado- y la unica que DECIDE: las demas ejecutan lo ya decidido. Sacarla
## deja el reparto de estados como lo que es, un indice, y la decision donde se
## puede leer entera.
func _decide_the_day(person: Inhabitant, hours: float) -> void:
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
		marcha._send_to(person, home_position)
		person.state = Inhabitant.State.VOLVIENDO
	elif person.job == Profession.Job.EXPLORACION \
			and person.current_speciality == Profession.Speciality.BATIDA:
		# La batida es radio corto y vuelve siempre a dormir a
		# casa: no hace falta avituallarla como a una expedicion.
		# Amplia el entorno inmediato del campamento, no la
		# frontera del territorio.
		var target := reconocimiento._batida_target(person)
		if target.distance_to(person.position) > arrive_radius:
			marcha._send_to(person, target)
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
				and cumbres.has_peak():
			# La cumbre que ESTA persona se atreve a atacar, no la mas
			# alta que haya. Ver [peak_for].
			climb = cumbres.peak_for(person)

		if climb.is_empty():
			# Que HAYA cumbre no quiere decir que le toque a esta
			# persona: puede no atreverse con ninguna de las que quedan,
			# o estar todas al otro lado del agua. Aqui se leia ["pos"]
			# sin mirar, y el juego se caia en cuanto pasaba.
			#
			# No es un caso raro ni un error: es la vuelta a la
			# exploracion normal, que es lo que hace quien se queda sin
			# monte al que subir.
			frontier = reconocimiento._scout_target(person)
		else:
			frontier = climb["pos"]

		if at_home and person.fatigue > REST_BEFORE_EXPEDITION:
			# Esperar a estar descansado antes de partir: salir ya
			# cansado de varios dias fuera es la manera de no
			# volver. La noche en casa recupera fatiga sola -ver el
			# bloque nocturno-, asi que esto no atasca a nadie:
			# solo retrasa la salida un dia o dos.
			person.state = Inhabitant.State.OCIOSO
		elif at_home and not despensa._provision(person, frontier.distance_to(home_position)):
			# Sin provisiones no hay expedicion. Se queda ayudando.
			person.state = Inhabitant.State.OCIOSO
		else:
			if frontier.distance_to(person.position) > arrive_radius:
				marcha._send_to(person, frontier)
				if person.route.is_empty():
					# No hay por donde llegar -un rio de por medio,
					# un cortado-: se busca otro sitio en vez de
					# salir andando derecho al agua
					_lament(person, frontier)
					if has_scout_order:
						reconocimiento.clear_scout_order()
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
	elif hogar._works_at_camp(person) and hogar._can_work_at_night(person):
		# Fichar. La faena en si la hace `_camp_work` desde TRABAJANDO,
		# igual que la de cualquiera: aqui solo se dice que se empieza.
		person.work_centre = home_position
		person.forage_target = home_position
		person.state = Inhabitant.State.TRABAJANDO
	elif person.has_task and hour >= HORA_SALIDA and hour < HORA_REGRESO:
		_send_to_work(person)


## Levanta un momento: algo que hay que enseñar o decidir ahora. Ver [Moment].
func raise_moment(moment: Moment) -> void:
	moment_raised.emit(moment)


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
			if not hogar._works_at_camp(person):
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


## El motivo de renunciar a un destino, con nombre fijo para poder contarlo.
const RENUNCIA := "por ahi no se pasa"


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
			despensa._deliver(person)
		else:
			lost_loads += 1
	person.load.clear()
	person.carrying = 0.0
	person.search_hours = 0.0

	# Los recipientes se cogen al salir, y DESPUES de entregar: `_deliver`
	# los devuelve al abrigo, asi que repartirlos antes era dejar salir a la
	# gente con las manos vacias.
	despensa._hand_out_containers(person)

	# EL CAZADOR MAYOR SE AVITUALLA, como el explorador. Una pieza grande no se
	# cobra entre el desayuno y la cena -medido: con caza de jornada salian una
	# a tres piezas en seis dias con ochenta y cuatro cacerias levantadas- y
	# seguir un rastro dos jornadas pide llevar de comer. Sin provisiones sale
	# igual: lo que no puede es dormir fuera, y eso ya lo mira `_camps_out`.
	if person.current_speciality == Profession.Speciality.CAZA_MAYOR:
		despensa._provision(person, CAZA_LEJOS_M)

	# El taller NO sale a picar piedra. Su oficio figura con la actividad
	# «materia prima» -es de donde saca lo que gasta- y eso le mandaba al
	# canchal como si fuera un recolector: se veia al tallador cruzando el
	# valle para traer cantos que cualquiera de los que ya estan fuera podia
	# haber traido de paso.
	#
	# Sale SOLO cuando de verdad falta lo que necesita para la pieza que toca,
	# y entonces es un recado, no una jornada de cantera.
	if person.job == Profession.Job.MANUFACTURA and not taller._workshop_short(person):
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
		marcha._send_to(person, candidate)
		if not person.route.is_empty():
			destination = candidate
			break

	if destination == Vector3.ZERO:
		# A ningun tajo de este oficio se llega hoy. Se apunta —para que salga
		# en los atascos y no en el silencio— y se marca la actividad como
		# inalcanzable, que es lo que hace que el reparto de manana lo baje a
		# su siguiente oficio en vez de dejarlo mirando el rio desde casa.
		marcha._record_stuck(person, "no hay camino hasta ningun tajo de %s"
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


## Los sitios adonde se puede mandar a trabajar a alguien, por orden de
## preferencia. El primero que tenga camino se lleva la jornada.
func _work_candidates(person: Inhabitant) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var best := tajo._best_known_spot(person)
	if best != Vector3.ZERO:
		out.append(best)

	# Si a este oficio no le queda un sitio conocido sin esquilmar, se sale a
	# BUSCAR. Va lo primero -por delante incluso del mejor conocido- porque en
	# ese caso el mejor conocido es un sitio muerto.
	#
	# Dos cosas distintas, y las dos hacen falta:
	#
	#   BUSCAR   el mejor sitio del entorno, mirando el campo de recursos. Es
	#            una mudanza y se hace sabiendo adonde se va. Ver
	#            [Barbecho.donde_buscar].
	#   TANTEAR  cuando no hay ni eso: una vuelta por el sector que toca -el
	#            margen del rio si es pescador- a ver que sale. Ver [Tanteo].
	#
	# El tanteo va DETRAS del buscar como candidato: si hay un sitio bueno al
	# alcance se va a el, y si no, se da la vuelta. Lo que ya no pasa es
	# quedarse en el abrigo.
	if barbecho.sin_sitio(person.activity):
		var buscando := barbecho.donde_buscar(person.activity, person.position)
		if buscando != Vector3.ZERO:
			out.insert(0, buscando)
		var tanteando := tanteo.adonde(person)
		if tanteando != Vector3.ZERO and not out.has(tanteando):
			out.append(tanteando)

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
	var search := tajo._search_target(person)
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
## Cuanto tiene que haber de algo para contar como que la banda «lo tiene».
##
## Medio bulto. Por debajo de eso no es comida de la despensa, es un resto.
const ALGO_EN_DESPENSA := 0.5


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
		return not trampas.traps.is_empty() or _can_afford_a_trap()
	if not SPECIALITY_MAKES.has(speciality):
		return true
	return taller._next_piece(speciality) >= 0


## Si en el abrigo hay con que armar alguna de las trampas que se saben hacer.
func _can_afford_a_trap() -> bool:
	for kind: int in trampas.known_traps():
		if taller._can_afford(Trap.materials(kind as Trap.Kind)):
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
	var crafting := taller.crafting_now(person)
	if not crafting.is_empty():
		var look: Array = MateriaIcon.TOOL_LOOK[int(crafting["tool"]) as Tool.Kind]
		return {
			"glyph": look[0], "tint": look[1],
			"progress": float(crafting["progress"]),
			"label": Tool.kind_name(int(crafting["tool"]) as Tool.Kind),
		}

	if person.state != Inhabitant.State.TRABAJANDO:
		return {}

	# El cazador: lo que dice la chapa es la FASE, que es lo que se quiere
	# saber mirándole. Un cazador acechando y uno corriendo detrás de un ciervo
	# son dos cosas muy distintas y hasta ahora se veían igual.
	var hunt := caceria.hunt_of(person)
	if hunt != null:
		return {
			"glyph": MateriaIcon.Glyph.CARNE, "tint": Color(0.72, 0.36, 0.30),
			"progress": _hunt_progress(hunt),
			"label": hunt.doing_text(),
		}

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


## Cuánto lleva andado de la cacería, de 0 a 1.
##
## No es una sola cuenta porque no hay una sola: acechando lo que avanza es el
## rastreo, corriendo lo que avanza es el fuelle que se gasta, y despiezando lo
## que avanza es la res abierta. La barra dice lo mismo en las tres —cuánto
## falta para lo siguiente—, que es lo único que se pregunta quien mira.
func _hunt_progress(hunt: Hunt) -> float:
	match hunt.phase:
		Hunt.Phase.PERSECUCION:
			return clampf(hunt.chased / Hunt.FUELLE_HORAS, 0.0, 1.0)
		Hunt.Phase.DESPIECE:
			return clampf(hunt.spent / maxf(
				Hunt.butcher_days(hunt.species), 0.01), 0.0, 1.0)
		Hunt.Phase.ACARREO:
			return 1.0
		_:
			# Acecho y lance: lo que se lleva de rastreo. El denominador es el
			# de esta persona, y aquí no la hay, así que se usa la cuadrilla.
			if hunt.crew.is_empty():
				return 0.0
			return clampf(hunt.spent / maxf(
				caceria._tracking_hours(hunt.crew[0]), 0.01), 0.0, 1.0)


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
	# Cuanta comida cabe cambia con el taller: los cestos se rompen y se
	# trenzan otros. Ver [_ajustar_despensa].
	_ajustar_despensa()
	_record_history()
	# Lo que la banda cree saber se reordena una vez al dia. Antes se
	# recalculaba por persona y por salida, y eso eran 61.000 operaciones cada
	# vez que alguien cruzaba la puerta.
	tajo._rank_known_spots()
	# El secadero, ANTES de que pase la noche por la despensa: lo que se cuelga
	# por la mañana ya está curado cuando llega la madrugada, y curarlo después
	# de aplicar la podredumbre sería ahumar lo que ya se tiró.
	hogar._smoke_the_larder()
	# Y el lavadero, que no pide fuego pero se atiende igual: se saca lo que ya
	# está dulce y se vuelve a llenar el cesto. Ver [Hogar._lavar_bellota].
	hogar._lavar_bellota()
	store.age(1)
	desechos.nuevo_dia()
	lobo.nuevo_dia()
	# Y revista a los parajes: lo que baja del veinte por ciento se deja
	# descansar solo, sin que el jugador tenga que estar mirandolo.
	barbecho.revisar()
	# Y el paisaje se mueve: la cota de nieve baja, las vegas se encharcan y el
	# rio crece o baja. No es pintura -frena y cierra vados-. Ver [Temporada].
	temporada.nuevo_dia(GameState.season as Subsistence.Season)
	# Y la fauna cria, con techo. Sin esto la caza solo resta y el valle se
	# vacia; con crecimiento sin techo, no se vacia nunca.
	if poblaciones != null:
		poblaciones.nuevo_dia(GameState.season as Subsistence.Season)
	despensa._report_spoilage()
	hogar._burn_hearth()

	# Las piezas rotas se retiran ahora y no al romperse, para que el parte del
	# dia pueda contarlas antes de que desaparezcan.
	toolkit.discard_spent()
	toolkit.broken_today.clear()

	# Las trampas cobran mientras la banda duerme, y se van gastando. Y las
	# nasas igual, que es lo mismo en el agua.
	_age_traps()
	nasas_line._age_nasas()
	# Y lo que quedó abierto en el monte: se pudre y, sobre todo, hay lobos.
	caceria._age_kills()

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

	tajo._roll_production()
	_roll_weather()
	percances._check_mishaps()
	reconocimiento._check_scout_order()

	# Los sitios que la banda ya conoce lo bastante se bautizan. Va aqui, una
	# vez por jornada: recorre las 4.096 celdas del campo y hacerlo por
	# fotograma fue lo que se comio el rendimiento la vez anterior.
	reconocimiento._name_new_parajes()

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
	# Lo que se vio pasar hoy se olvida: manana la banda puede tener ya la
	# azagaya, y entonces el aviso estorba en vez de informar.
	_quarry_lamented.clear()

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
			# El techo YA NO es fijo: lo que hay pintado en la pared lo sube,
			# tarea por tarea. Es la diferencia entre contar una cacería y
			# dejarla puesta -ver `paintings_ceiling` y [Tale]-, y sin
			# paredes devuelve exactamente el de siempre.
			var ceiling: float = float(best_known[task]) \
				* pinturas.paintings_ceiling(task)
			var mine := person.skill_in(task)
			if ceiling <= mine:
				continue
			var gain := (ceiling - mine) * TRANSMISSION_RATE * person.learn_rate()
			person.skill[task] = minf(mine + gain, ceiling)


## --- El parte de lo que se ha echado a perder ----------------------------
##
## La podredumbre existía —[Storehouse.age] la aplica desde siempre— y NO SE
## VEÍA: el almacén enseñaba un número que no subía y desde fuera un montón que
## no crece porque nadie lo trae y uno que no crece porque se pudre se leen
## igual. Ahora se dice todos los días, con nombre y cantidad.

## Lo que se ha perdido hoy, material -> unidades. Es una copia y no
## `store.spoiled` a secas porque aquélla se vacía en la siguiente llamada a
## `age`, y el parte tiene que aguantar la jornada entera en pantalla.
var spoiled_today: Dictionary = {}

## Raciones de comida perdidas hoy. Es la cifra que de verdad duele: dos pieles
## echadas a perder no son lo mismo que dos días de comer.
var spoiled_rations_today: float = 0.0

## Por encima de estas raciones perdidas en una jornada, el parte deja de ser
## rutina y pasa a ser noticia que sobrevive a la criba de la crónica. Cuatro
## raciones son dos días de una persona: por debajo de eso es la merma normal
## de una despensa, por encima es que algo se está haciendo mal.
const MERMA_QUE_DUELE := 4.0


## Une una lista como se diría en voz alta: «a, b y c». Vacía da cadena vacía.
static func _join_and(parts: Array[String]) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	return "%s y %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[-1]]


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
	var stock := despensa.winter_stock()
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


## Cuantos tramos se andan reconociendo una comarca.
##
## Nueve horas dan para unas seis patas de trescientos metros con sus paradas.
## Menos se lee como estar quieto; mas, como dar vueltas sin sentido.
const SURVEY_LEGS := 6


## Contar lo que la cuadrilla ve pasar y no puede cobrar.
##
## Va con la caza y no con la pesca porque es de la caza el problema: en el
## agua, faltar el aparejo BAJA UN ESCALON -ver [Fishing.best_for]- y se pesca
## a mano; en el monte no hay escalon que bajar contra un uro, o se tiene la
## azagaya o se le ve marchar.
func _watch_the_quarry_pass(person: Inhabitant) -> void:
	var speciality := person.current_speciality as Profession.Speciality
	if not Hunting.RACIONES_POR_JORNADA_PERFECTA.has(speciality):
		return

	var blocked := Hunting.out_of_reach(speciality, person.work_centre,
		GameState.season as Subsistence.Season, toolkit)
	if blocked.is_empty():
		return

	# La mejor de las que se escapan: es la que duele y la que hay que nombrar.
	var best: Dictionary = {}
	var most := -1.0
	for entry: Dictionary in blocked:
		var rations := Fauna.rations_of(String(entry["species"]))
		if rations > most:
			most = rations
			best = entry
	if best.is_empty():
		return

	var species := String(best["species"])
	person.log_deed(person.current_task(),
		"vio %s y no tenía con qué" % Fauna.species_name(species).to_lower(),
		false)

	var key := "%s|%d" % [species, day]
	if _quarry_lamented.has(key):
		return
	_quarry_lamented[key] = true
	_note(Chronicle.Kind.PENURIA,
		"%s vio %s en %s y lo dejó pasar: %s." % [
			person.given_name, Fauna.species_name(species).to_lower(),
			parajes.place_name(person.work_centre, home_position),
			String(best["missing"])], 1)


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
	var key := marcha._reach_key(where)
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

## Ajusta cuanta comida cabe, segun los recipientes que tenga la banda.
##
## Se llama al montar y al cerrar cada jornada, porque el utillaje cambia: los
## cestos se rompen con el uso y se trenzan otros.
##
## ESTO SUSTITUYE A UN TOPE INVENTADO. Hubo aqui un `food_cap` que arrancaba en
## treinta dias de comida y paraba a los recolectores cuando se llegaba. No era
## una mecanica: era un numero. Nada en el mundo impide a una banda seguir
## amontonando avellana, y poner que si lo impide es hacer trampa.
##
## Lo que de verdad limita es EN QUE SE GUARDA. La cueva tiene doce metros
## cubicos, que dan para 10.200 raciones de avellana -cuatrocientos dias para
## quince bocas-, asi que su volumen no muerde nunca. Lo que muerde es que la
## banda arranca SIN CESTOS y que trenzar cuesta jornadas de cordeleria.
##
## `food_cap` sigue existiendo y sigue en cero: es lo que el JUGADOR puede
## pedir -«no me acumules mas de tanto»-, y eso si es suyo.
func _ajustar_despensa() -> void:
	if store == null:
		return
	store.capacidad_comida = store.capacidad_de_comida(
		toolkit.count(Tool.Kind.CESTO), toolkit.count(Tool.Kind.ODRE))


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


## Como se llama lo que aparece en el libro de trabajo de una persona.
##
## Las piezas de utillaje se guardan con clave NEGATIVA para no chocar con los
## materiales, que empiezan en cero como ellas. Aqui se deshace.
static func logged_name(key: int) -> String:
	if key < 0:
		return Tool.kind_name((-1 - key) as Tool.Kind)
	return Materia.material_name(key as Materia.Kind)


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
		if not marcha._navgrid().connected(person.position, paraje.position):
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
					and reconocimiento._exploration_anchor(other).distance_to(paraje.position) < 120.0:
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
		taller.workers_in(Subsistence.Activity.PESCA))


# --- Las trampas de tierra -----------------------------------------------
#
# Se mudaron a `scripts/Trampas.gd`. Aqui quedan las tres que usa medio
# juego y que solo estaban aparcadas en esta seccion.

## La linea de trampas, que vive en [Trampas]. Se monta aqui y no en `setup`
## por lo mismo que [caceria]: las pruebas construyen simulaciones a medias.
var trampas: Trampas = Trampas.new(self)


func _quarry_bonus(person: Inhabitant, centre: Vector3) -> float:
	var speciality := person.current_speciality as Profession.Speciality
	if not Hunting.RACIONES_POR_JORNADA_PERFECTA.has(speciality):
		return 1.0
	# La cifra de verdad y no un premio a ojo: lo que ESTA rama sacaria de
	# ESTE sitio, en raciones. Un cotarro de conejos no es «malo para la caza
	# mayor», es exactamente 1,4 raciones por pieza, y con eso la lista se
	# ordena sola sin inventarse ningun factor.
	# CON EL UTILLAJE DELANTE. Un cotarro de uros sin una azagaya en el abrigo
	# no es un sitio de caza mayor flojo: es ninguno, y la cuadrilla tiene que
	# irse a donde haya algo que de verdad pueda cobrar.
	var here := Hunting.rations_at(speciality, centre,
		GameState.season as Subsistence.Season, techs, toolkit)
	return clampf(here / Trampas.CAZA_DE_REFERENCIA, 0.15, 4.0)


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


# --- Lo que se cuenta al volver, y lo que se pone en la pared -------------
#
# «Después de una caza mayor, cuando vuelvan al abrigo contarán la historia y
# eso se transmitirá al jugador contándosela a él también. Cualquier
# descubrimiento, adelanto tecnológico o hito quiero que se represente también
# con una historia y nos dará la opción de pintarlo en la cueva.»
#
# La mitad de esto ya existía y no se veía: `_knowledge_transmission` acerca
# cada noche a los que duermen en la cueva a lo que sabe el mejor de ellos, y
# eso ES contar la cacería junto al fuego. Lo que faltaba era enseñárselo al
# jugador y, sobre todo, la diferencia entre contarlo y PINTARLO.
#
# Contado, un relato dura lo que dure quien estuvo. Pintado, no: sube el techo
# de lo que se puede aprender de oídas sobre esa tarea, y lo sube para siempre.
# No es una metáfora —es lo que dice [TechTree.Tech.ARTE] con todas las letras,
# «la primera tecnología de la memoria»— y es la razón de que pintar valga el
# ocre, la grasa y las dos jornadas que cuesta.

## Todo lo que la banda ha contado, lo pintado y lo no pintado.
var tales: Array[Tale] = []

## Especies de las que YA se ha contado la primera pieza.
##
## Existe por una cuenta que salió del sondeo: con la cacería funcionando, una
## banda de cuatro batidores cobra pieza mayor cada tres o cuatro jornadas
## —medido con `CaceriaProbe`: sesenta y cuatro piezas en ciento veinte
## jornadas, treinta y dos relatos—. Levantar una tarjeta que para la partida
## con esa frecuencia es exactamente lo que [Moment] avisa que no hay que
## hacer: «en dos estaciones el jugador aprendería a cerrar la tarjeta sin
## leerla».
##
## Así que la PRIMERA de cada especie se cuenta y se para; las demás quedan en
## la crónica, que es donde se leen sin que nadie te interrumpa. Y encaja con
## lo que se pidió, que era que una gran caza pesara: la primera vez que la
## banda tumba un uro es un hito, la novena es el jueves.
var _told_species: Dictionary = {}

## Lo que hay en la pared, que es el subconjunto que importa de verdad.
var paintings: Array[Tale] = []

## El relato que el jugador ha mandado pintar y todavía no está en la pared.
var painting_queue: Tale = null
var painting_progress: float = 0.0

## Lo que cuesta poner un relato en la pared.
##
## Jornadas de alguien del hogar, ocre para el pigmento y grasa para la
## lámpara. Los tres son de balanceo y están sin calibrar, como todo lo que
## decide cuánto duele algo; lo que está decidido es que cueste, y que lo que
## cueste sea justo lo que hace falta de verdad para pintar dentro de una
## cueva: color, luz y tiempo.
const PINTURA_JORNADAS := 2.0
const PINTURA_OCRE := 3.0

## Y la grasa de la lámpara. Media porción por jornada de pintado: una lámpara
## de las de Lascaux arde unas horas con muy poca.
const PINTURA_GRASA := 1.5

## Cuánto sube el techo de lo que se aprende de oídas, por relato pintado de
## esa tarea. Ver [TRANSMISSION_CEILING] y `_knowledge_transmission`.
##
## Seis puntos: tres o cuatro paredes bien puestas acercan el techo al 95 %, y
## ahí se para. Nunca llega al 100 y no debe: una parte de lo que sabe un
## cazador es la mano, y eso no se aprende mirando una pared por muy buena que
## sea. Lo que la pared hace es que no haya que empezar de cero cada vez que se
## muere el que sabía.
const PINTURA_TECHO := 0.06

## Y hasta dónde puede llegar el techo con toda la pared pintada.
const PINTURA_TECHO_MAX := 0.95


## Levanta un relato: lo guarda, lo cuenta en la crónica y se lo enseña al
## jugador con la opción de pintarlo.
##
## Lo de enseñarlo va por [Moment] y no por un aviso propio a propósito: el
## juego ya tiene un sitio en el que la partida se para y te mira, y meter un
## segundo canal para lo mismo enseñaría al jugador a ignorar los dos.
func tell_tale(tale: Tale) -> void:
	tales.append(tale)
	_note(Chronicle.Kind.GENTE, tale.text, 1)

	# Las piezas repetidas se anotan y no se enseñan. Ver `_worth_stopping_for`.
	if not _worth_stopping_for(tale):
		return

	var moment := Moment.new()
	moment.kind = Moment.Kind.RELATO
	moment.title = tale.title
	moment.text = tale.text
	if tale.where != Vector3.ZERO:
		moment.where = tale.where
		moment.has_place = true

	# La decisión sólo se ofrece si de verdad se puede tomar. Un botón que
	# contesta «falta ocre» al pulsarlo es peor que no estar.
	if tale.paintable():
		var falta := pinturas.painting_blocked_by()
		if falta.is_empty():
			moment.options = [
				{
					"label": "Pintarlo en la cueva",
					"hint": "Dos jornadas del hogar, %.0f de ocre y grasa para "
						% PINTURA_OCRE
						+ "la lámpara. Lo que queda en la pared se aprende "
						+ "aunque no quede nadie que estuviera allí.",
					"on_pick": func() -> void: pinturas.queue_painting(tale),
				},
				{
					"label": "Con contarlo basta",
					"hint": "Se cuenta al fuego esta noche y ya. Dura lo que "
						+ "dure quien lo cuente.",
					"on_pick": func() -> void: pass,
				},
			]
		else:
			moment.text += "\n\nPara ponerlo en la pared: %s." % falta
	raise_moment(moment)


## La cacería que se cuenta al llegar: sólo la grande.
##
## Y sólo la grande, que es el encargo: «en el Paleolítico una gran caza no era
## algo diario». Contar cada conejo del lazo convertiría el relato en el ruido
## que la crónica ya evita con los pesos.
func _tell_the_hunt(person: Inhabitant, hunt: Hunt) -> void:
	if Fauna.porte_of(hunt.species) != Fauna.Porte.MAYOR:
		return
	tell_tale(Tale.hunt(person.given_name, hunt.species,
		parajes.place_name(hunt.kill_site, home_position),
		maxi(hunt.crew.size(), 1), hunt.unseen, day, person.current_task()))


## Si una pieza de esta especie merece parar la partida, o basta con anotarla.
##
## La primera vez que la banda tumba un uro es un hito; la novena es el jueves.
## Ver `_told_species`.
func _worth_stopping_for(tale: Tale) -> bool:
	if tale.kind != Tale.Kind.CACERIA:
		return true
	if _told_species.has(tale.subject):
		return false
	_told_species[tale.subject] = true
	return true


## Y lo que se aprende a hacer. Lo llama [DemoMain] al desbloquearse.
func tell_technique(tech: TechTree.Tech) -> void:
	var job := TechTree.job_of(tech)
	var task := -1
	if job >= 0:
		task = Profession.task_id(job as Profession.Job,
			Profession.Speciality.NINGUNA)
	tell_tale(Tale.technique(tech, day, task))


# --- La caceria, vista ---------------------------------------------------
#
# Se mudo entera a `scripts/Caceria.gd`. Aqui queda el asa: quien acecha, a
# quien, y el paso de cada tick.

## El acecho y el lance, que viven en [Caceria].
##
## Se monta AQUI y no en `setup`: las pruebas construyen simulaciones a
## medias -gente y reservas, sin pasar por el montaje- y alli el asa se
## quedaba a null, asi que cualquier prueba que rozara la caza reventaba.
var caceria: Caceria = Caceria.new(self)


## Pasa un día por todas las trampas: cobran solas y se van gastando.
##
## Va en el cierre de jornada porque eso es lo que las hace distintas: una
## trampa trabaja mientras la banda duerme. Las que se han pasado de vida se
## retiran, y se cuenta —perder una línea de trampas en marzo es noticia.
func _age_traps() -> void:
	trampas.traps_set_today.clear()
	trampas.traps_lost_today.clear()
	if trampas.traps.is_empty():
		return

	var alive: Array[Trap] = []
	for trap: Trap in trampas.traps:
		trap.soaking += 1.0
		trap.worn += 1.0
		if trap.is_spent():
			trampas.traps_lost_today.append(trap)
			_note(Chronicle.Kind.PENURIA,
				"%s de %s se ha echado a perder en %s. Dio %d piezas."
					% [Trap.trap_name(trap.kind), trap.maker,
						parajes.place_name(trap.position, home_position),
						trap.taken], 0)
			continue
		alive.append(trap)
	trampas.traps = alive


# --- La linea de nasas ---------------------------------------------------
#
# Se mudo entera a `scripts/Nasas.gd`.

## Las nasas caladas, que viven en [Nasas]. Se monta aqui y no en `setup` por
## lo mismo que [caceria]: las pruebas construyen simulaciones a medias.
var nasas_line: Nasas = Nasas.new(self)


## Andar: trazar el camino, seguirlo y vigilar a quien no avanza. Ver [Marcha].
var marcha: Marcha = Marcha.new(self)
