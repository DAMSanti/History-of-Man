class_name Inhabitant
extends RefCounted
## Una persona de la banda.
##
## El modelo es por INDIVIDUO y no agregado: cada uno tiene su hambre, su
## cansancio y su rutina. Un agregado -"la banda consume 2250 jornadas"- se
## simula facil pero no se ve, y en un city builder lo que se ve es la gente.
##
## Aviso de escala: esto funciona para 25 personas y para 200. Julioburiga
## andaba por las 1500 y una ciudad moderna por las 50.000, asi que en epocas
## tardias habra que abstraer en unidades familiares. Es una limitacion
## conocida, no un descuido.

enum Age { NINO, ADULTO, ANCIANO }

enum Sex { MUJER, HOMBRE }

## Rasgos fisicos y mentales generales, 0-1. No son saber tacito de una tarea
## -eso es `skill`, se aprende de cero cada partida-, es lo que trae el
## cuerpo y la cabeza de fabrica, y por eso cambia mucho mas despacio: una
## vida entera, no unas semanas de tajo.
enum Stat {
	FUERZA,      ## Cuanto se puede cargar y cuanto rinde el trabajo de brazo
	RESISTENCIA, ## Cuanto aguanta antes de rendirse: gobierna la fatiga
	AGUDEZA,     ## Variacion personal de lo espabilado que es, sobre la edad
}

## Rasgos personales que no son un oficio: no dan de comer por si solos, pero
## abren o facilitan cosas que de otro modo no se pueden hacer -o cuestan
## mucho mas-. `MONTA` y `DOMA` estan aqui porque el sistema es el mismo,
## pero no tienen todavia ningun animal domestico con el que valer: en el
## Paleolitico se quedan en cero y a la espera de una era que los use. Es una
## limitacion conocida, no un descuido.
enum Trait {
	NATACION,
	MONTA,
	DOMA,
}

enum State {
	DURMIENDO,
	YENDO,        ## De camino al tajo
	BUSCANDO,     ## Prospectando: no sabe dónde está lo bueno y lo busca
	TRABAJANDO,
	VOLVIENDO,    ## De vuelta con lo conseguido
	COMIENDO,
	OCIOSO,
	RECONOCIENDO, ## Ya ha llegado adonde iba y ahora bate la comarca
}

## Nombres para dar identidad. No pretenden ser paleoliticos -no sabemos como
## se llamaban- sino cortos y distinguibles de un vistazo.
const NAMES := [
	"Anda", "Beru", "Caro", "Duna", "Eiga", "Fusto", "Gala", "Haro",
	"Ilun", "Jara", "Kelo", "Lasa", "Muno", "Nara", "Oki", "Pelu",
	"Quira", "Rulo", "Sela", "Turo", "Ubar", "Vela", "Xilo", "Yara", "Zuro",
	"Arno", "Bela", "Cuno", "Dara", "Erko", "Falo", "Gora", "Hesa",
]

var id: int = 0
var given_name: String = ""
var age_group: Age = Age.ADULTO
var age_years: int = 20
var sex: Sex = Sex.MUJER

## Lleva una cría de pecho encima.
##
## Es la restricción que de verdad limita las jornadas largas, y va aparte del
## sexo a propósito: quien carga con el crío no hace la batida, sea quien sea.
## Y es temporal, no una etiqueta: al destetar se vuelve a la partida. Ver
## [Profession] para el razonamiento y las fuentes.
var nursing: bool = false

## Oficio que ESTÁ HACIENDO hoy. Ya no lo pone el jugador a mano: sale de las
## prioridades, cada jornada. Ver [Inhabitant.priorities].
var job: int = Profession.Job.RECOLECCION

## Qué está dispuesta a hacer esta persona y con cuántas ganas.
##
## La clave es una TAREA —ver [Profession.task_id]—, que es un oficio o un
## oficio con su especialidad. Así se puede decir «primero talla, y si no hace
## falta talla, cordel», que con una especialidad fija por cuadrilla era
## imposible.
##
##   0 · no lo hace
##   1 · lo primero
##   2 · si hace falta
##   3 · sólo si no hay otra cosa
var priorities: Dictionary = {}


## Con cuántas ganas hace esta persona esa tarea. 0 es que no la hace.
func priority_for(task: int) -> int:
	return int(priorities.get(task, 0))


func set_priority(task: int, level: int) -> void:
	if level <= 0:
		priorities.erase(task)
	else:
		priorities[task] = clampi(level, 1, 3)


## La mejor prioridad que tiene entre las tareas de un oficio. Sirve para
## saber si esta persona hace ese oficio de alguna forma.
func priority_in_job(job: int) -> int:
	var best := 0
	for task: int in priorities:
		if Profession.task_job(task) != job:
			continue
		var level := int(priorities[task])
		if best == 0 or level < best:
			best = level
	return best


## Lo que ha aprendido haciendo, de 0 a 1, por TAREA.
##
## Iba por actividad, y eso mezclaba cosas que no se parecen: talla, peletería
## y cordelería son las tres «materia prima», así que un tallador salía siendo
## también peletero experto sin haber curtido una piel en su vida.
##
## No es un número decorativo: entra en `effectiveness`, o sea que un cazador
## veterano trae más que uno que empieza, y las piezas que talla un buen
## artesano duran más. Es la razón mecánica de que mover gente de oficio
## constantemente salga caro.
func skill_in(task: int) -> float:
	return float(skill.get(task, 0.5))


