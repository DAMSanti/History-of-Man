extends SceneTree
## Que hay de verdad en cada paraje, y donde cae.
##
## «No encontraremos corteza en un paraje en el agua». `Paraje.fill_contents`
## recorre las CINCO actividades y mete lo que pase el umbral de cada una, sin
## mirar el suelo que hay debajo: si una celda del cauce llega al umbral de
## recoleccion, ese paraje del rio sale con corteza, bellota y yesca.
##
## Aqui se listan los parajes con el terreno REAL debajo -vadeo y pendiente- y
## lo que dicen tener, y se cuentan los desajustes: material de tierra en sitio
## de agua y al reves.

const SITE_ID := 56

## Los que solo salen fuera del agua.
const DE_TIERRA := [Materia.Kind.CORTEZA, Materia.Kind.BELLOTA,
	Materia.Kind.FRUTO_SECO, Materia.Kind.RAIZ, Materia.Kind.SETA,
	Materia.Kind.MIEL, Materia.Kind.BAYA, Materia.Kind.LENA, Materia.Kind.YESCA,
	Materia.Kind.RESINA, Materia.Kind.ASTA, Materia.Kind.OCRE]

## Los que solo salen del agua o de su orilla.
const DE_AGUA := [Materia.Kind.PESCADO, Materia.Kind.MARISCO,
	Materia.Kind.CONCHA]


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
	var terrain: TerrainGenerator = demo.terrain if "terrain" in demo else null
	var field: ResourceField = demo.field if "field" in demo else null
	if sim == null or terrain == null or field == null:
		print("sin simulacion, terreno o campo"); quit(); return

	sim.assign_default_jobs()
	# Se bautizan todos los parajes que el mapa daria, sin esperar a que la
	# banda los descubra: lo que se viene a mirar es el CATALOGO, no el ritmo
	# de exploracion.
	var born := 0
	for z in range(field.height):
		for x in range(field.width):
			var centre := field.cell_center(x, z)
			for activity: int in [Subsistence.Activity.RECOLECCION,
					Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
					Subsistence.Activity.MARISQUEO,
					Subsistence.Activity.MATERIA_PRIMA]:
				var act := activity as Subsistence.Activity
				if field.abundance_cell(act, x, z) < Parajes.threshold_for(act):
					continue
				# La misma puerta que usa `Parajes.birth`: en el cauce no se
				# bautizan avellanares. Sin esto la sonda cuenta parajes que
				# el juego ya no abre.
				if not Parajes.activity_fits(act,
						terrain.crossing_difficulty_at(centre)):
					continue
				var kind := Parajes._kind_for(act, centre, GameState.season)
				var paraje := Paraje.create(x, z, act, kind, centre, 1)
				paraje.ford = terrain.crossing_difficulty_at(centre)
				paraje.fill_contents(field, GameState.season)
				born += 1
				_judge(paraje, terrain)
				break

	print("")
	print("=== %d PARAJES DEL MAPA ===" % born)
	print("en el agua o su orilla: %d · en tierra: %d" % [_wet, _dry])
	print("")
	print("DESAJUSTES")
	print("  material de tierra en paraje de agua: %d parajes, %d entradas"
		% [_wet_with_land, _wet_land_entries])
	print("  material de agua en paraje de tierra: %d parajes, %d entradas"
		% [_dry_with_water, _dry_water_entries])
	# Y la FORMA: cuanto se aleja del agua la mancha de un pescador, y cuanta
	# agua se traga la de un recolector. Se mide sobre la huella de verdad, la
	# que se dibuja, no sobre el radio.
	var markers := ParajeMarkers.new()
	demo.add_child(markers)
	print("")
	print("=== LA FORMA DE LAS MANCHAS ===")
	for row: Array in [["pesca", Subsistence.Activity.PESCA],
			["recoleccion", Subsistence.Activity.RECOLECCION]]:
		var act := int(row[1]) as Subsistence.Activity
		var looked := 0
		var tiles := 0.0
		var worst_dry := 0.0
		var wet_share := 0.0
		for z in range(field.height):
			for x in range(field.width):
				if looked >= 12:
					break
				var centre := field.cell_center(x, z)
				if field.abundance_cell(act, x, z) < Parajes.threshold_for(act):
					continue
				if not Parajes.activity_fits(act,
						terrain.crossing_difficulty_at(centre)):
					continue
				var paraje := Paraje.create(x, z, act,
					Parajes._kind_for(act, centre, GameState.season), centre, 1)
				paraje.ford = terrain.crossing_difficulty_at(centre)
				var shape := markers._footprint(paraje, terrain, field)
				if shape.is_empty():
					continue
				looked += 1
				tiles += float(shape.size()) / 6.0
				var wet := 0
				for corner: Vector3 in shape:
					var f := terrain.crossing_difficulty_at(corner)
					if f > Parajes.SUELO_SECO:
						wet += 1
						continue
					# Lo que importa de un trozo seco de una pesquera no es lo
					# lejos que este del centro sino DEL AGUA: veinte metros de
					# orilla son la orilla, cien son una ladera.
					# Un maximo lo dispara un solo trozo. Lo que decide es
					# CUANTOS trozos secos estan lejos del agua: unos pocos son
					# el relleno de huecos, la mayoria seria una ladera.
					if _reach_to_water(corner, terrain) > 40.0:
						worst_dry += 1.0
				wet_share += float(wet) / maxf(float(shape.size()), 1.0)
			if looked >= 12:
				break
		if looked == 0:
			continue
		print("%-12s %d manchas · %5.0f trozos de media · %3.0f %% mojada · %3.0f %% de lo seco a mas de 40 m del agua" % [
			String(row[0]), looked, tiles / float(looked),
			100.0 * wet_share / float(looked),
			100.0 * worst_dry / maxf(tiles * 6.0, 1.0)])
	markers.queue_free()

	print("")
	print("los que mas mienten:")
	_worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["fallos"]) > int(b["fallos"]))
	for i in range(mini(10, _worst.size())):
		var row: Dictionary = _worst[i]
		print("  %-34s vado %.2f · %s" % [
			String(row["nombre"]), float(row["vado"]), String(row["mal"])])
	quit()


