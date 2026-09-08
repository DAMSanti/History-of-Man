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
##
## `tint` y `sat` son la GRADUACIÓN de color, y no son un capricho: la
## fotogrametría de la biblioteca está hecha en un prado inglés de junio, y esto
## es Cantabria hace quince mil años. El Magdaleniense es estepa fría —herbazal
## seco, pardo y ralo, con matorral enano— y ese material no existe en CC0: lo
## busqué y no está. Así que la textura pone la ESTRUCTURA —briznas, matas, tierra
## asomando— y el color se gradúa aquí.
##
## `sat` es cuánto se conserva del color original (1 = tal cual, 0 = gris) y
## `tint` lo que se multiplica después. Graduar es lo normal en producción: casi
## nadie usa el color de un escaneo en crudo.
##
## Ver SLICE_PALEOLITICO §8: «estepa fría con bosque de refugio en los valles,
## no el prado y el eucalipto de hoy».
const CATALOGUE := {
	Layer.PRADERA: {
		# El herbazal de estepa: se le quita la mitad del verde y se le empuja a
		# pardo pajizo. Es la capa que más manda en pantalla y la que más lejos
		# estaba de la época.
		# La dosis importa y la primera se quedó corta: con `sat` en 0,42 se
		# conserva casi la mitad del color original, y un verde saturado
		# sobrevive de sobra a eso. Para virar de verde a pajizo hay que
		# desaturar CASI del todo y dejar que el tinte ponga el color.
		"name": "Pradera", "asset": "Grass007", "tile_m": 4.0,
		"tint": Color(1.55, 1.32, 0.66), "sat": 0.22,
	},
	Layer.BOSQUE: {
		# El bosque de refugio sí es verde, pero de abedul y pino en valle
		# encajado: más oscuro y más frío que un prado a pleno sol.
		"name": "Suelo de bosque", "asset": "Ground037", "tile_m": 4.0,
		"tint": Color(0.86, 0.92, 0.70), "sat": 0.55,
	},
	Layer.ROQUEDO: {
		# Rock030 -«cliff, grey, rock, stone, wall»- en vez de Rock063, que
		# venía tan cubierto de musgo que parecía tapia de finca. La caliza
		# cántabra aflora desnuda y gris; el musgo lo pone el bosque, no la roca.
		"name": "Roquedo calizo", "asset": "Rock030", "tile_m": 6.0,
		"tint": Color(1.02, 1.01, 1.00), "sat": 0.45,
	},
	Layer.CANCHAL: {
		"name": "Canchal", "asset": "Rocks006", "tile_m": 3.0,
		"tint": Color(1.06, 1.03, 0.99), "sat": 0.55,
	},
	Layer.CANTOS: {
		# Cuarcita rodada: gris pálida y lavada. Si sale parda no se distingue
		# del cauce, y es la materia prima que hay que ver desde la cámara.
		"name": "Cantos de río", "asset": "Gravel041", "tile_m": 2.0,
		"tint": Color(1.04, 1.03, 1.02), "sat": 0.60,
	},
	Layer.ARENA: {
		"name": "Arena", "asset": "Ground095A", "tile_m": 3.0,
		"tint": Color(1.06, 1.00, 0.90), "sat": 0.70,
	},
	Layer.LIMO: {
		# Ground095C parecía mejor por etiquetas -wet, dark, layered- pero no
		# existe: da 404. Ground026 es fango liso de arcilla, que es lo que deja
		# una marisma cuando baja la marea.
		"name": "Limo de marisma", "asset": "Ground026", "tile_m": 3.5,
		"tint": Color(0.88, 0.87, 0.84), "sat": 0.55,
	},
	Layer.NIEVE: {
		"name": "Nieve", "asset": "Snow010A", "tile_m": 5.0,
		"tint": Color(1.00, 1.00, 1.02), "sat": 0.35,
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


## La graduación de color de cada capa, en el orden del array.
static func tints_in_order() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(COUNT):
		var tint: Color = CATALOGUE[i]["tint"]
		out.append(Vector3(tint.r, tint.g, tint.b))
	return out


## Cuánto se conserva del color original de cada capa, en el orden del array.
static func saturations_in_order() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(COUNT):
		out.append(CATALOGUE[i]["sat"] as float)
	return out


static func display_name(layer: Layer) -> String:
	return CATALOGUE[layer]["name"] as String
