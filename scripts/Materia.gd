class_name Materia
extends RefCounted
## Catálogo de materiales, con su peso y su volumen reales.
##
## Se llama `Materia` y no `Material` porque `Material` es una clase NATIVA de
## Godot —la de los materiales de render— y declararla aquí la tapaba: dejaban
## de compilar el mapa regional, el cielo y todo lo que asigna un
## StandardMaterial3D.
##
## El peso y el volumen no son adorno: son las dos restricciones que de verdad
## tenía una banda. Una persona carga unos 25 kg en una jornada larga, y un
## abrigo no tiene sitio para diez metros cúbicos de leña por mucho que sobre
## en el monte. Sin esas dos cifras, «almacén» es una lista de números que
## crecen sin consecuencia.
##
## El volumen va en LITROS. Es la unidad en la que las cantidades de una banda
## se leen sin decimales —un haz de leña son 40 litros, no 0,04 m³— y a metros
## cúbicos se pasa solo cuando la cifra lo pide.

enum Kind {
	# Alimento
	FRUTO_SECO,   ## Avellana con cáscara: la reina de la recolección
	BELLOTA,      ## Necesita desamargado: agua, recipiente y tiempo
	BAYA,         ## Endrina, mora, madroño. Poca caloría, mucha vitamina
	RAIZ,         ## Tubérculo y raíz. El colchón invisible de la dieta
	SETA,
	HUEVO,
	MIEL,
	CARACOL,      ## Molusco terrestre: recolecta de críos
	CARNE,        ## Fresca. Se pudre.
	CARNE_SECA,   ## Curada al humo. Aguanta estaciones.
	PESCADO,
	MARISCO,      ## Con concha: pesa y abulta mucho para lo que alimenta
	# Materia prima
	PIEDRA,       ## Cuarcita y sílex en bruto
	ASTA,
	HUESO,
	PIEL,
	TENDON,
	FIBRA,        ## Cordelería sin trenzar
	LENA,
	YESCA,
	RESINA,
	GRASA,
	OCRE,
	CONCHA,       ## Vacía, de playa: adorno
	PLUMA,
	CORTEZA,      ## Recipientes y cordel
	AGUA,
	SILEX,        ## Sílex de nódulo. Da el triple de filo útil que la cuarcita
}

