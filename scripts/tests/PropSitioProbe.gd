extends SceneTree
## Dónde acaban los props de verdad, y cuántos se ven desde el campamento.
##
## Hace falta porque el número que se venía mirando —cuántas instancias imprime
## `ResourceProps` al construirlas— no significa nada por sí solo. Treinta mil
## instancias repartidas por 16,8 km² pueden ser un mapa lleno o un mapa vacío
## con un montón junto al río, y desde la consola las dos cosas se leen igual.
##
## Aquí se recorre lo que ha quedado montado y se pregunta lo único que importa:
## cuántas de cada materia hay a menos de cien, doscientos y cuatrocientos metros
## del campamento, en cuántos sitios distintos, y hasta dónde llega su recorte de
## visibilidad. Con eso se distingue el fallo de COLOCACIÓN —están lejos— del
## fallo de VISIBILIDAD —están cerca pero recortadas—, que son problemas
## distintos y hasta ahora se estaban confundiendo.

const SITE_ID := 56
const RINGS: Array[float] = [100.0, 200.0, 400.0]


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
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(240):
		await process_frame

	var demo := current_scene
	var props: Node = demo.get_node_or_null("Recursos")
	if props == null:
		print("SIN NODO DE RECURSOS"); quit(); return

	# El campamento: es desde donde mira el jugador casi todo el rato, así que es
	# el único punto contra el que tiene sentido medir.
	var home := Vector3.ZERO
	if "sim" in demo and demo.sim != null:
		home = demo.sim.home_position
	if home == Vector3.ZERO:
		home = Vector3(2048.0, 0.0, 2048.0)
	print("campamento en (%.0f, %.0f)" % [home.x, home.z])

	# Y lo que decide si sale algo o no: la abundancia del campo alrededor del
	# campamento. Se descarta todo lo que baje de `ResourceProps.MIN_ABUNDANCE`,
	# así que si el campo está flojo aquí no hay cupo que valga.
	var field: ResourceField = demo.field if "field" in demo else null
	if field != null:
		print("")
		print("=== ABUNDANCIA ALREDEDOR DEL CAMPAMENTO (corte %.2f) ==="
			% ResourceProps.MIN_ABUNDANCE)
		var cell_x := field.world_size.x / float(field.width)
		var cell_z := field.world_size.y / float(field.height)
		for activity in range(5):
			var line := "actividad %d:" % activity
			for radius: float in [0.0, 150.0, 400.0, 900.0]:
				var best := 0.0
				var mean := 0.0
				var seen := 0
				var steps := 1 if radius <= 0.001 else 12
				for step in range(steps):
					var angle := TAU * float(step) / 12.0
					var spot := home + Vector3(cos(angle), 0.0, sin(angle)) * radius
					var gx := clampi(int(spot.x / cell_x), 0, field.width - 1)
					var gz := clampi(int(spot.z / cell_z), 0, field.height - 1)
					var value := field.abundance_cell(activity, gx, gz)
					best = maxf(best, value)
					mean += value
					seen += 1
				line += "  r%.0f med %.2f max %.2f" % [
					radius, mean / float(seen), best]
			print(line)

	# La cámara AL CAMPAMENTO, y unos fotogramas para que se pueblen los bloques.
	#
	# Sin esto la medida no vale nada: los props se siembran alrededor de la
	# cámara, así que preguntar cuántos hay cerca del campamento mientras la
	# cámara mira a otro sitio devuelve cero siempre, y por el motivo equivocado.
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(0.0, 60.0, 120.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()
	for i in range(120):
		await process_frame

	var by_kind: Dictionary = {}
	for child in props.get_children():
		var node := child as MultiMeshInstance3D
		if node == null or node.multimesh == null:
			continue
		# La materia viene en los METADATOS y no en el nombre. Godot renombra
		# los nodos repetidos, y como cada bloque crea los suyos con el mismo
		# nombre, del segundo en adelante llegan como `@Recurso_...@2`.
		# Leyendo el nombre, esta sonda llegó a informar de once mil piedras
		# que en realidad eran todo lo demás.
		var kind := String(node.get_meta("materia", "sin etiqueta"))
		if not by_kind.has(kind):
			by_kind[kind] = {
				"total": 0, "near": [0, 0, 0], "reach": 0.0, "nodes": 0,
			}
		var box: Dictionary = by_kind[kind]
		box["nodes"] = int(box["nodes"]) + 1
		box["reach"] = maxf(float(box["reach"]), node.visibility_range_end)

		var centre := node.global_position
		var multi := node.multimesh
		for i in range(multi.instance_count):
			box["total"] = int(box["total"]) + 1
			var spot: Vector3 = centre + multi.get_instance_transform(i).origin
			var away := Vector2(spot.x - home.x, spot.z - home.z).length()
			var near: Array = box["near"]
			for r in range(RINGS.size()):
				if away <= RINGS[r]:
					near[r] = int(near[r]) + 1

	print("")
	print("=== PROPS ALREDEDOR DEL CAMPAMENTO ===")
	print("%-14s %7s %7s %7s %7s %6s %8s" % [
		"materia", "total", "<100m", "<200m", "<400m", "nodos", "visible"])
	var keys: Array = by_kind.keys()
	keys.sort()
	for kind: String in keys:
		var box: Dictionary = by_kind[kind]
		var near: Array = box["near"]
		print("%-14s %7d %7d %7d %7d %6d %6.0f m" % [
			kind, box["total"], near[0], near[1], near[2],
			box["nodes"], box["reach"]])
	quit()
