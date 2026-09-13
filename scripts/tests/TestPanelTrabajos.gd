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
	sim.store.add(Materia.Kind.PIEL, 10.0)
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
	assert_true(sim.expedicion.mandar(3, 1000), "sale la expedición")
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
	sim.expedicion.mandar(3, 1000)
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
