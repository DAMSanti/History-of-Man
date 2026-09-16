extends SceneTree
## El clima en pantalla, visto y medido: GRAFICOS §7.4.
##
## Con ventana, a 1920×1080, en el valle del sitio 56 y con el mismo encuadre:
##
##   1. una captura por tiempo —despejado, nublado, orbayu, lluvia, temporal, niebla y
##      nieve— y la nieve al día siguiente de parar: `clima_<tiempo>.png`;
##   2. la condensación, con la cámara metida en la niebla: `clima_condensacion.png`;
##   3. el temporal con el clima apagado: `clima_apagado.png`;
##   4. la GPU de render con temporal y con niebla, clima sí y no, alternando en la misma
##      corrida y el mínimo de tres vueltas.
##
##   godot --path . --script res://scripts/tests/ClimaCaptura.gd
##
## `CAPTURAS=0` sólo mide.

const VUELTAS := 3
const HORA := 11.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/mapas"
	Configuracion.ruta = "user://sondas/configuracion.cfg"
	GameState.started = false
	GameState.niebla = null
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_root().size = Vector2i(1920, 1080)
	Configuracion.poner_nivel(Configuracion.Nivel.ALTO)
	var capturas := OS.get_environment("CAPTURAS") != "0"
	# `SOLO=gotas`: sólo la cámara metida en la niebla, para iterar el efecto.
	var solo_gotas := OS.get_environment("SOLO") == "gotas"
	# `SOLO=zoom`: la lluvia a tres zooms y el agua picada de gotas, que es lo que se
	# depuró el 2026-09-16. `SOLO=relieve`: el relieve de las texturas, con su coste.
	var solo_zoom := OS.get_environment("SOLO") == "zoom"
	var solo_relieve := OS.get_environment("SOLO") == "relieve"

	change_scene_to_file(Expedition.REGION_SCENE)
	var mapa: Node = await _escena_montada(null)
	if mapa == null:
		print("MAL: el mapa regional no se monta")
		quit(1)
		return
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio_56: Site = null
	for s: Site in comarca.sites:
		if s.id == 56:
			sitio_56 = s
	var campamento := Campamento.montar(self, sitio_56, GameState.population, 400.0)
	Campamentos.alta(self, campamento)
	Campamentos.traspaso_de(campamento)
	change_scene_to_file(Expedition.LOCAL_SCENE)
	var demo: Node = await _escena_montada(mapa)
	if demo == null:
		print("MAL: el valle no se monta")
		quit(1)
		return
	demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0
	sim.hour = HORA
	demo.ui.visible = false
	var vista: WeatherView = demo.weather_view
	var entorno: Node = demo._first_world_environment(get_root()).get_parent()
	print("")
	print("=== EL CLIMA EN PANTALLA ===")

	if solo_zoom:
		await _la_lluvia_con_el_zoom(demo, vista, entorno, sim)
		quit()
		return

	if solo_relieve:
		await _el_relieve_del_terreno(demo, sim)
		quit()
		return

	if solo_gotas:
		await _poner(demo, vista, entorno, Weather.Kind.NIEBLA)
		demo.camera.set_target(sim.home_position)
		demo.camera.set_distance(0.0)
		await _cuadros(90)
		_captura("clima_condensacion")
		quit()
		return

	if capturas:
		for tiempo: Weather.Kind in [Weather.Kind.DESPEJADO, Weather.Kind.NUBLADO, Weather.Kind.ORBAYU,
				Weather.Kind.LLUVIA, Weather.Kind.TEMPORAL, Weather.Kind.NIEBLA, Weather.Kind.NIEVE]:
			await _poner(demo, vista, entorno, tiempo)
			_captura("clima_%s" % String(Weather.NAMES[tiempo]).to_lower())
		# El temporal de cerca: la lluvia se lee junto a la cámara, no desde lo alto.
		await _poner(demo, vista, entorno, Weather.Kind.TEMPORAL)
		var distancia_de_gestion: float = demo.camera.orbit_distance
		demo.camera.set_distance(demo.camera.distancia_para_mirar())
		await _cuadros(120)
		print("lluvia: emite %s · %d gotas · caja en %s · cámara en %s" % [
			"SI" if vista._rain.emitting else "NO", vista._rain.amount, vista._rain.global_position,
			demo.camera.global_position])
		_captura("clima_temporal_de_cerca")
		demo.camera.set_distance(distancia_de_gestion)

		# La nieve al día siguiente de parar: nevado y veinticuatro horas despejado.
		vista.suelo.asentar(Weather.Kind.NIEVE)
		for h in range(24):
			vista.suelo.una_hora(Weather.Kind.DESPEJADO)
		await _poner(demo, vista, entorno, Weather.Kind.DESPEJADO, false)
		print("nieve al día siguiente: %.2f" % vista.nieve_vista)
		_captura("clima_nieve_al_dia_siguiente")

		# La condensación: la cámara metida en la niebla, sobre el fondo del valle.
		await _poner(demo, vista, entorno, Weather.Kind.NIEBLA)
		demo.camera.set_target(sim.home_position)
		demo.camera.set_distance(0.0)
		await _cuadros(90)
		print("cámara en %s · dentro de la niebla: %s · empañado %.2f" % [
			demo.camera.global_position, "SI" if vista.se_empana_en(demo.camera.global_position) else "NO",
			vista.empanado])
		_captura("clima_condensacion")
		demo.camera.set_distance(demo.camera.distancia_para_mirar() * 6.0)

		# El temporal con el clima apagado.
		await _poner(demo, vista, entorno, Weather.Kind.TEMPORAL)
		Configuracion.poner_ajuste("clima", false)
		get_root().propagate_call("aplicar_configuracion")
		demo._sync_weather()
		await _cuadros(60)
		print("apagado: lluvia %s · niebla %s · mojado %.2f" % [
			"SI" if vista._rain.emitting else "no", "SI" if vista.niebla.visible else "no", vista.mojado_visto])
		_captura("clima_apagado")
		Configuracion.poner_ajuste("clima", true)
		get_root().propagate_call("aplicar_configuracion")

	# EL COSTE: con temporal y con niebla, clima sí y no, alternando.
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for tiempo: Weather.Kind in [Weather.Kind.TEMPORAL, Weather.Kind.NIEBLA]:
		var con := INF
		var sin := INF
		for vuelta in range(VUELTAS):
			Configuracion.poner_ajuste("clima", true)
			get_root().propagate_call("aplicar_configuracion")
			await _poner(demo, vista, entorno, tiempo)
			con = minf(con, await _gpu(vp))
			Configuracion.poner_ajuste("clima", false)
			get_root().propagate_call("aplicar_configuracion")
			demo._sync_weather()
			sin = minf(sin, await _gpu(vp))
		print("GPU con %s: clima %.2f ms · sin %.2f ms · el clima %+.2f ms" % [
			Weather.NAMES[tiempo], con, sin, con - sin])
	Configuracion.poner_ajuste("clima", true)
	print("fin")
	quit()


