class_name Viento
extends RefCounted
## Cuánto ha corrido el viento de las nubes, con el reloj de la partida.
##
## **Una sola cuenta** para las nubes del cielo del valle
## ([WorldEnvironmentSetup]) y para las del mapa regional (GRAFICOS §3): si cada una
## llevara la suya, un día correrían a distinta velocidad sin que nadie lo notara.
##
## Va con el reloj de la partida y no con el de pared —decisión del usuario del
## 2026-09-14—: paradas si la partida está en pausa, cinco veces más rápido a ×5, y
## también en la noche acelerada.

## De metros de viento a unidades del ruido de las nubes. Es el 40 que usaba el shader
## con `TIME`, y se deja igual para que a ×1 corran como corrían.
const A_RUIDO := 40.0

## Lo que corre el viento de las nubes.
const METROS_POR_SEGUNDO := 0.012


## El recorrido del viento en la jornada `dia` a la hora `hora`, con jornadas de
## `segundos_por_dia` segundos de reloj a ×1.
##
## Envuelto muy lejos: el ruido de los shaders ya no pierde precisión hasta el millón
## —el hash no usa seno—, y a esa cifra se llega en miles de jornadas.
static func recorrido(dia: int, hora: float, segundos_por_dia: float) -> float:
	var segundos := (float(dia) * 24.0 + hora) / 24.0 * segundos_por_dia
	return fmod(segundos * METROS_POR_SEGUNDO * A_RUIDO, 1.0e6)
