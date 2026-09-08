class_name Muescas
extends Control
## Una tira de muescas talladas: como se cuenta en el Paleolitico.
##
## Sustituye a la barra de progreso para el hambre y el cansancio, y no es un
## adorno: los BASTONES DE MUESCAS estan atestiguados desde el Paleolitico
## superior -el hueso de Ishango, las placas de asta del Magdaleniense- y son
## la forma documentada de llevar una cuenta en esta epoca. Una barra de
## relleno continuo es un widget de 1990.
##
## Y ademas se lee mejor: diez marcas se cuentan de un vistazo, un relleno del
## 63 % no se distingue de uno del 71 %.
##
## La muesca llena se pinta de OCRE, que es el pigmento que la banda recoge.

## Cuantas marcas tiene la tira. Diez, para que cada una sea un diez por ciento
## y se pueda leer sin contar.
const MARCAS := 10

## De 0 a 1.
var valor: float = 0.0:
	set(v):
		valor = clampf(v, 0.0, 1.0)
		queue_redraw()

## El color de lo lleno. Se cambia desde fuera para que el hambre alta avise.
var tinta: Color = UISkin.OCHRE:
	set(c):
		tinta = c
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(84, 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var ancho := size.x / float(MARCAS)
	# Fina: una muesca es un corte de buril, no una barra. Con 0,42 de la
	# celda salian rectangulos gordos y volvia a parecer una barra de progreso.
	var grosor := maxf(ancho * 0.20, 2.0)
	var llenas := valor * float(MARCAS)
	for i in range(MARCAS):
		var x := ancho * (float(i) + 0.5)
		# La muesca tallada: una linea vertical con la punta mas fina abajo,
		# como la deja un buril al levantar.
		var cuanto := clampf(llenas - float(i), 0.0, 1.0)
		var color := UISkin.INK_FAINT if cuanto <= 0.0 else tinta
		# La vacia es un corte apenas empezado; la llena llega de arriba abajo.
		var alto := size.y * (0.42 if cuanto <= 0.0 else 1.0)
		var arriba := (size.y - alto) * 0.5
		draw_line(Vector2(x, arriba), Vector2(x, arriba + alto), color, grosor)
		# La decima marca va cruzada, como en un bastón de verdad: se agrupa de
		# cinco en cinco para poder contar sin contar.
		if i == 4 or i == 9:
			var media := arriba + alto * 0.5
			draw_line(Vector2(x - ancho * 0.28, media),
				Vector2(x + ancho * 0.28, media), color, maxf(grosor * 0.6, 1.0))
