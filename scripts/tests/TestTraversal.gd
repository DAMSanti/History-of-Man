class_name TestTraversal
extends TestCase
## Pruebas de por dónde se puede pasar y a qué velocidad.
##
## La base no es inventada: es la FUNCIÓN DE MARCHA DE TOBLER, ajustada sobre
## datos reales de excursionistas y sobre las tablas de marcha alpina de Imhof.
## Dice que la velocidad a pie es
##
##     v = 6 · e^(−3,5 · |pendiente + 0,05|)  km/h
##
## y de ahí salen tres cosas que no son obvias y que ninguna fórmula inventada
## daría bien:
##
##  · El máximo NO está en el llano, está en una bajada suave del 5%. Cuesta
##    abajo poco se aprovecha la gravedad sin tener que frenar.
##  · Cuesta abajo fuerte se va MÁS LENTO que en llano, porque hay que frenar
##    en cada paso y el terreno se vuelve traicionero.
##  · La caída con la pendiente es exponencial, no lineal: subir al 30% no
##    cuesta el triple que al 10%, cuesta mucho más.
##
## Sobre eso se monta lo demás: carga, tipo de suelo y qué es infranqueable.


func suite_name() -> String:
	return "Movilidad"


# --- la curva de Tobler ---------------------------------------------------

func test_el_maximo_esta_en_una_bajada_suave_no_en_el_llano() -> void:
	var llano := Traversal.hiking_speed(0.0)
	var bajada_suave := Traversal.hiking_speed(-0.05)
	assert_gt(bajada_suave, llano,
		"se anda mas rapido cuesta abajo suave que en llano")


func test_en_llano_se_andan_unos_cinco_kilometros_por_hora() -> void:
	assert_near(Traversal.hiking_speed(0.0), 5.04, 0.15,
		"la marcha en llano es la de un adulto andando de verdad")


func test_bajar_fuerte_es_mas_lento_que_el_llano() -> void:
	# Contraintuitivo pero medido: hay que frenar en cada paso
	assert_lt(Traversal.hiking_speed(-0.45), Traversal.hiking_speed(0.0),
		"bajar una ladera fuerte cuesta mas que llanear")


func test_subir_penaliza_mucho_mas_que_bajar_lo_mismo() -> void:
	assert_lt(Traversal.hiking_speed(0.30), Traversal.hiking_speed(-0.30),
		"a igual pendiente, subir cuesta mas que bajar")


func test_la_penalizacion_de_subir_no_es_lineal() -> void:
	var suave := Traversal.hiking_speed(0.0) / Traversal.hiking_speed(0.10)
	var fuerte := Traversal.hiking_speed(0.20) / Traversal.hiking_speed(0.30)
	assert_gt(fuerte, suave * 0.9,
		"cada escalon de pendiente cuesta al menos tanto como el anterior")
	assert_lt(Traversal.hiking_speed(0.60), Traversal.hiking_speed(0.20) * 0.35,
		"una ladera muy fuerte hunde la marcha, no la reduce un poco")


func test_la_velocidad_nunca_es_cero_ni_negativa() -> void:
	# Si llegara a cero, quien la use se quedaria clavado para siempre
	for slope: float in [-2.0, -1.0, 0.0, 1.0, 2.0, 5.0]:
		assert_gt(Traversal.hiking_speed(slope), 0.0,
			"la marcha sigue siendo positiva a pendiente %.1f" % slope)


# --- la carga --------------------------------------------------------------

func test_ir_cargado_es_mas_lento_que_ir_de_vacio() -> void:
	assert_lt(Traversal.load_factor(0.5), Traversal.load_factor(0.0),
		"con media carga se anda mas despacio")


func test_de_vacio_no_hay_penalizacion() -> void:
	assert_near(Traversal.load_factor(0.0), 1.0, 0.001,
		"sin carga se anda al ritmo propio")


func test_la_carga_penaliza_de_forma_creciente() -> void:
	var previo := 1.0
	for load: float in [0.25, 0.5, 0.75, 1.0]:
		var ahora := Traversal.load_factor(load)
		assert_lt(ahora, previo, "mas carga, menos ritmo (a %.2f)" % load)
		previo = ahora
	assert_gt(previo, 0.35, "ni siquiera a plena carga se queda clavado")


