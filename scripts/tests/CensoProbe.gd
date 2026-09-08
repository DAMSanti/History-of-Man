extends SceneTree
## Que el censo cuente lo que hay de verdad, y que el rastro de un bicho salga.
##
## Hace falta porque la pestaña de Entidades es justo la herramienta que se usa
## para no tener que fiarse de un vistazo, así que ella misma no puede
## comprobarse a ojo. Las tres cosas que pueden salir mal y no se ven en una
## captura son:
##
##  - que un sistema no aparezca en la lista —props sin sembrar, fauna sin
##    mallas horneadas— y la ausencia se lea como «aquí no hay nada»,
##  - que una ficha apunte a un sitio donde no está la pieza, que es lo que
##    pasaba si se olvidaba sumar la posición del bloque a la transformada del
##    `MultiMesh`,
##  - que el rastro de un animal no llegue a pintarse, y no se distinga de un
##    animal que simplemente no se ha movido todavía.
##
## Se arranca la escena de verdad, se deja andar un rato y se pregunta.

const SITE_ID := 56

## Fotogramas de arranque —montar el terreno, sembrar el bosque, poblar los
## primeros bloques de props— y fotogramas de más para que la fauna ande.
const WARMUP_FRAMES := 240
const WALK_FRAMES := 2400


func _init() -> void:
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
	for i in range(WARMUP_FRAMES):
		await process_frame

	var demo := current_scene
	var census: EntityCensus = demo.census if "census" in demo else null
	if census == null:
		print("SIN CENSO: la escena no lo ha montado"); quit(); return

	var eye: Vector3 = demo.camera.target_position

	# 1. La lista. Tiene que salir cada familia, o la pestaña miente por
	#    omisión: una familia que falta se lee igual que una familia vacía.
	print("\n--- LO QUE HAY PINTADO ---")
	var families: Dictionary = {}
	var groups := census.groups()
	for group: Dictionary in groups:
		families[String(group["family"])] = true
		print("  %-10s %-22s %8d  %s" % [String(group["family"]),
			String(group["label"]), int(group["count"]),
			String(group["note"])])
	for wanted: String in ["Gente", "Fauna", "Bosque", "Recursos"]:
		if not families.has(wanted):
			print("  FALTA la familia %s" % wanted)

	# 2. Las fichas. Se pide una de cada familia y se comprueba lo único que
	#    no se puede mirar de otra forma: que el punto al que llevaría la
	#    cámara cae dentro del mapa y sobre el terreno, no en el vacío.
	print("\n--- FICHAS ---")
	var terrain: TerrainGenerator = demo.terrain
	for group: Dictionary in groups:
		var entries := census.entries(String(group["key"]), eye)
		if entries.is_empty():
			print("  %-22s SIN FICHAS" % String(group["label"]))
			continue
		var first: Dictionary = entries[0]
		var spot: Vector3 = first["pos"]
		var ground := terrain.get_height_at(spot)
		var off := absf(spot.y - ground)
		print("  %-22s %4d fichas  1a: %-18s en (%.0f, %.0f)  %s" % [
			String(group["label"]), entries.size(), String(first["title"]),
			spot.x, spot.z,
			"suelo ok" if off < 3.0 else "DESPEGADA %.1f m del suelo" % off])
		if String(first.get("id", "")).is_empty():
			print("    SIN IDENTIDAD: la ficha se perderá al repintar")

	# 3. El rastro. Se deja andar a todo el mundo y se comprueba que ha
	#    apuntado puntos: sin esto el rastro sale vacío y no se distingue de un
	#    fallo de pintado.
	#
	#    Hay que quitar la pausa a mano. La partida arranca parada a propósito
	#    -ver `SettlementSim`, «la partida arranca EN PAUSA»- y la fauna anda
	#    igual porque tiene su propio reloj, así que sin esto salía un informe
	#    que parecía sensato: los animales con rastro y la banda sin ninguno,
	#    como si el rastro de la gente estuviera roto.
	demo.sim.time_scale = 8.0
	for i in range(WALK_FRAMES):
		await process_frame

	print("\n--- RASTROS DE FAUNA ---")
	var herds: WildlifeHerds = demo.herds
	var longest := 0
	var moved := 0
	for animal: Dictionary in herds.animals():
		var trail: PackedVector3Array = animal["trail"]
		longest = maxi(longest, trail.size())
		if trail.size() > 1:
			moved += 1
	print("  %d animales, %d con rastro de más de un punto, el más largo %d"
		% [herds.animals().size(), moved, longest])
	if moved == 0:
		print("  NINGUNO HA DEJADO RASTRO: o no andan, o no se está apuntando")

	# 4. Y que el visor lo pinte de verdad. Se le pide a la interfaz que abra
	#    la ficha de un animal y se cuentan las líneas que cuelgan del visor:
	#    es lo que separa «el rastro existe» de «el rastro se ve».
	print("\n--- PINTADO ---")
	var fauna_key := ""
	for group: Dictionary in groups:
		if String(group["key"]).begins_with("fauna:"):
			fauna_key = String(group["key"])
			break
	var ui: GameUI = demo.ui
	for key: String in [fauna_key, "banda"]:
		if key.is_empty():
			continue
		# La ficha que MÁS haya andado, no la primera. Al poco de empezar la
		# partida la banda todavía no ha salido del abrigo, así que la primera
		# persona no tiene ni un tramo que pintar y el cero de abajo no diría
		# si el rastro está roto o si es que ahí no hay nada que dibujar.
		var best := 0
		var best_points := 0
		var entries := census.entries(key, eye)
		for i in range(entries.size()):
			var points := _points_in(entries[i].get("trail", Callable()))
			if points > best_points:
				best_points = points
				best = i

		var aim: Vector3 = entries[best]["pos"]
		ui.censo.show_entity(key, best)

		# La cámara tiene que haber viajado. Se mira ANTES de dejar correr los
		# fotogramas: la ficha es de algo que anda, así que si se mide después
		# el bicho ya se ha movido y la holgura tendría que ser tan grande que
		# no comprobaría nada.
		var aimed: Vector3 = demo.camera.target_position
		var miss := Vector2(aimed.x - aim.x, aimed.z - aim.z).length()
		print("  %-14s -> la cámara apunta a %.0f m de la ficha%s" % [
			key, miss, "" if miss < 1.0 else "  <-- NO HA IDO"])

		for i in range(30):
			await process_frame
		var painted := 0
		for child in demo.trail_view.get_children():
			if child is MeshInstance3D:
				painted += 1
		print("  %-14s -> %d puntos andados, %d líneas, siguiendo a %s" % [
			key, best_points, painted, demo.trail_view.following()])
		if best_points < 2:
			print("    todavía no ha andado nadie: no hay nada que pintar")
		elif painted == 0:
			print("    EL RASTRO NO SE PINTA")

	# Y que soltar la ficha apague el rastro: si no, la línea se queda
	# congelada en el terreno para siempre, sin nadie que la mantenga al día.
	ui.close_topmost()
	for i in range(10):
		await process_frame
	var leftover := 0
	for child in demo.trail_view.get_children():
		if child is MeshInstance3D:
			leftover += 1
	print("  tras cerrar la ficha quedan %d líneas%s" % [
		leftover, "" if leftover == 0 else "  <-- SE QUEDAN COLGADAS"])

	quit()


## Cuántos puntos suman todos los tramos que devuelve un rastro.
func _points_in(trail: Callable) -> int:
	if not trail.is_valid():
		return 0
	var total := 0
	for path: PackedVector3Array in (trail.call() as Array):
		total += path.size()
	return total
