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
	
	var texture := ImageTexture.create_from_image(image)
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
	
	var texture := ImageTexture.create_from_image(image)
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
	
	var texture := ImageTexture.create_from_image(image)
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
	
	var texture := ImageTexture.create_from_image(image)
	return texture


## Genera un normal map a partir de un height map
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
	
	var texture := ImageTexture.create_from_image(image)
	return texture


## Genera todas las texturas del terreno y las guarda
static func generate_all_terrain_textures(_save_path: String = "res://textures/terrain/") -> Dictionary:
	var textures := {}
	
	print("Generando texturas procedurales...")
	
	textures["grass"] = generate_grass_texture()
	textures["rock"] = generate_rock_texture()
	textures["snow"] = generate_snow_texture()
	textures["sand"] = generate_sand_texture()
	
	textures["grass_normal"] = generate_normal_from_noise(512, 0.08, 0.5)
	textures["rock_normal"] = generate_normal_from_noise(512, 0.05, 1.0)
	textures["snow_normal"] = generate_normal_from_noise(512, 0.03, 0.3)
	textures["sand_normal"] = generate_normal_from_noise(512, 0.06, 0.4)
	
	print("Texturas generadas: ", textures.keys())
	
	return textures
