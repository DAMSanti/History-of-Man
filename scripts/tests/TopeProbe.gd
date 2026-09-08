extends SceneTree
## El vaiven del tope de comida, dia a dia.
##
## Queja del jugador: «llegan al tope de comida y no cogen mas, llega la
## noche, comen, baja del maximo y entonces vuelven a salir a por comida; es
## un circulo vicioso».

const SITE_ID := 56
const DAYS := 45

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

	# Un tope como el que pondria el jugador: unos diez dias de comida
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	sim.food_cap = mouths * 10.0
	print("=== TOPE %.0f raciones (%d bocas, %.1f raciones al dia) ===" % [
		sim.food_cap, sim.people.size(), mouths])

	var step := sim.seconds_per_day / 24.0 / 60.0
	var flips := 0
	var previous := sim.despensa.food_is_capped()
	var dias_libres := 0
	for _day in range(DAYS):
		for _tick in range(24 * 60):
			sim._process(step)

		var capped := sim.despensa.food_is_capped()
		if capped != previous:
			flips += 1
			previous = capped
		if capped:
			dias_libres += 1

		var comiendo := 0
		for person: Inhabitant in sim.people:
			if person.job == Profession.Job.CAZA \
					or person.job == Profession.Job.RIBERA \
					or person.job == Profession.Job.RECOLECCION:
				comiendo += 1
		var states := {}
		var hambre := 0.0
		for person: Inhabitant in sim.people:
			var key := int(person.state)
			states[key] = int(states.get(key, 0)) + 1
			hambre += person.hunger
		print("dia %2d  raciones %6.1f / %.0f  %-6s  a por comida %2d de %d  hambre media %.0f  estados %s" % [
			sim.day, sim.store.food_rations(), sim.food_cap,
			"LLENO" if capped else "", comiendo, sim.people.size(),
			hambre / float(sim.people.size()), JSON.stringify(states)])
		if not sim.stuck_tally.is_empty():
			print("        atascos: %s" % JSON.stringify(sim.stuck_tally))

	print("=== %d cambios de estado en %d dias, %d dias sin salir a por comida ===" % [
		flips, DAYS, dias_libres])
