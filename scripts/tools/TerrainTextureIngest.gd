extends SceneTree
## Trae las texturas PBR del terreno y las deja listas para el shader.
##
## Descarga de [ambientCG] —CC0, sin cuenta ni clave— los assets que nombra
## [TerrainLayers], los descomprime, empaqueta los mapas en tres texturas por
## capa y construye tres `Texture2DArray`:
##
##   albedo   RGB  color
##   normal   RGB  normal en convención OpenGL, que es la de Godot
##   orm      R=oclusión  G=rugosidad  B=metálico  A=ALTURA
##
## La altura va en el alfa y no en una cuarta textura porque BC7 trae alfa sin
## coste extra, y es la que alimentará el parallax que tapa el hueco de escala
## de 1 a 5 m. Hasta ahora ni se descargaba: el terreno usaba albedo y normal y
## nada más.
##
## Lo que se versiona es ESTE script, no los 34 MB de arrays: se reconstruyen
## solos y por eso `textures/` está en .gitignore. Igual que las teselas del MDT.
##
## Correr con:
##   Godot_v4.5.1-stable_win64_console.exe --headless --path . \
##     --script res://scripts/tools/TerrainTextureIngest.gd

## Formato de descarga. JPG y no PNG porque son 10 MB por asset en vez de 19 y
## el destino es BC7 de todas formas: la pérdida de BC7 se come la del JPG.
const FORMAT := "JPG"

## Resolución que se pide a ambientCG. Se pide la MISMA que se va a usar para no
## reescalar: reescalar una normal map desalinea las pendientes.
const REMOTE_RES := "1K"

const BASE_URL := "https://ambientcg.com/get?file=%s_%s-%s.zip"

## Dónde se dejan los zip mientras se trabaja. En user:// y no en el proyecto
## para no ensuciar el árbol de fuentes.
const WORK_DIR := "user://texture_ingest"

## La descarga la hace `curl` y no Godot, y no es por gusto.
##
## En modo `--script` el módulo TLS del motor no llega a registrarse: cualquier
## `connect_to_host` sobre https muere con «SSL module failed to initialize»,
## y falla igual con ventana que sin ella, y también pasando
## `TLSOptions.client_unsafe()`. O sea que no es un problema de certificados,
## es que el módulo no está. Por eso [DEMImporter] puede bajar teselas —corre
## dentro del juego, con el motor entero levantado— y esto no.
##
## `curl` viene de serie en Windows 10 en adelante, en macOS y en cualquier
## Linux de escritorio, así que sale más barato que montar la descarga en el
## juego para una herramienta que se ejecuta una vez.
const CURL_ARGS := ["-sSL", "--fail", "--retry", "2", "--max-time", "300"]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK_DIR))
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://textures/terrain"))

	var albedo: Array[Image] = []
	var normal: Array[Image] = []
	var orm: Array[Image] = []

	for index in range(TerrainLayers.COUNT):
		var asset: String = TerrainLayers.CATALOGUE[index]["asset"]
		var label: String = TerrainLayers.CATALOGUE[index]["name"]
		print("[%d/%d] %s (%s)" % [index + 1, TerrainLayers.COUNT, label, asset])

		var zip_path := "%s/%s.zip" % [WORK_DIR, asset]
		if not FileAccess.file_exists(zip_path):
			if not _download(asset, zip_path):
				print("   FALLO en la descarga; se aborta")
				quit(1)
				return
		else:
			print("   ya descargado")

		var maps := _unpack(zip_path, asset)
		if maps.is_empty():
			print("   FALLO al abrir el zip; se aborta")
			quit(1)
			return

		var source: Image = maps["color"]
		print("   %d x %d de origen" % [source.get_width(), source.get_height()])

		# El ORM se arma ANTES de preparar nada, porque `_prepare` muta la imagen
		# que recibe: si se armara después, leería las dimensiones del color ya
		# cuadrado y estiraría oclusión, rugosidad y altura mientras el albedo se
		# ha repetido. En Rock063 -1024x512- eso deja el ORM medio ciclo movido
		# respecto al color, que es un desajuste sutil y muy difícil de ver.
		var orm_image := _pack_orm(maps)

		albedo.append(_prepare(maps["color"] as Image, false))
		normal.append(_prepare(maps["normal"] as Image, false))
		orm.append(_prepare(orm_image, false))

	print("")
	print("Construyendo los arrays...")
	_save_arrays(albedo, normal, orm)
	quit()


