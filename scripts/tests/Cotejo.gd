extends SceneTree
## Compara dos corridas: si son la misma partida, y dónde se separan si no.
##
## Tarea 5 de docs/specs/LO_MISMO_MAS_DEPRISA.md. Lee dos ficheros de firmas
## de [FirmaDiaria] —los que escribe `TironAnualProbe` con `FIRMAS=`— y dice
## cuántas jornadas coinciden, la primera en que se separan y qué ha cambiado
## en ella: los campos del resumen que difieren y, del detalle, qué «Clase.campo»
## no cuadra. Con eso una diferencia se busca en el código, no a ojo.
##
##   godot --headless --path . --script res://scripts/tests/Cotejo.gd -- firmas A.txt B.txt
##
## Sale con 0 si las jornadas que tienen en común las dos son iguales, con 1 si
## no, y con 2 si no se ha podido leer algo.
##
## Y la tarea 19: `tramos` compara dos rankings de `TironAnualProbe`
## (`RESUMEN=`) tramo a tramo, por COSTE POR LLAMADA, contra la banda de ruido
## que dan las dos corridas de la línea base:
##
##   ... -- tramos ANTES.csv DESPUES.csv [BASE1.csv BASE2.csv]
##
## Sale con 1 si algún tramo sube más que su ruido. Sin las dos de la línea base
## usa [RUIDO_SIN_BASE] para todos y lo dice.

## Cuántos campos del detalle se listan como mucho.
const DETALLE_MAXIMO := 200

## La banda de ruido que se usa cuando no se da la línea base: ±10 %.
const RUIDO_SIN_BASE := 0.10

## Por debajo de esta banda no se baja nunca, aunque las dos corridas de la
## línea base hayan salido casi iguales en un tramo: dos corridas no son una
## estadística.
const RUIDO_MINIMO := 0.02

## Con menos llamadas que esto, el coste por llamada es una anécdota: se
## enseña pero no se juzga.
const LLAMADAS_MINIMAS := 20


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "firmas":
		quit(_firmas(args[1], args[2]))
		return
	if args.size() >= 3 and args[0] == "tramos":
		var base1 := args[3] if args.size() >= 5 else ""
		var base2 := args[4] if args.size() >= 5 else ""
		quit(_tramos(args[1], args[2], base1, base2))
		return
	print("uso: ... --script res://scripts/tests/Cotejo.gd -- firmas A B")
	print("     ... --script res://scripts/tests/Cotejo.gd -- tramos ANTES DESPUES [BASE1 BASE2]")
	quit(2)


# --- tramos ---------------------------------------------------------------


## Un ranking de `TironAnualProbe`: tramo -> {ms, veces, por_llamada}. Las
## líneas que empiezan por `#` son los totales y van en la clave "#".
func _lee_tramos(ruta: String) -> Dictionary:
	var tramos: Dictionary = {}
	var totales: Dictionary = {}
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		print("no se puede leer %s" % ruta)
		return tramos
	while not fichero.eof_reached():
		var linea := fichero.get_line().strip_edges()
		if linea.is_empty():
			continue
		var partes := linea.split(";")
		if linea.begins_with("#"):
			if partes.size() >= 2:
				totales[partes[0].trim_prefix("#").strip_edges()] = partes.slice(1)
			continue
		if partes.size() < 4 or not partes[1].is_valid_float():
			continue
		tramos[partes[0]] = {"ms": float(partes[1]), "veces": int(partes[2]),
			"por_llamada": float(partes[3])}
	tramos["#"] = totales
	return tramos


