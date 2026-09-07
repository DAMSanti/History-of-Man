extends Node3D
## Demo principal que integra todos los sistemas:
## TerrainGenerator, Chunk, Architecto y WorldEnvironment

@export_group("Demo Settings")
@export var terrain_size: Vector2i = Vector2i(2048, 2048)
@export var terrain_resolution: int = 513
@export var max_height: float = 30.0
@export var seed_value: int = 12345

@export_group("Terreno real")
## Usar elevacion real importada en vez del generador procedural
@export var use_real_terrain: bool = true

## Heightmap a cargar cuando use_real_terrain esta activo
@export var heightmap_path: String = "res://data/dem/cantabria_costa.res"

## Esquina del recuadro del DEM que se renderiza, en metros.
## (3000, 0) abarca 7 km de lado: costa cantabrica al norte, la ria de San
## Martin de la Arena y el interior montanoso.
@export var region_offset: Vector2 = Vector2(3000, 0)

## Cota del mar en metros. El cero del DEM es el nivel del mar real, pero la
## ria de San Martin es un estuario MAREAL y el dato de terrarium (13.9 m por
## muestra) no resuelve el canal: su lecho oscila entre -2.8 y +2.2 m. Con el
## plano a 0 exacto el fondo asoma a trozos y la ria parece tierra parcheada.
## A 2 m el estuario queda inundado, que es su estado en pleamar.
@export var sea_level: float = 2.0

@export_group("Debug")
## El panel de depuracion de la esquina. Apagado: lo que decia esta ahora en
## las pestanas -fecha y estado en Cronica, controles en su propio boton- y en
## la esquina solo estorbaba la vista del terreno.
@export var show_debug_ui: bool = false
@export var spawn_test_buildings: bool = true

## Referencias a nodos
var terrain: TerrainGenerator
var chunk: Chunk
var architecto: Architecto
var camera: OrbitalCamera
var debug_label: Label
var sim: SettlementSim
var band_label: Label
var _minimap: TextureRect
var _minimap_base: Image
var _minimap_clear: Image
var _minimap_frame: Image
var field: ResourceField
var knowledge: BandKnowledge
var herds: WildlifeHerds
var props: ResourceProps
## Si se siembra hierba de detalle. Ver dónde se monta para el porqué de que
## venga apagada.
@export var ground_cover := false

var cover: GroundCover
var forest: Forest

## Capas del overlay que no son una actividad concreta
const OVERLAY_OFF := -1
const OVERLAY_KNOWN := -2

## Capa que se esta mirando: una actividad, o una de las dos de arriba
var _overlay_activity: int = OVERLAY_OFF
var _overlay_label: Label
var _minimap_canvas: CanvasLayer

## Textura del overlay de recursos sobre el terreno. Una sola imagen para todo
## el recuadro en vez de miles de nodos: ver `_refresh_resource_overlay`.
var _overlay_image: Image
var _overlay_texture: ImageTexture
var tech: TechTree
var ui: GameUI

## El recuento de lo que hay pintado en el mundo, para la pestaña de
## Entidades. Ver [EntityCensus].
var census: EntityCensus

## Con el modo construccion activo el clic levanta en vez de seleccionar
var _build_mode: bool = false

## Bocas de cueva y demas elementos pinchables del mundo
var _caves: Array[CaveMouth] = []

## Marcadores de recurso en el mundo 3D, agrupados por actividad

## Marcadores de los sitios con nombre. Ver [ParajeMarkers].
var paraje_markers: ParajeMarkers
var trail_view: TrailView
var trap_markers: TrapMarkers

## Las nasas caladas en la orilla. Ver [NasaMarkers].
var nasa_markers: NasaMarkers

## La hoguera en la boca de la cueva. Ver [HearthFire].
var hearth_fire: HearthFire

## Las hogueras de vivac de quien duerme fuera. Ver [BivouacFires].
var bivouac_fires: BivouacFires

## Lo que está haciendo cada cual, sobre su cabeza. Ver [WorkMarkers].
var craft_markers: WorkMarkers
var weather_view: WeatherView
var nav_overlay: NavOverlay

## Materiales cargados
var materials: Dictionary = {}

## Bloques constructivos cargados desde buildings/, indexados por categoria
var blocks: Dictionary = {}

## Dimensiones de la cabana de demostracion, en metros
const HUT_SIZE := 3.0
const HUT_HEIGHT := 2.2


## Cronometra una fase de _ready() y la imprime con el prefijo [TIMING], para
## poder ver de un vistazo en que se va el tiempo de carga del mapa local sin
## tener que perfilar a mano cada vez. Ver tambien las marcas internas de
## [TerrainGenerator.generate].
var _phase_t0: int = 0

func _phase_start() -> void:
	_phase_t0 = Time.get_ticks_msec()

func _phase_end(label: String) -> void:
	print("[TIMING] %s: %d ms" % [label, Time.get_ticks_msec() - _phase_t0])


func _ready() -> void:
	var t_ready0 := Time.get_ticks_msec()
	print("=== Iniciando Demo ===")
	_phase_start(); _apply_expedition(); _phase_end("_apply_expedition")
	_phase_start(); _load_materials(); _phase_end("_load_materials")
	_phase_start(); _load_blocks(); _phase_end("_load_blocks")
	_phase_start(); _setup_terrain(); _phase_end("_setup_terrain")
	_phase_start(); _setup_chunk(); _phase_end("_setup_chunk")
	# Vegetacion desactivada: los arboles se colocaban con base_scale de 1
	# unidad sobre un mapa donde 1 unidad = 1 m, o sea arbolitos de un metro
	# que desde la camara solo se leian como manchas oscuras en el suelo.
	# Vuelve cuando haya especies de verdad con porte y altura por era.
	_phase_start(); _setup_architecto(); _phase_end("_setup_architecto")
	_phase_start(); _setup_camera(); _phase_end("_setup_camera")
	_phase_start(); _setup_ui(); _phase_end("_setup_ui")
	_phase_start(); _setup_performance_overlay(); _phase_end("_setup_performance_overlay")
	_phase_start(); _connect_signals(); _phase_end("_connect_signals")

	# Las bocas de cueva se excavan en la malla ANTES de generarla
	_phase_start(); _mark_cave_carvings(); _phase_end("_mark_cave_carvings")

	# Generar mundo
	print("Generando terreno...")
	_phase_start()
	terrain.generate()
	_phase_end("terrain.generate (mapa jugable)")
	print("Terreno generado. Mesh: ", terrain._terrain_mesh)

	# Las ocho casillas de alrededor, en gris: sin ellas el mapa se corta a
	# cuchillo y detras no hay nada
	_phase_start(); _build_surroundings(); _phase_end("_build_surroundings (8 casillas)")

	# Ahora si: el minimapa se pinta del relieve ya generado
	if _minimap_canvas:
		_phase_start(); _build_minimap(_minimap_canvas); _phase_end("_build_minimap")

	# Poblar recursos

	# Visualizar recursos

	# Elementos reales del emplazamiento: cuevas, yacimientos, ruinas
	_phase_start(); _place_site_features(); _phase_end("_place_site_features")

	# La gente. El mapa local corre por dias; el regional, por estaciones.
	_phase_start(); _start_settlement(); _phase_end("_start_settlement")

	# Spawn edificios de prueba
	if spawn_test_buildings:
		_phase_start(); _spawn_test_buildings(); _phase_end("_spawn_test_buildings")

	print("[TIMING] === _ready() TOTAL: %d ms ===" % (Time.get_ticks_msec() - t_ready0))
	print("=== Demo inicializado correctamente ===")


## Toma los datos que dejo el mapa regional al fundar.
##
## Si no hay expedicion en curso la escena arranca con sus valores por defecto,
## para poder abrirla suelta durante el desarrollo.
func _apply_expedition() -> void:
	if not Expedition.is_active():
		print("Sin expedicion: se usa el recuadro por defecto")
		return

	use_real_terrain = true
	heightmap_path = Expedition.heightmap_path
	region_offset = Expedition.region_offset
	sea_level = Expedition.sea_level_m
	terrain_size = Vector2i(Expedition.local_size_m, Expedition.local_size_m)

	print("Expedicion: %s  (%.4f N, %.4f E)  mar %+.0f m" % [
		Expedition.site.display_name(), Expedition.site.lat, Expedition.site.lon,
		Expedition.sea_level_m])


## Marca en el terreno las entalladuras de las bocas de cueva.
##
## Se hace antes de generar porque la excavacion altera el heightmap y con el
## se construyen la malla, las normales y la colision.
func _mark_cave_carvings() -> void:
	if not Expedition.is_active() or terrain == null:
		return

	var marked := 0
	for f: Dictionary in Expedition.site.features_in(Expedition.era):
		if int(f.get("class", Site.Feature.OTRO)) != Site.Feature.ABRIGO:
			continue
		var world := terrain.geo_to_world(f.get("lon", 0.0), f.get("lat", 0.0))
		if world.x < 0.0 or world.z < 0.0 				or world.x > terrain_size.x or world.z > terrain_size.y:
			continue
		# Mas honda y algo mas estrecha que antes. La entalladura es la CUEVA:
		# lo que se ve como hueco lo hace el terreno, no la geometria que se
		# pone encima, y con 5 m de profundidad la oscuridad sobresalia y
		# parecia un bulto pegado a la ladera.
		terrain.carvings.append({
			"position": world,
			"radius": 13.0,
			"depth": 9.0,
		})
		marked += 1
	print("Bocas de cueva excavadas en la malla: %d" % marked)


