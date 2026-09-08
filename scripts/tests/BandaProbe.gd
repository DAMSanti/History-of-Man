extends SceneTree
## Un año con una banda repartida a mano, y de donde sale cada racion.
##
## [AnoProbe] mide lo que hace la banda con el reparto por defecto. Esto mide un
## reparto CONCRETO y desglosa por oficio: cuanto saca cada uno, de que material
## y de que paraje.
##
## OJO CON `produced_days`: es una ventana rodante de 30 dias
## ([SettlementSim.CONSUMO_DIAS]), no el registro del año. Sumarla al final da
## el ultimo mes creyendo que es la partida entera. Aqui se acumula dia a dia,
## leyendo `produced_days.back()` -la jornada que se acaba de cerrar- cada vez
## que cambia el dia.
##
##   DIAS=360              jornadas
##   BANDA=4,3,2           recolectores, cazadores, pescadores

const SITE_ID := 56

## De que oficio viene cada comida. Lo que no este aqui es recoleccion.
const DE_QUIEN := {
	Materia.Kind.CARNE: "Caza",
	Materia.Kind.CARNE_SECA: "Caza",
	Materia.Kind.PESCADO: "Ribera",
	Materia.Kind.PESCADO_SECO: "Ribera",
	Materia.Kind.MARISCO: "Ribera",
}

var _total: Dictionary = {}          ## material -> unidades del año entero
var _por_estacion: Dictionary = {}   ## estacion -> {material -> unidades}
var _jornadas: Dictionary = {}       ## oficio -> jornadas-persona trabajadas
var _pudrido := 0.0
var _saltos := 0                     ## dias que se comieron dos de golpe


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

	var dias := 360
	if not OS.get_environment("DIAS").is_empty():
		dias = int(OS.get_environment("DIAS"))

	print("")
	print("=== %d RECOLECTORES · %d CAZADORES · %d PESCADORES, %d jornadas ===" % [
		reparto[0], reparto[1], reparto[2], dias])
	var quien: Dictionary = {}
	for person: Inhabitant in sim.people:
		var j := Profession.job_name(person.job as Profession.Job)
		quien[j] = int(quien.get(j, 0)) + 1
	print("la banda quedo asi: %s" % str(quien))
	print("")
	print("%-6s %-11s %9s %7s %8s %7s %7s" % [
		"dia", "estacion", "despensa", "dias", "cabe", "hambre", "cestos"])

	await _correr(sim, dias)
	_desglose(sim, dias)
	quit()


## Levanta la escena en el sitio 56 y devuelve su simulacion.
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


## Pone a tanta gente como se pida en cada oficio, por orden de quien pueda.
## El resto al hogar y a la cordeleria: alguien tiene que mantener el fuego.
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
	# Y el resto, LA MITAD AL TALLER. Ponerlos a todos en el hogar -que fue la
	# primera version- deja la manufactura vacia, y entonces no se trenza ni un
	# cesto ni se talla una azagaya en todo el año: los cazadores salen a mano
	# y la despensa se queda con la capacidad de arranque. Medido: 180 jornadas
	# con seis en el hogar dieron CERO cestos y 65 raciones de carne.
	var sobran := 0
	for person: Inhabitant in sim.people:
		if person.priorities.size() > 0:
			continue
		sobran += 1
		if sobran % 2 == 0:
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				Profession.Speciality.TALLA), 1)
			person.set_priority(Profession.task_id(Profession.Job.MANUFACTURA,
				Profession.Speciality.CORDELERIA), 2)
		else:
			person.set_priority(Profession.task_id(Profession.Job.HOGAR), 1)
	sim.apply_priorities()


## Sigue la partida jornada a jornada, cerrando la cuenta de cada una.
func _correr(sim: Node, dias: int) -> void:
	var primero: int = sim.day
	var ultimo: int = sim.day
	while sim.day < primero + dias:
		await process_frame
		if sim.day == ultimo:
			continue
		if sim.day > ultimo + 1:
			_saltos += sim.day - ultimo - 1
		ultimo = sim.day
		_cerrar_dia(sim)
		if (sim.day - primero) % 15 != 0:
			continue
		var hambre := 0.0
		var bocas := 0.0
		for p: Inhabitant in sim.people:
			hambre += p.hunger
			bocas += p.daily_food()
		print("%-6d %-11s %9.0f %7.1f %8.0f %7.0f %7d" % [
			sim.day, Subsistence.season_name(GameState.season),
			sim.store.food_rations(),
			sim.store.food_rations() / maxf(bocas, 0.01),
			sim.store.capacidad_comida,
			hambre / maxf(float(sim.people.size()), 1.0),
			sim.toolkit.count(Tool.Kind.CESTO)])


