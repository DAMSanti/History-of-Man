class_name Pinturas
extends RefCounted
## La pared del abrigo: que se pinta, cuando se puede y quien lo hace.
##
## Sale de `SettlementSim` como [Caceria] o [Tajo]. Es el unico trabajo de la
## banda que no da de comer ni fabrica nada, y por eso tiene su propia puerta:
## no se pinta hasta que hay algo que contar -un [Tale]- y hasta que la banda
## puede permitirse el rato.
var sim: SettlementSim

## Los elementos del sitio en la época de la partida, para saber qué cueva es cuál:
## `Exploracion` las cuenta por su índice aquí. Los pone [Campamento] al asentar la
## banda, porque la simulación no sabe de épocas y el hilo de un campamento no debe
## ir a mirarlo a `GameState`. Datos puros, y se guardan con la partida.
var elementos: Array[Dictionary] = []

## El id del sitio, para sembrar la pared: dos sitios con su cueva número 3 no
## tienen la misma roca.
var sitio_id: int = 0

## Las cuevas con arte que este campamento ya ha mirado, para contar su panel una
## sola vez: `cueva -> true`. Se guarda con la partida.
var _miradas: Dictionary = {}

## Las paredes ya montadas, por cueva. Es caché: se rehace de los relatos y de la
## semilla, y no se guarda (`Instantanea.FUERA`).
var _paredes: Dictionary = {}


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## La cueva con arte documentado que es esta cueva del sitio, o vacío.
func arte_de(cueva: int) -> Dictionary:
	if cueva < 0 or cueva >= elementos.size():
		return {}
	var elemento: Dictionary = elementos[cueva]
	if not elemento.has("lat"):
		return {}
	return ArteDeLosDeAntes.en(float(elemento["lat"]), float(elemento["lon"]))


## Por qué no se puede entrar a mirar una cueva, o vacío si se puede.
##
## **Sólo pide que esté explorada**, no la técnica: decisión del usuario del
## 2026-09-15 al planear. Sin arte parietal la cueva de la banda está vacía, pero
## las ajenas enseñan lo suyo. SISTEMAS §13.
func por_que_no_se_entra(cueva: int) -> String:
	if cueva < 0:
		return "no hay cueva"
	if not sim.exploracion.explorada(cueva):
		return "hay que explorarla antes: dentro no se sabe por dónde se va"
	return ""


## Las cuevas de este campamento en las que se puede entrar: `[[cueva, nombre]]`.
## La pide la ficha del sitio en el mapa regional.
func cuevas_para_entrar() -> Array:
	var fuera: Array = []
	for cueva in range(elementos.size()):
		if not por_que_no_se_entra(cueva).is_empty():
			continue
		fuera.append([cueva, String(elementos[cueva].get("name", "la cueva"))])
	return fuera


## Entrar a mirar: la primera vez que se entra en una cueva con arte, lo que se ve
## pasa a la crónica y a lo que la banda cuenta. Devuelve el relato, o null si no
## hay nada nuevo que contar.
##
## **Sin tarea**, a propósito: no es pintable ni sube ningún techo. Mirar pinturas
## ajenas es relato y lore, sin efecto de juego —decisión del usuario del
## 2026-09-15—. Y **no para la partida** con un momento: el texto ya lo tiene el
## jugador delante, en la sala.
func entrar_a_mirar(cueva: int) -> Tale:
	if not por_que_no_se_entra(cueva).is_empty() or _miradas.has(cueva):
		return null
	var arte := arte_de(cueva)
	if arte.is_empty():
		return null
	_miradas[cueva] = true
	var relato := Tale.new()
	relato.kind = Tale.Kind.HALLAZGO
	relato.subject = String(arte["id"])
	relato.title = String(arte["nombre"])
	relato.text = String(arte["texto"])
	relato.day = sim.day
	relato.task = -1
	sim.tales.append(relato)
	sim._note(Chronicle.Kind.GENTE, "En %s: %s" % [relato.title, relato.text], 1)
	return relato


