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
const HORA_MEDIODIA := 13.0   ## Parada: se come lo que se lleva
const HORA_FIN_MEDIODIA := 14.0
const HORA_REGRESO := 19.0    ## A esta hora hay que emprender la vuelta
const HORA_DORMIR := 21.0

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

## Que mejoras del abrigo estan hechas. Ver [CampProjects].
var camp_built: Dictionary = {}

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

var _time_manager: Node = null

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
var _bodies: Array[Node3D] = []
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
	game_seed = int(Time.get_unix_time_from_system() * 1000.0) & 0x7fffffff
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
	for i in range(6):
		toolkit.craft(Tool.Kind.CESTO, Tool.Stuff.FIBRA, 0.5)

	# La partida arranca EN PAUSA. Al fundar hay que repartir el trabajo, mirar
	# dónde se ha caído y decidir; que el reloj empiece a correr mientras el
	# jugador se orienta es quitarle la primera decisión de la partida.
	time_scale = 0.0

	camp_built = {}
	camp_queue = -1
	camp_progress = 0.0
	season_day = 0
	_peak_found = false

	# Cede el reloj de luz al de la banda. Sin esto el sol daba una vuelta
	# completa cada 24 segundos reales mientras la jornada de trabajo dura
	# 120: cinco amaneceres por cada dia de la banda.
	_time_manager = get_node_or_null("/root/TimeManager")
	if _time_manager:
		_time_manager.time_speed = 0.0

	# La banda se crea ENTERA, con cupos: sorteando la edad persona a persona
	# salian bandas de doce crios y dos adultos. Ver [Inhabitant.create_band].
	for person: Inhabitant in Inhabitant.create_band(population, home, _rng):
		# Repartidos alrededor del abrigo para que no salgan apilados
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(4.0, 22.0)
		person.position = home + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		person.position.y = _terrain.get_height_at(person.position)
		people.append(person)
		_bodies.append(_make_body(person))

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
	return _terrain.path_is_passable(home_position, stop, has_boat, has_bridge)


func set_work_site(activity: Subsistence.Activity, world_position: Vector3) -> void:
	work_sites[activity] = world_position


func _make_body(person: Inhabitant) -> Node3D:
	var body := MeshInstance3D.new()
	body.name = "P_%s" % person.given_name

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.9
	capsule.height = 3.2 if person.age_group != Inhabitant.Age.NINO else 2.1
	body.mesh = capsule

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.66, 0.48) if person.age_group == Inhabitant.Age.ADULTO \
		else (Color(0.95, 0.85, 0.60) if person.age_group == Inhabitant.Age.NINO
			else Color(0.72, 0.72, 0.78))
	material.roughness = 0.9
	body.material_override = material

	body.position = person.position + Vector3(0, 1.6, 0)
	add_child(body)
	return body


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

	# Exploracion y demas: se sigue mirando el material que producen
	var material := speciality_output(speciality)
	if material < 0:
		return 1.0
	var target: float = float(limits.get(material, 0.0))
	if target <= 0.0:
		target = float(people.size())
	return store.amount(material as Materia.Kind) / maxf(target, 0.001)


## Qué material produce cada especialidad. -1 si no produce ninguno todavía.
##
## De momento apunta a los materiales que ya existen; cuando estén las
## herramientas con su desgaste, esto pasará a devolverlas a ellas.
func speciality_output(speciality: Profession.Speciality) -> int:
	match speciality:
		Profession.Speciality.TALLA: return Materia.Kind.PIEDRA
		Profession.Speciality.ASTA: return Materia.Kind.HUESO
		Profession.Speciality.PELETERIA: return Materia.Kind.PIEL
		Profession.Speciality.CORDELERIA: return Materia.Kind.FIBRA
		_: return -1


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
		# La primera tarea del oficio: para los que no tienen especialidad es
		# el oficio a secas, y para los que si, la primera de la lista
		joining.set_priority(Profession.tasks_of(job)[0], 1)
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
	if work_sites.has(act):
		return true
	if not (_known_spots.get(act, []) as Array).is_empty():
		return true
	if parajes:
		for paraje: Paraje in parajes.list:
			if paraje.serves(act):
				return true
	return false


