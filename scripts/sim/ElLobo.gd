class_name ElLobo
extends RefCounted
## El trato con los lobos, que acaba en perro o acaba en enemigo.
##
## No es una técnica que se aprenda con jornadas: es una RELACIÓN que se
## construye o se rompe a lo largo de la partida, decisión a decisión, y en la
## que se puede perder. Un lobo no se domestica investigando.
##
## ## Por qué empieza en el montón de basura
##
## La hipótesis que hoy tiene más apoyo no es la del cazador que sale a buscar
## un cachorro: es la COMENSAL. Los lobos menos miedosos se acercaron solos a
## los desperdicios de los campamentos humanos, comieron mejor que los demás,
## criaron más, y la selección hizo el resto. La domesticación no la empezó la
## gente: la empezaron los lobos.
##
## Así que aquí arranca en el [Conchero]. Sin montón no hay lobos merodeando y
## sin lobos merodeando no hay camino, y eso encadena dos sistemas que si no
## serían dos adornos sueltos: la basura que la banda genera es lo que trae al
## animal que va a cambiarle la caza.
##
## Está atestiguado en Europa hacia 15.000–14.000 a.C. —Bonn-Oberkassel, el
## enterramiento de perro más antiguo aceptado— así que cae DENTRO del
## Magdaleniense que juega la slice. No hay que estirar nada.
##
## ## Los cinco pasos
##
## Cada uno es un [Moment] con opciones de verdad, y el reloj se para hasta que
## el jugador elija. Ninguna opción es gratis:
##
##   1. MERODEAN     los lobos vienen al montón de noche
##   2. UNO_SE_QUEDA uno deja de huir cuando alguien sale
##   3. LA_CAMADA    aparece una lobera cerca
##   4. EL_CACHORRO  ciento veinte jornadas de cría, y come
##   5. EL_PERRO     caza con la cuadrilla
##
## ## Y el otro final
##
## El [trato] baja con cada pedrada y cada lobo muerto. Por debajo de
## [ENEMIGO], la manada aprende que el campamento es peligroso y se comporta
## como tal: ronda los vivacs y roba de las matanzas. Eso NO es un castigo por
## jugar mal —matar al lobo que te ronda la despensa es razonable— es la otra
## rama, y tiene su propio sentido.
##
## Ver docs/PERRO_Y_BELLOTA.md.

## De -100 a 100. Cero es indiferencia: ni te conocen ni te temen.
##
## Las cifras de cuánto mueve cada cosa son de balanceo y quedan abiertas a
## playtest; lo que no es de balanceo es el SIGNO de cada una.
var trato: float = 0.0

const TRATO_TOPE := 100.0
const ENEMIGO := -45.0

## Cuánto trato hace falta para cada paso.
const PARA_QUE_SE_QUEDE := 25.0
const PARA_LA_CAMADA := 55.0

## Cuántas noches de merodeo hacen falta antes de que valga la pena mirarlo.
##
## Seis, y no una: un lobo que pasa una noche es un lobo que pasaba por ahí.
## Lo que cambia algo es que vuelvan.
const NOCHES_PARA_EMPEZAR := 6

## Desde cuántos litros de montón empiezan a venir. Por debajo no hay bastante
## que rebañar para que a un lobo le compense el riesgo. Ver [Desechos.SE_VE].
const MONTON_QUE_ATRAE := 250.0

## Jornadas de cría. El DOBLE que ninguna técnica del árbol, y a propósito: un
## perro no se aprende, se cría, y hay que llegar al final con él vivo.
const CRIA_JORNADAS := 120.0

## Lo que come, en raciones al día. Lo que come un crío.
##
## Es lo que convierte tener perro en una decisión y no en un regalo: una boca
## más que no recolecta ni talla. Con esto, sale a cuenta sólo si la banda caza
## de verdad, que es justo la decisión que se quiere provocar.
const COME_AL_DIA := 0.6

## Cuánto sube el trato por dejarles comer una noche.
const POR_DEJARLES := 3.0

