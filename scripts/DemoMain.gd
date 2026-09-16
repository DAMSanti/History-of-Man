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

## El mapa con gente que esta escena mira. Lo que decide partida vive ahi; la
## escena es su vista. Ver [Campamento] y SISTEMAS §23.
var campamento: Campamento

## Si el campamento ya estaba vivo y la escena sólo lo mira: ni se monta ni se
## empieza ni se vuelca. Ver [_montar_el_campamento].
var _adoptado := false

## Si la visita va con el reloj de la partida corriendo. Ver [_montar_la_visita].
var _de_visita_con_reloj := false

## Si la escena volcó una partida guardada: detrás van los demás campamentos.
var _retomada := false


## Referencias a nodos. `terrain`, `sim`, `field`, `knowledge`, `herds`, `tech` y
## `_caves` son del campamento: aqui se guardan para no reescribir la vista.
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

## Las pasarelas levantadas, sobre el terreno. Ver [PasarelaView].
var pasarela_view: PasarelaView

## Las tumbas de la banda sobre el terreno. Ver [SepulturasView].
var sepulturas_view: SepulturasView

## La hoguera en la boca de la cueva. Ver [HearthFire].
var hearth_fire: HearthFire

## El secadero, el paraviento, el lavadero y los troncos. Ver [ObrasDelAbrigo].
var obras_del_abrigo: ObrasDelAbrigo

## Qué alfileres se ven en el valle. Lo cuelga [Minimapa] debajo del mapa.
var filtro_de_marcadores: FiltroDeMarcadores

## El menú de la partida, el que abre ESC. Ver [MenuDelJuego].
var menu_del_juego: MenuDelJuego

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
## Hasta dónde se acerca la cámara del valle, en metros de órbita: casi a pie
## de tierra. Petición del usuario del 2026-09-14; ver [_setup_camera].
const CAMARA_A_PIE_DE_TIERRA := 3.5

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


## Las etapas del montaje, con lo que cuesta cada una en milisegundos, medido con
## `CargaProbe` con la pantalla puesta (ventana, bosque Medio, 2026-09-15): el relieve
## 0,65 s; los alrededores, el minimapa y los elementos, 0,6-0,65; la simulación y lo que
## la banda sabe al llegar, 2,2 al fundar y 0,15 al retomar —se toma lo de en medio—; los
## recursos visibles, 0,65-0,7; sembrar el bosque, 9,5-9,8; el bosque de lejos, 3,6-3,9
## —eran 2,4-2,9 antes de cargar sus modelos en un hilo y ceder por variante—; y el hogar,
## la fauna y la interfaz, 0,25-0,5. Son los pesos de la barra. Ver [Carga] e INTERFAZ §9.
##
## Volviendo al mismo valle no se siembra ([Forest.siembras]) y la etapa se da por hecha
## con lo que tardó: lo de lejos pasa a ser media carga, y con su peso viejo a media barra
## había pasado sólo el 36 % del tiempo.
const ETAPAS := [
	["Levantando el relieve", 650.0],
	["Dibujando los alrededores", 630.0],
	["Despertando a la banda", 1200.0],
	["Poniendo a la vista lo que da el valle", 660.0],
	["Sembrando el bosque", 9650.0],
	["Plantando el bosque de lejos", 3700.0],
	["Encendiendo el hogar", 400.0],
]

## Si la escena ya está en pie. Con pantalla de carga el montaje dura varios cuadros, y
## hasta aquí no se juega ni se puede dar por hecho que exista lo de dentro.
var montado := false
signal se_monto


func _ready() -> void:
	var t_ready0 := Time.get_ticks_msec()
	print("=== Iniciando Demo ===")
	# CON PANTALLA DE CARGA, EL MAPA SE MONTA EN VARIOS CUADROS, y mientras tanto la
	# escena está parada: sus `_process` darían por hecho cosas que todavía no existen.
	# Sin pantalla —una sonda— se monta de un tirón, como siempre. INTERFAZ §9.
	var cargando := Carga.abierta()
	if cargando:
		process_mode = Node.PROCESS_MODE_DISABLED
		Carga.etapas(ETAPAS)
		Carga.etapa(0)
	_phase_start(); _apply_expedition(); _phase_end("_apply_expedition")
	_phase_start(); _montar_el_campamento(); _phase_end("_montar_el_campamento")
	# El cambio de escena ya se ha comido parte de este cuadro: si no cede antes del
	# relieve, el primer cuadro de la carga pasaba de 500 ms (medido, 521).
	await Carga.ceder()
	# Vegetacion desactivada: los arboles se colocaban con base_scale de 1
	# unidad sobre un mapa donde 1 unidad = 1 m, o sea arbolitos de un metro
	# que desde la camara solo se leian como manchas oscuras en el suelo.
	# Vuelve cuando haya especies de verdad con porte y altura por era.
	_phase_start(); _setup_camera(); _phase_end("_setup_camera")
	_phase_start(); _setup_ui(); _phase_end("_setup_ui")
	_phase_start(); _setup_performance_overlay(); _phase_end("_setup_performance_overlay")
	_phase_start(); _connect_signals(); _phase_end("_connect_signals")

	# Las bocas de cueva se excavan en la malla ANTES de generarla
	# Un campamento adoptado ya tiene su relieve generado, con las bocas.
	if not _adoptado:
		_phase_start(); campamento.marcar_las_bocas(); _phase_end("marcar_las_bocas")
		# La malla de la caché del relieve, cargada aparte y retenida hasta generar: el
		# `load` de dentro de `generate` la encuentra hecha. Sin esto el relieve era un
		# cuadro de 680 ms al fundar.
		var _malla_cacheada: Resource = null
		var ruta_de_la_malla := terrain.malla._cache_base_path() if terrain.malla != null else ""
		if Carga.abierta() and not ruta_de_la_malla.is_empty() and ResourceLoader.exists(ruta_de_la_malla):
			_malla_cacheada = await Carga.cargar(ruta_de_la_malla)
		await Carga.ceder(500.0)

		# Generar mundo
		print("Generando terreno...")
		_phase_start()
		await terrain.generate(Carga.ceder_y_avanzar if Carga.abierta() else Callable())
		_phase_end("terrain.generate (mapa jugable)")
	print("Terreno generado. Mesh: ", terrain._terrain_mesh)
	Carga.siguiente()
	await Carga.ceder()

	# Las ocho casillas de alrededor, en gris: sin ellas el mapa se corta a
	# cuchillo y detras no hay nada
	_phase_start(); _build_surroundings(); _phase_end("_build_surroundings (8 casillas)")
	await Carga.ceder()

	# Ahora si: el minimapa se pinta del relieve ya generado
	if _minimap_canvas:
		_phase_start(); await minimapa._build_minimap(_minimap_canvas); _phase_end("_build_minimap")
	await Carga.ceder()

	# Poblar recursos

	# Visualizar recursos

	# Elementos reales del emplazamiento: cuevas, yacimientos, ruinas
	_phase_start(); _place_site_features(); _phase_end("_place_site_features")

	# La gente. El mapa local corre por dias; el regional, por estaciones.
	_phase_start(); await _start_settlement(); _phase_end("_start_settlement")

	await Carga.ceder(200.0)
	print("[TIMING] === _ready() TOTAL: %d ms ===" % (Time.get_ticks_msec() - t_ready0))
	print("=== Demo inicializado correctamente ===")
	montado = true
	if cargando:
		process_mode = Node.PROCESS_MODE_INHERIT
		Carga.cerrar()
	se_monto.emit()


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