func apply_priorities() -> void:
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
				# Si no hay exploracion de por medio, gana lo que ya se
				# estaba haciendo si sigue empatado -no se cambia de tajo
				# cada jornada por deportividad- y si no, lo que mas falte.
				var current_task := Profession.task_id(person.job as Profession.Job,
					person.current_speciality as Profession.Speciality)
				if candidates.has(current_task):
					best = current_task
				else:
					var worst_ratio := INF
					for task: int in candidates:
						var ratio := _speciality_pressure(
							Profession.task_speciality(task) as Profession.Speciality)
						if ratio < worst_ratio:
							worst_ratio = ratio
							best = task

		var job := Profession.task_job(best)
		Profession.assign(job, person)
		person.speciality = Profession.task_speciality(best)
		person.current_speciality = person.speciality

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

	if _time_manager:
		_time_manager.sync_from(hour, day, GameState.season as int, GameState.year)

	# El tick se parte en trozos para que acelerar no cambie el resultado: con
	# un solo paso largo la gente atraviesa obstaculos que a velocidad normal
	# la pararian.
	var steps := maxi(int(ceil(time_scale)), 1)
	var slice := scaled / float(steps)
	var slice_hours := hours / float(steps)
	for _s in range(steps):
		for i in range(people.size()):
			_tick_person(people[i], _bodies[i], slice_hours, slice)


## Cuanto suben los rasgos fisicos por el uso, por hora. Muchisimo mas lento
## que la destreza -esta es una vida, no una temporada- y por eso los
## numeros son minusculos: con estos ritmos, notarse de verdad lleva años de
## partida, que es justo lo que tiene que costar cambiar el cuerpo de nadie.
const FUERZA_TRAINING_RATE := 0.00004
const RESISTENCIA_TRAINING_RATE := 0.00003

## A partir de cuanta fatiga trabajar cuenta como aguantar de verdad. Por
## debajo de esto es una jornada normal, no un esfuerzo que curta.
const RESISTENCIA_TRAINING_THRESHOLD := 55.0


