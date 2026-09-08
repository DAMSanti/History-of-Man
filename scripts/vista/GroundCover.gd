class_name GroundCover
extends Node3D
## La alfombra de hierba: rejilla del mundo alrededor de la cámara, hasta un
## radio, teñida del color del suelo.
##
## Éste es el quinto planteamiento y los cuatro anteriores compartían el mismo
## error, así que conviene dejarlo escrito para no volver a él.
##
##   1. Sembrar la hierba con el resto de los props, de una vez sobre el mapa.
##      133.333 matas sobre 16,8 km² es UNA CADA 126 m²: desde el suelo se veían
##      dos en toda la pantalla, y costaba 69 ms.
##   2. Generarla alrededor de la cámara montando las transformaciones en
##      GDScript. Arreglaba el reparto pero no el precio: las matas de Poly
##      Haven son fotogrametría, 2.614 triángulos cada una.
##   3. Naipes de cuatro triángulos en anillos concéntricos. Se veían los
##      anillos, y estirarlos con el zoom fue peor: recolocar toda la hierba
##      mientras mueves la cámara se nota al instante.
##   4. Una rejilla de PANTALLA proyectada al suelo. La densidad salía perfecta
##      y cubría todo lo que se veía, pero el reparto dependía de a dónde
##      mirases: al inclinar la cámara la hierba se cortaba en recto.
##
## Los cuatro intentaban tapar más superficie. Y la respuesta, mirando cómo lo
## resuelven los juegos que lo tienen bien, es que eso no es el problema:
##
##   - Manor Lords enseña «densidad de hierba» y «DISTANCIA de hierba» como dos
##     ajustes separados. O sea que la hierba tiene un radio, y es finito.
##   - En Ghost of Tsushima las teselas lejanas llevan textura pintada en vez
##     del material procedural: el campo lejano es TEXTURA, no briznas.
##   - En Unreal la vegetación lee el color del terreno de una Runtime Virtual
##     Texture, para tomar el color del suelo que pisa.
##   - Y en el borde la hierba se hace más baja hasta fundirse con lo de fuera.
##
## O sea: el círculo es normal y lo tiene todo el mundo. Lo que hay que hacer es
## que NO SE VEA, y eso son dos cosas, que son las dos que aquí faltaban:
##
##   - la brizna se tiñe del color del suelo -ver `_bake_terrain_tint`-, así que
##     no hay salto de color en el borde;
##   - en el último tramo la brizna ENCOGE hasta hundirse en la textura, en vez
##     de ralear o cortarse.
##
## Lo que este fichero hace por fotograma es mover un nodo. Nada más.

const SHADER_PATH := "res://shaders/hierba.gdshader"
const ATLAS_PATH := "res://models/props/hierba_atlas.res"

## El mismo atlas fotografiado al ángulo de juego, para los quads tumbados.
const ATLAS_TOP_PATH := "res://models/props/hierba_atlas_cenital.res"

## Cuántas celdas por lado tiene el atlas de siluetas. Nueve plantas distintas:
## un prado no es un monocultivo, y con cuatro se leía el patrón.
##
## Vive aquí y no en la herramienta porque el que tiene que estar de acuerdo con
## el shader es este fichero; `scripts/tools/HierbaAtlas.gd` lee esta constante,
## así que no hay dos números que puedan discrepar.
const ATLAS_GRID := 3

## Franja sobre la lámina de agua en la que la hierba se rala hasta desaparecer.
## Medio metro: lo justo para que la orilla salga deshilachada y no recortada.
const SHORE_M := 0.5

## Lado del retrato cenital del terreno, en píxeles. Ver `_start_albedo_bake`.
##
## Dos mil cuarenta y ocho sobre cuatro kilómetros son dos metros por téxel. No
## hace falta más: lo que se le pide a este mapa es el color del suelo, que
## cambia despacio, no su detalle.
const BAKE_SIZE := 2048

## Cuántos fotogramas se le dan al retrato antes de leerlo. Tres, porque el
## primero monta la escena, el segundo compila el shader del terreno para ese
## viewport y el tercero ya dibuja de verdad.
const BAKE_FRAMES := 3

