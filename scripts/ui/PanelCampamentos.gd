class_name PanelCampamentos
extends RefCounted
## La lista de campamentos y la ficha para migrar y mover gente.
##
## Sale de [GameUI] como [PanelTaller]. Spec en INTERFAZ §4 («Los campamentos»);
## el mecanismo, en SISTEMAS §23. **Aquí no se cuenta nada**: lo que cuesta un
## viaje lo dice [Viaje.lo_que_cuesta], que es la misma cuenta que cobra
## [Viaje.salir], y quien manda es [Campamentos.mandar]. Si la ficha calculara
## por su cuenta, un día anunciaría una cifra y se cobraría otra.

## Anchos de la lista.
const NOMBRE := 150
const DATOS := 150

var ui: GameUI

## La ficha abierta: de qué campamento, a quién se ha marcado y adónde. Se
## guardan entre repintados, como la fila de encargar del taller.
var ficha: Campamento = null
var marcados: Array[int] = []
var destino: int = -1

## Lo último que la ficha anunció: jornadas, raciones y el motivo si no se puede.
## Es lo que se compara con lo cobrado.
var anunciado: Dictionary = {}

## Mientras se prepara un valle, y lo que va diciendo. Ver [PreparaValle].
var _preparando := false
var _aviso_del_valle := ""


func _init(panel: GameUI) -> void:
	ui = panel


# --- la lista ----------------------------------------------------------------

func show_campamentos() -> void:
	var body := ui._window("campamentos", "Campamentos")
	ui._clear(body)
	if Campamentos.vivos.is_empty():
		ui._text(body, "no hay campamentos en marcha", true)
		return
	for campamento: Campamento in Campamentos.vivos:
		_fila(body, campamento)
	if not Campamentos.viajes.is_empty():
		ui._text(body, "de camino:", true)
		for viaje: Viaje in Campamentos.viajes:
			ui._text(body, "  %d %s a %s, %s" % [viaje.personas.size(),
				"persona" if viaje.personas.size() == 1 else "personas",
				viaje.hasta_nombre, _quedan(viaje)])


func _fila(body: VBoxContainer, campamento: Campamento) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	var aqui := campamento.sim == ui.sim

	var nombre := Label.new()
	nombre.text = campamento.nombre() + ("  · aquí" if aqui else "")
	nombre.custom_minimum_size = Vector2(NOMBRE, 0)
	nombre.add_theme_font_size_override("font_size", 12)
	nombre.add_theme_color_override("font_color", UISkin.OCHRE if aqui else UISkin.INK)
	row.add_child(nombre)

	var datos := Label.new()
	var gente := campamento.sim.people.size()
	datos.text = "abandonado" if gente == 0 else "%d personas · jornada %d" \
		% [gente, campamento.sim.day]
	datos.custom_minimum_size = Vector2(DATOS, 0)
	datos.add_theme_font_size_override("font_size", 11)
	datos.add_theme_color_override("font_color", UISkin.INK_SOFT)
	row.add_child(datos)

	var alerta := Label.new()
	alerta.text = alerta_de(campamento)
	alerta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alerta.add_theme_font_size_override("font_size", 11)
	alerta.add_theme_color_override("font_color", UISkin.ALARM)
	row.add_child(alerta)

	if not aqui:
		var ir := Button.new()
		ir.text = "Ir"
		ir.tooltip_text = "Mirar este campamento. La partida no se para."
		ir.add_theme_font_size_override("font_size", 11)
		ir.pressed.connect(func() -> void: ui.ir_al_campamento.emit(campamento))
		row.add_child(ir)
	if gente > 0:
		var mover := Button.new()
		mover.text = "Mover gente"
		mover.add_theme_font_size_override("font_size", 11)
		mover.pressed.connect(abrir_ficha.bind(campamento))
		row.add_child(mover)


