class_name SettlementSim
extends Node3D
## Simula el asentamiento en el mapa local: gente concreta con rutina diaria.
##
## Los dos relojes del juego viven en escalas distintas y esto es el de abajo:
## el mapa local corre por DIAS, con la gente yendo y viniendo del tajo, y el
## regional por ESTACIONES, para estrategia y expediciones. Encaja con la
## arquitectura de dos escalas: cada capa simula lo que le corresponde.

signal day_passed(day: int)

## Ha cambiado la hora del reloj de la partida. Se emite DENTRO del paso de
## simulación, así que cae siempre en el mismo sitio de la partida corra la
## máquina como corra.
##
## Es para lo que tiene que ocurrir a horas de juego y no cada tantos
## fotogramas: el cotejo de cuevas descubiertas iba cada noventa fotogramas y
## escribe en la crónica, así que con fotogramas más rápidos la misma cueva se
## apuntaba a otra hora. Ver docs/specs/LO_MISMO_MAS_DEPRISA.md, paso 0.
signal hour_passed(day: int, hour: int)

## Un paso de simulación ha terminado ENTERO: la gente y la fauna ya han hecho
## lo suyo. Es el único punto donde la partida está en un límite limpio.
##
## La usan las sondas que guardan la partida: [day_passed] se emite DENTRO del
## paso —justo tras cerrar la jornada y ANTES de que la gente dé su tick—, así
## que una instantánea tomada ahí es media partida a medio paso, y al arrancar
## de ella se pierde la otra media. Ver docs/specs/LO_MISMO_MAS_DEPRISA.md,
## tarea 17.
signal paso_cerrado(day: int)

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

## Se ha aprendido una técnica, practicándola. La levanta el cierre de la
## jornada -ver [_practica_del_dia]- y la escucha quien la cuente: la escena la
## convierte en hito, relato y aviso de la interfaz.
signal tecnica_aprendida(tech: int)

## La banda se ha asentado en otra cueva. Lo escucha la vista, que tiene que
## mover la hoguera y los tajos a la casa nueva. Ver [Traslado].
signal campamento_trasladado(cueva: int)

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
## Cada cuantos pasos de simulacion piensa y anda la fauna.
##
## LA FAUNA ES UN INTEGRADOR, NO UNA DECISION POR TICK.
##
## Andar es `posicion += direccion * velocidad * delta`, y el hambre, la sed y
## los relojes del susto suben todos multiplicados por `delta`: cuatro pasos de
## `delta` y uno de `cuatro delta` dan lo mismo hasta el ultimo decimal en todo
## eso. Lo que NO da lo mismo es preguntarle al relieve: cada animal consulta
## dificultad de paso y altura en cada paso, y son seiscientos animales. Medido
## a velocidad de juego: 11,2 ms por paso, el 30 % del paso entero.
##
## Cuatro es el numero grande que todavia no se ve: a x1 la fauna se mueve
## siete veces y media por segundo, y lo que anda un ciervo entre dos de esas
## veces es menos de medio metro.
##
## Lo pendiente se acumula en `_fauna_pendiente` y se entrega entero, asi que
## la fauna no anda menos: anda a zancadas mas largas. Y va por pasos y no por
## reloj para que siga siendo repetible.
const PASOS_DE_FAUNA := 4

## Cuantos pasos de simulacion se han dado desde que la fauna penso por ultima
## vez, y cuanto tiempo le queda por andar. Ver [PASOS_DE_FAUNA].
var _pasos_de_fauna: int = 0
var _fauna_pendiente: float = 0.0

## Cuanto se espera antes de volver a pensar una jornada que no llevo a nada,
## en horas de juego. Seis minutos: quince ticks de simulacion.
##
## No es un numero de balanceo ni un umbral de decision: no cambia lo que se
## decide, solo cada cuanto se vuelve a preguntar lo mismo. Ver
## [Inhabitant.repensar_tras].
const ESPERA_PARA_REPENSAR := 0.1

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

## Cuanto cansa andar de noche, por hora, para quien vuelve tarde.
##
## QUIEN NO PUEDE ACAMPAR VUELVE SIEMPRE, llegue cuando llegue: no se acuesta en
## el monte porque se le haya hecho tarde. Peticion literal: «un habitante que
## no debe dormir fuera siempre intentara volver a la cueva, aunque llegue muy
## tarde; lo que hara sera dormir menos y por consiguiente peor, y empezar la
## jornada fatigado».
##
## Lo de dormir menos se cobra SOLO, sin regla nueva: el descanso va por horas
## dormidas -`fatigue -= hours * 9`- asi que quien entra a las dos de la manana
## descansa cuatro horas en vez de nueve y amanece cansado.
##
## Lo unico que hay que anadir es que andar de noche cansa MAS que andar de dia:
## se ve peor, se tropieza y no se para a descansar.
const CANSA_DE_NOCHE := 1.6


## Horas utiles de trabajo en una jornada, descontando la parada
const HORAS_UTILES := (HORA_REGRESO - HORA_SALIDA) - (HORA_FIN_MEDIODIA - HORA_MEDIODIA)

## Hasta donde se va a trabajar y se vuelve a dormir a casa, en metros.
##
## Novecientos. Estaba escrito a pelo dentro de `Tajo._rank_known_spots` con su
## razon al lado —«hay que ir, trabajar y volver antes de que anochezca»— y es
## la misma pregunta que se hace la batida, asi que tiene que ser el mismo
## numero y no dos.
##
## No sale de una cuenta y no puede salir: con [HORAS_UTILES] y la velocidad
## nominal darian quince kilometros, porque `Marcha.hours_to_walk` estima en
## llano y de vacio, y una jornada de verdad va cargada y por ladera. Este es de
## los de playtest.
##
## La caza no se rige por esto: sale avituallada y duerme donde caza. Ver
## [CAZA_LEJOS_M].
const RADIO_DE_JORNADA := 900.0

## Velocidad de la gente en llano, de vacio y por pasto, en unidades de mundo
## por segundo. Es la referencia: sobre ella actuan pendiente, suelo y carga.
##
## Calibrada CONTRA la duracion del dia, no a ojo: con 60 y una jornada util de
## 60 s reales, se alcanza algo menos de dos kilometros de ida. Descontando la
## vuelta y el tiempo de recoger, el radio util de una jornada queda en torno a
## 800 m, que es lo que da un forrajeo de radio corto de verdad.
## Lo que se anda por el llano, sin carga, en metros por segundo REAL.
##
## Con `seconds_per_day` a 120, una hora de juego son cinco segundos reales, así
## que esto por cinco son los metros que se cubren en una hora de juego. A 900
## salen 4.500 m/h, que es andar a cuatro kilómetros y medio por hora: lo que
## anda una persona por terreno llano. Con los factores del monte —pendiente,
## suelo, carga— se queda en unos 2,9 km/h efectivos, que es andar por el campo.
##
## Estuvo en 60, o sea 300 m por hora de juego: quince veces menos que una
## persona. Sumado al fallo de la cota de nieve —ver
## [TerrainGenerator.altura_relativa]— daba los 48 m/h medidos, y de ahí las
## siete horas para hacer trescientos metros.
##
## Lo que esto cambia no es sólo el reloj: con travesías realistas, el día se va
## en TRABAJAR y no en andar, y las reglas de volver antes de que anochezca
## pasan a decidir expediciones de kilómetros en vez de paseos de trescientos
## metros.
@export var walk_speed: float = 900.0

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

## Los topes con los que arranca una partida nueva, que el jugador cambia luego.
##
## **Decisión del usuario del 2026-09-13**: «es fundamental al empezar la partida
## poner límites a los materiales en el almacén, porque si no en unos cuantos
## días se llenan de morralla». Cincuenta de cada material, cien de leña y diez
## de cada pieza. La comida no lleva: tiene el suyo, el de la despensa
## (`food_cap`); ni el agua, que son odres llenos y no se recoge.
const TOPE_DE_MATERIAL := 50.0
const TOPE_DE_LENA := 100.0
const TOPE_DE_UTILLAJE := 10


func _poner_topes_de_partida() -> void:
	limits.clear()
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		if Materia.is_provision(k) or k == Materia.Kind.AGUA:
			continue
		limits[k] = TOPE_DE_LENA if k == Materia.Kind.LENA else TOPE_DE_MATERIAL
	taller.tool_orders.clear()
	for kind: int in Tool.Kind.values():
		taller.set_tool_order(kind as Tool.Kind, TOPE_DE_UTILLAJE)


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
## Las pasarelas levantadas. Aquí estaba `has_bridge`, un sí/no que abría
## TODOS los cauces del valle en cuanto se aprendía la técnica. Ver [Pasarelas]
## y EPOCA_01 §10.1, tanda 3, frente 13.
var pasarelas: Pasarelas = Pasarelas.new(self)

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

## Quién envejece, quién enferma de hambre o de frío, quién muere de vejez y
## quién nace. Ver [Relevo].
var relevo: Relevo = Relevo.new(self)

## Cómo se cierra la partida: victoria, derrota, o todavía nada. Ver [Partida].
enum Desenlace { NINGUNO, VICTORIA, DERROTA }
var desenlace: Desenlace = Desenlace.NINGUNO

## En qué jornada se decidió el desenlace. -1 mientras no haya ninguno.
var desenlace_dia: int = -1


## Si la partida ha terminado y el reloj ya no va a avanzar más.
##
## LA PREGUNTA VIVE AQUÍ Y EN UN SOLO SITIO, y no es una comodidad: es lo que
## costó diecisiete minutos de un núcleo entero sin escribir una línea de log.
##
## `_process` no avanza nada si `people` está vacía —no hay partida que simular
## sin banda—, así que `day` se queda clavado para siempre. Una sonda que
## espera con `while sim.day < hasta` está esperando una jornada que ya no va a
## llegar: gira en fotogramas vacíos hasta que alguien la mata a mano. Eso es
## exactamente lo que era el 🔴 «el cuelgue de la hambruna total», y no era un
## bucle del juego: era el instrumento esperando a un muerto.
##
## Quien espere jornadas pregunta esto y para. Ver `AnoProbe` y `CuelgueProbe`.
func partida_terminada() -> bool:
	return desenlace != Desenlace.NINGUNO or people.is_empty()

## Cuántos relatos pintados en la pared cuentan como "la cueva está pintada".
## Sin calibrar -pendiente de playtest, igual que el resto de umbrales de
## esta época.
const CUEVA_PINTADA_MINIMO := 3

## El objetivo, y qué pasa cuando se gana o se pierde. Ver [Partida].
var partida: Partida = Partida.new(self)

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

