class_name TestProfession
extends TestCase
## Pruebas del reparto del trabajo en la banda.
##
## Sobre la división sexual del trabajo, que es lo que decide media de estas
## reglas: el modelo por defecto NO es un veto por sexo, es una restricción por
## ETAPA VITAL, y conviene dejar escrito por qué.
##
## La idea de que las mujeres no cazaban en el Paleolítico es el modelo "Man
## the Hunter" de 1966, y el registro no lo sostiene. Haas et al. 2020 publicó
## un enterramiento femenino de 9.000 años en Wilamaya Patjxa con equipo
## completo de caza mayor, y en su revisión de enterramientos americanos
## contemporáneos 11 de 27 cazadores eran mujeres. Ocobock y Lacy (2023)
## revisaron la evidencia fisiológica y arqueológica en contra. Y en la
## etnografía, Anderson et al. (2023) encontraron caza femenina en el 79% de
## las sociedades forrajeras documentadas.
##
## Lo que SÍ está bien documentado es que el embarazo avanzado y la lactancia
## limitan las jornadas largas y las partidas de varios días. Eso produce la
## misma asimetría en la práctica, pero por el motivo correcto, y además es
## DINÁMICO: la misma persona vuelve a la partida de caza cuando su cría se
## desteta.
##
## El veto duro por sexo existe en el modelo y funciona —`sex_restriction`—
## por si se quiere jugar con él. Simplemente no es lo que viene puesto.


func suite_name() -> String:
	return "Trabajos"


func _adulto(sex: Inhabitant.Sex) -> Inhabitant:
	var person := Inhabitant.new()
	person.age_group = Inhabitant.Age.ADULTO
	person.age_years = 26
	person.sex = sex
	return person


# --- quien puede trabajar --------------------------------------------------

func test_un_adulto_puede_con_los_trabajos_de_campo() -> void:
	var person := _adulto(Inhabitant.Sex.HOMBRE)
	for job: int in [Profession.Job.CAZA, Profession.Job.RIBERA,
			Profession.Job.RECOLECCION, Profession.Job.EXPLORACION]:
		assert_true(Profession.can_do(job as Profession.Job, person),
			"un adulto puede %s" % Profession.job_name(job as Profession.Job))


func test_un_nino_no_sale_de_partida() -> void:
	var person := _adulto(Inhabitant.Sex.MUJER)
	person.age_group = Inhabitant.Age.NINO
	person.age_years = 8
	assert_false(Profession.can_do(Profession.Job.CAZA, person),
		"un nino no va a la caceria")
	assert_false(Profession.can_do(Profession.Job.EXPLORACION, person),
		"ni de batida")


func test_pero_un_nino_ayuda_cerca_de_casa() -> void:
	# Recolectar y mariscar en la orilla es trabajo de crios en toda sociedad
	# forrajera documentada, y ademas es de donde sale buena parte de la dieta
	var person := _adulto(Inhabitant.Sex.MUJER)
	person.age_group = Inhabitant.Age.NINO
	person.age_years = 10
	assert_true(Profession.can_do(Profession.Job.RECOLECCION, person),
		"un crio recolecta")
	assert_true(Profession.can_do(Profession.Job.RIBERA, person),
		"y marisquea en la orilla")


func test_un_anciano_no_hace_la_jornada_larga_pero_talla() -> void:
	var person := _adulto(Inhabitant.Sex.HOMBRE)
	person.age_group = Inhabitant.Age.ANCIANO
	person.age_years = 62
	assert_false(Profession.can_do(Profession.Job.EXPLORACION, person),
		"a los sesenta no se hace la batida de tres dias")
	assert_true(Profession.can_do(Profession.Job.MANUFACTURA, person),
		"pero el que mejor talla es el que lleva cuarenta anos tallando")


# --- etapa vital, que es lo que de verdad restringe -----------------------

func test_criando_no_se_va_de_partida_larga() -> void:
	var madre := _adulto(Inhabitant.Sex.MUJER)
	madre.nursing = true
	assert_false(Profession.can_do(Profession.Job.CAZA, madre),
		"con una cria de pecho no se va a la caza mayor")
	assert_false(Profession.can_do(Profession.Job.EXPLORACION, madre),
		"ni de exploracion")


func test_criando_si_se_trabaja_cerca() -> void:
	var madre := _adulto(Inhabitant.Sex.MUJER)
	madre.nursing = true
	assert_true(Profession.can_do(Profession.Job.RECOLECCION, madre),
		"la recoleccion se hace con la cria encima")
	assert_true(Profession.can_do(Profession.Job.MANUFACTURA, madre),
		"y tallar se talla sentada en el abrigo")


