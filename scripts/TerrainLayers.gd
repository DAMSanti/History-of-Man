class_name TerrainLayers
extends RefCounted
## Las capas de material del terreno, y de dónde sale la textura de cada una.
##
## El orden del enum ES el índice dentro del `Texture2DArray`, así que no se
## reordena: cambiarlo sin regenerar los arrays repinta el mapa entero con los
## materiales cambiados de sitio.
##
## Las cuatro de antes —hierba, roca, nieve, arena— eran ruido pintado píxel a
## píxel desde GDScript. Éstas son fotogrametría de [ambientCG], CC0, y salen de
## los biomas que pide SLICE_PALEOLITICO §8: el Magdaleniense cantábrico es
## estepa fría con bosque de refugio en los valles, roquedo calizo, canchal, y
## una costa con arena y marisma.
##
## Que haya ocho y no cuatro no cuesta muestreos: el coste lo fija cuántas están
## activas en un píxel, que siguen siendo dos. Cuesta VRAM, que sobra.

enum Layer {
	PRADERA,   ## Herbazal frío. La capa de fondo del valle
	BOSQUE,    ## Hojarasca y humus bajo el bosque de refugio
	ROQUEDO,   ## Caliza gris. Cantabria es caliza, no granito
	CANCHAL,   ## Derrubio de ladera: aristas vivas, no canto rodado
	CANTOS,    ## Cuarcita rodada de cauce. LA materia prima del juego
	ARENA,     ## Playa
	LIMO,      ## Fango de estuario. Donde va el conchero
	NIEVE,     ## Alta cota
}

## Cuántas capas hay. El shader lo necesita como constante.
const COUNT := 8

## Qué asset de ambientCG da cada capa, y con qué nombre se enseña.
##
## `tile_m` es el lado que ocupa una tesela sobre el terreno, en metros. No es
## decorativo: fija la densidad de téxeles y por tanto si la textura se lee como
## material o como manchurrón. Los cantos van más finos que la pradera porque
## un canto rodado mide un palmo y la mata de hierba no.
const CATALOGUE := {
	Layer.PRADERA: {
		"name": "Pradera", "asset": "Grass007", "tile_m": 4.0,
	},
	Layer.BOSQUE: {
		"name": "Suelo de bosque", "asset": "Ground037", "tile_m": 4.0,
	},
	Layer.ROQUEDO: {
		"name": "Roquedo calizo", "asset": "Rock063", "tile_m": 6.0,
	},
	Layer.CANCHAL: {
		"name": "Canchal", "asset": "Rocks006", "tile_m": 3.0,
	},
	Layer.CANTOS: {
		"name": "Cantos de río", "asset": "Gravel041", "tile_m": 2.0,
	},
	Layer.ARENA: {
		"name": "Arena", "asset": "Ground095A", "tile_m": 3.0,
	},
	Layer.LIMO: {
		# Ground095C parecía mejor por etiquetas -wet, dark, layered- pero no
		# existe: da 404. Ground026 es fango liso de arcilla, que es lo que deja
		# una marisma cuando baja la marea.
		"name": "Limo de marisma", "asset": "Ground026", "tile_m": 3.5,
	},
	Layer.NIEVE: {
		"name": "Nieve", "asset": "Snow010A", "tile_m": 5.0,
	},
}

## Lado de la textura, en píxeles.
##
## 1K y no 2K, y el motivo es una cuenta y no una preferencia: a la distancia
## mínima de cámara —unos 30 m, con `ground_clearance` en 12— los 1920 píxeles
## de ancho cubren unos 30 m de suelo, o sea 64 píxeles por metro. Una textura
## de 1024 con tesela de 4 m da 256 por metro: cuatro veces de sobra. Subir a 2K
## multiplica por cuatro la VRAM y el tráfico para un detalle que no cabe en
## pantalla.
##
## Si algún día la cámara baja mucho más, se sube esto y se vuelve a ingerir.
const SIZE := 1024

## Dónde quedan los arrays ya empaquetados. Se regeneran con
## `scripts/tools/TerrainTextureIngest.gd` y no van al repositorio: son 34 MB
## que se reconstruyen solos.
const ARRAYS_PATH := "res://textures/terrain/terrain_arrays.res"


## Los assets en orden de índice, que es como los espera el array.
static func assets_in_order() -> Array[String]:
	var out: Array[String] = []
	for i in range(COUNT):
		out.append(CATALOGUE[i]["asset"] as String)
	return out


## El lado de tesela de cada capa, en el orden del array. Va al shader como
## vector de uniforms para que cada material tenga su escala propia.
static func tiles_in_order() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(COUNT):
		out.append(CATALOGUE[i]["tile_m"] as float)
	return out


static func display_name(layer: Layer) -> String:
	return CATALOGUE[layer]["name"] as String
