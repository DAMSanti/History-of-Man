class_name TestPrioridades
extends TestCase
## Lo que el jugador prioriza: materiales, especies de caza y piezas.
##
## Spec y plan en docs/SISTEMAS.md §22. Aquí se comprueban las tres reglas que
## cambian con el nivel —adónde va la gente, qué entra en la carga y a qué pieza
## se le va— y la de arriba de todas: **con todo en normal, el juego se comporta
## exactamente igual que antes**. Cada regla se construye, no se simula: un
## paraje escrito a mano y un paso, no una partida.


func suite_name() -> String:
	return "Prioridades"


## Una banda mínima, la misma receta que [TestTaller._sim].
func _sim(size: int = 4) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
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


# --- los niveles ----------------------------------------------------------

func test_todo_empieza_en_normal() -> void:
	var sim := _sim()
	assert_eq(sim.prioridades.de_material(Materia.Kind.FRUTO_SECO),
		Prioridades.Nivel.NORMAL, "un material sin tocar está en normal")
	assert_eq(sim.prioridades.de_especie("ciervo"),
		Prioridades.Nivel.NORMAL, "una especie sin tocar, también")
	assert_eq(sim.prioridades.de_pieza(Tool.Kind.AZAGAYA),
		Prioridades.Nivel.NORMAL, "y una pieza")
	assert_false(sim.prioridades.hay_algo_puesto(),
		"y una partida recién empezada no tiene ninguna prioridad puesta")


func test_el_nivel_va_y_vuelve() -> void:
	var sim := _sim()
	sim.fijar_prioridad_material(Materia.Kind.FRUTO_SECO, Prioridades.Nivel.ALTA)
	assert_eq(sim.prioridades.de_material(Materia.Kind.FRUTO_SECO),
		Prioridades.Nivel.ALTA, "lo que se pone se lee")
	assert_true(sim.prioridades.hay_algo_puesto(), "y se nota que hay algo puesto")

	# Volver a normal no deja rastro: lo normal no se guarda, que es lo que hace
	# que una partida sin tocar nada tenga los tres diccionarios vacíos.
	sim.fijar_prioridad_material(Materia.Kind.FRUTO_SECO, Prioridades.Nivel.NORMAL)
	assert_eq(sim.prioridades.de_material(Materia.Kind.FRUTO_SECO),
		Prioridades.Nivel.NORMAL, "y vuelve a normal")
	assert_false(sim.prioridades.hay_algo_puesto(),
		"sin dejar la clave puesta detrás")


# --- la presa -------------------------------------------------------------
#
# La misma receta de [TestCaceria]: la fauna se pone a mano con
# `place_for_test` en vez de levantar el valle entero.

func _sim_de_caza() -> SettlementSim:
	var sim := _sim(0)
	sim.techs = TechTree.new()
	sim.caceria.wildlife = WildlifeHerds.new()
	# Con azagaya en el abrigo, que es la puerta de [Fauna.huntable_with] para
	# la pieza grande: sin ella no se elige uro porque no se puede cobrar.
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.default_stuff(Tool.Kind.AZAGAYA), 0.6)
	sim.toolkit.craft(Tool.Kind.LASCA, Tool.default_stuff(Tool.Kind.LASCA), 0.6)
	return sim


func _cazador(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var person := Inhabitant.create(sim.people.size(), Vector3.ZERO, rng)
	person.job = Profession.Job.CAZA
	person.current_speciality = Profession.Speciality.CAZA_MAYOR
	person.activity = Subsistence.Activity.CAZA
	person.has_task = true
	person.state = Inhabitant.State.TRABAJANDO
	sim.people.append(person)
	return person


## El ciervo al lado y el uro al borde de la búsqueda.
##
## Las distancias están calculadas contra la cuenta de verdad y no puestas a
## ojo: el uro da 140 raciones y el ciervo 62, y la distancia entra elevada a
## 0,35, así que para que gane el ciervo el uro tiene que estar más de diez
## veces más lejos. A 10 y 240 m —`Hunt.BUSCA_PIEZA_M` es 260— sale con margen.
func _ciervo_cerca_y_uro_lejos(sim: SettlementSim) -> void:
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(10.0, 0.0, 0.0))
	sim.caceria.wildlife.place_for_test("uro", Vector3(240.0, 0.0, 0.0))


