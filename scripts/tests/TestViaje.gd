class_name TestViaje
extends TestCase
## Migrar y mover gente entre campamentos: SISTEMAS §23, tareas 7 a 10.
##
## Lo que se comprueba aquí son las reglas —cuánto se tarda, qué cuesta, qué
## pasa al llegar— con simulaciones de mentira y los sitios de verdad de la
## comarca. Fundar un campamento nuevo monta relieve y necesita el árbol, que en
## la suite no hay: eso lo mira `CampamentosProbe`.

var _nodos: Array[Node] = []


func suite_name() -> String:
	return "Viaje"


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()


func _sitio(id: int) -> Site:
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	for s: Site in comarca.sites:
		if s.id == id:
			return s
	return null


func _sim(semilla: int, cuantos: int = 6) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var people: Array[Inhabitant] = []
	for i in range(cuantos):
		var persona := Inhabitant.create(i, Vector3.ZERO, rng)
		persona.age_group = Inhabitant.Age.ADULTO
		persona.age_years = 30
		people.append(persona)
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	sim._rng.seed = semilla
	var terreno := FakeTerrain.new()
	sim._terrain = terreno
	sim.home_position = Vector3(700.0, 200.0, 700.0)
	for persona: Inhabitant in sim.people:
		persona.position = sim.home_position
	sim.store.add(Materia.Kind.CARNE_SECA, 400.0)
	_nodos.append(sim)
	_nodos.append(terreno)
	return sim


# --- tarea 7: cuánto se tarda ---------------------------------------------

## El sitio de la comarca más cercano y el más lejano a uno dado, en metros de
## recta. Se buscan y no se escriben: los tres con relieve horneado (56, 14 y 33)
## están a dos y tres kilómetros, y un viaje así cabe en una jornada.
func _cercano_y_lejano(desde: Site) -> Array[Site]:
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var cerca: Site = null
	var lejos: Site = null
	var menos := INF
	var mas := -1.0
	for s: Site in comarca.sites:
		if s.id == desde.id:
			continue
		var m := Vector2((s.lon - desde.lon) * cos(deg_to_rad(desde.lat)), s.lat - desde.lat).length()
		if m < menos:
			menos = m
			cerca = s
		if m > mas:
			mas = m
			lejos = s
	return [cerca, lejos]


func test_dos_destinos_a_distinta_distancia_tardan_distinto() -> void:
	var casa := _sitio(56)
	var dos := _cercano_y_lejano(casa)
	var a := Viaje.camino(casa, dos[0], 0.0)
	var b := Viaje.camino(casa, dos[1], 0.0)
	assert_true(int(a["jornadas"]) >= 1, "un viaje dura al menos una jornada (%.1f km)"
		% (float(a["metros"]) / 1000.0))
	assert_true(int(b["jornadas"]) > int(a["jornadas"]),
		"el sitio más lejano (%.0f km) tarda más jornadas que el más cercano (%.1f km): %d contra %d"
			% [float(b["metros"]) / 1000.0, float(a["metros"]) / 1000.0,
				int(b["jornadas"]), int(a["jornadas"])])
	assert_eq((b["terreno"] as Array).size(), int(b["jornadas"]),
		"y lleva el terreno de cada jornada, para el riesgo")


func test_el_relieve_alarga_el_viaje() -> void:
	# El andar de siempre: la misma distancia en llano y cuesta arriba no cuesta
	# lo mismo. Se compara el viaje de verdad con su distancia a paso de llano.
	var a := Viaje.camino(_sitio(56), _cercano_y_lejano(_sitio(56))[1], 0.0)
	var horas_en_llano := float(a["metros"]) / Viaje.METROS_POR_HORA_EN_LLANO
	assert_true(float(a["horas"]) >= horas_en_llano,
		"con cuestas se tarda lo mismo o más que en llano: %.1f h contra %.1f"
			% [float(a["horas"]), horas_en_llano])


# --- tarea 8: salir -------------------------------------------------------

func test_salir_cobra_raciones_y_carga_lo_que_cabe() -> void:
	var origen := _sim(11)
	var grupo: Array[Inhabitant] = [origen.people[0], origen.people[1]]
	var raciones_antes := origen.store.food_rations()
	var viaje := Viaje.salir(origen, grupo, _sitio(56), _sitio(14), 1)
	assert_true(viaje != null, "sale: %s" % Viaje.ultimo_motivo)
	var cobradas := raciones_antes - origen.store.food_rations()
	var comen := grupo[0].daily_food() * float(viaje.jornadas) * 2.0
	assert_near(float(viaje.raciones), comen, 0.01,
		"las raciones del viaje son lo que comen dos personas esas jornadas")
	assert_true(cobradas >= float(viaje.raciones) - 0.01,
		"y salen de la despensa del campamento de origen")
	assert_eq(origen.people.size(), 4, "los dos ya no están en el campamento")
	var lleva := 0.0
	for persona: Inhabitant in viaje.personas:
		lleva += persona.load_kg()
	assert_true(lleva > 0.0, "y van cargados con lo que les cabe")


