class_name TestRelato
extends TestCase
## Lo que se cuenta al volver, y lo que se queda en la pared.
##
## Las dos mitades, porque la gracia está en la diferencia: contado, un relato
## dura lo que dure quien estuvo; pintado, no. Ver [Tale] y
## `Pinturas.paintings_ceiling`.


func suite_name() -> String:
	return "Relato"


func _techs(learned: Array) -> TechTree:
	var techs := TechTree.new()
	for t: int in learned:
		techs.known[t as TechTree.Tech] = true
	return techs


func _pintable() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.techs = _techs([TechTree.Tech.ARTE])
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.toolkit.craft(Tool.Kind.LAMPARA, Tool.Stuff.CUARCITA, 0.6)
	sim.store.add(Materia.Kind.OCRE, 20.0)
	sim.store.add(Materia.Kind.GRASA, 20.0)
	# Explorada y con pared: desde el frente 23 no se pinta sin entrar antes.
	# Ver [TestExploracion] para esa regla.
	sim.exploracion._sabido[sim.exploracion.cueva_de_la_banda] = {
		"explorada": true, "pintable": true}
	return sim


func _relato() -> Tale:
	return Tale.hunt("Beru", "ciervo", "el Vado Alto", 3, true, 12,
		Profession.task_id(Profession.Job.CAZA,
			Profession.Speciality.CAZA_MAYOR))


# --- el relato ------------------------------------------------------------

func test_la_caceria_se_cuenta_con_quien_como_y_donde() -> void:
	var tale := _relato()
	assert_true(tale.text.contains("Beru"), "quién: %s" % tale.text)
	assert_true(tale.text.contains("ciervo"), "qué: %s" % tale.text)
	assert_true(tale.text.contains("Vado Alto"), "dónde: %s" % tale.text)


func test_el_como_cambia_el_relato() -> void:
	# No es lo mismo llegar a tiro sin que te vean que reventar el monte detrás
	# de la pieza. Si las dos se contaran igual, no sería un relato.
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	var callado := Tale.hunt("Beru", "ciervo", "el Vado", 3, true, 12, task)
	var corriendo := Tale.hunt("Beru", "ciervo", "el Vado", 3, false, 12, task)
	assert_true(callado.text != corriendo.text,
		"acechada y perseguida no se cuentan igual")


func test_solo_la_pieza_grande_se_cuenta() -> void:
	# «En el Paleolítico una gran caza no era algo diario»: contar cada conejo
	# del lazo convertiría el relato en ruido.
	var sim := _pintable()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.CAZA
	person.current_speciality = Profession.Speciality.CAZA_MENOR
	sim.people = [person]

	var conejo := Hunt.new()
	conejo.species = "conejo"
	conejo.crew = [person]
	sim._tell_the_hunt(person, conejo)
	assert_eq(sim.tales.size(), 0, "un conejo no se cuenta")

	var ciervo := Hunt.new()
	ciervo.species = "ciervo"
	ciervo.crew = [person]
	sim._tell_the_hunt(person, ciervo)
	assert_eq(sim.tales.size(), 1, "un ciervo sí")


func test_contar_algo_lo_deja_en_la_cronica() -> void:
	var sim := _pintable()
	var antes := sim.chronicle.entries.size()
	sim.tell_tale(_relato())
	assert_gt(float(sim.chronicle.entries.size()), float(antes),
		"lo que se cuenta queda escrito")


func test_aprender_una_tecnica_se_cuenta() -> void:
	# «Cualquier descubrimiento, adelanto tecnológico o hito quiero que se
	# represente también con una historia.»
	var sim := _pintable()
	sim.tell_technique(TechTree.Tech.ARPON)
	assert_eq(sim.tales.size(), 1, "aprender a hacer algo es un hito")
	assert_true(sim.tales[0].title.contains("Arpón"),
		"y se cuenta por su nombre: %s" % sim.tales[0].title)


# --- la pared -------------------------------------------------------------

func test_sin_saber_pintar_no_se_pinta() -> void:
	var sim := _pintable()
	sim.techs = _techs([])
	assert_false(sim.pinturas.can_paint(), "sin arte parietal no hay pared")
	assert_true(sim.pinturas.painting_blocked_by().contains("pintar"),
		"y se dice por qué: %s" % sim.pinturas.painting_blocked_by())


