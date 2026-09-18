class_name TestSeguimiento
extends TestCase
## La camara sigue a la persona elegida. INTERFAZ §13.
##
## Lo que mas vale de aqui **no es que siga, sino que suelte**: los sitios que sueltan son
## seis y el que se olvide no da ningun error, se queda la camara pegada a alguien cuando
## el jugador ya esta mirando otra cosa. Cada gesto tiene su prueba.

## A cuanto se da por centrada a una persona, en metros de horizontal. De la spec.
const CERCA_M := 1.0

var _nodos: Array[Node] = []


func suite_name() -> String:
	return "Seguimiento"


func before_each() -> void:
	for nodo: Node in _nodos:
		if is_instance_valid(nodo):
			nodo.free()
	_nodos.clear()


func _sim(cuantos: int = 3) -> SettlementSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	var people: Array[Inhabitant] = []
	for i in range(cuantos):
		people.append(Inhabitant.create(i, Vector3.ZERO, rng))
	var sim := SettlementSim.new()
	sim.people = people
	sim.chronicle = Chronicle.new()
	sim._rng.seed = 71
	var terreno := FakeTerrain.new()
	sim._terrain = terreno
	sim.home_position = Vector3(700.0, 0.0, 700.0)
	for i in range(people.size()):
		people[i].position = Vector3(700.0 + float(i) * 10.0, 0.0, 700.0)
	_nodos.append(sim)
	_nodos.append(terreno)
	return sim


func _figuras(sim: SettlementSim) -> Figuras:
	var figuras := Figuras.new()
	figuras.sim = sim
	figuras.crowd = BandaCrowd.new()
	figuras.crowd.setup(sim.people.size())
	sim._bodies.clear()
	sim._headings.clear()
	for i in range(sim.people.size()):
		sim._bodies.append(figuras.crowd.add_person())
		sim._headings.append(0.0)
	figuras._cuantos_habia = sim.people.size()
	for i in range(sim.people.size()):
		figuras.anotar(sim.people[i], i)
	_nodos.append(figuras.crowd)
	_nodos.append(figuras)
	sim.figuras = figuras
	return figuras


func _lejos(uno: Vector3, otro: Vector3) -> float:
	return Vector2(uno.x - otro.x, uno.z - otro.z).length()


# --- lo que se ve de alguien (tarea 1) -------------------------------------------

func test_lo_que_se_ve_es_la_figura_o_la_marca() -> void:
	var sim := _sim()
	var figuras := _figuras(sim)
	var quien: Inhabitant = sim.people[0]
	# Quieta en el campamento: lo que se ve es donde está.
	figuras._process(1.0 / 60.0)
	assert_near(_lejos(figuras.donde_se_ve(0, quien), quien.position), 0.0, 0.01,
		"sin viaje, la figura está donde la persona")
	# En un viaje largo, andando la salida: la figura va por detrás, y es lo que se ve.
	quien.route = PackedVector3Array([quien.position, quien.position + Vector3(2000, 0, 0)])
	figuras._process(1.0 / 60.0)
	quien.position += Vector3(500.0, 0.0, 0.0)
	figuras._process(1.0 / 60.0)
	assert_eq(figuras.fase_de(0), Figuras.Fase.SALIDA, "va saliendo")
	assert_near(_lejos(figuras.donde_se_ve(0, quien), figuras.donde(0, Vector3.ZERO)),
		0.0, 0.01, "y lo que se ve es la figura")
	# Y por el medio, escondida: lo que se ve es la marca, en lo simulado.
	for cuadro in range(100):
		figuras._process(1.0 / 60.0)
	assert_eq(figuras.fase_de(0), Figuras.Fase.MEDIO, "ahora va por el medio")
	assert_near(_lejos(figuras.donde_se_ve(0, quien), quien.position), 0.0, 0.01,
		"y lo que se ve es la marca, que va en lo simulado")


# --- lo que el usuario vio jugando (depurar del 2026-09-17) ----------------------

