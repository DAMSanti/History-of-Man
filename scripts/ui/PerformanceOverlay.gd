class_name PerformanceOverlay
extends CanvasLayer
## Overlay de rendimiento. Muestra FPS, coste de frame y carga de render.
##
## Los valores salen de la clase [Performance] del motor, no de contadores
## propios: son los mismos que ve el profiler del editor, así que sirven para
## comparar entre ejecuciones y para decidir dónde optimizar con datos.

## Cada cuánto se refresca el texto, en segundos. Refrescarlo cada frame haría
## que los números bailasen tanto que no se pueden leer.
@export var update_interval: float = 0.25

## Ventana de historial para el mínimo y la mediana de FPS, en segundos
@export var history_seconds: float = 5.0

## Tecla que muestra u oculta el overlay
@export var toggle_key: Key = KEY_F3

## Umbrales de color para los FPS
@export var fps_good: float = 55.0
@export var fps_warn: float = 30.0

var _fps_label: Label
var _detail_label: Label
var _accumulator: float = 0.0
var _history: PackedFloat32Array = PackedFloat32Array()
var _history_size: int = 0


func _ready() -> void:
	layer = 128
	# Debe seguir midiendo aunque el juego esté en pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	_history_size = maxi(1, int(history_seconds / maxf(update_interval, 0.01)))
	_build_ui()
	_refresh()


func _build_ui() -> void:
	# Abajo a la izquierda, que es la unica esquina libre. Estuvo arriba a la
	# derecha y ahi TAPABA los botones de pausa, play y avance rapido: se
	# dibuja en la capa 128, o sea por encima de la interfaz, asi que los
	# botones seguian estando y respondiendo pero no se veian debajo de las
	# letras rojas. Visto en una captura de `VistaProbe`, no razonado.
	# Arriba a la derecha esta la barra de estado y abajo a la derecha la de
	# ventanas -ver `GameUI._build_clock` y `GameUI._build_taskbar`-.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left", 10)
	add_child(margin)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_fps_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.9))
	vbox.add_child(_detail_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == toggle_key:
			visible = not visible
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return

	_accumulator += delta
	if _accumulator < update_interval:
		return
	_accumulator = 0.0
	_refresh()


func _refresh() -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	_push_history(fps)

	_fps_label.text = "%d FPS   (min %d · med %d)" % [
		roundi(fps), roundi(_history_min()), roundi(_history_median())]
	_fps_label.add_theme_color_override("font_color", _fps_color(fps))

	var frame_ms := 1000.0 / maxf(fps, 0.001)
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0

	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var objects := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

	var vram := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	var ram := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)

	_detail_label.text = "\n".join([
		"frame %6.1f ms    proceso %.1f  fisica %.1f" % [frame_ms, process_ms, physics_ms],
		"draw calls %5d    triangulos %s" % [int(draw_calls), _format_count(primitives)],
		"objetos    %5d    nodos %d" % [int(objects), int(nodes)],
		"VRAM     %6.0f MB  RAM %.0f MB" % [vram, ram],
		"F3 para ocultar"
	])


func _fps_color(fps: float) -> Color:
	if fps >= fps_good:
		return Color(0.45, 0.95, 0.5)
	if fps >= fps_warn:
		return Color(0.98, 0.82, 0.35)
	return Color(1.0, 0.45, 0.45)


func _push_history(fps: float) -> void:
	_history.append(fps)
	while _history.size() > _history_size:
		_history.remove_at(0)


func _history_min() -> float:
	if _history.is_empty():
		return 0.0
	var m := _history[0]
	for v in _history:
		m = minf(m, v)
	return m


func _history_median() -> float:
	if _history.is_empty():
		return 0.0
	var sorted := Array(_history)
	sorted.sort()
	return sorted[sorted.size() / 2]


static func _format_count(value: float) -> String:
	if value >= 1000000.0:
		return "%.1f M" % (value / 1000000.0)
	if value >= 1000.0:
		return "%.0f k" % (value / 1000.0)
	return "%d" % int(value)
