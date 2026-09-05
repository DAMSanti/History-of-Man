class_name PropModels
extends RefCounted
## Qué modelo 3D usa cada cosa que se siembra en el suelo.
##
## Mismo papel que [TerrainLayers] para las texturas: el catálogo va aquí, como
## dato, y la herramienta `scripts/tools/PropIngest.gd` lo trae de
## [Poly Haven] —CC0, fotogrametría— y lo deja empaquetado.
##
## Medido en `scripts/tests/PropCosteProbe.gd`: en crudo un modelo de éstos son
## 14.844 triángulos y 2600 instancias son 38,6 millones, que no se sostiene.
## Con los niveles de detalle generados, la misma roca cuesta 1,1 ms más que una
## caja de doce triángulos. O sea que **no hay que decimar nada**: hay que
## generar los LOD y vigilar el NÚMERO de instancias, que es lo que manda.

## Dónde se dejan los modelos que NO se pueden descargar por script.
##
## Ni Poly Haven ni ambientCG tienen asta, hueso ni concha —comprobado contra el
## catálogo entero—, y Sketchfab y Poly Pizza piden clave o OAuth. Así que para
## esas piezas basta con soltar aquí el `.glb` o el `.gltf` y declararlo en el
## catálogo con `local` en vez de `slug`, junto con su autor y su licencia.
const LOCAL_DIR := "res://models/props/source"

## Resolución de textura que se pide. 1K basta: un canto ocupa un puñado de
## píxeles en pantalla y estas texturas van sobre miles de instancias.
const RES := "1k"

## Dónde queda la biblioteca ya empaquetada. No va al repositorio —se
## reconstruye con la herramienta— igual que las texturas del terreno.
const LIBRARY_PATH := "res://models/props/props.res"

