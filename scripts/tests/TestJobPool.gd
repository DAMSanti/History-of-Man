class_name TestJobPool
extends TestCase
## Pruebas del reparto de mano de obra.
##
## Aqui vivio un fallo que costo dos rondas de encontrar: el hogar hacia de
## trabajo Y de cajon de sastre a la vez, asi que se llenaba solo y restarle
## gente se la reasignaba a el mismo. El boton respondia y el numero no se
## movia.


func suite_name() -> String:
	return "Reparto"


func _banda(size: int = 12) -> Array[Inhabitant]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	var people: Array[Inhabitant] = []
	for i in range(size):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		# Todos adultos, para que ningun veto por edad enturbie la prueba
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		Profession.assign(Profession.Job.OCIOSO, person)
		people.append(person)
	return people


func _sim(people: Array[Inhabitant]) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.people = people
	return sim


func test_restar_de_un_oficio_deja_sin_oficio() -> void:
	# Lo que pidio el jugador con todas las letras: al quitar gente de un
	# trabajo tienen que quedar ociosos, no colocados en otro sitio
	var people := _banda()
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.CAZA, 4)
	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 4, "cuatro cazando")

	sim.set_job_count(Profession.Job.CAZA, 2)
	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 2, "quedan dos")
	# Nueve y no diez: el reparto garantiza siempre alguien en el hogar, y lo
	# coge de los ociosos. Sin nadie ahi no se mantiene el fuego.
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), SettlementSim.MIN_HEARTH,
		"el fuego queda atendido")
	assert_eq(sim.idle_count(), 9, "y el resto sin oficio")


func test_sumar_no_le_quita_gente_a_otro_oficio() -> void:
	# El fallo original: sumar un recolector te quitaba un cazador sin decirlo
	var people := _banda()
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.CAZA, 5)
	sim.set_job_count(Profession.Job.RECOLECCION, 7)

	var before: int = sim.job_counts().get(Profession.Job.CAZA, 0)
	sim.set_job_count(Profession.Job.RECOLECCION, 9)
	var after: int = sim.job_counts().get(Profession.Job.CAZA, 0)

	assert_eq(after, before, "la caza no ha perdido a nadie")
	assert_eq(sim.idle_count(), 0, "se han cogido los que quedaban libres")


func test_sin_ociosos_no_se_puede_sumar() -> void:
	var people := _banda(4)
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.CAZA, 4)
	assert_eq(sim.idle_count(), 0, "no queda nadie libre")
	# Con los cuatro cazando no habia nadie para el fuego, asi que el reparto
	# saca a uno: es el unico caso en que mueve gente por su cuenta, y lo
	# anota en la cronica
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), SettlementSim.MIN_HEARTH,
		"alguien atiende el fuego")
	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 3, "y quedan tres cazando")

	var got := sim.set_job_count(Profession.Job.RIBERA, 3)
	assert_eq(got, 0, "no se puede montar la pesca sin liberar a nadie antes")
	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 3, "la caza no pierde a nadie")


func test_el_hogar_se_puede_vaciar_hasta_uno() -> void:
	# El sintoma que reporto el jugador: no le dejaba bajar del hogar
	var people := _banda()
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.HOGAR, 4)
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), 4, "cuatro al hogar")

	sim.set_job_count(Profession.Job.HOGAR, 1)
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), 1, "baja a uno")
	assert_eq(sim.idle_count(), 11, "los otros tres quedan libres")


func test_el_hogar_nunca_baja_de_uno() -> void:
	var people := _banda()
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.HOGAR, 3)
	sim.set_job_count(Profession.Job.HOGAR, 0)
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), SettlementSim.MIN_HEARTH,
		"queda al menos uno para el fuego")


func test_se_puede_mover_gente_entre_oficios_en_dos_gestos() -> void:
	# El flujo completo que tiene que funcionar de punta a punta
	var people := _banda()
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.CAZA, 6)

	sim.set_job_count(Profession.Job.CAZA, 3)          # restar
	sim.set_job_count(Profession.Job.RIBERA, 3)         # sumar

	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 3, "tres cazando")
	assert_eq(sim.job_counts().get(Profession.Job.RIBERA, 0), 3, "tres pescando")


