class_name TestRelevo
extends TestCase
## Pruebas de quién deja la partida y quién entra en ella: `_person_dies`
## primero, y luego lo que vaya colgando de "que se pueda perder".
##
## Nace de docs/specs/QUE_SE_PUEDA_PERDER.md, tarea 1: el punto único de
## salida tiene que quedar probado antes de que hambre, frío, vejez y
## percance grave lo empiecen a llamar.


func suite_name() -> String:
	return "Relevo"


func _banda(size: int = 6) -> Array[Inhabitant]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var people: Array[Inhabitant] = []
	for i in range(size):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		Profession.assign(Profession.Job.CAZA, person)
		people.append(person)
	return people


func _sim(people: Array[Inhabitant]) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	return sim


func test_person_dies_la_saca_de_la_partida() -> void:
	var people := _banda()
	var sim := _sim(people)
	var before := sim.population()

	sim._person_dies(people[2], "Prueba: se muere alguien.")

	assert_eq(sim.population(), before - 1, "un muerto menos en la banda")


func test_person_dies_la_saca_del_reparto() -> void:
	var people := _banda()
	var sim := _sim(people)
	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 6, "los seis cazan")

	sim._person_dies(people[0], "Prueba: se muere el cazador.")

	assert_eq(sim.job_counts().get(Profession.Job.CAZA, 0), 5,
		"job_counts ya no cuenta al muerto, sin tocar el reparto a mano")


func test_person_dies_deja_constancia_en_la_cronica() -> void:
	var people := _banda()
	var sim := _sim(people)

	sim._person_dies(people[1], "Prueba: murió de algo.")

	var gente := sim.chronicle.recent(10, Chronicle.Kind.GENTE)
	assert_eq(gente.size(), 1, "una anotación de GENTE")
	assert_true((gente[0]["text"] as String).find("murió de algo") >= 0,
		"con el texto que trajo quien llamó")


func test_cumplir_anyos_suma_un_anyo_por_persona() -> void:
	var people := _banda()
	var sim := _sim(people)

	sim.relevo.cumplir_anyos()
	sim.relevo.cumplir_anyos()
	sim.relevo.cumplir_anyos()

	for person: Inhabitant in people:
		assert_eq(person.age_years, 33, "treinta empieza, tres giros de año")


func test_nino_pasa_a_adulto_al_cruzar_el_umbral() -> void:
	var people := _banda(1)
	var crio := people[0]
	crio.age_group = Inhabitant.Age.NINO
	crio.age_years = Relevo.CHILD_TO_ADULT_AGE - 1
	var sim := _sim(people)

	sim.relevo.cumplir_anyos()

	assert_eq(crio.age_years, Relevo.CHILD_TO_ADULT_AGE, "cumple el umbral")
	assert_eq(crio.age_group, Inhabitant.Age.ADULTO, "y ya cuenta como adulto")


func test_nino_no_pasa_a_adulto_antes_de_tiempo() -> void:
	var people := _banda(1)
	var crio := people[0]
	crio.age_group = Inhabitant.Age.NINO
	crio.age_years = 5
	var sim := _sim(people)

	sim.relevo.cumplir_anyos()

	assert_eq(crio.age_group, Inhabitant.Age.NINO, "un año no basta para crecer")


func test_adulto_pasa_a_anciano_al_cruzar_el_umbral() -> void:
	var people := _banda(1)
	var persona := people[0]
	persona.age_group = Inhabitant.Age.ADULTO
	persona.age_years = Relevo.ADULT_TO_ELDER_AGE - 1
	var sim := _sim(people)

	sim.relevo.cumplir_anyos()

	assert_eq(persona.age_years, Relevo.ADULT_TO_ELDER_AGE, "cumple el umbral")
	assert_eq(persona.age_group, Inhabitant.Age.ANCIANO, "y ya es anciano")


func test_cumplir_anyos_no_toca_stats_ni_skill() -> void:
	# Decisión de arquitectura: envejecer NO resiembra pericia ni físico -eso
	# borraría de un plumazo lo que la persona ya se ha ganado jugando.
	var people := _banda(1)
	var persona := people[0]
	persona.age_group = Inhabitant.Age.ADULTO
	persona.age_years = Relevo.ADULT_TO_ELDER_AGE - 1
	persona.stats[Inhabitant.Stat.FUERZA] = 0.9
	persona.skill[Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR)] = 0.77
	var sim := _sim(people)

	sim.relevo.cumplir_anyos()

	assert_near(persona.stat_in(Inhabitant.Stat.FUERZA), 0.9, 0.001,
		"la fuerza ganada no se borra al hacerse anciano")
	assert_near(persona.skill_in(
			Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR)),
		0.77, 0.001, "ni la pericia ya aprendida")


