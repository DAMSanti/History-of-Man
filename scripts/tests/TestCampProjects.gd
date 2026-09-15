class_name TestCampProjects
extends TestCase
## Pruebas de las mejoras del abrigo.
##
## Lo que importa comprobar es la dependencia: el secadero pide el hogar
## porque ahumar sin fuego no se hace, y esa regla vive en los datos, no en
## quien los use.


func suite_name() -> String:
	return "Campamento"


func test_el_hogar_no_depende_de_nada() -> void:
	assert_eq(CampProjects.requires(CampProjects.Kind.HOGAR), -1,
		"es lo primero que se puede levantar")


func test_las_plazas_de_abrigo_suben_con_el_paraviento() -> void:
	var sim := SettlementSim.new()
	var base := sim.plazas_abrigo()
	sim.camp_built[CampProjects.Kind.PARAVIENTO] = true
	assert_eq(sim.plazas_abrigo(), base + SettlementSim.PLAZAS_ABRIGO_POR_PARAVIENTO,
		"levantar un paraviento aumenta el aforo del abrigo")


func test_el_paraviento_no_depende_de_nada() -> void:
	# Es un cierre, no una fuente de calor: no necesita el hogar, igual que
	# el lavadero no necesita fuego para dejarse en el remanso.
	assert_eq(CampProjects.requires(CampProjects.Kind.PARAVIENTO), -1,
		"se puede levantar sin hogar previo")


func test_el_paraviento_se_cierra_con_piel_curtida() -> void:
	# Decisión del usuario del 2026-09-13: la piel cruda sólo sirve para
	# curtirla —y para el trueque—. Un cierre de pellejo sin curar se pudre en
	# la boca de la cueva.
	var receta := CampProjects.materials(CampProjects.Kind.PARAVIENTO)
	assert_true(receta.has(Materia.Kind.PIEL_CURTIDA), "pide piel curtida")
	assert_false(receta.has(Materia.Kind.PIEL), "y no cruda")


func test_el_secadero_exige_el_hogar() -> void:
	assert_eq(CampProjects.requires(CampProjects.Kind.SECADERO),
		CampProjects.Kind.HOGAR, "ahumar sin fuego no se hace")


func test_cada_proyecto_tiene_receta_y_jornadas() -> void:
	for kind: int in CampProjects.all():
		var materials := CampProjects.materials(kind as CampProjects.Kind)
		assert_true(materials.size() > 0, "%s pide algún material" % kind)
		assert_true(CampProjects.labor_days(kind as CampProjects.Kind) > 0.0,
			"%s cuesta jornadas de trabajo" % kind)
		assert_true(CampProjects.project_name(kind as CampProjects.Kind).length() > 0,
			"tiene nombre")


# --- el secadero ahúma pescado, no solo carne ----------------------------

func test_el_secadero_ahuma_el_pescado() -> void:
	# Queja literal: «los pescadores pescan pero no está subiendo el pescado
	# al almacén». Y no subía: el pescado fresco aguanta TRES DÍAS —uno menos
	# que la carne— y el secadero solo curaba carne, así que la banda
	# descargaba cincuenta raciones al día y el montón se quedaba clavado
	# porque se pudría igual de rápido que entraba.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim.hogar._dry_meat(1.0, 1.0)

	assert_true(sim.store.amount(Materia.Kind.PESCADO_SECO) > 0.0,
		"el pescado se ahúma")
	assert_true(sim.store.amount(Materia.Kind.PESCADO) < 30.0,
		"y sale del montón de fresco")


