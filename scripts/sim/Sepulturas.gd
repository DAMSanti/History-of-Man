class_name Sepulturas
extends RefCounted
## Cómo se despide la banda de sus muertos, y lo que eso le deja.
##
## Frente 27 de EPOCA_01 §10.1, tanda 4. Hasta el 2026-09-13 morir era una línea
## en la crónica y una persona menos. Ahora sale una decisión: dejarlo, cubrirlo
## con piedras o enterrarlo con ajuar, cada una con su coste, y las tres dejan
## algo distinto en la banda.
##
## **Lo que «nota la banda» es un duelo**, decidido por el usuario el
## 2026-09-13: tras una muerte la banda rinde algo menos unas jornadas, con la
## eficacia que ya existe —ver [Inhabitant.effectiveness]—; dejar al muerto
## alarga el duelo y enterrarlo con ajuar lo acorta. No hay una cifra de ánimo o
## cohesión de la banda en la que contarlo, y no se inventa una.

enum Despedida {
	DEJAR,     ## Donde cayó
	CUBRIR,    ## Con un túmulo de piedras
	ENTERRAR,  ## En una fosa, con ocre y conchas
}

## Jornadas de duelo que deja cada despedida. **Son una decisión, no una
## medida**: la spec pide que no se inventen, y lo único que fija el usuario es el
## orden —dejarlo alarga, enterrarlo con ajuar acorta—. Cuatro es el duelo de
## referencia, una semana corta de trabajo a medio gas; dejarlo lo alarga la
## mitad y el ajuar lo deja en la mitad.
const DUELO := {
	Despedida.DEJAR: 6,
	Despedida.CUBRIR: 4,
	Despedida.ENTERRAR: 2,
}

## Lo que rinde alguien de duelo, sobre lo que rendiría. Decisión: un 15 % menos
## se nota en la despensa de una semana sin parar la banda.
const RINDE_EN_DUELO := 0.85

## Lo que cuesta cada despedida. La piedra del túmulo y la fosa; el ocre y las
## conchas del ajuar, que son lo que aparece en las sepulturas del Paleolítico
## superior cantábrico. Las cantidades son decisión.
const COSTE := {
	Despedida.DEJAR: {},
	Despedida.CUBRIR: {Materia.Kind.PIEDRA: 4.0},
	Despedida.ENTERRAR: {Materia.Kind.PIEDRA: 4.0, Materia.Kind.OCRE: 1.0,
		Materia.Kind.CONCHA: 2.0},
}

var sim: SettlementSim

## Dónde está enterrado cada cual: `{"nombre", "donde", "despedida", "dia"}`.
## Sólo las cubiertas y las enterradas: a quien se deja no se le marca sitio.
var tumbas: Array[Dictionary] = []

## Si ya se contó el hito de la primera sepultura con ajuar. Es de la época, y
## sólo hay una primera.
var hito_contado: bool = false


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Muere alguien: se cuenta cómo, quién era, y se pregunta cómo se le despide.
##
## La tarjeta decía «Ha muerto Anda · La banda tiene que decidir qué se hace con
## el cuerpo», y la causa se quedaba en la crónica. Queja del usuario del
## 2026-09-13: «debe ser un acontecimiento que le importe al jugador, con una
## pequeña historia, no un mensaje robótico». Ver [relato].
func al_morir(muerto: Inhabitant, causa: String) -> void:
	var nombre := muerto.given_name
	var donde := muerto.position
	var momento := Moment.new()
	momento.kind = Moment.Kind.PERCANCE
	momento.title = "Muere %s" % nombre
	momento.text = relato(muerto, causa)
	momento.where = donde
	momento.has_place = true
	for despedida: int in [Despedida.DEJAR, Despedida.CUBRIR, Despedida.ENTERRAR]:
		var cual := despedida as Despedida
		momento.options.append(Moment.opcion(etiqueta(cual), aviso(cual),
			func() -> void: despedir(nombre, donde, cual),
			coste_escrito(cual), lo_que_falta(cual)))
	sim.raise_moment(momento)


## La pequeña historia de quien se va: cómo murió, quién era y a quién deja.
##
## Sale de lo que la partida ya sabe de esa persona —edad, oficio, lo que trajo
## al abrigo, con quién trabajaba— y no de frases al azar: una necrológica que
## dijera lo mismo de cualquiera sería otra vez el mensaje robótico.
func relato(muerto: Inhabitant, causa: String) -> String:
	var ella := muerto.sex == Inhabitant.Sex.MUJER
	var partes: Array[String] = [causa, ""]

	var oficio := Profession.job_name(muerto.job as Profession.Job).to_lower()
	partes.append("%s tenía %d años y vivía de %s." % [
		muerto.given_name, muerto.age_years, oficio])

	var jornadas := 0.0
	var mejor_kind := -1
	var mejor := 0.0
	for fila: Dictionary in muerto.work_summary():
		jornadas += float(fila["hours"]) / SettlementSim.HORAS_UTILES
		var traido: Dictionary = fila["gained"]
		for kind: int in traido:
			if float(traido[kind]) > mejor:
				mejor = float(traido[kind])
				mejor_kind = kind
	if mejor_kind >= 0 and mejor >= 1.0:
		partes.append("En %d jornadas de trabajo trajo al abrigo %.0f de %s%s." % [
			int(jornadas), mejor,
			Materia.material_name(mejor_kind as Materia.Kind).to_lower(),
			", más que nadie en la banda" if _nadie_trajo_mas(muerto, mejor_kind, mejor)
				else ""])
	elif jornadas >= 1.0:
		partes.append("Dejó %d jornadas de trabajo en esta banda." % int(jornadas))

	var cercano := _quien_lo_llora(muerto)
	if cercano != null:
		partes.append("%s, que trabajaba a su lado, %s llora." % [
			cercano.given_name, "la" if ella else "lo"])
	elif sim.people.size() > 0:
		partes.append("La banda se queda con %d bocas y un hueco junto al fuego."
			% sim.people.size())

	partes.append("")
	partes.append("Hay que decidir qué se hace con el cuerpo.")
	return "\n".join(partes)


