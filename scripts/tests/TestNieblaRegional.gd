class_name TestNieblaRegional
extends TestCase
## La niebla del mapa regional y el pasillo de una expedición: SISTEMAS §4,
## «Plan técnico: rumbo y niebla».
##
## La niebla de las pruebas es pequeña y de filas geográficas: un grado de lado a
## la latitud de Cantabria, en celdas de ~0,01°. Las cifras de los criterios se
## miden en celdas de la máscara, que es lo que la spec pide.


func suite_name() -> String:
	return "NieblaRegional"


## Un recuadro de un grado alrededor de Cantabria, con celdas de ~1 km.
func _niebla() -> NieblaRegional:
	return NieblaRegional.new(100, 100, 43.8, 42.8, -5.0, -4.0, true)


func test_empieza_toda_en_niebla() -> void:
	var niebla := _niebla()
	assert_eq(niebla.cuantas(), 0, "no se ha visto nada")
	assert_false(niebla.levantada(-4.5, 43.3), "ni el centro")


func test_un_recuadro_levanta_sus_celdas_y_nada_lejos() -> void:
	var niebla := _niebla()
	var nuevas := niebla.levantar_recuadro(-4.5, 43.3, 4096.0)
	assert_true(nuevas > 0, "levanta algo")
	assert_true(niebla.levantada(-4.5, 43.3), "el centro")
	assert_true(niebla.levantada(-4.5 + 0.02, 43.3 + 0.015), "y dentro del recuadro")
	assert_false(niebla.levantada(-4.5 + 0.1, 43.3), "pero no a 8 km")
	# Por exceso, pero no mucho: 4,1 km de lado en celdas de ~0,81 x 1,11 km son
	# 6 x 4 celdas enteras, y con el margen de media diagonal no pasan de 9 x 7.
	assert_lt(float(nuevas), 64.0, "no levanta de más: %d celdas" % nuevas)
	assert_eq(niebla.levantar_recuadro(-4.5, 43.3, 4096.0), 0, "levantar dos veces no suma")


func test_un_circulo_llega_hasta_su_radio() -> void:
	var niebla := _niebla()
	niebla.levantar_circulo(-4.5, 43.3, 1400.0)
	assert_true(niebla.levantada(-4.5, 43.3 + 0.009), "a un kilómetro al norte")
	assert_false(niebla.levantada(-4.5, 43.3 + 0.04), "a cuatro, no")


func test_las_capas_van_aparte() -> void:
	var niebla := _niebla()
	niebla.levantar_circulo(-4.5, 43.3, 1000.0, NieblaRegional.RECORRIDA)
	assert_true(niebla.levantada(-4.5, 43.3, NieblaRegional.RECORRIDA), "recorrida")
	assert_false(niebla.levantada(-4.5, 43.3, NieblaRegional.VISTA), "no la hace vista")


func test_la_fraccion_es_celdas_entre_celdas() -> void:
	var niebla := _niebla()
	var nuevas := niebla.levantar_recuadro(-4.5, 43.3, 4096.0)
	assert_near(niebla.fraccion(), float(nuevas) / 10000.0, 0.000001, "celdas levantadas entre todas")


func test_guardar_y_sumar() -> void:
	var niebla := _niebla()
	niebla.levantar_circulo(-4.5, 43.3, 3000.0)
	var otra := _niebla()
	otra.levantar_circulo(-4.2, 43.5, 3000.0)
	assert_true(otra.sumar_datos(niebla.a_datos()), "cuadra con el mismo recuadro")
	assert_true(otra.levantada(-4.5, 43.3), "trae lo de la guardada")
	assert_true(otra.levantada(-4.2, 43.5), "sin olvidar lo suyo")
	assert_eq(otra.cuantas(), niebla.cuantas() + _niebla_con(-4.2, 43.5).cuantas(),
		"y son las dos juntas")
	var pequena := NieblaRegional.new(10, 10, 43.8, 42.8, -5.0, -4.0, true)
	assert_false(pequena.sumar_datos(niebla.a_datos()), "otro recuadro no se suma")


func _niebla_con(lon: float, lat: float) -> NieblaRegional:
	var niebla := _niebla()
	niebla.levantar_circulo(lon, lat, 3000.0)
	return niebla