## Lo que sale del secadero cuenta como PRODUCIDO.
##
## Queja literal: «la producción de carne seca, o pescado seco no se cuenta
## como producido/30 días». La carne fresca GASTADA sí se apuntaba —eso lo hace
## `Storehouse.take` solo— pero la seca producida no, así que su columna salía
## en cero por muchas tiras que se colgaran. El lavadero de bellota, que es la
## misma clase de faena, ya lo apuntaba.
func test_lo_ahumado_cuenta_como_producido() -> void:
	# Cada uno por su lado: el secadero cura primero lo que antes se pudre, asi
	# que con pescado delante no le llega el turno a la carne.
	var con_carne := SettlementSim.new()
	con_carne.store.add(Materia.Kind.CARNE, 40.0)
	con_carne.hogar._dry_meat(1.0, 1.0)
	assert_gt(float(con_carne.taller.produced_today.get(
		int(Materia.Kind.CARNE_SECA), 0.0)),
		0.0, "la cecina que sale del secadero entra en el libro")

	var con_pescado := SettlementSim.new()
	con_pescado.store.add(Materia.Kind.PESCADO, 40.0)
	con_pescado.hogar._dry_meat(1.0, 1.0)
	assert_gt(float(con_pescado.taller.produced_today.get(
		int(Materia.Kind.PESCADO_SECO), 0.0)),
		0.0, "y el pescado seco tambien")


func test_se_cura_antes_lo_que_antes_se_pudre() -> void:
	# Con las dos cosas en el abrigo y un secadero que no da para todo, se
	# salva primero el pescado, que aguanta tres días contra los cuatro de la
	# carne. Salvar la carne y dejar podrir el pescado sería al revés.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.PESCADO, 100.0)
	sim.store.add(Materia.Kind.CARNE, 100.0)
	sim.hogar._dry_meat(1.0, 1.0)

	assert_true(Materia.shelf_life(Materia.Kind.PESCADO)
		< Materia.shelf_life(Materia.Kind.CARNE),
		"el pescado aguanta menos que la carne")
	assert_true(sim.store.amount(Materia.Kind.PESCADO_SECO) > 0.0,
		"se ahúma el pescado primero")
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"y la carne espera su turno")


func test_el_pescado_seco_aguanta_el_invierno() -> void:
	# Es la razón entera de plantarse en el río cuando sube el remonte: no se
	# pesca para comer hoy, se pesca para comer en enero.
	assert_true(Materia.shelf_life(Materia.Kind.PESCADO_SECO) > 150,
		"ahumado, media vuelta al año")
	assert_true(Materia.is_food(Materia.Kind.PESCADO_SECO), "y alimenta")
	assert_eq(Materia.nutrition(Materia.Kind.PESCADO_SECO),
		Materia.nutrition(Materia.Kind.PESCADO),
		"lo mismo que fresco: curar no añade comida, la conserva")


func test_el_secadero_da_para_un_remonte() -> void:
	# Medido: tres personas en la orilla descargaban 53 raciones al día. Con
	# los cuatro de antes, ahumar era un gesto simbólico.
	assert_true(Hogar.DRY_PER_DAY >= 20.0,
		"un bastidor sobre el hogar cura una jornada de pesca de verdad")


# --- el fuego: saber inicial, no investigación ---------------------------
#
# SLICE_PALEOLITICO §1 lo tiene como ATESTIGUADO: una banda del Magdaleniense
# sabe hacer fuego desde antes de llegar. Estaba en el árbol de técnicas como
# veinte jornadas de investigación, que es el tópico de género que el propio
# documento de diseño desmonta.

func test_el_fuego_no_se_investiga() -> void:
	for tech: int in TechTree.CATALOGUE.keys():
		assert_false(TechTree.tech_name(tech as TechTree.Tech).to_lower()
			.contains("fuego"),
			"el fuego no es una tecnica que se descubra")


func test_el_arte_pide_hogar_construido() -> void:
	# Necesita fuego DE VERDAD -una cueva se pinta con luz- y por eso dependia
	# de `Tech.FUEGO`. Al quitarlo, la dependencia pasa a un hecho del
	# campamento, no a un saber. La piragua pedia lo mismo y salio del
	# Paleolitico el 2026-09-13: es del Mesolitico, ver EPOCA_02.
	for tech: TechTree.Tech in [TechTree.Tech.ARTE]:
		assert_eq(TechTree.needs_camp(tech), CampProjects.Kind.HOGAR,
			"%s pide hogar levantado" % TechTree.tech_name(tech))