## Una persona en casa, de vuelta, lista para pasar la noche en el abrigo.
func _en_casa(job: Profession.Job = Profession.Job.RECOLECCION) -> Dictionary:
	var sim := SettlementSim.new()
	sim.home_position = Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.position = Vector3.ZERO
	person.job = job
	person.state = Inhabitant.State.VOLVIENDO
	sim.people = [person]
	return {"sim": sim, "person": person}


func test_cold_sube_de_noche_en_invierno_sin_hogar() -> void:
	# El campo existe desde siempre y ya entra en `effectiveness()`, pero
	# nada de la simulacion real le daba valor -tarea 3 de la spec.
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = false
	person.cold = 0.0

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_gt(person.cold, 0.0,
		"pasa frío durmiendo en el abrigo sin hogar en invierno")
	GameState.season = antes


func test_cold_no_sube_con_el_hogar_encendido() -> void:
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = true
	person.cold = 0.0

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_eq(person.cold, 0.0, "con fuego, la cueva abriga y no sube el frío")
	GameState.season = antes


func test_cold_no_sube_fuera_de_invierno() -> void:
	var antes := GameState.season
	GameState.season = Subsistence.Season.VERANO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = false
	person.cold = 0.0

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_eq(person.cold, 0.0, "el resto del año la cueva sola ya abriga")
	GameState.season = antes


func test_cold_baja_al_volver_el_fuego() -> void:
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = true
	person.cold = 50.0

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_lt(person.cold, 50.0, "el fuego encendido hace entrar en calor")
	GameState.season = antes


func test_superar_el_aforo_castiga_aunque_haya_hogar_y_sea_verano() -> void:
	# Se aisla a proposito de la estacion y del hogar -verano, fuego
	# encendido, los dos ya neutralizan `HEARTH_COLD_RISE`- para que lo unico
	# que pueda mover `cold` sea la superpoblacion.
	var antes := GameState.season
	GameState.season = Subsistence.Season.VERANO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = true
	person.cold = 0.0
	for i in range(SettlementSim.PLAZAS_ABRIGO_BASE):
		sim.people.append(Inhabitant.new())
	assert_gt(sim.population(), sim.plazas_abrigo(), "la banda de prueba supera el aforo")

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_gt(person.cold, 0.0,
		"por encima del aforo se pasa frío aunque haya hogar y sea verano")
	GameState.season = antes


func test_por_debajo_del_aforo_no_hay_penalizacion_fantasma() -> void:
	# Criterio negativo: una banda pequeña en un abrigo grande no debe notar
	# nada de esto.
	var antes := GameState.season
	GameState.season = Subsistence.Season.VERANO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = true
	person.cold = 0.0
	assert_lt(sim.population(), sim.plazas_abrigo(), "la banda de prueba no llega al aforo")

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_eq(person.cold, 0.0, "por debajo del aforo, sin efecto")
	GameState.season = antes


# --- crecimiento organico y aforo, varios años --------------------------
#
# El criterio real de la spec: no población forzada a mano, sino la banda
# creciendo por `Relevo.evaluar_nacimiento` de verdad. Sin escena 3D ni
# jornada a jornada -eso es lo que costaría horas de reloj real para ver
# nacimientos reales-: se conduce el ciclo ANUAL directamente, forzando
# "año bueno" cada vez (reserva de sobra, sin racha de hambre) para que los
# partos salgan solos, sin fijar cuántos ni cuándo.

func _banda_creciente() -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var people := Inhabitant.create_band(15, Vector3.ZERO, rng)
	for persona: Inhabitant in people:
		persona.position = Vector3.ZERO
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	sim.home_position = Vector3.ZERO
	sim._rng.seed = 20260912
	return sim


