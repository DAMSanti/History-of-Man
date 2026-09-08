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
	# La nasa sigue pidiendo las dos cosas -saberla y tenerla trenzada-, pero
	# YA NO es un escalón de `best_for`: no es una jornada en el agua, es un
	# aparejo que se cala y se deja. Ver [Fishing.ACTIVAS] y [Nasa].
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA])
	assert_false(Fishing.available(Fishing.Method.NASA, techs, Toolkit.new(),
		Storehouse.new()), "sabida la nasa pero sin nasas hechas, no hay nasa")

	var kit := _toolkit([Tool.Kind.NASA])
	assert_true(Fishing.available(Fishing.Method.NASA, techs, kit,
		Storehouse.new()), "con una nasa en el abrigo, ya sí")


func test_la_nasa_no_compite_con_el_arpon_se_suma() -> void:
	# La corrección de fondo: estando la nasa en la escalera, una banda con
	# nasas y sin arpón «pescaba con nasa» —o sea se pasaba la jornada entera
	# de pie en la orilla con una cesta— y una con arpón no calaba ninguna.
	# Son dos cosas distintas y se hacen las dos.
	assert_true(Fishing.is_passive(Fishing.Method.NASA),
		"la nasa es un aparejo que se deja puesto")
	for activa: Fishing.Method in Fishing.ACTIVAS:
		assert_false(Fishing.is_passive(activa),
			"%s es una jornada en el agua" % Fishing.method_name(activa))

	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA])
	var kit := _toolkit([Tool.Kind.NASA])
	assert_eq(Fishing.best_for(techs, kit, Storehouse.new()),
		Fishing.Method.PESQUERA,
		"con nasas caladas se pesca ADEMÁS con lo mejor que se tenga")


func test_la_red_pide_tres_manos() -> void:
	# La red no la cala uno solo: es la única forma de pescar que necesita
	# cuadrilla, y por eso el jugador tiene que decidir mandar gente.
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
		TechTree.Tech.ANZUELO, TechTree.Tech.RED])
	var kit := _toolkit([Tool.Kind.NASA, Tool.Kind.RED])

	assert_eq(Fishing.best_for(techs, kit, Storehouse.new(), 2),
		Fishing.Method.PESQUERA, "con dos manos no se cala una red")
	assert_eq(Fishing.best_for(techs, kit, Storehouse.new(), 3),
		Fishing.Method.RED, "con tres sí")


# --- el cebo --------------------------------------------------------------

func test_el_sedal_sin_cebo_no_es_sedal() -> void:
	var techs := _techs([TechTree.Tech.PESQUERA, TechTree.Tech.NASA,
		TechTree.Tech.ANZUELO])
	var kit := _toolkit([Tool.Kind.NASA, Tool.Kind.ANZUELO])

	assert_eq(Fishing.best_for(techs, kit, Storehouse.new()),
		Fishing.Method.PESQUERA,
		"con anzuelo y sin cebo se baja a la pesquera")

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


# --- la nasa calada: pesca sola -------------------------------------------
#
# Es la mitad nueva de la pesca, y la que la separa de todo lo demás: se cala,
# se deja y trabaja mientras la banda está en otra cosa. Ver [Nasa].

func _nasa(baited: bool = true) -> Nasa:
	var piece := Tool.make(Tool.Kind.NASA, Tool.Stuff.FIBRA, 0.5)
	var nasa := Nasa.create(Vector3.ZERO, 1, piece, "Beru")
	if baited:
		nasa.rebait(Materia.Kind.CARACOL)
	return nasa


func test_la_nasa_pesca_mientras_la_banda_hace_otra_cosa() -> void:
	var nasa := _nasa()
	assert_eq(nasa.collect(), 0, "recién calada no lleva nada")
	for _dia in range(4):
		nasa.soak(1.0)
	assert_gt(float(nasa.collect()), 0.0,
		"cuatro jornadas caladas y hay pieza dentro")
	assert_gt(float(nasa.taken), 0.0, "y queda apuntado lo que ha dado")


func test_sin_cebo_la_nasa_coge_pero_coge_poco() -> void:
	# Ponerlo a cero convertiría el cebo en un interruptor y la nasa en una
	# pieza inútil el día que se acaban los caracoles.
	var cebada := _nasa(true)
	var vacia := _nasa(false)
	for _dia in range(8):
		cebada.soak(1.0)
		vacia.soak(1.0)
	var con := cebada.collect()
	var sin := vacia.collect()
	assert_gt(float(sin), 0.0, "una nasa sin cebar coge lo que se mete solo")
	assert_gt(float(con), float(sin), "pero la cebada coge bastante más")


func test_el_cebo_se_pierde_en_el_agua() -> void:
	var nasa := _nasa()
	assert_true(nasa.is_baited(), "recién cebada")
	for _dia in range(int(Nasa.DIAS_DE_CEBO) + 1):
		nasa.soak(1.0)
	assert_false(nasa.is_baited(),
		"el cebo se deslíe y hay que reponerlo: es media faena de revisar")


func test_la_nasa_se_pudre_en_el_agua_y_se_pierde() -> void:
	# El mimbre en el río no dura. Y se pierde de verdad, porque la nasa ES la
	# pieza del utillaje: no vuelve al abrigo.
	var nasa := _nasa()
	for _dia in range(200):
		nasa.soak(1.0)
	assert_true(nasa.is_spent(), "el mimbre calado acaba podrido")
	assert_lt(nasa.condition(), 0.01, "y no queda nada que recuperar")