func test_en_un_viaje_corto_la_figura_no_se_teletransporta() -> void:
	# «Veo a los recolectores teletransportarse básicamente entre recolección y
	# recolección.» Sólo se abrevian los viajes de más de 150 m; por debajo, la figura se
	# pintaba en `person.position` tal cual, y a ×1 la simulación mueve a alguien de
	# quince a sesenta metros por cuadro. O sea: saltos.
	var sim := _sim()
	var figuras := _figuras(sim)
	var quien: Inhabitant = sim.people[0]
	figuras._process(1.0 / 60.0)
	var salida := figuras.donde(0, quien.position)
	# Un paso de simulación que la lleva 40 m: viaje corto, sin ruta que abreviar.
	quien.position += Vector3(40.0, 0.0, 0.0)
	figuras._process(1.0 / 60.0)
	var anduvo := _lejos(figuras.donde(0, quien.position), salida)
	assert_eq(figuras.fase_de(0), Figuras.Fase.PEGADA, "no hay viaje largo que abreviar")
	assert_true(anduvo < 30.0,
		"la figura no salta los 40 m de golpe: anduvo %.1f m, y no se descuelga más de 12"
		% anduvo)
	# Y no se queda atrás para siempre: en metro y medio de reloj ya está encima.
	for cuadro in range(100):
		figuras._process(1.0 / 60.0)
	assert_near(_lejos(figuras.donde(0, quien.position), quien.position), 0.0, 0.5,
		"y acaba donde está la persona")


func test_quien_esta_parado_se_ve_entero_aunque_le_quede_una_ruta_vieja() -> void:
	# «En ocasiones se quedan representados por la marca y no por el modelo cuando no
	# deberían, por ejemplo por la noche cenando.» La marca sólo se pinta en mitad de un
	# viaje abreviado; si alguien se queda quieto con una ruta larga sin recorrer —el
	# reparto cambia, cae la noche—, la figura se quedaba escondida para siempre.
	var sim := _sim()
	var figuras := _figuras(sim)
	var quien: Inhabitant = sim.people[0]
	quien.route = PackedVector3Array([quien.position, quien.position + Vector3(2000, 0, 0)])
	for cuadro in range(100):
		figuras._process(1.0 / 60.0)
		quien.position += Vector3(5.0, 0.0, 0.0)
	assert_eq(figuras.fase_de(0), Figuras.Fase.MEDIO, "va por el medio de su viaje")
	# Y ahora se para a cenar, sin tocar la ruta. Pasa media hora de juego.
	for cuadro in range(120):
		sim.hour += 0.5 / 120.0
		figuras._process(1.0 / 60.0)
	assert_eq(figuras.fase_de(0), Figuras.Fase.PEGADA,
		"parada, se la ve entera aunque le quede ruta")
	assert_near(_lejos(figuras.donde_se_ve(0, quien), quien.position), 0.0, 0.5,
		"y se la ve donde está")


# --- llevar la cámara (tarea 2) --------------------------------------------------

func _camara() -> OrbitalCamera:
	var camara := OrbitalCamera.new()
	camara.set_distance_limits(10.0, 4000.0)
	_nodos.append(camara)
	return camara


func test_la_camara_se_acerca_solo_si_estaba_lejos() -> void:
	var camara := _camara()
	camara.set_distance(150.0)
	camara.mirar_a(Vector3(100.0, 0.0, 100.0))
	assert_near(camara.orbit_distance, camara.distancia_para_mirar(), 0.5,
		"desde lejos se acerca a la distancia de mirar")
	camara.set_distance(30.0)
	camara.mirar_a(Vector3(200.0, 0.0, 200.0))
	assert_near(camara.orbit_distance, 30.0, 0.5, "y desde cerca no se toca el zoom")
	assert_near(_lejos(camara.target_position, Vector3(200.0, 0.0, 200.0)), 0.0, 0.01,
		"pero el punto sí se mueve")


# --- el seguimiento (tareas 3 y 4) -----------------------------------------------

