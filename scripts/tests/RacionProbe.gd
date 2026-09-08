extends SceneTree
## Si las cifras de comida cuadran entre si.
##
## La queja: «el tooltip me pone que come 0,5 por racion, y no concuerda con
## produce/mes gasta/mes». Habia dos cosas distintas llamadas RACION -la unidad
## fisica de la ficha y las [Materia.KCAL_RACION] calorias- y aqui se comprueba
## que ya solo hay una: que la columna GASTA/MES sumada sea exactamente lo que
## la banda come en un mes, y que HAY sumado sea la despensa.


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sim := SettlementSim.new()
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.apply_priorities()
	for kind: int in [Materia.Kind.CARNE, Materia.Kind.BAYA,
			Materia.Kind.FRUTO_SECO, Materia.Kind.PESCADO]:
		sim.store.add(kind as Materia.Kind, 40.0)

	print("")
	print("=== LA COMIDA, UNIDAD POR UNIDAD ===")
	print("%-14s %-9s %8s %8s %9s %9s" % [
		"", "unidad", "kcal", "raciones", "HAY", "GASTA/MES"])

	var bocas := 0.0
	for person: Inhabitant in sim.people:
		bocas += person.daily_food()

	var hay := 0.0
	var gasta := 0.0
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		if not Materia.is_food(k):
			continue
		var rate := Materia.nutrition(k)
		var units := sim.store.amount(k)
		var need := sim.material_needed(k)
		hay += units * rate
		gasta += need * rate
		if units <= 0.0 and need <= 0.0:
			continue
		print("%-14s %-9s %8.0f %8.2f %9.1f %9.1f" % [
			Materia.material_name(k), Materia.unit_name(k),
			Materia.kcal(k), rate, units * rate, need * rate])

	print("")
	print("suma de HAY:       %8.1f raciones · la despensa dice %.1f" % [
		hay, sim.store.food_rations()])
	print("suma de GASTA/MES: %8.1f raciones · la banda come %.1f al dia" % [
		gasta, bocas]
		+ " x %d dias = %.1f" % [sim.CONSUMO_DIAS, bocas * float(sim.CONSUMO_DIAS)])
	print("")
	print("una persona come %.1f raciones al dia (%.0f kcal / %.0f por racion)" % [
		Materia.KCAL_DIA / Materia.KCAL_RACION, Materia.KCAL_DIA,
		Materia.KCAL_RACION])
	# Y que ninguna unidad se llame ya como la medida, que era el lio entero.
	var chocan: Array[String] = []
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		if Materia.unit_name(k).to_lower().begins_with("raci"):
			chocan.append(Materia.material_name(k))
	print("unidades que se llaman «racion»: %s" % (
		"ninguna" if chocan.is_empty() else ", ".join(chocan)))
	quit()
