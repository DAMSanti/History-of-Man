class_name TestGuardado
extends TestCase
## Guardar la partida y retomarla donde se dejó.
##
## Frente 15 de EPOCA_01 §10.1, tanda 3, que es la FASE A3 del ROADMAP. Hasta el
## 2026-09-13 al volver al mapa regional sólo viajaban la población y la comida.
##
## Lo que se comprueba aquí es el **fichero**: que lo guardado se lee, que una
## versión distinta se rechaza en vez de cargarse a medias, y que la firma del
## estado sobrevive a la ida y la vuelta. Que la partida siga siendo la misma
## cinco jornadas después se mide con `GuardadoProbe`, que necesita dos procesos.


func suite_name() -> String:
	return "Guardado"


## LA CARPETA DE LAS PRUEBAS, antes de cada una. Nunca la del jugador: esta
## suite borró su partida el 2026-09-13 por guardar y borrar sobre el mismo
## fichero que el juego. Ver [Guardado.carpeta].
const CARPETA_DE_PRUEBAS := "user://pruebas/mapas"


func before_each() -> void:
	Guardado.carpeta = CARPETA_DE_PRUEBAS


func test_las_pruebas_no_tocan_la_carpeta_del_jugador() -> void:
	# El control de lo de arriba, y el que habría evitado perder la partida.
	assert_true(Guardado.carpeta != Guardado.CARPETA,
		"las pruebas guardan en su carpeta, no en la del juego")


func _sim(cuantos: int = 5) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 120.0)
	sim.techs = TechTree.new()
	sim.knowledge = BandKnowledge.new()
	sim.game_seed = 4242
	sim.day = 37
	for i in range(cuantos):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "P%d" % i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	return sim


## El mapa que se «juega» en estas pruebas: desde el 2026-09-13 el estado se
## guarda POR MAPA, así que sin un sitio no hay dónde guardarlo.
const SITIO := 777


func _guardar_estado(sitio: int = SITIO) -> Dictionary:
	var antes := {
		"home": GameState.home,
		"discovered": GameState.discovered.duplicate(),
		"avistados": GameState.avistados.duplicate(),
		"season": GameState.season,
		"year": GameState.year,
		"site": Expedition.site,
	}
	var s := Site.new()
	s.id = sitio
	Expedition.site = s
	return antes


func _devolver_estado(antes: Dictionary) -> void:
	GameState.home = antes["home"]
	GameState.discovered = antes["discovered"]
	GameState.avistados = antes["avistados"]
	GameState.season = antes["season"]
	GameState.year = antes["year"]
	Expedition.site = antes["site"]


func test_lo_guardado_se_lee() -> void:
	var antes := _guardar_estado()
	var sim := _sim()
	Guardado.borrar()
	assert_eq(Guardado.guardar(sim), "", "se guarda sin error")
	var leido := Guardado.leer()
	_devolver_estado(antes)
	assert_false(leido.is_empty(), "y se vuelve a leer")
	assert_eq(int(leido.get("semilla", -1)), 4242, "con su semilla")
	assert_eq(int(leido.get("jornada", -1)), 37, "y su jornada")
	Guardado.borrar()


func test_sin_partida_no_hay_nada_que_retomar() -> void:
	Guardado.borrar()
	assert_false(Guardado.hay_partida(), "sin fichero no hay partida")
	assert_true(Guardado.leer().is_empty(), "y leer no inventa una")


func test_un_guardado_de_otra_version_se_rechaza() -> void:
	# No se carga a medias: se dice y se empieza de nuevo. Es lo que la spec
	# acepta, y lo contrario de lo que hace una instantánea de medida.
	var antes := _guardar_estado()
	var sim := _sim()
	Guardado.borrar()
	Guardado.guardar(sim)
	var leido := Guardado.leer()
	_devolver_estado(antes)
	assert_false(leido.is_empty(), "el de esta versión sí se lee")
	# Se reescribe con una versión imposible.
	var fichero := FileAccess.open(Guardado.ruta_de(SITIO), FileAccess.WRITE)
	leido["version"] = Guardado.VERSION + 99
	fichero.store_var(leido, true)
	fichero.close()
	assert_true(Guardado.leer().is_empty(), "el de otra versión se rechaza")
	assert_false(Guardado.hay_partida(), "y no se ofrece retomarlo")
	Guardado.borrar()


