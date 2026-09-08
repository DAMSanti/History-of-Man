class_name Fishing
extends RefCounted
## Las formas de pescar en la orilla, de la mano desnuda a la red.
##
## No es una lista de mejoras de porcentaje: es la secuencia real, y cada
## escalón cambia lo que la banda tiene que tener antes. Pescar a mano no pide
## nada; la pesquera es una obra que se hace una vez y trabaja sola; la nasa
## pide cestería; el sedal pide hueso trabajado, cordel y CEBO, que hay que
## traer; la red pide una cantidad de fibra que solo se junta cuando la
## cordelería va sobrada, y tres manos a la vez; el arpón pide asta, buril y
## talla laminar, y es el último que llega.
##
## Fidelidad, que es lo que se pidió:
##
## - A mano y en pozas: es lo que se hace sin nada. Anguila bajo la piedra,
##   pez atrapado en la poza cuando baja la crecida. No deja rastro
##   arqueológico porque no usa nada, y por eso mismo es el punto de partida.
## - Pesquera —cierre de piedra y ramas que embudan el cauce—: no necesita
##   técnica que el Paleolítico superior no tuviera, solo jornadas de trabajo,
##   y convierte la pesca de suerte en cosecha.
## - Nasa de mimbre: cestería, la misma que hace el cesto de recolectar. Se
##   pone y se recoge, así que trabaja mientras la banda hace otra cosa.
## - Sedal y anzuelo: el anzuelo paleolítico NO es de gancho, es un
##   «bastoncillo» —gorge— de hueso o asta apuntado por los dos extremos y
##   atado por el medio; el pez se lo traga y se le atraviesa. El de gancho es
##   ya mesolítico y neolítico. Necesita cebo, y por eso aquí lo gasta.
## - Red de fibra: hay impronta de red trenzada en Pavlov, hace unos 29.000
##   años, o sea que es MÁS VIEJA que el arpón. Da mucho y pide mucho: fibra
##   a espuertas y tres manos para calarla.
## - Arpón de asta dentada: el objeto magdaleniense por excelencia —hace unos
##   quince mil años—, el que aparece a cientos en la cornisa cantábrica y el
##   último de la escalera. Es lo que hace del remonte del salmón una cosecha
##   previsible.
##
## El orden es el cronológico y no el de «cuánto rinde»: la red viene del
## Gravetiense y el arpón del Magdaleniense, así que se aprende antes la red
## aunque el arpón dé más.
##
## Lo que NO está, a propósito: la caña. Sedal sí está atestiguado; la caña
## de pescar como tal no tiene respaldo paleolítico, y meterla por quedar
## bonita sería inventarse la parte que se supone que este juego cuida.

enum Method {
	MANO,       ## A mano y en pozas. Sin nada.
	PESQUERA,   ## Cierre de piedra y ramas que embuda el cauce
	NASA,       ## Trampa de mimbre: se pone y se recoge
	SEDAL,      ## Anzuelo recto de hueso, cordel y cebo
	RED,        ## Red de fibra: mucha mano y mucha cordelería
	ARPON,      ## Arpón de asta dentada: el remonte del salmón, y la cumbre
}


