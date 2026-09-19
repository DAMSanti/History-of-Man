class_name ClipsDeLaBanda
## QUÉ SE VE HACIENDO CADA PERSONA: el gesto que hace y el apero que lleva en la mano.
##
## La tabla vivía dentro de [BandaCrowd] como `STATE_CLIP` —ocho estados a siete clips
## genéricos, con los estados escritos como números sueltos— y el resultado era que tallar
## cuarcita, raspar una piel y avivar el fuego **eran el mismo bucle**. Está aquí porque
## [BandaCrowd] dibuja y no decide, y porque esto es una tabla de datos del juego.
##
## Los gestos salen de la biblioteca CC0 «Universal Animation Library» (45 clips; ver
## `docs/CREDITOS.md`). No hay ninguno de tallar sílex —no existe en ningún pack libre—, así
## que cada oficio usa **el gesto real que más se le parece**, y lo que remata la lectura es
## el apero: arrodillarse a golpear con un percutor en la mano es tallar, y el mismo
## arrodillarse con un raspador es curtir.
##
## GRAFICOS §5.1.

## Manos vacías, **y a propósito**. No es lo mismo que no tener entrada en la tabla: quien
## cuida a un crío o bate el monte no lleva nada, y la prueba distingue las dos cosas.
const SIN_APERO := ""

## Los estados en que da igual el oficio: andar es andar.
const POR_ESTADO := {
	## No hay clip de dormir tumbado en la biblioteca. Sentado y quieto es lo que hace una
	## banda que duerme al raso o en la boca de la cueva, y es mejor que estar de pie.
	Inhabitant.State.DURMIENDO: "Sitting_Idle",
	Inhabitant.State.YENDO: "Walk",
	## Prospectar es ir mirando el suelo, no marchar: agachado y avanzando.
	Inhabitant.State.BUSCANDO: "Crouch_Fwd",
	Inhabitant.State.TRABAJANDO: "Fixing_Kneeling",
	Inhabitant.State.VOLVIENDO: "Walk",
	## Comer es lo más social del día: sentados y hablando.
	Inhabitant.State.COMIENDO: "Sitting_Talking",
	Inhabitant.State.OCIOSO: "Idle_Talking",
	## Batir la comarca se hace a paso vivo, que para eso es un día entero fuera.
	Inhabitant.State.RECONOCIENDO: "Jog_Fwd",
}

## Y el gesto de cada oficio, que es lo que manda cuando se está TRABAJANDO.
const POR_ESPECIALIDAD = {
	Profession.Speciality.NINGUNA: "Interact",
	## Manufactura: arrodillado y trabajando con las manos. Lo que cambia es el apero.
	Profession.Speciality.TALLA: "Fixing_Kneeling",
	Profession.Speciality.ASTA: "Fixing_Kneeling",
	Profession.Speciality.PELETERIA: "Fixing_Kneeling",
	## Torcer fibra se hace sentado, con las manos y sin herramienta.
	Profession.Speciality.CORDELERIA: "Sitting_Idle",
	## Exploración: batir es ir agachado leyendo el rastro; una expedición es marchar.
	Profession.Speciality.BATIDA: "Crouch_Fwd",
	Profession.Speciality.EXPEDICION: "Walk",
	Profession.Speciality.ASCENSION: "Sprint",
	## Recolección: agacharse y coger.
	Profession.Speciality.FORRAJEO: "PickUp_Table",
	Profession.Speciality.LENA_FIBRA: "PickUp_Table",
	Profession.Speciality.CANTERA: "Fixing_Kneeling",
	## Caza: la trampa se arma en cuclillas y quieto; la res se cobra de una lanzada.
	Profession.Speciality.TRAMPAS: "Crouch_Idle",
	Profession.Speciality.CAZA_MENOR: "Crouch_Idle",
	Profession.Speciality.CAZA_MAYOR: "Sword_Attack",
	## Ribera: el marisqueo es agacharse en la roca; el arpón es otra lanzada.
	Profession.Speciality.MARISQUEO: "Crouch_Idle",
	Profession.Speciality.ORILLA: "Sword_Attack",
	Profession.Speciality.ALTURA: "Push",
	## Hogar: el que ceba el fuego lleva una tea; el secadero es trabajo de manos.
	Profession.Speciality.YESQUERO: "Idle_Torch",
	Profession.Speciality.AHUMADO: "Fixing_Kneeling",
	## Cuidar es estar sentado con quien no se vale solo.
	Profession.Speciality.CUIDADO: "Sitting_Talking",
}

