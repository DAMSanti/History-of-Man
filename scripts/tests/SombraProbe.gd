extends SceneTree
## Cuánto de negras están las sombras, y qué las levanta.
##
## Hace falta una cifra porque «las sombras salen negras» no se puede discutir
## mirando: dos capturas del mismo valle a distinta hora parecen distintas por
## motivos que no tienen nada que ver, y el ojo se adapta al mirar una imagen
## sola. Aquí se mide el SUELO DE LUZ: la luminancia media del cuarto más oscuro
## de la pantalla. Es exactamente el número del que se queja uno cuando dice que
## una sombra está negra.
##
## Se prueba la luz de relleno a varias energías —ver `WorldEnvironmentSetup`—
## dando en cada una el suelo de luz, la luminancia media de toda la vista y lo
## que cuesta. Con eso el compromiso se elige leyendo, no adivinando.
##
## El punto de vista es el mismo de `ReboteProbe` a propósito: mira de frente la
## hondonada de la cueva, que es la peor sombra del emplazamiento.

const SITE_ID := 56
const ROUNDS := 2

## Qué energías de relleno se prueban, en fracción de la del sol.
const CASES: Array[float] = [0.0, 0.5, 3.0]

var _fill: DirectionalLight3D


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
	for i in range(240):
		await process_frame

	var demo := current_scene
	var terrain: Node = _first(demo, "TerrainGenerator")
	if terrain == null:
		print("sin terreno"); quit(); return

	_fill = _find_fill(demo)
	if _fill == null:
		print("SIN LUZ DE RELLENO: no esta montada"); quit(); return

	var home := Vector3(2048.0, 0.0, 2048.0)
	home.y = terrain.get_height_at(home)
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(120.0, 60.0, 190.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()

	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	# La energía de referencia es la DEL SOL, no la que traiga el relleno: así la
	# tabla se lee como «fracción del sol» y no depende de con qué estuviera
	# configurado el relleno al arrancar.
	var sun := _find_sun(demo)
	var base: float = sun.light_energy if sun != null else 1.2
	print("sol: energia %.2f, giro %s" % [base,
		sun.rotation_degrees if sun != null else Vector3.ZERO])
	print("relleno: color %s, giro %s, sombras %s, especular %.2f" % [
		_fill.light_color, _fill.rotation_degrees, _fill.shadow_enabled,
		_fill.light_specular])

	var floors: Dictionary = {}
	var means: Dictionary = {}
	var costs: Dictionary = {}

	for round_index in range(ROUNDS):
		for index in range(CASES.size()):
			var share: float = CASES[index]
			_fill.light_energy = base * share
			# Apagarla del todo y no dejarla a cero: una direccional con energía
			# cero sigue costando su pase de luz, y entonces la columna de coste
			# no diría lo que cuesta tenerla.
			_fill.visible = share > 0.001

			for i in range(30):
				await process_frame
			var gpu := 0.0
			for i in range(45):
				await process_frame
				gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			gpu /= 45.0

			var shot := root.get_texture().get_image()
			var read := _read(shot)
			if not costs.has(share) or gpu < costs[share]:
				costs[share] = gpu
			floors[share] = read["floor"]
			means[share] = read["mean"]
			if round_index == 0:
				shot.save_png("user://sombra_%d.png" % index)

	print("")
	print("=== SUELO DE LUZ (cuarto mas oscuro de la vista) ===")
	print("relleno   suelo    media    GPU")
	for share: float in CASES:
		print("%5.0f%%   %6.4f   %6.4f   %5.1f ms" % [
			share * 100.0, floors[share], means[share], costs[share]])
	print("capturas sombra_0..%d en %s" % [CASES.size() - 1,
		ProjectSettings.globalize_path("user://")])
	quit()


## Luminancia media de la vista y del cuarto más oscuro de ella.
##
## El cuarto más oscuro y no el mínimo: un solo píxel negro no dice nada -puede
## ser una grieta o el borde de un modelo- y en cambio la cuarta parte más
## oscura de la pantalla ES la zona en sombra cuando media ladera está de
## espaldas al sol, que es el caso que se quiere medir.
func _read(image: Image) -> Dictionary:
	var lums := PackedFloat32Array()
	var step := 6
	var total := 0.0
	# SÓLO LA PARTE DE LA VISTA QUE ES TERRENO.
	#
	# La primera versión medía la pantalla entera, y el resultado fue que el
	# relleno no cambiaba NADA ni al cincuenta por ciento del sol. La explicación
	# no era la luz: los paneles de la interfaz son gris muy oscuro y ocupan lo
	# suyo, así que el «cuarto más oscuro» era la propia interfaz, que no se
	# ilumina con nada. Se recorta a la banda central, sin la barra de abajo ni
	# el panel de arriba a la derecha.
	var x0 := int(float(image.get_width()) * 0.05)
	var x1 := int(float(image.get_width()) * 0.72)
	var y0 := int(float(image.get_height()) * 0.22)
	var y1 := int(float(image.get_height()) * 0.88)
	for y in range(y0, y1, step):
		for x in range(x0, x1, step):
			var c := image.get_pixel(x, y)
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			lums.append(lum)
			total += lum
	if lums.is_empty():
		return {"mean": 0.0, "floor": 0.0}
	var sorted := lums.duplicate()
	sorted.sort()
	var quarter := maxi(sorted.size() / 4, 1)
	var dark := 0.0
	for i in range(quarter):
		dark += sorted[i]
	return {"mean": total / float(lums.size()), "floor": dark / float(quarter)}


func _find_sun(node: Node) -> DirectionalLight3D:
	var light := node as DirectionalLight3D
	if light != null and light.name != "FillLight":
		return light
	for child in node.get_children():
		var found := _find_sun(child)
		if found != null:
			return found
	return null


func _find_fill(node: Node) -> DirectionalLight3D:
	var light := node as DirectionalLight3D
	if light != null and light.name == "FillLight":
		return light
	for child in node.get_children():
		var found := _find_fill(child)
		if found != null:
			return found
	return null


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
