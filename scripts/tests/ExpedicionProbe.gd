extends SceneTree
## La expedición en la escena de verdad, no en una prueba.
##
## Las pruebas de `TestExpedicion` y `TestContacto` construyen la simulación a
## mano y le pasan la comarca. Esto comprueba lo que ellas no pueden: que
## [DemoMain] le da a la simulación la comarca horneada y reparte quién vive
## dónde. Sin ese cableado todo compilaba y la expedición volvía sin descubrir
## nada, con nadie viviendo en ninguna parte.
##
## No simula jornadas: manda la expedición, adelanta el día hasta la vuelta y
## llama al cierre, que es lo que el paso fijo haría. Segundos, no un año.

const SITE_ID := 56


func _init() -> void:
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar la escena")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0

	print("comarca cargada: %s" % ("SI" if sim.expedicion.sitios != null else "NO"))
	print("emplazamientos con gente: %d" % sim.contacto.ocupados.size())
	print("conocidos al empezar: %d" % GameState.discovered.size())

	if sim.contacto.ocupados.is_empty():
		print("NADIE VIVE EN NINGUNA PARTE: el reparto no se ha hecho")
		quit(1)
		return

	var destino: int = sim.contacto.ocupados.keys()[0]
	var comida_antes := sim.store.food_rations()
	var salio := sim.expedicion.mandar(3, destino)
	print("sale hacia %d: %s · raciones que se lleva: %.1f" % [
		destino, "SI" if salio else "NO", comida_antes - sim.store.food_rations()])
	if not salio:
		quit(1)
		return

	var antes := GameState.discovered.size()
	sim.day = sim.expedicion.vuelve_el_dia
	sim.expedicion.nuevo_dia()
	print("vuelve · descubiertos: %d -> %d (+%d) · jornadas-persona: %d" % [
		antes, GameState.discovered.size(),
		GameState.discovered.size() - antes, sim.expedicion.jornadas_persona])
	print("contacto con %d: %s · gente conocida: %d" % [
		destino, "SI" if sim.contacto.se_conocen(destino) else "NO",
		sim.contacto.conocidos()])
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
