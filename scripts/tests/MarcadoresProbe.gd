extends SceneTree
## Los alfileres después de ir al mapa regional y volver.
##
## Queja del usuario del 2026-09-14: «he ido de la partida al mapa regional, y del
## mapa regional a la partida; me ha cargado todo menos los marcadores que tenía
## seleccionados: ahora no me muestra ninguno». Tenía tocado el filtro del botón
## «Marcadores».
##
## Se hace el mismo viaje que el juego, sin pasar por el mapa regional —que no
## guarda nada de la partida—: jugar hasta que haya parajes, apagar una familia,
## guardar el estado del mapa, montar la escena otra vez con `retomando` y contar.
##
##   godot --headless --path . --script res://scripts/tests/MarcadoresProbe.gd

const SITE_ID := 56


func _init() -> void:
	Guardado.carpeta = "user://sondas/mapas"
	# COPIA=<ruta de un .sav>: retoma ESE estado —una partida del jugador,
	# copiada a la carpeta de las sondas, nunca leída en su sitio— en vez de
	# jugar una nueva. Es como se reproduce lo que vio el jugador con 167
	# jornadas y no con cuatro parajes del primer día.
	var copia := OS.get_environment("COPIA")
	if not copia.is_empty():
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(Guardado.carpeta))
		var error := DirAccess.copy_absolute(copia,
			ProjectSettings.globalize_path(Guardado.ruta_de(SITE_ID)))
		print("copia de %s: %s" % [copia, "bien" if error == OK else "error %d" % error])
		var sitios_copia: SiteSet = load("res://data/sites/cantabria_sites.res")
		if not Guardado.preparar_la_escena(Guardado.leer(SITE_ID), sitios_copia):
			print("la copia no se puede preparar")
			quit(1)
			return
		Expedition.retomando = true
		change_scene_to_file("res://scenes/demo_main.tscn")
		for i in range(200):
			await process_frame
		_contar("COPIA", current_scene)
		current_scene.filtro_de_marcadores._elegido(FiltroDeMarcadores.Familia.CAZA)
		for i in range(10):
			await process_frame
		_contar("COPIA TRAS TOCAR EL FILTRO", current_scene)
		Guardado.borrar(SITE_ID)
		quit()
		return
	_preparar_el_sitio()
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	var sim: SettlementSim = demo.sim
	sim.time_scale = 20.0
	var hasta := sim.day + 4
	while sim.parajes.list.size() < 3 and sim.day < hasta:
		await process_frame
		demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	sim.time_scale = 0.0
	for i in range(10):
		await process_frame

	# Como el jugador: una familia apagada.
	var filtro: FiltroDeMarcadores = demo.filtro_de_marcadores
	if filtro != null:
		filtro._elegido(FiltroDeMarcadores.Familia.CAZA)
	for i in range(10):
		await process_frame
	_contar("ANTES", demo)

	var fallo := Guardado.guardar(sim, demo.herds, demo._caves)
	print("guardado: %s" % ("bien" if fallo.is_empty() else fallo))
	var guardado := Guardado.leer(SITE_ID)
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	if not Guardado.preparar_la_escena(guardado, sitios):
		print("no se puede preparar la escena")
		quit(1)
		return
	Expedition.retomando = true
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(160):
		await process_frame
	_contar("DESPUÉS", current_scene)
	Guardado.borrar(SITE_ID)
	quit()


func _contar(cuando: String, demo: Node) -> void:
	var sim: SettlementSim = demo.sim
	var markers: ParajeMarkers = demo.paraje_markers
	var hijos := 0
	var visibles := 0
	var cimas := 0
	for child: Node in markers.get_children():
		if String(child.name).begins_with("Cima_"):
			cimas += 1
		if not String(child.name).begins_with("Paraje_"):
			continue
		hijos += 1
		if (child as Node3D).visible:
			visibles += 1
	var cuevas_visibles := 0
	for cave: CaveMouth in demo._caves:
		if cave._marker != null and cave._marker.visible and cave.visible:
			cuevas_visibles += 1
	var camara: Camera3D = demo.camera
	print("   cámara en %s · cimas %d · cuevas con alfiler visible %d de %d" % [
		camara.global_position if camara != null else "?", cimas,
		cuevas_visibles, demo._caves.size()])
	var filtro: FiltroDeMarcadores = demo.filtro_de_marcadores
	print("%s · jornada %d · parajes %d · cambios %d · pintados %d · alfileres %d · visibles %d · filtro %s · filtro en markers %s" % [
		cuando, sim.day, sim.parajes.list.size(), sim.parajes.cambios,
		demo._parajes_pintados, hijos, visibles,
		filtro.visibles if filtro != null else "sin filtro",
		markers.filtro != null])


func _preparar_el_sitio() -> void:
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
