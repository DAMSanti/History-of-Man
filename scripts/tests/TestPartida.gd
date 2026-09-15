class_name TestPartida
extends TestCase
## Las partidas guardadas: empezar una limpia, guardarla, listarla y cargarla.
##
## Spec y plan: `docs/INTERFAZ.md` §7 y §7.6. Lo que se comprueba aquí son las
## REGLAS —qué toca cada cosa en disco, qué se lee, qué se rechaza—; que la
## partida cargada siga dando la misma firma jornada a jornada sólo se puede
## comprobar entre dos procesos, y eso es `PartidaProbe`.


func suite_name() -> String:
	return "Partidas"


## LAS CARPETAS DE LAS PRUEBAS, y no las del jugador. Esta suite borró una
## partida real el 2026-09-13 por escribir donde escribe el juego; desde
## entonces, tanto `Guardado.carpeta` como `Partidas.raiz` se apuntan aquí. Ver
## `TestGuardado`.
const RAIZ_DE_PRUEBAS := "user://pruebas/partidas"
const BORRADOR_DE_PRUEBAS := "user://pruebas/partida_abierta"


func before_each() -> void:
	Partidas.raiz = RAIZ_DE_PRUEBAS
	Partidas.borrador = BORRADOR_DE_PRUEBAS
	Guardado.carpeta = BORRADOR_DE_PRUEBAS
	Partidas.abierta = {"id": "", "nombre": ""}
	Partidas.sucia = false
	for entrada: Dictionary in Partidas.lista():
		Partidas.borrar(String(entrada["id"]))
	Guardado.borrar()


func test_las_pruebas_no_tocan_las_partidas_del_jugador() -> void:
	assert_true(Partidas.raiz != "user://partidas",
		"las pruebas guardan en su carpeta, no en la del juego")
	assert_true(Partidas.borrador != Partidas.BORRADOR_DEL_JUGADOR,
		"y tampoco en la carpeta de trabajo de la partida abierta")
	assert_true(Guardado.carpeta != Guardado.CARPETA,
		"ni en los mapas del jugador")


## Una simulación mínima que se pueda guardar, con su sitio de traspaso puesto:
## sin sitio no hay mapa donde guardar el estado. Ver [Guardado].
const SITIO := 778


func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 90.0)
	sim.techs = TechTree.new()
	sim.knowledge = BandKnowledge.new()
	sim.game_seed = 909
	sim.day = 12
	for i in range(4):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "P%d" % i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	return sim


func _con_sitio(sitio: int = SITIO) -> Dictionary:
	var antes := {"site": Expedition.site, "home": GameState.home}
	var s := Site.new()
	s.id = sitio
	Expedition.site = s
	return antes


func _devolver(antes: Dictionary) -> void:
	Expedition.site = antes["site"]
	GameState.home = antes["home"]


func _cuantos_ficheros(carpeta: String) -> int:
	var dir := DirAccess.open(carpeta)
	return 0 if dir == null else dir.get_files().size()


# --- empezar una limpia ----------------------------------------------------

func test_nueva_vacia_la_carpeta_de_trabajo_y_apunta_ahi() -> void:
	var antes := _con_sitio()
	Guardado.carpeta = BORRADOR_DE_PRUEBAS
	Guardado.guardar(_sim())
	assert_gt(float(_cuantos_ficheros(BORRADOR_DE_PRUEBAS)), 0.0,
		"había un mapa de antes")
	Partidas.nueva()
	_devolver(antes)
	assert_eq(_cuantos_ficheros(BORRADOR_DE_PRUEBAS), 0,
		"la partida nueva empieza con la carpeta de trabajo vacía")
	assert_eq(Guardado.carpeta, Partidas.borrador,
		"y el guardado de mapas apunta a ella")
	assert_eq(Partidas.nombre_abierto(), "", "una partida nueva no tiene nombre")
	assert_false(Partidas.hay_cambios(), "ni nada que guardar todavía")


func test_nueva_no_toca_las_partidas_guardadas() -> void:
	# Criterio 2 de la spec: empezar una partida no puede pisar las que hay.
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	assert_eq(Partidas.guardar("La primera"), "", "se guarda")
	var cuantas := Partidas.lista().size()
	Partidas.nueva()
	_devolver(antes)
	assert_eq(Partidas.lista().size(), cuantas,
		"la partida nueva deja las guardadas donde estaban")
	assert_false(Partidas.lista().is_empty(), "y hay al menos una")


# --- guardar y cargar ------------------------------------------------------

func test_guardar_deja_la_partida_en_la_lista() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	assert_eq(Partidas.guardar("Cueva del oso"), "", "se guarda sin error")
	var lista := Partidas.lista()
	_devolver(antes)
	assert_eq(lista.size(), 1, "sale una partida en la lista")
	assert_eq(String(lista[0]["nombre"]), "Cueva del oso", "con su nombre")
	assert_true(bool(lista[0]["legible"]), "y legible")
	assert_eq(int(lista[0].get("jornada", -1)), 12, "y la jornada de la partida")
	assert_eq(int(lista[0].get("sitio", -1)), SITIO, "y el mapa que se jugaba")


func test_guardar_sin_nombre_no_guarda() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	var fallo := Partidas.guardar("   ")
	_devolver(antes)
	assert_false(fallo.is_empty(), "una partida guardada necesita nombre")
	assert_true(Partidas.lista().is_empty(), "y no se ha creado ninguna")


