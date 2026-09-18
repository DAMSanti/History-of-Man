extends SceneTree
## El mapa regional TAL COMO LO ABRE EL MODO DEBUG: con la costa de la época, su relieve y
## sus ríos por la plataforma emergida. INTERFAZ §14 y GRAFICOS §3.
##
## Existe por una queja del usuario del 2026-09-17: «cuando entro en debug, el mapa regional
## no tiene ríos; pero cargo un mapa, vuelvo y vuelve a tener ríos». El modo Debug no funda
## nada, y el mapa se montaba con el mar de hoy —de ahí una plataforma pelada y sin cauces—
## para luego pintarle encima la costa glacial. Ver [RegionMap.mar_del_mapa].
##
##   godot --path . --script res://scripts/tests/DebugCaptura.gd
##
## Cuenta las celdas de cauce que caen sobre la plataforma emergida, que es lo que faltaba,
## y deja una captura.

func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Una sonda no escribe en los mapas del jugador. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/debug"
	ModoDebug.entrar()
	print("modo debug: activo %s · mar del mapa %.0f m" % [ModoDebug.activo,
		load("res://scripts/region/RegionMap.gd").mar_del_mapa()])
	change_scene_to_file("res://scenes/region_map.tscn")
	for i in range(600):
		await process_frame
	var mapa := current_scene
	if mapa == null:
		print("sin mapa regional")
		quit(1)
		return

	var relieve: HeightmapData = mapa.terrain.heightmap
	var original: HeightmapData = load(mapa.heightmap_path)
	var cauce_en_plataforma := 0
	var plataforma_emergida := 0
	for i in range(relieve.elevations.size()):
		if original.elevations[i] >= 0.0:
			continue
		if relieve.elevations[i] > mapa._sea_level_m:
			plataforma_emergida += 1
			if relieve.river_mask.size() == relieve.elevations.size() \
					and relieve.river_mask[i] > 0.01:
				cauce_en_plataforma += 1
	print("mar dibujado %.0f m · plataforma emergida %d celdas · con cauce pintado %d" % [
		mapa._sea_level_m, plataforma_emergida, cauce_en_plataforma])

	for i in range(120):
		await process_frame
	var foto := get_root().get_texture().get_image()
	if foto != null:
		foto.save_png("user://debug_regional.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://debug_regional.png"))
	ModoDebug.salir()
	quit()
