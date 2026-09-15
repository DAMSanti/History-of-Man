extends SceneTree
## Los árboles generados, en fila, para verlos antes de meterlos en el bosque.
##
## GRAFICOS §7.1, tarea 1: «capturas por especie, y parada para que el usuario las
## vea». **Con ventana**: los materiales sólo fallan de verdad con dispositivo.
##
##   godot --path . --script res://scripts/tests/ArbolesCaptura.gd
##
## Deja en `user://capturas/`:
##   arboles_todos.png   las cinco especies en filas, sus seis variantes en columnas
##   arboles_de_cerca.png  una de cada especie, a la altura de los ojos
##   arboles_niveles.png   un pino y un roble en sus tres niveles de detalle

const SALIDA := "user://capturas"
const ESPECIES := ["pino", "pino_joven", "abedul", "roble", "avellano"]
const VARIANTES := 6


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var mundo := _estudio()
	root.add_child(mundo)
	var camara := Camera3D.new()
	mundo.add_child(camara)
	camara.current = true

	# Todos: filas por especie, a 14 m unas de otras.
	var arboles := Node3D.new()
	mundo.add_child(arboles)
	for e in range(ESPECIES.size()):
		for v in range(VARIANTES):
			_plantar(arboles, ESPECIES[e], v, 0, Vector3(v * 12.0, 0.0, e * 16.0))
	camara.fov = 50.0
	await process_frame
	camara.look_at_from_position(Vector3(30.0, 38.0, 100.0), Vector3(30.0, 3.0, 32.0))
	await _capturar("arboles_todos")

	# De cerca: variante 0 de cada una, a la altura de los ojos.
	arboles.queue_free()
	await process_frame
	arboles = Node3D.new()
	mundo.add_child(arboles)
	for e in range(ESPECIES.size()):
		_plantar(arboles, ESPECIES[e], 1, 0, Vector3(e * 11.0, 0.0, 0.0))
	camara.fov = 55.0
	camara.look_at_from_position(Vector3(22.0, 1.7, 30.0), Vector3(22.0, 5.0, 0.0))
	await _capturar("arboles_de_cerca")

	# Los niveles de detalle, a la misma distancia para compararlos.
	arboles.queue_free()
	await process_frame
	arboles = Node3D.new()
	mundo.add_child(arboles)
	for n in range(3):
		_plantar(arboles, "pino", 2, n, Vector3(n * 10.0, 0.0, 0.0))
		_plantar(arboles, "roble", 2, n, Vector3(n * 10.0 + 32.0, 0.0, 0.0))
	camara.fov = 55.0
	camara.look_at_from_position(Vector3(26.0, 4.0, 34.0), Vector3(26.0, 5.0, 0.0))
	await _capturar("arboles_niveles")
	quit()


func _plantar(padre: Node3D, especie: String, variante: int, nivel: int, sitio: Vector3) -> void:
	var modelo: ArbolModelo = load(ArbolModelo.ruta(especie, variante))
	if modelo == null:
		print("  falta %s %d" % [especie, variante])
		return
	var nodo := MeshInstance3D.new()
	nodo.mesh = modelo.niveles[nivel]
	nodo.position = sitio
	padre.add_child(nodo)


func _estudio() -> Node3D:
	var mundo := Node3D.new()
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	var cielo := Sky.new()
	cielo.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.environment = env
	mundo.add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sol.shadow_enabled = true
	sol.light_energy = 1.2
	mundo.add_child(sol)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(400.0, 400.0)
	suelo.mesh = plano
	var tierra := StandardMaterial3D.new()
	tierra.albedo_color = Color(0.36, 0.33, 0.24)
	suelo.material_override = tierra
	mundo.add_child(suelo)
	return mundo


func _capturar(nombre: String) -> void:
	for _i in range(40):
		await process_frame
	var ruta := "%s/%s.png" % [SALIDA, nombre]
	root.get_texture().get_image().save_png(ruta)
	print("  %s" % ProjectSettings.globalize_path(ruta))
