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
## Lo que hay que meter en el zurrón para mandar a `cuantos` fuera.
##
## **Las mismas constantes del vivac que usa la cumbre**, no una copia: una piel
## de tienda por persona —que vuelve, ver [SettlementSim.VIVAC_PIEL]— y una de
## leña por persona y noche, más la noche de margen. Con tres personas y doce
## jornadas: 72 raciones, 3 pieles y 39 de leña.
func hace_falta_para(cuantos: int) -> Dictionary:
	var noches := float(JORNADAS_FUERA) + SettlementSim.VIVAC_MARGEN_NOCHES
	return {
		"raciones": float(cuantos * JORNADAS_FUERA) * 2.0,
		"piel": float(cuantos) * SettlementSim.VIVAC_PIEL,
		"lena": float(cuantos) * SettlementSim.VIVAC_LENA * noches,
	}


## Qué falta en el abrigo para que puedan salir, dicho como se diría. Vacío si
## no falta nada. Es lo que la tarjeta enseña cuando no se puede decir que sí.
func lo_que_falta(cuantos: int) -> Array[String]:
	var hace_falta := hace_falta_para(cuantos)
	var falta: Array[String] = []
	if sim.store.food_rations() < float(hace_falta["raciones"]):
		falta.append("%.0f raciones" % float(hace_falta["raciones"]))
	if sim.store.amount(Materia.Kind.PIEL) < float(hace_falta["piel"]):
		falta.append("%.0f pieles de tienda" % float(hace_falta["piel"]))
	if sim.store.amount(Materia.Kind.LENA) < float(hace_falta["lena"]):
		falta.append("%.0f de leña" % float(hace_falta["lena"]))
	return falta


## Las pieles que se llevaron puestas de tienda, para devolverlas al volver.
var pieles_prestadas := 0.0

## Por dónde se sale del valle: la celda del borde del mapa hacia el destino.
##
## Se guarda para volver por el mismo sitio, que es lo que hace que la vuelta se
## lea como una vuelta y no como una aparición.
var salida: Vector3 = Vector3.ZERO

## A cuánto del borde se da por salido del valle.
const LLEGADA := 24.0


## La puerta del valle hacia un destino regional: la celda del borde del mapa
## **alcanzable** más cercana a ese rumbo.
##
## Alcanzable y no la que caiga: nadie da un paso sin camino debajo —SPECS
## §4.3—, y el borde del mapa es tan de piedra y agua como el resto. Si por el
## rumbo del destino no se llega al borde, se sale por la celda alcanzable que
## más se le acerque, que es lo que haría cualquiera.
func puerta_del_valle(hacia: int) -> Vector3:
	if sim._terrain == null:
		return sim.home_position
	var lado := float(sim._terrain.terrain_size.x)
	var fondo := float(sim._terrain.terrain_size.y)
	var rumbo := Vector3(1.0, 0.0, 0.0)
	if sitios != null:
		var casa: Site = GameState.home
		for s: Site in sitios.available_in(GameState.sea_level_m, GameState.era):
			if s.id != hacia or casa == null:
				continue
			# El rumbo regional, pasado al mapa local: lon crece al este y lat
			# al norte, y la z del mundo crece al sur.
			rumbo = Vector3(s.lon - casa.lon, 0.0, casa.lat - s.lat)
			if rumbo.length() < 0.0001:
				rumbo = Vector3(1.0, 0.0, 0.0)
			rumbo = rumbo.normalized()
	var mejor := sim.home_position
	var mejor_lejos := INF
	# Un punto por cada tramo del borde, y el que menos se desvíe del rumbo.
	var pasos := 48
	for i in range(pasos):
		for borde in range(4):
			var t := float(i) / float(pasos - 1)
			var punto := Vector3(t * lado, 0.0, 1.0)
			match borde:
				1: punto = Vector3(lado - 1.0, 0.0, t * fondo)
				2: punto = Vector3(t * lado, 0.0, fondo - 1.0)
				3: punto = Vector3(1.0, 0.0, t * fondo)
			punto.y = sim._terrain.get_height_at(punto)
			if not sim.marcha.alcanzable_desde_casa(punto):
				continue
			var hacia_alla := (punto - sim.home_position)
			hacia_alla.y = 0.0
			if hacia_alla.length() < 1.0:
				continue
			# Cuánto se desvía del rumbo: 0 es justo en esa dirección.
			var desvio := 1.0 - hacia_alla.normalized().dot(rumbo)
			if desvio < mejor_lejos:
				mejor_lejos = desvio
				mejor = punto
	return mejor