func test_al_destetar_se_vuelve_a_la_partida() -> void:
	# La restriccion es dinamica, no una etiqueta permanente: es su diferencia
	# de fondo con un veto por sexo
	var madre := _adulto(Inhabitant.Sex.MUJER)
	madre.nursing = true
	assert_false(Profession.can_do(Profession.Job.CAZA, madre), "criando, no")
	madre.nursing = false
	assert_true(Profession.can_do(Profession.Job.CAZA, madre),
		"destetada la cria, vuelve a la caceria")


func test_un_hombre_criando_tampoco_esta_disponible() -> void:
	# Si alguien carga con el crio, carga igual sea quien sea. Que la regla
	# sea por etapa y no por sexo se nota justo aqui.
	var padre := _adulto(Inhabitant.Sex.HOMBRE)
	padre.nursing = true
	assert_false(Profession.can_do(Profession.Job.CAZA, padre),
		"quien lleva la cria no va a la caceria, sea quien sea")


# --- el veto por sexo existe, pero no viene puesto ------------------------

func test_por_defecto_ningun_trabajo_veta_por_sexo() -> void:
	for job: int in Profession.CATALOGUE.keys():
		assert_eq(Profession.CATALOGUE[job]["sex"], Profession.Sex.AMBOS,
			"%s no veta por sexo de serie" % Profession.job_name(job as Profession.Job))


func test_pero_el_veto_funciona_si_se_pone() -> void:
	var mujer := _adulto(Inhabitant.Sex.MUJER)
	var hombre := _adulto(Inhabitant.Sex.HOMBRE)
	assert_false(Profession.allows_sex(Profession.Sex.SOLO_HOMBRES, mujer),
		"un veto a hombres deja fuera a las mujeres")
	assert_true(Profession.allows_sex(Profession.Sex.SOLO_HOMBRES, hombre),
		"y deja dentro a los hombres")
	assert_true(Profession.allows_sex(Profession.Sex.AMBOS, mujer),
		"sin veto entra cualquiera")


# --- reparto ---------------------------------------------------------------

func _banda() -> Array[Inhabitant]:
	var gente: Array[Inhabitant] = []
	for i in range(12):
		var p := _adulto(Inhabitant.Sex.MUJER if i % 2 == 0 else Inhabitant.Sex.HOMBRE)
		gente.append(p)
	# Dos crios, un anciano y una madre criando
	gente[0].age_group = Inhabitant.Age.NINO
	gente[0].age_years = 9
	gente[1].age_group = Inhabitant.Age.NINO
	gente[1].age_years = 11
	gente[2].age_group = Inhabitant.Age.ANCIANO
	gente[2].age_years = 64
	gente[4].nursing = true
	return gente


func test_se_cuenta_quien_puede_hacer_cada_trabajo() -> void:
	var gente := _banda()
	assert_gt(float(Profession.eligible(Profession.Job.CAZA, gente).size()), 0.0,
		"hay gente para cazar")
	assert_lt(float(Profession.eligible(Profession.Job.CAZA, gente).size()),
		float(gente.size()),
		"pero no toda la banda: los crios, el anciano y quien cria quedan fuera")


func test_los_crios_cuentan_para_recolectar_y_no_para_cazar() -> void:
	var gente := _banda()
	assert_gt(float(Profession.eligible(Profession.Job.RECOLECCION, gente).size()),
		float(Profession.eligible(Profession.Job.CAZA, gente).size()),
		"a recolectar va mas gente que a la caceria")


func test_no_se_puede_asignar_a_quien_no_puede() -> void:
	var madre := _adulto(Inhabitant.Sex.MUJER)
	madre.nursing = true
	assert_false(Profession.assign(Profession.Job.CAZA, madre),
		"asignar a quien no puede se rechaza")
	assert_false(madre.has_task, "y no queda con la tarea puesta")


func test_asignar_a_quien_puede_le_pone_su_actividad() -> void:
	var person := _adulto(Inhabitant.Sex.HOMBRE)
	assert_true(Profession.assign(Profession.Job.RIBERA, person), "se acepta")
	assert_true(person.has_task, "queda con tarea")
	# La ribera arranca en lo mas suave -la rasa- y sube a la pesca cuando se
	# fija esa especialidad. El oficio dice DONDE se trabaja; la especialidad,
	# a que se va.
	assert_eq(person.activity, Subsistence.Activity.MARISQUEO,
		"la ribera arranca en la orilla")
	assert_eq(Profession.activity_of(Profession.Job.RIBERA,
		Profession.Speciality.ORILLA), Subsistence.Activity.PESCA,
		"y con el arpon se pesca")


