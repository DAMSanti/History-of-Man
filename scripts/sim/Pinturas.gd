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
	# AL FONDO NO SE BAJA A OSCURAS. Decisión del usuario del 2026-09-19, al unir los dos
	# botones que hacían lo mismo —«pintar la pared del fondo» y «entrar a mirar»— en uno:
	# «Entrar al fondo de la cueva, y para ello hace falta grasa y lámpara, por supuesto».
	#
	# Se PIDE, no se gasta: mirar lo que la banda tiene pintado no puede costarle la
	# despensa. La grasa se cobra al pintar, que es cuando la lámpara arde horas —ver
	# [SettlementSim.PINTURA_GRASA]—.
	return _con_que_alumbrarse(0.01)


## Qué falta para tener luz dentro, o "" si la hay. Un sitio y no dos: lo preguntan entrar
## al fondo y pintar, y con dos copias una diría que se puede y la otra que no.
##
## `grasa` es cuánta hace falta: un pellizco para bajar a mirar, [SettlementSim.PINTURA_GRASA]
## para pintar una pared entera.
func _con_que_alumbrarse(grasa: float) -> String:
	if sim.toolkit.count(Tool.Kind.LAMPARA) <= 0:
		return "no hay lámpara: dentro no se ve nada"
	if sim.store.amount(Materia.Kind.GRASA) < grasa:
		return "falta grasa para la lámpara"
	return ""


## Las cuevas de este campamento en las que se puede entrar: `[[cueva, nombre]]`.
## La pide la ficha del sitio en el mapa regional.
## **Las EXPLORADAS, se pueda bajar hoy o no.** Se filtraba por [por_que_no_se_entra], y
## desde que ésa pide lámpara y grasa (2026-09-19) eso habría hecho DESAPARECER los botones
## en cuanto se acabara el sebo, en vez de decir qué falta. Una cueva explorada existe; si
## no se puede bajar, lo dice el botón.
func cuevas_para_entrar() -> Array:
	var fuera: Array = []
	for cueva in range(elementos.size()):
		if not sim.exploracion.explorada(cueva):
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
	return por_que_no_se_pinta_en(sim.exploracion.cueva_de_la_banda)


## Lo mismo, PARA UNA CUEVA CONCRETA. "" si en ésa se puede pintar.
##
## Existe aparte desde el 2026-09-19, cuando el botón de pintar se metió dentro de la sala
## de la cueva: la sala se abre en **cualquier** cueva —también en una que no es la de la
## banda—, y allí el botón tiene que decir eso y no «falta ocre». Antes la pregunta sólo
## tenía sentido para la cueva de la banda, que es donde se pinta.
func por_que_no_se_pinta_en(cueva: int) -> String:
	if sim.techs == null or not sim.techs.has(TechTree.Tech.ARTE):
		return "todavía no se sabe pintar"
	if not sim.camp_built.get(CampProjects.Kind.HOGAR, false):
		return "hace falta el hogar"
	var sin_luz := _con_que_alumbrarse(SettlementSim.PINTURA_GRASA)
	if not sin_luz.is_empty():
		return sin_luz
	if sim.store.amount(Materia.Kind.OCRE) < SettlementSim.PINTURA_OCRE:
		return "falta ocre"
	# SÓLO SE PINTA LO EXPLORADO, Y DONDE SE PUEDE (frente 23, 2026-09-13).
	# Antes se pintaba sin haber entrado nunca. Se pinta en la cueva de la banda,
	# que una vez explorada tiene pared siempre: ver
	# [Exploracion.cueva_de_la_banda]. Va DESPUÉS de lo que se lleva dentro —la
	# lámpara, el ocre, la grasa—, que es lo que el jugador junta primero.
	if cueva != sim.exploracion.cueva_de_la_banda:
		return "se pinta en la pared del fondo de la cueva de la banda"
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
	# EL SITIO SE RESERVA AHORA, no al terminar. Es lo que permite ver cómo se va llenando
	# la pared: la figura ya está en su hueco, con cero trazos hechos, y quien pinta va
	# subiendo `pintado`. Petición del usuario del 2026-09-19: «al pintar algo, que vea
	# cómo se va pintando en la pared». Reservarlo al terminar dejaba la pared sin nada que
	# enseñar durante toda la obra, y la figura aparecía de golpe.
	tale.cueva = sim.exploracion.cueva_de_la_banda
	sim.painting_figura = pared_de(tale.cueva).colocar(tale.motivo(), _color_de(tale),
		false, 0.0)
	tale.sitio = sim.painting_figura
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
	# Y LA PARED SE ENTERA A LA VEZ: el diccionario es el mismo que tiene la pared —se
	# guardan por referencia—, así que subirlo aquí es subirlo allí.
	if not sim.painting_figura.is_empty():
		sim.painting_figura["pintado"] = clampf(
			sim.painting_progress / maxf(SettlementSim.PINTURA_JORNADAS, 0.0001), 0.0, 1.0)
	if sim.painting_progress < SettlementSim.PINTURA_JORNADAS:
		return

	var tale := sim.painting_queue
	var figura := sim.painting_figura
	sim.painting_queue = null
	sim.painting_progress = 0.0
	sim.painting_figura = {}

	if sim.store.amount(Materia.Kind.OCRE) < SettlementSim.PINTURA_OCRE \
			or sim.store.amount(Materia.Kind.GRASA) < SettlementSim.PINTURA_GRASA:
		# SE BORRA LO EMPEZADO. El sitio estaba reservado desde el primer día, así que una
		# pared que se queda sin ocre tiene que quitar de la roca lo que llevara hecho: si
		# no, quedaría media figura para siempre y sin relato detrás.
		if not figura.is_empty():
			pared_de(tale.cueva).quitar(figura)
		tale.sitio = {}
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
	# SU SITIO YA ESTABA: se reservó al mandar pintar (ver [queue_painting]), y aquí sólo
	# queda darla por terminada. Antes del 2026-09-19 se colocaba en esta línea, y por eso
	# la figura aparecía de golpe en vez de irse llenando.
	if not figura.is_empty():
		figura["pintado"] = 1.0
	sim.paintings.append(tale)
	sim._note(Chronicle.Kind.OBRA,
		"%s está en la pared del fondo. Ya no hace falta que quede nadie que "
			% tale.title
		+ "estuviera allí para que se sepa.", 2)