## Crea el campamento y su relieve con los ajustes de la escena.
##
## El relieve es del campamento y no de la escena: un mapa que no se mira sigue
## necesitando saber por dónde se pasa. Ver [Campamento] y SISTEMAS §23.
##
## **UN CAMPAMENTO VIVO SE ADOPTA, no se monta otro** (SISTEMAS §23, tarea 14):
## si la partida ya lo lleva —se fundó al llegar un viaje, o se miró antes y
## siguió simulando desde fuera—, la escena lo mete en su árbol y le pone la vista
## encima. Montarlo de nuevo sería otra simulación del mismo valle, y volcar el
## guardado encima lo devolvería al último autoguardado.
func _montar_el_campamento() -> void:
	var vivo: Campamento = null
	if Expedition.is_active() and not Expedition.visita:
		vivo = Campamentos.de_sitio(Expedition.site.id)
	if vivo != null:
		_adoptado = true
		campamento = vivo
		if vivo.get_parent() != null:
			vivo.get_parent().remove_child(vivo)
		add_child(vivo)
		vivo.sim.se_mira = true
		terrain = vivo.terrain
		# Lo guardado es más viejo que lo vivo: no se vuelca.
		Expedition.retomando = false
		return
	campamento = Campamento.new()
	campamento.name = "Campamento"
	add_child(campamento)
	campamento.preparar_el_relieve(terrain_size, terrain_resolution, max_height,
		seed_value, sea_level, use_real_terrain, heightmap_path, region_offset)
	campamento.relieve = heightmap_path
	campamento.recuadro = region_offset
	terrain = campamento.terrain


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
	# LAS CUEVAS YA ESTAN: las pone el campamento, porque son partida además de
	# geometría —ver [Campamento.colocar_las_cuevas]—. Aquí van sólo los jalones.
	if not _adoptado:
		campamento.colocar_las_cuevas()
	_caves = campamento.caves
	placed += _caves.size()
	var features := Expedition.site.features_in(Expedition.era)
	for indice in range(features.size()):
		var f: Dictionary = features[indice]
		# Las simas no se pintan: son pozos verticales de catalogo
		# espeleologico, no sitios que le importen al jugador. Siguen en los
		# datos porque senalan karst, que es pista de exploracion.
		if int(f.get("class", Site.Feature.OTRO)) == Site.Feature.SIMA:
			continue
		if int(f.get("class", Site.Feature.OTRO)) == Site.Feature.ABRIGO:
			continue

		var world := terrain.geo_to_world(f.get("lon", 0.0), f.get("lat", 0.0))
		# Puede caer fuera del recuadro de 4 km aunque este a menos de 2 km
		# del centro, porque el recuadro es cuadrado y el radio circular
		if world.x < 0.0 or world.z < 0.0 				or world.x > terrain_size.x or world.z > terrain_size.y:
			continue
		world.y = terrain.get_height_at(world)

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

	# EL ORDEN ES EL DE ANTES DE SACAR EL CAMPAMENTO, y lo que va por el
	# campamento consume azar de la partida: ver [Campamento]. Lo de la escena,
	# intercalado, es vista y no toca la simulacion.
	# Adoptado, lo del campamento ya está hecho: sólo se monta la vista.
	Carga.siguiente()
	# Lo que cuesta la simulación, 370 ms medidos al fundar: se cede antes si no cabe.
	await Carga.ceder(400.0)
	var _t := Time.get_ticks_msec()
	if not _adoptado:
		campamento.levantar_la_simulacion(home,
			0 if Expedition.visita else GameState.population, GameState.food)
	print("[TIMING]   levantar_la_simulacion: %d ms" % (Time.get_ticks_msec() - _t))
	sim = campamento.sim
	field = campamento.field
	sim.day_passed.connect(_on_day_passed)
	await Carga.ceder()
	_t = Time.get_ticks_msec()
	_levantar_marcadores()
	print("[TIMING]   _levantar_marcadores: %d ms" % (Time.get_ticks_msec() - _t))
	_t = Time.get_ticks_msec()
	if not _adoptado:
		await campamento.levantar_el_conocimiento(home, Carga.ceder_y_avanzar)
	print("[TIMING]   levantar_el_conocimiento: %d ms" % (Time.get_ticks_msec() - _t))
	knowledge = campamento.knowledge
	Carga.siguiente()
	await Carga.ceder()
	_t = Time.get_ticks_msec()
	await _levantar_vegetacion()
	print("[TIMING]   _levantar_vegetacion: %d ms" % (Time.get_ticks_msec() - _t))
	Carga.siguiente()
	await Carga.ceder()
	_t = Time.get_ticks_msec()
	if not _adoptado:
		campamento.asentar_en_la_cueva()
	print("[TIMING]   asentar_en_la_cueva: %d ms" % (Time.get_ticks_msec() - _t))
	_t = Time.get_ticks_msec()
	_levantar_hogar()
	print("[TIMING]   _levantar_hogar: %d ms" % (Time.get_ticks_msec() - _t))
	# La fauna y la técnica, 570 ms medidos al fundar.
	await Carga.ceder(600.0)
	_t = Time.get_ticks_msec()
	if not _adoptado:
		campamento.levantar_fauna_y_tecnica()
	print("[TIMING]   levantar_fauna_y_tecnica: %d ms" % (Time.get_ticks_msec() - _t))
	herds = campamento.herds
	tech = campamento.tech
	# El aviso en pantalla de la tecnica aprendida. Contarla es del campamento.
	sim.tecnica_aprendida.connect(_on_tecnica_aprendida)
	await Carga.ceder(200.0)
	_t = Time.get_ticks_msec()
	_levantar_interfaz()
	print("[TIMING]   _levantar_interfaz: %d ms" % (Time.get_ticks_msec() - _t))
	if _adoptado or Expedition.visita:
		return
	# Los tajos, 170-290 ms: el último paso largo antes de soltar la pantalla.
	await Carga.ceder(300.0)
	_t = Time.get_ticks_msec()
	campamento.elegir_tajos(home)
	print("[TIMING]   elegir_tajos: %d ms" % (Time.get_ticks_msec() - _t))
	# Y DESDE AQUÍ LO LLEVA EL RELOJ DE LA PARTIDA, que sobrevive a la escena. Va
	# al final, como en `CampamentosProbe`: el reloj toma la velocidad del primer
	# campamento, que `setup` deja en pausa hasta contestar la decisión del
	# arranque. Ver [RelojDeLaPartida.dirigir].
	Campamentos.alta(get_tree(), campamento)
	if _retomada:
		var errores := Guardado.retomar_los_demas(get_tree(),
			load(MenuPrincipal.SITIOS) as SiteSet, Expedition.site.id)
		if not errores.is_empty():
			print("Los demás campamentos se retoman a medias: %s" % ", ".join(errores))


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

	pasarela_view = PasarelaView.new()
	pasarela_view.name = "Pasarelas"
	add_child(pasarela_view)

	sepulturas_view = SepulturasView.new()
	sepulturas_view.name = "Sepulturas"
	add_child(sepulturas_view)

	# Y lo que está haciendo cada cual, encima de su cabeza: sin esto quien
	# trabaja y quien da vueltas se ven exactamente igual.
	craft_markers = WorkMarkers.new()
	craft_markers.name = "Faena"
	add_child(craft_markers)
	craft_markers.setup(camera, sim)

	trail_view = TrailView.new()
	trail_view.name = "Rastros"
	add_child(trail_view)
	trail_view.setup(sim)

	# Y el tiempo, que hasta ahora solo existia en un rotulo. Llevaba desde
	# que se implanto decidiendo lo que cunde la jornada, lo que se anda y lo
	# que se arriesga en una pared, y el jugador se enteraba leyendo. Un
	# temporal que solo esta en una etiqueta no es un temporal: es un numero.
	weather_view = WeatherView.new()
	weather_view.name = "Tiempo"
	add_child(weather_view)
	weather_view.setup(camera, _find_environment())
	weather_view.pintar_el_suelo_en(terrain, sim.temporada)
	# La niebla de valle, horneada sobre este relieve (GRAFICOS §7.4).
	var niebla_de_valle := NieblaDeValle.new()
	add_child(niebla_de_valle)
	niebla_de_valle.montar(terrain)
	weather_view.niebla = niebla_de_valle

	# Las salpicaduras de los rápidos, en Ultra: unos pocos emisores cerca de la cámara.
	# GRAFICOS §7.3.
	var salpicaduras := SalpicadurasDelRio.new()
	add_child(salpicaduras)
	salpicaduras.setup(terrain, camera)

	# La capa que ensena lo que el juego considera intransitable. Apagada por
	# defecto: es una herramienta de mirar por dentro, no una capa de partida.
	nav_overlay = NavOverlay.new()
	nav_overlay.name = "Navegacion"
	add_child(nav_overlay)


