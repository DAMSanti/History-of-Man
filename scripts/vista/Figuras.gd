class_name Figuras
extends Node3D
## Donde se DIBUJA cada persona, que no siempre es donde esta. GRAFICOS §7.6.
##
## Emite [pintadas] al acabar cada cuadro: quien quiera leer donde esta cada figura tiene
## que hacerlo AHI y no en su propio `_process`. La camara que sigue a alguien lo hacia por
## su cuenta y salia un cuadro por detras -**54 m de desvio, medido**, que es lo que anda
## una persona entre dos cuadros a x1-.
##
## Un dia de juego son 120 s reales, o sea que la gente anda 900 m por segundo de
## pantalla. Un viaje al tajo dura dos segundos y lo que se ve son muñecos cruzando el
## valle como disparos. Aqui se separa lo que se ve de lo que se simula: **el viaje largo
## se abrevia**, se ve salir andando y llegar andando, y por el medio va una marca.
##
## **No decide nada de la partida** (SPECS §4.7): nadie lee de aqui para nada, y la
## prueba de la firma lo comprueba. La simulacion dice donde esta cada uno y esto dice
## donde se le pinta.


## Las figuras de este cuadro ya estan puestas. Ver arriba.
signal pintadas

## Desde que largo se abrevia un viaje. Por debajo, la figura va pegada a la persona como
## siempre: un trayecto corto se lee aunque sea un salto. De la spec.
const LARGO_M := 150.0

## Lo mas deprisa que se dibuja a alguien andando, en metros por segundo REAL. De la spec:
## por encima de esto la vista ya no lo sigue.
const PASO_MAXIMO := 8.0

## Lo que puede retrasarse la figura respecto a la persona, en segundos reales. De la
## spec.
const RETRASO_TOPE := 1.5

## Lo que se anda a la salida y a la llegada, en metros.
##
## **La spec pedia 20 m y no cuadraban sus propios numeros**: 20 m a 8 m/s son 2,5 s, y la
## misma spec pone el retraso en 1,5 s como mucho. Los dos criterios son medibles y se
## contradicen, asi que el tramo sale de ellos y no al reves: 8 m/s x 1,5 s = 12 m. Es la
## mayor distancia que se puede andar a paso legible sin descolgar la figura mas de lo que
## la spec permite. Ver GRAFICOS §7.6, «Cómo quedó».
const TRAMO_M := PASO_MAXIMO * RETRASO_TOPE

## De que color va la marca de cada oficio.
##
## **Es la primera paleta por oficio del juego** (decision del usuario, 2026-09-17): no
## habia ninguna, ni por persona ni por oficio —el minimapa pinta a toda la banda del
## mismo amarillo—. Vive aqui porque hoy es su unico consumidor; el dia que la quieran el
## minimapa o los paneles, se muda a un sitio comun y esto la pide alli.
const COLOR_DEL_OFICIO := {
	Profession.Job.CAZA: Color(0.85, 0.35, 0.25),        # ocre rojo
	Profession.Job.RIBERA: Color(0.30, 0.62, 0.80),      # azul de agua
	Profession.Job.RECOLECCION: Color(0.55, 0.75, 0.35), # verde de monte
	Profession.Job.MANUFACTURA: Color(0.80, 0.68, 0.35), # asta
	Profession.Job.EXPLORACION: Color(0.72, 0.45, 0.80), # morado
	Profession.Job.HOGAR: Color(0.95, 0.72, 0.40),       # lumbre
	Profession.Job.OCIOSO: Color(0.70, 0.70, 0.68),      # ceniza
}

## Lo que mide la marca, en metros. Pequeña a proposito: dice por donde va alguien, no
## hace de personaje.
const MARCA_M := 1.4

## Lo que se sabe de cada figura: donde se la pinta, si se ve y si su viaje es largo.
## Por indice de persona.
var _pintadas: Dictionary = {}

## La banda dibujada, para escribirle la pose. La pone [SettlementSim] al montar.
var crowd: BandaCrowd = null

## De quien son las figuras. Se lee `people`, `_bodies` y `_headings`.
var sim: SettlementSim = null

var _marcas: MultiMeshInstance3D = null

