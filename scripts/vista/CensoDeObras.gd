class_name CensoDeObras
extends RefCounted
## Lo que la banda deja PLANTADO en el mundo, contado y localizable.
##
## Es la mitad que le faltaba a [EntityCensus]. Aquél cuenta lo que EXISTE en el
## valle —gente, fauna, árboles, props—, todo ello sembrado por el mundo o
## nacido con él. Esto cuenta lo otro: lo que la banda ha PUESTO. Una trampa,
## una nasa, el hogar del abrigo, el vivac de anoche.
##
## Y hace falta por lo mismo que hacía falta el censo de entidades: hasta ahora,
## la única forma de saber si una trampa se estaba dibujando era irse a buscarla
## con la cámara, y eso no distingue las tres cosas que se confunden todo el
## rato —no está puesta, está puesta y no se dibuja, o está dibujada y muy
## lejos—. Con cuatro tipos de trampa que se ven casi iguales de lejos, la
## confusión estaba servida.
##
## No guarda registro propio: le pregunta a quien ya lo lleva —`sim.trampas`,
## `sim.nasas_line`, `sim.camp_built` y la propia gente—, igual que hace
## [EntityCensus] con los sistemas que pintan.

var sim: SettlementSim = null


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Las obras que hay, por familia.
##
## Las trampas van SEPARADAS POR TIPO y no en una sola fila de «trampas»: son
## cuatro aparejos distintos con cuatro presas distintas, y el motivo de mirar
## esta lista suele ser justamente «¿el foso se está dibujando como un foso?».
func groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null:
		return out

	if sim.trampas != null:
		var por_tipo: Dictionary = {}
		for trap: Trap in sim.trampas.traps:
			por_tipo[trap.kind] = int(por_tipo.get(trap.kind, 0)) + 1
		for kind: int in Trap.Kind.values():
			if not por_tipo.has(kind):
				continue
			out.append({
				"key": "obra:trampa:%d" % kind,
				"label": Trap.trap_name(kind as Trap.Kind),
				"family": "Obras",
				"count": int(por_tipo[kind]),
				"note": "puestas en el valle",
			})

	if sim.nasas_line != null and not sim.nasas_line.nasas.is_empty():
		out.append({
			"key": "obra:nasa", "label": "Nasa", "family": "Obras",
			"count": sim.nasas_line.nasas.size(), "note": "caladas en el río",
		})

	var levantadas := 0
	for kind: int in CampProjects.all():
		if sim.camp_built.get(kind, false):
			levantadas += 1
	if levantadas > 0:
		out.append({
			"key": "obra:campamento", "label": "Obra del abrigo",
			"family": "Obras", "count": levantadas, "note": "levantadas",
		})

	# LAS PASARELAS, una familia más. Iban aparte, como un párrafo encima de la
	# lista, y por eso una pasarela armada no se podía ir a mirar (INTERFAZ §10).
	# Las levanta la banda sola y no el jugador, pero eso no cambia lo que se
	# quiere hacer con ellas: verlas.
	if sim.pasarelas != null:
		var cuantas := sim.pasarelas.puentes.size()
		if not sim.pasarelas.obra.is_empty():
			cuantas += 1
		if cuantas > 0:
			out.append({
				"key": "obra:pasarela", "label": "Pasarela de troncos",
				"family": "Obras", "count": cuantas,
				"note": "armadas sobre el cauce",
			})

	var vivacs := _vivacs()
	if not vivacs.is_empty():
		out.append({
			"key": "obra:vivac", "label": "Vivac", "family": "Obras",
			"count": vivacs.size(), "note": "acampados esta noche",
		})

	return out


func entries(key: String, near: Vector3) -> Array[Dictionary]:
	if key.begins_with("obra:trampa:"):
		return _trampas(int(key.substr(12)), near)
	if key == "obra:nasa":
		return _nasas(near)
	if key == "obra:pasarela":
		return _pasarelas(near)
	if key == "obra:campamento":
		return _campamento()
	if key == "obra:vivac":
		return _vivac_entries()
	return []