## Dónde se deja copia del retrato, para poder mirarlo.
const BAKE_DUMP := "user://terreno_albedo.png"

## Hasta dónde llega la hierba, en metros. Es el ajuste de gráficos «distancia
## de hierba», igual que en Manor Lords.
##
## Noventa metros se quedó corto y la cuenta lo explica: con un naipe de 0,46 m
## a 1080p y 60º, una brizna ocupa `430 / distancia` píxeles, así que por tamaño
## aguantaría hasta pasados los ciento setenta metros. El que la mataba antes de
## tiempo era el radio -el encogido del borde arrancaba a los cincuenta y dos-,
## no la visibilidad.
@export var grass_distance := 165.0:
	set(value):
		grass_distance = clampf(value, 20.0, 260.0)
		if is_inside_tree() and _material != null:
			_build()

## Matas por metro cuadrado. Es el ajuste «densidad de hierba».
## Baja de 3,6 a 2,4 al doblar el radio. No es un recorte de calidad: el número
## de instancias crece con el CUADRADO del radio, y a 165 m con 3,6 serían
## trescientas mil. Con 2,4 salen unas doscientas cinco mil, y de cerca sigue
## habiendo más de dos matas por metro cuadrado con naipes de medio metro, que
## se solapan de sobra.
@export var grass_density := 2.4:
	set(value):
		grass_density = clampf(value, 0.4, 12.0)
		if is_inside_tree() and _material != null:
			_build()

## Dónde no crece. La pendiente va en metros de subida por metro de avance.
@export var max_slope := 0.55
@export var min_humidity := 0.10

var _terrain: TerrainGenerator
var _material: ShaderMaterial
var _node: MultiMeshInstance3D
var _spacing := 0.5

## El retrato del terreno mientras se cuece, y en qué fotograma va.
var _bake_view: SubViewport
var _bake_frames := 0


func setup(terrain: TerrainGenerator) -> void:
	_terrain = terrain
	var shader: Shader = load(SHADER_PATH)
	var atlas: Image = load(ATLAS_PATH)
	if shader == null or atlas == null:
		push_warning("Falta el shader o el atlas de hierba. Generalo con:\n"
			+ "  godot --path . --script res://scripts/tools/HierbaAtlas.gd")
		return

	_material = ShaderMaterial.new()
	_material.shader = shader
	# Mipmaps sí: sin ellos la hierba lejana hierve de aliasing, que es el ruido
	# más molesto que puede tener una pradera en movimiento.
	atlas.generate_mipmaps()
	_material.set_shader_parameter("atlas",
		ImageTexture.create_from_image(atlas))
	_material.set_shader_parameter("atlas_grid", ATLAS_GRID)
	var top: Image = load(ATLAS_TOP_PATH)
	if top != null:
		top.generate_mipmaps()
		_material.set_shader_parameter("atlas_top",
			ImageTexture.create_from_image(top))
	_bake_terrain_maps()
	_build()
	_start_albedo_bake()


