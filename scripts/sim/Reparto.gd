class_name Reparto
extends RefCounted
## Quien hace que cada manana: el reparto de la mano de obra.
##
## Sale de `SettlementSim` porque es el trozo mas grande que se podia sacar de
## una pieza -ochocientas y pico lineas seguidas- y porque es un tema cerrado:
## aqui se decide QUIEN hace QUE, y ni se produce, ni se anda, ni se come.
##
## Lo que manda es lo que ha marcado el jugador. Cada cual hace lo que tiene
## mas arriba de lo que HOY se puede hacer, y cuando algo no se puede hay que
## poder decir por que -`task_blocked_by`-: un boton que se apaga sin explicarse
## parece un panel roto.
##
## Y el hogar tiene minimo. Si nadie lo atiende se saca a quien menos ganas
## tenga de lo suyo y se anota en la cronica, que es lo que lo diferencia del
## reparto viejo: no se hace a espaldas del jugador.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Reparte a los adultos entre las actividades que haya en el sitio
## Reparto inicial de oficios.
##
## Es PUBLICO y hay que llamarlo cuando ya existen los tajos. Al reordenar el
## montaje para que la comprobacion de alcance tuviera terreno, esto pasó a
## correr antes que los tajos, se encontraba la lista vacia y salia sin
## asignar a nadie: la banda entera se quedaba durmiendo y no avanzaba ni el
## conocimiento ni las tecnicas.
func assign_default_jobs() -> void:
	if sim.work_sites.is_empty():
		return

	# Oficios que tienen tajo montado, mas los que no lo necesitan
	var available: Array[Profession.Job] = []
	for job: int in Profession.CATALOGUE.keys():
		var activity := Profession.job_activity(job as Profession.Job)
		if activity < 0 or sim.work_sites.has(activity):
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
	for person: Inhabitant in sim.people:
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
	if sim.field == null or sim.knowledge == null:
		return 0.0

	var total := 0.0
	for z in range(sim.field.height):
		for x in range(sim.field.width):
			var centre := sim.field.cell_center(x, z)
			if sim.knowledge.familiarity_at(activity, centre) < BandKnowledge.KNOWN_ENOUGH:
				continue
			total += sim.field.abundance_cell(activity, x, z)

	return total / SettlementSim.DEPLETION_PER_DAY


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
	var best: float = sim.tajo._yield_materials(activity).get(kind, 0.0)
	for speciality: int in Profession.Speciality.values():
		if Profession.SPECIALITY_ACTIVITY.get(speciality, -1) != activity:
			continue
		var table: Dictionary = SettlementSim.SPECIALITY_YIELDS.get(speciality, {})
		best = maxf(best, float(table.get(kind, 0.0)))
	if best > 0.0:
		return best

	for other: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
			Subsistence.Activity.MATERIA_PRIMA]:
		best = maxf(best, float(sim.tajo._yield_materials(other as Subsistence.Activity).get(kind, 0.0)))
	for speciality: int in Profession.Speciality.values():
		var table: Dictionary = SettlementSim.SPECIALITY_YIELDS.get(speciality, {})
		best = maxf(best, float(table.get(kind, 0.0)))
	return best


## Unidades de un material que quedan por recoger en los parajes conocidos.
func remaining_units(activity: Subsistence.Activity, kind: Materia.Kind) -> float:
	var per_day := _yield_per_day(activity, kind)
	if per_day <= 0.0:
		return 0.0
	var season := ResourceField.seasonal_factor(activity, GameState.season)
	return per_day * SettlementSim.TYPICAL_YIELD_FRACTION * season * remaining_person_days(activity)


## Unidades de un material que quedan por recoger en ESTE paraje en
## concreto -no en todos los conocidos de la actividad, que es lo que
## pregunta [remaining_units]-. Misma cuenta, un solo sitio: lo que queda
## en la celda entre lo que se lleva una persona en una jornada.
func remaining_units_at(activity: Subsistence.Activity, kind: Materia.Kind,
		cell_x: int, cell_z: int) -> float:
	if sim.field == null:
		return 0.0
	var per_day := _yield_per_day(activity, kind)
	if per_day <= 0.0:
		return 0.0
	var season := ResourceField.seasonal_factor(activity, GameState.season)
	var cell_days := sim.field.abundance_cell(activity, cell_x, cell_z) / SettlementSim.DEPLETION_PER_DAY
	return per_day * SettlementSim.TYPICAL_YIELD_FRACTION * season * cell_days