# --- el suelo que se pisa --------------------------------------------------

func test_el_pasto_es_el_terreno_de_referencia() -> void:
	assert_near(Traversal.ground_factor(Traversal.Ground.PASTO), 1.0, 0.001,
		"el pasto es la referencia")


func test_la_marisma_es_lo_mas_lento() -> void:
	for ground: int in [Traversal.Ground.PASTO, Traversal.Ground.ROCA,
			Traversal.Ground.CANCHAL, Traversal.Ground.ARENA]:
		assert_gt(Traversal.ground_factor(ground as Traversal.Ground),
			Traversal.ground_factor(Traversal.Ground.MARISMA),
			"nada cuesta tanto como el barro")


func test_la_roca_firme_se_anda_mejor_que_el_canchal() -> void:
	# La caliza desnuda es incomoda pero firme; el canchal se mueve bajo el pie
	assert_gt(Traversal.ground_factor(Traversal.Ground.ROCA),
		Traversal.ground_factor(Traversal.Ground.CANCHAL),
		"la roca firme se pisa mejor que la piedra suelta")


func test_ningun_suelo_para_del_todo() -> void:
	for ground in range(5):
		assert_gt(Traversal.ground_factor(ground as Traversal.Ground), 0.0,
			"ningun suelo deja la marcha a cero")


# --- lo que se combina -----------------------------------------------------

func test_la_velocidad_final_junta_pendiente_suelo_y_carga() -> void:
	var comodo := Traversal.travel_speed(0.0, Traversal.Ground.PASTO, 0.0)
	var duro := Traversal.travel_speed(0.35, Traversal.Ground.MARISMA, 0.9)
	assert_gt(comodo, duro * 3.0,
		"llanear de vacio por pasto es muchisimo mas rapido que subir cargado por barro")
	assert_gt(duro, 0.0, "pero incluso lo peor sigue avanzando")


# --- por donde NO se puede pasar ------------------------------------------

func test_una_ladera_normal_se_pasa() -> void:
	assert_true(Traversal.is_passable(0.35, 0.0, false, false),
		"una ladera del 35% se sube andando")


func test_un_cortado_no_se_pasa() -> void:
	# Por encima del limite ya no es andar, es trepar, y con carga no se trepa
	assert_false(Traversal.is_passable(1.6, 0.0, false, false),
		"un cortado no se sube andando")


func test_el_limite_de_pendiente_es_el_de_trepar_no_el_de_cansarse() -> void:
	# Que algo sea agotador no lo hace intransitable: son cosas distintas y
	# confundirlas dejaria a la banda encerrada en el fondo del valle
	assert_true(Traversal.is_passable(0.8, 0.0, false, false),
		"una ladera muy fuerte se sube, aunque cueste")
	assert_lt(Traversal.travel_speed(0.8, Traversal.Ground.PASTO, 0.0),
		Traversal.travel_speed(0.1, Traversal.Ground.PASTO, 0.0) * 0.25,
		"pero se sube muy despacio")


func test_el_rio_sigue_mandando_sobre_la_pendiente() -> void:
	# 0,9 es un rio ancho. El 1,0 exacto esta reservado a la mar abierta, que
	# no la cruza nada de lo que hay en esta epoca, asi que usarlo aqui seria
	# probar otra cosa.
	assert_false(Traversal.is_passable(0.0, 0.9, false, false),
		"el llano no sirve de nada si lo que hay es agua honda")
	assert_true(Traversal.is_passable(0.0, 0.9, true, false),
		"con embarcacion si")
	assert_false(Traversal.is_passable(0.0, 1.0, true, false),
		"pero la mar abierta no la cruza una piragua")


func test_el_agua_somera_frena_pero_deja_pasar() -> void:
	var seco := Traversal.travel_speed(0.0, Traversal.Ground.PASTO, 0.0)
	var vadeando := Traversal.travel_speed(0.0, Traversal.Ground.MARISMA, 0.0)
	assert_true(Traversal.is_passable(0.0, 0.2, false, false), "un vado se cruza")
	assert_lt(vadeando, seco * 0.6, "pero cuesta la mitad o mas")


# --- clasificar el suelo a partir del terreno -----------------------------