# --- por que no se puede sumar --------------------------------------------

func test_dice_por_que_los_ociosos_no_sirven() -> void:
	# El sintoma que reporto el jugador: «solo me deja 1 explorador y no me
	# dice por que». La exploracion pide adulto de 16 a 50 sin criatura de
	# pecho, y una banda de verdad tiene crios y ancianos.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var people: Array[Inhabitant] = []

	var adult := Inhabitant.create(0, Vector3.ZERO, rng)
	adult.age_years = 30
	adult.age_group = Inhabitant.Age.ADULTO
	adult.nursing = false
	people.append(adult)

	for i in range(3):
		var child := Inhabitant.create(i + 1, Vector3.ZERO, rng)
		child.age_years = 8
		child.age_group = Inhabitant.Age.NINO
		people.append(child)

	var sim := _sim(people)
	for person: Inhabitant in people:
		Profession.assign(Profession.Job.OCIOSO, person)

	# El unico adulto se va de explorador; quedan tres crios ociosos
	sim.set_job_count(Profession.Job.EXPLORACION, 1)
	assert_eq(sim.job_counts().get(Profession.Job.EXPLORACION, 0), 1,
		"solo entra el adulto")
	# Uno de los tres crios se queda en el hogar, que si pueden hacer
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), SettlementSim.MIN_HEARTH,
		"el fuego atendido")
	assert_eq(sim.idle_count(), 2, "y quedan dos sin oficio")

	# Sumar otro no puede, y el motivo tiene que estar disponible
	assert_eq(sim.spare_count(Profession.Job.EXPLORACION), 0,
		"ninguno de los ociosos sirve")
	var why := sim.idle_blockers(Profession.Job.EXPLORACION)
	assert_eq(int(why["crios"]), 2, "y el motivo es que son crios")


func test_sin_ociosos_el_motivo_esta_vacio() -> void:
	var people := _banda(3)
	var sim := _sim(people)
	sim.set_job_count(Profession.Job.CAZA, 3)

	var why := sim.idle_blockers(Profession.Job.RIBERA)
	var total := int(why["crios"]) + int(why["ancianos"]) \
		+ int(why["criando"]) + int(why["sexo"])
	assert_eq(total, 0, "no hay ociosos que explicar: el problema es otro")


# --- prioridades -----------------------------------------------------------

func test_cada_cual_hace_lo_que_tiene_mas_arriba() -> void:
	var people := _banda(3)
	var sim := _sim(people)
	# Las prioridades van por ESPECIALIDAD desde que los oficios de campo se
	# repartieron: la recoleccion ya no es un boton sino tres -fruto, lena y
	# cantera-, y la ribera otras tres. Un oficio a secas ya no es una tarea.
	for person: Inhabitant in people:
		person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
			Profession.Speciality.FORRAJEO), 2)
		person.set_priority(Profession.task_id(Profession.Job.RIBERA,
			Profession.Speciality.MARISQUEO), 1)
	sim.apply_priorities()

	# Dos pescan y al tercero se le saca para el fuego: el minimo del hogar
	# es un minimo de verdad, incluso si nadie lo tiene marcado
	assert_eq(sim.job_counts().get(Profession.Job.RIBERA, 0), 2,
		"van a lo que tienen de primera")
	assert_eq(sim.job_counts().get(Profession.Job.HOGAR, 0), SettlementSim.MIN_HEARTH,
		"y uno atiende el fuego aunque no lo tuviera marcado")


func test_si_no_puede_su_primera_opcion_baja_a_la_siguiente() -> void:
	# El caso que hace util tener varias: un crio no puede cazar, pero si
	# recolectar, y no tiene que quedarse parado por eso
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var child := Inhabitant.create(0, Vector3.ZERO, rng)
	child.age_years = 10
	child.age_group = Inhabitant.Age.NINO
	child.set_priority(Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR), 1)
	child.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
		Profession.Speciality.FORRAJEO), 2)

	var people: Array[Inhabitant] = [child]
	var sim := _sim(people)
	sim.apply_priorities()

	# Con uno solo, el hogar se lo lleva por el minimo; con dos se ve mejor
	var second := Inhabitant.create(1, Vector3.ZERO, rng)
	second.age_years = 30
	second.age_group = Inhabitant.Age.ADULTO
	second.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.people = [child, second]
	sim.apply_priorities()

	assert_eq(child.job, Profession.Job.RECOLECCION,
		"el crio recolecta, que es lo que puede")
	assert_eq(second.job, Profession.Job.HOGAR, "y el adulto al fuego")


