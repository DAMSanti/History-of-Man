extends SceneTree
## Las cargas del juego, cuadro a cuadro. INTERFAZ §9.
##
## **Con ventana**: lo que se mide es lo que ve el jugador, y una ventana congelada sólo
## se congela si hay ventana.
##
##   godot --path . --script res://scripts/tests/CargaProbe.gd
##
## Recorre los caminos que cambian de escena, con las mismas funciones que los botones:
##
##   NUEVA      nueva partida: al mapa regional
##   FUNDAR     del regional a un valle ya preparado: al mapa de la banda (lo que hace
##              `RegionMap._enter_local`: abrir la pantalla y cambiar de escena)
##   IDA        del mapa de la banda al regional (guarda la partida)
##   RETOMAR    del regional a la partida guardada (lo mismo que «cargar partida»)
##
## De cada uno, desde que se pide hasta que la escena está en pie: el reloj de pared, el
## cuadro más largo y cuántos pasan de 500 ms —el criterio de la spec—. Lo que cuesta
## cada trozo del montaje lo imprimen las propias escenas en sus líneas `[TIMING]`.
##
## Guarda en la carpeta de las sondas, nunca en la del jugador.

const SITE_ID := 56
const LIMITE_MS := 500.0
## Cuadros que se siguen mirando tras estar la escena en pie: lo aplazado con
## `call_deferred` y los primeros cuadros de bosque también congelan.
const COLA := 60

var _sitios: SiteSet


func _init() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	Guardado.carpeta = "user://sondas/mapas"
	DirAccess.make_dir_recursive_absolute(Guardado.carpeta)
	_sitios = load("res://data/sites/cantabria_sites.res")
	for _i in range(10):
		await process_frame

	var resultados: Array[String] = []
	# CONTORNO=1: rehacer el contorno de un valle YA preparado, con red. INTERFAZ §12.
	if OS.get_environment("CONTORNO") == "1":
		resultados.append(await _rehacer_el_contorno(false))
		resultados.append(await _rehacer_el_contorno(true))
		print("")
		print("=== EL CONTORNO REHECHO, CUADRO A CUADRO (ventana 1920x1080) ===")
		for linea: String in resultados:
			print(linea)
		quit()
		return
	# VALLE=1: sólo preparar un valle nuevo, con red. Ver [_preparar_un_valle].
	if OS.get_environment("VALLE") == "1":
		resultados.append(await _preparar_un_valle())
		print("")
		print("=== PREPARAR UN VALLE, CUADRO A CUADRO (ventana 1920x1080) ===")
		for linea: String in resultados:
			print(linea)
		quit()
		return
	# NUEVA: la partida limpia, como `MenuPrincipal._nueva`.
	GameState.started = false
	GameState.discovered = {}
	GameState.niebla = null
	Expedition.clear()
	GameState.begin(_sitios)
	resultados.append(await _camino("NUEVA", func() -> void:
		Carga.abrir(self, "Saliendo a la comarca")
		Carga.cambiar_de_escena(self, Expedition.REGION_SCENE), "montado"))

	# FUNDAR: lo que deja `RegionMap._enter_local` con un valle ya preparado.
	_preparar_la_fundacion()
	resultados.append(await _camino("FUNDAR", func() -> void:
		Carga.abrir(self, "Entrando en %s" % Expedition.site.display_name())
		Carga.cambiar_de_escena(self, Expedition.LOCAL_SCENE), "montado"))

	# IDA: la tecla de volver al mapa regional, que guarda.
	var demo := current_scene
	resultados.append(await _camino("IDA", func() -> void:
		demo.call("_return_to_region"), "montado"))

	# RETOMAR: el botón de retomar del regional, que lee lo guardado.
	var region := current_scene
	resultados.append(await _camino("RETOMAR", func() -> void:
		region.call("_retomar_en", SITE_ID), "montado"))

	print("")
	print("=== LAS CARGAS, CUADRO A CUADRO (ventana 1920x1080) ===")
	for linea: String in resultados:
		print(linea)
	quit()


