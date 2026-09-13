class_name Expedicion
extends RefCounted
## La salida larga: se sale del mapa, se tarda jornadas y se vuelve sabiendo
## más — o no se vuelve sabiendo nada, pero las jornadas se han ido igual.
##
## Es la capa regional de docs/SISTEMAS.md §4, y **lo único que la levanta**:
## la niebla ya estaba puesta —`GameState.discovered` arranca con la cueva y
## `RegionMap` filtra por él— pero nadie llamaba a `GameState.discover` desde
## la partida, así que el mapa se quedaba en la cueva para siempre. Medido en
## ESTADO.md §2.
##
## ## Lo que cuesta, que es la mitad del frente
##
## Salir del abrigo no se vuelve el mismo día: quien va **no trabaja** mientras
## está fuera y **come de la despensa** antes de irse. Y una expedición que
## vuelve sin llegar cuesta exactamente lo mismo, porque el coste es haber
## salido, no haber acertado.

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Cuántas jornadas se está fuera.
##
## Doce: bastante para que se note en la contabilidad del oficio —una estación
## son cuarenta y cinco, así que es un cuarto de estación— y poco para que
## quepan dos o tres en un año. **Es una decisión, no una medida**, y se ajusta
## con la partida delante.
const JORNADAS_FUERA := 12

## A cuántos emplazamientos llega la noticia de lo que se ha visto.
##
## Se descubre el destino y sus vecinos más cercanos: se ha andado hasta allí,
## se ha mirado desde allí, y se vuelve sabiendo lo que se ve desde allí.
## Decisión, no medida.
const SE_DESCUBREN := 4

## Cuánta gente hace falta para que salga una expedición.
##
## Tres: sola no se sale —el criterio del vivac ya dice que dormir fuera es
## peligroso— y más de tres deja la banda corta en casa. Decisión.
const MINIMO_PARA_SALIR := 3


## Quiénes están fuera ahora mismo, por id.
var fuera: Array[int] = []

## A qué emplazamiento se fue, y qué jornada vuelven.
var destino_id: int = -1
var vuelve_el_dia: int = -1

## Si se ha mandado alguna vez. Es una de las tres condiciones que cierran la
## primera fase — ver [Partida].
var mandada_alguna_vez := false

## Cuántas expediciones han vuelto, y cuántos emplazamientos han descubierto
## entre todas. Lo mira la sonda.
var vueltas := 0
var descubiertos := 0

## Las jornadas-persona que se han ido en expediciones. Es la cifra que el
## frente pide contar: esas jornadas **no se recolectan**.
var jornadas_persona := 0

## Los emplazamientos de la comarca. Lo pone [DemoMain]; sin él no se puede
## descubrir nada y la expedición sale igual, que es lo correcto: el coste no
## depende de que haya mapa.
var sitios: SiteSet = null


## Si hay una expedición fuera ahora mismo.
func en_marcha() -> bool:
	return not fuera.is_empty()


## Se manda una expedición. Devuelve si ha salido.
##
## No sale si ya hay una fuera, si no hay gente bastante, o si la despensa no
## da para avituallarla: salir sin comida es mandar a tres personas a morirse,
## no una decisión difícil.
func mandar(cuantos: int, hacia: int) -> bool:
	if en_marcha():
		return false
	if cuantos < MINIMO_PARA_SALIR:
		return false

	var candidatos := _quienes_pueden_ir(cuantos)
	if candidatos.size() < cuantos:
		return false

	# EL AVITUALLAMIENTO VA PRIMERO, y si no hay, no se sale. La cuenta es la
	# de siempre -[Materia.KCAL_RACION], media jornada de una persona- y no una
	# unidad nueva: invariante 1 de SPECS §7.
	# Se mira ANTES de sacar: `sacar_raciones` se lleva lo que haya aunque no
	# llegue, y una expedición que no sale no se come la despensa.
	var hacen_falta := float(cuantos * JORNADAS_FUERA) * 2.0
	if sim.store.food_rations() < hacen_falta:
		sim._note(Chronicle.Kind.PENURIA,
			"No hay despensa para avituallar una expedición: se queda en casa.",
			0)
		return false
	sim.despensa.sacar_raciones(hacen_falta)

	fuera.clear()
	for person: Inhabitant in candidatos:
		person.expedicion_hasta = sim.day + JORNADAS_FUERA
		fuera.append(person.id)
	destino_id = hacia
	vuelve_el_dia = sim.day + JORNADAS_FUERA
	mandada_alguna_vez = true
	jornadas_persona += cuantos * JORNADAS_FUERA

	sim._note(Chronicle.Kind.HALLAZGO,
		"Salen %d a ver qué hay más allá del valle. No vuelven en %d jornadas."
			% [cuantos, JORNADAS_FUERA], 2)
	return true


## Un día de expedición. Lo llama [SettlementSim] al cerrar la jornada.
func nuevo_dia() -> void:
	if not en_marcha():
		return
	if sim.day < vuelve_el_dia:
		return
	_volver()


## Quiénes pueden ir: los adultos que están en casa.
##
## Ni niños ni ancianos: doce jornadas fuera del valle, durmiendo al raso por
## sitios que nadie conoce, son para adultos. Es una decisión de diseño.
func _quienes_pueden_ir(cuantos: int) -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		if out.size() >= cuantos:
			break
		if person.esta_de_expedicion(sim.day):
			continue
		if person.age_group != Inhabitant.Age.ADULTO:
			continue
		out.append(person)
	return out


