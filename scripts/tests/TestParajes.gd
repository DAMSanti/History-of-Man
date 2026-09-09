class_name TestParajes
extends TestCase
## Pruebas de los parajes con nombre.
##
## Lo que hay que asegurar es que el nombre sea ESTABLE -el mismo sitio se
## llama siempre igual- y que solo haya un tajo elegido por actividad: la
## cuadrilla va junta o no va.


func suite_name() -> String:
	return "Parajes"


func _paraje(x: int, z: int, kind: Materia.Kind = Materia.Kind.FRUTO_SECO,
		activity: Subsistence.Activity = Subsistence.Activity.RECOLECCION) -> Paraje:
	return Paraje.create(x, z, activity, kind,
		Vector3(float(x) * 64.0, 0.0, float(z) * 64.0), 1)


func test_el_nombre_sale_de_la_celda_y_no_cambia() -> void:
	# Si el nombre fuera al azar, el mismo avellanar se llamaria distinto cada
	# partida y el jugador no podria acordarse de nada
	var first := Paraje.build_name(12, 34, Materia.Kind.FRUTO_SECO)
	var again := Paraje.build_name(12, 34, Materia.Kind.FRUTO_SECO)
	assert_eq(first, again, "la misma celda da el mismo nombre")
	assert_true(first.begins_with("El avellanar"), "y dice lo que da")


func test_dos_celdas_vecinas_no_se_llaman_igual() -> void:
	var here := Paraje.build_name(12, 34, Materia.Kind.FRUTO_SECO)
	var there := Paraje.build_name(13, 34, Materia.Kind.FRUTO_SECO)
	assert_true(here != there, "dos avellanares vecinos se distinguen")


func test_cada_material_tiene_su_palabra() -> void:
	# Un cantizal y un avellanar no se parecen en nada y no pueden compartir
	# nombre: es la mitad del valor de bautizarlos
	var nuts := Paraje.build_name(5, 5, Materia.Kind.FRUTO_SECO)
	var stone := Paraje.build_name(5, 5, Materia.Kind.PIEDRA)
	assert_true(nuts.begins_with("El avellanar"), "avellanar")
	assert_true(stone.begins_with("El cantizal"), "cantizal")


func test_no_se_apunta_dos_veces_el_mismo() -> void:
	var registro := Parajes.new()
	assert_true(registro.add(_paraje(3, 4)), "el primero entra")
	assert_false(registro.add(_paraje(3, 4)), "el mismo, no")
	assert_eq(registro.list.size(), 1, "y solo hay uno apuntado")


func test_la_misma_celda_con_otra_actividad_es_otro_paraje() -> void:
	# Un remanso de pesca y un cantizal pueden caer en la misma celda: son
	# sitios distintos aunque compartan coordenada
	var registro := Parajes.new()
	registro.add(_paraje(3, 4, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION))
	assert_true(registro.add(_paraje(3, 4, Materia.Kind.PESCADO,
		Subsistence.Activity.PESCA)), "el de pesca es otro")
	assert_eq(registro.list.size(), 2, "dos parajes en la misma celda")


# --- la eleccion del jugador ----------------------------------------------

func test_solo_hay_un_tajo_elegido_por_actividad() -> void:
	var registro := Parajes.new()
	var first := _paraje(1, 1)
	var second := _paraje(2, 2)
	registro.add(first)
	registro.add(second)

	registro.choose(first)
	assert_true(first.chosen, "el primero elegido")

	registro.choose(second)
	assert_false(first.chosen, "elegir otro desmarca el anterior")
	assert_true(second.chosen, "y queda el nuevo")


func test_elegir_uno_no_toca_las_demas_actividades() -> void:
	var registro := Parajes.new()
	var gathering := _paraje(1, 1, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	var fishing := _paraje(2, 2, Materia.Kind.PESCADO,
		Subsistence.Activity.PESCA)
	registro.add(gathering)
	registro.add(fishing)

	registro.choose(gathering)
	registro.choose(fishing)
	assert_true(gathering.chosen, "el de recoleccion sigue elegido")
	assert_true(fishing.chosen, "y el de pesca tambien")


func test_elegir_un_paraje_lo_saca_del_descanso() -> void:
	# Mandar gente a un sitio en barbecho es una orden explicita: manda el
	# jugador, no la regla
	var registro := Parajes.new()
	var paraje := _paraje(1, 1)
	registro.add(paraje)
	paraje.resting = true

	registro.choose(paraje)
	assert_false(paraje.resting, "deja de estar en descanso")


func test_se_puede_quitar_la_eleccion() -> void:
	var registro := Parajes.new()
	var paraje := _paraje(1, 1)
	registro.add(paraje)
	registro.choose(paraje)

	registro.clear_choice(Subsistence.Activity.RECOLECCION)
	assert_eq(registro.chosen_for(Subsistence.Activity.RECOLECCION), null,
		"la banda vuelve a decidir sola")


func test_se_listan_del_mas_cercano_al_mas_lejano() -> void:
	# El orden importa: lo primero que se lee tiene que ser lo que esta a mano
	var registro := Parajes.new()
	registro.add(_paraje(10, 0))
	registro.add(_paraje(2, 0))
	registro.add(_paraje(6, 0))

	var near := registro.of(Subsistence.Activity.RECOLECCION, Vector3.ZERO)
	assert_eq(near.size(), 3, "los tres")
	assert_eq(near[0].cell_x, 2, "primero el mas cercano")
	assert_eq(near[2].cell_x, 10, "y ultimo el mas lejos")


func test_dos_parajes_no_comparten_nombre() -> void:
	# Con quince palabras de lugar los choques son inevitables, y dos sitios
	# con el mismo nombre no se pueden distinguir: es lo contrario de para lo
	# que sirve bautizarlos
	var registro := Parajes.new()
	var seen := {}
	for i in range(40):
		var paraje := _paraje(i, i * 3)
		registro.add(paraje)
		assert_false(seen.has(paraje.name_text),
			"«%s» ya estaba cogido" % paraje.name_text)
		seen[paraje.name_text] = true
	assert_eq(registro.list.size(), 40, "los cuarenta con nombre propio")


func test_dos_celdas_vecinas_son_el_mismo_paraje() -> void:
	# Un avellanar ocupa la ladera, no una celda de 64 m. Sin agrupar salian
	# tres avellanares a 45 m unos de otros, que como sitios distintos no
	# significan nada y llenaban el valle de chapas.
	var registro := Parajes.new()
	var first := _paraje(10, 10)
	registro.add(first)

	# Otro a una celda de distancia: 64 m, dentro del radio de agrupacion
	var neighbour := Vector3(11.0 * 64.0, 0.0, 10.0 * 64.0)
	assert_eq(registro.near(Subsistence.Activity.RECOLECCION, neighbour), first,
		"el vecino cae dentro del mismo paraje")


func test_lo_bastante_lejos_si_es_otro_paraje() -> void:
	var registro := Parajes.new()
	registro.add(_paraje(10, 10))
	var far := Vector3(20.0 * 64.0, 0.0, 10.0 * 64.0)
	assert_eq(registro.near(Subsistence.Activity.RECOLECCION, far), null,
		"a 640 m ya es otro sitio")


func test_un_clic_en_la_mancha_encuentra_el_paraje() -> void:
	# La chapa flotante solo marca el centro, pero el sitio es una mancha de
	# monte de decenas de metros: un clic en el borde tiene que caer en el
	# paraje igual que uno en el centro, o el jugador ve la ficha del terreno
	# donde esperaba la del avellanar.
	var registro := Parajes.new()
	var paraje := _paraje(10, 10)
	paraje.extent = 120.0
	registro.add(paraje)

	var edge := paraje.position + Vector3(100.0, 0.0, 0.0)
	assert_eq(registro.at(edge), paraje, "el borde de la mancha sigue siendo el paraje")

	var outside := paraje.position + Vector3(200.0, 0.0, 0.0)
	assert_eq(registro.at(outside), null, "fuera de la mancha ya no es el paraje")


func test_no_se_agrupa_con_otra_actividad() -> void:
	# Un remanso de pesca y un avellanar pueden estar pegados y siguen siendo
	# dos sitios: se va a ellos con gente distinta
	var registro := Parajes.new()
	registro.add(_paraje(10, 10, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION))
	var same_spot := Vector3(10.0 * 64.0, 0.0, 10.0 * 64.0)
	assert_eq(registro.near(Subsistence.Activity.PESCA, same_spot), null,
		"la pesca no se agrupa con la recoleccion")


# --- nombres de lugar ------------------------------------------------------

func test_un_punto_dentro_de_un_paraje_se_llama_como_el() -> void:
	var registro := Parajes.new()
	var paraje := _paraje(10, 10)
	registro.add(paraje)
	var name := registro.place_name(paraje.position, Vector3.ZERO)
	assert_eq(name, paraje.name_text, "es ese sitio, no otro")


func test_un_punto_cerca_se_nombra_respecto_al_paraje() -> void:
	# «Al norte del avellanar del recodo» situa el sitio; unas coordenadas no
	var registro := Parajes.new()
	var paraje := _paraje(10, 10)
	registro.add(paraje)
	var north := paraje.position + Vector3(0.0, 0.0, -400.0)
	var name := registro.place_name(north, Vector3.ZERO)
	assert_true(name.contains(paraje.name_text), "se nombra respecto a el")
	assert_true(name.begins_with("al norte"), "y con el rumbo delante")


func test_sin_nada_conocido_se_da_el_rumbo_y_la_distancia() -> void:
	# Es exactamente lo que sabria decir alguien que no ha estado alli
	var registro := Parajes.new()
	var home := Vector3(2000.0, 0.0, 2000.0)
	var far := home + Vector3(1500.0, 0.0, 0.0)
	var name := registro.place_name(far, home)
	assert_true(name.contains("levante"), "el este es levante")
	assert_true(name.contains("1500"), "y dice a que distancia")


func test_los_ocho_rumbos_salen_bien() -> void:
	var home := Vector3.ZERO
	assert_eq(Parajes.bearing(home, Vector3(0.0, 0.0, -100.0)), "al norte", "norte")
	assert_eq(Parajes.bearing(home, Vector3(100.0, 0.0, 0.0)), "a levante", "este")
	assert_eq(Parajes.bearing(home, Vector3(0.0, 0.0, 100.0)), "al sur", "sur")
	assert_eq(Parajes.bearing(home, Vector3(-100.0, 0.0, 0.0)), "a poniente", "oeste")


func test_la_puerta_de_casa_siempre_se_anda() -> void:
	# Un abrigo se elige por ser habitable, asi que su entrada se anda: si la
	# medicion dice lo contrario, la equivocada es la medicion. Y las
	# consecuencias son enormes y calladas -la banda entera queda en una celda
	# que no existe y no se le puede trazar nada-.
	var terrain := FakeTerrain.new()
	var grid := Navgrid.from_terrain(terrain, false, false)

	# El peor sitio posible: el abrigo con el pie metido en el rio
	var home := Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)
	assert_false(grid.passable(home), "de partida, la puerta esta cerrada")

	var freed := grid.open_around_home(home, terrain)
	assert_gt(float(freed), 0.0, "se abre a la fuerza")
	assert_true(grid.passable(home), "y ahora se anda")

	# Y el patio entero, no solo el punto
	for angle in range(8):
		var turn := float(angle) / 8.0 * TAU
		var near := home + Vector3(cos(turn) * 60.0, 0.0, sin(turn) * 60.0)
		assert_true(grid.passable(near),
			"tambien a sesenta metros, rumbo %d" % angle)


