class_name NavOverlay
extends MultiMeshInstance3D
## Pinta sobre el terreno lo que el juego considera intransitable.
##
## Es una herramienta para mirar el juego por dentro, no una capa de la
## partida. Existe porque la rejilla de navegación decide media simulación
## —adónde se puede ir, qué parajes son alcanzables, por dónde se rodea— y
## hasta ahora era invisible: cuando alguien se quedaba atascado había que
## deducir la causa de un rótulo en vez de mirar el mapa y verla.
##
## Tres colores, tres cosas distintas:
##   · **rojo**: por ahí no se pasa —río, cortado, canchal vertical—
##   · **naranja**: se pasa, pero está incomunicado del campamento
##   · **nada**: se anda sin problema
##
## El naranja es el importante. Una mancha roja es terreno; una mancha naranja
## grande quiere decir que la banda tiene medio valle vedado sin saberlo.

## Cuánto se levanta la lámina sobre el suelo, en metros.
##
## Suficiente para no pelearse con el terreno en el buffer de profundidad y
## poco para que se lea como algo pegado al suelo y no flotando.
const LIFT := 2.5

## Qué fracción de la celda ocupa cada baldosa.
##
## No el 100%: dejando una junta se distingue una mancha continua de celdas
## sueltas, que es justo lo que hay que poder distinguir.
const FILL := 0.88

const BLOCKED_COLOUR := Color(0.85, 0.20, 0.16, 0.42)
const CUT_OFF_COLOUR := Color(0.95, 0.62, 0.15, 0.42)

## La celda que SOLO se pasa por el vado.
##
## Hacía falta un tercer color porque la capa decía media verdad. [Navgrid]
## abre una celda de cuarenta metros en cuanto encuentra una línea vadeable
## dentro —lo cual es correcto: por ahí se cruza— y la capa la dejaba sin
## pintar, o sea igual que un prado seco. Pinchando esa misma casilla, la ficha
## del terreno decía «no se puede pasar por aquí», porque la ficha mira EL
## PUNTO y la capa miraba LA CELDA. No se contradecían: contestaban a cosas
## distintas y ninguna lo decía.
##
## Ahora se ve: azul es «se cruza, pero mojándose y por donde el río deja».
const FORD_COLOUR := Color(0.25, 0.55, 0.90, 0.38)

## A partir de cuánta agua en el centro de la celda se considera que lo que hay
## es un vado y no suelo seco.
const MOJADO := 0.02


var _shown := false


func _ready() -> void:
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material


func showing() -> bool:
	return _shown


## Enciende o apaga la capa. Al encenderla se rehace, porque la rejilla cambia
## cuando la banda aprende a cruzar el agua.
func toggle(grid: Navgrid, home: Vector3, terrain: TerrainGenerator) -> bool:
	_shown = not _shown
	visible = _shown
	if _shown:
		_rebuild(grid, home, terrain)
	return _shown


func _rebuild(grid: Navgrid, home: Vector3, terrain: TerrainGenerator) -> void:
	if grid == null or not grid.is_ready():
		return

	var home_area := -1
	var home_cell := grid.nearest_open(home)
	if home_cell >= 0:
		home_area = grid.area[home_cell]

	# Primero se cuentan las baldosas que hacen falta: un MultiMesh se
	# dimensiona antes de llenarlo
	var wanted: Array[int] = []
	var vados: Dictionary = {}
	for cell in range(grid.cost.size()):
		if grid.cost[cell] <= Navgrid.BLOCKED:
			wanted.append(cell)
		elif home_area >= 0 and grid.area[cell] != home_area:
			wanted.append(cell)
		elif terrain != null and terrain.crossing_difficulty_at(
				grid.point_of(cell)) > MOJADO:
			# Abierta, comunicada... y con agua. Es un vado, y decirlo es la
			# mitad de contestar «¿por dónde ha cruzado ése el río?».
			vados[cell] = true
			wanted.append(cell)

	var tile := QuadMesh.new()
	tile.size = Vector2(Navgrid.CELL * FILL, Navgrid.CELL * FILL)
	# Tumbada: el QuadMesh nace de pie, mirando al eje Z
	tile.orientation = PlaneMesh.FACE_Y

	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = tile
	mesh.instance_count = wanted.size()

	var index := 0
	for cell: int in wanted:
		var point := grid.point_of(cell)
		if terrain:
			point.y = terrain.get_height_at(point)
		point.y += LIFT
		mesh.set_instance_transform(index, Transform3D(Basis(), point))
		var tinte := CUT_OFF_COLOUR
		if grid.cost[cell] <= Navgrid.BLOCKED:
			tinte = BLOCKED_COLOUR
		elif vados.has(cell):
			tinte = FORD_COLOUR
		mesh.set_instance_color(index, tinte)
		index += 1

	multimesh = mesh


## Lo que hay que contarle al jugador de un vistazo.
static func tally_text(grid: Navgrid, home: Vector3) -> String:
	if grid == null or not grid.is_ready():
		return "Sin rejilla de navegación."

	var home_area := -1
	var home_cell := grid.nearest_open(home)
	if home_cell >= 0:
		home_area = grid.area[home_cell]

	var blocked := 0
	var cut_off := 0
	for cell in range(grid.cost.size()):
		if grid.cost[cell] <= Navgrid.BLOCKED:
			blocked += 1
		elif home_area >= 0 and grid.area[cell] != home_area:
			cut_off += 1

	var total := maxi(grid.cost.size(), 1)
	return "Rojo: %.0f%% no se pisa. Naranja: %.0f%% se pisa pero no se llega desde el abrigo. %d zonas." % [
		100.0 * float(blocked) / float(total),
		100.0 * float(cut_off) / float(total), grid.areas]
