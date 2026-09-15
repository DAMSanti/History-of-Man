extends SceneTree
## Las tres ventanas de las prioridades, montadas y pulsadas de verdad.
##
## Criterios de INTERFAZ §4 para la spec del 2026-09-14 (SISTEMAS §22). Son de
## ventana montada, no de regla, así que no caben en la suite: `TestCase` no
## tiene árbol de escena y un `Button` sin árbol no se pulsa. Aquí se monta
## [GameUI] como hace `PanelProbe`, se aprieta cada botón y se mira qué cambió
## en la simulación.
##
## Comprueba, en este orden:
##
##   1. que las tres ventanas se montan y pintan filas;
##   2. que pulsar la marca del almacén cambia **el mismo** nivel que usa la
##      simulación, y que cambiarlo por código se ve sin cerrar la ventana;
##   3. que lo que pinta la ventana Taller es, entrada a entrada, la misma
##      lista que usa el taller para elegir;
##   4. que añadir, subir, bajar y quitar hacen lo que dice SISTEMAS §22;
##   5. y que a 1920×1080 y a 1280×720 no se sale ningún control, con la vara
##      de `RegionCaptura`.
##
## **Las capturas necesitan ventana**: con `--headless`, `get_texture()
## .get_image()` devuelve null. Sin ventana, los puntos 1 a 4 siguen valiendo.
##
##   godot --path . --script res://scripts/tests/PrioridadesCaptura.gd

var _fallos: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9

	var sim := SettlementSim.new()
	sim.people = Inhabitant.create_band(15, Vector3.ZERO, rng)
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	for kind: int in [Materia.Kind.CARNE_SECA, Materia.Kind.PIEDRA,
			Materia.Kind.SILEX, Materia.Kind.ASTA, Materia.Kind.HUESO,
			Materia.Kind.FIBRA, Materia.Kind.LENA, Materia.Kind.PIEL_CURTIDA,
			Materia.Kind.TENDON, Materia.Kind.BAYA, Materia.Kind.FRUTO_SECO]:
		sim.store.add(kind as Materia.Kind, 60.0)
	sim.day = 20
	sim.apply_priorities()
	# Un artesano de cada rama, para que la columna «quién la hará» diga
	# nombres y no «nadie en talla».
	for i in range(2):
		sim.people[i].job = Profession.Job.MANUFACTURA
		sim.people[i].current_speciality = Profession.Speciality.TALLA if i == 0 \
			else Profession.Speciality.ASTA
		sim.people[i].has_task = true

	var ui := GameUI.new()
	ui.sim = sim
	ui.tech = TechTree.new()
	ui.tech.larder = sim.store
	get_root().add_child(ui)
	await process_frame

	print("")
	print("=== LAS TRES VENTANAS ===")
	await _se_montan(ui)
	await _el_nivel_va_y_vuelve(ui, sim)
	await _la_cola_pintada_es_la_de_verdad(ui, sim)
	await _los_botones_de_la_cola(ui, sim)
	await _a_dos_resoluciones(ui)

	print("")
	if _fallos.is_empty():
		print("=== TODO BIEN ===")
	else:
		print("=== %d COSAS MAL ===" % _fallos.size())
		for linea: String in _fallos:
			print("   %s" % linea)
	quit(0 if _fallos.is_empty() else 1)


func _mal(linea: String) -> void:
	_fallos.append(linea)


func _bien(linea: String) -> void:
	print("   ok · %s" % linea)


# --- 1. que se montan -----------------------------------------------------

func _se_montan(ui: GameUI) -> void:
	for entrada: Array in [
			["almacén", func() -> void: ui.show_store()],
			["trabajos", func() -> void: ui.show_jobs()],
			["taller", func() -> void: ui.taller.show_workshop()]]:
		(entrada[1] as Callable).call()
		await process_frame
		var filas := _filas_de(ui)
		if filas <= 0:
			_mal("la ventana %s no pinta nada" % entrada[0])
		else:
			_bien("la ventana %s pinta %d nodos" % [entrada[0], filas])


func _filas_de(ui: GameUI) -> int:
	var total := 0
	for hijo: Node in ui.get_children():
		total += _cuenta(hijo)
	return total


func _cuenta(nodo: Node) -> int:
	var total := 1 if nodo is Control and (nodo as Control).is_visible_in_tree() else 0
	for hijo: Node in nodo.get_children():
		total += _cuenta(hijo)
	return total


# --- 2. el nivel, de la ventana a la simulación y al revés ----------------

