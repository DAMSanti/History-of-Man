class_name TestModoDebug
extends TestCase
## El modo Debug: todos los yacimientos del Paleolitico, sin niebla. INTERFAZ §14.
##
## Lo que mas vale de aqui es **que no toque lo del jugador**: «Nueva partida» vacia el
## borrador, y al salir de un valle el juego autoguarda sin pedirlo. Un Debug que se
## colara por ahi tiraria la partida que el jugador tuviera a medias, sin avisar.

const Mapa := preload("res://scripts/region/RegionMap.gd")

## LAS CARPETAS DE LAS PRUEBAS, y no las del jugador: son las que hacen de «lo del jugador»
## que el Debug no puede tocar. Ver `TestPartida`.
const RAIZ_DE_PRUEBAS := "user://pruebas/debug/partidas"
const BORRADOR_DE_PRUEBAS := "user://pruebas/debug/partida_abierta"

var _nodos: Array[Node] = []


func suite_name() -> String:
	return "ModoDebug"


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()
	ModoDebug.salir()
	Partidas.raiz = RAIZ_DE_PRUEBAS
	Partidas.borrador = BORRADOR_DE_PRUEBAS
	Guardado.carpeta = BORRADOR_DE_PRUEBAS
	Partidas.abierta = {"id": "", "nombre": ""}
	Partidas.sucia = false
	GameState.started = false
	GameState.discovered = {}
	GameState.avistados = {}
	GameState.niebla = null
	ModoDebug.hay_version_de_desarrollo = OS.is_debug_build()


func _escribir(ruta: String, texto: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ruta.get_base_dir()))
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	fichero.store_string(texto)
	fichero.close()


func _bytes(ruta: String) -> PackedByteArray:
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		return PackedByteArray()
	return fichero.get_buffer(fichero.get_length())


# --- entrar y salir sin tocar lo del jugador (tarea 1) ---------------------------

func test_entrar_aparta_las_carpetas_y_salir_las_devuelve() -> void:
	ModoDebug.entrar()
	var dentro := Guardado.carpeta
	var raiz_dentro := Partidas.raiz
	ModoDebug.salir()
	assert_true(dentro.begins_with(ModoDebug.CARPETA),
		"dentro, los mapas van a la carpeta del Debug: %s" % dentro)
	assert_true(raiz_dentro.begins_with(ModoDebug.CARPETA), "y las partidas también")
	assert_eq(Guardado.carpeta, BORRADOR_DE_PRUEBAS, "al salir vuelve la de antes")
	assert_eq(Partidas.raiz, RAIZ_DE_PRUEBAS, "y la de las partidas")
	assert_eq(Partidas.borrador, BORRADOR_DE_PRUEBAS, "y el borrador")
	assert_false(ModoDebug.activo, "y ya no se está en Debug")


func test_no_toca_nada_guardado() -> void:
	# EL CRITERIO QUE IMPORTA. Lo del jugador —una partida guardada y un borrador a
	# medias— se escribe antes; se entra, se autoguarda como lo haría un valle, se funda
	# dos veces y se sale. Tiene que quedar byte a byte como estaba.
	var guardada := RAIZ_DE_PRUEBAS + "/mi_partida/partida.sav"
	var a_medias := BORRADOR_DE_PRUEBAS + "/sitio_56.sav"
	_escribir(guardada, "la partida del jugador")
	_escribir(a_medias, "lo que llevaba sin guardar")
	var antes_guardada := _bytes(guardada)
	var antes_a_medias := _bytes(a_medias)
	var sitios := SiteSet.comarca()

	ModoDebug.entrar()
	ModoDebug.preparar_el_mapa(sitios)
	# Lo que haría el valle al salir: escribir en `Guardado.carpeta` sin preguntar.
	_escribir(Guardado.carpeta + "/sitio_56.sav", "el autoguardado del Debug")
	ModoDebug.nueva_fundacion(sitios)
	_escribir(Guardado.carpeta + "/sitio_90001.sav", "otro autoguardado")
	ModoDebug.nueva_fundacion(sitios)
	ModoDebug.salir()

	assert_eq(_bytes(guardada), antes_guardada, "la partida guardada no se ha tocado")
	assert_eq(_bytes(a_medias), antes_a_medias, "ni el borrador a medias")
	assert_false(FileAccess.file_exists(BORRADOR_DE_PRUEBAS + "/sitio_90001.sav"),
		"y lo que se autoguardó en Debug no ha caído en la carpeta del jugador")


func test_nueva_partida_despues_de_debug_empieza_con_niebla() -> void:
	var sitios := SiteSet.comarca()
	ModoDebug.entrar()
	ModoDebug.preparar_el_mapa(sitios)
	ModoDebug.salir()
	# Lo que hace «Nueva partida».
	GameState.started = false
	GameState.discovered = {}
	GameState.niebla = null
	GameState.begin(sitios)
	assert_eq(GameState.discovered.size(), 1, "un solo yacimiento a la vista")
	assert_true(GameState.niebla != null, "y con niebla")
	assert_false(ModoDebug.activo, "sin rastro del Debug")