## Y cuánto sube por CADA NOCHE que vienen sin que nadie les tire una piedra.
##
## Sin esto el camino no se puede andar, y no es una suposición: `PerroProbe`
## lo midió. Eligiendo siempre lo amable, las dos decisiones que hay antes de
## la camada suman 24 de trato y la camada pide 55. Faltaban 31 que no salían
## de ninguna parte.
##
## Y salir de aquí es además lo correcto: la relación no la hacen los gestos,
## la hace el TIEMPO. Los lobos que se acercaron a los campamentos no lo
## hicieron porque alguien les echara una tajada, lo hicieron porque durante
## generaciones no pasó nada malo. Nueve décimas por noche: en las treinta y
## seis noches que pide el paso son 32, que es justo lo que faltaba.
const POR_NOCHE := 0.9

## Y cuánto baja por espantarlos o por matar a uno.
const POR_ESPANTAR := -6.0
const POR_MATAR := -35.0

## Cuánto multiplica el rencor cada lobo muerto al siguiente.
##
## Hace falta porque sin él el camino del enemigo NO EXISTE, y tampoco es una
## suposición: `PerroProbe` recorrió cuatrocientas jornadas matando en cada
## decisión y la manada acabó con el trato a 100. Cada muerte quitaba 35 y las
## noches de merodeo los devolvían a nueve décimas por noche, así que el pozo
## se rellenaba antes de la siguiente.
##
## Y multiplicar es lo correcto: la primera vez es un lobo muerto, la segunda
## es un patrón. Lo que aprende una manada no es la cuenta, es que ese sitio
## mata.
const RENCOR := 1.8

## A partir de cuántos muertos la manada está en contra pase lo que pase.
##
## Dos. Uno se puede explicar; dos es lo que sois. Con `trato` solo no bastaba
## -ver [RENCOR]- y una hostilidad que se levanta sola en veinte noches no es
## un final, es un tropiezo.
const MUERTOS_QUE_NO_SE_OLVIDAN := 2
const OLVIDO_JORNADAS := 180

## Cada cuántas jornadas sin matar a ninguno se olvida uno.
##
## Ciento ochenta: un año de partida entero por cada lobo. Es recuperable, que
## es lo que lo separa de un callejón sin salida, pero cuesta lo que tiene que
## costar.

## Qué probabilidad tiene el perro de cortar un rastro que ya se había perdido.
##
## Es el efecto grande y es el que ataca el problema medido: de quince cacerías
## levantadas sólo se cobran cuatro, y el 73 % se pierde en el acecho —«se
## enfrió el rastro», «se fue de vista»—. Un perro no mata la pieza: la
## ENCUENTRA y la PARA hasta que llegas.
const CORTA_EL_RASTRO := 0.55

## Cuánto alarga el fuelle de la persecución: el perro la entretiene mientras
## el cazador llega.
const FUELLE_EXTRA := 1.6

## Y cuánto baja el riesgo del vivac: a un campamento con perro no lo
## sorprenden de noche.
const VIVAC_MAS_SEGURO := 0.55

## Cuánto sube el riesgo del vivac con la manada en contra, por lo mismo al
## revés.
const VIVAC_CON_ENEMIGOS := 1.9

enum Paso { LEJOS, MERODEAN, UNO_SE_QUEDA, LA_CAMADA, EL_CACHORRO, EL_PERRO }

var paso: Paso = Paso.LEJOS

## Noches seguidas en que han venido al montón.
var noches: int = 0

## Cuántos lobos ha matado la banda, y cuánto lleva sin matar ninguno.
var muertos: int = 0
var sin_matar: float = 0.0

## Jornadas que lleva criándose el cachorro, si lo hay.
var cria: float = 0.0

## Si hay cachorro en el campamento ahora mismo.
var cachorro: bool = false

## Si el perro ya caza con la cuadrilla.
var perro: bool = false

