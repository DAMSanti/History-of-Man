extends SceneTree
## ¿Hay aro en el relevo del bosque? Con la cámara quieta. GRAFICOS §7.1, «Sin aros ni
## huecos».
##
## **Con ventana**, un escalón por corrida (0 Mínimo, 1 Medio, 2 Alto, 3 Ultra):
##
##   ESCALON=1 godot --path . --script res://scripts/tests/ArbolAroProbe.gd
##
## Sobre el bosque más espeso del valle, con la cámara de juego en los ángulos de
## `ArbolBordeProbe` y los dos encuadres de `BosqueCaptura`, pinta sólo el bosque dos
## veces —el de verdad, y **sólo los impostores**, que cubren todo el bosque sin relevo—
## y lanza un rayo al terreno por cada píxel para saber su anillo de 25 m. **Cobertura
## de un anillo = qué parte del árbol de la referencia sigue habiendo en el de verdad.**
## Sin aro, todos rondan el 100 %; el aro es el anillo del relevo por debajo. El
## criterio de la spec es que caiga **dentro del rango —mínimo a máximo— de los anillos
## que no lo contienen**.
##
## Contra la referencia y no en bruto, a medir: en bruto, con la distancia del suelo
## detrás de cada píxel, los árboles de cerca tapan suelo más lejano, los anillos de
## cerca salían vacíos (0-18 %) y el rango era tan ancho que ningún aro podía caer
## fuera. En Mínimo la referencia son las láminas de lejos, que nunca se esconden.