func test_no_sale_quien_esta_herido_ni_sin_comida() -> void:
	var origen := _sim(11)
	origen.people[0].hurt_days = 3
	var viaje := Viaje.salir(origen, [origen.people[0]], _sitio(56), _sitio(14), 1)
	assert_true(viaje == null, "herido no sale")
	assert_false(Viaje.ultimo_motivo.is_empty(), "y se dice por qué: %s" % Viaje.ultimo_motivo)

	var pobre := _sim(22)
	pobre.store.take(Materia.Kind.CARNE_SECA, 400.0)
	assert_true(Viaje.salir(pobre, [pobre.people[0]], _sitio(56), _sitio(33), 1) == null,
		"sin comida para el camino no sale")


func test_cuesta_lo_mismo_lo_que_se_anuncia_y_lo_que_se_cobra() -> void:
	# La ficha enseña jornadas y raciones ANTES de confirmar: tienen que ser las
	# que luego se cobran (INTERFAZ §4).
	var origen := _sim(11)
	var grupo: Array[Inhabitant] = [origen.people[2], origen.people[3], origen.people[4]]
	var anunciado := Viaje.lo_que_cuesta(origen, grupo, _sitio(56), _sitio(33))
	var viaje := Viaje.salir(origen, grupo, _sitio(56), _sitio(33), 1)
	assert_eq(viaje.jornadas, int(anunciado["jornadas"]), "las jornadas anunciadas")
	assert_near(viaje.raciones, float(anunciado["raciones"]), 0.001, "y las raciones")


# --- tarea 8: el camino ---------------------------------------------------

func test_el_viaje_llega_el_dia_que_toca() -> void:
	var origen := _sim(11)
	var viaje := Viaje.salir(origen, [origen.people[0]], _sitio(56), _sitio(14), 5)
	assert_eq(viaje.llega_el_dia, 5 + viaje.jornadas, "llega tras sus jornadas")
	for dia in range(5, viaje.llega_el_dia - 1):
		viaje.nueva_jornada(dia + 1)
		assert_false(viaje.ha_llegado(dia + 1), "el día %d sigue de camino" % (dia + 1))
	viaje.nueva_jornada(viaje.llega_el_dia)
	assert_true(viaje.ha_llegado(viaje.llega_el_dia), "y el día de llegada, llega")


func test_el_riesgo_del_camino_es_el_de_una_expedicion_y_no_mata() -> void:
	# Decisión del usuario del 2026-09-14: la misma cuenta que una jornada de
	# expedición, y se llega herido, no se muere. El viaje SE CONSTRUYE —sesenta
	# jornadas en roca, doce personas— en vez de buscar en la comarca uno así de
	# largo: lo que se comprueba es el mecanismo del riesgo.
	var origen := _sim(11, 12)
	var viaje := Viaje.new()
	for persona: Inhabitant in origen.people:
		viaje.personas.append(persona)
	viaje.sale_el_dia = 0
	viaje.jornadas = 60
	viaje.llega_el_dia = 60
	for i in range(60):
		viaje.suelo_por_jornada.append(Traversal.Ground.ROCA)
	viaje._rng.seed = 5
	for dia in range(1, 61):
		viaje.nueva_jornada(dia)
	assert_eq(viaje.personas.size(), 12, "no se muere nadie por el camino")
	# 12 personas × 60 jornadas × (4 % × 2,2 en roca) son unas 63 tiradas buenas;
	# que salga alguna herida es seguro con esa semilla.
	assert_true(viaje.percances.size() > 0,
		"en sesenta jornadas de roca pasa algo: %d percances" % viaje.percances.size())


# --- tarea 9: llegar ------------------------------------------------------

