class_name Profession
extends RefCounted
## Los oficios de la banda y quién puede hacer cada uno.
##
## Sobre la división sexual del trabajo, porque es lo que decide media de estas
## reglas y conviene dejarlo escrito:
##
## El modelo por defecto NO veta por sexo. Veta por ETAPA VITAL. La idea de que
## las mujeres no cazaban en el Paleolítico es el modelo "Man the Hunter" de
## 1966, y el registro no lo sostiene: Haas et al. (2020) publicaron un
## enterramiento femenino de 9.000 años en Wilamaya Patjxa con equipo completo
## de caza mayor, y en su revisión de enterramientos americanos contemporáneos
## 11 de 27 cazadores eran mujeres. Ocobock y Lacy (2023) revisaron la
## evidencia fisiológica y arqueológica en contra. En la etnografía, Anderson
## et al. (2023) documentaron caza femenina en el 79% de las sociedades
## forrajeras con datos.
##
## Lo que sí está bien documentado es que el embarazo avanzado y la lactancia
## limitan las jornadas largas. Eso produce en la práctica una asimetría
## parecida, pero por el motivo correcto y —lo que importa para el juego— de
## forma DINÁMICA: la misma persona vuelve a la partida cuando desteta.
##
## El veto duro por sexo existe y funciona: basta poner `sex` a SOLO_HOMBRES o
## SOLO_MUJERES en el catálogo. Simplemente no es lo que viene puesto.

enum Job {
	CAZA,          ## Del lazo a la res: tres formas distintas de traer carne
	RIBERA,        ## Todo lo que da el agua. Antes eran dos oficios: pesca y
	               ## marisqueo. Es el mismo sitio, la misma gente y la misma
	               ## marea; separarlos obligaba a repartir cuadrilla entre dos
	               ## columnas para hacer el mismo viaje a la orilla.
	RECOLECCION,   ## Lo que se coge del monte: comida, leña y piedra
	MANUFACTURA,   ## Taller. Rota entre sus especialidades salvo que se fije una
	EXPLORACION,   ## Salir del territorio conocido. También rota, o se fija
	HOGAR,         ## Fuego, crianza, preparación. No produce comida.
	OCIOSO,        ## Sin oficio. Es el fondo común del que tiran los demás.
}

## Especialidades de un oficio.
##
## Existen porque en una banda de quince nadie es tallador a tiempo completo:
## la especialización artesanal aparece con el excedente y la población, no
## antes. Quien está en manufactura hace de todo salvo que se le fije una
## especialidad, y poder fijarla es justo la recompensa de haber crecido.
##
## `NINGUNA` significa «lo que haga falta»: se elige lo que más lejos esté de
## su pedido permanente. Rotar por turnos daría al tallador trenzando cordel
## mientras la banda se queda sin puntas.
enum Speciality {
	NINGUNA,
	# Manufactura
	TALLA,         ## Piedra: lascas, hojas, buriles, raederas
	ASTA,          ## Asta y hueso: azagayas, arpones, agujas. Necesita buriles
	PELETERIA,     ## Piel: ropa, odres, cobijo. Necesita raederas
	CORDELERIA,    ## Fibra: cordel, redes, lazos, cestos
	# Exploración
	BATIDA,        ## Radio corto y diario: amplía la zona de trabajo
	EXPEDICION,    ## Varios días fuera, con provisiones: abre comarca
	ASCENSION,     ## Subir a lo alto: se ve muchísimo de golpe, y da prestigio
	# Recolección
	FORRAJEO,      ## Fruto, raíz, seta, huevo: la comida del monte
	LENA_FIBRA,    ## Leña, yesca, fibra, corteza: lo que alimenta al taller
	CANTERA,       ## Piedra, sílex y ocre. Antes salía a por ellos el tallador
	# Caza
	TRAMPAS,       ## Lazo y trampa: rinde poco y casi nunca falla
	CAZA_MENOR,    ## Ave, conejo, corzo. Diario y de radio corto
	CAZA_MAYOR,    ## Ciervo, uro, caballo. Jornada larga y varias manos
	# Ribera
	MARISQUEO,     ## Lapa, mejillón, berberecho: lo que sostiene el invierno
	ORILLA,        ## Río y estuario, con arpón
	ALTURA,        ## Mar abierto. Hace falta embarcación: todavía no la hay
	# Hogar
	YESQUERO,      ## El fuego: prenderlo, alimentarlo, no dejar que se apague
	AHUMADO,       ## El secadero: carne fresca a carne que dura el invierno
	CUIDADO,       ## Críos, viejos y heridos: los que no se valen solos
}

