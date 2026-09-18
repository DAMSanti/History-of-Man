class_name RellenoDelMarDeHoy
extends RefCounted
## El mar de hoy dentro de un valle, rellenado con el suelo de la epoca.
##
## Depurar del 2026-09-17 (GRAFICOS §3). El valle de un yacimiento real es el LiDAR del IGN,
## que se acaba en la orilla de hoy: el mar sale **a cota cero exacta y plano** —medido: del
## 39 % al 58 % del recuadro en los valles 36, 47 y 49—. Con el mar de la epoca a −120 m,
## ese llano queda en seco. Y los rios de OSM se acaban en la orilla, desembocando en nada.
##
## **Nada inventado** (decision del usuario):
##
## - **La forma grande es la del fondo real**: la plataforma del mapa regional en ese
##   punto ([RelieveDeLaPlataforma.cota_en]), que es la batimetria con su relieve prestado,
##   sus rias y los valles de sus rios. El valle cuenta lo mismo que el mapa grande.
## - **El detalle fino es de tierra real, y del propio valle**: trozos de 640 m de la tierra
##   de ese mismo recuadro, sin su forma grande, cosidos ([RelievePrestado]). El usuario
##   permitia «aunque sea de otro lugar»; del mismo sitio cuadra mejor y no hay que bajar
##   nada.
## - **Cosido en la orilla**: en la orilla de hoy el relleno vale lo que valia el mar, y
##   llega a su cota en [COSIDO_M]. Ni escalon ni llano.
##
## Y **los rios siguen**: desde donde cada uno tocaba el mar de hoy, bajan por el relleno
## hasta el mar de la epoca o el borde del valle.
##
## Datos y nada mas: corre en el hilo de [PreparaValle].

## Hasta que cota cuenta como mar de hoy lo que da el LiDAR. Sale 0 exacto; una decima de
## margen para los bordes interpolados.
const COTA_DEL_MAR_DE_HOY := 0.2

## Y hasta que cota se sigue el llano de la orilla adentro: la playa, la marisma y el
## intermareal, que el LiDAR da a unos decimetros y que con el mar de la epoca tampoco
## existian.
##
## **Sale de una medida** (2026-09-17): con la mascara cortada en seco a 0,2 m, el relleno
## quedaba a −25 m **pegado a celdas que seguian a 0,4 m**, y eso dibujaba una raya de
## escalones de 26 m por todo el borde del llano —417 celdas por encima de 12 m—. La orla
## de la orilla no es tierra que defender: es el mismo llano.
const CEJA_DEL_MAR_M := 1.5

## Cuanto tarda el relleno en llegar a su cota desde la orilla de hoy, en metros.
const COSIDO_M := 250.0

## Los trozos de tierra del propio valle que se prestan: lado en muestras, paso entre ellos
## y la cota minima para contar como tierra.
const LADO_DEL_TROZO := 128
const PASO_DEL_TROZO := 64
const TIERRA_DESDE_M := 2.0

## El detalle fino: lo que se le quita de forma grande a un trozo, y el bloque del cosido.
## A 111 m, el mapa regional ya trae lo que mide mas de un par de kilometros; esto pone lo
## que cabe entre medias.
const RADIO_FINO_M := 150.0
const BLOQUE_FINO_M := 400.0

## A que resolucion se buscan los rios por el relleno: una de cada tantas muestras. A 5 m,
## cuatro son 20 m, de sobra para un cauce, y la inundacion cuesta la dieciseisava parte.
const PASO_DE_LOS_RIOS := 4

## La pendiente minima del cauce de un rio alargado, y hasta donde se abre a los lados.
##
## **Un rio no sube.** El camino sale de una inundacion por prioridad, que busca el paso
## mas bajo pero **puede cruzar collados**: medido en el contorno del sitio 36 (auditoria
## del 2026-09-17, a peticion del usuario), el Rio Cabra remontaba **181,5 m** y el Deva
## 56. Asi que el cauce se abre, como lo abre el mapa regional en la plataforma
## ([RelieveDeLaPlataforma] y sus valles): se recorre aguas abajo y se baja el terreno lo
## justo para que nunca deje de bajar.
##
## 2,5 por mil es la pendiente de un rio de llanura. **Va por metro y no por punto del
## trazado**: el contorno de un valle tiene el paso mas grande que el recuadro jugable, y
## con una bajada por punto el mismo rio salia con dos pendientes distintas.
const PENDIENTE_DEL_CAUCE := 0.0025

