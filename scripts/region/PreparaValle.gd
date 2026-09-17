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
const VERSION := 10

## DONDE VIVEN LOS VALLES PREPARADOS, con sus contornos.
##
## La del juego, y otra en las pruebas, por lo mismo que `Guardado.carpeta` y
## `Configuracion.ruta`: **una prueba no toca nunca los datos del jugador**, y aqui lo
## que hay son ficheros de veinte megas que cuesta minutos de red volver a hacer.
const CARPETA := "res://data/dem/local"
var carpeta_de_los_valles: String = CARPETA


## El fichero del recuadro jugable de un sitio, y el de su contorno.
func ruta_del_valle(id: int) -> String:
	return "%s/site_%d.res" % [carpeta_de_los_valles, id]


func ruta_del_contorno(id: int) -> String:
	return "%s/site_%d_surround.res" % [carpeta_de_los_valles, id]


## DE DONDE SALE EL RELIEVE DEL CONTORNO, y de donde el agua.
##
## Son los dos unicos sitios donde rehacer el contorno toca la red, y estan aqui con
## nombre para poder comprobarlo SIN ELLA: la spec pide que el contorno rehecho salga
## igual byte a byte con datos guardados (INTERFAZ §12), y eso no se puede comprobar si
## la receta llama al IGN y a Overpass por su cuenta. La prueba les pone datos de bote;
## el juego no se entera.
##
## `trae_el_relieve(norte, sur, oeste, este, metros) -> HeightmapData` (o null si falla)
## `trae_el_agua(norte, sur, oeste, este) -> Dictionary` con `channels` y `bodies`.
var trae_el_relieve: Callable = func(norte: float, sur: float, oeste: float, este: float,
		metros: float) -> HeightmapData:
	return IGNImporter.new().import_area(norte, sur, oeste, este, metros)

var trae_el_agua: Callable = func(norte: float, sur: float, oeste: float,
		este: float) -> Dictionary:
	return OSMWays.new().fetch_water(norte, sur, oeste, este)


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

## De donde sale la cota de la plataforma para los valles inventados (EPOCA_01 §10.2).
const RELIEVE_REGIONAL := "res://data/dem/cantabria_region.res"


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
	var cache_path := ruta_del_valle(sitio.id)
	if ResourceLoader.exists(cache_path):
		var cached: HeightmapData = load(cache_path)
		if cached != null and cached.pipeline_version == VERSION:
			print("PreparaValle: recuadro local leido de %s" % cache_path)
			# El contorno tiene su propia resolucion y su propia vida: si se
			# ha quedado mas basto de lo que ahora se pide, se rehace SOLO el.
			# Subir el sello del recuadro para esto obligaria a volver a
			# descargar el mapa jugable entero, que no ha cambiado en nada.
			await _poner_al_dia_el_contorno(arbol, sitio, cached, al_cuadro)
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
	# UN SITIO DE LA COSTA DE LA EPOCA NO SE DESCARGA: no hay MDT bajo el mar de hoy, asi
	# que su valle se inventa con el mismo relieve que se ve en el mapa regional
	# (EPOCA_01 §10.2). Sin red, y siempre igual.
	if sitio.fidelity == Site.Fidelity.HIPOTETICO:
		return _valle_inventado(sitio, cache_path)

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

	var surround_path := ruta_del_contorno(sitio.id)
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
		ProjectSettings.globalize_path(carpeta_de_los_valles))
	ResourceSaver.save(local, cache_path)
	print("PreparaValle: recuadro local bakeado en %s" % cache_path)
	return local


## El valle de un abrigo de la costa, inventado. Ver [ValleDeLaPlataforma].
##
## Va en el mismo hilo que el resto: son cuentas, sin nodos y sin red. Guarda tambien su
## contorno, mas basto, porque un valle sin contorno se dibuja con el relieve regional a
## 111 m y se veria el corte.
func _valle_inventado(sitio: Site, cache_path: String) -> HeightmapData:
	_avisar("Levantando el valle de %s...\n(costa de la epoca, sin descarga)"
		% sitio.display_name(), 0)
	var regional: HeightmapData = load(RELIEVE_REGIONAL)
	if regional == null:
		_avisar("No esta el relieve regional.", -1)
		return null
	var rios := RiosDeLaRegion.cargar()
	var mar := Expedition.sea_level_m
	var t0 := Time.get_ticks_msec()
	var local := ValleDeLaPlataforma.generar(sitio, rios, regional, mar,
		float(Expedition.local_size_m) * 1.1, 5.0)
	if local == null:
		_avisar("No se pudo levantar el valle.", -1)
		return null
	print("ValleDeLaPlataforma: %d x %d a %.0f m en %d ms" % [local.width, local.height,
		local.meters_per_sample, Time.get_ticks_msec() - t0])

	_avisar("Levantando lo de alrededor...", 4)
	var surround := ValleDeLaPlataforma.generar(sitio, rios, regional, mar,
		float(Expedition.local_size_m) * 3.3, surround_meters * 2.0)
	if surround != null:
		surround.pipeline_version = VERSION
		ResourceSaver.save(surround, ruta_del_contorno(sitio.id))

	_avisar("Guardando el valle...", 5)
	local.pipeline_version = VERSION
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(carpeta_de_los_valles))
	ResourceSaver.save(local, cache_path)
	return local


