class_name Hunt
extends RefCounted
## Una cacería en marcha: el acecho, la persecución, el lance y el despiece.
##
## Es la petición literal —«toda caza que no sea sorpresiva quiero que se
## reproduzca en el juego, es decir quiero ver a los cazadores acechar,
## perseguir, cazar a su presa»— y de paso arregla algo que estaba mal de
## fondo: la caza era una tabla de rendimiento. El cazador se plantaba en su
## paraje, corrían las horas y aparecía carne en el zurrón. Los ciervos que
## [WildlifeHerds] pinta cruzando el valle no tenían nada que ver con eso: eran
## decorado, y la caza era aritmética.
##
## Aquí la pieza es UN ANIMAL DE LOS QUE HAY. Se elige el que anda cerca, se le
## entra, se le sigue si arranca y se le remata o se le pierde. Lo que llega al
## almacén sale de esa pieza y no de una media.
##
## **Lo que se queda fuera, y no es un olvido:** la TRAMPA. El encargo dice «la
## caza que no sea sorpresiva», y una trampa es exactamente lo sorpresivo: cae
## sola mientras la banda duerme y no hay acecho que mirar. Sigue como estaba,
## en `SettlementSim._trapline`.
##
## Las fases van en este orden y sólo hacia adelante, salvo el lance fallado,
## que devuelve a la persecución mientras quede fuelle.

enum Phase {
	ACECHO,        ## Acercarse sin que lo note. Lo más largo y lo más callado
	PERSECUCION,   ## Ya lo ha notado y ha arrancado: ahora es una carrera
	LANCE,         ## A tiro. Una tirada, y de ahí sale todo
	DESPIECE,      ## Cobrada y en el suelo: hay que abrirla donde cayó
	ACARREO,       ## Despiezada, con más de lo que cabe en una espalda
	FALLIDA,       ## Se ha perdido. Pasa, y pasa mucho
}

## A qué distancia se le puede tirar, por arma, en metros.
##
## No es un ajuste: es el alcance útil de cada cosa, que es de lo poco de esta
## época que se puede medir. Una azagaya de mano se tira a quince metros largos
## y con propulsor se dobla —eso es lo que hace un propulsor, y por eso está en
## [Hunting.MEJORAS]—; una lanza de mano no se tira, se clava, así que hay que
## estar encima; y sin nada hay que llegar a tocarla, que es por lo que sólo se
## coge lo que no corre.
const ALCANCE := {
	Tool.Kind.AZAGAYA: 16.0,
	Tool.Kind.PUNTA: 6.0,
}
const ALCANCE_A_MANO := 3.0

## Lo que multiplica el propulsor al alcance. Es su razón de ser.
const PROPULSOR_ALCANCE := 2.0

## Radio en el que se busca pieza alrededor del tajo, en metros.
##
## Amplio: un cazador no caza donde se planta, caza donde está el animal, y el
## animal se mueve. Es el radio de una mañana de monte, no el del brazo.
const BUSCA_PIEZA_M := 260.0

## Hasta dónde se sigue una pieza antes de darla por perdida. Más allá de esto
## ya no es perseguir, es andar detrás de un rastro frío.
const PIERDE_M := 320.0

## A partir de qué distancia se acecha de verdad, en metros.
##
## Antes de eso se ANDA, al paso de todo el mundo. Nadie cruza dos kilómetros
## agachado: se va al sitio, y el acecho empieza cuando la pieza ya puede oírte.
##
## Y no es sólo verosimilitud, es que sin esto no cuadraban los tiempos: a un
## tercio del paso normal, cubrir los doscientos sesenta metros del radio de
## busca cuesta cinco horas de jornada, o sea el doble de lo que dura un acecho
## entero -[ACECHO_HORAS]-. La cuadrilla se quedaba sin día antes de llegar.
const ACECHO_DESDE := 90.0

## Horas de acecho antes de dar el rastro por frío.
##
## Dos horas y media. Un acecho de verdad es largo —de eso va— pero no es
## infinito, y sin este corte no lo era: la pieza se mueve, al cazador se le
## hace de noche y a la mañana siguiente seguía tras un animal que se había ido
## al otro lado del valle. Medido con `CaceriaProbe`, 591.631 ticks en acecho
## contra 133 lances.
const ACECHO_HORAS := 2.5

