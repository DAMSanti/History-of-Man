extends SceneTree
## Lo que cuesta salir al mapa regional y volver al de la banda.
##
## Queja del usuario del 2026-09-14: «cada vez que salgo al mapa regional y
## vuelvo a mi mapa o a otro, tarda bastante. Debes buscar como optimizarlo».
## Antes de optimizar nada hay que saber **dónde** se va el tiempo, porque las
## dos escenas se montan enteras en cada viaje y cada una hace cosas distintas.
##
## Mide el reloj de pared de tres tramos, con la escena ya cargada en memoria
## —o sea sin contar el arranque en frío del juego, que se paga una vez—:
##
##   LOCAL INICIAL   montar el mapa de la banda desde el menú
##   IDA             de la banda al regional
##   VUELTA          del regional a la banda
##
##   godot --headless --path . --script res://scripts/tests/TransitoProbe.gd
##
## Va sin ventana a propósito: lo que se busca es el coste de CONSTRUIR las
## escenas —cargar el relieve, generar la malla, armar la interfaz—, no el de
## dibujarlas. Si alguna vez hace falta el coste de dibujo, eso es otra sonda y
## necesita ventana (ver [sondas-de-captura-necesitan-ventana]).
##
## **Por el camino del juego**: la ida con `DemoMain._return_to_region`, que guarda y
## suelta el campamento, y la vuelta con `RegionMap._entrar_en_el_campamento`, que lo
## adopta. Hasta el 2026-09-15 cambiaba de escena a pelo: la escena se llevaba el
## campamento y salían 16-17 `SCRIPT ERROR` por corrida que el juego no da, y la vuelta
## montaba un campamento nuevo en vez de adoptar el vivo. `A_PELO=1` viaja todavía así,
## y sirve para comprobar que la escena no se lleva el campamento aunque se vaya sin
## soltarlo ([Campamentos.soltar_de_la_escena]).
##
## **Con la pantalla de carga**, que es como viaja el juego (INTERFAZ §9), y esperando a
## que la escena diga `montado`. `A_PELO=1` va además sin pantalla, de un tirón: es la
## carga sin trocear, para comparar lo que cuesta trocearla. El primer viaje es
## EN FRÍO: sin la malla regional en caché —se borra antes— y sin la siembra guardada,
## que es lo que se compara con lo de antes de la pantalla. El segundo, con las dos, y
## dice si la ida encontró la malla y si la vuelta sembró.

const SITE_ID := 56

## Cuántos viajes de ida y vuelta se miden. Dos, para ver si el segundo sale más
## barato que el primero: si baja mucho, es que algo se está cacheando y lo que
## el jugador sufre es sólo el primer viaje.
const VIAJES := 2


func _init() -> void:
	Engine.max_fps = 0
	_preparar()

	var a_pelo := OS.get_environment("A_PELO") == "1"
	var pantalla := not a_pelo
	# Durante `_init` el árbol todavía no es el bucle principal, y la carga en hilo espera
	# cuadros de `Engine.get_main_loop()`.
	await process_frame
	_borrar_la_malla_regional()
	var t0 := Time.get_ticks_msec()
	if not await _montar(Expedition.LOCAL_SCENE, pantalla, true, ""):
		print("no arrancó el mapa de la banda")
		quit(1)
		return
	var local_inicial := Time.get_ticks_msec() - t0

	var idas: Array[int] = []
	var vueltas: Array[int] = []
	var memoria_de_la_siembra := 0
	var mallas: Array[bool] = []
	var siembras: Array[int] = []
	for i in range(VIAJES):
		mallas.append(_hay_malla_regional())
		var t_ida := Time.get_ticks_msec()
		if not await _montar(Expedition.REGION_SCENE, pantalla, a_pelo, "ida"):
			print("no arrancó el mapa regional")
			quit(1)
			return
		idas.append(Time.get_ticks_msec() - t_ida)

		if i == 0:
			# La primera vuelta, en frío: la siembra de montar la banda no cuenta. Y lo que
			# baja la memoria al soltarla es lo que ocupa guardarla (INTERFAZ §9.5, riesgos).
			var con_ella := OS.get_static_memory_usage()
			Forest._siembra_guardada = {}
			await process_frame
			memoria_de_la_siembra = con_ella - OS.get_static_memory_usage()
		var sembradas := Forest.siembras
		var t_vuelta := Time.get_ticks_msec()
		if not await _montar(Expedition.LOCAL_SCENE, pantalla, a_pelo, "vuelta"):
			print("no volvió al mapa de la banda")
			quit(1)
			return
		vueltas.append(Time.get_ticks_msec() - t_vuelta)
		siembras.append(Forest.siembras - sembradas)

	print("")
	print("=== LO QUE CUESTA EL VIAJE (reloj de pared, sin ventana, %s) ===" % (
		"a pelo" if a_pelo else "con pantalla de carga" if pantalla else "sin pantalla"))
	print("  montar el mapa de la banda la primera vez   %5d ms" % local_inicial)
	for i in range(VIAJES):
		print("  viaje %d:  ida al regional %5d ms (malla %s) · vuelta a la banda %5d ms (%s)"
			% [i + 1, idas[i], "en caché" if mallas[i] else "por hacer", vueltas[i],
				"sembrando" if siembras[i] > 0 else "sin sembrar"])
	print("  la siembra guardada ocupa %.0f MB" % (float(memoria_de_la_siembra) / 1048576.0))
	if VIAJES > 1:
		print("")
		print("  El segundo viaje frente al primero: ida %+d ms · vuelta %+d ms."
			% [idas[1] - idas[0], vueltas[1] - vueltas[0]])
		print("  Si bajan mucho, hay caché y el jugador sólo paga el primero.")
	quit()


