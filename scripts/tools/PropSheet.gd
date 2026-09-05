extends SceneTree
## Hoja de contactos de los modelos de props, con una persona al lado.
##
## Que la ingesta diga «guardado, 42 MB» sólo prueba que escribió bytes. Y en el
## juego no sirve mirarlos: a distancia de cámara un canto de 34 cm es subpíxel,
## así que no se distingue un modelo correcto de uno roto.
##
## Aquí sale cada pieza sola, sobre una cuadrícula de un metro y junto a una
## silueta de 1,70 m. Con eso se ve de un golpe si el modelo cargó, si la talla
## que calculó la ingesta es la que se pidió, y si a esa talla se va a ver algo
## en pantalla o no.

const OUT := "user://prop_sheet.png"
const STEP := 3.0


func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("no hay biblioteca en %s" % PropModels.LIBRARY_PATH)
		quit(1)
		return

	var world := Node3D.new()
	root.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, -40.0, 0.0)
	light.light_energy = 1.2
	world.add_child(light)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment = environment
	world.add_child(env)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 20.0)
	ground.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.30, 0.30, 0.32)
	ground.material_override = floor_material
	world.add_child(ground)

	var keys: Array = PropModels.CATALOGUE.keys()
	var span := float(keys.size()) * STEP
	var x := -span * 0.5

	# La referencia: una persona de 1,70 m. Sin algo de talla conocida al lado,
	# mirar un modelo suelto no dice nada de su tamaño.
	_place_person(world, Vector3(x - STEP, 0.0, 0.0))

	for key: String in keys:
		var entry: Dictionary = PropModels.CATALOGUE[key]
		var node := MeshInstance3D.new()
		node.mesh = library.mesh(key)
		var factor := library.scale_for(key)
		node.scale = Vector3(factor, factor, factor)
		node.position = Vector3(x, 0.0, 0.0)
		world.add_child(node)

		var box := node.mesh.get_aabb()
		print("%-9s %-26s %6.2f m de alto  (x%.3f sobre %.3f m de origen)" % [
			key, entry["name"], box.size.y * factor, factor, box.size.y])
		x += STEP

	# Un fotograma antes de colocar la camara: los nodos anadidos desde `_init`
	# no estan dentro del arbol hasta que corre uno, y `look_at` sobre un nodo
	# fuera del arbol no hace nada y avisa.
	await process_frame

	var camera := Camera3D.new()
	camera.far = 500.0
	world.add_child(camera)
	camera.global_position = Vector3(0.0, 2.6, span * 0.62 + 6.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.make_current()

	for i in range(20):
		await process_frame
	root.get_texture().get_image().save_png(OUT)
	print("hoja en %s" % ProjectSettings.globalize_path(OUT))
	quit()


func _place_person(world: Node3D, at: Vector3) -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.70
	body.mesh = capsule
	body.position = at + Vector3(0.0, 0.85, 0.0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.70, 0.52)
	body.material_override = skin
	world.add_child(body)
