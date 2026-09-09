extends SceneTree
## Deja los iconos de materiales y utensilios sin borde claro.
##
## Son TRES cosas distintas que se ven igual —un recuadro claro alrededor de la
## estampa sobre la piel oscura del almacén— y hubo que arreglar las tres:
##
##   EL FONDO    un marco blanco opaco alrededor de la imagen
##   EL MARCO    un marco de piedra clara pintado DENTRO, en siete de ellas
##   EL ALIAS    y, la que de verdad se veía en el juego, que un PNG de 512
##               pintado a 24 píxeles SIN MIPMAPS no se reduce: se muestrea a
##               saltos, y el filo claro del borde sale como una raya moteada
##
## ## Por qué es una herramienta y no un arreglo
##
## Porque ya se arregló una vez —a mano, desde fuera del proyecto— y volvió a
## aparecer en cuanto se añadieron iconos nuevos y se repusieron los viejos. Un
## arreglo que no está en el repositorio no es un arreglo: es una limpieza que
## alguien tiene que acordarse de repetir. Esto se vuelve a pasar cada vez que
## entren imágenes nuevas y no toca lo que ya está limpio.
##
##     godot --headless --path . --script res://scripts/tools/SinBordeBlanco.gd
##
## ## Cómo lo hace
##
## **Inundando desde el marco**, no borrando todo lo blanco. Es la diferencia
## que importa: un huevo es blanco por dentro y tiene que seguir siéndolo, igual
## que la nieve de una estampa o el filo de un sílex. Sólo se va el blanco que
## se toca con el borde de la imagen.
##
## Y después se apura el filo: al inundar queda un anillo de antialias muy claro
## a medio alfa que a tamaño de icono se lee como una raya blanca.
##
## Lo del alias no se arregla tocando la imagen —a 24 píxeles reducida bien no
## tiene borde ninguno— sino diciéndole al importador que genere mipmaps. Va
## aquí y no a mano porque los `.import` nacen sin ellos: cada icono nuevo
## volvería a traer la raya.

## A partir de qué claridad se considera fondo, de 0 a 255.
const ES_FONDO := 225

## Y a partir de cuál se apura el filo pegado al hueco.
##
## Más bajo que [ES_FONDO] a propósito: lo que hay entre las dos cifras es el
## antialias del marco, que ni es fondo del todo ni es estampa.
const ES_FILO := 190

## Cuántas vueltas se le dan al filo. Dos bastan: el antialias de estas
## imágenes tiene un par de píxeles de ancho.
const VUELTAS_DE_FILO := 2

const CARPETA := "res://textures/items"

## Donde se apunta a quién se le ha quitado ya el marco.
const YA_RECORTADOS := "res://textures/items/recortados.txt"

## El hueco que ha abierto la inundacion en la imagen que se esta mirando.
##
## El apurado del filo se ata a ESTE hueco y no a cualquier transparencia, y no
## es un detalle: atado a la transparencia a secas, cada pasada quitaba un
## anillo, el anillo dejaba transparencia nueva y la siguiente pasada quitaba
## otro. El tendon perdia treinta y cinco pixeles cada vez que se pasaba la
## herramienta, sin parar nunca. El filo del marco esta pegado a LO QUE SE
## ACABA DE BORRAR; lo demas es estampa.
var _hueco: PackedByteArray = PackedByteArray()


func _init() -> void:
	var tocados := 0
	var mirados := 0
	var con_mipmaps := 0
	var hechos := _ya_recortados()
	for nombre: String in _iconos():
		mirados += 1
		if _con_mipmaps(nombre):
			con_mipmaps += 1
		var ruta := CARPETA + "/" + nombre
		var imagen := Image.load_from_file(ProjectSettings.globalize_path(ruta))
		if imagen == null:
			print("no se pudo abrir %s" % nombre)
			continue
		imagen.convert(Image.FORMAT_RGBA8)
		var borrados := _quitar_el_fondo(imagen)
		var marco := 0
		if CON_MARCO.has(nombre) and not hechos.has(nombre):
			marco = _quitar_el_marco(imagen)
			if marco > 0:
				_apuntar_recortado(nombre)
				hechos.append(nombre)
		# El filo SOLO si la inundacion ha quitado algo: es el antialias del
		# marco blanco, y sin marco blanco no hay antialias que apurar. Sin esta
		# condicion, cada pasada mordia un anillo de la estampa clara pegada al
		# margen -el tendon perdia veinte pixeles cada vez- y no paraba nunca.
		var apurados := _apurar_el_filo(imagen) if borrados > 0 else 0
		if borrados + marco + apurados <= 0:
			continue
		tocados += 1
		imagen.save_png(ProjectSettings.globalize_path(ruta))
		print("%-28s %7d de fondo · %6d de marco · %5d de filo" % [
			nombre, borrados, marco, apurados])

	print("")
	print("%d iconos mirados, %d limpiados, %d puestos a generar mipmaps"
		% [mirados, tocados, con_mipmaps])
	if con_mipmaps > 0:
		print("hay que reimportar: godot --headless --path . --import")
	quit()


