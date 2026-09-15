class_name Traslado
extends RefCounted
## Mudar el campamento a otra cueva descubierta del mapa.
##
## Lo pidió el usuario el 2026-09-13: «construye el traslado de campamento a una
## cueva descubierta; la banda viajará físicamente hasta allí y se asentará, sólo
## si pueden llegar». Hasta entonces el botón «trasladar el campamento aquí»
## existía y sólo escribía una línea por consola.
##
## Tres decisiones suyas del mismo día, que es lo que cuesta mudarse:
##
## - **Se llevan lo que puedan cargar.** Cada cual hasta su capacidad; lo que no
##   cabe se queda en la cueva vieja, y se recupera si la banda vuelve allí.
## - **Las obras se quedan.** Hogar, secadero, paraviento y lavadero son del
##   sitio: en la cueva nueva hay que levantarlos otra vez. Si se vuelve a la
##   vieja, siguen allí.
## - **Viajan todos juntos y dejan de trabajar.** La banda entera anda hasta la
##   cueva nueva y se asienta cuando han llegado todos.

## Cerca de cuánto del sitio de llegada cuenta como llegado, en metros. El mismo
## radio que usa la expedición para dar por alcanzado el borde del valle: ver
## [Expedicion.LLEGADA].
const LLEGADA := Expedicion.LLEGADA

## Y hasta dónde vale llegar CON EL CAMINO AGOTADO: dos celdas de rejilla.
##
## La campa de una cueva está al pie de su ladera, y la celda de cuarenta metros
## de una ladera sale cerrada por pendiente: el camino deja a la gente en la
## celda abierta más cercana. Medido con `TrasladoProbe` el 2026-09-13: la banda
## entera se paraba **a 51–52 m** de la campa nueva con la ruta gastada, y con
## sólo [LLEGADA] no llegaba nunca —se asentaba por la red de seguridad—. Es lo
## mismo que pasa con la cueva de casa, y por eso a la de casa se le abre la
## puerta en la rejilla a la fuerza ([Navgrid.open_around_home]); al asentarse,
## se le abre también a la nueva.
const LLEGADA_CON_EL_CAMINO_ACABADO := Navgrid.CELL * 2.0

## Cuánto se espera a los que no llegan, en jornadas, antes de asentarse sin
## ellos... y con ellos: se les pone en la campa. **Es una red de seguridad, no
## una regla**: la orden sólo sale si se llega, así que en una partida sana no
## salta nunca; si salta, lo dice la crónica. Decisión.
const JORNADAS_DE_ESPERA := 2

## Cuánto se reparte la gente al llegar por la campa de la cueva nueva, en
## metros, para que no aparezcan uno encima de otro.
const REPARTO_AL_LLEGAR := 3.0

var sim: SettlementSim

## A qué cueva va la banda, y dónde queda su boca, su interior y su campa. -1 si
## no hay traslado en marcha.
var destino: int = -1
var _boca: Vector3 = Vector3.ZERO
var _dentro: Vector3 = Vector3.ZERO
var _campa: Vector3 = Vector3.ZERO

## El día en que salió la banda, para la red de seguridad.
var _salida_el_dia: int = -1

## Lo que se quedó en cada cueva al irse: `id de cueva -> {material: cuánto}`.
var dejado: Dictionary = {}

## Las obras que tiene cada cueva: `id de cueva -> {Kind: true}`. Se guardan al
## irse y se recuperan al volver.
var obras_de: Dictionary = {}

## Cuántas veces se ha trasladado la banda, para la crónica y la sonda.
var traslados: int = 0


func _init(settlement: SettlementSim) -> void:
	sim = settlement


func en_marcha() -> bool:
	return destino >= 0


## Por qué no se puede mudar la banda a esa cueva, dicho para el botón. Vacío si
## se puede.
func lo_que_falta(cueva: int, campa: Vector3) -> String:
	if en_marcha():
		return "la banda ya se está mudando"
	if cueva == sim.exploracion.cueva_de_la_banda:
		return "la banda ya vive aquí"
	if sim.expedicion != null and sim.expedicion.en_marcha():
		return "hay gente de expedición: no se muda la banda sin ellos"
	if sim.people.is_empty():
		return "no queda nadie"
	if not se_llega(campa):
		return "no se llega andando desde la cueva de ahora"
	return ""


