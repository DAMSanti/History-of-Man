class_name Instantanea
extends RefCounted
## La partida entera, pasada a algo que se puede comparar y guardar.
##
## Para dos cosas, las dos de docs/specs/LO_MISMO_MAS_DEPRISA.md: comparar dos
## corridas jornada a jornada —ver [FirmaDiaria]— y arrancar una sonda en la
## jornada N sin correr las anteriores. Es un instrumento, como [Cronometro]:
## no lo llama nada del juego y no promete que un fichero de hoy sirva mañana.
## El guardado del juego es otra cosa, la FASE A3 del roadmap.
##
## ## Cómo recorre
##
## No hay un serializador por módulo, que habría que mantener a mano cada vez
## que alguien añade un campo: se recorre el estado por reflexión, desde pocas
## raíces —la simulación, la fauna, dos estáticas de [GameState] y qué cuevas
## se han descubierto—. De cada objeto se guardan SÓLO sus variables de guion,
## y cada objeto UNA vez aunque lo apunten veinte sitios: van por identidad,
## con una tabla, que es también lo que deja pasar los ciclos sin reventar.
##
## Lo que no se recorre por dentro, y por qué:
##
## - **Los `Node`.** Son la escena, no la partida. Los que la partida apunta
##   con un papel conocido —la simulación, la fauna, el terreno, la multitud—
##   se guardan por su papel; los demás, por su clase, y al restaurar se deja
##   lo que haya en la escena nueva.
## - **Los objetos del motor** (mallas, imágenes, texturas), menos el generador
##   de azar: son vista. Se cuentan en [ajenos] para que se sepa qué se saltó.
## - **Un `Callable` es un error.** No se puede guardar, y si hay uno en el
##   estado al cerrar la jornada, lo guardado no sería la partida. Va a
##   [errores] y quien toma la instantánea decide.
##
## ## El formato
##
## Un valor suelto —número, texto, vector, `Packed*Array`— va tal cual. Un
## contenedor o una referencia va como un Array cuyo primer elemento es una
## etiqueta: como TODO Array de la partida se codifica etiquetado, un Array en
## lo codificado nunca es un valor suelto y no hay ambigüedad.

const VERSION := 2

## Campos que son coste o vista, no partida: no se guardan ni entran en la
## firma.
##
## Meter uno aquí es una decisión que se revisa en cada cambio, no un cajón de
## sastre: un campo que DECIDE algo y se esconde aquí haría pasar por iguales
## dos partidas distintas.
const FUERA := {
	# El presupuesto de caminos del paso: se pone a cero al empezar cada uno.
	"_path_nodes_this_frame": true,
	"_stranded_this_frame": true,
	# Cuánto tardó en hornearse la rejilla. Sólo se imprime.
	"grid_build_ms": true,
	# Reloj real todavía sin simular: depende del fotograma, no de la partida.
	"_pendiente": true,
	# La velocidad la pone quien juega, o la sonda.
	"time_scale": true,
	# Si la noche se salta. Es ritmo de reloj, no partida: acelerar da MAS
	# pasos del mismo tamaño, no pasos distintos, asi que la sucesion de
	# estados es la misma con el interruptor puesto o quitado. Y tiene que
	# estar fuera precisamente para poder demostrarlo: es lo unico que
	# separaba las firmas de la corrida con noche y la de sin.
	"noche_acelerada": true,
	# La fase del salto que se DIBUJA en la fauna sin marcha: avanza por
	# fotograma y sólo mueve la malla. Ver `WildlifeHerds._draw`.
	"_hop_phase": true,
	# Desde dónde se dio la última ojeada al mapa. Es caché de una llamada
	# IDEMPOTENTE -`see_from` sólo sube la claridad, nunca la baja-, así que
	# empezar sin ella sólo cuesta una ojeada de más que no toca un número.
	# Ver [Inhabitant.ojeada_desde].
	"ojeada_desde": true,
	"ojeada_alcance": true,
	# Qué hueco de la malla de la multitud le toca a cada persona. Los reparte
	# [BandaCrowd], que siembra su azar con `randomize()` porque es variedad
	# de cuerpos dibujados, no partida: sólo se usa para colocar la malla.
	"_bodies": true,
	# Lo que el horno lleva amasado de las rejillas que todavía no hacen
	# falta. Va por reloj, y desde que `HornoDeRejillas.de` termina la que se
	# pide no decide nada: la banda sólo anda con rejillas ENTERAS. La que usa
	# está en `sim._grid`, y ésa sí se firma.
	"HornoDeRejillas._rejillas": true,
	"HornoDeRejillas._cola": true,
	# Los caminos del arbol ya recortados. Es caché de una función pura -el
	# recorte sale del árbol, la rejilla y la celda-, así que empezar vacía da
	# la misma partida; y guardarla engordaría la instantánea por nada. Que
	# empezar vacía da lo mismo lo comprueba la prueba de la huella.
	"Marcha._recortes_del_arbol": true,
	# El abanico de puntos que se le prueban a cada persona, ya filtrado por el
	# relieve. Caché de una función pura del `id` y del abrigo; ver
	# [Tajo._abanico_de].
	"Tajo._abanicos": true,
	"Tajo._abanicos_con": true,
	"Tajo._abanicos_desde": true,
}

