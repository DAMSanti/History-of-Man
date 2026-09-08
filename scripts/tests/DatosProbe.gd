extends SceneTree
## Que los datos horneados siguen cargando y con contenido.
##
## Existe porque mover de carpeta una clase que va DENTRO de un `.res` puede
## dejar el fichero cargando «bien» pero VACIO, y eso no se ve hasta que la
## partida no encuentra ningun emplazamiento. Ver `tools/MigrarEsquema.gd`.


func _init() -> void:
	var sitios: SiteSet = load("res://data/sites/cantabria_sites.res")
	print("emplazamientos: %d" % (sitios.sites.size() if sitios else -1))
	if sitios:
		print("  jugables: %d" % sitios.playable().size())
		var uno: Site = sitios.sites[0] if not sitios.sites.is_empty() else null
		if uno:
			print("  el primero: %s (%.4f, %.4f)" % [uno.historical_name, uno.lat, uno.lon])
	var frontera: RegionBoundary = load("res://data/boundaries/cantabria.res")
	print("frontera: %d anillos" % (frontera.rings.size() if frontera else -1))
	var eras: RegionEras = load("res://data/sites/cantabria_eras.res")
	print("mascaras de era: %s" % ("si" if eras else "NO"))
	quit()
