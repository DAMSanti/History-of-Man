@tool
class_name TerrainGenerator
extends Node3D
## Generador de terreno procedural con 3 capas de ruido.
## Genera altura, humedad y geología para el mundo.

signal generation_complete()

## Tamaño del terreno en unidades
@export var terrain_size: Vector2i = Vector2i(128, 128):
	set(value):
		terrain_size = value
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Resolución del heightmap (vértices por lado)
@export var resolution: int = 129:
	set(value):
		# El limite de 513 dejaba 4 m por vertice en un mapa de 2 km; para
		# mundos mas grandes hace falta mas malla. El coste es de vertices, y
		# el terreno esta limitado por fragmento, no por geometria.
		resolution = clampi(value, 2, 2049)
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Altura máxima del terreno
@export var max_height: float = 30.0:
	set(value):
		max_height = value
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Semilla para generación procedural
@export var seed_value: int = 12345:
	set(value):
		seed_value = value
		_update_noise_seeds()
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

@export_group("Height Source")
## De donde sale la altura del terreno
enum HeightSource {
	PROCEDURAL,  ## Ruido procedural (mascara de relieve + crestas)
	HEIGHTMAP,   ## Elevacion real importada de un DEM
}

@export var height_source: HeightSource = HeightSource.PROCEDURAL:
	set(value):
		height_source = value
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Heightmap real a usar cuando height_source es HEIGHTMAP
@export var heightmap: HeightmapData:
	set(value):
		heightmap = value
		if Engine.is_editor_hint() and auto_generate:
			_queue_regenerate()

## Esquina del recuadro del heightmap que se renderiza, en metros desde su
## origen. Permite recortar una porcion de un DEM mucho mas grande que la malla.
@export var heightmap_region_offset: Vector2 = Vector2.ZERO

## Detalle procedural anadido sobre el DEM, en metros.
##
## No es adorno: el DEM tiene una muestra cada ~14 m y la malla local va a 4 m
## por vertice, o sea que 3 de cada 4 vertices son pura interpolacion. Sin
## detalle propio el terreno sale liso como una sabana.
## Es deliberadamente MODESTO. El DEM no tiene mas informacion real que sus
## muestras cada 14 m: lo que se anade aqui es invencion, y pasarse convierte
## el terreno en una sabana de picos.
@export_range(0.0, 8.0, 0.1) var detail_amplitude: float = 1.5

## Frecuencia base del detalle. Se recorta automaticamente para que ni la
## octava mas fina baje del cuadruple del paso de malla (ver _setup_noise).
@export var detail_frequency: float = 0.02

## Pocas octavas a proposito: cada una duplica la frecuencia, y la mas fina es
## la que alias contra la malla.
@export_range(1, 4) var detail_octaves: int = 2

## Cuanto mas detalle lleva la ladera que el llano. La roca desnuda es rugosa
## y una vega aluvial es lisa. Va acotado: sin tope, una ladera de 30 grados
## multiplicaba la amplitud por cuatro.
@export_range(0.0, 2.0, 0.1) var detail_slope_gain: float = 1.0

## Metros de desviacion que se consideran curvatura maxima. Con un valor bajo
## todo el mapa satura; con uno alto la curvatura no se nota.
## En cuantos trozos por lado se parte el terreno.
##
## Medido: el terreno se comia el 65% del fotograma, y era UNA sola malla de
## cuatro kilometros. Con una sola malla la tarjeta procesa los cuatro
## kilometros enteros mires donde mires -no hay nada que descartar por quedar
## fuera de camara- y el nivel de detalle tampoco sirve de mucho, porque Godot
## elige UN solo nivel para todo el conjunto segun lo que ocupa en pantalla.
##
## Troceado, cada cuadro se descarta o se simplifica por su cuenta. Con la
## camara a ras de suelo la mayoria quedan fuera y no cuestan nada.
##
## Ocho por lado son 64 trozos de 512 m. Mas trozos descartan mejor pero cada
## uno es una llamada de dibujo, y pasarse por ahi cuesta mas de lo que
## ahorra. En 1 se vuelve a la malla unica de antes.
@export_range(1, 16) var terrain_chunks: int = 8

@export_range(0.1, 20.0, 0.1) var curvature_scale: float = 2.5

## Longitud de onda de las manchas de vegetacion y roca, en metros
@export var macro_wavelength: float = 140.0
@export_range(1.0, 4.0, 0.1) var detail_slope_max: float = 2.0

@export_group("World Scale")
## Metros de terreno real por unidad de mundo.
## 1.0 para la capa local (el city builder trabaja en metros). Para la capa
## regional hay que subirlo: Cantabria son 171 km, que a 1 unidad = 1 m daria
## un mundo de 171.000 unidades, con problemas de precision y un plano lejano
## absurdo. A 100 m/unidad la region cabe en 1715 unidades.
@export var meters_per_unit: float = 1.0

## Exageracion vertical. A escala regional el relieve real es casi plano en
## proporcion (2600 m sobre 171 km), y los mapas en relieve siempre exageran.
@export_range(0.5, 10.0, 0.1) var vertical_exaggeration: float = 1.0

## Generar cuerpo de colision. La capa regional no lo necesita y en terreno no
## cuadrado obliga a un trimesh caro.
@export var generate_collision: bool = true

@export_group("Material Bands")
## Cotas en METROS sobre el nivel del mar donde cambia el material del shader
@export var shore_band_m: float = 4.0
@export var grass_top_m: float = 140.0
@export var rock_base_m: float = 100.0
@export var snow_base_m: float = 1e9

## Interpretar las bandas como FRACCION del rango de altura del recuadro en vez
## de como cotas absolutas.
##
## En un mapa local de 4 km la altitud no distingue el pasto de la roca: un
## sitio a 172 m con laderas hasta 300 salia entero marron porque todo pasaba
## de los 140 m de grass_top. A esa escala lo que separa hierba de roca es la
## PENDIENTE, no la cota.
@export var bands_relative: bool = false

## La cota que cuenta como orilla para los MATERIALES, en metros.
##
## Va aparte de `sea_level` —que entra en la geometría— porque son dos cosas
## distintas y confundirlas pintaba de arena la plataforma entera.
##
## Con el mar veinte mil años atrás a ciento veinte metros por debajo, todo lo
## que hoy es fondo marino queda por debajo de la cota cero; y si la banda de
## arena se ancla en cero, esos miles de kilómetros cuadrados salen de playa.
## No lo eran: eran una llanura costera con sus pastos, sus marismas y los
## mismos ríos de ahora corriendo veinte kilómetros más al norte. Arena hay
## donde rompe el mar, y el mar rompía en otro sitio.
@export var band_sea_level_m: float = 0.0

## Relieve que se le inventa a la plataforma emergida, en metros.
##
## La batimetría de la que sale el fondo marino es mucho más basta que el MDT
## de tierra, así que la plataforma sale como una mesa de billar. Esto le
## devuelve algo de forma —lomas suaves, los vallejos por donde bajaban los
## ríos hasta la costa glacial—.
##
## Es SÍNTESIS, no dato: no hay respaldo batimétrico para estas ondulaciones
## concretas. Se pone porque una llanura perfectamente lisa es una mentira
## peor que una llanura con lomas plausibles, pero conviene saber cuál es cuál.
@export_range(0.0, 40.0, 0.5) var shelf_relief_m: float = 0.0

@export_group("Rivers")
## Intensidad con la que se pintan los cauces deducidos del DEM (0 = ninguno)
@export_range(0.0, 1.0, 0.05) var river_strength: float = 1.0

@export_group("Sea")
## Cota del nivel del mar en metros. Con datos reales el cero es el mar real.
@export var sea_level: float = 0.0

## Dibujar el plano de agua
@export var show_water: bool = true

## Color del agua
@export var water_color: Color = Color(0.09, 0.22, 0.32, 0.88)

@export_group("Height Noise")
@export var height_frequency: float = 0.02
@export var height_octaves: int = 5
@export var height_lacunarity: float = 2.0
@export var height_gain: float = 0.5

@export_group("Mountain Noise")
## Ruido ridged que forma las crestas dentro de las zonas montanosas
@export var mountain_frequency: float = 0.018
@export var mountain_octaves: int = 5

@export_group("Relief Mask")
## Frecuencia de la mascara de relieve. Muy baja a proposito: define regiones
## grandes (llanura vs cordillera), no detalle. Subirla fragmenta el mapa.
@export var relief_frequency: float = 0.015
@export var relief_octaves: int = 3

## Por debajo de este valor de mascara la zona es llanura pura
@export_range(0.0, 1.0) var plains_level: float = 0.35

## Por encima de este valor la zona es montana con amplitud completa
@export_range(0.0, 1.0) var mountains_level: float = 0.70

## Exponente de la mascara: >1 concentra la montana en menos superficie
@export_range(0.5, 4.0) var relief_exponent: float = 1.4

## Altura base de las llanuras, como fraccion de max_height
@export_range(0.0, 1.0) var plains_height: float = 0.12