const LISTA := "A"
const DICCIONARIO := "D"
const OBJETO := "O"
const NODO := "N"
const RECURSO := "R"
const DEL_MOTOR := "M"
const CONTENEDOR := "@"

## Papel -> propiedades de esa raíz, como `[nombre, valor, nombre, valor…]`.
var raices: Dictionary = {}

## Los objetos, por orden de aparición: `[ruta del guion, [nombre, valor…]]`.
## Una referencia a uno es `[OBJETO, índice]`.
var objetos: Array = []

## Las listas y los diccionarios, también por orden de aparición y también UNA
## VEZ cada uno. Una referencia a uno es `[CONTENEDOR, índice]`.
##
## Van por identidad, como los objetos, y no por valor, porque en Godot son
## referencias y la partida se apoya en eso: la fauna mete el MISMO diccionario
## de cada animal en `_animals` y en `_prey`, y el árbol de técnicas comparte
## con la simulación el mismo diccionario de lo construido. Guardándolos por
## valor, al restaurar salían copias sueltas: mover un animal por una lista ya
## no se veía en la otra, y la partida restaurada se separaba de la guardada en
## cuanto daba un paso. Medido en la tarea 17 de la spec.
var contenedores: Array = []

## Lo que vive en estáticas y es de la partida.
var estaticas: Dictionary = {}

## Qué cuevas se han descubierto, en el orden de la escena. Son vista, pero la
## crónica depende de ellas: sin guardarlas, al restaurar se volverían a
## «descubrir» y la crónica saldría con entradas de más.
var cuevas: Array = []

## Lo que no se ha podido guardar, con dónde estaba.
var errores: Array[String] = []

## Clase -> cuántas veces se ha saltado un nodo sin papel o un objeto del motor.
var ajenos: Dictionary = {}

var _ids: Dictionary = {}
var _papeles: Dictionary = {}
## hash del contenido -> [[contenedor, índice], …]. Ver [_contenedor].
var _cubos: Dictionary = {}


## Toma la partida tal como está ahora. `cuevas_de_la_escena` son los
## `CaveMouth` de `DemoMain`, en su orden; sin escena, vacío.
static func tomar(sim: SettlementSim, fauna: WildlifeHerds = null,
		cuevas_de_la_escena: Array = []) -> Instantanea:
	var foto := Instantanea.new()
	foto._papel(sim, "sim")
	foto._papel(fauna, "fauna")
	if sim != null:
		foto._papel(sim._terrain, "terreno")
		foto._papel(sim._crowd, "multitud")
		foto.raices["sim"] = foto._propiedades(sim, "sim")
	if fauna != null:
		foto.raices["fauna"] = foto._propiedades(fauna, "fauna")
	foto.estaticas = {"season": int(GameState.season), "year": GameState.year}
	for cueva: Object in cuevas_de_la_escena:
		foto.cuevas.append(bool(cueva.get("discovered")))
	return foto


