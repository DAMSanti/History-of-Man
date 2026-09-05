class_name ParajeMarkers
extends Node3D
## Los marcadores de los parajes en el mundo: el asa por la que se agarran.
##
## Un paraje sin marcador no se puede pinchar, y sin poder pincharlo el
## jugador no manda: sigue poniendo números en una pestaña. Esto es lo que
## convierte el clic en un verbo.
##
## Cada marcador es una chapa que mira a cámara con el icono del material —los
## mismos glifos que el almacén, para que se reconozcan sin leer— y un rótulo
## con el nombre. El anillo ocre marca el que ha elegido el jugador.

## Alto sobre el terreno, en unidades de mundo. Lo bastante para verse por
## encima de un matorral y no tanto como para flotar.
##
## Ahora la chapa es un alfiler que SEÑALA con la punta, así que el soporte
## se pone donde debe caer esa punta: justo encima del suelo, no a la altura
## de la cabeza del alfiler -que es lo que hacía falta cuando la chapa era un
## disco centrado.
const HEIGHT := 7.0

## A partir de esta distancia el rótulo estorba más que informa: se queda el
## icono solo.
const LABEL_RANGE := 900.0

var _icons: Dictionary = {}
var _markers: Dictionary = {}
var _camera: Camera3D

## La baliza del rumbo señalado. Sin ella el jugador pincha, no ve nada
## cambiar, y no sabe si la orden ha entrado.
var _beacon: Node3D


var _sim: SettlementSim
var _terrain: TerrainGenerator


func setup(camera: Camera3D, sim: SettlementSim = null,
		terrain: TerrainGenerator = null) -> void:
	_camera = camera
	_sim = sim
	_terrain = terrain


## Rehace los marcadores a partir del registro. Se llama de tarde en tarde:
## los parajes se bautizan una vez por jornada, no por fotograma.
##
## Un marcador por SITIO, no por paraje: varios oficios pueden coincidir en
## el mismo trozo de monte -un cotarro con caza, avellanas y buena piedra a
## la vez-, y antes salían tres chapas superpuestas en el mismo punto. Se
## agrupan por cercanía -y por estar en el mismo lado de un río o cantil,
## si se da `same_patch`- y solo el primero de cada grupo pone chapa; los
## demás se leen en su ficha, que los junta -ver `GameUI._paraje_group`.
func refresh(parajes: Parajes, terrain: TerrainGenerator,
		same_patch: Callable = Callable()) -> void:
	var seen := {}

	for paraje: Paraje in parajes.list:
		if _grouped_under(paraje, parajes.list, same_patch) != paraje:
			continue
		seen[paraje.id()] = true
		if _markers.has(paraje.id()):
			_paint(_markers[paraje.id()], paraje)
			continue
		_markers[paraje.id()] = _build(paraje, terrain)

	# Los que ya no estén en el registro se van
	for id: String in _markers.keys():
		if not seen.has(id):
			(_markers[id] as Node).queue_free()
			_markers.erase(id)


## Las cimas también llevan alfiler.
##
## Una cumbre es un sitio al que se manda gente igual que a un paraje —se
## mira, se decide y se sube—, y hasta ahora solo existía en la cabeza del
## explorador: no había forma de verla ni de pincharla. Va aparte de los
## parajes porque no es un sitio de trabajo: no tiene contenidos ni
## cuadrilla, tiene dificultad y una decisión.
const PEAK_TINT := Color(0.58, 0.62, 0.70)

var _peaks: Dictionary = {}


func refresh_peaks(peaks: Array, terrain: TerrainGenerator) -> void:
	var seen := {}
	for peak: Dictionary in peaks:
		var key := _peak_key(peak["pos"] as Vector3)
		seen[key] = true
		if _peaks.has(key):
			continue
		_peaks[key] = _build_peak(peak, terrain)

	for key: String in _peaks.keys():
		if not seen.has(key):
			(_peaks[key] as Node).queue_free()
			_peaks.erase(key)