## Una tajada de tiempo de quien va andando hacia el borde. Lo llama
## [SettlementSim], que a los que ya están fuera no los simula.
func andar(person: Inhabitant, index: int, hours: float, delta: float) -> void:
	if not person.expedicion_andando:
		return
	var falta := Vector2(person.position.x - salida.x,
		person.position.z - salida.z).length()
	if falta <= LLEGADA:
		# Ya está fuera del valle: deja de andar y de verse.
		person.expedicion_andando = false
		sim._sacar_del_mapa(person, index)
		return
	# VA DESPEJANDO EL MAPA POR DONDE PASA, como cualquiera que anda: la
	# expedición cruza el valle entero hasta el borde y sería raro que ese
	# camino siguiera en niebla. Es la misma ojeada de
	# [SettlementSim._learn_from] —idempotente, no barre celdas dos veces desde
	# el mismo sitio— y no un segundo sistema de descubrir. Pedido por el
	# usuario el 2026-09-13.
	#
	# Va ANTES del paso y no después: la marcha puede dejarle en otro estado
	# —sin rumbo, esperando— y entonces la ojeada no se haría.
	sim._learn_from(person, delta)
	sim.marcha._tick_step(person, index, hours, delta)
	sim._pintar_a(person, index)


func mandar(cuantos: int, hacia: int) -> bool:
	if en_marcha():
		return false
	if cuantos < MINIMO_PARA_SALIR:
		return false

	var candidatos := _quienes_pueden_ir(cuantos)
	if candidatos.size() < cuantos:
		return false

	# EL AVITUALLAMIENTO VA PRIMERO, y si no hay, no se sale. La comida en
	# raciones -[Materia.KCAL_RACION], invariante 1 de SPECS §7-, y la tienda y
	# la hoguera con las constantes del vivac. Ver [hace_falta_para].
	#
	# Se mira TODO antes de sacar nada: `sacar_raciones` se lleva lo que haya
	# aunque no llegue, y una expedición que no sale no se come la despensa.
	var falta := lo_que_falta(cuantos)
	if not falta.is_empty():
		sim._note(Chronicle.Kind.PENURIA,
			"No hay con qué avituallar una expedición —falta %s—: se queda en casa."
				% ", ".join(falta), 0)
		return false
	var hace_falta := hace_falta_para(cuantos)
	sim.despensa.sacar_raciones(float(hace_falta["raciones"]))
	# La leña arde fuera; la piel es la tienda y vuelve con quien la llevó.
	sim.store.take(Materia.Kind.LENA, float(hace_falta["lena"]))
	pieles_prestadas = sim.store.take(Materia.Kind.PIEL, float(hace_falta["piel"]))

	fuera.clear()
	for person: Inhabitant in candidatos:
		person.expedicion_hasta = sim.day + JORNADAS_FUERA
		fuera.append(person.id)
	destino_id = hacia
	vuelve_el_dia = sim.day + JORNADAS_FUERA
	mandada_alguna_vez = true
	jornadas_persona += cuantos * JORNADAS_FUERA
	_echar_a_andar(hacia)

	sim._note(Chronicle.Kind.HALLAZGO,
		"Salen %d a ver qué hay más allá del valle. No vuelven en %d jornadas."
			% [cuantos, JORNADAS_FUERA], 2)
	return true


