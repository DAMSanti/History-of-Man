class_name Carga
extends RefCounted
## Las cargas largas del juego, repartidas entre cuadros y enseñadas. INTERFAZ §9.
##
## Quien va a cambiar de escena abre la pantalla (`abrir`) ANTES de pedir el cambio; la
## escena que se monta declara sus etapas, las recorre, y llama a `ceder` dentro de sus
## bucles largos. Al terminar, `cerrar`.
##
## **Sin pantalla abierta no se reparte nada**: `ceder` vuelve sin esperar, y la escena se
## monta de un tirón como siempre. Así las sondas que cambian de escena y esperan
## cuadros fijos siguen igual, y la partida cargada con y sin pantalla es la misma
## —que es la prueba de que la pantalla no cambia lo que se carga—.
##
## Estado estático y no un autoload (SPECS §2.2): la pantalla tiene que sobrevivir al
## cambio de escena, igual que `Campamentos`.

## Cuánto trabajo cabe en un cuadro antes de ceder, en microsegundos. **Decisión**: la
## mitad de los 500 ms de la spec, para dejar sitio a lo que el motor hace entre dos
## cuadros —cambiar de escena, pintar, subir mallas—.
const PRESUPUESTO_USEC := 250000
## Por encima de esto no se empieza un paso del que se sabe lo que cuesta: se cede antes.
## Con sólo el presupuesto, un paso de 370 ms que empezaba con el cuadro a 240 ms salía un
## cuadro de 610 (medido al fundar, 2026-09-15). Decisión: 50 ms de margen sobre el
## criterio.
const TOPE_USEC := 450000

static var _pantalla: PantallaDeCarga = null
## Cuándo se abrió la pantalla, en microsegundos: lo que pasa hasta que la escena declara
## sus etapas es de la primera. Ver [RepartoDeCarga.etapas].
static var _abierta_desde := 0
static var _reparto := RepartoDeCarga.new()
## Cuándo empezó el cuadro, en microsegundos: lo pone la señal `process_frame`.
static var _desde := 0


static func abierta() -> bool:
	return _pantalla != null and is_instance_valid(_pantalla)


## Abre la pantalla con su título. Si ya está abierta, sólo cambia el título: una carga
## que encadena dos no parpadea.
static func abrir(arbol: SceneTree, titulo: String) -> void:
	if not abierta():
		_reparto = RepartoDeCarga.new()
		_pantalla = PantallaDeCarga.new()
		arbol.root.add_child(_pantalla)
		if not arbol.process_frame.is_connected(_al_empezar_el_cuadro):
			arbol.process_frame.connect(_al_empezar_el_cuadro)
		_desde = Time.get_ticks_usec()
		_abierta_desde = _desde
	_pantalla.titulo = titulo


static func cerrar() -> void:
	if abierta():
		_reparto.terminar()
		_pantalla.queue_free()
		var arbol := _pantalla.get_tree()
		if arbol != null and arbol.process_frame.is_connected(_al_empezar_el_cuadro):
			arbol.process_frame.disconnect(_al_empezar_el_cuadro)
	_pantalla = null


## Las etapas de lo que viene: `[[texto, peso_ms], ...]`. Ver [RepartoDeCarga.etapas].
static func etapas(lista: Array) -> void:
	# La primera declaración tras abrir cuenta desde que se abrió; las que encadenan otra
	# carga detrás —el valle y luego el mapa— empiezan cuando se declaran.
	var primera := _reparto.valor() <= 0.0 and _reparto.texto().is_empty()
	_reparto.etapas(lista, _abierta_desde if primera else 0)


static func etapa(indice: int) -> void:
	_reparto.etapa(indice)


static func avanzar_por_tiempo() -> void:
	_reparto.avanzar_por_tiempo()


static func siguiente() -> void:
	_reparto.siguiente()


static func avanzar(fraccion: float) -> void:
	_reparto.avanzar(fraccion)


static func dar_por_hecha_la_etapa() -> void:
	_reparto.dar_por_hecha_la_etapa()


static func valor() -> float:
	return _reparto.valor()


static func texto() -> String:
	return _reparto.texto()


## Si ya se ha gastado el presupuesto del cuadro, espera al siguiente. Se llama con
## `await` dentro de los bucles largos; sin pantalla vuelve en el acto.
##
## El presupuesto se cuenta DESDE QUE EMPEZÓ EL CUADRO, no desde la primera llamada: el
## cambio de escena y lo que se monta antes de la primera llamada también son del cuadro,
## y contándolo desde la llamada el primer cuadro de la carga salía de 900 ms.
##
## `lo_que_viene_ms`, si se sabe, es lo que va a costar el paso siguiente sin ceder: si no
## cabe en lo que queda del cuadro, se cede antes de empezarlo.
static func ceder(lo_que_viene_ms: float = 0.0) -> void:
	if not abierta():
		return
	var gastado := Time.get_ticks_usec() - _desde
	if gastado < PRESUPUESTO_USEC and gastado + int(lo_que_viene_ms * 1000.0) <= TOPE_USEC:
		return
	await (Engine.get_main_loop() as SceneTree).process_frame


## `ceder` que además mueve la barra por el tiempo. Es lo que se pasa a quien no sabe
## nada de pantallas —la simulación, el relieve— como su `ceder`.
static func ceder_y_avanzar() -> void:
	_reparto.avanzar_por_tiempo()
	await ceder()


static func _al_empezar_el_cuadro() -> void:
	_desde = Time.get_ticks_usec()


## Carga un recurso. Con pantalla, en un hilo del cargador de Godot, esperando cuadro a
## cuadro: un solo `load` de la biblioteca de props —431 MB— congelaba más de un segundo.
## Sin pantalla, `load` de siempre.
static func cargar(ruta: String) -> Resource:
	if not abierta():
		return load(ruta)
	if ResourceLoader.load_threaded_request(ruta) != OK:
		return load(ruta)
	var arbol := Engine.get_main_loop() as SceneTree
	while ResourceLoader.load_threaded_get_status(ruta) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await arbol.process_frame
	return ResourceLoader.load_threaded_get(ruta)


## Cambia de escena cargándola antes en un hilo, con la pantalla ya abierta. Con
## `change_scene_to_file` la escena se lee del disco en el cuadro del cambio, y la
## primera vez que se entra en el mapa regional eso era un cuadro de 800 ms.
static func cambiar_de_escena(arbol: SceneTree, ruta: String) -> void:
	var escena := await cargar(ruta) as PackedScene
	if escena == null:
		arbol.change_scene_to_file(ruta)
		return
	arbol.change_scene_to_packed(escena)


## Si un texto de etapa se puede enseñar: en el lenguaje del juego, sin nombres del
## motor ni del código. Lo usan las pruebas sobre las etapas de cada escena.
static func texto_valido(texto: String) -> bool:
	if texto.strip_edges().is_empty():
		return false
	var regla := RegEx.new()
	# Guion bajo, extensión de fichero, paréntesis de llamada o una palabra EnCamello.
	regla.compile("_|\\.(gd|res|tscn)\\b|\\(|\\b[a-záéíóúñ]+[A-Z]|\\b[A-Z][a-z]+[A-Z]")
	return regla.search(texto) == null
