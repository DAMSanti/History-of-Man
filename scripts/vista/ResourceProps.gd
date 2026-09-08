class_name ResourceProps
extends Node3D
## Los recursos, visibles en el terreno y con la forma de lo que son.
##
## La primera versión los agrupaba por ACTIVIDAD, así que todo lo que se
## recoge salía igual: una mata de avellano, un haz de leña y una cuerna de
## desmogue eran el mismo bulto verde. Ahora cada material tiene su silueta y
## su color, porque distinguirlos de un vistazo es la mitad de saber dónde
## estás.
##
## Todo va en MultiMesh —un dibujado por material— porque un valle de cuatro
## kilómetros tiene miles de matas, y con nodos sueltos se comía los frames.
## Y todo lleva su TALLA REAL: el primer intento puso árboles de un metro sobre
## un mapa donde una unidad es un metro, y desde la cámara solo se leían como
## manchas oscuras.

## Por debajo de esta abundancia no se dibuja: sembrar una mata suelta en cada
## celda llena el mapa de ruido y esconde dónde está lo bueno.
const MIN_ABUNDANCE := 0.22

## Cuántas piezas van juntas en una mancha, y en cuántos metros a la redonda.
##
## Se siembra en manchas y no repartido por dos motivos. En el monte nada sale
## repartido: las setas salen en corro, los cantos se acumulan en la barra del
## río y el avellano hace mancha. Y sobre todo por LECTURA: a doscientos metros
## un canto de treinta y cuatro centímetros no se ve, pero doscientos cantos
## juntos sí. Es lo que permite tener la talla real —la de verdad, la que casa
## con una persona de 1,70 m— y que el paraje se siga reconociendo de lejos.
## Cuántas piezas van juntas en una mancha.
const CLUSTER_SIZE := 9

## Cómo de apretada va la mancha, en metros de radio por metro de talla.
##
## Escala con el TAMAÑO de la pieza y no es un número fijo, porque una barra de
## cantos es un manto apretado y un avellanar está espaciado. Con un radio fijo
## de seis metros, nueve cantos de treinta y cuatro centímetros quedaban a un
## par de metros unos de otros: eso no es una barra de río, es grava perdida.
const CLUSTER_SPREAD := 5.0
const CLUSTER_RADIUS_MIN := 1.4
const CLUSTER_RADIUS_MAX := 11.0

## Cuántos sitios se prueban antes de rendirse al buscar dónde plantar una
## mancha. Sin tope, una materia de hábitat estrecho recorrería la celda entera
## en cada intento.
const HABITAT_TRIES := 6

## Lado del bloque que se puebla y se tira de una pieza, en metros.
##
## Ciento veintiocho y no quinientos doce, que era el tamaño de las zonas de
## antes. Más pequeño compra tres cosas: el recorte de visibilidad -que se mide
## desde el nodo- pasa a significar algo, el motor puede descartar bloques
## enteros por frustum, y los niveles de detalle se eligen sobre una caja de
## ciento veintiocho metros en vez de una de quinientos doce, que llenaba la
## pantalla siempre y por tanto pedía siempre el nivel más fino.
const BLOCK_M := 128.0

## Hasta dónde se siembran props alrededor de la cámara, en metros.
@export var view_distance := 300.0:
	set(value):
		view_distance = clampf(value, 100.0, 900.0)
		_centre = Vector2i(999999, 999999)

## Cuántos props por celda respecto a lo que dice el catálogo.
##
## Es la palanca de densidad, y ahora SÍ puede subir: sembrando sólo alrededor
## de la cámara caben cuarenta veces más props por metro cuadrado que sembrando
## el valle entero con el mismo número de instancias.
@export var density := 3.0:
	set(value):
		density = clampf(value, 0.2, 20.0)
		_centre = Vector2i(999999, 999999)

var _field: ResourceField
var _terrain: TerrainGenerator
var _rng := RandomNumberGenerator.new()

## Dónde está cada instancia y de qué es, para poder pincharla. Se guarda a
## parte del MultiMesh porque un MultiMesh no se puede consultar por posición.
## Bloque -> lo que se puede pinchar en el. Se guarda por bloque para que se
## vaya con el: no tiene sentido poder pinchar algo que ya no esta dibujado.
var _picks: Dictionary = {}

## Las capas resueltas -malla, talla, densidad-, sin colocar.
var _specs: Array[Dictionary] = []

