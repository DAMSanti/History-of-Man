class_name ArteDeLosDeAntes
extends RefCounted
## Las cuevas del mapa con arte paleolítico documentado, y lo que se ve dentro.
##
## SISTEMAS §13, spec del 2026-09-15: **cada cueva con arte parietal documentado
## enseña su arte real**, con un texto corto de lo que hay y de cuándo es, sin
## inventar nada. La lista es la de las cuevas cántabras del bien de la UNESCO
## «Cueva de Altamira y arte rupestre paleolítico del norte de España», y está en
## EPOCA_01 §12 con la fuente de cada una.
##
## **Qué es y qué no es un panel.** No es una réplica: dice **qué motivos hay, con
## qué técnica y en qué proporción** —más ciervas que caballos en Covalanas, manos
## y discos en El Castillo—, con las figuras de [Motivos]. Cuántas se ponen es una
## muestra de la pared, no el inventario: La Pasiega tiene más de setecientas
## formas.
##
## **Las fechas son las publicadas**, desde hoy y no desde la banda: la época
## cubre todo el Magdaleniense (~17 000–11 700 a. C., EPOCA_01) y la banda no tiene
## un año fijo dentro de él. Lo claramente anterior al Magdaleniense se cuenta como
## de «los que estuvieron antes»; lo magdaleniense, como de gente de su tiempo. Una
## fecha discutida se dice discutida.
##
## Constantes en código por lo mismo que [Motivos]: se lee dentro del paso.

## Hasta qué distancia un elemento del mapa local es esta cueva, en metros.
##
## Se reconocen **por coordenadas y no por nombre**: en los datos de OpenStreetMap
## Las Monedas sale dos veces con nombres casi iguales, y otra «Cueva de la
## Monedas» distinta está junto a Covalanas. **Y al metro, no por cercanía**: las
## coordenadas de aquí se copiaron del mismo fichero del que salen los elementos
## de los mapas (`data/sites/cantabria_arqueologia.json`), así que la buena
## coincide exacta. Con 150 m —lo que decía esto el 2026-09-15, creyendo que las
## cuevas del monte Castillo estaban a 300–400 m unas de otras— Las Monedas se
## tomaba por La Pasiega (están a 112 m), Las Chimeneas por El Castillo (115 m), y
## El Clavo, El Mirón o Estalactitas por sus vecinas. Lo cazó `TestPared`.
const RADIO_M := 10.0