## Ondulacion residual de las llanuras (fraccion de max_height)
@export_range(0.0, 0.5) var plains_roughness: float = 0.08

## Altura que aportan las crestas en zona montanosa (fraccion de max_height)
@export_range(0.0, 1.0) var mountain_amplitude: float = 0.75

## Rugosidad extra dentro de las montanas, para que no sean picos limpios
@export_range(0.0, 0.5) var mountain_roughness: float = 0.12

@export_group("Humidity Noise")
@export var humidity_frequency: float = 0.01
@export var humidity_octaves: int = 3

@export_group("Geology Noise")
@export var geology_frequency: float = 0.015
@export var geology_octaves: int = 4

@export_group("Debug")
@export var auto_generate: bool = false
@export var show_debug_gizmos: bool = false
@export var debug_layer: String = "height"  # height, humidity, geology

## Nodos de ruido
var _height_noise: FastNoiseLite
var _mountain_noise: FastNoiseLite
var _relief_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _macro_noise: FastNoiseLite
var _humidity_noise: FastNoiseLite
var _geology_noise: FastNoiseLite

## Datos generados
var _height_map: PackedFloat32Array
var _humidity_map: PackedFloat32Array
var _geology_map: PackedFloat32Array
## Mascara de relieve ya evaluada: 0 = llanura, 1 = montana plena
var _relief_map: PackedFloat32Array

## Mascara de cauce muestreada en la rejilla de la malla (0 = seco, 1 = rio)
var _river_map: PackedFloat32Array
var _flow_map: PackedVector2Array
var _ford_map: PackedFloat32Array

## Mascara de region jugable en la rejilla de la malla (1 = dentro)
var _region_map: PackedFloat32Array

## Entalladuras a excavar antes de construir la malla.
## Cada entrada: {position: Vector3, radius: float, depth: float}
var carvings: Array[Dictionary] = []

## Mesh del terreno
var _terrain_mesh: MeshInstance3D
var _terrain_collision: StaticBody3D
var _water_mesh: MeshInstance3D

## Rango real de altura del terreno generado, en metros (min, max)
var _height_range: Vector2 = Vector2.ZERO

## Cache de generacion cargada para este generate(), o null si no hay ninguna
## valida y hay que calcular desde cero. Ver [TerrainGenerationCache].
var _gen_cache: TerrainGenerationCache = null

## Usar la cache de generacion en disco. Apagarlo obliga a calcular el terreno
## desde cero y NO escribe nada.
##
## Existe para las pruebas que comparan un mismo sitio con parametros
## distintos: la cache se nombra solo por resolucion, asi que dos variantes se
## pisarian el fichero, y la ultima en correr dejaria su malla como si fuese la
## buena. En juego siempre va encendido.
@export var use_generation_cache: bool = true

## Manager del material del terreno (carga diferida)
var _material_manager: RefCounted

## Variable para regeneración en editor
var _regenerate_queued: bool = false

## Si usar shader triplanar (true) o colores de vértice (false)
@export var use_triplanar_shader: bool = true


func _ready() -> void:
	_setup_noise()
	# No generar automáticamente - se llama generate() desde el código que lo use
	# if not Engine.is_editor_hint():
	# 	generate()


func _process(_delta: float) -> void:
	if _regenerate_queued:
		_regenerate_queued = false
		generate()


func _queue_regenerate() -> void:
	_regenerate_queued = true


func _setup_noise() -> void:
	_height_noise = FastNoiseLite.new()
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = height_frequency
	_height_noise.fractal_octaves = height_octaves
	_height_noise.fractal_lacunarity = height_lacunarity
	_height_noise.fractal_gain = height_gain
	
	# Ruido ridged: invierte los valles del FBM en crestas afiladas, que es lo
	# que distingue una cordillera de un monton de bultos redondeados.
	_mountain_noise = FastNoiseLite.new()
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_noise.frequency = mountain_frequency
	_mountain_noise.fractal_octaves = mountain_octaves
	_mountain_noise.fractal_lacunarity = height_lacunarity
	_mountain_noise.fractal_gain = height_gain

	# Detalle fino, para rellenar entre muestras del DEM.
	#
	# La frecuencia se recorta contra el paso de malla. Un ruido cuya octava
	# mas fina cae por debajo de unos pocos vertices no se puede representar:
	# alias, y en vez de textura salen picos vertice a vertice. Con 4 octavas a
	# 0.07 la mas fina median 1,8 m sobre una malla de 4 m, y el terreno
	# quedaba cubierto de puas.
	_detail_noise = FastNoiseLite.new()
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail_noise.fractal_octaves = detail_octaves
	_detail_noise.fractal_gain = 0.5
	_detail_noise.frequency = _safe_detail_frequency()

	# Variacion de parche: manchas de suelo, matorral y roca. Frecuencia baja a
	# proposito, es lo que rompe la homogeneidad sin tocar la geometria.
	_macro_noise = FastNoiseLite.new()
	_macro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_macro_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_macro_noise.fractal_octaves = 3
	_macro_noise.frequency = 1.0 / maxf(macro_wavelength, 1.0)
	_macro_noise.seed = seed_value + 1700

	# Mascara de relieve: decide DONDE hay montana, no que forma tiene
	_relief_noise = FastNoiseLite.new()
	_relief_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_relief_noise.frequency = relief_frequency
	_relief_noise.fractal_octaves = relief_octaves

	_humidity_noise = FastNoiseLite.new()
	_humidity_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_humidity_noise.frequency = humidity_frequency
	_humidity_noise.fractal_octaves = humidity_octaves
	
	_geology_noise = FastNoiseLite.new()
	_geology_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_geology_noise.frequency = geology_frequency
	_geology_noise.fractal_octaves = geology_octaves
	
	_update_noise_seeds()


func _update_noise_seeds() -> void:
	if _height_noise:
		_height_noise.seed = seed_value
	if _mountain_noise:
		_mountain_noise.seed = seed_value + 500
	if _relief_noise:
		_relief_noise.seed = seed_value + 3000
	if _detail_noise:
		_detail_noise.seed = seed_value + 900
	if _humidity_noise:
		_humidity_noise.seed = seed_value + 1000
	if _geology_noise:
		_geology_noise.seed = seed_value + 2000


## Genera el terreno completo
func generate() -> void:
	var t0 := Time.get_ticks_msec()
	_setup_noise()
	print("[TIMING] TerrainGenerator._setup_noise: %d ms" % (Time.get_ticks_msec() - t0))

	# El terreno de un sitio dado no cambia entre partidas: mismo heightmap,
	# mismos parametros, mismas entalladuras -> mismo resultado siempre. Si hay
	# una cache valida en disco, _generate_maps y _create_terrain_mesh se saltan
	# el muestreo del heightmap y el generate_lods, que es donde se va casi todo
	# el tiempo de carga. Ver [TerrainGenerationCache].
	var tcache := Time.get_ticks_msec()
	_gen_cache = _load_generation_cache()
	if _gen_cache != null:
		print("[TIMING] cache de generacion encontrada (%d ms de comprobar): %s" % [
			Time.get_ticks_msec() - tcache, _cache_base_path()])

	var t1 := Time.get_ticks_msec()
	_generate_maps()
	print("[TIMING] TerrainGenerator._generate_maps: %d ms" % (Time.get_ticks_msec() - t1))

	var t2 := Time.get_ticks_msec()
	_create_terrain_mesh()
	print("[TIMING] TerrainGenerator._create_terrain_mesh (total): %d ms" % (Time.get_ticks_msec() - t2))

	var t3 := Time.get_ticks_msec()
	_create_water()
	print("[TIMING] TerrainGenerator._create_water: %d ms" % (Time.get_ticks_msec() - t3))

	print("[TIMING] TerrainGenerator.generate TOTAL: %d ms" % (Time.get_ticks_msec() - t0))
	generation_complete.emit()