func test_la_ida_y_la_vuelta_no_pierden_nada() -> void:
	# LA FIRMA, que es lo que no perdona: una millonésima de hambre la cambia.
	var antes := _guardar_estado()
	var sim := _sim()
	sim.people[0].hunger = 31.25
	sim.people[1].fatigue = 12.5
	var firma_antes := FirmaDiaria.de(sim).firma
	Guardado.borrar()
	Guardado.guardar(sim)
	var otra := _sim()
	otra.people[0].hunger = 0.0
	var errores := Guardado.volcar(Guardado.leer(), otra)
	var firma_despues := FirmaDiaria.de(otra).firma
	_devolver_estado(antes)
	assert_eq(errores.size(), 0, "se vuelca sin errores: %s" % str(errores))
	assert_eq(firma_despues, firma_antes,
		"y la partida cargada tiene la misma firma que la guardada")
	Guardado.borrar()


func test_una_expedicion_a_medias_se_guarda_entera() -> void:
	var antes := _guardar_estado()
	var sim := _sim(6)
	sim.store.add(Materia.Kind.PIEL_CURTIDA, 10.0)
	sim.store.add(Materia.Kind.LENA, 200.0)
	TestExpedicion.con_algo_al_lado(sim)
	assert_true(sim.expedicion.mandar(3, 90.0), "sale la expedición")
	var vuelve := sim.expedicion.vuelve_el_dia
	Guardado.borrar()
	Guardado.guardar(sim)
	var otra := _sim(6)
	Guardado.volcar(Guardado.leer(), otra)
	_devolver_estado(antes)
	assert_true(otra.expedicion.en_marcha(), "sigue fuera al cargar")
	assert_eq(otra.expedicion.vuelve_el_dia, vuelve, "y vuelve el día que tocaba")
	assert_eq(otra.expedicion.fuera.size(), 3, "con los mismos que salieron")
	Guardado.borrar()


func test_lo_descubierto_de_la_comarca_viaja() -> void:
	# El otro criterio del frente: al volver a la región, el mapa tiene que
	# enseñar lo que la expedición descubrió.
	var antes := _guardar_estado()
	var sim := _sim()
	GameState.discovered = {56: true, 101: true, 102: true}
	Guardado.borrar()
	Guardado.guardar(sim)
	var leido := Guardado.leer()
	_devolver_estado(antes)
	var descubierto: Array = leido.get("descubierto", [])
	assert_eq(descubierto.size(), 3, "se guardan los tres sitios conocidos")
	Guardado.borrar()


# ------------------------------------------ un estado por mapa (2026-09-13) --

func test_un_mapa_de_visita_no_pisa_el_de_la_banda() -> void:
	# LO QUE LE HIZO PERDER LA PARTIDA AL USUARIO el 2026-09-13: entrar en otro
	# sitio empezaba una partida que al volver lo pisaba. Aquello se arregló con
	# un estado por mapa; desde el 2026-09-14 la banda sólo vive en UN mapa —el
	# primero— y los demás se visitan sin ella: «no debe traer a mi banda, sólo
	# cargar y mostrarme el mapa». Un mapa de visita no se guarda.
	Guardado.borrar()
	var antes := _guardar_estado(101)
	var a := _sim()
	a.day = 11
	assert_eq(Guardado.guardar(a), "", "el mapa de la banda se guarda")
	_guardar_estado(202)
	var b := _sim(0)
	b.day = 22
	var fallo := Guardado.guardar(b)
	_devolver_estado(antes)
	assert_false(fallo.is_empty(), "el de visita no")
	assert_eq(int(Guardado.leer(101).get("jornada", -1)), 11, "el de la banda sigue en su jornada")
	assert_false(Guardado.hay_partida(202), "y del visitado no queda estado")
	Guardado.borrar()


func test_el_mapa_de_la_banda_es_el_de_volver() -> void:
	Guardado.borrar()
	var antes := _guardar_estado(101)
	Guardado.guardar(_sim())
	_devolver_estado(antes)
	assert_eq(Guardado.sitio_de_la_banda(), 101, "la banda está en el primero")
	assert_eq(int(Guardado.leer().get("sitio", -1)), 101, "y leer sin decir cuál es leer ése")
	Guardado.borrar()


func test_con_varios_mapas_de_antes_la_banda_es_la_mas_vivida() -> void:
	# Partidas de antes del 2026-09-14 tienen banda en varios mapas —la del
	# usuario, en tres—. El de la banda es el que lleva más jornadas: el primero
	# que se fundó y en el que se jugó. Los demás pasan a ser visitas.
	Guardado.borrar()
	var antes := _guardar_estado(101)
	var a := _sim()
	a.day = 204
	var datos_a := {"version": Guardado.VERSION, "sitio": 101, "jornada": 204}
	var datos_b := {"version": Guardado.VERSION, "sitio": 202, "jornada": 12}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Guardado.carpeta))
	for datos: Dictionary in [datos_a, datos_b]:
		var fichero := FileAccess.open(Guardado.ruta_de(int(datos["sitio"])), FileAccess.WRITE)
		fichero.store_var(datos, true)
		fichero.close()
	_devolver_estado(antes)
	assert_eq(Guardado.sitio_de_la_banda(), 101, "la de 204 jornadas, no la de 12")
	Guardado.borrar()


