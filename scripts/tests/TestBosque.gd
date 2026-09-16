class_name TestBosque
extends TestCase
## El claro alrededor de las bocas de cueva.
##
## Queja del usuario del 2026-09-13: «aparecen árboles justo encima de la cueva
## y sus obras». El bosque se sembraba por ruido y sólo esquivaba el agua. La
## regla —25 m sin árboles alrededor de todas las bocas del mapa— es suya.


func suite_name() -> String:
	return "Bosque"


func test_dentro_del_radio_no_se_siembra() -> void:
	var bocas := PackedVector3Array([Vector3(1000.0, 50.0, 1000.0)])
	assert_true(Forest.en_un_claro(Vector3(1015.0, 0.0, 1015.0), bocas),
		"a 21 m de la boca es claro")


func test_fuera_del_radio_si() -> void:
	var bocas := PackedVector3Array([Vector3(1000.0, 50.0, 1000.0)])
	assert_false(Forest.en_un_claro(Vector3(1030.0, 0.0, 1000.0), bocas),
		"a 30 m ya puede haber bosque")


func test_el_radio_es_de_veinticinco_metros() -> void:
	assert_near(Forest.RADIO_DEL_CLARO, 25.0, 0.001,
		"lo que pidió el usuario: por lo menos 25 m")


func test_la_altura_no_cuenta() -> void:
	# Una boca en la ladera tiene el árbol de encima a la misma distancia en
	# planta aunque esté diez metros más arriba: se mide en planta.
	var bocas := PackedVector3Array([Vector3(500.0, 80.0, 500.0)])
	assert_true(Forest.en_un_claro(Vector3(510.0, 95.0, 500.0), bocas),
		"diez metros por encima de la boca sigue siendo su claro")


func test_vale_para_todas_las_bocas() -> void:
	# De todas las del mapa, no sólo la de la banda.
	var bocas := PackedVector3Array([
		Vector3(100.0, 0.0, 100.0), Vector3(3000.0, 0.0, 2000.0)])
	assert_true(Forest.en_un_claro(Vector3(3010.0, 0.0, 2005.0), bocas),
		"la segunda boca también tiene su claro")


# --- los árboles 3D (GRAFICOS §7.1, 2026-09-15) -----------------------------------

## Cada especie del bosque tiene sus seis variantes, cada una con tres niveles de
## detalle que van a menos, a una altura razonable para su especie.
##
## Seis variantes y no tres: «que no sean todos iguales, genera variedad», petición
## del usuario al generarlos.
func test_cada_especie_tiene_sus_variantes_y_niveles_de_detalle() -> void:
	var malos: Array[String] = []
	for especie: String in ["pino", "pino_joven", "abedul", "roble", "avellano"]:
		var alturas: Array[float] = []
		for v in range(6):
			var modelo: ArbolModelo = load(ArbolModelo.ruta(especie, v))
			if modelo == null:
				malos.append("%s %d no está" % [especie, v])
				continue
			if modelo.niveles.size() != 3:
				malos.append("%s %d: %d niveles" % [especie, v, modelo.niveles.size()])
				continue
			var t0 := modelo.triangulos(0)
			var t1 := modelo.triangulos(1)
			var t2 := modelo.triangulos(2)
			if not (t0 > t1 and t1 > t2):
				malos.append("%s %d: niveles que no bajan (%d/%d/%d)" % [especie, v, t0, t1, t2])
			if modelo.alto_m < 2.0 or modelo.alto_m > 15.0:
				malos.append("%s %d: %.1f m" % [especie, v, modelo.alto_m])
			alturas.append(modelo.alto_m)
		# Y que no sean todos iguales: alguna diferencia de altura entre variantes.
		if alturas.size() == 6 and alturas.max() - alturas.min() < 0.3:
			malos.append("%s: las seis variantes miden casi lo mismo" % especie)
	assert_eq(malos.size(), 0, "árboles mal hechos: %s" % str(malos))


# --- los impostores de varias vistas (GRAFICOS §7.1) ----------------------------

## La cuenta hemi-octaédrica va y vuelve: de una dirección a su foto y de vuelta.
func test_la_vista_de_una_direccion_va_y_vuelve() -> void:
	var peor := 0.0
	var celdas_mal := 0
	for j in range(ImpostorVistas.VISTAS):
		for i in range(ImpostorVistas.VISTAS):
			var dir := ImpostorVistas.direccion_de(i, j)
			if ImpostorVistas.celda_de(dir) != Vector2i(i, j):
				celdas_mal += 1
			var vuelta := ImpostorVistas.decodificar(ImpostorVistas.codificar(dir))
			peor = maxf(peor, vuelta.distance_to(dir))
	assert_eq(celdas_mal, 0, "cada foto se elige desde su propia dirección")
	assert_lt(peor, 0.001, "la dirección vuelve igual (peor %.4f)" % peor)


