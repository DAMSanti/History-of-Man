class_name Forest
extends Node3D
## El bosque: todos los árboles del valle, en dos cuerpos según la distancia.
##
## Los árboles son el caso contrario a la hierba y a los props, y por eso no
## comparten sistema. Aquéllos son detalle: se generan alrededor de la cámara
## porque a doscientos metros no se leen. Un bosque no: es un rasgo del paisaje,
## se ve desde cualquier altura de cámara y cubre laderas enteras. Hay que
## tenerlos TODOS, del pie de la cueva al borde del valle.
##
## Con geometría eso no se sostiene, y el número lo dice: el pino escaneado de
## Poly Haven trae diecisiete millones de triángulos, y ni siquiera se le pueden
## generar niveles de detalle —Godot lo rechaza, «mesh is too complex»—. Aunque
## se pudiera, decenas de miles de árboles con malla no caben en ningún
## fotograma.
##
## La salida son DOS CUERPOS para el mismo árbol:
##
##   - de cerca, la malla de verdad con sus niveles de detalle, en bloques
##     alrededor de la cámara;
##   - de lejos, un IMPOSTOR: un cuadrado con la foto del propio árbol, dos
##     triángulos, sembrado por todo el mapa.
##
## Treinta mil impostores son sesenta mil triángulos. Y como la foto se hornea
## del mismo modelo que se usa de cerca —ver `scripts/tools/TreeAtlas.gd`—, el
## relevo entre los dos no cambia de especie a medio camino.
##
## El reparto por especies sale del terreno, no de un ruido suelto: pinar en
## ladera de umbría, abedular en las vaguadas húmedas, troncos secos en la
## estepa expuesta. Es el bosque de refugio del Magdaleniense cantábrico, que no
## es el de hoy.

## Cada cuánto se prueba a poner un árbol, en metros. NO es la separación entre
## árboles: es la malla de candidatos, y de cada uno sale árbol o no según el
## terreno y la mancha de bosque.
## Once metros daban un arbolado de sabana y seis y medio seguía saliendo ralo.
## Un pinar cerrado tiene los pies a cinco metros, y ésa es la malla de
## candidatos: lo que decide si sale bosque o claro es la mancha, no el paso.
## Cada cuántos metros se prueba un candidato a árbol.
##
## Era cinco, y con ello el valle salía a doscientos mil árboles en cuatro
## kilómetros cuadrados: un arbolado ralo por el que se ve el suelo entero. Un
## bosque de refugio cantábrico del Magdaleniense no se parece a eso.
##
## Tres metros: un candidato cada tres metros sobre los cuatro kilómetros del
## valle, o sea 1,8 millones de tiradas. Es lo que cuesta un bosque que se vea
## como un bosque, y se paga UNA VEZ al arrancar —el terreno no cambia, así que
## los árboles tampoco—, no por fotograma.
const SPACING := 3.0

## Lado de la tesela de impostores, en metros. Grande, porque un impostor
## cuesta dos triángulos y lo que importa es que el motor pueda descartar
## teselas enteras por frustum.
const TILE_M := 512.0

## Lado del bloque de malla real alrededor de la cámara.
const BLOCK_M := 128.0

## Cuántos bloques de malla de verdad se montan por fotograma. Ver `_process`.
const BLOCKS_PER_FRAME := 12

const ATLAS_PATH := "res://models/props/arbol_atlas.res"
const IMPOSTOR_SHADER := "res://shaders/arbol_impostor.gdshader"

## Cuántas celdas por lado tiene el atlas de impostores. Debe coincidir con
## `TreeAtlas.GRID`.
##
## Tres y no dos porque ahora hay DOS fotos por especie: de perfil y desde
## arriba. Las tres primeras celdas son los perfiles, en el orden de `KINDS`, y
## las tres siguientes las copas vistas de pájaro. Ver `TreeAtlas.gd`.
## Lado del atlas en celdas.
##
## CUATRO desde que el bosque tiene cinco especies: van los cinco perfiles y
## las cinco copas cenitales, o sea diez celdas, y en una rejilla de tres sólo
## caben nueve. Si se añade una sexta especie hay que subirlo otra vez y
## rehornear con `TreeAtlas.gd`.
const ATLAS_GRID := 4

## Los tipos de bosque, en el orden en que se fotografían para el atlas.
##
## El orden ES el de las celdas del atlas y el de `TreeAtlas.PICKS`: no se
## reordena sin volver a hornear.
##
## Cada uno lleva su hábitat, y ahí está el contenido histórico del asunto. El
## Magdaleniense cantábrico —hace quince mil años— es estepa fría con bosque de
## refugio metido en los valles encajados: pino albar y abedul donde hay abrigo
## y humedad, nada en lo alto y lo expuesto, y troncos secos en pie por la
## estepa. No es el bosque atlántico de hoy y no debe parecerlo.
## EL ORDEN IMPORTA, y no es el del atlas: un candidato da un solo árbol, así
## que el bucle corta al primer acierto y la especie que va delante se lleva todo
## lo que compartan. Con el pinar primero, el abedul se quedaba en 2.575 árboles
## contra 157.789 —la hoja caduca no se veía— porque los dos pinos se llevaban la
## franja de humedad 0,58 a 0,88, que es justo donde crece el abedul.
##
## Va delante la especie de nicho MÁS ESTRECHO: la que sólo puede estar en un
## sitio lo reclama primero, y la de nicho ancho ocupa lo que queda, que es lo
## que hace la competencia de verdad en un bosque.
## Qué le hace el año a cada árbol.
##
## `tinte` gradúa el color y `hoja` es cuánta le queda, de 0 a 1. Las dos filas
## no son un gusto: son la diferencia entre un perennifolio y un caducifolio,
## que es la única que se ve de verdad en un bosque cantábrico.
##
##   PINO     apenas cambia. Un pino en enero es un pino en agosto un poco más
##            oscuro, y NO pierde la hoja: la muda poco a poco todo el año.
##   ABEDUL   verde tierno en primavera, verde hecho en verano, AMARILLO en
##            octubre y desnudo de noviembre a marzo. Es de los primeros en
##            perderla y de los últimos en echarla.
##
## Lo que decide cuál de las dos filas se usa es `caduco` en [KINDS].
const PERENNE := {
	Subsistence.Season.PRIMAVERA: {"tinte": Color(0.94, 1.04, 0.92), "hoja": 1.0},
	Subsistence.Season.VERANO: {"tinte": Color(1.00, 1.00, 0.94), "hoja": 1.0},
	Subsistence.Season.OTONO: {"tinte": Color(0.96, 0.94, 0.86), "hoja": 1.0},
	Subsistence.Season.INVIERNO: {"tinte": Color(0.82, 0.86, 0.86), "hoja": 1.0},
}

const CADUCO := {
	Subsistence.Season.PRIMAVERA: {"tinte": Color(0.88, 1.10, 0.78), "hoja": 0.85},
	Subsistence.Season.VERANO: {"tinte": Color(0.96, 1.02, 0.82), "hoja": 1.0},
	# El amarillo del abedular en octubre es de las cosas que más se ven de un
	# valle cantábrico desde lejos, y ya empieza a clarear.
	Subsistence.Season.OTONO: {"tinte": Color(1.30, 1.02, 0.42), "hoja": 0.55},
	Subsistence.Season.INVIERNO: {"tinte": Color(0.90, 0.86, 0.80), "hoja": 0.05},
}


