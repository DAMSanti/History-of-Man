class_name TestPartida
extends TestCase
## Pruebas del objetivo de partida: victoria, derrota y el momento inicial.
##
## Nace de docs/specs/QUE_FALTA_PARA_JUGARLO.md.


func suite_name() -> String:
	return "Partida"


func _banda(size: int = 6) -> Array[Inhabitant]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var people: Array[Inhabitant] = []
	for i in range(size):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		Profession.assign(Profession.Job.CAZA, person)
		people.append(person)
	return people


func _sim(people: Array[Inhabitant]) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	return sim


func test_los_tres_kind_nuevos_no_son_decision() -> void:
	for kind: Moment.Kind in [Moment.Kind.INICIO, Moment.Kind.VICTORIA,
			Moment.Kind.DERROTA]:
		var moment := Moment.new()
		moment.kind = kind
		assert_false(moment.is_decision(),
			"un hallazgo que se enseña, no una decisión que tomar")


func test_sim_arranca_con_partida_y_sin_desenlace() -> void:
	var sim := _sim(_banda())

	assert_true(sim.partida != null, "el módulo existe desde que existe el sim")
	assert_eq(sim.desenlace, SettlementSim.Desenlace.NINGUNO,
		"nadie ha ganado ni perdido todavía")


func test_ultima_muerte_declara_derrota() -> void:
	var people := _banda(1)
	var sim := _sim(people)
	# Capturado en un array, no en una variable suelta: un lambda de GDScript
	# captura las locales por valor, así que reasignar una variable de fuera
	# no se ve al salir del closure -TestMishap.gd usa el mismo truco.
	var capturados: Array[Moment] = []
	sim.moment_raised.connect(func(m: Moment) -> void: capturados.append(m))

	sim._person_dies(people[0], "Prueba: murió el último.")

	assert_eq(sim.desenlace, SettlementSim.Desenlace.DERROTA,
		"no queda nadie, la banda se ha extinguido")
	assert_eq(sim.desenlace_dia, sim.day, "con la jornada en que ocurrió")
	assert_eq(capturados.size(), 1, "se lanza un momento de cierre")
	assert_eq(capturados[0].kind, Moment.Kind.DERROTA, "del tipo que corresponde")
	assert_true(capturados[0].text.find("murió el último") >= 0,
		"con la causa de quien murió, no un texto genérico")


## --- «¿Ha terminado?», que es lo que nadie preguntaba ---------------------
##
## Del 🔴 «el cuelgue de la hambruna total» (EPOCA_01 §10.1). No era un bucle
## del juego: era una sonda esperando `while sim.day < hasta` con la banda ya
## muerta, o sea esperando una jornada que `_process` no iba a avanzar nunca.
## Reproducido con `CuelgueProbe`: 4 001 vueltas de fotograma sin que el día
## pasara del 2, vivos 0, el reloj a x5 —no parado— y ni una línea de log.

func test_con_la_banda_extinta_la_partida_ha_terminado() -> void:
	var people := _banda(1)
	var sim := _sim(people)
	assert_false(sim.partida_terminada(), "con gente viva, la partida sigue")

	sim._person_dies(people[0], "Prueba: murió el último.")

	assert_true(sim.partida_terminada(),
		"sin nadie vivo no hay jornada que esperar: quien espere días, para")


func test_la_victoria_tambien_termina_la_partida() -> void:
	var sim := _sim(_banda())
	sim.desenlace = SettlementSim.Desenlace.VICTORIA

	assert_true(sim.partida_terminada(),
		"ganada también se acabó, aunque queden los quince vivos")


func test_una_banda_viva_y_sin_desenlace_no_ha_terminado() -> void:
	var sim := _sim(_banda())

	assert_false(sim.partida_terminada(),
		"ni extinta ni resuelta: la partida sigue y el día avanzará")


func test_muerte_que_no_vacia_la_banda_no_declara_derrota() -> void:
	var people := _banda(3)
	var sim := _sim(people)

	sim._person_dies(people[0], "Prueba: muere uno de tres.")

	assert_eq(sim.desenlace, SettlementSim.Desenlace.NINGUNO,
		"quedan dos vivos, la banda no se ha extinguido")


