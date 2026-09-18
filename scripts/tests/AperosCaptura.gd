extends SceneTree
## ¿CAE EL APERO EN LA MANO? GRAFICOS §5.1, tarea 5.
##
## La cuenta del fotograma se repite en CPU fuera del shader y el agarre de cada apero es
## una transformada puesta a ojo: las dos cosas fallan igual —el apero flotando al lado de
## la persona— y ninguna de las dos la ve una prueba de la suite.
##
## **Monta la banda sola, sin valle y sin simulación.** El primer intento plantaba ocho
## personas en fila dentro de la partida y no sirvió de nada: la simulación decide dónde
## está cada una y escribir su `position` no la mueve, la cámara mira adonde ella quiere y a
## las 06:00 del día 1 no se ve un apero ni con lupa. Aquí no hay nada que discuta.
##
## Los pares salen vestidos y los impares en cueros, que es lo que hace el juego según haya
## o no un vestido en el utillaje para cada uno.
##
##   godot --path . --script res://scripts/tests/AperosCaptura.gd

const VENTANA := Vector2i(1800, 620)
## Las especialidades que se ponen en fila: las siete que llevan algo, y una sin nada
## delante del todo para ver que no aparece un apero fantasma.
const EN_FILA := [
	Profession.Speciality.CUIDADO,
	Profession.Speciality.TALLA,
	Profession.Speciality.ASTA,
	Profession.Speciality.PELETERIA,
	Profession.Speciality.CAZA_MAYOR,
	Profession.Speciality.ORILLA,
	Profession.Speciality.FORRAJEO,
	Profession.Speciality.LENA_FIBRA,
]
const PASO_M := 1.35


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VENTANA)
	get_root().size = VENTANA
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED

	var mundo := Node3D.new()
	get_root().add_child(mundo)

	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.74)
	env.ambient_light_energy = 1.1
	entorno.environment = env
	mundo.add_child(entorno)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	luz.light_energy = 2.0
	mundo.add_child(luz)

	var crowd := BandaCrowd.new()
	mundo.add_child(crowd)
	crowd.setup(EN_FILA.size())

	var ranuras: Array[Vector2i] = []
	for i in range(EN_FILA.size()):
		ranuras.append(crowd.add_person())

	var ancho := float(EN_FILA.size() - 1) * PASO_M
	var camara := Camera3D.new()
	camara.position = Vector3(ancho * 0.5, 1.0, ancho * 0.40 + 1.2)
	camara.rotation_degrees = Vector3(-5.0, 0.0, 0.0)
	mundo.add_child(camara)
	camara.current = true

	# Mirando a cámara, para que la mano derecha quede a la vista y no tapada por el cuerpo.
	# Con rumbo PI salían todos de espaldas: el cero ya mira hacia la cámara.
	for cuadro in range(120):
		for i in range(ranuras.size()):
			# Uno sí y otro no: sólo va vestido quien tenga un vestido del utillaje, así que
			# la fila enseña de paso las dos mitades (GRAFICOS §5.1).
			crowd.update(ranuras[i], Vector3(float(i) * PASO_M, 0.0, 0.0), 0.0,
				Inhabitant.State.TRABAJANDO, 1, EN_FILA[i], i % 2 == 0)
		await process_frame

	var foto := get_root().get_texture().get_image()
	if foto == null:
		print("AperosCaptura: no hubo foto")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("user://sondas/aperos")
	var ruta := "user://sondas/aperos/aperos.png"
	foto.save_png(ruta)
	print("foto: %s" % ProjectSettings.globalize_path(ruta))
	for i in range(EN_FILA.size()):
		print("  %d: %s" % [i,
			ClipsDeLaBanda.apero(Inhabitant.State.TRABAJANDO, EN_FILA[i])])
	quit()
