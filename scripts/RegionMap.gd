extends Node3D
## Capa regional: Cantabria entera como tablero de gestion.
##
## Es la mitad estrategica de la arquitectura de dos escalas. Aqui no se
## simulan edificios ni recursos por celda: se ven emplazamientos, rutas y
## relieve. El city builder vive en la capa local, que se genera bajo demanda
## a partir del emplazamiento que elija el jugador.
##
## La diferencia clave con DemoMain es la ESCALA DE MUNDO. Cantabria son 171 km
## de lado; a 1 unidad = 1 metro daria un mundo de 171.000 unidades, con
## problemas de precision de coma flotante y un plano lejano imposible. Aqui
## una unidad son 100 m.

@export_group("Escala")
## Metros reales por unidad de mundo
@export var meters_per_unit: float = 100.0

## Exageracion vertical del relieve. Cantabria llega a 2600 m sobre 171 km:
## a escala real seria practicamente plana.
@export_range(0.5, 6.0, 0.1) var vertical_exaggeration: float = 2.5

## Vertices por lado de la malla regional
@export var resolution: int = 1025

@export_group("Datos")
@export var heightmap_path: String = "res://data/dem/cantabria_region.res"

@export_group("Frontera")
@export var boundary_path: String = "res://data/boundaries/cantabria.json"
@export var eras_path: String = "res://data/sites/cantabria_eras.res"

## Usar el MDT del IGN (5 m, LiDAR) para el mapa local en vez del relieve
## global. Tarda mas en descargar pero es el mayor salto de calidad disponible,
## y no cuesta un solo frame: la malla tiene los mismos vertices.
@export var use_ign_elevation: bool = true

## Borrar del relieve carreteras, pistas, vias de tren y canteras usando la
## geometria de OpenStreetMap.
##
## El MDT del IGN es LiDAR: si hay una carretera de pueblo, esta TALLADA en la
## malla con su desmonte y su terraplen. En un mapa que empieza en el
## Paleolitico eso es un anacronismo, asi que se recorta y se reconstruye la
## ladera de debajo. Ver [TerrainInpainter].
@export var remove_human_works: bool = true

## Gotas de erosion hidraulica sobre el recuadro local, y pasadas de erosion
## termica despues. A cero se desactiva.
##
## 250.000 gotas sobre 900x900 celdas son unas 0,3 por celda, que suena poco
## pero cada una recorre hasta 64 pasos: da del orden de 20 visitas por celda.
## Se paga UNA vez, al bakear el emplazamiento.
## APAGADA. Las carcavas que producia se leian como carreteras y terrazas
## cortando la ladera: sobre un MDT que ya es dato medido, la erosion no
## anadia relieve creible sino cicatrices que competian con el relieve real.
## El codigo y sus pruebas se quedan -[Erosion]- por si mas adelante interesa
## para terreno generado, que es donde de verdad hace falta.
@export var erosion_drops: int = 0
@export var erosion_thermal_passes: int = 8

## Paso de la rejilla que se guarda para el contorno, en metros. El dato baja
## del IGN a 5 m como el mapa jugable; esto es solo cuanto se conserva.
##
## Estuvo en 15 m con este argumento: la malla del contorno muestreaba cada
## 32 m, asi que guardar mas fino era detalle que no se llegaba a dibujar. El
## argumento era bueno y la conclusion se quedo vieja en cuanto la malla subio
## a 513 vertices -8 m por vertice-: ahora el que limita es el DATO, y el
## contorno se veia de plastilina al lado del recuadro.
##
## A 8 m son 1.500x1.500 muestras para los 12 km de lado. Es un fichero bastante
## mas gordo y una descarga mas larga al fundar, y se paga una sola vez.
##
## No baja a 5 m porque con 8 m por vertice de malla no habria donde meterlo:
## serian 2.400x2.400 -casi seis millones de cotas- solo para interpolar.
@export var surround_meters: float = 8.0

## Sello del proceso que genera el recuadro local. SUBIRLO cuando cambie algo
## que afecte al relieve guardado -la fuente de cotas, el borrado de obra
## humana, el umbral de cauce- para que los ficheros ya bakeados se rehagan
## solos en vez de quedarse viejos sin avisar.
const LOCAL_PIPELINE_VERSION := 9
@export var border_color: Color = Color(1.0, 0.82, 0.25)
## Ancho de la cinta de frontera, en metros reales
@export var border_width_m: float = 400.0
## Cuanto se levanta sobre el terreno para que no se entierre en las laderas
@export var border_lift_m: float = 80.0

@export_group("Emplazamientos")
@export var sites_path: String = "res://data/sites/cantabria_sites.res"
## Tamano del marcador en metros reales
@export var marker_size_m: float = 900.0
@export var show_sites: bool = true

## Emplazamientos de prueba, para mirar el terreno en sitios conocidos.
##
## NO son parte del juego: no salen de la derivación del relieve ni tienen
## respaldo arqueológico. Existen para poder abrir el mapa de detalle sobre un
## paisaje que uno reconoce y juzgar si el terreno se ve bien, que a ojo en un
## valle anónimo es imposible.
@export var dev_sites: bool = true

@export_group("Bandas de material")
## Cotas reales en metros donde cambia el material del terreno
@export var shore_band_m: float = 30.0
@export var grass_top_m: float = 700.0
@export var rock_base_m: float = 500.0
@export var snow_base_m: float = 1900.0

var terrain: TerrainGenerator
var camera: OrbitalCamera
var boundary: RegionBoundary
var _info: Label
var _border: MeshInstance3D
var _sea_level_m: float = 0.0
var _site_set: SiteSet
var _markers: MultiMeshInstance3D
var _attested: int = 0
var _inferred: int = 0
var _legend_counts: Dictionary = {}
var _legend_labels: Dictionary = {}
var _visible_sites: Array[Site] = []
var _selected: Site
var _selection_marker: MeshInstance3D
var _detail: Label
var _founding: bool = false
## Epoca en curso. Se arranca en el Paleolitico, donde solo son ocupables los
## emplazamientos con abrigo natural: no hay tecnica para construir vivienda.
var _era: Site.Era = Site.Era.PALEOLITICO
## Reparto de partidas de esta estacion: Activity -> numero
var _assignment: Dictionary = {}
var _band_label: Label
var _eras: RegionEras
var _era_index: int = -1
## Fronteras ya trazadas, por indice de epoca: trazar cuesta segundos
var _border_cache: Dictionary = {}

