extends SceneTree
## ¿SON DE VERDAD LOS RÍOS QUE PINTAMOS? Auditoría de la hidrografía, pedida por el usuario
## el 2026-09-17: «comprueba que todos los ríos que hayas metido, tanto en mapa regional
## como en el mapa detalle, sean fieles a la realidad; que no hayas convertido carreteras
## en ríos».
##
## Mira tres cosas, y ninguna necesita red:
##
## 1. **El mapa regional**: qué clase de `waterway` trae cada cauce horneado, con qué
##    nombre y cuántos kilómetros. Lo que sale de OSM debería ser `river` y nada más.
## 2. **Lo inventado, dicho aparte**: los tramos que bajan por la plataforma no son dato de
##    OSM sino deducción sobre el relieve, y aquí se cuentan por separado.
## 3. **Los valles guardados**: la misma cuenta con el agua de OSM que llevan dentro, y
##    cuántos de esos cauces se alargaron por el relleno del mar de hoy.
##
##   godot --headless --path . --script res://scripts/tools/AuditarRios.gd

const CARPETAS := ["res://data/dem/local", "user://sondas/relleno"]

## Con qué mar se mide un valle que aún no esté rellenado.
const MAR_DE_LA_EPOCA := -120.0

## Lo que la tabla de [OSMWays] considera agua natural con cauce. Cualquier otra clase que
## aparezca en el dato es sospechosa y se dice.
const NATURALES := ["river", "stream", "tidal_channel", "brook"]


func _init() -> void:
	_el_mapa_regional()
	for carpeta: String in CARPETAS:
		_los_valles(carpeta)
	quit()


func _el_mapa_regional() -> void:
	var rios := RiosDeLaRegion.cargar()
	print("=== MAPA REGIONAL ===")
	_contar("de OSM (ríos de hoy)", rios.de_hoy)
	print("   prolongados por la plataforma (DEDUCIDOS del relieve, no son dato de OSM): "
		+ "%d tramos, %.0f km" % [rios.de_la_plataforma.size(),
		_kilometros(rios.de_la_plataforma)])
	var con_nombre: Dictionary = {}
	for cauce: Dictionary in rios.de_hoy:
		var nombre := str(cauce.get("name", ""))
		if nombre.is_empty():
			continue
		con_nombre[nombre] = float(con_nombre.get(nombre, 0.0)) + _kilometros([cauce])
	var nombres: Array = con_nombre.keys()
	nombres.sort_custom(func(a: String, b: String) -> bool:
		return float(con_nombre[a]) > float(con_nombre[b]))
	print("   los quince cauces con más kilómetros, por nombre:")
	for k in range(mini(15, nombres.size())):
		print("      %-34s %.0f km" % [nombres[k], con_nombre[nombres[k]]])
	var sin_nombre := 0
	for cauce: Dictionary in rios.de_hoy:
		if str(cauce.get("name", "")).is_empty():
			sin_nombre += 1
	print("   tramos sin nombre en OSM: %d de %d" % [sin_nombre, rios.de_hoy.size()])


