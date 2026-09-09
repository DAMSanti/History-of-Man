class_name Minimapa
extends RefCounted
## El minimapa de la esquina, con la niebla y las capas que se pintan encima.
##
## Sale de [DemoMain] porque es un tema cerrado y porque `DemoMain` es el
## cableado de la escena, no el sitio donde se dibuja nada.
##
## Se pinta del heightmap YA GENERADO y no con una segunda camara: una
## SubViewport cenital costaria un pase de render entero por fotograma para
## algo que no cambia nunca. Encima van dos imagenes mas sobre la misma base:
## la niebla de lo que la banda no ha explorado, y la capa de abundancia de
## recursos que se cicla con la tecla R.
var demo: Node3D


func _init(escena: Node3D) -> void:
	demo = escena


## Minimapa: sombreado del relieve del recuadro, con la gente encima.
##
## Se pinta del heightmap ya generado y no con una segunda camara: una
## SubViewport cenital costaria un pase de render entero por frame para algo
## que no cambia nunca.
## La columna del bloque del minimapa, para poder colgarle cosas debajo.
var _columna: VBoxContainer
var _ancho: int = 256


## Cuelga el reloj JUSTO DEBAJO DEL MAPA.
##
## La hora, el día, el mes, la estación y el año leídos bajo el mapa son la
## ficha del sitio y del momento; en la fila de arriba competían con los
## medidores. Lo crea [BarraSuperior._build_clock] y aquí se muda.
##
## Aparte de `_build_minimap` porque el minimapa se construye ANTES que la
## interfaz —el relieve tiene que estar generado, y la banda no— así que
## llamándolo desde allí `demo.ui` todavía es nulo y la mudanza no pasaba. Lo
## llama [DemoMain] en cuanto la barra existe.
func colgar_el_reloj() -> void:
	if _columna == null or demo.ui == null or demo.ui._clock == null:
		return
	var reloj: Label = demo.ui._clock
	if reloj.get_parent() == _columna:
		return
	if reloj.get_parent() != null:
		reloj.get_parent().remove_child(reloj)
	reloj.custom_minimum_size = Vector2(_ancho, 0)
	reloj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reloj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Encima del rótulo de capas y del botón, que es donde se mira la hora.
	_columna.add_child(reloj)
	_columna.move_child(reloj, 1)