## Genera los mapas de ruido
func _generate_maps() -> void:
	if _gen_cache != null:
		_height_map = _gen_cache.height_map
		_humidity_map = _gen_cache.humidity_map
		_geology_map = _gen_cache.geology_map
		_relief_map = _gen_cache.relief_map
		_river_map = _gen_cache.river_map
		_flow_map = _gen_cache.flow_map
		_ford_map = _gen_cache.ford_map
		_region_map = _gen_cache.region_map
		_height_range = _gen_cache.height_range
		return

	var total_points := resolution * resolution
	_height_map.resize(total_points)
	_humidity_map.resize(total_points)
	_geology_map.resize(total_points)
	_relief_map.resize(total_points)
	_river_map.resize(total_points)
	_river_map.fill(0.0)
	_flow_map.resize(total_points)
	_flow_map.fill(Vector2.ZERO)
	_ford_map.resize(total_points)
	_ford_map.fill(0.0)
	_region_map.resize(total_points)
	_region_map.fill(1.0)

	# Capas intermedias, solo necesarias durante la composicion
	var base_map := PackedFloat32Array()
	var ridge_map := PackedFloat32Array()
	base_map.resize(total_points)
	ridge_map.resize(total_points)

	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)

	var tn0 := Time.get_ticks_msec()
	for z in range(resolution):
		for x in range(resolution):
			var world_x := x * step_x
			var world_z := z * step_z
			var idx := z * resolution + x

			base_map[idx] = _height_noise.get_noise_2d(world_x, world_z)
			ridge_map[idx] = _mountain_noise.get_noise_2d(world_x, world_z)
			_relief_map[idx] = _relief_noise.get_noise_2d(world_x, world_z)
			_humidity_map[idx] = (_humidity_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5
			_geology_map[idx] = _geology_noise.get_noise_2d(world_x, world_z)
	print("[TIMING]   ruido base (5 capas x %d celdas): %d ms" % [
		resolution * resolution, Time.get_ticks_msec() - tn0])

	# Cada tipo de ruido ocupa un rango distinto: el celular con RETURN_DISTANCE
	# se queda en negativos (~[-0.88,-0.22]) y el ridged esta sesgado hacia
	# arriba. Asumir [-1,1] dejaba toda la geologia por debajo de 0.4 -> nunca
	# salia hierro. Reescalamos cada capa con su rango real.
	var tnorm0 := Time.get_ticks_msec()
	_geology_map = _normalize_map(_geology_map)
	_relief_map = _normalize_map(_relief_map)
	base_map = _normalize_map(base_map)
	ridge_map = _normalize_map(ridge_map)
	print("[TIMING]   normalize_map x4: %d ms" % (Time.get_ticks_msec() - tnorm0))

	var tcomp0 := Time.get_ticks_msec()
	if height_source == HeightSource.HEIGHTMAP and heightmap:
		_compose_from_heightmap(base_map)
	else:
		_compose_height_map(base_map, ridge_map)
	print("[TIMING]   composicion de altura: %d ms" % (Time.get_ticks_msec() - tcomp0))

	var tcarve0 := Time.get_ticks_msec()
	_apply_carvings()
	print("[TIMING]   _apply_carvings: %d ms" % (Time.get_ticks_msec() - tcarve0))
	_update_height_range()


## Combina las capas en el heightmap final.
## La mascara de relieve modula la AMPLITUD de la montana: sin esto una sola
## capa de FBM da la misma rugosidad en todo el mapa (ni llanuras ni cumbres).
func _compose_height_map(base_map: PackedFloat32Array, ridge_map: PackedFloat32Array) -> void:
	for i in range(_height_map.size()):
		var mask := smoothstep(plains_level, mountains_level, _relief_map[i])
		mask = pow(mask, relief_exponent)
		# Guardamos la mascara ya evaluada: 0 = llanura, 1 = montana
		_relief_map[i] = mask

		# Llanura: casi plana en todo el mapa
		var h := plains_height + base_map[i] * plains_roughness
		# Montana: crestas ridged + rugosidad, solo donde la mascara lo permite
		h += mask * (ridge_map[i] * mountain_amplitude + base_map[i] * mountain_roughness)

		# El mapa se guarda en METROS, no normalizado: es lo que necesita el
		# modo DEM y evita tener dos convenciones distintas conviviendo.
		_height_map[i] = clampf(h, 0.0, 1.0) * max_height


## Compone el heightmap a partir de elevacion real.
## El DEM aporta la forma grande y el ruido rellena el detalle entre muestras.
func _compose_from_heightmap(base_map: PackedFloat32Array) -> void:
	# El paso de la malla va en unidades; el muestreo del DEM, en metros
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	var meters_x := step_x * meters_per_unit
	var meters_z := step_z * meters_per_unit
	var top := maxf(heightmap.max_elevation - sea_level, 1.0)

	for z in range(resolution):
		for x in range(resolution):
			var idx := z * resolution + x
			var elevation := heightmap.sample_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z)

			# El detalle se desvanece al acercarse al agua para no rizar la
			# lamina ni inventar rocas donde el DEM dice que hay mar
			var land := clampf((elevation - sea_level) / 5.0, 0.0, 1.0)

			# Pendiente del DEM aqui: la ladera lleva mas rugosidad que el llano
			var east := heightmap.sample_meters(
				heightmap_region_offset.x + float(x) * meters_x + meters_x,
				heightmap_region_offset.y + float(z) * meters_z)
			var south := heightmap.sample_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z + meters_z)
			var gradient := Vector2(east - elevation, south - elevation).length() \
				/ maxf(meters_x, 0.001)
			var roughness := clampf(
				1.0 + gradient * detail_slope_gain, 1.0, detail_slope_max)

			var detail := _detail_noise.get_noise_2d(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z) \
				* _effective_detail_amplitude()

			# Y el relieve de la plataforma, que solo entra por DEBAJO de la
			# cota cero: ahi el dato es batimetria basta y sale una mesa de
			# billar. Se difumina en los treinta metros de encima de la costa
			# actual para que no aparezca una linea de corte donde hoy rompe
			# el mar.
			if shelf_relief_m > 0.0 and elevation < 30.0:
				var submerged := clampf((30.0 - elevation) / 30.0, 0.0, 1.0)
				var wide_noise := _detail_noise.get_noise_2d(
					(heightmap_region_offset.x + float(x) * meters_x) * 0.16,
					(heightmap_region_offset.y + float(z) * meters_z) * 0.16)
				detail += wide_noise * shelf_relief_m * submerged

			# La lamina de agua se toma de su propia cota y NO del terreno
			# remuestreado. Dos motivos: el muestreo bilineal cerca de la
			# orilla mezcla el agua con la ribera, y el ruido de detalle
			# rizaba la superficie, con lo que el rio salia ondulando en
			# vertical como si rodara por encima de las lomas.
			var river_here := heightmap.sample_river_mask_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z)
			var surface := heightmap.sample_water_level_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z)
			if river_here > 0.05 and surface != 0.0:
				elevation = lerpf(elevation, surface,
					smoothstep(0.05, 0.55, river_here))

			# El agua no lleva rugosidad de terreno: es una lamina
			var wet := clampf(river_here * 1.6, 0.0, 1.0)
			_height_map[idx] = _to_units(
				elevation + detail * land * roughness * (1.0 - wet))
			# En modo DEM el "relieve" es la altura sobre el nivel del mar
			_relief_map[idx] = clampf((elevation - sea_level) / top, 0.0, 1.0)

			# Cauces deducidos del DEM. Van aparte del plano de agua porque un
			# plano solo cubre UNA cota: el tramo mareal. Rio arriba el cauce
			# sube y hay que pintarlo sobre el propio terreno.
			_flow_map[idx] = heightmap.sample_flow_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z)
			_ford_map[idx] = heightmap.sample_ford_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z)
			_river_map[idx] = heightmap.sample_river_mask_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z) * river_strength

			# Fuera de la region jugable el terreno se dibuja apagado: es
			# contexto geografico, no tablero.
			_region_map[idx] = heightmap.sample_region_mask_meters(
				heightmap_region_offset.x + float(x) * meters_x,
				heightmap_region_offset.y + float(z) * meters_z)


## Excava el terreno en los puntos marcados.
##
## Un heightmap no puede representar una oquedad, porque no admite voladizos.
## Si puede representar la ENTALLADURA de una boca de cueva: el rebaje en la
## ladera donde se abre. La oquedad en si la pone una malla aparte.
func _apply_carvings() -> void:
	if carvings.is_empty():
		return

	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)

	for cut: Dictionary in carvings:
		var centre: Vector3 = cut.get("position", Vector3.ZERO)
		var radius: float = cut.get("radius", 12.0)
		var depth: float = cut.get("depth", 4.0)
		if radius <= 0.0:
			continue

		var cx := int(centre.x / step_x)
		var cz := int(centre.z / step_z)
		var span_x := int(ceil(radius / step_x))
		var span_z := int(ceil(radius / step_z))

		for z in range(maxi(cz - span_z, 0), mini(cz + span_z + 1, resolution)):
			for x in range(maxi(cx - span_x, 0), mini(cx + span_x + 1, resolution)):
				var dx := float(x) * step_x - centre.x
				var dz := float(z) * step_z - centre.z
				var dist := sqrt(dx * dx + dz * dz)
				if dist > radius:
					continue
				# Perfil suave: hondo en el centro, a ras en el borde
				var falloff := 1.0 - smoothstep(0.0, radius, dist)
				_height_map[z * resolution + x] -= depth * falloff * falloff


## Recalcula el rango real de altura tras generar
func _update_height_range() -> void:
	if _height_map.is_empty():
		_height_range = Vector2.ZERO
		return
	var mn := _height_map[0]
	var mx := _height_map[0]
	for h in _height_map:
		mn = minf(mn, h)
		mx = maxf(mx, h)
	_height_range = Vector2(mn, mx)


