@tool
class_name Site
extends Resource
## Un emplazamiento del mapa regional: un sitio donde el terreno ofrece algo.
##
## Es el objeto puente entre las dos escalas. En la capa regional es la unidad
## de decision —donde plantas un campamento, que ruta abres—; al seleccionarlo
## genera el mapa local de 4 km donde se construye de verdad.
##
## Sus atributos NO se escriben a mano: se derivan del relieve real (ver
## SiteDeriver). Ahi es donde la fidelidad historica deja de ser decoracion:
## un campamento costero tiene marisco porque el DEM dice que hay costa rocosa.

## Que clase de sitio es. NO incluye "plataforma": eso mezclaba donde esta un
## emplazamiento con en que epoca existe, que son cosas distintas. Un sitio de
## la plataforma emergida es costero o de valle como cualquier otro; lo que
## cambia es que solo esta disponible con el mar bajo.
enum Kind {
	COSTERO,     ## Junto al mar
	VALLE,       ## Fondo de valle, junto a cauce, llano
	ALTURA,      ## Prominente sobre su entorno: defendible
	INTERIOR,    ## Tierra adentro sin rasgo dominante
}

## Epocas del juego. Un emplazamiento no esta disponible siempre: depende de
## si la tecnologia de la epoca permite ocuparlo. En el Paleolitico no se
## construye, se OCUPA, asi que hace falta abrigo natural.
enum Era {
	PALEOLITICO,
	MESOLITICO,
	NEOLITICO,
	METALES,
	HISTORICA,
}

## Que es cada elemento del registro, y para que sirve.
##
## La distincion importante no es el tipo de OSM sino si es NATURAL o
## CONSTRUIDO. Una cueva ya estaba ahi en el Paleolitico; un dolmen, un castro
## o una ermita los levanto alguien DURANTE la linea temporal del juego, asi
## que ponerlos en el mapa inicial es un anacronismo. Lo construido no es un
## elemento del terreno: es la prueba de que ese sitio se ocupo en esa epoca.
enum Feature {
	ABRIGO,      ## Cueva, covacha, abrigo. Vivienda sin construir y pared para arte
	SIMA,        ## Torca, sima, sumidero. NO habitable: pozo vertical
	CAVIDAD,     ## Cavidad de catalogo sin nombre util. Natural, pero no se
	             ## sabe si es abrigo o pozo, asi que no cuenta como refugio
	SURGENCIA,   ## Fuente, manantial. Agua no estacional
	MEGALITO,    ## Tumulo, dolmen, menhir. Construido, Neolitico/Bronce
	CASTRO,      ## Construido, Edad del Hierro
	ROMANO,      ## Calzada, villa, campamento
	CULTO,       ## Ermita, iglesia. Construido, medieval
	DEFENSIVO,   ## Torre, castillo. Construido, medieval
	INDUSTRIA,   ## Molino, ferreria, mina. Construido, medieval/moderna
	OTRO,
}

## Nivel de evidencia, coherente con el resto del proyecto
enum Fidelity {
	ATESTIGUADO,  ## Yacimiento real documentado
	INFERIDO,     ## Deducido del relieve; plausible pero sin excavar
}

@export var id: int = -1
@export var lon: float = 0.0
@export var lat: float = 0.0
@export var cell: Vector2i = Vector2i.ZERO

@export_group("Derivado del relieve")
## Cota en metros sobre el nivel del mar ACTUAL. Negativa en la plataforma.
@export var elevation: float = 0.0
@export var slope_deg: float = 0.0
## Cuanto se levanta sobre su entorno inmediato, en metros. Define lo defendible.
@export var prominence: float = 0.0
## Distancia al cauce mas cercano, en km
@export var water_km: float = 0.0
## Distancia a la costa con el mar a su cota actual, en km
@export var coast_km: float = 0.0

## Distancia a la costa en cada epoca horneada, paralela a
## SiteSet.derived_at_sea_levels. La costa se mueve, asi que un sitio costero
## hoy puede quedar a trece kilometros del mar en el Ultimo Maximo Glacial.
@export var coast_km_by_era: PackedFloat32Array = PackedFloat32Array()
## Area drenada del cauce mas cercano, en km2
@export var drainage_km2: float = 0.0
@export var kind: Kind = Kind.INTERIOR
@export var score: float = 0.0

