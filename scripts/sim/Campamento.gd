class_name Campamento
extends Node3D
## Un mapa con gente: todo lo que hace falta para que la partida corra en él, y
## nada de lo que la dibuja.
##
## Sale de `DemoMain` (SISTEMAS §23, tarea 2 de la fase 1). Hasta el 2026-09-14
## la partida ERA la escena: la simulación, el relieve, la fauna y las cuevas
## eran nodos de `DemoMain`, y cambiar de escena los destruía. Con eso no se
## puede simular lo que no se mira, que es lo que pide §23. Aquí vive la parte
## que decide partida; `DemoMain` es ahora **la vista de un campamento**: la
## cámara, la interfaz, el bosque, los alfileres.
##
## **La regla para saber qué va aquí**: si al dejar de mirar el mapa esto
## dejara de pasar, la partida sería otra. Por eso vienen también cuatro cosas
## que la escena hacía por la partida sin que se notara —descubrir cuevas, contar
## técnicas, reelegir tajos al mudarse y fijar el caudal del río—: con el mapa
## sin mirar habrían dejado de pasar, y la firma diaria lo habría delatado.
##
## **EL ORDEN DE MONTAJE ES EL DE ANTES**, y no por costumbre: repartir la gente,
## sembrar la comarca y asentarse consumen tiradas del `_rng` de la simulación
## (SPECS §3.3), así que cambiar el orden es cambiar la partida. Las vistas que
## iban intercaladas usan su propio azar y no escriben en la simulación
## —comprobado al separarlas—, y por eso pueden montarse por fuera.

## Lo que trae `scenes/demo_main.tscn` sobre los `@export` de `DemoMain`: el
## relieve de la partida de verdad es de 825 de resolución y no de 513. Lo usan
## [montar] y quien monte un campamento sin la escena.
const RESOLUCION := 825
const ALTURA := 30.0
const SEMILLA_DEL_RELIEVE := 12345

var terrain: TerrainGenerator
var sim: SettlementSim
var field: ResourceField
var knowledge: BandKnowledge
var herds: WildlifeHerds
var tech: TechTree
var caves: Array[CaveMouth] = []

## El emplazamiento de este campamento. Se copia de [Expedition] al montarlo: el
## traspaso regional → local es de un momento, y el campamento dura más.
var sitio: Site

## El relieve local y el recuadro de este campamento: lo que guarda [Guardado]
## para volver a montarlo. En la escena son los de `Expedition`.
var relieve: String = ""
var recuadro: Vector2 = Vector2.ZERO
var era: Site.Era = Site.Era.PALEOLITICO


## El nombre del campamento: el de su sitio. Va en las decisiones y en la crónica
## cuando hay varios. Ver [SettlementSim.nombre_del_campamento].
func nombre() -> String:
	return sitio.display_name() if sitio != null else "el campamento"


## Si el valle de un sitio está preparado: su relieve fino, horneado. Fundar
## sin él pediría descargar a mitad de partida; se prepara al mandar el viaje
## (decisión del usuario del 2026-09-14).
static func valle_preparado(id: int) -> bool:
	return ResourceLoader.exists("res://data/dem/local/site_%d.res" % id)