func test_la_poblacion_crece_sola_y_supera_el_aforo_sin_paraviento() -> void:
	var sim := _banda_creciente()
	var anyos := 10
	for anyo in range(anyos):
		# Año bueno garantizado: la mecanica de nacimientos no es lo que se
		# prueba aqui, ya tiene su propia spec (QUE_SE_PUEDA_PERDER.md).
		sim.store.add(Materia.Kind.FRUTO_SECO, 100000.0)
		sim.hambre_severa_peor_racha_del_anyo = 0
		sim.relevo.cumplir_anyos()
		sim.relevo.revisar_vejez()
		sim.relevo.evaluar_nacimiento()

	assert_true(sim.population() > 15,
		"en diez años buenos, la banda crece de verdad más allá de la partida")
	assert_true(sim.population() > SettlementSim.PLAZAS_ABRIGO_BASE,
		"y con esa cifra, supera el aforo sin paraviento levantado")


func test_sin_paraviento_pesa_mas_de_frio_agregado_con_la_misma_poblacion() -> void:
	# Dos bandas gemelas -misma semilla en `create_band` Y en `sim._rng`, asi
	# que crecen exactamente igual, parto a parto- que sólo se diferencian en
	# si levantaron el paraviento a tiempo.
	var season_antes := GameState.season
	var year_antes := GameState.year

	var con_para := _banda_creciente()
	con_para.camp_built[CampProjects.Kind.PARAVIENTO] = true
	var sin_para := _banda_creciente()

	for sim: SettlementSim in [con_para, sin_para]:
		for anyo in range(10):
			sim.store.add(Materia.Kind.FRUTO_SECO, 100000.0)
			sim.hambre_severa_peor_racha_del_anyo = 0
			sim.relevo.cumplir_anyos()
			sim.relevo.revisar_vejez()
			sim.relevo.evaluar_nacimiento()

	assert_eq(con_para.population(), sin_para.population(),
		"las dos bandas crecen exactamente igual: sólo cambia el paraviento")
	assert_true(sin_para.population() > SettlementSim.PLAZAS_ABRIGO_BASE,
		"y esa población, sin paraviento, ya supera el aforo base")

	GameState.season = Subsistence.Season.INVIERNO
	for sim: SettlementSim in [con_para, sin_para]:
		for persona: Inhabitant in sim.people:
			persona.cold = 0.0
			persona.state = Inhabitant.State.VOLVIENDO
			sim._tick_routine(persona, 8.0, 8.0, true)

	var cold_con := 0.0
	for p: Inhabitant in con_para.people:
		cold_con += p.cold
	var cold_sin := 0.0
	for p: Inhabitant in sin_para.people:
		cold_sin += p.cold

	assert_true(cold_sin > cold_con,
		"con la misma banda, quien no levantó paraviento pasa más frío en total")

	GameState.season = season_antes
	GameState.year = year_antes


func test_cold_sube_menos_con_vestido_de_sobra() -> void:
	# El vestido se SUMA al hogar, no lo sustituye: con la misma noche sin
	# fuego, una banda con una prenda por persona pasa menos frio que una
	# banda identica sin ninguna.
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO

	var ctx_sin := _en_casa()
	var sim_sin: SettlementSim = ctx_sin["sim"]
	var person_sin: Inhabitant = ctx_sin["person"]
	sim_sin.hearth_lit = false
	person_sin.cold = 0.0
	sim_sin._tick_routine(person_sin, 8.0, 8.0, true)

	var ctx_con := _en_casa()
	var sim_con: SettlementSim = ctx_con["sim"]
	var person_con: Inhabitant = ctx_con["person"]
	sim_con.hearth_lit = false
	person_con.cold = 0.0
	sim_con.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)
	sim_con._tick_routine(person_con, 8.0, 8.0, true)

	assert_gt(person_sin.cold, 0.0, "sin vestido, sigue subiendo el frío")
	assert_true(person_con.cold < person_sin.cold,
		"con un vestido por persona sube menos que sin ninguno")
	GameState.season = antes


func test_vestido_no_hace_nada_fuera_de_invierno() -> void:
	# Criterio negativo: el vestido no puede inventar una penalizacion -o una
	# mejora- donde antes no la habia. Fuera de invierno la cueva sola ya
	# abriga, con o sin vestido.
	var antes := GameState.season
	GameState.season = Subsistence.Season.VERANO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = false
	person.cold = 0.0
	sim.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_eq(person.cold, 0.0, "en verano no sube el frío, tenga vestido o no")
	GameState.season = antes