## Lo que el jugador quiere primero: materiales, especies y piezas. Ver
## [Prioridades] y SISTEMAS §22.
##
## No lleva referencia al simulador a propósito: es estado del jugador, no un
## subsistema con paso. Se toca por los tres pasamanos de abajo y no a pelo,
## porque cambiar un nivel de material obliga a reordenar los parajes.
var prioridades: Prioridades = Prioridades.new()


## Pone el nivel de un material y reordena los sitios conocidos.
##
## Lo segundo es la mitad del trabajo: la lista de parajes se puntúa una vez al
## día -ver [Tajo._rank_known_spots]-, así que sin rehacerla aquí el cambio no
## se notaría hasta la mañana siguiente y el jugador vería que su clic no hace
## nada.
func fijar_prioridad_material(kind: Materia.Kind, nivel: Prioridades.Nivel) -> void:
	prioridades.fijar_material(kind, nivel)
	tajo._rank_known_spots()


func fijar_prioridad_especie(species: String, nivel: Prioridades.Nivel) -> void:
	prioridades.fijar_especie(species, nivel)


func fijar_prioridad_pieza(kind: Tool.Kind, nivel: Prioridades.Nivel) -> void:
	prioridades.fijar_pieza(kind, nivel)

## Quien hay ahi fuera y que tal os llevais. Ver [Contacto].
var contacto: Contacto = Contacto.new(self)

## La salida larga, fuera del mapa. Ver [Expedicion].
var expedicion: Expedicion = Expedicion.new(self)

## Trueque con la banda vecina: sílex a cambio de lo que sobra. Ver
## [Intercambio].
var intercambio: Intercambio = Intercambio.new(self)

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
var cronista: Cronista = Cronista.new(self)

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

# Los caminos ya trazados ESTABAN AQUI -`_route_cache` y `_route_order`- y se
# mudaron a `BandKnowledge.veredas` el 2026-09-12: son lo que la banda sabe, no
# estado del simulador. Ver docs/SISTEMAS.md §18 y [Vereda].

# Y con ellos se fue `LANE_CELL`, que era la celda de esa memoria: hoy es
# `Vereda.CELDA`.


# --- lo que el taller comparte con el resto --------------------------------

## Cuantos pasos seguidos contra un obstaculo antes de volver a trazar.
##
## Treinta: medio segundo de reloj. Bastantes para que un roce con la orilla
## se resuelva solo con el esquive -que para eso esta- y pocos para que nadie
## se pase la jornada empujando una pared.
const BLOCKED_BEFORE_REPLAN := 30

## Cuantos pasos de LADO seguidos se consienten bordeando algo.
##
## Veinticuatro, que a paso de persona son unos pocos metros de orilla: lo que
## cuesta rodear un charco o una peña, que es para lo que esta el esquive.
##
## Hacia falta un tope porque el paso de lado mueve a la persona, y moverse
## reinicia la cuenta de `blocked_steps`: sin esto el esquive nunca dejaba paso
## al replanteo y alguien podia caminar la orilla de un rio de un lado para otro
## durante horas. Anda muchisimo y no se acerca nada, que es la definicion misma
## del ovillo que se veia en los rastros.
##
## Pendiente de playtest: subirlo deja bordear obstaculos mas largos, bajarlo
## manda a pedir camino antes.
const RODEOS_DE_ORILLA := 24

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
## La semilla con la que arranca todo lo que se lanza con `--script`.
##
## No es una cifra de balanceo: es «un numero cualquiera, pero SIEMPRE EL
## MISMO», que es lo que hace que dos corridas de una sonda se puedan comparar.
## Ver [_semilla_de_esta_corrida].
const SEMILLA_DE_SONDA := 42

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

## Hasta donde trabaja el taller antes de parar: la cobertura justa mas una
## reserva. Sin tope, un artesano acumula cientos de piezas inutiles.
##
## Aqui vivia ademas `CRAFT_PER_DAY`, las piezas por jornada de cada
## especialidad. Se borro el 2026-09-14: el esfuerzo pasa a ser de la pieza y
## esta en [Tool.HORAS_DE_TRABAJO]. Su comentario ya avisaba de que «una azagaya
## lleva dias», pero la cifra era la misma para la azagaya y para el punzon.
const RESERVA_UTILLAJE := 1.3

