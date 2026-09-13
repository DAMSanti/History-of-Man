class_name TestPractica
extends TestCase
## Qué cuenta como una jornada de práctica, que es lo que hace subir el árbol.
##
## Sale del `/depurar` del 2026-09-13 (EPOCA_01 §10.1, tanda 3, fallo 1): en dos
## años de partida, con material de sobra, las técnicas de ribera y hogar
## seguían en 0 %. La cuenta vivía en `DemoMain`, miraba `has_task` **a
## medianoche** —cuando ya no hay tajo y el reparto del día siguiente ya ha
## corrido— y por eso el hogar, que trabaja en la cueva, no practicaba nunca.
## Medido con `PracticaProbe`: 3 personas 10 jornadas en la orilla y **0
## jornadas de ribera** en el árbol.
##
## Ahora es una regla de la simulación —`SettlementSim._practica_del_dia`— y se
## comprueba construyendo el día, sin simularlo.


func suite_name() -> String:
	return "Practica"


## Una banda con árbol de técnicas y memoria, sin escena.
func _sim(cuantos: int = 4) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.techs = TechTree.new()
	sim.knowledge = BandKnowledge.new()
	for i in range(cuantos):
		var p := Inhabitant.new()
		p.id = i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	return sim


func test_quien_trabaja_en_la_cueva_practica_su_oficio() -> void:
	# EL FALLO EN UNA LÍNEA: el hogar trabaja en la campa de la boca, no tiene
	# tajo en el mapa, y así no practicaba jamás.
	var sim := _sim(2)
	for person: Inhabitant in sim.people:
		person.job = Profession.Job.HOGAR
		person.oficio_de_hoy = Profession.Job.HOGAR
	sim._practica_del_dia()
	assert_near(sim.techs.days_in(Profession.Job.HOGAR), 2.0, 0.001,
		"dos personas en el hogar, dos jornadas de hogar")


func test_una_jornada_por_persona_y_en_su_oficio() -> void:
	var sim := _sim(3)
	sim.people[0].oficio_de_hoy = Profession.Job.RIBERA
	sim.people[1].oficio_de_hoy = Profession.Job.RIBERA
	sim.people[2].oficio_de_hoy = Profession.Job.CAZA
	sim._practica_del_dia()
	assert_near(sim.techs.days_in(Profession.Job.RIBERA), 2.0, 0.001,
		"dos en la orilla, dos jornadas de ribera")
	assert_near(sim.techs.days_in(Profession.Job.CAZA), 1.0, 0.001,
		"y una de caza")
	assert_near(sim.techs.days_in(Profession.Job.MANUFACTURA), 0.0, 0.001,
		"y ninguna de lo que nadie hizo")


func test_quien_no_trabaja_no_practica() -> void:
	# Sin esto la de arriba no prueba nada: si contara todo el mundo, «trabajó»
	# no significaría nada.
	var sim := _sim(2)
	sim.people[0].job = Profession.Job.RIBERA
	sim.people[1].job = Profession.Job.RIBERA
	sim._practica_del_dia()
	assert_near(sim.techs.days_in(Profession.Job.RIBERA), 0.0, 0.001,
		"tener el oficio no es haberlo trabajado")


func test_el_ocioso_no_practica() -> void:
	var sim := _sim(1)
	sim.people[0].oficio_de_hoy = Profession.Job.OCIOSO
	sim._practica_del_dia()
	assert_near(sim.techs.days_in(Profession.Job.OCIOSO), 0.0, 0.001,
		"esperar destino no es un oficio que se practique")


func test_el_dia_siguiente_empieza_a_cero() -> void:
	var sim := _sim(1)
	sim.people[0].oficio_de_hoy = Profession.Job.CAZA
	sim.people[0].actividad_de_hoy = Subsistence.Activity.CAZA
	sim._practica_del_dia()
	sim._practica_del_dia()
	assert_near(sim.techs.days_in(Profession.Job.CAZA), 1.0, 0.001,
		"la jornada de ayer no se cuenta dos veces")
	assert_eq(sim.people[0].oficio_de_hoy, -1, "y el día siguiente empieza limpio")


