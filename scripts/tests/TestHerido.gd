class_name TestHerido
extends TestCase
## Quien está tocado se queda en el abrigo.
##
## Frente 12 de EPOCA_01 §10.1, tanda 3. Hasta el 2026-09-13 un percance sólo
## bajaba lo que la persona rendía —`Inhabitant.hurt_factor`— y para poder salir
## a trabajar se miraba **sólo la edad**: se salía igual, con la pierna mal.
##
## El estado se construye, no se simula: un percance es un contador de días.


func suite_name() -> String:
	return "Herido"


func _sim(cuantos: int = 4) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	var gente: Array[Inhabitant] = []
	for i in range(cuantos):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.ADULTO
		gente.append(p)
	sim.people = gente
	return sim


## Uno que caza, con la caza menor puesta como primera opción.
func _cazador(sim: SettlementSim, indice: int = 0) -> Inhabitant:
	var person: Inhabitant = sim.people[indice]
	person.set_priority(Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MENOR), 1)
	return person


func test_el_tocado_no_sale_a_su_oficio() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	person.hurt_days = 3
	sim.apply_priorities()
	assert_true(person.job == Profession.Job.HOGAR,
		"con un percance se queda en el abrigo, no sale a cazar")


func test_tres_jornadas_tocado_son_tres_sin_salir() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	person.hurt_days = 3
	for dia in range(3):
		sim.apply_priorities()
		assert_true(person.job != Profession.Job.CAZA,
			"jornada %d: sigue sin salir" % (dia + 1))
		person.hurt_days -= 1


func test_curado_vuelve_exactamente_a_lo_suyo() -> void:
	# Sin guardar ni devolver nada: las prioridades son del jugador y no se
	# tocan, así que al curarse vuelve solo. Es lo que la berrea sí tiene que
	# hacer a mano, porque ésa SÍ las cambia.
	var sim := _sim()
	var person := _cazador(sim)
	var antes := person.priorities.duplicate()
	person.hurt_days = 2
	sim.apply_priorities()
	person.hurt_days = 0
	sim.apply_priorities()
	assert_eq(person.job, Profession.Job.CAZA, "curado, vuelve a su oficio")
	assert_eq(person.priorities, antes, "y con las prioridades de antes, intactas")


func test_el_sano_si_sale() -> void:
	# El control: sin esto, «no sale» podría ser que no saliera nadie.
	var sim := _sim()
	var person := _cazador(sim)
	sim.apply_priorities()
	assert_eq(person.job, Profession.Job.CAZA, "quien está entero sale a lo suyo")


func test_al_tocado_se_le_da_trabajo_de_hogar() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	person.hurt_days = 4
	sim.apply_priorities()
	assert_eq(person.job, Profession.Job.HOGAR,
		"aunque no tuviera el hogar entre lo suyo, es lo que puede hacer")


func test_no_se_manda_de_expedicion_a_un_tocado() -> void:
	var sim := _sim(6)
	sim.store.add(Materia.Kind.CARNE_SECA, 400.0)
	# Y el vivac, que la expedición también se lleva. Ver
	# [Expedicion.hace_falta_para].
	sim.store.add(Materia.Kind.PIEL, 10.0)
	sim.store.add(Materia.Kind.LENA, 200.0)
	for i in range(4):
		sim.people[i].hurt_days = 5
	assert_false(sim.expedicion.mandar(3, 1000),
		"con sólo dos sanos no sale la expedición de tres")
	sim.people[0].hurt_days = 0
	assert_true(sim.expedicion.mandar(3, 1000),
		"y en cuanto se cura uno, ya son tres")
	for person: Inhabitant in sim.people:
		assert_false(person.esta_tocado() and sim.expedicion.fuera.has(person.id),
			"nadie tocado va en la expedición")
