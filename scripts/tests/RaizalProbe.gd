extends SceneTree
## ¿Está «El raizal del paso» al otro lado del agua?
##
## Sospecha del jugador: «creo que el raizal del paso es el causante de que se
## choquen contra el río, un explorador ha ido a batir ese paraje y se ha ido a
## 1 km contra el río. ¿Puede tener que ver con que está cortado por el río?».
##
## Se mide lo único que contesta eso: de cada paraje, la línea recta desde el
## abrigo, lo que mide el camino de verdad, y —para su huella— cuántas de sus
## celdillas caen en la orilla de enfrente, o sea a las que no se llega sin dar
## la vuelta entera.

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
	var dias := 3
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame

	var grid: Navgrid = sim.marcha._navgrid()
	print("")
	print("--- CADA PARAJE: RECTO, CAMINO Y RODEO ---")
	print("   %-27s %7s %8s %7s %6s %s" % [
		"paraje", "recto", "camino", "rodeo", "suelto", "veredicto"])
	for paraje: Paraje in sim.parajes.list:
		var recto := Traversal.en_llano(sim.home_position, paraje.position)
		var camino := Wayfinder.find(grid, sim.home_position, paraje.position)
		var largo := 0.0
		if not camino.is_empty():
			largo = sim.home_position.distance_to(camino[0])
			for i in range(1, camino.size()):
				largo += camino[i - 1].distance_to(camino[i])

		# De su huella, cuántas celdillas quedan al otro lado: comunicadas
		# sobre el papel pero con un rodeo que no se anda en una jornada.
		var sueltas := 0
		var mojadas := 0
		var todas := 0
		if paraje.huella != null and not paraje.huella.vacia():
			for punto: Vector3 in paraje.huella.celdas():
				todas += 1
				if not sim.marcha.alcanzable_de_verdad(sim.home_position, punto):
					# Mojada es el cauce -en una pesquera tiene que estar-;
					# seca y sin camino es la orilla de enfrente, que es el
					# problema.
					if sim._terrain.crossing_difficulty_at(punto) > 0.05:
						mojadas += 1
					else:
						sueltas += 1

		var rodeo := largo / maxf(recto, 1.0)
		print("   %-27s %5.0f m %6.0f m  x%4.1f %2d seca %2d agua /%-4d %s" % [
			paraje.name_text, recto, largo, rodeo, sueltas, mojadas, todas,
			"AL OTRO LADO" if rodeo > Marcha.RODEO_QUE_SE_ANDA
				else ("PARTIDO POR EL AGUA" if sueltas > 0 else "ok")])
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