## Si nadie de los que quedan ha traído más de esto.
func _nadie_trajo_mas(muerto: Inhabitant, kind: int, cuanto: float) -> bool:
	for otro: Inhabitant in sim.people:
		if otro == muerto:
			continue
		var suyo := 0.0
		for fila: Dictionary in otro.work_summary():
			suyo += float((fila["gained"] as Dictionary).get(kind, 0.0))
		if suyo >= cuanto:
			return false
	return sim.people.size() > 0


## Quien más horas ha echado en el mismo oficio, de los que quedan.
func _quien_lo_llora(muerto: Inhabitant) -> Inhabitant:
	var mejor: Inhabitant = null
	var mejor_horas := -1.0
	for otro: Inhabitant in sim.people:
		if otro == muerto:
			continue
		var horas := 0.0 if otro.job != muerto.job else 1.0
		for fila: Dictionary in otro.work_summary():
			if Profession.task_job(int(fila["task"])) == muerto.job:
				horas += float(fila["hours"])
		if horas > mejor_horas:
			mejor_horas = horas
			mejor = otro
	return mejor


static func etiqueta(despedida: Despedida) -> String:
	match despedida:
		Despedida.CUBRIR:
			return "Cubrirlo con piedras"
		Despedida.ENTERRAR:
			return "Enterrarlo con ajuar"
	return "Dejarlo donde está"


## Lo que se le dice al jugador de cada una: el duelo que deja.
static func aviso(despedida: Despedida) -> String:
	return "La banda rinde menos %d días." % int(DUELO[despedida])


## El coste, para que la tarjeta lo escriba: materiales, y el duelo en días.
static func coste_escrito(despedida: Despedida) -> Dictionary:
	var cuesta: Dictionary = (COSTE[despedida] as Dictionary).duplicate()
	cuesta["duelo"] = int(DUELO[despedida])
	return cuesta


## Qué falta para poder despedirlo así, o vacío si se puede.
func lo_que_falta(despedida: Despedida) -> String:
	for material: int in (COSTE[despedida] as Dictionary):
		if sim.store.amount(material as Materia.Kind) < float(COSTE[despedida][material]):
			return "falta %s" % Materia.material_name(material as Materia.Kind).to_lower()
	return ""


## Aplica la despedida: cobra, pone el duelo, lo cuenta y deja la tumba. Dice si
## se ha podido.
func despedir(nombre: String, donde: Vector3, despedida: Despedida) -> bool:
	if not lo_que_falta(despedida).is_empty():
		return false
	for material: int in (COSTE[despedida] as Dictionary):
		sim.store.take(material as Materia.Kind, float(COSTE[despedida][material]))
	for person: Inhabitant in sim.people:
		person.duelo_dias = maxi(person.duelo_dias, int(DUELO[despedida]))

	match despedida:
		Despedida.DEJAR:
			sim._note(Chronicle.Kind.GENTE, "Se deja a %s donde cayó. A la banda "
				% nombre + "le cuesta quitárselo de la cabeza.", 2)
		Despedida.CUBRIR:
			sim._note(Chronicle.Kind.GENTE,
				"Se cubre a %s con un túmulo de piedras." % nombre, 2)
		Despedida.ENTERRAR:
			sim._note(Chronicle.Kind.GENTE, "Se entierra a %s en una fosa, con "
				% nombre + "ocre y conchas.", 2)
			if not hito_contado:
				hito_contado = true
				_hito(nombre)

	if despedida != Despedida.DEJAR:
		tumbas.append({"nombre": nombre, "donde": donde,
			"despedida": int(despedida), "dia": sim.day})
	return true


## Pasa un día: el duelo se va gastando.
func nueva_jornada() -> void:
	for person: Inhabitant in sim.people:
		if person.duelo_dias > 0:
			person.duelo_dias -= 1


## El hito de la época: la primera sepultura con ajuar. Se cuenta como relato,
## que es lo que se puede dejar en la pared.
func _hito(nombre: String) -> void:
	var relato := Tale.new()
	relato.kind = Tale.Kind.HITO
	relato.subject = "la sepultura"
	relato.title = "La primera sepultura"
	relato.text = "Se entierra a %s con ocre y conchas, y se le deja " % nombre \
		+ "mirando a la boca de la cueva. Es la primera vez que la banda guarda " \
		+ "a uno de los suyos para que siga estando."
	relato.day = sim.day
	sim.tell_tale(relato)
