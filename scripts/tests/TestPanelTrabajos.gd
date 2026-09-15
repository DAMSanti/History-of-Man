class_name TestPanelTrabajos
extends TestCase
## Lo que la ventana «Trabajos» dice de quien no está.
##
## Frente 17 de EPOCA_01 §10.1, tanda 3. Quien salía de expedición desaparecía
## del mapa y la ventana no decía nada: el jugador no sabía quién se había ido
## ni cuándo volvía.
##
## Se comprueba la LISTA, no los píxeles: `PanelTrabajos.ausentes` la calcula y
## la ventana sólo la pinta —la vista no decide nada, SPECS §4.7—.


func suite_name() -> String:
	return "PanelTrabajos"


func _sim(cuantos: int = 6) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 400.0)
	sim.store.add(Materia.Kind.PIEL_CURTIDA, 10.0)
	sim.store.add(Materia.Kind.LENA, 200.0)
	sim.day = 20
	for i in range(cuantos):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "P%d" % i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	return sim


func test_sin_nadie_fuera_la_lista_esta_vacia() -> void:
	var sim := _sim()
	assert_eq(PanelTrabajos.ausentes(sim).size(), 0,
		"con toda la banda en casa no falta nadie")


func test_los_de_la_expedicion_salen_con_el_dia_de_vuelta() -> void:
	var sim := _sim()
	assert_true(sim.expedicion.mandar(3, 90.0), "sale la expedición")
	var fuera := PanelTrabajos.ausentes(sim)
	assert_eq(fuera.size(), 3, "los tres que se fueron")
	for uno: Dictionary in fuera:
		assert_eq(int(uno["cuando"]), sim.expedicion.vuelve_el_dia,
			"con la jornada en que vuelven")
		assert_true(String(uno["donde"]).length() > 0, "y dónde están")


func test_el_herido_sale_con_el_dia_en_que_se_cura() -> void:
	var sim := _sim()
	sim.people[0].hurt_days = 4
	var fuera := PanelTrabajos.ausentes(sim)
	assert_eq(fuera.size(), 1, "el tocado")
	if fuera.size() == 1:
		assert_eq(int(fuera[0]["cuando"]), sim.day + 4,
			"y cuándo se cura: la jornada %d" % (sim.day + 4))
		assert_eq(String(fuera[0]["que"]), "se cura",
			"no «vuelve»: se cura, que no es lo mismo")


func test_quien_anda_hacia_el_borde_se_distingue_del_que_ya_esta_fuera() -> void:
	var sim := _sim()
	sim.expedicion.mandar(3, 90.0)
	var yendo: Dictionary = PanelTrabajos.ausentes(sim)[0]
	assert_true(String(yendo["donde"]).contains("camino"),
		"mientras anda, va de camino: %s" % str(yendo["donde"]))
	for person: Inhabitant in sim.people:
		person.expedicion_andando = false
	var ya: Dictionary = PanelTrabajos.ausentes(sim)[0]
	assert_true(String(ya["donde"]).contains("fuera"),
		"y al salir del valle, está fuera: %s" % str(ya["donde"]))


# ------------------------------- almacén y oficios (tanda 3, frente 17) --

func test_el_shift_sube_de_diez_en_diez() -> void:
	# Ya estaba, sin prueba y sin escribir en ninguna parte: la queja lo pedía
	# como si no existiera. Ahora se puede comprobar sin teclado.
	assert_near(PanelAlmacen.paso_del_objetivo(false), 1.0, 0.001,
		"el clic normal va de uno en uno")
	assert_near(PanelAlmacen.paso_del_objetivo(true), 10.0, 0.001,
		"y con Shift, de diez en diez")


func test_los_oficios_ensenan_las_jornadas_del_arbol() -> void:
	# LA MISMA CIFRA QUE EL ÁRBOL, no una copia: es lo que el frente pide.
	var sim := _sim()
	sim.techs = TechTree.new()
	sim.techs.add_practice(Profession.Job.CAZA, 37.0)
	var linea := PanelOficios.jornadas_de(sim, Profession.Job.CAZA)
	assert_true(linea.contains("37"),
		"la ventana dice las 37 jornadas del árbol: %s" % linea)
	# Sin despensa atada, el árbol da por pagado el material -ver
	# `TechTree.fraccion_pagada`-, así que con 37 jornadas el lazo ya se sabe y
	# la siguiente es el cepo. Lo que se comprueba es que DIGA cuál es y cuánto
	# pide, no cuál sea.
	assert_true(linea.contains("la siguiente,"),
		"y cuál es la siguiente técnica que pagan: %s" % linea)
	assert_true(linea.contains("pide"),
		"y cuántas jornadas pide: %s" % linea)


func test_un_oficio_sin_rama_lo_dice() -> void:
	var sim := _sim()
	sim.techs = TechTree.new()
	var linea := PanelOficios.jornadas_de(sim, Profession.Job.HOGAR)
	assert_true(linea.length() > 0, "algo dice")


# --- lo que el usuario vio el 2026-09-14 ------------------------------------------

func _textos(nodo: Node) -> Array[String]:
	var salida: Array[String] = []
	if nodo is Label:
		salida.append((nodo as Label).text)
	elif nodo is Button:
		salida.append((nodo as Button).text)
	for hijo: Node in nodo.get_children():
		salida.append_array(_textos(hijo))
	return salida


func test_la_ventana_de_trabajos_ensena_las_prioridades_de_caza() -> void:
	# «No veo dónde marcar las prioridades de caza»: las filas existían, pero
	# dentro de una función a la que no llamaba nadie.
	var sim := _sim()
	var ui := GameUI.new()
	ui.sim = sim
	ui.show_jobs()
	var textos := _textos(ui._windows["trabajos"])
	var presas := 0
	for species: String in Fauna.SPECIES:
		for texto: String in textos:
			if texto.begins_with(Fauna.species_name(species)):
				presas += 1
				break
	ui.free()
	sim.free()
	assert_eq(presas, Fauna.SPECIES.size(), "una fila por especie, con su nivel")


func test_limpiar_una_ventana_la_deja_vacia_en_el_momento() -> void:
	# «Al añadir un trabajador aparece un segundo una línea arriba de la ventana»:
	# al rehacerla, los hijos viejos seguían ahí hasta el final del fotograma y
	# `_heading` ponía un separador delante del primer rótulo. Lo quitaba el
	# repintado del segundo siguiente.
	var ui := GameUI.new()
	var body := VBoxContainer.new()
	body.add_child(Label.new())
	body.add_child(Label.new())
	ui._clear(body)
	var quedan := body.get_child_count()
	ui._heading(body, "")
	var separadores := 0
	for hijo: Node in body.get_children():
		if hijo is HSeparator:
			separadores += 1
	body.free()
	ui.free()
	assert_eq(quedan, 0, "limpia, no queda nadie")
	assert_eq(separadores, 0, "y el primer rótulo no lleva separador encima")


func test_cada_boton_de_la_barra_abre_su_ventana() -> void:
	# «La ventana del taller no muestra nada»: el botón existía y `_toggle` no
	# tenía su caso. Se prueban todos, que es lo que habría cazado ése.
	var sim := _sim()
	var ui := GameUI.new()
	ui.sim = sim
	var sin_ventana: Array[String] = []
	for entrada: Array in GameUI.BOTONES_DE_LA_BARRA:
		ui._toggle(String(entrada[0]))
		if not ui._windows.has(String(entrada[0])):
			sin_ventana.append(String(entrada[0]))
	ui.free()
	sim.free()
	assert_eq(sin_ventana.size(), 0, "botones que no abren nada: %s" % str(sin_ventana))
