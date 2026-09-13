extends SceneTree
## El humo del hogar, en captura, y lo que cuesta en el fotograma.
## Frente 24 de EPOCA_01 §10.1, tanda 4: «humo en toda hoguera, hogar o fuego,
## que se va cuando el fuego se apaga; no puede empeorar el fotograma de forma
## medible».
##
## El antes y el después se miden EN LA MISMA CORRIDA, con el humo saliendo y
## con el humo parado: el reloj de pared no se compara entre corridas (ver
## ARQUITECTURA §5.1).
##   godot --path . --script res://scripts/tests/HumoCaptura.gd

const SITE_ID := 56
const MAR_PALEOLITICO := -120.0
const CUADROS := 240


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
	for i in range(120):
		await process_frame

	var demo := current_scene
	var sim: SettlementSim = demo.sim
	var ui: GameUI = demo.ui
	sim.time_scale = 0.0
	ui.visible = false
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.hearth_lit = true

	var fuego: Node3D = demo.hearth_fire
	var ojo := Camera3D.new()
	demo.add_child(ojo)
	ojo.current = true
	ojo.global_position = fuego.global_position + Vector3(-14.0, 7.0, 14.0)
	ojo.look_at(fuego.global_position + Vector3(0.0, 4.0, 0.0), Vector3.UP)
	for f in range(200):
		sim.hour = 12.0
		await process_frame
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://humo.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://humo.png"))

	var con_humo := await _media()
	for hoguera: Node in _hogueras(demo):
		(hoguera as Bonfire)._humo.emitting = false
		(hoguera as Bonfire)._humo.visible = false
	for f in range(60):
		await process_frame
	var sin_humo := await _media()
	print("fuegos: %d · fotograma con humo %.2f ms · sin humo %.2f ms"
		% [_hogueras(demo).size(), con_humo, sin_humo])
	quit()


func _media() -> float:
	var total := 0.0
	for f in range(CUADROS):
		var antes := Time.get_ticks_usec()
		await process_frame
		total += float(Time.get_ticks_usec() - antes) / 1000.0
	return total / float(CUADROS)


func _hogueras(nodo: Node) -> Array:
	var salida: Array = []
	if nodo is Bonfire:
		salida.append(nodo)
	for hijo: Node in nodo.get_children():
		salida.append_array(_hogueras(hijo))
	return salida