## Hornea altura, cobertura y COLOR DEL SUELO como texturas, una vez.
##
## La altura va en coma flotante y sin comprimir a propósito: en ocho bits, un
## valle de doscientos metros se cuantiza a saltos de ochenta centímetros y la
## hierba sale escalonada, que se ve muchísimo.
func _bake_terrain_maps() -> void:
	var maps := _terrain.sample_maps()
	var res: int = maps["resolution"]
	var height: PackedFloat32Array = maps["height"]
	if res <= 1 or height.is_empty():
		return

	var humidity: PackedFloat32Array = maps["humidity"]
	var river: PackedFloat32Array = maps["river"]
	var ford: PackedFloat32Array = maps["ford"]
	var extent: Vector2 = maps["extent"]
	var spacing := extent.x / float(res - 1)
	var water_y: float = maps["water_y"]

	# Los dos colores del suelo donde hay hierba. Ver `_bake_terrain_tint`.
	var soil := _ground_colours()
	var meadow: Color = soil["pradera"]
	var wood: Color = soil["bosque"]

	# Se escriben los BYTES de las imágenes y no píxel a píxel: son más de medio
	# millón de texeles, y `set_pixel` construye un `Color` y lo vuelve a
	# descomponer en cada uno. La altura entra tal cual, porque `FORMAT_RF` es
	# exactamente el float que ya hay en el mapa.
	var total_cover := 0.0
	var height_bytes := PackedByteArray()
	height_bytes.resize(res * res * 4)
	var cover_bytes := PackedByteArray()
	cover_bytes.resize(res * res)
	var tint_bytes := PackedByteArray()
	tint_bytes.resize(res * res * 3)

	for z in range(res):
		for x in range(res):
			var idx := z * res + x
			height_bytes.encode_float(idx * 4, height[idx])

			# La pendiente sale del propio mapa por diferencias centradas: la
			# misma cuenta que `get_slope_at` pero sin pasar por la
			# interpolación, y una vez por texel en vez de una vez por brizna.
			var west := height[z * res + maxi(x - 1, 0)]
			var east := height[z * res + mini(x + 1, res - 1)]
			var north := height[maxi(z - 1, 0) * res + x]
			var south := height[mini(z + 1, res - 1) * res + x]
			var slope := Vector2(east - west, south - north).length() \
				/ (2.0 * spacing)

			var wet := humidity[idx] if not humidity.is_empty() else 0.5
			var grow := 1.0 - smoothstep(max_slope * 0.6, max_slope, slope)
			grow *= smoothstep(min_humidity * 0.5, min_humidity + 0.12, wet)

			# EN EL AGUA NO CRECE, y hay que decirlo tres veces porque hay tres
			# aguas distintas y con restar una no basta: se vio hierba entrando
			# en la ría.
			#
			# La primera es la lámina: lo que esté por debajo de la cota del mar
			# está sumergido, y el mapa de río no lo sabe -es una máscara de
			# cauce, no de calado-.
			grow *= smoothstep(water_y, water_y + SHORE_M, height[idx])
			# La segunda es el cauce, que río arriba va por encima de esa cota.
			# Corta duro: en un río no hay pradera aunque sea somero.
			if not river.is_empty():
				grow *= 1.0 - smoothstep(0.02, 0.14, river[idx])
			# Y la tercera el vado, que es lecho de piedra.
			if not ford.is_empty():
				grow *= 1.0 - clampf(ford[idx], 0.0, 1.0) * 0.8

			grow = clampf(grow, 0.0, 1.0)
			total_cover += grow
			cover_bytes[idx] = int(grow * 255.0)

			# El color del suelo. El shader del terreno reparte entre pradera y
			# bosque por curvatura y ruido, que aquí no se pueden reproducir sin
			# duplicar medio shader; la humedad es el sustituto razonable,
			# porque lo hondo y húmedo es justo lo que cría bosque. No hace
			# falta que case téxel a téxel: lo que importa es que el color MEDIO
			# sea el del suelo, que es lo que borra el borde.
			var here := meadow.lerp(wood, smoothstep(0.45, 0.85, wet))
			tint_bytes[idx * 3] = int(clampf(here.r, 0.0, 1.0) * 255.0)
			tint_bytes[idx * 3 + 1] = int(clampf(here.g, 0.0, 1.0) * 255.0)
			tint_bytes[idx * 3 + 2] = int(clampf(here.b, 0.0, 1.0) * 255.0)

	_material.set_shader_parameter("terrain_height",
		ImageTexture.create_from_image(Image.create_from_data(
			res, res, false, Image.FORMAT_RF, height_bytes)))
	_material.set_shader_parameter("terrain_cover",
		ImageTexture.create_from_image(Image.create_from_data(
			res, res, false, Image.FORMAT_R8, cover_bytes)))
	_material.set_shader_parameter("terrain_tint",
		ImageTexture.create_from_image(Image.create_from_data(
			res, res, false, Image.FORMAT_RGB8, tint_bytes)))
	_material.set_shader_parameter("terrain_origin", maps["origin"])
	_material.set_shader_parameter("terrain_extent", extent)
	# El mapa está muestreado en los VÉRTICES de la malla y una textura se lee
	# en el CENTRO de sus texeles: sin corregir medio texel, la hierba queda
	# desplazada medio paso respecto al suelo que pisa.
	_material.set_shader_parameter("terrain_texel",
		Vector2.ONE * (0.5 / float(res)))
	# Metros por texel: con esto el shader saca la pendiente del propio mapa y
	# puede inclinar la brizna con la ladera.
	_material.set_shader_parameter("terrain_step", spacing)

	print("GroundCover: mapa %dx%d, cobertura media %.2f, suelo %s" % [
		res, res, total_cover / float(res * res), meadow])


