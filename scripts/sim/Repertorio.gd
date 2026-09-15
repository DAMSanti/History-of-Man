class_name Repertorio
extends RefCounted
## Lo que puede pasar dentro de una cueva, y cómo se eligen las situaciones de
## cada visita.
##
## Frente 22 de EPOCA_01 §10.1, tanda 4. El usuario lo pidió así el 2026-09-13:
## «quiero que haya MUCHAS decisiones como ésta, para que el jugador no lo vea
## como un trámite, que cada cueva que investigue tenga opciones diferentes y no
## se sienta como "siempre me preguntan lo mismo"».
##
## Son DATOS, no código: cada situación es una entrada con su texto, sus
## opciones, y lo que cada opción desata. Lo que hace con ellas —preguntar,
## herir, matar— va aparte; aquí sólo está el repertorio y la regla de qué sale
## en cada cueva.
##
## **Las ramas.** Una opción puede llevar a otra situación (`lleva_a`), y ésa a
## otra. El ejemplo del oso es del usuario y marca el tono: se oye algo en lo
## oscuro; si se sigue investigando puede acabar mal; si se tiran piedras, el
## animal se mueve hacia la entrada y hay que decidir otra cosa; si se hace
## fuego, el humo lo espanta.

## Lo que desata una opción. La consecuencia la pone quien juegue la situación
## —ver el frente 22, E3—; aquí sólo se nombra.
enum Efecto {
	NADA,        ## Se sale sin más
	HALLAZGO,    ## Algo que la banda se lleva o aprende
	SUSTO,       ## Miedo: cuesta volver a entrar
	HERIDA,      ## Alguien sale herido
	PELIGRO,     ## Puede costar la vida
	PINTABLE,    ## Se encuentra pared buena
}

## Cuántas situaciones encadena una visita: dos o tres. Decisión de la spec.
const MINIMO_POR_VISITA := 2
const MAXIMO_POR_VISITA := 3

