class_name Paraje
extends RefCounted
## Un sitio con nombre: el objeto sobre el que el jugador manda.
##
## Hasta ahora el valle eran 4.096 celdas anónimas. Agotar un avellanar no
## dolía porque nunca fue «el avellanar»: era `field.cell(23, 41)`. Un sitio
## sin nombre no se echa de menos, y el agotamiento —que está modelado con
## cuidado— no producía ninguna emoción.
##
## Un paraje nace cuando la banda conoce una celda lo bastante como para
## volver a ella a propósito. A partir de ahí tiene nombre, tiene marcador en
## el mundo, y se le puede mandar gente.

## Palabras de sitio. La segunda mitad del nombre sale de aquí, y no es
## decoración: «el recodo» y «la vaguada» son sitios distintos y el jugador se
## acuerda de cuál es cuál.
const LUGARES := [
	"del recodo", "de arriba", "del vado", "de la solana", "de la umbría",
	"del alto", "de abajo", "del hondo", "de la peña", "del regato",
	"de la boca", "del paso", "de la loma", "del cortado", "de la vega",
]

## Cómo se llama el sitio según lo que da. Cada actividad tiene su palabra: un
## avellanar y un cantizal no se parecen en nada y no pueden llamarse igual.
const APODOS := {
	Materia.Kind.FRUTO_SECO: "El avellanar",
	Materia.Kind.BELLOTA: "El robledal",
	Materia.Kind.BAYA: "El zarzal",
	Materia.Kind.RAIZ: "El raizal",
	Materia.Kind.SETA: "El setal",
	Materia.Kind.MIEL: "La colmena",
	Materia.Kind.CARNE: "El pasto",
	Materia.Kind.PESCADO: "El remanso",
	Materia.Kind.MARISCO: "El marisqueo",
	Materia.Kind.PIEDRA: "El cantizal",
	Materia.Kind.SILEX: "La veta de sílex",
	Materia.Kind.ASTA: "El desmogadero",
	Materia.Kind.LENA: "El leñero",
	Materia.Kind.FIBRA: "El fibral",
	Materia.Kind.OCRE: "La veta de ocre",
	Materia.Kind.CORTEZA: "El corteal",
	Materia.Kind.AGUA: "La fuente",
}

## Celda del campo de recursos a la que corresponde.
var cell_x: int = 0
var cell_z: int = 0

## Qué se hace aquí y qué material lo caracteriza. Es el oficio PRINCIPAL:
## el que lo bautizó, el que le pone nombre e icono.
var activity: Subsistence.Activity = Subsistence.Activity.RECOLECCION
var kind: Materia.Kind = Materia.Kind.FRUTO_SECO

## TODOS los oficios que se hacen aquí, empezando por el principal.
##
## Un sitio no es de un oficio: es un sitio. El mismo recodo puede tener
## caza, raíz y cuerna caída a la vez, y eso es UN paraje con tres cosas
## que hacer, no tres parajes en el mismo punto -que es exactamente lo que
## salía antes: «el pasto del recodo», «el raizal del recodo» y «el
## desmogadero del recodo», tres nombres para el mismo trozo de monte.
var activities: Array[int] = []


## Si aquí se hace este oficio.
func serves(activity_value: Subsistence.Activity) -> bool:
	if activities.is_empty():
		return activity == activity_value
	return activities.has(int(activity_value))


## Suma un oficio más a este sitio. Devuelve si de verdad era nuevo.
func add_activity(activity_value: Subsistence.Activity) -> bool:
	if activities.is_empty():
		activities.append(int(activity))
	if activities.has(int(activity_value)):
		return false
	activities.append(int(activity_value))
	return true

var name_text: String = ""
var position: Vector3 = Vector3.ZERO

## Jornada en que la banda lo dio por conocido.
var found_day: int = 1

## Lo ha elegido el jugador a mano, o lo escogió la banda por su cuenta.
var chosen: bool = false

## En descanso: la banda no vuelve hasta que se reponga, aunque sea el mejor.
##
## Es la única forma que tiene el jugador de gestionar el agotamiento sin
## reasignar gente: dejar un sitio en barbecho y llevarse la cuadrilla a otro.
var resting: bool = false


## Lo que hay aquí, y lo que se sabe de ello.
##
## Cada entrada es `Materia.Kind -> {abundancia, sabido}`. Al descubrir un
## paraje se ven las ENTRADAS pero casi ninguna cifra: se sabe que allí hay
## cinco cosas y sólo lo que es una de ellas. Las demás salen como «???» hasta
## que alguien vaya a mirar de cerca.
##
## Es la diferencia entre encontrar un sitio y conocerlo, y es lo que da
## sentido a volver: una batida no repite trabajo, resuelve una incógnita.
var contents: Dictionary = {}

## Radio del paraje en metros. No es un punto: es una mancha de monte.
##
## Y no todos miden lo mismo, que es lo que lo dejaba mal: un paraje de
## pescadores con ciento veinte metros de radio se comia la ladera entera a los
## dos lados del cauce, cuando lo que es de verdad son el agua y su orilla. El
## rio de este valle tiene entre cuarenta y ochenta metros de ancho, asi que
## setenta de radio cubren el cauce y el borde y nada mas. Ver [EXTENSION].
var extent: float = 120.0

