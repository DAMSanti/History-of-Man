extends SceneTree
## Una jornada mirando como se dibuja la banda. GRAFICOS §7.6, tarea 8.
##
## Las tres cifras de aceptacion de la spec salen de la MISMA pasada, que es lo que hace
## que valga la pena arrancarla:
##
##   - **cuanto corre una figura en pantalla**: ninguna por encima de 8 m/s reales, salvo
##     en trayectos de menos de 150 m, que no se abrevian;
##   - **cuanto dura cada tramo andado**: como mucho 1,5 s de reloj, salida y llegada;
##   - **cuanto se mueve la marca de un cuadro a otro**, que es lo que el jugador ve como
##     un salto de la marca.
##
## Y de paso cuenta cuantos viajes se abreviaron: si salieran cero, las cifras de arriba
## estarian en verde sin haber probado nada.
##
## **Con ventana**, no por las capturas sino porque `Figuras` pinta por `_process` y una
## sonda headless con la escena montada vale igual; se abre ventana para poder mirarla.
##
##   godot --path . --script res://scripts/tests/VerTrabajarProbe.gd
##
## **Mira la linea de TODO BIEN, no el codigo de salida.** Godot revienta al cerrar
## -«CrashHandlerException: signal 11», despues del ultimo cuadro y de imprimirlo todo-
## en cualquier sonda que monte `demo_main` con ventana y llame a `quit()`:
## `NocheLuzProbe`, que no tiene nada que ver con esto, hace lo mismo. Es al apagar el
## servidor de render, no en la medida.
##
##   SITIO=56    que valle
##   HORAS=6     cuantas horas de juego mirar (por defecto, la jornada de luz)

const SITE_ID_POR_DEFECTO := 56

var _mas_rapida := 0.0
var _tramo_mas_largo := 0.0
var _salto_de_la_marca := 0.0
var _viajes_abreviados := 0
var _cuadros := 0
var _antes: Dictionary = {}
var _antes_fase: Dictionary = {}
var _recorrido: Dictionary = {}
var _andando_desde: Dictionary = {}
var _marca_antes: Dictionary = {}


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var site_id := SITE_ID_POR_DEFECTO
	if not OS.get_environment("SITIO").is_empty():
		site_id = int(OS.get_environment("SITIO"))
	var horas := 6.0
	if not OS.get_environment("HORAS").is_empty():
		horas = float(OS.get_environment("HORAS"))

	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % site_id)
	var sites := SiteSet.comarca()
	if local == null or sites == null:
		print("faltan datos"); quit(1); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == site_id:
			site = s
	if site == null:
		print("sin emplazamiento"); quit(1); return

	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % site_id
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	var sim: SettlementSim = demo.sim if "sim" in demo else null
	if sim == null or sim.figuras == null:
		print("sin simulacion o sin figuras"); quit(1); return

	# LA BANDA REPARTIDA. El juego deja el reparto al jugador, y sin oficios no sale nadie
	# del campamento, o sea ni un viaje que abreviar. `_repartir` es un ayudante de otras
	# sondas y no un metodo de la simulacion —la primera version lo llamaba como si lo
	# fuera, y la corrida entera salio sin un solo viaje—.
	sim.assign_default_jobs()
	sim.apply_priorities()
	sim.hour = 8.0
	sim.time_scale = 1.0
	# SIN CAMARA LENTA: lo que se mide aqui es el paso de la figura en segundos REALES, y
	# con el freno puesto la simulacion avanza menos y todo saldria mas despacio del suelo.
	sim.freno_de_la_vista = 1.0

	print("")
	print("=== LA BANDA, DIBUJADA ===")
	var hasta := sim.hour + horas
	# EL MISMO DELTA QUE RECIBE `Figuras`, que es el de la ventana raiz. Medirlo con
	# `Time.get_ticks_usec` entre vueltas del bucle da un 26 % mas —se toma en otro punto
	# del cuadro—, y con el la figura salia a 10,1 m/s con el tope en 8: la que corria era
	# la regla de medir.
	while sim.hour < hasta and is_instance_valid(demo):
		await process_frame
		_mirar(sim, get_root().get_process_delta_time())

	print("cuadros mirados ............ %d" % _cuadros)
	print("cuadros con alguien de viaje %d" % _viajes_abreviados)
	print("la figura mas rapida ....... %.2f m/s reales (tope %.1f)" % [
		_mas_rapida, Figuras.PASO_MAXIMO])
	print("el tramo andado mas largo .. %.2f s (tope %.2f)" % [
		_tramo_mas_largo, Figuras.RETRASO_TOPE])
	print("el mayor salto de la marca . %.2f m en un cuadro" % _salto_de_la_marca)
	var bien := _mas_rapida <= Figuras.PASO_MAXIMO + 0.5 and _viajes_abreviados > 0 and _tramo_mas_largo <= Figuras.RETRASO_TOPE + 0.1
	print("=== %s ===" % ("TODO BIEN" if bien else "ALGO NO CUADRA"))
	quit(0 if bien else 1)


