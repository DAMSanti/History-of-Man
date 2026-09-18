extends SceneTree
## ¿CABEN VEINTICINCO ESQUELETOS DE VERDAD? GRAFICOS §5.1.
##
## La banda va hoy con la animación horneada en una textura de vértices y dibujada como
## `MultiMesh`: cuesta 0,20 ms de GPU y no tiene huesos, así que no hay dónde colgar una
## herramienta ni cómo poner una prenda de geometría.
##
## Con los cuerpos nuevos —7 281 vértices contra 4 734— y **ropa modular de verdad**, el
## horneado deja de valer: cada pieza de ropa es otra malla y necesitaría **su propia**
## textura de vértices, unos 25 MB por pieza y 60 por atuendo. La alternativa es la de
## siempre, `Skeleton3D` + `AnimationPlayer` por persona, que era lo que el plan descartó
## **sin medirlo**. Esto lo mide.
##
## Monta el valle, esconde la banda de hoy, planta la misma gente con esqueleto en su sitio
## y compara: con ellos, sin ellos, y contra lo que cuesta la banda vieja.
##
##   godot --path . --script res://scripts/tests/EsqueletosProbe.gd
##
##   SITIO=56    en qué valle
##   CUADROS=90  cuántos cuadros por medida
##   ROPA=1      0 para medir sólo el cuerpo desnudo

const VENTANA := Vector2i(1920, 1080)
const ASENTARSE := 30
const DISTANCIA_M := 35.0

const CUERPO := "res://models/people/universal/cuerpos/Superhero_Male_FullBody.gltf"
const ANIMACIONES := "res://models/people/universal/animaciones/AL_Standard.fbx"
## Las cuatro piezas de un atuendo completo. Son mallas sueltas cosidas al mismo esqueleto.
const ATUENDO := ["Male_Peasant_Body", "Male_Peasant_Arms", "Male_Peasant_Legs",
	"Male_Peasant_Feet"]
## Qué animación se le pone a cada uno, repartidas para que no vayan todos al mismo paso.
const GESTOS := ["Idle", "Walk", "Fixing_Kneeling", "Sitting_Idle", "Crouch_Idle"]
## La altura a la que hay que escalar el modelo: viene en centímetros.
const ALTO_M := 1.70


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/esqueletos"
	Configuracion.ruta = "user://sondas/esqueletos/configuracion.cfg"
	var id := 56
	if not OS.get_environment("SITIO").is_empty():
		id = int(OS.get_environment("SITIO"))
	var cuadros := 90
	if not OS.get_environment("CUADROS").is_empty():
		cuadros = int(OS.get_environment("CUADROS"))
	var con_ropa := OS.get_environment("ROPA") != "0"

	var sitio: Site = null
	for s: Site in SiteSet.comarca().sites:
		if s.id == id:
			sitio = s
	if sitio == null:
		print("EsqueletosProbe: no hay sitio %d" % id)
		quit(1)
		return
	Expedition.site = sitio
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % id

	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VENTANA)
	get_root().size = VENTANA

	var demo: Node = load("res://scenes/demo_main.tscn").instantiate()
	get_root().add_child(demo)
	for i in range(240):
		await process_frame

	var sim: Object = demo.get("sim")
	var camara: Node = demo.get("camera")
	var vieja := _buscar(demo, "BandaCrowd") as Node3D
	if sim == null or camara == null or vieja == null:
		print("EsqueletosProbe: falta sim, cámara o banda")
		quit(1)
		return

	var gente: Array = sim.get("people")
	var centro := Vector3.ZERO
	for persona in gente:
		centro += persona.position as Vector3
	if not gente.is_empty():
		centro /= float(gente.size())
	camara.call("mirar_a", centro)
	camara.call("set_distance", DISTANCIA_M)

	# Los esqueletos nuevos, uno por persona y en su mismo sitio.
	var nuevos := Node3D.new()
	nuevos.name = "BandaConHuesos"
	demo.add_child(nuevos)
	var construidos := 0
	for i in range(gente.size()):
		var cuerpo := _montar(con_ropa)
		if cuerpo == null:
			break
		nuevos.add_child(cuerpo)
		cuerpo.position = gente[i].position
		cuerpo.rotation.y = randf() * TAU
		var player := _buscar(cuerpo, "AnimationPlayer") as AnimationPlayer
		if player != null:
			var gesto: String = GESTOS[i % GESTOS.size()]
			var cual := _clip(player, gesto)
			if not cual.is_empty():
				player.play(cual)
				player.seek(randf() * 2.0, true)
		construidos += 1

	paused = true
	camara.process_mode = Node.PROCESS_MODE_ALWAYS
	nuevos.process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_root().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)

	print("=== VEINTICINCO ESQUELETOS · valle %d · %d x %d ===" % [
		id, VENTANA.x, VENTANA.y])
	print("%d personas con hueso%s, a %.0f m" % [construidos,
		" y ropa" if con_ropa else " y en cueros", DISTANCIA_M])
	print("")
	print("%-22s %9s %9s %9s %9s" % ["", "GPU ms", "CPU ms", "fps", "VRAM MB"])

	vieja.visible = false
	var con_huesos := await _medir(vp, cuadros)
	nuevos.visible = false
	var sin_nadie := await _medir(vp, cuadros)
	vieja.visible = true
	var con_vieja := await _medir(vp, cuadros)
	vieja.visible = false
	nuevos.visible = true
	await _medir(vp, 2)
	var foto := get_root().get_texture().get_image()
	if foto != null:
		DirAccess.make_dir_recursive_absolute("user://sondas/esqueletos")
		foto.save_png("user://sondas/esqueletos/esqueletos.png")
		print("foto: %s" % ProjectSettings.globalize_path(
			"user://sondas/esqueletos/esqueletos.png"))

	_fila("con esqueletos", con_huesos)
	_fila("con la banda vieja", con_vieja)
	_fila("sin nadie", sin_nadie)
	print("")
	print("ESQUELETOS: %.2f ms GPU · %.2f ms CPU · %+d MB VRAM" % [
		con_huesos.gpu - sin_nadie.gpu, con_huesos.cpu - sin_nadie.cpu,
		int(con_huesos.vram - sin_nadie.vram)])
	print("VIEJA:      %.2f ms GPU · %.2f ms CPU" % [
		con_vieja.gpu - sin_nadie.gpu, con_vieja.cpu - sin_nadie.cpu])
	print("El presupuesto de GRAFICOS §1 para «Personajes» es 2,0 ms.")
	quit()


