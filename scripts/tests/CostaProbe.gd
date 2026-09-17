extends SceneTree
## Diez jornadas viviendo en la costa de la época: EPOCA_01 §10.2, tarea 12.
##
## Funda en uno de los abrigos hipotéticos —el del Nansa por defecto—, deja correr diez
## jornadas y cuenta lo que sólo puede salir de tener mar al lado: parajes de marisqueo y
## de pesca de orilla, y marisco y pescado en el almacén. De paso mide lo que cuesta
## inventar el valle.
##
##   godot --path . --script res://scripts/tests/CostaProbe.gd
##
##   CUAL=0..3   qué abrigo (Nansa, Saja-Besaya, Pas, Asón)
##   DIAS=10     cuántas jornadas
##   CAPTURA=0   sin captura del valle

const SEGUNDOS_TOPE := 900.0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Guardado.carpeta = "user://sondas/mapas"
	var cual := 0
	if not OS.get_environment("CUAL").is_empty():
		cual = int(OS.get_environment("CUAL"))
	var dias := 10
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	var sitio: Site = SitiosDeLaCosta.como_sitios()[cual]
	print("=== LA COSTA DE LA ÉPOCA: %s ===" % sitio.display_name())
	print("cota %.0f m · el mar de la época a %.0f m" % [sitio.elevation, -120.0])

	GameState.sea_level_m = -120.0
	Expedition.sea_level_m = -120.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.site = sitio

	# EL VALLE, INVENTADO: lo mismo que hace el juego al fundar, y con su reloj.
	var t0 := Time.get_ticks_msec()
	var valle: HeightmapData = await PreparaValle.new().preparar(self, sitio)
	if valle == null:
		print("MAL: no se pudo levantar el valle")
		quit(1)
		return
	print("valle: %d x %d a %.0f m · cotas %.0f..%.0f · %d ms" % [valle.width, valle.height,
		valle.meters_per_sample, valle.min_elevation, valle.max_elevation,
		Time.get_ticks_msec() - t0])
	var bajo_el_mar := 0
	for cota: float in valle.elevations:
		if cota <= -120.0:
			bajo_el_mar += 1
	print("mar en el recuadro: %.0f %% de las muestras"
		% (100.0 * float(bajo_el_mar) / float(valle.elevations.size())))

	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % sitio.id
	var size_m := valle.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.region_offset = Vector2(
		clampf(valle.u_for_lon(sitio.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(valle.v_for_lat(sitio.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	var demo: Node = null
	for i in range(1200):
		await process_frame
		demo = current_scene
		if demo != null and ("sim" in demo) and demo.sim != null and i > 120:
			break
	if demo == null or not ("sim" in demo):
		print("MAL: la escena no arrancó")
		quit(1)
		return
	var sim: Node = demo.sim
	demo.ui.visible = false
	# LOS OFICIOS, REPARTIDOS: el juego los deja al jugador, así que una sonda que no
	# reparta ve a quince personas ociosas y un almacén vacío —y eso no dice nada del mar
	# (2026-09-16)—. Con ribera, que es la que marisquea y pesca.
	_repartir(sim)
	sim.time_scale = 20.0

	var primero: int = sim.day
	var arranque := Time.get_ticks_msec()
	while sim.day < primero + dias:
		await process_frame
		if float(Time.get_ticks_msec() - arranque) / 1000.0 > SEGUNDOS_TOPE:
			print("(se acabó el tiempo en la jornada %d)" % sim.day)
			break
	sim.time_scale = 0.0

	print("")
	print("--- tras %d jornadas ---" % (sim.day - primero))
	var por_oficio: Dictionary = {}
	for paraje: Paraje in sim.parajes.list:
		for oficio: int in paraje.activities:
			por_oficio[oficio] = int(por_oficio.get(oficio, 0)) + 1
	for oficio: int in [Subsistence.Activity.MARISQUEO, Subsistence.Activity.PESCA,
			Subsistence.Activity.CAZA, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		print("   parajes de %s: %d" % [Subsistence.activity_name(
			oficio as Subsistence.Activity).to_lower(), int(por_oficio.get(oficio, 0))])
	for kind: int in [Materia.Kind.MARISCO, Materia.Kind.PESCADO, Materia.Kind.CARNE,
			Materia.Kind.PIEDRA]:
		print("   %s en el almacén: %.1f" % [Materia.material_name(kind as Materia.Kind),
			sim.store.amount(kind as Materia.Kind)])
	# DÓNDE ESTÁ EL MARISQUEO, si es que está: en el campo de recursos, y si se llega.
	var con_marisco := 0
	var alcanzables := 0
	var mas_cerca := INF
	var mas_cerca_alcanzable := INF
	var muestra := Vector3.ZERO
	for cz in range(sim.field.height):
		for cx in range(sim.field.width):
			var cuanto: float = sim.field.abundance_cell(Subsistence.Activity.MARISQUEO, cx, cz)
			if cuanto <= 0.01:
				continue
			con_marisco += 1
			var punto: Vector3 = sim.field.cell_center(cx, cz)
			punto.y = demo.terrain.get_height_at(punto)
			var lejos: float = punto.distance_to(sim.home_position)
			if lejos < mas_cerca:
				mas_cerca = lejos
				muestra = punto
			if sim.marcha.can_reach(punto, 40.0):
				alcanzables += 1
				mas_cerca_alcanzable = minf(mas_cerca_alcanzable, lejos)
	print("   campo: %d celdas con marisco, %d alcanzables" % [con_marisco, alcanzables])
	print("   la más cercana a casa, a %.0f m: vado %.2f · se llega %s" % [mas_cerca,
		demo.terrain.crossing_difficulty_at(muestra),
		"sí" if sim.marcha.can_reach(muestra, 40.0) else "NO"])
	if alcanzables > 0:
		print("   la más cercana a la que se llega, a %.0f m" % mas_cerca_alcanzable)
	# Y a qué distancia está el agua de casa, para saber si el abrigo es de costa.
	var al_mar := INF
	for radio in range(50, 2000, 50):
		for grados in range(0, 360, 20):
			var rad := deg_to_rad(float(grados))
			var p: Vector3 = sim.home_position + Vector3(cos(rad), 0.0, sin(rad)) * float(radio)
			if demo.terrain.is_underwater(p):
				al_mar = minf(al_mar, float(radio))
	print("   el mar, a %.0f m del abrigo" % al_mar)

	# QUÉ HACE LA GENTE: si no trabaja nadie, el almacén vacío no dice nada del mar.
	var estados: Dictionary = {}
	var oficios: Dictionary = {}
	for person: Inhabitant in sim.people:
		estados[person.state] = int(estados.get(person.state, 0)) + 1
		oficios[person.oficio_de_hoy] = int(oficios.get(person.oficio_de_hoy, 0)) + 1
	print("   estados: %s" % str(estados))
	for oficio: int in oficios:
		print("      %s: %d" % [Profession.job_name(oficio as Profession.Job),
			int(oficios[oficio])])
	print("   despensa: %.0f raciones · hora %.1f del día %d" % [
		sim.store.rations_available() if sim.store.has_method("rations_available") else -1.0,
		sim.hour, sim.day])

	# EL PERFIL POR EL EJE DE LA RAMPA: del punto del sitio hacia el mar, que es por
	# donde ValleDeLaPlataforma abre la bajada.
	var regional: HeightmapData = load("res://data/dem/cantabria_region.res")
	var plataforma := RelieveDeLaPlataforma.para(regional, -120.0,
		RiosDeLaRegion.cargar().de_la_plataforma)
	var eje_rampa := ValleDeLaPlataforma._hacia_el_mar(plataforma, sitio, 40.0)
	print("   la rampa mira a (%.2f, %.2f) —este, norte—" % [eje_rampa.x, eje_rampa.y])
	for metros in range(0, 400, 40):
		var lon := sitio.lon + eje_rampa.x * float(metros) / (111320.0 * cos(deg_to_rad(sitio.lat)))
		var lat := sitio.lat + eje_rampa.y * float(metros) / 111320.0
		var punto: Vector3 = demo.terrain.geo_to_world(lon, lat)
		punto.y = demo.terrain.get_height_at(punto)
		print("      rampa %4d m · cota %7.1f · vado %.2f · conectado %s" % [metros,
			demo.terrain.cota_en_metros(punto),
			demo.terrain.crossing_difficulty_at(punto),
			"sí" if sim.marcha.can_reach(punto, 5.0) else "NO"])

	# EL PERFIL DEL ABRIGO AL AGUA: cota, vado del mar y si la rejilla lo da por
	# conectado. Es lo que dice si se puede ir a mariscar.
	var hacia := Vector3.ZERO
	var mas_cerca_mar := INF
	for grados in range(0, 360, 10):
		var rad := deg_to_rad(float(grados))
		for radio in range(40, 1200, 20):
			var p2: Vector3 = sim.home_position + Vector3(cos(rad), 0.0, sin(rad)) * float(radio)
			if demo.terrain.is_underwater(p2) and float(radio) < mas_cerca_mar:
				mas_cerca_mar = float(radio)
				hacia = Vector3(cos(rad), 0.0, sin(rad))
	print("   perfil hacia el agua (a %.0f m):" % mas_cerca_mar)
	for radio in range(0, int(mas_cerca_mar) + 120, 40):
		var p3: Vector3 = sim.home_position + hacia * float(radio)
		p3.y = demo.terrain.get_height_at(p3)
		print("      %4d m · cota %7.1f m · vado %.2f · conectado %s" % [radio,
			demo.terrain.cota_en_metros(p3),
			demo.terrain.crossing_difficulty_at(p3),
			"sí" if sim.marcha.can_reach(p3, 5.0) else "NO"])

	var en_el_agua := 0
	for person: Inhabitant in sim.people:
		if demo.terrain.is_underwater(person.position):
			en_el_agua += 1
	print("   gente dentro del agua ahora mismo: %d (tiene que ser 0 o estar en la orilla)"
		% en_el_agua)

	if OS.get_environment("CAPTURA") != "0":
		# AL MEDIODÍA: la jornada se cierra a medianoche, así que la captura salía de
		# noche y no se veía ni el mar (2026-09-16).
		sim.hour = 12.0
		demo.ui.visible = true
		demo.camera.set_target(sim.home_position)
		demo.camera.set_distance(demo.camera.distancia_para_mirar() * 1.6)
		for i in range(90):
			await process_frame
		var shot := get_root().get_texture().get_image()
		if shot != null:
			shot.save_png("user://costa_valle.png")
			print("captura en %s" % ProjectSettings.globalize_path("user://costa_valle.png"))
	quit()


## Quién hace qué: cuatro a la ribera —marisqueo y pesca—, y el resto repartido.
func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RIBERA: 4,
		Profession.Job.RECOLECCION: 4,
		Profession.Job.CAZA: 2,
		Profession.Job.EXPLORACION: 2,
	}
	for person: Inhabitant in sim.people:
		for job: int in Profession.Job.values():
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 0)
	for job: int in pendiente:
		for person: Inhabitant in sim.people:
			if pendiente[job] <= 0:
				break
			if person.priorities.size() > 0:
				continue
			if not Profession.can_do(job as Profession.Job, person):
				continue
			for task: int in Profession.tasks_of(job as Profession.Job):
				person.set_priority(task, 1)
			pendiente[job] -= 1
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()