## Amplitud del detalle segun CUANTO IGNORA EL DATO.
##
## El detalle se escribio contra el terrarium, que trae una muestra cada 13,9 m
## sobre una malla de 4,97 m: alli 3 de cada 4 vertices eran interpolacion, la
## interpolacion siempre da rampa lisa, y el ruido rompia esa lisura. Era un
## defecto real y esto lo tapaba.
##
## Pero el mapa local se carga hoy del MDT05 del IGN -5,00 m por muestra, o sea
## practicamente un dato por vertice- y ahi no queda lisura que romper: el ruido
## solo puede ondular relieve medido. Comparado a ojo sobre el sitio 56, con
## amplitud 3 el monte se cubre de bultos redondos y se comen las crestas y las
## vaguadas del LiDAR (ver scripts/tests/DetalleProbe.gd).
##
## Asi que la amplitud sale de la razon entre el paso del DATO y el de la MALLA:
##
##   IGN        5,00 / 4,97 = 1,01  ->  ~0, el dato ya lo sabe
##   terrarium 13,91 / 4,97 = 2,80  ->  entero, hace falta
##
## `detail_amplitude` sigue siendo el techo, no el valor: se ajusta a mano lo
## que se anade COMO MUCHO, y el dato decide cuanto de eso hace falta. Con
## terreno procedural no hay muestreo que valga y entra entero.
func _effective_detail_amplitude() -> float:
	if height_source != HeightSource.HEIGHTMAP or heightmap == null:
		return detail_amplitude
	if heightmap.meters_per_sample <= 0.0:
		return detail_amplitude
	var spacing := float(terrain_size.x) / float(maxi(resolution - 1, 1)) * meters_per_unit
	if spacing <= 0.0:
		return detail_amplitude
	var ratio := heightmap.meters_per_sample / spacing
	return detail_amplitude * clampf(ratio - 1.0, 0.0, 1.0)


## Frecuencia de detalle recortada para que no alias contra la malla.
## La octava mas fina debe tener al menos cuatro vertices por longitud de onda.
func _safe_detail_frequency() -> float:
	var spacing := float(terrain_size.x) / float(maxi(resolution - 1, 1)) * meters_per_unit
	var finest_multiplier := pow(2.0, float(maxi(detail_octaves - 1, 0)))
	var min_wavelength := spacing * 4.0 * finest_multiplier
	return minf(detail_frequency, 1.0 / maxf(min_wavelength, 0.001))


## Convierte una cota en metros a unidades de mundo
func _to_units(meters: float) -> float:
	return (meters / maxf(meters_per_unit, 0.0001)) * vertical_exaggeration


## Normaliza una altura en metros a 0-1 para colores y bandas del shader
func _normalize_height(height_m: float) -> float:
	if height_source == HeightSource.HEIGHTMAP and heightmap:
		var span := maxf(_height_range.y - _height_range.x, 0.001)
		return clampf((height_m - _height_range.x) / span, 0.0, 1.0)
	return clampf(height_m / max_height, 0.0, 1.0)


## Reescala un mapa al rango 0-1 usando sus valores minimo y maximo reales
func _normalize_map(map: PackedFloat32Array) -> PackedFloat32Array:
	if map.is_empty():
		return map

	var min_v := map[0]
	var max_v := map[0]
	for v in map:
		min_v = minf(min_v, v)
		max_v = maxf(max_v, v)

	var span := max_v - min_v
	if span <= 0.0001:
		for i in range(map.size()):
			map[i] = 0.5
		return map

	for i in range(map.size()):
		map[i] = (map[i] - min_v) / span
	return map


## Crea el mesh del terreno
func _create_terrain_mesh() -> void:
	# Limpiar mesh anterior
	if _terrain_mesh:
		_terrain_mesh.queue_free()
	if _terrain_collision:
		_terrain_collision.queue_free()

	if _gen_cache != null:
		_create_terrain_mesh_from_cache(_gen_cache)
		return

	var arrays := _construir_arrays()

	# El paso vuelve a hacer falta aqui: es lo que dice si el recuadro es
	# cuadrado, y de eso depende que haga falta colision de malla.
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	var single_mesh := _malla_para_dibujar(arrays, step_x, step_z)

	_terrain_mesh = MeshInstance3D.new()
	_terrain_mesh.name = "TerrainMesh"
	# Con troceado el nodo raiz no lleva malla: la llevan los trozos, que
	# cuelgan de el. Ver [_split_into_chunks].
	if terrain_chunks <= 1:
		_terrain_mesh.mesh = single_mesh

	var tmat0 := Time.get_ticks_msec()
	_apply_terrain_material()
	print("[TIMING]   material/texturas de terreno: %d ms" % (Time.get_ticks_msec() - tmat0))

	add_child(_terrain_mesh)

	var chunk_meshes: Array[ArrayMesh] = []
	if terrain_chunks > 1:
		var tchunk0 := Time.get_ticks_msec()
		chunk_meshes = _split_into_chunks(arrays)
		print("[TIMING]   _split_into_chunks: %d ms" % (Time.get_ticks_msec() - tchunk0))

	# Crear colisión. Sale del campo de alturas, no de la malla, asi que el
	# troceado no la toca.
	var tcol0 := Time.get_ticks_msec()
	_create_collision(single_mesh)
	print("[TIMING]   _create_collision: %d ms" % (Time.get_ticks_msec() - tcol0))

	_save_generation_cache(single_mesh, chunk_meshes)


## Los arrays de la malla: vertices, normales, tangentes, color, UV e indices.
##
## Se construyen A MANO en vez de con SurfaceTool. SurfaceTool anade vertice a
## vertice desde GDScript y luego recalcula normales y tangentes promediando
## por cara: en una malla de un millon de vertices eso eran unos 35 segundos.
## Aqui las normales salen analiticamente del campo de alturas, que ademas de
## rapido es exacto: no hay que recorrer las caras.
func _construir_arrays() -> Array:
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	var count := resolution * resolution

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	tangents.resize(count * 4)
	colors.resize(count)
	uvs.resize(count)
	uv2s.resize(count)

	var tvert0 := Time.get_ticks_msec()
	for z in range(resolution):
		var row := z * resolution
		var zu := maxi(z - 1, 0) * resolution
		var zd := mini(z + 1, resolution - 1) * resolution
		var dz_span := (mini(z + 1, resolution - 1) - maxi(z - 1, 0)) * step_z

		for x in range(resolution):
			var idx := row + x
			var height := _height_map[idx]

			vertices[idx] = Vector3(float(x) * step_x, height, float(z) * step_z)
			# UV en coordenadas de mundo para que la textura tile igual
			uvs[idx] = Vector2(float(x) * step_x / 4.0, float(z) * step_z / 4.0)
			# El color de vertice transporta la hidrografia entera al shader, y
			# va gratis porque el triplanar no usaba ninguno de sus canales:
			#   rg = sentido de la corriente, reescalado a 0..1
			#   b  = agua quieta (una laguna no desfila)
			#   a  = lamina de agua
			var flow: Vector2 = _flow_map[idx] if idx < _flow_map.size() else Vector2.ZERO
			var wetness: float = _river_map[idx] if idx < _river_map.size() else 0.0
			colors[idx] = Color(
				flow.x * 0.5 + 0.5,
				flow.y * 0.5 + 0.5,
				1.0 if (wetness > 0.01 and flow.length_squared() < 0.01) else 0.0,
				wetness)

			# UV2 quedo libre al pasar la mascara de region a textura, y ahora
			# transporta dos cosas que se calculan una vez por vertice en vez
			# de por fragmento: curvatura y variacion de parche.
			#
			# La CURVATURA es lo que faltaba para que el terreno deje de verse
			# homogeneo: lo concavo acumula suelo y humedad, lo convexo se
			# erosiona y deja roca. Con pendiente y altitud solos, una ladera
			# entera sale del mismo color.
			var left := maxi(x - 1, 0)
			var right := mini(x + 1, resolution - 1)
			var laplacian := (
				_height_map[row + left] + _height_map[row + right]
				+ _height_map[zu + x] + _height_map[zd + x]) * 0.25 - height
			var curvature := clampf(laplacian / maxf(curvature_scale, 0.001), -1.0, 1.0)

			# Variacion a escala de decenas de metros, para que haya manchas de
			# pasto, matorral y roca en vez de un degradado continuo
			var macro := _macro_noise.get_noise_2d(
				float(x) * step_x, float(z) * step_z) * 0.5 + 0.5

			uv2s[idx] = Vector2(curvature * 0.5 + 0.5, macro)

			var xl := maxi(x - 1, 0)
			var xr := mini(x + 1, resolution - 1)
			var dhdx := (_height_map[row + xr] - _height_map[row + xl]) / (float(xr - xl) * step_x)
			var dhdz := (_height_map[zd + x] - _height_map[zu + x]) / dz_span

			# Normal de un campo de alturas y = h(x,z)
			normals[idx] = Vector3(-dhdx, 1.0, -dhdz).normalized()

			# Tangente a lo largo de +X, que es la direccion de +U
			var tangent := Vector3(1.0, dhdx, 0.0).normalized()
			var t := idx * 4
			tangents[t] = tangent.x
			tangents[t + 1] = tangent.y
			tangents[t + 2] = tangent.z
			# La bitangente debe ir hacia +Z (direccion de +V)
			tangents[t + 3] = -1.0

	print("[TIMING]   bucle de vertices/normales/UV (%d celdas): %d ms" % [
		count, Time.get_ticks_msec() - tvert0])

	# Índices (triángulos) - CCW winding order visto desde arriba
	var tidx0 := Time.get_ticks_msec()
	var indices := PackedInt32Array()
	indices.resize((resolution - 1) * (resolution - 1) * 6)
	var i := 0
	for z in range(resolution - 1):
		for x in range(resolution - 1):
			var top_left := z * resolution + x
			var top_right := top_left + 1
			var bottom_left := (z + 1) * resolution + x
			var bottom_right := bottom_left + 1

			indices[i] = top_left
			indices[i + 1] = top_right
			indices[i + 2] = bottom_left
			indices[i + 3] = top_right
			indices[i + 4] = bottom_right
			indices[i + 5] = bottom_left
			i += 6
	print("[TIMING]   bucle de indices: %d ms" % (Time.get_ticks_msec() - tidx0))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


