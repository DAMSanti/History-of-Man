class_name TestJornada
extends TestCase
## Pruebas de la jornada: la noche, el petate y el agua.
##
## Las tres cosas se tocan. Cuando cae la noche solo se trabaja al fuego y en
## casa; para eso hay que haber vuelto, y para volver a tiempo hay que salir con
## antelacion; y no se puede pasar el dia fuera sin un odre lleno, que es una
## pieza del taller y no una piel del almacen.
##
## Medido antes de que existiera nada de esto, sitio 56, seis jornadas: a las
## nueve de la noche -la hora de dormir- quedaban dos personas andando por el
## monte y a las tres de la madrugada media; nadie trabajaba despues de las
## siete ni con el hogar encendido; habia 635 momentos de gente en el abrigo con
## 5,5 kg encima sin entregar; y las quince personas salian con odre teniendo el
## taller CERO odres hechos.


func suite_name() -> String:
	return "Jornada"


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	sim.home_forecourt = Vector3(11.0, 0.0, 0.0)
	return sim


func _person(sim: SettlementSim, at: Vector3 = Vector3.ZERO) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260907
	var person := Inhabitant.create(sim.people.size(), at, rng)
	person.position = at
	sim.people.append(person)
	return person


# --- de noche solo se trabaja al fuego -----------------------------------

func test_de_dia_se_trabaja_este_donde_este() -> void:
	var sim := _sim()
	var person := _person(sim, Vector3(900.0, 0.0, 900.0))
	sim.hour = 12.0
	assert_true(sim.hogar._can_work_at_night(person), "a mediodia se trabaja")


func test_anochecido_se_trabaja_en_el_abrigo_con_el_hogar_encendido() -> void:
	var sim := _sim()
	var person := _person(sim)
	sim.hour = SettlementSim.HORA_REGRESO + 0.5
	sim.hearth_lit = true
	assert_true(sim.hogar._can_work_at_night(person),
		"al fuego y en casa se sigue trabajando de noche")


func test_anochecido_sin_hogar_no_se_trabaja() -> void:
	var sim := _sim()
	var person := _person(sim)
	sim.hour = SettlementSim.HORA_REGRESO + 0.5
	sim.hearth_lit = false
	assert_false(sim.hogar._can_work_at_night(person),
		"sin fuego no hay luz con la que trabajar")


func test_anochecido_fuera_de_casa_no_se_trabaja() -> void:
	var sim := _sim()
	var person := _person(sim, Vector3(900.0, 0.0, 900.0))
	sim.hour = SettlementSim.HORA_REGRESO + 0.5
	sim.hearth_lit = true
	assert_false(sim.hogar._can_work_at_night(person),
		"el fuego del abrigo no alumbra a un kilometro")


func test_a_la_hora_de_dormir_se_acaba_para_todos() -> void:
	# La peticion es literal: «aun asi a las 9 se iran a dormir siempre».
	var sim := _sim()
	var person := _person(sim)
	sim.hour = SettlementSim.HORA_DORMIR
	sim.hearth_lit = true
	assert_false(sim.hogar._can_work_at_night(person),
		"a la hora de dormir se acaba, haya fuego o no")


# --- volver PARA el anochecer, no empezar a volver entonces --------------

func test_andar_lejos_lleva_mas_horas_que_andar_cerca() -> void:
	var sim := _sim()
	assert_gt(sim.marcha.hours_to_walk(2000.0), sim.marcha.hours_to_walk(200.0),
		"dos kilometros llevan mas que doscientos metros")
	assert_gt(sim.marcha.hours_to_walk(2000.0), 0.0, "y llevan un rato de verdad")


func test_la_vuelta_de_lejos_se_emprende_antes() -> void:
	# Es la cuenta que decide cuando dar media vuelta: si volver desde el tajo
	# lleva mas de lo que queda de luz, ya se va tarde.
	var sim := _sim()
	var lejos := sim.marcha.hours_to_walk(2000.0)
	assert_lt(SettlementSim.HORA_REGRESO - lejos, SettlementSim.HORA_REGRESO,
		"desde dos kilometros se sale antes que desde la puerta")


# --- el petate: piezas del taller, no materia prima ---------------------

func test_sin_odres_hechos_nadie_lleva_odre() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	sim.store.add(Materia.Kind.PIEL, 50.0)
	sim.store.add(Materia.Kind.FIBRA, 50.0)
	var person := _person(sim)
	sim.despensa._hand_out_containers(person)
	assert_false(person.has_waterskin,
		"un pellejo sin curtir en el almacen no es un odre")


