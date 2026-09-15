extends SceneTree
## El abrigo visto de cerca: la hoguera, la gente y la boca de la cueva.
##
## Tres cosas que sólo se comprueban mirando: que la hoguera esté delante de la
## boca y alumbre de noche, que la banda se reparta —dentro a dormir, en la
## campa a lo demás— en vez de apilarse en un punto, y que el bosque llegue
## hasta la puerta.
##
##   HORA=22      a qué hora mirar
##   ORBITA=45    a qué distancia poner la cámara

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

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
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(60):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var camera: Node = demo.camera if "camera" in demo else null
	if sim == null or camera == null:
		print("sin simulacion o camara"); quit(); return

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	# El hogar, dado por levantado y encendido: lo que se mira aquí es cómo se
	# ve, no cuánto tarda la banda en construirlo. Y con él TODAS las obras del
	# abrigo, que desde el 2026-09-13 se ven en el terreno —secadero, paraviento,
	# lavadero y los troncos del corro, ver [ObrasDelAbrigo]— y sólo se pueden
	# comprobar mirándolas.
	for kind: int in CampProjects.all():
		sim.camp_built[kind] = true
	sim.hearth_lit = true

	var hour := 22.0
	if not OS.get_environment("HORA").is_empty():
		hour = float(OS.get_environment("HORA"))
	sim.hour = hour

	var orbit := 45.0
	if not OS.get_environment("ORBITA").is_empty():
		orbit = float(OS.get_environment("ORBITA"))

	print("")
	print("abrigo en %s" % sim.home_position)
	print("dentro   %s" % sim.home_inside)
	print("campa    %s" % sim.home_forecourt)

	camera.set_target(sim.home_forecourt if sim.home_forecourt != Vector3.ZERO
		else sim.home_position)
	# Por debajo del tope de acercamiento del juego si se pide: las obras del
	# abrigo son de dos metros y desde los cuarenta de la partida no se
	# distinguen. Es una sonda mirando una obra, no un encuadre jugable.
	if orbit < camera.min_distance:
		camera.min_distance = orbit
	camera.set_distance(orbit)
	camera.orbit_angle_v = -24.0
	_hide_ui(demo)

	# La partida arranca en pausa: sin dejarla correr nadie cambia de estado y
	# todo el mundo se queda como se fundó. Se le clava la hora a cada cuadro
	# para mirar siempre el mismo momento del día.
	sim.time_scale = 3.0
	var settle := Time.get_ticks_msec()
	while Time.get_ticks_msec() - settle < 12000:
		await process_frame
		sim.hour = hour

	var inside := 0
	var outside := 0
	for person: Inhabitant in sim.people:
		if person.position.distance_to(sim.home_position) > 40.0:
			continue
		if sim.home_inside != Vector3.ZERO \
				and person.position.distance_to(sim.home_inside) < 4.5:
			inside += 1
		else:
			outside += 1
	# Y los que se quedan A MEDIAS: ni dentro ni en la campa, plantados en el
	# canchal a la vista del jugador. Es lo que salia de dar por llegado a
	# quien agotaba el camino lejos de la boca -ver `_home_reached`- sin
	# recogerlo despues.
	var scree := 0
	for person: Inhabitant in sim.people:
		var off := person.position.distance_to(sim.home_position)
		if off > sim._shelter_reach() and off <= Navgrid.CELL:
			scree += 1
	# Dónde ha quedado cada obra y si está apoyada en el suelo. Es lo que no se
	# puede comprobar a ojo en una captura: un secadero enterrado medio metro y
	# uno bien puesto se ven casi igual desde arriba.
	var obras: Node = demo.obras_del_abrigo if "obras_del_abrigo" in demo else null
	if obras != null:
		print("")
		for hija: Node in obras.get_children():
			var nodo := hija as Node3D
			if nodo == null:
				continue
			if nodo.name == "TroncosDelCorro":
				# Es el soporte de los leños: quien lleva sitio es cada tronco.
				print("%-16s %d leños alrededor del fuego" % [
					nodo.name, nodo.get_child_count()])
				continue
			var suelo: float = demo.terrain.get_height_at(nodo.global_position)
			print("%-16s en %6.1f,%6.1f · cota %6.2f · suelo %6.2f · %+0.2f · a %5.1f m del fuego" % [
				nodo.name, nodo.global_position.x, nodo.global_position.z,
				nodo.global_position.y, suelo, nodo.global_position.y - suelo,
				nodo.global_position.distance_to(sim.home_forecourt)])
		# Lo pedido el 2026-09-14: el paraviento a 5–6 m del BORDE del pozo, y el
		# conchero junto a la boca y no a veinte metros.
		var cueva: CaveMouth = demo._cave_at(sim.home_position)
		if cueva != null:
			var boca := cueva.boca()
			var paraviento: Node3D = obras.get_node_or_null("Paraviento")
			# Desde el CENTRO y con el pozo de verdad, [CaveMouth.hueco_de]: se
			# midió con `mouth_radius`, que vale 7 m y no es el pozo, y la sonda
			# dio por buenos 5,5 m que eran 12,5.
			var pozo := CaveMouth.hueco_de(cueva.feature)
			if paraviento != null:
				print("paraviento a %.1f m del centro del pozo (radio del pozo %.1f)" % [
					Vector2(paraviento.global_position.x - boca.x,
						paraviento.global_position.z - boca.z).length(), pozo])
			var monton: Node3D = demo.conchero
			print("conchero a %.1f m del centro del pozo" % Vector2(
				monton.global_position.x - boca.x,
				monton.global_position.z - boca.z).length())
		print("orilla mas cercana a %.1f m del abrigo" % sim.home_position.distance_to(
			sim.tajo._shore_near(sim.home_position)))

	print("en el abrigo: %d dentro · %d en la campa" % [inside, outside])
	print("en el canchal, a %d-%d m: %d" % [
		int(sim._shelter_reach()), int(Navgrid.CELL), scree])

	root.get_texture().get_image().save_png("user://abrigo_%02d.png" % int(hour))
	print("captura en %s" % ProjectSettings.globalize_path("user://"))

	# CONCHERO=1: el montón en su máximo, visto de cerca, y cuánto se separa la
	# loma del suelo. «Está plano, parte flotando en el aire» (2026-09-14): con
	# la media esfera escalada, el borde de abajo de la cuesta quedaba en el aire.
	if OS.get_environment("CONCHERO") == "1":
		sim.desechos.tirar_litros(Materia.Kind.MARISCO, Desechos.SE_VE * 24.0)
		var monton: Conchero = demo.conchero
		monton.colocar(monton.global_position)
		var loma: MeshInstance3D = monton._loma
		var bajo := INF
		var alto := -INF
		var borde_alto := -INF
		if loma.mesh != null:
			var vertices: PackedVector3Array = loma.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in vertices:
				var mundo := loma.global_transform * v
				var sobre: float = mundo.y - demo.terrain.get_height_at(mundo)
				bajo = minf(bajo, sobre)
				alto = maxf(alto, sobre)
				var plano := Vector2(v.x, v.z).length()
				if plano > Conchero.RADIO_MAX * 0.72 * 0.95:
					borde_alto = maxf(borde_alto, sobre)
		print("conchero: loma entre %+.2f y %+.2f m sobre el suelo · el borde, como mucho %+.2f" % [
			bajo, alto, borde_alto])
		camera.set_target(monton.global_position)
		camera.set_distance(22.0)
		camera.orbit_angle_v = -30.0
		for i in range(30):
			await process_frame
		root.get_texture().get_image().save_png("user://abrigo_conchero.png")
	quit()


func _hide_ui(node: Node) -> void:
	var layer := node as CanvasLayer
	if layer != null:
		layer.visible = false
		return
	for child in node.get_children():
		_hide_ui(child)