const CUEVAS := [
	{
		"id": "altamira", "nombre": "Cueva de Altamira",
		"lat": 43.37684, "lon": -4.11975,
		"paneles": [
			{"motivo": "bisonte", "cuantos": 7}, {"motivo": "cierva", "cuantos": 1},
			{"motivo": "caballo", "cuantos": 2}, {"motivo": "jabali", "cuantos": 1},
		],
		"texto": "Un techo entero de bisontes, pintados en rojo y negro sobre los "
			+ "abultamientos de la roca para darles cuerpo, con una gran cierva, "
			+ "caballos y un jabalí. El techo es magdaleniense, de hace unos 15 000 "
			+ "años: de gente de este tiempo. Algunas marcas rojas de la misma cueva "
			+ "tienen como poco 35 600 años.",
		"discutida": false,
		"fuentes": ["https://es.wikipedia.org/wiki/Cueva_de_Altamira",
			"https://doi.org/10.1126/science.1219957"],
	},
	{
		"id": "el_castillo", "nombre": "Cueva de El Castillo",
		"lat": 43.29222, "lon": -3.96549,
		"paneles": [
			{"motivo": "mano", "cuantos": 7}, {"motivo": "puntos", "cuantos": 3},
			{"motivo": "tectiforme", "cuantos": 1}, {"motivo": "bisonte", "cuantos": 1},
		],
		"texto": "Más de cincuenta manos en negativo y una larga serie de grandes "
			+ "discos rojos. Es de lo más antiguo que se conoce pintado en Europa: "
			+ "un disco tiene como poco 40 800 años y una mano, 37 300. Los que "
			+ "soplaron el ocre sobre esas manos estuvieron aquí mucho antes que "
			+ "nadie que se recuerde; los bisontes se pintaron encima, muchos miles "
			+ "de años después.",
		"discutida": false,
		"fuentes": ["https://www.arterupestrecantabrico.es/cuevas/cueva-de-el-castillo.html",
			"https://doi.org/10.1126/science.1219957"],
	},
	{
		"id": "la_pasiega", "nombre": "Cueva de La Pasiega",
		"lat": 43.28875, "lon": -3.96632,
		"paneles": [
			{"motivo": "cierva", "cuantos": 4}, {"motivo": "caballo", "cuantos": 3},
			{"motivo": "bisonte", "cuantos": 1}, {"motivo": "uro", "cuantos": 1},
			{"motivo": "tectiforme", "cuantos": 2}, {"motivo": "claviforme", "cuantos": 1},
			{"motivo": "puntos", "cuantos": 2}, {"motivo": "escaleriforme", "cuantos": 1},
		],
		"texto": "Más de setecientas formas en varias galerías: ciervas sobre todo, "
			+ "caballos, cabras, bisontes y uros, y más de ciento treinta signos "
			+ "—tectiformes, claviformes, series de puntos—, casi todo en rojo. El "
			+ "signo en escalera llamado «La Trampa» se ha fechado en más de 64 800 "
			+ "años y atribuido a neandertales; muchos lo discuten, porque ese signo "
			+ "está pintado encima de animales mucho más recientes.",
		"discutida": true,
		"fuentes": ["https://es.wikipedia.org/wiki/Cueva_de_La_Pasiega",
			"https://doi.org/10.1126/science.aap7778",
			"https://www.sciencenews.org/article/dating-questions-challenge-whether-neandertals-drew-spanish-cave-art"],
	},
	{
		"id": "las_monedas", "nombre": "Cueva de Las Monedas",
		"lat": 43.28892, "lon": -3.96769,
		"paneles": [
			{"motivo": "caballo", "cuantos": 5}, {"motivo": "bisonte", "cuantos": 1},
			{"motivo": "uro", "cuantos": 1},
		],
		"texto": "Veintiocho animales en trazo negro: quince caballos, cuatro renos, "
			+ "cuatro cabras, un bisonte, un uro y un oso de las cavernas. Parecen "
			+ "pintados de una vez, en el Magdaleniense superior: gente de este "
			+ "mismo tiempo.",
		"discutida": false,
		"fuentes": ["https://www.arterupestrecantabrico.es/cuevas/cueva-de-las-monedas.html"],
	},
	{
		"id": "las_chimeneas", "nombre": "Cueva de Las Chimeneas",
		"lat": 43.29149, "lon": -3.96449,
		"paneles": [
			{"motivo": "ciervo", "cuantos": 2}, {"motivo": "tectiforme", "cuantos": 1,
				"color": "negro"},
		],
		"texto": "Ciervos y signos cuadrangulares pintados en negro con carbón. Se "
			+ "pensaba que eran solutrenses, pero el carbono 14 da unos 15 000 años "
			+ "a un ciervo y unos 14 000 a un signo: magdalenienses, de este tiempo.",
		"discutida": false,
		"fuentes": ["https://www.arterupestrecantabrico.es/cuevas/cueva-de-las-chimeneas.html"],
	},
	{
		"id": "covalanas", "nombre": "Cueva de Covalanas",
		"lat": 43.24560, "lon": -3.45207,
		"paneles": [
			{"motivo": "cierva", "cuantos": 6}, {"motivo": "caballo", "cuantos": 1,
				"color": "rojo"},
			{"motivo": "uro", "cuantos": 1, "color": "rojo"},
		],
		"texto": "Dieciocho ciervas rojas pintadas a base de toques de pigmento, un "
			+ "caballo, un bóvido y un posible reno. Son de finales del Gravetiense e "
			+ "inicios del Solutrense: de los que estuvieron antes, miles de años "
			+ "antes del Magdaleniense.",
		"discutida": false,
		"fuentes": ["https://www.arterupestrecantabrico.es/cuevas/cueva-de-covalanas.html"],
	},
	{
		"id": "el_pendo", "nombre": "Cueva del Pendo",
		"lat": 43.38839, "lon": -3.91227,
		"paneles": [
			{"motivo": "cierva", "cuantos": 4}, {"motivo": "caballo", "cuantos": 1,
				"color": "rojo"},
			{"motivo": "uro", "cuantos": 1, "color": "rojo"}, {"motivo": "puntos", "cuantos": 1},
		],
		"texto": "Un friso rojo que no se descubrió hasta 1997: sobre todo ciervas, "
			+ "un caballo, quizá un uro y una cabra, y signos, pintados con toques y "
			+ "con tinta plana. Tiene unos 20 000 años: de los que estuvieron antes.",
		"discutida": false,
		"fuentes": ["https://es.wikipedia.org/wiki/Cueva_de_El_Pendo"],
	},
	{
		"id": "la_garma", "nombre": "Cueva de La Garma",
		"lat": 43.43067, "lon": -3.66592,
		"paneles": [
			{"motivo": "mano", "cuantos": 5}, {"motivo": "caballo", "cuantos": 2,
				"color": "rojo"},
			{"motivo": "bisonte", "cuantos": 1}, {"motivo": "cierva", "cuantos": 1},
			{"motivo": "puntos", "cuantos": 2},
		],
		"texto": "Más de quinientas pinturas y grabados: unos cien animales —caballos, "
			+ "ciervas, bisontes, uros, cabras—, cuarenta manos en negativo y más de "
			+ "cien signos y puntos. Lo más viejo está en lo más hondo; lo del "
			+ "Magdaleniense medio, cerca de la entrada, junto a suelos donde se vivió.",
		"discutida": false,
		"fuentes": ["https://www.arterupestrecantabrico.es/cuevas/cueva-de-la-garma.html"],
	},
	{
		"id": "chufin", "nombre": "Cueva de Chufín",
		"lat": 43.29253, "lon": -4.45991,
		"paneles": [
			{"motivo": "cierva", "cuantos": 2}, {"motivo": "caballo", "cuantos": 1,
				"color": "rojo"},
			{"motivo": "bisonte", "cuantos": 1, "color": "rojo"}, {"motivo": "puntos", "cuantos": 2},
		],
		"texto": "Ciervas, cabras, caballos y bisontes sin cabeza en rojo, grabados "
			+ "profundos y muchos signos de puntos. Del Solutrense, de hace entre "
			+ "unos 20 000 y 25 000 años: de los que estuvieron antes.",
		"discutida": false,
		"fuentes": ["https://es.wikipedia.org/wiki/Cueva_de_Chuf%C3%ADn"],
	},
	{
		"id": "hornos_de_la_pena", "nombre": "Cueva de Hornos de la Peña",
		"lat": 43.26134, "lon": -4.03002,
		"paneles": [
			{"motivo": "caballo", "cuantos": 2, "color": "grabado"},
			{"motivo": "bisonte", "cuantos": 1, "color": "grabado"},
		],
		"texto": "Sólo grabados, sin pintura: un caballo hondo en el abrigo de la "
			+ "entrada, que está entre lo más antiguo de la costa cantábrica, del "
			+ "Auriñaciense; y dentro, bóvidos, ciervos, cabras y hasta un reno, del "
			+ "Magdaleniense superior.",
		"discutida": false,
		"fuentes": ["https://es.wikipedia.org/wiki/Cueva_de_Hornos_de_la_Pe%C3%B1a"],
	},
]