## La tarea que está haciendo ahora mismo, para mirar su pericia.
func current_task() -> int:
	return Profession.task_id(job as Profession.Job,
		current_speciality as Profession.Speciality)


## Cómo se llama lo que sabe, para poder enseñárselo al jugador.
func skill_label(value: float) -> String:
	if value < 0.35:
		return "torpe"
	if value < 0.5:
		return "aprendiendo"
	if value < 0.65:
		return "se defiende"
	if value < 0.8:
		return "buena mano"
	return "maestría"

## Especialidad DENTRO del oficio, cuando lo admite.
##
## NINGUNA es «lo que haga falta»: rota según lo que más falte. Fijar una es lo
## que convierte a alguien en artesano, y una banda pequeña no se lo puede
## permitir.
var speciality: int = Profession.Speciality.NINGUNA

## Un destino al que se ha comprobado que NO se puede llegar.
##
## Se guarda para no volver a intentarlo en bucle: sin esto, alguien al que se
## manda al otro lado de un río infranqueable pide el camino, no lo hay, se le
## vuelve a mandar, y así indefinidamente.
var unreachable: Vector3 = Vector3.ZERO


## El camino que está siguiendo, de aquí al destino.
##
## No es adorno de interfaz: la gente anda POR él. Rodea el canchal y el
## cortado en vez de meterse por en medio, que es donde se hacía daño.
var route: PackedVector3Array = PackedVector3Array()
var route_step: int = 0


## El punto al que se dirige AHORA: el siguiente hito del camino, o el destino
## si no hay camino trazado.
## Por donde ha ido y que ha hecho en cada sitio.
##
## Cada apunte es `{pos, day, hour, state, task, note}`. `note` va vacia salvo
## cuando ahi paso algo que se pueda contar -se abatio una pieza, se rompio un
## util, se corono una cumbre-, y es lo que convierte una linea en el suelo en
## un relato de la jornada.
##
## No es de la simulacion: la banda no consulta su propio rastro. Es para
## poder MIRAR el juego por dentro, que es lo unico que distingue afinar de
## adivinar.
var trail: Array[Dictionary] = []

## Cuantos apuntes se guardan por persona.
##
## Trescientos son varias jornadas a un apunte cada veinticinco metros. Mas no
## cabe en pantalla de forma legible, y guardar la partida entera seria pagar
## memoria por algo que nadie va a mirar.
const TRAIL_LIMIT := 300


## En que se le han ido las horas y que ha sacado de cada cosa.
##
## Es la contabilidad de la jornada: por tarea, cuantas horas se han echado y
## cuanto se ha traido de cada material. Existe porque «sospecho que algunos no
## funcionan bien» solo se puede resolver de una manera, que es MIRAR: una
## tarea con seis horas y cero unidades no es una intuicion, es un fallo con
## nombre y apellidos.
##
## Se acumula desde el principio de la partida. Las horas de andar y de
## reconocer tambien cuentan, porque «la recoleccion no trae nada» muchas veces
## quiere decir «la recoleccion se pasa la jornada andando».
var work_log: Dictionary = {}


## Apunta horas en una tarea.
func log_hours(task: int, hours: float) -> void:
	var entry: Dictionary = work_log.get(task, {"hours": 0.0, "gained": {}})
	entry["hours"] = float(entry["hours"]) + hours
	work_log[task] = entry


## Apunta algo HECHO que no es un material.
##
## Hace falta porque medio trabajo de la banda no sale del monte con nada
## encima: el hogar mantiene el fuego, el explorador trae mapa, el secadero
## ahuma. Contando solo unidades, esas tareas salian con seis horas y cero, y
## eso se lee como una averia cuando es que estan funcionando.
## `counted` separa lo que PASA de lo que se ESTA HACIENDO, y la diferencia
## importa: «comarca reconocida x4» dice algo, y «manteniendo el fuego x2833»
## -una vez por tick de simulacion- no dice nada, solo tapa lo que si.
func log_deed(task: int, what: String, counted: bool = true) -> void:
	var entry: Dictionary = work_log.get(task, {"hours": 0.0, "gained": {}})
	var deeds: Dictionary = entry.get("deeds", {})
	deeds[what] = (int(deeds.get(what, 0)) + 1) if counted else 1
	entry["deeds"] = deeds
	work_log[task] = entry


## Apunta lo que se ha traido haciendo una tarea.
func log_gain(task: int, kind: int, units: float) -> void:
	var entry: Dictionary = work_log.get(task, {"hours": 0.0, "gained": {}})
	var gained: Dictionary = entry["gained"]
	gained[kind] = float(gained.get(kind, 0.0)) + units
	entry["gained"] = gained
	work_log[task] = entry


