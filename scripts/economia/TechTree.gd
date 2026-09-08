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
##
## **Aquí NO está el fuego, y es a propósito.** Estuvo, como técnica de veinte
## jornadas, y era un error de bulto: una banda del Magdaleniense sabe hacer
## fuego desde antes de llegar —ver SLICE_PALEOLITICO §1, donde está como
## `ATESTIGUADO`—, y empezar la partida descubriéndolo es un tópico de género
## que además es falso. Lo que sí hay que levantar es el HOGAR
## (`CampProjects.Kind.HOGAR`), que es una obra del abrigo y no un saber.
##
## La piragua y el arte parietal necesitan fuego de verdad —un tronco se vacía
## a fuego, y una cueva se pinta con luz—, así que siguen dependiendo de él:
## por `camp` y no por `needs`, o sea de que el hogar esté construido en vez de
## de haber descubierto nada.

enum Tech {
	LASCA,          ## Talla sobre lasca: el punto de partida, ya se trae
	NUCLEO,         ## Núcleo preparado (Levallois): lascas predecibles
	HOJA,           ## Talla laminar: mucho más filo por kilo de sílex
	LAZO,           ## Corredera de fibra en el paso: la primera trampa
	CEPO,           ## Losa calzada sobre un disparador cebado
	RED_AVES,       ## Malla tendida en el bebedero: plumas a espuertas
	FOSO,           ## Hoyo tapado en la vereda: la trampa de pieza mayor
	OJEO,           ## Batida organizada: varias manos y un plan
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
	Tech.LAZO: {
		"name": "Lazo de fibra",
		"desc": "Una corredera atada a una vara doblada, puesta en el paso que "
			+ "el animal ya usa. No hace falta saber tallar ni tener asta: "
			+ "hace falta leer una vereda, que es lo primero que se aprende "
			+ "del monte. Es la trampa que da de comer mientras se duerme.",
		"needs": [], "practice": Subsistence.Activity.CAZA, "days": 35,
	},
	Tech.CEPO: {
		"name": "Cepo de losa",
		"desc": "Una losa calzada sobre un disparador cebado. Cae con el peso "
			+ "y mata en el sitio, así que no hay que llegar antes que el "
			+ "zorro. Dura mucho más que un lazo y pide piedra.",
		"needs": [Tech.LAZO], "practice": Subsistence.Activity.CAZA, "days": 110,
	},
	Tech.RED_AVES: {
		"name": "Red de aves",
		"desc": "Malla fina entre dos varas en el bebedero o en el paso de la "
			+ "nube. Es la misma cordelería que la red del río, y da plumas a "
			+ "espuertas: un ave no da piel, da pluma.",
		"needs": [Tech.LAZO], "practice": Subsistence.Activity.CAZA, "days": 190,
	},
	Tech.FOSO: {
		"name": "Foso",
		"desc": "Hoyo en la vereda, tapado con ramaje y tierra. Es la única "
			+ "trampa que coge pieza mayor, y cuesta lo que parece: días de "
			+ "cavar por una pieza cada tanto, pero esa pieza es un ciervo.",
		"needs": [Tech.CEPO], "practice": Subsistence.Activity.CAZA, "days": 330,
	},
	Tech.OJEO: {
		"name": "Ojeo",
		"desc": "Batida con un plan: unos levantan la pieza y la conducen, "
			+ "otros esperan en el paso. No es una herramienta, es saber "
			+ "repartirse, y multiplica lo que trae una cuadrilla de caza "
			+ "mayor sin gastar una azagaya de más.",
		"needs": [Tech.AZAGAYA], "practice": Subsistence.Activity.CAZA, "days": 260,
	},
	Tech.AZAGAYA: {
		"name": "Azagaya de asta",
		"desc": "Punta de asta de ciervo enmangada. Permite matar a distancia en "
			+ "vez de al acecho, y con ello cazar presa mayor sin perder gente.",
		"needs": [Tech.HOJA], "practice": Subsistence.Activity.CAZA, "days": 140,
	},
	Tech.PROPULSOR: {
		"name": "Propulsor",
		"desc": "Una palanca que alarga el brazo. Dobla el alcance útil de la "
			+ "azagaya y deja cazar sin acercarse a la distancia de carga.",
		"needs": [Tech.AZAGAYA], "practice": Subsistence.Activity.CAZA, "days": 420,
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
		"needs": [Tech.PROPULSOR], "practice": Subsistence.Activity.CAZA, "days": 700,
	},
	Tech.PIRAGUA: {
		"name": "Piragua monóxila",
		"desc": "Un tronco vaciado a fuego y azuela. Abre la otra orilla del río "
			+ "y la pesca en aguas profundas: media comarca que hasta ahora "
			+ "estaba a la vista y fuera de alcance.",
		"needs": [Tech.NUCLEO], "camp": CampProjects.Kind.HOGAR,
		"practice": Subsistence.Activity.PESCA, "days": 150,
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
		"needs": [Tech.HOJA], "camp": CampProjects.Kind.HOGAR,
		"practice": Subsistence.Activity.CAZA, "days": 200,
	},
	Tech.AGUJA: {
		"name": "Aguja de hueso",
		"desc": "Ropa cosida y ajustada en vez de piel echada por encima. Es lo "
			+ "que permite trabajar fuera en pleno invierno.",
		"needs": [Tech.HOJA], "practice": Subsistence.Activity.RECOLECCION, "days": 190,
	},
}


