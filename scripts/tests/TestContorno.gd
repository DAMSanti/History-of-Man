class_name TestContorno
extends TestCase
## El contorno del valle, rehecho sin congelar la ventana. INTERFAZ §12.
##
## Todo esto **sin red**: los dos sitios donde la receta toca el IGN y Overpass son
## `PreparaValle.trae_el_relieve` y `trae_el_agua`, y aqui se les ponen datos de bote.
## Esa es la unica razon de que existan.
##
## Y **sin tocar los datos del jugador**: los contornos de mentira se escriben en la
## carpeta de las pruebas, no en `data/dem/local`.

## Donde se escriben los contornos de mentira. Ver [_con_contorno].
const CARPETA := "user://pruebas/contorno"

## Un id que no es de ningun sitio de verdad, para no pisar un contorno bakeado.
const ID_DE_PRUEBA := 990001

var _nodos: Array[Node] = []


func suite_name() -> String:
	return "Contorno"


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))


# --- los datos de bote -----------------------------------------------------------

## Un relieve cuadrado con cotas que dependen de la casilla: dos iguales son iguales
## byte a byte, y dos distintos se distinguen.
func _relieve(lado: int, metros: float, con_agua: bool, sal: float = 0.0) -> HeightmapData:
	var datos := HeightmapData.new()
	datos.width = lado
	datos.height = lado
	datos.meters_per_sample = metros
	datos.lat_north = 43.4
	datos.lat_south = 43.3
	datos.lon_west = -4.1
	datos.lon_east = -4.0
	var cotas := PackedFloat32Array()
	cotas.resize(lado * lado)
	for i in range(cotas.size()):
		cotas[i] = float(i) * 0.5 + sal
	datos.elevations = cotas
	if con_agua:
		var agua := PackedFloat32Array()
		agua.resize(lado * lado)
		for i in range(agua.size()):
			agua[i] = 1.0 if i % 7 == 0 else 0.0
		datos.river_mask = agua
	return datos


## Un preparador que no toca la red y escribe en la carpeta de las pruebas.
func _preparador(relieve: Variant, agua: Dictionary) -> PreparaValle:
	var preparador := PreparaValle.new()
	preparador.trae_el_relieve = func(_n: float, _s: float, _o: float, _e: float,
			_m: float) -> HeightmapData:
		return relieve as HeightmapData
	preparador.trae_el_agua = func(_n: float, _s: float, _o: float,
			_e: float) -> Dictionary:
		return agua
	return preparador


## Deja guardado un contorno de mentira para `ID_DE_PRUEBA` y devuelve su ruta.
func _con_contorno(surround: HeightmapData) -> String:
	var ruta := "%s/site_%d_surround.res" % [CARPETA, ID_DE_PRUEBA]
	surround.pipeline_version = PreparaValle.VERSION
	ResourceSaver.save(surround, ruta)
	return ruta


func _sitio() -> Site:
	var sitio := Site.new()
	sitio.id = ID_DE_PRUEBA
	sitio.lat = 43.35
	sitio.lon = -4.05
	return sitio


# --- los costurones (tarea 1) ----------------------------------------------------

func test_por_defecto_los_costurones_son_los_de_verdad() -> void:
	# Que existan para la prueba no puede significar que el juego se quede sin red.
	var preparador := PreparaValle.new()
	assert_true(preparador.trae_el_relieve.is_valid(), "hay de dónde sacar el relieve")
	assert_true(preparador.trae_el_agua.is_valid(), "y de dónde el agua")


# --- la receta (tarea 2) ---------------------------------------------------------

func test_un_contorno_seco_se_pinta_sin_bajar_el_relieve() -> void:
	# Son DOS cosas con precios muy distintos: si sólo falta el agua, no se paga la
	# descarga del relieve. Aquí el relieve devolvería null —como si el IGN fallara— y aun
	# así tiene que salir bien, porque ni se le pregunta.
	var seco := _relieve(8, 8.0, false, 3.0)
	var antes := seco.elevations.duplicate()
	var preparador := _preparador(null, {
		"channels": [[Vector2(-4.08, 43.38), Vector2(-4.02, 43.32)]], "bodies": []})
	_en_la_carpeta_de_pruebas(preparador, seco)
	var toco := preparador._rehacer_el_contorno(_sitio(), _relieve(8, 8.0, true))
	var despues: HeightmapData = load(_ruta_de_pruebas())
	assert_true(toco, "ha hecho algo")
	assert_false(despues.river_mask.is_empty(), "ahora tiene agua")
	assert_eq(despues.elevations, antes, "y el relieve es el mismo: no se bajó nada")