## Las tareas en las que se ha echado tiempo, de mas a menos horas.
func work_summary() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for task: int in work_log:
		var entry: Dictionary = work_log[task]
		rows.append({
			"task": task, "hours": float(entry["hours"]),
			"gained": entry["gained"] as Dictionary,
			"deeds": entry.get("deeds", {}) as Dictionary,
		})
	rows.sort_custom(func(a, b): return float(a["hours"]) > float(b["hours"]))
	return rows


## Cuanto lleva sin moverse yendo a algun sitio, y desde donde.
##
## Lo usa el vigilante de plantados. Ver [SettlementSim._watch_for_stuck].
## Pasos seguidos que se han quedado en nada por tener algo delante.
var blocked_steps: int = 0

## Cuántas veces se ha vuelto a trazar el camino a ESTE destino sin conseguir
## avanzar. Ver `SettlementSim.BLOCKED_REPLANS`: replanificar la misma ruta
## contra la misma pared no la abre, sólo repite el intento.
var blocked_replans: int = 0

## Los sitios a los que HOY se ha intentado llegar y no se ha podido.
##
## Va aparte de `unreachable` porque son dos memorias distintas: aquélla es del
## trazador de caminos y se borra en cuanto encuentra una ruta a cualquier otro
## sitio, y ésta es de la persona —«por ahí no se pasa»— y tiene que durar la
## jornada. Sin ella se vuelve a elegir el mismo cotarro detrás del mismo
## cortado en cuanto se queda uno libre. Ver `SettlementSim._give_up_on`.
var given_up: Array[Vector3] = []

var stuck_hours: float = 0.0
var stuck_where: Vector3 = Vector3.ZERO

## El ultimo dia en que se conto que esta persona se quedo atascada. Una vez
## al dia y por persona: un aviso repetido deja de leerse, y la cronica salia
## con once identicos el primer dia.
var stuck_told: int = -1


## Las SALIDAS que ha hecho: una por ascension, una por reconocimiento, una
## por expedicion.
##
## Cada apunte es `{kind, day, hour, ended, metres, farthest, place, outcome}`.
##
## Existe porque juntar toda la actividad en una linea no dice nada: «2 jorn.
## de ascension» no distingue haber coronado dos picos de haberse dado la
## vuelta dos veces a media pared, y son partidas distintas.
var journeys: Array[Dictionary] = []

## La salida en curso. Vacia mientras se esta en el campamento.
var journey: Dictionary = {}

## Cuantas salidas se recuerdan. Cuarenta son varias temporadas de un
## explorador; mas no cabe en un panel que se lee de un vistazo.
const JOURNEY_LIMIT := 40


## Empieza a contar una salida.
func begin_journey(what: String, day_value: int, hour_value: float,
		home: Vector3) -> void:
	journey = {
		"kind": what, "day": day_value, "hour": hour_value,
		# El oficio con el que se salio, apuntado AQUI y no leido del que se
		# tenga luego. Sin esto, el dia que la despensa llega al tope que puso
		# el jugador toda la recoleccion cambia de oficio a la vez y el visor
		# de rastros -que filtraba por el oficio de AHORA- se quedaba en
		# blanco de golpe: los caminos del monte desaparecian todos el mismo
		# dia sin que nadie hubiera dejado de andarlos.
		"job": int(job),
		"ended": day_value, "metres": 0.0, "farthest": 0.0,
		"place": "", "outcome": "", "home": home,
		# El punto mas lejano al que se llego. Es el que da nombre a la salida
		# cuando no termina: al volver, el destino ya es el propio abrigo.
		"far_point": position,
		# El camino de ESTA salida. Va aqui y no en el rastro comun porque el
		# rastro es un anillo que se va tirando lo viejo: dibujandolo desde
		# ahi solo se veia el ultimo trecho, y lo que se quiere ver es por
		# donde ha ido la banda, todo.
		"path": PackedVector3Array([position]),
	}


## Un paso mas de la salida en curso.
## Cuantos puntos se guardan del camino de una salida. Doscientos cuarenta a
## un punto cada veinticinco metros son seis kilometros de detalle fino; a
## partir de ahi se sigue contando la distancia pero se deja de afinar la
## linea, que ya se entiende igual.
const PATH_POINTS := 240


func note_step(metres: float, home: Vector3) -> void:
	if journey.is_empty():
		return
	journey["metres"] = float(journey["metres"]) + metres
	var reach := home.distance_to(position)
	if reach > float(journey["farthest"]):
		journey["farthest"] = reach
		journey["far_point"] = position

	var path: PackedVector3Array = journey["path"]
	if path.is_empty() or (path.size() < PATH_POINTS
			and path[path.size() - 1].distance_to(position) > 25.0):
		path.append(position)
		journey["path"] = path


## Distancia minima para que una salida cuente como salida.
##
## Cincuenta metros. Es la red de seguridad del historial: cualquier camino
## que abra una salida y la cierre sin haber andado nada -y basta un fallo de
## estados para que eso pase cada tick- llenaria las cuarenta plazas en un
## suspiro y borraria las salidas de verdad. Ya paso una vez.
const JOURNEY_MIN_M := 50.0


