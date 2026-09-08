class_name PielDeEra
extends RefCounted
## De que esta hecha la interfaz en cada era.
##
## La ventana no es un panel de cristal flotando sobre el mundo: es una PIEL
## TENSADA, y lo escrito en ella esta pintado con ocre y carbon. La paleta sale
## del catalogo de materiales que la banda de verdad recoge -[Materia] tiene
## OCRE, HUESO, PIEL, SILEX- y no de un muestrario de diseñador.
##
## Y eso es lo que hace que la interfaz pueda EVOLUCIONAR sin que sea un
## capricho: no cambia porque toque una piel nueva cada era, cambia porque la
## banda aprende a hacer materiales nuevos y el soporte de su informacion
## cambia con ellos. Ver docs/INTERFAZ.md.
##
##   Paleolitico  piel tensada y pared de cueva · ocre y carbon
##   Mesolitico   corteza y estera de junco     · ocre y blanco de concha
##   Neolitico    barro cocido y lino           · almagre y engobe
##   Metales      tablilla y bronce bruñido     · tinta y verdin
##   Historica    pergamino                     · sepia y minio

## La paleta de cada era. Los nombres son los del material, no los del papel de
## un diseñador: quien lea `HEMATITES` sabe de que color es.
const PALETAS := {
	Site.Era.PALEOLITICO: {
		"ground":    Color(0.106, 0.086, 0.067),   ## Piel curtida en sombra
		"surface":   Color(0.153, 0.125, 0.098),   ## La misma piel, a la luz
		"raised":    Color(0.212, 0.176, 0.137),   ## Piel tensada de un boton
		"rule":      Color(0.400, 0.318, 0.216),   ## Filete de ocre apagado
		"ink":       Color(0.925, 0.894, 0.827),   ## Hueso
		"ink_soft":  Color(0.690, 0.639, 0.557),   ## Ceniza
		"ink_faint": Color(0.478, 0.435, 0.376),   ## Carbon frotado
		"accent":    Color(0.851, 0.588, 0.267),   ## Ocre
		"cold":      Color(0.545, 0.647, 0.722),   ## Silex
		"good":      Color(0.514, 0.639, 0.400),   ## Liquen
		"bad":       Color(0.769, 0.353, 0.286),   ## Hematites
	},
	Site.Era.MESOLITICO: {
		"ground":    Color(0.114, 0.106, 0.082), "surface": Color(0.165, 0.153, 0.118),
		"raised":    Color(0.227, 0.212, 0.161), "rule":    Color(0.404, 0.376, 0.267),
		"ink":       Color(0.933, 0.918, 0.855), "ink_soft": Color(0.702, 0.686, 0.596),
		"ink_faint": Color(0.490, 0.478, 0.412), "accent":  Color(0.804, 0.635, 0.318),
		"cold":      Color(0.541, 0.663, 0.667), "good":    Color(0.545, 0.678, 0.404),
		"bad":       Color(0.757, 0.376, 0.294),
	},
	Site.Era.NEOLITICO: {
		"ground":    Color(0.137, 0.106, 0.086), "surface": Color(0.196, 0.149, 0.118),
		"raised":    Color(0.278, 0.204, 0.157), "rule":    Color(0.478, 0.333, 0.239),
		"ink":       Color(0.945, 0.906, 0.839), "ink_soft": Color(0.722, 0.647, 0.573),
		"ink_faint": Color(0.510, 0.443, 0.388), "accent":  Color(0.808, 0.451, 0.267),
		"cold":      Color(0.549, 0.616, 0.686), "good":    Color(0.549, 0.643, 0.365),
		"bad":       Color(0.729, 0.286, 0.239),
	},
	Site.Era.METALES: {
		"ground":    Color(0.094, 0.098, 0.094), "surface": Color(0.137, 0.145, 0.137),
		"raised":    Color(0.196, 0.208, 0.196), "rule":    Color(0.365, 0.376, 0.325),
		"ink":       Color(0.918, 0.918, 0.894), "ink_soft": Color(0.671, 0.678, 0.647),
		"ink_faint": Color(0.463, 0.475, 0.451), "accent":  Color(0.784, 0.643, 0.373),
		"cold":      Color(0.478, 0.647, 0.639), "good":    Color(0.478, 0.647, 0.427),
		"bad":       Color(0.769, 0.361, 0.310),
	},
	Site.Era.HISTORICA: {
		"ground":    Color(0.122, 0.110, 0.094), "surface": Color(0.176, 0.161, 0.137),
		"raised":    Color(0.243, 0.224, 0.192), "rule":    Color(0.427, 0.384, 0.318),
		"ink":       Color(0.937, 0.914, 0.863), "ink_soft": Color(0.706, 0.671, 0.612),
		"ink_faint": Color(0.494, 0.463, 0.416), "accent":  Color(0.776, 0.541, 0.318),
		"cold":      Color(0.514, 0.596, 0.678), "good":    Color(0.510, 0.627, 0.412),
		"bad":       Color(0.749, 0.302, 0.259),
	},
}

## Cuanto se nota el grano del soporte, de 0 a 1.
##
## Una piel raspada tiene grano; un pergamino, mucho menos. Es lo que separa un
## rectangulo de color de algo que parece material.
const GRANO := {
	Site.Era.PALEOLITICO: 0.055,
	Site.Era.MESOLITICO: 0.045,
	Site.Era.NEOLITICO: 0.035,
	Site.Era.METALES: 0.022,
	Site.Era.HISTORICA: 0.018,
}

## Redondeo de las esquinas, en pixeles.
##
## CERO en el Paleolitico, y es la decision que mas cambia la impresion: una
## piel tensada no tiene el radio de 6 px de un widget. El redondeo llega con
## el torno y la vasija.
const ESQUINA := {
	Site.Era.PALEOLITICO: 0,
	Site.Era.MESOLITICO: 1,
	Site.Era.NEOLITICO: 4,
	Site.Era.METALES: 3,
	Site.Era.HISTORICA: 2,
}


static func paleta(era: Site.Era) -> Dictionary:
	return PALETAS.get(era, PALETAS[Site.Era.PALEOLITICO])


static func grano_de(era: Site.Era) -> float:
	return float(GRANO.get(era, 0.05))


static func esquina_de(era: Site.Era) -> int:
	return int(ESQUINA.get(era, 0))


## La textura de grano del soporte, generada una vez por era.
##
## Se dibuja en vez de cargarse por lo mismo que los iconos de [MateriaIcon] y
## las texturas del terreno: no hay pipeline de arte, y un ruido fino se genera
## mejor de lo que se pinta.
static var _granos: Dictionary = {}

static func textura_de_grano(era: Site.Era) -> ImageTexture:
	if _granos.has(era):
		return _granos[era]
	var lado := 128
	var fuerza := grano_de(era)
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	# Semilla fija: el grano tiene que ser el mismo en cada arranque, o la
	# interfaz cambia de aspecto entre partidas sin motivo.
	rng.seed = 20260908 + int(era)
	for y in range(lado):
		for x in range(lado):
			# Dos frecuencias: la fina es el poro y la gruesa es la veta.
			var poro := rng.randf() - 0.5
			var veta := sin(float(x) * 0.08 + float(y) * 0.031) * 0.35
			var v := clampf(0.5 + (poro + veta) * fuerza, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	var tex := ImageTexture.create_from_image(img)
	_granos[era] = tex
	return tex