func test_hay_tantos_odres_como_ha_hecho_el_taller() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL, 0.5)
	var uno := _person(sim)
	var otro := _person(sim)
	sim.despensa._hand_out_containers(uno)
	sim.despensa._hand_out_containers(otro)
	assert_true(uno.has_waterskin, "el primero coge el unico odre")
	assert_false(otro.has_waterskin, "y el segundo se queda sin el")


# --- el agua del dia -----------------------------------------------------

func test_con_odre_lleno_se_pasa_la_jornada_fuera() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL, 0.5)
	var person := _person(sim)
	sim.despensa._hand_out_containers(person)
	assert_true(person.water_left >= SettlementSim.HORAS_UTILES,
		"un odre lleno da para el dia entero, que es la peticion")


func test_sin_odre_no_se_pasa_la_jornada_fuera() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	var person := _person(sim)
	sim.despensa._hand_out_containers(person)
	assert_lt(person.water_left, SettlementSim.HORAS_UTILES,
		"sin odre no se aguanta el dia lejos del agua")
	assert_gt(person.water_left, 0.0, "pero se sale con lo bebido, no seco")

# --- lo primero al llegar es descargar -----------------------------------

func test_entregar_devuelve_los_recipientes_al_abrigo() -> void:
	# Se cogen al salir, de lo que hay hecho. Quedandoselos en casa, los dos
	# primeros que cogieron los dos unicos cestos no los soltaban nunca y el
	# resto de la banda salia a brazadas para siempre.
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	sim.toolkit.craft(Tool.Kind.CESTO, Tool.Stuff.FIBRA, 0.5)
	var person := _person(sim)
	sim.despensa._hand_out_containers(person)
	assert_true(person.has_basket, "sale con el cesto")
	sim.despensa._deliver(person)
	assert_false(person.has_basket, "y lo deja al entregar")


func test_entregar_vacia_lo_recogido_pero_no_el_petate() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	var person := _person(sim)
	person.add_load(Materia.Kind.FRUTO_SECO, 3.0)
	sim.despensa._deliver(person)
	assert_true(person.load.is_empty(), "lo cogido va al almacen entero")
	assert_gt(sim.store.amount(Materia.Kind.FRUTO_SECO), 0.0,
		"y aparece en la despensa")


# --- la sed parte la jornada --------------------------------------------

func test_sin_agua_se_deja_el_tajo_y_se_va_a_beber() -> void:
	var sim := _sim()
	sim._terrain = FakeTerrain.new()
	var person := _person(sim, Vector3(900.0, 0.0, 900.0))
	person.state = Inhabitant.State.TRABAJANDO
	person.water_left = 0.0
	sim.despensa._drink_and_thirst(person, 0.5)
	assert_false(person.state == Inhabitant.State.TRABAJANDO,
		"seco no se sigue trabajando: se va a por agua")


func test_dormir_no_da_sed() -> void:
	# De noche no se suda ni se bebe. Sin esto, quien acampa fuera amanecia
	# seco y lo primero que hacia era un viaje al rio en vez de su jornada.
	var sim := _sim()
	sim._terrain = FakeTerrain.new()
	var person := _person(sim, Vector3(900.0, 0.0, 900.0))
	person.state = Inhabitant.State.DURMIENDO
	person.water_left = 3.0
	sim.despensa._drink_and_thirst(person, 8.0)
	assert_eq(person.water_left, 3.0, "la noche no gasta agua")

# --- el trampero no sale de vacio ----------------------------------------

func test_sin_fibra_ni_lena_no_se_sale_a_trampear() -> void:
	# Armar una trampa cuesta material -ver `Trap.materials`- y eso se miraba
	# YA EN EL MONTE: se andaba el kilometro para apuntar «sin material para
	# armar mas trampas» y volver.
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.techs = TechTree.new()
	sim.techs.known[TechTree.Tech.LAZO] = true
	assert_false(sim._speciality_can_work(Profession.Speciality.TRAMPAS),
		"con el abrigo vacio no se sale a trampear")


func test_con_material_si_se_sale_a_trampear() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	# Todas las trampas piden tecnica -ver `Trap.tech_of`-, asi que sin arbol
	# no se sabe armar ninguna y el material no basta.
	sim.techs = TechTree.new()
	sim.techs.known[TechTree.Tech.LAZO] = true
	sim.store.add(Materia.Kind.FIBRA, 20.0)
	sim.store.add(Materia.Kind.LENA, 20.0)
	assert_true(sim._speciality_can_work(Profession.Speciality.TRAMPAS),
		"con fibra y leña si")


