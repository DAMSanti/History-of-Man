class_name AnchoDeLosRios
extends RefCounted
## Cuánto mide de ancho cada punto de un río: poco en la fuente y más aguas abajo.
##
## EPOCA_01 §10.2. Los ríos del mapa regional salían con el mismo grosor de la fuente
## a la boca —OSM da a todo «river» el mismo ancho de tabla— y el usuario: «el río
## aparece con el mismo grosor a lo largo de toda su extensión y eso no representa la
## realidad» (2026-09-16).
##
## Un río crece con lo que le llega de arriba. Sin caudales medidos, **la longitud de
## río que desagua en cada punto** es la medida honesta que hay: la de su propio cauce
## más la de todos los que le caen. Es una regla de datos: la aplica `HornearRios` y se
## prueba con ríos construidos.

## Semiancho en la fuente, en metros.
const EN_LA_FUENTE_M := 1.5

## Cuánto crece con la raíz de los kilómetros de río aguas arriba: con 6, un río de
## 25 km lleva 31 m de semiancho en su boca y uno de 100 km, 61. Decisión mirando
## anchos de los ríos cantábricos en su tramo bajo —el Saja-Besaya en Torrelavega ronda
## los 40-60 m—, no una medida.
const CRECE := 6.0

## Tope de semiancho, en metros.
const COMO_MUCHO_M := 80.0

## Dos puntas a menos de esto se tocan: un tramo desagua en el otro.
const SE_TOCAN_M := 60.0

## Sube si cambia la regla: entra en la huella de los ríos horneados.
const VERSION := 1


## Pone a cada cauce su `half_widths_m`, un semiancho por punto.
##
## Los tramos de OSM y los de la plataforma se enlazan igual: la punta de aguas abajo
## de uno toca el principio del siguiente. El que no tiene nada arriba empieza en la
## fuente.
static func poner(cauces: Array) -> void:
	var largos: Array[float] = []
	for cauce: Dictionary in cauces:
		largos.append(_km(cauce["points"]))

	# Quién desagua en quién: el principio de cada tramo, buscado por casillas.
	var principios: Dictionary = {}
	for i in range(cauces.size()):
		var puntos: PackedVector2Array = cauces[i]["points"]
		if puntos.size() < 2:
			continue
		var casilla := _casilla(puntos[0])
		if not principios.has(casilla):
			principios[casilla] = []
		(principios[casilla] as Array).append(i)
	var le_caen: Array = []
	for i in range(cauces.size()):
		le_caen.append([])
	for j in range(cauces.size()):
		var puntos: PackedVector2Array = cauces[j]["points"]
		if puntos.size() < 2:
			continue
		var punta := puntos[puntos.size() - 1]
		var base := _casilla(punta)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var vecina := Vector2i(base.x + dx, base.y + dz)
				for i: int in principios.get(vecina, []):
					if i == j:
						continue
					var inicio: Vector2 = (cauces[i]["points"] as PackedVector2Array)[0]
					if _metros(inicio, punta) < SE_TOCAN_M:
						(le_caen[i] as Array).append(j)

	var arriba: Array[float] = []
	arriba.resize(cauces.size())
	arriba.fill(-1.0)
	for i in range(cauces.size()):
		_arriba(i, le_caen, largos, arriba, {})

	for i in range(cauces.size()):
		var puntos: PackedVector2Array = cauces[i]["points"]
		var anchos := PackedFloat32Array()
		anchos.resize(puntos.size())
		var andado := 0.0
		for k in range(puntos.size()):
			if k > 0:
				andado += _metros(puntos[k - 1], puntos[k]) / 1000.0
			anchos[k] = semiancho(arriba[i] + andado)
		cauces[i]["half_widths_m"] = anchos


## El semiancho de un río con `km` de río aguas arriba.
static func semiancho(km: float) -> float:
	return minf(EN_LA_FUENTE_M + CRECE * sqrt(maxf(km, 0.0)), COMO_MUCHO_M)


## Los kilómetros de río que llegan al principio del tramo `i`. Con memoria, y sin
## entrar en un ciclo si OSM trae dos tramos que se apuntan entre sí.
static func _arriba(i: int, le_caen: Array, largos: Array[float], arriba: Array[float],
		andando: Dictionary) -> float:
	if arriba[i] >= 0.0:
		return arriba[i]
	if andando.has(i):
		return 0.0
	andando[i] = true
	var total := 0.0
	for j: int in le_caen[i]:
		total += _arriba(j, le_caen, largos, arriba, andando) + largos[j]
	andando.erase(i)
	arriba[i] = total
	return total


static func _casilla(punto: Vector2) -> Vector2i:
	# Unos 55 m de lado: una punta y el principio que toca caen en la misma casilla o
	# en una vecina.
	return Vector2i(floori(punto.x / 0.0007), floori(punto.y / 0.0005))


static func _km(puntos: PackedVector2Array) -> float:
	var total := 0.0
	for k in range(1, puntos.size()):
		total += _metros(puntos[k - 1], puntos[k])
	return total / 1000.0


static func _metros(a: Vector2, b: Vector2) -> float:
	var dy := (b.y - a.y) * 111320.0
	var dx := (b.x - a.x) * 111320.0 * cos(deg_to_rad(a.y))
	return sqrt(dx * dx + dy * dy)
