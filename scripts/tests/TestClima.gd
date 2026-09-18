class_name TestClima
extends TestCase
## El clima en pantalla: GRAFICOS §7.4. Lo que se le pide a la vista, el suelo que se moja
## y se nieva, la niebla de valle, la condensación y el interruptor.


func suite_name() -> String:
	# «Clima» ya es la suite del tiempo de la partida (`TestWeather`).
	return "ClimaEnPantalla"


var _nodos: Array[Node] = []


## El ajuste «Clima» con que empezó la suite: otras pruebas lo dejan apagado —Bajo, en
## `TestConfiguracion`—, y aquí se enciende en cada prueba y se devuelve al acabar. Sin esto
## la vista salía apagada en la suite entera y encendida con `SOLO`.
var _clima_de_antes: Variant = null


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()
	if _clima_de_antes == null:
		_clima_de_antes = Configuracion.graficos.get("clima", true)
	Configuracion.graficos["clima"] = true


func run() -> Array:
	var resultado := super.run()
	if _clima_de_antes != null:
		Configuracion.graficos["clima"] = _clima_de_antes
	return resultado


func test_las_tres_lluvias_se_distinguen_por_cifras() -> void:
	var orbayu := ClimaEnPantalla.lluvia(Weather.Kind.ORBAYU)
	var lluvia := ClimaEnPantalla.lluvia(Weather.Kind.LLUVIA)
	var temporal := ClimaEnPantalla.lluvia(Weather.Kind.TEMPORAL)
	for clave: String in ["cantidad", "tamano", "inclinacion"]:
		assert_lt(float(orbayu[clave]), float(lluvia[clave]), "%s: del orbayu a la lluvia, más" % clave)
		assert_lt(float(lluvia[clave]), float(temporal[clave]), "%s: de la lluvia al temporal, más" % clave)
	assert_eq(int(ClimaEnPantalla.lluvia(Weather.Kind.DESPEJADO)["cantidad"]), 0, "despejado no llueve")
	assert_eq(int(ClimaEnPantalla.lluvia(Weather.Kind.NIEVE)["cantidad"]), 0, "y con nieve cae nieve, no agua")


func test_el_suelo_se_moja_mientras_llueve_y_se_seca_al_parar_sin_saltos() -> void:
	var suelo := ClimaEnPantalla.new()
	var subiendo: Array[float] = []
	for h in range(6):
		suelo.una_hora(Weather.Kind.LLUVIA)
		subiendo.append(suelo.mojado)
	var bajando: Array[float] = []
	for h in range(24):
		suelo.una_hora(Weather.Kind.DESPEJADO)
		bajando.append(suelo.mojado)
	var salto := 0.0
	for i in range(1, subiendo.size()):
		assert_true(subiendo[i] >= subiendo[i - 1], "mientras llueve no baja")
		salto = maxf(salto, subiendo[i] - subiendo[i - 1])
	for i in range(1, bajando.size()):
		assert_true(bajando[i] <= bajando[i - 1], "al parar no sube")
		salto = maxf(salto, bajando[i - 1] - bajando[i])
	assert_near(subiendo.back(), 1.0, 0.001, "tras seis horas de lluvia, mojado del todo")
	assert_gt(bajando[5], 0.5, "seis horas después todavía moja")
	assert_near(bajando.back(), 0.0, 0.001, "y al día siguiente, seco")
	assert_lt(salto, 0.35, "sin saltos: como mucho %.2f por hora" % salto)


func test_el_orbayu_moja_a_medias_y_el_temporal_de_golpe() -> void:
	var orbayu := ClimaEnPantalla.new()
	var temporal := ClimaEnPantalla.new()
	for h in range(12):
		orbayu.una_hora(Weather.Kind.ORBAYU)
	temporal.una_hora(Weather.Kind.TEMPORAL)
	assert_near(orbayu.mojado, 0.6, 0.001, "el orbayu no pasa de 0,6")
	assert_near(temporal.mojado, 1.0, 0.001, "el temporal moja del todo en una hora")