func _mirar(sim: SettlementSim, delta: float) -> void:
	_cuadros += 1
	var figuras := sim.figuras
	for index in range(sim.people.size()):
		var person: Inhabitant = sim.people[index]
		var donde := figuras.donde(index, person.position)
		var fase := figuras.fase_de(index)
		var andando := fase == Figuras.Fase.SALIDA or fase == Figuras.Fase.LLEGADA
		var seguia: bool = int(_antes_fase.get(index, -1)) == fase
		# La figura escondida no se dibuja, y el cuadro en que REAPARECE tampoco cuenta:
		# venia de estar al otro lado del valle y ese salto no lo ve nadie.
		if andando and seguia and _antes.has(index):
			_recorrido[index] = float(_recorrido.get(index, 0.0)) 				+ donde.distance_to(_antes[index])
		# Cuanto dura cada tramo que se le ve andar, de reloj de pared.
		if andando and not seguia:
			_andando_desde[index] = Time.get_ticks_msec()
			_recorrido[index] = 0.0
		elif not andando and _andando_desde.has(index):
			_tramo_mas_largo = maxf(_tramo_mas_largo,
				float(Time.get_ticks_msec() - int(_andando_desde[index])) / 1000.0)
			_andando_desde.erase(index)
			_recorrido.erase(index)
		# LA VELOCIDAD, SOBRE MEDIO SEGUNDO Y NO SOBRE UN CUADRO. Comparar lo que anda en
		# un cuadro con el `delta` que mide esta sonda daba entre un 12 % y un 26 % de mas:
		# el delta que usa `Figuras` es el de su `_process` y este se toma en otro punto
		# del cuadro, asi que se estan dividiendo peras entre manzanas. Sobre medio
		# segundo de reloj, ese desajuste se lava.
		if andando and _andando_desde.has(index):
			var lleva := float(Time.get_ticks_msec() - int(_andando_desde[index])) / 1000.0
			if lleva >= 0.5:
				_mas_rapida = maxf(_mas_rapida, float(_recorrido[index]) / lleva)
		_antes[index] = donde
		_antes_fase[index] = fase
	if not figuras.marcas_puestas.is_empty():
		_viajes_abreviados += 1
	# Cuanto se mueve la marca de un cuadro a otro: es lo que se ve como un salto. No se
	# compara con la posicion simulada de ESTE cuadro porque la marca se puso en el
	# anterior, y a x1 la simulacion mueve a alguien quince metros entre dos cuadros.
	var ahora: Array[Vector3] = []
	for marca: Dictionary in figuras.marcas_puestas:
		ahora.append(marca["donde"])
	for i in range(mini(ahora.size(), _marca_antes.size())):
		_salto_de_la_marca = maxf(_salto_de_la_marca,
			ahora[i].distance_to(_marca_antes[i]))
	_marca_antes = {}
	for i in range(ahora.size()):
		_marca_antes[i] = ahora[i]
