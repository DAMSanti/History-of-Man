class_name PanelTecnicas
extends RefCounted
## Lo que la banda sabe hacer, oficio por oficio.
##
## Sale de [GameUI], y se separó de [PanelOficios] cuando dejó de ser una lista
## y pasó a ser una ventana con vida propia. «Oficios» es el mapa —qué oficios
## existen y quién los ejerce—; esto es lo OTRO: qué sabe hacer cada oficio hoy
## y qué cambia cuando aprenda lo siguiente.
##
## Tres cosas la separan de lo que había:
##
##   - UNA PESTAÑA POR OFICIO, y dentro sólo lo de ese oficio. Antes la pestaña
##     general llevaba el hogar, la pesca de orilla y la caza colgando debajo
##     del árbol de la manufactura, que es donde nadie los buscaba.
##   - EL ÁRBOL CRECE HACIA ABAJO. Ver [TechGraph].
##   - Y ESTÁ ESCRITA A MANO, con ocre y carbón sobre piel tensada. Es la
##     primera ventana con la piel de la era puesta de verdad; las demás irán
##     detrás. Ver [PielTensada], [Pigmento] y docs/INTERFAZ.md.
##
## En el Paleolítico nadie investiga: se aprende haciendo. Lo que abre una
## técnica son jornadas de oficio y material gastado, no un botón.

## Ancho de la ventana.
##
## Ochocientos, que es mucho más que las otras, y es la rama de la CAZA la que
## lo fija: tiene cuatro técnicas al mismo nivel —cepo, red de aves, ojeo y
## propulsor— y son 720 px de árbol. Con la ventana más estrecha aparecía una
## barra de desplazamiento HORIZONTAL, que es exactamente lo que se quitó al
## poner el árbol en vertical.
const ANCHO := 800

var ui: GameUI

## Qué oficio se está mirando.
var _tab: int = Profession.Job.MANUFACTURA

## Qué se practica para aprender lo de cada oficio, dicho en corto. Va aquí y
## no en [TechTree] porque es un rótulo de interfaz, no un dato de la partida.
const SE_APRENDE := {
	Profession.Job.MANUFACTURA: "Se aprende tallando y trenzando, y se paga en "
		+ "nódulos estropeados: nadie saca una hoja limpia a la primera.",
	Profession.Job.CAZA: "Se aprende cazando. Cada arma nueva no es más daño: "
		+ "es más alcance, y con más alcance la pieza no se va de vista.",
	Profession.Job.RIBERA: "Se aprende en la orilla. Es donde la técnica más se "
		+ "nota: la misma persona en el mismo río trae doce o ciento cinco.",
	Profession.Job.EXPLORACION: "Se aprende andando el valle. Lo que se abre "
		+ "aquí no da comida: da sitios a los que llegar.",
	Profession.Job.HOGAR: "Se aprende alrededor del fuego, que es lo único que "
		+ "la banda hace toda junta.",
}


func _init(panel: GameUI) -> void:
	ui = panel


func show_tech() -> void:
	var body := ui._window("tecnicas", "Técnicas", ANCHO, true)
	ui._clear(body)
	if ui.tech == null:
		_escrito(body, "Sin datos de técnica.")
		return

	if not TechTree.BRANCHES.has(_tab):
		_tab = int(TechTree.BRANCHES.keys()[0])

	_pestanas(body)
	_escrito(body, String(SE_APRENDE.get(_tab, "")), true)
	_arbol(body)
	_leyenda(body)
	_lo_del_oficio(body)


## Las pestañas, una por oficio. Se marca la abierta manchándola de ocre, que
## es lo que hace un dedo con pigmento y no un widget con otro tono de gris.
func _pestanas(body: VBoxContainer) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 3)
	body.add_child(fila)
	for job: int in TechTree.BRANCHES:
		var button := Button.new()
		button.text = Profession.job_name(job as Profession.Job)
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Pigmento.escribir_boton(button,
			UISkin.OCHRE if job == _tab else UISkin.INK_SOFT, 18)
		if job == _tab:
			var manchada := UISkin.button_box("pressed")
			manchada.border_width_bottom = 0
			button.add_theme_stylebox_override("normal", manchada)
			button.add_theme_stylebox_override("hover", manchada)
		button.pressed.connect(func() -> void:
			_tab = job
			show_tech())
		fila.add_child(button)