func test_la_nieve_cuaja_y_se_va_poco_a_poco() -> void:
	var suelo := ClimaEnPantalla.new()
	for h in range(8):
		suelo.una_hora(Weather.Kind.NIEVE)
	var cuajada := suelo.nieve
	for h in range(24):
		suelo.una_hora(Weather.Kind.DESPEJADO)
	var al_dia_siguiente := suelo.nieve
	for h in range(48):
		suelo.una_hora(Weather.Kind.DESPEJADO)
	assert_near(cuajada, 1.0, 0.001, "ocho horas nevando la cuajan")
	assert_gt(al_dia_siguiente, 0.3, "al día siguiente de parar todavía se ve")
	assert_near(suelo.nieve, 0.0, 0.001, "y en tres días se ha ido")


func test_asentar_deja_el_suelo_del_tiempo_que_hace() -> void:
	var suelo := ClimaEnPantalla.new()
	suelo.asentar(Weather.Kind.TEMPORAL)
	var con_temporal := [suelo.mojado, suelo.nieve]
	suelo.asentar(Weather.Kind.NIEVE)
	var con_nieve := [suelo.mojado, suelo.nieve]
	assert_eq(con_temporal, [1.0, 0.0], "con temporal, mojado y sin nieve")
	assert_eq(con_nieve, [0.0, 1.0], "con nieve, nevado")


func test_la_luz_del_temporal_es_la_mas_oscura_y_la_del_nublado_plana() -> void:
	var despejado := ClimaEnPantalla.luz(Weather.Kind.DESPEJADO)
	var nublado := ClimaEnPantalla.luz(Weather.Kind.NUBLADO)
	var temporal := ClimaEnPantalla.luz(Weather.Kind.TEMPORAL)
	assert_lt(float(nublado["sol"]), float(despejado["sol"]), "el nublado quita sol")
	assert_lt(float(nublado["sombra"]), float(despejado["sombra"]), "y ablanda las sombras: luz plana")
	assert_lt(float(temporal["sol"]), float(nublado["sol"]), "el temporal, menos sol todavía")
	assert_lt(float(temporal["ambiente"]), float(nublado["ambiente"]), "y más oscuro")


## Un campamento de prueba, como en `TestReloj`.
func _sim(semilla: int) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var sim := SettlementSim.new()
	for i in range(4):
		sim.people.append(Inhabitant.create(i, Vector3.ZERO, rng))
	sim.chronicle = Chronicle.new()
	sim._rng.seed = semilla
	var terreno := FakeTerrain.new()
	sim._terrain = terreno
	sim.home_position = Vector3(700.0, 200.0, 700.0)
	for persona: Inhabitant in sim.people:
		persona.position = sim.home_position
	sim.hour = 7.0
	_nodos.append(sim)
	_nodos.append(terreno)
	return sim


func test_la_partida_es_la_misma_con_el_clima_encendido_y_apagado() -> void:
	var antes := bool(Configuracion.graficos.get("clima", true))
	var firmas: Array[String] = []
	var horas_con_clima := 0
	for encendido: bool in [true, false]:
		Configuracion.graficos["clima"] = encendido
		var sim := _sim(77)
		var suelo := ClimaEnPantalla.new()
		var horas := [0]
		sim.hour_passed.connect(func(_dia: int, _hora: int) -> void:
			if bool(Configuracion.graficos["clima"]):
				suelo.una_hora(sim.weather.kind)
				horas[0] += 1)
		# Seis horas de juego: 120 s por jornada y 30 pasos por segundo.
		for i in range(1800):
			sim._advance(SettlementSim.PASO_FIJO)
		firmas.append(FirmaDiaria.de(sim).firma)
		if encendido:
			horas_con_clima = horas[0]
	Configuracion.graficos["clima"] = antes
	assert_gt(float(horas_con_clima), 3.0, "con el clima encendido, la vista ha avanzado horas: %d" % horas_con_clima)
	assert_eq(firmas[0], firmas[1], "la misma firma con el clima encendido y apagado")