func test_la_imagen_es_la_capa() -> void:
	var niebla := _niebla()
	niebla.levantar_circulo(-4.5, 43.3, 2000.0)
	var imagen := niebla.imagen()
	assert_eq(imagen.get_width(), 100, "del ancho de la rejilla")
	var blancas := 0
	for z in range(100):
		for x in range(100):
			if imagen.get_pixel(x, z).r > 0.5:
				blancas += 1
	assert_eq(blancas, niebla.cuantas(), "un píxel blanco por celda levantada")


func test_la_comarca_tiene_la_rejilla_del_relieve() -> void:
	var niebla := NieblaRegional.de_la_comarca()
	var relieve := load("res://data/dem/cantabria_region.res") as HeightmapData
	assert_eq(niebla.ancho, relieve.width, "tantas columnas como el relieve")
	assert_eq(niebla.alto, relieve.height, "y tantas filas")
	# Filas Mercator: un punto conocido cae en su fila de relieve.
	niebla.levantar_circulo(-4.0, 43.3, 200.0)
	var fila := int(floor(relieve.v_for_lat(43.3) * float(relieve.height)))
	var columna := int(floor(relieve.u_for_lon(-4.0) * float(relieve.width)))
	assert_true(niebla.celdas[fila * relieve.width + columna] & NieblaRegional.VISTA != 0,
		"la celda del punto, en la fila Mercator que le toca")


# --- el pasillo ----------------------------------------------------------------

## Un punto a `avance` metros por el rumbo y `lateral` a su derecha.
func _punto(pasillo: Pasillo, avance: float, lateral: float) -> Vector2:
	var este := sin(deg_to_rad(pasillo.rumbo))
	var norte := cos(deg_to_rad(pasillo.rumbo))
	var x := este * avance + norte * lateral
	var z := norte * avance - este * lateral
	var coseno := cos(deg_to_rad(pasillo.lat))
	return Vector2(pasillo.lon + x / (Viaje.METROS_POR_GRADO * coseno),
		pasillo.lat + z / Viaje.METROS_POR_GRADO)


func _dentro(pasillo: Pasillo, punto: Vector2) -> bool:
	return pasillo.contiene(punto.x, punto.y)


func test_las_jornadas_van_de_4_a_24_de_2_en_2() -> void:
	assert_true(Pasillo.jornadas_validas(4), "cuatro")
	assert_true(Pasillo.jornadas_validas(24), "veinticuatro")
	assert_false(Pasillo.jornadas_validas(2), "dos no")
	assert_false(Pasillo.jornadas_validas(13), "impares no")
	assert_false(Pasillo.jornadas_validas(26), "más de veinticuatro no")


func test_el_pasillo_contiene_lo_de_dentro_y_nada_de_fuera() -> void:
	# El catálogo puesto a mano a los dos lados, que pide el criterio.
	var pasillo := Pasillo.trazar(-4.1, 43.2, 90.0, 12)
	assert_gt(pasillo.largo_m, 5000.0, "seis jornadas de ida llegan lejos: %.0f m" % pasillo.largo_m)
	var mitad := pasillo.largo_m * 0.5
	assert_true(_dentro(pasillo, _punto(pasillo, mitad, 0.0)), "en el eje")
	assert_true(_dentro(pasillo, _punto(pasillo, mitad, 650.0)), "a 650 m a la derecha")
	assert_true(_dentro(pasillo, _punto(pasillo, mitad, -650.0)), "y a la izquierda")
	assert_false(_dentro(pasillo, _punto(pasillo, mitad, 760.0)), "a 760 m, fuera")
	assert_false(_dentro(pasillo, _punto(pasillo, mitad, -760.0)), "por los dos lados")
	assert_false(_dentro(pasillo, _punto(pasillo, -800.0, 0.0)), "detrás del campamento, fuera")
	assert_false(_dentro(pasillo, _punto(pasillo, pasillo.largo_m + 800.0, 0.0)),
		"más allá de donde se da la vuelta, fuera")


