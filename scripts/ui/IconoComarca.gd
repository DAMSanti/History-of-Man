class_name IconoComarca
extends Control
## El icono de «ver la comarca»: cuatro puntas que se abren hacia fuera.
##
## Va DENTRO del minimapa, en su esquina, y ahí un rótulo de texto no cabe sin
## taparlo. Cuatro flechas saliendo de un cuadro es lo que todo el mundo lee
## como «alejar» sin tener que poner la palabra, igual que las figuras del
## control de tiempo —ver [TimeIcon]—, y dibujarlo sale más barato que
## mantener un PNG y escala solo.

var tint: Color = Color.WHITE


static func make(size: float = 15.0) -> IconoComarca:
	var icon := IconoComarca.new()
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return

	# El recuadro de en medio: lo que se está mirando ahora.
	var borde := maxf(s * 0.07, 1.0)
	draw_rect(Rect2(Vector2(0.36, 0.36) * s, Vector2(0.28, 0.28) * s),
		tint, false, borde)

	# Y las cuatro puntas, cada una hacia su esquina.
	for giro: Vector2 in [Vector2(1, 1), Vector2(-1, 1),
			Vector2(1, -1), Vector2(-1, -1)]:
		var punta := PackedVector2Array()
		for punto: Vector2 in [Vector2(0.98, 0.98), Vector2(0.62, 0.98),
				Vector2(0.98, 0.62)]:
			var centrado := (punto - Vector2(0.5, 0.5)) * giro + Vector2(0.5, 0.5)
			punta.append(centrado * s)
		draw_colored_polygon(punta, tint)