func test_seguir_y_soltar() -> void:
	var sim := _sim()
	var figuras := _figuras(sim)
	var seguimiento := Seguimiento.new()
	assert_false(seguimiento.esta_siguiendo(), "de entrada no sigue a nadie")
	seguimiento.seguir_a(sim.people[1])
	assert_true(seguimiento.esta_siguiendo(), "y ahora sí")
	assert_near(_lejos(seguimiento.punto(sim, figuras), sim.people[1].position), 0.0,
		CERCA_M, "y el punto es el suyo")
	seguimiento.soltar()
	assert_false(seguimiento.esta_siguiendo(), "soltar suelta")
	assert_eq(seguimiento.punto(sim, figuras), Vector3.INF, "y ya no hay punto")


func test_quien_no_esta_en_el_valle_no_se_sigue() -> void:
	var sim := _sim()
	var fuera := Inhabitant.create(99, Vector3.ZERO, RandomNumberGenerator.new())
	assert_true(Seguimiento.esta_en_el_valle(sim.people[0], sim), "el de dentro, sí")
	assert_false(Seguimiento.esta_en_el_valle(fuera, sim), "y el de fuera, no")


func test_quien_se_va_deja_de_tener_punto() -> void:
	# De expedición, mudada o muerta: las tres salen de `people`, que es la lista de los
	# que están aquí. Se construye el estado, no se juega.
	var sim := _sim()
	var figuras := _figuras(sim)
	var seguimiento := Seguimiento.new()
	var quien: Inhabitant = sim.people[1]
	seguimiento.seguir_a(quien)
	sim.people.erase(quien)
	assert_eq(seguimiento.punto(sim, figuras), Vector3.INF,
		"quien ya no está en el valle no tiene punto que mirar")


# --- la camara suelta con las teclas, y no con el zoom (tarea 6) ------------------

func test_mover_con_las_teclas_avisa_y_girar_o_hacer_zoom_no() -> void:
	# LA REGLA QUE MAS FACIL SE ROMPE: rodear a alguien y acercarse a él **no** sueltan;
	# llevar la vista a otro sitio, sí. Vive en la cámara, que es quien sabe qué gesto es
	# cada cosa, y se avisa por señal.
	var camara := _camara()
	camara.bounds_min = Vector2(0.0, 0.0)
	camara.bounds_max = Vector2(4000.0, 4000.0)
	camara.set_target(Vector3(1000.0, 0.0, 1000.0))
	var avisos := {"cuantos": 0}
	camara.movida_a_mano.connect(func() -> void: avisos["cuantos"] += 1)

	# El zoom del teclado no mueve la vista: no avisa.
	Teclas.por_defecto()
	Input.action_press("acercar")
	camara._process(1.0 / 60.0)
	Input.action_release("acercar")
	assert_eq(int(avisos["cuantos"]), 0, "acercarse no suelta")

	# Y girar tampoco: es el ratón, y ni pasa por aquí.
	camara.orbit_angle_h += 20.0
	camara._update_camera()
	assert_eq(int(avisos["cuantos"]), 0, "girar tampoco")

	# Desplazar, sí.
	Input.action_press("avanzar")
	camara._process(1.0 / 60.0)
	Input.action_release("avanzar")
	assert_gt(float(avisos["cuantos"]), 0.0, "desplazar la vista sí suelta")


# --- la ficha engancha y suelta (tareas 4 y 6) -----------------------------------

## Una interfaz con lo justo para abrir la ficha de alguien.
func _ui(sim: SettlementSim, camara: OrbitalCamera) -> GameUI:
	var ui := GameUI.new()
	ui.sim = sim
	ui.camera = camara
	_nodos.append(ui)
	return ui


