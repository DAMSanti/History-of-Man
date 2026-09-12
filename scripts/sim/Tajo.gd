class_name Tajo
extends RefCounted
## Adonde se va a trabajar y que se trae de alli.
##
## Sale de `SettlementSim` como [Caceria] o [Reparto], y es el tema del que
## depende que la banda coma: elegir sitio -lo que se conoce, lo que queda en
## el, lo que cuesta llegar- y despues cosecharlo.
##
## Lo que se trae NO es una tabla: es una cadena de seis factores -pericia,
## saber del sitio, temporada, tiempo, cuadrilla y filo- que multiplicados dan
## el cuatro por ciento de lo nominal, y por eso existe
## [Tajo.HARVEST_SCALE]. Su hermana de la caza es
## [Caceria.ESCALA_DEL_RASTREO], y las dos tienen que salir del mismo orden.
##
## La caza NO pasa por aqui: acecha una pieza concreta de las que andan por el
## valle. Ver [Caceria].

## Familiaridad a partir de la cual un sitio se puede TRABAJAR: se llega y se
## empieza, sin prospectar antes.
##
## Es un peldaño por encima de [BandKnowledge.KNOWN_ENOUGH] -0,30-, que es lo
## que hace falta para que un sitio merezca nombre. La diferencia es a
## proposito: saber que ahi hay un avellanar basta para ponerle nombre en el
## mapa, pero para ir derecho a recoger hay que saber ademas por donde se entra
## y en que parte de la mancha esta lo bueno.
##
## Estaba escrito como un 0,35 suelto en dos sitios -aqui y en el paso de YENDO
## a TRABAJANDO de [SettlementSim._tick_daylight]- y encima citado a mano en un
## comentario de [Querencia]. Tres copias de la misma regla es como se pierde
## una: si se sube este numero hay que subir tambien con cuanto se siembra al
## fundar, o la banda amanece sin un solo sitio donde trabajar.
const SE_PUEDE_TRABAJAR := 0.35

## La cuerna que se recoge del suelo en una jornada completa, en invierno.
##
## UNA CIFRA EN UN SITIO, porque la recogen tres oficios distintos: el
## recolector que pasa por el prado, el cantero que trabaja el desmogadero y
## quien va a materia prima sin especialidad. Escrita tres veces se separa a
## la primera, y el asta es justo el material del que depende la azagaya.
##
## El ciervo desmoga de febrero a abril y es la unica materia dura animal que
## no exige matar; por eso la cifra es pequeña y estacional, no un recurso mas.
const ASTA_DE_DESMOGUE := 0.8

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Rehace la lista de sim.parajes conocidos. Una pasada por actividad y dia.
func _rank_known_spots() -> void:
	sim._known_spots.clear()
	if sim.knowledge == null or sim.field == null:
		return

	for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var act := activity as Subsistence.Activity
		var spots: Array[Dictionary] = []

		for z in range(sim.field.height):
			for x in range(sim.field.width):
				var centre := sim.field.cell_center(x, z)
				# Solo cuenta lo que se conoce: un cotarro sin pisar no esta en
				# el mapa de la banda por muy bueno que sea
				if sim.knowledge.familiarity_at(act, centre) < SE_PUEDE_TRABAJAR:
					continue

				var value := sim.knowledge.believed_abundance(
					sim.field, act, centre, GameState.season)
				if value <= 0.05:
					continue

				var distance := Vector2(centre.x - sim.home_position.x,
					centre.z - sim.home_position.z).length()
				# Radio de jornada: hay que ir, trabajar y volver antes de que
				# anochezca. Mas lejos que esto no da tiempo a recoger nada.
				#
				# Salvo LA CAZA, que ya no vuelve a diario: sale avituallada y
				# duerme donde caza -ver `_camps_out` y [SettlementSim.CAZA_LEJOS_M]-. Con el
				# tope de jornada, a los cazadores se les ofrecia monte de ida y
				# vuelta y nunca el coto de kilometro y medio para el que se les
				# habia cargado la mochila.
				if distance > (SettlementSim.CAZA_LEJOS_M if act == Subsistence.Activity.CAZA
						else SettlementSim.RADIO_DE_JORNADA):
					continue

				# Y QUE SE PUEDA LLEGAR HOY. No se ofrece como tajo un sitio
				# al que no hay camino: «un trabajador no debe ni siquiera
				# considerar un paraje no alcanzable».
				#
				# Se pregunta aqui y no solo al salir porque la rejilla cambia
				# con la estacion -ver [HornoDeRejillas]-: un avellanar que en
				# agosto se vadeaba deja de estar al alcance cuando el rio
				# crece, y hasta que alguien no se pasa media jornada contra el
				# agua nadie se entera. La rejilla lo sabe sin buscar nada:
				# trae las zonas comunicadas marcadas.
				var rejilla := sim.marcha._navgrid()
				if rejilla != null and rejilla.is_ready() 						and not rejilla.connected(sim.home_position, centre):
					continue

				if sim._terrain:
					centre.y = sim._terrain.get_height_at(centre)

				# El término medio entre no esquilmar y no perderse el día
				# andando, dicho como una cuenta y no como un descuento
				# inventado: lo que se saca de una jornada es lo que se
				# recoge por hora POR las horas que quedan después de ir y
				# volver. Un sitio el doble de rico a hora y media no gana
				# a uno mediano a diez minutos, y uno esquilmado al lado
				# tampoco gana a uno entero un poco más allá.
				var travel := 2.0 * sim.marcha.hours_to_walk(distance)
				var usable := clampf(1.0 - travel / SettlementSim.HORAS_UTILES, 0.1, 1.0)
				var stock := sim.field.stock_fraction_around(act, centre, 90.0)
				# Un paraje con nombre pesa más que monte anónimo del mismo
				# rendimiento.
				#
				# El sim.reparto miraba sólo la rejilla de familiaridad y no los
				# sim.parajes, así que la banda podía estar trabajando a cincuenta
				# metros de un avellanar bautizado sin ir a él: para el sim.reparto
				# no existía, aunque para el jugador fuera el sitio que había
				# encontrado y al que le había puesto nombre. Y un sitio con
				# nombre es un sitio que la banda CONOCE de verdad: sabe qué da,
				# por dónde se entra y cuándo conviene.
				var named := 1.0
				if sim._paraje_at(centre) != null:
					named = SettlementSim.PARAJE_BONUS
				spots.append({
					"pos": centre,
					"score": value * usable * stock * named,
				})

		spots.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
		# Solo interesan los mejores: con veinte hay de sobra para repartir a
		# una banda de quince
		sim._known_spots[activity] = spots.slice(0, mini(spots.size(), 20))


