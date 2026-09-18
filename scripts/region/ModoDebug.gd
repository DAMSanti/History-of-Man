class_name ModoDebug
extends RefCounted
## El modo Debug: el mapa regional sin niebla y todos los yacimientos del Paleolitico,
## para fundar en cualquiera. INTERFAZ §14.
##
## Para ver un valle hoy hay que jugarse la llegada: la partida empieza con un solo
## yacimiento a la vista y solo se funda una vez. Esto deja mirar cualquiera, con una
## banda nueva cada vez, **sin tocar nada del jugador**.
##
## Estado global sin autoload, como `GameState` (SPECS §2.2): tiene que sobrevivir a ir y
## volver entre el mapa regional y el valle.
##
## **La regla que lo sostiene: lo que se toca se aparta al entrar y se devuelve al salir,
## y todo lo que se escribe va a una carpeta suya.** «Nueva partida» vacia el borrador del
## jugador (`Partidas.nueva`), y al salir de un valle el juego autoguarda sin pedirlo. Un
## Debug que reutilizara ese camino tiraria la partida que el jugador tuviera a medias.
## Apuntando las carpetas a otra, lo que se escriba sin pedirlo cae aqui: es la receta de
## las pruebas, y es mas segura que perseguir cada sitio que guarda.

## Donde escribe el Debug. Se vacia al entrar y antes de cada fundacion.
const CARPETA := "user://debug"

## La epoca y el mar del Debug: el Paleolitico, con la plataforma emergida.
const ERA := Site.Era.PALEOLITICO
const MAR_M := -120.0

## Si se esta en Debug.
static var activo := false

## Si el boton sale en el menu principal. Es la version de desarrollo: al abrir el juego
## desde el proyecto, y no en un ejecutable exportado para jugar (decision del usuario).
## Es `static var` y no una consulta directa para que la prueba pueda pintar el menu con
## las dos marcas.
static var hay_version_de_desarrollo := OS.is_debug_build()

## Lo que habia antes de entrar, para devolverlo al salir.
static var _antes: Dictionary = {}


## Entra en Debug: aparta lo del jugador y deja el juego listo para montar el mapa.
static func entrar() -> void:
	if activo:
		return
	_antes = {
		"carpeta": Guardado.carpeta,
		"borrador": Partidas.borrador,
		"raiz": Partidas.raiz,
		"abierta": Partidas.abierta.duplicate(),
		"sucia": Partidas.sucia,
		"estado": _foto_del_estado(),
	}
	# Los campamentos vivos son de la partida de antes: la que se deja en el menu.
	Campamentos.vaciar()
	Guardado.carpeta = CARPETA + "/mapas"
	Partidas.borrador = CARPETA + "/mapas"
	Partidas.raiz = CARPETA + "/partidas"
	_vaciar(CARPETA)
	Partidas.abierta = {"id": "", "nombre": ""}
	Partidas.sucia = false
	_estado_limpio()
	Expedition.clear()
	activo = true


## Sale de Debug y lo deja todo como estaba al entrar.
static func salir() -> void:
	if not activo:
		return
	Campamentos.vaciar()
	_vaciar(CARPETA)
	Guardado.carpeta = String(_antes.get("carpeta", Guardado.CARPETA))
	Partidas.borrador = String(_antes.get("borrador", Partidas.BORRADOR_DEL_JUGADOR))
	Partidas.raiz = String(_antes.get("raiz", Partidas.raiz))
	Partidas.abierta = (_antes.get("abierta", {}) as Dictionary).duplicate()
	Partidas.sucia = bool(_antes.get("sucia", false))
	_poner_el_estado(_antes.get("estado", {}))
	Expedition.clear()
	_antes = {}
	activo = false


## El mapa regional de Debug: una partida arrancada, con todo a la vista y sin niebla.
##
## **Se arranca como una partida y luego se quita la niebla**, no al reves. Con
## `GameState.started` a falso el mapa ya lo enseñaria todo, pero media partida da por
## hecho que hay casa, poblacion y despensa, y eso lo pone `GameState.begin`.
static func preparar_el_mapa(sitios: SiteSet) -> void:
	if not activo or sitios == null:
		return
	if not GameState.started:
		GameState.begin(sitios)
	GameState.era = ERA
	GameState.sea_level_m = MAR_M
	for sitio: Site in sitios.available_in(MAR_M, ERA):
		GameState.discovered[sitio.id] = true
	# Sin niebla: `GameState.se_ve` da por visto lo descubierto cuando no hay niebla.
	GameState.niebla = null


