class_name Taller
extends RefCounted
## Lo que la banda fabrica y lo que se le gasta fabricandolo.
##
## Sale de `SettlementSim` como [Caceria] o [Tajo]. Junta tres cosas que son la
## misma: QUE hace falta -`tool_demand`, `material_needed`-, QUE se esta
## haciendo -`_craft`, `_next_piece`- y QUE se rompe por el camino
## -`tools_broken_per_month`, `_note_breakage`-.
##
## El sim.taller es un SITIO y no una ruta: mientras haya materia prima se trabaja
## dentro del abrigo, y la unica razon por la que un artesano sale es que le
## falte -ver `_workshop_short`-.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Lo que se saca de un rato de trabajo, ya en materiales concretos.
## Cuenta una rotura, y con mas enfasis si era LA ULTIMA.
##
## Quedarse sin la ultima azagaya a mitad de temporada de caza es el momento
## en que el jugador entiende para que servia el sim.taller. Una linea en una
## lista no dice eso; una frase con el nombre de quien la llevaba, si.
func _note_breakage(person: Inhabitant, kind: Tool.Kind) -> void:
	if sim.toolkit.broke_last_use.is_empty():
		return

	# Al libro de gasto, con clave NEGATIVA como en el de produccion: una pieza
	# rota ES gasto, y es el unico que no pasa por `Storehouse.take`. Ver
	# [spent_days].
	var key := -1 - int(kind)
	sim.store.spent_today[key] = float(sim.store.spent_today.get(key, 0.0)) + 1.0

	var left := sim.toolkit.count(kind)
	var doing := Subsistence.activity_name(person.activity).to_lower()
	if left <= 0:
		sim._note(Chronicle.Kind.TALLER,
			"A %s se le partio la ULTIMA %s, %s. No queda ninguna."
				% [person.given_name, sim.toolkit.broke_last_use.to_lower(), doing], 2)
	else:
		sim._note(Chronicle.Kind.TALLER,
			"A %s se le partio %s %s. Quedan %d."
				% [person.given_name, sim.toolkit.broke_last_use.to_lower(), doing, left], 0)


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
	for person: Inhabitant in sim.people:
		if person.has_task and person.activity == activity:
			total += 1
	return maxi(total, 1)


## Cuanta gente esta HOY en esta especialidad de caza en concreto -no toda
## la actividad CAZA, que mezcla trampas, menor y mayor-. Es lo que decide
## si una cuadrilla de caza mayor es de verdad una cuadrilla: ver
## [Hunting.crew_factor].
func hunters_in(speciality: Profession.Speciality) -> int:
	var total := 0
	for person: Inhabitant in sim.people:
		if person.has_task and person.current_speciality == speciality:
			total += 1
	return maxi(total, 1)


## Pedidos permanentes de herramienta que ha puesto el jugador.
##
## Vacio quiere decir «lo que haga falta», que es lo razonable por defecto.
var tool_orders: Dictionary = {}


## Fija -o quita, con 0- un pedido permanente de una pieza.
##
## Igual que el tope de material del almacen: sin pedido, el sim.taller decide
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
	if tech < 0 or sim.techs == null:
		return true
	return sim.techs.has(tech as TechTree.Tech)


# --- curtir la piel: cruda no sirve para nada ------------------------------
#
# `Materia.Kind.PIEL` es la piel recien descarnada, y se pudre -ver su ficha
# en Materia.gd-. Lo unico que la vuelve utilizable es curarla: raspar con
# raedera, frotar con ocre y grasa, y darle su tiempo. Sin este paso, ODRE y
# VESTIDO -que piden PIEL_CURTIDA, no PIEL- nunca tendrian con que hacerse.

## Pieles curadas por JORNADA COMPLETA de trabajo, a rendimiento pleno.
const CURTIDO_PER_DAY := 1.2

## Ocre y grasa que gasta CADA piel que se cura. Sin ellos no cura -se queda
## esperando a que alguien los traiga-, igual que cualquier receta del sim.taller.
const CURTIDO_OCRE_POR_PIEL := 0.3
const CURTIDO_GRASA_POR_PIEL := 0.5

