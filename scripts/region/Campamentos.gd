class_name Campamentos
extends RefCounted
## Los campamentos vivos de la partida, y el reloj que los lleva a todos.
##
## SISTEMAS §23, tarea 5. **Viven fuera de las escenas**: cada [Campamento] y el
## [RelojDeLaPartida] cuelgan de la raíz del árbol, no de la escena que se esté
## mirando, y por eso `change_scene_to_file` no los destruye. Así un campamento
## sigue simulando mientras se mira otro mapa o el regional.
##
## **Cambia el contrato de SPECS §2.2 y §6.4, y se dice**: no es un autoload
## —nada en `project.godot`—, pero sí es estado que sobrevive a las escenas.
## La estática es sólo el índice, como pide §2.2; los nodos cuelgan de la raíz
## porque un `Node` que simula tiene que estar en el árbol para que le llegue
## `_process`.

## Los campamentos dados de alta, en orden de alta. El primero gira la estación:
## ver [RelojDeLaPartida._repartir_el_giro].
static var vivos: Array[Campamento] = []

## El reloj de la partida. Se crea con el primer campamento.
static var reloj: RelojDeLaPartida = null

## Los grupos que van de camino entre campamentos. No están en ninguno: ver
## [Viaje].
static var viajes: Array[Viaje] = []

## El árbol donde se montan los campamentos que se fundan al llegar un viaje.
static var _arbol: SceneTree = null

## Quién quiere enterarse de que hay un campamento nuevo: la interfaz, para
## escuchar sus decisiones (SISTEMAS §23, punto 7). Cada uno recibe el
## `Campamento`.
static var al_sumarse: Array[Callable] = []

## Las decisiones y avisos que salen **sin interfaz que los escuche** —en el mapa
## regional—. Una decisión para la partida hasta que se enseña: si no, se perdería
## sin contestar y el campamento seguiría como si nadie la hubiera levantado. Las
## recoge [GameUI] al montarse.
static var sin_ver: Array[Moment] = []


## Da de alta un campamento ya montado: lo cuelga de la raíz si no colgaba de
## nada, y su simulación pasa a llevarla el reloj de la partida.
##
## Tiene que tener ya la simulación —ver [Campamento.levantar_la_simulacion]—:
## el reloj dirige simulaciones, no mapas vacíos.
static func alta(arbol: SceneTree, campamento: Campamento) -> void:
	if vivos.has(campamento):
		return
	_arbol = arbol
	if reloj == null or not is_instance_valid(reloj):
		reloj = RelojDeLaPartida.new()
		reloj.name = "RelojDeLaPartida"
		arbol.root.add_child(reloj)
		reloj.jornada_cerrada.connect(_nueva_jornada)
	if campamento.get_parent() == null:
		arbol.root.add_child(campamento)
	vivos.append(campamento)
	# SU RECUADRO SE VE: un campamento, habitado o no, conoce su valle (SISTEMAS
	# §4). Fuera del paso, así que va directo a la partida.
	if campamento.sitio != null:
		GameState.levantar_niebla({"forma": "recuadro", "lon": campamento.sitio.lon,
			"lat": campamento.sitio.lat, "lado": float(Expedition.local_size_m)})
	if campamento.sim != null:
		reloj.dirigir(campamento.sim)
		if not campamento.sim.moment_raised.is_connected(_al_levantarse):
			campamento.sim.moment_raised.connect(_al_levantarse)
	for quien: Callable in al_sumarse:
		if quien.is_valid():
			quien.call(campamento)


static func _al_levantarse(moment: Moment) -> void:
	if not al_sumarse.is_empty():
		return  # hay una interfaz escuchando: ella lo enseña
	sin_ver.append(moment)
	if moment.is_decision() and reloj != null and is_instance_valid(reloj):
		reloj.time_scale = 0.0


## Saca del árbol un campamento que nadie mira. Sigue vivo —lo guarda [vivos]— y
## sigue dando pasos, porque se los da el reloj.
##
## **Por qué fuera del árbol**, y es lo que costó la primera corrida en paralelo:
## Godot no deja tocar un nodo del árbol desde otro hilo, y el paso lo toca sin
## querer —`TerrainGenerator.get_height_at` lee `global_position`, y la
## simulación emite sus señales—. Medido el 2026-09-14: 46 000 errores en diez
## jornadas, las alturas por defecto y ni una `day_passed`. Un nodo fuera del
## árbol se usa desde cualquier hilo. Lo que se pierde es lo que sólo hace falta
## si se mira: dibujar, y el `_process` de cada nodo —el horno de rejillas lo
## amasa el reloj—.
static func dejar_de_mirar(campamento: Campamento) -> void:
	if campamento.sim != null:
		campamento.sim.se_mira = false
	if campamento.is_inside_tree():
		campamento.get_parent().remove_child(campamento)


## Suelta el campamento de una escena que se va, **aunque se vaya sin avisar**. Lo
## hacen `DemoMain._dejar_la_escena` y, por si un camino se olvida de ella, su
## `_exit_tree`: la escena se libera con todo lo que cuelga de ella, y un campamento
## vivo dentro se iba con ella —la banda entera— dejando al reloj y a [vivos] con un
## objeto liberado. Así salían los `SCRIPT ERROR` de `TransitoProbe` (2026-09-15).
##
## Sirve durante la salida del árbol: los hijos ya han salido y el padre ya no está
## ocupado, así que se puede quitar el hijo. `TestViaje`.
static func soltar_de_la_escena(escena: Node, campamento: Campamento) -> void:
	if campamento == null or not is_instance_valid(campamento) or not vivos.has(campamento):
		return
	if campamento.sim != null:
		campamento.sim.se_mira = false
	if campamento.get_parent() == escena:
		escena.remove_child(campamento)


