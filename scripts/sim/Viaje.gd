class_name Viaje
extends RefCounted
## Un grupo de camino entre dos campamentos: SISTEMAS §23, tareas 7 a 9.
##
## Mientras viaja, **no está en ningún campamento**: sale de la lista de gente del
## de origen al irse y entra en la del de destino al llegar. Por el camino no hay
## monte que simular —está fuera de los dos mapas—, así que el viaje avanza por
## jornadas de la partida y no por pasos: cada jornada puede haber un percance, y
## el día que toca, llega.
##
## Tres decisiones del usuario del 2026-09-14 lo gobiernan: las jornadas salen
## **del andar de siempre** sobre el relieve regional —[camino]—; el riesgo es **el
## de una jornada de expedición** con el terreno del tramo —[nueva_jornada]—; y
## **se llega herido, no se muere**.

## Cada cuánto se mira el relieve a lo largo del camino, en metros. Un vértice del
## relieve regional son unos 110 m; a 250 se ve cada ladera sin medir cada bache.
## Decisión, no medida.
const TRAMO_M := 250.0

## Metros por hora en llano y de vacío, los de la partida por defecto:
## `SettlementSim.walk_speed` (900) por las horas de juego de un segundo
## (`seconds_per_day / 24`, 5). Es lo mismo que cuenta `Marcha.hours_to_walk`;
## [salir] pasa los de su simulación, y esto sólo vale para preguntar sin ella.
const METROS_POR_HORA_EN_LLANO := 900.0 * 120.0 / 24.0

## Metros por grado de latitud. La longitud se encoge con el coseno.
const METROS_POR_GRADO := 111320.0

var personas: Array[Inhabitant] = []
var desde_id: int = -1
var hasta_id: int = -1
var hasta_nombre: String = ""
var sale_el_dia: int = 0
var llega_el_dia: int = 0
var jornadas: int = 0
var raciones: float = 0.0

## El terreno más arriesgado de cada jornada de camino (`Traversal.Ground`).
var suelo_por_jornada: Array[int] = []

## Lo que les ha pasado por el camino, contado. Se lee al llegar.
var percances: Array[String] = []

## El azar del camino. Sembrado con la semilla de la partida del campamento de
## origen, el día de salida y el grupo: un viaje con la misma partida da los
## mismos percances (SPECS §3.3), y no pide tiradas al `_rng` de ningún
## campamento, que cambiaría su partida por viajes que no son suyos.
var _rng := RandomNumberGenerator.new()

## Por qué no ha salido el último viaje que se intentó. Lo lee la ficha.
static var ultimo_motivo: String = ""

## El relieve de la comarca, cargado la primera vez que se pregunta.
static var _relieve: HeightmapData = null


## Cuánto se tarda de un sitio a otro, andando.
##
## Se recorre la recta sobre el relieve regional y se suma, tramo a tramo, el
## tiempo con la misma cuenta que cuesta andar un metro en el valle
## (`Traversal.pace_fraction`, con su suelo y su carga). Las jornadas son esas
## horas entre las horas útiles de una jornada. **Decisión del usuario**: el andar
## de siempre, sin una cifra de kilómetros inventada.
##
## Devuelve `metros`, `horas`, `jornadas` y `terreno` (el suelo más arriesgado de
## cada jornada).
static func camino(desde: Site, hasta: Site, carga: float,
		metros_por_hora: float = METROS_POR_HORA_EN_LLANO) -> Dictionary:
	var coseno := cos(deg_to_rad((desde.lat + hasta.lat) * 0.5))
	var dx := (hasta.lon - desde.lon) * METROS_POR_GRADO * coseno
	var dz := (hasta.lat - desde.lat) * METROS_POR_GRADO
	var metros := sqrt(dx * dx + dz * dz)
	var tramos := maxi(int(ceil(metros / TRAMO_M)), 1)
	var largo := metros / float(tramos)

	var horas := 0.0
	var terreno_del_dia: Array[int] = []
	var cota_antes := cota(desde.lat, desde.lon)
	for i in range(1, tramos + 1):
		var t := float(i) / float(tramos)
		var otra := cota(lerpf(desde.lat, hasta.lat, t), lerpf(desde.lon, hasta.lon, t))
		var tramo := andar_un_tramo(cota_antes, otra, largo, carga, metros_por_hora)
		cota_antes = otra
		var suelo: int = tramo["suelo"]
		horas += float(tramo["horas"])
		var dia := int(floor(horas / SettlementSim.HORAS_UTILES))
		while terreno_del_dia.size() <= dia:
			terreno_del_dia.append(Traversal.Ground.PASTO)
		if Mishap.chance(suelo, 0.0, 0.0) > Mishap.chance(
				terreno_del_dia[dia] as Traversal.Ground, 0.0, 0.0):
			terreno_del_dia[dia] = suelo

	var cuantas := maxi(int(ceil(horas / SettlementSim.HORAS_UTILES)), 1)
	terreno_del_dia.resize(cuantas)
	return {"metros": metros, "horas": horas, "jornadas": cuantas, "terreno": terreno_del_dia}


