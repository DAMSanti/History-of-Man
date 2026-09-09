class_name Diario
extends RefCounted
## Lo que ha hecho una persona, paso a paso y con la hora puesta.
##
## Es la petición literal del jugador: «cuando seleccionamos un miembro de la
## banda se abre una vista con su información; quiero añadir ahí una pestaña que
## sea Crónica, en la que detalle paso a paso lo que ha hecho esa persona.
## Desayunó a las XX:XX, salió de batida a las XX:XX, ha descubierto raíces a X
## metros de la cueva a las XX:XX, encontró un buen paraje a las XX:XX, decidió
## volver a la cueva a las XX:XX, llegó a la cueva a las XX:XX, cenó a las
## XX:XX, se fue a dormir a las XX:XX. DÍA 2: despertó a las XX:XX...»
##
## ## Por qué es un diario y no el registro de siempre
##
## Ya había dos cosas parecidas y ninguna servía para esto:
##
##   [Chronicle]   el diario DE LA BANDA. Cuenta lo que le pasa al grupo —una
##                 nevada, un hallazgo, una muerte—, no lo que hizo cada cual.
##   `work_log`    el resumen POR TAREA. Dice cuántas horas y cuánto se trajo,
##                 pero no en qué orden ni a qué hora, que es justo lo que se
##                 pide aquí.
##
## Esto es la tercera cosa: una LÍNEA DE TIEMPO, en la que el orden y la hora
## son la información. «Salió a las 8:10 y volvió a las 19:40 sin nada» y «salió
## a las 8:10, encontró el avellanar a las 10:20 y volvió a las 15:00 cargado»
## son dos jornadas que el resumen por tarea cuenta igual.

## Cuántos apuntes se guardan por persona.
##
## Trescientos son del orden de diez jornadas de alguien que sale a diario, que
## es lo que se lee de un tirón sin perderse. Más no cabe en una ventana y
## cuesta memoria por cada miembro de la banda.
const APUNTES := 300

## Qué clase de apunte es. La ventana los pinta distinto, y sobre todo permite
## quedarse sólo con lo que pasó de verdad cuando el día viene largo.
enum Que {
	RUTINA,    ## Despertar, desayunar, acostarse: el esqueleto del día
	CAMINO,    ## Salir, llegar, decidir volver
	TRABAJO,   ## Ponerse a ello, y con qué se vuelve
	HALLAZGO,  ## Lo que se descubre: un material, un sitio con nombre
	APURO,     ## Lo que sale mal: dormir al raso, quedarse sin agua, herirse
}

## Cada apunte es `{dia, hora, que, texto}`. En orden, del más viejo al último.
var apuntes: Array[Dictionary] = []


## Apunta algo, con el día y la hora puestos.
##
## Se descarta el apunte repetido seguido —mismo texto, mismo día— porque la
## simulación pregunta muchas veces por tick y lo que interesa es el CAMBIO.
func apunta(dia: int, hora: float, que: Que, texto: String) -> void:
	if texto.is_empty():
		return
	if not apuntes.is_empty():
		var ultimo: Dictionary = apuntes[apuntes.size() - 1]
		if int(ultimo["dia"]) == dia and String(ultimo["texto"]) == texto:
			return
	apuntes.append({"dia": dia, "hora": hora, "que": int(que), "texto": texto})
	while apuntes.size() > APUNTES:
		apuntes.remove_at(0)


## Los apuntes de una jornada, en orden.
func del_dia(dia: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for apunte: Dictionary in apuntes:
		if int(apunte["dia"]) == dia:
			out.append(apunte)
	return out


## Qué jornadas tienen algo apuntado, de la más reciente a la más vieja.
func jornadas() -> Array[int]:
	var out: Array[int] = []
	for i in range(apuntes.size() - 1, -1, -1):
		var dia := int(apuntes[i]["dia"])
		if not out.has(dia):
			out.append(dia)
	return out


## La hora, como se lee en un reloj. Es la mitad de lo que se pidió.
static func reloj(hora: float) -> String:
	var h := int(floor(hora)) % 24
	var m := int(round((hora - floor(hora)) * 60.0))
	if m >= 60:
		m -= 60
		h = (h + 1) % 24
	return "%02d:%02d" % [h, m]
