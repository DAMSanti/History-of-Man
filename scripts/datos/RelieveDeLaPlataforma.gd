class_name RelieveDeLaPlataforma
extends RefCounted
## La orografía de la plataforma que emerge con el mar bajo.
##
## Petición del usuario del 2026-09-14: «la plataforma emergida es totalmente
## plana». La batimetría del relieve regional va a 111 m por muestra y el fondo
## sale liso: con el mar a −120 m se veía una llanura sin un bulto.
##
## **Reescrito el mismo día, con la queja repetida**: la primera versión subía el
## fondo saturando hacia la cota cero de hoy —para no mover la costa actual—, así
## que las lomas se quedaban en veinte o treinta metros sobre un mapa de doscientos
## kilómetros: invisibles. El usuario: «no se aprecia NADA de elevación… quiero que
## tenga orografía como hoy la hay entre Santander y Torrelavega».
##
## **Las alturas salen de ahí, medidas** sobre `cantabria_region.res` en la franja
## costera entre las dos (43,33–43,48 N, 4,08–3,78 O; 28 637 celdas de tierra):
##
## | | p05 | p25 | p50 | p75 | p90 | p99 | máx |
## |---|---|---|---|---|---|---|---|
## | cota | 3 m | 19 m | 48 m | 100 m | 159 m | 312 m | 515 m |
##
## y el terreno sube o baja **22 m por kilómetro** de mediana, 86 en el décimo más
## quebrado. El ruido se mapea a esa escalera de percentiles, así que la plataforma
## tiene la misma repartición de alturas que esa costa, y la escala de las formas
## sale de ese desnivel por kilómetro.
##
## **Retirado el 2026-09-17, en un depurar** (GRAFICOS §3): las lomas ya no salen de un
## ruido mapeado a esos percentiles, sino de **detalle de relieve real prestado** de esa
## misma franja costera ([RelievePrestado]). El usuario: «no te la inventes, busca
## orografía que cuadre… aunque sea de otro lugar». Lo de arriba queda como historia de
## por qué la plataforma tenía relieve; las cifras ya no están en el código.
##
## **Dos promesas, y las dos por construcción:**
##
## - **Lo que está bajo el agua no se toca**, así que con el mar de hoy la plataforma
##   sigue siendo mar.
## - **La costa sólo entra por las rías** (2026-09-17). El relieve prestado baja además
##   de subir, y una vaguada que llega al mar se inunda: es una ría. Una que no llega se
##   queda como valle, con su forma, por encima del agua.
##
## *(Hasta el 2026-09-17 las promesas eran otras dos: «la costa de la época no se
## mueve» y «la orilla es llana», con una rampa de 600 m sin lomas desde la costa
## —decisión del usuario del 2026-09-14—. Con relieve real prestado dejaban **el 14,3 %
## de la plataforma en la franja marrón de orilla**, y el 10,7 % pegado a un metro sobre
## el agua por el recorte que evitaba que el mar entrara. El usuario: «veo mucho terreno
## marrón; cuando esté en costa crea rías, y si no, soluciónalo con valles».)*
##
## Lo usan los tres que dibujan o miden la plataforma: [RegionMap] al montar el
## terreno, `tools/HornearEras.gd` al hornear las máscaras de cada época —cada una
## con SU mar— y `TestFrontera`.

## Hasta qué cota de hoy hay plataforma: por encima de cero es tierra de siempre y
## no se toca.
const HASTA := 0.0

## Cuánto tardan las LOMAS en subir desde la costa, en metros. Las vaguadas no esperan:
## llegan hasta el agua, y ahí se hacen rías.
##
## Era de 600 m y valía para las dos —«llanura costera antes de las colinas», decisión del
## usuario del 2026-09-14—. Con relieve prestado, esa llanura era buena parte del marrón
## que el usuario pidió quitar (2026-09-17): se queda en lo justo para que una loma no
## salga cortada a pico en el agua.
const LLANURA_M := 200.0

