class_name Nasa
extends RefCounted
## Una nasa calada en la orilla: dónde está, cómo va y qué lleva dentro.
##
## Es a la pesca lo que [Trap] es a la caza, y por la misma razón de fondo:
## trabaja mientras la banda hace otra cosa. Se cala por la tarde y se levanta
## por la mañana, así que el pescador no está PESCANDO con ella —está
## revisándola— y el resto de su jornada se la lleva la pesca activa, que es la
## que pide estar metido en el agua.
##
## Eso es exactamente lo que la separaba de las demás formas de pescar y lo que
## estaba mal: [Fishing.Method.NASA] era una tabla de rendimiento como el arpón
## o el sedal, o sea una manera de plantarse en la orilla una jornada entera.
## Una nasa no es eso. Una nasa es un objeto que se queda en el río.
##
## La nasa ES una pieza del utillaje —`Tool.Kind.NASA`, que el taller ya sabía
## hacer con tres manojos y medio de fibra— y no un número: al calarla sale del
## utillaje y se queda aquí, gastándose en el agua, y el día que se pudre se
## pierde de verdad. Por eso `tool` es un [Tool] y no un contador: es la MISMA
## pieza que trenzó el cordelero.
##
## Fidelidad: la nasa de mimbre no necesita nada que el Paleolítico superior no
## tuviera —es la cestería del cesto de recolectar, trenzada en embudo— y por
## eso llega antes que el anzuelo y muchísimo antes que el arpón. Ver el orden
## de [Fishing].

## Jornadas que tarda de media en dar una pieza, calada y CEBADA.
##
## Poco más de una jornada: una nasa bien puesta en un buen paso da casi todos
## los días, y eso es lo que la hace valer la fibra que cuesta. Lo que no da es
## MUCHO de una vez —ver [RACIONES_POR_PIEZA]—, así que no sustituye a pescar:
## sostiene los días en que pescar sale mal.
const DIAS_POR_PIEZA := 1.3

## Y sin cebo. No es cero: una nasa vacía coge igual lo que entra a refugiarse
## —la anguila se mete en cualquier agujero—, sólo que mucho menos. Ponerlo a
## cero convertiría el cebo en un interruptor y la nasa en una pieza inútil el
## día que se acaban los caracoles.
const SIN_CEBO := 0.40

## Lo que da una pieza, en raciones-persona. Una anguila, una trucha, un
## salmón pequeño: la nasa coge lo que sube el cauce, no lo que se arponea.
const RACIONES_POR_PIEZA := 4.2

## Cuánto cebo se gasta al cebarla, y cuántas jornadas dura dentro.
##
## El cebo se deslíe y se lo comen: hay que reponerlo, y ésa es la mitad del
## trabajo de revisar la línea. Cuatro jornadas es lo que aguanta un trozo de
## carne o un puñado de caracol en agua fría.
const CEBO_POR_CALADA := 0.6
const DIAS_DE_CEBO := 4.0

## Con qué se ceba. Es lo que haya: un caracol, un trozo de carne, una lapa.
## La misma lista que el sedal y por el mismo motivo —atarse a un solo material
## haría que la nasa dependiera de la temporada del caracol.
const CEBOS := [Materia.Kind.CARACOL, Materia.Kind.CARNE, Materia.Kind.MARISCO]

## Jornadas de brazo que cuesta calarla o levantarla y volver a cebarla.
##
## Es poco a propósito, y es lo que hace que la nasa se lleve bien con la pesca
## activa: revisar la línea es un rato de la mañana, no la jornada. El resto
## del día el pescador está en el agua. Ver `SettlementSim._creel_round`.
const JORNADA_DE_CALAR := 0.22
const JORNADA_DE_REVISAR := 0.12


# --- una nasa concreta, calada en un sitio -------------------------------

## Dónde está calada, en el mundo.
var position: Vector3 = Vector3.ZERO

## Jornada en que se caló.
var set_day: int = 1

## La pieza de mimbre de verdad, con su desgaste. Sale del utillaje al calarla
## y no vuelve: el día que se pudre, se pierde.
var tool: Tool = null

## Jornadas que lleva calada sin que nadie la levante. Es el dato de mirar
## —«ésa lleva cinco días»—, no el que decide lo que ha cobrado.
var soaking: float = 0.0

