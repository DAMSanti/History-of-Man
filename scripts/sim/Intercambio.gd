class_name Intercambio
extends RefCounted
## Trueque con la gente de ahí fuera: se decide, se paga, y se recuerda.
##
## El primer peldaño de la escalera del comercio de docs/SISTEMAS.md §5. Era un
## envío automático —6 de fruto seco por 3 de sílex, un 55 % fijo, una vez por
## estación— que ocurría **sin que el jugador decidiera nada ni se enterara**.
## Ahora son las cuatro decisiones de la spec (EPOCA_01 §10.1, tanda 2, frente
## 6): con quién, qué se ofrece y cuánto, qué se pide, y si se va.
##
## ## Cómo caben cuatro decisiones en una tarjeta
##
## Combinadas darían veintisiete opciones, y eso no es una decisión: es un
## formulario. Se ofrece **un puñado de tratos con sentido**, siempre con la
## contraparte **de mejor trato** —así «con quién» lo decide la memoria que has
## ido dejando, no un desplegable—, y **con el coste escrito en cada opción**,
## que es lo que el frente 8 pide antes de elegir. Es una simplificación y está
## dicha: si el juego pide elegir contraparte a mano, se añade entonces.

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Qué se pide a cambio.
enum Pide { SILEX, CONCHA, GENTE }

## Cómo se ofrece.
enum Como { REGATEAR, JUSTO, GENEROSO }


## Lo justo que se ofrece por un trato, en unidades de lo que se da.
##
## Seis, que es lo que se daba antes por el sílex: la cifra se hereda del
## trueque automático, no se elige ahora. Lo que cambia es que ahora se puede
## dar más o menos.
const LO_JUSTO := 6.0

## Cuánto de lo justo se ofrece según cómo.
const CUANTO_SE_OFRECE := {
	Como.REGATEAR: 0.5,
	Como.JUSTO: 1.0,
	Como.GENEROSO: 1.5,
}

## Cuánto se mueve el trato con esa gente según cómo se ofrezca.
##
## **La memoria de la contraparte**, que es lo que la spec pide: el 55 % fijo
## deja de serlo porque ellos recuerdan. Se mueve en cada intento, salga bien o
## mal —si regateas y no tienen nada que darte, igualmente se acuerdan de que
## regateaste—. La forma es la de `ElLobo.trato`, que ya funciona así. Las
## cifras son decisiones, no medidas, y se ajustan con la partida delante.
const CUANTO_MUEVE_EL_TRATO := {
	Como.REGATEAR: -8.0,
	Como.JUSTO: 2.0,
	Como.GENEROSO: 10.0,
}

## Lo que llega de lo que se pide, cuando sale bien.
const LLEGA_SILEX := 3.0
const LLEGA_CONCHA := 2.0

## Cuántas jornadas está fuera quien va a tratar.
##
## Cuatro: ir y volver a otra comarca sin quedarse a vivir. **Decisión.** Esas
## jornadas **no se recolectan**, que es el cuarto criterio del frente.
const JORNADAS_DE_TRUEQUE := 4

## La probabilidad de que salga bien con un trato de cero.
##
## 0,55, que es la del trueque automático de antes: se hereda como punto de
## partida. El trato la sube o la baja desde ahí.
const PROBABILIDAD_DE_PARTIDA := 0.55

## Si ha salido bien alguna vez. El primero es un hito en la crónica.
var logrado_alguna_vez := false

## Lo que la sonda cuenta.
var intentados := 0
var consumados := 0


## La probabilidad de que salga bien con esa gente, según lo que recuerdan.
##
## Con trato 0 es la de partida; cada 100 de trato suma o resta 0,5, con topes
## para que nunca sea seguro ni imposible. Decisión de forma, no medida.
func probabilidad_con(id: int) -> float:
	var trato := sim.contacto.trato_con(id) if sim.contacto != null else 0.0
	return clampf(PROBABILIDAD_DE_PARTIDA + trato / 200.0, 0.05, 0.95)


