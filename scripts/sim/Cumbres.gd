class_name Cumbres
extends RefCounted
## Las cumbres de la comarca: encontrarlas, repartirlas y coronarlas.
##
## Sale de `SettlementSim` por lo mismo que [Caceria], [Nasas] y [Trampas]: es
## un tema cerrado que no lo toca nadie mas. Y ademas es el mas separable de
## todos, porque la cumbre no es un recurso: no se agota, no se reparte, no se
## acarrea. Se sube una vez, se mira, y ya esta.
##
## Lo que se queda en el simulador y no viene aqui es la RECOMPENSA de coronar
## -`_award_exploration_skill`, `raise_moment`, el hito de la cronica-: eso es
## del sistema de pericia y de la cronica, no de la montana.
var sim: SettlementSim

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


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Se olvida lo encontrado: el mapa de debajo ha cambiado.
func forget() -> void:
	_peak_found = false


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

	if sim._terrain == null:
		return _peaks

	# Los candidatos se recortan al recuadro del mapa. Fuera de el
	# `get_height_at` devuelve la altura del BORDE, no la real, asi que sin
	# recortar el barrido se iba a buscar cumbres que no existen.
	var limit_x := float(sim._terrain.terrain_size.x)
	var limit_z := float(sim._terrain.terrain_size.y)
	var margin := 40.0
	var home_height := sim._terrain.get_height_at(sim.home_position)

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
			var seed_point := sim.home_position + Vector3(
				float(dx) * PEAK_SEED_STEP, 0.0, float(dz) * PEAK_SEED_STEP)
			if seed_point.distance_to(sim.home_position) > PEAK_SEARCH_RADIUS:
				continue
			if seed_point.x < margin or seed_point.z < margin 					or seed_point.x > limit_x - margin 					or seed_point.z > limit_z - margin:
				continue
			seed_point.y = sim._terrain.get_height_at(seed_point)
			candidates.append(seed_point)

	# --- 2. y se sube andando hasta el alto de verdad --------------------
	for rough: Vector3 in candidates:
		var summit := _climb_to_top(rough, margin, limit_x, limit_z)
		var away := summit.distance_to(sim.home_position)
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
				sim._terrain.get_slope_at(summit), away),
		})

	# De la mas dura a la mas suave: asi elegir «la mejor que me atrevo» es
	# recorrer la lista y quedarse con la primera
	_peaks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["hard"]) > float(b["hard"]))

	print("Cumbres al alcance: %d" % _peaks.size())

	# Si la mas alta pide equipo, se dice una vez. No es un aviso de error: es
	# una promesa de que hay mas juego mas adelante, y de las que dan ganas.
	if not _peaks.is_empty() and Ascent.needs_gear(float(_peaks[0]["hard"])):
		sim._note(Chronicle.Kind.TIERRA,
			"Hay un alto %s que nadie de la banda sabe como subir. Haria falta "
				% Parajes.bearing(sim.home_position, _peaks[0]["pos"])
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
	here.y = sim._terrain.get_height_at(here)

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
					side.y = sim._terrain.get_height_at(side)
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
		lowest = minf(lowest, sim._terrain.get_height_at(point))
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
	for p: Inhabitant in sim.people:
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
	for person: Inhabitant in sim.people:
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
	for person: Inhabitant in sim.people:
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
	sim.apply_priorities()
	sim._note(Chronicle.Kind.TIERRA, "%s va a intentar la cumbre %s."
		% [climber.given_name, sim.parajes.place_name(peak_order, sim.home_position)], 1)
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
			if float(peak["hard"]) <= dares and sim.marcha._reachable(person, peak["pos"]):
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
		if not sim.marcha._reachable(person, peak["pos"]):
			continue
		if float(peak["hard"]) <= dares:
			within.append(peak)

	if not within.is_empty():
		# De las que puede, tira a las mas dificiles: es lo que hace alguien
		# con ganas de mirar lejos. Pero no siempre la peor, que seria un
		# automata igual que ir siempre a la primera.
		within.sort_custom(func(a, b): return float(a["hard"]) > float(b["hard"]))
		var reach := maxi(within.size() / 2, 1)
		return within[sim._rng.randi() % reach]

	# Ninguna a su altura: la mas suave que haya, que es lo que hace alguien
	# de verdad -mirar el monte y bajar el objetivo- en vez de ir derecho a la
	# peor pared del valle.
	for i in range(peaks.size() - 1, -1, -1):
		if Ascent.needs_gear(float(peaks[i]["hard"])):
			continue
		if not _climbing_party_enough(float(peaks[i]["hard"])):
			continue
		if sim.marcha._reachable(person, peaks[i]["pos"]):
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
	if peaks.is_empty() and not sim._peaks_done and not _climbed.is_empty():
		sim._peaks_done = true
		sim._note(Chronicle.Kind.TIERRA,
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
		if flat.length() < sim.arrive_radius * 2.0:
			return true
	return false


func _do_ascent(person: Inhabitant) -> void:
	if sim.knowledge:
		sim.knowledge.see_from(person.position, ASCENT_SIGHT_RANGE)
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
	var where := sim.parajes.place_name(person.position, sim.home_position)
	if ascents == 1:
		sim._note(Chronicle.Kind.HALLAZGO,
			"%s corono el alto %s. Desde alli se ve de golpe lo que costaria "
				% [person.given_name, where] + "semanas recorrer.", 2)
	elif remaining:
		sim._note(Chronicle.Kind.HALLAZGO,
			"%s corono otra cumbre, la %d de la banda. Queda mas monte por "
				% [person.given_name, ascents] + "encima del valle.", 1)
	else:
		sim._note(Chronicle.Kind.HALLAZGO,
			"%s corono la ultima cumbre al alcance. Ya no queda alto que suba "
				% person.given_name
			+ "lo bastante: a partir de ahora saldran de expedicion.", 2)

	# Y se para la partida a enseñarlo. Coronar un pico revela media comarca de
	# golpe -ver `_reveal_from_summit`- y hasta ahora eso era un cambio callado
	# en el mapa de niebla que el jugador descubría después, si se fijaba.
	# Y se cuenta como lo que es: un HITO, con la opción de dejarlo en la
	# pared. Coronar un alto no es un dato del mapa, es el día que la banda
	# supo por dónde seguía el valle.
	#
	# El bautizo de un paraje NO pasa por aquí y no es un olvido: un relato con
	# opciones para el reloj -ver [Moment]-, y si cada sitio con nombre parara
	# la partida a preguntar si se pinta, en dos estaciones el jugador
	# aprendería a cerrar la tarjeta sin leerla. Lo que se pinta es lo que pasa
	# pocas veces.
	sim.tell_tale(Tale.discovery("Cumbre coronada",
		"%s ha coronado el alto %s. Desde arriba se lee de una vez medio valle: "
			% [person.given_name, where]
		+ "dónde abunda la caza, por dónde va el agua y qué queda por explorar.",
		person.position, sim.day, person.current_task()))


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
	if sim.knowledge == null or sim.field == null:
		return
	for z in range(sim.field.height):
		for x in range(sim.field.width):
			var centre := sim.field.cell_center(x, z)
			if centre.distance_to(peak_position) > ASCENT_SIGHT_RANGE:
				continue
			if sim.knowledge.explored_at(centre) < SUMMIT_REVEAL_CLARITY:
				continue
			for activity: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
					Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
					Subsistence.Activity.MATERIA_PRIMA]:
				sim.knowledge.reveal(activity as Subsistence.Activity, centre,
					BandKnowledge.KNOWN_ENOUGH + 0.02)


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
	var odds := Ascent.chance(skill, hardness, sim.weather.risk_factor(),
		person.fatigue)

	var where := sim.parajes.place_name(person.position, sim.home_position)
	person.fatigue = clampf(
		person.fatigue + 18.0 * person.fatigue_factor(), 0.0, 100.0)

	# Se aprende intentandolo, se corone o no: es lo que hace que valga la
	# pena mandar al novato a cumbres pequenas antes que a la grande
	person.skill[task] = minf(skill + 0.035 * person.learn_rate(), 0.95)

	if sim._rng.randf() > odds:
		var scale := sim._terrain.meters_per_unit 			/ maxf(sim._terrain.vertical_exaggeration, 0.001) if sim._terrain else 1.0
		var missing := int(float(peak["rise"]) * (1.0 - Ascent.reached(sim._rng)) * scale)
		sim._note(Chronicle.Kind.PENURIA,
			"%s no pudo con la cumbre %s. Se quedo a unos %d m del alto y "
				% [person.given_name, where, maxi(missing, 10)]
			+ "tuvo que bajar.", 1)
		person.end_journey(sim.day, where,
			"NO corono: se quedo a %d m del alto" % maxi(missing, 10))
		return

	person.end_journey(sim.day, where, "CORONADA (+%d m)" % int(_peak_rise(peak)))

	# El hito grande de la ascension: cada cumbre solo se ofrece una vez -ver
	# `_already_climbed`, que las saca de `peak_for`-, asi que coronar SIEMPRE
	# es abrir un pico que nadie habia pisado, no repetir el de ayer.
	sim.reconocimiento._award_exploration_skill(person, Profession.Speciality.ASCENSION, SettlementSim.PEAK_MILESTONE)

	_do_ascent(person)


## Cuanto se levanta una cumbre sobre el valle, en metros de verdad.
func _peak_rise(peak: Dictionary) -> float:
	if sim._terrain == null:
		return float(peak.get("rise", 0.0))
	return float(peak.get("rise", 0.0)) * sim._terrain.meters_per_unit \
		/ maxf(sim._terrain.vertical_exaggeration, 0.001)
