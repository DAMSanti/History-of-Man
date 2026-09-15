extends SceneTree
## La ventana de campamentos y la ficha de mover gente, montadas y pulsadas.
##
## Criterios de INTERFAZ §4 para SISTEMAS §23, tareas 13 y 15. Son de ventana
## montada, así que no caben en la suite: se montan dos campamentos de verdad
## —`Campamento.montar`, sin escena—, la interfaz encima, y se aprieta **Mandar**.
##
## Comprueba:
##
##   1. que la lista pinta una fila por campamento;
##   2. que lo que la ficha anuncia antes de mandar —jornadas y raciones— es lo
##      que cobra el viaje, y que la despensa baja por lo menos eso;
##   3. y que a 1920×1080 y a 1280×720 no se sale ningún control de las dos
##      ventanas, con la vara de `PrioridadesCaptura`.
##
## **Necesita ventana** para las capturas. Unos tres minutos: montar dos valles.
##
##   godot --path . --script res://scripts/tests/CampamentosCaptura.gd

const ORIGEN := 56
const DESTINO := 14

var _fallos: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var sitios := load(MenuPrincipal.SITIOS) as SiteSet
	var origen := Campamento.montar(self, _sitio(sitios, ORIGEN),
		GameState.population, GameState.food)
	Campamentos.alta(self, origen)
	await process_frame
	var destino := Campamento.montar(self, _sitio(sitios, DESTINO), 5, 60.0)
	Campamentos.alta(self, destino)
	Campamentos.dejar_de_mirar(destino)
	# Quieto: esto mira ventanas, no la partida.
	Campamentos.reloj.time_scale = 0.0
	origen.sim.time_scale = 0.0
	await process_frame

	var ui := _interfaz(origen)
	await _frames(6)

	print("")
	print("=== CAMPAMENTOS ===")
	ui.campamentos.show_campamentos()
	await _frames(3)
	var nombres := _textos(ui._windows.get("campamentos", ui))
	var filas := 0
	for campamento: Campamento in Campamentos.vivos:
		for texto: String in nombres:
			if texto.begins_with(campamento.nombre()):
				filas += 1
				break
	_comprueba(filas == 2, "la lista pinta una fila por campamento", "%d filas" % filas)

	# 2. Lo anunciado es lo cobrado, pulsando el botón.
	ui.campamentos.abrir_ficha(origen)
	var marcados := 0
	for persona: Inhabitant in origen.sim.people:
		if marcados < 2 and persona.age_group == Inhabitant.Age.ADULTO \
				and persona.hurt_days == 0:
			ui.campamentos.marcar(persona.id, true)
			marcados += 1
	ui.campamentos.elegir_destino(DESTINO)
	ui.campamentos.show_ficha()
	await _frames(3)
	var anunciado := ui.campamentos.anunciado.duplicate()
	_comprueba(String(anunciado.get("motivo", "")).is_empty(), "la ficha deja mandar",
		String(anunciado.get("motivo", "")))
	var linea := "%.0f raciones de la despensa" % float(anunciado.get("raciones", 0.0))
	var textos := _textos(ui._windows.get("campamento", ui))
	var escrito := false
	for texto: String in textos:
		escrito = escrito or texto.contains(linea)
	_comprueba(escrito, "y lo escribe antes de confirmar: «%s»" % linea, str(textos))
	var despensa := origen.sim.store.food_rations()
	var boton := _boton_con_texto(ui._windows.get("campamento", ui), "Mandar")
	if boton == null or boton.disabled:
		_mal("no hay botón Mandar encendido")
	else:
		boton.pressed.emit()
		await _frames(3)
		var viaje: Viaje = Campamentos.viajes.back() if not Campamentos.viajes.is_empty() else null
		_comprueba(viaje != null, "mandar saca un viaje", Viaje.ultimo_motivo)
		if viaje != null:
			_comprueba(viaje.jornadas == int(anunciado["jornadas"]),
				"cobra las jornadas anunciadas", "%d frente a %d" % [viaje.jornadas, anunciado["jornadas"]])
			_comprueba(is_equal_approx(viaje.raciones, float(anunciado["raciones"])),
				"y las raciones anunciadas", "%.2f frente a %.2f" % [viaje.raciones, anunciado["raciones"]])
			var bajan := despensa - origen.sim.store.food_rations()
			_comprueba(bajan >= float(anunciado["raciones"]) - 0.01,
				"y la despensa baja por lo menos eso (%.1f, con lo que cargan)" % bajan,
				"sólo baja %.2f" % bajan)

	# 3. A dos resoluciones.
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		# EN VENTANA, primero: a pantalla completa `window_set_size` no hace nada.
		# Ver `PrioridadesCaptura`.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion)
		get_root().size = resolucion
		var esperas := 0
		while get_root().size != resolucion and esperas < 240:
			esperas += 1
			await process_frame
		await _frames(20)
		var pantalla := Rect2(Vector2.ZERO, Vector2(get_root().size))
		# La interfaz, montada de nuevo a esta resolución: el alto de las ventanas
		# se fija al crearlas.
		ui.queue_free()
		await process_frame
		ui = _interfaz(origen)
		await _frames(6)
		for entrada: Array in [
				["campamentos", func() -> void: ui.campamentos.show_campamentos()],
				["campamento", func() -> void: ui.campamentos.abrir_ficha(origen)]]:
			(entrada[1] as Callable).call()
			await _frames(6)
			var fuera := _fuera_de(ui._windows.get(entrada[0], ui), pantalla)
			_comprueba(fuera.is_empty(), "%dx%d · %s: nada se sale"
				% [resolucion.x, resolucion.y, entrada[0]], str(fuera.slice(0, 4)))
			var shot := get_root().get_texture().get_image()
			if shot != null:
				var ruta := "user://campamentos_%s_%dx%d.png" % [entrada[0],
					resolucion.x, resolucion.y]
				shot.save_png(ruta)
				print("      captura en %s" % ProjectSettings.globalize_path(ruta))
			(ui._windows[entrada[0]] as Control).visible = false

	print("")
	if _fallos.is_empty():
		print("=== TODO BIEN ===")
	else:
		print("=== %d COSAS MAL ===" % _fallos.size())
		for linea_mal: String in _fallos:
			print("   %s" % linea_mal)
	Campamentos.vaciar()
	quit(0 if _fallos.is_empty() else 1)