# --- todos a la vista, sin niebla (tarea 2) --------------------------------------

func test_en_debug_se_ve_todo_lo_que_ofrece_la_epoca() -> void:
	var sitios := SiteSet.comarca()
	ModoDebug.entrar()
	ModoDebug.preparar_el_mapa(sitios)
	var ofrecidos := sitios.available_in(ModoDebug.MAR_M, ModoDebug.ERA)
	# `RegionMap` no tiene `class_name`: se llama por su script, como en TestNieblaRegional.
	var dibujados: Dictionary = (load("res://scripts/region/RegionMap.gd") as GDScript).call(
		"sitios_que_se_dibujan", ofrecidos)
	var vistos: Array[Site] = dibujados["vistos"]
	var costa := 0
	for sitio: Site in vistos:
		if sitio.fidelity == Site.Fidelity.HIPOTETICO:
			costa += 1
	var niebla := GameState.niebla
	# Y LLEVAN MARCADOR, que es otro filtro: fuera de Debug sólo lo atestiguado lo lleva.
	# La primera versión pasaba esta prueba y dibujaba 63 de 76 en la ventana.
	var con_marcador := 0
	var guion := load("res://scripts/region/RegionMap.gd") as GDScript
	for sitio: Site in vistos:
		if guion.call("se_marca", sitio):
			con_marcador += 1
	ModoDebug.salir()
	var fuera_de_debug := 0
	for sitio: Site in vistos:
		if guion.call("se_marca", sitio):
			fuera_de_debug += 1
	assert_eq(con_marcador, ofrecidos.size(), "y todos llevan marcador en Debug")
	assert_true(fuera_de_debug < ofrecidos.size(),
		"fuera de Debug, los inferidos siguen sin marcador: %d de %d" % [
			fuera_de_debug, ofrecidos.size()])
	assert_gt(float(ofrecidos.size()), 1.0, "la época ofrece más de uno")
	assert_eq(vistos.size(), ofrecidos.size(),
		"se dibujan exactamente los que ofrece el Paleolítico: %d" % ofrecidos.size())
	assert_true(niebla == null, "y no hay niebla")
	assert_eq(costa, SitiosDeLaCosta.LOS_SITIOS.size(), "incluidos los abrigos de la costa")


# --- fundar en cualquiera, con banda nueva (tarea 3) -----------------------------

func test_se_funda_en_tres_sitios_distintos() -> void:
	var sitios := SiteSet.comarca()
	ModoDebug.entrar()
	ModoDebug.preparar_el_mapa(sitios)
	var ofrecidos := sitios.available_in(ModoDebug.MAR_M, ModoDebug.ERA)
	var casa := GameState.home
	var interior: Site = null
	var de_la_costa: Site = null
	var el_mas_lejos: Site = null
	var mas_lejos := -1.0
	for sitio: Site in ofrecidos:
		if sitio.fidelity == Site.Fidelity.HIPOTETICO:
			de_la_costa = sitio
		elif interior == null and sitio != casa:
			interior = sitio
		var lejos := Vector2(sitio.lon - casa.lon, sitio.lat - casa.lat).length()
		if lejos > mas_lejos:
			mas_lejos = lejos
			el_mas_lejos = sitio
	var bien := 0
	for sitio: Site in [interior, de_la_costa, el_mas_lejos]:
		ModoDebug.nueva_fundacion(sitios)
		if not Expedition.visita and not Expedition.retomando \
				and GameState.population == GameState.START_POPULATION \
				and Campamentos.vivos.is_empty() and GameState.se_ve(sitio):
			bien += 1
	ModoDebug.salir()
	assert_true(interior != null and de_la_costa != null and el_mas_lejos != null,
		"hay uno de cada")
	assert_eq(bien, 3, "los tres quedan listos para fundar, con la banda de arranque")


func test_cada_fundacion_trae_una_banda_nueva() -> void:
	var sitios := SiteSet.comarca()
	ModoDebug.entrar()
	ModoDebug.nueva_fundacion(sitios)
	var poblacion := GameState.population
	var despensa := GameState.food
	# Lo que la banda de A habría dejado al volver al mapa regional.
	GameState.population = 4
	GameState.food = 1.0
	GameState.year = 3
	GameState.season = Subsistence.Season.INVIERNO
	ModoDebug.nueva_fundacion(sitios)
	var en_b := [GameState.population, GameState.food, GameState.year, GameState.season]
	ModoDebug.salir()
	assert_eq(en_b[0], poblacion, "B arranca con la población inicial, no con la de A")
	assert_near(float(en_b[1]), despensa, 0.001, "y con la despensa de arranque")
	assert_eq(en_b[2], 1, "en el año uno")
	assert_eq(en_b[3], Subsistence.Season.PRIMAVERA, "y en primavera")


# --- el boton, solo en desarrollo (tarea 4) --------------------------------------

func _botones(nodo: Node) -> Array[String]:
	var salida: Array[String] = []
	if nodo is Button:
		salida.append((nodo as Button).text)
	for hijo: Node in nodo.get_children():
		salida.append_array(_botones(hijo))
	return salida


