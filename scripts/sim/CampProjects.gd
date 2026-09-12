class_name CampProjects
extends RefCounted
## Mejoras del abrigo: no se construye una choza, se EQUIPA la cueva.
##
## La cueva ya es el edificio. Lo que se añade son las piezas documentadas en
## el propio Cantábrico -Cueva Morín, El Esquilleu, El Mirón-: un hogar
## delimitado con piedras y, sobre él, un secadero. Cada una es barata y
## multiplica algo concreto, y el secadero exige el hogar porque ahumar carne
## sin fuego no es lento, es imposible.

enum Kind { HOGAR, SECADERO, LAVADERO, PARAVIENTO }

## `requires` es -1 si no depende de nada.
const INFO := {
	Kind.HOGAR: {
		"name": "Hogar",
		"desc": "Fogata delimitada con piedras, como en Cueva Morín o El "
			+ "Esquilleu. La comida cocinada rinde más: se digiere mejor y se "
			+ "aprovecha más de lo que se come.",
		# Una jornada, y ni una más. Delimitar una fogata con piedras es acarrear
		# cantos del río y ponerlos en corro: es trabajo de una mañana larga,
		# no una obra. Estaba en dos jornadas y con el rendimiento de la gente
		# por medio salían tres o cuatro días de partida en los que la banda
		# comía crudo por una fogata.
		"labor_days": 1.0,
		"materials": {Materia.Kind.PIEDRA: 6.0, Materia.Kind.LENA: 3.0},
		"requires": -1,
	},
	Kind.SECADERO: {
		"name": "Secadero",
		"desc": "Bastidor sobre el hogar para ahumar carne. Una ración fresca "
			+ "dura cuatro días; seca, ciento ochenta. Es el mejor negocio del "
			+ "Paleolítico, y sin fuego no se hace.",
		"labor_days": 3.0,
		"materials": {Materia.Kind.CORTEZA: 4.0, Materia.Kind.FIBRA: 2.0},
		"requires": Kind.HOGAR,
	},
	Kind.LAVADERO: {
		"name": "Lavadero de bellota",
		"desc": "Un cesto lastrado en el remanso. La corriente hace el trabajo: "
			+ "sólo hay que ponerla y volver a por ella tres días después. Sin "
			+ "esto, la bellota que se recoge en otoño no es comida.",
		# Dos jornadas: trenzar un cesto grande y buscar el remanso. No depende
		# del hogar -es agua corriente, no fuego- y ésa es la gracia: es la
		# primera obra que se puede levantar sin tener fuego encendido.
		"labor_days": 2.0,
		"materials": {Materia.Kind.FIBRA: 6.0, Materia.Kind.PIEDRA: 4.0},
		"requires": -1,
	},
	Kind.PARAVIENTO: {
		"name": "Paraviento",
		"desc": "Cierre de piel y madera contra la boca del abrigo. No abriga "
			+ "más que la roca: hace sitio. Es lo que se levanta cuando la "
			+ "banda ya no cabe entera al calor del hogar.",
		# Dos jornadas: no es un edificio, es cerrar un hueco con pieles
		# tensadas sobre un armazón. No depende del hogar -es un cierre, no
		# una fuente de calor-, igual que el lavadero.
		"labor_days": 2.0,
		"materials": {Materia.Kind.PIEL: 4.0, Materia.Kind.LENA: 3.0},
		"requires": -1,
	},
}


static func project_name(kind: Kind) -> String:
	return String(INFO[kind]["name"])


static func project_desc(kind: Kind) -> String:
	return String(INFO[kind]["desc"])


static func labor_days(kind: Kind) -> float:
	return float(INFO[kind]["labor_days"])


static func materials(kind: Kind) -> Dictionary:
	return INFO[kind]["materials"]


## -1 si no depende de ningún otro proyecto.
static func requires(kind: Kind) -> int:
	return int(INFO[kind]["requires"])


static func all() -> Array:
	return INFO.keys()
