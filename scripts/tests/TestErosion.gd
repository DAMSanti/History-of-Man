class_name TestErosion
extends TestCase
## Pruebas de la erosión hidráulica y térmica sobre el heightmap.
##
## El motivo de que esto exista: el ruido parece ruido. Se le puede dar la
## amplitud y la frecuencia que se quiera y sigue leyéndose como una manta de
## bultos, porque no hay ninguna relación entre un bulto y el de al lado.
##
## El terreno real no es aleatorio: es el resultado de un proceso. El agua cae,
## escurre ladera abajo, arranca material donde va rápida y lo suelta donde se
## frena. Simular eso —aunque sea de forma tosca— produce vaguadas que
## desembocan, conos de deyección al pie de las laderas y crestas afiladas
## entre cuencas, y todo eso es COHERENTE entre sí porque sale del mismo
## proceso que lo produce en la naturaleza.
##
## Lo que se prueba aquí no es que quede bonito, que no es comprobable, sino
## las propiedades que el proceso debe cumplir para ser ese proceso.


func suite_name() -> String:
	return "Erosion"


## Un cerro sobre una llanada, con ruido encima.
##
## La pendiente es fuerte a proposito para que el cono toque el llano DENTRO de
## la rejilla: con una ladera mas tendida no llegaba a cero antes del borde, o
## sea que no habia pie donde depositar, y probar que deposita al pie de una
## ladera que no tiene pie no prueba nada.
func _cone(size: int = 48) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(size * size)
	var centre := float(size) * 0.5
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.09
	for z in range(size):
		for x in range(size):
			var distance := Vector2(float(x) - centre, float(z) - centre).length()
			grid[z * size + x] = maxf(120.0 - distance * 7.0, 0.0) \
				+ noise.get_noise_2d(float(x), float(z)) * 6.0
	return grid


