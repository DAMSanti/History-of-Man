extends SceneTree
## EL RELIEVE DEL SUELO, DE CERCA. GRAFICOS §7.7.
##
## Capta el terreno a ras, con el relieve encendido a tope y **sin vegetación ni árboles
## delante**, que es la única forma de juzgar una textura del suelo: en la vista de juego la
## tapa la hierba.
##
## Sirve para el antes y el después de que la altura pasara a salir del mapa de altura en
## vez del brillo del dibujo, y para elegir texturas nuevas.
##
## *(La primera versión plantaba una capa sintética —franja oscura plana, grieta clara
## honda— para delatar de dónde salía el relieve. Reconstruir los tres `Texture2DArray` con
## una capa cambiada rompió los colores de todas y la captura salió inservible; la pregunta
## la contesta mejor y más barato `tools/_Altura.gd`, que mide la correlación entre brillo y
## altura capa por capa: 0,02 en el roquedo calizo.)*
##
##   godot --path . --script res://scripts/tests/TexturasCaptura.gd
##
##   SITIO=56      en qué valle
##   NOMBRE=antes  cómo se llama la captura

const LADO := 1024
## Cuántas franjas y grietas caben en la tesela. Cuatro de cada una: bastantes para verlas
## sin que se hagan rayas finas a la distancia de juego.
const FRANJAS := 4


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/texturas"
	var id := 56
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))
	var nombre := OS.get_environment("NOMBRE")
	if nombre.is_empty():
		nombre = "antes"

	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("TexturasCaptura: no hay sitio %d" % id)
		quit(1)
		return
	Expedition.site = sitio
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % id

	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	for i in range(240):
		await process_frame

	# EL RELIEVE, ENCENDIDO Y A TOPE: en Bajo y Medio está apagado (0 pasos), y lo que se
	# viene a mirar es justo eso.
	var terreno: Node = demo.get("terrain")
	var material := terreno.get_terrain_material() as ShaderMaterial
	if material == null:
		print("TexturasCaptura: el terreno no tiene material")
		quit(1)
		return
	# CON LUZ PLANA, si se pide: sin sombra direccional la textura se ve tal cual, sin que
	# el relieve del propio terreno la tape. Decisión del usuario del 2026-09-17: las dos
	# cosas, una para ver el bulto y otra para ver el color.
	if OS.get_environment("LUZ") == "plana":
		for nodo: Node in get_root().find_children("*", "DirectionalLight3D", true, false):
			(nodo as DirectionalLight3D).shadow_enabled = false
			(nodo as DirectionalLight3D).light_energy = 1.2
		print("luz plana: sin sombras")
	material.set_shader_parameter("relieve_pasos", 24)
	# EL RELIEVE DEL CANCHAL, para elegirlo sobre capturas: multiplica el de esa capa y
	# deja las demás como están. Ver [TerrainLayers.reliefs_in_order].
	if not OS.get_environment("CANCHAL").is_empty():
		var fuerzas := TerrainLayers.reliefs_in_order()
		fuerzas[TerrainLayers.Layer.CANCHAL] = float(OS.get_environment("CANCHAL"))
		material.set_shader_parameter("layer_relieve", fuerzas)
		print("canchal con relieve x%s" % OS.get_environment("CANCHAL"))
	material.set_shader_parameter("relieve_de_la_tesela", 0.12)
	# SIN NADA DELANTE: la hierba y el bosque tapan el suelo, que es lo que se viene a ver.
	Configuracion.poner_ajuste("vegetacion", 0.0)
	Configuracion.poner_ajuste("arboles", 0)
	Configuracion.aplicar_graficos(self)
	for i in range(60):
		await process_frame

	# AL ROQUEDO Y DE CERCA. En la pradera el relieve de la textura casi no se ve —la
	# hierba no tiene grietas—; donde se juzga es en la piedra, que además es la capa donde
	# el dibujo y la altura menos se parecen (correlación 0,02, `tools/_Altura.gd`). Se
	# busca el punto más empinado del recuadro, que es donde el terreno pone roquedo.
	var camara: Node = demo.get("camera")
	if camara != null:
		# Con la hojarasca se mira al BOSQUE, que es donde vive: su peso sale del peso del
		# suelo de bosque, así que en un canchal no hay hojas que caer.
		if not OS.get_environment("OTONO").is_empty():
			var ancho := float(terreno.terrain_size.x)
			var medio := Vector3(ancho * 0.5, 0.0, ancho * 0.5)
			medio.y = terreno.get_height_at(medio)
			camara.set_target(medio)
		elif not OS.get_environment("GRADOS").is_empty():
			camara.set_target(_con_pendiente(terreno, float(OS.get_environment("GRADOS"))))
		else:
			camara.set_target(_lo_mas_empinado(terreno))
		camara.set_distance(camara.min_distance * 2.5)
	# AL MEDIODÍA: a las seis de la mañana la ladera que se busca —la más empinada— cae en
	# sombra y la captura sale negra. Una textura no se juzga a contraluz.
	var sim: Node = demo.get("sim")
	if sim != null:
		sim.set("hour", 12.0)
	var ui: Node = demo.get("ui")
	if ui != null:
		ui.visible = false
	for i in range(60):
		await process_frame
	for i in range(90):
		await process_frame
	# Y LA HOJARASCA DEL OTOÑO, EN EL ÚLTIMO MOMENTO: `WeatherView` reescribe ese uniforme
	# cada cuadro con lo que diga la estación de la partida —primavera aquí—, así que
	# ponerlo al principio no servía de nada (visto el 2026-09-18).
	if not OS.get_environment("OTONO").is_empty():
		# POR LA VÍA BUENA: se pone la ESTACIÓN, no el uniforme. `WeatherView` lo reescribe
		# cada cuadro con lo que diga la temporada, así que ponerlo a mano no dura nada
		# (dos intentos perdidos el 2026-09-18 antes de caer).
		var sim2: Node = demo.get("sim")
		if sim2 != null and sim2.get("temporada") != null:
			sim2.temporada.asentar(Subsistence.Season.OTONO)
			print("temporada puesta en otoño")
		for i in range(30):
			await process_frame
	var foto := get_root().get_texture().get_image()
	if foto != null:
		var ruta := "user://texturas_%s.png" % nombre
		foto.save_png(ruta)
		print("captura en %s" % ProjectSettings.globalize_path(ruta))
	quit()


