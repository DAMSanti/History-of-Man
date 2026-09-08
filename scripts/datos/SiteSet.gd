@tool
class_name SiteSet
extends Resource
## Conjunto de emplazamientos ya derivados.
##
## Se guarda en disco porque derivarlos cuesta ~20 s y el resultado es estatico:
## depende solo del DEM, que no cambia en tiempo de juego. Pagarlo en cada
## arranque no tendria sentido.

@export var sites: Array[Site] = []
@export var source_heightmap: String = ""
@export var derived_at_sea_levels: PackedFloat32Array = PackedFloat32Array()


func playable() -> Array[Site]:
	var out: Array[Site] = []
	for s: Site in sites:
		if s.inside_region:
			out.append(s)
	return out


## Los que ademas se pueden ocupar con la tecnica de una epoca.
## Los demas siguen en el conjunto: no desaparecen, es que todavia no sabes
## como habitarlos.
func available_in(sea_level_m: float, era: Site.Era) -> Array[Site]:
	var out: Array[Site] = []
	for s: Site in sites:
		if s.inside_region and s.is_available(sea_level_m) and s.is_usable_in(era):
			out.append(s)
	return out


## Los disponibles con el mar a una cota dada
func available(sea_level_m: float) -> Array[Site]:
	var out: Array[Site] = []
	for s: Site in sites:
		if s.inside_region and s.is_available(sea_level_m):
			out.append(s)
	return out