func test_sin_lampara_no_se_pinta_dentro() -> void:
	# Es lo que hace falta de verdad para pintar en una cueva y lo que
	# aparece en Lascaux: un canto ahuecado con grasa y una mecha.
	var sim := _pintable()
	sim.toolkit.pieces.clear()
	assert_false(sim.pinturas.can_paint(), "a oscuras no se pinta")
	assert_true(sim.pinturas.painting_blocked_by().contains("lámpara"),
		"y se dice: %s" % sim.pinturas.painting_blocked_by())


func test_sin_ocre_ni_grasa_no_se_pinta() -> void:
	var sin_ocre := _pintable()
	sin_ocre.store.take(Materia.Kind.OCRE, 20.0)
	assert_true(sin_ocre.pinturas.painting_blocked_by().contains("ocre"),
		"sin pigmento: %s" % sin_ocre.pinturas.painting_blocked_by())

	var sin_grasa := _pintable()
	sin_grasa.store.take(Materia.Kind.GRASA, 20.0)
	assert_true(sin_grasa.pinturas.painting_blocked_by().contains("grasa"),
		"sin combustible: %s" % sin_grasa.pinturas.painting_blocked_by())


func test_pintar_cuesta_jornadas_ocre_y_grasa() -> void:
	var sim := _pintable()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.HOGAR
	sim.people = [person]

	var tale := _relato()
	assert_true(sim.pinturas.queue_painting(tale), "se encola")
	var ocre_antes := sim.store.amount(Materia.Kind.OCRE)

	for _i in range(200):
		if sim.painting_queue == null:
			break
		sim.pinturas._paint_wall(person, 0.1)

	assert_true(tale.painted, "acaba en la pared")
	assert_eq(sim.paintings.size(), 1, "y la pared la guarda")
	assert_lt(sim.store.amount(Materia.Kind.OCRE), ocre_antes,
		"se ha gastado el ocre")


func test_la_pared_sube_el_techo_de_lo_que_se_aprende_de_oidas() -> void:
	# La razón entera de pintar, y lo que dice [TechTree.Tech.ARTE]: fijar lo
	# que se sabe y transmitirlo a quien no estaba.
	var sim := _pintable()
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	assert_near(sim.pinturas.paintings_ceiling(task), SettlementSim.TRANSMISSION_CEILING,
		0.001, "sin paredes, el techo de siempre")

	var tale := _relato()
	tale.painted = true
	sim.paintings.append(tale)
	assert_gt(sim.pinturas.paintings_ceiling(task), SettlementSim.TRANSMISSION_CEILING,
		"con la cacería en la pared se aprende más de oídas")


func test_una_pared_de_caza_no_ensena_a_trenzar_cordel() -> void:
	var sim := _pintable()
	var tale := _relato()
	tale.painted = true
	sim.paintings.append(tale)
	var cordel := Profession.task_id(Profession.Job.MANUFACTURA,
		Profession.Speciality.CORDELERIA)
	assert_near(sim.pinturas.paintings_ceiling(cordel),
		SettlementSim.TRANSMISSION_CEILING, 0.001,
		"un bisonte en la pared no enseña cestería")


func test_el_relato_de_una_tecnica_cubre_el_oficio_entero() -> void:
	# Se aprende a hacer el arpón, no a hacerlo desde la orilla: la técnica no
	# tiene especialidad y por eso cubre todo su oficio.
	var sim := _pintable()
	sim.tell_technique(TechTree.Tech.ARPON)
	var tale := sim.tales[0]
	tale.painted = true
	sim.paintings.append(tale)
	var orilla := Profession.task_id(Profession.Job.RIBERA,
		Profession.Speciality.ORILLA)
	assert_gt(sim.pinturas.paintings_ceiling(orilla),
		SettlementSim.TRANSMISSION_CEILING,
		"el arpón en la pared enseña a toda la ribera")


func test_el_techo_no_llega_nunca_al_todo() -> void:
	# Una parte de lo que sabe un cazador es la mano, y eso no se aprende
	# mirando una pared por muy buena que sea.
	var sim := _pintable()
	var task := Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	for _i in range(50):
		var tale := _relato()
		tale.painted = true
		sim.paintings.append(tale)
	assert_lt(sim.pinturas.paintings_ceiling(task), 1.0,
		"ni con la cueva entera pintada se aprende todo de oídas")
	assert_near(sim.pinturas.paintings_ceiling(task), SettlementSim.PINTURA_TECHO_MAX,
		0.001, "se para donde dice el tope")


