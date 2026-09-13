class_name Exploracion
extends RefCounted
## Explorar una cueva: la orden, lo que cuesta, y lo que se sabe de cada una.
##
## Frente 22 de EPOCA_01 §10.1, tanda 4. Hasta el 2026-09-13 el botón «explorar
## el interior» de la ventana del abrigo revelaba conocimiento alrededor y
## escribía una línea por consola: no costaba nada y no decidía nada.
##
## Lo que pidió el usuario: **una lámpara y grasa**, y **alguien del hogar**, que
## pasa **una jornada entera** dentro. Sin lámpara o sin grasa no se empieza, y la
## orden dice qué falta. Al salir se sabe si la cueva tiene **zona pintable**.
##
## Lo que pasa DENTRO —las situaciones y sus decisiones— no está aquí: es el
## repertorio, que va aparte.

## Grasa que se quema en una jornada de exploración. Una unidad: es la ración de
## una lámpara ardiendo un día entero, y viene de la decisión de que la cueva
## cueste algo que también sirve para comer. No es una medida.
const GRASA_POR_JORNADA := 1.0

## De cada cuántas cuevas tiene una zona donde se pueda pintar. Decisión del
## usuario del 2026-09-13: «no todas las cuevas se pueden pintar; alrededor de
## una de cada tres». La de la banda, siempre.
const UNA_DE_CADA := 3

var sim: SettlementSim

## Cuál es la cueva de la banda, que siempre sale pintable. La pone quien monta
## el mapa, que es el único que sabe en cuál se vive.
var cueva_de_la_banda: int = -1

## Lo que se sabe de cada cueva: `id -> {"explorada": bool, "pintable": bool}`.
var _sabido: Dictionary = {}

## Quién está dentro ahora mismo: `id de cueva -> id de persona`. Dura una
## jornada; lo cierra [nueva_jornada].
var _dentro: Dictionary = {}

## Lo que falta por pasar en cada visita en curso: `id de cueva -> [ids]`.
var _pendiente: Dictionary = {}

## Lo que ya ha pasado en cada visita en curso, para no repetirlo: una rama puede
## llevar a una situación que la visita tenía sorteada para después.
var _vistas: Dictionary = {}

## Con qué situación abrió la última visita, para que la siguiente cueva no abra
## igual. Ver [Repertorio.visita_de].
var _ultima_apertura: String = ""

## Días de herida de una opción que hiere, y de una que sale mal en peligro.
## Decisión: una herida de cueva es un golpe o un corte, de los que tienen a
## alguien unos días sin rendir; la de peligro, una caída de verdad.
const DIAS_DE_HERIDA := 3
const DIAS_DE_HERIDA_GRAVE := 8

## Cómo sale una opción de PELIGRO, en quintos: uno mata, dos hieren de
## gravedad y dos se salen bien. Decisión del plan, para que «hay riesgo de
## verdad» sea verdad sin que explorar sea un suicidio.
const QUINTOS_QUE_MATAN := 1
const QUINTOS_QUE_HIEREN := 2


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Qué falta para poder explorar esta cueva, dicho para la orden. Vacío si se
## puede. El orden importa: se dice primero lo que el jugador puede arreglar.
func lo_que_falta(cueva: int) -> String:
	if explorada(cueva):
		return "ya está explorada"
	if _dentro.has(cueva):
		return "hay alguien dentro"
	# LA LÁMPARA ES UN ÚTIL, el mismo que pide la pintura —ver
	# [Pinturas.painting_blocked_by]—, no una obra: una pregunta, un sitio.
	if sim.toolkit == null or sim.toolkit.count(Tool.Kind.LAMPARA) <= 0:
		return "hace falta una lámpara de grasa"
	if sim.store.amount(Materia.Kind.GRASA) < GRASA_POR_JORNADA:
		return "hace falta grasa para la lámpara"
	if _quien_del_hogar() == null:
		return "hace falta alguien del hogar"
	return ""


func puede_explorar(cueva: int) -> bool:
	return lo_que_falta(cueva).is_empty()