## La pared de una cueva de este campamento: primero lo documentado, después lo
## que la banda pintó allí, por orden.
##
## Lo pintado **se pone donde se pintó**, con el sitio que guarda cada relato. Sólo
## lo pintado antes de que las figuras tuvieran sitio se coloca aquí, una vez, y
## queda guardado en su relato desde entonces.
func pared_de(cueva: int) -> ParedDeLaCueva:
	if _paredes.has(cueva):
		return _paredes[cueva]
	var pared := ParedDeLaCueva.de(sim.game_seed, sitio_id, cueva)
	var arte := arte_de(cueva)
	if not arte.is_empty():
		for figura: Dictionary in ArteDeLosDeAntes.figuras_de(arte):
			pared.colocar(String(figura["motivo"]), String(figura["color"]), true)
	fijar_lo_pintado_sin_cueva()
	for tale: Tale in sim.paintings:
		if tale.cueva != cueva:
			continue
		if tale.sitio.is_empty():
			tale.sitio = pared.colocar(tale.motivo(), _color_de(tale), false)
		else:
			pared.poner(tale.sitio)
	_paredes[cueva] = pared
	return pared


## Lo pintado sin cueva —de antes del 2026-09-15— es de la cueva de la banda. Hay
## que fijarlo **antes** de mudarse: después, «la cueva de la banda» es otra, y las
## pinturas viejas aparecerían en la pared nueva. Lo llama [Traslado].
func fijar_lo_pintado_sin_cueva() -> void:
	for tale: Tale in sim.paintings:
		if tale.cueva < 0:
			tale.cueva = sim.exploracion.cueva_de_la_banda


## De qué color va una figura de la banda: el de su motivo.
static func _color_de(tale: Tale) -> String:
	var motivo := tale.motivo()
	if not Motivos.FIGURAS.has(motivo):
		return "rojo"
	return String((Motivos.FIGURAS[motivo] as Dictionary)["color"])


## Cuánto se puede aprender de oídas sobre una tarea, con lo que hay pintado.
##
## Es [TRANSMISSION_CEILING] más lo que suban las paredes. Sin pinturas devuelve
## exactamente lo de siempre, así que una partida que no pinte nada se comporta
## igual que antes: esto añade, no cambia lo que había.
func paintings_ceiling(task: int) -> float:
	var ceiling := SettlementSim.TRANSMISSION_CEILING
	for tale: Tale in sim.paintings:
		if _painting_covers(tale, task):
			ceiling += SettlementSim.PINTURA_TECHO
	return minf(ceiling, SettlementSim.PINTURA_TECHO_MAX)


## Si una pared enseña algo sobre esta tarea.
##
## Una escena de caza mayor enseña a cazar pieza mayor y no a trenzar cordel,
## así que lo normal es que la tarea coincida clavada. La excepción es el
## relato de una TÉCNICA, que no tiene especialidad -se aprende a hacer el
## arpón, no a hacerlo desde la orilla-: ése cubre el oficio entero.
func _painting_covers(tale: Tale, task: int) -> bool:
	if tale.task < 0 or task < 0:
		return false
	if tale.task == task:
		return true
	if Profession.task_speciality(tale.task) != Profession.Speciality.NINGUNA:
		return false
	return Profession.task_job(tale.task) == Profession.task_job(task)


## Si la banda podría pintar ahora mismo, y qué le falta si no. "" si puede.
##
## Se contesta ENTERO y con nombres, porque es lo que va en el botón del
## momento: ofrecer «pintarlo en la cueva» sin decir que faltan tres de ocre es
## ofrecer un botón que no hace nada.
func painting_blocked_by() -> String:
	if sim.techs == null or not sim.techs.has(TechTree.Tech.ARTE):
		return "todavía no se sabe pintar"
	if not sim.camp_built.get(CampProjects.Kind.HOGAR, false):
		return "hace falta el hogar"
	if sim.toolkit.count(Tool.Kind.LAMPARA) <= 0:
		return "no hay lámpara: dentro no se ve nada"
	if sim.store.amount(Materia.Kind.OCRE) < SettlementSim.PINTURA_OCRE:
		return "falta ocre"
	if sim.store.amount(Materia.Kind.GRASA) < SettlementSim.PINTURA_GRASA:
		return "falta grasa para la lámpara"
	# SÓLO SE PINTA LO EXPLORADO, Y DONDE SE PUEDE (frente 23, 2026-09-13).
	# Antes se pintaba sin haber entrado nunca. Se pinta en la cueva de la banda,
	# que una vez explorada tiene pared siempre: ver
	# [Exploracion.cueva_de_la_banda]. Va DESPUÉS de lo que se lleva dentro —la
	# lámpara, el ocre, la grasa—, que es lo que el jugador junta primero.
	var cueva := sim.exploracion.cueva_de_la_banda
	if not sim.exploracion.explorada(cueva):
		return "hay que explorar la cueva antes de pintarla"
	if not sim.exploracion.pintable(cueva):
		return "esta cueva no tiene pared donde pintar"
	if sim.painting_queue != null:
		return "ya hay una pared empezada"
	return ""


