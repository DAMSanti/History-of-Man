extends SceneTree
## Por que la banda entera se pasa la jornada RECONOCIENDO en vez de trabajar.
##
## La queja: «sigue pasando gran parte de la jornada corriendo por una zona de
## la vereda del rio». Medido por estados, los recolectores y los de ribera
## gastan entre el 82 % y el 97 % de las horas de luz en RECONOCIENDO y CERO en
## TRABAJANDO. Eso solo pasa si `Barbecho.sin_sitio` dice que si.
##
##   SEMILLA=7 VEL=3 DIAS=3

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	sim.time_scale = float(OS.get_environment("VEL")) if not OS.get_environment("VEL").is_empty() else 3.0
	var dias := int(OS.get_environment("DIAS")) if not OS.get_environment("DIAS").is_empty() else 3
	var primero: int = sim.day
	var visto := -1
	while sim.day < primero + dias:
		await process_frame
		if sim.day != visto and sim.hour > 8.0:
			visto = sim.day
			_retrato(sim)
	quit()


func _retrato(sim: Node) -> void:
	print("")
	print("=== jornada %d ===" % sim.day)
	print("   %-14s %8s %8s %10s %9s" % [
		"actividad", "parajes", "conocidos", "sin_sitio", "mejor stock"])
	for act: int in [Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
			Subsistence.Activity.MARISQUEO, Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.MATERIA_PRIMA]:
		var a := act as Subsistence.Activity
		var parajes := 0
		if sim.parajes != null:
			for p: Paraje in sim.parajes.list:
				if p.activity == a:
					parajes += 1
		var conocidos: Array = sim._known_spots.get(act, [])
		var mejor := 0.0
		for spot: Dictionary in conocidos:
			mejor = maxf(mejor, sim.field.stock_fraction_around(a, spot["pos"], 90.0))
		print("   %-14s %8d %8d %10s %8.0f %%" % [
			Subsistence.activity_name(a), parajes, conocidos.size(),
			"SI" if sim.barbecho.sin_sitio(a) else "no", mejor * 100.0])

	# Y la familiaridad de los parajes que el jugador SI ve en el mapa: si un
	# paraje con nombre no llega a 0.35 no entra en la lista de tajos.
	print("   --- parajes con nombre ---")
	if sim.parajes != null:
		for p: Paraje in sim.parajes.list:
			var fam := 0.0
			if sim.knowledge != null:
				fam = sim.knowledge.familiarity_at(p.activity, p.position)
			var lejos := Vector2(p.position.x - sim.home_position.x,
				p.position.z - sim.home_position.z).length()
			var rejilla: Navgrid = sim.marcha._navgrid()
			var llega := rejilla != null and rejilla.is_ready() \
				and rejilla.connected(sim.home_position, p.position)
			# Y de donde sale ese 0.24: cuanto vale el maximo de la rejilla de
			# familiaridad de ese oficio, y donde esta.
			var tope := 0.0
			var donde_tope := Vector3.ZERO
			for z in range(sim.field.height):
				for x in range(sim.field.width):
					var c: Vector3 = sim.field.cell_center(x, z)
					var f: float = sim.knowledge.familiarity_at(p.activity, c)
					if f > tope:
						tope = f
						donde_tope = c
			print("      tope de la rejilla %4.2f a %.0f m del paraje, %.0f m del abrigo" % [
				tope, donde_tope.distance_to(p.position),
				Vector2(donde_tope.x - sim.home_position.x,
					donde_tope.z - sim.home_position.z).length()])
			print("   %-24s %-12s fam %4.2f  %5.0f m  %s%s" % [
				p.name_text, Subsistence.activity_name(p.activity), fam, lejos,
				"llega" if llega else "NO LLEGA",
				"  (en barbecho)" if p.resting else ""])


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
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
		print("la escena no arranco")
		return null
	return demo
