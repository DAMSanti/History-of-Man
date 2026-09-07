extends SceneTree
## Hornea el atlas de briznas: fotografía las matas fotogramétricas de frente y
## las deja como recortes con alfa.
##
## Es el paso que hace viable la alfombra. Una mata de `herbazal` son 2.614
## triángulos, así que veinte mil matas son cincuenta millones y la cosa se
## acaba ahí. Un juego no instancia mallas de hierba: instancia dos quads
## cruzados -cuatro triángulos- con un recorte de hierba pintado encima. Entre
## una cosa y otra hay un factor de SEISCIENTOS CINCUENTA, que es lo que separa
## «se ven dos hierbas en la pantalla» de una alfombra.
##
## Se hornea desde NUESTRAS matas y no se descarga una textura de hierba
## cualquiera, para que la alfombra y las matas sueltas que siguen siendo malla
## -las de los recursos- sean la misma planta y no dos hierbas distintas.
##
## Se fotografía SIN luz direccional y con ambiente blanco plano: lo que se
## quiere guardar es el color propio de la planta, no el de un foco. Si se
## hornease iluminada, la brizna traería su propia sombra pintada y se pelearía
## con la del sol de verdad.

## Qué se fotografía y en qué celda del atlas cae. Cuatro celdas porque el
## shader escoge una por el hash de la posición, y con cuatro siluetas ya no se
## lee el patrón.
## Cada celda es un MECHÓN, no una mata suelta, y ahí está la diferencia entre
## una pradera y un campo de puntitos. Una mata sola, recortada a su alfa, llena
## el diez por ciento de la celda: son briznas separadas por aire, porque eso es
## una mata. Un naipe de hierba tiene que estar LLENO, así que se fotografían
## varias juntas y algo giradas, como sale un mechón en el campo.
## Un mechón por celda del atlas. Cada uno de UNA planta distinta, porque un
## prado no es un monocultivo: con cuatro siluetas se leía el patrón en cuanto
## la cámara se alejaba.
const PICKS: Array[Dictionary] = [
	{"count": 7, "seed": 11, "source": 0},
	{"count": 9, "seed": 27, "source": 1},
	{"count": 6, "seed": 53, "source": 2},
	{"count": 8, "seed": 91, "source": 3},
	{"count": 5, "seed": 137, "source": 4},
	{"count": 7, "seed": 181, "source": 5},
	{"count": 9, "seed": 223, "source": 6},
	{"count": 6, "seed": 269, "source": 7},
	{"count": 8, "seed": 311, "source": 8},
]

## De dónde salen las matas, y cuáles valen.
##
## No valen todas, y por eso las escoge la herramienta en vez de una lista a
## mano. Entre las diecisiete variantes de `pasto` hay mechones cerrados y hay
## cañas sueltas y matas tumbadas; sorteadas al azar, dos de los cuatro naipes
## salían siendo una brizna torcida en medio de un cuadro negro. Lo que hace que
## una mata sirva para esto es que sea ANCHA respecto a su altura: eso es un
## mechón, y es lo que llena el naipe.
## De aquí salen las plantas. Helecho y roseta entran a propósito aunque no sean
## hierba: lo que rompe la lectura de monocultivo es que haya HOJA ANCHA entre
## las cañas, igual que en un prado de verdad.
const SOURCES: Array[String] = ["herbazal", "pasto", "helecho", "roseta"]

## Por debajo de esta parte de la celda ocupada, el mechón se descarta y se
## prueba con otra planta. Es el control de calidad del horneado: un naipe
## transparente es un hueco en el prado y no se ve venir de otra forma.
const MIN_COVERAGE := 0.06

## Cada mechón se hace de UNA SOLA mata repetida y girada, no de una mezcla.
##
## Mezclando al azar entre dieciocho variantes, dos de cada cuatro naipes salían
## siendo una caña suelta perdida en un cuadro negro: basta que el sorteo coja
## una mata alta y estrecha para que el encuadre se abra y el resto se quede
## minúsculo. Repitiendo la misma mata girada, el mechón siempre sale cerrado, y
## la variedad la dan las cuatro celdas -que usan las cuatro matas más cerradas
## que haya- y el giro que el shader le da a cada brizna.

const CELL := 512

## Lado del atlas en celdas. Sale de [GroundCover] para que la herramienta y el
## shader no puedan discrepar: el que tiene que estar de acuerdo con el shader es
## él, y aquí sólo se obedece.
const GRID := GroundCover.ATLAS_GRID