func test_un_mapa_sin_visitar_no_tiene_estado() -> void:
	Guardado.borrar()
	var antes := _guardar_estado(101)
	Guardado.guardar(_sim())
	_devolver_estado(antes)
	assert_false(Guardado.hay_partida(303), "al que no se ha entrado nunca se entra de nuevo")
	Guardado.borrar()


func test_lo_descubierto_se_suma_y_no_se_pisa() -> void:
	# Lo descubierto es de la comarca: entrar en un mapa guardado no puede
	# olvidar lo que se descubrió desde otro después.
	Guardado.borrar()
	var antes := _guardar_estado(101)
	GameState.discovered = {101: true}
	Guardado.guardar(_sim())
	GameState.discovered = {101: true, 500: true, 501: true}
	var sitios := SiteSet.new()
	var s := Site.new()
	s.id = 101
	sitios.sites.append(s)
	Guardado.preparar_la_escena(Guardado.leer(101), sitios)
	var sabidos := GameState.discovered.size()
	_devolver_estado(antes)
	assert_eq(sabidos, 3, "los dos sitios descubiertos después siguen sabidos")
	Guardado.borrar()


func test_las_prioridades_y_los_encargos_sobreviven() -> void:
	# Lo que el jugador ha decidido es parte de la partida, no del rato: si se
	# pierde al guardar, la ventana de prioridades es un juguete. Ver
	# SISTEMAS §22.
	var antes := _guardar_estado()
	var sim := _sim()
	sim.fijar_prioridad_material(Materia.Kind.SILEX, Prioridades.Nivel.ALTA)
	sim.fijar_prioridad_especie("uro", Prioridades.Nivel.NUNCA)
	sim.fijar_prioridad_pieza(Tool.Kind.LAMPARA, Prioridades.Nivel.BAJA)
	sim.taller.encargar_pieza(Tool.Kind.AZAGAYA, 3)
	Guardado.borrar()
	Guardado.guardar(sim)

	var otra := _sim()
	var errores := Guardado.volcar(Guardado.leer(), otra)
	_devolver_estado(antes)
	assert_eq(errores.size(), 0, "se vuelca sin errores: %s" % str(errores))
	assert_eq(otra.prioridades.de_material(Materia.Kind.SILEX),
		Prioridades.Nivel.ALTA, "el sílex sigue en alta")
	assert_eq(otra.prioridades.de_especie("uro"),
		Prioridades.Nivel.NUNCA, "el uro sigue apartado")
	assert_eq(otra.prioridades.de_pieza(Tool.Kind.LAMPARA),
		Prioridades.Nivel.BAJA, "y la lámpara en baja")
	assert_eq(otra.taller.encargos.size(), 1, "el encargo sigue en la cola")
	assert_eq(int(otra.taller.encargos[0]["faltan"]), 3, "con sus tres piezas")
	Guardado.borrar()


func test_un_guardado_de_antes_carga_en_normal() -> void:
	# Un fichero escrito antes de que existieran las prioridades no las lleva:
	# tiene que cargar con todo en normal y sin encargos, no fallar.
	var antes := _guardar_estado()
	var sim := _sim()
	Guardado.borrar()
	Guardado.guardar(sim)
	var leido := Guardado.leer()

	var otra := _sim()
	otra.fijar_prioridad_material(Materia.Kind.SILEX, Prioridades.Nivel.ALTA)
	otra.taller.encargar_pieza(Tool.Kind.AZAGAYA, 2)
	var errores := Guardado.volcar(leido, otra)
	_devolver_estado(antes)
	assert_eq(errores.size(), 0, "se vuelca sin errores: %s" % str(errores))
	assert_eq(otra.prioridades.de_material(Materia.Kind.SILEX),
		Prioridades.Nivel.NORMAL,
		"cargar una partida sin prioridades las deja en normal")
	assert_true(otra.taller.encargos.is_empty(), "y sin encargos")
	Guardado.borrar()


# --- varios campamentos y los grupos de camino (SISTEMAS §23, tarea 12) ------