func test_sin_ninguna_prioridad_se_queda_sin_oficio() -> void:
	var people := _banda(3)
	var sim := _sim(people)
	for person: Inhabitant in people:
		person.priorities.clear()
	sim.apply_priorities()

	# Uno va al hogar por el minimo; los otros dos, sin oficio
	assert_eq(sim.idle_count(), 2, "los que no quieren nada quedan libres")


func test_la_especialidad_fijada_sobrevive_a_un_cambio_de_oficio() -> void:
	# Pasa de verdad: el minimo del hogar saca al tallador, y antes eso le
	# borraba la talla. Al volver a manufactura habia que ponersela otra vez
	# sin que nada explicara por que se habia perdido.
	var people := _banda(2)
	var sim := _sim(people)
	var maker := people[0]

	Profession.assign(Profession.Job.MANUFACTURA, maker,
		Profession.Speciality.TALLA)
	assert_eq(maker.speciality, Profession.Speciality.TALLA, "queda fijada")
	assert_eq(maker.current_speciality, Profession.Speciality.TALLA, "y la ejerce")

	# Se le manda al hogar, donde no se talla
	Profession.assign(Profession.Job.HOGAR, maker)
	assert_eq(maker.speciality, Profession.Speciality.TALLA,
		"sigue siendo tallador aunque hoy atienda el fuego")
	assert_eq(maker.current_speciality, Profession.Speciality.NINGUNA,
		"pero hoy no talla")

	# Y al volver, recupera lo suyo sin que el jugador tenga que acordarse
	Profession.assign(Profession.Job.MANUFACTURA, maker)
	assert_eq(maker.current_speciality, Profession.Speciality.TALLA,
		"vuelve a tallar solo")


func test_subir_exploracion_al_mismo_nivel_que_otro_oficio_si_hace_algo() -> void:
	# El fallo real: alguien ya recolectando a nivel 1 (el reparto inicial
	# de la partida lo deja asi) y el jugador sube exploracion al mismo
	# nivel 1 desde Trabajos. Antes ganaba SIEMPRE quien apareciera primero
	# en el catalogo -recoleccion-, sin mirar para nada lo que el jugador
	# acababa de pedir: subir la prioridad de exploracion no hacia nada, en
	# silencio.
	#
	# Dos personas y no una: con una sola, el minimo del hogar se la lleva
	# a ella pase lo que pase, y la prueba dejaria de medir lo que quiere.
	var people := _banda(2)
	var sim := _sim(people)
	var person := people[0]
	people[1].set_priority(Profession.task_id(Profession.Job.HOGAR), 1)

	person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
		Profession.Speciality.FORRAJEO), 1)
	sim.apply_priorities()
	assert_eq(person.job, Profession.Job.RECOLECCION, "arranca recolectando")

	person.set_priority(Profession.task_id(Profession.Job.EXPLORACION,
		Profession.Speciality.BATIDA), 1)
	sim.apply_priorities()

	assert_eq(person.job, Profession.Job.EXPLORACION,
		"subir exploracion al mismo nivel que lo que ya hacia tiene que cambiarlo")
	assert_eq(person.current_speciality, Profession.Speciality.BATIDA,
		"y a la especialidad que se le puso")


func test_un_empate_entre_dos_oficios_sin_exploracion_no_cambia_cada_dia() -> void:
	# Sin exploracion de por medio, un empate entre oficios distintos se
	# queda con lo que ya se estaba haciendo -no se cambia de tajo cada
	# jornada por deportividad, aunque las presiones esten muy cerca.
	var people := _banda(2)
	var sim := _sim(people)
	var person := people[0]
	people[1].set_priority(Profession.task_id(Profession.Job.HOGAR), 1)

	person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
		Profession.Speciality.FORRAJEO), 1)
	person.set_priority(Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.TRAMPAS), 1)
	sim.apply_priorities()
	var first_job := person.job

	# Se repite varias veces: si hubiera reparto por sorteo o por orden del
	# catalogo, cambiaria en algun momento
	for _i in range(10):
		sim.apply_priorities()
		assert_eq(person.job, first_job, "el empate no oscila dia a dia")