func test_sin_hogar_no_se_alcanza_el_arte() -> void:
	var tree := TechTree.new()
	# El arte cuelga de la HOJA, no del nucleo: la piragua era la del nucleo.
	tree.known[TechTree.Tech.HOJA] = true
	assert_false(tree.is_available(TechTree.Tech.ARTE),
		"con la hoja pero sin hogar, todavia no")

	tree.camp_built[CampProjects.Kind.HOGAR] = true
	assert_true(tree.is_available(TechTree.Tech.ARTE),
		"con el hogar levantado, ya")


# --- el hogar se apaga de verdad ----------------------------------------
#
# Antes `_tend_camp` escribia «manteniendo el fuego» y ahi se acababa: ni
# gastaba lena, ni podia apagarse, ni pasaba nada si no lo cuidaba nadie.

func _con_hogar(lena: float = 50.0) -> SettlementSim:
	var sim := SettlementSim.new()
	# La cronica NO es opcional aqui. Sin ella, `test_apagarse_deja_rastro`
	# reventaba con «Invalid access to property 'entries' on Nil», el marco se
	# comia el error y la prueba figuraba como pasada sin haber comprobado nada.
	sim.chronicle = Chronicle.new()
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.hearth_lit = true
	sim._hearth_tended = true
	sim.store.add(Materia.Kind.LENA, lena)
	return sim


func test_levantar_el_hogar_lo_deja_prendido() -> void:
	# Nadie delimita una fogata con piedras para dejarla apagada.
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	sim.people = [person]
	sim.store.add(Materia.Kind.PIEDRA, 20.0)
	sim.store.add(Materia.Kind.LENA, 20.0)
	assert_true(sim.queue_project(CampProjects.Kind.HOGAR), "se pone en cola")
	assert_false(sim.hearth_lit, "todavia no hay fuego")

	for _i in range(20):
		sim.hogar._work_on_project(person, 1.0)
	assert_true(sim.camp_built.get(CampProjects.Kind.HOGAR, false),
		"la obra termina")
	assert_true(sim.hearth_lit, "y queda prendido")


## El hogar, en horas: `veces` ticks de `horas` cada uno, con los materiales.
func _hogar_tras(horas_por_tick: float, veces: int, pericia_baja: bool) -> SettlementSim:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	if pericia_baja:
		person.hunger = 200.0
	sim.people = [person]
	sim.store.add(Materia.Kind.PIEDRA, 20.0)
	sim.store.add(Materia.Kind.LENA, 20.0)
	sim.queue_project(CampProjects.Kind.HOGAR)
	for _i in range(veces):
		sim.hogar._work_on_project(person, horas_por_tick / SettlementSim.HORAS_UTILES)
	return sim


func test_el_hogar_se_levanta_en_cuatro_horas_y_no_en_tres() -> void:
	# Decisión del usuario (2026-09-13): «4 horas de trabajo de hogar una vez
	# tenga los materiales». A cachos de un cuarto de hora, como un tick.
	assert_true(_hogar_tras(0.25, 16, false).camp_built.get(
		CampProjects.Kind.HOGAR, false), "a las cuatro horas está levantado")
	assert_false(_hogar_tras(0.25, 12, false).camp_built.get(
		CampProjects.Kind.HOGAR, false), "a las tres, no")


func test_las_cuatro_horas_no_las_estira_la_pericia() -> void:
	assert_true(_hogar_tras(1.0, 4, true).camp_built.get(
		CampProjects.Kind.HOGAR, false), "uno hambriento también en cuatro horas")