func _viaje_de_prueba() -> Viaje:
	var viaje := Viaje.new()
	var p := Inhabitant.new()
	p.id = 3
	p.given_name = "Ariz"
	p.age_group = Inhabitant.Age.ADULTO
	p.hurt_days = 2
	p.load[Materia.Kind.CARNE_SECA] = 7.5
	viaje.personas.append(p)
	viaje.desde_id = SITIO
	viaje.hasta_id = SITIO + 1
	viaje.hasta_nombre = "El Pendo"
	viaje.sale_el_dia = 36
	viaje.llega_el_dia = 39
	viaje.jornadas = 3
	viaje.raciones = 9.0
	viaje.suelo_por_jornada.assign([0, 2, 1])
	viaje.percances.append("Ariz se torció un tobillo")
	viaje._rng.seed = 99
	viaje._rng.randi()
	return viaje


func test_un_grupo_de_camino_se_guarda_con_su_gente_y_su_azar() -> void:
	var viaje := _viaje_de_prueba()
	var otro := Viaje.de_datos(viaje.a_datos())
	assert_true(otro != null, "se lee")
	assert_eq(otro.personas.size(), 1, "con su gente")
	assert_eq(otro.personas[0].given_name, "Ariz", "que es quien era")
	assert_eq(otro.personas[0].hurt_days, 2, "herido como iba")
	assert_near(float(otro.personas[0].load.get(Materia.Kind.CARNE_SECA, 0.0)), 7.5, 0.0001,
		"y con lo que cargaba")
	assert_eq(otro.llega_el_dia, 39, "llega el mismo día")
	assert_eq(otro.suelo_por_jornada, viaje.suelo_por_jornada, "por el mismo suelo")
	assert_eq(otro.percances, viaje.percances, "con lo que le ha pasado")
	assert_eq(otro._rng.randi(), viaje._rng.randi(), "y el camino que queda sale igual")


func test_dos_campamentos_y_un_grupo_de_camino_se_guardan_juntos() -> void:
	var antes := _guardar_estado()
	Guardado.borrar()
	var escena := _sim()
	var otro := _sim(3)
	otro.day = 37
	otro.people[0].hunger = 44.5
	var firma_otro := FirmaDiaria.de(otro).firma
	var c1 := Campamento.new()
	c1.sim = escena
	c1.sitio = Expedition.site
	var c2 := Campamento.new()
	c2.sim = otro
	c2.sitio = Site.new()
	c2.sitio.id = SITIO + 1
	c2.relieve = "res://data/dem/local/site_14.res"
	Campamentos.vivos.clear()
	Campamentos.viajes.clear()
	Campamentos.vivos.append_array([c1, c2])
	var reloj := RelojDeLaPartida.new()
	Campamentos.reloj = reloj
	reloj.dia = 37
	reloj.hora = 15.5
	Campamentos.viajes.append(_viaje_de_prueba())

	var fallo := Guardado.guardar(escena)
	var cabeceras := Guardado.cabeceras()
	var del_otro := Guardado.leer(SITIO + 1)
	var partida := Guardado.leer_la_partida()
	var vuelta := _sim(3)
	var errores := Guardado.volcar(del_otro, vuelta)
	var firma_vuelta := FirmaDiaria.de(vuelta).firma
	Campamentos.vivos.clear()
	Campamentos.viajes.clear()
	Campamentos.reloj = null
	reloj.free()
	for nodo: Node in [escena, otro, vuelta, c1, c2]:
		nodo.free()
	_devolver_estado(antes)

	assert_eq(fallo, "", "se guarda sin error")
	assert_eq(cabeceras.size(), 2, "un fichero por campamento")
	assert_eq(int(del_otro.get("orden", -1)), 1, "con el orden en que da sus pasos")
	assert_eq(String(del_otro.get("relieve", "")), "res://data/dem/local/site_14.res",
		"y su relieve, no el del mapa que se mira")
	assert_eq(errores.size(), 0, "el otro se vuelca sin errores: %s" % str(errores))
	assert_eq(firma_vuelta, firma_otro, "y es la misma partida")
	assert_eq(int(partida.get("dia", -1)), 37, "la cabecera lleva la fecha de todos")
	assert_near(float(partida.get("hora", -1.0)), 15.5, 0.0001, "con su hora")
	assert_eq((partida.get("viajes", []) as Array).size(), 1, "y el grupo que va de camino")
	Guardado.borrar()