## EL COLOR DE CADA ESPECIE, medido contra fotos. GRAFICOS §7.1.
##
## Las texturas de hoja y corteza vienen de ambientCG, y su color no es el del árbol de
## aquí: medidas con la luz del juego a mediodía, las copas salían verde azulado
## —a* ≈ −25 contra −11 a −15 de las fotos— y la corteza del pino sin su naranja. Estos
## tintes llevan la media a la de `models/arboles/color_de_referencia.json`.
##
##   copa      la hoja en verano
##   otono     la hoja en otoño, sólo los caducos: un tinte que multiplica el verde
##             no llega nunca a amarillo, así que el otoño se mide aparte
##   corteza   el tronco, todo el año
##   impostor  la luz del impostor de varias vistas contra el 3D, por canal: la sombra
##             que la copa se hace a sí misma y la foto horneada no tiene. Y
##             `impostor_otono`: con la hoja cayendo, el 3D y el impostor la quitan distinto
##   minimo    la lámina del escalón Mínimo en verano, y `minimo_otono`: otra
##             textura, otra cuenta. Sobre la lámina dividida por su brillo medio
##   rama      lo que queda de un caduco de Mínimo en invierno, contra su corteza
##
## Salen de `ArbolColorProbe` con CALIBRAR=1, que itera el tinte contra la foto, y se
## verifican sin él. Las otras estaciones no tienen foto: siguen la forma del año de
## [PERENNE] y [CADUCO] a partir de la que sí la tiene.
const COLOR_DE_ESPECIE := {
	"pino": {
		"copa": Color(1.301, 1.359, 0.871),
		"corteza": Color(1.510, 1.084, 0.827),
		"impostor": Vector3(0.706, 0.692, 1.163),
		"minimo": Color(0.936, 0.929, 0.611),
	},
	"pino_joven": {
		"copa": Color(1.245, 1.305, 0.846),
		"corteza": Color(1.459, 1.041, 0.796),
		"impostor": Vector3(0.797, 0.793, 1.223),
		"minimo": Color(0.892, 0.861, 0.581),
	},
	"abedul": {
		"copa": Color(1.690, 1.712, 0.898),
		"otono": Color(2.049, 1.710, 0.989),
		"corteza": Color(1.085, 1.006, 0.874),
		"impostor": Vector3(0.607, 0.593, 0.968),
		"impostor_otono": Vector3(0.471, 0.444, 0.885),
		"minimo": Color(0.984, 0.982, 0.586),
		"minimo_otono": Color(1.193, 0.976, 0.381),
		"rama": Color(1.210, 1.176, 1.164),
	},
	"roble": {
		"copa": Color(0.820, 0.844, 0.402),
		"otono": Color(1.118, 0.864, 0.010),
		"corteza": Color(1.233, 1.029, 0.775),
		"impostor": Vector3(0.668, 0.714, 1.077),
		"impostor_otono": Vector3(0.633, 0.513, 3.590),
		"minimo": Color(0.958, 0.928, 0.532),
		"minimo_otono": Color(1.349, 1.023, 0.010),
		"rama": Color(0.909, 0.808, 0.722),
	},
	"avellano": {
		"copa": Color(0.848, 1.023, 0.550),
		"otono": Color(1.090, 0.859, 0.244),
		"corteza": Color(0.893, 0.790, 0.639),
		"impostor": Vector3(0.686, 0.761, 0.877),
		"impostor_otono": Vector3(0.708, 0.693, 1.459),
		"minimo": Color(0.843, 0.986, 0.542),
		"minimo_otono": Color(1.162, 0.959, 0.065),
		"rama": Color(0.800, 0.718, 0.685),
	},
}


const KINDS: Array[Dictionary] = [
	{
		# Abedular de vaguada: hoja caduca en lo hondo y húmedo. Es la otra
		# silueta del bosque —copa redonda contra la punta del pino— y por eso
		# importa que salga en sitios distintos y no mezclado al azar.
		"model": "abedul", "cell": 2, "name": "Abedular",
		"slope": Vector2(0.0, 0.38), "humidity": Vector2(0.50, 1.0),
		"height": Vector2(0.0, 0.52), "chance": 0.95,
		# CADUCO. Es la única de las tres, y por eso el bosque cambia de forma
		# con el año en vez de sólo cambiar de color: en enero la vaguada se
		# queda pelada y la ladera de pinos sigue verde. Ver [POR_ESTACION].
		"caduco": true,
	},
	{
		# EL ROBLEDAL, que es de donde sale la bellota. La banda llevaba
		# recogiéndola —y desde el desamargado, comiéndola— de un árbol que no
		# existía en el valle: sólo había pino, pino joven y abedul.
		#
		# Va en la ladera baja y soleada, que es donde está: el roble quiere más
		# calor que el abedul de la vaguada y menos altura que el pinar.
		"model": "roble", "cell": 3, "name": "Robledal",
		"slope": Vector2(0.02, 0.42), "humidity": Vector2(0.34, 0.70),
		"height": Vector2(0.02, 0.40), "chance": 0.55,
		"caduco": true,
	},
	{
		# Y EL AVELLANAR, que es de lo que vive la banda: seis mil raciones de
		# fruto seco al año salían de un árbol que tampoco estaba.
		#
		# Va en el borde húmedo, que es donde crece el avellano cantábrico: en
		# la orla del bosque y en la vaguada, en mata de varios pies.
		"model": "avellano", "cell": 4, "name": "Avellanar",
		"slope": Vector2(0.0, 0.34), "humidity": Vector2(0.46, 0.92),
		"height": Vector2(0.0, 0.36), "chance": 0.60,
		"caduco": true,
	},
	{
		# Pinar de umbría: la masa principal del bosque de refugio. Ladera con
		# algo de pendiente, humedad media y cota media: ni la vega encharcada
		# ni la cumbre pelada.
		#
		# El techo de humedad baja de 0,88 a 0,78: por encima de eso la vaguada
		# es del abedul, y dejándoselo al pino el abedular no existía.
		"model": "pino", "cell": 0, "name": "Pinar",
		"slope": Vector2(0.04, 0.55), "humidity": Vector2(0.32, 0.78),
		"height": Vector2(0.10, 0.68), "chance": 0.95,
	},
	{
		# Pino joven: rellena el borde del pinar y le da escalones de altura,
		# que es lo que hace que una masa de árboles no parezca un sello
		# repetido.
		"model": "pino_joven", "cell": 1, "name": "Pinar joven",
		"slope": Vector2(0.02, 0.62), "humidity": Vector2(0.28, 0.82),
		"height": Vector2(0.06, 0.72), "chance": 0.70,
	},
]

## Hasta dónde se dibuja la malla de verdad alrededor de la cámara, en metros.
## Más allá se ve el impostor, en un corte duro -ver `arbol_impostor.gdshader`-
## y no en un desvanecido: el mismo radio para todo el bosque a la vez.
##
## Ciento treinta se fijó a ojo y no llegaba: en un mapa de verdad el zoom más
## cercano de la cámara de juego no baja de unos 300 m de órbita, y el punto de
## suelo más próximo que cae en pantalla -el borde inferior de la vista- varía
## con el ángulo de cámara entre 15 y 183 m según medido con `ArbolBordeProbe`.
## Con el corte en 130, un ángulo intermedio (entre -45 y -65 grados, uno
## cualquiera de los que se alcanzan simplemente inclinando la cámara mientras
## se hace zoom) lo cruzaba EN PANTALLA: el radio de relevo pasaba por en medio
## del bosque de primer plano, justo en la parte baja de la cámara.
##
## Trescientos dejaba el corte por encima de los 183 m del peor caso medido...
## pero el zoom más cercano de la cámara estaba TAMBIÉN en 300 m de órbita, así
## que todo el bosque quedaba siempre al otro lado del corte y todo eran
## impostores. Ahora la cámara baja hasta unos 57 m, así que con 350 m de corte
## hay malla de verdad en TODO lo que se ve al acercarse -y bastante más allá-,
## que es donde se mira cuando uno se acerca. Subirlo a 700 se probó y no sale a
## cuenta: la malla de cerca proyecta sombra, y cuadruplicar su superficie
## cuadruplica el coste de sombra sin que se vea un árbol más en pantalla.
@export var near_distance := 350.0

## Cuánto bosque hay. Uno es lo pensado; medio deja el valle más abierto.
@export var density := 1.0

## Cómo de grandes son las manchas de bosque, en metros.
##
## Un bosque no se reparte, hace MASA: hay ladera de pinar y ladera pelada, y el
## borde entre las dos es lo que se lee como paisaje. Sin esto, aplicando sólo
## el hábitat, sale una nube de árboles sueltos de densidad uniforme por todo lo
## que cumple las condiciones, que es exactamente como no es un bosque.
@export var stand_size := 240.0

var _terrain: TerrainGenerator
var _library: PropLibrary
var _atlas: ImageTexture

## Especie -> tesela -> transformaciones. Es TODO el bosque, y se calcula una
## vez: el terreno no cambia, así que los árboles tampoco.
var _stands: Array[Dictionary] = []

## La talla de cada especie: alto real y ancho del impostor.
var _sizes: Array[Vector2] = []

## Los bloques de malla real que hay montados ahora mismo.
var _live: Dictionary = {}
var _pending: Array[Vector2i] = []
var _centre := Vector2i(999999, 999999)

## El naipe cruzado del árbol de cerca y su material por especie.
var _crossed: ArrayMesh
## El brillo medio de cada celda del atlas de Mínimo. Ver `brillo_de_celdas`.
var _brillo_de_celda := PackedFloat32Array()
var _near_material: Array[ShaderMaterial] = []

## El material del impostor de cada especie. Es UNO por especie y lo comparten
## todas sus teselas, asi que teñir el bosque entero es tocar tres materiales.
var _far_material: Array[ShaderMaterial] = []

var _total := 0

## Lo que decide la siembra, hasta aquí. Se sube al cambiar CÓMO se siembra —las reglas de
## [_sow], `KINDS`, `SPACING`—, que no sale en ningún número de lo que se guarda: sin
## subirla, la vuelta al valle enseñaría el bosque de las reglas viejas.
const VERSION_DE_LA_SIEMBRA := 1