## Arrima un punto a la orilla: tierra firme con agua justo al lado.
##
## Se pesca DESDE la orilla, no desde el prado de al lado ni desde dentro del
## cauce. El sim.reparto de tajos elige una celda de la rejilla de recursos, y esa
## celda mide decenas de metros: caía tan pronto en la ribera como en el pasto
## de detrás, y entonces la cuadrilla se plantaba a cincuenta metros del agua a
## «pescar». Aquí se busca el punto pisable más cercano que tenga agua al lado.
func _shore_near(point: Vector3) -> Vector3:
	if sim._terrain == null:
		return point

	var best := point
	var best_reach := INF
	for radius: float in [0.0, 8.0, 16.0, 26.0, 38.0, 52.0, SettlementSim.SHORE_SEARCH_M]:
		for spoke in range(12):
			var angle := TAU * float(spoke) / 12.0
			var candidate := point
			if radius > 0.01:
				candidate += Vector3(cos(angle), 0.0, sin(angle)) * radius
			# Pisable: la orilla es tierra firme, no el cauce.
			if sim._terrain.crossing_difficulty_at(candidate) > Hydrography.FORD_WADEABLE:
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
	best.y = sim._terrain.get_height_at(best)
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
			if sim._terrain.crossing_difficulty_at(point + Vector3(
					cos(angle) * reach, 0.0, sin(angle) * reach)) > Hydrography.HAY_AGUA:
				return true
	return false