## Las marcas de este cuadro: `donde` y `color`, en el orden en que se dibujan.
##
## Se guarda aparte de la malla porque **un `MultiMesh` no devuelve lo que se le escribe
## sin ventana**: `--headless` no tiene donde guardar las instancias y `get_instance_*`
## contesta ceros, asi que una prueba de la suite no puede mirar ahi. Lo que se comprueba
## en la suite es esta lista -la decision- y que se dibujan, la sonda con ventana.
var marcas_puestas: Array[Dictionary] = []

## Cuanta gente habia el cuadro pasado. Ver [_process].
var _cuantos_habia := 0


func _init() -> void:
	# La malla se crea al CREAR el nodo y no en `_ready`: la prueba lo usa sin meterlo en
	# ninguna escena, y con las marcas a medias reventaba al pintarlas.
	_montar_las_marcas()


func _ready() -> void:
	# Y se cuelga aqui. Colgarla dentro de `_init` -que es legal- dejaba el juego
	# reventando al salir, con `Segmentation fault` despues del ultimo cuadro.
	if _marcas != null and _marcas.get_parent() == null:
		add_child(_marcas)


## Un cuadrito de color por viaje en curso, todos en un dibujo. Sin luz: es una señal de
## interfaz puesta en el mundo, no un objeto que esté ahí.
func _montar_las_marcas() -> void:
	var malla := QuadMesh.new()
	malla.size = Vector2(MARCA_M, MARCA_M)
	malla.orientation = PlaneMesh.FACE_Y
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	malla.material = material
	_marcas = MultiMeshInstance3D.new()
	_marcas.name = "MarcasDeViaje"
	_marcas.multimesh = MultiMesh.new()
	_marcas.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_marcas.multimesh.use_colors = true
	_marcas.multimesh.mesh = malla
	# Las marcas andan por todo el valle: con la caja de serie el motor las descartaba en
	# cuanto la que las creó salía de cuadro. Ver la memoria de las partículas.
	_marcas.custom_aabb = AABB(Vector3(-5000.0, -500.0, -5000.0),
		Vector3(10000.0, 2000.0, 10000.0))


## Lo llama [SettlementSim] cuando pinta a alguien: aquí se apunta dónde está de verdad.
func anotar(person: Inhabitant, index: int) -> void:
	var ficha: Dictionary = _pintadas.get(index, {})
	if ficha.is_empty():
		ficha = {"donde": person.position, "se_ve": true, "fase": Fase.PEGADA,
			"ruta": PackedVector3Array(), "destino": Vector3.INF, "avance": 0.0}
		_pintadas[index] = ficha
	ficha["se_ve"] = true


## Se ha ido del mapa: ni figura ni marca hasta que vuelva.
func esconder(index: int) -> void:
	var ficha: Dictionary = _pintadas.get(index, {})
	if not ficha.is_empty():
		ficha["se_ve"] = false


## DONDE SE LE VE a esta persona: la figura dibujada, o la marca si va escondida.
##
## Es lo que sigue la camara (INTERFAZ §13): seguir `person.position` a secas dejaria a la
## persona fuera del centro justo cuando se la ve andar, que es el unico rato en que la
## figura y lo simulado no coinciden. Y por el medio de un viaje abreviado lo que se ve es
## la marca, que si va en lo simulado.
func donde_se_ve(index: int, person: Inhabitant) -> Vector3:
	var ficha: Dictionary = _pintadas.get(index, {})
	if not ficha.is_empty() and int(ficha.get("fase", Fase.PEGADA)) == Fase.MEDIO:
		return ficha.get("marca", person.position)
	return donde(index, person.position)


## En qué fase va la figura de esta persona. Ver [Fase].
func fase_de(index: int) -> int:
	var ficha: Dictionary = _pintadas.get(index, {})
	return int(ficha.get("fase", Fase.PEGADA)) if not ficha.is_empty() else Fase.PEGADA


## Dónde se está pintando a esta persona.
func donde(index: int, si_no_hay: Vector3) -> Vector3:
	var ficha: Dictionary = _pintadas.get(index, {})
	return ficha.get("donde", si_no_hay) if not ficha.is_empty() else si_no_hay


## En que va la figura de esta persona. Ver [_llevar].
enum Fase {
	PEGADA,   ## Donde esta la persona, sin mas: no hay viaje largo que abreviar
	SALIDA,   ## Andando los primeros metros del camino
	MEDIO,    ## Escondida; lo que se ve es la marca
	LLEGADA,  ## Andando los ultimos metros
}