## REHACER EL CONTORNO de un valle que ya está preparado. INTERFAZ §12.
##
## El caso que congelaba la ventana: el recuadro jugable está en caché y lo que se rehace
## es sólo el relieve de alrededor. Para provocarlo se estropea a propósito el contorno
## que hay —**sobre una copia, en la carpeta de las sondas: no se toca lo del jugador**—:
##
##   - `basto = false`: se le quita el agua. Rehacerlo es una consulta a Overpass, corta.
##   - `basto = true`: se le sube el paso de muestreo. Rehacerlo es la descarga del MDT
##     del IGN para doce kilómetros de lado, que son **43 s medidos**.
##
## Las dos pasan por el mismo camino, así que la corta ya prueba el hilo; la larga es la
## que de verdad congelaba.
func _rehacer_el_contorno(basto: bool) -> String:
	var nombre := "CONTORNO basto" if basto else "CONTORNO seco"
	var origen := "res://data/dem/local/site_%d.res" % SITE_ID
	var origen_contorno := "res://data/dem/local/site_%d_surround.res" % SITE_ID
	if not ResourceLoader.exists(origen) or not ResourceLoader.exists(origen_contorno):
		return "  %s  no está preparado el sitio %d" % [nombre, SITE_ID]

	# La copia, en la carpeta de las sondas.
	var carpeta := "user://sondas/dem"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
	var valle: HeightmapData = load(origen)
	# CON EL SELLO PUESTO A MANO. La copia salía «de una versión anterior» y `preparar`
	# rehacía el valle entero —dos minutos de descarga— en vez de sólo el contorno, que es
	# lo que se viene a medir. La sonda está fabricando el escenario «este valle ya está
	# preparado», así que lo dice.
	valle.pipeline_version = PreparaValle.VERSION
	ResourceSaver.save(valle, "%s/site_%d.res" % [carpeta, SITE_ID])
	var contorno: HeightmapData = load(origen_contorno)
	if basto:
		contorno.meters_per_sample = contorno.meters_per_sample * 4.0
	else:
		contorno.river_mask = PackedFloat32Array()
	contorno.pipeline_version = PreparaValle.VERSION
	ResourceSaver.save(contorno, "%s/site_%d_surround.res" % [carpeta, SITE_ID])

	var sitio: Site = null
	for s: Site in _sitios.sites:
		if s.id == SITE_ID:
			sitio = s
	if sitio == null:
		return "  %s  no está el sitio %d" % [nombre, SITE_ID]

	var estado := {"hecho": false}
	return await _camino(nombre, func() -> void:
		var preparador := PreparaValle.new()
		preparador.carpeta_de_los_valles = carpeta
		Carga.abrir(self, "Entrando en %s" % sitio.display_name())
		Carga.etapas(PreparaValle.ETAPAS)
		preparador.etapa_cambiada.connect(Carga.etapa)
		_esperar_al_valle(preparador, sitio, estado), "", estado)


## PREPARAR UN VALLE NUEVO, como lo hace `RegionMap` al fundar: con la pantalla, sus
## etapas y la preparación en su hilo. Con red: descarga el MDT del IGN y lo de OSM de un
## sitio jugable que todavía no esté preparado, y lo deja guardado como cualquier valle.
func _preparar_un_valle() -> String:
	var sitio: Site = null
	for s: Site in _sitios.playable():
		if not ResourceLoader.exists("res://data/dem/local/site_%d.res" % s.id):
			sitio = s
			break
	if sitio == null:
		return "  VALLE    no queda ningún sitio sin preparar"
	print("  preparando %s (sitio %d)" % [sitio.display_name(), sitio.id])
	var estado := {"hecho": false}
	return await _camino("VALLE", func() -> void:
		var preparador := PreparaValle.new()
		Carga.abrir(self, "Preparando %s" % sitio.display_name())
		Carga.etapas(PreparaValle.ETAPAS)
		preparador.etapa_cambiada.connect(Carga.etapa)
		_esperar_al_valle(preparador, sitio, estado), "", estado)


func _esperar_al_valle(preparador: PreparaValle, sitio: Site, estado: Dictionary) -> void:
	await preparador.preparar(self, sitio, Carga.avanzar_por_tiempo)
	Carga.cerrar()
	estado["hecho"] = true


