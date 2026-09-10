class_name Cronometro
extends RefCounted
## Quién se come el fotograma.
##
## Es para una queja muy concreta: «algunos frames están aceptables, pero cada
## segundo o así llega alguno de 1000 ms». Un pico así no se encuentra mirando
## la media —la media está bien, ése es justo el problema— sino cazando EL
## FOTOGRAMA MALO y preguntándole qué hizo de más.
##
## Así que esto no es un profiler: es un cepo. Se marcan unos cuantos sitios
## sospechosos con [tramo]/[cierra], se cuenta lo que tarda cada uno DENTRO del
## fotograma en curso, y cuando el fotograma se pasa del límite se vuelca el
## desglose y se olvida. Los fotogramas buenos no imprimen nada.
##
## ## Por qué estático
##
## Los sitios que hay que medir están repartidos por seis clases que no se
## conocen entre sí —el horno de rejillas, el trazado de caminos, las chapas del
## mundo, el minimapa— y pasarles un cronómetro a todas sería cambiar seis
## firmas para una medición. Con estático, marcar un tramo es una línea y
## quitarla también.
##
## ## Coste cuando está apagado
##
## Una comparación de un bool por llamada. [activo] arranca en `false` y sólo lo
## enciende quien mide —ver `PicoProbe`—, así que en partida normal esto no está.

## Si se está midiendo. Apagado, cada llamada es un `if` y vuelve.
static var activo: bool = false

## A partir de cuántos milisegundos un fotograma es un pico digno de contar.
static var limite_ms: float = 100.0

## Lo que lleva gastado cada tramo en el fotograma en curso, en microsegundos.
static var _gasto: Dictionary = {}

## Cuántas veces se ha entrado en cada tramo este fotograma.
static var _veces: Dictionary = {}

## Cuándo empezó cada tramo abierto. Anidar el mismo nombre no está previsto.
static var _abierto: Dictionary = {}

## Los picos cazados, listos para que la sonda los imprima.
static var picos: Array[Dictionary] = []

static var _fotograma_t0: int = 0


## Cierra el fotograma anterior y abre el siguiente. Una vez por cuadro.
##
## SE MIDE DE APERTURA A APERTURA, que es el fotograma de verdad: lo que dura
## `_process` de una escena no es lo que tarda el cuadro, y ahi se pierde justo
## lo que se busca —el pintado, la fisica, el `_process` de los demas nodos—.
## Medido con `PicoProbe` antes de caer en esto: 94 ms de media por cuadro y
## CERO tramos de mas de cien, porque lo marcado no llegaba a la mitad del
## cuadro.
##
## Lo que se apunta como gasto es lo que corrio en esa ventana, o sea el
## fotograma que se acaba de cerrar.
static func abre_el_fotograma() -> void:
	if not activo:
		return
	var ahora := Time.get_ticks_usec()
	if _fotograma_t0 != 0:
		var total := float(ahora - _fotograma_t0) / 1000.0
		_cuadros += 1
		_suma_ms += total
		if total > _peor_ms:
			_peor_ms = total
		if total >= limite_ms:
			var desglose: Array[Dictionary] = []
			for nombre: String in _gasto:
				desglose.append({
					"tramo": nombre,
					"ms": float(_gasto[nombre]) / 1000.0,
					"veces": int(_veces.get(nombre, 0)),
				})
			desglose.sort_custom(func(a, b): return float(a["ms"]) > float(b["ms"]))
			# Y EL REPARTO GRUESO: cuanto de ese cuadro esta explicado.
			#
			# Se suman SOLO los tramos de primer nivel —los `_process` de cada
			# nodo, marcados con el prefijo de raiz— porque los de dentro ya
			# van contados en ellos y sumarlos todos daria de mas.
			#
			# No se usa `Performance.TIME_PROCESS`: el motor lo entrega
			# SUAVIZADO entre cuadros, asi que en el cuadro del tiron da un
			# numero que no es el de ese cuadro. Se vio en la medicion: 114 %
			# del tiron atribuido al guion, o sea mas tiempo del que duro el
			# cuadro entero.
			var explicado := 0.0
			for nombre: String in _gasto:
				if _raiz.has(nombre):
					explicado += float(_gasto[nombre]) / 1000.0
			desglose.append({
				"tramo": "· TODO LO MARCADO (los _process de la escena)",
				"ms": explicado, "veces": 1})
			desglose.append({
				"tramo": "· SIN EXPLICAR (pintado, motor, o algo sin marcar)",
				"ms": maxf(total - explicado, 0.0), "veces": 1})
			desglose.sort_custom(func(a, b): return float(a["ms"]) > float(b["ms"]))
			picos.append({
				"total": total, "etiqueta": _etiqueta, "desglose": desglose})
	_gasto.clear()
	_veces.clear()
	_abierto.clear()
	_fotograma_t0 = ahora


## Le pone nombre al fotograma en curso: la hora de juego, para poder atarlo a
## lo que estaba pasando.
static func cierra_el_fotograma(etiqueta: String = "") -> void:
	if activo:
		_etiqueta = etiqueta


static var _etiqueta: String = ""

## Cuenta de cuadros y de milisegundos, para poder decir cuanto es «normal».
static var _cuadros: int = 0
static var _suma_ms: float = 0.0
static var _peor_ms: float = 0.0


static func media_ms() -> float:
	return _suma_ms / maxf(float(_cuadros), 1.0)


static func peor_ms() -> float:
	return _peor_ms


static func cuadros() -> int:
	return _cuadros


static func reinicia() -> void:
	picos.clear()
	_gasto.clear()
	_veces.clear()
	_abierto.clear()
	_fotograma_t0 = 0
	_cuadros = 0
	_suma_ms = 0.0
	_peor_ms = 0.0


## Los tramos que son un `_process` entero, para poder sumarlos sin contar
## dos veces lo que va dentro de ellos.
static var _raiz: Dictionary = {}


## Marca un tramo que es UN `_process` COMPLETO de un nodo.
static func tramo_raiz(nombre: String) -> void:
	if not activo:
		return
	_raiz[nombre] = true
	_abierto[nombre] = Time.get_ticks_usec()


static func tramo(nombre: String) -> void:
	if not activo:
		return
	_abierto[nombre] = Time.get_ticks_usec()


static func cierra(nombre: String) -> void:
	if not activo or not _abierto.has(nombre):
		return
	var gastado := Time.get_ticks_usec() - int(_abierto[nombre])
	_abierto.erase(nombre)
	_gasto[nombre] = int(_gasto.get(nombre, 0)) + gastado
	_veces[nombre] = int(_veces.get(nombre, 0)) + 1


## Apunta una llamada suelta que se quiere contar sin cronometrar.
static func cuenta(nombre: String) -> void:
	if not activo:
		return
	_veces[nombre] = int(_veces.get(nombre, 0)) + 1
	if not _gasto.has(nombre):
		_gasto[nombre] = 0