func _tick_person(person: Inhabitant, body: Node3D, hours: float, delta: float) -> void:
	# Las necesidades corren para todos, trabajen o no
	person.hunger = clampf(person.hunger + hours * 3.4, 0.0, 100.0)
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
	if person.fatigue > RESISTENCIA_TRAINING_THRESHOLD \
			and person.state != Inhabitant.State.DURMIENDO \
			and person.state != Inhabitant.State.OCIOSO \
			and person.state != Inhabitant.State.COMIENDO:
		person.train_stat(Inhabitant.Stat.RESISTENCIA, hours * RESISTENCIA_TRAINING_RATE)

	# Fuera de la jornada. La gente se recoge, come y duerme a sus horas.
	var night := hour < HORA_DESPERTAR or hour >= HORA_DORMIR
	var winding_down := hour >= HORA_REGRESO and hour < HORA_DORMIR
	var morning := hour >= HORA_DESPERTAR and hour < HORA_SALIDA
	var midday := hour >= HORA_MEDIODIA and hour < HORA_FIN_MEDIODIA

	# A la hora de volver, todo el mundo emprende el regreso salvo quien esta
	# de expedicion. Sin esto la gente se quedaba trabajando hasta la noche y
	# volvia a oscuras, que es lo que hace un autómata, no una persona.
	if winding_down and person.state != Inhabitant.State.VOLVIENDO:
		var on_expedition := person.job == Profession.Job.EXPLORACION \
			and person.current_speciality != Profession.Speciality.BATIDA \
			and person.position.distance_to(home_position) > arrive_radius * 4.0
		if not on_expedition:
			_send_to(person, home_position)
			if person.position.distance_to(home_position) > arrive_radius:
				person.state = Inhabitant.State.VOLVIENDO
			else:
				_deliver(person)
				person.state = Inhabitant.State.OCIOSO

	# Al levantarse se desayuna, antes de salir. Comer en casa por la manana
	# es lo que permite aguantar la jornada sin cargar comida.
	if morning and person.hunger > 25.0 and store.food_rations() > 0.0:
		person.state = Inhabitant.State.COMIENDO

	# Parada de mediodia: se come de lo que se lleva, sin volver
	if midday and person.state == Inhabitant.State.TRABAJANDO \
			and person.hunger > 45.0:
		person.hunger = maxf(person.hunger - hours * 22.0, 0.0)

	if night:
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
			# Se descansa peor al raso que en el abrigo
			person.fatigue = maxf(person.fatigue - hours * 6.0, 0.0)
			# Y se cena de lo que se lleva
			_eat_from_pack(person, hours)
		else:
			_send_to(person, home_position)
			if person.position.distance_to(home_position) < arrive_radius:
				person.state = Inhabitant.State.DURMIENDO
				person.fatigue = maxf(person.fatigue - hours * 9.0, 0.0)
			elif person.route.is_empty():
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
				person.state = Inhabitant.State.VOLVIENDO
	else:
		match person.state:
			Inhabitant.State.DURMIENDO, Inhabitant.State.OCIOSO:
				# Solo se va a comer si HAY comida. Sin esta condicion, con el
				# almacen vacio la gente entraba en COMIENDO, no comia nada,
				# volvia a OCIOSO y repetia: una espiral de hambre en la que
				# nadie salia a buscar comida PORQUE tenia hambre.
				if person.hunger > 55.0 and store.food_rations() > 0.5:
					person.state = Inhabitant.State.COMIENDO
				elif person.job == Profession.Job.EXPLORACION \
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
				elif person.job == Profession.Job.HOGAR \
						and hour >= HORA_SALIDA and hour < HORA_REGRESO:
					# El hogar no tiene tajo fuera: se trabaja EN el
					# campamento, levantando lo que este en cola y, si ya hay
					# secadero, ahumando lo que haya llegado fresco.
					_tend_camp(person, hours)
				elif person.job == Profession.Job.MANUFACTURA \
						and hour >= HORA_SALIDA and hour < HORA_REGRESO:
					# El taller tampoco sale. En la tabla de oficios figura con
					# actividad MATERIA_PRIMA -es de donde saca lo que talla- y eso
					# lo mandaba cada manana a un cotarro de piedra al otro lado del
					# valle: medido, un tallador se pasaba el 79% del dia andando y
					# no entraba NUNCA en TRABAJANDO, o sea que no salia una sola
					# pieza. La materia prima la traen los recolectores; el artesano
					# trabaja sobre lo que hay en el abrigo, y si no hay, se va a su
					# siguiente oficio -ver `_speciality_can_work`.
					_craft(person, hours)
				elif person.has_task and hour >= HORA_SALIDA and hour < HORA_REGRESO:
					_send_to_work(person)
			Inhabitant.State.COMIENDO:
				# El hambre sube 3,4 por hora, o sea 81,6 en un dia entero. Una
				# racion tiene que quitar exactamente eso, porque una racion ES
				# lo que come un adulto en un dia.
				#
				# Antes eran dos numeros sueltos —hambre por hora y hambre por
				# racion— y no cuadraban: la banda consumia un 50% mas de lo
				# que decia `daily_food()`, asi que ninguna calibracion de la
				# produccion podia salir bien.
				var bite := _eat_from_store(hours * 3.0)
				# Cocinar no anade comida: hace que la que hay cunda mas. La
				# carne y la raiz al fuego se digieren mejor y dan mas
				# calorias aprovechables por la misma racion -es la tesis de
				# Wrangham sobre el fuego en la dieta humana-, asi que el
				# hogar no toca el almacen, toca cuanto quita el hambre.
				var cooked := 1.15 if camp_built.get(CampProjects.Kind.HOGAR, false) else 1.0
				person.hunger = maxf(person.hunger - bite * cooked * (3.4 * 24.0), 0.0)
				if person.hunger < 15.0 or bite <= 0.0:
					person.state = Inhabitant.State.OCIOSO
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
				if person.position.distance_to(home_position) < arrive_radius:
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
		if to_target.length() > 0.5:
			var direction := to_target.normalized()

			# La velocidad NO es constante. Sale de la funcion de marcha de
			# Tobler segun la pendiente EN EL SENTIDO DE LA MARCHA -no la del
			# terreno a secas, porque subir y bajar no cuestan lo mismo-, del
			# suelo que se pisa y de lo que se lleva encima.
			var pace := _terrain_speed(person, direction, hours) * weather.pace_factor()
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
						var goal := person.target
						person.route = PackedVector3Array()
						person.route_step = 0
						_send_to(person, goal)

			person.position += step
			person.note_step(step.length(), home_position)
			if step.length() > 0.01:
				person.blocked_steps = 0
			person.position.y = _terrain.get_height_at(person.position)
			# Andar cansa. Hace falta para que la batida tenga final: sin esto
			# el explorador nunca acumulaba fatiga y no volvia jamas.
			person.fatigue = clampf(
				person.fatigue + hours * 2.6 * person.fatigue_factor(), 0.0, 100.0)

	body.position = person.position + Vector3(0, 1.6, 0)
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
	for kind: int in [Materia.Kind.CARNE_SECA, Materia.Kind.FRUTO_SECO,
			Materia.Kind.GRASA]:
		if needed <= 0.0:
			break
		var k := kind as Materia.Kind
		var units := store.take(k, needed / maxf(Materia.nutrition(k), 0.001))
		if units > 0.0:
			person.add_load(k, units)
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
				needed -= units * Materia.nutrition(k)

	# Con menos de un dia de comida no se sale
	return needed <= person.daily_food() * (days - 1.0)