## Todo junto, en bytes. Dos partidas iguales dan los mismos bytes.
func bytes() -> PackedByteArray:
	return var_to_bytes([VERSION, raices, objetos, estaticas, cuevas, contenedores])


## Nombre corto de la clase de una entrada de [objetos], para leerla.
static func clase_de(entrada: Array) -> String:
	var ruta := String(entrada[0])
	if ruta.is_empty():
		return "(sin guion)"
	if not ruta.begins_with("res://"):
		return ruta
	return ruta.get_file().get_basename()


## El nombre corto de la clase de un objeto vivo, como lo escribe [clase_de]
## para los guardados.
func _clase_de_objeto(obj: Object) -> String:
	var guion: Script = obj.get_script()
	if guion == null or guion.resource_path.is_empty():
		return obj.get_class()
	return guion.resource_path.get_file().get_basename()


func _papel(nodo: Object, papel: String) -> void:
	if nodo != null:
		_papeles[nodo.get_instance_id()] = papel


## Las variables de guion de un objeto, en el orden en que las declara.
func _propiedades(obj: Object, ruta: String) -> Array:
	var pares: Array = []
	var clase := _clase_de_objeto(obj)
	for prop: Dictionary in obj.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var nombre: String = prop["name"]
		# En [FUERA] vale el nombre suelto -vale para cualquier clase- y el
		# nombre con clase, para no esconder de paso el campo de otra que se
		# llame igual.
		if FUERA.has(nombre) or FUERA.has(clase + "." + nombre):
			continue
		pares.append(nombre)
		pares.append(_codifica(obj.get(nombre), ruta + "." + nombre))
	return pares


func _codifica(valor: Variant, ruta: String) -> Variant:
	match typeof(valor):
		TYPE_ARRAY, TYPE_DICTIONARY:
			return [CONTENEDOR, _contenedor(valor, ruta)]
		TYPE_OBJECT:
			return _codifica_objeto(valor, ruta)
		TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
			errores.append("%s: un %s no se puede guardar" % [ruta, type_string(typeof(valor))])
			return null
		_:
			return valor


## El índice de una lista o un diccionario en [contenedores], guardándolo la
## primera vez que se ve.
##
## La identidad se busca por cubos: `hash` del contenido para dar con los
## candidatos —es de contenido, así que dos distintos con lo mismo dentro caen
## en el mismo cubo— y `is_same` dentro del cubo, que es lo único que distingue
## «el mismo» de «uno igual».
func _contenedor(valor: Variant, ruta: String) -> int:
	var clave := hash(valor)
	var cubo: Array = _cubos.get(clave, [])
	for par: Array in cubo:
		if is_same(par[0], valor):
			return int(par[1])

	# Se apunta ANTES de recorrerlo, igual que los objetos: si algo de dentro
	# vuelve a él, ya tiene índice y el ciclo se corta.
	var indice := contenedores.size()
	contenedores.append([])
	cubo.append([valor, indice])
	_cubos[clave] = cubo

	if valor is Array:
		var lista: Array = [LISTA]
		var i := 0
		for elemento: Variant in (valor as Array):
			lista.append(_codifica(elemento, ruta + "[" + str(i) + "]"))
			i += 1
		contenedores[indice] = lista
	else:
		var pares: Array = [DICCIONARIO]
		var dic: Dictionary = valor
		for clave2: Variant in dic:
			pares.append(_codifica(clave2, ruta + "{clave}"))
			pares.append(_codifica(dic[clave2], ruta + "{" + str(clave2) + "}"))
		contenedores[indice] = pares
	return indice