## Cierra la salida y la guarda, si merecio el nombre.
func end_journey(day_value: int, place: String, outcome: String) -> void:
	if journey.is_empty():
		return
	if float(journey["metres"]) < JOURNEY_MIN_M:
		journey = {}
		return
	journey["ended"] = day_value
	journey["place"] = place
	journey["outcome"] = outcome
	journeys.append(journey)
	journey = {}
	while journeys.size() > JOURNEY_LIMIT:
		journeys.remove_at(0)


## Anota donde esta y que hace, si merece la pena.
##
## SOLO si se ha movido de verdad, o si hay algo que contar.
##
## Antes tambien se apuntaba al cambiar de tarea, y eso vaciaba el rastro: una
## noche en el campamento son decenas de cambios de estado -ocioso, comiendo,
## durmiendo- y en una sola noche se llenaban los trescientos huecos, tirando
## la expedicion entera que se acababa de hacer. De ahi el «0 km, lo mas lejos
## 0 m» despues de una salida larga.
func mark_trail(day_value: int, hour_value: float, note: String = "") -> void:
	var last: Dictionary = trail[trail.size() - 1] if not trail.is_empty() else {}
	if not note.is_empty() or last.is_empty():
		pass
	else:
		var moved: float = (last["pos"] as Vector3).distance_to(position)
		if moved < 25.0:
			return

	trail.append({
		"pos": position, "day": day_value, "hour": hour_value,
		"state": int(state), "task": current_task(), "note": note,
	})
	if trail.size() > TRAIL_LIMIT:
		trail.remove_at(0)


## Lo que FALTA del camino, desde donde se esta.
##
## La linea que se pintaba salia de la persona hasta el primer hito del camino
## -que puede quedar a un kilometro detras si ya se ha andado casi todo- y
## luego volvia. Se veia un triangulo enorme de ida y vuelta que no era el
## camino de nadie: era el trozo ya andado, dibujado al reves.
func remaining_route() -> PackedVector3Array:
	if route_step <= 0:
		return route
	var out := PackedVector3Array()
	for i in range(route_step, route.size()):
		out.append(route[i])
	return out


func next_waypoint() -> Vector3:
	if route_step < route.size():
		return route[route_step]
	return target


## Centro de la zona que está trabajando hoy, y el punto concreto al que se
## dirige dentro de ella.
##
## Un recolector no se planta en un sitio y recoge durante seis horas: batea
## la mancha, va de mata en mata. Antes llegaba a un punto, se quedaba clavado
## allí toda la jornada y volvía, que se lee como un autómata.
var work_centre: Vector3 = Vector3.ZERO
var forage_target: Vector3 = Vector3.ZERO


## Horas que lleva reconociendo la comarca adonde se le mandó.
##
## Llegar a un sitio no es explorarlo. Antes bastaba con pisar el punto y la
## orden se daba por cumplida: eso es marcar una casilla, no reconocer una
## comarca. Ahora hay que pasar allí una jornada batiendo los alrededores.
var survey_hours: float = 0.0


## Jornadas que le quedan de andar tocado por un percance.
##
## Mientras dura, rinde menos y anda mas despacio: es el precio de haber
## mandado la partida lejos, y se paga durante dias, no en el momento.
var hurt_days: int = 0


## Cuanto le penaliza el percance, de 0 -entero- a 1.
func hurt_factor() -> float:
	if hurt_days <= 0:
		return 0.0
	return clampf(float(hurt_days) / 8.0, 0.15, 0.55)


## Progreso hacia la siguiente pieza del taller, de 0 a 1.
##
## Va por persona y no por banda porque si no, dos artesanos a medias de dos
## piezas distintas sumarian una entera, que es justo lo que no pasa.
var craft_progress: float = 0.0

## Lo que multiplica su paso ahora mismo, de 0 a 1.
##
## Existe por el ACECHO. Acechar no es ir hacia el animal: es ir hacia el
## animal sin que se entere, y eso se hace parando y agachándose. Sin un paso
## propio, un cazador al acecho cruza el prado a la misma velocidad con la que
## vuelve cargado a casa, y desde fuera acechar y andar se ven igual.
##
## Lo pone [SettlementSim._walk_at] cada tick de cacería y se devuelve a 1 al
## empezar el siguiente, así que no se queda pegado: si mañana esta persona
## está recogiendo avellanas, anda como todo el mundo. Ver [Hunt].
var hunt_pace: float = 1.0

## El relato que trae y todavía no ha contado.
##
## Se levanta DONDE PASA —al cobrar la pieza, que es donde están los hechos: la
## especie, el sitio, si les vieron venir— y se cuenta AL LLEGAR, que es cuando
## hay quien lo oiga. Las dos cosas en el mismo sitio darían una de las dos
## mal: contarlo en el monte es hablarle a los árboles, y armarlo en la cueva
## obligaría a arrastrar los hechos hasta allí. Ver [Tale].
var pending_tale: Tale = null

## Horas de jornada que le quedan de RASTREO antes de poder levantar otra
## pieza. Ver `SettlementSim._tracking_hours`, que explica de dónde sale el
## número y por qué va delante del acecho y no dentro.
var hunt_cooldown: float = 0.0