## Horas de carrera que aguanta una persecución antes de dejarlo.
##
## La caza por agotamiento —seguir a un ungulado hasta que revienta de calor—
## existe y está documentada, pero es de sabana abierta y de mediodía: en un
## valle cantábrico con bosque el animal se pierde de vista mucho antes. Lo que
## decide aquí no es el fondo del cazador, es que el monte se lo traga.
##
## Estuvo en tres cuartos de hora y era demasiado poco: medido con
## `CaceriaProbe`, ochenta y tres cacerías levantadas y setenta y siete
## perdidas —una cobrada de ochenta y tres—. Hora y cuarto deja llegar a tiro a
## quien ya venía cerca cuando la pieza arrancó, que es de lo que va perseguir.
const FUELLE_HORAS := 1.25

## Probabilidad por HORA de acecho de que la pieza levante la cabeza, PEGADO A
## ELLA. De lejos baja con la distancia, que es lo suyo.
##
## Que la note NO es que se acabe la caza: es que se pasa a perseguirla, que
## rinde menos y cansa mucho más. La diferencia entre un buen cazador y uno
## malo es sobre todo cuántas veces llega a tiro sin que le vean.
##
## Estuvo en 2,4 y era una cifra sin medir. Un acecho es de un par de horas, y
## con 2,4 por hora la pieza levantaba la cabeza SIEMPRE: en la partida de
## prueba se llegó a tiro cuatro ticks en ciento veinte jornadas. Con 0,45, un
## acecho de dos horas se descubre algo menos de la mitad de las veces, que es
## lo que hace que acechar bien signifique algo.
const NOTA_POR_HORA := 0.45

## A partir de cuántas veces el alcance del arma empieza a notarte la pieza.
##
## Antes el factor era `alcance * 3 / distancia` recortado a uno, y con un
## alcance de treinta metros eso daba UNO a noventa: o sea que acercarse desde
## doscientos metros era tan peligroso como estar encima. Un ciervo no ve igual
## a diez metros que a doscientos.
const SE_NOTA_A := 1.5

## Y a cuántas veces el alcance se puede tirar a la carrera.
##
## Más lejos que a la parada -[reach_of]- porque quien persigue tira a lo que
## sea antes de perderla, no espera a la distancia buena. Lo paga en el lance:
## sin la sorpresa de [SORPRESA], que es lo que de verdad decide.
const TIRO_A_LA_CARRERA := 1.6

## Cuánto tapa el ojeo. Batir con un plan es, literalmente, que la pieza no
## sepa por dónde le viene: unos la levantan y la conducen, otros esperan en el
## paso. Ver [TechTree.Tech.OJEO].
const OJEO_SIGILO := 0.55

## Probabilidad base de acertar el lance, antes de destreza y cuadrilla.
##
## Cazar es fallar, y esta cifra es la que lo dice. Con destreza media y una
## cuadrilla de cuatro sale algo por encima de la mitad; solo y torpe, uno de
## cada cuatro.
const LANCE_BASE := 0.42

## Y lo que suma llegar a tiro SIN QUE TE VEAN, que es de lo que va el acecho.
## Una pieza parada y de costado no es la misma pieza que una que ya corre.
const SORPRESA := 1.7

## Jornadas de despiece por ración de la pieza.
##
## Un ciervo son unas cuatro horas de dos personas con filo: abrir, desollar,
## descuartizar y separar lo que se lleva de lo que se deja. Sale de las
## raciones y no de una tabla por especie porque es lo mismo: lo que cuesta
## abrir un animal es proporcional a lo que tiene dentro.
const DESPIECE_POR_RACION := 0.006

## Por debajo de estas raciones, la pieza se lleva ENTERA al abrigo.
##
## Aquí está la respuesta a «¿qué harían: llevarla a casa o despiezarla en el
## terreno?», y la respuesta es LAS DOS COSAS, según el tamaño. Es el efecto
## `schlepp`, que es de lo mejor documentado que hay en zooarqueología: en los
## abrigos aparecen esqueletos casi completos de pieza pequeña y perfiles
## sesgados a las partes buenas de la grande, porque lo pequeño se echa al
## hombro y lo grande se abre donde cae y se acarrea por partes. Veinte
## raciones son un corzo: una espalda.
const CARGA_ENTERA := 20.0

## Jornadas que aguanta lo despiezado en el suelo antes de perderse.
##
## No es sólo que se pudra: es que hay lobos, y una res abierta en el monte se
## anuncia sola. Tres días es generoso; lo que hace es dar tiempo a volver a
## por lo que no cupo, que es de lo que va dejar la pieza en el terreno.
const DIAS_EN_EL_SUELO := 3.0


var phase: Phase = Phase.ACECHO