## Con quién se trata: la gente conocida con mejor trato, y a igualdad, la de
## id más bajo, para que la elección no dependa del orden de un diccionario.
## -1 si no se conoce a nadie.
func con_quien() -> int:
	if sim.contacto == null:
		return -1
	var mejor := -1
	var mejor_trato := -INF
	var ids: Array = sim.contacto.trato.keys()
	ids.sort()
	for id: int in ids:
		var t := sim.contacto.trato_con(id)
		if t > mejor_trato:
			mejor_trato = t
			mejor = id
	return mejor


## Se trata. Devuelve si ha salido bien.
##
## Cuatro cosas pasan siempre que se va, salga como salga: alguien sale del
## mapa esas jornadas, se cuenta el intento, y el trato con esa gente se mueve
## según cómo se ofreció. Y dos pasan sólo si sale bien: se entrega lo ofrecido
## y llega lo pedido.
func tratar(con: int, ofrece: Materia.Kind, como: Como, pide: Pide) -> bool:
	if sim.contacto == null or not sim.contacto.se_conocen(con):
		return false
	var cuanto := LO_JUSTO * float(CUANTO_SE_OFRECE[como])
	if sim.store.amount(ofrece) < cuanto:
		sim._note(Chronicle.Kind.TRUEQUE,
			"No hay bastante que ofrecer para ir a tratar.", 0)
		return false

	var quien := _quien_va()
	if quien == null:
		return false

	# LA SUERTE SE LEE CON EL TRATO DE ANTES de este intento, y por eso va
	# antes de moverlo. Si se moviera primero, ser generoso compraría la suerte
	# del propio trato en que lo eres, y regatear no tendría riesgo inmediato:
	# lo que recuerdan es lo de las veces anteriores.
	var probabilidad := probabilidad_con(con)

	# IR CUESTA, y cuesta aunque salga mal. Se usa la misma marca que la
	# expedición: está fuera del mapa, no trabaja ni se le simula.
	quien.expedicion_hasta = sim.day + JORNADAS_DE_TRUEQUE
	intentados += 1
	sim.contacto.mover_el_trato(con, float(CUANTO_MUEVE_EL_TRATO[como]))

	if sim._rng.randf() > probabilidad:
		sim._note(Chronicle.Kind.TRUEQUE,
			"%s vuelve de tratar con las manos vacías: esta vez no había trato."
				% quien.given_name, 0)
		return false

	sim.store.take(ofrece, cuanto)
	_llega(pide)
	consumados += 1

	var peso := 1
	if not logrado_alguna_vez:
		logrado_alguna_vez = true
		peso = 2
	sim._note(Chronicle.Kind.TRUEQUE, _linea_del_trato(pide, quien), peso)
	return true


## Lo que llega de lo que se pidió.
func _llega(pide: Pide) -> void:
	match pide:
		Pide.SILEX:
			sim.store.add(Materia.Kind.SILEX, LLEGA_SILEX)
		Pide.CONCHA:
			sim.store.add(Materia.Kind.CONCHA, LLEGA_CONCHA)
		Pide.GENTE:
			# Alguien viene a vivir con la banda. Así funcionaban las redes
			# paleolíticas de verdad: se movía gente, no sólo cosas.
			var nuevo := Inhabitant.create(sim.relevo.id_libre(),
				sim.home_position, sim._rng)
			nuevo.position = sim.home_position
			sim.people.append(nuevo)


func _linea_del_trato(pide: Pide, quien: Inhabitant) -> String:
	match pide:
		Pide.CONCHA:
			return ("%s vuelve con conchas de un mar que no es el nuestro. "
				+ "Alguien, lejos, las ha cogido en su playa.") % quien.given_name
		Pide.GENTE:
			return ("%s no vuelve solo: con la banda viene a vivir alguien de "
				+ "la otra gente.") % quien.given_name
		_:
			return "%s vuelve con sílex de la otra gente." % quien.given_name


