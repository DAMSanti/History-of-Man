class_name Teclas
## Las teclas del juego, todas por accion. INTERFAZ §11.
##
## **Aqui y solo aqui se nombra una tecla.** Antes se preguntaban en seis sitios:
## `OrbitalCamera` miraba la W fisica Y la accion `move_forward` -asi que cambiar la
## accion no hacia nada-, y `DemoMain`, `RegionMap`, `SalaDeLaCueva`,
## `PerformanceOverlay` y `PanelAlmacen` comparaban `event.keycode` a mano. Es el
## invariante 3 de SPECS §7: una pregunta, un sitio que la contesta. Una prueba de la
## suite recorre `scripts/` y falla si alguien vuelve a preguntar por una tecla fuera de
## este fichero.
##
## Estado estatico, como [Configuracion] y por lo mismo (SPECS §2.2): no es de la
## partida, es de quien juega. Se guarda en su mismo fichero, seccion `[teclas]`.

## Donde vale una accion. **Sin esto, el detector de choques mentiria**: la R es «la capa
## del minimapa» en el valle y «la ficha del sitio» en el regional, y el espacio es
## «pausar» y «resolver la estacion». Son pantallas distintas y nunca coinciden.
enum Ambito { SIEMPRE, VALLE, REGIONAL }

## Sin tecla. Con nombre propio para que **nadie fuera de aqui escriba una constante de
## tecla del motor**: la prueba de la suite las busca y no distingue cuales son inocentes.
const NINGUNA := KEY_NONE

## Una fila del catalogo: `id` como se pregunta, `rotulo` como se lee, `ambito` donde
## vale, `tecla` la de siempre, y dos marcas.
##
## `fija` es para ESC: es la salida de TODAS las ventanas, incluida la de cambiar teclas
## y su propio aviso de choque, asi que cambiarla es la forma de quedarse encerrado
## (decision del usuario, 2026-09-17). `oculta` es para lo de desarrollo: pasa por accion
## como todo, pero no sale en la ventana del jugador.
const CATALOGO: Array[Dictionary] = [
	# --- en todas partes ---
	{"id": "cerrar", "rotulo": "Cerrar lo de delante, o el menú",
		"ambito": Ambito.SIEMPRE, "tecla": KEY_ESCAPE, "fija": true},
	# Rotulos cortos a proposito: la columna de la etiqueta son 260 px, y con la frase
	# entera la fila del 1 empujaba su boton y rompia la alineacion de toda la lista.
	# Lo que hacen los numeros lo cuenta la nota de la pestaña.
	{"id": "numero_0", "rotulo": "El 0", "ambito": Ambito.SIEMPRE, "tecla": KEY_0},
	{"id": "numero_1", "rotulo": "El 1", "ambito": Ambito.SIEMPRE, "tecla": KEY_1},
	{"id": "numero_2", "rotulo": "El 2", "ambito": Ambito.SIEMPRE, "tecla": KEY_2},
	{"id": "numero_3", "rotulo": "El 3", "ambito": Ambito.SIEMPRE, "tecla": KEY_3},
	{"id": "numero_4", "rotulo": "El 4", "ambito": Ambito.SIEMPRE, "tecla": KEY_4},
	{"id": "numero_5", "rotulo": "El 5", "ambito": Ambito.SIEMPRE, "tecla": KEY_5},
	# F4 y no F3: F3 era a la vez «velocidad x5» y este panel, y la ventana de controles
	# las listaba las dos como si nada. Decision del usuario (2026-09-17): se muda el
	# panel, que las tres velocidades son un trio de teclas seguidas.
	{"id": "panel_de_rendimiento", "rotulo": "Los fotogramas por segundo",
		"ambito": Ambito.SIEMPRE, "tecla": KEY_F4},

	# --- el valle ---
	{"id": "avanzar", "rotulo": "Desplazar la vista adelante",
		"ambito": Ambito.VALLE, "tecla": KEY_W},
	{"id": "retroceder", "rotulo": "Desplazar la vista atrás",
		"ambito": Ambito.VALLE, "tecla": KEY_S},
	{"id": "izquierda", "rotulo": "Desplazar la vista a la izquierda",
		"ambito": Ambito.VALLE, "tecla": KEY_A},
	{"id": "derecha", "rotulo": "Desplazar la vista a la derecha",
		"ambito": Ambito.VALLE, "tecla": KEY_D},
	{"id": "acercar", "rotulo": "Acercar", "ambito": Ambito.VALLE, "tecla": KEY_Q},
	{"id": "alejar", "rotulo": "Alejar", "ambito": Ambito.VALLE, "tecla": KEY_E},
	{"id": "deprisa", "rotulo": "Deprisa: la vista corre, y el almacén va de diez en diez",
		"ambito": Ambito.VALLE, "tecla": KEY_SHIFT},
	# La P se pierde: hasta hoy pausaban las dos y el catalogo lleva UNA tecla por accion
	# (la spec deja «varias teclas por accion» fuera de alcance). Se queda el espacio, que
	# es lo que se pulsa sin pensar.
	{"id": "pausa", "rotulo": "Pausar y reanudar",
		"ambito": Ambito.VALLE, "tecla": KEY_SPACE},
	{"id": "velocidad_normal", "rotulo": "Velocidad normal",
		"ambito": Ambito.VALLE, "tecla": KEY_F1},
	{"id": "velocidad_x3", "rotulo": "Velocidad ×3",
		"ambito": Ambito.VALLE, "tecla": KEY_F2},
	{"id": "velocidad_x5", "rotulo": "Velocidad ×5",
		"ambito": Ambito.VALLE, "tecla": KEY_F3},
	{"id": "capa_del_minimapa", "rotulo": "Cambiar la capa del minimapa",
		"ambito": Ambito.VALLE, "tecla": KEY_R},
	{"id": "capa_de_navegacion", "rotulo": "La capa de navegación (desarrollo)",
		"ambito": Ambito.VALLE, "tecla": KEY_N, "oculta": true},

	# --- el mapa regional ---
	{"id": "resolver", "rotulo": "Resolver la estación",
		"ambito": Ambito.REGIONAL, "tecla": KEY_SPACE},
	{"id": "fundar", "rotulo": "Fundar un campamento",
		"ambito": Ambito.REGIONAL, "tecla": KEY_F},
	{"id": "ficha_del_sitio", "rotulo": "La ficha del yacimiento",
		"ambito": Ambito.REGIONAL, "tecla": KEY_R},
	{"id": "cambiar_era", "rotulo": "Pasar a la era siguiente",
		"ambito": Ambito.REGIONAL, "tecla": KEY_E},
]

