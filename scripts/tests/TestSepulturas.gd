class_name TestSepulturas
extends TestCase
## La sepultura: una decisión al morir alguien, con coste, y lo que deja.
##
## Frente 27 de EPOCA_01 §10.1, tanda 4.


func suite_name() -> String:
	return "Sepulturas"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.techs = TechTree.new()
	for i in range(3):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = ["Anda", "Beru", "Caro"][i]
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	sim.store.add(Materia.Kind.PIEDRA, 20.0)
	sim.store.add(Materia.Kind.OCRE, 5.0)
	sim.store.add(Materia.Kind.CONCHA, 5.0)
	return sim


func test_morir_trae_la_decision_con_el_coste_escrito() -> void:
	var sim := _sim()
	var citados: Array = []
	sim.moment_raised.connect(func(m: Moment) -> void: citados.append(m))
	sim._person_dies(sim.people[0], "Anda muere.")
	assert_eq(citados.size(), 1, "sale una decisión")
	var momento: Moment = citados[0]
	assert_eq(momento.options.size(), 3, "dejarlo, cubrirlo o enterrarlo")
	var enterrar: Dictionary = momento.options[2]
	assert_eq(float((enterrar["cuesta"] as Dictionary)[Materia.Kind.OCRE]), 1.0,
		"el ajuar escribe su ocre")
	assert_eq(int((enterrar["cuesta"] as Dictionary)["duelo"]),
		int(Sepulturas.DUELO[Sepulturas.Despedida.ENTERRAR]), "y su duelo")


func test_enterrar_con_ajuar_gasta_exactamente_lo_que_dice() -> void:
	var sim := _sim()
	assert_true(sim.sepulturas.despedir("Anda", Vector3.ZERO,
		Sepulturas.Despedida.ENTERRAR), "hay con qué")
	assert_eq(sim.store.amount(Materia.Kind.PIEDRA), 16.0, "cuatro de piedra")
	assert_eq(sim.store.amount(Materia.Kind.OCRE), 4.0, "uno de ocre")
	assert_eq(sim.store.amount(Materia.Kind.CONCHA), 3.0, "dos conchas")


func test_sin_ajuar_la_opcion_sale_apagada_con_lo_que_falta() -> void:
	var sim := _sim()
	sim.store.take(Materia.Kind.OCRE, 5.0)
	assert_eq(sim.sepulturas.lo_que_falta(Sepulturas.Despedida.ENTERRAR),
		"falta ocre", "se dice qué falta")
	assert_false(sim.sepulturas.despedir("Anda", Vector3.ZERO,
		Sepulturas.Despedida.ENTERRAR), "y no se entierra")


func test_las_tres_despedidas_dejan_cosas_distintas() -> void:
	var duelos: Dictionary = {}
	var cronicas: Dictionary = {}
	for despedida: int in [0, 1, 2]:
		var sim := _sim()
		sim.sepulturas.despedir("Anda", Vector3.ZERO, despedida as Sepulturas.Despedida)
		duelos[despedida] = sim.people[1].duelo_dias
		cronicas[String(sim.chronicle.entries[-1]["text"])] = true
	assert_eq(duelos.size(), 3, "tres despedidas")
	assert_gt(float(duelos[0]), float(duelos[1]), "dejarlo alarga el duelo")
	assert_gt(float(duelos[1]), float(duelos[2]), "y el ajuar lo acorta")
	assert_eq(cronicas.size(), 3, "y la crónica cuenta las tres distinto")


func test_de_duelo_se_rinde_menos() -> void:
	var sim := _sim()
	var antes := sim.people[1].effectiveness()
	sim.sepulturas.despedir("Anda", Vector3.ZERO, Sepulturas.Despedida.CUBRIR)
	assert_lt(sim.people[1].effectiveness(), antes, "la banda lo nota en el trabajo")
	for i in range(int(Sepulturas.DUELO[Sepulturas.Despedida.CUBRIR])):
		sim.sepulturas.nueva_jornada()
	assert_eq(sim.people[1].effectiveness(), antes, "y se le pasa")


func test_la_primera_con_ajuar_es_hito_y_la_segunda_no() -> void:
	var sim := _sim()
	sim.sepulturas.despedir("Anda", Vector3.ZERO, Sepulturas.Despedida.ENTERRAR)
	sim.sepulturas.despedir("Beru", Vector3.ZERO, Sepulturas.Despedida.ENTERRAR)
	var hitos := 0
	for relato: Tale in sim.tales:
		if relato.kind == Tale.Kind.HITO:
			hitos += 1
	assert_eq(hitos, 1, "sólo hay una primera sepultura")


func test_la_tumba_queda_apuntada_y_a_quien_se_deja_no() -> void:
	var sim := _sim()
	sim.sepulturas.despedir("Anda", Vector3(5, 0, 5), Sepulturas.Despedida.DEJAR)
	assert_eq(sim.sepulturas.tumbas.size(), 0, "dejarlo no marca sitio")
	sim.sepulturas.despedir("Beru", Vector3(9, 0, 9), Sepulturas.Despedida.CUBRIR)
	assert_eq(sim.sepulturas.tumbas.size(), 1, "cubrirlo, sí")
	assert_eq(sim.sepulturas.tumbas[0]["donde"], Vector3(9, 0, 9), "donde murió")


# -------------------- la muerte se cuenta (depurar, 2026-09-13) --
#
# Queja del usuario: «cuando alguien muere debe decirme cómo murió; debe ser un
# acontecimiento que le importe al jugador, con una pequeña historia, no un
# mensaje robótico de "alguien ha muerto"». La tarjeta decía «Ha muerto Anda ·
# La banda tiene que decidir qué se hace con el cuerpo», y la causa se quedaba
# en la crónica.

func _muere_anda(sim: SettlementSim) -> Moment:
	var anda: Inhabitant = sim.people[0]
	anda.age_years = 34
	anda.job = Profession.Job.CAZA
	anda.log_hours(Profession.Job.CAZA, 900.0)
	anda.log_gain(Profession.Job.CAZA, Materia.Kind.CARNE, 420.0)
	var citados: Array = []
	sim.moment_raised.connect(func(m: Moment) -> void: citados.append(m))
	sim._person_dies(anda, "Anda murió en una caída en el Cantizal: no volvió del monte.")
	assert_eq(citados.size(), 1, "sale la tarjeta")
	return citados[0] if citados.size() == 1 else Moment.new()


func test_la_tarjeta_dice_como_murio() -> void:
	var momento := _muere_anda(_sim())
	assert_true(momento.text.contains("caída en el Cantizal"),
		"la causa va en la tarjeta: %s" % momento.text)


func test_la_tarjeta_cuenta_un_trozo_de_su_vida() -> void:
	var momento := _muere_anda(_sim())
	assert_true(momento.text.contains("34"), "su edad: %s" % momento.text)
	assert_true(momento.text.to_lower().contains(
		Profession.job_name(Profession.Job.CAZA).to_lower()),
		"de qué vivía: %s" % momento.text)
	assert_true(momento.text.contains("Beru") or momento.text.contains("Caro"),
		"y a quién deja: %s" % momento.text)
	assert_eq(momento.options.size(), 3, "y debajo, las despedidas de siempre")