## Quién va a tratar: el primer adulto que esté en casa.
func _quien_va() -> Inhabitant:
	for person: Inhabitant in sim.people:
		if person.age_group != Inhabitant.Age.ADULTO:
			continue
		if person.esta_de_expedicion(sim.day):
			continue
		return person
	return null


## Propone un trueque, si se conoce a alguien. Lo llama [SettlementSim] al
## empezar cada estación.
##
## **Ya no trata: pregunta.** La primera opción es **no ir**, y es deliberado
## por dos motivos. El primero, que no decidir no puede costar nada. Y el
## segundo, práctico: las sondas contestan los momentos eligiendo la primera
## opción, y si ésa fuera tratar, «en un año sin que el jugador decida nada,
## cero intercambios» —el primer criterio del frente— haría tratos él solo.
func proponer_el_trato() -> void:
	var con := con_quien()
	if con < 0:
		return
	var moment := Moment.new()
	moment.kind = Moment.Kind.TRUEQUE
	moment.title = "Se puede ir a tratar"
	moment.text = ("La otra gente está a %d jornadas de ida y vuelta. "
		+ "Con lo que recuerdan de vosotros, sale bien %d de cada diez veces.") % [
			JORNADAS_DE_TRUEQUE, int(round(probabilidad_con(con) * 10.0))]
	moment.options = [
		Moment.opcion("Dejarlo esta estación",
			"No va nadie. No cuesta nada y no llega nada.",
			func() -> void: pass),
		Moment.opcion("Sílex por fruto seco, lo justo",
			"Cuesta %d de fruto seco y %d jornadas de alguien." % [
				int(LO_JUSTO), JORNADAS_DE_TRUEQUE],
			func() -> void: tratar(con, Materia.Kind.FRUTO_SECO, Como.JUSTO, Pide.SILEX),
			_cuesta(Materia.Kind.FRUTO_SECO, Como.JUSTO)),
		Moment.opcion("Sílex, siendo generosos",
			"Cuesta %d de fruto seco. Os lo tendrán en cuenta." % int(LO_JUSTO * 1.5),
			func() -> void: tratar(con, Materia.Kind.FRUTO_SECO, Como.GENEROSO, Pide.SILEX),
			_cuesta(Materia.Kind.FRUTO_SECO, Como.GENEROSO)),
		Moment.opcion("Sílex, regateando",
			"Cuesta sólo %d de fruto seco. También os lo tendrán en cuenta." % int(LO_JUSTO * 0.5),
			func() -> void: tratar(con, Materia.Kind.FRUTO_SECO, Como.REGATEAR, Pide.SILEX),
			_cuesta(Materia.Kind.FRUTO_SECO, Como.REGATEAR)),
		Moment.opcion("Concha, por carne seca",
			"Cuesta %d de carne seca: la concha de un mar lejano." % int(LO_JUSTO),
			func() -> void: tratar(con, Materia.Kind.CARNE_SECA, Como.JUSTO, Pide.CONCHA),
			_cuesta(Materia.Kind.CARNE_SECA, Como.JUSTO)),
		Moment.opcion("Que venga alguien a vivir, por piel",
			"Cuesta %d de piel, y siendo generosos: se pide mucho." % int(LO_JUSTO * 1.5),
			func() -> void: tratar(con, Materia.Kind.PIEL, Como.GENEROSO, Pide.GENTE),
			_cuesta(Materia.Kind.PIEL, Como.GENEROSO)),
	]
	sim.raise_moment(moment)


## Lo que cuesta ir a tratar ofreciendo eso, en las cifras de [Moment.options].
## La comida cuenta en la despensa; la piel no, que no se come. Las jornadas se
## van siempre, salga como salga.
static func _cuesta(ofrece: Materia.Kind, como: Como) -> Dictionary:
	var cuesta := {"jornadas": JORNADAS_DE_TRUEQUE}
	if Materia.is_food(ofrece):
		var unidades := LO_JUSTO * float(CUANTO_SE_OFRECE[como])
		cuesta["despensa"] = -unidades * Materia.nutrition(ofrece)
	return cuesta
