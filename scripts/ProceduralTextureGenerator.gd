@tool
class_name ProceduralTextureGenerator
extends RefCounted
## Genera texturas procedurales para el terreno.
## Útil cuando no tienes texturas artísticas.

## Genera una textura de hierba
static func generate_grass_texture(size: int = 512) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.seed = 12345
	
	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.2
	detail_noise.seed = 54321
	
	var blade_noise := FastNoiseLite.new()
	blade_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	blade_noise.frequency = 0.3
	blade_noise.seed = 98765
	
	for y in range(size):
		for x in range(size):
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var d := (detail_noise.get_noise_2d(x, y) + 1.0) * 0.5
			var b := (blade_noise.get_noise_2d(x, y) + 1.0) * 0.5
			
			# Colores de hierba más vivos y variados
			var base_green := 0.38 + n * 0.18 + b * 0.08
			var base_red := 0.18 + n * 0.08
			var base_blue := 0.08 + d * 0.06
			
			# Variación para simular hojas/briznas
			if b > 0.7:
				base_green += 0.1
				base_red -= 0.02
			elif b < 0.3:
				base_green -= 0.05
				base_red += 0.03
			
			var color := Color(
				clampf(base_red, 0.0, 1.0),
				clampf(base_green, 0.0, 1.0),
				clampf(base_blue, 0.0, 1.0)
			)
			image.set_pixel(x, y, color)
	
	var texture := _finish_texture(image)
	return texture


## Genera una textura de roca
static func generate_rock_texture(size: int = 512) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.02
	noise.seed = 11111
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	
	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.1
	detail_noise.seed = 22222
	
	var crack_noise := FastNoiseLite.new()
	crack_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	crack_noise.frequency = 0.05
	crack_noise.seed = 33333
	crack_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	
	for y in range(size):
		for x in range(size):
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var d := (detail_noise.get_noise_2d(x, y) + 1.0) * 0.5
			var c := (crack_noise.get_noise_2d(x, y) + 1.0) * 0.5
			
			# Gris rocoso con variación y grietas
			var base := 0.38 + n * 0.28 + d * 0.12
			
			# Grietas oscuras
			if c < 0.15:
				base *= 0.6
			
			# Tono marrón/gris variado
			var r := base * 1.02
			var g := base * 0.95
			var b := base * 0.88
			
			var color := Color(
				clampf(r, 0.0, 1.0),
				clampf(g, 0.0, 1.0),
				clampf(b, 0.0, 1.0)
			)
			image.set_pixel(x, y, color)
	
	var texture := _finish_texture(image)
	return texture


## Genera una textura de nieve
static func generate_snow_texture(size: int = 512) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.seed = 33333
	
	var sparkle_noise := FastNoiseLite.new()
	sparkle_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	sparkle_noise.frequency = 0.15
	sparkle_noise.seed = 44444
	
	for y in range(size):
		for x in range(size):
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var s := (sparkle_noise.get_noise_2d(x, y) + 1.0) * 0.5
			
			# Blanco con sutil variación azulada
			var base := 0.92 + n * 0.08
			
			# Destellos
			if s > 0.85:
				base = 1.0
			
			var r := base * 0.98
			var g := base * 0.99
			var b := base * 1.0
			
			var color := Color(r, g, b)
			image.set_pixel(x, y, color)
	
	var texture := _finish_texture(image)
	return texture


## Genera una textura de arena
static func generate_sand_texture(size: int = 512) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.04
	noise.seed = 55555
	
	var ripple_noise := FastNoiseLite.new()
	ripple_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ripple_noise.frequency = 0.15
	ripple_noise.seed = 66666
	
	var grain_noise := FastNoiseLite.new()
	grain_noise.noise_type = FastNoiseLite.TYPE_VALUE
	grain_noise.frequency = 0.5
	grain_noise.seed = 77777
	
	for y in range(size):
		for x in range(size):
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var r_val := (ripple_noise.get_noise_2d(x, y) + 1.0) * 0.5
			var grain := (grain_noise.get_noise_2d(x, y) + 1.0) * 0.5
			
			# Arena dorada/beige con granos
			var base := 0.72 + n * 0.12 + r_val * 0.06 + grain * 0.03
			
			# Color arena cálido
			var r := base * 0.98
			var g := base * 0.82
			var b := base * 0.58
			
			var color := Color(
				clampf(r, 0.0, 1.0),
				clampf(g, 0.0, 1.0),
				clampf(b, 0.0, 1.0)
			)
			image.set_pixel(x, y, color)
	
	var texture := _finish_texture(image)
	return texture


