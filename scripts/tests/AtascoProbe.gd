extends SceneTree
## De donde salen los atascos: se cuenta cada tick lo que hace cada persona.
##
## Es la queja del jugador con numeros delante: 919 atascos en una partida, 591
## «por ahi no se pasa» y 328 «no avanza por el camino trazado», y en los
## rastros un ovillo de lineas pegado al rio.
##
## Aqui no se arregla nada: se MIDE, y se miden las cuatro cosas que pueden
## estar produciendo eso, para saber cual es y poder comprobar despues que se
## ha ido.
##
##   ANDAR SIN CAMINO   frames en los que alguien camina hacia su destino con
##                      la ruta vacia: eso es tirar en linea recta, y es como
##                      se acaba en la orilla de un rio que no se cruza.
##   TRAMO POR EL AGUA  tramos de ruta que cruzan una celda de agua SIN ir por
##                      su linea de vado -la fila o columna de en medio-. La
##                      rejilla abrio esa celda por el vado; el que anda no va
##                      por el.
##   BARRER LA ORILLA   frames en los que se anda mucho y no se avanza nada
##                      hacia el destino.
##   ATASCOS            el recuento del propio juego, por motivo.
##
##   DIAS=8   cuantas jornadas seguir

const SITE_ID := 56

var _sin_camino := 0
var _frames_andando := 0
var _agua_oblicua := 0
var _tramos_mirados := 0
var _barrido := 0
var _celdas_barridas: Dictionary = {}
var _historia: Dictionary = {}
var _andado: Dictionary = {}
var _desconectado := 0
var _parado := 0
var _parado_sin_camino := 0


