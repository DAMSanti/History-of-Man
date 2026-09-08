class_name Nasas
extends RefCounted
## La linea de nasas: ponerlas, cebarlas y levantarlas.
##
## Sale de `SettlementSim` por lo mismo que [Caceria]: es un tema cerrado que
## no se cruza con ningun otro, y aquel fichero pasaba de nueve mil lineas.
##
## Es la hermana de agua de la trampa de tierra -ver `_trapline`-: se arma, se
## deja y se vuelve. La diferencia es que la nasa pide cebo y se la lleva la
## corriente.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement

# --- La línea de nasas ---------------------------------------------------
#
# Es la trampa del río, y va aquí abajo al lado de aquélla porque son la misma
# idea con dos diferencias que importan.
#
# La primera es que la nasa NO sustituye a la jornada: el trampero se pasa el
# día recorriendo la línea y no hace otra cosa, mientras que el pescador
# revisa las nasas por la mañana —un rato— y luego se mete en el agua a pescar.
# Eso es lo que se pidió, literal: «coloca o revisa unas nasas y después el
# resto del tiempo le dedica a pescar activamente».
#
# La segunda es el CEBO. Una trampa de monte se ceba una vez y ya; una nasa
# pierde el cebo en el agua y hay que reponerlo, y ésa es la mitad del trabajo
# de revisar la línea. Ver [Nasa].

## Las nasas caladas, con su sitio y su estado.
var nasas: Array[Nasa] = []

## Las caladas hoy y las que hoy se han podrido, para la crónica y el marcador.
var nasas_set_today: Array[Nasa] = []
var nasas_lost_today: Array[Nasa] = []

## Cuántas nasas mantiene calada cada pescador de orilla.
##
## Menos que trampas de monte -[sim.trampas.TRAMPAS_POR_TRAMPERO] son cinco- por dos
## motivos: la línea de nasas se recorre metido en el agua, y además el
## pescador sólo le dedica un rato de la jornada. Cuatro es lo que da tiempo a
## revisar antes de ponerse a pescar de verdad.
const NASAS_POR_PESCADOR := 4

## A qué distancia se levanta una nasa sin desviarse. La misma que la trampa y
## por la misma razón: se llega al paraje, no a la estaca.
const ALCANCE_NASA := 160.0

## Lo cerca que pueden estar dos nasas. Menos que entre trampas: un río es una
## línea y las nasas se calan a lo largo del cauce, no repartidas por un monte.
const SEPARACION_NASAS := 45.0


## Cuántas nasas caben, por los pescadores que hay puestos a ello.
func nasa_allowance() -> int:
	var fishers := 0
	for person: Inhabitant in sim.people:
		if person.current_speciality == Profession.Speciality.ORILLA:
			fishers += 1
	return maxi(fishers, 1) * NASAS_POR_PESCADOR


## Si la banda sabe calar nasas y tiene alguna hecha.
func can_set_nasas() -> bool:
	if sim.techs == null or not sim.techs.has(TechTree.Tech.NASA):
		return false
	return sim.toolkit.count(Tool.Kind.NASA) > 0


## Si en este punto cabe una nasa más: junto al agua, ni encima de otra, ni
## pasándose de las que se pueden recorrer.
func _room_for_nasa(point: Vector3) -> bool:
	if nasas.size() >= nasa_allowance():
		return false
	if sim._terrain != null and not sim.tajo._water_beside(point):
		return false
	for nasa: Nasa in nasas:
		var flat := Vector2(point.x - nasa.position.x, point.z - nasa.position.z)
		if flat.length() < SEPARACION_NASAS:
			return false
	return true


## La nasa que más lleva cobrado, o null si ninguna tiene nada. Es a la que
## hay que ir hoy, igual que [sim.trampas._fullest_trap] en el monte.
func _fullest_nasa() -> Nasa:
	var best: Nasa = null
	var best_ready := 0.0
	for nasa: Nasa in nasas:
		if not nasa.has_catch() or nasa.ready() <= best_ready:
			continue
		best_ready = nasa.ready()
		best = nasa
	return best


## La nasa más cercana con algo dentro, o null.
func nasa_with_catch_near(point: Vector3, radius: float) -> Nasa:
	var best: Nasa = null
	var best_distance := radius
	for nasa: Nasa in nasas:
		if not nasa.has_catch():
			continue
		var flat := Vector2(point.x - nasa.position.x, point.z - nasa.position.z)
		if flat.length() < best_distance:
			best_distance = flat.length()
			best = nasa
	return best


## La nasa cercana a la que le falta cebo, o null. Una nasa sin cebar sigue
## cogiendo -ver [Nasa.SIN_CEBO]- pero coge poco, y reponerlo es barato.
func _nasa_to_rebait(point: Vector3, radius: float) -> Nasa:
	for nasa: Nasa in nasas:
		if nasa.is_baited():
			continue
		var flat := Vector2(point.x - nasa.position.x, point.z - nasa.position.z)
		if flat.length() < radius:
			return nasa
	return null