func _best_known_spot(person: Inhabitant) -> Vector3:
	# El trampero va primero a lo que ya tiene puesto y esta cebado. Levantar
	# una trampa cargada rinde mas por hora que cualquier otra cosa de la
	# caza, y ademas es lo que se hace: la linea se recorre.
	# Y el cazador, a por lo que dejo abierto en el monte. Volver a por una
	# espalda de ciervo rinde mas que cualquier otra cosa de la caza, y ademas
	# es lo que hace que dejar una pieza en el terreno sea una decision de
	# verdad en vez de una perdida silenciosa. Ver `_load_up`.
	if person.current_speciality == Profession.Speciality.CAZA_MENOR \
			or person.current_speciality == Profession.Speciality.CAZA_MAYOR:
		var abierta := sim.caceria.kill_to_fetch_near(person.position, 1200.0)
		if abierta != null:
			return abierta.kill_site

	# Y el pescador, a la nasa que ya tenga algo dentro. Mismo motivo que el
	# trampero, y hace la misma falta: medido con `CaceriaProbe`, una nasa
	# calada llevaba ciento veinte jornadas «con algo dentro» y CERO piezas
	# levantadas, porque el pescador volvia cada dia al mejor sitio de pesca y
	# ese no era donde tenia la nasa.
	if person.current_speciality == Profession.Speciality.ORILLA:
		var llena := sim.nasas_line._fullest_nasa()
		if llena != null:
			return llena.position

	if person.current_speciality == Profession.Speciality.TRAMPAS:
		var cebada := sim.trampas._fullest_trap()
		if cebada != null:
			return cebada.position
		# Y si no hay nada que levantar, se ALARGA la linea: a un sitio de
		# caza donde todavia no haya trampa. Sin esto el trampero volvia cada
		# dia a la misma estaca vacia -el mejor sitio conocido es siempre el
		# mismo- y la linea entera se quedaba en dos sim.trampas amontonadas en el
		# mismo claro.
		if sim.trampas.traps.size() < sim.trampas.trap_allowance():
			for spot: Dictionary in (sim._known_spots.get(
					Subsistence.Activity.CAZA, []) as Array):
				var point: Vector3 = spot["pos"]
				if sim.trampas._room_for_trap(point) and not sim._is_resting(
						Subsistence.Activity.CAZA, point):
					return point
			# Y si todo lo conocido ya tiene trampa, se sale a monte nuevo. Una
			# linea de sim.trampas se ALARGA: quedarse dando vueltas a las mismas
			# dos estacas es lo contrario de tener una linea.
			var fresh := _search_target(person)
			if fresh != Vector3.ZERO:
				return fresh

	# Si el jugador ha señalado un paraje para este oficio, se va ahi y no se
	# discute. Es todo el sentido de poder pinchar un sitio: la banda deja de
	# elegir por su cuenta cuando tu eliges por ella.
	var picked := sim.parajes.chosen_for(person.activity)
	if picked != null:
		return picked.position

	var spots: Array = sim._known_spots.get(person.activity, [])
	if spots.is_empty():
		return sim.work_sites.get(person.activity, Vector3.ZERO)

	var best := Vector3.ZERO
	var best_score := 0.0

	for spot: Dictionary in spots:
		var centre: Vector3 = spot["pos"]

		# En barbecho no se entra: es la unica forma que tiene el jugador de
		# gestionar el agotamiento sin mover gente de oficio
		if sim._is_resting(person.activity, centre):
			continue

		# Ni adonde ya se ha intentado llegar hoy sin conseguirlo. Ver
		# `_give_up_on`: sin esto se vuelve a elegir el mismo cotarro detrás del
		# mismo cortado en cuanto se queda uno libre, y la jornada se va en ir y
		# volver del mismo sitio imposible.
		if sim.marcha._given_up_on(person, centre):
			continue

		# Descuento por lo que ya hay trabajando ahi. El radio es amplio y la
		# penalizacion fuerte a proposito: con un descuento flojo todos
		# elegian el mismo paraje y salian en fila india uno detras de otro,
		# que es justo lo contrario de como se reparte una cuadrilla.
		var crowd := 0.0
		for other: Inhabitant in sim.people:
			if other == person or other.activity != person.activity:
				continue
			if other.state == Inhabitant.State.DURMIENDO \
					or other.state == Inhabitant.State.OCIOSO:
				continue
			# EN LLANO y contra una constante con nombre. El 260 estaba escrito
			# a mano aqui, que es el mismo numero que
			# [SettlementSim.SURVEY_RADIUS] y por el mismo motivo -es el trozo
			# de monte que ocupa una cuadrilla trabajando-.
			if Traversal.en_llano(other.target, centre) < SettlementSim.SURVEY_RADIUS:
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
		score *= sim._quarry_bonus(person, centre)

		if score > best_score:
			best_score = score
			best = centre

	if best == Vector3.ZERO:
		return best

	# Y dentro del paraje, cada uno a su trozo. Un avellanar no es un punto:
	# son decenas de metros, y dos personas recogiendo la misma mata es una
	# tonteria. El sim.reparto es por identidad, asi que es estable entre jornadas
	# y cada cual vuelve a su rincon.
	var spread := 55.0
	var angle := TAU * (float(person.id) * 0.618)
	best += Vector3(cos(angle), 0.0, sin(angle)) * spread \
		* (0.4 + fmod(float(person.id) * 0.37, 0.6))
	if sim._terrain:
		best.x = clampf(best.x, 10.0, float(sim._terrain.terrain_size.x) - 10.0)
		best.z = clampf(best.z, 10.0, float(sim._terrain.terrain_size.y) - 10.0)
		best.y = sim._terrain.get_height_at(best)
	return best


