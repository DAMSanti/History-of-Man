class_name Partidas
extends RefCounted
## La partida: la que se está jugando, y las que hay guardadas en disco.
##
## Spec y plan: `docs/INTERFAZ.md` §7 y §7.6. Es lo que [Guardado] dejó aplazado
## con todas las letras —«el guardado de partida se desarrollará
## aparte, más adelante»—: allí hay **un fichero por MAPA**, que es lo que
## sostiene la sesión, y aquí está lo que junta esos ficheros en una historia
## con nombre, fecha y sitio, que es lo que se puede cerrar el juego y retomar
## otro día.
##
## ## Carpeta de trabajo, y copia al guardar
##
## La partida abierta vive en [borrador], y a esa carpeta apunta
## `Guardado.carpeta` mientras se juega: así el autoguardado por mapa sigue
## haciendo exactamente lo que hacía, pero dentro de la partida en curso.
## **Guardar** copia esa carpeta a una ranura de [raiz] con su cabecera.
##
## Se descartó autoguardar directo sobre la ranura: eso sería el autoguardado de
## partida, que la spec deja fuera a propósito (§7.5). Con carpeta de trabajo,
## guardar sigue siendo un acto del jugador.
##
## ## Estático, y sin autoload
##
## Como [Guardado], [GameState] y [Expedition]: lo que cruza escenas va en
## `static var`, que queda cargado igual y no obliga a tocar `project.godot`.
## SPECS §2.2.

## Sube cuando una partida guardada deja de poder leerse. Es la versión de la
## PARTIDA, distinta de `Guardado.VERSION`, que es la de un mapa: una partida
## puede dejar de valer sin que cambie el formato de sus mapas.
const VERSION := 1

## La carpeta de trabajo del JUGADOR: la partida abierta, con sus mapas dentro.
const BORRADOR_DEL_JUGADOR := "user://partida_abierta"

## Y la que se usa de verdad. Conmutable por lo mismo que [raiz]: una prueba no
## escribe en la partida abierta del jugador.
static var borrador := BORRADOR_DEL_JUGADOR

## El nombre del fichero de cabecera dentro de una partida guardada.
const CABECERA := "partida.sav"

## El nombre que se le pone a la partida que sale del juego sin haberse guardado
## nunca. Decisión del usuario del 2026-09-13: salir no puede perder la partida,
## y el menú se queda en tres botones —sin «Continuar»—, así que lo que no tiene
## nombre aparece en la lista con éste.
const SIN_TITULO := "Sin título"

## Dónde viven las partidas guardadas.
##
## **Conmutable, y por el mismo motivo que `Guardado.carpeta`**: la suite borró
## una vez la partida del jugador. Las pruebas y las sondas apuntan esto a otro
## sitio, y hay una prueba que comprueba que el valor de aquí no es el del
## jugador mientras corren.
static var raiz := "user://partidas"

## La partida abierta: `{"id", "nombre"}`. `id` vacío quiere decir que nunca se
## ha guardado —una partida nueva que todavía no tiene ranura—.
static var abierta: Dictionary = {}

## Si ha pasado algo desde el último guardado.
##
## Es una MARCA, no una comparación de ficheros: se enciende al cerrar una
## jornada —`paso_cerrado`, SPECS §3.2, el único límite limpio de la partida— y
## al autoguardar un mapa, y se apaga al guardar. Comparar carpetas byte a byte
## para contestar «¿has jugado algo?» sería leer el disco entero cada vez que se
## pulsa ESC.
static var sucia := false


## Abre una partida nueva: vacía la carpeta de trabajo y apunta ahí el guardado
## de mapas. No toca ninguna ranura, que es el criterio 2 de la spec.
static func nueva() -> void:
	# Los campamentos vivos son de la partida que se cierra. Ver [Campamentos].
	Campamentos.vaciar()
	_vaciar(borrador)
	Guardado.carpeta = borrador
	abierta = {"id": "", "nombre": ""}
	sucia = false


## Marca que la partida ha avanzado. Lo llaman el cierre de jornada y el
## autoguardado de mapa.
static func tocar() -> void:
	sucia = true


## Si hay algo jugado que no está en disco.
static func hay_cambios() -> bool:
	return sucia


