class_name TestCase
extends RefCounted
## Base para las pruebas. Marco minimo y sin dependencias: no merece la pena
## meter un plugin entero para lo que hace falta aqui.
##
## Cada metodo que empiece por `test_` se ejecuta solo. `before_each()` corre
## antes de cada uno, para dejar el estado limpio.
##
## Se lanzan todas con:
##   godot --headless --path . --script res://scripts/tests/RunTests.gd

var failures: Array[String] = []
var checks: int = 0
var _current: String = ""


func before_each() -> void:
	pass


func suite_name() -> String:
	return "TestCase"


## Ejecuta todos los test_ de esta clase. Devuelve [pasados, fallados].
func run() -> Array:
	var passed := 0
	var failed := 0

	for entry: Dictionary in get_method_list():
		var method: String = entry["name"]
		if not method.begins_with("test_"):
			continue

		_current = method
		var before := failures.size()
		before_each()
		callv(method, [])
		if failures.size() == before:
			passed += 1
		else:
			failed += 1

	return [passed, failed]


func _fail(message: String) -> void:
	failures.append("%s :: %s — %s" % [suite_name(), _current, message])


func assert_true(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		_fail(message)


func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if actual != expected:
		_fail("%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		_fail("%s (esperado %.3f ±%.3f, obtenido %.3f)" % [
			message, expected, tolerance, actual])


func assert_gt(actual: float, threshold: float, message: String) -> void:
	checks += 1
	if actual <= threshold:
		_fail("%s (%.3f no es mayor que %.3f)" % [message, actual, threshold])


func assert_lt(actual: float, threshold: float, message: String) -> void:
	checks += 1
	if actual >= threshold:
		_fail("%s (%.3f no es menor que %.3f)" % [message, actual, threshold])


func assert_between(actual: float, low: float, high: float, message: String) -> void:
	checks += 1
	if actual < low or actual > high:
		_fail("%s (%.3f fuera de [%.3f, %.3f])" % [message, actual, low, high])
