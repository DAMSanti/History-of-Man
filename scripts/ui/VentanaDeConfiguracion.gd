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

const VEGETACIONES: Array[float] = [0.25, 0.5, 0.75, 1.0]
const PASOS_DE_NUBE: Array[int] = [0, 6, 12, 20, 32]
## Los escalones del agua, con el nombre del nivel que los pone. GRAFICOS §7.3.
const NIVELES_DE_AGUA: Array[String] = ["Bajo", "Medio", "Alto", "Ultra"]
## Las paradas del slider de la distancia del 3D: las de los niveles y las de en medio,
## más finas de cerca, donde cada metro cuenta, y el último, el máximo. Ver
## [Configuracion.RADIO_3D_MAXIMO]: el «sin límite» que acababa el slider rompía el motor.
const DISTANCIAS_3D: Array[float] = [10.0, 20.0, 30.0, 40.0, 50.0, 70.0, 100.0, 120.0,
	150.0, 200.0, 300.0, 500.0, Configuracion.RADIO_3D_MAXIMO]

var _pestanas: TabContainer
var _pantalla: VBoxContainer
var _graficos: VBoxContainer
var _controles: VBoxContainer
var _sonido: VBoxContainer

## La acción que está esperando una tecla, vacía si no hay ninguna. Ver
## [esperar_la_tecla]: mientras espera, la ventana se come la siguiente pulsación.
var esperando := ""

## El choque a resolver: la acción que se cambiaba, la tecla nueva y con quién choca.
## Vacío si no hay ninguno. Ver [resolver_el_choque].
var choque: Dictionary = {}
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
	_controles = _pestana("Controles")
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


## A CUÁNTO SE DIBUJA EL MUNDO, en fracción de la ventana (INTERFAZ §16).
##
## Es lo que hace el selector de «Resolución» cuando la ventana no la dimensiona el
## jugador —maximizada y a pantalla completa—, que es como se juega.
##
## **Sin cuenta atrás**, a diferencia de cambiar el modo o el tamaño de la ventana: la
## confirmación existe para que una resolución que el monitor no pueda dar no te deje sin
## ver nada, y dibujar a menos no puede hacer eso. Se aplica y se guarda como cualquier
## otro ajuste de gráficos.
func elegir_dibujo(escala: float) -> void:
	Configuracion.poner_ajuste("escala", escala)
	Configuracion.aplicar_graficos(get_tree())
	Configuracion.guardar()
	_pintar.call_deferred()


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


## Empieza a esperar la tecla de una acción. La siguiente que se pulse será la suya.
##
## ESC no espera nada: no se cambia (INTERFAZ §11, decisión del usuario del 2026-09-17).
func esperar_la_tecla(id: String) -> void:
	if Teclas.tecla_de(id) == Teclas.NINGUNA or _es_fija(id):
		return
	esperando = id
	choque = {}
	_pintar_controles_de_nuevo()


## La tecla que se ha pulsado mientras esperaba. Devuelve qué pasó: `"puesta"`,
## `"choque"` o `"nada"`. La ventana la llama desde `_input`; la prueba, a mano.
func tecla_pulsada(tecla: Key) -> String:
	if esperando.is_empty():
		return "nada"
	var id := esperando
	esperando = ""
	# La misma que tenía: ni se cambia ni se avisa de que choca consigo misma.
	if Teclas.tecla_de(id) == tecla:
		_pintar_controles_de_nuevo()
		return "nada"
	var chocan := Teclas.choca_con(id, tecla)
	if not chocan.is_empty():
		choque = {"id": id, "tecla": tecla, "con": chocan[0]}
		_pintar_controles_de_nuevo()
		return "choque"
	Teclas.poner(id, tecla)
	Configuracion.guardar()
	_pintar_controles_de_nuevo()
	return "puesta"


## Resuelve el choque que hay pendiente: `true` las intercambia, `false` lo deja todo
## como estaba. **Nunca quedan dos acciones con la misma tecla** sin que el jugador lo
## haya visto, que es lo que pedía la spec.
func resolver_el_choque(intercambiar: bool) -> void:
	if choque.is_empty():
		return
	if intercambiar:
		Teclas.intercambiar(String(choque["id"]), String(choque["con"]))
		Configuracion.guardar()
	choque = {}
	_pintar_controles_de_nuevo()


## Todas a las de siempre.
func teclas_de_siempre() -> void:
	esperando = ""
	choque = {}
	Teclas.por_defecto()
	Configuracion.guardar()
	_pintar_controles_de_nuevo()


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
	for pestana: VBoxContainer in [_pantalla, _graficos, _controles, _sonido]:
		for hijo: Node in pestana.get_children():
			pestana.remove_child(hijo)
			hijo.queue_free()
	_pintar_pantalla()
	_pintar_graficos()
	_pintar_controles()
	_pintar_sonido()