## Hasta cuantas pieles curtidas de sobra quiere tener el sim.taller antes de
## volver a tallar odres o vestidos. Sin este tope, un peletero con piel cruda
## de sobra curtiria sin parar y nunca coseria nada.
const CURTIDO_RESERVA := 4.0


## Curte piel cruda si toca. Devuelve si se ha gastado la jornada en ello -y
## por tanto `_craft` no talla nada mas este tick-.
func _curar_piel(person: Inhabitant, hours: float) -> bool:
	if person.current_speciality != Profession.Speciality.PELETERIA:
		return false
	if sim.store.amount(Materia.Kind.PIEL_CURTIDA) >= CURTIDO_RESERVA:
		return false
	if sim.toolkit.count(Tool.Kind.RAEDERA) <= 0:
		return false

	var cruda := sim.store.amount(Materia.Kind.PIEL)
	if cruda <= 0.0:
		return false

	var capacity := CURTIDO_PER_DAY * (hours / SettlementSim.HORAS_UTILES) \
		* person.effectiveness()
	if capacity <= 0.0:
		return false

	# Y sin pasarse de la reserva: un peletero no deja media piel a medio
	# curtir, pero tampoco cura de mas solo porque el dia daba para ello.
	var hueco := CURTIDO_RESERVA - sim.store.amount(Materia.Kind.PIEL_CURTIDA)
	var curadas := minf(minf(capacity, cruda), maxf(hueco, 0.0))
	var ocre := curadas * CURTIDO_OCRE_POR_PIEL
	if sim.store.amount(Materia.Kind.OCRE) < ocre:
		curadas = sim.store.amount(Materia.Kind.OCRE) / CURTIDO_OCRE_POR_PIEL
	var grasa := curadas * CURTIDO_GRASA_POR_PIEL
	if sim.store.amount(Materia.Kind.GRASA) < grasa:
		curadas = minf(curadas, sim.store.amount(Materia.Kind.GRASA) / CURTIDO_GRASA_POR_PIEL)
	if curadas <= 0.0:
		# Hay piel y raedera pero falta ocre o grasa: se cuenta como jornada
		# de peleteria gastada igual -es lo que estaba haciendo la persona-,
		# no se cae a tallar un odre a medio curtir.
		return true

	sim.store.take(Materia.Kind.PIEL, curadas)
	sim.store.take(Materia.Kind.OCRE, curadas * CURTIDO_OCRE_POR_PIEL)
	sim.store.take(Materia.Kind.GRASA, curadas * CURTIDO_GRASA_POR_PIEL)
	sim.store.add(Materia.Kind.PIEL_CURTIDA, curadas)
	note_production(Materia.Kind.PIEL_CURTIDA, curadas)
	return true