## Si ya se ha decidido este paso, para no volver a preguntar lo mismo.
var _preguntado: Dictionary = {}

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Si la manada está en contra.
##
## Por el trato O por la cuenta de muertos, y las dos hacen falta: el trato
## solo se recuperaba con las noches de merodeo antes de la siguiente muerte, y
## la cuenta sola no dejaría enemistarse sin matar a nadie.
func hostil() -> bool:
	return trato <= ENEMIGO or muertos >= MUERTOS_QUE_NO_SE_OLVIDAN


## Apunta un lobo muerto. Cada uno cuesta más que el anterior. Ver [RENCOR].
func matar() -> void:
	trato += POR_MATAR * pow(RENCOR, float(muertos))
	muertos += 1
	sin_matar = 0.0
	_volver_a_empezar()


## Los echa y el camino vuelve al principio. Pero VUELVEN.
##
## Es lo que hacía falta para que el camino del enemigo exista: los momentos se
## preguntaban una sola vez —`_ya`— así que en toda la partida había DOS
## ocasiones de matar un lobo, y con dos no se llega a manada hostil. Medido con
## `PerroProbe`: cuatrocientas jornadas eligiendo lo peor y la manada acababa
## con el trato a cien.
##
## Y volver a preguntar es lo correcto, no un parche: un lobo no deja de venir
## porque le tires una piedra. Deja de venir esa noche. Mientras haya montón,
## vuelven, y el jugador tiene que volver a decidir. Ahí está la diferencia
## entre una decisión y un trámite.
func _volver_a_empezar() -> void:
	noches = 0
	paso = Paso.LEJOS
	_preguntado.clear()


## Lo que hay que decir en una línea, para la ficha y la crónica.
func resumen() -> String:
	if perro:
		return "Hay perro. Corta el rastro perdido y para la pieza."
	if cachorro:
		return "Se cría un cachorro: %.0f de %.0f jornadas." % [
			cria, CRIA_JORNADAS]
	if hostil():
		return "La manada está en contra: %d muertos. Rondan los vivacs." % muertos
	match paso:
		Paso.LEJOS:
			return "Los lobos andan por el valle y no se acercan."
		Paso.MERODEAN:
			return "Vienen al montón de noche. Llevan %d." % noches
		Paso.UNO_SE_QUEDA:
			return "Uno ya no huye cuando alguien sale."
		Paso.LA_CAMADA:
			return "Se sabe dónde tienen la lobera."
	return "—"


# ------------------------------------------------------------ la jornada --

## Un día de trato. Se llama al cerrar la jornada.
func nuevo_dia() -> void:
	_dar_de_comer()
	_criar()
	sin_matar += 1.0
	if muertos > 0 and sin_matar >= OLVIDO_JORNADAS:
		muertos -= 1
		sin_matar = 0.0
	if hostil():
		# Con la manada en contra no hay camino: hay que ganársela otra vez, y
		# eso sólo pasa dejando de darles motivos. El trato se recupera solo,
		# muy despacio, porque el miedo se olvida pero no rápido.
		trato = minf(trato + 0.12, TRATO_TOPE)
		return
	_merodeo()


## El montón atrae. Es de donde sale todo: sin basura no hay lobos cerca.
func _merodeo() -> void:
	if sim.desechos == null or sim.desechos.volumen() < MONTON_QUE_ATRAE:
		noches = maxi(noches - 1, 0)
		return
	if not _hay_lobos():
		return
	noches += 1
	# Cada noche que vienen y no pasa nada, un poco. Ver [POR_NOCHE].
	if paso != Paso.LEJOS:
		trato = minf(trato + POR_NOCHE, TRATO_TOPE)
	if paso == Paso.LEJOS and noches >= NOCHES_PARA_EMPEZAR:
		paso = Paso.MERODEAN
		_preguntar_merodean()
		return
	_mirar_si_toca_el_siguiente()


## Si hay lobos en el valle ahora mismo.
##
## Se le pregunta a la fauna de verdad y no a un dado: si el jugador ha barrido
## los lobos del valle a azagayazos, no tiene que haber merodeo.
func _hay_lobos() -> bool:
	var fauna: WildlifeHerds = sim.caceria.wildlife if sim.caceria != null else null
	if fauna == null:
		return false
	return int(fauna.tally().get("lobo", 0)) > 0