func _process(delta: float) -> void:
	if sim == null or crowd == null or sim.people.is_empty():
		return
	# Las fichas van por INDICE, y `despedir` quita a alguien de en medio: a partir de
	# ahi cada figura llevaria la posicion de otra. Se tiran y se vuelven a llenar, que
	# es cosmetico y cuesta un cuadro.
	if sim.people.size() != _cuantos_habia:
		_cuantos_habia = sim.people.size()
		_pintadas.clear()
		return
	Cronometro.tramo_raiz("vista: figuras")
	var en_viaje: Array[Dictionary] = []
	for index in range(sim.people.size()):
		var person: Inhabitant = sim.people[index]
		var ficha: Dictionary = _pintadas.get(index, {})
		if ficha.is_empty() or not bool(ficha["se_ve"]):
			continue
		var donde_va := _llevar(ficha, person, delta)
		var escondida: bool = ficha["fase"] == Fase.MEDIO
		if escondida:
			# Y SE GUARDA DONDE SE PUSO LA MARCA, que es lo que se ve de esa persona este
			# cuadro. Leerlo luego de `person.position` daria un sitio distinto: la
			# simulacion da su paso despues y a x1 mueve a alguien decenas de metros entre
			# dos cuadros. Ver [donde_se_ve], que es lo que sigue la camara.
			ficha["marca"] = person.position
			en_viaje.append({"donde": person.position, "oficio": person.job})
		_pintar(person, index, donde_va, escondida)
	_poner_las_marcas(en_viaje)
	Cronometro.cierra("vista: figuras")
	pintadas.emit()


## Lleva la figura y devuelve dónde queda.
##
## **La figura anda por SU camino y a SU ritmo, no detrás de la persona**, y ésa es la
## corrección que costó la sonda. La primera versión la llevaba hacia la posición
## simulada y decidía si se la veía mirando dónde estaba *la persona*: cerca del
## principio del camino o cerca del final. Con la partida a ×1 **la simulación mueve a
## alguien de quince a sesenta metros por cuadro**, así que «estar en los primeros doce
## metros» es un estado por el que se pasa en un solo fotograma, o que se salta entero.
## Medido: figuras a **883 m/s** y retrasos de **64 m**, con los topes en 8 m/s y 12 m.
##
## Ahora la figura tiene fases y un avance propio a lo largo de la ruta:
##
##   - **SALIDA**: anda los primeros [TRAMO_M] metros del camino a [PASO_MAXIMO].
##     Dura [RETRASO_TOPE] segundos exactos, porque los metros y el paso son fijos.
##   - **MEDIO**: escondida. Lo que se ve es la marca, que va en lo simulado.
##   - **LLEGADA**: reaparece a [TRAMO_M] del final y los anda. Otro tanto.
##
## Así ninguna de las dos cifras depende de cuánto corra la simulación entre cuadros:
## mientras se la ve, la figura avanza `PASO_MAXIMO * delta` y nada más.
func _llevar(ficha: Dictionary, person: Inhabitant, delta: float) -> Vector3:
	var ruta: PackedVector3Array = person.route
	if ruta.size() < 2:
		# Sin camino: o no va a ninguna parte, o acaba de llegar. Si estaba llegando, se
		# le deja terminar su tramo con la ruta que traía.
		ruta = ficha.get("ruta", PackedVector3Array())
	var largo := _largo_de(ruta)
	if largo <= LARGO_M or ruta.size() < 2:
		ficha["fase"] = Fase.PEGADA
		ficha["ruta"] = PackedVector3Array()
		ficha["donde"] = person.position
		return person.position

	# ¿Es otro viaje? Se mira por el destino: replanificar a medio camino cambia el
	# principio de la ruta pero no adónde se va.
	var destino := ruta[ruta.size() - 1]
	if ficha["fase"] == Fase.PEGADA or destino.distance_to(
			ficha.get("destino", Vector3.INF)) > 1.0:
		ficha["ruta"] = ruta
		ficha["destino"] = destino
		# SI EL CAMINO NUEVO NO EMPIEZA DONDE ESTA LA FIGURA, no se la ve salir: se
		# esconde y se va al medio del viaje. Pasa cuando alguien replanifica a otro sitio
		# a mitad de camino —la ruta nueva empieza donde esta EL, que puede ser a un
		# kilometro de donde va la figura—, y ponerla en el principio del camino nuevo era
		# un salto de kilometros con la figura a la vista: **3 374 m/s, medido**, con el
		# tope en ocho.
		var lejos: bool = Vector3(ficha["donde"]).distance_to(ruta[0]) > TRAMO_M
		ficha["fase"] = Fase.MEDIO if lejos else Fase.SALIDA
		ficha["avance"] = TRAMO_M if lejos else 0.0
		if not lejos:
			ficha["donde"] = ruta[0]
		return ficha["donde"]
	# La ruta de la ficha es la buena mientras dure el viaje: la de la persona se recorta
	# según anda, y la figura necesita la entera para medir su avance.
	ruta = ficha["ruta"]
	largo = _largo_de(ruta)

	var avance: float = ficha["avance"]
	match int(ficha["fase"]):
		Fase.SALIDA:
			avance += PASO_MAXIMO * delta
			if avance >= TRAMO_M:
				ficha["fase"] = Fase.MEDIO
		Fase.MEDIO:
			# Se reaparece cuando la persona está a un tramo del final, o ya ha llegado.
			var le_falta := person.position.distance_to(destino)
			if le_falta <= TRAMO_M or person.route.size() < 2:
				ficha["fase"] = Fase.LLEGADA
				avance = maxf(largo - TRAMO_M, 0.0)
		Fase.LLEGADA:
			avance += PASO_MAXIMO * delta
			if avance >= largo:
				avance = largo
				ficha["fase"] = Fase.PEGADA
				# Y SE TIRA LA RUTA. Sin esto el viaje volvía a empezar en cuanto
				# terminaba: arriba, «¿es otro viaje?» mira si la fase es PEGADA, y con
				# la ruta todavía guardada la respuesta era que sí, para siempre. En la
				# prueba salían 321 cuadros de salida donde tenía que haber 90.
				ficha["ruta"] = PackedVector3Array()
				ficha["destino"] = Vector3.INF
	ficha["avance"] = avance
	var donde_va := _punto_en(ruta, avance)
	ficha["donde"] = donde_va
	return donde_va


