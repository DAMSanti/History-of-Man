extends SceneTree
## El agua del valle, en los encuadres que la enseñan. GRAFICOS §7.3.
##
## **Con ventana**, a 1920×1080.
##
##   godot --path . --script res://scripts/tests/AguaCaptura.gd
##   SITIO=0 MAR=30 godot --path . --script res://scripts/tests/AguaCaptura.gd
##
## Monta el valle y **elige los encuadres por los datos**, no a mano, para que sirvan
## en cualquier valle y no se muevan de una corrida a otra:
##
## - **rápido**: la celda de lámina con más caída aguas abajo;
## - **remanso**: la de lámina más ancha a su alrededor y casi sin caída;
## - **orilla**: la del borde de la lámina más cerca de la cueva;
## - **arriba**: el rápido desde la altura de gestión, como se juega;
## - **costa**, sólo si hay mar: la celda seca más cerca de la cueva que toca el agua.
##
## `MAR=metros` sube el mar de la época para tener costa en un valle que no la tiene:
## en el Paleolítico ningún valle preparado baja de 10,8 m (GRAFICOS §7.3). No toca la
## partida del jugador: la sonda escribe su configuración y sus mapas aparte.
##
## Deja `user://capturas/agua_<nivel>_<encuadre>.png`. Con `GPU=1` mide además la GPU de
## render en cada encuadre con el agua y sin ella, dos vueltas alternando y el mínimo
## (GRAFICOS §1: a 1080p, en el mismo proceso). `NIVEL=0-3` es el ajuste «Agua» desde
## que existe; antes de él, la sonda mide lo de hoy.

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute("user://capturas")
	# Su configuración y sus mapas, nunca los del jugador.
	Configuracion.ruta = "user://sondas/configuracion.cfg"
	Configuracion.por_defecto()
	Guardado.carpeta = "user://sondas/mapas"
	var nivel := -1
	if not OS.get_environment("NIVEL").is_empty() and Configuracion.graficos.has("agua"):
		nivel = int(OS.get_environment("NIVEL"))
		Configuracion.poner_ajuste("agua", nivel)
	var sitio := int(OS.get_environment("SITIO")) if not OS.get_environment("SITIO").is_empty() else SITE_ID
	if not _preparar(sitio):
		print("faltan los datos del sitio %d" % sitio); quit(1); return
	if not OS.get_environment("MAR").is_empty():
		Expedition.sea_level_m = float(OS.get_environment("MAR"))

	change_scene_to_file("res://scenes/demo_main.tscn")
	var demo: Node = null
	for _i in range(2000):
		await process_frame
		demo = current_scene
		if demo != null and demo.get("montado") == true:
			break
	if demo == null or demo.get("montado") != true:
		print("no arrancó"); quit(1); return
	var sim: Object = demo.get("sim")
	var ui: Object = demo.get("ui")
	if ui != null and ui.get("barra") != null:
		ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	# A MEDIODÍA, que es la luz de las fotos de referencia, y despejado.
	if sim != null:
		sim.set("hour", 12.0)
	for _i in range(60):
		await process_frame
	paused = true
	var camara: OrbitalCamera = demo.get("camera")
	camara.process_mode = Node.PROCESS_MODE_ALWAYS
	# Las salpicaduras se reparten y emiten en su `_process`: en pausa no salían nunca y la
	# captura de cerca de Ultra no las enseñaba (2026-09-15). En el juego no hay pausa.
	for salpicaduras: Node in demo.find_children("SalpicadurasDelRio", "", true, false):
		salpicaduras.process_mode = Node.PROCESS_MODE_ALWAYS
	var terreno: TerrainGenerator = demo.get("terrain")
	var casa: Vector3 = sim.get("home_position") if sim != null else Vector3(2048.0, 0.0, 2048.0)
	# Sin la interfaz ni el panel de rendimiento: lo que se compara con la foto es el agua.
	_ocultar_la_interfaz(demo)

	var encuadres := encuadres_de(terreno, casa)
	if encuadres.is_empty():
		print("este valle no tiene lámina de río"); quit(1); return
	var vp := root.get_viewport_rid()
	var medir := OS.get_environment("GPU") == "1"
	if medir:
		RenderingServer.viewport_set_measure_render_time(vp, true)
	# CALIENTE=n: se monta con NIVEL y, ya montado, se pasa al nivel n sin volver a montar
	# el mapa. Lo que se captura es n: si se aplica en caliente, se ve (GRAFICOS §7.3).
	if not OS.get_environment("CALIENTE").is_empty():
		nivel = int(OS.get_environment("CALIENTE"))
		var desde := Time.get_ticks_msec()
		Configuracion.poner_ajuste("agua", nivel)
		Configuracion.aplicar_graficos(self)
		for _i in range(30):
			await process_frame
		print("en caliente al nivel %d: %d ms" % [nivel, Time.get_ticks_msec() - desde])
	var etiqueta := "hoy" if nivel < 0 else str(nivel)
	# Otro sitio, otro nombre: la costa de prueba del sitio 0 pisaba las capturas del 56 del
	# mismo nivel y la hoja de fotos mezcló los dos valles (2026-09-15).
	if sitio != SITE_ID:
		etiqueta = "s%d_%s" % [sitio, etiqueta]
	if not OS.get_environment("CALIENTE").is_empty():
		etiqueta += "_caliente"
	# TERMINO=1-7: un término del agua del terreno en gris. Ver `ver_termino` en el shader.
	if not OS.get_environment("TERMINO").is_empty() and terreno._material_manager != null:
		terreno._material_manager.get_material().set_shader_parameter("ver_termino", int(OS.get_environment("TERMINO")))
		etiqueta += "_termino" + OS.get_environment("TERMINO")
	# MASCARA=1: la espuma en rojo, para ver dónde sale (GRAFICOS §7.3, criterio de la orilla).
	if OS.get_environment("MASCARA") == "1" and terreno._material_manager != null:
		terreno._material_manager.get_material().set_shader_parameter("ver_espuma", true)
		etiqueta += "_mascara"
	print("")
	print("=== EL AGUA, sitio %d, mar %.0f m, nivel %s ===" % [sitio, Expedition.sea_level_m, etiqueta])
	for nombre: String in encuadres:
		# SOLO_ENCUADRE=nombre: sólo ése, para no gastar disco ni tiempo en los demás.
		if not OS.get_environment("SOLO_ENCUADRE").is_empty() and nombre != OS.get_environment("SOLO_ENCUADRE"):
			continue
		var e: Dictionary = encuadres[nombre]
		camara.set_target(e["punto"])
		camara.orbit_angle_h = float(e["rumbo"])
		camara.orbit_angle_v = float(e["angulo"])
		camara.set_distance(float(e["distancia"]))
		camara._update_camera()
		for _i in range(90):
			await process_frame
		var ruta := "user://capturas/agua_%s_%s.png" % [etiqueta, nombre]
		# UNA CAPTURA VACÍA SE DICE: con la ventana minimizada o tapada el motor no pinta
		# y el PNG sale de cero bytes sin ningún error (visto el 2026-09-15).
		var imagen := root.get_texture().get_image()
		for _reintento in range(10):
			if imagen != null and not imagen.is_empty() and imagen.get_pixel(960, 540).a > 0.0:
				break
			await process_frame
			imagen = root.get_texture().get_image()
		if imagen == null or imagen.is_empty():
			print("  %-8s CAPTURA VACÍA: ¿la ventana está minimizada o tapada?" % nombre)
			continue
		var error := imagen.save_png(ruta)
		if error != OK or FileAccess.get_file_as_bytes(ruta).size() == 0:
			print("  %-8s NO SE GUARDÓ (%s, %d x %d)" % [nombre, error_string(error), imagen.get_width(), imagen.get_height()])
		# SECUENCIA=n: n capturas más del mismo encuadre, cada 0,6 s, para ver que la espuma
		# nace y se deshace y no sólo se desplaza (vuelta del usuario del 2026-09-15).
		var en_secuencia := int(OS.get_environment("SECUENCIA")) if not OS.get_environment("SECUENCIA").is_empty() else 0
		for paso_de_secuencia in range(en_secuencia):
			var hasta := Time.get_ticks_msec() + 600
			while Time.get_ticks_msec() < hasta:
				await process_frame
			var otra := root.get_texture().get_image()
			if otra != null and not otra.is_empty():
				otra.save_png(ruta.replace(".png", "_t%d.png" % (paso_de_secuencia + 1)))
		var linea := "  %-8s (%.0f, %.0f) %s" % [nombre, e["punto"].x, e["punto"].z, ProjectSettings.globalize_path(ruta)]
		if medir:
			var con := INF
			var sin := INF
			for _vuelta in range(2):
				_agua_visible(terreno, true)
				con = minf(con, await _gpu_medio(vp))
				_agua_visible(terreno, false)
				sin = minf(sin, await _gpu_medio(vp))
			_agua_visible(terreno, true)
			linea += "\n           GPU con agua %6.2f ms · sin %6.2f ms · el agua %5.2f ms" % [con, sin, con - sin]
		print(linea)
	quit()