func test_la_receta_no_toca_un_contorno_que_ya_esta_bien() -> void:
	# Fino y con agua: no hay nada que hacer, y hacerlo costaría una descarga.
	var preparador := _preparador(_relieve(8, 8.0, true, 100.0),
		{"channels": [], "bodies": []})
	var bueno := _relieve(8, 8.0, true, 0.0)
	_en_la_carpeta_de_pruebas(preparador, bueno)
	var toco := preparador._rehacer_el_contorno(_sitio(), _relieve(8, 8.0, true))
	var despues: HeightmapData = load(_ruta_de_pruebas())
	assert_false(toco, "no hay nada que hacer")
	assert_eq(despues.elevations, bueno.elevations, "y no se ha tocado nada")


func test_la_receta_no_toca_ni_un_nodo() -> void:
	# Corre en un hilo, y Godot no deja tocar el árbol desde ahí (invariante 9 de
	# SPECS §7). Si alguien mete un `aviso.emit` o un nodo, esto revienta al correr en el
	# hilo de verdad y no en la suite, así que se mira el texto.
	var fuente := FileAccess.get_file_as_string(
		"res://scripts/region/PreparaValle.gd")
	var desde := fuente.find("func _rehacer_el_contorno")
	var hasta := fuente.find("\nfunc ", desde + 10)
	var receta := fuente.substr(desde, hasta - desde)
	assert_false(receta.contains("aviso.emit"),
		"la receta no emite señales: para eso está el buzón de `_avisar`")
	assert_false(receta.contains("await"), "ni espera cuadros: está en un hilo")


# --- si la red falla (tarea 4) ---------------------------------------------------

func test_sin_red_se_queda_el_contorno_que_habia_y_se_dice() -> void:
	# El caso de la spec: la descarga falla y la partida sigue.
	var viejo := _relieve(8, 30.0, true, 0.0)   # basto, pero con agua
	var antes := viejo.elevations.duplicate()
	var preparador := _preparador(null, {"channels": [], "bodies": []})
	var dichos: Array[String] = []
	preparador.aviso.connect(func(texto: String) -> void: dichos.append(texto))
	_en_la_carpeta_de_pruebas(preparador, viejo)
	preparador._rehacer_el_contorno(_sitio(), _relieve(8, 8.0, true))
	preparador._publicar()
	var despues: HeightmapData = load(_ruta_de_pruebas())
	assert_eq(despues.elevations, antes, "el relieve de alrededor es el que había")
	# Y LO DICE EN EL ULTIMO AVISO, no en uno de paso: el buzón guarda un solo texto y lo
	# publica el hilo principal cuando puede, así que un cartel seguido de otro se pisa.
	# La primera versión avisaba y seguía, y el aviso duraba un cuadro.
	var lo_dijo := false
	for texto: String in dichos:
		if texto.contains("IGN"):
			lo_dijo = true
	assert_true(lo_dijo, "y lo dice: %s" % str(dichos))


func test_con_red_el_contorno_basto_se_sustituye() -> void:
	var fino := _relieve(8, 8.0, false, 7.0)
	var preparador := _preparador(fino, {"channels": [], "bodies": []})
	_en_la_carpeta_de_pruebas(preparador, _relieve(8, 30.0, true, 0.0))
	preparador._rehacer_el_contorno(_sitio(), _relieve(8, 8.0, true))
	var despues: HeightmapData = load(_ruta_de_pruebas())
	assert_eq(despues.elevations, fino.elevations, "se ha quedado con el que bajó")
	assert_near(despues.meters_per_sample, 8.0, 0.001, "y con su resolución")


# --- byte a byte (tarea 5) -------------------------------------------------------

func test_dos_veces_la_misma_receta_dan_el_mismo_contorno() -> void:
	# LO QUE PIDE LA SPEC: el contorno rehecho es el mismo, con los mismos datos. Se
	# corre dos veces sobre el mismo punto de partida y se comparan los bytes.
	var uno := _bytes_de_una_pasada()
	var otro := _bytes_de_una_pasada()
	assert_true(not uno.is_empty(), "sale algo")
	assert_eq(uno, otro, "y sale lo mismo las dos veces")


func _bytes_de_una_pasada() -> PackedByteArray:
	var preparador := _preparador(_relieve(8, 8.0, false, 7.0),
		{"channels": [], "bodies": []})
	_en_la_carpeta_de_pruebas(preparador, _relieve(8, 30.0, true, 0.0))
	preparador._rehacer_el_contorno(_sitio(), _relieve(8, 8.0, true))
	var fichero := FileAccess.open(_ruta_de_pruebas(), FileAccess.READ)
	if fichero == null:
		return PackedByteArray()
	return fichero.get_buffer(fichero.get_length())


# --- la carpeta de las pruebas ---------------------------------------------------

func _ruta_de_pruebas() -> String:
	return "%s/site_%d_surround.res" % [CARPETA, ID_DE_PRUEBA]


## `_rehacer_el_contorno` busca el contorno en `res://data/dem/local`. Aquí se le deja
## uno ahí no: se le deja en la carpeta de las pruebas y se le dice dónde mirar.
func _en_la_carpeta_de_pruebas(preparador: PreparaValle, surround: HeightmapData) -> void:
	preparador.carpeta_de_los_valles = CARPETA
	_con_contorno(surround)