## Come de lo que lleva en la mochila, estando fuera.
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
func order_ascent(peak: Dictionary) -> String:
	if peak.is_empty():
		return "No hay tal cumbre."
	var hardness := float(peak.get("hard", 1.0))

	if Ascent.needs_gear(hardness):
		return "Esa pared no se sube con lo que hay. Haría falta cuerda de " \
			+ "verdad y quien sepa asegurar, y eso todavía no se sabe hacer."

	if not _climbing_party_enough(hardness):
		return "Una cumbre así no se ataca en solitario: hacen falta al menos " \
			+ "%d en ascensión antes de intentarla." % MIN_CLIMBING_PARTY

	var climber := climber_for(peak)
	if climber == null:
		return "No hay ningún miembro de la banda con habilidad suficiente."

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


## Trabajo de quien esta en el hogar: no sale del campamento. Si hay un
## proyecto en cola lo saca adelante; si no, y ya hay secadero, ahuma lo que
## haya de carne fresca. Sin ninguna de las dos cosas, simplemente cuida del
## fuego y de quien no puede valerse solo, que es lo que ya hacia antes de
## que existiera nada de esto.
func _tend_camp(person: Inhabitant, hours: float) -> void:
	var fraction := hours / HORAS_UTILES
	if fraction <= 0.0:
		return

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

	if camp_built.get(CampProjects.Kind.SECADERO, false):
		_dry_meat(fraction, person.effectiveness())
		person.log_deed(person.current_task(), "ahumando carne", false)
	else:
		person.log_deed(person.current_task(), "manteniendo el fuego", false)


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
	camp_queue = -1
	camp_progress = 0.0
	_camp_paid = false
	_note(Chronicle.Kind.OBRA,
		"Queda levantado el %s del abrigo, obra de %s."
			% [CampProjects.project_name(kind).to_lower(), person.given_name], 2)


## Cuanto ahuma un dia entero de trabajo al frente del secadero, a rendimiento
## perfecto. Una persona no seca una res al dia: es un goteo constante,
## limitado sobre todo por cuanta carne fresca vaya llegando de la caza.
const DRY_PER_DAY := 4.0


