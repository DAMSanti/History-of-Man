extends SceneTree
## La ración de cada alimento, como se va a leer en la ficha.
##
## Es la comprobación de la queja: «no quiero que haya dos valores de ración,
## uno para proteína y uno para kcal. QUIERO QUE SOLO HAYA UN VALOR, QUE DEBES
## CALCULAR CON AMBOS DE LO QUE UNA RACION CONSUME, Y DEBE DAR MAS LA CARNE QUE
## LOS FRUTOS SECOS».
##
## Las dos cifras de kcal son correctas, y por kilo también —la avellana con
## cáscara da 3.091 kcal/kg y el venado magro 1.511, que es lo que dan de
## verdad—. Lo que estaba mal era medir la comida con una sola de las dos
## cuentas que lleva un cuerpo. Ver [Materia.nutrition].


func _init() -> void:
	print("")
	print("%-16s %-9s %6s %9s %9s %9s %9s" % [
		"alimento", "unidad", "kg", "kcal/kg", "energia", "proteina", "RACION"])
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		if not Materia.is_food(k) or Materia.kcal(k) <= 0.0:
			continue
		print("%-16s %-9s %6.2f %9.0f %9.2f %9.2f %9.2f" % [
			Materia.material_name(k), Materia.unit_name(k),
			Materia.kg_per_unit(k),
			Materia.kcal(k) / maxf(Materia.kg_per_unit(k), 0.001),
			Materia.kcal(k) / Materia.KCAL_RACION,
			Materia.protein(k) / Materia.PROTEINA_RACION,
			Materia.nutrition(k)])
	quit()
