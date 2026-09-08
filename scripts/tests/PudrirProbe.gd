extends SceneTree
## Si la comida se pudre de verdad.
##
## La despensa promedia la edad al añadir: `ages = vieja * habia / (habia +
## nuevo)`. Eso significa que un monton viejo REJUVENECE al echarle encima
## genero fresco, justo lo que el comentario del codigo dice que no pasa.
##
## Aqui se comprueba con dos despensas identicas: una que recibe carne una vez
## y otra que recibe la misma cantidad repartida en goteo diario, como hace una
## banda que caza.


func _initialize() -> void:
	print("")
	print("=== LA CARNE FRESCA AGUANTA %d DIAS ===" % Materia.shelf_life(Materia.Kind.CARNE))
	print("")

	var quieta := Storehouse.new()
	quieta.add(Materia.Kind.CARNE, 100.0)
	var goteo := Storehouse.new()
	goteo.add(Materia.Kind.CARNE, 100.0)

	print("%-5s %14s %14s   %s" % ["dia", "sin reponer", "con goteo", "lo que entra al dia"])
	for dia in range(1, 15):
		quieta.age(1)
		# Una banda que caza mete algo casi todos los dias
		goteo.add(Materia.Kind.CARNE, 12.0)
		goteo.age(1)
		print("%-5d %14.1f %14.1f   +12" % [
			dia, quieta.amount(Materia.Kind.CARNE), goteo.amount(Materia.Kind.CARNE)])

	print("")
	print("sin reponer: se pudrio TODO en %d dias, como debe" % 8)
	print("con goteo:   quedan %.0f unidades y la edad del monton es %.2f dias" % [
		goteo.amount(Materia.Kind.CARNE), float(goteo.ages.get(int(Materia.Kind.CARNE), 0.0))])
	print("             o sea que la carne del dia 1 sigue ahi, catorce dias despues")
	quit()