static func _peak_key(point: Vector3) -> String:
	return "cima_%d_%d" % [int(point.x), int(point.z)]


func _build_peak(peak: Dictionary, terrain: TerrainGenerator) -> Node3D:
	var holder := Node3D.new()
	var world: Vector3 = peak["pos"]
	if terrain:
		world.y = terrain.get_height_at(world)
	holder.name = "Cima_" + _peak_key(world)
	holder.position = world + Vector3(0.0, HEIGHT, 0.0)
	add_child(holder)

	var chapa := Sprite3D.new()
	chapa.name = "Icono"
	chapa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chapa.texture = _pin("cumbre", MateriaIcon.Glyph.CUMBRE, PEAK_TINT)
	chapa.pixel_size = 0.07
	chapa.offset = Vector2(0.0, float(PIN_HEIGHT) * 0.5)
	chapa.no_depth_test = true
	chapa.render_priority = 2
	chapa.shaded = false
	holder.add_child(chapa)

	var label := Label3D.new()
	label.name = "Nombre"
	label.text = "Cumbre · +%d m" % int(peak.get("rise", 0.0))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.014
	label.no_depth_test = true
	label.render_priority = 3
	label.position = Vector3(0.0, -4.0, 0.0)
	label.outline_size = 14
	label.modulate = UISkin.INK_SOFT
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	holder.add_child(label)
	return holder


