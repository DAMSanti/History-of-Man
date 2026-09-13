class_name TestTraslado
extends TestCase
## Mudar el campamento a otra cueva: sólo si se llega, con lo que se pueda
## cargar, las obras se quedan, y la banda se asienta al llegar.
##
## Pedido por el usuario el 2026-09-13. El terreno es [FakeTerrain]: casa al sur
## de un río infranqueable en z ∈ (1460, 1540).

const CASA := Vector3(700.0, 200.0, 700.0)
const CUEVA_VIEJA := 1
const CUEVA_NUEVA := 2
const LEJOS := 3

## Una cueva al sur, que se llega, y otra al norte del río, que no.
const CAMPA_NUEVA := Vector3(900.0, 200.0, 900.0)
const CAMPA_AL_OTRO_LADO := Vector3(700.0, 200.0, 1800.0)


func suite_name() -> String:
	return "Traslado"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = CASA
	sim._rng.seed = 11
	sim.exploracion.cueva_de_la_banda = CUEVA_VIEJA
	for i in range(3):
		var p := Inhabitant.create(i, CASA, sim._rng)
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	return sim


func test_no_se_muda_adonde_no_se_llega() -> void:
	var sim := _sim()
	assert_eq(sim.traslado.lo_que_falta(LEJOS, CAMPA_AL_OTRO_LADO),
		"no se llega andando desde la cueva de ahora", "con un río de por medio, no")
	assert_false(sim.traslado.mandar(LEJOS, CAMPA_AL_OTRO_LADO, CAMPA_AL_OTRO_LADO,
		CAMPA_AL_OTRO_LADO), "y no sale nadie")
	assert_false(sim.traslado.en_marcha(), "la banda sigue donde estaba")


func test_no_se_muda_a_la_cueva_donde_ya_vive() -> void:
	var sim := _sim()
	assert_eq(sim.traslado.lo_que_falta(CUEVA_VIEJA, CAMPA_NUEVA),
		"la banda ya vive aquí", "a la suya no hay adónde ir")


func test_se_llevan_lo_que_pueden_cargar_y_lo_demas_se_queda() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.FRUTO_SECO, 20.0)
	sim.store.add(Materia.Kind.PIEDRA, 4000.0)
	assert_true(sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA),
		"a una cueva a la que se llega, sí")
	assert_eq(sim.store.amount(Materia.Kind.PIEDRA), 0.0, "el almacén se vacía")
	var cargado := 0.0
	for p: Inhabitant in sim.people:
		assert_lt(p.load_kg(), p.carry_limit_kg() + 0.01, "nadie carga más de lo que puede")
		cargado += float(p.load.get(Materia.Kind.PIEDRA, 0.0))
	var dejado: Dictionary = sim.traslado.dejado.get(CUEVA_VIEJA, {})
	assert_gt(float(dejado.get(Materia.Kind.PIEDRA, 0.0)), 0.0,
		"cuatro mil piedras no caben en tres espaldas: el resto se queda")
	assert_eq(cargado + float(dejado.get(Materia.Kind.PIEDRA, 0.0)), 4000.0,
		"y no se pierde ni una: o va a cuestas o se queda")


func test_la_comida_se_carga_antes_que_la_piedra() -> void:
	var sim := _sim()
	sim.store.add(Materia.Kind.PIEDRA, 4000.0)
	sim.store.add(Materia.Kind.FRUTO_SECO, 20.0)
	sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA)
	assert_false((sim.traslado.dejado.get(CUEVA_VIEJA, {}) as Dictionary).has(
		Materia.Kind.FRUTO_SECO), "de qué comer no se deja atrás")


func test_mientras_se_mudan_todos_andan_y_nadie_trabaja() -> void:
	var sim := _sim()
	sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA)
	for p: Inhabitant in sim.people:
		assert_eq(int(p.state), int(Inhabitant.State.YENDO), "todos en camino")


func test_al_llegar_todos_la_banda_se_asienta_y_las_obras_se_quedan() -> void:
	var sim := _sim()
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.hearth_lit = true
	sim.store.add(Materia.Kind.FRUTO_SECO, 10.0)
	var avisos: Array = []
	sim.campamento_trasladado.connect(func(c: int) -> void: avisos.append(c))
	sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA)

	# Un estado lejano se construye: todos en la campa nueva.
	for p: Inhabitant in sim.people:
		p.position = CAMPA_NUEVA
	sim.traslado.revisar()

	assert_false(sim.traslado.en_marcha(), "se acabó la mudanza")
	assert_eq(sim.home_position, CAMPA_NUEVA, "la casa es la cueva nueva")
	assert_eq(sim.exploracion.cueva_de_la_banda, CUEVA_NUEVA, "y es la de la banda")
	assert_false(sim.camp_built.get(CampProjects.Kind.HOGAR, false),
		"el hogar se quedó en la vieja: hay que levantarlo otra vez")
	assert_false(sim.hearth_lit, "y aquí no hay fuego")
	assert_eq(sim.store.amount(Materia.Kind.FRUTO_SECO), 10.0,
		"lo que traían, al almacén")
	assert_eq(avisos, [CUEVA_NUEVA], "y se avisa a la vista")


func test_si_uno_no_ha_llegado_no_se_asienta() -> void:
	var sim := _sim()
	sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA)
	sim.people[0].position = CAMPA_NUEVA
	sim.people[1].position = CAMPA_NUEVA
	sim.traslado.revisar()
	assert_true(sim.traslado.en_marcha(), "se espera a todos")


func test_volver_a_la_cueva_vieja_recupera_obras_y_lo_que_se_dejo() -> void:
	var sim := _sim()
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.store.add(Materia.Kind.PIEDRA, 4000.0)
	sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA)
	for p: Inhabitant in sim.people:
		p.position = CAMPA_NUEVA
	sim.traslado.revisar()

	# Y de vuelta.
	sim.traslado.mandar(CUEVA_VIEJA, CASA, CASA, CASA)
	for p: Inhabitant in sim.people:
		p.position = CASA
	sim.traslado.revisar()
	assert_true(sim.camp_built.get(CampProjects.Kind.HOGAR, false),
		"el hogar seguía allí")
	assert_eq(sim.store.amount(Materia.Kind.PIEDRA), 4000.0,
		"y la piedra que no cupo, también")


func test_con_el_camino_acabado_al_pie_de_la_cueva_cuenta_como_llegado() -> void:
	# La campa de una cueva cae en ladera, en celda cerrada: el camino deja a la
	# gente a unos cincuenta metros. Medido en la partida: 51–52 m.
	var sim := _sim()
	sim.traslado.mandar(CUEVA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA, CAMPA_NUEVA)
	var p: Inhabitant = sim.people[0]
	p.route.clear()
	p.position = CAMPA_NUEVA + Vector3(50.0, 0.0, 0.0)
	assert_true(sim.traslado.ha_llegado(p), "a cincuenta metros y sin camino, llegado")
	p.position = CAMPA_NUEVA + Vector3(200.0, 0.0, 0.0)
	assert_false(sim.traslado.ha_llegado(p), "a doscientos, no")