func test_el_hogar_se_cuenta_en_horas() -> void:
	assert_eq(CampProjects.trabajo_texto(CampProjects.Kind.HOGAR), "4 horas de hogar",
		"el hogar se dice en horas, no en «0 jornadas»")
	assert_eq(CampProjects.trabajo_texto(CampProjects.Kind.HOGAR,
		1.0 / SettlementSim.HORAS_UTILES), "1 de 4 horas", "y lo que va, también")


func test_el_hogar_gasta_lena_cada_dia() -> void:
	var sim := _con_hogar()
	var antes := sim.store.amount(Materia.Kind.LENA)
	sim.hogar._burn_hearth()
	assert_true(sim.hearth_lit, "con lena, sigue encendido")
	assert_lt(sim.store.amount(Materia.Kind.LENA), antes,
		"y se ha llevado su parte")


func test_sin_lena_el_hogar_se_apaga() -> void:
	var sim := _con_hogar(0.0)
	sim.hogar._burn_hearth()
	assert_false(sim.hearth_lit, "sin lena no hay fuego")


func test_sin_nadie_que_lo_cuide_el_hogar_se_apaga() -> void:
	# Es lo que hace que el minimo de gente en el hogar signifique algo: antes
	# se podia dejar el oficio vacio y no pasaba nada.
	var sim := _con_hogar()
	sim._hearth_tended = false
	sim.hogar._burn_hearth()
	assert_false(sim.hearth_lit, "un hogar sin nadie encima se apaga solo")


func test_apagarse_deja_rastro_en_la_cronica() -> void:
	# Un castigo invisible es la peor clase de castigo.
	var sim := _con_hogar(0.0)
	var antes := sim.chronicle.entries.size()
	sim.hogar._burn_hearth()
	assert_gt(float(sim.chronicle.entries.size()), float(antes),
		"que se apague el fuego se cuenta")


func test_el_invierno_se_lleva_mas_lena() -> void:
	assert_gt(SettlementSim.HEARTH_WINTER_FACTOR, 1.0,
		"en invierno el fuego se aviva y ademas se pasa el dia dentro")


func test_reavivar_cuesta_jornada_y_lena() -> void:
	var sim := _con_hogar()
	sim.hearth_lit = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	sim.people = [person]

	var lena := sim.store.amount(Materia.Kind.LENA)
	# Una fraccion corta de jornada no basta
	sim.hogar._relight_hearth(person, 0.05)
	assert_false(sim.hearth_lit, "con un rato no se levanta un hogar")

	for _i in range(20):
		sim.hogar._relight_hearth(person, 0.2)
	assert_true(sim.hearth_lit, "con jornada, si")
	assert_lt(sim.store.amount(Materia.Kind.LENA), lena, "y se gasta lena")