func _build_minimap(canvas: CanvasLayer) -> void:
	if demo.terrain == null:
		return

	# Mas resolucion: a 176 px sobre 4 km cada pixel eran 23 m y el relieve se
	# perdia entero, que es por lo que salia como color plano.
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var span: Vector2 = demo.terrain.get_height_range()
	var range_h: float = maxf(span.y - span.x, 1.0)
	var step: float = float(demo.terrain_size.x) / float(size)

	# Sombreado direccional de verdad: se ilumina desde el noroeste, que es la
	# convencion cartografica, en vez de restar las dos derivadas. La suma de
	# derivadas aplana las laderas perpendiculares a la diagonal, y por eso el
	# relieve no se leia.
	var sun := Vector3(-0.6, 0.62, -0.5).normalized()

	for py in range(size):
		for px in range(size):
			var world := Vector3(
				float(px) / float(size - 1) * float(demo.terrain_size.x), 0.0,
				float(py) / float(size - 1) * float(demo.terrain_size.y))
			var h: float = demo.terrain.get_height_at(world)
			var t: float = clampf((h - span.x) / range_h, 0.0, 1.0)

			var dx: float = demo.terrain.get_height_at(world + Vector3(step, 0, 0)) - h
			var dz: float = demo.terrain.get_height_at(world + Vector3(0, 0, step)) - h
			var normal := Vector3(-dx, step, -dz).normalized()
			var light: float = clampf(normal.dot(sun) * 1.35 + 0.22, 0.18, 1.35)
			var slope: float = clampf(Vector2(dx, dz).length() / step, 0.0, 1.0)

			var colour: Color
			if demo.terrain.is_underwater(world):
				colour = Color(0.10, 0.20, 0.32)
			elif demo.terrain.crossing_difficulty_at(world) > 0.05:
				# El agua corriente se pinta aparte: es la referencia que hace
				# legible un mapa de valle
				colour = Color(0.20, 0.38, 0.55)
			else:
				# Verde en el llano, ocre segun sube, gris de caliza donde la
				# pendiente afloraria roca: los mismos criterios que el terreno
				var ground := Color(0.30, 0.40, 0.22).lerp(Color(0.58, 0.52, 0.36), t)
				colour = ground.lerp(Color(0.60, 0.58, 0.54), clampf(slope * 1.6, 0.0, 0.85))
				colour *= light
			image.set_pixel(px, py, colour)

	# Se guardan dos: la limpia, que es el relieve tal cual, y la que se pinta,
	# que es esa misma con la niebla de lo no explorado encima
	demo._minimap_clear = image
	demo._minimap_base = image.duplicate() as Image

	# EL MINIMAPA VA DENTRO DE LA BARRA DE ARRIBA.
	#
	# Pedido asi: «quiero integrar el minimapa en la barra superior; no la hagas
	# mas ancha, simplemente mete el minimapa en la barra, haciendola mas ancha
	# SOLO en la zona que coge el mapa».
	#
	# Y por eso no se mete en la fila de la barra: metiendolo ahi, la barra
	# entera engordaria hasta la altura del mapa. Lo que se hace es pegarlo
	# arriba a la derecha SIN margen y con la misma piel, de forma que se lee
	# como la barra bajando solo en ese trozo. [BarraSuperior.HUECO_DEL_MAPA] le
	# guarda el ancho en la fila para que los medidores no queden debajo.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 0)
	canvas.add_child(margin)

	var panel := PanelContainer.new()
	if demo.ui and demo.ui._skin:
		panel.theme = demo.ui._skin
	margin.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	demo._minimap = TextureRect.new()
	demo._minimap.custom_minimum_size = Vector2(size, size)
	demo._minimap.texture = ImageTexture.create_from_image(image)
	column.add_child(demo._minimap)

	_columna = column
	_ancho = size
	colgar_el_reloj()

	# Rotulo del overlay. Deja claro que lo que se pinta es lo que la banda
	# CONOCE: al empezar esta casi en blanco, y esa es la informacion.
	var label_panel := PanelContainer.new()
	column.add_child(label_panel)
	demo._overlay_label = Label.new()
	demo._overlay_label.text = "[R] capas de recurso"
	demo._overlay_label.add_theme_font_size_override("font_size", 11)
	demo._overlay_label.custom_minimum_size = Vector2(size, 0)
	demo._overlay_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_panel.add_child(demo._overlay_label)

	# El boton de volver al mapa regional. Va aqui, junto al minimapa, que es
	# donde uno mira cuando piensa «quiero ver el mapa grande». Antes esto era
	# ESC, y salirse del valle entero por pulsar ESC daba un susto cada vez.
	var back := Button.new()
	back.text = "Ver la comarca"
	back.custom_minimum_size = Vector2(size, 26)
	back.tooltip_text = "Vuelve al mapa regional de Cantabria"
	if demo.ui and demo.ui._skin:
		back.theme = demo.ui._skin
	back.pressed.connect(func() -> void:
		if Expedition.is_active():
			demo._return_to_region())
	column.add_child(back)


## Repinta gente y tajos sobre el relieve del minimapa
func _update_minimap() -> void:
	if demo._minimap == null or demo._minimap_base == null:
		return

	# Se reutiliza la misma imagen en vez de duplicar la base: son 256x256 y
	# esto corre cuatro veces por segundo
	if demo._minimap_frame == null:
		demo._minimap_frame = demo._minimap_base.duplicate() as Image
	else:
		demo._minimap_frame.blit_rect(demo._minimap_base,
			Rect2i(Vector2i.ZERO, demo._minimap_base.get_size()), Vector2i.ZERO)
	var image: Image = demo._minimap_frame

	# El overlay de recursos ya NO se pinta aqui. Lo hacia recorriendo los
	# 65.536 pixeles del minimapa y llamando a `believed_abundance` en cada
	# uno, cuatro veces por segundo: era la mitad de los frames que se comian
	# los overlays. Ahora esa capa la pinta el shader del terreno de una sola
	# muestra, y el minimapa se dedica a lo suyo, que es orientar.
	if demo.herds and demo._overlay_activity == Subsistence.Activity.CAZA:
		for position: Vector3 in demo.herds.positions():
			_plot(image, position, Color(0.95, 0.62, 0.30), 1)

	if demo.sim:
		for a: int in demo.sim.work_sites.keys():
			_plot(image, demo.sim.work_sites[a], Color(0.35, 0.9, 0.95), 2)
		for person: Inhabitant in demo.sim.people:
			_plot(image, person.position, Color(1.0, 0.92, 0.55), 1)
		_plot(image, demo.sim.home_position, Color(1.0, 0.42, 0.35), 3)
	if demo.camera:
		_draw_view_cone(image)
		_plot(image, demo.camera.target_position, Color(1.0, 1.0, 1.0), 2)

	# Actualizar la textura existente en vez de crear una nueva cada vez: crear
	# una ImageTexture reserva memoria de GPU, y hacerlo cuatro veces por
	# segundo deja al recolector trabajando de balde
	if demo._minimap.texture is ImageTexture:
		(demo._minimap.texture as ImageTexture).update(image)
	else:
		demo._minimap.texture = ImageTexture.create_from_image(image)


