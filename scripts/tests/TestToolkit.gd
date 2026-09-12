class_name TestToolkit
extends TestCase
## Pruebas del utillaje y su desgaste.
##
## Lo que se prueba aquí es que las herramientas TENGAN CONSECUENCIA. Un
## contador de «tienes 8 herramientas» no cambia ninguna decisión. Que una
## raedera de cuarcita se rompa en la mitad de tiempo que una de sílex es lo
## que convierte un viaje de cuarenta kilómetros en algo que compensa.


func suite_name() -> String:
	return "Utillaje"


# --- la pieza --------------------------------------------------------------

func test_una_pieza_nueva_esta_entera() -> void:
	var tool := Tool.make(Tool.Kind.RAEDERA, Tool.Stuff.SILEX)
	assert_near(tool.condition(), 1.0, 0.001, "sin estrenar")
	assert_false(tool.is_spent(), "y sirve")


func test_el_silex_dura_mucho_mas_que_la_cuarcita() -> void:
	# Es la cifra de la que cuelga toda la economia de la materia prima: si
	# ambas duraran igual, nadie iria a buscar silex y la mitad del mapa
	# sobraria.
	var flint := Tool.make(Tool.Kind.RAEDERA, Tool.Stuff.SILEX)
	var quartz := Tool.make(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)
	assert_true(flint.durability() > quartz.durability() * 2.5,
		"el silex da mas del doble de filo util")


func test_el_uso_gasta_y_acaba_rompiendo() -> void:
	var tool := Tool.make(Tool.Kind.LASCA, Tool.Stuff.CUARCITA)
	tool.wear(tool.durability() * 0.5)
	assert_near(tool.condition(), 0.5, 0.01, "a medio gastar")
	assert_false(tool.is_spent(), "pero aun sirve")

	var broke := tool.wear(tool.durability() * 0.6)
	assert_true(broke, "el uso que la pasa la rompe")
	assert_true(tool.is_spent(), "y queda inservible")
	assert_eq(tool.condition(), 0.0, "sin nada de filo")


func test_la_pericia_del_artesano_alarga_la_pieza() -> void:
	# La pericia no hace que corte mas: hace que aguante mas. Una hoja bien
	# sacada tiene el filo regular y se reaviva; una chapucera salta.
	var novice := Tool.make(Tool.Kind.LASCA, Tool.Stuff.SILEX, 0.0)
	var master := Tool.make(Tool.Kind.LASCA, Tool.Stuff.SILEX, 1.0)
	assert_true(master.durability() > novice.durability(),
		"la del maestro aguanta mas")


# --- las recetas -----------------------------------------------------------

func test_la_azagaya_necesita_cuatro_materiales() -> void:
	# Y esa es la gracia: una azagaya no es «madera». Es asta, astil, ligadura
	# y resina, o sea que hace falta que cuatro oficios distintos hayan
	# traido lo suyo.
	var recipe := Tool.recipe(Tool.Kind.AZAGAYA)
	assert_eq(recipe.size(), 4, "cuatro materiales distintos")
	assert_true(recipe.has(Materia.Kind.ASTA), "la punta")
	assert_true(recipe.has(Materia.Kind.FIBRA), "la ligadura")


func test_el_asta_necesita_un_buril_que_hace_el_tallador() -> void:
	# La dependencia entre talleres. Sin tallador se paran dos oficios mas.
	assert_eq(Tool.needs_tool(Tool.Kind.AZAGAYA), Tool.Kind.BURIL,
		"para ranurar el asta hace falta buril")
	assert_eq(Tool.needs_tool(Tool.Kind.ODRE), Tool.Kind.RAEDERA,
		"y para el odre, raedera")
	assert_eq(Tool.needs_tool(Tool.Kind.LASCA), -1,
		"la talla no necesita nada previo: es el principio de la cadena")


func test_el_vestido_se_hace_de_piel_y_se_cose_con_aguja() -> void:
	# Es la pieza que faltaba para que "ropa cosida y ajustada" (la propia
	# ficha de Tech.AGUJA) sea algo que se fabrica y no solo una frase.
	var tool := Tool.make(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)
	assert_eq(tool.display_name(), "Vestido de piel", "nombre de la pieza")
	assert_eq(Tool.default_stuff(Tool.Kind.VESTIDO), Tool.Stuff.PIEL,
		"se hace de piel por defecto")
	assert_eq(Tool.needs_tool(Tool.Kind.VESTIDO), Tool.Kind.AGUJA,
		"no se cose sin aguja")
	assert_eq(Tool.tech_of(Tool.Kind.VESTIDO), TechTree.Tech.AGUJA,
		"la misma tecnica que desbloquea la aguja desbloquea el vestido")
	assert_true(Tool.recipe(Tool.Kind.VESTIDO).has(Materia.Kind.PIEL_CURTIDA),
		"la receta pide piel CURTIDA, no cruda -ver Taller._curar_piel-")