func test_vestido_completo_frena_pero_no_hace_desaparecer_el_frio_sin_fuego() -> void:
	# El criterio central del bloque: las CUATRO combinaciones de hogar y
	# vestido son distintas, y sin fuego y sin vestido sigue siendo lo peor.
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO

	var ctx := _en_casa()
	var sim: SettlementSim = ctx["sim"]
	var person: Inhabitant = ctx["person"]
	sim.hearth_lit = false
	person.cold = 0.0
	for i in range(sim.population()):
		sim.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)

	sim._tick_routine(person, 8.0, 8.0, true)

	assert_gt(person.cold, 0.0,
		"con vestido completo pero sin fuego, todavia se pasa algo de frío")
	GameState.season = antes


func test_sin_vestido_la_banda_enferma_de_frio_antes() -> void:
	# Hasta la consecuencia que ya existia (Relevo.revisar_frio): a lo largo
	# de varias noches de invierno sin hogar, quien no tiene vestido acumula
	# mas dias de enfermedad de frío que quien si lo tiene.
	var antes := GameState.season
	GameState.season = Subsistence.Season.INVIERNO

	var ctx_sin := _en_casa()
	var sim_sin: SettlementSim = ctx_sin["sim"]
	var person_sin: Inhabitant = ctx_sin["person"]
	sim_sin.hearth_lit = false

	var ctx_con := _en_casa()
	var sim_con: SettlementSim = ctx_con["sim"]
	var person_con: Inhabitant = ctx_con["person"]
	sim_con.hearth_lit = false
	sim_con.toolkit.craft(Tool.Kind.VESTIDO, Tool.Stuff.PIEL)

	for day in range(10):
		sim_sin._tick_routine(person_sin, 8.0, 8.0, true)
		sim_sin.relevo.revisar_frio()
		sim_con._tick_routine(person_con, 8.0, 8.0, true)
		sim_con.relevo.revisar_frio()

	assert_true(person_sin.cold_sick_days >= person_con.cold_sick_days,
		"sin vestido se acumulan al menos tantos dias de enfermedad de frío")
	assert_gt(float(person_sin.cold_sick_days), 0.0,
		"y de hecho, sin vestido, enferma")
	GameState.season = antes


func test_revisar_frio_enferma_con_cold_sostenido() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.cold = 80.0

	sim.relevo.revisar_frio()

	assert_eq(persona.cold_sick_days, 1, "un día de frío sostenido cuenta")
	assert_true(persona.is_cold_sick(), "y ya está enferma")
	assert_eq(sim.chronicle.recent(10, Chronicle.Kind.PENURIA).size(), 1,
		"una anotación de PENURIA al enfermar")


func test_revisar_frio_no_repite_el_aviso_cada_dia() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.cold = 80.0

	sim.relevo.revisar_frio()
	sim.relevo.revisar_frio()
	sim.relevo.revisar_frio()

	assert_eq(persona.cold_sick_days, 3, "sigue sumando días")
	assert_eq(sim.chronicle.recent(10, Chronicle.Kind.PENURIA).size(), 1,
		"pero el aviso de que enferma sale una sola vez")


func test_revisar_frio_cura_si_baja_el_frio() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.cold_sick_days = 3
	persona.cold = 10.0

	sim.relevo.revisar_frio()

	assert_eq(persona.cold_sick_days, 2,
		"un día curando por cada jornada calentito")


func test_revisar_frio_mata_al_agotar_los_dias_que_aguanta() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.cold = 80.0

	for i in range(Relevo.COLD_DEATH_DAYS_ADULT):
		sim.relevo.revisar_frio()

	assert_eq(sim.population(), 0,
		"el adulto muere tras agotar los días que aguanta")
	var gente := sim.chronicle.recent(10, Chronicle.Kind.GENTE)
	assert_true(gente.size() >= 1 and (gente[0]["text"] as String).find("frío") >= 0,
		"y la crónica dice que fue de frío")


