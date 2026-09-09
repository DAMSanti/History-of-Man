extends SceneTree
## Quita el fondo blanco de los iconos de materiales y utensilios.
##
## Los iconos vienen con un marco blanco opaco alrededor de la estampa, y en la
## interfaz eso se ve como un recuadro claro sobre la piel oscura del almacén.
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


func _init() -> void:
	var tocados := 0
	var mirados := 0
	for nombre: String in _iconos():
		mirados += 1
		var ruta := CARPETA + "/" + nombre
		var imagen := Image.load_from_file(ProjectSettings.globalize_path(ruta))
		if imagen == null:
			print("no se pudo abrir %s" % nombre)
			continue
		imagen.convert(Image.FORMAT_RGBA8)
		var borrados := _quitar_el_fondo(imagen)
		var marco := _quitar_el_marco(imagen) if CON_MARCO.has(nombre) else 0
		var apurados := _apurar_el_filo(imagen)
		if borrados + marco + apurados <= 0:
			continue
		tocados += 1
		imagen.save_png(ProjectSettings.globalize_path(ruta))
		print("%-28s %7d de fondo · %6d de marco · %5d de filo" % [
			nombre, borrados, marco, apurados])

	print("")
	print("%d iconos mirados, %d limpiados" % [mirados, tocados])
	quit()


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
					if nx < 0 or ny < 0 or nx >= w or ny >= h \
							or imagen.get_pixel(nx, ny).a < 0.08:
						fuera.append(Vector2i(x, y))
						break
		for punto: Vector2i in fuera:
			var color := imagen.get_pixel(punto.x, punto.y)
			imagen.set_pixel(punto.x, punto.y,
				Color(color.r, color.g, color.b, 0.0))
		apurados += fuera.size()
	return apurados