## El punto cuya pendiente se acerca más a la que se pide, en grados: ahí es donde el
## terreno pinta la capa que se quiere mirar. Sin pedir nada, el más empinado del recuadro.
##
## Hace falta porque **el canchal ocupa el 2 % del valle** (medido con `_Pendientes`): sin
## buscarlo, la cámara cae siempre en la peña o en el prado y no hay nada que juzgar.
func _con_pendiente(terreno: Node, grados: float) -> Vector3:
	var ancho := float(terreno.terrain_size.x)
	var alto := float(terreno.terrain_size.y)
	var paso := ancho / 96.0
	var busca := 1.0 - cos(deg_to_rad(grados))
	var mejor := Vector3(ancho * 0.5, 0.0, alto * 0.5)
	var cerca := INF
	for z in range(4, 92):
		for x in range(4, 92):
			var p := Vector3(float(x) * paso, 0.0, float(z) * paso)
			var aqui: float = terreno.get_height_at(p)
			var dx: float = (terreno.get_height_at(p + Vector3(paso, 0.0, 0.0)) - aqui) / paso
			var dz: float = (terreno.get_height_at(p + Vector3(0.0, 0.0, paso)) - aqui) / paso
			var n := Vector3(-dx, 1.0, -dz).normalized()
			var s := 1.0 - absf(n.y)
			if absf(s - busca) < cerca:
				cerca = absf(s - busca)
				mejor = Vector3(p.x, aqui, p.z)
	print("mirando a %.0f° en (%.0f, %.0f)" % [grados, mejor.x, mejor.z])
	return mejor


## El punto más empinado del recuadro: donde el terreno pinta roca. Se mira en rejilla
## gruesa, que es de sobra para encontrar una ladera.
func _lo_mas_empinado(terreno: Node) -> Vector3:
	var ancho := float(terreno.terrain_size.x)
	var alto := float(terreno.terrain_size.y)
	var paso := ancho / 48.0
	var mejor := Vector3(ancho * 0.5, 0.0, alto * 0.5)
	var mas := -1.0
	for z in range(4, 44):
		for x in range(4, 44):
			var p := Vector3(float(x) * paso, 0.0, float(z) * paso)
			var aqui: float = terreno.get_height_at(p)
			var cuesta: float = absf(aqui - terreno.get_height_at(p + Vector3(paso, 0.0, 0.0))) 				+ absf(aqui - terreno.get_height_at(p + Vector3(0.0, 0.0, paso)))
			if cuesta > mas:
				mas = cuesta
				mejor = Vector3(p.x, aqui, p.z)
	print("lo más empinado: (%.0f, %.0f) con %.1f m de desnivel por %.0f m"
		% [mejor.x, mejor.z, mas, paso])
	return mejor