## Manda explorar: cobra la grasa y mete a alguien del hogar una jornada. Dice
## si sale la orden.
func mandar(cueva: int) -> bool:
	if not puede_explorar(cueva):
		return false
	var quien := _quien_del_hogar()
	if quien == null:
		return false
	sim.store.take(Materia.Kind.GRASA, GRASA_POR_JORNADA)
	_dentro[cueva] = quien.id

	# Lo que va a pasar dentro: dos o tres situaciones del repertorio, y la
	# primera se pregunta ya. Ver [Repertorio].
	var visita := Repertorio.visita_de(sim.game_seed, cueva, _ultima_apertura)
	_ultima_apertura = String(visita[0])
	_pendiente[cueva] = visita.slice(1)
	_vistas[cueva] = {}
	_preguntar(cueva, String(visita[0]))
	return true


## Enseña una situación como decisión. Cada opción, al elegirse, aplica lo suyo
## y sigue: por su rama si la tiene, o con la siguiente de la visita.
func _preguntar(cueva: int, situacion: String) -> void:
	var ficha: Dictionary = Repertorio.SITUACIONES.get(situacion, {})
	if ficha.is_empty():
		return
	if not _vistas.has(cueva):
		_vistas[cueva] = {}
	(_vistas[cueva] as Dictionary)[situacion] = true
	var quien := _persona(quien_esta_dentro(cueva))
	var momento := Moment.new()
	momento.kind = Moment.Kind.CUEVA
	momento.title = "Dentro de la cueva"
	momento.text = String(ficha["texto"])
	momento.who = quien
	var opciones: Array = ficha["opciones"]
	for i in range(opciones.size()):
		var opcion: Dictionary = opciones[i]
		var cual := i
		momento.options.append(Moment.opcion(String(opcion["texto"]),
			_aviso(opcion["efecto"] as Repertorio.Efecto),
			func() -> void: decidir(cueva, situacion, cual)))
	sim.raise_moment(momento)


## Lo que se le dice al jugador de una opción antes de elegirla. No se le cuenta
## el desenlace —eso sería quitarle la decisión—, sólo el aire que tiene.
static func _aviso(efecto: Repertorio.Efecto) -> String:
	match efecto:
		Repertorio.Efecto.PELIGRO:
			return "Puede salir muy mal."
		Repertorio.Efecto.HERIDA:
			return "Alguien puede hacerse daño."
		Repertorio.Efecto.HALLAZGO:
			return "Puede traer algo."
	return ""


## Aplica la opción elegida y sigue con la visita.
func decidir(cueva: int, situacion: String, opcion: int) -> void:
	var quien := _persona(quien_esta_dentro(cueva))
	if quien == null:
		return
	var sigue := _consecuencia(cueva, situacion, opcion, quien)
	if not sigue:
		_pendiente.erase(cueva)
		return

	# Por la rama si la hay y no ha pasado ya; si no, lo siguiente sorteado que
	# no haya pasado. DENTRO DE UNA CUEVA NO SE REPITE NINGUNA: la sonda de
	# variedad pilló dos cuevas en las que una rama llevaba a una situación que
	# la visita ya tenía para después.
	var vistas: Dictionary = _vistas.get(cueva, {})
	var siguiente := Repertorio.lleva_a(situacion, opcion)
	if vistas.has(siguiente):
		siguiente = ""
	var quedan: Array = _pendiente.get(cueva, [])
	while siguiente.is_empty() and not quedan.is_empty():
		var cual := String(quedan.pop_front())
		if not vistas.has(cual):
			siguiente = cual
	_pendiente[cueva] = quedan
	if siguiente.is_empty():
		_pendiente.erase(cueva)
		_vistas.erase(cueva)
		return
	_preguntar(cueva, siguiente)