## Cuantas celdas a cada lado se abre el cauce, ademas del ancho del propio rio.
const RIBERA_CELDAS := 3.0

## Cuanto se busca el relleno alrededor de donde acaba un rio de OSM, en casillas de
## [PASO_DE_LOS_RIOS]: tres son 60 m a 5 m por muestra.
const RADIO_DE_LA_BOCA := 3

## La version de la receta. Va en el valle guardado: si cambia, los valles con mar de hoy se
## rehacen.
const VERSION := 4


## El sello que se guarda: esta receta Y la de la plataforma, que es de donde sale la forma
## grande del relleno. Sin ella, retocar la plataforma dejaba los valles ya rellenados con
## el relieve viejo y sin enterarse.
static func sello() -> int:
	return hash([VERSION, RelieveDeLaPlataforma.huella()])


## Deja el valle con el relleno de la epoca de `mar`, si no lo tiene ya. Devuelve si ha
## cambiado algo, y entonces hay que guardarlo.
##
## El valle guardado es uno para todas las epocas y el mar cambia de una a otra: por eso el
## relleno lleva sello ([HeightmapData.relleno_mar]) y se deshace antes de rehacerse. El
## agua sale de lo guardado; `trae_el_agua(norte, sur, oeste, este) -> Dictionary` solo se
## llama si un valle de antes de esto no la tiene, y es la unica vez que toca la red.
static func poner_al_dia(datos: HeightmapData, regional: HeightmapData, mar: float,
		rios: RiosDeLaRegion, trae_el_agua: Callable = Callable()) -> bool:
	if datos == null or datos.elevations.is_empty() or not hace_falta(datos, mar):
		return false
	var objetivo := minf(mar, 0.0)
	var cuantas := 0
	for v in datos.mar_de_hoy:
		cuantas += v
	if cuantas > 0 or datos.relleno_version == 0:
		# SE DESHACE LO DE LA EPOCA ANTERIOR: el cauce que encajo el agua, y el relleno. Lo
		# rellenado vuelve a cota cero, que es lo que daba el LiDAR.
		var cotas := datos.elevations
		for k in range(datos.cauce_celdas.size()):
			cotas[datos.cauce_celdas[k]] = datos.cauce_cotas[k]
		# La primera vez no hay mascara que deshacer: el valle esta como lo dio el LiDAR.
		if datos.mar_de_hoy.size() == cotas.size():
			for i in range(cotas.size()):
				if datos.mar_de_hoy[i] == 1:
					cotas[i] = 0.0
		datos.elevations = cotas
		# Y LA MASCARA SE SACA AQUI, con el valle deshecho: asi cambiar la receta de la
		# mascara —la ceja de la orilla, por ejemplo— vuelve a decidir de cero en vez de
		# arrastrar la de la epoca anterior.
		datos.mar_de_hoy = mar_de_hoy(datos)
		cuantas = 0
		for v in datos.mar_de_hoy:
			cuantas += v
	if cuantas > 0:
		if objetivo < 0.0 and regional != null:
			_rellenar(datos, regional, objetivo, rios)
		_rehacer_el_agua(datos, objetivo, trae_el_agua)
		_poner_los_extremos(datos)
	datos.relleno_mar = objetivo
	datos.relleno_version = sello()
	return true


## Si el valle no esta rellenado para ese mar con esta receta.
static func hace_falta(datos: HeightmapData, mar: float) -> bool:
	return datos.relleno_version != sello() or absf(datos.relleno_mar - minf(mar, 0.0)) > 0.01