func _interfaz(campamento: Campamento) -> GameUI:
	var ui := GameUI.new()
	ui.sim = campamento.sim
	ui.tech = campamento.tech
	ui.knowledge = campamento.knowledge
	ui.field = campamento.field
	ui.site = campamento.sitio
	get_root().add_child(ui)
	return ui


func _sitio(sitios: SiteSet, id: int) -> Site:
	for s: Site in sitios.sites:
		if s.id == id:
			return s
	return null


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _textos(nodo: Node) -> Array[String]:
	var salida: Array[String] = []
	if nodo is Label:
		salida.append((nodo as Label).text)
	elif nodo is Button:
		salida.append((nodo as Button).text)
	for hijo: Node in nodo.get_children():
		salida.append_array(_textos(hijo))
	return salida


func _boton_con_texto(nodo: Node, texto: String) -> Button:
	if nodo is Button and (nodo as Button).text == texto:
		return nodo as Button
	for hijo: Node in nodo.get_children():
		var hallado := _boton_con_texto(hijo, texto)
		if hallado != null:
			return hallado
	return null


## La vara de `RegionCaptura`: lo que va dentro de un panel con desplazamiento lo
## recorta el panel, así que se mide el panel.
func _fuera_de(nodo: Node, pantalla: Rect2) -> Array:
	var salida: Array = []
	if nodo is ScrollContainer:
		if (nodo as Control).is_visible_in_tree():
			var marco := (nodo as Control).get_global_rect()
			if not pantalla.grow(1.0).encloses(marco):
				salida.append("%s %s" % [nodo.name, str(marco)])
		return salida
	if nodo is Control and (nodo as Control).is_visible_in_tree():
		var rect := (nodo as Control).get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0 \
				and not pantalla.grow(1.0).encloses(rect):
			salida.append("%s %s" % [nodo.name, str(rect)])
	for hijo: Node in nodo.get_children():
		salida.append_array(_fuera_de(hijo, pantalla))
	return salida


func _comprueba(bien: bool, que: String, porque: String) -> void:
	if bien:
		print("   ok · %s" % que)
	else:
		_mal("%s: %s" % [que, porque])


func _mal(linea: String) -> void:
	_fallos.append(linea)
	print("   MAL · %s" % linea)
