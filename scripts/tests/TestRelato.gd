class_name TestRelato
extends TestCase
## Lo que se cuenta al volver, y lo que se queda en la pared.
##
## Las dos mitades, porque la gracia está en la diferencia: contado, un relato
## dura lo que dure quien estuvo; pintado, no. Ver [Tale] y
## `SettlementSim.paintings_ceiling`.


func suite_name() -> String:
	return "Relato"


func _techs(learned: Array) -> TechTree:
	var techs := TechTree.new()
	for t: int in learned:
		techs.known[t as TechTree.Tech] = true
	return techs


func _pintable() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.techs = _techs([TechTree.Tech.ARTE])
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.toolkit.craft(Tool.Kind.LAMPARA, Tool.Stuff.CUARCITA, 0.6)
	sim.store.add(Materia.Kind.OCRE, 20.0)
	sim.store.add(Materia.Kind.GRASA, 20.0)
	return sim


func _relato() -> Tale:
	return Tale.hunt("Beru", "ciervo", "el Vado Alto", 3, true, 12,
		Profession.task_id(Profession.Job.CAZA,
			Profession.Speciality.CAZA_MAYOR))


# --- el relato ------------------------------------------------------------

func test_la_caceria_se_cuenta_con_quien_como_y_donde() -> void:
	var tale := _relato()
	assert_true(tale.text.contains("Beru"), "quién: %s" % tale.text)
	assert_true(tale.text.contains("ciervo"), "qué: %s" % tale.text)
	assert_true(tale.text.contains("Vado Alto"), "dónde: %s" % tale.text)


func test_el_como_cambia_el_relato() -> void:
	# No es lo mismo llegar a tiro sin que te vean que reventar el monte detrás
	# de la pieza. Si las dos se contaran igual, no sería un relato.
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	var callado := Tale.hunt("Beru", "ciervo", "el Vado", 3, true, 12, task)
	var corriendo := Tale.hunt("Beru", "ciervo", "el Vado", 3, false, 12, task)
	assert_true(callado.text != corriendo.text,
		"acechada y perseguida no se cuentan igual")


func test_solo_la_pieza_grande_se_cuenta() -> void:
	# «En el Paleolítico una gran caza no era algo diario»: contar cada conejo
	# del lazo convertiría el relato en ruido.
	var sim := _pintable()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.CAZA
	person.current_speciality = Profession.Speciality.CAZA_MENOR
	sim.people = [person]

	var conejo := Hunt.new()
	conejo.species = "conejo"
	conejo.crew = [person]
	sim._tell_the_hunt(person, conejo)
	assert_eq(sim.tales.size(), 0, "un conejo no se cuenta")

	var ciervo := Hunt.new()
	ciervo.species = "ciervo"
	ciervo.crew = [person]
	sim._tell_the_hunt(person, ciervo)
	assert_eq(sim.tales.size(), 1, "un ciervo sí")


func test_contar_algo_lo_deja_en_la_cronica() -> void:
	var sim := _pintable()
	var antes := sim.chronicle.entries.size()
	sim.tell_tale(_relato())
	assert_gt(float(sim.chronicle.entries.size()), float(antes),
		"lo que se cuenta queda escrito")


func test_aprender_una_tecnica_se_cuenta() -> void:
	# «Cualquier descubrimiento, adelanto tecnológico o hito quiero que se
	# represente también con una historia.»
	var sim := _pintable()
	sim.tell_technique(TechTree.Tech.ARPON)
	assert_eq(sim.tales.size(), 1, "aprender a hacer algo es un hito")
	assert_true(sim.tales[0].title.contains("Arpón"),
		"y se cuenta por su nombre: %s" % sim.tales[0].title)


# --- la pared -------------------------------------------------------------

func test_sin_saber_pintar_no_se_pinta() -> void:
	var sim := _pintable()
	sim.techs = _techs([])
	assert_false(sim.can_paint(), "sin arte parietal no hay pared")
	assert_true(sim.painting_blocked_by().contains("pintar"),
		"y se dice por qué: %s" % sim.painting_blocked_by())


func test_sin_lampara_no_se_pinta_dentro() -> void:
	# Es lo que hace falta de verdad para pintar en una cueva y lo que
	# aparece en Lascaux: un canto ahuecado con grasa y una mecha.
	var sim := _pintable()
	sim.toolkit.pieces.clear()
	assert_false(sim.can_paint(), "a oscuras no se pinta")
	assert_true(sim.painting_blocked_by().contains("lámpara"),
		"y se dice: %s" % sim.painting_blocked_by())