## La última siembra, con la huella de lo que la decidió. Volver al mismo valle —ir al
## regional y volver, retomar el campamento— sembraba otra vez los mismos árboles, 9-14 s
## (INTERFAZ §9). Es UNA, la del último valle: guardar las de todos los valles sería un
## millón de árboles por valle en memoria. Vive lo que vive el proceso; abrir el juego
## otra vez siembra.
static var _siembra_guardada: Dictionary = {}

## Cuántas veces se ha sembrado de verdad en este proceso. Lo lee la sonda del tránsito
## para decir que la vuelta no sembró.
static var siembras := 0


# --- los escalones (GRAFICOS §7.1, 2026-09-15) ------------------------------------

## El escalón de árboles: 0 Mínimo, 1 Medio, 2 Alto, 3 Ultra. Lo pone la
## configuración al montar el mapa (INTERFAZ §8.7).
##
## **Mínimo es el bosque de siempre** —tarjetas cruzadas y una foto—, por el mismo
## camino de código. Los otros tres ponen árboles 3D de cerca e impostores de varias
## vistas de lejos.
var escalon := 0

## Hasta dónde llega el 3D, en metros desde la cámara. Sale de la configuración
## (`Configuracion.graficos["radio_3d"]`, donde están las cifras medidas) al montar, y
## se cambia en caliente con [aplicar_configuracion].
var radio_3d := 40.0

## Hasta dónde se reparte el nivel de detalle del 3D, por escalón: con el slider en
## «sin límite», repartir los niveles sobre 100 km dejaba todo el valle en el nivel 0.
const DETALLE_HASTA := [0.0, 40.0, 70.0, 120.0]

## Hasta dónde mezcla el impostor sus cuatro vistas, por escalón; más lejos lee la más
## cercana. Medido en la vista de medida, bosque de Medio, dos vueltas: mezclando
## siempre 7,0-7,3 ms; hasta 300 m, 4,7-4,8; hasta 150, 3,2-3,4; sin mezclar, 3,2-3,3.
## Medio a 150 m cabe en lo que el usuario dio por bueno —3,8 ms en vez de 3,0—; Alto va
## por encima y Ultra no tiene límite (GRAFICOS §7).
const MEZCLA_HASTA := [0.0, 150.0, 300.0, 1.0e6]

## Lado del bloque de cerca en 3D, en metros. **32 y no los 128 de las tarjetas**: el
## nivel de detalle y el desvanecido se eligen por bloque, y con radios de decenas de
## metros un bloque de 128 lo metía todo en el nivel 0.
const BLOQUE_3D_M := 32.0


## Dónde empieza cada nivel de detalle, en fracción del radio del 3D.
const NIVELES_DESDE := [0.0, 0.25, 0.55]

## Cuántas variantes hay de cada especie. Ver `scripts/tools/arboles/generar.mjs`.
const VARIANTES := 6

const SHADER_3D := "res://shaders/arbol_3d.gdshader"
const SHADER_VISTAS := "res://shaders/arbol_impostor_vistas.gdshader"

## Especie -> variante -> [ArbolModelo].
var _modelos: Array = []
## Especie -> [corteza, hoja]: los materiales 3D, compartidos por sus variantes.
var _mat_3d: Array = []
## Especie -> el material del impostor de varias vistas.
var _mat_vistas: Array[ShaderMaterial] = []


## La variante de un pie, fija por su sitio: el mismo árbol es la misma variante en
## el 3D, en el impostor y en la próxima partida.
static func variante_de(sitio: Vector3) -> int:
	return posmod(hash(Vector2i(roundi(sitio.x * 10.0), roundi(sitio.z * 10.0))), VARIANTES)


## Lado del bloque de cerca del escalón.
func lado_de_bloque() -> float:
	return BLOCK_M if escalon <= 0 else BLOQUE_3D_M


## Hasta dónde se montan bloques de cerca: el de las tarjetas en Mínimo, el del 3D en
## los demás.
func radio_de_cerca() -> float:
	return near_distance if escalon <= 0 else radio_3d


## Cuánto se deja sin árboles alrededor de cada boca de cueva, en metros.
##
## **Decisión del usuario del 2026-09-13**: «la entrada de las cuevas tiene que
## estar libre de árboles, por lo menos 25 m alrededor», y de todas las bocas
## del mapa, no sólo la de la banda. Antes el bosque se sembraba por ruido y
## sólo esquivaba el agua, así que plantaba pinos encima de la boca y de las
## obras de la campa.
const RADIO_DEL_CLARO := 25.0

## Las bocas de cueva del mapa, alrededor de las cuales no se siembra. Las pone
## [DemoMain] antes de `setup`, que es cuando se siembra.
var claros: PackedVector3Array = PackedVector3Array()


## Si ese punto cae en el claro de alguna boca. En planta: la altura no cuenta,
## que una boca en la ladera tiene el árbol de arriba a la misma distancia.
static func en_un_claro(punto: Vector3, bocas: PackedVector3Array,
		radio: float = RADIO_DEL_CLARO) -> bool:
	for boca: Vector3 in bocas:
		if Vector2(punto.x - boca.x, punto.z - boca.z).length() < radio:
			return true
	return false


func setup(terrain: TerrainGenerator) -> void:
	_terrain = terrain
	# La densidad es un ajuste de la configuración (INTERFAZ §8), y entra AL
	# SEMBRAR, que es al montar el mapa: rehacer la siembra en caliente congela la
	# pantalla unos 10 s (medido, GRAFICOS §7). Ver [resembrar].
	density = float(Configuracion.graficos["vegetacion"])
	if not ResourceLoader.exists(PropModels.LIBRARY_PATH):
		push_warning("Faltan los modelos. Generalos con PropIngest.")
		return
	_library = await Carga.cargar(PropModels.LIBRARY_PATH) as PropLibrary
	if _library == null:
		return

	var image: Image = await Carga.cargar(ATLAS_PATH) as Image if ResourceLoader.exists(ATLAS_PATH) \
		else null
	await Carga.ceder()
	if image != null:
		if image.is_compressed():
			image.decompress()
		_brillo_de_celda = brillo_de_celdas(image, ATLAS_GRID)
		await Carga.ceder()
		image.generate_mipmaps()
		_atlas = ImageTexture.create_from_image(image)
		print("Forest: atlas %dx%d, %d celdas por lado" % [
			image.get_width(), image.get_height(), ATLAS_GRID])
	else:
		push_warning("Falta el atlas de arboles. Hornealo con:\n"
			+ "  godot --path . --script res://scripts/tools/TreeAtlas.gd")

	escalon = clampi(int(Configuracion.graficos.get("arboles", 0)), 0, MEZCLA_HASTA.size() - 1)
	radio_3d = maxf(float(Configuracion.graficos.get("radio_3d", DETALLE_HASTA[maxi(escalon, 1)])), 1.0)
	add_to_group(Configuracion.GRUPO)
	_measure()
	await _sow()


## Los árboles de lejos, ya sembrado el bosque. Va aparte de [setup] para que quien monta
## la escena lo enseñe como otra etapa de la carga: son 3-5 s de cargar modelos e
## impostores contra los 14 de sembrar (INTERFAZ §9).
func levantar_lejos() -> void:
	await _levantar_lejos()


## Los árboles de lejos del escalón que toque.
func _levantar_lejos() -> void:
	if escalon <= 0 or not await _cargar_modelos():
		escalon = 0
		_raise_impostors()
		return
	await _raise_impostors_vistas()


## Siembra otra vez con otra densidad: se quitan los árboles de cerca y los
## impostores y se rehacen. **No lo usa la configuración**, que deja la densidad
## para el próximo mapa: medido con `GpuProfile NIVELES=1`, tarda **unos 10 s**
## con el fotograma parado. Lo usa esa sonda para medir lo que cuesta cada valor.
func resembrar(nueva: float) -> void:
	if is_equal_approx(nueva, density) or _terrain == null or _library == null:
		return
	density = nueva
	for hijo: Node in get_children():
		hijo.queue_free()
	_live.clear()
	_pending.clear()
	_centre = Vector2i(999999, 999999)
	await _sow()
	await _levantar_lejos()


## La talla de cada especie, sacada de su propia malla.
##
## El ancho del impostor NO es un número a mano: sale de la proporción real del
## árbol. Con un cuadrado, un pino estrecho saldría gordo y un abedul redondo
## saldría estirado, y eso se nota en cuanto hay dos especies juntas.
func _measure() -> void:
	_sizes.clear()
	for kind: Dictionary in KINDS:
		var key: String = kind["model"]
		if _library == null or not _library.has(key):
			_sizes.append(Vector2(4.0, 3.0))
			continue
		var mesh := _library.mesh(key, 0)
		var factor := _library.scale_for(key)
		var box := mesh.get_aabb()
		var tall := box.size.y * factor
		var wide := maxf(box.size.x, box.size.z) * factor
		_sizes.append(Vector2(maxf(wide, 0.2), maxf(tall, 0.5)))