## Jornadas de pesca EFECTIVAS acumuladas, que es otra cosa.
##
## Se lleva aparte de `soaking` porque el cebo y el estado del mimbre cambian
## mientras la nasa está calada, y hay que cobrarlos EN EL MOMENTO en que
## valían. Con una sola cuenta, una nasa que estuvo cebada cuatro días y cuatro
## sin cebo se resolvía mirando cómo está HOY: si se la encuentra vacía, los
## cuatro buenos se pagaban a precio de mala, y al revés si se la acababan de
## cebar. Las dos respuestas son falsas, y la segunda además es explotable.
var fishing_days: float = 0.0

## Jornadas de cebo que le quedan dentro.
var bait_days: float = 0.0

## Con qué está cebada, o -1 si no lo está. Sirve para poder decirlo.
var bait_kind: int = -1

## Cuántas piezas ha dado desde que se caló. Es la única forma que tiene el
## jugador de saber si ese paso del río era bueno.
var taken: int = 0

## Quién la caló, para poder decirlo en la crónica.
var maker: String = ""


## De 1 (recién calada) a 0 (podrida). Sale del desgaste de la propia pieza,
## que es lo que la hace envejecer de verdad y no una cuenta aparte.
func condition() -> float:
	if tool == null:
		return 1.0
	return tool.condition()


func is_spent() -> bool:
	return tool != null and tool.is_spent()


func is_baited() -> bool:
	return bait_days > 0.0


## Lo que rinde HOY, de 0 a 1. Una nasa vieja coge menos —el mimbre se afloja
## y el embudo pierde la forma, así que el pez que entra vuelve a salir— y una
## sin cebar coge sólo lo que se mete a refugiarse.
func catch_rate() -> float:
	var rate := maxf(condition(), 0.15)
	if not is_baited():
		rate *= SIN_CEBO
	return rate


## Cuántas piezas lleva cobradas, y descuenta lo que se lleva por delante.
func collect() -> int:
	var pieces := int(fishing_days / DIAS_POR_PIEZA)
	if pieces > 0:
		fishing_days -= float(pieces) * DIAS_POR_PIEZA
		taken += pieces
	return pieces


## Si ya tiene algo dentro que merezca ir a levantarla.
func has_catch() -> bool:
	return fishing_days >= DIAS_POR_PIEZA


## Cuánto le falta para la siguiente pieza, de 0 a 1. Para el marcador.
func ready() -> float:
	return clampf(fishing_days / DIAS_POR_PIEZA, 0.0, 1.0)


## Pasa un día por ella: pesca sola, se gasta y se le va el cebo.
##
## Lo que se acumula es la jornada YA PESADA por lo que valía ese día —ver
## `fishing_days`—, y el cebo se descuenta DESPUÉS de cobrarlo: el día en que
## se acaba, se acaba por la noche, no por la mañana.
func soak(days: float = 1.0) -> void:
	soaking += days
	fishing_days += days * catch_rate()
	bait_days = maxf(bait_days - days, 0.0)
	if bait_days <= 0.0:
		bait_kind = -1
	if tool != null:
		tool.wear(Tool.wear_per_day(Tool.Kind.NASA) * days)


## La ceba con lo que se le eche.
func rebait(kind: int) -> void:
	bait_days = DIAS_DE_CEBO
	bait_kind = kind


## Con qué cebo de los que valen hay bastante en el abrigo, o -1 si con
## ninguno. Mismo criterio que [Fishing.bait_at_hand].
static func bait_at_hand(store: Storehouse) -> int:
	if store == null:
		return -1
	for kind: int in CEBOS:
		if store.amount(kind as Materia.Kind) >= CEBO_POR_CALADA:
			return kind
	return -1


## Cómo va, dicho para leerlo.
func status_text() -> String:
	if has_catch():
		return "con algo dentro"
	if not is_baited():
		return "sin cebo"
	return "cebada con %s" % Materia.material_name(
		bait_kind as Materia.Kind).to_lower()


static func create(where: Vector3, day: int, piece: Tool,
		who: String = "") -> Nasa:
	var nasa := Nasa.new()
	nasa.position = where
	nasa.set_day = day
	nasa.tool = piece
	nasa.maker = who
	return nasa