func _el_nivel_va_y_vuelve(ui: GameUI, sim: SettlementSim) -> void:
	ui.show_store()
	await process_frame
	var boton := _boton_con_texto(ui, Prioridades.nombre(Prioridades.Nivel.NORMAL))
	if boton == null:
		_mal("el almacén no tiene ninguna marca de prioridad")
		return
	var antes := sim.prioridades.materiales.size()
	boton.pressed.emit()
	await process_frame
	if sim.prioridades.materiales.size() <= antes:
		_mal("pulsar la marca del almacén no cambia el nivel de la simulación")
	else:
		_bien("pulsar la marca cambia el nivel que usa la simulación")

	# Y al revés: por código, y se ve sin cerrar la ventana.
	sim.fijar_prioridad_material(Materia.Kind.SILEX, Prioridades.Nivel.ALTA)
	ui._refresh_live()
	await process_frame
	if _boton_con_texto(ui, Prioridades.nombre(Prioridades.Nivel.ALTA)) == null:
		_mal("cambiar el nivel por código no se ve en la ventana abierta")
	else:
		_bien("cambiarlo por código se ve sin cerrar la ventana")


func _boton_con_texto(nodo: Node, texto: String) -> Button:
	if nodo is Button and (nodo as Button).is_visible_in_tree() \
			and (nodo as Button).text == texto:
		return nodo as Button
	for hijo: Node in nodo.get_children():
		var encontrado := _boton_con_texto(hijo, texto)
		if encontrado != null:
			return encontrado
	return null


# --- 3. la cola pintada, entrada a entrada --------------------------------

func _la_cola_pintada_es_la_de_verdad(ui: GameUI, sim: SettlementSim) -> void:
	# Con un encargo, una automática y una bloqueada, que es lo que pide el
	# criterio: las tres clases de entrada a la vez.
	sim.taller.encargar_pieza(Tool.Kind.AZAGAYA, 2)
	sim.store.take(Materia.Kind.ASTA, 60.0)
	ui.taller.show_workshop()
	await process_frame

	var pintado := _nombres_de_pieza(ui)
	var esperado: Array[String] = []
	for entrada: Dictionary in sim.taller.cola_de_trabajo():
		esperado.append(Tool.kind_name(int(entrada["tool"]) as Tool.Kind))
	if pintado == esperado:
		_bien("la ventana pinta la cola entera en su orden (%d entradas)"
			% esperado.size())
	else:
		_mal("lo pintado no es la cola: %s contra %s" % [str(pintado), str(esperado)])

	var bloqueadas := 0
	for entrada: Dictionary in sim.taller.cola_de_trabajo():
		if not String(entrada["motivo"]).is_empty():
			bloqueadas += 1
	if bloqueadas > 0:
		_bien("y %d entrada(s) dicen por qué no se pueden hacer" % bloqueadas)
	else:
		_mal("ninguna entrada sale bloqueada, y se quitó el asta a propósito")


## Los nombres de pieza de las filas de la cola, en orden. Son la primera
## etiqueta de cada fila, que es como las pinta [PanelTaller].
func _nombres_de_pieza(ui: GameUI) -> Array[String]:
	var salida: Array[String] = []
	var ventana: Node = ui._windows.get("taller")
	if ventana == null:
		return salida
	for fila: Node in _filas_de_la_cola(ventana):
		for hijo: Node in fila.get_children():
			if hijo is Label:
				salida.append((hijo as Label).text)
				break
	return salida


func _filas_de_la_cola(nodo: Node) -> Array[Node]:
	var salida: Array[Node] = []
	if nodo is PanelContainer:
		for hijo: Node in nodo.get_children():
			if hijo is HBoxContainer and _parece_fila_de_cola(hijo):
				salida.append(hijo)
	for hijo: Node in nodo.get_children():
		salida.append_array(_filas_de_la_cola(hijo))
	return salida


## Una fila de la cola tiene cuatro etiquetas -pieza, cuántas, quién, motivo- y
## tres botones. La de encargar no: lleva un `OptionButton`.
func _parece_fila_de_cola(fila: Node) -> bool:
	var etiquetas := 0
	for hijo: Node in fila.get_children():
		if hijo is OptionButton:
			return false
		if hijo is Label:
			etiquetas += 1
	return etiquetas >= 4


# --- 4. añadir, subir, bajar y quitar -------------------------------------