## Pone el suelo de la epoca en el mar de hoy de `datos`, que ya esta a cero.
static func _rellenar(local: HeightmapData, regional: HeightmapData, mar: float,
		rios: RiosDeLaRegion) -> void:
	var mascara := local.mar_de_hoy
	var ancho := local.width
	var alto := local.height
	var metros := local.meters_per_sample
	var hasta_la_orilla := _hasta_la_orilla(mascara, ancho, alto, metros)
	var fino := _detalle_del_valle(local, mascara)
	var plataforma := RelieveDeLaPlataforma.para(regional, mar,
		rios.de_la_plataforma if rios != null else [])

	var cotas := PackedFloat32Array(local.elevations)
	var mar_de_la_epoca := PackedByteArray()
	mar_de_la_epoca.resize(cotas.size())
	for z in range(alto):
		var lat := local.lat_for_v(float(z) / float(alto - 1))
		for x in range(ancho):
			var i := z * ancho + x
			if mascara[i] == 0:
				continue
			var lon := lerpf(local.lon_west, local.lon_east, float(x) / float(ancho - 1))
			var base := plataforma.cota_en(lon, lat)
			# Lo que es mar en el mapa regional de la epoca —con sus rias— es la semilla
			# de las rias del valle.
			if base <= mar:
				mar_de_la_epoca[i] = 1
			var con_detalle := base + fino.detalle(float(x) * metros, float(z) * metros)
			var cosido := smoothstep(0.0, COSIDO_M, hasta_la_orilla[i])
			cotas[i] = lerpf(0.0, con_detalle, cosido)

	# LA MISMA REGLA QUE EL MAPA REGIONAL: la vaguada fina que llega al mar es ria, la que
	# no, valle. Ver [RelieveDeLaPlataforma.rias_y_valles]. Y solo en el relleno: la tierra
	# de hoy no se toca.
	var con_rias := RelieveDeLaPlataforma.rias_y_valles(cotas, ancho, mar_de_la_epoca, mar)
	for i in range(cotas.size()):
		if mascara[i] == 1:
			cotas[i] = con_rias[i]
	local.elevations = cotas


## Vuelve a pintar el agua de OSM, con los rios alargados si hay relleno.
static func _rehacer_el_agua(datos: HeightmapData, mar: float, trae_el_agua: Callable) -> void:
	if datos.agua_de_osm.is_empty() and trae_el_agua.is_valid():
		var traida: Variant = trae_el_agua.call(datos.lat_north, datos.lat_south,
			datos.lon_west, datos.lon_east)
		if traida is Dictionary:
			datos.agua_de_osm = traida
	var canales: Array = datos.agua_de_osm.get("channels", [])
	var laminas: Array = datos.agua_de_osm.get("bodies", [])
	if canales.is_empty() and laminas.is_empty():
		return
	if mar < 0.0:
		var antes: Array = canales
		canales = alargar_los_rios(datos, canales, datos.mar_de_hoy, mar)
		abrir_los_cauces(datos, antes, canales, mar)
	pintar_el_agua(datos, canales, laminas)


## ABRE EL CAUCE DE LO QUE SE HA ALARGADO, para que el río baje siempre.
##
## Sólo el tramo nuevo y sólo dentro del relleno: la tierra de hoy es dato y no se toca.
## `antes` y `ahora` son la misma lista de cauces, sin alargar y alargados.
static func abrir_los_cauces(datos: HeightmapData, antes: Array, ahora: Array,
		mar: float) -> void:
	var cotas := datos.elevations
	for i in range(mini(antes.size(), ahora.size())):
		var viejos: PackedVector2Array = antes[i].get("points", PackedVector2Array())
		var nuevos: PackedVector2Array = ahora[i].get("points", PackedVector2Array())
		if nuevos.size() <= viejos.size():
			continue
		# El tramo añadido va al final o al principio, según por qué punta se alargó.
		var cola := nuevos.slice(viejos.size() - 1) if _acaba_igual(viejos, nuevos) \
			else _al_reves(nuevos.slice(0, nuevos.size() - viejos.size() + 1))
		var semiancho := float(antes[i].get("half_width_m", 4.0))
		var techo := INF
		var ultimo := Vector2.INF
		# A PASO DE CELDA: excavando sólo alrededor de cada punto del trazado quedaban
		# lomos entre punto y punto —el contorno del sitio 36, a 8 m por muestra, dejaba al
		# Gandarilla remontando 19,2 m—, porque entre dos discos el terreno sólo se baja a
		# medias. Con un punto por celda, el cauce es continuo.
		for p: Vector2 in _a_paso_de_celda(datos, cola):
			var x := datos.u_for_lon(p.x) * float(datos.width - 1)
			var z := datos.v_for_lat(p.y) * float(datos.height - 1)
			# Un punto que no sea un número acaba en un índice de basura y en un cierre por
			# señal 11, sin traza de GDScript que lo delate (visto el 2026-09-17).
			if not is_finite(x) or not is_finite(z):
				continue
			if x < 0.0 or z < 0.0 or x > float(datos.width - 1) or z > float(datos.height - 1):
				continue
			var aqui := datos.sample_bilinear(x / float(datos.width - 1),
				z / float(datos.height - 1))
			var avance := 0.0
			if ultimo != Vector2.INF:
				avance = (p - ultimo).length() * 111320.0
			ultimo = p
			if techo == INF:
				techo = aqui
			techo = minf(techo, aqui) - PENDIENTE_DEL_CAUCE * avance
			# Por debajo del mar no se excava: ahí ya es mar y el cauce se acabó.
			if techo <= mar:
				break
			var radio := semiancho / maxf(datos.meters_per_sample, 0.001) + RIBERA_CELDAS
			for dz in range(-ceili(radio), ceili(radio) + 1):
				for dx in range(-ceili(radio), ceili(radio) + 1):
					var cx := clampi(roundi(x), 0, datos.width - 1) + dx
					var cz := clampi(roundi(z), 0, datos.height - 1) + dz
					if cx < 0 or cz < 0 or cx >= datos.width or cz >= datos.height:
						continue
					var j := cz * datos.width + cx
					if datos.mar_de_hoy.size() == cotas.size() and datos.mar_de_hoy[j] == 0:
						continue
					var d := sqrt(float(dx * dx + dz * dz))
					if d > radio:
						continue
					# En el eje, la cota del cauce; hacia la ribera, lo que hubiera.
					cotas[j] = minf(cotas[j], lerpf(techo, cotas[j],
						smoothstep(0.0, radio, d)))
	datos.elevations = cotas