# --- el utillaje de la banda -----------------------------------------------

func test_se_apura_la_pieza_a_medias_antes_de_estrenar_otra() -> void:
	# Asi no acabas con todo el utillaje a medio gastar a la vez y sin nada
	# fresco en reserva, que es como te quedas tirado.
	var kit := Toolkit.new()
	var fresh := kit.craft(Tool.Kind.LASCA, Tool.Stuff.SILEX)
	var half := kit.craft(Tool.Kind.LASCA, Tool.Stuff.SILEX)
	half.wear(half.durability() * 0.5)

	assert_eq(kit.pick(Tool.Kind.LASCA), half, "se coge la mas gastada")
	assert_near(fresh.condition(), 1.0, 0.001, "y la nueva sigue sin tocar")


func test_usar_gasta_la_pieza_y_la_rotura_queda_anotada() -> void:
	var kit := Toolkit.new()
	var tool := kit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)

	assert_true(kit.use(Tool.Kind.RAEDERA, tool.durability() + 1.0),
		"habia una raedera que usar")
	assert_eq(kit.count(Tool.Kind.RAEDERA), 0, "y se ha roto")
	assert_eq(kit.broken_today.size(), 1, "queda anotado para la cronica")


func test_el_vestido_se_gasta_por_dia_y_no_por_tarea() -> void:
	# A diferencia del resto del utillaje, una prenda se lleva puesta todo el
	# rato: TODAS las piezas envejecen cada jornada, no solo la que "se usa".
	var kit := Toolkit.new()
	var a := kit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)
	var b := kit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)
	kit.wear_all(Tool.Kind.VESTIDO, 5.0)
	assert_near(a.used, 5.0, 0.001, "la primera prenda envejece")
	assert_near(b.used, 5.0, 0.001, "y la segunda tambien, no solo la peor")

	var days := 0
	while kit.count(Tool.Kind.VESTIDO) > 0 and days < 500:
		kit.wear_all(Tool.Kind.VESTIDO, SettlementSim.VESTIDO_WEAR_PER_DAY)
		kit.discard_spent()
		days += 1
	assert_true(days > 0 and days < 500,
		"sin reponer, el vestido acaba gastandose del todo")


func test_sin_piezas_no_se_puede_usar() -> void:
	var kit := Toolkit.new()
	assert_false(kit.use(Tool.Kind.BURIL), "no hay buriles")
	assert_eq(kit.pick(Tool.Kind.BURIL), null, "ni ninguno que coger")


# --- el rendimiento --------------------------------------------------------

func test_sin_herramienta_se_rinde_poco_pero_no_cero() -> void:
	# Sin azagaya se sigue comiendo: hay trampa, hay carrona y hay caza menor.
	# Poner cero aqui seria matar a la banda por un detalle de utillaje.
	var kit := Toolkit.new()
	assert_near(kit.efficiency(Tool.Kind.AZAGAYA, 3), 0.35, 0.001,
		"se caza mal, no se deja de cazar")
	assert_near(kit.efficiency(Tool.Kind.CESTO, 3), 0.55, 0.001,
		"y a brazadas se recolecta la mitad")


func test_el_asta_sin_buril_si_es_cero() -> void:
	# Es la unica excepcion, y esta bien que lo sea: ranurar un asta sin buril
	# no es lento, es que no se hace.
	var kit := Toolkit.new()
	assert_eq(kit.efficiency(Tool.Kind.BURIL, 1), 0.0,
		"sin buril el astero no trabaja")


func test_el_utillaje_completo_rinde_al_maximo() -> void:
	var kit := Toolkit.new()
	for i in range(3):
		kit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA)
	assert_near(kit.efficiency(Tool.Kind.AZAGAYA, 3), 1.0, 0.001,
		"una azagaya por cazador")


