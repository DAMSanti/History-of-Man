class_name ParedDeLaCueva
extends RefCounted
## La zona pintable de una cueva: su relieve, y dónde va cada figura.
##
## SISTEMAS §13, spec del 2026-09-15: **la pintura tiene su sitio**. En el
## Paleolítico se aprovechaban las formas de la roca —un abombamiento para el
## vientre de un bisonte, una grieta para el lomo—, y así se pinta aquí: la figura
## no la coloca el jugador ni cae en un hueco cualquiera, va **donde la roca la
## recalca**.
##
## **Es de la simulación y no de la vista**, aunque sea algo que se ve: el sitio de
## cada figura es un hecho de la partida y lo decide el paso. Por eso es puro —sin
## nodos, recursos ni texturas— y se puede calcular en el hilo de un campamento
## fuera del árbol (SPECS §3.1). La vista dibuja esta misma pared con más detalle.
##
## **Azar propio**, sembrado con la partida, el sitio y la cueva, y nunca el
## `_rng` de la simulación (SPECS §7): la pared de una cueva no puede depender de
## cuántas veces se haya preguntado por ella.

## Celdas de la rejilla de relieve, y lo que mide cada una.
##
## Doce metros por cuatro con ochenta, en celdas de siete centímetros y medio: una
## zona pintable del tamaño de un friso de verdad —el techo de Altamira mide unos
## dieciocho por nueve— y lo bastante fina para que una mano de veinte centímetros
## caiga en tres celdas. Es una decisión de tamaño, no una medida.
const ANCHO := 160
const ALTO := 64
const CELDA_M := 0.075

## De qué tamaño se pinta cada figura, en metros de lado de su cuadrado.
##
## Órdenes de magnitud de las figuras reales: los bisontes del techo de Altamira
## miden entre 1,4 y 1,8 m, las ciervas de Covalanas alrededor de un metro, las
## manos de El Castillo unos veinte centímetros. Decisión de la spec, a partir de
## ahí; no se miden en la partida.
const TAMANO_M := {
	"bisonte": 1.5, "cierva": 1.2, "ciervo": 1.4, "caballo": 1.4, "uro": 1.5,
	"jabali": 1.0, "mano": 0.24, "puntos": 0.7, "bastoncillos": 0.5,
	"claviforme": 0.6, "tectiforme": 0.6, "escaleriforme": 0.9,
}

## Cuánto pesa que el contorno siga una arista de la roca frente a que el cuerpo
## caiga en un abombamiento. Medio: el abombamiento es lo que da cuerpo, la arista
## lo que dibuja. Decisión.
const PESO_DEL_CONTORNO := 0.5

## Cuánto puede pisar una figura a otras antes de dar el sitio por ocupado.
const PISADA_TOLERADA := 0.10

var semilla_de_la_pared: int = 0

## La altura de la roca en cada celda, en metros hacia fuera. `y * ANCHO + x`.
var relieve := PackedFloat32Array()

## Cuánto se abomba la roca en cada celda, normalizado: positivo es bulto.
var convexidad := PackedFloat32Array()

## Cuánto cae la roca en cada celda, normalizado: alto es arista o grieta.
var pendiente := PackedFloat32Array()

## Las figuras puestas, en el orden en que se pusieron:
## `{motivo, color, centro: Vector2 (m), lado, giro (rad), espejo, documentada}`.
var figuras: Array[Dictionary] = []

## Qué figura ocupa cada celda, o -1.
var _ocupada := PackedInt32Array()


# --- la pared -------------------------------------------------------------------

## La pared de una cueva, siempre la misma para la misma partida, sitio y cueva.
static func de(semilla: int, sitio: int, cueva: int) -> ParedDeLaCueva:
	var pared := ParedDeLaCueva.new()
	pared.semilla_de_la_pared = hash([semilla, sitio, cueva, "pared"])
	pared._levantar_el_relieve()
	return pared