func test_abrir_la_puerta_no_regala_un_vado() -> void:
	# Se abre porque hay que salir, no porque sea buen camino: las celdas
	# forzadas quedan CARAS para que el trazado siga prefiriendo rodear
	var terrain := FakeTerrain.new()
	var grid := Navgrid.from_terrain(terrain, false, false)
	var home := Vector3(700.0, 0.0, FakeTerrain.RIVER_Z)
	grid.open_around_home(home, terrain)

	var cell := grid.cell_of(home)
	assert_gt(grid.cost[cell], 5.0,
		"cuesta cara (%.1f), no es una autopista" % grid.cost[cell])


## Una rejilla de prueba, escrita como se ve: '#' es mancha y '.' es vacio.
func _mask(rows: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for row: String in rows:
		for i in range(row.length()):
			out.append(1 if row[i] == "#" else 0)
	return out


## Una huella suelta del tamaño que haga falta, para probar la limpieza de la
## forma sin montar un paraje entero.
func _huella(side: int) -> Huella:
	var h := Huella.new()
	h.lado = side
	h.origen = Vector3.ZERO
	return h


func _draw(mask: PackedByteArray, side: int) -> String:
	var lines: Array[String] = []
	for z in range(side):
		var line := ""
		for x in range(side):
			line += "#" if mask[z * side + x] != 0 else "."
		lines.append(line)
	return "
".join(lines)


func test_un_paraje_es_un_sitio_y_no_un_archipielago() -> void:
	# Lo que se veia: una mancha agujereada con islas sueltas alrededor. Nadie
	# entiende asi un avellanar: uno dice «el avellanar» senalando un trozo de
	# ladera, con sus claros dentro y su borde.
	var side := 9
	# La isla va LEJOS a proposito. La primera version la puso a dos
	# celdillas y fallo con razon: a esa distancia tiene que absorberse, que
	# es justo lo que se pide. Una isla solo es otro sitio cuando de verdad
	# esta separada.
	var mask := _mask([
		".........",
		"..###....",
		"..#.#....",
		"..###....",
		".........",
		".........",
		".........",
		".........",
		"........#",
	])

	# El centro de la rejilla tiene que caer dentro del cuerpo para que la
	# prueba mida lo que dice medir
	mask[4 * side + 4] = 1

	var h := _huella(side)
	var body := h._solo_lo_pegado(h._ensanchar(mask), 4)
	h._tapar_claros(body)

	# El agujero de dentro, tapado
	assert_true(body[2 * side + 3] != 0, "el claro de en medio es parte del sitio")

	# Y la isla lejana, fuera: eso es otro paraje, y ya se llamara solo
	assert_true(body[8 * side + 8] == 0,
		"la isla de la esquina no se cuela:
%s" % _draw(body, side))


func test_las_islas_de_al_lado_se_absorben() -> void:
	# La peticion literal: si hay islas, se incorporan y el paraje se hace mas
	# grande. Un hueco de una celdilla no separa dos sitios, separa dos matas.
	var side := 7
	var mask := _mask([
		".......",
		".......",
		"..#.#..",
		"..###..",
		"..#.#..",
		".......",
		".......",
	])

	var h := _huella(side)
	var body := h._solo_lo_pegado(h._ensanchar(mask), 3)
	h._tapar_claros(body)

	var filled := 0
	for on: int in body:
		if on != 0:
			filled += 1
	assert_gt(float(filled), 8.0,
		"las cuatro esquinas quedan pegadas en un solo cuerpo:
%s"
			% _draw(body, side))


# --- que hay dentro: un paraje no es un material repetido siempre igual ---

func _field_rico() -> ResourceField:
	# Un cotarro con de todo: recoleccion, caza de sobra y materia prima,
	# para que fill_contents tenga donde elegir
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	for activity: int in [Subsistence.Activity.RECOLECCION, Subsistence.Activity.CAZA,
			Subsistence.Activity.MATERIA_PRIMA]:
		field.set_abundance(activity as Subsistence.Activity, 4, 4, 1.0)
		field.spread(activity as Subsistence.Activity, 3)
	return field


# --- la mancha respeta el terreno: ni cruza rios ni trepa cantiles -------

func test_la_mancha_no_cruza_el_rio() -> void:
	var terrain := FakeTerrain.new()
	var paraje := _paraje(10, 20, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	var orilla := Vector3(500.0, 0.0, FakeTerrain.RIVER_Z)
	assert_false(Huella._cuadra_el_terreno(paraje, orilla, terrain),
		"el cauce del rio no es sitio de recolectar")


func test_la_mancha_no_trepa_un_cantil() -> void:
	var terrain := FakeTerrain.new()
	var paraje := _paraje(10, 20, Materia.Kind.CARNE, Subsistence.Activity.CAZA)
	var pared := Vector3(FakeTerrain.GORGE_X, 0.0, 500.0)
	assert_false(Huella._cuadra_el_terreno(paraje, pared, terrain),
		"una pared casi vertical no es sitio de caza")


func test_la_materia_prima_si_trepa_un_cantil() -> void:
	# La excepcion explicita: una veta de piedra o silex SI puede estar en
	# roca viva -es precisamente donde se busca-, aunque el rio le siga
	# vedado igual que a cualquier otro.
	var terrain := FakeTerrain.new()
	var paraje := _paraje(10, 20, Materia.Kind.PIEDRA,
		Subsistence.Activity.MATERIA_PRIMA)
	var pared := Vector3(FakeTerrain.GORGE_X, 0.0, 500.0)
	assert_true(Huella._cuadra_el_terreno(paraje, pared, terrain),
		"la materia prima si se busca en la pared")

	var orilla := Vector3(500.0, 0.0, FakeTerrain.RIVER_Z)
	assert_false(Huella._cuadra_el_terreno(paraje, orilla, terrain),
		"pero el rio le sigue vedado igual que a cualquiera")


func test_terreno_normal_pasa_sin_problema() -> void:
	var terrain := FakeTerrain.new()
	var paraje := _paraje(10, 20, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	var llano := Vector3(500.0, 0.0, 500.0)
	assert_true(Huella._cuadra_el_terreno(paraje, llano, terrain),
		"la meseta llana no tiene nada que le impida ser paraje")


func test_sin_terreno_no_se_descarta_nada() -> void:
	# Las pruebas que bautizan sin terreno de verdad -Y=0 en todas partes-
	# no deben perder su mancha por esto.
	var paraje := _paraje(10, 20, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	assert_true(Huella._cuadra_el_terreno(paraje, Vector3(500.0, 0.0, 500.0), null),
		"sin terreno, no hay con que descartar y se deja pasar")


# --- un SITIO es un paraje, aunque en el se hagan tres cosas --------------

func test_tres_oficios_en_el_mismo_sitio_son_un_solo_paraje() -> void:
	# La queja literal: "el pasto del recodo, el raizal del recodo y el
	# desmogadero del recodo son 3 parajes IGUALES en el MISMO SITIO".
	var field := _field_rico()
	var knowledge := BandKnowledge.new()
	knowledge.setup(field.width, field.height, field.world_size)

	# Todo el cuadro central conocido de sobra, para las tres actividades
	for activity: int in [Subsistence.Activity.RECOLECCION,
			Subsistence.Activity.CAZA, Subsistence.Activity.MATERIA_PRIMA]:
		for z in range(field.height):
			for x in range(field.width):
				knowledge.reveal(activity as Subsistence.Activity,
					field.cell_center(x, z), 1.0)

	var registro := Parajes.new()
	registro.refresh(field, knowledge, 1, [Subsistence.Activity.RECOLECCION,
		Subsistence.Activity.CAZA, Subsistence.Activity.MATERIA_PRIMA])

	# Ni un solo par de parajes puede compartir sitio
	for uno: Paraje in registro.list:
		for otro: Paraje in registro.list:
			if uno == otro:
				continue
			var flat := Vector2(uno.position.x - otro.position.x,
				uno.position.z - otro.position.z).length()
			assert_gt(flat, Parajes.SITE_RANGE,
				"«%s» y «%s» estan en el mismo sitio y deberian ser uno"
					% [uno.name_text, otro.name_text])

	# Y el sitio rico tiene que servir a mas de un oficio: si no, no se ha
	# fusionado nada, simplemente no habia nada que fusionar
	var con_varios := 0
	for paraje: Paraje in registro.list:
		if paraje.activities.size() > 1:
			con_varios += 1
	assert_gt(con_varios, 0,
		"el cotarro con caza, recoleccion y piedra sirve a varios oficios")


func test_el_paraje_fundido_sirve_a_cada_uno_de_sus_oficios() -> void:
	var paraje := _paraje(3, 4, Materia.Kind.CARNE, Subsistence.Activity.CAZA)
	assert_true(paraje.serves(Subsistence.Activity.CAZA), "el suyo, de entrada")
	assert_false(paraje.serves(Subsistence.Activity.RECOLECCION), "el de otro, no")

	assert_true(paraje.add_activity(Subsistence.Activity.RECOLECCION),
		"sumar un oficio nuevo cuenta")
	assert_false(paraje.add_activity(Subsistence.Activity.RECOLECCION),
		"sumarlo dos veces, no")
	assert_true(paraje.serves(Subsistence.Activity.RECOLECCION),
		"y ahora tambien se recolecta aqui")
	assert_true(paraje.serves(Subsistence.Activity.CAZA),
		"sin perder el que tenia")


func test_un_paraje_fundido_sale_en_la_lista_de_cada_oficio() -> void:
	var registro := Parajes.new()
	var paraje := _paraje(3, 4, Materia.Kind.CARNE, Subsistence.Activity.CAZA)
	paraje.add_activity(Subsistence.Activity.MATERIA_PRIMA)
	registro.add(paraje)

	assert_eq(registro.of(Subsistence.Activity.CAZA, Vector3.ZERO).size(), 1,
		"sale para la caza")
	assert_eq(registro.of(Subsistence.Activity.MATERIA_PRIMA, Vector3.ZERO).size(), 1,
		"y para la materia prima, siendo el mismo")
	assert_eq(registro.of(Subsistence.Activity.PESCA, Vector3.ZERO).size(), 0,
		"pero no para lo que no se hace ahi")


# --- un marcador por sitio, no por paraje ----------------------------------

func test_un_marcador_por_grupo() -> void:
	var markers := ParajeMarkers.new()
	var registro := Parajes.new()
	var uno := _paraje(3, 4, Materia.Kind.FRUTO_SECO, Subsistence.Activity.RECOLECCION)
	var dos := _paraje(3, 4, Materia.Kind.CARNE, Subsistence.Activity.CAZA)
	dos.position = uno.position + Vector3(50.0, 0.0, 0.0)
	registro.add(uno)
	registro.add(dos)

	markers.refresh(registro, null)

	var con_chapa := 0
	for paraje: Paraje in registro.list:
		if markers._markers.has(paraje.id()):
			con_chapa += 1
	assert_eq(con_chapa, 1,
		"dos parajes en el mismo sitio comparten una sola chapa")
	markers.free()


func test_marcador_propio_si_estan_lejos() -> void:
	var markers := ParajeMarkers.new()
	var registro := Parajes.new()
	var uno := _paraje(3, 4, Materia.Kind.FRUTO_SECO, Subsistence.Activity.RECOLECCION)
	var lejos := _paraje(30, 40, Materia.Kind.CARNE, Subsistence.Activity.CAZA)
	registro.add(uno)
	registro.add(lejos)

	markers.refresh(registro, null)

	var con_chapa := 0
	for paraje: Paraje in registro.list:
		if markers._markers.has(paraje.id()):
			con_chapa += 1
	assert_eq(con_chapa, 2,
		"dos parajes lejos entre si tienen cada uno su chapa")
	markers.free()


# --- fusionar solo si es de verdad el mismo trozo de monte ----------------

func test_near_sin_same_patch_se_comporta_como_antes() -> void:
	var registro := Parajes.new()
	registro.add(_paraje(3, 4))
	var cerca := Vector3(3.0 * 64.0 + 100.0, 0.0, 4.0 * 64.0)
	assert_true(registro.near(Subsistence.Activity.RECOLECCION, cerca) != null,
		"sin same_patch, solo cuenta la distancia -como siempre")


func test_near_con_same_patch_no_funde_a_traves_de_una_barrera() -> void:
	var registro := Parajes.new()
	registro.add(_paraje(3, 4))
	# Cerca en linea recta -dentro de MERGE_RANGE- pero al otro lado de
	# "algo": el same_patch dice que no son el mismo trozo de monte.
	var otro_lado := Vector3(3.0 * 64.0 + 100.0, 0.0, 4.0 * 64.0)
	var nunca_mismo_sitio := func(_a: Vector3, _b: Vector3) -> bool: return false
	assert_eq(registro.near(Subsistence.Activity.RECOLECCION, otro_lado,
		Parajes.MERGE_RANGE, nunca_mismo_sitio), null,
		"cerca en linea recta no basta si same_patch dice que no son el mismo sitio")


func test_near_con_same_patch_si_funde_si_es_el_mismo_trozo() -> void:
	var registro := Parajes.new()
	registro.add(_paraje(3, 4))
	var cerca := Vector3(3.0 * 64.0 + 100.0, 0.0, 4.0 * 64.0)
	var siempre_mismo_sitio := func(_a: Vector3, _b: Vector3) -> bool: return true
	assert_true(registro.near(Subsistence.Activity.RECOLECCION, cerca,
		Parajes.MERGE_RANGE, siempre_mismo_sitio) != null,
		"cerca y en el mismo trozo, se funde en uno")


func test_la_caza_pide_mas_abundancia_que_las_demas() -> void:
	assert_gt(Parajes.threshold_for(Subsistence.Activity.CAZA),
		Parajes.threshold_for(Subsistence.Activity.RECOLECCION),
		"un roce de animales no basta para que aparezca carne")


func test_sin_caza_de_verdad_no_sale_carne() -> void:
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	field.set_abundance(Subsistence.Activity.RECOLECCION, 4, 4, 1.0)
	field.spread(Subsistence.Activity.RECOLECCION, 3)
	# Caza a un roce, por debajo del umbral estricto
	field.set_abundance(Subsistence.Activity.CAZA, 4, 4, 0.15)

	var centro := field.cell_center(4, 4)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, centro, 1)
	paraje.fill_contents(field, Subsistence.Season.OTONO)

	assert_false(paraje.contents.has(int(Materia.Kind.CARNE)),
		"sin caza de verdad, no hay carne fresca que listar")


func test_con_caza_de_verdad_si_sale_carne() -> void:
	var field := _field_rico()
	var centro := field.cell_center(4, 4)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.CAZA,
		Materia.Kind.CARNE, centro, 1)
	paraje.fill_contents(field, Subsistence.Season.OTONO)

	assert_true(paraje.contents.has(int(Materia.Kind.CARNE)),
		"con caza de sobra, la carne si aparece")


func test_un_paraje_rico_da_mas_de_dos_materiales() -> void:
	# La queja literal: faltaban casi todos los materiales del catalogo
	# porque cada actividad solo daba UNO siempre. Con un cotarro que tiene
	# de todo, `contents` tiene que reflejarlo.
	var field := _field_rico()
	var centro := field.cell_center(4, 4)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, centro, 1)
	paraje.fill_contents(field, Subsistence.Season.OTONO)

	assert_gt(float(paraje.contents.size()), 3.0,
		"un sitio con caza, recoleccion y materia prima da mas de tres cosas")


# --- lo que hay cambia con la estacion, de verdad -------------------------

func test_el_asta_solo_esta_en_invierno() -> void:
	# Peticion explicita: "los cuernos caidos de los animales solo ocurren
	# en una temporada"
	assert_true(Parajes.in_season(Materia.Kind.ASTA, Subsistence.Season.INVIERNO),
		"el desmogue es de invierno")
	for season: int in [Subsistence.Season.PRIMAVERA, Subsistence.Season.VERANO,
			Subsistence.Season.OTONO]:
		assert_false(Parajes.in_season(Materia.Kind.ASTA, season as Subsistence.Season),
			"fuera de invierno no hay cuernas caidas en el suelo")


func test_la_miel_solo_esta_en_verano() -> void:
	assert_true(Parajes.in_season(Materia.Kind.MIEL, Subsistence.Season.VERANO),
		"la miel es de verano")
	assert_false(Parajes.in_season(Materia.Kind.MIEL, Subsistence.Season.INVIERNO),
		"no de invierno")


func test_la_piedra_esta_todo_el_ano() -> void:
	# Lo que no aparece en la tabla es de todo el año
	for season: int in Subsistence.Season.values():
		assert_true(Parajes.in_season(Materia.Kind.PIEDRA, season as Subsistence.Season),
			"la piedra no sabe de estaciones")


## Busca un punto donde la eleccion determinista de materia prima de
## verdad caiga en asta, para no depender de que el hash de una celda
## cualquiera acierte por casualidad.
func _spot_with_asta(field: ResourceField) -> Vector3:
	var worth := Parajes.threshold_for(Subsistence.Activity.MATERIA_PRIMA)
	for z in range(field.height):
		for x in range(field.width):
			if field.abundance_cell(Subsistence.Activity.MATERIA_PRIMA, x, z) < worth:
				continue
			var centre := field.cell_center(x, z)
			if Parajes._kind_for(Subsistence.Activity.MATERIA_PRIMA, centre,
					Subsistence.Season.INVIERNO) == Materia.Kind.ASTA:
				return centre
	return Vector3.ZERO


func test_un_desmogadero_pierde_el_asta_fuera_de_invierno() -> void:
	var field := _field_rico()
	var centro := _spot_with_asta(field)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.MATERIA_PRIMA,
		Materia.Kind.ASTA, centro, 1)
	paraje.fill_contents(field, Subsistence.Season.INVIERNO)
	assert_true(paraje.contents.has(int(Materia.Kind.ASTA)),
		"en invierno, el desmogadero tiene asta")

	paraje.fill_contents(field, Subsistence.Season.VERANO)
	assert_false(paraje.contents.has(int(Materia.Kind.ASTA)),
		"en verano, ya no")


func test_lo_ya_sabido_no_se_olvida_al_cambiar_de_estacion() -> void:
	var field := _field_rico()
	var centro := _spot_with_asta(field)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.MATERIA_PRIMA,
		Materia.Kind.ASTA, centro, 1)
	paraje.fill_contents(field, Subsistence.Season.INVIERNO)
	paraje.reveal_one()
	paraje.reveal_one()
	var conocidos_antes: Array[int] = []
	for k: int in paraje.contents:
		if bool((paraje.contents[k] as Dictionary)["sabido"]):
			conocidos_antes.append(k)
	assert_gt(conocidos_antes.size(), 0, "hay que saber algo para que la prueba diga algo")

	# Cambia dos veces de estacion y vuelve a invierno: si el asta seguia
	# siendo sabida, tiene que seguir siendolo
	paraje.fill_contents(field, Subsistence.Season.PRIMAVERA)
	paraje.fill_contents(field, Subsistence.Season.INVIERNO)

	for k: int in conocidos_antes:
		if not paraje.contents.has(k):
			continue
		assert_true(bool((paraje.contents[k] as Dictionary)["sabido"]),
			"lo que ya se sabia sigue sabido al volver la estacion")


