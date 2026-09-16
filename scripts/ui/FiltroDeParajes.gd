class_name FiltroDeParajes
extends RefCounted
## Qué parajes enseña la ventana de Parajes: por oficio y por distancia.
##
## La lista era de cercanía y nada más, y con decenas de parajes «¿dónde hay
## caza a menos de un kilómetro?» obligaba a leerla entera (INTERFAZ §10).
##
## **Vive en la interfaz y no en [Parajes]**: es una preferencia de lectura, no
## estado de la partida, así que no entra en la instantánea, no se guarda en
## disco y no la ve la simulación. Se recuerda mientras dura la partida
## —decisión del usuario del 2026-09-15— y se vacía sola al cambiar de partida,
## que es lo que hace [para].
##
## Es estático a propósito: la ventana se destruye y se vuelve a montar cada vez
## que se abre, y el filtro tiene que sobrevivir a eso.

## Los cinco oficios que se filtran, en el orden en que salen en la fila.
const OFICIOS: Array[int] = [
	Subsistence.Activity.CAZA,
	Subsistence.Activity.PESCA,
	Subsistence.Activity.MARISQUEO,
	Subsistence.Activity.RECOLECCION,
	Subsistence.Activity.MATERIA_PRIMA,
]

## Los tramos de distancia al campamento, en metros. El 0 es «todos» y es el de
## partida. Decisión del usuario del 2026-09-15: uno a la vez, no varios.
const TRAMOS: Array[float] = [500.0, 1000.0, 2000.0, 0.0]

## Los oficios encendidos, `Activity -> true`. Vacío es «todos».
static var oficios: Dictionary = {}

## El tramo elegido, en metros. 0 es sin tope.
static var tramo: float = 0.0

## De qué partida son estos filtros. La identidad del objeto, no un nombre:
## cargar otra partida construye otra simulación, y eso es lo que hay que notar.
static var _de_quien: int = 0


## Deja el filtro listo para esta partida, vaciándolo si es otra.
##
## Lo llama la ventana antes de pintar. Cargar una partida o empezar otra
## construye un [SettlementSim] nuevo, así que basta con mirar de quién era.
static func para(sim: SettlementSim) -> void:
	var quien := 0 if sim == null else sim.get_instance_id()
	if quien != _de_quien:
		_de_quien = quien
		todo()


## Vuelve a «todo»: ningún oficio marcado y sin tope de distancia.
static func todo() -> void:
	oficios = {}
	tramo = 0.0


## Si este oficio está encendido.
static func encendido(oficio: Subsistence.Activity) -> bool:
	return bool(oficios.get(int(oficio), false))


## Enciende o apaga un oficio.
static func alternar(oficio: Subsistence.Activity) -> void:
	if encendido(oficio):
		oficios.erase(int(oficio))
	else:
		oficios[int(oficio)] = true


## Pone el tope de distancia. 0 es «todos».
static func poner_tramo(metros: float) -> void:
	tramo = metros


## Si hay algo filtrando de verdad. Con todos los oficios encendidos no filtra
## nada —salen todos igual—, y decirlo así evita el recuento «12 de 12».
static func hay_filtro() -> bool:
	return tramo > 0.0 or (not oficios.is_empty()
		and oficios.size() < OFICIOS.size())


## Si este paraje pasa el filtro.
##
## **Basta con que haga UNO de los oficios encendidos**, aunque no sea el que le
## da nombre e icono (decisión del usuario del 2026-09-15): el recodo donde
## además se saca raíz tiene que encontrarse buscando raíz.
static func pasa(paraje: Paraje, casa: Vector3) -> bool:
	if paraje == null:
		return false
	if tramo > 0.0 and paraje.distance_from(casa) > tramo:
		return false
	if oficios.is_empty():
		return true
	for oficio: int in oficios:
		if paraje.serves(oficio as Subsistence.Activity):
			return true
	return false


## Los parajes que la ventana enseña: los que pasan el filtro, **de más cerca a
## más lejos**, que es el orden de siempre y no lo cambia el filtro.
##
## La lista se calcula aquí y la ventana sólo la pinta: la vista no decide
## (SPECS §4.7), y así se prueba sin montar ningún nodo.
static func filtrar(parajes: Array, casa: Vector3) -> Array[Paraje]:
	var fuera: Array[Paraje] = []
	for paraje: Paraje in parajes:
		if pasa(paraje, casa):
			fuera.append(paraje)
	fuera.sort_custom(func(a: Paraje, b: Paraje) -> bool:
		return a.distance_from(casa) < b.distance_from(casa))
	return fuera


## El encabezado de la lista: cuántos enseña de cuántos conoce la banda.
static func titulo(mostrados: int, conocidos: int) -> String:
	if not hay_filtro():
		return "%d PARAJES CONOCIDOS" % conocidos
	return "%d DE %d PARAJES CONOCIDOS" % [mostrados, conocidos]


## Lo que dice la ventana cuando el filtro no deja ninguno. **Con esas
## palabras**: la ventana en blanco parecía que la banda no conocía nada.
static func aviso_de_vacio(conocidos: int) -> String:
	return ("Ninguno de los %d parajes conocidos pasa este filtro. "
		+ "Enciende otro oficio o alarga la distancia.") % conocidos


## Cómo se llama el tramo elegido, para el botón y para el aviso.
static func nombre_del_tramo(metros: float) -> String:
	if metros <= 0.0:
		return "todos"
	if metros < 1000.0:
		return "%d m" % int(metros)
	return "%d km" % int(metros / 1000.0)
