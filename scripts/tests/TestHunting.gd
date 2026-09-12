class_name TestHunting
extends TestCase
## La caza: el despiece por especie, las trampas y la mejora por técnica.


func suite_name() -> String:
	return "Caza"


func _techs(learned: Array) -> TechTree:
	var techs := TechTree.new()
	for t: int in learned:
		techs.known[t as TechTree.Tech] = true
	return techs


# --- el despiece sale de la PIEZA ----------------------------------------

func test_las_aves_dan_pluma_y_no_piel() -> void:
	# Petición literal: «en caso por ejemplo de caza de pájaros no darán piel,
	# sino que darán plumas».
	for ave: String in ["urogallo", "perdiz", "anade"]:
		var spoils := Fauna.spoils_of(ave)
		assert_true(spoils.has(Materia.Kind.PLUMA),
			"%s da pluma" % Fauna.species_name(ave))
		assert_false(spoils.has(Materia.Kind.PIEL),
			"%s NO da piel: se despluma, no se despelleja"
				% Fauna.species_name(ave))


func test_la_pieza_mayor_da_tendon_y_la_menuda_casi_no() -> void:
	# El tendón sale del tren posterior de una res grande. De un conejo no se
	# saca un tendón para atar una azagaya.
	assert_true(float(Fauna.spoils_of("ciervo").get(Materia.Kind.TENDON, 0.0))
		> float(Fauna.spoils_of("liebre").get(Materia.Kind.TENDON, 0.0)) * 5.0,
		"un ciervo da muchísimo más tendón que una liebre")
	assert_false(Fauna.spoils_of("conejo").has(Materia.Kind.TENDON),
		"de un conejo no se saca tendón que valga")


func test_el_jabali_no_da_asta_y_el_ciervo_si() -> void:
	assert_false(Fauna.spoils_of("jabali").has(Materia.Kind.ASTA),
		"un jabalí no tiene cuerna")
	assert_true(Fauna.spoils_of("ciervo").has(Materia.Kind.ASTA),
		"un ciervo sí")


func test_toda_especie_tiene_carne_despiece_y_porte() -> void:
	for species: String in Fauna.SPECIES:
		assert_true(Fauna.rations_of(species) > 0.0,
			"%s da carne" % species)
		assert_false(Fauna.spoils_of(species).is_empty(),
			"%s se despieza en algo" % species)
		assert_true(Fauna.porte_of(species) >= Fauna.Porte.MENUDA
			and Fauna.porte_of(species) <= Fauna.Porte.MAYOR,
			"%s tiene porte" % species)


func test_todas_las_estaciones_traen_pieza_mayor() -> void:
	# Sin esto, una cuadrilla de caza mayor se pasaba tres estaciones de cada
	# cuatro topándose conejos. La estacionalidad de la caza mayor está en el
	# RENDIMIENTO, no en que el animal desaparezca del monte: un ciervo en
	# marzo está flaco, no ausente.
	for season: int in Fauna.BY_SEASON:
		var mayores := 0
		for species: String in (Fauna.BY_SEASON[season] as Array):
			if Fauna.porte_of(species) == Fauna.Porte.MAYOR:
				mayores += 1
		assert_true(mayores >= 2,
			"en %s hay pieza mayor que cazar (%d)" % [
				Subsistence.season_name(season as Subsistence.Season), mayores])


# --- se caza lo que hay, hasta el porte de uno ---------------------------

func test_el_batidor_coge_lo_pequeno_pero_el_menor_no_coge_un_uro() -> void:
	# Hacia ABAJO sí, hacia arriba no: un batidor que se topa un corzo lo
	# mata; uno de caza menor que se topa un uro lo deja pasar, porque con
	# azagaya de mano no se mata un uro, se muere uno.
	var techs := _techs([])
	var punto := _punto_con("uro")
	assert_false(punto == Vector3.INF, "hay algún sitio con uro en otoño")

	var mayor := Hunting.yields_at(Profession.Speciality.CAZA_MAYOR, punto,
		Subsistence.Season.OTONO, techs)
	var menor := Hunting.yields_at(Profession.Speciality.CAZA_MENOR, punto,
		Subsistence.Season.OTONO, techs)
	assert_true(float(mayor.get(Materia.Kind.CARNE, 0.0))
		> float(menor.get(Materia.Kind.CARNE, 0.0)),
		"el batidor saca más de un sitio con uro que el de pieza menor")