## Al orbitar, el árbol lejano cambia de silueta: la foto desde un lado no es la del
## lado contrario, ni esa misma reflejada. Es el criterio de «que de lejos no se note».
func test_las_vistas_opuestas_no_son_la_misma_silueta() -> void:
	var atlas: Image = load("res://models/arboles/impostores/roble_0_color.res")
	assert_true(atlas != null, "está el atlas del roble")
	if atlas == null:
		return
	var desde_este := _silueta(atlas, ImpostorVistas.celda_de(Vector3(1.0, 0.05, 0.0)))
	var desde_oeste := _silueta(atlas, ImpostorVistas.celda_de(Vector3(-1.0, 0.05, 0.0)))
	var igual := 0
	var reflejada := 0
	var lado := ImpostorVistas.PIXELES
	for y in range(lado):
		for x in range(lado):
			if desde_este[y * lado + x] == desde_oeste[y * lado + x]:
				igual += 1
			if desde_este[y * lado + x] == desde_oeste[y * lado + (lado - 1 - x)]:
				reflejada += 1
	var total := float(lado * lado)
	assert_lt(float(igual) / total, 0.97, "no es la misma foto (%.0f %% igual)" % (100.0 * igual / total))
	assert_lt(float(reflejada) / total, 0.97,
		"ni la misma reflejada (%.0f %% igual)" % (100.0 * reflejada / total))


func _silueta(atlas: Image, celda: Vector2i) -> PackedByteArray:
	var lado := ImpostorVistas.PIXELES
	var fuera := PackedByteArray()
	fuera.resize(lado * lado)
	for y in range(lado):
		for x in range(lado):
			fuera[y * lado + x] = 1 if atlas.get_pixel(celda.x * lado + x, celda.y * lado + y).a > 0.5 else 0
	return fuera


# --- el bosque por escalones (GRAFICOS §7.1) ------------------------------------

func _bosque_de_prueba(pies: Array[Transform3D]) -> Forest:
	var bosque := Forest.new()
	bosque._stands.clear()
	for k in range(Forest.KINDS.size()):
		bosque._stands.append({})
	# Todos en el bloque (0, 0) y de la primera especie.
	bosque._stands[0][Vector2i.ZERO] = pies
	return bosque


func _pies() -> Array[Transform3D]:
	var pies: Array[Transform3D] = []
	for i in range(40):
		@warning_ignore("integer_division")
		var sitio := Vector3(1.0 + float(i % 8) * 3.5, 0.0, 1.0 + float(i / 8) * 5.5)
		pies.append(Transform3D(Basis().rotated(Vector3.UP, float(i)).scaled(Vector3.ONE * 1.1), sitio))
	return pies


## En Medio y por encima, el 3D de cerca reparte exactamente los pies de la siembra,
## en sus sitios, y cada uno en la variante que usa su impostor (`variante_de`).
##
## **Se prueba el reparto y no el MultiMesh montado**: sin ventana, el servidor de
## render de mentira no devuelve las transformaciones que se le escriben —la primera
## versión de esta prueba leía todos los pies en el origen—.
func test_el_3d_reparte_los_mismos_pies_que_la_siembra() -> void:
	var pies := _pies()
	var bosque := _bosque_de_prueba(pies)
	var por_variante := bosque.pies_por_variante(0, Vector2i.ZERO)
	var repartidos := 0
	var en_otra_variante := 0
	var fuera := 0
	for v in range(Forest.VARIANTES):
		for pie: Transform3D in por_variante[v]:
			repartidos += 1
			if Forest.variante_de(pie.origin) != v:
				en_otra_variante += 1
			if not pies.any(func(p: Transform3D) -> bool: return p == pie):
				fuera += 1
	bosque.free()
	assert_eq(repartidos, pies.size(), "tantos pies como en la siembra")
	assert_eq(fuera, 0, "los mismos, sin tocar")
	assert_eq(en_otra_variante, 0, "cada uno en la variante de su impostor")


