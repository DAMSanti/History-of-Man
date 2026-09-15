class_name TestExploracion
extends TestCase
## Explorar una cueva cuesta lámpara, grasa y una jornada de alguien del hogar.
##
## Frente 22 de EPOCA_01 §10.1, tanda 4. Antes el botón de explorar no costaba
## nada: revelaba el entorno al instante.


func suite_name() -> String:
	return "Cuevas"


## Una banda con lámpara, grasa y alguien en el hogar.
func _sim(con_lampara := true, grasa := 5.0, hogar := true) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.techs = TechTree.new()
	sim.toolkit = Toolkit.new()
	sim.game_seed = 7
	var person := Inhabitant.new()
	person.id = 3
	person.age_group = Inhabitant.Age.ADULTO
	person.job = Profession.Job.HOGAR if hogar else Profession.Job.CAZA
	sim.people = [person]
	if con_lampara:
		sim.toolkit.add(Tool.make(Tool.Kind.LAMPARA, Tool.default_stuff(Tool.Kind.LAMPARA)))
	if grasa > 0.0:
		sim.store.add(Materia.Kind.GRASA, grasa)
	return sim


func test_sin_lampara_no_se_entra() -> void:
	var sim := _sim(false)
	assert_eq(sim.exploracion.lo_que_falta(1), "hace falta una lámpara de grasa",
		"la orden dice qué falta")
	assert_false(sim.exploracion.mandar(1), "y no sale nadie")


func test_sin_grasa_tampoco() -> void:
	var sim := _sim(true, 0.0)
	assert_eq(sim.exploracion.lo_que_falta(1), "hace falta grasa para la lámpara",
		"la lámpara sin grasa no alumbra")
	assert_false(sim.exploracion.mandar(1), "y no sale nadie")


func test_hace_falta_alguien_del_hogar() -> void:
	var sim := _sim(true, 5.0, false)
	assert_eq(sim.exploracion.lo_que_falta(1), "hace falta alguien del hogar",
		"no entra el primero que pase")


func test_explorar_gasta_grasa_y_una_jornada_entera() -> void:
	var sim := _sim()
	assert_true(sim.exploracion.mandar(1), "con lámpara, grasa y gente, se entra")
	assert_eq(sim.store.amount(Materia.Kind.GRASA),
		5.0 - Exploracion.GRASA_POR_JORNADA, "se quema la grasa de la jornada")
	assert_true(sim.exploracion.hay_alguien_dentro(1), "y alguien se mete dentro")
	assert_false(sim.exploracion.explorada(1), "no se sabe nada hasta que salga")

	sim.exploracion.nueva_jornada()
	assert_true(sim.exploracion.explorada(1), "al acabar el día, explorada")
	assert_false(sim.exploracion.hay_alguien_dentro(1), "y ya no hay nadie dentro")
	assert_eq(sim.people[0].oficio_de_hoy, int(Profession.Job.HOGAR),
		"la jornada cuenta como hogar: es trabajo del hogar, a oscuras")


func test_una_cueva_explorada_no_se_vuelve_a_explorar() -> void:
	var sim := _sim()
	sim.exploracion.mandar(1)
	sim.exploracion.nueva_jornada()
	assert_eq(sim.exploracion.lo_que_falta(1), "ya está explorada",
		"lo que se sabe, sabido está")


func test_la_cueva_de_la_banda_siempre_es_pintable() -> void:
	var sim := _sim()
	sim.exploracion.cueva_de_la_banda = 4
	sim.exploracion.mandar(4)
	sim.exploracion.nueva_jornada()
	assert_true(sim.exploracion.pintable(4), "la de casa se pinta siempre")


func test_alrededor_de_una_de_cada_tres_es_pintable() -> void:
	# Decisión del usuario: «no todas las cuevas se pueden pintar». Con cien
	# cuevas el conteo tiene que rondar el tercio, no clavarlo.
	var pintables := 0
	for cueva in range(100):
		if Exploracion.hay_zona_pintable(11, cueva):
			pintables += 1
	assert_gt(float(pintables), 15.0, "no son cuatro contadas")
	assert_lt(float(pintables), 50.0, "ni casi todas")


func test_la_misma_cueva_sale_igual_en_la_misma_partida() -> void:
	for cueva in range(20):
		assert_eq(Exploracion.hay_zona_pintable(3, cueva),
			Exploracion.hay_zona_pintable(3, cueva),
			"preguntar dos veces no cambia la cueva")


# --- E3: las decisiones de dentro, y lo que pasa ---------------------------