## La cota del relieve regional en un punto. La lee también [Pasillo].
static func cota(lat: float, lon: float) -> float:
	if _relieve == null:
		_relieve = load("res://data/dem/cantabria_region.res") as HeightmapData
	return _relieve.sample_bilinear(_relieve.u_for_lon(lon), _relieve.v_for_lat(lat))


## Lo que cuesta andar un tramo de `largo` metros entre dos cotas: `horas` y el
## `suelo`. **Una sola cuenta** para el viaje entre campamentos y el pasillo de una
## expedición (SISTEMAS §4, decisión del usuario: el andar de siempre).
static func andar_un_tramo(cota_desde: float, cota_hasta: float, largo: float,
		carga: float, metros_por_hora: float) -> Dictionary:
	var pendiente := (cota_hasta - cota_desde) / maxf(largo, 0.001)
	var suelo := Traversal.classify_ground(absf(pendiente), 0.0, 0.0)
	var paso := Traversal.pace_fraction(pendiente, suelo, carga)
	return {"horas": largo / maxf(metros_por_hora * paso, 0.001), "suelo": suelo}


## Lo que costaría mandar a este grupo: `jornadas`, `raciones`, `metros` y, si no
## puede salir, `motivo`. **Es la misma cuenta que cobra [salir]**: la ficha la
## enseña antes de confirmar y tiene que ser la que luego se cobra.
static func lo_que_cuesta(origen: SettlementSim, grupo: Array, desde: Site,
		hasta: Site) -> Dictionary:
	var fuera := {"jornadas": 0, "raciones": 0.0, "metros": 0.0, "motivo": ""}
	if grupo.is_empty():
		fuera["motivo"] = "no va nadie"
		return fuera
	if desde == null or hasta == null:
		fuera["motivo"] = "no hay adónde"
		return fuera
	if desde.id == hasta.id:
		fuera["motivo"] = "ya están ahí"
		return fuera
	if origen.traslado.en_marcha():
		fuera["motivo"] = "la banda se está mudando de cueva"
		return fuera
	for persona: Inhabitant in grupo:
		if not origen.people.has(persona):
			fuera["motivo"] = "%s no está en este campamento" % persona.given_name
			return fuera
		if persona.esta_de_expedicion(origen.day):
			fuera["motivo"] = "%s está de expedición" % persona.given_name
			return fuera
		if persona.hurt_days > 0:
			fuera["motivo"] = "%s está herido" % persona.given_name
			return fuera

	var metros_por_hora := origen.walk_speed * origen.seconds_per_day / 24.0
	var ruta := camino(desde, hasta, _fraccion_de_carga(origen, grupo), metros_por_hora)
	var comen := 0.0
	for persona: Inhabitant in grupo:
		comen += persona.daily_food()
	fuera["jornadas"] = int(ruta["jornadas"])
	fuera["metros"] = float(ruta["metros"])
	fuera["raciones"] = comen * float(ruta["jornadas"])
	if origen.store.food_rations() < float(fuera["raciones"]):
		fuera["motivo"] = "faltan raciones para el camino: hacen falta %.0f y hay %.0f" \
			% [float(fuera["raciones"]), origen.store.food_rations()]
	return fuera


