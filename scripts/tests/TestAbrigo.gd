class_name TestAbrigo
extends TestCase
## Lo que ofrece la ventana de un abrigo.
##
## Decisión del usuario del 2026-09-13: el abrigo donde vive la banda ya es su
## taller, así que no hay botón para ello; y a la cueva propia no se muda nadie.


func suite_name() -> String:
	return "Abrigo"


func _ids(acciones: Array) -> Array:
	var ids: Array = []
	for accion: Array in acciones:
		ids.append(accion[0])
	return ids


func test_ningun_abrigo_ofrece_hacerse_taller() -> void:
	for de_la_banda: bool in [true, false]:
		assert_false("taller" in _ids(PanelSitios._actions_for(
			Site.Feature.ABRIGO, de_la_banda)),
			"el taller es el abrigo donde se vive, sin botón")


func test_la_cueva_de_la_banda_no_ofrece_mudarse() -> void:
	assert_false("ocupar" in _ids(PanelSitios._actions_for(Site.Feature.ABRIGO, true)),
		"en la suya no hay adónde trasladarse")


func test_una_cueva_libre_si_ofrece_mudarse() -> void:
	var ids := _ids(PanelSitios._actions_for(Site.Feature.ABRIGO, false))
	assert_true("ocupar" in ids, "a una cueva no habitada sí")
	assert_true("explorar" in ids, "y se puede explorar")


func test_explorar_dice_por_que_no_se_puede() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.store = Storehouse.new()
	sim.toolkit = Toolkit.new()
	var datos := {"cueva": 2}
	assert_eq(PanelSitios.por_que_no("explorar", datos, sim),
		"hace falta una lámpara de grasa", "sin lámpara el botón lo dice")
	sim.toolkit.add(Tool.make(Tool.Kind.LAMPARA, Tool.default_stuff(Tool.Kind.LAMPARA)))
	assert_eq(PanelSitios.por_que_no("explorar", datos, sim),
		"hace falta grasa para la lámpara", "y luego la grasa")


func test_pintar_no_se_apaga_desde_la_ventana() -> void:
	var sim := SettlementSim.new()
	sim.store = Storehouse.new()
	assert_eq(PanelSitios.por_que_no("pintar", {"cueva": 2}, sim), "",
		"pintar lo dice su propia tarjeta")


func _tiene(acciones: Array, id: String) -> bool:
	return id in _ids(acciones)


func test_pintar_solo_en_cueva_explorada_y_con_pared() -> void:
	# Petición del usuario del 2026-09-14: «la opción de pintar la pared del
	# fondo sólo aparece en las cuevas exploradas» —y con pared pintable, que es
	# lo que la exploración averigua—. Salía en todas, sin mirar nada.
	assert_false(_tiene(PanelSitios._actions_for(Site.Feature.ABRIGO, false, false, false),
		"pintar"), "sin explorar no se sabe si hay pared")
	assert_false(_tiene(PanelSitios._actions_for(Site.Feature.ABRIGO, false, true, false),
		"pintar"), "explorada y sin zona pintable, tampoco")
	assert_true(_tiene(PanelSitios._actions_for(Site.Feature.ABRIGO, false, true, true),
		"pintar"), "explorada y con pared, sí")