## QUÉ LLEVA EN LA MANO cada especialidad. El criterio es el de §6: **arponear y forrajear
## no pueden leerse igual**, y con once gestos para veinte oficios el apero es lo que acaba
## de separarlos.
##
## Las manos vacías son una decisión, no un hueco: quien bate el monte va mirando, quien
## sube a lo alto usa las dos manos, y quien cuida lleva a alguien.
const APEROS := {
	Profession.Speciality.NINGUNA: SIN_APERO,
	Profession.Speciality.TALLA: "percutor",     ## El canto con que se golpea el núcleo
	Profession.Speciality.ASTA: "buril",
	Profession.Speciality.PELETERIA: "raspador",
	Profession.Speciality.CORDELERIA: SIN_APERO, ## Se tuerce fibra con las manos
	Profession.Speciality.BATIDA: SIN_APERO,     ## Va mirando, no cargado
	Profession.Speciality.EXPEDICION: "cesto",   ## Las provisiones de varios días
	Profession.Speciality.ASCENSION: SIN_APERO,  ## Subir pide las dos manos
	Profession.Speciality.FORRAJEO: "cesto",
	Profession.Speciality.LENA_FIBRA: "haz",
	Profession.Speciality.CANTERA: "cesto",      ## Se baja piedra y ocre a peso
	Profession.Speciality.TRAMPAS: SIN_APERO,    ## Un lazo es cordel: no se ve a esta escala
	Profession.Speciality.CAZA_MENOR: "azagaya",
	Profession.Speciality.CAZA_MAYOR: "azagaya",
	Profession.Speciality.MARISQUEO: "cesto",
	Profession.Speciality.ORILLA: "arpon",
	Profession.Speciality.ALTURA: "arpon",
	Profession.Speciality.YESQUERO: "tea",       ## El gesto ya es el de sostenerla
	Profession.Speciality.AHUMADO: "haz",
	Profession.Speciality.CUIDADO: SIN_APERO,    ## Lleva a alguien, no una herramienta
}

## EN QUÉ ESTADOS ESTÁ FUERA DEL CAMPAMENTO. Contesta dos preguntas a la vez, y son la
## misma: si se le ve el apero en la mano —llevar la azagaya de camino al tajo es la mitad
## de lo que hace legible una cuadrilla de caza; llevarla dormido o cenando sería ruido— y
## **si le toca uno de los vestidos que haya**, porque el frío se pasa fuera. Ver
## [Vestuario.quien_va_vestido].
const FUERA_DEL_CAMPAMENTO := [
	Inhabitant.State.YENDO,
	Inhabitant.State.BUSCANDO,
	Inhabitant.State.TRABAJANDO,
	Inhabitant.State.VOLVIENDO,
	Inhabitant.State.RECONOCIENDO,
]


## El gesto que toca. El oficio sólo manda TRABAJANDO: andar es andar, lo haga quien lo haga.
static func clip(estado: int, especialidad: int, sentado: bool = false) -> String:
	if estado == Inhabitant.State.TRABAJANDO:
		return POR_ESPECIALIDAD.get(especialidad, "Fixing_Kneeling")
	# EN EL TRONCO, SENTADO. El corro del fuego es el sitio social del campamento —comer y
	# dormir ya se hacían sentados—, así que el ocio de quien tiene sitio en un leño es
	# sentarse a hablar y no quedarse de pie manoseándose las manos encima del banco. Quién
	# está en el tronco lo contesta [CorroDelHogar.sentado]; aquí sólo se elige el gesto.
	if sentado and estado == Inhabitant.State.OCIOSO:
		return "Sitting_Talking"
	return POR_ESTADO.get(estado, "Idle")


## Qué lleva en la mano, o [constant SIN_APERO] si no lleva nada.
static func apero(estado: int, especialidad: int) -> String:
	if not FUERA_DEL_CAMPAMENTO.has(estado):
		return SIN_APERO
	return APEROS.get(especialidad, SIN_APERO)
