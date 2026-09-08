extends SceneTree
## Hornea el atlas de impostores: cada árbol fotografiado de frente, con alfa.
##
## Es lo que permite cumplir la condición de «verlos TODOS». Un bosque no es
## detalle de cerca como la hierba: es un rasgo del paisaje, y se ve desde
## cualquier altura de cámara. Pero un pino de ocho metros con su malla son
## miles de triángulos, y treinta mil árboles con malla no se sostienen ni con
## niveles de detalle.
##
## La salida clásica, y la que se usa aquí, es que a partir de cierta distancia
## el árbol deje de ser geometría y pase a ser UN CUADRADO con su foto pegada:
## dos triángulos. Treinta mil árboles son sesenta mil triángulos, que no es
## nada, y siguen estando todos.
##
## Se fotografía SIN sol y con ambiente blanco plano, igual que el atlas de
## hierba: lo que se guarda es el color propio del árbol. Con el sol dentro, un
## bosque entero llevaría pintada la sombra del mediodía a las seis de la tarde.

## Qué se fotografía. El orden ES el de las celdas del atlas, y `Forest` lo lee
## de aquí, así que no se reordena sin regenerar.
# Sólo los tres ÁRBOLES. `seco` y `seco2` estuvieron aquí y se fueron: al
# fotografiarlos salieron con proporción alto/ancho 0,10 y 0,26, o sea
# TUMBADOS. Son troncos caídos, no árboles muertos en pie, y un impostor de
# un tronco tumbado girando para mirar a la cámara es de las cosas que peor
# se ven. Su sitio es la leña, en `ResourceProps`.
const PICKS: Array[String] = ["pino", "pino_joven", "abedul", "roble",
	"avellano"]

const CELL := 512
## Lado del atlas en celdas. Sale de [Forest], que es quien tiene que estar de
## acuerdo con el shader: aquí sólo se obedece. Escrito en los dos sitios era
## una discrepancia esperando a ocurrir.
const GRID := Forest.ATLAS_GRID
const OUT_PNG := "res://models/props/arbol_atlas.png"
const OUT_RES := "res://models/props/arbol_atlas.res"

## Se fotografía a este múltiplo y se reduce después.
##
## Un árbol tiene ramas finas y hoja suelta, que a la resolución final salen con
## alfa bajo y el recorte del shader se las lleva por delante. Es el mismo
## problema que tuvo la hierba y la misma solución: supermuestrear.
const SUPER := 2

## Cuánto se sube el alfa después de reducir, por lo mismo.
const ALPHA_GAIN := 1.7

var _view: SubViewport
var _holder: Node3D
var _camera: Camera3D

## Proporción alto/ancho de cada celda, que `Forest` necesita para que el
## cuadrado del impostor no deforme el árbol.
var _shapes: Array[float] = []


func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("sin biblioteca de props"); quit(1); return

	_build_studio()
	await process_frame

	var atlas := Image.create(CELL * GRID, CELL * GRID, false, Image.FORMAT_RGBA8)
	for index in range(PICKS.size()):
		var key: String = PICKS[index]
		if not library.has(key):
			print("  %-12s AUSENTE en la biblioteca" % key)
			_shapes.append(1.0)
			continue

		# Dos fotos del mismo árbol: de perfil y DESDE ARRIBA.
		#
		# La de arriba es la que faltaba, y su falta se veía: el impostor es una
		# lámina vertical, así que con la cámara alta se ve de canto, y lo que
		# había para taparlo era inclinar la lámina hacia quien mira. Eso dibuja
		# un remolino —cada árbol se tumba hacia el centro de la pantalla, y el
		# resultado desde arriba es un abanico circular— y además hace que un
		# árbol aparezca o desaparezca según el ángulo. Con una foto cenital la
		# lámina se puede tumbar del todo y enseñar la copa, que es lo que se ve
		# de verdad de un pino desde un pájaro.
		for from_top: bool in [false, true]:
			var height := _place(library, key, from_top)
			for i in range(8):
				await process_frame
			var shot := _view.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)

			var trimmed := _crop(shot)
			if not from_top:
				_shapes.append(float(trimmed["aspect"]))
			var cut: Image = trimmed["image"]
			print("  %-12s %-6s %5.1f m real · %4.1f%% de la celda · alto/ancho %.2f" % [
				key, "cenital" if from_top else "perfil", height,
				_coverage(cut) * 100.0, trimmed["aspect"]])
			var cell_index := index + (PICKS.size() if from_top else 0)
			atlas.blit_rect(cut, Rect2i(Vector2i.ZERO, Vector2i(CELL, CELL)),
				Vector2i(cell_index % GRID, cell_index / GRID)
					* Vector2i(CELL, CELL))

	atlas.save_png(OUT_PNG)
	ResourceSaver.save(atlas, OUT_RES)
	print("atlas de arboles en %s (%dx%d)" % [
		ProjectSettings.globalize_path(OUT_PNG), atlas.get_width(),
		atlas.get_height()])
	print("proporciones alto/ancho: %s" % str(_shapes))
	quit()


