extends SceneTree
## Como entra la cosecha: a chorro fino o de golpe.
##
## «La recoleccion no es un trabajo binario»: se va al paraje y se va cogiendo
## poco a poco, vaciandolo. Desde fuera no se distingue eso de un salto al
## final de la jornada, asi que se mira por dentro: cada cuarto de hora, lo
## que lleva encima quien trabaja y cuanto queda en el sitio donde esta.
##
## Lo que hay que poder contestar es si la curva SUBE o si es un escalon.
##
## Y de paso las comidas: cuantas veces al dia baja el hambre de alguien, y a
## que hora. Mirar el ESTADO no vale -se come y se sale de COMIENDO en el mismo
## tick, asi que la foto de cada cuadro no los pilla casi nunca-; lo que no
## miente es la curva del hambre.
##
##   DIAS=2

const SITE_ID := 56


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
	for i in range(90):
		await process_frame

	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var field: ResourceField = demo.field if "field" in demo else null
	if sim == null or field == null:
		print("sin simulacion o campo"); quit(); return

	sim.assign_default_jobs()
	sim.time_scale = 20.0

	var watched: Inhabitant = null
	for person: Inhabitant in sim.people:
		if person.job == Profession.Job.RECOLECCION:
			watched = person
			break
	if watched == null:
		print("nadie recolecta"); quit(); return

	var days := 2
	if not OS.get_environment("DIAS").is_empty():
		days = int(OS.get_environment("DIAS"))

	print("")
	print("=== %s, CUARTO DE HORA A CUARTO DE HORA ===" % watched.given_name)
	print("hora   estado       carga kg   del tope   queda en su celda")

	var first_day: int = sim.day
	var last_slot := -1
	var jumps := 0
	var steps := 0
	var before_kg := 0.0
	var _meals: Dictionary = {}
	var _peak_hands := 1
	var _raw_seen := 0.0
	var _raw_day := 0.0
	var _hunger_was: Dictionary = {}
	var _units_seen := 0.0
	var _units_day := 0.0
	var biggest := 0.0
	while sim.day < first_day + days:
		await process_frame
		# El hambre BAJANDO es lo que dice que se ha comido. Mirar el estado no
		# vale: se come y se sale de COMIENDO en el mismo tick, asi que la foto
		# de cada cuadro no los pilla casi nunca.
		for person: Inhabitant in sim.people:
			var was := float(_hunger_was.get(person.id, person.hunger))
			if person.hunger < was - 0.5:
				var at := int(sim.hour)
				_meals[at] = int(_meals.get(at, 0)) + 1
			_hunger_was[person.id] = person.hunger
		var out := 0
		for person: Inhabitant in sim.people:
			if person.job == Profession.Job.RECOLECCION 					or person.job == Profession.Job.CAZA 					or person.job == Profession.Job.RIBERA:
				out += 1
		_peak_hands = maxi(_peak_hands, out)
		var slot := int(sim.hour * 4.0)
		if slot == last_slot:
			continue
		last_slot = slot
		var kg := watched.load_kg()
		# Las unidades salen del libro del propio juego -`produced_today`-, que
		# no se enreda con las entregas: mi contador miraba la carga encima y
		# la carga se vacia al entregar, asi que perdia media jornada.
		# En RACIONES, no en unidades: la racion es la medida con la que se
		# calibra la cosecha -ver `SettlementSim.HARVEST_SCALE`- y una unidad
		# de miel y una de seta no valen lo mismo ni de lejos.
		# En unidades Y en raciones: si caen las dos es la produccion, y si solo
		# caen las raciones es la conversion.
		var today := 0.0
		var raw := 0.0
		for key: int in sim.produced_today:
			if key >= 0:
				raw += float(sim.produced_today[key])
				today += float(sim.produced_today[key]) 					* Materia.nutrition(key as Materia.Kind)
		if raw >= _raw_seen:
			_raw_seen = raw
		else:
			_raw_day += _raw_seen
			_raw_seen = raw
		if today >= _units_seen:
			_units_seen = today
		else:
			_units_day += _units_seen
			_units_seen = today
		var gained := kg - before_kg
		if gained > 0.0:
			steps += 1
			biggest = maxf(biggest, gained)
			if gained > 0.9 * watched.carry_limit_kg():
				jumps += 1
		before_kg = kg
		# La celda que de verdad se esta trabajando, no la media de la comarca:
		# la merma cae en la celda mas rica al alcance, y promediando noventa
		# metros alrededor esa bajada no se ve.
		var cell := field.best_cell(watched.activity, watched.position,
			SettlementSim.ALCANCE_DEL_TAJO)
		var left := field.stock_of_cell(watched.activity, cell)
		if sim.hour >= 6.0 and sim.hour <= 22.0:
			print("%05.2f  %-11s %7.2f    %5.0f %%       %5.0f %%       hambre %3.0f" % [
				sim.hour, watched.state_name(), kg,
				watched.load_fraction() * 100.0, left * 100.0, watched.hunger])

	print("")
	_units_day += _units_seen
	_raw_day += _raw_seen
	_raw_day += _raw_seen
	# Los del monte se cuentan MIENTRAS corre, no al final: si la banda entra
	# en hambre deja de trabajar, y contando al terminar el divisor sale cero.
	var hands := _peak_hands
	print("RACIONES a la despensa en %d jornadas: %.1f · %d en el monte · %.2f por persona y jornada" % [
		days, _units_day, hands,
		_units_day / maxf(float(days * hands), 1.0)])
	var mouths := 0.0
	for person: Inhabitant in sim.people:
		mouths += person.daily_food()
	print("en UNIDADES: %.1f en total · %.2f por persona y jornada" % [
		_raw_day, _raw_day / maxf(float(days * hands), 1.0)])
	print("la banda come %.1f raciones al dia · %d personas" % [
		mouths, sim.people.size()])
	print("subidas de carga: %d · la mayor %.2f kg · de tope %.1f kg" % [
		steps, biggest, watched.carry_limit_kg()])
	print("saltos de golpe -mas del 90 %% del tope de una vez-: %d" % jumps)
	print("")
	print("comidas de la banda, por hora del dia:")
	var slots: Array = _meals.keys()
	slots.sort()
	for slot: int in slots:
		print("   %02dh  %d veces baja el hambre de alguien" % [
			slot, int(_meals[slot])])
	quit()