## El paraje de SU oficio mas cercano al que todavia le quedan «???».
##
## Es el escalon que faltaba entre «tengo donde trabajar» y «me voy a dar una
## vuelta a ver que encuentro»:
##
##   1. Si hay una fuente conocida y utilizable, se trabaja. Eso ya lo hace
##      `_best_known_spot`.
##   2. Si no —o si las que hay estan esquilmadas—, SE VA AL PARAJE DE LO SUYO
##      MAS CERCANO QUE TENGA ALGO POR DESCUBRIR, y se prospecta ahi. Esto.
##   3. Y solo si no queda ninguno, se sale a tantear monte. Ver `_search_target`.
##
## Peticion literal: «lo primero que haran los recolectores es ir a un paraje de
## su especializacion y tratar de encontrar materiales que ellos puedan
## recolectar... quiero que SOLO hagan esto si no hay otro paraje con ese
## material descubierto o si los que hay descubiertos estan llenos. Lo que no
## quiero nunca es que se vayan mas lejos de lo necesario, no tiene sentido
## alejarse 2000 m si hay parajes sin descubrir a 500 m».
##
## Por cercania y nada mas, igual que la batida —ver
## [SettlementSim._paraje_to_survey]—: lo que se pide es un frente que se abre
## despacio desde el abrigo, no un salto al mejor sitio del valle.
func _paraje_por_prospectar(person: Inhabitant) -> Vector3:
	if sim.parajes == null:
		return Vector3.ZERO

	var best: Paraje = null
	var best_lejos := INF
	for paraje: Paraje in sim.parajes.list:
		if paraje.activity != person.activity or not paraje.has_unknowns():
			continue
		if paraje.resting or sim._is_resting(person.activity, paraje.position):
			continue
		# Adonde ya se intento llegar hoy sin conseguirlo, no se vuelve.
		if sim.marcha._given_up_on(person, paraje.position):
			continue
		var lejos := Traversal.en_llano(sim.home_position, paraje.position)
		if lejos >= best_lejos:
			continue
		# Lo caro va al final, y solo para el que ya es el mas cercano.
		#
		# Y DESDE CASA, que es donde se toma la decision.
		#
		# Es exactamente la misma pregunta que se hace
		# [SettlementSim._paraje_to_survey] un paso antes -«¿merece la pena
		# ir a este paraje?»- y la hacia desde OTRO SITIO: aquella desde el
		# abrigo y esta desde la persona. Dos origenes, dos respuestas, y
		# encima la de aqui no se podia guardar -la persona se mueve, la
		# memoria va por celda- asi que era una busqueda entera POR PARAJE
		# CANDIDATO, sin pasar por ningun presupuesto. De ahi salian los
		# treinta y dos A* en un cuadro del reparto de la manana.
		#
		# Preguntando desde casa se contesta con lo que ya esta calculado
		# -ver [Marcha.alcanzable_desde_casa], con memoria por celda- y las
		# dos capas dicen lo mismo. Que es lo que hay que exigirles.
		if not sim.marcha.alcanzable_desde_casa(paraje.position):
			continue
		best_lejos = lejos
		best = paraje
	return Vector3.ZERO if best == null else best.position


## Adonde salir a buscar cuando no se conoce ningun paraje.
##
## Se abren en abanico, cada uno por una direccion que no lleve otro. Es lo
## mismo que hacen los exploradores, pero a radio de jornada y buscando un
## recurso concreto en vez de mapa.
## El abanico ya filtrado de cada persona. Ver [_abanico_de].
var _abanicos: Dictionary = {}
var _abanicos_con := Vector2i(-1, -1)
var _abanicos_desde := Vector3(INF, INF, INF)


func _search_target(person: Inhabitant) -> Vector3:
	if sim._terrain == null:
		return sim.home_position

	var taken: Array[Vector3] = []
	for other: Inhabitant in sim.people:
		if other != person and other.state == Inhabitant.State.YENDO:
			taken.append(other.target)

	var best := sim.home_position
	var best_score := -1.0

	for par: Array in _abanico_de(person):
		var candidate: Vector3 = par[0]
		var distance: float = par[1]

		# Lo que promete el terreno, aunque la banda no lo sepa todavia:
		# el recolector no adivina, pero el monte tiene lo que tiene
		var promise := 0.0
		if sim.field:
			promise = sim.field.seasonal_abundance_at(
				person.activity, candidate, GameState.season)

		# Se premia lo que esta sin batir y se penaliza la distancia
		var unknown := 1.0
		if sim.knowledge:
			unknown = 1.0 - sim.knowledge.familiarity_at(person.activity, candidate)

		var score := (promise * 0.6 + unknown * 0.4) / (1.0 + distance / 700.0)
		for other_target: Vector3 in taken:
			if candidate.distance_to(other_target) < 260.0:
				score *= 0.35

		if score > best_score:
			best_score = score
			best = candidate

	return best


