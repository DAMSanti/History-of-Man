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
	HOJARASCA, ## Las hojas caidas del bosque. Solo en otoño: ver [Temporada.hojarasca]
}

## Cuántas capas hay. El shader lo necesita como constante.
##
## **Nueve desde el 2026-09-17**: entró la hojarasca, que no es un sitio del valle sino una
## ESTACIÓN del suelo de bosque —el usuario eligió Ground003 para el bosque y Ground041
## «en otoño»—. Se mezcla con el peso que le da [Temporada.hojarasca], no con la altura ni
## la pendiente como las otras ocho. GRAFICOS §7.7.
const COUNT := 9

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
		#
		# Ground003 en vez de Ground037 (elegido por el usuario el 2026-09-17 sobre la hoja
		# de contacto): el de antes era tierra con briznas y su altura era la más floja de
		# las ocho —desviación típica 0,053—, o sea que con el relieve enchufado de verdad
		# no habría dado nada. Éste trae matas con bulto.
		"name": "Suelo de bosque", "asset": "Ground003", "tile_m": 4.0,
		"tint": Color(0.86, 0.92, 0.70), "sat": 0.55,
	},
	Layer.ROQUEDO: {
		# Rock023 en vez de Rock030 (elegido por el usuario el 2026-09-17): «textura de
		# pared de caliza con sus grietas y tal». Es caliza gris en estratos, y **las
		# grietas están en el mapa de altura**, que es lo que ahora dibuja el relieve. La de
		# antes era piedra oscura y manchada: su altura eran bultos difusos.
		#
		# *(Y antes de aquélla estuvo Rock063, que venía tan cubierto de musgo que parecía
		# tapia de finca. La caliza cántabra aflora desnuda y gris.)*
		"name": "Roquedo calizo", "asset": "Rock023", "tile_m": 6.0, "relieve": 2.0,
		"tint": Color(1.02, 1.01, 1.00), "sat": 0.45,
	},
	Layer.CANCHAL: {
		# Rocks002 en vez de Rocks006 (elegido por el usuario el 2026-09-17): «en los
		# rocales, texturas de rocas con heightmaps de cada una de las rocas». Son cantos
		# sueltos que se leen uno a uno y su altura marca cada uno; el de antes era grava
		# fina, casi arena gruesa, y su altura era ruido.
		"name": "Canchal", "asset": "Rocks002", "tile_m": 3.0, "relieve": 3.0,
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
	Layer.HOJARASCA: {
		# LAS HOJAS DEL OTOÑO. No es un sitio del valle: es el suelo de bosque cuando cae
		# la hoja, y por eso su peso no sale de la altura ni de la pendiente sino de la
		# estación ([Temporada.hojarasca]). Elegida por el usuario el 2026-09-17: Ground041,
		# hojarasca con las hojas dibujadas en el mapa de altura.
		#
		# Tesela como la del bosque, que es el suelo que cubre: si fueran distintas se
		# vería el cambio de escala al entrar el otoño.
		"name": "Hojarasca de otoño", "asset": "Ground041", "tile_m": 4.0,
		"tint": Color(1.00, 0.96, 0.90), "sat": 0.80,
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


## CUÁNTO RELIEVE TIENE CADA CAPA, en el orden del array.
##
## Multiplica las tres cosas que dan bulto —el mapa de normales, la cuesta de la altura y
## el desplazamiento del parallax—, así que 1 es «como todas» y 3 es «el triple de
## marcada». Existe porque la fuerza era **una sola para las nueve capas** y el usuario
## pidió lo que pide una ladera de verdad: «el canchal apenas tiene relieve, debe tener
## MUCHO más relieve» (2026-09-18). Un canto suelto tiene bulto de canto; un limo de
## marisma no tiene ninguno.
static func reliefs_in_order() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in range(COUNT):
		out.append(float(CATALOGUE[i].get("relieve", 1.0)))
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


# ------------------------------------------------- la vuelta del año --

## Qué capas se apagan con el año, y cuánto.
##
## Sólo las VIVAS. La caliza es igual de gris en enero que en agosto, y el
## canchal también: pintarlos de otoño sería pintar el año encima de la piedra.
## Lo que amarillea y se moja es la hierba y la hojarasca.
const SE_APAGAN := [Layer.PRADERA, Layer.BOSQUE]

## El tinte de cada estación, como multiplicador sobre el de la capa.
##
## No se cambia la textura ni la saturación: se GRADÚA el mismo color, igual
## que hace `tint` con la fotogrametría inglesa —la biblioteca está fotografiada
## en un prado de junio y ya se corrige para la época; esto es la segunda
## corrección, la del mes—.
##
##   PRIMAVERA  el verde nuevo, y es el más vivo del año
##   VERANO     agostado: en el Cantábrico el pasto se seca en agosto
##   OTOÑO      pardo de hojarasca
##   INVIERNO   apagado y encharcado, con el verde casi fuera
const POR_ESTACION := {
	Subsistence.Season.PRIMAVERA: Color(0.98, 1.06, 0.92),
	Subsistence.Season.VERANO: Color(1.08, 1.00, 0.80),
	Subsistence.Season.OTONO: Color(1.06, 0.88, 0.68),
	Subsistence.Season.INVIERNO: Color(0.84, 0.82, 0.76),
}


## La graduación de color de cada capa CON la estación puesta.
##
## Se pasa un color y no una estación para que la transición sea continua:
## quien llama interpola entre el de ayer y el de hoy —ver [Temporada]— y el
## valle vira en unas jornadas en vez de cambiar de golpe a medianoche.
static func tints_in_order_tinted(estacional: Color) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in range(COUNT):
		var tint: Color = CATALOGUE[i]["tint"]
		if SE_APAGAN.has(i):
			tint = Color(tint.r * estacional.r, tint.g * estacional.g,
				tint.b * estacional.b)
		out.append(Vector3(tint.r, tint.g, tint.b))
	return out


## El color de una estación, para quien tenga que interpolar hacia él.
static func tint_of_season(season: Subsistence.Season) -> Color:
	return POR_ESTACION.get(season, Color.WHITE)
