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
	# --- Lo que viste el terreno --------------------------------------------
	#
	# Éstas no son recursos: nadie las recolecta. Son el paisaje, y se siembran
	# contra el TERRENO -pendiente, humedad, altura- y no contra el campo de
	# abundancia.
	#
	# Aquí NO hay árboles, y no por olvido. Los de Poly Haven son escaneos de
	# cine: `pine_tree_01` trae 17.182.252 triángulos y `fir_tree_01` casi siete
	# millones. Guardarlos dejaba la biblioteca en 1,3 GB, y no se pueden
	# recortar porque el generador de niveles de detalle de Godot los rechaza:
	# «Mesh LOD generation failed, mesh is too complex». Además hay superficies
	# que salen con CERO niveles, y una sola superficie sin simplificar arrastra
	# el total.
	#
	# O sea que no es un ajuste que falte: hacen falta árboles hechos para un
	# juego -unos miles de triángulos y la hoja en planos con alfa-, y eso no
	# está en Poly Haven. Ver `WANTED`.

	"herbazal": {
		# Relleno: la hierba que tapa el suelo desnudo. Es la que más instancias
		# se lleva y la que hace que el terreno deje de parecer una textura.
		"slug": "grass_medium_02", "name": "Herbazal", "height_m": 0.38,
		"tint": Color(3.10, 2.80, 1.60), "sat": 0.30,
	},
	"pena": {
		# Peña suelta de ladera. Es la deuda de G2: lo único que da silueta y
		# sombra REALES entre uno y cinco metros, que el shader no puede fingir.
		"slug": "namaqualand_boulder_02", "name": "Peña", "height_m": 2.6,
		"tint": Color(1.04, 1.03, 1.00), "sat": 0.45,
	},

	"pena2": {
		"slug": "namaqualand_boulder_03", "name": "Peña partida", "height_m": 1.9,
		"tint": Color(1.05, 1.04, 1.00), "sat": 0.45,
	},
	"pena3": {
		"slug": "namaqualand_boulder_05", "name": "Peña baja", "height_m": 1.4,
		"tint": Color(1.03, 1.02, 0.99), "sat": 0.45,
	},

	# --- Árboles ------------------------------------------------------------
	#
	# Bosque del Magdaleniense cantábrico, que no es el bosque de hoy: estepa
	# fría con bosque de refugio en los valles encajados. Pino albar y abedul en
	# lo húmedo y abrigado, enebro y matorral en lo expuesto, y troncos secos en
	# pie por toda la estepa. Árboles de porte MODESTO -entre tres y ocho metros-,
	# no el hayedo de postal: a quince mil años el clima no daba para más.
	#
	# Las alturas son deliberadamente cortas para la especie. Los modelos de Poly
	# Haven que se pueden usar son planteles -saplings-, no árboles adultos, y
	# estirar un plantel a veinte metros da un palo con cuatro ramas. A ocho lo
	# que sale es un pino joven de umbría, que es exactamente lo que había.
	#
	# Los adultos de verdad de Poly Haven NO se pueden traer: `pine_tree_01` son
	# 905 MB de geometría y `fir_tree_01` 456 MB, y Godot ya rechazó generarles
	# niveles de detalle -«mesh is too complex»-. Medido con su propia API.
	"pino": {
		"slug": "fir_sapling_medium", "name": "Pino de refugio", "height_m": 8.0,
		# Conífera de clima frío: verde azulado y apagado, no el verde de vivero.
		"tint": Color(0.82, 0.95, 0.80), "sat": 0.55,
	},
	"pino_joven": {
		"slug": "fir_sapling", "name": "Pino joven", "height_m": 4.0,
		"tint": Color(0.86, 0.98, 0.82), "sat": 0.58,
	},
	# --- LA FLORA QUE FALTABA ------------------------------------------------
	#
	# El bosque tenia pino, pino joven y abedul, y con eso no se cubre la
	# cornisa cantabrica del Magdaleniense. Los diagramas polinicos de El Miron,
	# La Riera y Tito Bustillo dan pinar-abedular abierto con AVELLANO y ROBLE
	# entrando en los interestadiales, y matorral de brezo y enebro en lo
	# abierto, que era mucho.
	#
	# Y hay una razon de juego encima de la historica: la banda vive de la
	# AVELLANA y desde el desamargado tambien de la BELLOTA, o sea que recogia
	# el fruto de dos arboles que no existian en el valle. Eso ya no.
	#
	# Poly Haven no tiene ni avellano ni roble -ni sauce, ni aliso, ni enebro-,
	# asi que van con lo unico de hoja que hay, igual que el abedul. A distancia
	# de juego lo que se lee es la silueta, y estas tres son distintas entre si
	# y distintas de la punta de la conifera. Queda anotado por si aparecen.
	"roble": {
		"slug": "island_tree_01", "name": "Roble", "height_m": 11.0,
		# Verde hecho y algo oscuro: el roble no tiene la hoja clara del abedul.
		"tint": Color(0.92, 1.02, 0.78), "sat": 0.52,
	},
	"avellano": {
		# Mas arbusto que arbol -el avellano cantabrico va en mata de varios
		# pies- y por eso queda bajo. Es el que da de comer a la banda.
		"slug": "island_tree_02", "name": "Avellano", "height_m": 5.0,
		"tint": Color(1.02, 1.08, 0.80), "sat": 0.54,
	},
	"brezo": {
		# El matorral de lo abierto, que era casi todo. Un valle cantabrico del
		# Dryas no es bosque cerrado: es pinar en las umbrias y brezal en el
		# resto.
		"slug": "shrub_01", "name": "Brezal", "height_m": 0.7,
		"tint": Color(0.94, 0.92, 0.78), "sat": 0.48,
	},
	"enebro": {
		# Enebro rastrero: el indicador de frio de los diagramas polinicos.
		"slug": "shrub_03", "name": "Enebro", "height_m": 0.9,
		"tint": Color(0.86, 0.94, 0.82), "sat": 0.50,
	},

	"abedul": {
		# La hoja caduca del bosque de refugio. `tree_small_02` no es un abedul
		# -Poly Haven no tiene ninguno- pero es el único árbol de HOJA que se
		# puede traer, y a distancia de juego lo que se lee es la silueta: copa
		# redonda contra la punta de la conífera. Queda anotado por si aparece uno.
		"slug": "tree_small_02", "name": "Abedul", "height_m": 6.5,
		# Abedul: hoja clara, casi amarillenta, y tronco pálido.
		"tint": Color(1.18, 1.14, 0.82), "sat": 0.50,
	},
	"seco": {
		# Tronco CAÍDO, no en pie, y la diferencia importa mucho más de lo que
		# parece. Se pidió como árbol muerto y al fotografiarlo para el atlas de
		# impostores salió con proporción alto/ancho 0,10: está TUMBADO. Con la
		# altura puesta a 4,5 m -pensada para un árbol- la ingesta lo habría
		# escalado por nueve y el valle se habría llenado de troncos de cuarenta y
		# cinco metros de largo.
		#
		# Su sitio es la LEÑA: un tronco caído es exactamente lo que se recoge
		# para el fuego, y le da a esa materia una silueta grande que la rama
		# suelta no tiene. La altura es ahora su GROSOR, que es lo que mide un
		# tronco tumbado de arriba abajo.
		"slug": "dead_tree_trunk", "name": "Tronco caído", "height_m": 0.5,
		"tint": Color(1.06, 1.00, 0.90), "sat": 0.45,
	},
	"seco2": {
		"slug": "dead_tree_trunk_02", "name": "Tronco partido", "height_m": 0.6,
		"tint": Color(1.04, 0.99, 0.91), "sat": 0.45,
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
	"arbol": {
		"name": "Árbol adulto de verdad",
		"note": "Los de Poly Haven son escaneos de cine -17 millones de "
			+ "triángulos el pino- y Godot se niega a generarles niveles de "
			+ "detalle: «mesh is too complex». Hace falta un árbol hecho para "
			+ "juego: unos miles de triángulos y la hoja en planos con alfa.",
	},
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
