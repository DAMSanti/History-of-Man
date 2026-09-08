extends SceneTree
## El mismo valle en las cuatro estaciones, fotografiado desde el mismo sitio.
##
## Es la única forma de juzgar el color del año: una tabla de tintes no dice si
## el invierno se lee como invierno o como «el mismo prado un poco más gris».
## Se planta la cámara, se asienta cada estación —sin transición, que si no se
## fotografiarían cuatro veces la misma— y se dispara.
##
## No pasa ni falla: mide. Lo que hay que mirar es si las cuatro se distinguen
## de un vistazo y si la cota de nieve cae donde tiene que caer.
##
##   ALTURA=900   a qué distancia se pone la cámara

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	var terrain: Node = demo.terrain
	var forest: Node = demo.forest if "forest" in demo else null
	var camera: Node = demo.camera if "camera" in demo else null
	var ui: Node = demo.ui if "ui" in demo else null

	# Sin ventanas por delante y con el reloj clavado a mediodía: de noche las
	# cuatro estaciones son el mismo negro.
	if ui != null:
		for id: String in (ui._windows as Dictionary).keys():
			(ui._windows[id] as Control).visible = false
	sim.time_scale = 0.0

	var lejos := 900.0
	if not OS.get_environment("ALTURA").is_empty():
		lejos = float(OS.get_environment("ALTURA"))
	if camera != null:
		camera.set_target(sim.home_position)
		camera.set_distance(lejos)
		camera.orbit_angle_v = -26.0

	print("")
	print("=== EL MISMO VALLE EN LAS CUATRO ESTACIONES ===")
	print("%-12s %8s %10s %8s %s" % [
		"estacion", "cota", "encharca", "caudal", "tinte del pasto"])

	for season: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		GameState.season = season
		sim.temporada.asentar(season as Subsistence.Season)
		# El paisaje se refresca al pasar la jornada, así que se avisa a mano.
		terrain.set_snow_line(sim.temporada.cota_de_nieve())
		terrain.caudal = sim.temporada.caudal()
		terrain.set_season_tint(sim.temporada.tinte_del_pasto())
		# Y el bosque, asentado del todo en la estacion -avance 1- para que la
		# foto sea de la estacion y no de la mezcla con la anterior.
		if forest != null:
			forest.set_season(season as Subsistence.Season,
				season as Subsistence.Season, 1.0)
		var tinte: Color = sim.temporada.tinte_del_pasto()
		print("%-12s %8.2f %10.2f %8.2f  %.2f %.2f %.2f" % [
			Subsistence.season_name(season as Subsistence.Season),
			sim.temporada.cota_de_nieve(), sim.temporada.encharcamiento(),
			sim.temporada.caudal(), tinte.r, tinte.g, tinte.b])
		for kind: Dictionary in Forest.KINDS:
			var tabla: Dictionary = Forest.CADUCO 				if bool(kind.get("caduco", false)) else Forest.PERENNE
			print("             %-14s hoja %.2f" % [
				String(kind["model"]), float(tabla[season]["hoja"])])

		# Unos cuantos cuadros: el terreno tiene que repintarse con los
		# uniformes nuevos antes de la foto.
		for i in range(24):
			sim.hour = 12.0
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot != null:
			shot.save_png("user://estacion_%d.png" % season)

	print("")
	print("capturas en %s" % ProjectSettings.globalize_path("user://"))
	print("y lo que dice la temporada de cada una:")
	for season: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO, Subsistence.Season.INVIERNO]:
		sim.temporada.asentar(season as Subsistence.Season)
		print("   %s" % sim.temporada.resumen(season as Subsistence.Season))
	quit()


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
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo
