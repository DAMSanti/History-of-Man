class_name ValleDeLaPlataforma
extends RefCounted
## El valle de un abrigo de la costa de la época, inventado.
##
## EPOCA_01 §10.2. Un sitio de la plataforma no tiene relieve que descargar: el MDT del
## IGN se acaba en la costa de hoy y lo que hay debajo del mar es batimetría a 111 m. Así
## que el recuadro jugable **se inventa**, y siempre igual:
##
## 1. **la cota de la plataforma** ([RelieveDeLaPlataforma]), que es la misma que se ve en
##    el mapa regional, con sus lomas y el valle de su río;
## 2. **el detalle fino** que a 111 m no existe, con la semilla del sitio;
## 3. **el cantil del abrigo**, que es lo que hace que haya abrigo;
## 4. **el río de la época**, el mismo que el del mapa ([RiosDeLaRegion]), pintado con
##    [Hydrography] como en cualquier valle.
##
## El mar no se pinta aquí: sale solo, porque el valle guarda cotas por debajo del mar de
## la época y el terreno lo dibuja (ver `DemoMain`, `sea_level`).

## Sube si cambia la receta. Va en `source` del recuadro guardado, y [PreparaValle] rehace
## los valles inventados que no la traigan: subirla NO obliga a redescargar los valles
## reales, que no salen de aquí.
##
## **2** (2026-09-17): el detalle fino es relieve real prestado y no ruido.
const VERSION := 2

## Cuánto detalle fino se le pone al relieve. La batimetría a 111 m no tiene nada más fino
## que una loma; esto son las vaguadas y los lomos que se ven al andar.
##
## **Es relieve real prestado, no ruido** (depurar del 2026-09-17, GRAFICOS §3): trozos de
## tierra del IGN a 5 m cosidos ([RelievePrestado.de_la_tierra]). Hasta entonces era un
## FastNoiseLite de 7 m de amplitud y 140 m de onda, elegido mirando el valle del Nansa;
## el usuario pidió que la orografía no se inventara, y el préstamo viene de ese mismo
## valle. Aquí sólo queda cuánto se escala lo prestado: 1 es tal cual.
const DETALLE := 1.0

## El cantil del abrigo: cuánto levanta y en cuántos metros.
##
## Un abrigo es una pared con un hueco: sin resalte no hay dónde meterse. Se levanta
## **hacia tierra adentro**, así que el abrigo mira al mar.
const CANTIL_M := 22.0
const CANTIL_ANCHO_M := 70.0

## Hasta dónde llega el cantil a cada lado del abrigo, en metros.
const CANTIL_LARGO_M := 320.0

## LA RASA: cuánto se aplana el relieve junto a la línea del agua, y en qué banda de
## cotas alrededor de ella.
##
## El mar plancha su orilla: donde rompe el oleaje queda una plataforma casi horizontal
## —la rasa mareal, que en la costa cantábrica se ve en todas partes— y por eso hay
## marisco. Sin ella la orilla de la plataforma bajaba de golpe, el agua era honda a dos
## metros de tierra y **no nacía un solo paraje de marisqueo**: no se llegaba andando
## (`CostaProbe`, 2026-09-16).
const RASA_M := 8.0
const RASA_APLANA := 0.30

## LA BAJADA A LA PLAYA: lo ancha que es y hasta dónde llega pasada la orilla.
##
## El abrigo está sobre un resalte y la costa de la plataforma cae a plomo: medido en el
## valle del Nansa, **40 m de caída en 40 m** justo en la línea del agua, así que a la
## orilla no se bajaba y no había marisqueo (`CostaProbe`, 2026-09-16). Esta es la playa
## que pide la spec: una rampa andable del abrigo al agua.
const RAMPA_ANCHA_M := 110.0
const RAMPA_PASADA_LA_ORILLA_M := 140.0


## El recuadro jugable del sitio, inventado. `lado_m` es su lado y `metros` lo que mide
## una muestra.
## Con qué receta se levantó un valle inventado: va en su `source` y [PreparaValle] lo
## mira para rehacer los que sean de otra.
static func firma() -> String:
	return "ValleDeLaPlataforma v%d" % VERSION