## En qué rama va cada técnica, para poder ENSEÑARLO como un árbol.
##
## El catálogo es un diccionario plano y se leía como una lista de la compra:
## veintiuna entradas seguidas en las que no se ve qué lleva a qué. Un árbol de
## progreso no es la lista de lo que hay: es qué abre qué, y eso pide agrupar
## por rama y ordenar por cadena de prerrequisitos.
##
## El orden DENTRO de cada rama es el de esa cadena, que es como se lee de
## arriba abajo. La profundidad no se escribe: sale sola de contar `needs` -ver
## `depth_of`-, así que no hay dos verdades que puedan separarse.
##
## El hogar no está aquí y no es un olvido: sus mejoras no son técnicas que se
## aprenden sino OBRAS que se levantan. Viven en [CampProjects] y la interfaz
## las enseña como cuarta rama.
## Lo que hay que GASTAR para aprender cada tecnica, aparte de las jornadas.
##
## «No sirven de nada cuarenta y cinco jornadas si no se tiene nada con lo que
## trabajar»: aprender a tallar un nucleo preparado se aprende ESTROPEANDO
## nodulos, y aprender a hacer una nasa se aprende tejiendo mimbre que se
## rompe. Sin esto, la unica moneda del arbol era el tiempo, y el tiempo pasa
## solo.
##
## Que material pide cada una NO es una eleccion libre: es el material del que
## se hace lo que la tecnica ensena a hacer -asta la azagaya, fibra la red,
## piedra la pesquera-. Lo que si esta pendiente de playtest son las
## CANTIDADES, y por eso van en una sola tabla y no repartidas por el
## catalogo. La escala de partida es «unas cuantas piezas echadas a perder
## mientras se aprende», no un almacen entero.
##
## El material se gasta AL DESBLOQUEAR, no antes: mientras se practica no se
## toca el almacen, y la tecnica espera a que haya con que rematarla. Ver
## `SettlementSim._pay_for_tech`.
const LEARNING_COST := {
	Tech.NUCLEO: {Materia.Kind.PIEDRA: 12.0},
	Tech.HOJA: {Materia.Kind.PIEDRA: 18.0},
	Tech.AGUJA: {Materia.Kind.HUESO: 6.0},
	Tech.PASARELA: {Materia.Kind.LENA: 20.0},
	Tech.PIRAGUA: {Materia.Kind.LENA: 30.0, Materia.Kind.RESINA: 6.0},
	Tech.ARTE: {Materia.Kind.OCRE: 8.0, Materia.Kind.GRASA: 4.0},
	Tech.LAZO: {Materia.Kind.FIBRA: 6.0},
	Tech.CEPO: {Materia.Kind.PIEDRA: 8.0, Materia.Kind.LENA: 4.0},
	Tech.RED_AVES: {Materia.Kind.FIBRA: 14.0},
	Tech.FOSO: {Materia.Kind.LENA: 16.0},
	Tech.AZAGAYA: {Materia.Kind.ASTA: 8.0, Materia.Kind.TENDON: 4.0},
	Tech.OJEO: {},
	Tech.PROPULSOR: {Materia.Kind.ASTA: 10.0},
	Tech.ARCO: {Materia.Kind.LENA: 10.0, Materia.Kind.TENDON: 8.0},
	Tech.PESQUERA: {Materia.Kind.PIEDRA: 24.0},
	Tech.NASA: {Materia.Kind.FIBRA: 10.0},
	Tech.ANZUELO: {Materia.Kind.HUESO: 5.0},
	Tech.RED: {Materia.Kind.FIBRA: 26.0},
	Tech.ARPON: {Materia.Kind.ASTA: 12.0},
}


