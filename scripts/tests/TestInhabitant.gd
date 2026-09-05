class_name TestInhabitant
extends TestCase
## Pruebas del modelo por individuo.

var _rng := RandomNumberGenerator.new()


func suite_name() -> String:
	return "Inhabitant"


func before_each() -> void:
	_rng.seed = 12345


func _adult() -> Inhabitant:
	var p := Inhabitant.create(0, Vector3.ZERO, _rng)
	p.age_group = Inhabitant.Age.ADULTO
	p.hunger = 0.0
	p.fatigue = 0.0
	p.cold = 0.0
	return p


func test_solo_los_adultos_salen_a_trabajar() -> void:
	var p := _adult()
	assert_true(p.can_work(), "un adulto trabaja")
	p.age_group = Inhabitant.Age.NINO
	assert_false(p.can_work(), "un nino no sale de caceria")
	p.age_group = Inhabitant.Age.ANCIANO
	assert_false(p.can_work(), "un anciano ayuda cerca, no se va al coto")


func test_un_nino_come_menos_que_un_adulto() -> void:
	var p := _adult()
	var adult_food := p.daily_food()
	p.age_group = Inhabitant.Age.NINO
	assert_lt(p.daily_food(), adult_food, "un nino come menos")


# --- destreza de partida, por edad ------------------------------------

func test_un_nino_no_sabe_nada_de_partida() -> void:
	var p := Inhabitant.create(0, Vector3.ZERO, _rng)
	p.age_group = Inhabitant.Age.NINO
	p.seed_skills(_rng)
	for task: int in p.skill:
		assert_eq(float(p.skill[task]), 0.0, "un crio empieza en cero")


func test_ningun_adulto_pasa_de_treinta_de_partida() -> void:
	var p := Inhabitant.create(0, Vector3.ZERO, _rng)
	p.age_group = Inhabitant.Age.ADULTO
	p.seed_skills(_rng)
	for task: int in p.skill:
		assert_between(float(p.skill[task]), 0.0, 0.30, "un adulto no nace ya experto")


func test_un_anciano_puede_llegar_a_cincuenta_de_partida() -> void:
	# Con muchas tareas sembradas, el maximo de una tirada de verdad tiene
	# que acercarse al techo o el rango no esta haciendo nada
	var p := Inhabitant.create(0, Vector3.ZERO, _rng)
	p.age_group = Inhabitant.Age.ANCIANO
	p.seed_skills(_rng)
	var highest := 0.0
	for task: int in p.skill:
		highest = maxf(highest, float(p.skill[task]))
		assert_between(float(p.skill[task]), 0.0, 0.50, "un anciano no pasa de cincuenta")
	assert_gt(highest, 0.30, "un anciano de verdad llega mas lejos que un adulto")


# --- velocidad de aprendizaje, por edad --------------------------------

func test_el_nino_aprende_mas_rapido_que_el_adulto_y_el_anciano_mas_lento() -> void:
	var p := Inhabitant.create(0, Vector3.ZERO, _rng)
	p.age_group = Inhabitant.Age.ADULTO
	var adult_rate := p.learn_rate()
	p.age_group = Inhabitant.Age.NINO
	var child_rate := p.learn_rate()
	p.age_group = Inhabitant.Age.ANCIANO
	var elder_rate := p.learn_rate()

	assert_gt(child_rate, adult_rate, "un crio aprende mas rapido que un adulto")
	assert_lt(elder_rate, adult_rate, "un anciano aprende mas despacio que un adulto")


func test_el_hambre_baja_el_rendimiento() -> void:
	var p := _adult()
	var healthy := p.effectiveness()
	p.hunger = 90.0
	assert_lt(p.effectiveness(), healthy, "con hambre se cunde menos")


func test_el_cansancio_baja_el_rendimiento() -> void:
	var p := _adult()
	var fresh := p.effectiveness()
	p.fatigue = 95.0
	assert_lt(p.effectiveness(), fresh, "agotado se cunde menos")


func test_el_rendimiento_nunca_es_cero() -> void:
	var p := _adult()
	p.hunger = 100.0
	p.fatigue = 100.0
	p.cold = 100.0
	assert_gt(p.effectiveness(), 0.0,
		"aun en las peores condiciones se produce algo, no se bloquea")


func test_cada_persona_tiene_nombre_propio() -> void:
	var names := {}
	for i in range(20):
		var p := Inhabitant.create(i, Vector3.ZERO, _rng)
		assert_false(p.given_name.is_empty(), "todo el mundo tiene nombre")
		names[p.given_name] = true
	assert_eq(names.size(), 20, "los nombres no se repiten en una banda")


func test_la_banda_tiene_ninos_y_ancianos() -> void:
	# La piramide se REPARTE, no se sortea. Sorteandola persona a persona
	# salian bandas inviables: una partida de verdad dio DOCE crios de quince,
	# o sea dos adultos para cazar, pescar, explorar y mantener el fuego.
	var band := Inhabitant.create_band(15, Vector3.ZERO, _rng)
	var kids := 0
	var elders := 0
	var adults := 0
	for p: Inhabitant in band:
		if p.age_group == Inhabitant.Age.NINO:
			kids += 1
		elif p.age_group == Inhabitant.Age.ANCIANO:
			elders += 1
		else:
			adults += 1

	assert_eq(band.size(), 15, "la banda entera")
	assert_gt(float(kids), 0.0, "una banda tiene ninos")
	assert_gt(float(elders), 0.0, "y ancianos")
	assert_lt(float(elders), float(kids), "menos viejos que ninos")
	assert_gt(float(adults), float(kids), "y mas adultos que ninos")