## Cuánto se levanta, como mucho, el fondo de un valle que no llega al mar y se quedaría
## por debajo de él. Se levanta con una curva y no a un llano, para que conserve su forma.
const SUELO_DE_VALLE_M := 4.0

## En cuántos metros de cota se desvanece el detalle prestado al acercarse a la COSTA DE
## HOY, que es donde la plataforma se acaba y empieza el relieve de verdad.
##
## **Por qué existe**: sin desvanecido el detalle entraba de golpe justo en la isolínea y
## dibujaba una raya de celdas con escalón. Medido en el valle del sitio 36: **saltos de
## hasta 49,5 m entre celdas contiguas a 5 m**, cuando el LiDAR real de ese mismo valle no
## pasa de 21,6 m (2026-09-17).
##
## *(El primer intento lo puso también en el borde de abajo —el mar de la época— y **se
## comió el relieve**: la plataforma está casi toda a menos de 30 m de esa cota, así que el
## detalle se anulaba en casi todas partes. Medido en el perfil de delante del Pas: de
## −152..+80 m pasó a −120..−20. Abajo no hace falta desvanecer nada, porque desde el mismo
## día el fondo sumergido TAMBIÉN lleva detalle y no hay frontera que cruzar.)*
const ORILLAS_M := 30.0

## Hasta cuántos metros POR DEBAJO del mar de la época llega el detalle prestado, y en
## cuántos se desvanece.
##
## El fondo sumergido lleva detalle para que la isolínea del mar no sea un corte, pero no
## todo el fondo: por debajo de esto vuelve a ser batimetría medida y nada más —el cañón a
## −3 413 m no es relieve de costa prestado—. La frontera del desvanecido cae a 60 m bajo
## la lámina, **donde no se ve**, que es justo lo que no se podía hacer en la orilla.
const HONDO_DEL_DETALLE_M := 60.0

## Cada cuántas muestras se mide la distancia a la costa. A 111 m por muestra, de
## cuatro en cuatro son 444 m: de sobra para una rampa de 600, y cuesta la
## dieciseisava parte.
const PASO_DE_LA_DISTANCIA := 4

## La versión de cómo se leen las cifras de arriba. **2 desde el 2026-09-16**: la
## distancia a la costa se lee interpolada y no por casillas de cuatro muestras, que
## en un valle de 5 m salían en terrazas de 444 m (EPOCA_01 §10.2). **4 desde el
## 2026-09-17**: las lomas son relieve real prestado y no ruido; **5**, el mismo día: las
## rías y los valles; **6**, el mismo día: el detalle se desvanece en los dos bordes. Entra en la [huella], así que la malla regional se rehace sola.
const VERSION := 6

## Cuánto se escala el detalle prestado: 1 es el relieve real tal cual.
##
## **Es `static var` y no constante a propósito**: cuánto se elige mirando capturas con
## varias propuestas, que la sonda pone cambiando esto (`PlataformaCaptura AMPLITUDES=`).
## Fuera de la sonda nadie lo toca; entra en la [huella], así que cada propuesta tiene su
## malla.
## *(Valía 1,6 desde el 2026-09-16, elegido sobre capturas de relieve INVENTADO. Con el
## detalle real prestado se vuelve a elegir: de momento, 1 —el relieve como es—.)*
static var amplitud := 1.0

## Cuánto se abre un valle a cada lado de un río de la plataforma, en metros. A esta
## distancia las lomas ya son las de siempre; en el río, el fondo del valle.
const ANCHO_DEL_VALLE_M := 1500.0

## Cuánto se hunde el fondo del valle bajo la cota más baja que lleva el río, en
## metros. Es lo que hace que baje siempre, aunque la batimetría tenga un umbral.
const HONDO_DEL_CAUCE_M := 3.0