## La alerta de un campamento: decisión pendiente o hambre. Vacía si no hay nada.
##
## La decisión pendiente se busca donde puede estar: guardada para la barrera,
## esperando turno en la barra, o en pantalla. El hambre es la de la regla del
## juego —`SettlementSim.hambre_severa_racha`—, no un umbral de la ventana.
func alerta_de(campamento: Campamento) -> String:
	var sim := campamento.sim
	var avisos: Array[String] = []
	var pendiente := false
	for moment: Moment in sim.momentos_pendientes:
		pendiente = pendiente or moment.is_decision()
	for moment: Moment in ui._moments:
		pendiente = pendiente or (moment.is_decision() and moment.desde == sim)
	for moment: Moment in Campamentos.sin_ver:
		pendiente = pendiente or (moment.is_decision() and moment.desde == sim)
	var en_pantalla := ui.barra.momento_en_pantalla()
	if en_pantalla != null and en_pantalla.is_decision() and en_pantalla.desde == sim:
		pendiente = true
	if pendiente:
		avisos.append("decisión pendiente")
	if sim.hambre_severa_racha > 0:
		avisos.append("hambre")
	return ", ".join(avisos)


func _quedan(viaje: Viaje) -> String:
	var hoy := Campamentos.reloj.dia if Campamentos.reloj != null else viaje.sale_el_dia
	var quedan := maxi(viaje.llega_el_dia - hoy, 0)
	if quedan == 0:
		return "llegan hoy"
	if quedan == 1:
		return "queda 1 jornada"
	return "quedan %d jornadas" % quedan


# --- la ficha: migrar y mover gente -----------------------------------------

func abrir_ficha(campamento: Campamento) -> void:
	if ficha != campamento:
		marcados.clear()
		destino = -1
	ficha = campamento
	show_ficha()


func show_ficha() -> void:
	if ficha == null or not is_instance_valid(ficha):
		return
	var body := ui._window("campamento", "Mover gente de %s" % ficha.nombre())
	ui._clear(body)
	var sim := ficha.sim

	ui._text(body, "quién va:", true)
	for persona: Inhabitant in sim.people:
		var casilla := CheckBox.new()
		casilla.text = "%s, %d años%s" % [persona.given_name, persona.age_years,
			" · herido" if persona.hurt_days > 0 else ""]
		casilla.button_pressed = marcados.has(persona.id)
		casilla.add_theme_font_size_override("font_size", 12)
		var quien := persona.id
		# Diferido: repintar desde la señal de la casilla es borrar el nodo que la
		# está emitiendo. Lo mismo que en la tarjeta de la expedición.
		casilla.toggled.connect(func(puesto: bool) -> void:
			marcar(quien, puesto)
			show_ficha.call_deferred())
		body.add_child(casilla)

	ui._text(body, "adónde:", true)
	var sitios := destinos()
	var lista := OptionButton.new()
	lista.add_theme_font_size_override("font_size", 11)
	for sitio: Site in sitios:
		var vivo := Campamentos.de_sitio(sitio.id)
		lista.add_item(sitio.display_name() + (" (campamento)" if vivo != null else ""))
	if sitios.is_empty():
		ui._text(body, "no se ha descubierto ningún otro sitio", true)
	else:
		var puesto := 0
		for i in range(sitios.size()):
			if sitios[i].id == destino:
				puesto = i
		destino = sitios[puesto].id
		lista.selected = puesto
		lista.item_selected.connect(func(donde: int) -> void:
			elegir_destino(sitios[donde].id)
			show_ficha.call_deferred())
		body.add_child(lista)

	var hasta := _sitio(destino)
	anunciado = Viaje.lo_que_cuesta(sim, grupo(), ficha.sitio, hasta)
	var motivo := String(anunciado.get("motivo", ""))
	if not motivo.is_empty():
		var no := ui._text(body, motivo)
		no.add_theme_color_override("font_color", UISkin.ALARM)
	else:
		ui._text(body, "%d %s de camino, %.0f raciones de la despensa" % [
			int(anunciado["jornadas"]),
			"jornada" if int(anunciado["jornadas"]) == 1 else "jornadas",
			float(anunciado["raciones"])])

	var valle_listo := hasta == null or Campamentos.de_sitio(hasta.id) != null \
		or Campamento.valle_preparado(hasta.id)
	if not valle_listo:
		ui._text(body, _aviso_del_valle if _preparando
			else "el valle de %s no está preparado: hay que descargarlo antes" \
				% hasta.display_name(), true)
		var preparar := Button.new()
		preparar.text = "Preparar el valle"
		preparar.disabled = _preparando
		preparar.pressed.connect(_preparar.bind(hasta))
		body.add_child(preparar)

	var mandar_boton := Button.new()
	mandar_boton.text = "Mandar"
	mandar_boton.disabled = not motivo.is_empty() or not valle_listo or _preparando
	mandar_boton.pressed.connect(func() -> void:
		mandar()
		show_ficha.call_deferred())
	body.add_child(mandar_boton)