## Pone al dia el contorno sin congelar la ventana. INTERFAZ §12.
##
## **La espera va aqui y el trabajo en un hilo**, igual que preparar un valle nuevo: lo
## que se hace son decenas de segundos de red -43 s el MDT del IGN, medidos- y hasta hoy
## se hacian en el hilo principal con dos cuadros de cortesia delante. La ventana se
## quedaba parada con un cartel de «esto tarda» encima.
##
## Todo va dentro del hilo, incluida la comprobacion de si hace falta: mirar el contorno
## es leer un recurso de disco, y leerlo en el principal seria justo el tiron que se viene
## a quitar. Si no hay nada que hacer, el hilo termina en el primer cuadro.
func _poner_al_dia_el_contorno(arbol: SceneTree, sitio: Site, local: HeightmapData,
		al_cuadro: Callable = Callable()) -> void:
	if local == null:
		return
	var hilo := Thread.new()
	hilo.start(_rehacer_el_contorno.bind(sitio, local))
	while hilo.is_alive():
		_publicar()
		if al_cuadro.is_valid():
			al_cuadro.call()
		await arbol.process_frame
	hilo.wait_to_finish()
	_publicar()


## La receta del contorno: mirar si hace falta, bajarlo, pintarle el agua y guardarlo.
##
## **Ni un nodo ni una señal**: corre en el hilo de [_poner_al_dia_el_contorno] y lo que
## va diciendo lo deja en el buzon de [_avisar] (invariante 9 de SPECS §7). Devuelve si
## ha tocado algo, que es lo que mira la prueba.
##
## Son DOS cosas independientes y con precios muy distintos. Rehacer el MDT es una
## descarga larga; traer la hidrografia de OSM es corta. Si se comprueban juntas, un
## contorno que solo le falta el agua paga la descarga entera del relieve para nada, y
## peor: si el IGN falla, se queda tambien sin rios.
func _rehacer_el_contorno(sitio: Site, local: HeightmapData) -> bool:
	if local == null:
		return false
	var path := ruta_del_contorno(sitio.id)
	if not ResourceLoader.exists(path):
		return false

	var surround: HeightmapData = load(path)
	if surround == null:
		return false

	# Con un 10% de margen: no merece la pena una descarga de minutos por una
	# diferencia de decimales
	var coarse := surround.meters_per_sample > surround_meters * 1.1
	var dry := surround.river_mask.is_empty()
	if not coarse and not dry:
		return false

	var no_respondio := false
	if coarse and use_ign_elevation:
		# La etapa 4 de [ETAPAS] es «Descargando el relieve de alrededor», que es esto;
		# el agua de abajo va en la misma para que la barra no vaya hacia atras.
		_avisar("Mejorando el relieve de alrededor...\n"
			+ "MDT del IGN a %.0f m para 12 km de lado: esto tarda." % surround_meters, 4)
		var span_lat := local.lat_north - local.lat_south
		var span_lon := local.lon_east - local.lon_west
		var started := Time.get_ticks_msec()
		var finer: HeightmapData = trae_el_relieve.call(
			local.lat_north + span_lat, local.lat_south - span_lat,
			local.lon_west - span_lon, local.lon_east + span_lon, surround_meters)

		if finer != null:
			surround = finer
			dry = true  # el MDT nuevo viene seco: hay que volver a pintarle el agua
			print("PreparaValle: contorno rehecho en %d ms, %d x %d a %.1f m" % [
				Time.get_ticks_msec() - started, surround.width, surround.height,
				surround.meters_per_sample])
		else:
			# Y LA PARTIDA SIGUE. Se dice y se sigue con el contorno que hubiera: es feo
			# pero no rompe nada. **Se reintenta la proxima vez que se entre al valle**
			# -sigue basto, asi que la condicion de arriba vuelve a dar verdad-, decision
			# del usuario del 2026-09-17: si la red va mal hoy y bien mañana, el contorno
			# mejora solo.
			#
			# NO SE AVISA AQUI Y YA: el buzon guarda UN texto y lo publica el hilo
			# principal cuando puede, asi que un aviso seguido de otro se pisa. El paso
			# siguiente tarda milisegundos, o sea que este cartel se veria durante un
			# cuadro y el jugador no leeria nada. Se guarda y se dice AL FINAL, que es
			# donde la barra se queda parada un momento.
			no_respondio = true
			print("PreparaValle: el IGN no ha respondido, se queda el relieve que habia")

	if dry:
		_avisar("Trazando los rios de alrededor...", 4)
		_apply_surround_water(surround)

	var final := "Guardando el relieve de alrededor..."
	if no_respondio:
		final += "\n(El IGN no ha respondido: se queda el que había.)"
	_avisar(final, 5)
	surround.pipeline_version = VERSION
	ResourceSaver.save(surround, path)
	return true


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
	var hidro: Dictionary = trae_el_agua.call(
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