## Se fotografía a este múltiplo y se reduce después.
##
## Sin esto la mitad de la hierba desaparece, y no es una cuestión de gusto. Una
## brizna vista de lejos mide menos de un píxel: al rasterizarla a 512 sale con
## un alfa bajo, y luego el recorte del shader -que es un sí o un no- la borra.
## El resultado era un mechón de cuatro cañas en medio de un cuadro negro.
## Fotografiando a 1536 y reduciendo, cada píxel del atlas resume nueve, y las
## briznas finas llegan con alfa suficiente para sobrevivir al corte.
const SUPER := 3

## Cuánto se sube el alfa después de reducir.
##
## Al promediar nueve píxeles, una brizna que cubría tres de ellos llega con un
## tercio de alfa y el recorte se la lleva por delante. Subirlo devuelve el
## grosor que la reducción se comía; no inventa hierba donde no la había, porque
## donde el alfa era cero sigue siendo cero.
const ALPHA_GAIN := 2.1
const OUT_PNG := "res://models/props/hierba_atlas.png"
const OUT_RES := "res://models/props/hierba_atlas.res"

## El segundo atlas: las mismas plantas fotografiadas DESDE ARRIBA.
##
## Hace falta porque el naipe tumbado -el que tapa el suelo cuando la cámara
## mira desde lo alto- no puede llevar la foto de perfil. Una mata de perfil es
## un ochenta por ciento aire: puesta en horizontal deja pasar el suelo y desde
## ciento noventa metros la pradera desaparecía. De frente esa transparencia es
## una virtud -se ven las briznas sueltas contra el cielo- y en horizontal es el
## defecto entero.
const OUT_TOP_PNG := "res://models/props/hierba_atlas_cenital.png"
const OUT_TOP_RES := "res://models/props/hierba_atlas_cenital.res"

var _view: SubViewport
var _holder: Node3D
var _camera: Camera3D

## Las matas que valen para hacer mechón. Ver `_pick_bushy`.
var _good: Array[Mesh] = []

## Las elegidas con su ficha, y las de reserva por si alguna sale vacía.
var _chosen: Array[Dictionary] = []
var _spare: Array[Dictionary] = []


func _init() -> void:
	var library: PropLibrary = load(PropModels.LIBRARY_PATH)
	if library == null:
		print("sin biblioteca de props"); quit(1); return

	_pick_bushy(library)
	if _good.is_empty():
		print("ninguna mata pasa el corte de mechón"); quit(1); return

	_build_studio()
	await process_frame

	var atlas := Image.create(CELL * GRID, CELL * GRID, false, Image.FORMAT_RGBA8)
	for index in range(PICKS.size()):
		var pick: Dictionary = PICKS[index]
		_place(library, pick)
		for i in range(6):
			await process_frame
		var shot := _view.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)

		var shape := _crop_to_plant(shot)
		# Si el mechón sale casi vacío se cambia la planta y se repite. Pasa con
		# las matas muy tumbadas o de una sola caña: de frente no son más que una
		# raya, y la caja de la malla no lo delata. Dos celdas de nueve salían así
		# -del todo transparentes- y en el prado eran huecos sin explicación.
		var tries := 0
		while _coverage(shape) < MIN_COVERAGE and not _spare.is_empty() 				and tries < 6:
			var swap: Dictionary = _spare.pop_front()
			print("    %s sale vacía, se cambia por %s" % [
				_chosen[index]["name"], swap["name"]])
			_chosen[index] = swap
			_good[int(pick["source"]) % _good.size()] = swap["mesh"] as Mesh
			_place(library, pick)
			for i in range(6):
				await process_frame
			shot = _view.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			shape = _crop_to_plant(shot)
			tries += 1

		shot = shape
		print("  mechón %d · %-12s %d matas · %4.1f%% de la celda" % [
			index + 1, _chosen[index]["name"], int(pick["count"]),
			_coverage(shot) * 100.0])
		atlas.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(CELL, CELL)),
			Vector2i(index % GRID, index / GRID) * Vector2i(CELL, CELL))

	# El borde entre celdas se sangra: con mipmaps, un texel de una celda se
	# mezcla con el de la vecina y aparece una línea de hierba fantasma al lado
	# de cada brizna. Se deja un margen transparente y ya está.
	atlas.save_png(OUT_PNG)
	ResourceSaver.save(atlas, OUT_RES)
	print("atlas de perfil en %s (%dx%d)" % [
		ProjectSettings.globalize_path(OUT_PNG), atlas.get_width(),
		atlas.get_height()])

	print("--- y ahora desde arriba ---")
	var top := Image.create(CELL * GRID, CELL * GRID, false, Image.FORMAT_RGBA8)
	for index in range(PICKS.size()):
		_place_disc(index)
		for i in range(6):
			await process_frame
		var shot := _view.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		shot = _shrink(shot)
		print("  cenital %d · %-12s %4.1f%% de la celda" % [
			index + 1, _chosen[index]["name"], _coverage(shot) * 100.0])
		top.blit_rect(shot, Rect2i(Vector2i.ZERO, Vector2i(CELL, CELL)),
			Vector2i(index % GRID, index / GRID) * Vector2i(CELL, CELL))

	top.save_png(OUT_TOP_PNG)
	ResourceSaver.save(top, OUT_TOP_RES)
	print("atlas cenital en %s" % ProjectSettings.globalize_path(OUT_TOP_PNG))
	quit()


