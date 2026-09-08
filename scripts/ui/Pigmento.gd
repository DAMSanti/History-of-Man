class_name Pigmento
extends RefCounted
## Ocre y carbon: no un color, un material.
##
## La interfaz del Paleolitico esta ESCRITA, no impresa. Aqui viven las tres
## piezas que hacen falta para eso y que no son de ninguna ventana en concreto:
##
##   - la letra, que es una manuscrita de verdad y no una tipografia de pantalla
##   - el grano del soporte, que es donde se mete el pigmento
##   - los dos pigmentos, ocre y carbon, con su comportamiento distinto
##
## La diferencia entre los dos no es el tono: es COMO se pintan. El ocre se
## amasa con grasa y cubre; el carbon es seco, se posa en el relieve del poro y
## salta a nada que la piel este alta. Eso lo hace el sombreador -ver
## `shaders/pigmento.gdshader`-, no un color con alfa.
##
## Ver docs/INTERFAZ.md.

const RUTA_SHADER := "res://shaders/pigmento.gdshader"
const RUTA_LETRA := "res://fonts/Caveat.ttf"

## Lado de la textura de grano, en pixeles. Manda el tamano del poro: mas
## pequeno y el trazo parece sucio, mas grande y parece manchado.
const LADO := 160

## Semilla del grano. Fija, porque la piel de la ventana tiene que ser la misma
## en cada arranque: si cambia entre partidas, la interfaz «parpadea» de aspecto
## sin que nadie haya tocado nada.
const SEMILLA := 20260908


## El grano del soporte, generado una vez.
##
## Va con [FastNoiseLite] y no con ruido blanco a mano porque el poro de una
## piel tiene TAMANO: el ruido blanco a un pixel se ve como suciedad de pantalla
## y no como material.
static var _grano: ImageTexture = null

static func grano() -> ImageTexture:
	if _grano != null:
		return _grano
	var ruido := FastNoiseLite.new()
	ruido.seed = SEMILLA
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Un poro de piel mide milimetros, no centimetros. Con 0,028 el periodo
	# salia de treinta y seis texeles -en pantalla, manchas de setenta pixeles-
	# y la ventana parecia llena de humo. Ver la captura de la primera version.
	ruido.frequency = 0.14
	ruido.fractal_octaves = 4
	ruido.fractal_gain = 0.5
	# Sin costura: el grano se repite por toda la pantalla y una junta visible
	# delataria el truco en cuanto la ventana pasara de ciento sesenta pixeles.
	var img := ruido.get_seamless_image(LADO, LADO, false, false)
	img.convert(Image.FORMAT_RGBA8)
	_grano = ImageTexture.create_from_image(img)
	return _grano


## La letra manuscrita.
##
## Caveat, con licencia SIL OFL -ver `fonts/Caveat-OFL.txt`-, que es lo que
## permite redistribuirla con el juego. Se eligio entre las manuscritas por lo
## unico que importa aqui: se lee a doce pixeles. Las que parecen mas «de
## cueva» -las de trazo muy roto- no se leen, y una interfaz que no se lee no
## es un estilo, es un fallo.
##
## Si falta el fichero se devuelve `null` y quien la pida se queda con la letra
## de serie: la ventana se ve peor pero se ve.
static var _letra: FontFile = null
static var _letra_buscada := false

static func letra() -> FontFile:
	if _letra_buscada:
		return _letra
	_letra_buscada = true
	if not ResourceLoader.exists(RUTA_LETRA):
		push_warning("Falta %s: la interfaz sale con la letra de serie." % RUTA_LETRA)
		return null
	_letra = load(RUTA_LETRA) as FontFile
	return _letra


## Los pigmentos, uno por receta. Se cachean porque un [ShaderMaterial] por
## etiqueta serian cientos de materiales para tres comportamientos distintos.
static var _pigmentos: Dictionary = {}


## Ocre: amasado con grasa, cubre. Es el pigmento de lo que importa.
static func ocre() -> ShaderMaterial:
	return _pigmento("ocre", 0.42, 0.20, 0.30)


## Carbon: seco, se posa en el relieve y salta. Es el de lo secundario, y que
## se rompa mas no es un defecto: es lo que lo manda al segundo plano.
static func carbon() -> ShaderMaterial:
	return _pigmento("carbon", 0.72, 0.04, 0.45)


## Trazo macizo, para lineas y flechas: el mismo grano, pero sin comerse el
## borde. Una linea de un pixel con mordiente se queda en nada.
static func trazo() -> ShaderMaterial:
	return _pigmento("trazo", 0.22, 0.30, 0.28)


static func _pigmento(nombre: String, mordiente: float, carga: float,
		veteado: float) -> ShaderMaterial:
	if _pigmentos.has(nombre):
		return _pigmentos[nombre]
	var shader := load(RUTA_SHADER) as Shader
	if shader == null:
		push_warning("Falta %s: no hay pigmento." % RUTA_SHADER)
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("grano", grano())
	mat.set_shader_parameter("lado", float(LADO))
	mat.set_shader_parameter("mordiente", mordiente)
	mat.set_shader_parameter("carga", carga)
	mat.set_shader_parameter("veteado", veteado)
	_pigmentos[nombre] = mat
	return mat


## Escribe una etiqueta con la letra y el pigmento de la era.
##
## Es el unico sitio donde se decide el tamano: la manuscrita tiene la caja mas
## baja que una tipografia de pantalla, asi que TODO va dos o tres puntos por
## encima de lo que iria con la letra de serie. Poner el mismo cuerpo que en las
## otras ventanas y esperar que se lea es el error clasico al meter una
## manuscrita.
static func escribir(label: Label, tinta: Color, tamano: int,
		pigmento: ShaderMaterial = null) -> void:
	var fuente := letra()
	if fuente != null:
		label.add_theme_font_override("font", fuente)
	label.add_theme_font_size_override("font_size", tamano)
	label.add_theme_color_override("font_color", tinta)
	# La manuscrita trae la caja MUY alta -los rasgos suben y bajan mucho- y con
	# el interlineado de serie un parrafo de dos lineas se abria un dedo. Se
	# aprieta en proporcion al cuerpo.
	label.add_theme_constant_override("line_spacing", -int(round(tamano * 0.28)))
	label.material = pigmento if pigmento != null else ocre()


## Lo mismo para un boton, que no comparte las anulaciones de tema con [Label].
static func escribir_boton(button: Button, tinta: Color, tamano: int) -> void:
	var fuente := letra()
	if fuente != null:
		button.add_theme_font_override("font", fuente)
	button.add_theme_font_size_override("font_size", tamano)
	button.add_theme_color_override("font_color", tinta)
	button.add_theme_color_override("font_hover_color", tinta.lightened(0.25))
	button.add_theme_color_override("font_pressed_color", tinta)