func test_rumbos_opuestos_no_comparten_nada_lejos_de_casa() -> void:
	var al_este := Pasillo.trazar(-4.1, 43.2, 90.0, 12)
	var al_oeste := Pasillo.trazar(-4.1, 43.2, 270.0, 12)
	var compartidos := 0
	for i in range(1, 20):
		var p := _punto(al_este, al_este.largo_m * float(i) / 20.0, 0.0)
		var q := _punto(al_oeste, al_oeste.largo_m * float(i) / 20.0, 0.0)
		if al_oeste.contiene(p.x, p.y) and float(i) / 20.0 * al_este.largo_m > 2.0 * Pasillo.MEDIO_ANCHO_M:
			compartidos += 1
		if al_este.contiene(q.x, q.y) and float(i) / 20.0 * al_oeste.largo_m > 2.0 * Pasillo.MEDIO_ANCHO_M:
			compartidos += 1
	assert_eq(compartidos, 0, "lo del este no lo ve quien va al oeste, ni al revés")


func test_el_pasillo_se_para_en_la_costa() -> void:
	# Hacia el norte desde el interior, la ida se acaba en el mar de la época.
	var pasillo := Pasillo.trazar(-4.1, 43.2, 0.0, 24, Viaje.METROS_POR_HORA_EN_LLANO, -120.0)
	assert_gt(Viaje.cota(pasillo.fin_lat, pasillo.fin_lon), -120.0 - 1.0,
		"donde se da la vuelta no es mar: %.0f m" % Viaje.cota(pasillo.fin_lat, pasillo.fin_lon))
	var mas_alla := _punto(pasillo, pasillo.largo_m + 600.0, 0.0)
	assert_lt(Viaje.cota(mas_alla.y, mas_alla.x), -120.0, "y un poco más allá sí")


func test_la_montana_acorta_la_ida() -> void:
	var pasillo := Pasillo.trazar(-4.1, 43.2, 180.0, 12)
	var en_llano := 6.0 * SettlementSim.HORAS_UTILES * Viaje.METROS_POR_HORA_EN_LLANO
	assert_lt(pasillo.largo_m, en_llano, "hacia la cordillera se llega menos lejos que en llano")


func test_la_niebla_que_levanta_es_la_del_mismo_pasillo() -> void:
	# Toda celda con un punto dentro del pasillo queda levantada: la flecha y el
	# descubrimiento no pueden discrepar.
	var pasillo := Pasillo.trazar(-4.1, 43.2, 45.0, 8)
	var niebla := NieblaRegional.de_la_comarca()
	var nuevas := pasillo.levantar_en(niebla, NieblaRegional.VISTA)
	assert_gt(float(nuevas), 0.0, "levanta celdas")
	var dentro_sin_levantar := 0
	var levantadas_lejos := 0
	for i in range(0, 41):
		for j in range(-10, 11):
			var p := _punto(pasillo, pasillo.largo_m * float(i) / 40.0, 140.0 * float(j))
			var levantada := niebla.levantada(p.x, p.y)
			if pasillo.contiene(p.x, p.y) and not levantada:
				dentro_sin_levantar += 1
			if pasillo.distancia_m(p.x, p.y) > 400.0 and levantada:
				levantadas_lejos += 1
	assert_eq(dentro_sin_levantar, 0, "nada de dentro se queda en niebla")
	assert_eq(levantadas_lejos, 0, "y no se levanta nada a más de 400 m del borde")


# --- levantar la niebla en la partida -------------------------------------------

var _estado: Array = []


func _guardar_estado() -> void:
	_estado = [GameState.niebla, GameState.discovered.duplicate(), GameState.home,
		GameState.started, GameState.avistados.duplicate()]


func _devolver_estado() -> void:
	GameState.niebla = _estado[0]
	GameState.discovered = _estado[1]
	GameState.home = _estado[2]
	GameState.started = _estado[3]
	GameState.avistados = _estado[4]