## Que fabrica cada especialidad.
const SPECIALITY_MAKES := {
	# La lampara va con la talla y no con la peleteria ni el asta: es un canto
	# ahuecado a golpes, o sea el mismo trabajo de piedra que una raedera.
	Profession.Speciality.TALLA: [Tool.Kind.LASCA, Tool.Kind.RAEDERA,
		Tool.Kind.BURIL, Tool.Kind.PUNTA, Tool.Kind.LAMPARA],
	Profession.Speciality.ASTA: [Tool.Kind.AZAGAYA, Tool.Kind.ARPON,
		Tool.Kind.AGUJA, Tool.Kind.PUNZON, Tool.Kind.ANZUELO],
	Profession.Speciality.PELETERIA: [Tool.Kind.ODRE, Tool.Kind.VESTIDO],
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
## tres mil, lo que puede gastar un fotograma en buscar caminos son unos
## veinticuatro milisegundos, y lo que no entre espera al siguiente.
##
## El tope de verdad no es este: es que la mayoria de las busquedas ya no
## llegan aqui. Las que van a un sitio incomunicado se resuelven comparando
## dos enteros, las repetidas salen de la cache, y «¿se llega desde casa?» se
## contesta leyendo el mapa de distancias -ver [Wayfinder.metros_desde]-.
##
## ESTUVO EN QUINIENTOS, y quinientos no daban ni para UNA busqueda: una sola
## puede costar miles de nodos, asi que el bote se agotaba con la primera y
## todo lo demas del cuadro se quedaba esperando. Mientras la cache tapaba el
## agujero -prestando caminos a quien no le servian- no se notaba; en cuanto se
## le exigio a la cache que el camino prestado valiera para el viaje, media
## banda se quedo plantada: medido, 353 atascos en ocho jornadas.
##
## Un tope que no deja pasar ni una unidad de lo que mide no es un tope: es un
## cerrojo. Tres mil dejan pasar unas pocas busquedas, que es lo que pide una
## manana en la que la banda entera sale a la vez.
const NODES_PER_FRAME := 500

var _path_nodes_this_frame: int = 0

## Cuanta gente sin camino se ha atendido ya este fotograma pasandose el
## presupuesto. Uno como mucho: sin este tope, la manana en que sale la banda
## entera son quince busquedas seguidas y se nota.
var _stranded_this_frame: int = 0

## El fuego del abrigo y lo que se hace a su alrededor. Ver [Hogar].
var hogar: Hogar = Hogar.new(self)

## Lo que se sabe de cada cueva, y quién está dentro. Ver [Exploracion].
var exploracion: Exploracion = Exploracion.new(self)

## Cómo se despide la banda de sus muertos, y dónde están. Ver [Sepulturas].
var sepulturas: Sepulturas = Sepulturas.new(self)

## Mudar el campamento a otra cueva. Ver [Traslado].
var traslado: Traslado = Traslado.new(self)


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

## Lo mismo, pero para `Inhabitant.cold`: el campo ya existe y ya entra en
## `effectiveness()`, pero hasta ahora nada de la simulación real le daba
## valor. Sube más despacio de lo que baja -misma asimetría que la
## proteína en `Despensa.pasar_cuenta_de_proteina`-: pasar frío se
## arrastra, entrar en calor es casi inmediato en cuanto vuelve el fuego o
## pasa el invierno.
const HEARTH_COLD_RISE := 4.0
const HEARTH_COLD_RECOVERY := 8.0


## Cuánto frío se coge por hora durmiendo SIN FUEGO a esa temperatura.
##
## Cero por encima de [Termometro.GRADOS_DE_ABRIGO]; por debajo, proporcional a
## cuánto se baja. Es la única pregunta «¿cuánto enfría esta noche?» del juego:
## la hacen la cueva y el raso, y antes ninguno de los dos miraba los grados —la
## cueva miraba si era invierno, y el raso **no tocaba el frío en absoluto**—.
##
## ## Calibrada para no mover lo que ya había
##
## La pendiente no se elige: se saca de que **una madrugada de invierno al nivel
## del mar dé exactamente [HEARTH_COLD_RISE]**, que es lo que el juego aplicaba
## antes a cualquier noche de invierno en la cueva. O sea que en ese punto el
## balance es el de siempre, y lo único que cambia es lo que antes no se veía:
## más arriba enfría más —el gradiente es físico, ver [Termometro]— y un abrigo
## alto puede coger frío también en otoño.
static func frio_por_hora(grados: float) -> float:
	var por_debajo := Termometro.GRADOS_DE_ABRIGO - grados
	if por_debajo <= 0.0:
		return 0.0
	var referencia := Termometro.grados(Subsistence.Season.INVIERNO, 3.0, 0.0)
	var pendiente := HEARTH_COLD_RISE / maxf(Termometro.GRADOS_DE_ABRIGO - referencia, 0.1)
	return por_debajo * pendiente


## Los grados que hace donde está esta persona, ahora.
func _grados_donde(person: Inhabitant) -> float:
	var cota := _terrain.get_height_at(person.position) if _terrain != null else 0.0
	return Termometro.grados(estacion as Subsistence.Season, hour, cota)


## Una hora de sueño, en cuanto al frío. `con_fuego` es el hogar en la cueva o
## la hoguera del vivac: con él se entra en calor, sin él se enfría por grados.
##
## El vestido se SUMA al fuego, no lo sustituye: con cobertura completa se pasa
## menos frío, pero sin fuego y sin vestido sigue siendo lo peor.
func _frio_de_una_noche(person: Inhabitant, hours: float, grados: float,
		con_fuego: bool) -> void:
	var frio := frio_por_hora(grados)
	if con_fuego or frio <= 0.0:
		person.cold = maxf(person.cold - hours * HEARTH_COLD_RECOVERY, 0.0)
		return
	var abrigo := 1.0 - vestido_coverage() * VESTIDO_COLD_MITIGATION
	person.cold = clampf(person.cold + hours * frio * abrigo, 0.0, 100.0)

## Cuánto se gasta cada `VESTIDO` por JORNADA DE CALENDARIO, se trabaje o no
## con él. A diferencia del resto del utillaje -que sólo se desgasta cuando
## alguien lo usa en una tarea, ver `Tool.WEAR_PER_DAY`-, una prenda se lleva
## puesta todo el rato: el desgaste no depende de la actividad, depende de
## los días. Con `Tool.DURABILITY[Stuff.PIEL]` (80 usos) esto da algo más de
## dos estaciones por prenda antes de tener que coser otra.
const VESTIDO_WEAR_PER_DAY := 0.6

## Cuánto de `HEARTH_COLD_RISE` cancela la cobertura de vestido COMPLETA (una
## prenda por persona). No es 1.0 a propósito: el vestido se suma al hogar,
## no lo sustituye -dormir sin fuego y sin vestido sigue siendo lo peor-.
const VESTIDO_COLD_MITIGATION := 0.6

## Fatiga y frío de más por hora que se lleva quien duerme en un abrigo por
## encima de `plazas_abrigo()`. Más suaves que `HEARTH_COLD_FATIGUE`/
## `HEARTH_COLD_RISE` a propósito -apretujarse molesta menos que pasar frío
## de verdad-, y se suman a lo que ya toque por hogar y estación: no
## sustituyen esos contadores, los alimentan.
const ABARROTADO_FATIGUE_RISE := 1.5
const ABARROTADO_COLD_RISE := 1.5

## Piel de tienda por persona. NO se gasta: se lleva y se devuelve al abrigo,
## que es lo que se hace con una tienda. Lo que se pierde es la noche que no se
## llevó.
##
## **Piel CURTIDA** desde el 2026-09-13, decisión del usuario: la cruda se pudre
## en doce días —en la mochila también— y se gastaba en tiendas mientras no se
## curtía ninguna. La cruda queda para curtirla y para el trueque.
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

## --- Rachas de hambre severa, para decidir si el año fue bueno -----------
##
## No es lo mismo hambre puntual -un día flojo- que hambre sostenida: lo que
## de verdad amenaza a la banda es una racha larga, no un pico suelto. Se
## lleva aparte de `Inhabitant.hunger`, que es individual, porque esto mide
## a la BANDA: el hambre media de todos, no la de cualquiera en concreto.
## Ver `docs/specs/QUE_SE_PUEDA_PERDER.md`, tarea 8, y `Relevo` para dónde se
## usa al cerrar el año.

## A partir de qué hambre MEDIA de la banda se cuenta como "severa".
const HAMBRE_SEVERA_UMBRAL := 60.0

## Jornadas SEGUIDAS que la banda lleva con hambre media severa ahora mismo.
## Se resetea en cuanto la media vuelve a bajar del umbral.
var hambre_severa_racha: int = 0

## La racha más larga que ha habido en lo que va de año. `_advance_local_season`
## la lee para decidir "año bueno" y la pone a cero al empezar el siguiente.
var hambre_severa_peor_racha_del_anyo: int = 0


## Se llama una vez al cerrar la jornada, desde `_end_of_day`.
func _revisar_hambre_de_la_banda() -> void:
	if people.is_empty():
		hambre_severa_racha = 0
		return
	var total := 0.0
	for person: Inhabitant in people:
		total += person.hunger
	var media := total / float(people.size())

	if media >= HAMBRE_SEVERA_UMBRAL:
		hambre_severa_racha += 1
		hambre_severa_peor_racha_del_anyo = maxi(
			hambre_severa_peor_racha_del_anyo, hambre_severa_racha)
	else:
		hambre_severa_racha = 0


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

## Donde se pinta cada persona. Ver [Figuras]: la simulacion dice donde esta, y eso dice
## donde se le dibuja. Vale null en las pruebas, que montan la simulacion sin vista.
var figuras: Figuras = null
var _rng := RandomNumberGenerator.new()


## Arranca con la poblacion y las reservas que trae la partida
## Con que semilla arranca esta corrida.
##
## Tres casos, y el de en medio es el que costo aprender:
##
##   - `SEMILLA=123` en el entorno manda siempre. Es como se repite una partida
##     concreta y como se comparan dos variantes.
##   - **Si esto se lanzo con `--script`, o sea una sonda o la suite, la
##     semilla es [SEMILLA_DE_SONDA] y no el reloj.** Una medida es una medida:
##     dos corridas de la misma sonda tienen que ser la misma partida o no hay
##     nada que comparar.
##   - Jugando, el reloj. Cada partida, distinta. Estuvo clavada en una fecha y
##     la comarca entera se comportaba igual siempre: los mismos picos en el
##     mismo orden, los mismos percances, el mismo tiempo.
##
## ## Por que el caso de en medio es el DEFECTO y no algo que pida cada sonda
##
## Porque se pedia y no se hacia. Ninguna sonda del repositorio fijaba la
## semilla —ni `AtascoProbe`, ni `RodeoProbe`, ni `TironAnualProbe`— y el aviso
## vivia aqui, en un comentario que hay que leer antes de medir. Medido el
## 2026-09-12: `AtascoProbe` sin semilla, ocho jornadas, sin tocar una linea de
## codigo entre corridas, dio 2.200, 1.747, 303 y 219 pasos cortados; con
## semilla fija da 2.295 dos veces seguidas, exacto. Sobre aquellas cifras se
## llegaron a escribir dos conclusiones falsas en ESTADO.md.
##
## Un aviso que hay que acordarse de seguir no es una garantia. Esto si.
##
## Si alguna sonda quiere de verdad varias tiradas, `SEMILLA=azar` le devuelve
## el reloj; y para barrer varias, se le pasa cada una a mano, que es lo que
## hay que hacer para poder promediar.
func _semilla_de_esta_corrida() -> int:
	var puesta := OS.get_environment("SEMILLA")
	if puesta == "azar":
		return int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
	if not puesta.is_empty():
		return int(puesta)
	if OS.get_cmdline_args().has("--script"):
		return SEMILLA_DE_SONDA
	return int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff


func setup(terrain: TerrainGenerator, home: Vector3, population: int, food: float) -> void:
	_terrain = terrain
	# La nieve sale del termómetro en metros, y se pinta y se anda en fracción
	# del relieve: sin esto no se sabe dónde cae. Ver [Temporada.relieve].
	if terrain != null:
		temporada.relieve = terrain.get_height_range()
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
	#
	# Y SE FIJA SOLA CUANDO ESTO NO ES UNA PARTIDA, SINO UNA MEDIDA. Ver
	# [_semilla_de_esta_corrida].
	game_seed = _semilla_de_esta_corrida()
	_rng.seed = game_seed
	print("Semilla de partida: %d" % game_seed)

	# `NOCHE=0` apaga el saltarse la noche, y esta aqui por lo mismo que
	# `SEMILLA`: la corrida que demuestra que acelerar NO cambia la partida
	# necesita la pareja, con y sin, y no se le puede pedir a cada sonda que se
	# invente el interruptor. Ver [noche_acelerada].
	noche_acelerada = OS.get_environment("NOCHE") != "0"

	toolkit = Toolkit.new()
	for entry: Dictionary in UTILLAJE_INICIAL:
		for i in range(int(entry["cuantas"])):
			toolkit.craft(int(entry["kind"]) as Tool.Kind,
				int(entry["stuff"]) as Tool.Stuff, 0.5)
	_poner_topes_de_partida()
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
	# DONDE SE DIBUJA CADA UNO, que no siempre es donde esta: los viajes largos se
	# abrevian en la vista para que se vea a la gente andar (GRAFICOS §7.6). No cambia
	# nada de la partida; solo la pose que recibe la multitud.
	figuras = Figuras.new()
	figuras.name = "Figuras"
	# ANTES QUE NADIE EN EL CUADRO. Godot procesa por prioridad y, a igualdad, de padre a
	# hijo: `DemoMain` es la raiz, asi que su `_process` -donde la camara sigue a la
	# persona elegida, INTERFAZ §13- corria ANTES de que esto moviera las figuras, y la
	# camara iba un cuadro por detras de lo que se dibujaba. Medido: **54 m de desvio**,
	# que es lo que anda alguien entre dos cuadros a x1. Con la prioridad por delante, lo
	# que se dibuja esta puesto cuando lo lee quien sea.
	figuras.process_priority = -10
	figuras.crowd = _crowd
	figuras.sim = self
	add_child(figuras)
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

## EL FRENO DE LA VISTA: cuantos pasos se dan por segundo real, en fraccion.
##
## 1,0 es lo de siempre; 0,05 es veinte veces mas despacio. Lo pone la vista
## -[CamaraLenta], desde `DemoMain`- cuando la camara se acerca, y aqui solo se
## guarda: `scripts/sim/` no le pregunta nada a `scripts/vista/`.
##
## **FRENA CUANTOS PASOS SE DAN, NO CUANTO DURA CADA UNO**, y ahi esta todo. Bajar
## `time_scale` pareceria lo mismo y no lo es: `_advance` multiplica por el, asi que
## cambiaria cuanta hora de juego avanza cada paso -y con ella el instante en que salta
## `hour_passed` y el trozo de fauna que entrega `_fauna_pendiente`-, o sea que seria OTRA
## PARTIDA. Multiplicando el reloj real que entra en `_pendiente`, la sucesion de
## `_advance` es identica y solo se reparte en mas fotogramas. Es la misma distincion que
## la noche acelerada, al reves. Ver SPECS §3.1 y GRAFICOS §7.6.
##
## La noche NO se frena: de noche no hay a nadie mirando trabajar.
var freno_de_la_vista: float = 1.0

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

## Si ahora mismo no hay NADIE trabajando, que es cuando no hay nada que mirar.
##
## Una pregunta, un sitio -invariante 3 de SPECS.md §7-, porque la van a
## preguntar la aceleracion de la noche y, el dia que se enseñe, la interfaz.
##
## ## Es «nadie trabaja» y no «todos duermen», y a eso se llego MIDIENDO
##
## Se construyo primero con la lectura estricta -todos en `DURMIENDO`- y al
## probarlo en el juego la noche seguia yendo lenta. Medido con `PicoProbe`,
## `VEL=5`, 4 jornadas, la misma maquina y la misma sesion:
##
##   sin saltarse la noche ......... 90 s
##   con «todos duermen» ........... 71 s
##   con «nadie trabaja» ........... 62 s
##
## El motivo es que la banda no se acuesta a la vez: se va acostando, y el que
## vuelve andando del monte bloqueaba la aceleracion durante toda esa hora
## larga. La spec decia «cuando nadie esta trabajando» desde el principio
## -EPOCA_01 §10.1, frente 2-; la lectura estricta era mia.
##
## **El que vivaquea entra solo**, que es el criterio explicito de la spec: si
## no contara, un solo cazador a tres kilometros bloquearia la noche entera.
##
## Frenan `TRABAJANDO`, `BUSCANDO` y `RECONOCIENDO`: son los tres estados en
## los que pasa algo que el jugador puede querer ver. Andar, comer y dormir no.
func nadie_trabaja() -> bool:
	if people.is_empty():
		return false
	for person: Inhabitant in people:
		match person.state:
			Inhabitant.State.TRABAJANDO, Inhabitant.State.BUSCANDO, 			Inhabitant.State.RECONOCIENDO:
				return false
	return true


## Cuántas horas de juego tiene que pasar la noche por cada segundo de reloj, con
## la banda dormida, y lo más que se le deja comer de un fotograma.
##
## **Diez horas en dos segundos, a cualquier velocidad**: decisión del usuario del
## 2026-09-14, «no está pasando las noches rápido cuando todos se van a dormir».
## Era un presupuesto fijo de 8 ms por cuadro —abajo, medido para no dar tirones—
## y con ventana no se notaba: dibujar un cuadro cuesta más de 30 ms, y a la
## resolución del usuario mucho más, así que 8 ms de pasos eran poco al lado. Con
## `NocheCimaPasarelaProbe` y ventana a 1080p, x5: una hora de noche costaba
## 450 ms de reloj contra 1 000 de día. Ahora se dan pasos hasta cubrir la noche
## que le toca a este cuadro, con [MS_DE_NOCHE_TOPE] de techo: el fotograma malo
## sigue acotado —el frente 4—, sólo que más arriba, y de noche no hay nada que
## mirar.
##
## Sigue sin ser un multiplicador de `time_scale`, y la diferencia es el frente 4
## entero:
##
## Acelerar subiendo `time_scale` cambiaria cuanta hora de juego avanza cada
## paso, y con ella el instante en que salta `hour_passed` y el tamaño del
## trozo de fauna que entrega `_fauna_pendiente`: **seria otra partida**. Lo
## que se hace es dar MAS PASOS DEL MISMO TAMAÑO, asi que la sucesion de
## `_advance` es identica a la de una corrida sin acelerar y la firma diaria
## sale igual POR CONSTRUCCION, no por suerte.
##
## Y como es un presupuesto de cuadro y no una velocidad, la noche corre «a
## todo lo que de» en la maquina que sea y **el fotograma malo queda acotado
## por arriba**, que es justo lo que el frente 4 pide. El precedente es
## [HornoDeRejillas.MS_POR_CUADRO], que amasa rejillas con la misma idea.
##
## ## El 8 esta medido, y el barrido dice que mas no compra nada
##
## `PicoProbe`, VEL=5, 4 jornadas, con «nadie trabaja». Reloj de las 4 jornadas
## y fotograma medio:
##
##   4 ms ..... 66 s · 39,9 ms          24 ms .... 60 s · 42,5 ms
##   8 ms ..... 62 s · 41,0 ms          48 ms .... 59 s · 45,1 ms · 14 tirones
##   16 ms .... 62 s · 41,4 ms          96 ms .... 58 s · 46,7 ms · 70 tirones
##
## El ahorro se agota en 8: de ahi en adelante se compran uno o dos segundos y
## se paga en fotograma medio, y pasados los 24 en tirones. Por debajo, se
## pierde ahorro. Contra los 90 s de no saltarse la noche, **8 ms ahorra el
## 31 % del reloj**. Aquella medida era sin ventana y a VEL=5; con ventana, ver
## arriba.
const NOCHE_HORAS_POR_SEGUNDO := 5.0
const MS_DE_NOCHE_TOPE := 60.0

## Si la noche se salta. Se apaga PARA MEDIR, no para jugar.
##
## Hace falta porque la comparacion que prueba que esto no cambia la partida
## -misma semilla, misma firma diaria- necesita las dos corridas, con y sin. Y
## porque una prueba que mida cuanta hora de juego cabe en un segundo de reloj
## deja de tener respuesta fija en cuanto la noche corre sola.
##
## No es estado de partida: no lo lee nada de la simulacion, solo este bucle.
var noche_acelerada: bool = true

## El tiempo real que aun no se ha simulado.
var _pendiente := 0.0


## Si alguien mira este campamento: si no, no se pintan los cuerpos.
##
## Pintar a cada persona en la multitud es vista y no partida —mueve una malla,
## no un número—, pero se hacía dentro del tick: medido con el cepo, un 7 % de lo
## que cuesta la gente, en campamentos que nadie ve (ESTADO §2). Verdadero por
## defecto, que es como se comporta la escena de siempre.
var se_mira: bool = true


## Si los pasos los da un [RelojDeLaPartida] y no esta simulacion.
##
## Falso por defecto, que es como se comporta una simulacion sola —las pruebas,
## las sondas de un mapa—: da sus pasos en su `_process`, como siempre.
var dirigido: bool = false

## La estación y el año de ESTE campamento.
##
## La fecha es de la partida y vive en `GameState`, pero **un campamento que lleva
## el reloj de la partida lee y gira su copia**, y el reloj publica la del primero
## en `GameState` entre pasos. Es lo que permitirá dar los pasos en paralelo: si
## cada campamento girase la global, uno la leería mientras otro la cambia. Una
## simulación suelta —las pruebas, las sondas, la escena de un mapa— lee la
## global como siempre, y por eso nada cambia para ella. Ver [RelojDeLaPartida] y
## SISTEMAS §23, «un hilo por campamento».
var estacion: Subsistence.Season:
	get:
		return _estacion if dirigido else GameState.season
var anyo: int:
	get:
		return _anyo if dirigido else GameState.year
var _estacion: Subsistence.Season = Subsistence.Season.PRIMAVERA
var _anyo: int = 1

## Si este campamento gira también la fecha de la partida (`GameState`). Sólo uno:
## el primero del reloj. Los demás giran su copia, que con la misma fecha es la
## misma. Verdadero por defecto, que es lo que hace una simulación sola.
var publica_la_fecha: bool = true


## El nombre del campamento al que pertenece esta simulación —el de su sitio—.
## Vacío en una simulación suelta. Lo pone [Campamento]; va en las decisiones y en
## la crónica cuando hay varios campamentos (SISTEMAS §23, punto 7).
var nombre_del_campamento: String = ""

## El sitio de la comarca donde está este campamento: desde donde sale una
## expedición. Lo pone quien monta el campamento —ver [Campamento]—.
var sitio: Site = null


## Lo que ha descubierto de la comarca este campamento y todavía no está en la
## partida. Un campamento dirigido no escribe `GameState.discovered` a mitad de
## paso —otro podría estar leyéndolo—: lo apunta aquí y el reloj lo junta entre
## pasos. Ver [descubrir] y SISTEMAS §23, «un hilo por campamento».
var descubrimientos: Array[Site] = []


## Si este sitio está descubierto: en la partida, o apuntado aquí.
func descubierto(site: Site) -> bool:
	return GameState.is_discovered(site) or descubrimientos.has(site)


## Descubre un sitio. Suelta, en la partida al momento, como siempre; dirigida,
## en la cola, y el reloj lo pasa. Contando lo apuntado en [descubierto], una
## expedición ve lo mismo que veía con un solo campamento.
func descubrir(site: Site) -> void:
	if dirigido:
		if not descubrimientos.has(site):
			descubrimientos.append(site)
	else:
		GameState.discover(site)


## Lo que este campamento ha avistado desde una cumbre y todavía no está en la
## partida, por lo mismo que [descubrimientos]. Ver [avistar].
var avistamientos: Array[Site] = []


## Avista un yacimiento. Suelta, en la partida al momento; dirigida, en la cola, y el
## reloj lo pasa en la barrera.
func avistar(site: Site) -> void:
	if dirigido:
		if not avistamientos.has(site):
			avistamientos.append(site)
	else:
		GameState.avistar(site)


## Lo que este campamento ha visto de la comarca y todavía no está en la niebla de
## la partida, por lo mismo que [descubrimientos]: formas de
## [GameState.levantar_niebla], que el reloj levanta entre pasos.
var niebla_por_levantar: Array[Dictionary] = []


## Levanta niebla. Suelta, al momento; dirigida, en la cola.
func levantar_niebla(forma: Dictionary) -> void:
	if dirigido:
		niebla_por_levantar.append(forma)
	else:
		GameState.levantar_niebla(forma)


func cuantos_descubiertos() -> int:
	var cuantos := GameState.discovered.size()
	for site: Site in descubrimientos:
		if not GameState.is_discovered(site):
			cuantos += 1
	return cuantos


func _init() -> void:
	# Los parajes leen la estación de este campamento, no la global. Ver
	# [Parajes.fecha].
	parajes.fecha = self


func _process(delta: float) -> void:
	# Mientras se carga, nada: ni la partida ni el horno, que le quitaría el cuadro a la
	# carga. El tiempo de esos cuadros se tira. Ver [RelojDeLaPartida._process].
	if Carga.abierta():
		return
	# El horno amasa SIEMPRE, aunque el reloj este parado: si no, una partida en
	# pausa no adelantaria trabajo y al reanudar seguiria faltando la rejilla
	# del trimestre que viene. Cuatro milisegundos por cuadro, ver
	# [HornoDeRejillas.MS_POR_CUADRO].
	Cronometro.tramo_raiz("simulacion (SettlementSim)")
	marcha.nuevo_cuadro()
	Cronometro.tramo("horno de rejillas")
	horno.amasar()
	Cronometro.cierra("horno de rejillas")
	# CON VARIOS CAMPAMENTOS LOS PASOS LOS DA EL RELOJ DE LA PARTIDA, a todos por
	# igual: si cada simulacion los diera aqui por su cuenta, en cuanto una
	# saltara la noche y otra no dejarian de estar en la misma hora. El horno si
	# sigue aqui: amasar no cambia la partida. Ver [RelojDeLaPartida].
	if dirigido:
		Cronometro.cierra("simulacion (SettlementSim)")
		return
	if people.is_empty() or _terrain == null or time_scale <= 0.0:
		Cronometro.cierra("simulacion (SettlementSim)")
		return
	# El freno de la vista entra AQUI y en ningun otro sitio: menos reloj real por
	# simular, o sea menos pasos, todos del mismo tamaño. Ver [freno_de_la_vista].
	_pendiente += delta * clampf(freno_de_la_vista, 0.0, 1.0)
	var dados := 0
	while _pendiente >= PASO_FIJO and dados < PASOS_POR_CUADRO:
		_pendiente -= PASO_FIJO
		dados += 1
		Cronometro.tramo("paso de simulacion")
		_advance(PASO_FIJO)
		Cronometro.cierra("paso de simulacion")
		# SI EL RELOJ SE PARA A MITAD DE FOTOGRAMA, AQUI SE ACABA.
		#
		# Una decision para el reloj -[Moment]- se levanta DESDE DENTRO de un
		# paso y la interfaz pone la velocidad a cero ahi mismo. Los pasos que
		# le quedaban al fotograma se daban igual, con `scaled` a cero: un tick
		# de cada persona sin que pase el tiempo, y cuantos de esos se daban
		# dependia de cuantos pasos le quedaran al fotograma. Lo pendiente NO
		# se pierde -sigue en `_pendiente`- y se hace al reanudar.
		if time_scale <= 0.0:
			break

	# Y AQUI SE SALTA LA NOCHE.
	#
	# Con todos durmiendo no hay nada que mirar, asi que se siguen dando pasos
	# -del MISMO tamaño- hasta cubrir la noche que le toca a este cuadro o gastar
	# el tope, ver [NOCHE_HORAS_POR_SEGUNDO]. Lo que avanza de mas no sale de `_pendiente`:
	# `_pendiente` es reloj real por simular y esto es reloj de juego regalado,
	# que es en lo que consiste saltarse la noche.
	#
	# Se relee `nadie_trabaja` en cada vuelta porque alguien se despierta
	# dentro de un paso -a las seis-, y desde ese paso ya no se acelera.
	if noche_acelerada and nadie_trabaja():
		var hasta := Time.get_ticks_usec() + int(MS_DE_NOCHE_TOPE * 1000.0)
		var dia_al_entrar := day
		# Lo que le toca a este cuadro, en horas, y lo que da cada paso. **Sin el freno
		# de la vista**: la camara lenta es para ver trabajar, y de noche no trabaja
		# nadie (GRAFICOS §7.6).
		var faltan := delta * NOCHE_HORAS_POR_SEGUNDO
		var por_paso := PASO_FIJO * time_scale / seconds_per_day * 24.0
		Cronometro.tramo("noche acelerada")
		while time_scale > 0.0 and faltan > 0.0 and Time.get_ticks_usec() < hasta:
			_advance(PASO_FIJO)
			faltan -= por_paso
			# EL CIERRE DE JORNADA CORTA EL CUADRO, y esto no es cosmetica: el
			# peor fotograma de la partida ES la contabilidad de medianoche
			# -medido, 113 ms de los que 42 son el cierre, ESTADO.md §2- y la
			# medianoche cae justo dentro de la noche acelerada. Sin este
			# corte, ese fotograma se come ademas el presupuesto entero.
			if day != dia_al_entrar:
				break
			if not nadie_trabaja():
				break
		Cronometro.cierra("noche acelerada")
	Cronometro.cierra("simulacion (SettlementSim)")


## Un paso de simulacion. Siempre del mismo tamaño: ver [PASO_FIJO].
func _advance(delta: float) -> void:

	_path_nodes_this_frame = 0
	_stranded_this_frame = 0

	var scaled := delta * time_scale
	var hours := scaled / seconds_per_day * 24.0
	var hora_antes := int(hour)
	hour += hours
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		Cronometro.tramo("cierre de jornada")
		_end_of_day()
		Cronometro.cierra("cierre de jornada")
		day_passed.emit(day)
	# EL REPASO DE REZAGADOS, A CADA HORA DE LUZ Y NO A MEDIANOCHE.
	#
	# Una vuelta de reconocimiento levanta un circulo entero y solo bautiza un
	# sitio -ver [Reconocimiento.DE_UNA_VUELTA]-; lo que queda esperando se
	# recogia al cerrar la jornada, o sea a las 00:00, que es la queja: «no se
	# debe esperar hasta media noche para mostrarlo». Repasando cada hora de
	# luz, la cola se va vaciando mientras la banda trabaja, que es cuando se
	# descubren las cosas.
	elif int(hour) != hora_antes and hour >= HORA_DESPERTAR 			and hour < HORA_DORMIR:
		Cronometro.tramo("repaso de rezagados")
		reconocimiento.repasar_rezagados()
		Cronometro.cierra("repaso de rezagados")

	# Y LA HORA SE DICE, para todo lo que tiene que ocurrir a horas de juego y
	# no cada tantos fotogramas. Ver [hour_passed]. Va tambien en el cambio de
	# dia, donde la hora entera pasa de 23 a 0.
	if int(hour) != hora_antes:
		hour_passed.emit(day, int(hour))


	# El tick se parte en trozos para que acelerar no cambie el resultado: con
	# un solo paso largo la gente atraviesa obstaculos que a velocidad normal
	# la pararian.
	var steps := maxi(int(ceil(time_scale)), 1)
	var slice := scaled / float(steps)
	var slice_hours := hours / float(steps)
	Cronometro.tramo("gente (todos los ticks)")
	for _s in range(steps):
		for i in range(people.size()):
			# LA BANDA SE ESTÁ MUDANDO: todos andan hacia la cueva nueva y nadie
			# trabaja. Ver [Traslado].
			if traslado.en_marcha():
				traslado.andar(people[i], i, slice_hours, slice)
				continue
			# QUIEN ESTA DE EXPEDICION NO ESTA EN EL MAPA. No anda, no come de la
			# despensa -comio al salir, ver [Expedicion.mandar]- ni trabaja: ha
			# salido de los cuatro kilometros. Simularlo aqui seria tenerlo
			# paseando por un valle del que se ha ido.
			if people[i].esta_de_expedicion(day):
				# Los que todavía van andando hacia el borde del valle SÍ se
				# mueven: se les ve irse. Los que ya están fuera, no.
				expedicion.andar(people[i], i, slice_hours, slice)
				continue
			_tick_person(people[i], i, slice_hours, slice)
	Cronometro.cierra("gente (todos los ticks)")

	# LA FAUNA, EN EL MISMO PASO Y DESPUÉS DE LA GENTE. Pensaba y andaba en su
	# propio `_process`, con el `delta` del fotograma, fuera del paso fijo, y la
	# cacería la lee: la misma semilla no daba la misma caza. Gente primero y
	# fauna después es el orden que ya había, porque `DemoMain` cuelga la
	# simulación antes que la fauna y su `_process` corría antes en cada
	# fotograma. Ver `WildlifeHerds.avanzar` y
	# docs/specs/LO_MISMO_MAS_DEPRISA.md, tarea 8.
	#
	# Y DE CUATRO PASOS EN CUATRO, no uno por paso. Ver [PASOS_DE_FAUNA].
	if caceria != null and caceria.wildlife != null:
		_pasos_de_fauna += 1
		_fauna_pendiente += scaled
		if _pasos_de_fauna >= PASOS_DE_FAUNA:
			Cronometro.tramo("fauna (en el paso)")
			caceria.wildlife.avanzar(_fauna_pendiente)
			Cronometro.cierra("fauna (en el paso)")
			_pasos_de_fauna = 0
			_fauna_pendiente = 0.0

	# Y el paso queda cerrado. Ver [paso_cerrado].
	# Si la banda se estaba mudando y han llegado todos, se asienta. Con el paso
	# cerrado, que es el único límite limpio de la partida (SPECS §3).
	traslado.revisar()
	paso_cerrado.emit(day)


## Cuanto suben los rasgos fisicos por el uso, por hora. Muchisimo mas lento
## que la destreza -esta es una vida, no una temporada- y por eso los
## numeros son minusculos: con estos ritmos, notarse de verdad lleva años de
## partida, que es justo lo que tiene que costar cambiar el cuerpo de nadie.
const FUERZA_TRAINING_RATE := 0.00004
const RESISTENCIA_TRAINING_RATE := 0.00003

## A partir de cuanta fatiga trabajar cuenta como aguantar de verdad. Por
## debajo de esto es una jornada normal, no un esfuerzo que curta.
const RESISTENCIA_TRAINING_THRESHOLD := 55.0


## LA JORNADA DE UNA PERSONA VIVE EN [Rutina] (ARQUITECTURA §3.2). Aqui quedan los
## pasamanos de lo que llamaban desde fuera y las constantes que se pedian por esta clase:
## la regla 3 del troceado dice que no se reescriben las llamadas de fuera.
var rutina := Rutina.new(self)

## Lo que se aprende por hora de trabajo. Se pide por la clase. Ver [Rutina].
const APRENDE_POR_HORA := Rutina.APRENDE_POR_HORA
const KM_PER_EXTRA_DAY := Rutina.KM_PER_EXTRA_DAY
const SAFETY_MARGIN_DAYS := Rutina.SAFETY_MARGIN_DAYS
const EXPEDITION_SKILL_DAYS_RANGE := Rutina.EXPEDITION_SKILL_DAYS_RANGE
const REST_BEFORE_EXPEDITION := Rutina.REST_BEFORE_EXPEDITION
const LLEGADA_MAXIMA := Rutina.LLEGADA_MAXIMA


## El tick de una persona. Ver [Rutina._tick_person].
func _tick_person(person: Inhabitant, index: int, hours: float, delta: float) -> void:
	rutina._tick_person(person, index, hours, delta)


func _tick_routine(person: Inhabitant, hours: float, delta: float,
		night: bool) -> void:
	rutina._tick_routine(person, hours, delta, night)


func _tick_daylight(person: Inhabitant, hours: float) -> void:
	rutina._tick_daylight(person, hours)


func _decide_the_day(person: Inhabitant, hours: float) -> void:
	rutina._decide_the_day(person, hours)


func _radio_de_llegada(hours: float) -> float:
	return rutina._radio_de_llegada(hours)


func _ultima_salida(person: Inhabitant) -> float:
	return rutina._ultima_salida(person)


## Si este estado cuenta como trabajar. Estatica, y se sigue pidiendo por esta clase.
static func cuenta_como_trabajo(state: int) -> bool:
	return Rutina.cuenta_como_trabajo(state)


## Levanta un momento: algo que hay que enseñar o decidir ahora. Ver [Moment].
func raise_moment(moment: Moment) -> void:
	moment.desde = self
	# DENTRO DEL PASO DE UN CAMPAMENTO DIRIGIDO NO SALE: se guarda y el reloj la
	# entrega en la barrera, al acabar la vuelta. Un jugador nunca contesta a
	# mitad de paso —la tarjeta para el reloj y se contesta entre pasos—, y con
	# varios campamentos la barra es una sola. Decisión del usuario del
	# 2026-09-14, aunque cambie la partida de las sondas, que contestaban dentro
	# del paso. Ver [RelojDeLaPartida] y SISTEMAS §23.
	if dirigido and _en_paso:
		momentos_pendientes.append(moment)
		return
	moment_raised.emit(moment)


## Las decisiones que esperan a la barrera. Ver [raise_moment].
var momentos_pendientes: Array[Moment] = []

## Si esta simulación está dando un paso del reloj ahora mismo.
var _en_paso: bool = false


## Saca las decisiones guardadas, en el orden en que se levantaron. Lo llama el
## reloj en la barrera.
func entregar_momentos() -> void:
	if momentos_pendientes.is_empty():
		return
	var lista := momentos_pendientes.duplicate()
	momentos_pendientes.clear()
	for moment: Moment in lista:
		moment_raised.emit(moment)


## Dispara el momento inicial (objetivo, derrota posible, primera decisión).
##
## Quien monta la escena lo llama a mano, DESPUÉS de que la interfaz ya esté
## escuchando `moment_raised` -si se llamara desde `setup()`, que corre antes
## de `ui.barra.watch_moments`, se perdería sin avisar a nadie. Ver
## [Partida.momento_inicial] y docs/specs/QUE_FALTA_PARA_JUGARLO.md.
func iniciar_partida() -> void:
	raise_moment(partida.momento_inicial())
	# Y SE CITA LA DECISIÓN DE LA ESTACIÓN EN QUE SE EMPIEZA. Las decisiones se
	# citan al CAMBIAR de estación, y la partida empieza ya dentro de la
	# primavera: sin esto, la de primavera del primer año —mandar la
	# expedición— no salía nunca, la primera expedición esperaba al año 2 y el
	# primer año tenía tres decisiones y no cuatro. Lo destapó la prueba de humo
	# de la pasada larga, antes de lanzarla.
	_citar_la_decision()


## Primer y último día de la estación en que puede caer su decisión.
##
## El segundo mes: así se decide **habiendo vivido** la estación —cómo se ha
## salido del invierno, qué ha dado la primavera— y no el primer día, a ciegas.
## Decisión del usuario del 2026-09-13: «a lo largo del 2º mes, ± 7 días».
const DECISION_PRIMER_DIA := 16
const DECISION_ULTIMO_DIA := 30

## El día de ESTA estación en que salta su decisión, contando desde 1. Cero
## mientras no hay ninguna citada -ya salió, o no había qué decidir-.
var dia_de_la_decision: int = 0


## Cita la decisión de la estación que acaba de entrar.
##
## **El día se sortea con la semilla de la partida, no con el `_rng`.** Con el
## `_rng` cada sorteo desplazaría todas las tiradas siguientes y ninguna cifra
## medida hasta hoy se podría comparar con una de después —pasó al repartir
## quién vive dónde, ver SPECS §4.4—. Sale de la semilla, el año y la estación,
## así que la misma partida da siempre los mismos días y dos partidas distintas
## dan días distintos, que es lo que el criterio pide. Decisión del usuario del
## 2026-09-13.
func _citar_la_decision() -> void:
	dia_de_la_decision = dia_de_decidir(game_seed, anyo,
		estacion as Subsistence.Season)
	# Si se entra en la estación ya pasado ese día -una partida que arranca a
	# mitad, o un estado construido-, se decide en cuanto se pueda: mejor tarde
	# que no tenerla.
	if season_day + 1 >= dia_de_la_decision:
		_revisar_la_decision()


## Qué día de esa estación toca decidir, de [DECISION_PRIMER_DIA] a
## [DECISION_ULTIMO_DIA]. Estático y sin estado: la misma semilla, el mismo día.
static func dia_de_decidir(semilla: int, anyo: int, estacion: Subsistence.Season) -> int:
	var azar := RandomNumberGenerator.new()
	# Mezclado a mano y con primos: `seed` a secas con números vecinos da
	# rachas, y aquí los números son vecinos a propósito -año y estación van de
	# uno en uno-.
	azar.seed = semilla * 1000003 + anyo * 10007 + int(estacion) * 101
	return DECISION_PRIMER_DIA + azar.randi_range(
		0, DECISION_ULTIMO_DIA - DECISION_PRIMER_DIA)


## ¿Toca hoy la decisión de la estación? Lo pregunta el cierre de la jornada.
func _revisar_la_decision() -> void:
	if dia_de_la_decision <= 0 or season_day + 1 < dia_de_la_decision:
		return
	dia_de_la_decision = 0
	_decision_de_la_estacion()


## La decisión fija de la estación en curso. UNA decisión por estación, que es
## el criterio del frente 8 de EPOCA_01 §10.1: cuatro al año que no se pueden
## evitar. Las tres que no eran la berrea las eligió el usuario el 2026-09-12, y
## las tres salen de sistemas que ya existían.
##
## **La primavera se quedó sin decisión el 2026-09-14**: la suya era mandar la
## expedición, y desde que se manda cuando se quiere, hacia un rumbo, esa tarjeta
## sobra (SISTEMAS §4). Consecuencia aceptada al escribir la spec.
##
## Está en un solo sitio porque la preguntan dos: el cambio de estación y el
## arranque de la partida.
func _decision_de_la_estacion() -> void:
	match estacion:
		Subsistence.Season.VERANO:
			cumbres.proponer_la_subida()
		Subsistence.Season.OTONO:
			_offer_rut_choice()
		Subsistence.Season.INVIERNO:
			hogar.proponer_el_fuego()


## Pone el cuerpo de esta persona donde está. La vista sólo lee.
func _pintar_a(person: Inhabitant, index: int) -> void:
	if _crowd == null or index >= _bodies.size():
		return
	if figuras != null:
		# La pose la pone `Figuras` en su propio `_process`, POR CUADRO y no por paso:
		# con la camara lenta se dan uno o dos pasos por segundo, y una figura que solo
		# se moviera en ellos daria tirones justo cuando se la mira de cerca.
		figuras.anotar(person, index)
		return
	_crowd.update(_bodies[index], person.position, _headings[index], person.state,
		person.age_group)


## Se lo lleva de la vista: ha salido de los cuatro kilómetros.
##
## No se borra su cuerpo —los huecos de la multitud son por índice— sino que se
## manda bajo tierra, que es lo que hace la multitud con lo que no toca ver. Sin
## esto, quien se iba de expedición se quedaba plantado en el borde del mapa
## doce jornadas: la simulación no lo tocaba y la vista seguía pintándolo donde
## lo dejó.
func _sacar_del_mapa(person: Inhabitant, index: int) -> void:
	if _crowd == null or index >= _bodies.size():
		return
	if figuras != null:
		figuras.esconder(index)
	_crowd.update(_bodies[index], person.position + Vector3(0.0, -1000.0, 0.0),
		_headings[index], person.state, person.age_group)


## DONDE SE PONE CADA UNO Y A QUE TAJO SE LE MANDA VIVE EN [Destino] (ARQUITECTURA
## §3.1). Aqui quedan los pasamanos de lo que llaman desde fuera, las constantes que se
## pedian por esta clase, y el estado -ver la nota de `berrea_hasta_el_dia`-.
var destino := Destino.new(self)

## Parajes conocidos por actividad, ya puntuados y ordenados. Se rehace una vez
## al dia, no una vez por persona: recorrer las 4.096 celdas del campo cada vez
## que alguien salia de casa dejaba la simulacion inservible. Lo usa [Destino].
var _known_spots: Dictionary = {}

const PARAJE_BONUS := Destino.PARAJE_BONUS
const RENUNCIA := Destino.RENUNCIA
const SALIDA_DE_CASA := Destino.SALIDA_DE_CASA
const SED_HORAS_CON_ODRE := Destino.SED_HORAS_CON_ODRE
const SED_HORAS_SIN_ODRE := Destino.SED_HORAS_SIN_ODRE
const SHORE_FORAGE_FACTOR := Destino.SHORE_FORAGE_FACTOR
const SHORE_SEARCH_M := Destino.SHORE_SEARCH_M
const SHORE_TRIES := Destino.SHORE_TRIES


func _at_shelter(person: Inhabitant) -> bool:
	return destino._at_shelter(person)


func _saliendo_de_casa(person: Inhabitant) -> bool:
	return destino._saliendo_de_casa(person)


func _shelter_reach() -> float:
	return destino._shelter_reach()


func _home_reached(person: Inhabitant) -> bool:
	return destino._home_reached(person)


func _settle_at_home(person: Inhabitant, delta: float) -> void:
	destino._settle_at_home(person, delta)


func _send_to_work(person: Inhabitant) -> void:
	destino._send_to_work(person)


func _work_candidates(person: Inhabitant) -> Array[Vector3]:
	return destino._work_candidates(person)


## Anota algo en el diario, con la fecha puesta.
##
## Todo lo que se cuenta sale de cosas que la simulacion YA detectaba y se
## limitaba a reflejar en un numero. Aqui solo se redacta.
func _note(kind: Chronicle.Kind, text: String, weight: int = 1) -> void:
	if chronicle == null:
		return
	chronicle.record(day, estacion as int, anyo,
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
	# Con encargo, o practicando: el taller no se queda parado porque nadie
	# haya pedido una pieza, y la peletería tampoco deja la piel cruda sin
	# curtir. Ver [Taller.puede_practicar] y el frente 14 de EPOCA_01 §10.1.
	return taller._next_piece(speciality) >= 0 or taller.puede_practicar(speciality)


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

	# EL ARTESANO QUE NO ESTA TALLANDO NO LLEVA CHAPA. `crafting_now` devuelve
	# vacio fuera de las horas de taller, y de aqui para abajo solo quedan
	# barras de gente que trae cosas del monte: sin este corte, el artesano
	# seguia de largo hasta la ultima rama y se le pintaba encima la barra de
	# «lo que llevas en el cesto», que para el es siempre cero. Se veia como una
	# barra a cero desde la cena hasta el dia siguiente -queja del usuario del
	# 2026-09-14-, y no era su progreso puesto a cero: era otra barra.
	if person.job == Profession.Job.MANUFACTURA:
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
	# Y NO DOS VECES DESDE EL MISMO SITIO. Ver [Inhabitant.ojeada_desde]: la
	# ojeada es idempotente, asi que repetirla sin haberse movido ni haber
	# cambiado el tiempo que hace es un barrido de celdas para no tocar nada.
	var alcance := sight_range * weather.sight_factor()
	if person.position != person.ojeada_desde or alcance != person.ojeada_alcance:
		knowledge.see_from(person.position, alcance)
		person.ojeada_desde = person.position
		person.ojeada_alcance = alcance

	# El ritmo se escala con el dia de juego para que aprender un paraje
	# lleve jornadas y no segundos
	var pace := delta / maxf(seconds_per_day, 0.001)
	var intensity := pace * (1.0 if working else 0.18)
	# Y SE MIRA SI SE CRUZA EL LISTON DE BAUTIZAR, para poner la chapa en el
	# momento en que la banda conoce el sitio.
	#
	# «Los parajes deben aparecer a medida que se descubran; ahora mismo
	# aparecen todos a la vez cuando llegan las 12 de la noche». Con el repaso
	# de fin de jornada como unico bautizo, un recolector que se pasa el dia
	# aprendiendo un avellanar no lo ve aparecer hasta medianoche, y salian
	# nueve chapas de golpe: medido, el dia 2 a las 00:00.
	#
	# La comprobacion es barata a proposito: solo se barre el entorno cuando
	# una celda ACABA de cruzar el umbral, que pasa un puñado de veces al dia.
	var cruzado := false
	for activity: int in _activities_for_learning(person):
		var act := activity as Subsistence.Activity
		var antes := knowledge.familiarity_at(act, person.position)
		knowledge.observe(act, person.position, intensity)
		if antes < Parajes.NAMED_AT 				and knowledge.familiarity_at(act, person.position) >= Parajes.NAMED_AT:
			cruzado = true
	if cruzado:
		reconocimiento.bautizar_lo_descubierto(
			person.position, Reconocimiento.FORAGE_RADIUS)

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
		field, person.activity, person.position, estacion)
	var real := field.seasonal_abundance_at(
		person.activity, person.position, estacion)
	if real <= 0.001:
		return 1.0
	return (believed / real) * knowledge.efficiency(person.activity, estacion)




## LO QUE PASA AL ACABAR LA JORNADA VIVE EN [CierreDelDia] (ARQUITECTURA §3.2). Aqui
## quedan los pasamanos, las constantes que se pedian por esta clase y el estado -ver la
## nota de `berrea_hasta_el_dia`-.
var cierre := CierreDelDia.new(self)

## Lo que se ha perdido hoy, material -> unidades. Es una copia y no
## `store.spoiled` a secas porque aquélla se vacía en la siguiente llamada a
## `age`, y el parte tiene que aguantar la jornada entera en pantalla.
var spoiled_today: Dictionary = {}

## Raciones de comida perdidas hoy. Es la cifra que de verdad duele: dos pieles
## echadas a perder no son lo mismo que dos días de comer.
var spoiled_rations_today: float = 0.0

## Estado del ultimo aviso de hambre, para no repetirlo cada jornada. La
## primera vez que se cruza el umbral es noticia; las diez siguientes, ruido.
var _warned_hungry: bool = false
var _warned_full: bool = false

const MERMA_QUE_DUELE := CierreDelDia.MERMA_QUE_DUELE
const RESERVA_CRITICA := CierreDelDia.RESERVA_CRITICA
const TRANSMISSION_CEILING := CierreDelDia.TRANSMISSION_CEILING
const TRANSMISSION_RATE := CierreDelDia.TRANSMISSION_RATE


func _record_history() -> void:
	cierre._record_history()


func _push_history(key: int, value: float) -> void:
	cierre._push_history(key, value)


func history_of(kind: Materia.Kind) -> PackedFloat32Array:
	return cierre.history_of(kind)


func tool_history_of(kind: Tool.Kind) -> PackedFloat32Array:
	return cierre.tool_history_of(kind)


func _end_of_day() -> void:
	cierre._end_of_day()


func _practica_del_dia() -> void:
	cierre._practica_del_dia()


func _knowledge_transmission() -> void:
	cierre._knowledge_transmission()


static func _join_and(parts: Array[String]) -> String:
	return CierreDelDia._join_and(parts)


func _note_daily_state() -> void:
	cierre._note_daily_state()


func _advance_local_season() -> void:
	cierre._advance_local_season()


## Cuánto sube de precio la lesión de quien decide aguantar y seguir fuera.
##
## Sin calibrar, como el resto del balanceo: lo decidido es que quedarse fuera
## con un tobillo torcido tenga precio, no cuánto.
const PERCANCE_AGUANTAR := 1.8


## EL ESTADO DE LA BERREA SE QUEDA AQUI, y el comportamiento esta en [Berrea].
##
## No es por gusto: la instantanea firma las propiedades del simulador por su sitio
## (ver [Instantanea]), asi que mover un `var` a una clase nueva **cambia la forma de la
## firma** aunque la partida sea exactamente la misma. Y el criterio de la segunda pasada
## es que la firma de treinta jornadas salga identica antes y despues
## (ARQUITECTURA §3.2). Asi que en esta pasada se mueve lo que se HACE y se queda lo que
## se ES. Quien quiera mudar tambien el estado tendra que cotejar por el resumen y no por
## el hash, y decirlo.

## Hasta qué jornada dura la berrea en curso. -1 si no hay.
var berrea_hasta_el_dia := -1

## Las prioridades que cada uno tenía antes de volcarse, por id, para
## devolvérselas al acabar. Es lo que hace que la apuesta tenga fin.
var _prioridades_antes_de_la_berrea: Dictionary = {}

## El celo del ciervo: la decision del otoño y el mes que dura. Ver [Berrea].
var berrea := Berrea.new(self)


## La decisión de la berrea, al empezar el otoño. Ver [Berrea].
func _offer_rut_choice() -> void:
	berrea._offer_rut_choice()


## La banda se vuelca en la berrea. Ver [Berrea].
func focus_on_rut() -> void:
	berrea.focus_on_rut()


func _acabar_la_berrea() -> void:
	berrea._acabar_la_berrea()


func _season_line() -> String:
	return berrea._season_line()


## Cuánto dura volcarse en la berrea. Se pide por la clase, y la fachada la reenvía
## para no romper lo que ya la nombraba. Ver [Berrea.DIAS_DE_BERREA].
const DIAS_DE_BERREA := Berrea.DIAS_DE_BERREA


func population() -> int:
	return people.size()


## Cuánta gente cabe en el abrigo sin paraviento. Quince es la banda de
## partida por defecto; un margen pequeño encima para que empezar a crecer
## no penalice el primer nacimiento.
const PLAZAS_ABRIGO_BASE := 18

## Cuánto más cabe con un `CampProjects.Kind.PARAVIENTO` levantado.
##
## `camp_built` guarda como mucho UN paraviento -es un `Dictionary[Kind,
## bool]`, no un contador, igual que el hogar o el secadero: sólo se levanta
## uno de cada obra-. Si algún día la banda necesita más de uno, esto deja
## de ser un booleano; hoy con "se levanta o no se levanta" basta para que
## la mecánica tenga efecto, y partir la banda en más de un abrigo queda
## fuera de esta spec (ver "Fuera de alcance").
const PLAZAS_ABRIGO_POR_PARAVIENTO := 8


## Cuánta gente cabe hoy en el abrigo. Sale de lo construido, no de un
## número fijo de partida -mismo principio que `Storehouse.capacidad_de_
## comida` con cestos y odres-.
func plazas_abrigo() -> int:
	var plazas := PLAZAS_ABRIGO_BASE
	if camp_built.get(CampProjects.Kind.PARAVIENTO, false):
		plazas += PLAZAS_ABRIGO_POR_PARAVIENTO
	return plazas


## De 0 a 1: qué parte de la banda podría llevar un `VESTIDO` de sobra hoy.
## Cobertura AGREGADA -no se sabe ni hace falta saber quién lleva cuál, igual
## que `Tool.Kind.CESTO` no dice qué recolector usa qué cesto-.
func vestido_coverage() -> float:
	var pop := population()
	if pop <= 0:
		return 1.0
	return clampf(float(toolkit.count(Tool.Kind.VESTIDO)) / float(pop), 0.0, 1.0)


## Alguien se va de este campamento vivo: de viaje a otro. Ver [Viaje].
##
## Es la otra puerta de salida de `people`, y va aparte de [_person_dies] porque
## no es morir: no hay crónica de muerte, ni sepultura, ni derrota si no queda
## nadie —un campamento vacío queda abandonado y conserva lo suyo, SISTEMAS §23—.
## **Y se lleva su cuerpo de la multitud**: `_bodies` y `_headings` van por
## índice con `people`, así que quitar a alguien sin quitar su cuerpo descuadra a
## todos los que vienen detrás. (`_person_dies` no lo hace, y es deuda anterior.)
func despedir(person: Inhabitant) -> void:
	var idx := people.find(person)
	if idx < 0:
		return
	if _crowd != null and idx < _bodies.size():
		_crowd.update(_bodies[idx], person.position + Vector3(0.0, -1000.0, 0.0),
			_headings[idx], person.state, person.age_group)
		_bodies.remove_at(idx)
		_headings.remove_at(idx)
	people.remove_at(idx)
	# Una cacería no sigue con quien se ha ido del valle.
	for hunt: Hunt in caceria.hunts:
		hunt.crew.erase(person)
	var vivas: Array[Hunt] = []
	for hunt: Hunt in caceria.hunts:
		if not hunt.crew.is_empty():
			vivas.append(hunt)
	caceria.hunts = vivas
	person.has_task = false
	person.route = PackedVector3Array()
	person.route_step = 0


## Alguien llega a este campamento: de un viaje. Ver [Viaje.llegar_a].
##
## **Con un id nuevo**: los ids son de cada campamento —cero, uno, dos…— y dos
## bandas que se juntan chocarían, y hay cosas que van por id (quién está de
## expedición, a quién se le dio por imposible un sitio). Descarga lo que trae en
## el almacén, se pone en la campa y, si alguien mira, tiene cuerpo.
func recibir(person: Inhabitant) -> void:
	person.id = relevo.id_libre()
	var angle := _rng.randf() * TAU
	var radius := _rng.randf_range(4.0, 22.0)
	var casa := home_forecourt if home_forecourt != Vector3.ZERO else home_position
	person.position = casa + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	if _terrain != null:
		person.position.y = _terrain.get_height_at(person.position)
	person.target = person.position
	person.state = Inhabitant.State.OCIOSO
	person.has_task = false
	person.route = PackedVector3Array()
	person.route_step = 0
	person.unreachable = Vector3.ZERO
	person.expedicion_hasta = -1
	person.expedicion_andando = false
	person.work_centre = home_position
	for kind: int in person.load:
		store.add(kind as Materia.Kind, float(person.load[kind]))
	person.load.clear()
	person.carrying = 0.0
	people.append(person)
	if _crowd != null:
		var slot := _crowd.add_person()
		_bodies.append(slot)
		_headings.append(angle)
		_crowd.update(slot, person.position, angle, person.state, person.age_group)


## El único sitio por el que alguien deja la partida para siempre.
##
## Hambre, frío, vejez y percance grave son cuatro caminos hasta aquí, y
## esta función es la única que de verdad quita a nadie de `people`.
## Escribirla cuatro veces -una por causa- sería la misma "regla en varios
## sitios" que el propio flujo de specs de este proyecto existe para evitar.
##
## No hace falta avisar a `reparto` por separado: `job_counts`, `idle_count`
## y el resto recorren `sim.people` cada vez que se les pregunta, así que en
## cuanto esta persona sale de la lista deja de contar en todos ellos sin
## tocar nada más. El texto de la crónica lo trae ya redactado quien llama
## -hambre, frío, vejez y percance se cuentan cada uno a su manera-, esto
## sólo se ocupa de sacarla y de que quede constancia.
func _person_dies(person: Inhabitant, texto: String) -> void:
	var idx := people.find(person)
	if idx < 0:
		return
	people.remove_at(idx)
	_note(Chronicle.Kind.GENTE, texto, 2)

	if people.is_empty():
		partida.declarar_derrota(texto)
		return
	# Y queda despedirlo: se pregunta cómo. Ver [Sepulturas].
	sepulturas.al_morir(person, texto)


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
				estacion as Subsistence.Season)
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
	var changed := weather.advance(_rng, estacion)
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
		estacion as Subsistence.Season, toolkit)
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
	# Los odres VACÍOS: uno lleno de agua no guarda comida. Ver
	# [Despensa.odres_vacios].
	store.capacidad_comida = store.capacidad_de_comida(
		toolkit.count(Tool.Kind.CESTO), int(floor(despensa.odres_vacios())))


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


