class_name CamaraLenta
## Cuanto frena la partida segun lo cerca que este la camara. GRAFICOS §7.6.
##
## De esto sale un numero y nada mas: quien lo aplica es `DemoMain`, poniendolo en
## `SettlementSim.freno_de_la_vista`. **Y lo que frena es cuantos pasos se dan, no cuanto
## dura cada uno**, que es lo que hace que la partida sea la misma (SPECS §3.1).
##
## Por que hace falta: un dia de juego son 120 s reales, o sea que la gente anda 900 m por
## segundo de pantalla -720 veces lo real-. Un viaje de dos kilometros dura dos segundos y
## lo que se ve son muñecos cruzando el valle como disparos. Los viajes se arreglan
## abreviandolos ([Figuras]); lo que se hace EN EL SITIO solo se puede mirar frenando.
##
## Funciones puras y sin estado: la prueba las llama sin montar nada.

## A partir de aqui no se frena nada. Decision del usuario (2026-09-16): es mas o menos
## la distancia a la que se deja de distinguir a una persona de otra.
const DESDE_M := 60.0

## Lo mas despacio que llega a ir, en fraccion de pasos por segundo. Veinte veces mas
## despacio, decision del usuario: a x1 eso deja la gente andando a 45 m por segundo de
## pantalla, que sigue sin ser un paso humano pero ya se sigue con la vista.
const LO_MAS_LENTO := 0.05


## El freno para esta distancia de camara. 1,0 es no frenar.
##
## `minima` es lo mas que se puede acercar la camara en esta escena, que no es fijo: sale
## del zoom que le haya dado el valle. Por debajo de ella no se frena mas.
##
## La cuesta va con el CUADRADO de lo que queda por acercarse, y no recta, porque el
## recorrido util del zoom esta casi todo en los ultimos metros: con una recta, la mitad
## del frenazo se gastaba entre los 60 y los 40 m, donde todavia no se distingue a nadie.
static func freno(distancia: float, minima: float) -> float:
	var suelo := maxf(minima, 0.01)
	if distancia >= DESDE_M or suelo >= DESDE_M:
		return 1.0
	var cerca := clampf((DESDE_M - distancia) / (DESDE_M - suelo), 0.0, 1.0)
	return lerpf(1.0, LO_MAS_LENTO, cerca * cerca)


## Si a este freno hay que avisar en pantalla. El redondeo del rotulo llega a «×1,0» un
## poco antes de que el freno sea 1, y un letrero que dice «x1,0» no dice nada.
static func se_avisa(freno_puesto: float) -> bool:
	return freno_puesto < 0.95


## Lo que dice el letrero de la barra: cuantas veces mas despacio va.
static func rotulo(freno_puesto: float) -> String:
	return "A cámara lenta ×%.1f" % (1.0 / maxf(freno_puesto, 0.001))
