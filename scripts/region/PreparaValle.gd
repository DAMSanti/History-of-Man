class_name PreparaValle
extends RefCounted
## Prepara el relieve fino de un sitio: lo descarga, lo limpia y lo guarda en
## `res://data/dem/local/site_<id>.res`, con su contorno.
##
## Salió de `RegionMap._found_settlement` el 2026-09-14 (SISTEMAS §23, tarea 13):
## migrar a un sitio pide su valle preparado **al mandar el viaje** —decisión del
## usuario—, y eso se hace desde la ficha de un campamento, donde no hay mapa
## regional. Una sola receta para los dos caminos: si el panel preparara el valle
## con otra, el mismo sitio saldría distinto según desde dónde se fundara.
##
## Las teselas se bajan al preparar y no antes porque a 13,9 m por muestra toda
## Cantabria serían unas 960 teselas; de un sitio son cuatro.

## Lo que va diciendo mientras trabaja: la descarga bloquea segundos, y sin
## mensaje parece colgado.
signal aviso(texto: String)

## La etapa en que va la preparación, por su número en [ETAPAS]. Para la pantalla de carga.
signal etapa_cambiada(indice: int)

## Lo que hace preparar un valle, por etapas y con lo que cuesta cada una en milisegundos.
## Medido con `CargaProbe VALLE=1` preparando la Cueva de la Lastrilla (2026-09-15): el
## MDT 4,7 s, quitar la obra moderna 4,7, los ríos 43 —Overpass contestó con error y se
## reintentó—, el relieve de alrededor 43 y guardar 0,1. La erosión va apagada
## (`erosion_drops` = 0) y no pesa. **Casi todo es red**, y la red varía: por eso la barra
## avanza por tiempo sin pararse cuando una etapa tarda más (ver
## [RepartoDeCarga.fraccion_por_tiempo]).
const ETAPAS := [
	["Descargando el relieve", 4700.0],
	["Quitando la obra moderna", 4700.0],
	["Erosionando el relieve", 100.0],
	["Trazando los ríos", 20000.0],
	["Descargando el relieve de alrededor", 43000.0],
	["Guardando el valle", 150.0],
]

var _cerrojo := Mutex.new()
var _texto := ""
var _etapa := -1
var _publicado := ""
var _etapa_publicada := -1


## Lo que el hilo va haciendo: se guarda, y lo publica [_publicar] desde el principal.
func _avisar(texto: String, etapa: int) -> void:
	_cerrojo.lock()
	_texto = texto
	if etapa >= 0:
		_etapa = etapa
	_cerrojo.unlock()


func _publicar() -> void:
	_cerrojo.lock()
	var texto := _texto
	var etapa := _etapa
	_cerrojo.unlock()
	if texto != _publicado:
		_publicado = texto
		aviso.emit(texto)
	if etapa != _etapa_publicada:
		_etapa_publicada = etapa
		etapa_cambiada.emit(etapa)

## Sello del proceso que genera el recuadro local. SUBIRLO cuando cambie algo
## que afecte al relieve guardado -la fuente de cotas, el borrado de obra
## humana, el umbral de cauce- para que los ficheros ya bakeados se rehagan
## solos en vez de quedarse viejos sin avisar.
const VERSION := 9

## Usar el MDT del IGN (5 m, LiDAR) para el mapa local en vez del relieve
## global. Tarda mas en descargar pero es el mayor salto de calidad disponible,
## y no cuesta un solo frame: la malla tiene los mismos vertices.
var use_ign_elevation: bool = true

## Borrar del relieve carreteras, pistas, vias de tren y canteras usando la
## geometria de OpenStreetMap.
##
## El MDT del IGN es LiDAR: si hay una carretera de pueblo, esta TALLADA en la
## malla con su desmonte y su terraplen. En un mapa que empieza en el
## Paleolitico eso es un anacronismo, asi que se recorta y se reconstruye la
## ladera de debajo. Ver [TerrainInpainter].
var remove_human_works: bool = true

## Gotas de erosion hidraulica sobre el recuadro local, y pasadas de erosion
## termica despues. A cero se desactiva.
##
## 250.000 gotas sobre 900x900 celdas son unas 0,3 por celda, que suena poco
## pero cada una recorre hasta 64 pasos: da del orden de 20 visitas por celda.
## Se paga UNA vez, al bakear el emplazamiento.
## APAGADA. Las carcavas que producia se leian como carreteras y terrazas
## cortando la ladera: sobre un MDT que ya es dato medido, la erosion no
## anadia relieve creible sino cicatrices que competian con el relieve real.
## El codigo y sus pruebas se quedan -[Erosion]- por si mas adelante interesa
## para terreno generado, que es donde de verdad hace falta.
var erosion_drops: int = 0
var erosion_thermal_passes: int = 8