func _dry_meat(fraction: float, skill: float) -> void:
	var capacity := DRY_PER_DAY * fraction * skill
	var available := store.amount(Materia.Kind.CARNE)
	var dried := minf(capacity, available)
	if dried <= 0.0:
		return
	store.take(Materia.Kind.CARNE, dried)
	store.add(Materia.Kind.CARNE_SECA, dried)


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
	# Los recipientes se cogen al salir, de lo que haya en el abrigo
	person.has_basket = store.amount(Materia.Kind.FIBRA) >= 1.0
	person.has_waterskin = store.amount(Materia.Kind.PIEL) >= 1.0
	# Lo que lleve encima se entrega ANTES de salir de nuevo. Estaba
	# limpiandose sin mas, asi que quien acababa la jornada sin pasar por el
	# abrigo -porque se atasco, porque se le cambio el oficio- perdia la carga
	# entera y nadie se enteraba: entre lo traido y lo guardado faltaba un
	# tercio de TODO, y el reparto era identico material a material, que es la
	# firma de una fuga y no de un gasto.
	if not person.load.is_empty():
		if person.position.distance_to(home_position) < arrive_radius * 2.0:
			_deliver(person)
		else:
			lost_loads += 1
	person.load.clear()
	person.carrying = 0.0
	person.search_hours = 0.0

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

	var destination := _best_known_spot(person)
	if destination == Vector3.ZERO:
		destination = _search_target(person)

	_send_to(person, destination)
	if person.route.is_empty():
		# Al tajo no se llega: se queda en el campamento en vez de salir a
		# estrellarse contra el rio
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


## Parajes conocidos por actividad, ya puntuados y ordenados. Se rehace una vez
## al dia, no una vez por persona: recorrer las 4.096 celdas del campo cada vez
## que alguien salia de casa dejaba la simulacion inservible.
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
				# `walk_speed` va en unidades por segundo REAL, y una hora de
				# juego son `seconds_per_day / 24` segundos reales: sin esa
				# conversión el viaje salía en unas unidades que no eran horas.
				var per_hour := walk_speed * (seconds_per_day / 24.0)
				var travel := 2.0 * distance / maxf(per_hour, 0.1)
				var usable := clampf(1.0 - travel / HORAS_UTILES, 0.1, 1.0)
				var stock := field.stock_fraction_around(act, centre, 90.0)
				spots.append({
					"pos": centre,
					"score": value * usable * stock,
				})

		spots.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
		# Solo interesan los mejores: con veinte hay de sobra para repartir a
		# una banda de quince
		_known_spots[activity] = spots.slice(0, mini(spots.size(), 20))


## El mejor paraje que la banda CONOCE para esa actividad y que este a tiro.
## Devuelve ZERO si no conoce ninguno: entonces toca prospectar.
func _best_known_spot(person: Inhabitant) -> Vector3:
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


## Cuantas piezas de cada tipo le hacen falta a la banda ahora mismo.
##
## Sale de quien esta trabajando en que, no de una tabla fija: si el jugador
## pone a cinco a pescar, la demanda de arpones sube sola y el taller lo nota
## sin que nadie tenga que pedirlo.
func tool_demand() -> Dictionary:
	var demand := {
		Tool.Kind.LASCA: maxi(people.size() / 2, 2),
		Tool.Kind.AZAGAYA: workers_in(Subsistence.Activity.CAZA),
		Tool.Kind.ARPON: workers_in(Subsistence.Activity.PESCA),
		Tool.Kind.CESTO: workers_in(Subsistence.Activity.RECOLECCION),
		Tool.Kind.RAEDERA: 2,
		Tool.Kind.BURIL: 2,
		Tool.Kind.AGUJA: 2,
		Tool.Kind.PUNZON: 1,
		Tool.Kind.CUERDA: 3,
		Tool.Kind.ODRE: 2,
		Tool.Kind.PUNTA: 2,
	}
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
	return {
		Tool.Kind.LASCA: maxi(people.size() / 2, 2),
		Tool.Kind.AZAGAYA: workers_in(Subsistence.Activity.CAZA),
		Tool.Kind.ARPON: workers_in(Subsistence.Activity.PESCA),
		Tool.Kind.CESTO: workers_in(Subsistence.Activity.RECOLECCION),
		Tool.Kind.RAEDERA: 2,
		Tool.Kind.BURIL: 2,
		Tool.Kind.AGUJA: 2,
		Tool.Kind.PUNZON: 1,
		Tool.Kind.CUERDA: 3,
		Tool.Kind.ODRE: 2,
		Tool.Kind.PUNTA: 2,
	}


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


