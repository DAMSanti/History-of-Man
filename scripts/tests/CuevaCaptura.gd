extends SceneTree
## Tres bocas de cueva, de cerca y de lejos. Frente 21 de EPOCA_01 §10.1, tanda
## 4: «capturas con ventana de tres bocas: se ven como cuevas a la distancia de
## gestión».
##
## Con ventana: con `--headless` no hay imagen.
##   godot --path . --script res://scripts/tests/CuevaCaptura.gd
##
## `DISTANCIA` cambia la toma de lejos (45 m por defecto) y `SUFIJO` el nombre de
## las capturas, para guardar el antes y el después.

const SITE_ID := 56
const MAR_PALEOLITICO := -120.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Una sonda no escribe en los mapas del jugador. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/mapas"
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: SettlementSim = demo.sim
	var ui: GameUI = demo.ui
	if sim == null or ui == null:
		print("sin simulacion")
		quit()
		return
	sim.time_scale = 0.0
	for id: String in (ui._windows as Dictionary).keys():
		(ui._windows[id] as Control).visible = false
	ui.visible = false

	var cuevas: Array = demo._caves
	print("bocas en el mapa: %d" % cuevas.size())
	if cuevas.is_empty():
		quit()
		return

	# La de casa primero, y luego las dos más lejanas: que salgan laderas
	# distintas y no tres veces la misma.
	var casa: CaveMouth = demo._cave_at(sim.home_position)
	var otras := cuevas.duplicate()
	otras.erase(casa)
	otras.sort_custom(func(a: CaveMouth, b: CaveMouth) -> bool:
		return a.pick_position().distance_to(sim.home_position) \
			> b.pick_position().distance_to(sim.home_position))
	var elegidas: Array = []
	if casa != null:
		elegidas.append(casa)
	for cueva: CaveMouth in otras:
		if elegidas.size() >= 3:
			break
		elegidas.append(cueva)

	var distancia := 45.0
	if not OS.get_environment("DISTANCIA").is_empty():
		distancia = float(OS.get_environment("DISTANCIA"))
	var sufijo := OS.get_environment("SUFIJO")

	# CÁMARA PROPIA, y no la del juego: la órbita tiene distancia mínima y no
	# baja de unos cien metros, donde una boca de 3 a 6 m son cuatro píxeles y no
	# se puede juzgar el modelo. Interesan las dos cosas: de cerca, cómo es; de
	# lejos, si se distingue.
	var ojo := Camera3D.new()
	demo.add_child(ojo)
	ojo.current = true

	for i in range(elegidas.size()):
		var cueva: CaveMouth = elegidas[i]
		cueva.discover()
		var frente := cueva.facing()
		var mirada := cueva.pick_position()
		# Dos tomas por cueva y no cuatro: cada captura pesa doce megas y llenaron
		# el disco del usuario dos veces el 2026-09-13.
		for vista: Array in [["ladeada", 24.0, 12.0, 55.0], ["alto", 14.0, 30.0, 20.0]]:
			var lejos: float = vista[1]
			var rumbo := frente.rotated(Vector3.UP, deg_to_rad(float(vista[3])))
			ojo.global_position = mirada + rumbo * lejos + Vector3(0.0, float(vista[2]), 0.0)
			ojo.look_at(mirada, Vector3.UP)
			for f in range(30):
				sim.hour = 12.0
				await process_frame
			var shot := get_root().get_texture().get_image()
			var nombre := "user://cueva_%d_%s%s.png" % [i, String(vista[0]), sufijo]
			if shot != null:
				shot.save_png(nombre)
				print("captura en %s" % ProjectSettings.globalize_path(nombre))
			else:
				print("sin captura: ¿se ha lanzado con --headless?")
	quit()


## Lo que deja el mapa regional al entrar. Ver [RegionMap._enter_local].
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
	Expedition.sea_level_m = MAR_PALEOLITICO
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.retomando = false
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	return current_scene
