class_name Guardado
extends RefCounted
## La partida guardada en disco, y lo que hace falta para retomarla.
##
## FASE A3 del ROADMAP y frente 15 de EPOCA_01 §10.1, tanda 3. Hasta el
## 2026-09-13 al volver al mapa regional sólo viajaban la población y la comida:
## el asentamiento se perdía, y cerrar el juego lo perdía todo.
##
## **No es la instantánea de las sondas, aunque use su recorrido.**
## [Instantanea] es un instrumento de medida —SPECS §6.4— que no promete
## sobrevivir a un cambio de esquema. Esto **sí** promete una cosa y sólo una:
## que un fichero de ESTA versión se carga entero, y que uno de otra **se
## rechaza avisando** en vez de cargarse a medias. Por eso tiene su propia
## cabecera y su propia versión.
##
## Lo que guarda, en dos piezas:
##
## - **La simulación entera**, por el recorrido de [Instantanea]: la banda, la
##   despensa, el utillaje, los parajes, las veredas, el estado del azar.
## - **Lo que cruza escenas y ella no guarda**: de [GameState], qué cueva es la
##   de la banda, qué se ha descubierto de la comarca, la era y la cota del mar;
##   de [Expedition], el relieve local y el recuadro. Sin eso, la escena nueva
##   no se puede montar igual, y volcar la partida encima sería volcarla sobre
##   otro valle.

## Sube cuando lo guardado deja de poder leerse. Un fichero de otra versión no
## se carga: se dice y se empieza de nuevo, que es lo que la spec acepta.
const VERSION := 1

## **UN ESTADO POR MAPA**, no uno por partida. Decidido por el usuario el
## 2026-09-13 al perder su partida: salió al mapa regional, eligió su sitio,
## pulsó F y se le fundó una nueva encima. «El jugador puede tener acceso a
## TODAS las zonas, todas deben guardar su estado: salir al mapa regional,
## visitar cualquier mapa, volver al suyo, y que todo siga igual.» Entrar en un
## mapa ya visitado lo retoma; entrar en uno nuevo no toca a los demás.
##
## Esto es el ESTADO DE LOS MAPAS, que se mantiene solo durante la partida. El
## GUARDADO DE PARTIDA —para cerrar el juego y seguir otro día cuando se quiera—
## es otra cosa, y se desarrolla más adelante.
const CARPETA := "user://mapas"

## Dónde se guarda DE VERDAD. Es `CARPETA` en el juego, y otra cosa en las
## pruebas y las sondas.
##
## **Esto existe porque la suite borró la partida del jugador.** Hasta el
## 2026-09-13 había una ruta fija, y `TestGuardado` guardaba y llamaba a
## `borrar()` sobre el MISMO fichero que usa el juego: cada pasada de la suite
## borraba el guardado real, y el usuario perdió su partida. Una prueba no toca
## nunca lo del jugador: [TestGuardado] y `GuardadoProbe` apuntan esto a su
## propia carpeta antes de nada.
static var carpeta: String = CARPETA


## El fichero del estado de un emplazamiento.
static func ruta_de(sitio: int) -> String:
	return carpeta.path_join("sitio_%d.sav" % sitio)


## Dónde se apunta cuál fue el último mapa jugado, para el botón de volver.
static func _ultimo() -> String:
	return carpeta.path_join("ultimo.txt")


## Guarda la partida. Devuelve el error, o vacío si ha ido bien.
static func guardar(sim: SettlementSim, fauna: WildlifeHerds = null,
		cuevas: Array = []) -> String:
	if sim == null:
		return "no hay partida que guardar"
	var foto := Instantanea.tomar(sim, fauna, cuevas)
	if not foto.errores.is_empty():
		# Un `Callable` en el estado, por ejemplo: lo guardado no sería la
		# partida, así que no se guarda nada. Ver [Instantanea].
		return "la partida no se puede recorrer: %s" % ", ".join(foto.errores)
	var datos := {
		"version": VERSION,
		"foto": foto.bytes(),
		# EL EMPLAZAMIENTO QUE SE ESTÁ JUGANDO, que es el del traspaso y no
		# necesariamente el de `GameState.home`: sólo lo pone `GameState.begin`,
		# y a la capa local se puede llegar sin pasar por ahí -una sonda, una
		# escena montada a mano-. Guardar -1 dejaba la partida imposible de
		# retomar sin decir por qué.
		"sitio": _sitio_de_la_partida(),
		"descubierto": GameState.discovered.keys(),
		"era": int(GameState.era),
		"cota_del_mar": GameState.sea_level_m,
		"poblacion": sim.population(),
		"comida": sim.store.food_rations(),
		"relieve": Expedition.heightmap_path,
		"recuadro": Expedition.region_offset,
		"lado": Expedition.local_size_m,
		"semilla": sim.game_seed,
		"jornada": sim.day,
		# LO QUE SE SABE, en la cabecera: el mapa regional no tiene simulación y
		# es lo único que puede leer para la ficha de un sitio y el panel de la
		# banda. Ver [RegionMap.ficha_del_sitio] y [RegionMap.panel_de_la_banda].
		"trato": sim.contacto.trato.duplicate(),
		"cuevas_exploradas": _cuantas_exploradas(sim),
		"cuevas_pintables": _cuantas_pintables(sim),
		"pintada": sim.paintings.size() >= SettlementSim.CUEVA_PINTADA_MINIMO,
		"estacion": int(GameState.season),
		"anyo": GameState.year,
	}
	var sitio := _sitio_de_la_partida()
	if sitio < 0:
		return "no se sabe qué mapa se está jugando"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	var ruta := ruta_de(sitio)
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero == null:
		return "no se puede escribir en %s" % ruta
	fichero.store_var(datos, true)
	fichero.close()
	var ultimo := FileAccess.open(_ultimo(), FileAccess.WRITE)
	if ultimo != null:
		ultimo.store_string(str(sitio))
		ultimo.close()
	return ""