## Lo que cuesta aprender esta tecnica, en materiales. Vacio si no cuesta.
static func learning_cost(tech: Tech) -> Dictionary:
	return LEARNING_COST.get(tech, {})


## Las ramas del arbol, UNA POR OFICIO.
##
## Estaban agrupadas por tema -«Talla y taller», «Caza», «Pesca»- y eso dejaba
## fuera media banda: quien mira la ventana no piensa «pesca», piensa «tengo
## cuatro en la ribera, que les falta». Y sobre todo dejaba tres tecnicas
## -pasarela, piragua, arte- colgando de la rama de talla, cuando lo que hacen
## es abrir territorio y marcarlo, que es exploracion y hogar.
##
## La clave es el oficio de verdad, no una cadena: la ventana pinta una
## pestaña por cada una y el nombre lo pone `Profession.job_name`.
const BRANCHES := {
	Profession.Job.MANUFACTURA: [Tech.LASCA, Tech.NUCLEO, Tech.HOJA,
		Tech.AGUJA],
	Profession.Job.CAZA: [Tech.LAZO, Tech.CEPO, Tech.RED_AVES, Tech.FOSO,
		Tech.AZAGAYA, Tech.OJEO, Tech.PROPULSOR, Tech.ARCO],
	Profession.Job.RIBERA: [Tech.PESQUERA, Tech.NASA, Tech.ANZUELO, Tech.RED,
		Tech.ARPON],
	Profession.Job.EXPLORACION: [Tech.PASARELA, Tech.PIRAGUA],
	Profession.Job.HOGAR: [Tech.ARTE],
}


## Con que cara se dibuja cada tecnica en el arbol.
##
## La mayoria ensena a hacer una PIEZA y se dibuja con ella, que es lo que el
## jugador reconoce de un vistazo; las que no -el ojeo, el arte- van con el
## material que las define. La clave negativa es una pieza del utillaje y la
## positiva un material, igual que en el libro de trabajo.
const TECH_FACE := {
	Tech.LASCA: -1 - int(Tool.Kind.LASCA),
	Tech.NUCLEO: int(Materia.Kind.SILEX),
	Tech.HOJA: -1 - int(Tool.Kind.BURIL),
	Tech.AGUJA: -1 - int(Tool.Kind.AGUJA),
	Tech.LAZO: -1 - int(Tool.Kind.CUERDA),
	Tech.CEPO: int(Materia.Kind.PIEDRA),
	Tech.RED_AVES: int(Materia.Kind.PLUMA),
	Tech.FOSO: int(Materia.Kind.LENA),
	Tech.AZAGAYA: -1 - int(Tool.Kind.AZAGAYA),
	Tech.OJEO: int(Materia.Kind.CARNE),
	Tech.PROPULSOR: int(Materia.Kind.ASTA),
	Tech.ARCO: int(Materia.Kind.TENDON),
	Tech.PESQUERA: int(Materia.Kind.PESCADO),
	Tech.NASA: -1 - int(Tool.Kind.NASA),
	Tech.ANZUELO: -1 - int(Tool.Kind.ANZUELO),
	Tech.RED: -1 - int(Tool.Kind.RED),
	Tech.ARPON: -1 - int(Tool.Kind.ARPON),
	Tech.PASARELA: int(Materia.Kind.LENA),
	Tech.PIRAGUA: int(Materia.Kind.RESINA),
	Tech.ARTE: int(Materia.Kind.OCRE),
}


