class_name Pasarelas
extends RefCounted
## Las pasarelas de troncos que la banda ha levantado, y dónde.
##
## **Una pasarela abre UN cruce, no el mapa.** Hasta el 2026-09-13 aprender la
## técnica ponía `SettlementSim.has_bridge = true` y con eso se vadeaba
## cualquier cauce del valle menos la mar abierta: una técnica de dos troncos
## funcionaba como un permiso. Ahora la técnica **permite construir**, y lo que
## abre el paso es la obra, en las celdas que ocupa. EPOCA_01 §10.1, tanda 3,
## frente 13.
##
## Las cifras son decisiones del usuario del 2026-09-13, no medidas: **hasta dos
## celdas de agua de ancho** —unos 16 m, dos tramos de tronco con apoyo en
## medio—, **40 de leña y 6 jornadas-persona**. El doble de los 20 de leña que
## cuesta aprender la técnica: una obra que se piensa, y que duele perder en una
## riada. No hay tope de número: lo limita lo que cuesta.


## Cuántas celdas de agua seguidas puede salvar una pasarela.
const CELDAS_DE_ANCHO := 2

## Lo que cuesta levantarla.
const LENA := 40.0
const JORNADAS := 6.0

## Desde qué calado una crecida se lleva la obra.
##
## Es el mismo número con el que el juego decide que un cauce no se vadea a pie
## —[Hydrography.FORD_IMPASSABLE]—, no una cifra nueva: si el río viene tan alto
## que ya no se cruza andando, viene lo bastante alto como para llevarse dos
## troncos.
const CRECIDA_QUE_ARRASTRA := Hydrography.FORD_IMPASSABLE

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Las pasarelas levantadas: cada una, las celdas de agua que salva, por el
## centro de cada celda en coordenadas de mundo.
var puentes: Array = []

## Sube cada vez que se levanta o se pierde una. Es lo que hace que las
## rejillas sepan que están viejas sin tener que compararse celda a celda.
var version: int = 0

## La obra en marcha: las celdas elegidas y las jornadas-persona puestas.
var obra: Array = []
var jornadas_puestas: float = 0.0


## Si hay una pasarela en ese punto del mundo.
##
## **Es la única pregunta** que hacen la rejilla y el andador sobre las
## pasarelas: ver [Navgrid] y [Marcha]. Media celda de radio, que es lo que
## ocupa la obra.
func hay_en(punto: Vector3) -> bool:
	for puente: Array in puentes:
		for celda: Vector3 in puente:
			if absf(celda.x - punto.x) <= Navgrid.CELL * 0.5 \
					and absf(celda.z - punto.z) <= Navgrid.CELL * 0.5:
				return true
	return false


## Todas las celdas con pasarela, en una lista plana. Para la rejilla.
func celdas() -> Array:
	var todas: Array = []
	for puente: Array in puentes:
		todas.append_array(puente)
	return todas


## Levanta una pasarela sobre esas celdas. Devuelve si se ha levantado.
##
## No cobra: cobra quien la manda levantar. Esto es el registro, y lo que
## avisa a las rejillas de que ya no valen.
func levantar(celdas_del_cauce: Array) -> bool:
	if celdas_del_cauce.is_empty() \
			or celdas_del_cauce.size() > CELDAS_DE_ANCHO:
		return false
	puentes.append(celdas_del_cauce.duplicate())
	version += 1
	return true


## Se la lleva una riada. Devuelve si había alguna ahí.
func llevarsela(indice: int) -> bool:
	if indice < 0 or indice >= puentes.size():
		return false
	puentes.remove_at(indice)
	version += 1
	return true


## Un día de obra. Lo llama [SettlementSim] al cerrar la jornada.
##
## **La banda la levanta sola**, que es lo que decidió el usuario: el jugador no
## la coloca. Trabajan los que ese día han salido de exploración —los mismos que
## aprenden los caminos, ver [Inhabitant.oficio_de_hoy]— a una jornada-persona
## cada uno, y la leña se paga al rematarla.
func nuevo_dia() -> void:
	if sim.techs == null or not sim.techs.has(TechTree.Tech.PASARELA):
		return
	if obra.is_empty():
		obra = elegir_cruce()
		jornadas_puestas = 0.0
		if obra.is_empty():
			return
		sim._note(Chronicle.Kind.TIERRA,
			"Hay un paso que se cruza dando un rodeo largo: se puede armar una "
				+ "pasarela de troncos.", 1)
	var manos := 0
	for person: Inhabitant in sim.people:
		if person.oficio_de_hoy == Profession.Job.EXPLORACION:
			manos += 1
	if manos <= 0:
		return
	jornadas_puestas += float(manos)
	if jornadas_puestas < JORNADAS:
		return
	if sim.store.amount(Materia.Kind.LENA) < LENA:
		sim._note(Chronicle.Kind.PENURIA,
			"La pasarela está a falta de leña: hacen falta %.0f haces." % LENA, 0)
		return
	sim.store.take(Materia.Kind.LENA, LENA)
	if levantar(obra):
		sim._note(Chronicle.Kind.TIERRA,
			"Queda armada una pasarela de troncos: ese paso se cruza todo el año.", 2)
	obra = []
	jornadas_puestas = 0.0


