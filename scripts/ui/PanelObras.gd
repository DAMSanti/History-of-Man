class_name PanelObras
extends RefCounted
## Lo que la banda ha PUESTO en el valle, para poder mirarlo pieza a pieza.
##
## Sale de [GameUI] y es la hermana de «Entidades». Aquélla cuenta lo que EXISTE
## en el valle —gente, fauna, árboles, props—, sembrado por el mundo o nacido
## con él; ésta cuenta lo otro: una trampa, una nasa, el hogar del abrigo, el
## vivac de anoche.
##
## Va en ventana propia y no como una familia más del censo de entidades, que
## fue el primer intento: ahí quedaba enterrada entre ciento ochenta mil pinos y
## había que saber que estaba para encontrarla. Y es una herramienta que se abre
## con una pregunta muy concreta en la cabeza —«¿el foso se está dibujando como
## un foso?»— así que tiene que tener su botón.
##
## Lo que cuenta lo lleva [CensoDeObras]; aquí sólo se pinta.

## Anchos de la lista, medidos contra la ventana.
const NOMBRE := 210
const CUANTAS := 60

var ui: GameUI

## Qué familia se está recorriendo, cuál de sus fichas y qué pieza era.
##
## La identidad y no sólo el número, por lo mismo que en [PanelCenso]: las
## listas se vuelven a pedir en cada repintado y una trampa se puede perder por
## el camino, así que con el índice solo la ficha «3/8» acababa enseñando otra
## cosa sin avisar.
var _grupo := ""
var _indice := 0
var _id := ""

## Desde dónde se midió «de más cerca a más lejos». Se congela al entrar: la
## ficha lleva la cámara a la pieza, así que midiendo desde la cámara viva la
## que estás mirando vuelve a ser la número uno en cada repintado.
var _ancla := Vector3.ZERO


func _init(panel: GameUI) -> void:
	ui = panel


func show_obras() -> void:
	var body := ui._window("obras", "Obras")
	ui._clear(body)
	if ui.sim == null or ui.census == null or ui.census.obras == null:
		ui._text(body, "Sin partida.")
		return

	if not _grupo.is_empty():
		_ficha(body)
		return

	ui._text(body, "Todo lo que la banda deja plantado en el valle. Al revés "
		+ "—pinchar algo en el mundo y que se abra su ficha— ya existe y no "
		+ "resuelve lo mismo: para pinchar una trampa hay que haberla "
		+ "encontrado antes, y encontrarla es justo lo que aquí se intenta.",
		true)

	var grupos := ui.census.obras.groups()
	if grupos.is_empty():
		ui._text(body, "La banda no ha puesto nada todavía: ni una trampa, ni "
			+ "una nasa, ni el hogar. Todo esto aparece según se levanta.", true)
		return

	var total := 0
	for grupo: Dictionary in grupos:
		total += int(grupo["count"])
	ui._text(body, "%d obras de %d clases." % [total, grupos.size()])

	var familia := ""
	for grupo: Dictionary in grupos:
		if String(grupo["family"]) != familia:
			familia = String(grupo["family"])
			ui._heading(body, familia.to_upper())
		_fila_de_grupo(body, grupo)


## Una clase de obra: cómo se llama, cuántas hay y el botón de entrar.
func _fila_de_grupo(body: VBoxContainer, grupo: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)

	var nombre := Label.new()
	nombre.text = String(grupo["label"])
	nombre.custom_minimum_size = Vector2(NOMBRE, 0)
	nombre.add_theme_font_size_override("font_size", 12)
	nombre.add_theme_color_override("font_color", UISkin.INK)
	row.add_child(nombre)

	var cuantas := Label.new()
	cuantas.text = "%d" % int(grupo["count"])
	cuantas.custom_minimum_size = Vector2(CUANTAS, 0)
	cuantas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cuantas.add_theme_font_size_override("font_size", 12)
	cuantas.add_theme_color_override("font_color", UISkin.OCHRE)
	row.add_child(cuantas)

	var nota := Label.new()
	nota.text = String(grupo["note"])
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nota.add_theme_font_size_override("font_size", 10)
	nota.add_theme_color_override("font_color", UISkin.INK_FAINT)
	row.add_child(nota)

	var entrar := Button.new()
	entrar.text = "ver"
	entrar.custom_minimum_size = Vector2(44, 22)
	entrar.pressed.connect(func() -> void:
		_grupo = String(grupo["key"])
		_indice = 0
		_id = ""
		_ancla = _mirando()
		show_obras())
	row.add_child(entrar)


## La ficha de una obra concreta, con la cámara puesta en ella.
func _ficha(body: VBoxContainer) -> void:
	var fichas := ui.census.obras.entries(_grupo, _ancla)
	if fichas.is_empty():
		ui._text(body, "Ya no queda ninguna de éstas.")
		_boton_volver(body)
		return

	# Se sigue LA MISMA pieza mientras exista, aunque la lista se reordene.
	if not _id.is_empty():
		for i in range(fichas.size()):
			if String(fichas[i]["id"]) == _id:
				_indice = i
				break
	_indice = clampi(_indice, 0, fichas.size() - 1)
	var ficha: Dictionary = fichas[_indice]
	_id = String(ficha["id"])

	var barra := HBoxContainer.new()
	barra.add_theme_constant_override("separation", 6)
	body.add_child(barra)

	var atras := Button.new()
	atras.text = "◀"
	atras.custom_minimum_size = Vector2(30, 22)
	atras.pressed.connect(func() -> void:
		_indice = maxi(_indice - 1, 0)
		_id = ""
		show_obras())
	barra.add_child(atras)

	var cuenta := Label.new()
	cuenta.text = "%d / %d" % [_indice + 1, fichas.size()]
	cuenta.custom_minimum_size = Vector2(70, 0)
	cuenta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cuenta.add_theme_font_size_override("font_size", 12)
	barra.add_child(cuenta)

	var alante := Button.new()
	alante.text = "▶"
	alante.custom_minimum_size = Vector2(30, 22)
	alante.pressed.connect(func() -> void:
		_indice = mini(_indice + 1, fichas.size() - 1)
		_id = ""
		show_obras())
	barra.add_child(alante)

	var ir := Button.new()
	ir.text = "llevar la cámara"
	ir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ir.pressed.connect(func() -> void:
		_llevar_camara(ficha["pos"] as Vector3))
	barra.add_child(ir)

	ui._heading(body, String(ficha["title"]).to_upper())
	for linea: String in (ficha["lines"] as Array[String]):
		ui._text(body, linea)
	_boton_volver(body)


func _boton_volver(body: VBoxContainer) -> void:
	body.add_child(HSeparator.new())
	var volver := Button.new()
	volver.text = "◀ todas las obras"
	volver.pressed.connect(func() -> void:
		_grupo = ""
		_id = ""
		show_obras())
	body.add_child(volver)


## Desde dónde se mide «de más cerca a más lejos».
func _mirando() -> Vector3:
	if ui.camera != null:
		return ui.camera.target_position
	if ui.sim != null:
		return ui.sim.home_position
	return Vector3.ZERO


## Lleva la cámara a un punto, y se acerca sólo si estaba lejos: el zoom es del
## jugador, y arrebatárselo cada vez que pulsa una ficha es de las cosas que
## más molestan de una herramienta de este tipo.
func _llevar_camara(point: Vector3) -> void:
	if ui.camera == null:
		return
	ui.camera.set_target(point)
	var cerca := ui.camera.min_distance * 1.6
	if ui.camera.orbit_distance > cerca:
		ui.camera.set_distance(cerca)