## Última jornada en la que revisó la línea de nasas.
##
## Existe porque la ronda es UNA VEZ AL DÍA y el bucle de la simulación entra
## en `_creel_round` sesenta veces por segundo. Sin esta marca, el pescador que
## tenía una nasa sin cebo se pasaba la jornada entera cebándola tick tras tick
## y no llegaba a mojar el arpón: medido con `CaceriaProbe`, la pesca de orilla
## cayó de 7,68 raciones por jornada-persona a 3,22.
var creel_day: int = 0

## Especialidad que está ejerciendo AHORA. Con `speciality` fijada son la
## misma; con NINGUNA, esta la decide la simulación cada jornada.
var current_speciality: int = Profession.Speciality.NINGUNA

## Necesidades, 0 = saciado, 100 = critico. Son de ESTA persona, no del grupo.
var hunger: float = 20.0
var fatigue: float = 10.0
var cold: float = 0.0

## Que hace ahora
var state: State = State.OCIOSO
var activity: Subsistence.Activity = Subsistence.Activity.CAZA
var has_task: bool = false

## Posiciones en el mapa local
var position: Vector3 = Vector3.ZERO
var target: Vector3 = Vector3.ZERO

## Lo que lleva encima, por material: {Materia.Kind: unidades}
var load: Dictionary = {}

## Lo que lleva encima, en jornadas-persona. Se mantiene para el balance de
## comida, que sigue contando en raciones.
var carrying: float = 0.0

## Recipientes que lleva. Deciden cuántos kilos puede traer de una jornada, y
## por eso deciden cuánto rinde de verdad la recolección.
##
## Son PIEZAS DEL TALLER, no materia prima del almacén: un odre es una piel
## raspada, cosida y engrasada, y un cesto son tres de fibra trenzada. Se
## miraba si había piel y fibra en bruto en el abrigo, que es como decir que
## cualquiera lleva agua encima porque en casa hay un pellejo sin curtir.
## Ver `SettlementSim._hand_out_containers`.
var has_basket: bool = false
var has_waterskin: bool = false

## Horas de agua que le quedan encima.
##
## Se llena al beber -junto al agua o en el abrigo- y baja mientras se anda y
## se trabaja lejos de ella. A cero hay que ir a beber, y eso parte la jornada
## por la mitad: es lo que hace que el odre valga para algo y no sea un número
## más de capacidad de carga.
var water_left: float = 0.0

## Horas que lleva buscando en el paraje actual. Prospectar cuesta tiempo:
## encontrar un avellanar bueno no es instantáneo.
var search_hours: float = 0.0

## --- El vivac ------------------------------------------------------------
##
## Dormir fuera no es sólo comer de la mochila. Hace falta una piel para armar
## una tienda pequeña y leña para la hoguera, y quien no las lleva pasa la noche
## a la intemperie. Ver `SettlementSim._bivouac`.

## Última jornada en la que se pagó el vivac. La noche se cobra UNA vez, no en
## cada tick.
var bivouac_day: int = -1

## De cuántas de las dos cosas se durmió sin, anoche.
var bivouac_lack: int = 0

## Si anoche armó mal el vivac. Es SABER, no material: se puede llevar la piel
## y la leña y aun así montar algo que no aguanta la noche. Lo decide el saber
## del hogar —ver `SettlementSim._camps_well`—, y se paga a la mañana
## siguiente en cansancio.
var bivouac_botched: bool = false

## Lo que se sacó DEL ALMACÉN para esta salida: víveres, la piel de la tienda,
## la leña de la hoguera.
##
## Existe para no contarlo dos veces. Al volver, todo lo que trae encima se
## apunta como producción de la banda, y la mitad de lo que traía un explorador
## era lo que se había llevado de casa sin gastar: la despensa decía que la
## banda producía comida que sólo había ido y vuelto en una mochila.
var carried_out: Dictionary = {}


## Si esta noche hay hoguera encendida donde acampa. Lo pone la simulación al
## cobrar la noche y lo dibuja [BivouacFires]: la leña se gastaba y no se veía,
## así que dormir con fuego y dormir sin él eran el mismo punto en la oscuridad.
var bivouac_fire: bool = false

## Destreza por actividad, 0-1. Sube con la practica: es el saber tacito.
var skill: Dictionary = {}

## Techo de destreza con la que se puede NACER a una partida, por grupo de
## edad. Nadie se sienta a la partida ya experto: lo que trae de fabrica es
## lo que ha podido ver y probar antes de que empiece a contar el reloj del
## juego -treinta como mucho-, y solo un anciano, con una vida entera detras,
## puede llegar a cincuenta. Un crio no ha tenido tiempo de nada: entra en
## cero y todo lo que sepa lo aprende jugando, en el tajo o al amor del fuego.
const ADULT_SKILL_RANGE := Vector2(0.05, 0.30)
const ELDER_SKILL_RANGE := Vector2(0.15, 0.50)


## Rellena la destreza de partida segun la edad. Se llama al crear y otra vez
## si `create_band` decide despues a que grupo de edad toca esta persona -la
## edad se reparte por CUPO y no se sabe hasta ese momento.
func seed_skills(rng: RandomNumberGenerator) -> void:
	# Se siembra por TAREA: cada especialidad tiene su propia pericia, asi que
	# un tallador no nace sabiendo curtir
	for job_key: int in Profession.CATALOGUE:
		if job_key == Profession.Job.OCIOSO:
			continue
		for task: int in Profession.tasks_of(job_key as Profession.Job):
			skill[task] = _starting_skill(rng)


