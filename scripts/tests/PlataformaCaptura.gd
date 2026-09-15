extends SceneTree
## La orografía de la plataforma emergida, vista: GRAFICOS §3 y
## [RelieveDeLaPlataforma].
##
## Queja del usuario del 2026-09-14: «en el mapa regional no se aprecia NADA de
## elevación en la plataforma emergida». Con partida empezada —el mar a −120 m— y
## **sin niebla**, que si no tapa justo lo que hay que mirar.
##
##   godot --path . --script res://scripts/tests/PlataformaCaptura.gd

func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Guardado.carpeta = "user://sondas/mapas"
	GameState.started = false
	GameState.niebla = null
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().size = Vector2i(1920, 1080)
	# La partida empieza en el mapa regional: con ella, el mar de la época.
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	GameState.begin(sitios)
	change_scene_to_file("res://scenes/region_map.tscn")
	for i in range(240):
		await process_frame
	var mapa := current_scene
	if mapa == null or mapa.get("terrain") == null:
		print("MAL: sin mapa regional")
		quit(1)
		return
	# Sin niebla: lo que se mira es el relieve.
	mapa.terrain.set_fog_texture(null, 0.0)
	var terreno: TerrainGenerator = mapa.terrain
	var casa := GameState.home
	mapa.camera.set_target(terreno.geo_to_world(casa.lon, casa.lat - 0.25))
	mapa.camera.set_distance(float(maxi(terreno.terrain_size.x, terreno.terrain_size.y)) * 0.30)
	for i in range(90):
		await process_frame
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://plataforma.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://plataforma.png"))
	quit()
