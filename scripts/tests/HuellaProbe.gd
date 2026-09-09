extends SceneTree
## Qué forma tienen los parajes de verdad.
##
## Es la queja del jugador: «¿por qué los parajes son círculos? Quiero que
## puedan ser cualquier forma, así se adaptan al río bien también, o a una
## ribera».
##
## Aquí se mide lo único que lo contesta sin mirar una captura: cuánto se
## parece la mancha a un disco. Dos cifras por paraje:
##
##   LLENADO  qué parte del círculo nominal ocupa de verdad. Un disco da 100 %.
##   ALARGADA cuánto mide el lado largo contra el corto. Un disco da 1,0; una
##            pesquera que siga el cauce tiene que dar bastante más.

const SITE_ID := 56


func _init() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var sim := await _arrancar()
	if sim == null:
		quit()
		return
	sim.time_scale = 20.0

	# Unas jornadas para que se descubran parajes de los cuatro oficios.
	var primero: int = sim.day
	while sim.day < primero + 4:
		await process_frame

	print("")
	print("=== LA FORMA DE LOS PARAJES ===")
	print("%-27s %-14s %7s %8s %9s" % [
		"sitio", "oficio", "radio", "llenado", "alargada"])
	for paraje: Paraje in sim.parajes.list:
		var h: Huella = paraje.huella
		if h == null or h.vacia():
			print("%-27s %-14s   SIN HUELLA" % [
				paraje.name_text, Subsistence.activity_name(paraje.activity)])
			continue
		var celdas := h.celdas()
		var disco := PI * paraje.extent * paraje.extent
		var caja := _caja(celdas)
		print("%-27s %-14s %6.0f m %6.0f %% %8.2f" % [
			paraje.name_text,
			Subsistence.activity_name(paraje.activity),
			paraje.extent,
			100.0 * h.superficie() / maxf(disco, 1.0),
			maxf(caja.x, caja.y) / maxf(minf(caja.x, caja.y), 1.0)])

	# Lo que cuesta rehacer la forma de todos. Se hace una vez al dia, asi que
	# tiene que caber de sobra en un cuadro.
	# Lo que cuesta mantener las formas al dia. Se reparte a lo largo de las
	# jornadas -ver [Parajes.MS_POR_REPASO]- porque hacerlas todas de una vez
	# costaba quince milisegundos, o sea un cuadro entero de tiron.
	print("")
	for repaso in range(6):
		var reloj := Time.get_ticks_usec()
		var hechas: int = sim.parajes.retocar_huellas(sim.field, sim._terrain)
		print("repaso %d: rehace %d de %d parajes en %.2f ms" % [
			repaso + 1, hechas, sim.parajes.list.size(),
			float(Time.get_ticks_usec() - reloj) / 1000.0])

	print("")
	print("--- LA MANCHA DE UN SITIO DE AGUA, CELDILLA A CELDILLA ---")
	for paraje: Paraje in sim.parajes.list:
		if paraje.activity != Subsistence.Activity.PESCA 				and paraje.activity != Subsistence.Activity.MARISQUEO:
			continue
		var h: Huella = paraje.huella
		print("%s · %d celdillas de lado" % [paraje.name_text, h.lado])
		# Tres mapas uno al lado del otro: donde hay AGUA, cuanto PESCADO da el
		# campo, y que celdillas acabaron dentro. Asi se ve de un vistazo cual
		# de los tres filtros corta la cinta.
		for z in range(h.lado):
			var agua := ""
			var pesca := ""
			var mancha := ""
			for x in range(h.lado):
				var punto := h.origen + Vector3(
					(float(x) + 0.5) * Huella.CELDILLA, 0.0,
					(float(z) + 0.5) * Huella.CELDILLA)
				var calado: float = sim._terrain.crossing_difficulty_at(punto)
				agua += "#" if calado > 0.05 else "."
				var hay: float = sim.field.seasonal_abundance_at(
					paraje.activity, punto, GameState.season)
				pesca += "#" if hay >= 0.05 else ("+" if hay > 0.0 else ".")
				mancha += "#" if h.dentro[z * h.lado + x] != 0 else "."
			print("   %s   %s   %s" % [agua, pesca, mancha])
		print("   (agua)%s(pesca)%s(mancha)" % [
			" ".repeat(maxi(h.lado - 3, 1)), " ".repeat(maxi(h.lado - 4, 1))])

	print("")
	print("--- QUE DA EL CAMPO ALREDEDOR (para elegir el umbral) ---")
	print("%-27s %7s %7s %7s %7s %7s" % [
		"sitio", "nucleo", "40 m", "80 m", "120 m", "170 m"])
	for paraje: Paraje in sim.parajes.list:
		var fila := "%-27s" % paraje.name_text
		for lejos: float in [0.0, 40.0, 80.0, 120.0, 170.0]:
			# La media del anillo, que es lo que decide si el borde entra.
			var suma := 0.0
			var cuantos := 0
			for i in range(16):
				var a := TAU * float(i) / 16.0
				var punto := paraje.position + Vector3(
					cos(a) * lejos, 0.0, sin(a) * lejos)
				suma += sim.field.seasonal_abundance_at(
					paraje.activity, punto, GameState.season)
				cuantos += 1
				if lejos <= 0.0:
					break
			fila += " %6.2f " % (suma / float(cuantos))
		print(fila)

	print("")
	print("--- Y QUE LA SIMULACION USE LA FORMA, NO EL RADIO ---")
	# La prueba de que ya no es pintura: puntos DENTRO del círculo nominal que
	# la mancha deja fuera. Con el paraje redondo esta cifra sería cero.
	for paraje: Paraje in sim.parajes.list:
		var dentro_del_disco := 0
		var dentro_de_la_mancha := 0
		var paso := 10.0
		var d := -paraje.extent
		while d <= paraje.extent:
			var e := -paraje.extent
			while e <= paraje.extent:
				if Vector2(d, e).length() <= paraje.extent:
					dentro_del_disco += 1
					var punto := paraje.position + Vector3(d, 0.0, e)
					if paraje.contains(punto):
						dentro_de_la_mancha += 1
				e += paso
			d += paso
		print("   %-27s %d de %d puntos del disco son del sitio (%.0f %%)" % [
			paraje.name_text, dentro_de_la_mancha, dentro_del_disco,
			100.0 * float(dentro_de_la_mancha) / maxf(float(dentro_del_disco), 1.0)])
	quit()


