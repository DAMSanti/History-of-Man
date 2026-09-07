extends SceneTree
## Cuánto queda de una ladera cuando el sol no la toca, hora a hora y estación a
## estación.
##
## `LuzProbe` midió esto a mediodía fijo, antes de que existiera [SolarPosition],
## y de ahí salió el «las sombras están bien» de REVAMP_GRAFICO §6. Aquella
## medida comparaba dos RECTÁNGULOS dibujados a mano sobre una captura, y el que
## hacía de sombra no lo estaba: era terreno al sol de albedo oscuro. Con sol de
## verdad la partida arranca a las 6:00 y pasa el invierno con el sol a 23°, que
## son además los momentos que nunca se midieron.
##
## El método aquí no depende del encuadre ni de acertar dónde cae la sombra. Se
## fotografía dos veces la misma vista, con el sol y sin él:
##
##   con sol = ambiente + sol   → la ladera iluminada
##   sin sol = ambiente         → esa MISMA ladera si algo se interpone
##
## O sea que la segunda captura es, literalmente, la primera en sombra, y la
## razón entre las dos es la profundidad de sombra de la escena.
##
## Se mide sólo el TERRENO: el cielo entra brillante en las dos capturas y, si se
## cuela, la razón sube hacia el 100 % sin querer decir nada. El recorte de cielo
## sale de una tercera captura con toda la luz apagada.
##
## Referencia, la misma de [LuzProbe]: en foto de campo la sombra ronda el
## 15-20 % de lo iluminado; por debajo del 8 % se lee como negro.

const SITE_ID := 56

## Por encima de qué luminancia, con toda la luz apagada, un píxel es cielo.
const SKY_LEVEL := 0.02

## etiqueta · hora solar · estación (0 primavera … 3 invierno)
const CASES := [
	["arranque primavera", 6.0, 0],
	["amanecer primavera", 7.5, 0],
	["mediodia primavera", 13.0, 0],
	["atardecer verano", 20.0, 1],
	["amanecer invierno", 9.0, 3],
	["mediodia invierno", 12.0, 3],
	["atardecer invierno", 16.5, 3],
	["noche primavera", 2.0, 0],
]

var _setup: Node3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky: Image


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

	_setup = _find_setup(demo)
	if _setup == null:
		print("sin WorldEnvironmentSetup"); quit(); return
	_sun = _setup.get_sun()
	_env = _setup.get_environment()

	# La interfaz es gris muy oscuro y no la ilumina nada: dejarla en el encuadre
	# hunde la parte oscura de la medida sin que tenga que ver con la luz.
	_hide_ui(demo)

	var home := Vector3(2048.0, 0.0, 2048.0)
	home.y = terrain.get_height_at(home)
	var camera := Camera3D.new()
	camera.far = 20000.0
	demo.add_child(camera)
	camera.global_position = home + Vector3(120.0, 60.0, 190.0)
	camera.look_at(home, Vector3.UP)
	camera.make_current()

	# Sin simulación corriendo: las dos capturas de un mismo caso tienen que ser
	# de la misma escena, y con la banda andando no lo serían.
	paused = true
	_setup.follow_time_of_day = false

	# Para barrer el ajuste sin tocar el código: AMBIENTE=1.0 en el entorno pisa
	# la energía de ambiente que trae `WorldEnvironmentSetup`.
	var override := OS.get_environment("AMBIENTE")
	if not override.is_empty():
		_setup.ambient_energy = float(override)
		_setup._apply_fixed_sun()

	_sky = await _sky_mask()

	print("ambiente %.2f · cielo %.2f · noche %.2f · relleno %.2f" % [
		_setup.ambient_energy, _setup.ambient_sky_share,
		_setup.ambient_night_floor, _setup.fill_energy])
	print("")
	print("%-20s %6s %7s %8s %8s %7s" % [
		"caso", "altura", "energia", "sombra", "sol", "razon"])

	for index in range(CASES.size()):
		var label: String = CASES[index][0]
		GameState.season = CASES[index][2]
		_setup.fixed_hour = CASES[index][1]
		_setup._apply_fixed_sun()
		var above := 90.0 - rad_to_deg(
			_sun.global_transform.basis.z.angle_to(Vector3.UP))
		var energy := _sun.light_energy

		var lit := _median(await _shoot("dia_%d_sol" % index))
		var was := _sun.visible
		_sun.visible = false
		var dark := _median(await _shoot("dia_%d_sombra" % index))
		_sun.visible = was

		print("%-20s %5.1fº %7.2f %8.4f %8.4f %6.1f %%" % [
			label, above, energy, dark, lit,
			100.0 * dark / maxf(lit, 0.0001)])

	print("")
	print("capturas dia_*.png en %s" % ProjectSettings.globalize_path("user://"))
	quit()


## La misma vista con todo apagado: lo que siga encendido es cielo.
##
## El ambiente se apaga por CONTRIBUCIÓN y energía, sin tocar la fuente: pasar la
## fuente a color y devolverla al cielo deja la radiancia sin rehornear y el
## terreno se queda negro para el resto de la prueba.
func _sky_mask() -> Image:
	var share: float = _env.ambient_light_sky_contribution
	var energy: float = _env.ambient_light_energy
	var lights: Array[Light3D] = []
	_collect_lights(current_scene, lights)
	var seen: Array[bool] = []
	for light: Light3D in lights:
		seen.append(light.visible)
		light.visible = false
	_env.ambient_light_sky_contribution = 0.0
	_env.ambient_light_energy = 0.0

	var shot := await _shoot("dia_cielo")

	_env.ambient_light_sky_contribution = share
	_env.ambient_light_energy = energy
	for i in range(lights.size()):
		lights[i].visible = seen[i]
	return shot


## Deja asentar el render y devuelve la imagen.
func _shoot(name: String) -> Image:
	for i in range(24):
		await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png("user://%s.png" % name)
	return shot


## Luminancia mediana del terreno. Mediana y no media: un reflejo del sol en el
## río o una brizna a contraluz son cientos de veces la luminancia de su vecina,
## y con la media dos píxeles así mueven el resultado.
func _median(shot: Image) -> float:
	var lums := PackedFloat32Array()
	for y in range(0, shot.get_height(), 4):
		for x in range(0, shot.get_width(), 4):
			if _lum(_sky.get_pixel(x, y)) > SKY_LEVEL:
				continue
			lums.append(_lum(shot.get_pixel(x, y)))
	if lums.is_empty():
		return 0.0
	var sorted := lums.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _lum(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


func _collect_lights(node: Node, into: Array[Light3D]) -> void:
	var light := node as Light3D
	if light != null:
		into.append(light)
	for child in node.get_children():
		_collect_lights(child, into)


func _hide_ui(node: Node) -> void:
	var layer := node as CanvasLayer
	if layer != null:
		layer.visible = false
		return
	for child in node.get_children():
		_hide_ui(child)


func _find_setup(node: Node) -> Node3D:
	if node.has_method("get_sun") and node.has_method("get_environment"):
		return node as Node3D
	for child in node.get_children():
		var found := _find_setup(child)
		if found != null:
			return found
	return null


func _first(root_node: Node, type_name: String) -> Node:
	for child in root_node.get_children():
		var script: Variant = child.get_script()
		if script != null and String(script.resource_path).ends_with(type_name + ".gd"):
			return child
	return null
