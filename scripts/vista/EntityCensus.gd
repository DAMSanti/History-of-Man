class_name EntityCensus
extends RefCounted
## Qué hay pintado en el mundo ahora mismo, contado y localizable.
##
## Es una herramienta para mirar el juego por dentro, como [TrailView]: no
## forma parte de la partida y el jugador no la necesita para nada. Existe
## porque hasta ahora la única forma de saber si algo se estaba dibujando era
## irse a buscarlo con la cámara, y eso no distingue las tres cosas que se
## confunden todo el rato —no está sembrado, está sembrado y no se dibuja, o
## está dibujado y muy lejos—.
##
## Lo que hace es preguntar a cada sistema que pinta lo que ya sabe de sí
## mismo, sin que ninguno tenga que guardar un registro aparte:
##
##  - la banda, a [SettlementSim], que ya lleva la lista de gente,
##  - la fauna, a [WildlifeHerds], que lleva sus animales con su recorrido,
##  - el bosque, a [Forest], que lleva la siembra ENTERA del valle,
##  - lo demás, a [ResourceProps], que sólo puede contar lo que hay puesto
##    alrededor de la cámara —ver `ResourceProps.census`—.
##
## Esa última diferencia no es un detalle de implementación, es lo que la
## pantalla tiene que decir: «cuarenta y ocho yescas» significa cuarenta y ocho
## a la vista, y «ciento ochenta mil pinos» significa en todo el valle. Contar
## las dos cosas con el mismo rótulo sería mentir.

## Cuántas fichas se dejan recorrer de una silueta.
##
## Hay un tope porque un pinar son cientos de miles de árboles y un «1/187402»
## con flechas no es una herramienta, es una broma. Con doscientos de los más
## cercanos se ve lo que se quiere ver —cómo está plantado esto de aquí— y el
## total sigue estando escrito al lado, que es el dato de verdad.
const SAMPLE_LIMIT := 200

var sim: SettlementSim = null
var herds: WildlifeHerds = null
var props: ResourceProps = null
var forest: Forest = null


func setup(settlement: SettlementSim, wildlife: WildlifeHerds,
		resources: ResourceProps, woods: Forest) -> void:
	sim = settlement
	herds = wildlife
	props = resources
	forest = woods


## Las siluetas que hay, con cuántas de cada una.
##
## Devuelve, por grupo: `key` para volver a pedirlo, `label` para enseñarlo,
## `family` para agruparlo, `count` y `note` —qué significa ese count, que no
## es lo mismo en el bosque que en los props—.
func groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	if sim != null and not sim.people.is_empty():
		out.append({
			"key": "banda", "label": "Banda", "family": "Gente",
			"count": sim.people.size(), "note": "en el valle",
		})

	if herds != null:
		var tally := herds.tally()
		var species: Array = tally.keys()
		species.sort()
		for name: String in species:
			out.append({
				"key": "fauna:%s" % name,
				"label": Fauna.species_name(name),
				"family": "Fauna",
				"count": int(tally[name]),
				"note": "en el valle",
			})

	if forest != null:
		for kind: Dictionary in forest.census():
			if int(kind["count"]) <= 0:
				continue
			out.append({
				"key": "arbol:%s" % String(kind["model"]),
				"label": String(kind["name"]),
				"family": "Bosque",
				"count": int(kind["count"]),
				"note": "sembrados en todo el valle",
			})

	if props != null:
		for entry: Dictionary in props.census():
			out.append({
				"key": "prop:%s" % String(entry["model"]),
				"label": _prop_label(entry),
				"family": "Paisaje" if bool(entry["paisaje"]) else "Recursos",
				"count": int(entry["count"]),
				"note": "pintados alrededor de la cámara",
			})

	return out


## El nombre de una silueta de prop.
##
## Lleva la materia Y el modelo porque ninguno de los dos basta solo: la leña
## se siembra con tres siluetas distintas —rama, tronco seco y otro tronco— y
## con sólo la materia salen tres filas iguales que dicen «leña»; con sólo el
## modelo, «nodulo» no le dice nada a nadie.
func _prop_label(entry: Dictionary) -> String:
	var model := String(entry["model"]).capitalize()
	if bool(entry["paisaje"]):
		return "%s (roca)" % model
	return "%s · %s" % [String(entry["materia"]), model]