## Ficha de cada material.
##
## `kg` y `litros` son POR UNIDAD. La unidad es la que tiene sentido para ese
## material: una ración de comida, un haz de leña, una cuerna, una piel.
##
## `dias` es lo que aguanta antes de echarse a perder; 0 significa que no se
## estropea. `alimenta` son raciones-persona por unidad, o 0 si no se come.
const CATALOGUE := {
	Kind.FRUTO_SECO: {
		"name": "Fruto seco", "unit": "ración", "kg": 0.55, "litros": 1.6,
		"dias": 360, "alimenta": 1.0,
		"desc": "Avellana y bellota con cáscara. La cáscara abulta, pero es lo "
			+ "que hace que aguante el año entero.",
	},
	Kind.BELLOTA: {
		"name": "Bellota", "unit": "ración", "kg": 0.6, "litros": 1.4,
		"dias": 300, "alimenta": 0.85,
		"desc": "Hay que desamargarla con agua antes de comerla, y eso pide "
			+ "recipiente y varios días. A cambio aguanta el año.",
	},
	Kind.BAYA: {
		"name": "Baya", "unit": "ración", "kg": 0.4, "litros": 0.55,
		"dias": 8, "alimenta": 0.45,
		"desc": "Endrina, mora, madroño. Alimenta poco y se pasa enseguida, "
			+ "pero es de lo poco fresco que hay en verano.",
	},
	Kind.RAIZ: {
		"name": "Raíz", "unit": "ración", "kg": 0.7, "litros": 0.7,
		"dias": 60, "alimenta": 0.7,
		"desc": "Tubérculos y raíces. Es el colchón invisible de la dieta "
			+ "forrajera: rinde poco, no falla casi nunca y hay todo el año.",
	},
	Kind.SETA: {
		"name": "Seta", "unit": "ración", "kg": 0.3, "litros": 1.2,
		"dias": 5, "alimenta": 0.3,
		"desc": "Poca energía y mucho riesgo. Interesa más por la yesca que "
			+ "sale de los hongos de tronco que por lo que da de comer.",
	},
	Kind.HUEVO: {
		"name": "Huevo", "unit": "docena", "kg": 0.6, "litros": 0.9,
		"dias": 14, "alimenta": 1.1,
		"desc": "Pulso corto de primavera y muy rentable. Vaciar la colonia "
			+ "hunde la del año siguiente.",
	},
	Kind.MIEL: {
		"name": "Miel", "unit": "ración", "kg": 0.5, "litros": 0.35,
		"dias": 720, "alimenta": 1.6,
		"desc": "Azúcar puro, valoradísimo en toda sociedad forrajera y con "
			+ "riesgo de por medio. No se estropea nunca.",
	},
	Kind.CARACOL: {
		"name": "Caracol", "unit": "ración", "kg": 1.1, "litros": 1.6,
		"dias": 3, "alimenta": 0.6,
		"desc": "Con concha, así que pesa para lo que da. Recolecta de críos, "
			+ "y aparece en cantidad en algunos yacimientos.",
	},
	Kind.CONCHA: {
		"name": "Concha", "unit": "puñado", "kg": 0.15, "litros": 0.3,
		"dias": 0, "alimenta": 0.0,
		"desc": "Vacías, de playa. Adorno perforado: no es lujo, es identidad "
			+ "y señal de contacto entre grupos.",
	},
	Kind.PLUMA: {
		"name": "Pluma", "unit": "manojo", "kg": 0.05, "litros": 2.0,
		"dias": 0, "alimenta": 0.0,
		"desc": "De muda y de aves muertas. No pesa nada y abulta mucho.",
	},
	Kind.CORTEZA: {
		"name": "Corteza", "unit": "pieza", "kg": 0.8, "litros": 3.5,
		"dias": 0, "alimenta": 0.0,
		"desc": "Recipientes, yesca y cordel. Es lo que permite llevar agua "
			+ "antes de saber curtir una piel.",
	},
	Kind.CARNE: {
		"name": "Carne fresca", "unit": "ración", "kg": 0.45, "litros": 0.45,
		"dias": 4, "alimenta": 1.0,
		"desc": "Se pudre en días. Toda la caza es una carrera contra esto.",
	},
	Kind.CARNE_SECA: {
		"name": "Carne seca", "unit": "ración", "kg": 0.18, "litros": 0.25,
		"dias": 180, "alimenta": 1.0,
		"desc": "Curada al humo. Pierde tres cuartos del peso y gana media año "
			+ "de vida: es el mejor negocio del Paleolítico.",
	},
	Kind.PESCADO: {
		"name": "Pescado", "unit": "ración", "kg": 0.5, "litros": 0.5,
		"dias": 3, "alimenta": 1.0,
		"desc": "Aún más perecedero que la carne.",
	},
	Kind.MARISCO: {
		"name": "Marisco", "unit": "ración", "kg": 2.4, "litros": 3.2,
		"dias": 2, "alimenta": 1.0,
		"desc": "Con concha. Pesa cinco veces lo que la carne para la misma "
			+ "comida, y por eso se come en la orilla y no se transporta.",
	},
	Kind.PIEDRA: {
		"name": "Cuarcita", "unit": "nódulo", "kg": 2.2, "litros": 0.85,
		"dias": 0, "alimenta": 0.0,
		"desc": "Canto de río o de playa. La hay en cualquier parte y talla "
			+ "bien, pero el filo se embota pronto.",
	},
	Kind.SILEX: {
		"name": "Sílex", "unit": "nódulo", "kg": 1.9, "litros": 0.75,
		"dias": 0, "alimenta": 0.0,
		"desc": "Da el triple de filo útil que la cuarcita y se reaviva. No "
			+ "lo hay en cualquier sitio: encontrarlo justifica el viaje.",
	},
	Kind.ASTA: {
		"name": "Asta", "unit": "cuerna", "kg": 1.6, "litros": 9.0,
		"dias": 0, "alimenta": 0.0,
		"desc": "De desmogue. Abulta mucho por su forma ramificada.",
	},
	Kind.HUESO: {
		"name": "Hueso", "unit": "pieza", "kg": 0.7, "litros": 1.2,
		"dias": 0, "alimenta": 0.0,
		"desc": "Punzones, agujas, y combustible cuando falta leña.",
	},
	Kind.PIEL: {
		"name": "Piel", "unit": "piel", "kg": 3.5, "litros": 12.0,
		"dias": 0, "alimenta": 0.0,
		"desc": "Ropa, cobijo y recipientes. Sin curtir se pudre.",
	},
	Kind.TENDON: {
		"name": "Tendón", "unit": "manojo", "kg": 0.15, "litros": 0.4,
		"dias": 0, "alimenta": 0.0,
		"desc": "Ligadura. Encoge al secar y aprieta sola.",
	},
	Kind.FIBRA: {
		"name": "Fibra", "unit": "manojo", "kg": 0.3, "litros": 4.0,
		"dias": 0, "alimenta": 0.0,
		"desc": "Ortiga y líber de tilo. Pesa nada y abulta mucho.",
	},
	Kind.LENA: {
		"name": "Leña", "unit": "haz", "kg": 16.0, "litros": 40.0,
		"dias": 0, "alimenta": 0.0,
		"desc": "Lo que más volumen ocupa del almacén, con diferencia. Un "
			+ "abrigo se llena de leña antes que de cualquier otra cosa.",
	},
	Kind.YESCA: {
		"name": "Yesca", "unit": "porción", "kg": 0.05, "litros": 0.6,
		"dias": 0, "alimenta": 0.0,
		"desc": "Hongo yesquero. Poquísima cantidad, imprescindible.",
	},
	Kind.RESINA: {
		"name": "Resina", "unit": "pella", "kg": 0.25, "litros": 0.25,
		"dias": 0, "alimenta": 0.0,
		"desc": "Adhesivo de enmangue.",
	},
	Kind.GRASA: {
		"name": "Grasa", "unit": "porción", "kg": 0.9, "litros": 1.0,
		"dias": 120, "alimenta": 1.4,
		"desc": "Combustible de lámpara y el alimento más denso que hay.",
	},
	Kind.OCRE: {
		"name": "Ocre", "unit": "nódulo", "kg": 1.1, "litros": 0.4,
		"dias": 0, "alimenta": 0.0,
		"desc": "Pintura y curtido.",
	},
	Kind.AGUA: {
		"name": "Agua", "unit": "odre", "kg": 8.0, "litros": 8.0,
		"dias": 6, "alimenta": 0.0,
		"desc": "Un odre lleno. Pesa exactamente lo que ocupa.",
	},
}


