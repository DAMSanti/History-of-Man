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

## Techo de instancias por material. Es el límite de coste.
const MAX_PER_KIND := 2600

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
const CLUSTER_SIZE := 9
const CLUSTER_RADIUS := 6.0

## Cuántos sitios se prueban antes de rendirse al buscar dónde plantar una
## mancha. Sin tope, una materia de hábitat estrecho recorrería la celda entera
## en cada intento.
const HABITAT_TRIES := 6

var _field: ResourceField
var _terrain: TerrainGenerator
var _rng := RandomNumberGenerator.new()
var _layers: Dictionary = {}

## Dónde está cada instancia y de qué es, para poder pincharla. Se guarda a
## parte del MultiMesh porque un MultiMesh no se puede consultar por posición.
var _picks: Array[Dictionary] = []

## Los modelos de fotogrametria, o null si no se han generado todavia.
var _library: PropLibrary


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
			# Helecho y zarza: humedad y media sombra, y no aguantan pendiente
			# fuerte porque necesitan suelo.
			"habitat": {"slope": Vector2(0.0, 0.30), "humidity": Vector2(0.45, 1.0)},
			"per_cell": 5, "sway": 0.4,
		},
		{
			# Rama caída: tumbada y alargada, nada que ver con una mata
			"kind": Materia.Kind.LENA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "rama",
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
			"mesh": _antler_mesh(),
			"color": Color(0.78, 0.73, 0.62),
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
		{
			# Pasto de claro: donde entra el ciervo
			"kind": Materia.Kind.CARNE,
			"from": Subsistence.Activity.CAZA,
			"model": "pasto",
			# El claro de pasto -donde entra el ciervo- es llano, abierto y con
			# algo de humedad. Es la razón de que el ciervo esté ahí.
			"habitat": {"slope": Vector2(0.0, 0.18), "humidity": Vector2(0.30, 0.90)},
			"per_cell": 4, "sway": 0.3,
		},
		{
			"kind": Materia.Kind.MARISCO,
			"from": Subsistence.Activity.MARISQUEO,
			"mesh": _shell_mesh(),
			"color": Color(0.60, 0.57, 0.52),
			"per_cell": 9, "sway": 0.0,
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
	_rng.seed = 20260903
	_load_library()

	for entry: Dictionary in _catalogue():
		_build_layer(entry)


func _build_layer(entry: Dictionary) -> void:
	if _field == null or _terrain == null:
		return

	var activity := entry["from"] as Subsistence.Activity
	var kind := entry["kind"] as Materia.Kind
	var per_cell := int(entry["per_cell"])
	var sway := float(entry["sway"])

	# La malla y su factor de talla. Los modelos vienen a la escala del escaneo
	# -un canto de rock_07 mide catorce centimetros-, asi que el factor lo
	# calcula la ingesta a partir de la altura que pide `PropModels` y entra en
	# la transformacion de la instancia, que sale gratis.
	var mesh: Mesh = entry.get("mesh")
	var model_scale := 1.0
	var mesh_height := 1.0
	if entry.has("model"):
		var key: String = entry["model"]
		if _library == null or not _library.has(key):
			return
		mesh = _library.mesh(key)
		model_scale = _library.scale_for(key)
	if mesh == null:
		return
	mesh_height = maxf(mesh.get_aabb().size.y, 0.01)

	# Fraccion de celdas donde asoma. Uno significa "en todas las que tengan
	# el recurso"; lo escaso lleva un numero pequeno.
	var rarity: float = float(entry.get("rarity", 1.0))

	var placements: Array[Transform3D] = []
	var cell_x := _field.world_size.x / float(_field.width)
	var cell_z := _field.world_size.y / float(_field.height)

	var habitat: Dictionary = entry.get("habitat", {})

	for z in range(_field.height):
		for x in range(_field.width):
			var abundance := _field.abundance_cell(activity, x, z)
			if abundance < MIN_ABUNDANCE:
				continue
			if rarity < 1.0 and _rng.randf() > rarity:
				continue

			# El número de instancias ES la abundancia: un paraje esquilmado se
			# ve vacío sin necesidad de ningún icono. Se nota al pasar.
			var count := int(round(float(per_cell) * abundance))
			if count <= 0:
				continue

			# Se siembra en MANCHAS y no repartido por la celda.
			#
			# Dos motivos, y el segundo es el que importa. El primero es que en
			# el monte nada sale repartido: las setas salen en corro, los cantos
			# se acumulan en la barra del río y el avellano hace mancha. Y el
			# segundo es de LECTURA: a doscientos metros un canto de treinta y
			# cuatro centímetros no se ve, pero doscientos cantos juntos sí. Es
			# lo que permite tener la talla real y que el paraje se siga
			# reconociendo de lejos.
			var clusters := maxi(1, int(ceil(float(count) / float(CLUSTER_SIZE))))
			for cluster in range(clusters):
				if placements.size() >= MAX_PER_KIND:
					break
				var seed_spot := _find_spot(x, z, cell_x, cell_z, habitat)
				if seed_spot == Vector3.INF:
					continue

				var here := mini(CLUSTER_SIZE, count - cluster * CLUSTER_SIZE)
				for i in range(here):
					if placements.size() >= MAX_PER_KIND:
						break
					var angle := _rng.randf() * TAU
					# Raíz de un aleatorio para que la mancha salga con densidad
					# pareja: sin ella se amontona todo en el centro.
					var reach := sqrt(_rng.randf()) * CLUSTER_RADIUS
					var spot := seed_spot + Vector3(
						cos(angle) * reach, 0.0, sin(angle) * reach)

					if _terrain.crossing_difficulty_at(spot) > 0.05:
						continue
					if _terrain.get_slope_at(spot) > 0.9:
						continue

					spot.y = _terrain.get_height_at(spot)
					var jitter := _rng.randf_range(0.75, 1.35)
					var scale := jitter * model_scale
					var basis := Basis().rotated(Vector3.UP, _rng.randf() * TAU)
					# Lo vegetal se inclina un poco; la piedra y el hueso no
					if sway > 0.0:
						basis = basis.rotated(Vector3.RIGHT,
							_rng.randf_range(-sway, sway) * 0.25)
					basis = basis.scaled(
						Vector3(scale, _rng.randf_range(0.8, 1.25) * scale, scale))
					placements.append(Transform3D(basis, spot))
					_picks.append({
						"pos": spot, "kind": kind, "from": activity,
						# El radio de acierto es el TAMAÑO REAL de la pieza en
						# metros, sacado de su caja por la talla que se le
						# acaba de poner.
						#
						# Antes salía de `scale` a secas, y `scale` lleva dentro
						# el factor del modelo, que NO es una talla: es cuánto
						# hay que multiplicar la malla de origen. La mata tiene
						# factor 12,2, así que su esfera de acierto medía hasta
						# VEINTISÉIS METROS y se tragaba lo que hubiera cerca:
						# pinchar una rama seleccionaba fruto seco.
						"radius": maxf(mesh_height * scale * 0.9, 0.8),
					})

	if placements.is_empty():
		return

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = placements.size()
	for i in range(placements.size()):
		multi.set_instance_transform(i, placements[i])

	var node := MultiMeshInstance3D.new()
	node.name = "Recurso_" + Materia.material_name(kind)
	node.multimesh = multi

	# Solo se pinta lo que NO trae modelo. Un modelo de fotogrametria ya viene
	# con su material y sus texturas, y un `material_override` las taparia: la
	# roca saldria de un gris plano habiendo bajado su albedo, su normal y su
	# ORM. Ver `PropModels` para cuales tienen modelo y cuales siguen siendo
	# silueta -la cuerna y la concha, que no existen en CC0-.
	if entry.has("color"):
		var material := StandardMaterial3D.new()
		material.albedo_color = entry["color"]
		material.roughness = 0.95
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		node.material_override = material
	# Se ven de lejos pero no desde el otro extremo del valle: a 900 m una mata
	# de dos metros es subpíxel y solo aporta aliasing
	node.visibility_range_end = 900.0
	node.visibility_range_end_margin = 120.0
	add_child(node)

	_layers[kind] = node
	# La talla va en el informe a proposito: es el numero con el que se pilla que
	# algo esta sembrado a escala equivocada, y es lo que fallo con el radio de
	# acierto de la mata.
	print("ResourceProps: %d de %s · %.2f m" % [placements.size(),
		Materia.material_name(kind), mesh_height * model_scale])


# --- las siluetas ---------------------------------------------------------
# Cada una distinta a propósito. La forma es lo que se lee a distancia, mucho
# antes que el color.

## Qué recurso hay bajo un rayo. Devuelve {} si no hay ninguno.
##
## Rayo contra esferas, como las cuevas y la gente: para unos miles de matas no
## hace falta un motor de colisiones, y montarlo obligaría a mantener capas y
## máscaras.
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

	for entry: Dictionary in _picks:
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





## Cuerna de desmogue: un asta con su candil, aproximada con un prisma
## alargado e inclinado. Poca cosa, pero desde arriba se lee como algo
## puntiagudo y claro sobre el suelo, y eso basta para que se distinga.
func _antler_mesh() -> Mesh:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.18, 0.85, 0.5)
	return mesh



## Costra de lapa en roca intermareal.
func _shell_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.06
	mesh.height = 0.05
	mesh.radial_segments = 5
	return mesh