## Qué especialidades admite cada oficio.
const SPECIALITIES := {
	Job.RECOLECCION: [Speciality.FORRAJEO, Speciality.LENA_FIBRA,
		Speciality.CANTERA],
	Job.CAZA: [Speciality.TRAMPAS, Speciality.CAZA_MENOR,
		Speciality.CAZA_MAYOR],
	Job.RIBERA: [Speciality.MARISQUEO, Speciality.ORILLA, Speciality.ALTURA],
	Job.MANUFACTURA: [Speciality.TALLA, Speciality.ASTA,
		Speciality.PELETERIA, Speciality.CORDELERIA],
	Job.EXPLORACION: [Speciality.BATIDA, Speciality.EXPEDICION,
		Speciality.ASCENSION],
	# El HOGAR no tiene especialidades, y es a proposito.
	#
	# Las tuvo -yesquero, ahumado, cuidado- y era repartir en tres a la unica
	# persona que suele haber: en una banda de quince, el hogar son uno o dos, y
	# pedirle al jugador que ademas elija cual de las tres cosas hacen es una
	# decision sin decision. En el Paleolitico el hogar LO HACE TODO: prende el
	# fuego, lo mantiene, ahuma la carne y el pescado, cuida de quien no se vale
	# y ensena a hacer vivac -ver `SettlementSim._bivouac`-.
	#
	# Los tres efectos no se han perdido: se aplican siempre a quien atiende el
	# hogar en vez de a quien lleve el rotulo.
}


## Qué actividad ecológica explota cada especialidad.
##
## Los oficios son cómo se organiza la BANDA; las actividades son qué parte del
## monte se toca, y el campo de recursos está hecho sobre esas. Separarlos es
## lo que permite que «cantera» y «forrajeo» sean el mismo oficio para el
## jugador y dos sitios distintos para el terreno.
const SPECIALITY_ACTIVITY := {
	Speciality.FORRAJEO: Subsistence.Activity.RECOLECCION,
	Speciality.LENA_FIBRA: Subsistence.Activity.RECOLECCION,
	Speciality.CANTERA: Subsistence.Activity.MATERIA_PRIMA,
	Speciality.TRAMPAS: Subsistence.Activity.CAZA,
	Speciality.CAZA_MENOR: Subsistence.Activity.CAZA,
	Speciality.CAZA_MAYOR: Subsistence.Activity.CAZA,
	Speciality.MARISQUEO: Subsistence.Activity.MARISQUEO,
	Speciality.ORILLA: Subsistence.Activity.PESCA,
	Speciality.ALTURA: Subsistence.Activity.PESCA,
}


## La actividad que toca una tarea, mirando primero su especialidad.
static func activity_of(job: Job, speciality: Speciality) -> Subsistence.Activity:
	if SPECIALITY_ACTIVITY.has(speciality):
		return SPECIALITY_ACTIVITY[speciality] as Subsistence.Activity
	return CATALOGUE[job]["activity"] as Subsistence.Activity


## Especialidades que la banda todavía no sabe hacer.
##
## La pesca de altura pide embarcación, y una embarcación no se improvisa: es
## la misma idea que las cumbres que piden cuerda de verdad. Sale en la tabla
## desde el principio a propósito, apagada, porque ver lo que aún no puedes
## hacer es la mitad de la gracia de un juego de progreso.
static func needs_craft(speciality: Speciality) -> bool:
	return speciality == Speciality.ALTURA

