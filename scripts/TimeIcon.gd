class_name TimeIcon
extends Control
## Iconos del control de tiempo, dibujados.
##
## Son las cuatro figuras que todo el mundo reconoce sin leer nada: dos barras,
## un triángulo, dos triángulos y dos triángulos con un número. Dibujarlas sale
## más barato que mantener cuatro PNG y escalan solas.

enum Shape { PAUSA, PLAY, RAPIDO, MUY_RAPIDO }

var shape: Shape = Shape.PLAY
var tint: Color = Color.WHITE


static func make(shape_value: Shape, size: float = 14.0) -> TimeIcon:
	var icon := TimeIcon.new()
	icon.shape = shape_value
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return

	match shape:
		Shape.PAUSA:
			_poly([Vector2(0.22, 0.14), Vector2(0.42, 0.14),
				Vector2(0.42, 0.86), Vector2(0.22, 0.86)], s)
			_poly([Vector2(0.58, 0.14), Vector2(0.78, 0.14),
				Vector2(0.78, 0.86), Vector2(0.58, 0.86)], s)
		Shape.PLAY:
			_poly([Vector2(0.26, 0.12), Vector2(0.82, 0.50),
				Vector2(0.26, 0.88)], s)
		Shape.RAPIDO:
			_poly([Vector2(0.08, 0.16), Vector2(0.50, 0.50),
				Vector2(0.08, 0.84)], s)
			_poly([Vector2(0.50, 0.16), Vector2(0.92, 0.50),
				Vector2(0.50, 0.84)], s)
		Shape.MUY_RAPIDO:
			# Tres puntas en vez de dos y algo más estrechas: se distingue de
			# la anterior de un vistazo sin tener que leer un número
			_poly([Vector2(0.02, 0.20), Vector2(0.34, 0.50),
				Vector2(0.02, 0.80)], s)
			_poly([Vector2(0.34, 0.20), Vector2(0.66, 0.50),
				Vector2(0.34, 0.80)], s)
			_poly([Vector2(0.66, 0.20), Vector2(0.98, 0.50),
				Vector2(0.66, 0.80)], s)


func _poly(points: Array, s: float) -> void:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * s)
	draw_colored_polygon(scaled, tint)
