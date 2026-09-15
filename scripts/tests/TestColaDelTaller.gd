class_name TestColaDelTaller
extends TestCase
## La cola del taller: qué se va a hacer, en qué orden, y por qué algo no sale.
##
## Spec en docs/SISTEMAS.md §22. Lo que se comprueba aquí es lo que antes no se
## podía ni mirar: el taller elegía la pieza menos cubierta dentro de una
## especialidad y no había forma de ver qué venía después, ni de mandar hacer
## algo concreto.
##
## Nada se simula: el taller se monta con el almacén y el utillaje escritos a
## mano, que es como se construye un estado lejano barato —CLAUDE.md—.


func suite_name() -> String:
	return "Cola del taller"


## La misma receta que [TestTaller._sim]: sin árbol de técnicas, o sea que se
## sabe hacer todo. Aquí no se comprueba el árbol.
func _sim(size: int = 6) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260914
	var people: Array[Inhabitant] = []
	for i in range(size):
		var person := Inhabitant.create(i, Vector3.ZERO, rng)
		person.age_years = 30
		person.age_group = Inhabitant.Age.ADULTO
		person.nursing = false
		people.append(person)
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	# Materia prima de sobra: lo que se comprueba es el ORDEN, y sin con qué
	# hacer nada la cola entera saldría bloqueada.
	for kind: int in Materia.Kind.values():
		sim.store.add(kind as Materia.Kind, 500.0)
	return sim


func _artesano(sim: SettlementSim,
		speciality: Profession.Speciality) -> Inhabitant:
	var person := sim.people[0]
	person.job = Profession.Job.MANUFACTURA
	person.current_speciality = speciality
	person.has_task = true
	person.state = Inhabitant.State.TRABAJANDO
	return person


## Deja el utillaje de una especialidad por encima de la reserva, como
## [TestTaller._cubrir].
func _cubrir(sim: SettlementSim, speciality: Profession.Speciality) -> void:
	var demand := sim.taller.tool_demand()
	for kind: int in SettlementSim.SPECIALITY_MAKES.get(speciality, []):
		var pedidas: int = int(demand.get(kind, 0))
		for i in range(maxi(pedidas, 1) * 3):
			sim.toolkit.craft(kind as Tool.Kind, Tool.Stuff.CUARCITA, 0.5)


# --- la cola, y que es la misma lista que usa el artesano -----------------

func test_la_pieza_que_se_hace_es_la_primera_de_la_cola() -> void:
	var sim := _sim()
	var lista := sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)
	assert_true(lista.size() > 0, "hay trabajo en la talla al empezar")
	assert_eq(sim.taller._next_piece(Profession.Speciality.TALLA),
		int(lista[0]["tool"]),
		"y lo que se talla es la primera entrada de la cola, no otra cosa")


## El buril, que es la herramienta previa del asta: sin él una azagaya no se
## hace —no es que se tarde más, es que no se hace— y la entrada sale bloqueada
## con su motivo, que es lo que comprueba
## [test_una_entrada_bloqueada_dice_por_que_y_no_para_la_cola].
func _con_herramientas_previas(sim: SettlementSim) -> void:
	for kind: int in [Tool.Kind.BURIL, Tool.Kind.LASCA, Tool.Kind.AGUJA]:
		sim.toolkit.craft(kind as Tool.Kind, Tool.Stuff.CUARCITA, 0.5)


func test_el_encargo_va_delante_de_lo_automatico() -> void:
	var sim := _sim()
	_con_herramientas_previas(sim)
	sim.taller.encargar_pieza(Tool.Kind.AZAGAYA, 2)
	var lista := sim.taller.cola_de_trabajo(Profession.Speciality.ASTA)
	assert_eq(int(lista[0]["tool"]), int(Tool.Kind.AZAGAYA),
		"el encargo es lo primero")
	assert_false(bool(lista[0]["automatico"]), "y se sabe que lo pidió el jugador")
	assert_eq(int(lista[0]["faltan"]), 2, "con su cantidad")
	assert_eq(sim.taller._next_piece(Profession.Speciality.ASTA),
		int(Tool.Kind.AZAGAYA), "el astero hace eso y no lo suyo de siempre")