## Los momentos que la visita va citando, para contestarlos desde la prueba. En
## un array y no en una variable suelta: una lambda de GDScript copia las
## variables locales, no las comparte.
func _escuchar(sim: SettlementSim) -> Array:
	var citados: Array = []
	sim.moment_raised.connect(func(m: Moment) -> void: citados.append(m))
	return citados


func test_entrar_pregunta_la_primera_situacion_de_la_visita() -> void:
	var sim := _sim()
	var citados := _escuchar(sim)
	sim.exploracion.mandar(1)
	assert_eq(citados.size(), 1, "al entrar se pregunta ya")
	var momento: Moment = citados[0]
	assert_eq(int(momento.kind), int(Moment.Kind.CUEVA), "es un momento de cueva")
	assert_eq(momento.text, String((Repertorio.SITUACIONES[
		Repertorio.visita_de(sim.game_seed, 1)[0]] as Dictionary)["texto"]),
		"y cuenta la primera situación de la visita")
	assert_gt(float(momento.options.size()), 1.0, "con algo que elegir")


func test_elegir_sigue_la_rama_de_la_opcion() -> void:
	var sim := _sim()
	var citados := _escuchar(sim)
	sim.people[0].id = 3
	sim.exploracion._dentro[9] = 3
	sim.exploracion._pendiente[9] = []
	# Tirar piedras a lo oscuro: el oso viene hacia la boca.
	sim.exploracion.decidir(9, "ruido_en_lo_oscuro", 1)
	assert_eq(citados.size(), 1, "la rama pregunta lo siguiente")
	assert_eq((citados[0] as Moment).text, String((Repertorio.SITUACIONES[
		"el_oso_hacia_la_boca"] as Dictionary)["texto"]), "que es el oso en la boca")


func test_una_herida_de_cueva_deja_dias_de_herida() -> void:
	var sim := _sim()
	sim.exploracion._dentro[9] = 3
	# «Buscar la salida a tientas» hiere.
	sim.exploracion.decidir(9, "la_lampara_apagada", 1)
	assert_gt(float(sim.people[0].hurt_days), 0.0, "sale con días de herida")


func test_el_peligro_mata_alguna_vez_y_no_siempre() -> void:
	# «Plantarle la lanza» al oso: PELIGRO. Sobre muchas cuevas, alguna vez muere
	# y alguna vez no. El azar es de la semilla y la cueva, así que variar la
	# cueva es variar la tirada.
	var muertos := 0
	var vivos := 0
	for cueva in range(40):
		var sim := _sim()
		sim.exploracion._dentro[cueva] = 3
		sim.exploracion.decidir(cueva, "el_oso_de_frente", 0)
		if sim.people.is_empty():
			muertos += 1
		else:
			vivos += 1
	assert_gt(float(muertos), 0.0, "hay riesgo de verdad: alguien muere")
	assert_gt(float(vivos), float(muertos), "pero no es un suicidio")


func test_un_muerto_acaba_la_visita() -> void:
	var sim := _sim()
	var citados := _escuchar(sim)
	# Busca una cueva donde plantarle cara al oso mate, y comprueba que no se
	# pregunta nada más después.
	for cueva in range(60):
		sim = _sim()
		citados = _escuchar(sim)
		sim.exploracion._dentro[cueva] = 3
		sim.exploracion._pendiente[cueva] = ["murcielagos"]
		sim.exploracion.decidir(cueva, "el_oso_de_frente", 0)
		if sim.people.is_empty():
			# Sólo los de cueva: al morir el único de la banda salta además el
			# momento de la derrota, que no es de la visita.
			var de_cueva := citados.filter(func(m: Moment) -> bool:
				return m.kind == Moment.Kind.CUEVA)
			assert_eq(de_cueva.size(), 0, "con el explorador muerto no sigue nada")
			assert_false(sim.exploracion.hay_alguien_dentro(cueva),
				"y ya no hay nadie dentro")
			return
	assert_true(false, "en sesenta cuevas el oso no mató a nadie")


# --- P1: sólo se pinta lo explorado y pintable --------------------------------

## Una banda que sabría pintar: arte, hogar, lámpara, ocre y grasa. Sólo le falta
## lo de la cueva.
func _que_sabria_pintar() -> SettlementSim:
	var sim := _sim()
	sim.techs.known[TechTree.Tech.ARTE] = true
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.store.add(Materia.Kind.OCRE, 20.0)
	sim.store.add(Materia.Kind.GRASA, 20.0)
	sim.exploracion.cueva_de_la_banda = 1
	return sim