# --- no esquilmar un paraje mandando a todo el mundo al mismo sitio -------

func test_un_paraje_lleno_se_descarta_para_el_siguiente() -> void:
	# Peticion explicita: ir al paraje mas cercano SIN mandar gente de sobra
	# como para esquilmarlo. El descuento por gente ya trabajando ahi era
	# solo eso -un descuento-, y un descuento nunca deja de ser el mejor
	# numero de la lista si es el unico sitio bueno que se conoce: hacia
	# falta un tope de verdad, no solo una penalizacion.
	var people := _banda(Subsistence.PEOPLE_PER_PARTY as int + 1)
	var sim := _sim(people)
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(700.0, 200.0, 700.0)

	var lleno := Vector3(720.0, 0.0, 700.0)
	sim._known_spots[Subsistence.Activity.RECOLECCION] = [
		{"pos": lleno, "score": 10.0},
	]

	# Una partida entera ya de camino a ese unico sitio
	for i in range(Subsistence.PEOPLE_PER_PARTY as int):
		people[i].activity = Subsistence.Activity.RECOLECCION
		people[i].state = Inhabitant.State.YENDO
		people[i].target = lleno

	var persona_de_mas := people[Subsistence.PEOPLE_PER_PARTY as int]
	persona_de_mas.activity = Subsistence.Activity.RECOLECCION

	var destino := sim._best_known_spot(persona_de_mas)
	assert_eq(destino, Vector3.ZERO,
		"con una partida entera ya alli, no se manda ni una persona mas")


func test_por_debajo_del_tope_si_se_manda() -> void:
	var people := _banda(3)
	var sim := _sim(people)
	sim._terrain = FakeTerrain.new()
	sim.home_position = Vector3(700.0, 200.0, 700.0)

	var sitio := Vector3(720.0, 0.0, 700.0)
	sim._known_spots[Subsistence.Activity.RECOLECCION] = [
		{"pos": sitio, "score": 10.0},
	]

	people[0].activity = Subsistence.Activity.RECOLECCION
	people[0].state = Inhabitant.State.YENDO
	people[0].target = sitio

	var otra_persona := people[1]
	otra_persona.activity = Subsistence.Activity.RECOLECCION

	var destino := sim._best_known_spot(otra_persona)
	# En plano: la Y viene del terreno de verdad -aqui siempre 200, la
	# altura llana de FakeTerrain-, y compararla con el 0 del punto de
	# prueba no dice nada del reparto, que es lo que mide esta prueba.
	var plano := Vector2(destino.x - sitio.x, destino.z - sitio.z).length()
	assert_true(plano < 100.0,
		"con solo una persona alli, todavia se puede mandar otra")


# --- un oficio sin sitio adonde ir no bloquea al siguiente ----------------

func test_si_no_hay_donde_recolectar_se_baja_a_la_segunda_opcion() -> void:
	# Peticion literal: «hay gente que sale a recolectar, sin tener nada que
	# recolectar, en lugar de hacer su trabajo siguiente en prioridad».
	var people := _banda(2)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	# Mundo montado pero SIN nada de recoleccion: ni sitio de reserva, ni
	# parajes, ni cotarros conocidos
	people[1].set_priority(Profession.task_id(Profession.Job.HOGAR), 1)

	# Con piedra en el abrigo el taller SI es una opcion: lo que se mide aqui
	# es que no se salga al monte a por nada, no que el taller sea gratis
	sim.store.add(Materia.Kind.PIEDRA, 20.0)

	var person := people[0]
	person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
		Profession.Speciality.FORRAJEO), 1)
	person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
		Profession.Speciality.TALLA), 2)
	sim.apply_priorities()

	assert_eq(person.job, Profession.Job.MANUFACTURA,
		"sin monte que recolectar, baja al taller en vez de salir por salir")


