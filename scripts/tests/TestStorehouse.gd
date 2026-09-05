class_name TestStorehouse
extends TestCase
## Pruebas del almacén.
##
## Lo que se prueba aquí no es que sume: es que el peso y el volumen tengan
## consecuencias. Un almacén sin límite es una lista de números que crecen, y
## entonces da igual qué se recoja. Con límite hay que elegir, y elegir es el
## juego.


func suite_name() -> String:
	return "Almacen"


func _abrigo() -> Storehouse:
	var store := Storehouse.new()
	# Un abrigo pequeño: 12 metros cúbicos utilizables
	store.capacity_litres = 12000.0
	return store


# --- contabilidad ----------------------------------------------------------

func test_al_empezar_esta_vacio() -> void:
	var store := _abrigo()
	assert_eq(store.amount(Materia.Kind.LENA), 0.0, "no hay nada guardado")
	assert_eq(store.total_litres(), 0.0, "ni ocupa volumen")
	assert_eq(store.total_kg(), 0.0, "ni pesa")


func test_guardar_suma_peso_y_volumen() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.LENA, 3.0)
	assert_eq(store.amount(Materia.Kind.LENA), 3.0, "hay tres haces")
	assert_near(store.total_kg(), 48.0, 0.01, "tres haces de 16 kg")
	assert_near(store.total_litres(), 120.0, 0.01, "y de 40 litros")


func test_el_peso_y_el_volumen_no_van_de_la_mano() -> void:
	# Es la razón de que hagan falta los dos números. La piedra pesa y no
	# abulta; la fibra abulta y no pesa. Con un solo límite, uno de los dos
	# materiales se comportaría mal.
	var piedra := _abrigo()
	piedra.add(Materia.Kind.PIEDRA, 10.0)
	var fibra := _abrigo()
	fibra.add(Materia.Kind.FIBRA, 10.0)

	assert_gt(piedra.total_kg(), fibra.total_kg() * 4.0,
		"diez nódulos pesan mucho más que diez manojos de fibra")
	assert_gt(fibra.total_litres(), piedra.total_litres() * 3.0,
		"y ocupan mucho menos sitio")


func test_sacar_resta() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.FRUTO_SECO, 40.0)
	var taken := store.take(Materia.Kind.FRUTO_SECO, 15.0)
	assert_near(taken, 15.0, 0.001, "se sacan las quince")
	assert_near(store.amount(Materia.Kind.FRUTO_SECO), 25.0, 0.001, "quedan 25")


func test_no_se_saca_lo_que_no_hay() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.CARNE, 3.0)
	assert_near(store.take(Materia.Kind.CARNE, 10.0), 3.0, 0.001,
		"se saca lo que hay, no lo que se pide")
	assert_eq(store.amount(Materia.Kind.CARNE), 0.0, "y queda vacío")


# --- el límite del sitio ---------------------------------------------------

func test_no_cabe_mas_de_lo_que_cabe() -> void:
	# Doce metros cúbicos son 300 haces de leña. Ni uno más.
	var store := _abrigo()
	var stored := store.add(Materia.Kind.LENA, 400.0)
	assert_near(stored, 300.0, 1.0, "solo entran las que caben")
	assert_lt(store.total_litres(), store.capacity_litres + 1.0,
		"y no se pasa de la capacidad")


func test_lo_que_no_cabe_se_queda_fuera() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.LENA, 400.0)
	assert_gt(store.overflow, 0.0, "el sobrante se anota, no desaparece sin más")


func test_la_leña_es_lo_que_llena_el_abrigo() -> void:
	# Es la observación de diseño que hace interesante el límite: no se llena
	# de comida, se llena de combustible
	var store := _abrigo()
	store.add(Materia.Kind.LENA, 100.0)
	var por_lena := store.total_litres()
	store.add(Materia.Kind.FRUTO_SECO, 100.0)
	var por_comida := store.total_litres() - por_lena
	assert_gt(por_lena, por_comida * 10.0,
		"cien haces ocupan mucho más que cien raciones de comida")


func test_el_espacio_libre_se_puede_consultar() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.LENA, 100.0)
	assert_near(store.free_litres(), 8000.0, 1.0, "quedan ocho metros cúbicos")


func test_sin_capacidad_declarada_no_hay_limite() -> void:
	# Sirve para probar y para el caso de guardar a la intemperie
	var store := Storehouse.new()
	store.capacity_litres = 0.0
	assert_near(store.add(Materia.Kind.LENA, 5000.0), 5000.0, 1.0,
		"sin techo declarado, cabe todo")


# --- alimento --------------------------------------------------------------

func test_las_raciones_se_cuentan_juntas() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.FRUTO_SECO, 10.0)
	store.add(Materia.Kind.CARNE, 5.0)
	store.add(Materia.Kind.PIEDRA, 20.0)
	assert_near(store.food_rations(), 15.0, 0.01,
		"la comida suma; la piedra no alimenta")


func test_la_grasa_alimenta_mas_que_su_peso() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.GRASA, 10.0)
	assert_gt(store.food_rations(), 10.0,
		"la grasa es el alimento más denso que hay")