## De qué color es el suelo donde hay hierba, MEDIDO del propio terreno.
##
## Es el ingrediente que faltaba y el que decide si el final de la alfombra se
## ve o no. Mientras la hierba tuvo un color escrito a mano, el borde del radio
## se leía como una raya: mata pajiza contra suelo pardo. Tiñéndola del color
## del suelo, el borde deja de existir.
##
## Se mide, no se estima: se coge la textura de la capa PRADERA del terreno, se
## saca su color medio reduciéndola a un píxel, y se le aplica LA MISMA
## graduación que le aplica el shader -desaturar hacia el gris de igual
## luminancia y después tintar-. Así, si mañana se regradúa el terreno, la
## hierba lo sigue sola. Ídem con BOSQUE, que es el otro suelo donde hay hierba.
func _ground_colours() -> Dictionary:
	# Un pardo pajizo de reserva por si la biblioteca de texturas no está: no es
	# el color bueno, pero es mejor que un magenta de error en medio del valle.
	var fallback := {
		"pradera": Color(0.34, 0.31, 0.19),
		"bosque": Color(0.22, 0.24, 0.16),
	}
	if not ResourceLoader.exists(TerrainLayers.ARRAYS_PATH):
		return fallback
	var arrays: TerrainTextureArrays = load(TerrainLayers.ARRAYS_PATH)
	if arrays == null or not arrays.is_usable():
		return fallback

	return {
		"pradera": _layer_colour(arrays, TerrainLayers.Layer.PRADERA,
			fallback["pradera"]),
		"bosque": _layer_colour(arrays, TerrainLayers.Layer.BOSQUE,
			fallback["bosque"]),
	}


## Color medio de una capa del terreno, ya graduado como lo gradúa el shader.
func _layer_colour(arrays: TerrainTextureArrays, layer: int,
		fallback: Color) -> Color:
	if layer >= arrays.albedo_images.size():
		return fallback
	var image: Image = (arrays.albedo_images[layer] as Image).duplicate()
	# Las texturas van comprimidas en BC7 y una imagen comprimida no se puede
	# reescalar: hay que descomprimirla antes.
	if image.is_compressed():
		image.decompress()
	# Reducir a un píxel ES la media, y la hace el motor en C++.
	image.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	var raw := image.get_pixel(0, 0)

	# Y se APAGA con la oclusión media de la capa.
	#
	# Sin esto la hierba sale más clara que el suelo, y no es cuestión de gusto:
	# de cerca el terreno se dibuja con su mapa de oclusión encima -las sombritas
	# propias del material- y la media del albedo a secas no lo lleva. Comparar
	# la media cruda con lo que se ve de cerca es comparar dos cosas distintas, y
	# de ahí que el prado siguiera sin casar por mucho que se tocara el tinte.
	var shade := 1.0
	if layer < arrays.orm_images.size():
		var orm: Image = (arrays.orm_images[layer] as Image).duplicate()
		if orm.is_compressed():
			orm.decompress()
		orm.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		shade = clampf(orm.get_pixel(0, 0).r, 0.25, 1.0)
	raw = Color(raw.r * shade, raw.g * shade, raw.b * shade)

	var entry: Dictionary = TerrainLayers.CATALOGUE[layer]
	var tint: Color = entry.get("tint", Color.WHITE)
	var saturation := float(entry.get("sat", 1.0))
	# La misma cuenta que `grade()` en `shaders/triplanar.gdshader`: desaturar
	# hacia el gris de igual luminancia y DESPUÉS tintar. En ese orden, o el
	# tinte se diluye justo en las capas que más hay que corregir.
	var lum := raw.r * 0.299 + raw.g * 0.587 + raw.b * 0.114
	var grey := Color(lum, lum, lum)
	return Color(
		lerpf(grey.r, raw.r, saturation) * tint.r,
		lerpf(grey.g, raw.g, saturation) * tint.g,
		lerpf(grey.b, raw.b, saturation) * tint.b)