## Cuantas piezas de cada tipo le hacen falta a la banda ahora mismo.
##
## Sale de quien esta trabajando en que, no de una tabla fija: si el jugador
## pone a cinco a pescar, la demanda de arpones sube sola y el sim.taller lo nota
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
		Tool.Kind.LASCA: maxi(sim.people.size() / 2, 2),
		Tool.Kind.AZAGAYA: workers_in(Subsistence.Activity.CAZA),
		Tool.Kind.CESTO: workers_in(Subsistence.Activity.RECOLECCION),
		Tool.Kind.RAEDERA: 2,
		Tool.Kind.BURIL: 2,
		Tool.Kind.AGUJA: 2,
		Tool.Kind.PUNZON: 1,
		Tool.Kind.CUERDA: 3,
		Tool.Kind.ODRE: 2,
		# Una prenda por persona: es la cobertura que de verdad abriga a toda
		# la banda, no un numero de taller como el resto.
		Tool.Kind.VESTIDO: sim.people.size(),
		Tool.Kind.PUNTA: 2,
		# El aparejo de pesca NO va con una cifra fija: va con la forma de
		# pescar que la banda sepa. Pedir arpones desde el primer dia era
		# pedirle al sim.taller que gastara asta en algo que nadie sabe usar
		# todavia, y pedir de todo a la vez seria peor: una red se lleva la
		# fibra de una estacion entera.
		Tool.Kind.ARPON: 0,
		Tool.Kind.NASA: 0,
		Tool.Kind.ANZUELO: 0,
		Tool.Kind.RED: 0,
		# Y la lampara, cero MIENTRAS no se sepa pintar. Nadie ahueca un canto
		# para tener luz dentro de la cueva antes de tener algo que hacer
		# dentro de la cueva; en cuanto se sabe pintar, una, que es lo que hace
		# falta y lo que aparece en los yacimientos.
		Tool.Kind.LAMPARA: 0,
	}
	if sim.techs != null and sim.techs.has(TechTree.Tech.ARTE):
		demand[Tool.Kind.LAMPARA] = 1
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
		if tech >= 0 and (sim.techs == null or not sim.techs.has(tech as TechTree.Tech)):
			continue
		var tool := Fishing.tool_of(method)
		if tool < 0:
			# La pesquera no es una pieza: es una obra. A partir de aqui hacia
			# abajo no hay nada que encargarle al sim.taller.
			break
		if top < 0:
			top = tool
		# Se encarga lo mejor que se pueda HACER, no solo lo mejor que se
		# sepa. Sin esto, el dia que la banda aprende el arpon dejaba de
		# trenzar redes -solo se pedia el escalon de arriba- y si no habia
		# asta en el abrigo se quedaba sin lo uno y sin lo otro, pescando a
		# mano con dos tecnicas de pesca dominadas.
		if sim.toolkit.count(tool as Tool.Kind) > 0 or _can_pay_for(tool as Tool.Kind):
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
	var per_day := Tool.wear_per_day(kind) * SettlementSim.TYPICAL_YIELD_FRACTION
	return in_use * per_day * float(SettlementSim.CONSUMO_DIAS) / maxf(life, 1.0)


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

## Y EL MISMO LIBRO PARA LO QUE SALE. Ventana rodante de [SettlementSim.CONSUMO_DIAS]
## jornadas, igual que la de producción, para que las dos columnas del almacén
## midan lo mismo y se puedan leer juntas.
##
## Sustituye a un PRONÓSTICO. `material_needed` decía «lo que la banda gastaría
## en un mes» —treinta días de comida proyectados—, así que el día dos ponía 762
## raciones de gasto sin que se hubiera comido casi nada. Eso no es un dato del
## almacén, es una previsión, y en una columna que se lee al lado de «HAY»
## engaña.
var spent_days: Array[Dictionary] = []


## Lo que de verdad ha salido del almacén en el periodo. SIN proyectar.
func spent_in_period(kind: Materia.Kind) -> float:
	var total := 0.0
	for a_day: Dictionary in spent_days:
		total += float(a_day.get(int(kind), 0.0))
	return total + float(sim.store.spent_today.get(int(kind), 0.0))


## Y lo mismo para una pieza de utillaje: lo que se ha roto de verdad.
func tool_spent_in_period(kind: Tool.Kind) -> float:
	var total := 0.0
	var key := -1 - int(kind)
	for a_day: Dictionary in spent_days:
		total += float(a_day.get(key, 0.0))
	return total


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
	return sim.tajo._produced_in_period(int(kind))


## Y lo mismo para el sim.taller. Las piezas van con clave NEGATIVA para no
## chocar con los materiales, igual que en el libro de trabajo de cada cual.
func note_tool_made(kind: Tool.Kind) -> void:
	var key := -1 - int(kind)
	produced_today[key] = float(produced_today.get(key, 0.0)) + 1.0


func tool_production_of(kind: Tool.Kind) -> float:
	return sim.tajo._produced_in_period(-1 - int(kind))


