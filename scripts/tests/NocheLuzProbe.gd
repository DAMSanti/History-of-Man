extends SceneTree
## Cuanta luz hay de noche, contada y no mirada.
##
## «No se ve nada» puede ser tres cosas y desde el sofa se ven igual: que la
## luna este en fase nueva o bajo el horizonte, que su energia sea demasiado
## poca, o que el ambiente nocturno este a cero y no haya de donde rebote nada.
##
## Aqui se fotografia la boca de la cueva a varias horas y varios dias -para
## barrer las fases de la luna- y se mide el brillo medio de la imagen, junto
## con el estado real de la luna en cada momento.
##
##   DIAS=8      cuantas noches barrer, para pillar fases distintas
##   LUNA=0.4    forzar la energia de la luna, para barrer valores
##   FUEGO=30    forzar la energia de la hoguera, igual
##   APAGADO=1   dejar el hogar apagado, para el A/B honesto
##   SUELO=0.3   forzar el suelo de ambiente nocturno
##   FIJO=1      una sola noche con la luna alta, para comparar valores sin
##               que la fase enturbie la cuenta

const SITE_ID := 56

## Horas que se miran de cada noche.
static var HOURS: Array = [21.0, 23.0, 2.0, 4.0]


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
	for i in range(90):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var camera: Node = demo.camera if "camera" in demo else null
	var sky: Node = _find_sky(demo)
	if sim == null or camera == null:
		print("sin simulacion o camara"); quit(); return

	# El hogar, dado por levantado y encendido: se viene a mirar como alumbra,
	# no cuanto tarda la banda en construirlo.
	sim.camp_built[CampProjects.Kind.HOGAR] = true
	sim.hearth_lit = OS.get_environment("APAGADO").is_empty()
	sim.time_scale = 0.0

	camera.set_target(sim.home_forecourt if sim.home_forecourt != Vector3.ZERO
		else sim.home_position)
	camera.set_distance(40.0)
	camera.orbit_angle_v = -18.0
	for child in demo.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false

	var days := 8
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))
	if sky != null and not OS.get_environment("LUNA").is_empty():
		sky.moon_energy = float(OS.get_environment("LUNA"))
	if sky != null and not OS.get_environment("SUELO").is_empty():
		sky.ambient_night_floor = float(OS.get_environment("SUELO"))
	var fire_boost := 1.0
	if not OS.get_environment("FUEGO").is_empty():
		fire_boost = float(OS.get_environment("FUEGO")) / Bonfire.LIGHT_ENERGY
	# Una noche fija y con la luna alta: para comparar dos valores hace falta
	# que lo unico que cambie sea el valor.
	var fixed := not OS.get_environment("FIJO").is_empty()
	# El ancla: sin dia con que comparar, «0,05 de brillo» no dice nada.
	if not OS.get_environment("HORAS").is_empty():
		HOURS = []
		for piece: String in OS.get_environment("HORAS").split(","):
			HOURS.append(float(piece))

	var root := get_root()
	print("")
	print("=== LA NOCHE, MEDIDA ===")
	print("dia  hora   pantalla   boca      luna: estado  altura  energia")

	var reported := false
	var first_day: int = sim.day
	for extra in range(days):
		sim.day = first_day + extra
		# La fase de la luna sale de `season_day` -ver
		# `WorldEnvironmentSetup._elapsed_real_days`-, y hay que barrerla a
		# saltos de cuatro dias para pillar luna nueva y luna llena en pocas
		# fotos: el ciclo son veintinueve dias y medio.
		sim.season_day = 8 if fixed else (extra * 4) % Subsistence.DAYS_PER_SEASON
		for hour: float in HOURS:
			sim.hour = hour
			for i in range(14):
				await process_frame
				if fire_boost != 1.0:
					_boost_fires(demo, fire_boost)
			var image := root.get_texture().get_image()
			if image == null:
				print("sin imagen: hace falta ventana, no --headless")
				quit(); return
			var bright := _mean_luma(image)
			# Y el corro de la boca aparte: la hoguera alumbra un trozo, y
			# promediando la pantalla entera su luz se diluye en el valle
			# oscuro que la rodea. Lo que hay que poder contestar es «se ve la
			# entrada de la cueva», no «se ve el valle».
			var mouth := _mean_luma_centre(image)
			# El estado del fuego EN EL MOMENTO DE LA FOTO. Preguntandolo antes
			# de que corriera un cuadro salia siempre apagado -`HearthFire`
			# copia el estado en su `_process`- y parecia que la hoguera no
			# existia.
			if not reported:
				reported = true
				var fires: Array = []
				_fire_report(get_root(), fires)
				for line: String in fires:
					print("   %s" % line)
			var moon := _moon_state(sky)
			var sun_check := ""
			if sky != null:
				var sun_light: DirectionalLight3D = sky.get_node_or_null("SunLight")
				if sun_light == null:
					for child: Node in sky.get_children():
						if child is DirectionalLight3D and child.name != "MoonLight":
							sun_light = child as DirectionalLight3D
							break
				if sun_light != null:
					sun_check = "  (sol a %.1f)" % _elevation_of(sun_light)
			print("%3d %5.1f   %6.4f  boca %6.4f   %s%s" % [
				sim.day, hour, bright, mouth, moon, sun_check])
	quit()