## Lo que desata una opción. Devuelve si la visita sigue: un muerto la acaba.
##
## El azar es PROPIO y sale de la semilla, la cueva, la situación y la opción:
## la misma decisión en la misma cueva sale igual si se vuelve a jugar, y no
## consume el `_rng` de la simulación (SPECS §7).
func _consecuencia(cueva: int, situacion: String, opcion: int,
		quien: Inhabitant) -> bool:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([sim.game_seed, cueva, situacion, opcion])
	match Repertorio.efecto_de(situacion, opcion):
		Repertorio.Efecto.HALLAZGO:
			var que: Materia.Kind = [Materia.Kind.OCRE, Materia.Kind.SILEX,
				Materia.Kind.ASTA][azar.randi() % 3]
			sim.store.add(que, 1.0)
			sim._note(Chronicle.Kind.HALLAZGO, "%s sale de la cueva con %s."
				% [quien.given_name, Materia.material_name(que).to_lower()], 1)
		Repertorio.Efecto.SUSTO:
			sim._note(Chronicle.Kind.GENTE,
				"%s sale de la cueva sin querer contar lo que ha visto."
				% quien.given_name, 1)
		Repertorio.Efecto.HERIDA:
			quien.hurt_days = maxi(quien.hurt_days, DIAS_DE_HERIDA)
			sim._note(Chronicle.Kind.PENURIA,
				"%s se hace daño dentro de la cueva." % quien.given_name, 2)
		Repertorio.Efecto.PELIGRO:
			var quinto := azar.randi() % 5
			if quinto < QUINTOS_QUE_MATAN:
				_dentro.erase(cueva)
				sim._person_dies(quien,
					"%s no sale de la cueva." % quien.given_name)
				return false
			if quinto < QUINTOS_QUE_MATAN + QUINTOS_QUE_HIEREN:
				quien.hurt_days = maxi(quien.hurt_days, DIAS_DE_HERIDA_GRAVE)
				sim._note(Chronicle.Kind.PENURIA,
					"%s sale de la cueva malherido." % quien.given_name, 2)
	return true


## Si alguien está ahora dentro de esa cueva.
func hay_alguien_dentro(cueva: int) -> bool:
	return _dentro.has(cueva)


## Quién está dentro de una cueva, o -1.
func quien_esta_dentro(cueva: int) -> int:
	return int(_dentro.get(cueva, -1))


## Cierra las exploraciones del día: la jornada entera se ha ido dentro.
##
## Va al acabar el día y ANTES de repartir la práctica, para que la jornada
## cuente como oficio de hogar: es trabajo del hogar, aunque se haga a oscuras.
func nueva_jornada() -> void:
	for cueva: int in _dentro.keys():
		var quien := _persona(int(_dentro[cueva]))
		if quien != null:
			quien.oficio_de_hoy = Profession.Job.HOGAR
		_sabido[cueva] = {
			"explorada": true,
			"pintable": hay_zona_pintable(sim.game_seed, cueva)
				or cueva == cueva_de_la_banda,
		}
	_dentro.clear()


## Si esta cueva ya se ha recorrido a fondo.
func explorada(cueva: int) -> bool:
	return bool((_sabido.get(cueva, {}) as Dictionary).get("explorada", false))


## Si tiene pared donde pintar. **Sólo se sabe explorándola**: antes de eso la
## pregunta no tiene respuesta y devuelve `false`.
func pintable(cueva: int) -> bool:
	return bool((_sabido.get(cueva, {}) as Dictionary).get("pintable", false))


## Si una cueva tiene zona pintable, por la semilla de la partida. Una de cada
## [UNA_DE_CADA], y siempre la misma cueva en la misma partida.
##
## Estático y con su propio azar: no consume el `_rng` de la simulación, que es
## la regla de SPECS §7 —lo que decide el mundo no puede depender de cuántas
## veces se haya preguntado—.
static func hay_zona_pintable(semilla: int, cueva: int) -> bool:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([semilla, cueva, "pintable"])
	return azar.randi() % UNA_DE_CADA == 0


## Alguien del hogar que no esté ya dentro de otra cueva.
func _quien_del_hogar() -> Inhabitant:
	for person: Inhabitant in sim.people:
		if person.job != Profession.Job.HOGAR:
			continue
		if _dentro.values().has(person.id):
			continue
		return person
	return null


func _persona(id: int) -> Inhabitant:
	for person: Inhabitant in sim.people:
		if person.id == id:
			return person
	return null