## Las fichas de un grupo.
##
## Cada ficha trae `id` —para no perderla de vista entre repintados—, `pos` —a
## dónde lleva la cámara—, `title`, `lines` con lo que se sabe de ella, `tint`
## para el rastro y `trail`: un `Callable` que devuelve los tramos andados, o
## inválido si esa cosa no anda. Una yesca no tiene rastro y no debe fingir
## que lo tiene.
##
## El ORDEN no es el mismo para todo, y a propósito. Lo que anda —gente y
## fauna— va en su orden de siempre, el mismo que en la pestaña de Banda: son
## unas decenas, tienen identidad, y ordenarlas por distancia haría que la
## ficha «3/14» cambiara de bicho sola en cuanto el rebaño se moviera. Lo que
## está clavado —árboles y props— va de más cerca a más lejos de `near`, que
## con miles de piezas iguales es lo único que hace navegable la lista.
func entries(key: String, near: Vector3) -> Array[Dictionary]:
	if key == "banda":
		return _band_entries(near)
	if key.begins_with("fauna:"):
		return _fauna_entries(key.substr(6), near)
	if key.begins_with("arbol:"):
		return _tree_entries(key.substr(6), near)
	if key.begins_with("prop:"):
		return _prop_entries(key.substr(5), near)
	return []


func _band_entries(near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if sim == null:
		return out
	for person: Inhabitant in sim.people:
		out.append({
			"id": "persona:%d" % person.id,
			"pos": person.position,
			"title": person.given_name,
			"tint": TrailView.colour_for(person.id),
			"lines": _person_lines(person),
			"trail": _person_trail.bind(person),
		})
	return out


## Los tramos que ha andado una persona, para el visor de rastros.
##
## La salida DE AHORA va primero, y va aunque esté vacía: el visor le pone el
## rombo al primer tramo, y el rombo marca dónde está. Con las viejas delante,
## el rombo caía en un sitio por donde ya no anda nadie.
func _person_trail(person: Inhabitant) -> Array:
	var paths: Array = [person.journey.get("path", PackedVector3Array())]
	for trip: Dictionary in person.journeys:
		paths.append(trip.get("path", PackedVector3Array()))
	return paths


func _person_lines(person: Inhabitant) -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s · %s de %d años" % [
		"Mujer" if person.sex == Inhabitant.Sex.MUJER else "Hombre",
		person.age_name(), person.age_years])
	lines.append("Está %s." % person.state_name())
	# El oficio, no `has_task`: esa bandera dice si hay TAJO EN EL MAPA, y el
	# hogar no lo tiene -no se cuida el fuego en un paraje-. Preguntandole a
	# ella, quien estaba levantando el hogar salia como «sin tarea asignada»
	# mientras lo levantaba. Sin oficio es `Job.OCIOSO`, y esos si lo estan.
	if person.job != Profession.Job.OCIOSO:
		lines.append("Oficio: %s" % Profession.job_name(
			person.job as Profession.Job))
	else:
		lines.append("Sin tarea asignada.")
	lines.append("Hambre %.0f · fatiga %.0f" % [person.hunger, person.fatigue])
	if not person.journey.is_empty():
		lines.append("Salida en curso: %.0f m andados, %.0f m de casa" % [
			float(person.journey.get("metres", 0.0)),
			float(person.journey.get("farthest", 0.0))])
	lines.append("Salidas cerradas: %d" % person.journeys.size())
	return lines