## Bloque -> silueta -> dónde ha caído cada instancia, en coordenadas del mundo.
##
## Es lo que le da de comer al censo de depuración -[EntityCensus]-, y va
## aparte de `_picks` por dos motivos: los picks NO llevan el paisaje -una peña
## no se pincha a propósito- y van por materia, no por silueta, así que con
## ellos no se puede contestar «cuántos troncos secos hay».
##
## Se apunta al SEMBRAR y no se lee del `MultiMesh` ya montado, que era lo
## primero que se probó. Leerlo con `get_instance_transform` devuelve la
## identidad en cuanto no hay servidor de render de verdad —en `--headless`,
## por ejemplo—, así que todas las fichas del censo salían en el centro de su
## bloque y a cien metros del suelo. Lo cazó `CensoProbe`.
##
## Se va con el bloque, como los picks: no tiene sentido poder ir a ver algo
## que ya no está dibujado.
var _plots: Dictionary = {}

## Bloque -> los nodos que lo dibujan, y en que bloque esta la camara.
var _live: Dictionary = {}
var _pending: Array[Vector2i] = []
var _centre := Vector2i(999999, 999999)

## Los modelos de fotogrametria, o null si no se han generado todavia.
var _library: PropLibrary

## Silueta -> qué materia es y si es paisaje. Se resuelve una vez en `setup`
## porque dentro del bucle de bloques no queda nada de esto a mano, y el censo
## necesita poder decir que `roseta` es raíz y que `pena3` no se recoge.
var _model_info: Dictionary = {}

## Cupo de instancias de cada materia: el techo global partido entre todas.


