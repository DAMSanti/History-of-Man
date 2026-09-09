extends SceneTree
## Las dos raciones de cada alimento, como se van a leer en la ficha.
##
## Es la comprobación de la queja: «sigue marcando que un fruto seco vale más
## que carne fresca... uno sigue siendo 1.36 raciones y el otro 0.54 raciones».
##
## Las dos cifras de energía son correctas, y por kilo también —la avellana con
## cáscara da 3.091 kcal/kg y el venado magro 1.511, que es lo que dan de
## verdad—. Lo que faltaba no era corregir un dato: era enseñar el otro.


func _init() -> void:
	print("")
	print("%-16s %-9s %6s %9s %10s %10s" % [
		"alimento", "unidad", "kg", "kcal/kg", "energia", "proteina"])
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		if not Materia.is_food(k) or Materia.kcal(k) <= 0.0:
			continue
		print("%-16s %-9s %6.2f %9.0f %8.1f r %8.1f r" % [
			Materia.material_name(k), Materia.unit_name(k),
			Materia.kg_per_unit(k),
			Materia.kcal(k) / maxf(Materia.kg_per_unit(k), 0.001),
			Materia.nutrition(k), Materia.raciones_de_proteina(k)])

	print("")
	print("--- Y EN EL MONTON, que es donde se ve para que sirve la carne ---")
	var solo_avellana := Storehouse.new()
	solo_avellana.add(Materia.Kind.FRUTO_SECO, 100.0)
	print("cien puñados de avellana:            %6.1f de energia · %6.1f completas" % [
		solo_avellana.food_rations(), solo_avellana.raciones_completas()])

	var con_carne := Storehouse.new()
	con_carne.add(Materia.Kind.FRUTO_SECO, 100.0)
	con_carne.add(Materia.Kind.CARNE, 20.0)
	print("y con veinte tajadas de carne encima: %6.1f de energia · %6.1f completas" % [
		con_carne.food_rations(), con_carne.raciones_completas()])
	quit()
