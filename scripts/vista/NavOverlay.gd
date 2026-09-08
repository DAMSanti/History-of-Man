class_name NavOverlay
extends MeshInstance3D
## Pinta sobre el terreno lo que el juego considera intransitable.
##
## Es una herramienta para mirar el juego por dentro, no una capa de la
## partida. Existe porque la rejilla de navegación decide media simulación
## —adónde se puede ir, qué parajes son alcanzables, por dónde se rodea— y
## hasta ahora era invisible: cuando alguien se quedaba atascado había que
## deducir la causa de un rótulo en vez de mirar el mapa y verla.
##
## Cuatro colores, cuatro cosas distintas:
##   · **rojo**: por ahí no se pasa —río hondo, cortado, canchal vertical—
##   · **azul**: agua que SÍ se vadea. Se cruza mojándose.
##   · **naranja**: se pasa, pero está incomunicado del campamento
##   · **nada**: se anda sin problema
##
## El naranja es el importante. Una mancha roja es terreno; una mancha naranja
## grande quiere decir que la banda tiene medio valle vedado sin saberlo.
##
## ## Se pinta EL SUELO, no baldosas flotando
##
## Fue un `MultiMesh` de cuadros planos levantados dos metros y medio, y sobre
## una ladera eso son láminas flotando en el aire: se metían dentro del monte
## por un canto y salían por el otro. Ahora es UNA malla con los vértices a la
## altura del terreno, o sea una capa de color pegada a la orografía.
##
## ## Y se muestrea A DIEZ METROS, no a cuarenta
##
## Ésta es la otra mitad, y la que hacía que faltaran tramos de río.
##
## [Navgrid] trabaja en celdas de cuarenta metros y las abre en cuanto hay una
## línea vadeable dentro. Pintando por celda pasaban dos cosas, las dos malas:
## un cauce más estrecho que la celda no salía pintado —su centro está seco— y
## una celda abierta por su vado se veía igual que un prado.
##
## Aquí se pregunta lo que de verdad decide cada paso: `Traversal.is_passable`
## en el PUNTO, que es exactamente lo que mira `Marcha._can_step_into` y lo que
## dice la ficha del terreno al pinchar. Por eso ya no se contradicen.

## Cuánto se levanta la lámina sobre el suelo, en metros.
##
## Medio metro basta y sobra desde que la malla sigue el relieve: lo único que
## tiene que hacer es no pelearse con el terreno en el buffer de profundidad.
## Con los dos y medio de cuando eran cuadros planos, la capa se despegaba.
const LIFT := 0.5

## En cuántos trozos se parte cada celda de la rejilla para muestrear.
##
## Cuatro, o sea diez metros de lado: es el orden de magnitud del ancho de un
## arroyo, y por debajo de eso la capa deja de decir nada nuevo mientras el
## coste se dispara al cuadrado.
const SUB := 4

const BLOCKED_COLOUR := Color(0.85, 0.20, 0.16, 0.45)
const CUT_OFF_COLOUR := Color(0.95, 0.62, 0.15, 0.42)
const FORD_COLOUR := Color(0.25, 0.55, 0.90, 0.42)

## A partir de cuánta agua se considera que lo que hay es vado y no suelo seco.
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
	# Sin escribir profundidad: son manchas translúcidas superpuestas y con el
	# buffer puesto se tapan entre ellas según el orden de dibujo.
	material.no_depth_test = false
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_override = material


func showing() -> bool:
	return _shown


## Enciende o apaga la capa. Devuelve si ha quedado visible.
func toggle(grid: Navgrid, home: Vector3, terrain: TerrainGenerator) -> bool:
	_shown = not _shown
	visible = _shown
	if _shown:
		_rebuild(grid, home, terrain)
	return _shown


