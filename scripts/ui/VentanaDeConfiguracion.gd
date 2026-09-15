class_name VentanaDeConfiguracion
extends PanelContainer
## La ventana de configuración: pantalla, gráficos y sonido.
##
## INTERFAZ §8. **La misma para los dos menús** —el principal y el de ESC—: la
## abren con [MenuPrincipal.abrir_configuracion] y [MenuDelJuego.abrir_configuracion],
## que la crean igual. Aquí no se decide nada de lo que vale cada cosa: los niveles
## y cómo se aplica cada ajuste están en [Configuracion].
##
## Cada cambio se aplica y **se guarda al momento**. El modo y la resolución,
## además, **piden confirmación**: se aplican y, si en [CUENTA_ATRAS] segundos no se
## confirma, vuelve lo de antes —una resolución que el monitor no enseña no se
## puede deshacer pinchando en ella—.

## Se cierra: quien la abrió la quita.
signal cerrada

## Segundos para confirmar un cambio de modo o de resolución. De la spec.
const CUENTA_ATRAS := 10.0

const ANCHO := 640
const ETIQUETA := 260

## Las escalas de render que se ofrecen: las de los niveles y dos intermedias.
const ESCALAS: Array[float] = [0.5, 0.6, 0.77, 0.9, 1.0]
const VEGETACIONES: Array[float] = [0.25, 0.5, 0.75, 1.0]
const PASOS_DE_NUBE: Array[int] = [0, 6, 12, 20, 32]
## Las paradas del slider de la distancia del 3D: las de los niveles y las de en medio,
## más finas de cerca, donde cada metro cuenta, y el último, sin límite.
const DISTANCIAS_3D: Array[float] = [10.0, 20.0, 30.0, 40.0, 50.0, 70.0, 100.0, 120.0,
	150.0, 200.0, 300.0, 500.0, 1000.0, Configuracion.RADIO_3D_SIN_LIMITE]

var _pestanas: TabContainer
var _pantalla: VBoxContainer
var _graficos: VBoxContainer
var _sonido: VBoxContainer
var _confirmar: HBoxContainer
var _aviso: Label

## El cambio de pantalla que espera confirmación: el modo y la resolución de antes,
## y cuánto queda.
var pendiente := false
var restante := 0.0
var _modo_antes: Configuracion.Modo = Configuracion.Modo.MAXIMIZADA
var _resolucion_antes: Vector2i = Vector2i.ZERO


func _init() -> void:
	theme = UISkin.build_theme()
	add_theme_stylebox_override("panel", UISkin.window_box())
	custom_minimum_size = Vector2(ANCHO, 0)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	add_child(columna)

	var titulo := Label.new()
	titulo.text = "Configuración"
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", UISkin.OCHRE)
	columna.add_child(titulo)

	_pestanas = TabContainer.new()
	_pestanas.custom_minimum_size = Vector2(ANCHO - 24, 380)
	columna.add_child(_pestanas)
	_pantalla = _pestana("Pantalla")
	_graficos = _pestana("Gráficos")
	_sonido = _pestana("Sonido")

	_confirmar = HBoxContainer.new()
	_confirmar.add_theme_constant_override("separation", 8)
	_confirmar.visible = false
	columna.add_child(_confirmar)
	_aviso = Label.new()
	_aviso.add_theme_color_override("font_color", UISkin.OCHRE)
	_aviso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirmar.add_child(_aviso)
	_confirmar.add_child(_boton("Se queda así", confirmar))
	_confirmar.add_child(_boton("Volver a lo de antes", revertir))

	columna.add_child(_boton("Cerrar", func() -> void:
		if pendiente:
			revertir()
		cerrada.emit()))
	_pintar()


func _process(delta: float) -> void:
	avanzar(delta)


# --- lo que se puede hacer desde fuera: la prueba lo usa igual que los botones ---

func elegir_modo(modo: Configuracion.Modo) -> void:
	_cambiar_pantalla(func() -> void: Configuracion.modo = modo)


func elegir_resolucion(resolucion: Vector2i) -> void:
	_cambiar_pantalla(func() -> void: Configuracion.resolucion = resolucion)


func elegir_vsync(si: bool) -> void:
	Configuracion.vsync = si
	_aplicar_pantalla_y_guardar()