## Queja del usuario (2026-09-13): «hay ocasiones en que se apaga teniendo
## leña, y tardan días en encenderlo si lo encienden». Con una obra en cola, el
## del hogar se ponía con la obra ANTES de mirar el fuego —y si a la obra le
## faltaba material, se pasaba la jornada esperándolo—: ni lo cuidaba, así que
## se apagaba esa noche, ni lo prendía mientras la obra siguiera en cola.
func _del_hogar_con_obra_parada(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.HOGAR
	sim.people = [person]
	# El secadero pide material que no hay: la obra se queda esperando.
	sim.camp_queue = CampProjects.Kind.SECADERO
	return person


func test_con_una_obra_parada_el_hogar_se_sigue_cuidando() -> void:
	var sim := _con_hogar()
	var person := _del_hogar_con_obra_parada(sim)
	sim._hearth_tended = false
	sim.hogar._tend_camp(person, SettlementSim.HORAS_UTILES)
	assert_true(sim._hearth_tended, "el fuego se cuida aunque haya obra en cola")
	sim.hogar._burn_hearth()
	assert_true(sim.hearth_lit, "y esa noche no se apaga")


func test_con_una_obra_parada_el_hogar_apagado_se_prende_primero() -> void:
	var sim := _con_hogar()
	sim.hearth_lit = false
	var person := _del_hogar_con_obra_parada(sim)
	sim.hogar._tend_camp(person, SettlementSim.HORAS_UTILES)
	assert_true(sim.hearth_lit,
		"con leña, una jornada del hogar prende el fuego antes que la obra")


func test_sin_lena_no_se_puede_reavivar() -> void:
	var sim := _con_hogar(0.0)
	sim.hearth_lit = false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	sim.people = [person]
	for _i in range(20):
		sim.hogar._relight_hearth(person, 0.5)
	assert_false(sim.hearth_lit, "sin lena no se prende nada")


func test_apagado_no_se_ahuma() -> void:
	# La consecuencia que pedia el diseno: sin fuego no hay secadero que valga.
	var sim := _con_hogar()
	sim.camp_built[CampProjects.Kind.SECADERO] = true
	sim.hearth_lit = false
	sim.store.add(Materia.Kind.CARNE, 40.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	sim.people = [person]

	sim.hogar._tend_camp(person, SettlementSim.HORAS_UTILES)
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"con el hogar frio no se ahuma nada")


func test_el_yesquero_estira_la_lena() -> void:
	assert_lt(SettlementSim.YESQUERO_SAVING, 1.0,
		"quien sabe de fuego gasta menos")
	assert_gt(SettlementSim.YESQUERO_BONUS, 1.0,
		"y lo levanta antes")


func test_el_cuidado_acorta_la_convalecencia() -> void:
	assert_gt(float(SettlementSim.CUIDADO_DAYS), 0.0,
		"cuidar de los heridos tiene que servir de algo, o es un rotulo")


# --- llenar odres: un odre hecho no es un odre lleno ---------------------
#
# Antes `_sync_waterskins` daba por lleno cualquier odre que hubiera en el
# taller. Un odre es un recipiente vacío hasta que alguien lo llena con
# trabajo de hogar -ver [Hogar._fill_waterskins]-, igual que un cesto vacío
# no da comida solo por existir.

func _hogar_con(rng_seed: int) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	Profession.assign(Profession.Job.HOGAR, person)
	return person


func test_los_odres_vacios_se_llenan_con_trabajo_de_hogar() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.people = [_hogar_con(1)]

	assert_eq(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"un odre recien hecho arranca vacío")
	sim.hogar._fill_waterskins()
	assert_gt(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"con alguien en el hogar, se van llenando")


func test_no_se_llenan_mas_odres_de_los_que_existen() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.people = [_hogar_con(1)]

	for i in range(10):
		sim.hogar._fill_waterskins()
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 1.0,
		"un solo odre no puede dar mas de un odre lleno, por muchos dias que pasen")


func test_sin_nadie_en_el_hogar_no_se_llenan_odres() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.hogar._fill_waterskins()
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"sin nadie de hogar, nadie va a por agua")


# --- cuevas que no estan pegadas al agua ----------------------------------
#
# «Tanto beber del río como llenar los odres debe ser una salida y marcarse
# como tal, quizá haya cuevas que no estén pegadas al agua». Antes de esto,
# _home_by_water no existia y se asumia que si, siempre. Ahora depende del
# terreno de verdad.

func test_home_by_water_depende_del_terreno_de_verdad() -> void:
	var sim := SettlementSim.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3.ZERO
	assert_false(sim.hogar._home_by_water(),
		"lejos del rio de FakeTerrain, el abrigo no esta junto al agua")

	sim.home_position = Vector3(0.0, 0.0, FakeTerrain.RIVER_Z)
	assert_true(sim.hogar._home_by_water(),
		"junto al rio, si lo esta")