## Qué cima hay bajo el cursor, si hay alguna. Mismo rayo contra esfera que
## los parajes -ver [pick].
func pick_peak(peaks: Array, origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INF

	for peak: Dictionary in peaks:
		var holder: Node3D = _peaks.get(_peak_key(peak["pos"] as Vector3))
		if holder == null:
			continue
		var reach := float(PIN_HEIGHT) * 0.5 * 0.07 * holder.scale.y
		var centre := holder.global_position + Vector3(0.0, reach, 0.0)
		var along := (centre - origin).dot(direction)
		if along <= 0.0:
			continue
		if (origin + direction * along).distance_to(centre) > maxf(reach, 12.0):
			continue
		if along < best_distance:
			best_distance = along
			best = peak

	return best


## A qué paraje "representa" -pone chapa por- uno dado: el primero de la
## lista, en orden de creación, entre él y todos los que están en su mismo
## sitio. Determinista por orden de lista, así que dos parajes del mismo
## grupo siempre eligen al mismo representante sin tener que acordarlo.
func _grouped_under(paraje: Paraje, list: Array[Paraje], same_patch: Callable) -> Paraje:
	for other: Paraje in list:
		if other == paraje:
			return paraje
		if other.position.distance_to(paraje.position) > Parajes.MERGE_RANGE:
			continue
		if same_patch.is_valid() and not same_patch.call(other.position, paraje.position):
			continue
		return other
	return paraje


## A que distancia de camara el marcador tiene su tamano natural, en metros.
##
## Mas cerca se encoge y mas lejos crece, de forma que ocupa siempre mas o
## menos lo mismo en pantalla. Es lo que hace que un paraje siga siendo un
## asa que se puede ver y pinchar con la comarca entera a la vista.
const MARKER_REFERENCE := 260.0

## Y los topes. Sin ellos, acercarse mucho lo deja invisible y alejarse
## mucho lo convierte en una mancha que tapa el valle: las dos cosas me han
## pasado, y las dos las ha visto el jugador antes que yo.
## El mínimo subió de 0,35 a 0,9: con el tope viejo, acercar la cámara
## encogía el alfiler hasta dejarlo del tamaño de un guijarro justo cuando
## más se le está mirando. Un marcador tiene que verse SIEMPRE.
const MARKER_MIN_SCALE := 0.9
const MARKER_MAX_SCALE := 4.5


func _build(paraje: Paraje, terrain: TerrainGenerator) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Paraje_" + paraje.id()
	var world := paraje.position
	if terrain:
		world.y = terrain.get_height_at(world)
	holder.position = world + Vector3(0.0, HEIGHT, 0.0)
	add_child(holder)

	var chapa := Sprite3D.new()
	chapa.name = "Icono"
	chapa.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	chapa.texture = _icon_for_paraje(paraje)
	# Tamano en el MUNDO, y la escala se ajusta cada fotograma con la
	# distancia de la camara. Ver `_scale_markers`.
	#
	# `fixed_size` parecia lo suyo y me ha costado dos intentos: con esa
	# bandera el tamano final sale de multiplicar cosas que no controlo, y
	# las dos veces acabe con una chapa tapando la pantalla -el tinte
	# rojizo era el icono del ocre a pantalla completa- o con un rotulo
	# gigante. Con escala explicita el tamano es una cuenta que se puede
	# leer y acotar.
	#
	# Subido de 0,04 a 0,07 -peticion explicita de marcador mas grande-.
	chapa.pixel_size = 0.07
	# La PUNTA del alfiler es la que señala el sitio, así que la chapa cuelga
	# hacia arriba desde el origen del soporte en vez de centrarse en él. Sin
	# esto el alfiler queda clavado por la mitad y señala metros más arriba
	# de donde está el paraje.
	chapa.offset = Vector2(0.0, float(PIN_HEIGHT) * 0.5)
	# Y se ve por delante del monte. Un paraje escondido tras una loma es
	# justo el que hace falta encontrar.
	chapa.no_depth_test = true
	chapa.render_priority = 2
	chapa.shaded = false
	holder.add_child(chapa)

	var label := Label3D.new()
	label.name = "Nombre"
	label.text = paraje.name_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.014
	label.no_depth_test = true
	label.render_priority = 3
	# Bajo la punta del alfiler, no bajo su cabeza
	label.position = Vector3(0.0, -4.0, 0.0)
	label.outline_size = 14
	label.modulate = UISkin.INK
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
	holder.add_child(label)

	_paint(holder, paraje)
	return holder


## El color dice el estado sin tener que pinchar: ocre lo que has elegido,
## apagado lo que está en barbecho, normal el resto.
func _paint(holder: Node3D, paraje: Paraje) -> void:
	var chapa := holder.get_node_or_null("Icono") as Sprite3D
	var label := holder.get_node_or_null("Nombre") as Label3D
	if chapa == null or label == null:
		return

	if paraje.chosen:
		chapa.modulate = Color(1.0, 1.0, 1.0, 1.0)
		chapa.scale = Vector3.ONE * 1.35
		label.modulate = UISkin.OCHRE
	elif paraje.resting:
		chapa.modulate = Color(1.0, 1.0, 1.0, 0.35)
		chapa.scale = Vector3.ONE
		label.modulate = UISkin.INK_FAINT
	else:
		chapa.modulate = Color(1.0, 1.0, 1.0, 0.8)
		chapa.scale = Vector3.ONE
		label.modulate = UISkin.INK_SOFT


## Oculta el rótulo de los que quedan lejos: con veinte parajes a la vista, el
## mapa se vuelve una sopa de letras.
func _process(_delta: float) -> void:
	if _camera == null:
		return

	# La escala va CADA fotograma: es lo que el ojo nota si se retrasa, porque
	# se mueve con la camara y un marcador que da saltos al hacer zoom se lee
	# como un fallo grafico.
	_scale_markers()

	if Engine.get_process_frames() % 12 != 0:
		return

	# La baliza se pone y se quita AL INSTANTE. Refrescarla solo al cerrar la
	# jornada dejaba al jugador pinchando «explorar hacia aqui» sin ver nada
	# cambiar hasta el dia siguiente, que se lee como que el boton no va.
	if _sim:
		var wanted := _sim.has_scout_order
		if wanted != (_beacon != null) 				or (wanted and _beacon.position.distance_to(_sim.scout_order) > 1.0):
			set_scout_beacon(_sim.scout_order, wanted, _terrain)

	var eye := _camera.global_position
	for id: String in _markers:
		var holder: Node3D = _markers[id]
		var label := holder.get_node_or_null("Nombre") as Label3D
		if label:
			label.visible = eye.distance_to(holder.global_position) < LABEL_RANGE


## Tamaño de la chapa en píxeles. Alta y estrecha porque es un alfiler, no
## un disco: cabeza arriba, punta abajo.
const PIN_WIDTH := 72
const PIN_HEIGHT := 94


## El alfiler de un paraje concreto, ya horneado y compartido.
##
## No siempre lleva el icono de su material: uno de caza no enseña la tajada
## genérica, enseña el ANIMAL que de verdad hay -mismo criterio que la
## sección FAUNA de la ficha, ver [GameUI._fauna_section]-, porque un corzo y
## un jabalí no son intercambiables aunque los dos sean "carne".
func _icon_for_paraje(paraje: Paraje) -> Texture2D:
	if paraje.activity == Subsistence.Activity.CAZA:
		var species := Fauna.species_at(paraje.position, GameState.season)
		if not species.is_empty():
			var beast: Array = MateriaIcon.SPECIES_LOOK.get(species[0],
				[MateriaIcon.Glyph.CARNE, Color(0.70, 0.28, 0.26)])
			return _pin(species[0], beast[0] as MateriaIcon.Glyph, beast[1] as Color)

	var entry: Array = MateriaIcon.LOOK.get(paraje.kind,
		[MateriaIcon.Glyph.CANTO, Color(0.6, 0.6, 0.6)])
	return _pin("materia_%d" % paraje.kind,
		entry[0] as MateriaIcon.Glyph, entry[1] as Color)


## Un alfiler con su glifo dentro, horneado una vez por material y
## compartido por todos los parajes que lo lleven.
##
## Se monta con el MISMO [MateriaIcon] que usa el almacén -no una copia del
## dibujo-, así que si cambia el glifo de la avellana cambia en los dos
## sitios. Para eso hace falta un [SubViewport]: es la manera de convertir un
## Control que se dibuja a mano en una textura que pueda llevar un Sprite3D.
## Son de 72x94 y hay uno por material, o sea nada.
func _pin(key: String, glyph: MateriaIcon.Glyph, tint: Color) -> Texture2D:
	if _icons.has(key):
		return _icons[key]

	var view := SubViewport.new()
	view.size = Vector2i(PIN_WIDTH, PIN_HEIGHT)
	view.transparent_bg = true
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	var pin := ParajePin.new()
	pin.body_tint = tint
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(pin)
	# El tamaño, DESPUÉS de entrar en el árbol: puesto antes se lo puede
	# comer el primer redimensionado y el Control se queda a cero, que se ve
	# como un alfiler en blanco.
	pin.size = Vector2(PIN_WIDTH, PIN_HEIGHT)

	# El glifo, centrado en la cabeza del alfiler y oscurecido para que se
	# lea sobre el hueco claro. El color sigue siendo el suyo: el del
	# material, no uno de adorno.
	var head_radius := float(PIN_WIDTH) * 0.5 - ParajePin.BORDER
	var box := head_radius * 0.9
	var icon := MateriaIcon.new()
	icon.glyph = glyph
	icon.tint = tint.darkened(0.3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(icon)
	icon.size = Vector2(box, box)
	icon.position = Vector2(float(PIN_WIDTH) * 0.5 - box * 0.5,
		ParajePin.BORDER + head_radius - box * 0.5)

	var texture := view.get_texture()
	_icons[key] = texture
	return texture


## Planta o quita la baliza del rumbo señalado.
func set_scout_beacon(point: Vector3, active: bool, terrain: TerrainGenerator) -> void:
	if not active:
		if _beacon:
			_beacon.queue_free()
			_beacon = null
		return

	if _beacon == null:
		_beacon = Node3D.new()
		_beacon.name = "RumboSenalado"
		add_child(_beacon)

		# Un mástil, que se ve de lejos y no se confunde con una chapa de
		# paraje: aquí no hay nada todavía, es adonde se va a MIRAR
		var pole := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.6
		shape.bottom_radius = 0.6
		shape.height = 46.0
		pole.mesh = shape
		pole.position = Vector3(0.0, 23.0, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = UISkin.OCHRE
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		pole.material_override = material
		pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beacon.add_child(pole)

		var label := Label3D.new()
		label.text = "Ir a mirar"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 44
		label.pixel_size = 0.07
		label.position = Vector3(0.0, 52.0, 0.0)
		label.outline_size = 14
		label.modulate = UISkin.OCHRE
		label.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
		_beacon.add_child(label)

	var world := point
	if terrain:
		world.y = terrain.get_height_at(point)
	_beacon.position = world


## Qué paraje hay bajo el cursor, si hay alguno.
##
## Rayo contra esfera, como las bocas de cueva: para veinte chapas no hace
## falta un motor de colisiones ni capas de máscara.
func pick(parajes: Parajes, origin: Vector3, direction: Vector3) -> Paraje:
	var best: Paraje = null
	var best_distance := INF

	for paraje: Paraje in parajes.list:
		var holder: Node3D = _markers.get(paraje.id())
		if holder == null:
			continue
		# El soporte está en la PUNTA del alfiler y el cuerpo queda por
		# encima, así que se pincha contra el centro del cuerpo y con un
		# radio que crece con la chapa: si no, el clic solo entraba en la
		# punta y el alfiler entero parecía no responder.
		var reach := float(PIN_HEIGHT) * 0.5 * 0.07 * holder.scale.y
		var centre := holder.global_position + Vector3(0.0, reach, 0.0)
		var to_marker := centre - origin
		var along := to_marker.dot(direction)
		if along <= 0.0:
			continue
		var closest := origin + direction * along
		if closest.distance_to(centre) > maxf(reach, 12.0):
			continue
		if along < best_distance:
			best_distance = along
			best = paraje

	return best


## La linea del camino que lleva alguien, dibujada sobre el terreno.
##
## Es lo que hace visible que la banda RODEA en vez de ir en recta: sin verla,
## el trabajo del trazado no existe para el jugador. Se levanta un poco del
## suelo para que no se pelee con el terreno por el mismo pixel.
var _route_line: MeshInstance3D
const ROUTE_LIFT := 2.5


func show_route(route: PackedVector3Array, from_point: Vector3,
		terrain: TerrainGenerator) -> void:
	if _route_line:
		_route_line.queue_free()
		_route_line = null
	if route.size() < 1:
		return

	# La linea se subdivide: con hitos cada ochenta metros, una recta entre
	# dos se hunde bajo una loma intermedia
	var points := PackedVector3Array([from_point])
	points.append_array(route)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(int(a.distance_to(b) / 12.0), 1)
		for s in range(steps + 1):
			var point := a.lerp(b, float(s) / float(steps))
			if terrain:
				point.y = terrain.get_height_at(point)
			mesh.surface_add_vertex(point + Vector3(0.0, ROUTE_LIFT, 0.0))
	mesh.surface_end()

	_route_line = MeshInstance3D.new()
	_route_line.name = "CaminoSenalado"
	_route_line.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = UISkin.OCHRE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = false
	# Se ve a traves del terreno: un camino que se esconde detras de una loma
	# no cuenta nada
	material.no_depth_test = true
	_route_line.material_override = material
	_route_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_route_line)


func hide_route() -> void:
	if _route_line:
		_route_line.queue_free()
		_route_line = null


## La mancha de terreno que ocupa un paraje.
##
## Un paraje no es un punto: es un trozo de monte con su extension, y hasta
## ahora eso solo existia en un numero. Sin verlo, el jugador no puede saber
## si dos parajes se solapan, si el que ha elegido cubre la ribera entera o si
## se le queda corto.
##
## Se ensena SOLO con su ficha abierta. Una capa permanente sobre el terreno
## tapa el paisaje, y el paisaje es la mitad del juego.
var _extent_mesh: MeshInstance3D


## Cuantos lados tiene la mancha. Veinticuatro basta para que se lea redonda
## sin que parezca dibujada con regla.
const EXTENT_SIDES := 24
const EXTENT_LIFT := 2.0
const EXTENT_COLOUR := Color(0.85, 0.64, 0.33, 0.22)


func hide_extent() -> void:
	if _extent_mesh:
		_extent_mesh.queue_free()
		_extent_mesh = null


## Cuanto mide la celdilla con la que se dibuja la mancha, en metros.
##
## Veinticinco: fina para que el borde siga la forma del sitio y gruesa para
## que un paraje de doscientos metros no sean mil baldosas.
const FOOTPRINT_CELL := 25.0

## Y con que paso se apoya en el suelo, en metros.
##
## Cinco: el mismo detalle con el que esta hecho el terreno. Mas grueso y la
## mancha atraviesa las lomas; mas fino no se nota y multiplica los triangulos
## por nada.
const DRAPE_STEP := 5.0


func show_extent(paraje: Paraje, terrain: TerrainGenerator,
		field: ResourceField = null) -> void:
	hide_extent()
	if paraje == null:
		return

	# La mancha sigue el BORDE REAL del sitio, no un circulo.
	#
	# Un avellanar no es redondo: ocupa la ladera de umbria hasta donde deja
	# de dar sombra, se mete por la vaguada y se corta en seco donde empieza
	# la peña. Dibujarlo como un disco perfecto es dibujar el numero `extent`,
	# no el paraje, y ademas miente sobre donde se puede ir a coger.
	#
	# Se saca del campo de recursos: son las celdillas de alrededor donde de
	# verdad hay lo que hay aqui. Irregular por construccion, porque el monte
	# lo es.
	var mesh := ImmediateMesh.new()
	var tiles := _footprint(paraje, terrain, field)
	if tiles.is_empty():
		return

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for corner: Vector3 in tiles:
		mesh.surface_set_color(EXTENT_COLOUR)
		mesh.surface_add_vertex(corner)
	mesh.surface_end()

	_extent_mesh = MeshInstance3D.new()
	_extent_mesh.name = "ExtensionParaje"
	_extent_mesh.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_extent_mesh.material_override = material
	_extent_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_extent_mesh)


## Las baldosas que forman la mancha, ya en triangulos y apoyadas en el suelo.
##
## Un paraje es UN SITIO, no un archipielago. La primera version pintaba
## celdilla a celdilla lo que daba el campo de recursos y salia una mancha
## agujereada con islas sueltas alrededor, que no es como nadie entiende un
## avellanar: uno dice «el avellanar» senalando un trozo de ladera, con sus
## claros dentro y su borde, no una constelacion de manchitas.
##
## Asi que la forma se limpia en tres pasos, y en este orden:
##   1. **se ensancha una celdilla**, para que las islas de al lado se peguen
##      al cuerpo en vez de quedarse sueltas -absorberlas, no tirarlas-
##   2. **se queda solo lo pegado al centro**, que descarta lo que quedo lejos
##      de verdad y es de otro sitio
##   3. **se tapan los agujeros de dentro**, porque un claro en mitad del
##      avellanar sigue siendo avellanar
func _footprint(paraje: Paraje, terrain: TerrainGenerator,
		field: ResourceField) -> PackedVector3Array:
	var reach := int(paraje.extent / FOOTPRINT_CELL) + 2
	var side := reach * 2 + 1
	var raw := _candidate_cells(paraje, field, reach, side, terrain)
	var grown := _grow(raw, side)
	var body := _keep_centre_blob(grown, side, reach)
	_fill_holes(body, side)

	# Y se dibuja DRAPEADO, con paso fino, no celdilla a celdilla.
	#
	# Una celdilla de veinticinco metros pintada como un cuadrado plano
	# atraviesa el relieve: en una ladera entra por un lado y sale por el otro,
	# y lo que se ve es una lamina rigida flotando sobre el valle en vez de una
	# mancha pegada al suelo. Con paso fino cada vertice se apoya donde de
	# verdad esta el monte.
	#
	# Los vertices se comparten entre celdillas vecinas -se recorre una rejilla
	# continua, no cada celdilla por su cuenta-, asi que no quedan grietas
	# entre ellas.
	var out := PackedVector3Array()
	var fine := int(FOOTPRINT_CELL / DRAPE_STEP)
	var span := side * fine
	var origin := paraje.position - Vector3(
		float(reach) * FOOTPRINT_CELL + FOOTPRINT_CELL * 0.5, 0.0,
		float(reach) * FOOTPRINT_CELL + FOOTPRINT_CELL * 0.5)

	for z in range(span):
		for x in range(span):
			# La celdilla gruesa a la que pertenece este trozo fino
			@warning_ignore("integer_division")
			var owner := (z / fine) * side + (x / fine)
			if owner < 0 or owner >= body.size() or not body[owner]:
				continue

			var corners: Array[Vector3] = []
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0),
					Vector2i(1, 1), Vector2i(0, 1)]:
				var point := origin + Vector3(
					float(x + offset.x) * DRAPE_STEP, 0.0,
					float(z + offset.y) * DRAPE_STEP)
				if terrain:
					point.y = terrain.get_height_at(point)
				point.y += EXTENT_LIFT
				corners.append(point)

			out.append(corners[0])
			out.append(corners[1])
			out.append(corners[2])
			out.append(corners[0])
			out.append(corners[2])
			out.append(corners[3])
	return out


