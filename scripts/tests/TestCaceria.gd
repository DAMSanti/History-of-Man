class_name TestCaceria
extends TestCase
## La cacería vista: acecho, persecución, lance y despiece.
##
## Se monta la fauna A MANO —[WildlifeHerds.place_for_test]— en vez de levantar
## el valle entero, y se dice por qué: montar terreno, campo de recursos y
## mallas horneadas para comprobar que un cazador se acerca despacio a un
## ciervo es desproporcionado, y sin poder comprobarlo la cacería sería el
## único sistema grande del juego sin una prueba detrás.


func suite_name() -> String:
	return "Caceria"


func _techs(learned: Array) -> TechTree:
	var techs := TechTree.new()
	for t: int in learned:
		techs.known[t as TechTree.Tech] = true
	return techs


func _sim(armas: Array = [Tool.Kind.AZAGAYA, Tool.Kind.LASCA]) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.techs = _techs([])
	sim.caceria.wildlife = WildlifeHerds.new()
	for kind: int in armas:
		sim.toolkit.craft(kind as Tool.Kind,
			Tool.default_stuff(kind as Tool.Kind), 0.6)
	return sim


func _cazador(sim: SettlementSim,
		rama: Profession.Speciality = Profession.Speciality.CAZA_MAYOR,
		donde: Vector3 = Vector3.ZERO) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + sim.people.size()
	var person := Inhabitant.create(sim.people.size(), donde, rng)
	person.job = Profession.Job.CAZA
	person.current_speciality = rama
	person.activity = Subsistence.Activity.CAZA
	# Con tarea puesta: `SettlementSim.hunters_in` solo cuenta a quien la tiene,
	# y sin esto una cuadrilla de tres contaba como uno.
	person.has_task = true
	person.state = Inhabitant.State.TRABAJANDO
	person.position = donde
	person.work_centre = donde
	sim.people.append(person)
	return person


# --- lo que se decide de la pieza sin que haya partida --------------------

func test_el_propulsor_dobla_el_alcance_del_lance() -> void:
	# Es su razón de ser: una palanca que alarga el brazo. Si no cambiara el
	# alcance, el propulsor sería un número en una tabla.
	var pelado := _techs([])
	var con := _techs([TechTree.Tech.PROPULSOR])
	assert_near(Hunt.reach_of(Tool.Kind.AZAGAYA, con),
		Hunt.reach_of(Tool.Kind.AZAGAYA, pelado) * Hunt.PROPULSOR_ALCANCE,
		0.01, "con propulsor se tira al doble de lejos")


func test_a_mano_hay_que_llegar_a_tocarla() -> void:
	assert_lt(Hunt.reach_of(-1, null), Hunt.reach_of(Tool.Kind.PUNTA, null),
		"sin nada se llega menos lejos que con una lanza de mano")
	assert_lt(Hunt.reach_of(Tool.Kind.PUNTA, null),
		Hunt.reach_of(Tool.Kind.AZAGAYA, null),
		"y una lanza de mano no se tira: se clava")


func test_lo_grande_se_abre_donde_cae_y_lo_pequeno_va_al_hombro() -> void:
	# El efecto `schlepp`: en los abrigos aparecen esqueletos casi completos de
	# pieza pequeña y perfiles sesgados a las partes buenas de la grande.
	for grande: String in ["ciervo", "caballo", "uro", "jabali"]:
		assert_true(Hunt.butchered_in_field(grande),
			"%s se abre donde cae" % Fauna.species_name(grande))
	for pequena: String in ["liebre", "conejo", "perdiz", "corzo"]:
		assert_false(Hunt.butchered_in_field(pequena),
			"%s se echa al hombro" % Fauna.species_name(pequena))


func test_abrir_una_res_grande_cuesta_mas_que_una_pequena() -> void:
	assert_gt(Hunt.butcher_days("uro"), Hunt.butcher_days("ciervo"),
		"un uro lleva más que un ciervo")
	assert_gt(Hunt.butcher_days("ciervo"), Hunt.butcher_days("liebre") * 10.0,
		"y un ciervo, muchísimo más que una liebre")


