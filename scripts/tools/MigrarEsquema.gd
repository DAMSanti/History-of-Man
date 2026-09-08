extends SceneTree
## Mueve de carpeta las clases que van DENTRO de los ficheros guardados.
##
## Un `.res` binario lleva escrita la ruta del script de cada objeto que
## contiene. Mover el script rompe el fichero -«Attempt to open script ...
## resulted in error 'File not found'»- y la ruta no se puede parchear a mano:
## va con su longitud delante y detras hay una tabla de desplazamientos.
##
## La via buena es `take_over_path`: se carga el script desde donde esta, se le
## dice cual va a ser su sitio, y al volver a guardar el recurso se escribe la
## ruta nueva. Despues se mueve el fichero de verdad.
##
## Se corre UNA vez, antes de mover los .gd:
##   godot --headless --path . --script res://scripts/tools/MigrarEsquema.gd

const DESTINO := "res://scripts/datos/%s.gd"

const CLASES := ["PropLibrary", "TerrainTextureArrays"]


func _init() -> void:
	# EL ORDEN IMPORTA Y ES LA TRAMPA DE TODO ESTO. Hay que cargar PRIMERO
	# todos los recursos y renombrar DESPUES: `take_over_path` le quita al
	# script su ruta vieja, asi que un recurso cargado despues ya no encuentra
	# «res://scripts/Site.gd», se carga como un Resource pelado sin una sola
	# propiedad, y al guardarlo se escribe ese vacio encima del bueno.
	#
	# Hecho al reves cost dieciseis ficheros: 667 MB de relieve convertidos en
	# ficheros de 330 bytes. Por eso ademas se comprueba el tamaño antes y
	# despues, y no se guarda nada que haya encogido.
	var rutas := _recursos()
	var cargados: Array[Resource] = []
	var tamanos: Array[int] = []
	for ruta: String in rutas:
		var res: Resource = ResourceLoader.load(ruta, "",
			ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			print("  NO CARGA %s" % ruta)
			cargados.append(null)
			tamanos.append(0)
			continue
		cargados.append(res)
		tamanos.append(_bytes(ruta))

	# Ahora si: los scripts se mudan.
	for nombre: String in CLASES:
		var script: Script = load("res://scripts/%s.gd" % nombre)
		if script == null:
			print("  no esta: res://scripts/%s.gd" % nombre)
			continue
		script.take_over_path(DESTINO % nombre)

	var hechos := 0
	for i in range(rutas.size()):
		if cargados[i] == null:
			continue
		var ruta: String = rutas[i]
		var error := ResourceSaver.save(cargados[i], ruta)
		if error != OK:
			print("  NO GUARDA %s (error %d)" % [ruta, error])
			continue
		var ahora := _bytes(ruta)
		if ahora < tamanos[i] / 2:
			print("  ENCOGIO %s: %d -> %d bytes. ALGO VA MAL." % [
				ruta, tamanos[i], ahora])
			continue
		hechos += 1
		print("  migrado %s (%d -> %d bytes)" % [ruta, tamanos[i], ahora])
	print("recursos migrados: %d de %d" % [hechos, rutas.size()])
	quit()


func _bytes(ruta: String) -> int:
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return int(n)


## Todos los .res del proyecto, que son los que llevan esquema dentro.
func _recursos() -> Array[String]:
	var out: Array[String] = []
	_barrer("res://textures", out)
	_barrer("res://models", out)
	return out


func _barrer(carpeta: String, out: Array[String]) -> void:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return
	dir.list_dir_begin()
	var nombre := dir.get_next()
	while nombre != "":
		var ruta := carpeta.path_join(nombre)
		if dir.current_is_dir():
			_barrer(ruta, out)
		elif nombre.ends_with(".res"):
			out.append(ruta)
		nombre = dir.get_next()
	dir.list_dir_end()