## Fotografía el terreno desde arriba con su propio material, para saber de qué
## color es el suelo EXACTAMENTE.
##
## Es el sustituto de las tres aproximaciones que fueron fallando: la media de la
## capa de pradera, luego la media con su oclusión, luego una mezcla entre
## pradera y bosque según la humedad. Ninguna casaba, y no por mala puntería: el
## sombreado del terreno mezcla ocho capas por curvatura, pendiente y ruido, les
## aplica oclusión, macro variación y el apagado de fuera de región. Reproducir
## eso a mano es duplicar medio shader y verlo desincronizarse al primer cambio.
##
## Fotografiarlo no aproxima nada: ES el terreno. Y de paso da lo que la
## investigación decía que hacía falta para la distancia -una capa de color
## ÚNICA en todo el mapa, que por construcción no puede teselar-, sin ningún
## número que calibrar, porque no hay nada que calibrar.
##
## Se fotografía SIN sol y con ambiente blanco plano: lo que se quiere guardar es
## el color propio del suelo, no el de la hora del día. Con el sol dentro, la
## hierba llevaría pintadas las sombras del mediodía a las seis de la tarde.
func _start_albedo_bake() -> void:
	var pieces := _terrain.malla.mesh_pieces()
	if pieces.is_empty():
		return
	var maps := _terrain.sample_maps()
	var extent: Vector2 = maps["extent"]
	var origin: Vector2 = maps["origin"]

	var view := SubViewport.new()
	view.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
	# Mundo propio: si compartiera el del juego entrarían el sol, el cielo y la
	# niebla, y el retrato saldría con la iluminación de ese instante.
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	# Sin reflejos y sin tonemap: se quiere el color, no una interpretación de él.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	view.add_child(env)

	for piece in pieces:
		var copy := MeshInstance3D.new()
		copy.mesh = piece.mesh
		# El MISMO material, no una copia: así el retrato sale con la graduación
		# que tenga el terreno en ese momento.
		copy.material_override = piece.material_override
		view.add_child(copy)
		copy.transform = piece.global_transform

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(extent.x, extent.y)
	camera.near = 1.0
	camera.far = 40000.0
	view.add_child(camera)
	# A plomo sobre el centro del mapa. Con este giro, la derecha de la imagen es
	# el +X del mundo y hacia abajo es el +Z, que es exactamente el reparto que
	# espera `terrain_uv` en el shader.
	camera.transform = Transform3D(
		Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)),
		Vector3(origin.x + extent.x * 0.5, 20000.0,
			origin.y + extent.y * 0.5))
	camera.make_current()

	_bake_view = view
	_bake_frames = 0


## Recoge el retrato cuando ya está dibujado y lo deja como color del suelo.
func _collect_albedo_bake() -> void:
	_bake_frames += 1
	if _bake_frames < BAKE_FRAMES:
		return

	var shot := _bake_view.get_texture().get_image()
	shot.convert(Image.FORMAT_RGB8)
	_material.set_shader_parameter("terrain_tint",
		ImageTexture.create_from_image(shot))

	# La media del retrato, para tener el dato: es el color del valle, y es
	# contra ese número contra el que se juzga si la hierba casa.
	var mean := shot.duplicate() as Image
	mean.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	var soil := mean.get_pixel(0, 0)
	print("GroundCover: terreno fotografiado a %d px, color medio %.3f/%.3f/%.3f"
		% [BAKE_SIZE, soil.r, soil.g, soil.b])

	# Se deja una copia en disco. No es un resto de depuración: es el único modo
	# de comprobar de un vistazo que el retrato ha salido -si sale negro, la
	# hierba se tiñe de negro y desde dentro del juego no se distingue de un
	# problema de luz-.
	shot.save_png(BAKE_DUMP)

	_bake_view.queue_free()
	_bake_view = null


