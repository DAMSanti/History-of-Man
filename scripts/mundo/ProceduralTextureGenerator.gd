@tool
class_name ProceduralTextureGenerator
extends RefCounted
## Genera las texturas procedurales del AGUA.
##
## Antes generaba tambien las del terreno -hierba, roca, nieve y arena, pintadas
## pixel a pixel-, y costaban cuatro segundos por partida. Ya no: el terreno usa
## fotogrametria, que trae `scripts/tools/TerrainTextureIngest.gd`.
##
## Las del agua se quedan aqui, y no por inercia: tienen que teselar EXACTAMENTE
## y desfilar sobre el cauce, y eso se consigue sumando senos de periodo entero
## sobre el lado de la textura. Una fotografia de agua no tesela sin costura, y
## la costura se veria justamente porque la textura se desplaza.

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


## Version del algoritmo de generacion. Subirla invalida las caches en disco.
##
## v5: el terreno pasa a fotogrametria y aqui solo quedan las del agua, asi que
## las caches viejas guardan ocho texturas que ya no mira nadie.
const TEXTURE_SET_VERSION := 5
const CACHE_PATH := "user://terrain_textures.res"

## Cache en memoria para no repetir el coste dentro de una misma sesion
static var _cached_textures: Dictionary = {}


## Las dos texturas del agua.
##
## Estas siguen siendo procedurales, y no por inercia: tienen que teselar
## EXACTAMENTE y desfilar sobre el cauce, y eso se consigue sumando senos de
## periodo entero sobre el lado de la textura. Una fotografia de agua no tesela
## sin costura, y la costura se veria porque la textura va desplazandose.
##
## Las del terreno, en cambio, ya no salen de aqui: las trae
## `scripts/tools/TerrainTextureIngest.gd` de ambientCG. Generar las ocho
## costaba cuatro segundos y ninguna se usa ya.
static func get_water_textures() -> Dictionary:
	if _cached_textures.has("water_normal"):
		return _cached_textures

	if ResourceLoader.exists(CACHE_PATH):
		var cached := ResourceLoader.load(CACHE_PATH) as TerrainTextureSet
		if cached and cached.version == TEXTURE_SET_VERSION \
				and cached.textures.has("water_normal"):
			_cached_textures = cached.textures
			return _cached_textures

	_cached_textures = {
		"water_normal": generate_water_normal_texture(),
		"water_foam": generate_water_foam_texture(),
	}

	var set_res := TerrainTextureSet.new()
	set_res.textures = _cached_textures
	set_res.version = TEXTURE_SET_VERSION
	if ResourceSaver.save(set_res, CACHE_PATH) != OK:
		push_warning("No se pudo guardar la cache de texturas en " + CACHE_PATH)

	return _cached_textures


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