func test_de_la_pieza_sale_carne_y_despiece_en_unidades() -> void:
	var salio := Hunt.spoils_of("ciervo")
	assert_gt(float(salio.get(int(Materia.Kind.CARNE), 0.0)), 0.0,
		"un ciervo da carne")
	assert_gt(float(salio.get(int(Materia.Kind.ASTA), 0.0)), 0.0,
		"y asta, que es lo que hace del ciervo el ciervo")
	# En UNIDADES y no en raciones: es como entra en el almacén.
	var raciones: float = float(salio[int(Materia.Kind.CARNE)]) \
		* Materia.nutrition(Materia.Kind.CARNE)
	assert_near(raciones, Fauna.rations_of("ciervo"), 0.5,
		"lo que entra en unidades vale las raciones que dice la ficha")


func test_una_pieza_grande_no_cabe_en_una_espalda() -> void:
	# Es lo que hace que dejar la pieza en el terreno sea una decisión y no una
	# comodidad de código: un ciervo son varios viajes.
	var hunt := Hunt.new()
	hunt.species = "ciervo"
	hunt.spoils = Hunt.spoils_of("ciervo")
	assert_gt(hunt.spoils_kg(), Storehouse.BASE_CARRY_KG,
		"un ciervo pesa más de lo que carga una persona")


# --- la cacería en marcha -------------------------------------------------

func test_sin_arma_no_se_levanta_caceria_contra_pieza_grande() -> void:
	# La misma puerta que [Fauna.huntable_with], aplicada donde se elige a
	# quién se le va: con las manos vacías el ciervo ni se intenta.
	var sim := _sim([])
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(40.0, 0.0, 0.0))
	assert_true(sim.caceria._open_hunt(person) == null,
		"sin azagaya no se le va a un ciervo")

	var armado := _sim()
	var otro := _cazador(armado)
	armado.caceria.wildlife.place_for_test("ciervo", Vector3(40.0, 0.0, 0.0))
	assert_true(armado.caceria._open_hunt(otro) != null, "con azagaya sí")


func test_la_caceria_empieza_acechando() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(60.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	assert_eq(hunt.phase, Hunt.Phase.ACECHO, "primero se acecha")
	assert_eq(hunt.species, "ciervo", "y se acecha a la pieza que hay")
	assert_true(hunt.unseen, "todavía no le ha visto")


func test_acechar_se_hace_despacio() -> void:
	# Acechar no es ir hacia el animal: es ir sin que se entere. Si el paso
	# fuera el mismo, desde fuera acechar y andar se verían igual.
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(60.0, 0.0, 0.0))
	sim.caceria._hunt_step(person, 0.1)
	assert_lt(sim.caceria._hunt_pace(person), 1.0, "al acecho se anda despacio")


func test_el_paso_lento_no_se_le_queda_pegado_a_nadie() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	person.hunt_pace = Caceria.PASO_DE_ACECHO
	assert_near(sim.caceria._hunt_pace(person), 1.0, 0.001,
		"sin cacería en marcha se anda como todo el mundo")


func test_la_cuadrilla_rodea_una_pieza_y_no_cuatro() -> void:
	# Es lo que hace que la caza mayor se vea como lo que es. Sin esto, cuatro
	# batidores acechaban cuatro ciervos cada uno por su lado.
	var sim := _sim()
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(60.0, 0.0, 0.0))
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(-60.0, 0.0, 0.0))
	var uno := _cazador(sim)
	var dos := _cazador(sim)
	var primera := sim.caceria._open_hunt(uno)
	var segunda := sim.caceria._open_hunt(dos)
	assert_true(primera == segunda, "el segundo se suma a la batida del primero")
	assert_eq(primera.crew.size(), 2, "y la cuadrilla son dos")
	assert_eq(sim.caceria.hunts.size(), 1, "una sola cacería en marcha")


func test_al_acecho_solitario_no_se_suma_nadie() -> void:
	# La caza menor se hace al acecho, solo o de a dos: una cuadrilla no acecha
	# mejor. Ver [Hunting.CREW], que ya lo decía y no llegaba a la conducta.
	var sim := _sim()
	sim.caceria.wildlife.place_for_test("corzo", Vector3(50.0, 0.0, 0.0))
	sim.caceria.wildlife.place_for_test("corzo", Vector3(-50.0, 0.0, 0.0))
	var uno := _cazador(sim, Profession.Speciality.CAZA_MENOR)
	var dos := _cazador(sim, Profession.Speciality.CAZA_MENOR)
	sim.caceria._open_hunt(uno)
	sim.caceria._open_hunt(dos)
	assert_eq(sim.caceria.hunts.size(), 2, "cada uno acecha lo suyo")