func test_ninos_y_ancianos_mueren_de_frio_antes_que_un_adulto() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var crio := Inhabitant.create(0, Vector3.ZERO, rng)
	crio.age_group = Inhabitant.Age.NINO
	crio.age_years = 8
	var adulto := Inhabitant.create(1, Vector3.ZERO, rng)
	adulto.age_group = Inhabitant.Age.ADULTO
	adulto.age_years = 30
	var sim := _sim([crio, adulto])
	crio.cold = 80.0
	adulto.cold = 80.0

	for i in range(Relevo.COLD_DEATH_DAYS_CHILD):
		sim.relevo.revisar_frio()

	assert_eq(sim.population(), 1, "el crío ya no está")
	assert_eq(sim.people[0], adulto, "el adulto aguanta más días con el mismo frío")


func test_revisar_hambre_enferma_con_hambre_sostenida() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.hunger = 90.0

	sim.relevo.revisar_hambre()

	assert_eq(persona.hunger_sick_days, 1, "un día de hambre sostenida cuenta")
	assert_true(persona.is_hunger_sick(), "y ya está enferma")
	assert_eq(sim.chronicle.recent(10, Chronicle.Kind.PENURIA).size(), 1,
		"una anotación de PENURIA al enfermar")


func test_revisar_hambre_no_repite_el_aviso_cada_dia() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.hunger = 90.0

	sim.relevo.revisar_hambre()
	sim.relevo.revisar_hambre()
	sim.relevo.revisar_hambre()

	assert_eq(persona.hunger_sick_days, 3, "sigue sumando días")
	assert_eq(sim.chronicle.recent(10, Chronicle.Kind.PENURIA).size(), 1,
		"pero el aviso de que enferma sale una sola vez")


func test_revisar_hambre_cura_si_baja_el_hambre() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.hunger_sick_days = 3
	persona.hunger = 10.0

	sim.relevo.revisar_hambre()

	assert_eq(persona.hunger_sick_days, 2,
		"un día curando por cada jornada bien comida")


func test_revisar_hambre_mata_al_agotar_los_dias_que_aguanta() -> void:
	var people := _banda(1)
	var persona := people[0]
	var sim := _sim(people)
	persona.hunger = 90.0

	for i in range(Relevo.HUNGER_DEATH_DAYS_ADULT):
		sim.relevo.revisar_hambre()

	assert_eq(sim.population(), 0,
		"el adulto muere tras agotar los días que aguanta")
	var gente := sim.chronicle.recent(10, Chronicle.Kind.GENTE)
	assert_true(gente.size() >= 1 and (gente[0]["text"] as String).find("hambre") >= 0,
		"y la crónica dice que fue de hambre")


## Criterio 1 de la spec: en una banda mixta bajo la misma privación, el
## primer enfermo y el primer muerto son un niño o un anciano, no un adulto.
func _banda_mixta() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var crio := Inhabitant.create(0, Vector3.ZERO, rng)
	crio.age_group = Inhabitant.Age.NINO
	crio.age_years = 8
	var anciano := Inhabitant.create(1, Vector3.ZERO, rng)
	anciano.age_group = Inhabitant.Age.ANCIANO
	anciano.age_years = 55
	var adulto := Inhabitant.create(2, Vector3.ZERO, rng)
	adulto.age_group = Inhabitant.Age.ADULTO
	adulto.age_years = 30
	var todos: Array[Inhabitant] = [crio, anciano, adulto]
	return {"crio": crio, "anciano": anciano, "adulto": adulto, "todos": todos}


func test_en_banda_mixta_enferman_antes_los_ninos_y_ancianos_de_hambre() -> void:
	var banda := _banda_mixta()
	var todos: Array[Inhabitant] = banda["todos"]
	var sim := _sim(todos)
	for person: Inhabitant in todos:
		person.hunger = 90.0

	# Justo los días que aguanta un crío o un anciano: ya deberían estar
	# muertos, y el adulto, con el MISMO hambre, todavía no.
	for i in range(Relevo.HUNGER_DEATH_DAYS_CHILD):
		sim.relevo.revisar_hambre()

	assert_eq(sim.population(), 1, "el crío y el anciano ya no están")
	assert_eq(sim.people[0], banda["adulto"],
		"el adulto aguanta más días con el mismo hambre")


func test_en_banda_mixta_enferman_antes_los_ninos_y_ancianos_de_frio() -> void:
	# Mismo criterio que arriba, para el vector de frío.
	var banda := _banda_mixta()
	var todos: Array[Inhabitant] = banda["todos"]
	var sim := _sim(todos)
	for person: Inhabitant in todos:
		person.cold = 80.0

	for i in range(Relevo.COLD_DEATH_DAYS_CHILD):
		sim.relevo.revisar_frio()

	assert_eq(sim.population(), 1, "el crío y el anciano ya no están")
	assert_eq(sim.people[0], banda["adulto"],
		"el adulto aguanta más días con el mismo frío")