## Sube la energia de todas las hogueras encendidas. Se hace cada cuadro
## porque el parpadeo la reescribe: `Bonfire._process` la recalcula sola.
func _boost_fires(node: Node, factor: float) -> void:
	if node is OmniLight3D:
		(node as OmniLight3D).light_energy *= factor
		return
	for child: Node in node.get_children():
		_boost_fires(child, factor)


## Que luces puntuales hay y como estan. Sin esto, «la hoguera no alumbra» no
## distingue entre que este apagada, que no exista o que no salga en cuadro.
func _fire_report(node: Node, into: Array) -> void:
	if node is OmniLight3D:
		var light := node as OmniLight3D
		into.append("%s energia %.1f alcance %.0f %s en %s" % [
			light.name, light.light_energy, light.omni_range,
			"visible" if light.is_visible_in_tree() else "OCULTA",
			light.global_position])
		return
	for child: Node in node.get_children():
		_fire_report(child, into)


## El brillo medio de la imagen, en luminancia lineal aproximada.
func _mean_luma(image: Image) -> float:
	var total := 0.0
	var count := 0
	# Una de cada ocho filas y columnas: con cuatro millones de pixeles por
	# captura, mirarlos todos son minutos por foto y la respuesta no cambia.
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / maxf(float(count), 1.0)


## El nodo que monta cielo, sol y luna, este donde este colgado.
func _find_sky(node: Node) -> Node:
	if node.get_script() != null 			and String(node.get_script().resource_path).ends_with(
				"WorldEnvironmentSetup.gd"):
		return node
	for child: Node in node.get_children():
		var found := _find_sky(child)
		if found != null:
			return found
	return null


## El brillo del tercio central, donde cae la boca de la cueva y su hoguera.
func _mean_luma_centre(image: Image) -> float:
	var w := image.get_width()
	var h := image.get_height()
	var total := 0.0
	var count := 0
	for y in range(h / 3, h * 2 / 3, 4):
		for x in range(w / 3, w * 2 / 3, 4):
			var c := image.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / maxf(float(count), 1.0)


## Lo que la luna esta haciendo ahora mismo, para poder separar «no hay luna»
## de «la luna alumbra poco».
func _moon_state(sky: Node) -> String:
	if sky == null:
		return "sin nodo de ambiente"
	var light: DirectionalLight3D = sky.get_node_or_null("MoonLight")
	if light == null:
		return "sin luz de luna"
	if not light.visible:
		return "apagada"
	var pitch := _elevation_of(light)
	return "encendida  %6.1f  %7.4f" % [pitch, light.light_energy]


## A que altura sobre el horizonte esta la fuente de una luz direccional.
##
## Una DirectionalLight3D VIAJA por su -Z, asi que el sitio de donde VIENE es
## su +Z. Midiendolo al reves salia la luna siempre bajo el horizonte y parecia
## que alumbraba desde debajo del suelo, que no era el fallo.
func _elevation_of(light: DirectionalLight3D) -> float:
	return rad_to_deg(asin(clampf(light.global_transform.basis.z.y, -1.0, 1.0)))
