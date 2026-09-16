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
const VERSION := 2

## Las versiones que se siguen abriendo. La 1 es la de una sola banda: su
## fichero es igual campo a campo, y lo que la 2 añade —más campamentos y la
## cabecera de la partida, [PARTIDA]— sencillamente no está.
const VERSIONES_QUE_SE_LEEN: Array[int] = [1, 2]

## La cabecera de la partida: la fecha de todos y los grupos de camino, que no
## son de ningún mapa. SISTEMAS §23, tarea 12.
const PARTIDA := "partida.sav"

## **UN ESTADO, EL DEL MAPA DE LA BANDA.** El 2026-09-13 el usuario perdió su
## partida —salió al mapa regional, eligió su sitio, pulsó F y se le fundó una
## nueva encima— y se decidió un estado por mapa: «todas deben guardar su
## estado». El 2026-09-14 cambió: entrar en otro mapa no trae a la banda, es una
## VISITA, y una visita no tiene estado que guardar. Ver [sitio_de_la_banda].
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


## Guarda la partida. Devuelve el error, o vacío si ha ido bien.
##
## Con varios campamentos guarda también **los demás y la cabecera de la
## partida**: guardar es guardar la partida, no el mapa que se mira —si no, un
## campamento que no se mira volvería de un autoguardado de hace días—.
static func guardar(sim: SettlementSim, fauna: WildlifeHerds = null,
		cuevas: Array = []) -> String:
	if sim == null:
		return "no hay partida que guardar"
	var sitio := _sitio_de_la_partida()
	if sitio < 0:
		return "no se sabe qué mapa se está jugando"
	# UN MAPA DE VISITA NO SE GUARDA. Ver [sitio_de_la_banda]. Uno con campamento
	# sí, aunque no sea el primero.
	var banda := sitio_de_la_banda()
	if banda >= 0 and sitio != banda and Campamentos.de_sitio(sitio) == null:
		return "es un mapa de visita: la banda está en el mapa %d" % banda
	var fallo := _escribir(sim, fauna, cuevas, sitio, Expedition.heightmap_path,
		Expedition.region_offset)
	if not fallo.is_empty():
		return fallo
	return _guardar_los_demas(sim)


## Un campamento a su fichero, `sitio_<n>.sav`.
static func _escribir(sim: SettlementSim, fauna: WildlifeHerds, cuevas: Array,
		sitio: int, relieve: String, recuadro: Vector2) -> String:
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
		"sitio": sitio,
		"descubierto": GameState.discovered.keys(),
		# Lo avistado desde las cumbres, que es de la comarca como lo descubierto.
		"avistado": GameState.avistados.keys(),
		# Lo que se ha visto de la comarca, que como lo descubierto es de la
		# partida y no del mapa: se suma al cargar. Ver [NieblaRegional].
		"niebla": GameState.niebla.a_datos() if GameState.niebla != null else {},
		"era": int(GameState.era),
		"cota_del_mar": GameState.sea_level_m,
		"poblacion": sim.population(),
		"comida": sim.store.food_rations(),
		"relieve": relieve,
		"recuadro": recuadro,
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
		# El filtro de alfileres del jugador. Ver [GameState.marcadores_visibles].
		"marcadores": GameState.marcadores_visibles.duplicate(),
		# En qué orden daba sus pasos: el primero publica la fecha, y la barrera
		# junta en ese orden. Retomar en otro orden sería otra partida.
		"orden": _orden_de(sim),
	}
	return _a_fichero(ruta_de(sitio), datos)


