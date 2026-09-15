extends SceneTree
## La tecla N —la capa de navegación— sobre el valle montado.
##
## Queja del usuario del 2026-09-14: «me ha crasheado al darle a la N para
## mostrar las zonas accesibles». Aquí se monta el valle de verdad y se pulsa,
## que es lo que la suite no puede hacer: `NavOverlay` necesita terreno, rejilla
## y árbol de escena.
##
##   godot --headless --path . --script res://scripts/tests/NavegacionProbe.gd

const SITE_ID := 56


func _init() -> void:
	Guardado.carpeta = "user://sondas/mapas"
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	var sitio: Site = null
	for s: Site in sitios.sites:
		if s.id == SITE_ID:
			sitio = s
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = sitio
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = GameState.era
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(sitio.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(sitio.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file(Expedition.LOCAL_SCENE)
	for i in range(600):
		await process_frame
		if current_scene != null and current_scene.get("ui") != null:
			break
	var demo := current_scene
	if demo == null or demo.get("sim") == null:
		print("MAL: el valle no se monta")
		quit(1)
		return
	demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	demo.sim.time_scale = 0.0
	for i in range(10):
		await process_frame

	print("")
	print("=== LA TECLA N ===")
	var rejilla: Navgrid = demo.sim.navgrid()
	print("rejilla: %s · lista %s" % ["null" if rejilla == null else "hay",
		"no" if rejilla == null or not rejilla.is_ready() else "sí"])
	var antes := Time.get_ticks_msec()
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_N
	tecla.pressed = true
	demo._tecla(tecla)
	print("pulsada: %d ms" % (Time.get_ticks_msec() - antes))
	for i in range(30):
		await process_frame
	var capa: NavOverlay = demo.get("nav_overlay")
	print("capa: %s · visible %s · malla %s" % ["null" if capa == null else "hay",
		"no" if capa == null or not capa.showing() else "sí",
		"sin malla" if capa == null or capa.mesh == null else "%d superficies"
			% (capa.mesh as Mesh).get_surface_count()])
	# Y otra vez, para apagarla: la segunda pulsación es la que no rehace nada.
	demo._tecla(tecla)
	for i in range(10):
		await process_frame
	print("apagada: visible %s" % ("sí" if capa != null and capa.showing() else "no"))
	print("=== FIN ===")
	quit(0)