## Lo que se ve crecer: los recursos en el suelo, la hierba y el bosque.
func _levantar_vegetacion() -> void:
	# Los recursos, VISIBLES en el terreno. Hasta ahora la abundancia existia
	# en los numeros y en una capa de color del minimapa, pero no en el mundo.
	props = ResourceProps.new()
	props.name = "Recursos"
	add_child(props)
	# Las bocas de cueva, ANTES de sembrar: alrededor de cada una no va nada.
	# Ver [ResourceProps.LEJOS_DE_LA_BOCA].
	for cave: CaveMouth in _caves:
		props.bocas.append(cave.pick_position())
	await props.setup(terrain, field)
	# Las piedras que asoman en los rápidos, con las peñas de la misma biblioteca. Vista:
	# no tocan la partida. GRAFICOS §7.3.
	var piedras := PiedrasDelRio.new()
	add_child(piedras)
	piedras.setup(terrain, props._library)

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
	# Las bocas de cueva, ANTES de sembrar: alrededor de cada una se deja un
	# claro. Ver [Forest.RADIO_DEL_CLARO].
	# `pick_position` y no `global_position`: el nodo de la boca se queda en el
	# origen y lo que está en su sitio es la geometría, construida en
	# `CaveMouth.build` alrededor de la boca.
	for cave: CaveMouth in _caves:
		forest.claros.append(cave.pick_position())
	Carga.siguiente()
	await Carga.ceder()
	await forest.setup(terrain)
	Carga.siguiente()
	await Carga.ceder()
	await forest.levantar_lejos()


