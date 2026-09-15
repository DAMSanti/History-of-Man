extends SceneTree
## El menú principal, la lista de partidas y el modal de ESC, vistos.
##
## Spec: `docs/INTERFAZ.md` §7, criterios 1, 3 y 4. Los tres sólo se pueden
## comprobar mirando la pantalla y pulsando teclas de verdad:
##
##   1. al arrancar hay menú y **no hay simulación corriendo**;
##   3. con una ventana abierta ESC la cierra y NO abre el modal; sin ninguna,
##      lo abre;
##   4. con el modal abierto, la jornada y la hora no avanzan.
##
## Con ventana: con `--headless` no hay imagen.
##   godot --path . --script res://scripts/tests/MenuCaptura.gd

const SITE_ID := 56

## Cuánto se deja correr el reloj con el modal abierto, en milisegundos de reloj
## real. Con `time_scale` a 5 son varias horas de juego: si la jornada no se
## mueve en eso, es que está parada de verdad.
const MIRANDO := 6000


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# Sus propias carpetas: una sonda no escribe en las partidas del jugador.
	# Ver [Partidas.raiz] y `TestPartida`.
	Partidas.raiz = "user://sondas/partidas"
	Partidas.borrador = "user://sondas/partida_abierta"
	Guardado.carpeta = Partidas.borrador

	_una_partida_de_muestra()
	await _el_menu()
	# SOLO=menu se salta el valle, que tarda casi un minuto en montarse. Sirve
	# para mirar el menú y la lista sin pagar la escena entera.
	if OS.get_environment("SOLO") == "region":
		await _en_la_comarca()
	elif OS.get_environment("SOLO") != "menu":
		await _el_modal()
	print("capturas en %s" % ProjectSettings.globalize_path("user://"))
	quit()


## Una partida guardada de mentira, para que la lista se vea con algo dentro:
## una lista vacía no enseña si las filas dicen lo que hacen falta para elegir.
func _una_partida_de_muestra() -> void:
	if not Partidas.lista().is_empty():
		return
	Partidas.nueva()
	var sitio := Site.new()
	sitio.id = SITE_ID
	Expedition.site = sitio
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.store.add(Materia.Kind.CARNE_SECA, 140.0)
	sim.techs = TechTree.new()
	sim.knowledge = BandKnowledge.new()
	sim.day = 63
	var azar := RandomNumberGenerator.new()
	azar.seed = 3
	for i in range(11):
		sim.people.append(Inhabitant.create(i, Vector3.ZERO, azar))
	Guardado.guardar(sim)
	Partidas.guardar("La cueva de los pendíos")
	Expedition.site = null


## El menú, con y sin lista desplegada.
func _el_menu() -> void:
	change_scene_to_file("res://scenes/menu_principal.tscn")
	for i in range(30):
		await process_frame
	var menu := current_scene
	print("")
	print("=== EL MENÚ ===")
	print("escena: %s" % menu.name)
	# Criterio 1: aquí no hay partida. Si hubiera simulación, alguien la habría
	# montado sin que nadie la pidiera.
	print("hay simulación montada: %s" % ("sí" if menu.get_node_or_null("SettlementSim")
		else "no"))
	print("partidas guardadas que se ven: %d" % Partidas.lista().size())
	root.get_texture().get_image().save_png("user://menu_principal.png")

	# Y con la lista abierta, que es el otro estado de esta pantalla.
	menu._abrir_lista()
	for i in range(10):
		await process_frame
	root.get_texture().get_image().save_png("user://menu_lista.png")


## Y el mismo modal en el mapa regional, que es la otra pantalla de una partida.
## Aquí no hay reloj que parar: lo que se comprueba es que ESC lo abra y que se
## pueda guardar desde ahí.
func _en_la_comarca() -> void:
	change_scene_to_file("res://scenes/region_map.tscn")
	for i in range(90):
		await process_frame
	var mapa := current_scene
	var menu: Node = mapa._menu_del_juego if "_menu_del_juego" in mapa else null
	print("")
	print("=== ESC EN LA COMARCA ===")
	if menu == null:
		print("el mapa regional no tiene menú de partida"); return
	_pulsar_escape()
	for i in range(10):
		await process_frame
	print("ESC abre el modal: %s" % ("sí" if menu.esta_abierto() else "NO"))
	root.get_texture().get_image().save_png("user://menu_en_la_comarca.png")


## El modal sobre el valle: que ESC lo abra sólo cuando no hay ventana, y que
## con él abierto el reloj no corra.
func _el_modal() -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan datos del emplazamiento"); return
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if site == null:
		print("sin emplazamiento"); return

	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half,
			0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half,
			0.0, maxf(size_m.y - half * 2.0, 0.0)))

	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(60):
		await process_frame
	var demo := current_scene
	var sim: Node = demo.sim if "sim" in demo else null
	var menu: Node = demo.menu_del_juego if "menu_del_juego" in demo else null
	if sim == null or menu == null:
		print("sin simulación o sin menú de partida"); return

	sim.assign_default_jobs()
	sim.time_scale = 5.0
	for i in range(20):
		await process_frame

	print("")
	print("=== ESC EN EL VALLE ===")
	# Con una ventana abierta: ESC la cierra y el modal NO se abre.
	demo.ui.show_store()
	for i in range(5):
		await process_frame
	_pulsar_escape()
	for i in range(5):
		await process_frame
	print("con una ventana delante, ESC abre el modal: %s"
		% ("sí" if menu.esta_abierto() else "no (bien: la cierra)"))

	# Sin nada delante: ESC abre el modal.
	_pulsar_escape()
	for i in range(5):
		await process_frame
	print("sin ventanas, ESC abre el modal: %s"
		% ("sí" if menu.esta_abierto() else "NO"))

	var jornada_antes: int = sim.day
	var hora_antes: float = sim.hour
	var desde := Time.get_ticks_msec()
	while Time.get_ticks_msec() - desde < MIRANDO:
		await process_frame
	print("con el modal abierto, jornada %d → %d y hora %.2f → %.2f" % [
		jornada_antes, sim.day, hora_antes, sim.hour])
	root.get_texture().get_image().save_png("user://menu_del_juego.png")


## Una pulsación de ESC de verdad, por el mismo camino que la del jugador.
func _pulsar_escape() -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_ESCAPE
	tecla.pressed = true
	Input.parse_input_event(tecla)