## Qué se ve en el suelo, de qué actividad sale, y con qué pinta.
##
## `per_cell` es cuántas instancias siembra una celda a plena abundancia. Los
## números están pensados para que lo abundante se lea como mancha y lo escaso
## como hallazgo: hay muchos cantos en una barra de río y muy pocas cuernas.
func _catalogue() -> Array[Dictionary]:
	return [
		{
			"kind": Materia.Kind.FRUTO_SECO,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "mata",
			"share": 0.35,
			# El avellano hace mancha en ladera suave y suelo hondo, no en el
			# roquedo ni en la vega encharcada.
			"habitat": {"slope": Vector2(0.02, 0.35), "humidity": Vector2(0.35, 0.95)},
			"per_cell": 4, "sway": 0.35,
		},
		{
			# Zarza y matorral bajo de fruto: más claro y más aplastado que el
			# avellano, para que se distingan a distancia
			"kind": Materia.Kind.FIBRA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "helecho",
			"share": 0.70,
			# Helecho y zarza: humedad y media sombra, y no aguantan pendiente
			# fuerte porque necesitan suelo.
			"habitat": {"slope": Vector2(0.0, 0.30), "humidity": Vector2(0.45, 1.0)},
			"per_cell": 5, "sway": 0.4,
		},
		{
			# Rama caída: tumbada y alargada, nada que ver con una mata
			"kind": Materia.Kind.LENA,
			"from": Subsistence.Activity.RECOLECCION,
			# Rama suelta Y tronco caído. El tronco es lo que de verdad se
			# recoge para una hoguera que dure la noche, y le da a la leña una
			# silueta grande que un haz de ramitas no tiene.
			"models": ["rama", "seco", "seco2"],
			# La rama cae DEBAJO del arbolado, así que sigue a la humedad; y
			# rueda ladera abajo, así que no se queda en lo empinado.
			"habitat": {"slope": Vector2(0.0, 0.22), "humidity": Vector2(0.40, 1.0)},
			"per_cell": 3, "sway": 0.0,
		},
		{
			# Cuerna de desmogue: pálida, ramificada y ESCASA. Es un hallazgo,
			# no un paisaje: una por celda buena y en invierno.
			"kind": Materia.Kind.ASTA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "asta",
			"per_cell": 1, "sway": 0.0, "rarity": 0.25,
		},
		{
			"kind": Materia.Kind.PIEDRA,
			"from": Subsistence.Activity.MATERIA_PRIMA,
			"model": "canto",
			# El canto rodado se acumula donde el agua lo ha dejado: fondo de
			# valle y barra de río. En alto no hay cantos, hay roca madre.
			"habitat": {"height": Vector2(0.0, 0.30), "slope": Vector2(0.0, 0.20)},
			"per_cell": 8, "sway": 0.0,
		},
		{
			# Ocre: nódulo rojo, muy escaso y muy visible
			"kind": Materia.Kind.OCRE,
			"from": Subsistence.Activity.MATERIA_PRIMA,
			"model": "nodulo",
			# El ocre aflora donde el suelo se ha ido: ladera con pendiente y
			# poca vegetación.
			"habitat": {"slope": Vector2(0.18, 0.70), "humidity": Vector2(0.0, 0.55)},
			# Una veta de ocre es un HALLAZGO, no un paisaje: sale en una de
			# cada treinta celdas con piedra. Sin esto salian 1.812 nodulos
			# repartidos por el valle, que es tanto como decir que no es raro.
			"per_cell": 1, "sway": 0.0, "rarity": 0.03,
		},
		# AQUÍ NO HAY CARNE, y no es un olvido.
		#
		# Había una capa de `pasto` etiquetada como `Materia.Kind.CARNE` para marcar
		# el claro por donde entra el ciervo. La idea era buena y la etiqueta mala:
		# lo que se sembraba era hierba, pero al pincharla decía «carne fresca», y
		# eso es prometer un filete tirado en el suelo. La carne sale de un animal,
		# que tiene su propio sistema -ver [WildlifeHerds]- y algún día su
		# comportamiento.
		#
		# Y de paso se quitaba de en medio: eran diecisiete siluetas a doce por
		# celda, la capa más densa de todo el catálogo, duplicando la hierba que ya
		# pone [GroundCover] sobre esos mismos claros.
		{
			# Endrino y zarzamora: borde de matorral, ni en el claro ni en lo
			# cerrado. Poca caloría y mucha vitamina, y por eso importa que se
			# vea dónde están.
			"kind": Materia.Kind.BAYA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "arbusto",
			"share": 0.35,
			"habitat": {"slope": Vector2(0.05, 0.40), "humidity": Vector2(0.30, 0.85)},
			"per_cell": 3, "sway": 0.3,
		},
		{
			# La raíz no se ve: lo que se ve es la hoja que la delata. Vega
			# llana y húmeda, que es donde el tubérculo engorda.
			"kind": Materia.Kind.RAIZ,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "roseta",
			"share": 0.30,
			"habitat": {"slope": Vector2(0.0, 0.20), "humidity": Vector2(0.40, 0.95)},
			"per_cell": 4, "sway": 0.25,
		},
		{
			# Tocón: de donde sale la corteza para recipientes y cordel. Va bajo
			# arbolado y es ocasional, no un paisaje.
			"kind": Materia.Kind.CORTEZA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "tocon",
			"habitat": {"slope": Vector2(0.0, 0.30), "humidity": Vector2(0.50, 1.0)},
			"per_cell": 1, "sway": 0.0, "rarity": 0.25,
		},
		{
			# La resina sale de la conífera, y el pino de refugio del
			# Magdaleniense está en ladera y en alto, no en la vega.
			"kind": Materia.Kind.RESINA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "conifera",
			"share": 0.60,
			"habitat": {"slope": Vector2(0.05, 0.45), "height": Vector2(0.25, 0.75)},
			"per_cell": 2, "sway": 0.15, "rarity": 0.4,
		},
		{
			# Yesca: lo que prende. Musgo de sombra húmeda, que seco es lo que
			# coge la chispa.
			"kind": Materia.Kind.YESCA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "yesca",
			"habitat": {"slope": Vector2(0.0, 0.35), "humidity": Vector2(0.55, 1.0)},
			"per_cell": 3, "sway": 0.0,
		},
		# --- Aquí NO hay paisaje -----------------------------------------------
		#
		# Ni hierba ni peñas. Este catálogo es de MATERIALES: cosas que la
		# banda recoge, que salen donde su actividad da rendimiento y que se
		# pueden pinchar. Lo que sólo viste el terreno es otra cosa y va en
		# `_scenery`, aparte, con su propio techo -si comparten catálogo,
		# comparten reparto, y el decorado le come el cupo a lo que importa-.
		#
		# La hierba se la lleva [GroundCover].
		# Estuvo aquí, con un cupo de 133.333 matas, y la cuenta no sale por
		# ningún lado. Repartidas por los 16,8 km² del mapa son UNA CADA
		# 126 m² -desde el suelo se ven dos o tres en toda la pantalla- y sin
		# embargo costaban 69 ms, porque un `MultiMesh` dibuja la zona entera
		# de 512 m aunque sólo se vean ochenta. Se pagaba hierba invisible y
		# faltaba justo donde se miraba.
		#
		# Subir el cupo tampoco: una alfombra de verdad sobre este mapa son
		# ocho millones de matas. Lo que se siembra de una vez sobre el mapa
		# entero tiene que ser ESCASO por definición; lo abundante hay que
		# generarlo alrededor de la cámara. Ver [GroundCover].
		{
			"kind": Materia.Kind.MARISCO,
			"from": Subsistence.Activity.MARISQUEO,
			# Dos conchas distintas: un conchero de una sola forma repetida se
			# lee como un patrón, no como marisco.
			"models": ["concha", "concha2"],
			# Porción corta, y es la única materia que la necesita: entre los dos
			# modelos suman quince siluetas, y como cada silueta se lleva el cupo
			# entero de su materia -ver el reparto en `setup`-, sin recortar aquí
			# el conchero se comía él solo más instancias que todo lo demás junto.
			"share": 0.35,
			"per_cell": 9, "sway": 0.0,
		},
	]


