extends SceneTree
## Hoja de contactos de los props: cada pieza encuadrada en su celda.
##
## La versión anterior los ponía a todos en fila y sacaba una foto de conjunto, y
## eso no servía para juzgar: entre un bloque de 1,9 m y una concha de 8,5 cm hay
## un factor veintidós, así que o se ve uno o se ve la otra. Aquí cada pieza se
## renderiza SOLA, con la cámara puesta a su medida, y luego se pegan las
## capturas en una rejilla. Así se ve el detalle de todas por igual.
##
## Cada celda lleva una regla roja de un metro clavada al lado. Es lo que
## convierte la hoja en algo que se puede juzgar: sin una talla conocida dentro
## del encuadre, la foto de una roca no dice si mide un palmo o dos metros.

const COLUMNS := 5
const CELL := Vector2i(480, 360)
const OUT := "user://prop_sheet.png"

var _holder: Node3D
var _camera: Camera3D
var _rule: MeshInstance3D
var _last_wide := 0.0


func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("no hay biblioteca en %s" % PropModels.LIBRARY_PATH)
		quit(1)
		return

	_build_stage()
	await process_frame

	var keys: Array = PropModels.CATALOGUE.keys()
	var rows := int(ceil(float(keys.size()) / float(COLUMNS)))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows,
		false, Image.FORMAT_RGBA8)

	print("orden de la rejilla, de izquierda a derecha y de arriba abajo:")
	for index in range(keys.size()):
		var key: String = keys[index]
		var entry: Dictionary = PropModels.CATALOGUE[key]
		if not library.has(key):
			print("  %2d · %-9s SIN MALLA" % [index + 1, key])
			continue

		var height := _show(library, key)
		# El ancho va en el informe porque es el número que delata un modelo
		# desproporcionado: una pieza cuatro veces más ancha que alta sembrada
		# como si fuera un arbusto se solapa con sus vecinas.
		print("  %2d · %-9s %-22s alto %.2f m · ancho %.2f m" % [
			index + 1, key, entry["name"], height, _last_wide])

		for i in range(8):
			await process_frame
		var shot := root.get_texture().get_image()
		shot.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, CELL),
			Vector2i(index % COLUMNS, index / COLUMNS) * CELL)

	sheet.save_png(OUT)
	print("hoja en %s" % ProjectSettings.globalize_path(OUT))
	quit()


## Coloca una pieza sola y encuadra la cámara a su medida.
func _show(library: PropLibrary, key: String) -> float:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()

	var node := MeshInstance3D.new()
	node.mesh = library.mesh(key)
	var factor := library.scale_for(key)
	node.scale = Vector3(factor, factor, factor)
	_holder.add_child(node)

	var box := node.mesh.get_aabb()
	var height := box.size.y * factor
	var wide := maxf(box.size.x, box.size.z) * factor

	# El encuadre lo manda la ALTURA, no la caja entera. Con la caja, una pieza
	# ancha -un parche de hierba lo es- echaba la cámara tan atrás que la planta
	# salía como una mota. Del ancho sólo se toma una parte, para que una pieza
	# muy tumbada tampoco se salga.
	var reach := maxf(height, wide * 0.45)
	_last_wide = wide

	# La regla, al lado y algo detrás para que no tape la pieza
	_rule.position = Vector3(reach * 0.9 + 0.12, 0.5, -reach * 0.35)

	# El encuadre sigue a la pieza O a la regla, lo que sea mayor: si la cámara
	# sólo mirase la concha, la regla se saldría y no habría referencia.
	var framed := maxf(reach, 1.1)
	_camera.position = Vector3(framed * 1.4, framed * 0.8, framed * 1.9)
	_camera.look_at(Vector3(0.0, framed * 0.32, 0.0), Vector3.UP)
	return height


func _build_stage() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	light.light_energy = 1.1
	world.add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.3
	env.environment = environment
	world.add_child(env)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.34, 0.34, 0.36)
	ground.material_override = floor_material
	world.add_child(ground)

	# Regla de UN METRO exacto, en rojo para que no se confunda con nada.
	_rule = MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.02
	rod.bottom_radius = 0.02
	rod.height = 1.0
	_rule.mesh = rod
	var rule_material := StandardMaterial3D.new()
	rule_material.albedo_color = Color(0.95, 0.22, 0.18)
	_rule.material_override = rule_material
	world.add_child(_rule)

	_holder = Node3D.new()
	world.add_child(_holder)

	_camera = Camera3D.new()
	_camera.far = 500.0
	world.add_child(_camera)
	_camera.make_current()