func test_al_empezar_se_ve_el_recuadro_del_primer_campamento() -> void:
	_guardar_estado()
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	GameState.begin(sitios)
	var levantadas := GameState.niebla.cuantas()
	var solo_recuadro := NieblaRegional.de_la_comarca()
	var del_recuadro := solo_recuadro.levantar_recuadro(GameState.home.lon,
		GameState.home.lat, float(Expedition.local_size_m))
	var recorrida := GameState.niebla.cuantas(NieblaRegional.RECORRIDA)
	_devolver_estado()
	assert_gt(float(levantadas), 0.0, "algo se ve")
	assert_eq(levantadas, del_recuadro, "exactamente las celdas del recuadro: %d" % levantadas)
	assert_eq(recorrida, 0, "y nada recorrido por expediciones")


func test_una_simulacion_dirigida_levanta_en_la_barrera() -> void:
	_guardar_estado()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {}
	var sim := SettlementSim.new()
	var reloj := RelojDeLaPartida.new()
	reloj.dirigir(sim)
	var forma := {"forma": "circulo", "lon": -4.1, "lat": 43.2, "radio": 1400.0}
	sim.levantar_niebla(forma)
	var antes := GameState.niebla.levantada(-4.1, 43.2)
	var en_cola := sim.niebla_por_levantar.size()
	reloj._un_paso_a_todos()
	var despues := GameState.niebla.levantada(-4.1, 43.2)
	var cola_despues := sim.niebla_por_levantar.size()
	_devolver_estado()
	reloj.free()
	sim.free()
	assert_false(antes, "dentro del paso no toca la niebla de la partida")
	assert_eq(en_cola, 1, "espera en la cola")
	assert_true(despues, "la barrera la levanta")
	assert_eq(cola_despues, 0, "y vacía la cola")


## Lo que se descubre es lo de dentro, Y SOLO SI LA FORMA LO PIDE.
##
## **Esta prueba pedía lo contrario hasta el 2026-09-14**: se llamaba «levantar
## descubre lo de dentro y nada de fuera» y exigía que levantar niebla
## descubriera, sin más, todo sitio que quedara debajo —«lo que se ve, se
## descubre»—. Era la regla de entonces y estaba bien comprobada; lo que estaba
## mal era la regla, porque entrar en un mapa levanta un recuadro y con eso se
## regalaban los sitios vecinos. Decisión del usuario: descubren las
## expediciones. Se conserva la comprobación de «justo los de dentro» porque esa
## mitad sigue valiendo, ahora sobre una forma que sí pide descubrir.
func test_lo_que_descubre_una_forma_que_lo_pide_es_justo_lo_de_dentro() -> void:
	_guardar_estado()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {}
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var centro: Site = sitios.sites[0]
	var radio := 6000.0
	var nuevos := GameState.levantar_niebla({"forma": "circulo", "lon": centro.lon,
		"lat": centro.lat, "radio": radio, "descubre": true}, sitios)
	var mal := 0
	var coseno := cos(deg_to_rad(centro.lat))
	for s: Site in sitios.sites:
		var x := (s.lon - centro.lon) * Viaje.METROS_POR_GRADO * coseno
		var z := (s.lat - centro.lat) * Viaje.METROS_POR_GRADO
		var dentro := x * x + z * z <= radio * radio
		if dentro != GameState.is_discovered(s):
			mal += 1
		if GameState.is_discovered(s) and not GameState.niebla.levantada(s.lon, s.lat):
			mal += 1
	var cuantos := GameState.discovered.size()
	_devolver_estado()
	assert_eq(nuevos, cuantos, "devuelve los nuevos")
	assert_eq(mal, 0, "descubre justo los de dentro, y ninguno queda bajo niebla")


# --- la cumbre ------------------------------------------------------------------

func _terreno_del_sitio_56() -> TerrainGenerator:
	var terreno := TerrainGenerator.new()
	terreno.heightmap = load("res://data/dem/local/site_56.res") as HeightmapData
	terreno.meters_per_unit = 1.0
	terreno.terrain_size = Vector2i(4096, 4096)
	terreno.heightmap_region_offset = Vector2(200.0, 200.0)
	return terreno


func test_del_mundo_a_la_comarca_y_de_vuelta() -> void:
	var terreno := _terreno_del_sitio_56()
	var geo := terreno.world_to_geo(Vector3(1234.0, 0.0, 3210.0))
	var vuelta := terreno.geo_to_world(geo.x, geo.y)
	terreno.free()
	# A menos de cinco centímetros: la latitud vuelve por bisección y se queda a
	# 1,7 cm, que en una niebla de celdas de 111 m no se ve.
	assert_near(vuelta.x, 1234.0, 0.05, "la x vuelve")
	assert_near(vuelta.z, 3210.0, 0.05, "y la z")