func _los_botones_de_la_cola(ui: GameUI, sim: SettlementSim) -> void:
	sim.store.add(Materia.Kind.ASTA, 60.0)
	sim.taller.encargos.clear()
	ui.taller.show_workshop()
	await process_frame

	# Añadir: el botón de encargar, con lo que traiga puesto el desplegable.
	var encargar := _boton_con_texto(ui, "Encargar")
	if encargar == null:
		_mal("no hay botón de encargar")
		return
	encargar.pressed.emit()
	await process_frame
	if sim.taller.encargos.size() == 1:
		_bien("el botón de encargar mete el encargo en la cola")
	else:
		_mal("el botón de encargar no encarga nada")
		return

	# Bajar una automática: baja el nivel de esa pieza.
	var cola := sim.taller.cola_de_trabajo()
	var automatica := -1
	for entrada: Dictionary in cola:
		if bool(entrada["automatico"]):
			automatica = int(entrada["tool"])
			break
	if automatica < 0:
		_mal("no hay ninguna entrada automática que mover")
		return
	var nivel_antes := sim.prioridades.de_pieza(automatica as Tool.Kind)
	sim.prioridades.mover_pieza(automatica as Tool.Kind, 1)
	if sim.prioridades.de_pieza(automatica as Tool.Kind) != nivel_antes:
		_bien("bajar una automática le baja la prioridad a la pieza")
	else:
		_mal("bajar una automática no cambia nada")

	# Quitar una automática: se queda en nunca, y sale en «apartadas» con su
	# botón de vuelta, que es lo único que la devuelve.
	sim.fijar_prioridad_pieza(automatica as Tool.Kind, Prioridades.Nivel.NUNCA)
	ui.taller.show_workshop()
	await process_frame
	var vuelve := _boton_con_texto(ui, "↺")
	if vuelve == null:
		_mal("una pieza apartada no tiene forma de volver a la cola")
		return
	vuelve.pressed.emit()
	await process_frame
	if sim.prioridades.de_pieza(automatica as Tool.Kind) == Prioridades.Nivel.NORMAL:
		_bien("y la línea de apartadas la devuelve a normal")
	else:
		_mal("el botón de volver no devuelve la pieza")


# --- 5. a dos resoluciones ------------------------------------------------

## **La interfaz se monta DE NUEVO a cada resolución, y hace falta.** El alto de
## una ventana se calcula al crearla (`GameUI._window`), así que midiendo con la
## interfaz montada a 3651×2054 —lo que abre una sonda con ventana en este
## equipo— las tres ventanas salían de 710 px y «se salían» a 1280×720 por algo
## que no le pasa a un jugador que arranca en esa resolución. Es lo mismo que
## midió mal la barra superior: la medida, no la interfaz.
func _a_dos_resoluciones(ui: GameUI) -> void:
	var sim: SettlementSim = ui.sim
	for resolucion: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		# EN VENTANA, primero. El proyecto arranca a pantalla completa y ahí
		# `window_set_size` no hace nada: la ventana seguía midiendo 3651×2054
		# —de ahí el alto de 710 px, que sale de `GameUI._content_height`— y lo
		# que se medía era la pantalla del equipo, no la resolución pedida.
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolucion)
		get_root().size = resolucion
		# Con veinte cuadros la barra superior todavía medía 2 209 px de ancho
		# —el tamaño de antes del cambio—, así que lo que se «salía» era la
		# medida y no la interfaz. Se espera a que el raíz sea de verdad del
		# tamaño pedido antes de medir nada.
		var esperas := 0
		while get_root().size != resolucion and esperas < 240:
			esperas += 1
			await process_frame
		for i in range(20):
			await process_frame
		var pantalla := Rect2(Vector2.ZERO, Vector2(get_root().size))
		print("   %dx%d (raíz %s · ventana %s · tras %d cuadros)"
			% [resolucion.x, resolucion.y, str(get_root().size),
			str(DisplayServer.window_get_size()), esperas])
		# La interfaz, montada de nuevo a esta resolución. Ver la cabecera de
		# esta función: midiendo la de antes se medía el tamaño de la ventana
		# de arranque, no la interfaz.
		ui.queue_free()
		await process_frame
		ui = GameUI.new()
		ui.sim = sim
		ui.tech = TechTree.new()
		ui.tech.larder = sim.store
		get_root().add_child(ui)
		for i in range(6):
			await process_frame
		# Lo que se sale de FUERA de las tres ventanas se cuenta, pero no es de
		# esto: la barra superior arrastra el ancho con el que se construyó.
		var de_toda_la_interfaz := _fuera_de(ui, pantalla).size()

		for entrada: Array in [
				["almacen", func() -> void: ui.show_store()],
				["trabajos", func() -> void: ui.show_jobs()],
				["taller", func() -> void: ui.taller.show_workshop()]]:
			(entrada[1] as Callable).call()
			for i in range(6):
				await process_frame
			# Sólo la ventana de la que va esto, y los botones que la abren.
			var fuera := _fuera_de(ui._windows.get(entrada[0], ui), pantalla)
			if fuera.is_empty():
				_bien("%dx%d · %s: nada se sale (y %d controles de FUERA de las"
					% [resolucion.x, resolucion.y, entrada[0],
					de_toda_la_interfaz] + " ventanas, que vienen de antes)")
			else:
				_mal("%dx%d · %s: %d controles se salen %s"
					% [resolucion.x, resolucion.y, entrada[0], fuera.size(),
					str(fuera.slice(0, 4))])
			var shot := get_root().get_texture().get_image()
			if shot != null:
				var ruta := "user://prioridades_%s_%dx%d.png" % [entrada[0],
					resolucion.x, resolucion.y]
				shot.save_png(ruta)
				print("      captura en %s" % ProjectSettings.globalize_path(ruta))


## La misma vara de `RegionCaptura`: lo que va dentro de un panel con
## desplazamiento lo recorta el panel, así que se mide el panel.
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