## Coloca los elementos reales que caen dentro de este recuadro.
##
## Sin esto el mapa detallado es terreno anonimo: entras en Altamira y no ves
## Altamira. Las coordenadas son las del registro, no inventadas, asi que la
## boca de la cueva cae donde esta de verdad.
func _place_site_features() -> void:
	if not Expedition.is_active() or terrain == null:
		return

	var root := Node3D.new()
	root.name = "Elementos"
	add_child(root)

	var placed := 0
	# Solo lo que YA EXISTE en la epoca. Un dolmen o una ermita los levanto
	# alguien despues: no son elementos del terreno, son prueba de ocupacion
	# posterior y se cuentan aparte, en las atestiguaciones del emplazamiento.
	for f: Dictionary in Expedition.site.features_in(Expedition.era):
		# Las simas no se pintan: son pozos verticales de catalogo
		# espeleologico, no sitios que le importen al jugador. Siguen en los
		# datos porque senalan karst, que es pista de exploracion.
		if int(f.get("class", Site.Feature.OTRO)) == Site.Feature.SIMA:
			continue

		var world := terrain.geo_to_world(f.get("lon", 0.0), f.get("lat", 0.0))
		# Puede caer fuera del recuadro de 4 km aunque este a menos de 2 km
		# del centro, porque el recuadro es cuadrado y el radio circular
		if world.x < 0.0 or world.z < 0.0 				or world.x > terrain_size.x or world.z > terrain_size.y:
			continue

		var is_cave: bool = int(f.get("class", Site.Feature.OTRO)) == Site.Feature.ABRIGO

		# Una boca de cueva no está dentro del río. Si la coordenada cae en
		# agua es porque el cauce de hoy no es el de hace veinte mil años —el
		# meandro se ha movido, o el catálogo redondea— así que se aparta a la
		# orilla seca más cercana en vez de dejarla flotando en la corriente.
		if is_cave:
			world = _nudge_out_of_water(world)

		# La altura la da el terreno YA excavado, para que el vano se apoye
		# en el fondo de la entalladura
		world.y = terrain.get_height_at(world)

		if is_cave:
			# Boca construida contra la ladera y orientada cuesta abajo, que es
			# como se abre una cueva. La media esfera mirando al cielo que
			# habia aqui parecia un agujero pintado en el suelo.
			var cave := CaveMouth.new()
			root.add_child(cave)
			cave.build(terrain, world, f)
			_caves.append(cave)
			placed += 1
			continue

		# El resto de elementos naturales -manantiales, cavidades sin
		# clasificar- siguen siendo un jalon, que es lo que son: una senal
		var marker := MeshInstance3D.new()
		var material := StandardMaterial3D.new()
		var post := CylinderMesh.new()
		post.top_radius = 0.4
		post.bottom_radius = 1.6
		post.height = 14.0
		marker.mesh = post
		marker.position = world + Vector3(0, 7.0, 0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.72, 0.25)
		marker.material_override = material
		root.add_child(marker)

		var name: String = f.get("name", "")
		if name != "sin nombre" and not name.is_empty():
			var label := Label3D.new()
			label.text = name
			label.position = world + Vector3(0, 26.0, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.pixel_size = 0.06
			label.modulate = Color(1, 1, 1)
			label.outline_size = 8
			root.add_child(label)

		placed += 1

	print("Elementos del emplazamiento colocados: %d de %d" % [
		placed, Expedition.site.features.size()])


## Levanta el asentamiento con la gente de la partida
func _start_settlement() -> void:
	if not Expedition.is_active() or terrain == null:
		return

	var home := terrain.geo_to_world(Expedition.site.lon, Expedition.site.lat)

	sim = SettlementSim.new()
	sim.name = "Asentamiento"
	add_child(sim)

	# El setup va PRIMERO porque asignar los tajos ya necesita saber si se
	# llega a ellos, y eso lo decide el terreno que se le pasa aqui
	sim.setup(terrain, home, GameState.population, GameState.food)
	sim.day_passed.connect(_on_day_passed)

	# Lo que el valle tiene, repartido en manchas y con su estacion
	field = ResourceMapper.build(terrain, home)

	# Y lo que la banda sabe de ello, que al llegar es nada. Sabe que en el rio
	# hay peces; no sabe en que remanso. Eso lo aprende pisandolo.
	# El diario de la partida. Va aqui y no dentro de la simulacion porque lo
	# comparten los dos: la simulacion lo escribe y la interfaz lo lee.
	# Los marcadores de paraje: el asa por la que el jugador agarra un sitio.
	# Sin ellos los parajes existen pero no se pueden pinchar, y no poder
	# pincharlos es seguir mandando con numeros en una pestana.
	paraje_markers = ParajeMarkers.new()
	paraje_markers.name = "Parajes"
	add_child(paraje_markers)
	paraje_markers.setup(camera, sim, terrain)

	# Y el visor de rastros: por donde ha andado la banda y que ha hecho en
	# cada sitio. No es una capa de la partida sino la herramienta para mirar
	# el juego por dentro, que es lo unico que distingue afinar de adivinar.
	# Las trampas puestas se ven en el monte: son lo unico que la banda deja
	# PLANTADO en el mapa, y sin verlas la linea de trampas es un numero.
	trap_markers = TrapMarkers.new()
	trap_markers.name = "Trampas"
	add_child(trap_markers)

	# Y las nasas caladas, por lo mismo: son la otra cosa que la banda deja
	# puesta en el mapa, y sin verlas la linea de nasas es otro numero.
	nasa_markers = NasaMarkers.new()
	nasa_markers.name = "Nasas"
	add_child(nasa_markers)

	# Y lo que está haciendo cada cual, encima de su cabeza: sin esto quien
	# trabaja y quien da vueltas se ven exactamente igual.
	craft_markers = WorkMarkers.new()
	craft_markers.name = "Faena"
	add_child(craft_markers)
	craft_markers.setup(camera, sim)

	trail_view = TrailView.new()
	trail_view.name = "Rastros"
	add_child(trail_view)

	# Y el tiempo, que hasta ahora solo existia en un rotulo. Llevaba desde
	# que se implanto decidiendo lo que cunde la jornada, lo que se anda y lo
	# que se arriesga en una pared, y el jugador se enteraba leyendo. Un
	# temporal que solo esta en una etiqueta no es un temporal: es un numero.
	weather_view = WeatherView.new()
	weather_view.name = "Tiempo"
	add_child(weather_view)
	weather_view.setup(camera, _find_environment())

	# La capa que ensena lo que el juego considera intransitable. Apagada por
	# defecto: es una herramienta de mirar por dentro, no una capa de partida.
	nav_overlay = NavOverlay.new()
	nav_overlay.name = "Navegacion"
	add_child(nav_overlay)

	sim.chronicle = Chronicle.new()
	sim.chronicle.record(sim.day, GameState.season as int, GameState.year,
		Chronicle.Kind.GENTE,
		"La banda se instala en %s. Son %d, y no conocen el valle."
			% [Expedition.site.display_name() if Expedition.is_active()
				else "el abrigo", sim.population()], 2)

	knowledge = BandKnowledge.new()
	knowledge.setup(field.width, field.height, field.world_size)
	sim.field = field
	sim.knowledge = knowledge

	# La banda ya conoce lo que tiene alrededor del campamento: vive ahi. Sin
	# esto arrancaria sin ver ni su propia cueva, que es absurdo -y ademas
	# dejaria el mapa entero en negro sin nada por donde empezar a leerlo.
	knowledge.see_from(home, sim.sight_range * 1.6)

	# Los recursos, VISIBLES en el terreno. Hasta ahora la abundancia existia
	# en los numeros y en una capa de color del minimapa, pero no en el mundo.
	props = ResourceProps.new()
	props.name = "Recursos"
	add_child(props)
	props.setup(terrain, field)

	# LA HIERBA VA APAGADA, y es una decisión, no un descuido.
	#
	# `GroundCover` sólo puede sembrar alrededor de la cámara —doscientas mil
	# briznas y un millón largo de triángulos en un disco de 165 m—, y ese disco
	# se LEE: en cuanto se levanta un poco la cámara, el valle tiene un círculo
	# verde de detalle en el centro y nada alrededor, que es peor que no tener
	# hierba. Ese millón de triángulos se va ahora al bosque, que sí cubre el
	# mapa entero.
	#
	# El sistema se conserva entero: es cambiar este `if` para volver a tenerla.
	if ground_cover:
		cover = GroundCover.new()
		cover.name = "Hierba"
		add_child(cover)
		cover.setup(terrain)

	# El bosque va aparte de la hierba y de los props, y por una razón de fondo:
	# aquellos son detalle de cerca y éste es PAISAJE. Un bosque se ve desde
	# cualquier altura de cámara y cubre laderas enteras, así que tiene que estar
	# entero desde el principio -con impostores de dos triángulos- y sólo la malla
	# de verdad se transmite alrededor de la cámara. Ver [Forest].
	forest = Forest.new()
	forest.name = "Bosque"
	add_child(forest)
	forest.setup(terrain)

	# La hoguera del abrigo. Va aquí y no dentro de la cueva porque no es parte
	# de la cueva: es una obra de la banda, aparece cuando la levantan y se apaga
	# cuando se les acaba la leña. Ver [HearthFire].
	hearth_fire = HearthFire.new()
	hearth_fire.name = "Hoguera"
	add_child(hearth_fire)
	# La cueva de casa manda dónde se duerme y dónde se hace corro. Sin esto la
	# banda se apila en el punto del emplazamiento, a la intemperie.
	var home_cave := _cave_at(sim.home_position)
	if home_cave != null:
		sim.home_inside = home_cave.inside_point()
		sim.home_forecourt = home_cave.forecourt_point()
		# El interior NO se apoya en el terreno, y ahí está la diferencia: la
		# galería se mete DENTRO de la ladera, así que preguntarle la altura al
		# terreno en ese punto devuelve la del monte que hay encima —medido,
		# once metros más arriba— y la banda dormía en el tejado de su cueva. El
		# suelo de la cueva es el de su boca.
		sim.home_inside.y = home_cave.pick_position().y
		if terrain:
			sim.home_forecourt.y = terrain.get_height_at(sim.home_forecourt)

	# La hoguera va en la campa de la boca, no encima del abrigo: es donde se
	# hace el fuego de una cueva.
	hearth_fire.setup(sim, terrain,
		sim.home_forecourt if sim.home_forecourt != Vector3.ZERO
		else sim.home_position)

	# Y las hogueras de quien duerme fuera. Ver [BivouacFires].
	bivouac_fires = BivouacFires.new()
	bivouac_fires.name = "Vivacs"
	add_child(bivouac_fires)
	bivouac_fires.setup(sim, terrain)

	herds = WildlifeHerds.new()
	herds.name = "Wildlife"
	add_child(herds)
	herds.setup(terrain, field)
	# La fauna anda al compas de la partida: en pausa no se mueve. Ver
	# `WildlifeHerds.sim`.
	herds.sim = sim
	# Y la banda caza LO QUE ANDA POR AHI, no una media. Sin esta linea la caza
	# se resuelve con la tabla de [Hunting], que es lo que pasa en las pruebas
	# headless; con ella, el cazador acecha a un ciervo de los que se ven. Ver
	# [Hunt] y `SettlementSim._hunt_step`.
	if sim:
		sim.wildlife = herds

	tech = TechTree.new()
	# La simulacion consulta el arbol de verdad, no solo la ficha: con que se
	# pesca hoy sale de ahi -ver `Fishing`-, y sin el solo se pesca a mano.
	if sim:
		sim.techs = tech
		# Y el arbol consulta la despensa: aprender cuesta material, no solo
		# jornadas. Ver `TechTree.LEARNING_COST`.
		tech.larder = sim.store

	ui = GameUI.new()
	ui.name = "GameUI"
	ui.sim = sim
	ui.knowledge = knowledge
	ui.trails = trail_view
	ui.markers = paraje_markers
	ui.field = field
	ui.tech = tech
	ui.site = Expedition.site
	# El censo de lo pintado y la camara a la que lleva. Va DESPUES de props,
	# bosque y fauna a proposito: el censo les pregunta a ellos, asi que si se
	# monta antes se queda con referencias nulas y la pestana sale vacia.
	census = EntityCensus.new()
	census.setup(sim, herds, props, forest)
	ui.census = census
	ui.camera = camera
	ui.cave_action.connect(_on_cave_action)
	add_child(ui)
	# Y que la interfaz se entere de los momentos: hallazgos que enseñar y
	# decisiones que pedir. Ver [Moment].
	if sim != null:
		ui.watch_moments(sim)

	_build_resource_overlay()
	# Las cuevas del entorno del campamento salen ya descubiertas, por lo mismo
	_check_discoveries()

	var descartados := 0
	for entry: Dictionary in _find_work_sites(home):
		# Se pesca y se coge agua DESDE la orilla. El punto que sale de la
		# mascara cae en mitad del cauce, asi que primero se arrima a la ribera
		# y luego se comprueba si se llega.
		var spot := _best_work_spot(entry["activity"] as Subsistence.Activity,
			_nearest_shore(entry["position"]))
		if spot == Vector3.ZERO:
			descartados += 1
			continue
		entry["position"] = spot
		sim.set_work_site(entry["activity"], spot)

	# La banda arranca SIN REPARTIR: toda la tabla de trabajos en «—», y el
	# primer reparto lo hace el jugador. Es la primera decision de la partida y
	# se la estaba dando hecha `assign_default_jobs`, que sigue existiendo
	# -la usan las sondas, que necesitan una banda trabajando para medir- pero
	# ya no se llama al empezar.
	sim.apply_priorities()

	print("Asentamiento: %d personas, %d sitios de trabajo" % [
		sim.population(), sim.work_sites.size()])
	if descartados > 0:
		print("  %d tajos descartados: quedan al otro lado del agua" % descartados)


## Metros antes del destino a los que se corta el trayecto cuando el tajo esta
## en el agua. La orilla de un rio de 22 m queda a 11 m del eje, bastante mas
## que el radio de llegada, asi que con el radio normal toda pesquera saldria
## inalcanzable.
const RIVER_APPROACH_M := 30.0


## Monta las ocho casillas de terreno de alrededor.
##
## El relieve sale del MDT REGIONAL, no del local: el local solo cubre 4,5 km y
## las vecinas caerian fuera. El regional es basto -111 m por muestra- pero es
## terreno de verdad, y para un fondo gris sin textura sobra.
func _build_surroundings() -> void:
	if not Expedition.is_active() or terrain == null or terrain.heightmap == null:
		return

	# Primero el MDT fino del contorno, bakeado al fundar: 13,9 m por muestra
	# frente a los 111 del regional. Es la diferencia entre un valle y una loma.
	var region: HeightmapData = null
	var fine_path := "res://data/dem/local/site_%d_surround.res" % Expedition.site.id
	if ResourceLoader.exists(fine_path):
		region = load(fine_path)

	if region == null:
		# Reserva: el MDT regional. Basto, pero mejor que un mapa cortado a
		# cuchillo con la nada detras.
		var region_path := "res://data/dem/cantabria_region.res"
		if not ResourceLoader.exists(region_path):
			print("Sin MDT: el recuadro se queda sin casillas de alrededor")
			return
		region = load(region_path)
	if region == null:
		return

	print("Alrededores desde un MDT de %.1f m/muestra" % region.meters_per_sample)

	var surround := TerrainSurround.new()
	surround.name = "Alrededores"
	add_child(surround)
	surround.build(terrain, region, terrain.heightmap)
	# Y un ribete que marque hasta donde se juega: ahora que la costura encaja,
	# sin el no se distingue el recuadro del fondo
	surround.build_border(terrain)
	print("Casillas de alrededor montadas")


## Acerca un punto a la ribera vadeable mas proxima A LA QUE SE LLEGUE.
##
## Hace falta porque los tajos de agua salen de la mascara de cauce y por tanto
## caen DENTRO del rio: nadie pesca desde el centro del Nansa. Y hace falta que
## exija alcance porque la orilla mas cercana a un punto del cauce es, la mitad
## de las veces, la de enfrente.
func _nearest_shore(point: Vector3) -> Vector3:
	if terrain == null:
		return point

	var walkable := func(p: Vector3) -> bool:
		return terrain.crossing_difficulty_at(p) <= Hydrography.FORD_WADEABLE

	if walkable.call(point) and (sim == null or sim.can_reach(point)):
		return point

	# Espiral corta hacia fuera. Se guarda ademas la primera orilla sin mas,
	# por si no hubiera ninguna alcanzable: mejor devolver tierra firme
	# inalcanzable -que el filtro de alcance descartara luego- que un punto en
	# mitad del agua.
	var fallback := point
	var has_fallback := false

	for radius in range(5, 200, 5):
		for spoke in range(16):
			var angle := TAU * float(spoke) / 16.0
			var candidate := point + Vector3(cos(angle), 0.0, sin(angle)) * float(radius)
			if candidate.x < 0.0 or candidate.z < 0.0 \
					or candidate.x > float(terrain_size.x) or candidate.z > float(terrain_size.y):
				continue
			if not walkable.call(candidate):
				continue

			candidate.y = terrain.get_height_at(candidate)
			if sim == null or sim.can_reach(candidate):
				return candidate
			if not has_fallback:
				fallback = candidate
				has_fallback = true

	return fallback


## Busca en el terreno donde se hace cada cosa.
##
## No son puntos inventados: el cauce sale de la mascara de rios, la orilla de
## la cota del mar, y el coto de caza del llano mas amplio a distancia
## razonable. Si el sitio no tiene costa, no habra marisqueo, y punto.
func _find_work_sites(home: Vector3) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var half := Vector2(terrain_size) * 0.5
	var best_river := Vector3.ZERO
	var best_river_score := -1.0
	var best_coast := Vector3.ZERO
	var best_coast_dist := INF
	var best_hunt := Vector3.ZERO
	var best_hunt_score := -1.0
	var best_gather := Vector3.ZERO
	var best_gather_score := -1.0

	var step := 64
	for z in range(step, terrain_size.y - step, step):
		for x in range(step, terrain_size.x - step, step):
			var point := Vector3(x, 0, z)
			point.y = terrain.get_height_at(point)
			var distance := Vector2(x - home.x, z - home.z).length()
			# Nada demasiado lejos: se va y se vuelve en el dia.
			#
			# Y el suelo baja de 90 m a 30. Ese suelo era el que mandaba a los
			# pescadores a 800 m con el río a cincuenta pasos de la cueva:
			# medido, salían por la mañana, no llegaban a tiempo de trabajar y
			# se pasaban la partida entera yendo y volviendo sin traer un pez.
			# Un abrigo se elige POR estar junto al agua; que el tajo no pueda
			# estar donde está el agua es justo lo contrario de lo que se quiere.
			if distance > 1500.0 or distance < 30.0:
				continue

			var river: float = terrain.heightmap.sample_river_mask_meters(
				terrain.heightmap_region_offset.x + float(x) * terrain.meters_per_unit,
				terrain.heightmap_region_offset.y + float(z) * terrain.meters_per_unit)
			var slope := terrain.get_slope_at(point)

			# Un punto al otro lado del rio no es candidato a nada. El filtro va
			# aqui dentro y no al final para que la banda se quede con el mejor
			# sitio ALCANZABLE, en vez de perder la actividad entera porque el
			# mejor absoluto cayera en la otra orilla.
			#
			# Se comprueba solo cuando el candidato GANA, no en cada celda del
			# barrido: el trayecto recorre cientos de celdas y hacerlo dos mil
			# veces colgaba la fundacion.
			if river > 0.25:
				# El precio de la distancia no es un descuento simbólico: es lo
				# que decide si se puede trabajar el sitio o sólo llegar a él.
				# Con `distance / 4000` un cauce un pelo mejor a ochocientos
				# metros le ganaba a uno bueno a cien, y la cuadrilla se pasaba
				# la jornada andando. Ahora la distancia MULTIPLICA, así que un
				# sitio al que no da tiempo a ir no gana nunca.
				var score := river * clampf(1.0 - distance / 1200.0, 0.05, 1.0)
				# A la pesquera se llega por la ribera, asi que el trayecto se
				# corta antes del cauce en vez de en el radio de llegada
				if score > best_river_score and sim.can_reach(point, RIVER_APPROACH_M):
					best_river_score = score
					best_river = point

			if terrain.is_underwater(point) and distance < best_coast_dist \
					and sim.can_reach(point, RIVER_APPROACH_M):
				best_coast_dist = distance
				best_coast = point

			# Coto de caza: llano y despejado, ni pegado a casa ni lejisimos
			var hunt := (1.0 - clampf(slope, 0.0, 1.0)) - absf(distance - 700.0) / 2600.0
			if hunt > best_hunt_score and sim.can_reach(point):
				best_hunt_score = hunt
				best_hunt = point

			# Recoleccion: ladera suave y cerca
			var gather_fit := 1.0 - clampf(slope * 0.7, 0.0, 1.0)
			var gather := gather_fit * clampf(1.0 - distance / 1400.0, 0.05, 1.0)
			if gather > best_gather_score and sim.can_reach(point):
				best_gather_score = gather
				best_gather = point

	if best_hunt_score > 0.0:
		found.append({"activity": Subsistence.Activity.CAZA, "position": best_hunt,
			"label": "Coto de caza"})
	if best_river_score > 0.0:
		found.append({"activity": Subsistence.Activity.PESCA, "position": best_river,
			"label": "Pesquera"})
		# Los cantos se cogen en la barra de grava de la misma orilla, no
		# cruzando al otro lado por un desplazamiento fijo en diagonal
		# Los cantos se cogen en la barra de grava de la misma orilla. El
		# desplazamiento se vuelve a arrimar a la ribera porque en diagonal se
		# metia otra vez en el cauce.
		found.append({"activity": Subsistence.Activity.MATERIA_PRIMA,
			"position": _nearest_shore(_nearest_shore(best_river) + Vector3(35, 0, 35)),
			"label": "Cantos de cuarcita"})
	if best_coast_dist < INF:
		found.append({"activity": Subsistence.Activity.MARISQUEO, "position": best_coast,
			"label": "Marisqueo"})
	if best_gather_score > 0.0:
		found.append({"activity": Subsistence.Activity.RECOLECCION, "position": best_gather,
			"label": "Recolección"})
	return found


## El mejor punto para plantar un tajo de esta actividad: el que MAS tiene y
## al que ADEMAS se puede llegar. Vector3.ZERO si no hay ninguno.
##
## Los sitios de trabajo salian de la forma del terreno —ladera suave,
## meandro, barra de cantos— sin preguntarle nada al campo de recursos ni a
## la rejilla de caminos. Con eso, el tajo de pesca del sitio 56 caia en una
## celda con abundancia 0,000 —habiendo 156 celdas de rio con pesca en el
## mismo mapa— y encima en otra zona de la rejilla, o sea sin camino: la
## banda salia a pescar, no llegaba, se ponia a prospectar por el monte y
## volvia de vacio todos los dias de la partida.
##
## Ahora se pregunta a los dos: se ordenan las celdas que de verdad tienen
## recurso cerca y se coge la primera a la que se pueda ir andando.
func _best_work_spot(activity: Subsistence.Activity, near: Vector3) -> Vector3:
	var candidates: Array[Vector3] = []
	if sim.field:
		for rich: Vector3 in sim.field.best_spots_near(activity, near, 400.0, 12):
			candidates.append(rich)
	candidates.append(near)

	for candidate: Vector3 in candidates:
		var spot := _nearest_shore(candidate)
		spot.y = terrain.get_height_at(spot)
		if sim.can_reach(spot):
			return spot
	return Vector3.ZERO


## Los postes azules que marcaban «aquí trabaja la gente» se han ido: eran
## de antes de que existieran los parajes, cuando el único sitio de trabajo
## era una corazonada del fundador. Ahora cada sitio tiene nombre, chapa y
## ficha propia -ver [ParajeMarkers]-, y dos marcadores para lo mismo solo
## ensucian el valle. `set_work_site` SÍ se queda: sigue siendo el sitio de
## reserva al que ir mientras no se conozca ningún paraje.
func _on_day_passed(_day: int) -> void:
	_update_band_panel()

	# Los parajes se bautizan al cerrar la jornada: es el momento de poner o
	# quitar sus chapas
	if paraje_markers and sim:
		var grid := sim._navgrid()
		paraje_markers.refresh(sim.parajes, terrain,
			func(a: Vector3, b: Vector3) -> bool: return grid.connected(a, b))
		paraje_markers.refresh_peaks(sim.peaks(), terrain)
	if trap_markers and sim:
		trap_markers.refresh(sim.traps, terrain)
	if nasa_markers and sim:
		nasa_markers.refresh(sim.nasas, terrain)
	# La baliza de exploracion colgaba del guardia de las TRAMPAS, que no pinta
	# nada aqui: sin marcador de trampas no se veia adonde se habia mandado
	# mirar. Va con las chapas de paraje, que es de lo que es.
	if paraje_markers and sim:
		paraje_markers.set_scout_beacon(sim.scout_order, sim.has_scout_order, terrain)

	# Una temporada no se sabe hasta haberla trabajado. Se anota por la
	# actividad de cada cual, no en bloque: la banda puede haber vivido tres
	# otonos de caza sin haber visto nunca el remonte del salmon, porque nadie
	# estaba en el rio esos dias.
	if knowledge:
		for person: Inhabitant in sim.people:
			if person.state == Inhabitant.State.TRABAJANDO or person.has_task:
				knowledge.record_season(person.activity, GameState.season)

	# Las tecnicas salen de la practica, no de gastar un recurso abstracto: se
	# suma una jornada por cada persona que ha trabajado en esa actividad
	if tech:
		var worked: Dictionary = {}
		for person: Inhabitant in sim.people:
			if person.has_task and person.can_work():
				worked[person.activity] = float(worked.get(person.activity, 0.0)) + 1.0
		for activity: int in worked.keys():
			for gained: int in tech.add_practice(
					activity as Subsistence.Activity, float(worked[activity])):
				var learned := gained as TechTree.Tech
				print("Tecnica aprendida: %s" % TechTree.tech_name(learned))
				# Aprender a hacer algo es un hito, y se cuenta como tal: con
				# su relato y con la opcion de dejarlo en la pared. Ver [Tale].
				if sim:
					sim.tell_technique(learned)
				# Las tecnicas de cruce no son un adorno de la ficha: abren
				# territorio de verdad, porque la simulacion las consulta
				if learned == TechTree.Tech.PIRAGUA:
					sim.has_boat = true
				elif learned == TechTree.Tech.PASARELA:
					sim.has_bridge = true


## Vuelve al mapa regional, llevandose el estado de la banda
func _return_to_region() -> void:
	if sim:
		GameState.population = sim.population()
		GameState.food = sim.store.food_rations()
	Expedition.clear()
	get_tree().change_scene_to_file(Expedition.REGION_SCENE)


func _load_materials() -> void:
	# Cargar todos los materiales
	var material_files := [
		"res://materials/Iron.tres",
		"res://materials/Stone.tres",
		"res://materials/Straw.tres",
		"res://materials/Coal.tres",
		"res://materials/Wood.tres",
		"res://materials/Copper.tres",
		"res://materials/Clay.tres"
	]
	
	for path in material_files:
		if ResourceLoader.exists(path):
			var mat := load(path) as RawMaterial
			if mat:
				var key := mat.display_name.to_lower()
				materials[key] = mat
				print("Material cargado: ", mat.display_name)


func _load_blocks() -> void:
	var block_files := [
		"res://buildings/StoneWall.tres",
		"res://buildings/WoodenFloor.tres",
		"res://buildings/StrawRoof.tres"
	]

	for path in block_files:
		if not ResourceLoader.exists(path):
			continue
		var block := load(path) as BlockData
		if block:
			blocks[block.category.to_lower()] = block
			print("Bloque cargado: %s (%.0f kg, dureza %.1f)" % [
				block.block_name, block.get_effective_weight(), block.get_hardness()])


func _setup_terrain() -> void:
	terrain = TerrainGenerator.new()
	terrain.name = "TerrainGenerator"
	terrain.terrain_size = terrain_size
	terrain.resolution = terrain_resolution
	terrain.max_height = max_height
	terrain.seed_value = seed_value
	terrain.sea_level = sea_level

	if use_real_terrain and ResourceLoader.exists(heightmap_path):
		var data := load(heightmap_path) as HeightmapData
		if data:
			terrain.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
			terrain.heightmap = data
			terrain.heightmap_region_offset = region_offset
			# A escala local la altitud no separa pasto de roca: eso lo hace la
			# pendiente. Con bandas absolutas el recuadro salia entero marron.
			terrain.bands_relative = true
			print("Terreno real: ", data.describe())
			print("  recuadro en uso: %.0f x %.0f m desde (%.0f, %.0f)" % [
				terrain_size.x, terrain_size.y, region_offset.x, region_offset.y])
		else:
			push_warning("No se pudo cargar el heightmap, se usa el procedural")
	elif use_real_terrain:
		push_warning("No existe %s, se usa el terreno procedural" % heightmap_path)

	add_child(terrain)


func _setup_chunk() -> void:
	chunk = Chunk.new()
	chunk.name = "MainChunk"
	chunk.chunk_size = terrain_size
	chunk.cell_size = 1.0
	add_child(chunk)
func _setup_architecto() -> void:
	architecto = Architecto.new()
	architecto.name = "Architecto"
	add_child(architecto)
	architecto.initialize(chunk, terrain)


func _setup_camera() -> void:
	# Cargar la escena de cámara preconfigurada
	var camera_scene := load("res://scenes/OrbitalCamera.tscn")
	if camera_scene:
		camera = camera_scene.instantiate() as OrbitalCamera
		camera.name = "MainCamera"
		add_child(camera)
		
		# La camara venia calibrada para 128 unidades; sobre 2 km hay que subir
		# el alcance o el terreno no cabe ni en el zoom ni en el plano lejano
		var world := float(maxi(terrain_size.x, terrain_size.y))
		# Se pasa el recorrido completo; la camara se queda con la banda util
		camera.set_distance_limits(maxf(10.0, world * 0.01), world * 2.0)
		# Mas contenido: a world*0.15 se cruzaban los 4 km en siete segundos
		camera.move_speed = maxf(25.0, world * 0.045)
		camera.far = world * 4.0
		# El plano cercano por defecto (0.05) con un lejano de miles de unidades
		# arruina la precision del buffer de profundidad. Como la camara nunca
		# se acerca mas que min_distance, se puede subir sin recortar nada.
		camera.near = maxf(world * 0.0008, 0.1)

		# Configurar posición inicial del target. Usar los setters: asignar las
		# propiedades sueltas tras el _ready() de la cámara no refrescaba la vista.
		# Arrancar a media distancia y no en la vista completa: a 3000 m de
		# altura un arbol de 5 m es subpixel y no se dibuja ninguno, asi que la
		# vista general daba la impresion de un mundo vacio. Se puede alejar
		# con la rueda hasta max_distance.
		camera.set_distance(world * 0.20)
		# La camara consulta el terreno para no colarse bajo tierra al acercarse
		camera.height_probe = func(point: Vector3) -> float:
			return terrain.get_height_at(point)
		camera.ground_clearance = 14.0
		# La camara no sale del recuadro jugable
		camera.bounds_min = Vector2.ZERO
		camera.bounds_max = Vector2(float(terrain_size.x), float(terrain_size.y))
		camera.set_target(Vector3(float(terrain_size.x) / 2.0, 0, float(terrain_size.y) / 2.0))
		camera.current = true
		print("Cámara configurada en: ", camera.target_position)
	else:
		push_error("No se pudo cargar la escena de cámara")


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	# El panel de la esquina es SOLO de depuracion, y va aparte del resto.
	# Antes el `return` que lo apagaba estaba al principio de esta funcion, asi
	# que quitarlo se llevaba por delante el minimapa y todo lo demas.
	if show_debug_ui:
		var panel := PanelContainer.new()
		panel.name = "DebugPanel"
		panel.position = Vector2(10, 10)
		canvas.add_child(panel)

		var vbox := VBoxContainer.new()
		panel.add_child(vbox)

		debug_label = Label.new()
		debug_label.name = "DebugLabel"
		debug_label.text = "CityBuilder Demo"
		vbox.add_child(debug_label)


	# El minimapa NO se construye aqui: se lee del terreno, y en este punto
	# `terrain.generate()` todavia no ha corrido, asi que `get_height_at`
	# devuelve la misma cota en todas partes y el mapa sale de un verde plano.
	# Se guarda el lienzo y se construye tras generar.
	_minimap_canvas = canvas

	# El panel de banda de la esquina se ha quitado: lo que decia esta ahora en
	# las pestanas de Banda y Almacen, que ademas lo dicen mejor. Tener las dos
	# cosas era ruido y ocupaba el sitio por donde se ve el terreno.

	# La cabecera del emplazamiento y la lista de controles se han quitado de
	# aqui: lo primero esta en la pestana de Cronica y lo segundo en la de
	# Controles, donde se consultan cuando hacen falta en vez de tapar el
	# terreno todo el rato.


func _setup_performance_overlay() -> void:
	var overlay := PerformanceOverlay.new()
	overlay.name = "PerformanceOverlay"
	add_child(overlay)


func _connect_signals() -> void:
	# Conectar señales del TerrainGenerator
	terrain.generation_complete.connect(_on_terrain_generated)
	
	# Conectar señales del Architecto
	architecto.building_placed.connect(_on_building_placed)
	architecto.building_collapsed.connect(_on_building_collapsed)
	architecto.placement_denied.connect(_on_placement_denied)
	


## Aparta un punto del agua hasta la orilla seca más cercana.
##
## Se busca en espiral: anillos de radio creciente y ocho rumbos por anillo, y
## se toma el primer punto seco. Así el desplazamiento es el mínimo que
## resuelve el problema —una boca junto al río sigue junto al río— en vez de
## mandarla a la ladera de enfrente.
##
## Si en cien metros no hay tierra seca, se deja donde estaba: será una
## cavidad que de verdad se abre sobre el agua, y las hay.
const NUDGE_STEP := 12.0
const NUDGE_MAX_RINGS := 8


func _nudge_out_of_water(world: Vector3) -> Vector3:
	if terrain == null:
		return world
	if terrain.crossing_difficulty_at(world) <= 0.0:
		return world

	for ring in range(1, NUDGE_MAX_RINGS + 1):
		var radius := float(ring) * NUDGE_STEP
		for i in range(8):
			var angle := (float(i) / 8.0) * TAU
			var candidate := world + Vector3(
				cos(angle) * radius, 0.0, sin(angle) * radius)
			if candidate.x < 0.0 or candidate.z < 0.0 \
					or candidate.x > float(terrain_size.x) \
					or candidate.z > float(terrain_size.y):
				continue
			if terrain.crossing_difficulty_at(candidate) <= 0.0:
				print("Cueva apartada del cauce: %.0f m" % radius)
				return candidate

	return world


func _on_terrain_generated() -> void:
	print("Terreno generado")
	
	# Inicializar vegetación después de generar terreno
	# Solo si hay vegetacion: esta desactivada mientras no haya especies con
	# porte de verdad, y estas llamadas se quedaban colgando de un nodo nulo




func _spawn_test_buildings() -> void:
	# Posiciones relativas al tamano del mundo, sobre tierra firme
	var world_x := float(terrain_size.x)
	var world_z := float(terrain_size.y)
	var test_positions := [
		Vector3(world_x * 0.15, 0, world_z * 0.50),
		Vector3(world_x * 0.30, 0, world_z * 0.15),
		Vector3(world_x * 0.88, 0, world_z * 0.12),
		Vector3(world_x * 0.22, 0, world_z * 0.85),
	]

	for pos in test_positions:
		_place_hut_at(pos)


## Busca en anillos concéntricos un punto donde el Architecto permita construir
func _find_buildable_spot_near(origin: Vector3, weight: float, search_radius: float = 14.0) -> Variant:
	if _is_buildable(origin, weight):
		return origin

	var step := maxf(2.0, search_radius / 12.0)
	var radius := step
	while radius <= search_radius:
		for i in range(16):
			var angle := float(i) / 16.0 * TAU
			var candidate := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			if _is_buildable(candidate, weight):
				return candidate
		radius += step

	return null


## Un sitio vale si el Architecto lo aprueba y no esta bajo el agua
func _is_buildable(world_pos: Vector3, weight: float) -> bool:
	if terrain and terrain.is_underwater(world_pos):
		return false
	return architecto.can_place_at_world(world_pos, weight)["can_place"]


## Coloca una cabana. Si allow_search es true y el punto exacto no vale,
## busca un llano cerca (util para el spawn automatico, no para un click).
func _place_hut_at(world_pos: Vector3, allow_search: bool = true) -> void:
	var built := _build_hut()
	var hut: Node3D = built["node"]
	var weight: float = built["weight"]

	var spot: Variant = world_pos
	if allow_search:
		# Radio proporcional al mundo: 14 m sobre un mapa de 2 km no encuentra
		# nada si el punto de partida cae en el agua o en una ladera
		spot = _find_buildable_spot_near(world_pos, weight, maxf(14.0, float(terrain_size.x) * 0.06))

	if spot == null:
		print("Sin sitio construible cerca de %s para %.0f kg" % [world_pos, weight])
		hut.queue_free()
		return

	if architecto.place_building_node(spot, hut, weight):
		add_child(hut)
	else:
		hut.queue_free()


## Ensambla una cabana con los bloques de la biblioteca: suelo, cuatro muros y
## techo. El peso sale de los BlockData reales via Architecto.calculate_structure_weight()
## en vez de un numero inventado.
func _build_hut() -> Dictionary:
	var hut := Node3D.new()
	hut.name = "Hut"

	var parts: Array[Dictionary] = []
	var half := HUT_SIZE * 0.5

	var floor_block: BlockData = blocks.get("floor")
	if floor_block:
		var thickness: float = floor_block.dimensions.y
		hut.add_child(_make_block_body(
			floor_block,
			Vector3(HUT_SIZE, thickness, HUT_SIZE),
			Vector3(0, thickness * 0.5, 0)))
		parts.append({"weight": floor_block.get_effective_weight() * _block_units(floor_block, HUT_SIZE * HUT_SIZE)})

	var wall_block: BlockData = blocks.get("wall")
	if wall_block:
		var t: float = wall_block.dimensions.z
		var wall_area := HUT_SIZE * HUT_HEIGHT
		var y := HUT_HEIGHT * 0.5
		var placements := [
			[Vector3(0, y, -half), Vector3(HUT_SIZE, HUT_HEIGHT, t)],
			[Vector3(0, y, half), Vector3(HUT_SIZE, HUT_HEIGHT, t)],
			[Vector3(-half, y, 0), Vector3(t, HUT_HEIGHT, HUT_SIZE)],
			[Vector3(half, y, 0), Vector3(t, HUT_HEIGHT, HUT_SIZE)],
		]
		for placement in placements:
			hut.add_child(_make_block_body(wall_block, placement[1], placement[0]))
			parts.append({"weight": wall_block.get_effective_weight() * _block_units(wall_block, wall_area)})

	var roof_block: BlockData = blocks.get("roof")
	if roof_block:
		var rt: float = roof_block.dimensions.y
		hut.add_child(_make_block_body(
			roof_block,
			Vector3(HUT_SIZE + 0.5, rt, HUT_SIZE + 0.5),
			Vector3(0, HUT_HEIGHT + rt * 0.5, 0)))
		parts.append({"weight": roof_block.get_effective_weight() * _block_units(roof_block, HUT_SIZE * HUT_SIZE)})

	return {"node": hut, "weight": Architecto.calculate_structure_weight(parts)}


## Cuantas piezas de un bloque hacen falta para cubrir un area, usando su cara mayor
func _block_units(block: BlockData, area_m2: float) -> float:
	var d := block.dimensions
	var face := maxf(maxf(d.x * d.y, d.x * d.z), d.y * d.z)
	return area_m2 / maxf(face, 0.01)


## Crea el cuerpo fisico de un bloque: malla + colision en la capa "buildings".
## Antes los edificios no tenian CollisionShape3D, asi que el raycast de
## colocacion los atravesaba y se podian solapar sin detectarlo.
func _make_block_body(block: BlockData, size: Vector3, offset: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block.block_name.replace(" ", "")
	body.position = offset
	# Capas declaradas en project.godot: 1 = terrain, 2 = buildings
	body.collision_layer = 2
	body.collision_mask = 1

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = block.primary_material.color if block.primary_material else Color(0.7, 0.6, 0.5)
	material.roughness = 0.9
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	return body


func _on_building_placed(world_pos: Vector3, _building: Node3D) -> void:
	print("Edificio colocado en: ", world_pos)


func _on_building_collapsed(world_pos: Vector3, _building: Node3D) -> void:
	print("¡Edificio colapsado en: ", world_pos, "!")


func _on_placement_denied(world_pos: Vector3, reason: String) -> void:
	print("No se puede colocar edificio en ", world_pos, ": ", reason)


## Minimapa: sombreado del relieve del recuadro, con la gente encima.
##
## Se pinta del heightmap ya generado y no con una segunda camara: una
## SubViewport cenital costaria un pase de render entero por frame para algo
## que no cambia nunca.
func _build_minimap(canvas: CanvasLayer) -> void:
	if terrain == null:
		return

	# Mas resolucion: a 176 px sobre 4 km cada pixel eran 23 m y el relieve se
	# perdia entero, que es por lo que salia como color plano.
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var span := terrain.get_height_range()
	var range_h: float = maxf(span.y - span.x, 1.0)
	var step: float = float(terrain_size.x) / float(size)

	# Sombreado direccional de verdad: se ilumina desde el noroeste, que es la
	# convencion cartografica, en vez de restar las dos derivadas. La suma de
	# derivadas aplana las laderas perpendiculares a la diagonal, y por eso el
	# relieve no se leia.
	var sun := Vector3(-0.6, 0.62, -0.5).normalized()

	for py in range(size):
		for px in range(size):
			var world := Vector3(
				float(px) / float(size - 1) * float(terrain_size.x), 0.0,
				float(py) / float(size - 1) * float(terrain_size.y))
			var h: float = terrain.get_height_at(world)
			var t: float = clampf((h - span.x) / range_h, 0.0, 1.0)

			var dx: float = terrain.get_height_at(world + Vector3(step, 0, 0)) - h
			var dz: float = terrain.get_height_at(world + Vector3(0, 0, step)) - h
			var normal := Vector3(-dx, step, -dz).normalized()
			var light: float = clampf(normal.dot(sun) * 1.35 + 0.22, 0.18, 1.35)
			var slope: float = clampf(Vector2(dx, dz).length() / step, 0.0, 1.0)

			var colour: Color
			if terrain.is_underwater(world):
				colour = Color(0.10, 0.20, 0.32)
			elif terrain.crossing_difficulty_at(world) > 0.05:
				# El agua corriente se pinta aparte: es la referencia que hace
				# legible un mapa de valle
				colour = Color(0.20, 0.38, 0.55)
			else:
				# Verde en el llano, ocre segun sube, gris de caliza donde la
				# pendiente afloraria roca: los mismos criterios que el terreno
				var ground := Color(0.30, 0.40, 0.22).lerp(Color(0.58, 0.52, 0.36), t)
				colour = ground.lerp(Color(0.60, 0.58, 0.54), clampf(slope * 1.6, 0.0, 0.85))
				colour *= light
			image.set_pixel(px, py, colour)

	# Se guardan dos: la limpia, que es el relieve tal cual, y la que se pinta,
	# que es esa misma con la niebla de lo no explorado encima
	_minimap_clear = image
	_minimap_base = image.duplicate() as Image

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	canvas.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var panel := PanelContainer.new()
	column.add_child(panel)
	_minimap = TextureRect.new()
	_minimap.custom_minimum_size = Vector2(size, size)
	_minimap.texture = ImageTexture.create_from_image(image)
	panel.add_child(_minimap)

	# Rotulo del overlay. Deja claro que lo que se pinta es lo que la banda
	# CONOCE: al empezar esta casi en blanco, y esa es la informacion.
	var label_panel := PanelContainer.new()
	column.add_child(label_panel)
	_overlay_label = Label.new()
	_overlay_label.text = "[R] capas de recurso"
	_overlay_label.add_theme_font_size_override("font_size", 11)
	_overlay_label.custom_minimum_size = Vector2(size, 0)
	_overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_panel.add_child(_overlay_label)

	# El boton de volver al mapa regional. Va aqui, junto al minimapa, que es
	# donde uno mira cuando piensa «quiero ver el mapa grande». Antes esto era
	# ESC, y salirse del valle entero por pulsar ESC daba un susto cada vez.
	var back := Button.new()
	back.text = "Ver la comarca"
	back.custom_minimum_size = Vector2(size, 26)
	back.tooltip_text = "Vuelve al mapa regional de Cantabria"
	if ui and ui._skin:
		back.theme = ui._skin
	back.pressed.connect(func() -> void:
		if Expedition.is_active():
			_return_to_region())
	column.add_child(back)


## Repinta gente y tajos sobre el relieve del minimapa
func _update_minimap() -> void:
	if _minimap == null or _minimap_base == null:
		return

	# Se reutiliza la misma imagen en vez de duplicar la base: son 256x256 y
	# esto corre cuatro veces por segundo
	if _minimap_frame == null:
		_minimap_frame = _minimap_base.duplicate() as Image
	else:
		_minimap_frame.blit_rect(_minimap_base,
			Rect2i(Vector2i.ZERO, _minimap_base.get_size()), Vector2i.ZERO)
	var image := _minimap_frame

	# El overlay de recursos ya NO se pinta aqui. Lo hacia recorriendo los
	# 65.536 pixeles del minimapa y llamando a `believed_abundance` en cada
	# uno, cuatro veces por segundo: era la mitad de los frames que se comian
	# los overlays. Ahora esa capa la pinta el shader del terreno de una sola
	# muestra, y el minimapa se dedica a lo suyo, que es orientar.
	if herds and _overlay_activity == Subsistence.Activity.CAZA:
		for position: Vector3 in herds.positions():
			_plot(image, position, Color(0.95, 0.62, 0.30), 1)

	if sim:
		for a: int in sim.work_sites.keys():
			_plot(image, sim.work_sites[a], Color(0.35, 0.9, 0.95), 2)
		for person: Inhabitant in sim.people:
			_plot(image, person.position, Color(1.0, 0.92, 0.55), 1)
		_plot(image, sim.home_position, Color(1.0, 0.42, 0.35), 3)
	if camera:
		_draw_view_cone(image)
		_plot(image, camera.target_position, Color(1.0, 1.0, 1.0), 2)

	# Actualizar la textura existente en vez de crear una nueva cada vez: crear
	# una ImageTexture reserva memoria de GPU, y hacerlo cuatro veces por
	# segundo deja al recolector trabajando de balde
	if _minimap.texture is ImageTexture:
		(_minimap.texture as ImageTexture).update(image)
	else:
		_minimap.texture = ImageTexture.create_from_image(image)


## Dibuja hacia donde mira la camara y hasta donde llega.
##
## Sin esto el minimapa no dice lo unico que hace falta para orientarse, que es
## en que parte del valle esta uno y hacia donde apunta.
func _draw_view_cone(image: Image) -> void:
	var size := image.get_width()
	var eye := camera.global_position
	var target := camera.target_position

	var forward := Vector2(target.x - eye.x, target.z - eye.z)
	if forward.length() < 0.001:
		return
	forward = forward.normalized()

	# Alcance proporcional a lo lejos que esta la camara: al alejarse se ve
	# mas mapa, y el cono tiene que crecer con ello
	var reach: float = clampf(eye.distance_to(target) * 1.5, 120.0, float(terrain_size.x))
	var half_angle := deg_to_rad(camera.fov * 0.5)

	var origin := Vector2(eye.x, eye.z)
	for side in [-1.0, 1.0]:
		var edge := forward.rotated(side * half_angle)
		var steps := int(reach / 6.0)
		for s in range(steps):
			var point := origin + edge * (float(s) * 6.0)
			var px := int(point.x / float(terrain_size.x) * float(size - 1))
			var py := int(point.y / float(terrain_size.y) * float(size - 1))
			if px < 0 or py < 0 or px >= size or py >= size:
				continue
			# Se mezcla en vez de pintar opaco: el cono es una guia, no debe
			# tapar el relieve que hay debajo
			image.set_pixel(px, py,
				image.get_pixel(px, py).lerp(Color(1.0, 1.0, 1.0), 0.55))

	# La posicion de la camara, que no es la misma que su objetivo
	_plot(image, Vector3(eye.x, 0.0, eye.z), Color(0.95, 0.95, 1.0), 2)


## Overlay de recursos sobre el terreno, en UNA textura.
##
## La primera version ponia un MeshInstance3D por celda y actividad: 64x64
## celdas por cinco actividades son mas de veinte mil nodos, cada uno con su
## material y su llamada de dibujado. Se comia los frames enteros.
##
## Ahora es una sola imagen que el shader del terreno muestrea y mezcla con el
## albedo. Cuesta cero llamadas de dibujado y ademas queda pegado al relieve en
## vez de flotando en discos por encima.
func _build_resource_overlay() -> void:
	if field == null:
		return

	_overlay_image = Image.create(field.width, field.height, false, Image.FORMAT_RGBA8)
	_overlay_texture = ImageTexture.create_from_image(_overlay_image)

	var material := terrain.get_terrain_material()
	if material:
		material.set_shader_parameter("overlay_tex", _overlay_texture)
		material.set_shader_parameter("overlay_world_size",
			Vector2(float(terrain_size.x), float(terrain_size.y)))
		material.set_shader_parameter("use_overlay", false)


## Repinta la capa activa. Se llama al cambiar de capa y de vez en cuando,
## porque lo que muestra -lo conocido- crece segun anda la gente.
func _refresh_resource_overlay() -> void:
	if _overlay_image == null or terrain == null:
		return

	var material := terrain.get_terrain_material()
	if material == null:
		return

	if _overlay_activity == OVERLAY_OFF:
		material.set_shader_parameter("use_overlay", false)
		return

	var showing_known := _overlay_activity == OVERLAY_KNOWN
	var activity := Subsistence.Activity.CAZA
	var tint := Color(0.55, 0.80, 1.0)
	if not showing_known:
		activity = _overlay_activity as Subsistence.Activity
		tint = _overlay_color(activity)

	for z in range(field.height):
		for x in range(field.width):
			var centre := field.cell_center(x, z)
			var strength := 0.0

			if showing_known:
				# Capa de territorio reconocido. Sale de `explored`, que es el
				# mapa de lo que se ha VISTO, y no de la familiaridad con los
				# recursos: se puede cruzar un valle entero sin aprender nada
				# de su caza y aun asi conocer el camino.
				if knowledge:
					strength = knowledge.explored_at(centre)
			else:
				# Capa de un recurso: se pinta lo que la banda CREE que hay.
				# Un mapa con los cotarros que nadie ha pisado seria el mapa
				# del disenador, no el de la banda.
				if knowledge:
					strength = clampf(knowledge.believed_abundance(
						field, activity, centre, GameState.season), 0.0, 1.0)
				else:
					strength = field.abundance_cell(activity, x, z)

			_overlay_image.set_pixel(x, z,
				Color(tint.r, tint.g, tint.b, clampf(strength, 0.0, 1.0)))

	_overlay_texture.update(_overlay_image)
	material.set_shader_parameter("use_overlay", true)



## Revisa qué cuevas ha encontrado ya la banda.
##
## Una cueva sin descubrir no se dibuja: no es que esté oculta, es que para el
## jugador todavía no existe. Es lo que da sentido a explorar.
## La boca de cueva más cercana a un punto, o null si no hay ninguna cerca.
func _cave_at(point: Vector3) -> CaveMouth:
	var best: CaveMouth = null
	var best_dist := 90.0
	for cave: CaveMouth in _caves:
		var reach := cave.pick_position().distance_to(point)
		if reach < best_dist:
			best_dist = reach
			best = cave
	return best


func _check_discoveries() -> void:
	if knowledge == null:
		return
	for cave: CaveMouth in _caves:
		if cave.discovered:
			continue
		if knowledge.is_discovered(cave.pick_position()):
			cave.discover()
			var name_text := String(cave.feature.get("name", "una cavidad"))
			print("Descubierta: %s" % name_text)
			if sim and sim.chronicle:
				var away := int(cave.pick_position().distance_to(sim.home_position))
				sim.chronicle.record(sim.day, GameState.season as int,
					GameState.year, Chronicle.Kind.HALLAZGO,
					"La banda dio con %s, a %d m del abrigo." % [name_text, away],
					2)


## Oscurece en el minimapa lo que la banda no ha visto.
##
## Se rehace la imagen base entera y de tarde en tarde, no en cada refresco:
## repintar 65.000 pixeles cuatro veces por segundo fue lo que se comio los
## frames la vez anterior, y lo que muestra cambia por jornadas.
func _refresh_minimap_fog() -> void:
	if _minimap_base == null or knowledge == null or _minimap_clear == null:
		return

	var size := _minimap_base.get_width()
	# Se muestrea a la resolucion del conocimiento y se rellena por bloques:
	# la niebla no tiene mas detalle que eso, asi que pedirle mas es tirar
	# trabajo
	var block := maxi(size / knowledge.width, 1)

	for by in range(0, size, block):
		for bx in range(0, size, block):
			var world := Vector3(
				float(bx) / float(size - 1) * float(terrain_size.x), 0.0,
				float(by) / float(size - 1) * float(terrain_size.y))
			# Ni negro del todo: se deja adivinar la silueta del valle, que es
			# lo que se ve desde lejos aunque no se haya estado
			var light: float = 0.16 + 0.84 * clampf(
				knowledge.explored_at(world), 0.0, 1.0)
			for y in range(by, mini(by + block, size)):
				for x in range(bx, mini(bx + block, size)):
					_minimap_base.set_pixel(x, y,
						_minimap_clear.get_pixel(x, y) * light)


## Un color por actividad, para que el overlay se lea de un vistazo
func _overlay_color(activity: Subsistence.Activity) -> Color:
	match activity:
		Subsistence.Activity.PESCA: return Color(0.35, 0.70, 0.95)
		Subsistence.Activity.CAZA: return Color(0.95, 0.45, 0.30)
		Subsistence.Activity.RECOLECCION: return Color(0.55, 0.85, 0.35)
		Subsistence.Activity.MARISQUEO: return Color(0.85, 0.75, 0.40)
		_: return Color(0.75, 0.70, 0.80)


## Cambia de capa de recursos con la tecla R
func _cycle_overlay() -> void:
	# El territorio conocido va PRIMERO: es la capa que contesta la pregunta
	# que se hace uno antes que ninguna otra, que es hasta donde ha llegado la
	# banda. Las de recurso solo tienen sentido leidas sobre esa.
	var order := [OVERLAY_OFF, OVERLAY_KNOWN,
		Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
		Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
		Subsistence.Activity.MATERIA_PRIMA]
	var current := order.find(_overlay_activity)
	_overlay_activity = order[(current + 1) % order.size()]
	_refresh_resource_overlay()

	if _overlay_label:
		if _overlay_activity == OVERLAY_OFF:
			_overlay_label.text = "[R] capas de recurso"
		elif _overlay_activity == OVERLAY_KNOWN:
			_overlay_label.text = "Territorio reconocido — lo que la banda ha pisado"
		else:
			var activity := _overlay_activity as Subsistence.Activity
			var season_note := "temporada conocida" if knowledge != null \
				and knowledge.knows_season(activity, GameState.season) else "temporada por descubrir"
			_overlay_label.text = "%s — lo que la banda conoce (%s)" % [
				Subsistence.activity_name(activity), season_note]


func _plot(image: Image, world: Vector3, colour: Color, radius: int) -> void:
	var size := image.get_width()
	var px := int(world.x / float(terrain_size.x) * float(size - 1))
	var py := int(world.z / float(terrain_size.y) * float(size - 1))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := px + dx
			var y := py + dy
			if x >= 0 and y >= 0 and x < size and y < size:
				image.set_pixel(x, y, colour)


## Estado de la gente, uno a uno
func _update_band_panel() -> void:
	if band_label == null or sim == null:
		return

	var lines: Array[String] = [
		"%s — dia %d, %02d:00 · %s, año %d" % [
			Expedition.site.display_name() if Expedition.is_active() else "Asentamiento",
			sim.day, int(sim.hour),
			Subsistence.season_name(GameState.season), GameState.year],
		"gente %d   ·   reserva %.1f jornadas   ·   con hambre %d" % [
			sim.population(), sim.store.food_rations(), sim.hungry_count()],
		"",
	]

	var counts := sim.state_counts()
	var summary := ""
	for key: String in counts.keys():
		summary += "%s %d   " % [key, counts[key]]
	lines.append(summary)
	lines.append("")

	# Los primeros, con nombre y necesidad propia
	var shown := 0
	for person: Inhabitant in sim.people:
		if shown >= 10:
			break
		lines.append("  " + person.summary())
		shown += 1
	if sim.people.size() > shown:
		lines.append("  ...y %d mas" % (sim.people.size() - shown))

	lines.append("")
	lines.append("[1-5] mandar a todos a una tarea · [ESC] volver al mapa regional")
	band_label.text = "\n".join(lines)


func _process(_delta: float) -> void:
	if sim == null:
		return
	var frame := Engine.get_process_frames()
	if frame % 15 == 0:
		_update_band_panel()
		_update_minimap()
		_refresh_debug_label()
		# El tiempo cambia por horas de juego, no por fotogramas: mirarlo
		# cuatro veces por segundo va sobrado, y la capa corta sola si no ha
		# cambiado nada
		_sync_weather()
	# El overlay del terreno se repinta mucho mas de tarde en tarde: lo que
	# muestra es conocimiento acumulado, que crece a lo largo de jornadas, no
	# de frames. Recorre las 4.096 celdas del campo, asi que hacerlo seguido
	# seria pagar cada segundo por un dato que cambia cada dia de juego.
	if _overlay_activity != OVERLAY_OFF and frame % 180 == 0:
		_refresh_resource_overlay()
	# Lo descubierto crece por jornadas, no por frames: revisarlo cuatro veces
	# por segundo seria pagar todo el rato por un dato que casi nunca cambia
	if frame % 90 == 0:
		_check_discoveries()
		_refresh_minimap_fog()


## La ficha de depuración, leída de la FUENTE y no de un espejo.
##
## Antes salía de `TimeManager`, un autoload que no era dueño de nada: la
## simulación le paraba el reloj al arrancar -`time_speed = 0.0`- y le empujaba
## su hora cada fotograma con `sync_from`. O sea que sostenía una copia del
## tiempo cuyo único consumidor era esta etiqueta. Eliminado el autoload, esto
## lee `sim` y `GameState`, que son quienes de verdad llevan la cuenta.
func _refresh_debug_label() -> void:
	if not debug_label or not show_debug_ui or sim == null:
		return
	debug_label.text = "CityBuilder Demo\n"
	debug_label.text += "Fecha: %s, dia %d, %s, ano %d\n" % [
		Subsistence.month_name(GameState.season, sim.season_day),
		sim.day, Subsistence.season_name(GameState.season), GameState.year]
	debug_label.text += "Hora: %02d:%02d\n" % [
		int(sim.hour), int((sim.hour - float(int(sim.hour))) * 60.0)]
	debug_label.text += "Velocidad: x%s\n" % str(sim.time_scale)
	debug_label.text += "Edificios: %d\n" % architecto.get_all_buildings().size()

func _on_season_changed(_season: int, season_name: String) -> void:
	print("Nueva estación: ", season_name)


## Pincha en el mundo: si hay una cueva bajo el cursor, abre su ventana.
##
## Se hace con un rayo contra esferas y no con cuerpos fisicos porque no hace
## falta un motor de colisiones para media docena de bocas de cueva, y montar
## Area3D para esto obligaria a mantener capas y mascaras de colision.
func _pick_cave(screen: Vector2) -> CaveMouth:
	if camera == null:
		return null

	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)

	var best: CaveMouth = null
	var best_distance := INF

	for cave: CaveMouth in _caves:
		# Lo que no se ha encontrado no se puede pinchar: seria darle al
		# jugador informacion que su banda no tiene
		if not cave.discovered:
			continue
		var centre := cave.pick_position()
		var to_centre := centre - origin
		var along := to_centre.dot(direction)
		if along <= 0.0:
			continue
		# Distancia del centro al rayo: si cabe en el radio, hay acierto
		var closest := origin + direction * along
		if closest.distance_to(centre) > cave.pick_radius():
			continue
		if along < best_distance:
			best_distance = along
			best = cave

	return best


## Pincha a una persona. Mismo metodo que las cuevas: rayo contra esferas, sin
## motor de fisica de por medio.
func _pick_person(screen: Vector2) -> Inhabitant:
	if camera == null or sim == null:
		return null

	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)

	var best: Inhabitant = null
	var best_distance := INF

	for person: Inhabitant in sim.people:
		# El radio de acierto crece con la distancia: a doscientos metros una
		# persona es de dos pixeles y seria imposible acertarle
		var centre := person.position + Vector3(0.0, 0.9, 0.0)
		var to_centre := centre - origin
		var along := to_centre.dot(direction)
		if along <= 0.0:
			continue
		var radius: float = clampf(along * 0.012, 1.2, 14.0)
		if (origin + direction * along).distance_to(centre) > radius:
			continue
		if along < best_distance:
			best_distance = along
			best = person

	return best


