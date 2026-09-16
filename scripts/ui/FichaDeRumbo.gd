class_name FichaDeRumbo
extends PanelContainer
## La ficha para mandar una expedición: hacia cuál de los ocho rumbos, quién va,
## cuántas jornadas y lo que cuesta, escrito antes de confirmar.
##
## INTERFAZ §4; el mecanismo, SISTEMAS §4. Se abre en el mapa regional, con la R o
## viniendo del botón «Rumbo» del valle. **Aquí no se cuenta nada**: los rumbos son
## [Expedicion.rumbos_posibles], el coste [Expedicion.hace_falta_para], quién puede ir
## [Expedicion.puede_ir], el motivo [Expedicion.motivo_para], el pasillo
## [Expedicion.pasillo_hacia] y quien manda [Expedicion.mandar_a].
##
## **Desde el 2026-09-16 el rumbo no se pincha**: es uno de ocho botones, apagados los
## que no tienen nada al alcance (decisión del usuario del 2026-09-15).

## Cambió lo que se va a recorrer: la flecha se rehace con este pasillo.
signal cambiada(pasillo: Pasillo)
## Se ha mandado, o se ha cancelado; y si se manda desde el valle, si se vuelve a él.
## Quien la abrió la quita.
signal cerrada(mandada: bool, volver_al_valle: bool)

const ANCHO := 380
const ALTO_DE_LA_LISTA := 240

## Los ocho rumbos como se ven en la rosa, fila a fila: el centro, vacío.
const ROSA: Array[float] = [315.0, 0.0, 45.0, 270.0, -1.0, 90.0, 225.0, 180.0, 135.0]
const LETRAS := {0.0: "N", 45.0: "NE", 90.0: "E", 135.0: "SE", 180.0: "S",
	225.0: "SO", 270.0: "O", 315.0: "NO"}

var sim: SettlementSim = null
var rumbo: float = 0.0
var jornadas: int = Expedicion.JORNADAS_PROPUESTAS
var marcados: Array[int] = []
## Los rumbos que se ofrecen, calculados al abrir: ocho pasillos largos, unos 30 ms
## desde la cueva de casa (SISTEMAS §4). Se rehacen al volver a abrirla.
var posibles: Array[float] = []
## Si se abrió viniendo del botón del valle: entonces se elige volver o quedarse.
var desde_el_valle := false
var _de_donde: String = ""
var _columna: VBoxContainer = null


## Abre la ficha para la simulación de un campamento. Marca de entrada a los primeros
## que pueden ir, para que mandar sea un clic, y apunta al primer rumbo que se ofrece.
func abrir(para: SettlementSim, nombre: String, viene_del_valle: bool = false) -> void:
	if sim != para:
		marcados.clear()
		for persona: Inhabitant in para.people:
			if marcados.size() >= Expedicion.MINIMO_PARA_SALIR:
				break
			if para.expedicion.puede_ir(persona):
				marcados.append(persona.id)
	sim = para
	_de_donde = nombre
	desde_el_valle = viene_del_valle
	posibles = para.expedicion.rumbos_posibles()
	if not posibles.is_empty() and not posibles.has(rumbo):
		rumbo = posibles[0]
	_pintar()
	cambiada.emit(pasillo())


## Cambia el rumbo sin tocar a quién va ni cuántas jornadas. Sólo a uno que se ofrece.
func apuntar(hacia: float) -> void:
	var grados := fposmod(hacia, 360.0)
	if not posibles.has(grados):
		return
	rumbo = grados
	_pintar()
	cambiada.emit(pasillo())


func elegir_jornadas(cuantas: int) -> void:
	if not Pasillo.jornadas_validas(cuantas):
		return
	jornadas = cuantas
	_pintar()
	cambiada.emit(pasillo())


func marcar(id: int, puesto: bool) -> void:
	if puesto and not marcados.has(id):
		marcados.append(id)
	elif not puesto:
		marcados.erase(id)
	_pintar()


## El pasillo que se recorrería con lo elegido, o null sin rumbo que se ofrezca. Es el
## de la flecha.
func pasillo() -> Pasillo:
	if sim == null or not posibles.has(rumbo):
		return null
	return sim.expedicion.pasillo_hacia(rumbo, jornadas)


