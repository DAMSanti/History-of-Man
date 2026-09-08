class_name CraftBadge
extends Control
## La chapa que dice qué está haciendo un artesano y cuánto le falta.
##
## Es una placa apaisada: el glifo de la pieza a la izquierda —los mismos que
## el almacén y los parajes, para que se reconozcan sin leer— y una barra a la
## derecha con lo que lleva hecho. El glifo dice QUÉ y la barra dice CUÁNTO,
## que son las dos preguntas que uno se hace mirando a alguien trabajar.
##
## No lleva rótulo con el nombre de la pieza a propósito. A la distancia a la
## que se juega no se lee un texto de doce píxeles, y el glifo sí: el nombre
## está en su ficha, para quien quiera el detalle.

## Grosor del borde oscuro, en píxeles de la chapa.
const BORDER := 3.0

## Alto de la barra dentro de la chapa.
const BAR_HEIGHT := 9.0

## Lo hecho de la pieza, de 0 a 1.
var progress: float = 0.0

## Color de la pieza. El mismo que le da el catálogo de iconos.
var tint: Color = Color(0.7, 0.7, 0.7)


func _draw() -> void:
	var plaque := Rect2(Vector2.ZERO, size)
	# Fondo oscuro y opaco: la chapa tiene que leerse igual sobre pasto claro
	# y sobre roca en sombra, y a esa distancia el contraste es lo único que
	# la separa del suelo.
	draw_rect(plaque, Color(0.07, 0.06, 0.05, 0.86))
	draw_rect(plaque, Color(0.94, 0.92, 0.87, 0.55), false, BORDER * 0.5)

	var left := size.y
	var bar := Rect2(
		Vector2(left, size.y - BORDER - BAR_HEIGHT),
		Vector2(size.x - left - BORDER * 2.0, BAR_HEIGHT))
	draw_rect(bar, Color(0.20, 0.19, 0.17, 0.9))

	var done := bar
	done.size.x = maxf(bar.size.x * clampf(progress, 0.0, 1.0), 1.0)
	draw_rect(done, tint)
