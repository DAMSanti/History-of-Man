extends SceneTree
## ¿Desaparecen árboles al mover la cámara? GRAFICOS §7.1, «Sin aros ni huecos».
##
## **Con ventana**, un escalón por corrida (0 Mínimo, 1 Medio, 2 Alto, 3 Ultra):
##
##   ESCALON=1 godot --path . --script res://scripts/tests/ArbolHuecoProbe.gd
##
## Con ROMPER=1 esconde el 3D que había montado al empezar, y tiene que contar huecos: es
## la prueba de que el instrumento los ve.
##
## Sesenta segundos de cámara a su velocidad máxima sobre el bosque —veinte de paneo con
## Mayús, veinte de órbita, veinte de zoom de ida y vuelta—, pintando sólo el bosque y
## guardando la pose y la máscara de árbol tres veces por segundo. Después **se vuelve a
## cada pose con la cámara quieta**, se espera a que el bosque tenga montado todo, y se
## compara: un hueco es una mancha de árbol que está asentada y faltaba en vivo, de más
## superficie que una copa a la distancia del relevo. El criterio es **cero huecos**.
##
## Contra la misma pose asentada y no contra el cuadro de al lado: con la cámara
## moviéndose, los árboles cambian de píxel legítimamente, y comparar cuadros seguidos
## contaría el movimiento como huecos. La spec habla de «desaparece y vuelve en menos
## de 1 s»; lo que se mide es lo que falta en un instante contra lo que debería haber,
## que es la misma pregunta sin depender de cuánto tarde en volver.