func test_la_vista_llueve_lo_que_pide_la_tabla_inclinado_por_el_viento() -> void:
	var vista := WeatherView.new()
	_nodos.append(vista)
	vista.setup(null, null)
	vista.contar_horas(3, 10.0, Weather.Kind.TEMPORAL)
	vista.show_weather(Weather.Kind.TEMPORAL)
	var pide := ClimaEnPantalla.lluvia(Weather.Kind.TEMPORAL)
	var gravedad := (vista._rain.process_material as ParticleProcessMaterial).gravity
	assert_true(vista._rain.emitting, "llueve")
	assert_eq(vista._rain.amount, int(pide["cantidad"]), "con las gotas de la tabla")
	assert_near(rad_to_deg(asin(Vector2(gravedad.x, gravedad.z).length() / gravedad.length())),
		float(pide["inclinacion"]), 0.5, "e inclinada lo que pide")
	assert_false(vista._snow.emitting, "y sin nieve")
	vista.show_weather(Weather.Kind.DESPEJADO)
	assert_false(vista._rain.emitting, "despejado, no llueve")


func test_el_suelo_de_la_vista_avanza_por_horas_de_juego() -> void:
	var vista := WeatherView.new()
	_nodos.append(vista)
	vista.setup(null, null)
	vista.contar_horas(2, 8.0, Weather.Kind.DESPEJADO)
	var seco := vista.suelo.mojado
	vista.contar_horas(2, 9.5, Weather.Kind.LLUVIA)
	var una_hora := vista.suelo.mojado
	vista.contar_horas(2, 11.0, Weather.Kind.LLUVIA)
	var tres_horas := vista.suelo.mojado
	vista.contar_horas(9, 11.0, Weather.Kind.TEMPORAL)
	var tras_un_salto := vista.suelo.mojado
	assert_eq(seco, 0.0, "empieza seco con despejado")
	assert_near(una_hora, 1.0 / 3.0, 0.001, "una hora de lluvia")
	assert_near(tres_horas, 1.0, 0.001, "tres horas, mojado del todo")
	assert_near(tras_un_salto, 1.0, 0.001, "y tras una semana sin mirar, se asienta en el de ahora")
	assert_eq(WeatherView.viento_del_dia(4), WeatherView.viento_del_dia(4), "el viento de un día es siempre el mismo")


func test_la_nieve_cuaja_por_encima_de_la_cota_y_no_por_debajo() -> void:
	# Con la cota a 400 m: a 500 m en llano, cuaja; a 300, no; y en una pared, poco.
	assert_near(ClimaEnPantalla.cuaja(500.0, 400.0, 1.0, 1.0), 1.0, 0.001, "encima de la cota, en llano, cuaja")
	assert_near(ClimaEnPantalla.cuaja(300.0, 400.0, 1.0, 1.0), 0.0, 0.001, "debajo, no")
	assert_near(ClimaEnPantalla.cuaja(500.0, 400.0, 0.4, 1.0), 0.4, 0.001, "y lo que haya cuajado")
	assert_near(ClimaEnPantalla.cuaja(500.0, 400.0, 1.0, 0.2), 0.0, 0.001, "en una pared no se queda")


func test_la_cota_de_la_nieve_del_tiempo_es_la_de_la_estacion() -> void:
	var temporada := Temporada.new()
	temporada.relieve = Vector2(100.0, 700.0)
	temporada.asentar(Subsistence.Season.INVIERNO)
	var vista := WeatherView.new()
	_nodos.append(vista)
	vista.setup(null, null)
	vista.pintar_el_suelo_en(null, temporada)
	vista.nieve_vista = 1.0
	vista._pintar_el_suelo()
	var encima := ClimaEnPantalla.material_encima()
	var cota_m := float(encima.get_shader_parameter("cota_de_nieve_m"))
	assert_near(cota_m, 100.0 + temporada.cota_de_nieve() * 600.0, 0.01,
		"la cota de las piedras es la de la estación pasada a metros: %.0f m" % cota_m)
	assert_near(cota_m, Termometro.cota_de_hielo(Subsistence.Season.INVIERNO), 0.5,
		"que es la cota de hielo del termómetro")
	assert_near(float(encima.get_shader_parameter("nieve")), 1.0, 0.001, "y la nieve que se ve")


# ------------------------------------------------------ la niebla de valle --

func _niebla_sobre_los_montes() -> NieblaDeValle:
	var terreno := PeakTerrain.new()
	_nodos.append(terreno)
	var niebla := NieblaDeValle.new()
	_nodos.append(niebla)
	niebla.hornear(terreno)
	return niebla