## Rehace la lámina. Es lo caro y sólo pasa al encender.
func _rebuild(grid: Navgrid, home: Vector3, terrain: TerrainGenerator) -> void:
	mesh = null
	if grid == null or not grid.is_ready() or terrain == null:
		return

	var home_area := -1
	var home_cell := grid.nearest_open(home)
	if home_cell >= 0:
		home_area = grid.area[home_cell]

	var paso := Navgrid.CELL / float(SUB)
	var ancho := int(grid.world.x / paso)
	var alto := int(grid.world.y / paso)
	if ancho <= 0 or alto <= 0:
		return

	# Las alturas de la REJILLA DE VÉRTICES, una vez. Cada trozo comparte sus
	# esquinas con los de al lado, así que muestrear por trozo sería pedirle al
	# terreno cuatro veces la misma altura.
	var alturas := PackedFloat32Array()
	alturas.resize((ancho + 1) * (alto + 1))
	for z in range(alto + 1):
		for x in range(ancho + 1):
			alturas[z * (ancho + 1) + x] = terrain.get_height_at(
				Vector3(float(x) * paso, 0.0, float(z) * paso)) + LIFT

	var vertices := PackedVector3Array()
	var colores := PackedColorArray()
	for z in range(alto):
		for x in range(ancho):
			var centro := Vector3(
				(float(x) + 0.5) * paso, 0.0, (float(z) + 0.5) * paso)
			var tinte := _colour_at(grid, terrain, centro, home_area)
			if tinte.a <= 0.0:
				continue
			# Dos triángulos, con las cuatro esquinas a la altura del suelo.
			var x0 := float(x) * paso
			var x1 := float(x + 1) * paso
			var z0 := float(z) * paso
			var z1 := float(z + 1) * paso
			var a := Vector3(x0, alturas[z * (ancho + 1) + x], z0)
			var b := Vector3(x1, alturas[z * (ancho + 1) + x + 1], z0)
			var c := Vector3(x1, alturas[(z + 1) * (ancho + 1) + x + 1], z1)
			var d := Vector3(x0, alturas[(z + 1) * (ancho + 1) + x], z1)
			vertices.append_array([a, c, b, a, d, c])
			for i in range(6):
				colores.append(tinte)

	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colores
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = malla


## De qué color va este punto, o transparente si no hay nada que decir.
##
## El orden importa: primero lo que CIERRA el paso —y se pregunta en el punto,
## que es lo que decide cada paso de verdad— y sólo después lo de la celda.
func _colour_at(grid: Navgrid, terrain: TerrainGenerator, point: Vector3,
		home_area: int) -> Color:
	var ford := terrain.crossing_difficulty_at(point)
	var slope := terrain.get_slope_at(point)

	# EN EL PUNTO. Es lo mismo que mira `Marcha._can_step_into` y lo mismo que
	# dice la ficha al pinchar el terreno, y por eso ya no se contradicen. Con
	# la celda de cuarenta metros, un arroyo más estrecho que ella no salía
	# pintado porque el centro de su celda estaba seco.
	if not Traversal.is_passable(slope, ford, grid.built_with_boat,
			grid.built_with_bridge):
		return BLOCKED_COLOUR

	# Y lo que la REJILLA dice de la celda: aunque el punto se pise, si su
	# celda está cerrada por ahí no se planea camino.
	var cell := grid.cell_of(point)
	if cell < 0 or cell >= grid.cost.size():
		return Color(0, 0, 0, 0)
	if grid.cost[cell] <= Navgrid.BLOCKED:
		return BLOCKED_COLOUR
	if ford > MOJADO:
		return FORD_COLOUR
	if home_area >= 0 and grid.area[cell] != home_area:
		return CUT_OFF_COLOUR
	return Color(0, 0, 0, 0)


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
	return "%d celdas cerradas (%.0f %%) · %d abiertas pero incomunicadas (%.0f %%)" % [
		blocked, 100.0 * float(blocked) / float(total),
		cut_off, 100.0 * float(cut_off) / float(total)]
