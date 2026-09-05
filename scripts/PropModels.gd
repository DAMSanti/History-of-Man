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

## Resolución de textura que se pide. 1K basta: un canto ocupa un puñado de
## píxeles en pantalla y estas texturas van sobre miles de instancias.
const RES := "1k"

## Dónde queda la biblioteca ya empaquetada. No va al repositorio —se
## reconstruye con la herramienta— igual que las texturas del terreno.
const LIBRARY_PATH := "res://models/props/props.res"

## `height_m` es la altura real que debe tener la pieza sobre el terreno, en
## metros. Los modelos vienen a su escala de escaneo, que no es la que hace
## falta: un canto de río mide un palmo y un bloque de derrubio, casi dos metros.
## La herramienta calcula el factor a partir de la caja de la malla.
const CATALOGUE := {
	"canto": {
		"slug": "rock_07", "name": "Canto rodado", "height_m": 0.34,
	},
	"nodulo": {
		# rock_09 es pardo rojizo de origen, así que el ocre no necesita que se
		# le fuerce el color: ya lo trae.
		"slug": "rock_09", "name": "Nódulo de ocre", "height_m": 0.26,
	},
	"bloque": {
		# El bloque suelto de ladera. Es la deuda de G2: lo que da silueta y
		# sombra de verdad en el tramo de 1 a 5 m, que el shader no puede fingir.
		"slug": "boulder_01", "name": "Bloque de ladera", "height_m": 1.9,
	},
	"rama": {
		"slug": "dry_branches_medium_01", "name": "Rama caída", "height_m": 0.5,
	},
	"helecho": {
		"slug": "fern_02", "name": "Helecho", "height_m": 0.85,
	},
	"mata": {
		# Mata alta de fruto. `nettle_plant` no es un avellano, pero a distancia
		# de juego lo que se lee es la SILUETA -un montón de hoja ancha- y no la
		# especie. Es lo más parecido que hay en CC0; queda anotado por si algún
		# día aparece algo mejor.
		"slug": "nettle_plant", "name": "Mata de fruto", "height_m": 1.6,
	},
	"pasto": {
		"slug": "grass_medium_01", "name": "Pasto de claro", "height_m": 0.45,
	},
}


static func slugs() -> Array[String]:
	var out: Array[String] = []
	for key: String in CATALOGUE:
		out.append(CATALOGUE[key]["slug"] as String)
	return out