## Un corro de matas visto desde arriba, encuadrado para que llene la celda.
##
## En corro y no en fila porque el naipe tumbado es un cuadrado de suelo: lo que
## tiene que enseñar es una MANCHA de hierba, no un seto. Y se recorta al cuadro
## del corro y no al alfa: si se recortase al alfa, una hoja que sobresale
## estiraría la mancha y las manchas vecinas no casarían de tamaño.
func _place_disc(index: int) -> void:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()

	var mesh: Mesh = _good[index % _good.size()]
	var box := mesh.get_aabb()
	var span := maxf(maxf(box.size.x, box.size.z), 0.01)
	var middle := box.position + box.size * 0.5

	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + index * 17
	# Muchas y muy juntas: aquí se busca TAPAR, no dar silueta. Con catorce
	# repartidas se veía el suelo entre ellas y la mancha salía al diez por
	# ciento, que sobre un naipe tumbado es lo mismo que no poner nada.
	const COUNT := 22
	var reach := span * 0.62
	for i in range(COUNT):
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var angle := (float(i) + rng.randf() * 0.7) / float(COUNT) * TAU
		# Raíz del azar para que el corro salga con densidad pareja en vez de
		# amontonarse en el centro.
		var away := sqrt(rng.randf()) * reach
		var grow := rng.randf_range(0.75, 1.15)
		node.position = Vector3(
			cos(angle) * away - middle.x * grow,
			-box.position.y * grow,
			sin(angle) * away - middle.z * grow)
		node.rotate_y(rng.randf() * TAU)
		node.scale = Vector3(grow, grow, grow)
		_holder.add_child(node)

	# NO se fotografía a plomo, sino al ángulo al que se juega.
	#
	# A noventa grados una mata de hierba son las PUNTAS de las briznas, y la
	# mancha salía entre el cero y el diez por ciento: cierto y enútil. La cámara
	# de este juego mira el suelo hacia cincuenta y cinco grados, y a ese ángulo
	# se ve el costado de las briznas además de las puntas, que es lo que llena.
	const PITCH := -55.0
	_camera.size = reach * 2.0 + span * 0.55
	_camera.far = box.size.y * 4.0 + _camera.size * 10.0 + 10.0
	var away := _camera.far * 0.4
	var tilt := deg_to_rad(PITCH)
	_camera.position = Vector3(0.0, -sin(tilt) * away, cos(tilt) * away)
	_camera.rotation = Vector3(tilt, 0.0, 0.0)


## Reduce la foto supermuestreada a una celda, recuperando el alfa que la
## reducción diluye. Igual que en `_crop_to_plant` pero sin recortar.
func _shrink(image: Image) -> Image:
	var cut := image.duplicate() as Image
	cut.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	for y in range(cut.get_height()):
		for x in range(cut.get_width()):
			var pixel := cut.get_pixel(x, y)
			pixel.a = clampf(pixel.a * ALPHA_GAIN, 0.0, 1.0)
			cut.set_pixel(x, y, pixel)
	return cut