func _codifica_objeto(obj: Object, ruta: String) -> Variant:
	if obj == null or not is_instance_valid(obj):
		return null
	var id := obj.get_instance_id()
	if obj is Node:
		if _papeles.has(id):
			return [NODO, _papeles[id]]
		_ajeno(obj.get_class())
		return [NODO, "?" + obj.get_class()]
	if _ids.has(id):
		return [OBJETO, _ids[id]]

	if obj is RandomNumberGenerator:
		# Por `seed` y `state`, y en ese orden al restaurar: fijar la semilla
		# reinicia el estado.
		var rng := obj as RandomNumberGenerator
		return [OBJETO, _registra(id, ["RandomNumberGenerator",
			["seed", rng.seed, "state", rng.state]])]

	var guion: Script = obj.get_script()
	# Un recurso cargado de disco se apunta por su ruta: es el mismo en todas
	# las corridas y `load` devuelve el mismo objeto.
	if obj is Resource:
		var camino := (obj as Resource).resource_path
		if not camino.is_empty() and not camino.contains("::"):
			return [RECURSO, camino]
	if guion == null:
		_ajeno(obj.get_class())
		return [DEL_MOTOR, obj.get_class()]

	# Se apunta ANTES de recorrerlo: si dentro hay un camino que vuelve a él,
	# ya tiene índice y el ciclo se corta ahí.
	var indice := _registra(id, [])
	objetos[indice] = [guion.resource_path, _propiedades(obj, ruta)]
	return [OBJETO, indice]


func _registra(id: int, entrada: Array) -> int:
	var indice := objetos.size()
	objetos.append(entrada)
	_ids[id] = indice
	return indice


func _ajeno(clase: String) -> void:
	ajenos[clase] = int(ajenos.get(clase, 0)) + 1


# --- De vuelta: de bytes a la partida -------------------------------------


## Algo que no se restaura: un nodo sin papel o un objeto del motor. Quien se
## lo encuentre dentro de un valor deja lo que haya en la escena nueva.
const AJENO := "@ajeno@"

## Lo que estaba en el código y no en la instantánea: se queda como estaba.
var avisos: Array[String] = []

var _vivos: Dictionary = {}
var _vivos_cont: Dictionary = {}
var _roles: Dictionary = {}


## Lo contrario de [bytes]. Devuelve null si no es una instantánea de esta
## versión.
static func desde_bytes(datos: PackedByteArray) -> Instantanea:
	var leido: Variant = bytes_to_var(datos)
	if not (leido is Array) or (leido as Array).size() < 6 \
			or int((leido as Array)[0]) != VERSION:
		return null
	var foto := Instantanea.new()
	foto.raices = (leido as Array)[1]
	foto.objetos = (leido as Array)[2]
	foto.estaticas = (leido as Array)[3]
	foto.cuevas = (leido as Array)[4]
	foto.contenedores = (leido as Array)[5]
	return foto


## Vuelca la partida sobre una escena recién montada con el MISMO
## emplazamiento y la MISMA semilla, todavía en pausa. Devuelve los errores:
## vacío es que ha entrado todo.
##
## Los módulos que ya existen —los que nacen con la simulación— se rellenan EN
## SU SITIO, no se sustituyen: hay quien los apunta desde fuera, y el árbol de
## técnicas comparte con la simulación el mismo diccionario de lo construido.
## Los contenedores, por lo mismo. Los objetos que van y vienen —personas,
## parajes, cacerías— se crean de nuevo.
func volcar(sim: SettlementSim, fauna: WildlifeHerds = null,
		cuevas_de_la_escena: Array = []) -> Array[String]:
	errores.clear()
	avisos.clear()
	_vivos.clear()
	_vivos_cont.clear()
	_roles = {"sim": sim, "fauna": fauna}
	if sim != null:
		_roles["terreno"] = sim._terrain
		_roles["multitud"] = sim._crowd

	# 1. Atar lo guardado a lo que ya existe, por identidad.
	if sim != null and raices.has("sim"):
		_ata(sim, raices["sim"])
	if fauna != null and raices.has("fauna"):
		_ata(fauna, raices["fauna"])

	# 2. Crear lo que falte.
	for indice in range(objetos.size()):
		if _vivos.has(indice):
			continue
		var clase := String((objetos[indice] as Array)[0])
		if clase == "RandomNumberGenerator":
			_vivos[indice] = RandomNumberGenerator.new()
			continue
		if not clase.begins_with("res://"):
			errores.append("objeto %d: no hay guion que cargar (%s)" % [indice, clase])
			continue
		var guion: Script = load(clase)
		if guion == null:
			errores.append("objeto %d: no se puede cargar %s" % [indice, clase])
			continue
		var nuevo: Variant = guion.new()
		# Un guion que pide argumentos para construirse —los módulos piden la
		# simulación— sólo entra aquí si NO se ató a uno que ya existiera, y
		# entonces no hay forma de crearlo. Se dice, en vez de reventar al
		# rellenarlo.
		if nuevo == null:
			errores.append("objeto %d: %s no se construye sin argumentos"
				% [indice, clase])
			continue
		_vivos[indice] = nuevo

	# 3. Rellenar: primero los objetos, luego las raíces.
	for indice: int in _vivos:
		var entrada: Array = objetos[indice]
		var obj: Object = _vivos[indice]
		if obj is RandomNumberGenerator:
			var pares_rng: Array = entrada[1]
			# La semilla primero: fijarla reinicia el estado.
			(obj as RandomNumberGenerator).seed = int(pares_rng[1])
			(obj as RandomNumberGenerator).state = int(pares_rng[3])
			continue
		_rellena(obj, entrada[1], Instantanea.clase_de(entrada))
	if sim != null and raices.has("sim"):
		_rellena(sim, raices["sim"], "sim")
	if fauna != null and raices.has("fauna"):
		_rellena(fauna, raices["fauna"], "fauna")

	if estaticas.has("season"):
		GameState.season = int(estaticas["season"]) as Subsistence.Season
	if estaticas.has("year"):
		GameState.year = int(estaticas["year"])
	for i in range(mini(cuevas.size(), cuevas_de_la_escena.size())):
		if bool(cuevas[i]):
			(cuevas_de_la_escena[i] as Object).call("discover")

	_rehacer_el_horno(sim)
	return errores