func test_sin_prioridades_se_elige_la_pieza_de_siempre() -> void:
	var sim := _sim_de_caza()
	var cazador := _cazador(sim)
	_ciervo_cerca_y_uro_lejos(sim)
	var elegida := sim.caceria._pick_quarry(cazador,
		sim.caceria._huntable_species(Profession.Speciality.CAZA_MAYOR))
	assert_eq(String(elegida.get("species", "")), "ciervo",
		"con todo en normal manda la cuenta de raciones entre distancia")


func test_la_especie_en_alta_manda_sobre_la_cuenta() -> void:
	var sim := _sim_de_caza()
	var cazador := _cazador(sim)
	_ciervo_cerca_y_uro_lejos(sim)
	sim.fijar_prioridad_especie("uro", Prioridades.Nivel.ALTA)
	var elegida := sim.caceria._pick_quarry(cazador,
		sim.caceria._huntable_species(Profession.Speciality.CAZA_MAYOR))
	assert_eq(String(elegida.get("species", "")), "uro",
		"se va a por el uro aunque el ciervo esté más cerca")


func test_sin_la_de_alta_a_su_alcance_se_caza_otra_cosa() -> void:
	var sim := _sim_de_caza()
	var cazador := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(20.0, 0.0, 0.0))
	sim.fijar_prioridad_especie("uro", Prioridades.Nivel.ALTA)
	var elegida := sim.caceria._pick_quarry(cazador,
		sim.caceria._huntable_species(Profession.Speciality.CAZA_MAYOR))
	assert_eq(String(elegida.get("species", "")), "ciervo",
		"priorizar no es quedarse parado esperando lo que no hay")


func test_lo_que_esta_en_nunca_no_se_caza() -> void:
	var sim := _sim_de_caza()
	var cazador := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(20.0, 0.0, 0.0))
	sim.fijar_prioridad_especie("ciervo", Prioridades.Nivel.NUNCA)
	var elegida := sim.caceria._pick_quarry(cazador,
		sim.caceria._huntable_species(Profession.Speciality.CAZA_MAYOR))
	assert_true(elegida.is_empty(),
		"con el ciervo en nunca y sólo ciervo al alcance no se persigue nada")


# --- la carga -------------------------------------------------------------
#
# El zurrón no se simula andando hasta él: se le pide a `_fill_the_basket` que
# llene uno con la tabla de rendimientos puesta a mano. Lo que se comprueba es
# el reparto de lo que cabe, no la cosecha.