## Cada forma de pescar, en el orden en que se aprende.
##
## `tech` es la técnica que hay que dominar -o -1 si no hace falta ninguna-,
## `tool` la pieza que hay que tener en el abrigo -o -1-, `yields` lo que
## saca una jornada entera y perfecta -las mismas unidades que
## `SettlementSim.SPECIALITY_YIELDS`-, `party` cuántas manos hacen falta a la
## vez y `bait` qué se gasta como cebo.
const CATALOGUE := {
	Method.MANO: {
		"name": "A mano y en pozas",
		"desc": "Anguila bajo la piedra, pez encerrado en la poza cuando baja "
			+ "la crecida. No hace falta nada y por eso se puede desde el "
			+ "primer día, pero se come más tiempo que pescado da.",
		"tech": -1, "tool": -1, "party": 1,
		"yields": {Materia.Kind.PESCADO: 12.0},
		"bait": [], "bait_per_day": 0.0,
	},
	Method.PESQUERA: {
		"name": "Pesquera de piedra",
		"desc": "Un cierre de cantos y ramaje que estrecha el cauce y lleva al "
			+ "pez a un embudo. Cuesta jornadas levantarla y después trabaja "
			+ "sola: es el salto de pescar con suerte a pescar con cuenta.",
		"tech": TechTree.Tech.PESQUERA, "tool": -1, "party": 1,
		"yields": {Materia.Kind.PESCADO: 28.0},
		"bait": [], "bait_per_day": 0.0,
	},
	Method.NASA: {
		"name": "Nasa de mimbre",
		"desc": "La misma cestería que hace el cesto, trenzada en embudo. Se "
			+ "cala por la tarde y se levanta por la mañana, así que pesca "
			+ "mientras la banda está en otra cosa.",
		"tech": TechTree.Tech.NASA, "tool": Tool.Kind.NASA, "party": 1,
		# Estas cifras ya no las usa nadie para pescar: la nasa es PASIVA -ver
		# [ACTIVAS] y [Nasa]- y lo que cobra sale de las jornadas que lleve
		# calada. Se dejan porque la ficha sigue sirviendo para ENSENAR la
		# manera en el arbol y en la ribera, con su nombre y su texto.
		"yields": {Materia.Kind.PESCADO: 42.0},
		"bait": Nasa.CEBOS, "bait_per_day": 0.0,
	},
	Method.SEDAL: {
		"name": "Sedal y anzuelo",
		"desc": "El anzuelo no es de gancho: es un bastoncillo de hueso "
			+ "apuntado por los dos extremos y atado por el medio, que el pez "
			+ "se traga y se le cruza dentro. Pide cebo, y sin cebo no hay "
			+ "sedal que valga.",
		"tech": TechTree.Tech.ANZUELO, "tool": Tool.Kind.ANZUELO, "party": 1,
		"yields": {Materia.Kind.PESCADO: 58.0},
		"bait": [Materia.Kind.CARACOL, Materia.Kind.CARNE, Materia.Kind.MARISCO],
		"bait_per_day": 0.8,
	},
	Method.ARPON: {
		"name": "Arpón de asta",
		"desc": "Asta de ciervo con hileras de dientes, para que el salmón no "
			+ "se suelte al revolverse. Es el objeto del Magdaleniense "
			+ "cantábrico y lo que hace del remonte una cosecha.",
		"tech": TechTree.Tech.ARPON, "tool": Tool.Kind.ARPON, "party": 1,
		"yields": {Materia.Kind.PESCADO: 105.0, Materia.Kind.GRASA: 2.0},
		"bait": [], "bait_per_day": 0.0,
	},
	Method.RED: {
		"name": "Red de fibra",
		"desc": "Trenzada con el cordel de la banda entera y calada entre dos "
			+ "orillas. Es más vieja que el arpón —hay impronta de red en "
			+ "Pavlov hace veintinueve mil años— y pide lo que costaba "
			+ "entonces: mucha fibra y tres manos tirando a la vez.",
		"tech": TechTree.Tech.RED, "tool": Tool.Kind.RED, "party": 3,
		"yields": {Materia.Kind.PESCADO: 88.0, Materia.Kind.GRASA: 1.0},
		"bait": [], "bait_per_day": 0.0,
	},
}

## De peor a mejor. El orden importa: `best_for` recorre de atrás adelante y
## se queda con la primera que se pueda usar hoy.
const ORDER := [Method.MANO, Method.PESQUERA, Method.NASA, Method.SEDAL,
	Method.RED, Method.ARPON]


## Y las que de verdad son una JORNADA en el agua.
##
## La nasa no lo es, y ésa es la corrección: estaba en esta lista como una
## manera más de plantarse en la orilla, con su tabla de rendimiento al lado
## del arpón y del sedal, y una nasa no es eso. Una nasa es un objeto que se
## cala y se deja. El pescador que la sabe hacer no se pasa el día con ella:
## revisa la línea por la mañana —que le cuesta un rato— y el resto de la
## jornada pesca ACTIVAMENTE con lo mejor que tenga de esta lista.
##
## O sea que la nasa no compite con el arpón: se suma. Ver [Nasa] y
## `SettlementSim._creel_round`.
const ACTIVAS := [Method.MANO, Method.PESQUERA, Method.SEDAL,
	Method.RED, Method.ARPON]


## Si esta manera de pescar es una jornada en el agua o un aparejo que se deja
## puesto.
static func is_passive(method: Method) -> bool:
	return not ACTIVAS.has(method)


static func method_name(method: Method) -> String:
	return String(CATALOGUE[method]["name"])


