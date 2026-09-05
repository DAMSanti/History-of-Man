class_name TestCampProjects
extends TestCase
## Pruebas de las mejoras del abrigo.
##
## Lo que importa comprobar es la dependencia: el secadero pide el hogar
## porque ahumar sin fuego no se hace, y esa regla vive en los datos, no en
## quien los use.


func suite_name() -> String:
	return "Campamento"


func test_el_hogar_no_depende_de_nada() -> void:
	assert_eq(CampProjects.requires(CampProjects.Kind.HOGAR), -1,
		"es lo primero que se puede levantar")


func test_el_secadero_exige_el_hogar() -> void:
	assert_eq(CampProjects.requires(CampProjects.Kind.SECADERO),
		CampProjects.Kind.HOGAR, "ahumar sin fuego no se hace")


func test_cada_proyecto_tiene_receta_y_jornadas() -> void:
	for kind: int in CampProjects.all():
		var materials := CampProjects.materials(kind as CampProjects.Kind)
		assert_true(materials.size() > 0, "%s pide algún material" % kind)
		assert_true(CampProjects.labor_days(kind as CampProjects.Kind) > 0.0,
			"%s cuesta jornadas de trabajo" % kind)
		assert_true(CampProjects.project_name(kind as CampProjects.Kind).length() > 0,
			"tiene nombre")


# --- el secadero ahúma pescado, no solo carne ----------------------------

func test_el_secadero_ahuma_el_pescado() -> void:
	# Queja literal: «los pescadores pescan pero no está subiendo el pescado
	# al almacén». Y no subía: el pescado fresco aguanta TRES DÍAS —uno menos
	# que la carne— y el secadero solo curaba carne, así que la banda
	# descargaba cincuenta raciones al día y el montón se quedaba clavado
	# porque se pudría igual de rápido que entraba.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim._dry_meat(1.0, 1.0)

	assert_true(sim.store.amount(Materia.Kind.PESCADO_SECO) > 0.0,
		"el pescado se ahúma")
	assert_true(sim.store.amount(Materia.Kind.PESCADO) < 30.0,
		"y sale del montón de fresco")


func test_se_cura_antes_lo_que_antes_se_pudre() -> void:
	# Con las dos cosas en el abrigo y un secadero que no da para todo, se
	# salva primero el pescado, que aguanta tres días contra los cuatro de la
	# carne. Salvar la carne y dejar podrir el pescado sería al revés.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.PESCADO, 100.0)
	sim.store.add(Materia.Kind.CARNE, 100.0)
	sim._dry_meat(1.0, 1.0)

	assert_true(Materia.shelf_life(Materia.Kind.PESCADO)
		< Materia.shelf_life(Materia.Kind.CARNE),
		"el pescado aguanta menos que la carne")
	assert_true(sim.store.amount(Materia.Kind.PESCADO_SECO) > 0.0,
		"se ahúma el pescado primero")
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"y la carne espera su turno")


func test_el_pescado_seco_aguanta_el_invierno() -> void:
	# Es la razón entera de plantarse en el río cuando sube el remonte: no se
	# pesca para comer hoy, se pesca para comer en enero.
	assert_true(Materia.shelf_life(Materia.Kind.PESCADO_SECO) > 150,
		"ahumado, media vuelta al año")
	assert_true(Materia.is_food(Materia.Kind.PESCADO_SECO), "y alimenta")
	assert_eq(Materia.nutrition(Materia.Kind.PESCADO_SECO),
		Materia.nutrition(Materia.Kind.PESCADO),
		"lo mismo que fresco: curar no añade comida, la conserva")


func test_el_secadero_da_para_un_remonte() -> void:
	# Medido: tres personas en la orilla descargaban 53 raciones al día. Con
	# los cuatro de antes, ahumar era un gesto simbólico.
	assert_true(SettlementSim.DRY_PER_DAY >= 20.0,
		"un bastidor sobre el hogar cura una jornada de pesca de verdad")
