extends SceneTree
## Qué animación usa cada especie MIENTRAS ANDA.
##
## «Hay animales que no mueven las patas» es una observación de pantalla, y en
## pantalla se confunden dos cosas: el que está quieto —que debe estar en
## reposo— y el que anda con la pose de reposo puesta, que es el fallo. Aquí se
## mira sólo a los que se están moviendo y se dice con qué clip se dibujan.

const SITE_ID := 56
const FRAMES := 900


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(60):
		await process_frame

	var demo := current_scene
	var herds: Node = null
	for child in demo.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with("WildlifeHerds.gd"):
			herds = child
	if herds == null:
		print("sin fauna"); quit(); return

	var moving: Dictionary = {}
	var frozen: Dictionary = {}
	for frame in range(FRAMES):
		await process_frame
		for animal: Dictionary in herds.animals():
			var species: String = animal["species"]
			var to_target: Vector3 = (animal["target"] as Vector3) \
				- (animal["position"] as Vector3)
			to_target.y = 0.0
			if to_target.length() < 3.0:
				continue
			moving[species] = int(moving.get(species, 0)) + 1
			var model: String = (WildlifeHerds.SPECIES_VISUAL[species] as Dictionary)["model"]
			var clips: Dictionary = WildlifeHerds.MOVE_CLIP.get(model, {})
			var clip: String = clips.get("slow", "idle")
			if clip == WildlifeHerds.IDLE_CLIP.get(model, "idle"):
				frozen[species] = int(frozen.get(species, 0)) + 1

	print("")
	print("%-10s %-8s %10s %10s" % ["especie", "malla", "andando", "con reposo"])
	for species: String in WildlifeHerds.SPECIES_VISUAL:
		var model: String = (WildlifeHerds.SPECIES_VISUAL[species] as Dictionary)["model"]
		print("%-10s %-8s %10d %10d %s" % [species, model,
			int(moving.get(species, 0)), int(frozen.get(species, 0)),
			"  <-- sin ciclo de marcha en su malla: va a saltos" if int(frozen.get(species, 0)) > 0 else ""])
	quit()