## Donde hay de verdad algo de lo de este paraje.
func _candidate_cells(paraje: Paraje, field: ResourceField,
		reach: int, side: int, terrain: TerrainGenerator = null) -> Array[bool]:
	var mask: Array[bool] = []
	mask.resize(side * side)

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var index := (dz + reach) * side + (dx + reach)
			var centre := paraje.position + Vector3(
				float(dx) * FOOTPRINT_CELL, 0.0, float(dz) * FOOTPRINT_CELL)
			var away := Vector2(centre.x - paraje.position.x,
				centre.z - paraje.position.z).length()
			if away > paraje.extent:
				mask[index] = false
				continue
			if field == null:
				mask[index] = true
				continue

			var amount := field.seasonal_abundance_at(
				paraje.activity, centre, GameState.season)
			# El umbral sube con la distancia al centro: el corazon del sitio
			# entra aunque este flojo, y el borde solo si de verdad sigue
			# habiendo
			var needed := lerpf(0.05, 0.16, away / maxf(paraje.extent, 1.0))
			mask[index] = amount >= needed and _fits_terrain(paraje, centre, terrain)
	return mask


## Si esta celdilla es terreno que de verdad pertenece al paraje.
##
## Un avellanar no cruza el rio para seguir siendo el mismo avellanar: la
## otra orilla es otro sitio, aunque el campo de recursos -que no sabe de
## agua ni de peñas, solo de cuanto hay- diga que ahi tambien abunda. Y una
## pared vertical no es sitio de recolectar ni de cazar: eso solo vale para
## la materia prima, que es precisamente la que se busca en la roca viva.
##
## Sin este corte, la mancha se colaba por el vado y trepaba el cantil con
## tal de que el material siguiera "abundando" ahi, que es fisicamente lo
## que ningun paraje hace de verdad.
func _fits_terrain(paraje: Paraje, centre: Vector3, terrain: TerrainGenerator) -> bool:
	if terrain == null:
		return true

	var ford := terrain.crossing_difficulty_at(centre)
	if not Hydrography.can_cross(ford, false, false):
		return false

	if paraje.serves(Subsistence.Activity.MATERIA_PRIMA):
		return true

	var slope := terrain.get_slope_at(centre)
	return absf(slope) <= Traversal.CLIMB_LIMIT