## Lo que sólo viste el terreno: no se recoge, no se pincha, no es materia.
##
## Va aparte del catálogo de materiales a propósito. Compartiendo lista
## compartían reparto, y con seis mil peñas de hasta dos metros y medio -visibles
## a novecientos metros- el valle entero era «solo piedras» mientras lo que la
## banda tiene que encontrar quedaba enterrado en la hierba. El decorado no puede
## competir por el mismo cupo que lo que se recolecta.
func _scenery() -> Array[Dictionary]:
	return [
		{
			# Peña suelta de ladera: la deuda de G2. Es lo único que da silueta y
			# sombra REALES en el tramo de uno a cinco metros, que el shader no
			# puede fingir por muy buena que sea la textura de roquedo.
			"scenery": true, "role": "hito",
			# Cuatro peñas distintas: un canchal con la misma piedra repetida se
			# lee como un patrón, igual que pasaba con el conchero.
			"models": ["pena", "pena2", "pena3", "bloque"],
			"habitat": {"slope": Vector2(0.28, 0.95)},
			# Freno propio: ver `_place`. Un doce por ciento, que es lo que
			# deja el canchal como fondo en vez de como protagonista.
			"density": 0.12,
			"per_cell": 3, "sway": 0.0, "rarity": 0.45,
		},
	]


## Carga la biblioteca de modelos. No va al repositorio -se reconstruye con
## `scripts/tools/PropIngest.gd`-, asi que en una copia recien clonada no esta y
## hay que decirlo, no fallar en silencio con el mapa lleno de nada.
func _load_library() -> void:
	if not ResourceLoader.exists(PropModels.LIBRARY_PATH):
		push_warning("Faltan los modelos de props. Generalos con:
"
			+ "  godot --headless --path . --script res://scripts/tools/PropIngest.gd")
		return
	_library = load(PropModels.LIBRARY_PATH) as PropLibrary
	if _library != null and not _library.is_usable():
		push_warning("La biblioteca de props no cubre el catalogo actual")
		_library = null


func setup(terrain: TerrainGenerator, field: ResourceField) -> void:
	_terrain = terrain
	_field = field
	_load_library()

	# Los materiales y el decorado. Van juntos a partir de aqui porque se
	# siembran igual; lo que no comparten es densidad ni papel.
	var catalogue := _catalogue()
	catalogue.append_array(_scenery())

	# Una capa por SILUETA. Un `MultiMesh` dibuja una sola malla, asi que la
	# variedad se consigue con varias capas: un fichero de Poly Haven empaqueta
	# tres ramas distintas o seis matas, y cada una va por su lado.
	#
	# Aqui solo se resuelve la ficha -malla, talla, altura real-. No se coloca
	# nada: eso lo hace `_build_block` cuando la camara se acerca.
	_specs.clear()
	for entry: Dictionary in catalogue:
		var models: Array = entry.get("models", [entry.get("model", "")])
		for model: String in models:
			var count := 1
			if _library != null and not model.is_empty():
				count = maxi(1, _library.variants(model))
			for variant in range(count):
				var spec := entry.duplicate()
				spec.erase("models")
				spec["model"] = model
				spec["variant"] = variant
				# La densidad se reparte entre los MODELOS distintos -una concha
				# y otra concha son dos cosas- pero NO entre las siluetas de un
				# mismo modelo, que son la misma planta vista de otra forma.
				spec["share"] = float(entry.get("share", 1.0)) \
					/ float(maxi(models.size(), 1))
				if _resolve(spec):
					_specs.append(spec)

	# Qué es cada silueta, para el censo. Aquí y no en el bucle de bloques
	# porque aquí es donde están las capas ya resueltas.
	_model_info.clear()
	for spec: Dictionary in _specs:
		var model := String(spec.get("model", "?"))
		if _model_info.has(model):
			continue
		var scenery := bool(spec.get("scenery", false))
		_model_info[model] = {
			"paisaje": scenery,
			"kind": -1 if scenery else int(spec["kind"]),
			"materia": "Paisaje" if scenery
				else Materia.material_name(spec["kind"] as Materia.Kind),
		}

	print("ResourceProps: %d siluetas, radio %d m, bloques de %d m" % [
		_specs.size(), int(view_distance), int(BLOCK_M)])
	var tally: Dictionary = {}
	for spec: Dictionary in _specs:
		var name := String(spec.get("model", "?"))
		var per := float(spec["per_cell"]) * float(spec.get("share", 1.0)) 			* density * float(spec.get("density", 1.0))
		if not tally.has(name):
			tally[name] = [0, per]
		tally[name][0] = int(tally[name][0]) + 1
	for name: String in tally:
		print("  %-10s %2d siluetas x %.2f por celda = %.2f" % [
			name, tally[name][0], tally[name][1],
			tally[name][0] * float(tally[name][1])])


