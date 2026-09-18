extends SceneTree
## ¿Se acaba el mar en la raya del recuadro jugable? GRAFICOS §3, depurar del 2026-09-17.
##
## Queja del usuario: «los ríos/rías en los mapas costeros se cortan cuando llegan a las 8
## casillas que rodean la casilla principal». Esta sonda monta un valle de costa, pone la
## cámara alta mirando a la raya y captura **con el mar de fuera y sin él**, para ver la
## diferencia y para que no vuelva a colarse.
##
##   godot --path . --script res://scripts/tests/MarDeFueraCaptura.gd
##
##   SITIO=36   qué yacimiento de costa

const MAR := -120.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Guardado.carpeta = "user://sondas/mar"
	var id := 36
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))
	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("MarDeFueraCaptura: no hay sitio %d" % id)
		quit(1)
		return

	GameState.sea_level_m = MAR
	Expedition.sea_level_m = MAR
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.site = sitio

	# EL VALLE, RELLENADO, en una copia: sin el relleno del mar de hoy no hay nada bajo
	# −120 m, el juego no crea lámina de agua y aquí no habría ría que mirar. Lo hace el
	# juego al fundar; la sonda no funda, así que se lo hace ella. Y no toca el valle del
	# jugador: ver [Guardado.carpeta].
	const CARPETA := "user://sondas/mar"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA))
	var regional: HeightmapData = load(PreparaValle.RELIEVE_REGIONAL)
	var rios := RiosDeLaRegion.cargar()
	for sufijo: String in ["", "_surround"]:
		var origen := "res://data/dem/local/site_%d%s.res" % [id, sufijo]
		var copia := "%s/site_%d%s.res" % [CARPETA, id, sufijo]
		if not ResourceLoader.exists(origen):
			continue
		var datos: HeightmapData = load(origen)
		if RellenoDelMarDeHoy.poner_al_dia(datos, regional, MAR, rios):
			print("relleno puesto en site_%d%s" % [id, sufijo])
		ResourceSaver.save(datos, copia)
	Expedition.heightmap_path = "%s/site_%d.res" % [CARPETA, id]

	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	for i in range(300):
		await process_frame

	var agua: Node = demo.terrain.get_node_or_null("Water")
	print("el mar del valle: %s" % ("puesto" if agua != null else "NO ESTÁ"))
	var fuera := demo.get_node_or_null("Alrededores/MarDeFuera") as MeshInstance3D
	print("el mar de fuera: %s" % ("puesto" if fuera != null else "NO ESTÁ"))
	var camara: Node = demo.get("camera")
	var terreno: Node = demo.get("terrain")
	if camara != null and terreno != null:
		# Mirando a la raya del norte desde dentro, y alto: es donde se ve si el agua sigue.
		var ancho := float(terreno.terrain_size.x)
		var alto := float(terreno.terrain_size.y)
		# CERCA DE LA RAYA, no desde el cielo: lo que hay que juzgar es si el cauce sigue
		# igual de azul al pasar del relieve de hoy al relleno.
		var donde := Vector3(ancho * 0.5, 0.0, alto * 0.5)
		if not OS.get_environment("CERCA").is_empty():
			camara.set_target(donde)
			camara.set_distance(camara.distancia_para_mirar() * 6.0)
		else:
			camara.set_target(Vector3(ancho * 0.5, 0.0, 0.0))
			camara.set_distance(camara.max_distance)
	var ui: Node = demo.get("ui")
	if ui != null:
		ui.visible = false
	for con_mar: bool in [true, false]:
		if fuera != null:
			fuera.visible = con_mar
		for i in range(60):
			await process_frame
		var foto := get_root().get_texture().get_image()
		if foto != null:
			var ruta := "user://mar_de_fuera_%s.png" % ("con" if con_mar else "sin")
			foto.save_png(ruta)
			print("captura en %s" % ProjectSettings.globalize_path(ruta))
	quit()
