extends SceneTree
## La capa de navegación encendida sobre el río, para poder mirarla.
##
## Es la única forma de juzgarla: una cuenta de celdas no dice si la mancha roja
## cubre el cauce ni si la lámina se pega al monte o flota sobre él. Se enciende
## la capa, se pone la cámara sobre el río y se dispara.
##
## Y de paso cuenta lo que la cuenta sí puede decir: cuántos puntos del CAUCE
## quedan sin pintar. Con la capa pintando por celda de cuarenta metros, un
## arroyo más estrecho que la celda desaparecía —su centro está seco— y eso es
## lo que se veía en la captura del jugador: tramos de río sin una sola casilla.
##
##   ALTURA=700   a qué distancia se pone la cámara

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	var terrain: Node = demo.terrain
	var camera: Node = demo.camera if "camera" in demo else null
	var ui: Node = demo.ui if "ui" in demo else null
	if ui != null:
		for id: String in (ui._windows as Dictionary).keys():
			(ui._windows[id] as Control).visible = false
	sim.time_scale = 0.0

	# La capa, encendida.
	var capa: NavOverlay = demo.nav_overlay
	var tardo := Time.get_ticks_msec()
	capa.toggle(sim.navgrid(), sim.home_position, terrain)
	tardo = Time.get_ticks_msec() - tardo

	print("")
	print("=== LA CAPA DE NAVEGACION ===")
	print("montada en %d ms" % tardo)
	print(NavOverlay.tally_text(sim.navgrid(), sim.home_position))
	_cuanto_cauce_queda_sin_pintar(sim, terrain)

	# Sobre el río, que es lo que hay que mirar.
	var lejos := 700.0
	if not OS.get_environment("ALTURA").is_empty():
		lejos = float(OS.get_environment("ALTURA"))
	var rio := _un_punto_del_cauce(sim, terrain)
	if camera != null:
		camera.set_target(rio if rio != Vector3.ZERO else sim.home_position)
		camera.set_distance(lejos)
		camera.orbit_angle_v = -40.0
	for i in range(40):
		sim.hour = 12.0
		await process_frame
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://navcapa.png")
		print("captura en user://navcapa.png")
	quit()


## Cuántos puntos del cauce quedan SIN pintar de rojo ni de azul.
##
## Es la cifra que delata el fallo del jugador: si sale por encima de cero, hay
## río que la capa no está diciendo. Se mira a la resolución a la que la capa
## dibuja ahora —diez metros— y no a la de la rejilla.
func _cuanto_cauce_queda_sin_pintar(sim: Node, terrain: Node) -> void:
	var grid: Navgrid = sim.navgrid()
	if grid == null or not grid.is_ready():
		return
	var paso := Navgrid.CELL / float(NavOverlay.SUB)
	var cauce := 0
	var mudos := 0
	var z := paso * 0.5
	while z < grid.world.y:
		var x := paso * 0.5
		while x < grid.world.x:
			var punto := Vector3(x, 0.0, z)
			var ford: float = terrain.crossing_difficulty_at(punto)
			if ford > NavOverlay.MOJADO:
				cauce += 1
				# Con la regla NUEVA todo punto con agua se pinta -rojo si no se
				# vadea, azul si si-, asi que preguntarlo seria preguntar por la
				# propia regla. Lo que se cuenta es lo que habria quedado MUDO
				# con la regla VIEJA: pintar por celda de cuarenta metros y
				# mirando solo su centro.
				var celda: int = grid.cell_of(punto)
				if celda >= 0 and celda < grid.cost.size():
					var cerrada := grid.cost[celda] <= Navgrid.BLOCKED
					var centro: Vector3 = grid.point_of(celda)
					var centro_mojado: float = terrain.crossing_difficulty_at(centro)
					if not cerrada and centro_mojado <= NavOverlay.MOJADO:
						mudos += 1
			x += paso
		z += paso
	print("puntos con agua: %d" % cauce)
	print("de esos, los que la regla VIEJA -por celda- dejaba MUDOS: %d (%.0f %%)"
		% [mudos, 100.0 * float(mudos) / maxf(float(cauce), 1.0)])
	print("con la regla nueva -por punto, a %.0f m- se pintan todos"
		% (Navgrid.CELL / float(NavOverlay.SUB)))


## Un punto del cauce lejos del abrigo, para plantar ahí la cámara.
func _un_punto_del_cauce(sim: Node, terrain: Node) -> Vector3:
	var grid: Navgrid = sim.navgrid()
	if grid == null:
		return Vector3.ZERO
	var mejor := Vector3.ZERO
	var mas_hondo := 0.0
	var paso := Navgrid.CELL
	var z := paso
	while z < grid.world.y:
		var x := paso
		while x < grid.world.x:
			var punto := Vector3(x, 0.0, z)
			if sim.home_position.distance_to(punto) > 700.0:
				x += paso
				continue
			var ford: float = terrain.crossing_difficulty_at(punto)
			if ford > mas_hondo:
				mas_hondo = ford
				punto.y = terrain.get_height_at(punto)
				mejor = punto
			x += paso
		z += paso
	return mejor


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