## Resuelve la malla y la talla de una capa. Devuelve false si no hay modelo.
func _resolve(spec: Dictionary) -> bool:
	var key: String = spec.get("model", "")
	if key.is_empty() or _library == null or not _library.has(key):
		return false
	var mesh := _library.mesh(key, int(spec.get("variant", 0)))
	if mesh == null:
		return false
	var factor := _library.scale_for(key)
	spec["mesh"] = mesh
	spec["model_scale"] = factor
	# La talla real gobierna dos cosas: como de apretada va la mancha y hasta
	# donde se ve.
	spec["real_height"] = maxf(mesh.get_aabb().size.y, 0.01) * factor
	return true


## Todo el trabajo por fotograma: mirar en que bloque estamos y poner al dia los
## que hay alrededor.
##
## Los props se siembran ALREDEDOR DE LA CAMARA y no sobre el mapa entero, y es
## el mismo cambio que salvo la hierba. Sembrando el valle de una vez, el techo
## de instancias se reparte entre 16,8 km2: con dieciocho mil props salen mil por
## materia sobre cuatro kilometros cuadrados, o sea una planta cada sesenta
## metros, que no es un paraje de fibra sino una planta perdida. Y encima el
## reparto se comia el fotograma -113 ms medidos con cuarenta mil-.
##
## Alrededor de la camara viven unos veinticinco bloques: cuatro decimas de
## kilometro cuadrado en vez de dieciseis y medio. La misma cuenta de instancias
## da cuarenta veces mas densidad DONDE SE MIRA, que es donde importa.
##
## El campo de abundancia es la verdad y esto solo lo representa: por eso cada
## bloque se puede tirar y reconstruir sin perder nada, y por eso su azar sale de
## SUS COORDENADAS -un sitio siempre da los mismos props, se vuelva cuando se
## vuelva-.
func _process(_delta: float) -> void:
	if _specs.is_empty() or _field == null or _terrain == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var eye := camera.global_position
	var centre := Vector2i(int(floor(eye.x / BLOCK_M)),
		int(floor(eye.z / BLOCK_M)))
	if centre != _centre:
		_centre = centre
		_replan()

	# Un bloque por fotograma como mucho. Poblar uno son unos miles de consultas
	# al terreno, y hacerlos todos de golpe al cruzar una frontera da un tiron.
	if not _pending.is_empty():
		_build_block(_pending.pop_front())


## Decide que bloques deben existir y tira los que sobran.
func _replan() -> void:
	var reach := int(ceil(view_distance / BLOCK_M))
	var keep: Dictionary = {}
	var order: Array[Vector2i] = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			# Recortado al circulo: la esquina de un cuadrado de bloques esta un
			# cuarenta por ciento mas lejos que su lado, y alli no hace falta nada.
			if Vector2(dx, dz).length() > float(reach) + 0.5:
				continue
			var block := _centre + Vector2i(dx, dz)
			keep[block] = true
			if not _live.has(block):
				order.append(block)

	var here := _centre
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - here).length_squared() < (b - here).length_squared())
	_pending = order

	for block: Vector2i in _live.keys():
		if keep.has(block):
			continue
		for node: MultiMeshInstance3D in _live[block]:
			node.queue_free()
		_live.erase(block)
		_picks.erase(block)
		_plots.erase(block)