## Distancia a la boca de cueva conocida mas cercana, en km.
## No se deduce del relieve: sale del registro real de cavidades. Es el
## atributo decisivo del Paleolitico, cuando no se construye sino que se ocupa.
@export var shelter_km: float = 99.0

## Tiene abrigo utilizable a menos de 500 m
@export var has_shelter: bool = false

@export_group("Contexto")
@export var inside_region: bool = true
@export var historical_name: String = ""
## Que es segun el registro: cueva, yacimiento, ruina
@export var record_kind: String = ""
## Periodo declarado en la fuente, cuando existe
@export var record_period: String = ""
@export var fidelity: Fidelity = Fidelity.INFERIDO

## Tiene entrada enciclopedica propia. Es una senal objetiva de relevancia:
## Altamira, El Castillo o La Garma la tienen; una cueva de catalogo
## espeleologico no. Sirve para que el grupo tome el nombre del sitio que
## importa y no el de un vecino cualquiera.
@export var notable: bool = false

## Elementos reales que caen DENTRO del recuadro local de este emplazamiento.
## Cada entrada: {name, kind, period, lat, lon}. Existe porque yacimientos a
## unos cientos de metros no son asentamientos distintos: Altamira y la Cueva
## de Estalactitas estan a 40 m. Son el mismo sitio con varias cavidades.
@export var features: Array[Dictionary] = []


## Cota del mar a partir de la cual este emplazamiento queda sumergido.
## Es su propia elevacion: cuando el mar la supera, el sitio se pierde.
func drowned_above() -> float:
	return elevation


## Disponible con el mar a la cota dada
func is_available(sea_level_m: float) -> bool:
	return elevation > sea_level_m


## Ya existia antes de que llegara nadie?
## Lo natural puede estar en el mapa desde el primer dia; lo construido no.
static func feature_is_natural(f: Feature) -> bool:
	return f == Feature.ABRIGO or f == Feature.SIMA 		or f == Feature.CAVIDAD or f == Feature.SURGENCIA


## Epoca en la que aparece un elemento construido
static func feature_era(f: Feature) -> Era:
	match f:
		Feature.MEGALITO: return Era.NEOLITICO
		Feature.CASTRO: return Era.METALES
		Feature.ROMANO, Feature.CULTO, Feature.DEFENSIVO, Feature.INDUSTRIA:
			return Era.HISTORICA
		_: return Era.PALEOLITICO


static func feature_name(f: Feature) -> String:
	match f:
		Feature.ABRIGO: return "abrigo"
		Feature.SIMA: return "sima"
		Feature.CAVIDAD: return "cavidad"
		Feature.SURGENCIA: return "surgencia"
		Feature.MEGALITO: return "megalito"
		Feature.CASTRO: return "castro"
		Feature.ROMANO: return "romano"
		Feature.CULTO: return "culto"
		Feature.DEFENSIVO: return "defensivo"
		Feature.INDUSTRIA: return "industria"
		_: return "otro"


## Cuantos abrigos habitables hay en el recuadro.
## Solo ABRIGO: una torca es un pozo vertical, no se vive dentro.
func cave_count() -> int:
	var total := 0
	for f: Dictionary in features:
		if int(f.get("class", Feature.OTRO)) == Feature.ABRIGO:
			total += 1
	return total


## Simas del recuadro. No son sitio de habitacion, pero senalan karst: donde
## hay una torca hay caliza, y donde hay caliza hay mas cuevas sin descubrir.
## Es la pista que necesita la exploracion.
func shaft_count() -> int:
	var total := 0
	for f: Dictionary in features:
		if int(f.get("class", Feature.OTRO)) == Feature.SIMA:
			total += 1
	return total


## Elementos que existen ya en una epoca dada: lo natural siempre, lo
## construido solo desde la epoca en que se levanto.
func features_in(era: Era) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in features:
		var c := int(f.get("class", Feature.OTRO)) as Feature
		if feature_is_natural(c) or feature_era(c) <= era:
			out.append(f)
	return out


