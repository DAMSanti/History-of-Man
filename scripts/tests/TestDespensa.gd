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
	sim.hogar._smoke_the_larder()
	assert_gt(sim.store.amount(Materia.Kind.PESCADO_SECO), 0.0,
		"el pescado sale curado sin que nadie se ponga a ello")
	assert_lt(sim.store.amount(Materia.Kind.PESCADO), 30.0,
		"y sale de lo fresco, no de la nada")


func test_sin_secadero_no_se_ahuma() -> void:
	var sim := _con_secadero()
	sim.camp_built.erase(CampProjects.Kind.SECADERO)
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim.hogar._smoke_the_larder()
	assert_eq(sim.store.amount(Materia.Kind.PESCADO_SECO), 0.0,
		"sin bastidor no hay donde colgar nada")


func test_con_el_hogar_apagado_no_se_ahuma() -> void:
	var sim := _con_secadero()
	sim.hearth_lit = false
	sim.store.add(Materia.Kind.CARNE, 30.0)
	sim.hogar._smoke_the_larder()
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"sin brasas no hay humo")


func test_sin_nadie_al_hogar_no_se_ahuma() -> void:
	# Es la supervisión, y es lo que hace que dejar el oficio vacío se pague en
	# la despensa y no solo en el fuego.
	var sim := _con_secadero(0)
	sim.store.add(Materia.Kind.CARNE, 30.0)
	sim.hogar._smoke_the_larder()
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"un secadero sin nadie encima no cura nada")


func test_dos_manos_al_hogar_curan_mas_que_una() -> void:
	# Una segunda persona al hogar es una segunda tanda colgada, no la misma
	# vigilada el doble.
	var uno := _con_secadero(1)
	uno.store.add(Materia.Kind.PESCADO, 200.0)
	uno.hogar._smoke_the_larder()

	var dos := _con_secadero(2)
	dos.store.add(Materia.Kind.PESCADO, 200.0)
	dos.hogar._smoke_the_larder()

	assert_gt(dos.store.amount(Materia.Kind.PESCADO_SECO),
		uno.store.amount(Materia.Kind.PESCADO_SECO),
		"con dos al hogar sale mas curado")


func test_se_cura_antes_lo_que_antes_se_pudre() -> void:
	# El pescado aguanta tres días y la carne cuatro: si sólo da para una tanda,
	# la tanda es de pescado.
	var sim := _con_secadero()
	sim.store.add(Materia.Kind.PESCADO, 200.0)
	sim.store.add(Materia.Kind.CARNE, 200.0)
	sim.hogar._smoke_the_larder()
	assert_gt(sim.store.amount(Materia.Kind.PESCADO_SECO), 0.0,
		"el pescado, que es lo primero que se echa a perder")
	assert_eq(sim.store.amount(Materia.Kind.CARNE_SECA), 0.0,
		"y la carne espera a la tanda siguiente")


func test_lo_ahumado_queda_apuntado_para_el_parte() -> void:
	var sim := _con_secadero()
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	sim.hogar._smoke_the_larder()
	assert_gt(float(sim.hogar.smoked_today.get(int(Materia.Kind.PESCADO_SECO), 0.0)),
		0.0, "el parte sabe cuanto salio del secadero")


# --- y lo que no se cura, se tira ---------------------------------------

func test_lo_que_se_pudre_se_apunta_con_nombre() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.PESCADO, 40.0)
	# El pescado aguanta tres dias y empieza a perderse a partir de la mitad
	sim.store.age(3)
	sim.despensa._report_spoilage()
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
	sim.despensa._report_spoilage()
	assert_gt(float(sim.chronicle.entries.size()), float(antes),
		"tirar comida se cuenta")


func test_sin_perdidas_no_se_dice_nada() -> void:
	# Un parte que sale todos los dias diciendo «nada» es ruido.
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.PIEDRA, 20.0)
	sim.store.age(30)
	sim.despensa._report_spoilage()
	assert_eq(sim.chronicle.entries.size(), 0,
		"la piedra no se pudre y no hay parte que dar")