func test_el_nombre_de_recoleccion_cambia_con_la_estacion() -> void:
	var punto := Vector3(100.0, 0.0, 200.0)
	var primavera := Parajes._kind_for(Subsistence.Activity.RECOLECCION, punto,
		Subsistence.Season.PRIMAVERA)
	var verano := Parajes._kind_for(Subsistence.Activity.RECOLECCION, punto,
		Subsistence.Season.VERANO)
	var otono := Parajes._kind_for(Subsistence.Activity.RECOLECCION, punto,
		Subsistence.Season.OTONO)

	assert_eq(primavera, Materia.Kind.RAIZ, "en primavera se coge raiz")
	assert_eq(verano, Materia.Kind.BAYA, "en verano, baya")
	assert_eq(otono, Materia.Kind.FRUTO_SECO, "en otono, fruto seco")


func test_materia_prima_varia_por_sitio_no_por_estacion() -> void:
	var punto := Vector3(333.0, 0.0, 777.0)
	var primavera := Parajes._kind_for(Subsistence.Activity.MATERIA_PRIMA, punto,
		Subsistence.Season.PRIMAVERA)
	var otono := Parajes._kind_for(Subsistence.Activity.MATERIA_PRIMA, punto,
		Subsistence.Season.OTONO)
	assert_eq(primavera, otono, "la piedra no sabe que mes es")

	# Y sitios distintos pueden dar un nombre distinto -cantizal, veta de
	# silex, veta de ocre o desmogadero-
	var any_different := false
	for i in range(30):
		var otro := Vector3(float(i) * 89.0, 0.0, float(i) * 131.0)
		if Parajes._kind_for(Subsistence.Activity.MATERIA_PRIMA, otro,
				Subsistence.Season.OTONO) != primavera:
			any_different = true
			break
	assert_true(any_different, "no todos los cotarros de piedra se llaman igual")