## Nombre y descripción de cada especialidad.
const SPECIALITY_INFO := {
	Speciality.NINGUNA: {
		"name": "Lo que haga falta",
		"desc": "Rota entre las especialidades del oficio según lo que más "
			+ "falte. Es lo que hace una banda pequeña: nadie da para vivir de "
			+ "un solo trabajo.",
	},
	Speciality.TALLA: {
		"name": "Talla",
		"desc": "Piedra: lascas, hojas, buriles y raederas. No produce comida "
			+ "y sin ella no come nadie, porque las otras dos artesanías "
			+ "necesitan sus herramientas.",
	},
	Speciality.ASTA: {
		"name": "Asta y hueso",
		"desc": "Azagayas, arpones, anzuelos, agujas y punzones. Necesita "
			+ "BURILES para ranurar el asta y el hueso: sin tallador, este "
			+ "oficio se para.",
	},
	Speciality.PELETERIA: {
		"name": "Peletería",
		"desc": "Descarnar y curtir pieles: ropa, cobijo y odres. Necesita "
			+ "RAEDERAS, y ocre y grasa para curtir.",
	},
	Speciality.CORDELERIA: {
		"name": "Cordelería y cestería",
		"desc": "Fibra trenzada: cuerda, cestos, nasas y redes de pesca. Es el "
			+ "único taller que no necesita herramienta de piedra, y de él "
			+ "salen los recipientes que deciden cuánto se trae de cada "
			+ "jornada y medio aparejo del río.",
	},
	Speciality.BATIDA: {
		"name": "Batida",
		"desc": "Radio corto y vuelta en el día. Amplía la zona de trabajo "
			+ "alrededor del campamento y localiza parajes nuevos cerca.",
	},
	Speciality.EXPEDICION: {
		"name": "Expedición",
		"desc": "Varios días fuera, durmiendo al raso y con provisiones a "
			+ "cuestas. Es lo que abre comarca y encuentra el sílex bueno, "
			+ "las cuevas y los pasos.",
	},
	Speciality.FORRAJEO: {
		"name": "Fruto y raíz",
		"desc": "Avellana, bellota, baya, raíz, seta, huevo. Es la comida que "
			+ "no falla: rinde poco por hora y hay casi todo el año, y por eso "
			+ "sostiene a la banda mientras la caza acierta o no.",
	},
	Speciality.LENA_FIBRA: {
		"name": "Leña y fibra",
		"desc": "Lo que se coge del suelo para que el taller y el fuego "
			+ "funcionen: leña, yesca, fibra, corteza, resina. No se come nada "
			+ "de esto y sin ello no se cocina, no se ata y no se enciende.",
	},
	Speciality.CANTERA: {
		"name": "Cantera",
		"desc": "Piedra, sílex y ocre del canchal y del cauce. Es el recado "
			+ "que antes hacía el propio tallador: se pasaba media jornada "
			+ "andando a por cantos que cualquiera podía traer de paso.",
	},
	Speciality.TRAMPAS: {
		"name": "Trampas",
		"desc": "Lazo y cepo puestos al paso. Rinde poco y casi nunca falla, "
			+ "y trabaja sola mientras la banda hace otra cosa. Lo puede llevar "
			+ "quien no aguanta una jornada de monte.",
	},
	Speciality.CAZA_MENOR: {
		"name": "Caza menor",
		"desc": "Ave, conejo, corzo. Radio corto y casi a diario: menos carne "
			+ "por salida que una res, pero llega todas las semanas.",
	},
	Speciality.CAZA_MAYOR: {
		"name": "Caza mayor",
		"desc": "Ciervo, uro, caballo. Jornada larga, varias manos y azagayas "
			+ "de verdad. Cuando sale, una sola pieza da carne, piel, asta, "
			+ "tendón y grasa para semanas.",
	},
	Speciality.MARISQUEO: {
		"name": "Marisqueo",
		"desc": "Lapa, mejillón y erizo en la rasa. Poco alimento por pieza, "
			+ "pero seguro y sin riesgo: es lo que sostiene el invierno cuando "
			+ "no hay fruto y la caza no aparece.",
	},
	Speciality.ORILLA: {
		"name": "Pesca de orilla",
		"desc": "Río y estuario, con arpón. En el remonte del salmón vale por "
			+ "tres cacerías; fuera de temporada, por media.",
	},
	Speciality.ALTURA: {
		"name": "Pesca de altura",
		"desc": "Mar abierto, donde está lo grande. Hace falta embarcación, y "
			+ "una embarcación no se improvisa: hasta que la banda sepa "
			+ "hacerla, esto se mira desde la playa.",
	},
	Speciality.YESQUERO: {
		"name": "Yesquero",
		"desc": "El fuego: prenderlo, alimentarlo y no dejar que se apague. "
			+ "Gasta menos leña que quien lo cuida de paso, y si se apaga lo "
			+ "levanta en la mitad de tiempo. La banda sabe hacer fuego desde "
			+ "siempre; lo que cuesta es tenerlo encendido todos los días.",
	},
	Speciality.AHUMADO: {
		"name": "Ahumado",
		"desc": "Colgar la carne sobre el humo y no perderla de vista. Una "
			+ "ración fresca dura cuatro días y seca ciento ochenta, así que "
			+ "esto es lo que convierte un otoño bueno en un invierno vivo. "
			+ "Hace falta secadero, y el secadero hace falta fuego.",
	},
	Speciality.CUIDADO: {
		"name": "Cuidado",
		"desc": "Críos, viejos y heridos. Quien vuelve con un tobillo torcido "
			+ "vuelve antes al trabajo si hay alguien pendiente de él, y una "
			+ "banda de quince no puede permitirse tener a nadie de baja más "
			+ "días de los necesarios.",
	},
	Speciality.ASCENSION: {
		"name": "Ascensión",
		"desc": "Subir a lo alto. Desde una cumbre se ve de golpe lo que "
			+ "costaría semanas recorrer, aunque sea de lejos y sin detalle. "
			+ "Y volver de ella cuenta: no todo lo que mueve a la gente es "
			+ "comida.",
	},
}