func marcar(id: int, puesto: bool) -> void:
	if puesto and not marcados.has(id):
		marcados.append(id)
	elif not puesto:
		marcados.erase(id)


func elegir_destino(id: int) -> void:
	destino = id


## Los marcados que siguen en el campamento, en el orden de la lista de gente.
func grupo() -> Array[Inhabitant]:
	var salida: Array[Inhabitant] = []
	if ficha == null:
		return salida
	for persona: Inhabitant in ficha.sim.people:
		if marcados.has(persona.id):
			salida.append(persona)
	return salida


## Lo que se puede elegir como destino: lo descubierto de la comarca y los
## campamentos vivos, menos el propio. Ordenado por nombre, que es como se busca.
func destinos() -> Array[Site]:
	var salida: Array[Site] = []
	var comarca := load(MenuPrincipal.SITIOS) as SiteSet
	if comarca == null or ficha == null:
		return salida
	for sitio: Site in comarca.sites:
		if sitio.id == ficha.sitio.id:
			continue
		if GameState.se_ve(sitio) or Campamentos.de_sitio(sitio.id) != null:
			salida.append(sitio)
	salida.sort_custom(func(a: Site, b: Site) -> bool:
		return a.display_name() < b.display_name())
	return salida


## Manda al grupo marcado. Devuelve el viaje, o null con el motivo en
## [Viaje.ultimo_motivo].
func mandar() -> Viaje:
	if ficha == null:
		return null
	var viaje := Campamentos.mandar(ficha, grupo(), _sitio(destino))
	if viaje != null:
		marcados.clear()
	return viaje


func _sitio(id: int) -> Site:
	if id < 0:
		return null
	var comarca := load(MenuPrincipal.SITIOS) as SiteSet
	for sitio: Site in comarca.sites:
		if sitio.id == id:
			return sitio
	return null


## Prepara el valle de destino sin salir de la partida: la descarga bloquea unos
## segundos, y la ficha va diciendo por dónde va.
func _preparar(hasta: Site) -> void:
	if _preparando:
		return
	_preparando = true
	_aviso_del_valle = "preparando el valle de %s..." % hasta.display_name()
	show_ficha()
	var preparador := PreparaValle.new()
	preparador.aviso.connect(func(texto: String) -> void:
		_aviso_del_valle = texto)
	# Con la pantalla de carga, que para el reloj mientras tanto. INTERFAZ §9.
	Carga.abrir(ui.get_tree(), "Preparando el valle de %s" % hasta.display_name())
	Carga.etapas(PreparaValle.ETAPAS)
	preparador.etapa_cambiada.connect(Carga.etapa)
	await preparador.preparar(ui.get_tree(), hasta, Carga.avanzar_por_tiempo)
	Carga.cerrar()
	_preparando = false
	_aviso_del_valle = ""
	show_ficha()
