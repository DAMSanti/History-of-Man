extends SceneTree
## Cuánto tardan de verdad en andar, y en qué se va el tiempo.
##
## Es la queja del jugador: «me extraña que un batidor tarde 7 horas en hacer
## 300 m, o en otros casos 8 horas para hacer 220 m; algo tenemos mal hecho».
##
## Hay dos formas de que eso pase y son fallos distintos:
##
##   EL CAMINO   se anda mucho más de lo que hay en línea recta —rodeos del
##               trazado, esquives de orilla, carriles—
##   EL PASO     se anda despacio: la velocidad efectiva por hora es mucho
##               menor que la nominal
##
## Aquí se miden las dos por separado, siguiendo cada salida de punta a punta.
##
##   DIAS=4   cuántas jornadas seguir

const SITE_ID := 56

## Lo que cada persona lleva andado en la salida en curso.
var _viaje: Dictionary = {}
var _partes: Array[String] = []
var _cerradas := 0
var _cortas := 0
var _instantaneas := 0
var _muestras := 0
var _suma_slope := 0.0
var _suma_tobler := 0.0
var _suma_suelo := 0.0
var _suma_carga := 0.0
var _suma_clima := 0.0
var _suma_total := 0.0


## Los factores que multiplican el paso, tal cual los calcula [Marcha].
func _muestrear(sim: Node, p: Inhabitant) -> void:
	if sim._terrain == null:
		return
	var rumbo: Vector3 = p.target - p.position
	rumbo.y = 0.0
	if rumbo.length() < 1.0:
		return
	rumbo = rumbo.normalized()
	var probe := 12.0
	var ahead: Vector3 = p.position + rumbo * probe
	var slope: float = (sim._terrain.get_height_at(ahead) - p.position.y) / probe
	var ground := Traversal.classify_ground(absf(slope),
		sim._terrain.crossing_difficulty_at(p.position),
		sim.temporada.encharcamiento() if sim.temporada != null else 0.0)
	var carga: float = clampf(p.carrying / maxf(sim.carry_capacity, 0.001), 0.0, 1.0)

	var llano: float = Traversal.travel_speed(0.0, Traversal.Ground.PASTO, 0.0)
	_muestras += 1
	_suma_slope += absf(slope)
	_suma_tobler += Traversal.hiking_speed(slope) / Traversal.hiking_speed(0.0)
	_suma_suelo += Traversal.ground_factor(ground)
	_suma_carga += Traversal.load_factor(carga)
	_suma_clima += sim.weather.pace_factor()
	_suma_total += (Traversal.travel_speed(slope, ground, carga) / llano) 		* sim.weather.pace_factor()


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sim := await _arrancar()
	if sim == null:
		quit()
		return
	_repartir(sim)
	sim.time_scale = 3.0
	if not OS.get_environment("VEL").is_empty():
		sim.time_scale = float(OS.get_environment("VEL"))

	var dias := 4
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== LO QUE CUESTA ANDAR ===")
	print("nominal: %.0f m por hora de juego (walk_speed %.0f, %.0f s por dia)" % [
		sim.walk_speed * (sim.seconds_per_day / 24.0),
		sim.walk_speed, sim.seconds_per_day])
	print("")

	var primero: int = sim.day
	var antes: Dictionary = {}
	while sim.day < primero + dias:
		await process_frame
		for p: Inhabitant in sim.people:
			var estado := int(p.state)
			var previo := int(antes.get(p.given_name, -1))
			antes[p.given_name] = estado

			if estado == int(Inhabitant.State.YENDO):
				var v: Dictionary = _viaje.get(p.given_name, {})
				if previo != estado:
					# Empieza una salida: se apunta de donde y adonde.
					v = {"desde": p.position, "hasta": p.target,
						"hora": sim.hour, "dia": sim.day, "andado": 0.0,
						"ultima": p.position, "parado": 0.0}
				else:
					_muestrear(sim, p)
					var paso: float = p.position.distance_to(
						v.get("ultima", p.position) as Vector3)
					v["andado"] = float(v.get("andado", 0.0)) + paso
					v["cuadros"] = float(v.get("cuadros", 0.0)) + 1.0
					if paso < 0.05:
						v["parado"] = float(v.get("parado", 0.0)) + 1.0
					v["ultima"] = p.position
					v["hasta"] = p.target
					if not v.has("ruta0"):
						v["ruta0"] = float(p.route.size())
				_viaje[p.given_name] = v
			elif previo == int(Inhabitant.State.YENDO):
				_cerrar(sim, p)
		if _partes.size() >= 18:
			break

	print("")
	print("--- EL RELIEVE Y LA NIEVE ---")
	print("   max_height %.0f · rango %s · abrigo a %.0f (%.2f del rango)" % [
		sim._terrain.max_height, str(sim._terrain.get_height_range()),
		sim.home_position.y,
		sim._terrain.altura_relativa(sim.home_position)])
	print("   cota de nieve de la estacion: %.2f · frena aqui: %.2f" % [
		Temporada.COTA_DE_NIEVE.get(GameState.season, 0.95),
		sim.temporada.freno_por_nieve(
			sim._terrain.altura_relativa(sim.home_position))])

	print("")
	print("--- EN QUE SE VA EL PASO (media de %d muestras andando) ---" % _muestras)
	if _muestras > 0:
		var n := float(_muestras)
		print("   pendiente en el sentido de la marcha  %.2f" % (_suma_slope / n))
		print("   factor de Tobler por esa pendiente    %.2f" % (_suma_tobler / n))
		print("   factor por el suelo que se pisa       %.2f" % (_suma_suelo / n))
		print("   factor por la carga                   %.2f" % (_suma_carga / n))
		print("   factor por el tiempo que hace         %.2f" % (_suma_clima / n))
		print("   TODO JUNTO                            %.2f" % (_suma_total / n))
	print("")
	print("salidas cerradas %d · descartadas por cortas %d · por instantaneas %d"
		% [_cerradas, _cortas, _instantaneas])
	for fila: String in _partes:
		print(fila)
	quit()


## Cierra una salida y saca la cuenta.
func _cerrar(sim: Node, p: Inhabitant) -> void:
	var v: Dictionary = _viaje.get(p.given_name, {})
	if v.is_empty():
		return
	_viaje.erase(p.given_name)
	_cerradas += 1
	var recto: float = (v["desde"] as Vector3).distance_to(v["hasta"] as Vector3)
	if recto < 60.0:
		_cortas += 1
		return
	var horas: float = sim.hour - float(v["hora"])
	if sim.day != int(v["dia"]):
		horas += 24.0 * float(sim.day - int(v["dia"]))
	if horas <= 0.01:
		_instantaneas += 1
		return
	var andado: float = float(v["andado"])
	_partes.append("%-9s %-12s recto %4.0f m · andado %5.0f m (rodeo x%.1f) · "
		% [p.given_name.substr(0, 9),
			Profession.job_name(p.job as Profession.Job), recto, andado,
			andado / maxf(recto, 1.0)]
		+ "%4.1f h · %4.0f m/h · %2.0f %% parado · ruta inicial %d · %d replan" % [
			horas, andado / horas,
			100.0 * float(v["parado"]) / maxf(float(v.get("cuadros", 1.0)), 1.0),
			int(float(v.get("ruta0", -1.0))), p.blocked_replans])


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
	for i in range(90):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo.sim


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
