extends SceneTree
## Todas las bocas de cueva de todos los mapas horneados: ¿alguna en el agua o
## donde no se llega andando desde casa?
##
## Frente 21 de EPOCA_01 §10.1, tanda 4, criterio: «ninguna boca queda en agua
## ni fuera de la zona a la que se llega andando desde la cueva de la banda, con
## el número de bocas movidas y cuánto se movió cada una».
##
## Mira la partida DE VERDAD: entra en cada mapa como entra el mapa regional y
## le pregunta a la rejilla de la simulación —la que usa la marcha, ya con las
## entalladuras excavadas—, no a la que usó [Bocas] para colocarlas. Si las dos
## no coinciden, es aquí donde sale.
##
## Uso (con ventana o sin ella):
##   godot --headless --path . --script res://scripts/tests/CuevasProbe.gd

const MAR_PALEOLITICO := -120.0


func _init() -> void:
	# Una sonda no escribe en los mapas del jugador. Ver [Guardado.carpeta].
	Guardado.carpeta = "user://sondas/mapas"
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	var por_id := {}
	for site: Site in sitios.sites:
		por_id[site.id] = site

	var mapas: Array[int] = []
	for nombre: String in DirAccess.get_files_at("res://data/dem/local"):
		var trozos := nombre.trim_suffix(".res").split("_")
		if trozos.size() == 2 and trozos[0] == "site" and trozos[1].is_valid_int() \
				and por_id.has(int(trozos[1])):
			mapas.append(int(trozos[1]))
	print("mapas horneados con sitio en el conjunto: %s" % str(mapas))

	var total := 0
	var malas := 0
	var movidas := 0
	for id: int in mapas:
		var site: Site = por_id[id]
		_preparar(site)
		change_scene_to_file("res://scenes/demo_main.tscn")
		for i in range(90):
			await process_frame
		var demo := current_scene
		var sim: SettlementSim = demo.sim if "sim" in demo else null
		if sim == null:
			print("sitio %d: sin simulacion" % id)
			continue
		var terreno: TerrainGenerator = demo.terrain
		var grid := sim.navgrid()
		for boca: Dictionary in terreno.carvings_colocadas:
			total += 1
			var queda: Vector3 = boca["position"]
			var agua := terreno.crossing_difficulty_at(queda) > 0.0
			var anda := grid.passable(queda)
			var llega := grid.connected(sim.home_position, queda)
			var movida := float(boca.get("movida_m", 0.0))
			if movida > 0.0:
				movidas += 1
			# `se anda` es la celda de la boca, y se enseña sin contar como mal:
			# una boca en ladera tiene la celda cerrada por pendiente y se llega
			# desde la de al lado. Ver [Bocas.vale].
			var mal := agua or not llega
			if mal:
				malas += 1
			print("  sitio %d · boca %d · movida %.0f m · agua %s · se anda %s · se llega %s%s" % [
				id, int(boca.get("feature", -1)), movida, agua, anda, llega,
				"   <-- MAL" if mal else ""])
		demo.queue_free()
		for i in range(5):
			await process_frame

	print("")
	print("bocas %d · movidas %d · mal colocadas %d" % [total, movidas, malas])
	quit(0 if malas == 0 else 1)


## Lo que deja el mapa regional al entrar. Ver [RegionMap._enter_local].
func _preparar(site: Site) -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % site.id)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % site.id
	Expedition.sea_level_m = MAR_PALEOLITICO
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.retomando = false
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