## La malla que se dibuja, si es que hay que dibujar una sola.
##
## Con el terreno troceado -el caso normal- devuelve null: la malla la llevan
## los trozos y la colision sale del campo de alturas, asi que construirla
## seria pagar `generate_lods()` dos veces sobre el mismo millon de vertices
## para tirar la primera entera. Medido: de 9 a 19 segundos regalados.
func _malla_para_dibujar(arrays: Array, step_x: float, step_z: float) -> ArrayMesh:
	# Con niveles de detalle. Medido: el recuadro cuesta 29 ms de fotograma con
	# 2,1 millones de triangulos a 1025 vertices por lado, y buena parte de esa
	# malla cae lejos de la camara, donde un vertice cada cuatro metros y uno
	# cada dieciseis dan el mismo pixel. Godot elige el nivel por cuanto ocupa
	# en pantalla; la colision y las consultas de altura NO usan esta malla,
	# asi que simplificarla no afecta a la simulacion.
	#
	# Si el terreno va troceado -el caso normal, ver `terrain_chunks`- esta
	# malla unica NO SE DIBUJA (la llevan los trozos) y la colision cuadrada
	# tampoco la usa (sale de `_height_map` via HeightMapShape3D). Construirla
	# igualmente era pagar generate_lods() dos veces sobre el mismo millon de
	# vertices -una para el conjunto, otra por cada trozo- para tirar la
	# primera entera: medido, 9-19 s regalados. Solo hace falta si no hay
	# trozos, o si el recuadro no es cuadrado y pide colision de verdad.
	var needs_trimesh_collision := generate_collision and terrain_chunks > 1 \
		and absf(step_x - step_z) >= 0.0001

	var tlod0 := Time.get_ticks_msec()
	var single_mesh: ArrayMesh = null
	if terrain_chunks <= 1:
		single_mesh = _mesh_with_lods(arrays)
	elif needs_trimesh_collision:
		# Caso raro -hoy no lo usa ninguna escena: colision pedida sobre un
		# recuadro troceado y no cuadrado. Una malla plana sin LODs basta para
		# un trimesh estatico; generate_lods() aqui seria trabajo tirado otra
		# vez, porque la colision no elige nivel de detalle.
		single_mesh = ArrayMesh.new()
		single_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	print("[TIMING]   _mesh_with_lods: %d ms" % (Time.get_ticks_msec() - tlod0))
	return single_mesh


## Aplica el material triplanar (o el basico de reserva) a `_terrain_mesh`.
## Comun al camino que genera desde cero y al que carga de cache: en los dos
## casos hace falta el mismo shader, y las texturas ya tienen su propia cache
## en [ProceduralTextureGenerator], asi que esto es barato en ambos.
func _apply_terrain_material() -> void:
	if use_triplanar_shader and not Engine.is_editor_hint():
		# Usar shader triplanar con texturas procedurales
		var manager_script := load("res://scripts/mundo/TerrainMaterialManager.gd")
		if manager_script:
			_material_manager = manager_script.new()
			var shader_material: ShaderMaterial = _material_manager.create_terrain_material()
			if shader_material:
				_apply_shader_height_setup()
				_material_manager.set_region_mask_enabled(
					heightmap != null and not heightmap.region_mask.is_empty())
				_terrain_mesh.material_override = shader_material
				print("Shader triplanar aplicado al terreno")
			else:
				# Fallback a material básico
				_apply_basic_material()
		else:
			push_warning("No se pudo cargar TerrainMaterialManager, usando material básico")
			_apply_basic_material()
	else:
		# Material básico con colores de vértice
		_apply_basic_material()


## Reconstruye lo que deja `_create_terrain_mesh()`, pero desde una cache ya
## valida en vez de recalcularlo: sin bucle de vertices, sin generate_lods.
func _create_terrain_mesh_from_cache(cache: TerrainGenerationCache) -> void:
	_terrain_mesh = MeshInstance3D.new()
	_terrain_mesh.name = "TerrainMesh"
	if terrain_chunks <= 1:
		_terrain_mesh.mesh = cache.single_mesh

	var tmat0 := Time.get_ticks_msec()
	_apply_terrain_material()
	print("[TIMING]   material/texturas de terreno: %d ms" % (Time.get_ticks_msec() - tmat0))

	add_child(_terrain_mesh)

	if terrain_chunks > 1:
		var tchunk0 := Time.get_ticks_msec()
		for i in range(cache.chunk_meshes.size()):
			var piece := MeshInstance3D.new()
			piece.name = "Trozo_%d" % i
			piece.mesh = cache.chunk_meshes[i]
			piece.material_override = _terrain_mesh.material_override
			_terrain_mesh.add_child(piece)
		print("[TIMING]   trozos desde cache (%d): %d ms" % [
			cache.chunk_meshes.size(), Time.get_ticks_msec() - tchunk0])

	var tcol0 := Time.get_ticks_msec()
	_create_collision(cache.single_mesh)
	print("[TIMING]   _create_collision: %d ms" % (Time.get_ticks_msec() - tcol0))


## Ruta de la cache de generacion para el heightmap actual, o "" si este
## terreno no es cacheable -procedural, o sin heightmap con ruta propia.
##
## Se deriva del propio fichero del heightmap: "site_9000.res" cachea en
## "site_9000_mesh_r825.res", al lado. Asi cada sitio tiene su cache, sin tener
## que inventar un id aparte, y coincide con donde ya vive "site_9000.res".
func _cache_base_path() -> String:
	if height_source != HeightSource.HEIGHTMAP or heightmap == null:
		return ""
	var src := heightmap.resource_path
	if src.is_empty():
		return ""
	return "%s/%s_mesh_r%d.res" % [src.get_base_dir(), src.get_file().get_basename(), resolution]


## Huella de las entalladuras actuales, para invalidar la cache si cambian
## -por ejemplo al fundar el mismo sitio en otra epoca, con otras cuevas
## excavadas en la malla.
func _carvings_hash() -> int:
	return hash(str(carvings))


## Huella del relieve inventado: lo que se anade por debajo de lo que mide el
## MDT. Ver [TerrainGenerationCache.detail_hash] para por que va todo junto.
func _detail_hash() -> int:
	# La amplitud EFECTIVA, no la del inspector: depende del paso del dato, asi
	# que el mismo sitio con MDT del IGN y con terrarium no comparten malla.
	return hash([_effective_detail_amplitude(), detail_frequency, detail_octaves,
		detail_slope_gain, detail_slope_max, shelf_relief_m])


## Si una cache ya cargada sigue describiendo lo que este generador pide ahora.
func _cache_matches(cache: TerrainGenerationCache) -> bool:
	return cache.version == TerrainGenerationCache.CACHE_VERSION \
		and cache.heightmap_pipeline_version == heightmap.pipeline_version \
		and cache.resolution == resolution \
		and cache.terrain_size == terrain_size \
		and cache.heightmap_region_offset == heightmap_region_offset \
		and is_equal_approx(cache.meters_per_unit, meters_per_unit) \
		and is_equal_approx(cache.vertical_exaggeration, vertical_exaggeration) \
		and is_equal_approx(cache.sea_level, sea_level) \
		and cache.terrain_chunks == terrain_chunks \
		and cache.carvings_hash == _carvings_hash() \
		and cache.detail_hash == _detail_hash() \
		and cache.height_map.size() == resolution * resolution \
		and (terrain_chunks > 1 or cache.single_mesh != null) \
		and (terrain_chunks <= 1 or cache.chunk_meshes.size() > 0)


## Carga la cache de disco si hay una y sigue describiendo este terreno.
func _load_generation_cache() -> TerrainGenerationCache:
	if not use_generation_cache:
		return null
	var path := _cache_base_path()
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var cache := ResourceLoader.load(path) as TerrainGenerationCache
	if cache == null or not _cache_matches(cache):
		return null
	return cache