static func _a_fichero(ruta: String, datos: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero == null:
		return "no se puede escribir en %s" % ruta
	fichero.store_var(datos, true)
	fichero.close()
	return ""


static func _orden_de(sim: SettlementSim) -> int:
	for i in range(Campamentos.vivos.size()):
		if Campamentos.vivos[i].sim == sim:
			return i
	return 0


## Los campamentos que no son el de la escena, y la cabecera de la partida. Sin
## reloj de la partida no hay más que un campamento y no se escribe nada.
static func _guardar_los_demas(escena: SettlementSim) -> String:
	if Campamentos.reloj == null or not is_instance_valid(Campamentos.reloj):
		return ""
	for campamento: Campamento in Campamentos.vivos:
		if campamento.sim == null or campamento.sim == escena:
			continue
		var fallo := _escribir(campamento.sim, campamento.herds, campamento.caves,
			campamento.sitio.id, campamento.relieve, campamento.recuadro)
		if not fallo.is_empty():
			return fallo
	var viajes: Array = []
	for viaje: Viaje in Campamentos.viajes:
		var datos := viaje.a_datos()
		if datos.is_empty():
			return "un grupo de camino a %s no se puede recorrer" % viaje.hasta_nombre
		viajes.append(datos)
	var reloj := Campamentos.reloj
	return _a_fichero(carpeta.path_join(PARTIDA), {
		"version": VERSION,
		"dia": reloj.dia,
		"hora": reloj.hora,
		"dia_de_estacion": reloj.dia_de_estacion,
		"estacion": int(GameState.season),
		"anyo": GameState.year,
		"viajes": viajes,
	})


## La cabecera de la partida, o vacío si no la hay: una partida de un campamento,
## o de antes de la versión 2.
static func leer_la_partida() -> Dictionary:
	var ruta := carpeta.path_join(PARTIDA)
	if not FileAccess.file_exists(ruta):
		return {}
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		return {}
	var datos: Variant = fichero.get_var(true)
	fichero.close()
	if not (datos is Dictionary) or int((datos as Dictionary).get("version", -1)) != VERSION:
		return {}
	return datos


## Monta y vuelca los campamentos guardados que no son el de la escena, sin
## mirarlos, y los grupos que iban de camino. Devuelve los errores.
##
## Va DESPUÉS de dar de alta el de la escena: el primero de la lista publica la
## fecha, y se respeta el orden en que se guardaron —ver `orden`—. Un fichero de
## la versión 1 no se monta aquí: aquella partida tenía una sola banda, la de la
## escena, y los demás mapas eran visitas o bandas sueltas de antes.
static func retomar_los_demas(arbol: SceneTree, sitios: SiteSet,
		escena: int) -> Array[String]:
	var errores: Array[String] = []
	var guardados: Array[Dictionary] = []
	for cabecera: Dictionary in cabeceras():
		var id := int(cabecera.get("sitio", -1))
		if int(cabecera.get("version", 1)) < 2 or id == escena \
				or Campamentos.de_sitio(id) != null:
			continue
		guardados.append(cabecera)
	guardados.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("orden", 0)) < int(b.get("orden", 0)))
	for cabecera: Dictionary in guardados:
		var id := int(cabecera.get("sitio", -1))
		var sitio: Site = null
		for s: Site in sitios.sites:
			if s.id == id:
				sitio = s
		var campamento := Campamento.montar(arbol, sitio,
			int(cabecera.get("poblacion", 0)), float(cabecera.get("comida", 0.0)))
		if campamento == null:
			errores.append("el campamento del sitio %d no se puede montar" % id)
			continue
		errores.append_array(volcar(leer(id), campamento.sim, campamento.herds,
			campamento.caves))
		campamento.mirar_las_cumbres()
		Campamentos.alta(arbol, campamento)
		Campamentos.dejar_de_mirar(campamento)
	var partida := leer_la_partida()
	if partida.is_empty():
		return errores
	for datos: Dictionary in (partida.get("viajes", []) as Array):
		var viaje := Viaje.de_datos(datos)
		if viaje == null:
			errores.append("un grupo de camino no se puede leer")
			continue
		Campamentos.viajes.append(viaje)
	# LA FECHA DE LA PARTIDA, la guardada: si el primer campamento se quedó vacío,
	# la suya es la del día en que se fue todo el mundo.
	if Campamentos.reloj != null and is_instance_valid(Campamentos.reloj):
		Campamentos.reloj.dia = int(partida.get("dia", Campamentos.reloj.dia))
		Campamentos.reloj.hora = float(partida.get("hora", Campamentos.reloj.hora))
		Campamentos.reloj.dia_de_estacion = int(partida.get("dia_de_estacion",
			Campamentos.reloj.dia_de_estacion))
	return errores