## Puebla un bloque: todas las capas, sobre las celdas de campo que lo componen.
func _build_block(block: Vector2i) -> void:
	if _live.has(block):
		return
	_live[block] = ([] as Array[MultiMeshInstance3D])
	_picks[block] = ([] as Array[Dictionary])
	_plots[block] = {}

	var cell_x := _field.world_size.x / float(_field.width)
	var cell_z := _field.world_size.y / float(_field.height)
	# Que celdas del campo caen en este bloque.
	var from_x := int(floor(float(block.x) * BLOCK_M / cell_x))
	var from_z := int(floor(float(block.y) * BLOCK_M / cell_z))
	var span_x := maxi(int(ceil(BLOCK_M / cell_x)), 1)
	var span_z := maxi(int(ceil(BLOCK_M / cell_z)), 1)
	var centre := Vector3((float(block.x) + 0.5) * BLOCK_M, 0.0,
		(float(block.y) + 0.5) * BLOCK_M)

	for index in range(_specs.size()):
		var spec: Dictionary = _specs[index]
		# El azar sale del BLOQUE y de la capa, nunca de un contador global: asi
		# un sitio da siempre los mismos props por mucho que se entre y se salga.
		_rng.seed = hash(Vector3i(block.x, block.y, index))
		var placements := _place(spec, from_x, from_z, span_x, span_z,
			cell_x, cell_z, block)
		if placements.is_empty():
			continue

		# Dónde ha caído cada una, apuntado al sembrarla. Ver `_plots`.
		var model := String(spec.get("model", "?"))
		var plots: Dictionary = _plots[block]
		var spots: PackedVector3Array = plots.get(model, PackedVector3Array())
		for placement: Transform3D in placements:
			spots.append(placement.origin)
		plots[model] = spots

		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = spec["mesh"]
		multi.instance_count = placements.size()
		for i in range(placements.size()):
			var placement: Transform3D = placements[i]
			multi.set_instance_transform(i,
				Transform3D(placement.basis, placement.origin - centre))

		var node := MultiMeshInstance3D.new()
		node.name = "%s_%s%d" % [
			"Paisaje" if bool(spec.get("scenery", false))
				else "Recurso_" + Materia.material_name(
					spec["kind"] as Materia.Kind),
			String(spec.get("model", "?")), int(spec.get("variant", 0))]
		node.multimesh = multi
		node.position = centre
		# La materia va en los METADATOS, no sólo en el nombre. Godot renombra
		# los nodos repetidos -cada bloque crea su `Recurso_Cuarcita_canto0`, y
		# del segundo en adelante pasan a `@Recurso_...@2`-, así que leer la
		# materia del nombre falla en cuanto hay más de un bloque. Se vio en
		# `PropSitioProbe`, que contaba once mil piedras donde no había ninguna.
		node.set_meta("materia", "paisaje" if bool(spec.get("scenery", false))
			else Materia.material_name(spec["kind"] as Materia.Kind))
		# Y el MODELO aparte de la materia, por lo mismo y por el mismo
		# renombrado. Cuatro peñas distintas son todas «paisaje», así que con
		# la materia sola no se puede mirar el árbol de nodos y saber cuál de
		# ellas es este montón.
		node.set_meta("modelo", model)
		# El recorte se mide desde el nodo, y el nodo esta en el centro de su
		# bloque: con bloques de ciento veintiocho metros eso si significa algo,
		# a diferencia de las zonas de quinientos doce de antes.
		var reach: float = clampf(float(spec["real_height"]) * 220.0,
			70.0, 900.0)
		node.visibility_range_end = reach + BLOCK_M * 0.71
		node.visibility_range_end_margin = reach * 0.18
		add_child(node)
		(_live[block] as Array[MultiMeshInstance3D]).append(node)


