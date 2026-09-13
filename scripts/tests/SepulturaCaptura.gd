extends SceneTree
## Dos tumbas junto a la cueva de la banda: una cubierta y una con ajuar.
## Frente 27 de EPOCA_01 §10.1, tanda 4: «la sepultura aparece sobre el
## terreno. Captura con ventana».
##   godot --path . --script res://scripts/tests/SepulturaCaptura.gd

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
	ui.visible = false

	var casa: Vector3 = sim.home_forecourt if sim.home_forecourt != Vector3.ZERO \
		else sim.home_position
	sim.store.add(Materia.Kind.PIEDRA, 20.0)
	sim.store.add(Materia.Kind.OCRE, 5.0)
	sim.store.add(Materia.Kind.CONCHA, 5.0)
	# En la campa de la boca, donde vive la banda: es seco por definición. Las
	# dos primeras capturas buscaron seco a mano y las pusieron en el río.
	var secos: Array[Vector3] = [casa + Vector3(3.5, 0.0, 2.0), casa + Vector3(-3.0, 0.0, 3.0)]
	sim.sepulturas.despedir("Anda", secos[0], Sepulturas.Despedida.CUBRIR)
	sim.sepulturas.despedir("Beru", secos[1], Sepulturas.Despedida.ENTERRAR)
	demo.sepulturas_view.refresh(sim.sepulturas, demo.terrain)
	print("tumbas: %d · piezas dibujadas: %d" % [sim.sepulturas.tumbas.size(),
		demo.sepulturas_view.get_child_count()])

	var ojo := Camera3D.new()
	demo.add_child(ojo)
	ojo.current = true
	var mira := (secos[0] + secos[1]) * 0.5
	mira.y = demo.terrain.get_height_at(mira)
	ojo.global_position = mira + Vector3(0.0, 7.0, 8.0)
	ojo.look_at(mira, Vector3.UP)
	for f in range(40):
		sim.hour = 12.0
		await process_frame
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://sepultura.png")
		print("captura en %s" % ProjectSettings.globalize_path("user://sepultura.png"))
	quit()