## Lo que se ha GASTADO de este material en el periodo.
##
## Antes era un PRONOSTICO -«lo que la banda gastaria en un mes»- y por eso el
## dia dos declaraba setecientas sesenta y dos raciones de comida sin que se
## hubiera comido casi nada: proyectaba treinta dias de bocas. En una columna
## que se lee al lado de «HAY», eso engaña.
##
## Ahora es la suma del libro, sin proyectar, igual que PRODUCE. Ver
## [spent_in_period], que es donde vive.
func material_needed(kind: Materia.Kind) -> float:
	return spent_in_period(kind)


## El pronostico de gasto, que sigue haciendo falta para OTRA cosa.
##
## No para enseñarlo en el almacen -eso es `material_needed`- sino para que el
## taller sepa cuanto conviene tener guardado de cada cosa. Ahi si se quiere
## una prevision: lo que hay que reponer se decide mirando adelante, no atras.
func material_forecast(kind: Materia.Kind) -> float:
	var total := 0.0

	# Lo que se COME, si alimenta y SI LO HAY. Es el gasto mas grande con
	# diferencia.
	#
	# Lo de «si lo hay» es el arreglo de un fallo que hinchaba la columna GASTA
	# del almacen: el consumo se repartia entre los alimentos que la banda tiene
	# en despensa -bien, nadie come avellana treinta dias seguidos- pero se le
	# cobraba entero A CADA MATERIAL, tambien a los que estaban a cero. Con
	# cuatro alimentos guardados de catorce, los catorce declaraban la cuarta
	# parte del consumo y la columna sumaba 2.667 raciones al mes cuando la
	# banda come 762. Medido con `scripts/tests/RacionProbe.gd`.
	if Materia.is_food(kind) and sim.store.amount(kind) > SettlementSim.ALGO_EN_DESPENSA:
		var mouths := 0.0
		for person: Inhabitant in sim.people:
			mouths += person.daily_food()
		var larder := 0
		for other: int in Materia.Kind.values():
			if Materia.is_food(other as Materia.Kind) 					and sim.store.amount(other as Materia.Kind) > SettlementSim.ALGO_EN_DESPENSA:
				larder += 1
		var share := 1.0 / maxf(float(larder), 1.0)
		total += mouths * float(SettlementSim.CONSUMO_DIAS) * share 			/ maxf(Materia.nutrition(kind), 0.001)

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
	if sim.camp_queue >= 0 and not sim._camp_paid:
		var project: Dictionary = CampProjects.materials(sim.camp_queue as CampProjects.Kind)
		total += float(project.get(kind, 0.0))

	return total


## Cuanto tiene la banda de un tipo respecto a lo que le hace falta, de 0 a 1.
## No se recorta a 1: el sim.taller necesita distinguir «justo» de «de sobra»
## para saber cuando parar. Quien si recorta es `Toolkit.efficiency`, porque
## ahi acumular de mas no debe dar rendimiento de mas.
func tool_coverage(kind: Tool.Kind) -> float:
	var needed: float = float(tool_demand().get(kind, 1))
	if needed <= 0.0:
		return 1.0
	return float(sim.toolkit.count(kind)) / needed


## Que pieza toca hacer dentro de una especialidad: la que mas falte.
func _next_piece(speciality: Profession.Speciality) -> int:
	var options: Array = SettlementSim.SPECIALITY_MAKES.get(speciality, [])
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
		# reserva, asi que sin esta linea el sim.taller se ponia a trenzar redes
		# que la banda ni sabe calar todavia.
		if float(tool_demand().get(kind_value, 0)) <= 0.0:
			continue
		# Y lo que todavia no se sabe hacer, no se hace. Ver `Tool.tech_of`.
		if not knows_tool(kind_value):
			continue
		var coverage := tool_coverage(kind_value)
		if coverage >= SettlementSim.RESERVA_UTILLAJE:
			continue
		# Sin la herramienta previa no es que se tarde mas: es que no se hace
		var prerequisite := Tool.needs_tool(kind_value)
		if prerequisite >= 0 and sim.toolkit.count(prerequisite as Tool.Kind) <= 0:
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
				and sim.store.amount(Materia.Kind.SILEX) >= wanted:
			continue
		if sim.store.amount(material as Materia.Kind) < wanted:
			return false
	return true


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
	if sim.hour < SettlementSim.HORA_SALIDA or sim.hour >= SettlementSim.HORA_REGRESO:
		return {}
	var kind := _next_piece(person.current_speciality as Profession.Speciality)
	if kind < 0:
		return {}
	return {"tool": kind, "progress": clampf(person.craft_progress, 0.0, 1.0)}


