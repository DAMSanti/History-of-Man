extends SceneTree
## Hacia dónde mira cada malla de fauna cuando se le da un rumbo.
##
## `WildlifeHerds` gira a los animales con `Basis(Vector3.UP, heading)` y calcula
## el rumbo con `atan2(step.x, step.z)`. Eso sólo es correcto si la malla mira
## hacia +Z en reposo: si el modelo viene mirando a otro lado, el animal anda de
## lado o de espaldas y el ciclo de marcha no se lee, por bien horneado que
## esté.
##
## Aquí se pone cada bicho con rumbo hacia +X y se mira desde arriba, con una
## bola blanca puesta DONDE DEBERÍA ESTAR LA CABEZA. Si la bola queda delante del
## morro, el rumbo se traduce bien; si queda al costado, esa malla está girada.

const MODELS := ["wolf", "horse", "cow", "pig", "sheep", "deer", "stag", "bull"]

## Separación entre bichos en la fila, en unidades de mundo.
const STEP := 9.0

## Cuánto se escala cada malla para que quepan todas iguales en el encuadre.
const VIEW_SCALE := 0.9


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	var root3d := Node3D.new()
	root.add_child(root3d)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.13, 0.15)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	environment.ambient_light_sky_contribution = 0.0
	env.environment = environment
	root3d.add_child(env)

	var heading := atan2(1.0, 0.0)   # rumbo hacia +X

	for i in range(MODELS.size()):
		var prefix: String = MODELS[i]
		var mesh: ArrayMesh = load("res://models/animals/%s_mesh.res" % prefix)
		var material: ShaderMaterial = load("res://models/animals/%s_material.tres" % prefix)
		if mesh == null or material == null:
			print("%s sin hornear" % prefix)
			continue
		var origin := Vector3(0.0, 0.0, float(i) * STEP)

		var node := AnimatedMultiMeshInstance3D.new()
		node.material_override = material
		node.sampling_fps = 12.0
		var multi := MultiMesh.new()
		multi.mesh = mesh
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.instance_count = 1
		multi.visible_instance_count = 1
		node.multimesh = multi
		# Sin `animation_list` y sin `play` el shader no sabe qué fotograma
		# leer y la malla se queda en el vértice cero: un punto.
		node.animation_list["idle"] = MultimeshAnimationData.new().set_values(0, 1)
		root3d.add_child(node)
		node.play(0, "idle")
		# Con la corrección que aplica el juego, para comprobarla y no repetirla.
		var yaw := heading + float(WildlifeHerds.MODEL_YAW.get(prefix, 0.0))
		multi.set_instance_transform(0, Transform3D(
			Basis(Vector3.UP, yaw).scaled(Vector3.ONE * VIEW_SCALE), origin))

		# La bola va donde debería quedar la cabeza si el rumbo se traduce bien.
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		ball.mesh = sphere
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color(1.0, 0.9, 0.2)
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ball.material_override = paint
		ball.position = origin + Vector3(5.0, 0.0, 0.0)
		root3d.add_child(ball)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(MODELS.size()) * STEP + 4.0
	camera.far = 200.0
	root3d.add_child(camera)
	# La base se pone a mano: `look_at` mirando recto hacia abajo pide un
	# «arriba» que no sea vertical y se queja igual. Cámara mirando a -Y, con
	# +Z hacia abajo en pantalla y +X a la derecha.
	camera.global_transform = Transform3D(
		Basis(Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)),
		Vector3(0.0, 60.0, float(MODELS.size() - 1) * STEP * 0.5))
	camera.make_current()

	for i in range(40):
		await process_frame
	root.get_texture().get_image().save_png("user://fauna_rumbo.png")
	print("rumbo hacia +X (la bola marca dónde debería ir la cabeza)")
	print("orden de arriba abajo: %s" % ", ".join(MODELS))
	print("captura en %s" % ProjectSettings.globalize_path("user://"))
	quit()
