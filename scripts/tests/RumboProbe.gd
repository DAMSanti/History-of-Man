extends SceneTree
## El botón «Rumbo» del valle, por el camino del juego: SISTEMAS §4, spec del
## 2026-09-15, e INTERFAZ §4.
##
## Con ventana, a 1920×1080:
##
##   1. en el valle del sitio 56, sin pieles curtidas: el botón apagado y por qué;
##   2. con ellas, encendido;
##   3. se pulsa: el mapa regional se monta con la ficha abierta para ese campamento,
##      viniendo del valle —`rumbo_regional_ficha.png`—, y con dos yacimientos
##      avistados dibujados bajo la niebla —`rumbo_regional_avistados.png`—;
##   4. «Mandar y volver al valle»: sale y se vuelve al valle.
##
##   godot --path . --script res://scripts/tests/RumboProbe.gd


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/mapas"
	GameState.started = false
	GameState.niebla = null
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().size = Vector2i(1920, 1080)
	var fallos := 0

	change_scene_to_file(Expedition.REGION_SCENE)
	var mapa: Node = await _escena_montada(null)
	if mapa == null:
		print("MAL: el mapa regional no se monta")
		quit(1)
		return
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio_56: Site = null
	for s: Site in comarca.sites:
		if s.id == 56:
			sitio_56 = s
	var campamento := Campamento.montar(self, sitio_56, GameState.population, 400.0)
	Campamentos.alta(self, campamento)
	Campamentos.traspaso_de(campamento)
	change_scene_to_file(Expedition.LOCAL_SCENE)
	var demo: Node = await _escena_montada(mapa)
	if demo == null:
		print("MAL: el valle no se monta")
		quit(1)
		return
	demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	demo.sim.time_scale = 0.0
	var sim: SettlementSim = demo.sim
	print("")
	print("=== EL BOTÓN «RUMBO» DEL VALLE ===")

	# 1. Sin pieles curtidas.
	sim.store.take(Materia.Kind.PIEL_CURTIDA, sim.store.amount(Materia.Kind.PIEL_CURTIDA))
	sim.store.add(Materia.Kind.LENA, 200.0)
	sim.store.add(Materia.Kind.CARNE_SECA, 200.0)
	demo.minimapa.refrescar_el_rumbo()
	var boton: Button = demo.minimapa.boton_de_rumbo
	print("sin pieles: %s · «%s»" % ["APAGADO" if boton.disabled else "ENCENDIDO", boton.tooltip_text])
	if not boton.disabled or not boton.tooltip_text.contains("pieles curtidas"):
		print("MAL: sin pieles tenía que estar apagado y decirlo")
		fallos += 1
	await _cuadros(10)
	_captura("rumbo_boton_apagado")

	# 2. Con ellas.
	sim.store.add(Materia.Kind.PIEL_CURTIDA, 10.0)
	demo.minimapa.refrescar_el_rumbo()
	print("con pieles: %s" % ("APAGADO: " + boton.tooltip_text if boton.disabled else "ENCENDIDO"))
	if boton.disabled:
		fallos += 1

	# Dos yacimientos avistados bajo la niebla, para verlos dibujados en el regional:
	# los dos más cercanos a casa que la partida no ve.
	var avistados: Array[Site] = []
	var candidatos: Array[Site] = []
	for s: Site in comarca.available_in(GameState.sea_level_m, GameState.era):
		if not GameState.se_ve(s) and s.id != sitio_56.id:
			candidatos.append(s)
	candidatos.sort_custom(func(a: Site, b: Site) -> bool:
		return absf(a.lon - sitio_56.lon) + absf(a.lat - sitio_56.lat) \
			< absf(b.lon - sitio_56.lon) + absf(b.lat - sitio_56.lat))
	for s: Site in candidatos.slice(0, 2):
		GameState.avistar(s)
		avistados.append(s)
		print("avistado: %s" % s.display_name())

	# 3. Se pulsa.
	demo.mandar_expedicion()
	var regional: Node = await _escena_montada(demo)
	if regional == null:
		print("MAL: el botón no lleva al regional")
		quit(1)
		return
	await _cuadros(30)
	var ficha: FichaDeRumbo = regional._ficha_de_rumbo
	if ficha == null:
		print("MAL: el regional no abre la ficha")
		fallos += 1
	else:
		print("ficha abierta: desde el valle %s · rumbos %s · bloqueo «%s»" % [
			"SI" if ficha.desde_el_valle else "NO", str(ficha.posibles), ficha.bloqueo()])
		if not ficha.desde_el_valle or ficha.sim != sim:
			fallos += 1
	_captura("rumbo_regional_ficha")
	var terreno: TerrainGenerator = regional.terrain
	var marcas: int = regional._markers.multimesh.instance_count
	var pinchables: Array = regional._visible_sites
	var pinchable := false
	for s: Site in avistados:
		pinchable = pinchable or pinchables.has(s)
	print("marcas dibujadas %d · se pinchan %d · algún avistado se pincha: %s" % [
		marcas, pinchables.size(), "SI" if pinchable else "NO"])
	if pinchable or marcas < pinchables.size() + avistados.size():
		fallos += 1
	if not avistados.is_empty():
		var a := avistados[0]
		regional.camera.set_target(terreno.geo_to_world(a.lon, a.lat))
		regional.camera.set_distance(float(maxi(terreno.terrain_size.x, terreno.terrain_size.y)) * 0.04)
	await _cuadros(60)
	_captura("rumbo_regional_avistados")

	# 4. Mandar y volver al valle.
	if ficha != null:
		var salio := ficha.mandar(true)
		var de_vuelta: Node = await _escena_montada(regional)
		print("manda y vuelve: sale %s · de vuelta en el valle %s · fuera %d" % [
			"SI" if salio else "NO", "SI" if de_vuelta != null and de_vuelta.get("sim") == sim else "NO",
			sim.expedicion.fuera.size()])
		if not salio or de_vuelta == null:
			fallos += 1
	print("fallos: %d" % fallos)
	quit(0 if fallos == 0 else 1)


## Espera a que la escena actual sea otra que `antes` y esté montada.
func _escena_montada(antes: Node) -> Node:
	for i in range(3000):
		await process_frame
		var escena := current_scene
		if escena != null and escena != antes and bool(escena.get("montado")):
			await _cuadros(20)
			return escena
	return null


func _cuadros(cuantos: int) -> void:
	for i in range(cuantos):
		await process_frame


func _captura(nombre: String) -> void:
	var shot := get_root().get_texture().get_image()
	if shot == null or shot.is_empty():
		print("sin captura: hace falta ventana")
		return
	var ruta := "user://capturas/%s.png" % nombre
	shot.save_png(ruta)
	print("captura en %s" % ProjectSettings.globalize_path(ruta))
