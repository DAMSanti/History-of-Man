class_name Expedicion
extends RefCounted
## La salida larga: se sale del mapa hacia un rumbo, se tarda jornadas y se vuelve
## sabiendo más — o no se vuelve sabiendo nada, pero las jornadas se han ido igual.
##
## Es la capa regional de docs/SISTEMAS.md §4. **Desde el 2026-09-14 va hacia un
## rumbo y no a un sitio** («Spec: explorar hacia un rumbo»): el jugador elige
## hacia dónde, quién y cuántas jornadas, se recorre un [Pasillo] durante la
## mitad de ellas y al volver se descubre lo que había a la vista. Hasta ese día
## salía una vez al año, con la tarjeta de primavera, al sitio sin descubrir más
## cercano, y descubría ese sitio y sus cuatro vecinos.
##
## ## Lo que cuesta, que es la mitad del frente
##
## Salir del abrigo no se vuelve el mismo día: quien va **no trabaja** mientras
## está fuera y **come de la despensa** antes de irse. Y una expedición que
## vuelve sin nada cuesta exactamente lo mismo, porque el coste es haber salido,
## no haber acertado.

var sim: SettlementSim


func _init(settlement: SettlementSim) -> void:
	sim = settlement


## Las jornadas que la ficha propone de entrada: las doce que duraba siempre antes
## de poderse elegir. Doce es un cuarto de estación: se nota en la contabilidad
## del oficio y caben dos o tres al año. Las que se pueden elegir, en [Pasillo].
const JORNADAS_PROPUESTAS := 12

## Los ocho rumbos hacia los que se sale, en grados desde el norte.
##
## **Ocho y no cualquier ángulo** (decisión del usuario del 2026-09-15, SISTEMAS §4):
## con el rumbo libre se pinchaba al azar y muchos pasillos no llevaban a ningún
## sitio. Y de los ocho, sólo se ofrecen los que tienen algo: [rumbos_posibles].
const RUMBOS: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]

## Los yacimientos entre los que se busca: la comarca horneada si nadie pone otra.
## Las pruebas ponen su catálogo a mano. Ver [_la_comarca].
var comarca: SiteSet = null

## Cuánta gente hace falta para que salga una expedición.
##
## Tres: sola no se sale —el criterio del vivac ya dice que dormir fuera es
## peligroso— y más de tres deja la banda corta en casa. Decisión.
const MINIMO_PARA_SALIR := 3


## Quiénes están fuera ahora mismo, por id.
var fuera: Array[int] = []

## Hacia dónde se fue —grados desde el norte—, cuántas jornadas, y qué jornada
## vuelven.
var rumbo: float = 0.0
var jornadas: int = 0
var vuelve_el_dia: int = -1

## El pasillo que recorren, trazado al salir ([Pasillo.a_datos]). Se traza al
## salir y no al volver: es el que enseñó la flecha, y lo que se descubre es lo
## que se prometió.
var pasillo: Dictionary = {}

## Si se ha mandado alguna vez. Es una de las tres condiciones que cierran la
## primera fase — ver [Partida].
var mandada_alguna_vez := false

## Cuántas expediciones han vuelto, y cuántos emplazamientos han descubierto
## entre todas. Lo mira la sonda.
var vueltas := 0
var descubiertos := 0

## Las jornadas-persona que se han ido en expediciones. Es la cifra que el
## frente pide contar: esas jornadas **no se recolectan**.
var jornadas_persona := 0


## Si hay una expedición fuera ahora mismo.
func en_marcha() -> bool:
	return not fuera.is_empty()


