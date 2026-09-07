extends SceneTree
## Una manada de cerca, andando, en la partida de verdad.
##
## `FaunaRumboProbe` comprueba la orientación de cada malla en el banco; esto
## comprueba lo otro: que en el valle se vea a la caza mayor andar y girar. Se
## busca en vivo un animal que se esté MOVIENDO y se le hace la foto desde la
## distancia a la que se juega.
##
##   ESPECIE=ciervo   a cuál seguir

const SITE_ID := 56
const FRAMES := 4000


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan datos"); quit(); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if site == null:
		print("sin emplazamiento"); quit(); return

	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(240):
		await process_frame

	var demo := current_scene
	var herds: Node = null
	for child in demo.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with("WildlifeHerds.gd"):
			herds = child
	if herds == null:
		print("sin fauna"); quit(); return

	# A mediodía: la partida arranca a las 6:00 y con el valle a oscuras no se
	# ve andar a nadie.
	if "sim" in demo and demo.sim != null:
		demo.sim.hour = 13.0

	var wanted := OS.get_environment("ESPECIE")
	if wanted.is_empty():
		wanted = "ciervo"

	var camera := Camera3D.new()
	camera.far = 4000.0
	demo.add_child(camera)
	_hide_ui(demo)

	for frame in range(FRAMES):
		await process_frame
		for animal: Dictionary in herds._animals:
			if String(animal["species"]) != wanted:
				continue
			var to_target: Vector3 = (animal["target"] as Vector3) \
				- (animal["position"] as Vector3)
			to_target.y = 0.0
			if to_target.length() < 6.0:
				continue
			var here: Vector3 = animal["position"]
			var side := Vector3(-to_target.z, 0.0, to_target.x).normalized()
			# De costado y un poco por detrás: de frente no se ve andar a nadie.
			camera.global_position = here + side * 9.0 + Vector3(0.0, 4.0, 0.0)
			camera.look_at(here + Vector3(0.0, 1.0, 0.0), Vector3.UP)
			camera.make_current()
			for i in range(4):
				await process_frame
			root.get_texture().get_image().save_png(
				"user://fauna_%s.png" % wanted)
			print("%s andando, rumbo %.0fº" % [wanted,
				rad_to_deg(float(animal["heading"]))])
			print("captura en %s" % ProjectSettings.globalize_path("user://"))
			quit()
			return

	print("no se pillo ningun %s en movimiento" % wanted)
	quit()


func _hide_ui(node: Node) -> void:
	var layer := node as CanvasLayer
	if layer != null:
		layer.visible = false
		return
	for child in node.get_children():
		_hide_ui(child)
