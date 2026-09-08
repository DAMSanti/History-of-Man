extends SceneTree
## Cuanto cuesta de verdad meter una clase por medio en el camino caliente.
##
## Al sacar un sistema de `SettlementSim` pasan dos cosas en cada llamada: la
## llamada deja de ser sobre `self` y va sobre un miembro, y TODO lo que el
## cuerpo leia del simulador pasa de `x` a `sim.x`. Lo segundo es lo que puede
## doler, porque no es una indireccion: son ocho por llamada en el caso de
## `_tick_step`.
##
## Esto lo mide en vez de suponerlo. Reproduce el patron real -ocho lecturas de
## miembro y unas cuentas- de las dos formas.
##
##   godot --headless --path . --script res://scripts/tools/CosteIndireccion.gd
##
## MEDIDO: la llamada pasa de 249,5 a 453,2 ns, un 82 % mas. Suena mucho y en
## la partida no es nada: quince personas por ocho pasos son 120 llamadas por
## fotograma, o sea 0,024 ms sobre un fotograma de 38,5. El 0,06 %. Para que
## esto costara UN milisegundo harian falta unas 4.900 llamadas por fotograma,
## y no hay nada aqui que se acerque.
##
## O sea que el coste de sacar un sistema del simulador NO es la velocidad: es
## que `sim.loquesea` deja de comprobarse en compilacion. Ver
## `tools/LlamadasHuerfanas.gd`, que es lo que sustituye a esa comprobacion.

const VUELTAS := 2_000_000


class FachadaFalsa extends RefCounted:
	var arrive_radius := 3.0
	var walk_speed := 1.2
	var home_position := Vector3(10.0, 0.0, 10.0)
	var gravedad := 9.8
	var escala := 1.5
	var tope := 100.0
	var suelo := 0.5
	var roce := 0.9

	## Como esta hoy: todo en casa, acceso directo.
	func paso(t: float) -> float:
		var v := walk_speed * escala
		v *= (1.0 - roce * suelo)
		v = minf(v, tope)
		return v + arrive_radius + gravedad * t + home_position.x


class SistemaFuera extends RefCounted:
	var sim: FachadaFalsa

	func _init(s: FachadaFalsa) -> void:
		sim = s

	## Como quedaria: la misma cuenta, pero todo pedido al simulador.
	func paso(t: float) -> float:
		var v := sim.walk_speed * sim.escala
		v *= (1.0 - sim.roce * sim.suelo)
		v = minf(v, sim.tope)
		return v + sim.arrive_radius + sim.gravedad * t + sim.home_position.x


func _init() -> void:
	var sim := FachadaFalsa.new()
	var fuera := SistemaFuera.new(sim)

	# Una vuelta en vacio para que no se mida el calentamiento.
	_directo(sim, 10000)
	_por_miembro(fuera, 10000)

	var t0 := Time.get_ticks_usec()
	var a := _directo(sim, VUELTAS)
	var directo := Time.get_ticks_usec() - t0

	t0 = Time.get_ticks_usec()
	var b := _por_miembro(fuera, VUELTAS)
	var indirecto := Time.get_ticks_usec() - t0

	var ns_directo := float(directo) * 1000.0 / float(VUELTAS)
	var ns_indirecto := float(indirecto) * 1000.0 / float(VUELTAS)
	print("")
	print("=== %s llamadas de cada forma ===" % VUELTAS)
	print("  en casa            %8.1f ns por llamada" % ns_directo)
	print("  por `sim.`         %8.1f ns por llamada" % ns_indirecto)
	print("  diferencia         %8.1f ns (%.0f %% mas)" % [
		ns_indirecto - ns_directo,
		100.0 * (ns_indirecto - ns_directo) / maxf(ns_directo, 0.001)])
	print("  (sumas iguales: %s)" % ("si" if is_equal_approx(a, b) else "NO"))

	# Y lo que eso significa en la partida. El peor caso de verdad: quince
	# personas por los ocho pasos que como mucho hace un fotograma.
	var por_cuadro := 15 * 8
	var coste_ms := (ns_indirecto - ns_directo) * float(por_cuadro) / 1_000_000.0
	print("")
	print("en la partida: %d llamadas por fotograma como mucho" % por_cuadro)
	print("  coste anadido  %.4f ms por fotograma" % coste_ms)
	print("  el fotograma dura hoy 38.5 ms -> %.3f %% del presupuesto" % (
		100.0 * coste_ms / 38.5))
	quit()


func _directo(sim: FachadaFalsa, n: int) -> float:
	var total := 0.0
	for i in range(n):
		total += sim.paso(0.033)
	return total


func _por_miembro(fuera: SistemaFuera, n: int) -> float:
	var total := 0.0
	for i in range(n):
		total += fuera.paso(0.033)
	return total