## A que distancia hay agua desde aqui, mirando en anillos. -1 si no hay
## ninguna cerca.
func _reach_to_water(point: Vector3, terrain: TerrainGenerator) -> float:
	for reach: float in [12.0, 25.0, 40.0, 60.0, 90.0, 130.0]:
		for spoke in range(8):
			var angle := TAU * float(spoke) / 8.0
			var at := point + Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
			if terrain.crossing_difficulty_at(at) > Parajes.SUELO_SECO:
				return reach
	return 999.0


var _wet := 0
var _dry := 0
var _wet_with_land := 0
var _dry_with_water := 0
var _wet_land_entries := 0
var _dry_water_entries := 0
var _worst: Array[Dictionary] = []


## Juzga un paraje contra el suelo que tiene debajo.
func _judge(paraje: Paraje, terrain: TerrainGenerator) -> void:
	var ford := terrain.crossing_difficulty_at(paraje.position)
	var wet := ford > 0.15
	if wet:
		_wet += 1
	else:
		_dry += 1

	var wrong: Array[String] = []
	for kind: int in paraje.contents:
		var k := kind as Materia.Kind
		if wet and DE_TIERRA.has(k):
			wrong.append(Materia.material_name(k).to_lower())
			_wet_land_entries += 1
		elif not wet and DE_AGUA.has(k):
			wrong.append(Materia.material_name(k).to_lower())
			_dry_water_entries += 1
	if wrong.is_empty():
		return
	if wet:
		_wet_with_land += 1
	else:
		_dry_with_water += 1
	_worst.append({"nombre": paraje.name_text, "vado": ford,
		"fallos": wrong.size(), "mal": ", ".join(wrong)})
