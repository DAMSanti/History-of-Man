extends SceneTree
## Rehace el recuadro local de un emplazamiento: relieve, cauces y contorno.
##
## Reutiliza LA MISMA tuberia que usa la partida -[PreparaValle], la de fundar
## desde el mapa regional y la de migrar desde la ficha de un campamento- en vez
## de copiarla: el recuadro pasa por importacion, borrado de obra humana, erosion
## e hidrografia, y cualquiera de esos pasos que se quedara aqui a medias daria un
## valle distinto del que ve el jugador.
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
	var preparador := PreparaValle.new()
	# Sin red, Overpass no responde y el borrado de obra humana se queda
	# colgado en el tiempo de espera: se apaga a proposito.
	preparador.remove_human_works = false
	await preparador.preparar(self, sitio)

	for i in range(30):
		await process_frame
	var salida := "res://data/dem/local/site_%d.res" % id
	print("%s: %s" % [salida,
		"escrito" if ResourceLoader.exists(salida) else "NO SE ESCRIBIO"])
	quit()