func test_sin_ocre_ni_grasa_no_se_pinta() -> void:
	var sin_ocre := _pintable()
	sin_ocre.store.take(Materia.Kind.OCRE, 20.0)
	assert_true(sin_ocre.painting_blocked_by().contains("ocre"),
		"sin pigmento: %s" % sin_ocre.painting_blocked_by())

	var sin_grasa := _pintable()
	sin_grasa.store.take(Materia.Kind.GRASA, 20.0)
	assert_true(sin_grasa.painting_blocked_by().contains("grasa"),
		"sin combustible: %s" % sin_grasa.painting_blocked_by())


func test_pintar_cuesta_jornadas_ocre_y_grasa() -> void:
	var sim := _pintable()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.HOGAR
	sim.people = [person]

	var tale := _relato()
	assert_true(sim.queue_painting(tale), "se encola")
	var ocre_antes := sim.store.amount(Materia.Kind.OCRE)

	for _i in range(200):
		if sim.painting_queue == null:
			break
		sim._paint_wall(person, 0.1)

	assert_true(tale.painted, "acaba en la pared")
	assert_eq(sim.paintings.size(), 1, "y la pared la guarda")
	assert_lt(sim.store.amount(Materia.Kind.OCRE), ocre_antes,
		"se ha gastado el ocre")


func test_la_pared_sube_el_techo_de_lo_que_se_aprende_de_oidas() -> void:
	# La razón entera de pintar, y lo que dice [TechTree.Tech.ARTE]: fijar lo
	# que se sabe y transmitirlo a quien no estaba.
	var sim := _pintable()
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	assert_near(sim.paintings_ceiling(task), SettlementSim.TRANSMISSION_CEILING,
		0.001, "sin paredes, el techo de siempre")

	var tale := _relato()
	tale.painted = true
	sim.paintings.append(tale)
	assert_gt(sim.paintings_ceiling(task), SettlementSim.TRANSMISSION_CEILING,
		"con la cacería en la pared se aprende más de oídas")


func test_una_pared_de_caza_no_ensena_a_trenzar_cordel() -> void:
	var sim := _pintable()
	var tale := _relato()
	tale.painted = true
	sim.paintings.append(tale)
	var cordel := Profession.task_id(Profession.Job.MANUFACTURA,
		Profession.Speciality.CORDELERIA)
	assert_near(sim.paintings_ceiling(cordel),
		SettlementSim.TRANSMISSION_CEILING, 0.001,
		"un bisonte en la pared no enseña cestería")


func test_el_relato_de_una_tecnica_cubre_el_oficio_entero() -> void:
	# Se aprende a hacer el arpón, no a hacerlo desde la orilla: la técnica no
	# tiene especialidad y por eso cubre todo su oficio.
	var sim := _pintable()
	sim.tell_technique(TechTree.Tech.ARPON)
	var tale := sim.tales[0]
	tale.painted = true
	sim.paintings.append(tale)
	var orilla := Profession.task_id(Profession.Job.RIBERA,
		Profession.Speciality.ORILLA)
	assert_gt(sim.paintings_ceiling(orilla),
		SettlementSim.TRANSMISSION_CEILING,
		"el arpón en la pared enseña a toda la ribera")


func test_el_techo_no_llega_nunca_al_todo() -> void:
	# Una parte de lo que sabe un cazador es la mano, y eso no se aprende
	# mirando una pared por muy buena que sea.
	var sim := _pintable()
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	for _i in range(50):
		var tale := _relato()
		tale.painted = true
		sim.paintings.append(tale)
	assert_lt(sim.paintings_ceiling(task), 1.0,
		"ni con la cueva entera pintada se aprende todo de oídas")
	assert_near(sim.paintings_ceiling(task), SettlementSim.PINTURA_TECHO_MAX,
		0.001, "se para donde dice el tope")


func test_no_se_pinta_lo_ya_pintado_ni_dos_a_la_vez() -> void:
	var sim := _pintable()
	var tale := _relato()
	assert_true(sim.queue_painting(tale), "la primera entra")
	assert_false(sim.queue_painting(_relato()),
		"la segunda espera: sólo hay una pared en marcha")

	tale.painted = true
	sim.painting_queue = null
	assert_false(sim.queue_painting(tale), "y lo ya pintado no se repinta")


func test_el_taller_no_hace_lamparas_antes_de_saber_pintar() -> void:
	# Nadie ahueca un canto para tener luz dentro de la cueva antes de tener
	# algo que hacer dentro de la cueva.
	var sim := SettlementSim.new()
	sim.techs = _techs([])
	assert_eq(int(sim.tool_natural_demand().get(Tool.Kind.LAMPARA, 0)), 0,
		"sin arte parietal no se piden lámparas")

	sim.techs = _techs([TechTree.Tech.ARTE])
	assert_gt(float(sim.tool_natural_demand().get(Tool.Kind.LAMPARA, 0)), 0.0,
		"sabiendo pintar, una")