func test_con_trampas_puestas_se_sale_aunque_no_haya_material() -> void:
	# Levantar lo que ya esta armado es la mitad del oficio y no cuesta nada.
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.trampas.traps.append(Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1, "Beru"))
	assert_true(sim._speciality_can_work(Profession.Speciality.TRAMPAS),
		"a recorrer la linea se sale igual")


# --- produce y gasta, en la misma escala ---------------------------------

func test_produce_se_mide_en_el_mismo_periodo_que_el_gasto() -> void:
	# Las dos columnas se leen juntas -entra tanto, se va tanto- y estaban en
	# escalas distintas por un factor de treinta: PRODUCE iba por dia y GASTA
	# por [CONSUMO_DIAS].
	var sim := _sim()
	sim.store = Storehouse.new()
	# Un mes entero produciendo dos al dia.
	for i in range(SettlementSim.CONSUMO_DIAS):
		sim.taller.note_production(Materia.Kind.LENA, 2.0)
		sim.tajo._roll_production()
	assert_near(sim.taller.production_of(Materia.Kind.LENA),
		2.0 * float(SettlementSim.CONSUMO_DIAS), 2.5,
		"el mes suma lo de los treinta dias, no la media de uno")


func test_produce_se_proyecta_mientras_no_haya_mes_entero() -> void:
	# Al tercer dia de partida no hay treinta jornadas que sumar. Sumando solo
	# las que hay, la banda parecia arruinada siempre.
	var sim := _sim()
	sim.store = Storehouse.new()
	for i in range(3):
		sim.taller.note_production(Materia.Kind.LENA, 2.0)
		sim.tajo._roll_production()
	assert_gt(sim.taller.production_of(Materia.Kind.LENA), 40.0,
		"tres dias a dos proyectan a mes, no se quedan en seis")


func test_el_registro_de_produccion_no_crece_sin_fin() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	for i in range(SettlementSim.CONSUMO_DIAS * 3):
		sim.taller.note_production(Materia.Kind.LENA, 1.0)
		sim.tajo._roll_production()
	assert_eq(sim.taller.produced_days.size(), SettlementSim.CONSUMO_DIAS,
		"solo se guardan los dias del periodo")

# --- el almacen guarda odres llenos, no agua a granel --------------------

func test_los_odres_llenos_del_abrigo_son_los_que_hay_menos_los_que_salen() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL, 0.5)
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL, 0.5)
	var person := _person(sim)
	sim.despensa._sync_waterskins()
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 2.0,
		"dos odres hechos y nadie fuera: dos colgados en la boca")
	sim.despensa._hand_out_containers(person)
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 1.0,
		"el que sale se lleva el suyo")
	sim.despensa._deliver(person)
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 2.0,
		"y al volver lo cuelga otra vez, lleno del rio de la puerta")


func test_sin_odres_hechos_no_hay_agua_guardada() -> void:
	# El agua no se tiene a granel: si no hay odre, no hay donde meterla.
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	sim.store.add(Materia.Kind.AGUA, 9.0)
	sim.despensa._sync_waterskins()
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"sin odres, el agua guardada no existe")


# --- lo que no se sabe hacer, no se hace ---------------------------------

func test_sin_la_tecnica_no_se_sabe_hacer_la_pieza() -> void:
	var sim := _sim()
	sim.techs = TechTree.new()
	assert_false(sim.taller.knows_tool(Tool.Kind.ARPON),
		"un arpon pide su tecnica")
	sim.techs.known[TechTree.Tech.ARPON] = true
	assert_true(sim.taller.knows_tool(Tool.Kind.ARPON),
		"y con ella aparece")


func test_las_piezas_de_siempre_no_piden_tecnica() -> void:
	# El buril y el punzon son requisito de otras piezas -ver `Tool.needs_tool`-
	# y cerrarlos cerraria la cadena entera del taller.
	var sim := _sim()
	sim.techs = TechTree.new()
	for kind: int in [Tool.Kind.LASCA, Tool.Kind.BURIL, Tool.Kind.RAEDERA,
		Tool.Kind.PUNZON, Tool.Kind.CESTO, Tool.Kind.ODRE, Tool.Kind.CUERDA]:
		assert_true(sim.taller.knows_tool(kind as Tool.Kind),
			"%s se sabe hacer desde el principio" % Tool.kind_name(
				kind as Tool.Kind))