## El mismo trazado con un punto por celda de la rejilla, para que el cauce se abra seguido.
static func _a_paso_de_celda(datos: HeightmapData, puntos: PackedVector2Array) -> PackedVector2Array:
	var fino := PackedVector2Array()
	if puntos.is_empty():
		return fino
	# Un grado de latitud son 111 320 m; el paso en grados que da una celda.
	var celda := datos.meters_per_sample / 111320.0
	fino.append(puntos[0])
	for i in range(1, puntos.size()):
		var a := puntos[i - 1]
		var b := puntos[i]
		var trozos := maxi(1, ceili((b - a).length() / maxf(celda, 0.000001)))
		for k in range(1, trozos + 1):
			fino.append(a.lerp(b, float(k) / float(trozos)))
	return fino


static func _acaba_igual(viejos: PackedVector2Array, nuevos: PackedVector2Array) -> bool:
	return viejos.size() > 0 and nuevos.size() > 0 and nuevos[0] == viejos[0]


static func _al_reves(puntos: PackedVector2Array) -> PackedVector2Array:
	var vuelta := puntos.duplicate()
	vuelta.reverse()
	return vuelta


## [Hydrography.apply], apuntando las cotas que el cauce rebaja para poder deshacerlo.
## Todo el agua de OSM de un valle entra por aqui.
static func pintar_el_agua(datos: HeightmapData, canales: Array, laminas: Array) -> void:
	var antes := PackedFloat32Array(datos.elevations)
	Hydrography.apply(datos, canales, laminas)
	var celdas := PackedInt32Array()
	var cotas := PackedFloat32Array()
	for i in range(antes.size()):
		if datos.elevations[i] != antes[i]:
			celdas.append(i)
			cotas.append(antes[i])
	datos.cauce_celdas = celdas
	datos.cauce_cotas = cotas


static func _poner_los_extremos(datos: HeightmapData) -> void:
	var lo := INF
	var hi := -INF
	for e in datos.elevations:
		lo = minf(lo, e)
		hi = maxf(hi, e)
	datos.min_elevation = lo
	datos.max_elevation = hi