## El fuego del abrigo y las hogueras de quien duerme fuera, con la cueva de
## casa mandando donde se duerme y donde se hace corro.
func _levantar_hogar() -> void:
	# La hoguera del abrigo. Va aquí y no dentro de la cueva porque no es parte
	# de la cueva: es una obra de la banda, aparece cuando la levantan y se apaga
	# cuando se les acaba la leña. Ver [HearthFire].
	hearth_fire = HearthFire.new()
	hearth_fire.name = "Hoguera"
	add_child(hearth_fire)
	# La cueva de casa, que el campamento ya ha asentado: dónde se duerme y la
	# campa. Ver [Campamento.asentar_en_la_cueva].
	var home_cave := campamento.cueva_en(sim.home_position)
	# Y si la banda se muda, la hoguera y las obras que se ven van con ella; los
	# tajos, los busca el campamento. Ver [Traslado].
	sim.campamento_trasladado.connect(_on_campamento_trasladado)

	# La hoguera va en la campa de la boca, no encima del abrigo: es donde se
	# hace el fuego de una cueva.
	hearth_fire.setup(sim, terrain,
		sim.home_forecourt if sim.home_forecourt != Vector3.ZERO
		else sim.home_position)

	# Y el resto de lo que la banda levanta en el abrigo: secadero, paraviento,
	# lavadero y los troncos del corro. Ver [ObrasDelAbrigo].
	obras_del_abrigo = ObrasDelAbrigo.new()
	obras_del_abrigo.name = "ObrasDelAbrigo"
	add_child(obras_del_abrigo)
	_plantar_obras(home_cave)

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
	conchero.setup(sim, terrain, _sitio_del_conchero(home_cave,
		sim.home_forecourt if sim.home_forecourt != Vector3.ZERO else sim.home_position))

	# El paisaje sigue al calendario: la cota de nieve baja en invierno y se
	# retira en verano. Se asienta ya en la estacion de arranque -si no, la
	# partida empieza con la nieve de la estacion anterior y tarda doce
	# jornadas en corregirse- y luego se mueve sola. Ver [Temporada].
	# La temporada ya la asentó el campamento. Ver [Campamento.asentar_en_la_cueva].
	sim.day_passed.connect(_on_dia_para_el_paisaje)
	_on_dia_para_el_paisaje(sim.day)


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
	ui.ir_al_campamento.connect(_ir_al_campamento)
	add_child(ui)
	# El reloj se cuelga debajo del minimapa, que ya esta montado: el minimapa
	# se construye antes que la interfaz -necesita el relieve generado- asi que
	# la mudanza no puede hacerse alli. Ver [Minimapa.colgar_el_reloj].
	minimapa.colgar_el_reloj()
	# Y que la interfaz se entere de los momentos: hallazgos que enseñar y
	# decisiones que pedir. Ver [Moment].
	if sim != null:
		ui.barra.watch_moments(sim)
		# AHORA, y no antes: sim.setup() ya corrió y nadie escuchaba todavía.
		# Ver [SettlementSim.iniciar_partida].
		#
		# Y una partida RETOMADA no empieza: sigue. Ni momento inicial ni
		# decisión de la estación, que ya se citó en su día y viene guardada.
		if _adoptado:
			pass  # sigue donde iba: ni empieza ni se vuelca
		elif Expedition.visita:
			_montar_la_visita()
		elif Expedition.retomando:
			_retomar_la_partida()
		else:
			sim.iniciar_partida()
		# Las cumbres, del campamento y no del alfiler: buscarlas apunta en la
		# crónica. Ver [Campamento.mirar_las_cumbres].
		campamento.mirar_las_cumbres()

		# LOS ALFILERES, YA, con la partida puesta y el filtro que eligió el
		# jugador. Las cimas sólo se repintaban al cerrar la jornada, así que al
		# retomar un mapa salían sin alfiler hasta el día siguiente; y el filtro
		# se colgaba del minimapa ANTES de que existieran los alfileres de
		# paraje, que se quedaban sin él hasta tocar el botón. Medido con
		# `MarcadoresProbe` sobre el guardado del jugador (2026-09-14): 0 cimas y
		# «filtro en markers false» al volver del mapa regional.
		if paraje_markers != null:
			paraje_markers.refresh_peaks(sim.cumbres.peaks(), terrain)
		_aplicar_filtro_de_marcadores()

		# El menú de la partida, el que abre ESC. Va aquí y no en `_setup_ui`
		# porque necesita la simulación, la fauna y las cuevas montadas: son lo
		# que guarda. Ver [MenuDelJuego].
		menu_del_juego = MenuDelJuego.new()
		menu_del_juego.name = "MenuDelJuego"
		# En una visita no hay mapa que guardar: ver [Guardado.sitio_de_la_banda].
		menu_del_juego.montar(null if Expedition.visita else sim, herds, _caves)
		menu_del_juego.visible = false
		add_child(menu_del_juego)

	minimapa._build_resource_overlay()
	# Las cuevas del entorno del campamento salen ya descubiertas, por lo mismo
	if not _adoptado:
		campamento.revisar_hallazgos()


## La cueva de un id, o null.
func _cueva_por_id(id: int) -> CaveMouth:
	for cave: CaveMouth in _caves:
		if cave.id == id:
			return cave
	return null


## Los tres puntos de una cueva que la banda usa como casa: la boca, dónde se
## duerme y la campa. Con las mismas alturas que al empezar —ver
## [_levantar_hogar]—: dentro, la del suelo de la cueva; fuera, la del terreno.
func _casa_de(cave: CaveMouth) -> Dictionary:
	var dentro := cave.inside_point()
	var campa := cave.forecourt_point()
	if terrain:
		# En el rellano de la campa, igual que al fundar. Ver [_levantar_hogar].
		campa = ObrasDelAbrigo.asiento_llano(terrain, campa, Bonfire.RING_RADIUS)
	return {"boca": cave.boca(), "dentro": dentro, "campa": campa}


## La banda se ha asentado en otra cueva: la hoguera va a la campa nueva. Los
## tajos los busca otra vez el campamento: ver [Campamento].
func _on_campamento_trasladado(_cueva: int) -> void:
	if hearth_fire != null:
		hearth_fire.colocar(terrain, sim.home_forecourt)
	# Las obras son del sitio y se vuelven a levantar allí: ver [Traslado]. Lo
	# que hay que mover es DÓNDE se plantan cuando se levanten.
	_plantar_obras(campamento.cueva_en(sim.home_position))


## Enseña o esconde los alfileres que el jugador haya elegido: los de paraje y
## los de cima los lleva [ParajeMarkers]; los de cueva, cada [CaveMouth].
func _aplicar_filtro_de_marcadores() -> void:
	if filtro_de_marcadores == null:
		return
	if paraje_markers != null:
		paraje_markers.filtro = filtro_de_marcadores
		paraje_markers.aplicar_filtro()
	var cuevas := filtro_de_marcadores.se_ve(FiltroDeMarcadores.Familia.CUEVA)
	for cave: CaveMouth in _caves:
		cave.mostrar_marcador(cuevas)