func test_el_utillaje_a_medias_rinde_a_medias() -> void:
	var kit := Toolkit.new()
	kit.craft(Tool.Kind.CESTO, Tool.Stuff.FIBRA)
	kit.craft(Tool.Kind.CESTO, Tool.Stuff.FIBRA)
	# Dos cestos para cuatro recolectores: cobertura 0,5
	var value := kit.efficiency(Tool.Kind.CESTO, 4)
	assert_near(value, 0.55 + 0.45 * 0.5, 0.001, "a medio camino del maximo")


func test_tener_de_sobra_no_da_mas_de_lo_maximo() -> void:
	# Sin esto, acumular herramientas seria una forma barata de multiplicar la
	# produccion sin limite, y el juego se romperia por ahi.
	var kit := Toolkit.new()
	for i in range(20):
		kit.craft(Tool.Kind.LASCA, Tool.Stuff.SILEX)
	assert_near(kit.efficiency(Tool.Kind.LASCA, 3), 1.0, 0.001,
		"veinte lascas para tres no rinden mas que tres")


# --- el ciclo de vida ------------------------------------------------------

func test_el_desgaste_hunde_el_rendimiento_con_el_tiempo() -> void:
	# La prueba que justifica todo el sistema: una banda que no repone se
	# queda sin filo sola, sin que nadie tenga que castigarla.
	var kit := Toolkit.new()
	for i in range(3):
		kit.craft(Tool.Kind.LASCA, Tool.Stuff.CUARCITA)
	var start := kit.efficiency(Tool.Kind.LASCA, 3)

	# Treinta jornadas de despiece sin reponer nada
	for day in range(30):
		for person in range(3):
			kit.use(Tool.Kind.LASCA, 2.0)
		kit.discard_spent()

	var finish := kit.efficiency(Tool.Kind.LASCA, 3)
	assert_near(start, 1.0, 0.001, "se empieza con el utillaje completo")
	assert_true(finish < start, "y se acaba peor de lo que se empezo")


func test_la_cuarcita_obliga_a_reponer_antes_que_el_silex() -> void:
	# El mismo trabajo con dos materias primas. La diferencia en jornadas es
	# la que el jugador tiene que notar al elegir donde va a buscar piedra.
	var days_quartz := _days_until_broken(Tool.Stuff.CUARCITA)
	var days_flint := _days_until_broken(Tool.Stuff.SILEX)
	assert_true(days_flint > days_quartz * 2.0,
		"el silex aguanta mas del doble de jornadas")


func _days_until_broken(stuff: Tool.Stuff) -> int:
	var kit := Toolkit.new()
	kit.craft(Tool.Kind.LASCA, stuff)
	var days := 0
	while kit.count(Tool.Kind.LASCA) > 0 and days < 500:
		kit.use(Tool.Kind.LASCA, 2.0)
		days += 1
	return days


func test_las_piezas_rotas_se_retiran_al_cerrar_la_jornada() -> void:
	var kit := Toolkit.new()
	var tool := kit.craft(Tool.Kind.LASCA, Tool.Stuff.CUARCITA)
	tool.wear(tool.durability())

	assert_eq(kit.pieces.size(), 1, "la rota sigue en la lista durante el dia")
	assert_eq(kit.discard_spent(), 1, "y se retira una al cerrar")
	assert_eq(kit.pieces.size(), 0, "el taller queda limpio")


func test_el_resumen_pone_delante_lo_que_esta_a_punto_de_faltar() -> void:
	# El orden es la informacion: lo primero que se lee tiene que ser el
	# problema, no el inventario.
	var kit := Toolkit.new()
	for i in range(5):
		kit.craft(Tool.Kind.LASCA, Tool.Stuff.SILEX)
	kit.craft(Tool.Kind.BURIL, Tool.Stuff.SILEX)

	var rows := kit.summary()
	assert_eq(rows.size(), 2, "dos tipos en el taller")
	assert_eq(int(rows[0]["kind"]), Tool.Kind.BURIL, "el escaso, primero")


func test_la_durabilidad_por_tipo_usa_su_materia_habitual() -> void:
	# Sirve para estimar cuantas piezas se rompen al mes, que es la mitad de
	# la columna «gasta» del almacen
	assert_near(Tool.durability_of(Tool.Kind.LASCA),
		Tool.DURABILITY[Tool.Stuff.CUARCITA], 0.01,
		"la lasca es de cuarcita por defecto")
	assert_near(Tool.durability_of(Tool.Kind.AZAGAYA),
		Tool.DURABILITY[Tool.Stuff.ASTA], 0.01,
		"y la azagaya de asta")