func test_una_partida_de_una_banda_se_sigue_abriendo() -> void:
	var antes := _guardar_estado()
	var sim := _sim()
	Guardado.borrar()
	Guardado.guardar(sim)
	var leido := Guardado.leer()
	_devolver_estado(antes)
	leido["version"] = 1
	var fichero := FileAccess.open(Guardado.ruta_de(SITIO), FileAccess.WRITE)
	fichero.store_var(leido, true)
	fichero.close()
	assert_false(Guardado.leer().is_empty(), "un fichero de la versión 1 se lee")
	assert_true(Guardado.leer_la_partida().is_empty(), "y sin cabecera de partida: era de un campamento")
	Guardado.borrar()


func test_la_niebla_se_guarda_y_se_suma_al_cargar() -> void:
	# SISTEMAS §4: la niebla sobrevive a guardar y cargar, y como lo descubierto
	# se suma a lo que ya se ha visto en la sesión.
	var antes := _guardar_estado()
	var niebla_antes := GameState.niebla
	Guardado.borrar()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.niebla.levantar_circulo(-4.1, 43.2, 3000.0)
	GameState.niebla.levantar_circulo(-4.1, 43.2, 1000.0, NieblaRegional.RECORRIDA)
	var vistas := GameState.niebla.cuantas()
	var recorridas := GameState.niebla.cuantas(NieblaRegional.RECORRIDA)
	var sim := _sim()
	var fallo := Guardado.guardar(sim)
	var guardado := Guardado.leer()
	# Otra sesión que ya había visto otra cosa.
	GameState.niebla = NieblaRegional.de_la_comarca()
	var de_la_sesion := GameState.niebla.levantar_circulo(-3.5, 43.3, 3000.0)
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var preparo := Guardado.preparar_la_escena(guardado, sitios)
	var total := GameState.niebla.cuantas()
	var recorrida := GameState.niebla.cuantas(NieblaRegional.RECORRIDA)
	var dentro := GameState.niebla.levantada(-4.1, 43.2)
	GameState.niebla = niebla_antes
	_devolver_estado(antes)
	sim.free()
	Guardado.borrar()
	assert_eq(fallo, "", "se guarda")
	# `preparar_la_escena` pide un sitio de la comarca; el de la prueba no lo es,
	# así que se prueba la suma directamente si no pudo prepararla.
	if not preparo:
		var otra := NieblaRegional.de_la_comarca()
		otra.levantar_circulo(-3.5, 43.3, 3000.0)
		assert_true(otra.sumar_datos(guardado.get("niebla", {})), "lo guardado se suma")
		total = otra.cuantas()
		recorrida = otra.cuantas(NieblaRegional.RECORRIDA)
		dentro = otra.levantada(-4.1, 43.2)
	assert_eq(total, vistas + de_la_sesion, "se ve lo guardado y lo de la sesión")
	assert_eq(recorrida, recorridas, "con lo recorrido")
	assert_true(dentro, "y lo guardado está donde estaba")


func test_un_guardado_sin_niebla_ve_lo_que_ya_conocia() -> void:
	# Compatibilidad: una partida de antes de la niebla (2026-09-14) trae sitios
	# descubiertos y ninguna niebla. Al abrirla se levanta su recuadro, o
	# quedarían todos tapados.
	var antes := _guardar_estado()
	var niebla_antes := GameState.niebla
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio: Site = sitios.sites[0]
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {}
	var preparo := Guardado.preparar_la_escena({"version": 1, "sitio": sitio.id,
		"descubierto": [sitio.id]}, sitios)
	var se_ve := GameState.se_ve(sitio)
	GameState.niebla = niebla_antes
	_devolver_estado(antes)
	assert_true(preparo, "se prepara")
	assert_true(se_ve, "y lo que ya conocía se ve")


func test_lo_avistado_se_guarda_y_se_suma() -> void:
	var antes := _guardar_estado()
	var sim := _sim()
	GameState.discovered = {SITIO: true}
	GameState.avistados = {201: true, 202: true}
	Guardado.borrar()
	Guardado.guardar(sim)
	var leido := Guardado.leer()
	var sitios := SiteSet.new()
	var casa := Site.new()
	casa.id = SITIO
	sitios.sites.append(casa)
	GameState.avistados = {203: true}
	var preparado := Guardado.preparar_la_escena(leido, sitios)
	var tras_cargar := GameState.avistados.duplicate()
	_devolver_estado(antes)
	Guardado.borrar()
	assert_eq((leido.get("avistado", []) as Array).size(), 2, "se guardan los dos avistados")
	assert_true(preparado, "se carga")
	assert_true(tras_cargar.has(201) and tras_cargar.has(202) and tras_cargar.has(203),
		"y al cargar se suman a lo que ya había: %s" % str(tras_cargar.keys()))