## Lo que hay que meter en el zurrón para mandar a `cuantos` fuera `dias` jornadas.
##
## **Las mismas constantes del vivac que usa la cumbre**, no una copia: una piel
## de tienda por persona —que vuelve, ver [SettlementSim.VIVAC_PIEL]— y una de
## leña por persona y noche, más la noche de margen; y dos raciones por persona y
## jornada. Con tres personas y doce jornadas: 72 raciones, 3 pieles y 39 de leña.
func hace_falta_para(cuantos: int, dias: int = JORNADAS_PROPUESTAS) -> Dictionary:
	var noches := float(dias) + SettlementSim.VIVAC_MARGEN_NOCHES
	return {
		"raciones": float(cuantos * dias) * 2.0,
		"piel": float(cuantos) * SettlementSim.VIVAC_PIEL,
		"lena": float(cuantos) * SettlementSim.VIVAC_LENA * noches,
	}


## Qué falta en el abrigo para que puedan salir, dicho como se diría. Vacío si
## no falta nada. Es lo que la ficha enseña cuando no se puede mandar.
func lo_que_falta(cuantos: int, dias: int = JORNADAS_PROPUESTAS) -> Array[String]:
	var hace_falta := hace_falta_para(cuantos, dias)
	var falta: Array[String] = []
	if sim.store.food_rations() < float(hace_falta["raciones"]):
		falta.append("%.0f raciones" % float(hace_falta["raciones"]))
	if sim.store.amount(Materia.Kind.PIEL_CURTIDA) < float(hace_falta["piel"]):
		falta.append("%.0f pieles curtidas para las tiendas" % float(hace_falta["piel"]))
	if sim.store.amount(Materia.Kind.LENA) < float(hace_falta["lena"]):
		falta.append("%.0f de leña" % float(hace_falta["lena"]))
	return falta


## Por qué no puede salir **la expedición más corta** —[MINIMO_PARA_SALIR] personas y
## [Pasillo.JORNADAS_MINIMAS]—, dicho como se diría; vacío si puede. Es lo que apaga el
## botón «Rumbo» del valle y lo que dice su ayuda (SISTEMAS §4, spec del 2026-09-15:
## «se sabe antes de pulsar»). No mira los rumbos: ésos se eligen en la ficha.
func por_que_no_sale() -> String:
	var pueden := 0
	for person: Inhabitant in sim.people:
		if puede_ir(person):
			pueden += 1
	# El coste, el de TRES aunque puedan ir más: con el de todos los que pueden, una
	# banda de ocho pedía ocho pieles para poder pulsar (`RumboProbe`, 2026-09-16).
	return motivo_para(mini(pueden, MINIMO_PARA_SALIR), Pasillo.JORNADAS_MINIMAS)


## Por qué no saldrían `pueden` personas que pueden ir durante `dias`, o vacío. Una
## sola lista de motivos para el botón y para la ficha ([FichaDeRumbo.bloqueo]).
##
## **Con una expedición fuera, tampoco** (decisión del 2026-09-16, aceptada por el
## usuario): [mandar_a] no deja, y un botón encendido que no manda es lo que motivó la
## spec.
func motivo_para(pueden: int, dias: int) -> String:
	if en_marcha():
		return "ya hay una expedición fuera"
	if pueden < MINIMO_PARA_SALIR:
		return "hacen falta %d adultos que puedan ir" % MINIMO_PARA_SALIR
	var falta := lo_que_falta(pueden, dias)
	if not falta.is_empty():
		return "falta " + ", ".join(falta)
	return ""


## Las pieles que se llevaron puestas de tienda, para devolverlas al volver.
var pieles_prestadas := 0.0

## Por dónde se sale del valle: la celda del borde del mapa hacia el rumbo.
##
## Se guarda para volver por el mismo sitio, que es lo que hace que la vuelta se
## lea como una vuelta y no como una aparición.
var salida: Vector3 = Vector3.ZERO

## A cuánto del borde se da por salido del valle.
const LLEGADA := 24.0


## El sitio desde el que sale: el del campamento, y si la simulación no lo sabe
## —una prueba, una escena montada a mano—, el de la banda.
func origen() -> Site:
	return sim.sitio if sim.sitio != null else GameState.home