## El mar de hoy del valle, y el llano de su orilla: lo que sale a cota cero unido al borde
## del recuadro, crecido por el llano de hasta [CEJA_DEL_MAR_M]. Una balsa o un embalse a
## cero tierra adentro no es mar: no toca el borde.
static func mar_de_hoy(local: HeightmapData) -> PackedByteArray:
	var ancho := local.width
	var alto := local.height
	var total := ancho * alto
	var mascara := PackedByteArray()
	mascara.resize(total)
	var cola := PackedInt32Array()
	for z in range(alto):
		for x in range(ancho):
			if x != 0 and z != 0 and x != ancho - 1 and z != alto - 1:
				continue
			var i := z * ancho + x
			if absf(local.elevations[i]) <= COTA_DEL_MAR_DE_HOY and mascara[i] == 0:
				mascara[i] = 1
				cola.append(i)
	var leido := 0
	while leido < cola.size():
		var i := cola[leido]
		leido += 1
		var x := i % ancho
		for vecino: int in [i - 1, i + 1, i - ancho, i + ancho]:
			if vecino < 0 or vecino >= total or mascara[vecino] == 1:
				continue
			if absi(vecino % ancho - x) > 1:
				continue
			# El mar de hoy se sigue por sus ceros, y la orla del llano —playa, marisma,
			# intermareal— hasta [CEJA_DEL_MAR_M].
			if local.elevations[vecino] <= CEJA_DEL_MAR_M:
				mascara[vecino] = 1
				cola.append(vecino)
	return mascara


## A cuantos metros de la tierra de hoy esta cada celda de mar. Chanfle de ida y vuelta.
static func _hasta_la_orilla(mascara: PackedByteArray, ancho: int, alto: int,
		metros: float) -> PackedFloat32Array:
	var lejos := 1.0e9
	var d := PackedFloat32Array()
	d.resize(mascara.size())
	for i in range(mascara.size()):
		d[i] = lejos if mascara[i] == 1 else 0.0
	var recto := metros
	var diagonal := metros * 1.4142
	for z in range(alto):
		for x in range(ancho):
			var i := z * ancho + x
			if x > 0:
				d[i] = minf(d[i], d[i - 1] + recto)
			if z > 0:
				d[i] = minf(d[i], d[i - ancho] + recto)
				if x > 0:
					d[i] = minf(d[i], d[i - ancho - 1] + diagonal)
				if x < ancho - 1:
					d[i] = minf(d[i], d[i - ancho + 1] + diagonal)
	for z in range(alto - 1, -1, -1):
		for x in range(ancho - 1, -1, -1):
			var i := z * ancho + x
			if x < ancho - 1:
				d[i] = minf(d[i], d[i + 1] + recto)
			if z < alto - 1:
				d[i] = minf(d[i], d[i + ancho] + recto)
				if x < ancho - 1:
					d[i] = minf(d[i], d[i + ancho + 1] + diagonal)
				if x > 0:
					d[i] = minf(d[i], d[i + ancho - 1] + diagonal)
	return d


## El detalle fino prestado de la tierra real del propio valle.
static func _detalle_del_valle(local: HeightmapData, mascara: PackedByteArray) -> RelievePrestado:
	var prestado := RelievePrestado.new()
	prestado.radio_m = RADIO_FINO_M
	prestado.bloque_m = BLOQUE_FINO_M
	prestado.semilla = 20260917 + local.width
	var ancho := local.width
	for z0 in range(0, local.height - LADO_DEL_TROZO, PASO_DEL_TROZO):
		for x0 in range(0, ancho - LADO_DEL_TROZO, PASO_DEL_TROZO):
			var trozo := PackedFloat32Array()
			trozo.resize(LADO_DEL_TROZO * LADO_DEL_TROZO)
			var entero := true
			for z in range(LADO_DEL_TROZO):
				for x in range(LADO_DEL_TROZO):
					var i := (z0 + z) * ancho + (x0 + x)
					var e := local.elevations[i]
					if mascara[i] == 1 or e <= TIERRA_DESDE_M:
						entero = false
						break
					trozo[z * LADO_DEL_TROZO + x] = e
				if not entero:
					break
			if entero:
				prestado.sumar_trozo(trozo, LADO_DEL_TROZO, LADO_DEL_TROZO,
					local.meters_per_sample)
	# Un recuadro casi todo mar puede no tener una sola ventana entera de tierra: entonces
	# se presta de la sábana de tierra real, que es el mismo trato pero de otro valle.
	if prestado._trozos.is_empty():
		return RelievePrestado.de_la_tierra()
	return prestado


# --- los rios que siguen ----------------------------------------------------------

