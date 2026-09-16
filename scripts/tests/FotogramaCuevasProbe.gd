extends SceneTree
## Lo que cuestan las cuevas nuevas en el fotograma: la sima cosida en el terreno
## y el techo de roca.
##
## Se mide EN LA MISMA CORRIDA, con las cuevas y sin ellas, desde dos cámaras: la
## de arranque del juego y una a treinta metros de la cueva de la banda. Entre
## corridas el reloj de pared no se compara (ARQUITECTURA §5.1). La simulación va
## parada: lo que se mide es el dibujo.
##   godot --path . --script res://scripts/tests/FotogramaCuevasProbe.gd

const SITE_ID := 56
const MAR_PALEOLITICO := -120.0
const CUADROS := 400


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Una sonda no escribe en los mapas del jugador. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/mapas"
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
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
	for i in range(150):
		await process_frame

	var demo := current_scene
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0
	demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)

	var simas: Node = demo.terrain.find_child("Simas", true, false)
	var cuevas: Array = demo._caves
	print("cuevas: %d · simas cosidas: %d" % [cuevas.size(),
		simas.get_child_count() if simas != null else 0])

	# 1. La cámara de arranque, sin tocarla. Con y sin, DOS VECES alternando: la
	# primera medida dio tirones sueltos —el horno de rejillas, lo que se carga al
	# mover la cámara— que pesaban más que las cuevas.
	for f in range(200):
		await process_frame
	var arranque := await _alternar(simas, cuevas)

	# 2. A treinta metros de la cueva de la banda, mirándola.
	# La busca el campamento, que es de quien son las cuevas.
	var casa: CaveMouth = demo.campamento.cueva_en(sim.home_position)
	if casa != null:
		demo.camera.set_target(casa.pick_position())
		demo.camera.set_distance(30.0)
	for f in range(300):
		await process_frame
	var cerca := await _alternar(simas, cuevas)

	print("")
	print("cámara de arranque · %s" % arranque)
	print("cerca de la cueva  · %s" % cerca)
	quit()


func _cuevas_visibles(simas: Node, cuevas: Array, si: bool) -> void:
	if simas != null:
		(simas as Node3D).visible = si
	for cueva: CaveMouth in cuevas:
		for hijo: Node in cueva.get_children():
			if hijo is MeshInstance3D:
				(hijo as MeshInstance3D).visible = si


## Con, sin, con, sin: la mediana de cada tanda.
func _alternar(simas: Node, cuevas: Array) -> String:
	var con: Array[float] = []
	var sin: Array[float] = []
	for vuelta in range(2):
		_cuevas_visibles(simas, cuevas, true)
		con.append(await _mediana())
		_cuevas_visibles(simas, cuevas, false)
		sin.append(await _mediana())
	_cuevas_visibles(simas, cuevas, true)
	return "con cuevas %.2f y %.2f ms · sin cuevas %.2f y %.2f ms (medianas)" % [
		con[0], con[1], sin[0], sin[1]]


## La mediana del fotograma, en ms: no la mueve un tirón suelto.
func _mediana() -> float:
	for f in range(30):
		await process_frame
	var tiempos: Array[float] = []
	for f in range(CUADROS):
		var antes := Time.get_ticks_usec()
		await process_frame
		tiempos.append(float(Time.get_ticks_usec() - antes) / 1000.0)
	tiempos.sort()
	return tiempos[CUADROS / 2]
