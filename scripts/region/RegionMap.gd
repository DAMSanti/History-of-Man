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

@export_group("Bandas de material")
## Cotas reales en metros donde cambia el material del terreno, contadas desde
## el mar de la época —ver [TerrainGenerator._apply_shader_height_setup]—.
##
## La playa, quince metros sobre el agua: decisión del usuario del 2026-09-14,
## «playa fina y hierba» en la costa glacial. Eran treinta, y no se notaba porque
## con el mar bajo toda la plataforma salía de arena de todos modos.
@export var shore_band_m: float = 15.0
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

## Los botones de entrar en las cuevas del sitio elegido. Ver [cuevas_para_entrar].
var _entradas: VBoxContainer
var _founding: bool = false

## El menú de la partida, el que abre ESC. Ver [MenuDelJuego].
var _menu_del_juego: MenuDelJuego
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


## Las etapas del montaje EN FRÍO, con lo que cuesta cada una en milisegundos, medido
## con `CargaProbe` con la pantalla puesta (ventana, 2026-09-15): leer el relieve 0,4 s;
## el ruido y la composición de alturas, unos 11; los vértices, los índices y el troceado
## de la malla, unos 7,5; la época 0,3; y los lugares con la frontera de la época, 0,7.
## Son los pesos de la barra. Ver [Carga] e INTERFAZ §9.
const ETAPAS := [
	["Leyendo la costa y los montes", 400.0],
	["Modelando las alturas", 11000.0],
	["Tendiendo la comarca", 7500.0],
	["Pintando la época", 300.0],
	["Marcando los lugares", 700.0],
]

## Las mismas, CON LA MALLA EN CACHÉ, que es desde el segundo viaje a la misma época: la
## malla ya no se modela ni se tiende, se lee. Medido igual, en la ida y en la nueva
## partida: leer 340-445 ms, las alturas casi nada, la malla 330, la época 80-270 y los
## lugares 510-770. A la primera se le suma lo que la pantalla lleva abierta antes de que
## la escena exista —leerla, y guardar la partida al salir del valle—: 160-360 ms en la
## ida y 860-1120 en la nueva, que con la carga entera en segundo y medio es media barra.
## Pesa lo de la nueva partida, 1300: lo de detrás —alturas y malla, 130-200 ms— cabe en
## un cuadro, así que la barra salta al acabar la primera, y con menos peso ese salto
## caía en la nueva al 65-77 % de la carga. En la ida la primera dura la mitad y el salto
## cae al 36-54 %.
const ETAPAS_CON_CACHE := [
	["Leyendo la costa y los montes", 1300.0],
	["Modelando las alturas", 20.0],
	["Tendiendo la comarca", 330.0],
	["Pintando la época", 180.0],
	["Marcando los lugares", 640.0],
]

## Mandar una expedición desde aquí: desde qué campamento, la ficha y la flecha. Ver
## [FichaDeRumbo] y SISTEMAS §4.
var _campamento_del_rumbo: Campamento = null
var _ficha_de_rumbo: FichaDeRumbo = null
var _flecha: FlechaDeRumbo = null


## Si el mapa ya está en pie. Ver [DemoMain.montado].
var montado := false
signal se_monto