func test_no_se_pinta_lo_ya_pintado_ni_dos_a_la_vez() -> void:
	var sim := _pintable()
	var tale := _relato()
	assert_true(sim.pinturas.queue_painting(tale), "la primera entra")
	assert_false(sim.pinturas.queue_painting(_relato()),
		"la segunda espera: sólo hay una pared en marcha")

	tale.painted = true
	sim.painting_queue = null
	assert_false(sim.pinturas.queue_painting(tale), "y lo ya pintado no se repinta")


func test_el_taller_pide_una_lampara_aunque_no_se_sepa_pintar() -> void:
	# Era cero antes de saber pintar —«nadie ahueca un canto para tener luz
	# dentro de la cueva antes de tener algo que hacer dentro»—. Desde la tanda 4
	# EXPLORAR también la pide, y eso se hace desde el primer día: con la
	# demanda a cero no se hacía ninguna y no se podía explorar. Queja del
	# usuario del 2026-09-14, «no me está haciendo lámparas».
	var sim := SettlementSim.new()
	sim.techs = _techs([])
	assert_eq(int(sim.taller.tool_natural_demand().get(Tool.Kind.LAMPARA, 0)), 1,
		"sin arte parietal, una: la de explorar")

	sim.techs = _techs([TechTree.Tech.ARTE])
	assert_gt(float(sim.taller.tool_natural_demand().get(Tool.Kind.LAMPARA, 0)), 0.0,
		"sabiendo pintar, una")


# --- pintar con sitio (SISTEMAS §13, 2026-09-15) ---------------------------------

func _pintar(sim: SettlementSim, cuantos: int) -> Array[Tale]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.HOGAR
	sim.people = [person]
	var pintados: Array[Tale] = []
	var especies := ["ciervo", "caballo", "uro", "jabali", "ciervo"]
	for i in range(cuantos):
		sim.store.add(Materia.Kind.OCRE, 10.0)
		sim.store.add(Materia.Kind.GRASA, 10.0)
		sim.toolkit.craft(Tool.Kind.LAMPARA, Tool.Stuff.CUARCITA, 0.6)
		var tale := Tale.hunt("Beru", String(especies[i % especies.size()]), "el vado",
			3, true, 10 + i, Profession.task_id(Profession.Job.CAZA,
				Profession.Speciality.CAZA_MAYOR))
		if not sim.pinturas.queue_painting(tale):
			continue
		for _j in range(400):
			if sim.painting_queue == null:
				break
			sim.pinturas._paint_wall(person, 0.1)
		pintados.append(tale)
	return pintados


## Cada relato pintado queda con su cueva y su sitio, y la pared tiene una figura
## por relato.
func test_cada_pintura_queda_con_su_cueva_y_su_sitio() -> void:
	var sim := _pintable()
	sim.game_seed = 42
	var pintados := _pintar(sim, 5)
	assert_eq(pintados.size(), 5, "se pintan los cinco")
	var sin_sitio := 0
	for tale: Tale in pintados:
		if tale.cueva != sim.exploracion.cueva_de_la_banda or tale.sitio.is_empty():
			sin_sitio += 1
	assert_eq(sin_sitio, 0, "todos con su cueva y su sitio")
	var pared := sim.pinturas.pared_de(sim.exploracion.cueva_de_la_banda)
	assert_eq(pared.figuras.size(), 5, "cinco figuras en la pared, y ninguna más")


## Mudarse no se lleva las pinturas: siguen en la pared de la cueva vieja.
func test_mudarse_no_mueve_las_pinturas() -> void:
	var sim := _pintable()
	sim.game_seed = 42
	# Una cueva de verdad: en `_pintable` la de la banda es -1, que es justo el valor
	# de «pintado sin cueva», y al mudarse se tomaba por eso.
	var vieja := 2
	sim.exploracion.cueva_de_la_banda = vieja
	sim.exploracion._sabido[vieja] = {"explorada": true, "pintable": true}
	_pintar(sim, 3)
	# Lo que hace `Traslado` con la cueva, que es lo que importa aquí.
	sim.pinturas.fijar_lo_pintado_sin_cueva()
	sim.exploracion.cueva_de_la_banda = vieja + 7
	sim.pinturas._paredes.clear()
	assert_eq(sim.pinturas.pared_de(vieja).figuras.size(), 3, "las tres, en la vieja")
	assert_eq(sim.pinturas.pared_de(vieja + 7).figuras.size(), 0, "y la nueva, limpia")