## Siembra el bosque entero, una vez.
##
## Se recorre una malla de candidatos sobre todo el mapa y en cada uno se
## pregunta al terreno. Las consultas van a los MAPAS EN CRUDO y no a
## `get_height_at` y compañía: son ciento cuarenta mil candidatos, y a cuatro
## llamadas cada uno eso es medio millón de llamadas de script cuando lo que
## hace falta es leer cuatro posiciones de un array.
func _sow() -> void:
	var maps := _terrain.sample_maps()
	var res: int = maps["resolution"]
	var height: PackedFloat32Array = maps["height"]
	if res <= 1 or height.is_empty():
		return
	var humidity: PackedFloat32Array = maps["humidity"]
	var river: PackedFloat32Array = maps["river"]
	var extent: Vector2 = maps["extent"]
	_extension = extent
	var origin: Vector2 = maps["origin"]
	var water_y: float = maps["water_y"]
	var spacing := extent.x / float(res - 1)

	var huella := huella_de_la_siembra(maps)
	if _siembra_guardada.get("huella", 0) == huella and not _siembra_guardada.is_empty():
		# Una copia del reparto por especie, no el de la estática: [_sow] y [resembrar]
		# lo vacían. Los árboles de dentro sí se comparten, que nadie los toca.
		_stands.assign(_siembra_guardada["stands"])
		_total = int(_siembra_guardada["total"])
		# La etapa de la carga pesaba lo de sembrar, y no se ha sembrado.
		Carga.dar_por_hecha_la_etapa()
		print("Forest: %d arboles de la siembra guardada, sin sembrar" % _total)
		return
	siembras += 1

	# El rango de alturas, para normalizar la cota igual que hace el terreno.
	var lowest := height[0]
	var highest := height[0]
	for value in height:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	var span := maxf(highest - lowest, 1.0)

	# La mancha de bosque. Ruido de onda larga: es lo que hace que haya ladera
	# de pinar y ladera pelada en vez de una nube uniforme de árboles.
	var stands := FastNoiseLite.new()
	stands.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	stands.frequency = 1.0 / maxf(stand_size, 20.0)
	stands.seed = 20260906
	# Y un segundo ruido, más fino y girado, para que el borde de la mancha se
	# deshilache en vez de salir con forma de nube de dibujos.
	var edge := FastNoiseLite.new()
	edge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	edge.frequency = 1.0 / maxf(stand_size * 0.22, 8.0)
	edge.seed = 77120

	_stands.clear()
	for i in range(KINDS.size()):
		_stands.append({})

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260906
	var steps_x := int(extent.x / SPACING)
	var steps_z := int(extent.y / SPACING)
	_total = 0

	for iz in range(steps_z):
		# La siembra son 14 s: cada fila dice por dónde va y, con pantalla de carga, deja
		# pintar si ya ha gastado su cuadro (INTERFAZ §9). Sin pantalla no espera nada.
		Carga.avanzar(float(iz) / float(steps_z))
		await Carga.ceder()
		for ix in range(steps_x):
			# El candidato, movido dentro de su casilla para que no se lea la
			# cuadrícula.
			var wx := origin.x + (float(ix) + rng.randf()) * SPACING
			var wz := origin.y + (float(iz) + rng.randf()) * SPACING

			var gx := clampi(int((wx - origin.x) / spacing), 0, res - 1)
			var gz := clampi(int((wz - origin.y) / spacing), 0, res - 1)
			var idx := gz * res + gx
			var ground := height[idx]

			# Ni en el agua ni en la orilla.
			if ground <= water_y + 0.6:
				continue
			# Ni en la boca de una cueva. Ver [RADIO_DEL_CLARO].
			if not claros.is_empty() 					and en_un_claro(Vector3(wx, 0.0, wz), claros):
				continue
			if not river.is_empty() and river[idx] > 0.08:
				continue

			var west := height[gz * res + maxi(gx - 1, 0)]
			var east := height[gz * res + mini(gx + 1, res - 1)]
			var north := height[maxi(gz - 1, 0) * res + gx]
			var south := height[mini(gz + 1, res - 1) * res + gx]
			var slope := Vector2(east - west, south - north).length() \
				/ (2.0 * spacing)
			var wet := humidity[idx] if not humidity.is_empty() else 0.5
			var level := (ground - lowest) / span

			# La mancha: dentro hay bosque, fuera no, y el borde se deshilacha.
			var mass := stands.get_noise_2d(wx, wz) * 0.5 + 0.5
			mass = clampf(mass + edge.get_noise_2d(wx, wz) * 0.18, 0.0, 1.0)
			# La mancha se ENDURECE. Dejando el ruido tal cual, la densidad varía
			# suave por todo el valle y sale un arbolado de sabana parejo: árboles
			# sueltos en todas partes y bosque en ninguna. Con el escalón hay
			# dentro y fuera, y el borde entre los dos es lo que se lee como
			# linde del bosque.
			# El escalón, más abierto que antes: con 0,44-0,60 la mancha se
			# comía media ladera y el valle quedaba pelado entre bosque y
			# bosque. Lo que se quiere es bosque con claros, no claros con
			# bosque.
			mass = smoothstep(0.30, 0.52, mass)
			# Fuera de la mancha no hay nada que probar. Se sale ANTES del bucle
			# de especies: es casi la mitad de los candidatos, y con medio millón
			# de ellos ahorrarse tres evaluaciones de hábitat en cada uno es la
			# diferencia entre sembrar en dos segundos o en seis.
			if mass <= 0.002:
				continue

			for k in range(KINDS.size()):
				var kind: Dictionary = KINDS[k]
				var fit := _band(slope, kind["slope"]) \
					* _band(wet, kind["humidity"]) \
					* _band(level, kind["height"])
				if fit <= 0.01:
					continue
				# El hábitat es una COMPUERTA, no un multiplicador, y ahí estaba
				# la falta de densidad. `fit` es el producto de tres bandas con
				# bordes blandos, así que dentro del sitio bueno rara vez llega
				# a uno: con `fit` en 0,6 y suerte 0,85 salía medio candidato de
				# cada dos, o sea un árbol cada nueve metros. Eso es arbolado
				# abierto. Un bosque no se rala hacia el centro: o el sitio vale
				# y está cerrado, o no vale y no hay árbol.
				# La compuerta se abre mucho más que antes -0,12 a 0,45-: con
				# aquélla, dentro del sitio bueno todavía se caía la mitad de
				# los candidatos y el bosque se veía por dentro. Aquí es casi un
				# sí o no: si el hábitat da mínimamente, hay árbol.
				var luck := smoothstep(0.04, 0.26, fit) * mass
				luck *= float(kind["chance"]) * density
				if rng.randf() > luck:
					continue

				var spot := Vector3(wx, ground, wz)
				# Se guarda por BLOQUE de malla real, no por tesela de
				# impostor. Es lo mismo para sembrar y muy distinto para montar
				# la malla de cerca: guardándolo por tesela de 512 m,
				# `_build_block` tenía que recorrer los treinta mil árboles de
				# la tesela para quedarse con los del bloque de 128, y con un
				# millón de árboles eso son decenas de millones de vueltas cada
				# vez que la cámara cruza un límite de bloque. La tesela se
				# reconstruye agrupando bloques —`_tiles_of`—, una sola vez.
				var tile := Vector2i(int(floor(wx / BLOCK_M)),
					int(floor(wz / BLOCK_M)))
				var grow := rng.randf_range(0.78, 1.28)
				var basis := Basis().rotated(Vector3.UP, rng.randf() * TAU)
				basis = basis.scaled(Vector3(grow, grow, grow))
				var bucket: Dictionary = _stands[k]
				if not bucket.has(tile):
					bucket[tile] = ([] as Array[Transform3D])
				(bucket[tile] as Array[Transform3D]).append(
					Transform3D(basis, spot))
				_total += 1
				# Un candidato da UN árbol: si no, dos especies con hábitats
				# solapados plantan las dos en el mismo punto y se cruzan.
				break

	print("Forest: %d arboles sembrados en %d x %d candidatos" % [
		_total, steps_x, steps_z])
	_siembra_guardada = {"huella": huella, "stands": _stands.duplicate(), "total": _total}
	for k in range(KINDS.size()):
		var count := 0
		for tile: Vector2i in _stands[k]:
			count += (_stands[k][tile] as Array).size()
		print("  %-18s %6d" % [KINDS[k]["name"], count])


## Todo lo que decide dónde cae cada árbol, en un número: el relieve, la humedad y los
## ríos tal cual —no su ruta: dos valles pueden salir de la misma—, el recuadro, el agua,
## las bocas, la densidad y las reglas. Hashear los mapas es trabajo del motor, no bucle de
## script: milisegundos contra los segundos de sembrar.
func huella_de_la_siembra(maps: Dictionary) -> int:
	return hash([VERSION_DE_LA_SIEMBRA, SPACING, BLOCK_M, KINDS, stand_size, density, claros,
		maps["resolution"], maps["extent"], maps["origin"], maps["water_y"],
		maps["height"], maps["humidity"], maps["river"]])