func _pintar_pantalla() -> void:
	var modos := ["Pantalla completa", "Ventana", "Ventana maximizada"]
	_opciones(_pantalla, "Modo", modos, int(Configuracion.modo), func(i: int) -> void:
		elegir_modo(i as Configuracion.Modo))

	# LA RESOLUCIÓN, DOS COSAS SEGÚN EL MODO (INTERFAZ §16). En ventana, el tamaño de la
	# ventana, como siempre. Maximizada y a pantalla completa —que es como se juega— el
	# tamaño lo manda el gestor de ventanas, así que lo que se elige es **a cuánto se
	# dibuja el mundo**, y se enseña en píxeles de verdad y no en tanto por ciento: era la
	# escala de render de Gráficos, que el usuario no encontraba.
	if Configuracion.manda_sobre_el_dibujo():
		var ventana := Configuracion.tamano_de_la_ventana()
		var dibujos := Configuracion.dibujos_que_caben(ventana)
		var pintados: Array = []
		for r: Vector2i in dibujos:
			pintados.append("%d × %d" % [r.x, r.y] if r.x > 0 else "—")
		var puesta := Configuracion.dibujo_con(
			float(Configuracion.graficos["escala"]), ventana)
		_opciones(_pantalla, "Resolución de dibujo", pintados,
			maxi(dibujos.find(puesta), 0), func(i2: int) -> void:
				elegir_dibujo(Configuracion.ESCALAS_DE_DIBUJO[i2]))
		_nota(_pantalla, "La ventana la manda el sistema. Esto es a cuánto se dibuja el "
			+ "mundo, y se estira a la pantalla: cuanto menos, más fotogramas. Los paneles "
			+ "y el texto no se tocan.")
	else:
		var lista := Configuracion.resoluciones()
		if not lista.has(Configuracion.resolucion):
			lista.append(Configuracion.resolucion)
		var textos: Array = []
		for r: Vector2i in lista:
			textos.append("%d × %d" % [r.x, r.y])
		_opciones(_pantalla, "Tamaño de la ventana", textos,
			lista.find(Configuracion.resolucion),
			func(i2: int) -> void: elegir_resolucion(lista[i2]))

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
	# LA ESCALA DE RENDER YA NO VIVE AQUÍ (2026-09-17, INTERFAZ §16): es la «Resolución de
	# dibujo» de Pantalla, en píxeles. Dos controles sobre el mismo valor es la pregunta
	# contestada desde dos sitios que prohíbe SPECS §7, y además el jugador no la
	# encontraba aquí.
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
	_opciones(_graficos, "Agua", NIVELES_DE_AGUA, int(g["agua"]),
		func(i: int) -> void: elegir_ajuste("agua", i))
	_casilla(_graficos, "Clima: lluvia, nieve y niebla", bool(g["clima"]),
		func(si: bool) -> void: elegir_ajuste("clima", si),
		"Apagado no se dibuja el tiempo, pero sigue haciendo lo que hace: la lluvia moja a la banda aunque no se vea.")
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
	elif float(g["radio_3d"]) >= Configuracion.RADIO_3D_MAXIMO:
		_nota(_graficos, AVISO_AL_MAXIMO)


## Lo que dice la ventana con la distancia al máximo. La cifra es la medida:
## `GpuProfile ARBOLES=1 ESCALON=1 RADIO=1000`, GTX 1070 a 1080p, 2026-09-15 —el bosque
## 34-67 ms de GPU contra 3,5 a 40 m, 54 millones de triángulos, 57 s en montar el mapa—.
const AVISO_AL_MAXIMO := "1000 m: sólo el bosque pasa de 3 ms a 34-67 ms por fotograma en una GTX 1070, y el mapa tarda un minuto en montarse. Para capturas."


static func texto_de_distancia(metros: float) -> String:
	return "%d m" % int(metros)