# --- lo que se está fabricando, para que se pueda ENSEÑAR ----------------
#
# `craft_progress` llevaba desde siempre en `Inhabitant` y no lo leía nadie
# fuera de `SettlementSim`: en pantalla no había forma de saber qué estaba
# tallando alguien ni cuánto le faltaba. Ver [CraftMarkers].

func _artesano(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.age_years = 30
	person.age_group = Inhabitant.Age.ADULTO
	person.nursing = false
	Profession.assign(Profession.Job.MANUFACTURA, person, Profession.Speciality.TALLA)
	sim.people = [person]
	# Sin materia prima en el abrigo `_next_piece` no elige nada: el artesano
	# no se planta delante de una pieza que no puede pagar.
	sim.store.add(Materia.Kind.PIEDRA, 40.0)
	sim.store.add(Materia.Kind.LENA, 20.0)
	sim.store.add(Materia.Kind.FIBRA, 20.0)
	sim.store.add(Materia.Kind.ASTA, 10.0)
	sim.store.add(Materia.Kind.HUESO, 10.0)
	sim.store.add(Materia.Kind.PIEL, 10.0)
	sim.store.add(Materia.Kind.RESINA, 10.0)
	sim.store.add(Materia.Kind.TENDON, 10.0)
	return person


func test_el_artesano_no_pasa_por_trabajando() -> void:
	# La trampa que dejaba la chapa apagada siempre: el taller NO sale del
	# abrigo, asi que quien talla se queda en OCIOSO y `_craft` se llama desde
	# ahi. Mirar `TRABAJANDO` para saber si alguien fabrica no vale.
	var sim := SettlementSim.new()
	var person := _artesano(sim)
	sim.hour = 10.0
	person.state = Inhabitant.State.OCIOSO
	person.craft_progress = 0.4

	var work := sim.taller.crafting_now(person)
	assert_false(work.is_empty(), "en OCIOSO tambien se esta tallando")
	assert_eq(work["progress"], 0.4, "y se sabe cuanto lleva")


func test_la_peleteria_fabrica_vestido_con_aguja_y_piel() -> void:
	# La especialidad ya decia "ropa, odres, cobijo" y solo hacia odres. Con
	# aguja en el taller y piel en el almacen, tiene que empezar a coser.
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.age_years = 30
	person.age_group = Inhabitant.Age.ADULTO
	person.nursing = false
	Profession.assign(Profession.Job.MANUFACTURA, person,
		Profession.Speciality.PELETERIA)
	sim.people = [person]
	# Piel CRUDA, no curtida: hace falta que la peleteria la curta primero
	# -raedera, ocre y grasa, ver `Taller._curar_piel`- antes de poder coser
	# nada. Con eso de sobra, la cadena entera tiene que completarse sola.
	sim.store.add(Materia.Kind.PIEL, 40.0)
	sim.store.add(Materia.Kind.OCRE, 40.0)
	sim.store.add(Materia.Kind.GRASA, 40.0)
	# `sim.techs` es null sin `setup()`: `Taller.knows_tool` ya trata eso como
	# "se sabe hacer todo" (comentario de `knows_tool`), asi que no hace falta
	# construir un arbol de tecnicas solo para esta prueba.
	sim.toolkit.craft(Tool.Kind.AGUJA, Tool.Stuff.HUESO)
	sim.toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)

	var hecho := false
	for day in range(30):
		sim.taller._craft(person, SettlementSim.HORAS_UTILES)
		if sim.toolkit.count(Tool.Kind.VESTIDO) > 0:
			hecho = true
			break
	assert_true(hecho,
		"con raedera, aguja, piel, ocre y grasa, la peleteria acaba curtiendo "
			+ "y cosiendo un vestido")


# --- curtir la piel: cruda no sirve para nada -----------------------------