## Guarda en disco lo que ha costado calcular, para no repetirlo la proxima
## vez que se cargue este mismo sitio. No hace nada si ya se cargo de cache
## -nada ha cambiado- ni si el terreno no tiene heightmap con ruta propia.
func _save_generation_cache(single_mesh: ArrayMesh, chunk_meshes: Array[ArrayMesh]) -> void:
	if _gen_cache != null or not use_generation_cache:
		return
	var path := _cache_base_path()
	if path.is_empty():
		return

	var cache := TerrainGenerationCache.new()
	cache.version = TerrainGenerationCache.CACHE_VERSION
	cache.heightmap_pipeline_version = heightmap.pipeline_version
	cache.resolution = resolution
	cache.terrain_size = terrain_size
	cache.heightmap_region_offset = heightmap_region_offset
	cache.meters_per_unit = meters_per_unit
	cache.vertical_exaggeration = vertical_exaggeration
	cache.sea_level = sea_level
	cache.terrain_chunks = terrain_chunks
	cache.carvings_hash = _carvings_hash()
	cache.detail_hash = _detail_hash()
	cache.height_map = _height_map
	cache.humidity_map = _humidity_map
	cache.geology_map = _geology_map
	cache.relief_map = _relief_map
	cache.river_map = _river_map
	cache.flow_map = _flow_map
	cache.ford_map = _ford_map
	cache.region_map = _region_map
	cache.height_range = _height_range
	cache.single_mesh = single_mesh
	cache.chunk_meshes = chunk_meshes

	var t0 := Time.get_ticks_msec()
	if ResourceSaver.save(cache, path) != OK:
		push_warning("No se pudo guardar la cache de generacion en " + path)
	else:
		print("[TIMING]   cache de generacion guardada (%s): %d ms" % [
			path, Time.get_ticks_msec() - t0])


func _create_collision(mesh: Mesh) -> void:
	if not generate_collision:
		return

	_terrain_collision = StaticBody3D.new()
	_terrain_collision.name = "TerrainCollision"
	# Capa 1 = "terrain" segun project.godot
	_terrain_collision.collision_layer = 1

	var collision_shape := CollisionShape3D.new()
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)

	if absf(step_x - step_z) < 0.0001:
		# HeightMapShape3D es la forma natural de un campo de alturas y evita
		# construir un ConcavePolygonShape3D con millones de triangulos, que
		# era la otra mitad del tiempo de generacion.
		var shape := HeightMapShape3D.new()
		shape.map_width = resolution
		shape.map_depth = resolution

		# La forma usa celdas de 1 unidad centradas en el origen, asi que hay
		# que escalar el nodo. La fisica no admite escalas no uniformes, por eso
		# las alturas se predividen por el paso en vez de escalar solo X y Z.
		var data := PackedFloat32Array()
		data.resize(_height_map.size())
		for i in range(_height_map.size()):
			data[i] = _height_map[i] / step_x
		shape.map_data = data

		collision_shape.shape = shape
		collision_shape.scale = Vector3.ONE * step_x
		collision_shape.position = Vector3(float(terrain_size.x) * 0.5, 0.0, float(terrain_size.y) * 0.5)
	else:
		# Terreno no cuadrado: no hay escala uniforme posible, se usa el trimesh
		collision_shape.shape = mesh.create_trimesh_shape()

	_terrain_collision.add_child(collision_shape)
	add_child(_terrain_collision)


func _apply_basic_material() -> void:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	_terrain_mesh.material_override = material


## Los mapas en crudo, para quien necesite HORNEARLOS en vez de consultarlos.
##
## Existe por [GroundCover]. La hierba se coloca en el shader, y para eso el
## shader necesita la altura y la cobertura como texturas: consultar el terreno
## una vez por brizna en GDScript son decenas de miles de llamadas y casi dos
## segundos de construcción, y además habría que repetirlas cada vez que la
## cámara se mueve. Con los mapas en la mano se hornean dos texturas UNA VEZ y
## la CPU deja de aparecer en la cuenta.
##
## Se devuelven las rejillas tal cual, sin copiar: son `PackedFloat32Array` y en
## GDScript se pasan por referencia con copia perezosa, así que esto no duplica
## varios megas cada vez que alguien pregunta.
func sample_maps() -> Dictionary:
	return {
		"resolution": resolution,
		# Metros de mundo que cubre la rejilla entera, que es lo que hace falta
		# para pasar de una posición del mundo a una coordenada de textura.
		"extent": Vector2(float(terrain_size.x), float(terrain_size.y))
			* meters_per_unit,
		"origin": Vector2(global_position.x, global_position.z),
		"height": _height_map,
		"humidity": _humidity_map,
		"geology": _geology_map,
		"river": _river_map,
		"ford": _ford_map,
		# La cota de la lámina de agua, en las MISMAS unidades que el mapa de
		# alturas. Va aquí porque quien siembra algo sobre el terreno necesita
		# saber dónde deja de haber terreno: sin esto la hierba entraba en la ría.
		"water_y": _to_units(sea_level),
	}


## Obtiene la altura en una posición del mundo
func get_height_at(world_pos: Vector3) -> float:
	if _height_map.is_empty():
		return 0.0

	# Fuera de los limites se usa el borde mas cercano. Devolver 0.0 creaba un
	# acantilado falso en todo el perimetro: la pendiente se disparaba y el mapa
	# se llenaba de piedra en los bordes ademas de bloquear la construccion.
	var local_x := clampf(world_pos.x - global_position.x, 0.0, float(terrain_size.x))
	var local_z := clampf(world_pos.z - global_position.z, 0.0, float(terrain_size.y))
	
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	
	var grid_x := local_x / step_x
	var grid_z := local_z / step_z
	
	var x0 := clampi(int(floor(grid_x)), 0, resolution - 1)
	var z0 := clampi(int(floor(grid_z)), 0, resolution - 1)
	var x1 := mini(x0 + 1, resolution - 1)
	var z1 := mini(z0 + 1, resolution - 1)
	
	var fx := grid_x - x0
	var fz := grid_z - z0
	
	# Interpolación bilineal
	var h00 := _height_map[z0 * resolution + x0]
	var h10 := _height_map[z0 * resolution + x1]
	var h01 := _height_map[z1 * resolution + x0]
	var h11 := _height_map[z1 * resolution + x1]
	
	var h0 := lerpf(h00, h10, fx)
	var h1 := lerpf(h01, h11, fx)

	# El mapa ya esta en metros
	return lerpf(h0, h1, fz)


## Altura normalizada 0-1 en una posicion, respecto al rango real del terreno
func get_normalized_height_at(world_pos: Vector3) -> float:
	return _normalize_height(get_height_at(world_pos))


## Convierte una coordenada geografica a posicion de mundo sobre este terreno.
## La latitud se interpola en Y de Mercator, que es como esta muestreado el DEM.
func geo_to_world(lon: float, lat: float) -> Vector3:
	if heightmap == null:
		return Vector3.ZERO

	var lon_span := heightmap.lon_east - heightmap.lon_west
	if absf(lon_span) < 1e-9:
		return Vector3.ZERO

	var u := heightmap.u_for_lon(lon)
	var v := heightmap.v_for_lat(lat)

	var size_m := heightmap.get_world_size_meters()
	var x := (u * size_m.x - heightmap_region_offset.x) / meters_per_unit
	var z := (v * size_m.y - heightmap_region_offset.y) / meters_per_unit
	return Vector3(x, get_height_at(Vector3(x, 0.0, z)), z)


## Cambia la mascara de region jugable sin regenerar nada
func set_region_mask_texture(texture: Texture2D) -> void:
	if _material_manager == null:
		return
	_material_manager.set_region_mask_texture(
		texture, Vector2(float(terrain_size.x), float(terrain_size.y)))
	_material_manager.set_region_mask_enabled(texture != null)


## Rango real de altura del terreno en metros (min, max)
## El material del terreno, para quien quiera pintarle algo encima.
##
## Lo usa el overlay de recursos: en vez de sembrar el mundo de nodos, le pasa
## una textura y deja que el shader la mezcle con el albedo.
## Las mallas del terreno, para quien necesite volver a dibujarlas aparte.
##
## Existe por [GroundCover], que hornea el color del terreno fotografiándolo
## desde arriba con su propio material. Es la única forma de saber de qué color
## es el suelo SIN aproximarlo: el sombreado del terreno mezcla ocho capas por
## curvatura, pendiente y ruido, les aplica oclusión, macro variación y el
## apagado de fuera de región, y reproducir todo eso en GDScript sería duplicar
## medio shader y verlo desincronizarse al primer cambio.
##
## Se devuelven los nodos, no copias: quien los use que los duplique.
func mesh_pieces() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if _terrain_mesh == null:
		return out
	# El nodo raiz lleva malla en el modo de una pieza, y en el troceado no:
	# ahi solo es el padre de los trozos.
	if _terrain_mesh.mesh != null:
		out.append(_terrain_mesh)
	for child in _terrain_mesh.get_children():
		var piece := child as MeshInstance3D
		if piece != null and piece.mesh != null:
			out.append(piece)
	return out


