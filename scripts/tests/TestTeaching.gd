class_name TestTeaching
extends TestCase
## Pruebas de la transmision de conocimiento junto al fuego.
##
## Es la otra mitad de aprender, al lado de la practica en el tajo: cada
## noche, quien esta EN LA CUEVA se acerca un poco a lo que sabe el mejor de
## los presentes. Lo que hay que asegurar es justo lo que pide el diseño:
## que solo cuente quien esta alli esa noche, y que nadie salga sabiendo mas
## que el mejor solo de oidas.


func suite_name() -> String:
	return "Ensenanza"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(400.0, 200.0, 400.0)
	sim._rng.seed = 5
	return sim


func _at_home(sim: SettlementSim, id: int) -> Inhabitant:
	var p := Inhabitant.create(id, sim.home_position, sim._rng)
	p.position = sim.home_position
	p.state = Inhabitant.State.DURMIENDO
	return p


const TASK := 0


func test_quien_sabe_menos_se_acerca_al_que_sabe_mas() -> void:
	var sim := _sim()
	var novato := _at_home(sim, 0)
	var veterano := _at_home(sim, 1)
	novato.skill[TASK] = 0.1
	veterano.skill[TASK] = 0.6
	sim.people = [novato, veterano]

	sim._knowledge_transmission()

	assert_gt(novato.skill_in(TASK), 0.1, "el novato aprende algo esa noche")


func test_nadie_sale_sabiendo_mas_que_el_75_por_ciento_del_maestro() -> void:
	# El maestro tiene un 60%, pero de palabra solo se transmite el 75% de
	# eso: un 45%. El resto -la mano- solo se aprende saliendo a probarlo.
	var sim := _sim()
	var novato := _at_home(sim, 0)
	var veterano := _at_home(sim, 1)
	novato.skill[TASK] = 0.1
	veterano.skill[TASK] = 0.6
	sim.people = [novato, veterano]

	# Muchas noches seguidas: si hubiera fuga, se notaria aqui
	for _night in range(200):
		sim._knowledge_transmission()

	var techo := 0.6 * SettlementSim.TRANSMISSION_CEILING
	assert_true(novato.skill_in(TASK) <= techo + 0.0001,
		"aprender de oidas no supera el 75%% de quien enseña")
	assert_near(novato.skill_in(TASK), techo, 0.01,
		"y con noches de sobra, se acerca de verdad a ese techo")
	assert_eq(veterano.skill_in(TASK), 0.6, "al maestro nadie le quita lo aprendido")


func test_quien_esta_fuera_no_recibe_nada() -> void:
	var sim := _sim()
	var novato := _at_home(sim, 0)
	var veterano := _at_home(sim, 1)
	var explorador := Inhabitant.create(2, sim.home_position, sim._rng)
	explorador.position = sim.home_position + Vector3(900.0, 0.0, 0.0)
	explorador.state = Inhabitant.State.DURMIENDO  # acampado, no en la cueva

	novato.skill[TASK] = 0.1
	veterano.skill[TASK] = 0.6
	explorador.skill[TASK] = 0.1
	sim.people = [novato, veterano, explorador]

	sim._knowledge_transmission()

	assert_eq(explorador.skill_in(TASK), 0.1,
		"quien esta de batida fuera no oye nada de esto")
	assert_gt(novato.skill_in(TASK), 0.1, "y quien si esta en la cueva, si aprende")


func test_una_sola_persona_en_la_cueva_no_transmite_nada() -> void:
	# Hace falta alguien de quien aprender: dormir solo no ensena
	var sim := _sim()
	var solo := _at_home(sim, 0)
	solo.skill[TASK] = 0.2
	sim.people = [solo]

	sim._knowledge_transmission()

	assert_eq(solo.skill_in(TASK), 0.2, "solo no hay de quien aprender")


func test_el_nino_se_acerca_mas_rapido_que_el_anciano_en_la_misma_noche() -> void:
	var sim := _sim()
	var nino := _at_home(sim, 0)
	var anciano := _at_home(sim, 1)
	var veterano := _at_home(sim, 2)
	nino.age_group = Inhabitant.Age.NINO
	anciano.age_group = Inhabitant.Age.ANCIANO
	nino.skill[TASK] = 0.1
	anciano.skill[TASK] = 0.1
	veterano.skill[TASK] = 0.6
	sim.people = [nino, anciano, veterano]

	sim._knowledge_transmission()

	assert_gt(nino.skill_in(TASK) - 0.1, anciano.skill_in(TASK) - 0.1,
		"el crio cierra mas hueco en una sola noche que el anciano")
