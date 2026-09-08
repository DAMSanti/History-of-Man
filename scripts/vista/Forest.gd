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
var _near_material: Array[ShaderMaterial] = []

## El material del impostor de cada especie. Es UNO por especie y lo comparten
## todas sus teselas, asi que teñir el bosque entero es tocar tres materiales.
var _far_material: Array[ShaderMaterial] = []

var _total := 0


func setup(terrain: TerrainGenerator) -> void:
	_terrain = terrain
	if not ResourceLoader.exists(PropModels.LIBRARY_PATH):
		push_warning("Faltan los modelos. Generalos con PropIngest.")
		return
	_library = load(PropModels.LIBRARY_PATH) as PropLibrary
	if _library == null:
		return

	var image: Image = load(ATLAS_PATH) if ResourceLoader.exists(ATLAS_PATH) \
		else null
	if image != null:
		image.generate_mipmaps()
		_atlas = ImageTexture.create_from_image(image)
		print("Forest: atlas %dx%d, %d celdas por lado" % [
			image.get_width(), image.get_height(), ATLAS_GRID])
	else:
		push_warning("Falta el atlas de arboles. Hornealo con:\n"
			+ "  godot --path . --script res://scripts/tools/TreeAtlas.gd")

	_measure()
	_sow()
	_raise_impostors()


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
	var origin: Vector2 = maps["origin"]
	var water_y: float = maps["water_y"]
	var spacing := extent.x / float(res - 1)

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
	for k in range(KINDS.size()):
		var count := 0
		for tile: Vector2i in _stands[k]:
			count += (_stands[k][tile] as Array).size()
		print("  %-18s %6d" % [KINDS[k]["name"], count])


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
	if _stands.is_empty() or _library == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var eye := camera.global_position
	var centre := Vector2i(int(floor(eye.x / BLOCK_M)),
		int(floor(eye.z / BLOCK_M)))
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


func _replan() -> void:
	var reach := int(ceil(near_distance / BLOCK_M))
	var keep: Dictionary = {}
	var order: Array[Vector2i] = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
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
				placement.origin - centre))

		var node := MultiMeshInstance3D.new()
		node.name = "Arbol_%s_%d_%d" % [KINDS[k]["model"], block.x, block.y]
		node.multimesh = multi
		node.position = centre
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
	if _far_material.is_empty():
		return
	var t := clampf(avance, 0.0, 1.0)
	for k in range(KINDS.size()):
		var kind: Dictionary = KINDS[k]
		var tabla: Dictionary = CADUCO if bool(kind.get("caduco", false)) 			else PERENNE
		var desde: Dictionary = tabla[previa]
		var hasta: Dictionary = tabla[season]
		var tinte: Color = (desde["tinte"] as Color).lerp(
			hasta["tinte"] as Color, t)
		var hoja := lerpf(float(desde["hoja"]), float(hasta["hoja"]), t)
		for material: ShaderMaterial in [_far_material[k], _near_material[k]]:
			if material == null:
				continue
			material.set_shader_parameter("tint",
				Vector3(tinte.r, tinte.g, tinte.b))
			material.set_shader_parameter("hoja", hoja)
