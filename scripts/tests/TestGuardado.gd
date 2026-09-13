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
	sim.store.add(Materia.Kind.PIEL, 10.0)
	sim.store.add(Materia.Kind.LENA, 200.0)
	assert_true(sim.expedicion.mandar(3, 1000), "sale la expedición")
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

func test_dos_mapas_no_se_pisan() -> void:
	# LO QUE LE HIZO PERDER LA PARTIDA AL USUARIO: había UN guardado, y entrar
	# en otro sitio empezaba una partida que al volver lo pisaba. Ahora cada
	# mapa tiene el suyo.
	Guardado.borrar()
	var antes := _guardar_estado(101)
	var a := _sim()
	a.day = 11
	Guardado.guardar(a)
	_guardar_estado(202)
	var b := _sim()
	b.day = 22
	Guardado.guardar(b)
	_devolver_estado(antes)
	assert_eq(int(Guardado.leer(101).get("jornada", -1)), 11, "el mapa A sigue en su jornada")
	assert_eq(int(Guardado.leer(202).get("jornada", -1)), 22, "y el B en la suya")
	Guardado.borrar()


func test_el_ultimo_mapa_jugado_se_recuerda() -> void:
	Guardado.borrar()
	var antes := _guardar_estado(101)
	Guardado.guardar(_sim())
	_guardar_estado(202)
	Guardado.guardar(_sim())
	_devolver_estado(antes)
	assert_eq(Guardado.ultimo_sitio(), 202, "el último en guardarse es el de volver")
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