func test_el_suelo_se_deduce_de_pendiente_y_agua() -> void:
	assert_eq(Traversal.classify_ground(0.05, 0.0), Traversal.Ground.PASTO,
		"llano y seco es pasto")
	assert_eq(Traversal.classify_ground(0.05, 0.25), Traversal.Ground.MARISMA,
		"llano con agua somera es marisma")
	assert_eq(Traversal.classify_ground(1.2, 0.0), Traversal.Ground.ROCA,
		"muy empinado y seco es roca desnuda")


func test_el_canchal_empieza_en_el_angulo_de_reposo() -> void:
	# Debajo del angulo de reposo -unos 34 grados, tangente 0,67- el suelo
	# agarra y hay herbazal; por encima, lo que queda es derrubio suelto. No es
	# un umbral de gusto: es la misma constante que usa la erosion termica.
	assert_eq(Traversal.classify_ground(0.55, 0.0), Traversal.Ground.PASTO,
		"a 29 grados una ladera cantabrica tiene hierba")
	assert_eq(Traversal.classify_ground(0.85, 0.0), Traversal.Ground.CANCHAL,
		"pasado el reposo, la piedra se mueve bajo el pie")


# --- suelo de velocidad: caro no es lo mismo que parado --------------------

func test_la_marcha_nunca_llega_a_cero_en_una_pendiente_muy_dura() -> void:
	# `open_around_home` fuerza a pasable el entorno del abrigo aunque la
	# pendiente real pase de CLIMB_LIMIT -la puerta de una cueva no siempre
	# tiene un llano delante-. Sin suelo, el andador que de verdad pisa esa
	# celda se arrastraba a milimetros por hora: el planificador prometia
	# una ruta cara y el andador no la cumplia.
	var muy_empinada := Traversal.hiking_speed(3.0)
	assert_near(muy_empinada, Traversal.MIN_SPEED, 0.001,
		"por muy dura que sea la pendiente, no se cae por debajo del suelo")


func test_el_suelo_de_marcha_no_toca_la_pendiente_normal() -> void:
	# El suelo es una red de seguridad para lo extremo, no un tope que se
	# note andando por una ladera corriente
	var llano := Traversal.hiking_speed(0.0)
	assert_gt(llano, Traversal.MIN_SPEED * 10.0,
		"en llano, la marcha va muy por encima del suelo de emergencia")


# ----------------------------------------------- el barro de la estacion --

func test_en_seco_una_vaguada_humeda_no_es_barro() -> void:
	# 0,03 de vado es suelo húmedo, no barrizal. En agosto se cruza andando.
	assert_eq(Traversal.classify_ground(0.05, 0.03, 0.0), Traversal.Ground.PASTO,
		"con el suelo seco, un poco de agua somera sigue siendo prado")


func test_encharcado_la_misma_vaguada_es_barro() -> void:
	# Y en enero, con el suelo saturado, la MISMA vaguada del MISMO mapa de
	# vados es un barrizal. Eso es el barro: no cambia el terreno, cambia
	# cuánta agua hace falta para que el pie se hunda.
	assert_eq(Traversal.classify_ground(0.05, 0.03, 0.85),
		Traversal.Ground.MARISMA,
		"con el suelo encharcado, la misma vaguada es barro")


func test_el_barro_frena_pero_no_tapia() -> void:
	# La distinción que importa: el barro cansa, no cierra el paso. Si cerrara,
	# un invierno dejaría a la banda encerrada en el fondo del valle.
	assert_lt(Traversal.travel_speed(0.05, Traversal.Ground.MARISMA, 0.0),
		Traversal.travel_speed(0.05, Traversal.Ground.PASTO, 0.0),
		"por barro se anda mas despacio")
	assert_true(Traversal.is_passable(0.05, 0.03, false, false),
		"y aun asi se pasa: lo que cierra el paso es el vado, no el barro")


func test_el_camino_horneado_se_clasifica_en_seco() -> void:
	# `Navgrid` hornea la rejilla UNA vez y llama sin estación. Si el valor por
	# defecto no fuera seco, cada cambio de estación obligaría a rehacerla.
	assert_eq(Traversal.classify_ground(0.05, 0.03),
		Traversal.classify_ground(0.05, 0.03, 0.0),
		"sin decir estacion se clasifica en seco, que es lo que hornea Navgrid")
