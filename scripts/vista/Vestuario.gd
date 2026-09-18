class_name Vestuario
## DE QUÉ VA VESTIDA LA BANDA EN CADA ERA.
##
## Sustituye a la `Prendas` de la primera versión, que no vestía a nadie: aquella «prenda»
## era la piel del propio cuerpo empujada un centímetro hacia afuera y teñida, o sea una
## mancha de color. Esto son **piezas de ropa de verdad** —túnica, calzas, botas, capucha—,
## mallas sueltas cosidas al mismo esqueleto, del pack CC0 «Modular Character Outfits».
##
## El pack libre trae **dos atuendos**, aldeano y montero, por sexo. No son once ni cinco,
## así que la era se nota en tres cosas a la vez:
##
##   - **qué piezas se ponen** —el montero lleva capucha y hombreras, el aldeano no—,
##   - **de qué color** —el tinte de la era, que es lo que más se lee de lejos—,
##   - y **cuánto tapa** —en el Paleolítico van con los brazos al aire y sin capucha—.
##
## Son cinco eras porque el código tiene cinco (`Site.Era`), que es lo que ya usa la piel de
## la interfaz. Las once de `docs/EPOCA_NN_*.md` son el reparto del diseño. GRAFICOS §5.1.

## Las piezas de cada atuendo, sin el sexo delante: se compone en [piezas].
const ALDEANO := ["Peasant_Body", "Peasant_Arms", "Peasant_Legs", "Peasant_Feet"]
const MONTERO := ["Ranger_Body", "Ranger_Arms", "Ranger_Legs"]

## `tinte` multiplica el color del atuendo. El pack es de fantasía medieval —lana verdosa y
## cuero— y el juego empieza en el Magdaleniense: teñir a cuero crudo y pardo es lo que más
## acerca lo que hay a lo que toca, y no cuesta un triángulo.
const CONJUNTOS := {
	Site.Era.PALEOLITICO: {
		"nombre": "pieles curtidas",
		"piezas": ALDEANO,
		"tinte": Color(0.72, 0.56, 0.40),   ## Cuero sin teñir, sebo y humo
	},
	Site.Era.MESOLITICO: {
		"nombre": "piel cosida y calzado",
		"piezas": MONTERO,
		"tinte": Color(0.78, 0.63, 0.45),
	},
	Site.Era.NEOLITICO: {
		"nombre": "tejido de lino",
		"piezas": ALDEANO,
		"tinte": Color(1.05, 1.02, 0.92),   ## Lino crudo: casi sin teñir, pero más claro
	},
	Site.Era.METALES: {
		"nombre": "lana teñida y capa",
		"piezas": MONTERO,
		"tinte": Color(0.95, 0.72, 0.62),   ## Rubia y granza
	},
	Site.Era.HISTORICA: {
		"nombre": "saya y manto",
		"piezas": MONTERO,
		"tinte": Color(0.72, 0.74, 0.88),   ## Paño pardo azulado
	},
}

## Los pelos del pack, por sexo. Son los que hay; el reparto es sorteo, no decisión.
const PELOS := {
	CatalogoDeCuerpos.Sexo.HOMBRE: ["Hair_Long", "Hair_Buzzed", "Hair_SimpleParted"],
	CatalogoDeCuerpos.Sexo.MUJER: ["Hair_Long", "Hair_Buns", "Hair_BuzzedFemale"],
}
## La barba se sortea aparte y sólo a los hombres adultos.
const BARBA := "Hair_Beard"

## Los colores de pelo que se sortean. La textura del pack es casi blanca a propósito, para
## poder teñirla; sin esto la banda entera sale canosa.
const PELAJES := [
	Color(0.16, 0.12, 0.09),   ## Negro
	Color(0.28, 0.19, 0.12),   ## Castaño oscuro
	Color(0.42, 0.30, 0.18),   ## Castaño
	Color(0.55, 0.36, 0.20),   ## Rojizo
	Color(0.72, 0.70, 0.68),   ## Cano: los viejos de la banda
]


## QUIÉN DE LA BANDA VA VESTIDO HOY, por índice en `people`.
##
## **El vestido no es de nadie**: la simulación lleva un número en el utillaje
## (`Tool.Kind.VESTIDO`) y lo dice explícitamente —«cobertura AGREGADA, no se sabe ni hace
## falta saber quién lleva cuál», `SettlementSim.vestido_coverage`—. Así que quién se dibuja
## vestido es una decisión **de la vista**, y ésta: **primero los que salen del campamento**,
## porque el frío se pasa fuera y porque así se lee de un vistazo quién va abrigado al tajo.
## Decisión del usuario del 2026-09-18.
##
## Si sobran vestidos después de abrigar a los que salen, se quedan los de dentro. Si
## faltan, van por orden de banda, que es estable: sin eso la ropa cambiaría de dueño cada
## cuadro y la gente parpadearía.
##
## Antes de esto **la banda salía vestida siempre**, incluso el día 1, que es cuando el
## utillaje tiene cero vestidos y la propia barra superior pone «sin vestidos».
static func quien_va_vestido(gente: Array, cuantos: int) -> PackedByteArray:
	var puestos := PackedByteArray()
	puestos.resize(gente.size())
	puestos.fill(0)
	var quedan := mini(cuantos, gente.size())
	# Dos vueltas: la primera reparte entre los que están fuera, la segunda entre el resto.
	for fuera: bool in [true, false]:
		for i in range(gente.size()):
			if quedan <= 0:
				return puestos
			if puestos[i] == 1:
				continue
			var persona: Object = gente[i]
			var esta_fuera: bool = ClipsDeLaBanda.FUERA_DEL_CAMPAMENTO.has(
				int(persona.get("state")))
			if esta_fuera != fuera:
				continue
			puestos[i] = 1
			quedan -= 1
	return puestos


static func conjunto(era: Site.Era) -> Dictionary:
	return CONJUNTOS.get(era, CONJUNTOS[Site.Era.PALEOLITICO])


## Las piezas de ropa de una era, con el nombre completo del fichero.
static func piezas(era: Site.Era, sexo: int) -> PackedStringArray:
	var out := PackedStringArray()
	for pieza: String in conjunto(era)["piezas"]:
		out.append("%s_%s" % [CatalogoDeCuerpos.sufijo(sexo), pieza])
	return out


static func tinte(era: Site.Era) -> Color:
	return conjunto(era)["tinte"]
