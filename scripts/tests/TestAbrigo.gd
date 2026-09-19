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


## LA ACCIÓN «pintar» YA NO EXISTE (2026-09-19): era un segundo botón que hacía lo mismo
## que «entrar», abrir la sala, desde que el botón de pintar se mudó dentro de ella.
func test_pintar_ya_no_es_una_accion_de_la_ficha() -> void:
	var sim := SettlementSim.new()
	sim.store = Storehouse.new()
	assert_eq(PanelSitios.por_que_no("pintar", {"cueva": 2}, sim), "",
		"una acción que no existe no tiene motivo que dar")
	for pintable: bool in [true, false]:
		assert_false(_tiene(PanelSitios._actions_for(Site.Feature.ABRIGO, false, true,
			pintable), "pintar"), "no hay acción «pintar» en la ficha")


func _tiene(acciones: Array, id: String) -> bool:
	return id in _ids(acciones)


## UN SOLO BOTÓN PARA EL FONDO, y sale en toda cueva (2026-09-19).
##
## Antes eran dos: «pintar la pared del fondo» —sólo en cuevas exploradas y con pared, a
## petición del usuario del 2026-09-14— y «entrar a mirar», en todas. Desde que pintar se
## hace **dentro** de la sala, los dos abrían la sala y el usuario lo vio: «hacen lo mismo,
## sustitúyelos por Entrar al fondo de la cueva». Así que la condición de «con pared
## pintable» deja de decidir si hay botón: decide si dentro se puede pintar, que es donde
## se pregunta ahora.
func test_el_fondo_de_la_cueva_es_un_solo_boton() -> void:
	for explorada: bool in [true, false]:
		for pintable: bool in [true, false]:
			var acciones := PanelSitios._actions_for(Site.Feature.ABRIGO, false,
				explorada, pintable)
			assert_true(_tiene(acciones, "entrar"),
				"el botón del fondo sale siempre (explorada %s, pintable %s)"
					% [explorada, pintable])
			assert_false(_tiene(acciones, "pintar"), "y no hay un segundo botón")
	# Y se llama por lo que hace.
	for accion: Array in PanelSitios._actions_for(Site.Feature.ABRIGO, false, true, true):
		if String(accion[0]) == "entrar":
			assert_true(String(accion[1]).contains("fondo de la cueva"),
				"el rótulo dice adónde lleva: %s" % String(accion[1]))