## Monta una escena y espera a que esté de verdad en pie —`montado`—, no sólo cargada.
##
## `tramo` dice por dónde: «ida» y «vuelta» por las funciones del juego, que abren su
## pantalla; vacío o `a_pelo`, cambiando de escena desde aquí —el primer montaje no
## tiene escena de antes que lo haga—.
func _montar(escena: String, pantalla: bool, a_pelo: bool, tramo: String) -> bool:
	# La de antes también dice `montado`, y con la escena leída en un hilo sigue ahí unos
	# cuadros: sin esto, la ida medía 20 ms.
	var antes := current_scene
	if not a_pelo and tramo == "ida":
		antes.call("_return_to_region")
	elif not a_pelo and tramo == "vuelta":
		var campamento := Campamentos.de_sitio(SITE_ID)
		if campamento == null:
			print("no hay campamento vivo al que volver")
			return false
		antes.call("_entrar_en_el_campamento", campamento)
	elif pantalla:
		Carga.abrir(self, "Viajando")
		Carga.cambiar_de_escena(self, escena)
	else:
		change_scene_to_file(escena)
	# Por cuadros, y con la pantalla cada cuadro es un trozo de carga: el tope es de
	# tiempo, no de cuadros.
	var hasta := Time.get_ticks_msec() + 180000
	while Time.get_ticks_msec() < hasta:
		await process_frame
		if current_scene != null and current_scene != antes and current_scene.get("montado") == true:
			# Un cuadro más: lo que se aplaza a `call_deferred` todavía no ha pasado.
			await process_frame
			return true
	return false


## Las mallas del regional en caché, de cualquier época: ver [RegionMap.sufijo_de_la_cache].
func _mallas_regionales() -> PackedStringArray:
	var hay := PackedStringArray()
	for fichero: String in DirAccess.get_files_at("res://data/dem"):
		if fichero.begins_with("cantabria_region_mar") and fichero.contains("_mesh_r"):
			hay.append("res://data/dem/" + fichero)
	return hay


func _hay_malla_regional() -> bool:
	return not _mallas_regionales().is_empty()


## Para medir el primer viaje en frío. Es caché: la ida la vuelve a hacer y a guardar.
func _borrar_la_malla_regional() -> void:
	for ruta: String in _mallas_regionales():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## La partida mínima para que las dos escenas tengan de dónde tirar.
func _preparar() -> void:
	# La ida guarda, como en el juego: una sonda no escribe en los mapas del jugador.
	Guardado.carpeta = "user://sondas/mapas"
	DirAccess.make_dir_recursive_absolute(Guardado.carpeta)
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	if local == null or site == null:
		print("faltan los datos de relieve")
		return
	GameState.begin(sites)
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
