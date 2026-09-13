extends SceneTree
## El frío de una noche en la escena de verdad, invierno contra verano.
##
## `TestFrio` prueba la regla llamando a `SettlementSim._frio_de_una_noche` a
## mano. Esto prueba lo que ella no puede: que las ramas de sueño de verdad —la
## cueva, el vivac, el que duerme donde le coge— la usan. Se deja correr la
## simulación una noche con el hogar apagado, en invierno y en verano, y se
## suma el frío de la banda.
##
## Construye el estado en vez de esperar al invierno: pone la estación y la
## hora y apaga el fuego. Una noche, no un año.

const SITE_ID := 56


func _init() -> void:
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar la escena")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	for estacion in [Subsistence.Season.VERANO, Subsistence.Season.INVIERNO]:
		var frio := await _una_noche(sim, estacion)
		print("NOCHE %s: frio medio de la banda %.2f · grados en el abrigo %.1f" % [
			Subsistence.season_name(estacion), frio,
			Termometro.grados(estacion, 3.0,
				sim.terrain().get_height_at(sim.home_position))])
	quit()


func _una_noche(sim: SettlementSim, estacion: Subsistence.Season) -> float:
	GameState.season = estacion
	for p: Inhabitant in sim.people:
		p.cold = 0.0
	sim.hour = 22.0
	sim.time_scale = 20.0
	var hasta := sim.day + 1
	while not (sim.day >= hasta and sim.hour >= 5.0):
		# El hogar lo enciende `Hogar` en cuanto hay leña: para que la noche sea
		# de verdad sin fuego, se le quita la leña y se apaga en cada vuelta.
		sim.store.take(Materia.Kind.LENA, sim.store.amount(Materia.Kind.LENA))
		sim.hearth_lit = false
		await process_frame
	sim.time_scale = 0.0
	var total := 0.0
	for p: Inhabitant in sim.people:
		total += p.cold
	return total / maxf(float(sim.people.size()), 1.0)


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		return null
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
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		return null
	return demo