## Lo pintado antes de que las figuras tuvieran sitio va a la cueva de la banda, y
## se coloca una vez: la segunda pared lo pone donde quedó.
func test_lo_pintado_sin_sitio_se_coloca_una_vez_en_la_cueva_de_la_banda() -> void:
	var sim := _pintable()
	sim.game_seed = 9
	var viejo := _relato()
	viejo.painted = true
	sim.paintings.append(viejo)
	var pared := sim.pinturas.pared_de(sim.exploracion.cueva_de_la_banda)
	assert_eq(viejo.cueva, sim.exploracion.cueva_de_la_banda, "es de la cueva de la banda")
	assert_false(viejo.sitio.is_empty(), "y ya tiene sitio")
	var primero: Vector2 = viejo.sitio["centro"]
	sim.pinturas._paredes.clear()
	sim.pinturas.pared_de(sim.exploracion.cueva_de_la_banda)
	assert_eq(viejo.sitio["centro"], primero, "no se mueve al rehacer la pared")
	assert_eq(pared.figuras.size(), 1, "una figura")


## La misma partida pinta las mismas figuras en los mismos sitios.
func test_misma_partida_mismos_sitios() -> void:
	var sitios: Array = []
	for _vez in range(2):
		var sim := _pintable()
		sim.game_seed = 2026
		var estos: Array = []
		for tale: Tale in _pintar(sim, 4):
			estos.append([tale.sitio["centro"], tale.sitio["giro"], tale.sitio["espejo"]])
		sitios.append(estos)
	assert_eq(str(sitios[0]), str(sitios[1]), "dos corridas, los mismos sitios")


# --- pintar lo de antes (SISTEMAS §13, 2026-09-15) --------------------------------

## Un relato del día 10 y la técnica aprendida el 50: el día 51 se puede encargar, y
## queda en la pared con la fecha de lo que cuenta.
func test_lo_vivido_antes_de_saber_pintar_se_pinta_con_su_fecha() -> void:
	var sim := _pintable()
	sim.techs = _techs([])
	var viejo := _relato()
	viejo.day = 10
	sim.tales.append(viejo)
	sim.day = 50
	assert_false(sim.pinturas.queue_painting(viejo), "sin la técnica, no")
	sim.techs = _techs([TechTree.Tech.ARTE])
	sim.day = 51
	assert_true(sim.pinturas.pintables().has(viejo), "el día 51 está en la lista")
	var pintados_antes := sim.paintings.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.job = Profession.Job.HOGAR
	sim.people = [person]
	assert_true(sim.pinturas.queue_painting(viejo), "y se encarga")
	for _i in range(400):
		if sim.painting_queue == null:
			break
		sim.pinturas._paint_wall(person, 0.1)
	assert_eq(sim.paintings.size(), pintados_antes + 1, "acaba en la pared")
	assert_eq(viejo.day, 10, "con la fecha de lo que cuenta")
	assert_eq(viejo.stamp(), "Jornada 10", "y así se enseña")


## La lista va del más viejo al más nuevo y no trae lo pintado ni lo que no se pinta.
func test_la_lista_de_lo_pintable_va_por_fecha_y_sin_lo_pintado() -> void:
	var sim := _pintable()
	var nuevo := _relato()
	nuevo.day = 30
	var viejo := _relato()
	viejo.day = 5
	var pintado := _relato()
	pintado.painted = true
	var sin_tarea := Tale.discovery("Algo", "", Vector3.ZERO, 3, -1)
	sim.tales.append_array([nuevo, viejo, pintado, sin_tarea])
	var lista := sim.pinturas.pintables()
	assert_eq(lista.size(), 2, "sólo los dos pintables sin pintar")
	assert_true(lista.size() == 2 and lista[0] == viejo and lista[1] == nuevo,
		"del más viejo al más nuevo")