func test_el_hogar_no_es_una_actividad_de_subsistencia() -> void:
	# Cuidar el fuego y a los crios es trabajo, pero no produce comida: si
	# contara como actividad, la banda se alimentaria de vigilar la hoguera
	var person := _adulto(Inhabitant.Sex.MUJER)
	assert_true(Profession.assign(Profession.Job.HOGAR, person), "se puede asignar")
	assert_false(person.has_task,
		"pero no sale al campo: no tiene tajo que producir")


# --- especialidades dentro de un oficio ------------------------------------

func test_hay_oficios_con_especialidad_y_oficios_sin_ella() -> void:
	assert_true(Profession.has_specialities(Profession.Job.MANUFACTURA),
		"la manufactura se reparte en talla, asta, peleteria y cordeleria")
	assert_true(Profession.has_specialities(Profession.Job.EXPLORACION),
		"salir a batir no es lo mismo que una expedicion de tres dias")
	# La recoleccion tambien se reparte: coger avellanas, traer lena y picar
	# piedra son el mismo oficio y tres jornadas muy distintas
	assert_true(Profession.has_specialities(Profession.Job.RECOLECCION),
		"fruto, lena y cantera no son lo mismo")
	assert_true(Profession.has_specialities(Profession.Job.CAZA),
		"una trampa no es una montería")
	assert_true(Profession.has_specialities(Profession.Job.RIBERA),
		"la rasa, el rio y el mar de fuera son tres cosas")
	assert_false(Profession.has_specialities(Profession.Job.HOGAR),
		"el hogar es uno y no se reparte")


func test_la_manufactura_no_es_solo_talla() -> void:
	# Era el problema de partida: un unico oficio hacia el trabajo de cuatro
	var options := Profession.specialities_of(Profession.Job.MANUFACTURA)
	assert_eq(options.size(), 4, "cuatro talleres distintos")
	for speciality: int in [Profession.Speciality.TALLA, Profession.Speciality.ASTA,
			Profession.Speciality.PELETERIA, Profession.Speciality.CORDELERIA]:
		assert_true(options.has(speciality),
			"%s es un taller propio" % Profession.speciality_name(
				speciality as Profession.Speciality))


func test_salir_del_valle_tiene_tres_formas_distintas() -> void:
	var options := Profession.specialities_of(Profession.Job.EXPLORACION)
	assert_eq(options.size(), 3, "batida, expedicion y ascension")


func test_sin_fijar_nada_se_hace_lo_que_haga_falta() -> void:
	var person := _adulto(Inhabitant.Sex.MUJER)
	assert_true(Profession.assign(Profession.Job.MANUFACTURA, person), "se asigna")
	assert_eq(person.speciality, Profession.Speciality.NINGUNA,
		"por defecto rota: en una banda pequena nadie vive de un solo oficio")


func test_fijar_una_especialidad_la_deja_fijada() -> void:
	var person := _adulto(Inhabitant.Sex.HOMBRE)
	Profession.assign(Profession.Job.MANUFACTURA, person, Profession.Speciality.ASTA)
	assert_eq(person.speciality, Profession.Speciality.ASTA,
		"quien se fija en el asta solo trabaja el asta")


func test_una_especialidad_de_otro_oficio_no_cuela() -> void:
	# Un tallador no puede estar de expedicion: son oficios distintos, y
	# aceptarlo dejaria a alguien con un estado incoherente
	var person := _adulto(Inhabitant.Sex.HOMBRE)
	Profession.assign(Profession.Job.MANUFACTURA, person, Profession.Speciality.EXPEDICION)
	# Lo que importa es lo que HACE hoy: una expedicion no se hace desde el
	# taller. Lo fijado se guarda -es una preferencia del jugador- y volvera a
	# valer en cuanto la persona vuelva a exploracion.
	assert_eq(person.current_speciality, Profession.Speciality.NINGUNA,
		"en el taller no se sale de expedicion: hoy rota")


func test_los_oficios_sin_especialidad_la_ignoran() -> void:
	var person := _adulto(Inhabitant.Sex.MUJER)
	Profession.assign(Profession.Job.RECOLECCION, person, Profession.Speciality.TALLA)
	assert_eq(person.current_speciality, Profession.Speciality.NINGUNA,
		"recolectando no se talla")


func test_toda_especialidad_se_puede_nombrar_y_explicar() -> void:
	# Si una no tiene texto, sale un boton en blanco en el panel de trabajos
	for speciality: int in Profession.SPECIALITY_INFO.keys():
		var s := speciality as Profession.Speciality
		assert_gt(float(Profession.speciality_name(s).length()), 2.0,
			"la especialidad %d tiene nombre" % speciality)
		assert_gt(float(Profession.speciality_desc(s).length()), 30.0,
			"y explica para que sirve")