func _peletero(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.age_years = 30
	person.age_group = Inhabitant.Age.ADULTO
	person.nursing = false
	Profession.assign(Profession.Job.MANUFACTURA, person,
		Profession.Speciality.PELETERIA)
	sim.people = [person]
	return person


func test_sin_raedera_no_se_curte_nada() -> void:
	var sim := SettlementSim.new()
	var person := _peletero(sim)
	sim.store.add(Materia.Kind.PIEL, 10.0)
	sim.store.add(Materia.Kind.OCRE, 10.0)
	sim.store.add(Materia.Kind.GRASA, 10.0)

	assert_false(sim.taller._curar_piel(person, SettlementSim.HORAS_UTILES),
		"sin raedera no hay con que descarnar")
	assert_eq(sim.store.amount(Materia.Kind.PIEL_CURTIDA), 0.0,
		"y no sale nada curtido")


func test_con_raedera_ocre_y_grasa_se_curte_gastando_los_tres() -> void:
	var sim := SettlementSim.new()
	var person := _peletero(sim)
	sim.toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)
	sim.store.add(Materia.Kind.PIEL, 10.0)
	sim.store.add(Materia.Kind.OCRE, 10.0)
	sim.store.add(Materia.Kind.GRASA, 10.0)

	assert_true(sim.taller._curar_piel(person, SettlementSim.HORAS_UTILES),
		"con raedera, ocre y grasa, cura")
	assert_gt(sim.store.amount(Materia.Kind.PIEL_CURTIDA), 0.0,
		"sale piel curtida")
	assert_lt(sim.store.amount(Materia.Kind.PIEL), 10.0, "se gasta piel cruda")
	assert_lt(sim.store.amount(Materia.Kind.OCRE), 10.0, "se gasta ocre")
	assert_lt(sim.store.amount(Materia.Kind.GRASA), 10.0, "se gasta grasa")


func test_sin_ocre_ni_grasa_no_cura_aunque_haya_piel_y_raedera() -> void:
	var sim := SettlementSim.new()
	var person := _peletero(sim)
	sim.toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)
	sim.store.add(Materia.Kind.PIEL, 10.0)

	assert_true(sim.taller._curar_piel(person, SettlementSim.HORAS_UTILES),
		"la jornada de peleteria se gasta en el intento, no en otra cosa")
	assert_eq(sim.store.amount(Materia.Kind.PIEL_CURTIDA), 0.0,
		"pero sin ocre ni grasa no sale nada curtido")
	assert_eq(sim.store.amount(Materia.Kind.PIEL), 10.0,
		"y la piel cruda se queda donde estaba")


func test_deja_de_curtir_al_llegar_a_la_reserva() -> void:
	# Sin este tope, un peletero con piel de sobra curtiria sin parar y nunca
	# coseria un odre ni un vestido.
	var sim := SettlementSim.new()
	var person := _peletero(sim)
	sim.toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)
	sim.store.add(Materia.Kind.PIEL, 100.0)
	sim.store.add(Materia.Kind.OCRE, 100.0)
	sim.store.add(Materia.Kind.GRASA, 100.0)

	for i in range(30):
		sim.taller._curar_piel(person, SettlementSim.HORAS_UTILES)

	assert_true(sim.store.amount(Materia.Kind.PIEL_CURTIDA) <= Taller.CURTIDO_RESERVA + 0.01,
		"no acumula curtida sin limite: hay que dejar sitio para coser")
	assert_false(sim.taller._curar_piel(person, SettlementSim.HORAS_UTILES),
		"con la reserva llena, deja de curtir")


func test_solo_curte_quien_es_peletero() -> void:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	Profession.assign(Profession.Job.MANUFACTURA, person, Profession.Speciality.TALLA)
	sim.people = [person]
	sim.toolkit.craft(Tool.Kind.RAEDERA, Tool.Stuff.CUARCITA)
	sim.store.add(Materia.Kind.PIEL, 10.0)
	sim.store.add(Materia.Kind.OCRE, 10.0)
	sim.store.add(Materia.Kind.GRASA, 10.0)

	assert_false(sim.taller._curar_piel(person, SettlementSim.HORAS_UTILES),
		"un tallador no cura piel: eso es de peleteria")


func test_de_noche_no_se_talla() -> void:
	var sim := SettlementSim.new()
	var person := _artesano(sim)
	person.state = Inhabitant.State.DURMIENDO
	sim.hour = 3.0
	assert_true(sim.taller.crafting_now(person).is_empty(),
		"a las tres de la manana no hay nadie en el taller")


func test_quien_no_es_del_taller_no_fabrica() -> void:
	var sim := SettlementSim.new()
	var person := _artesano(sim)
	sim.hour = 10.0
	Profession.assign(Profession.Job.CAZA, person)
	assert_true(sim.taller.crafting_now(person).is_empty(),
		"un cazador no lleva chapa de taller")


# --- el arbol de tecnicas, como arbol ------------------------------------

