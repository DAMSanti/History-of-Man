class_name MateriaIcon
extends Control
## Icono dibujado de un material.
##
## Se dibuja en vez de cargarse porque no hay pipeline de arte: veintiocho
## PNG que mantener a mano, por veintiocho materiales, para unos glifos de
## veinte píxeles. Dibujarlos sale gratis, escala solo y se cambia editando
## una función.
##
## Lo que importa es la SILUETA, no el detalle: a este tamaño lo único que se
## lee es la forma general y el color, y esos dos tienen que bastar para no
## confundir una fuente de semillas con unas cuernas.

## Formas disponibles. Varios materiales comparten forma cuando de verdad se
## parecen —baya y fruto son ambos algo redondo que se coge de una mata— y se
## separan por color.
enum Glyph {
	BAYAS,      ## Racimo de tres bolas
	BELLOTA,    ## Óvalo con caperuza
	RAIZ,       ## Cuña hacia abajo con raicillas
	SETA,       ## Sombrero y pie
	HUEVO,      ## Óvalo liso
	PANAL,      ## Hexágono
	ESPIRAL,    ## Caracol
	CARNE,      ## Tajada con veta
	TIRAS,      ## Tres tiras colgando: carne seca
	PEZ_SECO,   ## Pez abierto en mariposa y colgado del humo
	PEZ,        ## Cuerpo y cola
	CONCHA,     ## Abanico con nervios
	CANTO,      ## Polígono angular
	ASTA,       ## Vara con dos candiles
	HUESO,      ## Diáfisis con dos cabezas
	PIEL,       ## Cuadrilátero irregular estirado
	HEBRAS,     ## Tres hilos verticales
	RAMAS,      ## Haz cruzado
	COPO,       ## Mata pequeña: yesca
	GOTA,       ## Lágrima
	MONTON,     ## Montoncito de polvo
	PLUMA,      ## Raquis con barbas
	CORTEZA,    ## Lámina curvada
	CESTA,      ## Trapecio con trenzado
	CUMBRE,     ## Pico con nieve: no es un material, es un sitio al que subir
	ODRE,       ## Zurrón con cuello atado
	AGUJA,      ## Espiga fina con ojo
	PUNZON,     ## Espiga maciza
	LANZA,      ## Astil con punta enmangada
	ARPON,      ## Astil con dientes a un lado
	NASA,       ## Cesto en embudo, tumbado: la trampa de mimbre
	ANZUELO,    ## Bastoncillo apuntado por los dos cabos, con su cordel
	RED,        ## Malla de rombos con las plomadas colgando
	BURIL,      ## Barrita con bisel en la punta
	RAEDERA,    ## Media luna: filo curvo y dorso recto
	PUNTA,      ## Hoja triangular con nervio
	# Fauna de caza. Cada especie la suya: un corzo y un jabalí no se leen
	# igual ni de lejos, y meterlos bajo el mismo tajo de carne es mentir
	# sobre qué se ha visto de verdad.
	CIERVO,     ## Cabeza con cornamenta grande y ramificada
	CORZO,      ## Cabeza con cornamenta pequeña, de tres puntas
	REBECO,     ## Cabeza con cuernos cortos en gancho
	JABALI,     ## Cuerpo rechoncho, hocico y cerdas en el lomo
	LIEBRE,     ## Cuerpo agazapado con orejas largas
	LOBO,       ## Cuerpo esbelto, orejas triangulares, cola baja
	UROGALLO,   ## Ave con la cola en abanico
	AVE,        ## Ave pequena de tierra: perdiz
	ANADE,      ## Ave de agua: cuello largo y pico ancho
	CABALLO,    ## Cabeza de perfil con crin
	URO,        ## Cabeza ancha con cuernos en lira
}