## Le pone orografía a la plataforma emergida con ese mar. Sin `mar`, el del
## Paleolítico.
## Lo que decide estas lomas, en un número: si cambia una cifra de arriba, cambia. Va en
## el nombre de la caché de la malla regional (ver [TerrainGenerator.sufijo_de_la_cache]),
## así que retocar las lomas rehace la malla sola en vez de seguir enseñando la vieja.
static func huella() -> int:
	return hash([HASTA, LLANURA_M, SUELO_DE_VALLE_M, ORILLAS_M, HONDO_DEL_DETALLE_M,
		PASO_DE_LA_DISTANCIA, VERSION, amplitud, ANCHO_DEL_VALLE_M, HONDO_DEL_CAUCE_M,
		RelievePrestado.huella()])


static func aplicar(data: HeightmapData, mar: float = -120.0, cauces: Array = []) -> void:
	if data == null or data.elevations.is_empty():
		return
	var plataforma := para(data, mar, cauces)
	var elevaciones := PackedFloat32Array(data.elevations)
	for i in range(elevaciones.size()):
		var e := elevaciones[i]
		if e >= HASTA:
			continue
		var x := i % data.width
		@warning_ignore("integer_division")
		var z := i / data.width
		elevaciones[i] = plataforma._cota_de_la_plataforma(e, float(x), float(z))
	data.elevations = elevaciones


# --- La cota de un punto suelto ------------------------------------------------
#
# `aplicar` trabaja sobre la rejilla regional entera, a 111 m por muestra. El valle
# de un sitio de la plataforma se inventa a 5 m (EPOCA_01 §10.2) y tiene que casar
# con lo que se ve en el mapa: por eso la cota de un punto sale de LAS MISMAS
# cuentas, con el ruido leído en la posición fraccionaria y las distancias
# interpoladas. En las muestras de la rejilla, las dos dan lo mismo.

var _datos: HeightmapData = null
var _mar: float = -120.0
var _prestado: RelievePrestado = null
## La plataforma con su relieve prestado, sus rías y sus valles, para toda la rejilla. Se
## calcula una vez en [para] porque las rías piden mirar la rejilla entera —qué vaguada
## llega al mar—, y un punto suelto no lo puede saber. Así [aplicar] y [cota_en] leen lo
## mismo.
var _relieve: PackedFloat32Array = PackedFloat32Array()
var _distancia: PackedFloat32Array = PackedFloat32Array()
var _ancho_corto: int = 0
var _alto_corto: int = 0
## La distancia al río de la plataforma más cercano, en las casillas cortas, y la cota
## del fondo de su valle. Vacías si no se dieron ríos.
var _al_rio: PackedFloat32Array = PackedFloat32Array()
var _fondo: PackedFloat32Array = PackedFloat32Array()


## Deja preparada la plataforma de estos datos regionales, **sin aplicar**, para
## preguntarle puntos. Los datos tienen que ser los de siempre, sin lomas. `cauces`
## son los tramos de la plataforma de [RiosDeLaRegion]: por donde van, se abre valle.
static func para(data: HeightmapData, mar: float = -120.0,
		cauces: Array = []) -> RelieveDeLaPlataforma:
	var plataforma := RelieveDeLaPlataforma.new()
	plataforma._datos = data
	plataforma._mar = mar
	if data == null or data.elevations.is_empty():
		return plataforma
	plataforma._prestado = RelievePrestado.de_la_comarca()
	plataforma._distancia = _distancia_a_la_costa(data.elevations, data.width, mar,
		data.meters_per_sample)
	plataforma._ancho_corto = int(ceil(float(data.width) / float(PASO_DE_LA_DISTANCIA)))
	plataforma._alto_corto = int(ceil(float(data.height) / float(PASO_DE_LA_DISTANCIA)))
	plataforma._poner_el_relieve()
	if not cauces.is_empty():
		plataforma._valles(cauces)
	return plataforma


## La cota con lomas en ese punto, en metros.
func cota_en(lon: float, lat: float) -> float:
	if _datos == null or _datos.elevations.is_empty():
		return 0.0
	var u := clampf(_datos.u_for_lon(lon), 0.0, 1.0)
	var v := clampf(_datos.v_for_lat(lat), 0.0, 1.0)
	var e := _datos.sample_bilinear(u, v)
	if e >= HASTA:
		return e
	return _cota_de_la_plataforma(e, u * float(_datos.width - 1), v * float(_datos.height - 1))