func test_cargar_devuelve_el_mapa_que_se_guardo() -> void:
	var antes := _con_sitio()
	var sim := _sim()
	Guardado.guardar(sim)
	Partidas.guardar("La del río")
	# Se ensucia la carpeta de trabajo, como si se hubiera empezado otra.
	Partidas.nueva()
	assert_true(Guardado.leer(SITIO).is_empty(), "la nueva no tiene ese mapa")

	var fallo := Partidas.cargar(Partidas.lista()[0]["id"] as String, null)
	var leido := Guardado.leer(SITIO)
	_devolver(antes)
	assert_eq(fallo, "", "se carga sin error")
	assert_false(leido.is_empty(), "y el mapa vuelve")
	assert_eq(int(leido.get("semilla", -1)), 909, "con su semilla")
	assert_eq(Partidas.nombre_abierto(), "La del río", "y la partida abierta es ésa")


func test_la_partida_guarda_el_valle_de_la_banda_y_no_las_visitas() -> void:
	# Criterio 6 decía que una partida guarda TODOS los valles visitados. Desde el
	# 2026-09-14 la banda vive sólo en el primero y los demás se visitan sin ella:
	# «no debe traer a mi banda, sólo cargar y mostrarme el mapa». Una visita no
	# tiene estado, así que la partida lleva el valle de la banda y nada más. Ver
	# [Guardado.sitio_de_la_banda] e INTERFAZ §7.
	var antes := _con_sitio(SITIO)
	Guardado.guardar(_sim())
	var otro := _con_sitio(SITIO + 1)
	var sim2 := _sim()
	sim2.day = 40
	var fallo := Guardado.guardar(sim2)
	Partidas.guardar("Dos valles")
	Partidas.nueva()
	Partidas.cargar(Partidas.lista()[0]["id"] as String, null)
	var primero := Guardado.leer(SITIO)
	var segundo := Guardado.leer(SITIO + 1)
	_devolver(otro)
	_devolver(antes)
	assert_false(fallo.is_empty(), "el valle visitado no se guarda")
	assert_false(primero.is_empty(), "el de la banda sigue guardado")
	assert_eq(int(primero.get("jornada", -1)), 12, "en su jornada")
	assert_true(segundo.is_empty(), "y del visitado no vuelve nada")


# --- nombres, sobrescritura y borrado --------------------------------------

func test_el_mismo_nombre_es_la_misma_ranura() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	Partidas.guardar("Cueva Peña")
	assert_true(Partidas.abierta["id"] != "", "la partida tiene ranura")
	Partidas.abierta = {"id": "", "nombre": ""}
	assert_true(Partidas.existe("Cueva Peña"),
		"otra partida con ese nombre sobrescribiría")
	assert_false(Partidas.existe("Cueva Pena"),
		"y la eñe no se tira: son dos nombres distintos")
	_devolver(antes)


func test_la_suya_no_cuenta_como_sobrescribir() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	Partidas.guardar("La mía")
	var suya := Partidas.existe("La mía")
	_devolver(antes)
	assert_false(suya, "guardar encima de la propia no pregunta nada")


func test_borrar_la_quita_de_la_lista_y_del_disco() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	Partidas.guardar("Para borrar")
	var id := String(Partidas.lista()[0]["id"])
	Partidas.borrar(id)
	var lista := Partidas.lista()
	_devolver(antes)
	assert_true(lista.is_empty(), "ya no está en la lista")
	assert_true(Partidas.leer_cabecera(id).is_empty(), "ni en el disco")


# --- lo que no se puede leer -----------------------------------------------

func test_una_partida_de_otra_version_sale_marcada_y_no_carga() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	Partidas.guardar("Antigua")
	var id := String(Partidas.lista()[0]["id"])
	# Se le cambia la versión a mano, que es lo que pasará al subirla.
	var ruta := Partidas.raiz.path_join(id).path_join(Partidas.CABECERA)
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	fichero.store_var({"version": Partidas.VERSION + 1, "nombre": "Antigua"}, true)
	fichero.close()

	var lista := Partidas.lista()
	var fallo := Partidas.cargar(id, null)
	_devolver(antes)
	assert_eq(lista.size(), 1, "sigue saliendo en la lista")
	assert_false(bool(lista[0]["legible"]), "pero marcada como ilegible")
	assert_false(fallo.is_empty(), "y no se carga")


func test_una_carpeta_a_medias_no_esconde_las_demas() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	Partidas.guardar("Buena")
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(Partidas.raiz.path_join("rota")))
	var lista := Partidas.lista()
	_devolver(antes)
	assert_eq(lista.size(), 2, "salen las dos")
	var buenas := 0
	for entrada: Dictionary in lista:
		if bool(entrada["legible"]):
			buenas += 1
	assert_eq(buenas, 1, "y sólo una es legible")


# --- la marca de «hay cambios» ---------------------------------------------

func test_guardar_apaga_la_marca_y_jugar_la_enciende() -> void:
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	Partidas.tocar()
	assert_true(Partidas.hay_cambios(), "jugar deja cambios sin guardar")
	Partidas.guardar("Con marca")
	assert_false(Partidas.hay_cambios(), "guardar los deja en disco")
	Partidas.tocar()
	_devolver(antes)
	assert_true(Partidas.hay_cambios(), "y seguir jugando vuelve a marcarla")


func test_salir_sin_nombre_guarda_como_sin_titulo() -> void:
	# Decisión del usuario del 2026-09-13: salir no pierde la partida.
	var antes := _con_sitio()
	Guardado.guardar(_sim())
	assert_eq(Partidas.guardar_donde_estaba(), "", "se guarda sola")
	var lista := Partidas.lista()
	_devolver(antes)
	assert_eq(lista.size(), 1, "y aparece en la lista")
	assert_eq(String(lista[0]["nombre"]), Partidas.SIN_TITULO,
		"con el nombre de las que nunca se guardaron a mano")