func _total(grid: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in grid:
		sum += v
	return sum


func _roughness(grid: PackedFloat32Array, size: int) -> float:
	# Energía de alta frecuencia: cuánto se despega cada celda de sus vecinas
	var sum := 0.0
	for z in range(1, size - 1):
		for x in range(1, size - 1):
			var i := z * size + x
			sum += absf(grid[i - 1] + grid[i + 1] + grid[i - size] + grid[i + size]
				- 4.0 * grid[i])
	return sum / float((size - 2) * (size - 2))


# --- conservación de materia ----------------------------------------------

func test_la_erosion_mueve_material_no_lo_crea() -> void:
	# La propiedad que separa erosión de ruido: el sedimento que se arranca en
	# un sitio aparece en otro. Si el total sube o baja mucho, no se está
	# transportando nada, se está inventando relieve.
	var size := 48
	var grid := _cone(size)
	var antes := _total(grid)
	Erosion.hydraulic(grid, size, size, 6000, 20260903)
	var despues := _total(grid)

	assert_lt(absf(despues - antes) / maxf(absf(antes), 1.0), 0.06,
		"el volumen total apenas cambia: se transporta, no se inventa")


func test_no_deja_cotas_absurdas() -> void:
	var size := 48
	var grid := _cone(size)
	Erosion.hydraulic(grid, size, size, 6000, 1)
	for v in grid:
		assert_between(v, -30.0, 200.0, "ninguna cota se dispara")


# --- lo que hace el agua ---------------------------------------------------

func test_excava_vaguadas_donde_se_concentra_el_agua() -> void:
	# El agua no baja repartida: converge. Lo que distingue una vaguada de un
	# rebaje uniforme es justo eso, que unas celdas se llevan mucho más que sus
	# vecinas. Por eso no basta con comprobar que la ladera baja: hay que
	# comprobar que baja de forma DESIGUAL.
	var size := 48
	var antes := _cone(size)
	var despues := PackedFloat32Array(antes)
	Erosion.hydraulic(despues, size, size, 12000, 7)

	# Anillo intermedio de la ladera, evitando cumbre y borde
	var centre := float(size) * 0.5
	var deltas: Array[float] = []
	for z in range(size):
		for x in range(size):
			var distance := Vector2(float(x) - centre, float(z) - centre).length()
			if distance < 6.0 or distance > 16.0:
				continue
			deltas.append(despues[z * size + x] - antes[z * size + x])

	assert_gt(float(deltas.size()), 100.0, "el anillo tiene celdas de sobra")

	var media := 0.0
	for d in deltas:
		media += d
	media /= float(deltas.size())
	assert_lt(media, -0.02, "el anillo de ladera pierde material en conjunto")

	# Desviación frente a la media: si el rebaje fuera parejo sería casi cero
	var varianza := 0.0
	var mas_hondo := 0.0
	for d in deltas:
		varianza += (d - media) * (d - media)
		mas_hondo = minf(mas_hondo, d)
	var desviacion := sqrt(varianza / float(deltas.size()))

	# La evidencia directa de que hay surcos es que las celdas mas hondas se
	# llevan MUCHO mas que la media. La desviacion tipica decia lo mismo de
	# forma mas debil y sobre una ladera uniforme se quedaba corta, asi que se
	# afirma lo que de verdad distingue un surco de un cepillado.
	assert_gt(desviacion, 0.0, "el rebaje no es exactamente parejo")
	assert_lt(mas_hondo, media * 2.5,
		"los surcos se llevan al menos dos veces y media la media de la ladera")


func test_deposita_al_pie_de_la_ladera() -> void:
	# El cono de deyección: el agua se frena al llegar al llano y suelta lo que
	# traía. Es la contrapartida de la vaguada, y es lo que hace que el
	# resultado se lea como paisaje y no como una talla.
	var size := 48
	var antes := _cone(size)
	var despues := PackedFloat32Array(antes)
	Erosion.hydraulic(despues, size, size, 12000, 11)

	var centre := float(size) * 0.5
	var alto := 0.0
	var pie := 0.0
	for z in range(size):
		for x in range(size):
			var distance := Vector2(float(x) - centre, float(z) - centre).length()
			var delta: float = despues[z * size + x] - antes[z * size + x]
			if distance < 12.0:
				alto += delta
			elif distance < 26.0:
				pie += delta

	assert_lt(alto, 0.0, "la parte alta pierde material")
	assert_gt(pie, 0.0, "y el pie de la ladera lo gana")


# --- lo que hace la erosion termica ---------------------------------------

func test_la_termica_derrumba_lo_que_pasa_del_angulo_de_reposo() -> void:
	# Un talud de piedra suelta no se sostiene por encima de unos 34 grados: se
	# derrumba solo. Eso es lo que quita las paredes verticales que deja el
	# agua y las convierte en canchales.
	#
	# El escalon tiene que CABER en la rejilla: a talud 1.0 hacen falta tantas
	# celdas de recorrido como metros de altura tenga, asi que uno de 40 m
	# sobre 24 celdas es geometricamente imposible de tumbar y probarlo seria
	# exigir lo que no puede pasar.
	var size := 24
	var grid := PackedFloat32Array()
	grid.resize(size * size)
	for z in range(size):
		for x in range(size):
			grid[z * size + x] = 8.0 if x < size / 2 else 0.0

	Erosion.thermal(grid, size, size, 120, 1.0, 1.0)

	var salto := 0.0
	for z in range(size):
		for x in range(1, size):
			salto = maxf(salto, absf(grid[z * size + x] - grid[z * size + x - 1]))
	assert_lt(salto, 2.5, "el escalon vertical se ha derrumbado en talud")


func test_la_termica_tampoco_crea_material() -> void:
	var size := 24
	var grid := PackedFloat32Array()
	grid.resize(size * size)
	for z in range(size):
		for x in range(size):
			grid[z * size + x] = 8.0 if x < size / 2 else 0.0
	var antes := _total(grid)
	Erosion.thermal(grid, size, size, 120, 1.0, 1.0)
	assert_near(_total(grid), antes, absf(antes) * 0.02,
		"el derrumbe reparte material, no lo crea")


func test_la_termica_no_toca_lo_que_ya_esta_tumbado() -> void:
	# Una ladera suave ya está en reposo: la térmica no tiene nada que hacer
	# ahi, y si la alisara estaria borrando relieve legitimo.
	var size := 24
	var grid := PackedFloat32Array()
	grid.resize(size * size)
	for z in range(size):
		for x in range(size):
			grid[z * size + x] = float(x) * 0.2
	var antes := PackedFloat32Array(grid)
	Erosion.thermal(grid, size, size, 40, 1.0, 0.6)

	var peor := 0.0
	for i in range(grid.size()):
		peor = maxf(peor, absf(grid[i] - antes[i]))
	assert_lt(peor, 0.01, "una ladera en reposo se queda como esta")


# --- que el resultado sea terreno y no ruido -------------------------------

func test_la_termica_recoge_lo_que_deja_afilado_el_agua() -> void:
	# Aqui habia una prueba que afirmaba que la erosion deja el terreno mas
	# liso que el ruido de partida. Es FALSO, y medirlo lo dejo claro: el agua
	# excava canales estrechos y sube la aspereza de celda de 1,33 a 2,76.
	# Tenia que ser asi: una carcava es afilada.
	#
	# Lo que si es cierto, y es el motivo de que la termica exista en el
	# proceso, es que ella recoge esa aspereza. El agua talla y la gravedad
	# tumba lo que queda demasiado vertical.
	var size := 48
	var solo_agua := _cone(size)
	Erosion.hydraulic(solo_agua, size, size, 12000, 3)

	# El angulo de reposo tiene que estar POR ENCIMA de la pendiente general
	# del cerro, o la termica no recoge aristas: demuele la ladera entera. Este
	# cono cae 7 m por celda, asi que con talud 0,5 todas y cada una de sus
	# celdas pasaban del limite.
	var con_gravedad := PackedFloat32Array(solo_agua)
	Erosion.thermal(con_gravedad, size, size, 30, 1.0, 9.0)

	assert_lt(_roughness(con_gravedad, size), _roughness(solo_agua, size),
		"la termica tumba las aristas que deja el agua")


# --- erosion a resolucion reducida ----------------------------------------

func test_a_resolucion_reducida_tambien_conserva_materia() -> void:
	var size := 48
	var grid := _cone(size)
	var antes := _total(grid)
	Erosion.erode_coarse(grid, size, size, 8000, 6, 1.0, 1.0, 5, 2)
	assert_lt(absf(_total(grid) - antes) / maxf(absf(antes), 1.0), 0.06,
		"trabajar en grueso sigue transportando, no inventando")


func test_a_resolucion_reducida_conserva_el_detalle_fino() -> void:
	# Es la razon de ser del metodo: se devuelve la DIFERENCIA y no el
	# resultado, de modo que el detalle medido del MDT no se cambia por una
	# version suavizada de si mismo. Se comprueba viendo que lo que se le suma
	# al terreno es SUAVE: si trajera detalle de celda, estaria pisando el que
	# ya habia.
	var size := 48
	var antes := _cone(size)
	var despues := PackedFloat32Array(antes)
	Erosion.erode_coarse(despues, size, size, 8000, 6, 1.0, 1.0, 5, 2)

	var aporte := PackedFloat32Array()
	aporte.resize(antes.size())
	for i in range(antes.size()):
		aporte[i] = despues[i] - antes[i]

	assert_lt(_roughness(aporte, size), _roughness(antes, size) * 0.5,
		"lo que aporta la erosion es relieve de ladera, no ruido de celda")


func test_a_resolucion_reducida_si_cambia_el_terreno() -> void:
	# La contrapartida de la prueba anterior: que sea suave no puede
	# significar que no haga nada.
	var size := 48
	var antes := _cone(size)
	var despues := PackedFloat32Array(antes)
	Erosion.erode_coarse(despues, size, size, 8000, 6, 1.0, 1.0, 5, 2)

	var mayor := 0.0
	for i in range(antes.size()):
		mayor = maxf(mayor, absf(despues[i] - antes[i]))
	assert_gt(mayor, 1.0, "la erosion mueve metros, no centimetros")


func test_sin_gotas_no_pasa_nada() -> void:
	var size := 24
	var grid := _cone(size)
	var antes := PackedFloat32Array(grid)
	Erosion.hydraulic(grid, size, size, 0, 1)
	for i in range(grid.size()):
		assert_near(grid[i], antes[i], 0.0001, "sin lluvia no hay erosion")


func test_es_reproducible_con_la_misma_semilla() -> void:
	# Hace falta para poder bakear el recuadro: si cada partida erosionara
	# distinto, el mapa guardado no coincidiria con el regenerado.
	var size := 32
	var a := _cone(size)
	var b := PackedFloat32Array(a)
	Erosion.hydraulic(a, size, size, 3000, 99)
	Erosion.hydraulic(b, size, size, 3000, 99)
	var peor := 0.0
	for i in range(a.size()):
		peor = maxf(peor, absf(a[i] - b[i]))
	assert_lt(peor, 0.0001, "la misma semilla da el mismo terreno")