## Pone un tiempo y lo deja ya asentado: el suelo, la niebla y la luz sin esperar a la
## transición, para capturar lo que se ve con ese tiempo y no a medio camino.
func _poner(demo: Node, vista: WeatherView, entorno: Node, tiempo: Weather.Kind,
		asentar_el_suelo: bool = true) -> void:
	var sim: SettlementSim = demo.sim
	sim.weather.kind = tiempo
	# La nieve pide invierno: la cota de hielo baja al valle.
	var estacion := Subsistence.Season.INVIERNO if tiempo == Weather.Kind.NIEVE or not asentar_el_suelo \
		else Subsistence.Season.PRIMAVERA
	sim.temporada.asentar(estacion)
	demo.terrain.set_snow_line(sim.temporada.cota_de_nieve())
	demo._sync_weather()
	if asentar_el_suelo:
		vista.suelo.asentar(tiempo)
	vista.mojado_visto = vista.suelo.mojado
	vista.nieve_vista = vista.suelo.nieve
	if vista.niebla != null:
		vista.niebla.fuerza = vista.niebla.objetivo
	entorno.luz_del_tiempo = entorno._luz_objetivo.duplicate()
	vista._fog_now = vista._fog_target
	await _cuadros(150)


func _escena_montada(antes: Node) -> Node:
	for i in range(3000):
		await process_frame
		var escena := current_scene
		if escena != null and escena != antes and bool(escena.get("montado")):
			await _cuadros(20)
			return escena
	return null


