class_name Calculo
extends RefCounted
## `exp` y `pow` que dan el mismo último bit en cualquier hilo.
##
## **Por qué existe** (SISTEMAS §23, «un hilo por campamento»): los campamentos
## que no se miran dan su paso en hilos del pool y el que se mira en el hilo
## principal, y **`exp` y `pow` de la librería no dan el mismo último bit en uno
## y en otro**. Medido el 2026-09-14 sobre 60 000 valores: `exp` difería en el
## 15 % y `pow` en el 5 %; sumar, multiplicar, dividir, `floor`, `log`, `sqrt`,
## `sin` y `atan2` coincidían siempre, y los hilos del pool coincidían entre sí.
## Se vio en la sonda: el mismo campamento, en serie y en paralelo, escribía un
## parte de atasco con la última cifra distinta. En diez jornadas no llegó a la
## partida, pero un bit que cambia es lo que con los días separa dos partidas.
##
## Así que aquí se calculan **sólo con las operaciones que coinciden**. No dan
## el mismo bit que la librería —el cambio desplaza las firmas una vez— pero dan
## el mismo en todos los hilos, que es lo que pide SPECS §3.3. **Invariante**
## (SPECS §7): el código que corre dentro de un paso no llama a `exp` ni a `pow`
## de la librería; lo comprueba `TestCalculo`.

const LN2 := 0.6931471805599453


## e elevado a `x`.
##
## Se lleva `x` a `k·ln 2 + r` con `|r| ≤ ln 2 / 2` y se suma la serie de `r`
## hasta que el término no mueve la suma; luego se multiplica por dos `k` veces,
## que en binario es exacto. Con `|r| ≤ 0,35` la serie cierra en unos quince
## términos.
static func exponencial(x: float) -> float:
	if x > 709.0:
		return INF
	if x < -745.0:
		return 0.0
	var k := int(floor(x / LN2 + 0.5))
	var r := x - float(k) * LN2
	var suma := 1.0
	var termino := 1.0
	var n := 1
	while n < 40:
		termino = termino * r / float(n)
		var antes := suma
		suma += termino
		if suma == antes:
			break
		n += 1
	var escala := 2.0 if k > 0 else 0.5
	for _i in range(absi(k)):
		suma *= escala
	return suma


## `base` elevada a `exponente`, para bases no negativas.
##
## `exp(exponente · log(base))`, con la exponencial de aquí y el `log` de la
## librería, que sí coincide entre hilos. Una base negativa no se usa en la
## partida y devuelve NAN, como `pow` con exponente no entero.
static func potencia(base: float, exponente: float) -> float:
	if base == 0.0:
		return 1.0 if exponente == 0.0 else 0.0
	if base < 0.0:
		return NAN
	if base == 1.0 or exponente == 0.0:
		return 1.0
	return exponencial(exponente * log(base))