func _mirar_si_toca_el_siguiente() -> void:
	if paso == Paso.MERODEAN and trato >= PARA_QUE_SE_QUEDE \
			and noches >= NOCHES_PARA_EMPEZAR * 3:
		paso = Paso.UNO_SE_QUEDA
		_preguntar_se_queda()
	elif paso == Paso.UNO_SE_QUEDA and trato >= PARA_LA_CAMADA \
			and noches >= NOCHES_PARA_EMPEZAR * 6:
		paso = Paso.LA_CAMADA
		_preguntar_camada()


## El cachorro come todos los días, y si no hay qué darle se va.
func _dar_de_comer() -> void:
	if not cachorro and not perro:
		return
	var comido := sim.despensa._eat_from_store(COME_AL_DIA)
	if comido >= COME_AL_DIA * 0.5:
		return
	# Con hambre se vuelve al monte. Un perro no es leal a quien no le da de
	# comer, y menos uno que lleva tres generaciones siendo lobo.
	trato -= 8.0
	if cachorro:
		cachorro = false
		cria = 0.0
		paso = Paso.LA_CAMADA
		sim._note(Chronicle.Kind.PENURIA,
			"No hubo qué darle al cachorro y se volvió al monte.", 2)
	elif perro:
		perro = false
		paso = Paso.LA_CAMADA
		sim._note(Chronicle.Kind.PENURIA,
			"El perro pasó hambre y se fue con la manada.", 3)


## La cría, que es lo que de verdad cuesta.
func _criar() -> void:
	if not cachorro:
		return
	cria += 1.0
	if cria < CRIA_JORNADAS:
		return
	cachorro = false
	perro = true
	paso = Paso.EL_PERRO
	_hito()


# ----------------------------------------------------------- los pasos --

func _preguntar_merodean() -> void:
	if _ya("merodean"):
		return
	var momento := Moment.new()
	momento.kind = Moment.Kind.PERCANCE
	momento.title = "Lobos en el montón"
	momento.text = "Llevan seis noches viniendo a rebañar lo que se tira. No " \
		+ "entran al abrigo ni se acercan al fuego: van a la basura y se van " \
		+ "antes de que amanezca."
	momento.options = [
		{
			"label": "Dejarlos comer",
			"hint": "Lo que hay en ese montón no lo quiere nadie. Se " \
				+ "acostumbrarán a la gente, y la gente a ellos.",
			"on_pick": func() -> void:
				trato += POR_DEJARLES * 3.0
				sim._note(Chronicle.Kind.TIERRA,
					"Se les deja rebañar el montón. Vuelven cada noche.", 1),
		},
		{
			"label": "Espantarlos a pedradas",
			"hint": "Un lobo cerca del campamento es un lobo que un día " \
				+ "entrará. Aprenderán a no volver.",
			"on_pick": func() -> void:
				trato += POR_ESPANTAR * 4.0
				_volver_a_empezar()
				sim._note(Chronicle.Kind.TIERRA,
					"Se les echa a pedradas. Esa noche no vuelven.", 1),
		},
		{
			"label": "Matar al que se acerque",
			"hint": "Es carne y es una piel. Y se acaba el problema.",
			"on_pick": func() -> void:
				matar()
				sim.store.add(Materia.Kind.CARNE, 6.0)
				sim.store.add(Materia.Kind.PIEL, 1.0)
				sim._note(Chronicle.Kind.TIERRA,
					"Cae uno junto al montón. La manada aúlla toda la noche.", 2),
		},
	]
	sim.raise_moment(momento)