## Forma y color de cada material.
const LOOK := {
	Materia.Kind.FRUTO_SECO: [Glyph.BAYAS, Color(0.62, 0.45, 0.24)],
	Materia.Kind.BELLOTA: [Glyph.BELLOTA, Color(0.53, 0.38, 0.20)],
	Materia.Kind.BAYA: [Glyph.BAYAS, Color(0.42, 0.22, 0.38)],
	Materia.Kind.RAIZ: [Glyph.RAIZ, Color(0.72, 0.62, 0.42)],
	Materia.Kind.SETA: [Glyph.SETA, Color(0.74, 0.60, 0.48)],
	Materia.Kind.HUEVO: [Glyph.HUEVO, Color(0.88, 0.84, 0.72)],
	Materia.Kind.MIEL: [Glyph.PANAL, Color(0.86, 0.62, 0.18)],
	Materia.Kind.CARACOL: [Glyph.ESPIRAL, Color(0.68, 0.60, 0.44)],
	Materia.Kind.CARNE: [Glyph.CARNE, Color(0.70, 0.28, 0.26)],
	Materia.Kind.CARNE_SECA: [Glyph.TIRAS, Color(0.51, 0.24, 0.18)],
	Materia.Kind.PESCADO: [Glyph.PEZ, Color(0.46, 0.60, 0.68)],
	Materia.Kind.PESCADO_SECO: [Glyph.PEZ_SECO, Color(0.72, 0.58, 0.40)],
	Materia.Kind.MARISCO: [Glyph.CONCHA, Color(0.66, 0.63, 0.57)],
	Materia.Kind.PIEDRA: [Glyph.CANTO, Color(0.58, 0.57, 0.53)],
	Materia.Kind.SILEX: [Glyph.CANTO, Color(0.40, 0.47, 0.55)],
	Materia.Kind.ASTA: [Glyph.ASTA, Color(0.80, 0.75, 0.63)],
	Materia.Kind.HUESO: [Glyph.HUESO, Color(0.87, 0.85, 0.78)],
	Materia.Kind.PIEL: [Glyph.PIEL, Color(0.60, 0.44, 0.30)],
	Materia.Kind.TENDON: [Glyph.HEBRAS, Color(0.82, 0.78, 0.68)],
	Materia.Kind.FIBRA: [Glyph.HEBRAS, Color(0.50, 0.58, 0.28)],
	Materia.Kind.LENA: [Glyph.RAMAS, Color(0.42, 0.31, 0.20)],
	Materia.Kind.YESCA: [Glyph.COPO, Color(0.64, 0.56, 0.36)],
	Materia.Kind.RESINA: [Glyph.GOTA, Color(0.80, 0.55, 0.16)],
	Materia.Kind.GRASA: [Glyph.GOTA, Color(0.88, 0.85, 0.70)],
	Materia.Kind.OCRE: [Glyph.MONTON, Color(0.68, 0.29, 0.17)],
	Materia.Kind.CONCHA: [Glyph.CONCHA, Color(0.84, 0.80, 0.74)],
	Materia.Kind.PLUMA: [Glyph.PLUMA, Color(0.52, 0.54, 0.60)],
	Materia.Kind.CORTEZA: [Glyph.CORTEZA, Color(0.49, 0.38, 0.26)],
	Materia.Kind.AGUA: [Glyph.GOTA, Color(0.38, 0.58, 0.72)],
}

## Forma y color de cada tipo de herramienta, para las tablas del utillaje.
## Cada pieza con su silueta: son once herramientas y si cuatro comparten
## dibujo la tabla no se puede leer de un vistazo, que es justo para lo que
## está el icono. Sólo la lasca se queda con el canto genérico, porque una
## lasca ES un trozo de piedra sin más forma que la que salió del golpe.
const TOOL_LOOK := {
	Tool.Kind.BURIL: [Glyph.BURIL, Color(0.55, 0.64, 0.72)],
	Tool.Kind.RAEDERA: [Glyph.RAEDERA, Color(0.62, 0.68, 0.72)],
	Tool.Kind.LASCA: [Glyph.CANTO, Color(0.58, 0.57, 0.53)],
	Tool.Kind.PUNTA: [Glyph.PUNTA, Color(0.48, 0.58, 0.66)],
	Tool.Kind.AZAGAYA: [Glyph.LANZA, Color(0.80, 0.75, 0.63)],
	Tool.Kind.ARPON: [Glyph.ARPON, Color(0.72, 0.68, 0.58)],
	Tool.Kind.AGUJA: [Glyph.AGUJA, Color(0.87, 0.85, 0.78)],
	Tool.Kind.PUNZON: [Glyph.PUNZON, Color(0.80, 0.78, 0.71)],
	Tool.Kind.CESTO: [Glyph.CESTA, Color(0.56, 0.48, 0.28)],
	Tool.Kind.ODRE: [Glyph.ODRE, Color(0.60, 0.44, 0.30)],
	Tool.Kind.CUERDA: [Glyph.HEBRAS, Color(0.50, 0.58, 0.28)],
	Tool.Kind.NASA: [Glyph.NASA, Color(0.62, 0.52, 0.30)],
	Tool.Kind.ANZUELO: [Glyph.ANZUELO, Color(0.85, 0.83, 0.76)],
	Tool.Kind.RED: [Glyph.RED, Color(0.46, 0.62, 0.55)],
}

## Forma y color de cada especie de caza. La clave es el nombre tal cual lo
## da [Fauna] -en minúscula, sin artículo-, no un `Materia.Kind`: la carne
## sigue siendo un único material en el almacén, esto es solo la cara con la
## que se reconoce el animal en el paraje.
const SPECIES_LOOK := {
	"ciervo": [Glyph.CIERVO, Color(0.52, 0.36, 0.20)],
	"corzo": [Glyph.CORZO, Color(0.64, 0.48, 0.28)],
	"rebeco": [Glyph.REBECO, Color(0.48, 0.38, 0.26)],
	"liebre": [Glyph.LIEBRE, Color(0.64, 0.54, 0.40)],
	"lobo": [Glyph.LOBO, Color(0.56, 0.54, 0.50)],
	"urogallo": [Glyph.UROGALLO, Color(0.22, 0.22, 0.24)],
	# La clave va SIN tilde: es un identificador, no un rotulo. El nombre
	# bonito lo pone `Fauna.species_name`, que para eso esta.
	"jabali": [Glyph.JABALI, Color(0.28, 0.24, 0.20)],
	"conejo": [Glyph.LIEBRE, Color(0.55, 0.47, 0.38)],
	"perdiz": [Glyph.AVE, Color(0.62, 0.50, 0.36)],
	"anade": [Glyph.ANADE, Color(0.32, 0.46, 0.42)],
	"caballo": [Glyph.CABALLO, Color(0.60, 0.48, 0.32)],
	"uro": [Glyph.URO, Color(0.34, 0.28, 0.24)],
}