## La lluvia a tres zooms, y el agua picada de gotas.
##
## Queja del usuario del 2026-09-16: «la representación de la lluvia funciona mal
## cuando pongo o quito zoom» —«desaparece un momento y después se reinicia, pero
## lejos, y saliendo sólo de un cuadrado»—.
func _la_lluvia_con_el_zoom(demo: Node, vista: WeatherView, entorno: Node,
		sim: Node) -> void:
	await _poner(demo, vista, entorno, Weather.Kind.LLUVIA)
	demo.camera.set_target(sim.home_position)
	for cerca: float in [1.0, 3.0, 8.0]:
		demo.camera.set_distance(demo.camera.distancia_para_mirar() * cerca)
		await _cuadros(120)
		print("zoom %.0fx · órbita %.0f m · caja %.0f m · %d gotas · emite %s" % [
			cerca, demo.camera.orbit_distance, vista._lado_de_la_caja,
			vista._rain.amount, "SI" if vista._rain.emitting else "NO"])
		_captura("lluvia_zoom_%dx" % int(cerca))

	# Y EL AGUA PICADA: la cámara sobre el río, de cerca, con temporal.
	var agua := _donde_hay_agua(demo, sim)
	if agua == Vector3.ZERO:
		print("no se encontró cauce cerca del abrigo: sin captura del agua")
		return
	await _poner(demo, vista, entorno, Weather.Kind.TEMPORAL)
	demo.camera.set_target(agua)
	# De cerca: el anillo de una gota mide un metro, y desde la órbita de trabajo no se
	# distingue de la onda del río.
	demo.camera.set_distance(demo.camera.distancia_para_mirar() * 0.25)
	await _cuadros(120)
	print("agua en %s · lluvia que pica %.2f" % [agua, vista.lluvia_vista])
	# Lo que de verdad le llega a cada material del agua: la pantalla sola engañó una
	# vez —las culebrillas eran la espuma de orilla, no las gotas— (2026-09-16).
	for material: ShaderMaterial in demo.terrain.materiales_del_agua():
		print("   material %s · lluvia_en_el_agua %s · nivel %s · celda %s" % [
			material.shader.resource_path.get_file(),
			material.get_shader_parameter("lluvia_en_el_agua"),
			material.get_shader_parameter("nivel_de_agua"),
			material.get_shader_parameter("gota_cada_m")])
	_captura("lluvia_en_el_agua")
	# Y la misma agua sin lluvia, para poder comparar.
	await _poner(demo, vista, entorno, Weather.Kind.DESPEJADO)
	await _cuadros(150)
	print("sin lluvia: pica %.2f" % vista.lluvia_vista)
	_captura("lluvia_en_el_agua_no")


## El cauce más ancho cerca del abrigo. Se busca en la rejilla del terreno, que es
## quien sabe por dónde va el agua.
func _donde_hay_agua(demo: Node, sim: Node) -> Vector3:
	var terreno: TerrainGenerator = demo.terrain
	if terreno == null:
		return Vector3.ZERO
	var casa: Vector3 = sim.home_position
	var mejor := Vector3.ZERO
	var mas_hondo := 0.3
	for dz in range(-20, 21):
		for dx in range(-20, 21):
			var punto := casa + Vector3(float(dx) * 12.0, 0.0, float(dz) * 12.0)
			var calado: float = terreno.crossing_difficulty_at(punto)
			if calado > mas_hondo:
				mas_hondo = calado
				mejor = Vector3(punto.x, terreno.get_height_at(punto), punto.z)
	return mejor


## El relieve de las texturas, con y sin, y lo que cuesta.
##
## Queja del usuario del 2026-09-16: «las texturas no tienen height map, o al menos
## no es suficiente; quiero que en los rocales haya relieve en las rocas».
func _el_relieve_del_terreno(demo: Node, sim: Node) -> void:
	var material: ShaderMaterial = demo.terrain.get_terrain_material()
	var vista: WeatherView = demo.weather_view
	var entorno: Node = demo._first_world_environment(get_root()).get_parent()
	# Con sol: bajo nubes el relieve no hace sombra y no se ve si está o no.
	await _poner(demo, vista, entorno, Weather.Kind.DESPEJADO)
	demo.camera.set_target(sim.home_position)
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	# A la órbita con la que se juega, y de cerca.
	for cerca: float in [1.0, 0.35]:
		demo.camera.set_distance(demo.camera.distancia_para_mirar() * cerca)
		await _cuadros(90)
		# ALTERNANDO en la misma corrida y el mínimo de cada uno: la primera medida
		# dio 12 pasos igual que 0 y 24 trece milisegundos más, que no es una curva
		# sino ruido (2026-09-16).
		var mejor := {0: INF, 12: INF, 24: INF}
		for vuelta in range(VUELTAS):
			for pasos: int in [0, 12, 24]:
				material.set_shader_parameter("relieve_pasos", pasos)
				await _cuadros(40)
				mejor[pasos] = minf(float(mejor[pasos]),
					RenderingServer.viewport_get_measured_render_time_gpu(vp))
		print("órbita %.0f m · GPU sin relieve %.2f ms · 12 pasos %.2f · 24 pasos %.2f" % [
			demo.camera.orbit_distance, mejor[0], mejor[12], mejor[24]])
		for pasos: int in [0, 24]:
			material.set_shader_parameter("relieve_pasos", pasos)
			await _cuadros(30)
			_captura("relieve_%dm_%d" % [int(demo.camera.orbit_distance), pasos])
	material.set_shader_parameter("relieve_pasos", Configuracion.pasos_de_relieve())

func _cuadros(cuantos: int) -> void:
	for i in range(cuantos):
		await process_frame


func _gpu(vp: RID) -> float:
	await _cuadros(40)
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0


func _captura(nombre: String) -> void:
	var shot := get_root().get_texture().get_image()
	if shot == null or shot.is_empty():
		print("sin captura: hace falta ventana")
		return
	var ruta := "user://capturas/%s.png" % nombre
	shot.save_png(ruta)
	print("captura: %s" % nombre)