## Lo que la banda ha traído HOY, por material, y la media de los últimos
## días. La columna PRODUCE del almacén sale de aquí.
##
## Es producción MEDIDA, no una estimación a partir de las tablas: entre lo
## nominal y lo que de verdad entra hay cinco penalizaciones y un día que se
## va casi entero en andar -ver [HARVEST_SCALE]-, así que una estimación
## habría dicho diez veces más de lo que el jugador ve llegar al abrigo.
var produced_today: Dictionary = {}
var produced_per_day: Dictionary = {}

## Cuánto pesa el día de hoy en la media. Con 0,35 la cifra reacciona en
## dos o tres jornadas sin dar saltos por un día bueno.
const PRODUCTION_SMOOTHING := 0.35


## Apunta lo que acaba de entrar en el almacén.
func note_production(kind: Materia.Kind, units: float) -> void:
	if units <= 0.0:
		return
	produced_today[int(kind)] = float(produced_today.get(int(kind), 0.0)) + units


## Lo que produce la banda de esto al día, en unidades.
func production_of(kind: Materia.Kind) -> float:
	return float(produced_per_day.get(int(kind), 0.0))


## Y lo mismo para el taller. Las piezas van con clave NEGATIVA para no
## chocar con los materiales, igual que en el libro de trabajo de cada cual.
func note_tool_made(kind: Tool.Kind) -> void:
	var key := -1 - int(kind)
	produced_today[key] = float(produced_today.get(key, 0.0)) + 1.0


func tool_production_of(kind: Tool.Kind) -> float:
	return float(produced_per_day.get(-1 - int(kind), 0.0))


## Cierra el día de producción y lo mete en la media.
func _roll_production() -> void:
	var kinds := {}
	for key: int in produced_today:
		kinds[key] = true
	for key: int in produced_per_day:
		kinds[key] = true

	for key: int in kinds:
		var today := float(produced_today.get(key, 0.0))
		var before := float(produced_per_day.get(key, 0.0))
		produced_per_day[key] = before + (today - before) * PRODUCTION_SMOOTHING
	produced_today.clear()


## Materiales que NO están en todas partes: solo salen del paraje que los
## tiene. Son los que dan nombre a un sitio por sí solos -una veta de
## sílex, una de ocre, un desmogadero- frente a la piedra corriente, que se
## coge de cualquier canchal.
const LOCAL_ONLY := [Materia.Kind.SILEX, Materia.Kind.OCRE, Materia.Kind.ASTA]


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
## 1,8 lo pone en torno a 1,2 raciones por jornada al empezar -duro, porque
## uno solo no da de comer a dos, pero no imposible-. Va aquí, en un sitio
## único y con nombre, en vez de repartido por las tablas de rendimiento:
## así se toca UN número para mover la dificultad y las proporciones entre
## oficios se quedan como estaban.
const HARVEST_SCALE := 5.5


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
	var left := 1.0
	if field:
		left = field.deplete_at(person.activity, person.position,
			fraction * DEPLETION_PER_DAY)

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

	var multiplier := fraction * skill * season * left * tool_factor 		* weather.work_factor() * HARVEST_SCALE
	if multiplier <= 0.0:
		return

	var yields := _yields_for(person)
	var food := 0.0
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

		person.add_load(kind as Materia.Kind, fits)
		person.log_gain(person.current_task(), kind, fits)
		if Materia.is_food(kind as Materia.Kind):
			food += fits * Materia.nutrition(kind as Materia.Kind)

	person.carrying += food


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
		Tool.Kind.AGUJA, Tool.Kind.PUNZON],
	Profession.Speciality.PELETERIA: [Tool.Kind.ODRE],
	Profession.Speciality.CORDELERIA: [Tool.Kind.CUERDA, Tool.Kind.CESTO],
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
	if not SPECIALITY_MAKES.has(speciality):
		return true
	return _next_piece(speciality) >= 0