## Monta la rejilla. Una sola vez: lo que cambia por fotograma es un nodo.
func _build() -> void:
	if _node != null:
		_node.queue_free()

	# La separación sale de la densidad: una mata por celda.
	_spacing = 1.0 / sqrt(maxf(grass_density, 0.01))
	var half := int(ceil(grass_distance / _spacing))

	# Los puntos se recortan al CÍRCULO. Con el cuadrado entero sobrarían un
	# veintiún por ciento de instancias que el shader tendría que descartar de
	# todas formas, porque el fundido del borde es circular.
	var spots := PackedVector2Array()
	for row in range(-half, half + 1):
		for column in range(-half, half + 1):
			var spot := Vector2(float(column), float(row)) * _spacing
			if spot.length() > grass_distance:
				continue
			spots.append(spot)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _card_mesh()
	multi.instance_count = spots.size()
	for i in range(spots.size()):
		multi.set_instance_transform(i,
			Transform3D(Basis(), Vector3(spots[i].x, 0.0, spots[i].y)))

	_node = MultiMeshInstance3D.new()
	_node.name = "Alfombra"
	_node.multimesh = multi
	# La hierba no proyecta sombra. Lo que se ganaría es una maraña de sombritas
	# de diez centímetros que a distancia de juego no se lee, y se pagaría todo
	# el recorte con alfa otra vez en el pase de sombra. Sí RECIBE sombra, que
	# es lo que hace que un claro de bosque se note.
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La caja va a mano: las instancias están montadas en el plano, sin alturas
	# -las pone el shader-, así que la calculada sería una lámina y el motor
	# recortaría la alfombra en cuanto la cámara mirase desde abajo.
	_node.custom_aabb = AABB(
		Vector3(-grass_distance, -3000.0, -grass_distance),
		Vector3(grass_distance * 2.0, 6000.0, grass_distance * 2.0))
	_node.material_override = _material
	_material.set_shader_parameter("grass_radius", grass_distance)
	_material.set_shader_parameter("spacing", _spacing)
	add_child(_node)
	print("GroundCover: %d briznas, %d m de radio, %.1f por m2, %d triangulos" % [
		spots.size(), int(grass_distance), grass_density,
		spots.size() * multi.mesh.get_faces().size() / 3])