func _pinturas(cuantas: int) -> Array[Tale]:
	var out: Array[Tale] = []
	for i in range(cuantas):
		out.append(Tale.new())
	return out


func test_banda_viva_y_cueva_pintada_gana() -> void:
	var sim := _sim(_banda())
	sim.paintings = _pinturas(SettlementSim.CUEVA_PINTADA_MINIMO)
	var capturados: Array[Moment] = []
	sim.moment_raised.connect(func(m: Moment) -> void: capturados.append(m))

	sim.partida.evaluar_victoria()

	assert_eq(sim.desenlace, SettlementSim.Desenlace.VICTORIA,
		"vivos y con la cueva pintada: se gana")
	assert_eq(sim.desenlace_dia, sim.day, "con la jornada en que ocurrió")
	assert_eq(capturados.size(), 1, "con su momento de cierre")
	assert_eq(capturados[0].kind, Moment.Kind.VICTORIA, "del tipo que corresponde")


func test_banda_viva_sin_pintar_lo_suficiente_no_gana() -> void:
	var sim := _sim(_banda())
	sim.paintings = _pinturas(SettlementSim.CUEVA_PINTADA_MINIMO - 1)

	sim.partida.evaluar_victoria()

	assert_eq(sim.desenlace, SettlementSim.Desenlace.NINGUNO,
		"sobrevivir no basta si la cueva no está pintada")


func test_momento_inicial_contiene_lo_esencial() -> void:
	var sim := _sim(_banda())

	var moment := sim.partida.momento_inicial()

	assert_eq(moment.kind, Moment.Kind.INICIO, "es el momento de apertura")
	var texto := (moment.title + " " + moment.text).to_lower()
	assert_true(texto.find("sobrevivir") >= 0, "menciona el objetivo de sobrevivir")
	assert_true(texto.find("cueva pintada") >= 0, "y el de pintar la cueva")
	assert_true(texto.find("extingue") >= 0 or texto.find("termina") >= 0,
		"menciona que la partida se puede perder")
	assert_true(texto.find("oficios") >= 0,
		"menciona la primera decisión: repartir oficios")


func test_color_de_los_tres_momentos_nuevos() -> void:
	var barra := BarraSuperior.new(null)
	var colores := {}
	for kind: Moment.Kind in [Moment.Kind.INICIO, Moment.Kind.VICTORIA,
			Moment.Kind.DERROTA]:
		var moment := Moment.new()
		moment.kind = kind
		colores[kind] = barra._moment_tint(moment)

	assert_eq(colores[Moment.Kind.INICIO], UISkin.OCHRE, "inicio en ocre")
	assert_eq(colores[Moment.Kind.VICTORIA], UISkin.GREEN, "victoria en verde de liquen")
	assert_eq(colores[Moment.Kind.DERROTA], UISkin.ALARM, "derrota en hematites")
	assert_true(colores[Moment.Kind.INICIO] != colores[Moment.Kind.VICTORIA]
			and colores[Moment.Kind.VICTORIA] != colores[Moment.Kind.DERROTA]
			and colores[Moment.Kind.INICIO] != colores[Moment.Kind.DERROTA],
		"los tres son distintos entre sí")


func test_indicador_de_riesgo_sube_con_los_enfermos() -> void:
	var sana := _banda(4)
	var enferma := _banda(4)
	enferma[0].cold_sick_days = 3
	enferma[1].hunger_sick_days = 2

	var riesgo_sano := BarraSuperior._risk_share(sana)
	var riesgo_enfermo := BarraSuperior._risk_share(enferma)

	assert_eq(riesgo_sano, 0.0, "nadie enfermo, riesgo cero")
	assert_near(riesgo_enfermo, 0.5, 0.001, "dos de cuatro, la mitad")
	assert_true(riesgo_enfermo > riesgo_sano,
		"la misma banda, enferma, marca más riesgo que sana")


func test_cueva_pintada_sin_banda_viva_no_gana() -> void:
	var vacio: Array[Inhabitant] = []
	var sim := _sim(vacio)
	sim.paintings = _pinturas(SettlementSim.CUEVA_PINTADA_MINIMO + 5)

	sim.partida.evaluar_victoria()

	assert_eq(sim.desenlace, SettlementSim.Desenlace.NINGUNO,
		"pintar no basta si no queda quien lo viva")
