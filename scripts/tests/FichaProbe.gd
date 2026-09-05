extends SceneTree
## Compara lo que la banda TRAE con lo que las fichas de paraje DICEN.
##
## Queja del jugador: «no sé de dónde están sacando frutos secos, bayas,
## bellotas, setas... cuando ningún paraje muestra que lo tiene».

const SITE_ID := 56
const DAYS := 25

var _scene: Node
var _frames := 0


func _initialize() -> void:
	var set_res: SiteSet = load("res://data/sites/cantabria_sites.res")
	var chosen: Site = null
	for s: Site in set_res.sites:
		if s.id == SITE_ID:
			chosen = s
			break

	var path := "res://data/dem/local/site_%d.res" % SITE_ID
	var local: HeightmapData = load(path)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5

	Expedition.site = chosen
	Expedition.heightmap_path = path
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(chosen.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(chosen.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))

	_scene = (load("res://scenes/demo_main.tscn") as PackedScene).instantiate()
	get_root().add_child(_scene)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 15:
		return false
	_run()
	return true


func _run() -> void:
	var sim: SettlementSim = _scene.get("sim")
	sim.time_scale = 1.0

	var step := sim.seconds_per_day / 24.0 / 60.0
	for _day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)

	print("=== ESTACION: %s ===" % Subsistence.season_name(
		GameState.season as Subsistence.Season))

	print("=== PARAJES (%d) ===" % sim.parajes.list.size())
	var en_ficha := {}
	for paraje: Paraje in sim.parajes.list:
		var bits: Array[String] = []
		for row: Dictionary in paraje.listing():
			en_ficha[int(row["kind"])] = true
			bits.append("%s %.2f%s" % [
				Materia.material_name(row["kind"] as Materia.Kind),
				float(row["abundancia"]), "" if bool(row["sabido"]) else "?"])
		print("  %-30s %s" % [paraje.name_text, ", ".join(bits)])

	print("=== LO QUE HAY EN EL ALMACEN ===")
	var falta: Array[String] = []
	for kind_key: int in Materia.Kind.values():
		var kind := kind_key as Materia.Kind
		var have := sim.store.amount(kind)
		if have <= 0.0:
			continue
		var donde := "en ficha" if en_ficha.has(kind_key) else "NO SALE EN NINGUN PARAJE"
		if not en_ficha.has(kind_key):
			falta.append(Materia.material_name(kind))
		print("  %-14s %8.1f   %s" % [Materia.material_name(kind), have, donde])

	print("=== SIN FICHA: %s ===" % (", ".join(falta) if not falta.is_empty() else "nada"))