## Coloca una capa dentro de un bloque y devuelve sus transformaciones.
func _place(spec: Dictionary, from_x: int, from_z: int, span_x: int,
		span_z: int, cell_x: float, cell_z: float,
		block: Vector2i) -> Array[Transform3D]:
	var placements: Array[Transform3D] = []
	var scenery := bool(spec.get("scenery", false))
	var activity := Subsistence.Activity.RECOLECCION
	var kind := Materia.Kind.PIEDRA
	if not scenery:
		activity = spec["from"] as Subsistence.Activity
		kind = spec["kind"] as Materia.Kind

	# La densidad de la capa: lo que dice el catálogo, por su porción, por la
	# palanca global, y por su propio freno si lo lleva.
	#
	# El freno existe por las peñas. El paisaje NO pasa por el campo de
	# abundancia -vale uno en todas partes-, mientras que a los materiales la
	# palanca global les llega ya recortada por la abundancia de su celda, que
	# ronda un tercio. Así que el mismo número le pega tres veces más fuerte al
	# decorado, y de ahí que el valle saliera con once mil piedras contra ocho
	# matas de raíz. El freno lo iguala.
	var per_cell := float(spec["per_cell"]) * float(spec.get("share", 1.0)) \
		* density * float(spec.get("density", 1.0))
	var sway := float(spec["sway"])
	var rarity := float(spec.get("rarity", 1.0))
	var habitat: Dictionary = spec.get("habitat", {})
	var model_scale: float = spec["model_scale"]
	var real_height: float = spec["real_height"]
	var mesh_height: float = real_height / maxf(model_scale, 0.0001)
	var cluster_radius := clampf(real_height * CLUSTER_SPREAD,
		CLUSTER_RADIUS_MIN, CLUSTER_RADIUS_MAX)

	for dz in range(span_z):
		for dx in range(span_x):
			var x := from_x + dx
			var z := from_z + dz
			if x < 0 or z < 0 or x >= _field.width or z >= _field.height:
				continue

			# El paisaje esta en todas partes: lo que lo reparte es el habitat.
			var abundance := 1.0
			if not scenery:
				abundance = _field.abundance_cell(activity, x, z)
				if abundance < MIN_ABUNDANCE:
					continue
			if rarity < 1.0 and _rng.randf() > rarity:
				continue

			# El numero de instancias ES la abundancia: un paraje esquilmado se
			# ve vacio sin necesidad de ningun icono. Se nota al pasar.
			var raw := per_cell * abundance
			var count := int(raw)
			# El resto se sortea en vez de truncarse: con celdas que piden media
			# instancia, truncar las manda todas a cero y la materia desaparece.
			if _rng.randf() < fposmod(raw, 1.0):
				count += 1
			if count <= 0:
				continue

			var clusters := maxi(1,
				int(ceil(float(count) / float(CLUSTER_SIZE))))
			for cluster in range(clusters):
				var seed_spot := _find_spot(x, z, cell_x, cell_z, habitat)
				if seed_spot == Vector3.INF:
					continue
				var here := mini(CLUSTER_SIZE, count - cluster * CLUSTER_SIZE)
				for i in range(here):
					var angle := _rng.randf() * TAU
					# Raiz de un aleatorio para que la mancha salga con densidad
					# pareja: sin ella se amontona todo en el centro.
					var away := sqrt(_rng.randf()) * cluster_radius
					var spot := seed_spot + Vector3(
						cos(angle) * away, 0.0, sin(angle) * away)
					if _terrain.crossing_difficulty_at(spot) > 0.05:
						continue
					if _terrain.get_slope_at(spot) > 0.9:
						continue

					spot.y = _terrain.get_height_at(spot)
					var jitter := _rng.randf_range(0.75, 1.35)
					var scale := jitter * model_scale
					var basis := Basis().rotated(Vector3.UP,
						_rng.randf() * TAU)
					# Lo vegetal se inclina un poco; la piedra y el hueso no.
					if sway > 0.0:
						basis = basis.rotated(Vector3.RIGHT,
							_rng.randf_range(-sway, sway) * 0.25)
					basis = basis.scaled(Vector3(scale,
						_rng.randf_range(0.8, 1.25) * scale, scale))
					placements.append(Transform3D(basis, spot))
					if scenery:
						# El paisaje no se pincha: no es un recurso, y meterlo en
						# la lista haria que un clic sobre una pena dijese
						# "piedra" cuando no hay nada que recoger.
						continue
					(_picks[block] as Array[Dictionary]).append({
						"pos": spot, "kind": kind, "from": activity,
						# El radio de acierto es el TAMANO REAL de la pieza.
						# Antes salia de `scale`, que lleva dentro el factor del
						# modelo -12,2 para la mata- y daba esferas de VEINTISEIS
						# metros: pinchar una rama seleccionaba fruto seco.
						"radius": maxf(mesh_height * scale * 0.9, 0.8),
					})
	return placements


## Busca dónde plantar una mancha dentro de una celda, respetando el hábitat.
##
## Devuelve `Vector3.INF` si no encuentra sitio, que es una respuesta legítima:
## una celda de pradera no tiene por qué dar setas aunque tenga recolección.
## Ésa es justamente la gracia —que cada materia salga donde le toca y no todas
## en el mismo sitio— y es lo que el campo de abundancia por sí solo no puede
## decir, porque está indexado por ACTIVIDAD y no por materia: avellana, seta,
## baya y raíz comparten un único mapa.
func _find_spot(x: int, z: int, cell_x: float, cell_z: float,
		habitat: Dictionary) -> Vector3:
	var centre := _field.cell_center(x, z)
	for attempt in range(HABITAT_TRIES):
		var spot := centre + Vector3(
			_rng.randf_range(-0.5, 0.5) * cell_x, 0.0,
			_rng.randf_range(-0.5, 0.5) * cell_z)
		if _terrain.crossing_difficulty_at(spot) > 0.05:
			continue
		if _habitat_score(spot, habitat) > _rng.randf():
			return spot
	return Vector3.INF