func test_calar_una_nasa_la_saca_del_abrigo() -> void:
	# Mientras esté en el río no la puede usar nadie ni cuenta para lo que el
	# taller da por cubierto.
	var kit := _toolkit([Tool.Kind.NASA])
	assert_eq(kit.count(Tool.Kind.NASA), 1, "hay una trenzada")
	var piece := kit.detach(Tool.Kind.NASA)
	assert_true(piece != null, "se coge para calarla")
	assert_eq(kit.count(Tool.Kind.NASA), 0, "y ya no está en el abrigo")


func test_revisar_la_linea_no_se_come_la_jornada() -> void:
	# Es lo que la separa de la línea de trampas, que sí se lleva el día
	# entero: «coloca o revisa unas nasas y después el resto del tiempo le
	# dedica a pescar activamente».
	assert_lt(Nasa.JORNADA_DE_CALAR, 0.5,
		"calar una nasa es un rato de la mañana")
	assert_lt(Nasa.JORNADA_DE_REVISAR, Nasa.JORNADA_DE_CALAR,
		"y revisarla, menos todavía")


func test_levantar_una_nasa_la_deja_cebada_otra_vez() -> void:
	# Se levanta el cesto, se saca el pez, se le echa cebo nuevo y se cala otra
	# vez: es una sola visita. Separarlo en dos parecía más ordenado y era
	# falso, y se veía en la orilla —con una nasa dando pieza todos los días el
	# pescador iba siempre a ésa y las demás se quedaban sin cebo para siempre—.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.CARACOL, 20.0)
	var nasa := _nasa(false)
	assert_false(nasa.is_baited(), "empieza sin cebo")
	assert_true(sim.nasas_line._rebait(nasa), "se ceba con lo que hay en el abrigo")
	assert_true(nasa.is_baited(), "y queda cebada")
	assert_lt(sim.store.amount(Materia.Kind.CARACOL), 20.0,
		"y el caracol se gasta")


func test_sin_cebo_en_el_abrigo_no_se_ceba_nada() -> void:
	var sim := SettlementSim.new()
	var nasa := _nasa(false)
	assert_false(sim.nasas_line._rebait(nasa), "sin caracol ni carne no hay con qué")
	assert_false(nasa.is_baited(), "y se queda como estaba")


func test_no_se_gasta_cebo_en_una_nasa_que_ya_lo_tiene() -> void:
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.CARACOL, 20.0)
	var nasa := _nasa(true)
	assert_false(sim.nasas_line._rebait(nasa), "ya está cebada")
	assert_eq(sim.store.amount(Materia.Kind.CARACOL), 20.0,
		"y no se tira el caracol")


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

	# Y con la nasa fuera de la escalera, romper la red deja la pesquera: la
	# nasa no salva la jornada porque la nasa no ES la jornada.
	var solo_nasa := _toolkit([Tool.Kind.NASA])
	assert_eq(Fishing.best_for(techs, solo_nasa, Storehouse.new(), 3),
		Fishing.Method.PESQUERA, "rota la red, la pesquera")

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


# --- el aparejo existe de verdad para el taller y para el almacén ---------

func test_cada_aparejo_lo_sabe_hacer_alguien() -> void:
	# Petición literal: «no aparece la nasa, el anzuelo, la red o el arpón en
	# el utillaje; añádelo tanto a la lista de objetos fabricados por los
	# manufactureros como a la lista de almacén».
	for method_key: int in Fishing.ORDER:
		var tool := Fishing.tool_of(method_key as Fishing.Method)
		if tool < 0:
			continue
		var maker := -1
		for speciality: int in SettlementSim.SPECIALITY_MAKES:
			if (SettlementSim.SPECIALITY_MAKES[speciality] as Array).has(tool):
				maker = speciality
				break
		assert_true(maker >= 0,
			"%s tiene que salir de algún taller" % Tool.kind_name(tool as Tool.Kind))


func test_cada_aparejo_tiene_receta_desgaste_e_icono() -> void:
	# Sin receta no se fabrica, sin desgaste no se repone nunca y sin icono
	# la fila del almacén sale con el dibujo de una piedra cualquiera.
	for method_key: int in Fishing.ORDER:
		var tool_key := Fishing.tool_of(method_key as Fishing.Method)
		if tool_key < 0:
			continue
		var tool := tool_key as Tool.Kind
		assert_false(Tool.recipe(tool).is_empty(),
			"%s se hace con algo" % Tool.kind_name(tool))
		assert_true(Tool.wear_per_day(tool) > 0.0,
			"%s se gasta con el uso" % Tool.kind_name(tool))
		assert_true(MateriaIcon.TOOL_LOOK.has(int(tool)),
			"%s tiene icono propio" % Tool.kind_name(tool))
		assert_true(Tool.KIND_NAMES.has(int(tool)),
			"%s tiene nombre" % Tool.kind_name(tool))


func test_el_aparejo_no_se_pide_hasta_saber_usarlo() -> void:
	# Y al reves: no tiene sentido que el taller trence redes cuando la banda
	# ni sabe calarlas. Se pide lo de la mejor manera que se SEPA.
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	for i in range(6):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		sim.people.append(person)
		Profession.assign(Profession.Job.RIBERA, person,
			Profession.Speciality.ORILLA)

	sim.techs = TechTree.new()
	var demand := sim.tool_demand()
	for tool: Tool.Kind in [Tool.Kind.NASA, Tool.Kind.ANZUELO, Tool.Kind.RED,
			Tool.Kind.ARPON]:
		assert_eq(int(demand.get(tool, 0)), 0,
			"sin saber pescar de esa manera no se pide %s" % Tool.kind_name(tool))

	sim.techs.known[TechTree.Tech.PESQUERA] = true
	sim.techs.known[TechTree.Tech.NASA] = true
	assert_true(int(sim.tool_demand().get(Tool.Kind.NASA, 0)) > 0,
		"sabida la nasa, el taller la tiene en la lista")