func _trampas(kind: int, near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null or sim.trampas == null:
		return out
	var lista: Array[Trap] = []
	for trap: Trap in sim.trampas.traps:
		if int(trap.kind) == kind:
			lista.append(trap)
	lista.sort_custom(func(a: Trap, b: Trap) -> bool:
		return a.position.distance_squared_to(near) \
			< b.position.distance_squared_to(near))

	var n := 0
	for trap: Trap in lista:
		n += 1
		var cebada := trap.soaking >= Trap.days_per_catch(trap.kind)
		var lines: Array[String] = []
		lines.append("%s en %s." % [Trap.trap_name(trap.kind),
			sim.parajes.place_name(trap.position, sim.home_position)])
		lines.append("CEBADA: hay presa dentro." if cebada
			else "Puesta y esperando: %.1f de %.1f jornadas." % [
				trap.soaking, Trap.days_per_catch(trap.kind)])
		lines.append("Vida del aparejo: %.0f %%." % (trap.condition() * 100.0))
		lines.append("Piezas cobradas: %d." % trap.taken)
		lines.append("A %.0f m del abrigo."
			% sim.home_position.distance_to(trap.position))
		out.append({
			"id": "trampa:%d:%.0f:%.0f" % [kind, trap.position.x, trap.position.z],
			"pos": trap.position,
			"title": "%s %d" % [Trap.trap_name(trap.kind), n],
			"tint": Color(0.90, 0.72, 0.30) if cebada else Color(0.62, 0.55, 0.42),
			"lines": lines,
			"trail": Callable(),
		})
	return out


func _nasas(near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null or sim.nasas_line == null:
		return out
	var lista: Array[Nasa] = []
	lista.assign(sim.nasas_line.nasas)
	lista.sort_custom(func(a: Nasa, b: Nasa) -> bool:
		return a.position.distance_squared_to(near) \
			< b.position.distance_squared_to(near))

	var n := 0
	for nasa: Nasa in lista:
		n += 1
		var lines: Array[String] = []
		lines.append("Calada en %s." % sim.parajes.place_name(
			nasa.position, sim.home_position))
		lines.append(nasa.status_text())
		lines.append("Vida del aparejo: %.0f %%." % (nasa.condition() * 100.0))
		lines.append("Piezas cobradas: %d." % nasa.taken)
		out.append({
			"id": "nasa:%.0f:%.0f" % [nasa.position.x, nasa.position.z],
			"pos": nasa.position,
			"title": "Nasa %d" % n,
			"tint": Color(0.90, 0.72, 0.30) if nasa.has_catch()
				else Color(0.66, 0.56, 0.33),
			"lines": lines,
			"trail": Callable(),
		})
	return out


## Las pasarelas armadas y, la última, la que se está armando.
##
## La de en marcha va en la misma lista y no en una nota aparte: es la misma
## obra en otro momento, y el jugador quiere llevar la cámara a ella igual.
func _pasarelas(near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null or sim.pasarelas == null:
		return out
	var orden: Array[int] = []
	for i in range(sim.pasarelas.puentes.size()):
		orden.append(i)
	orden.sort_custom(func(a: int, b: int) -> bool:
		return _centro(sim.pasarelas.puentes[a]).distance_squared_to(near) \
			< _centro(sim.pasarelas.puentes[b]).distance_squared_to(near))

	var n := 0
	for i: int in orden:
		n += 1
		var puente: Array = sim.pasarelas.puentes[i]
		var donde := _centro(puente)
		var jornada := 0
		if i < sim.pasarelas.rematadas.size():
			jornada = int(sim.pasarelas.rematadas[i])
		var lines: Array[String] = []
		lines.append("Armada en %s." % sim.parajes.place_name(
			donde, sim.home_position))
		lines.append("Salva un paso de %d m."
			% int(float(puente.size()) * Navgrid.CELL))
		if jornada > 0:
			lines.append("Rematada la jornada %d." % jornada)
		else:
			lines.append("Rematada antes de que se apuntara la jornada.")
		lines.append("A %.0f m del abrigo."
			% sim.home_position.distance_to(donde))
		out.append({
			"id": "pasarela:%.0f:%.0f" % [donde.x, donde.z],
			"pos": donde,
			"title": "Pasarela %d" % n,
			"tint": Color(0.72, 0.58, 0.36),
			"lines": lines,
			"trail": Callable(),
		})

	if not sim.pasarelas.obra.is_empty():
		var donde := _centro(sim.pasarelas.obra)
		var lines: Array[String] = []
		lines.append("En marcha en %s." % sim.parajes.place_name(
			donde, sim.home_position))
		lines.append("Salvará un paso de %d m."
			% int(float(sim.pasarelas.obra.size()) * Navgrid.CELL))
		lines.append("%d de %d jornadas puestas." % [
			int(sim.pasarelas.jornadas_puestas), int(Pasarelas.JORNADAS)])
		lines.append("Gastará %.0f de leña al rematarla." % Pasarelas.LENA)
		out.append({
			"id": "pasarela:obra",
			"pos": donde,
			"title": "Pasarela en marcha",
			"tint": Color(0.55, 0.52, 0.45),
			"lines": lines,
			"trail": Callable(),
		})
	return out


## El centro de las celdas que salva una pasarela: adónde se lleva la cámara.
func _centro(celdas: Array) -> Vector3:
	if celdas.is_empty():
		return Vector3.ZERO
	var suma := Vector3.ZERO
	for celda: Vector3 in celdas:
		suma += celda
	return suma / float(celdas.size())


## Las obras del abrigo. Todas caen en el mismo sitio —el abrigo— y aun así van
## una por ficha: lo que se quiere mirar es CUÁL está levantada, no dónde.
func _campamento() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null:
		return out
	for kind: int in CampProjects.all():
		if not sim.camp_built.get(kind, false):
			continue
		var lines: Array[String] = []
		lines.append(CampProjects.project_desc(kind as CampProjects.Kind))
		if kind == CampProjects.Kind.HOGAR:
			lines.append("El fuego está %s." % (
				"encendido" if sim.hearth_lit else "APAGADO"))
		lines.append("Costó %s."
			% CampProjects.trabajo_texto(kind as CampProjects.Kind))
		out.append({
			"id": "campamento:%d" % kind,
			"pos": sim.home_position,
			"title": CampProjects.project_name(kind as CampProjects.Kind),
			"tint": Color(0.85, 0.59, 0.27),
			"lines": lines,
			"trail": Callable(),
		})
	return out


## Quién duerme fuera esta noche y con qué.
##
## Va por PERSONA y no por hoguera: [BivouacFires] junta a los que acampan a
## menos de catorce metros en un solo fuego, y aquí lo que interesa es quién
## pasó la noche a la intemperie y si llevaba lo que hacía falta.
func _vivacs() -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	if sim == null:
		return out
	for person: Inhabitant in sim.people:
		if person.state != Inhabitant.State.DURMIENDO:
			continue
		if person.position.distance_to(sim.home_position) < 60.0:
			continue
		out.append(person)
	return out


func _vivac_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for person: Inhabitant in _vivacs():
		var lines: Array[String] = []
		lines.append("%s duerme en %s." % [person.given_name,
			sim.parajes.place_name(person.position, sim.home_position)])
		lines.append("Tienda: %s." % ("plantada" if person.bivouac_tent
			else "NO — le faltó la piel"))
		lines.append("Hoguera: %s." % ("encendida" if person.bivouac_fire
			else "NO — le faltó la leña"))
		if person.bivouac_botched:
			lines.append("Y lo armó mal: mañana se levanta más cansado.")
		lines.append("A %.0f m del abrigo."
			% sim.home_position.distance_to(person.position))
		out.append({
			"id": "vivac:%d" % person.id,
			"pos": person.position,
			"title": "Vivac de %s" % person.given_name,
			"tint": Color(1.0, 0.62, 0.30) if person.bivouac_fire
				else Color(0.48, 0.52, 0.60),
			"lines": lines,
			"trail": Callable(),
		})
	return out