## La cota final de una celda de la plataforma con cota de fondo `e`, en la posición
## `fx`, `fz` de la rejilla (en muestras, con decimales).
##
## El nombre largo es a propósito: `MallaDelTerreno` tiene su propio `_cota`, y
## `LlamadasHuerfanas` sólo ve nombres, así que un `_cota` aquí salía como llamada mal
## puesta a la del terreno.
func _cota_de_la_plataforma(e: float, fx: float, fz: float) -> float:
	var con_lomas := _con_lomas(e, fx, fz)
	if _al_rio.is_empty():
		return con_lomas
	var al_rio := _interpolar(_al_rio, fx, fz)
	if al_rio >= ANCHO_DEL_VALLE_M:
		return con_lomas
	# EL VALLE: en el río, el fondo; a [ANCHO_DEL_VALLE_M], las lomas de siempre. El
	# fondo nunca por debajo del mar de la época, que la costa no se mueve.
	# Con el fondo PLANO el primer cuarto: la distancia sale de casillas de 446 m
	# interpoladas, y sin llano el propio río quedaba a doscientos metros de su fondo
	# y subía con las lomas (`TestCosta`, 2026-09-16).
	var abierto := smoothstep(ANCHO_DEL_VALLE_M * 0.25, ANCHO_DEL_VALLE_M, al_rio)
	# Y ABRIR UN VALLE NUNCA SUBE NADA. Con lomas de ruido, que sólo subían, no hacía falta
	# decirlo; con relieve real prestado hay vaguadas más hondas que el fondo del río de al
	# lado, y la mezcla las rellenaba hasta él (`TestCosta`, 2026-09-17: dos puntos).
	# EL CAUCE ELIGE ENTRE SU FONDO Y EL TERRENO CON RELIEVE, no el fondo marino liso: con
	# lomas de ruido el liso siempre quedaba por debajo, y daba igual; con relieve prestado
	# puede quedar por debajo del fondo del río, y el cauce se metía en él y subía al salir
	# (`TestCosta`: −54,7 m y luego −50,9 m, 3,8 m de subida junto a un umbral).
	var con_valle := minf(lerpf(minf(con_lomas, _interpolar(_fondo, fx, fz)), con_lomas,
		abierto), con_lomas)
	# Y EL VALLE TAMBIÉN SE DESVANECE EN LA COSTA DE HOY ([ORILLAS_M]), como el detalle: por
	# encima de esa cota la plataforma devuelve el dato crudo, sin excavar, y sin esto el
	# cauce llegaba excavado a la isolínea y se cortaba en seco. Es la raya que quedaba en
	# el valle del sitio 36: celdas a −25 m pegadas a celdas a 0,4 m (2026-09-17).
	return lerpf(con_lomas, con_valle, smoothstep(0.0, ORILLAS_M, HASTA - e))


## La cota de la plataforma con su relieve prestado, sus rías y sus valles, sin los
## valles de los ríos. Leída de [_relieve].
func _con_lomas(e: float, fx: float, fz: float) -> float:
	if _relieve.is_empty():
		return e
	var x := clampf(fx, 0.0, float(_datos.width - 1))
	var z := clampf(fz, 0.0, float(_datos.height - 1))
	return RelievePrestado._bilineal(_relieve, _datos.width, _datos.height, x, z)


