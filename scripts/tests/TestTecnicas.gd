class_name TestTecnicas
extends TestCase
## Qué dice el árbol que da cada técnica, y qué supone hoy para la banda.
##
## El tooltip decía qué es una técnica, cuánto falta y de qué cuelga, pero no
## qué cambia al tenerla: se elegía hacia dónde practicar a ciegas (INTERFAZ
## §10, spec del 2026-09-15).
##
## **Lo que se comprueba es el TEXTO que compone [TechTree.efecto], no los
## píxeles**: la ventana sólo lo pinta. Y se comprueba contra las mismas tablas
## de las que la partida saca la cifra —[Trap.INFO], [Hunting.MEJORAS],
## [Fishing.CATALOGUE], [Tool.recipe]—, que es lo único que distingue «lo lee
## del juego» de «alguien escribió 1,60 a mano y ya no es verdad».


func suite_name() -> String:
	return "Tecnicas"


func _texto(tech: TechTree.Tech) -> String:
	return "\n".join(TechTree.efecto(tech))


# --------------------------------------------- todas dicen para qué sirven

func test_las_dieciocho_tecnicas_dicen_que_dan() -> void:
	# Aprendidas o no: las que faltan dicen qué DARÁN, que es lo que ayuda a
	# decidir hacia dónde practicar (decisión del usuario del 2026-09-15).
	var sin_efecto: Array[String] = []
	for tech: int in TechTree.Tech.values():
		if TechTree.efecto(tech as TechTree.Tech).is_empty():
			sin_efecto.append(TechTree.tech_name(tech as TechTree.Tech))
	assert_eq(TechTree.Tech.values().size(), 18, "son dieciocho técnicas")
	assert_true(sin_efecto.is_empty(),
		"todas dicen qué dan; se callan: %s" % ", ".join(sin_efecto))


func test_ninguna_linea_sale_vacia_ni_a_medio_escribir() -> void:
	for tech: int in TechTree.Tech.values():
		for linea: String in TechTree.efecto(tech as TechTree.Tech):
			assert_true(linea.strip_edges().length() > 10,
				"%s: una línea con algo dentro" % TechTree.tech_name(
					tech as TechTree.Tech))


# ------------------------------------- y la cifra es la que usa la partida

func test_la_caza_dice_el_factor_de_la_tabla_de_mejoras() -> void:
	# La azagaya multiplica la caza mayor por lo que diga [Hunting.MEJORAS]. Si
	# esa tabla cambia, esto cambia con ella.
	var mayor: Array = Hunting.MEJORAS[Profession.Speciality.CAZA_MAYOR]
	var factor := 0.0
	for mejora: Dictionary in mayor:
		if int(mejora["tech"]) == int(TechTree.Tech.AZAGAYA):
			factor = float(mejora["factor"])
	assert_true(factor > 0.0, "la azagaya está en la tabla")
	assert_true(_texto(TechTree.Tech.AZAGAYA).contains(
		String.num(factor, 2).pad_decimals(2).replace(".", ",")),
		"y el tooltip dice ese mismo factor")


func test_la_pesca_dice_lo_que_saca_la_tabla_de_maneras() -> void:
	var ficha: Dictionary = Fishing.CATALOGUE[Fishing.Method.ARPON]
	var saca := int(float((ficha["yields"] as Dictionary)[Materia.Kind.PESCADO]))
	assert_true(_texto(TechTree.Tech.ARPON).contains("%d de pescado" % saca),
		"el arpón dice lo que da de verdad")


func test_la_trampa_dice_cada_cuanto_cobra_una_pieza() -> void:
	var info: Dictionary = Trap.INFO[Trap.Kind.FOSO]
	assert_true(_texto(TechTree.Tech.FOSO).contains(
		String.num(float(info["cada"]), 1).replace(".", ",")),
		"el foso dice sus jornadas por pieza")
	for presa: String in (info["caza"] as Array):
		assert_true(_texto(TechTree.Tech.FOSO).contains(
			Fauna.species_name(presa).to_lower()),
			"y qué cae en él: %s" % presa)