## El abanico de una persona: los puntos que se le prueban y a que distancia,
## en el orden en que se probaban.
##
## ES CACHE Y NO PARTIDA, y por eso se puede guardar: el abanico sale del `id`
## de la persona y del abrigo -doce direcciones por tres distancias, con un
## desfase por persona para que no prueben todos lo mismo-, y lo que el terreno
## dice de cada punto -altura, pendiente, vado- no cambia en toda la partida.
## Lo que SI cambia -lo que promete el campo y lo que la banda conoce- se sigue
## preguntando en cada llamada.
##
## Lo que evita: treinta y seis puntos por llamada con tres preguntas al
## relieve cada uno, y esto se llama cada vez que alguien decide su jornada.
## Medido en tres jornadas de verano: 5,0 s de los 34,2 del paso de
## simulacion. Ver la tarea 21 de docs/specs/LO_MISMO_MAS_DEPRISA.md.
func _abanico_de(person: Inhabitant) -> Array:
	# Barca, puente o abrigo nuevos cambian lo que se puede pisar: se rehace.
	var con := Vector2i(1 if sim.has_boat else 0, 1 if sim.has_bridge else 0)
	if con != _abanicos_con or sim.home_position != _abanicos_desde:
		_abanicos.clear()
		_abanicos_con = con
		_abanicos_desde = sim.home_position
	if _abanicos.has(person.id):
		return _abanicos[person.id]

	var puntos: Array = []
	for spoke in range(12):
		# El desfase por persona evita que todos prueben las mismas direcciones
		var angle := TAU * (float(spoke) / 12.0 + float(person.id) * 0.083)
		for distance: float in [200.0, 430.0, 700.0]:
			var candidate := sim.home_position \
				+ Vector3(cos(angle), 0.0, sin(angle)) * distance
			if candidate.x < 20.0 or candidate.z < 20.0 \
					or candidate.x > float(sim._terrain.terrain_size.x) - 20.0 \
					or candidate.z > float(sim._terrain.terrain_size.y) - 20.0:
				continue
			candidate.y = sim._terrain.get_height_at(candidate)

			if not Traversal.is_passable(sim._terrain.get_slope_at(candidate),
					sim._terrain.crossing_difficulty_at(candidate), sim.has_boat, sim.has_bridge):
				continue
			puntos.append([candidate, distance])
	_abanicos[person.id] = puntos
	return puntos


## La suma del periodo para una clave, materiales y piezas por igual.
func _produced_in_period(key: int) -> float:
	var total := 0.0
	for a_day: Dictionary in sim.taller.produced_days:
		total += float(a_day.get(key, 0.0))
	# El día en curso cuenta: sin él, la cifra no se mueve hasta mañana y el
	# jugador que acaba de mandar a media banda a por leña no ve nada.
	total += float(sim.taller.produced_today.get(key, 0.0))
	# SIN PROYECTAR. Esto multiplicaba por `CONSUMO_DIAS / dias jugados` cuando
	# aun no habia mes entero, con la idea de que las dos columnas del almacen
	# fueran comparables desde el primer dia. El resultado era mentir: el dia
	# cinco, veinte de cuarcita recogida salian como «112 al mes» al lado de un
	# «HAY 20», y no hay forma de leer eso.
	#
	# Lo que se enseña ahora es lo que ha pasado: la suma de lo que entro en los
	# ultimos treinta dias, sean treinta o sean dos. Al principio las dos
	# columnas son pequeñas, y eso es correcto y es honrado.
	return total


## Cierra el día de producción y lo mete en el registro.
func _roll_production() -> void:
	sim.taller.produced_days.append(sim.taller.produced_today.duplicate())
	while sim.taller.produced_days.size() > SettlementSim.CONSUMO_DIAS:
		sim.taller.produced_days.remove_at(0)
	sim.taller.produced_today = {}

	# Y el libro de lo que SALE, en la misma vuelta y con la misma ventana:
	# las dos columnas del almacen tienen que medir lo mismo o no se pueden
	# leer juntas. Ver [Taller.spent_days].
	sim.taller.spent_days.append(sim.store.spent_today.duplicate())
	while sim.taller.spent_days.size() > SettlementSim.CONSUMO_DIAS:
		sim.taller.spent_days.remove_at(0)
	sim.store.spent_today = {}

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
	var here := sim._paraje_at(point)
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

## La pericia contra la que esta calibrada esa cifra.
##
## Es la suposicion que estaba ESCONDIDA dentro de [HARVEST_SCALE]. Sacarla no
## cambia nada de lo que hace el juego -la cuenta es la misma- pero cambia lo
## que SIGNIFICA el numero, que es lo que hace falta para poder ajustarlo.
##
## Medido con `scripts/tests/RendimientoProbe.gd`, que descompone lo que trae
## cada salida en sus seis factores. Al octavo dia de partida:
##
##     pericia 0,19-0,27 · sitio 0,73-0,80 · estacion 0,70-0,82
##     queda 0,96 · filo 0,70-0,78 · tiempo 0,98
##
## De los seis, CINCO estan entre 0,7 y 1 y uno esta en 0,2: la escala no
## compensa «cinco penalizaciones», compensa sobre todo la pericia.
##
## Y la pericia es el unico de los seis que CAMBIA con la partida:
## `Inhabitant.effectiveness` la lleva de 0,2 a 1,4 segun se aprende el oficio.
## Una banda que domina su valle cosecha unas CUATRO VECES lo que cosecha el
## primer mes con el mismo numero aqui. Eso no es un fallo -aprender tiene que
## notarse- pero significa que ningun valor fijo esta bien en los dos extremos,
## y que la variacion entre partidas -de 3 a 11 dias de despensa con la misma
## configuracion- sale en buena parte de quien aprende antes.
##
## 0,26 es la eficacia media medida de los oficios de monte a los ocho dias.
const PERICIA_DE_REFERENCIA := 0.26

