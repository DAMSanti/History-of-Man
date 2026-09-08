class_name ParajePin
extends Control
## La chapa de un paraje: un alfiler con su icono dentro.
##
## No es un círculo de color. Un círculo dice «aquí hay algo» y nada más; hay
## que pinchar para saber qué. Un alfiler con el glifo del material dentro
## dice DE QUÉ es el sitio desde el otro lado del valle, que es justo lo que
## se mira cuando uno recorre el mapa buscando dónde mandar a la cuadrilla.
##
## La forma es la de cualquier mapa: cabeza redonda, punta abajo, y la punta
## es la que señala el suelo -ver cómo lo coloca [ParajeMarkers]-. Dentro, un
## hueco claro con el icono, que es lo que le da contraste a distancia:
## el color del cuerpo se lee de lejos, el glifo de cerca.

## Grosor del contorno oscuro, en píxeles de la chapa.
const BORDER := 4.0

## Color del cuerpo. El del material, para que el color siga contando lo
## mismo que contaba el círculo de antes.
var body_tint: Color = Color(0.6, 0.6, 0.6)


func _draw() -> void:
	var head_radius := size.x * 0.5 - BORDER
	if head_radius <= 1.0:
		return
	var head := Vector2(size.x * 0.5, BORDER + head_radius)
	var tip := Vector2(size.x * 0.5, size.y - 1.0)

	# Silueta oscura primero y cuerpo encima, un poco más chico: así el borde
	# sale parejo por todo el contorno sin tener que trazarlo aparte.
	_teardrop(head, head_radius, tip, Color(0.07, 0.06, 0.05, 0.95))
	_teardrop(head, head_radius - BORDER, tip - Vector2(0.0, BORDER * 1.4), body_tint)

	# El hueco claro donde vive el glifo
	draw_circle(head, head_radius * 0.62, Color(0.94, 0.92, 0.87))


## Círculo más cono tangente: la gota sale de una pieza, sin el escalón que
## deja pegar un triángulo cualquiera debajo de un círculo.
func _teardrop(centre: Vector2, radius: float, tip: Vector2, colour: Color) -> void:
	if radius <= 0.5:
		return
	draw_circle(centre, radius, colour)

	var to_tip := tip - centre
	var distance := to_tip.length()
	if distance <= radius:
		return

	# Los dos puntos donde el cono toca el círculo, para que encajen sin
	# solaparse ni dejar hueco
	var spread := acos(clampf(radius / distance, -1.0, 1.0))
	var base := to_tip.angle()
	var left := centre + Vector2(cos(base - spread), sin(base - spread)) * radius
	var right := centre + Vector2(cos(base + spread), sin(base + spread)) * radius
	draw_colored_polygon(PackedVector2Array([left, tip, right]), colour)
