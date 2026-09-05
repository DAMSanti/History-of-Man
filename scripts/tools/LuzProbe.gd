extends SceneTree
## Cuánta luz hay de verdad en las sombras, en números.
##
## Llevo cinco intentos diciendo «sigue saliendo negro» mirando capturas, que es
## justo lo que no vale. Esto mide la luminancia media de una zona en SOMBRA y
## otra al SOL en cada captura, y da la razón entre las dos.
##
## Referencia para juzgar: en una foto de campo a pleno sol, la sombra ronda el
## 15-20 % de lo iluminado. Por debajo del 8 % se lee como negro.

const SHADOW := Rect2(0.10, 0.56, 0.14, 0.18)
const LIT := Rect2(0.30, 0.30, 0.14, 0.10)


func _init() -> void:
	var dir := "C:/Users/Rathma/AppData/Roaming/Godot/app_userdata/CityBuilder/"
	var files := ["ao_80.png", "ao_25.png", "ao_00.png",
		"rebote_0.png", "rebote_3.png"]
	print("%-14s %8s %8s %8s" % ["captura", "sombra", "sol", "razon"])
	for name: String in files:
		var image := Image.new()
		if image.load(dir + name) != OK:
			print("%-14s no se pudo abrir" % name)
			continue
		var shadow := _mean(image, SHADOW)
		var lit := _mean(image, LIT)
		print("%-14s %8.4f %8.4f %7.1f %%" % [
			name, shadow, lit, 100.0 * shadow / maxf(lit, 0.0001)])
	quit()


func _mean(image: Image, area: Rect2) -> float:
	var x0 := int(area.position.x * float(image.get_width()))
	var y0 := int(area.position.y * float(image.get_height()))
	var x1 := int((area.position.x + area.size.x) * float(image.get_width()))
	var y1 := int((area.position.y + area.size.y) * float(image.get_height()))
	var total := 0.0
	var count := 0
	for y in range(y0, y1, 2):
		for x in range(x0, x1, 2):
			var c := image.get_pixel(x, y)
			total += 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			count += 1
	return total / maxf(float(count), 1.0)