func _levantar_el_relieve() -> void:
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla_de_la_pared
	relieve.resize(ANCHO * ALTO)
	relieve.fill(0.0)
	_ocupada.resize(ANCHO * ALTO)
	_ocupada.fill(-1)
	var ancho_m := ANCHO * CELDA_M
	var alto_m := ALTO * CELDA_M

	# ABOMBAMIENTOS: la roca de una cueva caliza es un paño de bultos redondeados,
	# de medio metro a metro y medio.
	for _i in range(10 + azar.randi_range(0, 6)):
		var centro := Vector2(azar.randf() * ancho_m, azar.randf() * alto_m)
		var radio := Vector2(azar.randf_range(0.4, 1.6), azar.randf_range(0.3, 1.0))
		var alto := azar.randf_range(0.05, 0.25)
		_sumar_bulto(centro, radio, alto)

	# GRIETAS Y ARISTAS: líneas quebradas que hunden la roca.
	for _i in range(3 + azar.randi_range(0, 3)):
		var punto := Vector2(azar.randf() * ancho_m, azar.randf() * alto_m)
		var rumbo := azar.randf() * TAU
		var hondo := azar.randf_range(0.03, 0.08)
		var ancho := azar.randf_range(0.04, 0.10)
		for _tramo in range(6 + azar.randi_range(0, 6)):
			rumbo += azar.randf_range(-0.6, 0.6)
			var siguiente := punto + Vector2(cos(rumbo), sin(rumbo)) * 0.3
			_hundir_tramo(punto, siguiente, hondo, ancho)
			punto = siguiente

	_medir_la_forma()


