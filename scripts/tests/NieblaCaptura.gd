extends SceneTree
## La niebla del mapa regional, vista y medida: GRAFICOS §3 y SISTEMAS §4.
##
## Con ventana, porque sin ella no hay captura ni tiempo de GPU:
##
##   1. al empezar la partida, la comarca entera: sólo el recuadro del primer
##      campamento sin niebla —`niebla_inicio.png`—;
##   2. tras un pasillo de doce jornadas hacia el este —`niebla_pasillo.png`—;
##   3. el coste: GPU de render a 1920×1080, alternando niebla sí y no en la
##      misma corrida, mínimo de varias vueltas. El presupuesto es 1 ms;
##   4. la ficha de rumbo abierta en el regional, a 1920×1080 y 1280×720: que no se
##      salga nada y que la flecha esté dibujada. Desde el 2026-09-16 no hay ficha en
##      el valle: su botón lleva al regional (`RumboProbe`).
##
##   godot --path . --script res://scripts/tests/NieblaCaptura.gd
##
## `ESTILOS=1` hace otra cosa: los aspectos de las nubes de la niebla (GRAFICOS §3), uno
## por captura —de lejos y el borde de cerca— y el coste de cada uno contra la calima de
## hoy, para que el usuario elija.

const VUELTAS := 4


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/mapas"
	GameState.started = false
	GameState.niebla = null
	# A 1080p y en ventana: el proyecto arranca a pantalla completa, y a pantalla
	# completa `window_set_size` no hace nada. Ver `PrioridadesCaptura`.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/region_map.tscn")
	for i in range(240):
		await process_frame
	var mapa := current_scene
	if mapa == null or mapa.get("terrain") == null:
		print("sin mapa regional")
		quit(1)
		return
	print("raíz %s" % str(get_root().size))
	var terreno: TerrainGenerator = mapa.terrain
	var casa := GameState.home
	mapa.camera.set_target(terreno.geo_to_world(casa.lon, casa.lat))
	mapa.camera.set_distance(float(maxi(terreno.terrain_size.x, terreno.terrain_size.y)) * 0.45)
	for i in range(60):
		await process_frame

	if OS.get_environment("ESTILOS") == "1":
		await _los_aspectos(mapa, terreno, casa)
		return

	print("")
	print("=== LA NIEBLA DEL MAPA REGIONAL ===")
	print("celdas vistas al empezar: %d de %d (%.3f %%)" % [GameState.niebla.cuantas(),
		GameState.niebla.celdas.size(), GameState.niebla.fraccion() * 100.0])
	_captura("niebla_inicio")

	var pasillo := Pasillo.trazar(casa.lon, casa.lat, 90.0, 12)
	var forma := {"forma": "pasillo", "pasillo": pasillo.a_datos()}
	var nuevos := GameState.levantar_niebla(forma)
	print("pasillo hacia el este, 12 jornadas: %.1f km de ida, %d sitios nuevos" % [
		pasillo.largo_m / 1000.0, nuevos])
	for i in range(90):
		await process_frame
	_captura("niebla_pasillo")

	# EL COSTE, con la misma vista y alternando en la misma corrida.
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var material := terreno.get_terrain_material()
	var con := INF
	var sin := INF
	for vuelta in range(VUELTAS):
		material.set_shader_parameter("use_fog", true)
		con = minf(con, await _gpu(vp))
		material.set_shader_parameter("use_fog", false)
		sin = minf(sin, await _gpu(vp))
	material.set_shader_parameter("use_fog", true)
	print("GPU de render a %s, mínimo de %d vueltas: con niebla %.2f ms, sin %.2f ms, %+.2f ms" % [
		str(get_root().size), VUELTAS, con, sin, con - sin])

	# 4. LA FICHA DE RUMBO, en el regional y en el valle, a las dos resoluciones.
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio_56: Site = null
	for s: Site in comarca.sites:
		if s.id == 56:
			sitio_56 = s
	var campamento := Campamento.montar(self, sitio_56, GameState.population, 400.0)
	campamento.sim.store.add(Materia.Kind.PIEL_CURTIDA, 10.0)
	campamento.sim.store.add(Materia.Kind.LENA, 200.0)
	Campamentos.alta(self, campamento)
	Campamentos.dejar_de_mirar(campamento)
	Campamentos.reloj.time_scale = 0.0
	campamento.sim.time_scale = 0.0
	mapa._select_site(sitio_56)
	mapa.camera.set_target(terreno.geo_to_world(sitio_56.lon, sitio_56.lat))
	mapa.camera.set_distance(float(maxi(terreno.terrain_size.x, terreno.terrain_size.y)) * 0.25)
	for i in range(30):
		await process_frame
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		await _a_resolucion(resolucion)
		# LA FICHA, ABIERTA A ESTA RESOLUCIÓN: como la interfaz de
		# `PrioridadesCaptura`, se mide montada a la resolución que se juega.
		mapa._cerrar_el_rumbo(false)
		mapa.abrir_la_ficha(campamento)
		for i in range(10):
			await process_frame
		_informe("regional", resolucion, mapa._ficha_de_rumbo, mapa._flecha)
		_captura("rumbo_regional_%dx%d" % [resolucion.x, resolucion.y])

	Campamentos.vaciar()
	quit()