func test_sin_terreno_se_asume_junto_al_agua() -> void:
	# Mismo patron que `Taller.knows_tool` con el arbol de tecnicas: un
	# montaje de prueba que no trae terreno no tiene por que probar esto.
	var sim := SettlementSim.new()
	assert_true(sim.hogar._home_by_water(),
		"sin terreno que consultar, se asume el comportamiento de siempre")


func test_lejos_del_agua_no_se_llena_pasivamente() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3.ZERO
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.people = [_hogar_con(1)]

	sim.hogar._fill_waterskins()
	assert_eq(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"sin rio a la puerta, llenar en el sitio ya no es gratis")


func test_lejos_del_agua_alguien_de_hogar_sale_a_por_ella() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3.ZERO
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	var person := _hogar_con(1)
	person.position = Vector3.ZERO
	sim.people = [person]

	assert_true(sim.hogar._fetch_water(person),
		"con odres vacios y el abrigo lejos del agua, alguien sale")
	assert_eq(person.state, Inhabitant.State.YENDO, "de camino, no en el sitio")
	assert_false(person.journey.is_empty(), "y la salida queda marcada como tal")


func test_por_agua_no_sale_nadie_si_el_abrigo_ya_esta_junto_al_rio() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(0.0, 0.0, FakeTerrain.RIVER_Z)
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	var person := _hogar_con(1)
	sim.people = [person]

	assert_false(sim.hogar._fetch_water(person),
		"junto al rio, llenar sigue siendo tarea pasiva, no una salida")


func test_llegar_a_la_orilla_llena_odres_y_manda_de_vuelta() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3.ZERO
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	var person := _hogar_con(1)
	sim.people = [person]

	sim.hogar._arrive_at_water(person)
	assert_gt(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"llegar a la orilla llena lo que da de si un acarreo")
	assert_eq(person.state, Inhabitant.State.VOLVIENDO,
		"y manda de vuelta a casa, no se queda en la orilla")


func test_un_odre_roto_pierde_el_agua_que_llevaba() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	var tool := sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.store.add(Materia.Kind.AGUA, 1.0)

	tool.wear(tool.durability())
	sim.toolkit.discard_spent()
	sim.despensa._sync_waterskins()

	assert_eq(sim.store.amount(Materia.Kind.AGUA), 0.0,
		"si el odre se rompe, el agua que llevaba se pierde con él")


# ------------------------ el odre lleno no es odre vacío (depurar, 2026-09-13) --
#
# Queja del usuario: «cuando un odre de agua está lleno, no cuenta como odre
# vacío; creo que ahora cuenta en ambos». Contaba en dos sitios: el almacén
# enseñaba «Odre» con todos y «Agua» con los llenos, y la capacidad de guardar
# comida sumaba doce litros por CADA odre, también por los que llevan agua.

func _con_odres(hechos: int, llenos: float) -> SettlementSim:
	var sim := SettlementSim.new()
	for _i in range(hechos):
		sim.toolkit.craft(Tool.Kind.ODRE, Tool.Stuff.PIEL)
	sim.store.add(Materia.Kind.AGUA, llenos)
	return sim


func test_los_odres_vacios_son_los_hechos_menos_los_llenos() -> void:
	var sim := _con_odres(5, 3.0)
	assert_eq(sim.despensa.odres_vacios(), 2, "cinco hechos y tres llenos: dos vacíos")