## Cómo se llama la partida abierta, o vacío si nunca se ha guardado.
static func nombre_abierto() -> String:
	return String(abierta.get("nombre", ""))


## Guarda la partida abierta con este nombre. Devuelve el error, o vacío si ha
## ido bien.
##
## El `sim` es el de la escena, si la hay: **se guarda primero el mapa en curso
## desde la simulación viva**, que es lo que hace que guardar a media jornada
## guarde lo que se ve y no el último autoguardado. En el mapa regional no hay
## simulación y no hace falta: lo que hay en la carpeta de trabajo ya es lo
## último.
static func guardar(nombre: String, sim: SettlementSim = null,
		fauna: WildlifeHerds = null, cuevas: Array = []) -> String:
	var como := nombre.strip_edges()
	if como.is_empty():
		return "una partida guardada necesita un nombre"
	if sim != null:
		var fallo := Guardado.guardar(sim, fauna, cuevas)
		if not fallo.is_empty():
			return fallo

	var id := _id_de(como)
	var destino := raiz.path_join(id)
	# A un nombre temporal y renombrando al final: si el juego se cierra a mitad
	# de la copia, lo que queda a medias es el temporal y la ranura de antes
	# sigue entera.
	var medias := raiz.path_join("_" + id)
	_vaciar(medias)
	var error := _copiar_mapas(borrador, medias)
	if not error.is_empty():
		return error
	error = _escribir_cabecera(medias, como)
	if not error.is_empty():
		return error
	_vaciar(destino)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))
	var fallo_mover := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(medias),
		ProjectSettings.globalize_path(destino))
	if fallo_mover != OK:
		return "no se ha podido dejar la partida en %s" % destino

	abierta = {"id": id, "nombre": como}
	sucia = false
	return ""


## Guarda con el nombre que ya tenía; si no tenía, con [SIN_TITULO]. Es lo que
## hace el botón de guardar y lo que hace salir sin guardar.
static func guardar_donde_estaba(sim: SettlementSim = null,
		fauna: WildlifeHerds = null, cuevas: Array = []) -> String:
	var como := nombre_abierto()
	if como.is_empty():
		como = SIN_TITULO
	return guardar(como, sim, fauna, cuevas)


## Si ya existe una partida guardada con este nombre. Lo pregunta el modal antes
## de sobrescribir.
static func existe(nombre: String) -> bool:
	var id := _id_de(nombre.strip_edges())
	if id.is_empty():
		return false
	if String(abierta.get("id", "")) == id:
		return false  # la suya no es sobrescribir a otro
	return FileAccess.file_exists(raiz.path_join(id).path_join(CABECERA))


## Abre una partida guardada: la copia a la carpeta de trabajo y la deja lista
## para entrar. Devuelve el error, o vacío.
##
## No cambia de escena ni monta nada: eso es de quien llama. Lo que deja hecho
## es `Guardado.carpeta` apuntando a la partida y `Expedition`/`GameState`
## preparados para el mapa en el que se guardó.
static func cargar(id: String, sitios: SiteSet) -> String:
	var cabecera := leer_cabecera(id)
	if cabecera.is_empty():
		return "esa partida no se puede leer"
	Campamentos.vaciar()
	_vaciar(borrador)
	var error := _copiar_mapas(raiz.path_join(id), borrador)
	if not error.is_empty():
		return error
	Guardado.carpeta = borrador
	abierta = {"id": id, "nombre": String(cabecera.get("nombre", id))}
	sucia = false

	var sitio := int(cabecera.get("sitio", -1))
	var guardado := Guardado.leer(sitio)
	if guardado.is_empty():
		return "la partida no trae el mapa en el que se guardó"
	if sitios != null and not Guardado.preparar_la_escena(guardado, sitios):
		return "la partida apunta a un emplazamiento que no está"
	return ""