## El pasillo que recorrería una salida hacia `hacia` durante `dias` jornadas, o
## null si no se sabe desde dónde se sale. **Es el que enseña la flecha** y el que
## se descubre al volver: ver [Pasillo].
func pasillo_hacia(hacia: float, dias: int) -> Pasillo:
	var desde := origen()
	if desde == null:
		return null
	# El andar de esta simulación, el mismo que cuenta `Marcha.hours_to_walk`.
	var metros_por_hora := sim.walk_speed * sim.seconds_per_day / 24.0
	return Pasillo.trazar(desde.lon, desde.lat, hacia, dias, metros_por_hora,
		GameState.sea_level_m)


## La puerta del valle hacia un rumbo: la celda del borde del mapa **alcanzable**
## que menos se desvía de él.
##
## Alcanzable y no la que caiga: nadie da un paso sin camino debajo —SPECS
## §4.3—, y el borde del mapa es tan de piedra y agua como el resto. Si por el
## rumbo no se llega al borde, se sale por la celda alcanzable que más se le
## acerque, que es lo que haría cualquiera.
func puerta_del_valle(hacia: float) -> Vector3:
	if sim._terrain == null:
		return sim.home_position
	var lado := float(sim._terrain.terrain_size.x)
	var fondo := float(sim._terrain.terrain_size.y)
	# El rumbo, pasado al mapa local: el este es +x y el norte es −z.
	var direccion := Vector3(sin(deg_to_rad(hacia)), 0.0, -cos(deg_to_rad(hacia)))
	var mejor := sim.home_position
	var mejor_lejos := INF
	# Un punto por cada tramo del borde, y el que menos se desvíe del rumbo.
	var pasos := 48
	for i in range(pasos):
		for borde in range(4):
			var t := float(i) / float(pasos - 1)
			var punto := Vector3(t * lado, 0.0, 1.0)
			match borde:
				1: punto = Vector3(lado - 1.0, 0.0, t * fondo)
				2: punto = Vector3(t * lado, 0.0, fondo - 1.0)
				3: punto = Vector3(1.0, 0.0, t * fondo)
			punto.y = sim._terrain.get_height_at(punto)
			if not sim.marcha.alcanzable_desde_casa(punto):
				continue
			var hacia_alla := (punto - sim.home_position)
			hacia_alla.y = 0.0
			if hacia_alla.length() < 1.0:
				continue
			# Cuánto se desvía del rumbo: 0 es justo en esa dirección.
			var desvio := 1.0 - hacia_alla.normalized().dot(direccion)
			if desvio < mejor_lejos:
				mejor_lejos = desvio
				mejor = punto
	return mejor


## Una tajada de tiempo de quien va andando hacia el borde. Lo llama
## [SettlementSim], que a los que ya están fuera no los simula.
func andar(person: Inhabitant, index: int, hours: float, delta: float) -> void:
	if not person.expedicion_andando:
		return
	var falta := Vector2(person.position.x - salida.x,
		person.position.z - salida.z).length()
	if falta <= LLEGADA:
		# Ya está fuera del valle: deja de andar y de verse.
		person.expedicion_andando = false
		sim._sacar_del_mapa(person, index)
		return
	# VA DESPEJANDO EL MAPA POR DONDE PASA, como cualquiera que anda: la
	# expedición cruza el valle entero hasta el borde y sería raro que ese
	# camino siguiera en niebla. Es la misma ojeada de
	# [SettlementSim._learn_from] —idempotente, no barre celdas dos veces desde
	# el mismo sitio— y no un segundo sistema de descubrir. Pedido por el
	# usuario el 2026-09-13.
	#
	# Va ANTES del paso y no después: la marcha puede dejarle en otro estado
	# —sin rumbo, esperando— y entonces la ojeada no se haría.
	sim._learn_from(person, delta)
	sim.marcha._tick_step(person, index, hours, delta)
	sim._pintar_a(person, index)