## Monta un campamento SIN VISTA en un sitio, en el orden en que lo monta
## `DemoMain`: relieve, bocas, cuevas, simulación, comarca, conocimiento, cueva
## de casa, fauna y técnica. Lo cuelga de la raíz para montarlo —como la
## escena— y quien lo llame decide si lo saca después
## ([Campamentos.dejar_de_mirar]).
##
## No empieza la partida ni elige tajos: eso depende de si es la primera banda o
## un grupo que llega. Devuelve null si el valle no está preparado.
static func montar(arbol: SceneTree, sitio_de: Site, poblacion: int,
		comida: float) -> Campamento:
	if sitio_de == null or not valle_preparado(sitio_de.id):
		return null
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % sitio_de.id)
	# El recuadro, como lo calcula `RegionMap` al entrar en un mapa.
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	var campamento := Campamento.new()
	campamento.name = "Campamento_%d" % sitio_de.id
	campamento.relieve = "res://data/dem/local/site_%d.res" % sitio_de.id
	campamento.recuadro = Vector2(
		clampf(local.u_for_lon(sitio_de.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(sitio_de.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))

	# EL TRASPASO ES DE LA ESCENA, y se devuelve como estaba: `preparar_el_relieve`
	# lee el sitio y la era de `Expedition`, pero un campamento que se funda o se
	# retoma sin mirarlo no puede cambiar el mapa que se está mirando —guardarlo
	# después lo guardaría con el relieve de otro valle—.
	var antes: Array = [Expedition.site, Expedition.heightmap_path,
		Expedition.sea_level_m, Expedition.era, Expedition.region_offset]
	Expedition.site = sitio_de
	Expedition.heightmap_path = campamento.relieve
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = GameState.era
	Expedition.region_offset = campamento.recuadro
	arbol.root.add_child(campamento)
	campamento.preparar_el_relieve(
		Vector2i(Expedition.local_size_m, Expedition.local_size_m), RESOLUCION,
		ALTURA, SEMILLA_DEL_RELIEVE, Expedition.sea_level_m, true,
		Expedition.heightmap_path, Expedition.region_offset)
	Expedition.site = antes[0]
	Expedition.heightmap_path = antes[1]
	Expedition.sea_level_m = antes[2]
	Expedition.era = antes[3]
	Expedition.region_offset = antes[4]
	campamento.marcar_las_bocas()
	campamento.terrain.generate()
	campamento.colocar_las_cuevas()
	var home := campamento.casa()
	campamento.levantar_la_simulacion(home, poblacion, comida)
	campamento.levantar_el_conocimiento(home)
	campamento.asentar_en_la_cueva()
	campamento.levantar_fauna_y_tecnica()
	return campamento


## El punto del emplazamiento en el valle.
func casa() -> Vector3:
	return terrain.geo_to_world(sitio.lon, sitio.lat)


# --- el relieve -------------------------------------------------------------

## Crea el generador de relieve con lo que traía la escena en sus `@export`.
##
## Separado de `terrain.generate` porque entre las dos cosas la vista monta cámara e
## interfaz, y el generador ya tiene que existir para que se cuelguen de él.
func preparar_el_relieve(tam: Vector2i, resolucion: int, altura: float,
		semilla: int, mar: float, real: bool, dem: String, recuadro: Vector2) -> void:
	if Expedition.is_active():
		sitio = Expedition.site
		era = Expedition.era

	terrain = TerrainGenerator.new()
	terrain.name = "TerrainGenerator"
	terrain.terrain_size = tam
	terrain.resolution = resolucion
	terrain.max_height = altura
	terrain.seed_value = semilla
	terrain.sea_level = mar

	if real and ResourceLoader.exists(dem):
		var data := load(dem) as HeightmapData
		if data:
			terrain.height_source = TerrainGenerator.HeightSource.HEIGHTMAP
			terrain.heightmap = data
			terrain.heightmap_region_offset = recuadro
			# A escala local la altitud no separa pasto de roca: eso lo hace la
			# pendiente. Con bandas absolutas el recuadro salia entero marron.
			terrain.bands_relative = true
			print("Terreno real: ", data.describe())
			print("  recuadro en uso: %.0f x %.0f m desde (%.0f, %.0f)" % [
				tam.x, tam.y, recuadro.x, recuadro.y])
		else:
			push_warning("No se pudo cargar el heightmap, se usa el procedural")
	elif real:
		push_warning("No existe %s, se usa el terreno procedural" % dem)

	add_child(terrain)


## Marca en el terreno las entalladuras de las bocas de cueva.
##
## Se hace antes de generar porque la excavacion altera el heightmap y con el
## se construyen la malla, las normales y la colision.
func marcar_las_bocas() -> void:
	if sitio == null or terrain == null:
		return

	# Dónde se abre de verdad cada boca lo decide [Bocas] al generar, con el
	# relieve hecho y antes de excavar: si cae en el agua o donde no se llega
	# desde casa, se mueve, y la entalladura va con ella.
	var casa := terrain.geo_to_world(sitio.lon, sitio.lat)
	terrain.colocar_las_bocas = func(t: TerrainGenerator) -> Array[Dictionary]:
		return Bocas.colocar(t, t.carvings, casa)

	var marked := 0
	var features := sitio.features_in(era)
	for indice in range(features.size()):
		var f: Dictionary = features[indice]
		if int(f.get("class", Site.Feature.OTRO)) != Site.Feature.ABRIGO:
			continue
		var world := terrain.geo_to_world(f.get("lon", 0.0), f.get("lat", 0.0))
		if world.x < 0.0 or world.z < 0.0 \
				or world.x > terrain.terrain_size.x or world.z > terrain.terrain_size.y:
			continue
		# Ceñida a la visera de ESA cueva, que va de 3 a 6 m: ver
		# [CaveMouth.entalladura_de]. Eran 13 m de radio y 9 de hondo para todas.
		var hueco := CaveMouth.entalladura_de(f)
		terrain.carvings.append({
			"position": world,
			"radius": float(hueco["radius"]),
			"depth": float(hueco["depth"]),
			# La sima: el radio del pozo y lo que baja. La malla del relieve
			# quita su ruedo y cose ahi un embudo fino, que a un punto cada
			# cinco metros un agujero de dos sale cuadrado. Ver
			# [TerrainGenerator.simas] y [MallaDelTerreno._construir_simas].
			"boca": CaveMouth.hueco_de(f),
			"hondo": CaveMouth.PROFUNDIDAD_DE_LA_SIMA,
			# Para que [colocar_las_cuevas] ponga cada boca donde quedó SU
			# entalladura, y no donde decía el catálogo.
			"feature": indice,
		})
		marked += 1
	print("Bocas de cueva excavadas en la malla: %d" % marked)


# --- las cuevas -------------------------------------------------------------

## Las bocas de cueva del emplazamiento, donde las dejó [Bocas].
##
## **Son geometría y estado a la vez**: una `CaveMouth` se dibuja, pero también
## sabe si está descubierta, dónde se duerme y dónde está la campa, y eso lo
## guarda [Instantanea]. Por eso van con el campamento aunque se vean: sin ellas
## un mapa sin mirar no descubriría cuevas. Separar la malla del estado es
## trabajo de después, si la memoria lo pide (§23, riesgos).
##
## Los jalones de lo que no es cueva —manantiales, cavidades sin clasificar— son
## sólo señal y los pone la vista.
func colocar_las_cuevas() -> void:
	if sitio == null or terrain == null:
		return

	var raiz := Node3D.new()
	raiz.name = "Cuevas"
	add_child(raiz)

	# Dónde quedó cada boca, por su índice en el catálogo. Ver [Bocas].
	var bocas := {}
	for boca: Dictionary in terrain.carvings_colocadas:
		bocas[int(boca.get("feature", -1))] = boca
	var features := sitio.features_in(era)
	for indice in range(features.size()):
		var f: Dictionary = features[indice]
		if int(f.get("class", Site.Feature.OTRO)) != Site.Feature.ABRIGO:
			continue

		var world := terrain.geo_to_world(f.get("lon", 0.0), f.get("lat", 0.0))
		# Puede caer fuera del recuadro de 4 km aunque este a menos de 2 km
		# del centro, porque el recuadro es cuadrado y el radio circular
		if world.x < 0.0 or world.z < 0.0 \
				or world.x > terrain.terrain_size.x or world.z > terrain.terrain_size.y:
			continue

		# La boca, donde la dejó [Bocas]: nunca en el agua ni donde no se llega.
		if bocas.has(indice):
			var boca: Dictionary = bocas[indice]
			world = boca["position"]
			# Y su campa en seco, que la cueva usa para todo lo de fuera. Ver
			# [Bocas.campa_de] y [CaveMouth.forecourt_point].
			if boca.has("campa"):
				f = f.duplicate()
				f["campa"] = boca["campa"]
			if float(boca.get("movida_m", 0.0)) > 0.0:
				print("Cueva %s movida %.0f m: caía en el agua o donde no se llega"
					% [String(f.get("name", "")), float(boca["movida_m"])])

		# LA ALTURA ES LA DEL BORDE, no la del fondo. Desde que la cueva es una
		# sima de cincuenta metros —ver [CaveMouth.PROFUNDIDAD_DE_LA_SIMA]—,
		# preguntar la cota en el punto de la boca devuelve el fondo del pozo, y
		# con ella se hundían la marca, la gente y la hoguera. El borde se mide en
		# corro, por fuera de la boca.
		world.y = _borde_de_la_sima(world, CaveMouth.hueco_de(f))

		# Boca construida contra la ladera y orientada cuesta abajo, que es
		# como se abre una cueva. La media esfera mirando al cielo que
		# habia aqui parecia un agujero pintado en el suelo.
		var cave := CaveMouth.new()
		cave.id = indice
		raiz.add_child(cave)
		cave.build(terrain, world, f)
		caves.append(cave)


## La cota del borde de una sima: la mediana del corro de alrededor, que no la
## mueve ni un canchal ni una vaguada sueltos.
func _borde_de_la_sima(centro: Vector3, radio: float) -> float:
	var cotas: Array[float] = []
	for i in range(12):
		var angulo := TAU * float(i) / 12.0
		cotas.append(terrain.get_height_at(centro + Vector3(
			cos(angulo) * radio * 1.4, 0.0, sin(angulo) * radio * 1.4)))
	cotas.sort()
	return cotas[cotas.size() / 2]


## La boca de cueva más cercana a un punto, o null si no hay ninguna cerca.
func cueva_en(point: Vector3) -> CaveMouth:
	var best: CaveMouth = null
	var best_dist := 90.0
	for cave: CaveMouth in caves:
		var reach := cave.pick_position().distance_to(point)
		if reach < best_dist:
			best_dist = reach
			best = cave
	return best


# --- la partida -------------------------------------------------------------

## La simulacion y el campo de recursos: lo primero de todo, porque el resto
## le pregunta a ellos.
##
## `setup` va ANTES que nada mas porque asignar los tajos ya necesita saber
## si se llega a ellos, y eso lo decide el terreno que se le pasa aqui.
func levantar_la_simulacion(home: Vector3, poblacion: int, comida: float) -> void:
	sim = SettlementSim.new()
	sim.name = "Asentamiento"
	sim.nombre_del_campamento = nombre()
	sim.sitio = sitio
	add_child(sim)

	sim.setup(terrain, home, poblacion, comida)

	# LA COMARCA DE AHI FUERA: quien vive en cada sitio. Va aqui y no en `setup`
	# porque la comarca es un dato regional horneado que la simulacion local no
	# carga por su cuenta, y SPECS §2.3 dice que este es el unico sitio donde se
	# cablean subsistemas. Sin esto nadie vivia en ninguna parte: compilaba, y no
	# funcionaba. (La expedicion ya no la necesita aqui: busca en la comarca los
	# sitios de su pasillo al volver. Ver [Expedicion].)
	var comarca := SiteSet.comarca()
	if comarca != null:
		var ids := PackedInt32Array()
		for otro: Site in comarca.available_in(GameState.sea_level_m, GameState.era):
			# La cueva de la banda no esta «ocupada por otro grupo»: es la suya.
			if GameState.home != null and otro.id == GameState.home.id:
				continue
			ids.append(otro.id)
		sim.contacto.repartir_la_gente(ids)

	# Lo que el valle tiene, repartido en manchas y con su estacion
	field = ResourceMapper.build(terrain, home)


## La cronica y lo que la banda sabe del valle, que al llegar es nada.
##
## Sabe que en el rio hay peces; no sabe en que remanso. Eso lo aprende
## pisandolo. Lo de alrededor del campamento si lo conoce: vive ahi.
## `ceder` va a [Querencia.asentarse]: lo pasa quien monta la escena detrás de una
## pantalla de carga.
func levantar_el_conocimiento(home: Vector3, ceder: Callable = Callable()) -> void:
	sim.chronicle = Chronicle.new()
	sim.chronicle.record(sim.day, sim.estacion as int, sim.anyo,
		Chronicle.Kind.GENTE,
		"La banda se instala en %s. Son %d, y no conocen el valle."
			% [sitio.display_name() if sitio != null else "el abrigo",
				sim.population()], 2)

	knowledge = BandKnowledge.new()
	knowledge.setup(field.width, field.height, field.world_size)
	sim.field = field
	sim.knowledge = knowledge

	# La banda ya conoce lo que tiene alrededor del campamento: vive ahi. Sin
	# esto arrancaria sin ver ni su propia cueva, que es absurdo -y ademas
	# dejaria el mapa entero en negro sin nada por donde empezar a leerlo.
	knowledge.see_from(home, sim.sight_range * 1.6)

	# Y LO QUE YA SABE DE SUS ALREDEDORES. Va AQUI y no en `sim.setup`, que es
	# donde estuvo primero y no servia de nada: el campo de recursos se puebla
	# en esta funcion, o sea DESPUES de `setup`, asi que `Querencia` corria con
	# `sim.field` a null y sembraba cero parajes.
	#
	# Una banda no llega a un valle y planta el campamento a ciegas: elige el
	# abrigo por lo que tiene alrededor. Ver [Querencia].
	var sembrados := await Querencia.new(sim).asentarse(ceder)
	print("La banda se asienta: %d parajes de la primera vuelta al abrigo"
		% sembrados)


## La cueva de casa manda dónde se duerme y dónde se hace corro, y el calendario
## manda cuánta agua lleva el río.
##
## Sin lo primero la banda se apila en el punto del emplazamiento, a la
## intemperie. Lo segundo **estaba en la vista**, en el mismo sitio que la cota de
## nieve y el color del pasto, pero no es paisaje: un río crecido no se vadea, y
## sin mirar el mapa se habría quedado con el caudal del día que se dejó de mirar.
func asentar_en_la_cueva() -> void:
	var home_cave := cueva_en(sim.home_position)
	# Y si la banda se muda, los tajos se buscan otra vez alrededor de la casa
	# nueva. La hoguera y las obras que se ven van con la vista. Ver [Traslado].
	sim.campamento_trasladado.connect(_on_campamento_trasladado)
	if home_cave != null:
		# La de casa sale siempre pintable al explorarla. Ver
		# [Exploracion.cueva_de_la_banda].
		sim.exploracion.cueva_de_la_banda = home_cave.id
		# Qué cueva es cuál, para que la pared sepa si ésta tiene arte documentado.
		# Ver [Pinturas.elementos].
		sim.pinturas.elementos = sitio.features_in(era)
		sim.pinturas.sitio_id = sitio.id
		sim.home_inside = home_cave.inside_point()
		sim.home_forecourt = home_cave.forecourt_point()
		# El interior NO se apoya en el terreno, y ahí está la diferencia: la
		# galería se mete DENTRO de la ladera, así que preguntarle la altura al
		# terreno en ese punto devuelve la del monte que hay encima —medido,
		# once metros más arriba— y la banda dormía en el tejado de su cueva. El
		# suelo de la cueva es el de su boca, que es la altura que ya trae
		# `inside_point`. Antes se tomaba la de `pick_position`, que va 2,8 m
		# por encima para que se pueda pinchar: la banda dormía flotando.
		sim.home_inside.y = home_cave.inside_point().y
		if terrain:
			# Y en el trozo MÁS LLANO de la campa, no en el punto exacto que
			# salga de la geometría de la boca: ahí es donde se hace el fuego,
			# se plantan los troncos y se junta la banda, y en una cuesta la
			# hoguera se entierra por el lado de arriba —queja del usuario del
			# 2026-09-13—. Ver [ObrasDelAbrigo.asiento_llano].
			sim.home_forecourt = ObrasDelAbrigo.asiento_llano(
				terrain, sim.home_forecourt, Bonfire.RING_RADIUS)

	# El calendario del río, ya en la estación de arranque y luego cada jornada.
	sim.temporada.asentar(sim.estacion as Subsistence.Season)
	sim.day_passed.connect(_on_dia_para_el_rio)
	_on_dia_para_el_rio(sim.day)
	# Y las cuevas que la banda va encontrando, a HORAS DE JUEGO: escriben en
	# la cronica, asi que cada cuanto se miran es de la partida y no del
	# fotograma. Ver docs/specs/LO_MISMO_MAS_DEPRISA.md, paso 0.
	sim.hour_passed.connect(_on_hora_para_los_hallazgos)


## El caudal de la jornada. Lo que cierra el paso es esto, no el azul del agua.
func _on_dia_para_el_rio(_day: int) -> void:
	if terrain == null or sim == null or sim.temporada == null:
		return
	terrain.caudal = sim.temporada.caudal()


func _on_hora_para_los_hallazgos(_dia: int, _hora: int) -> void:
	revisar_hallazgos()


## La fauna que anda de verdad por el valle, y el arbol de tecnicas.
func levantar_fauna_y_tecnica() -> void:
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
		# Aprender a hacer algo es un hito, y se cuenta como tal —con su relato
		# y la opcion de dejarlo en la pared, ver [Tale]—. **Esto estaba en la
		# vista**, junto al aviso en pantalla: sin mirar el mapa, la banda habria
		# aprendido tecnicas sin que se contaran. El aviso sigue alli.
		sim.tecnica_aprendida.connect(_on_tecnica_aprendida)


func _on_tecnica_aprendida(gained: int) -> void:
	var learned := gained as TechTree.Tech
	print("Tecnica aprendida: %s" % TechTree.tech_name(learned))
	if sim:
		sim.tell_technique(learned)


## Busca las cumbres que la banda tiene a la vista, al empezar.
##
## **Esto lo hacía la vista sin saberlo**, y es el caso de libro de §23: buscar
## las cumbres ([Cumbres._find_peaks]) es perezoso y la primera vez APUNTA EN LA
## CRÓNICA —«hay un alto que nadie sabe cómo subir»—. Quien la llamaba primero era
## el alfiler de cima al montar la escena. Sin escena no la llamaba nadie en diez
## jornadas, y la partida sin mirar tenía una entrada de crónica menos: lo cazó la
## firma de `CampamentosProbe` contra la de `TironAnualProbe` (SPECS §4.7: la
## vista no decide nada). Se busca aquí, en el mismo momento en que lo hacía la
## escena: nada más empezar la partida.
func mirar_las_cumbres() -> void:
	if sim != null:
		sim.cumbres.peaks()


## Revisa qué cuevas ha encontrado ya la banda.
##
## Una cueva sin descubrir no se dibuja: no es que esté oculta, es que para el
## jugador todavía no existe. Es lo que da sentido a explorar. Y **es partida**:
## escribe en la crónica, así que un mapa que no se mira tiene que seguir
## descubriendo.
func revisar_hallazgos() -> void:
	if knowledge == null:
		return
	for cave: CaveMouth in caves:
		if cave.discovered:
			continue
		if knowledge.is_discovered(cave.pick_position()):
			cave.discover()
			var name_text := String(cave.feature.get("name", "una cavidad"))
			print("Descubierta: %s" % name_text)
			if sim and sim.chronicle:
				var away := int(cave.pick_position().distance_to(sim.home_position))
				sim.chronicle.record(sim.day, sim.estacion as int,
					sim.anyo, Chronicle.Kind.HALLAZGO,
					"La banda dio con %s, a %d m del abrigo." % [name_text, away],
					2)


## Lo que las expediciones recorrieron de este valle, en su mapa: explorado, y sus
## cuevas con alfiler. Es lo que enseña una VISITA, que no tiene gente que
## explore (SISTEMAS §4, punto 5). Sólo cuevas y no parajes —decisión del usuario
## del 2026-09-14—: una expedición no bautiza parajes en valles ajenos.
##
## Devuelve cuántas celdas del conocimiento quedaron vistas.
func ver_lo_recorrido(niebla: NieblaRegional) -> int:
	if niebla == null or knowledge == null or terrain == null:
		return 0
	var vistas := 0
	var cell_w := knowledge.world_size.x / float(maxi(knowledge.width, 1))
	var cell_h := knowledge.world_size.y / float(maxi(knowledge.height, 1))
	for z in range(knowledge.height):
		for x in range(knowledge.width):
			var centro := Vector3((float(x) + 0.5) * cell_w, 0.0, (float(z) + 0.5) * cell_h)
			var geo := terrain.world_to_geo(centro)
			if geo == Vector2.INF or not niebla.levantada(geo.x, geo.y, NieblaRegional.RECORRIDA):
				continue
			knowledge.explored[z * knowledge.width + x] = 1.0
			vistas += 1
	for cave: CaveMouth in caves:
		var donde := terrain.world_to_geo(cave.pick_position())
		if not cave.discovered and donde != Vector2.INF 				and niebla.levantada(donde.x, donde.y, NieblaRegional.RECORRIDA):
			cave.discover()
	return vistas


## La banda se ha asentado en otra cueva: los tajos se buscan otra vez alrededor
## de la casa nueva.
func _on_campamento_trasladado(_cueva: int) -> void:
	elegir_tajos(sim.home_position)


# --- los tajos --------------------------------------------------------------

## Donde se va a trabajar: de los sitios que ofrece el valle, los que de
## verdad se alcanzan.
func elegir_tajos(home: Vector3) -> void:
	var descartados := 0
	for entry: Dictionary in _find_work_sites(home):
		# Se pesca y se coge agua DESDE la orilla. El punto que sale de la
		# mascara cae en mitad del cauce, asi que primero se arrima a la ribera
		# y luego se comprueba si se llega.
		var spot := _best_work_spot(entry["activity"] as Subsistence.Activity,
			orilla_mas_cercana(entry["position"]))
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


## La orilla pisable más cercana a un punto, a la que además se llegue.
func orilla_mas_cercana(point: Vector3) -> Vector3:
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
					or candidate.x > float(terrain.terrain_size.x) \
					or candidate.z > float(terrain.terrain_size.y):
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
	var best_river := Vector3.ZERO
	var best_river_score := -1.0
	var best_coast := Vector3.ZERO
	var best_coast_dist := INF
	var best_hunt := Vector3.ZERO
	var best_hunt_score := -1.0
	var best_gather := Vector3.ZERO
	var best_gather_score := -1.0

	var step := 64
	for z in range(step, terrain.terrain_size.y - step, step):
		for x in range(step, terrain.terrain_size.x - step, step):
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

			# LA ORILLA, no el mar adentro: ver [TerrainGenerator.en_la_orilla_del_mar].
			if terrain.en_la_orilla_del_mar(point) and distance < best_coast_dist \
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
			"position": orilla_mas_cercana(orilla_mas_cercana(best_river) + Vector3(35, 0, 35)),
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
		var spot := orilla_mas_cercana(candidate)
		spot.y = terrain.get_height_at(spot)
		if sim.marcha.can_reach(spot):
			return spot
	return Vector3.ZERO