## Genera un normal map a partir de un height map
## Normales de la superficie del agua, en una textura que TESELA de verdad.
##
## Se construye como suma de senos de periodo entero sobre el lado de la
## textura. Eso garantiza que el borde derecho encaja con el izquierdo sin
## costura, cosa que con ruido normal no pasa, y ahi la costura se veria porque
## la textura va a ir desfilando por encima del cauce.
##
## Los senos van AQUI y no en el shader: en el shader, con la direccion de la
## corriente interpolada por fragmento, la fase pegaba bandazos en la orilla y
## salian galones y espinas de pescado. En una textura se muestrea con mipmaps
## y el aliasing lo resuelve el hardware.
static func generate_water_normal_texture(size: int = 256) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)

	# Frecuencias enteras y primas entre si, para que la suma no repita antes
	# de completar la tesela. Amplitud decreciente: oleaje grande y rizado fino.
	var waves := [
		# [kx, ky, amplitud, fase]
		[1.0, 2.0, 1.00, 0.0],
		[3.0, 1.0, 0.55, 1.7],
		[2.0, 5.0, 0.35, 3.1],
		[5.0, 3.0, 0.24, 0.6],
		[7.0, 4.0, 0.16, 2.4],
		[4.0, 9.0, 0.11, 5.0],
		[11.0, 7.0, 0.07, 1.2],
	]

	var tau := TAU / float(size)
	for y in range(size):
		for x in range(size):
			# Derivada analitica de la suma: mas exacto y mas barato que restar
			# muestras vecinas, y sin el escalon de la diferencia finita
			var dx := 0.0
			var dy := 0.0
			for wave: Array in waves:
				var kx: float = wave[0]
				var ky: float = wave[1]
				var amp: float = wave[2]
				var phase: float = kx * float(x) * tau + ky * float(y) * tau + float(wave[3])
				var c := cos(phase) * amp
				dx += c * kx
				dy += c * ky

			var normal := Vector3(-dx * 0.06, -dy * 0.06, 1.0).normalized()
			image.set_pixel(x, y, Color(
				normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))

	return _finish_texture(image)


## Turbulencia del agua: manchas escalares que teselan, para que la espuma se
## MUEVA en vez de ser una funcion fija de la pendiente.
##
## Va en textura aparte y no en un canal de las normales porque necesita un
## contraste completamente distinto: las normales del agua son casi planas
## -valores muy juntos alrededor de 0.5- y de ahi no se saca una mascara de
## espuma con bordes. Aqui interesa justo lo contrario, manchas con borde.
##
## Tesela por el mismo motivo que las normales: va a ir desfilando por encima
## del cauce y una costura se veria pasar.
static func generate_water_foam_texture(size: int = 256) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)

	# Frecuencias enteras: es lo que garantiza que el borde derecho encaje con
	# el izquierdo. Primas entre si para que el patron no repita antes de
	# completar la tesela.
	var waves := [
		[2.0, 3.0, 1.00, 0.0],
		[5.0, 2.0, 0.62, 2.1],
		[3.0, 7.0, 0.44, 4.3],
		[11.0, 5.0, 0.28, 1.1],
		[7.0, 13.0, 0.19, 5.6],
	]

	var tau := TAU / float(size)
	var total := 0.0
	for wave: Array in waves:
		total += float(wave[2])

	for y in range(size):
		for x in range(size):
			var value := 0.0
			for wave: Array in waves:
				value += sin(float(wave[0]) * float(x) * tau
					+ float(wave[1]) * float(y) * tau + float(wave[3])) * float(wave[2])
			# A 0..1 y con contraste: la espuma es blanco o no es nada, no un
			# degradado, asi que se empuja hacia los extremos
			var level := clampf(value / total * 0.5 + 0.5, 0.0, 1.0)
			level = smoothstep(0.30, 0.72, level)
			image.set_pixel(x, y, Color(level, level, level))

	return _finish_texture(image)