## Los motivos de atasco que NO son del terreno, con nombre fijo para poder
## contarlos.
const LLEGADA_COLGADA := "llego y el estado no se entero"
const SUELO_MALO := "estaba metido donde no se pisa"

## Iba a un sitio y por el camino dejo de haber ruta hasta el.
##
## Se cuenta aparte de los demas porque apunta a otra pieza: no al andador ni
## al terreno, sino a QUIEN ELIGE LOS DESTINOS. Ver [Marcha._sin_rumbo].
const SIN_RUMBO := "se quedo sin camino a donde iba"


## Cuantas cargas se han perdido por salir de nuevo sin haber entregado.
##
## Deberia quedarse en cero. Si sube, alguien esta acabando la jornada lejos
## del abrigo y volviendo a salir sin pasar por casa.
var lost_loads: int = 0


## El siguiente paraje que le toca batir: EL MAS CERCANO CON INCOGNITAS.
##
## De mas cerca a mas lejos, sin mas. Es la mision del batidor mientras quede
## un «???» en el mapa, y el orden importa por dos razones:
##
##   · El sitio de al lado es al que la banda va a volver a diario, asi que
##     saber lo que tiene rinde antes que saber lo que hay a dos kilometros.
##   · Y se puede SEGUIR desde fuera. La lista de la pestaña de Parajes va en
##     ese mismo orden y con su porcentaje al lado, asi que el jugador ve cual
##     es el siguiente sin tener que adivinar nada.
##
## Antes se puntuaba mezclando lo que faltaba por saber con lo que costaba
## llegar —un paraje casi virgen a 600 m le ganaba a uno a medias a 200— y el
## resultado era que la batida saltaba de un lado a otro del valle sin que se
## entendiera por que. Que la regla sea explicable vale mas aqui que afinarla.
##
## Devuelve null si no queda ninguno con incognitas.
func _paraje_to_survey(person: Inhabitant) -> Paraje:
	if parajes == null:
		return null

	# Hasta donde llega ESTA salida. La batida va y vuelve el mismo dia, asi
	# que un paraje mas alla de su radio no es un destino: es una jornada
	# entera andando para volver sin nada. La expedicion si puede ir, y por eso
	# no lleva tope.
	#
	# EL RADIO DE JORNADA, NO EL DE LA BATIDA. Son dos cosas que se llamaban
	# igual y no lo son: [Reconocimiento.BATIDA_RADIUS] es hasta donde se PEINA
	# monte sin nombre —una vuelta corta alrededor del campamento— y esto es
	# hasta donde se VA A UN SITIO QUE YA SE CONOCE, que es la misma pregunta
	# que se hace el reparto de tajos y por tanto el mismo numero.
	#
	# Usando el de peinar, un paraje a 386 m quedaba fuera por seis metros: la
	# batida se quedaba sin destino, caia al plan B —peinar monte— y se ponia a
	# dar vueltas. Es la queja, y con la cifra puesta: «ha descubierto
	# totalmente los parajes hasta los 364 m, pero el siguiente, 386 m, ya no
	# ha ido a por el, y ha empezado a hacer rutas extrañas, otra vez contra el
	# rio».
	var alcance := INF
	if person.current_speciality == Profession.Speciality.BATIDA:
		alcance = RADIO_DE_JORNADA

	var best: Paraje = null
	var best_score := -INF
	for paraje: Paraje in parajes.list:
		if not paraje.has_unknowns():
			continue
		if paraje.distance_from(home_position) > alcance:
			continue
		# LOS MISMOS DOS FILTROS QUE MIRAN LOS OTROS DOS.
		#
		# Un paraje que descansa —o al que esta persona ya renuncio hoy—
		# lo descartan `Reconocimiento._batida_target` al heredar el sitio
		# de la salida anterior y `Tajo._paraje_por_prospectar` al
		# repartir trabajo. Aqui no se miraban, asi que ESTA capa lo
		# elegia y la siguiente lo rechazaba: el batidor entraba en el
		# sitio y a la salida siguiente se le mandaba a otro.
		#
		# Las tres deciden sobre el mismo paraje: tienen que mirar lo
		# mismo o el ir y venir esta garantizado.
		# `paraje.resting` y no `_is_resting`: aquello recorre la lista ENTERA
		# de parajes buscando vecinos que descansen, y esto ya esta dentro de
		# un bucle sobre la misma lista. Cuadratico, y con el mapa entero
		# abierto a la exploracion la lista pasa de cuatro a noventa parajes.
		#
		# Y no hace falta: `_is_resting` contesta «¿descansa ALGO en esta
		# zona?», que es la pregunta de quien mira un punto suelto del monte.
		# Aqui se tiene el paraje delante y se le puede preguntar a el.
		if paraje.resting:
			continue
		if marcha._given_up_on(person, paraje.position):
			continue
		# Comunicado no es alcanzable: la otra orilla lo está, por un vado a
		# kilómetro y medio.
		#
		# Con MEMORIA, y desde el abrigo: esto se pregunta por CADA paraje con
		# incognitas cada vez que alguien decide su salida, y con medio centenar
		# de parajes son medio centenar de busquedas enteras. La decision se toma
		# en el campamento —es de donde se sale— asi que la pregunta buena es
		# «¿se llega desde casa?», que ademas es la que ya esta guardada. Ver
		# [Marcha.alcanzable_desde_casa].
		if not marcha.alcanzable_desde_casa(paraje.position):
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
					and Traversal.en_llano(reconocimiento._exploration_anchor(other),
					paraje.position) < Reconocimiento.YA_HAY_OTRO:
				taken = true
				break
		if taken:
			continue

		# El mas cercano, y se acabo. `best_score` guarda la distancia en
		# negativo para no darle la vuelta a la comparacion.
		var score := -paraje.distance_from(home_position)
		if score > best_score:
			best_score = score
			best = paraje
	return best