func test_sin_arbol_de_tecnicas_se_sabe_hacer_todo() -> void:
	# Las pruebas y las sondas montan simulaciones a medias, sin arbol.
	var sim := _sim()
	for kind: int in Tool.Kind.values():
		assert_true(sim.taller.knows_tool(kind as Tool.Kind),
			"sin arbol que consultar no se cierra nada")

# --- se come dos veces al dia --------------------------------------------
#
# Antes se comia de tres maneras y ninguna era una comida: un desayuno si se
# tenia hambre, un bocado del zurron a mediodia, y ademas cualquier rato
# muerto con el hambre por encima de 55. La banda picaba todo el dia y no se
# sentaba nunca. Medido con `scripts/tests/CosechaVivaProbe.gd` despues: el
# hambre solo baja a las 06h y a las 21h, y el pico de la jornada es 47.

func test_las_dos_comidas_son_al_despertar_y_a_las_nueve() -> void:
	assert_eq(SettlementSim.HORA_DESAYUNO, SettlementSim.HORA_DESPERTAR,
		"se desayuna al levantarse")
	assert_eq(SettlementSim.HORA_CENA, SettlementSim.HORA_DORMIR,
		"y se cena a la hora de recogerse")


func test_una_comida_dura_lo_suyo() -> void:
	# Sin ventana, la cena caeria en el instante exacto de las nueve y se la
	# saltaria cualquiera cuyo tick no cayera justo ahi.
	assert_gt(SettlementSim.DURA_LA_COMIDA, 0.0, "comer lleva un rato")


func test_comer_baja_el_hambre_y_levanta_de_la_mesa() -> void:
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.FRUTO_SECO, 40.0)
	var person := _person(sim)
	person.hunger = 80.0
	person.state = Inhabitant.State.COMIENDO
	sim.despensa._eat_meal(person, 1.0)
	assert_lt(person.hunger, 80.0, "comer quita hambre")


func test_sin_comida_no_se_queda_uno_sentado_a_la_mesa() -> void:
	# El fallo de siempre: con el almacen vacio se entraba en COMIENDO, no se
	# comia nada y se repetia, que es una espiral de hambre.
	var sim := _sim()
	sim.store = Storehouse.new()
	var person := _person(sim)
	person.hunger = 80.0
	person.state = Inhabitant.State.COMIENDO
	sim.despensa._eat_meal(person, 1.0)
	assert_eq(person.state, Inhabitant.State.OCIOSO,
		"sin nada que comer, se levanta de la mesa")


# --- recoger y vaciar son la misma cosa ----------------------------------

func test_la_merma_sigue_a_lo_que_se_coge() -> void:
	# El paraje perdia lo mismo por jornada trabajada cogiera la persona el
	# cesto lleno o volviera de vacio: recoger y vaciar eran dos numeros que no
	# se hablaban, y eso es lo que hacia que la recoleccion se leyera como un
	# trabajo binario.
	assert_gt(SettlementSim.DEPLETION_PER_UNIT, 0.0,
		"cada unidad que sale del sitio se le resta al sitio")
	assert_near(SettlementSim.DEPLETION_PER_UNIT
		* SettlementSim.UNIDADES_POR_JORNADA,
		SettlementSim.DEPLETION_PER_DAY, 0.0001,
		"y una jornada normal merma lo mismo que antes: solo cambia que ahora"
		+ " sigue a la mano que coge")

func test_al_saciado_no_se_le_vuelve_a_sentar_a_la_mesa() -> void:
	# La hora del desayuno dura una hora entera y se mira en CADA tick. Sin
	# filtro de hambre, quien acababa de comer volvia a sentarse al tick
	# siguiente, y cada vuelta sacaba comida del almacen: medido, la despensa
	# pasaba de ocho dias de reserva a CERO en ocho jornadas.
	var sim := _sim()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.FRUTO_SECO, 200.0)
	var before := sim.store.food_rations()
	var person := _person(sim)
	person.hunger = 0.0
	person.state = Inhabitant.State.COMIENDO
	sim.despensa._eat_meal(person, 1.0)
	assert_eq(person.state, Inhabitant.State.OCIOSO,
		"el saciado se levanta")
	assert_lt(SettlementSim.COMIDA_SUFICIENTE, 55.0,
		"y con menos hambre que esto ni se sienta")
	assert_gt(before, 0.0, "habia comida de sobra, o sea que no era eso")

