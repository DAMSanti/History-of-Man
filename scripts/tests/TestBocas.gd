class_name TestBocas
extends TestCase
## Ninguna boca de cueva en el agua ni donde no se llega desde casa.
##
## Frente 21 de EPOCA_01 §10.1, tanda 4. El terreno de mentira es [FakeTerrain]:
## una meseta con un río infranqueable de este a oeste en z ∈ (1460, 1540), así
## que al norte del río no se llega. Casa, al sur.


func suite_name() -> String:
	return "Bocas"


const CASA := Vector3(500.0, 0.0, 500.0)


func _colocar(donde: Vector3) -> Dictionary:
	var pedidas: Array[Dictionary] = [{"position": donde, "radius": 13.0,
		"depth": 9.0, "feature": 3}]
	return Bocas.colocar(FakeTerrain.new(), pedidas, CASA)[0]


func test_una_boca_buena_no_se_mueve() -> void:
	var boca := _colocar(Vector3(700.0, 0.0, 700.0))
	assert_eq(float(boca["movida_m"]), 0.0, "en seco y a mano, se queda")
	assert_eq(int(boca["feature"]), 3, "y sigue sabiendo de qué elemento es")


func test_una_boca_en_el_rio_sale_a_la_orilla_de_casa() -> void:
	var boca := _colocar(Vector3(500.0, 0.0, 1480.0))
	var queda: Vector3 = boca["position"]
	assert_false(FakeTerrain.in_river(queda), "fuera del agua")
	assert_lt(queda.z, FakeTerrain.RIVER_Z, "y en la orilla a la que se llega")
	assert_lt(float(boca["movida_m"]), 60.0,
		"a la orilla más cercana, no a la otra punta del mapa")


func test_una_boca_al_otro_lado_del_rio_se_trae_a_donde_se_llega() -> void:
	var boca := _colocar(Vector3(500.0, 0.0, 1700.0))
	var queda: Vector3 = boca["position"]
	assert_lt(queda.z, FakeTerrain.RIVER_Z - FakeTerrain.RIVER_HALF,
		"al norte del río no se llega: se trae a la orilla de casa")
	assert_gt(float(boca["movida_m"]), 200.0, "y se dice cuánto se movió")
	assert_eq(boca["desde"], Vector3(500.0, 0.0, 1700.0),
		"con lo que pedía el catálogo")


func test_la_entalladura_entera_queda_en_seco() -> void:
	# A dos metros del río el centro está seco, pero un hueco de 13 m de radio
	# se mete en el agua.
	var boca := _colocar(Vector3(500.0, 0.0, 1458.0))
	var queda: Vector3 = boca["position"]
	assert_lt(queda.z, FakeTerrain.RIVER_Z - FakeTerrain.RIVER_HALF - 13.0 * Bocas.ORILLA + 0.5,
		"el corro que se excava, con su margen, no toca el agua")


## Una charca redonda con ladera al oeste y vega llana al este. Las dos orillas
## se andan: lo único que las distingue es la cuesta.
class CharcaEnLaLadera extends TerrainGenerator:
	const CENTRO := Vector3(800.0, 0.0, 800.0)
	const RADIO := 50.0

	func _init() -> void:
		terrain_size = Vector2i(1600, 1600)

	func get_height_at(p: Vector3) -> float:
		return 100.0 + maxf(0.0, CENTRO.x - p.x) * 0.3

	func get_slope_at(p: Vector3) -> float:
		return 0.3 if p.x < CENTRO.x else 0.0

	func crossing_difficulty_at(p: Vector3) -> float:
		return 1.0 if Vector2(p.x - CENTRO.x, p.z - CENTRO.z).length() < RADIO else 0.0

	func crossing_difficulty_with(p: Vector3, _caudal: float = 1.0) -> float:
		return crossing_difficulty_at(p)


func test_la_boca_sumergida_sale_por_la_orilla_con_pendiente() -> void:
	# Decisión del usuario (2026-09-13): hacia la ladera, no hacia el llano. La
	# boca pedida está un poco al este del centro, así que la orilla llana queda
	# MÁS CERCA: a secas, ganaba ella.
	var pedida := CharcaEnLaLadera.CENTRO + Vector3(15.0, 0.0, 0.0)
	var pedidas: Array[Dictionary] = [{"position": pedida, "radius": 0.0}]
	var casa := Vector3(1300.0, 0.0, 800.0)
	var boca: Dictionary = Bocas.colocar(CharcaEnLaLadera.new(), pedidas, casa)[0]
	var queda: Vector3 = boca["position"]
	assert_lt(queda.x, CharcaEnLaLadera.CENTRO.x, "sale por la ladera del oeste")
	assert_lt(float(boca["movida_m"]), 120.0, "y no se va a buscarla lejos")


func test_el_terreno_excava_donde_queda_la_boca() -> void:
	# La entalladura va con la boca: si se excavara donde decía el catálogo, el
	# hueco quedaría en el río y la cueva, en seco sin hueco.
	var terreno := FakeTerrain.new()
	terreno.carvings.append({"position": Vector3(500.0, 0.0, 1700.0),
		"radius": 13.0, "depth": 9.0, "feature": 0})
	terreno.colocar_las_bocas = func(t: TerrainGenerator) -> Array[Dictionary]:
		return Bocas.colocar(t, t.carvings, CASA)
	terreno.carvings_colocadas.assign(terreno.colocar_las_bocas.call(terreno))
	var queda: Vector3 = terreno.carvings_colocadas[0]["position"]
	assert_lt(queda.z, FakeTerrain.RIVER_Z, "lo que se excava es lo colocado")
	assert_eq(terreno.carvings[0]["position"], Vector3(500.0, 0.0, 1700.0),
		"y lo pedido no se toca: de ahí sale la clave de la caché")