func _informe(donde: String, resolucion: Vector2i, ficha: Node, flecha: FlechaDeRumbo) -> void:
	var fuera := _fuera_de(ficha, Rect2(Vector2.ZERO, Vector2(get_root().size)))
	var texto_fuera := "nada se sale" if fuera.is_empty() else "SE SALEN %s" % str(fuera.slice(0, 4))
	var texto_flecha := "dibujada" if flecha != null and flecha.mesh != null else "SIN DIBUJAR"
	print("%dx%d · ficha de rumbo en el %s: %s · flecha %s" % [resolucion.x,
		resolucion.y, donde, texto_fuera, texto_flecha])


func _a_resolucion(resolucion: Vector2i) -> void:
	# Sin escalar: si no, la interfaz se mide en los 1920×1080 del proyecto aunque
	# la ventana mida otra cosa. Ver `PrioridadesCaptura`.
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(resolucion)
	get_root().size = resolucion
	var esperas := 0
	while get_root().size != resolucion and esperas < 240:
		esperas += 1
		await process_frame
	for i in range(30):
		await process_frame


## La vara de `RegionCaptura`: lo que va dentro de un panel con desplazamiento lo
## recorta el panel, así que se mide el panel.
func _fuera_de(nodo: Node, pantalla: Rect2) -> Array:
	var salida: Array = []
	if nodo == null:
		return ["no hay ficha"]
	if nodo is ScrollContainer:
		if (nodo as Control).is_visible_in_tree():
			var marco := (nodo as Control).get_global_rect()
			if not pantalla.grow(1.0).encloses(marco):
				salida.append("%s %s" % [nodo.name, str(marco)])
		return salida
	if nodo is Control and (nodo as Control).is_visible_in_tree():
		var rect := (nodo as Control).get_global_rect()
		var dentro := pantalla.grow(1.0).encloses(rect)
		if rect.size.x > 1.0 and rect.size.y > 1.0 and not dentro:
			salida.append("%s %s" % [nodo.name, str(rect)])
	for hijo: Node in nodo.get_children():
		salida.append_array(_fuera_de(hijo, pantalla))
	return salida


func _captura(nombre: String) -> void:
	var shot := get_root().get_texture().get_image()
	if shot == null:
		print("sin captura: hace falta ventana")
		return
	var ruta := "user://%s.png" % nombre
	shot.save_png(ruta)
	print("captura en %s" % ProjectSettings.globalize_path(ruta))


func _gpu(vp: RID) -> float:
	for i in range(25):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0