## Dibuja hacia donde mira la camara y hasta donde llega.
##
## Sin esto el minimapa no dice lo unico que hace falta para orientarse, que es
## en que parte del valle esta uno y hacia donde apunta.
func _draw_view_cone(image: Image) -> void:
	var size := image.get_width()
	var eye: Vector3 = demo.camera.global_position
	var target: Vector3 = demo.camera.target_position

	var forward := Vector2(target.x - eye.x, target.z - eye.z)
	if forward.length() < 0.001:
		return
	forward = forward.normalized()

	# Alcance proporcional a lo lejos que esta la camara: al alejarse se ve
	# mas mapa, y el cono tiene que crecer con ello
	var reach: float = clampf(eye.distance_to(target) * 1.5, 120.0, float(demo.terrain_size.x))
	var half_angle := deg_to_rad(demo.camera.fov * 0.5)

	var origin := Vector2(eye.x, eye.z)
	for side in [-1.0, 1.0]:
		var edge := forward.rotated(side * half_angle)
		var steps := int(reach / 6.0)
		for s in range(steps):
			var point := origin + edge * (float(s) * 6.0)
			var px := int(point.x / float(demo.terrain_size.x) * float(size - 1))
			var py := int(point.y / float(demo.terrain_size.y) * float(size - 1))
			if px < 0 or py < 0 or px >= size or py >= size:
				continue
			# Se mezcla en vez de pintar opaco: el cono es una guia, no debe
			# tapar el relieve que hay debajo
			image.set_pixel(px, py,
				image.get_pixel(px, py).lerp(Color(1.0, 1.0, 1.0), 0.55))

	# La posicion de la camara, que no es la misma que su objetivo
	_plot(image, Vector3(eye.x, 0.0, eye.z), Color(0.95, 0.95, 1.0), 2)


## Overlay de recursos sobre el terreno, en UNA textura.
##
## La primera version ponia un MeshInstance3D por celda y actividad: 64x64
## celdas por cinco actividades son mas de veinte mil nodos, cada uno con su
## material y su llamada de dibujado. Se comia los frames enteros.
##
## Ahora es una sola imagen que el shader del terreno muestrea y mezcla con el
## albedo. Cuesta cero llamadas de dibujado y ademas queda pegado al relieve en
## vez de flotando en discos por encima.
func _build_resource_overlay() -> void:
	if demo.field == null:
		return

	demo._overlay_image = Image.create(demo.field.width, demo.field.height, false, Image.FORMAT_RGBA8)
	demo._overlay_texture = ImageTexture.create_from_image(demo._overlay_image)

	var material: ShaderMaterial = demo.terrain.get_terrain_material()
	if material:
		material.set_shader_parameter("overlay_tex", demo._overlay_texture)
		material.set_shader_parameter("overlay_world_size",
			Vector2(float(demo.terrain_size.x), float(demo.terrain_size.y)))
		material.set_shader_parameter("use_overlay", false)


## Repinta la capa activa. Se llama al cambiar de capa y de vez en cuando,
## porque lo que muestra -lo conocido- crece segun anda la gente.
func _refresh_resource_overlay() -> void:
	if demo._overlay_image == null or demo.terrain == null:
		return

	var material: ShaderMaterial = demo.terrain.get_terrain_material()
	if material == null:
		return

	if demo._overlay_activity == demo.OVERLAY_OFF:
		material.set_shader_parameter("use_overlay", false)
		return

	var showing_known: bool = demo._overlay_activity == demo.OVERLAY_KNOWN
	var activity := Subsistence.Activity.CAZA
	var tint := Color(0.55, 0.80, 1.0)
	if not showing_known:
		activity = demo._overlay_activity as Subsistence.Activity
		tint = _overlay_color(activity)

	for z in range(demo.field.height):
		for x in range(demo.field.width):
			var centre: Vector3 = demo.field.cell_center(x, z)
			var strength := 0.0

			if showing_known:
				# Capa de territorio reconocido. Sale de `explored`, que es el
				# mapa de lo que se ha VISTO, y no de la familiaridad con los
				# recursos: se puede cruzar un valle entero sin aprender nada
				# de su caza y aun asi conocer el camino.
				if demo.knowledge:
					strength = demo.knowledge.explored_at(centre)
			else:
				# Capa de un recurso: se pinta lo que la banda CREE que hay.
				# Un mapa con los cotarros que nadie ha pisado seria el mapa
				# del disenador, no el de la banda.
				if demo.knowledge:
					strength = clampf(demo.knowledge.believed_abundance(
						demo.field, activity, centre, GameState.season), 0.0, 1.0)
				else:
					strength = demo.field.abundance_cell(activity, x, z)

			demo._overlay_image.set_pixel(x, z,
				Color(tint.r, tint.g, tint.b, clampf(strength, 0.0, 1.0)))

	demo._overlay_texture.update(demo._overlay_image)
	material.set_shader_parameter("use_overlay", true)