## Recorta la foto a la planta y la estira hasta llenar la celda.
##
## Es el paso que decide si la alfombra funciona. Encuadrada por su caja, una
## mata de hierba ocupa el CINCO POR CIENTO de la celda: el resto es aire, y al
## instanciarla en un naipe de medio metro la planta acaba midiendo cinco
## centímetros. De ahí salía una pradera de puntitos sueltos en vez de un manto,
## y no tenía arreglo por densidad: había que poner veinte veces más naipes para
## tapar lo mismo.
##
## Recortada al alfa, la planta llena la celda y el naipe se aprovecha entero.
## Se estira sin respetar la proporción a propósito: la forma real la pone
## `card_size` en el shader, que es donde tiene que estar porque cambia de un
## anillo a otro.
func _crop_to_plant(image: Image) -> Image:
	var left := image.get_width()
	var top := image.get_height()
	var right := 0
	var bottom := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.08:
				continue
			left = mini(left, x)
			right = maxi(right, x)
			top = mini(top, y)
			bottom = maxi(bottom, y)
	if right <= left or bottom <= top:
		return image

	# Dos píxeles de margen: si se recorta a hueso, el filtro bilineal muerde el
	# borde de la brizna y la hoja sale con el canto cortado.
	const MARGIN := 2
	var box := Rect2i(
		maxi(left - MARGIN, 0), maxi(top - MARGIN, 0),
		mini(right - left + MARGIN * 2, image.get_width() - left + MARGIN),
		mini(bottom - top + MARGIN * 2, image.get_height() - top + MARGIN))
	var cut := image.get_region(box)
	cut.resize(CELL, CELL, Image.INTERPOLATE_LANCZOS)
	# El alfa se recupera después de reducir, no antes: reducir es lo que lo
	# diluye. Ver `ALPHA_GAIN`.
	for y in range(cut.get_height()):
		for x in range(cut.get_width()):
			var pixel := cut.get_pixel(x, y)
			pixel.a = clampf(pixel.a * ALPHA_GAIN, 0.0, 1.0)
			cut.set_pixel(x, y, pixel)
	return cut


## Cuánto de la celda ocupa la planta. Es el control de calidad del horneado: si
## sale un 2%, la cámara está demasiado lejos y la brizna serán cuatro píxeles
## borrosos; si sale un 90%, está cortada por los bordes.
func _coverage(image: Image) -> float:
	var hits := 0
	var step := 4
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			if image.get_pixel(x, y).a > 0.35:
				hits += 1
	var looked := (image.get_height() / step) * (image.get_width() / step)
	return float(hits) / float(maxi(looked, 1))


## Monta un mechón y lo encuadra.
##
## Las matas se apoyan todas en la MISMA COTA y se reparten a lo ancho, no en
## profundidad: el recorte acaba en un quad plano, así que una mata puesta más
## atrás no aporta volumen, sólo sale más pequeña sin motivo. Lo que da el
## volumen es que estén giradas.
func _place(library: PropLibrary, pick: Dictionary) -> void:
	for child in _holder.get_children():
		_holder.remove_child(child)
		child.queue_free()

	var rng := RandomNumberGenerator.new()
	rng.seed = int(pick["seed"])
	var count := int(pick["count"])

	var tall := 0.0
	var wide := 0.0
	var placed: Array[MeshInstance3D] = []
	var mesh: Mesh = _good[int(pick["source"]) % _good.size()]
	for i in range(count):
		var node := MeshInstance3D.new()
		node.mesh = mesh
		var box := mesh.get_aabb()
		# Cada mata apoyada en cero y centrada en su propia caja: las escaneadas
		# no tienen por qué venir con el pivote en el pie.
		var middle := box.position + box.size * 0.5
		node.position = Vector3(-middle.x, -box.position.y, -middle.z)
		node.rotate_y(rng.randf() * TAU)
		var grow := rng.randf_range(0.78, 1.12)
		node.scale = Vector3(grow, grow, grow)
		tall = maxf(tall, box.size.y * grow)
		# El ancho del mechón se acumula del ancho de las matas, no de su
		# altura. Con la altura, un puñado de cañas largas abría el grupo a lo
		# ancho de medio metro y quedaban despegadas unas de otras.
		wide += maxf(box.size.x, box.size.z) * grow * 0.30
		placed.append(node)
		_holder.add_child(node)

	if placed.is_empty():
		return

	for i in range(placed.size()):
		# Repartidas parejo y luego movidas un poco: al azar puro salen huecos
		# grandes y grumos, que es justo lo que no se quiere en un mechón.
		var slot := (float(i) + 0.5) / float(placed.size()) - 0.5
		placed[i].position.x += slot * wide + rng.randf_range(-0.05, 0.05) * wide
		placed[i].position.z += rng.randf_range(-0.10, 0.10) * wide

	# Encuadre sobre la CAJA REAL del mechón ya montado, no sobre una estimación.
	#
	# Estimarla de las cajas sueltas fallaba, y fallaba en silencio: una celda
	# salía transparente y aguantaba seis cambios de planta seguidos, porque el
	# problema nunca fue la planta sino que la cámara estaba mirando a otro sitio.
	# Con la caja de verdad no hay nada que adivinar.
	var box := AABB()
	var first := true
	for node in placed:
		var raw := node.mesh.get_aabb()
		# La mata va girada en Y, así que su caja sin girar no vale: se toma la
		# mayor dimensión horizontal como radio en las dos, que es una cota
		# superior correcta para cualquier giro.
		var span: float = maxf(raw.size.x, raw.size.z) * node.scale.x
		var here := AABB(
			node.position + Vector3(-span * 0.5, raw.position.y * node.scale.x,
				-span * 0.5),
			Vector3(span, raw.size.y * node.scale.x, span))
		box = here if first else box.merge(here)
		first = false

	var reach := maxf(maxf(box.size.x, box.size.y), 0.01) * 1.06
	_camera.size = reach
	var middle := box.position + box.size * 0.5
	# Bien lejos y con el plano lejano holgado: en ortográfica alejarse no
	# encoge nada, así que no cuesta y quita el riesgo de recortar por delante.
	_camera.far = box.size.z * 4.0 + reach * 8.0 + 10.0
	_camera.position = Vector3(middle.x, middle.y, middle.z + _camera.far * 0.5)
	_camera.rotation = Vector3.ZERO


