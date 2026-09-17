class_name Seguimiento
extends RefCounted
## A quien sigue la camara, si es que sigue a alguien. INTERFAZ §13.
##
## Elegir a una persona -con un clic en el valle o desde cualquier lista- la centra y la
## sigue: el punto de orbita va con ella cuadro a cuadro hasta que el jugador hace otra
## cosa. Sin esto, elegir a alguien desde una lista abria su ficha y la persona podia estar
## al otro lado del valle; y eligiendola en el mundo, en cuanto echaba a andar se salia
## del encuadre. La ficha decia que hacia y no dejaba **mirarla hacerlo**.
##
## **No decide nada de la partida** (SPECS §4.7): mira a quien sigue y dice que punto hay
## que mirar; quien mueve la camara es `DemoMain`.
##
## **Y no es estatico** aunque seria mas comodo de alcanzar: es estado de una escena, y con
## una estatica habria que acordarse de soltarlo al pasar al mapa regional. Asi se muere
## con la escena, que es lo que la spec pide. Vive colgado de [GameUI], que es lo que ya
## tienen a mano los paneles que sueltan.

## A quien se sigue, o null.
var a_quien: Inhabitant = null


## Empieza a seguir a alguien. Seguir a null es soltar.
## El nombre lleva el `_a` porque `BarraSuperior` -sacada de la fachada [GameUI]- tiene su
## propio `seguir`, el de continuar con la tarjeta de un momento, y `LlamadasHuerfanas`
## sólo ve nombres: un `seguimiento.seguir(...)` salía como llamada mal puesta a aquélla.
func seguir_a(person: Inhabitant) -> void:
	a_quien = person


func soltar() -> void:
	a_quien = null


func esta_siguiendo() -> bool:
	return a_quien != null


## El punto que hay que mirar, o `Vector3.INF` si no se sigue a nadie o ya no vale.
##
## **Lo que se SIGUE es lo que se VE**, no lo simulado: durante los metros que se le ve
## andar, la figura va por detras de la persona (GRAFICOS §7.6), y seguir la posicion
## simulada dejaria a la figura fuera del centro justo en el unico rato en que las dos no
## coinciden. Por el medio de un viaje abreviado lo que se ve es la marca, que si va en lo
## simulado. Las dos cosas las contesta [Figuras.donde_se_ve].
func punto(sim: SettlementSim, figuras: Figuras) -> Vector3:
	if a_quien == null or sim == null:
		return Vector3.INF
	var index := sim.people.find(a_quien)
	if index < 0:
		# Se ha ido del valle, se ha mudado o ha muerto: `people` es la lista de los que
		# estan aqui. Ver [DemoMain], que suelta al recibir esto.
		return Vector3.INF
	if figuras == null:
		return a_quien.position
	return figuras.donde_se_ve(index, a_quien)


## Si esta persona esta en el valle ahora mismo. Lo pregunta quien va a empezar a
## seguirla: a alguien que no esta se le abre la ficha y la camara no se mueve.
static func esta_en_el_valle(person: Inhabitant, sim: SettlementSim) -> bool:
	if person == null or sim == null:
		return false
	return sim.people.has(person)
