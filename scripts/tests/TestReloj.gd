class_name TestReloj
extends TestCase
## Una sola fecha para toda la partida: SISTEMAS §23, tarea 4.
##
## Con un campamento, el reloj era de la simulación y bastaba. Con dos, cada una
## daba sus pasos por su cuenta: en cuanto una saltaba la noche y la otra no, ya
## no estaban en la misma hora, y las dos giraban la estación global —la
## primavera habría llegado dos veces—. Aquí se comprueba el reloj que las lleva
## juntas, con simulaciones de mentira que andan sobre `FakeTerrain`: no hace
## falta un valle para saber si dos relojes van a la par.

## Los nodos que crea cada prueba, para soltarlos en la siguiente.
var _nodos: Array[Node] = []


func suite_name() -> String:
	return "Reloj"


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()


## Una simulación que puede dar pasos, la receta de [TestInstantanea].
func _sim(semilla: int) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var people: Array[Inhabitant] = []
	for i in range(4):
		people.append(Inhabitant.create(i, Vector3.ZERO, rng))
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	sim._rng.seed = semilla
	var terreno := FakeTerrain.new()
	sim._terrain = terreno
	sim.home_position = Vector3(700.0, 200.0, 700.0)
	for persona: Inhabitant in sim.people:
		persona.position = sim.home_position
	sim.hour = 7.0
	_nodos.append(sim)
	_nodos.append(terreno)
	return sim


func _reloj(sims: Array[SettlementSim]) -> RelojDeLaPartida:
	var reloj := RelojDeLaPartida.new()
	_nodos.append(reloj)
	for sim: SettlementSim in sims:
		reloj.dirigir(sim)
	return reloj


## Todos dormidos: la noche se puede saltar.
func _a_dormir(sim: SettlementSim) -> void:
	for persona: Inhabitant in sim.people:
		persona.state = Inhabitant.State.DURMIENDO


# --- la fecha es una ------------------------------------------------------

func test_dos_campamentos_van_a_la_misma_hora() -> void:
	var a := _sim(11)
	var b := _sim(22)
	var reloj := _reloj([a, b])
	reloj.time_scale = 5.0
	for i in range(60):
		reloj._process(1.0 / 30.0)
	assert_true(a.hour > 7.0, "el reloj ha andado: %.3f h" % a.hour)
	assert_eq(a.day, b.day, "la misma jornada")
	assert_near(a.hour, b.hour, 0.000001, "y la misma hora")


func test_un_campamento_dirigido_no_da_pasos_por_su_cuenta() -> void:
	# Si la simulación siguiera dando pasos en su propio `_process`, iría el doble
	# de deprisa que las demás en cuanto se la dirigiera.
	var a := _sim(11)
	_reloj([a])
	a.time_scale = 5.0
	a._process(1.0)
	assert_near(a.hour, 7.0, 0.000001, "sin el reloj, la simulación dirigida no anda")


func test_una_decision_en_un_campamento_para_a_todos() -> void:
	var a := _sim(11)
	var b := _sim(22)
	var reloj := _reloj([a, b])
	reloj.time_scale = 5.0
	reloj._process(1.0 / 30.0)
	# Lo que hace la interfaz al levantarse una decisión: parar ESA simulación.
	a.time_scale = 0.0
	reloj._process(1.0 / 30.0)
	assert_eq(reloj.time_scale, 0.0, "el reloj de la partida se para")
	assert_eq(b.time_scale, 0.0, "y con él el otro campamento")
	var hora_b := b.hour
	reloj._process(1.0)
	assert_eq(b.hour, hora_b, "que ya no avanza")


func test_un_campamento_que_se_suma_en_pausa_no_la_quita() -> void:
	# Una simulación recién montada trae velocidad 1. Si el reloj la tomara por
	# un cambio del jugador, sumar un campamento con la partida parada la
	# pondría en marcha para todos.
	var a := _sim(11)
	var reloj := _reloj([a])
	a.time_scale = 0.0
	reloj._process(1.0 / 30.0)
	var b := _sim(22)
	reloj.dirigir(b)
	reloj._process(1.0 / 30.0)
	assert_eq(reloj.time_scale, 0.0, "la partida sigue en pausa")
	assert_eq(b.time_scale, 0.0, "y el que se suma, también")


func test_el_primer_campamento_en_pausa_deja_la_partida_en_pausa() -> void:
	# `setup` deja la simulación parada hasta la decisión del arranque. Si el
	# reloj le pusiera la suya, andaría mientras se monta el resto.
	var a := _sim(11)
	a.time_scale = 0.0
	var reloj := _reloj([a])
	var hora := a.hour
	reloj._process(1.0)
	assert_eq(reloj.time_scale, 0.0, "el reloj toma la pausa del primero")
	assert_eq(a.hour, hora, "y no da ni un paso")


# --- en paralelo ----------------------------------------------------------

