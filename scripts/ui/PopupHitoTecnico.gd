class_name PopupHitoTecnico
extends Control
## Ventana modal para presentar y celebrar hitos tecnológicos con vídeo de acción.
##
## Aparece cuando la banda aprende una nueva técnica durante la partida, o
## cuando el jugador pulsa "Ver hito" en el árbol de técnicas. Muestra el clip
## cinematográfico de la acción arqueológica (una sola reproducción), el relato
## de la técnica y sus efectos para la banda.

signal closed()

const TECH_VIDEOS := {
	TechTree.Tech.NUCLEO: "tech_nucleo",
	TechTree.Tech.HOJA: "tech_hoja",
	TechTree.Tech.AGUJA: "tech_aguja",
	TechTree.Tech.LAZO: "tech_lazo",
	TechTree.Tech.CEPO: "tech_cepo",
	TechTree.Tech.RED_AVES: "tech_red_aves",
	TechTree.Tech.FOSO: "tech_foso",
	TechTree.Tech.OJEO: "tech_ojeo",
	TechTree.Tech.AZAGAYA: "tech_azagaya",
	TechTree.Tech.PROPULSOR: "tech_propulsor",
	TechTree.Tech.ARCO: "tech_arco",
	TechTree.Tech.PESQUERA: "tech_pesquera",
	TechTree.Tech.NASA: "tech_nasa",
	TechTree.Tech.ANZUELO: "tech_anzuelo",
	TechTree.Tech.RED: "tech_red",
	TechTree.Tech.ARPON: "tech_arpon",
	TechTree.Tech.PASARELA: "tech_pasarela",
	TechTree.Tech.PIRAGUA: "tech_piragua",
	TechTree.Tech.ARTE: "tech_arte",
}

## Efecto concreto o utilidad que habilita cada técnica.
const TECH_EFFECTS := {
	TechTree.Tech.NUCLEO: "Mejora el rendimiento de la talla lítica y reduce el desperdicio de sílex.",
	TechTree.Tech.HOJA: "Permite fabricar herramientas laminares y buriles de alta precisión.",
	TechTree.Tech.AGUJA: "Permite coser prendas ajustadas de cuero y tendón para soportar el invierno.",
	TechTree.Tech.LAZO: "Permite armar lazos de fibra en pasos de caza menor que rinden solos.",
	TechTree.Tech.CEPO: "Permite armar cepos de losa de gran durabilidad para piezas medianas.",
	TechTree.Tech.RED_AVES: "Permite tender redes en bebederos para capturar aves y obtener plumas.",
	TechTree.Tech.FOSO: "Permite excavar fosos camuflados para capturar pieza mayor (ciervo y jabalí).",
	TechTree.Tech.OJEO: "Organiza a los cazadores en batidas coordinadas aumentando las capturas.",
	TechTree.Tech.AZAGAYA: "Permite armar azagayas con punta de asta para cazar a distancia.",
	TechTree.Tech.PROPULSOR: "Duplica el alcance y la fuerza de lanzamiento de las azagayas.",
	TechTree.Tech.ARCO: "Permite cazar al acecho con tiro rápido y certero a gran distancia.",
	TechTree.Tech.PESQUERA: "Permite construir presas de piedra que canalizan la pesca fluvial.",
	TechTree.Tech.NASA: "Permite calar nasas de mimbre que capturan truchas de forma autónoma.",
	TechTree.Tech.ANZUELO: "Permite la pesca individual con sedal de fibra y anzuelo de hueso.",
	TechTree.Tech.RED: "Permite calar grandes redes de malla en el río para capturas masivas.",
	TechTree.Tech.ARPON: "Permite arponear salmones con púas retenedoras durante el remonte.",
	TechTree.Tech.PASARELA: "Permite cruzar arroyos y cauces estrechos a pie seco sin riesgo de carga.",
	TechTree.Tech.PIRAGUA: "Abre la navegación en aguas profundas y el acceso a la otra orilla del río.",
	TechTree.Tech.ARTE: "Fija el saber y la memoria de la banda en las paredes del abrigo.",
}

var _queue: Array[TechTree.Tech] = []
var _current_tech: int = -1