## Los cauces de OSM que tocaban el mar de hoy, alargados por el relleno hasta el mar de la
## epoca o el borde. Devuelve la lista entera de cauces, con los alargados.
##
## El rio **baja por el relieve nuevo** (decision del usuario): se inunda el relleno desde
## su salida —el mar de la epoca o el borde del recuadro— y se sigue de vuelta, como los
## rios de la plataforma ([RioDeLaPlataforma]). Por eso puede no coincidir con el trazado
## del mapa regional, y es a sabiendas.
static func alargar_los_rios(local: HeightmapData, canales: Array, mascara: PackedByteArray,
		mar: float) -> Array:
	if canales.is_empty() or mascara.is_empty():
		return canales
	var paso := PASO_DE_LOS_RIOS
	var ancho := local.width
	var alto := local.height
	var ancho_c := int(ceil(float(ancho) / float(paso)))
	var alto_c := int(ceil(float(alto) / float(paso)))
	var total := ancho_c * alto_c
	# La rejilla gruesa: la cota de cada casilla, y si es relleno.
	var cota := PackedFloat32Array()
	cota.resize(total)
	var relleno := PackedByteArray()
	relleno.resize(total)
	for zc in range(alto_c):
		for xc in range(ancho_c):
			var i := mini(zc * paso, alto - 1) * ancho + mini(xc * paso, ancho - 1)
			cota[zc * ancho_c + xc] = local.elevations[i]
			relleno[zc * ancho_c + xc] = mascara[i]

	# Salidas: el mar de la epoca dentro del relleno, y el borde del relleno.
	var padres := PackedInt32Array()
	padres.resize(total)
	padres.fill(-2)
	var cola := RioDeLaPlataforma._Cola.new()
	for zc in range(alto_c):
		for xc in range(ancho_c):
			var i := zc * ancho_c + xc
			if relleno[i] == 0:
				continue
			var borde := xc == 0 or zc == 0 or xc == ancho_c - 1 or zc == alto_c - 1
			if cota[i] <= mar or borde:
				padres[i] = -1
				cola.meter(i, cota[i])
	while not cola.vacia():
		var i := cola.sacar()
		var x := i % ancho_c
		@warning_ignore("integer_division")
		var z := i / ancho_c
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx := x + dx
				var nz := z + dz
				if nx < 0 or nz < 0 or nx >= ancho_c or nz >= alto_c:
					continue
				var vecina := nz * ancho_c + nx
				if padres[vecina] != -2 or relleno[vecina] == 0:
					continue
				padres[vecina] = i
				cola.meter(vecina, cota[vecina])

	# LOS AFLUENTES SE UNEN AL COLECTOR, no corren en paralelo hasta el mar. El camino de
	# vuelta se para en cuanto pisa una casilla por la que ya baja otro cauce alargado: eso
	# es una confluencia, y es lo que hace el agua.
	#
	# **Sale de una auditoría** (2026-09-17, a petición del usuario: «comprueba que los
	# ríos sean fieles a la realidad»): sin esto, el «Caño de la Portilla» —un caño de
	# marisma de tres metros— bajaba **12,7 km** él solo por el contorno del sitio 36, y el
	# Gandarilla salía **dos veces por el mismo sitio**, una por cada tramo que OSM parte.
	#
	# Y de mayor a menor, para que el colector sea el río y no el arroyo que llegó antes.
	var orden: Array = []
	for i in range(canales.size()):
		orden.append(i)
	orden.sort_custom(func(a: int, b: int) -> bool:
		return _caudal(canales[a]) > _caudal(canales[b]))
	var ocupada := PackedByteArray()
	ocupada.resize(total)
	var salida: Array = []
	salida.resize(canales.size())
	for i: int in orden:
		salida[i] = _alargar(local, canales[i], padres, relleno, ancho_c, alto_c, paso,
			ocupada)
	return salida


## Con qué mandar a un cauce sobre otro en una confluencia: su anchura, y a igualdad, lo
## largo que venga. Un río se lleva al arroyo, no al revés.
static func _caudal(canal: Dictionary) -> float:
	var puntos: PackedVector2Array = canal.get("points", PackedVector2Array())
	return float(canal.get("half_width_m", 2.0)) * 1000.0 + float(puntos.size())


