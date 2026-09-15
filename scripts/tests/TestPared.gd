class_name TestPared
extends TestCase
## La pared que se ve: los motivos, el arte de los que estuvieron antes, el
## relieve y dónde va cada figura. SISTEMAS §13, spec del 2026-09-15.


func suite_name() -> String:
	return "Pared"


# --- los motivos ----------------------------------------------------------------

## Todo relato que se puede pintar tiene su figura, y ninguno cae en una de
## relleno: la caza mayor lleva su animal, lo demás signos y manos.
func test_todo_relato_pintable_tiene_su_motivo() -> void:
	var sin_figura: Array[String] = []

	for especie: String in Fauna.SPECIES:
		if Fauna.porte_of(especie) != Fauna.Porte.MAYOR:
			continue
		var caza := Tale.hunt("Ana", especie, "el vado", 3, true, 1,
			Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR))
		if not Motivos.FIGURAS.has(caza.motivo()):
			sin_figura.append("caza de " + especie)

	for titulo: String in ["Cumbre coronada", "Una cueva nueva"]:
		var hallazgo := Tale.discovery(titulo, "", Vector3.ZERO, 1,
			Profession.task_id(Profession.Job.EXPLORACION, Profession.Speciality.NINGUNA))
		if not Motivos.FIGURAS.has(hallazgo.motivo()):
			sin_figura.append("hallazgo " + titulo)

	for tech: int in TechTree.Tech.values():
		var job := TechTree.job_of(tech as TechTree.Tech)
		var tarea := -1 if job < 0 else Profession.task_id(job as Profession.Job,
			Profession.Speciality.NINGUNA)
		var tecnica := Tale.technique(tech as TechTree.Tech, 1, tarea)
		if not Motivos.FIGURAS.has(tecnica.motivo()):
			sin_figura.append("técnica " + TechTree.tech_name(tech as TechTree.Tech))

	var hito := Tale.new()
	hito.kind = Tale.Kind.HITO
	if not Motivos.FIGURAS.has(hito.motivo()):
		sin_figura.append("hito")

	assert_eq(sin_figura.size(), 0, "relatos sin figura: %s" % str(sin_figura))


## Lo que no es caza no es un animal: son signos y manos.
func test_lo_que_no_es_caza_se_pinta_con_signos_y_manos() -> void:
	var hallazgo := Tale.discovery("Cumbre coronada", "", Vector3.ZERO, 1, 0)
	var hito := Tale.new()
	hito.kind = Tale.Kind.HITO
	var tecnica := Tale.technique(TechTree.Tech.ARTE, 1, 0)
	for relato: Tale in [hallazgo, hito, tecnica]:
		var figura: Dictionary = Motivos.FIGURAS[relato.motivo()]
		assert_true(String(figura["tecnica"]) != "contorno"
			and String(figura["tecnica"]) != "tinta_plana",
			"%s no debería ser un animal, y es %s" % [relato.title, relato.motivo()])
	assert_eq(hito.motivo(), "mano", "el hito, con una mano")


## Cada figura tiene pigmento y cuerpo, dentro de su cuadrado.
func test_cada_motivo_tiene_trazo_y_cuerpo_dentro_de_su_cuadrado() -> void:
	var malos: Array[String] = []
	for clave: String in Motivos.FIGURAS:
		var trazos: Array = Motivos.trazos_de(clave)
		var cuerpo: Array = Motivos.cuerpo_de(clave)
		if trazos.is_empty() or cuerpo.is_empty():
			malos.append(clave + " vacío")
			continue
		for forma: Array in trazos:
			for anillo: PackedVector2Array in forma:
				for p: Vector2 in anillo:
					if absf(p.x) > 0.51 or absf(p.y) > 0.51:
						malos.append(clave + " se sale")
						break
	assert_eq(malos.size(), 0, "motivos mal formados: %s" % str(malos))