const ANILLO_M := 25.0
## Un anillo con menos píxeles de suelo que esto no cuenta: un borde de pantalla no es
## una medida.
const PIXELES_MINIMOS := 150
## La máscara real se engorda estos píxeles (a 1/4) antes de comparar. De cerca, el
## impostor de la referencia es una mancha más gorda que la silueta 3D, y sin holgura
## eso restaba cobertura justo donde empieza el 3D sin que faltara ningún árbol —el
## anillo del relevo medía 85 %—. Un árbol entero que falta a 40 m son unos 30 píxeles
## de ancho: tres no lo tapan.
const HOLGURA_PX := 3
## Una copa, para decidir si lo que falta es un árbol o ruido de siluetas: el ancho de
## copa de los modelos va de 4 a 12 m (los radios de `ArbolImpostores`), y se toma el
## más estrecho para no dejar pasar ninguno.
const COPA_M := 4.0
## Ángulo vertical y distancia de órbita. Los de `ArbolBordeProbe`, al zoom más cercano,
## y los dos encuadres de `BosqueCaptura`.
const POSES := [[-10.0, 0.0], [-20.0, 0.0], [-30.0, 0.0], [-40.0, 0.0], [-60.0, 0.0],
	[-89.0, 0.0], [-38.0, 90.0], [-12.0, 38.0], [-12.0, 60.0], [-20.0, 120.0], [-8.0, 200.0]]


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
	print("escalón %d · relevo a %.0f m · sobre %s" % [escalon, relevo, str(sitio)])

	var espacio := camara.get_world_3d().direct_space_state
	var aros := 0
	for pose: Array in POSES:
		camara.orbit_angle_v = float(pose[0])
		camara.set_distance(float(pose[1]) if float(pose[1]) > 0.0 else camara.min_distance)
		camara._update_camera()
		await SoloElBosque.asentar(self, bosque)
		var m := SoloElBosque.mascara(root)
		var captura := root.get_texture().get_image()
		var referencia := await _solo_impostores(bosque)
		var w: int = m["w"]
		var h: int = m["h"]
		var real := SoloElBosque.dilatar(m["m"], w, h, HOLGURA_PX)
		var arbol := {}
		var suelo := {}
		var anillo_de := PackedInt32Array()
		anillo_de.resize(w * h)
		anillo_de.fill(-1)
		var rayo := PhysicsRayQueryParameters3D.new()
		for y in range(h):
			for x in range(w):
				var pantalla := Vector2((x + 0.5) * SoloElBosque.REDUCE, (y + 0.5) * SoloElBosque.REDUCE)
				rayo.from = camara.project_ray_origin(pantalla)
				rayo.to = rayo.from + camara.project_ray_normal(pantalla) * 6000.0
				var golpe := espacio.intersect_ray(rayo)
				if golpe.is_empty():
					continue
				if (referencia["m"] as PackedByteArray)[y * w + x] == 0:
					continue
				var anillo := int(floor((golpe["position"] as Vector3).distance_to(camara.global_position) / ANILLO_M))
				anillo_de[y * w + x] = anillo
				suelo[anillo] = int(suelo.get(anillo, 0)) + 1
				if real[y * w + x] == 1:
					arbol[anillo] = int(arbol.get(anillo, 0)) + 1
		var del_relevo := int(floor(relevo / ANILLO_M))
		var minimo := 2.0
		var maximo := -1.0
		var cobertura := {}
		for anillo: int in suelo:
			if int(suelo[anillo]) < PIXELES_MINIMOS:
				continue
			var c := float(arbol.get(anillo, 0)) / float(suelo[anillo])
			cobertura[anillo] = c
			if anillo != del_relevo:
				minimo = minf(minimo, c)
				maximo = maxf(maximo, c)
		var linea := "  %4.0f° a %3.0f m ·" % [pose[0], camara.orbit_distance]
		var anillos := cobertura.keys()
		anillos.sort()
		for anillo: int in anillos:
			linea += " %s%d:%.0f%%" % ["*" if anillo == del_relevo else "", int(anillo * ANILLO_M), float(cobertura[anillo]) * 100.0]
		if not cobertura.has(del_relevo):
			print(linea + "  · el relevo no está en pantalla")
			continue
		var c_relevo: float = cobertura[del_relevo]
		var dentro := maximo < 0.0 or (c_relevo >= minimo - 0.005 and c_relevo <= maximo + 0.005)
		# Lo que falta en el anillo del relevo, en manchas: ¿falta algún árbol entero?
		var falta := PackedByteArray()
		falta.resize(w * h)
		for i in range(w * h):
			if anillo_de[i] == del_relevo and (referencia["m"] as PackedByteArray)[i] == 1 and real[i] == 0:
				falta[i] = 1
		var mayor := SoloElBosque.mayor_mancha(falta, w, h)
		if OS.get_environment("VER_FALTA") == "1":
			var ver := captura.duplicate() as Image
			for i in range(w * h):
				if falta[i] == 1:
					ver.fill_rect(Rect2i((i % w) * SoloElBosque.REDUCE, (i / w) * SoloElBosque.REDUCE, SoloElBosque.REDUCE, SoloElBosque.REDUCE), Color.RED)
			ver.save_png("user://capturas/aro_falta_%d_%d_%d.png" % [escalon, int(-float(pose[0])), int(camara.orbit_distance)])
		var px_por_m := float(h) / (2.0 * relevo * tan(deg_to_rad(camara.fov * 0.5)))
		# Nunca por debajo de la ventana de holgura: ahí el instrumento no separa un hueco del
		# ruido. En Mínimo, una copa a 350 m son 3 px, y cuatro píxeles que parpadeaban en
		# el perfil de una loma a kilómetros contaban como hueco.
		var copa := maxf(PI * pow(COPA_M * 0.5 * px_por_m, 2.0), pow(2.0 * HOLGURA_PX + 1.0, 2.0))
		var aro := not dentro and float(mayor) >= copa
		if aro:
			aros += 1
		print(linea + "  · relevo %.1f%% entre %.1f%% y %.1f%%, mayor mancha que falta %d px (una copa, %.0f): %s" % [
			c_relevo * 100.0, minimo * 100.0, maximo * 100.0, mayor, copa, "ARO" if aro else "ok"])
		captura.save_png("user://capturas/aro_%d_%d.png" % [escalon, int(-float(pose[0]))])
	print("aros: %d" % aros)
	quit()


## La máscara con sólo los impostores: el 3D —o las láminas cruzadas de cerca, en
## Mínimo— escondido, y el impostor sin esconder en ningún radio. Con el bosque parado
## para que `_poner_el_ojo` no lo vuelva a esconder.
func _solo_impostores(bosque: Forest) -> Dictionary:
	bosque.process_mode = Node.PROCESS_MODE_DISABLED
	var escondidos: Array[Node3D] = []
	for bloque: Vector2i in bosque._live:
		for nodo: Node3D in bosque._live[bloque]:
			if nodo.visible:
				nodo.visible = false
				escondidos.append(nodo)
	for material: ShaderMaterial in bosque._mat_vistas:
		material.set_shader_parameter("oculto_hasta", -1.0)
	for _i in range(4):
		await process_frame
	var referencia := SoloElBosque.mascara(root)
	for nodo: Node3D in escondidos:
		nodo.visible = true
	bosque.process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in range(4):
		await process_frame
	return referencia