## Lo que hace el ratón, que no se cambia (la spec lo deja fuera). Está aquí para que la
## ventana de controles lo enseñe **del catálogo y no de un texto a mano**: la que había
## escrita a mano anunciaba una «B — modo construcción» que no existe en el juego.
const EL_RATON: Array[Dictionary] = [
	{"rotulo": "Ver la ficha de una persona, un recurso o una cueva", "como": "Clic"},
	{"rotulo": "Girar la cámara", "como": "Botón derecho"},
	{"rotulo": "Acercar y alejar", "como": "Rueda"},
]

## La tecla de cada acción ahora mismo. Se llena de [CATALOGO] y la cambia el jugador.
static var puestas: Dictionary = {}


## Las de siempre, las del catálogo.
static func por_defecto() -> void:
	puestas = {}
	for fila: Dictionary in CATALOGO:
		puestas[fila["id"]] = fila["tecla"]
	aplicar()


## Deja el `InputMap` con lo que dice [puestas].
##
## Por **código físico** y no por el carácter, como ya hacía el mapa del proyecto: en un
## teclado francés la W está donde en el nuestro la Z, y lo que el jugador quiere es la
## tecla donde la tiene la mano.
static func aplicar() -> void:
	if puestas.is_empty():
		por_defecto()
		return
	for fila: Dictionary in CATALOGO:
		var id: String = fila["id"]
		if not InputMap.has_action(id):
			InputMap.add_action(id)
		InputMap.action_erase_events(id)
		var evento := InputEventKey.new()
		evento.physical_keycode = int(puestas.get(id, fila["tecla"])) as Key
		InputMap.action_add_event(id, evento)


# --- COMO SE PREGUNTA. Todo el juego pasa por aquí -------------------------------
#
# Y no por `Input.is_action_pressed` a pelo, por una razón práctica: una sonda que
# arranca `demo_main` sin pasar por el menú principal no ha leído la configuración, así
# que el `InputMap` no tendría ninguna de estas acciones y Godot daría «request for
# nonexistent InputMap action». Preguntando por aquí, la primera pregunta las monta.

