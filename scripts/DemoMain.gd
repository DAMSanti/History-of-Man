extends Node3D
## La partida local: el valle, la banda y la interfaz.
##
## Monta el terreno, el campo de recursos, la fauna, la vegetacion, la
## simulacion -[SettlementSim]- y la interfaz -[GameUI]-, y los conecta. Es el
## unico sitio donde se cablean unos con otros.

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

## Referencias a nodos
var terrain: TerrainGenerator
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


## El minimapa, la niebla y las capas de encima. Ver [Minimapa].
var minimapa: Minimapa = Minimapa.new(self)

## Textura del overlay de recursos sobre el terreno. Una sola imagen para todo
## el recuadro en vez de miles de nodos: ver `_refresh_resource_overlay`.
var _overlay_image: Image
var _overlay_texture: ImageTexture
var tech: TechTree
var ui: GameUI

## El recuento de lo que hay pintado en el mundo, para la pestaña de
## Entidades. Ver [EntityCensus].
var census: EntityCensus

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

## El monton de desechos, que crece con la partida y tiñe el suelo. Ver
## [Conchero] y [Desechos].
var conchero: Conchero

## Lo que está haciendo cada cual, sobre su cabeza. Ver [WorkMarkers].
var craft_markers: WorkMarkers
var weather_view: WeatherView
var nav_overlay: NavOverlay

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
	_phase_start(); _setup_terrain(); _phase_end("_setup_terrain")
	# Vegetacion desactivada: los arboles se colocaban con base_scale de 1
	# unidad sobre un mapa donde 1 unidad = 1 m, o sea arbolitos de un metro
	# que desde la camara solo se leian como manchas oscuras en el suelo.
	# Vuelve cuando haya especies de verdad con porte y altura por era.
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
		_phase_start(); minimapa._build_minimap(_minimap_canvas); _phase_end("_build_minimap")

	# Poblar recursos

	# Visualizar recursos

	# Elementos reales del emplazamiento: cuevas, yacimientos, ruinas
	_phase_start(); _place_site_features(); _phase_end("_place_site_features")

	# La gente. El mapa local corre por dias; el regional, por estaciones.
	_phase_start(); _start_settlement(); _phase_end("_start_settlement")

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


## Levanta el asentamiento con la gente de la partida.
##
## EL ORDEN IMPORTA, y por eso esto es una lista de fases y no un bloque de
## doscientas lineas: la simulacion antes que los tajos -asignarlos necesita
## saber si se llega-, y el censo despues de los props, el bosque y la fauna,
## porque les pregunta a ellos y montado antes se queda con referencias nulas.
func _start_settlement() -> void:
	if not Expedition.is_active() or terrain == null:
		return

	var home := terrain.geo_to_world(Expedition.site.lon, Expedition.site.lat)

	_levantar_simulacion(home)
	_levantar_marcadores()
	_levantar_conocimiento(home)
	_levantar_vegetacion()
	_levantar_hogar()
	_levantar_fauna_y_tecnica()
	_levantar_interfaz()
	_elegir_tajos(home)


## La simulacion y el campo de recursos: lo primero de todo, porque el resto
## le pregunta a ellos.
##
## `setup` va ANTES que nada mas porque asignar los tajos ya necesita saber
## si se llega a ellos, y eso lo decide el terreno que se le pasa aqui.
func _levantar_simulacion(home: Vector3) -> void:
	sim = SettlementSim.new()
	sim.name = "Asentamiento"
	add_child(sim)

	# El setup va PRIMERO porque asignar los tajos ya necesita saber si se
	# llega a ellos, y eso lo decide el terreno que se le pasa aqui
	sim.setup(terrain, home, GameState.population, GameState.food)
	sim.day_passed.connect(_on_day_passed)

	# Lo que el valle tiene, repartido en manchas y con su estacion
	field = ResourceMapper.build(terrain, home)


## Los marcadores y visores del mundo: el asa por la que el jugador agarra
## cada cosa.
##
## Sin ellos los parajes, las trampas y las nasas existen pero no se pueden
## pinchar, y no poder pincharlos es seguir mandando con numeros en una
## pestana.
func _levantar_marcadores() -> void:
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