## Pertenencia a una banda [min, max] con un margen blando a cada lado.
func _band(value: float, range_v: Vector2) -> float:
	const EDGE := 0.10
	return smoothstep(range_v.x - EDGE, range_v.x + EDGE, value) \
		* (1.0 - smoothstep(range_v.y - EDGE, range_v.y + EDGE, value))


## Monta los impostores: todo el bosque, dos triángulos por árbol.
## Los árboles de una especie agrupados por TESELA de impostor.
##
## La siembra los guarda por bloque de 128 m —ver `_sow`— y el impostor los
## quiere por tesela de 512, que son cuatro por cuatro bloques. Se agrupan aquí,
## una sola vez al arrancar, en vez de guardarlos dos veces.
func _tiles_of(kind_index: int) -> Dictionary:
	var per_tile: Dictionary = {}
	var side := int(TILE_M / BLOCK_M)
	for block: Vector2i in _stands[kind_index]:
		var tile := Vector2i(
			int(floor(float(block.x) / float(side))),
			int(floor(float(block.y) / float(side))))
		if not per_tile.has(tile):
			per_tile[tile] = ([] as Array[Transform3D])
		(per_tile[tile] as Array[Transform3D]).append_array(
			_stands[kind_index][block] as Array[Transform3D])
	return per_tile


func _raise_impostors() -> void:
	if _atlas == null:
		return
	var shader: Shader = load(IMPOSTOR_SHADER)
	if shader == null:
		return

	var quad := _card_mesh()
	_crossed = _crossed_mesh()
	_near_material.clear()
	_far_material.clear()
	for k in range(KINDS.size()):
		var kind: Dictionary = KINDS[k]
		var size: Vector2 = _sizes[k]
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("atlas", _atlas)
		material.set_shader_parameter("atlas_grid", ATLAS_GRID)
		material.set_shader_parameter("cell_index", int(kind["cell"]))
		# La celda de la copa vista desde arriba: las tres primeras del atlas
		# son los perfiles y las tres siguientes las copas, en el mismo orden.
		material.set_shader_parameter("cell_top",
			int(kind["cell"]) + KINDS.size())
		material.set_shader_parameter("near_end", near_distance)

		# El mismo material para las tablas de cerca, con dos cosas cambiadas: no
		# se giran hacia la cámara -son tres cruzadas- y se desvanecen al revés,
		# porque son el relevo del impostor y no al contrario. Compartir shader y
		# textura es lo que hace que el relevo no se vea.
		if int(kind["cell"]) + KINDS.size() < _brillo_de_celda.size():
			material.set_shader_parameter("brillo_perfil", _brillo_de_celda[int(kind["cell"])])
			material.set_shader_parameter("brillo_copa",
				_brillo_de_celda[int(kind["cell"]) + KINDS.size()])
		var de_copa := tinte_de(k, Subsistence.Season.VERANO, true)
		material.set_shader_parameter("tint", de_copa)
		var colores: Dictionary = COLOR_DE_ESPECIE[String(kind["model"])]
		if colores.has("rama"):
			material.set_shader_parameter("rama", colores["rama"])
		var near := material.duplicate() as ShaderMaterial
		near.set_shader_parameter("billboard", 0.0)
		near.set_shader_parameter("invert_fade", 1.0)
		_near_material.append(near)
		_far_material.append(material)

		var per_tile := _tiles_of(k)
		for tile: Vector2i in per_tile:
			var group: Array[Transform3D] = per_tile[tile]
			if group.is_empty():
				continue
			var centre := Vector3((float(tile.x) + 0.5) * TILE_M, 0.0,
				(float(tile.y) + 0.5) * TILE_M)

			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = quad
			multi.instance_count = group.size()
			for i in range(group.size()):
				var placement: Transform3D = group[i]
				# La escala de la instancia lleva la talla del impostor: ancho
				# real del árbol en x y alto real en y. Así el cuadrado toma la
				# forma del árbol y no al revés.
				var grow := placement.basis.get_scale().x
				var shaped := Basis().scaled(
					Vector3(size.x * grow, size.y * grow, 1.0))
				multi.set_instance_transform(i,
					Transform3D(shaped, placement.origin - centre))

			var node := MultiMeshInstance3D.new()
			node.name = "Impostor_%s_%d_%d" % [kind["model"], tile.x, tile.y]
			node.multimesh = multi
			node.position = centre
			node.material_override = material
			# Los impostores no proyectan sombra: la sombra de un bosque a un
			# kilómetro es una mancha en el terreno, y pagar un pase de sombra
			# con alfa por treinta mil cuadrados para eso no sale a cuenta.
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# La caja a mano: las instancias están montadas en el plano y el
			# alto lo pone la escala, pero el shader las gira hacia la cámara,
			# así que la caja calculada se queda corta y el motor las recorta
			# antes de tiempo.
			var reach := TILE_M * 0.5 + size.y * 2.0
			node.custom_aabb = AABB(
				Vector3(-reach, -400.0, -reach),
				Vector3(reach * 2.0, 800.0, reach * 2.0))
			add_child(node)


## El cuadrado del impostor: el pie en el suelo, un metro de alto y uno de
## ancho. La talla real la pone la escala de cada instancia.
func _card_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0),
		Vector3(0.5, 1.0, 0.0), Vector3(-0.5, 1.0, 0.0)])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Por fotograma: poner al día los bloques de malla real que rodean la cámara.
##
## Sólo la malla se transmite; los impostores están todos montados desde el
## principio porque son dos triángulos cada uno y tienen que estar SIEMPRE, que
## es de lo que va este sistema.
func _process(_delta: float) -> void:
	Cronometro.tramo_raiz("vista: bosque")
	if _stands.is_empty() or _library == null:
		Cronometro.cierra("vista: bosque")
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		Cronometro.cierra("vista: bosque")
		return
	var eye := camera.global_position
	var lado := lado_de_bloque()
	var centre := Vector2i(int(floor(eye.x / lado)),
		int(floor(eye.z / lado)))
	if centre != _centre:
		_centre = centre
		_replan()
	# Varios bloques por cuadro y no uno.
	#
	# Con uno, rellenar el disco de malla de verdad al zoom cercano son casi
	# treinta bloques, o sea medio segundo largo de bosque a medias delante de
	# la cámara cada vez que se cruza un límite de bloque. Y ahora que se puede
	# bajar hasta los cincuenta metros de órbita, se cruzan muchos más.
	for _i in range(BLOCKS_PER_FRAME):
		if _pending.is_empty():
			break
		_build_block(_pending.pop_front())
	if escalon > 0:
		_poner_el_ojo(eye)
	Cronometro.cierra("vista: bosque")


## La cámara y el radio ya montado, a los materiales del 3D y del impostor.
##
## **El impostor sólo se esconde dentro de lo montado**: los bloques pendientes van por
## distancia, así que el primero de la cola dice hasta dónde está todo en su sitio. Si
## la cámara corre más que el montaje, el radio encoge y se ve el impostor en vez de un
## hueco —la otra mitad de la queja, «zonas en las que desaparecen»—.
func _poner_el_ojo(eye: Vector3) -> void:
	var radio := radio_de_cerca()
	var montado := radio
	if not _pending.is_empty():
		var bloque: Vector2i = _pending[0]
		var desde := Vector2(bloque) * BLOQUE_3D_M
		var caja := Rect2(desde, Vector2(BLOQUE_3D_M, BLOQUE_3D_M))
		var punto := Vector2(clampf(eye.x, caja.position.x, caja.end.x),
			clampf(eye.z, caja.position.y, caja.end.y))
		montado = clampf(punto.distance_to(Vector2(eye.x, eye.z)), 0.0, radio)
	for pareja: Array in _mat_3d:
		for m: ShaderMaterial in pareja:
			m.set_shader_parameter("ojo", eye)
	for m: ShaderMaterial in _mat_vistas:
		m.set_shader_parameter("ojo", eye)
		m.set_shader_parameter("oculto_hasta", montado)
	radio_montado = montado


## Cuántos bloques de montar caben en el mapa, por lado. Cero si todavía no se ha
## sembrado.
func bloques_del_mapa() -> Vector2i:
	if _extension == Vector2.ZERO:
		return Vector2i.ZERO
	var lado := lado_de_bloque()
	return Vector2i(int(ceil(_extension.x / lado)), int(ceil(_extension.y / lado)))


## El tamaño del mapa sembrado, en metros.
var _extension := Vector2.ZERO