func get_terrain_material() -> ShaderMaterial:
	if _material_manager == null:
		return null
	return _material_manager.get_material()


func get_height_range() -> Vector2:
	return _height_range


## El ruido de variacion a escala de decenas de metros.
##
## Lo comparte el contorno para que las manchas de pasto y matorral CRUCEN la
## costura: si cada malla usara su propio ruido, el borde del recuadro se
## leeria como un cambio de tapiz aunque las cotas encajaran al milimetro.
func get_macro_noise() -> FastNoiseLite:
	return _macro_noise


## Techo contra el que el shader normaliza la altura, en unidades de mundo.
var _shader_ceiling: float = 0.0


## Sube el techo de normalizacion del shader para que quepa terreno mas alto.
##
## El shader convierte la cota en fraccion dividiendo por `max_world_height` y
## SATURA lo que se pase. El techo se fijaba con el punto mas alto del recuadro
## jugable, asi que las casillas de alrededor -que llegan mas arriba, porque
## alrededor hay monte- saturaban enteras y se pintaban de roca: eran la franja
## tostada que no cuadraba con el verde de dentro.
##
## Subir el techo a secas correria todas las bandas hacia abajo y cambiaria el
## aspecto del terreno jugable. Por eso se reescalan a la vez: el techo sube
## por 1/k y las bandas por k, asi que cada cota absoluta se queda exactamente
## en la banda en la que estaba.
func extend_height_ceiling(new_top: float) -> void:
	if _material_manager == null:
		return
	if _shader_ceiling <= 0.0 or new_top <= _shader_ceiling:
		return

	var k := _shader_ceiling / new_top
	_shader_ceiling = new_top
	_material_manager.set_max_world_height(new_top)
	_material_manager.scale_height_bands(k)
	print("Techo del shader subido a %.1f unidades (bandas x%.3f)" % [new_top, k])


## True si la posicion queda bajo el nivel del mar.
## sea_level se declara en METROS; las alturas van en unidades de mundo.
## Dificultad de cruzar el agua en un punto del mundo: 0 en seco y creciendo
## con el calado. Ver los umbrales de [Hydrography].
##
## Es lo que convierte el rio en obstaculo en vez de en textura: sin esto la
## gente cruzaba el Nansa en linea recta como si no estuviera.
func crossing_difficulty_at(world_pos: Vector3) -> float:
	if _ford_map.is_empty() or resolution <= 1:
		return 0.0

	var x := clampi(int(round(world_pos.x / float(terrain_size.x) * float(resolution - 1))),
		0, resolution - 1)
	var z := clampi(int(round(world_pos.z / float(terrain_size.y) * float(resolution - 1))),
		0, resolution - 1)
	return _ford_map[z * resolution + x]


## Si un trayecto recto se puede recorrer a pie de principio a fin.
##
## Mira las DOS cosas que cortan el paso: el agua que no se vadea y la
## pendiente que no se sube. Antes solo se miraba el agua, y desde que la
## pendiente tambien bloquea eso dejaba elegir tajos al otro lado de un
## cortado, adonde la gente salia andando para quedarse atascada contra la
## pared.
func path_is_passable(from_pos: Vector3, to_pos: Vector3,
		has_boat: bool, has_bridge: bool) -> bool:
	var span := float(terrain_size.x) / float(maxi(resolution - 1, 1))
	var steps := maxi(int(from_pos.distance_to(to_pos) / maxf(span, 0.5)), 1)
	for s in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(s) / float(steps))
		if not Traversal.is_passable(get_slope_at(point),
				crossing_difficulty_at(point), has_boat, has_bridge):
			return false
	return true


## Qué fracción de un trayecto recto es transitable, de 0 a 1.
##
## Existe porque `path_is_passable` es demasiado estricto para una batida de
## reconocimiento. Sobre terreno real, una recta de un kilómetro casi siempre
## toca alguna celda con demasiada pendiente, así que exigirla limpia entera
## dejaba a los exploradores sin ningún destino válido: se quedaban parados en
## el campamento y el mapa no se abría.
##
## Para ir al tajo todos los días sí hay que poder ir en recta. Para explorar
## no: un batidor rodea el obstáculo, que es justo su trabajo.
func passable_fraction(from_pos: Vector3, to_pos: Vector3,
		has_boat: bool, has_bridge: bool) -> float:
	var span := float(terrain_size.x) / float(maxi(resolution - 1, 1))
	# Un paso cada varias celdas: aqui interesa la forma general del camino,
	# no cada piedra, y muestrear fino cuesta mucho por candidato
	var steps := maxi(int(from_pos.distance_to(to_pos) / maxf(span * 4.0, 1.0)), 1)
	var clear := 0
	for s in range(steps + 1):
		var point := from_pos.lerp(to_pos, float(s) / float(steps))
		if Traversal.is_passable(get_slope_at(point),
				crossing_difficulty_at(point), has_boat, has_bridge):
			clear += 1
	return float(clear) / float(steps + 1)


## Peor punto de cruce en un trayecto recto entre dos puntos del mundo.
##
## Se queda con el peor y no con la media: cien metros de vado no compensan
## veinte de rio, porque lo que decide si se puede pasar es el punto peor.
func worst_crossing_between(from_pos: Vector3, to_pos: Vector3) -> float:
	if _ford_map.is_empty():
		return 0.0

	var span := float(terrain_size.x) / float(maxi(resolution - 1, 1))
	var steps := maxi(int(from_pos.distance_to(to_pos) / maxf(span, 0.5)), 1)
	var worst := 0.0
	for s in range(steps + 1):
		worst = maxf(worst, crossing_difficulty_at(
			from_pos.lerp(to_pos, float(s) / float(steps))))
	return worst


func is_underwater(world_pos: Vector3) -> bool:
	return get_height_at(world_pos) <= _to_units(sea_level)


## Configura las bandas de altura del shader segun la fuente de altura
func _apply_shader_height_setup() -> void:
	if _material_manager == null:
		return

	if height_source == HeightSource.HEIGHTMAP and heightmap:
		var top := maxf(_height_range.y, 0.001)
		_material_manager.set_max_world_height(top)
		_shader_ceiling = top
		# Bandas en cotas reales, convertidas a la fraccion que espera el
		# shader. Se exponen como export porque la capa local y la regional
		# necesitan valores muy distintos: 140 m es "monte" en un valle y
		# "llanura" en un mapa que llega a 2600 m.
		if bands_relative:
			# Fracciones del rango propio del recuadro: arena solo en la orilla
			# y el grueso del mapa como pasto, dejando que la roca la ponga la
			# pendiente a traves de slope_threshold.
			var floor_h := _height_range.x
			var span := maxf(_height_range.y - floor_h, 0.001)
			var shore := clampf(
				(_to_units(band_sea_level_m + shore_band_m) - floor_h) / span,
				0.0, 1.0)
			# La nieve se manda fuera de rango (2.0, con la altura normalizada
			# en 0..1) en vez de dejarla en 0.995: smoothstep abre la banda 0.1
			# a cada lado, asi que un 0.995 pintaba de nieve el 10% mas alto del
			# recuadro. A 300 m en Cantabria no hay nieve, y su roughness 0.55
			# era la mitad del brillo raro de las cumbres.
			#
			# El techo de roca sube a 1.5 por lo mismo: con 0.97 la roca se
			# apagaba justo donde entraba esa nieve fantasma.
			_material_manager.set_height_bands(shore, 0.86, 0.74, 1.5, 2.0)
		else:
			_material_manager.set_height_bands(
				clampf(_to_units(band_sea_level_m + shore_band_m) / top, 0.0, 1.0),
				clampf(_to_units(band_sea_level_m + grass_top_m) / top, 0.0, 1.0),
				clampf(_to_units(band_sea_level_m + rock_base_m) / top, 0.0, 1.0),
				0.93,
				clampf(_to_units(band_sea_level_m + snow_base_m) / top, 0.0, 1.0))
	else:
		_material_manager.set_max_world_height(max_height)


## Crea (o rehace) el plano de agua al nivel del mar
func _create_water() -> void:
	if _water_mesh:
		_water_mesh.queue_free()
		_water_mesh = null

	# Sin nada bajo el nivel del mar no hay costa que dibujar
	var water_y := _to_units(sea_level)
	if not show_water or _height_range.x > water_y:
		return

	var plane := PlaneMesh.new()
	plane.size = Vector2(float(terrain_size.x), float(terrain_size.y))
	plane.subdivide_width = 32
	plane.subdivide_depth = 32

	_water_mesh = MeshInstance3D.new()
	_water_mesh.name = "Water"
	_water_mesh.mesh = plane
	# Un pelo por encima de la cota. Los datos terrarium cuantizan y dejan
	# muchisimas celdas a exactamente 0,0 m: coplanares con la lamina, el test
	# de profundidad no puede decidir cual esta delante y sale a bandas.
	var epsilon := maxf(float(terrain_size.x) * 0.00004, 0.05)
	_water_mesh.position = Vector3(
		float(terrain_size.x) * 0.5, water_y + epsilon, float(terrain_size.y) * 0.5)

	var material := StandardMaterial3D.new()
	material.albedo_color = water_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.25
	material.roughness = 0.06
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_mesh.material_override = material

	add_child(_water_mesh)


