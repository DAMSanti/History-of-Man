extends SceneTree
## Rehace el recuadro local de un emplazamiento: relieve, cauces y contorno.
##
## Reutiliza LA MISMA tuberia que usa la partida -`RegionMap._found_settlement`-
## en vez de copiarla: el recuadro pasa por importacion, borrado de obra humana,
## erosion e hidrografia, y cualquiera de esos pasos que se quedara aqui a medias
## daria un valle distinto del que ve el jugador.
##
## `data/dem/local/` no se versiona -se rehace solo- pero hasta ahora solo se
## rehacia fundando el asentamiento a mano desde el mapa regional.
##
##   SITIO=56 godot --path . --script res://scripts/tools/RehacerSitio.gd
##
## Sin conexion tira de las teselas cacheadas en `data/dem/tiles` (zoom 13) y
## se salta el borrado de obra humana, que necesita Overpass.


func _init() -> void:
	var id := 56
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))

	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	if sitios == null:
		print("no hay emplazamientos horneados"); quit(1); return
	var sitio: Site = null
	for s: Site in sitios.sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("no existe el emplazamiento %d" % id); quit(1); return

	print("rehaciendo %s (id %d)" % [sitio.display_name(), id])
	change_scene_to_file("res://scenes/region_map.tscn")
	for i in range(90):
		await process_frame

	var mapa := current_scene
	if mapa == null or not ("_selected" in mapa):
		print("la capa regional no arranco"); quit(1); return

	mapa.set("_selected", sitio)
	# Sin red, Overpass no responde y el borrado de obra humana se queda
	# colgado en el tiempo de espera: se apaga a proposito.
	if "remove_human_works" in mapa:
		mapa.set("remove_human_works", false)
	await mapa._found_settlement()

	for i in range(30):
		await process_frame
	var salida := "res://data/dem/local/site_%d.res" % id
	print("%s: %s" % [salida,
		"escrito" if ResourceLoader.exists(salida) else "NO SE ESCRIBIO"])
	quit()