var _backdrop: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _video_player: VideoStreamPlayer
var _video_fallback: TextureRect
var _desc_label: Label
var _effect_label: Label
var _replay_btn: Button
var _continue_btn: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.03, 0.02, 0.82)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 560)
	_panel.add_theme_stylebox_override("panel", UISkin.window_box())
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Encabezado
	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", 2)
	vbox.add_child(header_box)

	_subtitle_label = Label.new()
	_subtitle_label.text = "¡NUEVO HITO TÉCNICO!"
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", UISkin.OCHRE)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(_subtitle_label)

	_title_label = Label.new()
	_title_label.text = "TÉCNICA"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", UISkin.INK)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_box.add_child(_title_label)

	# Marco de Vídeo
	var video_frame := PanelContainer.new()
	video_frame.custom_minimum_size = Vector2(640, 360)
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0.02, 0.02, 0.02, 1.0)
	frame_box.border_color = UISkin.RULE
	frame_box.set_border_width_all(2)
	frame_box.set_corner_radius_all(4)
	video_frame.add_theme_stylebox_override("panel", frame_box)
	vbox.add_child(video_frame)

	_video_player = VideoStreamPlayer.new()
	_video_player.custom_minimum_size = Vector2(640, 360)
	_video_player.expand = true
	_video_player.loop = false
	_video_player.finished.connect(_on_video_finished)
	video_frame.add_child(_video_player)

	_video_fallback = TextureRect.new()
	_video_fallback.custom_minimum_size = Vector2(640, 360)
	_video_fallback.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_video_fallback.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_video_fallback.visible = false
	video_frame.add_child(_video_fallback)

	# Texto narrativo y utilidad
	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", UISkin.INK_SOFT)
	vbox.add_child(_desc_label)

	_effect_label = Label.new()
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.add_theme_font_size_override("font_size", 12)
	_effect_label.add_theme_color_override("font_color", UISkin.GREEN)
	vbox.add_child(_effect_label)

	# Barra inferior de botones
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	_replay_btn = Button.new()
	_replay_btn.text = "▶ Repetir"
	_replay_btn.custom_minimum_size = Vector2(90, 28)
	_replay_btn.pressed.connect(_on_replay_pressed)
	btn_row.add_child(_replay_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continuar"
	_continue_btn.custom_minimum_size = Vector2(110, 28)
	_continue_btn.pressed.connect(_on_continue_pressed)
	btn_row.add_child(_continue_btn)


## Encola una técnica aprendida para presentarla.
func queue_tech(tech: TechTree.Tech) -> void:
	if not _queue.has(tech):
		_queue.append(tech)
	if not visible:
		_show_next()


## Muestra directamente una técnica (por ejemplo, desde el árbol de técnicas).
func show_tech(tech: TechTree.Tech) -> void:
	_current_tech = int(tech)
	_present_current()


func _show_next() -> void:
	if _queue.is_empty():
		visible = false
		_current_tech = -1
		closed.emit()
		return
	_current_tech = int(_queue.pop_front())
	_present_current()


func _present_current() -> void:
	if _current_tech < 0 or not TechTree.CATALOGUE.has(_current_tech):
		visible = false
		return

	var tech := _current_tech as TechTree.Tech
	_title_label.text = TechTree.tech_name(tech).to_upper()
	_desc_label.text = TechTree.tech_desc(tech)
	_effect_label.text = "Habilidad ganada: " + TECH_EFFECTS.get(tech, "Nuevo conocimiento para la banda.")

	# Carga y reproducción de vídeo
	var vid_name: String = TECH_VIDEOS.get(tech, "")
	var stream_loaded := false

	if not vid_name.is_empty():
		var ogv_path := "res://videos/tech/%s.ogv" % vid_name
		if ResourceLoader.exists(ogv_path) or FileAccess.file_exists(ogv_path):
			var stream := VideoStreamTheora.new()
			stream.file = ogv_path
			_video_player.stream = stream
			_video_player.visible = true
			_video_fallback.visible = false
			if is_inside_tree():
				_video_player.play()
			stream_loaded = true

	if not stream_loaded:
		_video_player.stop()
		_video_player.visible = false
		# Fallback: intentar cargar imagen o textura representativa
		var img_path := "res://videos/tech/%s.png" % vid_name
		if FileAccess.file_exists(img_path):
			_video_fallback.texture = load(img_path)
			_video_fallback.visible = true
		else:
			_video_fallback.visible = false

	visible = true


func _on_video_finished() -> void:
	# El usuario solicitó que el vídeo se reproduzca una sola vez y quede en el fotograma final.
	_video_player.stop()


func _on_replay_pressed() -> void:
	if _video_player.visible and _video_player.stream != null:
		_video_player.play()


func _on_continue_pressed() -> void:
	if _video_player.is_playing():
		_video_player.stop()
	_show_next()