## LO ÚNICO QUE SE RECONSTRUYE, y por qué.
##
## La cola del horno no se guarda —es coste, ver [FUERA]—, así que en la escena
## nueva el horno trae las rejillas de su arranque. Hay que dejarlo con la de la
## estación restaurada, y que sea EL MISMO objeto: `Marcha._navgrid` compara por
## identidad y, si no coincide, cambia de rejilla y tira los caminos guardados,
## que ya es otra partida.
##
## Las otras tres se dejan preparadas y a la cola, sin hornear, igual que hace
## `HornoDeRejillas.encargar`.
func _rehacer_el_horno(sim: SettlementSim) -> void:
	if sim == null or sim.horno == null or sim._terrain == null or sim._grid == null:
		return
	# EN LA CASILLA QUE LE TOCA POR SU CAUDAL, no en la de la estación de hoy.
	#
	# La rejilla que la banda está usando puede ser la de la estación PASADA:
	# si la foto se tomó justo después de cambiar la estación y antes de que
	# alguien pidiera caminos, `sim._grid` sigue siendo la de antes. Puesta en
	# la casilla de hoy, el horno restaurado creería tener ya la nueva y la
	# banda no cambiaría nunca de caminos, mientras que la corrida continua sí
	# cambia. Los cuatro caudales son distintos, así que dicen de quién es cada
	# rejilla. Medido en la tarea 17 de la spec.
	var suya := int(GameState.season)
	for season3: int in Temporada.CAUDAL:
		if is_equal_approx(float(Temporada.CAUDAL[season3]), sim._grid.built_with_caudal):
			suya = season3
	sim.horno._rejillas = {suya: sim._grid}
	sim.horno._cola.clear()
	for paso in range(1, 4):
		var season := (suya + paso) % 4
		sim.horno._rejillas[season] = Navgrid.preparar(sim._terrain,
			sim.has_boat, sim.has_bridge,
			float(Temporada.CAUDAL.get(season, 1.0)),
			float(Temporada.ENCHARCA.get(season, 0.0)))
		sim.horno._cola.append(season)