## Lo mismo, pero para la mancha entera de un paraje. Es la cifra que se
## enseña en su ficha: la cuadrilla trabaja el sitio, no una celda suelta.
func remaining_units_in(paraje: Paraje, activity: Subsistence.Activity,
		kind: Materia.Kind) -> float:
	if sim.field == null or paraje == null:
		return 0.0
	var per_day := _yield_per_day(activity, kind)
	if per_day <= 0.0:
		return 0.0
	var season := ResourceField.seasonal_factor(activity, GameState.season)
	var stock := sim.field.stock_fraction_in(activity, paraje.huella)
	var cell_days := sim.field.abundance_cell(activity, paraje.cell_x, paraje.cell_z) \
		/ SettlementSim.DEPLETION_PER_DAY
	# El fondo de la celda del centro da la escala; la mancha, cuánto queda
	# de verdad en ella. Sin lo segundo la cifra no bajaba con las visitas.
	return per_day * SettlementSim.TYPICAL_YIELD_FRACTION * season * cell_days * stock


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
	var makes: Array = SettlementSim.SPECIALITY_MAKES.get(speciality, [])
	if not makes.is_empty():
		# La cobertura PEOR de lo que hace, no la media: una especialidad con
		# tres cosas cubiertas y una a cero tiene un problema, no un notable
		var worst := INF
		for kind: int in makes:
			worst = minf(worst, sim.taller.tool_coverage(kind as Tool.Kind))
		return worst

	# Las de comida no producen UN material: producen comida, y la comida se
	# mide en raciones y contra los dias de reserva que se quieran tener. Sin
	# esto devolvian 1.0 fijo -"satisfecho"- y no ganaban un empate jamas:
	# poner la pesca de orilla en prioridad 1 al lado de la recoleccion no
	# mandaba a nadie al rio.
	if ESPECIALIDADES_DE_COMIDA.has(speciality):
		var mouths := 0.0
		for person: Inhabitant in sim.people:
			mouths += person.daily_food()
		var larder: float = sim.food_cap if sim.food_cap > 0.0 else mouths * DIAS_DE_RESERVA
		return sim.store.food_rations() / maxf(larder, 0.001)

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
		var target: float = float(sim.limits.get(material, 0.0))
		if target <= 0.0:
			target = float(sim.people.size())
		worst_ratio = minf(worst_ratio,
			sim.store.amount(material as Materia.Kind) / maxf(target, 0.001))
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
	for person: Inhabitant in sim.people:
		counts[person.job] = int(counts.get(person.job, 0)) + 1
	return counts


## Pone a `count` personas en un oficio, quitandolas de otros.
##
## Devuelve cuantas se pudieron colocar de verdad: puede ser menos de las
## pedidas si no hay quien cumpla los requisitos.
## Fija -o quita- la especialidad de toda la gente de un oficio.
func set_speciality(job: Profession.Job, speciality: Profession.Speciality) -> void:
	for person: Inhabitant in sim.people:
		if person.job == job:
			person.speciality = speciality
			person.current_speciality = speciality