func _fauna_entries(species: String, near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if herds == null:
		return out
	var config: Dictionary = WildlifeHerds.SPECIES_VISUAL.get(species, {})
	var seen := 0
	for animal: Dictionary in herds.animals():
		if String(animal["species"]) != species:
			continue
		seen += 1
		out.append({
			"id": "fauna:%s:%d" % [species, int(animal["slot"])],
			"pos": animal["position"],
			"title": "%s %d" % [Fauna.species_name(species), seen],
			"tint": _fauna_tint(config),
			"lines": _animal_lines(animal, config),
			"trail": _animal_trail.bind(animal),
		})
	return out


## El recorrido de un animal: uno solo, el que lleva apuntado.
##
## Se pide el diccionario en vez de copiar la lista porque el rastro CRECE
## mientras la ficha está abierta, y un diccionario es una referencia: lo que
## se devuelve aquí es lo que hay en el momento de repintar, no lo que había
## cuando se pulsó.
func _animal_trail(animal: Dictionary) -> Array:
	return [animal["trail"]]


## El color del rastro de un animal.
##
## Se aclara el tinte de la especie en vez de usarlo tal cual: los tintes están
## puestos para que un uro sea pardo oscuro sobre hierba, y una línea de ese
## color sobre el terreno no se ve. Lo que importa aquí es reconocerla.
func _fauna_tint(config: Dictionary) -> Color:
	var base: Color = config.get("tint", Color(0.8, 0.8, 0.8))
	return base.lightened(0.45).lerp(Color(1.0, 0.85, 0.45), 0.25)


func _animal_lines(animal: Dictionary, config: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Está %s." % _state_word(int(animal["state"])))
	lines.append("Hambre %.0f · sed %.0f" % [
		float(animal["hunger"]), float(animal["thirst"])])
	if not config.is_empty():
		lines.append("%s, anda a %.1f m/s" % [
			String(config.get("diet", "?")).capitalize(),
			float(config.get("speed", 0.0))])
	var anchor: Vector3 = animal["anchor"]
	var here: Vector3 = animal["position"]
	lines.append("A %.0f m de su querencia."
		% Vector2(here.x - anchor.x, here.z - anchor.z).length())
	var trail: PackedVector3Array = animal["trail"]
	lines.append("Rastro guardado: %d puntos de %d." % [
		trail.size(), WildlifeHerds.TRAIL_LIMIT])
	return lines


func _state_word(state: int) -> String:
	match state:
		WildlifeHerds.State.BEBIENDO: return "bebiendo"
		WildlifeHerds.State.CAZANDO: return "cazando"
		WildlifeHerds.State.HUYENDO: return "huyendo"
		_: return "vagando"


func _tree_entries(model: String, near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if forest == null:
		return out
	var label := model.capitalize()
	for kind: Dictionary in forest.census():
		if String(kind["model"]) == model:
			label = String(kind["name"])
	var index := 0
	for spot: Vector3 in forest.positions_of(model, near, SAMPLE_LIMIT):
		index += 1
		out.append({
			"id": "arbol:%s:%d,%d" % [model, int(spot.x), int(spot.z)],
			"pos": spot,
			"title": "%s %d" % [label, index],
			"tint": Color(0.55, 0.78, 0.50),
			"lines": ([
				"Silueta: %s" % model,
				"Un árbol no anda: no tiene rastro que pintar.",
			] as Array[String]),
			"trail": Callable(),
		})
	return out


func _prop_entries(model: String, near: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if props == null:
		return out
	var materia := model.capitalize()
	var scenery := false
	for entry: Dictionary in props.census():
		if String(entry["model"]) == model:
			materia = String(entry["materia"])
			scenery = bool(entry["paisaje"])

	# La ficha se llama por la MATERIA, salvo el paisaje, que se llama por la
	# silueta. Las cuatro peñas del canchal son todas «paisaje», así que con la
	# materia salían cuatro listas distintas con fichas de idéntico nombre y no
	# había forma de saber cuál se estaba mirando.
	var stem := model.capitalize() if scenery else materia
	# Se ordena ANTES de numerar, no después: la ficha se llama «Yesca 3» y ese
	# número tiene que querer decir «la tercera más cercana». Numerando primero
	# y ordenando luego, la lista empieza por la «Yesca 812» y el número deja
	# de significar nada.
	var spots := props.positions_of(model)
	var flat := Vector2(near.x, near.z)
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x, a.z).distance_squared_to(flat) \
			< Vector2(b.x, b.z).distance_squared_to(flat))

	var index := 0
	for spot: Vector3 in spots:
		index += 1
		if index > SAMPLE_LIMIT:
			break
		var lines: Array[String] = [
			"Silueta: %s" % model,
		]
		if scenery:
			lines.append("Es paisaje: no se recoge y no se pincha en el mundo, "
				+ "sólo da silueta y sombra.")
		else:
			lines.insert(0, "Materia: %s" % materia)
		out.append({
			"id": "prop:%s:%d,%d" % [model, int(spot.x), int(spot.z)],
			"pos": spot,
			"title": "%s %d" % [stem, index],
			"tint": Color(0.85, 0.70, 0.45),
			"lines": lines,
			"trail": Callable(),
		})
	return out