## Si la banda puede llegar andando a ese punto desde casa. La misma rejilla de
## tránsito que la marcha —[Navgrid.connected], que va a la celda abierta más
## cercana—; la regla del rodeo no se aplica, porque mudarse lejos es justo lo
## que se quiere poder hacer.
func se_llega(punto: Vector3) -> bool:
	var grid := sim.navgrid()
	if grid == null or not grid.is_ready():
		return false
	return grid.connected(sim.home_position, punto)


## Manda mudarse: carga a cada cual, deja el resto en la cueva vieja, y echa a
## andar a la banda entera. Dice si sale la orden.
func mandar(cueva: int, boca: Vector3, dentro: Vector3, campa: Vector3) -> bool:
	if not lo_que_falta(cueva, campa).is_empty():
		return false
	destino = cueva
	_boca = boca
	_dentro = dentro
	_campa = campa
	_salida_el_dia = sim.day

	var vieja := sim.exploracion.cueva_de_la_banda
	_cargar(vieja)
	obras_de[vieja] = sim.camp_built.duplicate()

	for i in range(sim.people.size()):
		var person: Inhabitant = sim.people[i]
		person.state = Inhabitant.State.YENDO
		sim.marcha._send_to(person, _sitio_de(person))
	sim._note(Chronicle.Kind.TIERRA,
		"La banda recoge lo que puede cargar y se pone en marcha hacia otra cueva.", 2)
	return true


## Reparte el almacén en las espaldas de la banda, hasta lo que cada cual pueda
## cargar, y deja el resto en la cueva vieja.
##
## Primero la comida, de la que más alimenta por kilo a la que menos —en un
## traslado lo que no se puede dejar atrás es de qué comer—, y después lo demás
## por lo que vale en el trueque, que es la mejor medida que hay de lo que cuesta
## volver a juntarlo. Decisión.
func _cargar(vieja: int) -> void:
	var orden := cosas_en_orden_de_carga(sim.store)
	var hueco: Dictionary = {}
	for person: Inhabitant in sim.people:
		hueco[person.id] = maxf(person.carry_limit_kg() - person.load_kg(), 0.0)

	for kind: int in orden:
		var material := kind as Materia.Kind
		var por_unidad := maxf(Materia.kg_per_unit(material), 0.001)
		for person: Inhabitant in sim.people:
			var hay := sim.store.amount(material)
			if hay <= 0.0:
				break
			var cabe := floorf(float(hueco[person.id]) / por_unidad)
			var lleva := minf(hay, cabe)
			if lleva <= 0.0:
				continue
			sim.store.take(material, lleva)
			person.add_load(material, lleva)
			hueco[person.id] = float(hueco[person.id]) - lleva * por_unidad

	# Lo que no cabe, se queda. Se suma a lo que ya hubiera de otra vez.
	var queda: Dictionary = dejado.get(vieja, {})
	for kind: int in Materia.Kind.values():
		var resto := sim.store.amount(kind as Materia.Kind)
		if resto <= 0.0:
			continue
		sim.store.take(kind as Materia.Kind, resto)
		queda[kind] = float(queda.get(kind, 0.0)) + resto
	if not queda.is_empty():
		dejado[vieja] = queda


## Lo que hay en el almacén, en el orden en que se carga. Ver [_cargar].
static func cosas_en_orden_de_carga(store: Storehouse) -> Array[int]:
	var comida: Array[int] = []
	var resto: Array[int] = []
	for kind: int in Materia.Kind.values():
		if store.amount(kind as Materia.Kind) <= 0.0:
			continue
		if Materia.is_food(kind as Materia.Kind):
			comida.append(kind)
		else:
			resto.append(kind)
	comida.sort_custom(func(a: int, b: int) -> bool:
		return Materia.kcal(a as Materia.Kind) / maxf(Materia.kg_per_unit(a as Materia.Kind), 0.001) \
			> Materia.kcal(b as Materia.Kind) / maxf(Materia.kg_per_unit(b as Materia.Kind), 0.001))
	resto.sort_custom(func(a: int, b: int) -> bool:
		return Intercambio.precio(a as Materia.Kind) > Intercambio.precio(b as Materia.Kind))
	comida.append_array(resto)
	return comida


