extends SceneTree
## La ventana del trueque con un trato a medio hacer, y la de relaciones.
## Frentes 25 y 26 de EPOCA_01 §10.1, tanda 4.
##   godot --path . --script res://scripts/tests/TruequeCaptura.gd

const SITE_ID := 56
const MAR_PALEOLITICO := -120.0


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
	ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)

	# Una banda conocida, con un trato ya hecho y otro a medio hacer.
	var con := 34
	sim.contacto.ocupados[con] = true
	sim.contacto.conocerse(con)
	sim.contacto.mover_el_trato(con, 20.0)
	sim.store.add(Materia.Kind.FRUTO_SECO, 30.0)
	sim.store.add(Materia.Kind.PIEL, 6.0)
	var traen := sim.intercambio.lo_que_traen(con)
	var material: int = traen.keys()[0]
	sim.intercambio.cambiar(con, {Materia.Kind.FRUTO_SECO:
		Intercambio.precio(material as Materia.Kind) / sim.intercambio.factor_con(con) \
			/ sim.intercambio.factor_con(con)}, {material: 1.0})

	ui.trueque.da = {Materia.Kind.FRUTO_SECO: 6.0}
	ui.trueque.recibe = {material: 2.0}
	ui.trueque._con = con
	ui.trueque.show_trade()
	for i in range(20):
		await process_frame
	_captura("user://trueque.png")

	ui.relaciones.show_relations()
	for i in range(20):
		await process_frame
	_captura("user://relaciones.png")
	quit()


func _captura(ruta: String) -> void:
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png(ruta)
		print("captura en %s" % ProjectSettings.globalize_path(ruta))
