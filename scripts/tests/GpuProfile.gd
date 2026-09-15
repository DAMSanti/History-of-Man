extends SceneTree
## De dónde salen los 25 ms del terreno.
##
## La bisección a ciegas -apagar cosas y ver qué baja- se agotó: no eran los
## píxeles, ni los triángulos, ni los scripts, ni las sombras. Aquí se usa el
## medidor que trae Godot, que separa el tiempo de CPU del de GPU dentro del
## render. Eso dice de qué lado está el problema en vez de hacerlo adivinar.

const SITE_ID := 56


## `NIVELES=1`: en vez de la bisección, los niveles de la configuración (INTERFAZ §8,
## GRAFICOS §7). Comprueba que se aplican en caliente sobre la escena montada y mide
## la GPU de cada nivel y de los valores de nubes y vegetación, a 1920×1080 en
## ventana, dos vueltas y el mínimo de las dos. La spec pide dos corridas: se lanza
## dos veces.
const MODO_NIVELES := "NIVELES"
## `ARBOLES=1 ESCALON=n`: lo que cuesta el bosque de un escalón (GRAFICOS §7.1, «Lo que
## cuesta»). Un escalón por proceso, porque el bosque se monta con el mapa: el tiempo de
## montar el mapa hasta tener el bosque asentado, la VRAM, y la GPU con el bosque
## encendido y apagado —la diferencia es lo suyo— en la vista de medida y en los dos
## encuadres de juego de `BosqueCaptura`. Dos vueltas alternando, el mínimo; la spec
## pide dos corridas: se lanza dos veces.
##
## Los encuadres de juego además de la vista de medida porque ésta mira desde 75 m de
## alto, y el 3D sale de la distancia AL OJO: desde ahí no hay un árbol a menos de 40 m
## y sólo mediría impostores.
const MODO_ARBOLES := "ARBOLES"


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var niveles := OS.get_environment(MODO_NIVELES) == "1"
	var arboles := OS.get_environment(MODO_ARBOLES) == "1"
	if niveles or arboles:
		# Su configuración, nunca la del jugador. Y a 1080p en ventana: el proyecto
		# abre maximizado, y la GPU se mide a 1080p (GRAFICOS §1).
		Configuracion.ruta = "user://sondas/configuracion.cfg"
		Configuracion.por_defecto()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = Vector2i(1920, 1080)
	Engine.max_fps = 0
	if arboles:
		Configuracion.poner_ajuste("arboles", int(OS.get_environment("ESCALON")))
		# RADIO=metros: la distancia del 3D del slider, en vez de la del escalón.
		if not OS.get_environment("RADIO").is_empty():
			Configuracion.poner_ajuste("radio_3d", float(OS.get_environment("RADIO")))

	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan datos"); quit(); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if site == null:
		print("sin emplazamiento"); quit(); return

	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	var montar_desde := Time.get_ticks_msec()
	change_scene_to_file("res://scenes/demo_main.tscn")
	if arboles:
		await _arboles(montar_desde)
		quit()
		return
	for i in range(220):
		await process_frame

	var demo := current_scene
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	var home := Vector3(2048.0, 0.0, 2048.0)
	var terrain: Node = demo.terrain
	if terrain and terrain.has_method("get_height_at"):
		home.y = terrain.get_height_at(home)

	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(0.0, 75.0, 130.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()

	if niveles:
		await _niveles(demo, vp)
		quit()
		return

	print("")
	print("=== DE DONDE SALEN LOS MILISEGUNDOS (camara de juego) ===")
	print("%-26s %8s %8s %8s" % ["", "total", "cpu-rnd", "gpu-rnd"])
	await _sample(vp, "todo encendido")

	var ring: Node = demo.get_node_or_null("Alrededores")
	var pieces: Node = demo.get_node_or_null("TerrainMesh")
	if terrain:
		pieces = (terrain as Node).get_node_or_null("TerrainMesh")

	var light: DirectionalLight3D = _find_light(demo)

	if ring:
		(ring as Node3D).visible = false
		await _sample(vp, "sin contorno")
		(ring as Node3D).visible = true

	if pieces:
		(pieces as Node3D).visible = false
		await _sample(vp, "sin terreno jugable")
		(pieces as Node3D).visible = true

	if light:
		light.shadow_enabled = false
		await _sample(vp, "sin sombras")
		light.shadow_enabled = true

	# Y con un material trivial en el terreno: si el tiempo se desploma, el
	# coste esta en el shader triplanar y no en la geometria
	if pieces:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(0.4, 0.45, 0.35)
		plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var saved := {}
		for child in (pieces as Node).get_children():
			if child is MeshInstance3D:
				saved[child] = (child as MeshInstance3D).material_override
				(child as MeshInstance3D).material_override = plain
		await _sample(vp, "terreno sin shader")
		for child: Variant in saved:
			(child as MeshInstance3D).material_override = saved[child]

	# Los ajustes del proyecto: MSAA x4 Y TAA a la vez es raro -el TAA suele
	# sustituir al MSAA- y el filtro de sombras esta en calidad alta.
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _sample(vp, "sin MSAA")

	root.use_taa = false
	await _sample(vp, "sin MSAA ni TAA")
	root.use_taa = true
	root.msaa_3d = Viewport.MSAA_4X

	# Y la combinacion que propondria: escala al 75% con FSR2, que reconstruye
	# mucho mejor que el escalado bilineal
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	root.scaling_3d_scale = 0.75
	root.msaa_3d = Viewport.MSAA_DISABLED
	await _sample(vp, "FSR2 75% + sin MSAA")
	root.scaling_3d_scale = 1.0
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.msaa_3d = Viewport.MSAA_4X

	# Las dos palancas de dentro del shader: los mapas de normales duplican
	# los muestreos, y la anisotropia multiplica los texeles por fetch.
	if terrain and terrain.has_method("get_terrain_material"):
		var mat: ShaderMaterial = terrain.get_terrain_material()
		if mat:
			mat.set_shader_parameter("use_normal_maps", false)
			await _sample(vp, "sin mapas de normales")
			mat.set_shader_parameter("use_normal_maps", true)

			var sharp: float = mat.get_shader_parameter("triplanar_sharpness")
			mat.set_shader_parameter("weight_cutoff", 0.12)
			await _sample(vp, "corte de capa al 12%")
			mat.set_shader_parameter("weight_cutoff", 0.02)

	# La prueba de resolucion de antes no valia: cambiar el tamano de VENTANA
	# no cambia la resolucion a la que se dibuja el 3D. Esto si: `scaling_3d`
	# es el factor de la resolucion interna del render.
	for scale: float in [0.75, 0.5, 0.35]:
		root.scaling_3d_scale = scale
		await _sample(vp, "escala 3D al %d%%" % int(scale * 100.0))
	root.scaling_3d_scale = 1.0

	quit()


func _find_light(node: Node) -> DirectionalLight3D:
	for child in node.get_children():
		if child is DirectionalLight3D:
			return child
		var deeper := _find_light(child)
		if deeper:
			return deeper
	return null




func _sample(vp: RID, label: String) -> void:
	for i in range(25):
		await process_frame

	var frames := 60
	var start := Time.get_ticks_usec()
	var cpu := 0.0
	var gpu := 0.0
	for i in range(frames):
		await process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var total := float(Time.get_ticks_usec() - start) / float(frames) / 1000.0

	print("%-26s %7.1f  %7.1f  %7.1f   · %d tri, %d draws" % [
		label, total, cpu / frames, gpu / frames,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])


# --- los niveles de la configuración ------------------------------------------

const _NIVELES_A_MEDIR: Array[int] = [Configuracion.Nivel.BAJO, Configuracion.Nivel.MEDIO,
	Configuracion.Nivel.ALTO, Configuracion.Nivel.ULTRA]


func _niveles(demo: Node, vp: RID) -> void:
	for i in range(60):
		await process_frame
	print("")
	print("=== LOS NIVELES DE LA CONFIGURACION (raíz %s) ===" % str(root.size))
	var entorno: Node = null
	# El bosque no está en el grupo: su densidad entra al montar el mapa.
	var bosque: Forest = demo.get("forest")
	var relieve: TerrainGenerator = null
	for nodo: Node in get_nodes_in_group(Configuracion.GRUPO):
		if nodo.has_method("get_environment"):
			entorno = nodo
		elif nodo is TerrainGenerator and nodo.name == "Terreno":
			relieve = nodo
	if relieve == null and "terrain" in demo:
		relieve = demo.terrain

	# 1. EN CALIENTE: cada nivel deja el entorno como dice, sin recargar la escena.
	var escena := current_scene
	var mal := 0
	for nivel: int in [Configuracion.Nivel.BAJO, Configuracion.Nivel.ULTRA,
			Configuracion.Nivel.MEDIO]:
		Configuracion.poner_nivel(nivel as Configuracion.Nivel)
		var antes := Time.get_ticks_msec()
		Configuracion.aplicar_graficos(self)
		var tarda := Time.get_ticks_msec() - antes
		for i in range(5):
			await process_frame
		var g := Configuracion.graficos
		var fallos: Array[String] = []
		if current_scene != escena:
			fallos.append("la escena se recargó")
		if entorno == null:
			fallos.append("sin entorno en el grupo")
		else:
			var env: Environment = entorno.get_environment()
			if env.ssao_enabled != (int(g["oclusion"]) >= Configuracion.Oclusion.SSAO):
				fallos.append("ssao")
			if env.ssil_enabled != (int(g["oclusion"]) >= Configuracion.Oclusion.SSAO_Y_SSIL):
				fallos.append("ssil")
			if env.volumetric_fog_enabled != bool(g["niebla"]):
				fallos.append("niebla")
			if (entorno.get_sun() as DirectionalLight3D).shadow_enabled != bool(Configuracion.sombras()["activas"]):
				fallos.append("sombras")
		if relieve != null and relieve.get_terrain_material() != null:
			var material := relieve.get_terrain_material()
			if bool(material.get_shader_parameter("use_orm")) != bool(g["orm"]):
				fallos.append("orm")
			if bool(material.get_shader_parameter("use_normal_maps")) != bool(g["normales"]):
				fallos.append("normales")
		if not is_equal_approx(root.scaling_3d_scale, float(g["escala"])):
			fallos.append("escala")
		mal += fallos.size()
		print("en caliente · %-6s %s (aplicar: %d ms)" % [Configuracion.nombre_del_nivel(
			nivel as Configuracion.Nivel), "ok" if fallos.is_empty() else "MAL %s" % str(fallos), tarda])

	# 2. LO QUE CUESTA CADA NIVEL, dos vueltas alternando, el mínimo.
	var coste := {}
	for vuelta in range(2):
		for nivel: int in _NIVELES_A_MEDIR:
			Configuracion.poner_nivel(nivel as Configuracion.Nivel)
			Configuracion.aplicar_graficos(self)
			var gpu := await _gpu_medio(vp)
			coste[nivel] = minf(float(coste.get(nivel, INF)), gpu)
	for nivel: int in _NIVELES_A_MEDIR:
		print("nivel %-6s GPU %6.2f ms" % [Configuracion.nombre_del_nivel(
			nivel as Configuracion.Nivel), float(coste[nivel])])

	# 3. LOS VALORES DE NUBES Y VEGETACIÓN, sobre Medio.
	for pasos: int in [0, 6, 12, 20, 32]:
		var mejor := INF
		for vuelta in range(2):
			Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
			Configuracion.poner_ajuste("nubes", pasos)
			Configuracion.aplicar_graficos(self)
			mejor = minf(mejor, await _gpu_medio(vp))
		print("nubes %2d pasos      GPU %6.2f ms" % [pasos, mejor])
	for densidad: float in [0.25, 0.5, 1.0]:
		var mejor := INF
		var resiembra := 0
		for vuelta in range(2):
			Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
			# La configuración deja la densidad para el próximo mapa: aquí se siembra
			# a mano para medir, pasando antes por otra para que siembre de verdad.
			await bosque.resembrar(0.1)
			var antes := Time.get_ticks_msec()
			await bosque.resembrar(densidad)
			resiembra = maxi(resiembra, Time.get_ticks_msec() - antes)
			mejor = minf(mejor, await _gpu_medio(vp))
		print("vegetación %.2f      GPU %6.2f ms · resembrar %d ms" % [densidad, mejor, resiembra])
	Configuracion.poner_nivel(Configuracion.Nivel.MEDIO)
	Configuracion.aplicar_graficos(self)
	print("en caliente: %s" % ("TODO BIEN" if mal == 0 else "%d COSAS MAL" % mal))


# --- el bosque de cada escalón ----------------------------------------------------

func _arboles(montar_desde: int) -> void:
	var demo: Node = null
	var bosque: Forest = null
	# Con tope de reloj: con la distancia «sin límite» el bosque puede no acabar de
	# montarse en un tiempo razonable, y eso también es la medida.
	for _i in range(100000):
		await process_frame
		demo = current_scene
		if demo != null and demo.get("camera") != null and demo.get("forest") != null:
			bosque = demo.get("forest")
			if not bosque._stands.is_empty() and bosque._pending.is_empty():
				break
		if Time.get_ticks_msec() - montar_desde > 240000:
			break
	if bosque == null:
		print("no arrancó"); return
	var montar := Time.get_ticks_msec() - montar_desde
	print("bloques 3D montados %d · pendientes %d · %.0f FPS al terminar" % [bosque._live.size(),
		bosque._pending.size(), Engine.get_frames_per_second()])
	var sim: Node = demo.get("sim")
	if sim != null:
		sim.set("hour", 12.0)
	var ui: Object = demo.get("ui")
	if ui != null and ui.get("barra") != null:
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	for _i in range(60):
		await process_frame
	# Quieto: sin la banda andando ni el sol moviéndose entre medidas.
	paused = true
	var juego: OrbitalCamera = demo.get("camera")
	juego.process_mode = Node.PROCESS_MODE_ALWAYS
	bosque.process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	print("")
	print("=== EL BOSQUE, escalón %d (radio de cerca %.0f m) ===" % [bosque.escalon, bosque.radio_de_cerca()])
	print("montar el mapa hasta el bosque asentado: %d ms · VRAM %.0f MB" % [montar, vram])

	var home := Vector3(2048.0, 0.0, 2048.0)
	var terrain: Node = demo.get("terrain")
	if terrain and terrain.has_method("get_height_at"):
		home.y = terrain.get_height_at(home)
	var fija := Camera3D.new()
	fija.far = 20000.0
	demo.add_child(fija)
	fija.global_position = home + Vector3(0.0, 75.0, 130.0)
	fija.look_at(home, Vector3.UP)
	var casa: Vector3 = sim.get("home_position") if sim != null else home

	# EN CALIENTE: la distancia del slider se cambia sin volver a montar el mapa.
	if OS.get_environment("EN_CALIENTE") == "1" and bosque.escalon > 0:
		var antes := bosque.radio_de_cerca()
		var montados_antes := bosque._live.size()
		Configuracion.poner_ajuste("radio_3d", antes * 3.0)
		var desde := Time.get_ticks_msec()
		Configuracion.aplicar_graficos(self)
		for _i in range(3000):
			await process_frame
			if bosque._pending.is_empty() and not bosque._live.is_empty():
				break
		print("en caliente: %.0f m → %.0f m · bloques %d → %d · asentado en %d ms" % [antes,
			bosque.radio_de_cerca(), montados_antes, bosque._live.size(), Time.get_ticks_msec() - desde])
		Configuracion.poner_ajuste("radio_3d", antes)
		Configuracion.aplicar_graficos(self)

	for vista: Array in [["medida", -1.0, 0.0], ["juego alto", -38.0, 90.0], ["juego bajo", -12.0, 38.0]]:
		if float(vista[1]) < 0.0 and String(vista[0]) != "medida":
			juego.make_current()
			juego.set_target(casa + Vector3(60.0, 0.0, 60.0))
			juego.orbit_angle_v = float(vista[1])
			juego.set_distance(float(vista[2]))
			juego._update_camera()
		else:
			fija.make_current()
		var espera := Time.get_ticks_msec()
		for _i in range(100000):
			await process_frame
			if bosque._pending.is_empty() or Time.get_ticks_msec() - espera > 120000:
				break
		var con := INF
		var sin := INF
		var triangulos := 0
		for _vuelta in range(2):
			bosque.visible = true
			con = minf(con, await _gpu_medio(vp))
			triangulos = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			bosque.visible = false
			sin = minf(sin, await _gpu_medio(vp))
		bosque.visible = true
		print("  %-11s GPU con bosque %6.2f ms · sin %6.2f ms · el bosque %5.2f ms · %.1f M triángulos" % [
			vista[0], con, sin, con - sin, float(triangulos) / 1.0e6])


func _gpu_medio(vp: RID) -> float:
	for i in range(40):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0