## El repertorio. `arranque` dice si la situación puede abrir una visita; las
## demás sólo salen por la rama de otra.
##
## Cada opción: `texto`, `efecto`, y `lleva_a` con el id de la situación que
## viene después, o vacío si la cosa acaba ahí.
const SITUACIONES := {
	"ruido_en_lo_oscuro": {
		"arranque": true,
		"texto": "Algo se mueve al fondo, donde la luz no llega. Respira.",
		"opciones": [
			{"texto": "Seguir investigando", "efecto": Efecto.PELIGRO,
				"lleva_a": "el_oso_de_frente"},
			{"texto": "Tirar piedras a lo oscuro", "efecto": Efecto.NADA,
				"lleva_a": "el_oso_hacia_la_boca"},
			{"texto": "Hacer fuego aquí mismo", "efecto": Efecto.NADA,
				"lleva_a": "el_humo_lo_espanta"},
		],
	},
	"el_oso_de_frente": {
		"arranque": false,
		"texto": "Es un oso, y lo tienes encima antes de verlo entero.",
		"opciones": [
			{"texto": "Plantarle la lanza", "efecto": Efecto.PELIGRO, "lleva_a": ""},
			{"texto": "Tirarse a un lado y salir", "efecto": Efecto.HERIDA, "lleva_a": ""},
		],
	},
	"el_oso_hacia_la_boca": {
		"arranque": false,
		"texto": "El animal se levanta y viene hacia la entrada. Entre él y la "
			+ "luz estás tú.",
		"opciones": [
			{"texto": "Hacerle frente", "efecto": Efecto.PELIGRO, "lleva_a": ""},
			{"texto": "Esconderse en la grieta", "efecto": Efecto.SUSTO, "lleva_a": ""},
			{"texto": "Salir corriendo", "efecto": Efecto.HERIDA, "lleva_a": ""},
		],
	},
	"el_humo_lo_espanta": {
		"arranque": false,
		"texto": "El humo llena la galería. Algo grande sale de estampida por "
			+ "el fondo y no vuelve.",
		"opciones": [
			{"texto": "Seguir adelante con la lámpara", "efecto": Efecto.PINTABLE,
				"lleva_a": ""},
			{"texto": "Salir mientras se puede", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"sima_en_el_suelo": {
		"arranque": true,
		"texto": "El suelo se abre en un pozo negro. La piedra que tiras tarda "
			+ "en sonar.",
		"opciones": [
			{"texto": "Bordearlo pegado a la pared", "efecto": Efecto.PELIGRO,
				"lleva_a": ""},
			{"texto": "Bajar con la cuerda", "efecto": Efecto.PELIGRO,
				"lleva_a": "el_fondo_de_la_sima"},
			{"texto": "Volverse", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"el_fondo_de_la_sima": {
		"arranque": false,
		"texto": "Abajo hay huesos de animales que cayeron y no salieron.",
		"opciones": [
			{"texto": "Cargar con lo que sirva", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Subir sin tocar nada", "efecto": Efecto.SUSTO, "lleva_a": ""},
		],
	},
	"paso_estrecho": {
		"arranque": true,
		"texto": "La galería se cierra hasta un paso por el que hay que entrar "
			+ "de lado y sin la lámpara por delante.",
		"opciones": [
			{"texto": "Pasar", "efecto": Efecto.PELIGRO, "lleva_a": "la_sala_de_detras"},
			{"texto": "Agrandarlo a golpes", "efecto": Efecto.NADA, "lleva_a": ""},
			{"texto": "Dejarlo", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"la_sala_de_detras": {
		"arranque": false,
		"texto": "Detrás se abre una sala alta y seca, con la pared lisa.",
		"opciones": [
			{"texto": "Mirarla entera", "efecto": Efecto.PINTABLE, "lleva_a": ""},
			{"texto": "Marcar el paso y salir", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
		],
	},
	"agua_que_corre": {
		"arranque": true,
		"texto": "Se oye agua. Un hilo corre por el suelo de la galería y se "
			+ "mete bajo la roca.",
		"opciones": [
			{"texto": "Seguir el agua", "efecto": Efecto.HALLAZGO,
				"lleva_a": "el_sifon"},
			{"texto": "Beber y seguir a lo tuyo", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"el_sifon": {
		"arranque": false,
		"texto": "El agua llena la galería de pared a pared. Al otro lado se "
			+ "oye eco de sala grande.",
		"opciones": [
			{"texto": "Cruzar buceando", "efecto": Efecto.PELIGRO, "lleva_a": ""},
			{"texto": "Esperar a la seca", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"murcielagos": {
		"arranque": true,
		"texto": "El techo entero se mueve: cientos de murciélagos colgados.",
		"opciones": [
			{"texto": "Pasar despacio por debajo", "efecto": Efecto.NADA, "lleva_a": ""},
			{"texto": "Espantarlos con la lámpara", "efecto": Efecto.SUSTO,
				"lleva_a": "la_lampara_apagada"},
			{"texto": "Cazar unos cuantos", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
		],
	},
	"la_lampara_apagada": {
		"arranque": false,
		"texto": "El aleteo apaga la lámpara. Oscuridad entera, y no sabes "
			+ "hacia dónde estabas mirando.",
		"opciones": [
			{"texto": "Quedarse quieto y escuchar el aire", "efecto": Efecto.NADA,
				"lleva_a": ""},
			{"texto": "Buscar la salida a tientas", "efecto": Efecto.HERIDA, "lleva_a": ""},
		],
	},
	"huellas_de_gente": {
		"arranque": true,
		"texto": "En el barro hay pisadas que no son de la banda, y no son de hoy.",
		"opciones": [
			{"texto": "Seguirlas", "efecto": Efecto.HALLAZGO,
				"lleva_a": "el_hogar_apagado"},
			{"texto": "Borrarlas y salir", "efecto": Efecto.SUSTO, "lleva_a": ""},
		],
	},
	"el_hogar_apagado": {
		"arranque": false,
		"texto": "Un corro de piedras con ceniza vieja, y al lado lascas de un "
			+ "sílex que no es de por aquí.",
		"opciones": [
			{"texto": "Llevarse las lascas", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Dejar algo a cambio", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"pinturas_viejas": {
		"arranque": true,
		"texto": "En la pared hay manos en negativo. Alguien sopló pigmento "
			+ "alrededor de su mano hace mucho.",
		"opciones": [
			{"texto": "Mirarlas con calma", "efecto": Efecto.PINTABLE, "lleva_a": ""},
			{"texto": "Salir sin tocar", "efecto": Efecto.SUSTO, "lleva_a": ""},
		],
	},
	"osamenta_de_oso": {
		"arranque": true,
		"texto": "Un cráneo de oso enorme, con la mandíbula suelta, en mitad "
			+ "del paso.",
		"opciones": [
			{"texto": "Llevárselo", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Ponerlo mirando a la boca", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"zarpazos_en_la_pared": {
		"arranque": true,
		"texto": "La pared está rayada a la altura del pecho: alguien afila "
			+ "aquí las uñas, y no hace mucho.",
		"opciones": [
			{"texto": "Buscar la osera", "efecto": Efecto.PELIGRO,
				"lleva_a": "ruido_en_lo_oscuro"},
			{"texto": "Salir y volver en verano", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"aire_que_sopla": {
		"arranque": true,
		"texto": "De una grieta sale aire frío que hace bailar la llama: detrás "
			+ "hay mucho más.",
		"opciones": [
			{"texto": "Abrir la grieta", "efecto": Efecto.HALLAZGO,
				"lleva_a": "la_sala_de_detras"},
			{"texto": "Apuntarlo para otro día", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"barro_hasta_la_rodilla": {
		"arranque": true,
		"texto": "El suelo se vuelve barro pegajoso y la lámpara chisporrotea.",
		"opciones": [
			{"texto": "Seguir de rodillas", "efecto": Efecto.HERIDA, "lleva_a": ""},
			{"texto": "Dar la vuelta", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"bloque_suelto": {
		"arranque": true,
		"texto": "Del techo cuelga un bloque partido, sujeto por nada bueno.",
		"opciones": [
			{"texto": "Pasar por debajo deprisa", "efecto": Efecto.PELIGRO, "lleva_a": ""},
			{"texto": "Tirarlo con la pértiga", "efecto": Efecto.HERIDA, "lleva_a": ""},
			{"texto": "Buscar otro camino", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"columna_de_piedra": {
		"arranque": true,
		"texto": "Una columna de piedra une el suelo y el techo, y suena como "
			+ "un tambor al golpearla.",
		"opciones": [
			{"texto": "Tocarla y escuchar", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Romper un trozo", "efecto": Efecto.SUSTO, "lleva_a": ""},
		],
	},
	"charca_ciega": {
		"arranque": true,
		"texto": "Una charca quieta, sin una arruga, refleja la lámpara como "
			+ "un ojo.",
		"opciones": [
			{"texto": "Vadearla", "efecto": Efecto.PELIGRO, "lleva_a": ""},
			{"texto": "Rodearla por la cornisa", "efecto": Efecto.HERIDA, "lleva_a": ""},
			{"texto": "Beber y volverse", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"eco_que_contesta": {
		"arranque": true,
		"texto": "Gritas, y la cueva contesta tarde y desde otro sitio.",
		"opciones": [
			{"texto": "Ir hacia donde contestó", "efecto": Efecto.HALLAZGO,
				"lleva_a": "la_sala_de_detras"},
			{"texto": "Callarse", "efecto": Efecto.SUSTO, "lleva_a": ""},
		],
	},
	"lobos_en_el_vestibulo": {
		"arranque": true,
		"texto": "En la entrada hay una camada de lobos, y la madre no está "
			+ "lejos.",
		"opciones": [
			{"texto": "Salir despacio", "efecto": Efecto.NADA, "lleva_a": ""},
			{"texto": "Llevarse un cachorro", "efecto": Efecto.PELIGRO, "lleva_a": ""},
			{"texto": "Hacer fuego en la boca", "efecto": Efecto.SUSTO, "lleva_a": ""},
		],
	},
	"nido_de_vencejos": {
		"arranque": true,
		"texto": "En la bóveda del vestíbulo hay nidos al alcance de una "
			+ "pértiga.",
		"opciones": [
			{"texto": "Coger huevos", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Dejarlos criar", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"silex_en_la_pared": {
		"arranque": true,
		"texto": "En la caliza asoman riñones de sílex negro, del bueno.",
		"opciones": [
			{"texto": "Sacarlos a golpes", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Marcar el sitio", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"ocre_en_el_suelo": {
		"arranque": true,
		"texto": "Una veta de ocre rojo mancha el suelo y las manos.",
		"opciones": [
			{"texto": "Cargar un saco", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Probar la pared con un dedo", "efecto": Efecto.PINTABLE,
				"lleva_a": ""},
		],
	},
	"cornisa_sobre_el_vacio": {
		"arranque": true,
		"texto": "La galería sigue por una cornisa de un palmo, con el vacío "
			+ "debajo.",
		"opciones": [
			{"texto": "Cruzarla", "efecto": Efecto.PELIGRO, "lleva_a": "la_sala_de_detras"},
			{"texto": "Tirar la cuerda primero", "efecto": Efecto.NADA,
				"lleva_a": "la_sala_de_detras"},
			{"texto": "Volverse", "efecto": Efecto.NADA, "lleva_a": ""},
		],
	},
	"hielo_en_la_galeria": {
		"arranque": true,
		"texto": "El suelo está helado y la lámpara no lo derrite: aquí el "
			+ "invierno no se va nunca.",
		"opciones": [
			{"texto": "Guardar carne aquí", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Cruzar con cuidado", "efecto": Efecto.HERIDA, "lleva_a": ""},
		],
	},
	"la_lampara_titubea": {
		"arranque": true,
		"texto": "La llama se encoge y se pone azul. El aire de aquí no es "
			+ "bueno.",
		"opciones": [
			{"texto": "Salir enseguida", "efecto": Efecto.NADA, "lleva_a": ""},
			{"texto": "Aguantar un poco más", "efecto": Efecto.PELIGRO, "lleva_a": ""},
		],
	},
	"pisadas_de_oso_viejas": {
		"arranque": true,
		"texto": "En el barro seco hay huellas de oso del tamaño de una cabeza, "
			+ "y son de otro año.",
		"opciones": [
			{"texto": "Seguir adentro", "efecto": Efecto.NADA,
				"lleva_a": "osamenta_de_oso"},
			{"texto": "Medirlas y salir", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
		],
	},
	"grieta_que_llora": {
		"arranque": true,
		"texto": "Una grieta gotea sin parar y ha hecho una colada de piedra "
			+ "blanca.",
		"opciones": [
			{"texto": "Romperla para pasar", "efecto": Efecto.HERIDA, "lleva_a": ""},
			{"texto": "Recoger agua limpia", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
		],
	},
	"sala_de_los_ecos": {
		"arranque": true,
		"texto": "Una sala redonda donde cualquier ruido vuelve tres veces.",
		"opciones": [
			{"texto": "Contarlo al volver", "efecto": Efecto.HALLAZGO, "lleva_a": ""},
			{"texto": "Mirar la pared del fondo", "efecto": Efecto.PINTABLE, "lleva_a": ""},
		],
	},
	"el_paso_se_cierra": {
		"arranque": true,
		"texto": "Detrás cruje algo y cae tierra: el camino de vuelta se ha "
			+ "estrechado.",
		"opciones": [
			{"texto": "Cavar con las manos", "efecto": Efecto.HERIDA, "lleva_a": ""},
			{"texto": "Buscar otra salida", "efecto": Efecto.PELIGRO, "lleva_a": ""},
		],
	},
}


## Lo que queda de cada situación cuando se sale: `hay`, lo que la cueva tiene
## —para la descripción de la ficha—, y `dice`, lo que cuenta quien entró según
## lo que eligió, una frase por opción y en el mismo orden.
##
## Petición del usuario del 2026-09-13: «una vez explorada, una descripción
## detallada de la cueva y el testimonio de quien la exploró contando su
## experiencia». Va aparte de [SITUACIONES] para que la tabla de las decisiones
## siga leyéndose de un vistazo; `TestExploracion` comprueba que las dos cuadran
## situación por situación y opción por opción.
##
## Una `@` es la vocal del género de quien habla: `quiet@` sale «quieta» o
## «quieto». Ver [dice].
const TESTIMONIOS := {
	"ruido_en_lo_oscuro": {
		"hay": "Al fondo, donde no llega la luz, hay algo vivo que respira.",
		"dice": [
			"Oí algo respirar al fondo y seguí hacia el ruido, que es lo que no se hace.",
			"Oí algo respirar al fondo y tiré piedras a lo oscuro, a ver qué salía.",
			"Oí algo respirar al fondo y prendí fuego allí mismo, con lo que llevaba.",
		],
	},
	"el_oso_de_frente": {
		"hay": "Es cueva de oso: tiene su cama al fondo de la galería.",
		"dice": [
			"Era un oso, y cuando lo vi entero ya lo tenía encima. Le planté la lanza.",
			"Era un oso, y cuando lo vi entero ya lo tenía encima. Me tiré a un lado y salí como pude.",
		],
	},
	"el_oso_hacia_la_boca": {
		"hay": "Un oso la usa de paso, entre el fondo y la boca.",
		"dice": [
			"El oso se levantó y vino hacia la entrada, y yo estaba en medio. Le hice frente.",
			"El oso se levantó y vino hacia la entrada. Me metí en una grieta y lo dejé pasar a un palmo.",
			"El oso se levantó y vino hacia la entrada. Salí corriendo delante de él.",
		],
	},
	"el_humo_lo_espanta": {
		"hay": "La galería tira bien del humo: un fuego dentro la limpia entera.",
		"dice": [
			"El humo sacó de estampida a algo grande, y seguí adentro con la lámpara.",
			"El humo sacó de estampida a algo grande, y aproveché para salir.",
		],
	},
	"sima_en_el_suelo": {
		"hay": "El suelo se abre en una sima honda, de las que no se ve el fondo.",
		"dice": [
			"El suelo se abría en un pozo negro. Lo bordeé pegado a la pared, sin mirar abajo.",
			"El suelo se abría en un pozo negro, y bajé con la cuerda.",
			"El suelo se abría en un pozo negro. Tiré una piedra, tardó en sonar, y me volví.",
		],
	},
	"el_fondo_de_la_sima": {
		"hay": "En el fondo de la sima hay huesos de animales que cayeron y no salieron.",
		"dice": [
			"Abajo había huesos de bichos que cayeron y no salieron. Cargué con lo que servía.",
			"Abajo había huesos de bichos que cayeron y no salieron. Subí sin tocar nada.",
		],
	},
	"paso_estrecho": {
		"hay": "La galería se cierra en un paso por el que sólo se entra de lado.",
		"dice": [
			"La galería se cerraba hasta un paso de lado, y pasé a oscuras, con la lámpara detrás.",
			"La galería se cerraba hasta un paso de lado, y lo agrandé a golpes.",
			"La galería se cerraba hasta un paso de lado, y ahí lo dejé.",
		],
	},
	"la_sala_de_detras": {
		"hay": "Detrás hay una sala alta y seca, con la pared lisa.",
		"dice": [
			"Detrás se abría una sala alta y seca, con la pared lisa, y la miré entera.",
			"Detrás se abría una sala alta y seca. Marqué el paso para volver y salí.",
		],
	},
	"agua_que_corre": {
		"hay": "Por el suelo corre un hilo de agua que se mete bajo la roca.",
		"dice": [
			"Se oía agua corriendo por el suelo, y la seguí.",
			"Se oía agua corriendo por el suelo. Bebí y seguí a lo mío.",
		],
	},
	"el_sifon": {
		"hay": "El agua cierra la galería en un sifón; al otro lado suena a sala grande.",
		"dice": [
			"El agua llenaba la galería de pared a pared, y crucé buceando hacia el eco.",
			"El agua llenaba la galería de pared a pared. Hay que volver cuando baje.",
		],
	},
	"murcielagos": {
		"hay": "El techo de una sala está cubierto de murciélagos.",
		"dice": [
			"El techo entero se movía de murciélagos, y pasé por debajo muy despacio.",
			"El techo entero se movía de murciélagos, y los espanté con la lámpara.",
			"El techo entero se movía de murciélagos, y cacé unos cuantos.",
		],
	},
	"la_lampara_apagada": {
		"hay": "Hay corrientes de aire que apagan una lámpara sin avisar.",
		"dice": [
			"Se me apagó la lámpara y me quedé quiet@, escuchando por dónde entraba el aire.",
			"Se me apagó la lámpara y busqué la salida a tientas, a golpes contra la roca.",
		],
	},
	"huellas_de_gente": {
		"hay": "En el barro hay pisadas de gente que no es de la banda.",
		"dice": [
			"En el barro había pisadas que no eran nuestras, y las seguí.",
			"En el barro había pisadas que no eran nuestras. Las borré y salí.",
		],
	},
	"el_hogar_apagado": {
		"hay": "Hay un hogar viejo de otra gente, con lascas de un sílex de fuera.",
		"dice": [
			"Encontré un corro de piedras con ceniza vieja y lascas de otro sílex. Me las traje.",
			"Encontré un corro de piedras con ceniza vieja y lascas de otro sílex. Dejé algo a cambio.",
		],
	},
	"pinturas_viejas": {
		"hay": "En la pared hay manos en negativo, de gente de hace mucho.",
		"dice": [
			"En la pared había manos sopladas, de hace mucho, y me senté a mirarlas.",
			"En la pared había manos sopladas, de hace mucho. No las toqué y salí.",
		],
	},
	"osamenta_de_oso": {
		"hay": "En mitad del paso hay un cráneo de oso enorme.",
		"dice": [
			"En mitad del paso había un cráneo de oso enorme, y me lo traje.",
			"En mitad del paso había un cráneo de oso enorme. Lo dejé mirando a la boca.",
		],
	},
	"zarpazos_en_la_pared": {
		"hay": "La pared está rayada de zarpazos recientes, a la altura del pecho.",
		"dice": [
			"La pared estaba arañada a la altura del pecho, y fui a buscar la osera.",
			"La pared estaba arañada a la altura del pecho. Salí: se vuelve en verano.",
		],
	},
	"aire_que_sopla": {
		"hay": "De una grieta sale aire frío: la cueva sigue mucho más allá.",
		"dice": [
			"De una grieta salía aire frío, y la abrí.",
			"De una grieta salía aire frío. Lo apunté para otro día.",
		],
	},
	"barro_hasta_la_rodilla": {
		"hay": "Una galería de barro hasta la rodilla.",
		"dice": [
			"El suelo se volvió barro hasta la rodilla y seguí de rodillas.",
			"El suelo se volvió barro hasta la rodilla y di la vuelta.",
		],
	},
	"bloque_suelto": {
		"hay": "Del techo cuelga un bloque partido que no aguanta mucho.",
		"dice": [
			"Del techo colgaba un bloque partido, y pasé por debajo deprisa.",
			"Del techo colgaba un bloque partido, y lo tiré con la pértiga.",
			"Del techo colgaba un bloque partido, y busqué otro camino.",
		],
	},
	"columna_de_piedra": {
		"hay": "Una columna de piedra une suelo y techo, y suena como un tambor.",
		"dice": [
			"Una columna de piedra sonaba como un tambor al golpearla. La toqué y escuché.",
			"Una columna de piedra sonaba como un tambor al golpearla. Rompí un trozo.",
		],
	},
	"charca_ciega": {
		"hay": "Hay una charca quieta y oscura en mitad de la galería.",
		"dice": [
			"Una charca quieta me devolvía la lámpara como un ojo, y la vadeé.",
			"Una charca quieta me devolvía la lámpara como un ojo. La rodeé por la cornisa.",
			"Una charca quieta me devolvía la lámpara como un ojo. Bebí y me volví.",
		],
	},
	"eco_que_contesta": {
		"hay": "El eco contesta tarde y desde otro sitio: hay salas que no se ven.",
		"dice": [
			"Grité y la cueva contestó desde otro sitio, y fui hacia allí.",
			"Grité y la cueva contestó desde otro sitio. Me callé.",
		],
	},
	"lobos_en_el_vestibulo": {
		"hay": "Los lobos crían en el vestíbulo.",
		"dice": [
			"En la entrada había una camada de lobos, y salí despacio.",
			"En la entrada había una camada de lobos, y cogí un cachorro.",
			"En la entrada había una camada de lobos, e hice fuego en la boca.",
		],
	},
	"nido_de_vencejos": {
		"hay": "En la bóveda del vestíbulo crían vencejos.",
		"dice": [
			"En la bóveda había nidos al alcance de la pértiga, y cogí huevos.",
			"En la bóveda había nidos al alcance de la pértiga. Los dejé criar.",
		],
	},
	"silex_en_la_pared": {
		"hay": "En la caliza asoman riñones de sílex negro, del bueno.",
		"dice": [
			"En la pared asomaba sílex negro del bueno, y saqué lo que pude a golpes.",
			"En la pared asomaba sílex negro del bueno. Marqué el sitio.",
		],
	},
	"ocre_en_el_suelo": {
		"hay": "Una veta de ocre rojo mancha el suelo.",
		"dice": [
			"El suelo era ocre rojo, de mancharse las manos, y cargué un saco.",
			"El suelo era ocre rojo, de mancharse las manos, y probé la pared con un dedo.",
		],
	},
	"cornisa_sobre_el_vacio": {
		"hay": "La galería sigue por una cornisa de un palmo sobre el vacío.",
		"dice": [
			"La galería seguía por una cornisa de un palmo sobre el vacío, y la crucé.",
			"La galería seguía por una cornisa de un palmo sobre el vacío. Tendí la cuerda y pasé agarrad@.",
			"La galería seguía por una cornisa de un palmo sobre el vacío, y me volví.",
		],
	},
	"hielo_en_la_galeria": {
		"hay": "Hay una galería helada donde el invierno no se va nunca.",
		"dice": [
			"Había una galería helada, y dejé carne guardada allí.",
			"Había una galería helada, y la crucé con cuidado.",
		],
	},
	"la_lampara_titubea": {
		"hay": "Hay un tramo de aire malo, donde la llama se pone azul.",
		"dice": [
			"La llama se encogió y se puso azul, y salí enseguida.",
			"La llama se encogió y se puso azul, y aguanté un poco más.",
		],
	},
	"pisadas_de_oso_viejas": {
		"hay": "En el barro seco quedan huellas de oso de otros años.",
		"dice": [
			"En el barro seco había huellas de oso del tamaño de una cabeza, y seguí adentro.",
			"En el barro seco había huellas de oso del tamaño de una cabeza. Las medí y salí.",
		],
	},
	"grieta_que_llora": {
		"hay": "Una grieta gotea sin parar sobre una colada de piedra blanca.",
		"dice": [
			"Una grieta goteaba sobre una colada blanca, y la rompí para pasar.",
			"Una grieta goteaba sobre una colada blanca, y recogí agua limpia.",
		],
	},
	"sala_de_los_ecos": {
		"hay": "Tiene una sala redonda donde cada ruido vuelve tres veces.",
		"dice": [
			"Llegué a una sala donde cada ruido volvía tres veces, y me la aprendí para contarla.",
			"Llegué a una sala donde cada ruido volvía tres veces, y miré la pared del fondo.",
		],
	},
	"el_paso_se_cierra": {
		"hay": "El techo del camino de vuelta se desprende: es terreno flojo.",
		"dice": [
			"Detrás de mí cayó tierra y se estrechó la vuelta, y cavé con las manos.",
			"Detrás de mí cayó tierra y se estrechó la vuelta, y busqué otra salida.",
		],
	},
}


## Cuántas situaciones hay en total, y cuántas pueden abrir una visita.
static func cuantas() -> int:
	return SITUACIONES.size()


static func arranques() -> Array:
	var lista: Array = []
	for id: String in SITUACIONES:
		if bool((SITUACIONES[id] as Dictionary)["arranque"]):
			lista.append(id)
	lista.sort()
	return lista


## Las situaciones de una visita a una cueva: dos o tres, sin repetir, y sin
## empezar como la cueva anterior.
##
## Con la semilla de la partida y el id de la cueva: la misma cueva de la misma
## partida ofrece siempre lo mismo, y dos cuevas distintas, cosas distintas.
## Azar propio, que no toca el `_rng` de la simulación (SPECS §7).
static func visita_de(semilla: int, cueva: int, no_empezar_con: String = "") -> Array:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([semilla, cueva, "visita"])

	var posibles := arranques()
	if posibles.size() > 1 and not no_empezar_con.is_empty():
		posibles.erase(no_empezar_con)
	var visita: Array = [posibles[azar.randi() % posibles.size()]]

	var cuantas_hoy := MINIMO_POR_VISITA + (azar.randi() % (
		MAXIMO_POR_VISITA - MINIMO_POR_VISITA + 1))
	var resto := arranques()
	while visita.size() < cuantas_hoy and not resto.is_empty():
		var cual: String = resto[azar.randi() % resto.size()]
		resto.erase(cual)
		if not visita.has(cual):
			visita.append(cual)
	return visita


## Lo que cuenta quien eligió esa opción, con su género. Vacío si no está.
static func dice(situacion: String, opcion: int, mujer: bool) -> String:
	var ficha: Dictionary = TESTIMONIOS.get(situacion, {})
	var frases: Array = ficha.get("dice", [])
	if opcion < 0 or opcion >= frases.size():
		return ""
	return String(frases[opcion]).replace("@", "a" if mujer else "o")


## Lo que tiene la cueva por esa situación, dicho para la ficha.
static func hay(situacion: String) -> String:
	return String((TESTIMONIOS.get(situacion, {}) as Dictionary).get("hay", ""))


## La situación a la que lleva una opción, o vacío si ahí se acaba.
static func lleva_a(situacion: String, opcion: int) -> String:
	var ficha: Dictionary = SITUACIONES.get(situacion, {})
	if ficha.is_empty():
		return ""
	var opciones: Array = ficha["opciones"]
	if opcion < 0 or opcion >= opciones.size():
		return ""
	return String((opciones[opcion] as Dictionary)["lleva_a"])


## Y lo que desata esa opción. Ver [Efecto].
static func efecto_de(situacion: String, opcion: int) -> Efecto:
	var ficha: Dictionary = SITUACIONES.get(situacion, {})
	if ficha.is_empty():
		return Efecto.NADA
	var opciones: Array = ficha["opciones"]
	if opcion < 0 or opcion >= opciones.size():
		return Efecto.NADA
	return (opciones[opcion] as Dictionary)["efecto"] as Efecto
