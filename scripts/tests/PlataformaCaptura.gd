extends SceneTree
## La orografía de la plataforma emergida, vista: GRAFICOS §3 y
## [RelieveDeLaPlataforma].
##
## Queja del usuario del 2026-09-14: «en el mapa regional no se aprecia NADA de
## elevación en la plataforma emergida». Con partida empezada —el mar a −120 m— y
## **sin niebla**, que si no tapa justo lo que hay que mirar.
##
##   godot --path . --script res://scripts/tests/PlataformaCaptura.gd

## `AMPLITUDES=1,1.6,2.4`: una captura por amplitud de las lomas, para que el usuario
## elija cuánto relieve quiere (EPOCA_01 §10.2, tarea 4). Cada una monta su malla.
## `SITIO=lon,lat`: dónde mirar; por defecto, al norte de la casa.
func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Guardado.carpeta = "user://sondas/mapas"
	GameState.started = false
	GameState.niebla = null
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().size = Vector2i(1920, 1080)
	var amplitudes: Array[float] = [RelieveDeLaPlataforma.amplitud]
	if not OS.get_environment("AMPLITUDES").is_empty():
		amplitudes.clear()
		for trozo: String in OS.get_environment("AMPLITUDES").split(","):
			amplitudes.append(trozo.to_float())
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	for amplitud: float in amplitudes:
		RelieveDeLaPlataforma.amplitud = amplitud
		# La partida empieza en el mapa regional: con ella, el mar de la época.
		GameState.begin(sitios)
		change_scene_to_file("res://scenes/region_map.tscn")
		var mapa: Node = null
		for i in range(3000):
			await process_frame
			mapa = current_scene
			if mapa != null and mapa.get("terrain") != null \
					and not (mapa.terrain as TerrainGenerator).generando_la_malla \
					and i > 240:
				break
		if mapa == null or mapa.get("terrain") == null:
			print("MAL: sin mapa regional")
			quit(1)
			return
		# Sin niebla: lo que se mira es el relieve.
		# Ni las nubes con volumen, que se ponen encima de lo no descubierto y tapaban
		# justo la plataforma (primera captura del 2026-09-16). ANTES de quitar la niebla:
		# apagar las nubes la vuelve a poner, y la segunda captura salió gris entera.
		var terreno: TerrainGenerator = mapa.terrain
		var casa := GameState.home
		var mirar := Vector2(casa.lon, casa.lat + 0.12)
		if not OS.get_environment("SITIO").is_empty():
			var partes := OS.get_environment("SITIO").split(",")
			mirar = Vector2(partes[0].to_float(), partes[1].to_float())
		mapa.camera.set_target(terreno.geo_to_world(mirar.x, mirar.y))
		var lejos := 0.12
		if not OS.get_environment("LEJOS").is_empty():
			lejos = OS.get_environment("LEJOS").to_float()
		mapa.camera.set_distance(float(maxi(terreno.terrain_size.x,
			terreno.terrain_size.y)) * lejos)
		for i in range(120):
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot != null:
			var nombre := "user://plataforma_x%s.png" % String.num(amplitud, 1).replace(".", "_")
			shot.save_png(nombre)
			print("amplitud %.1f: captura en %s" % [amplitud, ProjectSettings.globalize_path(nombre)])
	quit()
