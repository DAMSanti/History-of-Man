extends SceneTree
## Guardar la PARTIDA a media jornada, cerrar el juego, abrirla y seguir.
##
## Spec: `docs/INTERFAZ.md` §7, criterios 5 y 6. `TestPartida` comprueba los
## ficheros —qué se copia, qué se lee, qué se rechaza— pero no puede comprobar
## lo que sólo pasa **entre dos procesos**: que la partida cargada siga dando la
## misma firma jornada a jornada que la que no se cerró nunca.
##
## Es hermana de [GuardadoProbe], que hace lo mismo con el estado de UN MAPA.
## Aquí se guarda por [Partidas], o sea la carpeta entera con su cabecera, y
## **a media jornada**: el criterio 5 dice «guardar a media jornada», que es
## justo el caso que un guardado atado al cambio de día no ejercita.
##
## Se corre dos veces:
##
##   MODO=guardar   juega 3 jornadas, espera a media jornada, GUARDA la partida
##                  y sigue 5 apuntando su firma
##   MODO=cargar    carga esa partida y juega esas mismas 5, apuntando la suya
##
## Las dos listas tienen que salir iguales.
##
##   FIRMAS=<ruta>  dónde se escriben (por defecto user://firmas_partida_<modo>.txt)

const SITE_ID := 56

## Cuántas jornadas se juegan antes de guardar, y cuántas después.
const ANTES := 3
const DESPUES := 5

## Cómo se llama la partida que usa la sonda. Con nombre fijo para que el
## segundo proceso sepa cuál cargar.
const NOMBRE := "Sonda de partida"


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Sus propias carpetas: una sonda no escribe en las partidas del jugador.
	Partidas.raiz = "user://sondas/partidas"
	Partidas.borrador = "user://sondas/partida_abierta"
	Guardado.carpeta = Partidas.borrador

	var modo := OS.get_environment("MODO")
	if modo != "guardar" and modo != "cargar":
		print("MODO=guardar o MODO=cargar")
		quit(1)
		return

	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	if modo == "cargar":
		var cual := ""
		for entrada: Dictionary in Partidas.lista():
			if String(entrada.get("nombre", "")) == NOMBRE:
				cual = String(entrada["id"])
		if cual.is_empty():
			print("no hay partida de sonda: corre antes MODO=guardar")
			quit(1)
			return
		var fallo := Partidas.cargar(cual, sitios)
		if not fallo.is_empty():
			print("no se ha podido cargar: %s" % fallo)
			quit(1)
			return
		Expedition.retomando = true
	else:
		Partidas.nueva()
		_preparar_una_nueva(sitios)

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	var sim: SettlementSim = demo.sim if "sim" in demo else null
	var ui: GameUI = demo.ui if "ui" in demo else null
	if sim == null or ui == null:
		print("sin simulacion")
		quit(1)
		return
	print("modo %s · jornada de arranque %d · hora %.2f · semilla %d" % [
		modo, sim.day, sim.hour, sim.game_seed])

	sim.time_scale = 5.0

	# La firma, con el paso CERRADO, por lo mismo que en [GuardadoProbe]: en un
	# mismo fotograma corren varios pasos, y tomarla fuera de ahí hace que dos
	# corridas iguales parezcan distintas.
	var firmas: Array[String] = []
	var toca := {"v": false}
	sim.day_passed.connect(func(_d: int) -> void: toca["v"] = true)
	sim.paso_cerrado.connect(func(_d: int) -> void:
		if not bool(toca["v"]):
			return
		toca["v"] = false
		var huella := FirmaDiaria.de(sim, demo.herds, demo._caves)
		firmas.append("%d %s" % [sim.day, huella.firma])
		print("   jornada %d · %.2f h · %s" % [sim.day, sim.hour,
			huella.firma.substr(0, 16)]))

	if modo == "guardar":
		await _jugar(sim, ui, ANTES)
		# A MEDIA JORNADA, que es el caso que pide el criterio 5: se deja correr
		# hasta pasado el mediodía y se guarda ahí, con el reloj parado, que es
		# lo que hace el modal. Ver [MenuDelJuego.abrir].
		while sim.hour < 13.0:
			await process_frame
			ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
		sim.time_scale = 0.0
		var fallo := Partidas.guardar(NOMBRE, sim, demo.herds, demo._caves)
		print("guardado en la jornada %d (%.2f h): %s" % [sim.day, sim.hour,
			"bien" if fallo.is_empty() else fallo])
		sim.time_scale = 5.0
		firmas.clear()
	await _jugar(sim, ui, DESPUES)

	var ruta := OS.get_environment("FIRMAS")
	if ruta.is_empty():
		ruta = "user://firmas_partida_%s.txt" % modo
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero != null:
		fichero.store_string("\n".join(firmas))
		fichero.close()
		print("firmas en %s" % ProjectSettings.globalize_path(ruta))
	print("mapas en la partida: %d" % Guardado.cabeceras().size())
	quit()


## Juega `dias` jornadas contestando lo que salga, como el jugador.
func _jugar(sim: SettlementSim, ui: GameUI, dias: int) -> void:
	var hasta := sim.day + dias
	while sim.day < hasta:
		await process_frame
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)


func _preparar_una_nueva(sites: SiteSet) -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))