func _ready() -> void:
	var t_ready0 := Time.get_ticks_msec()
	print("=== Capa regional ===")
	# Con pantalla de carga se monta en varios cuadros y parado; sin ella, de un tirón.
	# Ver [DemoMain._ready] e INTERFAZ §9.
	var cargando := Carga.abierta()
	if cargando:
		process_mode = Node.PROCESS_MODE_DISABLED
	var t_setup := Time.get_ticks_msec()
	# Las etapas, según esté la malla en caché: con ella la carga es de un segundo y medio
	# y sin ella de veinte, y con los pesos del frío la barra no decía la verdad. Se mira
	# antes de montar nada: declararlas dos veces dejaba el primer rato a cuenta de las
	# del frío, y a media barra había pasado el 75 % de la carga.
	if cargando:
		var con_cache := ResourceLoader.exists(MallaDelTerreno.ruta_de_la_cache(heightmap_path,
			sufijo_de_la_cache(mar_del_mapa()), resolution))
		Carga.etapas(ETAPAS_CON_CACHE if con_cache else ETAPAS)
		Carga.etapa(0)
	await _setup_terrain()
	print("[TIMING] _setup_terrain (carga heightmap regional): %d ms" % (Time.get_ticks_msec() - t_setup))
	await Carga.ceder()
	_setup_camera()
	_setup_ui()
	Carga.siguiente()
	await Carga.ceder()

	var t0 := Time.get_ticks_msec()
	# La generación no sabe de etapas: las alturas y la malla van en una sola llamada. La
	# barra avanza por tiempo dentro de cada una y cambia cuando el terreno dice que ya va
	# por la malla. Cambiando por tiempo, a media barra había pasado el 70 % de la carga.
	await terrain.generate(_ceder_al_generar if cargando else Callable())
	Carga.etapa(3)
	await Carga.ceder()

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
	# SIN CANCHALES: esto es una comarca vista desde arriba, y el derrubio es un detalle de
	# ladera que a 111 m por muestra sólo ensucia. Decisión del usuario del 2026-09-18.
	terrain.pintar_como_comarca()
	print("Region generada en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var t_eras := Time.get_ticks_msec()
	_eras = await Carga.cargar(eras_path) as RegionEras
	print("[TIMING] carga de eras_path: %d ms" % (Time.get_ticks_msec() - t_eras))

	# LA MÁSCARA DE LA ÉPOCA NO SE APLICA AQUÍ, sino en `_apply_era`, unas líneas más
	# abajo y siempre: `_era_index` empieza en -1, así que allí se aplica sea cual sea la
	# época. Aplicarla también aquí trazaba la frontera de la época por defecto —720 ms,
	# medido con `CargaProbe`— para tirarla enseguida.
	Carga.siguiente()
	await Carga.ceder()
	var t_sites := Time.get_ticks_msec()
	_build_sites()
	print("[TIMING] _build_sites (%d emplazamientos): %d ms" % [
		_site_set.sites.size() if _site_set else 0, Time.get_ticks_msec() - t_sites])

	if _site_set and not GameState.started:
		GameState.begin(_site_set)
	# EN DEBUG, TODOS LOS YACIMIENTOS A LA VISTA (INTERFAZ §14). Cada vez que se monta el
	# mapa: jugando en un valle se puede haber descubierto —o dejado de descubrir— algo.
	if ModoDebug.activo:
		ModoDebug.preparar_el_mapa(_site_set)
		ModoDebug.rotulo(self)
		_refresh_sites()

	# El menú de la partida, el que abre ESC. Aquí no hay simulación que parar:
	# lo que se guarda es lo que ya está en la carpeta de trabajo.
	_menu_del_juego = MenuDelJuego.new()
	_menu_del_juego.name = "MenuDelJuego"
	_menu_del_juego.visible = false
	add_child(_menu_del_juego)
	if GameState.home:
		_era = GameState.era
	# UN SOLO SITIO QUE CONTESTA CON QUÉ MAR SE MONTA ESTE MAPA, y es el mismo con el que se
	# montó el relieve y con el que se trazan los ríos. Había dos llamadas aquí -una con
	# `GameState.sea_level_m` si ya había campamento y otra con `mar_del_mapa()` si no-, y
	# `mar_del_mapa` devolvía el mar de HOY mientras no hubiera campamento: una partida nueva
	# dibujaba la Cantabria actual, sin plataforma emergida y por tanto **sin sus ríos**, y en
	# cuanto fundabas y volvías aparecían. Es el invariante 3 de SPECS §7 roto en la línea de
	# al lado. Depurado el 2026-09-18.
	await _apply_era(mar_del_mapa(), Carga.ceder)
	if GameState.home:
		_select_site(GameState.home)
		camera.set_target(terrain.geo_to_world(GameState.home.lon, GameState.home.lat))
		camera.set_distance(float(maxi(terrain.terrain_size.x, terrain.terrain_size.y)) * 0.12)

	_update_info()
	print("[TIMING] === RegionMap._ready() TOTAL: %d ms ===" % (Time.get_ticks_msec() - t_ready0))
	montado = true
	if cargando:
		process_mode = Node.PROCESS_MODE_INHERIT
		Carga.cerrar()
	# Y SI SE VIENE DEL BOTÓN «Rumbo» DEL VALLE, con la ficha abierta para ese
	# campamento. Ver [Expedition.ficha_de_rumbo_desde].
	if Expedition.ficha_de_rumbo_desde >= 0:
		var pedido := Campamentos.de_sitio(Expedition.ficha_de_rumbo_desde)
		Expedition.ficha_de_rumbo_desde = -1
		if pedido != null:
			abrir_la_ficha(pedido, true)
	se_monto.emit()


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


## EL MAR CON EL QUE SE MONTA ESTE MAPA, y la única respuesta a esa pregunta.
##
## El relieve de la plataforma y los ríos que la cruzan **se congelan al montar**: son la
## malla, y rehacerlos cuesta veinte segundos. Lo demás —el agua, las máscaras, los sitios—
## sí cambia en caliente con la tecla E. Por eso hay que decidir bien este mar una vez.
##
## **Con partida, el suyo. En modo Debug, el de la época que Debug abre. Sin nada, el de
## hoy**, que es el mapa que se ve al abrirlo a secas.
##
## *(Hasta el 2026-09-17 esto se preguntaba en tres sitios con `GameState.home != null`, y
## el modo Debug —que no funda nada— se quedaba fuera: montaba el relieve con el mar de hoy
## y luego pintaba encima la costa glacial, así que la plataforma salía pelada y **sin un
## solo río**. El usuario: «cuando entro en debug el mapa regional no tiene ríos, pero
## cargo un mapa, vuelvo y vuelve a tener ríos… ¿ya hay más de una verdad?». Había dos.)*
static func mar_del_mapa() -> float:
	# La cota de la época, siempre. `GameState.sea_level_m` vale -120 desde que arranca el
	# juego y sólo lo cambian cargar una partida o el modo Debug, así que **una partida nueva
	# ya sabe en qué época está antes de fundar nada**: se empieza en el Paleolítico y el mapa
	# es el del Paleolítico desde el primer momento. Decisión del usuario del 2026-09-18.
	#
	# Devolvía el mar de hoy mientras no hubiera campamento, y eso hacía que el mapa saliera
	# sin la plataforma emergida ni sus ríos hasta que fundabas.
	return GameState.sea_level_m


## Cambia el territorio a la cota del mar dada: mascara del terreno, frontera
## dibujada y emplazamientos disponibles.
## `ceder` va al trazado de la frontera (ver [_trace_border]).
func _apply_era(sea_level_m: float, ceder: Callable = Callable()) -> void:
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
			await _apply_era_mask(ceder)

	_refresh_sites()
	if _selected and not _selected.is_available(_sea_level_m):
		_select_site(null)
	else:
		_update_detail()
	_update_band()
	_update_info()


## Abre la ficha de la expedición para un campamento: el que se pide —el del botón
## «Rumbo» del valle—, el seleccionado o el primero. Sin campamentos vivos no hay quien
## salga: se retoman al entrar en el mapa de la banda.
##
## **El rumbo ya no se pincha en el mapa** (2026-09-16): es uno de los ocho de la ficha.
func abrir_la_ficha(desde: Campamento = null, viene_del_valle: bool = false) -> void:
	if desde == null and _selected != null:
		desde = Campamentos.de_sitio(_selected.id)
	if desde == null and not Campamentos.vivos.is_empty():
		desde = Campamentos.vivos[0]
	if desde == null or desde.sim == null:
		_detail.text = ("No hay campamento en marcha desde el que salir. Entra en el "
			+ "mapa de la banda y vuelve.")
		return
	_campamento_del_rumbo = desde
	if _flecha == null:
		_flecha = FlechaDeRumbo.new()
		_flecha.name = "FlechaDeRumbo"
		add_child(_flecha)
	if _ficha_de_rumbo == null:
		_ficha_de_rumbo = FichaDeRumbo.new()
		_ficha_de_rumbo.name = "FichaDeRumbo"
		_ficha_de_rumbo.cambiada.connect(func(recorrido: Pasillo) -> void:
			if recorrido == null:
				_flecha.mesh = null
			else:
				_flecha.trazar_pasillo(terrain, recorrido, 1.5, _ficha_de_rumbo.los_otros_rumbos()))
		_ficha_de_rumbo.cerrada.connect(_cerrar_el_rumbo)
		get_node("UI").add_child(_ficha_de_rumbo)
	_ficha_de_rumbo.abrir(desde.sim, desde.nombre(), viene_del_valle)


func _cerrar_el_rumbo(mandada: bool, volver_al_valle: bool = false) -> void:
	var desde := _campamento_del_rumbo
	_campamento_del_rumbo = null
	if _ficha_de_rumbo != null:
		_ficha_de_rumbo.queue_free()
		_ficha_de_rumbo = null
	if _flecha != null:
		_flecha.queue_free()
		_flecha = null
	if not mandada or desde == null:
		return
	# DESDE EL VALLE SE ELIGE (SISTEMAS §4, punto 3): volver a él o quedarse aquí.
	if volver_al_valle:
		_entrar_en_el_campamento(desde)
		return
	_detail.text = ("Sale la expedición desde %s. Lo que vean se sabrá cuando "
		+ "vuelvan.") % desde.nombre()


## LOS MARCADORES cambian solos con el mapa regional abierto: los campamentos siguen y
## las expediciones vuelven, y lo que descubren saca yacimientos nuevos a la vista. Se mira
## una vez por segundo si hay algo nuevo.
##
## *(Aquí iban también la calima y sus nubes, retiradas el 2026-09-17 a petición del
## usuario: «quitamos la niebla en el mapa regional». Lo explorado se sigue guardando y
## sigue decidiendo qué yacimientos se ven, que es conocimiento de la banda y no un velo.)*
func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 60 == 0:
		if GameState.niebla != null and GameState.niebla.version != _sitios_con_version:
			_sitios_con_version = GameState.niebla.version
			_refresh_sites()


var _sitios_con_version := -1


## Muestra la frontera de una epoca, trazandola la primera vez
func _show_border(index: int, ceder: Callable = Callable()) -> void:
	for key: int in _border_cache.keys():
		var node: MeshInstance3D = _border_cache[key]
		node.visible = key == index

	if _border_cache.has(index):
		return
	if _eras == null or index < 0 or index >= _eras.masks.size():
		return

	var mesh := await _trace_border(_eras.masks[index], _eras.width, _eras.height, ceder)
	if mesh == null:
		return

	var node := MeshInstance3D.new()
	node.name = "Frontera_%d" % index
	node.mesh = mesh
	# Sin luz, que es una raya sobre el mapa y no una superficie del mundo.
	# *(Hasta el 2026-09-17 llevaba el shader de la niebla, que además la borraba donde no
	# se había explorado. Al retirarse la niebla del mapa regional se queda sólo el color.)*
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = border_color
	add_child(node)
	node.material_override = material
	_border_cache[index] = node


## Carga los emplazamientos ya derivados y los dibuja como marcadores.
## Van en un solo MultiMesh: son casi dos mil y como nodos sueltos hundirian
## el rendimiento sin aportar nada.
func _build_sites() -> void:
	if not show_sites:
		return

	# Por la puerta de siempre cuando es el conjunto de siempre: así entran los abrigos
	# hipotéticos de la costa (EPOCA_01 §10.2).
	_site_set = SiteSet.comarca() if sites_path == SiteSet.RUTA else load(sites_path) as SiteSet
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


## El color de un yacimiento avistado: pardo oscuro apagado, el mismo para todos, porque
## de un avistado no se sabe de qué tipo es. Oscuro y no gris claro: sobre la niebla, que
## es clara, el gris no se distinguía (`RumboProbe`, 2026-09-16).
const COLOR_DE_AVISTADO := Color(0.30, 0.28, 0.26)


## Reparte los sitios de la época en los que se ven —descubiertos y fuera de la niebla,
## `GameState.se_ve`: se pinchan y salen en las listas— y los **avistados**, que sólo
## se dibujan. Sin partida empezada se ve todo, como antes.
static func sitios_que_se_dibujan(sitios: Array[Site]) -> Dictionary:
	var vistos: Array[Site] = []
	var avistados: Array[Site] = []
	for site: Site in sitios:
		if not GameState.started or GameState.se_ve(site):
			vistos.append(site)
		elif GameState.avistado(site):
			avistados.append(site)
	return {"vistos": vistos, "avistados": avistados}


## Si un yacimiento visible lleva marcador en el mapa.
##
## Solo lo ATESTIGUADO: los inferidos son sitios potenciales, y llenar el mapa de
## marcadores deducidos lo vuelve ilegible e insinua una certeza que no existe. **Salvo en
## Debug**, que existe justo para verlos todos (INTERFAZ §14): ahi llevan marcador tambien
## los inferidos y los hipoteticos de la costa. Sin esta excepcion, el mapa de Debug
## dibujaba 63 de los 76 yacimientos que ofrece el Paleolitico —medido con ventana—, y la
## prueba de la suite no lo veia porque miraba la niebla y no este filtro.
static func se_marca(site: Site) -> bool:
	return site.fidelity == Site.Fidelity.ATESTIGUADO or ModoDebug.activo


## Rellena el MultiMesh con los emplazamientos disponibles a la cota actual
func _refresh_sites() -> void:
	if _markers == null or _site_set == null or terrain == null:
		return

	# Solo lo DESCUBIERTO. Al empezar es la propia cueva y nada mas: el mapa se
	# gana explorando, no se regala. Y aparte, lo AVISTADO desde las cumbres.
	var repartidos := sitios_que_se_dibujan(_site_set.available_in(_sea_level_m, _era))
	_visible_sites = repartidos["vistos"]
	var avistados: Array[Site] = repartidos["avistados"]
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
		if se_marca(site):
			marked.append(site)

	mm.instance_count = marked.size() + avistados.size()
	for i in range(marked.size()):
		var site: Site = marked[i]
		var world := terrain.geo_to_world(site.lon, site.lat)
		var xform := Transform3D()
		xform = xform.scaled(Vector3.ONE * 1.6)
		xform.origin = world
		mm.set_instance_transform(i, xform)
		var color: Color = KIND_COLORS.get(site.kind_at(_era_index), Color.WHITE)
		# En Debug, lo que no tiene su valle preparado va APAGADO y no de otro color: el
		# color ya dice qué clase de yacimiento es. Fundar ahí descarga (INTERFAZ §14).
		if ModoDebug.activo and not ModoDebug.esta_preparado(site):
			color = color.darkened(0.6)
		mm.set_instance_color(i, color)
	# LOS AVISTADOS, MÁS APAGADOS Y AUNQUE ESTÉN BAJO LA NIEBLA (SISTEMAS §4, spec del
	# 2026-09-15): se sabe que están ahí, no qué son. Van al MultiMesh pero NO a
	# `_visible_sites`, que es lo que se pincha y lo que sale en las listas: no se
	# visitan ni se funda en ellos hasta que pase una expedición.
	for j in range(avistados.size()):
		var site: Site = avistados[j]
		var xform := Transform3D().scaled(Vector3.ONE * 1.2)
		xform.origin = terrain.geo_to_world(site.lon, site.lat)
		mm.set_instance_transform(marked.size() + j, xform)
		mm.set_instance_color(marked.size() + j, COLOR_DE_AVISTADO)

	_update_legend()


## Traza la frontera del contorno de una mascara.
##
## Del contorno REAL y no del poligono administrativo, porque el area jugable
## crece sobre la plataforma que emerge en cada epoca. Cinta y no linea porque
## Godot no engorda las lineas 3D y a esta escala se perderia.
## `ceder`, si se da, se llama entre filas: trazar una frontera son 720 ms, y al montar
## el mapa va detrás de la pantalla de carga (INTERFAZ §9).
func _trace_border(mask: PackedByteArray, w: int, h: int, ceder: Callable = Callable()) -> ArrayMesh:
	var sx := float(terrain.terrain_size.x) / float(w - 1)
	var sz := float(terrain.terrain_size.y) / float(h - 1)
	var half := (border_width_m / meters_per_unit) * 0.5
	var lift := (border_lift_m / meters_per_unit) * vertical_exaggeration

	# Suavizar la trama antes de trazar: la mascara vive en celdas de 111 m y
	# seguir sus bordes al pie de la letra dibuja una escalera de pixeles. Un
	# desenfoque y un nuevo umbral redondean esa escalera sin mover la silueta.
	var soft := await _smooth_mask(mask, w, h, 3, ceder)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 0

	for z in range(h - 1):
		if ceder.is_valid() and z % 16 == 0:
			await ceder.call()
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
func _smooth_mask(mask: PackedByteArray, w: int, h: int, radius: int,
		ceder: Callable = Callable()) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var out := PackedFloat32Array()
	out.resize(w * h)
	var window := float(radius * 2 + 1)

	for z in range(h):
		if ceder.is_valid() and z % 32 == 0:
			await ceder.call()
		var row := z * w
		var acc := 0.0
		for x in range(-radius, radius + 1):
			acc += 1.0 if mask[row + clampi(x, 0, w - 1)] > 127 else 0.0
		for x in range(w):
			tmp[row + x] = acc / window
			acc -= 1.0 if mask[row + clampi(x - radius, 0, w - 1)] > 127 else 0.0
			acc += 1.0 if mask[row + clampi(x + radius + 1, 0, w - 1)] > 127 else 0.0

	for x in range(w):
		if ceder.is_valid() and x % 32 == 0:
			await ceder.call()
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
	_poner_entradas()
	if _selected == null:
		_detail.text = "Click en el mapa para ver el
emplazamiento mas cercano"
		return

	var era := _eras.index_for(_sea_level_m) if _eras else 0
	# LO QUE SE SABE PRIMERO, y de un sitio no descubierto, nada más: ver
	# [ficha_del_sitio].
	var descubierto := not GameState.started or GameState.is_discovered(_selected)
	var sabido := ficha_del_sitio(_selected, descubierto, Guardado.cabeceras())
	if not descubierto:
		_detail.text = "\n".join(sabido)
		return
	var lines := Array(sabido)
	lines.append("")
	lines.append_array([
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
	])
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
	lines.append("[F] entrar al mapa")
	_detail.text = "
".join(lines)


## Un botón por cueva explorada del campamento de este sitio, para entrar a mirar.
## La lista es [Pinturas.cuevas_para_entrar].
##
## **Sólo si hay campamento vivo en el sitio**: lo explorado es de cada
## campamento, y una visita desde aquí no lleva gente que explore. Por eso Altamira
## sólo se ve por dentro si hay una banda allí que la haya recorrido (SISTEMAS §13,
## plan técnico).
func _poner_entradas() -> void:
	if _entradas == null:
		return
	for hijo: Node in _entradas.get_children():
		_entradas.remove_child(hijo)
		hijo.queue_free()
	if _selected == null:
		return
	var campamento := Campamentos.de_sitio(_selected.id)
	if campamento == null or campamento.sim == null:
		return
	for entrada: Array in campamento.sim.pinturas.cuevas_para_entrar():
		var cueva := int(entrada[0])
		var nombre := String(entrada[1])
		var boton := Button.new()
		boton.text = "Entrar en %s" % nombre
		boton.pressed.connect(func() -> void:
			var sala := SalaDeLaCueva.new()
			get_node("UI").add_child(sala)
			sala.montar(campamento.sim, cueva, nombre))
		_entradas.add_child(boton)


## Lo que se sabe de un sitio, para la ficha del mapa regional.
##
## Frente 18 de EPOCA_01 §10.1, tanda 4: «al pinchar un sitio descubierto se ve
## lo que se sabe de él: si tiene gente y el trato con ella, qué recursos se
## conocen, y si su cueva está explorada o pintada». **Y de uno no descubierto,
## nada**: ni nombre, que el nombre también es saber.
##
## Estático y sin estado propio: lee el sitio y las cabeceras de los mapas
## guardados, que es todo lo que el mapa regional tiene (SPECS §4.7).
static func ficha_del_sitio(site: Site, descubierto: bool,
		cabeceras: Array[Dictionary]) -> PackedStringArray:
	var lineas := PackedStringArray()
	if not descubierto:
		lineas.append("SIN DESCUBRIR")
		lineas.append("Hay que llegar hasta aquí para saber qué hay.")
		return lineas

	lineas.append(site.display_name().to_upper())

	# La gente: el trato de cualquier mapa donde se les conozca. Si varios mapas
	# los conocen, manda el más reciente, que es lo último que se supo.
	var trato_visto := false
	var trato := 0.0
	var mas_reciente := -1
	for cabecera: Dictionary in cabeceras:
		var tratos: Dictionary = cabecera.get("trato", {})
		if tratos.has(site.id) and int(cabecera.get("jornada", 0)) > mas_reciente:
			trato_visto = true
			trato = float(tratos[site.id])
			mas_reciente = int(cabecera.get("jornada", 0))
	if trato_visto:
		lineas.append("Vive gente. Trato %s." % PanelRelaciones.como_va(trato))
	else:
		lineas.append("No se sabe si vive gente.")

	# Los recursos que se conocen: los del catálogo que se ven sin quedarse.
	var recursos := PackedStringArray()
	if site.water_km < 1.0:
		recursos.append("agua cerca")
	if site.has_shelter:
		recursos.append("abrigo")
	if site.cave_count() > 0:
		recursos.append("%d %s" % [site.cave_count(),
			"cueva" if site.cave_count() == 1 else "cuevas"])
	lineas.append("Recursos: %s." % (", ".join(recursos) if not recursos.is_empty()
		else "nada que se sepa"))

	# Su cueva: sólo si se ha vivido en ese mapa y está guardado.
	var propia: Dictionary = {}
	for cabecera: Dictionary in cabeceras:
		if int(cabecera.get("sitio", -1)) == site.id:
			propia = cabecera
	if propia.is_empty():
		lineas.append("Nadie de la banda ha estado dentro de sus cuevas.")
	elif bool(propia.get("pintada", false)):
		lineas.append("La cueva está pintada.")
	elif int(propia.get("cuevas_exploradas", 0)) > 0:
		lineas.append("%d %s explorada%s, %d con pared para pintar." % [
			int(propia["cuevas_exploradas"]),
			"cueva" if int(propia["cuevas_exploradas"]) == 1 else "cuevas",
			"" if int(propia["cuevas_exploradas"]) == 1 else "s",
			int(propia.get("cuevas_pintables", 0))])
	else:
		lineas.append("Sus cuevas están sin explorar.")
	return lineas


## El panel de la banda y de los mapas guardados, para el mapa regional.
##
## Frente 18: «dónde vive la banda, en qué jornada está cada mapa visitado, y
## cómo volver». Estático: lee las cabeceras y el último mapa jugado.
static func panel_de_la_banda(cabeceras: Array[Dictionary], ultimo: int,
		nombres: Dictionary) -> PackedStringArray:
	var lineas := PackedStringArray()
	if cabeceras.is_empty():
		lineas.append("La banda todavía no se ha asentado en ningún mapa.")
		return lineas
	var ordenadas := cabeceras.duplicate()
	ordenadas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sitio", 0)) < int(b.get("sitio", 0)))
	for cabecera: Dictionary in ordenadas:
		var sitio := int(cabecera.get("sitio", -1))
		var nombre := String(nombres.get(sitio, "Sitio %d" % sitio))
		var marca := "  ← la banda está aquí" if sitio == ultimo else ""
		lineas.append("%s · jornada %d · %d personas%s" % [nombre,
			int(cabecera.get("jornada", 0)), int(cabecera.get("poblacion", 0)), marca])
	lineas.append("Pulsa el sitio y F para volver a él.")
	return lineas


## Funda en el emplazamiento seleccionado: descarga su relieve fino, guarda el
## recuadro y salta a la capa local.
##
## Las teselas se bajan AQUI y no antes porque a 13,9 m por muestra toda
## Cantabria serian unas 960 teselas; del sitio elegido son cuatro.
func _found_settlement() -> void:
	if _selected == null or _founding:
		return

	# EN DEBUG SE FUNDA EN CUALQUIERA, CON UNA BANDA NUEVA (INTERFAZ §14): ni campamento
	# que retomar, ni visita. Lo demás —preparar el valle con su pantalla— es lo de siempre.
	if ModoDebug.activo:
		ModoDebug.nueva_fundacion(_site_set)
	else:
		# EL MAPA DE LA BANDA SE RETOMA; LOS DEMÁS SE VISITAN. Entrar en un mapa sin
		# estado fundaba ahí otra banda —el usuario acabó con tres—, y el 2026-09-13
		# pisaba la partida. Desde el 2026-09-14 la banda sólo se asienta en el primer
		# mapa: «no debe traer a mi banda, sólo cargar y mostrarme el mapa». Ver
		# [Guardado.sitio_de_la_banda].
		# UN CAMPAMENTO VIVO SE MIRA: la partida lo lleva y no hay nada que leer de
		# disco. SISTEMAS §23, punto 8.
		var vivo := Campamentos.de_sitio(_selected.id)
		if vivo != null:
			_entrar_en_el_campamento(vivo)
			return
		var banda := Guardado.sitio_de_la_banda()
		if banda == _selected.id:
			_retomar_en(_selected.id)
			return
		Expedition.visita = banda >= 0 or not Campamentos.vivos.is_empty()

	_founding = true

	# La receta de preparar el valle vive en [PreparaValle]: la usa también la ficha
	# de un campamento para migrar, y tiene que ser la misma.
	var preparador := PreparaValle.new()
	preparador.aviso.connect(func(texto: String) -> void: _detail.text = texto)
	# Con la pantalla de carga: preparar un valle nuevo son decenas de segundos, y la
	# carga del mapa que viene detrás sigue en la misma barra. INTERFAZ §9.
	Carga.abrir(get_tree(), "Preparando %s" % _selected.display_name())
	Carga.etapas(PreparaValle.ETAPAS)
	preparador.etapa_cambiada.connect(Carga.etapa)
	# CON EL MAR DE ESTE MAPA, dicho a las claras: el valle se levanta y se rellena con la
	# época que se está jugando, y `Expedition` todavía no la tiene puesta aquí.
	preparador.mar_de_la_epoca = _sea_level_m
	var local := await preparador.preparar(get_tree(), _selected, Carga.avanzar_por_tiempo)
	if local == null:
		_founding = false
		Carga.cerrar()
		return
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

	print("Entrando en %s (%.4f, %.4f)" % [_selected.display_name(), _selected.lat, _selected.lon])
	Carga.abrir(get_tree(), "Entrando en %s" % _selected.display_name())
	Carga.cambiar_de_escena(get_tree(), Expedition.LOCAL_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed 			and event.button_index == MOUSE_BUTTON_LEFT:
		_select_site(_pick_site(event.position))
		get_viewport().set_input_as_handled()

	# POR ACCION, no por tecla: las teclas viven en [Teclas] y se cambian desde
	# Configuración (INTERFAZ §11).
	if event is InputEventKey and event.pressed and not event.echo:
		if Teclas.es(event, "cerrar"):
			# El mismo menú que en el valle: guardar, cargar y salir
			# también desde aquí, que es la otra pantalla de una partida.
			# Ver [MenuDelJuego] y `docs/INTERFAZ.md` §7.
			if _menu_del_juego == null:
				return
			if _menu_del_juego.esta_abierto():
				_menu_del_juego.cerrar()
			else:
				_menu_del_juego.abrir()
			get_viewport().set_input_as_handled()
			return
		for numero in range(1, 6):
			if Teclas.es(event, "numero_%d" % numero):
				_assign_party(numero - 1)
				return
		if Teclas.es(event, "numero_0"):
			_assignment.clear()
			_update_band()
		elif Teclas.es(event, "resolver"):
			_resolve_season()
		elif Teclas.es(event, "fundar"):
			_found_settlement()
		elif Teclas.es(event, "ficha_del_sitio"):
			abrir_la_ficha()
		elif Teclas.es(event, "cambiar_era"):
			_era = ((_era + 1) % (Site.Era.HISTORICA + 1)) as Site.Era
			_refresh_sites()
			if _selected and not _visible_sites.has(_selected):
				_select_site(null)
			_update_info()


## Cuánto se exageran los ríos al pintarlos en el mapa regional, y su mínimo en celdas.
## Un vértice de la malla regional son unos 195 m: con el ancho de verdad sólo se veían
## los cauces grandes, y por debajo de 0,8 celdas el río sale a trozos. Con 4,5, el Saja
## en su boca pinta unas 2,5 celdas y un arroyo de cabecera, el mínimo. Decisión mirando
## capturas (EPOCA_01 §10.2).
const RIOS_ESCALA_DEL_ANCHO := 4.5
const RIOS_CELDAS_MINIMAS := 0.8


## Lo que distingue la malla regional de una época de la de otra, para su caché.
##
## Con los RÍOS desde el 2026-09-16 (EPOCA_01 §10.2): se tallan en la malla —el cauce se
## asienta en su lámina— y abren valle en la plataforma, así que otros ríos son otra
## malla.
static func sufijo_de_la_cache(mar: float) -> String:
	var rios := RiosDeLaRegion.cargar().huella()
	return "_mar%d_lomas%x_rios%x" % [roundi(mar), RelieveDeLaPlataforma.huella() & 0xffffff,
		hash([rios, RIOS_ESCALA_DEL_ANCHO, RIOS_CELDAS_MINIMAS]) & 0xffffff]


## Lo que se pasa como `ceder` al generar: mueve la barra por tiempo, y cambia de las
## alturas a la malla cuando el terreno empieza la malla.
func _ceder_al_generar() -> void:
	if terrain.generando_la_malla and Carga.texto() == String(ETAPAS[1][0]):
		Carga.siguiente()
	await Carga.ceder_y_avanzar()


func _setup_terrain() -> void:
	var mar := mar_del_mapa()
	# EL RELIEVE YA PREPARADO, SI ESTÁ: con lomas, valles y ríos pintados. Pintar los ríos
	# costaba 23 s en cada montaje del mapa (`PlataformaCaptura`, 2026-09-16), y es
	# siempre lo mismo para un mar y unos ríos.
	var preparado := heightmap_path.get_basename() + sufijo_de_la_cache(mar) + "_hidro.res"
	var data: HeightmapData = null
	if ResourceLoader.exists(preparado):
		data = await Carga.cargar(preparado) as HeightmapData
	if data != null:
		print("Relieve: preparado de %s" % preparado)
	else:
		data = await Carga.cargar(heightmap_path) as HeightmapData
		if data == null:
			push_error("RegionMap: no se pudo cargar " + heightmap_path)
			return
		data = _preparar_el_relieve(data, mar)
		var error := ResourceSaver.save(data, preparado)
		if error != OK:
			push_warning("RegionMap: no se guardó el relieve preparado (%d)" % error)
	await _montar_el_terreno(data)


## Las lomas y los valles de la plataforma, y los ríos pintados, sobre UNA COPIA del
## relieve regional. Ver [_setup_terrain], que lo guarda para no rehacerlo.
func _preparar_el_relieve(original: HeightmapData, mar: float) -> HeightmapData:
	# Una copia con lomas y cerros sobre la plataforma: el fondo del relieve sale
	# liso. La misma que hornea las máscaras. Ver [RelieveDeLaPlataforma].
	#
	# COPIA DE VERDAD de las cotas: `duplicate` comparte los arrays empaquetados con el
	# recurso cacheado, y escribir en la copia escribía en el original (memoria del
	# proyecto, 2026-09-15).
	var data := original.duplicate() as HeightmapData
	data.elevations = PackedFloat32Array(original.elevations)
	# CON EL MAR QUE ESTE MAPA VA A DIBUJAR, que es el de la partida si la hay y el
	# de hoy si no: el relieve entra sólo donde ya hay tierra con ese mar, así que
	# la costa no se mueve. Sin partida —una sonda, el mapa abierto a secas— el mar
	# está a cero y la plataforma sigue siendo fondo marino; aplicarle el relieve
	# del Paleolítico la sacaba entera del agua (visto en `RegionCaptura`,
	# 2026-09-14). Cambiar de época con la tecla E no rehace el relieve: el de la
	# plataforma es el de la época con la que se montó el mapa.
	# LOS RÍOS, horneados de OSM y prolongados por la plataforma (EPOCA_01 §10.2): el
	# relieve regional se horneó sin cauces y el mapa no dibujaba ni uno. Los de la
	# plataforma abren su valle en las lomas y, después, todos se pintan igual que en un
	# valle, con [Hydrography.apply].
	var rios := RiosDeLaRegion.cargar()
	var de_la_plataforma: Array = rios.de_la_plataforma \
		if mar <= rios.mar_de_la_plataforma + 0.5 else []
	RelieveDeLaPlataforma.aplicar(data, mar, de_la_plataforma)
	var t_rios := Time.get_ticks_msec()
	Hydrography.apply(data, rios.para_el_mar(mar), [], RIOS_ESCALA_DEL_ANCHO,
		RIOS_CELDAS_MINIMAS)
	print("Ríos del mapa regional: %d cauces en %d ms" % [rios.para_el_mar(mar).size(),
		Time.get_ticks_msec() - t_rios])
	return data


func _montar_el_terreno(data: HeightmapData) -> void:
	print("Relieve: ", data.describe())

	terrain = TerrainGenerator.new()
	terrain.name = "RegionTerrain"
	terrain.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
	terrain.heightmap = data
	# LA CACHÉ, POR EL RELIEVE DE ORIGEN Y NO POR LA COPIA: la copia no tiene ruta y la
	# malla se rehacía en cada viaje. Con el mar y las lomas en el nombre, porque las
	# dos cambian la copia. INTERFAZ §9, tarea 7.
	terrain.origen_de_la_cache = heightmap_path
	terrain.sufijo_de_la_cache = sufijo_de_la_cache(mar_del_mapa())
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
	# Su agua no sigue el ajuste «Agua»: el agua del regional se queda como estaba.
	terrain.agua_con_niveles = false

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


## El ancho de la ficha del sitio, y lo que se deja libre abajo para el panel de
## la banda. Decisión de las capturas a 1280×720, que es la pantalla pequeña.
const ANCHO_DE_LA_FICHA := 360
const ALTO_DEL_PANEL_DE_ABAJO := 270

## La letra de los paneles del mapa regional. A la de serie, a 1280×720 la
## cabecera se comía la leyenda y la ficha se montaba sobre el panel de la
## banda: capturado el 2026-09-13.
const LETRA := 12


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	canvas.add_child(panel)

	_info = Label.new()
	_info.text = "Cantabria"
	_info.add_theme_font_size_override("font_size", LETRA)
	panel.add_child(_info)

	# LA FICHA CABE EN LA PANTALLA. Medía 1 505 px de alto con un sitio de
	# muchas cuevas —medido con `RegionCaptura` el 2026-09-13— y se salía a
	# 1920×1080 y a 1280×720. Ahora va anclada a todo el alto del lado derecho,
	# con margen arriba para la cabecera y abajo para el panel de la banda, y lo
	# que no quepa se desplaza. El ancho, fijo y estrecho: es una ficha, no una
	# página.
	var detail_margin := MarginContainer.new()
	detail_margin.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	detail_margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	detail_margin.add_theme_constant_override("margin_top", 96)
	detail_margin.add_theme_constant_override("margin_right", 12)
	detail_margin.add_theme_constant_override("margin_bottom", ALTO_DEL_PANEL_DE_ABAJO)
	canvas.add_child(detail_margin)

	var detail_panel := PanelContainer.new()
	detail_margin.add_child(detail_panel)
	var desplaza := ScrollContainer.new()
	desplaza.custom_minimum_size = Vector2(ANCHO_DE_LA_FICHA, 0)
	desplaza.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(desplaza)
	var columna := VBoxContainer.new()
	desplaza.add_child(columna)
	_detail = Label.new()
	_detail.text = "Click en un emplazamiento para verlo"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(ANCHO_DE_LA_FICHA - 16, 0)
	_detail.add_theme_font_size_override("font_size", LETRA)
	columna.add_child(_detail)
	# Debajo de la ficha, entrar en las cuevas que ha explorado el campamento de ese
	# sitio. Ver [cuevas_para_entrar].
	_entradas = VBoxContainer.new()
	columna.add_child(_entradas)

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
	_band_label.add_theme_font_size_override("font_size", LETRA)
	band_panel.add_child(_band_label)

	_boton_de_retomar(canvas)
	_build_legend(canvas)

	var overlay := PerformanceOverlay.new()
	overlay.name = "PerformanceOverlay"
	add_child(overlay)


## El botón de volver al valle donde está la banda, si hay alguno.
##
## **No es «cargar partida»**, y desde que existe el menú principal —2026-09-13,
## INTERFAZ §7— hay que distinguirlo bien: cargar una partida es abrir otra
## historia, y esto es entrar en un valle de LA PARTIDA QUE SE ESTÁ JUGANDO,
## donde la banda se quedó. Ver [Guardado], [Partidas] y EPOCA_01 §10.1, tanda
## 3, frente 15.
func _boton_de_retomar(canvas: CanvasLayer) -> void:
	var guardado := Guardado.leer()
	if guardado.is_empty():
		return
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 64)
	canvas.add_child(margin)

	var caja := VBoxContainer.new()
	margin.add_child(caja)
	var boton := Button.new()
	boton.text = "Entrar donde está la banda (jornada %d)" \
		% int(guardado.get("jornada", 0))
	boton.tooltip_text = ("Vuelve al valle donde se quedó la banda de esta "
		+ "partida. Para abrir otra partida, ESC → Cargar.")
	boton.pressed.connect(_retomar)
	caja.add_child(boton)

	# Y el estado de la banda y de cada mapa guardado. Ver [panel_de_la_banda].
	var nombres := {}
	if _site_set != null:
		for cabecera: Dictionary in Guardado.cabeceras():
			for site: Site in _site_set.sites:
				if site.id == int(cabecera.get("sitio", -1)):
					nombres[site.id] = site.display_name()
	var estado := Label.new()
	estado.text = "\n".join(panel_de_la_banda(Guardado.cabeceras(),
		Guardado.sitio_de_la_banda(), nombres))
	estado.add_theme_font_size_override("font_size", LETRA)
	caja.add_child(estado)


## Retoma el último mapa jugado. Es lo que hace el botón.
func _retomar() -> void:
	_retomar_en(Guardado.sitio_de_la_banda())


## Entra en un campamento que la partida lleva viva: el traspaso, del campamento.
## La escena lo adopta en vez de montarlo. Ver [DemoMain._montar_el_campamento].
func _entrar_en_el_campamento(campamento: Campamento) -> void:
	if _founding:
		return
	_founding = true
	Campamentos.traspaso_de(campamento)
	print("RegionMap: se entra en el campamento de %s" % campamento.nombre())
	Carga.abrir(get_tree(), "Volviendo a %s" % campamento.nombre())
	Carga.cambiar_de_escena(get_tree(), Expedition.LOCAL_SCENE)


## Entra en un mapa con estado guardado: deja el traspaso como estaba y entra.
func _retomar_en(sitio: int) -> void:
	if _founding or sitio < 0:
		return
	_founding = true
	# La pantalla antes que leer lo guardado, que también es del cuadro del clic. Ver
	# [MenuPrincipal._cargar].
	Carga.abrir(get_tree(), "Volviendo al valle")
	await get_tree().process_frame
	Expedition.visita = false
	var guardado := Guardado.leer(sitio)
	if guardado.is_empty() or _site_set == null \
			or not Guardado.preparar_la_escena(guardado, _site_set):
		if not guardado.is_empty():
			print("RegionMap: la partida guardada apunta a un emplazamiento que no está")
		_founding = false
		Carga.cerrar()
		return
	Expedition.retomando = true
	print("RegionMap: se retoma la partida en %s" % Expedition.site.display_name())
	Carga.cambiar_de_escena(get_tree(), Expedition.LOCAL_SCENE)


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
	title.add_theme_font_size_override("font_size", LETRA)
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
		label.add_theme_font_size_override("font_size", LETRA)
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
		"F           entrar al mapa seleccionado",
		"R           mandar una expedición hacia un rumbo",
		# LA DEL PANEL SE PREGUNTA, NO SE ESCRIBE: es remapeable (INTERFAZ §11) y este
		# cartel decía F3 cuando el panel ya vivía en F4. Las otras dos no son acciones del
		# catálogo de teclas, así que siguen escritas.
		"WASD mover · click derecho rotar · rueda zoom · %s rendimiento"
			% Teclas.nombre_de_la_tecla(Teclas.tecla_de("panel_de_rendimiento")),
	])


## Pone la mascara del territorio de la epoca en curso.
##
## Va aparte porque hay que llamarla en DOS momentos que no se pueden juntar:
## al cambiar de epoca, y justo despues de generar el terreno. Generar monta el
## material desde cero y lo deja con la frontera administrativa de hoy, que
## deja fuera -y por tanto gris- toda la plataforma emergida.
func _apply_era_mask(ceder: Callable = Callable()) -> void:
	if terrain == null:
		return
	if _eras == null:
		push_warning("Sin mascaras de epoca: el mapa queda con la frontera "
			+ "de hoy y la plataforma emergida sale gris.")
		return

	var index := maxi(_era_index, 0)
	var texture := _eras.mask_texture(index)
	terrain.set_region_mask_texture(texture)
	await _show_border(index, ceder)

	# Se dice en voz alta porque una mascara que no cubre lo que deberia NO
	# se ve como un fallo: se ve como que el terreno esta mal pintado, y uno
	# se pasa la tarde mirando el shader.
	print("Territorio: epoca %d de %d · mar %+.0f m · mascara %s" % [
		index + 1, _eras.sea_levels.size(), _sea_level_m,
		"puesta" if texture else "NO DISPONIBLE"])
