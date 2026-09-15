class_name TestCarga
extends TestCase
## La pantalla de carga: el reparto de la barra y lo que dice. INTERFAZ §9.


func suite_name() -> String:
	return "Carga"


func test_la_barra_avanza_por_peso_y_no_por_etapas() -> void:
	var r := RepartoDeCarga.new()
	r.etapas([["Levantando el relieve", 1000.0], ["Sembrando el bosque", 3000.0]])
	var al_empezar := r.valor()
	r.etapa(1)
	var tras_el_relieve := r.valor()
	r.avanzar(0.5)
	var medio_bosque := r.valor()
	r.terminar()
	assert_near(al_empezar, 0.0, 0.0001, "empieza vacía")
	assert_near(tras_el_relieve, 0.25, 0.0001, "el relieve pesa un cuarto, no la mitad")
	assert_near(medio_bosque, 0.625, 0.0001, "y medio bosque son tres octavos más")
	assert_near(r.valor(), 1.0, 0.0001, "terminada, llena")


func test_la_barra_no_retrocede() -> void:
	var r := RepartoDeCarga.new()
	r.etapas([["a", 1.0], ["b", 1.0]])
	r.etapa(1)
	r.avanzar(0.6)
	var antes := r.valor()
	r.avanzar(0.2)
	r.etapa(0)
	assert_near(r.valor(), antes, 0.0001, "ni un avance menor ni volver a una etapa pasada")


func test_encadenar_otra_carga_reparte_lo_que_falta() -> void:
	# Preparar un valle y luego montarlo: las etapas nuevas llegan con la barra avanzada.
	var r := RepartoDeCarga.new()
	r.etapas([["Descargando el relieve", 1.0]])
	r.etapa(0)
	r.avanzar(1.0)
	var descargado := r.valor()
	r.etapas([["Sembrando el bosque", 1.0], ["Encendiendo el hogar", 1.0]])
	var al_declarar := r.valor()
	r.etapa(1)
	assert_near(descargado, 1.0, 0.0001, "la primera carga, entera")
	assert_near(al_declarar, 1.0, 0.0001, "declarar la segunda no la vacía")
	var r2 := RepartoDeCarga.new()
	r2.etapas([["uno", 1.0], ["dos", 1.0]])
	r2.etapa(1)
	var mitad := r2.valor()
	r2.etapas([["tres", 1.0], ["cuatro", 1.0]])
	r2.etapa(1)
	assert_near(mitad, 0.5, 0.0001, "a medias")
	assert_near(r2.valor(), 0.75, 0.0001, "y lo nuevo se reparte la otra mitad")


func test_el_texto_es_el_de_la_etapa() -> void:
	var r := RepartoDeCarga.new()
	r.etapas([["Levantando el relieve", 1.0], ["Sembrando el bosque", 1.0]])
	var antes := r.texto()
	r.etapa(1)
	assert_eq(antes, "", "sin etapa empezada, nada")
	assert_eq(r.texto(), "Sembrando el bosque", "la que está en marcha")


func test_siguiente_empieza_la_etapa_de_detras() -> void:
	var r := RepartoDeCarga.new()
	r.etapas([["uno", 1.0], ["dos", 1.0], ["tres", 2.0]])
	r.siguiente()
	var primera := r.texto()
	r.siguiente()
	r.siguiente()
	assert_eq(primera, "uno", "sin etapa, la primera")
	assert_eq(r.texto(), "tres", "y cada vez la de detrás")
	assert_near(r.valor(), 0.5, 0.0001, "con las anteriores hechas")


func test_sin_pantalla_no_hay_carga_repartida() -> void:
	assert_false(Carga.abierta(), "en las pruebas no hay pantalla abierta")


func test_los_textos_son_del_juego_y_no_del_motor() -> void:
	for bueno: String in ["Levantando el relieve", "Sembrando el bosque", "Despertando a la banda"]:
		assert_true(Carga.texto_valido(bueno), "«%s» se enseña" % bueno)
	for malo: String in ["_levantar_vegetacion", "Forest.gd", "TerrainGenerator", "cargar(recursos)", ""]:
		assert_false(Carga.texto_valido(malo), "«%s» no" % malo)


func test_la_pantalla_se_monta() -> void:
	var pantalla := PantallaDeCarga.new()
	pantalla.titulo = "Volviendo al valle"
	var titulo := pantalla._titulo.text
	var capa := pantalla.layer
	var tapa := pantalla._fondo.mouse_filter
	pantalla.free()
	assert_eq(titulo, "Volviendo al valle", "con su título")
	assert_gt(float(capa), 100.0, "por encima de la interfaz")
	assert_eq(tapa, Control.MOUSE_FILTER_STOP, "y se come el ratón: detrás hay un mundo a medio montar")


