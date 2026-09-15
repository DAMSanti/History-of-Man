extends SceneTree
## Lo que la spec pide de la pared, medido: cada figura va donde la roca la
## recalca mejor que en el 90 % de los sitios al azar **donde podía ir**, y colocarla
## cabe en un paso.
##
## SISTEMAS §13. Sin escena: la pared es de la simulación y es pura.
##
##   godot --headless --path . --script res://scripts/tests/ParedProbe.gd
##
## Veinte figuras por pared —la muestra que pide la spec—, en tres paredes con
## semillas distintas, mezclando animales, manos y signos. Para cada figura se
## compara su ajuste con 200 sitios al azar del mismo motivo en la misma pared.

const FIGURAS := ["bisonte", "cierva", "caballo", "mano", "puntos", "ciervo", "uro",
	"tectiforme", "jabali", "claviforme"]
const AL_AZAR := 200


func _init() -> void:
	var peor := 1.0
	var peor_libre := 1.0
	var bajo_p90_libre := 0
	var bajo_p90 := 0
	var total := 0
	var ms_max := 0.0
	var ms_suma := 0.0
	for semilla: int in [42, 7, 2026]:
		var pared := ParedDeLaCueva.de(semilla, 56, 0)
		for i in range(20):
			var motivo := String(FIGURAS[i % FIGURAS.size()])
			var t := Time.get_ticks_usec()
			var figura := pared.colocar(motivo, "rojo", false)
			var ms := (Time.get_ticks_usec() - t) / 1000.0
			ms_max = maxf(ms_max, ms)
			ms_suma += ms
			total += 1
			if figura.is_empty():
				bajo_p90 += 1
				print("  sin sitio: %s" % motivo)
				continue
			var propio := pared.ajuste(motivo, figura["centro"], float(figura["lado"]),
				float(figura["giro"]), bool(figura["espejo"]))
			# LA OTRA LECTURA: contra los sitios al azar donde la figura PODÍA ir —libres
			# de otras figuras, medidos antes de ponerla—. Una figura quince de veinte no
			# puede ir donde ya hay catorce.
			var libres := _al_azar_libres(pared, motivo, AL_AZAR, semilla + i, figura)
			var bajo_libre := 0
			for v: float in libres:
				if v < propio:
					bajo_libre += 1
			var fraccion_libre := float(bajo_libre) / float(maxi(libres.size(), 1))
			peor_libre = minf(peor_libre, fraccion_libre)
			if fraccion_libre < 0.9:
				bajo_p90_libre += 1
			var azar := pared.ajustes_al_azar(motivo, AL_AZAR, semilla + i)
			var por_debajo := 0
			for v: float in azar:
				if v < propio:
					por_debajo += 1
			var fraccion := float(por_debajo) / float(maxi(azar.size(), 1))
			peor = minf(peor, fraccion)
			if fraccion < 0.9:
				bajo_p90 += 1
				print("  bajo el 90 %%: semilla %d, figura %d (%s): mejor que el %.0f %%"
					% [semilla, i, motivo, fraccion * 100.0])
	print("")
	print("=== LA PARED: %d figuras en 3 paredes ===" % total)
	print("  la peor figura recalca mejor que el %.0f %% de los sitios al azar" % (peor * 100.0))
	print("  figuras por debajo del 90 %%: %d" % bajo_p90)
	print("  contra sitios LIBRES: la peor mejor que el %.0f %%, por debajo del 90 %%: %d"
		% [peor_libre * 100.0, bajo_p90_libre])
	print("  colocar una figura: %.0f ms de media, %.0f ms la peor" % [ms_suma / total, ms_max])
	# EL CRITERIO ES CONTRA LOS SITIOS LIBRES —decisión del usuario del 2026-09-15—.
	# Contra cualquier sitio, la figura quince de una pared de veinte se compara con
	# huecos donde ya hay otras catorce y no podía ir: salía al 88 %, y al 99 % contra
	# los libres. La otra cifra se sigue enseñando arriba.
	print("TODO BIEN" if bajo_p90_libre == 0 else "NO CUMPLE")
	quit()


## Ajustes de sitios al azar donde la figura cabría sin pisar a las demás, sin
## contarse a sí misma: se quita un momento de la pared para medir.
func _al_azar_libres(pared: ParedDeLaCueva, motivo: String, cuantos: int, semilla: int,
		figura: Dictionary) -> PackedFloat32Array:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([semilla, motivo, "libres"])
	var m := ParedDeLaCueva.muestras_de(motivo)
	var suya := pared.figuras.find(figura)
	var valores := PackedFloat32Array()
	var intentos := 0
	while valores.size() < cuantos and intentos < cuantos * 40:
		intentos += 1
		var centro := Vector2(azar.randf() * ParedDeLaCueva.ANCHO * ParedDeLaCueva.CELDA_M,
			azar.randf() * ParedDeLaCueva.ALTO * ParedDeLaCueva.CELDA_M)
		var lado := float(ParedDeLaCueva.TAMANO_M[motivo]) 			* float(ParedDeLaCueva.ESCALAS[azar.randi() % ParedDeLaCueva.ESCALAS.size()])
		var espejo := azar.randf() < 0.5
		# Libre de las demás: ninguna muestra de dentro sobre celdas de otra figura.
		var pisa := false
		var prueba := {"centro": centro, "lado": lado, "giro": 0.0, "espejo": espejo}
		for p: Vector2 in m["dentro"]:
			var celda := ParedDeLaCueva.celda_de(p, prueba)
			if celda < 0:
				pisa = true
				break
			var quien := pared.ocupada_en(celda)
			if quien >= 0 and quien != suya:
				pisa = true
				break
		if pisa:
			continue
		valores.append(pared.ajuste(motivo, centro, lado, 0.0, espejo))
	return valores

