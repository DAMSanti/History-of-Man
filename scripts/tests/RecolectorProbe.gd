extends SceneTree
## Adónde sale el recolector, y qué tenía más cerca.
##
## La queja: «los recolectores deben tener un objetivo desde el principio y no
## volverse locos alejándose del asentamiento... no tiene sentido alejarse
## 2000 m si hay parajes sin descubrir a 500 m».
##
## Aquí se apunta, en cada salida de trabajo: a cuánto se fue, a cuánto estaba
## el paraje de su oficio más cercano con «???», y a cuánto el más cercano con
## material suyo YA descubierto. Con esas tres cifras se ve de un vistazo si la
## salida tenía sentido o si había algo mejor a la puerta de casa.
##
##   SEMILLA=7 VEL=6 DIAS=10

const SITE_ID := 56

## Una salida apuntada: quién, adónde, y qué tenía más cerca.
var _salidas: Array[Dictionary] = []
var _antes: Dictionary = {}


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var demo := await _arrancar()
	if demo == null:
		quit()
		return
	var sim: Node = demo.sim
	_repartir(sim)
	sim.time_scale = 6.0
	if not OS.get_environment("VEL").is_empty():
		sim.time_scale = float(OS.get_environment("VEL"))

	var dias := 10
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))
	var primero: int = sim.day
	while sim.day < primero + dias:
		await process_frame
		for p: Inhabitant in sim.people:
			var estado := int(p.state)
			if estado == int(_antes.get(p.id, -1)):
				continue
			_antes[p.id] = estado
			# Sólo al ARRANCAR la salida: el destino de ese momento es el que
			# se eligió, y lo que hay más cerca es lo que se sabía entonces.
			# Solo los oficios de recoger. La caza va donde esta la pieza -a
			# una res abierta, a una trampa cebada- y medirla contra «el
			# paraje mas cercano» diria que se va lejos cuando esta haciendo
			# justo lo suyo.
			if estado != int(Inhabitant.State.YENDO):
				continue
			if p.job != Profession.Job.RECOLECCION and p.job != Profession.Job.RIBERA:
				continue
			_apuntar(sim, p)

	print("")
	print("--- CADA SALIDA, CONTRA LO QUE TENIA MAS CERCA ---")
	print("   %-9s %-13s %8s %10s %11s %s" % [
		"quien", "oficio", "se fue a", "??? a", "sabido a", "veredicto"])
	var lejos_de_mas := 0
	for s: Dictionary in _salidas:
		var fue := float(s["fue"])
		var incognita := float(s["incognita"])
		var sabido := float(s["sabido"])
		# «Se fue más lejos de lo necesario» = había un paraje suyo, con
		# material por descubrir o ya descubierto, a menos de la mitad.
		var cerca := minf(incognita, sabido)
		var mal := cerca < INF and fue > cerca * 1.5 + 100.0
		if mal:
			lejos_de_mas += 1
		print("   %-9s %-13s %6.0f m %8s %9s %s" % [
			s["quien"], s["oficio"], fue,
			"-" if incognita == INF else "%.0f m" % incognita,
			"-" if sabido == INF else "%.0f m" % sabido,
			("LEJOS DE MAS · tenia %s" % s["cual"]) if mal else "ok"])
	print("")
	print("salidas apuntadas %d · lejos de mas %d (%.0f %%)" % [
		_salidas.size(), lejos_de_mas,
		100.0 * float(lejos_de_mas) / maxf(float(_salidas.size()), 1.0)])

	print("")
	print("--- LOS PARAJES, POR CERCANIA ---")
	var lista: Array[Paraje] = []
	for paraje: Paraje in sim.parajes.list:
		lista.append(paraje)
	lista.sort_custom(func(a: Paraje, b: Paraje) -> bool:
		return a.distance_from(sim.home_position) < b.distance_from(sim.home_position))
	for paraje: Paraje in lista:
		print("   %-26s %-14s a %4.0f m · sabido %3.0f %%" % [
			paraje.name_text, Subsistence.activity_name(paraje.activity),
			paraje.distance_from(sim.home_position),
			paraje.known_fraction() * 100.0])
	quit()


func _apuntar(sim: Node, p: Inhabitant) -> void:
	var incognita := INF
	var sabido := INF
	for paraje: Paraje in sim.parajes.list:
		if paraje.activity != p.activity:
			continue
		var lejos: float = paraje.distance_from(sim.home_position)
		if paraje.has_unknowns():
			incognita = minf(incognita, lejos)
		if paraje.known_fraction() > 0.0 and not paraje.resting:
			sabido = minf(sabido, lejos)
	_salidas.append({
		"quien": p.given_name.substr(0, 9),
		"oficio": Profession.job_name(p.job as Profession.Job),
		"fue": Traversal.en_llano(sim.home_position, p.target),
		"cual": _mas_cerca(sim, p),
		"incognita": incognita,
		"sabido": sabido,
	})


## Como se llama el paraje suyo mas cercano que le sirve.
func _mas_cerca(sim: Node, p: Inhabitant) -> String:
	var best: Paraje = null
	var best_lejos := INF
	for paraje: Paraje in sim.parajes.list:
		if paraje.activity != p.activity or paraje.resting:
			continue
		var lejos: float = paraje.distance_from(sim.home_position)
		if lejos < best_lejos:
			best_lejos = lejos
			best = paraje
	return "-" if best == null else best.name_text


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


func _repartir(sim: Node) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: 4,
		Profession.Job.CAZA: 3,
		Profession.Job.RIBERA: 2,
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