## El oficio al que pertenece una tecnica, o -1 si esta fuera de las ramas.
static func job_of(tech: Tech) -> int:
	for job: int in BRANCHES:
		if (BRANCHES[job] as Array).has(tech):
			return job
	return -1


## Cuántos eslabones de prerrequisito hay por debajo de esta técnica.
##
## Es la sangría con la que se dibuja el árbol, y sale de los datos: contarla
## a mano en una tabla aparte sería una segunda verdad que se desincroniza al
## primer cambio.
static func depth_of(tech: Tech) -> int:
	var deepest := -1
	for need: Tech in (CATALOGUE[tech]["needs"] as Array):
		deepest = maxi(deepest, depth_of(need))
	return deepest + 1


## Técnicas ya dominadas
var known: Dictionary = {Tech.LASCA: true}

## Qué obras del abrigo están levantadas. Es el MISMO diccionario que lleva
## `SettlementSim.camp_built`, no una copia: así no hay dos verdades sobre si
## hay hogar. Ver [CampProjects].
var camp_built: Dictionary = {}

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
	var camp := needs_camp(tech)
	if camp >= 0 and not camp_built.get(camp, false):
		return false
	return true


## Qué obra del abrigo hace falta para una técnica, o -1 si ninguna.
static func needs_camp(tech: Tech) -> int:
	return int((CATALOGUE[tech] as Dictionary).get("camp", -1))


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


## La despensa de la banda, para poder cobrar lo que cuesta aprender.
##
## Es la MISMA que la de la simulacion, no una copia, igual que `camp_built`:
## dos verdades sobre lo que hay en el abrigo se desincronizan al primer
## cambio. Si esta a null -las pruebas montan arboles sueltos- las tecnicas no
## cuestan material y se comportan como antes.
var larder: Storehouse = null


## Si en el abrigo hay con que rematar el aprendizaje de esta tecnica.
func can_afford(tech: Tech) -> bool:
	if larder == null:
		return true
	for material: int in learning_cost(tech):
		if larder.amount(material as Materia.Kind) \
			< float(learning_cost(tech)[material]):
			return false
	return true


## Lo que falta para poder rematarla, dicho para leerlo. Vacio si no falta.
func missing_for(tech: Tech) -> Array[String]:
	var short: Array[String] = []
	if larder == null:
		return short
	for material: int in learning_cost(tech):
		var want := float(learning_cost(tech)[material])
		var have := larder.amount(material as Materia.Kind)
		if have < want:
			short.append("%.0f %s" % [want - have,
				Materia.material_name(material as Materia.Kind).to_lower()])
	return short


func _check_unlocks() -> Array[Tech]:
	var gained: Array[Tech] = []
	for tech: Tech in CATALOGUE.keys():
		if not is_available(tech):
			continue
		if progress(tech) < 1.0:
			continue
		# Las jornadas estan; falta el material. La tecnica NO se pierde: se
		# queda esperando a que alguien traiga lo que falta, y mientras tanto
		# se ve en el arbol que lo unico que la frena es eso.
		if not can_afford(tech):
			continue
		for material: int in learning_cost(tech):
			if larder != null:
				larder.take(material as Materia.Kind,
					float(learning_cost(tech)[material]))
		known[tech] = true
		gained.append(tech)
	return gained


static func tech_name(tech: Tech) -> String:
	return CATALOGUE[tech]["name"]


static func tech_desc(tech: Tech) -> String:
	return CATALOGUE[tech]["desc"]
