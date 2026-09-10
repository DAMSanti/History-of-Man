extends SceneTree
## ¿Se puede llegar a la otra orilla, y por dónde?
##
## Duda del jugador: «mirando el mapa no deberían tener forma de llegar hasta
## verano, a no ser que las 8 tiles del margen se cuenten para buscar caminos».
##
## Se coge la otra orilla enfrente del abrigo y se pregunta por ella: si la
## rejilla la da por comunicada, se traza el camino y se mira POR DÓNDE cruza el
## agua. Un paso por el borde del mapa saldría aquí como un camino que se va a
## las tiles del margen antes de cruzar.

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	sim.time_scale = 6.0
	var primero: int = sim.day
	while sim.day < primero + 2:
		await process_frame

	var grid: Navgrid = sim.marcha._navgrid()
	var tam: Vector2 = Vector2(sim._terrain.terrain_size)
	print("")
	print("mapa %.0f x %.0f m · celda de rejilla %.0f m" % [tam.x, tam.y, Navgrid.CELL])
	print("abrigo en (%.0f, %.0f)" % [sim.home_position.x, sim.home_position.z])

	# Se barre en abanico alrededor del abrigo buscando puntos secos al otro
	# lado del agua: los que hay que cruzar el rio para pisar.
	var comunicados := 0
	var alcanzables := 0
	var mirados := 0
	var ejemplo := Vector3.ZERO
	for i in range(360):
		var angulo := float(i) / 360.0 * TAU
		for radio: float in [300.0, 500.0, 800.0, 1200.0]:
			var punto: Vector3 = sim.home_position + Vector3(
				cos(angulo) * radio, 0.0, sin(angulo) * radio)
			if punto.x < 0.0 or punto.z < 0.0 or punto.x > tam.x or punto.z > tam.y:
				continue
			punto.y = sim._terrain.get_height_at(punto)
			if not Hydrography.can_cross(
					sim._terrain.crossing_difficulty_at(punto), false, false):
				continue
			if not sim.marcha.cruza_el_agua(sim.home_position, punto):
				continue
			mirados += 1
			if grid.connected(sim.home_position, punto):
				comunicados += 1
				if ejemplo == Vector3.ZERO:
					ejemplo = punto
			if sim.marcha.alcanzable_de_verdad(sim.home_position, punto):
				alcanzables += 1

	print("")
	print("puntos secos con el rio de por medio: %d" % mirados)
	print("   que la rejilla da por COMUNICADOS: %d" % comunicados)
	print("   que ademas son ALCANZABLES (rodeo <= x%.1f): %d" % [
		Marcha.RODEO_QUE_SE_ANDA, alcanzables])

	if ejemplo != Vector3.ZERO:
		print("")
		print("--- POR DONDE CRUZA EL CAMINO A UNO DE ELLOS ---")
		var camino := Wayfinder.find(grid, sim.home_position, ejemplo)
		var largo: float = sim.marcha.largo_de(sim.home_position, camino)
		print("   destino a %.0f m en recta · camino de %.0f m (x%.1f)" % [
			Traversal.en_llano(sim.home_position, ejemplo), largo,
			largo / maxf(Traversal.en_llano(sim.home_position, ejemplo), 1.0)])
		var antes: Vector3 = sim.home_position
		for punto: Vector3 in camino:
			if sim.marcha.cruza_el_agua(antes, punto):
				var borde := minf(minf(punto.x, punto.z),
					minf(tam.x - punto.x, tam.y - punto.z))
				print("   cruza el agua en (%.0f, %.0f), a %.0f m del borde del mapa"
					% [punto.x, punto.z, borde])
				print("   o sea %s" % ("POR EL MARGEN DEL MAPA"
					if borde < Navgrid.CELL * 8.0 else "por un vado de dentro"))
				break
			antes = punto
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