func _tramos(ruta_antes: String, ruta_despues: String, ruta_base1: String,
		ruta_base2: String) -> int:
	var antes := _lee_tramos(ruta_antes)
	var despues := _lee_tramos(ruta_despues)
	if antes.size() <= 1 or despues.size() <= 1:
		print("alguno de los dos no tiene tramos")
		return 2
	var con_base := not ruta_base1.is_empty() and not ruta_base2.is_empty()
	var base1: Dictionary = _lee_tramos(ruta_base1) if con_base else {}
	var base2: Dictionary = _lee_tramos(ruta_base2) if con_base else {}

	var nombres: Array = []
	for nombre: String in antes:
		if nombre != "#" and despues.has(nombre):
			nombres.append(nombre)
	nombres.sort_custom(func(a: String, b: String) -> bool:
		return float(antes[a]["ms"]) > float(antes[b]["ms"]))

	print("")
	print("=== COTEJO DE TRAMOS (coste por llamada) ===")
	print("antes:   %s" % ruta_antes)
	print("después: %s" % ruta_despues)
	print("ruido:   %s" % ("las dos corridas de la línea base, tramo a tramo (mínimo %.0f %%)" % (
		RUIDO_MINIMO * 100.0) if con_base
		else "±%.0f %% para todos: no se ha dado la línea base" % (RUIDO_SIN_BASE * 100.0)))
	print("%-46s %10s %10s %8s %7s  %s" % ["tramo", "antes ms", "después", "cambio", "ruido", ""])
	var suben := 0
	for nombre: String in nombres:
		var a: Dictionary = antes[nombre]
		var d: Dictionary = despues[nombre]
		var por_a: float = a["por_llamada"]
		var por_d: float = d["por_llamada"]
		var cambio := (por_d - por_a) / maxf(por_a, 0.000001)
		var ruido := RUIDO_SIN_BASE
		if con_base:
			ruido = RUIDO_MINIMO
			if base1.has(nombre) and base2.has(nombre):
				var p1: float = base1[nombre]["por_llamada"]
				var p2: float = base2[nombre]["por_llamada"]
				ruido = maxf(RUIDO_MINIMO,
					absf(p1 - p2) / maxf((p1 + p2) * 0.5, 0.000001))
		var veredicto := ""
		if mini(int(a["veces"]), int(d["veces"])) < LLAMADAS_MINIMAS:
			veredicto = "pocas llamadas"
		elif cambio > ruido:
			veredicto = "SUBE"
			suben += 1
		elif cambio < -ruido:
			veredicto = "baja"
		print("%-46s %10.3f %10.3f %+7.1f%% %6.1f%%  %s" % [nombre.left(46), por_a, por_d,
			cambio * 100.0, ruido * 100.0, veredicto])
	for nombre: String in despues:
		if nombre != "#" and not antes.has(nombre):
			print("%-46s %10s %10.3f  (tramo nuevo)" % [nombre.left(46), "-",
				float(despues[nombre]["por_llamada"])])

	var totales_a: Dictionary = antes["#"]
	var totales_d: Dictionary = despues["#"]
	if not totales_a.is_empty():
		print("")
		for clave: String in totales_a:
			print("   %-16s antes %-24s después %s" % [clave, ";".join(totales_a[clave]),
				";".join(totales_d.get(clave, []))])
	print("")
	if suben == 0:
		print("NINGÚN TRAMO SUBE por encima de su ruido")
		return 0
	print("%d TRAMO(S) SUBEN por encima de su ruido" % suben)
	return 1


func _lee(ruta: String) -> Dictionary:
	var dias: Dictionary = {}
	var fichero := FileAccess.open(ruta, FileAccess.READ)
	if fichero == null:
		print("no se puede leer %s" % ruta)
		return dias
	while not fichero.eof_reached():
		var huella := FirmaDiaria.desde_linea(fichero.get_line())
		if huella != null:
			dias[huella.dia] = huella
	return dias


func _firmas(ruta_a: String, ruta_b: String) -> int:
	var a := _lee(ruta_a)
	var b := _lee(ruta_b)
	if a.is_empty() or b.is_empty():
		print("alguno de los dos no tiene firmas")
		return 2

	var comunes: Array = []
	var solo_a := 0
	var solo_b := 0
	for dia: int in a:
		if b.has(dia):
			comunes.append(dia)
		else:
			solo_a += 1
	for dia: int in b:
		if not a.has(dia):
			solo_b += 1
	comunes.sort()

	var iguales := 0
	var distintas := 0
	var primera := -1
	var iguales_antes := 0
	for dia: int in comunes:
		if (a[dia] as FirmaDiaria).firma == (b[dia] as FirmaDiaria).firma:
			iguales += 1
			if primera < 0:
				iguales_antes += 1
		else:
			distintas += 1
			if primera < 0:
				primera = dia

	print("")
	print("=== COTEJO DE FIRMAS ===")
	print("A: %s (%d jornadas)" % [ruta_a, a.size()])
	print("B: %s (%d jornadas)" % [ruta_b, b.size()])
	print("en común: %d jornadas%s" % [comunes.size(),
		"" if solo_a + solo_b == 0 else " (sólo en A: %d, sólo en B: %d)" % [solo_a, solo_b]])
	if comunes.is_empty():
		print("no tienen ninguna jornada en común")
		return 2
	if primera < 0:
		print("IGUALES: las %d jornadas en común, de la %d a la %d, tienen la misma firma" % [
			iguales, comunes.front(), comunes.back()])
		return 0

	print("SE SEPARAN en la jornada %d: %d iguales antes, %d distintas de %d en común" % [
		primera, iguales_antes, distintas, comunes.size()])
	var fa: FirmaDiaria = a[primera]
	var fb: FirmaDiaria = b[primera]

	print("   en el resumen:")
	var claves: Array = fa.resumen.keys()
	for clave: Variant in fb.resumen.keys():
		if not claves.has(clave):
			claves.append(clave)
	claves.sort()
	var alguna := false
	for clave: Variant in claves:
		var va: Variant = fa.resumen.get(clave)
		var vb: Variant = fb.resumen.get(clave)
		if va != vb:
			alguna = true
			print("      %-10s A %s" % [str(clave), str(va)])
			print("      %-10s B %s" % ["", str(vb)])
	if not alguna:
		print("      nada: la diferencia todavía no ha llegado a nada de lo que se ve")

	var campos: Array = []
	for clave: Variant in fa.detalle:
		if fa.detalle.get(clave) != fb.detalle.get(clave):
			campos.append(clave)
	for clave: Variant in fb.detalle:
		if not fa.detalle.has(clave):
			campos.append(clave)
	campos.sort()
	print("   en el detalle: %d campos distintos" % campos.size())
	for i in range(mini(campos.size(), DETALLE_MAXIMO)):
		print("      %s" % str(campos[i]))
	if campos.size() > DETALLE_MAXIMO:
		print("      ... y %d más" % (campos.size() - DETALLE_MAXIMO))
	return 1