## Obtiene la humedad en una posición del mundo (0-1)
func get_humidity_at(world_pos: Vector3) -> float:
	return _get_map_value_at(world_pos, _humidity_map)


## Obtiene la mascara de relieve en una posicion (0 = llanura, 1 = montana)
func get_relief_at(world_pos: Vector3) -> float:
	return _get_map_value_at(world_pos, _relief_map)


## Obtiene el valor de geología en una posición del mundo (0-1)
func get_geology_at(world_pos: Vector3) -> float:
	return _get_map_value_at(world_pos, _geology_map)


func _get_map_value_at(world_pos: Vector3, map: PackedFloat32Array) -> float:
	if map.is_empty():
		return 0.0
	
	# Igual que get_height_at: recortar al borde en vez de devolver 0.0
	var local_x := clampf(world_pos.x - global_position.x, 0.0, float(terrain_size.x))
	var local_z := clampf(world_pos.z - global_position.z, 0.0, float(terrain_size.y))
	
	var step_x := float(terrain_size.x) / float(resolution - 1)
	var step_z := float(terrain_size.y) / float(resolution - 1)
	
	var x := clampi(int(local_x / step_x), 0, resolution - 1)
	var z := clampi(int(local_z / step_z), 0, resolution - 1)
	
	return map[z * resolution + x]


## Calcula la pendiente (slope) en una posición del mundo
## Devuelve el gradiente en metros de altura por metro horizontal.
func get_slope_at(world_pos: Vector3) -> float:
	# Diferencias centradas: la version anterior usaba diferencia hacia adelante,
	# que sesga la pendiente medio paso y la sobreestima en terreno ruidoso.
	const D := 1.0
	var hx0 := get_height_at(world_pos - Vector3(D, 0, 0))
	var hx1 := get_height_at(world_pos + Vector3(D, 0, 0))
	var hz0 := get_height_at(world_pos - Vector3(0, 0, D))
	var hz1 := get_height_at(world_pos + Vector3(0, 0, D))
	
	var dx := (hx1 - hx0) / (2.0 * D)
	var dz := (hz1 - hz0) / (2.0 * D)
	
	return sqrt(dx * dx + dz * dz)

func get_vegetation_positions(min_humidity: float = 0.4, max_slope: float = 0.5, spacing: float = 3.0) -> PackedVector3Array:
	var positions: PackedVector3Array = []
	
	var step := maxf(spacing, 0.1)
	
	# Jitter determinista: sin él los árboles quedaban en una rejilla perfecta
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 4000
	
	var x := 0.0
	while x < terrain_size.x:
		var z := 0.0
		while z < terrain_size.y:
			var px := clampf(x + rng.randf() * step, 0.0, float(terrain_size.x))
			var pz := clampf(z + rng.randf() * step, 0.0, float(terrain_size.y))
			var world_pos := Vector3(px, 0, pz) + global_position
			var humidity := get_humidity_at(world_pos)
			var slope := get_slope_at(world_pos)
			
			if humidity >= min_humidity and slope <= max_slope:
				var h := get_height_at(world_pos)
				# Nada de arboles en el mar. El resto del filtro por altura lo
				# aplica el consumidor con sus propios umbrales
				# (MultiMeshVegetation.min_height/max_height_normalized).
				if h > _to_units(sea_level):
					positions.append(Vector3(px, h, pz) + global_position)
			
			z += step
		x += step
	
	return positions


## Malla con niveles de detalle generados, o la de siempre si no se puede.
func _mesh_with_lods(arrays: Array) -> ArrayMesh:
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if not importer.has_method("generate_lods"):
		var plain := ArrayMesh.new()
		plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return plain

	importer.generate_lods(25.0, 60.0, [])
	return importer.get_mesh()


## Parte la malla del terreno en una rejilla de trozos.
##
## Cada trozo se construye rebanando los MISMOS arrays de vertices que ya se
## han calculado, asi que ni el relieve ni las normales ni el agua cambian en
## nada: es la misma superficie, dibujada en cuadros.
##
## Los trozos COMPARTEN la fila y la columna del borde -de ahi el `<=` en los
## bucles-, que es lo que evita que se abra una grieta entre cuadros: los
## vertices del limite son literalmente los mismos, con la misma cota y la
## misma normal.
func _split_into_chunks(arrays: Array) -> Array[ArrayMesh]:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]

	var per_chunk := int(ceil(float(resolution - 1) / float(terrain_chunks)))
	var made := 0
	# En el mismo orden en que se crean, para poder recrearlos identicos desde
	# cache sin tener que guardar tambien sus coordenadas de trozo.
	var built: Array[ArrayMesh] = []

	for cz in range(terrain_chunks):
		for cx in range(terrain_chunks):
			var x0 := cx * per_chunk
			var z0 := cz * per_chunk
			var x1 := mini(x0 + per_chunk, resolution - 1)
			var z1 := mini(z0 + per_chunk, resolution - 1)
			if x1 <= x0 or z1 <= z0:
				continue

			var wide := x1 - x0 + 1
			var tall := z1 - z0 + 1
			var count := wide * tall

			var cv := PackedVector3Array()
			var cn := PackedVector3Array()
			var ct := PackedFloat32Array()
			var cc := PackedColorArray()
			var cu := PackedVector2Array()
			var cu2 := PackedVector2Array()
			cv.resize(count)
			cn.resize(count)
			ct.resize(count * 4)
			cc.resize(count)
			cu.resize(count)
			cu2.resize(count)

			for z in range(tall):
				for x in range(wide):
					var src := (z0 + z) * resolution + (x0 + x)
					var dst := z * wide + x
					cv[dst] = vertices[src]
					cn[dst] = normals[src]
					cc[dst] = colors[src]
					cu[dst] = uvs[src]
					cu2[dst] = uv2s[src]
					for k in range(4):
						ct[dst * 4 + k] = tangents[src * 4 + k]

			var ci := PackedInt32Array()
			ci.resize((wide - 1) * (tall - 1) * 6)
			var i := 0
			for z in range(tall - 1):
				for x in range(wide - 1):
					var top_left := z * wide + x
					var top_right := top_left + 1
					var bottom_left := top_left + wide
					var bottom_right := bottom_left + 1
					ci[i] = top_left
					ci[i + 1] = top_right
					ci[i + 2] = bottom_left
					ci[i + 3] = top_right
					ci[i + 4] = bottom_right
					ci[i + 5] = bottom_left
					i += 6

			var chunk_arrays := []
			chunk_arrays.resize(Mesh.ARRAY_MAX)
			chunk_arrays[Mesh.ARRAY_VERTEX] = cv
			chunk_arrays[Mesh.ARRAY_NORMAL] = cn
			chunk_arrays[Mesh.ARRAY_TANGENT] = ct
			chunk_arrays[Mesh.ARRAY_COLOR] = cc
			chunk_arrays[Mesh.ARRAY_TEX_UV] = cu
			chunk_arrays[Mesh.ARRAY_TEX_UV2] = cu2
			chunk_arrays[Mesh.ARRAY_INDEX] = ci

			var piece_mesh := _mesh_with_lods(chunk_arrays)
			var piece := MeshInstance3D.new()
			piece.name = "Trozo_%d_%d" % [cx, cz]
			piece.mesh = piece_mesh
			# `material_override` NO se hereda de un nodo padre a sus hijos:
			# sin esta linea los trozos salen con el material de serie, que es
			# blanco liso. Es el mismo recurso para todos, asi que cambiarlo
			# -las bandas de altura, la mascara de region, el overlay- sigue
			# afectando a los sesenta y cuatro a la vez.
			piece.material_override = _terrain_mesh.material_override
			_terrain_mesh.add_child(piece)
			built.append(piece_mesh)
			made += 1

	print("Terreno en %d trozos de %d x %d vertices" % [made, per_chunk + 1, per_chunk + 1])
	return built


## Rehace SOLO las bandas de material, sin tocar la malla.
##
## Existe porque el nivel del mar cambia de epoca en epoca y regenerar el
## terreno entero por eso seria pagar varios segundos por cambiar cuatro
## numeros de un shader.
func refresh_material_bands(sea_level_meters: float) -> void:
	band_sea_level_m = sea_level_meters

	# Antes de generar, el rango de alturas todavia es cero. Aplicar las
	# bandas ahi ponia el techo del shader en 0,001, con lo que TODA cota
	# normalizaba por encima de la banda de nieve y el mapa entero salia de
	# roca gris. La epoca se aplica al abrir el mapa, antes de que el terreno
	# exista, asi que este caso no es raro: es el primero que pasa.
	if _height_range.y <= _height_range.x:
		return
	_apply_shader_height_setup()
