extends SceneTree
## El valle de un yacimiento de la costa, antes y después de rellenar el mar de hoy.
## GRAFICOS §3, depurar del 2026-09-17, tarea 8: las capturas las juzga el usuario.
##
## Monta el valle del sitio que se le diga con el mar del Paleolítico y captura dos veces
## la MISMA vista: una con el relleno deshecho —el mar de hoy a cota cero, que es lo que
## el usuario vio— y otra con el suelo de la época puesto. La cámara se pone en la orilla
## de hoy mirando a la plataforma, que es desde donde se ve la diferencia.
##
##   godot --path . --script res://scripts/tests/RellenoCaptura.gd
##
##   SITIO=36    qué yacimiento (36, 47 o 49 son los de costa ya preparados)
##
## No toca los valles del jugador: trabaja sobre una copia en `user://sondas`.

const MAR := -120.0
const CARPETA := "user://sondas/relleno"


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var id := 36
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))

	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("RellenoCaptura: no hay sitio %d" % id)
		quit(1)
		return

	# UNA COPIA DEL VALLE, que las sondas no tocan los datos del jugador.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	for sufijo: String in ["", "_surround"]:
		var origen := "res://data/dem/local/site_%d%s.res" % [id, sufijo]
		var copia := "%s/site_%d%s.res" % [CARPETA, id, sufijo]
		if ResourceLoader.exists(origen) and not ResourceLoader.exists(copia):
			var datos: HeightmapData = load(origen)
			ResourceSaver.save(datos, copia)

	GameState.sea_level_m = MAR
	Expedition.sea_level_m = MAR
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.site = sitio
	Guardado.carpeta = "user://sondas/relleno/partida"

	Expedition.heightmap_path = "%s/site_%d.res" % [CARPETA, id]
	var prepara := PreparaValle.new()
	prepara.carpeta_de_los_valles = CARPETA
	var valle: HeightmapData = await prepara.preparar(self, sitio)
	if valle == null:
		print("RellenoCaptura: no se pudo preparar el valle %d" % id)
		quit(1)
		return
	var del_mar := 0
	for v in valle.mar_de_hoy:
		del_mar += v
	print("=== VALLE %d (%s) ===" % [id, sitio.display_name()])
	print("%d x %d a %.0f m · mar de hoy: %d celdas (%.1f %%) · cotas %.0f..%.0f" % [
		valle.width, valle.height, valle.meters_per_sample, del_mar,
		100.0 * float(del_mar) / float(valle.width * valle.height),
		valle.min_elevation, valle.max_elevation])
	if del_mar == 0:
		print("RellenoCaptura: este valle no tiene mar de hoy; elige otro")
		quit(1)
		return

	# ANTES: el relleno deshecho, que es el valle tal como lo daba el LiDAR.
	var regional: HeightmapData = load(PreparaValle.RELIEVE_REGIONAL)
	var rios := RiosDeLaRegion.cargar()
	RellenoDelMarDeHoy.poner_al_dia(valle, regional, 0.0, rios)
	ResourceSaver.save(valle, Expedition.heightmap_path)
	_volcar(valle, sitio, "antes")
	await _capturar(valle, sitio, "antes")

	# DESPUÉS: con el suelo de la época.
	RellenoDelMarDeHoy.poner_al_dia(valle, regional, MAR, rios)
	ResourceSaver.save(valle, Expedition.heightmap_path)
	print("rellenado: cotas %.0f..%.0f" % [valle.min_elevation, valle.max_elevation])
	_volcar(valle, sitio, "despues")
	await _capturar(valle, sitio, "despues")
	quit()


## El relieve del mar de hoy, en gris, y cuánto varía: la captura del juego puede engañar
## —el color de la orilla, el plano del agua—, y esto mira el dato.
func _volcar(valle: HeightmapData, sitio: Site, nombre: String) -> void:
	var lo := INF
	var hi := -INF
	var suma := 0.0
	var cuantas := 0
	for i in range(valle.elevations.size()):
		if valle.mar_de_hoy[i] == 0:
			continue
		var e := valle.elevations[i]
		lo = minf(lo, e)
		hi = maxf(hi, e)
		suma += e
		cuantas += 1
	var media := suma / maxf(float(cuantas), 1.0)
	var acum := 0.0
	for i in range(valle.elevations.size()):
		if valle.mar_de_hoy[i] == 1:
			acum += pow(valle.elevations[i] - media, 2.0)
	print("%s · relleno: %d celdas · cotas %.1f..%.1f · media %.1f · típica %.1f m" % [
		nombre, cuantas, lo, hi, media, sqrt(acum / maxf(float(cuantas), 1.0))])
	var imagen := Image.create(valle.width, valle.height, false, Image.FORMAT_RGB8)
	for z in range(valle.height):
		for x in range(valle.width):
			var e := valle.elevations[z * valle.width + x]
			var t := clampf((e - valle.min_elevation)
				/ maxf(valle.max_elevation - valle.min_elevation, 1.0), 0.0, 1.0)
			imagen.set_pixel(x, z, Color(t, t, t))
	imagen.save_png("user://relleno_%d_%s_cotas.png" % [sitio.id, nombre])


## Monta el valle, pone la cámara en la orilla de hoy mirando al mar de la época y guarda
## el png.
func _capturar(valle: HeightmapData, sitio: Site, nombre: String) -> void:
	# La malla guardada se borra: la sonda captura dos relieves con el MISMO mar, que es
	# justo lo que el sello de la caché no distinguía hasta hoy.
	var malla := MallaDelTerreno.ruta_de_la_cache(Expedition.heightmap_path, "", 825)
	if not malla.is_empty() and FileAccess.file_exists(ProjectSettings.globalize_path(malla)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(malla))
	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	await process_frame
	await process_frame
	for i in range(120):
		await process_frame
	var camara: Node = demo.get("camera")
	var terreno: Node = demo.get("terrain")
	if camara != null and terreno != null:
		# La orilla de hoy: la celda de mar más cercana a tierra en la fila del medio.
		var mitad := valle.height / 2
		var orilla := valle.width - 1
		for x in range(valle.width):
			if valle.mar_de_hoy[mitad * valle.width + x] == 1:
				orilla = x
				break
		var metros := valle.meters_per_sample
		var centro := Vector3((float(orilla) - float(valle.width) * 0.5) * metros, 0.0,
			(float(mitad) - float(valle.height) * 0.5) * metros)
		camara.set_target(centro)
		# Lo más lejos que llega la cámara: el relleno son cientos de metros de terreno, y
		# de cerca no se juzga si tiene relieve o no.
		camara.set_distance(camara.max_distance)
	var ui: Node = demo.get("ui")
	if ui != null:
		ui.visible = false
	for i in range(90):
		await process_frame
	var foto := get_root().get_texture().get_image()
	if foto != null:
		var ruta := "user://relleno_%d_%s.png" % [sitio.id, nombre]
		foto.save_png(ruta)
		print("captura %s en %s" % [nombre, ProjectSettings.globalize_path(ruta)])
	demo.queue_free()
	await process_frame