## Cada motivo cita su referencia en CREDITOS: la página de la que se calcó.
func test_cada_motivo_cita_su_referencia_en_creditos() -> void:
	var creditos := FileAccess.get_file_as_string("res://docs/CREDITOS.md")
	assert_gt(float(creditos.length()), 0.0, "se lee CREDITOS")
	var sin_cita: Array[String] = []
	for clave: String in Motivos.FIGURAS:
		var referencia := String((Motivos.FIGURAS[clave] as Dictionary)["referencia"])
		if referencia.is_empty() or not creditos.contains(referencia):
			sin_cita.append(clave)
	assert_eq(sin_cita.size(), 0, "motivos sin su referencia en CREDITOS: %s" % str(sin_cita))


# --- el arte de los que estuvieron antes ----------------------------------------

## Cada cueva del catálogo es un elemento de algún mapa: cae a menos de
## [ArteDeLosDeAntes.RADIO_M] de una cueva de los datos.
func test_cada_cueva_con_arte_esta_en_algun_mapa() -> void:
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var perdidas: Array[String] = []
	for cueva: Dictionary in ArteDeLosDeAntes.CUEVAS:
		var hallada := false
		for sitio: Site in sitios.sites:
			for elemento: Dictionary in sitio.features:
				if not elemento.has("lat"):
					continue
				if ArteDeLosDeAntes.distancia_m(float(elemento["lat"]), float(elemento["lon"]),
						float(cueva["lat"]), float(cueva["lon"])) <= ArteDeLosDeAntes.RADIO_M:
					hallada = true
		if not hallada:
			perdidas.append(String(cueva["nombre"]))
	assert_eq(perdidas.size(), 0, "cuevas con arte que no están en ningún mapa: %s" % str(perdidas))


## Y ningún otro elemento se reconoce como cueva con arte: todo lo que cae dentro
## del radio lleva el nombre de esa cueva. Las cuatro del monte Castillo están a
## poco más de cien metros unas de otras, y ésa es la trampa de este criterio.
func test_ningun_otro_elemento_se_toma_por_cueva_con_arte() -> void:
	var sitios := load("res://data/sites/cantabria_sites.res") as SiteSet
	var intrusos: Array[String] = []
	var reconocidos := 0
	for sitio: Site in sitios.sites:
		for elemento: Dictionary in sitio.features:
			if not elemento.has("lat"):
				continue
			var cueva := ArteDeLosDeAntes.en(float(elemento["lat"]), float(elemento["lon"]))
			if cueva.is_empty():
				continue
			reconocidos += 1
			var clave := String(cueva["id"]).split("_")[-1]
			var nombre := String(elemento.get("name", "")).to_lower() \
				.replace("í", "i").replace("ñ", "n")
			if not nombre.contains(clave):
				intrusos.append("%s tomado por %s" % [elemento.get("name", ""), cueva["nombre"]])
	assert_gt(float(reconocidos), 0.0, "se reconoce alguna")
	assert_eq(intrusos.size(), 0, "elementos tomados por una cueva con arte: %s" % str(intrusos))


## Cada panel es de motivos que existen, dice algo, y cita de dónde lo saca.
func test_cada_panel_tiene_figuras_texto_y_fuentes() -> void:
	var malos: Array[String] = []
	for cueva: Dictionary in ArteDeLosDeAntes.CUEVAS:
		var nombre := String(cueva["nombre"])
		var cuantas := 0
		for panel: Dictionary in cueva["paneles"]:
			if not Motivos.FIGURAS.has(String(panel["motivo"])):
				malos.append("%s: motivo %s no existe" % [nombre, panel["motivo"]])
			cuantas += int(panel["cuantos"])
		if ArteDeLosDeAntes.figuras_de(cueva).size() != cuantas or cuantas == 0:
			malos.append(nombre + ": figuras mal repartidas")
		if String(cueva["texto"]).length() < 60:
			malos.append(nombre + ": sin texto")
		if (cueva["fuentes"] as Array).is_empty():
			malos.append(nombre + ": sin fuentes")
		if bool(cueva["discutida"]) and not String(cueva["texto"]).contains("discut"):
			malos.append(nombre + ": fecha discutida que el texto no dice discutida")
	assert_eq(malos.size(), 0, "paneles mal: %s" % str(malos))