## Coloca un árbol solo y encuadra la cámara a su medida. Devuelve su altura
## real en metros, que es la que le da la biblioteca.
func _place(library: PropLibrary, key: String, from_top: bool = false) -> float:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()

	var mesh := library.mesh(key, 0)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var factor := library.scale_for(key)
	node.scale = Vector3(factor, factor, factor)
	_holder.add_child(node)

	var box := mesh.get_aabb()
	var tall := box.size.y * factor
	var wide := maxf(box.size.x, box.size.z) * factor
	var middle := (box.position + box.size * 0.5) * factor

	# Encuadre ortográfico sobre la caja entera, con un pelo de margen. Va
	# ortográfico y no en perspectiva porque el recorte acaba en un cuadrado
	# plano: cualquier fuga hacia el punto de vista haría que el árbol se viese
	# torcido al instanciarlo, y con treinta mil se notaría.
	if from_top:
		# Desde arriba lo que se encuadra es la COPA, así que la medida es el
		# ancho y no el alto: encuadrando por el alto, un pino de veinte metros
		# saldría como un punto en medio de la celda.
		var crown := wide * 1.03
		_camera.size = crown
		_camera.far = crown * 10.0 + 50.0
		_camera.position = Vector3(middle.x, middle.y + _camera.far * 0.4, middle.z)
		_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		return tall

	var reach := maxf(tall, wide) * 1.03
	_camera.size = reach
	_camera.far = reach * 10.0 + 50.0
	_camera.position = Vector3(middle.x, middle.y, middle.z + _camera.far * 0.4)
	_camera.rotation = Vector3.ZERO
	return tall


## Recorta al árbol y lo centra en la celda, sin deformarlo.
##
## Sin respetar la proporción, un pino estrecho se estiraría hasta llenar el
## cuadrado y saldría gordo. Se recorta al alfa, se escala para que el lado
## mayor llene la celda, y se devuelve la proporción para que el impostor use un
## rectángulo de esa forma y no un cuadrado.
func _crop(image: Image) -> Dictionary:
	var left := image.get_width()
	var top := image.get_height()
	var right := 0
	var bottom := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.06:
				continue
			left = mini(left, x)
			right = maxi(right, x)
			top = mini(top, y)
			bottom = maxi(bottom, y)
	if right <= left or bottom <= top:
		return {"image": image, "aspect": 1.0}

	const MARGIN := 3
	var box := Rect2i(
		maxi(left - MARGIN, 0), maxi(top - MARGIN, 0),
		mini(right - left + MARGIN * 2, image.get_width() - left + MARGIN),
		mini(bottom - top + MARGIN * 2, image.get_height() - top + MARGIN))
	var cut := image.get_region(box)
	var aspect := float(cut.get_height()) / maxf(float(cut.get_width()), 1.0)

	# El árbol se pega ABAJO de la celda y centrado a lo ancho. Abajo porque el
	# pie del árbol es lo que se clava en el suelo: si quedase flotando en medio
	# de la celda, el impostor saldría hundido o levitando según el recorte.
	var scale := float(CELL) / float(maxi(cut.get_width(), cut.get_height()))
	var wide := maxi(int(float(cut.get_width()) * scale), 1)
	var tall := maxi(int(float(cut.get_height()) * scale), 1)
	cut.resize(wide, tall, Image.INTERPOLATE_LANCZOS)
	for y in range(cut.get_height()):
		for x in range(cut.get_width()):
			var pixel := cut.get_pixel(x, y)
			pixel.a = clampf(pixel.a * ALPHA_GAIN, 0.0, 1.0)
			cut.set_pixel(x, y, pixel)

	var cell := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	cell.fill(Color(0, 0, 0, 0))
	cell.blit_rect(cut, Rect2i(Vector2i.ZERO, Vector2i(wide, tall)),
		Vector2i((CELL - wide) / 2, CELL - tall))
	return {"image": cell, "aspect": aspect}


## Cuánto de la celda ocupa el árbol. Control de calidad del horneado.
func _coverage(image: Image) -> float:
	var hits := 0
	var step := 4
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			if image.get_pixel(x, y).a > 0.35:
				hits += 1
	return float(hits) / float(maxi(
		(image.get_height() / step) * (image.get_width() / step), 1))


func _build_studio() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(CELL, CELL) * SUPER
	# Fondo transparente: lo que no es árbol tiene que salir con alfa cero, que
	# es justo el recorte que se busca.
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_view)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	_view.add_child(env)

	_holder = Node3D.new()
	_view.add_child(_holder)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.01
	_view.add_child(_camera)
	_camera.make_current()