## Ensancha la mancha una celdilla en todas direcciones.
##
## Es lo que ABSORBE las islas cercanas: dos trozos separados por un hueco de
## una o dos celdillas se tocan y pasan a ser el mismo sitio, que es lo que de
## verdad son.
func _grow(mask: Array[bool], side: int) -> Array[bool]:
	var out: Array[bool] = []
	out.resize(side * side)
	for z in range(side):
		for x in range(side):
			var on := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					if nx < 0 or nz < 0 or nx >= side or nz >= side:
						continue
					if mask[nz * side + nx]:
						on = true
						break
				if on:
					break
			out[z * side + x] = on
	return out


## Se queda solo con el trozo pegado al centro.
##
## Lo que quedo lejos de verdad no es este paraje: es otro sitio, y si merece
## nombre ya se lo pondra la banda cuando lo conozca.
func _keep_centre_blob(mask: Array[bool], side: int, reach: int) -> Array[bool]:
	var out: Array[bool] = []
	out.resize(side * side)

	var start := reach * side + reach
	if not mask[start]:
		return out

	var stack: Array[int] = [start]
	out[start] = true
	while not stack.is_empty():
		var cell: int = stack.pop_back()
		var x := cell % side
		var z := cell / side
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + step.x
			var nz := z + step.y
			if nx < 0 or nz < 0 or nx >= side or nz >= side:
				continue
			var next_cell := nz * side + nx
			if out[next_cell] or not mask[next_cell]:
				continue
			out[next_cell] = true
			stack.append(next_cell)
	return out


