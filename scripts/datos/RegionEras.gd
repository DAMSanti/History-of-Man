@tool
class_name RegionEras
extends Resource
## Mascaras de area jugable para cada cota del mar.
##
## La frontera no es fija: el territorio de una epoca es Cantabria mas la
## plataforma que este emergida entonces. Calcular cada mascara cuesta ~5 s,
## asi que se hornean y se guardan.

@export var sea_levels: PackedFloat32Array = PackedFloat32Array()
## Una mascara por cota, 1 byte por celda
@export var masks: Array[PackedByteArray] = []
@export var width: int = 0
@export var height: int = 0


## Indice de la cota mas cercana a la pedida
func index_for(sea_level_m: float) -> int:
	var best := 0
	var best_gap := INF
	for i in range(sea_levels.size()):
		var gap: float = absf(sea_levels[i] - sea_level_m)
		if gap < best_gap:
			best_gap = gap
			best = i
	return best


## Textura de mascara lista para el shader del terreno
func mask_texture(index: int) -> ImageTexture:
	if index < 0 or index >= masks.size():
		return null
	var image := Image.create_from_data(width, height, false, Image.FORMAT_R8, masks[index])
	return ImageTexture.create_from_image(image)