## La cueva con arte que hay en ese punto, o vacío si no hay ninguna.
static func en(lat: float, lon: float) -> Dictionary:
	for cueva: Dictionary in CUEVAS:
		if distancia_m(lat, lon, float(cueva["lat"]), float(cueva["lon"])) <= RADIO_M:
			return cueva
	return {}


## Distancia en metros entre dos puntos cercanos, en plano.
static func distancia_m(lat_a: float, lon_a: float, lat_b: float, lon_b: float) -> float:
	var coseno := cos(deg_to_rad((lat_a + lat_b) * 0.5))
	return Vector2((lon_a - lon_b) * Viaje.METROS_POR_GRADO * coseno,
		(lat_a - lat_b) * Viaje.METROS_POR_GRADO).length()


## Las figuras de un panel ya repartidas: `[{motivo, color}]`, una por figura.
static func figuras_de(cueva: Dictionary) -> Array[Dictionary]:
	var figuras: Array[Dictionary] = []
	for panel: Dictionary in cueva.get("paneles", []):
		var motivo := String(panel["motivo"])
		var color := String(panel.get("color",
			(Motivos.FIGURAS[motivo] as Dictionary)["color"]))
		for _i in range(int(panel["cuantos"])):
			figuras.append({"motivo": motivo, "color": color})
	return figuras