## Los encuadres, elegidos por los mapas del terreno. Ver la cabecera.
static func encuadres_de(terreno: TerrainGenerator, casa: Vector3) -> Dictionary:
	var maps := terreno.sample_maps()
	var res: int = maps["resolution"]
	var altura: PackedFloat32Array = maps["height"]
	var lamina: PackedFloat32Array = maps["river"]
	var extension: Vector2 = maps["extent"]
	var origen: Vector2 = maps["origin"]
	var agua_y: float = maps["water_y"]
	var flujo := terreno._flow_map
	if res <= 1 or lamina.is_empty():
		return {}
	var paso := extension.x / float(res - 1)
	var margen := int(ceil(300.0 / paso))
	var mejor_rapido := -INF
	var rapido := -1
	var mejor_remanso := -INF
	var remanso := -1
	var mejor_orilla := INF
	var orilla := -1
	var mejor_costa := INF
	var costa := -1
	for gz in range(margen, res - margen):
		for gx in range(margen, res - margen):
			var i := gz * res + gx
			var mundo := Vector3(origen.x + float(gx) * paso, altura[i], origen.y + float(gz) * paso)
			var lejos := Vector2(mundo.x - casa.x, mundo.z - casa.z).length()
			if altura[i] > agua_y and costa_toca_el_agua(altura, res, gx, gz, agua_y):
				if lejos < mejor_costa:
					mejor_costa = lejos
					costa = i
			if lamina[i] <= 0.2:
				continue
			var f: Vector2 = flujo[i] if i < flujo.size() else Vector2.ZERO
			var caida := caida_aguas_abajo(altura, res, gx, gz, f, paso)
			if lamina[i] > 0.6 and f.length() > 0.1 and caida > mejor_rapido:
				mejor_rapido = caida
				rapido = i
			if lamina[i] > 0.8 and caida < 0.01:
				var ancho := 0
				for dz in range(-4, 5):
					for dx in range(-4, 5):
						if lamina[(gz + dz) * res + gx + dx] > 0.8:
							ancho += 1
				if float(ancho) > mejor_remanso:
					mejor_remanso = float(ancho)
					remanso = i
			if lamina[i] < 0.45 and lejos < mejor_orilla:
				var junto_al_agua := false
				for dz in range(-3, 4):
					for dx in range(-3, 4):
						if lamina[(gz + dz) * res + gx + dx] > 0.8:
							junto_al_agua = true
				if junto_al_agua:
					mejor_orilla = lejos
					orilla = i
	var salida := {}
	for par: Array in [["rápido", rapido, -35.0, 55.0], ["remanso", remanso, -38.0, 70.0],
			["orilla", orilla, -32.0, 40.0], ["arriba", rapido, -50.0, 180.0], ["costa", costa, -35.0, 110.0],
			["rápido de cerca", rapido, -25.0, 16.0], ["costa de cerca", costa, -22.0, 30.0]]:
		var i: int = par[1]
		if i < 0:
			continue
		var gx := i % res
		var gz := i / res
		var f: Vector2 = flujo[i] if i < flujo.size() else Vector2.ZERO
		# De través a la corriente: el agua cruza el encuadre, que es como se lee que corre.
		var rumbo := rad_to_deg(atan2(-f.y, f.x)) if f.length() > 0.1 else 35.0
		var nombre := String(par[0]).replace("á", "a").replace(" ", "_")
		var punto := Vector3(origen.x + float(gx) * paso, altura[i], origen.y + float(gz) * paso)
		# DEL LADO ABIERTO: de las dos márgenes, desde la que tiene el suelo más bajo donde
		# queda el ojo. En un cañón, desde la otra la cámara acababa pegada a la ladera.
		rumbo = lado_abierto(terreno, punto, rumbo, float(par[2]), float(par[3]))
		salida[nombre] = {"punto": punto, "rumbo": rumbo, "angulo": par[2], "distancia": par[3]}
	return salida


