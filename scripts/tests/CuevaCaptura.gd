extends SceneTree
## Lo que se ve al entrar en una cueva, y lo que cuesta entrar. SISTEMAS §13.
##
## **Con ventana**: con `--headless` no hay imagen que capturar, y los shaders sólo
## fallan de verdad con un dispositivo de render.
##
##   godot --path . --script res://scripts/tests/CuevaCaptura.gd
##
## Tres paredes, a 1920×1080: la de una banda con cinco pinturas, Covalanas y El
## Castillo. Deja las capturas en `user://capturas/cueva_*.png` y dice lo que tardó
## en montarse cada una, que la spec pide por debajo de 2 s.

const SALIDA := "user://capturas"


func _init() -> void:
	# EN VENTANA antes de dar el tamaño: a pantalla completa `window_set_size` no
	# hace nada y la captura sale a 3651×2054. Ver `NieblaCaptura`.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await process_frame

	var casos: Array = [
		["banda", -1, 5],
		["covalanas", 5, 0],
		["el_castillo", 1, 0],
	]
	var peor := 0.0
	var gpu_peor := 0.0
	for caso: Array in casos:
		var sim := _sim(int(caso[1]), int(caso[2]))
		var capa := CanvasLayer.new()
		root.add_child(capa)
		var sala := SalaDeLaCueva.new()
		var t := Time.get_ticks_usec()
		capa.add_child(sala)
		sala.montar(sim, 0, "Prueba: %s" % caso[0])
		for _i in range(3):
			await process_frame
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		peor = maxf(peor, ms)
		for _i in range(20):
			await process_frame
		# LO QUE CUESTA MIRARLA, como `GpuProfile`: la ventana y el `SubViewport` de
		# la sala, sumados, con la cámara quieta y la lámpara parpadeando.
		var gpu := await _gpu_de(sala)
		gpu_peor = maxf(gpu_peor, gpu)
		print("  %-12s GPU: %.2f ms por cuadro" % [caso[0], gpu])
		var imagen := root.get_texture().get_image()
		var ruta := "%s/cueva_%s.png" % [SALIDA, caso[0]]
		imagen.save_png(ruta)
		sala.imagen_de_pinturas.save_png("%s/cueva_%s_pinturas.png" % [SALIDA, caso[0]])
		print("  %-12s %d figuras · montar y primer cuadro: %.0f ms · %s" % [caso[0],
			sala.figuras_dibujadas, ms, ProjectSettings.globalize_path(ruta)])
		var t_salir := Time.get_ticks_usec()
		sala.cerrar()
		await process_frame
		print("  %-12s salir: %.0f ms" % [caso[0], (Time.get_ticks_usec() - t_salir) / 1000.0])
		capa.queue_free()
		sim.free()
		await process_frame
	print("")
	print("entrar, el peor: %.0f ms (la spec pide menos de 2000)" % peor)
	print("GPU, la peor sala: %.2f ms (el valle en Medio, 18,1 ms en este equipo; GRAFICOS §7)" % gpu_peor)
	print("TODO BIEN" if peor < 2000.0 else "NO CUMPLE")
	quit()


## Una simulación mínima con una cueva: la de una cueva con arte del catálogo
## (`arte` es su índice en [ArteDeLosDeAntes.CUEVAS]) o una sin arte con
## `pintadas` relatos de la banda en la pared.
func _sim(arte: int, pintadas: int) -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.game_seed = 20260915
	if arte >= 0:
		var cueva: Dictionary = ArteDeLosDeAntes.CUEVAS[arte]
		sim.pinturas.elementos = [{"name": cueva["nombre"], "lat": cueva["lat"],
			"lon": cueva["lon"]}]
	else:
		sim.pinturas.elementos = [{"name": "la cueva de la banda", "lat": 0.0, "lon": 0.0}]
	sim.exploracion._sabido[0] = {"explorada": true, "pintable": true}
	sim.exploracion.cueva_de_la_banda = 0
	var especies := ["ciervo", "caballo", "uro", "jabali", "ciervo"]
	for i in range(pintadas):
		var tale := Tale.hunt("Ana", especies[i % especies.size()], "el vado", 3, true, i,
			Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR))
		tale.painted = true
		tale.cueva = 0
		sim.paintings.append(tale)
	var mano := Tale.new()
	mano.kind = Tale.Kind.HITO
	mano.task = 0
	if pintadas > 0:
		mano.painted = true
		mano.cueva = 0
		sim.paintings.append(mano)
	return sim


## Tiempo de GPU medio por cuadro de la ventana más el de la sala, en 120 cuadros.
func _gpu_de(sala: SalaDeLaCueva) -> float:
	var ventana := root.get_viewport_rid()
	var vista := sala._vista.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(ventana, true)
	RenderingServer.viewport_set_measure_render_time(vista, true)
	for _i in range(30):
		await process_frame
	var suma := 0.0
	for _i in range(120):
		await process_frame
		suma += RenderingServer.viewport_get_measured_render_time_gpu(ventana) 			+ RenderingServer.viewport_get_measured_render_time_gpu(vista)
	return suma / 120.0

