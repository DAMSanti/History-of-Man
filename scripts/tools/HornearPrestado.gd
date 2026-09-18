extends SceneTree
## Hornea la SÁBANA DE DETALLE: un trozo de tierra real a 5 m del que prestar el relieve
## fino a los valles que se levantan sin MDT. GRAFICOS §3, depurar del 2026-09-17.
##
## Por qué hace falta: el valle de un abrigo de la costa de la época no se puede descargar
## —hoy eso es mar y no hay LiDAR debajo—, así que se levanta con la batimetría regional,
## que a 111 m por muestra no tiene nada más fino que una loma. Ese detalle estaba puesto
## con ruido, y el usuario pidió que no se invente («busca orografía que cuadre con esos
## mapas, aunque sea de otro lugar»). De aquí sale el «otro lugar»: tierra de Cantabria, a
## la misma resolución a la que se juega.
##
## De dónde sale: de un valle real YA DESCARGADO en `data/dem/local`, que es MDT05 del IGN
## igual que lo sería una descarga nueva. Se guarda en `data/sites`, que sí va al
## repositorio —`data/dem` está en el .gitignore—, y a partir de ahí el juego no descarga
## nada para esto.
##
## Se corre UNA VEZ:
##
##     godot --headless --path . --script res://scripts/tools/HornearPrestado.gd

## De dónde se presta, por orden de preferencia: valles de interior, que traen laderas,
## vaguadas y lomos sin la forma grande del mar.
const CANDIDATOS := [14, 16, 33, 56, 1, 0]

## Lado del trozo que se guarda, en muestras. 512 a 5 m son 2,5 km: de sobra para sacar
## trozos de 640 m sin que se repita el mismo en dos sitios seguidos.
const LADO := 512

const CARPETA := "res://data/dem/local"
const DESTINO := "res://data/sites/detalle_de_tierra.res"


func _init() -> void:
	for id: int in CANDIDATOS:
		var ruta := "%s/site_%d.res" % [CARPETA, id]
		if not ResourceLoader.exists(ruta):
			continue
		var valle: HeightmapData = load(ruta)
		if valle == null or valle.width < LADO or valle.height < LADO:
			continue
		var trozo := _recortar(valle)
		if trozo == null:
			print("HornearPrestado: el sitio %d tiene mar o vega a cota cero, se prueba otro" % id)
			continue
		trozo.source = "MDT05 del IGN, del valle del sitio %d (%.4f, %.4f)" % [
			id, (valle.lat_north + valle.lat_south) * 0.5,
			(valle.lon_west + valle.lon_east) * 0.5]
		var error := ResourceSaver.save(trozo, DESTINO)
		print("HornearPrestado: %d x %d a %.1f m, cotas %.0f..%.0f · %s · guardado en %s (%d)" % [
			trozo.width, trozo.height, trozo.meters_per_sample,
			trozo.min_elevation, trozo.max_elevation, trozo.source, DESTINO, error])
		quit(0)
		return
	print("HornearPrestado: ningún valle descargado sirve; hace falta uno de interior")
	quit(1)


## El centro del valle, [LADO] x [LADO], si todo él es tierra.
func _recortar(valle: HeightmapData) -> HeightmapData:
	@warning_ignore("integer_division")
	var x0 := (valle.width - LADO) / 2
	@warning_ignore("integer_division")
	var z0 := (valle.height - LADO) / 2
	var cotas := PackedFloat32Array()
	cotas.resize(LADO * LADO)
	var lo := INF
	var hi := -INF
	for z in range(LADO):
		for x in range(LADO):
			var e := valle.elevations[(z0 + z) * valle.width + x0 + x]
			# Cota cero exacta es el mar del LiDAR: ese trozo no vale para prestar.
			if e <= 0.5:
				return null
			cotas[z * LADO + x] = e
			lo = minf(lo, e)
			hi = maxf(hi, e)
	var trozo := HeightmapData.new()
	trozo.width = LADO
	trozo.height = LADO
	trozo.meters_per_sample = valle.meters_per_sample
	trozo.elevations = cotas
	trozo.min_elevation = lo
	trozo.max_elevation = hi
	return trozo