func _download(asset: String, to_path: String) -> bool:
	var url := BASE_URL % [asset, REMOTE_RES, FORMAT]
	var args := CURL_ARGS.duplicate()
	args.append("-o")
	args.append(ProjectSettings.globalize_path(to_path))
	args.append(url)

	var output: Array = []
	var code := OS.execute("curl", args, output, true)
	if code != 0:
		print("   curl falló (código %d): %s" % [code, "\n".join(output).strip_edges()])
		return false

	var size := 0
	var file := FileAccess.open(to_path, FileAccess.READ)
	if file:
		size = file.get_length()
		file.close()
	if size <= 0:
		print("   descarga vacía")
		return false
	print("   descargado, %.1f MB" % (size / 1048576.0))
	return true


## Saca del zip los mapas que interesan.
##
## Los nombres dentro del zip son `<asset>_<res>-<formato>_<mapa>.jpg`, y la
## normal viene en las DOS convenciones: se coge la GL, que es la de Godot. Con
## la DX el relieve sale invertido y las laderas se leen al revés.
func _unpack(zip_path: String, asset: String) -> Dictionary:
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		return {}

	var prefix := "%s_%s-%s_" % [asset, REMOTE_RES, FORMAT]
	var maps := {}

	var color := _read_image(zip, prefix + "Color.jpg")
	if color == null:
		zip.close()
		return {}
	maps["color"] = color

	var normal := _read_image(zip, prefix + "NormalGL.jpg")
	if normal == null:
		# Sin normal no se aborta: se pone plana y se avisa. Es preferible una
		# capa mate a que la ingesta entera se caiga por un asset incompleto.
		print("   sin NormalGL: se usa normal plana")
		normal = Image.create(color.get_width(), color.get_height(),
			false, Image.FORMAT_RGB8)
		normal.fill(Color(0.5, 0.5, 1.0))
	maps["normal"] = normal

	# Estos tres pueden faltar según el asset, y cada ausencia tiene un valor
	# neutro claro: sin oclusión no hay sombra propia, sin rugosidad se asume
	# muy mate -que es lo que es una superficie natural- y sin altura, plano.
	maps["ao"] = _read_image(zip, prefix + "AmbientOcclusion.jpg")
	maps["roughness"] = _read_image(zip, prefix + "Roughness.jpg")
	maps["height"] = _read_image(zip, prefix + "Displacement.jpg")

	zip.close()
	return maps


func _read_image(zip: ZIPReader, name: String) -> Image:
	if not zip.file_exists(name):
		return null
	var bytes := zip.read_file(name)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_jpg_from_buffer(bytes) != OK:
		return null
	return image


## Mete oclusión, rugosidad y altura en un solo RGBA.
##
## Se trabaja sobre los BYTES y no con `get_pixel`: son un millón de píxeles por
## capa y ocho capas, y píxel a píxel desde GDScript esto tardaría minutos. Es
## el mismo error que ya costaba cuatro segundos por partida en el generador de
## texturas procedurales.
func _pack_orm(maps: Dictionary) -> Image:
	var reference: Image = maps["color"]
	var width := reference.get_width()
	var height := reference.get_height()
	var count := width * height

	var ao := _channel_bytes(maps["ao"] as Image, width, height, 255)
	var rough := _channel_bytes(maps["roughness"] as Image, width, height, 242)
	var tall := _channel_bytes(maps["height"] as Image, width, height, 128)

	var out := PackedByteArray()
	out.resize(count * 4)
	for i in range(count):
		var o := i * 4
		out[o] = ao[i]
		out[o + 1] = rough[i]
		out[o + 2] = 0  # metálico: ninguna superficie natural lo es
		out[o + 3] = tall[i]

	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, out)