## Qué emplazamiento se está jugando: el del traspaso, y si no el de la banda.
static func _sitio_de_la_partida() -> int:
	if Expedition.site != null:
		return Expedition.site.id
	return GameState.home.id if GameState.home != null else -1


## EL MAPA DONDE VIVE LA BANDA, o -1 si todavía no hay ninguno.
##
## **La banda vive en UN mapa**, el primero: decisión del usuario del 2026-09-14,
## «cuando voy al mapa regional y entro en otro mapa, no debe traer a mi banda,
## sólo cargar y mostrarme el mapa; sólo asienta la banda en el primer mapa al
## principio del juego». Hasta entonces entrar en un mapa sin estado fundaba una
## banda nueva ahí, y la partida acababa con tres. Los demás mapas se VISITAN y no
## se guardan —ver [guardar]—. Migrar a la gente a otro mapa pide un sistema que
## no existe todavía.
##
## No se apunta en ningún fichero: con las visitas sin guardar, el único mapa con
## estado ES el de la banda. Para las partidas de antes, que tienen banda en
## varios, es el que lleva más jornadas —el que se fundó primero y se jugó—.
static func sitio_de_la_banda() -> int:
	var mejor := -1
	var mas := -1
	for cabecera: Dictionary in cabeceras():
		var jornada := int(cabecera.get("jornada", 0))
		if jornada > mas:
			mas = jornada
			mejor = int(cabecera.get("sitio", -1))
	return mejor


## Si ese mapa tiene estado guardado. Sin sitio, el de la banda.
static func hay_partida(sitio: int = -1) -> bool:
	return not leer(sitio).is_empty()


## El estado guardado de un mapa, o vacío si no hay o no se puede leer. Sin
## sitio, el de la banda.
##
## **Una versión distinta devuelve vacío**: un fichero de otra versión del juego
## no promete cargar, y cargarlo a medias sería peor que no cargarlo.
static func leer(sitio: int = -1) -> Dictionary:
	if sitio < 0:
		sitio = sitio_de_la_banda()
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
	if not VERSIONES_QUE_SE_LEEN.has(int(guardado.get("version", -1))):
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
	# Lo avistado, igual: se suma. Un guardado de antes del 2026-09-16 no lo trae.
	for id: Variant in (guardado.get("avistado", []) as Array):
		GameState.avistados[int(id)] = true
	# LA NIEBLA, igual: se suma. Un guardado de antes del 2026-09-14 no la trae, y
	# entonces se ve lo que la partida ya tuviera.
	var niebla: Dictionary = guardado.get("niebla", {})
	if not niebla.is_empty():
		GameState.la_niebla().sumar_datos(niebla)
	else:
		# UN GUARDADO DE ANTES DE LA NIEBLA trae sitios descubiertos y ninguna
		# niebla: sin esto, al abrirlo quedaban todos tapados. Se levanta el
		# recuadro de cada uno, que es lo que la banda conocería de ellos.
		# Decisión de compatibilidad del 2026-09-14.
		for site: Site in sitios.sites:
			if GameState.is_discovered(site):
				GameState.levantar_niebla({"forma": "recuadro", "lon": site.lon,
					"lat": site.lat, "lado": float(Expedition.local_size_m)}, sitios)
	GameState.started = true
	# Un guardado de antes del 2026-09-14 no lo trae: se deja lo que hubiera.
	if guardado.has("marcadores"):
		GameState.marcadores_visibles.clear()
		var marcadores: Dictionary = guardado["marcadores"]
		for familia: Variant in marcadores:
			GameState.marcadores_visibles[int(familia)] = bool(marcadores[familia])
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