func test_una_cumbre_junto_al_borde_levanta_niebla_fuera_del_recuadro() -> void:
	var terreno := _terreno_del_sitio_56()
	var sim := SettlementSim.new()
	sim._terrain = terreno
	sim.chronicle = Chronicle.new()
	sim.knowledge = BandKnowledge.new()
	sim.knowledge.setup(32, 32, Vector2(4096.0, 4096.0))
	var persona := Inhabitant.new()
	persona.given_name = "Cima"
	persona.position = Vector3(4000.0, 0.0, 2048.0)
	sim.people.append(persona)
	_guardar_estado()
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {}
	sim.cumbres._do_ascent(persona)
	# 1 000 m más allá del borde este del recuadro, a la altura de la cumbre.
	var fuera := terreno.world_to_geo(Vector3(5000.0, 0.0, 2048.0))
	var lejos := terreno.world_to_geo(Vector3(6500.0, 0.0, 2048.0))
	var visto := GameState.niebla.levantada(fuera.x, fuera.y)
	var visto_lejos := GameState.niebla.levantada(lejos.x, lejos.y)
	_devolver_estado()
	sim.free()
	terreno.free()
	assert_true(visto, "a un kilómetro fuera del recuadro se ve")
	assert_false(visto_lejos, "a dos kilómetros y medio de la cumbre, no")


# --- bajo la niebla no se elige nada ---------------------------------------------

func test_un_sitio_descubierto_bajo_la_niebla_no_se_ve() -> void:
	_guardar_estado()
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio: Site = sitios.sites[0]
	GameState.niebla = NieblaRegional.de_la_comarca()
	GameState.discovered = {sitio.id: true}
	var bajo_la_niebla := GameState.se_ve(sitio)
	GameState.niebla.levantar_circulo(sitio.lon, sitio.lat, 500.0)
	var levantada := GameState.se_ve(sitio)
	GameState.discovered = {}
	var sin_descubrir := GameState.se_ve(sitio)
	_devolver_estado()
	assert_false(bajo_la_niebla, "descubierto pero bajo la niebla, no se ve")
	assert_true(levantada, "con la niebla levantada, sí")
	assert_false(sin_descubrir, "y sin descubrir, tampoco aunque no haya niebla")


func test_la_lista_del_mapa_regional_es_la_de_lo_que_se_ve() -> void:
	# `RegionMap._refresh_sites` y la ficha de mover gente preguntan lo mismo:
	# `GameState.se_ve`. Aquí se comprueba que no se pregunta otra cosa.
	var mapa := FileAccess.get_file_as_string("res://scripts/region/RegionMap.gd")
	var panel := FileAccess.get_file_as_string("res://scripts/ui/PanelCampamentos.gd")
	assert_true(mapa.contains("GameState.se_ve(site)"), "el mapa regional filtra por lo que se ve")
	assert_false(mapa.contains("GameState.is_discovered(site)"), "y no sólo por lo descubierto")
	assert_true(panel.contains("GameState.se_ve(sitio)"), "y los destinos de la ficha, igual")


# --- la ficha de rumbo y su flecha ------------------------------------------------

func _banda_en(sitio: Site) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 400.0)
	sim.store.add(Materia.Kind.PIEL_CURTIDA, 10.0)
	sim.store.add(Materia.Kind.LENA, 200.0)
	for i in range(6):
		var p := Inhabitant.new()
		p.id = i
		p.given_name = "P%d" % i
		p.age_group = Inhabitant.Age.ADULTO
		sim.people.append(p)
	sim.sitio = sitio
	return sim