## Le dice a [ObrasDelAbrigo] dónde cae cada cosa en este abrigo: la campa —que
## es donde arde el hogar—, la boca de la cueva y la orilla más cercana.
func _plantar_obras(cave: CaveMouth) -> void:
	if obras_del_abrigo == null:
		return
	var campa := sim.home_forecourt if sim.home_forecourt != Vector3.ZERO \
		else sim.home_position
	var boca := cave.boca() if cave != null else sim.home_position
	var mirando := cave.facing() if cave != null else Vector3.FORWARD
	# La orilla de verdad, la misma a la que se va a por agua. Ver
	# [Hogar._fetch_water].
	var orilla := sim.tajo._shore_near(sim.home_position)
	obras_del_abrigo.setup(sim, terrain, campa, boca, mirando, orilla)
	# Y el montón, junto a la boca y no en el punto del emplazamiento: ver
	# [_sitio_del_conchero].
	if conchero != null:
		conchero.colocar(_sitio_del_conchero(cave, campa))


## Dónde se tira lo que sobra: a un lado de la boca, cuesta abajo, a unos metros
## del filo del pozo.
##
## Iba a `home_position + (14, 0, 9)` —diecisiete metros del punto del
## emplazamiento, sin mirar dónde cae la boca— y no se movía si la banda se
## mudaba: «el conchero aparece demasiado alejado de la cueva», queja del usuario
## del 2026-09-14. Un conchero cantábrico está en la boca misma, a un lado de la
## puerta. Del lado que BAJA porque lo que se tira rueda cuesta abajo, y a un
## lado y no delante porque delante está la campa, donde se vive.
func _sitio_del_conchero(cave: CaveMouth, campa: Vector3) -> Vector3:
	if cave == null:
		return campa + Vector3(8.0, 0.0, 0.0)
	var mirada := cave.facing().normalized()
	var lado := mirada.cross(Vector3.UP).normalized()
	var desde := cave.boca() + mirada * cave.mouth_radius
	var alcance := cave.mouth_radius + CONCHERO_JUNTO_A_LA_BOCA
	var uno := desde + lado * alcance
	var otro := desde - lado * alcance
	if terrain != null and terrain.get_height_at(otro) < terrain.get_height_at(uno):
		return otro
	return uno


## Cuánto se aparta el conchero del filo de la boca, a un lado, en metros. Lo
## justo para que el montón en su máximo —[Conchero.RADIO_MAX] de mancha, la loma
## algo menos— no se meta en el pozo. Decisión, no medida.
const CONCHERO_JUNTO_A_LA_BOCA := 6.0


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


## Los postes azules que marcaban «aquí trabaja la gente» se han ido: eran
## de antes de que existieran los parajes, cuando el único sitio de trabajo
## era una corazonada del fundador. Ahora cada sitio tiene nombre, chapa y
## ficha propia -ver [ParajeMarkers]-, y dos marcadores para lo mismo solo
## ensucian el valle. `set_work_site` SÍ se queda: sigue siendo el sitio de
## reserva al que ir mientras no se conozca ningún paraje.
func _on_day_passed(_day: int) -> void:
	_update_band_panel()
	# Y la partida queda con algo que no está en disco. Ver [Partidas.sucia]: es
	# una marca, no una comparación de ficheros.
	Partidas.tocar()

	# Las chapas de paraje NO se rehacen aqui: se rehacen en cuanto nace o
	# muere un sitio. Ver `_repintar_parajes`.
	if paraje_markers and sim:
		paraje_markers.refresh_peaks(sim.cumbres.peaks(), terrain)
	if trap_markers and sim:
		trap_markers.refresh(sim.trampas.traps, terrain)
	if nasa_markers and sim:
		nasa_markers.refresh(sim.nasas_line.nasas, terrain)
	# Las pasarelas: se repintan solas cuando cambia la lista, así que
	# preguntar cada jornada no cuesta nada. Ver [PasarelaView.refresh].
	if pasarela_view and sim:
		pasarela_view.refresh(sim.pasarelas, terrain)
	# Las tumbas, igual: se rehacen sólo si hay una nueva.
	if sepulturas_view and sim:
		sepulturas_view.refresh(sim.sepulturas, terrain)
	# La baliza de exploracion colgaba del guardia de las TRAMPAS, que no pinta
	# nada aqui: sin marcador de trampas no se veia adonde se habia mandado
	# mirar. Va con las chapas de paraje, que es de lo que es.
	if paraje_markers and sim:
		paraje_markers.set_scout_beacon(sim.scout_order, sim.has_scout_order, terrain)

	# LAS TECNICAS YA NO SE CUENTAN AQUI. Contarlas en la señal de medianoche,
	# mirando quien tenia tajo en ese instante, dejaba al hogar y a la ribera sin
	# practicar nunca: ver [SettlementSim._practica_del_dia], que es donde vive
	# ahora la regla. Aqui solo queda lo que de verdad es de la escena -el
	# relato, el hito y el aviso-, colgado de `tecnica_aprendida`.


## Vuelve al mapa regional, llevandose el estado de la banda... y GUARDANDO.
##
## Antes de la tanda 3 sólo viajaban la población y la comida: el asentamiento
## se perdía y no había forma de retomarlo. Ahora se guarda entero en disco
## —ver [Guardado]— y el mapa regional ofrece volver.
##
## Se guarda con el reloj parado y desde fuera del paso: esto lo llama la
## tecla, o sea entre fotogramas, no a mitad de un `_advance`. Una instantánea
## tomada a medio paso es media partida, SPECS §3.2.
func _return_to_region() -> void:
	# La pantalla antes que guardar: guardar también es del cuadro de la tecla.
	Carga.abrir(get_tree(), "Saliendo a la comarca")
	await get_tree().process_frame
	_dejar_la_escena()
	Expedition.clear()
	Carga.cambiar_de_escena(get_tree(), Expedition.REGION_SCENE)


## Salta a otro campamento sin pasar por el mapa regional: SISTEMAS §23, punto 8.
func _ir_al_campamento(otro: Campamento) -> void:
	if otro == campamento:
		return
	Carga.abrir(get_tree(), "Yendo a %s" % otro.nombre())
	_dejar_la_escena()
	Campamentos.traspaso_de(otro)
	Carga.cambiar_de_escena(get_tree(), Expedition.LOCAL_SCENE)