## Una TAREA es lo que de verdad se hace: un oficio, o un oficio con su
## especialidad. Es la unidad sobre la que el jugador pone prioridades.
##
## Antes las prioridades eran por OFICIO y la especialidad era un apaño aparte,
## fija y para toda la cuadrilla. Eso hacia imposible lo unico interesante:
## decir «Naia primero talla, y si no hace falta talla, que trence cordel».
## Aqui cada especialidad tiene su propia prioridad, como cualquier otro
## trabajo, y anidada dentro de su oficio.
##
## Se codifica en un solo entero para que quepa como clave de diccionario y se
## guarde con la partida sin escribir nada.
static func task_id(job: Job, speciality: Speciality = Speciality.NINGUNA) -> int:
	return int(job) * 100 + int(speciality)


static func task_job(task: int) -> Job:
	return (task / 100) as Job


static func task_speciality(task: int) -> Speciality:
	return (task % 100) as Speciality


## Las tareas de un oficio: el oficio a secas si no tiene especialidades, y
## una por especialidad si las tiene.
static func tasks_of(job: Job) -> Array[int]:
	var out: Array[int] = []
	var specialities := specialities_of(job)
	if specialities.is_empty():
		out.append(task_id(job))
		return out
	for speciality: int in specialities:
		out.append(task_id(job, speciality as Speciality))
	return out


## Como se llama una tarea, para el rotulo de la columna.
static func task_name(task: int) -> String:
	var speciality := task_speciality(task)
	if speciality == Speciality.NINGUNA:
		return job_name(task_job(task))
	return speciality_name(speciality)


static func task_desc(task: int) -> String:
	var speciality := task_speciality(task)
	if speciality == Speciality.NINGUNA:
		return job_desc(task_job(task))
	return speciality_desc(speciality)


