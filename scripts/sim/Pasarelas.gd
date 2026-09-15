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
## celdas de agua de ancho** —80 m con la celda de 40 de [Navgrid.CELL]; aquí
## ponía «unos 16 m», que no lo fue nunca—, **40 de leña y 6 jornadas-persona**. El doble de los 20 de leña que
## cuesta aprender la técnica: una obra que se piensa, y que duele perder en una
## riada. No hay tope de número: lo limita lo que cuesta.


## Cuántas celdas de agua seguidas puede salvar una pasarela.
const CELDAS_DE_ANCHO := 2

## Lo que cuesta levantarla.
const LENA := 40.0
const JORNADAS := 6.0

## Desde qué calado una crecida se lleva la obra: el que ya no salva ni con ella,
## el tope de vado con pasarela de [Hydrography.tope_de_vado].
##
## **No es el que cierra el vado a pie**, y lo fue hasta el 2026-09-14: con
## [Hydrography.FORD_IMPASSABLE] la riada se llevaba la pasarela en la misma
## estación en que el vado se cerraba, o sea justo cuando servía, y sólo duraba
## donde el río no se cerraba nunca. Decisión del usuario: «sólo en una crecida
## que ni la pasarela aguanta».
const CRECIDA_QUE_ARRASTRA := 1.0

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
	# PRIMERO DE TODO, LO QUE NO SE ALCANZA. Ver [_hacia_lo_que_no_se_alcanza].
	var sin_acceso := _hacia_lo_que_no_se_alcanza()
	if not sin_acceso.is_empty():
		return sin_acceso
	# Después, EL VADO QUE LA CRECIDA CIERRA. Ver [_vado_que_se_cierra].
	var vado := _vado_que_se_cierra()
	if not vado.is_empty():
		return vado
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


## El cruce que lleva a la parte de valle más grande que la banda NO alcanza.
##
## **Decisión del usuario del 2026-09-14**: «gracias a las pasarelas deberíamos
## tener acceso a todo el mapa». Hasta entonces sólo se miraban los cruces de las
## veredas que la banda ya anda, y a la otra orilla de un río que nunca ha cruzado
## no hay vereda ninguna: esa mitad del valle no se abría jamás.
##
## Se mira la rejilla de caminos: desde una celda de la zona de casa, a lo ancho de
## hasta [CELDAS_DE_ANCHO] celdas **de agua**, ¿hay otra zona al otro lado? Las que
## están al otro lado de un cauce más ancho que dos celdas no se abren con dos
## troncos, y se dice.
##
## **Dos correcciones del 2026-09-14**, las dos de quejas del usuario sobre la
## primera versión de esta regla, escrita ese mismo día:
##
## - **«Está construyendo pasarelas de troncos en el monte, no para cruzar los
##   ríos».** El hueco se buscaba con `cost <= Navgrid.BLOCKED`, y eso en la
##   rejilla significa «no se pasa», NO «hay agua»: un cantil o una ladera de
##   más de la cuenta cuentan igual que un río. Se levantaban pasarelas sobre
##   roca. Ahora la celda tiene que **llevar agua** además de no pasarse
##   ([Navgrid.moja]), que es lo que distingue un vado de un risco.
## - **«Ha hecho una pasarela para cruzar el río pegado al borde del mapa, como a
##   3 km de la cueva; deben estar cerca de la cueva, la clave es la
##   eficiencia».** Se elegía la zona más grande del mapa estuviera donde
##   estuviera, sin mirar la distancia. Ahora se puntúa **lo que abre entre lo
##   que cuesta llegar** —ver [_LEJOS_NI_MIRARLO] y el reparto de abajo—, que es
##   justo «la eficiencia» que pide el usuario.
func _hacia_lo_que_no_se_alcanza() -> Array:
	# LA REJILLA QUE YA HAY, sin pedir que se amase: `sim.navgrid()` la rehace si
	# hace falta, y rehacerla **borra las veredas aprendidas**
	# (`Marcha.forget_routes`). Preguntando por ella aquí, el mismo día en que se
	# elige el cruce se perdía el vado de las veredas —lo cazó `TestPasarela`,
	# 2026-09-14—. Si todavía no hay rejilla, mañana la habrá.
	var rejilla := sim._grid
	if rejilla == null or not rejilla.is_ready():
		return []
	var casa := rejilla.nearest_open(sim.home_position)
	if casa < 0:
		return []
	var zona_de_casa := rejilla.area[casa]
	# Cuántas celdas tiene cada zona: es lo que mide cuánto valle abre el cruce.
	var tamano := {}
	for i in range(rejilla.cost.size()):
		if rejilla.cost[i] > Navgrid.BLOCKED:
			tamano[rejilla.area[i]] = int(tamano.get(rejilla.area[i], 0)) + 1
	var mejor: Array = []
	var mejor_nota := 0.0
	var pasos: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	for i in range(rejilla.cost.size()):
		if rejilla.cost[i] <= Navgrid.BLOCKED or rejilla.area[i] != zona_de_casa:
			continue
		var orilla := rejilla.point_of(i)
		var lejos := _distancia_a_casa(orilla)
		if lejos > _LEJOS_NI_MIRARLO:
			continue
		var x := i % rejilla.wide
		@warning_ignore("integer_division")
		var z := i / rejilla.wide
		for paso: Vector2i in pasos:
			for lado: int in [1, -1]:
				var agua: Array = []
				for salto in range(1, CELDAS_DE_ANCHO + 2):
					var nx := x + paso.x * salto * lado
					var nz := z + paso.y * salto * lado
					if nx < 0 or nz < 0 or nx >= rejilla.wide or nz >= rejilla.tall:
						break
					var j := nz * rejilla.wide + nx
					if rejilla.cost[j] > Navgrid.BLOCKED:
						# Tierra al otro lado: si es otra zona y el agua cabe, vale.
						if rejilla.area[j] != zona_de_casa and not agua.is_empty() \
								and agua.size() <= CELDAS_DE_ANCHO \
								and not hay_en(agua[0]):
							var nota := _cuanto_compensa(
								int(tamano.get(rejilla.area[j], 0)), lejos)
							if nota > mejor_nota:
								mejor = agua.duplicate()
								mejor_nota = nota
						break
					# NO BASTA CON QUE NO SE PASE: tiene que LLEVAR AGUA. Ver la
					# cabecera: sin esto se armaban pasarelas sobre un risco.
					#
					# Se pregunta al terreno y NO a `Navgrid.moja`, que parecía lo
					# suyo: `moja` se rinde y dice que no en cuanto la rejilla no
					# guarda la máscara de vados entera, y entonces no se elegía
					# NINGÚN cruce —tres pruebas en rojo a la vez, 2026-09-14—.
					# Éste es además el mismo criterio que usa
					# [_agua_en_la_recta] para la regla del vado, que es como
					# tiene que ser: una pregunta, un sitio que la contesta.
					var punto := rejilla.point_of(j)
					var calado := sim._terrain.crossing_difficulty_at(punto)
					if Hydrography.can_cross(calado, sim.has_boat, false):
						break
					agua.append(punto)
	return mejor