## Le pone a toda la rejilla el relieve prestado, y decide qué vaguada es ría y cuál valle.
func _poner_el_relieve() -> void:
	var ancho := _datos.width
	var alto := _datos.height
	var metros := _datos.meters_per_sample
	_relieve = PackedFloat32Array(_datos.elevations)
	for i in range(_relieve.size()):
		var e := _datos.elevations[i]
		# EL FONDO SUMERGIDO TAMBIÉN LLEVA DETALLE, aunque no se vea: si sólo lo llevara lo
		# emergido, en la isolínea del mar de la época el detalle entraría de golpe y ahí
		# saldría una raya de escalones (2026-09-17, hasta 49,5 m entre celdas). Con las dos
		# orillas del corte tratadas igual, no hay corte.
		if e >= HASTA:
			continue
		var fx := float(i % ancho)
		@warning_ignore("integer_division")
		var fz := float(i / ancho)
		# LAS LOMAS SON RELIEVE REAL PRESTADO, en metros del plano de la rejilla: el mismo
		# punto da el mismo detalle en el mapa regional y en un valle. Ver [RelievePrestado].
		var detalle := _prestado.detalle(fx * metros, fz * metros) * amplitud
		# Y SE DESVANECE EN LOS DOS BORDES de la plataforma ([ORILLAS_M]): fuera de ellos no
		# hay relieve puesto, y entrar de golpe dibujaba una raya de escalones.
		detalle *= smoothstep(0.0, ORILLAS_M, HASTA - e)
		if e < _mar:
			detalle *= smoothstep(HONDO_DEL_DETALLE_M, 0.0, _mar - e)
		# Las lomas suben desde la costa con su rampa; las vaguadas no esperan.
		if detalle > 0.0:
			detalle *= clampf(_interpolar(_distancia, fx, fz) / LLANURA_M, 0.0, 1.0)
		var con_detalle := e + detalle
		# Y LO QUE YA ERA MAR SIGUE SIENDO MAR: el detalle puede levantar el fondo por
		# encima del agua, y eso sería un islote inventado. Se recorta MEDIO METRO BAJO LA
		# LÁMINA, donde el recorte no se ve.
		if e <= _mar:
			con_detalle = minf(con_detalle, _mar - 0.5)
		_relieve[i] = con_detalle

	# LAS RÍAS Y LOS VALLES. El mar de antes del relieve es la semilla de la inundación.
	var mar_de_antes := PackedByteArray()
	mar_de_antes.resize(_relieve.size())
	for i in range(_relieve.size()):
		if _datos.elevations[i] <= _mar:
			mar_de_antes[i] = 1
	_relieve = rias_y_valles(_relieve, ancho, mar_de_antes, _mar)


## Lo que abre valle: la distancia de cada casilla corta al río más cercano y la cota
## del fondo de ese río.
##
## El fondo de cada punto del río es **la cota más baja que lleva recorrida desde la
## boca**, un poco hundida: así el río baja siempre, aunque la batimetría tenga un
## umbral (`RioDeLaPlataforma` los cuenta al hornear). Y nunca por debajo del mar.
func _valles(cauces: Array) -> void:
	var total := _ancho_corto * _alto_corto
	var lejos := 1.0e9
	_al_rio.resize(total)
	_al_rio.fill(lejos)
	_fondo.resize(total)
	_fondo.fill(0.0)
	var paso_m := _datos.meters_per_sample * float(PASO_DE_LA_DISTANCIA)
	for cauce: Dictionary in cauces:
		var vertices: PackedVector2Array = cauce["points"]
		# A PASO FINO, no sólo en los vértices: el fondo es lo más bajo recorrido, y con
		# relieve prestado una vaguada que el río cruza entre dos vértices quedaba más
		# honda que el fondo, y el río subía al salir de ella (`TestCosta`, 3,8 m).
		var puntos := _a_paso_fino(vertices)
		var mas_bajo := INF
		for k in range(puntos.size()):
			var u := clampf(_datos.u_for_lon(puntos[k].x), 0.0, 1.0)
			var v := clampf(_datos.v_for_lat(puntos[k].y), 0.0, 1.0)
			# El fondo sale de la plataforma CON su relieve, no del fondo liso: el río baja
			# por las vaguadas prestadas, y su cauce tiene que ser lo más bajo de ellas.
			var e := _datos.sample_bilinear(u, v)
			var fx := u * float(_datos.width - 1)
			var fz := v * float(_datos.height - 1)
			var aqui := e if (e <= _mar or e >= HASTA) else _con_lomas(e, fx, fz)
			mas_bajo = minf(mas_bajo, aqui)
			var fondo := maxf(mas_bajo - HONDO_DEL_CAUCE_M, _mar + 1.0)
			var cx := clampi(roundi(u * float(_datos.width - 1) / float(PASO_DE_LA_DISTANCIA)),
				0, _ancho_corto - 1)
			var cz := clampi(roundi(v * float(_datos.height - 1) / float(PASO_DE_LA_DISTANCIA)),
				0, _alto_corto - 1)
			var celda := cz * _ancho_corto + cx
			if _al_rio[celda] > 0.0 or fondo < _fondo[celda]:
				_al_rio[celda] = 0.0
				_fondo[celda] = fondo
	# Chanfle de ida y vuelta, llevando el fondo del río del que viene la distancia.
	for zc in range(_alto_corto):
		for xc in range(_ancho_corto):
			var i := zc * _ancho_corto + xc
			if xc > 0:
				_heredar(i, i - 1, paso_m)
			if zc > 0:
				_heredar(i, i - _ancho_corto, paso_m)
	for zc in range(_alto_corto - 1, -1, -1):
		for xc in range(_ancho_corto - 1, -1, -1):
			var i := zc * _ancho_corto + xc
			if xc < _ancho_corto - 1:
				_heredar(i, i + 1, paso_m)
			if zc < _alto_corto - 1:
				_heredar(i, i + _ancho_corto, paso_m)


