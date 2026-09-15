extends SceneTree
## Las nubes volumétricas: cómo se ven y qué cuestan.
##
## Petición del usuario del 2026-09-14: «las nubes están cuadriculadas, parecen de
## Minecraft; quiero hacerlas volumétricas si no cuestan mucho». El tope acordado
## es ~1 ms de GPU; si cuestan más, el volumen se queda para los niveles altos.
##
## Una sola corrida, alternando volumen y nubes planas cada tanda —como
## `MapasProbe`—: el coste sale de la DIFERENCIA dentro de la misma ejecución, así
## que una carga de fondo constante no lo contamina. Y dos capturas, una de cada.
##
## Necesita ventana: con --headless no hay imagen ni tiempo de GPU.
##
##   godot --path . --script res://scripts/tests/NubesCaptura.gd

const SITE_ID := 56
const TANDAS := 4
const CUADROS := 90


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# A 1080p, que es la resolución del presupuesto de GRAFICOS §1: la ventana
	# por defecto toma la pantalla, y a 3651×2054 el volumen cuesta el triple.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var demo := await _arrancar()
	print("ventana %s" % get_root().get_texture().get_size())
	if demo == null:
		print("no se pudo arrancar")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0
	sim.hour = 12.0
	demo.ui.visible = false
	var cielo := _material_del_cielo()
	if cielo == null:
		print("sin material de cielo")
		quit(1)
		return
	cielo.set_shader_parameter("nubes", 0.7)
	# La vista de gestión mirando al horizonte, que es donde se ve cielo.
	demo.camera.set_target(sim.home_position)
	demo.camera.set_distance(420.0)
	demo.camera.orbit_angle_v = -3.0
	for f in range(60):
		await process_frame

	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var suma := {0: 0.0, 12: 0.0}
	for tanda in range(TANDAS):
		for pasos: int in [0, 12]:
			cielo.set_shader_parameter("pasos_de_nube", pasos)
			for f in range(20):
				await process_frame
			var gpu := 0.0
			for f in range(CUADROS):
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			suma[pasos] = float(suma[pasos]) + gpu / float(CUADROS)
			if tanda == 0:
				var shot := get_root().get_texture().get_image()
				if shot == null:
					print("sin captura: hace falta ventana")
					quit(1)
					return
				var ruta := "user://nubes_%s.png" % ("volumen" if pasos > 0 else "planas")
				shot.save_png(ruta)
				print("captura: %s" % ProjectSettings.globalize_path(ruta))
	var planas := float(suma[0]) / float(TANDAS)
	var volumen := float(suma[12]) / float(TANDAS)
	print("GPU por cuadro · planas %.2f ms · volumen %.2f ms · coste del volumen %+.2f ms" % [
		planas, volumen, volumen - planas])
	quit()


func _material_del_cielo() -> ShaderMaterial:
	for node: Node in get_root().find_children("*", "WorldEnvironment", true, false):
		var entorno := (node as WorldEnvironment).environment
		if entorno != null and entorno.sky != null \
				and entorno.sky.sky_material is ShaderMaterial:
			return entorno.sky.sky_material as ShaderMaterial
	return null


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
