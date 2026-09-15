extends SceneTree
## Lo que vale que las veredas duren el año: SISTEMAS §18.
##
## **La pregunta es de estaciones, no de jornadas.** Dentro de una estación la
## memoria de veredas funciona igual antes y después del cambio del 2026-09-14: lo
## que cambia es qué queda **cuando la estación vuelve**. Así que la sonda no corre
## un año: corre unas jornadas, **cambia la rejilla a mano** —lo mismo que hace el
## reloj al entrar la estación— y vuelve a la de antes, y cuenta las búsquedas
## completas de camino en cada tramo.
##
## Dos pasadas, y la comparación es entre ellas:
##
##   OLVIDO=0   como ahora: la vereda de primavera duerme el invierno y vuelve
##   OLVIDO=1   como antes: al cambiar de rejilla se tiran todas
##
##   DIAS=4 OLVIDO=0 godot --headless --path . --script res://scripts/tests/VeredasProbe.gd
##
## `Wayfinder.busquedas` cuenta las búsquedas completas, que es lo que la memoria
## ahorra (§18: el 39 % medido en su día).

const SITE_ID := 56


func _init() -> void:
	Engine.max_fps = 0
	var olvido := OS.get_environment("OLVIDO") == "1"
	var dias := 4
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var sim := await _arrancar()
	if sim == null:
		quit(1)
		return
	_repartir(sim)
	sim.time_scale = 20.0
	print("")
	print("=== LAS VEREDAS, AL VOLVER LA ESTACIÓN (%d jornadas por tramo, olvido %s) ==="
		% [dias, "sí" if olvido else "no"])

	var primavera := await _tramo(sim, dias, "primavera, aprendiendo")
	_cambiar_de_estacion(sim, Subsistence.Season.INVIERNO, olvido)
	var invierno := await _tramo(sim, dias, "invierno, otra rejilla")
	_cambiar_de_estacion(sim, Subsistence.Season.PRIMAVERA, olvido)
	var vuelta := await _tramo(sim, dias, "vuelve la primavera")

	print("")
	print("%-26s %10s %10s" % ["tramo", "busq/jorn", "veredas"])
	for tramo: Dictionary in [primavera, invierno, vuelta]:
		print("%-26s %10.1f %10d" % [tramo["nombre"], float(tramo["busquedas"]) / float(dias),
			int(tramo["veredas"])])
	var ahorro := 100.0 * (1.0 - float(vuelta["busquedas"]) / maxf(float(primavera["busquedas"]), 1.0))
	print("al volver la primavera se buscan un %.0f %% menos que la primera vez." % ahorro)
	quit()


## El mismo reparto que `AtascoProbe`: sin gente andando no hay caminos que
## buscar, y la sonda medía ceros.
func _repartir(sim: SettlementSim) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 3,
		Profession.Job.CAZA: 3,
		Profession.Job.RIBERA: 2,
		Profession.Job.EXPLORACION: 4,
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
	sim.apply_priorities()


## Unas jornadas, contando lo que interesa.
func _tramo(sim: SettlementSim, dias: int, nombre: String) -> Dictionary:
	var busquedas_antes := Wayfinder.busquedas
	var hasta: int = sim.day + dias
	while sim.day < hasta:
		await process_frame
	return {"nombre": nombre, "busquedas": Wayfinder.busquedas - busquedas_antes,
		"veredas": sim.knowledge.veredas_recordadas()}


## Lo que hace el reloj al entrar una estación: otra rejilla. Con `olvido`, además
## se tiran las veredas, que es lo que se hacía hasta el 2026-09-14.
func _cambiar_de_estacion(sim: SettlementSim, estacion: Subsistence.Season, olvido: bool) -> void:
	GameState.season = estacion
	sim._estacion = estacion
	sim.horno.encargar(sim._terrain, sim.has_boat, sim.pasarelas.celdas(),
		estacion, Temporada.CAUDAL, Temporada.ENCHARCA, sim.pasarelas.version)
	# Amasar hasta que esté: en el juego lo hace el horno repartido en fotogramas.
	for _i in range(20000):
		if sim.horno.amasar():
			break
	sim._grid = sim.horno.de(estacion)
	if olvido and sim.knowledge != null:
		sim.knowledge.olvidar_veredas()
	sim.marcha.forget_routes()


func _arrancar() -> SettlementSim:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if local == null or site == null:
		print("faltan los datos de relieve")
		return null
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
	for i in range(600):
		await process_frame
		if current_scene != null and current_scene.get("ui") != null:
			break
	var demo := current_scene
	if demo == null or demo.get("sim") == null:
		print("la escena no arrancó")
		return null
	demo.ui.barra.contestar_todo(func(_m: Moment) -> int: return 0)
	return demo.sim