## Y montar el bloque en 3D y los impostores no revienta, con los árboles y los atlas
## de verdad.
func test_se_montan_el_bloque_3d_y_los_impostores() -> void:
	var bosque := _bosque_de_prueba(_pies())
	bosque.escalon = 2
	assert_true(await bosque._cargar_modelos(), "se cargan los árboles 3D")
	bosque._bloque_3d(Vector2i.ZERO)
	await bosque._raise_impostors_vistas()
	var nodos_3d: int = (bosque._live[Vector2i.ZERO] as Array).size()
	var impostores := 0
	for hijo: Node in bosque.get_children():
		if hijo.name.begins_with("Vistas_"):
			impostores += 1
	bosque.free()
	assert_gt(float(nodos_3d), 0.0, "hay árboles 3D en el bloque")
	assert_gt(float(impostores), 0.0, "y teselas de impostores")


## La variante de un pie depende de su sitio y de nada más, y reparte las seis.
func test_la_variante_de_un_pie_es_fija_y_reparte() -> void:
	var vistas := {}
	var fuera_de_rango := 0
	var cambia := 0
	for i in range(300):
		var sitio := Vector3(float(i) * 3.7, 0.0, float(i * 7 % 101) * 5.3)
		var v := Forest.variante_de(sitio)
		if v < 0 or v >= Forest.VARIANTES:
			fuera_de_rango += 1
		if Forest.variante_de(sitio) != v:
			cambia += 1
		vistas[v] = true
	assert_eq(fuera_de_rango, 0, "en rango")
	assert_eq(cambia, 0, "la misma cada vez")
	assert_eq(vistas.size(), Forest.VARIANTES, "salen las seis")


## Sin huecos: el impostor sólo se esconde dentro del radio YA MONTADO. Con un bloque
## de cerca todavía en cola a 64 m, el 3D no llega más allá y el impostor se ve desde
## ahí; con la cola vacía, hasta el radio entero.
func test_el_impostor_no_se_esconde_donde_el_3d_no_esta_montado() -> void:
	var bosque := _bosque_de_prueba(_pies())
	bosque.escalon = 3
	# La distancia de Ultra, puesta a mano: desde que es un ajuste suelto no sale del escalón.
	bosque.radio_3d = 120.0
	var radio := bosque.radio_de_cerca()
	# Un bloque pendiente que empieza a 64 m de la cámara, dentro de esos 120 m.
	bosque._pending = [Vector2i(2, 0)] as Array[Vector2i]
	bosque._poner_el_ojo(Vector3(0.0, 0.0, 16.0))
	var con_cola := bosque.radio_montado
	bosque._pending.clear()
	bosque._poner_el_ojo(Vector3(0.0, 0.0, 16.0))
	var sin_cola := bosque.radio_montado
	bosque.free()
	assert_near(con_cola, 64.0, 0.01, "con un bloque pendiente a 64 m, el impostor se ve desde ahí")
	assert_near(sin_cola, radio, 0.01, "con todo montado, desde el radio del 3D")


# --- el color de cada especie (GRAFICOS §7.1) ------------------------------------------
#
# Los números los mide `ArbolColorProbe`, con ventana. Aquí va la regla que los usa: qué
# tinte toca en cada estación, y que la tabla esté entera.

func _k(modelo: String) -> int:
	for k in range(Forest.KINDS.size()):
		if String(Forest.KINDS[k]["model"]) == modelo:
			return k
	return -1


func test_la_tabla_de_color_tiene_todo_lo_que_se_pide() -> void:
	for kind: Dictionary in Forest.KINDS:
		var modelo := String(kind["model"])
		assert_true(Forest.COLOR_DE_ESPECIE.has(modelo), "%s tiene color" % modelo)
		var color: Dictionary = Forest.COLOR_DE_ESPECIE.get(modelo, {})
		var claves := ["copa", "corteza", "impostor", "minimo"]
		if bool(kind.get("caduco", false)):
			claves.append_array(["otono", "impostor_otono", "minimo_otono", "rama"])
		for clave: String in claves:
			assert_true(color.has(clave), "%s lleva %s" % [modelo, clave])


func test_en_verano_el_tinte_es_el_medido() -> void:
	for modelo: String in ["pino", "abedul"]:
		var medido: Color = Forest.COLOR_DE_ESPECIE[modelo]["copa"]
		var tinte := Forest.tinte_de(_k(modelo), Subsistence.Season.VERANO, false)
		assert_true(tinte.is_equal_approx(medido), "%s en verano: su copa medida" % modelo)


