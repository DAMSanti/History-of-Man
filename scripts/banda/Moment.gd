class_name Moment
extends RefCounted
## Un instante en que la partida deja de ser gestión y te mira.
##
## Todo lo que pasa en este juego se resuelve por planificación previa: se
## reparten oficios, se señalan parajes y luego se mira correr el reloj. Eso
## está bien para el año y fatal para el minuto: cuando un explorador se
## rompe un tobillo a dos kilómetros del abrigo, el jugador se entera leyendo
## la crónica un rato después, y para entonces ya no hay nada que decidir.
##
## Un momento es lo contrario: la partida se para, se cuenta lo que acaba de
## pasar y —si lo hay— se ofrece una decisión ahí mismo. Sirve para las dos
## mitades del asunto:
##
## - **Sin opciones**, es un HALLAZGO: coronar un pico, dar con un paraje
##   nuevo. Se enseña, se lleva la cámara y se sigue. Encontrar algo tiene que
##   notarse en el momento, no ser un cambio silencioso en el mapa de niebla.
## - **Con opciones**, es una DECISIÓN: qué hacer con el que se ha torcido un
##   tobillo, si volcar la banda en la berrea. No sustituye a la gestión, la
##   interrumpe en los puntos de más tensión.
##
## Quien lo levanta es `SettlementSim`; quien lo enseña, `GameUI`.

enum Kind {
	HALLAZGO,   ## Un sitio nuevo con nombre
	CUMBRE,     ## Un pico coronado: media comarca de golpe
	PERCANCE,   ## Algo ha salido mal ahí fuera
	BERREA,     ## Empieza el otoño, y con él la caza que decide el invierno
	RELATO,     ## Lo que se cuenta al volver, y que se puede dejar en la pared
	INICIO,     ## Se funda el asentamiento: el objetivo, y que se puede perder
	VICTORIA,   ## Se cierra un año vivo y con la cueva pintada
	DERROTA,    ## La banda entera se ha extinguido
	EXPEDICION, ## Primavera: si se manda gente fuera del valle este año
	ASCENSO,    ## Verano: si se sube a las cumbres ahora que no hiela
	INVIERNO,   ## Invierno: el fuego a manos llenas o racionado
	CUEVA,      ## Algo pasa dentro de una cueva que se está explorando
}

var kind: Kind = Kind.HALLAZGO

## Titular corto. Es lo único que se lee seguro.
var title: String = ""

## Lo que ha pasado, en una o dos frases.
var text: String = ""

## Dónde. Si `has_place`, se ofrece llevar la cámara.
var where: Vector3 = Vector3.ZERO
var has_place: bool = false

## Quién, cuando el momento va de una persona concreta. Es lo que hace que
## perder a alguien pese: un nombre, no una cifra.
var who: Inhabitant = null

## Qué se puede decidir. Cada entrada:
##   {"label": String, "hint": String, "on_pick": Callable, "cuesta": Dictionary}
## Vacío significa que no hay nada que decidir, sólo algo que mirar.
##
## `cuesta` dice lo que cambia elegir esa opción, en las tres cifras que nombra
## la spec —EPOCA_01 §10.1, frente 8—: `"despensa"` (raciones que salen, en
## negativo), `"jornadas"` (jornadas-persona que no se trabajan en lo de
## siempre) y `"riesgo"` (de 0 a 1). Hace falta ESCRITO y no sólo en la pista:
## el criterio «un momento cuenta sólo si la opción que no se eligió cambia una
## cifra» no se puede medir si la cifra no está en ninguna parte. Ver
## [la_eleccion_importa].
var options: Array[Dictionary] = []


static func found(title_text: String, body: String, place: Vector3) -> Moment:
	var moment := Moment.new()
	moment.kind = Kind.HALLAZGO
	moment.title = title_text
	moment.text = body
	moment.where = place
	moment.has_place = true
	return moment


static func summit(title_text: String, body: String, place: Vector3,
		person: Inhabitant) -> Moment:
	var moment := found(title_text, body, place)
	moment.kind = Kind.CUMBRE
	moment.who = person
	return moment


## Una opción, con lo que cuesta. Ver [options].
## A QUIÉN se manda, cuando la decisión lo pregunta.
##
## Hasta la tanda 3 el jugador decía «sí» y la banda elegía sola: se enteraba de
## quién se había ido cuando lo echaba en falta. `candidatos` son los ids que
## pueden ir —ya filtrados: ni niños ni tocados—, `nombres` cómo se llaman para
## pintarlos, `minimo_elegidos` cuántos hacen falta para poder confirmar, y
## `elegidos` los que están marcados ahora mismo. Vacío en las decisiones que no
## preguntan por gente. Ver [BarraSuperior] y EPOCA_01 §10.1, tanda 3.
var candidatos: Array[int] = []
var nombres: Dictionary = {}
var minimo_elegidos: int = 0
var elegidos: Array[int] = []

## Lo que hay que rehacer cuando cambia la elección: el coste de las opciones
## depende de cuántos van. Lo pone quien levanta el momento.
var al_cambiar_la_eleccion: Callable = Callable()


## Marca o desmarca a uno, y rehace las opciones si hacía falta.
func marcar(id: int, puesto: bool) -> void:
	if puesto:
		if not candidatos.has(id) or elegidos.has(id):
			return
		elegidos.append(id)
	else:
		elegidos.erase(id)
	if al_cambiar_la_eleccion.is_valid():
		al_cambiar_la_eleccion.call()


## Si hay bastantes marcados para poder decir que sí.
func hay_bastantes() -> bool:
	return elegidos.size() >= minimo_elegidos


## `bloqueo` dice POR QUÉ no se puede elegir esta opción, y vacío es que sí se
## puede. No se esconde la opción: se enseña apagada con lo que falta, que es
## lo que deja al jugador ir a por ello. Ver [BarraSuperior].
static func opcion(label: String, hint: String, on_pick: Callable,
		cuesta: Dictionary = {}, bloqueo: String = "") -> Dictionary:
	return {"label": label, "hint": hint, "on_pick": on_pick, "cuesta": cuesta,
		"bloqueo": bloqueo}


## Si elegir una u otra cambia alguna cifra de la partida.
##
## Es el criterio del frente 8: un momento con dos botones cuya elección da
## igual **no cuenta como decisión**, aunque pare el reloj. Cuenta si al menos
## dos opciones declaran costes distintos. Una opción sin `cuesta` declara que
## no cuesta nada, que también es una cifra: «dejarlo» frente a «ir» importa.
func la_eleccion_importa() -> bool:
	if options.size() < 2:
		return false
	var primera: Dictionary = options[0].get("cuesta", {})
	for i in range(1, options.size()):
		var otra: Dictionary = options[i].get("cuesta", {})
		if not _mismo_coste(primera, otra):
			return true
	return false


static func _mismo_coste(a: Dictionary, b: Dictionary) -> bool:
	for clave in ["despensa", "jornadas", "riesgo"]:
		if not is_equal_approx(float(a.get(clave, 0.0)), float(b.get(clave, 0.0))):
			return false
	return true


## Si hay algo que decidir. Mientras lo haya, el reloj se para.
func is_decision() -> bool:
	return not options.is_empty()