func test_todas_las_tecnicas_estan_en_una_rama() -> void:
	# Una tecnica fuera de las ramas no se ve en ninguna ventana: existe en el
	# catalogo y no en la pantalla, que es la peor clase de contenido.
	var seen: Dictionary = {}
	for branch: int in TechTree.BRANCHES:
		for tech: int in (TechTree.BRANCHES[branch] as Array):
			assert_false(seen.has(tech),
				"%s sale en dos ramas" % TechTree.tech_name(tech as TechTree.Tech))
			seen[tech] = true
	for tech: int in TechTree.CATALOGUE.keys():
		assert_true(seen.has(tech),
			"%s no esta en ninguna rama" % TechTree.tech_name(tech as TechTree.Tech))


func test_la_profundidad_sale_de_los_prerrequisitos() -> void:
	assert_eq(TechTree.depth_of(TechTree.Tech.LASCA), 0, "la lasca es la raiz")
	assert_eq(TechTree.depth_of(TechTree.Tech.NUCLEO), 1, "el nucleo cuelga de ella")
	assert_eq(TechTree.depth_of(TechTree.Tech.HOJA), 2, "y la hoja del nucleo")
	assert_gt(float(TechTree.depth_of(TechTree.Tech.ARPON)), 2.0,
		"el arpon es de lo mas hondo del arbol")

# --- aprender cuesta material, no solo tiempo ----------------------------
#
# «No sirven de nada cuarenta y cinco jornadas si no se tiene nada con lo que
# trabajar». El tiempo pasa solo; el material hay que traerlo, y esa es toda
# la diferencia entre un arbol de progreso y un reloj.

func test_sin_material_las_jornadas_no_bastan() -> void:
	var tree := TechTree.new()
	tree.larder = Storehouse.new()
	var cost := TechTree.learning_cost(TechTree.Tech.NUCLEO)
	assert_false(cost.is_empty(), "el nucleo preparado cuesta piedra")
	var gained := tree.add_practice(Profession.Job.MANUFACTURA, 999.0)
	assert_false(tree.has(TechTree.Tech.NUCLEO),
		"con el abrigo vacio no se aprende por muchas jornadas que se echen")
	assert_eq(gained.size(), 0, "y no se anuncia nada")


func test_con_material_se_aprende_y_se_paga() -> void:
	var tree := TechTree.new()
	tree.larder = Storehouse.new()
	tree.larder.add(Materia.Kind.PIEDRA, 100.0)
	var before := tree.larder.amount(Materia.Kind.PIEDRA)
	tree.add_practice(Profession.Job.MANUFACTURA, 999.0)
	assert_true(tree.has(TechTree.Tech.NUCLEO), "con piedra si se aprende")
	assert_lt(tree.larder.amount(Materia.Kind.PIEDRA), before,
		"y la piedra se gasta aprendiendo")


func test_lo_que_falta_se_puede_decir() -> void:
	# La ventana tiene que poder escribir «falta 12 cuarcita», no «falta algo».
	var tree := TechTree.new()
	tree.larder = Storehouse.new()
	var short := tree.missing_for(TechTree.Tech.NUCLEO)
	assert_false(short.is_empty(), "con el abrigo vacio falta algo, y se dice")


func test_sin_despensa_el_arbol_se_comporta_como_antes() -> void:
	# Las pruebas viejas y las partidas guardadas montan arboles sueltos, sin
	# almacen: alli aprender no puede costar material o nada funcionaria.
	var tree := TechTree.new()
	tree.add_practice(Profession.Job.MANUFACTURA, 999.0)
	assert_true(tree.has(TechTree.Tech.NUCLEO),
		"sin despensa que consultar, las jornadas bastan")


func test_cada_rama_del_arbol_es_un_oficio_de_verdad() -> void:
	# La ventana pinta una pestaña por rama y le pone el nombre del oficio: una
	# rama que no fuera un oficio saldria sin nombre.
	for job: int in TechTree.BRANCHES:
		assert_true(Profession.CATALOGUE.has(job),
			"la rama %d es un oficio del catalogo" % job)
		assert_false((TechTree.BRANCHES[job] as Array).is_empty(),
			"%s tiene tecnicas" % Profession.job_name(job as Profession.Job))


func test_todas_las_tecnicas_tienen_cara_con_la_que_dibujarse() -> void:
	# El arbol dibuja un icono por tecnica. Sin entrada en la tabla se dibuja
	# un canto gris y todas parecen la misma.
	for tech: int in TechTree.CATALOGUE.keys():
		assert_true(TechTree.TECH_FACE.has(tech),
			"%s tiene con que dibujarse" % TechTree.tech_name(
				tech as TechTree.Tech))