## Lo que trae una jornada de una banda a la pericia de referencia.
##
## Es [HARVEST_SCALE] con la pericia dentro, para que el numero se pueda leer:
## «esto es lo que cosecha una banda competente» y no «esto es un factor de
## correccion de veintiseis».
const RENDIMIENTO_DE_REFERENCIA := HARVEST_SCALE * PERICIA_DE_REFERENCIA

## Hasta donde llega el brazo desde donde se planta uno a trabajar, en metros.
##
## Poco mas de una celda del campo de recursos: lo justo para que quien pesca
## desde la orilla alcance el agua y quien recoge alcance la mata de al lado,
## sin que un cotarro rinda desde el otro lado del valle.
const ALCANCE_DEL_TAJO := 80.0


func _harvest(person: Inhabitant, hours: float) -> void:
	# Fraccion de la jornada trabajada en este tick
	var fraction := hours / SettlementSim.HORAS_UTILES
	if fraction <= 0.0:
		return

	# Destreza, estado y conocimiento del paraje
	var skill := person.effectiveness() * sim._knowledge_factor(person)

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
	if sim.field:
		worked_cell = sim.field.best_cell(person.activity, person.position,
			ALCANCE_DEL_TAJO)
		left = sim.field.stock_of_cell(person.activity, worked_cell)

	# El filo disponible. Un cazador sin azagaya sigue trayendo algo -trampa,
	# carrona y caza menor-, pero poco; quien recolecta sin cesto trae lo que
	# le cabe en los brazos. Y usar la herramienta la gasta, que es de donde
	# sale la demanda del taller sin tener que inventarse ninguna cuota.
	var tool_factor := 1.0
	var tool_kind := sim.taller._tool_for(person)
	if tool_kind >= 0:
		var kind_value := tool_kind as Tool.Kind
		tool_factor = sim.toolkit.efficiency(kind_value, sim.taller.workers_in(person.activity))
		sim.toolkit.use(kind_value, fraction * Tool.wear_per_day(kind_value))
		sim.taller._note_breakage(person, kind_value)

	# El despiece se lleva por delante mas filo que ninguna otra cosa: una res
	# grande se come varias lascas. Va aparte de la azagaya porque son dos
	# trabajos distintos, y es lo que da sentido al tallador.
	if person.activity == Subsistence.Activity.CAZA:
		sim.toolkit.use(Tool.Kind.LASCA,
			fraction * Tool.wear_per_day(Tool.Kind.LASCA))
		sim.taller._note_breakage(person, Tool.Kind.LASCA)

	# La cuadrilla. Sólo pinta en caza mayor -ver [Hunting.crew_factor]-, y
	# ahi es donde manda de verdad: un solo batidor contra un uro trae casi
	# nada, cuatro traen la pieza entera.
	var crew := 1.0
	if person.activity == Subsistence.Activity.CAZA:
		var speciality := person.current_speciality as Profession.Speciality
		crew = Hunting.crew_factor(speciality, sim.taller.hunters_in(speciality))
		sim.percances._check_hunting_risk(person, speciality, fraction)

	# La pericia entra RELATIVA a la de referencia, no en crudo: asi el numero
	# de calibracion dice lo que cosecha una banda competente, y se ve solo que
	# el novato saca menos y el veterano mas. La cuenta es identica.
	var multiplier := fraction * (skill / PERICIA_DE_REFERENCIA) * season * left \
		* tool_factor * crew * sim.weather.work_factor() * RENDIMIENTO_DE_REFERENCIA
	if multiplier <= 0.0:
		return

	_fill_the_basket(person, hours, fraction, multiplier, worked_cell)