## La cronica y lo que la banda sabe del valle, que al llegar es nada.
##
## Sabe que en el rio hay peces; no sabe en que remanso. Eso lo aprende
## pisandolo. Lo de alrededor del campamento si lo conoce: vive ahi.
func _levantar_conocimiento(home: Vector3) -> void:
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


## Lo que se ve crecer: los recursos en el suelo, la hierba y el bosque.
func _levantar_vegetacion() -> void:
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


## El fuego del abrigo y las hogueras de quien duerme fuera, con la cueva de
## casa mandando donde se duerme y donde se hace corro.
func _levantar_hogar() -> void:
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

	# Y el monton, a un lado del abrigo: donde se tira lo que sobra, que es
	# cerca pero no en la puerta.
	conchero = Conchero.new()
	conchero.name = "Conchero"
	add_child(conchero)
	conchero.setup(sim, terrain,
		sim.home_position + Vector3(14.0, 0.0, 9.0))


## La fauna que anda de verdad por el valle, y el arbol de tecnicas.
func _levantar_fauna_y_tecnica() -> void:
	herds = WildlifeHerds.new()
	herds.name = "Wildlife"
	add_child(herds)
	herds.setup(terrain, field)
	# Y con ella su poblacion: la caza resta y la cria repone, con techo. Se
	# monta DESPUES de sembrar la fauna porque el techo sale del censo real.
	herds.poblaciones = Poblaciones.new(herds)
	sim.poblaciones = herds.poblaciones
	# La fauna anda al compas de la partida: en pausa no se mueve. Ver
	# `WildlifeHerds.sim`.
	herds.sim = sim
	# Y la banda caza LO QUE ANDA POR AHI, no una media. Sin esta linea la caza
	# se resuelve con la tabla de [Hunting] -el respaldo de `Caceria._hunt_step`
	# para las pruebas sin valle-; con ella, el cazador acecha a un ciervo de
	# los que se ven. Ver [Hunt] y [Caceria].
	#
	# La fauna cuelga de [Caceria] y no del simulador. Estuvo puesta como
	# `sim.caceria.wildlife` -de cuando la caceria vivia dentro de `SettlementSim`- y
	# al sacarla nadie corrigio esta linea: GDScript no avisa de asignar una
	# propiedad que no existe hasta que corre, las pruebas montan la fauna a
	# mano y las sondas la piden por `sim.caceria.wildlife`, asi que EN LA
	# PARTIDA DE VERDAD la caza llevaba resolviendose por la tabla vieja sin
	# que se notara. Aparecio al limpiar el proyecto.
	if sim and sim.caceria:
		sim.caceria.wildlife = herds

	tech = TechTree.new()
	# La simulacion consulta el arbol de verdad, no solo la ficha: con que se
	# pesca hoy sale de ahi -ver `Fishing`-, y sin el solo se pesca a mano.
	if sim:
		sim.techs = tech
		# Y el arbol consulta la despensa: aprender cuesta material, no solo
		# jornadas. Ver `TechTree.LEARNING_COST`.
		tech.larder = sim.store


## La interfaz, el censo de lo pintado y las capas que van encima.
func _levantar_interfaz() -> void:
	# La interfaz se viste con los materiales de la era ANTES de construir
	# nada: los colores son `static var` y quien ya los leyo no se entera.
	# Ver [PielDeEra] y docs/INTERFAZ.md.
	UISkin.vestir(Expedition.era if Expedition.is_active() else Site.Era.PALEOLITICO)

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
		ui.barra.watch_moments(sim)

	minimapa._build_resource_overlay()
	# Las cuevas del entorno del campamento salen ya descubiertas, por lo mismo
	_check_discoveries()