func test_en_paralelo_y_en_serie_dan_la_misma_partida() -> void:
	# El mecanismo, con simulaciones de mentira: noventa pasos —hora y media a
	# ×5, sin cruzar medianoche, así que todos van en paralelo— y las dos
	# firmas de cada modo iguales. Las carreras de verdad salen con valles de
	# verdad: eso lo mira `CampamentosProbe`, dos veces.
	var firmas := {}
	for en_paralelo: bool in [false, true]:
		var a := _sim(11)
		var b := _sim(22)
		a.time_scale = 5.0
		b.time_scale = 5.0
		var reloj := _reloj([a, b])
		reloj.paralelo = en_paralelo
		for i in range(90):
			reloj._un_paso_a_todos()
		firmas[en_paralelo] = [FirmaDiaria.de(a).firma, FirmaDiaria.de(b).firma]
		assert_true(a.hour > 7.0, "han andado (%s)" % ("paralelo" if en_paralelo else "serie"))
	assert_eq(firmas[true], firmas[false],
		"en paralelo, la misma partida que en serie para los dos campamentos")


func test_el_paso_que_cruza_medianoche_va_en_serie() -> void:
	var a := _sim(11)
	var b := _sim(22)
	a.hour = 23.999
	b.hour = 23.999
	a.time_scale = 5.0
	var reloj := _reloj([a, b])
	reloj._del_paso.assign([a, b])
	assert_true(reloj._cruza_la_medianoche(), "a un segundo de las doce, cruza")
	a.hour = 12.0
	b.hour = 12.0
	assert_false(reloj._cruza_la_medianoche(), "a mediodía, no")


# --- las decisiones, en la barrera ----------------------------------------

func test_una_decision_dentro_del_paso_sale_en_la_barrera() -> void:
	# Un jugador nunca contesta a mitad de paso: la tarjeta para el reloj y se
	# contesta entre pasos. Con varios campamentos, además, la barra es una sola.
	# Así que la decisión que un campamento dirigido levanta DENTRO de su paso se
	# guarda, y el reloj la entrega al acabar la vuelta.
	var a := _sim(11)
	var reloj := _reloj([a])
	var salidas: Array[bool] = []
	a.moment_raised.connect(func(_m: Moment) -> void: salidas.append(a._en_paso))
	a._en_paso = true
	a.raise_moment(Moment.new())
	assert_eq(salidas.size(), 0, "dentro del paso no sale")
	a._en_paso = false
	reloj._un_paso_a_todos()
	assert_eq(salidas.size(), 1, "sale en la barrera")
	assert_false(salidas[0], "y ya fuera del paso")


func test_fuera_de_un_paso_la_decision_sale_al_momento() -> void:
	# El arranque de la partida o un clic no están dentro de ningún paso.
	var a := _sim(11)
	_reloj([a])
	var salidas := [0]
	a.moment_raised.connect(func(_m: Moment) -> void: salidas[0] += 1)
	a.raise_moment(Moment.new())
	assert_eq(int(salidas[0]), 1, "sale en el acto")


# --- la noche -------------------------------------------------------------

func test_la_noche_no_se_acelera_si_alguien_trabaja_en_otro_campamento() -> void:
	# Se comprueba la DECISIÓN del reloj y no dando pasos. Dando pasos, alguien
	# puesto a mano «trabajando» a la una de la noche se va a dormir en el
	# primer tick —es lo que hace la banda, no un fallo— y la prueba medía eso.
	var dormidos := _sim(11)
	var trabajando := _sim(22)
	_a_dormir(dormidos)
	_a_dormir(trabajando)
	trabajando.people[0].state = Inhabitant.State.TRABAJANDO
	var reloj := _reloj([dormidos, trabajando])
	assert_true(dormidos.nadie_trabaja(), "en un campamento duermen todos")
	assert_false(reloj._nadie_trabaja_en_ninguno(),
		"pero con alguien trabajando en el otro, la noche no se salta")
	trabajando.people[0].state = Inhabitant.State.DURMIENDO
	assert_true(reloj._nadie_trabaja_en_ninguno(),
		"y en cuanto se acuesta, sí")


func test_con_todos_durmiendo_en_todos_la_noche_se_acelera() -> void:
	var a := _sim(11)
	var b := _sim(22)
	_a_dormir(a)
	_a_dormir(b)
	var reloj := _reloj([a, b])
	reloj.time_scale = 1.0
	a.hour = 1.0
	b.hour = 1.0
	reloj._process(1.0)
	assert_true(a.hour - 1.0 > 0.5,
		"con los dos durmiendo se salta la noche: %.3f h" % (a.hour - 1.0))
	assert_near(a.hour, b.hour, 0.000001, "y los dos a la par")


# --- la estación ----------------------------------------------------------

func test_la_estacion_gira_una_vez_con_dos_campamentos() -> void:
	var estacion := GameState.season
	var anyo := GameState.year
	GameState.season = Subsistence.Season.INVIERNO
	var a := _sim(11)
	var b := _sim(22)
	_reloj([a, b])
	a._advance_local_season()
	b._advance_local_season()
	var girada := GameState.season
	var anyo_girado := GameState.year
	var la_de_b := b.estacion
	GameState.season = estacion
	GameState.year = anyo
	assert_eq(girada, Subsistence.Season.PRIMAVERA,
		"del invierno a la primavera, una sola vez aunque giren los dos")
	assert_eq(anyo_girado, anyo + 1, "y el año sube uno, no dos")
	assert_eq(la_de_b, Subsistence.Season.PRIMAVERA,
		"y el segundo campamento está en primavera en su copia")