func test_el_taller_sin_materia_prima_baja_a_la_siguiente_opcion() -> void:
	# Peticion literal: «los encargados de manufactura no salen a buscar los
	# materiales; si no los traen los recolectores, bad luck, ellos haran su
	# siguiente profesion con mas prioridad».
	var people := _banda(2)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	people[1].set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	# Abrigo vacio: ni una piedra que tallar
	assert_eq(sim.store.amount(Materia.Kind.PIEDRA), 0.0, "el abrigo empieza vacio")

	var person := people[0]
	person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
		Profession.Speciality.TALLA), 1)
	person.set_priority(Profession.task_id(Profession.Job.HOGAR), 2)
	sim.apply_priorities()

	assert_eq(person.job, Profession.Job.HOGAR,
		"sin materia prima el tallador no se queda mirando el banco")


func test_con_materia_prima_el_taller_manda() -> void:
	var people := _banda(2)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	people[1].set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.store.add(Materia.Kind.PIEDRA, 20.0)

	var person := people[0]
	person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
		Profession.Speciality.TALLA), 1)
	person.set_priority(Profession.task_id(Profession.Job.HOGAR), 2)
	sim.apply_priorities()

	assert_eq(person.job, Profession.Job.MANUFACTURA,
		"con piedra guardada el tallador si talla")


func test_con_sitio_de_reserva_si_se_recolecta() -> void:
	var people := _banda(2)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	sim.set_work_site(Subsistence.Activity.RECOLECCION, Vector3(100.0, 0.0, 100.0))
	people[1].set_priority(Profession.task_id(Profession.Job.HOGAR), 1)

	var person := people[0]
	person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
		Profession.Speciality.FORRAJEO), 1)
	person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
		Profession.Speciality.TALLA), 2)
	sim.apply_priorities()

	assert_eq(person.job, Profession.Job.RECOLECCION,
		"con un sitio adonde ir, se respeta la primera opcion")


# --- lo empatado se reparte, no se va todo al primero de la lista ---------

func test_tres_especialidades_empatadas_reparten_la_banda() -> void:
	# Petición del jugador, por la vía de Gala: puso el taller en prioridad 1
	# y la banda seguía sin tallar. La cadena era ésta — nadie traía piedra ni
	# fibra, así que el taller nunca tenía con qué; y nadie las traía porque
	# forrajeo, leña y cantera puestas las tres a nivel 1 empataban en
	# presión, el desempate se lo llevaba siempre el forrajeo por ser el
	# primero de la lista, y el hábito lo dejaba fijado para siempre.
	var people := _banda(9)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	for activity: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		sim.set_work_site(activity as Subsistence.Activity, Vector3(100.0, 0.0, 100.0))

	for person: Inhabitant in people:
		for speciality: int in [Profession.Speciality.FORRAJEO,
				Profession.Speciality.LENA_FIBRA, Profession.Speciality.CANTERA]:
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				speciality as Profession.Speciality), 1)
	sim.apply_priorities()

	var reparto := {}
	for person: Inhabitant in people:
		var key := int(person.current_speciality)
		reparto[key] = int(reparto.get(key, 0)) + 1

	assert_true(reparto.size() >= 3,
		"con tres cosas al mismo nivel salen las tres, no sale %s" % [reparto])
	for speciality: int in [Profession.Speciality.FORRAJEO,
			Profession.Speciality.LENA_FIBRA, Profession.Speciality.CANTERA]:
		assert_true(int(reparto.get(speciality, 0)) > 0,
			"alguien va a %s" % Profession.speciality_name(
				speciality as Profession.Speciality))


func test_lo_que_sobra_deja_de_reclutar() -> void:
	# El reparto no es a partes iguales: es por lo que FALTA. Con el almacén
	# reventando de piedra, la cantera no se lleva a nadie.
	var people := _banda(6)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	for activity: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		sim.set_work_site(activity as Subsistence.Activity, Vector3(100.0, 0.0, 100.0))
	sim.store.add(Materia.Kind.PIEDRA, 900.0)

	for person: Inhabitant in people:
		for speciality: int in [Profession.Speciality.FORRAJEO,
				Profession.Speciality.CANTERA]:
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				speciality as Profession.Speciality), 1)
	sim.apply_priorities()

	var canteros := 0
	for person: Inhabitant in people:
		if person.current_speciality == Profession.Speciality.CANTERA:
			canteros += 1
	assert_eq(canteros, 0, "con novecientas de piedra no hace falta mas cantera")


