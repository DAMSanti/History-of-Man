extends SceneTree
## Cuánto mide de verdad cada malla horneada, para calibrar su talla.
##
## La `scale` de `WildlifeHerds.SPECIES_VISUAL` no es un número puesto a ojo:
## sale de medir la caja del PRIMER FOTOGRAMA horneado y compararla con la
## alzada real del animal. Como lo que se dibuja son las posiciones de la
## textura de vértice —no las de la malla en reposo—, hay que medir ahí.

const MODELS := ["wolf", "horse", "cow", "pig", "sheep", "deer", "stag", "bull"]


func _init() -> void:
	print("%-8s %8s %8s %8s   alzada 1,0 m pide escala" % [
		"malla", "alto", "largo", "ancho"])
	for prefix: String in MODELS:
		var texture: Texture2D = load("res://models/animals/%s_vertex.res" % prefix)
		if texture == null:
			print("%-8s sin hornear" % prefix)
			continue
		var image := texture.get_image()
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for y in range(image.get_height()):
			var c := image.get_pixel(0, y)
			var v := Vector3(c.r, c.g, c.b)
			low = low.min(v)
			high = high.max(v)
		var box := high - low
		print("%-8s %8.3f %8.3f %8.3f   %.4f" % [
			prefix, box.y, box.z, box.x, 1.0 / maxf(box.y, 0.0001)])
	quit()