## Cambia la distancia del 3D sin volver a sembrar: se desmonta el 3D y se vuelve a
## montar con la nueva. Mientras, el impostor tapa lo que falta —sólo se esconde
## dentro de lo montado—, así que no queda hueco.
func aplicar_configuracion() -> void:
	if escalon <= 0:
		return
	var nuevo := maxf(float(Configuracion.graficos.get("radio_3d", radio_3d)), 1.0)
	if is_equal_approx(nuevo, radio_3d):
		return
	radio_3d = nuevo
	for bloque: Vector2i in _live:
		for nodo: Node in _live[bloque]:
			nodo.queue_free()
	_live.clear()
	_pending.clear()
	_centre = Vector2i(999999, 999999)
	for pareja: Array in _mat_3d:
		for m: ShaderMaterial in pareja:
			m.set_shader_parameter("radio_3d", radio_3d)


## Hasta dónde está montado el 3D alrededor de la cámara, en metros. Para las sondas.
var radio_montado := 0.0


func _replan() -> void:
	var reach := int(ceil(radio_de_cerca() / lado_de_bloque()))
	var keep: Dictionary = {}
	var order: Array[Vector2i] = []
	var desde := Vector2i(-reach, -reach)
	var hasta := Vector2i(reach, reach)
	# SIN SALIRSE DEL MAPA: con la distancia del 3D «sin límite» el recorrido eran
	# millones de bloques vacíos por cada cambio de bloque de la cámara.
	var bloques := bloques_del_mapa()
	if bloques != Vector2i.ZERO:
		desde = Vector2i(maxi(desde.x, -_centre.x), maxi(desde.y, -_centre.y))
		hasta = Vector2i(mini(hasta.x, bloques.x - 1 - _centre.x), mini(hasta.y, bloques.y - 1 - _centre.y))
	for dz in range(desde.y, hasta.y + 1):
		for dx in range(desde.x, hasta.x + 1):
			if Vector2(dx, dz).length() > float(reach) + 0.5:
				continue
			var block := _centre + Vector2i(dx, dz)
			keep[block] = true
			if not _live.has(block):
				order.append(block)
	var here := _centre
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - here).length_squared() < (b - here).length_squared())
	_pending = order

	for block: Vector2i in _live.keys():
		if keep.has(block):
			continue
		for node: MultiMeshInstance3D in _live[block]:
			node.queue_free()
		_live.erase(block)


## Monta el árbol de cerca de un bloque: TRES TABLAS CRUZADAS, seis triángulos.
##
## Aquí había la malla escaneada y hubo que quitarla, con el número delante. El
## recorte de detalle de la ingesta elige entre los niveles que la malla ya trae,
## y estos modelos vienen con superficies de CERO niveles -«niveles por
## superficie: 3 0 3» dice su log-, que no se pueden simplificar. Así que el
## «recorte a 24.000» dejó el pino en 678.728 triángulos y el abedul en 1.335.353.
## Medido en el juego: 237 MILLONES de triángulos en el fotograma y 113 ms.
##
## Y la conclusión no es pelearse con la decimación, es que un árbol de cerca
## tampoco necesita ser un escaneo. Tres cuadrados cruzados con la misma foto son
## seis triángulos y se leen como un árbol con volumen desde cualquier ángulo:
## es lo que usa medio sector para el rango medio, y aquí además comparte shader
## y textura con el impostor, así que el relevo entre los dos es invisible.
##
## No se vuelve a decidir nada: son LOS MISMOS árboles que dibuja el impostor,
## leídos de la siembra. Si se recalculasen, el de cerca y el de lejos estarían en
## sitios distintos y el relevo se vería.
func _build_block(block: Vector2i) -> void:
	if escalon > 0:
		_bloque_3d(block)
		return
	if _live.has(block) or _near_material.is_empty():
		return
	_live[block] = ([] as Array[MultiMeshInstance3D])
	var from := Vector2(float(block.x) * BLOCK_M, float(block.y) * BLOCK_M)
	var to := from + Vector2(BLOCK_M, BLOCK_M)
	var centre := Vector3(from.x + BLOCK_M * 0.5, 0.0, from.y + BLOCK_M * 0.5)

	for k in range(KINDS.size()):
		var size: Vector2 = _sizes[k]
		# Los árboles de este bloque, tal cual: la siembra ya los guarda por
		# bloque. Ver el comentario en `_sow`.
		var found: Array[Transform3D] = _stands[k].get(block, [] as Array[Transform3D])
		if found.is_empty():
			continue

		# A la altura de sus árboles, por lo mismo que en `centro_de`.
		var aqui := centro_de(found, Vector2(centre.x, centre.z))
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _crossed
		multi.instance_count = found.size()
		for i in range(found.size()):
			var placement: Transform3D = found[i]
			var grow := placement.basis.get_scale().x
			# El giro de la siembra SÍ se conserva aquí, al contrario que en el
			# impostor: las tablas están quietas, así que dos árboles vecinos con
			# el mismo giro se verían como el mismo sello repetido.
			var turn := Basis(placement.basis.get_rotation_quaternion())
			multi.set_instance_transform(i, Transform3D(
				turn.scaled(Vector3(size.x * grow, size.y * grow, size.x * grow)),
				placement.origin - aqui))

		var node := MultiMeshInstance3D.new()
		node.name = "Arbol_%s_%d_%d" % [KINDS[k]["model"], block.x, block.y]
		node.multimesh = multi
		node.position = aqui
		# Éstos SÍ hacen sombra: un bosque sin sombra no pesa en el suelo, y de
		# cerca es donde se nota. Los impostores no, que son treinta mil.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.material_override = _near_material[k]
		var reach := near_distance + BLOCK_M * 0.71
		node.custom_aabb = AABB(
			Vector3(-BLOCK_M, -400.0, -BLOCK_M),
			Vector3(BLOCK_M * 2.0, 800.0, BLOCK_M * 2.0))
		node.visibility_range_end = reach
		node.visibility_range_end_margin = near_distance * 0.2
		add_child(node)
		(_live[block] as Array[MultiMeshInstance3D]).append(node)