## INTERFAZ §9: «la partida no avanza mientras carga». Con la pantalla abierta, el reloj
## de la partida y la simulación suelta no acumulan el tiempo de los cuadros.
func test_con_la_pantalla_abierta_el_reloj_no_anda() -> void:
	var sim := SettlementSim.new()
	sim.people.append(Inhabitant.new())
	sim._terrain = TerrainGenerator.new()
	var reloj := RelojDeLaPartida.new()
	reloj.noche_acelerada = false
	reloj.campamentos.append(sim)
	# Sin pantalla, y con menos de un paso: el tiempo se guarda.
	reloj._process(0.01)
	sim._process(0.01)
	var reloj_sin := reloj._pendiente
	var sim_sin := sim._pendiente
	var pantalla := PantallaDeCarga.new()
	Carga._pantalla = pantalla
	reloj._process(0.02)
	sim._process(0.02)
	var reloj_con := reloj._pendiente
	var sim_con := sim._pendiente
	Carga._pantalla = null
	pantalla.free()
	sim._terrain.free()
	sim.free()
	reloj.free()
	assert_gt(reloj_sin, 0.0, "sin pantalla, el reloj guarda el tiempo del cuadro")
	assert_gt(sim_sin, 0.0, "y la simulación suelta también")
	assert_near(reloj_con, reloj_sin, 0.000001, "con la pantalla abierta, el reloj no suma nada")
	assert_near(sim_con, sim_sin, 0.000001, "ni la simulación")


func test_las_etapas_del_mapa_de_la_banda_se_pueden_leer() -> void:
	# Por el script: `DemoMain` no tiene `class_name`.
	var etapas: Array = (load("res://scripts/DemoMain.gd") as GDScript).get_script_constant_map()["ETAPAS"]
	for par: Array in etapas:
		assert_true(Carga.texto_valido(String(par[0])), "«%s»" % par[0])
		assert_gt(float(par[1]), 0.0, "«%s» pesa algo" % par[0])


func test_las_etapas_del_regional_y_del_valle_se_pueden_leer() -> void:
	var regional: Array = (load("res://scripts/region/RegionMap.gd") as GDScript).get_script_constant_map()["ETAPAS"]
	var con_cache: Array = (load("res://scripts/region/RegionMap.gd") as GDScript).get_script_constant_map()["ETAPAS_CON_CACHE"]
	assert_eq(con_cache.size(), regional.size(), "con caché, las mismas etapas")
	for par: Array in regional + con_cache + PreparaValle.ETAPAS:
		assert_true(Carga.texto_valido(String(par[0])), "«%s»" % par[0])
		assert_gt(float(par[1]), 0.0, "«%s» pesa algo" % par[0])


## Por tiempo, la barra avanza en proporción a lo medido y se detiene cerca del final
## de la etapa si ésta tarda más: no finge avance (INTERFAZ §9.3).
func test_por_tiempo_la_barra_se_detiene_antes_de_acabar_la_etapa() -> void:
	assert_near(RepartoDeCarga.fraccion_por_tiempo(500.0, 1000.0), 0.5, 0.0001, "a mitad de lo medido, a mitad")
	assert_near(RepartoDeCarga.fraccion_por_tiempo(40000.0, 1000.0), 0.95, 0.0001,
		"pasado lo medido, detenida en el 95 %: la etapa no está hecha")


## Una etapa que resulta más corta de lo medido queda hecha con lo que tardó: la barra
## sube a donde está la carga de verdad en vez de quedarse atrás todo su peso.
func test_una_etapa_mas_corta_se_da_por_hecha() -> void:
	var r := RepartoDeCarga.new()
	r.etapas([["uno", 1000.0], ["Sembrando el bosque", 1000000.0], ["tres", 1000.0]])
	r.etapa(1)
	var antes := r.valor()
	r.dar_por_hecha_la_etapa()
	var despues := r.valor()
	r.siguiente()
	r.avanzar(0.5)
	assert_lt(antes, 0.01, "con el peso de sembrar, la barra casi vacía")
	assert_gt(despues, 0.49, "hecha con lo que tardó —casi nada—, la mitad de lo que queda")
	assert_near(r.valor(), 0.75, 0.01, "y lo de detrás se reparte lo que falta")