# ------------- las tecnicas: jornadas Y material, a la vez ---------------

## El material se gasta A PLAZOS y frena el progreso cuando falta.
##
## Queja literal: «por un lado pasan las jornadas, y despues consume los
## materiales. No deberia ser asi... si pide 100 jornadas y 10 de calcita,
## quiero que permita subir 10 jornadas por cada 1 de calcita». Y el reparto es
## proporcional: si son veinte unidades, cada una abre un 5 %.
func test_el_material_abre_su_parte_de_las_jornadas() -> void:
	var tree := TechTree.new()
	var despensa := Storehouse.new()
	tree.larder = despensa

	# La hoja pide 110 jornadas de manufactura y 18 de piedra. Con nueve
	# piedras -la mitad- solo se puede llegar a la mitad del camino.
	var pide := TechTree.learning_cost(TechTree.Tech.HOJA)
	var piedra := float(pide[Materia.Kind.PIEDRA])
	despensa.add(Materia.Kind.PIEDRA, piedra * 0.5)
	tree.known[TechTree.Tech.LASCA] = true
	tree.known[TechTree.Tech.NUCLEO] = true

	tree.add_practice(Profession.Job.MANUFACTURA, 9999.0)
	assert_near(tree.progress(TechTree.Tech.HOJA), 0.5, 0.02,
		"con la mitad del material, la mitad del camino, por muchas jornadas "
			+ "que se echen")
	assert_false(tree.has(TechTree.Tech.HOJA),
		"y no se aprende: faltan piedras")
	assert_near(despensa.amount(Materia.Kind.PIEDRA), 0.0, 0.01,
		"y la piedra que habia SI se ha gastado, mientras se practicaba")

	# Traen el resto y la tecnica se remata sin practicar mas.
	despensa.add(Materia.Kind.PIEDRA, piedra * 0.5)
	tree.add_practice(Profession.Job.MANUFACTURA, 0.0)
	assert_true(tree.has(TechTree.Tech.HOJA),
		"con el material puesto, la tecnica sale")


## Las jornadas cuentan por OFICIO, y el oficio es el de su rama.
##
## «Hay tecnicas de ribera y de exploracion que parece que no suben». No lo
## parecia: no subian. La actividad que hacia avanzar cada tecnica se escribia a
## mano y no coincidia con la pestaña —la pasarela, rama de exploracion,
## avanzaba con MATERIA_PRIMA; la piragua, tambien de exploracion, con PESCA—,
## asi que poner gente a explorar no las movia ni un dia.
func test_cada_tecnica_la_practica_el_oficio_de_su_rama() -> void:
	for job: int in TechTree.BRANCHES:
		for tech: int in (TechTree.BRANCHES[job] as Array):
			assert_eq(TechTree.job_of(tech as TechTree.Tech), job,
				"%s se practica en su propia rama"
					% TechTree.tech_name(tech as TechTree.Tech))


## Y trabajar de explorador mueve las tecnicas de exploracion.
func test_explorar_hace_subir_las_tecnicas_de_exploracion() -> void:
	var tree := TechTree.new()
	tree.known[TechTree.Tech.LASCA] = true
	tree.known[TechTree.Tech.NUCLEO] = true
	var antes := tree.progress(TechTree.Tech.PASARELA)
	tree.add_practice(Profession.Job.EXPLORACION, 20.0)
	assert_gt(tree.progress(TechTree.Tech.PASARELA), antes,
		"veinte jornadas de exploracion mueven la pasarela")
	# Y trabajar de OTRA cosa no la mueve.
	var ahora := tree.progress(TechTree.Tech.PASARELA)
	tree.add_practice(Profession.Job.CAZA, 200.0)
	assert_eq(tree.progress(TechTree.Tech.PASARELA), ahora,
		"y doscientas de caza no la mueven nada")


## Con que llega la banda al abrigo, y por que no puede llevar lo que no sabe
## hacer.
func test_el_utillaje_inicial_no_contradice_el_arbol() -> void:
	# Llegaban con dos azagayas de asta y `Tool.tech_of` exige `Tech.AZAGAYA`
	# para hacer una: la banda tenia puesto lo que no sabria reponer, y en
	# cuanto se gastaran no habria forma de volver a tenerlas. Lo midio
	# ESTADO.md §2 -«acabaron con dos azagayas de un utillaje que ni siquiera
	# sabian diseñar»- y se quedo sin arreglar.
	for entry: Dictionary in SettlementSim.UTILLAJE_INICIAL:
		var kind := int(entry["kind"]) as Tool.Kind
		assert_eq(Tool.tech_of(kind), -1,
			"%s se lleva de partida, asi que no puede pedir tecnica"
				% Tool.kind_name(kind))