## Si `grados` es uno de los ocho [RUMBOS].
static func es_un_rumbo(grados: float) -> bool:
	return RUMBOS.has(fposmod(grados, 360.0))


## Si hacia `hacia` hay algo que descubrir: **un yacimiento sin descubrir dentro del
## pasillo de la expedición más larga posible**, la de [Pasillo.JORNADAS_MAXIMAS]
## (decisión del usuario). Un avistado está sin descubrir, así que cuenta. Los sitios
## son los mismos que descubre la vuelta ([_sitios_del_pasillo]): una sola regla.
func se_ofrece(hacia: float) -> bool:
	if not es_un_rumbo(hacia):
		return false
	var recorrido := pasillo_hacia(hacia, Pasillo.JORNADAS_MAXIMAS)
	if recorrido == null:
		return false
	for site: Site in _sitios_del_pasillo(recorrido):
		if not sim.descubierto(site):
			return true
	return false


## Los rumbos que se ofrecen desde el campamento, en el orden de [RUMBOS]. Vacío si
## no queda nada al alcance.
func rumbos_posibles() -> Array[float]:
	var posibles: Array[float] = []
	for hacia: float in RUMBOS:
		if se_ofrece(hacia):
			posibles.append(hacia)
	return posibles


## Manda a los primeros `cuantos` que puedan ir. Lo usan las pruebas y las sondas;
## el jugador elige a quién en la ficha, con [mandar_a].
func mandar(cuantos: int, hacia: float, dias: int = JORNADAS_PROPUESTAS) -> bool:
	var quienes: Array[int] = []
	for person: Inhabitant in sim.people:
		if quienes.size() >= cuantos:
			break
		if puede_ir(person):
			quienes.append(person.id)
	if quienes.size() < cuantos:
		return false
	return mandar_a(quienes, hacia, dias)


## Manda a los elegidos hacia un rumbo. Devuelve si han salido.
##
## No sale si ya hay una fuera, si son menos del mínimo, si las jornadas no son
## de las que se pueden elegir o si la despensa no da para avituallarla: salir sin
## comida es mandar a tres personas a morirse, no una decisión difícil. **No
## depende de la estación**: se sale cuando se quiere.
##
## Comprueba que cada uno siga pudiendo ir: entre que se marca en la ficha y se
## confirma pueden pasar cosas.
##
## **Y sólo hacia uno de los ocho rumbos que se ofrecen** ([se_ofrece]): no queda
## forma de dar un rumbo libre, ni desde la ficha ni desde fuera de ella.
func mandar_a(quienes: Array[int], hacia: float, dias: int = JORNADAS_PROPUESTAS) -> bool:
	if en_marcha() or quienes.size() < MINIMO_PARA_SALIR:
		return false
	if not Pasillo.jornadas_validas(dias):
		return false
	if not se_ofrece(hacia):
		return false
	var pueden: Array[int] = []
	for person: Inhabitant in sim.people:
		if quienes.has(person.id) and puede_ir(person):
			pueden.append(person.id)
	if pueden.size() < MINIMO_PARA_SALIR:
		return false
	# EL AVITUALLAMIENTO VA PRIMERO, y si no hay, no se sale. Se mira TODO antes
	# de sacar nada: `sacar_raciones` se lleva lo que haya aunque no llegue, y una
	# expedición que no sale no se come la despensa.
	var falta := lo_que_falta(pueden.size(), dias)
	if not falta.is_empty():
		sim._note(Chronicle.Kind.PENURIA,
			"No hay con qué avituallar una expedición —falta %s—: se queda en casa."
				% ", ".join(falta), 0)
		return false
	var hace_falta := hace_falta_para(pueden.size(), dias)
	sim.despensa.sacar_raciones(float(hace_falta["raciones"]))
	# La leña arde fuera; la piel es la tienda y vuelve con quien la llevó.
	sim.store.take(Materia.Kind.LENA, float(hace_falta["lena"]))
	pieles_prestadas = sim.store.take(Materia.Kind.PIEL_CURTIDA, float(hace_falta["piel"]))

	fuera.clear()
	for person: Inhabitant in sim.people:
		if pueden.has(person.id):
			person.expedicion_hasta = sim.day + dias
			fuera.append(person.id)
	rumbo = fposmod(hacia, 360.0)
	jornadas = dias
	vuelve_el_dia = sim.day + dias
	var recorrido := pasillo_hacia(rumbo, dias)
	pasillo = recorrido.a_datos() if recorrido != null else {}
	mandada_alguna_vez = true
	jornadas_persona += pueden.size() * dias
	_echar_a_andar()

	sim._note(Chronicle.Kind.HALLAZGO,
		"Salen %d hacia el %s a ver qué hay más allá del valle. No vuelven en %d jornadas."
			% [pueden.size(), nombre_del_rumbo(rumbo), dias], 2)
	return true