func _los_valles(carpeta: String) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	print("=== VALLES en %s ===" % carpeta)
	for fichero: String in dir.get_files():
		if not fichero.begins_with("site_") or fichero.contains("mesh") \
				or not fichero.ends_with(".res"):
			continue
		var valle: HeightmapData = load(carpeta + "/" + fichero)
		if valle == null or valle.agua_de_osm.is_empty():
			continue
		var canales: Array = valle.agua_de_osm.get("channels", [])
		var laminas: Array = valle.agua_de_osm.get("bodies", [])
		print("   %s · %d cauces (%.1f km) y %d láminas de OSM" % [fichero, canales.size(),
			_kilometros(canales), laminas.size()])
		_clases("      ", canales)
		var del_mar := 0
		for v in valle.mar_de_hoy:
			del_mar += v
		# SIN ESCRIBIR NADA: si el valle guardado no está rellenado para la época, se
		# rellena aquí en memoria para poder medirlo. Auditar no toca los datos del jugador.
		if del_mar > 0 and valle.relleno_mar >= 0.0 and not canales.is_empty():
			RellenoDelMarDeHoy.poner_al_dia(valle, load(PreparaValle.RELIEVE_REGIONAL),
				MAR_DE_LA_EPOCA, RiosDeLaRegion.cargar())
			print("      (rellenado en memoria para medir, a %.0f m)" % MAR_DE_LA_EPOCA)
		if del_mar > 0 and valle.relleno_mar < 0.0:
			var alargados := RellenoDelMarDeHoy.alargar_los_rios(valle, canales,
				valle.mar_de_hoy, valle.relleno_mar)
			var cuantos := 0
			var metros := 0.0
			var sube_peor := 0.0
			for i in range(canales.size()):
				var antes: PackedVector2Array = canales[i].get("points", PackedVector2Array())
				var ahora: PackedVector2Array = alargados[i].get("points", PackedVector2Array())
				if ahora.size() <= antes.size():
					continue
				cuantos += 1
				var largo := (_kilometros([alargados[i]]) - _kilometros([canales[i]])) * 1000.0
				metros += largo
				# UN RÍO NO SUBE: cuánto remonta el tramo nuevo, de punta a punta.
				var sube := _lo_que_sube(valle, ahora, antes.size(), valle.relleno_mar)
				sube_peor = maxf(sube_peor, sube)
				print("      alargado: %-26s (%-6s) %+6.0f m · remonta %.1f m" % [
					str(canales[i].get("name", "sin nombre")),
					str(canales[i].get("kind", "?")), largo, sube])
			print("      %d cauces siguen por el relleno, %.0f m en total · el que más "
				% [cuantos, metros] + "remonta sube %.1f m" % sube_peor)


## Cuánto REMONTA el tramo nuevo de un cauce: la suma de las subidas siguiendo sus puntos
## desde donde empieza lo añadido. Un río de verdad no sube nunca.
func _lo_que_sube(valle: HeightmapData, puntos: PackedVector2Array, desde: int,
		mar: float) -> float:
	var sube := 0.0
	var anterior := INF
	for i in range(maxi(desde - 1, 0), puntos.size()):
		var u := valle.u_for_lon(puntos[i].x)
		var v := valle.v_for_lat(puntos[i].y)
		var e := valle.sample_bilinear(clampf(u, 0.0, 1.0), clampf(v, 0.0, 1.0))
		# Bajo el mar ya no es río sino estuario: el agua está a una cota y el fondo hace lo
		# que quiera. Sólo se mira el tramo que corre al aire.
		if e <= mar + 1.0:
			break
		if anterior != INF and e > anterior:
			sube += e - anterior
		anterior = e
	return sube


## Cuántos cauces hay de cada clase de `waterway`, y aviso de lo que no es agua natural.
func _clases(sangria: String, canales: Array) -> void:
	var por_clase: Dictionary = {}
	for cauce: Dictionary in canales:
		var kind := str(cauce.get("kind", "?"))
		por_clase[kind] = int(por_clase.get(kind, 0)) + 1
	var linea := ""
	var raros := ""
	for kind: String in por_clase:
		linea += "%s %d · " % [kind, por_clase[kind]]
		if not NATURALES.has(kind):
			raros += "%s (%d) " % [kind, por_clase[kind]]
	print(sangria + "clases: " + linea)
	if not raros.is_empty():
		print(sangria + "OJO, clases que NO son agua natural con cauce: " + raros)


func _contar(que: String, canales: Array) -> void:
	print("   %s: %d tramos, %.0f km" % [que, canales.size(), _kilometros(canales)])
	_clases("   ", canales)


## Kilómetros de una lista de cauces, sobre el elipsoide a la latitud de Cantabria.
func _kilometros(canales: Array) -> float:
	var metros := 0.0
	for cauce: Dictionary in canales:
		var puntos: PackedVector2Array = cauce.get("points", PackedVector2Array())
		for i in range(puntos.size() - 1):
			var a := puntos[i]
			var b := puntos[i + 1]
			var dx := (b.x - a.x) * 111320.0 * cos(deg_to_rad((a.y + b.y) * 0.5))
			var dz := (b.y - a.y) * 111320.0
			metros += sqrt(dx * dx + dz * dz)
	return metros / 1000.0