func test_al_llegar_se_suman_con_ids_nuevos_y_descargan() -> void:
	var origen := _sim(11)
	var destino := _sim(22)
	var viaje := Viaje.salir(origen, [origen.people[0], origen.people[1]],
		_sitio(56), _sitio(14), 1)
	var carne_antes := destino.store.amount(Materia.Kind.CARNE_SECA)
	var lleva := 0.0
	for persona: Inhabitant in viaje.personas:
		lleva += float(persona.load.get(Materia.Kind.CARNE_SECA, 0.0))
	viaje.llegar_a(destino)
	assert_eq(destino.people.size(), 8, "los dos se suman a los seis de allí")
	var ids := {}
	for persona: Inhabitant in destino.people:
		ids[persona.id] = true
	assert_eq(ids.size(), 8, "y nadie comparte id")
	assert_near(destino.store.amount(Materia.Kind.CARNE_SECA), carne_antes + lleva, 0.001,
		"y lo que traían entra en la despensa")
	for persona: Inhabitant in viaje.personas:
		assert_true(persona.load.is_empty(), "descargados")


func test_reocupar_un_campamento_vacio_lo_encuentra_como_se_dejo() -> void:
	var origen := _sim(11)
	var abandonado := _sim(22)
	abandonado.store.add(Materia.Kind.LENA, 77.0)
	abandonado.camp_built[CampProjects.Kind.HOGAR] = true
	var todos: Array[Inhabitant] = []
	for persona: Inhabitant in abandonado.people:
		todos.append(persona)
	for persona: Inhabitant in todos:
		abandonado.despedir(persona)
	assert_true(abandonado.people.is_empty(), "el campamento se ha quedado vacío")
	var viaje := Viaje.salir(origen, [origen.people[0]], _sitio(56), _sitio(14), 1)
	viaje.llegar_a(abandonado)
	assert_eq(abandonado.people.size(), 1, "vuelve a tener gente")
	assert_true(abandonado.store.amount(Materia.Kind.LENA) >= 77.0, "con la leña que se dejó")
	assert_true(bool(abandonado.camp_built.get(CampProjects.Kind.HOGAR, false)),
		"y el hogar levantado")


# --- tarea 10: el campamento vacío ----------------------------------------

func test_un_campamento_vacio_no_se_simula() -> void:
	var lleno := _sim(11)
	var vacio := _sim(22)
	var todos: Array[Inhabitant] = []
	for persona: Inhabitant in vacio.people:
		todos.append(persona)
	for persona: Inhabitant in todos:
		vacio.despedir(persona)
	var reloj := RelojDeLaPartida.new()
	_nodos.append(reloj)
	lleno.time_scale = 5.0
	reloj.dirigir(lleno)
	reloj.dirigir(vacio)
	var dia := vacio.day
	var hora := vacio.hour
	var foto := FirmaDiaria.de(vacio).firma
	for i in range(120):
		reloj._un_paso_a_todos()
	assert_true(lleno.hour != 7.0 or lleno.day > 1, "el lleno anda")
	assert_eq(vacio.day, dia, "la jornada del vacío no avanza")
	assert_eq(vacio.hour, hora, "ni su hora")
	assert_eq(FirmaDiaria.de(vacio).firma, foto, "ni cambia nada de su estado")


func test_si_todos_van_de_viaje_la_fecha_sigue() -> void:
	# Una sola fecha para la partida: con los campamentos vacíos, el reloj la
	# lleva él.
	var vacio := _sim(22)
	var todos: Array[Inhabitant] = []
	for persona: Inhabitant in vacio.people:
		todos.append(persona)
	for persona: Inhabitant in todos:
		vacio.despedir(persona)
	var reloj := RelojDeLaPartida.new()
	_nodos.append(reloj)
	vacio.time_scale = 5.0
	reloj.dirigir(vacio)
	var hora := reloj.hora
	for i in range(300):
		reloj._un_paso_a_todos()
	assert_true(reloj.hora > hora or reloj.dia > 1, "la fecha de la partida avanza igual")


# --- el registro: mandar, andar y llegar ----------------------------------

func _campamento(sim: SettlementSim, id: int) -> Campamento:
	var campamento := Campamento.new()
	campamento.sim = sim
	campamento.sitio = _sitio(id)
	_nodos.append(campamento)
	return campamento


func _registro_limpio() -> RelojDeLaPartida:
	Campamentos.vivos.clear()
	Campamentos.viajes.clear()
	var reloj := RelojDeLaPartida.new()
	_nodos.append(reloj)
	Campamentos.reloj = reloj
	return reloj


func _soltar_el_registro() -> void:
	Campamentos.vivos.clear()
	Campamentos.viajes.clear()
	Campamentos.reloj = null