func test_la_banda_siempre_puede_trabajar() -> void:
	# La prueba que justifica el cambio: da igual la semilla, siempre salen
	# adultos bastantes para que la partida arranque
	for seed_value in range(20):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var band := Inhabitant.create_band(15, Vector3.ZERO, rng)
		var able := 0
		for p: Inhabitant in band:
			if Profession.can_do(Profession.Job.CAZA, p):
				able += 1
		assert_gt(float(able), 3.0,
			"con la semilla %d hay %d capaces de jornada larga"
				% [seed_value, able])


func test_una_banda_pequena_no_se_queda_sin_adultos() -> void:
	# Con pocos, el cupo de crios cede: es lo que hace una banda real al
	# elegir con quien sale
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var band := Inhabitant.create_band(6, Vector3.ZERO, rng)
	var adults := 0
	for p: Inhabitant in band:
		if p.age_group == Inhabitant.Age.ADULTO:
			adults += 1
	assert_gt(float(adults), 2.0, "quedan adultos para trabajar")


# --- rasgos fisicos: fuerza, resistencia, agudeza ----------------------

func test_un_nino_es_mas_flojo_que_un_adulto_de_partida() -> void:
	var nino := Inhabitant.create(0, Vector3.ZERO, _rng)
	nino.age_group = Inhabitant.Age.NINO
	nino.seed_stats(_rng)
	var adulto := Inhabitant.create(1, Vector3.ZERO, _rng)
	adulto.age_group = Inhabitant.Age.ADULTO
	adulto.seed_stats(_rng)

	assert_lt(nino.stat_in(Inhabitant.Stat.FUERZA), adulto.stat_in(Inhabitant.Stat.FUERZA) + 0.001,
		"un crio no tiene el brazo de un adulto")


func test_la_fuerza_sube_lo_que_se_puede_cargar() -> void:
	var p := _adult()
	p.has_basket = true
	var base := p.carry_limit_kg()

	p.stats[Inhabitant.Stat.FUERZA] = 0.0
	var flojo := p.carry_limit_kg()
	p.stats[Inhabitant.Stat.FUERZA] = 1.0
	var fuerte := p.carry_limit_kg()

	assert_lt(flojo, base + 0.001, "poca fuerza, carga por debajo de la media")
	assert_gt(fuerte, flojo, "mas fuerza, mas se puede cargar")


func test_mas_resistencia_gana_menos_fatiga_por_hora() -> void:
	var p := _adult()
	p.stats[Inhabitant.Stat.RESISTENCIA] = 0.0
	var flojo := p.fatigue_factor()
	p.stats[Inhabitant.Stat.RESISTENCIA] = 1.0
	var aguantador := p.fatigue_factor()

	assert_lt(aguantador, flojo, "quien mas aguanta gana menos fatiga por la misma hora")


func test_la_agudeza_multiplica_la_velocidad_de_aprendizaje() -> void:
	var p := _adult()
	p.stats[Inhabitant.Stat.AGUDEZA] = 0.0
	var lento := p.learn_rate()
	p.stats[Inhabitant.Stat.AGUDEZA] = 1.0
	var espabilado := p.learn_rate()

	assert_gt(espabilado, lento, "mas agudeza, mas rapido se aprende, a igualdad de edad")


func test_entrenar_un_rasgo_fisico_sube_despacio_y_no_pasa_del_tope() -> void:
	var p := _adult()
	p.stats[Inhabitant.Stat.FUERZA] = 0.9
	p.train_stat(Inhabitant.Stat.FUERZA, 0.02)
	assert_near(p.stat_in(Inhabitant.Stat.FUERZA), 0.92, 0.001,
		"sube justo lo que se le pasa")

	p.stats[Inhabitant.Stat.FUERZA] = 0.94
	p.train_stat(Inhabitant.Stat.FUERZA, 0.1)
	assert_between(p.stat_in(Inhabitant.Stat.FUERZA), 0.0, 0.95,
		"no se pasa del tope aunque el empujon sea grande")


# --- rasgos personales: nadar, montar, domar ---------------------------

func test_casi_nadie_empieza_sabiendo_nadar() -> void:
	var con_natacion := 0
	var trials := 200
	for i in range(trials):
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var p := Inhabitant.create(0, Vector3.ZERO, rng)
		if p.trait_in(Inhabitant.Trait.NATACION) > 0.0:
			con_natacion += 1
	var fraction := float(con_natacion) / float(trials)
	assert_between(fraction, 0.05, 0.40,
		"es un rasgo de unos pocos, no de la mayoria (salio %.2f)" % fraction)


func test_montar_y_domar_empiezan_siempre_en_cero() -> void:
	# No hay animal domestico en esta era: el rasgo existe para mas adelante
	for i in range(10):
		var rng := RandomNumberGenerator.new()
		rng.seed = i
		var p := Inhabitant.create(0, Vector3.ZERO, rng)
		assert_eq(p.trait_in(Inhabitant.Trait.MONTA), 0.0, "sin caballo, sin monta")
		assert_eq(p.trait_in(Inhabitant.Trait.DOMA), 0.0, "sin animal, sin doma")


func test_entrenar_un_rasgo_personal_sube_desde_donde_este() -> void:
	var p := _adult()
	p.traits[Inhabitant.Trait.NATACION] = 0.0
	p.train_trait(Inhabitant.Trait.NATACION, 0.05)
	assert_near(p.trait_in(Inhabitant.Trait.NATACION), 0.05, 0.001,
		"nadar se aprende nadando, un poco cada vez")