## Qué emplazamiento se está jugando: el del traspaso, y si no el de la banda.
static func _sitio_de_la_partida() -> int:
	if Expedition.site != null:
		return Expedition.site.id
	return GameState.home.id if GameState.home != null else -1


## Si ese mapa tiene estado guardado. Sin sitio, el último que se jugó.
static func hay_partida(sitio: int = -1) -> bool:
	return not leer(sitio).is_empty()


## El último mapa que se jugó, o -1 si ninguno.
static func ultimo_sitio() -> int:
	if not FileAccess.file_exists(_ultimo()):
		return -1
	var fichero := FileAccess.open(_ultimo(), FileAccess.READ)
	if fichero == null:
		return -1
	var texto := fichero.get_as_text().strip_edges()
	fichero.close()
	return int(texto) if texto.is_valid_int() else -1


## El estado guardado de un mapa, o vacío si no hay o no se puede leer. Sin
## sitio, el del último que se jugó.
##
## **Una versión distinta devuelve vacío**: un fichero de otra versión del juego
## no promete cargar, y cargarlo a medias sería peor que no cargarlo.
static func leer(sitio: int = -1) -> Dictionary:
	if sitio < 0:
		sitio = ultimo_sitio()
	if sitio < 0:
		return {}
	var ruta := ruta_de(sitio)
	if not FileAccess.file_exists(ruta):
		return {}
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		return {}
	var datos: Variant = fichero.get_var(true)
	fichero.close()
	if not (datos is Dictionary):
		return {}
	var guardado: Dictionary = datos
	if int(guardado.get("version", -1)) != VERSION:
		return {}
	return guardado


## Deja `Expedition` y `GameState` como estaban, para poder montar la escena
## igual. Lo llama el mapa regional antes de entrar. Devuelve si ha podido.
static func preparar_la_escena(guardado: Dictionary, sitios: SiteSet) -> bool:
	if guardado.is_empty() or sitios == null:
		return false
	var sitio: Site = null
	for s: Site in sitios.sites:
		if s.id == int(guardado.get("sitio", -1)):
			sitio = s
	if sitio == null:
		return false
	GameState.home = sitio
	GameState.era = int(guardado.get("era", int(Site.Era.PALEOLITICO))) as Site.Era
	GameState.sea_level_m = float(guardado.get("cota_del_mar", -120.0))
	GameState.population = int(guardado.get("poblacion", GameState.START_POPULATION))
	GameState.food = float(guardado.get("comida", 0.0))
	# LO DESCUBIERTO ES DE LA COMARCA, no de un mapa: se SUMA a lo que ya se
	# sabe, no lo pisa. Si se reemplazara, entrar en el mapa A olvidaría lo que
	# la expedición del mapa B descubrió después de guardar A.
	for id: Variant in (guardado.get("descubierto", []) as Array):
		GameState.discovered[int(id)] = true
	GameState.started = true
	Expedition.site = sitio
	Expedition.heightmap_path = String(guardado.get("relieve", ""))
	Expedition.region_offset = guardado.get("recuadro", Vector2.ZERO) as Vector2
	Expedition.local_size_m = int(guardado.get("lado", 4096))
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = GameState.era
	return true


## La semilla con la que se jugaba, para que la escena nueva nazca igual.
static func semilla_de(guardado: Dictionary) -> int:
	return int(guardado.get("semilla", 0))


## Vuelca lo guardado sobre una escena recién montada. Devuelve los errores.
static func volcar(guardado: Dictionary, sim: SettlementSim,
		fauna: WildlifeHerds = null, cuevas: Array = []) -> Array[String]:
	var vacio: Array[String] = []
	if guardado.is_empty() or sim == null:
		vacio.append("no hay nada que volcar")
		return vacio
	var foto := Instantanea.desde_bytes(guardado.get("foto", PackedByteArray()))
	if foto == null:
		vacio.append("la instantánea guardada no se puede leer")
		return vacio
	return foto.volcar(sim, fauna, cuevas)


## Cuántas cuevas del mapa se han explorado, y cuántas tienen pared.
static func _cuantas_exploradas(sim: SettlementSim) -> int:
	var n := 0
	for sabido: Dictionary in sim.exploracion._sabido.values():
		if bool(sabido.get("explorada", false)):
			n += 1
	return n


static func _cuantas_pintables(sim: SettlementSim) -> int:
	var n := 0
	for sabido: Dictionary in sim.exploracion._sabido.values():
		if bool(sabido.get("pintable", false)):
			n += 1
	return n


## Las cabeceras de todos los mapas guardados, sin la foto: lo que el mapa
## regional necesita para decir qué se sabe y en qué jornada va cada uno.
static func cabeceras() -> Array[Dictionary]:
	var salida: Array[Dictionary] = []
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return salida
	for nombre: String in dir.get_files():
		if not nombre.begins_with("sitio_") or not nombre.ends_with(".sav"):
			continue
		var numero := nombre.trim_prefix("sitio_").trim_suffix(".sav")
		if not numero.is_valid_int():
			continue
		var guardado := leer(int(numero))
		if guardado.is_empty():
			continue
		guardado.erase("foto")
		salida.append(guardado)
	return salida


## Borra el estado de un mapa, o de todos si no se dice cuál. Lo usan las
## pruebas: en la partida los mapas no se borran, se retoman.
static func borrar(sitio: int = -1) -> void:
	if sitio >= 0:
		if FileAccess.file_exists(ruta_de(sitio)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_de(sitio)))
		return
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	for nombre: String in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(carpeta.path_join(nombre)))