## El árbol del oficio abierto. Ver [TechGraph].
func _arbol(body: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# El árbol NO se desplaza en vertical por su cuenta: se desplaza la ventana
	# entera, que es la que tiene la barra. Dos barras verticales encajadas es
	# de las peores cosas que se le pueden hacer a una rueda de ratón.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	var graph := TechGraph.new()
	scroll.add_child(graph)
	graph.build(ui.tech, _tab, _util())
	# Doce más de la barra horizontal, que si no tapa la fila de abajo.
	scroll.custom_minimum_size = Vector2(0, graph.custom_minimum_size.y + 12.0)


## Cómo se lee una casilla. Va DEBAJO del árbol y no encima: quien abre la
## ventana mira el árbol primero y la leyenda sólo si no lo entiende.
func _leyenda(body: VBoxContainer) -> void:
	_escrito(body, "La casilla se llena de ocre según se avanza. Llena del todo, "
		+ "dominada; a medias, en marcha; con el filo en carbón, todavía "
		+ "fuera de alcance. Pon el ratón encima para ver qué pide.", true)


## Lo que sólo le pasa a este oficio y no cabe en el árbol.
##
## Es la mitad de la reforma: estos tres bloques colgaban antes del árbol de la
## manufactura, todos seguidos, en la única pestaña que nadie abría buscándolos.
func _lo_del_oficio(body: VBoxContainer) -> void:
	match _tab:
		Profession.Job.CAZA:
			_hunting_block(body)
			_lobo_block(body)
		Profession.Job.RIBERA:
			_fishing_block(body)
		Profession.Job.HOGAR:
			_hogar_block(body)
			_paintings_block(body)


# ------------------------------------------------------ escrito a mano --

## El ancho de verdad que queda para escribir.
##
## No es el de la ventana: hay que quitarle el borde de la piel por los dos
## lados -[PielTensada.DESBORDE]- y la barra de desplazamiento. Sin quitarlo,
## los renglones se salían por la derecha y se leía «la misma persona en el
## mismo río trae» sin el final de la frase.
func _util() -> float:
	return float(ANCHO) - PielTensada.DESBORDE * 2.0 - 16.0


## Un rótulo de sección: en ocre, con un punto delante en vez de un guion.
##
## El punto no es un adorno: leído de lejos parece una marca hecha con el dedo,
## que es de lo que va toda la ventana.
func _rotulo(body: VBoxContainer, texto: String) -> void:
	if body.get_child_count() > 0:
		body.add_child(HSeparator.new())
	var label := Label.new()
	label.text = "•  " + texto
	Pigmento.escribir(label, UISkin.OCHRE, 21)
	body.add_child(label)


## Una línea escrita. `suave` es lo secundario, y va en CARBÓN: seco y roto,
## que es lo que lo manda al segundo plano sin tener que encogerlo.
func _escrito(body: VBoxContainer, texto: String, suave: bool = false) -> Label:
	var label := Label.new()
	label.text = texto
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(_util(), 0)
	Pigmento.escribir(label, UISkin.INK_SOFT if suave else UISkin.INK, 18,
		Pigmento.carbon() if suave else Pigmento.ocre())
	body.add_child(label)
	return label


## Una fila de dos columnas: el nombre a la izquierda y la nota a la derecha.
## Es la forma de casi todo lo que hay debajo del árbol.
func _fila(body: VBoxContainer, nombre: String, nota: String, tinta: Color,
		ayuda: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	var izquierda := Label.new()
	izquierda.text = nombre
	izquierda.custom_minimum_size = Vector2(190, 0)
	izquierda.tooltip_text = ayuda
	izquierda.mouse_filter = Control.MOUSE_FILTER_STOP if not ayuda.is_empty() \
		else Control.MOUSE_FILTER_IGNORE
	Pigmento.escribir(izquierda, tinta, 18)
	row.add_child(izquierda)

	var derecha := Label.new()
	derecha.text = nota
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Pigmento.escribir(derecha, UISkin.INK_SOFT, 16, Pigmento.carbon())
	row.add_child(derecha)


# ---------------------------------------------------------- el hogar --

## Las obras del abrigo. No son técnicas que se aprendan: son cosas que se
## levantan, con su material y sus jornadas.
func _hogar_block(body: VBoxContainer) -> void:
	if ui.sim == null:
		return
	_rotulo(body, "LO QUE SE LEVANTA EN EL ABRIGO")
	for kind: int in CampProjects.all():
		_camp_row(body, kind as CampProjects.Kind)


## Una obra del abrigo: qué es, qué cuesta y en qué punto está.
func _camp_row(body: VBoxContainer, kind: CampProjects.Kind) -> void:
	if ui.sim == null:
		return
	var name_text := CampProjects.project_name(kind)
	if ui.sim.camp_built.get(kind, false):
		var state := "levantado"
		if kind == CampProjects.Kind.HOGAR:
			state = "encendido" if ui.sim.hearth_lit else "APAGADO"
		_fila(body, "◆  %s" % name_text, state, UISkin.INK,
			CampProjects.project_desc(kind))
		return

	var needs := CampProjects.requires(kind)
	if needs >= 0 and not ui.sim.camp_built.get(needs, false):
		_fila(body, "·  %s" % name_text, "falta %s" % CampProjects.project_name(
			needs as CampProjects.Kind).to_lower(), UISkin.INK_FAINT,
			CampProjects.project_desc(kind))
		return

	# El avance va escrito y no en una barra de progreso: una barra con el
	# relleno de serie en medio de una piel escrita a mano canta a widget, y es
	# justo lo que esta ventana esta dejando de ser.
	if ui.sim.camp_queue == kind:
		_fila(body, "▸  %s" % name_text, "en marcha: %.0f de %.0f jornadas" % [
			ui.sim.camp_progress, CampProjects.labor_days(kind)],
			UISkin.OCHRE, CampProjects.project_desc(kind))
	else:
		_fila(body, "▸  %s" % name_text, "%.0f jornadas de hogar"
			% CampProjects.labor_days(kind), UISkin.INK,
			CampProjects.project_desc(kind))
	_escrito(body, "     %s" % CampProjects.project_desc(kind), true)
	_escrito(body, "     %s" % _materials_line(CampProjects.materials(kind)), true)


## Lo que pide una receta, con lo que hay al lado.
##
## «6 piedra, 3 leña» no dice si se puede hacer o no; «6 piedra (hay 14), 3 leña
## (hay 1)» sí, y de un vistazo. Es la mitad de lo que había que adivinar.
func _materials_line(recipe: Dictionary) -> String:
	if ui.sim == null or recipe.is_empty():
		return "sin material"
	var parts: Array[String] = []
	for material: int in recipe:
		var wanted := float(recipe[material])
		var have := ui.sim.store.amount(material as Materia.Kind)
		var mark := "" if have >= wanted else "  ¡faltan %.0f!" % (wanted - have)
		parts.append("%.0f %s (hay %.0f)%s" % [wanted,
			Materia.material_name(material as Materia.Kind).to_lower(),
			have, mark])
	return " · ".join(parts)


## Lo que hay pintado en la pared del fondo.
##
## Va en el hogar porque es de lo mismo: una pared no es un adorno —sube el
## techo de lo que se puede aprender de oídas sobre esa tarea, y lo sube para
## siempre— así que el jugador tiene que poder ver qué hay puesto. Ver [Tale].
func _paintings_block(body: VBoxContainer) -> void:
	if ui.sim == null:
		return
	if ui.sim.techs == null or not ui.sim.techs.has(TechTree.Tech.ARTE):
		return
	_rotulo(body, "LA PARED DEL FONDO")

	if ui.sim.painting_queue != null:
		_escrito(body, "Pintando: %s (%.0f%%)" % [ui.sim.painting_queue.title,
			100.0 * ui.sim.painting_progress / SettlementSim.PINTURA_JORNADAS])

	if ui.sim.paintings.is_empty():
		var falta := ui.sim.pinturas.painting_blocked_by()
		_escrito(body, "La pared está limpia. " + ("Lo que se cuenta dura lo que "
			+ "dure quien lo cuente." if falta.is_empty()
			else "Para pintar: %s." % falta), true)
	else:
		for tale: Tale in ui.sim.paintings:
			_fila(body, "   ·  %s" % tale.title, tale.stamp(), UISkin.INK)
		_escrito(body, "Lo que está en la pared se aprende aunque no quede nadie "
			+ "que estuviera allí.", true)


# -------------------------------------------------------------- caza --

## Cómo caza la banda hoy: las tres ramas, lo que rinde cada una y la línea
## de trampas que hay puesta.
##
## Sin esto, aprender el propulsor es una línea en una lista y no un cambio en
## la jornada.
func _hunting_block(body: VBoxContainer) -> void:
	if ui.sim == null:
		return
	_rotulo(body, "CÓMO SE CAZA HOY")

	for speciality_key: int in [Profession.Speciality.TRAMPAS,
			Profession.Speciality.CAZA_MENOR, Profession.Speciality.CAZA_MAYOR]:
		var speciality := speciality_key as Profession.Speciality
		var nota := ""
		if speciality == Profession.Speciality.TRAMPAS:
			nota = "%d trampas puestas de %d que se pueden atender" % [
				ui.sim.trampas.traps.size(), ui.sim.trampas.trap_allowance()]
		else:
			var known := Hunting.known_improvements(speciality, ui.sim.techs)
			nota = "%.1f piezas por jornada%s" % [
				Hunting.pieces_per_day(speciality, ui.sim.techs),
				"" if known.is_empty() else "  ·  con " + ", ".join(known).to_lower()]
		_fila(body, Profession.speciality_name(speciality), nota, UISkin.INK,
			Profession.speciality_desc(speciality))

		var pending := Hunting.next_improvement(speciality, ui.sim.techs)
		if pending >= 0:
			_escrito(body, "     falta %s: ×%.2f"
				% [TechTree.tech_name(pending as TechTree.Tech).to_lower(),
					_improvement_factor(speciality, pending)], true)

		# Y lo que anda por el coto y NO se puede cobrar por falta de arma. Es
		# la otra mitad de la puerta de [Fauna.huntable_with]: cerrarla en
		# silencio deja al jugador con una cuadrilla que vuelve de vacío de un
		# cotarro lleno de ciervos y ninguna forma de saber por qué.
		if speciality != Profession.Speciality.TRAMPAS:
			var coto := ui.sim.parajes.chosen_for(Subsistence.Activity.CAZA)
			var donde := coto.position if coto != null else ui.sim.home_position
			var escapa := Hunting.out_of_reach_text(speciality, donde,
				GameState.season as Subsistence.Season, ui.sim.toolkit)
			if not escapa.is_empty():
				_escrito(body, "     %s" % escapa, true)

	# Y la línea de trampas, una por una. Es lo único que la banda deja
	# PLANTADO en el mapa, así que merece una lista y no un número.
	if ui.sim.trampas.traps.is_empty():
		_escrito(body, "Sin una sola trampa puesta. Pon a alguien en trampas: "
			+ "es el único trabajo que rinde mientras la banda hace otra cosa.",
			true)
	else:
		for trap: Trap in ui.sim.trampas.traps:
			var ready := trap.soaking >= Trap.days_per_catch(trap.kind)
			_fila(body, "   %s  %s" % ["◆" if ready else "·",
				Trap.trap_name(trap.kind)],
				"en %s — %.0f%% de vida, %d piezas%s" % [
					ui.sim.parajes.place_name(trap.position, ui.sim.home_position),
					trap.condition() * 100.0, trap.taken,
					"  ·  CEBADA" if ready else ""],
				UISkin.INK if ready else UISkin.INK_FAINT)


## El trato con los lobos, que es la otra cosa que puede cambiar la caza y no
## está en el árbol porque no se aprende: se construye o se rompe.
##
## Va en la pestaña de caza y no en una ventana propia porque su efecto es de
## caza: corta el rastro perdido, que es donde se van tres de cada cuatro
## cacerías. Ver [ElLobo].
func _lobo_block(body: VBoxContainer) -> void:
	if ui.sim == null or ui.sim.lobo == null:
		return
	var lobo: ElLobo = ui.sim.lobo
	_rotulo(body, "LOS LOBOS")
	_escrito(body, lobo.resumen())

	if lobo.perro:
		_fila(body, "◆  Corta el rastro", "%.0f %% de las veces que se pierde"
			% (ElLobo.CORTA_EL_RASTRO * 100.0), UISkin.OCHRE)
		_fila(body, "◆  Para la pieza", "×%.2f de fuelle en la carrera"
			% ElLobo.FUELLE_EXTRA, UISkin.OCHRE)
		_fila(body, "◆  Guarda el vivac", "×%.2f de riesgo por noche fuera"
			% ElLobo.VIVAC_MAS_SEGURO, UISkin.OCHRE)
		_fila(body, "·  Y come", "%.1f raciones al día" % ElLobo.COME_AL_DIA,
			UISkin.INK_SOFT)
		return

	if lobo.hostil():
		_fila(body, "✕  La manada en contra", "×%.2f de riesgo por noche fuera"
			% ElLobo.VIVAC_CON_ENEMIGOS, UISkin.ALARM)
		_escrito(body, "Se les dio motivos y no lo olvidan. El trato se " 			+ "recupera solo, pero muy despacio: el miedo se olvida y no rápido.",
			true)
		return

	if lobo.cachorro:
		_fila(body, "▸  Criando el cachorro", "%.0f de %.0f jornadas · come %.1f al día"
			% [lobo.cria, ElLobo.CRIA_JORNADAS, ElLobo.COME_AL_DIA], UISkin.OCHRE)
		return

	# Y si todavía no ha empezado, POR QUÉ no. Es la pregunta que el jugador se
	# hace mirando esta pestaña, y sin contestarla el camino del perro es
	# invisible hasta que salta solo.
	var monton := ui.sim.desechos.volumen() if ui.sim.desechos != null else 0.0
	_fila(body, "Trato con la manada", "%.0f de %.0f" % [lobo.trato,
		ElLobo.TRATO_TOPE], UISkin.INK)
	_fila(body, "Vienen al montón", "%d noches de %d" % [lobo.noches,
		ElLobo.NOCHES_PARA_EMPEZAR], UISkin.INK)
	_fila(body, "El montón", "%.0f litros de %.0f que hacen falta" % [
		monton, ElLobo.MONTON_QUE_ATRAE],
		UISkin.INK if monton >= ElLobo.MONTON_QUE_ATRAE else UISkin.INK_FAINT)
	_escrito(body, "Los lobos vienen a lo que se tira, no a la gente. Sin " 		+ "montón de desechos no se acercan, y sin que se acerquen no hay " 		+ "nada que decidir.", true)


## Cuánto multiplica una técnica de caza en su rama.
func _improvement_factor(speciality: Profession.Speciality, tech_key: int) -> float:
	for entry: Dictionary in (Hunting.MEJORAS.get(speciality, []) as Array):
		if int(entry["tech"]) == tech_key:
			return float(entry["factor"])
	return 1.0


# ------------------------------------------------------------ ribera --

## Con qué se pesca hoy y qué falta para el siguiente escalón.
##
## La pesca es la actividad donde la técnica se nota de verdad en la jornada:
## la misma persona en el mismo río trae doce o ciento cinco según el aparejo
## que lleve. Sin esto, el jugador ve subir el pescado y no sabe por qué.
func _fishing_block(body: VBoxContainer) -> void:
	if ui.sim == null:
		return
	_rotulo(body, "CON QUÉ SE PESCA HOY")

	var actual := ui.sim.fishing_method() as Fishing.Method
	for method_key: int in Fishing.ORDER:
		var method := method_key as Fishing.Method
		var why := Fishing.blocked_by(method, ui.sim.techs, ui.sim.toolkit,
			ui.sim.store, ui.sim.taller.workers_in(Subsistence.Activity.PESCA))
		var pescado: float = float((Fishing.yields_of(method) as Dictionary).get(
			Materia.Kind.PESCADO, 0.0))
		var nota := ""
		# La nasa NO se mide en pescado al día: no es una jornada en el agua,
		# es un aparejo calado. Enseñarla con la cifra del arpón al lado hacía
		# creer que eran dos maneras de hacer lo mismo, y son dos cosas que se
		# hacen a la vez. Ver [Nasa].
		if Fishing.is_passive(method):
			nota = "se cala y pesca sola" if why == "" else why
		else:
			nota = "%.0f de pescado al día" % pescado if why == "" else why
		_fila(body, "%s  %s" % [
			"◆" if method == actual else ("·" if why == "" else " "),
			Fishing.method_name(method)], nota,
			UISkin.OCHRE if method == actual else
			(UISkin.INK if why == "" else UISkin.INK_FAINT),
			Fishing.method_desc(method))

	_escrito(body, "Se pesca siempre con lo mejor que se pueda HOY. Si se rompe "
		+ "el último arpón o se acaba el cebo, se baja un escalón hasta que "
		+ "el taller reponga.", true)

	# Y la línea de nasas, una por una, igual que la de trampas: es lo otro que
	# la banda deja plantado en el mapa.
	if ui.sim.techs != null and ui.sim.techs.has(TechTree.Tech.NASA):
		if ui.sim.nasas_line.nasas.is_empty():
			_escrito(body, "Sin una sola nasa calada. El pescador las revisa por "
				+ "la mañana y luego pesca: no le quita la jornada.", true)
		else:
			for nasa: Nasa in ui.sim.nasas_line.nasas:
				_fila(body, "   %s  Nasa" % ("◆" if nasa.has_catch() else "·"),
					"en %s — %.0f%% de vida, %d piezas  ·  %s" % [
						ui.sim.parajes.place_name(nasa.position,
							ui.sim.home_position),
						nasa.condition() * 100.0, nasa.taken,
						nasa.status_text()],
					UISkin.INK if nasa.has_catch() else UISkin.INK_FAINT)