func _starting_skill(rng: RandomNumberGenerator) -> float:
	match age_group:
		Age.NINO:
			return 0.0
		Age.ANCIANO:
			return rng.randf_range(ELDER_SKILL_RANGE.x, ELDER_SKILL_RANGE.y)
		_:
			return rng.randf_range(ADULT_SKILL_RANGE.x, ADULT_SKILL_RANGE.y)


## Cuanto cunde una hora de practica o una noche de relato, segun la edad.
##
## Un crio absorbe rapidisimo -es lo que hace un crio todo el dia, mirar y
## copiar-, el adulto aprende al ritmo normal del juego, y al anciano ya casi
## no se le fija destreza nueva: lo que sabe lo sabe de antes, y de aqui en
## adelante enseña mas de lo que aprende. Ver [SettlementSim] -practica en el
## tajo y transmision nocturna- y [Ascent].
const LEARN_RATE_CHILD := 2.5
const LEARN_RATE_ADULT := 1.0
const LEARN_RATE_ELDER := 0.25

## Cuanto pesa la agudeza personal sobre esa velocidad base de la edad: con
## poca agudeza se aprende mas despacio que la media de su edad, y con mucha
## mas rapido -un crio espabilado saca mas partido a los tres años y medio
## que dan los otros críos, y un adulto espabilado tambien al suyo.
const APTITUDE_LEARN_RANGE := Vector2(0.6, 1.5)

func learn_rate() -> float:
	var age_factor: float
	match age_group:
		Age.NINO: age_factor = LEARN_RATE_CHILD
		Age.ANCIANO: age_factor = LEARN_RATE_ELDER
		_: age_factor = LEARN_RATE_ADULT
	return age_factor * lerpf(APTITUDE_LEARN_RANGE.x, APTITUDE_LEARN_RANGE.y,
		stat_in(Stat.AGUDEZA))


## Rasgos fisicos y mentales, 0-1. Ver [Stat]: a diferencia de `skill` no se
## siembran a cero ni suben por HITO, cambian despacio y solo con el uso
## sostenido -una vida, no una temporada-.
var stats: Dictionary = {}

## Rango de FUERZA y RESISTENCIA de partida, por edad: el cuerpo hace lo que
## hace un cuerpo de esa edad, con margen para la variacion personal. Un
## crio no tiene el brazo de un adulto por mucho que se entrene, y un
## anciano ya ha bajado del pico aunque siga tirando.
const CHILD_PHYSICAL_RANGE := Vector2(0.05, 0.25)
const ADULT_PHYSICAL_RANGE := Vector2(0.30, 0.75)
const ELDER_PHYSICAL_RANGE := Vector2(0.15, 0.45)

## La agudeza NO se escala por edad: la edad ya gobierna la velocidad base de
## aprendizaje en `learn_rate`. Esto es la variacion de PERSONA sobre esa
## base -hay críos mas espabilados que otros críos, y adultos mas espabilados
## que otros adultos-, y por eso el rango es el mismo para todos.
const AGUDEZA_RANGE := Vector2(0.15, 0.85)


## Rellena fuerza, resistencia y agudeza de partida. Igual que `seed_skills`,
## se llama al crear y otra vez si `create_band` cambia despues el grupo de
## edad.
func seed_stats(rng: RandomNumberGenerator) -> void:
	var physical := _physical_range()
	stats[Stat.FUERZA] = rng.randf_range(physical.x, physical.y)
	stats[Stat.RESISTENCIA] = rng.randf_range(physical.x, physical.y)
	stats[Stat.AGUDEZA] = rng.randf_range(AGUDEZA_RANGE.x, AGUDEZA_RANGE.y)


func _physical_range() -> Vector2:
	match age_group:
		Age.NINO: return CHILD_PHYSICAL_RANGE
		Age.ANCIANO: return ELDER_PHYSICAL_RANGE
		_: return ADULT_PHYSICAL_RANGE


func stat_in(stat: Stat) -> float:
	return float(stats.get(stat, 0.5))


## Entrena un rasgo fisico. Deliberadamente lento -quien llame a esto pasa
## cantidades muy pequeñas-: son años de vida, no jornadas de tajo.
func train_stat(stat: Stat, amount: float) -> void:
	stats[stat] = clampf(stat_in(stat) + amount, 0.0, 0.95)


## Cuanto multiplica la FUERZA lo que se puede cargar. Ver `carry_limit_kg`.
const STRENGTH_CARRY_RANGE := Vector2(0.65, 1.5)

## Cuanto multiplica la RESISTENCIA la fatiga que se acumula por hora. Va AL
## REVES que los demas rangos -mucha resistencia da un factor BAJO- porque
## quien mas aguanta es quien menos fatiga gana por la misma hora de tajo.
const ENDURANCE_FATIGUE_RANGE := Vector2(0.7, 1.35)