func test_el_taller_dice_el_suelo_del_nucleo_y_la_mitad_de_la_laminar() -> void:
	assert_true(_texto(TechTree.Tech.NUCLEO).contains(
		String.num(Tool.CALIDAD_CON_NUCLEO, 2).pad_decimals(2).replace(".", ",")),
		"el núcleo dice su calidad mínima")
	var suelta := float(Tool.recipe(Tool.Kind.LASCA)[Materia.Kind.PIEDRA])
	var con_hoja := suelta * Tool.AHORRO_LAMINAR
	assert_true(_texto(TechTree.Tech.HOJA).contains(
		String.num(con_hoja, 1).replace(".", ",")),
		"y la laminar, lo que cuesta una pieza con ella")


func test_la_obra_dice_lo_que_salva_y_lo_que_cuesta() -> void:
	var texto := _texto(TechTree.Tech.PASARELA)
	assert_true(texto.contains("%d m" % int(
		Pasarelas.CELDAS_DE_ANCHO * Navgrid.CELL)), "cuánto cauce salva")
	assert_true(texto.contains("%d de leña" % int(Pasarelas.LENA)),
		"y lo que cuesta de leña")


func test_cada_tecnica_dice_a_cuales_abre_el_paso() -> void:
	# La otra mitad de «qué gano»: el núcleo preparado no cambia gran cosa por
	# sí solo, pero es la puerta de la talla laminar.
	assert_true(_texto(TechTree.Tech.NUCLEO).to_lower().contains(
		TechTree.tech_name(TechTree.Tech.HOJA).to_lower()),
		"el núcleo abre la talla laminar")
	assert_true(TechTree.abre(TechTree.Tech.ARPON).is_empty(),
		"y la cumbre de la pesca no abre ninguna")


# ------------------------------------------------------ y lo de hoy, de hoy

func _sim() -> SettlementSim:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.techs = TechTree.new()
	return sim


func test_lo_de_hoy_solo_sale_en_las_que_ya_se_saben() -> void:
	var sim := _sim()
	assert_eq(TechTree.lo_de_hoy(TechTree.Tech.PASARELA, sim), "",
		"sin saberla no hay «lo de hoy»")
	sim.techs.known[TechTree.Tech.PASARELA] = true
	assert_true(TechTree.lo_de_hoy(TechTree.Tech.PASARELA, sim).contains("0"),
		"sabida y sin ninguna armada, dice cero")
	sim.pasarelas.levantar([Vector3(20.0, 0.0, 20.0)], 5)
	assert_true(TechTree.lo_de_hoy(TechTree.Tech.PASARELA, sim).contains(
		"1 pasarelas"), "y con una armada, una")
	sim.free()


func test_lo_de_hoy_cuenta_las_trampas_puestas() -> void:
	var sim := _sim()
	sim.techs.known[TechTree.Tech.LAZO] = true
	sim.trampas.traps.append(Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1))
	sim.trampas.traps.append(Trap.create(Trap.Kind.LAZO, Vector3.ONE, 1))
	sim.trampas.traps.append(Trap.create(Trap.Kind.FOSO, Vector3.ZERO, 1))
	assert_true(TechTree.lo_de_hoy(TechTree.Tech.LAZO, sim).contains("2 lazo"),
		"cuenta los lazos y no los fosos")
	sim.free()


func test_lo_de_hoy_cuenta_las_piezas_del_utillaje() -> void:
	var sim := _sim()
	sim.techs.known[TechTree.Tech.AZAGAYA] = true
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.5)
	sim.toolkit.craft(Tool.Kind.AZAGAYA, Tool.Stuff.ASTA, 0.5)
	assert_true(TechTree.lo_de_hoy(TechTree.Tech.AZAGAYA, sim).contains("2 azagaya"),
		"dice cuántas azagayas hay")
	sim.free()


func test_lo_de_hoy_de_la_laminar_dice_para_cuantas_piezas_da_el_abrigo() -> void:
	var sim := _sim()
	sim.techs.known[TechTree.Tech.HOJA] = true
	sim.store.add(Materia.Kind.PIEDRA, 10.0)
	# Con la laminar, media piedra por pieza: diez de piedra dan veinte.
	assert_true(TechTree.lo_de_hoy(TechTree.Tech.HOJA, sim).contains("20 piezas"),
		"la cuenta sale de la receta que la banda sabe")
	sim.free()