## Paso de la rejilla que se guarda para el contorno, en metros. El dato baja
## del IGN a 5 m como el mapa jugable; esto es solo cuanto se conserva.
##
## Estuvo en 15 m con este argumento: la malla del contorno muestreaba cada
## 32 m, asi que guardar mas fino era detalle que no se llegaba a dibujar. El
## argumento era bueno y la conclusion se quedo vieja en cuanto la malla subio
## a 513 vertices -8 m por vertice-: ahora el que limita es el DATO, y el
## contorno se veia de plastilina al lado del recuadro.
##
## A 8 m son 1.500x1.500 muestras para los 12 km de lado. Es un fichero bastante
## mas gordo y una descarga mas larga al fundar, y se paga una sola vez.
##
## No baja a 5 m porque con 8 m por vertice de malla no habria donde meterlo:
## serian 2.400x2.400 -casi seis millones de cotas- solo para interpolar.
var surround_meters: float = 8.0


## El relieve fino del sitio, preparado, o null si no se ha podido descargar.
## Si ya estaba guardado y es de esta versión, se lee.
##
## El recuadro local es caro de montar -descarga del IGN, borrado de obra
## humana, drenaje- pero es SIEMPRE EL MISMO para un emplazamiento dado. Se
## guarda en disco la primera vez y a partir de ahi se lee, con lo que la
## segunda fundacion es instantanea. El sello de version invalida el fichero
## solo si cambia el proceso, sin tener que acordarse de borrarlo.
## `al_cuadro`, si se da, se llama en cada cuadro de espera: quien enseña la barra la
## mueve con él.
func preparar(arbol: SceneTree, sitio: Site, al_cuadro: Callable = Callable()) -> HeightmapData:
	var cache_path := "res://data/dem/local/site_%d.res" % sitio.id
	if ResourceLoader.exists(cache_path):
		var cached: HeightmapData = load(cache_path)
		if cached != null and cached.pipeline_version == VERSION:
			print("PreparaValle: recuadro local leido de %s" % cache_path)
			# El contorno tiene su propia resolucion y su propia vida: si se
			# ha quedado mas basto de lo que ahora se pide, se rehace SOLO el.
			# Subir el sello del recuadro para esto obligaria a volver a
			# descargar el mapa jugable entero, que no ha cambiado en nada.
			await _refresh_surround_if_coarse(arbol, sitio, cached)
			return cached
		print("PreparaValle: %s es de una version anterior, se rehace" % cache_path)

	# LO LARGO VA EN UN HILO. Descargar el MDT, las vías y los ríos de OSM, reconstruir el
	# relieve y guardar son decenas de segundos de trabajo de datos, sin un solo nodo: se
	# hacía en este hilo con dos cuadros de respiro entre paso y paso, y cada paso
	# congelaba la ventana. Aquí se espera cuadro a cuadro y se va diciendo por dónde va.
	# INTERFAZ §9.
	var hilo := Thread.new()
	hilo.start(_hacer_el_valle.bind(sitio, cache_path))
	while hilo.is_alive():
		_publicar()
		if al_cuadro.is_valid():
			al_cuadro.call()
		await arbol.process_frame
	var hecho: HeightmapData = hilo.wait_to_finish()
	_publicar()
	return hecho


