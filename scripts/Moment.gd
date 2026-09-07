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
##   {"label": String, "hint": String, "on_pick": Callable}
## Vacío significa que no hay nada que decidir, sólo algo que mirar.
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


## Si hay algo que decidir. Mientras lo haya, el reloj se para.
func is_decision() -> bool:
	return not options.is_empty()