const SEGUNDOS_POR_TRAMO := 20.0
const MUESTRAS_POR_SEGUNDO := 3.0
## Como en `ArbolAroProbe`: la máscara en vivo se engorda un poco, para que una silueta
## desplazada un píxel —un nivel de detalle distinto, el 3D contra el impostor— no
## cuente como árbol que falta.
const HOLGURA_PX := 3
const COPA_M := 4.0


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var escalon := int(OS.get_environment("ESCALON")) if not OS.get_environment("ESCALON").is_empty() else 1
	SoloElBosque.preparar_sitio(escalon)
	change_scene_to_file("res://scenes/demo_main.tscn")
	for _i in range(900):
		await process_frame
		if current_scene != null and current_scene.get("camera") != null:
			break
	var demo := current_scene
	var camara: OrbitalCamera = demo.get("camera")
	var bosque := SoloElBosque.buscar(demo, "Bosque") as Forest
	if camara == null or bosque == null:
		print("no arrancó"); quit(1); return
	for _i in range(30):
		await process_frame
	paused = true
	camara.process_mode = Node.PROCESS_MODE_ALWAYS
	bosque.process_mode = Node.PROCESS_MODE_ALWAYS
	SoloElBosque.aislar(demo, bosque, camara)
	SoloElBosque.en_verano(bosque)
	var relevo := bosque.radio_de_cerca()
	var sitio := SoloElBosque.lo_mas_espeso(bosque)
	camara.set_target(sitio)
	camara.orbit_angle_v = -20.0
	camara.set_distance(60.0)
	camara._update_camera()
	await SoloElBosque.asentar(self, bosque)
	print("escalón %d · relevo a %.0f m · sobre %s" % [escalon, relevo, str(sitio)])

	# --- el barrido, en vivo ---------------------------------------------------------
	var poses: Array[Array] = []
	var mascaras: Array[Dictionary] = []
	var t := 0.0
	var siguiente := 0.0
	var velocidad_de_paneo := camara.move_speed * clampf(camara.orbit_distance / 500.0, 0.15, 4.0) \
		* camara.sprint_multiplier
	var inicio := Time.get_ticks_msec()
	var peor_cuadro := 0.0
	var pose_pintada: Array = []
	# ROMPER=1 esconde el 3D montado durante el barrido: el hueco que la sonda tiene que
	# ver. Para comprobar el instrumento, no el bosque.
	var roto: Array[Node3D] = []
	if OS.get_environment("ROMPER") == "1":
		for bloque: Vector2i in bosque._live:
			for nodo: Node3D in bosque._live[bloque]:
				nodo.visible = false
				roto.append(nodo)
	while t < SEGUNDOS_POR_TRAMO * 3.0:
		var antes := Time.get_ticks_msec()
		await process_frame
		var delta := float(Time.get_ticks_msec() - antes) / 1000.0
		peor_cuadro = maxf(peor_cuadro, delta)
		t += delta
		# LA TEXTURA QUE SE LEE AQUÍ ES LA DEL CUADRO ANTERIOR, pintado con la pose de la
		# vuelta anterior. Guardarla con la pose nueva comparaba cada máscara con una pose
		# desplazada un cuadro, y los bordes de todos los árboles salían como huecos.
		if t >= siguiente and not pose_pintada.is_empty():
			siguiente += 1.0 / MUESTRAS_POR_SEGUNDO
			poses.append(pose_pintada)
			mascaras.append(SoloElBosque.mascara(root))
		if t < SEGUNDOS_POR_TRAMO:
			# Paneo en línea recta con Mayús, a la velocidad de `OrbitalCamera._process`.
			camara.target_position += Vector3(1.0, 0.0, 0.35).normalized() * velocidad_de_paneo * delta
		elif t < SEGUNDOS_POR_TRAMO * 2.0:
			# Órbita: media vuelta cada cuatro segundos.
			camara.orbit_angle_h += 45.0 * delta
		else:
			# Zoom de ida y vuelta entre lo más cerca y 400 m, como con Q y E.
			var fase := fmod((t - SEGUNDOS_POR_TRAMO * 2.0) / 5.0, 2.0)
			var hacia := 400.0 if fase < 1.0 else camara.min_distance
			camara.set_distance(lerpf(camara.orbit_distance, hacia, clampf(delta * 1.5, 0.0, 1.0)))
			camara.target_position += Vector3(-0.3, 0.0, 1.0).normalized() * velocidad_de_paneo * 0.3 * delta
		camara._apoyar_el_centro()
		camara._update_camera()
		pose_pintada = [camara.target_position, camara.orbit_distance, camara.orbit_angle_h, camara.orbit_angle_v]
	print("  barrido: %d muestras en %.1f s de reloj, peor cuadro %.0f ms" % [poses.size(),
		float(Time.get_ticks_msec() - inicio) / 1000.0, peor_cuadro * 1000.0])

	for nodo: Node3D in roto:
		if is_instance_valid(nodo):
			nodo.visible = true

	# --- cada pose, asentada -----------------------------------------------------------
	var huecos := 0
	var peor := 0
	for i in range(poses.size()):
		var pose: Array = poses[i]
		camara.target_position = pose[0]
		camara.orbit_distance = pose[1]
		camara.orbit_angle_h = pose[2]
		camara.orbit_angle_v = pose[3]
		camara._update_camera()
		await SoloElBosque.asentar(self, bosque)
		var asentada := SoloElBosque.mascara(root)
		var vivo: Dictionary = mascaras[i]
		var w: int = vivo["w"]
		var h: int = vivo["h"]
		var real := SoloElBosque.dilatar(vivo["m"], w, h, HOLGURA_PX)
		var falta := PackedByteArray()
		falta.resize(w * h)
		for j in range(w * h):
			if (asentada["m"] as PackedByteArray)[j] == 1 and real[j] == 0:
				falta[j] = 1
		var mayor := SoloElBosque.mayor_mancha(falta, w, h)
		var px_por_m := float(h) / (2.0 * relevo * tan(deg_to_rad(camara.fov * 0.5)))
		# Nunca por debajo de la ventana de holgura: ahí el instrumento no separa un hueco del
		# ruido. En Mínimo, una copa a 350 m son 3 px, y cuatro píxeles que parpadeaban en
		# el perfil de una loma a kilómetros contaban como hueco.
		var copa := maxf(PI * pow(COPA_M * 0.5 * px_por_m, 2.0), pow(2.0 * HOLGURA_PX + 1.0, 2.0))
		peor = maxi(peor, mayor)
		if float(mayor) >= copa:
			huecos += 1
			print("  HUECO en la muestra %d (%.1f s): %d px, una copa son %.0f" % [i,
				float(i) / MUESTRAS_POR_SEGUNDO, mayor, copa])
			var ver := root.get_texture().get_image()
			for j in range(w * h):
				if falta[j] == 1:
					ver.fill_rect(Rect2i((j % w) * SoloElBosque.REDUCE, (j / w) * SoloElBosque.REDUCE,
						SoloElBosque.REDUCE, SoloElBosque.REDUCE), Color.RED)
			ver.save_png("user://capturas/hueco_%d_%d.png" % [escalon, i])
	print("huecos: %d de %d muestras · la mayor mancha que faltó: %d px" % [huecos, poses.size(), peor])
	quit()