## Oscurece en el minimapa lo que la banda no ha visto.
##
## Se rehace la imagen base entera y de tarde en tarde, no en cada refresco:
## repintar 65.000 pixeles cuatro veces por segundo fue lo que se comio los
## frames la vez anterior, y lo que muestra cambia por jornadas.
func _refresh_minimap_fog() -> void:
	if demo._minimap_base == null or demo.knowledge == null or demo._minimap_clear == null:
		return

	var size: int = demo._minimap_base.get_width()
	# Se muestrea a la resolucion del conocimiento y se rellena por bloques:
	# la niebla no tiene mas detalle que eso, asi que pedirle mas es tirar
	# trabajo
	var block := maxi(size / demo.knowledge.width, 1)

	for by in range(0, size, block):
		for bx in range(0, size, block):
			var world := Vector3(
				float(bx) / float(size - 1) * float(demo.terrain_size.x), 0.0,
				float(by) / float(size - 1) * float(demo.terrain_size.y))
			# Ni negro del todo: se deja adivinar la silueta del valle, que es
			# lo que se ve desde lejos aunque no se haya estado
			var light: float = 0.16 + 0.84 * clampf(
				demo.knowledge.explored_at(world), 0.0, 1.0)
			for y in range(by, mini(by + block, size)):
				for x in range(bx, mini(bx + block, size)):
					demo._minimap_base.set_pixel(x, y,
						demo._minimap_clear.get_pixel(x, y) * light)


## Un color por actividad, para que el overlay se lea de un vistazo
func _overlay_color(activity: Subsistence.Activity) -> Color:
	match activity:
		Subsistence.Activity.PESCA: return Color(0.35, 0.70, 0.95)
		Subsistence.Activity.CAZA: return Color(0.95, 0.45, 0.30)
		Subsistence.Activity.RECOLECCION: return Color(0.55, 0.85, 0.35)
		Subsistence.Activity.MARISQUEO: return Color(0.85, 0.75, 0.40)
		_: return Color(0.75, 0.70, 0.80)


## Cambia de capa de recursos con la tecla R
func _cycle_overlay() -> void:
	# El territorio conocido va PRIMERO: es la capa que contesta la pregunta
	# que se hace uno antes que ninguna otra, que es hasta donde ha llegado la
	# banda. Las de recurso solo tienen sentido leidas sobre esa.
	var order := [demo.OVERLAY_OFF, demo.OVERLAY_KNOWN,
		Subsistence.Activity.CAZA, Subsistence.Activity.PESCA,
		Subsistence.Activity.RECOLECCION, Subsistence.Activity.MARISQUEO,
		Subsistence.Activity.MATERIA_PRIMA]
	var current := order.find(demo._overlay_activity)
	demo._overlay_activity = order[(current + 1) % order.size()]
	_refresh_resource_overlay()

	if demo._overlay_label:
		if demo._overlay_activity == demo.OVERLAY_OFF:
			demo._overlay_label.text = "[R] capas de recurso"
		elif demo._overlay_activity == demo.OVERLAY_KNOWN:
			demo._overlay_label.text = "Territorio reconocido — lo que la banda ha pisado"
		else:
			var activity := demo._overlay_activity as Subsistence.Activity
			var season_note := "temporada conocida" if demo.knowledge != null \
				and demo.knowledge.knows_season(activity, GameState.season) else "temporada por descubrir"
			demo._overlay_label.text = "%s — lo que la banda conoce (%s)" % [
				Subsistence.activity_name(activity), season_note]


func _plot(image: Image, world: Vector3, colour: Color, radius: int) -> void:
	var size := image.get_width()
	var px := int(world.x / float(demo.terrain_size.x) * float(size - 1))
	var py := int(world.z / float(demo.terrain_size.y) * float(size - 1))
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var x := px + dx
			var y := py + dy
			if x >= 0 and y >= 0 and x < size and y < size:
				image.set_pixel(x, y, colour)
