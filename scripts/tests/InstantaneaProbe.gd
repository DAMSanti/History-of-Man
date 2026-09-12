extends SceneTree
## ¿La partida restaurada es la misma que se guardó?
##
## Tarea 17 de docs/specs/LO_MISMO_MAS_DEPRISA.md. Cotejar dos corridas —una
## continua y otra arrancada de una instantánea— dice SI se separan, pero no
## dónde estaba el fallo: cualquier diferencia, por pequeña, se lo lleva todo
## por delante en una jornada. Esto compara la firma JUSTO DESPUÉS de
## restaurar, sin dar un paso, contra la que dejó la corrida continua en esa
## misma jornada. Lo que salga distinto es, literalmente, lo que la
## instantánea no trae.
##
##   DESDE=<instantánea>  FIRMAS=<fichero de firmas de la corrida continua>

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var desde := OS.get_environment("DESDE")
	var firmas_ruta := OS.get_environment("FIRMAS")
	if desde.is_empty() or firmas_ruta.is_empty():
		print("hacen falta DESDE y FIRMAS")
		quit(2)
		return

	var demo := await _arrancar()
	if demo == null:
		quit(1)
		return
	var sim: SettlementSim = demo.sim

	var fichero := FileAccess.open(desde, FileAccess.READ)
	if fichero == null:
		print("no se puede leer %s" % desde)
		quit(1)
		return
	var foto := Instantanea.desde_bytes(fichero.get_buffer(fichero.get_length()))
	if foto == null:
		print("%s no es una instantánea de esta versión" % desde)
		quit(1)
		return
	var fallos := foto.volcar(sim, demo.herds, demo._caves)
	print("")
	print("=== ¿ES FIEL LA INSTANTÁNEA? ===")
	print("restaurada la jornada %d desde %s" % [sim.day, desde.get_file()])
	for aviso: String in foto.avisos:
		print("   aviso: %s" % aviso)
	for fallo: String in fallos:
		print("   ERROR: %s" % fallo)

	var recien := FirmaDiaria.de(sim, demo.herds, demo._caves)
	var guardada := _firma_del_dia(firmas_ruta, sim.day)
	if guardada == null:
		print("en %s no hay firma de la jornada %d" % [firmas_ruta, sim.day])
		quit(2)
		return

	if recien.firma == guardada.firma:
		print("IGUALES: la partida restaurada es la que se guardó, campo por campo")
		quit(0)
		return

	print("DISTINTAS: lo que sigue es lo que la instantánea no trae")
	print("   en el resumen:")
	var claves: Array = guardada.resumen.keys()
	for clave: Variant in recien.resumen.keys():
		if not claves.has(clave):
			claves.append(clave)
	claves.sort()
	var alguna := false
	for clave: Variant in claves:
		var antes: Variant = guardada.resumen.get(clave)
		var ahora: Variant = recien.resumen.get(clave)
		if antes != ahora:
			alguna = true
			print("      %-10s guardado %s" % [str(clave), str(antes)])
			print("      %-10s restaurado %s" % ["", str(ahora)])
	if not alguna:
		print("      nada: lo que falta no se ve todavía en el resumen")
	var campos: Array = []
	for clave: Variant in guardada.detalle:
		if guardada.detalle.get(clave) != recien.detalle.get(clave):
			campos.append(clave)
	for clave: Variant in recien.detalle:
		if not guardada.detalle.has(clave):
			campos.append(clave)
	campos.sort()
	print("   en el detalle: %d campos" % campos.size())
	for campo: Variant in campos:
		print("      %s" % str(campo))
	quit(1)


func _firma_del_dia(ruta: String, dia: int) -> FirmaDiaria:
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		return null
	while not fichero.eof_reached():
		var huella := FirmaDiaria.desde_linea(fichero.get_line())
		if huella != null and huella.dia == dia:
			return huella
	return null


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
		return null
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo) or not ("herds" in demo):
		print("la escena no arranco")
		return null
	return demo