## Las nubes de la niebla: capturas y coste contra la calima lisa (GRAFICOS §3). El aspecto
## lo eligió el usuario el 2026-09-16; aquí se comprueban sus criterios.
func _los_aspectos(mapa: Node, terreno: TerrainGenerator, casa: Site) -> void:
	print("")
	print("=== LAS NUBES DE LA NIEBLA ===")
	var ui := mapa.get_node_or_null("UI")
	if ui != null:
		(ui as CanvasLayer).visible = false
	print("celdas vistas: %d de %d" % [GameState.niebla.cuantas(), GameState.niebla.celdas.size()])
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var lejos := float(maxi(terreno.terrain_size.x, terreno.terrain_size.y))
	var coste := {}
	for con_nubes: bool in [true, false]:
		mapa.poner_las_nubes(con_nubes)
		_poner_la_hora(9.0)
		mapa.camera.set_target(terreno.geo_to_world(casa.lon, casa.lat))
		mapa.camera.set_distance(lejos * 0.45)
		for i in range(60):
			await process_frame
		_captura("niebla_nubes" if con_nubes else "niebla_calima")
		coste[con_nubes] = await _gpu(vp)
		mapa.camera.set_distance(lejos * 0.10)
		for i in range(40):
			await process_frame
		if con_nubes:
			_captura("niebla_nubes_borde")
	print("")
	print("GPU: nubes %.2f ms · calima %.2f ms · las nubes %+.2f ms" % [
		coste[true], coste[false], coste[true] - coste[false]])

	# Y QUE SE MUEVEN CON EL RELOJ Y NO CON EL DE PARED (criterio de la spec): con la partida
	# en pausa —la misma hora—, dos capturas iguales aunque pasen cuadros; con la hora
	# corrida, distintas.
	mapa.poner_las_nubes(true)
	mapa.camera.set_distance(lejos * 0.45)
	_poner_la_hora(9.0)
	for i in range(30):
		await process_frame
	var parada := get_root().get_texture().get_image()
	for i in range(60):
		await process_frame
	var parada_otra_vez := get_root().get_texture().get_image()
	_captura("niebla_viento_parado")
	_poner_la_hora(15.0)
	for i in range(30):
		await process_frame
	var corrida := get_root().get_texture().get_image()
	_captura("niebla_viento_corrido")
	var quieta := _diferencia(parada, parada_otra_vez)
	var movida := _diferencia(parada, corrida)
	print("con el viento parado, entre dos capturas: %.4f · con el viento corrido: %.4f" % [
		quieta, movida])
	if quieta > 0.002:
		print("MAL: con la partida en pausa las nubes se mueven")
	if movida < 0.01:
		print("MAL: con la partida corriendo las nubes no se mueven")
	print("fin")
	quit()


## Cuánto se diferencian dos capturas, de 0 —iguales— a 1. Mira una de cada dieciséis
## filas y columnas: para saber si algo se ha movido sobra, y recorrer dos millones de
## píxeles en GDScript no.
func _diferencia(a: Image, b: Image) -> float:
	if a == null or b == null or a.get_size() != b.get_size():
		return 1.0
	var suma := 0.0
	var cuantos := 0
	for y in range(0, a.get_height(), 16):
		for x in range(0, a.get_width(), 16):
			var uno := a.get_pixel(x, y)
			var otro := b.get_pixel(x, y)
			suma += absf(uno.r - otro.r) + absf(uno.g - otro.g) + absf(uno.b - otro.b)
			cuantos += 1
	return suma / maxf(float(cuantos) * 3.0, 1.0)


## Mueve EL RELOJ DE LA PARTIDA, que es de donde sacan las nubes su viento
## (`Viento.recorrido_del_reloj`). Poner el uniforme a mano no vale: `RegionMap` lo
## reescribe con el del reloj en cada cuadro, y así la sonda medía nubes que no se movían
## creyendo que se movían (2026-09-16).
func _poner_la_hora(horas: float) -> void:
	if Campamentos.reloj == null:
		Campamentos.reloj = RelojDeLaPartida.new()
	Campamentos.reloj.dia = 1
	Campamentos.reloj.hora = horas