## Tapa los huecos de dentro.
##
## Se inunda el VACIO desde el borde del recuadro: lo que el vacio no alcanza
## esta rodeado por la mancha, o sea que es un claro de dentro. Un claro en
## mitad del avellanar sigue siendo avellanar.
func _fill_holes(mask: Array[bool], side: int) -> void:
	var outside: Array[bool] = []
	outside.resize(side * side)

	var stack: Array[int] = []
	for i in range(side):
		for edge: int in [i, (side - 1) * side + i, i * side, i * side + side - 1]:
			if not mask[edge] and not outside[edge]:
				outside[edge] = true
				stack.append(edge)

	while not stack.is_empty():
		var cell: int = stack.pop_back()
		var x := cell % side
		var z := cell / side
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
				Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + step.x
			var nz := z + step.y
			if nx < 0 or nz < 0 or nx >= side or nz >= side:
				continue
			var next_cell := nz * side + nx
			if outside[next_cell] or mask[next_cell]:
				continue
			outside[next_cell] = true
			stack.append(next_cell)

	for i in range(mask.size()):
		if not mask[i] and not outside[i]:
			mask[i] = true


## Ajusta el tamano de los marcadores a la distancia de la camara.
##
## Se hace a mano y no con `fixed_size` porque asi el tamano es una cuenta que
## se puede leer, acotar y corregir.
func _scale_markers() -> void:
	if _camera == null:
		return
	var eye := _camera.global_position

	for child: Node in get_children():
		var holder := child as Node3D
		if holder == null:
			continue
		if not holder.name.begins_with("Paraje_") 				and not holder.name.begins_with("Cima_"):
			continue
		var away := eye.distance_to(holder.global_position)
		holder.scale = Vector3.ONE * clampf(away / MARKER_REFERENCE,
			MARKER_MIN_SCALE, MARKER_MAX_SCALE)
