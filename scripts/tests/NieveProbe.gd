extends SceneTree
## La cota de nieve en la escena de verdad, por estación.
##
## `TestTermometro` prueba la cuenta con un relieve puesto a mano. Esto prueba lo
## que ella no puede: que `SettlementSim.setup` le da a `Temporada` el relieve
## del mapa ANTES de que nadie pregunte por la nieve. Sin él la cota sale «por
## encima de todo» y no nieva en ninguna parte, en silencio.

const SITE_ID := 56


func _init() -> void:
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar la escena")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	print("relieve del mapa: %s" % str(sim.temporada.relieve))
	if sim.temporada.relieve.y <= sim.temporada.relieve.x:
		print("SIN RELIEVE: la nieve no se sabe donde cae")
		quit(1)
		return
	for estacion in [Subsistence.Season.INVIERNO, Subsistence.Season.PRIMAVERA,
			Subsistence.Season.OTONO, Subsistence.Season.VERANO]:
		var f := sim.temporada.fraccion_de(estacion)
		var cumbre := sim.temporada.relieve.y
		print("NIEVE %s: cota %.0f m · fraccion %.2f · %s" % [
			Subsistence.season_name(estacion), Termometro.cota_de_hielo(estacion), f,
			"nieva dentro del mapa" if f < 1.0 else "por encima de la cumbre (%.0f m)" % cumbre])
	quit()


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