func test_elegir_a_alguien_la_centra_y_la_sigue() -> void:
	var sim := _sim()
	_figuras(sim)
	var camara := _camara()
	camara.set_distance(150.0)
	var ui := _ui(sim, camara)
	var quien: Inhabitant = sim.people[2]
	ui.show_person(quien)
	assert_true(ui.seguimiento.esta_siguiendo(), "se la sigue")
	assert_eq(ui.seguimiento.a_quien, quien, "y es a ella")
	assert_near(_lejos(camara.target_position, quien.position), 0.0, CERCA_M,
		"la cámara está centrada en ella")
	assert_near(camara.orbit_distance, camara.distancia_para_mirar(), 0.5,
		"y se ha acercado, que estaba lejos")


func test_elegir_a_alguien_que_no_esta_en_el_valle_no_mueve_la_camara() -> void:
	var sim := _sim()
	_figuras(sim)
	var camara := _camara()
	camara.set_target(Vector3(500.0, 0.0, 500.0))
	var donde_estaba := camara.target_position
	var ui := _ui(sim, camara)
	var fuera := Inhabitant.create(99, Vector3.ZERO, RandomNumberGenerator.new())
	ui.show_person(fuera)
	assert_false(ui.seguimiento.esta_siguiendo(), "a quien no está no se le sigue")
	assert_eq(camara.target_position, donde_estaba, "y la cámara no se ha movido")


func test_elegir_a_otra_persona_cambia_a_quien_se_sigue() -> void:
	var sim := _sim()
	_figuras(sim)
	var ui := _ui(sim, _camara())
	ui.show_person(sim.people[0])
	ui.show_person(sim.people[1])
	assert_eq(ui.seguimiento.a_quien, sim.people[1], "se sigue a la segunda")


func test_cerrar_la_ficha_suelta() -> void:
	var sim := _sim()
	_figuras(sim)
	var ui := _ui(sim, _camara())
	ui.show_person(sim.people[0])
	assert_true(ui.close_topmost(), "se cierra la ficha")
	assert_false(ui.seguimiento.esta_siguiendo(), "y se suelta")


func test_llevar_la_camara_a_otra_cosa_suelta() -> void:
	# El «llevar la cámara aquí» de otra ficha: el censo y las obras.
	var sim := _sim()
	_figuras(sim)
	var ui := _ui(sim, _camara())
	ui.show_person(sim.people[0])
	ui.censo._look_at_world(Vector3(300.0, 0.0, 300.0))
	assert_false(ui.seguimiento.esta_siguiendo(),
		"llevar la cámara a otra cosa deja de seguir a la persona")


# --- la camara va con ella cada cuadro (tarea 5) ---------------------------------

## Lo que hace `DemoMain.seguir_a_quien_toque` cada cuadro, sin montar la escena.
func _un_cuadro(camara: OrbitalCamera, seguimiento: Seguimiento, sim: SettlementSim,
		figuras: Figuras) -> void:
	figuras._process(1.0 / 60.0)
	if not seguimiento.esta_siguiendo():
		return
	var punto := seguimiento.punto(sim, figuras)
	if punto == Vector3.INF:
		seguimiento.soltar()
		return
	camara.set_target(punto)


func test_la_camara_va_con_ella_en_cada_cuadro() -> void:
	# Un trayecto CORTO, de los que se dibujan enteros: la figura va pegada a la persona y
	# la cámara tiene que ir con las dos.
	var sim := _sim()
	var figuras := _figuras(sim)
	var camara := _camara()
	var seguimiento := Seguimiento.new()
	var quien: Inhabitant = sim.people[0]
	quien.route = PackedVector3Array([quien.position, quien.position + Vector3(100, 0, 0)])
	seguimiento.seguir_a(quien)
	var peor := 0.0
	for paso in range(60):
		quien.position += Vector3(1.5, 0.0, 0.0)
		_un_cuadro(camara, seguimiento, sim, figuras)
		peor = maxf(peor, _lejos(camara.target_position, figuras.donde_se_ve(0, quien)))
	assert_true(peor <= CERCA_M,
		"en todo el trayecto se queda a menos de %.0f m: %.3f" % [CERCA_M, peor])


