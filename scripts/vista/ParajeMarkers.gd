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
## Lo que mide un pixel de la chapa en metros del mundo.
##
## Va aqui y no escrito en cada sitio porque lo usan TRES: el tamaño de la
## chapa y los dos radios de pinchado. Al subirlo de 0,07 a 0,14 -el doble,
## por peticion- los radios de pinchado se quedaron con el numero viejo y el
## alfiler pasaba a responder solo en su mitad de abajo.
const PIN_PIXEL := 0.14

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
## ## Un alfiler por paraje, sin agrupar
##
## Aquí se volvían a fusionar los parajes por cercanía —320 m,
## [Parajes.MERGE_RANGE]— y SIN MIRAR EL OFICIO, así que una pesquera
## desaparecía debajo de un cantizal por estar a doscientos metros. Medido con
## `HallazgoProbe`: ocho parajes en el registro y CUATRO alfileres pintados,
## que es exactamente lo que veía el jugador —«no son visibles con sus
## markers»—.
##
## Y sobraba, además. El caso que la agrupación quería resolver —un cotarro con
## caza, avellanas y buena piedra a la vez— ya no llega hasta aquí: cuando
## varios oficios caen en el mismo trozo de monte se juntan AL BAUTIZAR, en un
## solo paraje con varias actividades (ver [Parajes.near] y `activity_fits`,
## que sí miran el oficio y el lado del río). Lo que llega aquí como dos
## parajes distintos es que de verdad son dos sitios, y los dos tienen que
## verse.
func refresh(parajes: Parajes, terrain: TerrainGenerator) -> void:
	var seen := {}
	for paraje: Paraje in parajes.list:
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
		var reach := float(PIN_HEIGHT) * 0.5 * PIN_PIXEL * holder.scale.y
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
	# De 0,04 a 0,07 y de ahi a 0,14: dos peticiones seguidas de marcador mas
	# grande. Cabe hacerlo el doble justo porque ya no lleva el nombre escrito
	# debajo -ver abajo-: la chapa sola ocupa la mitad que la chapa con rotulo.
	chapa.pixel_size = PIN_PIXEL
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

	# SIN nombre escrito. El rotulo estaba debajo de cada alfiler y con quince
	# parajes a la vista el valle era una sopa de letras: se leia el mapa a
	# traves del texto en vez de a traves del terreno. El icono ya dice de que
	# es el sitio, y el nombre esta a un raton de distancia -el aviso emergente
	# y la ficha-, que es donde hace falta.

	_paint(holder, paraje)
	return holder


## El color dice el estado sin tener que pinchar: ocre lo que has elegido,
## apagado lo que está en barbecho, normal el resto.
func _paint(holder: Node3D, paraje: Paraje) -> void:
	var chapa := holder.get_node_or_null("Icono") as Sprite3D
	if chapa == null:
		return

	if paraje.chosen:
		chapa.modulate = Color(1.0, 1.0, 1.0, 1.0)
		chapa.scale = Vector3.ONE * 1.35
	elif paraje.resting:
		chapa.modulate = Color(1.0, 1.0, 1.0, 0.35)
		chapa.scale = Vector3.ONE
	else:
		chapa.modulate = Color(1.0, 1.0, 1.0, 0.8)
		chapa.scale = Vector3.ONE


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

	# Los alfileres ya no llevan rotulo fijo: lo enseña el que se señala, y uno
	# solo. Ver `_show_hovered_name`.
	_show_hovered_name()


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
		var reach := float(PIN_HEIGHT) * 0.5 * PIN_PIXEL * holder.scale.y
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


## El nombre del paraje que el ratón está señalando, y sólo ése.
##
## Los rótulos estaban clavados bajo cada alfiler y con quince parajes a la
## vista el valle era una sopa de letras: se leía el mapa a través del texto en
## vez de a través del terreno. Quitarlos deja el mapa limpio, pero no puede
## dejar el nombre a un clic de distancia y nada más —hay que poder recorrer el
## valle con el ratón y saber qué es cada cosa sin abrir ventanas—.
##
## Uno solo y compartido: no son quince rótulos apagados, es un rótulo que se
## muda al alfiler que toca.
var _hover_label: Label3D
var _hovered: String = ""


func _show_hovered_name() -> void:
	if _camera == null or _sim == null or _sim.parajes == null:
		return
	var mouse := _camera.get_viewport().get_mouse_position()
	var found := pick(_sim.parajes, _camera.project_ray_origin(mouse),
		_camera.project_ray_normal(mouse))
	var id := found.id() if found != null else ""
	if id == _hovered:
		return
	_hovered = id
	if found == null:
		if _hover_label != null:
			_hover_label.visible = false
		return
	if _hover_label == null:
		_hover_label = Label3D.new()
		_hover_label.name = "NombreSenalado"
		_hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hover_label.font_size = 48
		_hover_label.pixel_size = 0.02
		_hover_label.no_depth_test = true
		_hover_label.render_priority = 4
		_hover_label.outline_size = 14
		_hover_label.modulate = UISkin.INK
		_hover_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
		add_child(_hover_label)
	var holder: Node3D = _markers.get(id)
	if holder == null:
		_hover_label.visible = false
		return
	# Debajo de la punta, que es donde estaba el rótulo de antes.
	_hover_label.global_position = holder.global_position + Vector3(0.0, -4.0, 0.0)
	_hover_label.text = found.name_text
	_hover_label.modulate = UISkin.OCHRE if found.chosen else UISkin.INK
	_hover_label.visible = true


## La linea del camino que lleva alguien, dibujada sobre el terreno.## La linea del camino que lleva alguien, dibujada sobre el terreno.
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
## La FORMA no se saca aqui: la tiene el propio paraje, que es lo que arreglo
## que el juego y el dibujo dijeran cosas distintas. Ver [Huella]. Aqui solo se
## drapea sobre el relieve.
##
## Y se drapea con paso fino, no celdilla a celdilla: una celdilla de
## veinticinco metros pintada como un cuadrado plano atraviesa el relieve -en
## una ladera entra por un lado y sale por el otro-, y lo que se ve es una
## lamina rigida flotando sobre el valle en vez de una mancha pegada al suelo.
##
## Los vertices se comparten entre celdillas vecinas -se recorre una rejilla
## continua, no cada celdilla por su cuenta-, asi que no quedan grietas.
func _footprint(paraje: Paraje, terrain: TerrainGenerator,
		field: ResourceField) -> PackedVector3Array:
	var huella := paraje.huella
	if huella == null or huella.vacia():
		huella = Huella.de(paraje, field, terrain)

	var out := PackedVector3Array()
	var fine := int(Huella.CELDILLA / DRAPE_STEP)
	var span := huella.lado * fine

	for z in range(span):
		for x in range(span):
			# La celdilla gruesa a la que pertenece este trozo fino
			@warning_ignore("integer_division")
			var owner := (z / fine) * huella.lado + (x / fine)
			if owner < 0 or owner >= huella.dentro.size() 					or huella.dentro[owner] == 0:
				continue

			var corners: Array[Vector3] = []
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0),
					Vector2i(1, 1), Vector2i(0, 1)]:
				var point := huella.origen + Vector3(
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