## El paraje que hay en un punto, si lo hay.
func _paraje_at(point: Vector3) -> Paraje:
	if parajes == null:
		return null
	for paraje: Paraje in parajes.list:
		if paraje.contains(point):
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
## El utillaje con el que se llega al abrigo.
##
## Va CORTO a proposito: da para arrancar y no para acomodarse, asi que la
## primera escasez de filo llega a las pocas semanas y con ella la razon de
## poner a alguien a tallar.
##
## Todo de cuarcita, que es lo que hay en cualquier playa del Cantabrico. El
## silex bueno esta lejos, y encontrarlo es media aventura.
##
## ## Por que ya no hay azagayas
##
## Llegaban con dos, y `Tool.tech_of` exige `Tech.AZAGAYA` para fabricar una:
## la banda tenia puesto lo que no sabria reponer. [ESTADO.md] §2 lo midio
## -«acabaron con dos azagayas de un utillaje que ni siquiera sabian
## diseñar»- y se quedo sin arreglar.
##
## En su lugar van dos PUNTAS liticas, que es lo historico: la lanza de mano
## es lo anterior a la punta de asta enmangada, no pide tecnica ni otra
## herramienta para hacerse, y `Fauna` ya deja cobrar corzo y rebeco con ella.
## Asi la caza menor sigue viva desde el primer dia -y con ella el tendon, que
## es lo que hace falta para aprender la azagaya-.
##
## Es UNA LISTA y no ocho lineas de `craft` porque hay una regla que
## comprobar: nada de aqui puede pedir tecnica. Ver `TestToolkit`.
const UTILLAJE_INICIAL := [
	{"kind": Tool.Kind.LASCA, "stuff": Tool.Stuff.CUARCITA, "cuantas": 8},
	{"kind": Tool.Kind.RAEDERA, "stuff": Tool.Stuff.CUARCITA, "cuantas": 2},
	{"kind": Tool.Kind.BURIL, "stuff": Tool.Stuff.CUARCITA, "cuantas": 1},
	{"kind": Tool.Kind.PUNTA, "stuff": Tool.Stuff.CUARCITA, "cuantas": 2},
]


const SPECIALITY_TOOL := {
	Profession.Speciality.FORRAJEO: Tool.Kind.CESTO,
	Profession.Speciality.CANTERA: Tool.Kind.LASCA,
	# La caza menor con PUNTA, no con azagaya. Eran dos verdades sobre lo
	# mismo: `Fauna` ya decia que al corzo y al rebeco se les entra con lanza
	# de mano -«es lo que hubo mucho antes que la azagaya»- y esta tabla exigia
	# azagaya, que es lo que cerraba el bucle: sin tendon no se aprende la
	# azagaya y sin caza menor no hay tendon. Gana `Fauna`, que es la que
	# describe la pieza. La caza MAYOR si la sigue pidiendo: a un uro no se le
	# espera a distancia de brazo.
	Profession.Speciality.CAZA_MENOR: Tool.Kind.PUNTA,
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
		estacion as Subsistence.Season, techs, toolkit)
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