## Deja el juego listo para fundar en cualquier sitio **con una banda recien llegada**.
##
## Es lo que convierte «fundar una vez» en «fundar en cualquiera» (decision del usuario):
## fuera los campamentos vivos y lo que el valle anterior autoguardo, y una partida
## arrancada de nuevo, con su poblacion, su despensa y su fecha de arranque. Lo que queda
## despues es la fundacion de siempre, con su pantalla de carga.
static func nueva_fundacion(sitios: SiteSet) -> void:
	if not activo:
		return
	Campamentos.vaciar()
	_vaciar(CARPETA)
	GameState.started = false
	preparar_el_mapa(sitios)
	Expedition.visita = false
	Expedition.retomando = false


## Si el valle de este sitio ya esta preparado en disco.
##
## **Mira que el fichero exista, no su sello de version**: el sello esta dentro de un
## recurso de veinte megas, y leerlo para cada marcador del mapa seria el tiron que no se
## quiere. Un valle de una version anterior sale como preparado y se rehace al fundar,
## igual que en una partida.
static func esta_preparado(sitio: Site, preparador: PreparaValle = null) -> bool:
	if sitio == null:
		return false
	var quien := preparador if preparador != null else PreparaValle.new()
	return FileAccess.file_exists(quien.ruta_del_valle(sitio.id))


## El rotulo que dice que se esta en Debug. Lo ponen el mapa regional y el valle.
## Devuelve el rotulo, o null si no se esta en Debug.
static func rotulo(escena: Node) -> CanvasLayer:
	if not activo or escena == null:
		return null
	var capa := CanvasLayer.new()
	capa.name = "RotuloDebug"
	capa.layer = 120
	var texto := Label.new()
	texto.text = "DEBUG — no se guarda nada"
	texto.add_theme_font_size_override("font_size", 16)
	texto.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	texto.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	texto.add_theme_constant_override("outline_size", 4)
	texto.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	texto.position = Vector2(-120.0, -40.0)
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(texto)
	escena.add_child(capa)
	return capa


# --- el estado de la partida, apartado y devuelto --------------------------------

static func _foto_del_estado() -> Dictionary:
	return {
		"era": GameState.era, "year": GameState.year, "season": GameState.season,
		"sea_level_m": GameState.sea_level_m, "home": GameState.home,
		"population": GameState.population, "food": GameState.food,
		"raw_material": GameState.raw_material,
		"discovered": GameState.discovered.duplicate(),
		"avistados": GameState.avistados.duplicate(),
		"niebla": GameState.niebla, "last_report": GameState.last_report,
		"marcadores_visibles": GameState.marcadores_visibles.duplicate(),
		"started": GameState.started,
	}


static func _poner_el_estado(foto: Dictionary) -> void:
	if foto.is_empty():
		_estado_limpio()
		return
	GameState.era = foto["era"]
	GameState.year = foto["year"]
	GameState.season = foto["season"]
	GameState.sea_level_m = foto["sea_level_m"]
	GameState.home = foto["home"]
	GameState.population = foto["population"]
	GameState.food = foto["food"]
	GameState.raw_material = foto["raw_material"]
	GameState.discovered = foto["discovered"]
	GameState.avistados = foto["avistados"]
	GameState.niebla = foto["niebla"]
	GameState.last_report = foto["last_report"]
	GameState.marcadores_visibles = foto["marcadores_visibles"]
	GameState.started = foto["started"]


static func _estado_limpio() -> void:
	GameState.started = false
	GameState.discovered = {}
	GameState.avistados = {}
	GameState.niebla = null


## Vacia una carpeta de `user://` con lo que tenga dentro. Solo se usa con la del Debug.
static func _vaciar(carpeta: String) -> void:
	assert(carpeta.begins_with(CARPETA), "ModoDebug solo vacia su propia carpeta")
	var ruta := ProjectSettings.globalize_path(carpeta)
	if not DirAccess.dir_exists_absolute(ruta):
		DirAccess.make_dir_recursive_absolute(ruta)
		return
	_borrar_dentro(ruta)


static func _borrar_dentro(ruta: String) -> void:
	var dir := DirAccess.open(ruta)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_borrar_dentro(ruta.path_join(sub))
		DirAccess.remove_absolute(ruta.path_join(sub))
	for fichero: String in dir.get_files():
		DirAccess.remove_absolute(ruta.path_join(fichero))