## El rumbo dicho como se diría: norte, nordeste, este…
static func nombre_del_rumbo(grados: float) -> String:
	const NOMBRES := ["norte", "nordeste", "este", "sudeste", "sur", "sudoeste",
		"oeste", "noroeste"]
	return NOMBRES[int(round(fposmod(grados, 360.0) / 45.0)) % 8]


## Los pone a andar hacia el borde del valle. Se les ve irse.
func _echar_a_andar() -> void:
	salida = puerta_del_valle(rumbo)
	for person: Inhabitant in sim.people:
		if not fuera.has(person.id):
			continue
		person.expedicion_andando = true
		person.state = Inhabitant.State.YENDO
		if sim.marcha != null:
			sim.marcha._send_to(person, salida)


## Un día de expedición. Lo llama [SettlementSim] al cerrar la jornada.
func nuevo_dia() -> void:
	if not en_marcha():
		return
	if sim.day < vuelve_el_dia:
		return
	_volver()


## Si esta persona puede salir de expedición: un adulto en casa y sin tocar.
##
## Ni niños ni ancianos: jornadas fuera del valle, durmiendo al raso por sitios
## que nadie conoce, son para adultos. Es una decisión de diseño. **Una pregunta,
## un sitio**: lo usan la ficha, la salida a dedo y la comprobación de la vuelta.
func puede_ir(person: Inhabitant) -> bool:
	if person.esta_de_expedicion(sim.day):
		return false
	if person.age_group != Inhabitant.Age.ADULTO:
		return false
	# Ni tocados: quien está con un percance se queda en el abrigo, y jornadas
	# fuera es lo contrario de descansar. Frente 12.
	return not person.esta_tocado()


