class_name RepartoDeCarga
extends RefCounted
## Cuánto de una carga está hecho, de 0 a 1. INTERFAZ §9.
##
## La carga se declara en ETAPAS con su peso —lo que cuesta cada una, medido—, y dentro
## de una etapa larga se avanza por su propio contador. La barra avanza así en proporción
## al tiempo y no a partes iguales: sembrar el bosque son 14 s y el minimapa medio.
##
## **No retrocede nunca**, que es la mitad de que la barra diga la verdad. Una carga que
## encadena dos —preparar un valle y luego montarlo— declara etapas nuevas con la barra
## ya avanzada: las nuevas se reparten lo que falta, no vuelven a empezar.

var _etapas: Array[Dictionary] = []
var _total := 0.0
var _hecho := 0.0
var _actual := -1
var _dentro := 0.0
## Lo que ya estaba hecho al declarar las etapas de ahora.
var _base := 0.0
var _mostrado := 0.0
## Cuándo empezó la etapa actual, en microsegundos. Ver [avanzar_por_tiempo].
var _empezo := 0
## Cuándo empezó la primera etapa si fue antes de declararla. Ver [etapas].
var _desde_la_primera := 0


## Declara las etapas que vienen: `[[texto, peso], ...]`. El peso, en milisegundos
## medidos, o en cualquier unidad común.
##
## `desde_usec`, si se da, es cuándo empezó de verdad la PRIMERA etapa: la pantalla se
## abre antes de que la escena nueva exista para declarar nada —hay que leer la escena y
## guardar la partida—, y ese rato es de su primera etapa. Sin contarlo, la barra se
## quedaba a cero casi un segundo y a media barra había pasado el 75 % de la carga.
func etapas(lista: Array, desde_usec: int = 0) -> void:
	_desde_la_primera = desde_usec
	_base = valor()
	_etapas.clear()
	_total = 0.0
	for par: Array in lista:
		var peso := maxf(float(par[1]), 0.0)
		_etapas.append({"texto": String(par[0]), "peso": peso})
		_total += peso
	_hecho = 0.0
	_actual = -1
	_dentro = 0.0


## Empieza la etapa `indice`: las anteriores cuentan como hechas.
func etapa(indice: int) -> void:
	if indice < 0 or indice >= _etapas.size() or indice <= _actual:
		return
	_hecho = 0.0
	for i in range(indice):
		_hecho += float(_etapas[i]["peso"])
	_actual = indice
	_dentro = 0.0
	_empezo = _desde_la_primera if indice == 0 and _desde_la_primera > 0 else Time.get_ticks_usec()
	_recalcular()
	if indice == 0 and _desde_la_primera > 0:
		avanzar_por_tiempo()


## Empieza la etapa que viene detrás de la actual. Para quien no sabe en qué número va:
## el bosque pasa de sembrar a lo de lejos sin conocer la lista de la escena.
func siguiente() -> void:
	etapa(_actual + 1)


## Cuánto de la etapa actual está hecho, de 0 a 1. Hacia atrás no se mueve.
func avanzar(fraccion: float) -> void:
	_dentro = maxf(_dentro, clampf(fraccion, 0.0, 1.0))
	_recalcular()


## Avanza la etapa por el TIEMPO que lleva contra lo que se midió que cuesta: para las
## etapas que no tienen contador propio —asentar a la banda, generar el relieve, descargar—,
## donde la barra se quedaba quieta segundos. Ver [fraccion_por_tiempo].
func avanzar_por_tiempo() -> void:
	if _actual < 0 or _actual >= _etapas.size():
		return
	var peso := float(_etapas[_actual]["peso"])
	if peso <= 0.0:
		return
	avanzar(fraccion_por_tiempo(float(Time.get_ticks_usec() - _empezo) / 1000.0, peso))


## Cuánto de una etapa se da por hecho tras `ms` de los `peso` que se espera que cueste:
## proporcional, y **se detiene en el 95 %** si la etapa tarda más de lo medido.
##
## Detenerse es decir la verdad: preparar un valle espera a la red, y Overpass contesta
## entero al final —43 s una vez, medido el 2026-09-15—, sin nada intermedio que contar.
## Se probó a seguir acercándose al final sin llegar, y tras unos segundos se movía tan
## despacio que a la vista estaba quieta igual: fingía avance sin que se viera. Lo que
## dice que no está colgado es la señal de vida de [PantallaDeCarga], decisión del
## usuario (INTERFAZ §9.3).
static func fraccion_por_tiempo(ms: float, peso: float) -> float:
	if peso <= 0.0:
		return 0.0
	return minf(0.95, maxf(ms, 0.0) / peso)


## La etapa actual resultó más corta de lo medido —la vuelta al valle no siembra— y queda
## hecha con lo que llevaba: su peso pasa a ser lo que ha tardado. Si no, la barra se
## quedaba atrás todo lo que pesaba sembrar y saltaba al final.
func dar_por_hecha_la_etapa() -> void:
	if _actual < 0 or _actual >= _etapas.size():
		return
	var peso := float(_etapas[_actual]["peso"])
	var tardado := minf(float(Time.get_ticks_usec() - _empezo) / 1000.0, peso)
	_etapas[_actual]["peso"] = tardado
	_total -= peso - tardado
	_dentro = 1.0
	_recalcular()


## Da por hecho todo lo declarado.
func terminar() -> void:
	_hecho = _total
	_dentro = 0.0
	_actual = _etapas.size()
	_recalcular()


func valor() -> float:
	return _mostrado


func texto() -> String:
	return String(_etapas[_actual]["texto"]) if _actual >= 0 and _actual < _etapas.size() else ""


func _recalcular() -> void:
	if _total <= 0.0:
		return
	var peso := float(_etapas[_actual]["peso"]) if _actual >= 0 and _actual < _etapas.size() else 0.0
	var fraccion := clampf((_hecho + peso * _dentro) / _total, 0.0, 1.0)
	_mostrado = maxf(_mostrado, _base + (1.0 - _base) * fraccion)