## El rumbo de cámara, de los dos de través a la corriente, cuyo ojo cae sobre suelo más
## bajo respecto al punto. Ver [OrbitalCamera._update_camera] para la órbita.
static func lado_abierto(terreno: TerrainGenerator, punto: Vector3, rumbo: float,
		angulo: float, distancia: float) -> float:
	var mejor := rumbo
	var mas_bajo := INF
	for r: float in [rumbo, rumbo + 180.0]:
		var ojo := punto + Vector3(sin(deg_to_rad(r)), 0.0, cos(deg_to_rad(r))) 			* distancia * cos(deg_to_rad(angulo))
		var suelo := terreno.get_height_at(ojo) - punto.y
		if suelo < mas_bajo:
			mas_bajo = suelo
			mejor = r
	return mejor


func _ocultar_la_interfaz(demo: Node) -> void:
	for nodo: Node in demo.find_children("*", "CanvasLayer", true, false):
		(nodo as CanvasLayer).visible = false
	for nodo: Node in demo.find_children("*", "Control", false, false):
		(nodo as Control).visible = false


## Cuánto baja el cauce dos celdas aguas abajo, en unidades de altura por unidad de mundo.
static func caida_aguas_abajo(altura: PackedFloat32Array, res: int, gx: int, gz: int,
		flujo: Vector2, paso: float) -> float:
	if flujo.length() < 0.1:
		return 0.0
	var d := flujo.normalized()
	var nx := clampi(gx + roundi(d.x * 2.0), 0, res - 1)
	var nz := clampi(gz + roundi(d.y * 2.0), 0, res - 1)
	return (altura[gz * res + gx] - altura[nz * res + nx]) / (2.0 * paso)