## Cuanto abarca un paraje segun de que sea. Lo que no esta aqui usa el radio
## de siempre.
##
## Pendiente de playtest en las cifras; lo que NO esta pendiente es que la
## pesca y el marisqueo abarquen menos que la recoleccion, porque el agua es
## una linea en el paisaje y un avellanar es una mancha.
const EXTENSION := {
	Subsistence.Activity.PESCA: 70.0,
	Subsistence.Activity.MARISQUEO: 70.0,
}


## La forma de verdad del sitio: la mancha de monte que ocupa. Ver [Huella].
##
## `extent` deja de ser el borde del paraje y pasa a ser el ALCANCE con el que
## se busca la forma; el borde lo pone el monte. Un paraje de pesca sale como
## una cinta que sigue el cauce, y un avellanar como la mancha de umbría que
## ocupa, que es justo lo que el jugador pedía: «¿por qué los parajes son
## círculos? Quiero que puedan ser cualquier forma, así se adaptan al río bien
## también, o a una ribera».
##
## Vale `null` hasta que se saca —hace falta el campo de recursos y el
## terreno—, y mientras tanto [contains] cae al disco de siempre.
var huella: Huella = null


## Si este punto cae DENTRO del sitio.
##
## Es lo que antes preguntaba todo el mundo por su cuenta como «distancia al
## centro menor que el radio», y por eso todos los parajes eran redondos.
func contains(point: Vector3) -> bool:
	if huella != null and not huella.vacia():
		return huella.contiene(point)
	return distance_from(point) <= extent


## Vuelve a sacar la forma. Cambia con la estación y con lo que se saque.
func retocar(field: ResourceField, terrain: TerrainGenerator) -> void:
	huella = Huella.de(self, field, terrain)


## Cuánto se sabe de este sitio, de 0 a 1.
func known_fraction() -> float:
	if contents.is_empty():
		return 0.0
	var known := 0
	for kind: int in contents:
		if bool((contents[kind] as Dictionary)["sabido"]):
			known += 1
	return float(known) / float(contents.size())


## Si queda algo por averiguar aquí.
func has_unknowns() -> bool:
	return known_fraction() < 0.999


## Los materiales, con lo que se sepa de cada uno.
##
## Ordenados por abundancia REAL y no por lo sabido: el orden no es
## información que la banda tenga, es cómo está el monte, y ordenar por lo
## conocido delataría cuál es el bueno antes de ir a mirarlo.
func listing() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for kind: int in contents:
		var entry: Dictionary = contents[kind]
		rows.append({
			"kind": kind as Materia.Kind,
			"abundancia": float(entry["abundancia"]),
			"sabido": bool(entry["sabido"]),
		})
	rows.sort_custom(func(a, b): return float(a["abundancia"]) > float(b["abundancia"]))
	return rows


## Resuelve una incógnita. Devuelve qué material se ha averiguado, o -1.
##
## Se descubre el MÁS ABUNDANTE de los que faltan, no uno al azar: quien bate
## un monte una jornada entera se fija primero en lo que más hay, que para eso
## es lo que más se ve.
func reveal_one() -> int:
	var best := -1
	var best_amount := -1.0
	for kind: int in contents:
		var entry: Dictionary = contents[kind]
		if bool(entry["sabido"]):
			continue
		if float(entry["abundancia"]) > best_amount:
			best_amount = float(entry["abundancia"])
			best = kind
	if best >= 0:
		(contents[best] as Dictionary)["sabido"] = true
	return best


static func create(x: int, z: int, activity_value: Subsistence.Activity,
		kind_value: Materia.Kind, world: Vector3, day: int) -> Paraje:
	var paraje := Paraje.new()
	paraje.cell_x = x
	paraje.cell_z = z
	paraje.activity = activity_value
	paraje.activities = [int(activity_value)]
	paraje.kind = kind_value
	paraje.position = world
	paraje.found_day = day
	paraje.extent = float(EXTENSION.get(activity_value, paraje.extent))
	paraje.name_text = build_name(x, z, kind_value)
	return paraje


## Rellena lo que hay aquí a partir del campo de recursos.
##
## Lo que se sabe de entrada es SÓLO el material que le da nombre: se ha visto
## el avellanar desde lejos y se ha visto que es un avellanar. Lo que además
## haya allí -leña, fibra, una veta de ocre- hay que ir a mirarlo.
## Rellena -o RE-rellena- lo que hay en el sitio para la estación que
## corresponda.
##
## No es solo la primera vez: se llama de nuevo cada vez que cambia la
## estación -ver `SettlementSim._advance_local_season`-, porque lo que se
## encuentra en un paraje no es fijo. Un desmogadero tiene cuernas caídas en
## invierno y ninguna en julio; una colmena da miel en verano y nada el
## resto del año. Repetir la llamada y no una tabla estática es lo que hace
## que la estación se note de verdad, no solo en el multiplicador de
## rendimiento sino en QUÉ hay que ir a buscar.
##
## Lo ya sabido no se olvida al cambiar de estación -conocer una colmena no
## se borra porque ahora sea invierno-, así que se preserva antes de
## rehacer la lista.
## El vadeo del suelo que hay debajo, apuntado al nacer el paraje.
##
## Decide QUE puede haber aqui: en el cauce no hay avellanas y en el canchal
## no hay pescado. Ver `Parajes.material_fits`. Se guarda en vez de preguntarle
## al terreno cada vez porque `fill_contents` se llama en cada cambio de
## estacion para los parajes de todo el valle, y el terreno no cambia.
var ford: float = 0.0


