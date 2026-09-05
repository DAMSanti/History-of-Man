class_name TestFishing
extends TestCase
## La escalera de la pesca de orilla: qué se puede hacer y con qué.


func suite_name() -> String:
	return "Pesca"


func _techs(learned: Array) -> TechTree:
	var techs := TechTree.new()
	for t: int in learned:
		techs.known[t as TechTree.Tech] = true
	return techs


func _toolkit(kinds: Array) -> Toolkit:
	var kit := Toolkit.new()
	for kind: int in kinds:
		kit.craft(kind as Tool.Kind, Tool.default_stuff(kind as Tool.Kind), 0.5)
	return kit


func _store(kind: int = -1, amount: float = 0.0) -> Storehouse:
	var store := Storehouse.new()
	if kind >= 0:
		store.add(kind as Materia.Kind, amount)
	return store


# --- el escalón de partida ------------------------------------------------

func test_sin_saber_nada_se_pesca_a_mano() -> void:
	# Es el punto de partida y no puede fallar: pescar a mano no pide nada,
	# y por eso una banda recién llegada pesca algo desde el primer día.
	assert_eq(Fishing.best_for(null, null, null), Fishing.Method.MANO,
		"sin árbol, sin utillaje y sin abrigo se pesca a mano")
	assert_eq(Fishing.tool_of(Fishing.Method.MANO), -1,
		"y no gasta ninguna pieza")
	assert_eq(Fishing.tech_of(Fishing.Method.MANO), -1,
		"ni hace falta saber nada")


func test_la_pesquera_no_pide_pieza_solo_saberla() -> void:
	# Una pesquera es una obra de piedra y ramaje, no un objeto que se lleve
	# encima: en cuanto se sabe levantar, se usa.
	var techs := _techs([TechTree.Tech.PESQUERA])
	assert_eq(Fishing.best_for(techs, Toolkit.new(), Storehouse.new()),
		Fishing.Method.PESQUERA, "sabida la pesquera, se pesca con ella")


# --- cada escalón pide su pieza -------------------------------------------

func test_saber_la_nasa_sin_tenerla_no_sirve() -> void:
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA])
	assert_eq(Fishing.best_for(techs, Toolkit.new(), Storehouse.new()),
		Fishing.Method.PESQUERA,
		"sabida la nasa pero sin nasas hechas, se baja a la pesquera")

	var kit := _toolkit([Tool.Kind.NASA])
	assert_eq(Fishing.best_for(techs, kit, Storehouse.new()),
		Fishing.Method.NASA, "con una nasa en el abrigo, ya sí")


func test_la_red_pide_tres_manos() -> void:
	# La red no la cala uno solo: es la única forma de pescar que necesita
	# cuadrilla, y por eso el jugador tiene que decidir mandar gente.
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
		TechTree.Tech.ANZUELO, TechTree.Tech.RED])
	var kit := _toolkit([Tool.Kind.NASA, Tool.Kind.RED])

	assert_eq(Fishing.best_for(techs, kit, Storehouse.new(), 2),
		Fishing.Method.NASA, "con dos manos no se cala una red")
	assert_eq(Fishing.best_for(techs, kit, Storehouse.new(), 3),
		Fishing.Method.RED, "con tres sí")


# --- el cebo --------------------------------------------------------------

func test_el_sedal_sin_cebo_no_es_sedal() -> void:
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
		TechTree.Tech.ANZUELO])
	var kit := _toolkit([Tool.Kind.NASA, Tool.Kind.ANZUELO])

	assert_eq(Fishing.best_for(techs, kit, Storehouse.new()),
		Fishing.Method.NASA,
		"con anzuelo y sin cebo se pesca con la nasa")

	assert_eq(Fishing.best_for(techs, kit, _store(Materia.Kind.CARACOL, 20.0)),
		Fishing.Method.SEDAL, "con caracol, sedal")


func test_de_cebo_vale_lo_que_haya() -> void:
	# El cebo es lo que se tenga a mano: un caracol, un trozo de carne, una
	# lapa. Atarlo a un solo material dejaría el sedal a merced de la
	# temporada del caracol.
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
		TechTree.Tech.ANZUELO])
	var kit := _toolkit([Tool.Kind.ANZUELO])
	for kind: Materia.Kind in [Materia.Kind.CARACOL, Materia.Kind.CARNE,
			Materia.Kind.MARISCO]:
		assert_eq(Fishing.best_for(techs, kit, _store(kind, 20.0)),
			Fishing.Method.SEDAL,
			"con %s se puede cebar" % Materia.material_name(kind))


# --- se baja un escalón, no se para ---------------------------------------