func elegir_tope(tope: int) -> void:
	Configuracion.tope = tope
	_aplicar_pantalla_y_guardar()


func elegir_nivel(nivel: Configuracion.Nivel) -> void:
	Configuracion.poner_nivel(nivel)
	_aplicar_graficos_y_guardar()


func elegir_ajuste(nombre: String, valor: Variant) -> void:
	Configuracion.poner_ajuste(nombre, valor)
	_aplicar_graficos_y_guardar()


func elegir_volumen(cual: String, valor: float) -> void:
	match cual:
		"general": Configuracion.volumen_general = clampf(valor, 0.0, 1.0)
		"musica": Configuracion.volumen_musica = clampf(valor, 0.0, 1.0)
		"efectos": Configuracion.volumen_efectos = clampf(valor, 0.0, 1.0)
	Configuracion.aplicar_sonido()
	Configuracion.guardar()


## Pasa el tiempo de la cuenta atrás. Lo llama `_process`, y la prueba a mano.
func avanzar(segundos: float) -> void:
	if not pendiente:
		return
	restante -= segundos
	if restante <= 0.0:
		revertir()
	else:
		_aviso.text = "¿Se queda así? Vuelve a lo de antes en %d s" % int(ceil(restante))


func confirmar() -> void:
	pendiente = false
	_confirmar.visible = false
	Configuracion.guardar()


func revertir() -> void:
	if not pendiente:
		return
	pendiente = false
	_confirmar.visible = false
	Configuracion.modo = _modo_antes
	Configuracion.resolucion = _resolucion_antes
	_aplicar_pantalla_y_guardar()


# --- por dentro ------------------------------------------------------------------

## Un cambio de modo o de resolución: se aplica ya, y se guarda lo de antes para
## volver si no se confirma. Si ya había uno esperando, lo de antes sigue siendo
## lo de antes del primero.
func _cambiar_pantalla(cambio: Callable) -> void:
	if not pendiente:
		_modo_antes = Configuracion.modo
		_resolucion_antes = Configuracion.resolucion
	cambio.call()
	Configuracion.aplicar_pantalla()
	pendiente = true
	restante = CUENTA_ATRAS
	_confirmar.visible = true
	_aviso.text = "¿Se queda así? Vuelve a lo de antes en %d s" % int(CUENTA_ATRAS)
	_pintar.call_deferred()


func _aplicar_pantalla_y_guardar() -> void:
	Configuracion.aplicar_pantalla()
	Configuracion.guardar()
	_pintar.call_deferred()


func _aplicar_graficos_y_guardar() -> void:
	Configuracion.aplicar_graficos(get_tree() if is_inside_tree() else null)
	Configuracion.guardar()
	# Diferido: repintar desde la señal del control es borrar el nodo que la emite.
	_pintar.call_deferred()


func _pestana(nombre: String) -> VBoxContainer:
	var desplazable := ScrollContainer.new()
	desplazable.name = nombre
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pestanas.add_child(desplazable)
	var dentro := VBoxContainer.new()
	dentro.add_theme_constant_override("separation", 6)
	dentro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(dentro)
	return dentro


func _pintar() -> void:
	for pestana: VBoxContainer in [_pantalla, _graficos, _sonido]:
		for hijo: Node in pestana.get_children():
			pestana.remove_child(hijo)
			hijo.queue_free()
	_pintar_pantalla()
	_pintar_graficos()
	_pintar_sonido()


func _pintar_pantalla() -> void:
	var modos := ["Pantalla completa", "Ventana", "Ventana maximizada"]
	_opciones(_pantalla, "Modo", modos, int(Configuracion.modo), func(i: int) -> void:
		elegir_modo(i as Configuracion.Modo))

	var lista := Configuracion.resoluciones()
	if not lista.has(Configuracion.resolucion):
		lista.append(Configuracion.resolucion)
	var textos: Array = []
	for r: Vector2i in lista:
		textos.append("%d × %d" % [r.x, r.y])
	var selector := _opciones(_pantalla, "Resolución", textos,
		lista.find(Configuracion.resolucion), func(i: int) -> void: elegir_resolucion(lista[i]))
	# SÓLO EN VENTANA, decisión del usuario del 2026-09-14: a pantalla completa y
	# maximizada Godot usa el tamaño del monitor.
	selector.disabled = Configuracion.modo != Configuracion.Modo.VENTANA
	if selector.disabled:
		_nota(_pantalla, "En pantalla completa y maximizada se usa la del monitor. Para dibujar a menos, la escala de render de Gráficos.")

	_casilla(_pantalla, "Sincronización vertical", Configuracion.vsync, elegir_vsync)
	var topes: Array = []
	for t: int in Configuracion.TOPES:
		topes.append("Sin tope" if t == 0 else "%d" % t)
	_opciones(_pantalla, "Tope de fotogramas", topes,
		Configuracion.TOPES.find(Configuracion.tope), func(i: int) -> void:
			elegir_tope(Configuracion.TOPES[i]))


