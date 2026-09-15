class_name FichaDeRumbo
extends PanelContainer
## La ficha para mandar una expedición hacia un rumbo: quién va, cuántas jornadas
## y lo que cuesta, escrito antes de confirmar.
##
## INTERFAZ §4, «El rumbo de la expedición»; el mecanismo, SISTEMAS §4. La usan el
## mapa regional y el valle, con la misma ficha. **Aquí no se cuenta nada**: el
## coste es [Expedicion.hace_falta_para], quién puede ir es [Expedicion.puede_ir],
## el pasillo es [Expedicion.pasillo_hacia] y quien manda es [Expedicion.mandar_a].

## Cambió lo que se va a recorrer: la flecha se rehace con este pasillo.
signal cambiada(pasillo: Pasillo)
## Se ha mandado, o se ha cancelado: quien la abrió la quita.
signal cerrada(mandada: bool)

const ANCHO := 380
const ALTO_DE_LA_LISTA := 240

var sim: SettlementSim = null
var rumbo: float = 0.0
var jornadas: int = Expedicion.JORNADAS_PROPUESTAS
var marcados: Array[int] = []
var _de_donde: String = ""
var _columna: VBoxContainer = null


## Abre la ficha para la simulación de un campamento hacia un rumbo. Marca de
## entrada a los primeros que pueden ir, para que mandar sea un clic.
func abrir(para: SettlementSim, hacia: float, nombre: String) -> void:
	if sim != para:
		marcados.clear()
		for persona: Inhabitant in para.people:
			if marcados.size() >= Expedicion.MINIMO_PARA_SALIR:
				break
			if para.expedicion.puede_ir(persona):
				marcados.append(persona.id)
	sim = para
	_de_donde = nombre
	apuntar(hacia)


## Cambia el rumbo sin tocar a quién va ni cuántas jornadas.
func apuntar(hacia: float) -> void:
	rumbo = fposmod(hacia, 360.0)
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


## El pasillo que se recorrería con lo elegido. Es el de la flecha.
func pasillo() -> Pasillo:
	return sim.expedicion.pasillo_hacia(rumbo, jornadas) if sim != null else null


## Por qué no se puede mandar, o vacío. Lo mismo que comprueba [Expedicion.mandar_a].
func bloqueo() -> String:
	if sim == null:
		return "no hay campamento"
	if sim.expedicion.en_marcha():
		return "ya hay una expedición fuera"
	var pueden := 0
	for persona: Inhabitant in sim.people:
		if marcados.has(persona.id) and sim.expedicion.puede_ir(persona):
			pueden += 1
	if pueden < Expedicion.MINIMO_PARA_SALIR:
		return "hacen falta %d adultos que puedan ir" % Expedicion.MINIMO_PARA_SALIR
	var falta := sim.expedicion.lo_que_falta(pueden, jornadas)
	if not falta.is_empty():
		return "falta " + ", ".join(falta)
	return ""


func mandar() -> bool:
	if sim == null or not bloqueo().is_empty():
		return false
	var salio := sim.expedicion.mandar_a(marcados, rumbo, jornadas)
	if salio:
		cerrada.emit(true)
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
	var recorrido := pasillo()
	_rotulo("Hacia el %s · %.0f km de ida" % [Expedicion.nombre_del_rumbo(rumbo),
		recorrido.largo_m / 1000.0 if recorrido != null else 0.0], 12, UISkin.INK)

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
	var mandar_boton := Button.new()
	mandar_boton.text = "Mandar"
	mandar_boton.disabled = not motivo.is_empty()
	mandar_boton.pressed.connect(func() -> void: mandar())
	botones.add_child(mandar_boton)
	var cancelar := Button.new()
	cancelar.text = "Cancelar"
	cancelar.pressed.connect(func() -> void: cerrada.emit(false))
	botones.add_child(cancelar)


func _rotulo(texto: String, letra: int, color: Color) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(ANCHO - 20, 0)
	etiqueta.add_theme_font_size_override("font_size", letra)
	etiqueta.add_theme_color_override("font_color", color)
	_columna.add_child(etiqueta)
