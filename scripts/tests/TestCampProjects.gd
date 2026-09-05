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