func _pintar_graficos() -> void:
	var niveles := ["Bajo", "Medio", "Alto", "Ultra"]
	var cual := int(Configuracion.nivel)
	if Configuracion.nivel == Configuracion.Nivel.PERSONALIZADO:
		niveles.append("Personalizado")
	var nivel := _opciones(_graficos, "Nivel", niveles, cual, func(i: int) -> void:
		if i < 4:
			elegir_nivel(i as Configuracion.Nivel))
	if Configuracion.nivel == Configuracion.Nivel.PERSONALIZADO:
		nivel.set_item_disabled(4, true)
	_graficos.add_child(HSeparator.new())

	var g := Configuracion.graficos
	_opciones(_graficos, "Sombras", ["Apagadas", "Bajas", "Medias", "Altas", "Ultra"],
		int(g["sombras"]), func(i: int) -> void: elegir_ajuste("sombras", i))
	_opciones(_graficos, "Oclusión ambiental", ["No", "SSAO", "SSAO y SSIL"],
		int(g["oclusion"]), func(i: int) -> void: elegir_ajuste("oclusion", i))
	_casilla(_graficos, "Niebla volumétrica", bool(g["niebla"]), func(si: bool) -> void:
		elegir_ajuste("niebla", si))
	_opciones(_graficos, "Nubes volumétricas", _textos(PASOS_DE_NUBE, func(v: Variant) -> String:
		return "Planas" if int(v) == 0 else "%d pasos" % int(v)),
		PASOS_DE_NUBE.find(int(g["nubes"])), func(i: int) -> void:
			elegir_ajuste("nubes", PASOS_DE_NUBE[i]))
	_opciones(_graficos, "Escala de render", _textos(ESCALAS, func(v: Variant) -> String:
		return "%d %%" % int(round(float(v) * 100.0))),
		_indice_cercano(ESCALAS, float(g["escala"])), func(i: int) -> void:
			elegir_ajuste("escala", ESCALAS[i]))
	_opciones(_graficos, "Densidad de vegetación", _textos(VEGETACIONES, func(v: Variant) -> String:
		return "%d %%" % int(round(float(v) * 100.0))),
		_indice_cercano(VEGETACIONES, float(g["vegetacion"])), func(i: int) -> void:
			elegir_ajuste("vegetacion", VEGETACIONES[i]))
	_opciones(_graficos, "Árboles", ["Mínimo", "Medio", "Alto", "Ultra"], int(g["arboles"]),
		func(i: int) -> void: elegir_ajuste("arboles", i))
	# Lo que no entra en caliente se dice, en vez de fingir que se aplicó
	# (GRAFICOS §7). Ver [Configuracion.AL_MONTAR_EL_MAPA]. La distancia del 3D, debajo,
	# sí entra en caliente.
	_nota(_graficos, "La vegetación y los árboles cambian al volver a entrar en un mapa: montar el bosque de nuevo para la pantalla unos segundos.")
	_distancia_3d(g)
	_casilla(_graficos, "Mapas de normales del terreno", bool(g["normales"]),
		func(si: bool) -> void: elegir_ajuste("normales", si))
	_casilla(_graficos, "Oclusión y rugosidad del terreno (ORM)", bool(g["orm"]),
		func(si: bool) -> void: elegir_ajuste("orm", si))