## Apunta la jornada que se acaba de cerrar. La ultima de `produced_days` es
## esa: `_roll_production` la mete justo antes de que cambie el dia.
func _cerrar_dia(sim: Node) -> void:
	_pudrido += sim.spoiled_rations_today
	var est := Subsistence.season_name(GameState.season)
	if not _por_estacion.has(est):
		_por_estacion[est] = {}
	if sim.taller.produced_days.size() > 0:
		var ayer: Dictionary = sim.taller.produced_days.back()
		for k: int in ayer:
			if k < 0:
				continue
			_total[k] = float(_total.get(k, 0.0)) + float(ayer[k])
			_por_estacion[est][k] = float(_por_estacion[est].get(k, 0.0)) \
				+ float(ayer[k])
	# Jornadas-persona: quien tenia el oficio ese dia, no quien lo tiene al
	# final. Sin esto, una banda que acaba ociosa divide entre cero.
	for person: Inhabitant in sim.people:
		var j := Profession.job_name(person.job as Profession.Job)
		_jornadas[j] = int(_jornadas.get(j, 0)) + 1


func _desglose(sim: Node, dias: int) -> void:
	print("")
	print("--- DE DONDE SALE CADA RACION ---")
	var por_oficio: Dictionary = {}
	var suma := 0.0
	for k: int in _total:
		var kk := k as Materia.Kind
		if not Materia.is_food(kk):
			continue
		var oficio: String = DE_QUIEN.get(kk, "Recolección")
		var r := float(_total[k]) * Materia.nutrition(kk)
		por_oficio[oficio] = float(por_oficio.get(oficio, 0.0)) + r
		suma += r
	var comidas := 0.0
	for person: Inhabitant in sim.people:
		comidas += person.daily_food()
	comidas *= float(dias)
	for oficio: String in ["Recolección", "Caza", "Ribera"]:
		var jp: int = int(_jornadas.get(oficio, 0))
		var r: float = float(por_oficio.get(oficio, 0.0))
		print("   %-14s %5d jornadas-persona · %8.0f raciones (%2.0f %%) · %6.2f al dia cada uno" % [
			oficio, jp, r, 100.0 * r / maxf(suma, 1.0),
			r / maxf(float(jp), 1.0)])
	print("   la banda se comio %.0f raciones y se pudrieron %.0f" % [comidas, _pudrido])

	print("")
	print("--- Y DE QUE MATERIAL ---")
	var orden: Array[int] = []
	orden.assign(_total.keys())
	orden.sort_custom(func(a: int, b: int) -> bool:
		return _raciones(a) > _raciones(b))
	for k: int in orden:
		var kk := k as Materia.Kind
		if not Materia.is_food(kk) or _raciones(k) < 1.0:
			continue
		print("   %-16s %8.0f raciones (%7.0f %s · aguanta %d dias)" % [
			Materia.material_name(kk), _raciones(k), _total[k],
			Materia.unit_name(kk), Materia.shelf_life(kk)])

	print("")
	print("--- POR ESTACION, EN RACIONES ---")
	for est: String in _por_estacion:
		var r := 0.0
		for k: int in _por_estacion[est]:
			var kk := k as Materia.Kind
			if Materia.is_food(kk):
				r += float(_por_estacion[est][k]) * Materia.nutrition(kk)
		print("   %-12s %8.0f" % [est, r])

	print("")
	print("--- Y CON QUE UTILLAJE SE ACABO ---")
	for kind: int in [Tool.Kind.CESTO, Tool.Kind.ODRE, Tool.Kind.AZAGAYA,
			Tool.Kind.LASCA, Tool.Kind.CUERDA]:
		print("   %-12s %d" % [Tool.kind_name(kind as Tool.Kind),
			sim.toolkit.count(kind as Tool.Kind)])

	print("")
	print("--- Y DE QUE PARAJE ---")
	for act: int in sim.work_sites:
		var punto: Vector3 = sim.work_sites[act]
		# El paraje ELEGIDO para esa actividad, no el mas cercano al tajo:
		# `parajes.at` devuelve el que pilla, y con dos tajos a doscientos
		# metros salia el mismo nombre para la pesca y para la recoleccion.
		var paraje: Paraje = sim.parajes.chosen_for(act as Subsistence.Activity)
		print("   %-16s a %5.0f m · %s" % [
			Subsistence.activity_name(act as Subsistence.Activity),
			sim.home_position.distance_to(punto),
			paraje.name_text if paraje != null else "sin elegir"])
	if _saltos > 0:
		print("")
		print("   (%d jornadas se pasaron sin contar: el cuadro fue muy largo)" % _saltos)


func _raciones(k: int) -> float:
	var kk := k as Materia.Kind
	if not Materia.is_food(kk):
		return 0.0
	return float(_total[k]) * Materia.nutrition(kk)