## Los pasillos más largos de los demás rumbos que se ofrecen, para que la flecha
## enseñe hacia dónde más se puede ir.
func los_otros_rumbos() -> Array[Pasillo]:
	var otros: Array[Pasillo] = []
	if sim == null:
		return otros
	for hacia: float in posibles:
		if hacia != rumbo:
			var largo := sim.expedicion.pasillo_hacia(hacia, Pasillo.JORNADAS_MAXIMAS)
			if largo != null:
				otros.append(largo)
	return otros


## Por qué no se puede mandar, o vacío. Lo mismo que comprueba [Expedicion.mandar_a].
func bloqueo() -> String:
	if sim == null:
		return "no hay campamento"
	if posibles.is_empty():
		return "no queda nada por descubrir al alcance de una expedición"
	var pueden := 0
	for persona: Inhabitant in sim.people:
		if marcados.has(persona.id) and sim.expedicion.puede_ir(persona):
			pueden += 1
	return sim.expedicion.motivo_para(pueden, jornadas)


func mandar(volver_al_valle: bool = false) -> bool:
	if sim == null or not bloqueo().is_empty():
		return false
	var salio := sim.expedicion.mandar_a(marcados, rumbo, jornadas)
	if salio:
		cerrada.emit(true, volver_al_valle)
	return salio


# --- lo que se ve ----------------------------------------------------------------

func _ready() -> void:
	theme = UISkin.build_theme()
	custom_minimum_size = Vector2(ANCHO, 0)
	_pintar()
	# CENTRADA EN EL LADO IZQUIERDO, recolocada cuando cambia su alto o el de la
	# pantalla. A una altura fija se salía por abajo a 1280×720, y anclada al
	# centro se iba por arriba: colgando de una capa de lienzo, el anclaje no
	# veía el tamaño de la pantalla (`NieblaCaptura`, 2026-09-14).
	resized.connect(_colocar)
	get_viewport().size_changed.connect(_colocar)
	_colocar.call_deferred()


func _colocar() -> void:
	var alto := get_viewport().get_visible_rect().size.y
	position = Vector2(16.0, maxf((alto - size.y) * 0.5, 8.0))