## La receta entera, en el hilo de [preparar]. Lo que va diciendo lo apunta con [_avisar]
## y lo publica el hilo principal: una señal no se emite desde otro hilo.
func _hacer_el_valle(sitio: Site, cache_path: String) -> HeightmapData:
	_avisar("Descargando relieve de %s...\n(unos segundos)" % sitio.display_name(), 0)

	# Margen justo sobre el recuadro jugable: cada decima de grado de mas son
	# miles de muestras que hay que descargar y parsear.
	var margin_m := float(Expedition.local_size_m) * 0.55
	var half_lat := margin_m * IGNImporter.DEG_PER_METER_LAT
	var half_lon := margin_m * IGNImporter.deg_per_meter_lon(sitio.lat)

	# Primero el MDT del IGN: 5 m derivados de LiDAR frente a los 13,9 m de
	# terrarium, que ademas da cotas en metros enteros. Es la diferencia entre
	# relieve y una interpolacion suave.
	var local: HeightmapData = null
	if use_ign_elevation:
		local = IGNImporter.new().import_area(
			sitio.lat + half_lat, sitio.lat - half_lat,
			sitio.lon - half_lon, sitio.lon + half_lon)

	var importer := DEMImporter.new()
	if local == null:
		# Reserva: fuera de Espana, o si el servicio del IGN no responde
		_avisar("Sin MDT del IGN, usando relieve global...", 0)
		local = importer.import_area(
			sitio.lat + half_lat, sitio.lat - half_lat,
			sitio.lon - half_lon, sitio.lon + half_lon, 13)
		if local == null:
			_avisar("No se pudo descargar el relieve.\nComprueba la conexion.", -1)
			return null
		# Los artefactos que corregimos eran de terrarium. El MDT es dato
		# controlado y un umbral bajo se cargaria acantilados reales.
		importer.despike(local)

	# Quitar la obra humana ANTES de calcular los cauces: si se hace despues,
	# el drenaje se ha calculado ya sobre una cuneta de carretera y sale un rio
	# donde no lo hay.
	if remove_human_works:
		_avisar("Quitando carreteras y obra moderna del relieve...", 1)

		var ways := OSMWays.new().fetch_area(
			local.lat_north, local.lat_south, local.lon_west, local.lon_east)
		if ways.is_empty():
			# Overpass caido o recuadro sin nada: se sigue igual, esto es una
			# mejora del paisaje, no un requisito para fundar
			print("PreparaValle: sin geometrias de OSM, el relieve se deja como esta")
		else:
			var mask := TerrainInpainter.build_mask(local, ways)
			var repaired := TerrainInpainter.inpaint(local, mask)
			print("PreparaValle: %d vias/areas de OSM, %d celdas de relieve reconstruidas (%.1f%%)" % [
				ways.size(), repaired,
				100.0 * float(repaired) / maxf(float(local.width * local.height), 1.0)])

	# Erosion: el MDT del IGN es fiel pero esta remuestreado a 5 m, y ese
	# remuestreo se come las carcavas y los regueros, que a esa escala son
	# justo lo que distingue una ladera de una rampa. Devolverselos con RUIDO
	# daria bultos sin relacion entre si; devolverselos con el proceso que los
	# produce da vaguadas que desembocan y conos de deyeccion al pie.
	#
	# Va DESPUES de quitar la obra humana -no tiene sentido erosionar un
	# terraplen de carretera- y ANTES de los cauces, para que el agua de OSM se
	# encaje sobre un relieve ya trabajado.
	if erosion_drops > 0:
		_avisar("Erosionando el relieve...", 2)

		var t0 := Time.get_ticks_msec()
		# A media resolucion: las formas de la erosion viven a escala de
		# decenas de metros y salen igual sobre celdas de diez que de cinco,
		# pero cuestan la cuarta parte. Medido sobre este mismo recuadro:
		# 90 s a resolucion completa frente a 22 s asi, y con MAS efecto.
		# 0.67 es la tangente de 34 grados, el talud de un canchal calizo.
		Erosion.erode_coarse(local.elevations, local.width, local.height,
			erosion_drops, erosion_thermal_passes,
			local.meters_per_sample, 0.67, sitio.id, 2)

		var lo := INF
		var hi := -INF
		for e in local.elevations:
			lo = minf(lo, e)
			hi = maxf(hi, e)
		local.min_elevation = lo
		local.max_elevation = hi
		print("PreparaValle: erosion de %d gotas en %d ms, cotas %.1f..%.1f" % [
			erosion_drops, Time.get_ticks_msec() - t0, lo, hi])

	# Los cauces salen de OSM, no del relieve. La acumulacion de drenaje D8
	# funciona a escala regional, donde una cuenca grande se ve sola, pero
	# sobre 4 km dejaba un 0,5% de celdas con valor medio 0,06: invisible. Y
	# ademas no sabe cual de esos hilos es el Nansa.
	_avisar("Trazando los ríos...", 3)
	var hidro := OSMWays.new().fetch_water(
		local.lat_north, local.lat_south, local.lon_west, local.lon_east)
	var canales: Array = hidro.get("channels", [])
	var laminas: Array = hidro.get("bodies", [])

	if canales.is_empty() and laminas.is_empty():
		# Reserva: sin OSM se vuelve al drenaje deducido, que es poco pero es
		# mejor que un recuadro completamente seco
		print("PreparaValle: sin hidrografia de OSM, se deduce del relieve")
		importer.compute_river_mask(local, 20, 0.35)
	else:
		Hydrography.apply(local, canales, laminas)
		var mojadas := 0
		for v in local.river_mask:
			if v > 0.01:
				mojadas += 1
		print("PreparaValle: %d cauces y %d laminas de OSM, %.2f%% del recuadro con agua" % [
			canales.size(), laminas.size(),
			100.0 * float(mojadas) / maxf(float(local.width * local.height), 1.0)])

	# --- relieve de las casillas de alrededor -----------------------------
	# Mismo sistema que el mapa jugable: MDT05 del IGN, LiDAR. El MDT regional
	# que se usaba antes da 111 m por muestra, o sea 37 puntos por casilla de
	# 4 km, y de ahi salian lomas lisas sin nada que se pareciera a un valle.
	#
	# Se pide el bloque de 3x3 casillas en UNA sola peticion -unos 12 km de
	# lado, medido: 19 s y 79 MB- y se guarda a 15 m por muestra. El dato es
	# el mismo MDT05; lo que cambia es cuanto se guarda, y 15 m sobra porque
	# la malla del contorno muestrea cada 32 m.
	_avisar("Descargando el relieve de alrededor...\nMDT del IGN, unos segundos.", 4)

	var surround_path := "res://data/dem/local/site_%d_surround.res" % sitio.id
	var span_lat := local.lat_north - local.lat_south
	var span_lon := local.lon_east - local.lon_west
	var t_sur := Time.get_ticks_msec()
	var surround: HeightmapData = null
	if use_ign_elevation:
		surround = IGNImporter.new().import_area(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon,
			surround_meters)

	if surround == null:
		# Reserva: fuera de Espana o si el IGN no responde
		surround = importer.import_area(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon, 13)
		if surround != null:
			importer.despike(surround)

	if surround != null:
		_apply_surround_water(surround)
		surround.pipeline_version = VERSION
		ResourceSaver.save(surround, surround_path)
		print("PreparaValle: contorno bakeado en %d ms, %d x %d a %.1f m (%s)" % [
			Time.get_ticks_msec() - t_sur, surround.width, surround.height,
			surround.meters_per_sample, surround.source])
	else:
		print("PreparaValle: sin contorno propio, se usara el MDT regional")

	_avisar("Guardando el valle...", 5)
	local.pipeline_version = VERSION
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://data/dem/local"))
	ResourceSaver.save(local, cache_path)
	print("PreparaValle: recuadro local bakeado en %s" % cache_path)
	return local