## Ancho y largo de la caja que envuelve la mancha, en metros.
func _caja(celdas: Array[Vector3]) -> Vector2:
	if celdas.is_empty():
		return Vector2.ONE
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for c: Vector3 in celdas:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_z = minf(min_z, c.z)
		max_z = maxf(max_z, c.z)
	return Vector2(max_x - min_x + Huella.CELDILLA, max_z - min_z + Huella.CELDILLA)


func _arrancar() -> Node:
	var local: HeightmapData = load("res://data/dem/local/site_%d.res" % SITE_ID)
	var sites: SiteSet = load("res://data/sites/cantabria_sites.res")
	if local == null or sites == null:
		print("faltan los datos de relieve")
		return null
	var site: Site = null
	for s: Site in sites.sites:
		if s.id == SITE_ID:
			site = s
	var size_m := local.get_world_size_meters()
	var half := float(Expedition.local_size_m) * 0.5
	Expedition.site = site
	Expedition.heightmap_path = "res://data/dem/local/site_%d.res" % SITE_ID
	Expedition.sea_level_m = 0.0
	Expedition.era = Site.Era.PALEOLITICO
	Expedition.region_offset = Vector2(
		clampf(local.u_for_lon(site.lon) * size_m.x - half, 0.0,
			maxf(size_m.x - half * 2.0, 0.0)),
		clampf(local.v_for_lat(site.lat) * size_m.y - half, 0.0,
			maxf(size_m.y - half * 2.0, 0.0)))
	change_scene_to_file("res://scenes/demo_main.tscn")
	for i in range(90):
		await process_frame
	var demo := current_scene
	if demo == null or not ("sim" in demo):
		print("la escena no arranco")
		return null
	return demo.sim
