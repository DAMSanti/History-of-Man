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
			"per_cell": 4, "sway": 0.35,
		},
		{
			# Zarza y matorral bajo de fruto: más claro y más aplastado que el
			# avellano, para que se distingan a distancia
			"kind": Materia.Kind.FIBRA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "helecho",
			"per_cell": 5, "sway": 0.4,
		},
		{
			# Rama caída: tumbada y alargada, nada que ver con una mata
			"kind": Materia.Kind.LENA,
			"from": Subsistence.Activity.RECOLECCION,
			"model": "rama",
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
			"per_cell": 8, "sway": 0.0,
		},
		{
			# Ocre: nódulo rojo, muy escaso y muy visible
			"kind": Materia.Kind.OCRE,
			"from": Subsistence.Activity.MATERIA_PRIMA,
			"model": "nodulo",
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
	if entry.has("model"):
		var key: String = entry["model"]
		if _library == null or not _library.has(key):
			return
		mesh = _library.mesh(key)
		model_scale = _library.scale_for(key)
	if mesh == null:
		return

	# Fraccion de celdas donde asoma. Uno significa "en todas las que tengan
	# el recurso"; lo escaso lleva un numero pequeno.
	var rarity: float = float(entry.get("rarity", 1.0))

	var placements: Array[Transform3D] = []
	var cell_x := _field.world_size.x / float(_field.width)
	var cell_z := _field.world_size.y / float(_field.height)

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
			for i in range(count):
				if placements.size() >= MAX_PER_KIND:
					break
				var centre := _field.cell_center(x, z)
				var spot := centre + Vector3(
					_rng.randf_range(-0.5, 0.5) * cell_x, 0.0,
					_rng.randf_range(-0.5, 0.5) * cell_z)

				if _terrain.crossing_difficulty_at(spot) > 0.05:
					continue
				if _terrain.get_slope_at(spot) > 0.9:
					continue

				spot.y = _terrain.get_height_at(spot)
				var scale := _rng.randf_range(0.75, 1.35) * model_scale
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
					# El radio para pinchar va en METROS de mundo, asi que se
					# mide sobre la talla ya aplicada y no sobre el azar suelto.
					"radius": maxf(scale * 1.6, 1.2),
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
	print("ResourceProps: %d de %s" % [placements.size(), Materia.material_name(kind)])


# --- las siluetas ---------------------------------------------------------
# Cada una distinta a propósito. La forma es lo que se lee a distancia, mucho
# antes que el color.

## Qué recurso hay bajo un rayo. Devuelve {} si no hay ninguno.
##
## Rayo contra esferas, como las cuevas y la gente: para unos miles de matas no
## hace falta un motor de colisiones, y montarlo obligaría a mantener capas y
## máscaras.
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