## LA VENTANA ENSEÑA LO QUE SE PODRÍA PINTAR Y EL MOTIVO, PERO YA NO PINTA.
##
## Hasta el 2026-09-19 tenía un botón «Pintar» por relato, y era el sitio equivocado: esto
## es una ventana de gestión y lo que se pinta es la pared del fondo. El botón se **movió**
## a [SalaDeLaCueva] —decisión del usuario, no se duplica—, así que lo que aquí se fija es
## lo contrario de antes: que la lista siga estando con su motivo, y que **no haya ningún
## botón** que abra un segundo camino para lo mismo.
##
## El botón de la sala lo cubre `TestPared.test_la_sala_trae_la_lista_de_lo_que_falta`.
func test_la_ventana_dice_por_que_no_se_pinta_pero_no_pinta() -> void:
	var sim := _pintable()
	sim.techs = _techs([])
	sim.tales.append(_relato())
	var ui := GameUI.new()
	ui.sim = sim
	var body := VBoxContainer.new()
	ui.tecnicas._paintings_block(body)
	assert_eq(_botones(body).size(), 0, "aquí ya no se pinta: ni un botón")
	var dicho := _texto_de(body)
	assert_true(dicho.contains("no se sabe pintar"),
		"sigue diciendo por qué no se puede: %s" % dicho)
	assert_true(dicho.contains("entrando en la cueva"),
		"y dónde se pinta ahora: %s" % dicho)
	assert_true(dicho.contains(_relato().title), "con el relato en la lista")
	body.free()
	sim.techs = _techs([TechTree.Tech.ARTE])
	body = VBoxContainer.new()
	ui.tecnicas._paintings_block(body)
	assert_eq(_botones(body).size(), 0, "con la técnica, tampoco")
	assert_true(_texto_de(body).contains("entrando en la cueva"),
		"y sigue diciendo dónde")
	body.free()
	ui.free()


## Todo el texto de un trozo de ventana, junto, para preguntarle qué dice.
func _texto_de(nodo: Node) -> String:
	var fuera := ""
	for hijo: Node in nodo.get_children():
		if hijo is Label:
			fuera += (hijo as Label).text + "\n"
		fuera += _texto_de(hijo)
	return fuera


func _botones(nodo: Node) -> Array[Button]:
	var fuera: Array[Button] = []
	for hijo: Node in nodo.get_children():
		if hijo is Button:
			fuera.append(hijo as Button)
		fuera.append_array(_botones(hijo))
	return fuera


# --- lo que se lee al entrar (SISTEMAS §13, 2026-09-15) ----------------------------

func _con_covalanas(sim: SettlementSim) -> int:
	var covalanas: Dictionary = ArteDeLosDeAntes.CUEVAS[5]
	sim.pinturas.elementos = [
		{"name": "otra cueva", "lat": 43.0, "lon": -4.0},
		{"name": String(covalanas["nombre"]), "lat": covalanas["lat"], "lon": covalanas["lon"]},
	]
	sim.exploracion._sabido[1] = {"explorada": true, "pintable": true}
	return 1


## La primera vez se cuenta; la segunda, no.
func test_la_primera_entrada_cuenta_el_panel_y_la_segunda_no() -> void:
	var sim := _pintable()
	var cueva := _con_covalanas(sim)
	var relatos := sim.tales.size()
	var primera := sim.pinturas.entrar_a_mirar(cueva)
	assert_true(primera != null, "la primera vez hay relato")
	assert_eq(sim.tales.size(), relatos + 1, "y queda en lo que la banda cuenta")
	assert_true(primera != null and primera.text.contains("ciervas"), "con el texto del panel")
	assert_true(sim.pinturas.entrar_a_mirar(cueva) == null, "la segunda, nada")
	assert_eq(sim.tales.size(), relatos + 1, "ni un relato más")


## Mirar no cambia nada más: ni techos, ni lo pintado, ni lo que se puede pintar.
func test_mirar_arte_ajeno_no_tiene_efecto_de_juego() -> void:
	var sim := _pintable()
	var cueva := _con_covalanas(sim)
	var tarea := Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR)
	var techo := sim.pinturas.paintings_ceiling(tarea)
	var pintables := sim.pinturas.pintables().size()
	var pintados := sim.paintings.size()
	var relato := sim.pinturas.entrar_a_mirar(cueva)
	assert_true(relato != null and not relato.paintable(), "no es pintable")
	assert_eq(sim.pinturas.paintings_ceiling(tarea), techo, "el techo no se mueve")
	assert_eq(sim.pinturas.pintables().size(), pintables, "no hay nada nuevo que pintar")
	assert_eq(sim.paintings.size(), pintados, "ni en la pared")


## Sin explorar no se entra, se sepa pintar o no; explorada, sí, aunque no se sepa.
func test_se_entra_en_lo_explorado_sin_hacer_falta_la_tecnica() -> void:
	var sim := _pintable()
	sim.techs = _techs([])
	assert_false(sim.pinturas.por_que_no_se_entra(6).is_empty(), "sin explorar, no")
	sim.exploracion._sabido[6] = {"explorada": true, "pintable": false}
	assert_eq(sim.pinturas.por_que_no_se_entra(6), "", "explorada, sí, sin la técnica")