## El cruce que más rodeo le ahorra a la banda, en celdas de agua seguidas.
## Vacío si no hay ninguno que valga.
##
## **Sale de los caminos que la banda ya sabe** —`BandKnowledge.veredas`,
## SISTEMAS §18—: la vereda que más se desvía respecto de la línea recta entre
## sus dos extremos es, por definición, la que rodea algo, y lo que rodea en un
## valle con río es el río. Se mira dónde corta esa recta el agua y se cuentan
## las celdas seguidas: si pasan de [CELDAS_DE_ANCHO] no es un cauce para dos
## troncos y se prueba con la vereda siguiente.
##
## No se mide «cuánto ahorraría» rehaciendo la rejilla con la pasarela puesta:
## eso es hornear una rejilla por candidato —novecientos milisegundos cada una—
## y la pregunta que contesta es la misma.
func elegir_cruce() -> Array:
	if sim.knowledge == null or sim._terrain == null:
		return []
	var candidatas: Array = []
	for clave: Variant in sim.knowledge.veredas:
		var vereda: Vereda = sim.knowledge.veredas[clave]
		if vereda == null or vereda.hitos.size() < 2:
			continue
		var andado := 0.0
		for i in range(1, vereda.hitos.size()):
			andado += vereda.hitos[i].distance_to(vereda.hitos[i - 1])
		var recto := vereda.hitos[0].distance_to(vereda.hitos[vereda.hitos.size() - 1])
		candidatas.append({"rodeo": andado - recto, "vereda": vereda})
	candidatas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["rodeo"]) > float(b["rodeo"]))
	for candidata: Dictionary in candidatas:
		var vereda: Vereda = candidata["vereda"]
		var celdas_mojadas := _agua_en_la_recta(vereda.hitos[0],
			vereda.hitos[vereda.hitos.size() - 1])
		if celdas_mojadas.is_empty() or celdas_mojadas.size() > CELDAS_DE_ANCHO:
			continue
		if hay_en(celdas_mojadas[0]):
			continue
		return celdas_mojadas
	return []


## Las celdas seguidas que no se vadean en la recta entre dos puntos.
func _agua_en_la_recta(desde: Vector3, hasta: Vector3) -> Array:
	var celdas: Array = []
	var pasos := maxi(int(desde.distance_to(hasta) / (Navgrid.CELL * 0.5)), 1)
	for i in range(pasos + 1):
		var punto := desde.lerp(hasta, float(i) / float(pasos))
		var calado := sim._terrain.crossing_difficulty_at(punto)
		if Hydrography.can_cross(calado, sim.has_boat, false):
			if not celdas.is_empty():
				# El primer tramo mojado que se acaba es el cauce: lo que venga
				# después es otro, y con uno basta.
				return celdas
			continue
		var centro := _centro_de_la_celda(punto)
		if celdas.is_empty() or not celdas[celdas.size() - 1].is_equal_approx(centro):
			celdas.append(centro)
	return celdas


static func _centro_de_la_celda(punto: Vector3) -> Vector3:
	return Vector3(
		(floor(punto.x / Navgrid.CELL) + 0.5) * Navgrid.CELL, 0.0,
		(floor(punto.z / Navgrid.CELL) + 0.5) * Navgrid.CELL)


## ¿Se la ha llevado una riada? Lo llama [SettlementSim] al entrar la estación.
##
## **Sin sorteo**: se pierde cuando la rejilla de la estación que entra cierra
## ese vado sin contar la pasarela, o sea cuando el cauce viene crecido de
## verdad. La frecuencia sale de la rejilla estacional y no de un dado nuevo,
## que es lo que pedía la spec. Así, una pasarela sobre un cauce que crece todos
## los inviernos se pierde todos los inviernos, y eso se ve al jugar.
func revisar_riada(caudal: float) -> void:
	if sim._terrain == null:
		return
	var i := puentes.size() - 1
	while i >= 0:
		var puente: Array = puentes[i]
		var arrastrada := false
		for celda: Vector3 in puente:
			var calado := sim._terrain.crossing_difficulty_with(celda, caudal)
			if calado >= CRECIDA_QUE_ARRASTRA:
				arrastrada = true
				break
		if arrastrada and llevarsela(i):
			sim._note(Chronicle.Kind.PENURIA,
				"La crecida se ha llevado la pasarela. Ese paso vuelve a estar "
					+ "cortado, y habrá que armarla otra vez.", 2)
		i -= 1
