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
## ella. `needs` son otras técnicas y `days` las jornadas de trabajo que hay que
## acumular; el OFICIO que la practica sale de la rama —ver [BRANCHES] y
## [job_of]— y no se escribe aquí, para que la pestaña en la que sale y lo que
## la hace subir no puedan discrepar.
const CATALOGUE := {
	Tech.LASCA: {
		"name": "Talla sobre lasca",
		"desc": "Percusión directa con percutor duro. Filos rápidos, poco control "
			+ "de la forma. Es con lo que llega la banda: no se aprende aquí.",
		"needs": [], "days": 0,
	},
	Tech.NUCLEO: {
		"name": "Núcleo preparado",
		"desc": "Se prepara el nódulo antes de extraer, de modo que la lasca sale "
			+ "con la forma buscada. Es el salto técnico del Musteriense: menos "
			+ "desperdicio de sílex y filos repetibles.",
		"needs": [Tech.LASCA], "days": 45,
	},
	Tech.HOJA: {
		"name": "Talla laminar",
		"desc": "Hojas largas y estrechas desde un núcleo prismático. Multiplica "
			+ "los metros de filo por kilo de sílex, que en un valle sin sílex "
			+ "bueno es la diferencia entre tener herramientas o no.",
		"needs": [Tech.NUCLEO], "days": 110,
	},
	Tech.LAZO: {
		"name": "Lazo de fibra",
		"desc": "Una corredera atada a una vara doblada, puesta en el paso que "
			+ "el animal ya usa. No hace falta saber tallar ni tener asta: "
			+ "hace falta leer una vereda, que es lo primero que se aprende "
			+ "del monte. Es la trampa que da de comer mientras se duerme.",
		"needs": [], "days": 35,
	},
	Tech.CEPO: {
		"name": "Cepo de losa",
		"desc": "Una losa calzada sobre un disparador cebado. Cae con el peso "
			+ "y mata en el sitio, así que no hay que llegar antes que el "
			+ "zorro. Dura mucho más que un lazo y pide piedra.",
		"needs": [Tech.LAZO], "days": 110,
	},
	Tech.RED_AVES: {
		"name": "Red de aves",
		"desc": "Malla fina entre dos varas en el bebedero o en el paso de la "
			+ "nube. Es la misma cordelería que la red del río, y da plumas a "
			+ "espuertas: un ave no da piel, da pluma.",
		"needs": [Tech.LAZO], "days": 190,
	},
	Tech.FOSO: {
		"name": "Foso",
		"desc": "Hoyo en la vereda, tapado con ramaje y tierra. Es la única "
			+ "trampa que coge pieza mayor, y cuesta lo que parece: días de "
			+ "cavar por una pieza cada tanto, pero esa pieza es un ciervo.",
		"needs": [Tech.CEPO], "days": 330,
	},
	Tech.OJEO: {
		"name": "Ojeo",
		"desc": "Batida con un plan: unos levantan la pieza y la conducen, "
			+ "otros esperan en el paso. No es una herramienta, es saber "
			+ "repartirse, y multiplica lo que trae una cuadrilla de caza "
			+ "mayor sin gastar una azagaya de más.",
		"needs": [Tech.AZAGAYA], "days": 260,
	},
	Tech.AZAGAYA: {
		"name": "Azagaya de asta",
		"desc": "Punta de asta de ciervo enmangada. Permite matar a distancia en "
			+ "vez de al acecho, y con ello cazar presa mayor sin perder gente.",
		"needs": [Tech.HOJA], "days": 140,
	},
	Tech.PROPULSOR: {
		"name": "Propulsor",
		"desc": "Una palanca que alarga el brazo. Dobla el alcance útil de la "
			+ "azagaya y deja cazar sin acercarse a la distancia de carga.",
		"needs": [Tech.AZAGAYA], "days": 420,
	},
	Tech.PESQUERA: {
		"name": "Pesquera de piedra",
		"desc": "Un cierre de cantos y ramaje que estrecha el cauce y lleva al "
			+ "pez a un embudo. No hace falta ninguna técnica nueva, solo "
			+ "jornadas de brazo, y es lo que convierte la pesca de suerte en "
			+ "pesca con cuenta.",
		"needs": [], "days": 60,
	},
	Tech.NASA: {
		"name": "Nasa de mimbre",
		"desc": "La cestería de la banda trenzada en embudo. Se cala por la "
			+ "tarde y se levanta por la mañana: pesca mientras la banda "
			+ "está en otra cosa.",
		"needs": [Tech.PESQUERA], "days": 180,
	},
	Tech.ANZUELO: {
		"name": "Anzuelo de hueso",
		"desc": "No es de gancho —eso es ya mesolítico—: es un bastoncillo "
			+ "apuntado por los dos cabos y atado por el medio, que el pez se "
			+ "traga y se le cruza dentro. Pide hueso ranurado con buril, "
			+ "cordel y cebo.",
		"needs": [Tech.NASA, Tech.NUCLEO],
		"days": 320,
	},
	Tech.ARPON: {
		"name": "Arpón de asta",
		"desc": "Asta de ciervo con hileras de dientes, para que el salmón no se "
			+ "suelte al revolverse. Es lo último que llega —Magdaleniense, "
			+ "hace unos quince mil años— y lo que convierte el remonte de una "
			+ "suerte estacional en una cosecha previsible.",
		"needs": [Tech.RED, Tech.HOJA],
		"days": 850,
	},
	Tech.RED: {
		"name": "Red de fibra",
		"desc": "Hay impronta de red trenzada en Pavlov de hace veintinueve mil "
			+ "años: es más vieja que el arpón, no un adelanto. Se hace cuando "
			+ "sobra cordel y hay manos para calarla, y pide las dos cosas.",
		"needs": [Tech.ANZUELO], "days": 560,
	},
	Tech.ARCO: {
		"name": "Arco",
		"desc": "Precisión a distancia y tiro repetido. Cambia la caza de "
			+ "batida a acecho individual.",
		"needs": [Tech.PROPULSOR], "days": 700,
	},
	Tech.PIRAGUA: {
		"name": "Piragua monóxila",
		"desc": "Un tronco vaciado a fuego y azuela. Abre la otra orilla del río "
			+ "y la pesca en aguas profundas: media comarca que hasta ahora "
			+ "estaba a la vista y fuera de alcance.",
		"needs": [Tech.NUCLEO], "camp": CampProjects.Kind.HOGAR,
		"days": 150,
	},
	Tech.PASARELA: {
		"name": "Pasarela de troncos",
		"desc": "Dos troncos y un tejido de ramas sobre el paso más estrecho. "
			+ "No sirve para el río grande, pero cruza un arroyo crecido sin "
			+ "perder la carga.",
		"needs": [Tech.NUCLEO], "days": 70,
	},
	Tech.ARTE: {
		"name": "Arte parietal",
		"desc": "Pintar la cueva no es adorno: es marcar el territorio, fijar "
			+ "lo que se sabe de los animales y transmitirlo a quien no estaba. "
			+ "Es la primera tecnología de la memoria.",
		"needs": [Tech.HOJA], "camp": CampProjects.Kind.HOGAR,
		"days": 200,
	},
	Tech.AGUJA: {
		"name": "Aguja de hueso",
		"desc": "Ropa cosida y ajustada en vez de piel echada por encima. Es lo "
			+ "que permite trabajar fuera en pleno invierno.",
		"needs": [Tech.HOJA], "days": 190,
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
## El material se gasta A PLAZOS, al ritmo de la practica.
##
## Era al final -se practicaban las jornadas enteras y solo entonces se cobraba
## el material-, y el jugador lo dijo claro: «por un lado pasan las jornadas, y
## despues consume los materiales. No deberia ser asi... si pide 100 jornadas y
## 10 de calcita, quiero que permita subir 10 jornadas por cada 1 de calcita».
##
## Y tiene razon en la mecanica, no solo en el orden: aprender a tallar un
## nucleo se aprende ESTROPEANDO nodulos, asi que el material no es un peaje de
## salida, es lo que se consume mientras se aprende. Sin nodulos no se practica,
## se mira.
##
## Ahora cada unidad de material abre su parte de las jornadas: con 100 jornadas
## y 10 de piedra, cada piedra vale diez jornadas y el progreso se para en cuanto
## no hay con que seguir. Ver [fraccion_pagada] y [_ir_pagando].
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

## Jornadas de trabajo acumuladas POR OFICIO.
##
## Por oficio y no por actividad, que es lo que pedía el jugador: «las jornadas
## de trabajo sólo deben contar las de esa profesión; si me pide 100 jornadas de
## caza contará cada jornada que un cazador sale».
##
## Y con eso se arregla de paso lo de «hay técnicas de ribera y de exploración
## que parece que no suben». No lo parecía: no subían. La actividad que hacía
## avanzar cada técnica se escribía a mano en el catálogo y no tenía por qué
## coincidir con la pestaña en la que sale, y no coincidía: la pasarela —rama de
## exploración— avanzaba con MATERIA_PRIMA y la piragua —también exploración—
## con PESCA. O sea que poner gente a explorar no las movía ni un día.
##
## Ahora el oficio sale de [BRANCHES], que es la misma tabla que pinta las
## pestañas: la rama en la que está una técnica ES la profesión que la practica,
## y no hay dos verdades que puedan separarse.
var practice_days: Dictionary = {}


func has(tech: Tech) -> bool:
	return known.get(tech, false)


## Suma jornadas de práctica de un OFICIO y devuelve lo que se haya desbloqueado.
func add_practice(job: Profession.Job, days: float) -> Array[Tech]:
	practice_days[int(job)] = float(practice_days.get(int(job), 0.0)) + days
	_ir_pagando()
	return _check_unlocks()


func days_in(job: Profession.Job) -> float:
	return float(practice_days.get(int(job), 0.0))



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
	var needed: float = float(CATALOGUE[tech]["days"])
	if needed <= 0.0:
		return 1.0
	# El oficio que la practica es el de su rama. Ver [job_of], que ya existia
	# para pintar las pestañas: la pestaña y lo que hace subir la tecnica son
	# la misma cosa, y por eso no pueden discrepar.
	var job := job_of(tech)
	if job < 0:
		return 1.0
	# LO QUE MENOS DE LAS DOS: las jornadas hechas y lo que el material da de
	# sí. Ver [fraccion_pagada].
	return minf(clampf(days_in(job as Profession.Job) / needed, 0.0, 1.0),
		fraccion_pagada(tech))


## La despensa de la banda, para poder cobrar lo que cuesta aprender.
##
## Es la MISMA que la de la simulacion, no una copia, igual que `camp_built`:
## dos verdades sobre lo que hay en el abrigo se desincronizan al primer
## cambio. Si esta a null -las pruebas montan arboles sueltos- las tecnicas no
## cuestan material y se comportan como antes.
var larder: Storehouse = null


## Si en el abrigo hay con que rematar el aprendizaje de esta tecnica.
## Si en el abrigo hay con que TERMINAR de pagar esta tecnica.
##
## Lo que falta por poner, no el coste entero: el material se va gastando a
## plazos mientras se practica, asi que preguntar por el total sobra en cuanto
## se ha puesto la primera piedra.
func can_afford(tech: Tech) -> bool:
	if larder == null:
		return true
	var puesto: Dictionary = pagado.get(int(tech), {})
	for material: int in learning_cost(tech):
		var falta := float(learning_cost(tech)[material]) \
			- float(puesto.get(material, 0.0))
		if falta > 0.0 and larder.amount(material as Materia.Kind) < falta:
			return false
	return true


## Por que no avanza una tecnica. Una pregunta, un sitio que la contesta.
##
## La casilla del panel y su aviso emergente lo decidian cada uno por su
## cuenta, y por eso la casilla se quedaba en «43 %» mientras el aviso decia
## «PARADA por falta de asta»: dos verdades sobre lo mismo. Ahora las dos
## preguntan aqui. Ver [causa] y `docs/INTERFAZ.md` §4.
enum Freno {
	NINGUNO,        ## Dominada, o nada la frena
	PRERREQUISITO,  ## Falta una tecnica de las de antes
	OBRA,           ## Falta una obra del abrigo
	JORNADAS,       ## Va despacio: faltan jornadas de su oficio
	MATERIAL,       ## PARADA: el progreso no sube aunque se practique
}

## Margen para no llamar «parada por material» a una diferencia de redondeo
## entre las dos fracciones, que van a plazos y nunca casan al decimal.
const HOLGURA_DEL_FRENO := 0.001


## Cual de las tres puertas esta cerrada. Ver [Freno].
##
## MATERIAL y JORNADAS no son lo mismo y por eso se separan: con material se
## PARA -`_ir_pagando` no puede seguir comprando y `progress` deja de subir
## aunque la banda practique-, y con jornadas solo va despacio. El panel las
## pinta distinto porque piden decisiones distintas: traer asta, o poner gente
## en el oficio.
func freno(tech: Tech) -> Freno:
	if has(tech):
		return Freno.NINGUNO
	for need: Tech in (CATALOGUE[tech]["needs"] as Array):
		if not has(need):
			return Freno.PRERREQUISITO
	var camp := needs_camp(tech)
	if camp >= 0 and not camp_built.get(camp, false):
		return Freno.OBRA
	var needed: float = float(CATALOGUE[tech]["days"])
	var job := job_of(tech)
	if needed <= 0.0 or job < 0:
		return Freno.NINGUNO
	var por_dias := clampf(days_in(job as Profession.Job) / needed, 0.0, 1.0)
	# LAS DOS CONDICIONES, no solo que el material vaya por detras.
	#
	# `_ir_pagando` solo compra cuando alguien practica, asi que entre tanda y
	# tanda la fraccion pagada va siempre un poco atrasada aunque la despensa
	# este llena: eso no es estar parado, es un tick de retraso que se cobra
	# solo. Con solo la primera condicion el panel pintaba «parada por
	# material» -y en rojo- tecnicas que tenian el material en el abrigo, y
	# encima sin poder decir cual faltaba, porque no faltaba ninguno.
	# Visto en `ArbolProbe`: «Lazo de fibra · parada por material», con fibra
	# de sobra.
	if fraccion_pagada(tech) < por_dias - HOLGURA_DEL_FRENO \
			and not can_afford(tech):
		return Freno.MATERIAL
	return Freno.JORNADAS


## La causa, dicha en corto para la casilla del panel.
##
## Cadena vacia si no hay nada que decir. Va aqui y no en la ventana porque es
## la misma frase que necesitan la casilla, el aviso emergente y la leyenda, y
## escrita tres veces se separa a la primera.
func causa(tech: Tech) -> String:
	match freno(tech):
		Freno.PRERREQUISITO:
			for need: Tech in (CATALOGUE[tech]["needs"] as Array):
				if not has(need):
					return "tras %s" % tech_name(need).to_lower()
			return "falta lo de antes"
		Freno.OBRA:
			return "pide %s" % CampProjects.project_name(
				needs_camp(tech) as CampProjects.Kind).to_lower()
		Freno.MATERIAL:
			# `missing_for` no puede volver vacia aqui: [freno] solo dice
			# MATERIAL cuando la despensa no da para rematarla.
			return "parada: falta %s" % ", ".join(missing_for(tech))
		Freno.JORNADAS:
			# La cifra que hace falta para DECIDIR es la que queda, no el
			# porcentaje: «faltan 118 de manufactura» dice a quien hay que
			# mover de oficio, y «82 %» no dice nada.
			var job := job_of(tech)
			if job < 0:
				return ""
			var quedan: float = float(CATALOGUE[tech]["days"]) \
				- days_in(job as Profession.Job)
			if quedan <= 0.0:
				return "lista"
			return "faltan %d de %s" % [int(ceilf(quedan)),
				Profession.job_name(job as Profession.Job).to_lower()]
		_:
			return ""


## Lo que falta para poder rematarla, dicho para leerlo. Vacio si no falta.
func missing_for(tech: Tech) -> Array[String]:
	var short: Array[String] = []
	if larder == null:
		return short
	var puesto: Dictionary = pagado.get(int(tech), {})
	for material: int in learning_cost(tech):
		# LO QUE FALTA POR PONER, descontado lo ya gastado a plazos.
		var want := float(learning_cost(tech)[material]) \
			- float(puesto.get(material, 0.0))
		var have := larder.amount(material as Materia.Kind)
		if want > 0.0 and have < want:
			short.append("%.0f %s" % [want - have,
				Materia.material_name(material as Materia.Kind).to_lower()])
	return short


## Lo que ya se lleva gastado en cada tecnica. `tech -> {material: unidades}`.
var pagado: Dictionary = {}


## Que parte del material de una tecnica esta ya puesta, de 0 a 1.
##
## La del material que peor va, no la media: con nodulos de sobra y sin tendon
## no se aprende a montar una azagaya a medias, se para.
func fraccion_pagada(tech: Tech) -> float:
	var cost := learning_cost(tech)
	if cost.is_empty() or larder == null:
		return 1.0
	var puesto: Dictionary = pagado.get(int(tech), {})
	var peor := 1.0
	for material: int in cost:
		var total := float(cost[material])
		if total <= 0.0:
			continue
		peor = minf(peor, float(puesto.get(material, 0.0)) / total)
	return clampf(peor, 0.0, 1.0)


## Va sacando del almacen lo que las jornadas hechas dan derecho a gastar.
##
## Se llama en cada tanda de practica. Para cada tecnica al alcance mira cuanto
## camino llevan hecho las JORNADAS y compra material hasta ponerse a la par; si
## el almacen no da, se compra lo que haya y el progreso se queda ahi hasta que
## alguien traiga mas. Eso es lo que hace que la ventana de tecnicas diga la
## verdad sobre por que una no avanza.
func _ir_pagando() -> void:
	if larder == null:
		return
	for tech: Tech in CATALOGUE.keys():
		if not is_available(tech):
			continue
		var cost := learning_cost(tech)
		if cost.is_empty():
			continue
		var needed: float = float(CATALOGUE[tech]["days"])
		if needed <= 0.0:
			continue
		var job := job_of(tech)
		if job < 0:
			continue
		var camino := clampf(days_in(job as Profession.Job) / needed, 0.0, 1.0)

		var puesto: Dictionary = pagado.get(int(tech), {})
		for material: int in cost:
			var total := float(cost[material])
			var ya := float(puesto.get(material, 0.0))
			var toca := total * camino - ya
			if toca <= 0.0:
				continue
			var sacado := larder.take(material as Materia.Kind, toca)
			if sacado > 0.0:
				puesto[material] = ya + sacado
		pagado[int(tech)] = puesto


func _check_unlocks() -> Array[Tech]:
	var gained: Array[Tech] = []
	for tech: Tech in CATALOGUE.keys():
		if not is_available(tech):
			continue
		if progress(tech) < 1.0:
			continue
		# El material ya esta puesto: se ha ido gastando a plazos mientras se
		# practicaba -ver [_ir_pagando]-, y `progress` no llega a uno hasta que
		# esta pagado del todo. Aqui no se cobra nada; solo se aprende.
		known[tech] = true
		gained.append(tech)
	return gained


static func tech_name(tech: Tech) -> String:
	return CATALOGUE[tech]["name"]


static func tech_desc(tech: Tech) -> String:
	return CATALOGUE[tech]["desc"]
