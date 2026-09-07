extends SceneTree
## Dónde cae, en pantalla, el corte tabla/impostor del bosque.
##
## El aviso dice que los árboles de la parte de abajo de la cámara se encogen
## y desaparecen. La sospecha es geométrica: `Forest.near_distance` (130 m) se
## fijó sin mirar el zoom mínimo real de la cámara de juego, que en un mapa de
## 4096 m no baja de unos 300 m de órbita. El punto de suelo más cercano que se
## ve en pantalla -el borde inferior- puede caer justo en el radio de corte
## según el ángulo, y ahí es donde el borde entre malla e impostor cruza el
## bosque de primer plano en vez de quedar fuera de cuadro.
##
## Esto mide el `reach` (distancia cámara-suelo) del borde inferior de la
## pantalla, con la cámara REAL del juego, en el zoom más cercano posible y
## varios ángulos, y lo compara con `near_end`.

const SITE_ID := 56


func _init() -> void:
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

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(240):
		await process_frame

	var demo := current_scene
	var terrain: Node = _first(demo, "TerrainGenerator")
	var forest: Node = _first(demo, "Forest")
	var camera: Camera3D = demo.camera
	if terrain == null or camera == null:
		print("falta terreno o camara"); quit(); return

	var near_distance: float = forest.near_distance if forest else 130.0
	print("Forest.near_distance = near_end = %.1f" % near_distance)
	print("camera min_distance=%.1f max_distance=%.1f fov=%.1f keep_aspect=%d" % [
		camera.min_distance, camera.max_distance, camera.fov, camera.keep_aspect])
	print("viewport = %s" % str(root.get_visible_rect().size))

	# El bosque de cerca hace sombra (Forest._build_block, cast_shadow=ON), y si
	# la luz no llega tan lejos como la malla real, queda un anillo con árboles
	# de verdad pero sin sombra -un arco que se nota justo en el borde-. Ver
	# `WorldEnvironmentSetup._setup_lighting`.
	for light_name in ["Sun", "MoonLight"]:
		var light: DirectionalLight3D = _find_named(demo, light_name) as DirectionalLight3D
		if light:
			var margen := light.directional_shadow_max_distance - near_distance
			print("%s.directional_shadow_max_distance = %.1f (%s, margen %.1f)" % [
				light_name, light.directional_shadow_max_distance,
				"OK" if margen >= 0.0 else "CORTO: hay malla sin sombra", margen])

	camera.set_distance(camera.min_distance)
	var view := root.get_visible_rect().size

	print("")
	print("%-8s %10s %10s %10s %14s" % [
		"angulo", "altura", "reach_abajo", "reach_centro", "cruza el corte?"])
	for angle in [-10.0, -15.0, -20.0, -25.0, -30.0, -35.0, -40.0, -50.0, -60.0, -75.0, -89.0]:
		camera.orbit_angle_v = angle
		camera._update_camera()
		for i in range(3):
			await process_frame
		var ground_h: float = terrain.get_height_at(camera.target_position) \
			if terrain.has_method("get_height_at") else 0.0
		var height := camera.global_position.y - ground_h
		var bottom := _ground_reach(camera, terrain, Vector2(view.x * 0.5, view.y * 0.98))
		var centre := _ground_reach(camera, terrain, view * 0.5)
		# El corte es duro, sin banda: lo malo es que el radio near_end quede
		# DENTRO de lo que se ve en pantalla, es decir entre el borde inferior
		# (lo más cerca posible) y el centro (más lejos). Si near_end cae fuera
		# de ese rango, el corte no se ve -está por delante o por detrás de
		# cuadro-, aunque siga siendo un salto brusco para quien SÍ lo cruce.
		var visible_on_screen := near_distance >= bottom and near_distance <= centre
		print("%-8.0f %10.1f %10.1f %10.1f %14s" % [
			angle, height, bottom, centre, "SI" if visible_on_screen else ""])

	quit()


## Lanza un rayo desde la cámara por ese punto de pantalla y devuelve la
## distancia 3D desde la cámara hasta donde corta el terreno (a base de
## bisección sobre la altura real, no una colisión física).
func _ground_reach(camera: Camera3D, terrain: Node, screen: Vector2) -> float:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if not terrain.has_method("get_height_at"):
		return -1.0
	var step := 4.0
	var t_lo := 0.0
	var t := 0.0
	for i in range(20000):
		t += step
		var p: Vector3 = origin + dir * t
		if p.y - terrain.get_height_at(p) <= 0.0:
			var t_hi := t
			t_lo = t - step
			for j in range(24):
				var mid := (t_lo + t_hi) * 0.5
				var pm: Vector3 = origin + dir * mid
				if pm.y - terrain.get_height_at(pm) <= 0.0:
					t_hi = mid
				else:
					t_lo = mid
			return t_hi
	return -1.0


func _find_named(root_node: Node, name: String) -> Node:
	if root_node.name == name:
		return root_node
	for child in root_node.get_children():
		var found := _find_named(child, name)
		if found:
			return found
	return null


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if child.get_class() == type_name:
			return child
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
