extends SceneTree
## Lo que gasta el taller en piedra y sílex, antes y después de la talla laminar.
##
## La cifra que hacía falta para ESTADO §2 al darle efecto a la técnica
## (INTERFAZ §10, EPOCA_01 §7): la laminar deja cada pieza de piedra o de sílex
## a la mitad, y lo que importa saber es cuánta piedra deja de irse del abrigo.
##
## **No simula jornadas**: el gasto de un tramo de taller es lo que piden las
## piezas que el trabajo pide —[Taller.tool_natural_demand], la misma tabla con
## la que el taller decide qué hacer— por lo que cuesta cada una. Correr días
## para llegar a la misma cuenta cuesta minutos y no mide nada más (CLAUDE.md,
## «mide barato»).
##
##   GENTE=15   el tamaño de la banda


func _init() -> void:
	var cuantos := 15
	if not OS.get_environment("GENTE").is_empty():
		cuantos = int(OS.get_environment("GENTE"))

	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260916
	for i in range(cuantos):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		sim.people.append(person)

	var demanda := sim.taller.tool_natural_demand()
	var sabe := TechTree.new()
	sabe.known[TechTree.Tech.HOJA] = true

	var antes := _factura(demanda, null)
	var despues := _factura(demanda, sabe)
	print("banda de %d · el utillaje que pide el trabajo:" % cuantos)
	for kind: int in demanda:
		if int(demanda[kind]) > 0 and Tool.recipe(kind as Tool.Kind).has(
				Materia.Kind.PIEDRA):
			print("   %d %s" % [int(demanda[kind]),
				Tool.kind_name(kind as Tool.Kind).to_lower()])
	print("piedra o silex por tanda: %.1f sin la talla laminar, %.1f con ella"
		% [antes, despues])
	if antes > 0.0:
		print("o sea el %.0f %% de lo que costaba" % (despues / antes * 100.0))
	sim.free()
	quit()


## Lo que cuesta de piedra —o de sílex, que se paga en su lugar— una tanda
## entera del utillaje que pide el trabajo.
func _factura(demanda: Dictionary, techs: TechTree) -> float:
	var total := 0.0
	for kind: int in demanda:
		var receta := Tool.recipe(kind as Tool.Kind, techs)
		total += float(receta.get(Materia.Kind.PIEDRA, 0.0)) * float(demanda[kind])
	return total