func test_los_dias_de_autonomia_dependen_de_las_bocas() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.FRUTO_SECO, 40.0)
	assert_near(store.days_of_food(10.0), 4.0, 0.01, "diez bocas, cuatro días")
	assert_near(store.days_of_food(20.0), 2.0, 0.01, "veinte bocas, dos días")


# --- lo que se echa a perder ----------------------------------------------

func test_la_carne_fresca_se_pudre() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.CARNE, 20.0)
	store.age(6)
	assert_lt(store.amount(Materia.Kind.CARNE), 20.0,
		"en seis días parte de la carne se ha perdido")


func test_la_carne_seca_aguanta() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.CARNE_SECA, 20.0)
	store.age(60)
	assert_near(store.amount(Materia.Kind.CARNE_SECA), 20.0, 0.5,
		"la carne curada cruza el invierno")


func test_la_piedra_no_caduca() -> void:
	var store := _abrigo()
	store.add(Materia.Kind.PIEDRA, 20.0)
	store.age(3650)
	assert_near(store.amount(Materia.Kind.PIEDRA), 20.0, 0.001,
		"diez años y la piedra sigue siendo piedra")


func test_secar_la_carne_es_el_mejor_negocio_del_paleolitico() -> void:
	# Cuatro raciones frescas dan tres secas, pero pesan la cuarta parte y
	# duran cuarenta veces más: esa es la decision que crea el fuego
	var fresca := _abrigo()
	fresca.add(Materia.Kind.CARNE, 4.0)
	var seca := _abrigo()
	seca.add(Materia.Kind.CARNE_SECA, 3.0)

	assert_lt(seca.total_kg(), fresca.total_kg() * 0.4, "pesa mucho menos")
	assert_gt(float(Materia.shelf_life(Materia.Kind.CARNE_SECA)),
		float(Materia.shelf_life(Materia.Kind.CARNE)) * 20.0,
		"y dura muchísimo más")


# --- lo que se puede cargar -----------------------------------------------

func test_una_persona_carga_lo_que_carga() -> void:
	# 25 kg es lo que se lleva en una jornada larga. Con eso, el marisco es
	# casi intransportable y por eso se come en la orilla.
	assert_gt(Storehouse.units_carryable(Materia.Kind.FRUTO_SECO, 25.0),
		Storehouse.units_carryable(Materia.Kind.MARISCO, 25.0) * 3.0,
		"de fruto seco se traen muchas más raciones que de marisco")


func test_el_recipiente_multiplica_lo_que_se_trae() -> void:
	var sin_cesto := Storehouse.carry_capacity_kg(false, false)
	var con_cesto := Storehouse.carry_capacity_kg(true, false)
	var con_todo := Storehouse.carry_capacity_kg(true, true)
	assert_gt(con_cesto, sin_cesto, "con cesto se trae más")
	assert_gt(con_todo, con_cesto, "y con odre además, todavía más")
	assert_gt(sin_cesto, 0.0, "a mano siempre se puede traer algo")


func test_los_materiales_tienen_sitio_fijo() -> void:
	# La queja: las filas del almacen bailaban. Iban ordenadas por volumen, o
	# sea que cada vez que la banda traia un haz de lena la tabla entera se
	# recolocaba y buscabas la piedra donde ya no estaba.
	var store := Storehouse.new()
	var before: Array[int] = []
	for row: Dictionary in store.in_catalogue_order():
		before.append(int(row["kind"]))

	store.add(Materia.Kind.LENA, 200.0)
	store.add(Materia.Kind.SILEX, 3.0)
	store.add(Materia.Kind.CARNE, 40.0)

	var after: Array[int] = []
	for row: Dictionary in store.in_catalogue_order():
		after.append(int(row["kind"]))

	assert_eq(after, before, "el orden no depende de lo que haya guardado")


func test_el_almacen_ensena_todos_los_materiales() -> void:
	# Un material solo tiene sitio fijo si sale SIEMPRE, tenga o no unidades:
	# si aparece y desaparece, arrastra a todas las filas de debajo
	var store := Storehouse.new()
	assert_eq(store.in_catalogue_order().size(), Materia.Kind.size(),
		"salen los %d del catalogo aunque este vacio" % Materia.Kind.size())


func test_el_alimento_va_antes_que_la_materia_prima() -> void:
	# Es lo que hace navegable una tabla de veintisiete filas: la tabla se
	# parte en dos de una sola vez, asi que la despensa tiene que estar junta
	var store := Storehouse.new()
	var seen_raw := false
	for row: Dictionary in store.in_catalogue_order():
		var kind := row["kind"] as Materia.Kind
		if Materia.is_provision(kind):
			assert_false(seen_raw,
				"%s sale entre la materia prima" % Materia.material_name(kind))
		else:
			seen_raw = true
	assert_true(seen_raw, "hay materia prima")


func test_la_grasa_va_con_la_materia_prima_aunque_alimente() -> void:
	# El caso que descubrio la prueba de arriba. `is_food` no puede decidir el
	# estante: la grasa se come Y se quema, y el jugador la busca con la
	# resina y la yesca, no con las bayas.
	assert_true(Materia.is_food(Materia.Kind.GRASA), "alimenta")
	assert_false(Materia.is_provision(Materia.Kind.GRASA),
		"pero se guarda con la materia prima")
	assert_true(Materia.is_provision(Materia.Kind.BAYA),
		"y la baya en la despensa")