func _ata(vivo: Object, pares: Array) -> void:
	for i in range(0, pares.size(), 2):
		var valor: Variant = pares[i + 1]
		if not (valor is Array) or (valor as Array).size() != 2 \
				or (valor as Array)[0] != OBJETO:
			continue
		var indice: int = (valor as Array)[1]
		if _vivos.has(indice):
			continue
		var actual: Variant = vivo.get(String(pares[i]))
		if not (actual is Object):
			continue
		var clase := String((objetos[indice] as Array)[0])
		if actual is RandomNumberGenerator:
			if clase == "RandomNumberGenerator":
				_vivos[indice] = actual
			continue
		var guion: Script = (actual as Object).get_script()
		if guion != null and guion.resource_path == clase:
			_vivos[indice] = actual
			_ata(actual as Object, (objetos[indice] as Array)[1])


func _rellena(obj: Object, pares: Array, donde: String) -> void:
	var tiene: Dictionary = {}
	for prop: Dictionary in obj.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			tiene[String(prop["name"])] = true
	var vistos: Dictionary = {}
	for i in range(0, pares.size(), 2):
		var nombre := String(pares[i])
		vistos[nombre] = true
		if not tiene.has(nombre):
			errores.append("%s.%s: la instantánea lo trae y el código ya no lo tiene"
				% [donde, nombre])
			continue
		var valor: Variant = _descodifica(pares[i + 1])
		if _lleva_ajeno(valor):
			continue
		var actual: Variant = obj.get(nombre)
		# Los contenedores se rellenan en su sitio: hay quien apunta al mismo
		# diccionario desde otro módulo. Ver `SettlementSim.techs`.
		if actual is Array and valor is Array:
			(actual as Array).assign(valor as Array)
		elif actual is Dictionary and valor is Dictionary:
			(actual as Dictionary).clear()
			(actual as Dictionary).merge(valor as Dictionary)
		else:
			obj.set(nombre, valor)
	for nombre2: String in tiene:
		if not vistos.has(nombre2) and not FUERA.has(nombre2) \
				and not FUERA.has(donde + "." + nombre2):
			avisos.append("%s.%s: el código lo tiene y la instantánea no: se queda como estaba"
				% [donde, nombre2])


func _descodifica(valor: Variant) -> Variant:
	if not (valor is Array):
		return valor
	var lista: Array = valor
	if lista.is_empty():
		return []
	match lista[0]:
		CONTENEDOR:
			return _contenedor_vivo(int(lista[1]))
		OBJETO:
			return _vivos.get(int(lista[1]))
		NODO:
			var papel := String(lista[1])
			return AJENO if papel.begins_with("?") else _roles.get(papel)
		RECURSO:
			return load(String(lista[1]))
		DEL_MOTOR:
			return AJENO
	return valor


## Una lista o un diccionario ya construidos, UNA sola vez por índice: es lo
## que devuelve la identidad que tenían al guardarlos. Ver [contenedores].
func _contenedor_vivo(indice: int) -> Variant:
	if _vivos_cont.has(indice):
		return _vivos_cont[indice]
	var enc: Array = contenedores[indice]
	if enc.is_empty() or enc[0] == LISTA:
		var lista: Array = []
		# Se apunta antes de rellenarlo, por los ciclos.
		_vivos_cont[indice] = lista
		for i in range(1, enc.size()):
			lista.append(_descodifica(enc[i]))
		return lista
	var dic: Dictionary = {}
	_vivos_cont[indice] = dic
	for i in range(1, enc.size(), 2):
		dic[_descodifica(enc[i])] = _descodifica(enc[i + 1])
	return dic


## Si dentro de esto hay algo que no se restaura. Lleva memoria de por dónde ha
## pasado: con la identidad de los contenedores ya hay ciclos de verdad.
func _lleva_ajeno(valor: Variant, vistos: Array = []) -> bool:
	if valor is String:
		return String(valor) == AJENO
	if valor is Array or valor is Dictionary:
		for visto: Variant in vistos:
			if is_same(visto, valor):
				return false
		vistos.append(valor)
	if valor is Array:
		for elemento: Variant in (valor as Array):
			if _lleva_ajeno(elemento, vistos):
				return true
	elif valor is Dictionary:
		var dic: Dictionary = valor
		for clave: Variant in dic:
			if _lleva_ajeno(clave, vistos) or _lleva_ajeno(dic[clave], vistos):
				return true
	return false