func _sumar_bulto(centro: Vector2, radio: Vector2, alto: float) -> void:
	var x0 := maxi(int((centro.x - radio.x * 2.5) / CELDA_M), 0)
	var x1 := mini(int((centro.x + radio.x * 2.5) / CELDA_M), ANCHO - 1)
	var y0 := maxi(int((centro.y - radio.y * 2.5) / CELDA_M), 0)
	var y1 := mini(int((centro.y + radio.y * 2.5) / CELDA_M), ALTO - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2((x * CELDA_M - centro.x) / radio.x,
				(y * CELDA_M - centro.y) / radio.y)
			relieve[y * ANCHO + x] += alto * Calculo.exponencial(-d.length_squared())


func _hundir_tramo(a: Vector2, b: Vector2, hondo: float, ancho: float) -> void:
	var margen := ancho * 3.0
	var x0 := maxi(int((minf(a.x, b.x) - margen) / CELDA_M), 0)
	var x1 := mini(int((maxf(a.x, b.x) + margen) / CELDA_M), ANCHO - 1)
	var y0 := maxi(int((minf(a.y, b.y) - margen) / CELDA_M), 0)
	var y1 := mini(int((maxf(a.y, b.y) + margen) / CELDA_M), ALTO - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x * CELDA_M, y * CELDA_M)
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
			relieve[y * ANCHO + x] -= hondo * Calculo.exponencial(-(d * d) / (ancho * ancho))


## Convexidad y pendiente, a la escala de una figura y no del grano de la roca:
## un bulto de medio metro, no una rugosidad de un centímetro.
func _medir_la_forma() -> void:
	var suave := _suavizar(relieve, 2)
	convexidad.resize(ANCHO * ALTO)
	pendiente.resize(ANCHO * ALTO)
	var paso := 2
	for y in range(ALTO):
		for x in range(ANCHO):
			var c := suave[y * ANCHO + x]
			var xm := suave[y * ANCHO + maxi(x - paso, 0)]
			var xp := suave[y * ANCHO + mini(x + paso, ANCHO - 1)]
			var ym := suave[maxi(y - paso, 0) * ANCHO + x]
			var yp := suave[mini(y + paso, ALTO - 1) * ANCHO + x]
			# Laplaciano con el signo cambiado: un bulto da positivo.
			convexidad[y * ANCHO + x] = 4.0 * c - xm - xp - ym - yp
			pendiente[y * ANCHO + x] = Vector2(xp - xm, yp - ym).length()
	_normalizar(convexidad)
	_normalizar(pendiente)


static func _suavizar(campo: PackedFloat32Array, radio: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(campo.size())
	var fuera := PackedFloat32Array()
	fuera.resize(campo.size())
	for y in range(ALTO):
		for x in range(ANCHO):
			var suma := 0.0
			var n := 0
			for dx in range(-radio, radio + 1):
				var xx := x + dx
				if xx >= 0 and xx < ANCHO:
					suma += campo[y * ANCHO + xx]
					n += 1
			tmp[y * ANCHO + x] = suma / float(n)
	for y in range(ALTO):
		for x in range(ANCHO):
			var suma := 0.0
			var n := 0
			for dy in range(-radio, radio + 1):
				var yy := y + dy
				if yy >= 0 and yy < ALTO:
					suma += tmp[yy * ANCHO + x]
					n += 1
			fuera[y * ANCHO + x] = suma / float(n)
	return fuera


static func _normalizar(campo: PackedFloat32Array) -> void:
	var media := 0.0
	for v: float in campo:
		media += v
	media /= float(campo.size())
	var varianza := 0.0
	for v: float in campo:
		varianza += (v - media) * (v - media)
	var desviacion := sqrt(varianza / float(campo.size()))
	if desviacion <= 0.0:
		return
	for i in range(campo.size()):
		campo[i] = (campo[i] - media) / desviacion


# --- cómo recalca la roca una figura ---------------------------------------------

## Los puntos de muestra de un motivo, en sus coordenadas: los de dentro del cuerpo,
## los del contorno y los del anillo de fuera. Se sacan una vez por motivo.
##
## Muestrear y no rasterizar la figura en cada intento es lo que hace que buscar
## sitio quepa en un paso: unos doscientos puntos por intento en vez de cientos de
## celdas con su punto-en-polígono. Con cerrojo, porque los campamentos dan su paso
## a la vez en el `WorkerThreadPool` (`RelojDeLaPartida`).
static var _muestras: Dictionary = {}
static var _cerrojo := Mutex.new()

const _RASTER := 40
const _MAX_DENTRO := 90
const _MAX_BORDE := 60
const _MAX_FUERA := 60


static func muestras_de(motivo: String) -> Dictionary:
	_cerrojo.lock()
	var hechas: Variant = _muestras.get(motivo, null)
	_cerrojo.unlock()
	if hechas != null:
		return hechas
	var cuerpo := Motivos.cuerpo_de(motivo)
	var dentro_de := PackedByteArray()
	dentro_de.resize(_RASTER * _RASTER)
	for j in range(_RASTER):
		for i in range(_RASTER):
			var p := Vector2((i + 0.5) / _RASTER - 0.5, (j + 0.5) / _RASTER - 0.5)
			dentro_de[j * _RASTER + i] = 1 if dentro(cuerpo, p) else 0
	var dentro_p := PackedVector2Array()
	var borde_p := PackedVector2Array()
	var fuera_p := PackedVector2Array()
	for j in range(_RASTER):
		for i in range(_RASTER):
			var p := Vector2((i + 0.5) / _RASTER - 0.5, (j + 0.5) / _RASTER - 0.5)
			var vecinos_dentro := 0
			var vecinos := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ii := i + d.x
				var jj := j + d.y
				vecinos += 1
				if ii < 0 or jj < 0 or ii >= _RASTER or jj >= _RASTER:
					continue
				vecinos_dentro += dentro_de[jj * _RASTER + ii]
			if dentro_de[j * _RASTER + i] == 1:
				if vecinos_dentro < vecinos:
					borde_p.append(p)
				else:
					dentro_p.append(p)
			elif vecinos_dentro > 0:
				fuera_p.append(p)
	@warning_ignore("integer_division")
	var hechas_ahora := {
		"dentro": _aclarar(dentro_p, _MAX_DENTRO),
		"borde": _aclarar(borde_p, _MAX_BORDE),
		"fuera": _aclarar(fuera_p, _MAX_FUERA),
		# Un tercio, para la pasada gorda de [_buscar].
		"dentro_r": _aclarar(dentro_p, _MAX_DENTRO / 3),
		"borde_r": _aclarar(borde_p, _MAX_BORDE / 3),
		"fuera_r": _aclarar(fuera_p, _MAX_FUERA / 3),
	}
	_cerrojo.lock()
	_muestras[motivo] = hechas_ahora
	_cerrojo.unlock()
	return hechas_ahora


static func _aclarar(puntos: PackedVector2Array, tope: int) -> PackedVector2Array:
	if puntos.size() <= tope:
		return puntos
	var fuera := PackedVector2Array()
	var paso := float(puntos.size()) / float(tope)
	for k in range(tope):
		fuera.append(puntos[int(k * paso)])
	return fuera


## Si un punto está dentro de unos anillos, por paridad: un hueco dentro de un
## exterior cuenta como fuera.
static func dentro(anillos: Array, p: Vector2) -> bool:
	var cruces := 0
	for anillo: PackedVector2Array in anillos:
		if Geometry2D.is_point_in_polygon(p, anillo):
			cruces += 1
	return cruces % 2 == 1


## Cuánto recalca la roca una figura puesta así. `-INF` si alguna muestra se sale.
##
## El cuerpo sobre un abombamiento —más convexo dentro que en el anillo de fuera—
## y el contorno sobre una arista —pendiente alta donde está el borde—. Es la
## misma cuenta que usa el criterio de la spec, «mejor que el 90 % de los sitios al
## azar»: por construcción sale, y lo que hay que mirar de verdad es que la cuenta
## sea la buena, que se ve en las capturas (SISTEMAS §13, plan técnico).
func ajuste(motivo: String, centro: Vector2, lado: float, giro: float, espejo: bool) -> float:
	var m := muestras_de(motivo)
	return _evaluar(m["dentro"], m["fuera"], m["borde"], centro, lado, giro, espejo,
		false, false)


## La cuenta de [ajuste], y a la vez lo que pisa: `-INF` si se sale, si toca algo
## documentado o —con `mira_pisadas` y sin `encima`— si pisa a otras más de lo
## tolerado.
##
## **Todo en un bucle y sin llamadas por muestra.** En GDScript llamar a una función
## por cada punto es lo caro: con el ajuste, la media y la celda en funciones
## sueltas, colocar una figura costaba 248 ms de media (`ParedProbe`, 2026-09-15),
## un tirón dentro del paso y más de 2 s para las once figuras de Altamira.
func _evaluar(dentro_p: PackedVector2Array, fuera_p: PackedVector2Array,
		borde_p: PackedVector2Array, centro: Vector2, lado: float, giro: float,
		espejo: bool, mira_pisadas: bool, encima: bool) -> float:
	var c := cos(giro) * lado
	var s := sin(giro) * lado
	var signo := -1.0 if espejo else 1.0
	var limite_x := ANCHO * CELDA_M
	var limite_y := ALTO * CELDA_M
	var suma_dentro := 0.0
	var pisadas := 0
	for p: Vector2 in dentro_p:
		var x := p.x * signo
		var wx := x * c - p.y * s + centro.x
		var wy := x * s + p.y * c + centro.y
		if wx < 0.0 or wy < 0.0 or wx >= limite_x or wy >= limite_y:
			return -INF
		var celda := int(wy / CELDA_M) * ANCHO + int(wx / CELDA_M)
		if mira_pisadas:
			var quien := _ocupada[celda]
			if quien >= 0:
				if bool(figuras[quien]["documentada"]):
					return -INF
				pisadas += 1
		suma_dentro += convexidad[celda]
	if mira_pisadas and not encima and dentro_p.size() > 0 \
			and float(pisadas) / float(dentro_p.size()) > PISADA_TOLERADA:
		return -INF
	var suma_fuera := 0.0
	for p: Vector2 in fuera_p:
		var x := p.x * signo
		var wx := x * c - p.y * s + centro.x
		var wy := x * s + p.y * c + centro.y
		if wx < 0.0 or wy < 0.0 or wx >= limite_x or wy >= limite_y:
			return -INF
		suma_fuera += convexidad[int(wy / CELDA_M) * ANCHO + int(wx / CELDA_M)]
	# EL CONTORNO TAMBIÉN PISA. Mirando sólo el cuerpo, las cuernas de un ciervo a
	# línea se metían en la cabeza de un uro con seis figuras en la pared (captura
	# del 2026-09-15): el trazo cruzaba a la otra figura sin contar como pisada.
	var suma_borde := 0.0
	var pisadas_borde := 0
	for p: Vector2 in borde_p:
		var x := p.x * signo
		var wx := x * c - p.y * s + centro.x
		var wy := x * s + p.y * c + centro.y
		if wx < 0.0 or wy < 0.0 or wx >= limite_x or wy >= limite_y:
			return -INF
		var celda := int(wy / CELDA_M) * ANCHO + int(wx / CELDA_M)
		if mira_pisadas:
			var quien := _ocupada[celda]
			if quien >= 0:
				if bool(figuras[quien]["documentada"]):
					return -INF
				pisadas_borde += 1
		suma_borde += pendiente[celda]
	if mira_pisadas and not encima and borde_p.size() > 0 			and float(pisadas_borde) / float(borde_p.size()) > PISADA_TOLERADA:
		return -INF
	var media_dentro := suma_dentro / float(maxi(dentro_p.size(), 1))
	var media_fuera := suma_fuera / float(maxi(fuera_p.size(), 1))
	var media_borde := suma_borde / float(maxi(borde_p.size(), 1))
	return (media_dentro - media_fuera) + PESO_DEL_CONTORNO * media_borde


## La celda de la pared donde cae una muestra de figura, o -1 si se sale.
static func celda_de(p: Vector2, figura: Dictionary) -> int:
	var lado := float(figura["lado"])
	var giro := float(figura["giro"])
	var centro: Vector2 = figura["centro"]
	var x := -p.x if bool(figura["espejo"]) else p.x
	var wx := (x * cos(giro) - p.y * sin(giro)) * lado + centro.x
	var wy := (x * sin(giro) + p.y * cos(giro)) * lado + centro.y
	if wx < 0.0 or wy < 0.0 or wx >= ANCHO * CELDA_M or wy >= ALTO * CELDA_M:
		return -1
	return int(wy / CELDA_M) * ANCHO + int(wx / CELDA_M)


# --- dónde va -------------------------------------------------------------------

## Pone una figura donde mejor la recalca la roca y la apunta. Devuelve su sitio:
## `{motivo, color, centro, lado, giro, espejo, documentada}`.
##
## **Lo documentado no se pisa nunca.** Y con la pared llena **se pinta encima**
## —decisión del usuario del 2026-09-15, «como en las cuevas reales»: La Pasiega
## está llena de superposiciones—: si no queda un sitio libre que recalque mejor que
## la mitad de los sitios al azar, la figura va sobre la más antigua de la banda.
##
## **El listón es la mediana.** Se probó el 90 % (2026-09-15) para cumplir el
## criterio de la spec contra cualquier sitio, y pintaba encima con la pared a
## medias —14 de 96 figuras pisaban a otra con ocho por pared—. El usuario decidió
## entonces que el criterio se mide contra los sitios LIBRES, y con eso el 90 % ya
## no hacía falta: «la pared llena» vuelve a significar llena.
## `pintado` es cuánto lleva hecho, de 0 a 1. Uno, lo normal: una figura que ya está. Cero,
## la que se acaba de empezar — el sitio **se reserva al mandar pintar** para poder ver cómo
## se va llenando, y antes del 2026-09-19 se reservaba al terminar, que es justo lo que hacía
## imposible enseñarlo (SISTEMAS §13).
func colocar(motivo: String, color: String, documentada: bool,
		pintado: float = 1.0) -> Dictionary:
	var lado := float(TAMANO_M.get(motivo, 1.0))
	var libre := _buscar(motivo, lado, false, -1)
	var sitio := libre
	if not documentada and (libre.is_empty()
			or float(libre["ajuste"]) < _liston_al_azar(motivo)):
		var antigua := _la_mas_antigua_de_la_banda()
		if antigua >= 0:
			var encima := _buscar(motivo, lado, true, antigua)
			# EL MEJOR DE LOS DOS, no «encima» a ciegas. Pintar sobre la más antigua
			# para quedar en un hueco que recalca PEOR que el mejor sitio libre no sirve
			# a ninguna de las dos cosas que pidió el usuario —«la pintura tiene su
			# sitio» y «se pinta encima, como en las cuevas reales»—, y dejaba una figura
			# al 88 % de la pared (`ParedProbe`, 2026-09-15). Es una lectura de la
			# decisión, dicha en SISTEMAS §13 para que se pueda corregir.
			if not encima.is_empty() and (libre.is_empty()
					or float(encima["ajuste"]) >= float(libre["ajuste"])):
				sitio = encima
	if sitio.is_empty():
		return {}
	# EL LADO PROBADO, no el de la tabla: se busca a dos escalas, y guardando el de
	# la tabla la figura quedaba de otro tamaño que el que se había medido —y sus
	# muestras caían donde no se había mirado, encima de lo documentado incluido—.
	# Lo cazó `TestPared` el 2026-09-15.
	var figura := {
		"motivo": motivo, "color": color, "centro": sitio["centro"],
		"lado": sitio["lado"], "giro": sitio["giro"], "espejo": sitio["espejo"],
		"documentada": documentada,
		# Cuánto lleva pintado, de 0 a 1. Lo lee [SalaDeLaCueva], que dibuja los trazos
		# hasta donde llegue. El diccionario se guarda por referencia, así que quien pinta
		# sube este número y la pared se entera sola.
		"pintado": clampf(pintado, 0.0, 1.0),
	}
	poner(figura)
	return figura


## Apunta una figura ya colocada —la de un relato guardado— sin buscarle sitio.
func poner(figura: Dictionary) -> void:
	var indice := figuras.size()
	figuras.append(figura)
	var m := muestras_de(String(figura["motivo"]))
	for grupo: String in ["dentro", "borde"]:
		for p: Vector2 in m[grupo]:
			var celda := celda_de(p, figura)
			if celda < 0:
				continue
			# Un poco de brocha alrededor de cada muestra, que son dispersas.
			var cx := celda % ANCHO
			@warning_ignore("integer_division")
			var cy := celda / ANCHO
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := cx + dx
					var yy := cy + dy
					if xx < 0 or yy < 0 or xx >= ANCHO or yy >= ALTO:
						continue
					var k := yy * ANCHO + xx
					# Lo documentado sigue siendo lo documentado aunque algo lo roce.
					if _ocupada[k] >= 0 and bool(figuras[_ocupada[k]]["documentada"]):
						continue
					_ocupada[k] = indice


## QUITA DE LA ROCA UNA FIGURA QUE NO LLEGÓ A PINTARSE.
##
## Hace falta desde que el sitio se reserva **al mandar pintar** y no al terminar (ver
## [colocar]): una pared que se queda sin ocre a medias tendría si no media figura en la
## roca para siempre, y sin relato detrás.
##
## Sólo se puede deshacer limpiamente **la última**, porque `_ocupada` guarda el ÍNDICE de
## cada figura y sacar una de en medio correría todos los demás. Y la última es justamente
## la que se acaba de reservar, que es el único caso que esto tiene que atender. Si no lo
## fuera —una pared rehecha a mitad de obra—, se deja en cero trazos: no se dibuja nada, que
## es lo que importa, aunque su hueco quede pedido.
func quitar(figura: Dictionary) -> void:
	if figuras.is_empty():
		return
	if figuras[figuras.size() - 1] != figura:
		figura["pintado"] = 0.0
		return
	var indice := figuras.size() - 1
	for k in range(_ocupada.size()):
		if _ocupada[k] == indice:
			_ocupada[k] = -1
	figuras.remove_at(indice)


## El mejor sitio para una figura: libre, o encima de la figura `sobre` si se da.
##
## **Dos pasadas.** La gorda recorre la pared a zancadas de 8 celdas, a dos
## escalas y con y sin espejo, con un tercio de las muestras; la fina vuelve sobre
## los tres mejores con todas las muestras, celda a celda y con un poco de giro.
func _buscar(motivo: String, lado: float, encima: bool, sobre: int) -> Dictionary:
	var m := muestras_de(motivo)
	var zancada := 8
	var x_desde := 0
	var x_hasta := ANCHO
	var y_desde := 0
	var y_hasta := ALTO
	if encima:
		# Se busca alrededor de la figura que se tapa, no por toda la pared.
		var vieja: Dictionary = figuras[sobre]
		var cv: Vector2 = vieja["centro"]
		# Un lado entero alrededor del centro y no medio: con medio, las figuras que
		# caían encima recalcaban menos que el 90 % de la pared (87–88 %, `ParedProbe`).
		var alcance := int(float(vieja["lado"]) / CELDA_M)
		x_desde = maxi(int(cv.x / CELDA_M) - alcance, 0)
		x_hasta = mini(int(cv.x / CELDA_M) + alcance + 1, ANCHO)
		y_desde = maxi(int(cv.y / CELDA_M) - alcance, 0)
		y_hasta = mini(int(cv.y / CELDA_M) + alcance + 1, ALTO)
		zancada = 3
	var candidatos: Array[Dictionary] = []
	for escala: float in ESCALAS:
		for espejo: bool in [false, true]:
			for cy in range(y_desde, y_hasta, zancada):
				for cx in range(x_desde, x_hasta, zancada):
					var centro := Vector2((cx + 0.5) * CELDA_M, (cy + 0.5) * CELDA_M)
					var a := _evaluar(m["dentro_r"], m["fuera_r"], m["borde_r"], centro,
						lado * escala, 0.0, espejo, true, encima)
					if is_inf(a):
						continue
					candidatos.append({"centro": centro, "lado": lado * escala,
						"espejo": espejo, "ajuste": a})
	if candidatos.is_empty():
		return {}
	candidatos.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return float(p["ajuste"]) > float(q["ajuste"]))
	var mejor := {}
	var mejor_ajuste := -INF
	@warning_ignore("integer_division")
	var medio := zancada / 2
	for candidato: Dictionary in candidatos.slice(0, 3):
		var base: Vector2 = candidato["centro"]
		for giro: float in [-0.2, 0.0, 0.2]:
			for dy in range(-medio, medio + 1):
				for dx in range(-medio, medio + 1):
					var centro := base + Vector2(dx, dy) * CELDA_M
					var a := _evaluar(m["dentro"], m["fuera"], m["borde"], centro,
						float(candidato["lado"]), giro, bool(candidato["espejo"]), true, encima)
					if a > mejor_ajuste:
						mejor_ajuste = a
						mejor = {"centro": centro, "lado": candidato["lado"], "giro": giro,
							"espejo": candidato["espejo"], "ajuste": a}
	return mejor


## A qué escalas del tamaño de la tabla se prueba una figura.
const ESCALAS := [0.9, 1.15]


func _la_mas_antigua_de_la_banda() -> int:
	for i in range(figuras.size()):
		if not bool(figuras[i]["documentada"]):
			return i
	return -1


## Cuántos sitios al azar se miran para el listón.
##
## Doscientos y no sesenta y cuatro: el percentil 90 de 64 muestras es ruidoso, y
## con él dos figuras de sesenta pasaban el listón propio y se quedaban al 87–88 %
## frente a los 200 sitios de la sonda (`ParedProbe`, 2026-09-15).
const MUESTRAS_DEL_LISTON := 200


## La mediana del ajuste en sitios al azar, con azar propio de la pared: el listón
## de «recalca bien». Ver [colocar].
func _liston_al_azar(motivo: String) -> float:
	var valores := ajustes_al_azar(motivo, MUESTRAS_DEL_LISTON, semilla_de_la_pared)
	if valores.is_empty():
		return -INF
	@warning_ignore("integer_division")
	return valores[valores.size() / 2]


## El ajuste de `cuantos` sitios al azar de la pared, ordenado. Lo usan el listón de
## arriba y la sonda del criterio.
func ajustes_al_azar(motivo: String, cuantos: int, semilla: int) -> PackedFloat32Array:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([semilla, motivo, "al azar"])
	var lado := float(TAMANO_M.get(motivo, 1.0))
	var valores := PackedFloat32Array()
	var intentos := 0
	while valores.size() < cuantos and intentos < cuantos * 20:
		intentos += 1
		var centro := Vector2(azar.randf() * ANCHO * CELDA_M, azar.randf() * ALTO * CELDA_M)
		var a := ajuste(motivo, centro, lado * float(ESCALAS[azar.randi() % ESCALAS.size()]),
			0.0, azar.randf() < 0.5)
		if not is_inf(a):
			valores.append(a)
	valores.sort()
	return valores


## Qué figura ocupa una celda, o -1. Para las pruebas.
func ocupada_en(celda: int) -> int:
	return _ocupada[celda]
