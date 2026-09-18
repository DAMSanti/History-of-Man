class_name TerrainMaterialManager
extends RefCounted
## Gestiona el material del terreno con shader triplanar.
##
## Antes generaba cuatro texturas procedurales píxel a píxel y las ataba a ocho
## samplers sueltos. Ahora carga los tres [Texture2DArray] que deja
## `scripts/tools/TerrainTextureIngest.gd` —ocho capas de fotogrametría con
## albedo, normal y ORM— y sólo sigue generando las del agua, que son patrones
## que teselan y no fotografías.

## Dónde avisar si faltan los arrays. Se regeneran con la herramienta y no van
## al repositorio, así que en una copia recién clonada no están.
const MISSING_HINT := "Faltan las texturas del terreno. Genéralas con:\n" \
	+ "  godot --headless --path . --script res://scripts/tools/TerrainTextureIngest.gd"

var _material: ShaderMaterial
var _arrays: TerrainTextureArrays
var _water: Dictionary = {}

## Si el agua de este terreno sigue el ajuste «Agua». El del mapa regional no: se queda
## como el río de siempre (GRAFICOS §7.3, fuera de alcance). Ver
## [TerrainGenerator.agua_con_niveles].
var agua_con_niveles := true


## Crea el material del terreno con shader triplanar
func create_terrain_material() -> ShaderMaterial:
	_material = ShaderMaterial.new()

	var shader := load("res://shaders/triplanar.gdshader") as Shader
	if not shader:
		push_error("No se pudo cargar el shader triplanar")
		return null
	_material.shader = shader

	_load_arrays()
	_load_water_textures()
	_configure_shader_params()

	return _material


func _load_arrays() -> void:
	if not ResourceLoader.exists(TerrainLayers.ARRAYS_PATH):
		push_error(MISSING_HINT)
		return

	_arrays = load(TerrainLayers.ARRAYS_PATH) as TerrainTextureArrays
	if _arrays == null or not _arrays.is_usable():
		# Que el recurso exista no basta: puede ser de una ingesta anterior con
		# otro número de capas, y entonces los índices del shader apuntarían a
		# materiales cambiados de sitio.
		push_error("Las texturas del terreno no coinciden con %d capas. %s"
			% [TerrainLayers.COUNT, MISSING_HINT])
		_arrays = null
		return

	_material.set_shader_parameter("terrain_albedo", _arrays.albedo())
	_material.set_shader_parameter("terrain_normal", _arrays.normal())
	_material.set_shader_parameter("terrain_orm", _arrays.orm())
	_material.set_shader_parameter("layer_tile_m", TerrainLayers.tiles_in_order())
	_material.set_shader_parameter("layer_relieve", TerrainLayers.reliefs_in_order())
	_material.set_shader_parameter("layer_tint", TerrainLayers.tints_in_order())
	_material.set_shader_parameter("layer_saturation",
		TerrainLayers.saturations_in_order())

	print("Terreno: %d capas de %d px" % [_arrays.layers, _arrays.size])


## Las del agua siguen siendo procedurales, y con motivo: son patrones que
## tienen que teselar EXACTAMENTE y desfilar sobre el cauce, y eso se construye
## con senos de periodo entero. Una fotografía de agua no tesela sin costura.
func _load_water_textures() -> void:
	_water = ProceduralTextureGenerator.get_water_textures()
	if _water.has("water_normal"):
		_material.set_shader_parameter("water_normal_tex", _water["water_normal"])
	# La espuma ya no lleva textura: es ruido del shader (`espuma_viva.gdshaderinc`).


