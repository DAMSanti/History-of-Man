extends SceneTree
## Guardar, cerrar el juego, abrirlo y seguir jugando la misma partida.
##
## Frente 15 de EPOCA_01 §10.1, tanda 3. `TestGuardado` comprueba el fichero
## —que se lee, que una versión distinta se rechaza, que la firma sobrevive a la
## ida y la vuelta— pero no puede comprobar lo que sólo pasa **entre dos
## procesos**: que la partida cargada siga dando la misma firma jornada a
## jornada que la que no se guardó nunca.
##
## Se corre dos veces:
##
##   MODO=guardar   juega 3 jornadas, GUARDA, y sigue 5 apuntando su firma
##   MODO=cargar    retoma lo guardado y juega esas mismas 5, apuntando la suya
##
## Las dos listas tienen que salir iguales. Si no, lo guardado no era la partida
## entera, y la diferencia dice en qué jornada se separan —lo mismo que hace
## `Cotejo` con dos corridas—.
##
##   FIRMAS=<ruta>  dónde se escriben (por defecto user://firmas_<modo>.txt)

const SITE_ID := 56

## Cuántas jornadas se juegan antes de guardar, y cuántas después.
const ANTES := 3
const DESPUES := 5


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Su propia carpeta: una sonda no escribe en los mapas del jugador, y el
	# mapa que usa —el 56— es el de arranque por defecto. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/mapas"
	var modo := OS.get_environment("MODO")
	if modo != "guardar" and modo != "cargar":
		print("MODO=guardar o MODO=cargar")
		quit(1)
		return

	if modo == "cargar":
		var guardado := Guardado.leer()
		if guardado.is_empty():
			print("no hay partida guardada: corre antes MODO=guardar")
			quit(1)
			return
		var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
		if not Guardado.preparar_la_escena(guardado, sitios):
			print("la partida guardada no se puede preparar")
			quit(1)
			return
		Expedition.retomando = true
	else:
		_preparar_una_nueva()

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
	print("modo %s · jornada de arranque %d · semilla %d" % [modo, sim.day, sim.game_seed])

	sim.time_scale = 5.0

	# LA FIRMA SE TOMA CON EL PASO CERRADO, y no cuando la jornada cambia de
	# número: `paso_cerrado` es «el único límite limpio de la partida» —SPECS
	# §3.2—, y en un mismo fotograma pueden correr varios pasos. Tomándola al
	# salir del bucle de espera, la hora exacta dependía de cuántos pasos
	# hubieran cabido en ese cuadro: **dos corridas del mismo brazo daban firmas
	# distintas**, y parecía que lo roto era el guardado.
	var firmas: Array[String] = []
	var toca := {"v": false}
	sim.day_passed.connect(func(_d: int) -> void: toca["v"] = true)
	sim.paso_cerrado.connect(func(_d: int) -> void:
		if not bool(toca["v"]):
			return
		toca["v"] = false
		var huella := FirmaDiaria.de(sim, demo.herds, demo._caves)
		firmas.append("%d %s" % [sim.day, huella.firma])
		var detalle := FileAccess.open("user://detalle_%s_%d.json" % [modo, sim.day],
			FileAccess.WRITE)
		if detalle != null:
			detalle.store_string(JSON.stringify(huella.detalle, "  ", true))
			detalle.close()
		print("   jornada %d · %.2f h · %s" % [sim.day, sim.hour,
			huella.firma.substr(0, 16)]))

	if modo == "guardar":
		await _jugar(sim, ui, ANTES)
		var fallo := Guardado.guardar(sim, demo.herds, demo._caves)
		print("guardado en la jornada %d (%.2f h): %s" % [sim.day, sim.hour,
			"bien" if fallo.is_empty() else fallo])
		firmas.clear()
	await _jugar(sim, ui, DESPUES)

	var ruta := OS.get_environment("FIRMAS")
	if ruta.is_empty():
		ruta = "user://firmas_%s.txt" % modo
	var fichero := FileAccess.open(ruta, FileAccess.WRITE)
	if fichero != null:
		fichero.store_string("\n".join(firmas))
		fichero.close()
		print("firmas en %s" % ProjectSettings.globalize_path(ruta))
	quit()


## Juega `dias` jornadas contestando lo que salga, como el jugador.
func _jugar(sim: SettlementSim, ui: GameUI, dias: int) -> void:
	var hasta := sim.day + dias
	while sim.day < hasta:
		await process_frame
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)


func _preparar_una_nueva() -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
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
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