## La ronda de nasas del pescador. Devuelve las HORAS QUE LE QUEDAN de jornada.
##
## Esto es lo que hace que la nasa se sume a la pesca en vez de sustituirla: se
## lleva un rato —levantar lo que haya caído, cebar lo que esté sin cebo, calar
## una más si hay sitio y hay nasa hecha— y devuelve el resto del día para que
## quien llama se ponga a pescar de verdad con `sim._harvest`.
##
## El orden es el que tiene sentido en el río y no el que cae mejor: primero lo
## que ya está cobrado, que es lo que rinde; luego el cebo, que es lo que hace
## que mañana haya algo; y sólo al final alargar la línea.
func _creel_round(person: Inhabitant, hours: float) -> float:
	if person.current_speciality != Profession.Speciality.ORILLA:
		return hours
	if sim.techs == null or not sim.techs.has(TechTree.Tech.NASA):
		return hours

	# UNA VEZ AL DIA. Es lo que separa revisar la línea de vivir en ella: quien
	# llama entra aquí en cada tick, y sin esta marca el pescador con una nasa
	# sin cebo se pasaba la jornada cebándola sin llegar a pescar. Medido: la
	# pesca de orilla cayó de 7,68 raciones por jornada-persona a 3,22.
	if person.creel_day == sim.day:
		return hours

	# 1. Levantar la que tenga algo dentro.
	var full := nasa_with_catch_near(person.position, ALCANCE_NASA)
	if full == null:
		full = nasa_with_catch_near(person.work_centre, ALCANCE_NASA)
	if full != null:
		var pieces := full.collect()
		if pieces > 0:
			# Y SE VUELVE A CEBAR ANTES DE SOLTARLA, que es lo que se hace: se
			# levanta el cesto, se saca el pez, se le echa cebo nuevo y se cala
			# otra vez. Separarlo en dos visitas parecía más ordenado y era
			# falso, y además se veía: con una nasa dando pieza todos los días,
			# el pescador iba siempre a ésa y las demás se quedaban sin cebo
			# para siempre. Comprobado mirando, en la orilla, con el rótulo
			# «sin cebo» encima y cuarenta caracoles en el abrigo.
			_rebait(full)
			var rations := float(pieces) * Nasa.RACIONES_POR_PIEZA
			var units := rations / maxf(
				Materia.nutrition(Materia.Kind.PESCADO), 0.001)
			person.add_load(Materia.Kind.PESCADO, units)
			person.carrying += rations
			person.log_gain(person.current_task(), Materia.Kind.PESCADO, units)
			person.log_deed(person.current_task(),
				"levantó la nasa: %d piezas" % pieces)
			sim._note(Chronicle.Kind.TIERRA, "%s levantó la nasa de %s: %d piezas."
				% [person.given_name,
					sim.parajes.place_name(full.position, sim.home_position), pieces], 0)
			person.creel_day = sim.day
			return _spend(hours, Nasa.JORNADA_DE_REVISAR)

	# 2. Reponer el cebo de la que lo haya perdido. Sin esto la línea entera
	#    acaba cogiendo al cuarenta por ciento sin que nadie se entere.
	var hungry := _nasa_to_rebait(person.position, ALCANCE_NASA)
	if hungry != null and _rebait(hungry):
		person.log_deed(person.current_task(),
			"cebó la nasa con %s" % Materia.material_name(
				hungry.bait_kind as Materia.Kind).to_lower(), false)
		person.creel_day = sim.day
		return _spend(hours, Nasa.JORNADA_DE_REVISAR)

	# 3. Y si no hay nada que atender, se alarga la línea.
	if not can_set_nasas() or not _room_for_nasa(person.position):
		return hours

	var piece := sim.toolkit.detach(Tool.Kind.NASA)
	if piece == null:
		return hours
	var placed := Nasa.create(person.position, sim.day, piece, person.given_name)
	_rebait(placed)
	nasas.append(placed)
	nasas_set_today.append(placed)
	person.creel_day = sim.day
	person.log_deed(person.current_task(), "caló una nasa")
	sim._note(Chronicle.Kind.TIERRA,
		"%s caló una nasa en %s. Pesca sola: sólo hay que ir a levantarla."
			% [person.given_name,
				sim.parajes.place_name(placed.position, sim.home_position)], 1)
	return _spend(hours, Nasa.JORNADA_DE_CALAR)


## Le echa cebo del abrigo si hay y le hace falta. Devuelve si se cebó.
##
## En un solo sitio porque se ceba en tres momentos —al calarla, al levantarla
## y al pasar a repasar la línea— y con tres copias del mismo bloque una de
## ellas acabaría olvidándose de descontar el caracol.
func _rebait(nasa: Nasa) -> bool:
	if nasa.is_baited():
		return false
	var bait := Nasa.bait_at_hand(sim.store)
	if bait < 0:
		return false
	sim.store.take(bait as Materia.Kind, Nasa.CEBO_POR_CALADA)
	nasa.rebait(bait)
	return true


## Lo que queda de un rato de jornada después de gastarle una fracción.
func _spend(hours: float, day_fraction: float) -> float:
	return maxf(hours - day_fraction * SettlementSim.HORAS_UTILES, 0.0)


## Pasa un día por todas las nasas: pescan solas, pierden el cebo y el mimbre
## se pudre en el agua.
func _age_nasas() -> void:
	nasas_set_today.clear()
	nasas_lost_today.clear()
	if nasas.is_empty():
		return

	var alive: Array[Nasa] = []
	for nasa: Nasa in nasas:
		nasa.soak(1.0)
		if nasa.is_spent():
			nasas_lost_today.append(nasa)
			sim._note(Chronicle.Kind.PENURIA,
				"La nasa de %s se ha podrido en %s. Dio %d piezas."
					% [nasa.maker,
						sim.parajes.place_name(nasa.position, sim.home_position),
						nasa.taken], 0)
			continue
		alive.append(nasa)
	nasas = alive