## Cuadra una textura que no lo sea, REPITIENDOLA por el lado corto.
##
## Un `1K` de ambientCG no garantiza 1024x1024: Rock063 viene en 1024x512.
## Reescalar a cuadrado sin mas estiraria la caliza al doble de alto, y en una
## roca estratificada eso se ve. Repetirla dos veces en vertical conserva la
## proporcion Y la teselabilidad -una textura seamless repetida un numero entero
## de veces sigue siendo seamless-, que es justo lo que hace falta.
##
## Recortar al cuadrado central seria la otra opcion, pero rompe el seamless,
## que en terreno se nota mucho mas que ver el patron dos veces.
func _make_square(image: Image) -> void:
	var width := image.get_width()
	var height := image.get_height()
	if width == height or width <= 0 or height <= 0:
		return

	var side := maxi(width, height)
	var tiled := Image.create(side, side, false, image.get_format())
	var y := 0
	while y < side:
		var x := 0
		while x < side:
			tiled.blit_rect(image, Rect2i(0, 0, width, height), Vector2i(x, y))
			x += width
		y += height
	image.copy_from(tiled)


## Un mapa de un solo canal como bytes, o un relleno constante si no existe.
func _channel_bytes(image: Image, width: int, height: int,
		fallback: int) -> PackedByteArray:
	var out := PackedByteArray()
	if image == null:
		out.resize(width * height)
		out.fill(fallback)
		return out
	if image.get_width() != width or image.get_height() != height:
		image.resize(width, height, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_R8)
	return image.get_data()


## Deja la imagen al tamaño de destino, con mipmaps y comprimida a BC7.
##
## Se comprueban las DOS dimensiones. Comprobando sólo el ancho, un asset que no
## fuese cuadrado se colaba con su alto original y el array se negaba a montarse
## entero -«All images must share the same dimensions»- sin decir cuál era el
## raro. Un `1K` de ambientCG no garantiza 1024x1024.
func _prepare(image: Image, _is_normal: bool) -> Image:
	_make_square(image)
	if image.get_width() != TerrainLayers.SIZE \
			or image.get_height() != TerrainLayers.SIZE:
		image.resize(TerrainLayers.SIZE, TerrainLayers.SIZE,
			Image.INTERPOLATE_LANCZOS)
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	image.generate_mipmaps()
	image.compress(Image.COMPRESS_BPTC, Image.COMPRESS_SOURCE_GENERIC)
	return image


func _save_arrays(albedo: Array[Image], normal: Array[Image],
		orm: Array[Image]) -> void:
	var set_res := TerrainTextureArrays.new()
	set_res.albedo_images = albedo
	set_res.normal_images = normal
	set_res.orm_images = orm
	set_res.size = TerrainLayers.SIZE
	set_res.layers = TerrainLayers.COUNT

	if not set_res.is_usable():
		print("NO se guarda nada: faltan capas")
		return

	var error := ResourceSaver.save(set_res, TerrainLayers.ARRAYS_PATH)
	if error != OK:
		print("no se pudieron guardar los arrays (error %d)" % error)
		return

	var bytes := 0
	var file := FileAccess.open(TerrainLayers.ARRAYS_PATH, FileAccess.READ)
	if file:
		bytes = file.get_length()
		file.close()
	print("guardado %s · %d capas de %d px · %.1f MB" % [
		TerrainLayers.ARRAYS_PATH, TerrainLayers.COUNT, TerrainLayers.SIZE,
		bytes / 1048576.0])