var glyph: Glyph = Glyph.CANTO
var tint: Color = Color.WHITE


static func for_materia(kind: Materia.Kind, size: float = 20.0) -> MateriaIcon:
	var entry: Array = LOOK.get(kind, [Glyph.CANTO, Color(0.6, 0.6, 0.6)])
	return _make(entry[0] as Glyph, entry[1] as Color, size)


static func for_tool(kind: Tool.Kind, size: float = 20.0) -> MateriaIcon:
	var entry: Array = TOOL_LOOK.get(kind, [Glyph.CANTO, Color(0.6, 0.6, 0.6)])
	return _make(entry[0] as Glyph, entry[1] as Color, size)


static func for_fauna(species: String, size: float = 20.0) -> MateriaIcon:
	var entry: Array = SPECIES_LOOK.get(species, [Glyph.CARNE, Color(0.70, 0.28, 0.26)])
	return _make(entry[0] as Glyph, entry[1] as Color, size)


static func _make(glyph_value: Glyph, color: Color, size: float) -> MateriaIcon:
	var icon := MateriaIcon.new()
	icon.glyph = glyph_value
	icon.tint = color
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return
	# Todo se dibuja en un cuadrado de 0 a 1 y se escala al final, para poder
	# escribir las formas con numeros legibles
	var dark := tint.darkened(0.35)

	match glyph:
		Glyph.BAYAS:
			_circle(Vector2(0.33, 0.60), 0.19, s, tint)
			_circle(Vector2(0.67, 0.58), 0.17, s, dark)
			_circle(Vector2(0.50, 0.32), 0.18, s, tint.lightened(0.12))
		Glyph.BELLOTA:
			_poly([Vector2(0.30, 0.45), Vector2(0.70, 0.45), Vector2(0.62, 0.86),
				Vector2(0.38, 0.86)], s, tint)
			_poly([Vector2(0.24, 0.44), Vector2(0.76, 0.44), Vector2(0.70, 0.24),
				Vector2(0.30, 0.24)], s, dark)
		Glyph.RAIZ:
			# Cuerpo de nabo: ancho arriba y en punta abajo, con raicillas.
			# Con la cuña estrecha de antes esto parecía un signo de admiración
			_poly([Vector2(0.24, 0.30), Vector2(0.50, 0.20), Vector2(0.76, 0.30),
				Vector2(0.62, 0.68), Vector2(0.50, 0.80), Vector2(0.38, 0.68)],
				s, tint)
			_line(Vector2(0.50, 0.76), Vector2(0.50, 0.96), s, dark, 0.045)
			_line(Vector2(0.44, 0.72), Vector2(0.26, 0.90), s, dark, 0.04)
			_line(Vector2(0.56, 0.72), Vector2(0.74, 0.90), s, dark, 0.04)
			_line(Vector2(0.42, 0.26), Vector2(0.30, 0.08), s, dark, 0.05)
			_line(Vector2(0.58, 0.26), Vector2(0.70, 0.08), s, dark, 0.05)
		Glyph.SETA:
			_poly([Vector2(0.42, 0.52), Vector2(0.58, 0.52), Vector2(0.58, 0.86),
				Vector2(0.42, 0.86)], s, tint.lightened(0.25))
			_poly([Vector2(0.16, 0.52), Vector2(0.28, 0.26), Vector2(0.72, 0.26),
				Vector2(0.84, 0.52)], s, tint)
		Glyph.HUEVO:
			_poly([Vector2(0.50, 0.14), Vector2(0.76, 0.48), Vector2(0.68, 0.82),
				Vector2(0.32, 0.82), Vector2(0.24, 0.48)], s, tint)
		Glyph.PANAL:
			_poly([Vector2(0.50, 0.12), Vector2(0.86, 0.32), Vector2(0.86, 0.68),
				Vector2(0.50, 0.88), Vector2(0.14, 0.68), Vector2(0.14, 0.32)], s, tint)
			_poly([Vector2(0.50, 0.34), Vector2(0.68, 0.44), Vector2(0.68, 0.62),
				Vector2(0.50, 0.72), Vector2(0.32, 0.62), Vector2(0.32, 0.44)], s, dark)
		Glyph.ESPIRAL:
			_circle(Vector2(0.50, 0.52), 0.36, s, tint)
			_circle(Vector2(0.53, 0.50), 0.24, s, dark)
			_circle(Vector2(0.50, 0.50), 0.12, s, tint)
		Glyph.CARNE:
			_poly([Vector2(0.18, 0.34), Vector2(0.74, 0.20), Vector2(0.86, 0.56),
				Vector2(0.44, 0.82), Vector2(0.16, 0.62)], s, tint)
			_line(Vector2(0.34, 0.40), Vector2(0.66, 0.58), s, tint.lightened(0.3), 0.07)
		Glyph.TIRAS:
			for i in range(3):
				var x := 0.26 + float(i) * 0.24
				_poly([Vector2(x - 0.07, 0.16), Vector2(x + 0.07, 0.16),
					Vector2(x + 0.05, 0.84), Vector2(x - 0.05, 0.84)], s,
					tint if i != 1 else dark)
		Glyph.PEZ:
			_poly([Vector2(0.14, 0.50), Vector2(0.44, 0.24), Vector2(0.76, 0.50),
				Vector2(0.44, 0.76)], s, tint)
			_poly([Vector2(0.76, 0.50), Vector2(0.94, 0.28), Vector2(0.94, 0.72)],
				s, dark)
		Glyph.CONCHA:
			_poly([Vector2(0.50, 0.86), Vector2(0.12, 0.40), Vector2(0.30, 0.18),
				Vector2(0.70, 0.18), Vector2(0.88, 0.40)], s, tint)
			_line(Vector2(0.50, 0.84), Vector2(0.28, 0.32), s, dark, 0.045)
			_line(Vector2(0.50, 0.84), Vector2(0.50, 0.22), s, dark, 0.045)
			_line(Vector2(0.50, 0.84), Vector2(0.72, 0.32), s, dark, 0.045)
		Glyph.PEZ_SECO:
			# Abierto en mariposa y colgado de una vara: asi se ahuma, y asi
			# se distingue de un pez entero de un vistazo
			_line(Vector2(0.08, 0.16), Vector2(0.92, 0.16), s, dark, 0.055)
			_line(Vector2(0.50, 0.16), Vector2(0.50, 0.30), s, dark, 0.04)
			_poly([Vector2(0.50, 0.28), Vector2(0.22, 0.52), Vector2(0.34, 0.86),
				Vector2(0.50, 0.92)], s, tint)
			_poly([Vector2(0.50, 0.28), Vector2(0.78, 0.52), Vector2(0.66, 0.86),
				Vector2(0.50, 0.92)], s, tint.darkened(0.18))
			# La espina, que es lo que queda a la vista al abrirlo
			_line(Vector2(0.50, 0.30), Vector2(0.50, 0.90), s, dark, 0.035)
			for i in range(3):
				var y := 0.44 + float(i) * 0.16
				_line(Vector2(0.34, y), Vector2(0.66, y), s, dark, 0.022)
		Glyph.CANTO:
			_poly([Vector2(0.20, 0.44), Vector2(0.42, 0.16), Vector2(0.78, 0.30),
				Vector2(0.84, 0.64), Vector2(0.52, 0.86), Vector2(0.20, 0.72)], s, tint)
			_poly([Vector2(0.42, 0.16), Vector2(0.78, 0.30), Vector2(0.52, 0.50)],
				s, tint.lightened(0.22))
		Glyph.ASTA:
			_line(Vector2(0.38, 0.90), Vector2(0.52, 0.20), s, tint, 0.09)
			_line(Vector2(0.47, 0.56), Vector2(0.82, 0.34), s, tint, 0.07)
			_line(Vector2(0.44, 0.72), Vector2(0.76, 0.66), s, tint, 0.06)
			_line(Vector2(0.50, 0.34), Vector2(0.26, 0.20), s, tint, 0.06)
		Glyph.HUESO:
			_line(Vector2(0.28, 0.72), Vector2(0.72, 0.28), s, tint, 0.14)
			_circle(Vector2(0.24, 0.70), 0.14, s, tint)
			_circle(Vector2(0.32, 0.80), 0.13, s, tint)
			_circle(Vector2(0.76, 0.30), 0.14, s, tint)
			_circle(Vector2(0.68, 0.20), 0.13, s, tint)
		Glyph.PIEL:
			# Piel estirada: cuerpo con las cuatro patas marcadas. El polígono
			# redondeado de antes salía casi hexagonal y se confundía con la miel
			_poly([Vector2(0.50, 0.14), Vector2(0.70, 0.30), Vector2(0.88, 0.22),
				Vector2(0.78, 0.48), Vector2(0.88, 0.78), Vector2(0.66, 0.72),
				Vector2(0.50, 0.90), Vector2(0.34, 0.72), Vector2(0.12, 0.78),
				Vector2(0.22, 0.48), Vector2(0.12, 0.22), Vector2(0.30, 0.30)],
				s, tint)
			_line(Vector2(0.50, 0.24), Vector2(0.50, 0.80), s, dark, 0.05)
		Glyph.HEBRAS:
			for i in range(3):
				var x := 0.28 + float(i) * 0.22
				_line(Vector2(x, 0.14), Vector2(x + 0.06, 0.86), s,
					tint if i != 1 else dark, 0.07)
		Glyph.RAMAS:
			_line(Vector2(0.14, 0.72), Vector2(0.86, 0.34), s, tint, 0.10)
			_line(Vector2(0.16, 0.36), Vector2(0.84, 0.70), s, dark, 0.09)
			_line(Vector2(0.50, 0.14), Vector2(0.50, 0.88), s, tint.lightened(0.15), 0.07)
		Glyph.COPO:
			_circle(Vector2(0.50, 0.58), 0.26, s, tint)
			for i in range(6):
				var a := (float(i) / 6.0) * TAU
				_line(Vector2(0.50, 0.58),
					Vector2(0.50 + cos(a) * 0.40, 0.58 + sin(a) * 0.36), s, dark, 0.05)
		Glyph.GOTA:
			_poly([Vector2(0.50, 0.12), Vector2(0.78, 0.56), Vector2(0.68, 0.84),
				Vector2(0.32, 0.84), Vector2(0.22, 0.56)], s, tint)
			_circle(Vector2(0.40, 0.58), 0.09, s, tint.lightened(0.35))
		Glyph.MONTON:
			_poly([Vector2(0.10, 0.82), Vector2(0.50, 0.24), Vector2(0.90, 0.82)],
				s, tint)
			_poly([Vector2(0.50, 0.24), Vector2(0.90, 0.82), Vector2(0.50, 0.82)],
				s, dark)
		Glyph.PLUMA:
			# Las barbas van INCLINADAS hacia el cálamo y estrechándose hacia
			# la punta. Perpendiculares y todas iguales, esto salía un tornillo
			var quill := Vector2(0.30, 0.90)
			var tip := Vector2(0.70, 0.12)
			for i in range(7):
				var t := 0.06 + float(i) * 0.14
				var spine := quill.lerp(tip, t)
				var reach: float = 0.30 * (1.0 - t * 0.75)
				_line(spine, spine + Vector2(reach, reach * 0.55), s, tint, 0.035)
				_line(spine, spine + Vector2(-reach, -reach * 0.55), s, tint, 0.035)
			_line(quill, tip, s, tint.lightened(0.35), 0.05)
		Glyph.CORTEZA:
			_poly([Vector2(0.24, 0.16), Vector2(0.62, 0.20), Vector2(0.76, 0.84),
				Vector2(0.36, 0.80)], s, tint)
			_line(Vector2(0.34, 0.22), Vector2(0.46, 0.80), s, dark, 0.05)
			_line(Vector2(0.52, 0.24), Vector2(0.64, 0.80), s, dark, 0.05)
		Glyph.CESTA:
			# Trapecio boca arriba con trenzado. Antes compartía dibujo con la
			# leña —dos haces de palos cruzados— y no había forma de saber cuál
			# era cuál en la tabla
			_poly([Vector2(0.14, 0.34), Vector2(0.86, 0.34), Vector2(0.72, 0.86),
				Vector2(0.28, 0.86)], s, tint)
			_line(Vector2(0.10, 0.32), Vector2(0.90, 0.32), s, tint.lightened(0.3), 0.09)
			_line(Vector2(0.19, 0.52), Vector2(0.81, 0.52), s, dark, 0.045)
			_line(Vector2(0.23, 0.69), Vector2(0.77, 0.69), s, dark, 0.045)
		Glyph.ODRE:
			# Zurrón: panza ancha y cuello atado. Compartía dibujo con la piel,
			# que a su vez salía igual que el panal
			_poly([Vector2(0.50, 0.86), Vector2(0.20, 0.68), Vector2(0.18, 0.44),
				Vector2(0.38, 0.30), Vector2(0.62, 0.30), Vector2(0.82, 0.44),
				Vector2(0.80, 0.68)], s, tint)
			_poly([Vector2(0.42, 0.32), Vector2(0.58, 0.32), Vector2(0.56, 0.12),
				Vector2(0.44, 0.12)], s, dark)
			_line(Vector2(0.38, 0.24), Vector2(0.62, 0.24), s, tint.lightened(0.35), 0.06)
		Glyph.AGUJA:
			_poly([Vector2(0.50, 0.06), Vector2(0.60, 0.40), Vector2(0.56, 0.92),
				Vector2(0.44, 0.92), Vector2(0.40, 0.40)], s, tint)
			# El ojo, que es lo que la distingue del punzón
			_circle(Vector2(0.50, 0.76), 0.075, s, UISkin.GROUND)
		Glyph.PUNZON:
			_poly([Vector2(0.50, 0.06), Vector2(0.62, 0.46), Vector2(0.58, 0.90),
				Vector2(0.42, 0.90), Vector2(0.38, 0.46)], s, tint)
			_circle(Vector2(0.50, 0.86), 0.11, s, dark)
		Glyph.LANZA:
			# Astil largo y punta enmangada con su ligadura
			_line(Vector2(0.28, 0.94), Vector2(0.66, 0.30), s, dark, 0.075)
			_poly([Vector2(0.74, 0.06), Vector2(0.82, 0.34), Vector2(0.58, 0.42)],
				s, tint)
			_line(Vector2(0.58, 0.44), Vector2(0.70, 0.38), s, tint.lightened(0.3), 0.05)
		Glyph.ARPON:
			# Dientes A UN SOLO LADO, que es lo que hace un arpón y no una lanza
			_line(Vector2(0.34, 0.94), Vector2(0.62, 0.10), s, tint, 0.085)
			for i in range(3):
				var along := 0.22 + float(i) * 0.22
				var base := Vector2(0.62, 0.10).lerp(Vector2(0.34, 0.94), along)
				_poly([base, base + Vector2(0.26, 0.02),
					base + Vector2(0.06, 0.16)], s, dark)
		Glyph.NASA:
			# Embudo tumbado, con la boca ancha a la izquierda y el trenzado
			# marcado: es un cesto, pero echado y con entrada de embudo
			_poly([Vector2(0.08, 0.14), Vector2(0.08, 0.86), Vector2(0.88, 0.68),
				Vector2(0.88, 0.32)], s, tint)
			# El aro de la boca, a la izquierda, y el cono de entrada por el
			# que el pez pasa y ya no sabe volver. En claro y no en oscuro:
			# sobre el fondo del panel, lo oscuro desaparece y la nasa se leia
			# como un cuerno.
			_line(Vector2(0.08, 0.12), Vector2(0.08, 0.88), s,
				tint.lightened(0.45), 0.09)
			_poly([Vector2(0.08, 0.18), Vector2(0.08, 0.82), Vector2(0.38, 0.56),
				Vector2(0.38, 0.44)], s, tint.lightened(0.25))
			# El trenzado
			_line(Vector2(0.46, 0.28), Vector2(0.46, 0.72), s, dark, 0.04)
			_line(Vector2(0.66, 0.30), Vector2(0.66, 0.70), s, dark, 0.04)
			_line(Vector2(0.85, 0.32), Vector2(0.85, 0.68), s, dark, 0.04)
		Glyph.ANZUELO:
			# NO es un gancho: es un bastoncillo apuntado por los dos cabos y
			# atado por el medio. Dibujarlo curvo seria dibujar un anzuelo
			# mesolitico en un juego del Paleolitico.
			_poly([Vector2(0.16, 0.84), Vector2(0.44, 0.50), Vector2(0.56, 0.56),
				Vector2(0.30, 0.90)], s, tint)
			_poly([Vector2(0.84, 0.16), Vector2(0.56, 0.50), Vector2(0.44, 0.44),
				Vector2(0.70, 0.10)], s, tint)
			# La ligadura del medio, que es de donde tira el sedal
			_circle(Vector2(0.50, 0.50), 0.10, s, dark)
			_line(Vector2(0.50, 0.50), Vector2(0.92, 0.72), s, dark, 0.04)
		Glyph.RED:
			# Malla de rombos y las plomadas de la relinga de abajo
			for i in range(4):
				var x := 0.10 + float(i) * 0.26
				_line(Vector2(x, 0.10), Vector2(x + 0.36, 0.74), s, tint, 0.045)
				_line(Vector2(x + 0.36, 0.10), Vector2(x, 0.74), s, tint, 0.045)
			_line(Vector2(0.04, 0.74), Vector2(0.96, 0.74), s, dark, 0.05)
			for i in range(3):
				_circle(Vector2(0.22 + float(i) * 0.28, 0.86), 0.07, s, dark)
		Glyph.BURIL:
			# Barrita con bisel: el filo es la esquina, no el canto
			_poly([Vector2(0.38, 0.90), Vector2(0.62, 0.90), Vector2(0.62, 0.26),
				Vector2(0.38, 0.26)], s, tint)
			_poly([Vector2(0.38, 0.28), Vector2(0.62, 0.28), Vector2(0.62, 0.10)],
				s, tint.lightened(0.3))
		Glyph.RAEDERA:
			# Dorso recto arriba y filo curvo abajo: la forma de trabajo
			var arc := [Vector2(0.12, 0.34), Vector2(0.88, 0.34)]
			for i in range(9):
				var a := PI * (1.0 - float(i) / 8.0)
				arc.append(Vector2(0.50 + cos(a) * -0.38, 0.34 + sin(a) * 0.50))
			_poly(arc, s, tint)
			_line(Vector2(0.16, 0.36), Vector2(0.84, 0.36), s, dark, 0.05)
		Glyph.PUNTA:
			_poly([Vector2(0.50, 0.06), Vector2(0.76, 0.56), Vector2(0.50, 0.94),
				Vector2(0.24, 0.56)], s, tint)
			_line(Vector2(0.50, 0.14), Vector2(0.50, 0.86), s, dark, 0.05)
		Glyph.CIERVO:
			# Cabeza y cornamenta grande, muy ramificada: el venado
			_poly([Vector2(0.38, 0.55), Vector2(0.62, 0.55), Vector2(0.58, 0.86),
				Vector2(0.42, 0.86)], s, tint)
			_circle(Vector2(0.50, 0.50), 0.10, s, tint)
			_line(Vector2(0.46, 0.50), Vector2(0.30, 0.10), s, dark, 0.05)
			_line(Vector2(0.36, 0.30), Vector2(0.20, 0.24), s, dark, 0.04)
			_line(Vector2(0.32, 0.20), Vector2(0.18, 0.16), s, dark, 0.04)
			_line(Vector2(0.54, 0.50), Vector2(0.70, 0.10), s, dark, 0.05)
			_line(Vector2(0.64, 0.30), Vector2(0.80, 0.24), s, dark, 0.04)
			_line(Vector2(0.68, 0.20), Vector2(0.82, 0.16), s, dark, 0.04)
		Glyph.CORZO:
			# La misma cabeza, con cornamenta pequeña de tres puntas: es lo
			# que de verdad distingue un corzo de un venado en el monte
			_poly([Vector2(0.38, 0.55), Vector2(0.62, 0.55), Vector2(0.58, 0.86),
				Vector2(0.42, 0.86)], s, tint)
			_circle(Vector2(0.50, 0.50), 0.09, s, tint)
			_line(Vector2(0.46, 0.50), Vector2(0.36, 0.22), s, dark, 0.045)
			_line(Vector2(0.40, 0.32), Vector2(0.28, 0.28), s, dark, 0.035)
			_line(Vector2(0.54, 0.50), Vector2(0.64, 0.22), s, dark, 0.045)
			_line(Vector2(0.60, 0.32), Vector2(0.72, 0.28), s, dark, 0.035)
		Glyph.REBECO:
			# Cuernos cortos y en gancho, no ramificados: cabra de peña, no
			# ciervo de bosque
			_poly([Vector2(0.38, 0.55), Vector2(0.62, 0.55), Vector2(0.58, 0.86),
				Vector2(0.42, 0.86)], s, tint)
			_circle(Vector2(0.50, 0.50), 0.09, s, tint)
			_line(Vector2(0.46, 0.50), Vector2(0.44, 0.20), s, dark, 0.045)
			_line(Vector2(0.44, 0.20), Vector2(0.34, 0.16), s, dark, 0.04)
			_line(Vector2(0.54, 0.50), Vector2(0.56, 0.20), s, dark, 0.045)
			_line(Vector2(0.56, 0.20), Vector2(0.66, 0.16), s, dark, 0.04)
		Glyph.JABALI:
			# Cuerpo rechoncho, hocico adelantado y cerdas erizadas en el
			# lomo: nada que ver con la silueta esbelta de un ciervo
			_poly([Vector2(0.16, 0.60), Vector2(0.22, 0.38), Vector2(0.50, 0.28),
				Vector2(0.82, 0.36), Vector2(0.88, 0.58), Vector2(0.70, 0.78),
				Vector2(0.34, 0.78)], s, tint)
			_poly([Vector2(0.10, 0.50), Vector2(0.22, 0.44), Vector2(0.22, 0.62)],
				s, dark)
			_line(Vector2(0.30, 0.32), Vector2(0.26, 0.16), s, dark, 0.035)
			_line(Vector2(0.42, 0.28), Vector2(0.40, 0.12), s, dark, 0.035)
			_line(Vector2(0.54, 0.28), Vector2(0.54, 0.12), s, dark, 0.035)
			_line(Vector2(0.16, 0.56), Vector2(0.08, 0.62), s, tint.lightened(0.4), 0.03)
		Glyph.LIEBRE:
			# Agazapada, con las orejas largas por encima del lomo: lo unico
			# que hace falta ver para saber que no es un zorro
			_poly([Vector2(0.22, 0.60), Vector2(0.30, 0.42), Vector2(0.60, 0.40),
				Vector2(0.80, 0.56), Vector2(0.78, 0.78), Vector2(0.34, 0.82)], s, tint)
			_poly([Vector2(0.42, 0.40), Vector2(0.36, 0.08), Vector2(0.46, 0.10),
				Vector2(0.50, 0.40)], s, dark)
			_poly([Vector2(0.54, 0.40), Vector2(0.58, 0.08), Vector2(0.68, 0.10),
				Vector2(0.62, 0.40)], s, dark)
		Glyph.LOBO:
			# Cuerpo esbelto de perfil, orejas de punta y cola baja: la
			# postura de acecho, no de perro echado
			_poly([Vector2(0.14, 0.62), Vector2(0.20, 0.44), Vector2(0.46, 0.36),
				Vector2(0.70, 0.40), Vector2(0.86, 0.56), Vector2(0.80, 0.72),
				Vector2(0.30, 0.74)], s, tint)
			_poly([Vector2(0.24, 0.38), Vector2(0.30, 0.18), Vector2(0.36, 0.38)], s, dark)
			_poly([Vector2(0.42, 0.34), Vector2(0.46, 0.14), Vector2(0.52, 0.34)], s, dark)
			_poly([Vector2(0.08, 0.56), Vector2(0.20, 0.50), Vector2(0.20, 0.62)], s, dark)
			_line(Vector2(0.80, 0.68), Vector2(0.95, 0.84), s, tint, 0.05)
		Glyph.UROGALLO:
			# Cuerpo redondo y cola en abanico: la postura de cortejo es lo
			# que hace inconfundible a un urogallo
			_circle(Vector2(0.32, 0.44), 0.16, s, tint)
			_poly([Vector2(0.30, 0.52), Vector2(0.30, 0.30), Vector2(0.92, 0.12),
				Vector2(0.92, 0.70)], s, dark)
			_line(Vector2(0.30, 0.30), Vector2(0.92, 0.12), s, tint.lightened(0.2), 0.02)
			_line(Vector2(0.30, 0.52), Vector2(0.92, 0.70), s, tint.lightened(0.2), 0.02)
			_circle(Vector2(0.20, 0.38), 0.04, s, dark)
		Glyph.AVE:
			# Perdiz: cuerpo redondo, cabeza pequena y cola corta. Se
			# distingue del urogallo por no llevar el abanico
			_circle(Vector2(0.46, 0.56), 0.22, s, tint)
			_circle(Vector2(0.26, 0.38), 0.10, s, tint)
			_poly([Vector2(0.16, 0.38), Vector2(0.24, 0.34), Vector2(0.24, 0.42)],
				s, dark)
			_poly([Vector2(0.62, 0.50), Vector2(0.88, 0.40), Vector2(0.86, 0.62)],
				s, dark)
			_line(Vector2(0.42, 0.76), Vector2(0.40, 0.92), s, dark, 0.04)
			_line(Vector2(0.54, 0.76), Vector2(0.56, 0.92), s, dark, 0.04)
		Glyph.ANADE:
			# Ave de agua: cuello en S, pico ancho y el cuerpo posado
			_poly([Vector2(0.24, 0.62), Vector2(0.42, 0.52), Vector2(0.78, 0.56),
				Vector2(0.88, 0.70), Vector2(0.60, 0.80), Vector2(0.28, 0.76)],
				s, tint)
			_line(Vector2(0.42, 0.56), Vector2(0.38, 0.30), s, tint, 0.09)
			_circle(Vector2(0.38, 0.26), 0.10, s, tint)
			_poly([Vector2(0.28, 0.24), Vector2(0.10, 0.26), Vector2(0.28, 0.32)],
				s, dark)
			_line(Vector2(0.24, 0.80), Vector2(0.86, 0.80), s, tint.lightened(0.35), 0.04)
		Glyph.CABALLO:
			# Cabeza de perfil con la crin erizada: el caballo de las
			# cuevas, que es como se dibujaba entonces
			_poly([Vector2(0.30, 0.86), Vector2(0.34, 0.44), Vector2(0.52, 0.32),
				Vector2(0.78, 0.34), Vector2(0.90, 0.50), Vector2(0.62, 0.58),
				Vector2(0.52, 0.86)], s, tint)
			_poly([Vector2(0.46, 0.34), Vector2(0.42, 0.16), Vector2(0.54, 0.28)],
				s, dark)
			for i in range(4):
				var x := 0.36 + float(i) * 0.11
				_line(Vector2(x, 0.36), Vector2(x - 0.05, 0.16), s, dark, 0.035)
			_circle(Vector2(0.62, 0.44), 0.04, s, dark)
		Glyph.URO:
			# Testuz ancho y cuernos en lira hacia delante: el uro no es una
			# vaca, y en las paredes se le pinta justo por eso
			_poly([Vector2(0.32, 0.48), Vector2(0.68, 0.48), Vector2(0.62, 0.88),
				Vector2(0.38, 0.88)], s, tint)
			_circle(Vector2(0.50, 0.48), 0.17, s, tint)
			_line(Vector2(0.36, 0.42), Vector2(0.16, 0.26), s, dark, 0.06)
			_line(Vector2(0.16, 0.26), Vector2(0.22, 0.10), s, dark, 0.05)
			_line(Vector2(0.64, 0.42), Vector2(0.84, 0.26), s, dark, 0.06)
			_line(Vector2(0.84, 0.26), Vector2(0.78, 0.10), s, dark, 0.05)
			_circle(Vector2(0.44, 0.50), 0.035, s, dark)
			_circle(Vector2(0.56, 0.50), 0.035, s, dark)
		Glyph.CUMBRE:
			# Dos crestas y el nevero de arriba. La segunda cresta, más baja y
			# detrás, es lo que lo hace leerse como monte y no como triángulo
			_poly([Vector2(0.46, 0.40), Vector2(0.92, 0.84), Vector2(0.30, 0.84)],
				s, dark)
			_poly([Vector2(0.38, 0.16), Vector2(0.74, 0.84), Vector2(0.04, 0.84)],
				s, tint)
			_poly([Vector2(0.38, 0.16), Vector2(0.52, 0.42), Vector2(0.44, 0.36),
				Vector2(0.34, 0.44), Vector2(0.25, 0.38)], s, Color(0.95, 0.96, 0.97))


func _circle(at: Vector2, radius: float, s: float, color: Color) -> void:
	draw_circle(at * s, radius * s, color)


func _poly(points: Array, s: float, color: Color) -> void:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * s)
	draw_colored_polygon(scaled, color)


func _line(from_point: Vector2, to_point: Vector2, s: float,
		color: Color, width: float) -> void:
	draw_line(from_point * s, to_point * s, color, width * s, true)
