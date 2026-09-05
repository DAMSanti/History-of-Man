extends SceneTree
## Que el detalle inventado se apague solo cuando el dato ya lo sabe.
##
## Comprueba la regla de `_effective_detail_amplitude`: con el MDT05 del IGN
## -5,00 m por muestra sobre una malla de 4,97 m- no queda interpolacion que
## romper y el ruido debe irse a cero; con el terrarium de 13,9 m si hace falta
## y debe entrar entero.

const RESOLUTION := 825


func _init() -> void:
	var ign: HeightmapData = load("res://data/dem/local/site_56.res")
	if ign == null:
		print("no hay MDT local del sitio 56")
		quit()
		return

	print("techo de detalle (inspector): 1.5")
	print("")
	_case("IGN MDT05", ign, 5.0)
	_case("terrarium z13", ign, 13.91)
	_case("terrarium z10 (regional)", ign, 111.0)
	quit()


## Se reutiliza el mismo heightmap cambiandole el paso declarado: lo que se
## prueba es la REGLA, no el fichero.
func _case(label: String, heightmap: HeightmapData, meters_per_sample: float) -> void:
	var copy: HeightmapData = heightmap.duplicate()
	copy.meters_per_sample = meters_per_sample

	var terrain := TerrainGenerator.new()
	terrain.terrain_size = Vector2i(Expedition.local_size_m, Expedition.local_size_m)
	terrain.resolution = RESOLUTION
	terrain.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
	terrain.heightmap = copy
	terrain.detail_amplitude = 1.5

	var spacing := float(Expedition.local_size_m) / float(RESOLUTION - 1)
	var effective: float = terrain.call("_effective_detail_amplitude")
	print("%-26s dato %6.2f m / malla %.2f m = %.2f  ->  amplitud %.3f" % [
		label, meters_per_sample, spacing, meters_per_sample / spacing, effective])
	terrain.free()