func _craft(person: Inhabitant, hours: float) -> void:
	var fraction := hours / SettlementSim.HORAS_UTILES
	if fraction <= 0.0:
		return

	# Curtir va antes que tallar: una prenda o un odre no se hacen con piel
	# cruda -ver `_curar_piel`-, así que si hay piel esperando y no hay
	# curtida de sobra, la peletería se dedica a eso primero.
	if _curar_piel(person, hours):
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
	if tool_coverage(kind_value) >= SettlementSim.RESERVA_UTILLAJE:
		person.craft_progress = 0.0
		return

	# La herramienta previa. Sin buril no se ranura el asta: no es que se
	# tarde mas, es que no se hace, y esa dependencia entre talleres es media
	# gracia del sistema.
	var prerequisite := Tool.needs_tool(kind_value)
	if prerequisite >= 0 and sim.toolkit.count(prerequisite as Tool.Kind) <= 0:
		return

	# Progreso acumulado hacia la siguiente pieza. Se guarda por persona
	# porque una azagaya no sale de una sentada.
	var rate: float = float(SettlementSim.CRAFT_PER_DAY.get(speciality, 1.0))
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
				and sim.store.amount(Materia.Kind.SILEX) >= wanted:
			continue
		if sim.store.amount(material as Materia.Kind) < wanted:
			return

	for material: int in recipe:
		var wanted: float = float(recipe[material])
		if material == Materia.Kind.PIEDRA \
				and sim.store.amount(Materia.Kind.SILEX) >= wanted:
			sim.store.take(Materia.Kind.SILEX, wanted)
			stuff = Tool.Stuff.SILEX
			continue
		sim.store.take(material as Materia.Kind, wanted)

	if prerequisite >= 0:
		sim.toolkit.use(prerequisite as Tool.Kind,
			Tool.wear_per_day(prerequisite as Tool.Kind) * 0.5)

	var made := sim.toolkit.craft(kind_value, stuff, person.effectiveness())
	note_tool_made(kind_value)
	person.craft_progress -= 1.0
	# Las piezas se apuntan en negativo del catalogo de materiales para no
	# mezclarlas con la materia prima: el libro de trabajo las separa al
	# leerlas. Ver [Inhabitant.work_log].
	person.log_gain(person.current_task(), -1 - int(kind_value), 1.0)

	# La PRIMERA de un tipo, o la primera de silex, se cuenta. Las siguientes
	# no: un diario que anota cada lasca deja de leerse.
	var first_of_kind := sim.toolkit.count(kind_value) == 1
	if stuff == Tool.Stuff.SILEX and not _knows_silex:
		_knows_silex = true
		sim._note(Chronicle.Kind.TALLER,
			"%s saco la primera pieza de silex de la banda: %s. Aguanta casi el "
				% [person.given_name, made.display_name().to_lower()]
			+ "triple que la cuarcita.", 2)
	elif first_of_kind:
		sim._note(Chronicle.Kind.TALLER,
			"%s hizo la primera %s de la banda."
				% [person.given_name, Tool.kind_name(kind_value).to_lower()], 1)


## Si la banda ha llegado a trabajar silex alguna vez. Solo para no repetir el
## aviso: la primera pieza de silex es noticia, la decima no.
var _knows_silex: bool = false