func test_el_encargo_se_hace_aunque_la_meta_este_cubierta() -> void:
	var sim := _sim()
	_con_herramientas_previas(sim)
	_cubrir(sim, Profession.Speciality.ASTA)
	assert_eq(sim.taller._next_piece(Profession.Speciality.ASTA), -1,
		"con el utillaje cubierto el astero no tenía nada que hacer")

	sim.taller.encargar_pieza(Tool.Kind.AZAGAYA, 3)
	assert_eq(sim.taller._next_piece(Profession.Speciality.ASTA),
		int(Tool.Kind.AZAGAYA),
		"y con un encargo lo tiene: la meta es un tope, el encargo es una orden")


func test_el_encargo_cumplido_desaparece() -> void:
	var sim := _sim()
	sim.taller.encargar_pieza(Tool.Kind.LASCA, 2)
	sim.taller._cumplir_encargo(Tool.Kind.LASCA)
	assert_eq(int(sim.taller.encargos[0]["faltan"]), 1, "queda una")
	sim.taller._cumplir_encargo(Tool.Kind.LASCA)
	assert_true(sim.taller.encargos.is_empty(),
		"y cumplido del todo se va de la cola")


func test_una_entrada_bloqueada_dice_por_que_y_no_para_la_cola() -> void:
	var sim := _sim()
	# Un vestido sin aguja: la aguja es la herramienta previa de la costura.
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 500.0)
	sim.taller.encargar_pieza(Tool.Kind.VESTIDO, 1)
	var lista := sim.taller.cola_de_trabajo(Profession.Speciality.PELETERIA)
	assert_eq(int(lista[0]["tool"]), int(Tool.Kind.VESTIDO), "el encargo, delante")
	assert_false(String(lista[0]["motivo"]).is_empty(),
		"y dice por qué no se puede hacer")
	# Y el peletero, mientras tanto, hace lo siguiente que sí puede.
	var siguiente := sim.taller._next_piece(Profession.Speciality.PELETERIA)
	assert_true(siguiente != int(Tool.Kind.VESTIDO),
		"una entrada bloqueada no para la cola")


func test_lo_de_nunca_no_sale_en_la_cola() -> void:
	var sim := _sim()
	var antes := sim.taller.cola_de_trabajo(Profession.Speciality.TALLA).size()
	var primera := int(sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)[0]["tool"])
	sim.fijar_prioridad_pieza(primera as Tool.Kind, Prioridades.Nivel.NUNCA)
	var lista := sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)
	assert_eq(lista.size(), antes - 1, "la pieza apartada se va de la cola")
	for entrada: Dictionary in lista:
		assert_true(int(entrada["tool"]) != primera,
			"y no vuelve mientras siga en nunca")


func test_bajar_una_automatica_la_pone_detras_de_las_normales() -> void:
	var sim := _sim()
	var lista := sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)
	assert_true(lista.size() >= 2, "hay al menos dos cosas que hacer")
	var primera := int(lista[0]["tool"])

	# Bajarla es ponerle nivel bajo: una sola palanca con dos puertas.
	sim.prioridades.mover_pieza(primera as Tool.Kind, 1)
	assert_eq(sim.prioridades.de_pieza(primera as Tool.Kind),
		Prioridades.Nivel.BAJA, "bajar la entrada baja el nivel de la pieza")
	var despues := sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)
	assert_true(int(despues[0]["tool"]) != primera,
		"y deja de ser la primera")
	assert_eq(int(despues[despues.size() - 1]["tool"]), primera,
		"se va detrás de todas las de nivel normal")


