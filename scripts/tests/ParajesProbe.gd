extends SceneTree
## A qué velocidad se vacían los parajes, y si se reponen.
##
## Es la pregunta que decide si el valle es un sitio o es un almacén. Un paraje
## que no baja nunca convierte la partida en «encuentra el mejor sitio y no te
## muevas»; uno que se agota en tres jornadas convierte el juego en una mudanza
## permanente. En medio está lo que se busca: que valga la pena volver, que
## haya un momento en que ya no, y que el sitio se recupere si se le deja.
##
## Lo que se mide, por paraje TRABAJADO:
##
##   - cuántas jornadas tarda en bajar al 75 %, al 50 % y al 25 %
##   - a cuánto se queda, y si se recupera cuando la banda se va
##   - cuántos parajes se abandonan por agotados y cuántos nuevos se buscan
##
## Se mira `stock_fraction_around` y no la celda del centro: quien trabaja un
## paraje no pisa siempre su celda, y mirando sólo el centro el agotamiento es
## invisible. Ver [ResourceField.stock_fraction_around].
##
##   DIAS=180              jornadas
##   BANDA=4,3,2           recolectores, cazadores, pescadores

const SITE_ID := 56

## Los escalones que se apuntan, en tanto por uno de lo que tenía intacto.
const ESCALONES := [0.75, 0.5, 0.25, 0.1]

## Cada cuántas jornadas se escribe una fila.
const CADA := 15

## Lo que sigue cada paraje trabajado: cuándo cruzó cada escalón y su mínimo.
var _fichas: Dictionary = {}

## Parajes que se han perdido por agotarse, y nuevos que han aparecido.
var _perdidos := 0
var _nuevos := 0


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sim := await _arrancar()
	if sim == null:
		quit()
		return

	var reparto := [4, 3, 2]
	if not OS.get_environment("BANDA").is_empty():
		var partes := OS.get_environment("BANDA").split(",")
		for i in range(mini(partes.size(), 3)):
			reparto[i] = int(partes[i])
	_repartir(sim, reparto)
	sim.time_scale = 25.0

	var dias := 180
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== A QUÉ VELOCIDAD SE VACÍAN LOS PARAJES (%d jornadas) ===" % dias)
	print("   repone %.3f al día, con curva logística · un paraje se pierde por"
		% 0.045)
	print("   debajo de %.2f y sólo si su material NO se repone (vetas)."
		% Parajes.EXHAUSTED)
	print("")
	print("%-6s %-11s %8s %9s %9s %9s" % [
		"dia", "estacion", "parajes", "recolec.", "caza", "pesca"])

	await _correr(sim, dias)
	_informe(sim, dias)
	quit()


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


## El mismo reparto que [BandaProbe], para poder comparar las dos corridas.
func _repartir(sim: Node, reparto: Array) -> void:
	var pendiente := {
		Profession.Job.RECOLECCION: reparto[0],
		Profession.Job.CAZA: reparto[1],
		Profession.Job.RIBERA: reparto[2],
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
	var sobran := 0
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		sobran += 1
		if sobran % 2 == 0:
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				Profession.Speciality.TALLA), 1)
		else:
			person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()


func _correr(sim: Node, dias: int) -> void:
	var primero: int = sim.day
	var ultimo: int = sim.day
	var antes: int = sim.parajes.list.size()
	while sim.day < primero + dias:
		await process_frame
		if sim.day == ultimo:
			continue
		ultimo = sim.day
		_apuntar(sim)
		var ahora: int = sim.parajes.list.size()
		if ahora > antes:
			_nuevos += ahora - antes
		elif ahora < antes:
			_perdidos += antes - ahora
		antes = ahora
		if (sim.day - primero) % CADA != 0:
			continue
		print("%-6d %-11s %8d %9s %9s %9s" % [
			sim.day, Subsistence.season_name(GameState.season),
			sim.parajes.list.size(),
			_cuanto_queda(sim, Subsistence.Activity.RECOLECCION),
			_cuanto_queda(sim, Subsistence.Activity.CAZA),
			_cuanto_queda(sim, Subsistence.Activity.PESCA)])