func _configure_shader_params() -> void:
	if not _material:
		return

	# Sharpness del blend entre materiales (más bajo = transiciones más suaves)
	_material.set_shader_parameter("blend_sharpness", 1.5)
	_material.set_shader_parameter("triplanar_sharpness", 2.5)

	# Configuración de alturas para el blend (valores normalizados 0-1)
	_material.set_shader_parameter("grass_max_height", 0.45)
	_material.set_shader_parameter("rock_min_height", 0.35)
	_material.set_shader_parameter("rock_max_height", 0.70)
	_material.set_shader_parameter("snow_min_height", 0.65)
	_material.set_shader_parameter("sand_max_height", 0.15)
	_material.set_shader_parameter("max_world_height", 30.0)

	# Configuración de pendiente - pendientes pronunciadas muestran más roca
	# `slope` es 1 - |normal.y|. Empezo en 0.55 -unos 63 grados, casi solo
	# cortados- y por eso no salia una piedra en ninguna ladera. Bajo a 0.26
	# (42 grados) y seguia siendo poco.
	#
	# Ahora 0.15 son unos 32 grados, que en terreno calizo es de sobra donde
	# aflora: por encima de esa pendiente el suelo no se sostiene. Y el blend
	# es ancho a proposito -0.20- para que la transicion sea un manto de
	# derrubio que va clareando, no una linea de nivel pintada en la ladera.
	#
	# Ese manto ya no es un degradado de color: entre el pasto y la pared hay
	# una capa propia, el CANCHAL, que sale de la mitad baja de este mismo
	# margen. Ver el reparto de pesos en el shader.
	# DÓNDE EMPIEZA EL DERRUBIO Y DÓNDE LA PARED, en `1 - |normal.y|`. Los cuatro números y
	# su porqué están en el shader; aquí se ponen los del juego. Antes eran un umbral de
	# 0,15 y un margen de 0,20, que dejaban medio canchal en una ladera de treinta grados.
	_material.set_shader_parameter("canchal_desde", 0.18)
	_material.set_shader_parameter("canchal_hasta", 0.43)
	# La caliza desde 40° y hasta 60°, con el canchal donde estaba (35-55°): así la peña se
	# come parte del derrubio y el resto del valle no cambia. Decisión del usuario del
	# 2026-09-18 sobre las cifras medidas: con lo de antes, el valle del sitio 56 daba
	# **2,4 % de canchal contra 0,2 % de caliza** —doce veces más derrubio que peña—.
	_material.set_shader_parameter("pared_desde", 0.23)
	_material.set_shader_parameter("pared_hasta", 0.50)

	# La rugosidad ya no es una constante por material: la trae el canal verde
	# del ORM. Aquí sólo queda el margen para retocarla en bloque.
	# Encendido o no según la configuración: es uno de sus ajustes sueltos
	# (INTERFAZ §8). Ver [aplicar_configuracion].
	aplicar_configuracion()
	_material.set_shader_parameter("roughness_scale", 1.0)
	_material.set_shader_parameter("ao_strength", 0.8)
	_material.set_shader_parameter("terrain_specular", 0.08)


## Los ajustes de gráficos que son del relieve: los mapas de normales, el ORM y el agua
## del cauce, que va pintada en el mismo shader. Se aplican en caliente: son uniformes.
func aplicar_configuracion() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("use_orm", bool(Configuracion.graficos["orm"]))
	_material.set_shader_parameter("use_normal_maps", bool(Configuracion.graficos["normales"]))
	# El escalón del agua del cauce: cada uno enciende lo suyo en el shader (GRAFICOS §7.3).
	_material.set_shader_parameter("nivel_de_agua",
		int(Configuracion.graficos.get("agua", 1)) if agua_con_niveles else 0)
	# EL RELIEVE DE LAS TEXTURAS: el canal de altura que ya estaba empaquetado y
	# que no leía nadie (GRAFICOS §4). Sólo en Alto y Ultra, ver
	# [Configuracion.pasos_de_relieve].
	_material.set_shader_parameter("relieve_pasos", Configuracion.pasos_de_relieve())
	# Y los umbrales de la espuma de rápido: una sola cifra, la de [AguaDelCauce].
	_material.set_shader_parameter("caida_de_rapido", AguaDelCauce.CAIDA_DE_RAPIDO)
	_material.set_shader_parameter("veces_para_romper", AguaDelCauce.VECES_PARA_ROMPER_ENTERA)
	_material.set_shader_parameter("linea_del_agua", AguaDelCauce.LINEA_DEL_AGUA)


## Obtiene el material
func get_material() -> ShaderMaterial:
	return _material


## Ajusta las bandas de altura del blend (valores normalizados 0-1).
## Los defaults estan pensados para terreno procedural; con elevacion real hay
## que recolocarlas o la arena se come media montana.
func set_height_bands(sand_max: float, grass_max: float, rock_min: float, rock_max: float, snow_min: float) -> void:
	if not _material:
		return
	_material.set_shader_parameter("sand_max_height", sand_max)
	_material.set_shader_parameter("grass_max_height", grass_max)
	_material.set_shader_parameter("rock_min_height", rock_min)
	_material.set_shader_parameter("rock_max_height", rock_max)
	_material.set_shader_parameter("snow_min_height", snow_min)