func _init() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sim := await _arrancar()
	if sim == null:
		quit()
		return
	_repartir(sim)
	sim.time_scale = 20.0

	var dias := 8
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== DE DONDE SALEN LOS ATASCOS, %d JORNADAS ===" % dias)

	var primero: int = sim.day
	var previo: Dictionary = {}
	while sim.day < primero + dias:
		await process_frame
		var grid: Navgrid = sim.marcha._navgrid()
		if grid == null or not grid.is_ready():
			continue
		for p: Inhabitant in sim.people:
			var andando: bool = int(p.state) == int(Inhabitant.State.YENDO)
			andando = andando or int(p.state) == int(Inhabitant.State.VOLVIENDO)
			andando = andando or int(p.state) == int(Inhabitant.State.RECONOCIENDO)
			var antes: Vector3 = previo.get(p.given_name, p.position)
			previo[p.given_name] = p.position
			if not andando:
				_historia.erase(p.given_name)
				continue

			_frames_andando += 1
			var falta: float = p.position.distance_to(p.target)
			var paso: float = p.position.distance_to(antes)

			# LO QUE SE ANDA, no lo que se pretende.
			#
			# Esto miraba el hito al que se APUNTA, y mientras el andador tiraba
			# en linea recta al quedarse sin ruta las dos cosas eran la misma.
			# Ya no: quien no tiene camino se queda quieto, y medirle la recta
			# hasta su destino cuenta como agua cruzada un tramo que nadie ha
			# andado. Se mide EL PASO DADO, de donde estaba a donde esta.
			if paso < 0.05:
				_parado += 1
				if p.route.size() - p.route_step <= 0:
					_parado_sin_camino += 1
			else:
				if p.route.size() - p.route_step <= 0 and falta > 40.0:
					_sin_camino += 1
					if not grid.connected(p.position, p.target):
						_desconectado += 1
				_mirar_tramo(grid, antes, p.position)

			# Barrer la orilla: mucho andado, nada de acercarse.
			_andado[p.given_name] = float(_andado.get(p.given_name, 0.0)) + paso
			var h: Array = _historia.get(p.given_name, [])
			h.append(falta)
			if h.size() > 120:
				h.remove_at(0)
			_historia[p.given_name] = h
			if h.size() >= 120:
				var mejor: float = h[0]
				for v: float in h:
					mejor = minf(mejor, v)
				if float(h[0]) - mejor < 15.0 and paso > 0.5:
					_barrido += 1
					var celda: int = grid.cell_of(p.position)
					_celdas_barridas[celda] = int(_celdas_barridas.get(celda, 0)) + 1

	print("")
	print("--- ATASCOS QUE CUENTA EL JUEGO ---")
	var total := 0
	for causa: String in sim.stuck_tally:
		total += int(sim.stuck_tally[causa])
	print("   TOTAL %d en %d jornadas" % [total, dias])
	for causa: String in sim.stuck_tally:
		print("   %-38s %d" % [causa, int(sim.stuck_tally[causa])])

	print("")
	print("--- QUIETO EN ESTADO DE ANDAR ---")
	print("   %d de %d frames sin dar un paso (%.1f %%); sin ruta: %d" % [
		_parado, _frames_andando,
		100.0 * float(_parado) / maxf(float(_frames_andando), 1.0),
		_parado_sin_camino])

	print("")
	print("--- LO QUE CUENTA EL PROPIO ANDADOR ---")
	print("   Las dos cifras que dicen la verdad, contadas al dar el paso y no")
	print("   deducidas desde fuera. Las dos tienen que quedarse en casi cero.")
	print("   pasos SIN CAMINO debajo (tiro en linea recta) %d" %
		int(sim.marcha.pasos_sin_camino))
	print("   pasos CORTADOS por el terreno con camino    %d" %
		int(sim.marcha.pasos_cortados))
	print("   caminos que NO merecian andarse             %d de %d" % [
		int(sim.marcha.rodeos_malos), int(sim.marcha.rodeos_mirados)])
	print("      de esos, por celda cerrada %d · por agua %d" % [
		int(sim.marcha.pasos_cortados_celda),
		int(sim.marcha.pasos_cortados_agua)])

	# LO QUE LAS VEREDAS TIENEN QUE AHORRAR. Es la otra mitad del frente 1 de
	# EPOCA_01 §10.1 -«en vez de buscarse de cero»- y se mide aparte del rodeo.
	# Por jornada, para que se pueda comparar entre corridas de largo distinto.
	var jornadas := maxi(dias, 1)
	print("   busquedas COMPLETAS de camino               %d · %.1f por jornada" % [
		Wayfinder.busquedas, float(Wayfinder.busquedas) / float(jornadas)])
	print("   caminos entregados sin buscar               %d" % [
		int(sim.marcha.rodeos_mirados) - Wayfinder.busquedas])

	print("")
	print("--- VISTO DESDE FUERA, PARA COMPARAR ---")
	print("   frames con paso y sin ruta viva: %d de %d" % [
		_sin_camino, _frames_andando])
	print("   pasos por celda de agua fuera de su linea: %d de %d" % [
		_agua_oblicua, _tramos_mirados])

	print("")
	print("--- BARRER LA ORILLA (andar sin acercarse) ---")
	print("   %d de %d frames andando (%.1f %%)" % [_barrido, _frames_andando,
		100.0 * float(_barrido) / maxf(float(_frames_andando), 1.0)])
	var peores: Array = _celdas_barridas.keys()
	peores.sort_custom(func(a: int, b: int) -> bool:
		return int(_celdas_barridas[a]) > int(_celdas_barridas[b]))
	for i in range(mini(6, peores.size())):
		var c: int = peores[i]
		var punto: Vector3 = grid_de(sim).point_of(c)
		print("      celda %5d (%4.0f,%4.0f) %4d frames · agua %d · coste %.1f" % [
			c, punto.x, punto.z, int(_celdas_barridas[c]),
			int(grid_de(sim).vado[c]), grid_de(sim).cost[c]])

	print("")
	print("--- CUANTO SE ANDA DE MAS ---")
	for p2: Inhabitant in sim.people:
		if p2.journeys.is_empty():
			continue
		var km := 0.0
		for trip: Dictionary in p2.journeys:
			km += float(trip.get("metres", 0.0))
		print("   %-9s %-13s %2d salidas · %5.2f km · %5.0f m por salida" % [
			p2.given_name.substr(0, 9),
			Profession.job_name(p2.job as Profession.Job),
			p2.journeys.size(), km / 1000.0,
			km / maxf(float(p2.journeys.size()), 1.0)])

	print("")
	print("--- LO QUE SE HA DESCUBIERTO ---")
	var con_dudas := 0
	for pj: Paraje in sim.parajes.list:
		if pj.has_unknowns():
			con_dudas += 1
	print("   %d parajes con nombre · %d con «???» · cola pendiente %d" % [
		sim.parajes.list.size(), con_dudas, sim.parajes.cola.size()])

	print("")
	print("--- EL PARTE FORENSE ---")
	print(sim.marcha.stuck_report_text())
	quit()


func grid_de(sim: Node) -> Navgrid:
	return sim.marcha._navgrid()


## Si el tramo recto de aqui al hito cruza una celda de agua por fuera de su
## linea de vado. Ver [Navgrid.vado] y [Navgrid._vado_de_verdad].
func _mirar_tramo(grid: Navgrid, desde: Vector3, hasta: Vector3) -> void:
	var largo := Vector2(hasta.x - desde.x, hasta.z - desde.z).length()
	if largo < 0.05:
		return
	_tramos_mirados += 1
	var catas := maxi(int(ceil(largo / 3.0)), 2)
	for i in range(catas + 1):
		var punto := desde.lerp(hasta, float(i) / float(catas))
		var celda := grid.cell_of(punto)
		if celda < 0 or celda >= grid.vado.size():
			continue
		if grid.vado[celda] == 0:
			continue
		# Es agua. Se mira si el punto va por la linea de vado: la fila o la
		# columna de en medio de la celda, con metro y medio de margen.
		var centro := grid.point_of(celda)
		var dx: float = absf(punto.x - centro.x)
		var dz: float = absf(punto.z - centro.z)
		if minf(dx, dz) > 1.5:
			_agua_oblicua += 1
			return


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


## El mismo reparto que usa PasoProbe, con exploracion de sobra: los atascos
## que se buscan son de batida y de expedicion.
func _repartir(sim: Node) -> void:
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
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()