func test_la_flecha_cubre_el_mismo_pasillo_que_se_descubre() -> void:
	# EL CRITERIO DE INTERFAZ §4: la máscara de la flecha y la del pasillo que
	# recorre la expedición mandada desde la ficha, comparadas celda a celda.
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio: Site = sitios.available_in(-120.0, Site.Era.PALEOLITICO)[0]
	var sim := _banda_en(sitio)
	var ficha := FichaDeRumbo.new()
	var dibujados: Array[Pasillo] = []
	ficha.cambiada.connect(func(recorrido: Pasillo) -> void: dibujados.append(recorrido))
	# Apunta sola al primero de los ocho que se ofrecen: desde el 2026-09-16 no se
	# sale hacia otro.
	ficha.abrir(sim, "prueba")
	ficha.elegir_jornadas(8)
	ficha.elegir_jornadas(13)
	var sin_bloqueo := ficha.bloqueo()
	var salio := ficha.mandar()
	var de_la_flecha := NieblaRegional.de_la_comarca()
	dibujados.back().levantar_en(de_la_flecha, NieblaRegional.VISTA)
	var de_la_expedicion := NieblaRegional.de_la_comarca()
	Pasillo.de_datos(sim.expedicion.pasillo).levantar_en(de_la_expedicion, NieblaRegional.VISTA)
	var jornadas := sim.expedicion.jornadas
	ficha.free()
	sim.free()
	assert_eq(dibujados.size(), 2, "la flecha se rehace al apuntar y al cambiar las jornadas, no con jornadas imposibles")
	assert_eq(sin_bloqueo, "", "con tres marcados y despensa, nada lo impide")
	assert_true(salio, "y sale")
	assert_eq(jornadas, 8, "con las jornadas elegidas")
	assert_gt(float(de_la_flecha.cuantas()), 0.0, "la flecha cubre algo")
	assert_true(de_la_flecha.celdas == de_la_expedicion.celdas, "y es exactamente el pasillo que recorre")


func test_la_ficha_dice_por_que_no_se_puede_mandar() -> void:
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sim := _banda_en(sitios.available_in(-120.0, Site.Era.PALEOLITICO)[0])
	var ficha := FichaDeRumbo.new()
	ficha.abrir(sim, "prueba")
	ficha.marcar(ficha.marcados[0], false)
	var pocos := ficha.bloqueo()
	var salio := ficha.mandar()
	ficha.marcar(5, true)
	sim.store.take(Materia.Kind.PIEL_CURTIDA, 10.0)
	var sin_pieles := ficha.bloqueo()
	ficha.free()
	sim.free()
	assert_true(pocos.contains("hacen falta"), "con dos, lo dice: %s" % pocos)
	assert_false(salio, "y no manda")
	assert_true(sin_pieles.contains("pieles"), "sin tiendas, lo dice: %s" % sin_pieles)


# --- la visita ---------------------------------------------------------------------

func test_la_visita_ve_en_su_mapa_solo_lo_recorrido() -> void:
	var campamento := Campamento.new()
	campamento.terrain = _terreno_del_sitio_56()
	campamento.knowledge = BandKnowledge.new()
	campamento.knowledge.setup(64, 64, Vector2(4096.0, 4096.0))
	var niebla := NieblaRegional.de_la_comarca()
	var dentro := campamento.terrain.world_to_geo(Vector3(1000.0, 0.0, 1000.0))
	# La capa vista entera, como la deja visitar el mapa: no debe contar.
	var centro := campamento.terrain.world_to_geo(Vector3(2048.0, 0.0, 2048.0))
	niebla.levantar_recuadro(centro.x, centro.y, 4096.0, NieblaRegional.VISTA)
	niebla.levantar_circulo(dentro.x, dentro.y, 400.0, NieblaRegional.RECORRIDA)
	var vistas := campamento.ver_lo_recorrido(niebla)
	var en := campamento.knowledge.explored_at(Vector3(1000.0, 0.0, 1000.0))
	var lejos := campamento.knowledge.explored_at(Vector3(3000.0, 0.0, 3000.0))
	campamento.terrain.free()
	campamento.free()
	assert_gt(float(vistas), 0.0, "algo del valle queda visto")
	assert_eq(en, 1.0, "donde pasó una expedición")
	assert_eq(lejos, 0.0, "y no donde no pasó nadie, aunque el mapa se haya visitado")