func fill_contents(field: ResourceField, season: Subsistence.Season) -> void:
	var previously_known := {}
	for k: int in contents:
		if bool((contents[k] as Dictionary)["sabido"]):
			previously_known[k] = true

	var fresh := {}
	if field == null:
		contents = fresh
		return

	for activity_key: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.MATERIA_PRIMA]:
		var activity_value := activity_key as Subsistence.Activity
		# Lo que el SUELO permite, antes que lo que el campo de recursos diga.
		# Sin esto, una celda del cauce que llegue al umbral de recoleccion se
		# bautiza como avellanar y sale con corteza y ocre en medio del rio.
		if not Parajes.activity_fits(activity_value, ford):
			continue
		var amount := field.seasonal_abundance_at(activity_value, position, season)
		if amount < Parajes.threshold_for(activity_value):
			continue

		# El material que da nombre a la actividad, con la abundancia medida
		# de verdad. Y lo que ADEMÁS se encontraría pasando por ahí -no todo
		# lo que da un sitio es lo que lo bautiza: un cotarro de caza también
		# deja piel y hueso, un avellanar también da seta o miel según toque.
		var primary := Parajes._kind_for(activity_value, position, season)
		if not fresh.has(int(primary)) and Parajes.in_season(primary, season) \
			and Parajes.material_fits(primary, ford):
			fresh[int(primary)] = {
				"abundancia": amount,
				"sabido": primary == kind or previously_known.has(int(primary)),
			}

		var picked := Parajes.extra_materials_at(activity_value, position, primary)
		for extra_kind: Materia.Kind in picked:
			if fresh.has(int(extra_kind)) or not Parajes.in_season(extra_kind, season) \
				or not Parajes.material_fits(extra_kind, ford):
				continue
			# La mitad de lo medido: es lo que se lleva de paso, no lo que se
			# ha ido a buscar.
			fresh[int(extra_kind)] = {
				"abundancia": amount * 0.5,
				"sabido": extra_kind == kind or previously_known.has(int(extra_kind)),
			}

		# Y el resto del surtido de la actividad, de rebusca. No es adorno:
		# es lo que la banda YA se estaba trayendo de aquí y no salía en
		# ninguna ficha. Un recolector vuelve con avellana, baya, bellota y
		# seta del mismo prado —lo da `SettlementSim.SPECIALITY_YIELDS`— y el
		# paraje enseñaba tres cosas de ocho. Con esto la ficha dice lo que
		# de verdad se puede sacar allí, y la pizca es pequeña para que
		# siga habiendo prados buenos y prados flojos.
		for rest: Materia.Kind in (Parajes.EXTRAS_BY_ACTIVITY.get(
				activity_value, []) as Array):
			if fresh.has(int(rest)) or not Parajes.in_season(rest, season) \
				or not Parajes.material_fits(rest, ford):
				continue
			fresh[int(rest)] = {
				"abundancia": amount * Parajes.DE_PASO,
				"sabido": rest == kind or previously_known.has(int(rest)),
			}

	# Siempre hay algo que se lleva quien pasa por allí, aunque el sitio no sea
	# de eso: leña del suelo y fibra de las matas. Salen como incógnita, salvo
	# que ya se supieran de una estación anterior.
	#
	# Siempre, pero EN TIERRA. Esto se metía sin mirar el suelo y era lo último
	# que quedaba mintiendo: cuarenta y un parajes de agua con su haz de leña
	# flotando. Del fondo de un río no se saca leña ni fibra.
	for extra: int in [Materia.Kind.LENA, Materia.Kind.FIBRA]:
		if fresh.has(extra) or not Parajes.material_fits(extra as Materia.Kind, ford):
			continue
		fresh[extra] = {"abundancia": 0.12, "sabido": previously_known.has(extra)}

	contents = fresh


## El nombre sale de la CELDA, no de un azar: el mismo sitio se llama siempre
## igual aunque se descubra en otra partida, y dos parajes vecinos del mismo
## material no comparten nombre.
static func build_name(x: int, z: int, kind_value: Materia.Kind) -> String:
	var base: String = String(APODOS.get(kind_value, "El paraje"))
	var index := (x * 31 + z * 17) % LUGARES.size()
	return "%s %s" % [base, LUGARES[index]]


func id() -> String:
	return "%d_%d_%d" % [cell_x, cell_z, activity]


## A qué distancia queda del campamento, en metros.
func distance_from(home: Vector3) -> float:
	return Vector2(position.x - home.x, position.z - home.z).length()