func _recolector(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var person := Inhabitant.create(sim.people.size(), Vector3.ZERO, rng)
	person.job = Profession.Job.RECOLECCION
	person.current_speciality = Profession.Speciality.FORRAJEO
	person.activity = Subsistence.Activity.RECOLECCION
	person.has_task = true
	person.state = Inhabitant.State.TRABAJANDO
	# Sin cesto, que es como arranca la banda: el zurrón se llena antes y la
	# pregunta —qué entra cuando no cabe todo— se ve en una sola llamada.
	person.has_basket = false
	sim.people.append(person)
	return person


## Un tick de cosecha con la tabla de forrajeo de verdad.
##
## Nada de inyectar rendimientos: se usa `SPECIALITY_YIELDS[FORRAJEO]` —fruto
## seco 5,2 y baya 3,0— en otoño, que es cuando las dos están en temporada. El
## `multiplier` va alto a propósito: lo que se comprueba es qué entra cuando
## **no cabe todo**, así que el tick tiene que pasarse del límite de carga.
func _llenar(sim: SettlementSim, person: Inhabitant) -> void:
	GameState.season = Subsistence.Season.OTONO
	sim.tajo._fill_the_basket(person, 1.0, 0.1, 60.0, -1)


func test_sin_prioridades_el_zurron_lleva_de_las_dos() -> void:
	var sim := _sim(0)
	var person := _recolector(sim)
	# Un tick corto: cabe de todo, y entra de todo. Es el comportamiento de
	# siempre, y la línea contra la que se miden los dos de abajo.
	GameState.season = Subsistence.Season.OTONO
	sim.tajo._fill_the_basket(person, 1.0, 0.1, 1.0, -1)
	assert_true(float(person.load.get(Materia.Kind.FRUTO_SECO, 0.0)) > 0.0,
		"con todo en normal entra fruto seco")
	assert_true(float(person.load.get(Materia.Kind.BAYA, 0.0)) > 0.0,
		"y baya, que es lo que hace hoy")


func test_lo_de_alta_llena_y_lo_demas_va_en_lo_que_sobre() -> void:
	# La baya va la TERCERA en la tabla de forrajeo, detrás del fruto seco y la
	# raíz, así que sin tocar nada es de lo que menos entra cuando el zurrón se
	# llena. Es el caso de la spec visto al revés: ponerla en alta tiene que
	# darle la vuelta.
	var sim := _sim(0)
	var normal := _recolector(sim)
	_llenar(sim, normal)
	var baya_normal: float = float(normal.load.get(Materia.Kind.BAYA, 0.0))

	var sim_alta := _sim(0)
	var person := _recolector(sim_alta)
	sim_alta.fijar_prioridad_material(Materia.Kind.BAYA, Prioridades.Nivel.ALTA)
	_llenar(sim_alta, person)
	assert_true(float(person.load.get(Materia.Kind.BAYA, 0.0)) > baya_normal,
		"con la baya en alta vuelve con más baya que sin tocar nada")
	assert_true(float(person.load.get(Materia.Kind.FRUTO_SECO, 0.0))
			< float(normal.load.get(Materia.Kind.FRUTO_SECO, 0.0)),
		"y con menos fruto seco: lo que se prioriza se lleva el sitio")


func test_lo_que_esta_en_nunca_se_queda_en_el_monte() -> void:
	var sim := _sim(0)
	var person := _recolector(sim)
	sim.fijar_prioridad_material(Materia.Kind.BAYA, Prioridades.Nivel.NUNCA)
	_llenar(sim, person)
	assert_eq(float(person.load.get(Materia.Kind.BAYA, 0.0)), 0.0,
		"no vuelve con baya aunque le cupiera")
	assert_true(float(person.load.get(Materia.Kind.FRUTO_SECO, 0.0)) > 0.0,
		"y el fruto seco sigue entrando")


func test_lo_de_alta_desaloja_lo_que_ya_llevaba() -> void:
	# El caso de la spec: el zurrón se llena tick a tick, así que cuando
	# aparece lo prioritario ya lleva encima lo que cogió por la mañana. El
	# zurrón lleno SE CONSTRUYE —CLAUDE.md, «mide barato»— en vez de cosecharlo
	# a lo largo de una mañana simulada.
	var sim := _sim(0)
	var person := _recolector(sim)
	var baya_antes := person.carry_limit_kg() \
		/ maxf(Materia.kg_per_unit(Materia.Kind.BAYA), 0.001)
	person.add_load(Materia.Kind.BAYA, baya_antes)
	person.carrying = baya_antes * Materia.nutrition(Materia.Kind.BAYA)
	assert_true(person.carry_limit_kg() - person.load_kg() < 0.001,
		"el zurrón está lleno de baya y no cabe nada más")

	# Y ahora el jugador pide fruto seco y deja la baya en baja. Lo único que
	# puede entrar es lo que desaloje.
	sim.fijar_prioridad_material(Materia.Kind.FRUTO_SECO, Prioridades.Nivel.ALTA)
	sim.fijar_prioridad_material(Materia.Kind.BAYA, Prioridades.Nivel.BAJA)
	_llenar(sim, person)
	assert_true(float(person.load.get(Materia.Kind.BAYA, 0.0)) < baya_antes,
		"se suelta parte de la baya para hacerle sitio al fruto seco")
	assert_true(float(person.load.get(Materia.Kind.FRUTO_SECO, 0.0)) > 0.0,
		"que es lo que entra en su lugar")
	assert_true(person.load_kg() <= person.carry_limit_kg() + 0.001,
		"y el zurrón no se pasa de lo que se puede llevar")


# --- el sitio -------------------------------------------------------------
#
# Se comprueba el PESO, que es la regla nueva: el resto de la puntuación
# -abundancia, lo que se tarda en llegar, lo esquilmado que esté- ya estaba
# probado y no cambia. Un paraje se escribe a mano; levantar el valle entero
# para comparar dos sitios sería desproporcionado.

func _paraje_con(materiales: Dictionary) -> Paraje:
	var paraje := Paraje.new()
	for kind: int in materiales:
		paraje.contents[kind] = {
			"abundancia": float(materiales[kind]), "sabido": true,
		}
	return paraje


func test_sin_prioridades_todos_los_parajes_pesan_igual() -> void:
	var sim := _sim(0)
	var silex := _paraje_con({Materia.Kind.SILEX: 0.6, Materia.Kind.PIEDRA: 0.4})
	var cuarcita := _paraje_con({Materia.Kind.PIEDRA: 1.0})
	assert_eq(sim.tajo._peso_de_prioridad(silex, Subsistence.Activity.MATERIA_PRIMA),
		1.0, "sin tocar nada el peso es uno")
	assert_eq(sim.tajo._peso_de_prioridad(cuarcita, Subsistence.Activity.MATERIA_PRIMA),
		1.0, "en los dos, o sea que la elección es la de siempre")


func test_el_paraje_con_lo_prioritario_pesa_mas() -> void:
	var sim := _sim(0)
	var silex := _paraje_con({Materia.Kind.SILEX: 0.6, Materia.Kind.PIEDRA: 0.4})
	var cuarcita := _paraje_con({Materia.Kind.PIEDRA: 1.0})
	sim.fijar_prioridad_material(Materia.Kind.SILEX, Prioridades.Nivel.ALTA)
	assert_true(sim.tajo._peso_de_prioridad(silex, Subsistence.Activity.MATERIA_PRIMA)
			> sim.tajo._peso_de_prioridad(cuarcita, Subsistence.Activity.MATERIA_PRIMA),
		"con el sílex en alta, la veta de sílex tira más que el canchal")


func test_lo_que_esta_en_nunca_no_cuenta_para_elegir_sitio() -> void:
	var sim := _sim(0)
	var solo_nunca := _paraje_con({Materia.Kind.BAYA: 1.0})
	sim.fijar_prioridad_material(Materia.Kind.BAYA, Prioridades.Nivel.NUNCA)
	assert_eq(sim.tajo._peso_de_prioridad(solo_nunca, Subsistence.Activity.RECOLECCION),
		0.0, "un paraje que sólo tiene lo que nadie quiere deja de elegirse")


func test_lo_que_no_se_sabe_no_tira_de_nadie() -> void:
	# Descubrir un paraje es ver que hay cinco cosas, no saber cuáles. Pesar
	# con lo no averiguado delataría el sitio bueno sin ir a mirarlo.
	var sim := _sim(0)
	var paraje := _paraje_con({Materia.Kind.PIEDRA: 1.0})
	paraje.contents[Materia.Kind.SILEX] = {"abundancia": 5.0, "sabido": false}
	sim.fijar_prioridad_material(Materia.Kind.SILEX, Prioridades.Nivel.ALTA)
	assert_eq(sim.tajo._peso_de_prioridad(paraje, Subsistence.Activity.MATERIA_PRIMA),
		1.0, "el sílex que nadie ha identificado todavía no pesa")


func test_la_prioridad_de_material_no_mueve_la_caza() -> void:
	var sim := _sim(0)
	var coto := _paraje_con({Materia.Kind.CARNE: 1.0})
	sim.fijar_prioridad_material(Materia.Kind.CARNE, Prioridades.Nivel.ALTA)
	assert_eq(sim.tajo._peso_de_prioridad(coto, Subsistence.Activity.CAZA),
		1.0, "la especie decide a qué pieza se le va, no adónde se va a cazar")


func test_el_peso_de_cada_nivel() -> void:
	# Decisión del usuario del 2026-09-14, ver SISTEMAS §22: un empujón, no una
	# orden. Lo de nunca no pesa nada, que es lo que lo saca de la elección.
	assert_eq(Prioridades.peso(Prioridades.Nivel.ALTA), 2.0, "lo alto, el doble")
	assert_eq(Prioridades.peso(Prioridades.Nivel.NORMAL), 1.0, "lo normal, uno")
	assert_eq(Prioridades.peso(Prioridades.Nivel.BAJA), 0.5, "lo bajo, la mitad")
	assert_eq(Prioridades.peso(Prioridades.Nivel.NUNCA), 0.0, "y lo de nunca, nada")