func test_la_camara_sigue_la_marca_en_un_viaje_abreviado() -> void:
	var sim := _sim()
	var figuras := _figuras(sim)
	var camara := _camara()
	var seguimiento := Seguimiento.new()
	var quien: Inhabitant = sim.people[0]
	quien.route = PackedVector3Array([quien.position, quien.position + Vector3(3000, 0, 0)])
	seguimiento.seguir_a(quien)
	var por_el_medio := 0
	var peor := 0.0
	for paso in range(200):
		quien.position += Vector3(15.0, 0.0, 0.0)
		_un_cuadro(camara, seguimiento, sim, figuras)
		if figuras.fase_de(0) == Figuras.Fase.MEDIO:
			por_el_medio += 1
			peor = maxf(peor, _lejos(camara.target_position, quien.position))
	assert_gt(float(por_el_medio), 0.0, "el viaje llega a abreviarse")
	assert_true(peor <= CERCA_M,
		"y la cámara va con la marca, que está en lo simulado: %.3f m" % peor)


func test_tras_soltar_la_camara_se_queda_donde_estaba() -> void:
	var sim := _sim()
	var figuras := _figuras(sim)
	var camara := _camara()
	var seguimiento := Seguimiento.new()
	var quien: Inhabitant = sim.people[0]
	quien.route = PackedVector3Array([quien.position, quien.position + Vector3(100, 0, 0)])
	seguimiento.seguir_a(quien)
	_un_cuadro(camara, seguimiento, sim, figuras)
	seguimiento.soltar()
	var donde_se_quedo := camara.target_position
	for paso in range(10):
		quien.position += Vector3(5.0, 0.0, 0.0)
		_un_cuadro(camara, seguimiento, sim, figuras)
	assert_eq(camara.target_position, donde_se_quedo,
		"soltado, el punto no se mueve aunque ella ande")


func test_quien_se_va_del_valle_suelta_la_camara() -> void:
	var sim := _sim()
	var figuras := _figuras(sim)
	var camara := _camara()
	var seguimiento := Seguimiento.new()
	var quien: Inhabitant = sim.people[0]
	seguimiento.seguir_a(quien)
	_un_cuadro(camara, seguimiento, sim, figuras)
	var donde_se_quedo := camara.target_position
	sim.people.erase(quien)
	_un_cuadro(camara, seguimiento, sim, figuras)
	assert_false(seguimiento.esta_siguiendo(), "se suelta sola")
	assert_eq(camara.target_position, donde_se_quedo, "y la cámara se queda donde estaba")


# --- que no se caiga ninguno de los seis (tarea 6) -------------------------------

func test_los_seis_sitios_siguen_soltando() -> void:
	# LOS OTROS DOS GESTOS —ESC y el minimapa— viven en `DemoMain` y en `Minimapa`, que no
	# se pueden montar en la suite sin la escena entera. Lo que sí se puede es comprobar
	# que **el suelto sigue ahí**: si alguien reescribe uno de estos sitios y se lo deja,
	# no habría ningún error, sólo una cámara pegada a alguien que ya no se mira. Lo demás
	# lo comprueban las pruebas de arriba, que sí ejercitan el comportamiento.
	var faltan: Array[String] = []
	for donde: Array in [
		["res://scripts/DemoMain.gd", "seguimiento.soltar()", "ESC y las teclas"],
		["res://scripts/vista/Minimapa.gd", "seguimiento.soltar()", "el minimapa"],
		["res://scripts/ui/GameUI.gd", "seguimiento.soltar()", "cerrar la ficha"],
		["res://scripts/ui/PanelCenso.gd", "seguimiento.soltar()", "llevar la cámara"],
		["res://scripts/ui/PanelObras.gd", "seguimiento.soltar()", "las obras"],
	]:
		var texto := FileAccess.get_file_as_string(String(donde[0]))
		if not texto.contains(String(donde[1])):
			faltan.append(String(donde[2]))
	assert_true(faltan.is_empty(), "todos sueltan; se han quedado sin soltar: %s"
		% ", ".join(faltan))
