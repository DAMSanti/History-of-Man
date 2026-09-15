extends SceneTree
## La expedición en la escena de verdad, no en una prueba.
##
## Las pruebas de `TestExpedicion` y `TestContacto` construyen la simulación a
## mano y le pasan la comarca. Esto comprueba lo que ellas no pueden: que
## [DemoMain] le da a la simulación la comarca horneada y reparte quién vive
## dónde. Sin ese cableado todo compilaba y la expedición volvía sin descubrir
## nada, con nadie viviendo en ninguna parte.
##
## No simula jornadas: manda la expedición, adelanta el día hasta la vuelta y
## llama al cierre, que es lo que el paso fijo haría. Segundos, no un año.

const SITE_ID := 56


func _init() -> void:
	var demo := await _arrancar()
	if demo == null:
		print("no se pudo arrancar la escena")
		quit(1)
		return
	var sim: SettlementSim = demo.sim
	sim.time_scale = 0.0

	print("sale desde: %s" % (sim.expedicion.origen().display_name()
		if sim.expedicion.origen() != null else "NINGUNA PARTE"))
	print("emplazamientos con gente: %d" % sim.contacto.ocupados.size())
	print("conocidos al empezar: %d" % GameState.discovered.size())

	if sim.contacto.ocupados.is_empty():
		print("NADIE VIVE EN NINGUNA PARTE: el reparto no se ha hecho")
		quit(1)
		return

	# HACIA UN SITIO CON GENTE, por su rumbo: desde el 2026-09-14 se sale hacia un
	# rumbo y no a un sitio (SISTEMAS §4).
	var destino: int = sim.contacto.ocupados.keys()[0]
	var hacia := 0.0
	for s: Site in (load("res://data/sites/cantabria_sites.res") as SiteSet).sites:
		if s.id == destino and sim.expedicion.origen() != null:
			var desde := sim.expedicion.origen()
			hacia = rad_to_deg(atan2((s.lon - desde.lon) * cos(deg_to_rad(desde.lat)),
				s.lat - desde.lat))
	# EL ZURRÓN, puesto a mano. Desde la tanda 3 una expedición se lleva también
	# tienda y hoguera —3 pieles y 39 de leña con tres personas, ver
	# [Expedicion.hace_falta_para]— y al empezar la partida la banda no tiene ni
	# una cosa ni la otra: sin esto la sonda mide «no sale», que es justo lo que
	# no está midiendo. **Y es un hallazgo de la partida**: la primera expedición
	# no puede salir hasta que haya pieles y leña guardadas.
	sim.store.add(Materia.Kind.PIEL, 6.0)
	sim.store.add(Materia.Kind.LENA, 120.0)
	sim.store.add(Materia.Kind.CARNE_SECA, 120.0)
	var comida_antes := sim.store.food_rations()
	var salio := sim.expedicion.mandar(3, hacia)
	print("sale hacia %d: %s · raciones que se lleva: %.1f" % [
		destino, "SI" if salio else "NO", comida_antes - sim.store.food_rations()])
	if not salio:
		quit(1)
		return

	# QUE SE LES VEA IRSE (tanda 3, frente 10): la puerta del valle es una celda
	# del borde ALCANZABLE hacia el destino, y hasta llegar a ella siguen en el
	# mapa. Se les deja andar unas horas de juego y se mira si se acercan.
	var puerta := sim.expedicion.salida
	var quien: Inhabitant = null
	for person: Inhabitant in sim.people:
		if person.expedicion_andando:
			quien = person
			break
	if quien == null:
		print("NADIE VA ANDANDO: la salida no se ve")
	else:
		var borde_x: float = minf(puerta.x, float(demo.terrain.terrain_size.x) - puerta.x)
		var borde_z: float = minf(puerta.z, float(demo.terrain.terrain_size.y) - puerta.z)
		print("puerta del valle: %s · a %.0f m del borde · a %.0f m del abrigo" % [
			str(puerta), minf(borde_x, borde_z),
			sim.home_position.distance_to(puerta)])
		var lejos_antes := quien.position.distance_to(puerta)
		# Y CUÁNTO MAPA DESPEJA POR EL CAMINO: la expedición cruza el valle
		# entero, y ese camino no puede quedarse en niebla. Ver [Expedicion.andar].
		var conocido_antes := sim.knowledge.explored_fraction()
		sim.time_scale = 5.0
		# Media jornada andando, y la foto: ver [CAPTURA].
		var media := sim.day + 1
		while sim.hour < 9.0 and sim.day < media:
			await process_frame
		await _retratar(demo, sim, quien, puerta)
		var hasta := sim.day + 2
		while sim.day < hasta:
			await process_frame
		sim.time_scale = 0.0
		var lejos_ahora := quien.position.distance_to(puerta)
		print("mapa despejado: %.1f %% -> %.1f %% mientras iban de camino" % [
			conocido_antes * 100.0, sim.knowledge.explored_fraction() * 100.0])
		print("%s: a %.0f m de la puerta al salir, a %.0f m dos jornadas después %s" % [
			quien.given_name, lejos_antes, lejos_ahora,
			"(y ya está fuera)" if not quien.expedicion_andando else ""])
	var antes := GameState.discovered.size()
	sim.day = sim.expedicion.vuelve_el_dia
	sim.expedicion.nuevo_dia()
	print("vuelve · descubiertos: %d -> %d (+%d) · jornadas-persona: %d" % [
		antes, GameState.discovered.size(),
		GameState.discovered.size() - antes, sim.expedicion.jornadas_persona])
	print("contacto con %d: %s · gente conocida: %d" % [
		destino, "SI" if sim.contacto.se_conocen(destino) else "NO",
		sim.contacto.conocidos()])
	var en_la_puerta := 0
	for person: Inhabitant in sim.people:
		if person.position.distance_to(sim.expedicion.salida) < 2.0:
			en_la_puerta += 1
	print("al volver, en la puerta del valle: %d (y no en la cueva)" % en_la_puerta)
	quit()


## La foto de quien va andando hacia el borde. Sólo con CAPTURA= y con ventana.
func _retratar(demo: Node, sim: SettlementSim, quien: Inhabitant,
		puerta: Vector3) -> void:
	if OS.get_environment("CAPTURA").is_empty():
		return
	var ui: GameUI = demo.ui
	ui.visible = false
	if "camera" in demo and demo.camera != null:
		demo.camera.set_distance(70.0)
		demo.camera.orbit_angle_v = -58.0
	for i in range(40):
		await process_frame
		if "camera" in demo and demo.camera != null:
			demo.camera.set_target(quien.position)
	var shot := get_root().get_texture().get_image()
	if shot != null:
		shot.save_png("user://expedicion.png")
		print("captura en %s · %s a %.0f m de la puerta" % [
			ProjectSettings.globalize_path("user://expedicion.png"),
			quien.given_name, quien.position.distance_to(puerta)])
	ui.visible = true


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		return null
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(120):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		return null
	return demo