## Color por tipo de emplazamiento
const KIND_COLORS := {
	Site.Kind.COSTERO: Color(0.20, 0.82, 0.74),
	Site.Kind.VALLE: Color(0.48, 0.83, 0.33),
	Site.Kind.ALTURA: Color(0.97, 0.61, 0.22),
	Site.Kind.INTERIOR: Color(0.85, 0.78, 0.60),
}

const KIND_ORDER := [
	Site.Kind.COSTERO, Site.Kind.VALLE, Site.Kind.ALTURA, Site.Kind.INTERIOR,
]


func _ready() -> void:
	var t_ready0 := Time.get_ticks_msec()
	print("=== Capa regional ===")
	var t_setup := Time.get_ticks_msec()
	_setup_terrain()
	print("[TIMING] _setup_terrain (carga heightmap regional): %d ms" % (Time.get_ticks_msec() - t_setup))
	_setup_camera()
	_setup_ui()

	var t0 := Time.get_ticks_msec()
	terrain.generate()

	# Y AHORA las bandas de material y la mascara de la epoca. Las dos cosas
	# hay que ponerlas DESPUES de generar, y por el mismo motivo de fondo:
	# generar el terreno monta el material desde cero.
	#
	# La mascara era la culpable del gris. Al montar el material, la
	# generacion la activa a partir de `heightmap.region_mask`, que es la
	# frontera ADMINISTRATIVA de hoy; y todo lo que queda fuera se pinta
	# desaturado y apagado. La plataforma emergida esta fuera de la Cantabria
	# de hoy por definicion -hoy es fondo marino-, asi que salia gris entera.
	#
	# La mascara buena es la de la epoca, que si la incluye. Se aplicaba, pero
	# ANTES de generar, y la generacion la pisaba.
	terrain.refresh_material_bands(_sea_level_m)
	print("Region generada en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var t_eras := Time.get_ticks_msec()
	_eras = load(eras_path) as RegionEras
	print("[TIMING] carga de eras_path: %d ms" % (Time.get_ticks_msec() - t_eras))

	# La mascara VA AQUI y no dos lineas antes: `_eras` se carga en la linea
	# de arriba, asi que llamando antes se llamaba con el objeto nulo y la
	# funcion se salia sin hacer nada. La plataforma seguia con la frontera
	# administrativa de hoy encima -que la deja fuera, porque hoy es fondo
	# marino- y por eso salia gris.
	var t_mask := Time.get_ticks_msec()
	_apply_era_mask()
	print("[TIMING] _apply_era_mask: %d ms" % (Time.get_ticks_msec() - t_mask))
	var t_sites := Time.get_ticks_msec()
	_build_sites()
	print("[TIMING] _build_sites (%d emplazamientos): %d ms" % [
		_site_set.sites.size() if _site_set else 0, Time.get_ticks_msec() - t_sites])

	if _site_set and not GameState.started:
		GameState.begin(_site_set)
	if GameState.home:
		_era = GameState.era
		# La cota del mar la fija la epoca, no el teclado
		_apply_era(GameState.sea_level_m)
		_select_site(GameState.home)
		camera.set_target(terrain.geo_to_world(GameState.home.lon, GameState.home.lat))
		camera.set_distance(float(maxi(terrain.terrain_size.x, terrain.terrain_size.y)) * 0.12)
	else:
		_apply_era(0.0)

	_update_info()
	print("[TIMING] === RegionMap._ready() TOTAL: %d ms ===" % (Time.get_ticks_msec() - t_ready0))


## Actividades que la banda puede hacer esta estacion, en orden estable
func _current_activities() -> Array[Subsistence.Activity]:
	if GameState.home == null:
		return []
	return Subsistence.available(GameState.home, GameState.season)


## Reparte las partidas que queden en la mejor actividad disponible
func _auto_assign() -> void:
	var acts := _current_activities()
	if acts.is_empty():
		return
	_assignment.clear()
	var total := Subsistence.parties(GameState.population)
	for i in range(total):
		var best: Subsistence.Activity = acts[0]
		var best_gain := -1.0
		for a: Subsistence.Activity in acts:
			if a == Subsistence.Activity.MATERIA_PRIMA:
				continue
			var now: int = _assignment.get(a, 0)
			var gain: float = Subsistence.harvest(GameState.home, GameState.season, a, now + 1) \
				- Subsistence.harvest(GameState.home, GameState.season, a, now)
			if gain > best_gain:
				best_gain = gain
				best = a
		_assignment[best] = int(_assignment.get(best, 0)) + 1


func _assigned_total() -> int:
	var total := 0
	for k: int in _assignment.keys():
		total += int(_assignment[k])
	return total


## Manda una partida a la actividad n-esima de la lista
func _assign_party(index: int) -> void:
	var acts := _current_activities()
	if index < 0 or index >= acts.size():
		return
	if _assigned_total() >= Subsistence.parties(GameState.population):
		return
	var a := acts[index]
	_assignment[a] = int(_assignment.get(a, 0)) + 1
	_update_band()


func _resolve_season() -> void:
	if GameState.home == null:
		return
	if _assigned_total() == 0:
		_auto_assign()
	GameState.advance_season(_assignment)
	_assignment.clear()
	_update_band()
	_update_info()


## Cambia el territorio a la cota del mar dada: mascara del terreno, frontera
## dibujada y emplazamientos disponibles.
func _apply_era(sea_level_m: float) -> void:
	_sea_level_m = sea_level_m

	var water := terrain.get_node_or_null("Water") as MeshInstance3D
	if water:
		water.position.y = (sea_level_m / meters_per_unit) * vertical_exaggeration

	# La arena va donde ROMPE EL MAR, y el mar rompia en otro sitio. Anclando
	# la banda en la cota cero, toda la plataforma emergida -miles de
	# kilometros cuadrados- salia pintada de playa; y no era playa, era
	# llanura costera con sus pastos y sus marismas, igual de verde que la
	# comarca de hoy.
	#
	# Si el terreno todavia no se ha generado, la llamada no hace nada y se
	# repite despues de generarlo. Ver [TerrainGenerator.refresh_material_bands].
	if terrain:
		terrain.refresh_material_bands(sea_level_m)

	if _eras:
		var index := _eras.index_for(sea_level_m)
		if index != _era_index:
			_era_index = index
			_apply_era_mask()

	_refresh_sites()
	if _selected and not _selected.is_available(_sea_level_m):
		_select_site(null)
	else:
		_update_detail()
	_update_band()
	_update_info()


## Muestra la frontera de una epoca, trazandola la primera vez
func _show_border(index: int) -> void:
	for key: int in _border_cache.keys():
		var node: MeshInstance3D = _border_cache[key]
		node.visible = key == index

	if _border_cache.has(index):
		return
	if _eras == null or index < 0 or index >= _eras.masks.size():
		return

	var mesh := _trace_border(_eras.masks[index], _eras.width, _eras.height)
	if mesh == null:
		return

	var node := MeshInstance3D.new()
	node.name = "Frontera_%d" % index
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = border_color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(node)
	node.material_override = material
	_border_cache[index] = node


## Carga los emplazamientos ya derivados y los dibuja como marcadores.
## Van en un solo MultiMesh: son casi dos mil y como nodos sueltos hundirian
## el rendimiento sin aportar nada.
func _build_sites() -> void:
	if not show_sites:
		return

	_site_set = load(sites_path) as SiteSet
	if _site_set == null:
		push_warning("RegionMap: no hay emplazamientos en " + sites_path)
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _marker_mesh()

	_markers = MultiMeshInstance3D.new()
	_markers.name = "Emplazamientos"
	_markers.multimesh = mm

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_markers.material_override = material

	if dev_sites:
		_add_dev_sites()

	for site: Site in _site_set.playable():
		if site.fidelity == Site.Fidelity.ATESTIGUADO:
			_attested += 1
		else:
			_inferred += 1

	add_child(_markers)
	_refresh_sites()
	print("Emplazamientos: %d jugables de %d derivados" % [
		_site_set.playable().size(), _site_set.sites.size()])


## Piramide invertida: apunta al sitio y se lee bien desde arriba
func _marker_mesh() -> ArrayMesh:
	var size := marker_size_m / meters_per_unit
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var tip := Vector3(0, 0, 0)
	var top := size * 1.8
	var half := size * 0.5
	var corners := [
		Vector3(-half, top, -half), Vector3(half, top, -half),
		Vector3(half, top, half), Vector3(-half, top, half),
	]
	for i in range(4):
		st.set_normal(Vector3.UP)
		st.add_vertex(tip)
		st.set_normal(Vector3.UP)
		st.add_vertex(corners[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(corners[(i + 1) % 4])

	return st.commit()


## Rellena el MultiMesh con los emplazamientos disponibles a la cota actual
func _refresh_sites() -> void:
	if _markers == null or _site_set == null or terrain == null:
		return

	# Solo lo DESCUBIERTO. Al empezar es la propia cueva y nada mas: el mapa se
	# gana explorando, no se regala.
	_visible_sites = []
	for site: Site in _site_set.available_in(_sea_level_m, _era):
		# Los de prueba se saltan la niebla: no son parte de la partida, son
		# un mirador. Con el filtro puesto desaparecian en cuanto se fundaba
		# el primer asentamiento, que es justo cuando hacen falta.
		var is_dev := site.id >= DEV_SITE_BASE
		if not is_dev and GameState.started and not GameState.is_discovered(site):
			continue
		_visible_sites.append(site)
	var visible_sites := _visible_sites
	_legend_counts.clear()
	var mm := _markers.multimesh

	# Solo se dibuja lo ATESTIGUADO. Los inferidos son sitios potenciales, no
	# yacimientos: llenar el mapa de marcadores deducidos lo vuelve ilegible y
	# ademas insinua una certeza que no existe. Se descubren al hacer click.
	var marked: Array[Site] = []
	for site: Site in visible_sites:
		var kind := site.kind_at(_era_index)
		_legend_counts[kind] = int(_legend_counts.get(kind, 0)) + 1
		if site.fidelity == Site.Fidelity.ATESTIGUADO:
			marked.append(site)

	mm.instance_count = marked.size()
	for i in range(marked.size()):
		var site: Site = marked[i]
		var world := terrain.geo_to_world(site.lon, site.lat)
		var is_dev := site.id >= DEV_SITE_BASE
		var xform := Transform3D()
		# Los de prueba, mas grandes y en un color que no usa ningun otro: son
		# un mirador para mirar terreno, y tienen que encontrarse a la primera
		# entre los ochocientos y pico marcadores del mapa.
		xform = xform.scaled(Vector3.ONE * (3.2 if is_dev else 1.6))
		xform.origin = world
		mm.set_instance_transform(i, xform)
		mm.set_instance_color(i, DEV_SITE_COLOR if is_dev
			else KIND_COLORS.get(site.kind_at(_era_index), Color.WHITE))

	_update_legend()


## Traza la frontera del contorno de una mascara.
##
## Del contorno REAL y no del poligono administrativo, porque el area jugable
## crece sobre la plataforma que emerge en cada epoca. Cinta y no linea porque
## Godot no engorda las lineas 3D y a esta escala se perderia.
func _trace_border(mask: PackedByteArray, w: int, h: int) -> ArrayMesh:
	var sx := float(terrain.terrain_size.x) / float(w - 1)
	var sz := float(terrain.terrain_size.y) / float(h - 1)
	var half := (border_width_m / meters_per_unit) * 0.5
	var lift := (border_lift_m / meters_per_unit) * vertical_exaggeration

	# Suavizar la trama antes de trazar: la mascara vive en celdas de 111 m y
	# seguir sus bordes al pie de la letra dibuja una escalera de pixeles. Un
	# desenfoque y un nuevo umbral redondean esa escalera sin mover la silueta.
	var soft := _smooth_mask(mask, w, h, 3)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 0

	for z in range(h - 1):
		var row := z * w
		for x in range(w - 1):
			var here := soft[row + x] > 0.5
			if here != (soft[row + x + 1] > 0.5):
				_add_border_quad(st,
					Vector2((float(x) + 0.5) * sx, float(z) * sz),
					Vector2((float(x) + 0.5) * sx, float(z + 1) * sz), half, lift)
				segments += 1
			if here != (soft[row + w + x] > 0.5):
				_add_border_quad(st,
					Vector2(float(x) * sx, (float(z) + 0.5) * sz),
					Vector2(float(x + 1) * sx, (float(z) + 0.5) * sz), half, lift)
				segments += 1

	if segments == 0:
		return null
	print("Frontera: %d tramos" % segments)
	return st.commit()


## Desenfoque de caja sobre la mascara, para quitar la escalera de trama
func _smooth_mask(mask: PackedByteArray, w: int, h: int, radius: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var window := float(radius * 2 + 1)

	for z in range(h):
		var row := z * w
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += 1.0 if mask[row + clampi(x, 0, w - 1)] > 127 else 0.0
		for x in range(w):
			tmp[row + x] = acc / window
			acc -= 1.0 if mask[row + clampi(x - radius, 0, w - 1)] > 127 else 0.0
			acc += 1.0 if mask[row + clampi(x + radius + 1, 0, w - 1)] > 127 else 0.0

	for x in range(w):
		var acc := 0.0
		for z in range(-radius, radius + 1):
			acc += tmp[clampi(z, 0, h - 1) * w + x]
		for z in range(h):
			out[z * w + x] = acc / window
			acc -= tmp[clampi(z - radius, 0, h - 1) * w + x]
			acc += tmp[clampi(z + radius + 1, 0, h - 1) * w + x]

	return out


func _add_border_quad(st: SurfaceTool, a2: Vector2, b2: Vector2, half: float, lift: float) -> void:
	var a := Vector3(a2.x, terrain.get_height_at(Vector3(a2.x, 0, a2.y)) + lift, a2.y)
	var b := Vector3(b2.x, terrain.get_height_at(Vector3(b2.x, 0, b2.y)) + lift, b2.y)
	var dir := b - a
	dir.y = 0.0
	if dir.length() < 0.0001:
		return
	dir = dir.normalized()
	var perp := Vector3(-dir.z, 0.0, dir.x) * half

	for v: Vector3 in [a - perp, a + perp, b + perp, a - perp, b + perp, b - perp]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


## Cambia la epoca desde el teclado
func _set_sea_level(meters: float) -> void:
	_apply_era(meters)


## Selecciona el emplazamiento mas cercano al raton.
##
## Se hace proyectando a pantalla y no con un raycast porque el mapa regional
## no tiene cuerpo de colision: no hace falta para nada mas y un trimesh de
## este tamano seria caro. Con dos mil sitios, recorrerlos por click es
## despreciable.
func _pick_site(screen_pos: Vector2) -> Site:
	if camera == null or _visible_sites.is_empty():
		return null

	var best: Site = null
	var best_score := 90.0   # tolerancia en pixeles
	for site: Site in _visible_sites:
		var world := terrain.geo_to_world(site.lon, site.lat)
		if camera.is_position_behind(world):
			continue
		var dist := camera.unproject_position(world).distance_to(screen_pos)
		# Los atestiguados tienen marcador visible y se estan apuntando, asi
		# que ganan a un inferido que este igual de cerca
		if site.fidelity == Site.Fidelity.ATESTIGUADO:
			dist *= 0.55
		if dist < best_score:
			best_score = dist
			best = site
	return best


func _select_site(site: Site) -> void:
	_selected = site

	if _selection_marker == null:
		_selection_marker = MeshInstance3D.new()
		_selection_marker.name = "Seleccion"
		var ring := TorusMesh.new()
		ring.inner_radius = (marker_size_m * 1.1) / meters_per_unit
		ring.outer_radius = (marker_size_m * 1.5) / meters_per_unit
		_selection_marker.mesh = ring
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 1.0, 1.0)
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		add_child(_selection_marker)
		_selection_marker.material_override = material

	_selection_marker.visible = site != null
	if site:
		_selection_marker.position = terrain.geo_to_world(site.lon, site.lat)
	_update_detail()


func _update_detail() -> void:
	if _detail == null:
		return
	if _selected == null:
		_detail.text = "Click en el mapa para ver el
emplazamiento mas cercano"
		return

	var era := _eras.index_for(_sea_level_m) if _eras else 0
	var lines := [
		("★ " if _selected.notable else "") + _selected.display_name().to_upper(),
		"%s   ·   %s" % [
			Site.name_of(_selected.kind_at(era)),
			"YACIMIENTO REAL" if _selected.fidelity == Site.Fidelity.ATESTIGUADO else "deducido del relieve"],
		"",
		"cota          %6.0f m" % _selected.elevation,
		"pendiente     %6.1f°" % _selected.slope_deg,
		"prominencia   %6.0f m sobre su entorno" % _selected.prominence,
		"al mar        %6.2f km" % _selected.coast_km_by_era[era] if era < _selected.coast_km_by_era.size() else "",
		"a un cauce    %6.2f km" % _selected.water_km,
		"a una cueva   %6.2f km%s" % [_selected.shelter_km, "   CON ABRIGO" if _selected.has_shelter else ""],
		"",
		"%.4f N  %.4f E" % [_selected.lat, _selected.lon],
	]
	lines.append("")
	lines.append(_selected.describe_for_player(era))

	if not _selected.features.is_empty():
		lines.append("")
		lines.append("EN ESTE RECUADRO (%d abrigos, %d simas):" % [
			_selected.cave_count(), _selected.shaft_count()])
		var shown := 0
		for f: Dictionary in _selected.features:
			var fname: String = f.get("name", "")
			if fname == "sin nombre" or shown >= 6:
				continue
			lines.append("  · %s" % fname)
			shown += 1
		var rest := _selected.features.size() - shown
		if rest > 0:
			lines.append("  · y %d mas" % rest)

	var att := _selected.attestations()
	if not att.is_empty():
		lines.append("")
		lines.append("OCUPACION DOCUMENTADA DESPUES:")
		var seen := {}
		for a: Dictionary in att:
			var cname := Site.feature_name(int(a["class"]) as Site.Feature)
			if seen.has(cname):
				continue
			seen[cname] = true
			lines.append("  · %s — %s" % [cname, a["name"]])

	lines.append("")
	lines.append("[F] fundar aqui")
	_detail.text = "
".join(lines)


## Funda en el emplazamiento seleccionado: descarga su relieve fino, guarda el
## recuadro y salta a la capa local.
##
## Las teselas se bajan AQUI y no antes porque a 13,9 m por muestra toda
## Cantabria serian unas 960 teselas; del sitio elegido son cuatro.
func _found_settlement() -> void:
	if _selected == null or _founding:
		return

	_founding = true

	# El recuadro local es caro de montar -descarga del IGN, borrado de obra
	# humana, drenaje- pero es SIEMPRE EL MISMO para un emplazamiento dado. Se
	# guarda en disco la primera vez y a partir de ahi se lee, con lo que la
	# segunda fundacion es instantanea. El sello de version invalida el fichero
	# solo si cambia el proceso, sin tener que acordarse de borrarlo.
	var cache_path := "res://data/dem/local/site_%d.res" % _selected.id
	if ResourceLoader.exists(cache_path):
		var cached: HeightmapData = load(cache_path)
		if cached != null and cached.pipeline_version == LOCAL_PIPELINE_VERSION:
			print("RegionMap: recuadro local leido de %s" % cache_path)
			# El contorno tiene su propia resolucion y su propia vida: si se
			# ha quedado mas basto de lo que ahora se pide, se rehace SOLO el.
			# Subir el sello del recuadro para esto obligaria a volver a
			# descargar el mapa jugable entero, que no ha cambiado en nada.
			await _refresh_surround_if_coarse(cached)
			_enter_local(cached)
			return
		print("RegionMap: %s es de una version anterior, se rehace" % cache_path)

	_detail.text = "Descargando relieve de %s...
(unos segundos)" % _selected.display_name()
	# Dos frames para que el mensaje llegue a pintarse antes del bloqueo
	await get_tree().process_frame
	await get_tree().process_frame

	# Margen justo sobre el recuadro jugable: cada decima de grado de mas son
	# miles de muestras que hay que descargar y parsear.
	var margin_m := float(Expedition.local_size_m) * 0.55
	var half_lat := margin_m * IGNImporter.DEG_PER_METER_LAT
	var half_lon := margin_m * IGNImporter.deg_per_meter_lon(_selected.lat)

	# Primero el MDT del IGN: 5 m derivados de LiDAR frente a los 13,9 m de
	# terrarium, que ademas da cotas en metros enteros. Es la diferencia entre
	# relieve y una interpolacion suave.
	var local: HeightmapData = null
	if use_ign_elevation:
		local = IGNImporter.new().import_area(
			_selected.lat + half_lat, _selected.lat - half_lat,
			_selected.lon - half_lon, _selected.lon + half_lon)

	var importer := DEMImporter.new()
	if local == null:
		# Reserva: fuera de Espana, o si el servicio del IGN no responde
		_detail.text = "Sin MDT del IGN, usando relieve global..."
		await get_tree().process_frame
		local = importer.import_area(
			_selected.lat + half_lat, _selected.lat - half_lat,
			_selected.lon - half_lon, _selected.lon + half_lon, 13)
		if local == null:
			_detail.text = "No se pudo descargar el relieve.
Comprueba la conexion."
			_founding = false
			return
		# Los artefactos que corregimos eran de terrarium. El MDT es dato
		# controlado y un umbral bajo se cargaria acantilados reales.
		importer.despike(local)

	# Quitar la obra humana ANTES de calcular los cauces: si se hace despues,
	# el drenaje se ha calculado ya sobre una cuneta de carretera y sale un rio
	# donde no lo hay.
	if remove_human_works:
		_detail.text = "Quitando carreteras y obra moderna del relieve..."
		await get_tree().process_frame

		var ways := OSMWays.new().fetch_area(
			local.lat_north, local.lat_south, local.lon_west, local.lon_east)
		if ways.is_empty():
			# Overpass caido o recuadro sin nada: se sigue igual, esto es una
			# mejora del paisaje, no un requisito para fundar
			print("RegionMap: sin geometrias de OSM, el relieve se deja como esta")
		else:
			var mask := TerrainInpainter.build_mask(local, ways)
			var repaired := TerrainInpainter.inpaint(local, mask)
			print("RegionMap: %d vias/areas de OSM, %d celdas de relieve reconstruidas (%.1f%%)" % [
				ways.size(), repaired,
				100.0 * float(repaired) / maxf(float(local.width * local.height), 1.0)])

	# Erosion: el MDT del IGN es fiel pero esta remuestreado a 5 m, y ese
	# remuestreo se come las carcavas y los regueros, que a esa escala son
	# justo lo que distingue una ladera de una rampa. Devolverselos con RUIDO
	# daria bultos sin relacion entre si; devolverselos con el proceso que los
	# produce da vaguadas que desembocan y conos de deyeccion al pie.
	#
	# Va DESPUES de quitar la obra humana -no tiene sentido erosionar un
	# terraplen de carretera- y ANTES de los cauces, para que el agua de OSM se
	# encaje sobre un relieve ya trabajado.
	if erosion_drops > 0:
		_detail.text = "Erosionando el relieve..."
		await get_tree().process_frame

		var t0 := Time.get_ticks_msec()
		# A media resolucion: las formas de la erosion viven a escala de
		# decenas de metros y salen igual sobre celdas de diez que de cinco,
		# pero cuestan la cuarta parte. Medido sobre este mismo recuadro:
		# 90 s a resolucion completa frente a 22 s asi, y con MAS efecto.
		# 0.67 es la tangente de 34 grados, el talud de un canchal calizo.
		Erosion.erode_coarse(local.elevations, local.width, local.height,
			erosion_drops, erosion_thermal_passes,
			local.meters_per_sample, 0.67, _selected.id, 2)

		var lo := INF
		var hi := -INF
		for e in local.elevations:
			lo = minf(lo, e)
			hi = maxf(hi, e)
		local.min_elevation = lo
		local.max_elevation = hi
		print("RegionMap: erosion de %d gotas en %d ms, cotas %.1f..%.1f" % [
			erosion_drops, Time.get_ticks_msec() - t0, lo, hi])

	# Los cauces salen de OSM, no del relieve. La acumulacion de drenaje D8
	# funciona a escala regional, donde una cuenca grande se ve sola, pero
	# sobre 4 km dejaba un 0,5% de celdas con valor medio 0,06: invisible. Y
	# ademas no sabe cual de esos hilos es el Nansa.
	var hidro := OSMWays.new().fetch_water(
		local.lat_north, local.lat_south, local.lon_west, local.lon_east)
	var canales: Array = hidro.get("channels", [])
	var laminas: Array = hidro.get("bodies", [])

	if canales.is_empty() and laminas.is_empty():
		# Reserva: sin OSM se vuelve al drenaje deducido, que es poco pero es
		# mejor que un recuadro completamente seco
		print("RegionMap: sin hidrografia de OSM, se deduce del relieve")
		importer.compute_river_mask(local, 20, 0.35)
	else:
		Hydrography.apply(local, canales, laminas)
		var mojadas := 0
		for v in local.river_mask:
			if v > 0.01:
				mojadas += 1
		print("RegionMap: %d cauces y %d laminas de OSM, %.2f%% del recuadro con agua" % [
			canales.size(), laminas.size(),
			100.0 * float(mojadas) / maxf(float(local.width * local.height), 1.0)])

	# --- relieve de las casillas de alrededor -----------------------------
	# Mismo sistema que el mapa jugable: MDT05 del IGN, LiDAR. El MDT regional
	# que se usaba antes da 111 m por muestra, o sea 37 puntos por casilla de
	# 4 km, y de ahi salian lomas lisas sin nada que se pareciera a un valle.
	#
	# Se pide el bloque de 3x3 casillas en UNA sola peticion -unos 12 km de
	# lado, medido: 19 s y 79 MB- y se guarda a 15 m por muestra. El dato es
	# el mismo MDT05; lo que cambia es cuanto se guarda, y 15 m sobra porque
	# la malla del contorno muestrea cada 32 m.
	_detail.text = "Descargando el relieve de alrededor...\nMDT del IGN, unos segundos."
	await get_tree().process_frame

	var surround_path := "res://data/dem/local/site_%d_surround.res" % _selected.id
	var span_lat := local.lat_north - local.lat_south
	var span_lon := local.lon_east - local.lon_west
	var t_sur := Time.get_ticks_msec()
	var surround: HeightmapData = null
	if use_ign_elevation:
		surround = IGNImporter.new().import_area(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon,
			surround_meters)

	if surround == null:
		# Reserva: fuera de Espana o si el IGN no responde
		surround = importer.import_area(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon, 13)
		if surround != null:
			importer.despike(surround)

	if surround != null:
		_apply_surround_water(surround)
		surround.pipeline_version = LOCAL_PIPELINE_VERSION
		ResourceSaver.save(surround, surround_path)
		print("RegionMap: contorno bakeado en %d ms, %d x %d a %.1f m (%s)" % [
			Time.get_ticks_msec() - t_sur, surround.width, surround.height,
			surround.meters_per_sample, surround.source])
	else:
		print("RegionMap: sin contorno propio, se usara el MDT regional")

	local.pipeline_version = LOCAL_PIPELINE_VERSION
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://data/dem/local"))
	ResourceSaver.save(local, cache_path)
	print("RegionMap: recuadro local bakeado en %s" % cache_path)

	_enter_local(local)


## Centra el recuadro jugable en el emplazamiento y salta a la capa local.
##
## Lo llaman los dos caminos -el que acaba de montar el recuadro y el que lo ha
## leido de disco- para que un cambio en el encuadre no se aplique solo a uno.
func _enter_local(local: HeightmapData) -> void:
	var size_m := local.get_world_size_meters()
	# Por el helper, que sabe si la rejilla es Mercator o geografica
	var u := local.u_for_lon(_selected.lon)
	var v := local.v_for_lat(_selected.lat)
	var half := float(Expedition.local_size_m) * 0.5

	Expedition.site = _selected
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % _selected.id
	Expedition.sea_level_m = _sea_level_m
	Expedition.era = _era
	Expedition.region_offset = Vector2(
		clampf(u * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(v * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))

	print("Fundando en %s (%.4f, %.4f)" % [_selected.display_name(), _selected.lat, _selected.lon])
	get_tree().change_scene_to_file(Expedition.LOCAL_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed 			and event.button_index == MOUSE_BUTTON_LEFT:
		_select_site(_pick_site(event.position))
		get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_assign_party(event.keycode - KEY_1)
			KEY_0:
				_assignment.clear()
				_update_band()
			KEY_SPACE:
				_resolve_season()
			KEY_F:
				_found_settlement()
			KEY_E:
				_era = ((_era + 1) % (Site.Era.HISTORICA + 1)) as Site.Era
				_refresh_sites()
				if _selected and not _visible_sites.has(_selected):
					_select_site(null)
				_update_info()


func _setup_terrain() -> void:
	var data := load(heightmap_path) as HeightmapData
	if data == null:
		push_error("RegionMap: no se pudo cargar " + heightmap_path)
		return

	print("Relieve: ", data.describe())

	terrain = TerrainGenerator.new()
	terrain.name = "RegionTerrain"
	terrain.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
	terrain.heightmap = data
	terrain.meters_per_unit = meters_per_unit
	terrain.vertical_exaggeration = vertical_exaggeration
	terrain.resolution = resolution

	# El mundo cubre exactamente el recuadro importado
	var size_m := data.get_world_size_meters()
	terrain.terrain_size = Vector2i(
		int(size_m.x / meters_per_unit),
		int(size_m.y / meters_per_unit))

	# A 111 m por muestra el DEM ya es basto: anadir ruido encima solo
	# ensuciaria la silueta de la costa
	terrain.detail_amplitude = 0.0

	# Sin colision: nada camina por el mapa regional, y el recuadro no es
	# cuadrado, asi que exigiria un trimesh caro
	terrain.generate_collision = false

	terrain.sea_level = 0.0
	terrain.band_sea_level_m = 0.0

	# La plataforma sale de batimetria, que es mucho mas basta que el MDT de
	# tierra: sin esto es una mesa de billar de veinte kilometros. Son lomas
	# INVENTADAS -no hay dato batimetrico a esta escala-, pero una llanura
	# perfectamente lisa es una mentira peor.
	terrain.shelf_relief_m = 14.0

	terrain.shore_band_m = shore_band_m
	terrain.grass_top_m = grass_top_m
	terrain.rock_base_m = rock_base_m
	terrain.snow_base_m = snow_base_m

	add_child(terrain)
	print("Mundo: %d x %d unidades  (%.1f x %.1f km a %.0f m/unidad)" % [
		terrain.terrain_size.x, terrain.terrain_size.y,
		size_m.x / 1000.0, size_m.y / 1000.0, meters_per_unit])


func _setup_camera() -> void:
	var scene := load("res://scenes/OrbitalCamera.tscn")
	if scene == null:
		push_error("RegionMap: falta OrbitalCamera.tscn")
		return

	camera = scene.instantiate() as OrbitalCamera
	camera.name = "RegionCamera"
	add_child(camera)

	var span := float(maxi(terrain.terrain_size.x, terrain.terrain_size.y))
	# En el regional se recorta solo el extremo cercano. El lejano se deja
	# entero porque el trabajo de esta capa es ver Cantabria de un vistazo, y
	# recortarlo dejaria la region sin caber en pantalla.
	camera.zoom_far_step = OrbitalCamera.ZOOM_STEPS
	camera.set_distance_limits(span * 0.02, span * 2.5)
	camera.move_speed = span * 0.25
	camera.far = span * 6.0
	# Ver el comentario en DemoMain: un near de 0.05 con este lejano deja el
	# buffer de profundidad sin resolucion y el mar sale a bandas
	camera.near = maxf(span * 0.0008, 0.1)
	camera.orbit_angle_v = -48.0
	camera.set_distance(span * 0.85)
	camera.set_target(Vector3(
		float(terrain.terrain_size.x) * 0.5, 0.0, float(terrain.terrain_size.y) * 0.5))
	camera.current = true


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	canvas.add_child(panel)

	_info = Label.new()
	_info.text = "Cantabria"
	panel.add_child(_info)

	var detail_margin := MarginContainer.new()
	detail_margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	detail_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	detail_margin.add_theme_constant_override("margin_top", 96)
	detail_margin.add_theme_constant_override("margin_right", 12)
	canvas.add_child(detail_margin)

	var detail_panel := PanelContainer.new()
	detail_margin.add_child(detail_panel)
	_detail = Label.new()
	_detail.text = "Click en un emplazamiento para verlo"
	detail_panel.add_child(_detail)

	# El detalle de la banda vive en el mapa LOCAL, que es donde esta la gente.
	# Aqui solo se resume: esta capa es de estrategia.
	var band_margin := MarginContainer.new()
	band_margin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	band_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	band_margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	band_margin.add_theme_constant_override("margin_right", 12)
	band_margin.add_theme_constant_override("margin_bottom", 12)
	canvas.add_child(band_margin)

	var band_panel := PanelContainer.new()
	band_margin.add_child(band_panel)
	_band_label = Label.new()
	band_panel.add_child(_band_label)

	_build_legend(canvas)

	var overlay := PerformanceOverlay.new()
	overlay.name = "PerformanceOverlay"
	add_child(overlay)


## Leyenda de tipos de emplazamiento, con el recuento de la epoca en curso
func _build_legend(canvas: CanvasLayer) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	canvas.add_child(margin)

	var panel := PanelContainer.new()
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "EMPLAZAMIENTOS"
	vbox.add_child(title)

	for kind: int in KIND_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		vbox.add_child(row)

		var swatch := ColorRect.new()
		swatch.color = KIND_COLORS[kind]
		swatch.custom_minimum_size = Vector2(16, 16)
		row.add_child(swatch)

		var label := Label.new()
		label.text = Site.name_of(kind)
		row.add_child(label)
		_legend_labels[kind] = label

	var note := Label.new()
	note.text = "
Solo se marcan los yacimientos reales.
Click en cualquier punto para ver
el emplazamiento potencial mas cercano."
	vbox.add_child(note)


## Estado de la banda y reparto de la estacion
func _update_band() -> void:
	if _band_label == null or GameState.home == null:
		return

	var total := Subsistence.parties(GameState.population)
	var capacity := Subsistence.carrying_capacity(GameState.home, GameState.population)
	var lines: Array[String] = [
		"%s, año %d" % [Subsistence.season_name(GameState.season), GameState.year],
		"",
		"%s" % GameState.home.display_name(),
		"gente    %3d   (el sitio da para %d)" % [GameState.population, capacity],
		"reserva  %3.0f dias" % GameState.food_days(),
		"",
		"El dia a dia de la gente se lleva",
		"desde el mapa de detalle: [F] entrar.",
		"",
		"[ESPACIO] pasar estacion",
	]
	var unused := total
	_band_label.text = "\n".join(lines)


func _update_legend() -> void:
	for kind: int in KIND_ORDER:
		var label: Label = _legend_labels.get(kind)
		if label:
			label.text = "%-9s %4d" % [Site.name_of(kind), int(_legend_counts.get(kind, 0))]


func _update_info() -> void:
	if _info == null or terrain == null:
		return

	var data: HeightmapData = terrain.heightmap
	var size_m := data.get_world_size_meters()
	var span := terrain.get_height_range()

	_info.text = "\n".join([
		"CANTABRIA — capa regional",
		"%.0f x %.0f km   ·   %.0f m por muestra" % [
			size_m.x / 1000.0, size_m.y / 1000.0, data.meters_per_sample],
		"cotas reales %.0f .. %.0f m" % [data.min_elevation, data.max_elevation],
		"1 unidad = %.0f m   ·   relieve x%.1f" % [meters_per_unit, vertical_exaggeration],
		"1 unidad = %.0f m   ·   relieve x%.1f" % [meters_per_unit, vertical_exaggeration],
		"",
		"nivel del mar: %+.0f m   %s" % [_sea_level_m,
			"(actual)" if is_zero_approx(_sea_level_m) else "(costa glacial)"],
		"",
		"emplazamientos disponibles: %d de %d" % [
			_site_set.available(_sea_level_m).size() if _site_set else 0,
			_site_set.playable().size() if _site_set else 0],
		"  %d atestiguados (rojizos) · %d inferidos" % [_attested, _inferred],
		"territorio: %s" % ("frontera administrativa" if is_zero_approx(_sea_level_m) else "Cantabria + plataforma emergida"),
		"",
		"EPOCA: %s   ·   %d ocupables de %d" % [
			Site.era_name(_era).to_upper(), _visible_sites.size(),
			_site_set.available(_sea_level_m).size() if _site_set else 0],
		"",
		"click       seleccionar emplazamiento",
		"F           fundar en el seleccionado",
		"WASD mover · click derecho rotar · rueda zoom · F3 rendimiento",
	])


## Pone al dia el contorno: la resolucion del relieve y los cauces.
##
## Son DOS cosas independientes y con precios muy distintos. Rehacer el MDT es
## una descarga larga; traer la hidrografia de OSM es corta. Si se comprueban
## juntas, un contorno que solo le falta el agua paga la descarga entera del
## relieve para nada, y peor: si el IGN falla, se queda tambien sin rios.
func _refresh_surround_if_coarse(local: HeightmapData) -> void:
	if local == null:
		return

	var path := "res://data/dem/local/site_%d_surround.res" % _selected.id
	if not ResourceLoader.exists(path):
		return

	var surround: HeightmapData = load(path)
	if surround == null:
		return

	# Con un 10% de margen: no merece la pena una descarga de minutos por una
	# diferencia de decimales
	var coarse := surround.meters_per_sample > surround_meters * 1.1
	var dry := surround.river_mask.is_empty()
	if not coarse and not dry:
		return

	if coarse and use_ign_elevation:
		_detail.text = "Mejorando el relieve de alrededor...
" 			+ "MDT del IGN a %.0f m para 12 km de lado: esto tarda." % surround_meters
		await get_tree().process_frame
		await get_tree().process_frame

		var span_lat := local.lat_north - local.lat_south
		var span_lon := local.lon_east - local.lon_west
		var started := Time.get_ticks_msec()
		var finer: HeightmapData = IGNImporter.new().import_area(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon, surround_meters)

		if finer != null:
			surround = finer
			dry = true  # el MDT nuevo viene seco: hay que volver a pintarle el agua
			print("RegionMap: contorno rehecho en %d ms, %d x %d a %.1f m" % [
				Time.get_ticks_msec() - started, surround.width, surround.height,
				surround.meters_per_sample])
		else:
			print("RegionMap: el IGN no ha respondido, se queda el relieve que habia")

	if dry:
		_detail.text = "Trazando los rios de alrededor..."
		await get_tree().process_frame
		_apply_surround_water(surround)

	surround.pipeline_version = LOCAL_PIPELINE_VERSION
	ResourceSaver.save(surround, path)


## Mete los cauces de OSM en el MDT del contorno.
##
## El agua tiene que CONTINUAR fuera del recuadro. Sin esto el Nansa llegaba
## al borde y se cortaba en seco contra la casilla de al lado, que es lo que
## mas delata que el mapa se acaba ahi: un rio que se acaba en una raya recta
## no existe en ninguna parte.
##
## Es la misma llamada que se hace para el recuadro jugable, sobre el bloque
## de 3x3. Si Overpass no responde, el contorno se queda seco y ya esta: es un
## fallo feo pero no rompe nada.
func _apply_surround_water(surround: HeightmapData) -> void:
	var hidro := OSMWays.new().fetch_water(
		surround.lat_north, surround.lat_south,
		surround.lon_west, surround.lon_east)
	var canales: Array = hidro.get("channels", [])
	var laminas: Array = hidro.get("bodies", [])

	if canales.is_empty() and laminas.is_empty():
		print("RegionMap: sin hidrografia para el contorno, se queda seco")
		return

	Hydrography.apply(surround, canales, laminas)
	print("RegionMap: %d cauces y %d laminas en el contorno"
		% [canales.size(), laminas.size()])


## Ids de los emplazamientos de prueba. Muy altos para no chocar nunca con los
## que salen de la derivación, que van desde cero.
const DEV_SITE_BASE := 9000

## Magenta: no lo usa ninguna clase de emplazamiento, asi que un marcador de
## este color sólo puede ser un sitio de prueba.
const DEV_SITE_COLOR := Color(1.0, 0.25, 0.85)

## Sitios conocidos donde poder mirar el terreno.
##
## Torrelavega es el caso util: valle ancho del Besaya, llano, con el mar a
## unos ocho kilometros. Es un paisaje que se reconoce, y sobre un paisaje que
## se reconoce se ve enseguida si el relieve, los rios y las texturas estan
## bien o no.
const DEV_PLACES := [
	{"name": "Torrelavega (prueba)", "lat": 43.34894, "lon": -4.04601},
]


func _add_dev_sites() -> void:
	if _site_set == null:
		return

	var index := 0
	for place: Dictionary in DEV_PLACES:
		var site := Site.new()
		site.id = DEV_SITE_BASE + index
		index += 1
		site.lat = float(place["lat"])
		site.lon = float(place["lon"])
		site.historical_name = String(place["name"])
		site.inside_region = true
		site.notable = true
		# ATESTIGUADO no por honestidad historica -no lo es- sino porque el
		# mapa SOLO dibuja marcador para los atestiguados: los inferidos son
		# sitios potenciales y llenar el mapa de ellos lo volveria ilegible.
		# Sin esto el sitio existia y no habia forma de verlo ni pincharlo.
		site.fidelity = Site.Fidelity.ATESTIGUADO

		# La cota sale del relieve regional: `is_available` la compara con el
		# nivel del mar de la epoca, y sin ella el sitio desaparece del mapa
		var data: HeightmapData = terrain.heightmap if terrain else null
		if data:
			site.elevation = data.sample_bilinear(
				data.u_for_lon(site.lon), data.v_for_lat(site.lat))

		# Se declara habitable en cualquier epoca: es un mirador, no una
		# propuesta arqueologica. Sin esto el filtro del Paleolitico -que pide
		# abrigo- lo dejaria fuera.
		site.has_shelter = true
		site.kind = Site.Kind.VALLE
		site.water_km = 0.4
		site.coast_km = 8.0
		site.slope_deg = 3.0

		_site_set.sites.append(site)
		print("Emplazamiento de prueba: %s (%.4f, %.4f) a %.0f m" % [
			site.display_name(), site.lat, site.lon, site.elevation])


## Pone la mascara del territorio de la epoca en curso.
##
## Va aparte porque hay que llamarla en DOS momentos que no se pueden juntar:
## al cambiar de epoca, y justo despues de generar el terreno. Generar monta el
## material desde cero y lo deja con la frontera administrativa de hoy, que
## deja fuera -y por tanto gris- toda la plataforma emergida.
func _apply_era_mask() -> void:
	if terrain == null:
		return
	if _eras == null:
		push_warning("Sin mascaras de epoca: el mapa queda con la frontera "
			+ "de hoy y la plataforma emergida sale gris.")
		return

	var index := maxi(_era_index, 0)
	var texture := _eras.mask_texture(index)
	terrain.set_region_mask_texture(texture)
	_show_border(index)

	# Se dice en voz alta porque una mascara que no cubre lo que deberia NO
	# se ve como un fallo: se ve como que el terreno esta mal pintado, y uno
	# se pasa la tarde mirando el shader.
	print("Territorio: epoca %d de %d · mar %+.0f m · mascara %s" % [
		index + 1, _eras.sea_levels.size(), _sea_level_m,
		"puesta" if texture else "NO DISPONIBLE"])