static func generate_normal_from_noise(size: int = 512, frequency: float = 0.05, strength: float = 1.0) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.seed = randi()
	
	for y in range(size):
		for x in range(size):
			# Obtener alturas vecinas
			var h := noise.get_noise_2d(x, y)
			var hx := noise.get_noise_2d(x + 1, y)
			var hy := noise.get_noise_2d(x, y + 1)
			
			# Calcular normal
			var dx := (h - hx) * strength
			var dy := (h - hy) * strength
			
			# Convertir a color (normal map format)
			var nx := dx * 0.5 + 0.5
			var ny := dy * 0.5 + 0.5
			var nz := 1.0
			
			# Normalizar
			var normal_len := sqrt(nx*nx + ny*ny + nz*nz)
			nx /= normal_len
			ny /= normal_len
			nz /= normal_len
			
			# Convertir a rango 0-1 para textura
			var color := Color(nx * 0.5 + 0.5, ny * 0.5 + 0.5, nz * 0.5 + 0.5)
			image.set_pixel(x, y, color)
	
	var texture := _finish_texture(image)
	return texture


## Genera todas las texturas del terreno y las guarda
## Version del algoritmo de generacion. Subirla invalida las caches en disco.
const TEXTURE_SET_VERSION := 4
const CACHE_PATH := "user://terrain_textures.res"

## Cache en memoria para no repetir el coste dentro de una misma sesion
static var _cached_textures: Dictionary = {}


## Devuelve las texturas del terreno reutilizando la cache cuando existe.
## Es el punto de entrada que deberia usar todo el mundo: generarlas cuesta
## unos 4 s y antes se repetia ese coste en cada regeneracion del terreno.
static func get_terrain_textures() -> Dictionary:
	if not _cached_textures.is_empty():
		return _cached_textures

	if ResourceLoader.exists(CACHE_PATH):
		var cached := ResourceLoader.load(CACHE_PATH) as TerrainTextureSet
		if cached and cached.version == TEXTURE_SET_VERSION and not cached.textures.is_empty():
			_cached_textures = cached.textures
			print("Texturas de terreno recuperadas de cache")
			return _cached_textures

	_cached_textures = generate_all_terrain_textures()

	var set_res := TerrainTextureSet.new()
	set_res.textures = _cached_textures
	set_res.version = TEXTURE_SET_VERSION
	if ResourceSaver.save(set_res, CACHE_PATH) != OK:
		push_warning("No se pudo guardar la cache de texturas en " + CACHE_PATH)

	return _cached_textures


static func generate_all_terrain_textures(_save_path: String = "res://textures/terrain/") -> Dictionary:
	var textures := {}
	
	print("Generando texturas procedurales...")
	
	textures["grass"] = generate_grass_texture()
	textures["water_normal"] = generate_water_normal_texture()
	textures["water_foam"] = generate_water_foam_texture()
	textures["rock"] = generate_rock_texture()
	textures["snow"] = generate_snow_texture()
	textures["sand"] = generate_sand_texture()
	
	textures["grass_normal"] = generate_normal_from_noise(512, 0.08, 0.5)
	textures["rock_normal"] = generate_normal_from_noise(512, 0.05, 1.0)
	textures["snow_normal"] = generate_normal_from_noise(512, 0.03, 0.3)
	textures["sand_normal"] = generate_normal_from_noise(512, 0.06, 0.4)
	
	print("Texturas generadas: ", textures.keys())
	
	return textures


## Genera los mipmaps y crea la textura.
## Sin mipmaps cada fragmento del terreno hace un acceso practicamente aleatorio
## a una textura de 512x512 repetida cientos de veces a lo largo del mapa, lo
## que a distancia son fallos de cache constantes. Ademas el filtrado
## anisotropico configurado en project.godot no tiene efecto sin niveles de mip.
static func _finish_texture(image: Image) -> ImageTexture:
	image.generate_mipmaps()
	_compress(image)
	return ImageTexture.create_from_image(image)


## Comprime a BC7 antes de subirla a la tarjeta.
##
## Estaban en RGB8 crudo, que la tarjeta suele rellenar a RGBA8: cuatro bytes
## por texel. BC7 es uno, o sea la CUARTA parte de trafico por cada fetch, con
## la misma calidad a efectos practicos. Y el terreno hace varios fetch por
## fragmento -material por plano, y otra vez para las normales-, asi que si el
## shader esta limitado por memoria y no por aritmetica es aqui donde se nota.
##
## Se comprime DESPUES de generar los mipmaps: al reves habria que comprimir
## cada nivel por separado y el resultado es peor.
static func _compress(image: Image) -> void:
	if image.is_compressed():
		return
	# BC7 pide cuatro canales; en RGB8 la llamada no hace nada y la textura se
	# queda cruda sin avisar.
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	image.compress(Image.COMPRESS_BPTC, Image.COMPRESS_SOURCE_GENERIC)