## Donde se va a trabajar: de los sitios que ofrece el valle, los que de
## verdad se alcanzan.
func _elegir_tajos(home: Vector3) -> void:
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

	if walkable.call(point) and (sim == null or sim.marcha.can_reach(point)):
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
			if sim == null or sim.marcha.can_reach(candidate):
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
				if score > best_river_score and sim.marcha.can_reach(point, RIVER_APPROACH_M):
					best_river_score = score
					best_river = point

			if terrain.is_underwater(point) and distance < best_coast_dist \
					and sim.marcha.can_reach(point, RIVER_APPROACH_M):
				best_coast_dist = distance
				best_coast = point

			# Coto de caza: llano y despejado, ni pegado a casa ni lejisimos
			var hunt := (1.0 - clampf(slope, 0.0, 1.0)) - absf(distance - 700.0) / 2600.0
			if hunt > best_hunt_score and sim.marcha.can_reach(point):
				best_hunt_score = hunt
				best_hunt = point

			# Recoleccion: ladera suave y cerca
			var gather_fit := 1.0 - clampf(slope * 0.7, 0.0, 1.0)
			var gather := gather_fit * clampf(1.0 - distance / 1400.0, 0.05, 1.0)
			if gather > best_gather_score and sim.marcha.can_reach(point):
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
		if sim.marcha.can_reach(spot):
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
		var grid := sim.marcha._navgrid()
		paraje_markers.refresh(sim.parajes, terrain,
			func(a: Vector3, b: Vector3) -> bool: return grid.connected(a, b))
		paraje_markers.refresh_peaks(sim.cumbres.peaks(), terrain)
	if trap_markers and sim:
		trap_markers.refresh(sim.trampas.traps, terrain)
	if nasa_markers and sim:
		nasa_markers.refresh(sim.nasas_line.nasas, terrain)
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
			sim.population(), sim.store.food_rations(), sim.despensa.hungry_count()],
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
		minimapa._update_minimap()
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
		minimapa._refresh_resource_overlay()
	# Lo descubierto crece por jornadas, no por frames: revisarlo cuatro veces
	# por segundo seria pagar todo el rato por un dato que casi nunca cambia
	if frame % 90 == 0:
		_check_discoveries()
		minimapa._refresh_minimap_fog()


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
				minimapa._refresh_resource_overlay()
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
	# El raton va antes que las teclas porque no entra en el match.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_pinchar_en_el_mundo(event as InputEventMouseButton)

	if event is InputEventKey and event.pressed:
		_tecla(event as InputEventKey)


## Que pasa al pinchar en el mundo, por orden de prioridad.
##
## El orden NO es casual y es lo unico que importa aqui: los parajes son chapas
## que flotan sobre el terreno, o sea lo mas alto y lo que el jugador esta
## buscando; las personas van antes que las cuevas porque son mas pequenas y
## estan mas cerca de la camara; y el suelo desnudo va el ultimo, para que el
## clic sea un verbo en todas partes.
func _pinchar_en_el_mundo(event: InputEventMouseButton) -> void:
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
			ui.sitios.show_paraje(paraje)
			get_viewport().set_input_as_handled()
			return

		# Y las cumbres, con el mismo alfiler: también son un sitio al
		# que se manda gente, aunque no se trabaje en ellas
		var peak := paraje_markers.pick_peak(sim.cumbres.peaks(),
			camera.project_ray_origin(event.position),
			camera.project_ray_normal(event.position))
		if not peak.is_empty():
			ui.sitios.show_peak(peak)
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
			ui.sitios.show_resource(hit["kind"] as Materia.Kind, hit["pos"],
				hit["from"] as Subsistence.Activity)
			get_viewport().set_input_as_handled()
			return

	var cave := _pick_cave(event.position)
	if cave and ui:
		ui.sitios.show_feature(cave.feature, cave.pick_position(),
			sim.home_position if sim else Vector3.ZERO)
		get_viewport().set_input_as_handled()
		return

	# Y por ultimo el propio suelo. Es lo que faltaba para que el clic sea
	# un verbo en todas partes: hasta ahora el terreno desnudo no consumia
	# el clic y no habia forma de decir «id a mirar alli».
	if ui and camera and terrain:
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
				ui.sitios.show_paraje(here_paraje)
			else:
				ui.sitios.show_ground(ground, terrain)
			get_viewport().set_input_as_handled()
			return


## Los atajos de teclado.
func _tecla(event: InputEventKey) -> void:
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
			minimapa._cycle_overlay()
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