func _punto_con(species: String) -> Vector3:
	for i in range(400):
		var point := Vector3(float(i) * 37.0, 0.0, float(i) * 61.0)
		if Fauna.species_at(point, Subsistence.Season.OTONO).has(species):
			return point
	return Vector3.INF


# --- con qué se le entra a cada pieza -------------------------------------
#
# «No vamos a cazar un bisonte o un lobo con las manos vacías». Es una PUERTA
# y no una penalización: media pieza de uro sin azagaya no es media pieza, es
# una cuadrilla que vuelve corriendo.

func _utillaje(kinds: Array) -> Toolkit:
	var kit := Toolkit.new()
	for kind: int in kinds:
		kit.craft(kind as Tool.Kind, Tool.default_stuff(kind as Tool.Kind), 0.6)
	return kit


func test_la_pieza_menuda_se_coge_con_las_manos() -> void:
	# Un conejo se coge con un lazo y un palo, y por eso la banda del primer
	# día come algo en vez de nada.
	for humilde: String in ["conejo", "liebre", "perdiz", "anade", "urogallo"]:
		assert_true(Fauna.unarmed(humilde),
			"%s no pide arma" % Fauna.species_name(humilde))
		assert_true(Fauna.huntable_with(humilde, Toolkit.new()),
			"%s se caza con el zurrón vacío" % Fauna.species_name(humilde))


func test_al_uro_y_al_lobo_no_se_les_entra_con_las_manos_vacias() -> void:
	# La petición, literal.
	var pelado := Toolkit.new()
	for grande: String in ["uro", "caballo", "ciervo", "jabali", "lobo"]:
		assert_false(Fauna.huntable_with(grande, pelado),
			"a %s no se le entra con las manos vacías"
				% Fauna.species_name(grande))
		assert_true(Fauna.huntable_with(grande,
			_utillaje([Tool.Kind.AZAGAYA])),
			"con azagaya sí" % [])


func test_la_lanza_de_mano_vale_para_el_corzo_pero_no_para_el_uro() -> void:
	# Una punta lítica enmangada es muchísimo más vieja que la azagaya de asta,
	# y da para un corzo. No da para un uro.
	var lanza := _utillaje([Tool.Kind.PUNTA])
	assert_true(Fauna.huntable_with("corzo", lanza),
		"al corzo se le entra con lanza de mano")
	assert_false(Fauna.huntable_with("uro", lanza),
		"al uro no")


func test_sin_azagaya_el_cotarro_de_uros_no_rinde_nada() -> void:
	var punto := _punto_con("uro")
	assert_false(punto == Vector3.INF, "hay algún sitio con uro en otoño")
	var techs := _techs([])

	var pelado := Hunting.rations_at(Profession.Speciality.CAZA_MAYOR, punto,
		Subsistence.Season.OTONO, techs, Toolkit.new())
	var armado := Hunting.rations_at(Profession.Speciality.CAZA_MAYOR, punto,
		Subsistence.Season.OTONO, techs, _utillaje([Tool.Kind.AZAGAYA]))
	assert_gt(armado, pelado,
		"el mismo sitio vale muchísimo más con azagaya en el abrigo")


func test_lo_que_no_se_puede_cazar_no_cuesta_riesgo() -> void:
	# Sin esto una banda desarmada se llevaba las cornadas de una caza que no
	# estaba haciendo.
	var punto := _punto_con("uro")
	assert_false(punto == Vector3.INF, "hay algún sitio con uro en otoño")
	var pelado := Hunting.risk_at(Profession.Speciality.CAZA_MAYOR, punto,
		Subsistence.Season.OTONO, 1, Toolkit.new())
	var armado := Hunting.risk_at(Profession.Speciality.CAZA_MAYOR, punto,
		Subsistence.Season.OTONO, 1, _utillaje([Tool.Kind.AZAGAYA]))
	assert_lt(pelado, armado,
		"al uro que se ve pasar no te cornea")