## El punto de la ruta a `metros` de su principio, andando por ella.
static func _punto_en(ruta: PackedVector3Array, metros: float) -> Vector3:
	if ruta.is_empty():
		return Vector3.ZERO
	var queda := maxf(metros, 0.0)
	for i in range(1, ruta.size()):
		var tramo := ruta[i - 1].distance_to(ruta[i])
		if queda <= tramo or tramo <= 0.001:
			return ruta[i - 1].lerp(ruta[i], clampf(queda / maxf(tramo, 0.001), 0.0, 1.0))
		queda -= tramo
	return ruta[ruta.size() - 1]


static func _largo_de(ruta: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, ruta.size()):
		total += ruta[i].distance_to(ruta[i - 1])
	return total


func _pintar(person: Inhabitant, index: int, donde_va: Vector3, escondida: bool) -> void:
	if index >= sim._bodies.size():
		return
	# Bajo tierra, que es lo que la multitud hace con lo que no toca ver: los huecos son
	# por índice y no se pueden quitar. Ver [SettlementSim._sacar_del_mapa].
	var punto := donde_va + (Vector3(0.0, -1000.0, 0.0) if escondida else Vector3.ZERO)
	crowd.update(sim._bodies[index], punto, sim._headings[index], person.state,
		person.age_group)


func _poner_las_marcas(en_viaje: Array[Dictionary]) -> void:
	marcas_puestas.clear()
	for fila: Dictionary in en_viaje:
		marcas_puestas.append({
			# Un palmo por encima del suelo: pegada al terreno se la comía la pendiente.
			"donde": Vector3(fila["donde"]) + Vector3(0.0, 0.6, 0.0),
			"color": COLOR_DEL_OFICIO.get(fila["oficio"], Color(0.7, 0.7, 0.68)),
		})
	if _marcas == null:
		return
	_marcas.multimesh.instance_count = marcas_puestas.size()
	_marcas.visible = not marcas_puestas.is_empty()
	for i in range(marcas_puestas.size()):
		var marca: Dictionary = marcas_puestas[i]
		_marcas.multimesh.set_instance_transform(i,
			Transform3D(Basis.IDENTITY, marca["donde"]))
		_marcas.multimesh.set_instance_color(i, marca["color"])
