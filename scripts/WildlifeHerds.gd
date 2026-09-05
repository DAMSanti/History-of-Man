class_name WildlifeHerds
extends Node3D
## Manadas que se mueven por el mapa, como marcador de dónde hay caza.
##
## Son placeholders —cápsulas— pero no están puestas al azar: pastan dentro de
## las manchas de caza del [ResourceField], se van de las zonas empinadas y no
## cruzan el agua que no vadearían. Es decir, dan la misma información que el
## campo de recursos, pero mirándolas en vez de consultando una tabla, que es
## como la vería un cazador.
##
## Se mueven porque un cotarro de caza no es un sitio fijo: la manada se
## desplaza dentro de su querencia, y encontrarla forma parte del trabajo.

## Animales por manada
const HERD_SIZE := 7

## Radio de querencia de una manada alrededor de su centro, en metros
const HOME_RANGE_M := 220.0

## Velocidad de paso, en metros por segundo de juego
const WANDER_SPEED := 7.0

## Cada cuánto se replantea el rumbo un animal, en segundos
const RETHINK_SECONDS := 3.5

var _terrain: TerrainGenerator
var _field: ResourceField
var _rng := RandomNumberGenerator.new()

## Un animal: {body, position, target, anchor, timer}
var _animals: Array[Dictionary] = []


func setup(terrain: TerrainGenerator, field: ResourceField, herds: int = 5) -> void:
	_terrain = terrain
	_field = field
	_rng.seed = 20260903

	for anchor in _pick_grounds(herds):
		for i in range(HERD_SIZE):
			_spawn(anchor)


## Elige las querencias: las celdas con más caza, separadas entre sí para que
## las manadas no se amontonen todas en el mismo prado.
func _pick_grounds(count: int) -> Array[Vector3]:
	var candidates: Array[Dictionary] = []
	for z in range(_field.height):
		for x in range(_field.width):
			var value := _field.abundance_cell(Subsistence.Activity.CAZA, x, z)
			if value > 0.35:
				candidates.append({"pos": _field.cell_center(x, z), "value": value})

	candidates.sort_custom(func(a, b): return a["value"] > b["value"])

	var chosen: Array[Vector3] = []
	for candidate: Dictionary in candidates:
		if chosen.size() >= count:
			break
		var spot: Vector3 = candidate["pos"]
		var far_enough := true
		for taken: Vector3 in chosen:
			if taken.distance_to(spot) < HOME_RANGE_M * 1.6:
				far_enough = false
		if far_enough:
			chosen.append(spot)
	return chosen


func _spawn(anchor: Vector3) -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	# Talla de ciervo: 1,7 m de largo y 0,45 de ancho. Importa que sea la
	# escala real, porque el error de la vegetacion fue justo ese.
	mesh.radius = 0.45
	mesh.height = 1.7
	body.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42, 0.30, 0.20)
	material.roughness = 0.95
	body.material_override = material

	# Tumbada: una capsula de pie parece una persona, no un animal
	body.rotation.z = PI * 0.5
	add_child(body)

	var offset := Vector3(
		_rng.randf_range(-HOME_RANGE_M, HOME_RANGE_M) * 0.4, 0.0,
		_rng.randf_range(-HOME_RANGE_M, HOME_RANGE_M) * 0.4)
	var start := _clamped(anchor + offset)
	start.y = _terrain.get_height_at(start)

	_animals.append({
		"body": body, "position": start, "target": start, "anchor": anchor,
		"timer": _rng.randf() * RETHINK_SECONDS,
	})


func _process(delta: float) -> void:
	if _terrain == null:
		return

	for animal: Dictionary in _animals:
		animal["timer"] = float(animal["timer"]) - delta
		if float(animal["timer"]) <= 0.0:
			animal["timer"] = RETHINK_SECONDS * _rng.randf_range(0.6, 1.6)
			animal["target"] = _new_target(animal["anchor"])

		var position: Vector3 = animal["position"]
		var target: Vector3 = animal["target"]
		var to_target := target - position
		to_target.y = 0.0

		if to_target.length() > 1.5:
			var step := to_target.normalized() * WANDER_SPEED * delta
			var next := position + step
			# El agua es tan barrera para el ciervo como para la banda
			if _terrain.crossing_difficulty_at(next) <= Hydrography.FORD_WADEABLE:
				position = next
			else:
				animal["timer"] = 0.0

		position.y = _terrain.get_height_at(position)
		animal["position"] = position

		var body: MeshInstance3D = animal["body"]
		body.position = position + Vector3(0.0, 0.7, 0.0)
		if to_target.length() > 0.1:
			body.rotation.y = atan2(to_target.x, to_target.z)


## Un destino nuevo dentro de la querencia, en terreno pisable y no empinado.
func _new_target(anchor: Vector3) -> Vector3:
	for attempt in range(8):
		var angle := _rng.randf() * TAU
		var radius := _rng.randf() * HOME_RANGE_M
		var candidate := _clamped(anchor + Vector3(cos(angle), 0.0, sin(angle)) * radius)
		candidate.y = _terrain.get_height_at(candidate)
		if _terrain.crossing_difficulty_at(candidate) > Hydrography.FORD_WADEABLE:
			continue
		# Un herbivoro pasta en el llano, no en el canchal
		if _terrain.get_slope_at(candidate) > 0.35:
			continue
		return candidate
	return anchor


func _clamped(point: Vector3) -> Vector3:
	if _terrain == null:
		return point
	return Vector3(
		clampf(point.x, 5.0, float(_terrain.terrain_size.x) - 5.0), point.y,
		clampf(point.z, 5.0, float(_terrain.terrain_size.y) - 5.0))


## Dónde está cada animal, para que el minimapa los pinte
func positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for animal: Dictionary in _animals:
		out.append(animal["position"])
	return out