## Un cauce, alargado por su punta que toca el relleno, si alguna lo toca.
static func _alargar(local: HeightmapData, canal: Dictionary, padres: PackedInt32Array,
		relleno: PackedByteArray, ancho_c: int, alto_c: int, paso: int,
		ocupada: PackedByteArray) -> Dictionary:
	var puntos: PackedVector2Array = canal.get("points", PackedVector2Array())
	if puntos.size() < 2:
		return canal
	for punta: int in [puntos.size() - 1, 0]:
		var p := puntos[punta]
		var celda := _boca(_casilla_de(local, p, ancho_c, alto_c, paso), relleno, padres,
			ancho_c, alto_c)
		if celda < 0:
			continue
		var camino := PackedVector2Array()
		var pasos := 0
		var desde := celda
		while celda >= 0 and pasos < 10000:
			var xc := celda % ancho_c
			@warning_ignore("integer_division")
			var zc := celda / ancho_c
			camino.append(Vector2(
				lerpf(local.lon_west, local.lon_east,
					float(mini(xc * paso, local.width - 1)) / float(local.width - 1)),
				local.lat_for_v(float(mini(zc * paso, local.height - 1)) / float(local.height - 1))))
			# Si ya baja agua por aquí, este cauce desemboca en ella: se para en la
			# confluencia. El primer paso no cuenta, que es su propia boca.
			if celda != desde and ocupada[celda] == 1:
				break
			ocupada[celda] = 1
			celda = padres[celda]
			pasos += 1
		if camino.size() < 2:
			continue
		camino = RioDeLaPlataforma.suavizar(camino, 2)
		var nuevo := canal.duplicate()
		var todos := PackedVector2Array()
		if punta == puntos.size() - 1:
			todos.append_array(puntos)
			todos.append_array(camino.slice(1))
		else:
			var al_reves := camino.duplicate()
			al_reves.reverse()
			todos.append_array(al_reves.slice(0, al_reves.size() - 1))
			todos.append_array(puntos)
		nuevo["points"] = todos
		# El ancho del tramo nuevo es el de la punta de la que sale: el rio no crece por
		# cruzar el relleno.
		var anchos: PackedFloat32Array = canal.get("half_widths_m", PackedFloat32Array())
		if anchos.size() == puntos.size():
			var nuevos := PackedFloat32Array()
			var del_extremo := anchos[punta]
			if punta == puntos.size() - 1:
				nuevos.append_array(anchos)
				for k in range(camino.size() - 1):
					nuevos.append(del_extremo)
			else:
				for k in range(camino.size() - 1):
					nuevos.append(del_extremo)
				nuevos.append_array(anchos)
			nuevo["half_widths_m"] = nuevos
		return nuevo
	return canal


## La casilla de relleno mas cercana a donde acaba un cauce, a [RADIO_DE_LA_BOCA] casillas
## como mucho, o -1. OSM y el LiDAR no dibujan la orilla en el mismo sitio: el ultimo
## punto de un rio cae a veces un par de celdas tierra adentro de donde el MDT da cero.
static func _boca(celda: int, relleno: PackedByteArray, padres: PackedInt32Array,
		ancho_c: int, alto_c: int) -> int:
	if celda < 0:
		return -1
	var cx := celda % ancho_c
	@warning_ignore("integer_division")
	var cz := celda / ancho_c
	var mejor := -1
	var mejor_d := INF
	for dz in range(-RADIO_DE_LA_BOCA, RADIO_DE_LA_BOCA + 1):
		for dx in range(-RADIO_DE_LA_BOCA, RADIO_DE_LA_BOCA + 1):
			var x := cx + dx
			var z := cz + dz
			if x < 0 or z < 0 or x >= ancho_c or z >= alto_c:
				continue
			var i := z * ancho_c + x
			if relleno[i] == 0 or padres[i] == -2:
				continue
			var d := float(dx * dx + dz * dz)
			if d < mejor_d:
				mejor_d = d
				mejor = i
	return mejor


static func _casilla_de(local: HeightmapData, p: Vector2, ancho_c: int, alto_c: int,
		paso: int) -> int:
	var u := local.u_for_lon(p.x)
	var v := local.v_for_lat(p.y)
	if u < -0.001 or u > 1.001 or v < -0.001 or v > 1.001:
		return -1
	var xc := clampi(roundi(clampf(u, 0.0, 1.0) * float(local.width - 1) / float(paso)), 0, ancho_c - 1)
	var zc := clampi(roundi(clampf(v, 0.0, 1.0) * float(local.height - 1) / float(paso)), 0, alto_c - 1)
	return zc * ancho_c + xc