func test_activity_for_kind_reconoce_lo_de_cada_actividad() -> void:
	assert_eq(Parajes.activity_for_kind(Materia.Kind.CARNE),
		Subsistence.Activity.CAZA, "la carne es caza")
	assert_eq(Parajes.activity_for_kind(Materia.Kind.PESCADO),
		Subsistence.Activity.PESCA, "el pescado es pesca")
	assert_eq(Parajes.activity_for_kind(Materia.Kind.MARISCO),
		Subsistence.Activity.MARISQUEO, "el marisco es marisqueo")
	assert_eq(Parajes.activity_for_kind(Materia.Kind.SILEX),
		Subsistence.Activity.MATERIA_PRIMA, "el silex es materia prima")
	assert_eq(Parajes.activity_for_kind(Materia.Kind.SETA),
		Subsistence.Activity.RECOLECCION, "la seta es recoleccion")
	assert_eq(Parajes.activity_for_kind(Materia.Kind.PIEL),
		Subsistence.Activity.CAZA, "la piel es un extra de caza")


func test_activity_for_kind_no_sabe_de_lena_ni_fibra() -> void:
	# Salen de cualquier sitio de paso, no tienen actividad propia
	assert_eq(Parajes.activity_for_kind(Materia.Kind.LENA), -1,
		"la leña no tiene actividad propia")
	assert_eq(Parajes.activity_for_kind(Materia.Kind.FIBRA), -1,
		"la fibra tampoco")