## Cuánta gente hay en cada especialidad de un oficio, contando lo que ejercen
## HOY: quien rota cuenta en la que le ha tocado.
func speciality_counts(job: Profession.Job) -> Dictionary:
	var counts := {}
	for person: Inhabitant in sim.people:
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
	for person: Inhabitant in sim.people:
		if person.job == job:
			current.append(person)
		elif Profession.can_do(job, person) and _is_spare(person):
			spare.append(person)

	# Sobran: los que salgan van al hogar, que lo puede hacer casi cualquiera
	# Los que salgan pierden la prioridad de ESTE oficio. Si no tienen otra,
	# `apply_priorities` los dejara sin oficio.
	var floor_count := SettlementSim.MIN_HEARTH if job == Profession.Job.HOGAR else 0
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
			if sim._speciality_can_work(
				Profession.task_speciality(task) as Profession.Speciality):
				wanted = task
				break
		joining.set_priority(wanted, 1)
		current.append(joining)

	apply_priorities()

	var placed := 0
	for person: Inhabitant in sim.people:
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
	if sim.field == null:
		return true

	var act := activity as Subsistence.Activity
	# Si hoy no se ha podido llegar a ningun tajo de esta actividad, no la
	# hay: el reparto tiene que bajar a esa gente a su siguiente oficio en vez
	# de dejarla mirando el rio desde el campamento.
	if sim._unreachable_today.has(int(act)):
		return false
	if sim.work_sites.has(act):
		return true
	if not (sim._known_spots.get(act, []) as Array).is_empty():
		return true
	if sim.parajes:
		for paraje: Paraje in sim.parajes.list:
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

	if sim.despensa.food_is_capped() and sim.despensa._feeds_the_band(job):
		return "la despensa esta al tope; nadie sale a por mas comida"

	var speciality := Profession.task_speciality(task)
	if not _task_has_somewhere(job, task):
		var act := Profession.activity_of(job, speciality)
		if sim._unreachable_today.has(int(act)):
			return "hoy no hay camino a ningun sitio de %s" 				% Subsistence.activity_name(act).to_lower()
		return "no se conoce ningun sitio de %s" 			% Subsistence.activity_name(act).to_lower()

	if not sim._speciality_can_work(speciality):
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
	for person: Inhabitant in sim.people:
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

		var larder_full := sim.despensa.food_is_capped()

		for job_key: int in Profession.CATALOGUE:
			if job_key == Profession.Job.OCIOSO:
				continue
			if not Profession.can_do(job_key as Profession.Job, person):
				continue
			# Con la despensa al tope nadie sale a BUSCAR mas comida. Se
			# bloquea el reparto, no el trabajo empezado: quien viene cargado
			# entrega igual, y quien esta en una pieza abatida la termina de
			# traer. Lo que se para es abrir tajo nuevo.
			if larder_full and sim.despensa._feeds_the_band(job_key as Profession.Job):
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
				if not sim._speciality_can_work(
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
	for person: Inhabitant in sim.people:
		if Profession.can_do(job, person):
			person.set_priority(job, level)
	apply_priorities()


## --- Lo que cuesta tener fuego ------------------------------------------
##
## Todos estos números son de BALANCEO y están sin calibrar: se dejan aquí,
## juntos y con nombre, para poder moverlos en playtest de una tacada. Lo que
## está decidido es que el fuego cueste y que apagarse duela; cuánto, no.


## --- Lo que hace falta para dormir fuera ---------------------------------
##
## Quien pernocta fuera sólo gastaba comida de mochila y recuperaba menos
## fatiga. Una expedición de otoño en Cantabria sin tienda ni hoguera no es
## «descansar peor»: es la clase de noche de la que se vuelve con algo roto.
## También aquí lo decidido es que duela, no cuánto.


## Se asegura de que quede alguien en el hogar, cogiendolo de los ociosos.
func _ensure_hearth() -> void:
	var hearth := 0
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.HOGAR:
			hearth += 1
	if hearth >= SettlementSim.MIN_HEARTH:
		return

	# Primero, de quien no esta haciendo nada
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.OCIOSO:
			continue
		if Profession.assign(Profession.Job.HOGAR, person):
			hearth += 1
			if hearth >= SettlementSim.MIN_HEARTH:
				return

	# Y si no hay nadie libre, se saca a alguien de su oficio: sin fuego no se
	# cocina, no se seca la carne y no avanza ninguna obra, asi que el minimo
	# es un minimo de verdad. Se coge a quien MENOS ganas tenga de lo que esta
	# haciendo, y se anota en la cronica para que no sea a espaldas del
	# jugador -que es lo que hacia el reparto viejo y por lo que se noto-.
	var weakest: Inhabitant = null
	var weakest_level := -1
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.HOGAR:
			continue
		if not Profession.can_do(Profession.Job.HOGAR, person):
			continue
		var level := person.priority_in_job(person.job)
		if level > weakest_level:
			weakest_level = level
			weakest = person

	if weakest != null and Profession.assign(Profession.Job.HOGAR, weakest):
		sim._note(Chronicle.Kind.GENTE,
			"No quedaba nadie para el fuego: %s deja %s y se queda en el abrigo."
				% [weakest.given_name,
					Profession.job_name(weakest.job as Profession.Job).to_lower()], 1)


## Cuanta gente esta sin oficio ahora mismo.
func idle_count() -> int:
	var total := 0
	for person: Inhabitant in sim.people:
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

	for person: Inhabitant in sim.people:
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
	for person: Inhabitant in sim.people:
		if person.job != job and Profession.can_do(job, person) and _is_spare(person):
			total += 1
	return total


## Manda a todos los adultos a una actividad
func assign_all(activity: Subsistence.Activity) -> void:
	if not sim.work_sites.has(activity):
		return
	for person: Inhabitant in sim.people:
		if person.can_work():
			person.activity = activity
			person.has_task = true
			person.state = Inhabitant.State.OCIOSO