## Lo que se hace al irse de un mapa, vaya adonde se vaya: guardar la partida y
## sacar el campamento de la escena, que sigue simulando fuera.
func _dejar_la_escena() -> void:
	# Una visita no se guarda: no hay banda, y guardarla la haría pasar por el
	# mapa de la banda. Ver [Guardado.sitio_de_la_banda].
	if sim and not Expedition.visita:
		var velocidad := sim.time_scale
		sim.time_scale = 0.0
		GameState.population = sim.population()
		GameState.food = sim.store.food_rations()
		var fallo := Guardado.guardar(sim, herds, _caves)
		# La partida no se para por salir al mapa regional: SISTEMAS §23, punto 5.
		sim.time_scale = velocidad
		# El autoguardado deja el mapa en la carpeta de trabajo, no en la
		# ranura: la partida sigue teniendo algo que no está guardado.
		Partidas.tocar()
		if fallo.is_empty():
			print("Estado del mapa guardado en %s" % Guardado.ruta_de(
				Expedition.site.id if Expedition.site != null else -1))
		else:
			print("NO se ha podido guardar: %s" % fallo)
	# EL CAMPAMENTO SALE DE LA ESCENA, NO DE LA PARTIDA: sigue simulando fuera del
	# árbol. Ver [Campamentos.soltar_de_la_escena].
	Campamentos.soltar_de_la_escena(self, campamento)


## Vuelca la partida guardada sobre la escena recién montada.
##
## Va al final de `_ready`, cuando ya existen la simulación, la fauna y las
## cuevas: [Instantanea.volcar] ata lo guardado a lo que hay, y lo que no
## existiera todavía se crearía suelto y sin que nadie lo apunte.
## Deja montada una VISITA: el mapa sin banda, con la fecha en la que va la banda
## y el reloj parado.
##
## Decisión del usuario del 2026-09-14: «cuando voy a otro mapa no debe traer a mi
## banda, sólo cargar y mostrarme el mapa; lo que sí debe hacer es mantener la
## fecha entre todas las zonas». **El reloj no corre aquí** mientras no exista la
## simulación de la banda en segundo plano —queda para su spec—: si corriera, al
## volver la banda estaría en otra fecha que el mundo.
func _montar_la_visita() -> void:
	# UN MAPA VISITADO SE VE ENTERO en el regional (SISTEMAS §4). Fuera del paso.
	if Expedition.site != null:
		GameState.levantar_niebla({"forma": "recuadro", "lon": Expedition.site.lon,
			"lat": Expedition.site.lat, "lado": float(Expedition.local_size_m)})
	# Y EN SU MINIMAPA, sólo lo que las expediciones pisaron, con las cuevas de
	# dentro. Ver [Campamento.ver_lo_recorrido].
	campamento.ver_lo_recorrido(GameState.niebla)
	# CON CAMPAMENTOS VIVOS, EL RELOJ CORRE (SISTEMAS §23, tarea 14, que cambia la
	# decisión de arriba: ya existe la simulación en segundo plano). La simulación
	# de la visita no tiene gente y el reloj no le da pasos; la toma para que los
	# botones de velocidad muevan la partida, y copia su fecha en cada fotograma.
	var reloj := Campamentos.reloj
	if reloj != null and is_instance_valid(reloj) and not Campamentos.vivos.is_empty():
		reloj.dirigir(sim)
		Campamentos.a_la_fecha(sim)
		_de_visita_con_reloj = true
		sim._note(Chronicle.Kind.TIERRA, "De visita en %s. Aquí no vive nadie de los tuyos; "
			% (Expedition.site.display_name() if Expedition.site != null else "este mapa")
			+ "en tus campamentos la vida sigue mientras miras.", 2)
		return
	var banda := Guardado.leer()
	if not banda.is_empty():
		sim.day = int(banda.get("jornada", sim.day))
		GameState.season = int(banda.get("estacion", GameState.season)) as Subsistence.Season
		GameState.year = int(banda.get("anyo", GameState.year))
	sim.time_scale = 0.0
	sim._note(Chronicle.Kind.TIERRA, "De visita en %s. La banda sigue en su valle; aquí "
		% (Expedition.site.display_name() if Expedition.site != null else "este mapa")
		+ "no vive nadie de los tuyos, y el tiempo no corre mientras miras.", 2)
	print("Visita: sin banda, jornada %d, reloj parado" % sim.day)


func _retomar_la_partida() -> void:
	if not Expedition.retomando:
		return
	Expedition.retomando = false
	var sitio := Expedition.site.id if Expedition.site != null else -1
	var guardado := Guardado.leer(sitio)
	if guardado.is_empty():
		print("Se pedía retomar y no hay estado de este mapa que leer")
		return
	var errores := Guardado.volcar(guardado, sim, herds, _caves)
	_retomada = true
	if errores.is_empty():
		print("Partida retomada: jornada %d" % sim.day)
	else:
		print("La partida se retoma a medias: %s" % ", ".join(errores))


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
		# PERO POR ABAJO, HASTA EL SUELO. El recorte dejaba el tope en unos
		# 55 m de órbita, y el usuario quiere «hacer más zoom hasta
		# prácticamente estar sobre el terreno» (2026-09-14). Se abre sólo el
		# extremo cercano —el lejano sigue siendo el de la banda útil—, y la
		# muesca de abajo se ensancha para que el tramo nuevo no cueste veinte
		# vueltas de rueda: el paso es multiplicativo, así que un 8 % a tres
		# metros se ve igual que un 8 % a cincuenta.
		camera.min_distance = CAMARA_A_PIE_DE_TIERRA
		camera.zoom_factor_near = 1.08
		camera.zoom_fine_span = 0.25
		# Mas contenido: a world*0.15 se cruzaban los 4 km en siete segundos
		camera.move_speed = maxf(25.0, world * 0.045)
		camera.far = world * 4.0
		# El plano cercano tiene que caber por debajo de la órbita más corta, o
		# a pie de tierra la hierba de delante se recorta. Godot 4.5 guarda la
		# profundidad invertida, así que un cercano de 0,1 con miles de metros
		# de lejano ya no arruina la precisión como con el búfer clásico.
		camera.near = 0.1

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
		# El punto de órbita, AL SUELO -y antes de `set_target`, que ya lo apoya-.
		# Ver [OrbitalCamera._apoyar_el_centro].
		# A la altura de los ojos de alguien de pie: bajar hasta el suelo es
		# para eso. Eran 14 m, la copa de un árbol.
		camera.ground_clearance = 1.6
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

	# El minimapa va en SU PROPIO lienzo, y por encima de la barra -que va en la
	# capa 10, ver [GameUI._ready]-.
	#
	# Va metido DENTRO de la barra: se ancla arriba a la derecha en y=0 y la
	# barra le guarda el hueco. Con la barra dibujandose encima, los primeros
	# cuarenta y cinco pixeles del mapa quedaban tapados, y con ellos el boton
	# de la comarca, que va en esa misma esquina.
	#
	# Y en un lienzo aparte y no subiendo el de la interfaz: en ese cuelga
	# tambien la ficha de depuracion, y subirla entera la pondria por encima de
	# las ventanas del juego.
	var lienzo_del_mapa := CanvasLayer.new()
	lienzo_del_mapa.name = "Minimapa"
	lienzo_del_mapa.layer = 11
	add_child(lienzo_del_mapa)

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
	_minimap_canvas = lienzo_del_mapa

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