func test_el_forrajeo_mide_la_comida_y_no_devuelve_uno_fijo() -> void:
	# Antes las tres de recolección devolvían 1.0 —"satisfecha"— pasara lo
	# que pasara, y por eso empataban siempre entre sí.
	var people := _banda(4)
	var sim := _sim(people)
	var vacio := sim._speciality_pressure(Profession.Speciality.FORRAJEO)
	sim.store.add(Materia.Kind.FRUTO_SECO, 400.0)
	var lleno := sim._speciality_pressure(Profession.Speciality.FORRAJEO)
	assert_true(lleno > vacio,
		"con la despensa llena aprieta menos: %.2f frente a %.2f" % [lleno, vacio])


func test_la_cantera_mide_la_piedra() -> void:
	var people := _banda(4)
	var sim := _sim(people)
	var vacio := sim._speciality_pressure(Profession.Speciality.CANTERA)
	sim.store.add(Materia.Kind.PIEDRA, 400.0)
	var lleno := sim._speciality_pressure(Profession.Speciality.CANTERA)
	assert_true(lleno > vacio,
		"con piedra de sobra aprieta menos: %.2f frente a %.2f" % [lleno, vacio])


func test_la_lena_y_fibra_mira_la_peor_de_las_dos() -> void:
	# Trae dos cosas: si sobra la leña pero falta la fibra, sigue haciendo
	# falta. La media diría que no.
	var people := _banda(4)
	var sim := _sim(people)
	sim.store.add(Materia.Kind.LENA, 400.0)
	var solo_lena := sim._speciality_pressure(Profession.Speciality.LENA_FIBRA)
	sim.store.add(Materia.Kind.FIBRA, 400.0)
	var las_dos := sim._speciality_pressure(Profession.Speciality.LENA_FIBRA)
	assert_true(las_dos > solo_lena,
		"con leña de sobra y sin fibra sigue apretando: %.2f frente a %.2f"
			% [solo_lena, las_dos])


func test_el_habito_no_congela_el_reparto() -> void:
	# Seguir en lo de ayer da ventaja, pero poca: si lo de ayer ya sobra y
	# otra cosa falta, se cambia. Con la ley de antes -"si sigue empatado, se
	# queda"- el reparto del primer día no se movía nunca más.
	var people := _banda(6)
	var sim := _sim(people)
	sim.field = ResourceField.new()
	sim.field.setup(8, 8, Vector2(512.0, 512.0))
	for activity: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		sim.set_work_site(activity as Subsistence.Activity, Vector3(100.0, 0.0, 100.0))

	for person: Inhabitant in people:
		for speciality: int in [Profession.Speciality.FORRAJEO,
				Profession.Speciality.CANTERA]:
			person.set_priority(Profession.task_id(Profession.Job.RECOLECCION,
				speciality as Profession.Speciality), 1)
		person.job = Profession.Job.RECOLECCION
		person.current_speciality = Profession.Speciality.CANTERA

	# Piedra hasta arriba y despensa a cero: aunque todos vengan de la
	# cantera, hoy toca comer
	sim.store.add(Materia.Kind.PIEDRA, 900.0)
	sim.apply_priorities()

	# Uno se queda en el hogar -`_ensure_hearth` no deja el fuego sin nadie-,
	# pero de la cantera no queda ni uno y al forrajeo va todo lo demas.
	var canteros := 0
	var forrajeadores := 0
	for person: Inhabitant in people:
		if person.current_speciality == Profession.Speciality.CANTERA:
			canteros += 1
		elif person.current_speciality == Profession.Speciality.FORRAJEO:
			forrajeadores += 1
	assert_eq(canteros, 0, "con piedra de sobra y sin comida se deja la cantera")
	assert_true(forrajeadores >= 4,
		"y se pasan al forrajeo, no se quedan de brazos cruzados: %d"
			% forrajeadores)


# --- se come TODO lo que alimenta ----------------------------------------