## Cada tick, mientras dura el traslado: todos andan hacia la campa nueva, y
## cuando han llegado todos, la banda se asienta.
func andar(person: Inhabitant, index: int, hours: float, delta: float) -> void:
	if not en_marcha():
		return
	sim._learn_from(person, delta)
	if not ha_llegado(person):
		if person.state != Inhabitant.State.YENDO:
			person.state = Inhabitant.State.YENDO
			sim.marcha._send_to(person, _sitio_de(person))
		sim.marcha._tick_step(person, index, hours, delta)
	sim._pintar_a(person, index)


## Se llama al cerrar cada paso: si han llegado todos —o se acabó la espera—, la
## banda se asienta.
func revisar() -> void:
	if not en_marcha():
		return
	var todos := true
	for person: Inhabitant in sim.people:
		if not ha_llegado(person):
			todos = false
			break
	if todos:
		_asentarse()
		return
	if sim.day - _salida_el_dia >= JORNADAS_DE_ESPERA:
		sim._note(Chronicle.Kind.PENURIA, "Parte de la banda no encuentra el "
			+ "camino a la cueva nueva, y los demás salen a buscarlos.", 2)
		for person: Inhabitant in sim.people:
			person.position = _sitio_de(person)
		_asentarse()


func ha_llegado(person: Inhabitant) -> bool:
	var falta := Vector2(person.position.x - _campa.x, person.position.z - _campa.z).length()
	if falta <= LLEGADA:
		return true
	var camino_acabado := person.route.is_empty() or person.route_step >= person.route.size()
	return camino_acabado and falta <= LLEGADA_CON_EL_CAMINO_ACABADO


## Dónde se pone cada cual en la campa nueva: repartido y estable por id.
func _sitio_de(person: Inhabitant) -> Vector3:
	var angulo := TAU * fmod(float(person.id) * 0.618, 1.0)
	return _campa + Vector3(cos(angulo), 0.0, sin(angulo)) * REPARTO_AL_LLEGAR


## La banda se asienta en la cueva nueva.
func _asentarse() -> void:
	var nueva := destino
	destino = -1
	traslados += 1

	# Lo que traían, al almacén; y lo que se dejó aquí otra vez, si se vuelve.
	for person: Inhabitant in sim.people:
		for kind: int in person.load.keys():
			sim.store.add(kind as Materia.Kind, float(person.load[kind]))
		person.load.clear()
		person.carrying = 0.0
		person.state = Inhabitant.State.OCIOSO
		# Los últimos pasos, de la celda abierta a la campa: ver
		# [LLEGADA_CON_EL_CAMINO_ACABADO]. Son unas decenas de metros al pie de
		# la cueva, y la puerta se abre justo abajo.
		person.position = _sitio_de(person)
		person.route.clear()
		person.route_step = 0
	if dejado.has(nueva):
		for kind: int in (dejado[nueva] as Dictionary):
			sim.store.add(kind as Materia.Kind, float(dejado[nueva][kind]))
		dejado.erase(nueva)

	# Las obras son del sitio: las de aquí, si las había; si no, ninguna.
	sim.camp_built = (obras_de.get(nueva, {}) as Dictionary).duplicate()
	sim.hearth_lit = false
	sim._hearth_tended = false
	sim.camp_queue = -1
	sim.camp_progress = 0.0
	sim._camp_paid = false

	# La casa, aquí. Y todo lo que se medía desde la casa vieja, a rehacer: los
	# metros hasta cada celda y los caminos ya trazados.
	sim.home_position = _boca
	sim.home_inside = _dentro
	sim.home_forecourt = _campa
	# Lo pintado sin cueva es de la VIEJA: se fija antes de cambiar cuál es la de la
	# banda, o saldría en la pared nueva. Ver [Pinturas.fijar_lo_pintado_sin_cueva].
	sim.pinturas.fijar_lo_pintado_sin_cueva()
	sim.exploracion.cueva_de_la_banda = nueva
	sim.marcha.forget_routes()
	sim.marcha._mapa_de = null
	var grid := sim.navgrid()
	if grid != null and grid.is_ready():
		grid.open_around_home(sim.home_position, sim._terrain)

	sim._note(Chronicle.Kind.TIERRA, "La banda se asienta en su cueva nueva. "
		+ "Todo lo que era del sitio de antes —el hogar, el secadero— hay que "
		+ "levantarlo otra vez.", 2)
	sim.campamento_trasladado.emit(nueva)