func test_el_parte_dice_que_falta_para_que_no_vuelva_a_pasar() -> void:
	# Un parte que solo dice cuanto se ha perdido deja al jugador sin nada que
	# hacer con el dato.
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store.add(Materia.Kind.PESCADO, 60.0)
	sim.store.age(3)
	sim.despensa._report_spoilage()
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
	poco.despensa._report_spoilage()

	var mucho := SettlementSim.new()
	mucho.chronicle = Chronicle.new()
	mucho.store.add(Materia.Kind.PESCADO, 200.0)
	mucho.store.age(3)
	mucho.despensa._report_spoilage()

	assert_eq(int(poco.chronicle.entries[-1]["weight"]), 0,
		"una merma pequena es rutina")
	assert_eq(int(mucho.chronicle.entries[-1]["weight"]), 1,
		"perder la despensa no se olvida")


# --- que las cifras de comida cuadren entre si ----------------------------
#
# «El tooltip me pone que come 0,5 por racion y no concuerda con produce/mes
# gasta/mes». Habia dos fallos detras y los dos se comprueban aqui.

func test_ninguna_unidad_se_llama_racion() -> void:
	# RACION es una medida -[Materia.KCAL_RACION], media jornada de una
	# persona- y no puede ser ademas el nombre del bulto: llegaron a convivir
	# «una ración» de seta que valia 0,06 raciones y «una ración» de fruto seco
	# que valia 1,36.
	for kind: int in Materia.Kind.values():
		var k := kind as Materia.Kind
		assert_false(Materia.unit_name(k).to_lower().begins_with("raci"),
			"%s no mide en raciones" % Materia.material_name(k))


func test_una_persona_come_dos_raciones_al_dia() -> void:
	# Es la definicion, y la ficha del material la enseña: si esto cambia, hay
	# que cambiar el texto de la ficha con ello.
	assert_near(Materia.KCAL_DIA / Materia.KCAL_RACION, 2.0, 0.001,
		"la racion es media jornada")


func test_gastado_es_lo_que_de_verdad_ha_salido_del_almacen() -> void:
	# LA COLUMNA GASTADO/30d ES UN LIBRO, NO UN PRONOSTICO.
	#
	# Era `material_needed`, o sea «lo que la banda gastaria en un mes»: treinta
	# dias de bocas proyectados. El dia dos de partida declaraba 762 raciones de
	# comida sin que se hubiera comido casi nada, y eso, leido al lado de «HAY»,
	# engaña.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.CARNE, 40.0)
	assert_eq(sim.taller.material_needed(Materia.Kind.CARNE), 0.0,
		"sin haber sacado nada, no hay nada gastado")

	sim.store.take(Materia.Kind.CARNE, 7.0)
	assert_near(sim.taller.material_needed(Materia.Kind.CARNE), 7.0, 0.001,
		"lo gastado es lo que ha salido por la puerta")


func test_lo_gastado_se_acumula_por_jornadas_y_no_crece_sin_fin() -> void:
	# Misma ventana rodante que la produccion: las dos columnas tienen que
	# medir lo mismo o no se pueden leer juntas.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.LENA, 500.0)
	for i in range(5):
		sim.store.take(Materia.Kind.LENA, 2.0)
		sim.tajo._roll_production()
	assert_near(sim.taller.material_needed(Materia.Kind.LENA), 10.0, 0.001,
		"cinco jornadas a dos son diez")

	for i in range(SettlementSim.CONSUMO_DIAS * 2):
		sim.store.take(Materia.Kind.LENA, 1.0)
		sim.tajo._roll_production()
	assert_eq(sim.taller.spent_days.size(), SettlementSim.CONSUMO_DIAS,
		"el libro no crece sin fin")
	assert_near(sim.taller.material_needed(Materia.Kind.LENA),
		float(SettlementSim.CONSUMO_DIAS), 0.001,
		"y lo que dice es el ultimo mes, no la partida entera")