func test_el_odre_que_va_fuera_no_esta_vacio_en_casa() -> void:
	var sim := _con_odres(5, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var fuera := Inhabitant.create(0, Vector3.ZERO, rng)
	fuera.has_waterskin = true
	sim.people = [fuera]
	assert_eq(sim.despensa.odres_vacios(), 1, "el que lleva alguien encima no se llena")


func test_el_odre_lleno_no_guarda_comida() -> void:
	var sim := _con_odres(5, 3.0)
	sim._ajustar_despensa()
	assert_near(sim.store.capacidad_comida,
		Storehouse.A_GRANEL + 2.0 * Storehouse.POR_ODRE, 0.001,
		"sólo los dos vacíos suman sitio para comida")


# ------------------- el corro del fuego y el filtro (depurar, 2026-09-13) --

func test_los_troncos_rodean_la_hoguera_sin_pisarla() -> void:
	# Los leños van FUERA del corro de piedras: dentro serían leña ardiendo.
	var centro := Vector3(100.0, 0.0, 100.0)
	var troncos := CorroDelHogar.troncos(centro)
	assert_eq(troncos.size(), CorroDelHogar.TRONCOS, "hay cinco leños")
	for tronco: Dictionary in troncos:
		var lejos := (tronco["pos"] as Vector3).distance_to(centro)
		assert_gt(lejos, Bonfire.RING_RADIUS, "%s no pisa las piedras" % str(lejos))
		assert_lt(lejos, 4.0, "pero se llega a la lumbre desde el asiento")


func test_cada_tronco_da_dos_asientos_y_se_acaban() -> void:
	var centro := Vector3.ZERO
	var asientos := CorroDelHogar.asientos(centro)
	assert_eq(asientos.size(), CorroDelHogar.TRONCOS * CorroDelHogar.POR_TRONCO,
		"dos por leño")
	assert_true(CorroDelHogar.asiento_de(centro, 0) != Vector3.ZERO, "el primero se sienta")
	assert_eq(CorroDelHogar.asiento_de(centro, asientos.size()), Vector3.ZERO,
		"y al que llega tarde no le queda sitio: se queda por la campa")


func test_el_filtro_reparte_los_parajes_en_familias() -> void:
	# La recolección se parte en dos —frutos y leña— porque son dos cuadrillas.
	var pesquera := Paraje.create(1, 1, Subsistence.Activity.PESCA,
		Materia.Kind.PESCADO, Vector3.ZERO, 1)
	var lenar := Paraje.create(2, 2, Subsistence.Activity.RECOLECCION,
		Materia.Kind.LENA, Vector3.ZERO, 1)
	var avellanar := Paraje.create(3, 3, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, Vector3.ZERO, 1)
	var cantera := Paraje.create(4, 4, Subsistence.Activity.MATERIA_PRIMA,
		Materia.Kind.PIEDRA, Vector3.ZERO, 1)
	assert_eq(FiltroDeMarcadores.familia_de(pesquera), FiltroDeMarcadores.Familia.PESCA,
		"la pesquera, con la pesca")
	assert_eq(FiltroDeMarcadores.familia_de(lenar), FiltroDeMarcadores.Familia.LENA,
		"el leñar, con la leña y la fibra")
	assert_eq(FiltroDeMarcadores.familia_de(avellanar), FiltroDeMarcadores.Familia.FRUTOS,
		"el avellanar, con los frutos y raíces")
	assert_eq(FiltroDeMarcadores.familia_de(cantera), FiltroDeMarcadores.Familia.CANTERA,
		"y la cantera, con la cantera")


## Queja del 2026-09-15: en una ladera el humo salía perpendicular a la hoguera. La
## hoguera se inclina con el suelo; su humo tiene que seguir mirando al cielo.
func test_en_una_ladera_el_humo_sube_hacia_arriba() -> void:
	# Una hoguera de vivac (escala 0,6) apoyada en una ladera: su «arriba» es la normal.
	var ladera := Basis(Quaternion(Vector3.UP, Vector3(0.5, 1.0, 0.2).normalized())) 		* Basis.from_scale(Vector3.ONE * 0.6)
	var humo := Bonfire.orientacion_del_humo(ladera)
	assert_lt(ladera.y.normalized().dot(Vector3.UP), 0.99, "la hoguera sí está inclinada")
	assert_gt(humo.y.normalized().dot(Vector3.UP), 0.999, "el humo mira al cielo, no a la normal del suelo")
	assert_near(humo.get_scale().x, 0.6, 0.001, "y conserva el tamaño de su hoguera")