## Los pone a andar hacia el borde del valle. Se les ve irse.
func _echar_a_andar(hacia: int) -> void:
	salida = puerta_del_valle(hacia)
	for person: Inhabitant in sim.people:
		if not fuera.has(person.id):
			continue
		person.expedicion_andando = true
		person.state = Inhabitant.State.YENDO
		if sim.marcha != null:
			sim.marcha._send_to(person, salida)


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
## Si esta persona puede salir de expedición. **Una pregunta, un sitio**: lo
## usan la lista de la tarjeta, la salida a dedo y la comprobación de la vuelta.
func _puede_ir(person: Inhabitant) -> bool:
	if person.esta_de_expedicion(sim.day):
		return false
	if person.age_group != Inhabitant.Age.ADULTO:
		return false
	# Ni tocados: quien está con un percance se queda en el abrigo, y doce
	# jornadas fuera es lo contrario de descansar. Frente 12.
	return not person.esta_tocado()


func _quienes_pueden_ir(cuantos: int) -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		if out.size() >= cuantos:
			break
		if _puede_ir(person):
			out.append(person)
	return out


## Vuelven, y con lo que hayan visto.
func _volver() -> void:
	for person: Inhabitant in sim.people:
		if fuera.has(person.id):
			person.expedicion_hasta = -1
			person.expedicion_andando = false
			# VUELVEN POR DONDE SALIERON, y desde ahí andan solos: el reparto
			# de la mañana les da tajo y la marcha los trae. Hasta el
			# 2026-09-13 aparecían de golpe en el abrigo, que es la mitad del
			# viaje sin contar. Ver [salida].
			person.position = salida if salida != Vector3.ZERO else sim.home_position
			person.target = person.position
			person.route = PackedVector3Array()
			person.route_step = 0
			person.state = Inhabitant.State.VOLVIENDO
	fuera.clear()
	vueltas += 1
	# LAS PIELES VUELVEN. Una tienda no se gasta: se lleva y se trae, igual que
	# en la acampada de la cumbre. Ver [SettlementSim.VIVAC_PIEL].
	if pieles_prestadas > 0.0:
		sim.store.add(Materia.Kind.PIEL, pieles_prestadas)
		pieles_prestadas = 0.0

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


## Propone la decisión de la primavera. Lo llama [SettlementSim] el día citado
## del segundo mes. Es, además, **el botón que la expedición no tenía**: hasta
## la tanda 2, `mandar` sólo se podía llamar desde código.
##
## No sale tarjeta si ya hay una fuera, si no queda adónde ir o si no hay
## bastante gente que pueda: una decisión con una sola salida no es una
## decisión.
func proponer_la_salida() -> void:
	if en_marcha():
		return
	var hacia := destino_de_hoy()
	if hacia < 0:
		return
	var moment := Moment.new()
	moment.kind = Moment.Kind.EXPEDICION
	moment.title = "Es primavera: ¿se sale del valle?"
	moment.text = ("Hay %d sitios conocidos. Una expedición saldría hacia lo que "
		+ "haya al otro lado del valle, y podría volver con noticias —o con "
		+ "gente con la que tratar—.") % GameState.discovered.size()
	# QUIÉN VA LO ELIGE EL JUGADOR, en la propia tarjeta. Se marcan los primeros
	# que pueden ir para que decir que sí sea un clic, pero se pueden cambiar.
	# Ni niños ni tocados salen en la lista: ver [_puede_ir].
	for person: Inhabitant in sim.people:
		if _puede_ir(person):
			moment.candidatos.append(person.id)
			moment.nombres[person.id] = person.given_name
	moment.minimo_elegidos = MINIMO_PARA_SALIR
	for id: int in moment.candidatos:
		if moment.elegidos.size() >= MINIMO_PARA_SALIR:
			break
		moment.elegidos.append(id)
	# El coste depende de cuántos van, así que las opciones se rehacen cada vez
	# que se marca o se desmarca a alguien. Ver [Moment.marcar].
	moment.al_cambiar_la_eleccion = func() -> void: _opciones_de_la_salida(moment, hacia)
	_opciones_de_la_salida(moment, hacia)
	sim.raise_moment(moment)