## El naipe: dos quads cruzados de pie y uno tumbado.
##
## El tumbado es la respuesta a que una lámina vertical, vista desde arriba, se
## ve DE CANTO y no tapa nada. La tentación es girar el naipe hacia el
## observador, y se probó: funciona y es peor, porque entonces la inclinación
## depende de dónde esté la cámara y al moverla GIRA TODA LA HIERBA A LA VEZ. Un
## quad tumbado y quieto tapa lo mismo y no se mueve nunca.
##
## Va marcado con el rojo del vértice a cero, y el shader lo usa para dos cosas:
## leerle el atlas cenital en vez del de perfil, y no aplicarle la sombra del
## pie -está a ras de suelo y quedaría negro justo en la vista para la que
## existe-.
func _card_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Cruzados a noventa grados: desde cualquier ángulo se ve al menos uno de
	# frente, que es lo que evita que la brizna desaparezca al girar la cámara.
	for quad in range(2):
		var angle := float(quad) * PI * 0.5
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.5
		var base := verts.size()
		verts.append_array([
			-side, side, side + Vector3.UP, -side + Vector3.UP])
		uvs.append_array([
			Vector2(0.0, 1.0), Vector2(1.0, 1.0),
			Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
		colors.append_array([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
		indices.append_array([
			base, base + 1, base + 2, base, base + 2, base + 3])

	# A un palmo del suelo -en talla de naipe-, no pegado: apoyado en la cota
	# exacta se pelea con el terreno y sale en zigzag.
	const LIFT := 0.12
	var flat_base := verts.size()
	verts.append_array([
		Vector3(-0.5, LIFT, -0.5), Vector3(0.5, LIFT, -0.5),
		Vector3(0.5, LIFT, 0.5), Vector3(-0.5, LIFT, 0.5)])
	uvs.append_array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	var flat := Color(0.0, 0.0, 0.0, 1.0)
	colors.append_array([flat, flat, flat, flat])
	indices.append_array([
		flat_base, flat_base + 1, flat_base + 2,
		flat_base, flat_base + 2, flat_base + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Todo el trabajo por fotograma: mover un nodo.
##
## Y se mueve REDONDEADO a la separación de la rejilla. Ése es el truco entero:
## como las briznas están en múltiplos de la separación respecto al nodo y el
## nodo también, cada una cae siempre en el mismo punto del mundo por mucho que
## la cámara se mueva. Sin redondear, la pradera repta bajo tus pies al andar y
## se nota al instante.
func _process(_delta: float) -> void:
	if _node == null or _terrain == null:
		return
	if _bake_view != null:
		_collect_albedo_bake()

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var eye := camera.global_position

	# Cuántos píxeles de pantalla ocupa un radián. Es lo que le permite al shader
	# saber si una brizna se ve o no, y por tanto si merece dibujarla.
	#
	# Sustituye al apagado por ALTURA DE CÁMARA, que estaba mal planteado: un
	# umbral en metros supone una forma de jugar, y aquí habrá quien juegue
	# pegado al suelo, quien juegue en modo gestión con la cámara arriba del todo
	# y mil posiciones en medio. Los píxeles valen para todas.
	#
	# Va por fotograma porque depende de la resolución de la ventana y del campo
	# de visión, y las dos pueden cambiar en marcha; el shader no tiene forma de
	# saberlas por su cuenta.
	var view_size := camera.get_viewport().get_visible_rect().size
	var span := view_size.y
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		span = view_size.x
	_material.set_shader_parameter("pixels_per_radian",
		span / maxf(2.0 * tan(deg_to_rad(camera.fov) * 0.5), 0.001))

	# El centro se corre hacia donde mira la cámara, pero sin soltarse de ella.
	#
	# Las dos mitades hacen falta. Centrar en la cámara a secas deja la alfombra
	# a la espalda del jugador cuando la órbita está lejos y alta. Y centrar en
	# el punto de mira a secas fue peor: a la altura de los ojos, mirando casi
	# horizontal, ese punto cae a cientos de metros y a tus pies no quedaba ni
	# una brizna.
	var focus := _look_point(camera)
	var offset := Vector2(focus.x - eye.x, focus.z - eye.z)
	# El tope es casi el radio entero, no la mitad.
	#
	# Con la mitad -que es lo que había, heredado de cuando el radio medía
	# noventa metros- el disco se quedaba a medio camino entre la cámara y lo que
	# se mira, y desde arriba eso se ve como hierba a un lado del río y ninguna al
	# otro. Lo único que este tope tiene que garantizar es que la CÁMARA siga
	# dentro del disco, para que a ras de suelo haya hierba en los pies; con 0,85
	# se cumple de sobra y el disco queda centrado en lo que estás mirando.
	var cap := grass_distance * 0.85
	if offset.length() > cap:
		offset = offset.normalized() * cap
	var centre := Vector2(eye.x, eye.z) + offset

	_node.global_position = Vector3(
		snappedf(centre.x, _spacing), 0.0, snappedf(centre.y, _spacing))


## A dónde mira la cámara, sobre el suelo. Unos pocos pasos contra la altura del
## terreno: no hace falta precisión, sólo saber dónde centrar la alfombra.
func _look_point(camera: Camera3D) -> Vector3:
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	if direction.y > -0.05:
		return origin
	var point := origin
	for step in range(16):
		var travel := (point.y - _terrain.get_height_at(point)) / -direction.y
		if absf(travel) < 0.5:
			break
		point += direction * clampf(travel, -400.0, 400.0)
	return point


## Cuántas briznas hay montadas. Para las sondas.
func live_instances() -> int:
	return _node.multimesh.instance_count if _node != null else 0
