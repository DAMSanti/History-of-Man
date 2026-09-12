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

## Los picos cazados, listos para quien quiera leerlos.
##
## LA VACÍA EL CEPO, NO QUIEN LEE, y esto es importante: la leen DOS —el panel
## de F3 y la sonda que esté midiendo— y mientras el que leía la vaciaba, el
## primero en pasar se la llevaba y el otro se quedaba a ciegas. Medido: la
## sonda contaba 3 tirones donde el cepo había empujado 92, y un año entero
## salía con «8 tirones» cuando cada fotograma pasaba de cien milisegundos.
##
## Se vacía al ABRIR cada fotograma, así que durante el fotograma en curso
## contiene los picos del que se acaba de cerrar y los leen los dos.
static var picos: Array[Dictionary] = []

static var _fotograma_t0: int = 0

## Cuantos picos se han dejado en la bandeja desde [reinicia]. Es para saber si
## quien los recoge los esta perdiendo: si esto sube y quien mide cuenta cero,
## alguien mas esta vaciando [picos].
static var empujados: int = 0


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
	# La bandeja es del cuadro que se cierra: lo de antes ya lo ha visto quien
	# tuviera que verlo. Ver [picos].
	picos.clear()
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
			# LOS DOS RENGLONES GRUESOS, dichos por lo que son.
			#
			# Se llamaban «TODO LO MARCADO» y «SIN EXPLICAR», y el segundo se
			# llevaba el 84 % de un tiron de 917 ms sin decir nada mas. Un
			# renglon que se lleva el tiron entero y se titula «sin explicar»
			# no es un dato: es una encogida de hombros.
			#
			# Y si tiene nombre. Lo que no esta marcado es EL MOTOR -pintar,
			# fisica, el arbol de nodos-, porque todos los `_process` del juego
			# estan marcados; se comprueba con un grep. Asi que se dice, y se
			# acompana de las tres cifras que explican por que pintar cuesta:
			# cuantos nodos hay, cuantos objetos entran en el cuadro y cuantas
			# llamadas de dibujo salen. Con eso, un tiron que crece con los dias
			# -«a medida que pasan los dias los tirones se hacen mas comunes»- se
			# lee de un vistazo en vez de quedarse en el limbo.
			desglose.append({
				"tramo": "· EL JUEGO (todos sus _process, que estan marcados)",
				"ms": explicado, "veces": 1})
			desglose.append({
				"tramo": "· EL MOTOR (pintar, fisica) · %d nodos · %d objetos · %d dibujos" % [
					int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
					int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))],
				"ms": maxf(total - explicado, 0.0), "veces": 1})
			desglose.sort_custom(func(a, b): return float(a["ms"]) > float(b["ms"]))
			picos.append({
				"total": total, "etiqueta": _etiqueta, "desglose": desglose})
			empujados += 1
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
	empujados = 0


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


## Microsegundos que las sondas han apartado de la cuenta, en total. Ver
## [aparta].
static var apartado_us: int = 0

static var _aparte_t0: int = 0


## Deja fuera de la cuenta lo que haga una SONDA dentro del fotograma.
##
## Una sonda que toma la firma de la jornada —ver [FirmaDiaria]— lo hace desde
## `day_passed`, o sea dentro del paso de simulación: sin esto, lo que tarda en
## recorrer la partida saldría como coste del «paso de simulación» y del
## fotograma, y el ranking culparía al juego de lo que hace quien lo mide.
##
## Entre [aparta] y [vuelve], el reloj de cada tramo abierto y el del
## fotograma se corren hacia delante lo que se haya tardado. Lo apartado se
## suma en [apartado_us], también con el cepo apagado, para que la sonda pueda
## quitarlo de sus propias cuentas de fotograma.
static func aparta() -> void:
	_aparte_t0 = Time.get_ticks_usec()


static func vuelve() -> void:
	if _aparte_t0 == 0:
		return
	var gastado := Time.get_ticks_usec() - _aparte_t0
	_aparte_t0 = 0
	apartado_us += gastado
	if not activo:
		return
	for nombre: String in _abierto:
		_abierto[nombre] = int(_abierto[nombre]) + gastado
	if _fotograma_t0 != 0:
		_fotograma_t0 += gastado


## Apunta una llamada suelta que se quiere contar sin cronometrar.
static func cuenta(nombre: String) -> void:
	if not activo:
		return
	_veces[nombre] = int(_veces.get(nombre, 0)) + 1
	if not _gasto.has(nombre):
		_gasto[nombre] = 0