## Pide el cambio y cuenta los cuadros hasta que la escena tiene `senal` y `COLA` más.
## Con `estado`, en vez de la escena se espera a que `estado.hecho` sea verdad.
func _camino(nombre: String, pedir: Callable, senal: String, estado: Dictionary = {}) -> String:
	var antes := current_scene
	var desde := Time.get_ticks_usec()
	var ultimo := desde
	pedir.call()
	var cuadros: Array[float] = []
	var barra: Array[float] = []
	var etapas: Array[String] = []
	var en_pie := -1
	for _i in range(20000):
		await process_frame
		var ahora := Time.get_ticks_usec()
		cuadros.append(float(ahora - ultimo) / 1000.0)
		ultimo = ahora
		barra.append(Carga.valor() if Carga.abierta() else -1.0)
		etapas.append(Carga.texto() if Carga.abierta() else "")
		if en_pie < 0 and not estado.is_empty() and bool(estado["hecho"]):
			en_pie = cuadros.size()
		if en_pie < 0 and estado.is_empty() and current_scene != null and current_scene != antes \
				and _en_pie(current_scene.get(senal)):
			en_pie = cuadros.size()
		if en_pie >= 0 and cuadros.size() >= en_pie + COLA:
			break
	var total := 0.0
	var peor := 0.0
	var largos := 0
	for i in range(cuadros.size()):
		if i < en_pie:
			total += cuadros[i]
		peor = maxf(peor, cuadros[i])
		if cuadros[i] > LIMITE_MS:
			largos += 1
			# La etapa que había al terminar el cuadro largo y la de antes: el trabajo que
			# no cedió está entre las dos.
			print("    %s: cuadro %d de %.0f ms, entre «%s» y «%s»" % [nombre, i, cuadros[i],
				etapas[i - 1] if i > 0 else "", etapas[i]])
	_por_etapa(nombre, cuadros, etapas, en_pie)
	return "  %-8s en pie a %6.0f ms · cuadro más largo %6.0f ms · %d cuadros de más de %d ms · %d cuadros%s" % [
		nombre, total, peor, largos, int(LIMITE_MS), cuadros.size(), _la_barra(cuadros, barra, en_pie)]


## Lo que hizo la barra: si retrocedió, cuánto estuvo quieta como mucho, y cuánto tiempo
## había pasado al llegar a la mitad. Vacío si no hubo pantalla.
func _la_barra(cuadros: Array[float], barra: Array[float], en_pie: int) -> String:
	var hubo := false
	var atras := 0
	var quieta := 0.0
	var quieta_max := 0.0
	var anterior := -1.0
	var tiempo := 0.0
	var a_la_mitad := -1.0
	var total := 0.0
	for i in range(mini(en_pie, cuadros.size())):
		total += cuadros[i]
	for i in range(mini(en_pie, barra.size())):
		tiempo += cuadros[i]
		if barra[i] < 0.0:
			continue
		hubo = true
		if anterior >= 0.0 and barra[i] < anterior - 0.0001:
			atras += 1
		if anterior >= 0.0 and absf(barra[i] - anterior) < 0.0001:
			quieta += cuadros[i]
		else:
			quieta = 0.0
		quieta_max = maxf(quieta_max, quieta)
		if a_la_mitad < 0.0 and barra[i] >= 0.5:
			a_la_mitad = tiempo
		anterior = barra[i]
	if not hubo:
		return " · sin pantalla"
	return " · barra: %d retrocesos, quieta como mucho %.1f s, mitad a %.0f %% del tiempo" % [
		atras, quieta_max / 1000.0, 100.0 * a_la_mitad / maxf(total, 1.0)]


## Cuánto tiempo pasó la pantalla en cada etapa: los pesos de la barra salen de aquí.
func _por_etapa(nombre: String, cuadros: Array[float], etapas: Array[String], en_pie: int) -> void:
	var tiempo := {}
	var orden: Array[String] = []
	for i in range(mini(en_pie, etapas.size())):
		var e := etapas[i]
		if e.is_empty():
			e = "(antes de declarar las etapas)"
		if not tiempo.has(e):
			orden.append(e)
		tiempo[e] = float(tiempo.get(e, 0.0)) + cuadros[i]
	for e: String in orden:
		print("    %s · %-42s %6.0f ms" % [nombre, e, float(tiempo[e])])


## La señal de que la escena está en pie: que exista, o si es un booleano —`montado`,
## desde que el mapa se monta en varios cuadros—, que sea verdad.
func _en_pie(valor: Variant) -> bool:
	return valor != null and (not (valor is bool) or bool(valor))


func _preparar_la_fundacion() -> void:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var site: Site = null
	for s: Site in _sitios.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0, maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0, maxf(size_m.y - half * 2.0, 0.0)))