## Vuelven, y con lo que hayan visto.
func _volver() -> void:
	for person: Inhabitant in sim.people:
		if fuera.has(person.id):
			person.expedicion_hasta = -1
			# Vuelven AL ABRIGO. Mientras estaban fuera no se les simulaba, asi
			# que su posicion es la de la jornada en que salieron.
			person.position = sim.home_position
	fuera.clear()
	vueltas += 1

	var nuevos := _descubrir_alrededor(destino_id)
	descubiertos += nuevos

	# EL CONTACTO, que es el propósito de todo esto: la expedición no busca
	# terreno, busca gente con la que tratar. Ver docs/SISTEMAS.md §4.
	var conocida := false
	# LA PRIMERA EXPEDICIÓN SIEMPRE ENCUENTRA GENTE, decidido por el usuario el
	# 2026-09-13. Con uno de cada cinco sitios ocupados y contacto sólo en el
	# destino, la pasada de dos años con un jugador que manda la expedición
	# acabó con **cero tratos y nadie conocido**: el trueque quedaba a una tirada
	# al año, y la mayoría de partidas no lo verían nunca. Sólo la primera; de
	# ahí en adelante, el sorteo de [Contacto.OCUPADOS] como siempre. ESTADO §2,
	# «Dos años con un jugador que decide».
	if vueltas == 1 and sim.contacto != null and destino_id >= 0:
		sim.contacto.poblar(destino_id)
	if sim.contacto != null and sim.contacto.hay_gente_en(destino_id):
		conocida = sim.contacto.conocerse(destino_id)

	if conocida:
		sim._note(Chronicle.Kind.HALLAZGO,
			"La expedición vuelve con algo que no se esperaba: allí vive otra "
				+ "gente. Se puede tratar con ellos.", 3)
	elif nuevos > 0:
		sim._note(Chronicle.Kind.HALLAZGO,
			("Vuelve la expedición: %d sitios nuevos que antes no estaban en "
				+ "la cabeza de nadie.") % nuevos, 2)
	else:
		# Y ÉSTE ES EL CASO QUE EL CRITERIO EXIGE QUE CUESTE IGUAL.
		sim._note(Chronicle.Kind.PENURIA,
			"Vuelve la expedición sin nada que contar. Las jornadas se han "
				+ "ido igual.", 1)
	destino_id = -1
	vuelve_el_dia = -1


## Se levanta la niebla del destino y de sus vecinos. Devuelve cuántos eran
## nuevos de verdad.
func _descubrir_alrededor(id: int) -> int:
	if sitios == null or id < 0:
		return 0
	var centro: Site = null
	for s: Site in sitios.sites:
		if s.id == id:
			centro = s
			break
	if centro == null:
		return 0

	# Por cercanía al destino, que es lo que se ve desde allí.
	var cerca: Array[Site] = sitios.sites.duplicate()
	cerca.sort_custom(func(a: Site, b: Site) -> bool:
		return _lejos(centro, a) < _lejos(centro, b))

	var nuevos := 0
	for s: Site in cerca:
		if nuevos >= SE_DESCUBREN:
			break
		if GameState.is_discovered(s):
			continue
		GameState.discover(s)
		nuevos += 1
	return nuevos


static func _lejos(a: Site, b: Site) -> float:
	var dlon := a.lon - b.lon
	var dlat := a.lat - b.lat
	return dlon * dlon + dlat * dlat



## Adónde iría una expedición mandada hoy: el emplazamiento sin descubrir más
## cercano a la cueva. -1 si no queda ninguno o no hay comarca.
##
## El más cercano y no uno sorteado: la primera salida de una banda que no
## conoce la comarca va a lo que tiene al lado, y así la decisión se puede
## leer —«vamos a ver qué hay en el valle de al lado»— en vez de ser una
## lotería.
func destino_de_hoy() -> int:
	if sitios == null:
		return -1
	var casa: Site = GameState.home
	var mejor := -1
	var mejor_lejos := INF
	for s: Site in sitios.available_in(GameState.sea_level_m, GameState.era):
		if GameState.is_discovered(s):
			continue
		var lejos := _lejos(casa, s) if casa != null else float(s.id)
		if lejos < mejor_lejos:
			mejor_lejos = lejos
			mejor = s.id
	return mejor


## Propone la decisión de la primavera. Lo llama [SettlementSim] al entrar la
## primavera. Es, además, **el botón que la expedición no tenía**: hasta ahora
## `mandar` sólo se podía llamar desde código.
##
## No sale tarjeta si ya hay una fuera o si no queda adónde ir: una decisión
## con una sola salida no es una decisión.
func proponer_la_salida() -> void:
	if en_marcha():
		return
	var hacia := destino_de_hoy()
	if hacia < 0:
		return
	var raciones := float(MINIMO_PARA_SALIR * JORNADAS_FUERA) * 2.0
	var moment := Moment.new()
	moment.kind = Moment.Kind.EXPEDICION
	moment.title = "Es primavera: ¿se sale del valle?"
	moment.text = ("Hay %d sitios conocidos. Una expedición saldría hacia lo que "
		+ "haya al otro lado del valle, y podría volver con noticias —o con "
		+ "gente con la que tratar—.") % GameState.discovered.size()
	moment.options = [
		Moment.opcion("Este año no",
			"Nadie sale. No cuesta nada y no se sabe nada nuevo.",
			func() -> void: pass),
		Moment.opcion("Mandarla",
			("Salen %d adultos %d jornadas y se llevan %.0f raciones que no "
				+ "vuelven, encuentren algo o no.") % [MINIMO_PARA_SALIR,
					JORNADAS_FUERA, raciones],
			func() -> void: mandar(MINIMO_PARA_SALIR, hacia),
			{"jornadas": MINIMO_PARA_SALIR * JORNADAS_FUERA, "despensa": -raciones}),
	]
	sim.raise_moment(moment)