## `tint` y `sat` gradúan el color, igual que en [TerrainLayers]: se desatura
## hacia el gris de la misma luminancia y después se tinta. Se hornea en la
## INGESTA, sobre la propia textura, así que en ejecución no cuesta nada.
##
## Hace falta porque un escaneo trae el color del sitio y del día en que se hizo,
## y aquí eso no vale: `rock_07` es pardo rojizo y hace de cuarcita, que es gris
## pálida, mientras que `rock_09` es grisáceo y hace de ocre, que es rojo. Sin
## graduar están justo al revés de lo que deben ser.
##
## `height_m` es la altura real que debe tener la pieza sobre el terreno, en
## metros. Los modelos vienen a su escala de escaneo, que no es la que hace
## falta: un canto de río mide un palmo y un bloque de derrubio, casi dos metros.
## La herramienta calcula el factor a partir de la caja de la malla.
const CATALOGUE := {
	"canto": {
		"slug": "rock_07", "name": "Canto rodado", "height_m": 0.34,
		# Cuarcita: gris pálida y lavada. De origen es pardo rojiza.
		"tint": Color(1.42, 1.40, 1.34), "sat": 0.22,
	},
	"nodulo": {
		# Aviso: el comentario anterior decía que rock_09 «ya viene pardo rojizo
		# y no necesita que se le fuerce el color». Es falso, y se vio en la hoja
		# de contactos: de origen es GRISÁCEO. El que sale rojizo es rock_07, que
		# hace de cuarcita. Estaban justo al revés de lo que deben ser.
		"slug": "rock_09", "name": "Nódulo de ocre", "height_m": 0.26,
		# Ocre: hematites, rojo terroso. De origen es grisáceo.
		"tint": Color(1.55, 0.82, 0.55), "sat": 0.45,
	},
	"bloque": {
		# El bloque suelto de ladera. Es la deuda de G2: lo que da silueta y
		# sombra de verdad en el tramo de 1 a 5 m, que el shader no puede fingir.
		"slug": "boulder_01", "name": "Bloque de ladera", "height_m": 1.9,
		# Caliza de derrubio, no arenisca.
		"tint": Color(1.06, 1.05, 1.02), "sat": 0.50,
	},
	"rama": {
		"slug": "dry_branches_medium_01", "name": "Rama caída", "height_m": 0.5,
		# Madera muerta y seca, no negra.
		"tint": Color(1.22, 1.12, 0.94), "sat": 0.65,
	},
	"helecho": {
		"slug": "fern_02", "name": "Helecho", "height_m": 0.85,
		# Menos verde de invernadero.
		"tint": Color(0.94, 1.00, 0.78), "sat": 0.55,
	},
	"mata": {
		# Mata alta de fruto. `nettle_plant` no es un avellano, pero a distancia
		# de juego lo que se lee es la SILUETA -un montón de hoja ancha- y no la
		# especie. Es lo más parecido que hay en CC0; queda anotado por si algún
		# día aparece algo mejor.
		"slug": "nettle_plant", "name": "Mata de fruto", "height_m": 1.6,
		# Hoja de estepa, más seca.
		# Luminancia medida 0,129; se sube a 0,17 con factor 1,32.
		"tint": Color(1.48, 1.37, 0.98), "sat": 0.50,
	},
	"pasto": {
		"slug": "grass_medium_01", "name": "Pasto de claro", "height_m": 0.45,
		# Pasto pajizo, como la pradera del terreno.
		# Medido: la luminancia del albedo era 0,060, casi negro. El factor sale
		# de la medida y no del ojo: 2,33 para llevarla a 0,14, que es lo que
		# tiene un pasto seco. Un tinte alto sobre un albedo bajo sigue siendo
		# bajo, y eso no se ve mirando una miniatura.
		"tint": Color(3.26, 2.89, 1.58), "sat": 0.32,
	},
	"arbusto": {
		# Endrino y zarzamora. `shrub_02` no es ninguno de los dos, pero a
		# distancia de juego lo que se lee es la silueta de un matorral leñoso.
		"slug": "shrub_02", "name": "Arbusto de baya", "height_m": 1.10,
		# Matorral leñoso.
		"tint": Color(1.16, 1.06, 0.80), "sat": 0.60,
	},
	"roseta": {
		# La raíz no se ve: lo que se ve es la mata de hoja que la delata, y por
		# eso se busca por la hoja. Una roseta baja sirve.
		"slug": "dandelion_01", "name": "Mata de raíz", "height_m": 0.30,
		# Roseta de hoja, no de jardín.
		# Luminancia medida 0,203; sube poco, factor 1,08.
		"tint": Color(1.19, 1.17, 0.84), "sat": 0.50,
	},
	"tocon": {
		# De donde se saca la corteza para recipientes y cordel.
		"slug": "tree_stump_01", "name": "Tocón", "height_m": 0.75,
		# Madera vieja.
		"tint": Color(1.02, 0.98, 0.90), "sat": 0.70,
	},
	"conifera": {
		# La resina sale de la conífera. En el Magdaleniense cantábrico el pino
		# es parte del bosque de refugio, así que además cuadra con la época.
		"slug": "pine_sapling_small", "name": "Conífera joven", "height_m": 1.40,
		# Pino de refugio: verde frío y apagado.
		"tint": Color(0.90, 0.98, 0.78), "sat": 0.60,
	},
	"asta": {
		# Cuerna de desmogue: lo que se recoge, no lo que se caza. De ella salen
		# azagayas y arpones, así que es icono de la época.
		"local": "asta.glb", "name": "Cuerna", "height_m": 0.70,
		# Asta: hueso pálido.
		"tint": Color(1.18, 1.12, 0.96), "sat": 0.50,
	},
	"concha": {
		"local": "concha.glb", "name": "Concha", "height_m": 0.11,
		# Concha lavada por el mar.
		"tint": Color(1.12, 1.09, 1.02), "sat": 0.55,
	},
	"concha2": {
		# Dos conchas distintas a propósito: un conchero de una sola forma
		# repetida se lee como un patrón, no como marisco.
		"local": "concha2.glb", "name": "Concha menuda", "height_m": 0.085,
		# Ídem.
		"tint": Color(1.12, 1.09, 1.02), "sat": 0.55,
	},
	"yesca": {
		# Yesca: lo que prende. Era `moss_01` y se cambia por dos motivos. Uno,
		# que medido daba una luminancia de 0,021 —prácticamente negro— y en el
		# terreno salía como una mancha ilegible. Y dos, que la yesca es corteza
		# seca y hongo, no musgo húmedo: el musgo era el parecido más cercano que
		# había, pero no es lo que se recoge para prender fuego.
		"slug": "bark_debris_01", "name": "Corteza de yesca", "height_m": 0.16,
		# Corteza seca y clara, que es lo que se ve al lado del hogar.
		"tint": Color(1.30, 1.20, 0.95), "sat": 0.55,
	},
}


## Las piezas que faltan por conseguir, con lo que hay que buscar.
##
## Se quedan aquí escritas en vez de en un comentario suelto para que la propia
## herramienta pueda decir qué falta, y para que no se olvide qué se buscó ya.
const WANTED := {
	"asta": {
		"name": "Cuerna de desmogue",
		"note": "Icono del Magdaleniense: azagayas y arpones salen de aquí. "
			+ "No existe en Poly Haven ni en ambientCG.",
	},
	"concha": {
		"name": "Concha de lapa o mejillón",
		"note": "Ojo con la especie: `lambis_shell` de Poly Haven es una "
			+ "caracola tropical, nada que ver con el marisqueo cantábrico.",
	},
	"seta": {"name": "Seta", "note": "Tampoco existe en CC0 scripteable."},
	"hueso": {"name": "Hueso", "note": "Ídem."},
}


## Graduación de una pieza: cuánto color se conserva y con qué se tinta.
static func grade_of(key: String) -> Dictionary:
	var entry: Dictionary = CATALOGUE.get(key, {})
	return {
		"tint": entry.get("tint", Color.WHITE),
		"sat": float(entry.get("sat", 1.0)),
	}


static func slugs() -> Array[String]:
	var out: Array[String] = []
	for key: String in CATALOGUE:
		out.append(CATALOGUE[key]["slug"] as String)
	return out