func test_al_romperse_el_arpon_se_baja_un_escalon() -> void:
	# Petición de fondo: la banda no se queda parada porque le falte la pieza
	# buena. Se pesca con lo mejor que se pueda HOY, y mañana el taller repone.
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
		TechTree.Tech.ANZUELO, TechTree.Tech.RED, TechTree.Tech.ARPON])

	var completo := _toolkit([Tool.Kind.NASA, Tool.Kind.RED, Tool.Kind.ARPON])
	assert_eq(Fishing.best_for(techs, completo, Storehouse.new(), 3),
		Fishing.Method.ARPON, "con todo hecho, arpón")

	var sin_arpon := _toolkit([Tool.Kind.NASA, Tool.Kind.RED])
	assert_eq(Fishing.best_for(techs, sin_arpon, Storehouse.new(), 3),
		Fishing.Method.RED, "roto el arpón, la red")

	var solo_nasa := _toolkit([Tool.Kind.NASA])
	assert_eq(Fishing.best_for(techs, solo_nasa, Storehouse.new(), 3),
		Fishing.Method.NASA, "rota la red, la nasa")

	assert_eq(Fishing.best_for(techs, Toolkit.new(), Storehouse.new(), 3),
		Fishing.Method.PESQUERA, "y sin nada hecho, la pesquera, que es obra")


func test_se_dice_por_que_no_se_puede() -> void:
	# El jugador tiene que poder leer qué le falta, no adivinarlo
	var techs := _techs([TechTree.Tech.PESQUERA])
	assert_true(Fishing.blocked_by(Fishing.Method.NASA, techs, Toolkit.new(),
		Storehouse.new()).contains("nasa de mimbre"),
		"si falta la técnica, lo dice")

	var sabidas := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA])
	assert_true(Fishing.blocked_by(Fishing.Method.NASA, sabidas, Toolkit.new(),
		Storehouse.new()).contains("abrigo"),
		"si falta la pieza, lo dice")

	assert_eq(Fishing.blocked_by(Fishing.Method.PESQUERA, sabidas,
		Toolkit.new(), Storehouse.new()), "",
		"y si se puede, no dice nada")


# --- el orden es el de verdad ---------------------------------------------

func test_la_escalera_va_de_menos_a_mas() -> void:
	var last := -1.0
	for method_key: int in Fishing.ORDER:
		var pescado: float = float((Fishing.yields_of(
			method_key as Fishing.Method) as Dictionary).get(
				Materia.Kind.PESCADO, 0.0))
		assert_true(pescado > last,
			"%s da más que el escalón de antes (%.0f sobre %.0f)" % [
				Fishing.method_name(method_key as Fishing.Method), pescado, last])
		last = pescado


func test_la_red_se_aprende_antes_que_el_arpon() -> void:
	# Cronología real y no «cuánto rinde»: la red es gravetiense -impronta de
	# Pavlov, hace unos 29.000 años- y el arpón magdaleniense, hace unos
	# 15.000. Aunque el arpón dé más, se llega antes a la red.
	assert_true(Fishing.ORDER.find(Fishing.Method.RED)
		< Fishing.ORDER.find(Fishing.Method.ARPON),
		"la red va antes en la escalera")
	assert_true((TechTree.CATALOGUE[TechTree.Tech.ARPON]["needs"] as Array)
		.has(TechTree.Tech.RED),
		"y el arpón no llega sin haber pasado por ella")


func test_cada_escalon_pide_mas_practica_que_el_anterior() -> void:
	var previous := 0.0
	for method_key: int in Fishing.ORDER:
		var tech := Fishing.tech_of(method_key as Fishing.Method)
		if tech < 0:
			continue
		var days: float = float(TechTree.CATALOGUE[tech as TechTree.Tech]["days"])
		assert_true(days > previous,
			"%s cuesta más jornadas que lo anterior (%.0f sobre %.0f)" % [
				TechTree.tech_name(tech as TechTree.Tech), days, previous])
		previous = days


func test_todo_lo_que_saca_la_pesca_sale_en_la_ficha_del_paraje() -> void:
	# La regla que ya se aplicó a la recolección: lo que se puede traer de un
	# sitio tiene que salir en la ficha del sitio.
	var pool: Array = Parajes.EXTRAS_BY_ACTIVITY[Subsistence.Activity.PESCA]
	for method_key: int in Fishing.ORDER:
		var yields: Dictionary = Fishing.yields_of(method_key as Fishing.Method)
		for kind: int in yields:
			if kind == Materia.Kind.PESCADO:
				continue  # es el que da nombre al sitio
			assert_true(pool.has(kind),
				"%s se saca pescando, así que tiene que estar en el surtido "
					% Materia.material_name(kind as Materia.Kind)
					+ "de la pesca")
