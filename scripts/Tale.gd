class_name Tale
extends RefCounted
## Lo que se cuenta al volver: la cacería, el hallazgo, lo que se ha aprendido.
##
## Una banda del Paleolítico no lleva libros de cuentas. Lo que sabe lo sabe
## porque alguien lo cuenta, y lo cuenta junto al fuego cuando vuelve. El juego
## ya tenía la mitad de eso —[SettlementSim._knowledge_transmission] acerca cada
## noche a los que están en la cueva a lo que sabe el mejor de ellos— pero era
## un número que subía en silencio: el jugador no veía nunca el relato, sólo el
## efecto.
##
## Un relato es ese momento hecho cosa. Se levanta cuando pasa algo que merece
## contarse, se le enseña al jugador —ver [Moment]— y, si la banda sabe pintar y
## tiene con qué, se puede PONER EN LA PARED.
##
## **Y ahí está la diferencia que importa.** Un relato contado dura lo que dura
## quien lo cuenta: se transmite mientras haya alguien que estuviera allí. Uno
## pintado no. Eso no es una metáfora bonita, es lo que dice
## [TechTree.Tech.ARTE] con todas las letras —«fijar lo que se sabe de los
## animales y transmitirlo a quien no estaba: es la primera tecnología de la
## memoria»— y es exactamente lo que hace en la partida: sube el techo de lo que
## se puede aprender de oídas sobre ESA tarea, para siempre y aunque se muera
## todo el que estuvo. Ver `SettlementSim.paintings_ceiling`.

enum Kind {
	CACERIA,    ## Una pieza mayor cobrada. La que de verdad se cuenta
	HALLAZGO,   ## Un sitio nuevo, una cumbre, una cueva
	TECNICA,    ## Se ha aprendido a hacer algo que antes no se sabía
	HITO,       ## Lo demás que marca un antes y un después
}

var kind: Kind = Kind.CACERIA

## Titular corto y cuerpo. Se redactan al levantarlo, con los datos de lo que
## acaba de pasar: quién, qué, dónde. No hay plantillas guardadas por ahí.
var title: String = ""
var text: String = ""

## Quién lo protagoniza, si es de alguien.
var who: String = ""

## De qué va, en clave y no en prosa: la especie de la pieza, el nombre de la
## técnica. El título lleva además el sitio —«Uro en el Vado Alto»— y por eso no
## sirve para saber si ya se ha contado un uro alguna vez.
var subject: String = ""

## Dónde pasó.
var where: Vector3 = Vector3.ZERO

## Jornada en que pasó.
var day: int = 0

## De qué TAREA habla, en la clave de [Profession.task_id].
##
## Es lo que decide qué se aprende mirando la pared: una escena de caza mayor
## enseña a cazar, no a trenzar cordel. -1 si no habla de ninguna.
var task: int = -1

## Si está pintado, y en qué jornada.
var painted: bool = false
var painted_day: int = 0


## Si esto se puede poner en la pared.
##
## No todo se pinta, y eso también es fiel: en las cuevas cantábricas hay
## bisontes, ciervos, caballos y manos, no inventarios. Lo que se pinta es lo
## que la banda considera que hay que fijar, y aquí eso son las cacerías
## grandes, los hallazgos y lo que se aprende a hacer.
func paintable() -> bool:
	return task >= 0


## Cómo se cuenta la fecha, para la ficha de la pared.
func stamp() -> String:
	return "Jornada %d" % day


static func hunt(person_name: String, species: String, place: String,
		crew_size: int, unseen: bool, when: int, task_id: int) -> Tale:
	var tale := Tale.new()
	tale.kind = Kind.CACERIA
	tale.who = person_name
	tale.subject = species
	tale.day = when
	tale.task = task_id
	tale.title = "%s en %s" % [Fauna.species_name(species), place]

	# El cómo importa más que el qué, que es lo que hace que sea un relato y no
	# una entrada de almacén: no es lo mismo llegar a tiro sin que te vean que
	# reventar el monte detrás de la pieza hasta acorralarla.
	var como := "Le llegaron encima sin que levantara la cabeza." if unseen \
		else "Los vio venir y hubo que correr detrás de %s hasta acorralarla." \
			% ("él" if crew_size > 1 else "ella")
	var quien := "%s y otros %d" % [person_name, crew_size - 1] \
		if crew_size > 1 else person_name
	tale.text = "%s trajo %s de %s. %s" % [quien,
		Fauna.species_name(species).to_lower(), place, como]
	return tale


static func discovery(title_text: String, body: String, place: Vector3,
		when: int, task_id: int) -> Tale:
	var tale := Tale.new()
	tale.kind = Kind.HALLAZGO
	tale.title = title_text
	tale.text = body
	tale.where = place
	tale.day = when
	tale.task = task_id
	return tale


static func technique(tech: TechTree.Tech, when: int, task_id: int) -> Tale:
	var tale := Tale.new()
	tale.kind = Kind.TECNICA
	tale.subject = TechTree.tech_name(tech)
	tale.title = TechTree.tech_name(tech)
	tale.text = "Ya se sabe hacer. %s" % TechTree.tech_desc(tech)
	tale.day = when
	tale.task = task_id
	return tale