func test_se_dice_lo_que_se_ve_pasar_y_por_que() -> void:
	# Cerrar la puerta en silencio es la peor versión de sí misma.
	var punto := _punto_con("uro")
	assert_false(punto == Vector3.INF, "hay algún sitio con uro en otoño")
	var texto := Hunting.out_of_reach_text(Profession.Speciality.CAZA_MAYOR,
		punto, Subsistence.Season.OTONO, Toolkit.new())
	assert_true(texto.contains("uro"), "dice qué se escapa: %s" % texto)
	assert_true(texto.contains("azagaya"), "y qué falta: %s" % texto)
	assert_eq(Hunting.out_of_reach_text(Profession.Speciality.CAZA_MAYOR,
		punto, Subsistence.Season.OTONO, _utillaje([Tool.Kind.AZAGAYA])), "",
		"con la azagaya no hay nada que lamentar")


func test_sin_utillaje_la_puerta_no_cierra() -> void:
	# Las pruebas y el rato antes de montar el utillaje: se responde que sí a
	# todo, igual que hacen ya Fishing y TechTree con el árbol a null.
	assert_true(Fauna.huntable_with("uro", null),
		"sin nada con que cerrarla, la puerta se queda abierta")


func test_la_trampa_se_salta_la_puerta_del_arma() -> void:
	# Un foso coge un jabalí sin que nadie le tenga que entrar, y ÉSA es su
	# razón de ser. Si el foso pidiera azagaya, no serviría para nada.
	assert_true(Trap.catches(Trap.Kind.FOSO).has("jabali"),
		"el foso coge jabalí")
	assert_false(Fauna.unarmed("jabali"),
		"y al jabalí, a mano, no se le entra")


# --- la técnica se nota ---------------------------------------------------

func test_cada_tecnica_de_caza_sube_lo_que_se_cobra() -> void:
	# Petición literal: «deben ir mejorando la técnica a medida que cazan más».
	var pelado := _techs([])
	var previous := Hunting.pieces_per_day(Profession.Speciality.CAZA_MAYOR, pelado)
	var learned: Array = []
	for entry: Dictionary in (Hunting.MEJORAS[
			Profession.Speciality.CAZA_MAYOR] as Array):
		learned.append(entry["tech"])
		var now := Hunting.pieces_per_day(Profession.Speciality.CAZA_MAYOR,
			_techs(learned))
		assert_true(now > previous,
			"%s sube lo que cobra una cuadrilla (%.2f sobre %.2f)" % [
				TechTree.tech_name(entry["tech"] as TechTree.Tech), now, previous])
		previous = now


func test_sin_arbol_de_tecnicas_se_caza_igual_pero_a_secas() -> void:
	assert_true(Hunting.pieces_per_day(Profession.Speciality.CAZA_MENOR, null)
		> 0.0, "sin saber nada se caza, mal pero se caza")


func test_las_tecnicas_de_caza_salen_de_cazar() -> void:
	for tech_key: int in [TechTree.Tech.LAZO, TechTree.Tech.CEPO,
			TechTree.Tech.RED_AVES, TechTree.Tech.FOSO, TechTree.Tech.OJEO,
			TechTree.Tech.AZAGAYA, TechTree.Tech.PROPULSOR, TechTree.Tech.ARCO]:
		# Se pregunta a `job_of`, que lee [TechTree.BRANCHES]. Esta prueba
		# miraba una clave "practice" del catalogo que dejo de existir cuando
		# el oficio paso a salir de la rama, asi que reventaba antes de su
		# primer assert y se contaba como que pasaba. Una prueba que no llega
		# a comprobar nada no falla: por eso hay que mirar tambien el total de
		# comprobaciones y no solo el verde.
		assert_eq(TechTree.job_of(tech_key as TechTree.Tech),
			int(Profession.Job.CAZA),
			"%s se aprende cazando" % TechTree.tech_name(tech_key as TechTree.Tech))


# --- las trampas ----------------------------------------------------------

func test_cada_trampa_coge_lo_suyo_y_cuesta_lo_suyo() -> void:
	# Petición literal: «puede haber trampas de varios tipos para diferentes
	# animales».
	for kind: int in Trap.INFO:
		var trap_kind := kind as Trap.Kind
		assert_false(Trap.catches(trap_kind).is_empty(),
			"%s coge algo" % Trap.trap_name(trap_kind))
		assert_false(Trap.materials(trap_kind).is_empty(),
			"%s se construye con algo" % Trap.trap_name(trap_kind))
		assert_true(Trap.labor_days(trap_kind) > 0.0,
			"%s cuesta jornadas de armar" % Trap.trap_name(trap_kind))
		assert_true(Trap.lifespan(trap_kind) > 0.0,
			"%s se acaba echando a perder" % Trap.trap_name(trap_kind))
		for species: String in Trap.catches(trap_kind):
			assert_true(Fauna.SPECIES.has(species),
				"«%s» existe en el catálogo" % species)