## El slider de la distancia del 3D. Se aplica AL SOLTAR: aplicar repinta la ventana,
## y repintar a mitad de arrastre borraba el slider bajo el ratón; y cada parada
## intermedia desmontaría y montaría el bosque. Mientras se arrastra, sólo cambia la
## cifra.
func _distancia_3d(g: Dictionary) -> void:
	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = float(DISTANCIAS_3D.size() - 1)
	barra.step = 1.0
	barra.value = float(_indice_cercano(DISTANCIAS_3D, float(g["radio_3d"])))
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.editable = int(g["arboles"]) > 0
	var fila := _fila(_graficos, "Distancia de los árboles 3D")
	fila.add_child(barra)
	var cifra := Label.new()
	cifra.custom_minimum_size = Vector2(90, 0)
	cifra.text = texto_de_distancia(DISTANCIAS_3D[int(barra.value)])
	fila.add_child(cifra)
	var arrastrando := [false]
	barra.drag_started.connect(func() -> void: arrastrando[0] = true)
	barra.value_changed.connect(func(v: float) -> void:
		cifra.text = texto_de_distancia(DISTANCIAS_3D[int(v)])
		if not arrastrando[0]:
			elegir_ajuste("radio_3d", DISTANCIAS_3D[int(v)]))
	barra.drag_ended.connect(func(_cambio: bool) -> void:
		arrastrando[0] = false
		elegir_ajuste("radio_3d", DISTANCIAS_3D[int(barra.value)]))
	if int(g["arboles"]) <= 0:
		_nota(_graficos, "Con los árboles en Mínimo no hay 3D: la distancia no se usa.")
	elif float(g["radio_3d"]) >= Configuracion.RADIO_3D_SIN_LIMITE:
		_nota(_graficos, AVISO_SIN_LIMITE)


## Lo que dice la ventana con la distancia sin límite. La cifra es la medida.
const AVISO_SIN_LIMITE := "Sin límite: todos los árboles del mapa en 3D. Sólo para equipos muy potentes o para capturas."


static func texto_de_distancia(metros: float) -> String:
	return "sin límite" if metros >= Configuracion.RADIO_3D_SIN_LIMITE else "%d m" % int(metros)


func _pintar_sonido() -> void:
	_barra(_sonido, "General", Configuracion.volumen_general, func(v: float) -> void:
		elegir_volumen("general", v))
	_barra(_sonido, "Música", Configuracion.volumen_musica, func(v: float) -> void:
		elegir_volumen("musica", v))
	_barra(_sonido, "Efectos", Configuracion.volumen_efectos, func(v: float) -> void:
		elegir_volumen("efectos", v))
	_nota(_sonido, "Todavía no suena nada: el volumen se guarda para cuando suene.")


# --- piezas ----------------------------------------------------------------------

func _fila(donde: VBoxContainer, texto: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	donde.add_child(fila)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.custom_minimum_size = Vector2(ETIQUETA, 0)
	fila.add_child(etiqueta)
	return fila


func _opciones(donde: VBoxContainer, texto: String, opciones: Array, elegida: int,
		al_elegir: Callable) -> OptionButton:
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for opcion: Variant in opciones:
		selector.add_item(String(opcion))
	selector.selected = elegida
	selector.item_selected.connect(al_elegir)
	_fila(donde, texto).add_child(selector)
	return selector


func _casilla(donde: VBoxContainer, texto: String, puesta: bool, al_cambiar: Callable) -> void:
	var casilla := CheckButton.new()
	casilla.button_pressed = puesta
	casilla.toggled.connect(al_cambiar)
	_fila(donde, texto).add_child(casilla)


func _barra(donde: VBoxContainer, texto: String, valor: float, al_cambiar: Callable) -> void:
	var barra := HSlider.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.step = 0.05
	barra.value = valor
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.value_changed.connect(al_cambiar)
	_fila(donde, texto).add_child(barra)


func _nota(donde: VBoxContainer, texto: String) -> void:
	var nota := Label.new()
	nota.text = texto
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(ANCHO - 60, 0)
	nota.add_theme_font_size_override("font_size", 11)
	nota.add_theme_color_override("font_color", UISkin.INK_SOFT)
	donde.add_child(nota)


func _boton(texto: String, al_pulsar: Callable) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.pressed.connect(al_pulsar)
	return boton


static func _textos(valores: Array, como: Callable) -> Array:
	var salida: Array = []
	for valor: Variant in valores:
		salida.append(como.call(valor))
	return salida


static func _indice_cercano(valores: Array, valor: float) -> int:
	var mejor := 0
	for i in range(valores.size()):
		if absf(float(valores[i]) - valor) < absf(float(valores[mejor]) - valor):
			mejor = i
	return mejor