## LA COMARCA NO TIENE CANCHALES (decisión del usuario, 2026-09-18): «no puede haber
## canchales en la vista regional».
##
## El mapa regional usa el mismo shader que el valle, así que heredaba sus dos escalones de
## roca —derrubio y pared—. Pero **el derrubio es un detalle de ladera**: a 111 m por
## muestra no se distingue un canchal de una peña, y lo que se veía eran parches grises de
## canto suelto donde debería haber caliza.
##
## Lo que hace: **iguala el escalón del canchal al de la pared**, con lo que el peso del
## canchal —que es `scree − cliff`— sale cero en todas partes, y baja el umbral de la roca
## al que tenía el derrubio. La pendiente regional es más suave que la del valle —111 m por
## muestra promedian una ladera entera— así que con el umbral del valle no asomaría peña
## casi en ningún sitio.
func pintar_como_comarca() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("canchal_desde", 0.18)
	_material.set_shader_parameter("canchal_hasta", 0.43)
	_material.set_shader_parameter("pared_desde", 0.18)
	_material.set_shader_parameter("pared_hasta", 0.43)


## LA HUMEDAD DEL VALLE, que es lo que decide dónde hay bosque.
##
## Existe porque el suelo de bosque y los árboles **no se hablaban**: el shader pintaba
## bosque según la curvatura del terreno y un ruido macro suyos, y `Forest` siembra según
## este mapa de humedad, la pendiente y la cota. Eran dos criterios distintos, así que bajo
## un pinar el suelo podía estar pintado de pradera —y la hojarasca de otoño, que cuelga de
## esa capa, no aparecía—. Decisión del usuario del 2026-09-18: **manda la humedad, la
## misma que los árboles**. GRAFICOS §7.7.
func set_humedad(texture: Texture2D, world_size: Vector2, origen: Vector2) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("use_humedad", texture != null)
	_material.set_shader_parameter("humedad_tex", texture)
	_material.set_shader_parameter("humedad_extent", world_size)
	_material.set_shader_parameter("humedad_origen", origen)


## Activa el apagado del terreno fuera de la region jugable
func set_region_mask_enabled(enabled: bool) -> void:
	if _material:
		_material.set_shader_parameter("use_region_mask", enabled)


## Cambia la mascara de region. Barata: es solo cambiar la textura, asi que
## el area jugable puede seguir a la cota del mar sin rehacer la malla.
func set_region_mask_texture(texture: Texture2D, world_size: Vector2) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("region_mask_tex", texture)
	_material.set_shader_parameter("region_world_size", world_size)


## Actualiza la altura máxima del mundo en el shader
func set_max_world_height(height: float) -> void:
	if _material:
		_material.set_shader_parameter("max_world_height", height)


## Desde qué cota —en unidades de mundo— cuentan las bandas. Ver `cota_base` en
## `shaders/triplanar.gdshader`.
func set_cota_base(cota: float) -> void:
	if _material:
		_material.set_shader_parameter("cota_base", cota)


## Reescala las bandas por un factor.
##
## Sirve para subir el techo de normalizacion sin mover NADA de sitio: el
## shader compara `y / max_world_height` contra las bandas, asi que si el techo
## se multiplica por 1/k y las bandas por k, la misma cota absoluta sigue
## cayendo en la misma banda. Es lo que permite que el contorno -que llega mas
## alto que el recuadro- deje de saturar sin que el terreno jugable cambie de
## aspecto ni un pixel.
func scale_height_bands(k: float) -> void:
	if not _material or k <= 0.0:
		return
	for name: String in ["sand_max_height", "grass_max_height",
			"rock_min_height", "rock_max_height", "snow_min_height"]:
		var value: float = _material.get_shader_parameter(name)
		_material.set_shader_parameter(name, value * k)


## Mueve SOLO la cota de nieve, sin tocar las demas bandas.
##
## Existe aparte de `set_height_bands` porque la nieve es lo unico que cambia
## con el calendario: las otras cuatro bandas describen de que esta hecho el
## monte y no se mueven en todo el año. Ver [Temporada].
func set_snow_line(snow_min: float) -> void:
	if _material:
		_material.set_shader_parameter("snow_min_height", snow_min)


## Vuelve a graduar el color de las capas VIVAS con el tinte de la estacion.
##
## Barato: es un array de ocho vec3 al shader, no una textura. Se puede llamar
## una vez por jornada sin pensarlo. Ver [TerrainLayers.tints_in_order_tinted].
func set_season_tint(estacional: Color) -> void:
	if _material:
		_material.set_shader_parameter("layer_tint",
			TerrainLayers.tints_in_order_tinted(estacional))