static func speciality_name(speciality: Speciality) -> String:
	return SPECIALITY_INFO[speciality]["name"]


static func speciality_desc(speciality: Speciality) -> String:
	return SPECIALITY_INFO[speciality]["desc"]


## Especialidades que admite un oficio. Vacío si no admite ninguna.
static func specialities_of(job: Job) -> Array:
	return SPECIALITIES.get(job, [])


static func has_specialities(job: Job) -> bool:
	return SPECIALITIES.has(job)

enum Sex { AMBOS, SOLO_HOMBRES, SOLO_MUJERES }

## Definición de cada oficio.
##
## `activity` es la actividad de subsistencia que produce, o -1 si no produce.
## `mobile` marca los que exigen alejarse del campamento una jornada entera:
## son los que quedan cerrados a crios, ancianos y a quien esté criando.
const CATALOGUE := {
	Job.CAZA: {
		"name": "Caza",
		"desc": "Partidas de caza mayor: ciervo, caballo, bisonte. Se sale al "
			+ "amanecer y se vuelve con la carga, o no se vuelve con nada.",
		"activity": Subsistence.Activity.CAZA,
		"mobile": true, "min_age": 15, "max_age": 55, "sex": Sex.AMBOS,
	},
	Job.RIBERA: {
		"name": "Ribera",
		"desc": "Todo lo que da el agua: la lapa de la rasa, el salmón en el "
			+ "remonte y, el día que haya con qué salir, el mar de fuera. "
			+ "Antes eran dos oficios y era el mismo viaje a la orilla.",
		"activity": Subsistence.Activity.MARISQUEO,
		# La edad es la de la especialidad MAS suave -el marisqueo lo hace un
		# crio en la rasa-, y lo duro se filtra por especialidad. Al reves,
		# exigiendo adulto para el oficio entero, se dejaba sin marisquear a
		# media banda por una regla que solo valia para la pesca de altura.
		"mobile": false, "min_age": 7, "max_age": 75, "sex": Sex.AMBOS,
	},
	Job.RECOLECCION: {
		"name": "Recolección",
		"desc": "Avellana, bellota, raíz, fruto. La mitad callada de la dieta "
			+ "paleolítica, y la que menos falla.",
		"activity": Subsistence.Activity.RECOLECCION,
		"mobile": false, "min_age": 7, "max_age": 75, "sex": Sex.AMBOS,
	},
	Job.MANUFACTURA: {
		"name": "Manufactura",
		"desc": "El taller de la banda: piedra, asta, piel y fibra. Nadie come "
			+ "de esto y todos comen gracias a esto, porque sin filo no hay "
			+ "despiece y sin ligadura no hay azagaya.",
		"activity": Subsistence.Activity.MATERIA_PRIMA,
		"mobile": false, "min_age": 12, "max_age": 90, "sex": Sex.AMBOS,
	},
	Job.EXPLORACION: {
		"name": "Exploración",
		"desc": "Salir de lo conocido. No trae comida: trae mapa, y con él los "
			+ "sitios donde habrá comida. Batida, expedición o ascensión son "
			+ "cosas muy distintas y se eligen aparte.",
		"activity": Subsistence.Activity.CAZA,
		"mobile": true, "min_age": 16, "max_age": 50, "sex": Sex.AMBOS,
	},
	Job.OCIOSO: {
		"name": "Sin oficio",
		"desc": "Quien no está asignado a nada. Es de aquí de donde salen los "
			+ "brazos cuando se suma a un oficio, y aquí es adonde van cuando "
			+ "se resta. No produce nada: es el margen de maniobra.",
		"activity": -1,
		"mobile": false, "min_age": 0, "max_age": 120, "sex": Sex.AMBOS,
	},
	Job.HOGAR: {
		"name": "Hogar",
		"desc": "Mantener el fuego, criar, preparar pieles y secar carne. No "
			+ "produce comida, pero sin ello se pierde la que entra.",
		"activity": -1,
		"mobile": false, "min_age": 5, "max_age": 99, "sex": Sex.AMBOS,
	},
}


