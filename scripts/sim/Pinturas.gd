class_name Pinturas
extends RefCounted
## La pared del abrigo: que se pinta, cuando se puede y quien lo hace.
##
## Sale de `SettlementSim` como [Caceria] o [Tajo]. Es el unico trabajo de la
## banda que no da de comer ni fabrica nada, y por eso tiene su propia puerta:
## no se pinta hasta que hay algo que contar -un [Tale]- y hasta que la banda
## puede permitirse el rato.
var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


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
		return "hace falta el sim.hogar"
	if sim.toolkit.count(Tool.Kind.LAMPARA) <= 0:
		return "no hay lámpara: dentro no se ve nada"
	if sim.store.amount(Materia.Kind.OCRE) < SettlementSim.PINTURA_OCRE:
		return "falta ocre"
	if sim.store.amount(Materia.Kind.GRASA) < SettlementSim.PINTURA_GRASA:
		return "falta grasa para la lámpara"
	if sim.painting_queue != null:
		return "ya hay una pared empezada"
	return ""


func can_paint() -> bool:
	return painting_blocked_by().is_empty()


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
	sim.paintings.append(tale)
	sim._note(Chronicle.Kind.OBRA,
		"%s está en la pared del fondo. Ya no hace falta que quede nadie que "
			% tale.title
		+ "estuviera allí para que se sepa.", 2)