## Si al sim.taller le falta materia prima para lo que toca hacer.
##
## Es la unica razon por la que un artesano sale del abrigo. Mientras haya de
## que, se trabaja dentro: el sim.taller es un sitio, no una ruta.
func _workshop_short(person: Inhabitant) -> bool:
	var speciality := person.current_speciality as Profession.Speciality
	var kind := _next_piece(speciality)
	if kind < 0:
		return false

	for material: int in Tool.recipe(kind as Tool.Kind):
		var wanted: float = float(Tool.recipe(kind as Tool.Kind)[material])
		# El silex vale por la piedra: si hay de uno, no falta el otro
		if material == Materia.Kind.PIEDRA \
				and sim.store.amount(Materia.Kind.SILEX) >= wanted:
			continue
		if sim.store.amount(material as Materia.Kind) < wanted * WORKSHOP_RESERVE:
			return true
	return false


## Cuantas piezas de reserva de materia prima quiere tener el sim.taller.
##
## Tres. Con una sola, el artesano saldria a por material cada dos dias y se
## pasaria la vida andando; con muchas mas, no saldria nunca y el sim.taller se
## pararia en seco el dia que se acabase.
const WORKSHOP_RESERVE := 3.0


func _yields_for(person: Inhabitant) -> Dictionary:
	var speciality := person.current_speciality as Profession.Speciality
	# La pesca no tiene UNA tabla: tiene una por cada forma de pescar, y cual
	# toca depende de lo que se sepa, de lo que haya en el abrigo y de cuanta
	# gente este en el agua a la vez.
	if speciality == Profession.Speciality.ORILLA:
		return Fishing.yields_of(sim.fishing_method() as Fishing.Method)

	# La caza tampoco tiene UNA tabla: tiene la PIEZA. Lo que se cobra sale de
	# que animales de su porte andan por ese sitio en esta estacion y de como
	# se despieza cada uno, no de una lista escrita a mano. Por eso un cotarro
	# de aves da plumas y no piel, y por eso la tecnica se nota: un cazador
	# con propulsor no encuentra ciervos donde no los hay, cobra mas de los
	# que encuentra.
	if speciality == Profession.Speciality.CAZA_MENOR 			or speciality == Profession.Speciality.CAZA_MAYOR:
		return Hunting.yields_at(speciality, person.work_centre,
			GameState.season as Subsistence.Season, sim.techs, sim.toolkit)
	# El cantero recoge la cuerna de desmogue igual que el recolector: el
	# desmogadero es un sitio de materia prima -uno de los cuatro nombres de
	# `Parajes.MATERIA_PRIMA_POOL`- y esta rama no pasa por la tabla de
	# `Tajo`, asi que se iba a por asta y se volvia con cantos. Va aqui y no
	# en `SPECIALITY_YIELDS` porque la tabla es constante y esto es de
	# temporada; la cifra la pone `Tajo`, que es donde vive la del otro oficio.
	if speciality == Profession.Speciality.CANTERA \
			and GameState.season == Subsistence.Season.INVIERNO:
		var cantera: Dictionary = (SettlementSim.SPECIALITY_YIELDS[speciality]
			as Dictionary).duplicate()
		cantera[Materia.Kind.ASTA] = Tajo.ASTA_DE_DESMOGUE
		return cantera
	if SettlementSim.SPECIALITY_YIELDS.has(speciality):
		return SettlementSim.SPECIALITY_YIELDS[speciality]
	return sim.tajo._yield_materials(person.activity)


## Y el utillaje que pide, por el mismo criterio.
func _tool_for(person: Inhabitant) -> int:
	var speciality := person.current_speciality as Profession.Speciality
	if speciality == Profession.Speciality.ORILLA:
		# El aparejo lo pone la forma de pescar, no la especialidad: a mano y
		# con pesquera no se gasta ninguna pieza.
		return Fishing.tool_of(sim.fishing_method() as Fishing.Method)
	if SettlementSim.SPECIALITY_TOOL.has(speciality):
		return int(SettlementSim.SPECIALITY_TOOL[speciality])
	return activity_tool(person.activity)


func _can_afford(recipe: Dictionary) -> bool:
	for material: int in recipe:
		if sim.store.amount(material as Materia.Kind) < float(recipe[material]):
			return false
	return true