func test_solo_el_foso_coge_pieza_mayor() -> void:
	# Un lazo de fibra no sujeta a un jabalí y una losa no cae sobre un
	# ciervo. Es lo que hace que el foso valga las tres jornadas que cuesta.
	for kind: int in Trap.INFO:
		if kind == Trap.Kind.FOSO:
			continue
		for species: String in Trap.catches(kind as Trap.Kind):
			assert_true(Fauna.porte_of(species) < Fauna.Porte.MAYOR,
				"%s no coge %s" % [Trap.trap_name(kind as Trap.Kind), species])


func test_la_trampa_cobra_con_el_tiempo_calada() -> void:
	# Es lo que la hace distinta de todo lo demás: no es una jornada por
	# pieza, es una inversión que trabaja mientras la banda hace otra cosa.
	var trap := Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1, "prueba")
	assert_eq(trap.collect(), 0, "recién puesta no tiene nada")

	trap.soaking = Trap.days_per_catch(Trap.Kind.LAZO) * 3.0
	var pieces := trap.collect()
	assert_true(pieces >= 2, "tres veces el tiempo dan varias piezas: %d" % pieces)
	assert_eq(trap.taken, pieces, "y se apunta lo que ha dado")
	assert_true(trap.soaking < Trap.days_per_catch(Trap.Kind.LAZO),
		"levantarla descuenta el tiempo cobrado")


func test_la_trampa_vieja_coge_menos() -> void:
	var nueva := Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1)
	var vieja := Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1)
	vieja.worn = Trap.lifespan(Trap.Kind.LAZO) * 0.9
	nueva.soaking = 20.0
	vieja.soaking = 20.0
	assert_true(nueva.collect() > vieja.collect(),
		"la fibra floja y el sitio revuelto cogen menos")


func test_la_trampa_se_acaba_echando_a_perder() -> void:
	var sim := SettlementSim.new()
	var trap := Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1, "prueba")
	trap.worn = Trap.lifespan(Trap.Kind.LAZO) - 0.5
	sim.trampas.traps.append(trap)
	sim.parajes = Parajes.new()
	sim._age_traps()
	assert_true(sim.trampas.traps.is_empty(), "la que se pasa de vida se retira")
	assert_eq(sim.trampas.traps_lost_today.size(), 1, "y se cuenta como pérdida")


func test_las_trampas_cobran_mientras_la_banda_duerme() -> void:
	var sim := SettlementSim.new()
	sim.parajes = Parajes.new()
	var trap := Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1, "prueba")
	sim.trampas.traps.append(trap)
	sim._age_traps()
	assert_eq(trap.soaking, 1.0, "una jornada calada por cada jornada que pasa")
	assert_eq(trap.worn, 1.0, "y una jornada de vida gastada")


func test_no_se_amontonan_las_trampas_en_el_mismo_claro() -> void:
	# Una línea de trampas es una LÍNEA: amontonarlas no coge más, coge lo
	# mismo repartido.
	var sim := SettlementSim.new()
	sim.trampas.traps.append(Trap.create(Trap.Kind.LAZO, Vector3.ZERO, 1))
	assert_false(sim.trampas._room_for_trap(Vector3(10.0, 0.0, 10.0)),
		"pegada a otra, no")
	assert_true(sim.trampas._room_for_trap(Vector3(400.0, 0.0, 400.0)),
		"a cuatrocientos metros, sí")


# --- la cuadrilla: cuánta gente hace falta según la rama -----------------

func test_caza_mayor_sola_rinde_muy_poco() -> void:
	# La petición: «según el tipo de caza y el animal se necesitará más o
	# menos gente». Un solo batidor contra un uro no es una cuadrilla.
	assert_lt(Hunting.crew_factor(Profession.Speciality.CAZA_MAYOR, 1), 0.30,
		"un cazador solo de caza mayor rinde a menos de un tercio")


func test_caza_mayor_con_cuadrilla_completa_rinde_entero() -> void:
	assert_eq(Hunting.crew_factor(Profession.Speciality.CAZA_MAYOR, 4), 1.0,
		"con cuatro manos, la batida rinde entera")
	assert_eq(Hunting.crew_factor(Profession.Speciality.CAZA_MAYOR, 9), 1.0,
		"de cuatro para arriba no hay más que ganar: sobran brazos, no faltan")


