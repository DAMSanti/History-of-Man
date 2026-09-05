extends SceneTree
## Prueba de carga cronometrada del mapa local, sin pasar por el mapa regional.
##
## Reutiliza el recuadro ya bakeado del sitio de prueba (Torrelavega, id 9000)
## para medir el coste de _ready() de DemoMain / TerrainGenerator.generate()
## en aislamiento, sin repetir la descarga de MDT.
##
## Uso:
##   godot --headless --path . --script res://scripts/tests/RunLocalTiming.gd --quit-after 20

const SITE_ID := 9000
const SITE_LAT := 43.34894
const SITE_LON := -4.04601
const HEIGHTMAP_PATH := "res://data/dem/local/site_9000.res"


func _init() -> void:
	var t0 := Time.get_ticks_msec()

	if not ResourceLoader.exists(HEIGHTMAP_PATH):
		print("RunLocalTiming: no existe %s, funda antes una vez en el sitio de prueba" % HEIGHTMAP_PATH)
		quit(1)
		return

	var hm: HeightmapData = load(HEIGHTMAP_PATH)

	var site := Site.new()
	site.id = SITE_ID
	site.lat = SITE_LAT
	site.lon = SITE_LON
	site.historical_name = "Torrelavega (prueba)"
	site.inside_region = true
	site.notable = true
	site.fidelity = Site.Fidelity.ATESTIGUADO
	site.has_shelter = true
	site.kind = Site.Kind.VALLE
	site.water_km = 0.4
	site.coast_km = 8.0
	site.slope_deg = 3.0

	var size_m := hm.get_world_size_meters()
	var u := hm.u_for_lon(site.lon)
	var v := hm.v_for_lat(site.lat)
	var half := float(Expedition.local_size_m) * 0.5

	Expedition.site = site
	Expedition.heightmap_path = HEIGHTMAP_PATH
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(u * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(v * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	print("[TIMING] preparacion de Expedition: %d ms" % (Time.get_ticks_msec() - t0))

	var scene: PackedScene = load("res://scenes/demo_main.tscn")
	var inst := scene.instantiate()
	get_root().add_child(inst)