## Lo que de verdad entra en el zurron, y lo que se le resta al sitio.
##
## `_harvest` calculaba CUANTO se cosecha -los seis factores, ver
## [PERICIA_DE_REFERENCIA]- y ademas repartia el resultado material a material
## con sus cinco filtros: lo que solo sale de su veta, lo que no es de
## temporada, el tope que puso el jugador, lo que no caza un recolector y lo
## que ya no cabe en el cesto. Son dos cosas, y la segunda es la larga.
func _fill_the_basket(person: Inhabitant, hours: float, fraction: float,
		multiplier: float, worked_cell: int) -> void:
	var yields := sim.taller._yields_for(person)

	# Lo que pasa por delante y no se puede cobrar. Se dice, porque la puerta
	# de [Fauna.huntable_with] cerrada en silencio es la peor version de si
	# misma: una cuadrilla que vuelve de vacio de un cotarro lleno de ciervos
	# se ve, desde fuera, exactamente igual que una que fue a un sitio pelado.
	sim._watch_the_quarry_pass(person)

	# El cebo del sedal se gasta. Es lo que hace que el anzuelo no sea una
	# mejora gratis: hay que traer caracol, y el dia que no queda `Fishing`
	# baja el aparejo un escalon por su cuenta.
	if person.current_speciality == Profession.Speciality.ORILLA:
		var method := sim.fishing_method() as Fishing.Method
		var bait := Fishing.bait_at_hand(method, sim.store)
		if bait >= 0:
			sim.store.take(bait as Materia.Kind,
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
		if sim.limits.has(kind):
			var cap: float = sim.limits[kind]
			var have: float = sim.store.amount(kind as Materia.Kind) \
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
	# recoger y vaciar sean la misma cosa y no dos. Ver [SettlementSim.DEPLETION_PER_UNIT].
	if sim.field and taken > 0.0:
		sim.field.take_from_cell(person.activity, worked_cell,
			taken * SettlementSim.DEPLETION_PER_UNIT)


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
			var duro := {Materia.Kind.PIEDRA: 13.0, Materia.Kind.OCRE: 0.8}
			# El desmogadero es un sitio de materia prima -uno de los cuatro
			# nombres de `Parajes.MATERIA_PRIMA_POOL`- y esta tabla no daba
			# asta: se iba a por cuerna y se volvia con cantos. La misma cifra
			# que la recoleccion de invierno, que es la otra forma de
			# recogerla, porque es la misma cuerna del mismo suelo.
			if GameState.season == Subsistence.Season.INVIERNO:
				duro[Materia.Kind.ASTA] = ASTA_DE_DESMOGUE
			return duro
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
##
## ## Lo que se corrigio al repasar el calendario
##
## Tres cosas estaban mal de CALENDARIO, no de balanceo, y las tres inflaban la
## recoleccion:
##
##   - **La avellana salia las cuatro estaciones** (6 en primavera, 9 en verano,
##     4 en invierno). La avellana es de SEPTIEMBRE. Recogerla en marzo no es
##     una simplificacion, es recoger lo que no hay: el arbol no la tiene.
##   - **La baya salia en primavera.** La mora es de agosto, la endrina de
##     octubre, el madrono de noviembre. En primavera el zarzal esta en flor.
##   - **La cesta de todos los dias era demasiado.** Lena, fibra, yesca, raiz,
##     corteza y hueso salian TODOS los dias en TODOS los sitios. Un recolector
##     volvia con seis materiales distintos cada jornada del año, hiciera lo que
##     hiciera y fuera donde fuera. Se queda lo que de verdad se recoge de paso,
##     y a la mitad.
##
## Medido antes del repaso: 6.306 raciones de fruto seco en un año, con la
## despensa clavada en su tope y mas de la mitad del trabajo tirandose a la
## puerta del abrigo. Ver `BandaProbe`.
func _gathering_yields() -> Dictionary:
	# Lo que se coge DE PASO, vaya uno a lo que vaya. A la mitad de lo que era:
	# esto es lo que se recoge sin buscarlo, no una cosecha.
	#
	# LAS CIFRAS DE COMIDA SE SUBIERON DESPUES, y hace falta decir por que. El
	# primer repaso del calendario -avellana solo en otoño, baya fuera de
	# primavera, cesta diaria a la mitad- dejo a la banda produciendo 2.151
	# raciones al año contra las 4.572 que come: hambre al 100 nueve meses de
	# doce y despensa a cero. Medido con `BandaProbe`, no supuesto.
	#
	# El calendario NO se toco al arreglarlo -la avellana sigue siendo de
	# septiembre- porque el calendario no era el error. El error fue bajar la
	# cantidad Y quitar las temporadas de mas a la vez, y eso se corrige con la
	# cantidad, que es lo que es de balanceo.
	var yields := {
		Materia.Kind.LENA: 1.2,
		Materia.Kind.FIBRA: 1.6,
		Materia.Kind.YESCA: 0.35,
		Materia.Kind.CORTEZA: 0.5,
	}

	match GameState.season:
		Subsistence.Season.PRIMAVERA:
			# Todo brota y todo cria: poca caloria, mucha materia prima. Es la
			# estacion mas floja de la recoleccion y tiene que serlo -entre la
			# reserva agotada y la cosecha por venir esta el hambre de marzo.
			yields[Materia.Kind.HUEVO] = 8.0
			yields[Materia.Kind.CARACOL] = 10.0
			yields[Materia.Kind.PLUMA] = 1.2
			# La raiz es el colchon invisible, y en primavera es lo que hay.
			yields[Materia.Kind.RAIZ] = 15.0
		Subsistence.Season.VERANO:
			yields[Materia.Kind.BAYA] = 18.0
			yields[Materia.Kind.MIEL] = 1.8
			yields[Materia.Kind.CARACOL] = 6.0
			yields[Materia.Kind.RESINA] = 1.8
			# La fibra buena es de final de verano: la ortiga y el lino se
			# cortan cuando el tallo ya esta hecho.
			yields[Materia.Kind.FIBRA] = 3.2
			yields[Materia.Kind.RAIZ] = 9.0
		Subsistence.Season.OTONO:
			# La cosecha. Lo que se guarde ahora decide el invierno, y es la
			# UNICA estacion en que hay fruto seco y bellota.
			yields[Materia.Kind.FRUTO_SECO] = 42.0
			yields[Materia.Kind.BELLOTA] = 30.0
			yields[Materia.Kind.SETA] = 10.0
			yields[Materia.Kind.BAYA] = 9.0
			yields[Materia.Kind.RAIZ] = 10.0
		_:
			# Invierno: NO HAY VEGETAL. Lena, raiz desenterrada y la cuerna de
			# desmogue, que es la unica materia dura animal que no exige matar.
			# El ciervo desmoga de febrero a abril.
			yields[Materia.Kind.RAIZ] = 7.0
			yields[Materia.Kind.ASTA] = ASTA_DE_DESMOGUE
			yields[Materia.Kind.LENA] = 2.6
			yields[Materia.Kind.HUESO] = 0.8

	return yields


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


## Mueve a quien esta trabajando por su zona, de mata en mata.
##
## Sin esto la gente llegaba a un punto, se quedaba clavada seis horas y
## volvia, que se lee como un automata. Recoger es batir la mancha, y ademas
## asi la cuadrilla se reparte sola por el paraje en vez de amontonarse.
## Cuanto se recoge en cada mata antes de pasar a la siguiente, en horas.
##
## Tres cuartos de hora. Con las horas utiles de una jornada salen unas diez
## matas, que es batear una mancha; sorteando otra en cuanto se llega salian
## cientos, y la jornada se iba en andar entre ellas.
##
## Pendiente de playtest: subirlo deja al recolector mas quieto -y esquilma
## antes la mata-, bajarlo lo vuelve a poner a correr.
const RECOGER_LA_MATA := 0.75


func _forage_drift(person: Inhabitant, hours: float) -> void:
	if person.work_centre == Vector3.ZERO:
		person.work_centre = person.position

	if person.position.distance_to(person.forage_target) > sim.arrive_radius * 0.8:
		person.target = person.forage_target
		return

	# Y AL LLEGAR A LA MATA, SE RECOGE: no se sale corriendo a la siguiente.
	#
	# Sin esto, en cuanto se pisa el punto se sortea otro, y a velocidad de
	# persona setenta metros se andan en un minuto y medio: la jornada se iba en
	# ir de mata en mata sin pararse en ninguna. Medido en los rastros: seis y
	# ocho kilometros por salida para trabajar un paraje a ochocientos metros, y
	# un ovillo apretado donde tenia que haber trabajo.
	#
	# Un recolector no corre entre matas: se planta en una y la deja limpia.
	person.horas_en_el_tramo += hours
	if person.horas_en_el_tramo < RECOGER_LA_MATA:
		return
	person.horas_en_el_tramo = 0.0

	# Quien trabaja el agua bate la ORILLA, no la mancha entera.
	#
	# Se pesca y se marisquea con los pies en el borde: batiendo el paraje como
	# un recolector, la cuadrilla acababa a cincuenta metros del cauce, de
	# espaldas al río, «pescando» en un prado. Se prueban varios puntos y se
	# toma el primero que tenga agua al alcance de la mano; si ninguno la tiene
	# —el paraje se ha alejado del agua— se bate como siempre, que es mejor que
	# quedarse quieto.
	var waterside := person.activity == Subsistence.Activity.PESCA 		or person.activity == Subsistence.Activity.MARISQUEO
	var tries := SettlementSim.SHORE_TRIES if waterside else 1
	for attempt in range(tries):
		var angle := sim._rng.randf() * TAU
		var reach := Reconocimiento.FORAGE_RADIUS
		if waterside:
			reach *= SettlementSim.SHORE_FORAGE_FACTOR
		var radius := sqrt(sim._rng.randf()) * reach
		var candidate := person.work_centre + Vector3(
			cos(angle) * radius, 0.0, sin(angle) * radius)
		if sim._terrain:
			candidate.y = sim._terrain.get_height_at(candidate)
			# No se va a recoger al otro lado de un cortado ni al agua
			if not Traversal.is_passable(sim._terrain.get_slope_at(candidate),
					sim._terrain.crossing_difficulty_at(candidate), sim.has_boat, sim.has_bridge):
				continue
			if waterside and attempt < tries - 1 and not _water_beside(candidate):
				continue
			# NI SE CRUZA EL AGUA PARA IR A LA MATA SIGUIENTE.
			#
			# El punto de allá es tierra firme y pisable, así que pasaba el
			# filtro de arriba; lo que no se puede es LLEGAR. En una pesquera
			# —donde el sitio es el río y sus dos orillas están a treinta
			# metros— eso es la jornada entera andando contra el agua. Ver
			# [Marcha.cruza_el_agua].
			if sim.marcha.cruza_el_agua(person.work_centre, candidate):
				continue

		person.forage_target = candidate
		person.target = candidate
		return