## Ordena las matas por lo cerradas que son y se queda con las cuatro primeras.
##
## La medida es el ancho partido por el alto, y lo que se busca es que se
## PAREZCA A UNO, no que sea grande. Ordenar por el máximo fue un error y se vio
## en el horneado: el primer puesto se lo llevó una mata de proporción 2,16, o
## sea una planta TUMBADA, y su naipe salió con un cero por ciento de cobertura
## porque de frente no es más que una raya. Una caña alta da 0,2 y una tumbada
## da 2,2: las dos son malas, y la buena está en medio.
##
## Sale de la propia malla, así que no hay que mantener a mano una lista que se
## quede desfasada en cuanto cambie la biblioteca.
func _pick_bushy(library: PropLibrary) -> void:
	var ranked: Array[Dictionary] = []
	for key: String in SOURCES:
		for variant in range(library.variants(key)):
			var mesh := library.mesh(key, variant)
			if mesh == null:
				continue
			var box := mesh.get_aabb()
			if box.size.y <= 0.0001:
				continue
			var bushy := maxf(box.size.x, box.size.z) / box.size.y
			ranked.append({
				"mesh": mesh, "name": "%s v%d" % [key, variant],
				"bushy": bushy,
				# Distancia a la proporción uno, en logaritmo para que
				# «el doble de ancha» y «la mitad de ancha» penalicen igual.
				"off": absf(log(maxf(bushy, 0.01))),
			})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["off"]) < float(b["off"]))

	# Primero LA MEJOR DE CADA ESPECIE, y luego se rellena por orden.
	#
	# Sin esto el ranking se llenaba entero de `pasto`, que tiene diecisiete
	# variantes y copaba las nueve celdas: nueve mechones distintos de la misma
	# planta. La variedad que se busca no es de silueta, es de PLANTA -que haya
	# hoja ancha entre las cañas-, y eso hay que exigirlo, no esperarlo.
	var taken: Dictionary = {}
	for key: String in SOURCES:
		for entry: Dictionary in ranked:
			if String(entry["name"]).begins_with(key + " "):
				_chosen.append(entry)
				taken[entry["name"]] = true
				break
	for entry: Dictionary in ranked:
		if _chosen.size() >= PICKS.size():
			break
		if taken.has(entry["name"]):
			continue
		_chosen.append(entry)
		taken[entry["name"]] = true

	for i in range(_chosen.size()):
		print("  candidata %d: %-12s ancho/alto %.2f" % [
			i + 1, _chosen[i]["name"], _chosen[i]["bushy"]])
		_good.append(_chosen[i]["mesh"] as Mesh)

	# Y de reserva, el resto del ranking: si una candidata se hornea vacía -pasa,
	# y no se ve venir por la caja de la malla- se tira de aquí.
	for entry: Dictionary in ranked:
		if not taken.has(entry["name"]):
			_spare.append(entry)


func _build_studio() -> void:
	_view = SubViewport.new()
	_view.size = Vector2i(CELL, CELL) * SUPER
	# Fondo transparente: lo que no es planta tiene que salir con alfa cero, que
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
	# Sin tonemap ni ajustes: se quiere el albedo, no una interpretación de él.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = environment
	_view.add_child(env)

	_holder = Node3D.new()
	_view.add_child(_holder)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.001
	_camera.far = 100.0
	_view.add_child(_camera)
	_camera.make_current()
