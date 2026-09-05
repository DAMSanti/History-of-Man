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