static func job_name(job: Job) -> String:
	return CATALOGUE[job]["name"]


static func job_desc(job: Job) -> String:
	return CATALOGUE[job]["desc"]


## La actividad de subsistencia que produce un oficio, o -1 si no produce.
static func job_activity(job: Job) -> int:
	return int(CATALOGUE[job]["activity"])


## Si un oficio exige alejarse del campamento la jornada entera.
static func is_mobile(job: Job) -> bool:
	return bool(CATALOGUE[job]["mobile"])


## Si una restricción de sexo deja pasar a esta persona.
static func allows_sex(restriction: Sex, person: Inhabitant) -> bool:
	match restriction:
		Sex.SOLO_HOMBRES: return person.sex == Inhabitant.Sex.HOMBRE
		Sex.SOLO_MUJERES: return person.sex == Inhabitant.Sex.MUJER
		_: return true


## Si esta persona puede desempeñar este oficio ahora mismo.
static func can_do(job: Job, person: Inhabitant) -> bool:
	var entry: Dictionary = CATALOGUE[job]

	if person.age_years < int(entry["min_age"]) or person.age_years > int(entry["max_age"]):
		return false
	if not allows_sex(entry["sex"] as Sex, person):
		return false

	if bool(entry["mobile"]):
		# Los oficios de jornada larga piden poder andar todo el día lejos del
		# campamento. Eso deja fuera a crios y ancianos, y a quien lleve una
		# cría de pecho: con un lactante encima no se hace una batida, lo lleve
		# quien lo lleve.
		if person.age_group != Inhabitant.Age.ADULTO:
			return false
		if person.nursing:
			return false

	return true


## Quiénes de un grupo pueden hacer ese oficio.
static func eligible(job: Job, people: Array) -> Array[Inhabitant]:
	var out: Array[Inhabitant] = []
	for person: Inhabitant in people:
		if can_do(job, person):
			out.append(person)
	return out


## Asigna el oficio si la persona puede. Devuelve si se aceptó.
##
## El hogar se acepta pero NO pone tarea de campo: es trabajo, pero no produce
## comida, y si contara como actividad la banda se alimentaría de vigilar la
## hoguera.
static func assign(job: Job, person: Inhabitant,
		speciality: Speciality = Speciality.NINGUNA) -> bool:
	if not can_do(job, person):
		return false

	person.job = job
	# Lo que el jugador ha FIJADO no se toca: es una preferencia suya, no un
	# estado del día. Antes, sacar a un tallador al hogar —cosa que hace el
	# mínimo del fuego— le borraba la talla, y al volver había que ponérsela
	# otra vez sin que nada explicara por qué se había perdido.
	#
	# Lo que sí se recorta es lo que ejerce HOY: en el hogar no se talla,
	# aunque uno sea tallador.
	if speciality != Speciality.NINGUNA:
		person.speciality = speciality
	if not specialities_of(job).has(person.speciality):
		person.current_speciality = Speciality.NINGUNA
	else:
		person.current_speciality = person.speciality
	# La actividad sale de la ESPECIALIDAD que se va a ejercer, no del oficio.
	#
	# No es un matiz: la cantera es recoleccion para el jugador y materia
	# prima para el terreno, y la orilla es ribera para el jugador y pesca
	# para el terreno. Poniendo la del oficio, un cantero esquilmaba el monte
	# de recoger y cobraba la temporada de la avellana, y un pescador de
	# orilla no contaba como pesca en ningun sitio: ni para pedir aparejo, ni
	# para el remonte del salmon, ni para las jornadas que dan las tecnicas
	# de pesca. Medido: 260 dias con cinco personas en la orilla y el arbol
	# de tecnicas marcaba CERO jornadas de pesca.
	var activity := activity_of(job, person.current_speciality)
	if activity < 0:
		person.has_task = false
		return true

	person.activity = activity as Subsistence.Activity
	person.has_task = true
	return true