## Empezar partida deja UN solo sitio descubierto: el de casa.
##
## Queja del usuario del 2026-09-14, «en una nueva partida sólo debe aparecer 1
## sitio en el mapa regional». Levantar el recuadro de casa descubría de paso a
## todos los vecinos que cayeran dentro, que en el mapa real son varios.
func test_al_empezar_solo_esta_descubierto_el_sitio_de_casa() -> void:
	_guardar_estado()
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	GameState.begin(sitios)
	var cuantos := GameState.discovered.size()
	var es_el_de_casa := GameState.discovered.has(GameState.home.id)
	_devolver_estado()
	assert_eq(cuantos, 1, "sólo la cueva de casa, y había %d descubiertos" % cuantos)
	assert_true(es_el_de_casa, "y el descubierto es el de casa")


## Volver a un sitio ya descubierto no descubre a sus vecinos.
##
## La otra mitad de la misma queja: «cuando el jugador visita un punto del mapa
## regional que ha descubierto, al volver le han aparecido puntos nuevos». Entrar
## en un mapa levanta el recuadro de ese sitio —[Campamentos] y [DemoMain]—, y
## ese recuadro descubría lo que hubiera debajo.
func test_entrar_en_un_mapa_levanta_niebla_pero_no_descubre_nada() -> void:
	_guardar_estado()
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	GameState.begin(sitios)
	# Un sitio cualquiera que NO sea el de casa, y se «visita».
	var otro: Site = null
	for s: Site in sitios.sites:
		if s.id != GameState.home.id:
			otro = s
			break
	var antes := GameState.discovered.size()
	var antes_de_niebla := GameState.niebla.cuantas()
	var nuevos := GameState.levantar_niebla({"forma": "recuadro", "lon": otro.lon,
		"lat": otro.lat, "lado": float(Expedition.local_size_m)}, sitios)
	var despues := GameState.discovered.size()
	var despues_de_niebla := GameState.niebla.cuantas()
	_devolver_estado()
	assert_eq(nuevos, 0, "visitar no descubre sitios")
	assert_eq(despues, antes, "y no cambia la cuenta de descubiertos")
	assert_gt(float(despues_de_niebla), float(antes_de_niebla),
		"pero la niebla sí se levanta")


## La expedición sí descubre: es la única que lo pide.
func test_solo_la_expedicion_descubre() -> void:
	_guardar_estado()
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	GameState.begin(sitios)
	var pasillo := Pasillo.trazar(GameState.home.lon, GameState.home.lat, 90.0, 24)
	var sin_pedirlo := GameState.levantar_niebla({"forma": "pasillo",
		"pasillo": pasillo.a_datos()}, sitios)
	var pidiendolo := GameState.levantar_niebla({"forma": "pasillo",
		"pasillo": pasillo.a_datos(), "descubre": true}, sitios)
	_devolver_estado()
	assert_eq(sin_pedirlo, 0, "el mismo pasillo sin pedir descubrir no descubre")
	assert_gt(float(pidiendolo), 0.0,
		"y pidiéndolo descubre los sitios del pasillo")


## La malla del mapa regional se busca en la caché aunque el relieve sea una copia: sin
## ruta propia no se buscaba nunca y cada viaje rehacía 24,6 s de malla (INTERFAZ §9).
func test_la_malla_regional_tiene_caché_aunque_el_relieve_sea_una_copia() -> void:
	var terreno := TerrainGenerator.new()
	terreno.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
	terreno.heightmap = HeightmapData.new()
	var sin_origen := terreno.malla._cache_base_path()
	terreno.origen_de_la_cache = "res://data/dem/cantabria_region.res"
	terreno.sufijo_de_la_cache = (load("res://scripts/region/RegionMap.gd") as GDScript).call("sufijo_de_la_cache", -120.0)
	var paleolitico := terreno.malla._cache_base_path()
	terreno.sufijo_de_la_cache = (load("res://scripts/region/RegionMap.gd") as GDScript).call("sufijo_de_la_cache", 0.0)
	var hoy := terreno.malla._cache_base_path()
	terreno.free()
	assert_eq(sin_origen, "", "una copia sin origen no tiene dónde guardarse")
	assert_true(paleolitico.begins_with("res://data/dem/cantabria_region_mar-120"), "con origen, sí: %s" % paleolitico)
	assert_true(paleolitico != hoy, "y el mar de otra época es otra caché")