func test_lo_que_se_pudre_no_figura_como_gastado() -> void:
	# No lo ha gastado la banda: se ha perdido. Va aparte, en
	# `SettlementSim.spoiled_today`, y mezclarlo aqui haria que un mal invierno
	# pareciera un mes de mucho comer.
	var sim := SettlementSim.new()
	sim.store.add(Materia.Kind.PESCADO, 30.0)
	for i in range(int(Materia.shelf_life(Materia.Kind.PESCADO)) + 2):
		sim.store.age(1)
	assert_eq(sim.taller.material_needed(Materia.Kind.PESCADO), 0.0,
		"lo podrido no es gasto")


func test_el_pronostico_sigue_existiendo_para_el_taller() -> void:
	# Se quito de la COLUMNA, no del juego: el taller decide cuanto conviene
	# tener guardado mirando adelante, y para eso si hace falta una prevision.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var sim := SettlementSim.new()
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.apply_priorities()
	sim.store.add(Materia.Kind.CARNE, 40.0)
	assert_gt(sim.taller.material_forecast(Materia.Kind.CARNE), 0.0,
		"de lo que hay en despensa si se preve comer")
	assert_eq(sim.taller.material_forecast(Materia.Kind.SETA), 0.0,
		"y de lo que no hay, no")


# ------------------------------- comer no es lo mismo que comer bien --

func test_la_carne_da_mucha_mas_proteina_por_racion_que_la_raiz() -> void:
	# LA PREGUNTA DEL JUGADOR: «las kcal hacen que un fruto seco alimente como 3
	# pescados y pico, me parece que no esta bien».
	#
	# Y los datos SI estan bien -avellana 3.090 kcal/kg contra 1.200 del
	# pescado-. Lo que esta mal es la medida: una racion no es una caloria. Lo
	# que limita la dieta de un forrajeador es la PROTEINA, y ahi la cosa se da
	# la vuelta.
	var carne := Materia.protein_per_ration(Materia.Kind.CARNE)
	var raiz := Materia.protein_per_ration(Materia.Kind.RAIZ)
	var fruto := Materia.protein_per_ration(Materia.Kind.FRUTO_SECO)
	assert_gt(carne, raiz * 2.0,
		"una racion de carne da mas del doble de proteina que una de raiz")
	assert_gt(carne, fruto,
		"y mas que una de fruto seco, que por calorias le ganaba de largo")


func test_de_avellana_sola_no_se_vive() -> void:
	# Es la frase que el propio `Hunting.gd` lleva escrita -«una banda cantabrica
	# del Magdaleniense vivia de la carne, no de la avellana»- y hasta ahora el
	# juego hacia lo contrario.
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.store.add(Materia.Kind.FRUTO_SECO, 4000.0)

	for dia in range(20):
		sim.day = dia + 1
		sim.despensa._eat_from_store(30.0)
		sim.despensa.pasar_cuenta_de_proteina()

	var flaco := 0
	for person: Inhabitant in sim.people:
		if person.flaqueza > 5.0:
			flaco += 1
	assert_gt(float(flaco), 0.0,
		"veinte dias de solo avellana y la banda flaquea, por llena que este")


func test_con_carne_no_se_flaquea() -> void:
	var sim := SettlementSim.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.store.add(Materia.Kind.CARNE, 4000.0)

	for dia in range(20):
		sim.day = dia + 1
		sim.despensa._eat_from_store(30.0)
		sim.despensa.pasar_cuenta_de_proteina()

	for person: Inhabitant in sim.people:
		assert_near(person.flaqueza, 0.0, 0.001,
			"comiendo carne no se flaquea")


func test_la_flaqueza_baja_el_rendimiento() -> void:
	# Es lo que la hace importar: se puede estar lleno y trabajar mal.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var person := Inhabitant.create(0, Vector3.ZERO, rng)
	person.hunger = 0.0
	person.fatigue = 0.0
	var entero := person.effectiveness()
	person.flaqueza = 80.0
	assert_lt(person.effectiveness(), entero,
		"quien flaquea rinde menos aunque no tenga hambre")