## LA REGLA DE LAS RÍAS Y LOS VALLES, para cualquier rejilla: la del mapa regional y la de
## un valle rellenado ([RellenoDelMarDeHoy]). Una sola, para que las dos escalas digan lo
## mismo.
##
## `mar_de_antes` marca lo que ya era mar antes de ponerle relieve: es de donde se inunda.
## Lo que ha quedado bajo `mar` y está unido a eso, se inunda —es una ría—. Lo que ha
## quedado bajo `mar` sin llegar al mar no es un lago bajo su nivel —el plano del agua lo
## pintaría de mar—, sino el fondo de un valle, y se levanta por encima del agua.
##
## **Devuelve las cotas nuevas**: un `PackedFloat32Array` se copia en cuanto se escribe
## dentro de una función, así que escribir en el que se recibe no cambia el de quien llama.
static func rias_y_valles(entrada: PackedFloat32Array, ancho: int,
		mar_de_antes: PackedByteArray, mar: float) -> PackedFloat32Array:
	var cotas := entrada
	var total := cotas.size()
	var ria := PackedByteArray()
	ria.resize(total)
	var cola := PackedInt32Array()
	for i in range(total):
		if mar_de_antes[i] == 1:
			ria[i] = 1
			cola.append(i)
	var leido := 0
	while leido < cola.size():
		var i := cola[leido]
		leido += 1
		var x := i % ancho
		for vecino: int in [i - 1, i + 1, i - ancho, i + ancho]:
			if vecino < 0 or vecino >= total or ria[vecino] == 1:
				continue
			if absi(vecino % ancho - x) > 1:
				continue
			if cotas[vecino] <= mar:
				ria[vecino] = 1
				cola.append(vecino)

	# La curva empieza en [SUELO_DE_VALLE_M] sobre el mar y no en el mar, y ahí empalma con
	# pendiente uno. La primera versión empezaba en el mar y **saltaba cuatro metros justo
	# en él** —un valle levantado quedaba más alto que la tierra de al lado—, y a mucha
	# hondura daba exactamente la cota del mar en coma flotante, que el agua pintaba como
	# mar: 1 632 celdas de «ría» sin mar al lado (`TestFrontera`, 2026-09-17). Medio metro
	# de suelo lo impide.
	var tope := mar + SUELO_DE_VALLE_M
	for i in range(total):
		if ria[i] == 1 or cotas[i] >= tope:
			continue
		var levantado := tope + SUELO_DE_VALLE_M * (exp((cotas[i] - tope) / SUELO_DE_VALLE_M) - 1.0)
		cotas[i] = maxf(levantado, mar + 0.5)
	return cotas