## Las partidas guardadas, de la más reciente a la más vieja.
##
## Cada una se lee de SU cabecera, no de un índice aparte que pueda
## desincronizarse (criterio 7). Lo que no trae cabecera legible sale igual, con
## `legible: false`: que una carpeta a medias no esconda las demás.
static func lista() -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	var dir := DirAccess.open(raiz)
	if dir == null:
		return salida
	for nombre: String in dir.get_directories():
		if nombre.begins_with("_"):
			continue  # una copia a medias
		var cabecera := leer_cabecera(nombre)
		if cabecera.is_empty():
			salida.append({"id": nombre, "nombre": nombre, "legible": false})
			continue
		cabecera["id"] = nombre
		cabecera["legible"] = true
		salida.append(cabecera)
	salida.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("cuando", 0)) > int(b.get("cuando", 0)))
	return salida


## La cabecera de una partida, o vacío si no está o es de otra versión.
static func leer_cabecera(id: String) -> Dictionary:
	var ruta := raiz.path_join(id).path_join(CABECERA)
	if not FileAccess.file_exists(ruta):
		return {}
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		return {}
	var datos: Variant = fichero.get_var(true)
	fichero.close()
	if not (datos is Dictionary):
		return {}
	var cabecera: Dictionary = datos
	if int(cabecera.get("version", -1)) != VERSION:
		return {}
	return cabecera


## Borra una partida guardada. Si era la abierta, la abierta se queda sin
## ranura: lo jugado sigue en la carpeta de trabajo.
static func borrar(id: String) -> void:
	_vaciar(raiz.path_join(id))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(raiz.path_join(id)))
	if String(abierta.get("id", "")) == id:
		abierta["id"] = ""
		sucia = true


# ------------------------------------------------------------- por dentro --

## El identificador de carpeta de un nombre: lo que se puede escribir en un
## sistema de ficheros sin sorpresas. Dos nombres que se reducen al mismo id son
## la misma ranura, que es justo lo que hace que «sobrescribir» signifique algo.
static func _id_de(nombre: String) -> String:
	# Se quita lo que un sistema de ficheros no admite, y NADA MÁS. Las tildes y
	# la eñe se quedan: «Cueva Peña» y «Cueva Pena» son dos partidas distintas y
	# tienen que ser dos ranuras. Doblar la eñe en ene las metía en la misma, y
	# lo pilló `TestPartida.test_el_mismo_nombre_es_la_misma_ranura`.
	const PROHIBIDOS := "<>:\"/\\|?*."
	var limpio := ""
	for caracter: String in nombre.to_lower():
		if PROHIBIDOS.contains(caracter) or caracter.unicode_at(0) < 32 \
				or caracter == " ":
			if not limpio.ends_with("_"):
				limpio += "_"
		else:
			limpio += caracter
	return limpio.lstrip("_").rstrip("_")


## Escribe la cabecera con lo que la lista necesita para elegir.
static func _escribir_cabecera(donde: String, nombre: String) -> String:
	var mapa := Guardado.leer()
	var cabecera := {
		"version": VERSION,
		"nombre": nombre,
		"cuando": int(Time.get_unix_time_from_system()),
		"sitio": Guardado.sitio_de_la_banda(),
		"jornada": int(mapa.get("jornada", 0)),
		"anyo": int(mapa.get("anyo", GameState.year)),
		"estacion": int(mapa.get("estacion", int(GameState.season))),
		"poblacion": int(mapa.get("poblacion", 0)),
		"mapas": Guardado.cabeceras().size(),
	}
	var ruta := donde.path_join(CABECERA)
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero == null:
		return "no se puede escribir en %s" % ruta
	fichero.store_var(cabecera, true)
	fichero.close()
	return ""


## Copia los mapas de una carpeta a otra, y el apunte de cuál fue el último.
static func _copiar_mapas(desde: String, hasta: String) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(hasta))
	var dir := DirAccess.open(desde)
	if dir == null:
		return ""  # una partida sin mapas todavía: no es un error
	for nombre: String in dir.get_files():
		if nombre == CABECERA:
			continue  # la cabecera se escribe nueva, no se arrastra
		var error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(desde.path_join(nombre)),
			ProjectSettings.globalize_path(hasta.path_join(nombre)))
		if error != OK:
			return "no se ha podido copiar %s" % nombre
	return ""


## Deja una carpeta vacía, creándola si no estaba. No borra la carpeta misma.
static func _vaciar(cual: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cual))
	var dir := DirAccess.open(cual)
	if dir == null:
		return
	for nombre: String in dir.get_files():
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(cual.path_join(nombre)))
