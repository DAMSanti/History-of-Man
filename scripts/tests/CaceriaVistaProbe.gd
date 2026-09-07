extends SceneTree
## La cacería y las nasas, MIRADAS.
##
## `CaceriaProbe` cuenta lo que pasa; ésta enseña lo que se ve, que no es lo
## mismo y ya ha mordido dos veces en este proyecto: una capa puede estar
## sembrada, informar de miles de instancias y no dibujarse —ver el recorte de
## visibilidad que medía desde el origen del mapa—. Un cesto de mimbre nuevo y
## una chapa de estado son código de dibujo que ninguna prueba toca.
##
## Lleva la cámara a tres sitios y guarda una imagen de cada uno:
##
##   1. una nasa calada en la orilla,
##   2. un cazador en plena cacería, con su chapa encima,
##   3. la boca del abrigo, para ver que no se ha roto nada de lo de antes.
##
## Se lanza CON VENTANA:
##   godot --path . --script res://scripts/tests/CaceriaVistaProbe.gd

const SITE_ID := 56

## Jornadas que se dejan correr antes de mirar. Las suficientes para que haya
## nasas caladas y alguna cacería en marcha, y no más: cada una cuesta.
const DIAS := 14

## A cuánto se corre el reloj mientras se espera. Ver el bucle de abajo.
const PRISA := 10.0

## A qué distancia de su pieza hay que pillar al cazador para que la captura
## enseñe una cacería y no a una persona andando por el monte.
const CERCA_DE_LA_PIEZA := 60.0

## Cuántos fotogramas se espera a que eso pase antes de rendirse.
const ESPERA_MAXIMA := 40000

## A qué distancia se pone la cámara de lo que enfoca, en metros. Cerca: lo que
## hay que ver es un cesto de mimbre de un metro y una chapa sobre una cabeza.
const CAMARA_LEJOS := 24.0

## Y a qué altura la deja el ángulo orbital, en grados sobre el horizonte. Baja,
## que es como se mira una orilla: desde arriba un cesto medio hundido no se
## distingue del suelo.
const CAMARA_ANGULO := -22.0


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
	var sim: SettlementSim = demo.get("sim")
	var tech: TechTree = demo.get("tech")
	if sim == null:
		print("sin simulacion"); quit(); return

	# Las técnicas y el aparejo, dados: aquí no se mide cuánto tarda la banda en
	# aprender, se mira si lo que hace se ve.
	for t: int in [TechTree.Tech.NUCLEO, TechTree.Tech.HOJA,
			TechTree.Tech.AZAGAYA, TechTree.Tech.PESQUERA, TechTree.Tech.NASA]:
		tech.known[t as TechTree.Tech] = true
	for _n in range(6):
		sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.6)
		sim.toolkit.craft(Tool.Kind.LASCA, Tool.Stuff.CUARCITA, 0.6)
	for _n in range(4):
		sim.toolkit.craft(Tool.Kind.NASA, Tool.Stuff.FIBRA, 0.6)
	sim.store.add(Materia.Kind.CARACOL, 40.0)

	_reparto(sim)

	# Se deja correr con el motor de verdad -no a mano-, que es lo que mueve la
	# fauna, los marcadores y la interfaz a la vez, y es justo lo que aquí hay
	# que comprobar. Acelerado, porque a velocidad de partida catorce jornadas
	# son veintiocho minutos de reloj de pared; la simulación ya trocea el tick
	# para que acelerar no cambie el resultado -ver `SettlementSim._process`-.
	sim.time_scale = PRISA
	var seen := sim.day
	while sim.day - seen < DIAS:
		await process_frame
	# Y a velocidad normal para las capturas: con el reloj corriendo, entre que
	# se coloca la cámara y se dispara la banda se ha ido a otra parte.
	sim.time_scale = 1.0

	print("nasas caladas: %d · cacerias en marcha: %d"
		% [sim.nasas.size(), sim.hunts.size()])

	# La nasa y el abrigo se pueden fotografiar cuando sea; la cacería no. Hay
	# que esperar a que a alguien le pille la cámara CERCA de su pieza, que es
	# lo que se viene a mirar: a trescientos metros del ciervo, un cazador es
	# una persona andando por el monte.
	await _shoot(demo, sim, _nasa_spot(sim), "nasa")

	var hunter := await _wait_for_a_close_hunt(sim)
	await _shoot(demo, sim, hunter, "caceria")

	await _shoot(demo, sim, sim.home_forecourt, "abrigo")

	print("en %s" % ProjectSettings.globalize_path("user://"))
	quit()