func test_racha_de_hambre_sube_con_media_severa() -> void:
	var people := _banda(4)
	var sim := _sim(people)
	for person: Inhabitant in people:
		person.hunger = 80.0

	sim._revisar_hambre_de_la_banda()
	sim._revisar_hambre_de_la_banda()
	sim._revisar_hambre_de_la_banda()

	assert_eq(sim.hambre_severa_racha, 3, "tres jornadas seguidas por encima del umbral")


func test_racha_de_hambre_no_sube_por_debajo_del_umbral() -> void:
	var people := _banda(4)
	var sim := _sim(people)
	for person: Inhabitant in people:
		person.hunger = 20.0

	sim._revisar_hambre_de_la_banda()

	assert_eq(sim.hambre_severa_racha, 0, "hambre normal no cuenta como racha")


func test_racha_de_hambre_se_resetea_al_bajar_la_media() -> void:
	var people := _banda(4)
	var sim := _sim(people)
	for person: Inhabitant in people:
		person.hunger = 80.0
	sim._revisar_hambre_de_la_banda()
	sim._revisar_hambre_de_la_banda()
	assert_eq(sim.hambre_severa_racha, 2, "arranca la racha")

	for person: Inhabitant in people:
		person.hunger = 10.0
	sim._revisar_hambre_de_la_banda()

	assert_eq(sim.hambre_severa_racha, 0, "y se corta en cuanto la media baja")


func test_peor_racha_del_anyo_se_recuerda_aunque_la_racha_se_corte() -> void:
	var people := _banda(4)
	var sim := _sim(people)
	for person: Inhabitant in people:
		person.hunger = 80.0
	for i in range(4):
		sim._revisar_hambre_de_la_banda()
	assert_eq(sim.hambre_severa_racha, 4, "cuatro jornadas de racha")

	for person: Inhabitant in people:
		person.hunger = 10.0
	sim._revisar_hambre_de_la_banda()

	assert_eq(sim.hambre_severa_racha, 0, "la racha en curso se corta")
	assert_eq(sim.hambre_severa_peor_racha_del_anyo, 4,
		"pero se recuerda que este año hubo una racha de cuatro")


## Una mujer fértil, para las pruebas de nacimiento.
func _con_madre_fertil(sim: SettlementSim) -> Inhabitant:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var madre := Inhabitant.create(sim.people.size(), Vector3.ZERO, rng)
	madre.sex = Inhabitant.Sex.MUJER
	madre.age_group = Inhabitant.Age.ADULTO
	madre.age_years = 28
	sim.people.append(madre)
	return madre


func test_evaluar_nacimiento_nace_en_anyo_bueno() -> void:
	var sim := _sim(_banda(2))
	_con_madre_fertil(sim)
	sim.store.add(Materia.Kind.FRUTO_SECO, 10000.0)
	sim.hambre_severa_peor_racha_del_anyo = 0
	var antes := sim.population()

	sim.relevo.evaluar_nacimiento()

	assert_eq(sim.population(), antes + 1, "nace alguien en un año bueno")
	var recien_nacido: Inhabitant = sim.people[sim.people.size() - 1]
	assert_eq(recien_nacido.age_group, Inhabitant.Age.NINO, "nace niño")
	assert_eq(recien_nacido.age_years, 0, "con cero años")
	assert_eq(sim.chronicle.recent(10, Chronicle.Kind.GENTE).size(), 1,
		"una anotación de GENTE con el nacimiento")


func test_evaluar_nacimiento_no_nace_sin_reserva() -> void:
	var sim := _sim(_banda(2))
	_con_madre_fertil(sim)
	# El almacén se queda vacío -sin `store.add`-, así que no hay reserva.
	sim.hambre_severa_peor_racha_del_anyo = 0
	var antes := sim.population()

	sim.relevo.evaluar_nacimiento()

	assert_eq(sim.population(), antes, "sin reserva no hay parto, aunque haya madre")