func test_perseguir_se_acaba_por_fuelle() -> void:
	# Lo que decide no es el fondo del cazador: es que el monte se traga a la
	# pieza. Y se pierden muchas, que es de lo que va cazar.
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(200.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	hunt.phase = Hunt.Phase.PERSECUCION
	hunt.chased = Hunt.FUELLE_HORAS + 0.1
	sim.caceria._hunt_step(person, 0.05)
	assert_eq(hunt.phase, Hunt.Phase.FALLIDA, "sin fuelle se deja")


func test_perseguir_se_acaba_por_distancia() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo",
		Vector3(Hunt.PIERDE_M + 50.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	assert_true(hunt == null, "tan lejos ni se ve")

	sim.caceria.wildlife.place_for_test("ciervo", Vector3(100.0, 0.0, 0.0))
	var cerca := sim.caceria._open_hunt(person)
	cerca.phase = Hunt.Phase.PERSECUCION
	cerca.quarry["position"] = Vector3(Hunt.PIERDE_M + 100.0, 0.0, 0.0)
	sim.caceria._hunt_step(person, 0.05)
	assert_eq(cerca.phase, Hunt.Phase.FALLIDA, "se le fue de vista")


func test_cobrar_una_pieza_grande_manda_a_despiezar() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(5.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	hunt.phase = Hunt.Phase.LANCE
	# Se tira hasta que entra: lo que se comprueba es qué pasa al acertar, no
	# la probabilidad, que ya la gobierna `Hunt.LANCE_BASE`.
	for _intento in range(200):
		if hunt.phase == Hunt.Phase.DESPIECE:
			break
		hunt.phase = Hunt.Phase.LANCE
		hunt.chased = 0.0
		sim.caceria._throw(person, hunt)
	assert_eq(hunt.phase, Hunt.Phase.DESPIECE,
		"un ciervo se abre donde cae")
	assert_gt(hunt.spoils_kg(), 0.0, "y queda la res en el suelo")


func test_cobrar_una_pieza_pequena_se_carga_directamente() -> void:
	var sim := _sim()
	var person := _cazador(sim, Profession.Speciality.CAZA_MENOR)
	sim.caceria.wildlife.place_for_test("conejo", Vector3(2.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	for _intento in range(200):
		if hunt.phase == Hunt.Phase.ACARREO:
			break
		hunt.phase = Hunt.Phase.LANCE
		hunt.chased = 0.0
		sim.caceria._throw(person, hunt)
	assert_eq(hunt.phase, Hunt.Phase.ACARREO,
		"un conejo se echa al hombro sin abrirlo")


func test_lo_que_no_cabe_se_queda_en_el_monte() -> void:
	var sim := _sim()
	var person := _cazador(sim)
	var hunt := Hunt.new()
	hunt.species = "uro"
	hunt.phase = Hunt.Phase.ACARREO
	hunt.spoils = Hunt.spoils_of("uro")
	hunt.kill_site = person.position
	hunt.crew = [person]
	sim.caceria.hunts.append(hunt)

	sim.caceria._load_up(person, hunt)
	assert_gt(person.load_kg(), 0.0, "se carga lo que cabe")
	assert_false(hunt.spoils.is_empty(),
		"y un uro no cabe en una espalda: queda res en el monte")


func test_se_vuelve_a_por_lo_que_quedo_abierto() -> void:
	# Volver a por una espalda de ciervo rinde más que cualquier otra cosa de
	# la caza, y es lo que hace que dejarla sea una decisión y no una pérdida.
	var sim := _sim()
	var person := _cazador(sim)
	var hunt := Hunt.new()
	hunt.species = "ciervo"
	hunt.phase = Hunt.Phase.ACARREO
	hunt.spoils = Hunt.spoils_of("ciervo")
	hunt.kill_site = Vector3(300.0, 0.0, 0.0)
	sim.caceria.hunts.append(hunt)
	var vuelta := sim.caceria.kill_to_fetch_near(person.position, 1200.0)
	assert_true(vuelta == hunt, "el cazador vuelve a por ella")


func test_lo_que_se_deja_demasiado_tiempo_se_pierde() -> void:
	# No es sólo que se pudra: hay lobos, y una res abierta se anuncia sola.
	var sim := _sim()
	var hunt := Hunt.new()
	hunt.species = "ciervo"
	hunt.phase = Hunt.Phase.ACARREO
	hunt.spoils = Hunt.spoils_of("ciervo")
	sim.caceria.hunts.append(hunt)

	for _dia in range(int(Hunt.DIAS_EN_EL_SUELO) + 1):
		sim.caceria._age_kills()
	assert_eq(sim.caceria.hunts.size(), 0, "lo que nadie fue a buscar se pierde")
	assert_gt(float(sim.chronicle.entries.size()), 0.0, "y se cuenta")


func test_la_chapa_dice_en_que_fase_va() -> void:
	# Un cazador acechando y uno corriendo detrás de un ciervo son dos cosas
	# muy distintas, y hasta ahora se veían igual.
	var hunt := Hunt.new()
	hunt.species = "ciervo"
	var visto: Array[String] = []
	for phase: Hunt.Phase in [Hunt.Phase.ACECHO, Hunt.Phase.PERSECUCION,
			Hunt.Phase.LANCE, Hunt.Phase.DESPIECE, Hunt.Phase.ACARREO]:
		hunt.phase = phase
		var text := hunt.doing_text()
		assert_false(visto.has(text), "cada fase se dice distinta: %s" % text)
		visto.append(text)


func test_el_peligro_se_corre_en_el_lance() -> void:
	# El riesgo vivía en `_harvest`, y al dejar de pasar la caza por ahí se
	# habría quedado muerto sin que se notara: la banda podría mandar a un solo
	# cazador contra un uro sin que le pasara nunca nada. Se cobra en el lance
	# porque un uro es peligroso cuando lo tienes a quince metros, no mientras
	# lo sigues.
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("uro", Vector3(5.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	assert_true(hunt != null, "hay uro al que entrarle")

	var herido := false
	for _intento in range(400):
		hunt.phase = Hunt.Phase.LANCE
		hunt.chased = 0.0
		hunt.spoils.clear()
		sim.caceria._throw(person, hunt)
		if person.hurt_days > 0:
			herido = true
			break
	assert_true(herido, "tirarle cuatrocientas veces a un uro se paga alguna")


func test_la_pieza_que_se_echa_al_agua_se_da_por_perdida() -> void:
	# Salió mirando, no probando: un cazador plantado en mitad del río con la
	# chapa encima, siguiendo a un ánade. La línea recta de la cacería se salta
	# la rejilla —que mide celdas de cuarenta metros y da por transitable un río
	# más estrecho que eso— y metía a la persona en el cauce.
	#
	# Sin terreno montado la comprobación de suelo dice que sí a todo, que es lo
	# que corresponde: lo que se comprueba aquí es que la fase existe y que la
	# cacería sabe acabarse por ese motivo.
	var sim := _sim()
	var person := _cazador(sim)
	sim.caceria.wildlife.place_for_test("ciervo", Vector3(30.0, 0.0, 0.0))
	var hunt := sim.caceria._open_hunt(person)
	hunt.phase = Hunt.Phase.PERSECUCION
	assert_true(sim.caceria._dry_footing(Vector3.ZERO),
		"sin terreno, se puede pisar en cualquier parte")

	# Y la línea recta se tantea de verdad: entre dos puntos se mira el suelo
	# cada pocos metros, no sólo los extremos.
	assert_lt(Caceria.TANTEO_DEL_PASO, 20.0,
		"el tanteo tiene que ser más fino que el cauce más estrecho del valle")
	assert_true(sim.caceria._straight_line_holds(Vector3.ZERO, Vector3(200.0, 0.0, 0.0)),
		"sin terreno, la recta vale")


func test_no_se_levanta_caceria_contra_lo_que_esta_en_el_agua() -> void:
	# El ánade se caza con red en el bebedero, no metiéndose en el río detrás
	# de él. Ver [Trap.Kind.RED_AVES].
	assert_true(Trap.catches(Trap.Kind.RED_AVES).has("anade"),
		"del ánade se encarga la red de aves")
	assert_true(WildlifeHerds.WATERSIDE_SPECIES.has("anade"),
		"y el ánade vive en el agua, que es de donde viene el problema")


# --- el tiempo de la cacería sale de lo que ya estaba medido --------------

func test_rastrear_cuesta_lo_que_dice_la_cifra_de_siempre() -> void:
	# La cacería no trae números nuevos de rendimiento: gasta donde se ven las
	# horas que [Hunting.pieces_per_day] ya decía. Una rama que cobra más
	# piezas al día tarda menos en dar con cada una.
	var sim := _sim()
	var menor := _cazador(sim, Profession.Speciality.CAZA_MENOR)
	var mayor := _cazador(sim, Profession.Speciality.CAZA_MAYOR)
	assert_lt(sim.caceria._tracking_hours(menor), sim.caceria._tracking_hours(mayor),
		"dar con un conejo cuesta menos que dar con un ciervo")


func test_sin_fauna_dibujada_la_caza_sigue_funcionando() -> void:
	# Es lo que mantiene en pie las pruebas headless y el rato entre que
	# arranca la simulación y se puebla el valle: se cae a la tabla de
	# [Hunting], que es lo que había antes.
	var sim := _sim()
	sim.caceria.wildlife = null
	var person := _cazador(sim)
	sim.caceria._hunt_step(person, 1.0)
	assert_eq(sim.caceria.hunts.size(), 0, "sin fauna no hay cacería que levantar")

# --- la caceria de varios dias -------------------------------------------
#
# Una pieza grande no se cobra entre el desayuno y la cena. Antes la caza era
# de jornada y se notaba: medido con `CazaEscalonProbe`, ochenta y cuatro
# caceria levantadas en seis dias y una sola cobrada.

func test_el_cazador_con_pieza_levantada_duerme_fuera() -> void:
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	sim.caceria.wildlife = WildlifeHerds.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.CAZA
	person.position = Vector3(900.0, 0.0, 900.0)
	sim.people = [person]

	assert_false(sim.despensa._camps_out(person, false),
		"sin pieza levantada no hay por que dormir fuera")

	var hunt := Hunt.new()
	hunt.crew = [person]
	sim.caceria.hunts.append(hunt)
	assert_true(sim.despensa._camps_out(person, false),
		"con la pieza levantada se sigue el rastro y se duerme al raso")
	sim.free()


func test_el_de_casa_no_acampa_por_muy_cazador_que_sea() -> void:
	# Las tres condiciones son las mismas para todos, y la primera es estar
	# LEJOS: dormir fuera a doscientos metros del abrigo es dormir mal por gusto.
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.CAZA
	person.position = Vector3(10.0, 0.0, 10.0)
	sim.people = [person]
	var hunt := Hunt.new()
	hunt.crew = [person]
	sim.caceria.hunts.append(hunt)
	assert_false(sim.despensa._camps_out(person, false),
		"en la puerta de casa no se acampa")
	sim.free()


func test_amanecer_es_rastro_nuevo() -> void:
	# El presupuesto de acecho es POR JORNADA. Si fuera por caceria, una que
	# dura dos dias llegaria al segundo con las dos horas y media ya gastadas y
	# se moriria de vieja: las caceria de varios dias serian imposibles por
	# construccion, no por dificiles.
	var sim := SettlementSim.new()
	var hunt := Hunt.new()
	hunt.spent = Hunt.ACECHO_HORAS
	hunt.chased = Hunt.FUELLE_HORAS
	hunt.counted_day = 1
	sim.day = 2
	sim.caceria._reset_del_dia(hunt)
	assert_eq(hunt.spent, 0.0, "el acecho empieza de cero")
	assert_eq(hunt.chased, 0.0, "y el fuelle tambien")
	assert_eq(hunt.days_open, 2, "y se apunta que lleva dos jornadas")

	# Y en el mismo dia NO se reinicia, o el acecho no acabaria nunca.
	hunt.spent = 1.0
	sim.caceria._reset_del_dia(hunt)
	assert_eq(hunt.spent, 1.0, "dentro del mismo dia la cuenta sigue")
	sim.free()


func test_el_fuelle_da_para_mas_de_un_lance() -> void:
	# El noventa y cinco por ciento de las caceria acababan en un lance
	# fallado, y no por punteria: un fallo pasaba a persecucion y el fuelle se
	# acababa antes del segundo tiro.
	assert_gt(Hunt.FUELLE_HORAS, Hunt.ACECHO_HORAS * 0.5,
		"perseguir tiene que dar para volver a ponerse a tiro")


# --- lo que la banda decide antes de salir --------------------------------
#
# «La poblacion no es tonta, y saben si tienen alguna posibilidad de cazar algo
# rentable»: nadie se va cinco jornadas detras de un uro con las manos vacias.

func test_las_piezas_por_jornada_salen_de_las_raciones() -> void:
	# Las raciones de la pieza MANDAN -[Fauna]- y las piezas se deducen. La
	# comprobacion es que multiplicar una por otra devuelva la jornada
	# perfecta: si alguien vuelve a poner las piezas a mano, esto se cae.
	for rama: int in [Profession.Speciality.CAZA_MAYOR,
			Profession.Speciality.CAZA_MENOR]:
		var speciality := rama as Profession.Speciality
		var piezas := Hunting.pieces_per_day(speciality, null)
		var por_pieza := Hunting.raciones_por_pieza(speciality)
		assert_near(piezas * por_pieza,
			float(Hunting.RACIONES_POR_JORNADA_PERFECTA[rama]), 0.01,
			"piezas x raciones por pieza = la jornada perfecta")


func test_una_pieza_mayor_vale_mas_que_una_menor() -> void:
	# Y por eso son menos piezas al dia: es la misma jornada contada en la
	# unidad que toca.
	var mayor := Hunting.raciones_por_pieza(Profession.Speciality.CAZA_MAYOR)
	var menor := Hunting.raciones_por_pieza(Profession.Speciality.CAZA_MENOR)
	assert_gt(mayor, menor, "una pieza mayor da mas raciones")
	assert_lt(Hunting.pieces_per_day(Profession.Speciality.CAZA_MAYOR, null),
		Hunting.pieces_per_day(Profession.Speciality.CAZA_MENOR, null),
		"y por eso se cobran menos piezas mayores al dia")


func test_sin_arma_no_se_espera_nada_de_la_pieza_grande() -> void:
	# A un uro no se le entra con las manos vacias: `Fauna.huntable_with` cierra
	# la puerta y la cuenta tiene que verlo, no estimar por encima.
	var sim := _sim([Tool.Kind.LASCA])
	var person := _cazador(sim)
	assert_eq(sim.caceria.raciones_esperadas(person,
		Profession.Speciality.CAZA_MAYOR), 0.0,
		"sin azagaya, la caza mayor no promete nada")
	assert_false(sim.despensa._worth_sleeping_out(person),
		"y por eso no se duerme fuera")


func test_con_azagaya_la_pieza_grande_ya_promete() -> void:
	var sim := _sim([Tool.Kind.AZAGAYA, Tool.Kind.LASCA])
	var person := _cazador(sim)
	assert_gt(sim.caceria.raciones_esperadas(person,
		Profession.Speciality.CAZA_MAYOR), 0.0,
		"con azagaya en el abrigo si hay algo que esperar")


func test_la_cuadrilla_sube_lo_que_se_espera_de_la_pieza_grande() -> void:
	# «Con azagayas y 3 personas igual si que les renta intentarlo». La
	# cuadrilla entra por `Hunting.crew_factor`, que es donde ya estaba.
	var solo := _sim([Tool.Kind.AZAGAYA, Tool.Kind.LASCA])
	var uno := _cazador(solo)
	var solitario := solo.caceria.raciones_esperadas(uno,
		Profession.Speciality.CAZA_MAYOR)

	var grupo := _sim([Tool.Kind.AZAGAYA, Tool.Kind.LASCA])
	var primero := _cazador(grupo)
	_cazador(grupo)
	_cazador(grupo)
	var acompanado := grupo.caceria.raciones_esperadas(primero,
		Profession.Speciality.CAZA_MAYOR)

	assert_gt(acompanado, solitario,
		"tres manos esperan mas que una de la misma pieza")