# --- lo que de verdad hay en el mapa, para el porcentaje de Territorio ----

func test_sin_recurso_alguno_el_catalogo_esta_vacio() -> void:
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	assert_true(Parajes.materials_on_map(Subsistence.Activity.CAZA, field).is_empty(),
		"sin caza de verdad en el mapa, no hay nada que catalogar")


func test_un_roce_de_caza_no_cuenta_para_el_catalogo() -> void:
	# El mismo umbral estricto que decide si nace un paraje de caza decide
	# tambien si la caza cuenta como "algo que hay en este mapa"
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	field.set_abundance(Subsistence.Activity.CAZA, 4, 4, 0.15)
	assert_true(Parajes.materials_on_map(Subsistence.Activity.CAZA, field).is_empty(),
		"un roce por debajo del umbral no es caza de verdad")


func test_el_catalogo_incluye_lo_que_da_nombre_y_los_extras() -> void:
	var field := _field_rico()
	var catalogo := Parajes.materials_on_map(Subsistence.Activity.CAZA, field)
	assert_true(catalogo.has(Materia.Kind.CARNE),
		"la carne -lo que da nombre- esta en el catalogo")
	# Con caza de sobra extendida por varias celdas, alguno de los extras
	# -piel, hueso, tendon, grasa- tiene que aparecer en algun sitio
	var algun_extra := false
	for extra: Materia.Kind in [Materia.Kind.PIEL, Materia.Kind.HUESO,
			Materia.Kind.TENDON, Materia.Kind.GRASA]:
		if catalogo.has(extra):
			algun_extra = true
			break
	assert_true(algun_extra, "algun extra de caza sale en el mapa")


func test_recoleccion_recorre_las_cuatro_estaciones() -> void:
	# La raiz de invierno y la avellana de otoño son sitios que existen en
	# este mapa aunque la banda todavia no haya vivido esa estacion: el
	# catalogo no puede depender de la estacion actual de la partida.
	var field := _field_rico()
	var catalogo := Parajes.materials_on_map(Subsistence.Activity.RECOLECCION, field)
	for kind: Materia.Kind in Parajes.RECOLECCION_NAMING_BY_SEASON.values():
		assert_true(catalogo.has(kind),
			"%s deberia estar, salga la estacion que salga"
				% Materia.material_name(kind))