static func generar(sitio: Site, rios: RiosDeLaRegion, regional: HeightmapData,
		mar: float, lado_m: float, metros: float) -> HeightmapData:
	if regional == null:
		return null
	var plataforma := RelieveDeLaPlataforma.para(regional, mar, rios.de_la_plataforma)
	var muestras := maxi(int(lado_m / metros), 16)
	var medio_lat := lado_m * 0.5 * IGNImporter.DEG_PER_METER_LAT
	var medio_lon := lado_m * 0.5 * IGNImporter.deg_per_meter_lon(sitio.lat)

	var datos := HeightmapData.new()
	datos.width = muestras
	datos.height = muestras
	datos.meters_per_sample = metros
	datos.lat_north = sitio.lat + medio_lat
	datos.lat_south = sitio.lat - medio_lat
	datos.lon_west = sitio.lon - medio_lon
	datos.lon_east = sitio.lon + medio_lon
	datos.geographic_rows = true
	datos.source = firma()

	# EL DETALLE FINO ES TIERRA REAL PRESTADA. Cada sitio lo lee de un rincón distinto de
	# la sábana —su id lo desplaza— para que dos abrigos no salgan calcados.
	var detalle := RelievePrestado.de_la_tierra()
	var corrimiento := Vector2(float((sitio.id * 977) % 2048), float((sitio.id * 1597) % 2048))

	# Hacia dónde cae el terreno en el abrigo: el cantil se levanta al revés, tierra
	# adentro, para que el abrigo mire al mar.
	var hacia_el_mar := _hacia_el_mar(plataforma, sitio, metros * 8.0)
	# Dónde está el agua en esa dirección: hasta ahí baja la rampa.
	var hasta_el_agua := _hasta_el_agua(plataforma, sitio, hacia_el_mar, mar, metros)
	var cotas := PackedFloat32Array()
	cotas.resize(muestras * muestras)
	var mas_baja := INF
	var mas_alta := -INF
	for z in range(muestras):
		var lat := lerpf(datos.lat_north, datos.lat_south, float(z) / float(muestras - 1))
		for x in range(muestras):
			var lon := lerpf(datos.lon_west, datos.lon_east, float(x) / float(muestras - 1))
			var cota := plataforma.cota_en(lon, lat)
			cota += detalle.detalle(corrimiento.x + float(x) * metros,
				corrimiento.y + float(z) * metros) * DETALLE
			cota += _cantil(sitio, hacia_el_mar, lon, lat)
			cota = _rampa(sitio, hacia_el_mar, hasta_el_agua, mar, lon, lat, cota)
			cota = _rasa(cota, mar)
			cotas[z * muestras + x] = cota
			mas_baja = minf(mas_baja, cota)
			mas_alta = maxf(mas_alta, cota)
	datos.elevations = cotas
	datos.min_elevation = mas_baja
	datos.max_elevation = mas_alta

	# EL RÍO, EL MISMO QUE EL DEL MAPA: se recortan los cauces que pasan por el recuadro
	# y se pintan como en cualquier valle, con su ancho por punto.
	var dentro := _cauces_dentro(rios.para_el_mar(mar), datos)
	if not dentro.is_empty():
		Hydrography.apply(datos, dentro, [])
	return datos


## Cuánto hay del abrigo al agua en la dirección del mar, en metros.
static func _hasta_el_agua(plataforma: RelieveDeLaPlataforma, sitio: Site,
		hacia_el_mar: Vector2, mar: float, paso_m: float) -> float:
	var por_metro_lon := 1.0 / (111320.0 * cos(deg_to_rad(sitio.lat)))
	var por_metro_lat := 1.0 / 111320.0
	var andado := paso_m
	while andado < 2500.0:
		var lon := sitio.lon + hacia_el_mar.x * andado * por_metro_lon
		var lat := sitio.lat + hacia_el_mar.y * andado * por_metro_lat
		if plataforma.cota_en(lon, lat) <= mar:
			return andado
		andado += paso_m * 2.0
	return 0.0


## La bajada del abrigo a la playa: ver [RAMPA_ANCHA_M].
##
## Dentro del pasillo que va del abrigo al agua, el terreno se lleva hacia una cuesta
## constante; fuera, se queda como estaba. Así hay por dónde bajar a mariscar sin tocar
## el resto del valle.
static func _rampa(sitio: Site, hacia_el_mar: Vector2, hasta_el_agua: float, mar: float,
		lon: float, lat: float, cota: float) -> float:
	if hasta_el_agua <= 0.0:
		return cota
	var del_sitio := Vector2(
		(lon - sitio.lon) * 111320.0 * cos(deg_to_rad(sitio.lat)),
		(lat - sitio.lat) * 111320.0)
	var de_frente := del_sitio.dot(hacia_el_mar)
	if de_frente < 0.0 or de_frente > hasta_el_agua + RAMPA_PASADA_LA_ORILLA_M:
		return cota
	var de_lado := absf(del_sitio.dot(Vector2(-hacia_el_mar.y, hacia_el_mar.x)))
	var peso := 1.0 - smoothstep(RAMPA_ANCHA_M * 0.35, RAMPA_ANCHA_M * 0.5, de_lado)
	if peso <= 0.0:
		return cota
	var t := clampf(de_frente / hasta_el_agua, 0.0, 1.5)
	var cuesta := lerpf(sitio.elevation, mar - 2.0, minf(t, 1.0))
	if t > 1.0:
		# Pasada la orilla sigue bajando, suave, para que haya somero donde mariscar.
		cuesta = mar - 2.0 - (t - 1.0) * hasta_el_agua * 0.02
	# HACIA la cuesta, no al mínimo: el problema no era un hoyo sino que la costa cae a
	# plomo, así que la rampa tiene que RELLENAR el acantilado por donde se baja
	# (`CostaProbe`, 2026-09-16).
	return lerpf(cota, cuesta, peso)