## Si la acción está pulsada ahora mismo.
static func pulsada(id: String) -> bool:
	_asegurar()
	return Input.is_action_pressed(id)


## Si este evento es el de esta acción, recién pulsada. Sustituye a los
## `match event.keycode` que había en el valle y en el regional.
static func es(evento: InputEvent, id: String) -> bool:
	_asegurar()
	return evento.is_action_pressed(id)


static func _asegurar() -> void:
	if puestas.is_empty():
		por_defecto()


## La tecla de una acción, o la de siempre si no está puesta.
static func tecla_de(id: String) -> Key:
	return int(puestas.get(id, _del_catalogo(id).get("tecla", NINGUNA))) as Key


## Cómo se lee una tecla en pantalla.
static func nombre_de_la_tecla(tecla: Key) -> String:
	if tecla == NINGUNA:
		return "—"
	return OS.get_keycode_string(tecla)


## Las acciones con las que ésta chocaría si se le pusiera `tecla`.
##
## Dos acciones chocan si comparten la tecla **y** se pueden pulsar en la misma pantalla:
## el mismo ámbito, o una de las dos en todas partes. Ver [Ambito].
static func choca_con(id: String, tecla: Key) -> Array[String]:
	var mio: Ambito = _del_catalogo(id).get("ambito", Ambito.SIEMPRE)
	var chocan: Array[String] = []
	for fila: Dictionary in CATALOGO:
		var otro: String = fila["id"]
		if otro == id or tecla_de(otro) != tecla:
			continue
		var suyo: Ambito = fila["ambito"]
		if suyo == mio or suyo == Ambito.SIEMPRE or mio == Ambito.SIEMPRE:
			chocan.append(otro)
	return chocan


## Pone una tecla a una acción, sin mirar si choca. Devuelve false si la acción no
## existe o no se cambia (ESC).
static func poner(id: String, tecla: Key) -> bool:
	var fila := _del_catalogo(id)
	if fila.is_empty() or bool(fila.get("fija", false)):
		return false
	if puestas.is_empty():
		por_defecto()
	puestas[id] = tecla
	aplicar()
	return true


## Cambia dos acciones sus teclas. Es lo que se ofrece cuando una choca con otra.
static func intercambiar(uno: String, otro: String) -> bool:
	var del_uno := tecla_de(uno)
	var del_otro := tecla_de(otro)
	if not poner(uno, del_otro):
		return false
	if not poner(otro, del_uno):
		poner(uno, del_uno)
		return false
	return true


## El rótulo de una acción, para la ventana y para los avisos.
static func rotulo_de(id: String) -> String:
	return _del_catalogo(id).get("rotulo", id)


## Las acciones de un ámbito que salen en la ventana del jugador.
static func del_ambito(cual: Ambito) -> Array[Dictionary]:
	var filas: Array[Dictionary] = []
	for fila: Dictionary in CATALOGO:
		if fila["ambito"] == cual and not bool(fila.get("oculta", false)):
			filas.append(fila)
	return filas


static func nombre_del_ambito(cual: Ambito) -> String:
	return ["En todas partes", "En el valle", "En el mapa regional"][cual]


static func _del_catalogo(id: String) -> Dictionary:
	for fila: Dictionary in CATALOGO:
		if fila["id"] == id:
			return fila
	return {}


# --- guardar y leer. Lo llama [Configuracion], que es la dueña del fichero ---

## Lo puesto, para el `[teclas]` del fichero de configuración.
static func para_guardar() -> Dictionary:
	if puestas.is_empty():
		por_defecto()
	return puestas.duplicate()


## Lee lo guardado. Lo que no traiga el fichero se queda con la tecla de siempre, que es
## lo que deja añadir acciones nuevas sin que a nadie se le borre lo suyo.
static func cargar_de(guardado: Dictionary) -> void:
	puestas = {}
	for fila: Dictionary in CATALOGO:
		var id: String = fila["id"]
		var tecla: Key = int(guardado.get(id, fila["tecla"])) as Key
		# ESC no se cambia ni editando el fichero a mano: es la salida de todo.
		if bool(fila.get("fija", false)):
			tecla = fila["tecla"]
		puestas[id] = tecla
	aplicar()