func can_paint() -> bool:
	return painting_blocked_by().is_empty()


## Lo que se puede poner en la pared: todo relato pintable y sin pintar, **también
## lo que pasó antes de saber pintar**, del más viejo al más nuevo.
##
## Es lo que abre la técnica además de pintar —decisión del usuario del
## 2026-09-15—: los relatos se guardan desde el primer día, sepa o no la banda
## pintar, y al aprender la técnica lo vivido antes se puede pintar también. Cada
## uno conserva la fecha de lo que cuenta. SISTEMAS §13.
func pintables() -> Array[Tale]:
	var lista: Array[Tale] = []
	for tale: Tale in sim.tales:
		if tale.paintable() and not tale.painted and tale != sim.painting_queue:
			lista.append(tale)
	lista.sort_custom(func(a: Tale, b: Tale) -> bool: return a.day < b.day)
	return lista


## Manda pintar un relato. Devuelve si se ha podido encolar.
func queue_painting(tale: Tale) -> bool:
	if tale == null or tale.painted or not tale.paintable():
		return false
	if not can_paint():
		return false
	sim.painting_queue = tale
	sim.painting_progress = 0.0
	return true


## La jornada de quien está pintando. La hace el hogar, que es de quien es la
## cueva por dentro —y es donde vive [TechTree.Tech.ARTE] en el árbol—.
##
## Se cobra AL TERMINAR y no al empezar, igual que las obras del campamento:
## una pared a medias no se ha comido el ocre todavía.
func _paint_wall(person: Inhabitant, fraction: float) -> void:
	sim.painting_progress += fraction * person.effectiveness()
	person.log_deed(person.current_task(),
		"pintando %s" % sim.painting_queue.title.to_lower(), false)
	if sim.painting_progress < SettlementSim.PINTURA_JORNADAS:
		return

	var tale := sim.painting_queue
	sim.painting_queue = null
	sim.painting_progress = 0.0

	if sim.store.amount(Materia.Kind.OCRE) < SettlementSim.PINTURA_OCRE \
			or sim.store.amount(Materia.Kind.GRASA) < SettlementSim.PINTURA_GRASA:
		sim._note(Chronicle.Kind.PENURIA,
			"Se quedaron sin ocre a media pared: %s se queda sin pintar."
				% tale.title.to_lower(), 1)
		return

	sim.store.take(Materia.Kind.OCRE, SettlementSim.PINTURA_OCRE)
	sim.store.take(Materia.Kind.GRASA, SettlementSim.PINTURA_GRASA)
	sim.toolkit.use(Tool.Kind.LAMPARA, SettlementSim.PINTURA_JORNADAS
		* Tool.wear_per_day(Tool.Kind.LAMPARA))
	sim.taller._note_breakage(person, Tool.Kind.LAMPARA)

	tale.painted = true
	tale.painted_day = sim.day
	# SU CUEVA Y SU SITIO, al terminar: la figura va donde la roca la recalca, y ahí
	# se queda. La pared se monta antes de añadir el relato, que si no se pondría a
	# sí mismo. Ver [pared_de] y SISTEMAS §13.
	tale.cueva = sim.exploracion.cueva_de_la_banda
	tale.sitio = pared_de(tale.cueva).colocar(tale.motivo(), _color_de(tale), false)
	sim.paintings.append(tale)
	sim._note(Chronicle.Kind.OBRA,
		"%s está en la pared del fondo. Ya no hace falta que quede nadie que "
			% tale.title
		+ "estuviera allí para que se sepa.", 2)