## Un cauce con un punto cada media muestra de la rejilla, como mucho.
func _a_paso_fino(vertices: PackedVector2Array) -> PackedVector2Array:
	if vertices.size() < 2:
		return vertices
	var fino := PackedVector2Array()
	var paso_lon := (_datos.lon_east - _datos.lon_west) / float(maxi(_datos.width - 1, 1)) * 0.5
	var paso_lat := absf(_datos.lat_north - _datos.lat_south) / float(maxi(_datos.height - 1, 1)) * 0.5
	for k in range(vertices.size() - 1):
		var a := vertices[k]
		var b := vertices[k + 1]
		var trozos := maxi(1, int(ceil(maxf(absf(b.x - a.x) / paso_lon, absf(b.y - a.y) / paso_lat))))
		for t in range(trozos):
			fino.append(a.lerp(b, float(t) / float(trozos)))
	fino.append(vertices[vertices.size() - 1])
	return fino


func _heredar(aqui: int, de: int, paso_m: float) -> void:
	if _al_rio[de] + paso_m < _al_rio[aqui]:
		_al_rio[aqui] = _al_rio[de] + paso_m
		_fondo[aqui] = _fondo[de]


## Una casilla corta, interpolada en la posición de la rejilla fina.
func _interpolar(casillas: PackedFloat32Array, fx: float, fz: float) -> float:
	var cx := clampf(fx / float(PASO_DE_LA_DISTANCIA), 0.0, float(_ancho_corto - 1))
	var cz := clampf(fz / float(PASO_DE_LA_DISTANCIA), 0.0, float(_alto_corto - 1))
	var x0 := int(floor(cx))
	var z0 := int(floor(cz))
	var x1 := mini(x0 + 1, _ancho_corto - 1)
	var z1 := mini(z0 + 1, _alto_corto - 1)
	var tx := cx - float(x0)
	var tz := cz - float(z0)
	var a := lerpf(casillas[z0 * _ancho_corto + x0], casillas[z0 * _ancho_corto + x1], tx)
	var b := lerpf(casillas[z1 * _ancho_corto + x0], casillas[z1 * _ancho_corto + x1], tx)
	return lerpf(a, b, tz)


## A cuántos metros de la costa está cada celda, en una rejilla de un cuarto de
## lado. Dos pasadas de chanfle —ida y vuelta—, que es lo que cuesta una distancia
## aproximada sin recorrer el mapa entero por cada celda.
static func _distancia_a_la_costa(elevaciones: PackedFloat32Array, ancho: int,
		mar: float, metros_por_muestra: float) -> PackedFloat32Array:
	var alto := int(elevaciones.size() / ancho)
	var ancho_corto := int(ceil(float(ancho) / float(PASO_DE_LA_DISTANCIA)))
	var alto_corto := int(ceil(float(alto) / float(PASO_DE_LA_DISTANCIA)))
	var paso_m := metros_por_muestra * float(PASO_DE_LA_DISTANCIA)
	var lejos := 1.0e9
	var distancia := PackedFloat32Array()
	distancia.resize(ancho_corto * alto_corto)
	for zc in range(alto_corto):
		for xc in range(ancho_corto):
			var i := mini(zc * PASO_DE_LA_DISTANCIA, alto - 1) * ancho \
				+ mini(xc * PASO_DE_LA_DISTANCIA, ancho - 1)
			distancia[zc * ancho_corto + xc] = lejos if elevaciones[i] > mar else 0.0
	for zc in range(alto_corto):
		for xc in range(ancho_corto):
			var i := zc * ancho_corto + xc
			if xc > 0:
				distancia[i] = minf(distancia[i], distancia[i - 1] + paso_m)
			if zc > 0:
				distancia[i] = minf(distancia[i], distancia[i - ancho_corto] + paso_m)
	for zc in range(alto_corto - 1, -1, -1):
		for xc in range(ancho_corto - 1, -1, -1):
			var i := zc * ancho_corto + xc
			if xc < ancho_corto - 1:
				distancia[i] = minf(distancia[i], distancia[i + 1] + paso_m)
			if zc < alto_corto - 1:
				distancia[i] = minf(distancia[i], distancia[i + ancho_corto] + paso_m)
	return distancia