## Hasta dónde se mira un cruce, en metros desde la cueva.
##
## Decisión del usuario del 2026-09-14 —«deben estar cerca de la cueva, la clave
## es la eficiencia»—, puesta en la escala que ya usa la banda: [Marcha] manda a
## la gente a trabajar dentro del mapa local, y media anchura de ese mapa es lo
## que se recorre y se vuelve en el día. Un cruce más lejos que eso abre terreno
## al que no se va a ir, y son 40 de leña y 6 jornadas-persona.
const _LEJOS_NI_MIRARLO := 1500.0


## Lo que compensa un cruce: cuánto abre partido por lo que cuesta llegar.
##
## No es la zona más grande y ya —eso es lo que mandaba una pasarela a 3 km—, ni
## la más cercana y ya, que armaría dos troncos para abrir un recodo de nada. Es
## el reparto entre las dos, que es lo que el usuario llama «eficiencia». El
## suelo de 200 m evita que un cruce pegado a la puerta salga infinito.
func _cuanto_compensa(celdas_que_abre: int, lejos: float) -> float:
	return float(celdas_que_abre) / maxf(lejos, 200.0)


## Distancia llana de un punto a la cueva. En plano: lo que se compara es cuánto
## hay que andar, no cuánto hay que subir. Ver [dos-clases-de-vector3].
func _distancia_a_casa(punto: Vector3) -> float:
	return Vector2(punto.x - sim.home_position.x,
		punto.z - sim.home_position.z).length()


## El cruce que abre una pasarela DE VERDAD: un vado de una vereda de la banda
## que se anda con el río bajo y se cierra con la crecida del año, estrecho y sin
## pasarela todavía. Vacío si no hay.
##
## Es lo que faltaba (2026-09-14): «si han ido al otro lado del río en verano...».
## La banda cruza andando en verano, su vereda va recta por el vado y la regla del
## rodeo no la veía nunca; y ese vado es exactamente el que en invierno la deja
## sin la otra orilla. De los que hay, el de la vereda más andada —el paso que más
## se usa es el que más se echa de menos cuando se cierra—.
##
## Se descarta el que ni con pasarela se pasaría en la crecida: la riada se la
## llevaría el primer invierno. Ver [CRECIDA_QUE_ARRASTRA].
func _vado_que_se_cierra() -> Array:
	var crecida := 0.0
	for caudal: float in Temporada.CAUDAL.values():
		crecida = maxf(crecida, caudal)
	var mejor: Array = []
	var mas_andada := -1
	for clave: Variant in sim.knowledge.veredas:
		var vereda: Vereda = sim.knowledge.veredas[clave]
		if vereda == null or vereda.hitos.size() < 2 or vereda.recorridos <= mas_andada:
			continue
		for i in range(1, vereda.hitos.size()):
			var celdas := _agua_en_la_recta(vereda.hitos[i - 1], vereda.hitos[i], crecida)
			if celdas.is_empty() or celdas.size() > CELDAS_DE_ANCHO or hay_en(celdas[0]):
				continue
			var aguanta := true
			for celda: Vector3 in celdas:
				if sim._terrain.crossing_difficulty_with(celda, crecida) >= CRECIDA_QUE_ARRASTRA:
					aguanta = false
			if aguanta:
				mejor = celdas
				mas_andada = vereda.recorridos
				break
	return mejor


## Las celdas seguidas que no se vadean en la recta entre dos puntos: con el agua
## de hoy, o con un caudal dado —la crecida, para [_vado_que_se_cierra]—.
func _agua_en_la_recta(desde: Vector3, hasta: Vector3, caudal: float = -1.0) -> Array:
	var celdas: Array = []
	var pasos := maxi(int(desde.distance_to(hasta) / (Navgrid.CELL * 0.5)), 1)
	for i in range(pasos + 1):
		var punto := desde.lerp(hasta, float(i) / float(pasos))
		var calado := sim._terrain.crossing_difficulty_at(punto) if caudal < 0.0 \
			else sim._terrain.crossing_difficulty_with(punto, caudal)
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