func _preguntar_se_queda() -> void:
	if _ya("se_queda"):
		return
	var momento := Moment.new()
	momento.kind = Moment.Kind.RELATO
	momento.title = "Uno ya no huye"
	momento.text = "Los demás se apartan cuando alguien sale del abrigo. Uno " \
		+ "no. Se queda a diez pasos, mirando, y espera a que te vayas."
	momento.options = [
		{
			"label": "Echarle una tajada",
			"hint": "Cuesta comida y no da nada a cambio hoy. Pero mañana " \
				+ "estará más cerca.",
			"on_pick": func() -> void:
				sim.despensa._eat_from_store(2.0)
				trato += POR_DEJARLES * 5.0
				sim._note(Chronicle.Kind.TIERRA,
					"Se le echa una tajada al que no huye. La coge y se " \
					+ "aparta, pero no se va.", 2),
		},
		{
			"label": "Dejarlo estar",
			"hint": "Ni se le da ni se le echa. Que decida él.",
			"on_pick": func() -> void:
				trato += POR_DEJARLES,
		},
		{
			"label": "Cobrárselo",
			"hint": "A tiro de azagaya y quieto. No habrá otro igual de fácil.",
			"on_pick": func() -> void:
				matar()
				sim.store.add(Materia.Kind.CARNE, 8.0)
				sim.store.add(Materia.Kind.PIEL, 1.0)
				sim._note(Chronicle.Kind.TIERRA,
					"Cae el que no huía. Los demás dejan de venir.", 3),
		},
	]
	sim.raise_moment(momento)


func _preguntar_camada() -> void:
	if _ya("camada"):
		return
	var momento := Moment.new()
	momento.kind = Moment.Kind.RELATO
	momento.title = "La lobera"
	momento.text = "Siguiéndolos se ha dado con la lobera, en un talud a " \
		+ "media hora del abrigo. Hay camada: se les oye."
	momento.options = [
		{
			"label": "Coger un cachorro",
			"hint": "Ciento veinte jornadas de criarlo, y come todos los " \
				+ "días. La manada no lo va a olvidar.",
			"on_pick": func() -> void:
				cachorro = true
				cria = 0.0
				paso = Paso.EL_CACHORRO
				trato -= 12.0
				sim._note(Chronicle.Kind.GENTE,
					"Se saca un cachorro de la lobera. Duerme dentro, junto " \
					+ "al fuego.", 3),
		},
		{
			"label": "Dejarla en paz",
			"hint": "Una camada es una manada dentro de dos años, y esa " \
				+ "manada ya conoce el campamento.",
			"on_pick": func() -> void:
				trato += POR_DEJARLES * 4.0
				sim._note(Chronicle.Kind.TIERRA,
					"Se deja la camada donde está.", 1),
		},
	]
	sim.raise_moment(momento)


## El hito: se pinta en la pared, como la primera pieza mayor.
func _hito() -> void:
	var relato := Tale.new()
	relato.kind = Tale.Kind.HITO
	relato.subject = "el perro"
	relato.title = "El lobo que se queda"
	relato.text = "Ya no es un lobo. Sale con la cuadrilla, corta el rastro " \
		+ "que se había perdido y para la pieza hasta que llega el cazador. " \
		+ "No caza por nadie: caza CON alguien, que es otra cosa y no la " \
		+ "había hecho ningún animal antes."
	relato.day = sim.day
	relato.task = Profession.task_id(Profession.Job.CAZA,
		Profession.Speciality.CAZA_MAYOR)
	sim.tell_tale(relato)


func _ya(clave: String) -> bool:
	if _preguntado.has(clave):
		return true
	_preguntado[clave] = true
	return false


# ------------------------------------------------- lo que cambia fuera --

## Si el perro corta un rastro que se acaba de perder.
##
## Es el efecto grande, y va con dado: un perro no encuentra siempre. Ver
## [CORTA_EL_RASTRO] y `Caceria._stalk`.
func corta_el_rastro(rng: RandomNumberGenerator) -> bool:
	if not perro:
		return false
	return rng.randf() < CORTA_EL_RASTRO


## Cuánto alarga la persecución. Uno es «nada».
func fuelle() -> float:
	return FUELLE_EXTRA if perro else 1.0


## Cuánto multiplica el riesgo de una noche fuera.
func riesgo_de_vivac() -> float:
	if perro:
		return VIVAC_MAS_SEGURO
	if hostil():
		return VIVAC_CON_ENEMIGOS
	return 1.0
