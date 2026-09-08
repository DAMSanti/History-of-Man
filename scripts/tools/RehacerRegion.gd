extends SceneTree
## Rehace el MDT de la region a partir de las teselas ya cacheadas.
##
## `data/dem/` no se versiona -son 667 MB que se reconstruyen solos, ver
## .gitignore- pero NADA lo reconstruia sin pasar por la interfaz: `RegionMap`
## carga `cantabria_region.res` y da error si falta, y `BakeRegion` lo consume.
## Sin esta herramienta, perder ese fichero obligaba a rehacer el proyecto a
## mano.
##
## El recuadro sale de la frontera ya horneada -`data/boundaries/cantabria.res`,
## que si esta versionada- para no repetir las coordenadas en dos sitios.
##
##   godot --headless --path . --script res://scripts/tools/RehacerRegion.gd
##
## ZOOM=10 para elegir la escala. Con las teselas en `data/dem/tiles` no hace
## falta red; si falta alguna, se baja de AWS Terrain Tiles.

const FRONTERA := "res://data/boundaries/cantabria.res"
const SALIDA := "res://data/dem/cantabria_region.res"

## Margen alrededor de la frontera, en grados. El mapa regional enseña algo de
## mar y de meseta alrededor: cortar justo por la linea deja la costa pegada al
## borde de la pantalla.
const MARGEN := 0.15


func _init() -> void:
	var frontera: RegionBoundary = load(FRONTERA)
	if frontera == null:
		print("no se pudo cargar %s" % FRONTERA); quit(1); return

	var zoom := 10
	if not OS.get_environment("ZOOM").is_empty():
		zoom = int(OS.get_environment("ZOOM"))

	print("recuadro de la frontera: lat %.4f..%.4f · lon %.4f..%.4f" % [
		frontera.lat_min, frontera.lat_max, frontera.lon_min, frontera.lon_max])

	var datos := DEMImporter.new().import_area(
		frontera.lat_max + MARGEN, frontera.lat_min - MARGEN,
		frontera.lon_min - MARGEN, frontera.lon_max + MARGEN, zoom)
	if datos == null:
		print("la importacion no devolvio nada"); quit(1); return

	var error := ResourceSaver.save(datos, SALIDA)
	print("%s: %d x %d muestras · guardado %s" % [
		SALIDA, datos.width, datos.height, "OK" if error == OK else "ERROR %d" % error])
	quit(0 if error == OK else 1)
