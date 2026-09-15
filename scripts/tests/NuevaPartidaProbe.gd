extends SceneTree
## El camino entero: menú → Nueva partida → mapa regional → fundar en el valle.
##
## Spec: `docs/INTERFAZ.md` §7, criterios 1 y 2. `MenuCaptura` mira el menú y el
## modal, y `TestPartida` mira los ficheros; lo que no cubría ninguno de los dos
## es **el recorrido**: que pulsar «Nueva partida» de verdad lleve a una partida
## limpia y que desde ahí se pueda fundar.
##
## Y de paso comprueba el criterio 2 **byte a byte**, que en la suite sólo se
## comprueba a nivel de lista: se huellan los ficheros de las partidas guardadas
## antes de empezar y se vuelven a huellar al final. Empezar una partida no
## puede tocarlas.
##
## Los botones se pulsan de verdad —`pressed.emit()` y una tecla F por el mismo
## camino que la del jugador—: llamar a los métodos por dentro comprobaría que
## los métodos funcionan, no que el recorrido existe.
##
## **Sólo funda donde hay recuadro horneado.** Fundar en un emplazamiento sin
## `data/dem/local/site_<id>.res` se baja el relieve del IGN, que ni es rápido ni
## es cosa de una sonda. Hoy están horneados el 56 —el de casa— y el 9000.
##
## Con ventana: con `--headless` no hay imagen.
##   godot --path . --script res://scripts/tests/NuevaPartidaProbe.gd

## El que sale elegido al empezar, que es el de casa. Si esto deja de coincidir,
## la sonda lo dice y no funda: ver el encabezado.
const CASA := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Sus propias carpetas: una sonda no escribe en las partidas del jugador.
	Partidas.raiz = "user://sondas/partidas"
	Partidas.borrador = "user://sondas/partida_abierta"
	Guardado.carpeta = Partidas.borrador

	_una_partida_guardada_de_antes()
	var antes := _huella_de_las_guardadas()
	print("")
	print("=== EL RECORRIDO ===")
	print("partidas guardadas antes de empezar: %d" % antes.size())

	if not await _el_menu():
		quit(1)
		return
	if not await _pulsar_nueva_partida():
		quit(1)
		return
	if not await _fundar():
		quit(1)
		return

	var despues := _huella_de_las_guardadas()
	print("")
	print("=== LO GUARDADO, ANTES Y DESPUÉS ===")
	print("partidas guardadas al acabar: %d" % despues.size())
	print("intactas byte a byte: %s" % ("sí" if antes == despues else "NO"))
	for nombre: String in antes:
		if not despues.has(nombre) or String(despues[nombre]) != String(antes[nombre]):
			print("   cambió %s" % nombre)
	quit()


# ------------------------------------------------------------- el menú --

func _el_menu() -> bool:
	change_scene_to_file("res://scenes/menu_principal.tscn")
	for i in range(30):
		await process_frame
	var menu := current_scene
	print("")
	print("1. el juego arranca en: %s" % menu.name)
	print("   simulación montada: %s" % ("sí" if _hay_simulacion(menu) else "no"))
	return menu.name == "MenuPrincipal"


func _pulsar_nueva_partida() -> bool:
	var boton := _boton_que_dice(current_scene, "Nueva partida")
	if boton == null:
		print("   NO hay botón de «Nueva partida»")
		return false
	boton.pressed.emit()
	# El mapa regional tarda en montarse: relieve, máscara de era y sitios.
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene.name == "RegionMap":
			break
	var mapa := current_scene
	print("")
	print("2. «Nueva partida» lleva a: %s" % mapa.name)
	if mapa.name != "RegionMap":
		return false
	# Esperar a que el mapa acabe de montar sus sitios.
	for i in range(120):
		await process_frame
		if mapa._selected != null:
			break
	print("   carpeta de trabajo: %s" % Guardado.carpeta)
	print("   mapas dentro de la partida nueva: %d" % Guardado.cabeceras().size())
	var elegido: int = mapa._selected.id if mapa._selected != null else -1
	print("   emplazamiento elegido al llegar: %d" % elegido)
	return true


# ------------------------------------------------------------- fundar --