func _menu_principal() -> Array[String]:
	# Sin aplicar la configuración del equipo: eso lo hace el primer menú del proceso y
	# no es lo que se prueba.
	MenuPrincipal._configuracion_aplicada = true
	var menu := MenuPrincipal.new()
	menu._ready()
	var textos := _botones(menu)
	menu.free()
	return textos


func test_el_boton_solo_sale_en_la_version_de_desarrollo() -> void:
	ModoDebug.hay_version_de_desarrollo = true
	var con := _menu_principal()
	ModoDebug.hay_version_de_desarrollo = false
	var sin := _menu_principal()
	assert_true(con.has("Debug"), "en desarrollo sale: %s" % str(con))
	assert_false(sin.has("Debug"), "y en un ejecutable exportado, no: %s" % str(sin))


# --- el menú de ESC no guarda (tarea 5) ------------------------------------------

func _menu_de_esc() -> Array[String]:
	var menu := MenuDelJuego.new()
	menu._ready()
	var textos := _botones(menu)
	menu.free()
	return textos


func test_en_debug_el_menu_de_esc_no_ofrece_guardar() -> void:
	var fuera := _menu_de_esc()
	ModoDebug.entrar()
	var dentro := _menu_de_esc()
	ModoDebug.salir()
	assert_true(fuera.has("Guardar"), "fuera de Debug se puede guardar")
	for boton: String in ["Guardar", "Guardar como…", "Cargar"]:
		assert_false(dentro.has(boton), "en Debug no hay «%s»" % boton)
	assert_true(dentro.has("Salir al menú principal"), "pero sí se sale al menú")


# --- el rótulo y los sin preparar (tarea 6) --------------------------------------

func test_el_mapa_se_monta_con_el_mar_de_la_epoca_de_debug() -> void:
	# EL FALLO QUE ESTO IMPIDE (2026-09-17): el relieve de la plataforma y sus ríos se
	# congelan con el mar del montaje, y el modo Debug no funda nada, así que el mapa se
	# montaba con el mar de HOY y luego dibujaba encima la costa glacial: plataforma pelada
	# y sin un solo río. Al cargar una partida volvían, porque entonces sí había casa.
	#
	# **CORREGIDA EL 2026-09-18.** Esta prueba arreglaba el caso de Debug y a la vez fijaba
	# el otro como estaba: «sin partida y sin debug, el mapa es el de hoy». Y ése era el
	# mismo fallo, sin arreglar: el usuario lo vio al entrar en una partida nueva —«el mapa
	# regional aparece sin los ríos de la plataforma emergida»— porque hasta fundar se
	# dibujaba la Cantabria actual. Ahora hay **una sola respuesta**: la cota de la época,
	# que `GameState.sea_level_m` ya sabe desde que arranca el juego. Decisión del usuario.
	var casa := GameState.home
	var mar := GameState.sea_level_m
	var antes := ModoDebug.activo
	GameState.home = null

	ModoDebug.activo = false
	GameState.sea_level_m = -120.0
	# Mientras `EPOCA_ANTES_DE_FUNDAR` esté apagado -paso de bisección del 2026-09-19- una
	# partida nueva sin fundar vuelve a ver el mar de hoy. Cuando se encienda, esto pasa a
	# esperar -120 y la prueba lo dice sola.
	assert_near(Mapa.mar_del_mapa(), 0.0 if not Mapa.EPOCA_ANTES_DE_FUNDAR else -120.0, 0.01,
		"sin partida y sin debug, el mar que diga el interruptor")

	ModoDebug.activo = true
	assert_near(Mapa.mar_del_mapa(), -120.0, 0.01,
		"en debug, el mismo: debug no es un caso aparte")

	GameState.home = casa
	GameState.sea_level_m = mar
	ModoDebug.activo = antes


func test_el_rotulo_solo_en_debug() -> void:
	var escena := Node.new()
	_nodos.append(escena)
	var fuera := ModoDebug.rotulo(escena)
	ModoDebug.entrar()
	var dentro := ModoDebug.rotulo(escena)
	var dice := ""
	if dentro != null:
		dice = (dentro.get_child(0) as Label).text
	ModoDebug.salir()
	assert_true(fuera == null, "fuera de Debug no hay rótulo")
	assert_true(dentro != null, "en Debug sí")
	assert_true(dice.contains("DEBUG"), "y lo dice: %s" % dice)


func test_preparado_es_lo_que_hay_en_disco() -> void:
	var preparador := PreparaValle.new()
	preparador.carpeta_de_los_valles = "user://pruebas/debug/valles"
	var con := Site.new()
	con.id = 990501
	var sin := Site.new()
	sin.id = 990502
	_escribir(preparador.ruta_del_valle(con.id), "un valle")
	if FileAccess.file_exists(preparador.ruta_del_valle(sin.id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			preparador.ruta_del_valle(sin.id)))
	assert_true(ModoDebug.esta_preparado(con, preparador), "el que está en disco, sí")
	assert_false(ModoDebug.esta_preparado(sin, preparador), "y el que no, no")