func test_el_registro_lleva_el_viaje_y_al_llegar_se_suman() -> void:
	var reloj := _registro_limpio()
	reloj.dia = 3
	var origen := _campamento(_sim(11), 56)
	var destino := _campamento(_sim(22), 14)
	Campamentos.vivos.append_array([origen, destino])
	var viaje := Campamentos.mandar(origen, [origen.sim.people[0], origen.sim.people[1]], destino.sitio)
	assert_true(viaje != null, "sale: %s" % Viaje.ultimo_motivo)
	assert_eq(viaje.sale_el_dia, 3, "sale en la jornada de la partida, no en la de su campamento")
	assert_eq(Campamentos.viajes.size(), 1, "y el registro lo lleva")
	for dia in range(4, viaje.llega_el_dia):
		Campamentos._nueva_jornada(dia)
		assert_eq(destino.sim.people.size(), 6, "de camino no ha llegado nadie")
	Campamentos._nueva_jornada(viaje.llega_el_dia)
	assert_eq(destino.sim.people.size(), 8, "el día que toca, se suman")
	assert_true(Campamentos.viajes.is_empty(), "y el viaje se acaba")
	_soltar_el_registro()


func test_reocupar_pone_el_campamento_en_la_fecha_de_la_partida() -> void:
	var reloj := _registro_limpio()
	var origen := _campamento(_sim(11), 56)
	var vacio := _campamento(_sim(22), 14)
	var todos: Array[Inhabitant] = []
	for persona: Inhabitant in vacio.sim.people:
		todos.append(persona)
	for persona: Inhabitant in todos:
		vacio.sim.despedir(persona)
	Campamentos.vivos.append_array([origen, vacio])
	var viaje := Campamentos.mandar(origen, [origen.sim.people[0]], vacio.sitio)
	# El vacío se quedó en su jornada; la partida siguió.
	reloj.dia = viaje.llega_el_dia
	reloj.hora = 13.0
	reloj.dia_de_estacion = 9
	Campamentos._nueva_jornada(viaje.llega_el_dia)
	assert_eq(vacio.sim.people.size(), 1, "vuelve a tener gente")
	assert_eq(vacio.sim.day, reloj.dia, "en la jornada de la partida")
	assert_eq(vacio.sim.hour, 13.0, "a su hora")
	assert_eq(vacio.sim.season_day, 9, "y en su día de estación, que si no giraría en otra jornada")
	_soltar_el_registro()


func test_no_se_manda_a_un_valle_sin_preparar() -> void:
	_registro_limpio()
	var origen := _campamento(_sim(11), 56)
	Campamentos.vivos.append(origen)
	var sin_valle: Site = null
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	for s: Site in comarca.sites:
		if not Campamento.valle_preparado(s.id):
			sin_valle = s
			break
	assert_true(sin_valle != null, "hay algún sitio sin valle preparado")
	var viaje := Campamentos.mandar(origen, [origen.sim.people[0]], sin_valle)
	assert_true(viaje == null, "no sale")
	assert_true(Viaje.ultimo_motivo.contains("no está preparado"), "y se dice por qué: %s" % Viaje.ultimo_motivo)
	assert_eq(origen.sim.people.size(), 6, "y nadie se ha ido")
	_soltar_el_registro()


## SPECS §6.4: el campamento vive fuera de las escenas. Si una escena se va sin soltar
## el suyo —un camino que se olvida de `DemoMain._dejar_la_escena`—, al liberarla se
## llevaba el campamento, y el reloj y el índice se quedaban con un objeto liberado:
## los `SCRIPT ERROR` de cada viaje de `TransitoProbe`, que cambiaba de escena a pelo.
##
## Sin árbol —la suite corre en `_init` y no tiene—: se llama lo que la escena llama al
## salir del árbol, y se libera. Que se pueda llamar DURANTE la salida lo comprueba
## `TransitoProbe A_PELO=1`, sin un `SCRIPT ERROR`.
func test_una_escena_que_se_va_no_se_lleva_su_campamento() -> void:
	var reloj := _registro_limpio()
	var campamento := _campamento(_sim(3), 56)
	Campamentos.vivos.append(campamento)
	reloj.dirigir(campamento.sim)
	var escena := Node.new()
	escena.add_child(campamento)
	Campamentos.soltar_de_la_escena(escena, campamento)
	escena.free()
	var sigue := is_instance_valid(campamento)
	var suelto := sigue and campamento.get_parent() == null
	var sin_mirar := sigue and not campamento.sim.se_mira
	_soltar_el_registro()
	assert_true(sigue, "el campamento sobrevive a la escena")
	assert_true(suelto, "suelto, sin padre: sigue simulando fuera del árbol")
	assert_true(sin_mirar, "y ya no se mira")