func _fundar() -> bool:
	var mapa := current_scene
	if mapa._selected == null or mapa._selected.id != CASA:
		print("   el sitio de casa ya no es el %d: la sonda no funda para no " % CASA
			+ "bajarse un relieve nuevo")
		return false
	# Si hubiera estado guardado de este mapa, F RETOMARÍA en vez de fundar
	# —ver `RegionMap._found_settlement`—. Que funde es la prueba de que la
	# partida empezó limpia.
	print("   ¿hay estado de este mapa?: %s"
		% ("sí (entonces F retomaría)" if Guardado.hay_partida(CASA) else "no"))

	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F
	tecla.pressed = true
	Input.parse_input_event(tecla)

	# Fundar monta el valle entero: relieve, bosque, fauna y banda.
	for i in range(600):
		await process_frame
		if current_scene != null and current_scene.name == "DemoMain":
			break
	var demo := current_scene
	print("")
	print("3. fundar lleva a: %s" % demo.name)
	if demo.name != "DemoMain":
		return false
	for i in range(120):
		await process_frame
		if "sim" in demo and demo.sim != null and demo.sim.people.size() > 0:
			break
	var sim: Node = demo.sim if "sim" in demo else null
	if sim == null:
		print("   NO hay simulación en el valle")
		return false
	print("   jornada %d · %d personas · semilla %d" % [
		sim.day, sim.people.size(), sim.game_seed])
	print("   el guardado de mapas apunta a: %s" % Guardado.carpeta)
	print("   dentro de la partida (mapas ya guardados): %d"
		% Guardado.cabeceras().size())
	for i in range(20):
		await process_frame
	root.get_texture().get_image().save_png("user://nueva_partida.png")
	print("   captura en %s" % ProjectSettings.globalize_path("user://nueva_partida.png"))
	return true


# ------------------------------------------------------------ por dentro --

## Una partida guardada de antes, para tener qué comparar. Si ya hay alguna, se
## deja como está: lo que importa es que no cambie.
func _una_partida_guardada_de_antes() -> void:
	if not Partidas.lista().is_empty():
		return
	Partidas.nueva()
	var sitio := Site.new()
	sitio.id = 9000
	Expedition.site = sitio
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 80.0)
	sim.techs = TechTree.new()
	sim.knowledge = BandKnowledge.new()
	sim.day = 31
	var azar := RandomNumberGenerator.new()
	azar.seed = 8
	for i in range(9):
		sim.people.append(Inhabitant.create(i, Vector3.ZERO, azar))
	Guardado.guardar(sim)
	Partidas.guardar("La de antes")
	Expedition.site = null
	# Y se deja el estado global como lo encontró: quien monta el menú tiene que
	# encontrarse una partida sin empezar, no la de esta trastienda.
	GameState.started = false
	GameState.discovered = {}
	Expedition.clear()


## La huella de cada fichero de cada partida guardada: ruta → hash del contenido.
func _huella_de_las_guardadas() -> Dictionary:
	var huellas := {}
	var raiz := DirAccess.open(Partidas.raiz)
	if raiz == null:
		return huellas
	for carpeta: String in raiz.get_directories():
		var dentro := DirAccess.open(Partidas.raiz.path_join(carpeta))
		if dentro == null:
			continue
		for fichero: String in dentro.get_files():
			var ruta := Partidas.raiz.path_join(carpeta).path_join(fichero)
			huellas[ruta] = FileAccess.get_sha256(ruta)
	return huellas


func _hay_simulacion(nodo: Node) -> bool:
	if nodo is SettlementSim:
		return true
	for hijo: Node in nodo.get_children():
		if _hay_simulacion(hijo):
			return true
	return false


## El botón que dice esto, buscando por el árbol. Se pulsa el de verdad: si el
## menú cambia de forma, la sonda lo dice en vez de seguir llamando por dentro a
## un método que ya no usa nadie.
func _boton_que_dice(nodo: Node, texto: String) -> Button:
	var boton := nodo as Button
	if boton != null and boton.text == texto:
		return boton
	for hijo: Node in nodo.get_children():
		var encontrado := _boton_que_dice(hijo, texto)
		if encontrado != null:
			return encontrado
	return null
