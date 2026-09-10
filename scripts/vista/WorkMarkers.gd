class_name WorkMarkers
extends Node3D
## Qué está haciendo cada cual, encima de su cabeza.
##
## Empezó siendo sólo del taller —`craft_progress` existía y no lo leía nadie
## fuera de `SettlementSim`, así que un artesano trabajando y uno parado se
## veían igual— y vale para todos por la misma razón: desde fuera, un pescador
## que trae ochenta raciones y uno que da vueltas por la orilla son la misma
## figura andando.
##
## Cada oficio lleva su cuenta a su manera —el taller en piezas, el trampero en
## jornadas de armar, el que trabaja el monte en lo que le cabe en el cesto— y
## aquí se enseñan todas igual. Ver `SettlementSim.doing_now`.
##
## Se dibuja como los demás marcadores del mundo —chapa que mira a cámara, ver
## [ParajeMarkers] y [TrapMarkers]— pero con una diferencia de fondo: un paraje
## es un sitio y no se mueve, y esto va pegado a una persona que anda. Por eso
## el soporte sigue la posición cada fotograma y la chapa sólo se REPINTA
## cuando cambia algo, que es lo caro.

## Alto sobre los pies, en metros. Una persona mide 1,7: esto la deja justo
## encima de la cabeza sin despegarse de ella.
const HEIGHT := 2.5

## A partir de aquí no se dibuja. Más lejos la chapa es un píxel de color y
## sólo ensucia el valle.
const RANGE := 260.0

## Cuánto tiene que moverse el progreso para volver a pintar la chapa. Repintar
## por fotograma es un `SubViewport` entero por artesano y por cuadro para un
## dato que avanza despacio.
const REPAINT_STEP := 0.02

## Tamaño de la chapa, en píxeles.
const BADGE_WIDTH := 84
const BADGE_HEIGHT := 34

var _camera: Camera3D
var _sim: SettlementSim

## Una entrada por persona que esté fabricando: soporte, chapa y lo último que
## se pintó.
var _badges: Dictionary = {}


func setup(camera: Camera3D, sim: SettlementSim) -> void:
	_camera = camera
	_sim = sim


func _process(_delta: float) -> void:
	Cronometro.tramo_raiz("vista: marcas de trabajo")
	if _sim == null:
		Cronometro.cierra("vista: marcas de trabajo")
		return
	# La cámara ACTIVA, no la que se pasó al montar. La partida tiene una sola,
	# pero las sondas montan la suya para mirar de cerca, y con la guardada el
	# recorte por distancia medía desde un sitio donde no estaba nadie mirando.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		camera = _camera
	if camera == null:
		Cronometro.cierra("vista: marcas de trabajo")
		return

	var alive := {}
	for person: Inhabitant in _sim.people:
		var work := _sim.doing_now(person)
		if work.is_empty():
			continue
		var origin := person.position + Vector3(0.0, HEIGHT, 0.0)
		if camera.global_position.distance_to(origin) > RANGE:
			continue
		alive[person.id] = true
		_update(person, work, origin)

	for id: int in _badges.keys():
		if alive.has(id):
			continue
		(_badges[id]["holder"] as Node).queue_free()
		_badges.erase(id)
	Cronometro.cierra("vista: marcas de trabajo")


func _update(person: Inhabitant, work: Dictionary, origin: Vector3) -> void:
	var kind: int = work["glyph"]
	var progress: float = work["progress"]

	if not _badges.has(person.id):
		_badges[person.id] = _build()
	var entry: Dictionary = _badges[person.id]
	(entry["holder"] as Node3D).global_position = origin

	# La chapa se rehace sólo si cambia la pieza o el progreso da un paso. Ver
	# `REPAINT_STEP`.
	var moved: bool = absf(progress - float(entry["progress"])) >= REPAINT_STEP
	if int(entry["kind"]) == kind and not moved:
		return
	entry["kind"] = kind
	entry["progress"] = progress
	_paint(entry, work)


func _build() -> Dictionary:
	var holder := Node3D.new()
	add_child(holder)

	var view := SubViewport.new()
	view.size = Vector2i(BADGE_WIDTH, BADGE_HEIGHT)
	view.transparent_bg = true
	view.disable_3d = true
	# A demanda y no siempre: lo que se pinta cambia despacio, y con
	# `UPDATE_ALWAYS` esto sería un render por artesano y por fotograma.
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	holder.add_child(view)

	var badge := CraftBadge.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(badge)
	badge.size = Vector2(BADGE_WIDTH, BADGE_HEIGHT)

	var icon := MateriaIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(icon)
	var box := float(BADGE_HEIGHT) - CraftBadge.BORDER * 3.0
	icon.size = Vector2(box, box)
	icon.position = Vector2(CraftBadge.BORDER * 1.5, CraftBadge.BORDER * 1.5)

	var plate := Sprite3D.new()
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.texture = view.get_texture()
	plate.pixel_size = 0.022
	# Por delante del terreno y de los árboles: una chapa medio tapada por una
	# rama no dice nada, y no está señalando un punto del suelo que haya que
	# ver ocluido.
	plate.no_depth_test = true
	plate.render_priority = 2
	plate.shaded = false
	holder.add_child(plate)

	return {
		"holder": holder, "view": view, "badge": badge, "icon": icon,
		"kind": -1, "progress": -1.0,
	}


func _paint(entry: Dictionary, work: Dictionary) -> void:
	var tint: Color = work["tint"]
	var badge := entry["badge"] as CraftBadge
	badge.tint = tint
	badge.progress = float(work["progress"])
	badge.queue_redraw()

	var icon := entry["icon"] as MateriaIcon
	icon.glyph = int(work["glyph"]) as MateriaIcon.Glyph
	icon.tint = tint
	icon.queue_redraw()

	# Un solo cuadro: lo pintado se queda en la textura hasta el siguiente
	# cambio.
	(entry["view"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