func test_sin_explorar_no_se_pinta() -> void:
	var sim := _que_sabria_pintar()
	assert_eq(sim.pinturas.painting_blocked_by(),
		"hay que explorar la cueva antes de pintarla", "y la tarjeta dice por qué")


func test_explorada_sin_pared_no_se_pinta() -> void:
	var sim := _que_sabria_pintar()
	# Otra cueva de casa sin pared: se escribe el estado, no se sortea.
	sim.exploracion._sabido[1] = {"explorada": true, "pintable": false}
	assert_eq(sim.pinturas.painting_blocked_by(),
		"esta cueva no tiene pared donde pintar", "explorada no basta")


func test_explorada_y_con_pared_se_pinta() -> void:
	var sim := _que_sabria_pintar()
	sim.exploracion._sabido[1] = {"explorada": true, "pintable": true}
	assert_eq(sim.pinturas.painting_blocked_by(), "", "ahora sí")


# --------------------- lo que cuenta quien entró (depurar, 2026-09-13) --
#
# Petición del usuario: «una vez que se explora la cueva, desaparece el botón,
# da una descripción detallada de la cueva y el testimonio de quien la exploró
# contando su experiencia».

## Recorre la visita entera eligiendo siempre una opción que no mate: lo que se
## prueba es el testimonio, no la suerte.
func _visita_entera(sim: SettlementSim, cueva: int) -> void:
	var citados := _escuchar(sim)
	sim.exploracion.mandar(cueva)
	var vueltas := 0
	while not citados.is_empty() and vueltas < 10:
		vueltas += 1
		var momento: Moment = citados.pop_back()
		var elegida := 0
		for id: String in Repertorio.SITUACIONES:
			var ficha: Dictionary = Repertorio.SITUACIONES[id]
			if String(ficha["texto"]) != momento.text:
				continue
			var opciones: Array = ficha["opciones"]
			for i in range(opciones.size()):
				if int((opciones[i] as Dictionary)["efecto"]) != int(Repertorio.Efecto.PELIGRO):
					elegida = i
					break
		((momento.options[elegida] as Dictionary)["on_pick"] as Callable).call()
	sim.exploracion.nueva_jornada()


func test_al_salir_queda_el_testimonio_de_quien_entro() -> void:
	var sim := _sim()
	sim.people[0].given_name = "Ilse"
	_visita_entera(sim, 1)
	assert_true(sim.exploracion.explorada(1), "la cueva queda explorada")
	var testimonio := sim.exploracion.testimonio(1)
	assert_true(testimonio.contains("Ilse"), "dice quién entró: %s" % testimonio)
	assert_gt(float(testimonio.length()), 120.0,
		"y cuenta algo más que una línea: %s" % testimonio)


func test_la_cueva_explorada_se_describe() -> void:
	var sim := _sim()
	_visita_entera(sim, 1)
	var descripcion := sim.exploracion.descripcion(1)
	assert_gt(float(descripcion.length()), 80.0, "una descripción de verdad: %s" % descripcion)
	assert_true(descripcion.contains("pintar"),
		"que dice si tiene pared para pintar: %s" % descripcion)


func test_explorada_ya_no_ofrece_explorar() -> void:
	var acciones := PanelSitios._actions_for(Site.Feature.ABRIGO, false, true)
	for accion: Array in acciones:
		assert_false(String(accion[0]) == "explorar", "el botón de explorar desaparece")
	var sin_explorar := PanelSitios._actions_for(Site.Feature.ABRIGO, false, false)
	var hay := false
	for accion: Array in sin_explorar:
		hay = hay or String(accion[0]) == "explorar"
	assert_true(hay, "y sin explorar, sigue")


func test_cada_opcion_tiene_su_frase_de_testimonio() -> void:
	# Las decisiones y lo que se cuenta de ellas van en dos tablas —ver
	# [Repertorio.TESTIMONIOS]—; ésta es la que impide que se desincronicen.
	for id: String in Repertorio.SITUACIONES:
		var opciones: Array = (Repertorio.SITUACIONES[id] as Dictionary)["opciones"]
		assert_true(Repertorio.TESTIMONIOS.has(id), "%s tiene testimonio" % id)
		assert_false(Repertorio.hay(id).is_empty(), "%s dice lo que hay" % id)
		var frases: Array = (Repertorio.TESTIMONIOS.get(id, {}) as Dictionary).get("dice", [])
		assert_eq(frases.size(), opciones.size(), "%s: una frase por opción" % id)
	assert_eq(Repertorio.TESTIMONIOS.size(), Repertorio.SITUACIONES.size(),
		"y no sobra ninguna")
