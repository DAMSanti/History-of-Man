class_name TestTaller
extends TestCase
## Por que el taller se para solo, y si vuelve.
##
## Nace del 🔴 «El taller se para solo hacia la jornada 31» —EPOCA_01 §10.1,
## «La puerta de entrada»—. Lo medido por `ArbolPasoProbe` es que la practica
## corre a 2,00 jornadas/dia treinta dias y se cae a 0,3 mientras la cuarcita
## del almacen pasa de 96 a 3 054: la banda se va al canchal y no vuelve.
##
## LA JORNADA 31 NO SE SIMULA, SE CONSTRUYE. Correr treinta dias para llegar
## al estado que interesa cuesta minutos y no comprueba nada mas que el estado;
## aqui se escribe el estado —utillaje litico cubierto, almacen con piedra de
## sobra— y se pregunta. Ver CLAUDE.md, «mide barato».


func suite_name() -> String:
	return "Taller"


## Una banda minima con almacen y taller, sin arbol de tecnicas.
##
## Sin `techs`, `Taller.knows_tool` devuelve que si a todo: aqui no se esta
## comprobando el arbol, se esta comprobando que elige el taller cuando puede
## elegir cualquier cosa. Meter el arbol solo taparia la pregunta.
func _sim(size: int = 15) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var people: Array[Inhabitant] = []
	for i in range(size):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		people.append(person)
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	return sim


## Deja el utillaje de una especialidad por encima de la reserva.
##
## `RESERVA_UTILLAJE` es 1,3: con la demanda cubierta a ras, el taller todavia
## tiene trabajo. Se pasa de largo —el triple de lo que se pide— para que no
## quede duda de que lo que para al taller es la cobertura y no el redondeo.
func _cubrir(sim: SettlementSim, speciality: Profession.Speciality) -> void:
	var demand := sim.taller.tool_demand()
	for kind: int in SettlementSim.SPECIALITY_MAKES.get(speciality, []):
		var pedidas: int = int(demand.get(kind, 0))
		for i in range(maxi(pedidas, 1) * 3):
			sim.toolkit.craft(kind as Tool.Kind, Tool.Stuff.CUARCITA, 0.5)


func test_con_el_utillaje_cubierto_el_taller_no_tiene_que_hacer() -> void:
	var sim := _sim()
	# Piedra a espuertas: la cifra medida en la jornada 61 del 🔴.
	sim.store.add(Materia.Kind.PIEDRA, 3054.0)
	_cubrir(sim, Profession.Speciality.TALLA)

	assert_eq(sim.taller._next_piece(Profession.Speciality.TALLA), -1,
		"con la demanda litica cubierta no queda pieza que tallar, "
		+ "por mucha piedra que haya")


func test_y_por_eso_el_reparto_saca_al_artesano_del_taller() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.PIEDRA, 3054.0)
	_cubrir(sim, Profession.Speciality.TALLA)

	# Esta es la cadena entera del 🔴, y el punto que ESTADO.md §2 daba por
	# sospecha: `_speciality_can_work` es `_next_piece(...) >= 0`, y
	# `Reparto.apply_priorities` descarta la tarea cuya especialidad no puede
	# trabajar -ver su comentario, «el artesano se va a su siguiente oficio en
	# vez de quedarse el dia entero delante de un banco vacio»-.
	assert_false(sim._speciality_can_work(Profession.Speciality.TALLA),
		"sin pieza que hacer, la especialidad no puede trabajar")


func test_no_es_falta_de_material_sino_cobertura() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.PIEDRA, 3054.0)
	_cubrir(sim, Profession.Speciality.TALLA)
	var artesano: Inhabitant = sim.people[0]
	artesano.job = Profession.Job.MANUFACTURA
	artesano.current_speciality = Profession.Speciality.TALLA

	# El recado a por materia prima -`_workshop_short`- NO es lo que para al
	# taller: con el almacen asi de lleno no falta nada que comprar. Lo que
	# para al taller es que no hay nada que hacer.
	assert_false(sim.taller._workshop_short(artesano),
		"con 3 054 de piedra no falta materia prima")


func test_con_el_utillaje_gastado_vuelve_a_haber_que_hacer() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.PIEDRA, 3054.0)

	# Sin una sola pieza en el utillaje, la demanda natural esta sin cubrir y
	# el taller tiene trabajo. Es el reverso de la primera prueba: lo que
	# manda es la cobertura, asi que el taller VUELVE cuando algo se rompe.
	assert_true(sim.taller._next_piece(Profession.Speciality.TALLA) >= 0,
		"con el utillaje vacio y piedra de sobra, hay pieza que tallar")