## La última hora de la última jornada del verano, lista para cruzar.
func _al_filo_del_otono(sim: SettlementSim) -> void:
	sim.hour = 23.9
	sim.season_day = Subsistence.DAYS_PER_SEASON - 1
	sim.time_scale = 5.0


func test_dirigida_y_suelta_cruzan_la_estacion_con_la_misma_firma() -> void:
	# LA PRUEBA DE LA COPIA DE LA FECHA. Una simulación dirigida lee y gira su
	# copia; una suelta, la global. Si en algún sitio del cambio de estación se
	# leyera la que no toca, las dos partidas se separarían justo ahí, y es un
	# sitio que diez jornadas de sonda no cruzan nunca: la estación dura 45. Se
	# construye el filo y se cruza.
	var estacion := GameState.season
	var anyo := GameState.year

	GameState.season = Subsistence.Season.VERANO
	GameState.year = 3
	var suelta := _sim(33)
	_al_filo_del_otono(suelta)
	for i in range(40):
		suelta._advance(SettlementSim.PASO_FIJO)
	var firma_suelta := FirmaDiaria.de(suelta).firma
	var girada_suelta := suelta.estacion

	GameState.season = Subsistence.Season.VERANO
	GameState.year = 3
	var dirigida := _sim(33)
	_al_filo_del_otono(dirigida)
	_reloj([dirigida])
	for i in range(40):
		dirigida._advance(SettlementSim.PASO_FIJO)
	var firma_dirigida := FirmaDiaria.de(dirigida).firma
	var girada_dirigida := dirigida.estacion

	GameState.season = estacion
	GameState.year = anyo
	assert_eq(girada_suelta, Subsistence.Season.OTONO, "la suelta ha entrado en otoño")
	assert_eq(girada_dirigida, Subsistence.Season.OTONO, "y la dirigida también")
	assert_eq(firma_dirigida, firma_suelta,
		"y es la misma partida, leyendo cada una su fecha")


func test_una_simulacion_sola_sigue_girando_la_estacion() -> void:
	# Sin reloj de la partida —las pruebas, las sondas de un mapa— se comporta
	# como siempre.
	var estacion := GameState.season
	GameState.season = Subsistence.Season.VERANO
	var a := _sim(11)
	a._advance_local_season()
	var girada := GameState.season
	GameState.season = estacion
	assert_eq(girada, Subsistence.Season.OTONO, "del verano al otoño")


# --- las decisiones de cualquier campamento (SISTEMAS §23, punto 7) --------

func _campamento_de(sim: SettlementSim, nombre: String) -> Campamento:
	var campamento := Campamento.new()
	campamento.sim = sim
	sim.nombre_del_campamento = nombre
	_nodos.append(campamento)
	return campamento


func test_la_decision_de_otro_campamento_sale_con_su_nombre_y_su_aviso_va_a_la_cronica() -> void:
	var mirado := _sim(11)
	var otro := _sim(22)
	_reloj([mirado, otro])
	Campamentos.vivos.clear()
	Campamentos.vivos.append_array([_campamento_de(mirado, "Altamira"), _campamento_de(otro, "El Pendo")])
	var ui := GameUI.new()
	_nodos.append(ui)
	ui.sim = mirado
	ui.barra.watch_moments(mirado)
	ui.barra.watch_moments(otro)
	mirado.time_scale = 5.0

	var cronica_antes := mirado.chronicle.entries.size()
	otro.raise_moment(Moment.found("Un paraje", "Un claro con avellanos.", Vector3.ZERO))
	assert_true(ui.barra.momento_en_pantalla() == null, "el aviso del otro no sale en tarjeta")
	assert_eq(mirado.chronicle.entries.size(), cronica_antes + 1, "va a la crónica del que se mira")
	assert_true(String(mirado.chronicle.entries.back()["text"]).begins_with("El Pendo:"),
		"con el nombre de su campamento")

	var decision := Moment.found("¿Salir a cazar?", "Hay uros cerca.", Vector3.ZERO)
	decision.options.append({"label": "Sí", "hint": "", "on_pick": func() -> void: pass})
	otro.raise_moment(decision)
	assert_true(ui.barra.momento_en_pantalla() == decision, "la decisión del otro sí sale")
	var cabeza := ui._moment_card.get_child(0).get_child(0).get_child(0).get_child(0) as Label
	assert_true(cabeza.text.ends_with("EL PENDO"), "con el nombre en la tarjeta: %s" % cabeza.text)
	assert_eq(mirado.time_scale, 0.0, "y para el reloj")
	Campamentos.vivos.clear()
	# Aquí y no en `before_each`: es la última prueba del fichero, y una capa de
	# lienzo sin liberar sale como aviso al cerrar la suite.
	before_each()