## Cuatro a la caza mayor y dos a la ribera. El resto, a lo suyo.
func _reparto(sim: SettlementSim) -> void:
	var i := 0
	for person: Inhabitant in sim.people:
		if not person.can_work():
			continue
		var job := Profession.Job.CAZA
		var speciality := Profession.Speciality.CAZA_MAYOR
		if i >= 4 and i < 6:
			job = Profession.Job.RIBERA
			speciality = Profession.Speciality.ORILLA
		elif i >= 6:
			continue
		if not Profession.can_do(job, person):
			continue
		for job_key: int in Profession.CATALOGUE:
			for task: int in Profession.tasks_of(job_key as Profession.Job):
				person.set_priority(task, 0)
		person.set_priority(Profession.task_id(job, speciality), 1)
		i += 1
	sim.apply_priorities()


## Dónde hay una nasa que mirar, o el abrigo si no hay ninguna.
func _nasa_spot(sim: SettlementSim) -> Vector3:
	if sim.nasas.is_empty():
		print("AVISO: ninguna nasa calada, la captura no dice nada")
		return sim.home_forecourt
	return (sim.nasas[0] as Nasa).position


## Espera a que haya alguien pegado a su pieza y devuelve dónde está.
##
## Una cacería dura minutos de partida y la mayor parte se va en rastrear, así
## que mirar en un instante cualquiera es casi siempre mirar a nadie: la primera
## vez que se corrió esta sonda salió «ninguna caceria en marcha al mirar» con
## la caza funcionando perfectamente.
func _wait_for_a_close_hunt(sim: SettlementSim) -> Vector3:
	sim.time_scale = PRISA
	for i in range(ESPERA_MAXIMA):
		var best: Vector3 = Vector3.ZERO
		var closest := INF
		for hunt: Hunt in sim.hunts:
			for person: Inhabitant in hunt.crew:
				var distance := person.position.distance_to(hunt.where())
				if distance < closest:
					closest = distance
					best = person.position
		_mas_cerca = minf(_mas_cerca, closest)
		if best != Vector3.ZERO and closest < CERCA_DE_LA_PIEZA:
			sim.time_scale = 1.0
			print("cazador a %.0f m de su pieza, dia %d" % [closest, sim.day])
			return best
		await process_frame
	sim.time_scale = 1.0
	print("AVISO: nadie llego a tiro en la espera (lo mas cerca, %.0f m);"
		% _mas_cerca + " la captura no dice nada")
	return sim.home_forecourt


## Lo mas cerca que ha estado alguien de su pieza en toda la espera. Se imprime
## al rendirse: sin este numero, «nadie llego a tiro» no distingue entre que la
## caza no funciona y que la ventana es estrecha.
var _mas_cerca := INF


## Lleva la cámara a un punto y guarda lo que se ve.
##
## Por `set_target` y `set_distance` y no colocándola a mano: la cámara es
## ORBITAL y se recoloca sola en cada `_process` a partir de su objetivo, su
## distancia y sus ángulos, así que ponerle la posición dura un fotograma.
func _shoot(demo: Node, sim: SettlementSim, target: Vector3,
		name: String) -> void:
	var camera: OrbitalCamera = demo.get("camera")
	if camera == null:
		print("sin camara"); return
	var terrain: TerrainGenerator = sim.terrain()
	var ground := target
	if terrain != null:
		ground.y = terrain.get_height_at(ground)
	# El tope de acercamiento se BAJA antes de pedir la distancia. La cámara de
	# la partida no deja acercarse más de unos cincuenta metros —`DemoMain` le
	# pone los límites con `set_distance_limits(mundo*0,01, mundo*2)`, que en un
	# valle de cuatro kilómetros son cincuenta y siete metros de tope— y a esa
	# distancia un cesto de mimbre de un metro no se distingue del suelo. Aquí
	# no se está jugando: se está mirando una pieza concreta.
	camera.set_distance_limits(CAMARA_LEJOS * 0.5, 4000.0)
	camera.orbit_angle_v = CAMARA_ANGULO
	camera.set_target(ground)
	camera.set_distance(CAMARA_LEJOS)
	print("  camara: %.0f m sobre %s" % [camera.orbit_distance, ground])

	# A MEDIODIA. La primera captura salió a las 00:19 y era una pantalla negra
	# con dos rótulos flotando: de noche el valle no tiene más luz que el hogar
	# —y eso está bien—, pero lo que aquí hay que ver es un cesto de mimbre.
	sim.hour = 13.0

	# Varios fotogramas: el primero mueve la cámara y el terreno todavía no ha
	# subido el detalle de cerca. Fotografiar el primero da una captura borrosa
	# que no dice si la pieza está bien puesta.
	for i in range(30):
		await process_frame
	var shot := root.get_texture().get_image()
	var file := "user://caceria_%s.png" % name
	shot.save_png(file)
	print("captura %s" % file)
