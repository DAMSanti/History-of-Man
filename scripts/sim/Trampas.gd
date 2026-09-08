class_name Trampas
extends RefCounted
## La linea de trampas de tierra: armarlas, repasarlas y levantarlas.
##
## Sale de `SettlementSim` por lo mismo que [Caceria] y [Nasas]: es un tema
## cerrado. Y es la hermana de tierra de la nasa -se arma, se deja y se
## vuelve-; la diferencia es que la trampa no pide cebo y no se la lleva la
## corriente, se la lleva quien pasa.
##
## Se quedaron en el simulador `_butcher`, `_can_afford` y `_quarry_bonus`:
## estaban aparcados en esta seccion pero los usa medio juego.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement

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
## llega al paraje, no a la estaca, y `sim._forage_drift` lo mueve por la mancha
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
	for person: Inhabitant in sim.people:
		if person.current_speciality == Profession.Speciality.TRAMPAS:
			trappers += 1
	return maxi(trappers, 1) * TRAMPAS_POR_TRAMPERO



## Los tipos de trampa que la banda sabe armar hoy, de la mejor a la peor.
func known_traps() -> Array[int]:
	var out: Array[int] = []
	for kind: int in Trap.INFO:
		var tech := Trap.tech_of(kind as Trap.Kind)
		if tech >= 0 and (sim.techs == null or not sim.techs.has(tech as TechTree.Tech)):
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
		if not sim._can_afford(Trap.materials(kind as Trap.Kind)):
			continue
		if fallback < 0:
			fallback = kind
		for species: String in Trap.catches(kind as Trap.Kind):
			if here.has(species):
				return kind
	return fallback



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
	var fraction := hours / SettlementSim.HORAS_UTILES
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
					GameState.season as Subsistence.Season, sim._rng)
				brought.append(Fauna.species_name(species).to_lower())
				sim._butcher(person, species, 1.0)
			person.log_deed(person.current_task(),
				"levantó %s: %s" % [Trap.trap_name(trap.kind).to_lower(),
					", ".join(brought)])
			sim._note(Chronicle.Kind.TIERRA, "%s levantó %s en %s: %s."
				% [person.given_name, Trap.trap_name(trap.kind).to_lower(),
					sim.parajes.place_name(trap.position, sim.home_position),
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
	if not sim._can_afford(Trap.materials(trap_kind)):
		return
	for material: int in Trap.materials(trap_kind):
		sim.store.take(material as Materia.Kind,
			float(Trap.materials(trap_kind)[material]))

	var placed := Trap.create(trap_kind, person.position, sim.day, person.given_name)
	traps.append(placed)
	traps_set_today.append(placed)
	person.log_deed(person.current_task(),
		"armó %s" % Trap.trap_name(trap_kind).to_lower())
	sim._note(Chronicle.Kind.TIERRA, "%s armó %s en %s. Cobra sola: solo hay que ir a levantarla."
		% [person.given_name, Trap.trap_name(trap_kind).to_lower(),
			sim.parajes.place_name(placed.position, sim.home_position)], 1)

