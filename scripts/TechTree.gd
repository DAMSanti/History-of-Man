class_name TechTree
extends RefCounted
## Lo que la banda sabe hacer, y lo que podría llegar a saber.
##
## No es un árbol de "investigación" de laboratorio: en el Paleolítico nadie
## investiga, se aprende haciendo. Por eso cada técnica se desbloquea con
## EXPERIENCIA en la actividad que la produce —tallar mucho lleva al núcleo
## preparado, pescar mucho lleva al arpón— y no gastando un recurso abstracto.
##
## El orden es el de la secuencia real del Paleolítico cantábrico: modo 2
## achelense, modo 3 musteriense, y el paquete del Paleolítico superior con el
## azagaya, el arpón y el arte parietal.

enum Tech {
	LASCA,          ## Talla sobre lasca: el punto de partida, ya se trae
	FUEGO,          ## Dominio del fuego: cocinar, calor, protección
	NUCLEO,         ## Núcleo preparado (Levallois): lascas predecibles
	HOJA,           ## Talla laminar: mucho más filo por kilo de sílex
	AZAGAYA,        ## Azagaya de asta: caza a distancia
	PROPULSOR,      ## Propulsor: dobla el alcance de la azagaya
	PESQUERA,       ## Cierre de piedra en el cauce: la pesca deja de ser suerte
	NASA,           ## Nasa de mimbre: una trampa que pesca sola
	ANZUELO,        ## Anzuelo recto de hueso: sedal y cebo
	RED,            ## Red de fibra: mucha mano y mucha cordelería
	ARPON,          ## Arpón de asta: el remonte del salmón, y la cumbre
	ARCO,           ## Arco: caza de precisión
	PIRAGUA,        ## Piragua monóxila: cruzar ríos y costear
	PASARELA,       ## Pasarela de troncos: cruzar un cauce a pie seco
	ARTE,           ## Arte parietal: la marca del territorio
	AGUJA,          ## Aguja de hueso: ropa cosida, ocupar el invierno
}


