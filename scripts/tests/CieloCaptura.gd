extends SceneTree
## El cielo que hay hoy, a cuatro horas, desde la cámara del juego.
##
## Frente 16 de EPOCA_01 §10.1, tanda 3. La spec dice «no hay cielo», y el
## código dice otra cosa: `WorldEnvironmentSetup._setup_sky` monta un
## `ProceduralSkyMaterial` y le cambia los colores de noche. Antes de escribir
## un shader hay que ver **qué se ve de verdad**, que para eso las capturas
## necesitan ventana.
##
##   ALTURA=420   a qué distancia se pone la cámara
##   INCLINA=-12  cuánto se inclina: la cámara de gestión mira hacia abajo, y
##                el cielo está justo en lo que no mira

const SITE_ID := 56
const HORAS := [6.0, 12.0, 19.0, 23.0]
const NOMBRES := ["alba", "mediodia", "ocaso", "noche"]


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	var ui: GameUI = demo.ui
	sim.time_scale = 0.0
	ui.visible = false

	# TIEMPO=despejado|nublado|temporal... : el cielo depende de lo que haga, y
	# con el del día 1 -nublado- no se ve una estrella.
	var tiempo := OS.get_environment("TIEMPO")
	if not tiempo.is_empty() and sim.weather != null:
		for kind: int in Weather.Kind.values():
			if String(Weather.NAMES.get(kind, "")).to_lower() == tiempo.to_lower():
				sim.weather.kind = kind as Weather.Kind
		demo._sync_weather()
		print("tiempo forzado: %s" % sim.weather.name_text())

	var lejos := 420.0
	if not OS.get_environment("ALTURA").is_empty():
		lejos = float(OS.get_environment("ALTURA"))
	var inclina := -12.0
	if not OS.get_environment("INCLINA").is_empty():
		inclina = float(OS.get_environment("INCLINA"))
	if "camera" in demo and demo.camera != null:
		demo.camera.set_target(sim.home_position)
		demo.camera.set_distance(lejos)
		demo.camera.orbit_angle_v = inclina

	for i in range(HORAS.size()):
		sim.hour = float(HORAS[i])
		for f in range(40):
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot == null:
			print("sin captura: hace falta ventana")
			quit(1)
			return
		var ruta := "user://cielo_%s.png" % NOMBRES[i]
		shot.save_png(ruta)
		print("%s (%.0f h): %s" % [NOMBRES[i], HORAS[i],
			ProjectSettings.globalize_path(ruta)])
	quit()


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
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
	return current_scene