## Trabajo de taller. Se llama en lugar de la cosecha para quien esta en
## manufactura: no trae nada del monte, gasta lo que hay en el abrigo y saca
## piezas.
##
## Lo que no se puede hacer se queda sin hacer y punto, sin penalizacion
## escondida. La falta se ve en el panel, que es donde tiene que verse.
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
		note_production(kind as Materia.Kind, units)
		rejected += store.overflow
	person.load.clear()
	person.carrying = 0.0
	if rejected > 0.01:
		storage_full.emit(rejected)


## Come del almacen, empezando por lo que antes se echa a perder.
##
## El orden importa: comerse primero la carne fresca y dejar el fruto seco para
## el final es lo que de verdad hacia una banda, y ademas es lo optimo.
func _eat_from_store(rations: float) -> float:
	var order := [Materia.Kind.PESCADO, Materia.Kind.MARISCO, Materia.Kind.CARNE,
		Materia.Kind.GRASA, Materia.Kind.CARNE_SECA, Materia.Kind.FRUTO_SECO]
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

	if ground == Traversal.Ground.MARISMA:
		# El barro y el agua somera es donde de verdad se nota saber nadar:
		# quien nada no lucha con cada paso igual que quien no. No abre paso
		# donde antes no lo habia -eso pide tocar la rejilla compartida, ver
		# `NATACION` en Inhabitant- pero cruza lo que ya se cruza mucho mejor.
		here *= lerpf(1.0, NATACION_MARISMA_BONUS, person.trait_in(Inhabitant.Trait.NATACION))
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

	return walk_speed * (here / maxf(reference, 0.001))


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

	# Las piezas rotas se retiran ahora y no al romperse, para que el parte del
	# dia pueda contarlas antes de que desaparezcan.
	toolkit.discard_spent()
	toolkit.broken_today.clear()

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
		if person.state == Inhabitant.State.DURMIENDO \
				and person.position.distance_to(home_position) < arrive_radius * 2.0:
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

	for person: Inhabitant in people:
		if person.hurt_days > 0:
			person.hurt_days -= 1
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

	var angle := _rng.randf() * TAU
	var radius := sqrt(_rng.randf()) * FORAGE_RADIUS
	var candidate := person.work_centre + Vector3(
		cos(angle) * radius, 0.0, sin(angle) * radius)
	if _terrain:
		candidate.y = _terrain.get_height_at(candidate)
		# No se va a recoger al otro lado de un cortado ni al agua
		if not Traversal.is_passable(_terrain.get_slope_at(candidate),
				_terrain.crossing_difficulty_at(candidate), has_boat, has_bridge):
			return

	person.forage_target = candidate
	person.target = candidate


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
	elif here == null and (is_batida or opens_ground):
		# Monte sin nombre: si de aqui a que se cierre la jornada nace un
		# paraje cerca, es esta salida la que lo ha abierto -batida,
		# expedicion o ascension de paso.
		_new_ground_surveys_today.append(
			{"person": person, "position": person.work_centre, "speciality": speciality})

		# Reconocer ES descubrir: una jornada entera dando vueltas por un
		# sitio nuevo, mirando el terreno, tiene que bastar para saber que
		# hay ahi -no una curva de visitas que tarda semanas en subir, que es
		# lo que daba `observe` y lo que dejaba el mapa vacio de parajes
		# lejanos por mucho que la banda saliera a explorar.
		if knowledge:
			for activity: int in _activities_for_learning(person):
				knowledge.reveal(activity as Subsistence.Activity,
					person.work_centre, BandKnowledge.KNOWN_ENOUGH + 0.02)

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


## Si la despensa ha llegado al tope que puso el jugador.
func food_is_capped() -> bool:
	return food_cap > 0.0 and store.food_rations() >= food_cap


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

	if person.position.distance_to(person.stuck_where) > STUCK_SLACK and not arrived:
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
	if person.position.distance_to(home_position) < arrive_radius * 2.0:
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
func _yields_for(person: Inhabitant) -> Dictionary:
	var speciality := person.current_speciality as Profession.Speciality
	if SPECIALITY_YIELDS.has(speciality):
		return SPECIALITY_YIELDS[speciality]
	return _yield_materials(person.activity)


## Y el utillaje que pide, por el mismo criterio.
func _tool_for(person: Inhabitant) -> int:
	var speciality := person.current_speciality as Profession.Speciality
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