## La especie y el animal concreto de [WildlifeHerds] al que se le va. Es el
## MISMO diccionario que lleva la fauna, no una copia: por eso `where()` sabe
## dónde está ahora y no dónde estaba cuando empezó todo.
var species: String = ""
var quarry: Dictionary = {}

## Quién anda en ella. La primera es la que la levantó.
var crew: Array[Inhabitant] = []

## Horas gastadas en la fase de ahora.
var spent: float = 0.0

## Lo que se lleva corrido detrás de la pieza. Ver [FUELLE_HORAS].
var chased: float = 0.0

## Dónde cayó, y lo que queda en el suelo sin acarrear.
var kill_site: Vector3 = Vector3.ZERO
var spoils: Dictionary = {}

## Jornadas que lleva lo despiezado en el monte.
var days_out: float = 0.0

## Con qué se le entró, para poder contarlo. -1 si a mano.
var weapon: int = -1

## Si llegó a tiro sin que lo vieran. Decide el lance y además es la mitad de
## la historia que se cuenta luego junto al fuego.
var unseen: bool = true

## Jornada en que se cobró, para la crónica y el relato.
var day: int = 0


## Dónde está la pieza AHORA. Mientras esté viva es donde ande; una vez cobrada,
## donde cayó.
func where() -> Vector3:
	if phase == Phase.DESPIECE or phase == Phase.ACARREO \
			or phase == Phase.FALLIDA:
		return kill_site
	if quarry.has("position"):
		return quarry["position"]
	return kill_site


## A qué distancia se le puede tirar con lo que se lleva.
static func reach_of(weapon_kind: int, techs: TechTree) -> float:
	if weapon_kind < 0:
		return ALCANCE_A_MANO
	var reach: float = float(ALCANCE.get(weapon_kind, ALCANCE_A_MANO))
	if weapon_kind == Tool.Kind.AZAGAYA and techs != null \
			and techs.has(TechTree.Tech.PROPULSOR):
		reach *= PROPULSOR_ALCANCE
	return reach


## Si esta pieza se lleva entera al abrigo o se abre donde cayó.
static func butchered_in_field(species_key: String) -> bool:
	return Fauna.rations_of(species_key) > CARGA_ENTERA


## Jornadas de trabajo que cuesta abrirla.
static func butcher_days(species_key: String) -> float:
	return Fauna.rations_of(species_key) * DESPIECE_POR_RACION


## Todo lo que sale de la pieza: la carne en unidades y el despiece.
##
## En UNIDADES de material y no en raciones, que es como entra en el almacén.
## La carne se convierte de raciones a unidades con la nutrición del material,
## que es lo que hace que una ración signifique lo mismo aquí que en la
## despensa.
static func spoils_of(species_key: String) -> Dictionary:
	var out: Dictionary = {}
	var rations := Fauna.rations_of(species_key)
	if rations > 0.0:
		out[int(Materia.Kind.CARNE)] = rations / maxf(
			Materia.nutrition(Materia.Kind.CARNE), 0.001)
	var rest := Fauna.spoils_of(species_key)
	for kind: int in rest:
		out[kind] = float(out.get(kind, 0.0)) + float(rest[kind])
	return out


## Lo que queda por acarrear, en kilos. Es lo que decide si hace falta volver.
func spoils_kg() -> float:
	var kg := 0.0
	for kind: int in spoils:
		kg += float(spoils[kind]) * Materia.kg_per_unit(kind as Materia.Kind)
	return kg


func is_over() -> bool:
	return phase == Phase.FALLIDA or (phase == Phase.ACARREO and spoils.is_empty())


## En qué anda, dicho para leerlo. Es lo que sale sobre la cabeza del cazador.
func doing_text() -> String:
	match phase:
		Phase.ACECHO:
			return "acechando %s" % Fauna.species_name(species).to_lower()
		Phase.PERSECUCION:
			return "tras %s" % Fauna.species_name(species).to_lower()
		Phase.LANCE:
			return "a tiro de %s" % Fauna.species_name(species).to_lower()
		Phase.DESPIECE:
			return "despiezando %s" % Fauna.species_name(species).to_lower()
		Phase.ACARREO:
			return "acarreando %s" % Fauna.species_name(species).to_lower()
		_:
			return "se le fue %s" % Fauna.species_name(species).to_lower()


static func create(species_key: String, animal: Dictionary,
		who: Inhabitant) -> Hunt:
	var hunt := Hunt.new()
	hunt.species = species_key
	hunt.quarry = animal
	hunt.crew = [who]
	hunt.kill_site = animal.get("position", who.position)
	return hunt
