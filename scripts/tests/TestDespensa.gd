class_name TestDespensa
extends TestCase
## La despensa: lo que el secadero salva y lo que la podredumbre se lleva.
##
## Las dos mitades del mismo asunto, y por eso van juntas. Toda la caza y toda
## la pesca de esta época son una carrera contra el reloj —la carne fresca
## aguanta cuatro días y el pescado tres—, así que lo único que convierte una
## buena jornada en una despensa es el humo. Y lo que no se cura se tira, que
## es la otra mitad y la que no se veía por ninguna parte.


func suite_name() -> String:
	return "Despensa"


func _con_secadero(hogar_hands: int = 1) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.camp_built[CampProjects.Kind.SECADERO] = true
	sim.hearth_lit = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(hogar_hands):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.job = Profession.Job.HOGAR
		sim.people.append(person)
	return sim


# --- el secadero trabaja solo -------------------------------------------

func test_con_hogar_secadero_y_gente_se_ahuma_sin_pedirlo() -> void:
	# La petición literal: automático mientras haya las tres cosas. Nadie gasta
	# la jornada en ello; `_smoke_the_larder` corre en el cierre del día.
	var sim := _con_secadero()
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim._smoke_the_larder()
	assert_gt(sim.store.amount(Materia.Kind.PESCADO_SECO), 0.0,
		"el pescado sale curado sin que nadie se ponga a ello")
	assert_lt(sim.store.amount(Materia.Kind.PESCADO), 30.0,
		"y sale de lo fresco, no de la nada")


func test_sin_secadero_no_se_ahuma() -> void:
	var sim := _con_secadero()
	sim.camp_built.erase(CampProjects.Kind.SECADERO)
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim._smoke_the_larder()
	assert_eq(sim.store.amount(Materia.Kind.PESCADO_SECO), 0.0,
		"sin bastidor no hay donde colgar nada")


func test_con_el_hogar_apagado_no_se_ahuma() -> void:
	var sim := _con_secadero()
	sim.hearth_lit = false
	sim.store.add(Materia.Kind.CARNE, 30.0)
	sim._smoke_the_larder()
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"sin brasas no hay humo")


func test_sin_nadie_al_hogar_no_se_ahuma() -> void:
	# Es la supervisión, y es lo que hace que dejar el oficio vacío se pague en
	# la despensa y no solo en el fuego.
	var sim := _con_secadero(0)
	sim.store.add(Materia.Kind.CARNE, 30.0)
	sim._smoke_the_larder()
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"un secadero sin nadie encima no cura nada")


func test_dos_manos_al_hogar_curan_mas_que_una() -> void:
	# Una segunda persona al hogar es una segunda tanda colgada, no la misma
	# vigilada el doble.
	var uno := _con_secadero(1)
	uno.store.add(Materia.Kind.PESCADO, 200.0)
	uno._smoke_the_larder()

	var dos := _con_secadero(2)
	dos.store.add(Materia.Kind.PESCADO, 200.0)
	dos._smoke_the_larder()

	assert_gt(dos.store.amount(Materia.Kind.PESCADO_SECO),
		uno.store.amount(Materia.Kind.PESCADO_SECO),
		"con dos al hogar sale mas curado")


func test_se_cura_antes_lo_que_antes_se_pudre() -> void:
	# El pescado aguanta tres días y la carne cuatro: si sólo da para una tanda,
	# la tanda es de pescado.
	var sim := _con_secadero()
	sim.store.add(Materia.Kind.PESCADO, 200.0)
	sim.store.add(Materia.Kind.CARNE, 200.0)
	sim._smoke_the_larder()
	assert_gt(sim.store.amount(Materia.Kind.PESCADO_SECO), 0.0,
		"el pescado, que es lo primero que se echa a perder")
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"y la carne espera a la tanda siguiente")


func test_lo_ahumado_queda_apuntado_para_el_parte() -> void:
	var sim := _con_secadero()
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim._smoke_the_larder()
	assert_gt(float(sim.smoked_today.get(int(Materia.Kind.PESCADO_SECO), 0.0)),
		0.0, "el parte sabe cuanto salio del secadero")


# --- y lo que no se cura, se tira ---------------------------------------

func test_lo_que_se_pudre_se_apunta_con_nombre() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.PESCADO, 40.0)
	# El pescado aguanta tres dias y empieza a perderse a partir de la mitad
	sim.store.age(3)
	sim._report_spoilage()
	assert_true(sim.spoiled_today.has(int(Materia.Kind.PESCADO)),
		"el parte dice QUE se ha perdido, no solo cuanto")
	assert_gt(sim.spoiled_rations_today, 0.0,
		"y en raciones, que es lo que duele")


func test_el_parte_sale_todos_los_dias_en_la_cronica() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.CARNE, 60.0)
	sim.store.age(4)
	var antes := sim.chronicle.entries.size()
	sim._report_spoilage()
	assert_gt(float(sim.chronicle.entries.size()), float(antes),
		"tirar comida se cuenta")


func test_sin_perdidas_no_se_dice_nada() -> void:
	# Un parte que sale todos los dias diciendo «nada» es ruido.
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.PIEDRA, 20.0)
	sim.store.age(30)
	sim._report_spoilage()
	assert_eq(sim.chronicle.entries.size(), 0,
		"la piedra no se pudre y no hay parte que dar")


func test_el_parte_dice_que_falta_para_que_no_vuelva_a_pasar() -> void:
	# Un parte que solo dice cuanto se ha perdido deja al jugador sin nada que
	# hacer con el dato.
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.PESCADO, 60.0)
	sim.store.age(3)
	sim._report_spoilage()
	var texto := String(sim.chronicle.entries[-1]["text"])
	assert_true(texto.contains("secadero"),
		"sin secadero, el parte lo dice: %s" % texto)


func test_perder_mucho_es_noticia_y_perder_poco_no() -> void:
	# La cronica olvida primero lo de peso 0. Una merma normal es rutina; medio
	# almacen es una noticia que tiene que sobrevivir.
	var poco := SettlementSim.new()
	poco.chronicle = Chronicle.new()
	poco.store.add(Materia.Kind.PESCADO, 1.0)
	poco.store.age(3)
	poco._report_spoilage()

	var mucho := SettlementSim.new()
	mucho.chronicle = Chronicle.new()
	mucho.store.add(Materia.Kind.PESCADO, 200.0)
	mucho.store.age(3)
	mucho._report_spoilage()

	assert_eq(int(poco.chronicle.entries[-1]["weight"]), 0,
		"una merma pequena es rutina")
	assert_eq(int(mucho.chronicle.entries[-1]["weight"]), 1,
		"perder la despensa no se olvida")
