class_name Desechos
extends RefCounted
## El montón: lo que la banda tira y NO desaparece.
##
## Un conchero no es un adorno arqueológico: es la prueba de que la gente estuvo
## comiendo ahí durante años. El Cantábrico está lleno de ellos —El Mazo, La
## Fragua, Santimamiñe— y son montones de metros de espesor hechos de una sola
## cosa: cáscara. Lo que se comió se fue; lo que sobró sigue ahí, y es lo único
## que queda.
##
## Aquí pasa lo mismo. La comida entra en la despensa, se come y desaparece de
## la cuenta; el DESECHO se queda, se acumula y a partir de cierto volumen se
## ve en el paisaje —ver [Conchero]— y tiñe el suelo alrededor.
##
## Lo que lo hace interesante es que no todo deja lo mismo. El marisco es casi
## todo concha: un litro de comida deja casi dos de cáscara. La carne no deja
## casi nada. Así que el montón DICE de qué ha vivido la banda, y a los cinco
## años el jugador puede mirarlo y saberlo sin abrir ninguna ventana.

## Litros de desecho por RACIÓN comida, material a material.
##
## No es una tabla de balanceo: es la parte no comestible de cada cosa. Una
## lapa es concha en su mayor parte; una raíz se come entera. Las que no están
## no dejan nada que dure —una baya no deja montón—.
##
## Queda abierta a playtest, pero el ORDEN de magnitud es el bueno: el marisco
## tiene que dominar el montón como domina los concheros de verdad.
const POR_RACION := {
	Materia.Kind.MARISCO: 2.4,        ## Casi todo es concha
	Materia.Kind.CARACOL: 1.1,        ## Concha también, más menuda
	Materia.Kind.BELLOTA_DULCE: 0.45, ## Cascarilla y cúpula
	Materia.Kind.FRUTO_SECO: 0.40,    ## Cáscara de avellana
	Materia.Kind.HUEVO: 0.20,
	Materia.Kind.CARNE: 0.14,         ## Hueso y asta que no se aprovechan
	Materia.Kind.CARNE_SECA: 0.10,
	Materia.Kind.PESCADO: 0.09,       ## Espina
	Materia.Kind.PESCADO_SECO: 0.07,
}

## A partir de cuántos litros el montón se ve en el mundo.
##
## Cuatrocientos: un año de marisqueo fuerte. Por debajo de eso son unas
## cáscaras tiradas, y unas cáscaras tiradas no son un conchero.
const SE_VE := 400.0

## Litros acumulados por material de origen.
var litros: Dictionary = {}

## Lo que se tiró hoy, en litros. Para la crónica y las sondas.
var hoy: float = 0.0


## Apunta lo que deja una comida.
func tirar(kind: Materia.Kind, raciones: float) -> void:
	if raciones <= 0.0:
		return
	var por := float(POR_RACION.get(kind, 0.0))
	if por <= 0.0:
		return
	var cuanto := raciones * por
	litros[int(kind)] = float(litros.get(int(kind), 0.0)) + cuanto
	hoy += cuanto


## Y lo que deja un proceso, que no se come pero también sobra: la cascarilla
## que suelta la bellota en el lavadero. Ver [Hogar._lavar_bellota].
func tirar_litros(kind: Materia.Kind, cuanto: float) -> void:
	if cuanto <= 0.0:
		return
	litros[int(kind)] = float(litros.get(int(kind), 0.0)) + cuanto
	hoy += cuanto


func nuevo_dia() -> void:
	hoy = 0.0


## El montón entero, en litros.
func volumen() -> float:
	var total := 0.0
	for kind: int in litros:
		total += float(litros[kind])
	return total


## De qué está hecho sobre todo. Es lo que decide el COLOR del montón: blanco
## de concha o pardo de cáscara.
func dominante() -> int:
	var mejor := -1
	var mas := 0.0
	for kind: int in litros:
		if float(litros[kind]) > mas:
			mas = float(litros[kind])
			mejor = kind
	return mejor


## Si hay bastante para que se vea desde fuera.
func se_ve() -> bool:
	return volumen() >= SE_VE


## Cuánto ha crecido, de 0 a 1, para que la vista sepa de qué tamaño pintarlo.
##
## Se satura: un conchero de diez metros no se dibuja diez veces más grande que
## uno de uno, entre otras cosas porque no cabría en el abrigo. La raíz cúbica
## es lo que hace que el montón crezca deprisa al principio y luego casi no,
## que es como crece un montón de verdad al desparramarse.
func crecido() -> float:
	if volumen() <= 0.0:
		return 0.0
	return clampf(pow(volumen() / (SE_VE * 24.0), 1.0 / 3.0), 0.0, 1.0)


## Lo que hay, dicho en una línea, para la ficha y la crónica.
func resumen() -> String:
	if not se_ve():
		return "Todavía no hay montón: sólo cáscara suelta."
	var partes: Array[String] = []
	var orden: Array[int] = []
	orden.assign(litros.keys())
	orden.sort_custom(func(a: int, b: int) -> bool:
		return float(litros[a]) > float(litros[b]))
	for kind: int in orden:
		if float(litros[kind]) < volumen() * 0.05:
			continue
		partes.append("%s %.0f %%" % [
			Materia.material_name(kind as Materia.Kind).to_lower(),
			100.0 * float(litros[kind]) / volumen()])
	return "%.1f m³ de desecho: %s." % [volumen() / 1000.0, ", ".join(partes)]