func test_el_nombre_lo_pone_lo_que_mas_abunda() -> void:
	# Peticion literal: «los parajes deben estar nombrados por el material
	# mas numeroso... lo que mas haya».
	var paraje := _paraje(2, 2, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	paraje.contents = {
		int(Materia.Kind.FRUTO_SECO): {"abundancia": 0.2, "sabido": true},
		int(Materia.Kind.RAIZ): {"abundancia": 0.9, "sabido": false},
		int(Materia.Kind.LENA): {"abundancia": 0.12, "sabido": false},
	}
	assert_eq(Parajes._richest_named(paraje), int(Materia.Kind.RAIZ),
		"con cuatro veces mas raiz que avellana, es un raizal")


func test_la_lena_no_bautiza_medio_valle() -> void:
	# La leña y la fibra se meten en TODOS los parajes con una pizca fija:
	# si pujaran de tu a tu, cualquier sitio flojo saldria como «el leñero»
	var paraje := _paraje(2, 2, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	paraje.contents = {
		int(Materia.Kind.BAYA): {"abundancia": 0.10, "sabido": true},
		int(Materia.Kind.LENA): {"abundancia": 0.12, "sabido": false},
	}
	assert_eq(Parajes._richest_named(paraje), int(Materia.Kind.BAYA),
		"gana la baya aunque la lena tenga un pelo mas")


# --- la veta que se acaba se lleva el paraje por delante ------------------

## Deja una actividad a cero SIN tocar la capacidad: eso es esquilmar, que no
## es lo mismo que agotar -lo esquilmado vuelve a crecer.
func _esquilmar(field: ResourceField, activity: Subsistence.Activity) -> void:
	for z in range(field.height):
		for x in range(field.width):
			# Por celda y con `take_from_cell`, que es lo que usa el juego:
			# `deplete_at` era el otro camino y no lo llamaba nadie.
			field.take_from_cell(activity, z * field.width + x, 999.0)


## Un campo con una mancha de materia prima en una celda que de verdad da una
## VETA -de las que no vuelven a crecer- y no cuerna caída.
##
## La celda no se elige a dedo: cuál es cuál lo decide `Parajes._kind_for`,
## determinista por posición, así que hay que buscarla. Fijar una celda a mano
## y suponer que da sílex es como se escribe una prueba que pasa por
## casualidad y deja de pasar al cambiar una constante.
func _campo_con_veta() -> Dictionary:
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	for z in range(8):
		for x in range(8):
			var kind := Parajes._kind_for(Subsistence.Activity.MATERIA_PRIMA,
				field.cell_center(x, z), GameState.season as Subsistence.Season)
			if Materia.renews(kind):
				continue
			field.set_abundance(Subsistence.Activity.MATERIA_PRIMA, x, z, 1.0)
			field.spread(Subsistence.Activity.MATERIA_PRIMA, 2)
			return {"field": field, "x": x, "z": z, "kind": kind}
	return {}


## El paraje de esa veta, ya colocado en su celda.
func _paraje_de_veta(veta: Dictionary) -> Paraje:
	var field: ResourceField = veta["field"]
	var paraje := Paraje.create(int(veta["x"]), int(veta["z"]),
		Subsistence.Activity.MATERIA_PRIMA, veta["kind"] as Materia.Kind,
		field.cell_center(int(veta["x"]), int(veta["z"])), 1)
	paraje.contents = {int(veta["kind"]): {"abundancia": 0.9, "sabido": true}}
	return paraje


func test_la_veta_agotada_borra_el_paraje() -> void:
	# Petición literal: «si un producto no sostenible se agota y es el que
	# nombra un paraje, el paraje desaparece».
	var veta := _campo_con_veta()
	assert_false(veta.is_empty(), "en un campo de 8x8 hay alguna veta")
	var field: ResourceField = veta["field"]
	var parajes := Parajes.new()
	var paraje := _paraje_de_veta(veta)
	parajes.add(paraje)

	# Con la veta entera no pasa nada: agotar no es lo mismo que estar usada
	assert_true(parajes.prune_exhausted(field).is_empty(),
		"una veta llena no se pierde")
	assert_eq(parajes.list.size(), 1, "y el paraje sigue ahi")

	# Se saca hasta el fondo
	_esquilmar(field, Subsistence.Activity.MATERIA_PRIMA)
	var news := parajes.prune_exhausted(field)
	assert_eq(news.size(), 1, "la veta agotada es noticia")
	assert_true(bool(news[0]["gone"]), "y la noticia es que el sitio se pierde")
	assert_eq(parajes.list.size(), 0, "el paraje ha desaparecido")


func test_la_veta_agotada_no_vuelve_a_crecer() -> void:
	# Que desaparezca y reaparezca al día siguiente no sería agotarse: es la
	# CAPACIDAD la que se va, no sólo las existencias
	var veta := _campo_con_veta()
	var field: ResourceField = veta["field"]
	var parajes := Parajes.new()
	parajes.add(_paraje_de_veta(veta))

	_esquilmar(field, Subsistence.Activity.MATERIA_PRIMA)
	parajes.prune_exhausted(field)

	for _day in range(200):
		field.regrow(Subsistence.Activity.MATERIA_PRIMA, 0.045)
	assert_eq(field.abundance_cell(Subsistence.Activity.MATERIA_PRIMA,
		int(veta["x"]), int(veta["z"])), 0.0,
		"doscientos dias despues sigue sin haber nada")


func test_la_veta_no_se_repone_ni_estando_a_medias() -> void:
	# El fallo de fondo: `regrow` le devolvía a una veta lo mismo que a un
	# pastizal. Medido en la sonda, ocho canteros sacando seis mil unidades
	# en ciento cuarenta días dejaban el cantizal al 77% y ahí se quedaba
	# para siempre: no se podía agotar, o sea que no se podía perder.
	var veta := _campo_con_veta()
	var field: ResourceField = veta["field"]
	var x := int(veta["x"])
	var z := int(veta["z"])
	field.freeze(Subsistence.Activity.MATERIA_PRIMA, x, z)
	field.take_from_cell(Subsistence.Activity.MATERIA_PRIMA,
		z * field.width + x, 0.5)
	var medio := field.abundance_cell(Subsistence.Activity.MATERIA_PRIMA, x, z)

	for _day in range(100):
		field.regrow(Subsistence.Activity.MATERIA_PRIMA, 0.045)
	assert_eq(field.abundance_cell(Subsistence.Activity.MATERIA_PRIMA, x, z),
		medio, "cien dias despues sigue habiendo lo mismo: no rebrota")


func test_el_avellanar_esquilmado_no_desaparece() -> void:
	# Lo que vuelve a crecer no se pierde nunca: un avellanar esquilmado es
	# un avellanar flojo, no un sitio menos en el mapa
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	field.set_abundance(Subsistence.Activity.RECOLECCION, 4, 4, 1.0)
	field.spread(Subsistence.Activity.RECOLECCION, 2)

	var parajes := Parajes.new()
	var paraje := _paraje(4, 4, Materia.Kind.FRUTO_SECO,
		Subsistence.Activity.RECOLECCION)
	paraje.position = field.cell_center(4, 4)
	parajes.add(paraje)

	_esquilmar(field, Subsistence.Activity.RECOLECCION)
	assert_true(parajes.prune_exhausted(field).is_empty(),
		"la avellana vuelve el año que viene")
	assert_eq(parajes.list.size(), 1, "y el sitio sigue siendo el sitio")


func test_el_sitio_con_otro_oficio_sobrevive_a_la_veta() -> void:
	# Un cantizal que además era pasto no desaparece: deja de ser cantizal
	var veta := _campo_con_veta()
	var field: ResourceField = veta["field"]
	var paraje := _paraje_de_veta(veta)
	field.set_abundance(Subsistence.Activity.CAZA, int(veta["x"]),
		int(veta["z"]), 1.0)
	field.spread(Subsistence.Activity.CAZA, 2)

	var parajes := Parajes.new()
	paraje.add_activity(Subsistence.Activity.CAZA)
	paraje.contents[int(Materia.Kind.CARNE)] = {"abundancia": 0.6, "sabido": true}
	parajes.add(paraje)

	_esquilmar(field, Subsistence.Activity.MATERIA_PRIMA)
	var news := parajes.prune_exhausted(field)
	assert_eq(news.size(), 1, "la veta se ha acabado igual")
	assert_false(bool(news[0]["gone"]), "pero el sitio no se pierde")
	assert_eq(parajes.list.size(), 1, "sigue en la lista")
	assert_eq(paraje.kind, Materia.Kind.CARNE, "y ahora lo nombra la caza")
	assert_true(paraje.name_text.begins_with("El pasto"),
		"con el nombre cambiado: %s" % paraje.name_text)
	assert_false(paraje.serves(Subsistence.Activity.MATERIA_PRIMA),
		"ya no se viene aqui a por piedra")


func test_el_punto_puede_volver_a_bautizarse_con_otro_material() -> void:
	# «Podrá volver a salir un paraje en ese punto con otro material»: al
	# secar sólo la materia prima, la recolección de ese mismo punto sigue
	# entera y `refresh` puede bautizarlo de nuevo
	var veta := _campo_con_veta()
	var field: ResourceField = veta["field"]
	var x := int(veta["x"])
	var z := int(veta["z"])
	field.set_abundance(Subsistence.Activity.RECOLECCION, x, z, 1.0)
	field.spread(Subsistence.Activity.RECOLECCION, 2)

	var parajes := Parajes.new()
	parajes.add(_paraje_de_veta(veta))

	_esquilmar(field, Subsistence.Activity.MATERIA_PRIMA)
	parajes.prune_exhausted(field)
	assert_eq(parajes.list.size(), 0, "el cantizal se ha perdido")

	var knowledge := BandKnowledge.new()
	knowledge.setup(8, 8, Vector2(512.0, 512.0))
	knowledge.see_from(field.cell_center(x, z), 200.0)
	knowledge.reveal(Subsistence.Activity.RECOLECCION, field.cell_center(x, z), 1.0)
	parajes.refresh(field, knowledge, 30, [Subsistence.Activity.RECOLECCION])

	assert_true(parajes.list.size() >= 1,
		"en ese punto vuelve a salir un sitio, ahora de recoleccion")
	assert_false(parajes.list[0].serves(Subsistence.Activity.MATERIA_PRIMA),
		"pero ya no de piedra")


# --- la ficha dice lo que de verdad se saca de allí -----------------------

func test_el_paraje_enseña_toda_la_cesta_de_la_actividad() -> void:
	# Petición literal: «no sé de dónde están sacando frutos secos, bayas,
	# bellotas, setas... cuando ningún paraje muestra que lo tiene; deberían
	# aparecer en los parajes».
	#
	# Y no aparecían: la cosecha da la cesta ENTERA de la especialidad en
	# cualquier sitio, y la ficha enseñaba el material que bautiza el paraje
	# y dos extras. Ocho cosas en el zurrón y tres en la ficha.
	# Y la cesta es LA DE LA ESTACIÓN, que es la otra mitad: pedía avellana y
	# baya en primavera, y desde el repaso del calendario no las hay. La
	# avellana es de septiembre y la mora de agosto; en marzo el zarzal está en
	# flor. La prueba comprueba ahora las dos cosas -que sale todo lo que se
	# recoge Y que no sale lo que no toca-, que es más fuerte que lo de antes.
	var field := _field_rico()
	var paraje := _paraje(4, 4, Materia.Kind.RAIZ, Subsistence.Activity.RECOLECCION)
	paraje.position = field.cell_center(4, 4)

	paraje.fill_contents(field, Subsistence.Season.PRIMAVERA)
	for kind: Materia.Kind in [Materia.Kind.CARACOL, Materia.Kind.HUEVO,
			Materia.Kind.CORTEZA, Materia.Kind.RAIZ]:
		assert_true(paraje.contents.has(int(kind)),
			"%s se saca de aquí en primavera, así que tiene que salir en la ficha"
				% Materia.material_name(kind))
	for fuera: Materia.Kind in [Materia.Kind.FRUTO_SECO, Materia.Kind.BAYA,
			Materia.Kind.BELLOTA, Materia.Kind.SETA]:
		assert_false(paraje.contents.has(int(fuera)),
			"%s no es de primavera y no puede salir en la ficha"
				% Materia.material_name(fuera))

	paraje.fill_contents(field, Subsistence.Season.OTONO)
	for kind: Materia.Kind in [Materia.Kind.FRUTO_SECO, Materia.Kind.BAYA,
			Materia.Kind.BELLOTA, Materia.Kind.SETA, Materia.Kind.RAIZ]:
		assert_true(paraje.contents.has(int(kind)),
			"%s es de otoño y tiene que salir en la ficha"
				% Materia.material_name(kind))


func test_la_rebusca_no_le_quita_el_nombre_al_paraje() -> void:
	# Todo lo de la cesta sale, pero de rebusca: si pujara de tú a tú, el
	# material que menos abunda podría acabar bautizando el sitio y todos los
	# prados del valle se llamarían igual.
	# Solo recoleccion: en un sitio que ademas tenga materia prima manda la
	# veta, y con razon -eso es otra prueba
	var field := ResourceField.new()
	field.setup(8, 8, Vector2(512.0, 512.0))
	field.set_abundance(Subsistence.Activity.RECOLECCION, 4, 4, 1.0)
	field.spread(Subsistence.Activity.RECOLECCION, 3)

	var paraje := _paraje(4, 4, Materia.Kind.RAIZ, Subsistence.Activity.RECOLECCION)
	paraje.position = field.cell_center(4, 4)
	paraje.fill_contents(field, Subsistence.Season.PRIMAVERA)

	var principal := float((paraje.contents[int(Materia.Kind.RAIZ)]
		as Dictionary)["abundancia"])
	var rebusca := float((paraje.contents[int(Materia.Kind.CORTEZA)]
		as Dictionary)["abundancia"])
	assert_true(rebusca < principal * 0.5,
		"la rebusca es una pizca (%.3f) al lado de lo que da el sitio (%.3f)"
			% [rebusca, principal])
	assert_eq(Parajes._richest_named(paraje), int(Materia.Kind.RAIZ),
		"y el nombre sigue saliendo de lo que de verdad abunda")


func test_lo_de_otra_temporada_no_sale_ni_en_la_ficha() -> void:
	# La bellota es de otoño y la miel de verano. En primavera no están, ni
	# de rebusca: si no, la ficha volvería a decir una cosa y el monte otra.
	var field := _field_rico()
	var paraje := _paraje(4, 4, Materia.Kind.RAIZ, Subsistence.Activity.RECOLECCION)
	paraje.position = field.cell_center(4, 4)
	paraje.fill_contents(field, Subsistence.Season.PRIMAVERA)
	assert_false(paraje.contents.has(int(Materia.Kind.BELLOTA)),
		"en marzo no hay bellota")
	assert_false(paraje.contents.has(int(Materia.Kind.MIEL)),
		"ni miel")

	paraje.fill_contents(field, Subsistence.Season.OTONO)
	assert_true(paraje.contents.has(int(Materia.Kind.BELLOTA)),
		"y en otoño sí la hay")


# --- el reparto de nombres de materia prima -------------------------------

func test_hay_menos_cantizales_que_de_lo_demas() -> void:
	# Petición literal: «hay demasiado cantizal, reduce ligeramente su
	# proporción». Con los cuatro nombres a la misma papeleta salía uno de
	# cada cuatro; ahora la cuarcita saca menos que las otras tres.
	var field := ResourceField.new()
	field.setup(32, 32, Vector2(2048.0, 2048.0))
	var tally := {}
	for z in range(32):
		for x in range(32):
			var kind := Parajes._kind_for(Subsistence.Activity.MATERIA_PRIMA,
				field.cell_center(x, z), Subsistence.Season.PRIMAVERA)
			tally[int(kind)] = int(tally.get(int(kind), 0)) + 1

	var cuarcita := int(tally.get(int(Materia.Kind.PIEDRA), 0))
	var total := 32 * 32
	assert_true(cuarcita > 0, "cantizales sigue habiendo")
	var share := float(cuarcita) / float(total)
	assert_true(share < 0.23,
		"la cuarcita baja del cuarto que sacaba antes: %.1f%%" % (share * 100.0))
	assert_true(share > 0.15,
		"pero sin pasarse, que la cuarcita es la piedra de todos los dias: %.1f%%"
			% (share * 100.0))
	for kind: Materia.Kind in [Materia.Kind.SILEX, Materia.Kind.OCRE,
			Materia.Kind.ASTA]:
		assert_true(int(tally.get(int(kind), 0)) > cuarcita,
			"%s sale mas que la cuarcita" % Materia.material_name(kind))

# --- cada cosa en su suelo -----------------------------------------------
#
# «No encontraremos corteza en un paraje en el agua». `fill_contents` recorria
# las cinco actividades y metia lo que pasara el umbral de cada una sin mirar
# el suelo de debajo. Medido en el sitio 56 con `scripts/tests/ParajeProbe.gd`:
# los 41 parajes que caen en agua llevaban material de tierra -272 entradas de
# corteza, bellota, resina y ocre EN EL RIO- y 103 de tierra llevaban pescado.
# Despues: cero y cero.

func test_en_el_agua_no_hay_corteza_ni_lena() -> void:
	var hondo := Hydrography.FORD_IMPASSABLE
	for kind: int in [Materia.Kind.CORTEZA, Materia.Kind.LENA,
		Materia.Kind.BELLOTA, Materia.Kind.OCRE, Materia.Kind.RESINA]:
		assert_false(Parajes.material_fits(kind as Materia.Kind, hondo),
			"%s no sale del fondo de un rio" % Materia.material_name(
				kind as Materia.Kind).to_lower())


func test_en_seco_no_hay_pescado_ni_marisco() -> void:
	for kind: int in [Materia.Kind.PESCADO, Materia.Kind.MARISCO,
		Materia.Kind.CONCHA]:
		assert_false(Parajes.material_fits(kind as Materia.Kind, 0.0),
			"%s no sale de un canchal" % Materia.material_name(
				kind as Materia.Kind).to_lower())


func test_la_piedra_sale_de_los_dos_sitios() -> void:
	# Peticion literal: un paraje de pescadores tiene pescado y CANTOS RODADOS.
	# El hueso, la piel y la pluma igual: salen de un animal, que puede haber
	# caido en cualquier parte.
	for kind: int in [Materia.Kind.PIEDRA, Materia.Kind.HUESO,
		Materia.Kind.PIEL, Materia.Kind.PLUMA]:
		assert_true(Parajes.material_fits(kind as Materia.Kind, 0.0),
			"en tierra si")
		assert_true(Parajes.material_fits(kind as Materia.Kind,
			Hydrography.FORD_IMPASSABLE), "y en el agua tambien")


func test_la_orilla_somera_tampoco_da_plantas() -> void:
	# Los dos umbrales no son el mismo: se vadea hasta 0,35 pero una planta se
	# ahoga mucho antes. Con un umbral solo quedaban 113 entradas de corteza y
	# resina en puntos de vadeo 0,32.
	var somero := Parajes.EN_EL_AGUA - 0.03
	assert_lt(somero, Hydrography.FORD_WADEABLE, "es agua que se vadea")
	assert_false(Parajes.material_fits(Materia.Kind.CORTEZA, somero),
		"pero sigue siendo agua, y ahi no hay arbol que descortezar")


func test_el_pescador_quiere_agua_y_el_recolector_suelo() -> void:
	assert_true(Parajes.activity_fits(Subsistence.Activity.PESCA, 0.5),
		"la pesca es en el agua")
	assert_false(Parajes.activity_fits(Subsistence.Activity.PESCA, 0.0),
		"y no en un prado seco")
	assert_true(Parajes.activity_fits(Subsistence.Activity.RECOLECCION, 0.0),
		"la recoleccion es en tierra")
	assert_false(Parajes.activity_fits(Subsistence.Activity.RECOLECCION, 0.5),
		"y no en el cauce")


func test_la_mancha_de_una_pesquera_ES_el_rio() -> void:
	# Se rechazaba TODO lo que no se pudiera cruzar a pie, incluso para la
	# pesca: la mancha salia con el cauce recortado por dentro, un agujero
	# justo donde estan los peces.
	var terrain := FakeTerrain.new()
	var paraje := _paraje(10, 20, Materia.Kind.PESCADO,
		Subsistence.Activity.PESCA)
	var cauce := Vector3(500.0, 0.0, FakeTerrain.RIVER_Z)
	assert_true(Huella._cuadra_el_terreno(paraje, cauce, terrain),
		"el rio ES la pesquera")
	var ladera := Vector3(500.0, 0.0, FakeTerrain.RIVER_Z + 400.0)
	assert_false(Huella._cuadra_el_terreno(paraje, ladera, terrain),
		"y la ladera de enfrente no")


# ------------------------------------ lo que la banda sabe al asentarse --

func test_asentarse_sin_campo_no_revienta() -> void:
	# `Querencia` corrio una vez con `sim.field` a null -se llamaba desde
	# `setup`, que va ANTES de poblar el campo- y sembraba cero parajes sin
	# decir nada. Que devuelva cero es correcto; que reviente, no.
	var sim := SettlementSim.new()
	assert_eq(Querencia.new(sim).asentarse(), 0,
		"sin campo de recursos no se siembra nada y no pasa nada")


func test_lo_sembrado_pasa_los_dos_umbrales() -> void:
	# Son DOS y distintos: 0,30 para bautizar el sitio y 0,35 para que el
	# reparto de tajos lo ofrezca. Sembrar entre los dos daba parajes en los
	# que la banda no podia trabajar.
	var minimo := Querencia.SABIDO * 0.75
	assert_gt(minimo, Parajes.NAMED_AT,
		"hasta el filo del radio se puede bautizar")
	assert_gt(minimo, 0.35,
		"y hasta el filo del radio se puede ofrecer como tajo")


func test_el_tanteo_no_manda_a_cruzar_el_valle() -> void:
	# La vuelta de tanteo es media jornada como mucho: quien no sabe si al
	# llegar habra algo no se juega el dia entero en el camino.
	assert_lt(Tanteo.VUELTA, 400.0, "la vuelta de tanteo es corta")
	assert_lt(Barbecho.BUSCAR_HASTA, 400.0,
		"y buscar sitio nuevo tampoco cruza el valle")


# ------------------------------------ cada paraje, de lo suyo y en su medio --

func test_un_paraje_de_agua_no_se_funde_en_uno_de_tierra() -> void:
	# LA QUEJA: «los parajes de pesca tambien abarcan parte de tierra, o
	# parajes de recoleccion cruzan el rio».
	#
	# Salia de la fusion: un sitio con caza, raiz y cuerna caida es UN sitio
	# donde se hacen tres cosas -y eso esta bien-, pero la regla no miraba el
	# MEDIO, asi que el remanso del rio se sumaba como oficio del avellanar de
	# la orilla si quedaba a menos de ciento cincuenta metros.
	assert_false(Parajes.activity_fits(Subsistence.Activity.PESCA, 0.0),
		"en tierra seca no se pesca, asi que no se le suma la pesca")
	assert_false(Parajes.activity_fits(Subsistence.Activity.RECOLECCION, 0.76),
		"y en el cauce no se recolecta")


func test_la_tierra_de_un_paraje_de_recoleccion_es_seca() -> void:
	# Estuvo admitiendo hasta el limite de VADEAR -0,35- y eso deja bautizar
	# avellanares con el agua por el tobillo: un sitio que se puede CRUZAR no
	# es un sitio donde CRECE algo.
	assert_true(Parajes.activity_fits(Subsistence.Activity.RECOLECCION,
		Parajes.SUELO_SECO), "hasta el limite de suelo seco, si")
	assert_false(Parajes.activity_fits(Subsistence.Activity.RECOLECCION,
		Parajes.SUELO_SECO + 0.05), "pasado de ahi, no")


func test_el_nombre_de_un_paraje_es_de_su_oficio() -> void:
	# Salia «El raizal de la vega - Caza»: bautizado por la caza y llamado por
	# la raiz, porque el nombre lo ponia lo que mas abundara fuera de la
	# actividad que fuera. El jugador lee una cosa y manda alli a otra.
	assert_eq(Parajes.material_que_da_nombre(Subsistence.Activity.CAZA),
		int(Materia.Kind.CARNE), "un sitio de caza se llama por la caza")
	assert_eq(Parajes.material_que_da_nombre(Subsistence.Activity.PESCA),
		int(Materia.Kind.PESCADO), "y uno de pesca por el pescado")
	assert_eq(Parajes.material_que_da_nombre(Subsistence.Activity.MATERIA_PRIMA),
		int(Materia.Kind.PIEDRA), "y una cantera por la piedra")


# ------------- la forma de un paraje no es un circulo ---------------------

## Un sitio de agua sale CINTA, no disco: se estira por donde hay cauce.
##
## [FakeTerrain] tiene un rio de ochenta metros de ancho cruzando de este a
## oeste, asi que una pesquera plantada encima tiene que salir estirada en x y
## cortada en z.
func test_una_pesquera_sigue_el_rio() -> void:
	var terrain := FakeTerrain.new()
	var centro := Vector3(500.0, 0.0, FakeTerrain.RIVER_Z)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.PESCA,
		Materia.Kind.PESCADO, centro, 1)
	var huella := Huella.de(paraje, null, terrain)

	var mas_lejos := paraje.extent * 2.0
	assert_gt(mas_lejos, paraje.extent,
		"la prueba mide MAS ALLA del radio nominal, que es de lo que va")
	assert_true(huella.contiene(centro + Vector3(mas_lejos, 0.0, 0.0)),
		"la cinta sigue el cauce mas alla del radio nominal")
	assert_true(huella.contiene(centro - Vector3(mas_lejos, 0.0, 0.0)),
		"y rio arriba tambien")
	assert_false(huella.contiene(centro + Vector3(0.0, 0.0, mas_lejos)),
		"pero no se sube a la ladera: ahi no hay donde pescar")
	terrain.free()


## Y un sitio de tierra no se sale de su alcance por las esquinas.
##
## Es lo que salia mal al ensanchar: crecer una celdilla sin volver a mirar el
## radio llenaba la caja de busqueda, y los parajes de tierra salian CUADRADOS
## -medido, el 224 % de su circulo con el lado largo igual al corto.
func test_un_paraje_de_tierra_no_sale_cuadrado() -> void:
	var terrain := FakeTerrain.new()
	var centro := Vector3(500.0, 0.0, 500.0)
	var paraje := Paraje.create(4, 4, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, centro, 1)
	var huella := Huella.de(paraje, null, terrain)

	var casi := paraje.extent * 0.9
	assert_true(huella.contiene(centro + Vector3(casi, 0.0, 0.0)),
		"de frente, al 90 % del radio, dentro")
	assert_false(huella.contiene(centro + Vector3(casi, 0.0, casi)),
		"pero la esquina esta a 1,27 radios del centro: fuera")
	terrain.free()


## Y la simulacion pregunta por la FORMA, no por el radio.
func test_lo_que_esta_dentro_lo_dice_la_huella() -> void:
	var paraje := Paraje.create(4, 4, Subsistence.Activity.RECOLECCION,
		Materia.Kind.FRUTO_SECO, Vector3(900.0, 0.0, 900.0), 1)
	# Sin forma sacada se cae al disco de siempre, que es lo que habia antes.
	assert_true(paraje.contains(paraje.position + Vector3(100.0, 0.0, 0.0)),
		"sin forma sacada, el disco de siempre")

	var huella := Huella.new()
	huella.lado = 3
	huella.origen = paraje.position - Vector3(
		Huella.CELDILLA * 1.5, 0.0, Huella.CELDILLA * 1.5)
	huella.dentro = PackedByteArray([0, 0, 0, 0, 1, 0, 0, 0, 0])
	paraje.huella = huella

	assert_true(paraje.contains(paraje.position), "el nucleo esta dentro")
	assert_false(paraje.contains(paraje.position + Vector3(100.0, 0.0, 0.0)),
		"y lo que la forma deja fuera esta fuera, aunque el radio lo abarque")