func test_el_fondo_del_valle_queda_abajo_y_no_en_la_cumbre() -> void:
	var niebla := _niebla_sobre_los_montes()
	var cima: Array = PeakTerrain.SUMMITS[0]
	var centro: Vector2 = cima[0]
	var fondo_bajo_la_cima := niebla.fondo_en(centro.x, centro.y)
	var terreno := PeakTerrain.new()
	var cota_de_la_cima := terreno.get_height_at(Vector3(centro.x, 0.0, centro.y))
	terreno.free()
	assert_lt(fondo_bajo_la_cima, PeakTerrain.BASE + 40.0,
		"bajo la cima, el fondo es el del valle (%.0f m), no la cima (%.0f m)" % [fondo_bajo_la_cima, cota_de_la_cima])


func test_la_niebla_es_mas_densa_en_el_fondo_que_en_la_cumbre_mas_alta() -> void:
	var niebla := _niebla_sobre_los_montes()
	niebla.fuerza = 1.0
	var cima: Array = PeakTerrain.SUMMITS[0]
	var centro: Vector2 = cima[0]
	var terreno := PeakTerrain.new()
	var en_la_cumbre := niebla.densidad(Vector3(centro.x, terreno.get_height_at(Vector3(centro.x, 0.0, centro.y)), centro.y))
	var en_el_fondo := niebla.densidad(Vector3(200.0, PeakTerrain.BASE + 5.0, 1900.0))
	terreno.free()
	assert_gt(en_el_fondo, 0.9, "en el fondo del valle, niebla entera: %.2f" % en_el_fondo)
	assert_lt(en_la_cumbre, 0.01, "en la cumbre más alta, nada: %.2f" % en_la_cumbre)
	assert_gt(NieblaDeValle.perfil(0.0), NieblaDeValle.perfil(90.0), "y se apaga con la altura")


func test_la_camara_se_empana_solo_dentro_de_la_niebla() -> void:
	var niebla := _niebla_sobre_los_montes()
	var dentro := Vector3(200.0, PeakTerrain.BASE + 20.0, 1900.0)
	var encima := Vector3(200.0, PeakTerrain.BASE + 300.0, 1900.0)
	niebla.fuerza = 1.0
	var metida := niebla.dentro(dentro)
	var por_encima := niebla.dentro(encima)
	niebla.quitar()
	var sin_niebla := niebla.dentro(dentro)
	assert_true(metida, "dentro de la capa, sí")
	assert_false(por_encima, "encima de la capa, no")
	assert_false(sin_niebla, "sin niebla, no")


func test_la_vista_empana_la_camara_solo_metida_en_la_niebla() -> void:
	var vista := WeatherView.new()
	_nodos.append(vista)
	vista.setup(null, null)
	var sin_niebla := vista.se_empana_en(Vector3(200.0, PeakTerrain.BASE + 20.0, 1900.0))
	vista.niebla = _niebla_sobre_los_montes()
	vista.niebla.fuerza = 1.0
	var dentro := vista.se_empana_en(Vector3(200.0, PeakTerrain.BASE + 20.0, 1900.0))
	var encima := vista.se_empana_en(Vector3(200.0, PeakTerrain.BASE + 300.0, 1900.0))
	assert_false(sin_niebla, "sin niebla de valle, no")
	assert_true(dentro, "con la cámara dentro, sí")
	assert_false(encima, "con la cámara encima de la capa, no")


func test_el_entorno_lleva_la_luz_del_tiempo_sin_saltos() -> void:
	# `WorldEnvironmentSetup` no tiene `class_name`: se hace por su script.
	var entorno: Node3D = (load("res://scripts/vista/WorldEnvironmentSetup.gd") as GDScript).new()
	_nodos.append(entorno)
	entorno.luz_por_el_tiempo(Weather.Kind.TEMPORAL)
	entorno._suavizar_la_luz(0.5)
	var a_medias := float(entorno.luz_del_tiempo["sol"])
	entorno._suavizar_la_luz(10.0)
	var del_todo := float(entorno.luz_del_tiempo["sol"])
	entorno.luz_sin_clima()
	var sin_clima := float(entorno.luz_del_tiempo["sol"])
	var temporal := float(ClimaEnPantalla.luz(Weather.Kind.TEMPORAL)["sol"])
	assert_true(a_medias < 1.0 and a_medias > temporal, "entra poco a poco: %.2f" % a_medias)
	assert_near(del_todo, temporal, 0.001, "y llega a la del temporal")
	assert_near(sin_clima, 1.0, 0.001, "sin clima, la de la hora al momento")