## Cuanto cunde una hora de fatiga, segun la resistencia. Se multiplica en
## cada sitio de [SettlementSim] donde se gana fatiga -andar, trabajar,
## reconocer, intentar una cumbre-.
func fatigue_factor() -> float:
	return lerpf(ENDURANCE_FATIGUE_RANGE.y, ENDURANCE_FATIGUE_RANGE.x,
		stat_in(Stat.RESISTENCIA))


## Rasgos personales que no son un oficio. Ver [Trait]: casi nadie empieza
## con ninguno, y se entrenan haciendo la cosa concreta -nadar se aprende
## nadando, no reconociendo terreno seco.
var traits: Dictionary = {}

## Probabilidad de haber crecido junto al agua y ya saber nadar algo al
## empezar la partida. El resto arranca en cero: no es un saber que traiga
## todo el mundo, es lo que tienen unos pocos y lo que el resto aprende -o
## no- viviendo junto al rio.
const NATACION_STARTING_CHANCE := 0.2
const NATACION_STARTING_RANGE := Vector2(0.15, 0.45)


func seed_traits(rng: RandomNumberGenerator) -> void:
	traits[Trait.NATACION] = rng.randf_range(
		NATACION_STARTING_RANGE.x, NATACION_STARTING_RANGE.y) \
		if rng.randf() < NATACION_STARTING_CHANCE else 0.0
	# Sin animal domestico en esta era, no hay nada que montar ni domar. Ver
	# el aviso en [Trait].
	traits[Trait.MONTA] = 0.0
	traits[Trait.DOMA] = 0.0


func trait_in(trait_kind: Trait) -> float:
	return float(traits.get(trait_kind, 0.0))


## Entrena un rasgo personal. Igual de lento que `train_stat` y por la misma
## razon: es una destreza del cuerpo, no del oficio.
func train_trait(trait_kind: Trait, amount: float) -> void:
	traits[trait_kind] = clampf(trait_in(trait_kind) + amount, 0.0, 0.95)


static func create(index: int, home: Vector3, rng: RandomNumberGenerator) -> Inhabitant:
	var person := Inhabitant.new()
	person.id = index
	person.given_name = NAMES[index % NAMES.size()]
	if index >= NAMES.size():
		person.given_name += " " + str(index / NAMES.size() + 1)

	# La edad la pone quien crea la banda, por CUPO. Ver [create_band].
	#
	# Sorteandola persona a persona salian bandas inviables: con quince
	# tiradas independientes al 30% de crios, una partida de verdad dio DOCE
	# crios de quince, o sea dos adultos para cazar, pescar, explorar y
	# mantener el fuego. Una banda no se forma echando dados uno a uno: tiene
	# la composicion que tiene, y de ella depende que el juego sea jugable.
	person.age_group = Age.ADULTO
	person.age_years = rng.randi_range(18, 40)

	person.sex = Sex.MUJER if rng.randf() < 0.5 else Sex.HOMBRE

	person.position = home
	person.target = home
	person.hunger = rng.randf_range(10.0, 35.0)
	person.seed_skills(rng)
	person.seed_stats(rng)
	person.seed_traits(rng)
	return person


## Puede salir a trabajar? Los ninos y los ancianos ayudan cerca de casa, no
## se van de caceria.
func can_work() -> bool:
	return age_group == Age.ADULTO


## Cuanto rinde: destreza por estado. Alguien hambriento o agotado cunde menos.
func effectiveness() -> float:
	var condition := 1.0 - (hunger / 220.0) - (fatigue / 260.0) - (cold / 300.0) 		- hurt_factor()
	return clampf(skill_in(current_task()) * 1.4, 0.2, 1.4) * clampf(condition, 0.15, 1.0)


## Lo que come al dia, en jornadas-persona. Un nino come menos.
## Lo que come al dia, en RACIONES.
##
## Dos para un adulto, y no una: una racion es media jornada -lo que se come en
## cada una de las dos comidas del dia, ver [Materia.KCAL_RACION]-. Antes un
## adulto figuraba con una racion diaria y a la vez comia dos veces, asi que la
## despensa decia el doble de dias de los que aguantaba.
##
## Los factores de edad no cambian: un crio come el 60 % de lo que come un
## adulto y un anciano el 85 %.
func daily_food() -> float:
	match age_group:
		Age.NINO: return 2.0 * 0.6
		Age.ANCIANO: return 2.0 * 0.85
		_: return 2.0


func age_name() -> String:
	match age_group:
		Age.NINO: return "niño"
		Age.ANCIANO: return "anciano"
		_: return "adulto"


## El nombre de un estado cualquiera, sin necesitar la persona. Lo usa el
## parte de atascos, que guarda el estado como numero.
static func new_state_name(value: int) -> String:
	match value:
		State.DURMIENDO: return "durmiendo"
		State.YENDO: return "de camino"
		State.BUSCANDO: return "buscando"
		State.TRABAJANDO: return "trabajando"
		State.VOLVIENDO: return "volviendo"
		State.COMIENDO: return "comiendo"
		State.RECONOCIENDO: return "reconociendo"
		_: return "ocioso"