## La pestaña de los controles: una fila por acción, agrupadas por dónde valen.
##
## Se agrupan por ámbito porque la misma tecla vale en dos pantallas sin chocar —la R es
## la capa del minimapa en el valle y la ficha del sitio en el regional—, y verlas en dos
## bloques distintos es lo que hace que eso no parezca un fallo. Ver [Teclas.Ambito].
func _pintar_controles() -> void:
	if not choque.is_empty():
		_pintar_el_choque()
		return
	if not esperando.is_empty():
		_nota(_controles, "Pulsa la tecla nueva para «%s». ESC no vale: es la salida."
			% Teclas.rotulo_de(esperando))
	for ambito: int in [Teclas.Ambito.SIEMPRE, Teclas.Ambito.VALLE, Teclas.Ambito.REGIONAL]:
		var filas := Teclas.del_ambito(ambito as Teclas.Ambito)
		if filas.is_empty():
			continue
		var titulo := Label.new()
		titulo.text = Teclas.nombre_del_ambito(ambito as Teclas.Ambito)
		titulo.add_theme_color_override("font_color", UISkin.OCHRE)
		_controles.add_child(titulo)
		if ambito == Teclas.Ambito.SIEMPRE:
			_nota(_controles, "Los números mandan a toda la banda a un oficio en el "
				+ "valle, y reparten la partida en el mapa regional; el 0 la deja sin "
				+ "nadie.")
		for fila: Dictionary in filas:
			_fila_de_tecla(fila)
	_controles.add_child(HSeparator.new())
	_controles.add_child(_boton("Volver a las de siempre", teclas_de_siempre))
	_nota(_controles, "El ratón no se cambia: clic para mirar, botón derecho para girar "
		+ "y la rueda para acercar.")


func _fila_de_tecla(fila: Dictionary) -> void:
	var id: String = fila["id"]
	var caja := _fila(_controles, String(fila["rotulo"]))
	var boton := Button.new()
	boton.text = Teclas.nombre_de_la_tecla(Teclas.tecla_de(id))
	boton.custom_minimum_size = Vector2(110, 0)
	if _es_fija(id):
		boton.disabled = true
		boton.tooltip_text = "No se cambia: es la salida de todas las ventanas."
	elif esperando == id:
		boton.text = "pulsa una tecla"
	else:
		boton.pressed.connect(func() -> void: esperar_la_tecla(id))
	caja.add_child(boton)


func _pintar_el_choque() -> void:
	var aviso := Label.new()
	# Se nombran LAS DOS: sin decir cuál se estaba cambiando, el aviso llega cuando la
	# lista ya no se ve y hay que acordarse de qué fila se tocó.
	aviso.text = "Querías poner «%s» en la tecla %s, y esa tecla ya es «%s»." % [
		Teclas.rotulo_de(String(choque["id"])),
		Teclas.nombre_de_la_tecla(int(choque["tecla"]) as Key),
		Teclas.rotulo_de(String(choque["con"]))]
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(ANCHO - 60, 0)
	aviso.add_theme_color_override("font_color", UISkin.OCHRE)
	_controles.add_child(aviso)
	_nota(_controles, "Si las cambias entre sí, «%s» se queda con la %s."
		% [Teclas.rotulo_de(String(choque["con"])),
			Teclas.nombre_de_la_tecla(Teclas.tecla_de(String(choque["id"])))])
	_controles.add_child(_boton("Cambiarlas entre sí",
		func() -> void: resolver_el_choque(true)))
	_controles.add_child(_boton("Dejarlo como estaba",
		func() -> void: resolver_el_choque(false)))


func _es_fija(id: String) -> bool:
	for fila: Dictionary in Teclas.CATALOGO:
		if fila["id"] == id:
			return bool(fila.get("fija", false))
	return false


## Repinta sólo los controles: repintar la ventana entera cerraría los desplegables de
## las otras pestañas cada vez que se toca una tecla.
func _pintar_controles_de_nuevo() -> void:
	for hijo: Node in _controles.get_children():
		_controles.remove_child(hijo)
		hijo.queue_free()
	_pintar_controles()


## Mientras espera una tecla, la ventana se come la pulsación: si no, la W de «avanzar»
## movería además la cámara de detrás.
func _input(event: InputEvent) -> void:
	if esperando.is_empty():
		return
	var tecla := event as InputEventKey
	if tecla == null or not tecla.pressed or tecla.echo:
		return
	get_viewport().set_input_as_handled()
	# ESC cancela la espera: es la salida de todo, y por eso no se puede asignar.
	if Teclas.es(tecla, "cerrar"):
		esperando = ""
		_pintar_controles_de_nuevo()
		return
	tecla_pulsada(tecla.physical_keycode)


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


func _casilla(donde: VBoxContainer, texto: String, puesta: bool, al_cambiar: Callable,
		ayuda: String = "") -> void:
	var casilla := CheckButton.new()
	casilla.button_pressed = puesta
	casilla.tooltip_text = ayuda
	casilla.toggled.connect(al_cambiar)
	var fila := _fila(donde, texto)
	fila.tooltip_text = ayuda
	fila.add_child(casilla)


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