func test_la_lanza_de_mano_es_lo_que_hay_antes_de_la_azagaya() -> void:
	# La punta litica enmangada no pide tecnica ni otra herramienta para
	# hacerse, y `Fauna` ya deja cobrar corzo y rebeco con ella. Es lo que
	# sostiene la caza menor hasta que llegue la azagaya de asta.
	assert_eq(Tool.tech_of(Tool.Kind.PUNTA), -1, "la punta no pide tecnica")
	assert_eq(Tool.needs_tool(Tool.Kind.PUNTA), -1, "ni otra herramienta")
	assert_true((Fauna.armas_of("corzo") as Array).has(Tool.Kind.PUNTA),
		"y con ella se cobra un corzo")
	assert_eq(int(SettlementSim.SPECIALITY_TOOL[Profession.Speciality.CAZA_MENOR]),
		int(Tool.Kind.PUNTA),
		"asi que la caza menor pide punta, no azagaya: pedir azagaya cerraba "
		+ "el bucle -sin tendon no hay azagaya y sin caza menor no hay tendon")


## El panel tiene que decir POR QUE no avanza una tecnica, y las tres causas
## se ven iguales desde fuera. Ver `TechTree.Freno` y docs/INTERFAZ.md §4.
func test_el_arbol_dice_cual_de_las_tres_puertas_esta_cerrada() -> void:
	var tree := TechTree.new()
	var almacen := Storehouse.new()
	tree.larder = almacen

	# Sin la previa: prerrequisito, y se dice CUAL.
	assert_eq(tree.freno(TechTree.Tech.AZAGAYA), TechTree.Freno.PRERREQUISITO,
		"la azagaya cuelga de la talla laminar")
	assert_true(tree.causa(TechTree.Tech.AZAGAYA).contains("laminar"),
		"y la casilla manda a la que falta, no dice «falta lo de antes»")

	# Con la previa y sin jornadas: jornadas, y se dice CUANTAS faltan.
	assert_eq(tree.freno(TechTree.Tech.NUCLEO), TechTree.Freno.JORNADAS,
		"el nucleo esta al alcance y solo le faltan jornadas")
	var dice := tree.causa(TechTree.Tech.NUCLEO)
	assert_true(dice.contains("45") and dice.contains("manufactura"),
		"y dice cuantas y de que oficio, que es lo que decide a quien mover: "
		+ dice)

	# Con jornadas y sin material: PARADA. Es la que nadie adivinaba, porque
	# `_ir_pagando` detiene el progreso y la casilla solo enseñaba un tanto
	# por ciento que no se movia.
	tree.add_practice(Profession.Job.MANUFACTURA, 45.0)
	assert_eq(tree.freno(TechTree.Tech.NUCLEO), TechTree.Freno.MATERIAL,
		"con las jornadas hechas y la despensa vacia, para")
	assert_true(tree.causa(TechTree.Tech.NUCLEO).begins_with("parada"),
		"y lo dice con esa palabra")
	assert_lt(tree.progress(TechTree.Tech.NUCLEO), 1.0,
		"el progreso no llega a uno sin material, que es de donde salia la queja")

	# Y con la despensa llena y el cobro atrasado, NO es «parada»: es un tick
	# de retraso que se cobra solo en cuanto alguien practique. Marcarlo en
	# rojo era decirle al jugador que fuera a por piedra teniendola en casa.
	almacen.add(Materia.Kind.PIEDRA, 40.0)
	assert_eq(tree.freno(TechTree.Tech.NUCLEO), TechTree.Freno.JORNADAS,
		"con material en el abrigo no esta parada aunque no se haya cobrado")
	assert_true(tree.causa(TechTree.Tech.NUCLEO).is_empty()
		or not tree.causa(TechTree.Tech.NUCLEO).begins_with("parada"),
		"y no lo dice")

	# Y con material, se aprende.
	tree.add_practice(Profession.Job.MANUFACTURA, 1.0)
	assert_true(tree.has(TechTree.Tech.NUCLEO),
		"con nodulos que estropear, se aprende")
	assert_eq(tree.freno(TechTree.Tech.NUCLEO), TechTree.Freno.NINGUNO,
		"y ya no la frena nada")