static func costa_toca_el_agua(altura: PackedFloat32Array, res: int, gx: int, gz: int, agua_y: float) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if altura[(gz + d.y) * res + gx + d.x] < agua_y:
			return true
	return false


## Enciende o apaga TODA el agua: la del cauce, que va en el shader del terreno, y el mar.
func _agua_visible(terreno: TerrainGenerator, visible: bool) -> void:
	var material: ShaderMaterial = terreno._material_manager.get_material() 		if terreno._material_manager != null else null
	if material != null:
		material.set_shader_parameter("use_rivers", visible)
	if terreno._water_mesh != null:
		terreno._water_mesh.visible = visible
	# Y la lámina y las salpicaduras de Alto y Ultra, que van en nodos aparte: sin
	# apagarlas, «sin agua» seguía pintando la lámina y el agua salía de coste cero.
	if terreno.malla.lamina != null:
		terreno.malla.lamina.visible = visible and int(Configuracion.graficos.get("agua", 1)) >= 2
	for salpicaduras: Node in terreno.get_parent().find_children("SalpicadurasDelRio", "", true, false):
		(salpicaduras as Node3D).visible = visible and int(Configuracion.graficos.get("agua", 1)) >= 3


func _gpu_medio(vp: RID) -> float:
	for i in range(40):
		await process_frame
	var gpu := 0.0
	for i in range(60):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / 60.0


func _preparar(sitio: int) -> bool:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % sitio) \
		if ResourceLoader.exists("res://data/dem/local/site_%d.res" % sitio) else null
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == sitio:
			site = s
	if local == null or site == null:
		return false
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % sitio
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))
	return true