## Da de baja un campamento: su simulación deja de llevarla el reloj. No lo
## destruye —abandonar un campamento no borra lo que se dejó, §23 punto 6—.
static func baja(campamento: Campamento) -> void:
	vivos.erase(campamento)
	if reloj != null and is_instance_valid(reloj) and campamento.sim != null:
		reloj.soltar(campamento.sim)


## Deja el traspaso para que la escena local adopte este campamento: sin visita,
## sin retomar de disco, y el relieve y el recuadro suyos. Lo usan el mapa
## regional y el salto directo desde la lista de campamentos.
static func traspaso_de(campamento: Campamento) -> void:
	Expedition.visita = false
	Expedition.retomando = false
	Expedition.site = campamento.sitio
	Expedition.heightmap_path = campamento.relieve
	Expedition.region_offset = campamento.recuadro
	Expedition.sea_level_m = GameState.sea_level_m
	Expedition.era = GameState.era


## El campamento de un sitio, o null.
static func de_sitio(id: int) -> Campamento:
	for campamento: Campamento in vivos:
		if campamento.sitio != null and campamento.sitio.id == id:
			return campamento
	return null


## Libera todo: la partida que se cierra, o la prueba que termina.
static func vaciar() -> void:
	# El reloj suelta antes sus simulaciones: si no, en el fotograma siguiente
	# pregunta `is_inside_tree` a una simulación ya liberada. Salió al cerrar cada
	# corrida de `CampamentosProbe` (2026-09-14).
	if reloj != null and is_instance_valid(reloj):
		reloj.campamentos.clear()
	for campamento: Campamento in vivos:
		if not is_instance_valid(campamento):
			continue
		# Fuera del árbol no hay cola de borrado que lo recoja.
		if campamento.is_inside_tree():
			campamento.queue_free()
		else:
			campamento.free()
	vivos.clear()
	viajes.clear()
	sin_ver.clear()
	if reloj != null and is_instance_valid(reloj):
		reloj.queue_free()
	reloj = null


# --- migrar y mover gente ----------------------------------------------------

## Manda a un grupo de un campamento a un sitio. Null si no puede salir, con el
## porqué en [Viaje.ultimo_motivo]. Ver SISTEMAS §23, puntos 2 y 3.
##
## El valle de destino tiene que estar preparado —decisión del usuario del
## 2026-09-14: se prepara al mandar el viaje, no al llegar—.
static func mandar(origen: Campamento, grupo: Array, hasta: Site) -> Viaje:
	if hasta != null and de_sitio(hasta.id) == null and not Campamento.valle_preparado(hasta.id):
		Viaje.ultimo_motivo = "el valle de %s no está preparado" % hasta.display_name()
		return null
	var dia := reloj.dia if reloj != null else origen.sim.day
	var viaje := Viaje.salir(origen.sim, grupo, origen.sitio, hasta, dia)
	if viaje != null:
		viajes.append(viaje)
	return viaje


## Una jornada nueva de la partida: los viajes andan, y quien llega, llega. Lo
## llama el reloj en la barrera, en el hilo principal.
static func _nueva_jornada(dia: int) -> void:
	var llegados: Array[Viaje] = []
	for viaje: Viaje in viajes:
		viaje.nueva_jornada(dia)
		if viaje.ha_llegado(dia):
			llegados.append(viaje)
	for viaje: Viaje in llegados:
		viajes.erase(viaje)
		_llegar(viaje)


## Llegar: **se suman** a un campamento con gente, **lo reocupan** si está vacío
## —con todo lo que se dejó— o **lo fundan** si no lo hay. SISTEMAS §23, punto 2.
static func _llegar(viaje: Viaje) -> void:
	var destino := de_sitio(viaje.hasta_id)
	if destino == null:
		destino = _fundar(viaje.hasta_id)
		if destino == null:
			push_warning("Campamentos: no se pudo fundar en el sitio %d" % viaje.hasta_id)
			return
	elif destino.sim.people.is_empty():
		# REOCUPAR: el campamento se quedó en la jornada en que se vació. Se pone
		# en la de la partida, que es la de todos.
		a_la_fecha(destino.sim)
	viaje.llegar_a(destino.sim)


## Monta un campamento nuevo para un grupo que llega, sin gente propia, en la
## fecha de la partida, y lo da de alta sin mirar.
static func _fundar(id: int) -> Campamento:
	if _arbol == null:
		return null
	var comarca := load("res://data/sites/cantabria_sites.res") as SiteSet
	var sitio: Site = null
	for s: Site in comarca.sites:
		if s.id == id:
			sitio = s
	var campamento := Campamento.montar(_arbol, sitio, 0, 0.0)
	if campamento == null:
		return null
	a_la_fecha(campamento.sim)
	campamento.mirar_las_cumbres()
	campamento.revisar_hallazgos()
	campamento.elegir_tajos(campamento.casa())
	alta(_arbol, campamento)
	dejar_de_mirar(campamento)
	return campamento


## Pone una simulación en la fecha de la partida: jornada, hora y día de la
## estación —si no, un campamento fundado a mitad de estación la giraría en otra
## jornada que los demás—, y su copia de estación y año.
static func a_la_fecha(sim: SettlementSim) -> void:
	if reloj == null or not is_instance_valid(reloj):
		return
	sim.day = reloj.dia
	sim.hour = reloj.hora
	sim.season_day = reloj.dia_de_estacion
	sim._estacion = GameState.season
	sim._anyo = GameState.year