## La lista está escrita en EPOCA_01 §12, cueva a cueva con su fuente.
func test_la_lista_esta_en_la_ficha_de_epoca_con_sus_fuentes() -> void:
	var ficha := FileAccess.get_file_as_string("res://docs/EPOCA_01_PALEOLITICO.md")
	var faltan: Array[String] = []
	for cueva: Dictionary in ArteDeLosDeAntes.CUEVAS:
		if not ficha.contains(String(cueva["nombre"])):
			faltan.append(String(cueva["nombre"]))
		for fuente: String in cueva["fuentes"]:
			if not ficha.contains(fuente):
				faltan.append(fuente)
	assert_eq(faltan.size(), 0, "falta en EPOCA_01: %s" % str(faltan))


# --- la pared -------------------------------------------------------------------

## La misma partida, sitio y cueva dan la misma roca; otra cueva, otra.
func test_misma_semilla_misma_pared() -> void:
	var a := ParedDeLaCueva.de(42, 56, 3)
	var b := ParedDeLaCueva.de(42, 56, 3)
	var c := ParedDeLaCueva.de(42, 56, 4)
	assert_true(a.relieve == b.relieve, "la misma cueva sale igual")
	assert_false(a.relieve == c.relieve, "otra cueva sale distinta")


## Y las mismas figuras caen en los mismos sitios.
func test_misma_pared_mismos_sitios() -> void:
	var sitios: Array = []
	for _vez in range(2):
		var pared := ParedDeLaCueva.de(7, 1, 0)
		var estos: Array = []
		for motivo: String in ["bisonte", "cierva", "mano", "puntos", "caballo"]:
			var figura := pared.colocar(motivo, "rojo", false)
			estos.append([figura["centro"], figura["giro"], figura["espejo"]])
		sitios.append(estos)
	assert_eq(str(sitios[0]), str(sitios[1]), "dos corridas, la misma pared")


## Lo documentado no se pisa nunca, ni con la pared llena de la banda.
func test_nada_encima_de_una_figura_documentada() -> void:
	var pared := ParedDeLaCueva.de(11, 16, 0)
	for figura: Dictionary in ArteDeLosDeAntes.figuras_de(ArteDeLosDeAntes.CUEVAS[0]):
		pared.colocar(String(figura["motivo"]), String(figura["color"]), true)
	var documentadas := pared.figuras.size()
	assert_gt(float(documentadas), 5.0, "hay figuras documentadas puestas")
	var pisadas := 0
	for i in range(40):
		var motivo := ["bisonte", "cierva", "caballo", "mano"][i % 4] as String
		var figura := pared.colocar(motivo, "rojo", false)
		if figura.is_empty():
			continue
		var m := ParedDeLaCueva.muestras_de(motivo)
		for p: Vector2 in m["dentro"]:
			var celda := ParedDeLaCueva.celda_de(p, figura)
			if celda < 0:
				continue
			var quien := pared.ocupada_en(celda)
			if quien >= 0 and quien < documentadas:
				pisadas += 1
	assert_eq(pisadas, 0, "muestras de la banda sobre figuras documentadas")


## Con la pared llena se pinta encima de lo más antiguo de la banda, y nunca se
## queda una figura sin sitio.
func test_con_la_pared_llena_se_pinta_encima() -> void:
	var pared := ParedDeLaCueva.de(3, 2, 1)
	var sin_sitio := 0
	for _i in range(45):
		if pared.colocar("uro", "negro", false).is_empty():
			sin_sitio += 1
	assert_eq(sin_sitio, 0, "ninguna figura se queda sin sitio")
	# La primera ya no ocupa todas sus celdas: alguna le ha caído encima.
	var m := ParedDeLaCueva.muestras_de("uro")
	var primera: Dictionary = pared.figuras[0]
	var suyas := 0
	var tapadas := 0
	for p: Vector2 in m["dentro"]:
		var celda := ParedDeLaCueva.celda_de(p, primera)
		if celda < 0:
			continue
		suyas += 1
		if pared.ocupada_en(celda) != 0:
			tapadas += 1
	assert_gt(float(tapadas), 0.0, "la más antigua tiene algo pintado encima (%d de %d)"
		% [tapadas, suyas])