## Los que ya llevan el marco quitado, para no quitarlo dos veces.
func _ya_recortados() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(YA_RECORTADOS):
		return out
	for linea: String in FileAccess.get_file_as_string(
			YA_RECORTADOS).split("
"):
		var limpia := linea.strip_edges()
		if not limpia.is_empty() and not limpia.begins_with("#"):
			out.append(limpia)
	return out


## Apunta que a este icono ya se le ha quitado el marco.
func _apuntar_recortado(nombre: String) -> void:
	var archivo := FileAccess.open(YA_RECORTADOS, FileAccess.READ_WRITE)
	if archivo == null:
		return
	archivo.seek_end()
	archivo.store_string(nombre + "
")
	archivo.close()


## Se asegura de que el icono se importe CON MIPMAPS. Devuelve si hizo falta.
##
## Es lo que de verdad se veía en el juego. Un PNG de 512 pintado en un cuadro
## de veinticuatro píxeles sin mipmaps no se reduce: la tarjeta coge un punto
## de cada veintiuno, y el filo claro del borde de la estampa sale como una raya
## moteada alrededor del icono. Con mipmaps se reduce promediando y el borde
## desaparece —además de que la estampa se ve entera en vez de a manchas.
##
## Los `.import` se generan con `mipmaps/generate=false`, así que esto hay que
## volver a pasarlo cada vez que entren iconos nuevos.
func _con_mipmaps(nombre: String) -> bool:
	var ruta := ProjectSettings.globalize_path(
		CARPETA + "/" + nombre + ".import")
	if not FileAccess.file_exists(ruta):
		return false
	var texto := FileAccess.get_file_as_string(ruta)
	if not texto.contains("mipmaps/generate=false"):
		return false
	texto = texto.replace("mipmaps/generate=false", "mipmaps/generate=true")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(texto)
	archivo.close()
	return true


func _iconos() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(CARPETA)
	if dir == null:
		return out
	for nombre: String in dir.get_files():
		if nombre.ends_with(".png"):
			out.append(nombre)
	out.sort()
	return out


## Los iconos que traen un MARCO DE PIEDRA pintado alrededor de la losa.
##
## Va por lista y no por deteccion, y no es pereza: lo probé de tres maneras y
## ninguna separa «marco decorativo» de «estampa clara pegada al borde». Con
## umbral de brillo absoluto no vale —el marco es gris como la propia losa—; con
## brillo relativo al interior, la miel y el fruto seco entran también; y con el
## peor de los cuatro lados, la cecina (0,46) y la miel (0,39) se solapan. Cada
## intento se comió iconos que estaban bien.
##
## Estas siete imágenes vinieron generadas con el marco dentro y el resto no.
## Es un dato del material, no una propiedad que se pueda deducir mirando
## píxeles, así que se escribe: si entra otra con marco, se añade aquí.
##
## Y como tampoco se puede deducir si YA está recortada, se apunta en
## [YA_RECORTADOS] al recortarla. Sin eso, pasar la herramienta dos veces
## recortaba dos veces y la estampa se iba acercando a saltos.
const CON_MARCO := [
	"materia_agua.png",
	"materia_caracol.png",
	"materia_carne_seca.png",
	"materia_huevo.png",
	"materia_pescado.png",
	"materia_resina.png",
	"materia_seta.png",
]

## Cuanto se recorta por cada lado, en partes del lado.
##
## Un noveno. Medidos uno a uno, los marcos de estas siete imagenes ocupan entre
## once y veinticuatro pixeles de los quinientos doce, contando el margen
## transparente que llevan por fuera; cuarenta y seis los cubre todos con
## holgura y sin llegar a la estampa.
##
## Fijo y no medido por imagen a proposito. Lo probé midiendo el perfil de
## brillo de cada lado y se quedaba corto justo donde el marco tiene bisel
## -franja clara, franja oscura, franja clara- porque la primera franja oscura
## lo daba por terminado: el agua y la seta se quedaban con su marco puesto. Una
## fraccion fija los quita todos, y lo que se pierde es un noveno de losa, que en
## una estampa fotografica no se ve.
const RECORTE := 1.0 / 9.0


## Recorta el marco de piedra y estira la losa hasta llenar el cuadro.
##
## Lo que queda —la losa sola, llenando el icono— es como estan los que no traen
## marco.
func _quitar_el_marco(imagen: Image) -> int:
	var w := imagen.get_width()
	var h := imagen.get_height()
	var quitar_x := int(float(w) * RECORTE)
	var quitar_y := int(float(h) * RECORTE)
	if quitar_x <= 0 or quitar_y <= 0:
		return 0

	var dentro := imagen.get_region(Rect2i(quitar_x, quitar_y,
		w - quitar_x * 2, h - quitar_y * 2))
	dentro.resize(w, h, Image.INTERPOLATE_LANCZOS)
	imagen.copy_from(dentro)
	return (quitar_x + quitar_y) * 2


## Si este color es fondo: transparente ya, o lo bastante claro.
static func _es_fondo(color: Color) -> bool:
	if color.a < 0.08:
		return true
	return minf(minf(color.r, color.g), color.b) * 255.0 >= float(ES_FONDO)


## Borra el fondo blanco que TOCA EL MARCO. Devuelve cuántos píxeles se fueron.
func _quitar_el_fondo(imagen: Image) -> int:
	var w := imagen.get_width()
	var h := imagen.get_height()
	var visto := PackedByteArray()
	visto.resize(w * h)
	_hueco = visto

	var cola: Array[int] = []
	for x in range(w):
		cola.append(x)
		cola.append((h - 1) * w + x)
	for y in range(h):
		cola.append(y * w)
		cola.append(y * w + w - 1)

	var borrados := 0
	while not cola.is_empty():
		var i: int = cola.pop_back()
		if i < 0 or i >= w * h or visto[i] != 0:
			continue
		@warning_ignore("integer_division")
		var y := i / w
		var x := i % w
		var color := imagen.get_pixel(x, y)
		if not _es_fondo(color):
			continue
		visto[i] = 1
		_hueco[i] = 1
		if color.a > 0.0:
			borrados += 1
			imagen.set_pixel(x, y, Color(color.r, color.g, color.b, 0.0))
		if x > 0:
			cola.append(i - 1)
		if x < w - 1:
			cola.append(i + 1)
		if y > 0:
			cola.append(i - w)
		if y < h - 1:
			cola.append(i + w)
	return borrados


## Apura el anillo de antialias que deja el marco al irse.
func _apurar_el_filo(imagen: Image) -> int:
	var w := imagen.get_width()
	var h := imagen.get_height()
	var apurados := 0
	for _vuelta in range(VUELTAS_DE_FILO):
		var fuera: Array[Vector2i] = []
		for y in range(h):
			for x in range(w):
				var color := imagen.get_pixel(x, y)
				if color.a < 0.08:
					continue
				if minf(minf(color.r, color.g), color.b) * 255.0 < float(ES_FILO):
					continue
				# Pegado al hueco -o al borde de la imagen- y casi blanco: es
				# el filo del marco, no la estampa.
				for paso: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + paso.x
					var ny := y + paso.y
					if nx >= 0 and ny >= 0 and nx < w and ny < h 							and _hueco.size() == w * h 							and _hueco[ny * w + nx] != 0:
						fuera.append(Vector2i(x, y))
						break
					# Pegado a un HUECO DE VERDAD, no al canto de la imagen.
					#
					# Contando el canto como hueco, una estampa que llega al
					# borde -el tendon, la cuerda- se roia un pelo en cada
					# pasada y no paraba nunca: treinta y cinco pixeles cada
					# vez. El filo del marco esta pegado a lo transparente; el
					# canto de la imagen no es filo de nada.

		for punto: Vector2i in fuera:
			var color := imagen.get_pixel(punto.x, punto.y)
			imagen.set_pixel(punto.x, punto.y,
				Color(color.r, color.g, color.b, 0.0))
		apurados += fuera.size()
	return apurados