## Las tres tablas cruzadas: el pie en el suelo, un metro de alto y de ancho.
##
## Tres y no dos porque con dos, mirando justo por la bisectriz, el árbol se ve
## de canto y desaparece medio segundo. Con tres a sesenta grados siempre hay una
## de frente.
func _crossed_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for quad in range(3):
		var angle := float(quad) * PI / 3.0
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.5
		var base := verts.size()
		verts.append_array([
			-side, side, side + Vector3.UP, -side + Vector3.UP])
		uvs.append_array([
			Vector2(0.0, 1.0), Vector2(1.0, 1.0),
			Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
		indices.append_array([
			base, base + 1, base + 2, base, base + 2, base + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Cuántos árboles hay sembrados. Para las sondas.
func tree_count() -> int:
	return _total


## Cuántos árboles hay de cada especie en TODO el mapa, no sólo a la vista.
##
## Sale de la siembra y no de los bloques montados a propósito: los bloques son
## los treinta o cuarenta que caben alrededor de la cámara, y el número que se
## quiere saber es cuánto pinar hay en el valle. Lo segundo se lee en la
## consola al arrancar y se perdía en cuanto pasaba el arranque.
func census() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in range(mini(KINDS.size(), _stands.size())):
		var count := 0
		for tile: Vector2i in _stands[k]:
			count += (_stands[k][tile] as Array).size()
		out.append({
			"model": String(KINDS[k]["model"]),
			"name": String(KINDS[k]["name"]),
			"count": count,
		})
	return out


## Dónde están los árboles de una especie, los más cercanos a un punto.
##
## Se recorre por TESELAS y de la más cercana hacia fuera. Un pinar son cientos
## de miles de árboles y ordenarlos todos por distancia para enseñar doscientos
## es trabajo tirado: con vaciar las teselas de al lado hasta juntar unos
## cuantos candidatos ya sobra, porque una tesela son 512 m de lado y ahí
## dentro cabe mucho más de lo que se va a enseñar.
func positions_of(model: String, near: Vector3, limit: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var k := -1
	for i in range(mini(KINDS.size(), _stands.size())):
		if String(KINDS[i]["model"]) == model:
			k = i
			break
	if k < 0:
		return out

	var tiles: Array[Vector2i] = []
	tiles.assign(_stands[k].keys())
	var flat := Vector3(near.x, 0.0, near.z)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _tile_reach(a, flat) < _tile_reach(b, flat))

	var pool: Array[Vector3] = []
	for tile: Vector2i in tiles:
		for placement: Transform3D in _stands[k][tile]:
			pool.append(placement.origin)
		if pool.size() >= limit * 6:
			break
	pool.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(flat) < b.distance_squared_to(flat))
	for i in range(mini(limit, pool.size())):
		out.append(pool[i])
	return out


## A qué distancia queda el centro de un bloque, para ordenarlos.
##
## Bloques y no teselas: desde que la siembra se guarda por bloque -ver `_sow`-
## las claves de `_stands` son de 128 m, y medirlas con el paso de 512 daría
## posiciones cuatro veces más lejos de donde están.
func _tile_reach(tile: Vector2i, point: Vector3) -> float:
	var centre := Vector3(
		(float(tile.x) + 0.5) * BLOCK_M, 0.0, (float(tile.y) + 0.5) * BLOCK_M)
	return centre.distance_squared_to(point)


# ------------------------------------------------- la vuelta del año --

## Le pone al bosque la estacion que toca: color y hoja.
##
## `avance` es cuanto se ha entrado en la estacion, de 0 a 1, y sirve para que
## la hoja no caiga de golpe el dia que cambia el calendario. Un abedular tarda
## tres semanas en pelarse.
##
## Es BARATO: tres materiales y dos uniformes cada uno, o sea seis numeros al
## shader. Se puede llamar una vez por jornada sin pensarlo dos veces.
func set_season(season: Subsistence.Season, previa: Subsistence.Season,
		avance: float) -> void:
	if _far_material.is_empty() and _mat_vistas.is_empty():
		return
	var t := clampf(avance, 0.0, 1.0)
	for k in range(KINDS.size()):
		var kind: Dictionary = KINDS[k]
		var tabla: Dictionary = CADUCO if bool(kind.get("caduco", false)) else PERENNE
		var hoja := lerpf(float(tabla[previa]["hoja"]), float(tabla[season]["hoja"]), t)
		var de_3d := tinte_de(k, previa, false).lerp(tinte_de(k, season, false), t)
		var de_minimo := tinte_de(k, previa, true).lerp(tinte_de(k, season, true), t)
		var materiales: Array = []
		if k < _far_material.size():
			for m: ShaderMaterial in [_far_material[k], _near_material[k]]:
				materiales.append([m, de_minimo])
		if k < _mat_3d.size():
			materiales.append([(_mat_3d[k] as Array)[1], de_3d])
		if k < _mat_vistas.size():
			materiales.append([_mat_vistas[k], de_3d])
			_mat_vistas[k].set_shader_parameter("luz",
				luz_de(k, previa).lerp(luz_de(k, season), t))
		for par: Array in materiales:
			var material := par[0] as ShaderMaterial
			if material == null:
				continue
			var tinte: Color = par[1]
			material.set_shader_parameter("tint", tinte)
			material.set_shader_parameter("hoja", hoja)


## La luminancia lineal media de lo opaco de cada celda del atlas, en orden de celda.
##
## Lo que el shader de Mínimo divide antes de teñir. Se lee del atlas y no se apunta a
## mano: si se rehornea, cambia con él.
static func brillo_de_celdas(image: Image, grid: int) -> PackedFloat32Array:
	var brillos := PackedFloat32Array()
	var lado := image.get_width() / grid
	for c in range(grid * grid):
		var suma := 0.0
		var n := 0
		for y in range(0, lado, 4):
			for x in range(0, lado, 4):
				var p := image.get_pixel((c % grid) * lado + x, (c / grid) * lado + y)
				if p.a > 0.5:
					var lineal := p.srgb_to_linear()
					suma += 0.2126 * lineal.r + 0.7152 * lineal.g + 0.0722 * lineal.b
					n += 1
		brillos.append(suma / float(n) if n > 0 else 1.0)
	return brillos


## La luz del impostor de la especie `k` en una estación: la de otoño en los caducos
## pelándose, la de verano en lo demás. Ver [COLOR_DE_ESPECIE].
static func luz_de(k: int, season: Subsistence.Season) -> Vector3:
	var color: Dictionary = COLOR_DE_ESPECIE[String(KINDS[k]["model"])]
	var de_otono := bool(KINDS[k].get("caduco", false)) and (season == Subsistence.Season.OTONO
		or season == Subsistence.Season.INVIERNO)
	return color["impostor_otono" if de_otono else "impostor"]


## El tinte de la copa de la especie `k` en una estación: el medido de la estación con
## foto más cercana, y encima lo que cambia el año según [PERENNE] o [CADUCO].
##
## Los caducos toman el otoño y el invierno del tinte de otoño TAL CUAL —la hoja seca
## que queda; lo que cambia en invierno es cuánta, `hoja`—, y la primavera del de verano.
## Los perennes, todo del de verano con su forma del año.
##
## El invierno de los caducos se sacaba antes también con la forma del año, relativa al
## otoño; como el otoño de [CADUCO] tiene 0,42 de azul, el invierno salía ×1,9 de azul y
## a principios de primavera los robles se veían azules.
static func tinte_de(k: int, season: Subsistence.Season, minimo: bool) -> Color:
	var kind: Dictionary = KINDS[k]
	var caduco := bool(kind.get("caduco", false))
	var tabla: Dictionary = CADUCO if caduco else PERENNE
	var color: Dictionary = COLOR_DE_ESPECIE[String(kind["model"])]
	var de_otono := caduco and (season == Subsistence.Season.OTONO
		or season == Subsistence.Season.INVIERNO)
	var ancla := Subsistence.Season.OTONO if de_otono else Subsistence.Season.VERANO
	var clave := "copa"
	if minimo:
		clave = "minimo_otono" if de_otono else "minimo"
	elif de_otono:
		clave = "otono"
	var medido: Color = color[clave]
	if de_otono:
		return medido
	var forma: Color = tabla[season]["tinte"]
	var base: Color = tabla[ancla]["tinte"]
	return Color(medido.r * forma.r / base.r, medido.g * forma.g / base.g,
		medido.b * forma.b / base.b)


# --- el bosque de los escalones Medio, Alto y Ultra -----------------------------------

## Carga los árboles 3D y les pone los materiales del bosque. Falso si faltan.
func _cargar_modelos() -> bool:
	var shader: Shader = load(SHADER_3D)
	if shader == null:
		return false
	_modelos.clear()
	_mat_3d.clear()
	for kind: Dictionary in KINDS:
		var clave := String(kind["model"])
		var variantes: Array = []
		var corteza: ShaderMaterial = null
		var hoja: ShaderMaterial = null
		for v in range(VARIANTES):
			Carga.avanzar(0.6 * float(_modelos.size() * VARIANTES + v) / float(KINDS.size() * VARIANTES))
			await Carga.ceder()
			# En segundo plano si hay pantalla de carga: el primer modelo de cada especie
			# decodifica sus texturas, y de un tirón rozaba el medio segundo de cuadro.
			var modelo: ArbolModelo = await Carga.cargar(ArbolModelo.ruta(clave, v)) as ArbolModelo \
				if ResourceLoader.exists(ArbolModelo.ruta(clave, v)) else null
			if modelo == null:
				push_warning("Forest: falta el árbol 3D %s %d; va el bosque Mínimo" % [clave, v])
				return false
			if corteza == null:
				corteza = _material_3d(shader, modelo.niveles[0].surface_get_material(0), false)
				hoja = _material_3d(shader, modelo.niveles[0].surface_get_material(1), true)
			# Los materiales del bosque, en la malla ya cargada: no se guarda, así que el
			# recurso del disco no cambia.
			for malla: Mesh in modelo.niveles:
				(malla as ArrayMesh).surface_set_material(0, corteza)
				(malla as ArrayMesh).surface_set_material(1, hoja)
			variantes.append(modelo)
		_modelos.append(variantes)
		_mat_3d.append([corteza, hoja])
		var de_corteza: Color = COLOR_DE_ESPECIE[clave]["corteza"]
		corteza.set_shader_parameter("tint", de_corteza)
		var de_copa := tinte_de(_modelos.size() - 1, Subsistence.Season.VERANO, false)
		hoja.set_shader_parameter("tint", de_copa)
	return true


func _material_3d(shader: Shader, original: Material, es_hoja: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	var estandar := original as BaseMaterial3D
	if estandar != null:
		m.set_shader_parameter("albedo_tex", estandar.albedo_texture)
		m.set_shader_parameter("recorte", estandar.alpha_scissor_threshold)
	m.set_shader_parameter("es_hoja", es_hoja)
	m.set_shader_parameter("radio_3d", radio_de_cerca())
	return m


## Los impostores de varias vistas: por especie, un material con sus seis variantes, y
## por tesela un MultiMesh donde cada pie lleva su variante en el dato de instancia.
func _raise_impostors_vistas() -> void:
	var shader: Shader = load(SHADER_VISTAS)
	if shader == null:
		return
	var cuadro := _cuadro_de_vistas()
	var radio := radio_de_cerca()
	_mat_vistas.clear()
	for k in range(KINDS.size()):
		Carga.avanzar(0.6 + 0.4 * float(k) / float(KINDS.size()))
		await Carga.ceder()
		var clave := String(KINDS[k]["model"])
		var colores: Array[Image] = []
		var normales: Array[Image] = []
		var radios := PackedFloat32Array()
		var centros := PackedFloat32Array()
		var anchos := PackedFloat32Array()
		var altos := PackedFloat32Array()
		for v in range(VARIANTES):
			# Una variante son dos imágenes con sus mipmaps: la especie entera de golpe
			# llegó a un cuadro de 590 ms al fundar (INTERFAZ §9).
			await Carga.ceder()
			var base := "res://models/arboles/impostores/%s_%d" % [clave, v]
			var color: Image = (await Carga.cargar(base + "_color.res") as Image).duplicate()
			var normal: Image = (await Carga.cargar(base + "_normal.res") as Image).duplicate()
			color.generate_mipmaps()
			normal.generate_mipmaps()
			colores.append(color)
			normales.append(normal)
			var ficha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
			radios.append(float(ficha["radio"]))
			centros.append(float(ficha["centro_y"]))
			# La caja del mismo modelo que se horneó, con el mismo margen del 4 %: el ancho,
			# en diagonal, porque el pie está girado y se mira desde cualquier acimut.
			var caja := (load(ArbolModelo.ruta(clave, v)) as ArbolModelo).niveles[0].get_aabb()
			anchos.append(Vector2(caja.size.x, caja.size.z).length() * 0.5 * 1.04)
			altos.append(caja.size.y * 0.5 * 1.04)
		var array_color := Texture2DArray.new()
		array_color.create_from_images(colores)
		var array_normal := Texture2DArray.new()
		array_normal.create_from_images(normales)
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("color_vistas", array_color)
		m.set_shader_parameter("normal_vistas", array_normal)
		m.set_shader_parameter("vistas", ImpostorVistas.VISTAS)
		m.set_shader_parameter("radios", radios)
		m.set_shader_parameter("centros", centros)
		m.set_shader_parameter("anchos", anchos)
		m.set_shader_parameter("mezcla_hasta", float(MEZCLA_HASTA[clampi(escalon, 0, MEZCLA_HASTA.size() - 1)]))
		m.set_shader_parameter("altos", altos)
		m.set_shader_parameter("oculto_hasta", 0.0)
		var de_corteza: Color = COLOR_DE_ESPECIE[clave]["corteza"]
		var de_copa := tinte_de(k, Subsistence.Season.VERANO, false)
		m.set_shader_parameter("tint_corteza", de_corteza)
		m.set_shader_parameter("luz", luz_de(k, Subsistence.Season.VERANO))
		m.set_shader_parameter("tint", de_copa)
		_mat_vistas.append(m)

		var per_tile := _tiles_of(k)
		for tile: Vector2i in per_tile:
			var group: Array[Transform3D] = per_tile[tile]
			if group.is_empty():
				continue
			var centre := Vector3((float(tile.x) + 0.5) * TILE_M, 0.0,
				(float(tile.y) + 0.5) * TILE_M)
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_custom_data = true
			multi.mesh = cuadro
			multi.instance_count = group.size()
			for i in range(group.size()):
				var placement: Transform3D = group[i]
				multi.set_instance_transform(i, Transform3D(placement.basis,
					placement.origin - centre))
				multi.set_instance_custom_data(i,
					Color(float(variante_de(placement.origin)) / 255.0, 0.0, 0.0, 0.0))
			var node := MultiMeshInstance3D.new()
			node.name = "Vistas_%s_%d_%d" % [clave, tile.x, tile.y]
			node.multimesh = multi
			node.position = centre
			node.material_override = m
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var reach := TILE_M * 0.5 + 30.0
			node.custom_aabb = AABB(Vector3(-reach, -400.0, -reach),
				Vector3(reach * 2.0, 800.0, reach * 2.0))
			add_child(node)


## El cuadrado del impostor de varias vistas: sus esquinas van en la UV, que el shader
## lee porque el vértice le llega ya en el mundo.
func _cuadro_de_vistas() -> ArrayMesh:
	var verts := PackedVector3Array([
		Vector3(-1.0, -1.0, 0.0), Vector3(1.0, -1.0, 0.0),
		Vector3(1.0, 1.0, 0.0), Vector3(-1.0, 1.0, 0.0)])
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Los pies de una especie en un bloque, repartidos por su variante: los mismos de la
## siembra, sin quitar ni poner ninguno. Es lo que monta `_bloque_3d`, y está aparte
## para poder probarlo: sin ventana, un MultiMesh no devuelve lo que se le escribió.
func pies_por_variante(k: int, block: Vector2i) -> Array:
	var por_variante: Array = []
	for v in range(VARIANTES):
		por_variante.append([] as Array[Transform3D])
	# El bloque es de 32 m y la siembra va por bloques de 128: se toma el de 128 que lo
	# contiene y se quedan los pies que caen dentro.
	var desde := Vector2(block) * BLOQUE_3D_M
	var hasta := desde + Vector2(BLOQUE_3D_M, BLOQUE_3D_M)
	var padre := Vector2i(int(floor(desde.x / BLOCK_M)), int(floor(desde.y / BLOCK_M)))
	var found: Array[Transform3D] = _stands[k].get(padre, [] as Array[Transform3D])
	for placement: Transform3D in found:
		var o := placement.origin
		if o.x < desde.x or o.z < desde.y or o.x >= hasta.x or o.z >= hasta.y:
			continue
		(por_variante[variante_de(placement.origin)] as Array[Transform3D]).append(placement)
	return por_variante


## Un bloque de cerca en 3D: por especie y variante, un MultiMesh por nivel de detalle
## con su rango de distancia. Los mismos pies que la siembra —ver `_build_block`—.
## Dónde se pone el nodo de un grupo de pies: en el centro del bloque y A LA ALTURA
## MEDIA DE SUS ÁRBOLES, no a cota cero.
##
## Godot mide el rango de visibilidad desde el centro de la caja del nodo. Con el nodo
## a cota cero y los árboles subidos dentro del MultiMesh, un bloque del valle quedaba
## «lejos» por lo que tiene de alto y se apagaba entero antes de tiempo: con la cámara
## a 38 m y mirando bajo, el primer plano del 3D desaparecía mientras el impostor ya se
## había escondido. Lo vio `ArbolAroProbe` (2026-09-15).
static func centro_de(pies: Array[Transform3D], xz: Vector2) -> Vector3:
	var suma := 0.0
	for pie: Transform3D in pies:
		suma += pie.origin.y
	return Vector3(xz.x, suma / float(pies.size()) if not pies.is_empty() else 0.0, xz.y)


func _bloque_3d(block: Vector2i) -> void:
	if _live.has(block) or _modelos.is_empty():
		return
	_live[block] = ([] as Array[MultiMeshInstance3D])
	var from := Vector2(block) * BLOQUE_3D_M
	var centre := Vector3(from.x + BLOQUE_3D_M * 0.5, 0.0, from.y + BLOQUE_3D_M * 0.5)
	var radio := radio_de_cerca()
	# Los niveles de detalle se reparten sobre la distancia del escalón, o sobre la
	# elegida si es menor; más allá, el último nivel llega hasta el radio.
	var detalle := minf(radio, float(DETALLE_HASTA[clampi(escalon, 1, DETALLE_HASTA.size() - 1)]))
	for k in range(KINDS.size()):
		var por_variante := pies_por_variante(k, block)
		for v in range(VARIANTES):
			var pies: Array[Transform3D] = por_variante[v]
			if pies.is_empty():
				continue
			var modelo: ArbolModelo = _modelos[k][v]
			var aqui := centro_de(pies, Vector2(centre.x, centre.z))
			for n in range(modelo.niveles.size()):
				var multi := MultiMesh.new()
				multi.transform_format = MultiMesh.TRANSFORM_3D
				multi.mesh = modelo.niveles[n]
				multi.instance_count = pies.size()
				for i in range(pies.size()):
					multi.set_instance_transform(i, Transform3D(pies[i].basis,
						pies[i].origin - aqui))
				var node := MultiMeshInstance3D.new()
				node.name = "Arbol3D_%s_%d_%d_%d_%d" % [KINDS[k]["model"], v, n, block.x, block.y]
				node.multimesh = multi
				node.position = aqui
				# Los rangos por NIVEL, medidos desde el centro del bloque —así los hace
				# Godot— y SIN SOLAPARSE: con holgura a los dos lados, en la franja común
				# se pintaban dos niveles del mismo árbol a la vez. El último llega hasta
				# el radio y medio bloque más; el que quita cada árbol es su corte en el
				# shader, por su pie.
				node.visibility_range_begin = float(NIVELES_DESDE[n]) * detalle
				node.visibility_range_end = float(NIVELES_DESDE[n + 1]) * detalle \
					if n + 1 < NIVELES_DESDE.size() else radio + BLOQUE_3D_M * 0.71
				# Sombra de cerca, que es donde se nota; el último nivel, sin.
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
					if n < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.custom_aabb = AABB(Vector3(-BLOQUE_3D_M, -80.0, -BLOQUE_3D_M),
					Vector3(BLOQUE_3D_M * 2.0, 160.0, BLOQUE_3D_M * 2.0))
				add_child(node)
				(_live[block] as Array[MultiMeshInstance3D]).append(node)

