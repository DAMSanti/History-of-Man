extends SceneTree
## Qué le pasa de verdad a una decisión en una sonda.
##
## Tarea 1 de docs/specs/LO_MISMO_MAS_DEPRISA.md. La interfaz se engancha a
## `moment_raised` antes que cualquier sonda y, ante una decisión, para el
## reloj; ningún `on_pick` lo devuelve —sólo el botón de la tarjeta—. Sobre el
## papel `TironAnualProbe` y `AnoProbe` tendrían que colgarse en la primera
## decisión, y no se colgaban. Esto lo mide en tres tiempos:
##
##   1. las decisiones reales de la primera jornada, contestadas como las
##      contestan las sondas (llamando a `on_pick` a pelo);
##   2. una decisión de prueba lanzada DENTRO de un paso —al cerrar la
##      jornada— con la tarjeta del arranque todavía abierta;
##   3. la misma, con las tarjetas ya cerradas, que es como la ve un jugador.
##
## En cada una: la velocidad al llegar a la sonda y después de contestar, si
## hay tarjeta abierta, cuántas esperan en cola, y cuántos pasos se dan en el
## resto de ese fotograma. Los pasos se cuentan con el propio cepo
## ([Cronometro]), que lleva la cuenta de «paso de simulacion» por fotograma.

const SITE_ID := 56
const VEL := 20.0

## Cuántos fotogramas se espera, con el reloj parado, a que alguien lo devuelva.
const ESPERA := 60

var sim: SettlementSim
var ui: GameUI
var _primero := 0
var _tiempo := 1
var _pasos_al_saltar := -1
var _cuadro_del_salto := -1
var _medido_el_salto := false
var _escogido := 0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit(1)
		return
	sim = demo.sim
	ui = demo.ui

	for nodo: Node in get_root().find_children("*", "PerformanceOverlay", true, false):
		(nodo as CanvasLayer).visible = false
	# Sólo para contar pasos: con un límite imposible no se caza ningún pico.
	Cronometro.limite_ms = 1.0e9
	Cronometro.activo = true
	Cronometro.reinicia()

	print("")
	print("=== DECISIONES EN UNA SONDA ===")
	print("al arrancar: tarjeta %s «%s» · en cola %d · velocidad guardada %.1f · velocidad %.1f" % [
		"ABIERTA" if ui._moment_card != null else "cerrada", _titulo_abierto(),
		ui._moments.size(), ui._speed_before_moment, sim.time_scale])

	sim.moment_raised.connect(_on_moment)
	sim.day_passed.connect(_on_day)
	sim.assign_default_jobs()
	sim.time_scale = VEL
	_primero = sim.day
	print("")
	print("--- 1. las decisiones reales de la primera jornada ---")

	var parados := 0
	while sim.day < _primero + 4:
		await process_frame
		var cuadro := Engine.get_process_frames()
		# Aquí todavía no ha abierto `DemoMain` el fotograma nuevo, así que la
		# cuenta del cepo es la del fotograma anterior, entero.
		if _cuadro_del_salto >= 0 and cuadro == _cuadro_del_salto + 1:
			var total := int(Cronometro._veces.get("paso de simulacion", 0))
			var el_suyo := _pasos_al_saltar + 1
			print("      en ese fotograma: %d pasos; el de la decisión era el %d, así que después se dieron %d con la velocidad a %.1f" % [
				total, el_suyo, total - el_suyo, sim.time_scale])
			_cuadro_del_salto = -1
			_medido_el_salto = true
		if _tiempo == 3 and _medido_el_salto:
			if sim.time_scale > 0.0:
				print("      la velocidad volvió a %.1f tras %d fotogramas parada" % [
					sim.time_scale, parados])
				break
			parados += 1
			if parados >= ESPERA:
				print("      %d fotogramas después la velocidad sigue en %.1f: nadie la devuelve" % [
					parados, sim.time_scale])
				print("      (una sonda que conteste así se queda colgada)")
				break

	print("")
	print("--- al terminar ---")
	print("tarjeta %s «%s» · en cola %d · decisiones de prueba contestadas %d" % [
		"ABIERTA" if ui._moment_card != null else "cerrada", _titulo_abierto(),
		ui._moments.size(), _escogido])
	Cronometro.activo = false
	quit()


func _on_moment(moment: Moment) -> void:
	var prueba := moment.title == "PRUEBA"
	var linea := "   dia %d %05.2f h · %s%s · al llegar a la sonda: velocidad %.1f · tarjeta %s · en cola %d" % [
		sim.day, sim.hour, Moment.Kind.keys()[moment.kind],
		" (DECISION)" if moment.is_decision() else "", sim.time_scale,
		"abierta" if ui._moment_card != null else "cerrada", ui._moments.size()]
	if prueba:
		# El paso en curso está abierto y aún no cuenta: los cerrados son los
		# anteriores a este dentro del mismo fotograma.
		_pasos_al_saltar = int(Cronometro._veces.get("paso de simulacion", 0))
		_cuadro_del_salto = Engine.get_process_frames()
	if moment.is_decision():
		if prueba and _tiempo == 3:
			# Por la vía del jugador, `BarraSuperior.elegir`: la de la tarea 7.
			ui.barra.elegir(0)
			linea += " · tras elegir por la vía del jugador: velocidad %.1f" % sim.time_scale
		else:
			# Como contestaban antes `TironAnualProbe` y `AnoProbe`: a pelo.
			var index := 1 if moment.kind == Moment.Kind.BERREA else 0
			(moment.options[index]["on_pick"] as Callable).call()
			linea += " · tras contestar a pelo: velocidad %.1f" % sim.time_scale
	print(linea)


func _on_day(day: int) -> void:
	if day == _primero + 1:
		_tiempo = 2
		print("")
		print("--- 2. decisión de prueba al cerrar la jornada, con la tarjeta del arranque abierta ---")
		_lanzar_prueba()
	elif day == _primero + 2:
		_tiempo = 3
		print("")
		print("--- 3. la misma, con las tarjetas cerradas (como la ve un jugador) ---")
		# Lo que haría el jugador: pulsar «Seguir» en cada tarjeta hasta que no
		# quede ninguna. Una decisión en cola, al enseñarse, para el reloj, y
		# vaciar la cola se lo devuelve: se acaba donde se estaba.
		var vueltas := 0
		while ui._moment_card != null and vueltas < 1000:
			ui.barra._show_next_moment()
			vueltas += 1
		print("   cerradas %d tarjetas · velocidad %.1f · velocidad guardada %.1f" % [
			vueltas, sim.time_scale, ui._speed_before_moment])
		_medido_el_salto = false
		_lanzar_prueba()


func _lanzar_prueba() -> void:
	var moment := Moment.new()
	moment.kind = Moment.Kind.PERCANCE
	moment.title = "PRUEBA"
	moment.text = "Una decisión de prueba de DecisionProbe."
	moment.options.append({"label": "Vale", "hint": "",
		"on_pick": func() -> void: _escogido += 1})
	sim.raise_moment(moment)


func _titulo_abierto() -> String:
	if ui._moment_card == null:
		return ""
	var etiqueta := _primer_label(ui._moment_card)
	return etiqueta.text if etiqueta != null else "?"


func _primer_label(node: Node) -> Label:
	if node is Label:
		return node as Label
	for child in node.get_children():
		var found := _primer_label(child)
		if found != null:
			return found
	return null


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
		return null
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
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo) or not ("ui" in demo):
		print("la escena no arranco")
		return null
	return demo