func _on_cave_action(action: String, data: Dictionary) -> void:
	var label := String(data.get("name", "la cavidad"))
	match action:
		"ocupar":
			print("Banda: se traslada el campamento a %s" % label)
		"explorar":
			# Explorar ENSENA: es la mecanica que arregla no saber donde estan
			# las cosas, y por eso da conocimiento de golpe en su entorno
			if knowledge and terrain:
				var world := terrain.geo_to_world(
					data.get("lon", 0.0), data.get("lat", 0.0))
				for activity: int in [Subsistence.Activity.CAZA,
						Subsistence.Activity.RECOLECCION,
						Subsistence.Activity.MATERIA_PRIMA]:
					for i in range(6):
						knowledge.observe(activity as Subsistence.Activity, world, 1.0)
				_refresh_resource_overlay()
			print("Banda: reconocido el entorno de %s" % label)
		"taller":
			print("Banda: %s pasa a usarse como taller de talla" % label)
		"pintar":
			if tech and not tech.has(TechTree.Tech.ARTE):
				print("Banda: todavia no se sabe pintar (falta %s)" %
					TechTree.tech_name(TechTree.Tech.ARTE))
			else:
				print("Banda: se pinta la pared del fondo de %s" % label)


## Lo que pasa en el MUNDO, y solo si la interfaz no se lo ha quedado antes.
##
## Estaba en `_input`, que corre ANTES de que los Control vean el evento: por
## eso pulsar la X de una ventana la cerraba y ademas lanzaba el rayo contra
## el terreno, que abria otra encima. `_unhandled_input` recibe unicamente lo
## que la interfaz no ha consumido, que es justo el reparto que hacia falta.
## Es ademas donde escucha la camara, asi que ahora van los dos por el mismo
## sitio.
func _unhandled_input(event: InputEvent) -> void:
	# Pinchar una cueva abre su ficha. Va antes del match de teclas porque el
	# raton no entra ahi.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# Un clic en cualquier otro sitio borra el camino pintado: si no, se
		# quedan lineas de gente que ya ha llegado
		if paraje_markers:
			paraje_markers.hide_route()

		# Los parajes primero: son chapas que flotan sobre el terreno, o sea
		# lo mas alto y lo que el jugador esta buscando cuando pincha ahi.
		if paraje_markers and sim and ui and camera:
			var paraje := paraje_markers.pick(sim.parajes,
				camera.project_ray_origin(event.position),
				camera.project_ray_normal(event.position))
			# Si su ficha ya esta abierta, pinchar la chapa otra vez no hace
			# nada nuevo: se deja caer el clic al resto de la cadena -persona,
			# recurso, terreno- en vez de consumirlo aqui sin mas.
			if paraje and not ui.paraje_is_open(paraje):
				ui.show_paraje(paraje)
				get_viewport().set_input_as_handled()
				return

			# Y las cumbres, con el mismo alfiler: también son un sitio al
			# que se manda gente, aunque no se trabaje en ellas
			var peak := paraje_markers.pick_peak(sim.peaks(),
				camera.project_ray_origin(event.position),
				camera.project_ray_normal(event.position))
			if not peak.is_empty():
				ui.show_peak(peak)
				get_viewport().set_input_as_handled()
				return

		# Las personas despues: son mas pequenas y estan mas cerca de la
		# camara, asi que si compiten con una cueva gana la persona
		var person := _pick_person(event.position)
		if person and ui:
			ui.show_person(person)
			# Y se le pinta el camino que lleva: es lo que hace visible que la
			# banda rodea el canchal en vez de cruzarlo
			if paraje_markers:
				paraje_markers.show_route(person.remaining_route(),
					person.position, terrain)
			get_viewport().set_input_as_handled()
			return

		# Y despues los recursos del suelo, antes que las cuevas: son mas
		# pequenos y estan mas cerca
		if props and ui and camera:
			var hit := props.pick(camera.project_ray_origin(event.position),
				camera.project_ray_normal(event.position))
			if not hit.is_empty():
				ui.show_resource(hit["kind"] as Materia.Kind, hit["pos"],
					hit["from"] as Subsistence.Activity)
				get_viewport().set_input_as_handled()
				return

		var cave := _pick_cave(event.position)
		if cave and ui:
			ui.show_feature(cave.feature, cave.pick_position(),
				sim.home_position if sim else Vector3.ZERO)
			get_viewport().set_input_as_handled()
			return

		# Y por ultimo el propio suelo. Es lo que faltaba para que el clic sea
		# un verbo en todas partes: hasta ahora el terreno desnudo no consumia
		# el clic y no habia forma de decir «id a mirar alli».
		if ui and camera and terrain and not _build_mode:
			var ground := _pick_ground(event.position)
			if ground != Vector3.INF:
				# Todavia puede caer dentro de la mancha de un paraje: la chapa
				# solo cubre su propio centro, y el sitio es mucho mas grande
				# que eso. Sin esto, pinchar el borde de un avellanar abria la
				# ficha del terreno en vez de la del avellanar.
				var here_paraje := sim.parajes.at(ground) if sim else null
				# Y si esa ficha YA esta abierta, el punto se trata como
				# terreno normal: sin esto, cualquier clic dentro de una
				# mancha grande -a veces un buen trozo del mapa- se quedaba
				# reabriendo la misma ficha para siempre y el terreno de ahi
				# dentro dejaba de responder a nada.
				if here_paraje and not ui.paraje_is_open(here_paraje):
					ui.show_paraje(here_paraje)
				else:
					ui.show_ground(ground, terrain)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				# Primero cierra lo que tengas delante. Salirse del mapa entero
				# al pulsar ESC daba un susto cada vez: eso ahora es el boton
				# del minimapa, que es donde se busca.
				if ui and ui.close_topmost():
					pass
				elif Expedition.is_active():
					_return_to_region()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				if sim:
					var index: int = event.keycode - KEY_1
					var acts: Array[int] = []
					for a: int in sim.work_sites.keys():
						acts.append(a)
					acts.sort()
					if index < acts.size():
						sim.assign_all(acts[index] as Subsistence.Activity)
						_update_band_panel()
			KEY_R:
				_cycle_overlay()
			KEY_N:
				# La capa de navegacion: rojo lo que no se pisa, naranja lo que
				# se pisa pero no se alcanza desde el abrigo. Es la unica forma
				# de comprobar si la rejilla esta acertando.
				if nav_overlay and sim:
					var on := nav_overlay.toggle(sim.navgrid(),
						sim.home_position, terrain)
					print("Navegacion: %s" % ["visible" if on else "oculta"])
					if on:
						print("   " + NavOverlay.tally_text(
							sim.navgrid(), sim.home_position))
			KEY_B:
				# Modo construccion: mientras esta activo el clic levanta, y
				# mientras no, selecciona
				_build_mode = not _build_mode
				print("Modo construccion: %s" % ("activo" if _build_mode else "apagado"))
			# El teclado mueve LA MISMA velocidad que los botones del reloj.
			# Hubo un tiempo en que tocaba un segundo reloj, y acelerar por
			# teclado movía el sol dejando a la banda a su ritmo. Ya no hay
			# segundo reloj: sólo manda `sim`.
			KEY_P, KEY_SPACE:
				if sim:
					sim.time_scale = 0.0 if sim.time_scale > 0.0 else 1.0
			KEY_F1:
				if sim: sim.time_scale = 1.0
			KEY_F2:
				if sim: sim.time_scale = 3.0
			KEY_F3:
				if sim: sim.time_scale = 5.0
	
	# Construir pasa a ser un MODO, no lo que hace el clic por defecto. Con el
	# UI orientado a raton el clic izquierdo sirve para seleccionar -pinchar
	# una cueva y ver su ficha-, y dejarlo tambien construyendo significaba
	# levantar una cabana cada vez que el jugador miraba algo.
	if event is InputEventMouseButton and _build_mode:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_place_building_at_mouse()