## Nombre y descripción de cada técnica, más lo que hace falta para llegar a
## ella. `needs` son otras técnicas; `practice` es la actividad que hay que
## haber trabajado, y `days` las jornadas acumuladas en ella.
const CATALOGUE := {
	Tech.LASCA: {
		"name": "Talla sobre lasca",
		"desc": "Percusión directa con percutor duro. Filos rápidos, poco control "
			+ "de la forma. Es con lo que llega la banda: no se aprende aquí.",
		"needs": [], "practice": -1, "days": 0,
	},
	Tech.FUEGO: {
		"name": "Dominio del fuego",
		"desc": "No solo encenderlo: mantenerlo, transportarlo y cocinar con él. "
			+ "Cocinar abre alimentos que crudos no se aprovechan, y el hogar "
			+ "hace habitable una cueva en invierno.",
		"needs": [], "practice": Subsistence.Activity.RECOLECCION, "days": 20,
	},
	Tech.NUCLEO: {
		"name": "Núcleo preparado",
		"desc": "Se prepara el nódulo antes de extraer, de modo que la lasca sale "
			+ "con la forma buscada. Es el salto técnico del Musteriense: menos "
			+ "desperdicio de sílex y filos repetibles.",
		"needs": [Tech.LASCA], "practice": Subsistence.Activity.MATERIA_PRIMA, "days": 45,
	},
	Tech.HOJA: {
		"name": "Talla laminar",
		"desc": "Hojas largas y estrechas desde un núcleo prismático. Multiplica "
			+ "los metros de filo por kilo de sílex, que en un valle sin sílex "
			+ "bueno es la diferencia entre tener herramientas o no.",
		"needs": [Tech.NUCLEO], "practice": Subsistence.Activity.MATERIA_PRIMA, "days": 110,
	},
	Tech.AZAGAYA: {
		"name": "Azagaya de asta",
		"desc": "Punta de asta de ciervo enmangada. Permite matar a distancia en "
			+ "vez de al acecho, y con ello cazar presa mayor sin perder gente.",
		"needs": [Tech.HOJA], "practice": Subsistence.Activity.CAZA, "days": 90,
	},
	Tech.PROPULSOR: {
		"name": "Propulsor",
		"desc": "Una palanca que alarga el brazo. Dobla el alcance útil de la "
			+ "azagaya y deja cazar sin acercarse a la distancia de carga.",
		"needs": [Tech.AZAGAYA], "practice": Subsistence.Activity.CAZA, "days": 160,
	},
	Tech.PESQUERA: {
		"name": "Pesquera de piedra",
		"desc": "Un cierre de cantos y ramaje que estrecha el cauce y lleva al "
			+ "pez a un embudo. No hace falta ninguna técnica nueva, solo "
			+ "jornadas de brazo, y es lo que convierte la pesca de suerte en "
			+ "pesca con cuenta.",
		"needs": [], "practice": Subsistence.Activity.PESCA, "days": 60,
	},
	Tech.NASA: {
		"name": "Nasa de mimbre",
		"desc": "La cestería de la banda trenzada en embudo. Se cala por la "
			+ "tarde y se levanta por la mañana: pesca mientras la banda "
			+ "está en otra cosa.",
		"needs": [Tech.PESQUERA], "practice": Subsistence.Activity.PESCA, "days": 180,
	},
	Tech.ANZUELO: {
		"name": "Anzuelo de hueso",
		"desc": "No es de gancho —eso es ya mesolítico—: es un bastoncillo "
			+ "apuntado por los dos cabos y atado por el medio, que el pez se "
			+ "traga y se le cruza dentro. Pide hueso ranurado con buril, "
			+ "cordel y cebo.",
		"needs": [Tech.NASA, Tech.NUCLEO],
		"practice": Subsistence.Activity.PESCA, "days": 320,
	},
	Tech.ARPON: {
		"name": "Arpón de asta",
		"desc": "Asta de ciervo con hileras de dientes, para que el salmón no se "
			+ "suelte al revolverse. Es lo último que llega —Magdaleniense, "
			+ "hace unos quince mil años— y lo que convierte el remonte de una "
			+ "suerte estacional en una cosecha previsible.",
		"needs": [Tech.RED, Tech.HOJA],
		"practice": Subsistence.Activity.PESCA, "days": 850,
	},
	Tech.RED: {
		"name": "Red de fibra",
		"desc": "Hay impronta de red trenzada en Pavlov de hace veintinueve mil "
			+ "años: es más vieja que el arpón, no un adelanto. Se hace cuando "
			+ "sobra cordel y hay manos para calarla, y pide las dos cosas.",
		"needs": [Tech.ANZUELO], "practice": Subsistence.Activity.PESCA, "days": 560,
	},
	Tech.ARCO: {
		"name": "Arco",
		"desc": "Precisión a distancia y tiro repetido. Cambia la caza de "
			+ "batida a acecho individual.",
		"needs": [Tech.PROPULSOR], "practice": Subsistence.Activity.CAZA, "days": 280,
	},
	Tech.PIRAGUA: {
		"name": "Piragua monóxila",
		"desc": "Un tronco vaciado a fuego y azuela. Abre la otra orilla del río "
			+ "y la pesca en aguas profundas: media comarca que hasta ahora "
			+ "estaba a la vista y fuera de alcance.",
		"needs": [Tech.FUEGO, Tech.NUCLEO], "practice": Subsistence.Activity.PESCA, "days": 150,
	},
	Tech.PASARELA: {
		"name": "Pasarela de troncos",
		"desc": "Dos troncos y un tejido de ramas sobre el paso más estrecho. "
			+ "No sirve para el río grande, pero cruza un arroyo crecido sin "
			+ "perder la carga.",
		"needs": [Tech.NUCLEO], "practice": Subsistence.Activity.MATERIA_PRIMA, "days": 70,
	},
	Tech.ARTE: {
		"name": "Arte parietal",
		"desc": "Pintar la cueva no es adorno: es marcar el territorio, fijar "
			+ "lo que se sabe de los animales y transmitirlo a quien no estaba. "
			+ "Es la primera tecnología de la memoria.",
		"needs": [Tech.FUEGO, Tech.HOJA], "practice": Subsistence.Activity.CAZA, "days": 200,
	},
	Tech.AGUJA: {
		"name": "Aguja de hueso",
		"desc": "Ropa cosida y ajustada en vez de piel echada por encima. Es lo "
			+ "que permite trabajar fuera en pleno invierno.",
		"needs": [Tech.HOJA], "practice": Subsistence.Activity.RECOLECCION, "days": 190,
	},
}


## Técnicas ya dominadas
var known: Dictionary = {Tech.LASCA: true}

## Jornadas acumuladas por actividad
var practice_days: Dictionary = {}


func has(tech: Tech) -> bool:
	return known.get(tech, false)


## Suma jornadas de práctica y devuelve lo que se haya desbloqueado con ellas.
func add_practice(activity: Subsistence.Activity, days: float) -> Array[Tech]:
	practice_days[activity] = float(practice_days.get(activity, 0.0)) + days
	return _check_unlocks()


func days_in(activity: Subsistence.Activity) -> float:
	return float(practice_days.get(activity, 0.0))


## Si una técnica está al alcance: se tienen sus previas pero no ella.
func is_available(tech: Tech) -> bool:
	if has(tech):
		return false
	for need: Tech in (CATALOGUE[tech]["needs"] as Array):
		if not has(need):
			return false
	return true


## Progreso hacia una técnica, de 0 a 1.
func progress(tech: Tech) -> float:
	var entry: Dictionary = CATALOGUE[tech]
	var needed: float = float(entry["days"])
	if needed <= 0.0:
		return 1.0
	var activity: int = entry["practice"]
	if activity < 0:
		return 1.0
	return clampf(days_in(activity as Subsistence.Activity) / needed, 0.0, 1.0)


func _check_unlocks() -> Array[Tech]:
	var gained: Array[Tech] = []
	for tech: Tech in CATALOGUE.keys():
		if not is_available(tech):
			continue
		if progress(tech) >= 1.0:
			known[tech] = true
			gained.append(tech)
	return gained


static func tech_name(tech: Tech) -> String:
	return CATALOGUE[tech]["name"]


static func tech_desc(tech: Tech) -> String:
	return CATALOGUE[tech]["desc"]