## Se ha aprendido una tecnica practicandola. Lo cuenta [SettlementSim].
func _on_tecnica_aprendida(gained: int) -> void:
	# Contarla —el relato y el hito— es del campamento, que la cuenta se mire o
	# no. Aquí sólo el aviso en pantalla. Ver [Campamento.levantar_fauna_y_tecnica].
	if ui != null:
		ui.show_tech_milestone(gained as TechTree.Tech)


## Mandar una expedición: el botón «Rumbo» lleva al mapa regional, con la pantalla de
## carga, y allí se abre la ficha para este campamento (SISTEMAS §4, spec del
## 2026-09-15). **Hasta el 2026-09-16 se pinchaba un rumbo en el valle**, y el botón
## sólo escribía una línea en la crónica: visto por el usuario, «no hacía nada». El
## botón está apagado mientras no pueda salir la más corta ([Minimapa.refrescar_el_rumbo]),
## y aquí se vuelve a mirar por si cambió entre el refresco y el clic.
func mandar_expedicion() -> void:
	if sim == null or Expedition.visita or campamento == null or campamento.sitio == null:
		return
	if not sim.expedicion.por_que_no_sale().is_empty():
		return
	Expedition.ficha_de_rumbo_desde = campamento.sitio.id
	_return_to_region()


## La simulación de una visita se suelta del reloj al irse: la escena la libera, y
## el reloj le daría la vuelta a un objeto liberado.
##
## Y el campamento se suelta aunque la escena se vaya sin pasar por [_dejar_la_escena]:
## si no, se libera con ella. Ver [Campamentos.soltar_de_la_escena].
func _exit_tree() -> void:
	Campamentos.soltar_de_la_escena(self, campamento)
	if _de_visita_con_reloj and Campamentos.reloj != null \
			and is_instance_valid(Campamentos.reloj):
		Campamentos.reloj.soltar(sim)


func _connect_signals() -> void:
	# Conectar señales del TerrainGenerator
	terrain.generation_complete.connect(_on_terrain_generated)


func _on_terrain_generated() -> void:
	print("Terreno generado")
	
	# Inicializar vegetación después de generar terreno
	# Solo si hay vegetacion: esta desactivada mientras no haya especies con
	# porte de verdad, y estas llamadas se quedaban colgando de un nodo nulo


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
	if _de_visita_con_reloj:
		Campamentos.a_la_fecha(sim)
	Cronometro.abre_el_fotograma()
	Cronometro.tramo_raiz("escena principal (DemoMain)")
	var frame := Engine.get_process_frames()
	if frame % 15 == 0:
		Cronometro.tramo("cada 15: panel de banda + minimapa")
		_update_band_panel()
		minimapa._update_minimap()
		minimapa.refrescar_el_rumbo()
		_refresh_debug_label()
		# El tiempo cambia por horas de juego, no por fotogramas: mirarlo
		# cuatro veces por segundo va sobrado, y la capa corta sola si no ha
		# cambiado nada
		_sync_weather()
		Cronometro.cierra("cada 15: panel de banda + minimapa")
	# El overlay del terreno se repinta mucho mas de tarde en tarde: lo que
	# muestra es conocimiento acumulado, que crece a lo largo de jornadas, no
	# de frames. Recorre las 4.096 celdas del campo, asi que hacerlo seguido
	# seria pagar cada segundo por un dato que cambia cada dia de juego.
	if _overlay_activity != OVERLAY_OFF and frame % 180 == 0:
		Cronometro.tramo("cada 180: capa de recursos")
		minimapa._refresh_resource_overlay()
		Cronometro.cierra("cada 180: capa de recursos")
	# La niebla del minimapa crece por jornadas, no por frames: repintarla
	# cuatro veces por segundo seria pagar todo el rato por un dato que casi
	# nunca cambia. Los hallazgos ya no se miran aqui: van a horas de juego,
	# colgados de `SettlementSim.hour_passed`, porque escriben en la cronica y
	# el numero de fotograma no es de la partida.
	if frame % 90 == 0:
		Cronometro.tramo("cada 90: niebla del minimapa")
		minimapa._refresh_minimap_fog()
		Cronometro.cierra("cada 90: niebla del minimapa")
	Cronometro.tramo("chapas de parajes")
	_repintar_parajes()
	Cronometro.cierra("chapas de parajes")
	Cronometro.cierra("escena principal (DemoMain)")
	Cronometro.cierra_el_fotograma("dia %d %02d:%02d" % [sim.day, int(sim.hour),
		int(fmod(sim.hour, 1.0) * 60.0)])


## Cuantos parajes habia la ultima vez que se pintaron las chapas.
var _parajes_pintados: int = -1