## Lo que queda en el paraje elegido de una actividad, como texto corto.
func _cuanto_queda(sim: Node, act: Subsistence.Activity) -> String:
	var paraje: Paraje = sim.parajes.chosen_for(act)
	if paraje == null:
		# Sin paraje elegido se mira el tajo, que es donde de verdad se trabaja.
		if not sim.work_sites.has(act):
			return "—"
		return "%.0f %%" % (100.0 * sim.field.stock_fraction_around(
			act, sim.work_sites[act], 120.0))
	return "%.0f %%" % (100.0 * sim.field.stock_fraction_around(
		act, paraje.position, paraje.extent))


## Apunta el estado de cada sitio que se está trabajando.
func _apuntar(sim: Node) -> void:
	for act: int in sim.work_sites:
		var actividad := act as Subsistence.Activity
		var punto: Vector3 = sim.work_sites[act]
		var queda: float = sim.field.stock_fraction_around(actividad, punto, 120.0)
		var clave := "%s@%.0f,%.0f" % [
			Subsistence.activity_name(actividad), punto.x, punto.z]
		if not _fichas.has(clave):
			_fichas[clave] = {
				"desde": sim.day, "min": 1.0, "ultimo": queda,
				"cruces": {}, "dias": 0,
			}
		var ficha: Dictionary = _fichas[clave]
		ficha["dias"] = int(ficha["dias"]) + 1
		ficha["ultimo"] = queda
		ficha["min"] = minf(float(ficha["min"]), queda)
		for escalon: float in ESCALONES:
			if queda <= escalon and not (ficha["cruces"] as Dictionary).has(escalon):
				(ficha["cruces"] as Dictionary)[escalon] = \
					sim.day - int(ficha["desde"])


func _informe(sim: Node, dias: int) -> void:
	print("")
	print("--- CADA SITIO TRABAJADO ---")
	print("%-26s %6s %7s %7s %7s %7s %7s %7s" % [
		"sitio", "dias", "a 75 %", "a 50 %", "a 25 %", "a 10 %", "minimo", "final"])
	for clave: String in _fichas:
		var f: Dictionary = _fichas[clave]
		var cruces: Dictionary = f["cruces"]
		print("%-26s %6d %7s %7s %7s %7s %6.0f %% %6.0f %%" % [
			clave.substr(0, 26), int(f["dias"]),
			_cruce(cruces, 0.75), _cruce(cruces, 0.5),
			_cruce(cruces, 0.25), _cruce(cruces, 0.1),
			100.0 * float(f["min"]), 100.0 * float(f["ultimo"])])

	print("")
	print("--- EL VALLE ENTERO ---")
	print("   parajes conocidos al final: %d" % sim.parajes.list.size())
	print("   perdidos por agotarse:      %d" % _perdidos)
	print("   nuevos encontrados:         %d" % _nuevos)

	# Y lo que decide si el valle aguanta: cuánto queda de media en TODAS las
	# celdas de cada actividad, no sólo donde se ha trabajado.
	print("")
	print("--- CUÁNTO QUEDA EN TODO EL VALLE, POR ACTIVIDAD ---")
	for act: int in [Subsistence.Activity.RECOLECCION, Subsistence.Activity.CAZA,
			Subsistence.Activity.PESCA, Subsistence.Activity.MARISQUEO,
			Subsistence.Activity.MATERIA_PRIMA]:
		var actividad := act as Subsistence.Activity
		print("   %-16s %5.1f %% de lo que tenía intacto" % [
			Subsistence.activity_name(actividad),
			100.0 * _media_del_valle(sim, actividad)])


func _cruce(cruces: Dictionary, escalon: float) -> String:
	if not cruces.has(escalon):
		return "—"
	return "%d d" % int(cruces[escalon])


## La media de lo que queda en todo el mapa de una actividad.
func _media_del_valle(sim: Node, act: Subsistence.Activity) -> float:
	var campo: ResourceField = sim.field
	if campo == null or not campo.capacities.has(act):
		return 1.0
	var grid: PackedFloat32Array = campo.grids[act]
	var cap: PackedFloat32Array = campo.capacities[act]
	var suma := 0.0
	var cuantas := 0
	for i in range(mini(grid.size(), cap.size())):
		if cap[i] <= 0.001:
			continue
		suma += grid[i] / cap[i]
		cuantas += 1
	return suma / maxf(float(cuantas), 1.0)