func test_el_otono_de_un_caduco_es_el_suyo_y_no_el_verano_tenido() -> void:
	var k := _k("abedul")
	var otono: Color = Forest.COLOR_DE_ESPECIE["abedul"]["otono"]
	assert_true(Forest.tinte_de(k, Subsistence.Season.OTONO, false).is_equal_approx(otono),
		"el abedul de octubre lleva su tinte de otoño")
	var minimo: Color = Forest.COLOR_DE_ESPECIE["abedul"]["minimo_otono"]
	assert_true(Forest.tinte_de(k, Subsistence.Season.OTONO, true).is_equal_approx(minimo),
		"y en Mínimo, el de otoño de Mínimo")


func test_el_invierno_de_un_caduco_no_sale_azul() -> void:
	# Se sacaba del otoño con la forma del año de CADUCO, que divide por el 0,42 de azul
	# de su otoño: ×1,9 de azul, y los robles de principios de primavera se veían azules.
	for modelo: String in ["abedul", "roble", "avellano"]:
		var k := _k(modelo)
		var otono := Forest.tinte_de(k, Subsistence.Season.OTONO, false)
		var invierno := Forest.tinte_de(k, Subsistence.Season.INVIERNO, false)
		assert_true(invierno.is_equal_approx(otono), "%s en enero: la hoja seca de otoño" % modelo)


func test_la_primavera_sigue_la_forma_del_ano_desde_el_verano() -> void:
	var k := _k("roble")
	var verano: Color = Forest.COLOR_DE_ESPECIE["roble"]["copa"]
	var forma: Color = Forest.CADUCO[Subsistence.Season.PRIMAVERA]["tinte"]
	var base: Color = Forest.CADUCO[Subsistence.Season.VERANO]["tinte"]
	var tinte := Forest.tinte_de(k, Subsistence.Season.PRIMAVERA, false)
	assert_near(tinte.g, verano.g * forma.g / base.g, 0.0001, "la hoja nueva, sobre la de verano")


func test_la_luz_del_impostor_cambia_en_otono_solo_en_los_caducos() -> void:
	var pino := _k("pino")
	var abedul := _k("abedul")
	assert_eq(Forest.luz_de(pino, Subsistence.Season.OTONO),
		Forest.COLOR_DE_ESPECIE["pino"]["impostor"], "el pino no cambia de luz")
	assert_eq(Forest.luz_de(abedul, Subsistence.Season.INVIERNO),
		Forest.COLOR_DE_ESPECIE["abedul"]["impostor_otono"], "el abedul pelado, la de otoño")
	assert_eq(Forest.luz_de(abedul, Subsistence.Season.PRIMAVERA),
		Forest.COLOR_DE_ESPECIE["abedul"]["impostor"], "y con hoja nueva, la de verano")


func test_el_brillo_de_cada_celda_es_su_luminancia_lineal_media() -> void:
	# Dos celdas por lado; una gris sRGB 0,5 y otra vacía, que no divide por cero.
	var imagen := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0, 0, 0, 0))
	imagen.fill_rect(Rect2i(0, 0, 32, 32), Color(0.5, 0.5, 0.5, 1.0))
	var brillos := Forest.brillo_de_celdas(imagen, 2)
	assert_eq(brillos.size(), 4, "una cifra por celda")
	assert_near(brillos[0], Color(0.5, 0.5, 0.5).srgb_to_linear().r, 0.01, "sRGB 0,5 es 0,21 lineal")
	assert_near(brillos[1], 1.0, 0.0001, "la celda vacía no divide: 1")


## El nodo de un bloque 3D está a la altura de sus árboles: Godot mide el rango de
## visibilidad desde ahí, y a cota cero un bloque del valle se apagaba entero antes de
## llegar al radio —el hueco que vio `ArbolAroProbe`—.
func test_el_bloque_3d_esta_a_la_altura_de_sus_arboles() -> void:
	var pies := _pies()
	for i in range(pies.size()):
		pies[i].origin.y = 300.0 + float(i % 3)
	var bosque := _bosque_de_prueba(pies)
	bosque.escalon = 1
	assert_true(await bosque._cargar_modelos(), "se cargan los árboles 3D")
	bosque._bloque_3d(Vector2i.ZERO)
	var alturas: Array[float] = []
	for nodo: Node3D in bosque._live[Vector2i.ZERO]:
		alturas.append(nodo.position.y)
	bosque.free()
	assert_gt(float(alturas.size()), 0.0, "hay nodos")
	for y: float in alturas:
		assert_between(y, 299.0, 303.0, "el nodo, a la cota de los pies y no a cero")