## Repinta las chapas EN CUANTO nace o muere un paraje.
##
## Colgaba de `_on_day_passed`, y ese es el fallo que el jugador veia: un sitio
## descubierto a las once de la manana existia en la simulacion desde esa hora
## y su chapa no aparecia hasta medianoche, con todas las demas de golpe. La
## queja -«los parajes deben aparecer con su marker y su info cuando se
## descubren, no se debe esperar hasta media noche»- era de esto y no de cuando
## se bautizaban.
##
## Comparar dos enteros por fotograma no cuesta nada; rehacer las chapas si
## cuesta, y por eso solo se hace cuando la lista ha cambiado de verdad. Ver
## [Parajes.cambios].
func _repintar_parajes() -> void:
	if paraje_markers == null or sim == null or sim.parajes == null:
		return
	if sim.parajes.cambios == _parajes_pintados:
		return
	_parajes_pintados = sim.parajes.cambios
	paraje_markers.refresh(sim.parajes, terrain)


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
			# EL TRASLADO DE VERDAD: la banda carga, anda hasta aquí y se asienta,
			# sólo si se llega. Ver [Traslado].
			var cueva := _cueva_por_id(int(data.get("cueva", -1)))
			if sim != null and cueva != null:
				var casa := _casa_de(cueva)
				if not sim.traslado.mandar(cueva.id, casa["boca"], casa["dentro"],
						casa["campa"]):
					print("Banda: no se muda a %s: %s" % [label,
						sim.traslado.lo_que_falta(cueva.id, casa["campa"])])
		"explorar":
			# EXPLORAR DE VERDAD: lámpara, grasa y una jornada de alguien del
			# hogar, con sus decisiones dentro. Antes revelaba el entorno de
			# golpe y no costaba nada. Ver [Exploracion].
			if sim != null and not sim.exploracion.mandar(int(data.get("cueva", -1))):
				print("Banda: no se puede explorar %s: %s" % [label,
					sim.exploracion.lo_que_falta(int(data.get("cueva", -1)))])
		"entrar":
			# LA SALA, encima de la escena: no se cambia de mapa. Ver [SalaDeLaCueva].
			var cueva := int(data.get("cueva", -1))
			var falta := sim.pinturas.por_que_no_se_entra(cueva) if sim != null else "no hay banda"
			if not falta.is_empty():
				print("Banda: no se entra en %s: %s" % [label, falta])
			else:
				var sala := SalaDeLaCueva.new()
				ui.add_child(sala)
				sala.montar(sim, cueva, label)
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
		# Con su número de cueva, que la ventana necesita para decir si se
		# puede explorar y qué se sabe de ella.
		var datos := cave.feature.duplicate()
		datos["cueva"] = cave.id
		# La campa, para que la ventana pueda decir si se llega. Ver
		# [Traslado.lo_que_falta].
		datos["campa"] = _casa_de(cave)["campa"]
		ui.sitios.show_feature(datos, cave.pick_position(),
			sim.home_position if sim else Vector3.ZERO,
			sim != null and cave == campamento.cueva_en(sim.home_position))
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
			#
			# Y sin nada delante, el menú de la partida —guardar, cargar,
			# salir—, que es lo que pidió la spec de INTERFAZ §7. Cerrar una
			# ventana y abrir el menú son dos pulsaciones distintas a
			# propósito: con una sola, salir del juego estaría a un ESC de
			# distancia de mirar el almacén.
			if menu_del_juego != null and menu_del_juego.esta_abierto():
				menu_del_juego.cerrar()
			elif ui and ui.close_topmost():
				pass
			elif menu_del_juego != null:
				menu_del_juego.abrir()
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
			# se pisa pero no se alcanza desde el abrigo, y AZUL lo que solo
			# se pasa por el vado. El azul hacia falta: la capa dejaba sin
			# pintar una celda del rio abierta por su vado -o sea igual que un
			# prado seco- y al pinchar esa casilla la ficha decia que no se
			# podia pasar. Es la unica forma de comprobar si la rejilla esta
			# acertando.
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
			if sim and (not Expedition.visita or _de_visita_con_reloj):
				sim.time_scale = 0.0 if sim.time_scale > 0.0 else 1.0
		KEY_F1:
			if sim and (not Expedition.visita or _de_visita_con_reloj): sim.time_scale = 1.0
		KEY_F2:
			if sim and (not Expedition.visita or _de_visita_con_reloj): sim.time_scale = 3.0
		KEY_F3:
			if sim and (not Expedition.visita or _de_visita_con_reloj): sim.time_scale = 5.0


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
		# Las horas antes que el tiempo: el viento de hoy lo pone al contar.
		weather_view.contar_horas(sim.day, sim.hour, sim.weather.kind)
		weather_view.show_weather(sim.weather.kind)
		# Y el cielo: las nubes que se ven arriba son las del tiempo que hace,
		# no una decoración aparte. Ver [WorldEnvironmentSetup.nubes_por_el_tiempo].
		var entorno := _first_world_environment(get_tree().root)
		if entorno != null and entorno.get_parent() != null 				and entorno.get_parent().has_method("nubes_por_el_tiempo"):
			entorno.get_parent().call("nubes_por_el_tiempo", int(sim.weather.kind))
			# Y la luz del tiempo (GRAFICOS §7.4), si el clima se dibuja.
			if bool(Configuracion.graficos.get("clima", true)):
				entorno.get_parent().call("luz_por_el_tiempo", int(sim.weather.kind))
			else:
				entorno.get_parent().call("luz_sin_clima")


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


## Lleva al terreno lo que la estacion ha hecho con el paisaje.
##
## Una vez por JORNADA y no por fotograma: mover un uniform del shader es
## barato, pero hacerlo sesenta veces por segundo para poner el mismo numero es
## trabajo tirado. Ver [Temporada].
func _on_dia_para_el_paisaje(_day: int) -> void:
	if terrain == null or sim == null or sim.temporada == null:
		return
	terrain.set_snow_line(sim.temporada.cota_de_nieve())
	# El caudal no va aqui: cierra el paso, asi que es partida y lo lleva el
	# campamento. Ver [Campamento._on_dia_para_el_rio].
	# Y el color: el pasto y la hojarasca se apagan con el año. Solo las capas
	# VIVAS -la caliza es igual de gris en enero que en agosto-.
	terrain.set_season_tint(sim.temporada.tinte_del_pasto())
	# Y EL BOSQUE. El pino apenas cambia -es perennifolio-; el abedul amarillea
	# en octubre y se queda desnudo en enero. Se le pasa cuanto se ha entrado en
	# la estacion para que la hoja no caiga de golpe el dia del calendario: un
	# abedular tarda tres semanas en pelarse. Ver [Forest.set_season].
	if forest != null:
		var dentro := clampf(
			float(sim.season_day) / float(Subsistence.DAYS_PER_SEASON) * 2.0,
			0.0, 1.0)
		forest.set_season(GameState.season as Subsistence.Season,
			_estacion_previa(GameState.season as Subsistence.Season), dentro)


## La estacion de la que se viene, para poder mezclar entre las dos.
func _estacion_previa(season: Subsistence.Season) -> Subsistence.Season:
	return ((int(season) + 3) % 4) as Subsistence.Season
