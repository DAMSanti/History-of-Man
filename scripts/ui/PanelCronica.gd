class_name PanelCronica
extends RefCounted
## La crónica de una persona: qué hizo, en qué orden y a qué hora.
##
## Es la pestaña que pidió el jugador: «cuando seleccionamos un miembro de la
## banda se abre una vista con su información; quiero añadir ahí una pestaña que
## sea Crónica, en la que detalle paso a paso lo que ha hecho esa persona».
##
## Lo que se pinta sale de [Diario], que lo va escribiendo [Cronista]. Aquí sólo
## se ordena por jornadas y se le pone la hora delante.
##
## ## Por qué de la última jornada hacia atrás
##
## Porque lo que se va a mirar el noventa por ciento de las veces es qué ha
## hecho HOY. Dentro de cada jornada sí va en orden, de la mañana a la noche,
## que es como se lee un día.

## Cuántas jornadas se pintan de una vez.
##
## Ocho. El diario guarda muchas más —ver [Diario.APUNTES]— pero pintarlas
## todas es una ventana de tres mil líneas que nadie recorre; con ocho se ve la
## semana larga, que es lo que cabe en la cabeza.
const JORNADAS_A_LA_VISTA := 8

## De qué color va cada clase de apunte.
##
## No es decoración: es lo que permite recorrer una jornada con el ojo sin
## leerla entera. El hallazgo en ocre y el apuro en rojo saltan solos, que es
## lo que tienen que hacer.
##
## Función y no tabla porque la paleta se viste al arrancar —[UISkin.dress]—
## y una constante se habría quedado con los colores de antes de vestirla.
static func tinte(que: int) -> Color:
	match que:
		Diario.Que.RUTINA: return UISkin.INK_SOFT
		Diario.Que.HALLAZGO: return UISkin.OCHRE
		Diario.Que.APURO: return UISkin.ALARM
		_: return UISkin.INK

var ui: GameUI


func _init(game_ui: GameUI) -> void:
	ui = game_ui


## Pinta la crónica de esta persona en el cuerpo que se le dé.
func pintar(body: VBoxContainer, person: Inhabitant) -> void:
	if person.diario == null or person.diario.apuntes.is_empty():
		ui._text(body, "Todavía no hay nada que contar de %s."
			% person.given_name, true)
		return

	var jornadas := person.diario.jornadas()
	var pintadas := 0
	for dia: int in jornadas:
		if pintadas >= JORNADAS_A_LA_VISTA:
			break
		pintadas += 1
		_una_jornada(body, person, dia)


func _una_jornada(body: VBoxContainer, person: Inhabitant, dia: int) -> void:
	var apuntes := person.diario.del_dia(dia)
	if apuntes.is_empty():
		return

	ui._heading(body, "DÍA %d%s" % [dia, " · hoy" if dia == ui.sim.day else ""])
	for apunte: Dictionary in apuntes:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		body.add_child(fila)

		var hora := Label.new()
		hora.text = Diario.reloj(float(apunte["hora"]))
		# Ancho fijo: las horas tienen que quedar en columna, que es lo que
		# deja leer la jornada de un vistazo en vez de palabra a palabra.
		hora.custom_minimum_size = Vector2(46, 0)
		hora.add_theme_color_override("font_color", UISkin.INK_SOFT)
		fila.add_child(hora)

		var texto := Label.new()
		texto.text = String(apunte["texto"])
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto.add_theme_color_override("font_color", tinte(int(apunte["que"])))
		fila.add_child(texto)

	body.add_child(HSeparator.new())