func state_name() -> String:
	match state:
		State.DURMIENDO: return "durmiendo"
		State.YENDO: return "de camino"
		State.BUSCANDO: return "buscando"
		State.TRABAJANDO: return "trabajando"
		State.VOLVIENDO: return "volviendo"
		State.COMIENDO: return "comiendo"
		State.RECONOCIENDO: return "reconociendo"
		_: return "ocioso"


## Resumen de una linea para la interfaz
## Kilos que lleva encima ahora mismo
func load_kg() -> float:
	var kg := 0.0
	for kind: int in load.keys():
		kg += float(load[kind]) * Materia.kg_per_unit(kind as Materia.Kind)
	return kg


## Lo que puede cargar, según los recipientes que lleve y su fuerza.
##
## Los recipientes ponen el TECHO -sin cesto no hay donde meter lo que se
## coge, por fuerte que se sea-, y la fuerza lo mueve dentro de ese techo:
## quien mas tira carga mas con el mismo cesto, y quien menos, menos.
func carry_limit_kg() -> float:
	return Storehouse.carry_capacity_kg(has_basket, has_waterskin) \
		* lerpf(STRENGTH_CARRY_RANGE.x, STRENGTH_CARRY_RANGE.y, stat_in(Stat.FUERZA))


## De 0 a 1, cuánto de su capacidad lleva ocupada
func load_fraction() -> float:
	return clampf(load_kg() / maxf(carry_limit_kg(), 0.001), 0.0, 1.0)


func add_load(kind: Materia.Kind, units: float) -> void:
	load[kind] = float(load.get(kind, 0.0)) + units


## Apunta que esto salió del almacén y no del monte. Ver `carried_out`.
func note_from_store(kind: Materia.Kind, units: float) -> void:
	if units <= 0.0:
		return
	carried_out[kind] = float(carried_out.get(kind, 0.0)) + units


## Cuánto de lo que lleva encima de esto salió del almacén.
func brought_from_store(kind: Materia.Kind) -> float:
	return float(carried_out.get(kind, 0.0))


## Saca de la mochila lo que se pueda, y dice cuánto salió de verdad.
func take_load(kind: Materia.Kind, units: float) -> float:
	var have: float = float(load.get(kind, 0.0))
	var taken := minf(have, units)
	if taken <= 0.0:
		return 0.0
	load[kind] = have - taken
	if load[kind] <= 0.0001:
		load.erase(kind)
	return taken


func summary() -> String:
	var task := Subsistence.activity_name(activity) if has_task else "sin tarea"
	return "%-7s %-8s %-11s %-12s h%3.0f c%3.0f" % [
		given_name, age_name(), task, state_name(), hunger, fatigue]


## Cupos de la pirámide de una banda cazadora-recolectora.
##
## Los números salen de la etnografía forrajera: en torno a un tercio de
## críos, poco más de la mitad de adultos y alrededor de un 10% que pasa de
## los cuarenta y cinco. Lo que cambia respecto a antes es que se REPARTEN, no
## se sortean: la composición de una banda no puede ser una tirada que te deje
## con dos adultos para todo.
const SHARE_CHILDREN := 0.33
const SHARE_ELDERS := 0.12


## Crea la banda entera, con una pirámide que siempre sale viable.
##
## Se garantiza además un mínimo de adultos capaces de jornada larga: sin
## ellos no hay partida de caza ni exploración, y una partida que arranca sin
## eso no arranca.
static func create_band(count: int, home: Vector3,
		rng: RandomNumberGenerator) -> Array[Inhabitant]:
	var children := int(round(float(count) * SHARE_CHILDREN))
	var elders := int(round(float(count) * SHARE_ELDERS))
	var adults := count - children - elders

	# Ocho adultos es lo que pide una banda para funcionar: partida de caza,
	# pesca, recolección y alguien en el hogar. Si el cupo no llega, se le
	# quitan críos, que es lo que hace una banda real al elegir con quién sale.
	var floor_adults := mini(8, count)
	while adults < floor_adults and children > 0:
		children -= 1
		adults += 1

	var people: Array[Inhabitant] = []
	for i in range(count):
		var person := create(i, home, rng)
		if i < children:
			person.age_group = Age.NINO
			person.age_years = rng.randi_range(2, 14)
		elif i < children + elders:
			person.age_group = Age.ANCIANO
			person.age_years = rng.randi_range(46, 64)
		else:
			person.age_group = Age.ADULTO
			person.age_years = rng.randi_range(16, 45)

		# `create` sembro la destreza y los rasgos fisicos suponiendo un
		# adulto -no hay edad hasta que se reparte el cupo, arriba-. Se
		# vuelven a sembrar ahora que ya se sabe de verdad quien es crio y
		# quien es anciano. Los rasgos personales (`traits`) no dependen de
		# la edad, asi que esos se quedan como salieron.
		person.seed_skills(rng)
		person.seed_stats(rng)

		# Criando. En una banda forrajera con intervalo entre partos de tres o
		# cuatro años, en torno a un tercio de las mujeres en edad reproductiva
		# lleva una cría de pecho. Es lo que de verdad limita las jornadas
		# largas: ver [Profession].
		person.nursing = person.age_group == Age.ADULTO 			and person.sex == Sex.MUJER and person.age_years < 40 			and rng.randf() < 0.33

		people.append(person)
	return people