## Cuánto le gusta a esta materia el sitio, de 0 a 1.
##
## Cada condición es una banda con bordes blandos: dentro vale uno, fuera cae a
## cero en el margen. Se multiplican, así que basta que falle una para descartar
## el sitio —una seta necesita sombra Y humedad, no una de las dos—.
##
## Un hábitat vacío da uno siempre, que es el comportamiento de antes.
func _habitat_score(spot: Vector3, habitat: Dictionary) -> float:
	if habitat.is_empty():
		return 1.0

	var score := 1.0
	if habitat.has("slope"):
		score *= _band(_terrain.get_slope_at(spot), habitat["slope"])
	if habitat.has("humidity"):
		score *= _band(_terrain.get_humidity_at(spot), habitat["humidity"])
	if habitat.has("height"):
		score *= _band(_terrain.get_normalized_height_at(spot), habitat["height"])
	if habitat.has("geology"):
		score *= _band(_terrain.get_geology_at(spot), habitat["geology"])
	return score


## Pertenencia a una banda [min, max] con un margen blando a cada lado.
func _band(value: float, range_v: Vector2) -> float:
	const EDGE := 0.12
	var low := smoothstep(range_v.x - EDGE, range_v.x + EDGE, value)
	var high := 1.0 - smoothstep(range_v.y - EDGE, range_v.y + EDGE, value)
	return low * high


func pick(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF

	# Los pinchables van por BLOQUE, así que hay dos bucles. No es un rodeo:
	# es lo que hace que la lista se vaya con el bloque cuando se descarga,
	# y no se pueda pinchar algo que ya no está dibujado.
	for block: Vector2i in _picks:
		for entry: Dictionary in _picks[block]:
			var centre: Vector3 = entry["pos"]
			var to_centre := centre - origin
			var along := to_centre.dot(direction)
			if along <= 0.0 or along > 600.0:
				continue
			# El radio de acierto crece con la distancia: a doscientos metros una
			# mata es de dos píxeles y sería imposible acertarle
			var radius: float = maxf(float(entry["radius"]), along * 0.008)
			if (origin + direction * along).distance_to(centre) > radius:
				continue
			if along < best_distance:
				best_distance = along
				best = entry

	return best








## Cuántas instancias de cada silueta hay pintadas ahora mismo.
##
## «Ahora mismo» y no «en el valle», y ésa es la diferencia con el bosque: los
## props se siembran sólo alrededor de la cámara -ver `_replan`-, así que un
## total del mapa entero no existe en ninguna parte. Lo que se puede contestar
## es cuántos hay puestos, y eso es justamente lo que interesa mirar cuando se
## sospecha que falta o sobra algo a la vista.
##
## Sale de `_plots`, que se apunta al sembrar. Ver ahí por qué no se lee del
## `MultiMesh` ya montado, que es lo que uno intentaría primero.
func census() -> Array[Dictionary]:
	var tally: Dictionary = {}
	for block: Vector2i in _plots:
		var plots: Dictionary = _plots[block]
		for model: String in plots:
			var spots: PackedVector3Array = plots[model]
			if not tally.has(model):
				var info: Dictionary = _model_info.get(model, {})
				tally[model] = {
					"model": model,
					"materia": String(info.get("materia", "?")),
					"paisaje": bool(info.get("paisaje", false)),
					"kind": int(info.get("kind", -1)),
					"count": 0,
				}
			tally[model]["count"] = int(tally[model]["count"]) + spots.size()

	var out: Array[Dictionary] = []
	out.assign(tally.values())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["count"]) > int(b["count"]))
	return out


## Dónde está cada instancia de una silueta, en coordenadas del mundo.
##
## Se devuelven TODAS y no las primeras que se encuentren, aunque quien
## pregunta sólo vaya a enseñar unas pocas: los bloques se recorren en el orden
## en que se montaron, que no es el de cerca a lejos, así que cortando aquí se
## entregaría un puñado arbitrario. Un millar de vectores no cuesta nada, y
## quien pregunte ya los ordenará por lo que le importe.
func positions_of(model: String) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for block: Vector2i in _plots:
		var plots: Dictionary = _plots[block]
		if not plots.has(model):
			continue
		for spot: Vector3 in (plots[model] as PackedVector3Array):
			out.append(spot)
	return out