func test_evaluar_nacimiento_no_nace_con_racha_larga_de_hambre() -> void:
	var sim := _sim(_banda(2))
	_con_madre_fertil(sim)
	sim.store.add(Materia.Kind.FRUTO_SECO, 10000.0)
	sim.hambre_severa_peor_racha_del_anyo = Relevo.ANYO_BUENO_RACHA_MAXIMA + 5

	sim.relevo.evaluar_nacimiento()

	assert_eq(sim.population(), 3,
		"con reserva pero con una racha larga de hambre, el año no fue bueno")


func test_evaluar_nacimiento_no_nace_sin_madre() -> void:
	var people := _banda(4)
	for person: Inhabitant in people:
		person.sex = Inhabitant.Sex.HOMBRE
	var sim := _sim(people)
	sim.store.add(Materia.Kind.FRUTO_SECO, 10000.0)
	sim.hambre_severa_peor_racha_del_anyo = 0
	var antes := sim.population()

	sim.relevo.evaluar_nacimiento()

	assert_eq(sim.population(), antes,
		"año bueno pero sin ninguna mujer en edad fértil: no hay parto")


func test_evaluar_nacimiento_resetea_la_racha_del_anyo_siempre() -> void:
	var sim := _sim(_banda(2))
	sim.hambre_severa_peor_racha_del_anyo = 7

	sim.relevo.evaluar_nacimiento()

	assert_eq(sim.hambre_severa_peor_racha_del_anyo, 0,
		"el año que empieza arranca sin la racha del anterior")


func test_evaluar_nacimiento_no_repite_id() -> void:
	var sim := _sim(_banda(2))
	_con_madre_fertil(sim)
	sim.store.add(Materia.Kind.FRUTO_SECO, 10000.0)
	sim.hambre_severa_peor_racha_del_anyo = 0

	sim.relevo.evaluar_nacimiento()

	var ids: Array[int] = []
	for person: Inhabitant in sim.people:
		assert_false(ids.has(person.id), "cada persona con su propio id")
		ids.append(person.id)


func test_revisar_vejez_no_arriesga_nada_por_debajo_del_umbral() -> void:
	var people := _banda(3)
	for person: Inhabitant in people:
		person.age_years = Relevo.OLD_AGE_RISK_START - 1
	var sim := _sim(people)
	sim._rng.seed = 1

	for i in range(50):
		sim.relevo.revisar_vejez()

	assert_eq(sim.population(), 3,
		"nadie muere de vieja antes del umbral, ni en cincuenta giros de año")


func test_revisar_vejez_con_muchos_ancianos_muere_alguno_pero_no_todos() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	var people: Array[Inhabitant] = []
	for i in range(200):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_group = Inhabitant.Age.ANCIANO
		person.age_years = Relevo.OLD_AGE_RISK_MAX_AGE
		people.append(person)
	var sim := _sim(people)
	sim._rng.seed = 7

	sim.relevo.revisar_vejez()

	assert_gt(float(sim.population()), 0.0, "no muere toda la banda de golpe")
	assert_lt(float(sim.population()), 200.0, "pero sí muere alguno, con el riesgo al máximo")


func test_revisar_vejez_forzado_muere_en_un_horizonte_razonable() -> void:
	var people := _banda(1)
	people[0].age_years = Relevo.OLD_AGE_RISK_MAX_AGE
	var sim := _sim(people)
	sim._rng.seed = 3

	for i in range(200):
		sim.relevo.revisar_vejez()
		if sim.population() == 0:
			break

	assert_eq(sim.population(), 0,
		"con el riesgo al máximo, muere dentro de doscientos giros de año")
	var gente := sim.chronicle.recent(10, Chronicle.Kind.GENTE)
	assert_true(gente.size() >= 1 and (gente[0]["text"] as String).find("vieja") >= 0,
		"y la crónica dice que fue de vieja")


func test_person_dies_es_idempotente() -> void:
	var people := _banda()
	var sim := _sim(people)
	var muerto := people[3]

	sim._person_dies(muerto, "Prueba: primera vez.")
	var after_first := sim.population()
	sim._person_dies(muerto, "Prueba: segunda vez, no debería contar.")

	assert_eq(sim.population(), after_first,
		"llamar dos veces sobre quien ya no está no saca a nadie más")
	assert_eq(sim.chronicle.recent(10, Chronicle.Kind.GENTE).size(), 1,
		"y no deja una segunda anotación")