func test_apagado_no_dibuja_nada_del_tiempo() -> void:
	var antes := bool(Configuracion.graficos.get("clima", true))
	Configuracion.graficos["clima"] = true
	var vista := WeatherView.new()
	_nodos.append(vista)
	vista.setup(null, null)
	vista.niebla = _niebla_sobre_los_montes()
	vista.contar_horas(4, 6.0, Weather.Kind.NIEBLA)
	vista.show_weather(Weather.Kind.TEMPORAL)
	vista.niebla.fuerza = 1.0
	vista.mojado_visto = 1.0
	vista.nieve_vista = 0.5
	var llovia := vista._rain.emitting

	Configuracion.graficos["clima"] = false
	vista.aplicar_configuracion()
	vista.show_weather(Weather.Kind.NIEVE)
	var encima := ClimaEnPantalla.material_encima()
	var apagado := {
		"lluvia": vista._rain.emitting, "nieve": vista._snow.emitting,
		"niebla de valle": vista.niebla.fuerza > 0.0 or vista.niebla.visible,
		"bruma": vista._fog_target > 0.0,
		"suelo mojado": float(encima.get_shader_parameter("mojado")) > 0.0,
		"nieve cuajada": float(encima.get_shader_parameter("nieve")) > 0.0,
		"condensación": vista.se_empana_en(Vector3(200.0, PeakTerrain.BASE + 20.0, 1900.0)),
	}

	Configuracion.graficos["clima"] = true
	vista.aplicar_configuracion()
	vista.show_weather(Weather.Kind.TEMPORAL)
	var vuelve := vista._rain.emitting
	Configuracion.graficos["clima"] = antes
	assert_true(llovia, "encendido, llovía")
	for que: String in apagado:
		assert_false(bool(apagado[que]), "apagado, sin %s" % que)
	assert_true(vuelve, "y al encenderlo vuelve a llover")


func test_la_hojarasca_sube_en_otono_y_se_va_con_el() -> void:
	# GRAFICOS §7.7: el suelo de bosque tiene dos caras y la de otoño es una capa aparte,
	# con su peso mandado por la estación. «Sube y baja con la estación», pidió el usuario:
	# nada de interruptor, la misma transición de doce días que la cota de nieve.
	var temporada := Temporada.new()
	temporada.relieve = Vector2(0.0, 800.0)
	temporada.asentar(Subsistence.Season.VERANO)
	assert_near(temporada.hojarasca(), 0.0, 0.001, "en verano no hay hojas caídas")

	# Llega el otoño: sube, y no de golpe.
	temporada.nuevo_dia(Subsistence.Season.OTONO)
	var primer_dia := temporada.hojarasca()
	assert_gt(primer_dia, 0.0, "el primer día de otoño ya cae algo")
	assert_true(primer_dia < 0.5, "pero no está el suelo cubierto: %.2f" % primer_dia)
	for dia in range(20):
		temporada.nuevo_dia(Subsistence.Season.OTONO)
	assert_near(temporada.hojarasca(), 1.0, 0.001, "y al cabo del otoño, cubierto")

	# Y en invierno se va, también poco a poco.
	temporada.nuevo_dia(Subsistence.Season.INVIERNO)
	assert_true(temporada.hojarasca() < 1.0, "en invierno empieza a irse")
	for dia in range(20):
		temporada.nuevo_dia(Subsistence.Season.INVIERNO)
	assert_near(temporada.hojarasca(), 0.0, 0.001, "y acaba sin hojas")


func test_asentar_pone_la_hojarasca_de_la_estacion() -> void:
	# Las sondas y el arranque de partida no pueden esperar doce días a que caiga la hoja.
	var temporada := Temporada.new()
	temporada.relieve = Vector2(0.0, 800.0)
	temporada.asentar(Subsistence.Season.OTONO)
	assert_near(temporada.hojarasca(), 1.0, 0.001, "asentado en otoño, el suelo cubierto")
	temporada.asentar(Subsistence.Season.PRIMAVERA)
	assert_near(temporada.hojarasca(), 0.0, 0.001, "y en primavera, limpio")