# ------------------------------------------------ lo avistado (2026-09-16) --

func test_una_simulacion_dirigida_avista_en_la_barrera() -> void:
	_guardar_estado()
	GameState.avistados = {}
	GameState.discovered = {}
	var sim := SettlementSim.new()
	var reloj := RelojDeLaPartida.new()
	reloj.dirigir(sim)
	var lejos := Site.new()
	lejos.id = 424242
	sim.avistar(lejos)
	var antes := GameState.avistado(lejos)
	reloj._un_paso_a_todos()
	var despues := GameState.avistado(lejos)
	var cola := sim.avistamientos.size()
	_devolver_estado()
	reloj.free()
	sim.free()
	assert_false(antes, "dentro del paso no toca la partida")
	assert_true(despues, "la barrera lo apunta")
	assert_eq(cola, 0, "y vacía la cola")


func test_descubrir_un_avistado_lo_deja_como_cualquier_otro() -> void:
	_guardar_estado()
	GameState.avistados = {}
	GameState.discovered = {}
	var s := Site.new()
	s.id = 424243
	GameState.avistar(s)
	var avistado := GameState.avistado(s)
	GameState.discover(s)
	var tras_descubrirlo := GameState.avistado(s)
	_devolver_estado()
	assert_true(avistado, "avistado y sin descubrir")
	assert_false(tras_descubrirlo, "descubierto ya no es un avistado")


func test_un_avistado_se_dibuja_pero_no_se_pincha_ni_sale_en_listas() -> void:
	_guardar_estado()
	GameState.started = true
	GameState.niebla = _niebla()
	var visto := Site.new()
	visto.id = 424250
	visto.lon = -4.5
	visto.lat = 43.3
	var avistado := Site.new()
	avistado.id = 424251
	avistado.lon = -4.2
	avistado.lat = 43.5
	var nada := Site.new()
	nada.id = 424252
	nada.lon = -4.3
	nada.lat = 43.4
	GameState.discovered = {visto.id: true}
	GameState.niebla.levantar_recuadro(visto.lon, visto.lat, 4096.0)
	GameState.avistados = {avistado.id: true}
	# `RegionMap` no tiene `class_name`: se llama por su script, como en la prueba de la caché.
	var repartidos: Dictionary = (load("res://scripts/region/RegionMap.gd") as GDScript).call(
		"sitios_que_se_dibujan", [visto, avistado, nada] as Array[Site])
	var bajo_la_niebla := not GameState.niebla.levantada(avistado.lon, avistado.lat)
	_devolver_estado()
	assert_true(bajo_la_niebla, "el avistado está bajo la niebla")
	assert_eq(repartidos["vistos"], [visto] as Array[Site], "se pincha y sale en listas sólo el descubierto")
	assert_eq(repartidos["avistados"], [avistado] as Array[Site], "el avistado se dibuja aparte")


# ------------------------------------------------------- el viento (2026-09-16) --
#
# Movía las nubes de la niebla del mapa regional, retirada el 2026-09-17. Lo que queda
# mueve la lluvia y la hierba (`WorldEnvironmentSetup`).

func test_el_viento_corre_con_el_reloj_de_la_partida_y_no_con_el_de_pared() -> void:
	var a_las_siete := Viento.recorrido(3, 7.0, 120.0)
	var otra_vez := Viento.recorrido(3, 7.0, 120.0)
	var a_las_ocho := Viento.recorrido(3, 8.0, 120.0)
	var al_dia_siguiente := Viento.recorrido(4, 7.0, 120.0)
	assert_eq(a_las_siete, otra_vez, "la misma hora, el mismo recorrido: en pausa no se mueven")
	assert_gt(a_las_ocho, a_las_siete, "una hora después, más")
	assert_gt(al_dia_siguiente, a_las_ocho, "y al día siguiente, más todavía")
	# A x5 la partida da cinco veces más horas por segundo de reloj: el viento las sigue.
	assert_near(Viento.recorrido(3, 12.0, 120.0) - a_las_siete,
		(Viento.recorrido(3, 8.0, 120.0) - a_las_siete) * 5.0, 0.001,
		"cinco horas corren cinco veces lo que una")
