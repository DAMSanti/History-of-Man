class_name Contacto
extends RefCounted
## Quién hay ahí fuera, y qué tal os lleváis.
##
## Es la capa exterior de docs/SISTEMAS.md §4: no otra banda simulada —eso está
## fuera de alcance a propósito— sino **gente al final del camino** con la que
## se puede tratar. El primer indicio ya lo exigía la ficha del Paleolítico sin
## que nadie lo hubiera construido: la «concha de lejos» es materia que no es de
## aquí, y que por tanto obliga a que exista una red.
##
## ## Por qué esto NO vive en `Site` ni en `GameState`
##
## En `Site` no, porque [Site] es un **recurso horneado**: sus campos son
## `@export`, vive en `data/sites/cantabria_sites.res`, lo comparten todas las
## partidas y se rehornea con las herramientas. Escribir ahí quién te conoce
## sería escribir estado de partida en un dato de sólo lectura.
##
## En `GameState` tampoco, aunque ahí viva la niebla (`discovered`). `GameState`
## es lo que **cruza escenas** —SPECS.md §2.2—, y esto tiene que recorrerlo la
## instantánea: el trato con cada contraparte es estado de simulación, se firma
## con la jornada y decide el trueque. Va donde va el resto de la partida.

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Qué parte de los emplazamientos de la comarca están ocupados por otro grupo.
##
## Uno de cada cinco. **Es una decisión, no una medida**: no hay dato
## arqueológico que diga cuántos de los 72 emplazamientos usables del
## Magdaleniense estaban habitados a la vez, y ponerlo más alto convertiría la
## expedición en un trámite —siempre encuentras a alguien— y más bajo la
## volvería una lotería. Se ajusta con la partida delante, no aquí.
const OCUPADOS := 0.2

## Los ids de los emplazamientos que tienen gente. Se sortean una vez.
var ocupados: Dictionary = {}

## Con quién se ha tratado ya, y qué tal: {id del Site: trato}.
##
## El trato es la misma idea que `ElLobo.trato` —la spec lo dice— y por el mismo
## motivo: una relación que recuerda es lo que hace que este peldaño del
## comercio escale a los otros tres sin rehacerse. Ver docs/SISTEMAS.md §5.
var trato: Dictionary = {}


## Con qué trato empieza alguien a quien acabas de conocer.
##
## Ni bien ni mal: se parte de cero y se gana o se pierde tratando. Es una
## decisión de diseño, no una cifra medida.
const TRATO_AL_CONOCERSE := 0.0


## Se sortea quién está ocupado. Lo llama [SettlementSim] al empezar la partida.
##
## **El sorteo sale del `_rng` de la simulación** —invariante 2 de SPECS.md §7—
## y no de `randf()`: la misma semilla tiene que dar la misma comarca, o dos
## corridas de la misma partida encuentran vecinos distintos y no se puede
## comparar nada.
## Y SE REPARTE UNA SOLA VEZ. Volver a llamar no hace nada, y es deliberado:
## la comarca no cambia a mitad de partida. Sin esta guarda, una segunda
## llamada volvía a sortear con el `_rng` ya avanzado y salía otra comarca
## —medido: 19 ocupados la primera vez, 12 la segunda—, o sea que la gente que
## habías conocido dejaba de estar donde estaba.
func repartir_la_gente(ids: PackedInt32Array) -> void:
	if not ocupados.is_empty():
		return
	for id: int in ids:
		if sim._rng.randf() < OCUPADOS:
			ocupados[id] = true


## Pone gente en ese emplazamiento, lo hubiera sorteado o no.
##
## Lo usa la primera expedición: ver [Expedicion._volver].
func poblar(id: int) -> void:
	ocupados[id] = true


## Si ese emplazamiento tiene gente.
func hay_gente_en(id: int) -> bool:
	return ocupados.has(id)


## Si ya se ha tratado con la gente de ese emplazamiento.
##
## Es lo que el trueque pregunta antes de ofrecer nada: sin contacto no hay
## «con quién».
func se_conocen(id: int) -> bool:
	return trato.has(id)


## Se conoce a la gente de un emplazamiento. Devuelve si es la primera vez.
##
## Conocer a alguien NO se deshace: por eso el contacto sobrevive a la
## expedición que lo trajo, que es el criterio del frente 5.
func conocerse(id: int) -> bool:
	if trato.has(id):
		return false
	trato[id] = TRATO_AL_CONOCERSE
	return true


## El trato con esa gente. Cero si no os conocéis.
func trato_con(id: int) -> float:
	return float(trato.get(id, 0.0))


## Mueve el trato con esa gente. No hace nada si no os conocéis: no se puede
## quedar bien con quien no has visto.
func mover_el_trato(id: int, cuanto: float) -> void:
	if not trato.has(id):
		return
	trato[id] = clampf(trato_con(id) + cuanto, TRATO_PEOR, TRATO_MEJOR)


## Los topes del trato, para que ni un año de generosidad ni uno de regateo
## dejen la relación fuera de escala. Decisión, no medida.
const TRATO_MEJOR := 100.0
const TRATO_PEOR := -100.0


## Cuánta gente conocida hay. Lo usa la crónica y lo mira la sonda.
func conocidos() -> int:
	return trato.size()