## Con la distancia del 3D al máximo, el plan de bloques no pasa de los que tiene el
## mapa: si no, cada cambio de bloque de la cámara recorría bloques vacíos por fuera.
func test_al_maximo_el_plan_no_se_sale_del_mapa() -> void:
	var bosque := _bosque_de_prueba(_pies())
	bosque.escalon = 3
	bosque.radio_3d = Configuracion.RADIO_3D_MAXIMO
	bosque._extension = Vector2(640.0, 320.0)
	bosque._centre = Vector2i(3, 2)
	bosque._replan()
	var fuera := 0
	for bloque: Vector2i in bosque._pending:
		if bloque.x < 0 or bloque.y < 0 or bloque.x >= 20 or bloque.y >= 10:
			fuera += 1
	var cuantos := bosque._pending.size()
	bosque.free()
	assert_eq(fuera, 0, "ningún bloque fuera del mapa")
	assert_eq(cuantos, 200, "y están todos los del mapa: 20 × 10 bloques de 32 m")


## Cambiar la distancia en caliente desmonta el 3D para volver a montarlo con la nueva,
## y no toca la siembra.
func test_la_distancia_se_cambia_en_caliente() -> void:
	var bosque := _bosque_de_prueba(_pies())
	bosque.escalon = 1
	bosque.radio_3d = 40.0
	assert_true(await bosque._cargar_modelos(), "se cargan los árboles 3D")
	bosque._bloque_3d(Vector2i.ZERO)
	var antes := Configuracion.graficos.duplicate()
	Configuracion.graficos["radio_3d"] = 150.0
	bosque.aplicar_configuracion()
	Configuracion.graficos = antes
	var radio := bosque.radio_de_cerca()
	var montados := bosque._live.size()
	var en_material := float((bosque._mat_3d[0][1] as ShaderMaterial).get_shader_parameter("radio_3d"))
	var pies := (bosque._stands[0][Vector2i.ZERO] as Array).size()
	bosque.free()
	assert_near(radio, 150.0, 0.001, "la distancia nueva")
	assert_eq(montados, 0, "el 3D de antes, desmontado para montarse con ella")
	assert_near(en_material, 150.0, 0.001, "y el corte del shader, movido")
	assert_eq(pies, 40, "la siembra, intacta")


## Un valle pequeño de ladera suave, para sembrar de verdad.
func _terreno_de_prueba() -> TerrainGenerator:
	var terreno := TerrainGenerator.new()
	terreno.meters_per_unit = 1.0
	terreno.vertical_exaggeration = 1.0
	terreno.terrain_size = Vector2i(256, 256)
	terreno.resolution = 65
	terreno.sea_level = -1000.0
	terreno._height_map.resize(65 * 65)
	terreno._humidity_map.resize(65 * 65)
	for z in range(65):
		for x in range(65):
			terreno._height_map[z * 65 + x] = float(x + z) * 0.4
			terreno._humidity_map[z * 65 + x] = 0.55
	return terreno


func _sembrar(terreno: TerrainGenerator, densidad: float) -> Forest:
	var bosque := Forest.new()
	bosque._terrain = terreno
	bosque.density = densidad
	await bosque._sow()
	return bosque


## INTERFAZ §9: volver al mismo valle no siembra, y el bosque de la vuelta es el mismo.
## Otra densidad sí siembra, y con la nueva.
func test_la_vuelta_al_valle_no_siembra_otra_vez() -> void:
	var guardada := Forest._siembra_guardada
	Forest._siembra_guardada = {}
	var terreno := _terreno_de_prueba()
	var antes := Forest.siembras
	var ida := await _sembrar(terreno, 1.0)
	var tras_la_ida := Forest.siembras
	var vuelta := await _sembrar(terreno, 1.0)
	var tras_la_vuelta := Forest.siembras
	var iguales := ida._total == vuelta._total
	for k in range(Forest.KINDS.size()):
		for bloque: Vector2i in ida._stands[k]:
			if ida._stands[k][bloque] != vuelta._stands[k].get(bloque, []):
				iguales = false
	var otra := await _sembrar(terreno, 0.5)
	var tras_otra := Forest.siembras
	var arboles := [ida._total, otra._total]
	for b: Forest in [ida, vuelta, otra]:
		b.free()
	terreno.free()
	Forest._siembra_guardada = guardada
	assert_gt(float(arboles[0]), 100.0, "el valle de prueba tiene bosque que sembrar")
	assert_eq(tras_la_ida - antes, 1, "la ida siembra")
	assert_eq(tras_la_vuelta, tras_la_ida, "la vuelta no")
	assert_true(iguales, "y son los mismos árboles en los mismos sitios")
	assert_eq(tras_otra - tras_la_vuelta, 1, "con otra densidad, se siembra")
	assert_lt(float(arboles[1]), float(arboles[0]), "y con la nueva: menos árboles")

