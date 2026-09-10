extends SceneTree
## Caza el fotograma de mil milisegundos y dice quién se lo comió.
##
## La queja: «algunos frames están aceptables —todo lo que sea menor a 100 ms de
## momento me vale— pero cada segundo o así llega algún frame de 1000 ms».
##
## Un tirón así no sale en una media, porque la media está bien: ése es el
## problema. Aquí se enciende [Cronometro] —lo mismo que enseña el panel de F3—
## y se juega un rato, y al final se vuelcan los peores fotogramas con su
## desglose.
##
##   VEL=6 DIAS=4 LIMITE=100

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	sim.time_scale = 6.0
	if not OS.get_environment("VEL").is_empty():
		sim.time_scale = float(OS.get_environment("VEL"))

	Cronometro.limite_ms = 100.0
	if not OS.get_environment("LIMITE").is_empty():
		Cronometro.limite_ms = float(OS.get_environment("LIMITE"))
	# El panel de F3 tambien vacia la bandeja de picos —para eso esta— y se
	# los quitaria a la sonda. Se aparta: su `_process` corta si no se ve.
	for nodo: Node in get_root().find_children("*", "PerformanceOverlay", true, false):
		(nodo as CanvasLayer).visible = false

	Cronometro.activo = true
	Cronometro.reinicia()

	var dias := 4
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	var cuadros := 0
	var t0 := Time.get_ticks_msec()
	var recogidos: Array[Dictionary] = []
	while sim.day < primero + dias:
		await process_frame
		cuadros += 1
		for pico: Dictionary in Cronometro.picos:
			recogidos.append(pico)
		Cronometro.picos.clear()
	var corridos := float(Time.get_ticks_msec() - t0) / 1000.0
	Cronometro.activo = false

	print("")
	print("motor: %d cuadros de _process de la escena" % Engine.get_process_frames())
	print("cepo: %d cuadros vistos · medio %.1f ms · peor %.1f ms" % [
		Cronometro.cuadros(), Cronometro.media_ms(), Cronometro.peor_ms()])
	print("=== %d cuadros en %.0f s · %d tirones de mas de %.0f ms ===" % [
		cuadros, corridos, recogidos.size(), Cronometro.limite_ms])
	if recogidos.is_empty():
		print("ninguno")
		quit()
		return
	print("uno cada %.2f s de reloj, uno de cada %d cuadros" % [
		corridos / float(recogidos.size()),
		int(float(cuadros) / float(recogidos.size()))])

	# Lo que de verdad contesta la pregunta: sumando TODOS los tirones, en que
	# tramo se va el tiempo. Un tramo que sale en los treinta tirones pesa mas
	# que uno carisimo que salio una vez.
	var suma: Dictionary = {}
	var veces: Dictionary = {}
	var total_tirones := 0.0
	for pico: Dictionary in recogidos:
		total_tirones += float(pico["total"])
		for tramo: Dictionary in (pico["desglose"] as Array):
			var nombre: String = tramo["tramo"]
			suma[nombre] = float(suma.get(nombre, 0.0)) + float(tramo["ms"])
			veces[nombre] = int(veces.get(nombre, 0)) + int(tramo["veces"])

	print("")
	print("--- SUMANDO TODOS LOS TIRONES (%.0f ms en total) ---" % total_tirones)
	var orden: Array[String] = []
	for nombre: String in suma:
		orden.append(nombre)
	orden.sort_custom(func(a: String, b: String) -> bool:
		return float(suma[a]) > float(suma[b]))
	var explicado := 0.0
	for nombre: String in orden:
		var ms: float = suma[nombre]
		explicado += ms
		print("   %8.0f ms %3.0f %%  %-38s x%d" % [
			ms, 100.0 * ms / maxf(total_tirones, 0.001), nombre, int(veces[nombre])])
	print("   %8.0f ms %3.0f %%  SIN MARCAR (fuera de lo instrumentado)" % [
		total_tirones - explicado,
		100.0 * (total_tirones - explicado) / maxf(total_tirones, 0.001)])

	print("")
	print("--- LOS TRES PEORES, UNO A UNO ---")
	recogidos.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["total"]) > float(b["total"]))
	for i in range(mini(3, recogidos.size())):
		var pico: Dictionary = recogidos[i]
		print("   %.0f ms · %s" % [float(pico["total"]), String(pico.get("etiqueta", ""))])
		for tramo: Dictionary in (pico["desglose"] as Array):
			if float(tramo["ms"]) < 1.0:
				break
			print("      %7.1f ms  %-38s x%d" % [
				float(tramo["ms"]), String(tramo["tramo"]), int(tramo["veces"])])
	quit()


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
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo
