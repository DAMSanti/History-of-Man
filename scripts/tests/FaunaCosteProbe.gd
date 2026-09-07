extends SceneTree
## Cuánta fauna hay, qué cuesta y si vuelve del río.
##
## Las tres preguntas del bloque de fauna en una sola pasada, porque las tres se
## contestan sobre la misma partida corriendo:
##
## - **Cuántos.** Un valle de cuatro kilómetros cuadrados con cien animales se
##   cruza entero sin ver una manada.
## - **Qué cuesta.** Subir la población sólo es una opción si el coste por
##   fotograma no se dispara: la búsqueda de depredador era cuadrática.
## - **Si vuelven.** El estado de beber no tenía salida, así que el primero que
##   llegaba a la charca se quedaba allí el resto de la partida. Se mira cuántos
##   están bebiendo al principio y cuántos al cabo de un rato: si sube y no baja
##   nunca, el valle se está vaciando hacia el agua.

const SITE_ID := 56
const FRAMES := 2400


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan datos"); quit(); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if site == null:
		print("sin emplazamiento"); quit(); return

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

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(240):
		await process_frame

	var demo := current_scene
	var herds: Node = null
	for child in demo.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with("WildlifeHerds.gd"):
			herds = child
	if herds == null:
		print("sin fauna"); quit(); return

	print("")
	print("fauna en el valle: %d animales (%d especies)" % [
		herds.animals().size(), WildlifeHerds.SPECIES_VISUAL.size()])

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var drinking_peak := 0
	var drinking_last := 0
	var moved := 0
	var frame_ms := 0.0
	var before: Array[Vector3] = herds.positions()

	for frame in range(FRAMES):
		await process_frame
		frame_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp) \
			+ RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var drinking := 0
		for animal: Dictionary in herds.animals():
			if int(animal["state"]) == WildlifeHerds.State.BEBIENDO:
				drinking += 1
		drinking_peak = maxi(drinking_peak, drinking)
		drinking_last = drinking

	var after: Array[Vector3] = herds.positions()
	for i in range(mini(before.size(), after.size())):
		if before[i].distance_to(after[i]) > 20.0:
			moved += 1

	print("coste medio de cuadro: %.1f ms" % (frame_ms / float(FRAMES)))
	print("bebiendo: maximo %d, al final %d (de %d)" % [
		drinking_peak, drinking_last, herds.animals().size()])
	print("se han movido mas de 20 m: %d de %d" % [moved, before.size()])
	quit()