## Manda a los que se han elegido en la tarjeta. Devuelve si han salido.
##
## `mandar` coge a los primeros que puedan; esto respeta la lista del jugador, y
## comprueba que cada uno siga pudiendo ir —entre que se levanta la tarjeta y se
## contesta pueden pasar cosas: el reloj está parado, pero la partida se puede
## haber guardado y vuelto a cargar—.
func mandar_a(quienes: Array[int], hacia: int) -> bool:
	if en_marcha() or quienes.size() < MINIMO_PARA_SALIR or hacia < 0:
		return false
	var pueden: Array[int] = []
	for person: Inhabitant in sim.people:
		if quienes.has(person.id) and _puede_ir(person):
			pueden.append(person.id)
	if pueden.size() < MINIMO_PARA_SALIR:
		return false
	var falta := lo_que_falta(pueden.size())
	if not falta.is_empty():
		sim._note(Chronicle.Kind.PENURIA,
			"No hay con qué avituallar una expedición —falta %s—: se queda en casa."
				% ", ".join(falta), 0)
		return false
	var hace_falta := hace_falta_para(pueden.size())
	sim.despensa.sacar_raciones(float(hace_falta["raciones"]))
	sim.store.take(Materia.Kind.LENA, float(hace_falta["lena"]))
	pieles_prestadas = sim.store.take(Materia.Kind.PIEL, float(hace_falta["piel"]))
	fuera.clear()
	for person: Inhabitant in sim.people:
		if pueden.has(person.id):
			person.expedicion_hasta = sim.day + JORNADAS_FUERA
			fuera.append(person.id)
	destino_id = hacia
	vuelve_el_dia = sim.day + JORNADAS_FUERA
	mandada_alguna_vez = true
	jornadas_persona += pueden.size() * JORNADAS_FUERA
	_echar_a_andar(hacia)
	sim._note(Chronicle.Kind.HALLAZGO,
		"Salen %d a ver qué hay más allá del valle. No vuelven en %d jornadas."
			% [pueden.size(), JORNADAS_FUERA], 2)
	return true


## Las opciones de la tarjeta, rehechas con los que están marcados ahora: lo que
## cuesta una expedición depende de cuántos van.
func _opciones_de_la_salida(moment: Moment, hacia: int) -> void:
	var cuantos := maxi(moment.elegidos.size(), MINIMO_PARA_SALIR)
	var hace_falta := hace_falta_para(cuantos)
	var falta := lo_que_falta(cuantos)
	var bloqueo := ""
	if not moment.hay_bastantes():
		bloqueo = "hacen falta %d" % MINIMO_PARA_SALIR
	elif not falta.is_empty():
		bloqueo = "falta " + ", ".join(falta)
	moment.options = [
		Moment.opcion("Este año no",
			"Nadie sale. No cuesta nada y no se sabe nada nuevo.",
			func() -> void: pass),
		Moment.opcion("Mandarla",
			("Salen %d %d jornadas con %.0f raciones y %.0f de leña, que no "
				+ "vuelven, y %.0f pieles de tienda, que sí.") % [cuantos,
					JORNADAS_FUERA, float(hace_falta["raciones"]),
					float(hace_falta["lena"]), float(hace_falta["piel"])],
			func() -> void: mandar_a(moment.elegidos, hacia),
			{"jornadas": cuantos * JORNADAS_FUERA,
				"despensa": -float(hace_falta["raciones"])},
			bloqueo),
	]
