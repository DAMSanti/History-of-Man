extends SceneTree
## Cuánto se acercan dos personas que van andando a la vez.
##
## «Se solapan al andar» no se puede discutir mirando: en una vista cenital de
## dos kilómetros dos cuerpos a metro y medio parecen uno solo de todas formas.
## Lo que se mide aquí es la distancia MÍNIMA entre dos personas que estén las
## dos en movimiento, a lo largo de una jornada entera, y con qué frecuencia
## bajan de lo que mide un cuerpo.
##
## La referencia: un adulto ocupa medio metro de ancho. Por debajo de eso los
## dos modelos comparten píxeles y se leen como uno; a partir de metro y medio
## se ven claramente como dos.
##
## Sólo cuentan las parejas EN TRÁNSITO: las dos personas moviéndose y las dos
## lejos de su destino. Cerca del tajo el carril se deshace a propósito -si no,
## nadie llegaría nunca a su sitio- y dos personas juntas ahí no son el problema
## que se está midiendo; y en el campamento se amontonan porque el campamento es
## un punto.
##
## Se acompaña de una captura de una pareja andando junta, buscada en vivo, que
## es la prueba de que el número dice lo que parece decir.

const SITE_ID := 56

## Cuántos fotogramas de partida se miran.
const FRAMES := 2400

## Ancho de un cuerpo, en metros: por debajo de esto se solapan.
const BODY := 0.5

## A partir de cuántos metros del destino se cuenta que alguien va de camino.
## Por debajo, el carril ya se está deshaciendo para poder llegar.
const IN_TRANSIT := 30.0


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
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("sin simulacion"); quit(); return

	# La partida arranca con la tabla de trabajos en blanco -el primer reparto
	# es del jugador-, asi que la sonda tiene que repartir para tener banda
	# que medir. Ver `SettlementSim.assign_default_jobs`.
	sim.assign_default_jobs()

	# La partida arranca en pausa, esperando al jugador: sin esto el reloj no
	# corre y no anda nadie.
	sim.time_scale = 5.0

	var gaps := PackedFloat32Array()
	var overlapped := 0

	for frame in range(FRAMES):
		await process_frame
		var walking := _in_transit(sim)
		for i in range(walking.size()):
			for j in range(i + 1, walking.size()):
				var gap := _flat(walking[i].position, walking[j].position)
				gaps.append(gap)
				if gap < BODY:
					overlapped += 1

	if gaps.is_empty():
		print("nadie llego a andar a la vez"); quit(); return
	var sorted := gaps.duplicate()
	sorted.sort()

	print("")
	print("carril %.2f m" % SettlementSim.LANE_SPREAD)
	print("parejas en transito miradas: %d" % gaps.size())
	print("la mas junta: %.2f m · el 1%% mas junto: %.2f m · el 5%%: %.2f m" % [
		sorted[0], sorted[maxi(sorted.size() / 100, 0)],
		sorted[maxi(sorted.size() / 20, 0)]])
	print("por debajo de un cuerpo (%.1f m): %d, o sea %.2f %%" % [
		BODY, overlapped, 100.0 * float(overlapped) / float(gaps.size())])

	# Y la foto: se espera a pillar en vivo una pareja andando junta, porque
	# fotografiar el sitio donde estuvieron hace mil fotogramas no enseña nada.
	var camera := Camera3D.new()
	camera.far = 4000.0
	demo.add_child(camera)
	_hide_ui(demo)
	for frame in range(FRAMES):
		await process_frame
		var walking := _in_transit(sim)
		var found := false
		for i in range(walking.size()):
			for j in range(i + 1, walking.size()):
				if _flat(walking[i].position, walking[j].position) > 6.0:
					continue
				var middle := (walking[i].position + walking[j].position) * 0.5
				camera.global_position = middle + Vector3(7.0, 4.0, 7.0)
				camera.look_at(middle + Vector3(0.0, 1.0, 0.0), Vector3.UP)
				camera.make_current()
				found = true
				break
			if found:
				break
		if not found:
			continue
		for i in range(6):
			await process_frame
		root.get_texture().get_image().save_png("user://carril_%s.png" % (
			"con" if SettlementSim.LANE_SPREAD > 0.01 else "sin"))
		break

	print("captura en %s" % ProjectSettings.globalize_path("user://"))
	quit()


## Quién va de camino ahora mismo: moviéndose y todavía lejos de su destino.
func _in_transit(sim: Node) -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	for person: Inhabitant in sim.people:
		if _walking(person) 				and _flat(person.position, person.target) > IN_TRANSIT:
			out.append(person)
	return out


func _walking(person: Inhabitant) -> bool:
	return person.state == Inhabitant.State.YENDO \
		or person.state == Inhabitant.State.VOLVIENDO \
		or person.state == Inhabitant.State.BUSCANDO


## Distancia en planta: la altura no separa dos cuerpos que se pisan.
func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _hide_ui(node: Node) -> void:
	var layer := node as CanvasLayer
	if layer != null:
		layer.visible = false
		return
	for child in node.get_children():
		_hide_ui(child)