## Qué parte de lo que pueden cargar llevarán, con lo que hay en el almacén.
static func _fraccion_de_carga(origen: SettlementSim, grupo: Array) -> float:
	var capacidad := 0.0
	for persona: Inhabitant in grupo:
		capacidad += persona.carry_limit_kg()
	var hay := 0.0
	for kind: int in Materia.Kind.values():
		hay += origen.store.amount(kind as Materia.Kind) * Materia.kg_per_unit(kind as Materia.Kind)
	return clampf(hay / maxf(capacidad, 0.001), 0.0, 1.0)


## Manda al grupo. Cobra las raciones del camino al campamento de origen, les
## carga lo que cabe —la regla del traslado, [Traslado.cosas_en_orden_de_carga]—
## y los saca de su gente. Null si no puede salir, con el porqué en
## [ultimo_motivo].
static func salir(origen: SettlementSim, grupo: Array, desde: Site, hasta: Site,
		dia: int) -> Viaje:
	var cuesta := lo_que_cuesta(origen, grupo, desde, hasta)
	ultimo_motivo = String(cuesta["motivo"])
	if not ultimo_motivo.is_empty():
		return null

	var viaje := Viaje.new()
	viaje.desde_id = desde.id
	viaje.hasta_id = hasta.id
	viaje.hasta_nombre = hasta.display_name()
	viaje.sale_el_dia = dia
	viaje.jornadas = int(cuesta["jornadas"])
	viaje.llega_el_dia = dia + viaje.jornadas
	viaje.raciones = float(cuesta["raciones"])
	var metros_por_hora := origen.walk_speed * origen.seconds_per_day / 24.0
	var ruta := camino(desde, hasta, _fraccion_de_carga(origen, grupo), metros_por_hora)
	for suelo: int in (ruta["terreno"] as Array):
		viaje.suelo_por_jornada.append(suelo)
	var ids: Array[int] = []
	for persona: Inhabitant in grupo:
		viaje.personas.append(persona)
		ids.append(persona.id)
	viaje._rng.seed = hash([origen.game_seed, dia, hasta.id, ids])

	origen.despensa.sacar_raciones(viaje.raciones)
	_cargar(origen, viaje.personas)
	for persona: Inhabitant in viaje.personas:
		origen.despedir(persona)
	origen._note(Chronicle.Kind.GENTE,
		"Salen %d hacia %s: %d jornadas de camino y %.0f raciones de la despensa."
			% [viaje.personas.size(), viaje.hasta_nombre, viaje.jornadas, viaje.raciones], 2)
	if origen.people.is_empty():
		origen._note(Chronicle.Kind.GENTE,
			"No queda nadie. El campamento se queda como está, por si alguien vuelve.", 2)
	return viaje


## Lo que cabe en la espalda de cada cual, por orden: primero la comida que más
## alimenta por kilo, luego lo que más vale. La misma regla que el traslado.
static func _cargar(origen: SettlementSim, grupo: Array[Inhabitant]) -> void:
	for kind: int in Traslado.cosas_en_orden_de_carga(origen.store):
		var material := kind as Materia.Kind
		var por_unidad := maxf(Materia.kg_per_unit(material), 0.001)
		for persona: Inhabitant in grupo:
			var hay := origen.store.amount(material)
			if hay <= 0.0:
				break
			var cabe := floorf(maxf(persona.carry_limit_kg() - persona.load_kg(), 0.0) / por_unidad)
			var lleva := minf(hay, cabe)
			if lleva <= 0.0:
				continue
			origen.store.take(material, lleva)
			persona.add_load(material, lleva)