## Ocupaciones historicas documentadas en este sitio, con su epoca.
## No son elementos del terreno: son la prueba de que el sitio valia.
func attestations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f: Dictionary in features:
		var c := int(f.get("class", Feature.OTRO)) as Feature
		if not feature_is_natural(c) and not String(f.get("name", "")).is_empty():
			out.append(f)
	return out


## Se puede ocupar en esta epoca?
##
## No es una restriccion arbitraria: en el Paleolitico la vivienda ES la cueva,
## no hay tecnica constructiva que la sustituya. El Mesolitico anade la costa
## (los concheros son campamentos al aire libre junto al marisqueo) y a partir
## del Neolitico se construye, asi que vale casi cualquier sitio habitable.
func is_usable_in(era: Era) -> bool:
	match era:
		Era.PALEOLITICO:
			return has_shelter
		Era.MESOLITICO:
			return has_shelter or coast_km < 2.0
		Era.NEOLITICO:
			return slope_deg < 15.0 and (water_km < 3.0 or coast_km < 3.0)
		_:
			return true


static func era_name(era: Era) -> String:
	match era:
		Era.PALEOLITICO: return "Paleolitico"
		Era.MESOLITICO: return "Mesolitico"
		Era.NEOLITICO: return "Neolitico"
		Era.METALES: return "Edad de los metales"
		_: return "Historica"


## Descripcion para el jugador, compuesta de lo que dice el relieve.
## No es literatura: cada frase sale de un atributo medido.
func describe_for_player(era_index: int = 0) -> String:
	var parts: Array[String] = []

	# Que es
	if has_shelter:
		var caves := cave_count()
		if caves > 1:
			parts.append("Conjunto de %d cavidades. Se ocupa sin construir." % caves)
		else:
			parts.append("Abrigo natural. Se ocupa sin construir nada.")
	elif fidelity == Fidelity.ATESTIGUADO and record_kind == "ruina":
		parts.append("Restos construidos reaprovechables.")
	else:
		parts.append("Emplazamiento al aire libre: exige levantar refugio.")

	# Relieve
	if prominence > 90.0:
		parts.append("Domina %.0f m sobre el entorno: defendible y con buena vista." % prominence)
	elif slope_deg > 20.0:
		parts.append("Ladera pronunciada (%.0f°), mal sitio para construir." % slope_deg)
	elif slope_deg < 8.0:
		parts.append("Terreno llano, comodo para asentarse.")

	# Agua y mar en la epoca que toca
	var sea := coast_km
	if era_index >= 0 and era_index < coast_km_by_era.size():
		sea = coast_km_by_era[era_index]
	if sea < 1.0:
		parts.append("Al pie del mar: marisqueo y pesca de orilla.")
	elif sea < 5.0:
		parts.append("El mar queda a %.1f km, una jornada corta." % sea)

	if water_km < 0.5:
		parts.append("Agua dulce inmediata.")
	elif water_km < 2.0:
		parts.append("Cauce a %.1f km." % water_km)
	else:
		parts.append("Sin agua dulce cerca (%.1f km): condiciona la ocupacion." % water_km)

	return "
".join(parts)


## Nombre para la interfaz
func display_name() -> String:
	if not historical_name.is_empty():
		return historical_name
	return "%s %d" % [kind_name(), id]


## Clase del emplazamiento en una epoca concreta.
## La prominencia y la pendiente no cambian, pero la distancia al mar si, asi
## que la clasificacion tiene que recalcularse con la costa de cada epoca.
func kind_at(era_index: int) -> Kind:
	var distance := coast_km
	if era_index >= 0 and era_index < coast_km_by_era.size():
		distance = coast_km_by_era[era_index]

	if distance < 2.0:
		return Kind.COSTERO
	if prominence > 90.0:
		return Kind.ALTURA
	if water_km < 1.5 and slope_deg < 10.0:
		return Kind.VALLE
	return Kind.INTERIOR


static func name_of(k: Kind) -> String:
	match k:
		Kind.COSTERO: return "Costa"
		Kind.VALLE: return "Valle"
		Kind.ALTURA: return "Altura"
		_: return "Interior"


func kind_name() -> String:
	return name_of(kind)