## Vuelven, y con lo que hayan visto.
func _volver() -> void:
	for person: Inhabitant in sim.people:
		if fuera.has(person.id):
			person.expedicion_hasta = -1
			person.expedicion_andando = false
			# VUELVEN POR DONDE SALIERON, y desde ahí andan solos: el reparto
			# de la mañana les da tajo y la marcha los trae. Hasta el
			# 2026-09-13 aparecían de golpe en el abrigo, que es la mitad del
			# viaje sin contar. Ver [salida].
			person.position = salida if salida != Vector3.ZERO else sim.home_position
			person.target = person.position
			person.route = PackedVector3Array()
			person.route_step = 0
			person.state = Inhabitant.State.VOLVIENDO
	fuera.clear()
	vueltas += 1
	# LAS PIELES VUELVEN. Una tienda no se gasta: se lleva y se trae, igual que
	# en la acampada de la cumbre. Ver [SettlementSim.VIVAC_PIEL].
	if pieles_prestadas > 0.0:
		sim.store.add(Materia.Kind.PIEL_CURTIDA, pieles_prestadas)
		pieles_prestadas = 0.0

	var conocida := false
	var nuevos := 0
	if not pasillo.is_empty():
		var recorrido := Pasillo.de_datos(pasillo)
		var dentro := _sitios_del_pasillo(recorrido)
		for site: Site in dentro:
			if not sim.descubierto(site):
				nuevos += 1
		# LO QUE SE VE SE DESCUBRE, y lo pisado queda recorrido: las dos capas de
		# la niebla, y los sitios de dentro con la vista. Al volver —decisión del
		# usuario—: lo visto llega con quien vuelve. Por la barrera si la
		# simulación la lleva el reloj. Ver [SettlementSim.levantar_niebla].
		# `"descubre"` sólo aquí: es la ÚNICA forma de descubrir un sitio
		# (decisión del usuario, 2026-09-14). Ver [GameState.levantar_niebla].
		sim.levantar_niebla({"forma": "pasillo", "pasillo": pasillo,
			"capa": NieblaRegional.VISTA, "descubre": true})
		sim.levantar_niebla({"forma": "pasillo", "pasillo": pasillo,
			"capa": NieblaRegional.RECORRIDA})

		# EL CONTACTO, que es el propósito de todo esto: la expedición no busca
		# terreno, busca gente con la que tratar.
		#
		# LA PRIMERA EXPEDICIÓN SIEMPRE ENCUENTRA GENTE, decidido por el usuario el
		# 2026-09-13: con uno de cada cinco sitios ocupados, dos años de partida
		# acabaron sin conocer a nadie (ESTADO §2). Con rumbo no hay destino, y la
		# gente se pone **en el sitio del pasillo más lejano** del campamento, el
		# más cerca de donde se da la vuelta —decisión del usuario del 2026-09-14—.
		# Sin sitios en el pasillo, no hay a quién encontrar.
		if vueltas == 1 and sim.contacto != null and not dentro.is_empty():
			sim.contacto.poblar(_el_mas_lejano(dentro, recorrido).id)
		if sim.contacto != null:
			for site: Site in dentro:
				if sim.contacto.hay_gente_en(site.id) and sim.contacto.conocerse(site.id):
					conocida = true
	descubiertos += nuevos

	if conocida:
		sim._note(Chronicle.Kind.HALLAZGO,
			"La expedición vuelve con algo que no se esperaba: allí vive otra "
				+ "gente. Se puede tratar con ellos.", 3)
	elif nuevos > 0:
		sim._note(Chronicle.Kind.HALLAZGO,
			("Vuelve la expedición: %d sitios nuevos que antes no estaban en "
				+ "la cabeza de nadie.") % nuevos, 2)
	else:
		# Y ÉSTE ES EL CASO QUE EL CRITERIO EXIGE QUE CUESTE IGUAL.
		sim._note(Chronicle.Kind.PENURIA,
			"Vuelve la expedición sin nada que contar. Las jornadas se han "
				+ "ido igual.", 1)
	vuelve_el_dia = -1
	pasillo = {}


## Los sitios de la comarca cuyo punto cae dentro del pasillo, sin el propio.
func _sitios_del_pasillo(recorrido: Pasillo) -> Array[Site]:
	var dentro: Array[Site] = []
	var desde := origen()
	for site: Site in _la_comarca().sites:
		if desde != null and site.id == desde.id:
			continue
		if recorrido.contiene(site.lon, site.lat):
			dentro.append(site)
	return dentro


func _la_comarca() -> SiteSet:
	if comarca == null:
		comarca = SiteSet.comarca()
	return comarca


static func _el_mas_lejano(sitios: Array[Site], recorrido: Pasillo) -> Site:
	var mejor: Site = sitios[0]
	var mas := -1.0
	var coseno := cos(deg_to_rad(recorrido.lat))
	for site: Site in sitios:
		var x := (site.lon - recorrido.lon) * coseno
		var z := site.lat - recorrido.lat
		var lejos := x * x + z * z
		if lejos > mas:
			mas = lejos
			mejor = site
	return mejor