static func material_name(kind: Kind) -> String:
	return CATALOGUE[kind]["name"]


static func unit_name(kind: Kind) -> String:
	return CATALOGUE[kind]["unit"]


static func describe(kind: Kind) -> String:
	return CATALOGUE[kind]["desc"]


static func kg_per_unit(kind: Kind) -> float:
	return float(CATALOGUE[kind]["kg"])


static func litres_per_unit(kind: Kind) -> float:
	return float(CATALOGUE[kind]["litros"])


## Días que aguanta antes de echarse a perder. Cero = no se estropea.
static func shelf_life(kind: Kind) -> int:
	return int(CATALOGUE[kind]["dias"])


## Dónde acaba el alimento y empieza la materia prima en el catálogo.
##
## Hace falta porque `is_food` NO sirve para partir la tabla en dos: la grasa
## se come y además se quema, así que da verdadero y sin embargo el jugador la
## busca con la resina y la yesca, no con las bayas. Lo que decide el estante
## no es si alimenta sino dónde se va a buscar.
const FIRST_RAW := Kind.PIEDRA


## Si este material va en la despensa o en el montón de materia prima.
static func is_provision(kind: Kind) -> bool:
	return int(kind) < int(FIRST_RAW)


static func is_food(kind: Kind) -> bool:
	return float(CATALOGUE[kind]["alimenta"]) > 0.0


## Raciones-persona que da una unidad.
static func nutrition(kind: Kind) -> float:
	return float(CATALOGUE[kind]["alimenta"])


## Volumen SIEMPRE en metros cúbicos.
##
## Mezclar litros y metros cúbicos según la cantidad obligaba a convertir de
## cabeza para comparar dos filas de la misma tabla. Con una sola unidad, la
## columna se lee de un vistazo aunque las cifras pequeñas lleven decimales.
static func format_volume(litres: float) -> String:
	var cubic := litres / 1000.0
	if cubic < 0.01 and cubic > 0.0:
		return "<0,01 m³"
	if cubic < 10.0:
		return "%.2f m³" % cubic
	return "%.1f m³" % cubic


static func format_weight(kg: float) -> String:
	if kg < 1000.0:
		return "%.0f kg" % kg
	return "%.2f t" % (kg / 1000.0)
