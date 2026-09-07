extends SceneTree
## Que en pausa no se mueva nada.
##
## Pausar es la forma de MIRAR: se para el tiempo para leer una ficha, contar
## la banda o seguir a un ciervo. Si al pausar la fauna sigue andando, lo que
## el jugador ve no es una foto, es un plano con la mitad de las cosas
## corriendo, y ademas se le escapa justo lo que queria mirar.
##
## Se mide en metros: cuanto se ha desplazado cada animal y cada persona entre
## dos instantes, con el reloj parado y con el reloj andando.

const SITE_ID := 56


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
	for i in range(90):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var herds: Node = demo.herds if "herds" in demo else null
	if sim == null or herds == null:
		print("sin simulacion o sin fauna"); quit(); return

	sim.assign_default_jobs()
	# Un rato andando, para que la fauna tenga rumbo y la banda haya salido.
	sim.time_scale = 8.0
	for i in range(240):
		await process_frame

	print("")
	print("=== LO QUE SE MUEVE, EN PAUSA Y ANDANDO ===")
	for entry: Array in [["EN PAUSA", 0.0], ["andando", 8.0]]:
		sim.time_scale = float(entry[1])
		# Un cuadro para que el cambio de escala cuaje antes de medir.
		await process_frame
		var animals_before := _animal_spots(herds)
		var people_before := _people_spots(sim)
		for i in range(45):
			await process_frame
		var animals_after := _animal_spots(herds)
		var people_after := _people_spots(sim)
		print("%-9s fauna %6.2f m de media (la que mas, %6.2f) · banda %6.2f m" % [
			String(entry[0]),
			_mean_shift(animals_before, animals_after),
			_worst_shift(animals_before, animals_after),
			_mean_shift(people_before, people_after)])
	print("")
	print("y el reloj: hora %.4f" % sim.hour)
	quit()


func _animal_spots(herds: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for animal: Dictionary in herds._animals:
		out.append(animal["position"] as Vector3)
	return out


func _people_spots(sim: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for person: Inhabitant in sim.people:
		out.append(person.position)
	return out


func _mean_shift(before: Array[Vector3], after: Array[Vector3]) -> float:
	var total := 0.0
	var count := mini(before.size(), after.size())
	for i in range(count):
		total += before[i].distance_to(after[i])
	return total / maxf(float(count), 1.0)


func _worst_shift(before: Array[Vector3], after: Array[Vector3]) -> float:
	var worst := 0.0
	for i in range(mini(before.size(), after.size())):
		worst = maxf(worst, before[i].distance_to(after[i]))
	return worst