func test_subir_una_automatica_la_pone_delante() -> void:
	var sim := _sim()
	var lista := sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)
	assert_true(lista.size() >= 2, "hay al menos dos cosas que hacer")
	var ultima := int(lista[lista.size() - 1]["tool"])
	sim.prioridades.mover_pieza(ultima as Tool.Kind, -1)
	assert_eq(sim.prioridades.de_pieza(ultima as Tool.Kind),
		Prioridades.Nivel.ALTA, "subir la entrada sube el nivel de la pieza")
	assert_eq(int(sim.taller.cola_de_trabajo(Profession.Speciality.TALLA)[0]["tool"]), ultima,
		"y se pone la primera")


# --- lo que se ve es lo que se hace ---------------------------------------

func test_lo_que_termina_el_artesano_es_la_cabeza_de_la_cola() -> void:
	# El criterio de la spec, sin correr una partida: se talla hora a hora y en
	# cada pieza terminada se comprueba que era **la primera entrada de la cola
	# que se podía hacer** en ese momento. Lo que lo hace distinto de mirar
	# `_next_piece` a secas es que por en medio pasa todo lo demás: el progreso
	# por persona, la materia prima que se gasta y la cobertura que sube con
	# cada pieza, y cualquiera de las tres puede cambiar la cabeza.
	var sim := _sim()
	_con_herramientas_previas(sim)
	var artesano := _artesano(sim, Profession.Speciality.TALLA)
	sim.taller.encargar_pieza(Tool.Kind.RAEDERA, 2)

	var terminadas := 0
	var descuadres := 0
	for jornada in range(12):
		for hora in range(int(SettlementSim.HORAS_UTILES)):
			var cabeza := sim.taller._next_piece(Profession.Speciality.TALLA)
			var antes := {}
			for kind: int in SettlementSim.SPECIALITY_MAKES[Profession.Speciality.TALLA]:
				antes[kind] = sim.toolkit.count(kind as Tool.Kind)
			sim.taller._craft(artesano, 1.0)
			for kind: int in antes:
				if sim.toolkit.count(kind as Tool.Kind) <= int(antes[kind]):
					continue
				terminadas += 1
				if kind != cabeza:
					descuadres += 1

	assert_true(terminadas > 0, "se terminaron piezas: %d" % terminadas)
	assert_eq(descuadres, 0,
		"y todas eran la primera entrada de la cola que se podía hacer")
	assert_true(sim.taller.encargos.is_empty(),
		"el encargo de dos raederas se cumplió y desapareció de la cola")


# --- a quién se manda al taller -------------------------------------------

func test_un_encargo_manda_gente_al_taller() -> void:
	var sim := _sim()
	_con_herramientas_previas(sim)
	_cubrir(sim, Profession.Speciality.ASTA)
	assert_true(sim.reparto._speciality_pressure(Profession.Speciality.ASTA) > 0.5,
		"con el utillaje cubierto el asta estaba satisfecha")

	sim.taller.encargar_pieza(Tool.Kind.AZAGAYA, 3)
	assert_eq(sim.reparto._speciality_pressure(Profession.Speciality.ASTA), 0.0,
		"y un encargo hacedero la pone a lo más urgente")


func test_lo_apartado_no_manda_a_nadie() -> void:
	var sim := _sim()
	# Sin utillaje ninguno, la talla está a cero de todo: máxima presión.
	assert_eq(sim.reparto._speciality_pressure(Profession.Speciality.TALLA), 0.0,
		"la talla sin nada hecho pide gente")
	for kind: int in SettlementSim.SPECIALITY_MAKES[Profession.Speciality.TALLA]:
		sim.fijar_prioridad_pieza(kind as Tool.Kind, Prioridades.Nivel.NUNCA)
	assert_eq(sim.reparto._speciality_pressure(Profession.Speciality.TALLA), 1.0,
		"y con todo lo suyo apartado deja de pedirla")


func test_la_cola_entera_lleva_las_cuatro_especialidades() -> void:
	var sim := _sim()
	var vistas := {}
	for entrada: Dictionary in sim.taller.cola_de_trabajo():
		vistas[int(entrada["especialidad"])] = true
	assert_true(vistas.size() > 1,
		"la ventana pinta la cola de todo el taller, no la de un oficio")