static func _rasa(cota: float, mar: float) -> float:
	var sobre := cota - mar
	if absf(sobre) >= RASA_M:
		return cota
	# Cuanto más cerca de la línea del agua, más plano: así la franja que se pisa es
	# ancha y hay dónde mariscar.
	var cerca := 1.0 - absf(sobre) / RASA_M
	return mar + sobre * lerpf(1.0, RASA_APLANA, cerca)


## Cuánto levanta el cantil en este punto.
##
## Es un escalón recto que pasa por el abrigo, mirando al mar: delante (hacia el mar) no
## levanta nada, detrás levanta [CANTIL_M], y el paso de una cosa a otra son
## [CANTIL_ANCHO_M]. Se apaga a los lados para no partir el valle en dos.
static func _cantil(sitio: Site, hacia_el_mar: Vector2, lon: float, lat: float) -> float:
	var del_sitio := Vector2(
		(lon - sitio.lon) * 111320.0 * cos(deg_to_rad(sitio.lat)),
		(lat - sitio.lat) * 111320.0)
	var de_frente := del_sitio.dot(hacia_el_mar)
	var de_lado := absf(del_sitio.dot(Vector2(-hacia_el_mar.y, hacia_el_mar.x)))
	var subida := smoothstep(0.0, CANTIL_ANCHO_M, -de_frente) * CANTIL_M
	return subida * (1.0 - smoothstep(CANTIL_LARGO_M * 0.6, CANTIL_LARGO_M, de_lado))


## Hacia dónde está el mar desde el abrigo, en el plano.
static func _hacia_el_mar(plataforma: RelieveDeLaPlataforma, sitio: Site,
		paso_m: float) -> Vector2:
	var por_lon := paso_m / (111320.0 * cos(deg_to_rad(sitio.lat)))
	var por_lat := paso_m / 111320.0
	var este := plataforma.cota_en(sitio.lon + por_lon, sitio.lat)
	var oeste := plataforma.cota_en(sitio.lon - por_lon, sitio.lat)
	var norte := plataforma.cota_en(sitio.lon, sitio.lat + por_lat)
	var sur := plataforma.cota_en(sitio.lon, sitio.lat - por_lat)
	var cuesta := Vector2(este - oeste, norte - sur)
	if cuesta.length() < 0.001:
		# Sin cuesta, el mar está al norte: es la costa cantábrica.
		return Vector2(0.0, 1.0)
	# El mar es hacia donde BAJA.
	return -cuesta.normalized()


## Los cauces que tocan el recuadro, recortados con un poco de margen.
static func _cauces_dentro(cauces: Array, datos: HeightmapData) -> Array:
	var margen_lon := (datos.lon_east - datos.lon_west) * 0.15
	var margen_lat := (datos.lat_north - datos.lat_south) * 0.15
	var fuera: Array = []
	for cauce: Dictionary in cauces:
		var puntos: PackedVector2Array = cauce["points"]
		var anchos: PackedFloat32Array = cauce.get("half_widths_m", PackedFloat32Array())
		var trozo := PackedVector2Array()
		var trozo_anchos := PackedFloat32Array()
		for k in range(puntos.size()):
			var p := puntos[k]
			var cerca := p.x > datos.lon_west - margen_lon and p.x < datos.lon_east + margen_lon \
				and p.y > datos.lat_south - margen_lat and p.y < datos.lat_north + margen_lat
			if cerca:
				trozo.append(p)
				if anchos.size() == puntos.size():
					trozo_anchos.append(anchos[k])
			elif trozo.size() >= 2:
				fuera.append(_un_cauce(cauce, trozo, trozo_anchos))
				trozo = PackedVector2Array()
				trozo_anchos = PackedFloat32Array()
			else:
				trozo = PackedVector2Array()
				trozo_anchos = PackedFloat32Array()
		if trozo.size() >= 2:
			fuera.append(_un_cauce(cauce, trozo, trozo_anchos))
	return fuera


static func _un_cauce(original: Dictionary, puntos: PackedVector2Array,
		anchos: PackedFloat32Array) -> Dictionary:
	var cauce := {
		"points": puntos,
		"half_width_m": float(original.get("half_width_m", 11.0)),
		"kind": String(original.get("kind", "river")),
		"name": String(original.get("name", "")),
		"closed": false,
	}
	if anchos.size() == puntos.size():
		cauce["half_widths_m"] = anchos
	return cauce