func _try_place_building_at_mouse() -> void:
	if not camera:
		return
	
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit_pos: Vector3 = result.position
		# Sin busqueda de alternativa: donde el jugador hace click, o nada
		_place_hut_at(hit_pos, false)


## Donde toca el terreno el rayo del cursor, o INF si no lo toca.
##
## Se avanza por el rayo comparando con la altura del terreno en vez de usar
## el motor de fisica: es lo mismo que hace el resto del picking del juego, no
## depende de capas de colision, y con un paso grueso y luego uno fino sale
## exacto de sobra para senalar un rumbo.
func _pick_ground(screen: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if direction.y >= -0.001:
		return Vector3.INF  # mirando al cielo

	var far := 12000.0
	var step := 24.0
	var travelled := 0.0
	var last := origin

	while travelled < far:
		var point := origin + direction * travelled
		if point.y <= terrain.get_height_at(point):
			# Afinado entre el ultimo punto por encima y este por debajo
			for i in range(12):
				var middle := (last + point) * 0.5
				if middle.y <= terrain.get_height_at(middle):
					point = middle
				else:
					last = middle
			if point.x < 0.0 or point.z < 0.0 					or point.x > float(terrain_size.x) 					or point.z > float(terrain_size.y):
				return Vector3.INF
			point.y = terrain.get_height_at(point)
			return point
		last = point
		travelled += step

	return Vector3.INF


## El entorno del mundo, para poder cerrar el valle de niebla cuando toque.
##
## Se busca en vez de exigirlo montado: la escena lo crea por su cuenta y este
## fichero no deberia depender de en que rama acabe colgado.
func _sync_weather() -> void:
	if weather_view and sim and sim.weather:
		weather_view.show_weather(sim.weather.kind)


func _find_environment() -> Environment:
	for node: Node in get_tree().get_nodes_in_group("world_environment"):
		var holder := node as WorldEnvironment
		if holder and holder.environment:
			return holder.environment
	var found := _first_world_environment(get_tree().root)
	return found.environment if found else null


func _first_world_environment(node: Node) -> WorldEnvironment:
	var holder := node as WorldEnvironment
	if holder and holder.environment:
		return holder
	for child: Node in node.get_children():
		var deeper := _first_world_environment(child)
		if deeper:
			return deeper
	return null