func test_caza_mayor_sube_con_cada_mano_de_mas() -> void:
	var uno := Hunting.crew_factor(Profession.Speciality.CAZA_MAYOR, 1)
	var dos := Hunting.crew_factor(Profession.Speciality.CAZA_MAYOR, 2)
	var tres := Hunting.crew_factor(Profession.Speciality.CAZA_MAYOR, 3)
	assert_true(uno < dos and dos < tres,
		"cada mano de más sube el rendimiento, no sólo la de cuatro")


func test_caza_menor_no_necesita_cuadrilla() -> void:
	# Al acecho, solo o de a dos: una cuadrilla no acecha mejor que un
	# cazador solo, y por eso NO tiene curva.
	assert_eq(Hunting.crew_factor(Profession.Speciality.CAZA_MENOR, 1), 1.0,
		"solo, rinde entero")
	assert_eq(Hunting.crew_factor(Profession.Speciality.CAZA_MENOR, 5), 1.0,
		"y con cuadrilla, igual: no cunde ni estorba")


func test_las_trampas_no_tienen_curva_de_cuadrilla() -> void:
	assert_eq(Hunting.crew_factor(Profession.Speciality.TRAMPAS, 1), 1.0,
		"la trampa trabaja sola, no tiene noción de cuadrilla")


func test_hunters_in_cuenta_solo_esta_especialidad_de_caza() -> void:
	# No toda la actividad CAZA: trampas, menor y mayor son cuadrillas
	# distintas y no se mezclan al contar manos.
	var sim := SettlementSim.new()
	var mayor_uno := Inhabitant.create(0, Vector3.ZERO, sim._rng)
	mayor_uno.has_task = true
	mayor_uno.current_speciality = Profession.Speciality.CAZA_MAYOR
	var mayor_dos := Inhabitant.create(1, Vector3.ZERO, sim._rng)
	mayor_dos.has_task = true
	mayor_dos.current_speciality = Profession.Speciality.CAZA_MAYOR
	var menor := Inhabitant.create(2, Vector3.ZERO, sim._rng)
	menor.has_task = true
	menor.current_speciality = Profession.Speciality.CAZA_MENOR
	var ocioso := Inhabitant.create(3, Vector3.ZERO, sim._rng)
	ocioso.has_task = false
	ocioso.current_speciality = Profession.Speciality.CAZA_MAYOR
	sim.people = [mayor_uno, mayor_dos, menor, ocioso]

	assert_eq(sim.taller.hunters_in(Profession.Speciality.CAZA_MAYOR), 2,
		"dos en cuadrilla mayor, sin contar al que no tiene tarea hoy")
	assert_eq(sim.taller.hunters_in(Profession.Speciality.CAZA_MENOR), 1,
		"uno solo en menor, aparte del todo")


# --- el riesgo: un uro no es un conejo ------------------------------------

func test_la_cuadrilla_reparte_tambien_el_peligro() -> void:
	# Ir en cuadrilla no es sólo más pieza: es también más seguro. Cuatro
	# batidores no corren, cada uno, el riesgo entero del que va solo.
	var solo := Hunting.risk_at(Profession.Speciality.CAZA_MAYOR,
		Vector3(2048.0, 0.0, 2048.0), Subsistence.Season.OTONO, 1)
	var cuadrilla := Hunting.risk_at(Profession.Speciality.CAZA_MAYOR,
		Vector3(2048.0, 0.0, 2048.0), Subsistence.Season.OTONO, 4)
	if solo > 0.0:
		assert_eq(cuadrilla, solo / 4.0, "el riesgo se reparte entre manos")


func test_un_uro_no_es_un_conejo() -> void:
	# El aviso literal de Fauna.gd, hecho número: la caza mayor arriesga más
	# que la trampa, porque las piezas que persigue son más peligrosas.
	var mayor := Hunting.risk_at(Profession.Speciality.CAZA_MAYOR,
		Vector3(2048.0, 0.0, 2048.0), Subsistence.Season.OTONO)
	var menuda := Hunting.risk_at(Profession.Speciality.TRAMPAS,
		Vector3(2048.0, 0.0, 2048.0), Subsistence.Season.OTONO)
	assert_gt(mayor, menuda, "la pieza mayor arriesga más que la de trampa")