func _pintar() -> void:
	if _columna == null:
		var margen := MarginContainer.new()
		for lado: String in ["left", "right", "top", "bottom"]:
			margen.add_theme_constant_override("margin_" + lado, 10)
		add_child(margen)
		_columna = VBoxContainer.new()
		_columna.add_theme_constant_override("separation", 6)
		margen.add_child(_columna)
	for hijo: Node in _columna.get_children():
		hijo.queue_free()
	if sim == null:
		return

	_rotulo("EXPEDICIÓN DESDE %s" % _de_donde.to_upper(), 13, UISkin.OCHRE)
	_pintar_la_rosa()
	var recorrido := pasillo()
	if recorrido != null:
		_rotulo("Hacia el %s · %.0f km de ida" % [Expedicion.nombre_del_rumbo(rumbo),
			recorrido.largo_m / 1000.0], 12, UISkin.INK)

	_rotulo("Quién va:", 11, UISkin.INK_SOFT)
	var desplazable := ScrollContainer.new()
	# La lista, como mucho un cuarto largo del alto de la pantalla.
	var alto := ALTO_DE_LA_LISTA
	if is_inside_tree():
		alto = mini(alto, int(get_viewport().get_visible_rect().size.y * 0.22))
	desplazable.custom_minimum_size = Vector2(ANCHO - 20, mini(alto, sim.people.size() * 26))
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_columna.add_child(desplazable)
	var lista := VBoxContainer.new()
	desplazable.add_child(lista)
	for persona: Inhabitant in sim.people:
		if not sim.expedicion.puede_ir(persona):
			continue
		var casilla := CheckBox.new()
		casilla.text = "%s, %d años" % [persona.given_name, persona.age_years]
		casilla.button_pressed = marcados.has(persona.id)
		casilla.add_theme_font_size_override("font_size", 12)
		var quien := persona.id
		# Diferido: repintar desde la señal de la casilla es borrar el nodo que la
		# emite. Lo mismo que en la tarjeta de la expedición de antes.
		casilla.toggled.connect(func(puesto: bool) -> void:
			marcar.call_deferred(quien, puesto))
		lista.add_child(casilla)

	var fila := HBoxContainer.new()
	_columna.add_child(fila)
	var cuantas := Label.new()
	cuantas.text = "Jornadas:"
	cuantas.add_theme_font_size_override("font_size", 12)
	fila.add_child(cuantas)
	var selector := OptionButton.new()
	selector.add_theme_font_size_override("font_size", 12)
	var opciones: Array[int] = []
	var dias := Pasillo.JORNADAS_MINIMAS
	while dias <= Pasillo.JORNADAS_MAXIMAS:
		opciones.append(dias)
		selector.add_item("%d" % dias)
		dias += Pasillo.JORNADAS_DE_PASO
	selector.selected = maxi(opciones.find(jornadas), 0)
	selector.item_selected.connect(func(donde: int) -> void:
		elegir_jornadas.call_deferred(opciones[donde]))
	fila.add_child(selector)

	var van := maxi(marcados.size(), Expedicion.MINIMO_PARA_SALIR)
	var hace_falta := sim.expedicion.hace_falta_para(van, jornadas)
	_rotulo("Se llevan %.0f raciones y %.0f de leña, que no vuelven, y %.0f pieles curtidas de tienda, que sí. Cuesta igual si vuelven sin nada." % [
		float(hace_falta["raciones"]), float(hace_falta["lena"]),
		float(hace_falta["piel"])], 11, UISkin.INK)

	var motivo := bloqueo()
	if not motivo.is_empty():
		_rotulo(motivo, 11, UISkin.ALARM)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	_columna.add_child(botones)
	# DESDE EL VALLE SE ELIGE ADÓNDE SE VUELVE (SISTEMAS §4, punto 3, decisión del
	# usuario); desde el regional con la R se queda en el regional.
	var textos := ["Mandar y volver al valle", "Mandar y quedarse"] if desde_el_valle else ["Mandar"]
	for i in range(textos.size()):
		var mandar_boton := Button.new()
		mandar_boton.text = textos[i]
		mandar_boton.disabled = not motivo.is_empty()
		var volver := desde_el_valle and i == 0
		mandar_boton.pressed.connect(func() -> void: mandar(volver))
		botones.add_child(mandar_boton)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func() -> void: cerrada.emit(false, false))
	botones.add_child(cancelar)


## La rosa de los ocho rumbos: apagados los que no tienen nada al alcance, y marcado el
## elegido.
func _pintar_la_rosa() -> void:
	var rosa := GridContainer.new()
	rosa.columns = 3
	rosa.add_theme_constant_override("h_separation", 4)
	rosa.add_theme_constant_override("v_separation", 4)
	_columna.add_child(rosa)
	for hacia: float in ROSA:
		if hacia < 0.0:
			var centro := Label.new()
			centro.text = "·"
			centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rosa.add_child(centro)
			continue
		var boton := Button.new()
		boton.text = LETRAS[hacia]
		boton.custom_minimum_size = Vector2(44, 26)
		boton.toggle_mode = true
		boton.button_pressed = posibles.has(hacia) and hacia == rumbo
		boton.disabled = not posibles.has(hacia)
		boton.tooltip_text = ("Hacia el %s" % Expedicion.nombre_del_rumbo(hacia)) if posibles.has(hacia) \
			else "Hacia el %s no queda nada al alcance" % Expedicion.nombre_del_rumbo(hacia)
		# Diferido, como las casillas: repintar borra el botón que emite.
		boton.pressed.connect(func() -> void: apuntar.call_deferred(hacia))
		rosa.add_child(boton)


func _rotulo(texto: String, letra: int, color: Color) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(ANCHO - 20, 0)
	etiqueta.add_theme_font_size_override("font_size", letra)
	etiqueta.add_theme_color_override("font_color", color)
	_columna.add_child(etiqueta)