## Una jornada de camino. La llama el registro de campamentos al cerrarse cada
## jornada de la partida.
##
## Cada cual se cura un día de lo que traiga, y puede tener un percance con **la
## misma cuenta que una jornada de expedición** (`Mishap.chance`) sobre el suelo
## más arriesgado del tramo de hoy. Lo que hiere, hiere; **no mata** —decisión del
## usuario—, y lo que no hiere no cuenta en el camino.
func nueva_jornada(dia: int) -> void:
	if dia <= sale_el_dia or dia > llega_el_dia:
		return
	var indice := clampi(dia - sale_el_dia - 1, 0, maxi(suelo_por_jornada.size() - 1, 0))
	var suelo := suelo_por_jornada[indice] as Traversal.Ground if not suelo_por_jornada.is_empty() \
		else Traversal.Ground.PASTO
	for persona: Inhabitant in personas:
		if persona.hurt_days > 0:
			persona.hurt_days -= 1
		if _rng.randf() >= Mishap.chance(suelo, persona.fatigue, 0.0):
			continue
		var que := Mishap.roll(_rng, suelo)
		var dias := Mishap.hurt_days(que)
		if dias <= 0:
			continue
		persona.hurt_days = maxi(persona.hurt_days, dias)
		percances.append(Mishap.tell(que, persona.given_name, "por el camino"))


func ha_llegado(dia: int) -> bool:
	return dia >= llega_el_dia


## Entran en la gente del campamento de destino, con lo que traen.
func llegar_a(destino: SettlementSim) -> void:
	for persona: Inhabitant in personas:
		destino.recibir(persona)
	destino.apply_priorities()
	var texto := "Llegan %d tras %d jornadas de camino." % [personas.size(), jornadas]
	if not percances.is_empty():
		texto += " " + " ".join(percances)
	destino._note(Chronicle.Kind.GENTE, texto, 2)


# --- guardar -----------------------------------------------------------------

## Lo que se guarda de un viaje, o vacío si su gente no se puede recorrer.
## SISTEMAS §23, tarea 12.
##
## **La gente va en una instantánea de una simulación de paso**: [Instantanea]
## recorre simulaciones, y un grupo de camino no está en ninguna. Así una persona
## se guarda por el mismo recorrido que en un campamento, con todo lo que lleva,
## y no por una lista de campos que se quedaría atrás al añadir uno.
func a_datos() -> Dictionary:
	var portador := SettlementSim.new()
	portador.people.assign(personas)
	var foto := Instantanea.tomar(portador)
	portador.free()
	if not foto.errores.is_empty():
		return {}
	# La fecha es de la partida, no del grupo: la guarda la cabecera.
	foto.estaticas = {}
	return {
		"gente": foto.bytes(),
		"desde": desde_id,
		"hasta": hasta_id,
		"hasta_nombre": hasta_nombre,
		"sale": sale_el_dia,
		"llega": llega_el_dia,
		"jornadas": jornadas,
		"raciones": raciones,
		"suelo": suelo_por_jornada.duplicate(),
		"percances": percances.duplicate(),
		"azar": [_rng.seed, _rng.state],
	}


## Un viaje guardado, o null si no se puede leer.
static func de_datos(datos: Dictionary) -> Viaje:
	var foto := Instantanea.desde_bytes(datos.get("gente", PackedByteArray()))
	if foto == null:
		return null
	var portador := SettlementSim.new()
	var errores := foto.volcar(portador)
	var viaje := Viaje.new()
	viaje.personas.assign(portador.people)
	portador.free()
	if not errores.is_empty():
		return null
	viaje.desde_id = int(datos.get("desde", -1))
	viaje.hasta_id = int(datos.get("hasta", -1))
	viaje.hasta_nombre = String(datos.get("hasta_nombre", ""))
	viaje.sale_el_dia = int(datos.get("sale", 0))
	viaje.llega_el_dia = int(datos.get("llega", 0))
	viaje.jornadas = int(datos.get("jornadas", 0))
	viaje.raciones = float(datos.get("raciones", 0.0))
	viaje.suelo_por_jornada.assign(datos.get("suelo", []))
	viaje.percances.assign(datos.get("percances", []))
	var azar: Array = datos.get("azar", [0, 0])
	# La semilla primero: fijarla reinicia el estado.
	viaje._rng.seed = int(azar[0])
	viaje._rng.state = int(azar[1])
	return viaje