# --- la sala --------------------------------------------------------------------

## La sala dibuja tantas figuras como hay: las documentadas de la cueva más las
## que pintó la banda allí.
func test_la_sala_dibuja_lo_documentado_y_lo_pintado() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.game_seed = 3
	var covalanas: Dictionary = ArteDeLosDeAntes.CUEVAS[5]
	sim.pinturas.elementos = [{"name": String(covalanas["nombre"]),
		"lat": covalanas["lat"], "lon": covalanas["lon"]}]
	sim.exploracion._sabido[0] = {"explorada": true, "pintable": true}
	sim.exploracion.cueva_de_la_banda = 0
	for especie: String in ["ciervo", "caballo"]:
		var tale := Tale.hunt("Ana", especie, "el vado", 3, true, 1,
			Profession.task_id(Profession.Job.CAZA, Profession.Speciality.CAZA_MAYOR))
		tale.painted = true
		tale.cueva = 0
		sim.paintings.append(tale)
	var sala := SalaDeLaCueva.new()
	sala.montar(sim, 0, String(covalanas["nombre"]))
	var esperadas := ArteDeLosDeAntes.figuras_de(covalanas).size() + 2
	assert_eq(sala.figuras_dibujadas, esperadas, "documentadas y pintadas, todas")
	assert_eq(sala.pared.figuras.size(), esperadas, "y la pared tiene las mismas")
	sala.free()
	sim.free()


# --- entrar y salir ------------------------------------------------------------

## En la ficha de una cueva siempre está «entrar a mirar»; sin explorar, apagado y
## con el motivo, y explorada, se pulsa. No hace falta saber pintar.
func test_la_ficha_de_la_cueva_deja_entrar_en_lo_explorado_y_dice_por_que_no() -> void:
	var sim := SettlementSim.new()
	sim.techs = TechTree.new()
	var acciones := PanelSitios._actions_for(Site.Feature.ABRIGO, true, false, false)
	var tiene := false
	for accion: Array in acciones:
		if String(accion[0]) == "entrar":
			tiene = true
	assert_true(tiene, "la acción está aunque no esté explorada")
	var sin_explorar := PanelSitios.por_que_no("entrar", {"cueva": 2}, sim)
	assert_false(sin_explorar.is_empty(), "sin explorar, dice por qué no")
	sim.exploracion._sabido[2] = {"explorada": true, "pintable": false}
	assert_eq(PanelSitios.por_que_no("entrar", {"cueva": 2}, sim), "",
		"explorada, se entra, y sin saber pintar")
	sim.free()


## En el mapa regional se ofrece entrar sólo en las cuevas exploradas del
## campamento, con su nombre.
func test_el_mapa_regional_ofrece_las_cuevas_exploradas_del_campamento() -> void:
	var sim := SettlementSim.new()
	sim.pinturas.elementos = [{"name": "Cueva de Altamira"}, {"name": "Otra"},
		{"name": "Cueva del Pendo"}]
	sim.exploracion._sabido[0] = {"explorada": true, "pintable": true}
	sim.exploracion._sabido[2] = {"explorada": true, "pintable": false}
	var cuevas := sim.pinturas.cuevas_para_entrar()
	assert_eq(cuevas.size(), 2, "las dos exploradas, no la otra")
	assert_true(cuevas.size() == 2 and String(cuevas[0][1]) == "Cueva de Altamira",
		"con su nombre")
	sim.free()


## Salir quita la sala y avisa: la escena de debajo queda como estaba.
func test_salir_quita_la_sala() -> void:
	var sim := SettlementSim.new()
	sim.chronicle = Chronicle.new()
	sim.exploracion._sabido[0] = {"explorada": true, "pintable": true}
	var sala := SalaDeLaCueva.new()
	sala.montar(sim, 0, "prueba")
	var avisada := [false]
	sala.cerrada.connect(func() -> void: avisada[0] = true)
	sala.cerrar()
	assert_true(avisada[0], "avisa al salir")
	assert_true(sala.is_queued_for_deletion(), "y se va")
	sala.free()
	sim.free()