func test_se_come_la_raiz_y_no_solo_la_carne() -> void:
	# La lista de lo comestible estaba escrita a mano y tenía seis cosas
	# —pescado, marisco, carne, grasa, carne seca y fruto seco— mientras la
	# despensa contaba las doce que alimentan. Medido en el sitio 56: día 23,
	# cuarenta y siete raciones en el abrigo, los quince con el hambre a 100 y
	# la cifra clavada quince días seguidos. En primavera lo que se recoge es
	# raíz, y la banda se moría de hambre al lado de ella.
	var sim := _sim(_banda(2))
	sim.store.add(Materia.Kind.RAIZ, 40.0)
	var comido := sim._eat_from_store(5.0)
	assert_true(comido > 4.9,
		"con cuarenta de raíz se comen cinco raciones, no %.2f" % comido)
	assert_true(sim.store.amount(Materia.Kind.RAIZ) < 40.0,
		"y salen de la raíz")


func test_se_come_todo_lo_que_alimenta() -> void:
	for kind: int in Materia.Kind.values():
		if not Materia.is_food(kind as Materia.Kind):
			continue
		var sim := _sim(_banda(2))
		sim.store.add(kind as Materia.Kind, 60.0)
		var comido := sim._eat_from_store(3.0)
		assert_true(comido > 2.9,
			"%s alimenta, así que se puede comer (comido %.2f)"
				% [Materia.material_name(kind as Materia.Kind), comido])


func test_se_come_antes_lo_que_antes_se_pudre() -> void:
	# No es capricho: comerse primero lo que aguanta obliga a tirar lo fresco
	var sim := _sim(_banda(2))
	sim.store.add(Materia.Kind.CARNE, 20.0)
	sim.store.add(Materia.Kind.CARNE_SECA, 20.0)
	assert_true(Materia.shelf_life(Materia.Kind.CARNE)
		< Materia.shelf_life(Materia.Kind.CARNE_SECA),
		"la carne fresca aguanta menos que la curada")

	sim._eat_from_store(4.0)
	assert_true(sim.store.amount(Materia.Kind.CARNE) < 20.0,
		"se tira de la fresca")
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 20.0,
		"y la curada se guarda")


# --- el tope de comida no da tumbos --------------------------------------

func test_el_tope_no_se_suelta_a_la_primera_racion() -> void:
	# Petición literal: «llegan al tope de comida y no cogen más, llega la
	# noche, comen, baja del máximo y entonces vuelven a salir a por comida;
	# es un círculo vicioso». Medido antes: día 9 LLENO con 0 fuera, día 10
	# no lleno con 7 fuera, día 11 LLENO otra vez.
	var sim := _sim(_banda(4))
	sim.food_cap = 100.0
	# Justo por encima del tope, que es donde se para de recolectar
	sim.store.add(Materia.Kind.CARNE_SECA,
		102.0 / Materia.nutrition(Materia.Kind.CARNE_SECA))
	assert_true(sim.store.food_rations() >= 100.0, "la despensa esta llena")
	assert_true(sim.food_is_capped(), "y se nota")

	# Se cena: baja del tope, pero de poco. No se vuelve al monte por eso.
	sim._eat_from_store(12.0)
	assert_true(sim.store.food_rations() < 100.0, "ya no llega al tope")
	assert_true(sim.food_is_capped(),
		"pero con %.0f raciones no se sube al monte a por la de hoy"
			% sim.store.food_rations())


func test_al_ver_el_fondo_se_vuelve_a_por_comida() -> void:
	var sim := _sim(_banda(4))
	sim.food_cap = 100.0
	sim.store.add(Materia.Kind.CARNE_SECA,
		102.0 / Materia.nutrition(Materia.Kind.CARNE_SECA))
	assert_true(sim.food_is_capped(), "lleno de salida")

	# Comida hasta bajar por debajo de la banda
	while sim.store.food_rations() > 100.0 * SettlementSim.REANUDAR_COMIDA:
		sim._eat_from_store(5.0)
	assert_false(sim.food_is_capped(),
		"con la despensa al %.0f%% se vuelve a salir"
			% (SettlementSim.REANUDAR_COMIDA * 100.0))


func test_sin_tope_puesto_no_hay_memoria_que_valga() -> void:
	var sim := _sim(_banda(4))
	sim.store.add(Materia.Kind.CARNE_SECA, 500.0)
	assert_false(sim.food_is_capped(), "sin tope, nunca esta lleno")