# --- la comida se mide en calorias ---------------------------------------

func test_una_racion_es_media_jornada() -> void:
	# Peticion literal: «una racion es el equivalente a la mitad del consumo
	# calorico del dia, es decir, lo que come una persona en cada comida».
	assert_near(Materia.KCAL_RACION, Materia.KCAL_DIA * 0.5, 0.01,
		"media jornada")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var adulto := Inhabitant.create(0, Vector3.ZERO, rng)
	adulto.age_group = Inhabitant.Age.ADULTO
	assert_near(adulto.daily_food(), 2.0, 0.01,
		"y un adulto come dos al dia, una por comida")


func test_las_raciones_salen_de_las_calorias_y_no_de_una_tabla() -> void:
	for kind: int in [Materia.Kind.FRUTO_SECO, Materia.Kind.CARNE,
		Materia.Kind.PESCADO, Materia.Kind.MIEL]:
		var k := kind as Materia.Kind
		assert_near(Materia.nutrition(k),
			Materia.kcal(k) / Materia.KCAL_RACION, 0.0001,
			"%s: la racion se deriva" % Materia.material_name(k))


func test_curar_conserva_pero_no_crea_alimento() -> void:
	# Ahumar quita agua y peso; no anade una caloria. La unidad es una porcion
	# de racion, asi que la seca tiene que dar lo mismo que la fresca.
	assert_near(Materia.kcal(Materia.Kind.CARNE_SECA),
		Materia.kcal(Materia.Kind.CARNE), 0.01, "la carne, igual")
	assert_near(Materia.kcal(Materia.Kind.PESCADO_SECO),
		Materia.kcal(Materia.Kind.PESCADO), 0.01, "y el pescado")
	assert_lt(Materia.kg_per_unit(Materia.Kind.CARNE_SECA),
		Materia.kg_per_unit(Materia.Kind.CARNE),
		"pero pesa mucho menos, que es para lo que se cura")


func test_la_barra_de_hambre_es_la_jornada() -> void:
	# De 0 a 100 va un dia entero: asi una racion -media jornada- quita
	# cincuenta, y las dos comidas del dia suman cien.
	assert_near(SettlementSim.HAMBRE_POR_RACION, 50.0, 0.01, "media barra")
	assert_near(SettlementSim.HAMBRE_POR_HORA * 24.0, 100.0, 0.01,
		"y el dia entero la llena")


# --- el recolector recoge, y nada mas ------------------------------------

func test_el_recolector_no_trae_caza_ni_pesca() -> void:
	# En las tablas ya no habia carne bajo recoleccion, pero eso era una
	# propiedad de los DATOS: cualquier extra de temporada podia colar una
	# pieza en el zurron de quien salio a por avellanas.
	for kind: int in Tajo.SOLO_DE_CAZA_O_PESCA:
		assert_true(Materia.is_food(kind as Materia.Kind),
			"lo que se veta es comida de caza o pesca, no materia prima")
	assert_false(Tajo.SOLO_DE_CAZA_O_PESCA.has(Materia.Kind.HUEVO),
		"el huevo se coge agachandose: eso es recoleccion")
	assert_false(Tajo.SOLO_DE_CAZA_O_PESCA.has(Materia.Kind.CARACOL),
		"y el caracol tambien")


# --- el hogar es uno y lo hace todo --------------------------------------

func test_el_hogar_no_se_reparte() -> void:
	assert_eq(Profession.specialities_of(Profession.Job.HOGAR).size(), 0,
		"en el Paleolitico el hogar lo hace todo")


func test_armar_el_vivac_es_saber_del_hogar() -> void:
	# Se puede llevar la piel y la leña y aun asi montar algo que no aguanta la
	# noche. Quien sabe de hogar lo arma bien mas veces.
	var sim := _sim()
	sim._rng = RandomNumberGenerator.new()
	sim._rng.seed = 20260907
	var torpe := _person(sim)
	var mano := _person(sim)
	mano.skill[Profession.task_id(Profession.Job.HOGAR)] = 0.95

	var bien_torpe := 0
	var bien_mano := 0
	for i in range(400):
		if sim.despensa._camps_well(torpe):
			bien_torpe += 1
		if sim.despensa._camps_well(mano):
			bien_mano += 1
	assert_gt(bien_mano, bien_torpe,
		"quien sabe de hogar arma mejor el vivac")
	assert_gt(bien_torpe, 0, "y el torpe acierta a veces: no es imposible")