## Pone al dia el contorno: la resolucion del relieve y los cauces.
##
## Son DOS cosas independientes y con precios muy distintos. Rehacer el MDT es
## una descarga larga; traer la hidrografia de OSM es corta. Si se comprueban
## juntas, un contorno que solo le falta el agua paga la descarga entera del
## relieve para nada, y peor: si el IGN falla, se queda tambien sin rios.
func _refresh_surround_if_coarse(arbol: SceneTree, sitio: Site,
		local: HeightmapData) -> void:
	if local == null:
		return

	var path := "res://data/dem/local/site_%d_surround.res" % sitio.id
	if not ResourceLoader.exists(path):
		return

	var surround: HeightmapData = load(path)
	if surround == null:
		return

	# Con un 10% de margen: no merece la pena una descarga de minutos por una
	# diferencia de decimales
	var coarse := surround.meters_per_sample > surround_meters * 1.1
	var dry := surround.river_mask.is_empty()
	if not coarse and not dry:
		return

	if coarse and use_ign_elevation:
		aviso.emit("Mejorando el relieve de alrededor...\n"
			+ "MDT del IGN a %.0f m para 12 km de lado: esto tarda." % surround_meters)
		await arbol.process_frame
		await arbol.process_frame

		var span_lat := local.lat_north - local.lat_south
		var span_lon := local.lon_east - local.lon_west
		var started := Time.get_ticks_msec()
		var finer: HeightmapData = IGNImporter.new().import_area(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon, surround_meters)

		if finer != null:
			surround = finer
			dry = true  # el MDT nuevo viene seco: hay que volver a pintarle el agua
			print("PreparaValle: contorno rehecho en %d ms, %d x %d a %.1f m" % [
				Time.get_ticks_msec() - started, surround.width, surround.height,
				surround.meters_per_sample])
		else:
			print("PreparaValle: el IGN no ha respondido, se queda el relieve que habia")

	if dry:
		aviso.emit("Trazando los rios de alrededor...")
		await arbol.process_frame
		_apply_surround_water(surround)

	surround.pipeline_version = VERSION
	ResourceSaver.save(surround, path)


## Mete los cauces de OSM en el MDT del contorno.
##
## El agua tiene que CONTINUAR fuera del recuadro. Sin esto el Nansa llegaba
## al borde y se cortaba en seco contra la casilla de al lado, que es lo que
## mas delata que el mapa se acaba ahi: un rio que se acaba en una raya recta
## no existe en ninguna parte.
##
## Es la misma llamada que se hace para el recuadro jugable, sobre el bloque
## de 3x3. Si Overpass no responde, el contorno se queda seco y ya esta: es un
## fallo feo pero no rompe nada.
func _apply_surround_water(surround: HeightmapData) -> void:
	var hidro := OSMWays.new().fetch_water(
		surround.lat_north, surround.lat_south,
		surround.lon_west, surround.lon_east)
	var canales: Array = hidro.get("channels", [])
	var laminas: Array = hidro.get("bodies", [])

	if canales.is_empty() and laminas.is_empty():
		print("PreparaValle: sin hidrografia para el contorno, se queda seco")
		return

	Hydrography.apply(surround, canales, laminas)
	print("PreparaValle: %d cauces y %d laminas en el contorno"
		% [canales.size(), laminas.size()])