static func method_desc(method: Method) -> String:
	return String(CATALOGUE[method]["desc"])


static func yields_of(method: Method) -> Dictionary:
	return CATALOGUE[method]["yields"]


## La pieza que pide, o -1 si ninguna.
static func tool_of(method: Method) -> int:
	return int(CATALOGUE[method]["tool"])


## La técnica que pide, o -1 si ninguna.
static func tech_of(method: Method) -> int:
	return int(CATALOGUE[method]["tech"])


## Cuántas manos hacen falta a la vez.
static func party_of(method: Method) -> int:
	return int(CATALOGUE[method]["party"])


## Con qué se ceba. Lista vacía si no lleva cebo.
##
## Es una lista y no una cosa porque el cebo es lo que haya: un caracol, un
## trozo de carne, una lapa. Atarse a un único material haría que el sedal
## dependiera de la temporada del caracol, que no es la idea.
static func baits_of(method: Method) -> Array:
	return CATALOGUE[method]["bait"] as Array


## El cebo que HAY en el abrigo para esta manera, o -1 si no lleva o no hay.
static func bait_at_hand(method: Method, store: Storehouse) -> int:
	var baits := baits_of(method)
	if baits.is_empty() or store == null:
		return -1
	var per_day := bait_per_day(method)
	for kind: int in baits:
		if store.amount(kind as Materia.Kind) >= per_day:
			return kind
	return -1


static func bait_per_day(method: Method) -> float:
	return float(CATALOGUE[method]["bait_per_day"])


## La mejor forma de pescar HOY.
##
## No es la mejor que se sepa: es la mejor que se puede hacer ahora mismo. Se
## sabe hacer la red y se han roto todas, se pesca con arpón; se sabe el sedal
## y no hay cebo en el abrigo, se pesca con nasa. La banda no se queda parada
## porque le falte la pieza buena, baja un escalón —que es exactamente lo que
## se hace.
## Se recorre [ACTIVAS] y no [ORDER]: la nasa queda fuera porque no es una
## jornada de pesca, es un aparejo calado. La banda que sabe hacer nasas las
## cala Y ADEMÁS pesca con lo mejor que tenga.
static func best_for(techs: TechTree, toolkit: Toolkit, store: Storehouse,
		workers: int = 1) -> Method:
	for i in range(ACTIVAS.size() - 1, -1, -1):
		var method: Method = ACTIVAS[i]
		if available(method, techs, toolkit, store, workers):
			return method
	return Method.MANO


## Si esta forma de pescar se puede usar ahora mismo.
static func available(method: Method, techs: TechTree, toolkit: Toolkit,
		store: Storehouse, workers: int = 1) -> bool:
	var tech := tech_of(method)
	if tech >= 0:
		# Sin árbol de técnicas -las pruebas, o el rato antes de montarlo- solo
		# se sabe lo que no hay que aprender
		if techs == null or not techs.has(tech as TechTree.Tech):
			return false

	var tool := tool_of(method)
	if tool >= 0 and (toolkit == null or toolkit.count(tool as Tool.Kind) <= 0):
		return false

	if workers < party_of(method):
		return false

	if not baits_of(method).is_empty() and bait_at_hand(method, store) < 0:
		return false

	return true


## Por qué NO se puede usar, para poder decírselo al jugador. "" si sí se puede.
static func blocked_by(method: Method, techs: TechTree, toolkit: Toolkit,
		store: Storehouse, workers: int = 1) -> String:
	var tech := tech_of(method)
	if tech >= 0 and (techs == null or not techs.has(tech as TechTree.Tech)):
		return "falta saber %s" % TechTree.tech_name(tech as TechTree.Tech).to_lower()

	var tool := tool_of(method)
	if tool >= 0 and (toolkit == null or toolkit.count(tool as Tool.Kind) <= 0):
		return "no hay %s en el abrigo" % Tool.kind_name(tool as Tool.Kind).to_lower()

	if workers < party_of(method):
		return "hacen falta %d manos a la vez" % party_of(method)

	var baits := baits_of(method)
	if not baits.is_empty() and bait_at_hand(method, store) < 0:
		var names: Array[String] = []
		for kind: int in baits:
			names.append(Materia.material_name(kind as Materia.Kind).to_lower())
		return "no hay cebo: ni %s" % " ni ".join(names)

	return ""
