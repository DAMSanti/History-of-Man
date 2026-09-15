class_name Prioridades
extends RefCounted
## Lo que el jugador quiere primero: materiales, especies de caza y piezas.
##
## Las prioridades que ya existían son DE PERSONA Y OFICIO —quién recolecta,
## quién caza, quién talla—. Dentro del oficio no decidía nadie: el recolector
## se traía todo lo que hubiera y el cazador iba a la pieza de más raciones por
## metro. Esto es la palanca que faltaba para decir QUÉ. Spec en
## docs/SISTEMAS.md §22.
##
## **Sólo se guarda lo que no es normal.** Una partida sin tocar nada tiene los
## tres diccionarios vacíos, y ése es el camino por el que el juego se comporta
## exactamente igual que antes de que esto existiera: ver [hay_algo_puesto].
##
## Va colgado de [SettlementSim] y NO es estático: cada campamento tendrá el
## suyo sin tocar esta clase —ver SISTEMAS §23—, y SPECS §2.2 no admite un
## autoload más. Se guarda solo, porque [Instantanea] recorre por reflexión.
##
## El jugador no lo toca directamente: pasa por la fachada de [SettlementSim],
## porque cambiar el nivel de un material obliga a reordenar los parajes.

enum Nivel { ALTA, NORMAL, BAJA, NUNCA }


## Cuánto pesa cada nivel al elegir paraje.
##
## **Decisión del usuario del 2026-09-14**, no una medida: un empujón y no una
## orden. Con ×2, el sitio que tiene lo prioritario gana a uno mediano, pero un
## paraje el doble de rico en lo demás todavía puede ganarle. Lo de nunca pesa
## cero, que es lo que lo saca de la elección sin necesidad de un caso aparte.
const PESO := {
	Nivel.ALTA: 2.0,
	Nivel.NORMAL: 1.0,
	Nivel.BAJA: 0.5,
	Nivel.NUNCA: 0.0,
}

## Cómo se llama cada nivel en pantalla. Vive aquí y no en la ventana porque lo
## leen tres paneles distintos: almacén, trabajos y taller.
const NOMBRE := {
	Nivel.ALTA: "alta",
	Nivel.NORMAL: "normal",
	Nivel.BAJA: "baja",
	Nivel.NUNCA: "nunca",
}

## El orden en que se recorren los niveles al pulsar la marca de una fila.
const RUEDA := [Nivel.NORMAL, Nivel.ALTA, Nivel.BAJA, Nivel.NUNCA]

## Lo que no está en normal, y nada más. Las claves son `Materia.Kind`,
## el nombre de especie de [Fauna] y `Tool.Kind`.
var materiales: Dictionary = {}
var especies: Dictionary = {}
var piezas: Dictionary = {}


static func peso(nivel: Nivel) -> float:
	return float(PESO[nivel])


static func nombre(nivel: Nivel) -> String:
	return String(NOMBRE[nivel])


## El nivel siguiente al pulsar: normal → alta → baja → nunca → normal.
static func siguiente(nivel: Nivel) -> Nivel:
	var donde := RUEDA.find(nivel)
	return RUEDA[(donde + 1) % RUEDA.size()] as Nivel


## Si el jugador ha tocado alguna prioridad.
##
## Es el interruptor del camino de siempre: mientras esto sea falso, la carga
## se recorre en el orden de la tabla y los parajes se puntúan sin pesos, o sea
## exactamente como antes de que esto existiera.
func hay_algo_puesto() -> bool:
	return not (materiales.is_empty() and especies.is_empty() and piezas.is_empty())


func de_material(kind: Materia.Kind) -> Nivel:
	return materiales.get(int(kind), Nivel.NORMAL) as Nivel


func fijar_material(kind: Materia.Kind, nivel: Nivel) -> void:
	_fijar(materiales, int(kind), nivel)


func de_especie(species: String) -> Nivel:
	return especies.get(species, Nivel.NORMAL) as Nivel


func fijar_especie(species: String, nivel: Nivel) -> void:
	_fijar(especies, species, nivel)


func de_pieza(kind: Tool.Kind) -> Nivel:
	return piezas.get(int(kind), Nivel.NORMAL) as Nivel


func fijar_pieza(kind: Tool.Kind, nivel: Nivel) -> void:
	_fijar(piezas, int(kind), nivel)


## Sube o baja una pieza un escalón, sin salirse por los extremos.
##
## Es lo que hace el botón de subir y bajar de la cola del taller: una sola
## palanca con dos puertas —ver SISTEMAS §22—, y por eso el orden de la cola y
## el nivel de la pieza no son dos reglas distintas.
func mover_pieza(kind: Tool.Kind, escalones: int) -> void:
	var orden := [Nivel.ALTA, Nivel.NORMAL, Nivel.BAJA, Nivel.NUNCA]
	var donde := orden.find(de_pieza(kind))
	fijar_pieza(kind, orden[clampi(donde + escalones, 0, orden.size() - 1)] as Nivel)


## Las piezas apartadas, para poder devolverlas. Quitar una entrada automática
## de la cola la deja en nunca, y sin esta lista no habría forma de sacarla.
func piezas_en_nunca() -> Array[int]:
	var fuera: Array[int] = []
	for kind: int in piezas:
		if piezas[kind] == Nivel.NUNCA:
			fuera.append(kind)
	fuera.sort()
	return fuera


## Lo normal no se guarda: es lo que deja los diccionarios vacíos en una
## partida sin tocar, y con ellos vacíos nada de esto cambia el juego.
func _fijar(donde: Dictionary, clave: Variant, nivel: Nivel) -> void:
	if nivel == Nivel.NORMAL:
		donde.erase(clave)
	else:
		donde[clave] = nivel