## Una persona entera: el cuerpo con su esqueleto, las piezas de ropa cosidas a ese mismo
## esqueleto, y el reproductor con la biblioteca de animaciones re-enraizada.
func _montar(con_ropa: bool) -> Node3D:
	var escena: PackedScene = load(CUERPO)
	if escena == null:
		print("EsqueletosProbe: no carga el cuerpo")
		return null
	var raiz := escena.instantiate() as Node3D
	var esqueleto := _buscar(raiz, "Skeleton3D") as Skeleton3D
	if esqueleto == null:
		print("EsqueletosProbe: el cuerpo no trae esqueleto")
		return null
	# Viene en centímetros: 1,70 m de persona.
	var alto := _alto(raiz)
	if alto > 0.001:
		raiz.scale = Vector3.ONE * (ALTO_M / alto)

	if con_ropa:
		for pieza: String in ATUENDO:
			var vestido: PackedScene = load(
				"res://models/people/universal/ropa/%s.gltf" % pieza)
			if vestido == null:
				continue
			var malla := _buscar(vestido.instantiate(), "MeshInstance3D") as MeshInstance3D
			if malla == null:
				continue
			var copia := MeshInstance3D.new()
			copia.mesh = malla.mesh
			copia.skin = malla.skin
			esqueleto.add_child(copia)
			copia.skeleton = NodePath("..")

	var player := AnimationPlayer.new()
	raiz.add_child(player)
	player.add_animation_library("", _biblioteca(esqueleto, raiz))
	return raiz


## La biblioteca se construye UNA VEZ y se comparte: los recursos `Animation` son los
## mismos para las veinticinco personas, lo único propio de cada una es el reproductor.
static var _cache: AnimationLibrary = null


func _biblioteca(esqueleto: Skeleton3D, raiz: Node) -> AnimationLibrary:
	if _cache != null:
		return _cache
	var fuente: PackedScene = load(ANIMACIONES)
	var escena := fuente.instantiate()
	var player := _buscar(escena, "AnimationPlayer") as AnimationPlayer
	var lib := AnimationLibrary.new()
	var ruta := raiz.get_path_to(esqueleto)
	for nombre: String in player.get_animation_list():
		var anim: Animation = player.get_animation(nombre).duplicate(true)
		for t in range(anim.get_track_count()):
			var hueso := anim.track_get_path(t).get_concatenated_subnames()
			anim.track_set_path(t, NodePath("%s:%s" % [ruta, hueso]))
		lib.add_animation(nombre.get_slice("|", 1) if "|" in nombre else nombre, anim)
	_cache = lib
	return lib


func _clip(player: AnimationPlayer, quiere: String) -> String:
	for n: String in player.get_animation_list():
		if n.begins_with(quiere):
			return n
	return ""


func _alto(raiz: Node) -> float:
	var caja := AABB()
	var primera := true
	for m in _todas(raiz):
		var aabb: AABB = (m as MeshInstance3D).get_aabb()
		caja = aabb if primera else caja.merge(aabb)
		primera = false
	return caja.size.y


func _todas(nodo: Node) -> Array[Node]:
	var out: Array[Node] = []
	if nodo is MeshInstance3D:
		out.append(nodo)
	for h in nodo.get_children():
		out.append_array(_todas(h))
	return out


func _fila(nombre: String, m: Dictionary) -> void:
	print("%-22s %9.2f %9.2f %9.1f %9.0f" % [nombre, m.gpu, m.cpu,
		1000.0 / maxf(m.gpu + m.cpu, 0.001), m.vram])


func _medir(vp: RID, cuadros: int) -> Dictionary:
	for i in range(ASENTARSE):
		await process_frame
	var gpu := 0.0
	var cpu := 0.0
	for i in range(cuadros):
		await process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	return {
		"gpu": gpu / float(cuadros),
		"cpu": cpu / float(cuadros),
		"vram": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
	}


func _buscar(nodo: Node, clase: String) -> Node:
	if nodo.get_class() == clase or (clase == "BandaCrowd" and nodo is BandaCrowd):
		return nodo
	for h in nodo.get_children():
		var f := _buscar(h, clase)
		if f != null:
			return f
	return null