func test_la_temporada_se_anota_por_lo_trabajado() -> void:
	# La otra mitad de lo que se contaba a medianoche: lo que la banda sabe de
	# cada temporada. Misma bandera, mismo fallo.
	var sim := _sim(1)
	var antes := GameState.season
	GameState.season = Subsistence.Season.OTONO
	sim.people[0].oficio_de_hoy = Profession.Job.RIBERA
	sim.people[0].actividad_de_hoy = Subsistence.Activity.PESCA
	sim._practica_del_dia()
	GameState.season = antes
	assert_true(sim.knowledge.knows_season(
		Subsistence.Activity.PESCA, Subsistence.Season.OTONO),
		"quien pescó en otoño sabe cómo es el otoño en el río")
	assert_false(sim.knowledge.knows_season(
		Subsistence.Activity.CAZA, Subsistence.Season.OTONO),
		"y de lo que no hizo, no sabe nada")


func test_una_tecnica_se_aprende_practicandola() -> void:
	# El extremo de la regla: con las jornadas hechas y el material puesto, la
	# técnica sale, y la simulación lo dice por su señal.
	var sim := _sim(1)
	sim.store.add(Materia.Kind.FIBRA, 40.0)
	sim.techs.larder = sim.store
	var avisos: Array[int] = []
	sim.tecnica_aprendida.connect(func(tech: int) -> void: avisos.append(tech))
	var hacen_falta := int(TechTree.CATALOGUE[TechTree.Tech.LAZO]["days"])
	for dia in range(hacen_falta + 1):
		sim.people[0].oficio_de_hoy = Profession.Job.CAZA
		sim._practica_del_dia()
	assert_true(sim.techs.has(TechTree.Tech.LAZO),
		"con las jornadas y la fibra, el lazo se aprende")
	assert_true(avisos.has(int(TechTree.Tech.LAZO)),
		"y la simulación avisa de que se ha aprendido")


func test_el_arbol_del_paleolitico_no_tiene_piragua() -> void:
	# La piragua monóxila es del Mesolítico —EPOCA_02— y estaba en la rama de
	# exploración del Paleolítico desde antes de que las épocas se repartieran
	# las técnicas. Se quitó el 2026-09-13 (tanda 3, frente 13).
	for tech: int in TechTree.CATALOGUE:
		assert_false(TechTree.tech_name(tech as TechTree.Tech).to_lower().contains("piragua"),
			"ninguna técnica del árbol es la piragua")
	var rama: Array = TechTree.BRANCHES.get(Profession.Job.EXPLORACION, [])
	assert_eq(rama.size(), 1, "la rama de exploración se queda en la pasarela")


func test_el_arbol_del_paleolitico_no_tiene_arco() -> void:
	# El arco es del Mesolítico —Aziliense, EPOCA_02— y lo pidió quitar el
	# usuario el 2026-09-13. La caza del Paleolítico termina en el propulsor.
	for tech: int in TechTree.CATALOGUE:
		assert_false(TechTree.tech_name(tech as TechTree.Tech).to_lower() == "arco",
			"ninguna técnica del árbol es el arco")
	for mejora: Dictionary in (Hunting.MEJORAS[Profession.Speciality.CAZA_MAYOR] as Array):
		assert_true(int(mejora["tech"]) in TechTree.CATALOGUE,
			"y la caza no espera de ninguna técnica que no se pueda aprender")


func test_la_batida_practica_exploracion() -> void:
	# REGRESIÓN DEL 2026-09-13, la metí yo al arreglar la práctica: se apuntaba
	# el trabajo sólo en el estado TRABAJANDO, y la batida corre en
	# RECONOCIENDO. La exploración practicaba cero —«la técnica de exploración
	# no sube con las batidas», dijo el usuario— y las pruebas no lo vieron
	# porque marcaban `oficio_de_hoy` a mano.
	assert_true(SettlementSim.cuenta_como_trabajo(Inhabitant.State.RECONOCIENDO),
		"reconocer es trabajar: la jornada de batida cuenta como exploración")


func test_buscar_tambien_es_trabajar() -> void:
	assert_true(SettlementSim.cuenta_como_trabajo(Inhabitant.State.BUSCANDO),
		"buscar en un paraje cuenta como jornada de su oficio")
	assert_true(SettlementSim.cuenta_como_trabajo(Inhabitant.State.TRABAJANDO),
		"y trabajar, claro")


func test_andar_o_dormir_no_es_trabajar() -> void:
	# El control: ir y volver, dormir o esperar no practican nada.
	for state: Inhabitant.State in [Inhabitant.State.YENDO,
			Inhabitant.State.VOLVIENDO, Inhabitant.State.DURMIENDO,
			Inhabitant.State.OCIOSO]:
		assert_false(SettlementSim.cuenta_como_trabajo(state),
			"%s no es trabajar" % Inhabitant.State.keys()[state])
